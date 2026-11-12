-- ProfileSwap core: saved data, profiles, which profile is active, events, slash commands.
local ADDON, ns = ...
ns.ADDON = ADDON
ns.TITLE = "ProfileSwap"
ns.AUTHOR = "zakarulcodes"
ns.ICON = "Interface\\Icons\\INV_Misc_Gear_01"
ns.SUPPORTED_INTERFACE = { 16001 }

do
    local v = C_AddOns.GetAddOnMetadata(ADDON, "Version") or ""
    ns.VERSION = (v == "" or v:find("@")) and "dev" or v
end

---------------------------------------------------------------------------
-- Saved data
--   profiles[id] = {
--     id, name,
--     resolution    hint "WxH" (the resolution it is meant for)
--     layout        Edit Mode layout name or nil
--     scale         UI scale
--     suppressChat  hide the game's "layout applied" chat line
--     gamepad       controller input + Gamepad UI on/off
--     gamepadScale  scale of the Gamepad UI button wheel (GamepadMainActionBarFrame) or nil
--     display       { [gx CVar] = value } or nil
--     addonSet      name of a set in DB.sets, or nil
--     addonProfiles { [targetKey] = profileName }
--   }
--   autoByRes[res] = profile id picked automatically at that resolution
--   manual         = profile id, or nil for Auto
--   sets[name]     = { [addonName] = true }
--   known[addon]   = true once ProfileSwap has seen it (unknown addons are never disabled)
---------------------------------------------------------------------------

local DEFAULTS = {
    nextID = 0,
    profiles = {},
    autoByRes = {},
    manual = nil,
    sets = {},
    known = nil,
    gamepadStyle = nil,
    skin = "Neon",
    paused = false,
    muted = false,
    collapsed = {},
    window = nil,
    picker = {
        enabled = true,
        point = "CENTER", x = 0, y = -200,
        width = 110, height = 28,
        anchor = "FREE", side = "BOTTOM", matchWidth = false,
        offsetX = 0, offsetY = -8,
        customFrame = nil,
    },
}

local function FillDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = type(v) == "table" and CopyTable(v) or v
        elseif type(v) == "table" and type(target[k]) == "table" then
            FillDefaults(target[k], v)
        end
    end
end

-- Profiles saved by the first test builds used other field names.
local function MigrateOldProfiles(db)
    for id, p in pairs(db.profiles) do
        if p.resolution and not db.autoByRes[p.resolution] and p.migrated == nil then
            db.autoByRes[p.resolution] = id
        end
        if type(p.addons) == "table" then
            local members = {}
            for name, on in pairs(p.addons) do
                if on then members[name] = true end
            end
            local setName = p.name .. " set"
            db.sets[setName] = members
            p.addonSet = setName
            p.addons = nil
        end
        p.addonProfiles = p.addonProfiles or {}
        p.migrated = true
    end
end

local function InitDB()
    ProfileSwapDB = ProfileSwapDB or {}
    FillDefaults(ProfileSwapDB, DEFAULTS)
    MigrateOldProfiles(ProfileSwapDB)
    if not ProfileSwapDB.known then ns.SeedKnownAddons() end
end

function ns.DB()
    return ProfileSwapDB
end

---------------------------------------------------------------------------
-- Chat output (Mute hides it all)
---------------------------------------------------------------------------

function ns.Print(msg)
    if ns.DB() and ns.DB().muted then return end
    print("|cff" .. ns.AccentHex() .. ns.TITLE .. ":|r " .. msg)
end

---------------------------------------------------------------------------
-- Change listeners: everything that shows state registers here
---------------------------------------------------------------------------

local listeners = {}
function ns.OnChange(fn)
    listeners[#listeners + 1] = fn
end
function ns.Changed()
    for _, fn in ipairs(listeners) do fn() end
end

---------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------

function ns.CurrentResolution()
    local w, h = GetPhysicalScreenSize()
    return string.format("%dx%d", math.floor(w + 0.5), math.floor(h + 0.5))
end

function ns.NewProfileID()
    local db = ns.DB()
    db.nextID = db.nextID + 1
    return "p" .. db.nextID
end

function ns.GetProfile(id)
    return id and ns.DB().profiles[id]
end

function ns.SortedProfiles()
    local list = {}
    for _, p in pairs(ns.DB().profiles) do list[#list + 1] = p end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

function ns.FindProfile(text)
    local db = ns.DB()
    if db.profiles[text] then return db.profiles[text] end
    text = text:lower()
    for _, p in pairs(db.profiles) do
        if p.name:lower() == text then return p end
    end
end

function ns.DeleteProfile(id)
    local db = ns.DB()
    db.profiles[id] = nil
    if db.manual == id then db.manual = nil end
    for res, autoID in pairs(db.autoByRes) do
        if autoID == id then db.autoByRes[res] = nil end
    end
    if ns.lastAppliedID == id then ns.lastAppliedID = nil end
    ns.Changed()
end

function ns.IsAutoProfile(p)
    return p and p.resolution and ns.DB().autoByRes[p.resolution] == p.id
end

-- Returns profile or nil, and mode: "manual", "auto" or "none".
function ns.ResolveProfile()
    local db = ns.DB()
    if db.manual then
        if db.profiles[db.manual] then return db.profiles[db.manual], "manual" end
        db.manual = nil -- deleted profile: fall back to Auto
    end
    local id = db.autoByRes[ns.CurrentResolution()]
    if id and db.profiles[id] then return db.profiles[id], "auto" end
    return nil, "none"
end

---------------------------------------------------------------------------
-- Evaluate / select
---------------------------------------------------------------------------

-- force = explicit user choice: applies even while paused and re-checks the addon set.
function ns.Evaluate(verbose, force)
    if not force and ns.DB().paused then
        if verbose then ns.Print("Automation is paused, nothing applied. Activate a profile, or turn Pause off on Overview.") end
        ns.Changed()
        return
    end
    local profile, mode = ns.ResolveProfile()
    if not profile then
        if verbose then ns.Print("No profile for resolution " .. ns.CurrentResolution() .. " (Auto mode).") end
        ns.Changed()
        return
    end
    if verbose then
        ns.Print("Applying profile '" .. profile.name .. "' (" .. (mode == "manual" and "manual" or "auto") .. ", " .. ns.CurrentResolution() .. ").")
    end
    ns.Apply(profile, verbose, force)
end

-- id = profile id, nil = Auto mode.
function ns.SelectProfile(id, verbose)
    if id and not ns.GetProfile(id) then
        ns.Print("Unknown profile.")
        return
    end
    ns.lastAppliedID = nil -- re-check the addon set for the new choice
    ns.DB().manual = id
    ns.Evaluate(verbose ~= false, id ~= nil)
end

---------------------------------------------------------------------------
-- Suppress the game's "layout applied" chat line for profiles that ask for it
---------------------------------------------------------------------------

local layoutAppliedPattern
local function LayoutChatFilter(_, _, msg)
    local p = ns.GetProfile(ns.lastAppliedID)
    if not (p and p.suppressChat and type(msg) == "string") then return false end
    if not layoutAppliedPattern and ERR_EDIT_MODE_LAYOUT_APPLIED then
        layoutAppliedPattern = "^" .. ERR_EDIT_MODE_LAYOUT_APPLIED:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", ".+") .. "$"
    end
    return layoutAppliedPattern ~= nil and msg:find(layoutAppliedPattern) ~= nil
end
do
    local addFilter = ChatFrame_AddMessageEventFilter or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
    if addFilter then
        addFilter("CHAT_MSG_SYSTEM", LayoutChatFilter)
        addFilter("CHAT_MSG_BN_SYSTEM", LayoutChatFilter)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")

local resizeTimer
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        InitDB()
        C_Timer.After(0.5, function() ns.BuildPicker() end)
    elseif event == "PLAYER_LOGIN" then
        ns.RememberGamepadStyle()
        ns.Changed()
        -- once per login / reload; manual choices apply instantly
        C_Timer.After(4, function()
            if ns.DB().paused then
                ns.Print("Automation is paused, login auto-apply skipped. Activate a profile, or turn Pause off on Overview.")
                ns.Changed()
            else
                ns.Evaluate(true)
            end
        end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.RunPending()
    elseif event == "DISPLAY_SIZE_CHANGED" then
        -- moved to another screen: re-pick in Auto mode once the size settles
        if ns.DB().manual or ns.DB().paused or GetTime() < (ns.ignoreResizeUntil or 0) then return end
        if resizeTimer then resizeTimer:Cancel() end
        resizeTimer = C_Timer.NewTimer(1, function()
            local p = ns.ResolveProfile()
            if p and p.id ~= ns.lastAppliedID then ns.Evaluate(true) end
        end)
    end
end)

---------------------------------------------------------------------------
-- Slash: /pswap, /pswap auto, /pswap use <name>, /pswap <name>
---------------------------------------------------------------------------

SLASH_PROFILESWAP1 = "/pswap"
SLASH_PROFILESWAP2 = "/profileswap"
SlashCmdList.PROFILESWAP = function(msg)
    msg = strtrim(msg or "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        ns.OpenWindow("Overview")
    elseif cmd == "auto" then
        ns.SelectProfile(nil, true)
    else
        local p = ns.FindProfile(cmd == "use" and rest or msg)
        if p then
            ns.SelectProfile(p.id, true)
        else
            ns.Print("No profile '" .. (cmd == "use" and rest or msg) .. "'. Commands: /pswap, /pswap auto, /pswap use <profile>")
        end
    end
end
