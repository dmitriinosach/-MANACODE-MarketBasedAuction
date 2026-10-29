local _, ns = ...
local K = ns.TradeKit
local OutcomeList = {}
OutcomeList.__index = OutcomeList
K.OutcomeList = OutcomeList
function OutcomeList:New(parent, changed)
    local view = setmetatable({cards = {}, changed = changed}, self)
    view.frame = ns.NewFrame("Frame", nil, parent)
    view.scroll = K.Scroller:New(view.frame, function() view:Render() end, 46)
    view.scroll.frame:SetAllPoints(view.frame)
    for i = 1, 4 do
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
                .. (self.changed and ("\n\n" .. ns.T(output.id == focus and "outcomeBackTip" or "outcomeFocusTip")) or "")
        else card.frame:Hide() end
    end
end
