local _, ns = ...
local Bids = {mine = {}, placed = {}}
ns.Bids = Bids
local RANGES = {{0, 1800}, {1800, 7200}, {7200, 43200}, {43200, 172800}}
Bids.RANGES = RANGES
function Bids.Risk(left, expires, now)
    if expires and now >= expires then return "ended" end
    return (left or 4) <= 2 and "short" or "long"
end
function Bids.OfferExpires(offer, now)
    return offer.expiresMax or (offer.seenAt or now) + RANGES[4][2]
end
Bids.RANK = {short = 1, long = 2, ended = 3}
function Bids.Before(a, b, now)
    local ra, rb = Bids.RANK[Bids.Risk(a.left, a.expires, now)], Bids.RANK[Bids.Risk(b.left, b.expires, now)]
    if ra ~= rb then return ra < rb end
    if (a.profit or 0) ~= (b.profit or 0) then return (a.profit or 0) > (b.profit or 0) end
    return a.expires < b.expires
end
local function chanceKey(lot)
    return ns.Lot.Key(lot.item, lot.suffix, lot.count, lot.buyout, lot.owner) .. ":" .. lot.minBid .. ":" .. lot.bid
end
function Bids.Next(lot, me)
    if not lot or lot.count <= 0 or lot.owner == "" or lot.owner == me then return nil end
    local next = ns.Bargain.NextBid(lot)
    if next <= 0 or (lot.buyout > 0 and next >= lot.buyout) then return nil end
    return next
end
local function snapshots()
    local seen, shots = {}, {}
    for i = #(ns.Store.DB().scans or {}), 1, -1 do
        local key = ns.Store.DB().scans[i].deGroup
        if key and not seen[key] then
            seen[key] = true
            shots[key] = ns.Disenchant.Snapshot(key)
        end
    end
    for key in pairs(ns.Store.DB().disenchantDrafts or {}) do
        if not seen[key] then shots[key] = ns.Disenchant.Snapshot(key) end
    end
    return shots
end
local function selling()
    local view = ns.DisenchantUI
    return view and view.selling
end
local function fromDisenchant(list, seen, fee)
    local D, me, memo = ns.Disenchant, UnitName("player"), {}
    for group, scan in pairs(snapshots()) do
        local at = scan.t + (scan.secs or 0)
        for _, text in ipairs(scan.lots or {}) do
            local lot = ns.Lot.Decode(text)
            local meta = lot and scan.disenchantItems and scan.disenchantItems[lot.item]
            local next = meta and Bids.Next(lot, me)
            if next then
                local range = RANGES[lot.timeLeft] or RANGES[4]
                local key = chanceKey(lot)
                if not seen[key] then
                    seen[key] = true
                    local unit = next / lot.count
                    local estimate = D.Estimate(D.Band(meta.band), unit, fee, nil, selling(), memo)
                    local chance = {key = key, buyKey = ns.Lot.Key(lot.item, lot.suffix, lot.count, lot.buyout, lot.owner),
                        source = "disenchant", group = group, item = lot.item, lot = lot, cost = next, unit = unit,
                        estimate = estimate, seen = at, left = lot.timeLeft, expires = at + range[2],
                        expiresMin = scan.t + range[1], scanID = scan.id}
                    if estimate.net then
                        chance.value = estimate.net * lot.count
                        chance.profit = chance.value - next
                        chance.percent = chance.profit / next * 100
                    end
                    list[#list + 1] = chance
                end
            end
        end
    end
end
local function fromBargain(list, seen, now, fee)
    local B = ns.Bargain
    local percent = ns.BargainUI and ns.BargainUI.props and ns.BargainUI.props.percent or B.PERCENT
    for _, row in ipairs(B.Rows("deals", {percent = percent, fee = fee, now = now})) do
        local deal = row.deal
        local lot = deal and deal.kind == "bid" and deal.lot
        if lot and not seen[deal.key] then
            seen[deal.key] = true
            local at = lot.seenAt or row.checked or now
            list[#list + 1] = {key = deal.key, buyKey = deal.buyKey, source = "bargain", item = row.id, lot = lot,
                name = B.Name(row.entry),
                cost = deal.cost, unit = deal.unit, value = deal.resale.revenue, profit = deal.profit,
                percent = deal.profit / deal.cost * 100, deal = deal, seen = at, left = lot.timeLeft,
                expires = Bids.OfferExpires(lot, at), expiresMin = lot.expiresMin or at, scanID = row.scanID}
        end
    end
end
local cached
function Bids.All(now)
    now = now or time()
    local scans = ns.Store.DB().scans or {}
    local last = scans[#scans]
    local sig = table.concat({#scans, last and last.id or "", math.floor(now / 60), ns.Fee(), Bids.revision or 0,
        ns.Bargain.revision or 0, UnitName("player") or ""}, "|")
    if cached and cached.sig == sig then return cached.list end
    local list, seen, fee = {}, {}, ns.Fee()
    local mine = {}
    for _, bid in ipairs(Bids.mine) do mine[bid.key] = true end
    fromDisenchant(list, seen, fee)
    fromBargain(list, seen, now, fee)
    local kept = {}
    for _, chance in ipairs(list) do
        if not mine[chance.buyKey] and (not Bids.placed[chance.key] or Bids.placed[chance.key] ~= chance.scanID) then
            kept[#kept + 1] = chance
        end
    end
    cached = {sig = sig, list = kept, now = now}
    return kept
end
function Bids.Chances(now)
    now = now or time()
    local list = {}
    for _, chance in ipairs(Bids.All(now)) do
        if chance.profit and chance.profit > 0 then list[#list + 1] = chance end
    end
    table.sort(list, function(a, b) return Bids.Before(a, b, now) end)
    return list
end
function Bids.ForItem(item, now)
    local list = Bids.All(now)
    if cached.byItem == nil then
        local byItem = {}
        for _, chance in ipairs(list) do
            local entry = byItem[chance.item] or {}
            byItem[chance.item] = entry
            if not entry.cheapest or chance.unit < entry.cheapest.unit then entry.cheapest = chance end
            if chance.profit and chance.profit > 0 and (not entry.best or Bids.Before(chance, entry.best, cached.now)) then
                entry.best = chance
            end
        end
        cached.byItem = byItem
    end
    local entry = cached.byItem[item]
    if not entry then return nil, nil end
    return entry.cheapest, entry.best
end
function Bids.Find(key, now)
    for _, chance in ipairs(Bids.All(now)) do if chance.key == key then return chance end end
    return nil
end
function Bids.Active()
    return Bids.job ~= nil and ns.Buy.Active()
end
function Bids.Place(chance)
    if ns.Buy.Active() then
        if Bids.job and Bids.job.key == chance.key then return ns.Buy.Confirm() end
        ns.say(ns.T("bidsBusy"), "bad")
        return false
    end
    local lot = chance.lot
    local offer = {key = chance.buyKey, item = chance.item, suffix = lot.suffix, owner = lot.owner, stack = lot.count,
        buyout = lot.buyout, count = 1, page = 0}
    local plan = ns.Plan.Recount({kind = "manual", need = lot.count, picks = {{offer = offer, lots = 1}}})
    Bids.job = {key = chance.key, scanID = chance.scanID, offer = offer, source = chance.source, seen = chance.seen,
        ended = Bids.Risk(chance.left, chance.expires, time()) == "ended"}
    local started = ns.Buy.Start(chance.name or ns.Markets.Name(chance.item), plan, chance.item,
        ns.Bargain.BidGuard(offer, chance.cost), {lookup = {[chance.buyKey] = offer}, bid = true})
    if not started then Bids.job = nil end
    return started
end
function Bids.Cancel()
    Bids.job, Bids.raise = nil, nil
    return ns.Buy.Stop()
end
function Bids.BuyChanged()
    local job = Bids.job
    if job and not ns.Buy.Active() then
        if job.ended and job.offer.count > 0 and ns.Buy.state.stopKey == "sayBuyShort" then
            ns.say(ns.T("bidsGone", ns.TradeKit.Ago(math.max(0, time() - job.seen))), "bad")
        end
        if job.offer.count == 0 then
            Bids.placed[job.key] = job.scanID or ""
            if job.source == "bargain" then ns.Bargain.placed[job.key] = job.scanID end
            Bids.revision = (Bids.revision or 0) + 1
            Bids.Request()
        end
        Bids.job = nil
    end
    if Bids.onChange then Bids.onChange() end
end
function Bids.Request()
    if not ns.Scan.state.open or not GetBidderAuctionItems then return false end
    GetBidderAuctionItems()
    return true
end
function Bids.ReadMine()
    local mine, count = {}, GetNumAuctionItems and GetNumAuctionItems("bidder") or 0
    for index = 1, count do
        local name, _, stack, _, _, _, minBid, increment, buyout, bid, high, owner = GetAuctionItemInfo("bidder", index)
        if name then
            local link = GetAuctionItemLink and GetAuctionItemLink("bidder", index)
            local item, suffix = ns.Lot.FromLink(link)
            stack, bid, buyout = stack or 1, bid or 0, buyout or 0
            local next = bid > 0 and bid + math.max(1, increment or 0) or (minBid or 0)
            mine[#mine + 1] = {key = ns.Lot.Key(item or 0, suffix or 0, stack, buyout, owner or ""), index = index,
                item = item, link = link, name = name, count = stack, bid = bid, next = next, buyout = buyout,
                high = high and true or false, owner = owner,
                timeLeft = GetAuctionItemTimeLeft and GetAuctionItemTimeLeft("bidder", index) or nil}
        end
    end
    table.sort(mine, function(a, b)
        if a.high ~= b.high then return not a.high end
        return (a.timeLeft or 9) < (b.timeLeft or 9)
    end)
    Bids.mine, Bids.mineAt = mine, time()
    Bids.revision = (Bids.revision or 0) + 1
    if Bids.raise then
        local still
        for _, bid in ipairs(mine) do if bid.key == Bids.raise.key and not bid.high then still = bid end end
        if not still or still.next ~= Bids.raise.amount then Bids.raise = nil end
    end
    if Bids.onChange then Bids.onChange() end
end
function Bids.Raise(bid)
    if bid.high or (bid.buyout > 0 and bid.next >= bid.buyout) then return false end
    local raise = Bids.raise
    if not raise or raise.key ~= bid.key or raise.amount ~= bid.next then
        Bids.raise = {key = bid.key, amount = bid.next}
        if Bids.onChange then Bids.onChange() end
        return false
    end
    Bids.raise = nil
    if not ns.Scan.state.open or ns.Buy.Active() then return false end
    local name, _, _, _, _, _, _, increment, buyout, current, high = GetAuctionItemInfo("bidder", bid.index)
    local next = (current or 0) > 0 and current + math.max(1, increment or 0) or nil
    if name ~= bid.name or high or (buyout or 0) ~= bid.buyout or (next and next ~= bid.next) or GetMoney() < bid.next then
        ns.say(ns.T("bidsChanged"), "bad")
        Bids.Request()
        return false
    end
    PlaceAuctionBid("bidder", bid.index, bid.next)
    Bids.Request()
    if Bids.onChange then Bids.onChange() end
    return true
end
local previous = ns.Buy.onChange
ns.Buy.onChange = function()
    if previous then previous() end
    Bids.BuyChanged()
end
local events = ns.NewFrame("Frame")
ns.Listen(events, "AUCTION_BIDDER_LIST_UPDATE")
ns.Listen(events, "AUCTION_HOUSE_CLOSED")
events:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_CLOSED" then Bids.raise = nil; return end
    Bids.ReadMine()
end)
