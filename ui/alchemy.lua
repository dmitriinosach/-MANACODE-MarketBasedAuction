local _, ns = ...
local UI = {props = {profession = "alchemy", recipe = 46376, id = 46376, page = 1},
    rows = {}, groups = {}, collapsed = {}, make = {}, ignore = {}, open = {}, parties = {}, choice = {}}
ns.AlchemyUI = UI
function UI:SwapParty(recipe)
    local p = self.props
    if p.recipe then
        self.parties[p.recipe] = {make = self.make, ignore = self.ignore, choice = self.choice, quantity = p.quantity, craftAll = p.craftAll}
    end
    local party = self.parties[recipe] or {make = {}, ignore = {}, choice = {}, craftAll = false}
    self.make, self.ignore, self.choice, p.quantity, p.craftAll = party.make, party.ignore, party.choice or {}, party.quantity, party.craftAll
end
function UI:SetProps(props)
    if props.profession and props.profession ~= self.props.profession then
        self.props.profession = props.profession
        local catalog = ns.craftCatalogs[props.profession]
        local first = (ns.Hidden.Filter(catalog.recipes, false)[1] or catalog.recipes[1]).raw
        self:SwapParty(first)
        self.props.recipe, self.props.id, self.props.page = first, first, 1
        self.showHidden = false
        self.open = {}
        if self.scroll then self.scroll.offset = 0 end
    end
    if props.recipe and props.recipe ~= self.props.recipe then
        self.props.id = props.recipe
        self:SwapParty(props.recipe)
    end
    if props.reveal then self.revealID = props.recipe or self.props.recipe end
    for key, value in pairs(props) do
        if key ~= "reveal" and key ~= "fee" then self.props[key] = value end
    end
    if props.learnedOnly ~= nil and self.scroll then self.scroll.offset = 0 end
    if props.reveal then
        local catalog = ns.craftCatalogs[self.props.profession]
        local recipe = catalog.byItem[self.props.recipe]
        if recipe and self.props.learnedOnly and ns.Recipes.Known(recipe.spell, ns.T(catalog.labelKey)) ~= true then
            self.props.learnedOnly = false
        end
        if recipe and not ns.Crafting.Shown(recipe) then
            ns.Crafting.SetEpoch(recipe.profession, recipe.expansion or "wrath", true)
        end
    end
    self:Render()
end
function UI:SetEpoch(expansion, shown)
    ns.Crafting.SetEpoch(self.props.profession, expansion, shown)
    if self.scroll then self.scroll.offset = 0 end
    self:Render()
end
function UI:Select(id, row)
    if row and row.hidden then return end
    local owner = row and row.owner
    if not owner then self:SetProps({recipe = id, id = id}); return end
    self:SetProps({recipe = owner})
    for key in pairs(self.open[owner] or {}) do self.make[key] = true end
    self:SetProps({id = id})
end
function UI:ToggleMaterial(id, row)
    local owner = row and row.owner
    if owner then
        local tree = self.open[owner]
        tree[id] = not tree[id] or nil
    else self.open[id] = not self.open[id] and {} or nil end
    self:Render()
end
function UI:Controls()
    if not self.frame then return end
    if ns.Scan.state.phase == "idle" and not ns.Buy.Active() then self.scan:Enable() else self.scan:Disable() end
    if self.batch then self.batch:Controls() end
end
function UI:Options()
    local p, policy = self.props, ns.ReagentPolicy.Get()
    return {make = self.make, ignore = self.ignore, choice = self.choice, craftAll = policy.craftAll, owned = policy.owned,
        fee = ns.Fee(), quantity = p.quantity}
end
function UI:ScanSources()
    return ns.Crafting.ProfessionSources(self.props.profession, self.props.learnedOnly)
end
function UI:RecipeSources()
    local recipe = ns.craftCatalogs[self.props.profession].byItem[self.props.recipe]
    return recipe and ns.Crafting.RecipeSources(recipe, self:Options()) or {}
end
function UI:ScanRecipe()
    local recipe = ns.craftCatalogs[self.props.profession].byItem[self.props.recipe]
    if recipe then ns.Crafting.Complete(recipe, ns.TradeKit.ScanMode(), self:Options()) end
    self:Render()
end
function UI:Render()
    if not self.frame then return end
    local K, p = ns.TradeKit, self.props
    local catalog = ns.craftCatalogs[p.profession]
    self.wide = self.showHidden
    local width = K.CraftLayout(self, -38, 40)
    self.learnedFilter:Select(p.learnedOnly and "known" or "all")
    self:RenderEpochs()
    self.listTitle:SetWidth(math.max(120, width - self.learnedFilter.frame:GetWidth() - self.epochs.frame:GetWidth() - 28))
    local columns = K.MarketColumns(width - self.rows[1]:Reserve(self.wide))
    for key, label in pairs(self.headers) do
        if columns[key] then
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10 + columns[key][1], -38)
            label:SetWidth(columns[key][2]); label:Show()
        else label:Hide() end
    end
    self.sorter:Mark()
    self:RenderList(catalog, width)
    self:Controls()
end
function UI:RenderEpochs()
    local profession = self.props.profession
    self.epochs:SetProps({shown = ns.Crafting.Epochs(profession), counts = ns.Crafting.EpochCounts(profession),
        tip = function(key)
            local counts = ns.Crafting.EpochCounts(profession)
            return ns.T("craftEpochTip", counts[key] or 0, counts.sellable or 0)
        end})
end
function UI:ListEntries(ranked)
    local p = self.props
    local entries, categories, byCategory = {}, {}, {}
    for _, entry in ipairs(ranked) do
        local category = entry.recipe.category
        local bucket = byCategory[category]
        if not bucket then
            bucket = {category = category, key = p.profession .. ":" .. category, entries = {}, priced = 0}
            byCategory[category] = bucket
            categories[#categories + 1] = bucket
        end
        bucket.entries[#bucket.entries + 1] = entry
        if entry.plan.margin then
            bucket.priced = bucket.priced + 1
            bucket.best = math.max(bucket.best or entry.plan.margin, entry.plan.margin)
        end
        if entry.raw == self.revealID then self.collapsed[bucket.key] = nil end
    end
    local hiddenGroups = {}
    for _, bucket in ipairs(categories) do
        if ns.Hidden.IsGroup(bucket.key) then hiddenGroups[#hiddenGroups + 1] = bucket
        else
            entries[#entries + 1] = {category = bucket}
            if not self.collapsed[bucket.key] then
                for _, entry in ipairs(bucket.entries) do
                    entries[#entries + 1] = entry
                    if self.open[entry.raw] then
                        for _, node in ipairs(ns.CraftPlan.Build(entry.recipe, {make = self.open[entry.raw], fee = ns.Fee()}).rows) do
                            entries[#entries + 1] = {node = node, owner = entry.raw}
                        end
                    end
                end
            end
        end
    end
    local hidden = ns.Crafting.Recipes(p.profession, p.learnedOnly, true)
    if #hidden > 0 or #hiddenGroups > 0 then
        entries[#entries + 1] = {spoiler = true, count = #hidden + #hiddenGroups}
        if self.showHidden then
            for _, bucket in ipairs(hiddenGroups) do entries[#entries + 1] = {category = bucket, hiddenGroup = true} end
            for _, recipe in ipairs(hidden) do entries[#entries + 1] = {hiddenRecipe = recipe} end
        end
    end
    return entries
end
ns.Hidden.Describe(function(key)
    local profession, category = key:match("^([^:]+):(.+)$")
    local catalog = profession and ns.craftCatalogs[profession]
    if not catalog then return nil end
    return {name = ns.T(category), place = ns.T(catalog.labelKey)}
end)
function UI:CategoryProps(bucket, width, hiddenGroup, columns)
    local K = ns.TradeKit
    local units = 0
    for _, entry in ipairs(bucket.entries) do
        local q = ns.Markets.Quote(entry.raw)
        units = units + (q and q.units or 0)
    end
    return {key = bucket.key, width = width, open = hiddenGroup or not self.collapsed[bucket.key],
        name = ns.T(bucket.category), detail = ns.T("craftCategoryDetail", #bucket.entries, bucket.priced, K.Money(bucket.best)),
        tip = ns.T("craftCategoryTip"), columns = columns,
        cells = {margin = {bucket.best and K.Money(bucket.best) or nil, K.Tone(bucket.best)},
            units = {units > 0 and tostring(units) or nil, "secondary"}},
        sources = function()
            local ids = {}
            for _, entry in ipairs(bucket.entries) do
                for _, id in ipairs(ns.Crafting.Targets(entry.recipe)) do ids[#ids + 1] = id end
            end
            return ids
        end,
        scanTip = ns.T("craftCategoryScanTip"), hideKey = bucket.key, hidden = hiddenGroup}
end
function UI:Reveal(entries, visible)
    local id = self.revealID
    self.revealID = nil
    for index, entry in ipairs(entries) do
        if entry.raw == id and not entry.node then
            local offset = self.scroll.offset or 0
            if index <= offset or index > offset + visible then self.scroll.offset = math.max(0, index - 2) end
            return
        end
    end
end
function UI:RenderList(catalog, width)
    local K, p = ns.TradeKit, self.props
    local ranked = ns.CraftPlan.Rank(ns.Crafting.Recipes(p.profession, p.learnedOnly),
        {owned = ns.ReagentPolicy.Get().owned, fee = ns.Fee()})
    ranked = self.sorter:Apply(ranked, {
        item = function(entry) return ns.Markets.Name(entry.raw) end,
        price = function(entry) local q = ns.Markets.Quote(entry.raw); return q and q.price end,
        margin = function(entry) return entry.plan.margin end,
        units = function(entry) local q = ns.Markets.Quote(entry.raw); return q and q.units end,
    }, function(entry) return ns.Collections.Pinned(entry.raw) end)
    self.ranked = ranked
    if p.learnedOnly or not p.recipe then
        local selected = false
        for _, entry in ipairs(ranked) do if entry.raw == p.recipe then selected = true end end
        if not selected then
            p.recipe, p.id = ranked[1] and ranked[1].raw or nil, ranked[1] and ranked[1].raw or nil
            self.make, self.ignore, self.choice, p.craftAll, p.quantity = {}, {}, {}, false, nil
        end
    end
    local entries = self:ListEntries(ranked)
    local columns = K.MarketColumns(width - self.rows[1]:Reserve(self.wide))
    local visible = K.ListCapacity(self.frame, 56, 40, 29, #self.rows + #self.groups)
    if self.revealID then self:Reveal(entries, visible) end
    local offset = self.scroll:SetRange(#entries, visible)
    self.spoiler:Hide()
    local usedRows, usedGroups = 0, 0
    for i = 1, visible do
        local entry = entries[offset + i]
        local y = -56 - (i - 1) * 29
        if entry and entry.spoiler then
            self.spoiler:ClearAllPoints()
            self.spoiler:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, y)
            self.spoiler:SetWidth(width); self.spoiler:SetHeight(26)
            self.spoiler:SetText(ns.T(self.showHidden and "hiddenSpoilerOpen" or "hiddenSpoilerClosed", entry.count))
            self.spoiler:Show()
        elseif entry and entry.category then
            usedGroups = usedGroups + 1
            local header = self.groups[usedGroups]
            if header then
                header.frame:ClearAllPoints(); header.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, y)
                header:SetProps(self:CategoryProps(entry.category, width, entry.hiddenGroup, columns))
            end
        elseif entry then
            usedRows = usedRows + 1
            local row = self.rows[usedRows]
            if row then
                row.frame:ClearAllPoints(); row.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, y)
                self:ListRow(row, entry, width)
            end
        end
    end
    for i = usedRows + 1, #self.rows do self.rows[i].frame:Hide() end
    for i = usedGroups + 1, #self.groups do self.groups[i].frame:Hide() end
    self.listTitle:SetText(ns.T("craftListTitle", ns.T(catalog.labelKey), #ranked))
    self.empty:SetWidth(width)
    self.empty:SetText(#ranked == 0 and p.learnedOnly and ns.T("craftKnownEmpty") or "")
    self:RenderPanel(catalog)
end
function UI:Note(recipe)
    local note = recipe.noteKey and ns.T(recipe.noteKey) or recipe.cooldown and ns.T("craftCooldown") or ""
    if recipe.leveling then note = note .. ns.T("craftLevelingNote") end
    if #ns.Crafting.Alternatives(recipe) > 0 then note = note .. ns.T("craftAlternativeNote") end
    for _, input in ipairs(recipe.inputs) do
        local q = ns.Crafting.Quote(input[1])
        if q and q.conditional then note = note .. ns.T("craftConditionalNote", ns.Markets.Name(input[1])); break end
    end
    return note ~= "" and note or nil
end
function UI:RenderPanel(catalog)
    local p = self.props
    local recipe = catalog.byItem[p.recipe]
    if not recipe then
        self.inspector:Clear(); self.category:SetText(ns.T(catalog.labelKey)); self.batch:SetProps({}); return
    end
    self.inspector:SetProps({id = p.id or p.recipe})
    self.category:SetWidth(self.inspector.frame:GetWidth() - 24)
    self.category:SetText(ns.T(recipe.category))
    local known = ns.Recipes.Known(recipe.spell, ns.T(catalog.labelKey))
    self.batch:SetProps({recipe = recipe, known = known, options = self:Options(),
        note = self:Note(recipe),
        selected = p.id ~= p.recipe and p.id or false,
        select = function(id) self:SetProps({id = id or p.recipe}) end,
        scan = {run = function() self:ScanRecipe() end, tip = function()
            return ns.T("scanRecipeSelectionTip") .. "\n\n" .. ns.TradeKit.ScanRule() .. "\n\n"
                .. ns.Batch.PreviewText(self:RecipeSources(), false)
        end},
        reagent = {open = function(id) ns.Trader.OpenReagent(id) end},
        change = function(key, value, id)
            if key == "make" then self.make[id] = value; self.choice[id] = nil; self:Render()
            elseif key == "ignore" then self.ignore[id] = value or nil; self:Render()
            elseif key == "price" then self:Render()
            elseif key == "choice" or key == "craftAll" or key == "owned" then
                if key ~= "choice" then ns.ReagentPolicy.Set(key, value) end
                if key ~= "owned" then for chosen in pairs(self.choice) do self.choice[chosen] = nil end end
                self:Render()
            else self:SetProps({[key] = value}) end
        end,
        buy = function(id, need) ns.Trader.OpenBuy(id, need); return ns.Trader.section == "buy" end})
end
function UI:ListRow(row, entry, width)
    local K, p = ns.TradeKit, self.props
    if entry.hiddenRecipe then
        local recipe = entry.hiddenRecipe
        row:SetProps({id = recipe.raw, active = false, width = width, wide = self.wide, depth = 0,
            expandable = false, hidden = true, hideable = true, noRefresh = true,
            hideLabel = ns.T("hiddenRestore"), detail = ns.T(recipe.category) .. ns.T("hiddenRowNote")})
    elseif entry.node then
        local node = entry.node
        local have = math.max(0, GetItemCount(node.id, true) or 0)
        local q = ns.Alchemy.Quote(node.id)
        local detail = ns.T(have >= node.count and "craftListInputEnough" or "craftListInput", node.count, have)
        if q and q.vendor then detail = detail .. ns.T("cacheVendorRole")
        elseif q and q.conditional then detail = detail .. ns.T("craftConditionalPrice")
        elseif q and q.manual then detail = detail .. ns.T("alchemyOwnPrice") end
        if node.crafted then detail = detail .. ns.T("craftSourceMake") end
        if node.extra and node.extra > 0 then detail = detail .. ns.T("craftExtra", node.extra) end
        K.Tooltip(row.expand, ns.T("craftListExpand"), ns.T("craftListExpandTip"))
        row:SetProps({id = node.id, quote = q, active = entry.owner == p.recipe and node.id == p.id,
            width = width, depth = node.depth + 1,
            expandable = node.expandable, crafted = node.crafted, owner = entry.owner, wide = self.wide,
            detail = detail, extraTip = q and q.conditional and ns.T(q.conditional.noteKey) or ns.T("craftListInputTip")})
    else
        local q = ns.Markets.Quote(entry.raw)
        local catalog = ns.craftCatalogs[p.profession]
        local known = ns.Recipes.Known(entry.recipe.spell, ns.T(catalog.labelKey))
        local state = known == true and "craftListKnown" or known == false and "craftListUnknown" or "craftListUnchecked"
        local detail = ns.T("craftListDetail", ns.T(entry.recipe.category), entry.recipe.count, K.Money(entry.plan.cost))
        detail = ns.T(state, detail)
        local expansion = entry.recipe.expansion or "wrath"
        if expansion ~= "wrath" then detail = detail .. ns.T("craftEpochNote", ns.T(K.EpochChips.labels[expansion])) end
        if entry.recipe.leveling then detail = detail .. ns.T("craftLevelingNote") end
        for _, other in ipairs(ns.Crafting.Alternatives(entry.recipe)) do
            detail = detail .. ns.T("craftAlternative", ns.T(other.category), ns.T(ns.craftCatalogs[other.profession].labelKey),
                K.Money(ns.CraftPlan.Build(other, {fee = ns.Fee()}).cost))
        end
        if q then detail = detail .. ns.T("cacheAge", math.max(0, math.floor((time() - q.at) / 60))) end
        local stock = ns.CraftPlan.Stock(entry.recipe)
        if stock > 0 then detail = detail .. ns.T("craftListStock", stock) end
        K.Tooltip(row.expand, ns.T("craftListExpand"), ns.T("craftListExpandTip"))
        row:SetProps({id = entry.raw, quote = q, active = entry.raw == p.recipe, width = width,
            margin = entry.plan.margin, detail = detail, depth = 0,
            expandable = true, crafted = self.open[entry.raw] ~= nil, wide = self.wide, hideable = true,
            unlearned = known == false, extraTip = ns.T("craftRecipeStatusTip")})
    end
end
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent)
    local f = self.frame
    f:SetAllPoints(parent)
    self.listTitle = K.Label(f, "", 12, -11, 240, "heading")
    self.learnedFilter = K.Segment(f, {{key = "all", label = ns.T("craftFilterAll")},
        {key = "known", label = ns.T("craftFilterKnown")}}, function(key) self:SetProps({learnedOnly = key == "known"}) end,
        {ns.T("craftFilterKnown"), ns.T("craftRecipeStatusTip")})
    self.epochs = K.EpochChips:New(f, ns.Crafting.expansions, function(key, checked) self:SetEpoch(key, checked) end,
        ns.T("craftEpochEmpty"))
    self.empty = K.Label(f, "", 12, -58, 400, "secondary"); self.empty:SetHeight(44)
    self.scan = K.Button(f, ns.T("craftListScan"), 170, function()
        ns.Crafting.CompleteProfession(self.props.profession, K.ScanMode(), self.props.learnedOnly)
        self:Render()
    end, "main")
    self.scan:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -282, 4)
    K.ScanTip(self.scan, ns.T("craftListScan"), ns.T("craftListScanTip"), function()
        return ns.Crafting.ProfessionSources(self.props.profession, self.props.learnedOnly)
    end)
    self.headerBand = K.TableHeader(f, -38)
    self.headers = {}
    for _, entry in ipairs({{"item", "craftListRecipes"}, {"price", "tradeUnitPrice"},
        {"margin", "craftMargin"}, {"units", "tradeUnits"}}) do
        local label = K.Label(f, ns.T(entry[2]), 0, -38, 100)
        if entry[1] ~= "item" then label:SetJustifyH("RIGHT") end
        self.headers[entry[1]] = label
    end
    self.sorter = K.Sorter(f, self.headers, function() self.scroll.offset = 0; self:Render() end, nil, {key = "margin", desc = true})
    self.scroll = K.TableScroll(f, function() self:Render() end, 85, 40, 29)
    for i = 1, 40 do
        local row = K.MarketRow:New(f, function(id, props) self:Select(id, props) end,
            function(id, props) self:ToggleMaterial(id, props) end,
            function(id) self.open[id] = nil; ns.Hidden.Toggle(id); ns.Trader.Refresh() end)
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -56 - (i - 1) * 29)
        row.frame:SetHeight(28)
        self.rows[i] = row
        self.scroll:Wheel(row.frame)
    end
    for i = 1, 10 do
        local header = K.GroupRow:New(f, function(key) self.collapsed[key] = not self.collapsed[key] or nil; self:Render() end,
            function() self:Render() end)
        header.frame:SetHeight(29); header.frame:Hide(); self.scroll:Wheel(header.frame); self.groups[i] = header
    end
    self.spoiler = K.Button(f, "", 400, function() self.showHidden = not self.showHidden; self:Render() end, "quiet")
    self.spoiler.text:ClearAllPoints(); self.spoiler.text:SetPoint("LEFT", self.spoiler, "LEFT", 10, 0)
    self.spoiler:Hide()
    K.Tooltip(self.spoiler, ns.T("hiddenSection"), ns.T("hiddenSpoilerTip"))
    self.inspector = K.Inspector:New(f)
    local panel = self.inspector.body
    self.selection = self.inspector.item
    self.category = K.Label(panel, "", 12, -48, 240)
    self.category:SetHeight(14); self.category:SetJustifyV("TOP")
    self.batch = K.BatchPanel:New(panel)
    self.inspector:SetInfo(ns.T("batchTitle"), ns.T("batchTip"))
    self.batch.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -66)
    self.batch.frame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 8)
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
