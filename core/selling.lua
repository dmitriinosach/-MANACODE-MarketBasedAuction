local _, ns = ...
local Sell = {}
ns.Selling = Sell
Sell.FLOW_DAYS = 7
Sell.PACKS = 6
Sell.COMMON = {20, 100}
Sell.BETTER = 0.05
Sell.WAYS = 8
function Sell.Owned()
    local list = {}
    if not GetNumAuctionItems then return list, 0 end
    local count, total = GetNumAuctionItems("owner")
    for index = 1, count or 0 do
        local name, _, stack, _, _, _, minBid, _, buyout, bid, _, _, saleStatus = GetAuctionItemInfo("owner", index)
        local link = GetAuctionItemLink("owner", index)
        local id = ns.Lot.FromLink(link)
        if name and id then
            stack = math.max(1, stack or 1)
            buyout = buyout or 0
            list[#list + 1] = {index = index, id = id, link = link, name = name, count = stack, minBid = minBid or 0,
                buyout = buyout, bid = bid or 0, unit = buyout > 0 and buyout / stack or nil,
                timeLeft = GetAuctionItemTimeLeft("owner", index) or 0, sold = saleStatus == 1,
                canCancel = saleStatus ~= 1 and (not CanCancelAuction or CanCancelAuction(index) and true or false)}
        end
    end
    return list, total or #list
end
function Sell.Standing(auction, wall)
    wall = wall or ns.Posting.Wall(auction.id)
    local result = {state = "first", lots = 0, units = 0, lowest = wall.lowest, at = wall.at}
    if auction.sold then result.state = "sold"
    elseif not auction.unit then result.state = "nobuyout"
    elseif type(ns.Posting.ItemKey(auction.link)) == "string" then result.state, result.at = "noscan", nil
    elseif not wall.at then result.state = "noscan"
    elseif not wall.lowest then result.state = "alone"
    else
        local lots, units, same = ns.Posting.Ahead(wall, auction.unit)
        result.lots, result.units = lots, units
        if lots > 0 then result.state = "undercut" elseif same > 0 then result.state = "tie" end
    end
    return result
end
function Sell.OwnedRows()
    local auctions, total = Sell.Owned()
    local walls, rows = {}, {}
    for _, auction in ipairs(auctions) do
        walls[auction.id] = walls[auction.id] or ns.Posting.Wall(auction.id)
        rows[#rows + 1] = {auction = auction, standing = Sell.Standing(auction, walls[auction.id])}
    end
    return rows, total
end
function Sell.OwnedByItem()
    local byItem = {}
    for _, row in ipairs(Sell.OwnedRows()) do
        local id = ns.Posting.ItemKey(row.auction.link) or row.auction.id
        local entry = byItem[id] or {active = 0, undercut = 0, sold = 0}
        byItem[id] = entry
        if row.auction.sold then entry.sold = entry.sold + 1
        else
            entry.active = entry.active + 1
            if row.standing.state == "undercut" then entry.undercut = entry.undercut + 1 end
        end
    end
    return byItem
end
local function bySkill(way)
    local rank = ns.Recipes.Rank(way.profession)
    way.rank = rank or nil
    if rank and rank >= way.skill then way.able = "self"; return end
    for _, owner in ipairs(ns.Recipes.Professions()[way.profession] or {}) do
        if not owner.me and (owner.rank or 0) >= way.skill then way.able, way.alt = "alt", owner.name; return end
    end
    if rank == nil then way.able, way.reason = "unknown", "sellWayUnchecked"
    else way.able, way.reason = "no", rank and "sellWaySkill" or "sellWayNoProfession" end
end
local function byRecipe(way, spell)
    local known = ns.Recipes.Known(spell, way.profession)
    if known then way.able = "self"; return end
    for _, owner in ipairs(ns.Recipes.KnownBy(spell, way.profession)) do
        if not owner.me and owner.known and not owner.other then way.able, way.alt = "alt", owner.name; return end
    end
    if known == false then way.able, way.reason = "no", "sellWayNotLearned"
    elseif ns.Recipes.Rank(way.profession) == false then way.able, way.reason = "no", "sellWayNoProfession"
    else way.able, way.reason = "unknown", "sellWayUnchecked" end
end
local function shortfall(way, recipe, id, bags)
    way.buy, way.short = 0, 0
    for _, input in ipairs(recipe.inputs or {}) do
        local need = input[1] ~= id and input[2] - (bags[input[1]] and bags[input[1]].count or 0) or 0
        if need > 0 then
            local q = ns.Markets.Quote(input[1])
            way.short = way.short + need
            way.buy = way.buy and q and q.price and way.buy + need * q.price or nil
        end
    end
end
function Sell.Ways(id, fee, count, link, variant, bags)
    bags = bags or ns.Posting.Bags()
    local sell, list = ns.Reagents.Next(id, fee, Sell.WAYS)
    if variant then sell = nil end
    local ways = {}
    for _, entry in ipairs(list) do
        local way = {entry = entry, gain = not variant and entry.gain or nil, step = 1, short = 0}
        if entry.recipe then
            way.kind, way.id, way.step = "craft", entry.recipe.raw, entry.count or 1
            local catalog = ns.craftCatalogs[entry.recipe.profession]
            way.profession = catalog and ns.T(catalog.labelKey)
            byRecipe(way, entry.recipe.spell)
            shortfall(way, entry.recipe, id, bags)
        elseif entry.source then
            way.kind, way.id, way.step = "process", id, entry.count or ns.Prospect.OPERATION
            way.profession = ns.T(entry.mode == "mill" and ns.craftCatalogs.inscription.labelKey or "jewelrySection")
            way.skill = entry.source.skill or 1
            bySkill(way)
        elseif entry.offer then
            way.kind, way.id, way.step, way.able = "exchange", entry.offer.itemID, entry.count or 1, "self"
        else
            local pair = entry.pair
            way.kind, way.able = "recycle", "self"
            way.id, way.step = id == pair.big and pair.small or pair.big, id == pair.small and pair.ratio or 1
        end
        way.value = sell and way.gain and sell + way.gain
        ways[#ways + 1] = way
    end
    local candidate = ns.Disenchant.Candidate(id, link)
    local band = candidate and ns.Disenchant.Band(candidate.band)
    if band then
        local estimate = ns.Disenchant.Estimate(band, 0, fee)
        local way = {kind = "disenchant", band = band, id = ns.Disenchant.MainOutput(band).itemID, step = 1, short = 0,
            profession = ns.T(ns.craftCatalogs.enchanting.labelKey), skill = candidate.skill or 1, value = estimate.net}
        way.gain = sell and estimate.net and estimate.net - sell or nil
        bySkill(way)
        ways[#ways + 1] = way
    end
    for i, way in ipairs(ways) do
        way.index = i
        way.units = math.floor(count / way.step) * way.step
        way.total = way.gain and way.units > 0 and math.floor(way.gain * way.units) or nil
    end
    table.sort(ways, function(a, b)
        if a.gain ~= b.gain then
            if a.gain == nil then return false end
            if b.gain == nil then return true end
            return a.gain > b.gain
        end
        return a.index < b.index
    end)
    for i = #ways, Sell.WAYS + 1, -1 do ways[i] = nil end
    return sell, ways
end
function Sell.Best(ways, sell)
    if not sell or sell <= 0 then return nil end
    local best
    for _, way in ipairs(ways) do
        if way.able == "self" and way.gain and way.units > 0 and way.gain >= sell * Sell.BETTER
            and (not best or way.gain > best.gain) then best = way end
    end
    return best
end
function Sell.WayGap(id, way)
    if way.entry then
        local _, ids = ns.Reagents.Gap(id, way.entry)
        return ids
    end
    local ids = {id}
    for _, output in ipairs(way.band.outputs) do ids[#ids + 1] = output.itemID end
    return ids
end
local function character()
    return (GetRealmName() or "") .. "|" .. (UnitFactionGroup("player") or "") .. "|" .. (UnitName("player") or "")
end
local function bagCounts()
    local counts = {}
    if not GetContainerItemLink then return counts end
    for bag = 0, 4 do
        for slot = 1, ns.Compat.BagSlots(bag) or 0 do
            local key = ns.Posting.ItemKey(GetContainerItemLink(bag, slot))
            if key then counts[key] = (counts[key] or 0) + (select(2, ns.Compat.BagItemIcon(bag, slot)) or 1) end
        end
    end
    return counts
end
function Sell.Track(now)
    now = now or time()
    local db = ns.Store.DB()
    db.bagSeen = db.bagSeen or {}
    local me = character()
    local seen = db.bagSeen[me] or {}
    db.bagSeen[me] = seen
    local counts = bagCounts()
    for key, count in pairs(counts) do
        local entry = seen[key]
        if not entry then seen[key] = {first = now, at = now, count = count}
        elseif entry.count ~= count then entry.count, entry.at = count, now end
    end
    for key in pairs(seen) do if not counts[key] then seen[key] = nil end end
    return seen
end
function Sell.BagRows(fee)
    local owned = Sell.OwnedByItem()
    local rows, project, bags, seen = {}, ns.Accounting.Project(), ns.Posting.Bags(), Sell.Track()
    for key, entry in pairs(ns.Posting.BagVariants()) do
        local id, variant = entry.id, type(key) == "string"
        local q = ns.Markets.Quote(id, true)
        local complete = q and q.complete ~= false and (q.miss or 0) == 0
        local price = not variant and complete and q.price or nil
        local mine = owned[key]
        local sell, ways = Sell.Ways(id, fee, entry.count, entry.link, variant, bags)
        local name, _, quality = ns.Compat.ItemInfo(entry.link)
        rows[#rows + 1] = {id = id, key = key, link = entry.link,
            name = name or ns.Markets.Name(id), quality = quality, count = entry.count,
            first = seen[key] and seen[key].first, changed = seen[key] and seen[key].at,
            cost = not variant and ns.Posting.Cost(id, 0, project) or nil,
            market = price, net = price and price * (1 - fee),
            value = price and math.floor(price * entry.count * (1 - fee)), complete = price ~= nil,
            at = not variant and q and q.at or nil,
            priceState = variant and "variant" or price and "priced" or (complete and q.lots == 0 and "empty" or "unknown"),
            active = mine and mine.active or 0, undercut = mine and mine.undercut or 0,
            ways = ways, sell = sell, best = Sell.Best(ways, sell)}
    end
    table.sort(rows, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return tostring(a.key) < tostring(b.key)
    end)
    return rows
end
function Sell.Flow(id, days)
    days = days or Sell.FLOW_DAYS
    local board = ns.Activity.Board(id, days)
    local flow = {days = days, compared = board.compared, early = board.early, earlyUnits = board.earlyUnits,
        median = board.median, supply = board.supply and board.supply.units, lots = board.supply and board.supply.lots}
    local first, last
    for _, point in ipairs(board.points) do
        if point.gone then
            first = first or (point.from or point.at)
            last = point.at
        end
    end
    if first and last and last > first then
        flow.hours = (last - first) / 3600
        if flow.hours >= 24 then flow.perDay = flow.earlyUnits / (flow.hours / 24) end
    end
    return flow
end
function Sell.StackSize(id)
    local name, _, _, _, _, _, _, limit = ns.Compat.ItemInfo(id)
    if not name then
        ns.Compat.RequestItem(id, Sell.Changed)
        return nil
    end
    return type(limit) == "number" and limit > 0 and limit or 1
end
function Sell.Packs(id, fee)
    local limit = Sell.StackSize(id)
    if not limit then return {}, nil end
    if limit < 2 then return {}, limit end
    local bySize, list = {}, {}
    local function pack(size, bulk)
        if size < 2 or (size > limit and (not bulk or size % limit ~= 0)) then return nil end
        local entry = bySize[size]
        if not entry then
            entry = {size = size, stack = math.min(size, limit), count = math.ceil(size / limit),
                uses = {}, lots = 0, best = false, common = false, full = false}
            bySize[size], list[#list + 1] = entry, entry
        end
        return entry
    end
    for _, use in ipairs(ns.Reagents.Demands(id, fee)) do
        local entry = use.count and pack(use.count)
        if entry and #entry.uses < 3 then
            local name = ns.Reagents.UseName(use)
            local seen = false
            for _, known in ipairs(entry.uses) do if known == name then seen = true end end
            if not seen then entry.uses[#entry.uses + 1] = name end
        end
    end
    local fixed = 0
    for _, size in ipairs(Sell.COMMON) do
        local entry = pack(size, true)
        if entry then entry.common = true; fixed = fixed + 1 end
    end
    local full = pack(limit)
    if full then
        if not full.common then fixed = fixed + 1 end
        full.full = true
    end
    local stacks, best = ns.Recycle.Stacks(id)
    for _, stack in ipairs(stacks) do
        local entry = bySize[stack.size] or (stack.lots >= 2 and pack(stack.size)) or nil
        if entry then
            entry.lots, entry.premium = stack.lots, stack.premium
            entry.best = best ~= nil and best.size == stack.size
        end
    end
    table.sort(list, function(a, b)
        if (#a.uses > 0) ~= (#b.uses > 0) then return #a.uses > 0 end
        if a.lots ~= b.lots then return a.lots > b.lots end
        return a.size < b.size
    end)
    local result, room = {}, Sell.PACKS - fixed
    for _, entry in ipairs(list) do
        if entry.common or entry.full then result[#result + 1] = entry
        elseif room > 0 then result[#result + 1] = entry; room = room - 1 end
    end
    table.sort(result, function(a, b) return a.size < b.size end)
    return result, limit
end
function Sell.Cancel(auction)
    if not ns.Scan.state.open or not CancelAuction then return false, "postNoAuction" end
    local name, _, count, _, _, _, _, _, buyout, _, _, _, saleStatus = GetAuctionItemInfo("owner", auction.index)
    local link = GetAuctionItemLink("owner", auction.index)
    local id = ns.Lot.FromLink(link)
    if not name or id ~= auction.id or math.max(1, count or 1) ~= auction.count or (buyout or 0) ~= auction.buyout then
        return false, "sellCancelMoved"
    end
    if auction.link and ns.Posting.ItemKey(link) ~= ns.Posting.ItemKey(auction.link) then return false, "sellCancelMoved" end
    if saleStatus == 1 or (CanCancelAuction and not CanCancelAuction(auction.index)) then return false, "sellCancelSold" end
    CancelAuction(auction.index)
    return true
end
function Sell.ScanIds(view)
    local ids, seen = {}, {}
    if view == "owned" then
        for _, auction in ipairs(Sell.Owned()) do
            if not seen[auction.id] then seen[auction.id] = true; ids[#ids + 1] = auction.id end
        end
    else
        for _, row in ipairs(Sell.BagRows(ns.Fee())) do
            if not seen[row.id] then
                seen[row.id] = true
                ids[#ids + 1] = ns.vendorPrices and ns.vendorPrices[row.id] and {id = row.id, auction = true} or row.id
            end
        end
    end
    return ids
end
function Sell.Changed()
    if Sell.onChange then Sell.onChange() end
end
local function trackNextFrame(f)
    f:SetScript("OnUpdate", nil)
    Sell.Track()
end
local frame = ns.NewFrame("Frame")
ns.Listen(frame, "AUCTION_OWNED_LIST_UPDATE")
ns.Listen(frame, "PLAYER_ENTERING_WORLD")
ns.Listen(frame, "BAG_UPDATE")
frame:SetScript("OnEvent", function(f, event)
    if event == "AUCTION_OWNED_LIST_UPDATE" then return Sell.Changed() end
    if event == "PLAYER_ENTERING_WORLD" then Sell.ready = true end
    if Sell.ready then f:SetScript("OnUpdate", trackNextFrame) end
end)
