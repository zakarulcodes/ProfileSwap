-- Main window: title bar, sidebar tabs, page host, footer, What's New.
local _, ns = ...

local WHATS_NEW = {
    "|cffffffffv1.0.0|r  (first release)",
    "- One profile per device: display mode and resolution, Edit Mode layout, UI scale.",
    "- Controller + Gamepad UI on/off, and the size of the Gamepad UI buttons.",
    "- AddOn sets with groups and search, applied per profile.",
    "- Switch other addons' profiles: EllesmereUI, Naowh Forever, AceDB addons.",
    "- Auto mode picks the profile for your screen resolution.",
    "- On-screen picker, placed and anchored through Edit Mode.",
    "- Options > AddOns page with a Switch button per profile, for controllers.",
    "- Reload popup that lists what changed; switching back cancels it.",
}

local window, pageHost, currentPage
local pages, order, tabs = {}, {}, {}

-- build(host) returns the page frame; refresh(frame) updates it.
function ns.RegisterPage(name, build, refresh)
    pages[name] = { build = build, refresh = refresh }
    order[#order + 1] = name
end

local function RefreshPage()
    if not window or not window:IsShown() or not currentPage then return end
    local page = pages[currentPage]
    if page.frame and page.refresh then page.refresh(page.frame) end
end
ns.RefreshPage = RefreshPage

local function ShowPage(name)
    currentPage = name
    for pageName, page in pairs(pages) do
        if pageName == name then
            if not page.frame then
                page.frame = page.build(pageHost)
                page.frame:SetAllPoints(pageHost)
            end
            page.frame:Show()
        elseif page.frame then
            page.frame:Hide()
        end
    end
    for pageName, tab in pairs(tabs) do tab:SetCurrent(pageName == name) end
    RefreshPage()
end

---------------------------------------------------------------------------
-- What's New
---------------------------------------------------------------------------

local whatsNew
local function ToggleWhatsNew()
    if not whatsNew then
        local f = ns.Card(window, "card", 0.98)
        f:SetSize(480, 440)
        f:SetPoint("CENTER", window, "CENTER", 36, 12)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        ns.Themed(function()
            local c = ns.Theme().accent
            f:SetBackdropBorderColor(c[1], c[2], c[3], 0.85)
        end)
        local title = ns.Text(f, "What's New - v" .. ns.VERSION, "GameFontNormalLarge", 1, 1, 1)
        title:SetPoint("TOPLEFT", 18, -16)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 18, -48)
        scroll:SetPoint("BOTTOMRIGHT", -32, 16)
        local body = CreateFrame("Frame", nil, scroll)
        body:SetSize(420, 1)
        scroll:SetScrollChild(body)
        local text = ns.Text(body, table.concat(WHATS_NEW, "\n"), "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT")
        text:SetWidth(420)
        text:SetSpacing(3)
        body:SetHeight(text:GetStringHeight() + 8)
        f:Hide()
        whatsNew = f
        window:HookScript("OnHide", function() f:Hide() end)
    end
    whatsNew:SetShown(not whatsNew:IsShown())
end

---------------------------------------------------------------------------
-- Footer
---------------------------------------------------------------------------

local function PatchStatus()
    local version, _, _, toc = GetBuildInfo()
    for _, supported in ipairs(ns.SUPPORTED_INTERFACE) do
        if supported == toc then return version, true end
    end
    return version, false
end

local function BuildFooter(w)
    local footer = CreateFrame("Frame", nil, w)
    footer:SetPoint("BOTTOMLEFT", 14, 10)
    footer:SetPoint("BOTTOMRIGHT", -14, 10)
    footer:SetHeight(36)

    local credit = ns.Text(footer, "v" .. ns.VERSION .. "   by " .. ns.AUTHOR, "GameFontDisableSmall", 0.6, 0.65, 0.72)
    credit:SetPoint("LEFT")

    local patchHolder = CreateFrame("Frame", nil, footer)
    patchHolder:SetPoint("LEFT", credit, "RIGHT", 14, 0)
    patchHolder:SetSize(140, 20)
    local patch = ns.Text(patchHolder, "", "GameFontDisableSmall")
    patch:SetPoint("LEFT")
    local version, inDate = PatchStatus()
    patch:SetText("Patch " .. version)
    if inDate then patch:SetTextColor(0.45, 0.82, 0.45) else patch:SetTextColor(0.95, 0.62, 0.28) end
    patchHolder:EnableMouse(true)
    patchHolder:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if inDate then
            GameTooltip:SetText("In date. This addon supports " .. version .. ".", 1, 1, 1, true)
        else
            GameTooltip:SetText("Out of date. You are on " .. version .. "; this addon was made for WoW Forever.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    patchHolder:SetScript("OnLeave", GameTooltip_Hide)

    local whatsNewButton = ns.Button(footer, 130, 26, "What's New?", ToggleWhatsNew)
    whatsNewButton:SetPoint("RIGHT")
    local plain = ns.Button(footer, 56, 26, "Plain", function() ns.SetSkin("Plain") end)
    plain:SetPoint("RIGHT", whatsNewButton, "LEFT", -8, 0)
    local neon = ns.Button(footer, 56, 26, "Neon", function() ns.SetSkin("Neon") end)
    neon:SetPoint("RIGHT", plain, "LEFT", -4, 0)
    local skinLabel = ns.Text(footer, "Skin:", "GameFontDisableSmall", 0.6, 0.65, 0.72)
    skinLabel:SetPoint("RIGHT", neon, "LEFT", -6, 0)
    ns.OnChange(function()
        plain:SetCurrent(ns.DB().skin == "Plain")
        neon:SetCurrent(ns.DB().skin == "Neon")
    end)
    plain:SetCurrent(ns.DB().skin == "Plain")
    neon:SetCurrent(ns.DB().skin == "Neon")
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function SavePosition(w)
    ns.DB().window = { x = w:GetLeft(), y = w:GetTop() }
end

local function BuildWindow()
    local w = ns.Card(UIParent)
    window = w
    w:SetSize(920, 760)
    w:SetFrameStrata("HIGH")
    w:SetClampedToScreen(true)
    w:EnableMouse(true)
    w:SetMovable(true)
    _G.ProfileSwapWindow = w
    tinsert(UISpecialFrames, "ProfileSwapWindow") -- Escape closes
    local pos = ns.DB().window
    if pos then
        w:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        w:SetPoint("CENTER")
    end

    -- title bar (drag handle)
    local bar = CreateFrame("Frame", nil, w)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(44)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() w:StartMoving() end)
    bar:SetScript("OnDragStop", function() w:StopMovingOrSizing(); SavePosition(w) end)
    local icon = bar:CreateTexture(nil, "ARTWORK")
    icon:SetSize(26, 26)
    icon:SetPoint("LEFT", 14, 0)
    icon:SetTexture(ns.ICON)
    local title = ns.Text(bar, ns.TITLE, "GameFontNormalLarge", 1, 1, 1)
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    local divider = bar:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", 10, 0)
    divider:SetPoint("BOTTOMRIGHT", -10, 0)
    ns.Themed(function()
        local c = ns.Theme().cardBorder
        divider:SetColorTexture(c[1], c[2], c[3], 0.8)
    end)

    -- sidebar
    local sidebar = ns.Card(w, "sidebar")
    sidebar:SetPoint("TOPLEFT", 0, -44)
    sidebar:SetPoint("BOTTOMLEFT", 0, 46)
    sidebar:SetWidth(160)
    for i, name in ipairs(order) do
        local tab = ns.Button(sidebar, 140, 34, name == "Sets" and "AddOn Sets" or name, function() ShowPage(name) end)
        tab:SetPoint("TOP", 0, -12 - (i - 1) * 42)
        tabs[name] = tab
    end

    pageHost = CreateFrame("Frame", nil, w)
    pageHost:SetPoint("TOPLEFT", 172, -44)
    pageHost:SetPoint("BOTTOMRIGHT", -14, 46)

    BuildFooter(w)
    w:SetScript("OnShow", RefreshPage)
    w:Hide()
end

function ns.OpenWindow(name)
    if not window then BuildWindow() end
    name = name or currentPage or "Overview"
    if window:IsShown() and currentPage == name then
        window:Hide()
        return
    end
    window:Show()
    ShowPage(name)
end

ns.OnChange(RefreshPage)
