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
        rate = P.Rate(options.rate), resale = options.resale and true or false, owned = options.owned}
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
    local ctx = {catalog = catalog, options = options, prices = {}, missing = {}, byOutput = {}, quotes = {}, stock = {},
        priceSkill = {}}
    local inputs, thresholds = {}, {}
    for _, recipe in ipairs(catalog.recipes) do
        for _, input in ipairs(recipe.inputs) do inputs[input[1]] = true end
    end
    for _, recipe in ipairs(catalog.recipes) do
        if inputs[recipe.output] and (recipe.count or 0) > 0 and not recipe.tool
            and (options.known(recipe.spell) or (recipe.source == "trainer"
            and not recipe.special and (not recipe.faction or not options.faction or recipe.faction == options.faction))) then
            local list = ctx.byOutput[recipe.output] or {}
            list[#list + 1] = recipe
            ctx.byOutput[recipe.output] = list
            thresholds[recipe.req] = true
        end
    end
    local threshold = options.first
    for skill = options.first, options.target do
        if thresholds[skill] then threshold = skill end
        ctx.priceSkill[skill] = threshold
    end
    return ctx
end
local function quote(ctx, id)
    if ctx.quotes[id] == nil then ctx.quotes[id] = quoted(id) or false end
    return ctx.quotes[id] or nil
end
local function owned(ctx, id)
    if ctx.stock[id] == nil then
        ctx.stock[id] = ctx.options.owned and math.max(0, ctx.options.owned(id) or 0) or 0
        if ctx.stock[id] > 0 then ctx.hasStock = true end
    end
    return ctx.stock[id]
end
local function unitPrice(id, ctx, skill, depth)
    depth = depth or 0
    if ctx.options.blind then return 1 end
    if ctx.options.owned and owned(ctx, id) > 0 and ctx.useStock then return 0 end
    local bucket = ctx.priceSkill[skill] or skill
    local prices = ctx.prices[bucket]
    if not prices then prices = {}; ctx.prices[bucket] = prices end
    if prices[id] ~= nil and depth == 0 then return prices[id] or nil end
    local best = quote(ctx, id)
    if depth < 2 then
        for _, recipe in ipairs(ctx.byOutput[id] or {}) do
            if recipe.req <= skill then
                local total = 0
                for _, input in ipairs(recipe.inputs) do
                    local price = unitPrice(input[1], ctx, skill, depth + 1)
                    if not price then total = nil; break end
                    total = total + price * input[2]
                end
                if total and (not best or total / recipe.count < best) then best = total / recipe.count end
            end
        end
    end
    if depth == 0 then prices[id] = best or false end
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
                local resale = (options.blind or not options.resale) and 0 or P.Resale(recipe)
                out[#out + 1] = {recipe = recipe, acquire = acquire, weight = weight, buy = buy, resale = resale}
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
        c.costs, c.unpriced = {[c.from] = 0}, {}
        local priced, materials, lastBucket = false, nil, nil
        for skill = c.from, c.to - 1 do
            local bucket = ctx.priceSkill[skill]
            if bucket ~= lastBucket then
                lastBucket, materials = bucket, 0
                for _, input in ipairs(c.recipe.inputs) do
                    local price = unitPrice(input[1], ctx, skill)
                    if not price then ctx.missing[input[1]] = true; materials = nil; break end
                    materials = materials + price * input[2]
                end
            end
            c.unpriced[skill] = not materials or nil
            if materials then priced = true end
            c.costs[skill + 1] = c.costs[skill] + (materials and math.max(0, materials - c.resale)
                * (c.sums[skill + 1] - c.sums[skill]) or 0)
        end
        if not priced then c.sums = nil end
    end
    local settled = 0
    for k = 1, P.LAYERS do
        local row, from, changed = {}, {}, false
        for s, value in pairs(best[k - 1]) do row[s] = value; from[s] = parent[k - 1] and parent[k - 1][s] end
        for _, c in ipairs(list) do
            local base = c.sums and best[k - c.weight]
            if base then
                local running, at = inf, nil
                for b = c.from + 1, c.to do
                    local a = b - 1
                    if c.unpriced[a] then
                        running, at = inf, nil
                    else
                        local start = base[a]
                        if start then
                            local value = start - c.costs[a]
                            if value < running then running, at = value, a end
                        end
                        if at then
                            local cost = running + c.costs[b] + c.acquire
                            if not row[b] or cost < row[b] - 0.5 then
                                row[b] = cost
                                from[b] = {c = c, a = at, k = k - c.weight}
                                changed = true
                            end
                        end
                    end
                end
            end
        end
        best[k], parent[k] = row, from
        settled = changed and 0 or settled + 1
        if settled >= 2 then
            for rest = k + 1, P.LAYERS do best[rest], parent[rest] = row, from end
            break
        end
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
            resaleUnit = c.resale, acquire = c.acquire, buy = c.buy, inputs = inputs, rate = ctx.options.rate})
        k, skill = step.k, a
    end
    local merged = {}
    for _, s in ipairs(segments) do
        local last = merged[#merged]
        if last and last.recipe == s.recipe and last.target == s.first then
            last.target, last.crafts = s.target, last.crafts + s.crafts
            for id, count in pairs(s.inputs) do last.inputs[id] = (last.inputs[id] or 0) + count end
        else merged[#merged + 1] = s end
    end
    return merged
end
local function copy(values)
    local result = {}
    for key, value in pairs(values) do result[key] = value end
    return result
end
local function copyState(state)
    return {stock = copy(state.stock), learned = copy(state.learned), shopping = copy(state.shopping),
        prep = copy(state.prep), cash = state.cash, training = state.training}
end
local function stock(ctx, state, id)
    local count = state.stock[id]
    if count == nil then return owned(ctx, id) end
    return count
end
local function supply(ctx, state, id, count, skill, depth, visiting)
    local available = stock(ctx, state, id)
    local used = math.min(count, available)
    state.stock[id], count = available - used, count - used
    if count == 0 then return state end
    local price = ctx.options.blind and 0 or quote(ctx, id)
    local best, cost = nil, price and price * count or math.huge
    if depth < 2 and not ctx.options.blind and not visiting[id] then
        visiting[id] = true
        for _, recipe in ipairs(ctx.byOutput[id] or {}) do
            if recipe.req <= skill then
                local craft = copyState(state)
                local times = math.ceil(count / recipe.count)
                if not craft.learned[recipe.spell] and not ctx.options.known(recipe.spell) then
                    craft.training = craft.training + (recipe.cost or 0)
                    craft.learned[recipe.spell] = true
                end
                for _, input in ipairs(recipe.inputs) do
                    craft = supply(ctx, craft, input[1], times * input[2], skill, depth + 1, visiting)
                    if not craft then break end
                end
                if craft then
                    local extra = craft.cash - state.cash + craft.training - state.training
                    if extra < cost then
                        craft.stock[id] = times * recipe.count - count
                        craft.prep[#craft.prep + 1] = {recipe = recipe, crafts = times}
                        best, cost = craft, extra
                    end
                end
            end
        end
        visiting[id] = nil
    end
    if best then return best end
    if not price then return nil end
    state.cash = state.cash + price * count
    state.shopping[id] = (state.shopping[id] or 0) + count
    return state
end
local function stretch(segment, first, target)
    local result = copy(segment)
    result.first, result.target = first, target
    result.crafts = prefix(segment.recipe, first, target, segment.rate)[target]
    result.inputs = {}
    for _, input in ipairs(segment.recipe.inputs) do result.inputs[input[1]] = result.crafts * input[2] end
    return result
end
local function whole(crafts)
    return math.ceil(crafts - 0.0000001)
end
local function advance(ctx, previous, segment)
    local state = {stock = copy(previous.stock), learned = copy(previous.learned), shopping = {}, prep = {},
        cash = 0, training = 0}
    local r, crafts = segment.recipe, whole(segment.crafts)
    local visiting = {}
    if r.output then visiting[r.output] = true end
    for _, input in ipairs(r.inputs) do
        state = supply(ctx, state, input[1], crafts * input[2], segment.first, 0, visiting)
        if not state then return nil end
    end
    if r.output then state.stock[r.output] = stock(ctx, state, r.output) + crafts * (r.count or 1) end
    state.acquire = state.learned[r.spell] and 0 or segment.acquire
    state.learned[r.spell] = true
    return state
end
local function simulate(ctx, segments, stop)
    local path = {segments = {}, cost = 0, materials = 0, resale = 0, acquire = 0, crafts = 0, actions = 0, complexity = 0,
        reached = ctx.options.first, rods = {}}
    local previous = {stock = {}, learned = {}}
    for _, original in ipairs(segments) do
        local segment = copy(original)
        local state = advance(ctx, previous, segment)
        if not state then
            if not stop then return nil end
            local lo, hi = segment.first, segment.target
            while hi - lo > 1 do
                local mid = math.floor((lo + hi) / 2)
                local part = stretch(original, original.first, mid)
                local partial = advance(ctx, previous, part)
                if partial then lo, segment, state = mid, part, partial else hi = mid end
            end
            if not state then break end
        end
        segment.shopping, segment.prep = state.shopping, state.prep
        segment.materials, segment.resale = state.cash, segment.resaleUnit * whole(segment.crafts)
        segment.cost = math.max(0, segment.materials - segment.resale)
        if previous.learned[segment.recipe.spell] then segment.buy = nil end
        segment.acquire = state.acquire
        path.segments[#path.segments + 1] = segment
        path.cost = path.cost + segment.cost + state.acquire + state.training
        path.materials, path.resale = path.materials + segment.materials, path.resale + segment.resale
        path.acquire, path.crafts = path.acquire + state.acquire + state.training, path.crafts + segment.crafts
        path.actions = path.actions + whole(segment.crafts)
        for _, step in ipairs(segment.prep) do
            path.crafts, path.actions = path.crafts + step.crafts, path.actions + step.crafts
        end
        path.complexity = path.complexity + (segment.buy and 2 or 1) + #segment.prep
        path.reached, previous = segment.target, state
        if segment.target < original.target then break end
    end
    if #path.segments == 0 then return nil end
    path.remainingStock = previous.stock
    return path
end
local function better(path, current)
    if not path then return false end
    if not current then return true end
    if path.reached ~= current.reached then return path.reached > current.reached end
    if path.cost ~= current.cost then return path.cost < current.cost end
    if path.complexity ~= current.complexity then return path.complexity < current.complexity end
    return path.actions < current.actions
end
local function refine(ctx, segments, path)
    if not path or ctx.options.blind or #segments < 2 then return path end
    local used = {}
    for i = #segments - 1, 1, -1 do
        local a, b = segments[i], segments[i + 1]
        for _, input in ipairs(b.recipe.inputs) do used[input[1]] = true end
        if used[a.recipe.output] or used[b.recipe.output] then
            local lo = math.max(a.first + 1, b.recipe.req)
            local hi = math.min(b.target - 1, a.recipe.gray)
            local bestA, bestB = a, b
            for at = lo, hi do
                if at ~= a.target then
                    segments[i], segments[i + 1] = stretch(a, a.first, at), stretch(b, at, b.target)
                    local alternative = simulate(ctx, segments)
                    if better(alternative, path) then
                        path, bestA, bestB = alternative, segments[i], segments[i + 1]
                    end
                end
            end
            segments[i], segments[i + 1] = bestA, bestB
        end
    end
    return path
end
local function promotePreparation(ctx, segments, path)
    if not path or ctx.options.blind or path.reached ~= segments[#segments].target then return path end
    local best, route = path, nil
    for i, segment in ipairs(path.segments) do
        local seen = {}
        for _, step in ipairs(segment.prep) do
            local recipe = step.recipe
            local previous = segments[i - 1]
            if not seen[recipe] and (not previous or previous.recipe ~= recipe) then
                seen[recipe] = true
                local acquire = P.Acquire(recipe, ctx)
                local new = {recipe = recipe, rate = segment.rate, resaleUnit = 0, acquire = acquire}
                local candidate = copy(segments)
                table.insert(candidate, i, new)
                for at = segment.first + 1, math.min(recipe.gray, segment.target - 1) do
                    candidate[i] = stretch(new, segment.first, at)
                    candidate[i + 1] = stretch(segments[i], at, segment.target)
                    local alternative = simulate(ctx, candidate)
                    if better(alternative, best) then best, route = alternative, copy(candidate) end
                end
            end
        end
    end
    return route and refine(ctx, route, best) or best
end
local function evaluate(ctx, segments)
    local path = refine(ctx, segments, simulate(ctx, segments, true))
    return promotePreparation(ctx, segments, path)
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
                local price = unitPrice(input[1], ctx, math.max(ctx.options.first, recipe.req))
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
    local paths = {}
    local runs = p.owned and not p.blind and 2 or 1
    for run = 1, runs do
        ctx.useStock, ctx.prices = run == 2, {}
        local best, parent = layers(ctx, list)
        local top, goal = best[P.LAYERS], p.first
        for skill in pairs(top) do if skill > goal then goal = skill end end
        if goal > p.first then
            local cheapest, cheapK = top[goal], P.LAYERS
            for k = 1, P.LAYERS do
                if best[k][goal] and best[k][goal] <= cheapest + 0.5 then cheapK = k; break end
            end
            local segments = unwind(ctx, parent, cheapK, goal)
            paths[#paths + 1] = evaluate(ctx, segments)
            if not p.blind then
                for k = 1, cheapK - 1 do
                    if best[k][goal] and best[k][goal] <= cheapest + p.tolerance then
                        segments = unwind(ctx, parent, k, goal)
                        paths[#paths + 1] = evaluate(ctx, segments)
                        break
                    end
                end
            end
        end
        if not ctx.hasStock then break end
    end
    for _, candidate in ipairs(list) do if candidate.sums then plan.candidates = plan.candidates + 1 end end
    for id in pairs(ctx.missing) do plan.missing[#plan.missing + 1] = id end
    table.sort(plan.missing)
    ctx.useStock, ctx.prices = false, {}
    for _, path in ipairs(paths) do
        if not p.blind then rods(path, ctx) end
        if better(path, plan.cheap) then
            plan.cheap, plan.reached = path, path.reached
        end
    end
    if not plan.cheap then return plan end
    for _, path in ipairs(paths) do
        if path.reached == plan.reached and path.complexity < plan.cheap.complexity
            and path.cost <= plan.cheap.cost + p.tolerance and (not plan.simple or path.complexity < plan.simple.complexity
            or (path.complexity == plan.simple.complexity and path.cost < plan.simple.cost)) then
            plan.simple = path
        end
    end
    if p.blind then
        plan.simple, plan.missing = nil, {}
        plan.cheap.blind, plan.cheap.cost, plan.cheap.materials, plan.cheap.resale = true, nil, 0, 0
        for _, s in ipairs(plan.cheap.segments) do s.blind, s.cost, s.materials, s.resale = true, nil, 0, 0 end
        return plan
    end
    return plan
end
function P.Shopping(path, rank, reagentsOnly)
    local out = {}
    for _, s in ipairs(path.segments) do
        if not rank or s.target > rank then
            for id, count in pairs(s.shopping or {}) do out[id] = (out[id] or 0) + count end
            if not reagentsOnly and s.buy == "auction" and s.recipe.item then
                out[s.recipe.item] = (out[s.recipe.item] or 0) + 1
            end
        end
    end
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
        out[input[1]] = (out[input[1]] or 0) + input[2] * whole(crafts)
    end
    return out, crafts
end
function P.Targets(options)
    local p = P.Options(options)
    local catalog = ns.levelingPaths and ns.levelingPaths[p.profession]
    if not catalog then return {} end
    local ctx = context(catalog, p)
    local ids, seen = {}, {}
    local function add(id)
        if id and not seen[id] and not (ns.vendorPrices and ns.vendorPrices[id]) then seen[id] = true; ids[#ids + 1] = id end
    end
    local scanned = {}
    local function reagent(id, depth)
        if scanned[id] and scanned[id] <= depth then return end
        scanned[id] = depth
        add(id)
        if depth >= 2 then return end
        for _, producer in ipairs(ctx.byOutput[id] or {}) do
            if producer.req < p.target then
                for _, input in ipairs(producer.inputs) do reagent(input[1], depth + 1) end
            end
        end
    end
    for _, recipe in ipairs(catalog.recipes) do
        local known = p.known(recipe.spell)
        local available = not recipe.special and recipe.source ~= "other"
            and (not recipe.faction or not p.faction or recipe.faction == p.faction)
        if recipe.req < p.target and recipe.gray > p.first and (known or available) then
            for _, input in ipairs(recipe.inputs) do reagent(input[1], 0) end
            if recipe.source == "auction" and not known then add(recipe.item) end
            if recipe.resale and p.resale then add(recipe.output) end
        end
    end
    table.sort(ids)
    return ids
end
