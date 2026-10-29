local _, ns = ...
local UI = {props = {profession = "mining"}, rows = {}, open = {}}
ns.GatheringUI = UI
function UI:SetProps(props)
    if props.profession and props.profession ~= self.props.profession then
        self.props.id, self.open = nil, {}
        if self.scroll then self.scroll.offset = 0 end
    end
    for key, value in pairs(props) do self.props[key] = value end
    self:Render()
end
function UI:SetEpoch(expansion, shown)
    ns.Crafting.SetEpoch(self.props.profession, expansion, shown)
    if self.scroll then self.scroll.offset = 0 end
    self:Render()
end
function UI:Select(id)
    self.props.id = id
    if ns.Reagents.Process(id) then self.open[id] = not self.open[id] or nil end
    self:Render()
end
function UI:Entries()
    local entries = {}
    for _, id in ipairs(ns.Crafting.Resources(self.props.profession)) do
        local process = ns.Reagents.Process(id)
        local estimate = process and ns.Prospect.Estimate(process.source, ns.Prospect.Price(id), ns.Fee())
        entries[#entries + 1] = {id = id, process = process, estimate = estimate}
        if self.open[id] and estimate then
            for _, output in ipairs(estimate.outputs) do entries[#entries + 1] = {id = output.id, output = output} end
        end
    end
    return entries
end
function UI:Render()
    if not self.frame then return end
    local K, p = ns.TradeKit, self.props
    local ids, shown = ns.Crafting.Resources(p.profession), false
    for _, id in ipairs(ids) do if id == p.id then shown = true end end
    if not shown then p.id = ids[1] end
    local epochs, counts = ns.Crafting.Epochs(p.profession), ns.Crafting.ResourceCounts(p.profession)
    self.epochs:SetProps({shown = epochs, counts = counts, tip = function() return ns.T("resourceEpochTip") end})
    local entries, width = self:Entries(), (self.frame:GetWidth() or 996) - 310
    local columns = K.MarketColumns(width - self.rows[1]:Reserve())
    K.PlaceHeaders(self.headers, columns, self.frame, -38)
    local visible = K.ListCapacity(self.frame, 56, 56, 29, #self.rows)
    local offset = self.scroll:SetRange(#entries, visible)
    for i, row in ipairs(self.rows) do
        local entry = i <= visible and entries[offset + i]
        if entry then
            local process, e, output = entry.process, entry.estimate, entry.output
            local detail = output and ns.T("resourceOutcome", K.Chance(output.chance), K.Decimal(output.quantity, 2))
                or (process and ns.T("resourceProcess", ns.T(ns.Prospect.modes[process.mode].titleKey),
                    process.count, process.source.skill) or ns.T("modeResources"))
            row:SetProps({id = entry.id, width = width, quote = ns.Markets.Quote(entry.id),
                margin = e and e.exact and e.margin or nil, detail = detail,
                active = entry.id == p.id, expandable = process ~= nil, crafted = self.open[entry.id] ~= nil,
                depth = output and 1 or 0, extraTip = ns.T("resourceTip"),
                go = process and {title = ns.T("resourceDetails"), tip = ns.T("resourceGoTip")} or nil})
        else row.frame:Hide() end
    end
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
    self.note:SetText(e and ((not e.exact or not e.cost) and ns.T("resourceIncomplete")
        or (not e.fresh or not ns.Prospect.Fresh(p.id)) and ns.T("resourceStale") or "") or ns.T("resourceNoProcess"))
    if process then self.details:Show() else self.details:Hide() end
    local outputs = e and e.outputs or {}
    if process then self.outcomes.frame:Show() else self.outcomes.frame:Hide() end
    self.outcomes:SetProps({source = p.id, outputs = outputs})
    local focus = self.outcomes:Focus()
    self.panelHeight = (process and 390 or 230) + (focus and ns.TradeKit.NextUses.HEIGHT or 0)
    if focus then
        self.next:SetProps({id = focus, back = function() self.outcomes:Toggle(focus) end, backLabel = ns.T("nextBackRaw"),
            open = K.OpenNext})
    else self.next.frame:Hide() end
    self:FitPanel()
    if ns.Scan.state.phase == "idle" and not ns.Buy.Active() then self.scan:Enable() else self.scan:Disable() end
end
function UI:FitPanel()
    local width = self.panelScroll:Fit(self.panelHeight)
    local inner = width - 2 * ns.TradeKit.theme.inset
    self.note:SetWidth(inner)
    self.next.frame:SetWidth(inner)
    self.details:SetWidth(inner); self.materials:SetWidth(inner)
end
function UI:OpenProcess()
    local process = ns.Reagents.Process(self.props.id)
    if process then ns.TradeKit.OpenProcess(process.mode, process.source) end
end
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent)
    local f = self.frame
    f:SetAllPoints(parent)
    K.Label(f, ns.T("resourceTitle"), 10, -6, 420, "heading")
    self.epochs = K.EpochChips:New(f, ns.Crafting.expansions, function(key, checked) self:SetEpoch(key, checked) end,
        ns.T("resourceEpochEmpty"))
    self.epochs.frame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -328, -2)
    K.TableHeader(f, -38)
    self.headers = {}
    for _, entry in ipairs({{"item", "matColItem"}, {"price", "tradeUnitPrice"},
        {"margin", "resourceMargin"}, {"units", "tradeUnits"}}) do
        self.headers[entry[1]] = K.Label(f, ns.T(entry[2]), 10, -38, 100)
        if entry[1] ~= "item" then self.headers[entry[1]]:SetJustifyH("RIGHT") end
    end
    self.scroll = K.TableScroll(f, function() self:Render() end, 56, 56, 29)
    for i = 1, 40 do
        local row = K.MarketRow:New(f, function(id) self:Select(id) end, function(id) self:Select(id) end, nil,
            function(id) self.props.id = id; self:OpenProcess() end)
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -56 - (i - 1) * 29)
        row.frame:SetHeight(28)
        self.rows[i] = row; self.scroll:Wheel(row.frame)
    end
    self.inspector = K.Inspector:New(f)
    self.panelScroll = K.PanelScroll:New(self.inspector, "ManaCodeResourcesPanelScroll", 390)
    self.scrollBody, self.panelChild = self.panelScroll.frame, self.panelScroll.child
    local panel, label = self.panelChild
    label, self.sell = K.ValueRow(panel, ns.T("resourceSell"), -4, 120, 80)
    label, self.net = K.ValueRow(panel, ns.T("resourceNet"), -21, 120, 80)
    label, self.cost = K.ValueRow(panel, ns.T("resourceCost"), -44, 120, 80)
    label, self.revenue = K.ValueRow(panel, ns.T("resourceRevenue"), -61, 120, 80)
    label, self.margin = K.ValueRow(panel, ns.T("resourceMargin"), -78, 120, 80)
    self.note = K.Label(panel, "", 12, -99, 240, "secondary"); self.note:SetHeight(34)
    self.details = K.Button(panel, ns.T("resourceDetails"), 210, function() self:OpenProcess() end)
    self.details:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -136)
    self.materials = K.Button(panel, ns.T("resourceMaterials"), 210, function() ns.Trader.OpenReagent(self.props.id) end)
    self.materials:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -164)
    self.outcomes = K.OutcomeList:New(panel, function() self:Render() end)
    self.outcomes.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -198)
    self.outcomes.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -198)
    self.outcomes.frame:SetHeight(184)
    self.next = K.NextUses:New(panel)
    self.next.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -388); self.next.frame:SetWidth(234)
    self.scan = K.Button(f, ns.T("resourceScan"), 150, function()
        ns.Batch.Complete(ns.Crafting.ResourceTargets(self.props.profession), K.ScanMode(), true)
        self:Render()
    end, "main")
    self.scan:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -282, 4)
    K.ScanTip(self.scan, ns.T("resourceScan"), ns.T("resourceScanTip"), function()
        return ns.Crafting.ResourceTargets(self.props.profession)
    end)
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
