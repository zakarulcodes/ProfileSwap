-- Applying a profile: display, UI scale, controller, Edit Mode layout,
-- addon profiles, addon set. Deferred out of combat.
local _, ns = ...

local function SetCVarIfDifferent(name, value)
    local current = GetCVar(name)
    if current ~= nil and current ~= value then
        SetCVar(name, value)
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Display: monitor, window mode, resolution (captured from the Graphics settings)
---------------------------------------------------------------------------

local DISPLAY_CVARS = { "gxMonitor", "gxWindow", "gxMaximize", "gxFullscreenResolution", "gxWindowedResolution" }

function ns.CaptureDisplay()
    local display = {}
    for _, name in ipairs(DISPLAY_CVARS) do
        local value = GetCVar(name)
        if value ~= nil then display[name] = value end
    end
    return display
end

function ns.DisplayText(d)
    if not d then return "None" end
    local res = d[ns.ResolutionCVar(d)]
    return (res and res ~= "auto" and (res .. " ") or "") .. ns.DisplayModeOf(d).name
end

-- Display modes as the gx CVars store them. Forever has no gxWindow CVar (tested
-- in game): there only Windowed and Fullscreen (Windowed) exist, picked by gxMaximize.
ns.DISPLAY_MODES = {
    { name = "Fullscreen", gxWindow = "0", gxMaximize = "0", needsWindowCVar = true },
    { name = "Windowed", gxWindow = "1", gxMaximize = "0" },
    { name = "Fullscreen (Windowed)", gxWindow = "1", gxMaximize = "1" },
}

function ns.AvailableDisplayModes()
    local list = {}
    for _, mode in ipairs(ns.DISPLAY_MODES) do
        if not mode.needsWindowCVar or GetCVar("gxWindow") ~= nil then list[#list + 1] = mode end
    end
    return list
end

function ns.SetDisplayMode(d, mode)
    d.gxMaximize = mode.gxMaximize
    d.gxWindow = GetCVar("gxWindow") ~= nil and mode.gxWindow or nil
end

function ns.DisplayModeOf(d)
    if d.gxWindow == "0" then return ns.DISPLAY_MODES[1] end
    if d.gxMaximize == "1" then return ns.DISPLAY_MODES[3] end
    return ns.DISPLAY_MODES[2]
end

-- The resolution CVar the given display mode uses. Fullscreen (Windowed) uses
-- gxFullscreenResolution too (tested in game; "auto" = the game's Default).
function ns.ResolutionCVar(d)
    if ns.DisplayModeOf(d) == ns.DISPLAY_MODES[2] then return "gxWindowedResolution" end
    return "gxFullscreenResolution"
end

-- Returns { "WxH", ... } the monitor supports, largest first. Empty if the client has no API for it.
-- gxMonitor is 0-based; the client APIs below are not confirmed on Forever, so all are guarded.
function ns.SupportedResolutions(d)
    local list, seen = {}, {}
    local function add(w, h)
        w, h = tonumber(w), tonumber(h)
        if not w or not h then return end
        local text = w .. "x" .. h
        if not seen[text] then
            seen[text] = true
            list[#list + 1] = { text = text, pixels = w * h, w = w }
        end
    end
    local monitor = tonumber(d.gxMonitor) or 0
    local fullscreen = ns.ResolutionCVar(d) == "gxFullscreenResolution"
    if C_VideoOptions and C_VideoOptions.GetGameWindowSizes then
        local ok, sizes = pcall(C_VideoOptions.GetGameWindowSizes, monitor, fullscreen)
        if ok and type(sizes) == "table" then
            for _, s in ipairs(sizes) do add(s.x, s.y) end
        end
    end
    if #list == 0 and GetScreenResolutions then
        local ok, res = pcall(function() return { GetScreenResolutions() } end)
        if ok then
            if type(res[1]) == "table" then res = res[1] end
            for _, r in ipairs(res) do
                if type(r) == "string" then add(r:match("^(%d+)%s*x%s*(%d+)$")) end
            end
        end
    end
    if #list == 0 then
        -- shortcut: common 16:9 sizes when the client has no list API; Custom covers the rest.
        for _, r in ipairs({ "3840x2160", "2560x1440", "1920x1080", "1600x900", "1280x720" }) do
            add(r:match("(%d+)x(%d+)"))
        end
    end
    table.sort(list, function(a, b)
        if a.pixels ~= b.pixels then return a.pixels > b.pixels end
        return a.w > b.w
    end)
    local texts = {}
    for i, r in ipairs(list) do texts[i] = r.text end
    return texts
end

-- Returns { {text, value} ... } for the monitor picker, or nil when there is only one monitor.
function ns.MonitorItems()
    local count = GetMonitorCount and tonumber((select(2, pcall(GetMonitorCount)))) or 1
    if count <= 1 then return nil end
    local items = {}
    for i = 1, count do
        local ok, name = false, nil
        if GetMonitorName then ok, name = pcall(GetMonitorName, i) end
        local label = "Monitor " .. i .. ((ok and type(name) == "string" and name ~= "") and (": " .. name) or "")
        items[#items + 1] = { label, tostring(i - 1) }
    end
    return items
end

-- Parses "1920x1080", "1920 x 1080" or "1920*1080" into "1920x1080", or nil.
function ns.ParseResolution(text)
    local w, h = strtrim(text or ""):match("^(%d+)%s*[xX%*]%s*(%d+)$")
    w, h = tonumber(w), tonumber(h)
    if not w or not h or w < 640 or h < 480 or w > 15360 or h > 8640 then return nil end
    return w .. "x" .. h
end

local function ApplyDisplay(p, verbose)
    if not p.display then
        if verbose then ns.Print("Display: none set in this profile (use Capture Current in the editor).") end
        return
    end
    local changed = false
    for name, value in pairs(p.display) do
        if GetCVar(name) == nil then
            ns.Print("Display: setting '" .. name .. "' does not exist on this client, skipped.")
        elseif SetCVarIfDifferent(name, value) then
            changed = true
        end
    end
    if not changed then
        if verbose then ns.Print("Display: already " .. ns.DisplayText(p.display) .. ".") end
        return
    end
    if not RestartGx then
        ns.Print("Display: RestartGx is missing on this client, the display will change after a game restart.")
        return
    end
    ns.ignoreResizeUntil = GetTime() + 5 -- our own resize must not trigger an Auto re-pick
    if verbose then ns.Print("Display: switching to " .. ns.DisplayText(p.display) .. ".") end
    RestartGx()
end

---------------------------------------------------------------------------
-- UI scale
---------------------------------------------------------------------------

ns.SCALE_MIN, ns.SCALE_MAX = 0.65, 1.15

local function ApplyScale(p)
    if not p.scale then return end
    local current = tonumber(GetCVar("uiScale"))
    if current and math.abs(current - p.scale) > 0.001 then
        SetCVar("useUiScale", "1")
        SetCVar("uiScale", tostring(p.scale))
    end
end

---------------------------------------------------------------------------
-- Controller. GamePadEnable = controller input. On WoW Forever the
-- "Enable Gamepad UI" setting is InputDeviceInterfaceStyle (0 = keyboard/mouse).
---------------------------------------------------------------------------

function ns.HasGamepadUI()
    return GetCVar("InputDeviceInterfaceStyle") ~= nil
end

function ns.IsGamepadOn()
    local style = GetCVar("InputDeviceInterfaceStyle")
    if style == nil then return GetCVar("GamePadEnable") == "1" end
    return style ~= "" and style ~= "0"
end

-- The game's "on" value is not documented, so remember whatever it uses.
function ns.RememberGamepadStyle()
    local style = GetCVar("InputDeviceInterfaceStyle")
    if style and style ~= "" and style ~= "0" then ns.DB().gamepadStyle = style end
end

-- On: controller input + Gamepad UI. Off: only the Gamepad UI goes off, the
-- controller keeps working. Clients without the Gamepad UI toggle the controller.
local function ApplyGamepad(p)
    if p.gamepad == nil then return end
    ns.RememberGamepadStyle()
    if not ns.HasGamepadUI() then
        SetCVarIfDifferent("GamePadEnable", p.gamepad and "1" or "0")
        return
    end
    if p.gamepad then SetCVarIfDifferent("GamePadEnable", "1") end
    SetCVarIfDifferent("InputDeviceInterfaceStyle", p.gamepad and (ns.DB().gamepadStyle or "1") or "0")
end

-- Gamepad UI action bar size. Edit Mode has no size option for it, so scale
-- Blizzard's frame directly (tested in game: SetScale works on it).
ns.PAD_SCALE_MIN, ns.PAD_SCALE_MAX = 0.5, 2

function ns.GamepadBarScale()
    local frame = _G.GamepadMainActionBarFrame
    return frame and frame:GetScale()
end

local function ApplyGamepadScale(p)
    local frame = _G.GamepadMainActionBarFrame
    if not (p and p.gamepadScale and frame) or InCombatLockdown() then return end
    if math.abs(frame:GetScale() - p.gamepadScale) > 0.001 then frame:SetScale(p.gamepadScale) end
end

-- The Gamepad UI bars load on demand; scale them once they exist.
local padWatcher = CreateFrame("Frame")
padWatcher:RegisterEvent("ADDON_LOADED")
padWatcher:SetScript("OnEvent", function(_, _, name)
    if name == "Blizzard_GamepadActionBars" then ApplyGamepadScale(ns.GetProfile(ns.lastAppliedID)) end
end)

---------------------------------------------------------------------------
-- Edit Mode layout, matched by name ignoring case and colour codes
---------------------------------------------------------------------------

local function Clean(text)
    return text and strtrim(ns.StripColors(text)):lower() or ""
end

function ns.GetLayoutNames()
    if not EditModeManagerFrame then C_AddOns.LoadAddOn("Blizzard_EditMode") end
    local names = {}
    local layouts = EditModeManagerFrame and EditModeManagerFrame:GetLayouts() or {}
    for _, info in ipairs(layouts) do names[#names + 1] = info.layoutName end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

local lastLayout

local function ApplyLayout(name, triesLeft)
    if not name or name == "" then return end
    local want = Clean(name)
    if not EditModeManagerFrame then C_AddOns.LoadAddOn("Blizzard_EditMode") end
    local active = C_EditMode.GetActiveLayoutInfo and C_EditMode.GetActiveLayoutInfo()
    if active and Clean(active.layoutName) == want then
        lastLayout = want
        return
    end
    if lastLayout == want and not active then return end
    local layouts = EditModeManagerFrame and EditModeManagerFrame:GetLayouts()
    for i, info in ipairs(layouts or {}) do
        if Clean(info.layoutName) == want then
            EditModeManagerFrame:SelectLayout(i)
            lastLayout = want
            return
        end
    end
    -- Edit Mode may not be ready right after login.
    triesLeft = triesLeft or 3
    if triesLeft > 0 then
        C_Timer.After(1, function() ApplyLayout(name, triesLeft - 1) end)
    else
        ns.Print("Could not find Edit Mode layout '" .. name .. "'.")
    end
end

---------------------------------------------------------------------------
-- Addon profiles
---------------------------------------------------------------------------

local function Contains(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

local loadedProfiles = {} -- each addon's profile before our first switch this session

-- Returns the labels of addons now on a different profile than at load (they need a reload).
local function ApplyAddonProfiles(p)
    local changed = {}
    for _, t in ipairs(ns.GetTargets()) do
        local want = p.addonProfiles and p.addonProfiles[t.key]
        if loadedProfiles[t.key] == nil then loadedProfiles[t.key] = t.current() or false end
        if want and t.current() ~= want then
            if Contains(t.profiles(), want) then
                local ok, err = pcall(t.set, want)
                if not ok then ns.Print(t.label .. ": profile switch failed: " .. tostring(err)) end
            else
                ns.Print(t.label .. ": profile '" .. want .. "' no longer exists, skipped.")
            end
        end
        if (t.current() or false) ~= loadedProfiles[t.key] then changed[#changed + 1] = t.label end
    end
    return changed
end

---------------------------------------------------------------------------
-- Apply
---------------------------------------------------------------------------

local pending

function ns.Apply(profile, verbose, force)
    if InCombatLockdown() then
        pending = { id = profile.id, verbose = verbose, force = force }
        if verbose then ns.Print("In combat: switching to '" .. profile.name .. "' after combat.") end
        return
    end
    pending = nil
    local identityChanged = profile.id ~= ns.lastAppliedID
    ns.lastAppliedID = profile.id
    if ns.loadedStyle == nil then ns.loadedStyle = GetCVar("InputDeviceInterfaceStyle") or false end
    ApplyDisplay(profile, verbose)
    ApplyScale(profile)
    ApplyGamepad(profile)
    ApplyGamepadScale(profile)
    ApplyLayout(profile.layout)
    if identityChanged or force then
        local other = {}
        -- shortcut: assumes Forever's Gamepad UI needs a reload to rebuild; drop this if it switches live.
        if ns.HasGamepadUI() and GetCVar("InputDeviceInterfaceStyle") ~= ns.loadedStyle then
            other[#other + 1] = "Gamepad UI"
        end
        local switched = ApplyAddonProfiles(profile)
        if #switched > 0 then other[#other + 1] = "Addon profiles: " .. table.concat(switched, ", ") end
        ns.ApplyAddonSet(profile, verbose)
        ns.UpdateReload(profile.name, other)
    end
    ns.Changed()
end

function ns.RunPending()
    if not pending then return end
    local p = ns.GetProfile(pending.id)
    local verbose, force = pending.verbose, pending.force
    pending = nil
    if p then ns.Apply(p, verbose, force) end
end
