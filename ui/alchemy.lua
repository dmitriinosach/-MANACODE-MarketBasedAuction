local _, ns = ...
local UI = {props = {profession = "alchemy", recipe = 46376, id = 46376, page = 1},
    collapsed = {}, make = {}, ignore = {}, open = {}, parties = {}, choice = {}}
ns.AlchemyUI = UI
function UI:SwapParty(recipe)
    local p = self.props
    if p.recipe then
        self.parties[p.recipe] = {make = self.make, ignore = self.ignore, choice = self.choice, quantity = p.quantity, craftAll = p.craftAll}
    end
    local party = self.parties[recipe] or {make = {}, ignore = {}, choice = {}, craftAll = false}
    self.make, self.ignore, self.choice, p.quantity, p.craftAll = party.make, party.ignore, party.choice or {}, party.quantity, party.craftAll
end
function UI:PinList()
    return "craft:" .. self.props.profession
end
function UI:ShowRecipe(recipe)
    local filters = ns.Crafting.Filters()
    if not ns.Crafting.Shown(recipe) then ns.Crafting.SetEpoch(recipe.profession, recipe.expansion or "wrath", true) end
    local known = ns.Recipes.Known(recipe.spell, ns.T(ns.craftCatalogs[recipe.profession].labelKey))
    if known == false and filters.unlearned == false then filters.unlearned = nil end
    local quality = ns.Crafting.Quality(recipe.raw)
    if quality then filters.quality[quality] = nil end
end
function UI:SetProps(props)
    if props.profession and props.profession ~= self.props.profession then
        self.props.profession = props.profession
        self:FitHead()
        local catalog = ns.craftCatalogs[props.profession]
        local first = (ns.Hidden.Filter(catalog.recipes, false)[1] or catalog.recipes[1]).raw
        self:SwapParty(first)
        self.props.recipe, self.props.id, self.props.page = first, first, 1
        self.showHidden = false
        self.open = {}
        if self.table then self.table:ResetScroll() end
    end
    if props.recipe and props.recipe ~= self.props.recipe then
        self.props.id = props.recipe
        self:SwapParty(props.recipe)
    end
    if props.reveal then self.revealID = props.recipe or self.props.recipe end
    for key, value in pairs(props) do
        if key ~= "reveal" and key ~= "fee" then self.props[key] = value end
    end
    if props.reveal then
        local recipe = ns.craftCatalogs[self.props.profession].byItem[self.props.recipe]
        if recipe then self:ShowRecipe(recipe) end
    end
    self:Render()
end
function UI:SetEpoch(expansion, shown)
    ns.Crafting.SetEpoch(self.props.profession, expansion, shown)
    if self.table then self.table:ResetScroll() end
    self:Render()
end
function UI:SetFilter(key, on)
    if on then ns.Crafting.Filters()[key] = nil else ns.Crafting.Filters()[key] = false end
    if self.table then self.table:ResetScroll() end
    self:Render()
end
function UI:ToggleQuality(quality)
    local set = ns.Crafting.Filters().quality
    if set[quality] == false then set[quality] = nil else set[quality] = false end
    if self.table then self.table:ResetScroll() end
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
function UI:TogglePin(id)
    if not ns.Collections.TogglePin(self:PinList(), id) then
        ns.say(ns.T("craftPinLimit", ns.Collections.PIN_MAX), "bad")
    end
    self:Render()
end
function UI:Bar()
    return self.barFrames
end
function UI:Controls()
    if not self.frame then return end
    self.scan:SetBusy(ns.Trader.Busy() and ns.T("batchBusy") or nil)
    if self.batch then self.batch:Controls() end
end
function UI:Options()
    local p, policy = self.props, ns.ReagentPolicy.Get()
    return {make = self.make, ignore = self.ignore, choice = self.choice, craftAll = policy.craftAll, owned = policy.owned,
        fee = ns.Fee(), quantity = p.quantity}
end
function UI:ScanSources()
    return ns.Crafting.ProfessionSources(self.props.profession)
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
    local p = self.props
    local catalog = ns.craftCatalogs[p.profession]
    local filters = ns.Crafting.Filters()
    ns.TradeKit.ScreenBody(self.table, self.inspector)
    self.learnedFilter:SetChecked(filters.unlearned ~= false)
    self.groupSwitch:SetChecked(filters.groups ~= false)
    self:RenderEpochs()
    self:RenderList(catalog)
    self:Controls()
end
local MARGIN_SORT, LEVEL_SORT = {key = "margin", desc = true}, {key = "level", desc = true}
function UI:FitHead()
    if not self.table then return end
    local catalog = ns.craftCatalogs[self.props.profession]
    local epochs = ns.TradeKit.EpochChips.Present(ns.Crafting.EpochCounts(self.props.profession))
    local filters = {}
    if #epochs > 1 then filters[1] = self.epochs.frame
    else
        self.epochs.frame:Hide()
        if epochs[1] then ns.Crafting.SetEpoch(self.props.profession, epochs[1], true) end
    end
    filters[#filters + 1] = self.learnedFilter
    local present, count = ns.Crafting.Qualities(self.props.profession)
    self.quality:SetPresent(present)
    self.qualityCount = count
    if catalog.noQuality or count <= 1 then self.quality.frame:Hide() else filters[#filters + 1] = self.quality.frame end
    if #ns.Crafting.ClassGroups(self.props.profession) > 1 then filters[#filters + 1] = self.classMenu.frame
    else self.classMenu.frame:Hide() end
    filters[#filters + 1] = self.groupSwitch
    self.head.filters = filters
    self.table.sorter.default = catalog.sort == "level" and LEVEL_SORT or MARGIN_SORT
end
function UI:RenderEpochs()
    local profession = self.props.profession
    self.epochs:SetProps({shown = ns.Crafting.Epochs(profession), counts = ns.Crafting.EpochCounts(profession),
        tip = function(key)
            local counts = ns.Crafting.EpochCounts(profession)
            return ns.T("craftEpochTip", counts[key] or 0, counts.sellable or 0)
        end})
    local unknown = 0
    for _, recipe in ipairs(ns.Crafting.Recipes(profession)) do
        if not ns.Crafting.Quality(recipe.raw) then unknown = unknown + 1 end
    end
    self.quality:SetState(ns.Crafting.Filters().quality, unknown)
    local present, count = ns.Crafting.Qualities(profession)
    if count ~= self.qualityCount or not self.quality:Same(present) then
        self:FitHead()
        local head = ns.Trader and ns.Trader.professionHead
        local p = head and head.props
        local ours = false
        for _, frame in ipairs(p and p.filters or {}) do if frame == self.learnedFilter then ours = true end end
        if ours then
            head:SetProps({lead = p.lead, filters = self.head.filters, actions = p.actions, extra = p.extra})
        end
    end
    self:RenderClasses()
end
function UI:RenderClasses()
    local K, profession = ns.TradeKit, self.props.profession
    local groups, entries, on = ns.Crafting.ClassGroups(profession), {}, 0
    if #groups == 0 then return end
    for _, group in ipairs(groups) do
        local shown = not ns.Hidden.IsGroup(profession .. ":" .. group)
        if shown then on = on + 1 end
        entries[#entries + 1] = {key = group, label = ns.T(group), checked = shown}
    end
    self.classMenu:SetEntries(entries)
    self.classMenu.frame:SetText(on == #groups and ns.T("craftClasses") or ns.T("craftClassesCount", on))
    K.FitButton(self.classMenu.frame, 36)
end
function UI:AnyUnlearned(ranked)
    local catalog = ns.craftCatalogs[self.props.profession]
    local line = catalog and ns.T(catalog.labelKey)
    for _, entry in ipairs(ranked) do
        if ns.Recipes.Known(entry.recipe.spell, line) == false then return true end
    end
    return false
end
local function splitLearned(list, known)
    local learned, unlearned = {}, {}
    for _, entry in ipairs(list) do
        entry.divider = nil
        if known(entry) == false then unlearned[#unlearned + 1] = entry else learned[#learned + 1] = entry end
    end
    for i, entry in ipairs(unlearned) do
        entry.divider = i == 1 and #learned > 0 or nil
        learned[#learned + 1] = entry
    end
    return learned
end
function UI:Buckets(rest, known)
    local p, buckets, byKey = self.props, {}, {}
    for index, entry in ipairs(rest) do
        local group = ns.Crafting.Group(entry.recipe)
        local bucket = byKey[group]
        if not bucket then
            bucket = {group = group, key = p.profession .. ":" .. group, entries = {}, priced = 0, first = math.huge, any = index}
            byKey[group] = bucket
            buckets[#buckets + 1] = bucket
        end
        bucket.entries[#bucket.entries + 1] = entry
        if known(entry) ~= false and bucket.first == math.huge then bucket.first = index end
        if entry.raw == self.revealID then self.collapsed[bucket.key] = nil end
    end
    table.sort(buckets, function(a, b)
        local otherA, otherB = a.group == ns.Crafting.OTHER, b.group == ns.Crafting.OTHER
        if otherA ~= otherB then return otherB end
        local rankA, rankB = ns.Crafting.GroupRank(p.profession, a.group), ns.Crafting.GroupRank(p.profession, b.group)
        if rankA ~= rankB then return rankA < rankB end
        if a.first ~= b.first then return a.first < b.first end
        return a.any < b.any
    end)
    return buckets
end
function UI:HiddenGroups()
    local p, result, seen = self.props, {}, {}
    for _, recipe in ipairs(ns.Crafting.Recipes(p.profession)) do
        for _, group in ipairs({ns.Crafting.Group(recipe), recipe.category}) do
            local key = p.profession .. ":" .. group
            if not seen[key] and ns.Hidden.IsGroup(key) then
                seen[key] = {group = group, key = key, entries = {}, priced = 0}
                result[#result + 1] = seen[key]
            end
            if seen[key] then table.insert(seen[key].entries, {raw = recipe.raw, recipe = recipe, plan = {}}); break end
        end
    end
    return result
end
function UI:ListEntries(ranked)
    local p = self.props
    local line = ns.T(ns.craftCatalogs[p.profession].labelKey)
    local function known(entry) return ns.Recipes.Known(entry.recipe.spell, line) end
    local list = self:PinList()
    local pinned, rest = {}, {}
    for _, entry in ipairs(ranked) do
        entry.pinned = ns.Collections.IsPinned(list, entry.raw) or nil
        if entry.pinned then pinned[#pinned + 1] = entry else rest[#rest + 1] = entry end
    end
    local entries = {}
    local function add(entry)
        entries[#entries + 1] = entry
        if self.open[entry.raw] then
            for _, node in ipairs(ns.CraftPlan.Build(entry.recipe, {make = self.open[entry.raw], fee = ns.Fee()}).rows) do
                entries[#entries + 1] = {node = node, owner = entry.raw}
            end
        end
    end
    for _, entry in ipairs(splitLearned(pinned, known)) do add(entry) end
    if ns.Crafting.Filters().groups ~= false then
        for _, bucket in ipairs(self:Buckets(rest, known)) do
            entries[#entries + 1] = {category = bucket}
            if not self.collapsed[bucket.key] then
                for _, entry in ipairs(splitLearned(bucket.entries, known)) do add(entry) end
            end
        end
    else
        local flat = splitLearned(rest, known)
        if #pinned > 0 and flat[1] then flat[1].divider = true end
        for _, entry in ipairs(flat) do add(entry) end
    end
    local hiddenGroups = self:HiddenGroups()
    local hidden = ns.Crafting.Recipes(p.profession, false, true)
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
    local profession, group = key:match("^([^:]+):(.+)$")
    local catalog = profession and ns.craftCatalogs[profession]
    if not catalog then return nil end
    return {name = ns.T(group), place = ns.T(catalog.labelKey)}
end)
function UI:CategoryProps(bucket, width, hiddenGroup, columns)
    local K = ns.TradeKit
    local line = ns.T(ns.craftCatalogs[self.props.profession].labelKey)
    local units, best, any, priced = 0, nil, nil, 0
    for _, entry in ipairs(bucket.entries) do
        local q = ns.Markets.Quote(entry.raw)
        units = units + (q and q.units or 0)
        local margin = entry.plan.margin
        if margin then
            priced = priced + 1
            any = math.max(any or margin, margin)
            if ns.Recipes.Known(entry.recipe.spell, line) ~= false then best = math.max(best or margin, margin) end
        end
    end
    local fallback = best == nil and any ~= nil
    best = best or any
    return {key = bucket.key, width = width, open = hiddenGroup or not self.collapsed[bucket.key],
        name = ns.T(bucket.group), detail = K.Details({ns.T("craftCategoryRecipes", #bucket.entries), ns.T("craftCategoryPriced", priced)}),
        tip = ns.T("craftCategoryTip"), columns = columns,
        cells = {margin = {best and K.Money(best) or nil, fallback and "off" or K.Tone(best)},
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
function UI:RenderList(catalog)
    local K, p = ns.TradeKit, self.props
    local ranked = ns.CraftPlan.Rank(ns.Crafting.Recipes(p.profession, true),
        {owned = ns.ReagentPolicy.Get().owned, fee = ns.Fee()})
    ranked = self.table.sorter:Apply(ranked, {
        item = function(entry) return ns.Markets.Name(entry.raw) end,
        price = function(entry) local q = ns.Markets.Quote(entry.raw); return q and q.price end,
        margin = function(entry) return entry.plan.margin end,
        units = function(entry) local q = ns.Markets.Quote(entry.raw); return q and q.units end,
        level = function(entry) return entry.recipe.req end,
    })
    self.ranked = ranked
    local selected = false
    for _, entry in ipairs(ranked) do if entry.raw == p.recipe then selected = true end end
    if not selected and (#ranked > 0 or p.recipe) then
        p.recipe, p.id = ranked[1] and ranked[1].raw or nil, ranked[1] and ranked[1].raw or nil
        self.make, self.ignore, self.choice, p.craftAll, p.quantity = {}, {}, {}, false, nil
    end
    local entries = self:ListEntries(ranked)
    local reveal
    for i, entry in ipairs(entries) do
        entry.kind = entry.spoiler and "spoiler" or entry.category and "group" or "row"
        entry.depth = entry.node and entry.node.depth + 1 or 0
        if self.revealID and entry.raw == self.revealID then reveal = i end
    end
    self.revealID = nil
    self.table:SetLines(entries, function(entry, width, columns)
        if entry.spoiler then return {count = entry.count, open = self.showHidden} end
        if entry.category then return self:CategoryProps(entry.category, width, entry.hiddenGroup, columns) end
        return self:RowProps(entry, width)
    end, {tree = #ranked > 0, reveal = reveal, cross = self:AnyUnlearned(ranked)})
    local line = ns.T(catalog.labelKey)
    self.unread = ns.Recipes.Rank(line) ~= false and not ns.Recipes.Checked(line)
    self.statusText = nil
    self.statusLink = self.unread and {spell = ns.Recipes.OpenSpell(catalog, line), text = ns.T("craftBookOpen"),
        tip = ns.T("craftBookOpenTip"), preClick = function() ns.Recipes.Expect(line) end} or nil
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
    if not recipe then self.inspector:Clear(); self.batch:SetProps({}); return end
    local header = p.id or p.recipe
    self.inspector:SetProps({id = header})
    local known = ns.Recipes.Known(recipe.spell, ns.T(catalog.labelKey))
    self.batch:SetProps({recipe = recipe, known = known, options = self:Options(), header = header,
        note = self:Note(recipe),
        selected = p.id ~= p.recipe and p.id or false,
        select = function(id) self:SetProps({id = id or p.recipe}) end,
        scan = {run = function() self:ScanRecipe() end, sources = function() return self:RecipeSources() end},
        change = function(key, value, id)
            if key == "make" then self.make[id] = value; self.choice[id] = nil; self:Render()
            elseif key == "ignore" then self.ignore[id] = value or nil; self:Render()
            elseif key == "price" then self:Render()
            elseif key == "choice" or key == "craftAll" or key == "owned" then
                if key ~= "choice" then ns.ReagentPolicy.Set(key, value) end
                if key ~= "owned" then for chosen in pairs(self.choice) do self.choice[chosen] = nil end end
                self:Render()
            else self:SetProps({[key] = value}) end
        end})
end
function UI:RecipeText(entry, q)
    local K, recipe = ns.TradeKit, entry.recipe
    local parts = {}
    if recipe.count > 1 then parts[#parts + 1] = ns.T("craftListYield", recipe.count) end
    parts[#parts + 1] = ns.T("craftListCost", K.Money(entry.plan.cost))
    parts[#parts + 1] = q and q.at and not q.vendor and ns.T("craftScanAgo", K.Ago(math.max(0, time() - q.at)))
        or ns.T("craftGroupNoScan")
    local detail = table.concat(parts, " | ")
    local expansion = recipe.expansion or "wrath"
    if expansion ~= "wrath" then detail = detail .. ns.T("craftEpochNote", ns.T(K.EpochChips.labels[expansion])) end
    if recipe.leveling then detail = detail .. ns.T("craftLevelingNote") end
    if entry.plan.via == "disenchant" then detail = detail .. " | " .. K.Colored(ns.T("craftViaDisenchant"), "positive") end
    local stock = ns.CraftPlan.Stock(recipe)
    if stock > 0 then detail = detail .. ns.T("craftListStock", stock) end
    if q and (q.miss or 0) > 0 then detail = detail .. ns.T("cacheIncomplete") end
    local known = ns.Recipes.Known(recipe.spell, ns.T(ns.craftCatalogs[recipe.profession].labelKey))
    local tips = {}
    if known ~= true then tips[1] = ns.T(known == false and "craftRowUnlearnedTip" or "craftRowUncheckedTip") end
    for _, other in ipairs(ns.Crafting.Alternatives(recipe)) do
        tips[#tips + 1] = ns.T("craftAlternativeTip", ns.T(ns.Crafting.Group(other)), ns.T(ns.craftCatalogs[other.profession].labelKey),
            K.Money(ns.CraftPlan.Plan(other, {fee = ns.Fee()}).cost))
    end
    return detail, table.concat(tips, "\n")
end
function UI:RowProps(entry, width)
    local K, p = ns.TradeKit, self.props
    if entry.hiddenRecipe then
        local recipe = entry.hiddenRecipe
        return {id = recipe.raw, width = width, depth = 0, hidden = true,
            detail = ns.T(ns.Crafting.Group(recipe)) .. ns.T("hiddenRowNote"), units = nil,
            actions = {{label = ns.T("hiddenRestore"), width = 66, tip = ns.T("hiddenRestoreTip"),
                fn = function(id) ns.Hidden.Set(id, false); ns.Trader.Refresh() end}}}
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
        return {id = node.id, owner = entry.owner, width = width, depth = node.depth + 1,
            active = entry.owner == p.recipe and node.id == p.id, detail = detail,
            price = q and q.price, units = q and q.units, marginText = "",
            expandable = node.expandable, opened = node.crafted,
            tip = q and q.conditional and ns.T(q.conditional.noteKey) or ns.T("craftListInputTip"),
            actions = not (q and (q.vendor or q.conditional)) and {{label = ns.T("craftScanRow"), icon = "refresh",
                tip = ns.T("craftScanRowTip"), sources = function() return {node.id} end,
                fn = function(id) ns.Batch.Complete({id}, K.ScanMode(), true); self:Render() end}} or {}}
    end
    local recipe = entry.recipe
    local q = ns.Markets.Quote(entry.raw)
    local known = ns.Recipes.Known(recipe.spell, ns.T(ns.craftCatalogs[p.profession].labelKey))
    local detail, tip = self:RecipeText(entry, q)
    local cost = entry.plan.cost
    return {id = entry.raw, width = width, depth = 0, active = entry.raw == p.recipe, detail = detail, tip = tip,
        price = q and q.price, change = ns.Family.Change(entry.raw), margin = entry.plan.margin,
        percent = entry.plan.margin and cost and cost > 0 and entry.plan.margin / cost * 100 or nil,
        units = q and q.units, unlearned = known == false, divider = entry.divider,
        favorite = ns.Collections.Favorite(entry.raw), pinnable = true, pinned = entry.pinned,
        expandable = true, opened = self.open[entry.raw] ~= nil,
        actions = {{label = ns.T("craftScanRow"), icon = "refresh", tip = ns.T("craftScanRecipeTip"),
                sources = function() return ns.Alchemy.Targets(recipe) end,
                fn = function() ns.Crafting.Complete(recipe, K.ScanMode()); self:Render() end},
            {label = ns.T("hiddenHide"), icon = "hide", tip = ns.T("hiddenHideTip"),
                fn = function(id) self.open[id] = nil; ns.Hidden.Set(id, true); ns.Trader.Refresh() end}}}
end
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent)
    local f = self.frame
    f:SetAllPoints(parent)
    self.epochs = K.EpochChips:New(f, ns.Crafting.expansions, function(key, checked) self:SetEpoch(key, checked) end,
        ns.T("craftEpochEmpty"))
    self.learnedFilter = K.Switch(f, ns.T("craftUnlearnedSwitch"), function(on) self:SetFilter("unlearned", on) end)
    K.Tooltip(self.learnedFilter, ns.T("craftUnlearnedSwitch"), ns.T("craftUnlearnedSwitchTip"))
    self.quality = K.QualityToggles:New(f, {1, 2, 3, 4}, function(quality) self:ToggleQuality(quality) end)
    self.classMenu = K.Menu(f, {}, function(group)
        local profession = self.props.profession
        ns.Crafting.HideGroup(profession, group, not ns.Hidden.IsGroup(profession .. ":" .. group))
        self:Render()
    end)
    self.classMenu.keep, self.classMenu.bounds = true, f
    self.classMenu.frame:SetHeight(22)
    K.Tooltip(self.classMenu.frame, ns.T("craftClasses"), ns.T("craftClassesTip"))
    self.groupSwitch = K.Switch(f, ns.T("craftGroupsSwitch"), function(on) self:SetFilter("groups", on) end)
    K.Tooltip(self.groupSwitch, ns.T("craftGroupsSwitch"), ns.T("craftGroupsSwitchTip"))
    self.scan = K.ScanBarButton(f, {label = ns.T("craftBarRecipes"),
        run = function(mode)
            ns.Crafting.CompleteProfession(self.props.profession, mode)
            self:Render()
        end,
        sources = function() return ns.Crafting.ProfessionSources(self.props.profession) end,
        body = ns.T("craftListScanTip")})
    self.scan.tipTitle = ns.T("craftListScan")
    self.barFrames = {self.scan}
    self.head = {filters = {self.epochs.frame, self.learnedFilter, self.quality.frame, self.groupSwitch}}
    self.table = K.Table:New(f, {
        headers = {{key = "item", text = "craftListRecipes"}, {key = "price", text = "tradeUnitPrice"},
            {key = "margin", text = "craftMargin"}, {key = "units", text = "tradeUnits"}},
        columns = K.CraftColumns,
        kinds = {
            row = {new = function(parent)
                return K.CraftRow:New(parent, function(id, props) self:Select(id, props) end,
                    function(id, props) self:ToggleMaterial(id, props) end, function(id) self:TogglePin(id) end)
            end},
            group = {new = function(parent)
                return K.GroupRow:New(parent, function(key) self.collapsed[key] = not self.collapsed[key] or nil; self:Render() end,
                    function() self:Render() end)
            end},
        },
        spoiler = {toggle = function() self.showHidden = not self.showHidden; self:Render() end},
        sort = {default = MARGIN_SORT},
        changed = function() self:Render() end,
        empty = "craftFilteredEmpty",
    })
    self.inspector = K.Inspector:New(f)
    self.selection = self.inspector.item
    self.batch = K.BatchPanel:New(self.inspector, "ManaCodeCraftBatchScroll")
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:FitHead()
    self:Render()
    return self
end
