local _, ns = ...
local UI = {props = {fee = 0.05}, rows = {}}
ns.SeasonalUI = UI
local EDGE, RIGHT, CARD, HEAD, TOP, BOTTOM, ROW = 8, 302, 52, -67, 87, 44, 29
local ART = 0.7109375
function UI:SetProps(props)
    if props.event and props.event ~= self.props.event then self.selected = nil; self.scroll.offset = 0 end
    for key, value in pairs(props) do self.props[key] = value end
    self:Render()
end
function UI:RenderHeader(event)
    local K = ns.TradeKit
    if not event then self.title:SetText(""); self.dates:SetText(""); self.art:Hide(); return end
    self.title:SetText(ns.T(event.labelKey))
    local dates = ns.Seasonal.Dates(event.key)
    if dates then
        local to = date("%d.%m", dates.to)
        self.dates:SetText(dates.days <= 0 and ns.T("seasonDatesNow", to)
            or ns.T("seasonDatesNext", date("%d.%m", dates.from), to, dates.days))
    else
        self.dates:SetText(ns.T(event.timingKey))
    end
    K.Tooltip(self.header, ns.T(event.labelKey), ns.T(event.timingKey) .. "\n\n" .. ns.T("seasonDatesTip"))
    if dates and dates.texture then
        local band = ART * (CARD - 2) / 150
        self.art:SetTexture(dates.texture)
        self.art:SetTexCoord(0, ART, (ART - band) / 2, (ART + band) / 2)
        ns.Gradient(self.art, "HORIZONTAL", 1, 1, 1, 0.75, 1, 1, 1, 0)
        self.art:Show()
    else self.art:Hide() end
end
function UI:Render()
    if not self.frame then return end
    local K, p = ns.TradeKit, self.props
    local event = ns.Seasonal.Event(p.event)
    self:RenderHeader(event)
    local entries = ns.Seasonal.Items(p.event)
    for _, entry in ipairs(entries) do
        local q = ns.Markets.Quote(entry.raw, true)
        local detail = ns.T(entry.noteKey)
        if q and not q.vendor and q.at then detail = detail .. ns.T("cacheAge", math.max(0, math.floor((time() - q.at) / 60))) end
        entry.quote, entry.detail = q, detail
    end
    entries = self.sorter:Apply(entries, {
        item = function(entry) return ns.Markets.Name(entry.raw) end,
        price = function(entry) return entry.quote and entry.quote.price end,
        need = function(entry) return entry.count end,
        units = function(entry) return entry.quote and entry.quote.units end,
    })
    self.sorter:Mark()
    local width = (self.frame:GetWidth() or 996) - RIGHT - EDGE
    local columns = K.MarketColumns(width - self.rows[1]:Reserve())
    columns.need = columns.margin
    K.PlaceHeaders(self.headers, columns, self.frame, HEAD)
    local offset = self.scroll:SetRange(#entries, K.ListCapacity(self.frame, TOP, BOTTOM, ROW, #self.rows))
    local selected
    for _, entry in ipairs(entries) do if entry.raw == self.selected then selected = entry end end
    if not selected then selected = entries[1]; self.selected = selected and selected.raw end
    for i, row in ipairs(self.rows) do
        local entry = entries[offset + i]
        if i > self.scroll.visible then entry = nil end
        if entry then
            row:SetProps({id = entry.raw, quote = entry.quote, width = width, reveal = true,
                active = entry.raw == self.selected, detail = entry.detail, extraTip = ns.T(entry.noteKey),
                marginText = ns.T("seasonNeed", entry.count),
                tag = ns.Markets.FromVendor(entry.raw) and ns.T("vendorAvailable") or nil})
        else row.frame:Hide() end
    end
    self.empty:SetText(#entries == 0 and ns.T("seasonNoAuctionItems") or "")
    if selected then
        self.inspector:SetProps({id = selected.raw})
        local q = selected.quote
        self.price:SetText(K.Money(q and q.price))
        self.observed:SetText(q and not q.vendor and q.at and date("%d.%m %H:%M", q.at) or ns.T("tradeNoPrice"))
        self.summary:SetText((ns.Markets.FromVendor(selected.raw) and ns.T("vendorAvailableTip") .. "\n\n" or "")
            .. ns.T(selected.noteKey))
        self.selectedNeed = selected.count
        local available = q and not q.vendor and q.price and (q.units or 0) > 0
        self.buy:SetText(ns.T(available and "seasonBuyAuction" or "seasonSearchAuction"))
        K.FitButton(self.buy, 24)
        self.buy.tipTitle = self.buy:GetText()
        if ns.vendorPrices and ns.vendorPrices[selected.raw] then self.buy:Hide() else self.buy:Show() end
        if ns.Scan.state.phase == "idle" and not ns.Buy.Active() then self.buy:Enable() else self.buy:Disable() end
    else
        self.inspector:Clear()
        self.selectedNeed = nil
        self.price:SetText(""); self.observed:SetText(""); self.summary:SetText(""); self.buy:Hide()
    end
    if #entries > 0 and ns.Scan.state.phase == "idle" and not ns.Buy.Active() then self.scan:Enable() else self.scan:Disable() end
end
function UI:BuildHeader(f)
    local K = ns.TradeKit
    local header = K.Card(f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", EDGE, -2)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -RIGHT, -2)
    header:SetHeight(CARD); header:EnableMouse(true)
    self.header = header
    local art = K.Picture(header, nil, "BORDER")
    art:ClearAllPoints()
    art:SetPoint("TOPLEFT", header, "TOPLEFT", 1, -1)
    art:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 1, 1)
    art:SetWidth(150)
    self.art = art
    self.title = K.Label(header, "", 14, -10, 420, "title")
    self.dates = K.Label(header, "", 14, -30, 520)
    self.scan = K.Button(header, ns.T("seasonScan"), 140, function()
        ns.Seasonal.Scan(self.props.event, K.ScanMode()); self:Render()
    end, "main")
    self.scan:SetPoint("RIGHT", header, "RIGHT", -12, 0)
    K.ScanTip(self.scan, ns.T("seasonScan"), ns.T("seasonScanTip"), function()
        return ns.Seasonal.Targets(self.props.event)
    end)
end
function UI:New(parent)
    local K = ns.TradeKit
    local f = ns.NewFrame("Frame", nil, parent); f:SetAllPoints(parent); self.frame = f
    self.props.event = self.props.event or ns.Seasonal.Default()
    ns.Seasonal.RequestCalendar()
    self:BuildHeader(f)
    K.TableHeader(f, HEAD)
    self.headers = {}
    for _, entry in ipairs({{"item", "tradeItem"}, {"price", "tradeUnitPrice"},
        {"need", "seasonNeedHeader"}, {"units", "tradeUnits"}}) do
        self.headers[entry[1]] = K.Label(f, ns.T(entry[2]), 0, HEAD, 100)
        if entry[1] ~= "item" then self.headers[entry[1]]:SetJustifyH("RIGHT") end
    end
    self.sorter = K.Sorter(f, self.headers, function() self.scroll.offset = 0; self:Render() end, nil, {key = "item", desc = false})
    self.scroll = K.TableScroll(f, function() self:Render() end, TOP, BOTTOM, ROW)
    for i = 1, 40 do
        local row = K.MarketRow:New(f, function(id) self.selected = id; self:Render() end)
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -TOP - (i - 1) * ROW)
        row.frame:SetHeight(ROW - 1); self.rows[i] = row; self.scroll:Wheel(row.frame)
    end
    self.empty = K.Label(f, "", 10, -TOP - 10, 440); self.empty:SetHeight(64)
    self.inspector = K.Inspector:New(f)
    local panel = self.inspector.body
    local _
    _, self.price = K.ValueRow(panel, ns.T("collectionPrice"), -48)
    _, self.observed = K.ValueRow(panel, ns.T("collectionObserved"), -70)
    self.buy = K.Button(panel, ns.T("seasonSearchAuction"), 140, function()
        if self.selected then ns.Trader.OpenBuy(self.selected, self.selectedNeed) end
    end)
    self.buy:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -96)
    K.Tooltip(self.buy, ns.T("seasonSearchAuction"), ns.T("seasonBuyAuctionTip"))
    self.summary = K.Label(panel, "", 12, -130, 240); self.summary:SetHeight(200); self.summary:SetJustifyV("TOP")
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render(); return self
end
