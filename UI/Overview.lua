-- Overview page: status, quick start, global options.
local _, ns = ...

local QUICK_START = table.concat({
    "1. Create a profile for each setup on the Profiles tab (e.g. PC, TV and Steam Deck).",
    "2. Build AddOn sets on the AddOn Sets tab if each setup needs different addons.",
    "3. Edit each profile: display, layout, scale, controller, set and addon profiles.",
    "4. Tick \"Automatic for this resolution\" so it switches by itself.",
    "5. Switch any time with Activate, the on-screen picker or /pswap <profile>.",
    "",
    "See What's New for changes, and the footer to change the skin.",
}, "\n")

local function Build(host)
    local page = CreateFrame("Frame", nil, host)

    local heading = ns.Text(page, "Overview", "GameFontNormalLarge", 1, 1, 1)
    heading:SetPoint("TOPLEFT", 20, -20)
    local meta = ns.Text(page, "v" .. ns.VERSION .. " · by " .. ns.AUTHOR .. " · /pswap", "GameFontHighlightSmall", 0.75, 0.8, 0.9)
    meta:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)

    local status = ns.Card(page)
    status:SetSize(700, 78)
    status:SetPoint("TOPLEFT", 20, -70)
    ns.AccentText(status, "Current Status"):SetPoint("TOPLEFT", 14, -12)
    page.statusText = ns.Text(status, "", "GameFontHighlight", 0.75, 0.8, 0.9)
    page.statusText:SetPoint("TOPLEFT", 14, -40)

    local guide = ns.Card(page)
    guide:SetSize(700, 168)
    guide:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -16)
    ns.AccentText(guide, "Quick Start"):SetPoint("TOPLEFT", 14, -12)
    local steps = ns.Text(guide, QUICK_START, "GameFontHighlightSmall", 0.85, 0.88, 0.92)
    steps:SetPoint("TOPLEFT", 14, -36)
    steps:SetWidth(670)
    steps:SetSpacing(3)

    local function Check(label, anchor, gap, get, set)
        local cb = CreateFrame("CheckButton", nil, page, "ChatConfigCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap)
        if cb.Text then cb.Text:SetText(label) end
        cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
        cb.Refresh = function() cb:SetChecked(get()) end
        return cb
    end

    page.picker = Check("Show on-screen profile picker", guide, -20,
        function() return ns.DB().picker.enabled end,
        function(v) ns.DB().picker.enabled = v; ns.Changed() end)
    page.mute = Check("Mute chat output (" .. ns.TITLE .. " only)", page.picker, -10,
        function() return ns.DB().muted end,
        function(v) ns.DB().muted = v end)
    page.pause = Check("Pause all automation", page.mute, -10,
        function() return ns.DB().paused end,
        function(v) ns.DB().paused = v; ns.Changed() end)
    local note = ns.Text(page, "While paused, login and Auto mode skip applying profiles. Activate still works, so you can keep broken addons off during addon update periods.", "GameFontHighlightSmall", 0.65, 0.7, 0.78)
    note:SetPoint("TOPLEFT", page.pause, "BOTTOMLEFT", 28, -2)
    note:SetWidth(420)

    local open = ns.Button(page, 150, 30, "Open Profiles", function() ns.OpenWindow("Profiles") end)
    open:SetPoint("LEFT", page.picker, "RIGHT", 280, 0)

    return page
end

local function Refresh(page)
    local profile, mode = ns.ResolveProfile()
    local modeText = mode == "manual" and "Manual" or (profile and "Auto" or "None")
    local text = string.format("Mode: |cffffffff%s|r    Profile: |cffffffff%s|r    Resolution: |cffffffff%s|r",
        modeText, profile and profile.name or "None", ns.CurrentResolution())
    if ns.DB().paused then text = text .. "    |cffff9f47Paused|r" end
    page.statusText:SetText(text)
    page.picker.Refresh()
    page.mute.Refresh()
    page.pause.Refresh()
end

ns.RegisterPage("Overview", Build, Refresh)
