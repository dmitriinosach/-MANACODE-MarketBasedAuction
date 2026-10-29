local _, ns = ...
local UI = {props = {key = "planar"}, rows = {}, groups = {}, collapsed = {}}
ns.RecycleUI = UI
local TOP, BOTTOM, ROW = 26, 34, 24
function UI:SetProps(props)
    for key, value in pairs(props) do if key ~= "fee" then self.props[key] = value end end
    self:Render()
end
function UI:Controls()
    if not self.frame then return end
    local phase = ns.Scan.state.phase
    if phase == "idle" and not ns.Buy.Active() then self.scan:Enable() else self.scan:Disable() end
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
    local K, R, p, f = ns.TradeKit, ns.Recycle, self.props, self.frame
    local width = (f:GetWidth() or 996) - 300
    local columns = K.RecycleColumns(width)
    K.PlaceHeaders(self.headers, columns, f, -(TOP - 16), true)
    for key, button in pairs(self.headerTips) do
        if columns[key] then button:Show() else button:Hide() end
    end
    local lines = self:Lines()
    local visible = K.ListCapacity(f, TOP, BOTTOM, ROW, #self.rows + #self.groups)
    local offset = self.scroll:SetRange(#lines, visible)
    local usedRows, usedGroups = 0, 0
    for i = 1, visible do
        local line = lines[offset + i]
        local y = -TOP - (i - 1) * ROW
        if line and line.group then
            usedGroups = usedGroups + 1
            local header, group = self.groups[usedGroups], line.group
            if header then
                local priced, best = 0, nil
                for _, pair in ipairs(group.pairs) do
                    local e = R.Evaluate(pair, ns.Fee())
                    if e.asIs or e.split then priced = priced + 1 end
                    if e.assemble then best = math.max(best or e.assemble, e.assemble) end
                end
                header.frame:ClearAllPoints(); header.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
                header:SetProps({key = group.group, width = width, height = ROW, open = not self.collapsed[group.group],
                    name = ns.T(group.labelKey), detail = ns.T("recycleGroupDetail", #group.pairs, priced),
                    tip = ns.T("recycleGroupTip"), columns = columns,
                    cells = {assemble = {best and K.Money(best) or nil, K.Tone(best)}},
                    sources = function() return R.Targets(group.group) end, scanTip = ns.T("recycleGroupScanTip"),
                    hideKey = R.HideKey(group.group)})
            end
        elseif line then
            usedRows = usedRows + 1
            local row, pair = self.rows[usedRows], line.pair
            if row then
                local estimate = R.Evaluate(pair, ns.Fee())
                row.frame:ClearAllPoints(); row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
                row:SetProps({key = pair.key, id = pair.big, width = width, estimate = estimate, oneWay = not pair.both,
                    active = pair.key == p.key, tip = self:RowTip(pair, estimate),
                    actions = {{label = ns.T("cacheComplete"), icon = "refresh", tip = ns.T("recycleScanPairTip"),
                        fn = function(key) R.Complete(R.Pair(key), K.ScanMode()); self:Render() end}}})
            end
        end
    end
    for i = usedRows + 1, #self.rows do self.rows[i].frame:Hide() end
    for i = usedGroups + 1, #self.groups do self.groups[i].frame:Hide() end
    local selected = R.Pair(p.key)
    if selected then
        self.inspector:SetProps({id = selected.big})
        self:Panel(selected, R.Evaluate(selected, ns.Fee()))
    else self.inspector:Clear() end
    self:Controls()
end
function UI:NewTable(f)
    local K = ns.TradeKit
    self.headerBand = K.TableHeader(f, -(TOP - 18))
    self.headerBand:ClearAllPoints()
    self.headerBand:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -3)
    self.headerBand:SetPoint("TOPRIGHT", f, "TOPRIGHT", -290, -3)
    self.headers, self.headerTips = {}, {}
    local tips = {asIs = "recycleAsIsTip", split = "recycleSplitTip", assemble = "recycleAssembleTip", bags = "recycleBagsTip"}
    for _, entry in ipairs({{"item", "recycleColPair"}, {"asIs", "recycleColAsIs"}, {"split", "recycleColSplit"},
        {"assemble", "recycleColAssemble"}, {"bags", "recycleColBags"}}) do
        local label = K.Label(f, ns.T(entry[2]), 0, -(TOP - 16), 100)
        label:SetHeight(12)
        if entry[1] ~= "item" then label:SetJustifyH("RIGHT") end
        self.headers[entry[1]] = label
        if tips[entry[1]] then
            local button = ns.NewFrame("Button", nil, f)
            button:SetAllPoints(label); button:EnableMouse(true)
            K.Tooltip(button, ns.T(entry[2]), ns.T(tips[entry[1]]))
            self.headerTips[entry[1]] = button
        end
    end
    self.scroll = K.Scroller:New(f, function() self:Render() end, ROW)
    self.scroll.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -TOP)
    self.scroll.frame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -272, BOTTOM)
    for i = 1, 40 do
        local row = K.RecycleRow:New(f, function(key) self:SetProps({key = key}) end)
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -TOP - (i - 1) * ROW)
        row.frame:Hide()
        self.rows[i] = row
        self.scroll:Wheel(row.frame)
    end
    for i = 1, 3 do
        local header = K.GroupRow:New(f, function(key) self.collapsed[key] = not self.collapsed[key] or nil; self:Render() end,
            function() self:Render() end)
        header.frame:Hide(); self.scroll:Wheel(header.frame); self.groups[i] = header
    end
end
function UI:NewBottom(f)
    local K = ns.TradeKit
    self.buyBig = K.Button(f, ns.T("recycleBuyBig"), 120, function()
        local pair = ns.Recycle.Pair(self.props.key); if pair then ns.Trader.OpenBuy(pair.big) end
    end)
    self.buyBig:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -428, 4)
    self.buySmall = K.Button(f, ns.T("recycleBuySmall"), 120, function()
        local pair = ns.Recycle.Pair(self.props.key); if pair then ns.Trader.OpenBuy(pair.small) end
    end)
    self.buySmall:SetPoint("RIGHT", self.buyBig, "LEFT", -6, 0)
end
function UI:NewPanel()
    local K = ns.TradeKit
    self.inspector = K.Inspector:New(self.frame)
    self.inspector:Place(-30)
    self.panelHeight = 296
    self.panelScroll = K.PanelScroll:New(self.inspector, "ManaCodeRecyclePanelScroll", self.panelHeight)
    self.scrollBody, self.panelChild = self.panelScroll.frame, self.panelScroll.child
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
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent)
    local f = self.frame
    f:SetAllPoints(parent)
    self:NewTable(f)
    self:NewBottom(f)
    self.scan = K.Button(f, ns.T("recycleScanAll"), 140, function() ns.Recycle.CompleteAll(K.ScanMode()); self:Render() end, "main")
    self.scan:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -282, 4)
    K.ScanTip(self.scan, ns.T("recycleScanAll"), ns.T("recycleScanAllTip"), ns.Recycle.Targets)
    self:NewPanel()
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
