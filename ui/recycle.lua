local _, ns = ...
local UI = {props = {key = "planar"}, collapsed = {}}
ns.RecycleUI = UI
function UI:SetProps(props)
    for key, value in pairs(props) do if key ~= "fee" then self.props[key] = value end end
    self:Render()
end
function UI:Controls()
    if not self.frame then return end
    local phase = ns.Scan.state.phase
    self.scan:SetBusy((phase ~= "idle" or ns.Buy.Active()) and ns.T("batchBusy") or nil)
    local pair = self.inspector.props and ns.Recycle.Pair(self.props.key)
    local actions = {}
    if pair then
        for i, entry in ipairs({{pair.small, "recycleBuySmall"}, {pair.big, "recycleBuyBig"}}) do
            local action = ns.TradeKit.ActionBand.Buy(entry[1], ns.T(entry[2]))
            action.key, action.tip = entry[2], ns.T("recycleBuyTip", ns.Markets.Name(entry[1]))
            actions[i] = action
        end
    end
    self.band:SetProps({actions = actions})
end
ns.Hidden.Describe(function(key)
    local group = key:match("^recycle:(.+)$")
    local label = group and ns.recycleGroups[group]
    return label and {name = ns.T(label), place = ns.T("recycleNav")} or nil
end)
function UI:Lines()
    local lines = {}
    for _, group in ipairs(ns.Recycle.Groups()) do
        if not ns.Hidden.IsGroup(ns.Recycle.HideKey(group.group)) then
            lines[#lines + 1] = {group = group}
            if not self.collapsed[group.group] then
                for _, pair in ipairs(group.pairs) do lines[#lines + 1] = {pair = pair} end
            end
        end
    end
    return lines
end
function UI:RowTip(pair, estimate)
    local K = ns.TradeKit
    return ns.T("recycleDetail", ns.Markets.Name(pair.small), pair.ratio) .. "\n"
        .. ns.T("recycleDetailPrices", K.Money(estimate.smallPrice), K.Money(estimate.bigPrice)) .. "\n"
        .. ns.T("recycleHave", estimate.haveBig, estimate.haveSmall) .. "\n"
        .. ns.T("recycleRowTip")
end
function UI:FitPanel()
    local width = self.panelScroll:Fit(self.panelHeight)
    local inner = width - 24
    for _, label in ipairs(self.priceLabels) do label:SetWidth(inner - 118) end
    for _, label in ipairs(self.outcomeLabels) do label:SetWidth(inner - 108) end
    self.formula:SetWidth(inner)
    self.advice:SetWidth(inner); self.packNote:SetWidth(inner); self.have:SetWidth(inner)
    self.packsHead:SetWidth(inner)
    for _, label in ipairs(self.packLines) do label:SetWidth(inner) end
end
function UI:Panel(pair, estimate)
    local K = ns.TradeKit
    self.formula:SetText(ns.T("recycleFormula", pair.ratio))
    self.priceValues[1]:SetText(K.Money(estimate.smallPrice))
    self.priceValues[2]:SetText(K.Money(estimate.bigPrice))
    local values = {estimate.asIs, pair.both and estimate.split or nil, estimate.assemble}
    for i, label in ipairs(self.outcomeValues) do
        local value = values[i]
        label:SetText(i == 2 and not pair.both and ns.T("recycleOneWay") or K.Money(value))
        local tone = "text"
        if i == 1 and estimate.best == "asIs" or i == 2 and estimate.best == "split" then tone = "accent"
        elseif i == 3 and value then tone = K.Tone(value) end
        label:SetTextColor(unpack(K.theme[tone]))
    end
    self.advice:SetText(ns.T(estimate.advice))
    self.have:SetText(ns.T("recycleHave", estimate.haveBig, estimate.haveSmall))
    local stacks, best = ns.Recycle.Stacks(pair.big)
    for i, label in ipairs(self.packLines) do
        local stack = stacks[i]
        if stack then
            label:SetText(ns.T("recyclePackRow", stack.size, K.Money(stack.unit))
                .. (stack.premium and ns.T("recyclePackPremium", K.Decimal(stack.premium, 1, true)) or ""))
            label:SetTextColor(unpack(K.theme[K.Tone(math.max(0, stack.premium or 0))]))
            label:Show()
        else label:Hide() end
    end
    self.packNote:SetText(#stacks == 0 and ns.T("recyclePackEmpty")
        or (best and ns.T("recyclePackBest", best.size, K.Decimal(best.premium, 1, true)) or ns.T("recyclePackNone")))
    self:FitPanel()
end
function UI:Render()
    if not self.frame then return end
    local K, R, p = ns.TradeKit, ns.Recycle, self.props
    local lines = self:Lines()
    for _, line in ipairs(lines) do
        line.kind, line.depth = line.group and "group" or "row", line.group and 0 or 1
    end
    ns.TradeKit.ScreenBody(self.table, self.inspector, self.sectionHead)
    self.table:SetLines(lines, function(line, _, columns)
        local group, pair = line.group, line.pair
        if group then
            local priced, best = 0, nil
            for _, candidate in ipairs(group.pairs) do
                local e = R.Evaluate(candidate, ns.Fee())
                if e.asIs or e.split then priced = priced + 1 end
                if e.assemble then best = math.max(best or e.assemble, e.assemble) end
            end
            return {key = group.group, open = not self.collapsed[group.group],
                name = ns.T(group.labelKey), detail = ns.T("recycleGroupDetail", #group.pairs, priced),
                tip = ns.T("recycleGroupTip"), columns = columns,
                cells = {assemble = {best and K.Money(best) or nil, K.Tone(best)}},
                sources = function() return R.Targets(group.group) end, scanTip = ns.T("recycleGroupScanTip"),
                hideKey = R.HideKey(group.group)}
        end
        local estimate = R.Evaluate(pair, ns.Fee())
        return {key = pair.key, id = pair.big, estimate = estimate, oneWay = not pair.both,
            active = pair.key == p.key, tip = self:RowTip(pair, estimate),
            actions = {{label = ns.T("cacheComplete"), icon = "refresh", tip = ns.T("recycleScanPairTip"),
                fn = function(key) R.Complete(R.Pair(key), K.ScanMode()); self:Render() end}}}
    end)
    local selected = R.Pair(p.key)
    if selected then
        self.inspector:SetProps({id = selected.big})
        self:Panel(selected, R.Evaluate(selected, ns.Fee()))
    else self.inspector:Clear() end
    self:Controls()
end
function UI:NewTable(f)
    local K = ns.TradeKit
    self.table = K.Table:New(f, {
        headers = {{key = "item", text = "recycleColPair"},
            {key = "asIs", text = "recycleColAsIs", tip = "recycleAsIsTip"},
            {key = "split", text = "recycleColSplit", tip = "recycleSplitTip"},
            {key = "assemble", text = "recycleColAssemble", tip = "recycleAssembleTip"},
            {key = "bags", text = "recycleColBags", tip = "recycleBagsTip"}},
        columns = K.RecycleColumns,
        height = K.Table.LINE,
        kinds = {
            row = {new = function(parent)
                return K.RecycleRow:New(parent, function(key) self:SetProps({key = key}) end)
            end},
            group = {new = function(parent)
                return K.GroupRow:New(parent, function(key) self.collapsed[key] = not self.collapsed[key] or nil; self:Render() end,
                    function() self:Render() end)
            end},
        },
        empty = "recycleTableEmpty",
    })
end
function UI:NewPanel()
    local K = ns.TradeKit
    self.inspector = K.Inspector:New(self.frame)
    self.sectionHead = K.SectionHead:New(self.frame)
    self.panelHeight = 296
    self.panelScroll = K.PanelScroll:New(self.inspector, "ManaCodeRecyclePanelScroll", self.panelHeight)
    self.scrollBody, self.panelChild = self.panelScroll.frame, self.panelScroll.child
    self.band = K.ActionBand:For(self.inspector, self.panelScroll)
    local c = self.panelChild
    self.formula = K.Label(c, "", 12, -4, 234, "heading"); self.formula:SetHeight(14)
    self.priceLabels, self.priceValues = K.ValueRows(c, -22, {ns.T("recyclePriceSmall"), ns.T("recyclePriceBig")},
        {labelWidth = 130, valueWidth = 110})
    K.Rule(c, -54)
    K.Label(c, ns.T("recyclePerUnit"), 12, -62, 234, "heading")
    self.outcomeLabels, self.outcomeValues = K.ValueRows(c, -82,
        {ns.T("recycleAsIs"), ns.T("recycleSplit"), ns.T("recycleAssemble")}, {labelWidth = 150, valueWidth = 100})
    self.advice = K.Label(c, "", 12, -128, 234); self.advice:SetHeight(28); self.advice:SetJustifyV("TOP")
    self.have = K.Label(c, "", 12, -160, 234, "secondary"); self.have:SetHeight(12)
    K.Rule(c, -178)
    self.packsHead = K.Label(c, ns.T("recyclePacks"), 12, -186, 234, "heading"); self.packsHead:SetHeight(14)
    local packsTip = ns.NewFrame("Button", nil, c)
    packsTip:SetAllPoints(self.packsHead); packsTip:EnableMouse(true)
    K.Tooltip(packsTip, ns.T("recyclePacks"), ns.T("recyclePacksTip"))
    self.packLines = {}
    for i = 1, 5 do
        local line = K.Label(c, "", 12, -206 - (i - 1) * 13, 234); line:SetHeight(12)
        self.packLines[i] = line
    end
    self.packNote = K.Label(c, "", 12, -274, 234); self.packNote:SetHeight(28); self.packNote:SetJustifyV("TOP")
    self.inspector:SetInfo(ns.T("recycleNav"), ns.T("recycleInfo"))
end
function UI:Bar()
    return self.barFrames
end
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent)
    local f = self.frame
    f:SetAllPoints(parent)
    self:NewTable(f)
    self.scan = K.ScanBarButton(f, {label = ns.T("recycleBar"), kind = "main", body = ns.T("recycleScanAllTip"),
        run = function(mode) ns.Recycle.CompleteAll(mode); self:Render() end, sources = ns.Recycle.Targets})
    self.barFrames = {self.scan}
    self:NewPanel()
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
