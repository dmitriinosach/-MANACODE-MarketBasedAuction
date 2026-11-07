local _, ns = ...
local UI = {props = {mode = "chances"}, list = {}}
ns.BidsUI = UI
local PANEL = 240
local LINES = 8
function UI.Open(key)
    UI.props.mode, UI.props.key = "chances", key
    ns.Trader:ShowSection("bids")
    if UI.frame then UI:Render() end
end
function UI:SetProps(props)
    local p = self.props
    if props.mode and props.mode ~= p.mode then
        p.mode, p.key = props.mode, nil
        self.table:ResetScroll()
        if p.mode == "mine" then ns.Bids.Request() end
    end
    if props.key ~= nil then p.key = props.key end
    self:Render()
end
local function ready()
    return ns.Scan.state.open and ns.Scan.state.phase == "idle" and not ns.Buy.Active()
end
local RISK_TONES = {short = "secondary", long = "accent", ended = "negative"}
function UI.Term(chance, now)
    local risk = ns.Bids.Risk(chance.left, chance.expires, now)
    if risk == "ended" then return ns.T("bidsMayEnded"), RISK_TONES.ended end
    if chance.expires - now < 300 then return ns.T("bidsEndsSoon"), RISK_TONES[risk] end
    return ns.T("bidsLeft" .. (chance.left or 4)), RISK_TONES[risk]
end
function UI.EndsAt(expires, now)
    local day = date("%d.%m", expires) ~= date("%d.%m", now)
    return ns.T("bidsEndsAt", date(day and "%d.%m %H:%M" or "%H:%M", expires))
end
function UI.RiskText(left, expires, seen, now)
    local risk = ns.Bids.Risk(left, expires, now)
    if risk == "ended" then return ns.T("bidsRiskEnded", ns.TradeKit.Ago(math.max(0, now - seen))) end
    return ns.T(risk == "long" and "bidsRiskLong" or "bidsRiskShort", ns.T("bidsLeft" .. (left or 4)))
end
function UI.Source(chance)
    return ns.T(chance.source == "bargain" and "bidsFromBargain" or "bidsFromDisenchant")
end
function UI.ChanceCells(chance, now)
    local K = ns.TradeKit
    return {
        cost = {K.Money(chance.cost)},
        buyout = {chance.lot.buyout > 0 and K.Money(chance.lot.buyout) or ns.T("bidsNoBuyout"), "secondary"},
        value = {K.Money(chance.value), "secondary"},
        profit = {K.Money(chance.profit), K.Tone(chance.profit)},
        ends = {UI.Term(chance, now)},
    }
end
function UI.MineCells(bid)
    local K = ns.TradeKit
    return {
        bid = {K.Money(bid.bid)},
        next = {bid.high and "" or K.Money(bid.next), "secondary"},
        buyout = {bid.buyout > 0 and K.Money(bid.buyout) or ns.T("bidsNoBuyout"), "secondary"},
        state = {ns.T(bid.high and "bidsLeading" or "bidsOutbid"), bid.high and "positive" or "negative"},
        ends = {bid.timeLeft and ns.T("bidsLeft" .. bid.timeLeft) or "", "secondary"},
    }
end
function UI.Raisable(bid)
    return not bid.high and not (bid.buyout > 0 and bid.next >= bid.buyout)
end
function UI:Rows()
    if self.props.mode ~= "mine" then return ns.Bids.Chances() end
    local list = {}
    for _, bid in ipairs(ns.Bids.mine) do if bid.item then list[#list + 1] = bid end end
    return list
end
function UI:Find(key)
    for _, row in ipairs(self.list) do if row.key == key then return row end end
    return nil
end
function UI:Lines(entries)
    local K = ns.TradeKit
    for i = 1, LINES do
        local label, value, entry = self.lineLabels[i], self.lineValues[i], entries[i]
        if entry then
            label:SetText(entry[1]); value:SetText(entry[2])
            value:SetTextColor(unpack(K.theme[entry[3] or "text"]))
            label:Show(); value:Show()
        else label:Hide(); value:Hide() end
    end
    local y = -8 - #entries * K.theme.valueStep - 8
    self.note:ClearAllPoints(); self.note:SetPoint("TOPLEFT", self.body, "TOPLEFT", K.theme.inset, y)
end
function UI:ChancePanel(chance, now)
    local K, lot = ns.TradeKit, chance.lot
    local ended = ns.Bids.Risk(chance.left, chance.expires, now) == "ended"
    local source = UI.Source(chance)
    if chance.group then
        local group = ns.Disenchant.Group(chance.group)
        source = source .. ": " .. (group.targetID and ns.Markets.Name(group.targetID) or ns.T(group.labelKey))
    end
    self:Lines({
        {ns.T("bidsLineSource"), source},
        {ns.T("bidsLineLot"), ns.T("bidsLotValue", lot.count, lot.owner or "")},
        {ns.T("bidsLineBid"), K.Money(chance.cost)},
        {ns.T("bidsLineBuyout"), lot.buyout > 0 and K.Money(lot.buyout) or ns.T("bidsNoBuyout"), "secondary"},
        {ns.T(chance.source == "bargain" and "bidsLineResale" or "bidsLineDisenchant"), K.Money(chance.value)},
        {ns.T("bidsLineProfit"), K.Money(chance.profit) .. " " .. ns.T("bidsPercent", math.floor(chance.percent + 0.5)),
            K.Tone(chance.profit)},
        {ns.T("bidsLineTerm"), UI.Term(chance, now)},
        {ns.T("bidsLineEnds"), ended and ns.T("bidsEndedDetail", K.Ago(math.max(0, now - chance.seen)))
            or ns.T("bidsEndsDetail", UI.EndsAt(chance.expires, now), date("%H:%M", chance.seen)), "secondary"},
    })
    local note = UI.RiskText(chance.left, chance.expires, chance.seen, now) .. "\n\n" .. ns.T("bidsNoteChance")
    if chance.estimate and not chance.estimate.fresh then note = ns.T("bidsNoteStale") .. "\n\n" .. note end
    self.note:SetText(note)
end
function UI:MinePanel(bid)
    local K = ns.TradeKit
    self:Lines({
        {ns.T("bidsLineState"), ns.T(bid.high and "bidsLeading" or "bidsOutbid"), bid.high and "positive" or "negative"},
        {ns.T("bidsLineMine"), K.Money(bid.bid)},
        {ns.T("bidsLineNext"), bid.high and "" or K.Money(bid.next)},
        {ns.T("bidsLineBuyout"), bid.buyout > 0 and K.Money(bid.buyout) or ns.T("bidsNoBuyout"), "secondary"},
        {ns.T("bidsLineLeft"), bid.timeLeft and ns.T("bidsLeft" .. bid.timeLeft) or "", "secondary"},
        {ns.T("bidsLineSeller"), bid.owner or "", "secondary"},
        {ns.T("bidsLineLedger"), ns.T(ns.AccountingEvents.Watching(bid.item, bid.count, bid.owner, bid.buyout)
            and "bidsLedgerOn" or "bidsLedgerOff"), "secondary"},
    })
    self.note:SetText(ns.T(bid.high and "bidsNoteLeading" or "bidsNoteOutbid"))
end
function UI:Bar()
    if self.props.mode == "mine" then return self.barFrames end
end
function UI:Controls()
    if not self.frame then return end
    local K, B, p, row = ns.TradeKit, ns.Bids, self.props, self.selected
    local state = {bid = p.mode ~= "mine", raise = p.mode == "mine", title = ns.T(p.mode == "mine" and "bidsRaiseTitle" or "bidsAct"),
        tip = ns.T(p.mode == "mine" and "bidsRaiseTip" or "bidsActTip")}
    self.action = nil
    if B.Active() then
        local count = ns.Buy.Offer()
        if ns.Buy.state.phase == "ready" and count > 0 then state.confirm = true; self.action = "confirm"
        else state.searching = true end
    elseif row and p.mode == "mine" then
        local raising = B.raise and B.raise.key == row.key
        if row.high then state.reason = ns.T("bidsLeadingTip")
        elseif not UI.Raisable(row) then state.reason = ns.T("bidsRaiseBuyout")
        else state.confirm, self.action = raising or nil, "raise" end
    elseif row then self.action = "place"
    else state.reason = ns.T(p.mode == "mine" and "bidsPickMineTip" or "bidsPickTip") end
    if not state.reason and not state.searching and self.action ~= "confirm" and not ready() then
        state.reason = ns.T(ns.Scan.state.open and "bidsBusyTip" or "bidsClosed")
    end
    self.band:SetProps({actions = {K.BuyAction(state, function() self:Act() end, "bid")}})
    local _, button = self.band:Find("bid")
    self.act = button
    local refreshReason = not ns.Scan.state.open and ns.T("bidsClosed") or ns.Trader.Busy() and ns.T("batchBusy") or nil
    K.DisabledTip(self.refresh, ns.T("bidsRefresh"), refreshReason)
    if refreshReason then self.refresh:Disable() else self.refresh:Enable() end
end
function UI:Render()
    if not self.frame then return end
    local K = ns.TradeKit
    local B, p = ns.Bids, self.props
    local now = time()
    local rows = self:Rows()
    self.list = rows
    local selected = self:Find(p.key) or rows[1]
    self.selected = selected
    local empty = p.mode == "mine" and (B.mineAt and "bidsEmptyMine" or "bidsMineUnknown") or "bidsEmpty"
    K.ScreenBody(self.table, self.inspector, self.sectionHead)
    self.table:SetLines(rows, function(row)
        local open = ready()
        local actions, cells, tag, tone
        local tip = ns.T("bidsRowMineTip")
        if p.mode == "mine" then
            cells = UI.MineCells(row)
            if UI.Raisable(row) then
                actions = {{label = ns.T("bidsActRaise"), tip = ns.T("bidsRaiseTip"), disabled = not open,
                    fn = function(key) self:Act(key) end}}
            end
        else
            cells, tag, tone = UI.ChanceCells(row, now), UI.Source(row), "secondary"
            actions = {{label = ns.T("bidsActPlace"), tip = ns.T("bidsActTip"), disabled = not open,
                fn = function(key) self:Act(key) end}}
            tip = ns.T("bidsRowTip") .. "\n\n" .. UI.RiskText(row.left, row.expires, row.seen, now)
        end
        return {key = row.key, id = row.item, link = row.link, mode = p.mode, cells = cells,
            tag = tag, tagTone = tone, active = selected == row, actions = actions, tip = tip}
    end, {empty = empty})
    if selected then
        self.inspector:SetProps({id = selected.item})
        if p.mode == "mine" then self:MinePanel(selected) else self:ChancePanel(selected, now) end
        self.body:Show()
    else
        self.inspector:Clear()
        self.body:Hide()
    end
    self.modes:Select(p.mode)
    self.panelScroll:Fit(PANEL)
    self.statusText = nil
    ns.Trader.RenderStatus()
    self:Controls()
end
function UI:Act(key)
    local row = self:Find(key or (self.selected and self.selected.key))
    if not row then return end
    self.props.key = row.key
    if self.props.mode == "mine" then ns.Bids.Raise(row) else ns.Bids.Place(row) end
    self:Render()
end
function UI:NewPanel()
    local K = ns.TradeKit
    self.inspector = K.Inspector:New(self.frame)
    self.panelScroll = K.PanelScroll:New(self.inspector, "ManaCodeBidsPanelScroll", PANEL)
    self.band = K.ActionBand:For(self.inspector, self.panelScroll)
    local body = ns.NewFrame("Frame", nil, self.panelScroll.child)
    body:SetAllPoints(self.panelScroll.child)
    self.body = body
    self.inspector:SetInfo(ns.T("bidsTitle"), ns.T("bidsInfo"))
    self.lineLabels, self.lineValues = {}, {}
    for i = 1, LINES do
        self.lineLabels[i], self.lineValues[i] = K.ValueRow(body, "", -8 - (i - 1) * K.theme.valueStep, 100, 140)
    end
    self.note = K.Label(body, "", K.theme.inset, -110, 240, "secondary")
    self.note:SetHeight(110); self.note:SetJustifyV("TOP")
end
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent)
    local f = self.frame
    f:SetAllPoints(parent)
    self.modes = K.Segment(f, {{key = "chances", label = ns.T("bidsChances")}, {key = "mine", label = ns.T("bidsMine")}},
        function(mode) self:SetProps({mode = mode}) end)
    self.sectionHead = K.SectionHead:New(f)
    self.sectionHead:SetProps({lead = self.modes.frame})
    self.refresh = K.Button(f, ns.T("bidsBar"), 80, function() ns.Bids.Request(); self:Render() end, "scan")
    self.refresh:SetHeight(22)
    K.FitButton(self.refresh, 20)
    K.Tooltip(self.refresh, ns.T("bidsRefresh"), ns.T("bidsRefreshTip"))
    self.refresh:Hide()
    self.barFrames = {self.refresh}
    self.table = K.Table:New(f, {
        headers = {{key = "item", text = "bidsColItem"},
            {key = "cost", text = "bidsColCost", tip = "bidsTipCost"},
            {key = "buyout", text = "bidsColBuyout"},
            {key = "value", text = "bidsColValue", tip = "bidsTipValue"},
            {key = "profit", text = "bidsColProfit", tip = "bidsTipProfit"},
            {key = "ends", text = "bidsColEnds", tip = "bidsTipEnds"},
            {key = "bid", text = "bidsColMine"},
            {key = "next", text = "bidsColNext", tip = "bidsTipNext"},
            {key = "state", text = "bidsColState"}},
        columns = function(width) return K.BidColumns(width, self.props.mode) end,
        height = K.Table.LINE,
        kinds = {row = {new = function(parent)
            return K.BidRow:New(parent, function(key) self:SetProps({key = key}) end)
        end}},
    })
    self:NewPanel()
    f:HookScript("OnShow", function()
        ns.Bids.Request()
        self:Render()
    end)
    f:SetScript("OnSizeChanged", function() self:Render() end)
    ns.Bids.onChange = function()
        if self.frame and self.frame:IsVisible() then self:Render() end
    end
    self:Render()
    return self
end
