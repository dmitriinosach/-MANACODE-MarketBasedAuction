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
    if props.reveal then
        local recipe = ns.craftCatalogs[self.props.profession].byItem[self.props.recipe]
        if recipe then self:ShowRecipe(recipe) end
    end
    self:Render()
end
function UI:SetEpoch(expansion, shown)
    ns.Crafting.SetEpoch(self.props.profession, expansion, shown)
    if self.scroll then self.scroll.offset = 0 end
    self:Render()
end
function UI:SetFilter(key, on)
    if on then ns.Crafting.Filters()[key] = nil else ns.Crafting.Filters()[key] = false end
    if self.scroll then self.scroll.offset = 0 end
    self:Render()
end
function UI:ToggleQuality(quality)
    local set = ns.Crafting.Filters().quality
    if set[quality] == false then set[quality] = nil else set[quality] = false end
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
function UI:TogglePin(id)
    if not ns.Collections.TogglePin(self:PinList(), id) then
        ns.say(ns.T("craftPinLimit", ns.Collections.PIN_MAX), "bad")
    end
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
    local K, p = ns.TradeKit, self.props
    local catalog = ns.craftCatalogs[p.profession]
    local filters = ns.Crafting.Filters()
    local width = K.CraftLayout(self, -38, 4)
    self.learnedFilter:SetChecked(filters.unlearned ~= false)
    self.groupSwitch:SetChecked(filters.groups ~= false)
    self:RenderEpochs()
    self.listTitle:SetWidth(math.max(120, width - 4))
    local columns = K.CraftColumns(width)
    K.PlaceHeaders(self.headers, columns, self.frame, -38, true)
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
    local unknown = 0
    for _, recipe in ipairs(ns.Crafting.Recipes(profession)) do
        if not ns.Crafting.Quality(recipe.raw) then unknown = unknown + 1 end
    end
    self.quality:SetState(ns.Crafting.Filters().quality, unknown)
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
function UI:Reveal(entries, visible)
    local id = self.revealID
    self.revealID = nil
    for index, entry in ipairs(entries) do
        if entry.raw == id and not entry.node and not entry.hiddenRecipe then
            local offset = self.scroll.offset or 0
            if index <= offset or index > offset + visible then self.scroll.offset = math.max(0, index - 2) end
            return
        end
    end
end
function UI:RenderList(catalog, width)
    local K, p = ns.TradeKit, self.props
    local ranked = ns.CraftPlan.Rank(ns.Crafting.Recipes(p.profession, true),
        {owned = ns.ReagentPolicy.Get().owned, fee = ns.Fee()})
    ranked = self.sorter:Apply(ranked, {
        item = function(entry) return ns.Markets.Name(entry.raw) end,
        price = function(entry) local q = ns.Markets.Quote(entry.raw); return q and q.price end,
        margin = function(entry) return entry.plan.margin end,
        units = function(entry) local q = ns.Markets.Quote(entry.raw); return q and q.units end,
    })
    self.ranked = ranked
    local selected = false
    for _, entry in ipairs(ranked) do if entry.raw == p.recipe then selected = true end end
    if not selected and (#ranked > 0 or p.recipe) then
        p.recipe, p.id = ranked[1] and ranked[1].raw or nil, ranked[1] and ranked[1].raw or nil
        self.make, self.ignore, self.choice, p.craftAll, p.quantity = {}, {}, {}, false, nil
    end
    local entries = self:ListEntries(ranked)
    local columns = K.CraftColumns(width)
    local visible = K.ListCapacity(self.frame, 56, 4, 30, #self.rows + #self.groups)
    if self.revealID then self:Reveal(entries, visible) end
    local offset = self.scroll:SetRange(#entries, visible)
    self.spoiler:Hide()
    local usedRows, usedGroups, gap = 0, 0, 0
    local placed = {}
    for i = 1, visible do
        local entry = entries[offset + i]
        if entry and entry.divider and i > 1 then gap = gap + K.DIVIDER_GAP end
        local y = -56 - (i - 1) * 30 - gap
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
                placed[#placed + 1] = {row, self:RowProps(entry, width)}
            end
        end
    end
    local crossed = false
    for _, pair in ipairs(placed) do crossed = crossed or pair[2].unlearned end
    for _, pair in ipairs(placed) do pair[1].compact = not crossed; pair[1]:SetProps(pair[2]) end
    for i = usedRows + 1, #self.rows do self.rows[i].frame:Hide() end
    for i = usedGroups + 1, #self.groups do self.groups[i].frame:Hide() end
    local line = ns.T(catalog.labelKey)
    self.unread = ns.Recipes.Rank(line) ~= false and not ns.Recipes.Checked(line)
    self.listTitle:SetText(ns.T("craftListTitle", line, #ranked)
        .. (self.unread and "  " .. K.Colored(ns.T("craftBookUnread"), "negative") or ""))
    self.empty:SetWidth(width)
    self.empty:SetText(#ranked == 0 and ns.T("craftFilteredEmpty") or "")
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
    local stock = ns.CraftPlan.Stock(recipe)
    if stock > 0 then detail = detail .. ns.T("craftListStock", stock) end
    if q and (q.miss or 0) > 0 then detail = detail .. ns.T("cacheIncomplete") end
    local known = ns.Recipes.Known(recipe.spell, ns.T(ns.craftCatalogs[recipe.profession].labelKey))
    local tips = {}
    if known ~= true then tips[1] = ns.T(known == false and "craftRowUnlearnedTip" or "craftRowUncheckedTip") end
    for _, other in ipairs(ns.Crafting.Alternatives(recipe)) do
        tips[#tips + 1] = ns.T("craftAlternativeTip", ns.T(ns.Crafting.Group(other)), ns.T(ns.craftCatalogs[other.profession].labelKey),
            K.Money(ns.CraftPlan.Build(other, {fee = ns.Fee()}).cost))
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
    self.listTitle = K.Label(f, "", 12, -11, 240, "heading")
    self.titleHelp = ns.NewFrame("Frame", nil, f)
    self.titleHelp:SetAllPoints(self.listTitle); self.titleHelp:EnableMouse(true)
    K.Tooltip(self.titleHelp, ns.T("craftBookTitle"), "")
    self.titleHelp.tipFn = function()
        local line = ns.T(ns.craftCatalogs[self.props.profession].labelKey)
        local at = ns.Recipes.Checked(line)
        if at then return ns.T("craftBookRead", K.Ago(time() - at)) end
        return ns.T(self.unread and "craftBookUnreadTip" or "craftBookAbsent")
    end
    self.epochs = K.EpochChips:New(f, ns.Crafting.expansions, function(key, checked) self:SetEpoch(key, checked) end,
        ns.T("craftEpochEmpty"))
    self.learnedFilter = K.Switch(f, ns.T("craftUnlearnedSwitch"), function(on) self:SetFilter("unlearned", on) end)
    K.Tooltip(self.learnedFilter, ns.T("craftUnlearnedSwitch"), ns.T("craftUnlearnedSwitchTip"))
    self.quality = K.QualityToggles:New(f, {1, 2, 3, 4}, function(quality) self:ToggleQuality(quality) end)
    self.groupSwitch = K.Switch(f, ns.T("craftGroupsSwitch"), function(on) self:SetFilter("groups", on) end)
    K.Tooltip(self.groupSwitch, ns.T("craftGroupsSwitch"), ns.T("craftGroupsSwitchTip"))
    self.empty = K.Label(f, "", 12, -58, 400, "secondary"); self.empty:SetHeight(44)
    self.scan = K.Button(f, ns.T("cacheComplete"), 90, function()
        ns.Crafting.CompleteProfession(self.props.profession, K.ScanMode())
        self:Render()
    end, "main")
    K.FitButton(self.scan, 24)
    K.ScanTip(self.scan, ns.T("craftListScan"), ns.T("craftListScanTip"), function()
        return ns.Crafting.ProfessionSources(self.props.profession)
    end)
    self.head = {filters = {self.epochs.frame, self.learnedFilter, self.quality.frame, self.groupSwitch}, actions = {self.scan}}
    self.headerBand = K.TableHeader(f, -38)
    self.headers = {}
    for _, entry in ipairs({{"item", "craftListRecipes"}, {"price", "tradeUnitPrice"},
        {"margin", "craftMargin"}, {"units", "tradeUnits"}}) do
        local label = K.Label(f, ns.T(entry[2]), 0, -38, 100)
        label:SetHeight(12)
        if entry[1] ~= "item" then label:SetJustifyH("RIGHT") end
        self.headers[entry[1]] = label
    end
    self.sorter = K.Sorter(f, self.headers, function() self.scroll.offset = 0; self:Render() end, nil, {key = "margin", desc = true})
    self.scroll = K.TableScroll(f, function() self:Render() end, 85, 4, 30)
    for i = 1, 40 do
        local row = K.CraftRow:New(f, function(id, props) self:Select(id, props) end,
            function(id, props) self:ToggleMaterial(id, props) end, function(id) self:TogglePin(id) end)
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -56 - (i - 1) * 30)
        row.frame:Hide()
        self.rows[i] = row
        self.scroll:Wheel(row.frame)
    end
    for i = 1, 24 do
        local header = K.GroupRow:New(f, function(key) self.collapsed[key] = not self.collapsed[key] or nil; self:Render() end,
            function() self:Render() end)
        header.frame:SetHeight(29); header.frame:Hide(); self.scroll:Wheel(header.frame); self.groups[i] = header
    end
    self.spoiler = K.Button(f, "", 400, function() self.showHidden = not self.showHidden; self:Render() end, "quiet")
    self.spoiler.text:ClearAllPoints(); self.spoiler.text:SetPoint("LEFT", self.spoiler, "LEFT", 10, 0)
    self.spoiler:Hide()
    K.Tooltip(self.spoiler, ns.T("hiddenSection"), ns.T("hiddenSpoilerTip"))
    self.inspector = K.Inspector:New(f)
    self.selection = self.inspector.item
    self.batch = K.BatchPanel:New(self.inspector, "ManaCodeCraftBatchScroll")
    self.inspector:SetInfo(ns.T("batchTitle"), ns.T("batchTip"))
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
