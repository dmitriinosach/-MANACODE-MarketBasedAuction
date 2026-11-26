local _, ns = ...
local O = {}
ns.Offers = O
O.FRESH = 60
function O.Me()
    return UnitName and UnitName("player") or nil
end
function O.Foreign(lot, me)
    return lot.owner ~= (me or O.Me())
end
function O.Accept(lot, opts)
    local me, bid
    if type(opts) == "string" then me = opts elseif opts then me, bid = opts.me, opts.bid end
    if (lot.count or 0) <= 0 or not O.Foreign(lot, me) then return false end
    return (lot.buyout or 0) > 0 or bid == true
end
function O.Sort(offers)
    table.sort(offers, function(a, b)
        if a.buyout * b.stack ~= b.buyout * a.stack then return a.buyout * b.stack < b.buyout * a.stack end
        return a.buyout < b.buyout
    end)
    return offers
end
function O.Add(item, lot)
    local key = lot.count .. ":" .. lot.buyout
    local offer = item.groups[key]
    if not offer then
        offer = {stack = lot.count, buyout = lot.buyout, count = 0, page = 0, item = lot.item, owners = {}}
        item.groups[key] = offer
        item.offers[#item.offers + 1] = offer
    end
    offer.count = offer.count + 1
    local owner = lot.owner or ""
    offer.owners[owner] = (offer.owners[owner] or 0) + 1
    return offer
end
function O.Collect(lots, opts)
    opts = opts or {}
    local me = opts.me or O.Me()
    local items, byID = {}, {}
    for _, entry in ipairs(lots or {}) do
        local lot = type(entry) == "string" and ns.Lot.Decode(entry) or entry
        if lot and (not opts.item or lot.item == opts.item) and O.Accept(lot, me) then
            local item = byID[lot.item]
            if not item then
                item = {id = lot.item, offers = {}, groups = {}}
                byID[lot.item], items[#items + 1] = item, item
            end
            O.Add(item, lot)
        end
    end
    for _, item in ipairs(items) do O.Sort(item.offers) end
    return items, byID
end
function O.Group(lots, opts)
    local items = O.Collect(lots, opts)
    return items[1] and items[1].offers or {}
end
function O.Merge(into, offers)
    into.groups = into.groups or {}
    for _, offer in ipairs(into.offers) do into.groups[offer.stack .. ":" .. offer.buyout] = offer end
    for _, offer in ipairs(offers) do
        local same = into.groups[offer.stack .. ":" .. offer.buyout]
        if same then
            same.count = same.count + offer.count
            for owner, lots in pairs(offer.owners or {}) do
                same.owners = same.owners or {}
                same.owners[owner] = (same.owners[owner] or 0) + lots
            end
        else
            into.groups[offer.stack .. ":" .. offer.buyout] = offer
            into.offers[#into.offers + 1] = offer
        end
    end
    O.Sort(into.offers)
end
function O.Summary(offers)
    local units, lots = 0, 0
    for _, offer in ipairs(offers) do units, lots = units + offer.stack * offer.count, lots + offer.count end
    local first = offers[1]
    return first and math.floor(first.buyout / first.stack) or nil, units, lots
end
function O.Sellers(offer)
    local names = {}
    for owner in pairs(offer.owners or {}) do names[#names + 1] = owner end
    table.sort(names, function(a, b)
        local la, lb = offer.owners[a], offer.owners[b]
        if la ~= lb then return la > lb end
        return a < b
    end)
    local lines = {}
    for i, owner in ipairs(names) do
        lines[i] = ns.T("buySellerLots", owner ~= "" and owner or ns.T("cacheUnknownSeller"), offer.owners[owner])
    end
    return lines
end
function O.Stored(id)
    local lots, observation = ns.Markets.Offers(id)
    return O.Group(lots, {item = id}), observation
end
function O.StoredAge(id)
    local _, observation = ns.Markets.Offers(id)
    if not observation or observation.lost or not observation.at then return nil end
    return math.max(0, time() - observation.at)
end
function O.Fresh(id, seconds)
    local age = O.StoredAge(id)
    return age ~= nil and age <= (seconds or O.FRESH), age
end
