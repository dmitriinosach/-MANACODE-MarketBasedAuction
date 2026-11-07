local _, ns = ...
local UI = {props = {fee = 0.05}}
ns.SeasonalUI = UI
function UI:SetProps(props)
    for key, value in pairs(props) do self.props[key] = value end
    self:Render()
end
function UI:RenderBanner(event)
    local status = event and ns.Seasonal.Status(event.key)
    if not status then self.banner:SetProps(nil); return end
    local K = ns.TradeKit
    self.banner.frame:ClearAllPoints()
    self.banner.frame:SetPoint("BOTTOMRIGHT", self.frame, "TOPRIGHT", -K.Table.EDGE, 4)
    self.banner:SetProps({title = ns.T(event.labelKey), status = status.text, tone = status.tone, art = status.art,
        width = self.inspector.width})
end
function UI:Render()
    if not self.frame then return end
    local K, p = ns.TradeKit, self.props
    local event = ns.Seasonal.Event(p.event)
    if self.renderedEvent ~= p.event then
        self.renderedEvent, self.selected = p.event, nil
        self.table:ResetScroll()
    end
    local entries = ns.Seasonal.Items(p.event)
    for _, entry in ipairs(entries) do
        local q = ns.Markets.Quote(entry.raw, true)
        entry.quote = q
        entry.detail = q and not q.vendor and q.at and ns.T("seasonPriceAge", K.Ago(math.max(0, time() - q.at))) or nil
    end
    entries = self.table.sorter:Apply(entries, {
        item = function(entry) return ns.Markets.Name(entry.raw) end,
        price = function(entry) return entry.quote and entry.quote.price end,
        need = function(entry) return entry.count end,
        units = function(entry) return entry.quote and entry.quote.units end,
    })
    local selected
    for _, entry in ipairs(entries) do if entry.raw == self.selected then selected = entry end end
    if not selected then self.selected = nil end
    K.ScreenBody(self.table, self.inspector)
    self.table:SetLines(entries, function(entry, _, columns)
        return {id = entry.raw, quote = entry.quote, columns = columns,
            active = entry.raw == self.selected, detail = entry.detail,
            extraTip = ns.T(entry.noteKey), marginText = ns.T("seasonNeed", entry.count),
            tag = ns.Markets.FromVendor(entry.raw) and ns.T("vendorAvailable") or nil}
    end)
    self:RenderBanner(event)
    self.summary:SetWidth(self.inspector.width - 2 * K.theme.inset)
    if selected then
        self.inspector:SetProps({id = selected.raw})
        for _, label in ipairs(self.labels) do label:Show() end
        local q = selected.quote
        self.price:SetText(K.Money(q and q.price))
        self.observed:SetText(q and not q.vendor and q.at and date("%d.%m %H:%M", q.at) or ns.T("tradeNoPrice"))
        self.summary:SetText((ns.Markets.FromVendor(selected.raw) and ns.T("vendorAvailableTip") .. "\n\n" or "")
            .. ns.T(selected.noteKey))
        self.selectedNeed = selected.count
        local actions = {}
        if not (ns.vendorPrices and ns.vendorPrices[selected.raw]) then
            local buy = K.ActionBand.Buy(selected.raw, nil, selected.count)
            buy.tip = ns.T("seasonBuyAuctionTip")
            actions[1] = buy
        end
        self.band:SetProps({actions = actions})
    else
        self.inspector:Clear()
        self.inspector.rule:Hide()
        for _, label in ipairs(self.labels) do label:Hide() end
        self.selectedNeed = nil
        self.price:SetText(""); self.observed:SetText(""); self.summary:SetText(""); self.band:SetProps({actions = {}})
    end
    local busy = ns.Scan.state.phase ~= "idle" or ns.Buy.Active()
    self.scan:SetBusy(busy and ns.T("batchBusy") or #entries == 0 and ns.T("seasonScanEmpty") or nil)
end
function UI:Bar()
    return self.barFrames
end
function UI:New(parent)
    local K = ns.TradeKit
    local f = ns.NewFrame("Frame", nil, parent); f:SetAllPoints(parent); self.frame = f
    self.props.event = self.props.event or ns.Seasonal.Default()
    ns.Seasonal.RequestCalendar()
    self.inspector = K.Inspector:New(f)
    self.banner = K.Banner:New(f)
    self.scan = K.ScanBarButton(f, {label = ns.T("seasonBar"), kind = "main", body = ns.T("seasonScanTip"),
        run = function(mode) ns.Seasonal.Scan(self.props.event, mode); self:Render() end,
        sources = function() return ns.Seasonal.Targets(self.props.event) end})
    self.barFrames = {self.scan}
    self.table = K.Table:New(f, {
        headers = {{key = "item", text = "tradeItem"}, {key = "price", text = "tradeUnitPrice"},
            {key = "need", text = "seasonNeedHeader"}, {key = "units", text = "seasonSupplyHeader"}},
        columns = function(width, tbl)
            local w = width - tbl:Row("row", 1):Reserve()
            local columns = K.MarketColumns(w)
            columns.units = {w - 96, 96}
            columns.margin = {w - 176, 76}
            columns.price = {w - 290, 110}
            columns.item = {0, w - 290}
            columns.need = columns.margin
            return columns
        end,
        kinds = {row = {new = function(parent)
            return K.MarketRow:New(parent, function(id) self.selected = id; self:Render() end)
        end}},
        sort = {default = {key = "item", desc = false}},
        changed = function() self:Render() end,
        empty = "seasonNoAuctionItems",
    })
    local panel = self.inspector.body
    local priceLabel, observedLabel
    priceLabel, self.price = K.ValueRow(panel, ns.T("collectionPrice"), -48)
    observedLabel, self.observed = K.ValueRow(panel, ns.T("collectionObserved"), -70)
    self.labels = {priceLabel, observedLabel}
    self.summary = K.Label(panel, "", 12, -96, 240); self.summary:SetHeight(200); self.summary:SetJustifyV("TOP")
    self.band = K.ActionBand:For(self.inspector)
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render(); return self
end
