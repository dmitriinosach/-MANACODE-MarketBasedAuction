local _, ns = ...
local B = {days = 7, mode = "line", all = {}}
B.__index = B
ns.MarketBoardUI = B
local function money(value)
    return ns.TradeKit.Money(value)
end
local function count(value)
    return tostring(math.floor(value + 0.5))
end
local function direction(board)
    local first, last = board.first, board.last
    if first and last and first ~= last and first.price > 0 then
        local delta = (last.price / first.price - 1) * 100
        return delta, delta > 0.05 and "positive" or (delta < -0.05 and "negative" or nil)
    end
    return nil, nil
end
local function tiles(board)
    local C = ns.TradeKit.theme.chart
    local last, quote = board.last, board.quote
    local price = last and last.price or (quote and quote.price)
    local delta, tone = direction(board)
    local change = delta and ns.T("boardChange", ns.TradeKit.Decimal(delta, 1, true), board.days) or nil
    local supply, supplyNote = board.supply, ns.T("boardSupplyMissing")
    if supply and board.supplyFirst and board.supplyFirst ~= supply and (board.supplyFirst.units or 0) > 0 then
        supplyNote = ns.T("boardSupplyChange", supply.lots or 0, ((supply.units or 0) / board.supplyFirst.units - 1) * 100)
    elseif supply then supplyNote = ns.T("boardSupplyLots", supply.lots or 0) end
    local flow = board.compared > 0
    return {
        {title = ns.T("boardPrice"), value = price and money(price) or ns.T("tradeNoPrice"), accent = C.minimum,
            note = change or ns.T("boardChangeMissing"), tone = tone, tip = ns.T("boardPriceTip")},
        {title = ns.T("boardMedian"), value = board.median and money(board.median) or ns.T("boardDash"), accent = C.median,
            note = ns.T("boardObservations", board.count), tip = board.low and ns.T("boardMedianTip", money(board.low), money(board.high))
            or ns.T("boardMedianEmpty")},
        {title = ns.T("boardVolatility"), value = board.volatility and ns.T("boardVolatilityValue", ns.TradeKit.Decimal(board.volatility, 1)) or ns.T("boardDash"),
            accent = C.late, note = ns.T("boardChanges", board.changes), tip = ns.T("boardVolatilityTip")},
        {title = ns.T("boardSupply"), value = supply and ns.T("boardUnits", supply.units or 0) or ns.T("boardDash"),
            accent = C.supply, note = supplyNote, tip = ns.T("boardSupplyTip")},
        {title = ns.T("boardEarly"), value = flow and ns.T("boardLots", board.early) or ns.T("boardDash"), accent = C.early,
            note = flow and ns.T("boardUnitsNote", board.earlyUnits) or ns.T("boardNoFlow"), tip = ns.T("boardEarlyTip")},
        {title = ns.T("boardLate"), value = flow and ns.T("boardLots", board.late) or ns.T("boardDash"), accent = C.late,
            note = flow and ns.T("boardLateNote", board.lateUnits, board.added) or ns.T("boardNoFlow"), tip = ns.T("boardLateTip")},
    }
end
local function tip(bucket)
    local C = ns.TradeKit.theme.chart
    local lines = {
        {ns.T("boardTipMinimum"), bucket.price and money(bucket.price) or ns.T("tradeNoPrice"), C.minimum},
        {ns.T("boardTipQuartile"), bucket.p25 and money(bucket.p25) or ns.T("tradeNoPrice"), C.quartile},
        {ns.T("boardTipSupply"), bucket.units and ns.T("boardTipSupplyValue", bucket.units, bucket.lots or 0) or ns.T("boardDash"), C.supply},
    }
    if bucket.compared > 0 then
        lines[#lines + 1] = {ns.T("boardTipAdded"), ns.T("boardTipFlowValue", bucket.added, bucket.addedUnits), C.added}
        lines[#lines + 1] = {ns.T("boardTipEarly"), ns.T("boardTipFlowValue", bucket.early, bucket.earlyUnits), C.early}
        lines[#lines + 1] = {ns.T("boardTipLate"), ns.T("boardTipFlowValue", bucket.late, bucket.lateUnits), C.late}
    else lines[#lines + 1] = {ns.T("boardTipNoFlow")} end
    if bucket.points > 1 then lines[#lines + 1] = {ns.T("boardTipScans", bucket.points)} end
    if bucket.shared then lines[#lines + 1] = {ns.T("boardTipShared")} end
    return date("%d.%m %H:%M", bucket.at), lines
end
function B:New(parent)
    local K = ns.TradeKit
    local view = setmetatable({tiles = {}}, self)
    local f = ns.NewFrame("Frame", nil, parent)
    view.frame = f
    f:SetFrameLevel(parent:GetFrameLevel() + 3); f:EnableMouse(true)
    view.periods = K.Segment(f, {{key = 1, label = ns.T("familyDays", 1)}, {key = 7, label = ns.T("familyDays", 7)},
        {key = 30, label = ns.T("familyDays", 30)}}, function(days) B.days = days; view:Render() end)
    view.periods.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    view.modes = K.Segment(f, {{key = "line", label = ns.T("boardLine")}, {key = "candles", label = ns.T("boardCandles")}},
        function(mode) B.mode = mode; view:Render() end, {ns.T("boardCandles"), ns.T("boardCandlesTip")})
    view.modes.frame:SetPoint("LEFT", view.periods.frame, "RIGHT", 10, 0)
    view.coverage = K.Label(f, "", 0, -5, 300, "secondary"); view.coverage:SetHeight(12)
    view.coverage:ClearAllPoints(); view.coverage:SetPoint("LEFT", view.modes.frame, "RIGHT", 12, 0)
    view.ownNote = K.Label(f, "", 0, -94, 700)
    view.ownNote:SetHeight(16)
    view.help = K.InfoButton(f, ns.T("boardHelpTitle"), ns.T("boardHelp"))
    view.help:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    view.refresh = K.Button(f, ns.T("tradeUpdate"), 90, function()
        if view.props then ns.Markets.Scan(view.props.id) end
    end)
    view.refresh:SetPoint("RIGHT", view.help, "LEFT", -6, 0)
    K.Tooltip(view.refresh, ns.T("cacheRefreshItem"), ns.T("cacheRefreshTip"))
    view.coverage:SetPoint("RIGHT", view.refresh, "LEFT", -8, 0)
    for i = 1, 6 do view.tiles[i] = K.StatTile:New(f) end
    view.chart = K.TimeChart:New(f)
    view.chart.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -94)
    view.chart.frame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 18)
    view.status = K.Label(f, "", 0, 0, 400, "secondary")
    view.status:ClearAllPoints(); view.status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); view.status:SetHeight(12)
    f:SetScript("OnSizeChanged", function() if view.props then view:Layout() end end)
    B.all[#B.all + 1] = view
    return view
end
function B:SetProps(props)
    self.props = props; self.frame:Show(); self:Render()
end
function B:Layout()
    local width = self.frame:GetWidth() or 760
    local tile = math.floor((width - 5 * 8) / 6)
    for i, view in ipairs(self.tiles) do
        view.frame:ClearAllPoints()
        view.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", (i - 1) * (tile + 8), -32)
        if view.props then view.props.width = tile; view:Render() end
    end
    self.status:SetWidth(width)
end
function B:Controls()
    if ns.Scan.state.phase == "idle" and not ns.Buy.Active() and not (ns.vendorPrices and ns.vendorPrices[self.props.id]) then
        self.refresh:Enable()
    else self.refresh:Disable() end
end
function B:Render()
    if not self.props then return end
    local K = ns.TradeKit
    local C = K.theme.chart
    local board = ns.Activity.Board(self.props.id, B.days)
    local own = ns.Accounting and ns.Accounting.Levels(self.props.id)
    local references, markers = {}, {}
    if own and own.cost then
        references = {{value = own.cost, color = C.supply}, {value = own.breakEven, color = C.quartile}}
        self.ownNote:SetWidth(self.frame:GetWidth() or 700)
        self.ownNote:SetText(ns.T("acChartSummary", K.Money(own.cost), K.Money(own.breakEven), own.count))
        self.ownNote:Show()
        K.Tooltip(self.help, ns.T("boardHelpTitle"), ns.T("boardHelp") .. "\n\n"
            .. ns.T("acChartTip", own.count, K.Money(own.cost), K.Money(own.breakEven)))
    else self.ownNote:Hide() end
    for _, sale in ipairs(own and own.sales or {}) do
        if sale.at >= board.to - B.days * 86400 and sale.at <= board.to then
            markers[#markers + 1] = {at = sale.at, value = sale.price, count = sale.count, color = C.added}
            board.from = math.min(board.from, sale.at)
        end
    end
    if #markers > 0 and not (own and own.cost) then
        self.ownNote:SetWidth(self.frame:GetWidth() or 700)
        self.ownNote:SetText(ns.T("acChartSalesCount", #markers)); self.ownNote:Show()
    end
    self.chart.frame:ClearAllPoints()
    self.chart.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, (#references > 0 or #markers > 0) and -116 or -94)
    self.chart.frame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 18)
    self.periods:Select(B.days)
    local candlesAllowed = B.days > 1
    if candlesAllowed then self.modes.frame:Show() else self.modes.frame:Hide() end
    local mode = candlesAllowed and B.mode or "line"
    self.modes:Select(mode)
    for i, props in ipairs(tiles(board)) do self.tiles[i].props = props end
    self:Layout()
    local last = board.points[#board.points]
    self.coverage:SetText(ns.T("boardCoverage", #board.points, board.compared,
        last and ns.T("boardAge", math.max(0, math.floor((time() - last.at) / 60))) or ns.T("boardDash")))
    local delta, tone = direction(board)
    local lineColor = K.theme[tone or "text"]
    self.chart:SetProps({from = board.from, to = board.to, days = B.days, mode = mode,
        candles = function() return ns.Activity.Candles(board, K.DayShift()) end,
        empty = board.count < 2 and #references == 0 and #markers == 0 and ns.T("familyNeedHistory") or nil,
        buckets = function(n) return ns.Activity.Buckets(board, n) end, tip = tip,
        markerTip = function(marker)
            return ns.T("acChartSaleAt", date("%d.%m %H:%M", marker.at)),
                ns.T("acChartSaleDetail", marker.count, money(marker.value))
        end,
        tracks = {
            {kind = "price", weight = 5, title = ns.T("boardTrackPrice"), format = money,
                change = delta and ns.T("boardChange", ns.TradeKit.Decimal(delta, 1, true), board.days) or nil, tone = tone,
                last = board.last and board.last.price or nil,
                references = references, markers = markers,
                extraLegend = #markers > 0 and {{color = C.added, legend = ns.T("acChartSales")}} or nil,
                median = board.median, medianLegend = ns.T("boardLegendMedian"),
                series = {{field = "p25", color = C.quartile, legend = ns.T("boardLegendQuartile"), thick = 1},
                    {field = "price", color = lineColor, legend = ns.T("boardLegendMinimum"), area = true, dots = true}}},
            {kind = "bars", weight = 2, title = ns.T("boardTrackSupply"), format = count,
                series = {{field = "units", color = C.supply}}},
            {kind = "flow", weight = 2, title = ns.T("boardTrackFlow"), format = count,
                series = {{field = "addedUnits", color = C.added, legend = ns.T("boardLegendAdded")}},
                down = {{field = "earlyUnits", color = C.early, legend = ns.T("boardLegendEarly")},
                    {field = "lateUnits", color = C.late, legend = ns.T("boardLegendLate")}}},
        }})
    self:Controls()
end
function B.Status(text)
    for _, view in ipairs(B.all) do
        view.status:SetText(text)
        if view.props then view:Controls() end
    end
end
function B.Refresh()
    for _, view in ipairs(B.all) do
        if view.props and view.frame:IsVisible() then view:Render() end
    end
end
local W = {hosts = {}, names = {}}
ns.MarketWindow = W
function W.Build(host)
    local K = ns.TradeKit
    local modal = K.Modal(host, "ManaCodeMarketWindow" .. (#W.names + 1))
    W.names[#W.names + 1] = modal
    local window = modal.window
    modal.item = K.ItemChoice(window, function() end)
    modal.item:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -8)
    modal.item:SetWidth(420); modal.item.text:SetWidth(380)
    modal.item.text:SetFontObject("GameFontNormal")
    modal.caption = K.Label(window, ns.T("marketWindowTitle"), 0, 0, 200, "secondary")
    modal.caption:SetHeight(12); modal.caption:ClearAllPoints()
    modal.caption:SetPoint("LEFT", modal.item, "RIGHT", 10, 0)
    modal.board = B:New(window)
    modal.board.frame:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -44)
    modal.board.frame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -12, 10)
    W.hosts[host] = modal
    return modal
end
function W.Open(id)
    local trader = ns.Trader and ns.Trader.frame
    local host = trader and trader:IsVisible() and trader or UIParent
    if not host then return end
    local modal = W.hosts[host] or W.Build(host)
    W.frame, W.board = modal, modal.board
    ns.TradeKit.SetItemChoice(modal.item, id, false)
    modal:Show()
    modal.board:SetProps({id = id})
end
function W.Close()
    for _, modal in pairs(W.hosts) do modal:Hide() end
end
function W.IsOpen()
    for _, modal in pairs(W.hosts) do if modal:IsShown() then return true end end
    return false
end
function W.Refresh()
    for _, modal in pairs(W.hosts) do
        if modal:IsShown() and modal.board.props then modal.board:Render() end
    end
end
