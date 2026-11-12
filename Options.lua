-- Options > AddOns > ProfileSwap: one button per profile, so profiles can be
-- switched with a controller from the game's own settings window.
local _, ns = ...

local function Register()
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory
        and CreateSettingsButtonInitializer) then return end
    local category, layout = Settings.RegisterVerticalLayoutCategory(ns.TITLE)
    if not layout then return end

    -- shortcut: the list is built at login, so profiles made later show after a /reload.
    layout:AddInitializer(CreateSettingsButtonInitializer("Auto (by resolution)", "Switch",
        function() ns.SelectProfile(nil) end, "Pick the profile for this screen resolution.", false))
    for _, p in ipairs(ns.SortedProfiles()) do
        local id = p.id
        layout:AddInitializer(CreateSettingsButtonInitializer(p.name, "Switch",
            function() ns.SelectProfile(id) end, "Switch to this profile.", false))
    end

    do
        layout:AddInitializer(CreateSettingsButtonInitializer("", "Open ProfileSwap", function()
            if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
            ns.OpenWindow("Profiles")
        end, "", false))
    end

    Settings.RegisterAddOnCategory(category)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    local ok, err = pcall(Register)
    if not ok then ns.Print("Could not add the Options > AddOns page: " .. tostring(err)) end
end)
