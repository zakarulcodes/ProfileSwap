-- AddOn Sets page: list of sets on the left, grouped addon checklist on the right.
local _, ns = ...

local page

---------------------------------------------------------------------------
-- Popups: new / rename / delete
---------------------------------------------------------------------------

local function PopupText(popup)
    local box = popup.editBox or popup.EditBox
    return box and strtrim(box:GetText() or "") or ""
end

StaticPopupDialogs["PROFILESWAP_NEW_SET"] = {
    text = "New AddOn set name:",
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    maxLetters = 64,
    enterClicksFirstButton = true,
    OnAccept = function(self)
        local name = PopupText(self)
        if name ~= "" and ns.CreateSet(name) then
            page.selected = name
            page.workingFor = nil
            ns.RefreshPage()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["PROFILESWAP_RENAME_SET"] = {
    text = "Rename AddOn set:",
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    maxLetters = 64,
    enterClicksFirstButton = true,
    OnShow = function(self, data)
        local box = self.editBox or self.EditBox
        if box then box:SetText(data or "") box:HighlightText() end
    end,
    OnAccept = function(self, data)
        local name = PopupText(self)
        if name ~= "" and ns.RenameSet(data, name) then
            page.selected = name
            page.workingFor = name
            ns.RefreshPage()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["PROFILESWAP_DELETE_SET"] = {
    text = "Delete AddOn set \"%s\"?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, data)
        ns.DeleteSet(data)
        page.selected, page.workingFor = nil, nil
        ns.RefreshPage()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

---------------------------------------------------------------------------
-- Working copy of the selected set (saved only by "Save Set")
---------------------------------------------------------------------------

local function EnsureWorking()
    if page.workingFor ~= page.selected then
        page.working = CopyTable(page.selected and ns.DB().sets[page.selected] or {})
        page.workingFor = page.selected
    end
end

---------------------------------------------------------------------------
-- Left: set list
---------------------------------------------------------------------------

local function PaintSetRow(row)
    if row.selected then
        local c = ns.Theme().accent
        row:SetBackdropColor(c[1], c[2], c[3], 0.45)
        row:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    else
        row:SetBackdropColor(0.1, 0.12, 0.15, 0.9)
        row:SetBackdropBorderColor(0.3, 0.35, 0.4, 1)
    end
end

local function RefreshSetList()
    local names = ns.SortedSetNames()
    if not page.selected or not ns.DB().sets[page.selected] then page.selected = names[1] end
    for i, name in ipairs(names) do
        local row = page.setRows[i]
        if not row then
            row = CreateFrame("Button", nil, page.setContent, "BackdropTemplate")
            row:SetBackdrop(ns.FLAT_BACKDROP)
            row:SetSize(210, 30)
            row.label = ns.Text(row, "", "GameFontHighlight", 1, 1, 1)
            row.label:SetPoint("LEFT", 10, 0)
            row.label:SetPoint("RIGHT", -6, 0)
            page.setRows[i] = row
        end
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 34)
        row.label:SetText(name)
        row.selected = name == page.selected
        row:SetScript("OnClick", function()
            page.selected = name
            ns.RefreshPage()
        end)
        PaintSetRow(row)
        row:Show()
    end
    for i = #names + 1, #page.setRows do page.setRows[i]:Hide() end
    page.setContent:SetHeight(math.max(1, #names * 34))
    page.noSets:SetShown(#names == 0)
end

---------------------------------------------------------------------------
-- Right: new addons box
---------------------------------------------------------------------------

local function RefreshNewBox()
    local unknown = ns.UnknownAddons()
    page.newBox:SetShown(#unknown > 0)
    for i, a in ipairs(unknown) do
        local row = page.newRows[i]
        if not row then
            row = CreateFrame("Frame", nil, page.newContent)
            row:SetSize(560, 28)
            row.check = CreateFrame("CheckButton", nil, row, "ChatConfigCheckButtonTemplate")
            row.check:SetPoint("LEFT", 0, 0)
            row.label = ns.Text(row, "", "GameFontHighlight", 0.95, 0.9, 0.75)
            row.label:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
            row.dismiss = ns.Button(row, 80, 24, "Dismiss")
            row.dismiss:SetPoint("RIGHT", -4, 0)
            page.newRows[i] = row
        end
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 32)
        row.label:SetText(a.title .. "  |cff888888" .. a.name .. "|r")
        if page.selected then row.check:Enable() else row.check:Disable() end
        row.check:SetChecked(page.working[a.name] == true)
        row.check:SetScript("OnClick", function(cb)
            page.working[a.name] = cb:GetChecked() or nil
        end)
        row.dismiss:SetScript("OnClick", function()
            ns.MarkKnown(a.name)
            ns.RefreshPage()
        end)
        row:Show()
    end
    for i = #unknown + 1, #page.newRows do page.newRows[i]:Hide() end
    page.newContent:SetHeight(math.max(1, #unknown * 32))
    return #unknown > 0
end

---------------------------------------------------------------------------
-- Right: grouped checklist
---------------------------------------------------------------------------

local function GetHeader(i)
    local h = page.headers[i]
    if h then return h end
    h = CreateFrame("Button", nil, page.listContent, "BackdropTemplate")
    h:SetBackdrop(ns.FLAT_BACKDROP)
    h:SetBackdropColor(0.16, 0.19, 0.24, 0.95)
    h:SetBackdropBorderColor(0.16, 0.19, 0.24, 0.95)
    h:SetHeight(30)
    h.arrow = ns.AccentText(h, "-", "GameFontNormalLarge")
    h.arrow:SetPoint("LEFT", 8, 0)
    h.check = CreateFrame("CheckButton", nil, h, "ChatConfigCheckButtonTemplate")
    h.check:SetPoint("LEFT", 28, 0)
    h.label = ns.Text(h, "", "GameFontHighlight", 1, 1, 1)
    h.label:SetPoint("LEFT", h.check, "RIGHT", 4, 0)
    page.headers[i] = h
    return h
end

local function GetRow(i)
    local r = page.addonRows[i]
    if r then return r end
    r = CreateFrame("CheckButton", nil, page.listContent, "ChatConfigCheckButtonTemplate")
    r:SetSize(26, 26)
    r.label = ns.Text(r, "", "GameFontHighlight", 1, 1, 1)
    r.label:SetPoint("LEFT", r, "RIGHT", 4, 0)
    page.addonRows[i] = r
    return r
end

local function RefreshChecklist()
    local search = strtrim(page.search:GetText() or ""):lower()
    local editable = page.selected ~= nil
    local known = ns.DB().known
    local addons = {}
    for _, a in ipairs(ns.InstalledAddons()) do
        local matches = search == "" or a.title:lower():find(search, 1, true) or a.name:lower():find(search, 1, true)
        if not ns.IsProtected(a.name) and known[a.name] and matches then addons[#addons + 1] = a end
    end

    local y, hi, ri = 0, 0, 0
    local width = math.max(300, page.listScroll:GetWidth() - 4)
    page.listContent:SetWidth(width)
    for _, g in ipairs(ns.GroupAddons(addons)) do
        local checked = 0
        for _, m in ipairs(g.members) do
            if page.working[m.name] then checked = checked + 1 end
        end
        local open = search ~= "" or not ns.DB().collapsed[g.key]

        hi = hi + 1
        local h = GetHeader(hi)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 0, -y)
        h:SetWidth(width)
        h.arrow:SetText(open and "-" or "+")
        h.label:SetText(g.title .. "  |cff888888(" .. checked .. "/" .. #g.members .. ")|r")
        h.check:SetChecked(checked == #g.members)
        if editable then h.check:Enable() else h.check:Disable() end
        h.check:SetScript("OnClick", function(cb)
            local on = cb:GetChecked() and true or nil
            for _, m in ipairs(g.members) do page.working[m.name] = on end
            RefreshChecklist()
        end)
        h:SetScript("OnClick", function()
            ns.DB().collapsed[g.key] = not ns.DB().collapsed[g.key] or nil
            RefreshChecklist()
        end)
        h:Show()
        y = y + 34

        if open then
            for _, m in ipairs(g.members) do
                ri = ri + 1
                local r = GetRow(ri)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 28, -y)
                r.label:SetText(m.title .. "  |cff888888" .. m.name .. "|r")
                r:SetChecked(page.working[m.name] == true)
                if editable then r:Enable() else r:Disable() end
                r:SetScript("OnClick", function(cb)
                    page.working[m.name] = cb:GetChecked() and true or nil
                    RefreshChecklist()
                end)
                r:Show()
                y = y + 30
            end
        end
    end
    for i = hi + 1, #page.headers do page.headers[i]:Hide() end
    for i = ri + 1, #page.addonRows do page.addonRows[i]:Hide() end
    page.listContent:SetHeight(math.max(1, y))
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------

local function Build(host)
    page = CreateFrame("Frame", nil, host)
    page.setRows, page.newRows, page.headers, page.addonRows = {}, {}, {}, {}
    page.working = {}

    ns.Text(page, "AddOn Sets", "GameFontNormalLarge", 1, 1, 1):SetPoint("TOPLEFT", 20, -16)
    ns.Text(page, "Create named sets of enabled AddOns, then assign them on Profiles.", "GameFontHighlightSmall", 0.75, 0.8, 0.85)
        :SetPoint("TOPLEFT", 20, -40)

    -- left card
    local left = ns.Card(page)
    left:SetPoint("TOPLEFT", 20, -70)
    left:SetPoint("BOTTOMLEFT", 20, 16)
    left:SetWidth(260)
    ns.AccentText(left, "Sets"):SetPoint("TOPLEFT", 14, -14)
    local new = ns.Button(left, 72, 26, "New", function() StaticPopup_Show("PROFILESWAP_NEW_SET") end)
    new:SetPoint("TOPLEFT", 14, -40)
    local delete = ns.Button(left, 72, 26, "Delete", function()
        if page.selected then StaticPopup_Show("PROFILESWAP_DELETE_SET", page.selected, nil, page.selected) end
    end)
    delete:SetPoint("LEFT", new, "RIGHT", 6, 0)
    local rename = ns.Button(left, 72, 26, "Rename", function()
        if page.selected then StaticPopup_Show("PROFILESWAP_RENAME_SET", nil, nil, page.selected) end
    end)
    rename:SetPoint("LEFT", delete, "RIGHT", 6, 0)
    local setScroll = CreateFrame("ScrollFrame", nil, left, "UIPanelScrollFrameTemplate")
    setScroll:SetPoint("TOPLEFT", 14, -78)
    setScroll:SetPoint("BOTTOMRIGHT", -30, 12)
    page.setContent = CreateFrame("Frame", nil, setScroll)
    page.setContent:SetSize(210, 1)
    setScroll:SetScrollChild(page.setContent)
    page.noSets = ns.Text(left, "No sets yet.", "GameFontDisable")
    page.noSets:SetPoint("TOPLEFT", 16, -82)

    -- right card
    local right = ns.Card(page)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 16, 0)
    right:SetPoint("BOTTOMRIGHT", -16, 16)
    page.rightTitle = ns.AccentText(right, "AddOns in set")
    page.rightTitle:SetPoint("TOPLEFT", 14, -14)
    page.search = CreateFrame("EditBox", nil, right, "SearchBoxTemplate")
    page.search:SetSize(280, 24)
    page.search:SetPoint("TOPLEFT", 20, -42)
    page.search:HookScript("OnTextChanged", function()
        if page.listScroll then RefreshChecklist() end -- the template fires this while building
    end)
    local all = ns.Button(right, 72, 26, "All", function()
        for _, a in ipairs(ns.InstalledAddons()) do
            if not ns.IsProtected(a.name) then page.working[a.name] = true end
        end
        RefreshChecklist()
    end)
    all:SetPoint("TOPLEFT", 14, -76)
    local none = ns.Button(right, 72, 26, "None", function()
        wipe(page.working)
        RefreshChecklist()
    end)
    none:SetPoint("LEFT", all, "RIGHT", 6, 0)
    local save = ns.Button(right, 110, 28, "Save Set", function()
        if not page.selected then return end
        for name in pairs(page.working) do ns.MarkKnown(name) end
        ns.SaveSet(page.selected, page.working)
        page.workingFor = nil
        ns.Print("Saved AddOn set '" .. page.selected .. "'.")
    end)
    save:SetPoint("TOPRIGHT", -14, -12)
    page.allButton, page.noneButton, page.saveButton = all, none, save

    -- new addons box
    local newBox = CreateFrame("Frame", nil, right, "BackdropTemplate")
    newBox:SetBackdrop(ns.FLAT_BACKDROP)
    newBox:SetBackdropColor(0.06, 0.08, 0.12, 0.9)
    newBox:SetPoint("TOPLEFT", 14, -114)
    newBox:SetPoint("RIGHT", -14, 0)
    newBox:SetHeight(140)
    local strip = newBox:CreateTexture(nil, "ARTWORK")
    strip:SetPoint("TOPLEFT", 1, -1)
    strip:SetPoint("TOPRIGHT", -1, -1)
    strip:SetHeight(28)
    ns.Themed(function()
        local c = ns.Theme().accent
        newBox:SetBackdropBorderColor(c[1], c[2], c[3], 0.75)
        strip:SetColorTexture(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 0.95)
    end)
    ns.AccentText(newBox, "New AddOns"):SetPoint("TOPLEFT", 10, -8)
    local dismissAll = ns.Button(newBox, 100, 24, "Dismiss all", function()
        for _, a in ipairs(ns.UnknownAddons()) do ns.MarkKnown(a.name) end
        ns.RefreshPage()
    end)
    dismissAll:SetPoint("TOPRIGHT", -4, -2)
    local note = ns.Text(newBox, "Tick to add to this set. Dismissed addons get disabled by sets that leave them out.", "GameFontHighlightSmall", 0.75, 0.8, 0.85)
    note:SetPoint("TOPLEFT", 10, -34)
    note:SetPoint("RIGHT", -10, 0)
    local newScroll = CreateFrame("ScrollFrame", nil, newBox, "UIPanelScrollFrameTemplate")
    newScroll:SetPoint("TOPLEFT", 8, -52)
    newScroll:SetPoint("BOTTOMRIGHT", -28, 6)
    page.newContent = CreateFrame("Frame", nil, newScroll)
    page.newContent:SetSize(560, 1)
    newScroll:SetScrollChild(page.newContent)
    page.newBox = newBox

    -- grouped list
    page.listScroll = CreateFrame("ScrollFrame", nil, right, "UIPanelScrollFrameTemplate")
    page.listScroll:SetPoint("BOTTOMRIGHT", -30, 12)
    page.listContent = CreateFrame("Frame", nil, page.listScroll)
    page.listContent:SetSize(1, 1)
    page.listScroll:SetScrollChild(page.listContent)
    page.right = right

    return page
end

local function Refresh()
    RefreshSetList()
    EnsureWorking()
    local editable = page.selected ~= nil
    page.rightTitle:SetText(editable and ("AddOns in set: " .. page.selected) or "AddOns in set (create a set first)")
    page.allButton:SetEnabledState(editable)
    page.noneButton:SetEnabledState(editable)
    page.saveButton:SetEnabledState(editable)
    local hasNew = RefreshNewBox()
    page.listScroll:ClearAllPoints()
    page.listScroll:SetPoint("TOPLEFT", page.right, "TOPLEFT", 14, hasNew and -264 or -114)
    page.listScroll:SetPoint("BOTTOMRIGHT", page.right, "BOTTOMRIGHT", -30, 12)
    RefreshChecklist()
end

ns.RegisterPage("Sets", Build, Refresh)
