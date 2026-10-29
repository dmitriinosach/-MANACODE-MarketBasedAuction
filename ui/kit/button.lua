local _, ns = ...
local K = ns.TradeKit
function K.StyleButton(b)
    local skin = K.theme[b.kind] or K.theme.control
    local fill = skin[b.pressed and "down" or (b.hovered and "hover" or "bg")]
    local edge, text = skin.edge, skin.text
    if b.active and b.kind == "nav" then
        text = K.theme.gold
    elseif b.active and b.kind ~= "main" then
        fill, edge, text = K.theme.chosen.bg, K.theme.chosen.edge, K.theme.chosen.text
    end
    if b.btnDisabled and b.kind == "main" then fill, edge = K.theme.control.down, K.theme.edge end
    b:SetBackdropColor(unpack(fill))
    b:SetBackdropBorderColor(unpack(edge))
    b.text:SetTextColor(unpack(b.btnDisabled and K.theme.off or text))
    if rawget(b, "glyph") then
        b.glyph:SetDesaturated(b.btnDisabled); b.glyph:SetAlpha(b.btnDisabled and 0.5 or 1)
    end
    if rawget(b, "navLine") then
        if b.active then b.navLine:Show() else b.navLine:Hide() end
    end
    if rawget(b, "dot") then
        b.dot:SetVertexColor(unpack(b.btnDisabled and K.theme.off or (b.active and K.theme.accent or K.theme.edge)))
    end
end
function K.Button(parent, text, width, fn, kind, template)
    local b = ns.NewFrame("Button", nil, parent, template)
    b.kind, b.onClick = kind, fn
    b.active, b.btnDisabled, b.hovered, b.pressed = false, false, false, false
    b:SetWidth(width)
    b:SetHeight(22)
    b:SetNormalFontObject("GameFontNormalSmall")
    b:SetHighlightFontObject("GameFontHighlightSmall")
    b:SetDisabledFontObject("GameFontHighlightSmall")
    local textRegion = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    textRegion:SetPoint("CENTER", b, "CENTER", 0, 0)
    b:SetFontString(textRegion)
    b.text = textRegion
    textRegion:ClearAllPoints()
    textRegion:SetPoint("LEFT", b, "LEFT", 7, 0)
    textRegion:SetPoint("RIGHT", b, "RIGHT", -7, 0)
    textRegion:SetJustifyH("CENTER")
    b:SetText(text)
    b:SetBackdrop(K.theme.buttonSkin)
    if kind == "main" then b:SetHeight(26); K.LargeText(b) end
    if kind == "nav" then K.MakeNav(b) end
    b.nativeEnable, b.nativeDisable = b.Enable, b.Disable
    b.Enable = function(self) self.btnDisabled = false; self.nativeEnable(self); K.StyleButton(self) end
    b.Disable = function(self) self.btnDisabled = true; self.nativeDisable(self); K.StyleButton(self) end
    b.SetActive = function(self, active) self.active = active and true or false; K.StyleButton(self) end
    b:SetScript("OnEnter", function(self) self.hovered = true; K.StyleButton(self) end)
    b:SetScript("OnLeave", function(self) self.hovered, self.pressed = false, false; K.StyleButton(self) end)
    b:SetScript("OnMouseDown", function(self) self.pressed = not self.btnDisabled; K.StyleButton(self) end)
    b:SetScript("OnMouseUp", function(self) self.pressed = false; K.StyleButton(self) end)
    b:SetScript(template and "PreClick" or "OnClick", function(self, button)
        if not self.btnDisabled and self.onClick then self.onClick(self, button) end
    end)
    K.StyleButton(b)
    return b
end
function K.SetGlyph(b, key)
    local icon = key and K.theme.actionIcons[key]
    if not icon then
        if rawget(b, "glyph") then b.glyph:Hide() end
        return false
    end
    if not rawget(b, "glyph") then
        b.glyph = b:CreateTexture(nil, "ARTWORK")
        b.glyph:SetWidth(14); b.glyph:SetHeight(14)
        b.glyph:SetPoint("CENTER", b, "CENTER", 0, 0)
    end
    b.glyph:SetTexture(icon[1])
    b.glyph:SetTexCoord(icon[2] or 0, icon[3] or 1, icon[4] or 0, icon[5] or 1)
    b.glyph:Show()
    b:SetText(""); b:SetWidth(22)
    K.StyleButton(b)
    return true
end
function K.IconButton(parent, key, fn, title, tip)
    local b = K.Button(parent, "", 22, fn, "quiet")
    b:SetHeight(20)
    K.SetGlyph(b, key)
    K.Tooltip(b, title, tip)
    return b
end
function K.InfoButton(parent, title, body)
    local b = K.Button(parent, ns.T("tradeInfo"), K.theme.infoSize, nil, "control")
    b:SetHeight(K.theme.infoSize)
    b.infoButton = true
    K.Tooltip(b, title, body)
    return b
end
function K.NavText(b)
    local font = K.Font("ManaCodeNavFont", "GameFontNormal", 11)
    b:SetNormalFontObject(font); b:SetHighlightFontObject(font); b:SetDisabledFontObject(font)
    b.text:SetFontObject(font)
end
function K.MakeNav(b)
    b.kind = "nav"
    b:SetHeight(26)
    K.NavText(b)
    if not rawget(b, "navLine") then
        b.navLine = b:CreateTexture(nil, "ARTWORK")
        b.navLine:SetTexture(K.theme.white)
        b.navLine:SetVertexColor(unpack(K.theme.gold))
        b.navLine:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 4, 1)
        b.navLine:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 1)
        b.navLine:SetHeight(2)
    end
    K.StyleButton(b)
    return b
end
function K.LargeText(b)
    b:SetNormalFontObject("GameFontNormal")
    b:SetHighlightFontObject("GameFontHighlight")
    b:SetDisabledFontObject("GameFontHighlight")
    b.text:SetFontObject("GameFontNormal")
end
function K.FitButton(b, pad)
    b:SetWidth(math.ceil((b.text:GetStringWidth() or 60) + math.max(pad or 24, K.theme.fitPad)))
end
function K.Navigation(parent, text, fn)
    local b = ns.NewFrame("Button", nil, parent)
    b:SetWidth(158)
    b:SetHeight(27)
    b.text = K.Label(b, text, 9, -7, 144)
    b.selected = b:CreateTexture(nil, "BACKGROUND")
    b.selected:SetAllPoints(b)
    b.selected:SetTexture(K.theme.white)
    b.selected:SetVertexColor(unpack(K.theme.selected))
    b.selected:Hide()
    b.mark = b:CreateTexture(nil, "ARTWORK")
    b.mark:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.mark:SetWidth(2); b.mark:SetTexture(K.theme.white)
    b.mark:SetVertexColor(unpack(K.theme.gold))
    b.mark:Hide()
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(b); hover:SetTexture(K.theme.white)
    hover:SetVertexColor(unpack(K.theme.hover)); b:SetHighlightTexture(hover)
    b.onClick = fn
    b:SetScript("OnClick", function(self, button) if self.onClick then self.onClick(self, button) end end)
    return b
end
function K.TextLink(parent, fn)
    local b = ns.NewFrame("Button", nil, parent)
    b:SetHeight(26)
    b.text = K.Label(b, "", 0, -1, 100)
    b.text:SetHeight(12); b.text:SetTextColor(unpack(K.theme.accent))
    b.sub = K.Label(b, "", 0, -14, 100, "secondary")
    b.sub:SetHeight(10)
    b.onClick = fn
    b:SetScript("OnClick", function(self, button) if self.onClick then self.onClick(self, button) end end)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(unpack(K.theme.text)) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(unpack(K.theme.accent)) end)
    return b
end
function K.SetTextLink(b, width, text, sub)
    b:SetWidth(width)
    b.text:SetWidth(width); b.sub:SetWidth(width)
    b.text:SetText(text); b.sub:SetText(sub or "")
    b:Show()
end
function K.Selector(b)
    b:SetBackdrop(K.theme.buttonSkin)
    b:SetBackdropColor(unpack(K.theme.control.bg))
    b:SetBackdropBorderColor(unpack(K.theme.control.edge))
    b.arrow = b:CreateTexture(nil, "ARTWORK")
    b.arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
    b.arrow:SetTexCoord(0, 0.9375, 0.9375, 0.4375)
    b.arrow:SetWidth(11); b.arrow:SetHeight(6)
    b.arrow:SetPoint("RIGHT", b, "RIGHT", -8, 0)
end
