-- On-screen picker button. Moved, sized and anchored through Blizzard Edit Mode (LibEditMode).
local _, ns = ...

local LEM = LibStub("LibEditMode")
local button, menu, picking

local SIDE_DEFAULTS = { LEFT = { -8, 0 }, RIGHT = { 8, 0 }, TOP = { 0, 8 }, BOTTOM = { 0, -8 } }

local function DB() return ns.DB().picker end

function ns.PickerLabel()
    local db = ns.DB()
    local profile, mode = ns.ResolveProfile()
    local text
    if mode == "manual" then
        text = profile.name
    elseif profile then
        text = "Auto: " .. profile.name
    else
        text = "Auto"
    end
    if db.paused then text = text .. " (Paused)" end
    return text
end

---------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------

local function Paint()
    if not button then return end
    local t = ns.Theme()
    ns.SetBg(button, t.cardBg, 0.92)
    ns.SetBorder(button, button:IsMouseOver() and t.accent or t.cardBorder)
end

local function UpdateFont()
    local h = button:GetHeight()
    local font = (h <= 24 and "GameFontHighlightSmall") or (h <= 32 and "GameFontNormal") or "GameFontNormalLarge"
    button.label:SetFontObject(font)
end

---------------------------------------------------------------------------
-- Position: free, or attached to the minimap, chat frame or any named frame
---------------------------------------------------------------------------

local function AnchorTarget()
    local db = DB()
    if db.anchor == "MINIMAP" then
        return MinimapCluster or Minimap
    elseif db.anchor == "CHAT" then
        local chat = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
        return chat and (_G[chat:GetName() .. "Background"] or chat)
    elseif db.anchor == "CUSTOM" and db.customFrame then
        return _G[db.customFrame]
    end
end

local retries = 0
local function Position()
    if not button then return end
    local db = DB()
    button:ClearAllPoints()
    local target = db.anchor ~= "FREE" and AnchorTarget()
    if target and type(target) == "table" and target.GetObjectType then
        local ox, oy = db.offsetX, db.offsetY
        if db.side == "LEFT" then
            button:SetPoint("RIGHT", target, "LEFT", ox, oy)
        elseif db.side == "RIGHT" then
            button:SetPoint("LEFT", target, "RIGHT", ox, oy)
        elseif db.side == "TOP" then
            button:SetPoint("BOTTOM", target, "TOP", ox, oy)
        else
            button:SetPoint("TOP", target, "BOTTOM", ox, oy)
        end
        local width = db.matchWidth and math.min(400, math.max(70, target:GetWidth())) or db.width
        button:SetSize(width, db.height)
        retries = 0
    else
        button:SetPoint(db.point, UIParent, db.point, db.x, db.y)
        button:SetSize(db.width, db.height)
        -- a custom frame may be created later by its addon
        if db.anchor == "CUSTOM" and retries < 20 then
            retries = retries + 1
            C_Timer.After(0.5, Position)
        end
    end
    UpdateFont()
end

local function SetAnchor(anchor)
    local db = DB()
    db.anchor = anchor
    if anchor ~= "CUSTOM" then db.customFrame = nil end
    local d = SIDE_DEFAULTS[db.side] or SIDE_DEFAULTS.BOTTOM
    db.offsetX, db.offsetY = d[1], d[2]
    retries = 0
    Position()
    LEM:RefreshFrameSettings(button)
end

---------------------------------------------------------------------------
-- Hover-pick: choose any named frame on screen to anchor to
---------------------------------------------------------------------------

local pickOverlay, pickHighlight, pickInfo, pickCandidate

local function IsOurs(frame)
    while frame do
        if frame == button or frame == pickOverlay then return true end
        frame = frame:GetParent()
    end
    return false
end

-- Smallest named, visible frame under the cursor (excluding the screen roots and our own frames).
local function FindCandidate()
    local best, bestArea
    local frame = EnumerateFrames()
    while frame do
        local ok, name, visible, over, w, h = pcall(function()
            if frame:IsForbidden() then return nil end
            return frame:GetName(), frame:IsVisible(), frame:IsMouseOver(), frame:GetWidth(), frame:GetHeight()
        end)
        if ok and name and visible and over and w and h and w > 1 and h > 1
            and frame ~= UIParent and frame ~= WorldFrame and not IsOurs(frame) then
            local area = w * h
            if not bestArea or area < bestArea then best, bestArea = frame, area end
        end
        frame = EnumerateFrames(frame)
    end
    return best
end

local function StopPicking()
    picking = false
    if pickOverlay then pickOverlay:Hide() end
end

local function StartPicking()
    if not pickOverlay then
        pickOverlay = CreateFrame("Frame", nil, UIParent)
        pickOverlay:SetAllPoints(UIParent)
        pickOverlay:SetFrameStrata("TOOLTIP")
        pickOverlay:EnableMouse(true)
        pickOverlay:EnableKeyboard(true)
        local dim = pickOverlay:CreateTexture(nil, "BACKGROUND")
        dim:SetAllPoints()
        dim:SetColorTexture(0, 0, 0, 0.15)

        pickHighlight = CreateFrame("Frame", nil, pickOverlay, "BackdropTemplate")
        pickHighlight:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        pickHighlight:SetBackdropColor(0.15, 0.55, 0.85, 0.18)
        pickHighlight:SetBackdropBorderColor(0.2, 0.85, 1, 1)

        pickInfo = CreateFrame("Frame", nil, pickOverlay, "BackdropTemplate")
        pickInfo:SetSize(420, 54)
        pickInfo:SetPoint("TOP", 0, -80)
        pickInfo:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        pickInfo:SetBackdropColor(0, 0, 0, 0.9)
        pickInfo.text = pickInfo:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        pickInfo.text:SetPoint("CENTER")
        pickInfo.text:SetWidth(400)

        local elapsed = 0
        pickOverlay:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed < 0.1 then return end
            elapsed = 0
            pickOverlay:EnableMouse(false) -- let IsMouseOver see what is underneath
            pickCandidate = FindCandidate()
            pickOverlay:EnableMouse(true)
            if pickCandidate then
                pickHighlight:ClearAllPoints()
                pickHighlight:SetPoint("TOPLEFT", pickCandidate, "TOPLEFT", -3, 3)
                pickHighlight:SetPoint("BOTTOMRIGHT", pickCandidate, "BOTTOMRIGHT", 3, -3)
                pickHighlight:Show()
                pickInfo.text:SetText("Anchor to: |cff66ccff" .. pickCandidate:GetName() .. "|r\nLeft-click to confirm, right-click or Esc to cancel")
            else
                pickHighlight:Hide()
                pickInfo.text:SetText("Hover a UI element, left-click to anchor.\nRight-click or Esc cancels.")
            end
        end)
        pickOverlay:SetScript("OnMouseDown", function(_, mouse)
            if mouse == "LeftButton" and pickCandidate then
                local name = pickCandidate:GetName()
                StopPicking()
                DB().customFrame = name
                SetAnchor("CUSTOM")
                ns.Print("Anchored to '" .. name .. "'.")
            elseif mouse == "RightButton" then
                StopPicking()
                ns.Print("Anchor pick cancelled.")
            end
        end)
        pickOverlay:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                StopPicking()
                ns.Print("Anchor pick cancelled.")
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)
    end
    picking = true
    pickCandidate = nil
    pickHighlight:Hide()
    pickOverlay:Show()
end

---------------------------------------------------------------------------
-- Menu
---------------------------------------------------------------------------

local ROW_H, ROW_PITCH = 26, 28
local menuRows = {}

local function PaintRow(row)
    local r, g, b = 0.08, 0.08, 0.08
    if row.hover then
        r, g, b = 0.2, 0.35, 0.6
    elseif row.selected then
        r, g, b = 0.15, 0.45, 0.25
    end
    row:SetBackdropColor(r, g, b, 0.9)
end

local function HideMenu()
    if menu then menu:Hide() end
end

local function BuildMenu()
    menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    menu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    menu:SetBackdropColor(0, 0, 0, 0.9)
    menu:Hide()
    local away = 0
    menu:SetScript("OnUpdate", function(self, dt)
        if self:IsMouseOver() or button:IsMouseOver() then
            away = 0
        else
            away = away + dt
            if away > 0.15 then self:Hide() end
        end
    end)
end

local function ShowMenu()
    if not menu then BuildMenu() end
    local entries = { { text = "Auto (by resolution)", id = nil, selected = ns.DB().manual == nil } }
    for _, p in ipairs(ns.SortedProfiles()) do
        entries[#entries + 1] = { text = p.name, id = p.id, selected = ns.DB().manual == p.id }
    end
    local width = math.max(160, button:GetWidth()) + 20
    menu:SetSize(width, math.max(40, #entries * ROW_PITCH + 16))
    menu:ClearAllPoints()
    menu:SetPoint("TOP", button, "BOTTOM", 0, -4)
    for i, entry in ipairs(entries) do
        local row = menuRows[i]
        if not row then
            row = CreateFrame("Button", nil, menu, "BackdropTemplate")
            row:SetBackdrop(ns.FLAT_BACKDROP)
            row:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.label:SetPoint("LEFT", 8, 0)
            row.label:SetPoint("RIGHT", -8, 0)
            row.label:SetJustifyH("LEFT")
            row:SetScript("OnEnter", function(self) self.hover = true; PaintRow(self) end)
            row:SetScript("OnLeave", function(self) self.hover = false; PaintRow(self) end)
            menuRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 8, -8 - (i - 1) * ROW_PITCH)
        row:SetPoint("TOPRIGHT", -8, -8 - (i - 1) * ROW_PITCH)
        row:SetHeight(ROW_H)
        row.label:SetText(entry.text)
        row.selected = entry.selected
        row.hover = false
        row:SetScript("OnClick", function()
            HideMenu()
            ns.SelectProfile(entry.id, true)
        end)
        PaintRow(row)
        row:Show()
    end
    for i = #entries + 1, #menuRows do menuRows[i]:Hide() end
    menu:Show()
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

function ns.FillTooltip(tooltip, withEditModeHint)
    tooltip:AddLine(ns.TITLE, 1, 1, 1)
    ns.AddPendingReloadTooltip(tooltip)
    tooltip:AddLine(" ")
    tooltip:AddLine("Left-click: choose profile", 0.8, 0.8, 0.8)
    tooltip:AddLine("Right-click: open profile settings", 0.8, 0.8, 0.8)
    tooltip:AddLine("Middle-click: reload UI", 0.8, 0.8, 0.8)
    if withEditModeHint then
        tooltip:AddLine("Move, resize and anchor it in Edit Mode.", 0.7, 0.7, 0.7)
    end
end

---------------------------------------------------------------------------
-- Build + refresh
---------------------------------------------------------------------------

local function Refresh()
    if not button then return end
    button.label:SetText(ns.PickerLabel() .. ns.ReloadStar())
    local show = DB().enabled
    if show or LEM:IsInEditMode() then
        button:Show()
    else
        button:Hide()
        HideMenu()
    end
end

local function EditModeSettings()
    local S = LEM.SettingType
    local function Free() return DB().anchor == "FREE" end
    return {
        { name = "Width", kind = S.Slider, default = 110, minValue = 70, maxValue = 260, valueStep = 1,
          get = function() return DB().width end,
          set = function(_, v) DB().width = v; Position() end,
          hidden = function() return DB().matchWidth and not Free() end },
        { name = "Height", kind = S.Slider, default = 28, minValue = 20, maxValue = 48, valueStep = 1,
          get = function() return DB().height end,
          set = function(_, v) DB().height = v; Position() end },
        { name = "Anchor To", kind = S.Dropdown, default = "FREE",
          values = function()
              local list = {
                  { text = "Free (drag)", value = "FREE" },
                  { text = "Minimap", value = "MINIMAP" },
                  { text = "Chat Frame", value = "CHAT" },
              }
              if DB().customFrame then
                  list[#list + 1] = { text = "Custom: " .. DB().customFrame, value = "CUSTOM" }
              end
              return list
          end,
          get = function() return DB().anchor end,
          set = function(_, v) SetAnchor(v) end },
        { name = "Anchor Side", kind = S.Dropdown, default = "BOTTOM",
          values = { { text = "Left", value = "LEFT" }, { text = "Right", value = "RIGHT" },
                     { text = "Top", value = "TOP" }, { text = "Bottom", value = "BOTTOM" } },
          get = function() return DB().side end,
          set = function(_, v) DB().side = v; SetAnchor(DB().anchor) end,
          hidden = Free },
        { name = "Match Width", kind = S.Checkbox, default = false,
          get = function() return DB().matchWidth end,
          set = function(_, v) DB().matchWidth = v; Position(); LEM:RefreshFrameSettings(button) end,
          hidden = Free },
        { name = "Offset X", kind = S.Slider, default = 0, minValue = -100, maxValue = 100, valueStep = 1,
          get = function() return DB().offsetX end,
          set = function(_, v) DB().offsetX = v; Position() end,
          hidden = Free },
        { name = "Offset Y", kind = S.Slider, default = -8, minValue = -100, maxValue = 100, valueStep = 1,
          get = function() return DB().offsetY end,
          set = function(_, v) DB().offsetY = v; Position() end,
          hidden = Free },
    }
end

function ns.BuildPicker()
    if button then return end
    button = CreateFrame("Button", "ProfileSwapPicker", UIParent, "BackdropTemplate")
    button.editModeName = ns.TITLE
    button:SetFrameStrata("MEDIUM")
    button:SetClampedToScreen(true)
    button:SetBackdrop(ns.FLAT_BACKDROP)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", 6, 0)
    button.label:SetPoint("RIGHT", -6, 0)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    button:SetScript("OnClick", function(_, mouse)
        if picking or LEM:IsInEditMode() then return end
        if mouse == "LeftButton" then
            if menu and menu:IsShown() then HideMenu() else ShowMenu() end
        elseif mouse == "RightButton" then
            HideMenu()
            ns.OpenWindow("Profiles")
        elseif mouse == "MiddleButton" then
            HideMenu()
            ns.ExecuteReload()
        end
    end)
    button:SetScript("OnEnter", function(self)
        Paint()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        ns.FillTooltip(GameTooltip, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        Paint()
        GameTooltip:Hide()
    end)
    ns.Themed(Paint)

    LEM:AddFrame(button, function(_, _, point, x, y)
        -- dragging in Edit Mode always means a free position
        local db = DB()
        db.anchor, db.customFrame = "FREE", nil
        db.point, db.x, db.y = point, x, y
        Position()
        LEM:RefreshFrameSettings(button)
    end, { point = "CENTER", x = 0, y = -200 }, ns.TITLE)
    LEM:AddFrameSettings(button, EditModeSettings())
    LEM:AddFrameSettingsButtons(button, {
        { text = "Pick Anchor Frame", click = StartPicking },
        { text = "Clear Custom Anchor", click = function()
            if DB().anchor == "CUSTOM" then SetAnchor("FREE") end
            DB().customFrame = nil
            LEM:RefreshFrameSettings(button)
        end },
    })
    LEM:RegisterCallback("enter", function()
        HideMenu()
        Refresh()
    end)
    LEM:RegisterCallback("exit", function()
        StopPicking()
        Refresh()
    end)

    Position()
    Refresh()
end

ns.OnChange(Refresh)
