local _, ns = ...
local R = {}
ns.Reagents = R
function R.Items()
    local items, seen = {}, {}
    for id in pairs(ns.Crafting.inputs) do seen[id] = true end
    for _, family in ipairs(ns.gemFamilies) do seen[family.raw] = true end
    for _, mode in ipairs({"prospect", "mill"}) do
        for _, source in ipairs(ns.Prospect.Sources(mode)) do seen[source.itemID] = true end
    end
    for _, exchange in ipairs(ns.exchanges or {}) do seen[exchange.currency] = true end
    local names = {}
    for id in pairs(seen) do items[#items + 1] = {raw = id}; names[id] = ns.Markets.Name(id) end
    table.sort(items, function(a, b) return names[a.raw] < names[b.raw] end)
    return items
end
function R.Process(id)
    for _, mode in ipairs({"prospect", "mill"}) do
        local source = ns.Prospect.Source(mode, id)
        if source then return {mode = mode, source = source, count = ns.Prospect.OPERATION} end
    end
end
function R.Demands(id, fee)
    local demands = R.Uses(id, fee)
    for _, use in ipairs(ns.professionUses or {}) do
        local count = 0
        for _, input in ipairs(use.inputs) do if input[1] == id then count = count + input[2] end end
        if count > 0 then demands[#demands + 1] = {spell = use.spell, profession = use.profession,
            count = count, inputs = use.inputs} end
    end
    local process = R.Process(id)
    if process then
        local estimate = ns.Prospect.Estimate(process.source, ns.Prospect.Price(id), fee)
        local price = ns.Prospect.Price(id)
        process.estimate = estimate
        process.gain = estimate.exact and estimate.net and price and estimate.net / process.count - price * (1 - fee) or nil
        demands[#demands + 1] = process
    end
    local exchange, offers = R.Exchange(id, fee), {}
    for _, entry in ipairs(exchange and exchange.offers or {}) do
        offers[#offers + 1] = {exchange = exchange.exchange, offer = entry.offer, count = entry.offer.count,
            value = entry.value, gain = entry.value and exchange.price and entry.value - exchange.price * (1 - fee) or nil}
    end
    table.sort(offers, function(a, b)
        if a.value == b.value then return a.offer.itemID < b.offer.itemID end
        if a.value == nil then return false end
        if b.value == nil then return true end
        return a.value > b.value
    end)
    for _, use in ipairs(offers) do demands[#demands + 1] = use end
    return demands
end
function R.UseItem(use)
    return use.recipe and use.recipe.raw or use.source and use.source.itemID or use.offer and use.offer.itemID or 0
end
function R.UseName(use)
    if use.spell then return ns.Compat.SpellIcon(use.spell) or ns.T("levelSpell", use.spell) end
    return ns.Markets.Name(R.UseItem(use))
end
function R.Targets(id)
    local ids = {id}
    for _, use in ipairs(R.Demands(id, ns.Fee())) do
        if use.recipe then
            for _, target in ipairs(ns.Crafting.Targets(use.recipe)) do ids[#ids + 1] = target end
        elseif use.source then
            for _, output in ipairs(ns.Prospect.Outcomes(use.source)) do ids[#ids + 1] = output.id end
        elseif use.offer then
            if not use.offer.bound then ids[#ids + 1] = use.offer.itemID end
        else
            for _, input in ipairs(use.inputs) do ids[#ids + 1] = input[1] end
        end
    end
    return ids
end
function R.Resources(profession)
    local catalog, ids, seen = ns.gatheringCatalogs[profession], {}, {}
    if not catalog then return ids end
    for _, id in ipairs(catalog.items) do ids[#ids + 1], seen[id] = id, true end
    if catalog.mode then
        for _, source in ipairs(ns.Prospect.Sources(catalog.mode)) do
            if not seen[source.itemID] then ids[#ids + 1], seen[source.itemID] = source.itemID, true end
        end
    end
    table.sort(ids, function(a, b) return ns.Markets.Name(a) < ns.Markets.Name(b) end)
    return ids
end
function R.ResourceTargets(profession)
    local ids = {}
    for _, id in ipairs(R.Resources(profession)) do
        ids[#ids + 1] = id
        local process = R.Process(id)
        if process then
            for _, output in ipairs(ns.Prospect.Outcomes(process.source)) do ids[#ids + 1] = output.id end
        end
    end
    return ids
end
local inputIndex
local function byInput()
    local order, catalogs, index = ns.Crafting.order, ns.craftCatalogs, inputIndex
    if index and index.order == order and index.catalogs == catalogs and #index.seen == #order then
        local same = true
        for i, key in ipairs(order) do
            local catalog, seen = catalogs[key], index.seen[i]
            if seen.catalog ~= catalog or (catalog and (seen.recipes ~= catalog.recipes
                or seen.count ~= #catalog.recipes)) then same = false; break end
        end
        if same then return index.byInput end
    end
    index = {order = order, catalogs = catalogs, seen = {}, byInput = {}}
    for i, key in ipairs(order) do
        local catalog = catalogs[key]
        index.seen[i] = {catalog = catalog, recipes = catalog and catalog.recipes, count = catalog and #catalog.recipes}
        for _, recipe in ipairs(catalog and catalog.recipes or {}) do
            for _, input in ipairs(recipe.inputs) do
                local list = index.byInput[input[1]]
                if not list then list = {}; index.byInput[input[1]] = list end
                list[#list + 1] = {recipe = recipe, count = input[2]}
            end
        end
    end
    inputIndex = index
    return index.byInput
end
function R.Uses(id, fee)
    local uses = {}
    for _, entry in ipairs(byInput()[id] or {}) do
        local recipe = entry.recipe
        if not ns.Hidden.Is(recipe.raw) then
            local estimate = ns.Crafting.Estimate(recipe, fee)
            local market, basis = ns.Markets.Quote(id), ns.Crafting.Quote(id)
            local gain
            if estimate.revenue and market and market.price and market.miss == 0
                and not market.vendor and basis and basis.price then
                gain = (estimate.revenue - estimate.cost + basis.price * entry.count) / entry.count
                    - market.price * (1 - fee)
            end
            uses[#uses + 1] = {recipe = recipe, count = entry.count, estimate = estimate, gain = gain}
        end
    end
    table.sort(uses, function(a, b)
        if a.gain == b.gain then return a.recipe.raw < b.recipe.raw end
        if a.gain == nil then return false end
        if b.gain == nil then return true end
        return a.gain > b.gain
    end)
    return uses
end
function R.Complete(id, mode)
    return ns.Batch.Complete(R.Targets(id), mode, true)
end
function R.Packs(id, fee)
    local result, quote = {}, ns.Markets.Quote(id)
    local item = ns.Markets.Item(id)
    local observation = item and item.observations[item.quote.scanID]
    local offers = ns.Markets.Offers(id)
    local reference
    for _, offer in ipairs(offers) do
        if offer.price and offer.owner ~= UnitName("player") then reference = math.min(reference or math.huge, offer.price) end
    end
    local maximum = select(8, ns.Compat.ItemInfo(id))
    local function add(count, use)
        local size = math.min(count, type(maximum) == "number" and maximum > 0 and maximum or count)
        local entry = {raw = use and R.UseItem(use) or id, count = size, needed = count,
            recipe = use and use.recipe, spell = use and use.spell, use = use, lots = 0}
        for _, offer in ipairs(offers) do
            if offer.count == size and offer.buyout > 0 and offer.owner ~= UnitName("player") then
                entry.price = math.min(entry.price or math.huge, offer.buyout)
                entry.lots = entry.lots + 1
            end
        end
        if observation and observation.complete and not observation.truncated and quote and reference
            and quote.miss == 0 and entry.price then
            entry.net = entry.price * (1 - fee)
            entry.premium = entry.net - reference * size * (1 - fee)
        end
        result[#result + 1] = entry
    end
    add(1)
    for _, use in ipairs(R.Demands(id, fee)) do add(use.count, use) end
    return result
end
local function market(id)
    local q = ns.Markets.Quote(id)
    if q and q.price and not q.vendor and (q.miss or 0) == 0 and q.complete ~= false then return q.price end
end
function R.BagItems(fee)
    local rows, project = {}, ns.Accounting.Project()
    for id, entry in pairs(ns.Posting.Bags()) do
        local q = ns.Markets.Quote(id)
        if (q and q.price and not q.vendor) or ns.Markets.Catalog(id) then
            local price = market(id)
            local cost = ns.Posting.Cost(id, 0, project)
            local m = project.materials[id]
            rows[#rows + 1] = {id = id, count = entry.count, cost = cost, market = price,
                net = price and price * (1 - fee), value = price and math.floor(price * entry.count * (1 - fee)),
                posted = m and m.posted or 0, complete = price ~= nil}
        end
    end
    local names = {}
    for _, row in ipairs(rows) do names[row.id] = ns.Markets.Name(row.id) end
    table.sort(rows, function(a, b)
        local left, right = names[a.id], names[b.id]
        if left ~= right then return left < right end
        return a.id < b.id
    end)
    return rows
end
function R.PairFor(id)
    for _, pair in ipairs(ns.recyclePairs or {}) do
        if pair.small == id or pair.big == id then return pair end
    end
end
function R.Exchange(id, fee)
    for _, exchange in ipairs(ns.exchanges or {}) do
        if exchange.currency == id then
            local result = {exchange = exchange, price = market(id), offers = {}}
            for _, offer in ipairs(exchange.offers) do
                local price = not offer.bound and market(offer.itemID) or nil
                local entry = {offer = offer, price = price, value = price and price * (1 - fee) / offer.count}
                result.offers[#result.offers + 1] = entry
                if entry.value and (not result.best or entry.value > result.best.value) then result.best = entry end
            end
            return result
        end
    end
end
function R.Options(id, fee)
    local price = market(id)
    local sell = price and price * (1 - fee)
    local options = {{key = "sell", value = sell, best = false}}
    local craft = {key = "craft", best = false}
    for _, use in ipairs(R.Uses(id, fee)) do
        if use.gain and sell then craft.value, craft.recipe, craft.count = sell + use.gain, use.recipe, use.count; break end
    end
    options[2] = craft
    local recycle = {key = "recycle", best = false}
    local pair = R.PairFor(id)
    if pair then
        recycle.pair = pair
        local small, big = market(pair.small), market(pair.big)
        if id == pair.big and pair.both and small then recycle.value = pair.ratio * small * (1 - fee)
        elseif id == pair.small and big then recycle.value = big * (1 - fee) / pair.ratio end
    end
    options[3] = recycle
    local process = R.Process(id)
    if process then
        local estimate = ns.Prospect.Estimate(process.source, ns.Prospect.Price(id), fee)
        recycle.mode, recycle.source = process.mode, process.source
        recycle.value = estimate.exact and estimate.net and estimate.net / process.count or nil
    end
    local exchange = R.Exchange(id, fee)
    if exchange then
        options[3] = {key = "exchange", best = false, exchange = exchange.exchange,
            value = exchange.best and exchange.best.value, offer = exchange.best and exchange.best.offer}
    end
    local best
    for _, option in ipairs(options) do
        if option.value and (not best or option.value > best.value * 1.02) then best = option end
    end
    if best then best.best = true end
    return options
end
function R.Next(id, fee, limit)
    local options = R.Options(id, fee)
    local sell, recycle = options[1].value, options[3]
    local list = {}
    for _, use in ipairs(R.Demands(id, fee)) do
        if use.recipe or use.source or use.offer then
            list[#list + 1] = {recipe = use.recipe, source = use.source, mode = use.mode, offer = use.offer,
                exchange = use.exchange, count = use.count, gain = use.gain, index = #list + 1}
        end
    end
    if recycle.pair and not recycle.mode then
        list[#list + 1] = {pair = recycle.pair, gain = recycle.value and sell and recycle.value - sell, index = #list + 1}
    end
    table.sort(list, function(a, b)
        if a.gain ~= b.gain then
            if a.gain == nil then return false end
            if b.gain == nil then return true end
            return a.gain > b.gain
        end
        return a.index < b.index
    end)
    local result = {}
    for i = 1, math.min(limit, #list) do result[i] = list[i] end
    return sell, result, #list
end
function R.Gap(id, entry)
    local ids = {id}
    local own = ns.Markets.Quote(id)
    local priced = own and own.price and (own.miss or 0) == 0
    if entry.recipe then
        for _, target in ipairs(ns.Crafting.Targets(entry.recipe)) do ids[#ids + 1] = target end
        if not priced then return "nextGapSelf", ids end
        return ns.Markets.Quote(entry.recipe.raw) and "nextGapInputs" or "nextGapProduct", ids
    elseif entry.source then
        for _, output in ipairs(ns.Prospect.Outcomes(entry.source)) do ids[#ids + 1] = output.id end
        if not ns.Prospect.Price(id) then return "nextGapSelf", ids end
        return entry.mode == "mill" and "nextGapPigments" or "nextGapGems", ids
    elseif entry.offer then
        ids[#ids + 1] = entry.offer.itemID
        return priced and "nextGapProduct" or "nextGapSelf", ids
    end
    local pair = entry.pair
    ids[#ids + 1] = id == pair.big and pair.small or pair.big
    return priced and "nextGapPair" or "nextGapSelf", ids
end
