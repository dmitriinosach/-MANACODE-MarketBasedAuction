local _, ns = ...
local S = {}
ns.Shared = S
local INBOX_ADDON, INBOX_GLOBAL = "ManaCode_AuctionScan_Shared", "ManaCodeAuctionScanInbox"
S.limits = {markets = 2, days = 30, item = 240, points = 8000}
local function integer(value, maximum)
    return type(value) == "number" and value >= 0 and value <= maximum and value == math.floor(value)
end
local function valid(point)
    return type(point) == "table" and type(point.sourceID) == "string" and #point.sourceID <= 128
        and type(point.scanID) == "string" and #point.scanID <= 256 and integer(point.itemID, 2147483647)
        and point.itemID > 0 and integer(point.at, 4102444800) and integer(point.since, point.at)
        and integer(point.lots, 10000000) and integer(point.units, 1000000000)
        and (point.price == nil or (type(point.price) == "number" and point.price >= 0 and point.price <= 1e12))
        and (point.p25 == nil or (type(point.p25) == "number" and point.p25 >= 0 and point.p25 <= 1e12))
        and point.at <= time() and point.complete == true
        and (point.clockStatus == "unverified" or point.clockStatus == "verified")
end
local function usable(inbox)
    return type(inbox) == "table" and inbox.v == 1 and type(inbox.market) == "table"
end
local loadTried = false
function S.Inbox()
    local inbox = _G[INBOX_GLOBAL]
    if inbox == nil and not loadTried and LoadAddOn then
        loadTried = true
        LoadAddOn(INBOX_ADDON)
        inbox = _G[INBOX_GLOBAL]
    end
    if usable(inbox) then return inbox end
    return ns.SharedInbox
end
local pending
local function group(items, list)
    local count = 0
    for _, point in ipairs(type(list) == "table" and list or {}) do
        local id = type(point) == "table" and point.itemID
        if id ~= nil then
            local bucket = items[id]
            if not bucket then bucket = {}; items[id] = bucket; count = count + 1 end
            bucket[#bucket + 1] = point
        end
    end
    return count
end
local function grouped(inbox)
    if pending and pending.inbox == inbox and pending.version == inbox.version then return pending end
    local items = {}
    local count = group(items, inbox.observations)
    for _, part in ipairs(type(inbox.parts) == "table" and inbox.parts or {}) do count = count + group(items, part) end
    pending = {inbox = inbox, version = inbox.version, items = items, count = count}
    return pending
end
local function trimItem(list, edge)
    local n = #list
    local first = math.max(1, n - S.limits.item + 1)
    while first <= n and list[first].at < edge do first = first + 1 end
    if first == 1 then return end
    for i = first, n do list[i - first + 1] = list[i] end
    for i = n - first + 2, n do list[i] = nil end
end
function S.Trim(data, now)
    local edge, count = (now or time()) - S.limits.days * 86400, 0
    for id, list in pairs(data.items) do
        trimItem(list, edge)
        if #list == 0 then data.items[id] = nil else count = count + #list end
    end
    if count > S.limits.points then
        local ats = {}
        for _, list in pairs(data.items) do
            for _, point in ipairs(list) do ats[#ats + 1] = point.at end
        end
        table.sort(ats)
        local cut = ats[count - S.limits.points]
        count = 0
        for id, list in pairs(data.items) do
            local n, kept = #list, 0
            for i = 1, n do
                if list[i].at > cut then kept = kept + 1; list[kept] = list[i] end
            end
            for i = n, kept + 1, -1 do list[i] = nil end
            if kept == 0 then data.items[id] = nil end
            count = count + kept
        end
    end
    data.count = count
    return count
end
local trimmed = setmetatable({}, {__mode = "k"})
local function evict(history)
    local count, oldest, oldestAt = 0, nil, math.huge
    for key, data in pairs(history) do
        count = count + 1
        local opened = type(data) == "table" and data.opened or 0
        if opened < oldestAt then oldest, oldestAt = key, opened end
    end
    if count >= S.limits.markets and oldest then history[oldest] = nil end
end
function S.Data()
    local inbox, db = S.Inbox(), ns.Store.DB()
    if not usable(inbox) then return nil end
    local market = inbox.market
    if market.realm ~= (GetRealmName() or "") or market.faction ~= (UnitFactionGroup("player") or "")
        or type(market.serverID) ~= "string" or type(market.pool) ~= "string" then return nil end
    local key = table.concat({market.serverID, market.realm, market.faction, market.pool}, "|")
    db.sharedHistory = db.sharedHistory or {}
    local data = db.sharedHistory[key]
    if not data then
        evict(db.sharedHistory)
        data = {items = {}, count = 0}
        db.sharedHistory[key] = data
    end
    if not trimmed[data] then
        trimmed[data], data.seen, data.opened = true, nil, time()
        S.Trim(data)
    end
    return data
end
function S.Status()
    local inbox, data = S.Inbox(), S.Data()
    local source = "none"
    if usable(inbox) and type(inbox.version) == "string" then
        source = inbox == _G[INBOX_GLOBAL] and "addon" or "file"
    end
    return source, data and data.count or 0
end
local function identity(point)
    return #point.sourceID .. ":" .. point.sourceID .. point.scanID
end
function S.Points(id)
    local data, inbox = S.Data(), S.Inbox()
    if not data then return nil end
    if data.version ~= inbox.version and type(inbox.version) == "string" then
        local merged = data.merged
        if not merged or merged.version ~= inbox.version then
            merged = {version = inbox.version, items = {}, count = 0}
            data.merged = merged
        end
        if not merged.items[id] then
            local group = grouped(inbox)
            local list = data.items[id] or {}
            local before, have, edge = #list, {}, time() - S.limits.days * 86400
            for _, point in ipairs(list) do have[identity(point)] = true end
            for _, point in ipairs(group.items[id] or {}) do
                if valid(point) and point.at >= edge and not have[identity(point)] then
                    have[identity(point)] = true
                    list[#list + 1] = {sourceID = point.sourceID, scanID = point.scanID, at = point.at,
                        since = point.since, price = point.price, p25 = point.p25, lots = point.lots,
                        units = point.units, clockStatus = point.clockStatus}
                end
            end
            table.sort(list, function(a, b)
                if a.at ~= b.at then return a.at < b.at end
                return a.sourceID .. a.scanID < b.sourceID .. b.scanID
            end)
            trimItem(list, edge)
            data.items[id] = #list > 0 and list or nil
            data.count = (data.count or 0) + #list - before
            if data.count > S.limits.points then S.Trim(data) end
            merged.items[id] = true
            if group.items[id] then merged.count = merged.count + 1 end
            if merged.count >= group.count then data.version, data.merged = inbox.version, nil end
        end
    end
    return data.items[id]
end
function S.Quote(id, own)
    local list = S.Points(id)
    local point = list and list[#list]
    if not point or point.at > time() or (own and own.at >= point.at) then return own end
    return {price = point.price, at = point.at, since = point.since, units = point.units, lots = point.lots,
        complete = true, miss = 0, shared = true, sourceID = point.sourceID, scanID = point.scanID,
        clockStatus = point.clockStatus}
end
function S.Merge(id, points, days, volume)
    local result, times = {}, {}
    local inbox = S.Inbox()
    local ownSource = inbox and inbox.localSourceID
    for _, point in ipairs(S.Points(id) or {}) do
        local importedOwn = point.sourceID == ownSource and ns.Store.Scan(point.scanID)
        if not importedOwn and point.at >= time() - days * 86400 and point.at <= time()
            and (volume or point.price) then
            times[point.at] = {at = point.at, price = volume and point.lots or point.price,
                quartile = volume and point.units or (point.p25 or point.price), shared = true,
                sourceID = point.sourceID, scanID = point.scanID}
        end
    end
    for _, point in ipairs(points) do times[point.at] = point end
    for _, point in pairs(times) do result[#result + 1] = point end
    table.sort(result, function(a, b) return a.at < b.at end)
    return result
end
local neutralAuctionZones = {
    ["Booty Bay"] = true, ["Gadgetzan"] = true, ["Everlook"] = true,
}
function ns.Fee()
    return ns.Store.DB().auctionFee == 0.15 and 0.15 or 0.05
end
local feeEvents = ns.NewFrame("Frame")
ns.Listen(feeEvents, "AUCTION_HOUSE_SHOW")
feeEvents:SetScript("OnEvent", function()
    local zone = GetRealZoneText and GetRealZoneText()
    local subzone = GetSubZoneText and GetSubZoneText()
    local neutral = neutralAuctionZones[zone] or neutralAuctionZones[subzone]
    for _, key in ipairs({"neutralBootyBay", "neutralGadgetzan", "neutralEverlook"}) do
        neutral = neutral or zone == ns.T(key) or subzone == ns.T(key)
    end
    ns.Store.DB().auctionFee = neutral and 0.15 or 0.05
    if ns.Trader then ns.Trader.Refresh() end
end)
