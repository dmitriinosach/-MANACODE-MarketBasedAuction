local _, ns = ...
local A = {}
ns.Alchemy = A
ns.Crafting = A
ns.craftCatalogs = ns.craftCatalogs or {}
ns.craftCatalogs.alchemy = {labelKey = "alchemySection", recipes = ns.alchemyRecipes}
A.order = {"alchemy", "enchanting", "tailoring", "blacksmithing", "engineering", "leatherworking",
    "inscription", "cooking", "firstaid", "mining", "jewelry"}
A.expansions = {"wrath", "bc", "classic"}
A.items, A.inputs, A.byItem, A.makers, A.epochs = {}, {}, {}, {}, {}
for _, key in ipairs(A.order) do
    local catalog = ns.craftCatalogs[key]
    if catalog then
        catalog.byItem = {}
        for _, recipe in ipairs(catalog.recipes) do
            recipe.profession = key
            catalog.byItem[recipe.raw], A.items[recipe.raw] = recipe, true
            A.makers[recipe.raw] = A.makers[recipe.raw] or {}
            table.insert(A.makers[recipe.raw], recipe)
            local current = A.byItem[recipe.raw]
            if not current or current.category == "alchemyTransmutes" and recipe.category ~= "alchemyTransmutes" then
                A.byItem[recipe.raw] = recipe
            end
            for _, input in ipairs(recipe.inputs) do
                A.items[input[1]], A.inputs[input[1]] = true, true
            end
            for _, slot in ipairs(recipe.slots or {}) do
                for _, option in ipairs(slot.options) do A.items[option.itemID] = true end
            end
            for deck in pairs(recipe.decks or {}) do A.items[deck] = true end
        end
    end
end
for _, use in ipairs(ns.professionUses or {}) do
    for _, input in ipairs(use.inputs) do A.items[input[1]], A.inputs[input[1]] = true, true end
end
for _, catalog in pairs(ns.gatheringCatalogs or {}) do
    for _, id in ipairs(catalog.items) do A.items[id], A.inputs[id] = true, true end
end
local function prices()
    local db = ns.Store.DB()
    db.alchemyPrices = db.alchemyPrices or {}
    local key = ns.Markets.Key()
    db.alchemyPrices[key] = db.alchemyPrices[key] or {}
    return db.alchemyPrices[key]
end
function A.IsInput(id)
    return A.inputs[id] or false
end
function A.SetPrice(id, copper)
    if not A.IsInput(id) or ns.vendorPrices[id] then return false end
    if copper and (copper ~= copper or copper < 0 or copper > 1000000000) then return false end
    if not copper then ns.Markets.Forget(ns.Store.DB().alchemyPrices, id); return true end
    prices()[id] = math.floor(copper + 0.5)
    return true
end
function A.Quote(id)
    local q = ns.Markets.Quote(id)
    if ns.vendorPrices[id] then return q end
    local price = ns.Markets.Lookup(ns.Store.DB().alchemyPrices, id)
    local conditional = price == nil and ns.conditionalPrices and ns.conditionalPrices[id]
    if conditional then
        return {price = conditional.price, miss = 0, units = q and q.units or 0, lots = q and q.lots or 0, at = time(),
            manual = true, conditional = conditional, complete = true}
    end
    if price == nil then return q end
    return {price = price, miss = 0, units = q and q.units or 0, lots = q and q.lots or 0, at = time(), manual = true}
end
function A.Estimate(recipe, fee)
    local cost = 0
    for _, input in ipairs(recipe.inputs) do
        local q = A.Quote(input[1])
        if not q or not q.price or q.miss > 0 then return {} end
        cost = cost + q.price * input[2]
    end
    local result = {cost = cost, unitCost = cost / recipe.count}
    local output = ns.Markets.Quote(recipe.raw)
    if recipe.slots then result.revenue = A.Expected(recipe, fee)
    elseif output and output.price and output.miss == 0 then result.revenue = output.price * recipe.count * (1 - fee) end
    if result.revenue then
        result.margin = result.revenue - cost
        result.unitMargin = result.margin / recipe.count
    end
    return result
end
function A.Expected(recipe, fee)
    local estimate = ns.Prospect.Estimate(recipe, nil, fee)
    return estimate.exact and estimate.net or nil
end
function A.Targets(recipe)
    if ns.CraftPlan then return ns.CraftPlan.Targets(recipe) end
    local ids = {recipe.raw}
    for _, input in ipairs(recipe.inputs) do
        if ns.vendorPrices[input[1]] or ns.Markets.Lookup(ns.Store.DB().alchemyPrices, input[1]) == nil then
            ids[#ids + 1] = input[1]
        end
    end
    return ids
end
function A.Scan(recipe)
    if ns.Hidden.Is(recipe.raw) then return false end
    return ns.Batch.Start(A.Targets(recipe))
end
function A.RecipeSources(recipe, options)
    return options and ns.CraftPlan.Targets(recipe, options) or A.Targets(recipe)
end
function A.Solo(recipe)
    return {recipe.raw}
end
function A.Complete(recipe, mode, options, solo)
    if ns.Hidden.Is(recipe.raw) then return false end
    return ns.Batch.Complete(solo and A.Solo(recipe) or A.RecipeSources(recipe, options), mode, true)
end
function A.Epochs(profession)
    A.epochs[profession] = A.epochs[profession] or {wrath = true, bc = false, classic = false}
    return A.epochs[profession]
end
function A.SetEpoch(profession, expansion, shown)
    local epochs = A.Epochs(profession)
    if not shown and ns.craftCatalogs[profession] then
        local counts = A.EpochCounts(profession)
        local remaining = 0
        for _, key in ipairs(A.expansions) do
            if key ~= expansion and epochs[key] then remaining = remaining + (counts[key] or 0) end
        end
        if remaining == 0 and (counts[expansion] or 0) > 0 then return end
    end
    epochs[expansion] = shown and true or false
end
function A.Shown(recipe)
    return A.Epochs(recipe.profession)[recipe.expansion or "wrath"] or recipe.sellable == true
end
function A.EpochCounts(profession)
    local counts = {}
    local filters = A.Filters(profession)
    local quality = A.EffectiveQuality(profession)
    for _, recipe in ipairs(ns.craftCatalogs[profession].recipes) do
        local expansion = recipe.expansion or "wrath"
        if A.LearnedPasses(recipe) and A.FoodStatPasses(recipe, filters) and not ns.Hidden.Is(recipe.raw) and not A.GroupHidden(recipe) then
            if ns.craftCatalogs[profession].noQuality or A.QualityPasses(recipe.raw, quality) then
                counts[expansion] = (counts[expansion] or 0) + 1
                if recipe.sellable then counts.sellable = (counts.sellable or 0) + 1 end
            end
        end
    end
    return counts
end
function A.EnsureEpochs(profession)
    local counts, epochs = A.EpochCounts(profession), A.Epochs(profession)
    local shown = 0
    for _, key in ipairs(A.expansions) do if epochs[key] then shown = shown + (counts[key] or 0) end end
    if shown > 0 then return end
    for _, key in ipairs(A.expansions) do
        if (counts[key] or 0) > 0 then epochs[key] = true; return end
    end
end
function A.Alternatives(recipe)
    local result = {}
    for _, other in ipairs(A.makers[recipe.raw] or {}) do
        if other ~= recipe then result[#result + 1] = other end
    end
    return result
end
A.OTHER = "craftGroupOther"
local groupSizes = {}
function A.Group(recipe)
    local key, sizes = A.GroupKey(recipe), groupSizes[recipe.profession]
    if not sizes then
        sizes = {}
        for _, other in ipairs(ns.craftCatalogs[recipe.profession].recipes) do
            local name = A.GroupKey(other)
            sizes[name] = (sizes[name] or 0) + 1
        end
        groupSizes[recipe.profession] = sizes
    end
    return (sizes[key] or 0) < 2 and A.OTHER or key
end
A.GROUP_ORDER = {
    engineering = {"craftMounts", "engineeringAmmo", "engineeringScopes", "engineeringExplosives",
        "slotHead", "slotTrinket", "slotRanged", "*", "engineeringGadgets", "engineeringMaterials"},
    leatherworking = {"leatherworkingEnhancements", "leatherworkingDrums", "leatherworkingBags", "*",
        "leatherworkingMaterials"},
    inscription = {"inscriptionVellums", "*"},
}
function A.HideGroup(profession, group, hidden)
    ns.Hidden.SetGroup(profession .. ":" .. group, hidden)
end
function A.ClassGroups(profession)
    local groups, seen = {}, {}
    for _, recipe in ipairs(ns.craftCatalogs[profession].recipes) do
        local group = recipe.group
        if group and group:sub(1, 5) == "glyph" and not seen[group] then seen[group] = true; groups[#groups + 1] = group end
    end
    table.sort(groups, function(a, b) return ns.T(a) < ns.T(b) end)
    return groups
end
function A.GroupRank(profession, group)
    local order = A.GROUP_ORDER[profession]
    if not order then return 0 end
    local rest = #order + 1
    for i, key in ipairs(order) do
        if key == group then return i end
        if key == "*" then rest = i end
    end
    return rest
end
local EPOCH_GROUPS = {wrath = "craftWrath", bc = "craftBC", classic = "craftClassic"}
function A.GroupKey(recipe)
    if ns.craftCatalogs[recipe.profession].groupByEpoch then return EPOCH_GROUPS[recipe.expansion or "wrath"] end
    return recipe.group or recipe.category
end
function A.GroupHidden(recipe)
    return ns.Hidden.IsGroup(recipe.profession .. ":" .. A.Group(recipe))
        or ns.Hidden.IsGroup(recipe.profession .. ":" .. recipe.category)
end
function A.Filters(profession)
    local db = ns.Store.DB()
    if type(db.listFilters) ~= "table" then db.listFilters = {} end
    local filters = db.listFilters.craft
    if type(filters) ~= "table" then filters = {}; db.listFilters.craft = filters end
    if type(filters.quality) ~= "table" then filters.quality = {} end
    if type(filters.professions) ~= "table" then
        filters.professions = {}
        local allOff = filters.quality[2] == false and filters.quality[3] == false and filters.quality[4] == false
        for key in pairs(ns.craftCatalogs) do
            local quality = {}
            if not allOff then for q, on in pairs(filters.quality) do quality[q] = on end end
            filters.professions[key] = {quality = quality}
        end
        local jewelry = db.listFilters.jewelry
        if type(jewelry) == "table" then
            if filters.unlearned == true or jewelry.unlearned == true then filters.unlearned = true
            elseif filters.unlearned == nil then filters.unlearned = jewelry.unlearned end
        end
        if type(jewelry) == "table" then jewelry.unlearned = nil end
    end
    if profession then
        local own = filters.professions[profession]
        if type(own) ~= "table" then own = {}; filters.professions[profession] = own end
        if type(own.quality) ~= "table" then own.quality = {} end
        return own
    end
    return filters
end
function A.Quality(id)
    local _, _, quality = ns.Compat.ItemInfo(id)
    if quality then return quality end
    local text = ns.Store.DB().items[id]
    local stored = text and tonumber(text:match("\t(%d+)$"))
    return stored and stored > 0 and stored or nil
end
local qualityView
function A.Qualities(profession, allEpochs)
    if qualityView and qualityView.profession == profession and not allEpochs then
        return qualityView.present, qualityView.count
    end
    local present, count = {}, 0
    for _, recipe in ipairs(ns.craftCatalogs[profession].recipes) do
        local q = false
        if (allEpochs or A.Shown(recipe)) and A.LearnedPasses(recipe) and not ns.Hidden.Is(recipe.raw) and not A.GroupHidden(recipe) then q = A.Quality(recipe.raw) end
        if q then
            q = math.max(1, math.min(4, q))
            if not present[q] then present[q], count = true, count + 1 end
        end
    end
    return present, count
end
function A.WithView(profession, draw)
    local previous = qualityView
    local present, count = A.Qualities(profession)
    qualityView = {profession = profession, present = present, count = count}
    local ok, reason = pcall(draw)
    qualityView = previous
    if not ok then error(reason) end
end
function A.LearnedPasses(recipe)
    return A.Filters().unlearned ~= false
        or ns.Recipes.Known(recipe.spell, ns.T(ns.craftCatalogs[recipe.profession].labelKey)) ~= false
end
function A.EffectiveQuality(profession)
    local present, count = A.Qualities(profession)
    local quality, on = A.Filters(profession).quality, false
    for q in pairs(present) do on = on or quality[q] ~= false end
    return (count <= 1 or not on) and {} or quality, count
end
function A.QualityPasses(id, quality)
    local q = A.Quality(id)
    return not q or quality[q] ~= false
end
function A.Passes(recipe, filters, qualityCount, skipStat, quality)
    filters = filters or A.Filters(recipe.profession)
    if not A.LearnedPasses(recipe) then return false end
    if not skipStat and not A.FoodStatPasses(recipe, filters) then return false end
    if ns.craftCatalogs[recipe.profession].noQuality then return true end
    if not quality then quality, qualityCount = A.EffectiveQuality(recipe.profession) end
    return qualityCount <= 1 or A.QualityPasses(recipe.raw, quality)
end
function A.Recipes(profession, filtered, hidden, skipStat)
    local catalog, result = ns.craftCatalogs[profession], {}
    if filtered then A.EnsureEpochs(profession) end
    local filters = filtered and A.Filters(profession)
    local quality, qualityCount = A.EffectiveQuality(profession)
    for _, recipe in ipairs(ns.Hidden.Filter(catalog.recipes, hidden == true)) do
        if A.Shown(recipe) and (not filtered or not A.GroupHidden(recipe) and A.Passes(recipe, filters, qualityCount, skipStat, quality)) then
            result[#result + 1] = recipe
        end
    end
    return result
end
function A.FoodStatPasses(recipe, filters)
    if recipe.profession ~= "cooking" or not filters.stat then return true end
    local item = ns.searchItems and ns.searchItems[recipe.raw]
    return ns.Search.StatAvailable(item, filters.stat)
end
function A.FoodStatCounts(profession)
    local counts = {}
    if profession ~= "cooking" then return counts end
    for _, recipe in ipairs(A.Recipes(profession, true, false, true)) do
        local item = ns.searchItems and ns.searchItems[recipe.raw]
        for key in pairs(item and item.stats or {}) do
            if ns.Search.StatAvailable(item, key) then counts[key] = (counts[key] or 0) + 1 end
        end
    end
    return counts
end
function A.ProfessionSources(profession)
    local ids = {}
    for _, recipe in ipairs(A.Recipes(profession, true)) do
        for _, id in ipairs(A.Targets(recipe)) do ids[#ids + 1] = id end
    end
    return ids
end
function A.CompleteProfession(profession, mode)
    return ns.Batch.Complete(A.ProfessionSources(profession), mode, true)
end
function A.ResourceExpansion(profession, id)
    local process = ns.Reagents.Process(id)
    if process and process.source.expansion then return process.source.expansion end
    local catalog = ns.gatheringCatalogs[profession]
    return catalog.epochs and catalog.epochs[id] or catalog.expansion or "wrath"
end
function A.ResourceKey(profession, id)
    return "raw:" .. profession .. ":" .. id
end
function A.HideResource(profession, id, hidden)
    ns.Hidden.SetGroup(A.ResourceKey(profession, id), hidden)
end
function A.Resources(profession, all)
    local ids, epochs = {}, A.Epochs(profession)
    for _, id in ipairs(ns.Reagents.Resources(profession)) do
        if (all or epochs[A.ResourceExpansion(profession, id)]) and not ns.Hidden.IsGroup(A.ResourceKey(profession, id)) then
            ids[#ids + 1] = id
        end
    end
    return ids
end
function A.ResourceCounts(profession)
    local counts = {}
    for _, id in ipairs(A.Resources(profession, true)) do
        local expansion = A.ResourceExpansion(profession, id)
        counts[expansion] = (counts[expansion] or 0) + 1
    end
    return counts
end
A.RESOURCE_USES = {fishing = {"cooking"}, skinning = {"leatherworking"}, herbalism = {"alchemy"}, mining = {"mining"}}
function A.Gain(margin, cost, units)
    if not margin or not cost or units <= 0 then return nil end
    return (margin + cost * ns.Fee()) / units
end
function A.ProcessGain(estimate)
    if not estimate or not estimate.exact then return nil end
    return A.Gain(estimate.margin, estimate.cost, ns.Prospect.OPERATION)
end
function A.Uses(profession, id)
    local result, fee, quote = {}, ns.Fee(), A.Quote(id)
    local price = quote and quote.miss == 0 and quote.complete ~= false and quote.price or nil
    for _, key in ipairs(A.RESOURCE_USES[profession] or {}) do
        local catalog = ns.craftCatalogs[key]
        for _, recipe in ipairs(catalog and catalog.recipes or {}) do
            local per = 0
            for _, input in ipairs(recipe.inputs) do if input[1] == id then per = per + input[2] end end
            if per > 0 and not recipe.cooldown and not ns.Hidden.Is(recipe.raw) then
                local plan = ns.CraftPlan.Build(recipe, {fee = fee})
                result[#result + 1] = {recipe = recipe, profession = key, per = per,
                    gain = A.Gain(plan.margin, price and per * price, per)}
            end
        end
    end
    table.sort(result, function(a, b)
        if (a.gain == nil) ~= (b.gain == nil) then return a.gain ~= nil end
        if a.gain and a.gain ~= b.gain then return a.gain > b.gain end
        return a.recipe.raw < b.recipe.raw
    end)
    return result
end
function A.ResourceTargets(profession)
    local ids, seen = {}, {}
    local function add(id) if not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
    for _, id in ipairs(A.Resources(profession)) do
        add(id)
        local process = ns.Reagents.Process(id)
        if process then
            for _, output in ipairs(ns.Prospect.Outcomes(process.source)) do add(output.id) end
        end
        for _, use in ipairs(A.Uses(profession, id)) do
            for _, target in ipairs(A.Targets(use.recipe)) do add(target) end
        end
    end
    return ids
end
