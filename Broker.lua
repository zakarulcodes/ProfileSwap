-- LibDataBroker entry for Titan Panel, Bazooka, ChocolateBar and similar bars.
local _, ns = ...

local LDB = LibStub("LibDataBroker-1.1", true)
if not LDB then return end

local broker = LDB:NewDataObject(ns.TITLE, {
    type = "data source",
    label = ns.TITLE,
    text = ns.TITLE,
    icon = ns.ICON,
    category = "Interface",
    OnClick = function(frame, mouse)
        if mouse == "RightButton" then
            ns.OpenWindow("Profiles")
        elseif mouse == "MiddleButton" then
            ns.ExecuteReload()
        else
            MenuUtil.CreateContextMenu(frame, function(_, root)
                root:CreateTitle(ns.TITLE)
                root:CreateRadio("Auto (by resolution)",
                    function() return ns.DB().manual == nil end,
                    function() ns.SelectProfile(nil, true) end)
                for _, p in ipairs(ns.SortedProfiles()) do
                    root:CreateRadio(p.name,
                        function() return ns.DB().manual == p.id end,
                        function() ns.SelectProfile(p.id, true) end)
                end
            end)
        end
    end,
    OnTooltipShow = function(tooltip)
        ns.FillTooltip(tooltip, false)
    end,
})

ns.OnChange(function()
    if ns.DB() then broker.text = ns.PickerLabel() .. ns.ReloadStar() end
end)
