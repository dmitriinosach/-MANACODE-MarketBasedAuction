local _, ns = ...
local UI = {props = {mode = "favorites"}, rows = {}}
ns.CollectionsUI = UI
function UI:SetProps(props)
    for key, value in pairs(props) do if key ~= "fee" then self.props[key] = value end end
    self.selected = nil; self.scroll.offset = 0; self:Render()
end
function UI:Render()
    if not self.frame then return end
    local K, C, p = ns.TradeKit, ns.Collections, self.props
    local entries = C.Items(p.mode)
    for _, entry in ipairs(entries) do
        local q, margin = ns.Markets.Quote(entry.raw)
        local recipe, family = ns.Crafting.byItem[entry.raw], ns.gemByItem[entry.raw]
        local detail = ""
        if recipe then
            margin = ns.CraftPlan.Build(recipe, {fee = ns.Fee()}).margin
            detail = ns.T(ns.craftCatalogs[recipe.profession].labelKey)
        elseif family and family.raw ~= entry.raw then
            local raw = ns.Markets.Quote(family.raw)
            if q and q.price and raw and raw.price and q.miss == 0 and raw.miss == 0 then margin = q.price * (1 - ns.Fee()) - raw.price end
            detail = ns.T("jewelrySection")
        end
        if q and not q.vendor then detail = detail .. ns.T("cacheAge", math.max(0, math.floor((time() - q.at) / 60))) end
        entry.quote, entry.margin, entry.detail = q, margin, detail
    end
    entries = self.sorter:Apply(entries, {
        item = function(entry) return ns.Markets.Name(entry.raw) end,
        price = function(entry) return entry.quote and entry.quote.price end,
        margin = function(entry) return entry.margin end,
        units = function(entry) return entry.quote and entry.quote.units end,
    })
    self.sorter:Mark()
    self.mode.frame:SetText(ns.T(p.mode == "favorites" and "collectionFavorites" or "collectionTracked"))
    if p.mode == "tracked" then
        self.input:Show(); self.add:Show()
    else
        self.input:Hide(); self.add:Hide()
    end
    local width = (self.frame:GetWidth() or 996) - 310
    local columns = K.MarketColumns(width - self.rows[1]:Reserve())
    K.PlaceHeaders(self.headers, columns, self.frame, -74)
    local offset = self.scroll:SetRange(#entries, K.ListCapacity(self.frame, 94, 56, 29, #self.rows))
    local selected
    for _, entry in ipairs(entries) do if entry.raw == self.selected then selected = entry end end
    if not selected then selected = entries[1]; self.selected = selected and selected.raw end
    for i, row in ipairs(self.rows) do
        local entry = entries[offset + i]
        if i > self.scroll.visible then entry = nil end
        if entry then
            row:SetProps({id = entry.raw, quote = entry.quote, margin = entry.margin, width = width,
                active = entry.raw == self.selected, detail = entry.detail,
                tag = ns.Markets.FromVendor(entry.raw) and ns.T("vendorAvailable") or nil})
        else row.frame:Hide() end
    end
    self.empty:SetText(#entries == 0 and ns.T("collectionEmpty") or "")
    if selected then
        self.inspector:SetProps({id = selected.raw})
        local q = ns.Markets.Quote(selected.raw)
        self.price:SetText(K.Money(q and q.price))
        self.observed:SetText(q and not q.vendor and date("%d.%m %H:%M", q.at) or ns.T("tradeNoPrice"))
        self.summary:SetText(ns.T("collectionHistoryHint"))
        if C.CanFavorite(selected.raw) then self.open:Show() else self.open:Hide() end
        self.buy:Enable()
    else
        self.inspector:Clear()
        self.summary:SetText(ns.T("collectionActionsTip")); self.open:Hide(); self.buy:Disable()
        self.price:SetText(""); self.observed:SetText("")
    end
    if ns.Scan.state.phase == "idle" and not ns.Buy.Active() then self.scan:Enable() else self.scan:Disable() end
end
function UI:New(parent)
    local K = ns.TradeKit
    local f = ns.NewFrame("Frame", nil, parent); f:SetAllPoints(parent); self.frame = f
    self.mode = K.Menu(f, {{key = "favorites", labelKey = "collectionFavorites"},
        {key = "tracked", labelKey = "collectionTracked"}},
        function(mode) self:SetProps({mode = mode}) end)
    self.mode.frame:SetWidth(120); self.mode.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -3)
    self.input = K.Edit(f, 220); self.input:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -36)
    K.Tooltip(self.input, ns.T("collectionTracked"), ns.T("collectionInputTip"))
    local function add()
        if not ns.Collections.Add(self.input:GetText()) then ns.say(ns.T("collectionInvalid")); return end
        self.input:SetText(""); self.input:ClearFocus(); self:Render()
    end
    self.input:SetScript("OnEnterPressed", add)
    self.add = K.Button(f, ns.T("collectionAdd"), 84, add)
    self.add:SetPoint("LEFT", self.input, "RIGHT", 6, 0)
    K.Tooltip(self.mode.frame, ns.T("collectionTitle"), ns.T("collectionFavoriteHint"))
    self.scan = K.Button(f, ns.T("collectionScan"), 140, function()
        ns.Collections.Scan(self.props.mode, K.ScanMode()); self:Render()
    end, "main")
    self.scan:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -282, 4)
    K.ScanTip(self.scan, ns.T("collectionScan"), ns.T("collectionScanTip"), function()
        return ns.Collections.Targets(self.props.mode)
    end)
    K.TableHeader(f, -74)
    self.headers = {}
    for _, entry in ipairs({{"item", "tradeItem"}, {"price", "tradeUnitPrice"},
        {"margin", "familyMargin"}, {"units", "tradeUnits"}}) do
        self.headers[entry[1]] = K.Label(f, ns.T(entry[2]), 0, -74, 100)
        if entry[1] ~= "item" then self.headers[entry[1]]:SetJustifyH("RIGHT") end
    end
    self.sorter = K.Sorter(f, self.headers, function() self.scroll.offset = 0; self:Render() end, nil, {key = "item", desc = false})
    self.scroll = K.TableScroll(f, function() self:Render() end, 94, 56, 29)
    for i = 1, 40 do
        local row = K.MarketRow:New(f, function(id) self.selected = id; self:Render() end)
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -94 - (i - 1) * 29)
        row.frame:SetHeight(28); self.rows[i] = row; self.scroll:Wheel(row.frame)
    end
    self.empty = K.Label(f, "", 10, -104, 440); self.empty:SetHeight(64)
    self.buy = K.Button(f, ns.T("tradeBuy"), 84, function() if self.selected then ns.Trader.OpenBuy(self.selected) end end)
    self.buy:SetPoint("RIGHT", self.scan, "LEFT", -6, 0)
    self.inspector = K.Inspector:New(f)
    local panel = self.inspector.body
    local label
    label, self.price = K.ValueRow(panel, ns.T("collectionPrice"), -48)
    label, self.observed = K.ValueRow(panel, ns.T("collectionObserved"), -70)
    self.summary = K.Label(panel, "", 12, -98, 240); self.summary:SetHeight(200); self.summary:SetJustifyV("TOP")
    self.open = K.Button(panel, ns.T("collectionOpenRecipe"), 150, function() if self.selected then ns.Collections.OpenRecipe(self.selected) end end)
    self.open:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 8)
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render(); return self
end
