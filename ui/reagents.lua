local _, ns = ...
local UI = {props = {id = 36905, page = 1}, scope = "all", open = {}, recent = {},
    batchState = {make = {}, ignore = {}, choice = {}, craftAll = false, owned = false}}
ns.ReagentsUI = UI
local POST_LINE = 24
local RECENT = 6
function UI:SetProps(props)
    if props.id and props.id ~= self.props.id then
        self.open, self.focus = {}, nil
        self:Remember(props.id)
        if self.scope == "all" and self.tables then self.tables.all:ResetScroll() end
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
    self.scan:SetBusy(not idle and ns.T("batchBusy") or nil)
    if self.batch then self.batch:Controls() end
    local f, id, actions = self.focus, self.props.id, {}
    if f then
        if not self:FocusRecipe() then
            local short = f.need and math.max(0, f.need - math.max(0, GetItemCount(f.id, true) or 0)) or 0
            actions[1] = ns.TradeKit.ActionBand.Buy(f.id, nil, short > 0 and short or nil)
            if short > 0 then actions[1].tip = ns.T("matBuyCount", short) .. "\n\n" .. actions[1].tip end
            if f.child or (f.use and f.use.offer) then
                local target = f.child and f.id or f.use.offer.itemID
                actions[2] = {key = "material", label = ns.T("matGoLabel"), title = ns.T("matOpenMaterial"),
                    tip = ns.T("matOpenMaterialTip"), fn = function() self:Visit(target) end}
            elseif f.use and f.use.source then
                actions[2] = {key = "go", label = ns.T("matGoLabel"), title = ns.T("matOpenProcess"),
                    tip = ns.T("matOpenProcessTip"), fn = function() self:OpenUse({use = f.use}) end}
            end
        end
    elseif id then
        actions[1] = ns.TradeKit.ActionBand.Buy(id)
        local recipe = ns.Crafting.byItem[id]
        if recipe then
            actions[2] = {key = "recipe", label = ns.T("reagentObtain"), tip = ns.T("matObtainTip"),
                fn = function() ns.Trader.OpenRecipe(recipe.profession, recipe.raw) end}
        end
    end
    self.band:SetProps({actions = actions})
end
function UI:Bar()
    return self.barFrames
end
function UI:SetScope(scope)
    self.scope, self.focus = scope, nil
    if self.tables then self.tables[scope]:ResetScroll() end
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
    if props.child then
        local owner = props.owner and tonumber(props.owner:match("^recipe:(%d+)$"))
        self.focus = {id = props.id, child = true, need = props.need, owner = owner}
    else self.focus = {id = props.id, use = props.use, key = props.key} end
    self:Render()
end
function UI:Focused(id, key, child)
    local f = self.focus
    return f ~= nil and f.id == id and (f.child or false) == (child or false) and (child or f.key == key)
end
function UI:OpenUse(props)
    if props.child then self:Visit(props.id); return end
    local use = props.use
    if not use then return end
    if use.recipe then ns.Trader.OpenRecipe(use.recipe.profession, use.recipe.raw)
    elseif use.source then ns.TradeKit.OpenProcess(use.mode, use.source)
    elseif use.offer then self:Visit(use.offer.itemID) end
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
    local p = self.props
    local packs = self.mode == "packs"
    local uses, items = packs and ns.Reagents.Packs(p.id, ns.Fee()) or ns.Reagents.Demands(p.id, ns.Fee()), ns.Reagents.Items()
    local function quote(id) return ns.Markets.Quote(id) end
    uses = self.tables.all.sorter:Apply(uses, {
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
    self.viewMenu.frame:SetText(ns.T(packs and "reagentPacks" or "professionCrafts"))
    self.tables.all.headers.item:SetText(ns.T(packs and "packRecipe" or "reagentRecipes"))
    self.tables.all.headers.price:SetText(ns.T(packs and "packPrice" or "tradeUnitPrice"))
    self.tables.all.headers.margin:SetText(ns.T(packs and "packPremium" or "reagentGain"))
    self.tables.all.headers.units:SetText(ns.T(packs and "packLots" or "tradeUnits"))
    self.picker:SetProps({families = items, raw = p.id, headingKey = "reagentsSection",
        pinned = function() return self:Pinned(items) end})
    local entries = self:UseEntries(uses, packs)
    for _, entry in ipairs(entries) do
        local demand = entry.use
        if packs then demand = demand and demand.use end
        entry.depth = entry.node and entry.node.depth + 1 or (entry.output or entry.input) and 1 or 0
        entry.tree = entry.node and entry.node.expandable or demand and not demand.offer
            and (not packs or demand.spell ~= nil or demand.source ~= nil)
    end
    local tbl = self.tables.all
    ns.TradeKit.ScreenBody(tbl, self.inspector, self.sectionHead)
    tbl:SetLines(entries, function(entry, _, columns)
        return self:UseProps(entry, columns, packs)
    end)
    return uses
end
function UI:UseProps(entry, columns, packs)
    if entry.node then return self:NodeProps(entry, columns) end
    local K, p = ns.TradeKit, self.props
    if entry.output or entry.input then
        local output, input = entry.output, entry.input
        local id = output and output.id or input[1]
        return {id = id, quote = ns.Markets.Quote(id), columns = columns, depth = 1, child = true,
            need = input and input[2], go = self:ChildGo(), active = self:Focused(id, nil, true),
            detail = output and ns.T("resourceOutcome", K.Chance(output.chance), K.Decimal(output.quantity, 2))
                or ns.T("professionPackUse", input[2]), extraTip = ns.T("matInputTip")}
    end
    local use = entry.use
    if packs then
        local demand = use.use
        local key = demand and (demand.spell or demand.source) and openKey(demand)
        return {id = use.raw, quote = {price = use.price, units = use.lots}, columns = columns,
            spell = use.spell, use = demand, key = key, margin = use.premium, depth = 0,
            active = self:Focused(use.raw, key), action = function() ns.Markets.Scan(p.id) end,
            detail = ns.T("packDetail", use.count, use.needed, K.Money(use.net)),
            expandable = key ~= nil, crafted = key and self.open[key] ~= nil,
            go = demand and (demand.recipe or demand.source) and self:Go(demand) or nil,
            extraTip = ns.T("packTip", ns.Markets.Name(p.id), use.count) .. (demand and ("\n\n" .. self:UseTip(demand)) or "")}
    end
    local recipe = use.recipe
    local profession = use.profession or (recipe and recipe.profession)
    local detail = use.source and ns.T("professionProcessUse", ns.T(ns.Prospect.modes[use.mode].titleKey), use.count)
        or use.offer and ns.T(use.offer.bound and "matExchangeBound" or "matExchangeUse", ns.T(use.exchange.nameKey), use.count)
        or ns.T(use.spell and "professionBonusUse" or "reagentUse", use.count, ns.T(ns.craftCatalogs[profession].labelKey))
    local key = not use.offer and openKey(use) or nil
    local id = ns.Reagents.UseItem(use)
    return {id = id, spell = use.spell, use = use, key = key,
        quote = (recipe or use.source or use.offer) and ns.Markets.Quote(id), columns = columns,
        depth = 0, expandable = key ~= nil, crafted = key and self.open[key] ~= nil, active = self:Focused(id, key),
        margin = use.gain, detail = detail, noRefresh = use.spell ~= nil,
        go = (recipe or use.source) and self:Go(use) or nil, extraTip = self:UseTip(use),
        expandTitle = ns.T("craftListExpand"), expandTip = ns.T("matExpandTip")}
end
function UI:ChildGo()
    return {title = ns.T("matOpenMaterial"), tip = ns.T("matOpenMaterialTip")}
end
function UI:Go(use)
    if use.recipe then
        return {title = ns.T("matOpenRecipe"), tip = ns.T("matOpenRecipeTip"),
            icon = ns.TradeKit.ProfessionIcon(use.recipe.profession)}
    end
    return {title = ns.T("matOpenProcess"), tip = ns.T("matOpenProcessTip"), icon = ns.Trader.ProcessIcon(use.mode)}
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
function UI:NodeProps(entry, columns)
    local node = entry.node
    local have = math.max(0, GetItemCount(node.id, true) or 0)
    local q = ns.Alchemy.Quote(node.id)
    local detail = ns.T(have >= node.count and "craftListInputEnough" or "craftListInput", node.count, have)
    if q and q.vendor then detail = detail .. ns.T("cacheVendorRole")
    elseif q and q.manual then detail = detail .. ns.T("alchemyOwnPrice") end
    if node.crafted then detail = detail .. ns.T("craftSourceMake") end
    return {id = node.id, quote = q, active = self:Focused(node.id, nil, true), columns = columns,
        depth = node.depth + 1, expandable = node.expandable, crafted = node.crafted, owner = entry.owner,
        child = true, need = node.count, go = self:ChildGo(), detail = detail, extraTip = ns.T("matInputTip"),
        expandTitle = ns.T("craftMaterialSource"), expandTip = ns.T("craftTreeTip")}
end
function UI:RenderBags()
    local K, p = ns.TradeKit, self.props
    local rows = ns.Reagents.BagItems(ns.Fee())
    rows = self.tables.bags.sorter:Apply(rows, {
        item = function(row) return ns.Markets.Name(row.id) end,
        count = function(row) return row.count end,
        cost = function(row) return row.cost end,
        market = function(row) return row.market end,
        value = function(row) return row.value end,
        posted = function(row) return row.posted end,
    })
    local tbl = self.tables.bags
    ns.TradeKit.ScreenBody(tbl, self.inspector, self.sectionHead)
    tbl:SetLines(rows, function(row)
        local cells = {count = {tostring(row.count)},
            cost = {row.cost and K.Money(row.cost) or ns.T("tradeNoPrice"), row.cost and "text" or "secondary"},
            market = {K.Money(row.market), row.market and "text" or "secondary"},
            value = {K.Money(row.value), row.value and "text" or "secondary"},
            posted = {row.posted > 0 and tostring(row.posted) or "", "gold"}}
        return {id = row.id, cells = cells, active = row.id == p.id, tip = ns.T("matBagTip")}
    end)
    return rows
end
function UI:RenderNext(width)
    local K, p = ns.TradeKit, self.props
    local sell = ns.Reagents.Next(p.id, ns.Fee(), 1)
    self.sell:SetWidth(math.max(60, width - 24))
    self.sell:SetText(sell and ns.T("nextSell", K.Money(sell)) or ns.T("nextSellNone"))
    self.hint:SetWidth(math.max(60, width - 24))
    self.hint:SetText(self.scope == "bags" and "" or ns.T("matPickHint"))
    local q = ns.Markets.Quote(p.id)
    local age = q and (q.vendor and ns.T("cacheVendorPrice", K.Money(q.price))
        or ns.T("cacheObserved", date("%d.%m %H:%M", q.at))) or ns.T("reagentNoPrice")
    if q and (q.miss or 0) > 0 then age = age .. ns.T("cacheIncomplete") end
    self.age:SetText(age)
    self.age:SetWidth(math.max(60, width - 24))
end
function UI:PanelHeight(have)
    self.panelHeight = -self.postTop + (have > 0 and self.form.height or POST_LINE) + 8
    return self.panelHeight
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
        onChange = function() self.panelScroll:Fit(self:PanelHeight(have)) end,
        onPosted = function() self:Render() end,
        onCheckOwned = function()
            ns.Trader:ShowSection("sell"); ns.SellingUI.note = ns.T("postCheckPendingNote"); ns.SellingUI:SetView("owned")
        end})
end
function UI:FocusRecipe()
    local f = self.focus
    if not f then return nil end
    if f.child then return ns.Crafting.byItem[f.id] end
    return f.use and f.use.recipe
end
function UI:RenderCard(f)
    local K, c = ns.TradeKit, self.card
    local q = ns.Markets.Quote(f.id)
    local have = math.max(0, GetItemCount(f.id, true) or 0)
    local unit = ns.Obtain.Cost(f.id) or (q and q.price)
    local rows
    if f.child and f.need then
        local short = math.max(0, f.need - have)
        rows = {{ns.T("matNeedCraft"), ns.T("matUnits", f.need)}, {ns.T("matHave"), ns.T("matUnits", have)},
            {ns.T("matShort"), short > 0 and ns.T("matShortCost", short, K.Money(unit and unit * short)) or ns.T("matEnough")}}
    else
        local use = f.use
        rows = {{ns.T("matHave"), ns.T("matUnits", have)}}
        if use and use.count then rows[#rows + 1] = {ns.T("matUseCount"), ns.T("matUnits", use.count)} end
        if use then rows[#rows + 1] = {ns.T("matGain"), use.gain and K.Money(use.gain) or ns.T("tradeNoPrice")} end
    end
    c.context:SetText(f.owner and ns.T("matInRecipe", ns.Markets.Name(f.owner)) or "")
    for i, label in ipairs(c.topKeys) do
        local row = rows[i]
        label:SetText(row and row[1] or ""); c.topValues[i]:SetText(row and row[2] or "")
    end
    local options = ns.Obtain.Alternatives(f.id)
    for i, label in ipairs(c.wayKeys) do
        local option, value = options[i], c.wayValues[i]
        label:SetText(option and ns.Obtain.Label(option.edge) or "")
        value:SetText(option and (option.cost and K.Money(option.cost) or ns.T("tradeNoPrice")) or "")
        local tone = option and option.best and "accent" or (option and option.cost and "text" or "secondary")
        label:SetTextColor(unpack(K.theme[option and option.best and "accent" or "secondary"]))
        value:SetTextColor(unpack(K.theme[tone]))
    end
    c.marketValues[1]:SetText(q and q.vendor and ns.T("matVendorPrice", K.Money(q.price))
        or q and ns.T("matMarketUnits", q.units or 0, q.lots or 0, K.Money(q.price)) or ns.T("tradeNoPrice"))
    c.marketValues[2]:SetText(q and not q.vendor and q.at and K.Ago(math.max(0, time() - q.at)) or "")
    c.marketKeys[2]:SetText(q and not q.vendor and q.at and ns.T("matMarketAge") or "")
    c:Show()
end
function UI:RenderFocus()
    local K, f = ns.TradeKit, self.focus
    if not f or self.scope == "bags" then
        self.focus = nil
        self.scrollBody:Show(); self.back:Hide(); self.card:Hide(); self.batch:SetProps({})
        return false
    end
    self.scrollBody:Hide()
    self.inspector:SetProps({id = f.id})
    K.Tooltip(self.back, ns.T("matBack"), ns.T("matBackTip", ns.Markets.Name(self.props.id)))
    self.back:Show()
    local recipe = self:FocusRecipe()
    if recipe then
        self.card:Hide()
        local state, policy = self.batchState, ns.ReagentPolicy.Get()
        state.craftAll, state.owned = policy.craftAll, policy.owned
        local catalog = ns.craftCatalogs[recipe.profession]
        self.batch:SetProps({recipe = recipe, options = state, header = f.id,
            known = ns.Recipes.Known(recipe.spell, catalog and ns.T(catalog.labelKey)),
            change = function(key, value, id)
                if key == "make" then state.make[id] = value; state.choice[id] = nil
                elseif key == "ignore" then state.ignore[id] = value or nil
                elseif key == "choice" or key == "craftAll" or key == "owned" then
                    if key ~= "choice" then ns.ReagentPolicy.Set(key, value) end
                    if key ~= "owned" then for chosen in pairs(state.choice) do state.choice[chosen] = nil end end
                elseif key ~= "price" then state[key] = value end
                self:Render()
            end})
    else
        self.batch:SetProps({})
        self:RenderCard(f)
    end
    return true
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
    self.sectionHead:SetProps({lead = self.scopeSegment.frame, filters = not bags and {self.viewMenu.frame, self.picker.frame} or nil})
    local count
    if bags then
        self.tables.all.frame:Hide(); self.tables.bags.frame:Show()
        count = #self:RenderBags()
        self.scan:SetText(ns.T("matBarBags"))
    else
        self.tables.bags.frame:Hide(); self.tables.all.frame:Show()
        count = #self:RenderUses()
        self.scan:SetText(ns.T("matBarUses"))
    end
    K.FitButton(self.scan, 20)
    self.scan.tipTitle = self.scan:GetText()
    self.inspector:SetProps({id = p.id})
    local have = ns.Posting.Have(p.id)
    local width = self.panelScroll:Fit(self:PanelHeight(have))
    self:RenderNext(width)
    self:RenderPost(width, have)
    local fitted = self.panelScroll:Fit(self:PanelHeight(have))
    if fitted ~= width then
        self:RenderNext(fitted)
        self:RenderPost(fitted, have)
        self.panelScroll:Fit(self:PanelHeight(have))
    end
    self:RenderFocus()
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
    self.postTop = -64
    self.panelHeight = -self.postTop + K.PostForm.HEIGHT + 8
    self.panelScroll = K.PanelScroll:New(inspector, "ManaCodeMaterialsPanelScroll", self.panelHeight)
    self.scrollBody, self.panelChild = self.panelScroll.frame, self.panelScroll.child
    local panel = self.panelChild
    self.selection = inspector.item
    self.sell = K.Label(panel, "", 12, -4, 240); self.sell:SetHeight(12)
    self.age = K.Label(panel, "", 12, -20, 200, "secondary")
    self.age:SetHeight(12)
    self.hint = K.Label(panel, "", 12, -36, 240, "secondary"); self.hint:SetHeight(12)
    self.band = K.ActionBand:For(inspector, self.panelScroll)
    local body = inspector.body
    self.back = K.Button(body, ns.T("matBack"), 110, function() self.focus = nil; self:Render() end, "quiet")
    self.back:SetHeight(20); K.FitButton(self.back, 18)
    self.back:SetPoint("TOPLEFT", body, "TOPLEFT", K.theme.inset, -44)
    self.back:Hide()
    self.batch = K.BatchPanel:New(inspector, "ManaCodeMaterialsBatchScroll", 66)
    local card = ns.NewFrame("Frame", nil, body)
    card:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -70)
    card:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, K.ActionBand.HEIGHT)
    self.card = card
    card.context = K.Label(card, "", K.theme.inset, 0, 240, "secondary"); card.context:SetHeight(12)
    card.topKeys, card.topValues = K.ValueRows(card, -18, {"", "", ""}, {labelWidth = 120, valueWidth = 130})
    K.Label(card, ns.T("matWaysTitle"), K.theme.inset, -66, 200, "heading"):SetHeight(14)
    card.wayKeys, card.wayValues = K.ValueRows(card, -84, {"", "", "", ""}, {labelWidth = 160, valueWidth = 80})
    K.Label(card, ns.T("matMarketTitle"), K.theme.inset, -144, 200, "heading"):SetHeight(14)
    card.marketKeys, card.marketValues = K.ValueRows(card, -162, {ns.T("matMarketOffer"), ns.T("matMarketAge")},
        {labelWidth = 90, valueWidth = 160})
    card:Hide()
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
    self.sectionHead = K.SectionHead:New(f)
    self.scopeSegment = K.Segment(f, {{key = "all", label = ns.T("matScopeAll")}, {key = "bags", label = ns.T("matScopeBags")}},
        function(scope) self:SetScope(scope) end, {ns.T("matScopeTitle"), ns.T("matScopeTip")})
    self.viewMenu = K.Menu(f, {{key = "craft", labelKey = "professionCrafts"}, {key = "packs", labelKey = "reagentPacks"}}, function(mode)
        self.mode = mode; self.tables.all:ResetScroll(); self:Render()
    end)
    self.viewMenu.frame:SetWidth(100)
    self.picker = K.FamilyPicker:New(f, function(id) self:SetProps({id = id}) end, true)
    self.picker.frame:SetWidth(224); self.picker.frame.text:SetWidth(176)
    self.picker.fitMax = 224
    local function bagIds()
        local ids = {}
        for _, row in ipairs(ns.Reagents.BagItems(ns.Fee())) do ids[#ids + 1] = row.id end
        return ids
    end
    self.scan = K.ScanBarButton(f, {label = ns.T("matBarUses"),
        run = function(mode)
            if self.scope == "bags" then ns.Batch.Complete(bagIds(), mode, true)
            else ns.Reagents.Complete(self.props.id, mode) end
            self:Render()
        end,
        body = function() return ns.T(self.scope == "bags" and "matScanBagsTip" or "scanReagentSelectionTip") end,
        sources = function()
            if self.scope == "bags" then return bagIds() end
            if self.props.id then return ns.Reagents.Targets(self.props.id) end
        end})
    self.barFrames = {self.scan}
    self.inspector = K.Inspector:New(f)
    self.tables = {}
    self.tables.all = K.Table:New(f, {
        headers = {{key = "item", text = "reagentRecipes"}, {key = "price", text = "tradeUnitPrice"},
            {key = "margin", text = "reagentGain"}, {key = "units", text = "tradeUnits"}},
        columns = function(width, tbl) return K.MarketColumns(width - tbl:Row("row", 1):Reserve()) end,
        kinds = {row = {new = function(parent)
            return K.MarketRow:New(parent, function(_, props) self:SelectUse(props) end,
                function(_, props) self:ToggleUse(props) end, nil, function(_, props) self:OpenUse(props) end)
        end}},
        sort = {default = {key = "margin", desc = true}},
        changed = function() self:Render() end,
        empty = "reagentNoUses",
    })
    self.tables.bags = K.Table:New(f, {
        headers = {{key = "item", text = "matColItem"}, {key = "count", text = "matColCount"}, {key = "cost", text = "matColCost"},
            {key = "market", text = "matColMarket"}, {key = "value", text = "matColValue"}, {key = "posted", text = "matColPosted"}},
        columns = K.BagColumns,
        height = K.Table.LINE,
        kinds = {row = {new = function(parent)
            return K.BagRow:New(parent, function(id) self:SetProps({id = id}) end)
        end}},
        sort = {default = {key = "value", desc = true}},
        changed = function() self:Render() end,
        empty = "matBagsEmpty",
    })
    self:NewPanel(self.inspector)
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
