local _, ns = ...
local UI = {props = {profession = "alchemy", page = 1}, rows = {}}
ns.ResaleUI = UI
function UI:SetProps(props)
    if props.profession and props.profession ~= self.props.profession then
        self.props.id = nil
        if self.scroll then self.scroll.offset = 0 end
    end
    for key, value in pairs(props) do if key ~= "fee" then self.props[key] = value end end
    self:Render()
end
function UI:Controls()
    if not self.frame then return end
    local idle = ns.Scan.state.phase == "idle"
    local ready = idle and not ns.Buy.Active()
    if ready then self.scan:Enable() else self.scan:Disable() end
    if ready and self.props.id then self.buy:Enable() else self.buy:Disable() end
end
function UI:Render()
    if not self.frame then return end
    local K, p = ns.TradeKit, self.props
    local fee = ns.Fee()
    local items = self.sorter:Apply(ns.Resale.Items(p.profession), {
        item = function(entry) return ns.Markets.Name(entry.raw) end,
        price = function(entry) local q = ns.Markets.Quote(entry.raw); return q and q.price end,
        margin = function(entry) return ns.Resale.Estimate(entry, fee).margin end,
        units = function(entry) local q = ns.Markets.Quote(entry.raw); return q and q.units end,
    })
    if not p.id or not ns.Resale.byItem[p.id] or ns.Resale.byItem[p.id].profession ~= p.profession then
        p.id = items[1] and items[1].raw
    end
    local visible = K.ListCapacity(self.frame, 56, 56, 29, #self.rows)
    local offset = self.scroll:SetRange(#items, visible)
    local width = (self.frame:GetWidth() or 996) - 310
    local columns = K.MarketColumns(width - self.rows[1]:Reserve())
    K.PlaceHeaders(self.headers, columns, self.frame, -38)
    self.sorter:Mark()
    for i, row in ipairs(self.rows) do
        local entry = i <= visible and items[offset + i]
        if entry then
            local estimate = ns.Resale.Estimate(entry, ns.Fee())
            local quote = ns.Markets.Quote(entry.raw)
            local detail = ns.T("vendorResaleCost", K.Money(entry.buy))
            if quote then detail = detail .. ns.T("cacheAge", math.max(0, math.floor((time() - quote.at) / 60))) end
            row:SetProps({id = entry.raw, width = width, active = entry.raw == p.id,
                quote = quote, margin = estimate.margin, detail = detail})
        else row.frame:Hide() end
    end
    local selected = p.id and ns.Resale.byItem[p.id]
    self.empty:SetText(#items == 0 and ns.T("vendorResaleEmpty") or "")
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
    K.Label(f, ns.T("vendorResaleRecipes"), 12, -11, 236, "heading")
    self.scan = K.Button(f, ns.T("cacheComplete"), 140, function()
        ns.Resale.Complete(self.props.profession, ns.TradeKit.ScanMode()); self:Render()
    end, "main")
    self.scan:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -282, 4)
    K.ScanTip(self.scan, ns.T("cacheComplete"), ns.T("vendorResaleScanTip"), function()
        return ns.Resale.Targets(self.props.profession)
    end)
    K.TableHeader(f, -38)
    self.headers = {}
    for _, entry in ipairs({{"item", "vendorResaleRecipes"}, {"price", "tradeUnitPrice"},
        {"margin", "familyMargin"}, {"units", "tradeUnits"}}) do
        local label = K.Label(f, ns.T(entry[2]), 0, -38, 100)
        if entry[1] ~= "item" then label:SetJustifyH("RIGHT") end
        self.headers[entry[1]] = label
    end
    self.sorter = K.Sorter(f, self.headers, function() self.scroll.offset = 0; self:Render() end, nil, {key = "margin", desc = true})
    self.scroll = K.TableScroll(f, function() self:Render() end, 56, 56, 29)
    for i = 1, 40 do
        local row = K.MarketRow:New(f, function(id) self:SetProps({id = id}) end)
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -56 - (i - 1) * 29)
        row.frame:SetHeight(28)
        self.rows[i] = row
        self.scroll:Wheel(row.frame)
    end
    self.empty = K.Label(f, "", 10, -66, 370)
    self.empty:SetHeight(60); self.empty:SetJustifyV("TOP")
    self.buy = K.Button(f, ns.T("vendorResaleAuction"), 92, function() ns.Trader.OpenBuy(self.props.id) end)
    self.buy:SetPoint("RIGHT", self.scan, "LEFT", -6, 0)
    self.inspector = K.Inspector:New(f)
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
    self.inspector:SetInfo(ns.T("vendorResaleCategory"), ns.T("vendorResaleTip") .. "\n\n" .. ns.T("vendorResaleCaveat"))
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
