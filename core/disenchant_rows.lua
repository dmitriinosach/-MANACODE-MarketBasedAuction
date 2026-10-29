local _, ns = ...
local D = ns.Disenchant
function D.Snapshot(key)
    local scans = ns.Store.DB().scans
    local draft = ns.Store.DB().disenchantDrafts and ns.Store.DB().disenchantDrafts[key]
    for i = #scans, 1, -1 do
        if scans[i].deGroup == key then
            return draft and draft.t >= scans[i].t and draft or scans[i]
        end
    end
    return draft
end
function D.Progress(key)
    local state, job = ns.Scan.state, ns.Batch.job
    local scan = state.scan
    if scan and scan.deGroup == key then
        return {stage = "equipment", paused = state.phase == "paused", page = state.page + 1, classIndex = scan.classIndex,
            minLevel = scan.minLevel, maxLevel = scan.maxLevel,
            pages = state.pages, lots = #scan.lots, scan = scan}
    end
    if not job or not scan then return nil end
    local matches, total, index = job.deGroup == key, 0, 0
    for i, task in ipairs(job.items) do
        if task.target.deGroup == key then matches = true end
        if task.target.itemID then
            total = total + 1
            if i <= job.index then index = index + 1 end
        end
    end
    if matches and scan.itemID then
        return {stage = "materials", paused = state.phase == "paused", index = index, total = total,
            name = ns.Markets.Name(scan.itemID), page = state.page + 1, pages = state.pages}
    end
    return nil
end
local EMPTY = {}
local parsed = {text = {}, lots = {}}
local rowsCache, poolCache
local function lotAt(lots, index)
    if parsed.source ~= lots then parsed = {source = lots, text = {}, lots = {}} end
    local text = lots[index]
    if parsed.text[index] ~= text then
        parsed.text[index], parsed.lots[index] = text, ns.Lot.Decode(text) or false
    end
    return parsed.lots[index] or nil
end
local function settingsKey(fee, selling, excludedBands)
    local parts, bands = {tostring(fee), UnitName("player") or ""}, {}
    if selling then
        parts[#parts + 1] = tostring(selling.hours) .. ":" .. tostring(selling.losses) .. ":" .. tostring(selling.base)
    end
    for band, off in pairs(excludedBands or EMPTY) do if off then bands[#bands + 1] = band end end
    table.sort(bands)
    parts[#parts + 1] = table.concat(bands, ",")
    for _, id in ipairs(ns.disenchantMaterials) do
        local quote = D.Quote(id)
        parts[#parts + 1] = quote and (tostring(quote.price) .. ":" .. tostring(quote.miss) .. ":"
            .. tostring(quote.complete) .. ":" .. tostring(D.Fresh(id))) or "-"
    end
    return table.concat(parts, "|")
end
local function reuse(cache, scan, lots, sig)
    if cache and cache.scan == scan and cache.lots == lots and cache.sig == sig and cache.count <= #lots
        and lots[cache.count] == cache.tail then
        return cache
    end
    return {scan = scan, lots = lots, sig = sig, count = 0, entries = {}, memo = {}, rows = {}, names = {}}
end
local function byMargin(a, b)
    local left, right = a.estimate.margin, b.estimate.margin
    if left ~= right then
        if left == nil then return false end
        if right == nil then return true end
        return left > right
    end
    return a.id < b.id
end
function D.Rows(key, fee, selling, minItemLevel, minPercent, maxItemLevel, includeNoLevel, excludedBands)
    local progress = D.Progress(key)
    local scan = progress and progress.scan or D.Snapshot(key)
    local lots = scan and scan.lots or EMPTY
    local sig = table.concat({key, tostring(minItemLevel), tostring(minPercent), tostring(maxItemLevel),
        tostring(includeNoLevel), settingsKey(fee, selling, excludedBands)}, "|")
    local cache = reuse(rowsCache, scan, lots, sig)
    rowsCache = cache
    if cache.count < #lots then
        local group, me, entries, touched = D.Group(key), UnitName("player"), cache.entries, {}
        for i = cache.count + 1, #lots do
            local lot = lotAt(lots, i)
            local meta = lot and scan.disenchantItems[lot.item]
            local eligible = meta and D.Accepts(group, meta) and D.WithinLevels(meta, minItemLevel, maxItemLevel)
                and (includeNoLevel ~= false or meta.required ~= 0)
                and not (excludedBands and excludedBands[meta.band])
                and lot.count > 0 and lot.buyout > 0 and lot.owner ~= "" and lot.owner ~= me
            local deal = eligible and ns.Bargain.Vendor(lot.item, lot.count, lot.buyout, nil) or nil
            if eligible and minPercent ~= nil and not deal then
                local estimate = D.Estimate(D.Band(meta.band), lot.buyout / lot.count, fee, nil, selling, cache.memo)
                eligible = estimate.percent ~= nil and estimate.percent >= minPercent - 0.000001
            end
            if eligible then
                local row = entries[lot.item] or {id = lot.item, units = 0, lots = 0, meta = meta}
                row.cost = math.min(row.cost or math.huge, lot.buyout / lot.count)
                row.units, row.lots = row.units + lot.count, row.lots + 1
                if deal then
                    local vendor = row.vendor or {unit = deal.unit, lots = 0, units = 0, profit = 0, best = 0}
                    vendor.lots, vendor.units = vendor.lots + 1, vendor.units + lot.count
                    vendor.profit, vendor.best = vendor.profit + deal.buyout, math.max(vendor.best, deal.buyout)
                    row.vendor = vendor
                end
                entries[lot.item], touched[row] = row, true
            end
        end
        cache.count, cache.tail = #lots, lots[#lots]
        for row in pairs(touched) do
            local band = D.Band(row.meta.band)
            row.estimate = D.Estimate(band, row.cost, fee, nil, selling, cache.memo)
            row.target = group.targetID and D.Output(band, group.targetID) or nil
        end
        local rows = {}
        for _, row in pairs(entries) do rows[#rows + 1] = row end
        table.sort(rows, byMargin)
        cache.rows = rows
    end
    local result = {}
    for i, row in ipairs(cache.rows) do result[i] = row end
    return result
end
local function purchasePool(key, scan, options)
    local lots = scan and scan.lots or EMPTY
    local sig = table.concat({key, tostring(options.minItemLevel), tostring(options.maxItemLevel),
        tostring(options.includeNoLevel), settingsKey(options.fee, options.selling, options.excludedBands)}, "|")
    local cache = reuse(poolCache, scan, lots, sig)
    poolCache = cache
    if cache.count < #lots then
        local group, me, entries = D.Group(key), UnitName("player"), cache.entries
        for i = cache.count + 1, #lots do
            local lot = lotAt(lots, i)
            local meta = lot and scan.disenchantItems[lot.item]
            if meta and D.Accepts(group, meta) and D.WithinLevels(meta, options.minItemLevel, options.maxItemLevel)
                and (options.includeNoLevel ~= false or meta.required ~= 0)
                and not (options.excludedBands and options.excludedBands[meta.band])
                and lot.buyout > 0 and lot.count > 0 and lot.owner ~= "" and lot.owner ~= me then
                entries[#entries + 1] = {lot = lot, meta = meta,
                    estimate = D.Estimate(D.Band(meta.band), lot.buyout / lot.count, options.fee, nil,
                        options.selling, cache.memo),
                    key = ns.Lot.Key(lot.item, lot.suffix, lot.count, lot.buyout, lot.owner)}
            end
        end
        cache.count, cache.tail = #lots, lots[#lots]
    end
    return cache
end
function D.PurchasePlan(key, options)
    local progress = D.Progress(key)
    local scan, lots = progress and progress.scan or D.Snapshot(key), {}
    local ordered, rejected, stale = {}, {unknown = 0, threshold = 0, money = 0}, 0
    for _, basket in ipairs(D.orders and scan and D.orders[scan.id] or {}) do
        for _, pick in ipairs(basket.picks) do
            local signature = pick.offer.key
            ordered[signature] = (ordered[signature] or 0) + pick.lots - pick.offer.count
        end
    end
    local pool = purchasePool(key, scan, options)
    for _, entry in ipairs(pool.entries) do
        local lot, e = entry.lot, entry.estimate
        if not options.itemID or lot.item == options.itemID then
            if e.percent ~= nil and not e.fresh then stale = stale + 1 end
            if options.priceLimit and lot.buyout >= options.priceLimit * lot.count then rejected.threshold = rejected.threshold + 1
            elseif not options.priceLimit and not e.percent then rejected.unknown = rejected.unknown + 1
            elseif not options.priceLimit and not options.itemID and e.percent <= options.percent then rejected.threshold = rejected.threshold + 1
            else
                lots[#lots + 1] = {lot = lot, percent = e.percent, margin = e.margin and e.margin * lot.count,
                    priority = options.priceLimit and -lot.buyout / lot.count or e.percent,
                    classIndex = entry.meta.classIndex, key = entry.key}
            end
        end
    end
    table.sort(lots, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.lot.buyout < b.lot.buyout
    end)
    local result, byID, money = {items = {}, count = 0, cost = 0, map = {},
        basket = {kind = "manual", picks = {}, need = 0}, scanID = scan and scan.id,
        rejected = rejected, stale = stale, margin = 0}, {}, GetMoney()
    for _, entry in ipairs(lots) do
        if options.itemID and result.count > 0 then break end
        local lot = entry.lot
        if (ordered[entry.key] or 0) > 0 then
            ordered[entry.key] = ordered[entry.key] - 1
        elseif lot.buyout <= money then
            local item = byID[lot.item]
            if not item then
                pool.names[lot.item] = pool.names[lot.item] or ns.Markets.Name(lot.item)
                item = {id = lot.item, name = pool.names[lot.item], plan = {kind = "manual", picks = {}, need = 0}}
                byID[lot.item] = item; result.items[#result.items + 1] = item
            end
            local offer = {stack = lot.count, buyout = lot.buyout, count = 1, page = 0}
            item.plan.picks[#item.plan.picks + 1] = {offer = offer, lots = 1}
            item.plan.need = item.plan.need + lot.count
            local saved = result.map[entry.key]
            if not saved then
                local offer = {key = entry.key, item = lot.item, suffix = lot.suffix, owner = lot.owner,
                    classIndex = entry.classIndex, percent = entry.percent, priority = entry.priority,
                    stack = lot.count, buyout = lot.buyout, count = 0, page = 0}
                saved = {offer = offer, lots = 0}
                result.map[entry.key] = saved
                result.basket.picks[#result.basket.picks + 1] = saved
            end
            saved.lots, saved.offer.count = saved.lots + 1, saved.offer.count + 1
            result.basket.need = result.basket.need + lot.count
            result.count, result.cost, money = result.count + 1, result.cost + lot.buyout, money - lot.buyout
            result.margin = result.margin and entry.margin and result.margin + entry.margin or nil
        else
            rejected.money = rejected.money + 1
        end
    end
    for _, item in ipairs(result.items) do ns.Plan.Recount(item.plan) end
    ns.Plan.Recount(result.basket)
    return result
end
function D.CancelBuy()
    D.purchase = nil
    ns.Scan.purchaseRequest = nil
    ns.Buy.Stop()
end
local function startPurchase()
    local job = D.purchase
    local options, group = job.options, D.Group(job.key)
    local function guard(index)
        local id = ns.Lot.FromLink(GetAuctionItemLink("list", index))
        local _, _, count, _, _, _, _, _, buyout, _, _, owner = GetAuctionItemInfo("list", index)
        local meta = id and D.Candidate(id, GetAuctionItemLink("list", index))
        if not meta or not D.WithinLevels(meta, options.minItemLevel, options.maxItemLevel)
            or options.includeNoLevel == false and meta.required == 0
            or options.excludedBands and options.excludedBands[meta.band]
            or not D.Accepts(group, meta) or not count or count <= 0
            or not buyout or buyout <= 0 or not owner or owner == "" or owner == UnitName("player") then return false end
        if options.priceLimit then return buyout < options.priceLimit * count end
        local estimate = D.Estimate(D.Band(meta.band), buyout / count, options.fee, nil, options.selling)
        return estimate.percent ~= nil and (options.itemID ~= nil or estimate.percent > options.percent)
    end
    job.starting = true
    local ok = ns.Buy.StartCategory(job.plan.basket, job.filter, guard)
    job.starting = false
    if ok then
        D.orders = D.orders or {}
        D.orders[job.plan.scanID] = D.orders[job.plan.scanID] or {}
        table.insert(D.orders[job.plan.scanID], job.plan.basket)
    else D.purchase = nil end
    return ok
end
function D.Purchase(key, options)
    if D.purchase then
        if D.purchase.key ~= key or D.purchase.options.itemID ~= options.itemID then
            D.CancelBuy(); ns.say(ns.T("deBuyContextChanged")); return false
        end
        return ns.Buy.Confirm()
    end
    if ns.Buy.Active() or not ns.Scan.state.open then return false end
    if ns.Scan.state.phase ~= "idle" then
        return ns.Scan.SnapshotForPurchase(key, function() D.Purchase(key, options) end)
    end
    local plan = D.PurchasePlan(key, options)
    if #plan.items == 0 then ns.say(ns.T("deBuyEmpty")); return false end
    local group, scan = D.Group(key), D.Snapshot(key)
    local frozen = {fee = options.fee, percent = options.percent, minItemLevel = options.minItemLevel,
        maxItemLevel = options.maxItemLevel, includeNoLevel = options.includeNoLevel, itemID = options.itemID,
        priceLimit = options.priceLimit}
    if options.selling then
        frozen.selling = {hours = options.selling.hours, losses = options.selling.losses, base = options.selling.base}
    end
    if options.excludedBands then
        frozen.excludedBands = {}
        for band, off in pairs(options.excludedBands) do frozen.excludedBands[band] = off end
    end
    D.purchase = {key = key, options = frozen, plan = plan,
        filter = {scope = "disenchant", deGroup = key, deTarget = group.targetID,
            classIndex = group.classIndex, minLevel = group.minLevel,
            maxLevel = group.maxLevel, minQuality = group.quality,
            maxPages = math.max(1, scan.deReadPages or math.ceil((scan.expect or 0) / 50))}}
    local firstClass = group.classIndex or 2
    local range = scan.deRanges and scan.deRanges[firstClass]
    local low, high = D.RequiredRange(key, firstClass, options)
    D.purchase.filter.minLevel, D.purchase.filter.maxLevel = range and range.minLevel or low,
        range and range.maxLevel or high
    if group.targetID then
        local routes = {}
        for _, pick in ipairs(plan.basket.picks) do
            local class = pick.offer.classIndex
            local low, high = D.RequiredRange(key, class, options)
            routes[class] = routes[class] or {classIndex = class,
                minLevel = scan.deRanges and scan.deRanges[class] and scan.deRanges[class].minLevel or low,
                maxLevel = scan.deRanges and scan.deRanges[class] and scan.deRanges[class].maxLevel or high,
                maxPages = math.max(1, scan.deRoutePages and scan.deRoutePages[class] or D.purchase.filter.maxPages), score = -math.huge}
            routes[class].score = math.max(routes[class].score, pick.offer.priority or pick.offer.percent)
        end
        D.purchase.filter.routes = {}
        for _, route in pairs(routes) do table.insert(D.purchase.filter.routes, route) end
        table.sort(D.purchase.filter.routes, function(a, b) return a.score > b.score end)
    end
    return startPurchase()
end
function D.BuyChanged()
    local job = D.purchase
    if job and not job.starting then
        if (ns.Buy.state.refused or 0) > 0 then D.CancelBuy()
        elseif not ns.Buy.Active() then
            D.purchase = nil
        end
    end
    if ns.Trader and ns.Trader.ViewActive("disenchant") and ns.Trader.frame then ns.Trader.Refresh() end
end
