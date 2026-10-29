local _, ns = ...
local A = {}
ns.Alchemy = A
ns.Crafting = A
ns.craftCatalogs = ns.craftCatalogs or {}
ns.craftCatalogs.alchemy = {labelKey = "alchemySection", recipes = ns.alchemyRecipes}
A.order = {"alchemy", "enchanting", "tailoring", "blacksmithing", "engineering", "leatherworking",
    "inscription", "cooking", "firstaid", "mining"}
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
    prices()[id] = copper and math.floor(copper + 0.5) or nil
    return true
end
function A.Quote(id)
    local q = ns.Markets.Quote(id)
    if ns.vendorPrices[id] then return q end
    local price = prices()[id]
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
        if ns.vendorPrices[input[1]] or prices()[input[1]] == nil then ids[#ids + 1] = input[1] end
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
function A.Complete(recipe, mode, options)
    if ns.Hidden.Is(recipe.raw) then return false end
    return ns.Batch.Complete(A.RecipeSources(recipe, options), mode, true)
end
function A.Epochs(profession)
    A.epochs[profession] = A.epochs[profession] or {wrath = true, bc = false, classic = false}
    return A.epochs[profession]
end
function A.SetEpoch(profession, expansion, shown)
    A.Epochs(profession)[expansion] = shown and true or false
end
function A.Shown(recipe)
    return A.Epochs(recipe.profession)[recipe.expansion or "wrath"] or recipe.sellable == true
end
function A.EpochCounts(profession)
    local counts = {}
    for _, recipe in ipairs(ns.craftCatalogs[profession].recipes) do
        local expansion = recipe.expansion or "wrath"
        counts[expansion] = (counts[expansion] or 0) + 1
        if recipe.sellable then counts.sellable = (counts.sellable or 0) + 1 end
    end
    return counts
end
function A.Alternatives(recipe)
    local result = {}
    for _, other in ipairs(A.makers[recipe.raw] or {}) do
        if other ~= recipe then result[#result + 1] = other end
    end
    return result
end
function A.Recipes(profession, learnedOnly, hidden)
    local catalog, result = ns.craftCatalogs[profession], {}
    for _, recipe in ipairs(ns.Hidden.Filter(catalog.recipes, hidden == true)) do
        if A.Shown(recipe) and (not learnedOnly or ns.Recipes.Known(recipe.spell, ns.T(catalog.labelKey)) == true) then
            result[#result + 1] = recipe
        end
    end
    return result
end
function A.ProfessionSources(profession, learnedOnly)
    local ids = {}
    for _, recipe in ipairs(A.Recipes(profession, learnedOnly)) do
        if not ns.Hidden.IsGroup(profession .. ":" .. recipe.category) then
            for _, id in ipairs(A.Targets(recipe)) do ids[#ids + 1] = id end
        end
    end
    return ids
end
function A.CompleteProfession(profession, mode, learnedOnly)
    return ns.Batch.Complete(A.ProfessionSources(profession, learnedOnly), mode, true)
end
function A.ResourceExpansion(profession, id)
    local process = ns.Reagents.Process(id)
    if process and process.source.expansion then return process.source.expansion end
    return ns.gatheringCatalogs[profession].expansion or "wrath"
end
function A.Resources(profession, all)
    local ids, epochs = {}, A.Epochs(profession)
    for _, id in ipairs(ns.Reagents.Resources(profession)) do
        if all or epochs[A.ResourceExpansion(profession, id)] then ids[#ids + 1] = id end
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
function A.ResourceTargets(profession)
    local ids = {}
    for _, id in ipairs(A.Resources(profession)) do
        ids[#ids + 1] = id
        local process = ns.Reagents.Process(id)
        if process then
            for _, output in ipairs(ns.Prospect.Outcomes(process.source)) do ids[#ids + 1] = output.id end
        end
    end
    return ids
end
