local _, ns = ...
local B = {}
ns.Bargain = B
B.PERCENT = 20
B.LIMIT = 60
B.HISTORY_DAYS = 30
B.HISTORY_MIN = 3
B.MIN_LOTS = 3
B.MIN_SELLERS = 2
B.SPREAD = 3
B.HOURS = 12
B.GROUPS = {"deals", "gear", "mounts", "recipes", "reagents", "own", "off"}
B.onChange = nil
function B.IsFull(scan)
    return scan.scope ~= "disenchant" and scan.scope ~= "gems" and not scan.itemID and not scan.family
        and (not scan.query or scan.query == "") and (scan.miss or 0) == 0 and scan.complete ~= false
        and not scan.truncated and not (scan.mode == "all" and (scan.expect or 0) > scan.total)
        and #scan.lots > 0
end
local function saved()
    local db = ns.Store.DB()
    local w = db.bargainWatch
    if type(w) ~= "table" then w = {}; db.bargainWatch = w end
    for _, key in ipairs({"own", "off", "worth"}) do
        if type(w[key]) ~= "table" then w[key] = {} end
    end
    return w
end
B.revision = 0
local function changed()
    B.revision = B.revision + 1
end
local function validID(id)
    return type(id) == "number" and id >= 1 and id <= 2147483647 and id == math.floor(id)
end
local byID
local function dataByID()
    local source = ns.bargainWatch or {}
    if not byID or byID.source ~= source then
        byID = {source = source, items = {}}
        for _, entry in ipairs(source) do byID.items[entry.id] = entry end
    end
    return byID.items
end
function B.Entries()
    local w, faction = saved(), UnitFactionGroup("player")
    local list, seen = {}, {}
    for _, data in ipairs(ns.bargainWatch or {}) do
        local id = data.id
        local mine = w.own[id] == true
        if mine or ((not data.side or data.side == faction) and not ns.Markets.Catalog(id)
            and not (ns.vendorPrices and ns.vendorPrices[id])) then
            seen[id] = true
            list[#list + 1] = {id = id, group = data.group, from = data.from, ru = data.ru, en = data.en,
                own = mine or nil, off = w.off[id] == true or nil}
        end
    end
    for id in pairs(w.own) do
        if not seen[id] and validID(id) then list[#list + 1] = {id = id, group = "own", own = true, off = w.off[id] == true or nil} end
    end
    return list
end
function B.Name(entry)
    local name = ns.Compat.ItemInfo(entry.id)
    if name then return name end
    if GetLocale() == "ruRU" then return entry.ru or entry.en end
    return entry.en or entry.ru
end
function B.Warm(done)
    local asked = 0
    for _, entry in ipairs(B.Entries()) do
        if not entry.off and not ns.Compat.ItemInfo(entry.id) then
            ns.Compat.RequestItem(entry.id, done)
            asked = asked + 1
        end
    end
    return asked
end
function B.Add(input)
    local text = (input or ""):match("^%s*(.-)%s*$")
    if text == "" then return nil end
    local id = tonumber(text:match("^(%d+)$")) or tonumber(text:match("item:(%d+)"))
    if not id then
        local _, link = ns.Compat.ItemInfo(text)
        id = link and tonumber(link:match("item:(%d+)"))
    end
    if not id then
        for _, entry in ipairs(ns.bargainWatch or {}) do
            if entry.ru == text or entry.en == text then id = entry.id; break end
        end
    end
    if not id then
        for itemID, line in pairs(ns.Store.DB().items or {}) do
            if type(line) == "string" and line:match("^[^\t]+") == text then id = itemID; break end
        end
    end
    if not validID(id) then return nil end
    local w = saved()
    w.own[id], w.off[id] = true, nil
    ns.Compat.RequestItem(id)
    changed()
    return id
end
function B.Hide(id)
    local w = saved()
    if w.own[id] and not dataByID()[id] then w.own[id] = nil else w.own[id], w.off[id] = nil, true end
    changed()
end
function B.Show(id)
    saved().off[id] = nil
    changed()
end
function B.Worth(id)
    return saved().worth[id]
end
function B.SetWorth(id, copper)
    saved().worth[id] = (copper and copper > 0) and math.floor(copper) or nil
    changed()
end
function B.InGroup(entry, group)
    if group == "off" then return entry.off == true end
    if entry.off then return false end
    if group == "own" then return entry.own == true end
    if group == "deals" then return true end
    return entry.group == group
end
function B.History(id, at)
    local prices = {}
    for _, point in ipairs(ns.Activity.History(id, B.HISTORY_DAYS).points) do
        if point.price and point.price > 0 and point.at ~= at then prices[#prices + 1] = point.price end
    end
    table.sort(prices)
    local n = #prices
    local stats = {count = n, jumpy = false}
    if n == 0 then return stats end
    stats.min, stats.max = prices[1], prices[n]
    stats.median = n % 2 == 1 and prices[(n + 1) / 2] or (prices[n / 2] + prices[n / 2 + 1]) / 2
    stats.jumpy = stats.max > stats.min * B.SPREAD
    return stats
end
function B.Reference(id, stats, offers, skip)
    local worth = B.Worth(id)
    if worth then return worth, "own" end
    if stats.count >= B.HISTORY_MIN then return stats.median, "history" end
    local list, sellers, count = {}, {}, 0
    for _, offer in ipairs(offers) do
        if offer ~= skip and offer.price then
            list[#list + 1] = {offer.price, offer.count}
            if not sellers[offer.owner] then sellers[offer.owner] = true; count = count + 1 end
        end
    end
    if #list < B.MIN_LOTS or count < B.MIN_SELLERS then return nil, nil end
    return ns.Markets.MarketPrice(list), "offers"
end
function B.Deposit(id, count, fee)
    local vendor = select(11, ns.Compat.ItemInfo(id))
    local rate = fee == 0.15 and 0.75 or 0.15
    if not vendor then return 100, false end
    return math.max(100, math.floor(vendor * (count * rate * (B.HOURS / 12)))), true
end
function B.Resale(id, ref, count, fee)
    local gross = ref * count
    local commission = gross * fee
    local deposit, known = B.Deposit(id, count, fee)
    return {gross = gross, commission = commission, deposit = deposit, depositKnown = known,
        revenue = gross - commission - deposit}
end
function B.Increment(bid)
    return math.max(1, math.floor(bid / 100) * 5)
end
function B.NextBid(lot)
    if lot.bid > 0 then return lot.bid + B.Increment(lot.bid) end
    return lot.minBid
end
function B.Vendor(item, count, buyout, nextBid)
    local unit = select(11, ns.Compat.ItemInfo(item))
    if type(unit) ~= "number" or unit <= 0 or count <= 0 then return nil end
    local total = unit * count
    local deal = {unit = unit, total = total, nextBid = nextBid}
    if buyout > 0 and buyout < total then deal.buyout = total - buyout end
    if nextBid and nextBid > 0 and nextBid < total and not (buyout > 0 and nextBid >= buyout) then
        deal.bid = total - nextBid
    end
    if not deal.buyout and not deal.bid then return nil end
    return deal
end
local function lotKey(lot)
    return ns.Lot.Key(lot.item, lot.suffix, lot.count, lot.buyout, lot.owner) .. ":" .. lot.minBid .. ":" .. lot.bid
end
B.placed = {}
function B.Evaluate(entry, options)
    local id, now, fee = entry.id, options.now or time(), options.fee or ns.Fee()
    local percent = options.percent or B.PERCENT
    local item = ns.Markets.Item(id)
    local all, observation = {}, nil
    if item and item.quote then all, observation = ns.Markets.Offers(id) end
    local row = {id = id, entry = entry, lots = 0, checked = observation and observation.at or nil,
        scanID = item and item.quote and item.quote.scanID or nil}
    row.stats = B.History(id, row.checked)
    local me, offers = UnitName("player"), {}
    for _, offer in ipairs(all) do
        if offer.owner ~= me and offer.owner ~= "" and offer.count > 0 then
            row.lots = row.lots + 1
            if offer.price then
                offers[#offers + 1] = offer
                if not row.min or offer.price < row.min then row.min = offer.price end
            end
        end
    end
    row.ref, row.source = B.Reference(id, row.stats, offers, nil)
    if row.ref and row.min then row.discount = (1 - row.min / row.ref) * 100 end
    for _, offer in ipairs(all) do
        if offer.owner ~= me and offer.owner ~= "" and offer.count > 0 then
            local key = lotKey(offer)
            if B.placed[key] and B.placed[key] == row.scanID then
                row.placed = true
            else
                local ref, source = row.ref, row.source
                if source == "offers" then ref, source = B.Reference(id, row.stats, offers, offer.price and offer or nil) end
                local kinds = {}
                if offer.buyout > 0 then kinds[1] = {"buyout", offer.buyout} end
                if (offer.timeLeft == 1 or offer.timeLeft == 2) and (offer.expiresMax or 0) > now then
                    local bid = B.NextBid(offer)
                    if offer.buyout == 0 or bid < offer.buyout then kinds[#kinds + 1] = {"bid", bid} end
                end
                for _, pair in ipairs(ref and ref > 0 and kinds or {}) do
                    local kind, cost = pair[1], pair[2]
                    local unit = cost / offer.count
                    local discount = (1 - unit / ref) * 100
                    local resale = B.Resale(id, ref, offer.count, fee)
                    local profit = resale.revenue - cost
                    if cost > 0 and discount >= percent and profit > 0 then
                        if not row.deal or profit > row.deal.profit then
                            row.deal = {kind = kind, lot = offer, key = key, cost = cost, unit = unit, ref = ref,
                                source = source, discount = discount, resale = resale, profit = profit,
                                buyKey = ns.Lot.Key(offer.item, offer.suffix, offer.count, offer.buyout, offer.owner),
                                cheapest = row.stats.min ~= nil and unit < row.stats.min}
                        end
                        break
                    end
                end
            end
        end
    end
    return row
end
local cached
function B.Rows(group, options)
    local now = options.now or time()
    local scans = ns.Store.DB().scans or {}
    local last = scans[#scans]
    local sig = table.concat({group, options.percent or B.PERCENT, options.fee or 0, math.floor(now / 60), B.revision,
        #scans, last and last.id or "", UnitFactionGroup("player") or ""}, "|")
    if cached and cached.sig == sig then return cached.rows, cached.info end
    local rows, info = {}, {total = 0, checked = 0, deals = 0, group = group}
    for _, entry in ipairs(B.Entries()) do
        if B.InGroup(entry, group) then
            local row = B.Evaluate(entry, {percent = options.percent, fee = options.fee, now = now})
            if group ~= "deals" or row.deal then
                rows[#rows + 1] = row
                info.total = info.total + 1
                if row.checked then info.checked = info.checked + 1 end
                if row.deal then info.deals = info.deals + 1 end
            end
        end
    end
    table.sort(rows, function(a, b)
        if (a.deal ~= nil) ~= (b.deal ~= nil) then return a.deal ~= nil end
        if a.deal and a.deal.profit ~= b.deal.profit then return a.deal.profit > b.deal.profit end
        if (a.discount ~= nil) ~= (b.discount ~= nil) then return a.discount ~= nil end
        if a.discount and a.discount ~= b.discount then return a.discount > b.discount end
        if (a.checked ~= nil) ~= (b.checked ~= nil) then return a.checked ~= nil end
        return ns.Markets.Name(a.id) < ns.Markets.Name(b.id)
    end)
    cached = {sig = sig, rows = rows, info = info}
    return rows, info
end
local function groupEntries(group, options)
    local rows = group == "deals" and B.Rows(group, options or {}) or nil
    local entries = {}
    if rows then
        for _, row in ipairs(rows) do entries[#entries + 1] = row.entry end
    else
        for _, entry in ipairs(B.Entries()) do
            if B.InGroup(entry, group) and group ~= "off" then entries[#entries + 1] = entry end
        end
    end
    return entries
end
function B.Targets(group, options)
    local ids = {}
    for _, entry in ipairs(groupEntries(group, options)) do ids[#ids + 1] = entry.id end
    return ids
end
function B.Sources(group, mode, options)
    local picked = {}
    for _, entry in ipairs(groupEntries(group, options)) do
        local item = ns.Markets.Item(entry.id)
        local q = item and item.quote
        local fresh = q and q.complete and (q.miss or 0) == 0 and time() - (q.at or 0) < ns.Markets.TTL(entry.id)
        local take = mode == "hard" or (mode == "missing" and not (q and q.price)) or (mode == "soft" and not fresh)
        if take then picked[#picked + 1] = {entry = entry, at = q and q.at or 0} end
    end
    table.sort(picked, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.entry.id < b.entry.id
    end)
    local sources = {}
    for i = 1, math.min(#picked, B.LIMIT) do
        local entry = picked[i].entry
        if ns.Compat.ItemInfo(entry.id) then sources[#sources + 1] = entry.id
        else
            local name = B.Name(entry)
            if name then sources[#sources + 1] = {target = {itemID = entry.id, query = name}, covered = {entry.id}} end
        end
    end
    return sources, math.max(0, #picked - B.LIMIT)
end
function B.Scan(group, mode, options)
    mode = ns.Batch.Mode(mode)
    local sources, more = B.Sources(group, mode, options)
    if #sources == 0 then ns.say(ns.T("bargainNothing")); return false end
    local started = ns.Batch.Complete(sources, "hard", true)
    if started and more > 0 then ns.say(ns.T("bargainMore", #sources, more)) end
    return started
end
function B.Preview(group)
    local soft, more = B.Sources(group, "soft")
    local hard = B.Sources(group, "hard")
    local missing = B.Sources(group, "missing")
    return #soft, #hard, #missing, more
end
function B.Depth(id, limit)
    local depth = ns.Markets.Depth(id)
    local levels = {}
    for i = 1, math.min(#depth.levels, limit or 6) do levels[i] = depth.levels[i] end
    return levels, {lots = depth.lots, units = depth.units}
end
local function live(index)
    local name, _, count, _, _, _, minBid, increment, buyout, bidAmount, highBidder, owner =
        GetAuctionItemInfo("list", index)
    if not name or not count then return nil end
    local nextBid = (bidAmount or 0) > 0 and bidAmount + math.max(1, increment or 0) or minBid
    return {count = count, minBid = minBid, buyout = buyout or 0, bid = bidAmount or 0, mine = highBidder and true or false,
        owner = owner, nextBid = nextBid, left = GetAuctionItemTimeLeft and GetAuctionItemTimeLeft("list", index)}
end
local function bidGuard(offer, limit)
    return function(index)
        local lot = live(index)
        if not lot or lot.mine or lot.owner == UnitName("player") or not lot.left or lot.left > 2 then return false end
        if lot.nextBid > limit or (lot.buyout > 0 and lot.nextBid >= lot.buyout) then return false end
        offer.bid = lot.nextBid
        return true
    end
end
local function buyoutGuard(deal)
    return function(index)
        local lot = live(index)
        return lot ~= nil and lot.buyout == deal.lot.buyout and lot.count == deal.lot.count and lot.owner ~= UnitName("player")
    end
end
B.job = nil
function B.Active()
    return B.job ~= nil and ns.Buy.Active()
end
function B.Act(row)
    local deal = row.deal
    if not deal then return false end
    if ns.Buy.Active() then
        if B.job and B.job.key == deal.key then return ns.Buy.Confirm() end
        ns.say(ns.T("bargainBusy"))
        return false
    end
    local lot, bid = deal.lot, deal.kind == "bid"
    local offer = {key = deal.buyKey, item = row.id, suffix = lot.suffix, owner = lot.owner, stack = lot.count,
        buyout = lot.buyout, count = 1, page = 0}
    local plan = ns.Plan.Recount({kind = "manual", need = lot.count, picks = {{offer = offer, lots = 1}}})
    local guard = bid and bidGuard(offer, deal.cost) or buyoutGuard(deal)
    B.job = {key = deal.key, scanID = row.scanID, offer = offer, kind = deal.kind}
    local started = ns.Buy.Start(B.Name(row.entry) or ns.Markets.Name(row.id), plan, row.id, guard,
        {lookup = {[deal.buyKey] = offer}, bid = bid})
    if not started then B.job = nil end
    return started
end
function B.Cancel()
    B.job = nil
    return ns.Buy.Stop()
end
function B.BuyChanged()
    local job = B.job
    if job and not ns.Buy.Active() then
        if job.offer.count == 0 then
            B.placed[job.key] = job.scanID
            changed()
        end
        B.job = nil
    end
    if B.onChange then B.onChange() end
end
local previous = ns.Buy.onChange
ns.Buy.onChange = function()
    if previous then previous() end
    B.BuyChanged()
end
