local _, ns = ...
local UI = {props = {id = 36905, page = 1}, rows = {}, bagRows = {}, scope = "all", open = {}, recent = {}}
ns.ReagentsUI = UI
local BAG_ROW = 26
local NEXT_ROWS = 3
local POST_LINE = 24
local RECENT = 6
function UI:SetProps(props)
    if props.id and props.id ~= self.props.id then
        self.open = {}
        self:Remember(props.id)
        if self.scope == "all" and self.scroll then self.scroll.offset = 0 end
    end
    for key, value in pairs(props) do if key ~= "fee" then self.props[key] = value end end
    self:Render()
end
function UI:Remember(id)
    for i = #self.recent, 1, -1 do if self.recent[i] == id then table.remove(self.recent, i) end end
    table.insert(self.recent, 1, id)
    for i = #self.recent, RECENT + 1, -1 do self.recent[i] = nil end
end
function UI:Pinned(items)
    local work, result, bags = {}, {}, ns.Posting.Bags()
    for _, id in ipairs(self.recent) do work[id] = "matPickRecent" end
    for _, id in ipairs(ns.TradeKit.BatchPanel.Reagents()) do work[id] = "matPickBatch" end
    for _, item in ipairs(items) do
        local id = item.raw
        local stock = ns.Inventory.Total(id)
        if stock == 0 and bags[id] then stock = bags[id].count end
        if stock > 0 then result[#result + 1] = {raw = id, note = ns.T("matPickStock", stock)}
        elseif work[id] then result[#result + 1] = {raw = id, note = ns.T(work[id])} end
    end
    return result
end
function UI:Controls()
    if not self.frame then return end
    local idle = ns.Scan.state.phase == "idle" and not ns.Buy.Active()
    if idle then self.scan:Enable() else self.scan:Disable() end
    for _, row in ipairs(self.next.rows) do
        if idle then row.fill:Enable() else row.fill:Disable() end
    end
    if ns.vendorPrices[self.props.id] then self.buy:Disable() else self.buy:Enable() end
    if ns.Crafting.byItem[self.props.id] then self.obtain:Show() else self.obtain:Hide() end
end
function UI:Layout()
    local K = ns.TradeKit
    local width = self.frame:GetWidth() or 996
    local panel = K.CraftPanelWidth(width)
    if self.inspector.width ~= panel then
        self.inspector.width = panel
        self.inspector:Layout()
    end
    self.scan:ClearAllPoints(); self.scan:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -panel - 18, 4)
    return width - panel - 46
end
function UI:SetScope(scope)
    self.scope = scope
    if self.scroll then self.scroll.offset = 0 end
    if scope == "bags" then
        local rows = ns.Reagents.BagItems(ns.Fee())
        local present = false
        for _, row in ipairs(rows) do if row.id == self.props.id then present = true end end
        if not present and rows[1] then self.props.id = rows[1].id end
    end
    self:Render()
end
local function openKey(use)
    if not use then return nil end
    if use.recipe then return "recipe:" .. use.recipe.raw end
    if use.spell then return "spell:" .. use.spell end
    if use.source then return "source:" .. use.source.itemID end
end
function UI:ToggleUse(props)
    if props.owner then
        local tree = self.open[props.owner]
        tree[props.id] = not tree[props.id] or nil
    elseif props.key then self.open[props.key] = not self.open[props.key] and {} or nil end
    self:Render()
end
function UI:Visit(id)
    ns.Trader.Navigate(function() self:SetProps({id = id}) end)
end
function UI:SelectUse(props)
    if props.child then self:Visit(props.id)
    elseif props.expandable then self:ToggleUse(props)
    else self:OpenUse(props) end
end
function UI:OpenUse(props)
    local use = props.use
    if not use then return end
    if use.recipe then ns.Trader.OpenRecipe(use.recipe.profession, use.recipe.raw)
    elseif use.source then ns.TradeKit.OpenProcess(use.mode, use.source)
    elseif use.offer then self:Visit(use.offer.itemID) end
end
function UI:Pick(entry, id)
    local key = openKey(entry)
    if not key then ns.Trader.OpenReagent(id); return end
    self.scope, self.mode = "all", "craft"
    self.open[key] = self.open[key] or {}
    self.revealID = key
    self:Render()
end
function UI:UseEntries(uses, packs)
    local entries = {}
    for _, use in ipairs(uses) do
        entries[#entries + 1] = {use = use}
        local demand = packs and use.use or use
        local key = openKey(demand)
        local tree = key and self.open[key]
        if tree then
            if demand.recipe and not packs then
                for _, node in ipairs(ns.CraftPlan.Build(demand.recipe, {make = tree, fee = ns.Fee()}).rows) do
                    entries[#entries + 1] = {node = node, owner = key}
                end
            elseif demand.source then
                for _, output in ipairs(demand.estimate.outputs) do entries[#entries + 1] = {output = output} end
            elseif demand.spell then
                for _, input in ipairs(demand.inputs) do entries[#entries + 1] = {input = input} end
            end
        end
    end
    return entries
end
function UI:RenderUses()
    local K, p = ns.TradeKit, self.props
    local packs = self.mode == "packs"
    local uses, items = packs and ns.Reagents.Packs(p.id, ns.Fee()) or ns.Reagents.Demands(p.id, ns.Fee()), ns.Reagents.Items()
    local function quote(id) return ns.Markets.Quote(id) end
    uses = self.sorter:Apply(uses, {
        item = function(use) return packs and (use.use and ns.Reagents.UseName(use.use) or ns.Markets.Name(p.id))
            or ns.Reagents.UseName(use) end,
        price = function(use)
            if packs then return use.price end
            local q = quote(ns.Reagents.UseItem(use)); return q and q.price
        end,
        margin = function(use) if packs then return use.premium end return use.gain end,
        units = function(use)
            if packs then return use.lots end
            local q = quote(ns.Reagents.UseItem(use)); return q and q.units
        end,
    })
    self.sorter:Mark()
    self.viewMenu.frame:SetText(ns.T(packs and "reagentPacks" or "professionCrafts"))
    self.headers.item:SetText(ns.T(packs and "packRecipe" or "reagentRecipes"))
    self.headers.price:SetText(ns.T(packs and "packPrice" or "tradeUnitPrice"))
    self.headers.margin:SetText(ns.T(packs and "packPremium" or "reagentGain"))
    self.headers.units:SetText(ns.T(packs and "packLots" or "tradeUnits"))
    local width = self:Layout()
    local columns = K.MarketColumns(width - self.rows[1]:Reserve())
    self.picker:SetProps({families = items, raw = p.id, headingKey = "reagentsSection",
        pinned = function() return self:Pinned(items) end})
    K.PlaceHeaders(self.headers, columns, self.frame, -38)
    local entries = self:UseEntries(uses, packs)
    local visible = K.ListCapacity(self.frame, 56, 56, 29, #self.rows)
    if self.revealID then self:Reveal(entries, visible) end
    local offset = self.scroll:SetRange(#entries, visible)
    for i, row in ipairs(self.rows) do
        local entry = i <= visible and entries[offset + i]
        if not entry then row.frame:Hide()
        elseif entry.node then self:NodeRow(row, entry, width)
        elseif entry.output or entry.input then
            local output, input = entry.output, entry.input
            local id = output and output.id or input[1]
            row:SetProps({id = id, quote = quote(id), width = width, depth = 1, child = true,
                active = id == p.id, detail = output and ns.T("resourceOutcome", K.Chance(output.chance), K.Decimal(output.quantity, 2))
                    or ns.T("professionPackUse", input[2]), extraTip = ns.T("matInputTip")})
        elseif packs then
            local use = entry.use
            local demand = use.use
            local key = demand and (demand.spell or demand.source) and openKey(demand)
            row:SetProps({id = use.raw, quote = {price = use.price, units = use.lots}, width = width,
                spell = use.spell, use = demand, key = key, margin = use.premium, depth = 0,
                action = function() ns.Markets.Scan(p.id) end,
                detail = ns.T("packDetail", use.count, use.needed, K.Money(use.net)),
                expandable = key ~= nil, crafted = key and self.open[key] ~= nil,
                go = demand and (demand.recipe or demand.source) and self:Go(demand) or nil,
                extraTip = ns.T("packTip", ns.Markets.Name(p.id), use.count) .. (demand and ("\n\n" .. self:UseTip(demand)) or "")})
        else
            local use = entry.use
            local recipe = use.recipe
            local profession = use.profession or (recipe and recipe.profession)
            local detail = use.source and ns.T("professionProcessUse", ns.T(ns.Prospect.modes[use.mode].titleKey), use.count)
                or use.offer and ns.T(use.offer.bound and "matExchangeBound" or "matExchangeUse", ns.T(use.exchange.nameKey), use.count)
                or ns.T(use.spell and "professionBonusUse" or "reagentUse", use.count,
                    ns.T(ns.craftCatalogs[profession].labelKey))
            local key = not use.offer and openKey(use) or nil
            K.Tooltip(row.expand, ns.T("craftListExpand"), ns.T("matExpandTip"))
            row:SetProps({id = ns.Reagents.UseItem(use), spell = use.spell, use = use, key = key,
                quote = (recipe or use.source or use.offer) and quote(ns.Reagents.UseItem(use)), width = width,
                depth = 0, expandable = key ~= nil, crafted = key and self.open[key] ~= nil,
                margin = use.gain, detail = detail, noRefresh = use.spell ~= nil,
                go = (recipe or use.source) and self:Go(use) or nil, extraTip = self:UseTip(use)})
        end
    end
    self.empty:SetText(#uses == 0 and ns.T("reagentNoUses") or "")
    return uses
end
function UI:Go(use)
    if use.recipe then return {title = ns.T("matOpenRecipe"), tip = ns.T("matOpenRecipeTip")} end
    return {title = ns.T("matOpenProcess"), tip = ns.T("matOpenProcessTip")}
end
function UI:UseTip(use)
    if use.source then return ns.T("resourceTip") .. "\n\n" .. ns.T("matRecipeRowTip") end
    if use.offer then return ns.T("matExchangeTip") end
    if not use.spell then return ns.T("matRecipeRowTip") end
    local lines = {ns.T("professionBonusTip"), ns.T("professionUseInputs")}
    for _, input in ipairs(use.inputs) do
        lines[#lines + 1] = ns.Markets.Name(input[1]) .. ": " .. tostring(input[2])
    end
    return table.concat(lines, "\n")
end
function UI:NodeRow(row, entry, width)
    local K, node = ns.TradeKit, entry.node
    local have = math.max(0, GetItemCount(node.id, true) or 0)
    local q = ns.Alchemy.Quote(node.id)
    local detail = ns.T(have >= node.count and "craftListInputEnough" or "craftListInput", node.count, have)
    if q and q.vendor then detail = detail .. ns.T("cacheVendorRole")
    elseif q and q.manual then detail = detail .. ns.T("alchemyOwnPrice") end
    if node.crafted then detail = detail .. ns.T("craftSourceMake") end
    K.Tooltip(row.expand, ns.T("craftMaterialSource"), ns.T("craftTreeTip"))
    row:SetProps({id = node.id, quote = q, active = node.id == self.props.id, width = width,
        depth = node.depth + 1, expandable = node.expandable, crafted = node.crafted, owner = entry.owner,
        child = true, detail = detail, extraTip = ns.T("matInputTip")})
end
function UI:Reveal(entries, visible)
    local key = self.revealID
    self.revealID = nil
    for index, entry in ipairs(entries) do
        if entry.use and openKey(entry.use) == key then
            local offset = self.scroll.offset or 0
            if index <= offset or index > offset + visible then self.scroll.offset = math.max(0, index - 2) end
            return
        end
    end
end
function UI:RenderBags()
    local K, p = ns.TradeKit, self.props
    local rows = ns.Reagents.BagItems(ns.Fee())
    rows = self.bagSorter:Apply(rows, {
        item = function(row) return ns.Markets.Name(row.id) end,
        count = function(row) return row.count end,
        cost = function(row) return row.cost end,
        market = function(row) return row.market end,
        value = function(row) return row.value end,
        posted = function(row) return row.posted end,
    })
    self.bagSorter:Mark()
    local width = self:Layout()
    local columns = K.BagColumns(width)
    for key, label in pairs(self.bagHeaders) do
        local column = columns[key]
        label:ClearAllPoints()
        if column then
            label:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10 + column[1] + (key == "item" and 6 or 0), -38)
            label:SetWidth(column[2] - 6); label:Show()
        else label:Hide() end
    end
    local visible = K.ListCapacity(self.frame, 56, 56, BAG_ROW, #self.bagRows)
    local offset = self.scroll:SetRange(#rows, visible)
    for i, widget in ipairs(self.bagRows) do
        local row = i <= visible and rows[offset + i]
        if row then
            local cells = {count = {tostring(row.count)},
                cost = {row.cost and K.Money(row.cost) or ns.T("tradeNoPrice"), row.cost and "text" or "secondary"},
                market = {K.Money(row.market), row.market and "text" or "secondary"},
                value = {K.Money(row.value), row.value and "text" or "secondary"},
                posted = {row.posted > 0 and tostring(row.posted) or "", "gold"}}
            widget.frame:ClearAllPoints()
            widget.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -56 - (i - 1) * BAG_ROW)
            widget:SetProps({id = row.id, width = width, cells = cells, active = row.id == p.id,
                tip = ns.T("matBagTip")})
        else widget.frame:Hide() end
    end
    self.empty:SetText(#rows == 0 and ns.T("matBagsEmpty") or "")
    return rows
end
function UI:RenderNext(width)
    local K, p = ns.TradeKit, self.props
    self.next.frame:SetWidth(width - 24)
    self.next:SetProps({id = p.id, title = ns.T("matDo"), limit = NEXT_ROWS, tip = ns.T("matNextRowTip"),
        pick = function(entry, id) self:Pick(entry, id) end,
        open = function(entry) K.OpenNext(entry) end,
        complete = function(_, ids)
            ns.Batch.Complete(ids, K.ScanMode(), true)
            self:Render()
        end})
    local q = ns.Markets.Quote(p.id)
    local age = q and (q.vendor and ns.T("cacheVendorPrice", K.Money(q.price))
        or ns.T("cacheObserved", date("%d.%m %H:%M", q.at))) or ns.T("reagentNoPrice")
    if q and (q.miss or 0) > 0 then age = age .. ns.T("cacheIncomplete") end
    self.age:SetText(age)
    local obtain = ns.Crafting.byItem[p.id] and ((self.obtain:GetWidth() or 100) + 6) or 0
    self.age:SetWidth(math.max(60, width - 24 - obtain))
end
function UI:RenderPost(width, have)
    if have < 1 then
        self.form.frame:Hide()
        self.postLine:SetWidth(width); self.postLine:Show()
        self.postHave:SetText(ns.T("postHave", 0))
        return
    end
    self.postLine:Hide(); self.form.frame:Show()
    self.form:SetProps({id = self.props.id, fee = ns.Fee(), width = width,
        onPosted = function() self:Render() end,
        onCheckOwned = function()
            ns.Trader:ShowSection("sell"); ns.SellingUI.note = ns.T("postCheckPendingNote"); ns.SellingUI:SetView("owned")
        end})
end
function UI:Render()
    if not self.frame then return end
    local K, p = ns.TradeKit, self.props
    local bags = self.scope == "bags"
    local packs = self.mode == "packs"
    self.scopeSegment:Select(self.scope)
    for _, widget in ipairs({self.viewMenu.frame, self.picker.frame}) do
        if bags then widget:Hide() else widget:Show() end
    end
    for _, label in pairs(self.headers) do if bags then label:Hide() else label:Show() end end
    for _, label in pairs(self.bagHeaders) do if not bags then label:Hide() end end
    for _, row in ipairs(bags and self.rows or self.bagRows) do row.frame:Hide() end
    local count
    if bags then
        count = #self:RenderBags()
        self.sorter:Mark()
        self.scan:SetText(ns.T("matScanBags"))
    else
        local uses = self:RenderUses()
        count = #uses
        self.bagSorter:Mark()
        self.scan:SetText(ns.T("matScanUses"))
    end
    K.FitButton(self.scan, 28)
    self.inspector:SetProps({id = p.id})
    local have = ns.Posting.Have(p.id)
    self.panelHeight = -self.postTop + (have > 0 and K.PostForm.HEIGHT or POST_LINE) + 8
    local width = self.panelScroll:Fit(self.panelHeight)
    self:RenderNext(width)
    self:RenderPost(width, have)
    local activity = ns.Activity.Recent(p.id)
    local guide = bags and "" or ("\n\n" .. ns.T(packs and "packSummary" or "reagentComparisonShort") .. "\n\n"
        .. ns.T(packs and "packGuide" or (count == 0 and "reagentNoUses" or "reagentGuide")))
    self.inspector:SetInfo(ns.T("matPanelTitle"), ns.T("matPanelTip") .. guide
        .. "\n\n" .. (activity and ns.T("marketActivityShort", activity.added, activity.gone, activity.beforeExpiry) or "")
        .. "\n\n" .. ns.T("marketActivityTip"))
    self.count = count
    self:Controls()
end
function UI:NewPanel(inspector)
    local K = ns.TradeKit
    self.postTop = -12 - K.NextUses.Height(NEXT_ROWS) - 30
    self.panelHeight = -self.postTop + K.PostForm.HEIGHT + 8
    self.panelScroll = K.PanelScroll:New(inspector, "ManaCodeMaterialsPanelScroll", self.panelHeight)
    self.scrollBody, self.panelChild = self.panelScroll.frame, self.panelScroll.child
    local panel = self.panelChild
    self.selection = inspector.item
    self.next = K.NextUses:New(panel)
    self.next.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -4)
    self.next.frame:SetHeight(K.NextUses.Height(NEXT_ROWS))
    local y = -8 - K.NextUses.Height(NEXT_ROWS)
    self.age = K.Label(panel, "", 12, y - 5, 200, "secondary")
    self.age:SetHeight(12)
    self.obtain = K.Button(panel, ns.T("reagentObtain"), 120, function()
        local recipe = ns.Crafting.byItem[self.props.id]
        if recipe then ns.Trader.OpenRecipe(recipe.profession, recipe.raw) end
    end, "quiet")
    self.obtain:SetHeight(20); K.FitButton(self.obtain, 18)
    self.obtain:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, y)
    K.Tooltip(self.obtain, ns.T("reagentObtain"), ns.T("matObtainTip"))
    K.Rule(panel, self.postTop + 6)
    self.form = K.PostForm:New(panel)
    self.form:Place(self.postTop)
    local line = ns.NewFrame("Frame", nil, panel)
    self.postLine = line
    line:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, self.postTop); line:SetHeight(POST_LINE)
    K.Label(line, ns.T("postTitle"), 12, -3, 80, "heading"):SetHeight(14)
    self.postHave = K.Label(line, "", 92, -4, 80, "secondary"); self.postHave:SetHeight(12)
    self.toSell = K.Button(line, ns.T("matPostSell"), 100, function() ns.Trader.OpenSell(self.props.id) end, "quiet")
    self.toSell:SetHeight(20); K.FitButton(self.toSell, 18)
    self.toSell:SetPoint("TOPRIGHT", line, "TOPRIGHT", -12, 0)
    K.Tooltip(self.toSell, ns.T("matPostSell"), ns.T("matPostSellTip"))
    line:Hide()
    inspector:SetInfo(ns.T("matPanelTitle"), "")
    local function refresh() if self.frame:IsVisible() then self:Render() end end
    ns.Posting.Listen(refresh)
end
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent)
    local f = self.frame
    f:SetAllPoints(parent)
    self.scopeSegment = K.Segment(f, {{key = "all", label = ns.T("matScopeAll")}, {key = "bags", label = ns.T("matScopeBags")}},
        function(scope) self:SetScope(scope) end, {ns.T("matScopeTitle"), ns.T("matScopeTip")})
    self.scopeSegment.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -3)
    self.viewMenu = K.Menu(f, {{key = "craft", labelKey = "professionCrafts"}, {key = "packs", labelKey = "reagentPacks"}}, function(mode)
        self.mode = mode; self.scroll.offset = 0; self:Render()
    end)
    self.viewMenu.frame:SetWidth(100); self.viewMenu.frame:SetPoint("LEFT", self.scopeSegment.frame, "RIGHT", 6, 0)
    self.picker = K.FamilyPicker:New(f, function(id) self:SetProps({id = id}) end, true)
    self.picker.frame:SetPoint("LEFT", self.viewMenu.frame, "RIGHT", 6, 0)
    self.picker.frame:SetWidth(224); self.picker.frame.text:SetWidth(192)
    self.scan = K.Button(f, ns.T("scanSelection"), 140, function()
        if self.scope == "bags" then
            local ids = {}
            for _, row in ipairs(ns.Reagents.BagItems(ns.Fee())) do ids[#ids + 1] = row.id end
            ns.Batch.Complete(ids, K.ScanMode(), true)
        else ns.Reagents.Complete(self.props.id, K.ScanMode()) end
        self:Render()
    end)
    self.scan:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -282, 4)
    K.ScanTip(self.scan, ns.T("scanSelection"),
        function() return ns.T(self.scope == "bags" and "matScanBagsTip" or "scanReagentSelectionTip") end,
        function()
            if self.scope == "bags" then
                local ids = {}
                for _, row in ipairs(ns.Reagents.BagItems(ns.Fee())) do ids[#ids + 1] = row.id end
                return ids
            elseif self.props.id then return ns.Reagents.Targets(self.props.id) end
        end)
    K.TableHeader(f, -38)
    self.headers, self.bagHeaders = {}, {}
    for _, entry in ipairs({{"item", "reagentRecipes"}, {"price", "tradeUnitPrice"},
        {"margin", "reagentGain"}, {"units", "tradeUnits"}}) do
        local label = K.Label(f, ns.T(entry[2]), 0, -38, 100)
        if entry[1] ~= "item" then label:SetJustifyH("RIGHT") end
        self.headers[entry[1]] = label
    end
    for _, entry in ipairs({{"item", "matColItem"}, {"count", "matColCount"}, {"cost", "matColCost"},
        {"market", "matColMarket"}, {"value", "matColValue"}, {"posted", "matColPosted"}}) do
        local label = K.Label(f, ns.T(entry[2]), 0, -38, 100)
        label:SetHeight(12)
        if entry[1] ~= "item" then label:SetJustifyH("RIGHT") end
        label:Hide()
        self.bagHeaders[entry[1]] = label
    end
    self.sorter = K.Sorter(f, self.headers, function() self.scroll.offset = 0; self:Render() end, nil, {key = "margin", desc = true})
    self.bagSorter = K.Sorter(f, self.bagHeaders, function() self.scroll.offset = 0; self:Render() end, nil, {key = "value", desc = true})
    self.scroll = K.TableScroll(f, function() self:Render() end, 56, 56, 29)
    for i = 1, 40 do
        local row = K.MarketRow:New(f, function(_, props) self:SelectUse(props) end,
            function(_, props) self:ToggleUse(props) end, nil, function(_, props) self:OpenUse(props) end)
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -56 - (i - 1) * 29)
        row.frame:SetHeight(28)
        self.rows[i] = row
        self.scroll:Wheel(row.frame)
        local bagRow = K.BagRow:New(f, function(id) self:SetProps({id = id}) end)
        bagRow.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -56 - (i - 1) * BAG_ROW)
        bagRow.frame:Hide()
        self.bagRows[i] = bagRow
        self.scroll:Wheel(bagRow.frame)
    end
    self.empty = K.Label(f, "", 10, -66, 370)
    self.empty:SetHeight(60); self.empty:SetJustifyV("TOP")
    self.buy = K.Button(f, ns.T("tradeBuy"), 84, function() ns.Trader.OpenBuy(self.props.id) end)
    K.FitButton(self.buy, 28)
    self.buy:SetPoint("RIGHT", self.scan, "LEFT", -6, 0)
    self.inspector = K.Inspector:New(f)
    self:NewPanel(self.inspector)
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
