local _, ns = ...
local UI = {props = {profession = "mining"}, open = {}}
ns.GatheringUI = UI
local OUTCOMES = 12
ns.Hidden.Describe(function(key)
    local profession, id = key:match("^raw:([^:]+):(%d+)$")
    local catalog = profession and ns.gatheringCatalogs[profession]
    if not catalog then return nil end
    return {name = ns.Markets.Name(tonumber(id)), place = ns.T(catalog.labelKey)}
end)
function UI:SetProps(props)
    if props.profession and props.profession ~= self.props.profession then
        self.props.id, self.open = nil, {}
        if self.table then self.table:ResetScroll() end
    end
    for key, value in pairs(props) do self.props[key] = value end
    self:Render()
end
function UI:SetEpoch(expansion, shown)
    ns.Crafting.SetEpoch(self.props.profession, expansion, shown)
    if self.table then self.table:ResetScroll() end
    self:Render()
end
function UI:Hide(id)
    ns.Crafting.HideResource(self.props.profession, id, true)
    if self.props.id == id then self.props.id = nil end
    self.open[id] = nil
    self:Render()
end
function UI:Ways(id)
    local ways, process = {}, ns.Reagents.Process(id)
    if process then
        local estimate = ns.Prospect.Estimate(process.source, ns.Prospect.Price(id), ns.Fee())
        ways[1] = {process = process, estimate = estimate, gain = ns.Crafting.ProcessGain(estimate)}
    end
    for _, use in ipairs(ns.Crafting.Uses(self.props.profession, id)) do ways[#ways + 1] = {use = use, gain = use.gain} end
    table.sort(ways, function(a, b)
        if (a.gain == nil) ~= (b.gain == nil) then return a.gain ~= nil end
        if a.gain and a.gain ~= b.gain then return a.gain > b.gain end
        return (a.process and 0 or a.use.recipe.raw) < (b.process and 0 or b.use.recipe.raw)
    end)
    return ways
end
function UI:Select(id, props)
    if props and props.parent then self.props.id = props.parent; self:Render(); return end
    self.props.id = id
    if #self:Ways(id) > 0 then self.open[id] = not self.open[id] or nil end
    self:Render()
end
function UI:Entries()
    local entries = {}
    for _, id in ipairs(ns.Crafting.Resources(self.props.profession)) do
        local ways = self:Ways(id)
        entries[#entries + 1] = {id = id, ways = #ways > 0 and ways or nil, tree = #ways > 0, depth = 0, process = ns.Reagents.Process(id)}
        if self.open[id] then
            for _, way in ipairs(ways) do
                entries[#entries + 1] = {id = way.use and way.use.recipe.raw or id, way = way, parent = id, depth = 1}
            end
        end
    end
    return entries
end
local function wayName(way)
    if way.process then return ns.T(ns.Prospect.modes[way.process.mode].titleKey) end
    return ns.Markets.Name(way.use.recipe.raw)
end
local function unlearned(way)
    if not way.use then return false end
    local catalog = ns.craftCatalogs[way.use.profession]
    return ns.Recipes.Known(way.use.recipe.spell, ns.T(catalog.labelKey)) == false
end
function UI.Verdict(ways)
    local best = ways[1]
    if not best then return ns.T("resourceNoProcess") end
    if not best.gain then return ns.T("resourceUseNoPrice") end
    if best.gain <= 0 then return ns.T("resourceSellBetter") end
    return ns.T("resourceUseBetter", wayName(best), ns.TradeKit.Money(best.gain))
        .. (unlearned(best) and ns.T("resourceUseUnlearned") or "")
end
function UI:RowProps(entry, columns, go)
    local K, p, way = ns.TradeKit, self.props, entry.way
    local props = {id = entry.id, columns = columns, parent = entry.parent, way = way, active = entry.id == p.id and not entry.parent,
        depth = entry.depth, noGo = not go, extraTip = ns.T("resourceTip")}
    if not way then
        props.quote = ns.Markets.Quote(entry.id)
        props.margin = entry.ways and entry.ways[1].gain or nil
        props.detail = ns.T("modeResources")
        props.expandable, props.crafted, props.hideable = entry.ways ~= nil, self.open[entry.id] ~= nil, true
        if entry.process then props.go = {title = ns.T("resourceDetails"), tip = ns.T("resourceGoTip")} end
    elseif way.process then
        local process = way.process
        props.spell, props.noRefresh, props.margin = ns.Prospect.modes[process.mode].spell, true, way.gain
        props.detail = ns.T("resourceProcess", ns.T(ns.Prospect.modes[process.mode].titleKey), process.count, process.source.skill)
        props.go = {title = ns.T("resourceDetails"), tip = ns.T("resourceGoTip")}
    else
        local use, catalog = way.use, ns.craftCatalogs[way.use.profession]
        props.quote, props.margin = ns.Markets.Quote(entry.id), way.gain
        props.detail = ns.T("resourceUse", ns.T(catalog.labelKey), use.per)
        props.unlearned = unlearned(way) or nil
        props.extraTip = ns.T("resourceUseTip")
        props.go = {title = ns.T("resourceUseGo"), tip = ns.T("resourceUseGoTip")}
    end
    return props
end
function UI:Render()
    if not self.frame then return end
    local K, p = ns.TradeKit, self.props
    local ids, shown = ns.Crafting.Resources(p.profession), false
    for _, id in ipairs(ids) do if id == p.id then shown = true end end
    if not shown then p.id = ids[1] end
    local epochs, counts = ns.Crafting.Epochs(p.profession), ns.Crafting.ResourceCounts(p.profession)
    local present = K.EpochChips.Present(counts)
    if #present == 1 and not epochs[present[1]] then
        ns.Crafting.SetEpoch(p.profession, present[1], true)
        return self:Render()
    end
    self.epochs:SetProps({shown = epochs, counts = counts, tip = function() return ns.T("resourceEpochTip") end})
    self.head = self.head or {}
    if #present > 1 then self.head.filters = {self.epochs.frame}
    else self.head.filters = {}; self.epochs.frame:Hide() end
    local entries, go = self:Entries(), false
    for _, entry in ipairs(entries) do go = go or entry.way ~= nil or entry.process ~= nil end
    ns.TradeKit.ScreenBody(self.table, self.inspector)
    self.table:SetLines(entries, function(entry, _, columns) return self:RowProps(entry, columns, go) end, {noGo = not go})
    self.inspector:SetProps({id = self.outcomes:Focus(p.id) or p.id})
    local q = ns.Markets.Quote(p.id)
    self.sell:SetText(K.Money(q and q.price))
    self.net:SetText(K.Money(q and q.price and q.price * (1 - ns.Fee())))
    local process = ns.Reagents.Process(p.id)
    local e = process and ns.Prospect.Estimate(process.source, ns.Prospect.Price(p.id), ns.Fee())
    self.cost:SetText(K.Money(e and e.cost))
    self.revenue:SetText(K.Money(e and e.exact and e.net or nil))
    self.margin:SetText(K.Money(e and e.exact and e.margin or nil))
    self.margin:SetTextColor(unpack(K.theme[e and e.exact and K.Tone(e.margin) or "text"]))
    local stale = e and e.exact and (not e.fresh or not ns.Prospect.Fresh(p.id))
    self.note:SetText(UI.Verdict(self:Ways(p.id)) .. (stale and "\n" .. ns.T("resourceStale") or ""))
    self.band:SetProps({actions = {
        {key = "process", label = ns.T("resourceDetails"), tip = ns.T("resourceDetailsTip"),
            reason = not process and ns.T("resourceNoProcessReason") or nil, fn = function() self:OpenProcess() end},
        {key = "materials", label = ns.T("resourceMaterials"), tip = ns.T("resourceMaterialsTip"),
            fn = function() ns.Trader.OpenReagent(p.id) end}}})
    local outputs = e and e.outputs or {}
    local outcomes = math.min(#outputs, OUTCOMES) * 46
    self.outcomes.frame:SetHeight(math.max(46, outcomes))
    if process then self.outcomes.frame:Show() else self.outcomes.frame:Hide() end
    self.outcomes:SetProps({source = p.id, outputs = outputs})
    local focus = self.outcomes:Focus()
    self.next.frame:ClearAllPoints()
    self.next.frame:SetPoint("TOPLEFT", self.panelChild, "TOPLEFT", 12, -(136 + outcomes + 6))
    self.panelHeight = (process and 136 + outcomes + 8 or 140) + (focus and ns.TradeKit.NextUses.HEIGHT + 6 or 0)
    if focus then
        self.next:SetProps({id = focus, back = function() self.outcomes:Toggle(focus) end, backLabel = ns.T("nextBackRaw"),
            open = K.OpenNext})
    else self.next.frame:Hide() end
    self:FitPanel()
    self:Controls()
end
function UI:Bar()
    return self.barFrames
end
function UI:Controls()
    if not self.frame then return end
    self.scan:SetBusy(ns.Trader.Busy() and ns.T("batchBusy") or nil)
end
function UI:FitPanel()
    local width = self.panelScroll:Fit(self.panelHeight)
    local inner = width - 2 * ns.TradeKit.theme.inset
    self.note:SetWidth(inner)
    self.next.frame:SetWidth(inner)
end
function UI:OpenProcess()
    local process = ns.Reagents.Process(self.props.id)
    if process then ns.TradeKit.OpenProcess(process.mode, process.source) end
end
function UI:Open(id, props)
    if props.way and props.way.use then ns.Trader.OpenRecipe(props.way.use.profession, id); return end
    self.props.id = props.parent or id
    self:OpenProcess()
end
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent)
    local f = self.frame
    f:SetAllPoints(parent)
    self.epochs = K.EpochChips:New(f, ns.Crafting.expansions, function(key, checked) self:SetEpoch(key, checked) end,
        ns.T("resourceEpochEmpty"))
    self.inspector = K.Inspector:New(f)
    self.table = K.Table:New(f, {
        headers = {{key = "item", text = "matColItem"}, {key = "price", text = "tradeUnitPrice"},
            {key = "margin", text = "resourceGain"}, {key = "units", text = "tradeUnits"}},
        columns = function(width, tbl, layout) return K.MarketColumns(width - tbl:Row("row", 1):Reserve(nil, layout.noGo)) end,
        kinds = {row = {new = function(parent)
            return K.MarketRow:New(parent, function(id, props) self:Select(id, props) end, function(id) self:Select(id) end,
                function(id) self:Hide(id) end, function(id, props) self:Open(id, props) end)
        end}},
        empty = "resourceTableEmpty",
    })
    self.panelScroll = K.PanelScroll:New(self.inspector, "ManaCodeResourcesPanelScroll", 390)
    self.scrollBody, self.panelChild = self.panelScroll.frame, self.panelScroll.child
    local panel, label = self.panelChild
    label, self.sell = K.ValueRow(panel, ns.T("resourceSell"), -4, 120, 80)
    label, self.net = K.ValueRow(panel, ns.T("resourceNet"), -21, 120, 80)
    label, self.cost = K.ValueRow(panel, ns.T("resourceCost"), -44, 120, 80)
    label, self.revenue = K.ValueRow(panel, ns.T("resourceRevenue"), -61, 120, 80)
    label, self.margin = K.ValueRow(panel, ns.T("resourceMargin"), -78, 120, 80)
    self.note = K.Label(panel, "", 12, -99, 240, "secondary"); self.note:SetHeight(34)
    self.band = K.ActionBand:For(self.inspector, self.panelScroll)
    self.outcomes = K.OutcomeList:New(panel, function() self:Render() end, OUTCOMES)
    self.outcomes.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -136)
    self.outcomes.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -136)
    self.outcomes.frame:SetHeight(184)
    self.next = K.NextUses:New(panel)
    self.next.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -326); self.next.frame:SetWidth(234)
    self.scan = K.ScanBarButton(f, {label = ns.T("resourceBar"),
        run = function(mode)
            ns.Batch.Complete(ns.Crafting.ResourceTargets(self.props.profession), mode, true)
            self:Render()
        end,
        sources = function() return ns.Crafting.ResourceTargets(self.props.profession) end,
        body = ns.T("resourceScanTip")})
    self.scan.tipTitle = ns.T("resourceScan")
    self.barFrames = {self.scan}
    self.head = {filters = {self.epochs.frame}}
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
