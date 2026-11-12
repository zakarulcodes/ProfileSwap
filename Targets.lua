-- Addons whose own profiles ProfileSwap can switch.
-- Each target: key, label, profiles() -> sorted names, current() -> name, set(name).
local _, ns = ...

local function SortedKeys(set)
    local list = {}
    for k in pairs(set or {}) do list[#list + 1] = k end
    table.sort(list, function(a, b) return a:lower() < b:lower() end)
    return list
end

local function StripColors(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
ns.StripColors = StripColors

-- AceDB keeps no name, and addons can't read another TOC's SavedVariables line,
-- so find the global that holds db.sv (one _G scan per new database, cached).
local varOf = setmetatable({}, { __mode = "k" })
local function SavedVarName(db)
    if varOf[db] == nil then
        varOf[db] = false
        for name, value in pairs(_G) do
            if value == db.sv and type(name) == "string" then varOf[db] = name break end
        end
    end
    return varOf[db] or nil
end

-- Label a database by the loaded addon whose folder name is the longest prefix
-- of its variable (BigWigs3DB -> BigWigs, QuestieConfig -> Questie).
local function LabelFor(var)
    local best, bestLen = nil, 0
    local lowerVar = var:lower()
    for i = 1, C_AddOns.GetNumAddOns() do
        local name, title = C_AddOns.GetAddOnInfo(i)
        if #name > bestLen and lowerVar:sub(1, #name) == name:lower() and C_AddOns.IsAddOnLoaded(i) then
            best = (title and title ~= "") and StripColors(title) or name
            bestLen = #name
        end
    end
    return best or var
end

function ns.GetTargets()
    local targets = {}

    -- Addons that follow the Wago LibAddonProfiles shape.
    local EUI = _G.EllesmereUI
    if EUI and EUI.GetProfileKeys and EUI.SwitchProfile then
        targets[#targets + 1] = {
            key = "EllesmereUI", label = "EllesmereUI",
            profiles = function() return SortedKeys(EUI.GetProfileKeys()) end,
            current = function() return EUI.GetCurrentProfileKey and EUI.GetCurrentProfileKey() end,
            set = function(name) EUI.SwitchProfile(name) end,
        }
    end
    local NF = _G.NaowhForever_API
    if NF and NF.GetProfileKeys and NF.SetProfile then
        targets[#targets + 1] = {
            key = "NaowhForever", label = "Naowh Forever",
            profiles = function() return SortedKeys(NF:GetProfileKeys()) end,
            current = function() return NF:GetCurrentProfileKey() end,
            set = function(name) NF:SetProfile(name) end,
        }
    end

    -- Every loaded AceDB-3.0 database (BigWigs, Questie, Zygor, ...).
    local AceDB = LibStub and LibStub("AceDB-3.0", true)
    if AceDB and AceDB.db_registry then
        for db in pairs(AceDB.db_registry) do
            local var = not db.parent and db.sv and db.GetProfiles and SavedVarName(db) -- namespaces follow their parent
            if var then
                targets[#targets + 1] = {
                    key = "ace:" .. var, label = LabelFor(var),
                    profiles = function()
                        local list = db:GetProfiles({})
                        table.sort(list, function(a, b) return a:lower() < b:lower() end)
                        return list
                    end,
                    current = function() return db:GetCurrentProfile() end,
                    set = function(name) db:SetProfile(name) end,
                }
            end
        end
    end

    table.sort(targets, function(a, b) return a.label:lower() < b.label:lower() end)
    return targets
end
