local _, ns = ...
local P = {}
ns.CraftPlan = P
local function sum(left, right)
    if left == nil or right == nil then return nil end
    return left + right
end
function P.Build(recipe, options)
    local stock, path, rows = {}, {[recipe.raw] = true}, {}
    local quantity = math.max(1, math.min(100000, math.floor(options.quantity or recipe.count)))
    local crafts = math.ceil(quantity / recipe.count)
    local function loops(child)
        if not child then return false end
        for _, input in ipairs(child.inputs) do
            if path[input[1]] then return true end
        end
        return false
    end
    local function material(id, quantity, depth)
        local quote = ns.Crafting.Quote(id)
        local price = quote and quote.miss == 0 and quote.complete ~= false
            and (not quote.at or quote.at <= time()) and quote.price or nil
        local O = ns.Obtain
        local key = options.choice and options.choice[id]
        if key == nil and options.auto and O then key = O.BestKey(id) end
        local edge = key and key ~= "buy" and O and O.Edge(id, key) or nil
        local child = edge and {count = O.Output(edge), inputs = edge.inputs} or ns.Crafting.byItem[id]
        local make
        if edge then make = true
        elseif key == "buy" then make = false
        else
            make = options.make and options.make[id]
            if make == nil then make = options.craftAll end
        end
        local expandable = child ~= nil and not path[id] and not loops(child) and depth < 8
        local crafted = make and expandable or false
        local node = {id = id, count = quantity, depth = depth, quote = quote, expandable = expandable,
            crafted = crafted, own = 0, need = quantity, children = {}, ways = O and O.Ways(id) or 0,
            chosen = options.choice ~= nil and options.choice[id] ~= nil}
        if O then
            local made = not edge and crafted and ns.Crafting.byItem[id]
            node.edge = edge or made and O.RecipeEdge(made) or O.BuyEdge(id)
        end
        rows[#rows + 1] = node
        if options.ignore and options.ignore[id] then
            node.excluded, node.crafted, node.own, node.need, node.value, node.cash = true, false, quantity, 0, 0, 0
            return node
        end
        if options.owned and not ns.vendorPrices[id] then
            local pool = stock[id]
            if pool == nil then
                local here, alts = ns.Inventory.Stock(id)
                pool = {here = here, alts = alts}
                stock[id] = pool
            end
            local mine = math.min(quantity, pool.here)
            local theirs = math.min(quantity - mine, pool.alts)
            pool.here, pool.alts = pool.here - mine, pool.alts - theirs
            node.own, node.ownAlts = mine + theirs, theirs
            node.need = quantity - node.own
        end
        node.value = node.own == 0 and 0 or (price and node.own * price)
        node.cash = 0
        if node.crafted and node.need > 0 then
            path[id] = true
            node.crafts = math.ceil(node.need / child.count - 0.000001)
            node.extra = math.floor(node.crafts * child.count - node.need + 0.5)
            for _, input in ipairs(child.inputs) do
                local part = material(input[1], input[2] * node.crafts, depth + 1)
                node.children[#node.children + 1] = part
                node.value, node.cash = sum(node.value, part.value), sum(node.cash, part.cash)
            end
            path[id] = nil
        elseif node.need > 0 then
            node.cash = price and node.need * price
            node.value = sum(node.value, node.cash)
        end
        return node
    end
    local result = {rows = rows, cost = 0, cash = 0, count = recipe.count * crafts,
        requested = quantity, crafts = crafts, extra = math.floor(recipe.count * crafts - quantity + 0.5),
        missing = 0, stale = 0, short = 0, chosen = 0, needs = {}}
    for _, input in ipairs(recipe.inputs) do
        local node = material(input[1], input[2] * crafts, 0)
        result.cost, result.cash = sum(result.cost, node.value), sum(result.cash, node.cash)
    end
    local quotes = {}
    for _, node in ipairs(rows) do
        if not node.excluded then
            if node.chosen then result.chosen = result.chosen + 1 end
            if not node.crafted then result.needs[node.id] = (result.needs[node.id] or 0) + node.need end
            if not node.crafted or node.own > 0 then quotes[node.id] = node.quote or false end
        end
    end
    for id, quote in pairs(quotes) do
        if not quote or not quote.price or quote.miss ~= 0 or quote.complete == false or quote.at and quote.at > time() then
            result.missing = result.missing + 1
        elseif not quote.vendor and not quote.manual then
            if not ns.Markets.Fresh(id) then result.stale = result.stale + 1 end
            if (result.needs[id] or 0) > (quote.units or 0) then result.short = result.short + 1 end
        end
    end
    result.unitCost = result.cost and result.cost / result.count
    local output = ns.Markets.Quote(recipe.raw)
    if recipe.slots then
        local expected = ns.Crafting.Expected(recipe, options.fee or 0.05)
        result.revenue = expected and expected * crafts
    elseif output and output.price and output.miss == 0 and output.complete ~= false and (not output.at or output.at <= time()) then
        result.market = output.price * result.count
        result.revenue = result.market * (1 - (options.fee or 0.05))
    end
    result.sale = result.revenue
    local disenchant = not recipe.slots and P.Disenchant(recipe.raw, options.fee or 0.05)
    if disenchant then
        result.disenchant = disenchant.net * result.count
        if not result.sale or result.disenchant > result.sale then result.revenue, result.via = result.disenchant, "disenchant" end
    end
    if result.revenue and result.cost then result.margin = result.revenue - result.cost end
    return result
end
function P.Disenchant(id, fee)
    local D = ns.Disenchant
    if not D or not D.Candidate then return nil end
    local candidate = D.Candidate(id)
    local band = candidate and D.Band(candidate.band)
    if not band then return nil end
    local estimate = D.Estimate(band, 0, fee)
    if not estimate.net then return nil end
    return {net = estimate.net, band = band, outputs = estimate.outputs}
end
function P.DisenchantTargets(id)
    local D = ns.Disenchant
    local candidate = D and D.Candidate and D.Candidate(id)
    local band = candidate and D.Band(candidate.band)
    local ids = {}
    for _, output in ipairs(band and band.outputs or {}) do ids[#ids + 1] = output.itemID end
    return ids
end
function P.Stock(recipe)
    local crafts
    for _, input in ipairs(recipe.inputs) do
        local enough = math.floor(math.max(0, GetItemCount(input[1], true) or 0) / input[2])
        crafts = math.min(crafts or enough, enough)
    end
    return crafts or 0
end
local planCache = {}
local PLAN_KEYS = 4
local function signature(options)
    local O, M, I = ns.Obtain, ns.Markets, ns.Inventory
    if O then O.Hook() end
    return table.concat({O and O.serial or 0, M and M.version or 0, options.fee or 0.05,
        options.owned and (I and I.version or 0) or "-", math.floor(time() / 60)}, ":")
end
function P.Plans(recipes, options)
    local key = signature(options)
    local plans = planCache[key]
    if not plans then
        local kept = 0
        for _ in pairs(planCache) do kept = kept + 1 end
        if kept >= PLAN_KEYS then planCache = {} end
        plans = setmetatable({}, {__mode = "k"})
        planCache[key] = plans
    end
    for _, recipe in ipairs(recipes) do
        if not plans[recipe] and not (ns.Hidden and ns.Hidden.Is(recipe.raw)) then plans[recipe] = P.Build(recipe, options) end
    end
    return plans
end
function P.Plan(recipe, options)
    return P.Plans({recipe}, options)[recipe] or P.Build(recipe, options)
end
function P.Rank(recipes, options)
    local plans, ranked = P.Plans(recipes, options), {}
    for _, recipe in ipairs(recipes) do
        if not (ns.Hidden and ns.Hidden.Is(recipe.raw)) then
            ranked[#ranked + 1] = {raw = recipe.raw, recipe = recipe, plan = plans[recipe]}
        end
    end
    local names = {}
    local function name(raw)
        names[raw] = names[raw] or ns.Markets.Name(raw)
        return names[raw]
    end
    table.sort(ranked, function(a, b)
        local left, right = a.plan.margin, b.plan.margin
        if left == right then return name(a.raw) < name(b.raw) end
        if left == nil then return false end
        if right == nil then return true end
        return left > right
    end)
    return ranked
end
function P.Targets(recipe, options)
    local ids, seen = recipe.slots and ns.Prospect.RecipeTargets(recipe) or {recipe.raw}, {}
    if not recipe.slots then
        for _, id in ipairs(P.DisenchantTargets(recipe.raw)) do ids[#ids + 1] = id end
    end
    for _, id in ipairs(ids) do seen[id] = true end
    if options then
        for _, row in ipairs(P.Build(recipe, options).rows) do
            local quote = ns.Crafting.Quote(row.id)
            if not row.excluded and not seen[row.id] and not (quote and quote.manual) then
                seen[row.id] = true
                ids[#ids + 1] = row.id
            end
        end
        return ids
    end
    local function visit(current, depth)
        if depth > 8 then return end
        for _, input in ipairs(current.inputs) do
            local id = input[1]
            if not seen[id] then
                seen[id] = true
                local quote = ns.Crafting.Quote(id)
                if ns.vendorPrices[id] or not (quote and quote.manual) then ids[#ids + 1] = id end
                if ns.Crafting.byItem[id] then visit(ns.Crafting.byItem[id], depth + 1) end
            end
        end
    end
    visit(recipe, 0)
    return ids
end
