local _, ns = ...
local K = ns.TradeKit
local OutcomeList = {}
OutcomeList.__index = OutcomeList
K.OutcomeList = OutcomeList
function OutcomeList:New(parent, changed, cards)
    local view = setmetatable({cards = {}, changed = changed}, self)
    view.frame = ns.NewFrame("Frame", nil, parent)
    view.scroll = K.Scroller:New(view.frame, function() view:Render() end, 46)
    view.scroll.frame:SetAllPoints(view.frame)
    for i = 1, cards or 4 do
        local card = {}
        card.frame = K.ItemChoice(view.frame, function() view:Toggle(card.frame.itemID) end)
        card.frame:SetHeight(42)
        card.back = card.frame:CreateTexture(nil, "BACKGROUND")
        card.back:SetAllPoints(card.frame); card.back:SetTexture(K.theme.white)
        card.back:SetVertexColor(unpack(K.theme.row))
        card.frame.selected:SetDrawLayer("BORDER")
        card.icon, card.name = card.frame.icon, card.frame.text
        card.icon:SetWidth(34); card.icon:SetHeight(34)
        card.icon:ClearAllPoints(); card.icon:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 4, -4)
        card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        card.name:ClearAllPoints(); card.name:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 44, -3)
        card.name:SetWidth(130); card.name:SetHeight(12)
        card.amount = K.Label(card.frame, "", 0, 0, 52)
        card.amount:ClearAllPoints(); card.amount:SetPoint("TOPRIGHT", card.frame, "TOPRIGHT", -62, -16)
        card.amount:SetJustifyH("RIGHT")
        card.track = card.frame:CreateTexture(nil, "BORDER")
        card.track:SetTexture(K.theme.white); card.track:SetVertexColor(unpack(K.theme.chart.axis))
        card.track:SetHeight(7); card.track:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 44, -18)
        card.fill = card.frame:CreateTexture(nil, "ARTWORK")
        card.fill:SetTexture(K.theme.white); card.fill:SetHeight(7)
        card.fill:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 44, -18)
        card.chance = K.Label(card.frame, "", 0, -16, 56)
        card.chance:ClearAllPoints(); card.chance:SetPoint("TOPRIGHT", card.frame, "TOPRIGHT", -4, -16)
        card.line = K.Label(card.frame, "", 44, -29, 178); card.line:SetHeight(12)
        card.frame:Hide(); view.cards[i] = card
        view.scroll:Wheel(card.frame)
    end
    return view
end
function OutcomeList:SetProps(props)
    if not self.props or self.props.source ~= props.source or self.props.target ~= props.target then self.scroll.offset = 0 end
    if self.focus and self.focus.source ~= props.source then self.focus = nil end
    self.props = props; self:Render()
end
function OutcomeList:Focus(source)
    local focus = self.focus
    if focus and focus.source == (source or (self.props and self.props.source)) then return focus.id end
end
function OutcomeList:Toggle(id)
    if not self.changed or not id or not self.props then return end
    if self:Focus() == id then self.focus = nil else self.focus = {source = self.props.source, id = id} end
    self:Render()
    self.changed(self:Focus())
end
function OutcomeList:Render()
    if not self.props then return end
    local visible = math.max(0, math.min(#self.cards, math.floor((self.frame:GetHeight() or 184) / 46)))
    local outputs = self.props.outputs or {}
    local offset = self.scroll:SetRange(#outputs, visible)
    local width = (self.frame:GetWidth() or 244) - (#outputs > visible and 18 or 0)
    local barWidth = math.max(30, width - 164)
    local focus = self:Focus()
    for i, card in ipairs(self.cards) do
        local output = i <= visible and outputs[offset + i]
        if output then
            card.frame:ClearAllPoints(); card.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -(i - 1) * 46)
            card.frame:SetWidth(width)
            K.SetItemChoice(card.frame, output.id, output.id == (focus or self.props.target))
            local range = output.minCount == output.maxCount and tostring(output.minCount)
                or output.minCount .. "-" .. output.maxCount
            card.amount:SetText(ns.T("deCardCount", range))
            card.name:SetWidth(math.max(50, width - 48))
            card.track:SetWidth(barWidth); card.fill:SetWidth(math.max(2, math.floor(barWidth * output.chance + 0.5)))
            local color = output.chance >= 0.5 and K.theme.chance.high
                or (output.chance >= 0.05 and K.theme.chance.mid or K.theme.chance.low)
            card.fill:SetVertexColor(unpack(color))
            card.chance:SetText(K.Chance(output.chance))
            card.line:SetWidth(math.max(40, width - 48))
            card.line:SetText(ns.T("deCardLine", K.Decimal(output.quantity, 2),
                K.MoneyShort(output.price), K.MoneyShort(output.price and output.quantity * output.price)))
            card.frame.extraTip = (output.id == self.props.target and ns.T("deTargetOutcome") or ns.T("deOtherOutcome"))
            card.frame.tipKeys = self.changed and function()
                return {body = card.frame.extraTip, keys = {{key = ns.T("scanKeyClick"),
                    text = ns.T(output.id == focus and "outcomeBackTip" or "outcomeFocusTip")}}}
            end or nil
        else card.frame:Hide() end
    end
end
local Strip = {ROW = 30, ICON = 26, SMALL = 18, TAIL = 20, GAP = 2, LEFT = 3, PERCENT = 36, VALUE = 84, BAR = 7}
Strip.__index = Strip
K.OutcomeStrip = Strip
local function range(output)
    return output.minCount == output.maxCount and tostring(output.minCount) or output.minCount .. "-" .. output.maxCount
end
function Strip:New(parent, pick)
    local view = setmetatable({rows = {}, icons = {}, pick = pick, height = 0, full = 0, rest = 0, lines = 0}, self)
    view.frame = ns.NewFrame("Frame", nil, parent)
    view.tail = ns.NewFrame("Frame", nil, view.frame)
    view.sum = K.Label(view.tail, "", 0, 0, Strip.VALUE)
    view.sum:SetHeight(12); view.sum:SetJustifyH("RIGHT")
    view.probe = K.Label(view.frame, "", 0, 0, Strip.VALUE)
    view.probe:SetHeight(12); view.probe:SetAlpha(0)
    view.frame:Hide(); view.tail:Hide()
    return view
end
function Strip.RowHeight()
    return math.max(Strip.ROW, 2 * K.FontHeight(12) + 5)
end
function Strip.Split(count, room, row, first, second)
    if not room or count * row <= room then return count, 0 end
    local least, leastLines
    for full = count - 1, 1, -1 do
        local rest = count - full
        if rest <= first + second then
            local lines = rest <= first and 1 or 2
            if full * row + Strip.GAP + lines * Strip.TAIL <= room then return full, lines end
            least, leastLines = full, lines
        end
    end
    if least then return least, leastLines end
    return count, 0
end
function Strip:Row(i)
    local row = self.rows[i]
    if row then return row end
    row = {}
    row.frame = K.ItemChoice(self.frame, function(b) self:Pick(b.itemID) end)
    local f = row.frame
    f.text:Hide()
    f.icon:SetWidth(Strip.ICON); f.icon:SetHeight(Strip.ICON)
    f.icon:ClearAllPoints(); f.icon:SetPoint("LEFT", f, "LEFT", Strip.LEFT, 0)
    row.count = K.BindFont(K.Label(f, "", 0, 0, Strip.ICON + 8), "count")
    row.count:ClearAllPoints(); row.count:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", 1, 0)
    row.count:SetJustifyH("RIGHT"); row.count:SetTextColor(unpack(K.theme.text))
    row.track = f:CreateTexture(nil, "BORDER")
    row.track:SetTexture(K.theme.white); row.track:SetHeight(Strip.BAR)
    row.fill = f:CreateTexture(nil, "ARTWORK")
    row.fill:SetTexture(K.theme.white); row.fill:SetHeight(Strip.BAR)
    row.chance = K.Label(f, "", 0, 0, Strip.PERCENT)
    row.unit = K.Label(f, "", 0, 0, 120, "secondary")
    row.value = K.Label(f, "", 0, 0, Strip.VALUE)
    row.value:SetJustifyH("RIGHT")
    row.value:ClearAllPoints(); row.value:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    self.rows[i] = row
    return row
end
function Strip:Icon(i)
    local b = self.icons[i]
    if b then return b end
    b = K.ItemChoice(self.tail, function(button) self:Pick(button.itemID) end)
    b.text:Hide()
    b:SetWidth(Strip.SMALL); b:SetHeight(Strip.SMALL)
    b.icon:SetDrawLayer("BORDER")
    b.icon:SetWidth(Strip.SMALL); b.icon:SetHeight(Strip.SMALL)
    b.icon:ClearAllPoints(); b.icon:SetPoint("LEFT", b, "LEFT", 0, 0)
    self.icons[i] = b
    return b
end
function Strip:Pick(id)
    if self.pick and id then self.pick(id) end
end
function Strip:SetProps(props)
    self.props = props; self:Render()
end
function Strip:Bind(b, output)
    local p = self.props
    local focused = output.id == p.focus
    K.SetItemChoice(b, output.id, output.id == (p.focus or p.target))
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local body = p.tips and (output.id == p.target and p.tips.target or p.tips.other) or nil
    b.extraTip = body
    if self.pick then
        b.tipKeys = function()
            return {body = body, keys = {{key = ns.T("scanKeyClick"), text = ns.T(focused and "outcomeBackKey" or "outcomeFocusKey")}}}
        end
    else b.tipKeys = nil end
end
function Strip:Measure(text, width)
    local probe = self.probe
    probe:SetWidth(width); probe:SetText(text)
    local measured = probe:GetStringWidth()
    if not measured or measured < 1 then return Strip.VALUE end
    return math.ceil(measured) + 2
end
function Strip:Render()
    local p = self.props
    if not p then return end
    local order = K.OutcomeOrder(p.outputs or {})
    local count, width = #order, p.width
    if count == 0 then
        self.height, self.full, self.rest, self.lines = 0, 0, 0, 0
        self.frame:Hide()
        return
    end
    self.frame:Show()
    local total, valueWidth
    for _, item in ipairs(order) do
        if item.value then total = (total or 0) + item.value end
        valueWidth = math.max(valueWidth or 0, self:Measure(K.Money(item.value), width))
    end
    valueWidth = math.min(math.max(valueWidth, self:Measure(K.Money(total), width)), math.floor(width * 0.45))
    local height, step = Strip.RowHeight(), Strip.SMALL + Strip.GAP
    local first = math.max(0, math.floor((width - valueWidth - 6 + Strip.GAP) / step))
    local second = math.max(0, math.floor((width + Strip.GAP) / step))
    local full, lines = Strip.Split(count, p.room, height, first, second)
    local left = Strip.LEFT + Strip.ICON + 6
    local bar = math.max(24, width - left - 4 - Strip.PERCENT - 6 - valueWidth)
    local line = K.FontHeight(12)
    local pad = math.floor((height - 2 * line - 1) / 2)
    local barTop = -pad - math.floor((line - Strip.BAR) / 2)
    for i = 1, full do
        local row, item = self:Row(i), order[i]
        local output, f = item.output, row.frame
        f:ClearAllPoints(); f:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -(i - 1) * height)
        f:SetWidth(width); f:SetHeight(height)
        self:Bind(f, output)
        row.count:SetText(range(output))
        row.track:ClearAllPoints(); row.track:SetPoint("TOPLEFT", f, "TOPLEFT", left, barTop)
        row.track:SetWidth(bar); row.track:SetVertexColor(unpack(K.theme.chart.axis))
        row.fill:ClearAllPoints(); row.fill:SetPoint("TOPLEFT", f, "TOPLEFT", left, barTop)
        row.fill:SetWidth(math.max(2, math.floor(bar * output.chance + 0.5)))
        row.fill:SetVertexColor(unpack(output.chance >= 0.5 and K.theme.chance.high
            or (output.chance >= 0.05 and K.theme.chance.mid or K.theme.chance.low)))
        row.chance:ClearAllPoints(); row.chance:SetPoint("TOPLEFT", f, "TOPLEFT", left + bar + 4, -pad)
        row.chance:SetHeight(line); row.chance:SetText(K.Chance(output.chance))
        row.unit:ClearAllPoints(); row.unit:SetPoint("TOPLEFT", f, "TOPLEFT", left, -pad - line - 1)
        row.unit:SetWidth(bar + 4 + Strip.PERCENT); row.unit:SetHeight(line)
        row.unit:SetText(output.price and ns.T("obtainPerUnit", K.MoneyShort(output.price)) or "")
        row.value:SetWidth(valueWidth); row.value:SetHeight(line)
        row.value:SetText(K.Money(item.value))
        row.value:SetTextColor(unpack(K.theme[item.value and "text" or "secondary"]))
    end
    for i = full + 1, #self.rows do self.rows[i].frame:Hide() end
    local rest, shown = count - full, 0
    if rest > 0 then
        local sum
        for i = 1, rest do
            local item = order[full + i]
            if item.value then sum = (sum or 0) + item.value end
            local onFirst = i <= first
            local index = onFirst and i or i - first
            if onFirst or index <= second then
                shown = i
                local b = self:Icon(i)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", self.tail, "TOPLEFT", (index - 1) * step, -(onFirst and 0 or Strip.TAIL) - 1)
                self:Bind(b, item.output)
            end
        end
        self.tail:ClearAllPoints(); self.tail:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -(full * height + Strip.GAP))
        self.tail:SetWidth(width); self.tail:SetHeight(lines * Strip.TAIL)
        self.sum:ClearAllPoints()
        self.sum:SetPoint("TOPRIGHT", self.tail, "TOPRIGHT", 0, -math.floor((Strip.TAIL - line) / 2))
        self.sum:SetWidth(valueWidth); self.sum:SetHeight(line)
        self.sum:SetText(K.Money(sum))
        self.sum:SetTextColor(unpack(K.theme[sum and "text" or "secondary"]))
        self.tail:Show()
    else self.tail:Hide() end
    for i = shown + 1, #self.icons do self.icons[i]:Hide() end
    self.full, self.rest, self.lines = full, rest, lines
    self.height = full * height + (rest > 0 and Strip.GAP + lines * Strip.TAIL or 0)
    self.frame:SetWidth(width); self.frame:SetHeight(self.height)
end
