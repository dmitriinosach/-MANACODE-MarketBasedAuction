local _, ns = ...
local UI = {props = {profession = "alchemy", page = 1}}
ns.ResaleUI = UI
function UI:SetProps(props)
    if props.profession and props.profession ~= self.props.profession then
        self.props.id = nil
        if self.table then self.table:ResetScroll() end
    end
    for key, value in pairs(props) do if key ~= "fee" then self.props[key] = value end end
    self:Render()
end
function UI:Bar()
    return self.barFrames
end
function UI:Controls()
    if not self.frame then return end
    self.scan:SetBusy(ns.Trader.Busy() and ns.T("batchBusy") or nil)
    local id = self.inspector.props and self.props.id
    self.band:SetProps({actions = id and {ns.TradeKit.ActionBand.Buy(id)} or {}})
end
function UI:Render()
    if not self.frame then return end
    local K, p = ns.TradeKit, self.props
    local fee = ns.Fee()
    local items = self.table.sorter:Apply(ns.Resale.Items(p.profession), {
        item = function(entry) return ns.Markets.Name(entry.raw) end,
        price = function(entry) local q = ns.Markets.Quote(entry.raw); return q and q.price end,
        margin = function(entry) return ns.Resale.Estimate(entry, fee).margin end,
        units = function(entry) local q = ns.Markets.Quote(entry.raw); return q and q.units end,
    })
    if not p.id or not ns.Resale.byItem[p.id] or ns.Resale.byItem[p.id].profession ~= p.profession then
        p.id = items[1] and items[1].raw
    end
    ns.TradeKit.ScreenBody(self.table, self.inspector)
    self.table:SetLines(items, function(entry, _, columns)
        local estimate = ns.Resale.Estimate(entry, fee)
        local quote = ns.Markets.Quote(entry.raw)
        local detail = ns.T("vendorResaleCost", K.Money(entry.buy))
        if quote then detail = detail .. ns.T("cacheAge", math.max(0, math.floor((time() - quote.at) / 60))) end
        return {id = entry.raw, columns = columns, active = entry.raw == p.id,
            quote = quote, margin = estimate.margin, detail = detail}
    end)
    local selected = p.id and ns.Resale.byItem[p.id]
    if selected then
        self.inspector:SetProps({id = p.id})
        local estimate = ns.Resale.Estimate(selected, ns.Fee())
        local amounts = {estimate.cost, estimate.revenue, estimate.margin, estimate.breakEven}
        self.valueLabels[2]:SetText(ns.T("resaleRevenue", math.floor(ns.Fee() * 100 + 0.5)))
        for i, value in ipairs(self.values) do value:SetText(K.Money(amounts[i])) end
        self.values[3]:SetTextColor(unpack(K.theme[K.Tone(estimate.margin)]))
        local vendor = ns.Resale.Vendor(selected)
        self.location:SetText(vendor and ns.T("vendorResaleWhere", ns.T("vendorNPC" .. vendor.npc),
            ns.T("vendorArea" .. vendor.npc), selected.skill) or ns.T("vendorResaleNoVendor"))
        self.stock:SetText(vendor and (vendor.stock > 0 and ns.T("vendorResaleLimited", vendor.stock)
            or ns.T("vendorResaleUnlimited")) or "")
    else
        self.inspector:Clear(); self.location:SetText(""); self.stock:SetText("")
        for _, value in ipairs(self.values) do value:SetText("") end
    end
    self:Controls()
end
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent)
    local f = self.frame
    f:SetAllPoints(parent)
    self.scan = K.ScanBarButton(f, {label = ns.T("vendorResaleBarRecipes"),
        run = function(mode)
            ns.Resale.Complete(self.props.profession, mode); self:Render()
        end,
        sources = function() return ns.Resale.Targets(self.props.profession) end,
        body = ns.T("vendorResaleScanTip")})
    self.scan.tipTitle = ns.T("cacheComplete")
    self.barFrames = {self.scan}
    self.head = {filters = {}}
    self.inspector = K.Inspector:New(f)
    self.table = K.Table:New(f, {
        headers = {{key = "item", text = "vendorResaleRecipes"}, {key = "price", text = "tradeUnitPrice"},
            {key = "margin", text = "familyMargin"}, {key = "units", text = "tradeUnits"}},
        columns = function(width, tbl) return K.MarketColumns(width - tbl:Row("row", 1):Reserve()) end,
        kinds = {row = {new = function(parent)
            return K.MarketRow:New(parent, function(id) self:SetProps({id = id}) end)
        end}},
        sort = {default = {key = "margin", desc = true}},
        changed = function() self:Render() end,
        empty = "vendorResaleEmpty",
    })
    local panel = self.inspector.body
    self.selection = self.inspector.item
    self.values, self.valueLabels = {}, {}
    for i, key in ipairs({"resaleCost", "resaleRevenue", "resaleMargin", "resaleBreakEven"}) do
        self.valueLabels[i], self.values[i] = K.ValueRow(panel, ns.T(key, math.floor(ns.Fee() * 100 + 0.5)), -48 - (i - 1) * 20, 130, 100)
    end
    self.location = K.Label(panel, "", 12, -134, 240)
    self.location:SetHeight(64); self.location:SetJustifyV("TOP")
    self.stock = K.Label(panel, "", 12, -204, 240)
    self.stock:SetHeight(26); self.stock:SetJustifyV("TOP")
    self.band = K.ActionBand:For(self.inspector)
    self.inspector:SetInfo(ns.T("vendorResaleCategory"), ns.T("vendorResaleTip") .. "\n\n" .. ns.T("vendorResaleCaveat"))
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
