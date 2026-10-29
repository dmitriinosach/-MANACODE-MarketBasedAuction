local _, ns = ...
local D = ns.Disenchant
local T = {}
ns.DisenchantTail = T
local BUYOUT = {"buyout", false}
function T.Limit(key, options)
    if options.priceLimit then return options.priceLimit - 1 end
    local percent = tonumber(options.percent)
    if not percent or percent <= -100 or percent > 1000 then return nil end
    local group, fixed, limit = D.Group(key), {}, 0
    for _, id in ipairs(D.Materials(key)) do
        local q = D.Quote(id)
        if not q or not q.price or q.miss > 0 or q.complete == false then return nil, "prices", id end
        fixed[id] = {price = q.price, miss = 0, complete = true, manual = q.manual}
    end
    for _, band in ipairs(ns.disenchantBands) do
        if D.Matches(group, band) and band.maxLevel >= (options.minItemLevel or 0)
            and (not options.maxItemLevel or options.maxItemLevel == 0 or band.minLevel <= options.maxItemLevel) then
            local estimate = D.Estimate(band, 0, options.fee or 0.05, fixed, options.selling)
            if not estimate.net then return nil, "prices", band.key end
            limit = math.max(limit, estimate.net / (1 + percent / 100))
        end
    end
    return limit, fixed, percent
end
function T.Ready(target)
    if target.scope ~= "disenchant" then return true end
    local options = target.deOptions
    if D.blocked and D.blocked.key == target.deGroup then D.blocked = nil end
    if not options or not options.cut then return true end
    local limit, reason, missing = T.Limit(target.deGroup, options)
    if limit or reason ~= "prices" then return true end
    D.blocked = {key = target.deGroup, id = type(missing) == "number" and missing or nil}
    return false
end
function T.BlockedText(blocked)
    return blocked.id and ns.T("deCutBlocked", ns.Markets.Name(blocked.id)) or ns.T("deCutBlockedAll")
end
function T.Prepare(scan)
    local options = scan.deOptions
    if not options or not options.cut then return end
    local limit, prices, percent = T.Limit(scan.deGroup, options)
    if not limit then
        if prices then scan.deCutDisabled, scan.deCutMissing = prices, percent end
        return
    end
    scan.deLimit, scan.dePriceLimit = limit, options.priceLimit
    if not options.priceLimit then scan.dePrices, scan.dePercent = prices, percent end
end
function T.Admit(scan, item, link)
    local meta = D.Candidate(item, link)
    if meta == nil then return nil end
    if meta == false then return false end
    local options = scan.deOptions
    if not D.Accepts(D.Group(scan.deGroup), meta) or (scan.classIndex and meta.classIndex ~= scan.classIndex)
        or not D.WithinLevels(meta, options and options.minItemLevel, options and options.maxItemLevel)
        or (meta.required and (meta.required < scan.minLevel or meta.required > scan.maxLevel)) then return false end
    scan.disenchantItems[item] = meta
    return true
end
function T.Sort(filter)
    if not filter or filter.scope ~= "disenchant" then return nil end
    if type(SortAuctionClearSort) ~= "function" or type(SortAuctionSetSort) ~= "function"
        or type(GetAuctionSort) ~= "function" then
        if filter.deOptions and filter.deOptions.cut then filter.deCutDisabled = filter.deCutDisabled or "sort" end
        return nil
    end
    if not filter.deOriginalSort then
        filter.deOriginalSort = {}
        for i = 1, 10 do
            local key, reverse = GetAuctionSort("list", i)
            if not key then break end
            filter.deOriginalSort[#filter.deOriginalSort + 1] = {key, reverse}
        end
    end
    return BUYOUT
end
function T.RestoreSort(filter)
    if not filter or not filter.deOriginalSort then return end
    local key, reverse = GetAuctionSort("list", 1)
    if key == "buyout" and not reverse then
        SortAuctionClearSort("list")
        for i = #filter.deOriginalSort, 1, -1 do
            local rule = filter.deOriginalSort[i]
            SortAuctionSetSort("list", rule[1], rule[2])
        end
    end
    filter.deOriginalSort = nil
end
function T.CheckTail(scan, batch)
    if not scan.deLimit or scan.deCutDisabled or batch == 0 then return false end
    if type(GetAuctionSort) ~= "function" then scan.deCutDisabled = "sort"; return false end
    local sort, reverse = GetAuctionSort("list", 1)
    if sort ~= "buyout" or reverse then scan.deCutDisabled = "sort"; return false end
    local minimum, previous = math.huge, scan.deLastPrice or 0
    for i = 1, batch do
        local _, _, count, _, _, _, _, _, buyout = GetAuctionItemInfo("list", i)
        if not count or count <= 0 or not buyout then scan.deCutDisabled = "missing"; return false end
        if buyout > 0 then
            if buyout < previous then scan.deCutDisabled = "order"; return false end
            if count ~= 1 then
                local id = ns.Lot.FromLink(GetAuctionItemLink("list", i))
                local meta = id and D.Candidate(id, GetAuctionItemLink("list", i))
                if meta == nil then scan.deCutDisabled = "missing"; return false end
                if D.Accepts(D.Group(scan.deGroup), meta) then scan.deCutDisabled = "stack"; return false end
            end
            previous = buyout
            minimum = math.min(minimum, buyout)
        end
    end
    scan.deLastPrice = previous
    if (scan.miss or 0) > 0 then scan.deCutDisabled = "missing"; return false end
    scan.deTailPages = minimum < math.huge and minimum > scan.deLimit and (scan.deTailPages or 0) + 1 or 0
    return scan.deTailPages >= 2
end
local route = {}
function route.Base(scan)
    return scan.deExpectedBase or 0
end
function route.Read(scan, page)
    scan.deScannedPages = (scan.deScannedPages or 0) + 1
    scan.deRoutePages = scan.deRoutePages or {}
    scan.deRoutePages[scan.classIndex or 0] = page
end
function route.Cut(scan, batch, more)
    local cut = T.CheckTail(scan, batch)
    local blocked = scan.deOptions and scan.deOptions.cut and scan.deCutDisabled
    if not (cut or blocked) or not more then return nil end
    scan.truncated, scan.deCut, scan.deReadPages = true, cut or nil, scan.deScannedPages
    scan.deCutStopped = blocked or nil
    if blocked or not scan.deClasses then return "finish" end
    return "class"
end
function route.Next(scan, expect)
    local classes = scan.deClasses
    local nextClass = classes and classes[(scan.deRoute or 1) + 1]
    if not nextClass then return false end
    scan.deRoute = (scan.deRoute or 1) + 1
    scan.classIndex, scan.deExpectedBase = nextClass, expect
    local range = scan.deRanges and scan.deRanges[nextClass]
    if range then scan.minLevel, scan.maxLevel = range.minLevel, range.maxLevel end
    scan.deTailPages, scan.deLastPrice = 0, nil
    return true
end
function T.Route(scan)
    return scan and scan.scope == "disenchant" and route or nil
end
function T.Begin(scan, target)
    scan.scope, scan.deGroup, scan.disenchantItems = "disenchant", target.deGroup, {}
    scan.classIndex, scan.minLevel, scan.maxLevel, scan.minQuality = target.classIndex,
        target.minLevel, target.maxLevel, target.minQuality
    scan.deOptions = target.deOptions
    scan.deClasses, scan.deRoute = target.deClasses, 1
    if target.deClasses then scan.classIndex = target.deClasses[1] end
    scan.deRanges = target.deRanges
    local range = target.deRanges and target.deRanges[scan.classIndex]
    if range then scan.minLevel, scan.maxLevel = range.minLevel, range.maxLevel end
    scan.deTarget = D.Group(target.deGroup).targetID
    T.Prepare(scan)
    return route
end
D.BlockedText = T.BlockedText
