-- Profiles page, the profile editor overlay, and the small list popups it uses.
local _, ns = ...

local NONE = "(don't change)"
local page, editor

StaticPopupDialogs["PROFILESWAP_DELETE_PROFILE"] = {
    text = "Delete profile \"%s\"? This cannot be undone.",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, id)
        ns.DeleteProfile(id)
        if editor and editor.id == id then editor:Hide() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

---------------------------------------------------------------------------
-- List popup: a small scrolling column of buttons under an anchor
---------------------------------------------------------------------------

local listPopup
-- items = { {text, value} ... }
function ns.ShowListPopup(anchor, width, items, onPick)
    if not listPopup then
        local f = ns.Card(UIParent, "card", 0.98)
        f:SetFrameStrata("TOOLTIP")
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 10, -26)
        scroll:SetPoint("BOTTOMRIGHT", -28, 10)
        f.content = CreateFrame("Frame", nil, scroll)
        f.content:SetSize(1, 1)
        scroll:SetScrollChild(f.content)
        f.buttons = {}
        f:Hide()
        listPopup = f
    end
    local f = listPopup
    if f:IsShown() and f.anchor == anchor then
        f:Hide()
        return
    end
    f.anchor = anchor
    f:SetSize(width, 220)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    local bw = width - 40
    f.content:SetSize(bw, math.max(1, #items * 24))
    for i, item in ipairs(items) do
        local b = f.buttons[i]
        if not b then
            b = ns.Button(f.content, bw, 22, "")
            f.buttons[i] = b
        end
        b:SetWidth(bw)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 0, -(i - 1) * 24)
        b:SetText(item[1])
        b:SetScript("OnClick", function()
            f:Hide()
            onPick(item[2])
        end)
        b:Show()
    end
    for i = #items + 1, #f.buttons do f.buttons[i]:Hide() end
    f:Show()
end

function ns.HideListPopup()
    if listPopup then listPopup:Hide() end
end

---------------------------------------------------------------------------
-- Editor overlay
---------------------------------------------------------------------------

local function Label(parent, text, x, y)
    local fs = ns.Text(parent, text, "GameFontNormal", 0.85, 0.88, 0.92)
    fs:SetPoint("TOPLEFT", x, y)
    return fs
end

local function Box(parent, width, x, y)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetPoint("TOPLEFT", x + 6, y)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    return box
end

local function RefreshDisplayControls()
    local e, d = editor, editor.draft.display
    local resCVar = d and ns.ResolutionCVar(d)
    e.modeButton:SetText("Mode: " .. (d and ns.DisplayModeOf(d).name or NONE))
    if e.monitorButton then
        e.monitorButton:SetText("Monitor " .. (d and ((tonumber(d.gxMonitor) or 0) + 1) or "-"))
        e.monitorButton:SetEnabledState(d ~= nil)
    end
    if not resCVar then
        e.resButton:SetText("Resolution: -")
        e.resButton:SetEnabledState(false)
        e.customRes:Hide()
        return
    end
    local value = d[resCVar] or "auto"
    e.resButton:SetText("Resolution: " .. (e.customMode and "Custom" or (value == "auto" and "Default" or value)))
    e.resButton:SetEnabledState(true)
    e.customRes:SetShown(e.customMode)
    if e.customMode and not e.customRes:HasFocus() then
        e.customRes:SetText(value ~= "auto" and value or "")
    end
end

local function RefreshDraftTexts()
    local d = editor.draft
    editor.setValue:SetText(d.addonSet or "None")
    editor.displayValue:SetText(d.display and ns.DisplayText(d.display) or "None")
    RefreshDisplayControls()
    local targets = ns.GetTargets()
    for i, t in ipairs(targets) do
        local row = editor.targetRows[i]
        if not row then
            row = CreateFrame("Frame", nil, editor.targetContent)
            row:SetSize(580, 24)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
            row.label = ns.Text(row, "", "GameFontHighlight")
            row.label:SetPoint("LEFT", 4, 0)
            row.label:SetWidth(300)
            row.button = ns.Button(row, 240, 22, "")
            row.button:SetPoint("RIGHT", -4, 0)
            editor.targetRows[i] = row
        end
        row.label:SetText(t.label)
        row.button:SetText(d.addonProfiles[t.key] or NONE)
        row.button:SetScript("OnClick", function(btn)
            local items = { { NONE, false } }
            for _, name in ipairs(t.profiles()) do items[#items + 1] = { name, name } end
            ns.ShowListPopup(btn, 260, items, function(value)
                d.addonProfiles[t.key] = value or nil
                RefreshDraftTexts()
            end)
        end)
        row:Show()
    end
    for i = #targets + 1, #editor.targetRows do editor.targetRows[i]:Hide() end
    editor.targetContent:SetHeight(math.max(1, #targets * 26))
    editor.noTargets:SetShown(#targets == 0)
end

local function FillForm(profile)
    local e = editor
    e.id = profile and profile.id
    e.title:SetText(profile and "Edit Profile" or "New Profile")
    e.subtitle:SetText(profile and ("Editing  •  " .. profile.name) or "Fill in the fields below, then Save.")
    e.name:SetText(profile and profile.name or "")
    e.res:SetText(profile and profile.resolution or ns.CurrentResolution())
    e.layout:SetText(profile and profile.layout or "")
    e.scale:SetValue(profile and profile.scale or tonumber(GetCVar("uiScale")) or 1)
    e.padScale:SetValue(profile and profile.gamepadScale or ns.GamepadBarScale() or 1)
    e.suppress:SetChecked(profile and profile.suppressChat or false)
    if profile and profile.gamepad ~= nil then
        e.gamepad:SetChecked(profile.gamepad)
    else
        e.gamepad:SetChecked(ns.IsGamepadOn())
    end
    e.auto:SetChecked(ns.IsAutoProfile(profile) and true or false)
    e.draft = {
        addonSet = profile and profile.addonSet,
        display = profile and profile.display and CopyTable(profile.display),
        addonProfiles = profile and CopyTable(profile.addonProfiles or {}) or {},
    }
    -- a saved resolution the monitor list does not offer opens in the Custom box
    local d = e.draft.display
    local cvar = d and ns.ResolutionCVar(d)
    e.customMode = false
    if cvar and d[cvar] and d[cvar] ~= "auto" then
        e.customMode = not tContains(ns.SupportedResolutions(d), d[cvar])
    end
    e.deleteButton:SetShown(profile ~= nil)
    RefreshDraftTexts()
end

local function Save()
    local e = editor
    e.customRes:ClearFocus() -- commits a typed resolution before saving
    local name = strtrim(e.name:GetText() or "")
    if name == "" then
        ns.Print("Please enter a profile name (e.g. PC or Steam Deck).")
        return
    end
    local res = strtrim(e.res:GetText() or "")
    if res == "" then res = ns.CurrentResolution() end
    local db = ns.DB()
    local p = ns.GetProfile(e.id)
    if not p then
        p = { id = ns.NewProfileID(), addonProfiles = {}, migrated = true }
        db.profiles[p.id] = p
        e.id = p.id
    end
    local layout = strtrim(e.layout:GetText() or "")
    p.name = name
    p.resolution = res
    p.layout = layout ~= "" and layout or nil
    p.scale = tonumber(string.format("%.2f", e.scale:GetValue()))
    p.gamepadScale = tonumber(string.format("%.2f", e.padScale:GetValue()))
    p.suppressChat = e.suppress:GetChecked() and true or false
    p.gamepad = e.gamepad:GetChecked() and true or false
    ns.RememberGamepadStyle()
    p.addonSet = e.draft.addonSet
    p.display = e.draft.display
    p.addonProfiles = e.draft.addonProfiles

    for r, id in pairs(db.autoByRes) do
        if id == p.id and r ~= res then db.autoByRes[r] = nil end
    end
    if e.auto:GetChecked() then
        db.autoByRes[res] = p.id
    elseif db.autoByRes[res] == p.id then
        db.autoByRes[res] = nil
    end

    ns.Print("Saved profile '" .. name .. "'.")
    ns.Changed()
    e.blocker:Hide()
end

local function BuildEditor()
    local blocker = CreateFrame("Frame", "ProfileSwapEditor", UIParent)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("FULLSCREEN_DIALOG")
    blocker:SetFrameLevel(90)
    blocker:EnableMouse(true)
    local dim = blocker:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, 0.55)
    tinsert(UISpecialFrames, "ProfileSwapEditor") -- Escape closes
    blocker:SetScript("OnHide", ns.HideListPopup)

    local e = ns.Card(blocker, "card", 0.98)
    editor = e
    e.blocker = blocker
    e:SetSize(660, 706)
    e:SetPoint("CENTER")
    e:SetFrameLevel(100)
    e:EnableMouse(true)
    local close = CreateFrame("Button", nil, e, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() blocker:Hide() end)

    e.title = ns.Text(e, "", "GameFontNormalLarge", 1, 1, 1)
    e.title:SetPoint("TOPLEFT", 24, -18)
    e.subtitle = ns.Text(e, "", "GameFontHighlightSmall", 0.75, 0.8, 0.85)
    e.subtitle:SetPoint("TOPLEFT", 24, -42)

    Label(e, "Profile Name", 28, -72)
    e.name = Box(e, 220, 28, -92)

    Label(e, "Resolution hint (e.g. 1920x1080)", 28, -122)
    e.res = Box(e, 140, 28, -142)
    local useCurrent = ns.Button(e, 110, 22, "Use Current", function()
        e.res:SetText(ns.CurrentResolution())
        e.res:ClearFocus()
    end)
    useCurrent:SetPoint("LEFT", e.res, "RIGHT", 10, 0)
    e.auto = CreateFrame("CheckButton", nil, e, "ChatConfigCheckButtonTemplate")
    e.auto:SetPoint("LEFT", useCurrent, "RIGHT", 12, 0)
    if e.auto.Text then e.auto.Text:SetText("Automatic for this resolution") end

    Label(e, "Edit Mode Layout Name", 28, -172)
    e.layout = Box(e, 260, 28, -192)
    local pickLayout = ns.Button(e, 110, 22, "Pick Layout")
    pickLayout:SetPoint("LEFT", e.layout, "RIGHT", 10, 0)
    pickLayout:SetScript("OnClick", function(btn)
        local names = ns.GetLayoutNames()
        if #names == 0 then
            ns.Print("No Edit Mode layouts found. Save one in Edit Mode first.")
            return
        end
        local items = {}
        for _, n in ipairs(names) do items[#items + 1] = { n, n } end
        ns.ShowListPopup(btn, 220, items, function(value) e.layout:SetText(value) end)
    end)

    e.scale = CreateFrame("Slider", nil, e, "OptionsSliderTemplate")
    e.scale:SetSize(200, 17)
    e.scale:SetPoint("TOPLEFT", 420, -194)
    e.scale:SetMinMaxValues(ns.SCALE_MIN, ns.SCALE_MAX)
    e.scale:SetValueStep(0.01)
    e.scale:SetObeyStepOnDrag(true)
    local scaleText = ns.Text(e, "", "GameFontNormal", 0.85, 0.88, 0.92)
    scaleText:SetPoint("TOP", e.scale, "BOTTOM", 0, -4)
    e.scale:SetScript("OnValueChanged", function(_, value)
        scaleText:SetText(string.format("UI Scale: %.2f", value))
    end)

    e.suppress = CreateFrame("CheckButton", nil, e, "ChatConfigCheckButtonTemplate")
    e.suppress:SetPoint("TOPLEFT", 24, -236)
    if e.suppress.Text then e.suppress.Text:SetText("Suppress 'layout applied' chat messages") end
    e.gamepad = CreateFrame("CheckButton", nil, e, "ChatConfigCheckButtonTemplate")
    e.gamepad:SetPoint("TOPLEFT", 416, -236)
    if e.gamepad.Text then
        e.gamepad.Text:SetText(ns.HasGamepadUI() and "Controller + Gamepad UI on" or "Controller on")
    end

    e.padScale = CreateFrame("Slider", nil, e, "OptionsSliderTemplate")
    e.padScale:SetSize(200, 17)
    e.padScale:SetPoint("TOPLEFT", 420, -270)
    e.padScale:SetMinMaxValues(ns.PAD_SCALE_MIN, ns.PAD_SCALE_MAX)
    e.padScale:SetValueStep(0.05)
    e.padScale:SetObeyStepOnDrag(true)
    local padScaleText = ns.Text(e, "", "GameFontNormal", 0.85, 0.88, 0.92)
    padScaleText:SetPoint("TOP", e.padScale, "BOTTOM", 0, -4)
    e.padScale:SetScript("OnValueChanged", function(_, value)
        padScaleText:SetText(string.format("Gamepad UI buttons size: %.2f", value))
    end)
    ns.Tooltip(e.padScale, "Gamepad UI buttons size", "Size of the Gamepad UI's on-screen button wheel. Edit Mode has no size option for it.")

    -- AddOn set
    Label(e, "AddOn Set", 28, -316)
    e.setValue = ns.Text(e, "", "GameFontHighlight", 1, 1, 1)
    e.setValue:SetPoint("TOPLEFT", 28, -338)
    e.setValue:SetWidth(170)
    local pickSet = ns.Button(e, 110, 22, "Pick Set")
    pickSet:SetPoint("TOPLEFT", 214, -334)
    pickSet:SetScript("OnClick", function(btn)
        local items = { { "None", false } }
        for _, n in ipairs(ns.SortedSetNames()) do items[#items + 1] = { n, n } end
        ns.ShowListPopup(btn, 240, items, function(value)
            e.draft.addonSet = value or nil
            RefreshDraftTexts()
        end)
    end)
    local noSet = ns.Button(e, 70, 22, "None", function()
        e.draft.addonSet = nil
        RefreshDraftTexts()
    end)
    noSet:SetPoint("LEFT", pickSet, "RIGHT", 6, 0)
    local manage = ns.Button(e, 110, 22, "Manage Sets", function()
        blocker:Hide()
        ns.OpenWindow("Sets")
    end)
    manage:SetPoint("LEFT", noSet, "RIGHT", 6, 0)

    -- Display
    Label(e, "Display", 28, -372)
    e.displayValue = ns.Text(e, "", "GameFontHighlight", 1, 1, 1)
    e.displayValue:SetPoint("TOPLEFT", 28, -394)
    e.displayValue:SetWidth(170)

    -- A new display setting starts from the current one.
    local function EnsureDisplay()
        if not e.draft.display then e.draft.display = ns.CaptureDisplay() end
        return e.draft.display
    end
    local function SetResolution(value)
        local d = EnsureDisplay()
        d[ns.ResolutionCVar(d)] = value
        -- keep the Auto mode hint in step with the game resolution
        if value ~= "auto" then e.res:SetText(value) end
        RefreshDraftTexts()
    end

    e.modeButton = ns.Button(e, 220, 22, "")
    e.modeButton:SetPoint("TOPLEFT", 214, -390)
    e.modeButton:SetScript("OnClick", function(btn)
        local items = { { NONE, false } }
        for _, mode in ipairs(ns.AvailableDisplayModes()) do items[#items + 1] = { mode.name, mode } end
        ns.ShowListPopup(btn, 230, items, function(mode)
            if not mode then
                e.draft.display = nil
            else
                ns.SetDisplayMode(EnsureDisplay(), mode)
            end
            e.customMode = false
            RefreshDraftTexts()
        end)
    end)
    local capture = ns.Button(e, 130, 22, "Capture Current", function()
        e.draft.display = ns.CaptureDisplay()
        e.customMode = false
        RefreshDraftTexts()
    end)
    capture:SetPoint("LEFT", e.modeButton, "RIGHT", 6, 0)
    ns.Tooltip(capture, "Capture display", "Copies the monitor, display mode and resolution the game uses right now.")
    local noDisplay = ns.Button(e, 70, 22, "None", function()
        e.draft.display = nil
        e.customMode = false
        RefreshDraftTexts()
    end)
    noDisplay:SetPoint("LEFT", capture, "RIGHT", 6, 0)
    ns.Tooltip(noDisplay, "No display change", "Switching to this profile leaves the display alone.")

    e.resButton = ns.Button(e, 220, 22, "")
    e.resButton:SetPoint("TOPLEFT", 214, -418)
    e.resButton:SetScript("OnClick", function(btn)
        local d = EnsureDisplay()
        local items = { { "Default", "auto" } }
        for _, r in ipairs(ns.SupportedResolutions(d)) do items[#items + 1] = { r, r } end
        items[#items + 1] = { "Custom...", false }
        ns.ShowListPopup(btn, 200, items, function(value)
            e.customMode = not value
            if value then
                SetResolution(value)
            else
                RefreshDraftTexts()
                e.customRes:SetFocus()
            end
        end)
    end)

    e.customRes = CreateFrame("EditBox", nil, e, "InputBoxTemplate")
    e.customRes:SetSize(100, 20)
    e.customRes:SetAutoFocus(false)
    e.customRes:SetPoint("LEFT", e.resButton, "RIGHT", 14, 0)
    local function CommitCustom(box)
        local value = ns.ParseResolution(box:GetText())
        if value then
            SetResolution(value)
        elseif strtrim(box:GetText() or "") ~= "" then
            ns.Print("Type the resolution as width x height, for example 1920x1080.")
        end
        RefreshDraftTexts()
    end
    e.customRes:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    e.customRes:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    e.customRes:SetScript("OnEditFocusLost", CommitCustom)
    ns.Tooltip(e.customRes, "Custom resolution", "Type width x height, for example 2560x1080, then press Enter.")

    local monitors = ns.MonitorItems()
    if monitors then
        e.monitorButton = ns.Button(e, 110, 22, "")
        e.monitorButton:SetPoint("LEFT", e.customRes, "RIGHT", 8, 0)
        e.monitorButton:SetScript("OnClick", function(btn)
            ns.ShowListPopup(btn, 260, monitors, function(value)
                EnsureDisplay().gxMonitor = value
                RefreshDraftTexts()
            end)
        end)
    end

    -- Addon profiles
    ns.AccentText(e, "Addon Profiles"):SetPoint("TOPLEFT", 28, -460)
    local box = ns.Card(e, "row")
    box:SetPoint("TOPLEFT", 24, -480)
    box:SetSize(612, 160)
    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    e.targetContent = CreateFrame("Frame", nil, scroll)
    e.targetContent:SetSize(580, 1)
    scroll:SetScrollChild(e.targetContent)
    e.targetRows = {}
    e.noTargets = ns.Text(box, "No loaded addons with switchable profiles.", "GameFontDisable")
    e.noTargets:SetPoint("TOPLEFT", 10, -10)

    -- bottom row
    local saveButton = ns.Button(e, 130, 28, "Save / Update", Save)
    saveButton:SetPoint("BOTTOMLEFT", 24, 20)
    local applyNow = ns.Button(e, 110, 28, "Apply Now", function()
        if ns.GetProfile(e.id) then ns.SelectProfile(e.id, true) else ns.Evaluate(true, true) end
    end)
    applyNow:SetPoint("LEFT", saveButton, "RIGHT", 8, 0)
    local clear = ns.Button(e, 110, 28, "Clear Form", function()
        local id = e.id
        FillForm(nil)
        e.id = id -- clearing the form keeps editing the same profile
        e.deleteButton:SetShown(id ~= nil)
    end)
    clear:SetPoint("LEFT", applyNow, "RIGHT", 8, 0)
    e.deleteButton = ns.Button(e, 100, 28, "Delete", function()
        local p = ns.GetProfile(e.id)
        if p then StaticPopup_Show("PROFILESWAP_DELETE_PROFILE", p.name, nil, p.id) end
    end)
    e.deleteButton:SetPoint("LEFT", clear, "RIGHT", 8, 0)
    local cancel = ns.Button(e, 90, 28, "Cancel", function() blocker:Hide() end)
    cancel:SetPoint("BOTTOMRIGHT", -24, 20)

    blocker:Hide()
end

function ns.OpenEditor(profile)
    if not editor then BuildEditor() end
    FillForm(profile)
    editor.blocker:Show()
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------

local function ProfileRow(parent)
    local row = ns.Card(parent, "row")
    row:SetHeight(64)
    row.name = ns.Text(row, "", "GameFontNormal", 1, 1, 1)
    row.name:SetPoint("TOPLEFT", 12, -8)
    row.sub = ns.Text(row, "", "GameFontHighlightSmall", 0.75, 0.8, 0.85)
    row.sub:SetPoint("BOTTOMLEFT", 12, 10)
    row.delete = ns.Button(row, 70, 22, "Delete")
    row.delete:SetPoint("RIGHT", -10, 0)
    row.edit = ns.Button(row, 60, 22, "Edit")
    row.edit:SetPoint("RIGHT", row.delete, "LEFT", -6, 0)
    row.activate = ns.Button(row, 80, 22, "Activate")
    row.activate:SetPoint("RIGHT", row.edit, "LEFT", -6, 0)
    return row
end

local function FillRow(row, p, isActive, mode)
    local name = p.name
    if ns.IsAutoProfile(p) then name = name .. "  |cff66ccffAUTO|r" end
    if isActive then name = name .. "  |cff999999(" .. (mode == "manual" and "Manual" or "Auto") .. ")|r" end
    row.name:SetText(name)
    row.sub:SetText(string.format("%s  •  Layout: %s  •  Scale: %s",
        p.resolution or "?", p.layout or "?", p.scale and string.format("%.2f", p.scale) or "default"))
    row.activate:SetText(isActive and "Active" or "Activate")
    row.activate:SetEnabledState(not isActive)
    row.activate:SetScript("OnClick", function() ns.SelectProfile(p.id, true) end)
    row.edit:SetScript("OnClick", function() ns.OpenEditor(p) end)
    row.delete:SetScript("OnClick", function()
        StaticPopup_Show("PROFILESWAP_DELETE_PROFILE", p.name, nil, p.id)
    end)
end

local function Build(host)
    page = CreateFrame("Frame", nil, host)

    ns.Text(page, "Profiles", "GameFontNormalLarge", 1, 1, 1):SetPoint("TOPLEFT", 20, -16)
    ns.Text(page, "Activate, edit or delete profiles. Changes show immediately.", "GameFontHighlightSmall", 0.75, 0.8, 0.85)
        :SetPoint("TOPLEFT", 20, -40)

    local new = ns.Button(page, 140, 32, "New Profile", function() ns.OpenEditor(nil) end)
    new:SetPoint("TOPLEFT", 20, -60)
    ns.Text(page, "Edit opens a popup editor.", "GameFontHighlightSmall", 0.65, 0.7, 0.78)
        :SetPoint("LEFT", new, "RIGHT", 12, 0)

    ns.AccentText(page, "Active Profile"):SetPoint("TOPLEFT", 20, -108)
    page.activeCard = ns.Card(page, "active")
    page.activeCard:SetPoint("TOPLEFT", 20, -128)
    page.activeCard:SetPoint("RIGHT", -16, 0)
    page.activeCard:SetHeight(80)
    page.activeRow = ProfileRow(page.activeCard)
    page.activeRow:SetPoint("TOPLEFT", 8, -8)
    page.activeRow:SetPoint("RIGHT", -8, 0)
    page.activeRow.kind = "transparent"
    page.activeRow:SetBackdropColor(0, 0, 0, 0)
    page.activeRow:SetBackdropBorderColor(0, 0, 0, 0)
    page.activeEmpty = ns.Text(page.activeCard, "No active profile. Create one, or Activate a saved profile.", "GameFontDisable")
    page.activeEmpty:SetPoint("LEFT", 16, 0)

    ns.AccentText(page, "All Profiles"):SetPoint("TOPLEFT", 20, -224)
    local listCard = ns.Card(page)
    listCard:SetPoint("TOPLEFT", 20, -244)
    listCard:SetPoint("BOTTOMRIGHT", -16, 16)
    local scroll = CreateFrame("ScrollFrame", nil, listCard, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    page.listContent = CreateFrame("Frame", nil, scroll)
    page.listContent:SetSize(1, 1)
    scroll:SetScrollChild(page.listContent)
    page.scroll = scroll
    page.rows = {}
    page.listEmpty = ns.Text(listCard, "", "GameFontDisable")
    page.listEmpty:SetPoint("TOPLEFT", 16, -16)

    return page
end

local function Refresh()
    local active, mode = ns.ResolveProfile()
    if active then
        FillRow(page.activeRow, active, true, mode)
        page.activeRow:Show()
        page.activeEmpty:Hide()
    else
        page.activeRow:Hide()
        page.activeEmpty:Show()
    end

    local width = math.max(360, page.scroll:GetWidth() - 4)
    page.listContent:SetWidth(width)
    local shown = 0
    for _, p in ipairs(ns.SortedProfiles()) do
        if p ~= active then
            shown = shown + 1
            local row = page.rows[shown]
            if not row then
                row = ProfileRow(page.listContent)
                page.rows[shown] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(shown - 1) * 72)
            row:SetWidth(width)
            FillRow(row, p, false)
            row:Show()
        end
    end
    for i = shown + 1, #page.rows do page.rows[i]:Hide() end
    page.listContent:SetHeight(math.max(1, shown * 72))
    if shown == 0 then
        page.listEmpty:SetText(next(ns.DB().profiles) and "No other profiles." or "No profiles yet. Click New Profile to create one.")
        page.listEmpty:Show()
    else
        page.listEmpty:Hide()
    end
end

ns.RegisterPage("Profiles", Build, Refresh)
