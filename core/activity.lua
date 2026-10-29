local _, ns = ...
local A = {}
ns.Activity = A
local function lowerQuartile(observation)
    if observation.truncated then return nil end
    local prices, total = {}, 0
    for _, lot in ipairs(ns.Markets.Lots(observation) or {}) do
        if lot.count > 0 and lot.buyout > 0 then
            prices[#prices + 1] = {lot.buyout / lot.count, lot.count}
            total = total + lot.count
        end
    end
    table.sort(prices, function(a, b) return a[1] < b[1] end)
    local seen = 0
    for _, entry in ipairs(prices) do
        seen = seen + entry[2]
        if seen >= total * 0.25 then return entry[1] end
    end
    return nil
end
local function compare(point, observation, item)
    point.compared = true
    point.p25 = point.p25 or lowerQuartile(observation)
    local previous
    for _, scanID in ipairs(item and item.order or {}) do
        local other = item.observations[scanID]
        if other and scanID ~= observation.scanID and other.scope == observation.scope
            and other.at <= (observation.since or observation.at) and (not previous or other.at > previous.at) then
            previous = other
        end
    end
    local flow = previous and A.Compare(previous, observation)
    if not flow then return end
    point.from, point.added, point.addedUnits = flow.from, flow.added, flow.addedUnits
    point.gone, point.goneUnits = flow.gone, flow.goneUnits
    point.early, point.earlyUnits = flow.beforeExpiry, flow.beforeExpiryUnits
end
A.limits = {markets = 4, items = 2048, points = 720, days = 30}
local function series(key, id, at)
    local db = ns.Store.DB()
    db.activityHistory = db.activityHistory or {}
    local markets = db.activityHistory
    local market = markets[key]
    if not market then
        local count, oldest, stamp = 0, nil, math.huge
        for name, value in pairs(markets) do
            count = count + 1
            if value.at < stamp then oldest, stamp = name, value.at end
        end
        if count >= A.limits.markets then markets[oldest] = nil end
        market = {items = {}, at = at}; markets[key] = market
    end
    local points = market.items[id]
    if not points then
        local count, oldest, stamp = 0, nil, math.huge
        for itemID, list in pairs(market.items) do
            count = count + 1
            if list[#list].at < stamp then oldest, stamp = itemID, list[#list].at end
        end
        if count >= A.limits.items then market.items[oldest] = nil end
        points = {}; market.items[id] = points
    end
    return market, points
end
local function trim(market, id, points)
    local oldest = time() - A.limits.days * 86400
    while #points > A.limits.points or (#points > 0 and points[1].at < oldest) do table.remove(points, 1) end
    if #points == 0 then market.items[id] = nil end
end
function A.Record(id, observation, key, item)
    if not observation.complete then return end
    if observation.scope ~= "item" and not (ns.gemByItem and ns.gemByItem[id]) and not (ns.Crafting and ns.Crafting.items[id]) then return end
    local market, points = series(key, id, observation.at)
    for _, point in ipairs(points) do
        if point.scanID == observation.scanID then
            if not point.compared then compare(point, observation, item) end
            return
        end
    end
    if points[#points] and points[#points].at > observation.at then return end
    local count = observation.count
    local lots = not count and not observation.truncated and ns.Markets.Lots(observation)
    if lots then
        count = 0
        for _, lot in ipairs(lots) do
            if lot.count > 0 and lot.buyout > 0 then count = count + 1 end
        end
    end
    if not count then
        if #points == 0 then market.items[id] = nil end
        return
    end
    local point = {at = observation.at, scanID = observation.scanID, price = observation.price,
        lots = count, units = observation.units}
    compare(point, observation, item)
    points[#points + 1] = point
    market.at = math.max(market.at, observation.at)
    trim(market, id, points)
end
function A.Add(key, id, point)
    local market, points = series(key, id, point.at)
    for _, existing in ipairs(points) do
        if existing.scanID == point.scanID then
            existing.p25 = existing.p25 or point.p25
            return
        end
    end
    local index = #points + 1
    while index > 1 and points[index - 1].at > point.at do index = index - 1 end
    table.insert(points, index, point)
    market.at = math.max(market.at, point.at)
    trim(market, id, points)
end
local function own(id)
    local key = ns.Markets.Key()
    local item = ns.Markets.Item(id)
    for _, scanID in ipairs(item and item.order or {}) do
        local observation = item.observations[scanID]
        observation.scanID = scanID
        A.Record(id, observation, key, item)
    end
    local market = (ns.Store.DB().activityHistory or {})[key]
    return market and market.items[id] or {}
end
function A.History(id, days, volume)
    local result = {points = {}, volume = volume}
    for _, point in ipairs(own(id)) do
        if point.at >= time() - days * 86400 and (volume or point.price) then
            result.points[#result.points + 1] = {at = point.at, price = volume and point.lots or point.price,
                quartile = volume and point.units or point.price}
        end
    end
    if ns.Shared then result.points = ns.Shared.Merge(id, result.points, days, volume) end
    return result
end
function A.Board(id, days)
    local now = time()
    local list = {}
    for _, point in ipairs(own(id)) do
        if point.at >= now - days * 86400 and point.at <= now then list[#list + 1] = point end
    end
    if ns.Shared then
        local volume, merged = {}, {}
        for _, point in ipairs(ns.Shared.Merge(id, {}, days, true)) do volume[point.at] = point end
        for _, point in ipairs(ns.Shared.Merge(id, list, days)) do
            if point.shared then
                local supply = volume[point.at]
                point = {at = point.at, price = point.price, p25 = point.quartile, shared = true,
                    lots = supply and supply.price, units = supply and supply.quartile}
            end
            merged[#merged + 1] = point
        end
        list = merged
    end
    local board = {id = id, days = days, points = list, quote = ns.Markets.Quote(id), count = 0, changes = 0,
        compared = 0, added = 0, addedUnits = 0, early = 0, earlyUnits = 0, late = 0, lateUnits = 0,
        from = list[1] and list[1].at or now - days * 86400, to = math.max(now, list[#list] and list[#list].at or now)}
    local prices, daily = {}, {}
    for _, point in ipairs(list) do
        if point.price then
            prices[#prices + 1] = point.price
            daily[math.floor(point.at / 86400)] = point.price
            board.first, board.last = board.first or point, point
        end
        if point.units then board.supplyFirst, board.supply = board.supplyFirst or point, point end
        if point.gone then
            board.compared = board.compared + 1
            board.added, board.addedUnits = board.added + point.added, board.addedUnits + point.addedUnits
            board.early, board.earlyUnits = board.early + point.early, board.earlyUnits + (point.earlyUnits or 0)
            board.late = board.late + point.gone - point.early
            board.lateUnits = board.lateUnits + point.goneUnits - (point.earlyUnits or 0)
        end
    end
    table.sort(prices)
    local n = #prices
    board.count = n
    if n == 0 then return board end
    board.low, board.high = prices[1], prices[n]
    board.median = (prices[math.floor((n + 1) / 2)] + prices[math.ceil((n + 1) / 2)]) / 2
    local returns, sum = {}, 0
    for day, price in pairs(daily) do
        if daily[day - 1] and daily[day - 1] > 0 then
            local r = price / daily[day - 1] - 1
            returns[#returns + 1], sum = r, sum + r
        end
    end
    board.changes = #returns
    if #returns >= 3 then
        local variance = 0
        for _, r in ipairs(returns) do variance = variance + (r - sum / #returns) ^ 2 end
        board.volatility = math.sqrt(variance / (#returns - 1)) * 100
    end
    return board
end
function A.Buckets(board, count)
    local span, buckets = math.max(1, board.to - board.from), {}
    for _, point in ipairs(board.points) do
        local index = math.min(count, math.max(1, math.floor((point.at - board.from) / span * count) + 1))
        local b = buckets[index]
        if not b then
            b = {index = index, points = 0, compared = 0, added = 0, addedUnits = 0, early = 0, earlyUnits = 0,
                late = 0, lateUnits = 0}
            buckets[index] = b
        end
        b.points, b.at = b.points + 1, point.at
        if point.price then b.price = math.min(b.price or point.price, point.price) end
        if point.p25 or point.price then b.p25 = math.min(b.p25 or math.huge, point.p25 or point.price) end
        if point.units then b.units, b.lots = point.units, point.lots end
        if point.shared then b.shared = true end
        if point.gone then
            b.compared = b.compared + 1
            b.added, b.addedUnits = b.added + point.added, b.addedUnits + point.addedUnits
            b.early, b.earlyUnits = b.early + point.early, b.earlyUnits + (point.earlyUnits or 0)
            b.late = b.late + point.gone - point.early
            b.lateUnits = b.lateUnits + point.goneUnits - (point.earlyUnits or 0)
        end
    end
    return buckets
end
function A.Candles(board, shift)
    local byDay, order = {}, {}
    for _, point in ipairs(board.points) do
        if point.price then
            local day = math.floor((point.at + shift) / 86400)
            local candle = byDay[day]
            if not candle then
                candle = {day = day, at = day * 86400 - shift + 43200, open = point.price, close = point.price,
                    high = point.p25 or point.price, low = point.price, points = 0}
                byDay[day] = candle
                order[#order + 1] = candle
            end
            candle.close = point.price
            candle.high = math.max(candle.high, point.p25 or point.price, point.price)
            candle.low = math.min(candle.low, point.price)
            candle.points = candle.points + 1
        end
    end
    table.sort(order, function(a, b) return a.day < b.day end)
    return order
end
local function groups(observation)
    local lots = ns.Markets.Lots(observation)
    if not lots then return nil end
    local result = {}
    for _, lot in ipairs(lots) do
        if lot.buyout > 0 and lot.count > 0 then
            if lot.owner == "" then return nil end
            local key = table.concat({lot.item, lot.suffix, lot.count, lot.minBid, lot.buyout, lot.owner}, ":")
            local entry = result[key] or {lots = 0, stack = lot.count, earliest = math.huge}
            local minimum = ({0, 1800, 7200, 43200})[lot.timeLeft] or 0
            entry.earliest = math.min(entry.earliest, (observation.since or observation.at) + minimum)
            entry.lots = entry.lots + 1
            result[key] = entry
        end
    end
    return result
end
function A.Compare(previous, current)
    if not previous or not current or not previous.complete or not current.complete
        or previous.truncated or current.truncated or #(previous.rows or {}) >= 500 or #(current.rows or {}) >= 500
        or previous.scope ~= current.scope or previous.at > (current.since or current.at) then return nil end
    if current.scope ~= "item" and current.scope ~= "family" and current.scope ~= "market" then return nil end
    local before, after = groups(previous), groups(current)
    if not before or not after then return nil end
    local result = {from = previous.at, at = current.at, added = 0, gone = 0, beforeExpiry = 0,
        expiryPossible = 0, addedUnits = 0, goneUnits = 0, beforeExpiryUnits = 0, expiryPossibleUnits = 0,
        oldUnits = previous.units, units = current.units}
    for key, old in pairs(before) do
        local missing = math.max(0, old.lots - (after[key] and after[key].lots or 0))
        result.gone, result.goneUnits = result.gone + missing, result.goneUnits + missing * old.stack
        local reason = current.at < old.earliest and "beforeExpiry" or "expiryPossible"
        result[reason] = result[reason] + missing
        result[reason .. "Units"] = result[reason .. "Units"] + missing * old.stack
    end
    for key, entry in pairs(after) do
        local added = math.max(0, entry.lots - (before[key] and before[key].lots or 0))
        result.added, result.addedUnits = result.added + added, result.addedUnits + added * entry.stack
    end
    return result
end
function A.Recent(id)
    local item = ns.Markets.Item(id)
    local current = item and item.observations[item.quote.scanID]
    if not current then return nil end
    for i = #item.order, 1, -1 do
        local scanID = item.order[i]
        if scanID ~= item.quote.scanID then
            local result = A.Compare(item.observations[scanID], current)
            if result then return result end
        end
    end
    return nil
end
