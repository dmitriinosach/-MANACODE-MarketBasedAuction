local _, ns = ...
local O = {}
ns.Obtain = O
O.DEPTH = 8
O.LOTTERY = 0.05
O.serial = 0
local edges
local nodes
local usesBy
local buys = {}
local cache
local hooked = {}
function O.Bump()
    O.serial = O.serial + 1
end
local function wrap(owner, name, tag)
    if not owner or hooked[tag] == owner[name] then return end
    local original = owner[name]
    owner[name] = function(...) O.Bump(); return original(...) end
    hooked[tag] = owner[name]
end
local function hook()
    wrap(ns.Markets, "Remember", "remember")
    wrap(ns.Alchemy, "SetPrice", "price")
    wrap(ns.Hidden, "Set", "hidden")
end
local function add(edge)
    local list = edges[edge.target]
    if not list then list = {}; edges[edge.target] = list end
    list[#list + 1] = edge
    nodes[edge.target] = true
    for _, input in ipairs(edge.inputs) do
        nodes[input[1]] = true
        local uses = usesBy[input[1]]
        if not uses then uses = {}; usesBy[input[1]] = uses end
        if uses[#uses] ~= edge then uses[#uses + 1] = edge end
    end
end
local function exchange(seen, target, tokens, ref)
    local key = "exchange:" .. tokens[1][1]
    if seen[target .. key] then return end
    seen[target .. key] = true
    add({key = key, kind = "exchange", target = target, inputs = tokens, out = 1, ref = ref})
end
local function build()
    if edges then return end
    edges, nodes, usesBy = {}, {}, {}
    for _, key in ipairs(ns.Crafting.order) do
        local catalog = ns.craftCatalogs[key]
        if catalog then
            for _, recipe in ipairs(catalog.recipes) do
                add({key = "craft:" .. key .. ":" .. tostring(recipe.spell),
                    kind = recipe.category == "alchemyTransmutes" and "transmute" or "craft",
                    target = recipe.raw, inputs = recipe.inputs, out = recipe.count, spell = recipe.spell,
                    profession = key, cooldown = recipe.cooldown, ref = recipe})
            end
        end
    end
    for _, family in ipairs(ns.gemFamilies or {}) do
        for cut, spell in pairs(family.spells) do
            add({key = "cut:" .. spell, kind = "cut", target = cut, inputs = {{family.raw, 1}}, out = 1,
                spell = spell, profession = "jewelry", ref = family})
        end
    end
    for _, mode in ipairs({"prospect", "mill"}) do
        for _, source in ipairs(ns.Prospect.Sources(mode)) do
            local outcomes = ns.Prospect.Outcomes(source)
            for _, outcome in ipairs(outcomes) do
                local family = ns.gemByItem and ns.gemByItem[outcome.id]
                if outcome.quantity > 0 and not (family and (family.expansion or "wrath") ~= source.expansion) then
                    local byproducts = {}
                    for _, other in ipairs(outcomes) do
                        if other.id ~= outcome.id then byproducts[#byproducts + 1] = {id = other.id, quantity = other.quantity} end
                    end
                    add({key = mode .. ":" .. source.itemID, kind = mode, target = outcome.id,
                        inputs = {{source.itemID, ns.Prospect.OPERATION}}, out = 0, yield = outcome.quantity,
                        chance = outcome.chance, byproducts = byproducts, skill = source.skill,
                        expansion = source.expansion, ref = source})
                end
            end
        end
    end
    for _, pair in ipairs(ns.recyclePairs or {}) do
        add({key = "recycle:" .. pair.key .. ":assemble", kind = "recycle", target = pair.big,
            inputs = {{pair.small, pair.ratio}}, out = 1, ref = pair})
        if pair.both then
            add({key = "recycle:" .. pair.key .. ":split", kind = "recycle", target = pair.small,
                inputs = {{pair.big, 1}}, out = pair.ratio, ref = pair})
        end
    end
    for _, band in ipairs(ns.disenchantBands or {}) do
        for _, output in ipairs(band.outputs) do
            if output.chance > 0 then
                local byproducts = {}
                for _, other in ipairs(band.outputs) do
                    if other ~= output then
                        byproducts[#byproducts + 1] = {id = other.itemID, quantity = other.chance * (other.minCount + other.maxCount) / 2}
                    end
                end
                add({key = "disenchant:" .. band.key, kind = "disenchant", target = output.itemID, inputs = {}, out = 0,
                    yield = output.chance * (output.minCount + output.maxCount) / 2, chance = output.chance,
                    byproducts = byproducts, skill = band.skill, expansion = band.expansion, ref = band})
            end
        end
    end
    local seen = {}
    for _, group in ipairs(ns.npcGoods or {}) do
        for _, good in ipairs(group.items or {}) do
            if good.tokens and good.tokens[1] then exchange(seen, good.raw, good.tokens, good) end
        end
    end
    for _, entry in ipairs(ns.exchanges or {}) do
        for _, offer in ipairs(entry.offers) do exchange(seen, offer.itemID, {{entry.currency, offer.count}}, offer) end
    end
end
function O.BuyEdge(id)
    local edge = buys[id]
    if not edge then
        edge = {key = "buy", kind = ns.vendorPrices and ns.vendorPrices[id] and "vendor" or "buy",
            target = id, inputs = {}, out = 1}
        buys[id] = edge
    end
    return edge
end
function O.IsBuy(edge)
    return edge.kind == "buy" or edge.kind == "vendor"
end
function O.Output(edge)
    return edge.yield or edge.out
end
function O.Edges(id)
    build()
    return edges[id] or {}
end
function O.RecipeEdge(recipe)
    local key = "craft:" .. tostring(recipe.profession) .. ":" .. tostring(recipe.spell)
    return O.Edge(recipe.raw, key) or {key = key, kind = recipe.category == "alchemyTransmutes" and "transmute" or "craft",
        target = recipe.raw, inputs = recipe.inputs, out = recipe.count, spell = recipe.spell,
        profession = recipe.profession, cooldown = recipe.cooldown, ref = recipe}
end
local gathers = {}
function O.GatherEdge(id)
    local gather = O.Gather(id)
    if not gather then return nil end
    local edge = gathers[id]
    if not edge or edge.ref ~= gather then
        edge = {key = "gather", kind = "gather", target = id, inputs = {}, out = 1, ref = gather}
        gathers[id] = edge
    end
    return edge
end
function O.Edge(id, key)
    if not key then return nil end
    if key == "buy" then return O.BuyEdge(id) end
    if key == "gather" then return O.GatherEdge(id) end
    for _, edge in ipairs(O.Edges(id)) do if edge.key == key then return edge end end
    return nil
end
local function price(id)
    local q = ns.Crafting.Quote(id)
    if q and q.price and (q.miss or 0) == 0 and q.complete ~= false and (not q.at or q.at <= time()) then
        return q.price, q
    end
    return nil, q
end
local function stale(id, q)
    return q ~= nil and not q.vendor and not q.manual and not ns.Markets.Fresh(id)
end
function O.Sale(id)
    local q = ns.Markets.Quote(id)
    if q and q.price and (q.miss or 0) == 0 and q.complete ~= false and (not q.at or q.at <= time()) then
        return q.price
    end
    return nil
end
function O.Market(id)
    local q = ns.Markets.Quote(id)
    if q and q.vendor then return nil end
    return O.Sale(id)
end
function O.IsLottery(edge)
    return edge.yield ~= nil and (edge.chance or 0) < O.LOTTERY
end
function O.Eligible(edge)
    if O.IsBuy(edge) then return true end
    if edge.cooldown or O.IsLottery(edge) or edge.kind == "exchange" or edge.kind == "gather"
        or edge.kind == "disenchant" then return false end
    return not (ns.Hidden and ns.Hidden.Is(edge.target))
end
local function edgeCost(edge, costs, stales, fee)
    if edge.kind == "disenchant" then return O.BandCost(edge, fee) end
    if O.IsBuy(edge) then
        local p, q = price(edge.target)
        return p, p, stale(edge.target, q), p and 0 or 1
    end
    local total, old, missing = 0, false, 0
    for _, input in ipairs(edge.inputs) do
        local c = costs[input[1]]
        if c == nil then return nil, nil, false, 1 end
        total = total + c * input[2]
        if stales[input[1]] then old = true end
    end
    if edge.yield then
        local others = 0
        for _, by in ipairs(edge.byproducts) do
            local p, q = price(by.id)
            if p then
                others = others + by.quantity * p
                if stale(by.id, q) then old = true end
            else missing = missing + 1 end
        end
        return math.max(0, total - others * (1 - fee)) / edge.yield, total / edge.yield, old, missing
    end
    return total / edge.out, total / edge.out, old, missing
end
local function stamp()
    local scans = ns.Store.DB().scans or {}
    local last = scans[#scans]
    return #scans .. ":" .. tostring(last and last.t or 0)
end
local function compute()
    build(); hook()
    local fee, mark = ns.Fee(), stamp()
    if cache and cache.serial == O.serial and cache.fee == fee and cache.stamp == mark then return cache end
    local costs, stales, best = {}, {}, {}
    for id in pairs(nodes) do
        local edge = O.BuyEdge(id)
        local c, _, old = edgeCost(edge, costs, stales, fee)
        costs[id], stales[id], best[id] = c, old, edge
    end
    for _ = 1, O.DEPTH do
        local improved = false
        for id, list in pairs(edges) do
            for _, edge in ipairs(list) do
                if O.Eligible(edge) then
                    local c, _, old = edgeCost(edge, costs, stales, fee)
                    if c and (costs[id] == nil or c < costs[id] - 0.000001) then
                        costs[id], stales[id], best[id], improved = c, old, edge, true
                    end
                end
            end
        end
        if not improved then break end
    end
    cache = {serial = O.serial, fee = fee, stamp = mark, costs = costs, stales = stales, best = best, options = {}}
    return cache
end
function O.Best(id)
    return compute().best[id] or O.BuyEdge(id)
end
function O.BestKey(id)
    return O.Best(id).key
end
function O.Cost(id)
    local c = compute()
    if c.costs[id] ~= nil then return c.costs[id] end
    return (price(id))
end
local function byCost(a, b)
    if a.cost ~= b.cost then
        if a.cost == nil then return false end
        if b.cost == nil then return true end
        return a.cost < b.cost
    end
    return a.edge.key < b.edge.key
end
function O.Alternatives(id)
    local c = compute()
    if c.options[id] then return c.options[id] end
    local list = {}
    local function option(edge)
        local cost, gross, old, missing = edgeCost(edge, c.costs, c.stales, c.fee)
        list[#list + 1] = {edge = edge, cost = cost, gross = gross, stale = old, missing = missing,
            cooldown = edge.cooldown or false, lottery = O.IsLottery(edge),
            hidden = not O.IsBuy(edge) and ns.Hidden ~= nil and ns.Hidden.Is(id),
            eligible = O.Eligible(edge), best = c.best[id] == edge}
    end
    option(O.BuyEdge(id))
    for _, edge in ipairs(O.Edges(id)) do option(edge) end
    table.sort(list, byCost)
    c.options[id] = list
    return list
end
function O.Ways(id)
    return #O.Edges(id)
end
local function merge(node, child)
    local l, m = node.limits, child.limits
    l.cooldown = l.cooldown or m.cooldown
    l.lottery = l.lottery or m.lottery
    l.stale = l.stale or m.stale
    l.short = l.short or m.short
    l.own = l.own or m.own
    l.missing = l.missing + m.missing
end
function O.CraftBest(id)
    for _, option in ipairs(O.Alternatives(id)) do
        if not O.IsBuy(option.edge) and option.eligible and option.cost then return option.edge end
    end
    return O.BuyEdge(id)
end
local function leaf(node, policy, fee)
    local item, qty = node.id, node.qty
    if node.edge.kind == "disenchant" then
        local net, gross, old, missing = O.BandCost(node.edge, fee)
        node.cost, node.gross, node.limits.stale = net, gross, old
        node.limits.missing = net and missing or math.max(1, missing)
        return
    end
    local sale = O.Sale(item)
    local net = sale and sale * (1 - fee)
    if node.edge.kind == "gather" then
        node.cost, node.gross, node.own = net, net, qty
        node.limits.missing, node.limits.own = net and 0 or 1, true
        return
    end
    local p, q = price(item)
    node.cost, node.gross, node.quote = p, p, q
    node.limits.stale = stale(item, q)
    node.limits.missing = p and 0 or 1
    node.limits.short = p ~= nil and not q.vendor and not q.manual and (q.units or 0) < math.ceil(qty - 0.000001)
    if not (policy and policy.owned and net) or (ns.vendorPrices and ns.vendorPrices[item]) then return end
    local own = math.min(math.max(0, GetItemCount(item, true) or 0), qty)
    if own <= 0 then return end
    node.own, node.limits.own = own, true
    if own >= qty - 0.000001 then
        node.cost, node.limits.missing, node.limits.short = net, 0, false
    elseif p then node.cost = (own * net + (qty - own) * p) / qty end
    node.gross = node.cost
end
function O.Evaluate(id, choice, policy)
    local c = compute()
    local visiting = {}
    local function auto(item, depth)
        if not policy or depth == 0 then return c.best[item] or O.BuyEdge(item) end
        if policy.craftAll then return O.CraftBest(item) end
        return O.BuyEdge(item)
    end
    local visit
    visit = function(item, qty, depth, bought)
        local picked = not bought and O.Edge(item, choice and choice[item]) or nil
        local edge = picked or (bought and O.BuyEdge(item)) or auto(item, depth)
        if visiting[item] or depth >= O.DEPTH then edge = O.BuyEdge(item) end
        for _, input in ipairs(edge.inputs) do
            if visiting[input[1]] then edge = O.BuyEdge(item) end
        end
        local node = {id = item, edge = edge, qty = qty, depth = depth, children = {},
            limits = {cooldown = edge.cooldown or false, lottery = O.IsLottery(edge), stale = false, short = false,
                own = false, missing = 0}}
        if O.IsBuy(edge) or edge.kind == "gather" or edge.kind == "disenchant" then
            leaf(node, policy, c.fee)
            return node
        end
        visiting[item] = true
        local per = O.Output(edge)
        local total = 0
        for _, input in ipairs(edge.inputs) do
            local child = visit(input[1], input[2] * qty / per, depth + 1)
            node.children[#node.children + 1] = child
            merge(node, child)
            if total and child.cost then total = total + child.cost * input[2] else total = nil end
        end
        visiting[item] = nil
        if total then
            node.gross = total / per
            if edge.yield then
                local others = 0
                for _, by in ipairs(edge.byproducts) do
                    local p, q = price(by.id)
                    if p then
                        others = others + by.quantity * p
                        if stale(by.id, q) then node.limits.stale = true end
                    else node.limits.missing = node.limits.missing + 1 end
                end
                node.cost = math.max(0, total - others * (1 - c.fee)) / per
            else node.cost = node.gross end
        end
        if node.cost == nil and not picked and policy and depth > 0 then return visit(item, qty, depth, true) end
        return node
    end
    return visit(id, 1, 0)
end
function O.Choice(node, into)
    local choice = into or {}
    if choice[node.id] == nil then choice[node.id] = node.edge.key end
    for _, child in ipairs(node.children) do O.Choice(child, choice) end
    return choice
end
function O.Ids(node)
    local ids, seen = {}, {}
    local function walk(current)
        if not seen[current.id] then seen[current.id] = true; ids[#ids + 1] = current.id end
        for _, child in ipairs(current.children) do walk(child) end
    end
    walk(node)
    return ids
end
function O.Signature(node)
    local parts = {}
    for item, key in pairs(O.Choice(node)) do parts[#parts + 1] = item .. "=" .. key end
    table.sort(parts)
    return table.concat(parts, ";")
end
function O.Paths(id, limit)
    local fee, sale = ns.Fee(), O.Sale(id)
    local paths, seen = {}, {}
    local function addPath(choice)
        local node = O.Evaluate(id, choice)
        local key = O.Signature(node)
        if seen[key] then return end
        seen[key] = true
        paths[#paths + 1] = {choice = O.Choice(node), node = node, cost = node.cost, gross = node.gross,
            limits = node.limits, margin = sale and node.cost and sale * (1 - fee) - node.cost or nil}
    end
    for _, option in ipairs(O.Alternatives(id)) do
        addPath({[id] = option.edge.key})
        for _, input in ipairs(option.edge.inputs) do
            for _, alt in ipairs(O.Alternatives(input[1])) do
                if not alt.best then addPath({[id] = option.edge.key, [input[1]] = alt.edge.key}) end
            end
        end
    end
    table.sort(paths, function(a, b)
        if a.margin ~= b.margin then
            if a.margin == nil then return false end
            if b.margin == nil then return true end
            return a.margin > b.margin
        end
        if a.cost ~= b.cost then
            if a.cost == nil then return false end
            if b.cost == nil then return true end
            return a.cost < b.cost
        end
        return O.Signature(a.node) < O.Signature(b.node)
    end)
    for i = #paths, (limit or 12) + 1, -1 do paths[i] = nil end
    return paths
end
function O.Tree(id, qty, options)
    options = options or {}
    local key = options.choice and options.choice[id] or O.BestKey(id)
    local edge = O.Edge(id, key) or O.BuyEdge(id)
    local choice = {}
    for item, way in pairs(options.choice or {}) do choice[item] = way end
    local recipe
    if O.IsBuy(edge) then
        choice[id] = "buy"
        recipe = {raw = id, count = 1, inputs = {{id, 1}}, edge = edge}
    else
        choice[id] = edge.key
        recipe = {raw = id, count = O.Output(edge), inputs = edge.inputs, spell = edge.spell,
            cooldown = edge.cooldown, edge = edge}
    end
    local plan = ns.CraftPlan.Build(recipe, {choice = choice, auto = true, quantity = qty, owned = options.owned,
        ignore = options.ignore, fee = options.fee or ns.Fee()})
    plan.edge, plan.recipe = edge, recipe
    return plan
end
function O.ProfessionName(edge)
    if edge.profession == "jewelry" then return ns.T("jewelrySection") end
    local catalog = edge.profession and ns.craftCatalogs[edge.profession]
    return catalog and ns.T(catalog.labelKey) or nil
end
function O.Label(edge)
    local kind = edge.kind
    if kind == "buy" then return ns.T("pathWayBuy") end
    if kind == "vendor" then return ns.T("pathWayVendor") end
    if kind == "craft" or kind == "transmute" or kind == "cut" then
        local keys = {craft = "pathWayCraft", transmute = "pathWayTransmute", cut = "pathWayCut"}
        return ns.T(keys[kind], O.ProfessionName(edge) or "")
    end
    if kind == "prospect" or kind == "mill" then
        return ns.T(kind == "prospect" and "pathWayProspect" or "pathWayMill", ns.Markets.Name(edge.inputs[1][1]))
    end
    if kind == "gather" then return ns.T("pathWayGather", O.GatherName(edge.ref)) end
    if kind == "disenchant" then return ns.T("pathWayDisenchant", O.BandName(edge.ref), O.BandLevels(edge.ref)) end
    if kind == "exchange" then
        return ns.T("pathWayExchange", O.Amount(edge.inputs[1][2]), ns.Markets.Name(edge.inputs[1][1]))
    end
    local pair = edge.ref
    if edge.target == pair.big then
        return ns.T("pathWayAssemble", ns.Markets.Name(pair.small), pair.ratio)
    end
    return ns.T("pathWaySplit", ns.Markets.Name(pair.big))
end
function O.KnownBy(edge)
    if not edge.spell then return {} end
    return ns.Recipes.KnownBy(edge.spell, O.ProfessionName(edge))
end
function O.Amount(value)
    if value >= 10 then return tostring(math.floor(value + 0.5)) end
    return ns.Decimal(value, 1, false, true)
end
local GATHER_KEYS = {herbalism = "professionHerbalism", mining = "professionMining",
    skinning = "professionSkinning", fishing = "professionFishing"}
O.gatherKeys = GATHER_KEYS
function O.Sources(id)
    return ns.reagentSources and ns.reagentSources[id] or nil
end
function O.Gather(id)
    local source = O.Sources(id)
    return source and source.gather or nil
end
function O.Drops(id)
    local source = O.Sources(id)
    return source and source.drops or {}
end
local function named(key, fallback)
    local text = ns.T(key)
    if text:sub(1, 1) == "[" then return fallback end
    return text
end
function O.ZoneName(zone)
    if not zone or zone == 0 then return ns.T("npcZoneUnknown") end
    return named("npcZone" .. zone, ns.T("npcZoneUnknown"))
end
function O.NpcName(npc)
    if not npc or npc == 0 then return ns.T("pathVendorAny") end
    return named("npcName" .. npc, ns.T("pathVendorAny"))
end
function O.GatherName(gather)
    local key = GATHER_KEYS[gather.profession]
    return key and ns.T(key) or tostring(gather.profession)
end
local function sameFaction(faction, own)
    return faction == nil or faction == "Both" or own == nil or faction == own
end
function O.Vendors(id)
    local list, faction = {}, UnitFactionGroup("player")
    local source = O.Sources(id)
    for _, vendor in ipairs(source and source.vendors or {}) do
        if sameFaction(vendor.faction, faction) then list[#list + 1] = vendor end
    end
    if #list == 0 then
        for _, group in ipairs(ns.npcGoods or {}) do
            for _, good in ipairs(group.items or {}) do
                if good.raw == id and good.buy then
                    for _, vendor in ipairs(good.vendors or {}) do
                        if sameFaction(vendor.faction, faction) then
                            list[#list + 1] = {npc = vendor.npc, faction = vendor.faction, zone = vendor.zone, x = vendor.x,
                                y = vendor.y, price = good.buy, stock = vendor.stock, restock = vendor.restock}
                        end
                    end
                end
            end
        end
    end
    if #list == 0 and ns.vendorPrices and ns.vendorPrices[id] then list[1] = {npc = 0, zone = 0, price = ns.vendorPrices[id]} end
    table.sort(list, function(a, b)
        if (a.price or 0) ~= (b.price or 0) then return (a.price or 0) < (b.price or 0) end
        return (a.npc or 0) < (b.npc or 0)
    end)
    return list
end
function O.Uses(id)
    build()
    local list, byKey = {}, {}
    for _, edge in ipairs(usesBy[id] or {}) do
        local craft = edge.kind == "craft" or edge.kind == "transmute"
        if not (craft and ns.Hidden and ns.Hidden.Is(edge.target)) then
            local key = edge.kind == "exchange" and (edge.key .. ">" .. edge.target) or edge.key
            local use = byKey[key]
            if not use then
                local count = 0
                for _, input in ipairs(edge.inputs) do if input[1] == id then count = count + input[2] end end
                use = {key = key, kind = edge.kind, edge = edge, count = count, outputs = {}, index = #list + 1}
                byKey[key] = use
                list[#list + 1] = use
            end
            use.outputs[#use.outputs + 1] = {id = edge.target, qty = O.Output(edge)}
        end
    end
    return list
end
function O.UseGains(id, fee)
    local gains = {}
    for _, use in ipairs(ns.Reagents.Demands(id, fee)) do
        if use.recipe then gains["craft:" .. use.recipe.profession .. ":" .. use.recipe.spell] = use.gain
        elseif use.source then gains[use.mode .. ":" .. id] = use.gain
        elseif use.offer then gains["exchange:" .. id .. ">" .. use.offer.itemID] = use.gain end
    end
    local sale = O.Sale(id)
    if not sale then return gains end
    for _, use in ipairs(O.Uses(id)) do
        local simple = use.kind == "cut" or use.kind == "recycle" or use.kind == "exchange"
        if gains[use.key] == nil and simple and use.count > 0 then
            local total = 0
            for _, output in ipairs(use.outputs) do
                local value = O.Sale(output.id)
                if not value or (use.kind == "exchange" and use.edge.ref.bound) then total = nil; break end
                total = total + value * output.qty
            end
            if total then gains[use.key] = total * (1 - fee) / use.count - sale * (1 - fee) end
        end
    end
    return gains
end
function O.UseLabel(use)
    local kind, edge = use.kind, use.edge
    local label
    if kind == "mill" then label = ns.T("pathUseMill")
    elseif kind == "prospect" then label = ns.T("pathUseProspect")
    elseif kind == "exchange" then label = ns.T("pathUseExchange")
    elseif kind == "recycle" then label = ns.T(edge.target == edge.ref.big and "pathUseAssemble" or "pathUseSplit")
    else label = O.Label(edge) end
    return ns.T("pathUseCount", label, O.Amount(use.count))
end
local Policy = {}
ns.ReagentPolicy = Policy
function Policy.Get()
    local db = ns.Store.DB()
    local state = db.reagentPolicy
    if type(state) ~= "table" then
        state = {craftAll = false, owned = false}
        db.reagentPolicy = state
    end
    return state
end
function Policy.Set(key, value)
    Policy.Get()[key] = value and true or false
end
O.BAND_CHEAPEST = 3
O.BAND_FRESH = 86400
local bandIndex = setmetatable({}, {__mode = "k"})
local bandMemo
local function snapshotBands(scan)
    local lots = scan.lots or {}
    local index = bandIndex[scan]
    if index and index.count == #lots then return index.bands end
    local items, me = {}, UnitName("player")
    for _, text in ipairs(lots) do
        local lot = ns.Lot.Decode(text)
        local meta = lot and scan.disenchantItems[lot.item]
        if meta and meta.band and lot.count > 0 and lot.buyout > 0 and lot.owner ~= "" and lot.owner ~= me then
            local byItem = items[meta.band] or {}
            items[meta.band] = byItem
            local unit = lot.buyout / lot.count
            if not byItem[lot.item] or unit < byItem[lot.item] then byItem[lot.item] = unit end
        end
    end
    local bands = {}
    for key, byItem in pairs(items) do
        local list = {}
        for _, unit in pairs(byItem) do list[#list + 1] = unit end
        table.sort(list)
        bands[key] = list
    end
    bandIndex[scan] = {count = #lots, bands = bands}
    return bands
end
function O.BandOffer(band)
    local mark = stamp()
    if not bandMemo or bandMemo.stamp ~= mark then
        local db, offers, keys, seen = ns.Store.DB(), {}, {}, {}
        local scans = db.scans or {}
        for i = #scans, 1, -1 do
            local key = scans[i].deGroup
            if key and not seen[key] then seen[key] = true; keys[#keys + 1] = key end
        end
        for key in pairs(db.disenchantDrafts or {}) do
            if not seen[key] then seen[key] = true; keys[#keys + 1] = key end
        end
        for _, key in ipairs(keys) do
            local scan = ns.Disenchant.Snapshot(key)
            if scan and scan.disenchantItems then
                for bandKey, units in pairs(snapshotBands(scan)) do
                    local old = offers[bandKey]
                    local at = (scan.t or 0) + (scan.secs or 0)
                    if not old or at > old.at then
                        local count, total = math.min(O.BAND_CHEAPEST, #units), 0
                        for i = 1, count do total = total + units[i] end
                        offers[bandKey] = {units = units, item = total / count, at = at}
                    end
                end
            end
        end
        bandMemo = {stamp = mark, offers = offers}
    end
    return bandMemo.offers[band.key]
end
function O.BandCost(edge, fee)
    local offer = O.BandOffer(edge.ref)
    if not offer then return nil, nil, false, 1 end
    local estimate = ns.Disenchant.Estimate(edge.ref, offer.item, fee)
    local others, missing, old = 0, 0, time() - offer.at > O.BAND_FRESH
    for _, output in ipairs(estimate.outputs) do
        if output.id ~= edge.target then
            if output.price then
                others = others + output.quantity * output.price
                if not ns.Disenchant.Fresh(output.id) then old = true end
            else missing = missing + 1 end
        end
    end
    return math.max(0, offer.item - others * (1 - fee)) / edge.yield, offer.item / edge.yield, old, missing
end
function O.BandName(band)
    local kind = band.kind == "weapon" and "Weapon" or (band.kind == "armor" and "Armor" or "Any")
    return ns.T("pathBand" .. kind .. (band.quality or 2))
end
function O.BandLevels(band)
    if band.minLevel == band.maxLevel then return tostring(band.minLevel) end
    return band.minLevel .. "-" .. band.maxLevel
end
local function fits(rule, edge)
    if rule.kinds and not rule.kinds[edge.kind] then return false end
    return not rule.categories or (edge.ref ~= nil and rule.categories[edge.ref.category or ""] == true)
end
function O.GroupOf(edge, side)
    for _, rule in ipairs(ns.pathGroups or {}) do
        if rule.side == side and fits(rule, edge) then
            return rule, rule.byProfession and (rule.key .. ":" .. tostring(edge.profession)) or rule.key
        end
    end
    return nil, nil
end
function O.Partition(list, side, edgeOf)
    local counts, keys = {}, {}
    for i, member in ipairs(list) do
        local rule, key = O.GroupOf(edgeOf(member), side)
        if rule then keys[i] = {rule, key}; counts[key] = (counts[key] or 0) + 1 end
    end
    local out, groups = {}, {}
    for i, member in ipairs(list) do
        local entry = keys[i]
        if entry and counts[entry[2]] >= entry[1].min then
            local group = groups[entry[2]]
            if not group then
                group = {rule = entry[1], key = entry[2], members = {}}
                groups[entry[2]] = group
                out[#out + 1] = group
            end
            group.members[#group.members + 1] = member
        else out[#out + 1] = {member = member} end
    end
    return out
end
O.MAP_DEPTH = 3
O.MAP_USES = 8
O.GROUP_ROWS = 6
function O.Map(id, state)
    local fee = ns.Fee()
    local root = O.Evaluate(id, state.choice, state.policy)
    local cards, missing, seen, scans = {}, {}, {}, {}
    local function need(item)
        if not seen[item] then seen[item] = true; missing[#missing + 1] = item end
    end
    local function opened(key, default)
        local value = state.open and state.open[key]
        if value == nil then return default end
        return value
    end
    local function push(card)
        cards[#cards + 1] = card
        return card
    end
    local function fill(group, members, place)
        local all = opened(group.key .. ":all", false)
        local shown = (all or #members <= O.GROUP_ROWS + 1) and #members or O.GROUP_ROWS
        for i = 1, shown do
            local member = members[i]
            local row = {member = member, id = member.kind == "use" and member.use.outputs[1].id or nil,
                cost = member.kind == "use" and member.gain or member.cost, key = group.key .. ">" .. member.key,
                path = member.path, expand = true}
            group.rows[i] = row
            if opened(row.key, group.rule.open) then
                row.open = true
                place(member, i)
            end
        end
        if shown < #members then group.rows[#group.rows + 1] = {more = #members - shown, key = group.key .. ":all", expand = true}
        elseif all and #members > O.GROUP_ROWS + 1 then
            group.rows[#group.rows + 1] = {less = true, key = group.key .. ":all", expand = true, open = true}
        end
        group.limit = #group.rows
    end
    local sale = O.Sale(id)
    push({key = "center", kind = "center", side = 0, depth = 0, item = id, rows = {}, path = true,
        cost = root.cost, sale = sale and sale * (1 - fee)})
    if not sale then need(id) end
    local chain = {}
    local left, right
    left = function(item, node, column, level, parent, parentRow, onPath)
        local base = parent .. "<" .. item .. ":"
        local kind = node and node.edge.kind
        local function card(fields, at, owner, ownerRow)
            fields.side, fields.depth, fields.item = -1, at or column, item
            fields.parent, fields.parentRow = owner or parent, owner and ownerRow or parentRow
            fields.rows = fields.rows or {}
            fields.path = onPath and fields.chosen or false
            return push(fields)
        end
        local market, vendors = O.Market(item), O.Vendors(item)
        if market or #vendors == 0 then
            local q = ns.Markets.Quote(item)
            card({key = base .. "auction", kind = "source", source = "auction", cost = market, edge = O.BuyEdge(item),
                chosen = kind == "buy", rows = {{id = item, units = market and q and q.units or nil}}})
            if not market then need(item) end
        end
        if #vendors > 0 then
            local rows = {}
            for i, vendor in ipairs(vendors) do rows[i] = {vendor = vendor, cost = vendor.price} end
            card({key = base .. "vendor", kind = "source", source = "vendor", cost = vendors[1].price, rows = rows,
                edge = O.BuyEdge(item), chosen = kind == "vendor"})
        end
        local gather = O.GatherEdge(item)
        if gather then
            local zones = {}
            for i, zone in ipairs(gather.ref.zones or {}) do zones[i] = zone end
            table.sort(zones, function(a, b)
                if (a.share or 0) ~= (b.share or 0) then return (a.share or 0) > (b.share or 0) end
                return a.zone < b.zone
            end)
            local rows = {}
            for i, zone in ipairs(zones) do rows[i] = {zone = zone} end
            card({key = base .. "gather", kind = "source", source = "gather", edge = gather, rows = rows,
                cost = market and market * (1 - fee), chosen = kind == "gather"})
        end
        local drops = O.Drops(item)
        if #drops > 0 then
            local rows = {}
            for i, drop in ipairs(drops) do rows[i] = {note = drop.note} end
            card({key = base .. "drop", kind = "source", source = "drop", rows = rows})
        end
        local function way(option, key)
            local edge = option.edge
            local fields = {key = key, kind = "way", edge = edge, option = option, cost = option.cost,
                chosen = node ~= nil and node.edge == edge, rows = {}, side = -1, item = item}
            fields.path = onPath and fields.chosen or false
            if option.cost == nil then
                if edge.kind == "disenchant" then
                    scans[item] = scans[item] or {}
                    scans[item][edge.ref.quality or 2] = true
                else need(item) end
            end
            if edge.kind == "disenchant" then
                fields.offer = O.BandOffer(edge.ref)
                fields.rows = {{info = "levels"}, {info = "chance"}, {info = "offer"}}
            end
            return fields
        end
        local function inputs(way)
            local edge = way.edge
            if edge.kind == "disenchant" then return end
            local per = O.Output(edge)
            for i, input in ipairs(edge.inputs) do
                local child = way.chosen and node and node.children[i] or nil
                local row = {id = input[1], qty = input[2] / per, cost = child and child.cost or O.Cost(input[1]),
                    key = way.key .. ">" .. input[1], path = way.path, node = child}
                way.rows[i] = row
                if row.cost == nil then need(input[1]) end
                if not chain[input[1]] then
                    if level >= O.MAP_DEPTH then row.deeper = true
                    else
                        row.expand = true
                        if opened(row.key, true) then
                            row.open = true
                            left(input[1], child, way.depth + 1, level + 1, way.key, i, way.path)
                        end
                    end
                end
            end
        end
        local options = {}
        for _, option in ipairs(O.Alternatives(item)) do
            if not O.IsBuy(option.edge) then options[#options + 1] = option end
        end
        chain[item] = true
        for _, entry in ipairs(O.Partition(options, -1, function(option) return option.edge end)) do
            if entry.member then
                local fields = way(entry.member, base .. entry.member.edge.key)
                inputs(card(fields))
            else
                local key = base .. "group:" .. entry.key
                local members, chosen = {}, false
                for i, option in ipairs(entry.members) do
                    members[i] = way(option, key .. "|" .. option.edge.key)
                    chosen = chosen or members[i].chosen
                end
                local group = card({key = key, kind = "group", rule = entry.rule, count = #members, best = members[1],
                    cost = members[1].cost, chosen = chosen})
                fill(group, members, function(member, row) inputs(card(member, column + 1, group.key, row)) end)
            end
        end
        chain[item] = nil
    end
    local function useCard(use, key, item)
        if use.gain == nil then need(item) end
        return {key = key, kind = "use", side = 1, item = item, use = use, gain = use.gain, rows = {}}
    end
    right = function(item, column, level, parent, parentRow)
        local list = O.Uses(item)
        if #list == 0 then return end
        local gains = O.UseGains(item, fee)
        for _, use in ipairs(list) do use.gain = gains[use.key] end
        table.sort(list, function(a, b)
            if a.gain ~= b.gain then
                if a.gain == nil then return false end
                if b.gain == nil then return true end
                return a.gain > b.gain
            end
            return a.index < b.index
        end)
        local base = parent .. ">" .. item .. ":"
        local function place(card, at, owner, ownerRow)
            card.depth, card.parent, card.parentRow = at, owner, ownerRow
            push(card)
            for j, output in ipairs(card.use.outputs) do
                local value = O.Sale(output.id)
                local row = {id = output.id, qty = output.qty, cost = value and value * (1 - fee), key = card.key .. ">" .. output.id}
                card.rows[j] = row
                if not value then need(output.id) end
                if #O.Uses(output.id) > 0 and not chain[output.id] then
                    if level >= O.MAP_DEPTH then row.deeper = true
                    else
                        row.expand = true
                        if opened(row.key, true) then
                            row.open = true
                            right(output.id, at + 1, level + 1, card.key, j)
                        end
                    end
                end
            end
        end
        chain[item] = true
        local entries = O.Partition(list, 1, function(use) return use.edge end)
        local shown = opened(base .. "all", false) and #entries or math.min(#entries, O.MAP_USES)
        for i = 1, shown do
            local entry = entries[i]
            if entry.member then
                place(useCard(entry.member, base .. entry.member.key, item), column, parent, parentRow)
            else
                local key = base .. "group:" .. entry.key
                local members = {}
                for j, use in ipairs(entry.members) do members[j] = useCard(use, key .. "|" .. use.key, item) end
                local group = push({key = key, kind = "group", side = 1, depth = column, item = item, parent = parent,
                    parentRow = parentRow, rule = entry.rule, count = #members, best = members[1], gain = members[1].gain,
                    rows = {}})
                fill(group, members, function(member, row) place(member, column + 1, group.key, row) end)
            end
        end
        if shown < #entries then
            push({key = base .. "all", kind = "more", side = 1, depth = column, item = item, parent = parent,
                parentRow = parentRow, more = #entries - shown, rows = {}})
        end
        chain[item] = nil
    end
    left(id, root, 1, 1, "center", nil, true)
    right(id, 1, 1, "center", nil)
    return {cards = cards, root = root, missing = missing, scans = scans}
end
