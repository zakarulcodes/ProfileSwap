-- Flat look shared by the window, picker and popups. Two skins, repainted live.
local _, ns = ...

local SKINS = {
    Plain = {
        accent = { 0.62, 0.68, 0.76 },
        cardBg = { 0.10, 0.11, 0.13, 0.96 }, cardBorder = { 0.22, 0.24, 0.28, 1 },
        sidebarBg = { 0.07, 0.08, 0.10, 1 },
        btn = { 0.14, 0.15, 0.18, 0.95 }, btnHover = { 0.18, 0.20, 0.24, 1 },
        btnActive = { 0.18, 0.22, 0.28, 1 }, btnDisabled = { 0.12, 0.13, 0.15, 0.9 },
        btnBorder = { 0.28, 0.30, 0.34, 1 }, btnBorderActive = { 0.55, 0.62, 0.72, 1 },
        btnBorderDisabled = { 0.30, 0.32, 0.36, 1 },
        accentBar = true,
        activeCardBg = { 0.14, 0.16, 0.20, 0.95 }, activeCardBorder = { 0.55, 0.62, 0.72, 1 },
        rowBg = { 0.13, 0.14, 0.16, 0.9 },
    },
    Neon = {
        accent = { 0.35, 0.55, 0.85 },
        cardBg = { 0.08, 0.09, 0.12, 0.97 }, cardBorder = { 0.25, 0.30, 0.40, 1 },
        sidebarBg = { 0.05, 0.06, 0.08, 1 },
        btn = { 0.16, 0.30, 0.52, 0.95 }, btnHover = { 0.26, 0.42, 0.70, 1 },
        btnActive = { 0.08, 0.36, 0.20, 1 }, btnDisabled = { 0.12, 0.13, 0.15, 0.9 },
        btnBorder = { 0.35, 0.55, 0.85, 1 }, btnBorderActive = { 0.55, 0.92, 0.62, 1 },
        btnBorderDisabled = { 0.30, 0.32, 0.36, 1 },
        accentBar = false,
        activeCardBg = { 0.10, 0.18, 0.28, 0.95 }, activeCardBorder = { 0.35, 0.65, 0.95, 1 },
        rowBg = { 0.12, 0.14, 0.18, 0.9 },
    },
}

ns.FLAT_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

function ns.Theme()
    local db = ns.DB()
    return SKINS[db and db.skin or "Neon"] or SKINS.Neon
end

function ns.AccentHex()
    local c = ns.Theme().accent
    return string.format("%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

-- Everything themed registers a paint function; changing skin repaints all.
local painters = {}
function ns.Themed(fn)
    painters[#painters + 1] = fn
    fn()
    return fn
end

function ns.SetSkin(name)
    if not SKINS[name] then name = "Neon" end
    ns.DB().skin = name
    for _, fn in ipairs(painters) do fn() end
    ns.Changed()
end

local function SetBg(frame, color, alpha)
    frame:SetBackdropColor(color[1], color[2], color[3], alpha or color[4] or 1)
end
local function SetBorder(frame, color, alpha)
    frame:SetBackdropBorderColor(color[1], color[2], color[3], alpha or color[4] or 1)
end
ns.SetBg, ns.SetBorder = SetBg, SetBorder

-- kind: "card" (default), "active", "sidebar", "row"
function ns.Card(parent, kind, bgAlpha)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop(ns.FLAT_BACKDROP)
    f.kind = kind or "card"
    ns.Themed(function()
        local t = ns.Theme()
        if f.kind == "active" then
            SetBg(f, t.activeCardBg); SetBorder(f, t.activeCardBorder)
        elseif f.kind == "sidebar" then
            SetBg(f, t.sidebarBg); SetBorder(f, t.sidebarBg)
        elseif f.kind == "transparent" then
            f:SetBackdropColor(0, 0, 0, 0); f:SetBackdropBorderColor(0, 0, 0, 0)
        elseif f.kind == "row" then
            SetBg(f, t.rowBg); SetBorder(f, t.cardBorder)
        else
            SetBg(f, t.cardBg, bgAlpha); SetBorder(f, t.cardBorder)
        end
    end)
    return f
end

function ns.Text(parent, text, font, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    if r then fs:SetTextColor(r, g, b) end
    return fs
end

-- Section heading in the accent colour.
function ns.AccentText(parent, text, font)
    local fs = ns.Text(parent, text, font or "GameFontNormal")
    ns.Themed(function()
        local c = ns.Theme().accent
        fs:SetTextColor(c[1], c[2], c[3])
    end)
    return fs
end

---------------------------------------------------------------------------
-- Flat button: normal / hover / current / disabled
---------------------------------------------------------------------------

local function PaintButton(b)
    local t = ns.Theme()
    if not b:IsEnabled() then
        SetBg(b, t.btnDisabled); SetBorder(b, t.btnBorderDisabled)
        b.label:SetTextColor(0.55, 0.57, 0.62)
    elseif b.current then
        SetBg(b, t.btnActive); SetBorder(b, t.btnBorderActive)
        b.label:SetTextColor(1, 1, 1)
    elseif b.hover then
        SetBg(b, t.btnHover); SetBorder(b, t.btnBorder)
        b.label:SetTextColor(0.88, 0.90, 0.94)
    else
        SetBg(b, t.btn); SetBorder(b, t.btnBorder)
        b.label:SetTextColor(0.88, 0.90, 0.94)
    end
    local showBar = b.current and t.accentBar and b:IsEnabled()
    b.bar:SetShown(showBar and true or false)
    if showBar then b.bar:SetColorTexture(t.accent[1], t.accent[2], t.accent[3], 0.95) end
end

function ns.Button(parent, width, height, text, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, height)
    b:SetBackdrop(ns.FLAT_BACKDROP)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.label:SetPoint("LEFT", 10, 0)
    b.label:SetPoint("RIGHT", -8, 0)
    b.label:SetJustifyH("CENTER")
    b.label:SetWordWrap(true)
    b.bar = b:CreateTexture(nil, "OVERLAY")
    b.bar:SetPoint("TOPLEFT", 1, -1)
    b.bar:SetPoint("BOTTOMLEFT", 1, 1)
    b.bar:SetWidth(3)
    function b:SetText(value) self.label:SetText(value) end
    function b:GetText() return self.label:GetText() end
    function b:SetCurrent(on) self.current = on and true or false; PaintButton(self) end
    function b:SetEnabledState(on)
        if on then self:Enable() else self:Disable() end
        PaintButton(self)
    end
    b:SetScript("OnEnter", function(self) self.hover = true; PaintButton(self) end)
    b:SetScript("OnLeave", function(self) self.hover = false; PaintButton(self) end)
    b:SetText(text or "")
    if onClick then b:SetScript("OnClick", onClick) end
    ns.Themed(function() PaintButton(b) end)
    return b
end

-- Simple tooltip helper for any frame.
function ns.Tooltip(frame, title, body)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if body then GameTooltip:AddLine(body, 1, 0.82, 0, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
end
