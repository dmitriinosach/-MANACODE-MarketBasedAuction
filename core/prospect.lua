local _, ns = ...
local P = {}
ns.Prospect = P
P.OPERATION = 5
P.priceSeconds = 1800
P.RARE = 0.05
P.modes = {
    prospect = {sources = "prospectSources", titleKey = "pmProspectTitle"},
    mill = {sources = "millSources", titleKey = "pmMillTitle"},
}
local built = {}
local function market(mode)
    local def = P.modes[mode]
    if not def then return nil end
    if built[mode] then return built[mode] end
    local list = ns[def.sources] or {}
    local result = {mode = mode, sources = {}, byID = {}, outputs = {}}
    local seen = {}
    for _, source in ipairs(list) do
        result.sources[#result.sources + 1] = source
        result.byID[source.itemID] = source
    end
    for _, source in ipairs(list) do
        for _, slot in ipairs(source.slots) do
            for _, option in ipairs(slot.options) do
                if not seen[option.itemID] and not result.byID[option.itemID] then
                    seen[option.itemID] = true
                    result.outputs[#result.outputs + 1] = option.itemID
                end
            end
        end
    end
    table.sort(result.outputs)
    built[mode] = result
    return result
end
function P.Sources(mode)
    local m = market(mode)
    return m and m.sources or {}
end
function P.Source(mode, id)
    local m = market(mode)
    return m and m.byID[id]
end
function P.Targets(mode)
    local m = market(mode)
    return m and m.outputs or {}
end
function P.TargetItems(mode)
    local list = {}
    for _, id in ipairs(P.Targets(mode)) do list[#list + 1] = {raw = id} end
    return list
end
function P.IsTarget(mode, id)
    for _, target in ipairs(P.Targets(mode)) do if target == id then return true end end
    return false
end
function P.Yield(source, id)
    local quantity, miss = 0, 1
    for _, slot in ipairs(source.slots) do
        for _, option in ipairs(slot.options) do
            if option.itemID == id then
                local hit = slot.chance * option.chance
                quantity = quantity + hit * (option.minCount + option.maxCount) / 2
                miss = miss * (1 - hit)
            end
        end
    end
    return quantity, 1 - miss
end
function P.Outcomes(source)
    local list, byID = {}, {}
    for _, slot in ipairs(source.slots) do
        for _, option in ipairs(slot.options) do
            local row = byID[option.itemID]
            if not row then
                row = {id = option.itemID, minCount = option.minCount, maxCount = option.maxCount}
                byID[option.itemID] = row; list[#list + 1] = row
            end
            row.minCount, row.maxCount = math.min(row.minCount, option.minCount), math.max(row.maxCount, option.maxCount)
        end
    end
    for _, row in ipairs(list) do row.quantity, row.chance = P.Yield(source, row.id) end
    table.sort(list, function(a, b)
        if a.quantity ~= b.quantity then return a.quantity > b.quantity end
        return a.id < b.id
    end)
    return list
end
function P.Average(source, target)
    return (P.Yield(source, target))
end
function P.SourcesFor(mode, target)
    local list = {}
    for _, source in ipairs(P.Sources(mode)) do
        if P.Average(source, target) > 0 then list[#list + 1] = source end
    end
    return list
end
function P.Price(id, fixed)
    local q = fixed and fixed[id] or ns.Markets.Quote(id)
    if q and q.price and (q.miss or 0) == 0 and q.complete ~= false then return q.price end
    return nil
end
function P.Fresh(id)
    return ns.Markets.Fresh(id, P.priceSeconds)
end
local cards = setmetatable({}, {__mode = "k"})
function P.Deck(source, id)
    if not source.decks then return nil end
    local map = cards[source]
    if not map then
        map = {}
        for deck, list in pairs(source.decks) do
            for _, card in ipairs(list) do map[card] = {deck, #list} end
        end
        cards[source] = map
    end
    local entry = map[id]
    if entry then return entry[1], entry[2] end
end
function P.PriceID(source, id)
    if source.zero and source.zero[id] then return nil end
    return (P.Deck(source, id)) or id
end
function P.OutcomePrice(source, id, fixed)
    local priced = P.PriceID(source, id)
    if not priced then return 0 end
    local price = P.Price(priced, fixed)
    local _, size = P.Deck(source, id)
    return price and size and price / size or price
end
function P.RecipeTargets(source)
    local list, seen = {}, {}
    for _, output in ipairs(P.Outcomes(source)) do
        local id = P.PriceID(source, output.id)
        if id and not seen[id] then seen[id] = true; list[#list + 1] = id end
    end
    return list
end
function P.Spread(result, slots, prices, fee, cost)
    local low, high = 0, 0
    for _, slot in ipairs(slots) do
        local least, most, covered = nil, nil, 0
        for pass = 1, 2 do
            for _, option in ipairs(slot.options) do
                local price = prices[option.itemID]
                if price and (pass == 2 or option.chance >= P.RARE) then
                    local small, large = option.minCount * price, option.maxCount * price
                    least = least and math.min(least, small) or small
                    most = most and math.max(most, large) or large
                end
            end
            if least then break end
        end
        for _, option in ipairs(slot.options) do covered = covered + option.chance end
        if least then
            if slot.chance >= 1 and covered >= 0.999999 then low = low + least end
            high = high + most
        end
    end
    result.low = low * (1 - fee) - cost
    result.high = high * (1 - fee) - cost
end
function P.Estimate(source, unit, fee, fixed)
    local cost = unit and unit * (P.OPERATION + 0.0) or nil
    local result = {cost = cost, outputs = P.Outcomes(source), gross = 0, fresh = true, missing = 0}
    local prices = {}
    for _, output in ipairs(result.outputs) do
        local priced = P.PriceID(source, output.id)
        output.price, output.deck = P.OutcomePrice(source, output.id, fixed), P.Deck(source, output.id)
        if output.price then
            prices[output.id] = output.price
            result.gross = result.gross + output.quantity * output.price
        else result.missing = result.missing + 1 end
        result.fresh = result.fresh and (fixed ~= nil or not priced or P.Fresh(priced))
    end
    result.exact = result.missing == 0
    result.net = result.gross * (1 - fee)
    if result.missing == #result.outputs then
        result.gross, result.net = nil, nil
        return result
    end
    if cost then
        result.margin = result.net - cost
        result.percent = cost > 0 and result.margin / cost * 100 or nil
        P.Spread(result, source.slots, prices, fee, cost)
    end
    return result
end
function P.Limit(source, fee, percent, fixed)
    local estimate = P.Estimate(source, nil, fee, fixed)
    if not estimate.net or estimate.net <= 0 then return nil end
    local limit = math.floor(estimate.net / (1 + percent / 100) / P.OPERATION)
    return limit > 0 and limit or nil
end
function P.Via(estimate, source, target, fee)
    local average = P.Average(source, target)
    if average <= 0 or not estimate.cost then return nil, nil end
    local others = 0
    for _, output in ipairs(estimate.outputs) do
        if output.id ~= target and output.price then others = others + output.quantity * output.price end
    end
    return estimate.cost / average, math.max(0, estimate.cost - others * (1 - fee)) / average
end
function P.GroupKey(mode, source)
    if mode == "prospect" then return source.expansion end
    return source.slots[1].options[1].itemID
end
local expansionRank = {wrath = 3, bc = 2, classic = 1}
local function order(a, b)
    if a.skill ~= b.skill then return a.skill > b.skill end
    return a.itemID < b.itemID
end
function P.Rows(mode, options)
    local rows = {}
    local list = options.view == "target" and options.target and P.SourcesFor(mode, options.target) or P.Sources(mode)
    for _, source in ipairs(list) do
        local skill = options.skill or 0
        if (not options.expansions or options.expansions[source.expansion])
            and (skill <= 0 or source.skill <= skill) then
            local unit = P.Price(source.itemID)
            local estimate = P.Estimate(source, unit, options.fee)
            local row = {id = source.itemID, source = source, unit = unit, cost = estimate.cost, estimate = estimate,
                group = P.GroupKey(mode, source)}
            if options.view == "target" and options.target then
                row.average = P.Average(source, options.target)
                row.via, row.viaNet = P.Via(estimate, source, options.target, options.fee)
                local price = P.Price(options.target)
                row.viaRate = row.via and price and price > 0 and (row.via / price - 1) * 100 or nil
            end
            rows[#rows + 1] = row
        end
    end
    table.sort(rows, function(a, b)
        local left, right = a.estimate.margin, b.estimate.margin
        if left ~= right then
            if left == nil then return false end
            if right == nil then return true end
            return left > right
        end
        return order(a.source, b.source)
    end)
    return rows
end
function P.Groups(mode, rows)
    local byKey, groups = {}, {}
    for _, row in ipairs(rows) do
        local group = byKey[row.group]
        if not group then
            group = {key = row.group, rows = {}, expansion = row.source.expansion,
                skillMin = row.source.skill, skillMax = row.source.skill}
            byKey[row.group] = group; groups[#groups + 1] = group
        end
        group.rows[#group.rows + 1] = row
        group.skillMin, group.skillMax = math.min(group.skillMin, row.source.skill), math.max(group.skillMax, row.source.skill)
    end
    table.sort(groups, function(a, b)
        if a.expansion ~= b.expansion then return expansionRank[a.expansion] > expansionRank[b.expansion] end
        if a.skillMax ~= b.skillMax then return a.skillMax > b.skillMax end
        return tostring(a.key) < tostring(b.key)
    end)
    return groups
end
function P.PriceIDs(mode, ids)
    local list, seen = {}, {}
    local function add(id)
        if not seen[id] then seen[id] = true; list[#list + 1] = id end
    end
    for _, source in ipairs(P.Sources(mode)) do
        local wanted = not ids
        for _, id in ipairs(ids or {}) do if id == source.itemID then wanted = true end end
        if wanted then
            add(source.itemID)
            for _, output in ipairs(P.Outcomes(source)) do add(output.id) end
        end
    end
    return list
end
function P.Refresh(ids, mode)
    return ns.Batch.Complete(ids, mode, true)
end
function P.Offers(id)
    local offers, byKey, me = {}, {}, UnitName("player")
    for _, lot in ipairs(ns.Markets.Offers(id)) do
        if lot.buyout > 0 and lot.count > 0 and lot.owner ~= "" and lot.owner ~= me then
            local key = lot.count .. ":" .. lot.buyout
            local offer = byKey[key]
            if not offer then
                offer = {stack = lot.count, buyout = lot.buyout, count = 0, page = 0}
                byKey[key] = offer; offers[#offers + 1] = offer
            end
            offer.count = offer.count + 1
        end
    end
    return offers
end
P.spent = {}
function P.PurchasePlan(mode, id, options)
    local source = P.Source(mode, id)
    local result = {count = 0, units = 0, cost = 0, stale = false, rejected = nil}
    if not source then result.rejected = "unknown"; return result end
    local quote = ns.Markets.Quote(id)
    result.stale = quote ~= nil and not P.Fresh(id)
    local limit = options.priceLimit or P.Limit(source, options.fee, options.percent or 0)
    result.limit = limit
    if not limit then result.rejected = "unknown"; return result end
    if quote and quote.scanID and P.spent[id] == quote.scanID then result.rejected = "refresh"; return result end
    local plan = ns.Plan.Price(P.Offers(id), limit, GetMoney())
    result.plan, result.count, result.units, result.cost = plan, plan.lots, plan.units, plan.cost
    if plan.lots == 0 then
        local free = ns.Plan.Price(P.Offers(id), limit, math.huge)
        result.rejected = free.lots > 0 and "money" or "threshold"
    end
    return result
end
function P.CancelBuy()
    P.purchase = nil
    ns.Buy.Stop()
end
function P.Purchase(mode, id, options)
    if P.purchase then
        if P.purchase.id ~= id then P.CancelBuy(); ns.say(ns.T("pmBuyContextChanged")); return false end
        return ns.Buy.Confirm()
    end
    if ns.Buy.Active() or not ns.Scan.state.open then return false end
    if not ns.Scan.Release() then ns.say(ns.T("sayBusy")); return false end
    local plan = P.PurchasePlan(mode, id, options)
    if plan.count == 0 then ns.say(ns.T("pmBuyEmpty")); return false end
    local limit = plan.limit
    local function guard(index)
        local item = ns.Lot.FromLink(GetAuctionItemLink("list", index))
        local _, _, count, _, _, _, _, _, buyout, _, _, owner = GetAuctionItemInfo("list", index)
        return item == id and count ~= nil and count > 0 and buyout ~= nil and buyout > 0
            and owner ~= nil and owner ~= "" and owner ~= UnitName("player") and buyout < limit * count
    end
    P.purchase = {mode = mode, id = id, plan = plan, limit = limit, starting = true}
    local started = ns.Buy.Start(ns.Markets.Name(id), plan.plan, id, guard)
    P.purchase.starting = false
    if not started then P.purchase = nil end
    return started
end
function P.BuyChanged()
    local job = P.purchase
    if job and not job.starting then
        if (ns.Buy.state.refused or 0) > 0 then P.CancelBuy()
        elseif not ns.Buy.Active() then
            local quote = ns.Markets.Quote(job.id)
            if ns.Buy.state.bought > 0 and quote and quote.scanID then P.spent[job.id] = quote.scanID end
            P.purchase = nil
        end
    end
    local view = ns.ProspectUI
    if view and view.frame and view.frame:IsShown() then view:Render() end
end
