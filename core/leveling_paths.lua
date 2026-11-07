local _, ns = ...
local P = {SIMPLE = 1000000, LAYERS = 60, LIQUID = 3, RATE_MAX = 10}
ns.LevelingPaths = P
function P.Chance(recipe, skill)
    if skill >= recipe.gray then return 0 end
    if skill < recipe.yellow then return 1 end
    return (recipe.gray - skill) / (recipe.gray - recipe.yellow)
end
function P.Color(recipe, skill)
    if skill >= recipe.gray then return "gray" end
    if skill < recipe.yellow then return "orange" end
    return skill < math.floor((recipe.yellow + recipe.gray) / 2) and "yellow" or "green"
end
function P.Options(options)
    options = options or {}
    local first = math.max(1, math.min(449, math.floor(tonumber(options.first) or 1)))
    local target = math.max(first + 1, math.min(450, math.floor(tonumber(options.target) or 450)))
    return {profession = options.profession or "tailoring", first = first, target = target,
        known = options.known or function() return nil end, faction = options.faction,
        rodTier = options.rodTier or 0, tolerance = options.tolerance or P.SIMPLE, blind = options.blind,
        rate = P.Rate(options.rate), resale = options.resale and true or false}
end
function P.Rate(rate)
    rate = math.floor(tonumber(rate) or 1)
    return math.max(1, math.min(P.RATE_MAX, rate))
end
local function quoted(id)
    local q = ns.Markets.Quote(id)
    if q and q.price and q.complete ~= false and (q.miss or 0) == 0 then return q.price end
end
local function context(catalog, options)
    local ctx = {catalog = catalog, options = options, prices = {}, missing = {}, byOutput = {}}
    for _, recipe in ipairs(catalog.recipes) do
        if recipe.output and (recipe.source == "trainer" or options.known(recipe.spell)) then
            local list = ctx.byOutput[recipe.output] or {}
            list[#list + 1] = recipe
            ctx.byOutput[recipe.output] = list
        end
    end
    return ctx
end
local function unitPrice(id, ctx, depth)
    depth = depth or 0
    if ctx.options.blind then return 1 end
    if ctx.prices[id] ~= nil and depth == 0 then return ctx.prices[id] or nil end
    local best = quoted(id)
    if depth < 2 then
        for _, recipe in ipairs(ctx.byOutput[id] or {}) do
            local total = 0
            for _, input in ipairs(recipe.inputs) do
                local price = unitPrice(input[1], ctx, depth + 1)
                if not price then total = nil; break end
                total = total + price * input[2]
            end
            if total and (not best or total / recipe.count < best) then best = total / recipe.count end
        end
    end
    if depth == 0 then
        ctx.prices[id] = best or false
        if not best then ctx.missing[id] = true end
    end
    return best
end
function P.Resale(recipe)
    if not recipe.resale then return 0 end
    local q = ns.Markets.Quote(recipe.output)
    if not q or q.vendor or not q.price or q.complete == false or (q.miss or 0) > 0 or (q.lots or 0) < P.LIQUID then return 0 end
    return math.floor(q.price * (recipe.count or 1) * (1 - ns.Fee()))
end
function P.Acquire(recipe, ctx)
    local options = ctx.options
    if options.known(recipe.spell) then return 0, 1, nil end
    if recipe.special then return nil, 0 end
    if recipe.faction and options.faction and recipe.faction ~= options.faction then return nil, 0 end
    if recipe.source == "trainer" then return recipe.cost or 0, 1, nil end
    if recipe.source == "vendor" then return recipe.cost or 0, 2, "vendor" end
    if recipe.source == "token" then return 0, 2, "token" end
    if recipe.source == "auction" and recipe.item then
        if options.blind then return 0, 2, "auction" end
        local price = quoted(recipe.item)
        if price then return price, 2, "auction" end
        ctx.missing[recipe.item] = true
    end
    return nil, 0
end
local function candidates(ctx)
    local out, options = {}, ctx.options
    for _, recipe in ipairs(ctx.catalog.recipes) do
        if recipe.req < options.target and recipe.gray > options.first then
            local acquire, weight, buy = P.Acquire(recipe, ctx)
            if acquire then
                local materials = 0
                for _, input in ipairs(recipe.inputs) do
                    local price = unitPrice(input[1], ctx)
                    if not price then materials = nil; break end
                    materials = materials + price * input[2]
                end
                if materials then
                    local resale = (options.blind or not options.resale) and 0 or P.Resale(recipe)
                    out[#out + 1] = {recipe = recipe, acquire = acquire, weight = weight, buy = buy,
                        materials = materials, resale = resale, craft = math.max(0, materials - resale)}
                end
            end
        end
    end
    return out
end
local function prefix(recipe, from, to, rate)
    local out, total = {[from] = 0}, 0
    for skill = from, to - 1 do
        total = total + 1 / (P.Chance(recipe, skill) * rate)
        out[skill + 1] = total
    end
    return out
end
local function layers(ctx, list)
    local options = ctx.options
    local first, target, inf = options.first, options.target, math.huge
    local best, parent = {}, {}
    best[0] = {[first] = 0}
    for _, c in ipairs(list) do
        c.from = math.max(first, c.recipe.req)
        c.to = math.min(target, c.recipe.gray)
        c.sums = c.from < c.to and prefix(c.recipe, c.from, c.to, options.rate) or nil
    end
    for k = 1, P.LAYERS do
        local row, from = {}, {}
        for s, value in pairs(best[k - 1]) do row[s] = value; from[s] = parent[k - 1] and parent[k - 1][s] end
        for _, c in ipairs(list) do
            local base = c.sums and best[k - c.weight]
            if base then
                local running, at = inf, nil
                for b = c.from + 1, c.to do
                    local a = b - 1
                    local start = base[a]
                    if start then
                        local value = start - c.craft * c.sums[a]
                        if value < running then running, at = value, a end
                    end
                    if at then
                        local cost = running + c.craft * c.sums[b] + c.acquire
                        if not row[b] or cost < row[b] - 0.5 then
                            row[b] = cost
                            from[b] = {c = c, a = at, k = k - c.weight}
                        end
                    end
                end
            end
        end
        best[k], parent[k] = row, from
    end
    return best, parent
end
local function unwind(ctx, parent, k, skill)
    local segments = {}
    while k > 0 and parent[k] and parent[k][skill] do
        local step = parent[k][skill]
        local c, a = step.c, step.a
        local crafts = c.sums[skill] - c.sums[a]
        local inputs = {}
        for _, input in ipairs(c.recipe.inputs) do inputs[input[1]] = input[2] * crafts end
        table.insert(segments, 1, {recipe = c.recipe, first = a, target = skill, crafts = crafts,
            materials = c.materials * crafts, resale = c.resale * crafts, cost = c.craft * crafts,
            acquire = c.acquire, buy = c.buy, inputs = inputs, rate = ctx.options.rate})
        k, skill = step.k, a
    end
    local merged = {}
    for _, s in ipairs(segments) do
        local last = merged[#merged]
        if last and last.recipe == s.recipe and last.target == s.first then
            last.target, last.crafts = s.target, last.crafts + s.crafts
            last.materials, last.resale, last.cost = last.materials + s.materials, last.resale + s.resale, last.cost + s.cost
            for id, count in pairs(s.inputs) do last.inputs[id] = (last.inputs[id] or 0) + count end
        else merged[#merged + 1] = s end
    end
    local path = {segments = merged, cost = 0, materials = 0, resale = 0, acquire = 0, crafts = 0, complexity = 0,
        reached = merged[#merged] and merged[#merged].target or ctx.options.first, rods = {}}
    for _, s in ipairs(merged) do
        path.cost = path.cost + s.cost + s.acquire
        path.materials, path.resale = path.materials + s.materials, path.resale + s.resale
        path.acquire, path.crafts = path.acquire + s.acquire, path.crafts + s.crafts
        path.complexity = path.complexity + (s.buy and 2 or 1)
    end
    return path
end
local function rods(path, ctx)
    local tools = ns.levelingRods
    if ctx.options.profession ~= "enchanting" or not tools then return end
    local need = ctx.options.rodTier
    for _, s in ipairs(path.segments) do need = math.max(need, s.recipe.tool or 0) end
    local bySpell = {}
    for _, recipe in ipairs(ctx.catalog.recipes) do bySpell[recipe.spell] = recipe end
    for tier = ctx.options.rodTier + 1, need do
        local tool, cost = tools[tier], 0
        local recipe = bySpell[tool.spell]
        for _, input in ipairs(recipe and recipe.inputs or {}) do
            if tier == 1 or input[1] ~= tools[tier - 1].item then
                local price = unitPrice(input[1], ctx)
                cost = price and cost + price * input[2] or nil
                if not cost then break end
            end
        end
        path.rods[#path.rods + 1] = {spell = tool.spell, item = tool.item, cost = cost, tier = tier}
        if cost then path.cost = path.cost + cost end
    end
end
function P.Plan(options)
    local p = P.Options(options)
    local catalog = ns.levelingPaths and ns.levelingPaths[p.profession]
    local plan = {options = p, reached = p.first, missing = {}, candidates = 0}
    if not catalog then return plan end
    local ctx = context(catalog, p)
    local list = candidates(ctx)
    plan.candidates = #list
    local best, parent = layers(ctx, list)
    local top = best[P.LAYERS]
    for skill in pairs(top) do if skill > plan.reached then plan.reached = skill end end
    for id in pairs(ctx.missing) do plan.missing[#plan.missing + 1] = id end
    table.sort(plan.missing)
    local goal = top[p.target] and p.target or plan.reached
    if goal <= p.first then return plan end
    local cheapest, cheapK = top[goal], P.LAYERS
    for k = 1, P.LAYERS do
        if best[k][goal] and best[k][goal] <= cheapest + 0.5 then cheapK = k; break end
    end
    plan.cheap = unwind(ctx, parent, cheapK, goal)
    for k = 1, cheapK - 1 do
        if best[k][goal] and best[k][goal] <= cheapest + p.tolerance then
            plan.simple = unwind(ctx, parent, k, goal)
            break
        end
    end
    if p.blind then
        plan.simple, plan.missing = nil, {}
        plan.cheap.blind, plan.cheap.cost, plan.cheap.materials, plan.cheap.resale = true, nil, 0, 0
        for _, s in ipairs(plan.cheap.segments) do s.blind, s.cost, s.materials, s.resale = true, nil, 0, 0 end
        return plan
    end
    rods(plan.cheap, ctx)
    if plan.simple then rods(plan.simple, ctx) end
    return plan
end
function P.Shopping(path)
    local out = {}
    for _, s in ipairs(path.segments) do
        for id, count in pairs(s.inputs) do out[id] = (out[id] or 0) + count end
        if s.buy == "auction" and s.recipe.item then out[s.recipe.item] = (out[s.recipe.item] or 0) + 1 end
    end
    for id, count in pairs(out) do out[id] = math.ceil(count - 0.0000001) end
    return out
end
function P.Need(segment, skill)
    local from = math.max(segment.first, skill or segment.first)
    local crafts = segment.crafts
    if from > segment.first then
        crafts = 0
        for s = from, segment.target - 1 do
            local chance = P.Chance(segment.recipe, s)
            if chance > 0 then crafts = crafts + 1 / (chance * (segment.rate or 1)) end
        end
    end
    local out = {}
    if crafts <= 0 then return out, 0 end
    for _, input in ipairs(segment.recipe.inputs) do
        out[input[1]] = (out[input[1]] or 0) + math.ceil(input[2] * crafts - 0.0000001)
    end
    return out, crafts
end
function P.Targets(options)
    local p = P.Options(options)
    local catalog = ns.levelingPaths and ns.levelingPaths[p.profession]
    local ids, seen = {}, {}
    local function add(id)
        if id and not seen[id] and not (ns.vendorPrices and ns.vendorPrices[id]) then seen[id] = true; ids[#ids + 1] = id end
    end
    for _, recipe in ipairs(catalog and catalog.recipes or {}) do
        if recipe.req < p.target and recipe.gray > p.first and not recipe.special
            and (recipe.source ~= "other" or p.known(recipe.spell)) then
            for _, input in ipairs(recipe.inputs) do add(input[1]) end
            if recipe.source == "auction" and not p.known(recipe.spell) then add(recipe.item) end
            if recipe.resale and p.resale then add(recipe.output) end
        end
    end
    table.sort(ids)
    return ids
end
