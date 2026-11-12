-- Reload: pending indicator, tooltip details, popup, executing the reload.
local _, ns = ...

local MAX_LINES = 12

function ns.ReloadStar()
    return ns.pendingReload and " |cffff3030*|r" or ""
end

function ns.ExecuteReload()
    local reload = (C_UI and C_UI.Reload) or ReloadUI
    if not reload then
        ns.Print("Type /reload to finish.")
        return
    end
    ns.Print("Reloading UI...")
    local ok, err = pcall(reload)
    if not ok then ns.Print("Reload failed: " .. tostring(err)) end
end

-- Over MAX_LINES changes: fold each group into "<Parent> (+N dependencies)".
local function Collapse(changes)
    local buckets, order = {}, {}
    for _, c in ipairs(changes) do
        local key = ns.GroupKeyOf(c.name) .. (c.enable and "+" or "-")
        local b = buckets[key]
        if not b then
            b = { group = ns.GroupKeyOf(c.name), enable = c.enable, count = 0, hasParent = false }
            buckets[key] = b
            order[#order + 1] = b
        end
        b.count = b.count + 1
        if c.name == b.group then b.hasParent = true end
    end
    local lines = {}
    for _, b in ipairs(order) do
        local title = ns.AddonTitle(b.group)
        local extra = b.count - (b.hasParent and 1 or 0)
        if b.count > 1 and extra > 0 then
            title = string.format("%s (+%d %s)", title, extra, extra == 1 and "dependency" or "dependencies")
        end
        lines[#lines + 1] = { title = title, enable = b.enable }
    end
    table.sort(lines, function(a, b)
        if a.enable ~= b.enable then return a.enable end
        return a.title:lower() < b.title:lower()
    end)
    return lines
end

function ns.AddPendingReloadTooltip(tooltip)
    local info = ns.pendingReload
    if not info then return end
    tooltip:AddLine(" ")
    tooltip:AddLine("* UI reload required", 1, 0.19, 0.19)
    tooltip:AddLine("Profile: " .. info.profileName, 0.85, 0.85, 0.85)
    for _, reason in ipairs(info.other) do
        tooltip:AddLine("~ " .. reason, 1, 0.82, 0.3)
    end
    if info.setName then tooltip:AddLine("AddOn Set: " .. info.setName, 0.85, 0.85, 0.85) end
    local lines = info.changes
    if #lines > MAX_LINES then lines = Collapse(lines) end
    for i = 1, math.min(#lines, MAX_LINES) do
        local c = lines[i]
        if c.enable then
            tooltip:AddLine("+ Enable: " .. c.title, 0.35, 1, 0.45)
        else
            tooltip:AddLine("- Disable: " .. c.title, 1, 0.45, 0.45)
        end
    end
    if #lines > MAX_LINES then
        tooltip:AddLine("... and " .. (#lines - MAX_LINES) .. " more", 0.6, 0.6, 0.6)
    end
    tooltip:AddLine("Middle-click to reload now", 0.9, 0.8, 0.4)
end

---------------------------------------------------------------------------
-- Popup
---------------------------------------------------------------------------

local popup

local function BuildPopup()
    local f = CreateFrame("Frame", "ProfileSwapReloadPopup", UIParent, "BackdropTemplate")
    f:SetSize(400, 190)
    f:SetPoint("CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -18)
    title:SetText(ns.TITLE .. " - Reload Required")

    f.message = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.message:SetSize(360, 90)
    f.message:SetPoint("TOP", 0, -40)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local later = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    later:SetSize(120, 25)
    later:SetPoint("BOTTOMLEFT", 40, 20)
    later:SetText("Later")
    later:SetScript("OnClick", function() f:Hide() end)

    local reload = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reload:SetSize(120, 25)
    reload:SetPoint("BOTTOMRIGHT", -40, 20)
    reload:SetText("Reload UI")
    reload:SetScript("OnClick", ns.ExecuteReload)

    f:Hide()
    return f
end

function ns.ShowReloadPopup(profileName)
    popup = popup or BuildPopup()
    local why = {}
    local info = ns.pendingReload
    if info then
        for _, reason in ipairs(info.other) do why[#why + 1] = reason end
        local on, off = 0, 0
        for _, c in ipairs(info.changes) do
            if c.enable then on = on + 1 else off = off + 1 end
        end
        if on + off > 0 then why[#why + 1] = string.format("AddOns: %d to enable, %d to disable", on, off) end
    end
    popup.message:SetText("Profile '" .. profileName .. "' applied. Reload the UI to finish.\n|cffffd200"
        .. table.concat(why, "\n") .. "|r")
    popup:Show()
    popup:Raise()
end

function ns.HideReloadPopup()
    if popup then popup:Hide() end
end

-- Combines the addon set changes (ns.addonReload) with other reload reasons
-- from the profile switch, then shows or hides the popup.
function ns.UpdateReload(profileName, other)
    local addons = ns.addonReload
    if addons or #other > 0 then
        ns.pendingReload = {
            profileName = profileName,
            other = other,
            setName = addons and addons.setName,
            changes = addons and addons.changes or {},
        }
        ns.ShowReloadPopup(profileName)
    else
        ns.pendingReload = nil
        ns.HideReloadPopup()
    end
end
