local ADDON, ns = ...
local Store = {}
ns.Store = Store
local MAX_LOG = 60
Store.VERSION = 3
Store.EXCHANGE = 1
Store.RAW_DAYS = 30
Store.RAW_BYTES = 150 * 1024 * 1024
Store.LUA_KEYS = 262143
Store.FILE_KEYS = 200000
Store.OTHER_KEYS_TTL = 600
Store.VALUABLE = {"ledger", "disenchantLog", "recipeBook", "alchemyPrices", "disenchantPrices", "collections",
    "hidden", "buyHistory", "stock", "reagentPolicy", "auctionFee", "mailPanel", "auctionWindow",
    "disenchantUI", "prospectUI", "bargainUI"}
Store.migrations = {}
Store.migrations[2] = function(db)
    local gems = db.gemHistory
    db.gemHistory = nil
    if type(gems) ~= "table" then return end
    db.activityHistory = db.activityHistory or {}
    for key, items in pairs(gems) do
        local market = db.activityHistory[key]
        if not market then
            market = {items = {}, at = 0}
            db.activityHistory[key] = market
        end
        for id, series in pairs(items) do
            local points, byScan = market.items[id] or {}, {}
            for _, point in ipairs(points) do byScan[point.scanID or ""] = point end
            for _, q in ipairs(series) do
                local point = q.scan and byScan[q.scan]
                if point then
                    point.p25 = point.p25 or q.quartile
                else
                    points[#points + 1] = {at = q.at, scanID = q.scan, price = q.price, p25 = q.quartile,
                        lots = q.lots, units = q.units}
                    market.at = math.max(market.at or 0, q.at or 0)
                end
            end
            table.sort(points, function(a, b) return a.at < b.at end)
            if #points > 0 then market.items[id] = points end
        end
    end
end
Store.migrations[3] = function(db)
    local p = db.unfinished
    if type(p) == "table" and type(p.scan) == "table" then
        db.unfinished = {[tostring(p.scan.realm or "") .. "|" .. tostring(p.scan.faction or "")] = p}
    end
end
local function migrate(db)
    local from = tonumber(db.v) or 0
    if from > Store.VERSION then return end
    for v = from + 1, Store.VERSION do
        if Store.migrations[v] then Store.migrations[v](db) end
    end
    db.v = Store.VERSION
end
function Store.Born()
    return string.format("%x-%04x", time(), math.random(0, 65535))
end
function Store.DB()
    local db = AuctionScanDB
    if type(db) ~= "table" then
        db = { v = Store.VERSION }
        AuctionScanDB = db
    elseif db.v ~= Store.VERSION then
        migrate(db)
    end
    db.born = db.born or Store.Born()
    db.exchange = Store.EXCHANGE
    db.maxScans = 0
    db.storageNotice = nil
    db.seq = db.seq or 0
    db.scans = db.scans or {}
    db.items = db.items or {}
    db.log = db.log or {}
    return db
end
local function scanBytes(scan)
    local bytes = 512
    for _, text in ipairs(scan.lots) do bytes = bytes + #text + 24 end
    for _ in pairs(scan.disenchantItems or {}) do bytes = bytes + 120 end
    return bytes
end
function Store.Usage()
    local db = Store.DB()
    if db.scanBytesCount ~= #db.scans then
        db.scanBytes = 0
        for _, scan in ipairs(db.scans) do db.scanBytes = db.scanBytes + scanBytes(scan) end
        db.scanBytesCount = #db.scans
    end
    return db.scanBytes or 0
end
local function constants(value, visit, seen)
    local n = #value
    for k, v in pairs(value) do
        local tk = type(k)
        if tk == "string" or (tk == "number" and not (k >= 1 and k <= n and k % 1 == 0)) then visit(k) end
        local tv = type(v)
        if tv == "table" then
            if not seen[v] then seen[v] = true; constants(v, visit, seen) end
        elseif tv == "string" or tv == "number" then
            visit(v)
        end
    end
end
local refs
local rawKeys = 0
local refsList
local refsCount = 0
local otherKeys, otherAt = 0, -math.huge
local function countScan(scan, delta)
    local map = refs
    if not map then return end
    constants(scan, function(c)
        local r = (map[c] or 0) + delta
        if r <= 0 then
            if map[c] then rawKeys = rawKeys - 1 end
            map[c] = nil
        else
            if not map[c] then rawKeys = rawKeys + 1 end
            map[c] = r
        end
    end, {})
end
local function buildRefs(db)
    refs, rawKeys, refsList, refsCount = {}, 0, db.scans, #db.scans
    for _, scan in ipairs(db.scans) do countScan(scan, 1) end
end
local function liveRefs(db)
    if refs and (refsList ~= db.scans or refsCount ~= #db.scans) then refs = nil end
    return refs ~= nil
end
local function otherCount(db, force)
    local now = time()
    if not force and now - otherAt < Store.OTHER_KEYS_TTL then return otherKeys end
    local set, count = {}, 0
    local function visit(c) if not set[c] then set[c] = true; count = count + 1 end end
    local seen = {[db.scans] = true}
    for k, v in pairs(db) do
        visit(k)
        if type(v) == "table" then
            if not seen[v] then seen[v] = true; constants(v, visit, seen) end
        elseif type(v) == "string" or type(v) == "number" then
            visit(v)
        end
    end
    otherKeys, otherAt = count, now
    return count
end
function Store.Keys(force)
    local db = Store.DB()
    local other = otherCount(db, force)
    if not liveRefs(db) then
        local lines = 0
        for _, scan in ipairs(db.scans) do
            lines = lines + #scan.lots + 32
            for _ in pairs(scan.disenchantItems or {}) do lines = lines + 16 end
        end
        if lines + other <= Store.FILE_KEYS then return lines + other, false end
        buildRefs(db)
    end
    return rawKeys + other, true
end
function Store.Begin(mode)
    local db = Store.DB()
    db.seq = db.seq + 1
    local t = time()
    local realm, faction = GetRealmName() or "", UnitFactionGroup("player") or ""
    return {
        id = realm .. "|" .. faction .. "|" .. t .. "|" .. db.seq,
        t = t,
        realm = realm,
        faction = faction,
        mode = mode,
        total = 0,
        secs = 0,
        lots = {},
    }
end
function Store.Item(id, name, quality)
    local items = Store.DB().items
    if not items[id] and name then
        items[id] = name .. "\t" .. tostring(quality or 0)
        Store.itemsVersion = (Store.itemsVersion or 0) + 1
    end
end
function Store.Log(text)
    local log = Store.DB().log
    log[#log + 1] = date("%d.%m %H:%M:%S") .. " " .. text
    while #log > MAX_LOG do table.remove(log, 1) end
end
local byID
local scansVersion = 0
function Store.Scan(id)
    if not id then return nil end
    local scans = Store.DB().scans
    if not byID or byID.list ~= scans or byID.count ~= #scans or byID.version ~= scansVersion then
        byID = {list = scans, count = #scans, version = scansVersion, scans = {}}
        for _, scan in ipairs(scans) do byID.scans[scan.id] = scan end
    end
    return byID.scans[id]
end
local function keepers(scans)
    local keep, seen = {}, {}
    for i = #scans, 1, -1 do
        local scan = scans[i]
        local key = tostring(scan.realm) .. "|" .. tostring(scan.faction)
        if not seen[key] and ns.Bargain and ns.Bargain.IsFull(scan) then seen[key], keep[scan] = true, true end
    end
    if scans[#scans] then keep[scans[#scans]] = true end
    return keep
end
function Store.Rotate(now)
    local db = Store.DB()
    local scans = db.scans
    local bytes, edge = Store.Usage(), (now or time()) - Store.RAW_DAYS * 86400
    local keys, exact = Store.Keys()
    local other = exact and keys - rawKeys or 0
    local keep, kept, total = keepers(scans), 0, #scans
    for i = 1, total do
        local scan = scans[i]
        local crowded = exact and rawKeys + other > Store.FILE_KEYS
        if not keep[scan] and ((scan.t or 0) + (scan.secs or 0) < edge or bytes > Store.RAW_BYTES or crowded) then
            bytes = bytes - scanBytes(scan)
            if exact then countScan(scan, -1) end
        else
            kept = kept + 1
            scans[kept] = scan
        end
    end
    for i = total, kept + 1, -1 do scans[i] = nil end
    db.scanBytes, db.scanBytesCount = bytes, kept
    if exact then refsCount, keys = kept, rawKeys + other end
    Store.overKeys = keys > Store.FILE_KEYS and keys or nil
    if kept < total then
        scansVersion = scansVersion + 1
        Store.Log("rotate scans=" .. (total - kept) .. " left=" .. kept .. " bytes=" .. bytes .. " keys=" .. keys)
    end
    if Store.overKeys then Store.Log("keys over budget keys=" .. keys .. " budget=" .. Store.FILE_KEYS) end
    return total - kept
end
local function derive(what, fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then return result end
    Store.Log("cache " .. what .. " error " .. tostring(result))
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(result) end
    return nil
end
function Store.Commit(scan)
    local db = Store.DB()
    local bytes = Store.Usage()
    local scans = db.scans
    local counted = liveRefs(db)
    scans[#scans + 1] = scan
    if counted then countScan(scan, 1); refsCount = #scans end
    scansVersion = scansVersion + 1
    db.scanBytes, db.scanBytesCount = bytes + scanBytes(scan), #scans
    local parsed = ns.Markets and derive("markets", ns.Markets.Remember, scan)
    if ns.Family then derive("family", ns.Family.Record, scan, parsed and parsed.lots) end
    return Store.Rotate()
end
