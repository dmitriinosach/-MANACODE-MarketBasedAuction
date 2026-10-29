local _, ns = ...
local K = ns.TradeKit
local Inspector = {all = {}}
Inspector.__index = Inspector
K.Inspector = Inspector
function Inspector:New(parent)
    local view = setmetatable({parent = parent, top = -2}, self)
    local panel = ns.NewFrame("Frame", nil, parent)
    view.frame = panel
    panel:SetFrameLevel(parent:GetFrameLevel() + 12)
    panel:EnableMouse(true); K.Panel(panel)
    view.item = K.ItemChoice(panel, function() if view.props then K.Inspector.Switch("market", view.props.id) end end)
    view.item.extraTip = ns.T("itemHistoryOpenTip")
    view.item:SetPoint("TOPLEFT", panel, "TOPLEFT", K.theme.inset, -6)
    view.item:SetWidth(180); view.item.text:SetWidth(148)
    view.item:SetHeight(30); view.item.text:SetHeight(26); view.item.text:SetJustifyV("MIDDLE")
    if ns.Collections then
        view.actions = K.Menu(panel, {{key = "favorite", labelKey = "collectionFavorite"},
            {key = "tracked", labelKey = "collectionTrack"}}, function(key)
            local id = view.item.itemID
            if not id then return end
            if key == "favorite" then ns.Collections.ToggleFavorite(id) else ns.Collections.ToggleTracked(id) end
            ns.Trader.Refresh()
        end)
        view.actions.frame.arrow:Hide(); K.SetGlyph(view.actions.frame, "lists")
        view.actions.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -K.theme.inset, -10)
        K.Tooltip(view.actions.frame, ns.T("collectionActions"), ns.T("collectionActionsTip"))
    end
    view.market = K.Button(panel, ns.T("inspectorMarket"), 117, function()
        if view.props then K.Inspector.Switch("market", view.props.id) end
    end)
    view.market:SetPoint("TOPLEFT", panel, "TOPLEFT", K.theme.inset, -40)
    K.Tooltip(view.market, ns.T("inspectorMarket"), ns.T("inspectorMarketTip"))
    view.paths = K.Button(panel, ns.T("inspectorPaths"), 78, function()
        if view.props and ns.PathWindow then ns.PathWindow.Open(view.props.id) end
    end)
    view.paths:SetPoint("TOP", panel, "TOP", 0, -40)
    K.Tooltip(view.paths, ns.T("inspectorPaths"), ns.T("inspectorPathsTip"))
    view.offers = K.Button(panel, ns.T("offersOpen"), 117, function()
        if view.item.itemID then ns.OfferPreview.Open(view.item.itemID) end
    end, "quiet")
    view.offers:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -K.theme.inset, -40)
    K.Tooltip(view.offers, ns.T("offersTitle"), ns.T("offersOpenTip"))
    K.Rule(panel, -66)
    view.body = ns.NewFrame("Frame", nil, panel)
    view.body:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -26)
    view.body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    panel:HookScript("OnShow", function() view:Layout() end)
    Inspector.all[#Inspector.all + 1] = view
    view:Layout()
    return view
end
function Inspector.Switch(mode, id)
    if mode == "market" then
        local target = id or Inspector.lastID
        if target and ns.MarketWindow then ns.MarketWindow.Open(target) end
    elseif ns.MarketWindow then ns.MarketWindow.Close() end
end
function Inspector:Place(top, bottom)
    if self.top == top and self.bottom == bottom then return end
    self.top, self.bottom = top, bottom; self:Layout()
end
function Inspector:Layout()
    local panel = self.frame
    panel:ClearAllPoints()
    panel:SetPoint("TOPRIGHT", self.parent, "TOPRIGHT", -6, self.top)
    panel:SetPoint("BOTTOMRIGHT", self.parent, "BOTTOMRIGHT", -6, self.bottom or 2)
    local width = self.width or 264
    panel:SetWidth(width)
    local item = width - 2 * K.theme.inset - (self.actions and 30 or 0) - (self.info and K.theme.infoSize + 4 or 0)
    self.item:SetWidth(item); self.item.text:SetWidth(item - 32)
    local third = math.floor((width - 2 * K.theme.inset - 12) / 3)
    self.market:SetWidth(third)
    self.paths:SetWidth(third)
    self.offers:SetWidth(third)
    self.body:Show()
end
function K.CraftPanelWidth(width)
    return math.min(480, 264 + math.floor(math.max(0, width - 996) * 0.4))
end
function K.CraftLayout(view, headY, bottom)
    local width = view.frame:GetWidth() or 996
    local panel = K.CraftPanelWidth(width)
    view.inspector.width = panel
    view.inspector:Layout()
    view.headerBand:SetPoint("TOPRIGHT", view.frame, "TOPRIGHT", -panel - 38, headY + 5)
    view.scroll.frame:SetPoint("BOTTOMRIGHT", view.frame, "BOTTOMRIGHT", -panel - 16, bottom)
    view.scan:SetPoint("BOTTOMRIGHT", view.frame, "BOTTOMRIGHT", -panel - 18, 4)
    local right = -panel - 18
    if view.learnedFilter then
        view.learnedFilter.frame:SetPoint("TOPRIGHT", view.frame, "TOPRIGHT", right, -2)
        right = right - (view.learnedFilter.frame:GetWidth() or 0) - 8
    end
    if view.epochs then view.epochs.frame:SetPoint("TOPRIGHT", view.frame, "TOPRIGHT", right, -2) end
    return width - panel - 46
end
function Inspector:SetProps(props)
    self.props = props
    Inspector.lastID = props.id
    self:Render()
end
function Inspector:SetInfo(title, body)
    if not self.info then
        local b = K.InfoButton(self.frame, title, body)
        local star = self.actions and self.actions.frame
        if star then b:SetPoint("RIGHT", star, "LEFT", -4, 0)
        else b:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -K.theme.inset, -10) end
        self.info = b
        self:Layout()
    end
    K.Tooltip(self.info, title, body)
end
function Inspector:Clear()
    self.props = nil
    self.item:Hide(); self.offers:Hide(); self.market:Hide(); self.paths:Hide()
    if self.actions then self.actions.frame:Hide() end
    if self.info then self.info:Hide() end
    self:Layout()
end
function Inspector:Render()
    K.SetItemChoice(self.item, self.props.id, self.props.active, nil, self.props.link)
    self.offers:Show(); self.market:Show(); self.paths:Show()
    if self.info then self.info:Show() end
    if self.actions then
        self.actions.frame:Show()
        local C, id = ns.Collections, self.props.id
        self.actions:SetEntries({
            {key = "favorite", labelKey = C.Favorite(id) and "collectionUnfavorite" or "collectionFavorite", disabled = not C.CanFavorite(id)},
            {key = "tracked", labelKey = C.Tracked(id) and "collectionUntrack" or "collectionTrack"}})
    end
    self:Layout()
end
local NextUses = {LIMIT = 3, HEIGHT = 126, MAX = 8}
NextUses.__index = NextUses
K.NextUses = NextUses
function NextUses.Height(limit)
    return 36 + (limit or NextUses.LIMIT) * 30
end
function NextUses:New(parent)
    local view = setmetatable({rows = {}}, self)
    local f = ns.NewFrame("Frame", nil, parent)
    view.frame = f
    f:SetHeight(self.HEIGHT)
    view.title = K.Label(f, "", 0, 0, 150, "heading"); view.title:SetHeight(14)
    view.back = K.Button(f, ns.T("nextBack"), 76, function()
        if view.props and view.props.back then view.props.back() end
    end, "quiet")
    view.back:SetHeight(18); view.back:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 2)
    K.Tooltip(view.back, ns.T("nextBack"), ns.T("nextBackTip"))
    view.sell = K.Label(f, "", 0, -18, 230, "secondary"); view.sell:SetHeight(12)
    view.more = K.Label(f, "", 0, -18, 80, "secondary"); view.more:SetHeight(12); view.more:SetJustifyH("RIGHT")
    view.more:ClearAllPoints(); view.more:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -18)
    view.empty = K.Label(f, "", 0, -36, 230, "secondary"); view.empty:SetHeight(26); view.empty:SetJustifyV("TOP")
    for i = 1, self.LIMIT do view:Row(i) end
    return view
end
function NextUses:Row(i)
    if self.rows[i] then return self.rows[i] end
    local view, f = self, self.frame
    local row = {}
    row.frame = K.ItemChoice(f, function()
        local id = row.frame.itemID
        if not id then return end
        if view.props.pick then view.props.pick(row.entry, id) else K.Inspector.Switch("market", id) end
    end)
    row.frame:SetHeight(28)
    row.frame.text:ClearAllPoints(); row.frame.text:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 26, -2)
    row.frame.text:SetHeight(12)
    row.detail = K.Label(row.frame, "", 26, -15, 120, "secondary"); row.detail:SetHeight(12)
    row.value = K.Label(row.frame, "", 0, 0, 84); row.value:SetHeight(12); row.value:SetJustifyH("RIGHT")
    row.value:ClearAllPoints(); row.value:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT", -26, -2)
    row.go = K.IconButton(row.frame, "go", function()
        if row.entry and view.props.open then view.props.open(row.entry) end
    end, "", "")
    row.go:SetPoint("RIGHT", row.frame, "RIGHT", 0, 0)
    row.fill = K.Button(row.frame, ns.T("nextComplete"), 70, function()
        if row.entry and view.props.complete then view.props.complete(row.entry, row.gap) end
    end, "quiet")
    row.fill:SetHeight(18); K.FitButton(row.fill, 16)
    row.fill:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT", -26, 1)
    K.Tooltip(row.fill, ns.T("nextComplete"), ns.T("nextCompleteTip"))
    row.fill:Hide()
    row.frame:Hide()
    self.rows[i] = row
    return row
end
function NextUses:SetProps(props)
    self.props = props; self:Render()
end
function NextUses.Describe(id, entry)
    if entry.recipe then
        return entry.recipe.raw, ns.T("reagentUse", entry.count, ns.T(ns.craftCatalogs[entry.recipe.profession].labelKey))
    elseif entry.source then
        return entry.source.itemID, ns.T("professionProcessUse", ns.T(ns.Prospect.modes[entry.mode].titleKey), entry.count)
    elseif entry.offer then
        return entry.offer.itemID, ns.T("nextExchangeDetail", entry.offer.count)
    end
    local pair = entry.pair
    local other = id == pair.big and pair.small or pair.big
    if id ~= pair.big then return other, ns.T("matAssembleDetail", pair.ratio, ns.Markets.Name(pair.big)) end
    if pair.both then return other, ns.T("matSplitDetail", ns.Markets.Name(pair.small), pair.ratio) end
    return other, ns.T("matOneWay")
end
function NextUses:Render()
    local p = self.props
    if not p or not p.id then self.frame:Hide(); return end
    self.frame:Show()
    local width = math.max(160, self.frame:GetWidth() or 0)
    local limit = math.max(1, math.min(self.MAX, p.limit or self.LIMIT))
    for i = 1, limit do self:Row(i) end
    local sell, list, total = ns.Reagents.Next(p.id, ns.Fee(), limit)
    self.title:SetText(p.title or ns.T("nextTitle"))
    if p.back then
        self.back:SetText(p.backLabel or ns.T("nextBack"))
        K.Tooltip(self.back, p.backLabel or ns.T("nextBack"), ns.T("nextBackTip"))
        self.back:Show()
    else self.back:Hide() end
    self.sell:SetWidth(width - 84); self.sell:SetText(sell and ns.T("nextSell", K.Money(sell)) or ns.T("nextSellNone"))
    self.more:SetText(total > #list and ns.T("nextMore", total - #list) or "")
    self.empty:SetWidth(width); self.empty:SetText(#list == 0 and ns.T("nextEmpty") or "")
    for i, row in ipairs(self.rows) do
        local entry = list[i]
        row.entry = entry
        if entry then
            local id, detail = NextUses.Describe(p.id, entry)
            row.frame:ClearAllPoints(); row.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -36 - (i - 1) * 30)
            row.frame:SetWidth(width)
            K.SetItemChoice(row.frame, id, false)
            row.frame.extraTip = p.tip or ns.T(p.pick and "nextRowPickTip" or "nextRowTip")
            row.frame.icon:SetWidth(20); row.frame.icon:SetHeight(20)
            row.frame.text:SetWidth(math.max(40, width - 140)); row.detail:SetWidth(math.max(40, width - 52))
            local gain = entry.gain
            row.gap = nil
            if gain == nil then
                local reason
                reason, row.gap = ns.Reagents.Gap(p.id, entry)
                detail = detail .. ns.T("nextGapJoin") .. ns.T(reason)
            end
            row.detail:SetText(detail)
            row.value:SetText(gain and ((gain > 0 and "+" or "") .. K.Money(gain)) or ns.T("tradeNoPrice"))
            row.value:SetTextColor(unpack(K.theme[K.Tone(gain)]))
            if gain == nil and p.complete then row.value:Hide(); row.fill:Show() else row.value:Show(); row.fill:Hide() end
            if entry.recipe then K.Tooltip(row.go, ns.T("nextOpenRecipe"), ns.T("nextOpenRecipeTip"))
            elseif entry.source then K.Tooltip(row.go, ns.T("nextOpenProcess"), ns.T("nextOpenProcessTip"))
            elseif entry.offer then K.Tooltip(row.go, ns.T("nextOpenExchange"), ns.T("nextOpenExchangeTip"))
            else K.Tooltip(row.go, ns.T("nextOpenRecycle"), ns.T("nextOpenRecycleTip")) end
        else row.frame:Hide() end
    end
end
function K.OpenNext(entry)
    if entry.recipe then ns.Trader.OpenRecipe(entry.recipe.profession, entry.recipe.raw)
    elseif entry.source then K.OpenProcess(entry.mode, entry.source)
    elseif entry.offer then
        ns.Trader.Navigate(function()
            ns.Trader:ShowSection("npc")
            if ns.NpcUI then ns.NpcUI:SetProps({segment = "trading", id = entry.offer.itemID}) end
        end)
    else ns.Trader.OpenProcessing("recycle") end
end
function K.OpenProcess(mode, source)
    ns.Trader.Navigate(function()
        ns.Trader.OpenProcessing(mode)
        local view = ns.ProspectUI
        if not view or not view.frame then return end
        view:SetProps({view = "raw"})
        local state = view:S()
        state.selected, state.chosen = source.itemID, source.itemID
        state.expansions[source.expansion] = true
        state.skill = 0
        view:Save()
        view:Render()
    end)
end
