local _, ns = ...
local L = {}
ns.Leveling = L
local function integer(value, fallback, low, high)
    value = tonumber(value)
    if not value or value ~= value then value = fallback end
    return math.max(low, math.min(high, math.floor(value)))
end
function L.Options(options)
    options = options or {}
    local profession = options.profession or "enchanting"
    local catalog = ns.levelingCatalogs[profession]
    local first = integer(options.first, 1, 1, 450)
    return {profession = profession, strategy = options.strategy == "free" and "free" or "guide",
        freeChoices = options.freeChoices or {}, first = first, target = integer(options.target, 450, first, 450),
        tool = integer(options.tool, 0, 0, catalog and #catalog.tools or 0), reserve = integer(options.reserve, 0, 0, 20),
        owned = options.owned == true, choices = options.choices or {}, known = options.known or {},
        make = options.make or {}, open = options.open or {}}
end
function L.Obtain(id, options)
    local catalog = ns.levelingCatalogs[options and options.profession or "enchanting"]
    return catalog and (catalog.obtains[id] or ns.Crafting.byItem[id])
end
function L.Quote(id, options)
    local catalog = ns.levelingCatalogs[options and options.profession or "enchanting"]
    local vendor = catalog and catalog.vendors[id]
    if options and options.strategy == "free" then vendor = vendor or (catalog.freeVendors or {})[id] end
    if vendor then return {price = vendor, vendor = true, complete = true, miss = 0} end
    local quote = ns.Markets.Quote(id)
    if options and options.strategy == "free" and ns.Disenchant then
        local via = ns.Disenchant.MaterialVia(id)
        if via and (not quote or not quote.price or quote.complete == false or (quote.miss or 0) > 0 or via.price < quote.price) then
            return via
        end
    end
    return quote
end
local function price(quote)
    if quote and quote.price and quote.complete and (quote.miss or 0) == 0 then return quote.price end
end
local function unitCost(id, options, quotes, path)
    local obtain = options.make[id] and L.Obtain(id, options)
    if obtain and not path[id] then
        path[id] = true
        local total = 0
        for _, input in ipairs(obtain.inputs) do
            local cost = unitCost(input[1], options, quotes, path)
            if cost == nil then path[id] = nil; return nil end
            total = total + cost * input[2]
        end
        path[id] = nil
        return total / obtain.count
    end
    if quotes[id] == nil then quotes[id] = L.Quote(id, options) or false end
    return price(quotes[id])
end
local function better(left, right)
    if not right then return true end
    if left.missing ~= right.missing then return left.missing < right.missing end
    return left.cost < right.cost
end
local function contains(mask, bit)
    return math.floor(mask / bit) % 2 == 1
end
function L.Stages(catalog, options)
    local out = {}
    for index, stage in ipairs(catalog.stages) do
        local first, target = math.max(options.first, stage.first), math.min(options.target, stage.target)
        if first < target then out[#out + 1] = {index = index, first = first, target = target, choices = stage.choices} end
    end
    return out
end
local function transition(catalog, options, stage, recipe, previous, quotes)
    if recipe.requiredSkill > stage.first or recipe.gray < stage.target then return nil end
    local step = {first = stage.first, target = stage.target, index = stage.index, spell = recipe.spellID,
        tools = {}, inputs = {}, cost = 0, missing = 0, tool = previous.tool, mask = previous.mask,
        gains = 0, prev = previous}
    local skill = stage.first
    local function add(id, count)
        if count <= 0 then return end
        step.inputs[id] = (step.inputs[id] or 0) + count
        local value = unitCost(id, options, quotes, {})
        if value then step.cost = step.cost + value * count else step.missing = step.missing + 1 end
    end
    local function learn(part)
        if not part.acquisition or options.known[part.spellID] then return end
        local bit = part.acquisition.bit
        if contains(step.mask, bit) then return end
        step.mask = step.mask + bit
        for _, input in ipairs(part.acquisition.inputs) do add(input[1], input[2]) end
    end
    for tier = previous.tool + 1, recipe.tool do
        local tool = catalog.recipes[catalog.tools[tier].spell]
        if tool.requiredSkill > skill then return nil end
        learn(tool)
        for _, input in ipairs(tool.inputs) do
            if tier == 1 or input[1] ~= catalog.tools[tier - 1].item then add(input[1], input[2]) end
        end
        local gain = skill < tool.gray and skill < stage.target
        if gain and skill >= tool.yellow then step.toolUncertain = true end
        step.tools[#step.tools + 1] = {spell = tool.spellID, item = catalog.tools[tier].item, gain = gain}
        if gain then skill = skill + 1; step.gains = step.gains + 1 end
        step.tool = tier
    end
    step.count = stage.target - skill
    step.uncertain = step.toolUncertain or (step.count > 0 and stage.target - 1 >= recipe.yellow)
    step.extra = step.uncertain and options.reserve or 0
    if step.count + step.extra > 0 then
        learn(recipe)
        for _, input in ipairs(recipe.inputs) do add(input[1], input[2] * (step.count + step.extra)) end
    end
    step.totalCost, step.totalMissing = previous.cost + step.cost, previous.missing + step.missing
    return step
end
function L.Route(options)
    local p = L.Options(options)
    local catalog = ns.levelingCatalogs[p.profession]
    if not catalog then return {options = p, steps = {}, inputs = {}, missing = 0, unavailable = true, comparison = false} end
    local initial = {cost = 0, missing = 0, tool = p.tool, mask = 0}
    local states, quotes, comparison = {initial}, {}, true
    for _, stage in ipairs(L.Stages(catalog, p)) do
        local nextStates, keys = {}, {}
        for _, previous in ipairs(states) do
            for _, spell in ipairs(stage.choices) do
                if not p.choices[stage.index] or p.choices[stage.index] == spell then
                    local step = transition(catalog, p, stage, catalog.recipes[spell], previous, quotes)
                    if step then
                        if step.missing > 0 then comparison = false end
                        local key = step.tool .. ":" .. step.mask
                        local candidate = {cost = step.totalCost, missing = step.totalMissing,
                            tool = step.tool, mask = step.mask, step = step}
                        if better(candidate, keys[key]) then keys[key] = candidate end
                    end
                end
            end
        end
        for _, candidate in pairs(keys) do nextStates[#nextStates + 1] = candidate end
        table.sort(nextStates, function(a, b)
            if a.tool ~= b.tool then return a.tool < b.tool end
            return a.mask < b.mask
        end)
        states = nextStates
        if #states == 0 then return {options = p, steps = {}, inputs = {}, unavailable = true, comparison = false} end
    end
    local best
    for _, candidate in ipairs(states) do if better(candidate, best) then best = candidate end end
    local out = {options = p, steps = {}, inputs = {}, comparison = comparison, stateCount = #states,
        catalogVersion = catalog.version, cost = best and best.cost, missing = best and best.missing or 0}
    local step = best and best.step
    while step do table.insert(out.steps, 1, step); step = step.prev.step end
    for _, part in ipairs(out.steps) do
        for id, count in pairs(part.inputs) do out.inputs[id] = (out.inputs[id] or 0) + count end
    end
    return out
end
function L.Alternatives(route, step)
    if route.options.strategy == "free" then return L.FreeAlternatives(route, step) end
    local catalog, out = ns.levelingCatalogs[route.options.profession], {}
    local stage = {first = step.first, target = step.target, index = step.index}
    for _, spell in ipairs(catalog.stages[step.index].choices) do
        local candidate = transition(catalog, route.options, stage, catalog.recipes[spell], step.prev, {})
        if candidate then out[#out + 1] = candidate end
    end
    return out
end
function L.Candidates(options)
    local p = L.Options(options)
    local catalog, out = ns.levelingCatalogs[p.profession], {}
    local instruments = {}
    for _, tool in ipairs(catalog and catalog.tools or {}) do instruments[tool.spell] = true end
    for _, recipe in pairs(catalog and (catalog.freeRecipes or catalog.recipes) or {}) do
        if not instruments[recipe.spellID] and not recipe.unavailable and not recipe.cooldown and not recipe.spellFocus and not recipe.unsupportedTool
            and recipe.requiredSkill <= p.target and recipe.gray > p.first then out[#out + 1] = recipe end
    end
    table.sort(out, function(a, b) return a.spellID < b.spellID end)
    return out
end
function L.Expected(recipe, skill)
    if skill >= recipe.gray then return math.huge end
    if skill < recipe.yellow then return 1 end
    return (recipe.gray - recipe.yellow) / (recipe.gray - skill)
end
local function freeKnown(recipe, options)
    return recipe.sourceType ~= "other" or options.known[recipe.spellID] == true
end
local function freeContext(catalog, options)
    local context = {catalog = catalog, options = options, quotes = {}, recipes = catalog.freeRecipes or catalog.recipes}
    context.candidates = L.Candidates(options)
    return context
end
local function freeCost(inputs, context)
    local total, missing = 0, 0
    for id, count in pairs(inputs) do
        local value = unitCost(id, context.options, context.quotes, {})
        if value then total = total + value * count else missing = missing + 1 end
    end
    return total, missing
end
local function freeMove(skill, tool, recipe, context)
    local p, catalog = context.options, context.catalog
    if recipe.requiredSkill > skill or recipe.gray <= skill or not freeKnown(recipe, p) then return nil end
    local move = {first = skill, target = skill + 1, spell = recipe.spellID, tool = tool,
        tools = {}, inputs = {}, learns = {}, gains = 0, count = 0, extra = 0, uncertain = skill >= recipe.yellow}
    local function add(id, count)
        if count > 0 then move.inputs[id] = (move.inputs[id] or 0) + count end
    end
    for tier = tool + 1, recipe.tool do
        local entry = catalog.tools[tier]
        local rod = context.recipes[entry.spell] or catalog.recipes[entry.spell]
        if rod.requiredSkill > skill or not freeKnown(rod, p) then return nil end
        for _, input in ipairs(rod.inputs) do
            if tier == 1 or input[1] ~= catalog.tools[tier - 1].item then add(input[1], input[2]) end
        end
        if rod.acquisition then move.learns[#move.learns + 1] = rod end
        local gain = move.gains == 0 and skill < rod.gray
        move.tools[#move.tools + 1] = {spell = rod.spellID, item = entry.item, gain = gain}
        if gain then move.gains = 1 end
        move.tool = tier
    end
    if move.gains == 0 then
        move.count = L.Expected(recipe, skill)
        for _, input in ipairs(recipe.inputs) do add(input[1], input[2] * move.count) end
        if recipe.acquisition then move.learns[#move.learns + 1] = recipe end
    end
    move.cost, move.missing = freeCost(move.inputs, context)
    return move
end
local function freeKey(learned, skill, recipes)
    local out, keys = {}, {}
    for spell in pairs(learned) do
        if recipes[spell] and recipes[spell].gray > skill then out[spell] = true; keys[#keys + 1] = spell end
    end
    table.sort(keys)
    return out, table.concat(keys, ",")
end
local function freeAdvance(previous, move, context)
    local learned, charges = previous.learned, {}
    local cost, missing, changed = previous.cost + move.cost, previous.missing + move.missing, false
    for _, recipe in ipairs(move.learns) do
        if not context.options.known[recipe.spellID] and not learned[recipe.spellID] then
            if not changed then
                local copy = {}; for spell in pairs(learned) do copy[spell] = true end; learned, changed = copy, true
            end
            learned[recipe.spellID] = true
            for _, input in ipairs(recipe.acquisition.inputs) do charges[input[1]] = (charges[input[1]] or 0) + input[2] end
        end
    end
    local fee, unknown = freeCost(charges, context)
    local key
    learned, key = freeKey(learned, move.target, context.recipes)
    return {cost = cost + fee, missing = missing + unknown, learned = learned, tool = move.tool,
        key = move.tool .. ":" .. key, move = move, charges = charges, prev = previous}
end
local function freeDominates(left, right)
    if left.tool ~= right.tool or left.cost > right.cost or left.missing > right.missing then return false end
    for spell in pairs(right.learned) do if not left.learned[spell] then return false end end
    return true
end
local function freePrune(keys)
    local sorted, out = {}, {}
    for _, state in pairs(keys) do sorted[#sorted + 1] = state end
    table.sort(sorted, function(a, b)
        if a.missing ~= b.missing then return a.missing < b.missing end
        if a.cost ~= b.cost then return a.cost < b.cost end
        return a.key < b.key
    end)
    for _, state in ipairs(sorted) do
        local dominated = false
        for _, previous in ipairs(out) do if freeDominates(previous, state) then dominated = true; break end end
        if not dominated then out[#out + 1] = state end
    end
    return out
end
local function freeResult(options, best, catalog, comparison)
    local path, state = {}, best
    while state and state.move do table.insert(path, 1, state); state = state.prev end
    local out = {options = options, steps = {}, inputs = {}, cost = best and best.cost, missing = best and best.missing or 0,
        unavailable = not best, comparison = comparison, catalogVersion = catalog.version, estimated = true}
    for _, node in ipairs(path) do
        local move, step = node.move, out.steps[#out.steps]
        if not step or step.spell ~= move.spell or step.target ~= move.first then
            step = {spell = move.spell, index = move.first, first = move.first, target = move.first, count = 0,
                extra = 0, gains = 0, tools = {}, inputs = {}, cost = 0, missing = 0, prev = node.prev, estimated = true}
            out.steps[#out.steps + 1] = step
        end
        step.target, step.count, step.gains = move.target, step.count + move.count, step.gains + move.gains
        step.cost, step.missing = step.cost + node.cost - node.prev.cost, step.missing + node.missing - node.prev.missing
        step.uncertain = step.uncertain or move.uncertain
        for _, tool in ipairs(move.tools) do step.tools[#step.tools + 1] = tool end
        for _, inputs in ipairs({move.inputs, node.charges}) do
            for id, count in pairs(inputs) do
                step.inputs[id] = (step.inputs[id] or 0) + count
                out.inputs[id] = (out.inputs[id] or 0) + count
            end
        end
    end
    return out
end
function L.FreeRoute(options)
    local p = L.Options(options); p.strategy = "free"
    local catalog = ns.levelingCatalogs[p.profession]
    if not catalog then return {options = p, steps = {}, inputs = {}, unavailable = true, missing = 0, comparison = false} end
    local context = freeContext(catalog, p)
    local states, comparison, peak = {{cost = 0, missing = 0, learned = {}, tool = p.tool}}, true, 1
    for skill = p.first, p.target - 1 do
        local keys, moves = {}, {}
        for _, previous in ipairs(states) do
            for _, recipe in ipairs(context.candidates) do
                if not p.freeChoices[skill] or p.freeChoices[skill] == recipe.spellID then
                    local key = previous.tool .. ":" .. recipe.spellID
                    if moves[key] == nil then moves[key] = freeMove(skill, previous.tool, recipe, context) or false end
                    local move = moves[key]
                    if move then
                        local candidate = freeAdvance(previous, move, context)
                        if candidate.missing > 0 then comparison = false end
                        if better(candidate, keys[candidate.key]) then keys[candidate.key] = candidate end
                    end
                end
            end
        end
        states = freePrune(keys)
        peak = math.max(peak, #states)
        if #states == 0 then break end
    end
    local best
    for _, candidate in ipairs(states) do if better(candidate, best) then best = candidate end end
    local out = freeResult(p, best, catalog, comparison)
    out.stateCount = peak
    return out
end
function L.Plan(options)
    if options and options.strategy == "free" then return L.FreeRoute(options) end
    return L.Route(options)
end
function L.FreeAlternatives(route, step)
    local context = freeContext(ns.levelingCatalogs[route.options.profession], route.options)
    local out = {}
    for _, recipe in ipairs(context.candidates) do
        if recipe.requiredSkill <= step.first and recipe.gray >= step.target then
            if not freeKnown(recipe, route.options) then
                out[#out + 1] = {spell = recipe.spellID, locked = true, recipe = recipe}
            else
                local state = {cost = 0, missing = 0, learned = step.prev.learned, tool = step.prev.tool}
                for skill = step.first, step.target - 1 do
                    local move = freeMove(skill, state.tool, recipe, context)
                    if not move then state = nil; break end
                    state = freeAdvance(state, move, context)
                end
                if state then
                    local candidate = freeResult(route.options, state, context.catalog, true).steps[1]
                    out[#out + 1] = candidate
                end
            end
        end
    end
    return out
end
local function purchase(need, id, options)
    if need == 0 then return {cost = 0, units = 0} end
    if need > 1000 or not ns.Markets.Fresh(id) then return nil end
    local item, q = ns.Markets.Item(id), L.Quote(id, options)
    if not item or not q or q.shared then return nil end
    local observation = item.observations[item.quote.scanID]
    if not observation or observation.truncated then return nil end
    local groups, offers, me = {}, {}, UnitName("player")
    for _, lot in ipairs(ns.Markets.Offers(id)) do
        if lot.buyout > 0 and lot.count > 0 and lot.owner ~= "" and lot.owner ~= me then
            local key = lot.count .. ":" .. lot.buyout
            if not groups[key] then
                groups[key] = {stack = lot.count, buyout = lot.buyout, count = 0, page = 0}
                offers[#offers + 1] = groups[key]
            end
            groups[key].count = groups[key].count + 1
        end
    end
    return ns.Plan.Options(offers, need)[1]
end
function L.Basket(route)
    local p, stock, surplus, pending, used, roots = route.options, {}, {}, {}, {}, {}
    local catalog = ns.levelingCatalogs[p.profession]
    local rows, leaves = {}, {}
    local out = {rows = rows, leaves = leaves, roots = roots, cost = 0, cash = 0, lotsCost = 0,
        missing = 0, cashMissing = 0, stale = 0, unavailable = route.unavailable, extra = 0}
    local function build(id, count, depth, path)
        local q, obtain = L.Quote(id, p), L.Obtain(id, p)
        local expandable = obtain and not path[id] and depth < 8
        local make = p.make[id] and expandable or false
        local row = {id = id, count = count, depth = depth, quote = q, expandable = expandable,
            crafted = make, opened = p.open[id], children = {}, own = 0, need = count}
        rows[#rows + 1] = row
        local missingBefore = out.missing
        row.reused = math.min(count, surplus[id] or 0)
        surplus[id] = (surplus[id] or 0) - row.reused
        if p.owned then
            if stock[id] == nil then stock[id] = math.max(0, GetItemCount(id, true) or 0) end
            row.own = math.min(count - row.reused, stock[id]); stock[id] = stock[id] - row.own
        end
        row.need = count - row.own - row.reused
        local unit = price(q)
        if (row.own > 0 or (not make and row.need > 0)) and q and not q.vendor and not ns.Markets.Fresh(id) then
            out.stale = out.stale + 1
        end
        row.cost, row.cash, row.lotsCost = unit and row.own * unit or 0, 0, 0
        if row.own > 0 and not unit then out.missing = out.missing + 1 end
        if make and row.need > 0 then
            local crafts = math.ceil(row.need / obtain.count)
            row.extra = crafts * obtain.count - row.need
            surplus[id] = (surplus[id] or 0) + row.extra
            path[id] = true
            for _, input in ipairs(obtain.inputs) do
                local child = build(input[1], input[2] * crafts, depth + 1, path)
                row.children[#row.children + 1] = child
                row.cost, row.cash, row.lotsCost = row.cost + child.cost, row.cash + child.cash, row.lotsCost + child.lotsCost
            end
            path[id] = nil
        elseif row.need > 0 then
            local leaf = leaves[id]
            if not leaf then leaf = {id = id, need = 0, quote = q}; leaves[id] = leaf end
            leaf.need = leaf.need + row.need
            if unit then row.cash = row.need * unit; row.cost = row.cost + row.cash
            else out.missing = out.missing + 1; out.cashMissing = out.cashMissing + 1 end
        end
        row.incomplete = out.missing > missingBefore
        return row
    end
    local ids = {}
    for id, count in pairs(route.inputs) do
        pending[id] = p.strategy == "free" and math.ceil(count - 0.0000001) or count
        ids[#ids + 1] = id
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if not used[id] then
            used[id] = true
            local row = build(id, pending[id], 0, {})
            roots[#roots + 1] = row
            out.cost, out.cash = out.cost + row.cost, out.cash + row.cash
        end
    end
    out.lotsMissing = 0
    for _, leaf in pairs(leaves) do
        local batch = catalog.vendorBatches[leaf.id] or 1
        local units = math.ceil(leaf.need / batch) * batch
        local plan
        if leaf.quote and leaf.quote.vendor then plan = {cost = units * leaf.quote.price, units = units}
        elseif not (leaf.quote and leaf.quote.via) then plan = purchase(leaf.need, leaf.id, p) end
        leaf.plan = plan
        if plan then out.lotsCost = out.lotsCost + plan.cost else out.lotsMissing = out.lotsMissing + 1 end
    end
    if out.missing > 0 then out.cost = nil end
    if out.cashMissing > 0 then out.cash = nil end
    if out.lotsMissing > 0 then out.lotsCost = nil end
    return out
end
function L.Targets(options, all)
    local seen, ids = {}, {}
    if options == nil and all then
        for profession in pairs(ns.levelingCatalogs) do
            for _, id in ipairs(L.Targets({profession = profession}, true)) do
                if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
            end
        end
        table.sort(ids)
        return ids
    end
    local p = L.Options(options)
    local catalog = ns.levelingCatalogs[p.profession]
    if not catalog then return ids end
    local function add(id, path)
        if seen[id] or catalog.vendors[id] or ns.vendorPrices[id]
            or (p.strategy == "free" and (catalog.freeVendors or {})[id]) then return end
        seen[id] = true; ids[#ids + 1] = id
        local obtain = L.Obtain(id, p)
        if obtain and not path[id] and (all or p.make[id]) then
            path[id] = true
            for _, input in ipairs(obtain.inputs) do add(input[1], path) end
            path[id] = nil
        end
    end
    if all then
        local maxTool = p.tool
        local stages = L.Stages(catalog, p)
        if p.strategy == "free" then
            local choices = {}
            for _, recipe in ipairs(L.Candidates(p)) do
                if freeKnown(recipe, p) then choices[#choices + 1] = recipe.spellID end
            end
            stages = {{choices = choices}}
        end
        local recipes = p.strategy == "free" and (catalog.freeRecipes or catalog.recipes) or catalog.recipes
        for _, stage in ipairs(stages) do
            for _, spell in ipairs(stage.choices) do
                local r = recipes[spell]; maxTool = math.max(maxTool, r.tool)
                for _, input in ipairs(r.inputs) do add(input[1], {}) end
                if r.acquisition and not p.known[spell] then
                    for _, input in ipairs(r.acquisition.inputs) do add(input[1], {}) end
                end
            end
        end
        for tier = p.tool + 1, maxTool do
            local r = catalog.recipes[catalog.tools[tier].spell]
            for _, input in ipairs(r.inputs) do
                if tier == 1 or input[1] ~= catalog.tools[tier - 1].item then add(input[1], {}) end
            end
            if r.acquisition and not p.known[r.spellID] then
                for _, input in ipairs(r.acquisition.inputs) do add(input[1], {}) end
            end
        end
    else
        local basket = L.Basket(L.Plan(p))
        for id in pairs(basket.leaves) do
            if not seen[id] and not catalog.vendors[id] and not (p.strategy == "free" and (catalog.freeVendors or {})[id])
                and not ns.vendorPrices[id] then
                seen[id] = true; ids[#ids + 1] = id
            end
        end
    end
    table.sort(ids)
    return ids
end
function L.Complete(options, all, mode)
    local started = ns.Batch.Complete(L.Targets(options, all), mode, true)
    if started and ns.Batch.job then ns.Batch.job.levelingProfession = L.Options(options).profession end
    return started
end
function L.Brackets(route)
    local ranks = {1, 75, 150, 225, 300, 375, 450}
    local groups = {}
    for _, step in ipairs(route.steps) do
        local key = 1
        while key < 6 and step.first >= ranks[key + 1] do key = key + 1 end
        local group = groups[#groups]
        if not group or group.key ~= key then
            group = {key = key, first = ranks[key], target = ranks[key + 1], steps = {}}
            groups[#groups + 1] = group
        end
        group.steps[#group.steps + 1] = step
    end
    local prefix = {inputs = {}, options = route.options, unavailable = route.unavailable}
    local previousCost, previousCash = 0, 0
    for _, group in ipairs(groups) do
        for _, step in ipairs(group.steps) do
            for id, count in pairs(step.inputs) do prefix.inputs[id] = (prefix.inputs[id] or 0) + count end
        end
        local basket = L.Basket(prefix)
        group.cost = basket.cost and previousCost and basket.cost - previousCost or nil
        group.cash = basket.cash and previousCash and basket.cash - previousCash or nil
        previousCost, previousCash = basket.cost, basket.cash
    end
    return groups
end
