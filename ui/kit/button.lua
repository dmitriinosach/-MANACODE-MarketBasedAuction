local _, ns = ...
local K = ns.TradeKit
function K.StyleButton(b)
    local art = K.ButtonArt(b)
    local skin = K.theme[b.kind] or K.theme.control
    local fill = skin[b.pressed and "down" or (b.hovered and "hover" or "bg")]
    local edge, text = skin.edge, rawget(b, "flat") and K.theme.text or skin.text
    if b.active and b.kind == "nav" then
        text = K.theme.gold
    elseif b.active and b.kind ~= "main" then
        fill, edge, text = K.theme.chosen.bg, K.theme.chosen.edge, K.theme.chosen.text
        if art then text = skin.text end
    end
    if b.btnDisabled and b.kind == "main" then fill, edge = K.theme.control.down, K.theme.edge end
    if art and b.hovered and not b.btnDisabled then text = K.theme.text end
    local bare = rawget(b, "bare")
    if bare then
        local push = b.pressed and 1 or 0
        b.glyph:ClearAllPoints(); b.glyph:SetPoint("CENTER", b, "CENTER", push, -push)
        b.bareLit:SetTexture(bare.lit or K.theme.iconLit)
        if b.hovered and not b.btnDisabled then b.bareLit:Show() else b.bareLit:Hide() end
        if b.active then b.bareCheck:Show() else b.bareCheck:Hide() end
    elseif art then
        local file = b.btnDisabled and art.disabled or ((b.pressed or b.active) and art.down or art.up)
        for _, piece in ipairs(b.artPieces) do piece:SetTexture(file) end
        if b.hovered and not b.btnDisabled then b.artLit:Show() else b.artLit:Hide() end
    else
        b:SetBackdropColor(unpack(fill))
        b:SetBackdropBorderColor(unpack(edge))
    end
    b.text:SetTextColor(unpack(b.btnDisabled and K.theme.off or text))
    if rawget(b, "glyph") then
        b.glyph:SetDesaturated(b.btnDisabled); b.glyph:SetAlpha(b.btnDisabled and 0.5 or 1)
    end
    if rawget(b, "navLine") then
        if b.active then b.navLine:Show() else b.navLine:Hide() end
    end
    if rawget(b, "dot") and rawget(b, "quality") then
        local r, g, bl = K.QualityColor(b.quality)
        b.dot:SetVertexColor(r, g, bl, b.btnDisabled and 0.3 or (b.active and 1 or 0.25))
    elseif rawget(b, "dot") then
        b.dot:SetVertexColor(unpack(b.btnDisabled and K.theme.off or (b.active and K.theme.accent or K.theme.edge)))
    end
end
local CAP = 0.09375
local RIGHT = 0.625
local BOTTOM = 0.6875
function K.ButtonArt(b)
    local look = K.theme.look.button
    local bare = rawget(b, "bare")
    local art = not bare and look and look.kinds[rawget(b, "kind") or "control"] and not rawget(b, "flat") and look or nil
    local mode = (bare and "bare" or (art and "art" or "flat")) .. K.LookStamp()
    if rawget(b, "skinMode") ~= mode then
        b.skinMode = mode
        if art or bare then b:SetBackdrop(nil) else b:SetBackdrop(K.theme.buttonSkin) end
        if art and not rawget(b, "artPieces") then
            local left, middle, right = b:CreateTexture(nil, "BACKGROUND"), b:CreateTexture(nil, "BACKGROUND"),
                b:CreateTexture(nil, "BACKGROUND")
            left:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0); left:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
            right:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0); right:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
            middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0); middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
            b.artPieces = {left, middle, right}
            b.artLit = b:CreateTexture(nil, "BORDER")
            b.artLit:SetAllPoints(b)
            b.artLit:SetTexCoord(0, RIGHT, 0, BOTTOM)
            b.artLit:SetBlendMode("ADD")
        end
        if rawget(b, "artPieces") then
            for _, piece in ipairs(b.artPieces) do if art then piece:Show() else piece:Hide() end end
            if art then b.artLit:SetTexture(art.highlight) end
            b.artLit:Hide()
        end
    end
    if art then
        local cap = math.min(12, math.floor((b:GetWidth() or 24) / 2))
        local share = CAP * cap / 12
        local left, middle, right = b.artPieces[1], b.artPieces[2], b.artPieces[3]
        left:SetWidth(cap); right:SetWidth(cap)
        left:SetTexCoord(0, share, 0, BOTTOM)
        middle:SetTexCoord(share, RIGHT - share, 0, BOTTOM)
        right:SetTexCoord(RIGHT - share, RIGHT, 0, BOTTOM)
    end
    return art
end
function K.Button(parent, text, width, fn, kind, template)
    local b = ns.NewFrame("Button", nil, parent, template)
    b.kind, b.onClick = kind, fn
    b.active, b.btnDisabled, b.hovered, b.pressed = false, false, false, false
    b.tradeKitButton = true
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
    b.bare = icon and icon.bare and icon or nil
    if not icon then
        if rawget(b, "glyph") then b.glyph:Hide(); b.glyph:ClearAllPoints(); b.glyph:SetPoint("CENTER", b, "CENTER", 0, 0) end
        if rawget(b, "bareLit") then b.bareLit:Hide(); b.bareCheck:Hide() end
        K.StyleButton(b)
        return false
    end
    if not rawget(b, "glyph") then
        b.glyph = b:CreateTexture(nil, "ARTWORK")
        b.glyph:SetPoint("CENTER", b, "CENTER", 0, 0)
    end
    b:SetText(""); b:SetWidth(22)
    local side = b.bare and math.min(22, b:GetHeight() or 22) or 14
    b.glyph:SetWidth(side); b.glyph:SetHeight(side)
    b.glyph:SetTexture(icon[1])
    b.glyph:SetTexCoord(icon[2] or 0, icon[3] or 1, icon[4] or 0, icon[5] or 1)
    b.glyph:Show()
    if b.bare and not rawget(b, "bareLit") then
        b.bareLit = b:CreateTexture(nil, "OVERLAY")
        b.bareLit:SetAllPoints(b.glyph)
        b.bareLit:SetBlendMode("ADD")
        b.bareCheck = b:CreateTexture(nil, "OVERLAY")
        b.bareCheck:SetAllPoints(b.glyph)
        b.bareCheck:SetTexture(K.theme.iconChecked)
        b.bareCheck:SetBlendMode("ADD")
    end
    if rawget(b, "bareLit") then b.bareLit:Hide(); b.bareCheck:Hide() end
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
function K.FitButton(b, pad)
    b:SetWidth(math.ceil((b.text:GetStringWidth() or 60) + math.max(pad or 24, K.theme.fitPad)))
end
local ActionBand = {}
ActionBand.__index = ActionBand
K.ActionBand = ActionBand
ActionBand.HEIGHT = 28
ActionBand.SUMMARY = 20
function ActionBand:New(parent)
    local band = setmetatable({buttons = {}, props = {actions = {}}}, self)
    band.frame = ns.NewFrame("Frame", nil, parent)
    band.frame:SetHeight(ActionBand.HEIGHT)
    for i = 1, 3 do
        local b = K.Button(band.frame, "", 80, function() band:Click(i) end, "control")
        b:Hide()
        band.buttons[i] = b
    end
    band.total = K.Label(band.frame, "", 0, -2, 140); band.total:SetHeight(16)
    band.total:SetFontObject("GameFontHighlight")
    band.note = K.Label(band.frame, "", 0, -4, 100, "secondary"); band.note:SetHeight(12); band.note:SetJustifyH("RIGHT")
    band.note:ClearAllPoints(); band.note:SetPoint("TOPRIGHT", band.frame, "TOPRIGHT", 0, -4)
    band.help = ns.NewFrame("Frame", nil, band.frame)
    band.help:SetPoint("TOPLEFT", band.frame, "TOPLEFT", 0, 0)
    band.help:SetPoint("TOPRIGHT", band.frame, "TOPRIGHT", 0, 0)
    band.help:SetHeight(ActionBand.SUMMARY); band.help:EnableMouse(true)
    K.Tooltip(band.help, "", "")
    band.help.tipFn = function() return band.props.summary and band.props.summary.tip or "" end
    for _, part in ipairs({band.total, band.note, band.help}) do part:Hide() end
    return band
end
function ActionBand:For(inspector, scroll, summary)
    local band = self:New(inspector.body)
    band.inspector, band.scroll = inspector, scroll
    band.frame:SetPoint("BOTTOMLEFT", inspector.body, "BOTTOMLEFT", K.theme.inset, 2)
    if scroll then scroll.reserve = ActionBand.HEIGHT + (summary and ActionBand.SUMMARY or 0) end
    return band
end
function ActionBand.Buy(id, label, need)
    local busy = ns.Scan.state.phase ~= "idle" or ns.Buy.Active()
    local vendor = ns.vendorPrices and ns.vendorPrices[id]
    return {key = "buy", label = label or ns.T("tradeToBuy"), title = ns.T("tradeToBuyTitle"), tip = ns.T("tradeBuyTip"),
        reason = vendor and ns.T("cacheVendor") or busy and ns.T("batchBusy") or nil,
        fn = function() ns.Trader.OpenBuy(id, need) end}
end
function ActionBand:Find(key)
    for i, action in ipairs(self.props.actions) do
        if action.key == key then return action, self.buttons[i] end
    end
end
function ActionBand:Click(i)
    local action = self.props.actions[i]
    if action and not action.reason then action.fn() end
end
function ActionBand:SetProps(props)
    if not props.width then
        props.width = ((self.inspector and self.inspector.width) or 264) - 2 * K.theme.inset
    end
    self.props = props
    local actions, gap = props.actions, 4
    local summary = props.summary
    local top = props.top
    if rawget(self, "topFrame") and self.topFrame ~= top then self.topFrame:Hide() end
    self.topFrame = top
    self.topHeight = top and math.ceil((top:GetHeight() or 22) + 4) or 0
    if top then
        top:ClearAllPoints(); top:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
        top:SetWidth(props.width); top:Show()
    end
    local inline = props.inline and summary and #actions == 1
    local height = ActionBand.HEIGHT + ((summary and not inline) and ActionBand.SUMMARY or 0) + self.topHeight
    self.frame:SetWidth(props.width); self.frame:SetHeight(height)
    if self.scroll then self.scroll.reserve = height end
    self:Summary(summary, props.width)
    if #actions == 0 then self.frame:Hide(); return end
    self.frame:Show()
    if inline then return self:Inline(actions[1], props.width) end
    local width = math.floor((props.width - gap * (#actions - 1)) / #actions)
    for i, b in ipairs(self.buttons) do
        local action = actions[i]
        if action then
            b.kind = action.main and "main" or "control"
            K.StyleButton(b)
            b:SetWidth(i == #actions and props.width - (width + gap) * (#actions - 1) or width)
            b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", (i - 1) * (width + gap), 2)
            b:SetText(action.label)
            if action.sources then
                K.ScanTip(b, action.title or action.label, action.tip or "", action.sources, false)
            else
                K.ScanUntrack(b)
                K.Tooltip(b, action.title or action.label, action.tip or "")
                b.tipFn = action.tipFn
            end
            K.DisabledTip(b, action.title or action.label, action.reason)
            if action.reason then b:Disable() else b:Enable() end
            b:Show()
        else b:Hide() end
    end
end
function ActionBand:Inline(action, width)
    local b = self.buttons[1]
    for i = 2, #self.buttons do self.buttons[i]:Hide() end
    b.kind = action.main and "main" or "control"
    K.StyleButton(b)
    b:SetText(action.label); K.FitButton(b, 32); b:SetWidth(math.max(90, b:GetWidth() or 90))
    b:ClearAllPoints(); b:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 2)
    K.Tooltip(b, action.title or action.label, action.tip or "")
    b.tipFn = action.tipFn
    K.DisabledTip(b, action.title or action.label, action.reason)
    if action.reason then b:Disable() else b:Enable() end
    b:Show()
    local room = math.max(40, width - (b:GetWidth() or 90) - 8)
    self.total:ClearAllPoints(); self.total:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, 5); self.total:SetWidth(room)
    self.note:Hide()
    self.help:ClearAllPoints(); self.help:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, 2)
    self.help:SetWidth(room); self.help:SetHeight(22)
end
function ActionBand:Summary(summary, width)
    if not summary then
        for _, part in ipairs({self.total, self.note, self.help}) do part:Hide() end
        return
    end
    local y = -(self.topHeight or 0)
    self.total:ClearAllPoints(); self.total:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, y - 2)
    self.note:ClearAllPoints(); self.note:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, y - 4)
    self.help:ClearAllPoints()
    self.help:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, y); self.help:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, y)
    self.total:SetText(summary.text or "")
    self.note:SetText(summary.note or "")
    self.note:SetTextColor(unpack(K.theme[summary.tone or "secondary"]))
    local noteWidth = math.min(math.floor(width * 0.45), math.ceil(self.note:GetStringWidth() or width * 0.4) + 2)
    self.note:SetWidth(noteWidth)
    self.total:SetWidth(math.max(40, width - noteWidth - 6))
    self.help.tipTitle = summary.title or summary.text or ""
    for _, part in ipairs({self.total, self.note, self.help}) do part:Show() end
end
function K.Navigation(parent, text, fn)
    local b = ns.NewFrame("Button", nil, parent)
    b:SetWidth(158)
    b:SetHeight(27)
    b.text = K.Label(b, text, 9, -7, 144)
    b.selected = b:CreateTexture(nil, "BACKGROUND")
    b.selected:SetAllPoints(b)
    K.Highlight(b.selected, "selected")
    b.selected:Hide()
    b.mark = b:CreateTexture(nil, "ARTWORK")
    b.mark:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.mark:SetWidth(2); b.mark:SetTexture(K.theme.white)
    b.mark:SetVertexColor(unpack(K.theme.gold))
    b.mark:Hide()
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(b); K.Highlight(hover, "hover"); b:SetHighlightTexture(hover)
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
    b.flat = true
    if rawget(b, "btnDisabled") ~= nil then
        K.StyleButton(b)
    else
        K.Skin(b)
        b:SetBackdropColor(unpack(K.theme.control.bg))
        b:SetBackdropBorderColor(unpack(K.theme.control.edge))
    end
    b.arrow = b:CreateTexture(nil, "ARTWORK")
    b.arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
    b.arrow:SetTexCoord(0, 0.9375, 0.9375, 0.4375)
    b.arrow:SetWidth(11); b.arrow:SetHeight(6)
    b.arrow:SetPoint("RIGHT", b, "RIGHT", -8, 0)
end
