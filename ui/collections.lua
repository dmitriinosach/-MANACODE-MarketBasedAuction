local _, ns = ...
local UI = {props = {mode = "favorites"}}
ns.CollectionsUI = UI
function UI:SetProps(props)
    for key, value in pairs(props) do if key ~= "fee" then self.props[key] = value end end
    self.selected = nil; self.table:ResetScroll(); self:Render()
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
    entries = self.table.sorter:Apply(entries, {
        item = function(entry) return ns.Markets.Name(entry.raw) end,
        price = function(entry) return entry.quote and entry.quote.price end,
        margin = function(entry) return entry.margin end,
        units = function(entry) return entry.quote and entry.quote.units end,
    })
    self.mode:Select(p.mode)
    if p.mode == "tracked" then self.addFilter:Show() else self.addFilter:Hide() end
    self.sectionHead:SetProps({lead = self.mode.frame, filters = p.mode == "tracked" and {self.addFilter} or nil})
    local selected
    for _, entry in ipairs(entries) do if entry.raw == self.selected then selected = entry end end
    if not selected then selected = entries[1]; self.selected = selected and selected.raw end
    K.ScreenBody(self.table, self.inspector, self.sectionHead)
    self.table:SetLines(entries, function(entry, _, columns)
        return {id = entry.raw, quote = entry.quote, columns = columns,
            active = entry.raw == self.selected, detail = entry.detail, margin = entry.margin,
            tag = ns.Markets.FromVendor(entry.raw) and ns.T("vendorAvailable") or nil}
    end)
    if selected then
        self.inspector:SetProps({id = selected.raw})
        local q = ns.Markets.Quote(selected.raw)
        self.price:SetText(K.Money(q and q.price))
        self.observed:SetText(q and not q.vendor and date("%d.%m %H:%M", q.at) or ns.T("tradeNoPrice"))
        self.summary:SetText(ns.T("collectionHistoryHint"))
        local id, actions = selected.raw, {K.ActionBand.Buy(selected.raw)}
        if C.CanFavorite(id) then
            actions[2] = {key = "recipe", label = ns.T("collectionOpenRecipe"), tip = ns.T("collectionOpenRecipeTip"),
                fn = function() C.OpenRecipe(id) end}
        end
        self.band:SetProps({actions = actions})
    else
        self.inspector:Clear()
        self.summary:SetText(ns.T("collectionActionsTip")); self.band:SetProps({actions = {}})
        self.price:SetText(""); self.observed:SetText("")
    end
    self.scan:SetBusy((ns.Scan.state.phase ~= "idle" or ns.Buy.Active()) and ns.T("batchBusy") or nil)
end
function UI:Bar()
    return self.barFrames
end
function UI:New(parent)
    local K = ns.TradeKit
    local f = ns.NewFrame("Frame", nil, parent); f:SetAllPoints(parent); self.frame = f
    self.mode = K.Segment(f, {{key = "favorites", label = ns.T("collectionFavorites")},
        {key = "tracked", label = ns.T("collectionTracked")}},
        function(mode) self:SetProps({mode = mode}) end, {ns.T("collectionTitle"), ns.T("collectionFavoriteHint")})
    self.sectionHead = K.SectionHead:New(f)
    self.addFilter = ns.NewFrame("Frame", nil, f)
    self.addFilter:SetWidth(310); self.addFilter:SetHeight(22)
    self.input = K.Edit(self.addFilter, 220); self.input:SetPoint("TOPLEFT", self.addFilter, "TOPLEFT", 0, 0)
    K.Tooltip(self.input, ns.T("collectionTracked"), ns.T("collectionInputTip"))
    local function add()
        if not ns.Collections.Add(self.input:GetText()) then ns.say(ns.T("collectionInvalid"), "bad"); return end
        self.input:SetText(""); self.input:ClearFocus(); self:Render()
    end
    self.input:SetScript("OnEnterPressed", add)
    self.add = K.Button(self.addFilter, ns.T("collectionAdd"), 84, add)
    self.add:SetPoint("LEFT", self.input, "RIGHT", 6, 0)
    K.Tooltip(self.add, ns.T("collectionAdd"), ns.T("collectionAddTip"))
    self.scan = K.ScanBarButton(f, {label = ns.T("collectionBar"), kind = "main", body = ns.T("collectionScanTip"),
        run = function(mode) ns.Collections.Scan(self.props.mode, mode); self:Render() end,
        sources = function() return ns.Collections.Targets(self.props.mode) end})
    self.barFrames = {self.scan}
    self.inspector = K.Inspector:New(f)
    self.table = K.Table:New(f, {
        headers = {{key = "item", text = "tradeItem"}, {key = "price", text = "tradeUnitPrice"},
            {key = "margin", text = "familyMargin"}, {key = "units", text = "tradeUnits"}},
        columns = function(width, tbl)
            local columns = K.MarketColumns(width - tbl:Row("row", 1):Reserve())
            return columns
        end,
        kinds = {row = {new = function(parent)
            return K.MarketRow:New(parent, function(id) self.selected = id; self:Render() end)
        end}},
        sort = {default = {key = "item", desc = false}},
        changed = function() self:Render() end,
        empty = "collectionEmpty",
    })
    local panel = self.inspector.body
    local label
    label, self.price = K.ValueRow(panel, ns.T("collectionPrice"), -48)
    label, self.observed = K.ValueRow(panel, ns.T("collectionObserved"), -70)
    self.summary = K.Label(panel, "", 12, -98, 240); self.summary:SetHeight(200); self.summary:SetJustifyV("TOP")
    self.band = K.ActionBand:For(self.inspector)
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render(); return self
end
