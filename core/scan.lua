local ADDON, ns = ...
local Scan = {}
ns.Scan = Scan
local CHUNK = 400
local PAGE = 50
local PAGE_LOG_EVERY = 20
local GAP = 0.3
local MAX_GAP = 8
local BACKOFF = 5
local STALE_STEP = 0.1
local STALE_POLLS = 50
local SETTLE = 0.3
local REREAD = 3
local HOLD = 2
local OWNER_REPEATS = 3
local SHIFT_SHARE = 0.01
local ALL_REREAD_GAP = 1
local PAGE_TIMEOUT = 30
local RETRY = 2
local ALL_TIMEOUT = 300
local PAUSE_LIMIT = 1800
local PARK_LIMIT = 86400
local OVERLAP = 2
local REWIND_AFTER = 120
local S = {
    phase = "idle", mode = "pages", scan = nil, index = 1, count = 0, page = 0, pages = 0,
    expect = 0, miss = 0, retry = {}, rereads = 0, repeated = false, holdUntil = 0, holdOwner = false,
    ownerWaste = 0, filtered = 0, tailCount = 0, tries = 0, gap = GAP, errors = 0, sig = "", stale = 0, sentAt = 0, readAt = 0, nextAt = 0,
    startedAt = 0, pausedAt = 0, open = false,
}
Scan.state = S
Scan.onStatus = nil
Scan.onComplete = nil
local sending = false
local hooked = false
local function cooling()
    return math.max(0, (ns.Store.DB().cooldownUntil or 0) - time())
end
function Scan.Trace(what)
    local stack = (debugstack(3, 4, 6) or ""):gsub("Interface\\AddOns\\", ""):gsub("%s*\n%s*", " < ")
    ns.Store.Log(what .. " phase=" .. S.phase .. " page=" .. (S.page + 1) .. "/" .. S.pages
        .. " t=" .. math.floor(GetTime() - S.startedAt) .. " | " .. stack)
end
local function status(key, ...)
    if Scan.onStatus then Scan.onStatus(ns.T(key, ...)) end
end
local function lotAt(i)
    local name, _, count, quality, _, _, minBid, _, buyout, bid, _, owner = GetAuctionItemInfo("list", i)
    local link = GetAuctionItemLink("list", i)
    local item, suffix = ns.Lot.FromLink(link)
    if not item or not name then return nil end
    local line = ns.Lot.Encode({
        item = item, suffix = suffix, count = count or 1, minBid = minBid or 0,
        buyout = buyout or 0, bid = bid or 0,
        timeLeft = GetAuctionItemTimeLeft("list", i) or 0, owner = owner,
    })
    return line, item, name, quality, link, owner
end
local function readOne(i, lenient)
    local line, item, name, quality, link, owner = lotAt(i)
    if not line then return false end
    if S.scan.itemID and item ~= S.scan.itemID then S.filtered = S.filtered + 1; return true, line end
    if S.scan.scope == "disenchant" then
        local admitted = ns.DisenchantTail.Admit(S.scan, item, link)
        if admitted == nil then return false, line end
        if not admitted then S.filtered = S.filtered + 1; return true, line end
    end
    if not lenient and (not owner or owner == "") then return false, line end
    ns.Store.Item(item, name, quality)
    local seen = S.seen
    if seen and S.page < (S.seenUntil or 0) and (seen[line] or 0) > 0 then
        seen[line] = seen[line] - 1
        return true, line
    end
    local lots = S.scan.lots
    lots[#lots + 1] = line
    return true, line
end
local function signature(count)
    local parts = {}
    local uniform = count > 0
    for i = 1, count do
        local _, _, n, _, _, _, minBid, _, buyout, bid, _, owner = GetAuctionItemInfo("list", i)
        local link = GetAuctionItemLink("list", i)
        parts[i] = tostring(link) .. ":" .. tostring(n) .. ":" .. tostring(minBid)
            .. ":" .. tostring(buyout) .. ":" .. tostring(bid) .. ":" .. tostring(owner)
        if i > 1 and parts[i] ~= parts[i - 1] then uniform = false end
    end
    return table.concat(parts, ";"), uniform
end
local function pageReady(count)
    local named = true
    for i = 1, count do
        local name, _, _, _, _, _, _, _, _, _, _, owner = GetAuctionItemInfo("list", i)
        local link = GetAuctionItemLink("list", i)
        if not name or not link then return false, false end
        if S.scan.scope == "disenchant" and not ns.Compat.ItemInfo(link) then return false, false end
        if not owner or owner == "" then named = false end
    end
    return named or S.ownerWaste >= OWNER_REPEATS, true
end
local function shifted(batch, total)
    local prev, n = S.tail, S.tailCount
    if not prev or not S.lastTotal or total <= S.lastTotal then return 0 end
    for k = math.min(total - S.lastTotal, batch, n), 1, -1 do
        local same = true
        for j = 1, k do
            local a = prev[n - k + j]
            if not a or a ~= lotAt(j) then same = false; break end
        end
        if same then return k end
    end
    return 0
end
local function wholeMarket(scan)
    return scan ~= nil and S.mode == "pages" and not scan.itemID and not scan.family
        and scan.scope ~= "disenchant" and scan.scope ~= "gems" and (not scan.query or scan.query == "")
end
Scan.policies = {
    pause = {slot = "pending", limit = PAUSE_LIMIT, paused = true},
    market = {slot = "unfinished", limit = PARK_LIMIT, market = true},
}
local function marketOf(scan)
    return (scan.realm or "") .. "|" .. (scan.faction or "")
end
local function slot(policy, key)
    local value = ns.Store.DB()[policy.slot]
    if not policy.market then return value end
    return type(value) == "table" and value[key] or nil
end
local function store(policy, key, record)
    local db = ns.Store.DB()
    if not policy.market then db[policy.slot] = record; return end
    local markets = type(db[policy.slot]) == "table" and db[policy.slot] or {}
    markets[key] = record
    db[policy.slot] = next(markets) and markets or nil
end
function Scan.Park(scan, policy)
    local now = GetTime()
    local idle = policy.paused and S.phase == "paused" and math.floor(now - S.pausedAt) or 0
    local record = {scan = scan, page = S.page, pages = S.pages, expect = S.expect, miss = S.miss,
        filtered = S.filtered, at = time() - idle, ran = math.floor(now - S.startedAt)}
    store(policy, marketOf(scan), record)
    return record
end
local function parked(policy)
    local key = ns.Markets.Key()
    if policy.market then
        local markets = ns.Store.DB()[policy.slot]
        for other, p in pairs(type(markets) == "table" and markets or {}) do
            local at = type(p) == "table" and p.at or 0
            if other ~= key and time() - at > policy.limit then store(policy, other, nil) end
        end
    end
    local p = slot(policy, key)
    if type(p) ~= "table" or type(p.scan) ~= "table" or type(p.scan.lots) ~= "table" then return nil end
    local age = time() - (p.at or 0)
    if age > policy.limit then
        store(policy, key, nil)
        return nil, age
    end
    return p, age
end
local function adopt(p)
    S.mode, S.scan, S.page, S.pages = "pages", p.scan, p.page or 0, p.pages or 0
    S.expect, S.miss, S.retry, S.tries, S.rereads = p.expect or 0, p.miss or 0, {}, 0, 0
    S.filtered, S.ownerWaste, S.repeated, S.tail, S.lastTotal = p.filtered or 0, 0, false, nil, nil
    S.gap, S.errors, S.sig, S.stale, S.shownSecs = ns.Query.Gap(), 0, "", 0, nil
    S.seen, S.seenUntil, S.route = nil, nil, ns.DisenchantTail.Route(p.scan)
    S.startedAt = GetTime() - (p.ran or 0)
end
local function park(key)
    local scan = S.scan
    Scan.Park(scan, Scan.policies.market)
    ns.Store.Log("park page=" .. S.page .. "/" .. S.pages .. " lots=" .. #scan.lots)
    Scan.purchaseRequest = nil
    S.phase, S.scan, S.seen, S.seenUntil = "idle", nil, nil, nil
    if key then
        status("stParked", S.page, math.max(S.pages, 1))
    end
end
local function rewind()
    local from = math.max(0, S.page - OVERLAP)
    if from == S.page then return end
    local lots, seen = S.scan.lots, {}
    for i = math.max(1, #lots - (S.page - from) * PAGE + 1), #lots do seen[lots[i]] = (seen[lots[i]] or 0) + 1 end
    S.seen, S.seenUntil, S.page, S.sig = seen, S.page, from, ""
    S.tail, S.lastTotal = nil, nil
end
local function finish()
    local scan = S.scan
    S.seen, S.seenUntil = nil, nil
    if wholeMarket(scan) then Scan.DropParked(marketOf(scan)) end
    ns.DisenchantTail.RestoreSort(scan)
    scan.total = #scan.lots
    scan.expect = S.expect
    scan.miss = S.miss
    if S.mode == "pages" and not S.route and S.expect > 0
        and math.abs(scan.total + S.filtered + S.miss - S.expect) > S.expect * SHIFT_SHARE then
        scan.shifted = true
    end
    scan.secs = time() - scan.t
    if scan.truncated and scan.deScannedPages then scan.deReadPages = scan.deScannedPages end
    local drafts = ns.Store.DB().disenchantDrafts
    if drafts and scan.deGroup then drafts[scan.deGroup] = nil end
    local dropped = ns.Store.Commit(scan)
    ns.Store.Log("done " .. S.mode .. " lots=" .. scan.total .. " expect=" .. S.expect .. " miss=" .. S.miss
        .. " secs=" .. scan.secs .. " errors=" .. S.errors .. " gap=" .. S.gap)
    S.phase, S.scan = "idle", nil
    if S.mode == "all" and S.expect > scan.total + S.miss then status("stDoneCut", scan.total + S.miss, S.expect)
    elseif S.miss > 0 then status("stDoneMiss", scan.total, S.miss)
    else status("stDone", scan.total) end
    if dropped > 0 then ns.Store.Log("dropped old scans=" .. dropped) end
    if Scan.onComplete then Scan.onComplete(scan) end
end
local function fail(key)
    Scan.CheckpointDisenchant()
    Scan.purchaseRequest = nil
    ns.DisenchantTail.RestoreSort(S.scan)
    ns.Store.Log("fail " .. key .. " phase=" .. S.phase .. " page=" .. (S.page + 1) .. "/" .. S.pages)
    S.phase, S.scan, S.seen, S.seenUntil = "idle", nil, nil, nil
    if Scan.onAbort then Scan.onAbort() end
    status(key)
end
local PAUSE_STATUS = {sayForeign = "stPauseForeign", sayRefused = "stPauseRefused",
    sayPageUnchanged = "stPauseUnchanged", sayNoAnswer = "stPauseNoAnswer", sayAfk = "stPauseAfk",
    sayClosed = "stPauseClosed"}
local function pause(key)
    Scan.purchaseRequest = nil
    ns.Store.Log("pause " .. key .. " phase=" .. S.phase .. " page=" .. (S.page + 1) .. "/" .. S.pages)
    S.phase, S.pausedAt = "paused", GetTime()
    status(PAUSE_STATUS[key] or "stPaused", S.page + 1, math.max(S.pages, 1))
end
local function onForeign()
    if sending or S.phase == "idle" or S.phase == "paused" then return end
    Scan.Trace("foreign query")
    if S.mode == "all" then return fail("stForeignAll") end
    pause("sayForeign")
end
local function send()
    sending = true
    local scan = S.scan
    local sent = ns.Query.Send(scan.query or "", S.page, false, {classIndex = scan.classIndex,
        subClassIndex = scan.subClassIndex, minLevel = scan.minLevel, maxLevel = scan.maxLevel,
        minQuality = scan.minQuality, sort = ns.DisenchantTail.Sort(scan)})
    sending = false
    if not sent then return end
    S.phase, S.sentAt, S.rereads = "wait", GetTime(), 0
end
local function refused(now, why)
    S.errors, S.tries = S.errors + 1, S.tries + 1
    S.gap = math.min(S.gap * 2, MAX_GAP)
    ns.Store.DB().scanGap = S.gap
    ns.Store.Log("refused " .. why .. " page=" .. (S.page + 1) .. "/" .. S.pages .. " try=" .. S.tries .. " gap=" .. S.gap)
    if why == "error" or S.tries > RETRY then
        ns.Store.DB().cooldownUntil = time() + 120
        return pause("sayRefused")
    end
    S.phase, S.nextAt = "send", now + BACKOFF * S.tries
    status("stBackoff", BACKOFF * S.tries)
end
local function readPage(now)
    local batch, total = GetNumAuctionItems("list")
    batch, total = batch or 0, total or 0
    if batch == 0 and (total > S.page * PAGE or (S.page > 0 and total == 0)) then
        return refused(now, "empty")
    end
    local sig, uniform = signature(batch)
    if S.page > 0 and sig == S.sig then
        if S.stale < STALE_POLLS then
            S.stale, S.readAt = S.stale + 1, now + STALE_STEP
            return
        end
        S.stale = 0
        if not uniform then
            ns.Store.Log("unchanged page=" .. (S.page + 1) .. " wait=" .. string.format("%.2f", now - S.sentAt))
            return pause("sayPageUnchanged")
        end
        ns.Store.Log("identical stacks page=" .. (S.page + 1) .. " lots=" .. batch)
    end
    local ready, known = pageReady(batch)
    if not ready and S.rereads < REREAD then
        S.rereads = S.rereads + 1
        S.readAt = now + SETTLE
        return
    end
    if not ready and not S.repeated then
        S.phase, S.holdUntil, S.readAt, S.holdOwner = "hold", now + HOLD, now + SETTLE, known
        return
    end
    if S.repeated and S.holdOwner and not ready then
        S.ownerWaste = S.ownerWaste + 1
        ns.Store.Log("owners missing page=" .. (S.page + 1) .. " waste=" .. S.ownerWaste)
    end
    local skip = shifted(batch, total)
    if skip > 0 then ns.Store.Log("shift page=" .. (S.page + 1) .. " repeated=" .. skip) end
    local tail = {}
    for i = 1, batch do
        local read, line
        if i <= skip then read, line = true, lotAt(i) else read, line = readOne(i, true) end
        if not read then S.miss = S.miss + 1 end
        tail[i] = line or false
    end
    S.tail, S.tailCount, S.lastTotal, S.repeated = tail, batch, total, false
    if S.page == 0 then S.expect = (S.route and S.route.Base(S.scan) or 0) + total end
    if S.page % PAGE_LOG_EVERY == 0 then
        ns.Store.Log("page read=" .. (S.page + 1) .. " lots=" .. batch .. " total=" .. total
            .. " response=" .. string.format("%.2f", now - S.sentAt))
    end
    S.sig, S.stale = sig, 0
    S.pages = math.ceil(total / PAGE)
    S.page, S.tries = S.page + 1, 0
    local route = S.route
    if route then
        route.Read(S.scan, S.page)
        if Scan.purchaseRequest then return Scan.CompletePurchaseRequest() end
        S.scan.miss = S.miss
        local cut = route.Cut(S.scan, batch, S.page < S.pages)
        if cut == "finish" then return finish() end
        if cut == "class" then S.page = S.pages end
    end
    if S.page >= S.pages then
        if not (route and route.Next(S.scan, S.expect)) then return finish() end
        S.page, S.pages, S.sig, S.stale, S.rereads = 0, 0, "", 0, 0
        S.tail, S.lastTotal = nil, nil
        S.phase, S.nextAt = "send", math.max(now, S.sentAt + S.gap)
        return
    end
    S.phase, S.nextAt = "send", math.max(now, S.sentAt + S.gap)
    local left = math.ceil((now - S.startedAt) / S.page * (S.pages - S.page) / 60)
    status("stPageEta", S.page + 1, S.pages, left)
end
local function hold(now)
    if now < S.readAt then return end
    if pageReady(GetNumAuctionItems("list") or 0) then
        S.phase, S.readAt = "settle", now
        return
    end
    if now < S.holdUntil then S.readAt = now + SETTLE; return end
    ns.Store.Log("repeat page=" .. (S.page + 1) .. " owners=" .. tostring(S.holdOwner))
    S.repeated = true
    S.phase, S.nextAt = "send", math.max(now, S.sentAt + S.gap)
end
local function readChunk(now)
    local last = math.min(S.index + CHUNK - 1, S.count)
    for i = S.index, last do
        if not readOne(i) then S.retry[#S.retry + 1] = i end
    end
    S.index = last + 1
    status("stRead", last, S.count)
    if S.index <= S.count then return end
    if #S.retry == 0 then return finish() end
    S.phase, S.readAt, S.rereads = "reread", now + ALL_REREAD_GAP, 0
end
local function reread(now)
    local left, lenient = {}, S.rereads + 1 >= REREAD
    for _, i in ipairs(S.retry) do
        if not readOne(i, lenient) then left[#left + 1] = i end
    end
    S.retry, S.rereads = left, S.rereads + 1
    if #left == 0 or S.rereads >= REREAD then
        S.miss = #left
        return finish()
    end
    S.readAt = now + ALL_REREAD_GAP
end
function Scan.Same(scan, target)
    if not scan then return false end
    local scope = (target.scope == "gems" or target.scope == "disenchant") and target.scope
        or (target.family and "family") or (target.itemID and "item") or "query"
    local query = scope == "gems" and "" or ns.Query.Name(target.query or "")
    return scan.scope == scope and scan.deGroup == target.deGroup and scan.gemGroup == target.gemGroup
        and scan.itemID == target.itemID and scan.family == target.family and (scan.query or "") == query
end
function Scan.Start(mode, target)
    if ns.Buy and ns.Buy.Active() then ns.say(ns.T("sayBusy")); return false end
    if not hooked then
        hooksecurefunc("QueryAuctionItems", onForeign)
        hooked = true
    end
    if cooling() > 0 then
        ns.say(ns.T("tradeCooling", math.ceil(cooling())))
        return false
    end
    if S.phase == "paused" then
        local other = target and not Scan.Same(S.scan, target)
        if other and wholeMarket(S.scan) then
            if S.page > 0 then park("sayParked") else S.phase, S.scan = "idle", nil end
        elseif other then
            ns.say(ns.T("tradeOtherScan"))
            return false
        elseif not S.open then
            ns.say(ns.T("sayNoAuction"))
            return false
        elseif wholeMarket(S.scan) or GetTime() - S.pausedAt <= PAUSE_LIMIT then
            if GetTime() - S.pausedAt > REWIND_AFTER then rewind() end
            ns.Store.Log("resume page=" .. (S.page + 1) .. "/" .. S.pages)
            S.phase, S.nextAt, S.tries = "send", GetTime(), 0
            status("stPage", S.page + 1, tostring(math.max(S.pages, 1)))
            return true
        else
            ns.DisenchantTail.RestoreSort(S.scan)
            S.phase, S.scan = "idle", nil
            ns.say(ns.T("sayStale"))
        end
    end
    if S.phase ~= "idle" then
        ns.say(ns.T("sayBusy"))
        return false
    end
    if not S.open then
        ns.say(ns.T("sayNoAuction"))
        return false
    end
    local _, canMass = CanSendAuctionQuery("list")
    if mode == "all" and not canMass then
        status("stMassWait")
        return false
    end
    if mode == "all" and not ns.Query.Ready(true) then ns.say(ns.T("sayBusy")); return false end
    if target and not ns.DisenchantTail.Ready(target) then
        if Scan.onStatus then Scan.onStatus(ns.DisenchantTail.BlockedText(ns.Disenchant.blocked)) end
        return false
    end
    S.mode, S.scan, S.index, S.count = mode, ns.Store.Begin(mode), 1, 0
    if target then
        S.scan.scope, S.scan.itemID, S.scan.query = target.itemID and "item" or "query", target.itemID, ns.Query.Name(target.query)
        S.scan.family = target.family
        S.scan.classIndex, S.scan.subClassIndex = ns.Compat.AuctionFilter(target.itemID or target.family)
        if target.family then S.scan.scope = "family" end
        if target.scope == "gems" then
            S.scan.scope, S.scan.gemGroup, S.scan.query = "gems", target.gemGroup, ""
            S.scan.classIndex, S.scan.subClassIndex, S.scan.minQuality = target.classIndex, nil, target.minQuality
        end
        if target.scope == "disenchant" then ns.DisenchantTail.Begin(S.scan, target) end
    end
    S.route = ns.DisenchantTail.Route(S.scan)
    S.page, S.pages, S.expect, S.miss, S.retry, S.seen, S.seenUntil = 0, 0, 0, 0, {}, nil, nil
    S.filtered, S.ownerWaste, S.repeated, S.tail, S.lastTotal = 0, 0, false, nil, nil
    S.tries, S.rereads, S.shownSecs, S.startedAt = 0, 0, nil, GetTime()
    S.gap, S.errors, S.sig, S.stale = ns.Query.Gap(), 0, "", 0
    ns.Store.Log("start " .. mode .. " item=" .. tostring(S.scan.itemID or 0))
    if mode == "all" then
        sending = true
        ns.Query.Send("", nil, true)
        sending = false
        S.phase, S.sentAt = "wait", GetTime()
        status("stAllWait")
    else
        S.phase, S.nextAt = "send", 0
        status("stPage", 1, "?")
    end
    return true
end
function Scan.OnListUpdate()
    if S.phase == "hold" then S.readAt = math.min(S.readAt, GetTime()); return end
    if S.phase ~= "wait" and S.phase ~= "settle" then return end
    local now = GetTime()
    S.phase, S.readAt = "settle", now + SETTLE
end
function Scan.OnUpdate(elapsed)
    local phase = S.phase
    if phase == "idle" or phase == "paused" then return end
    local now = GetTime()
    if phase == "send" then
        if cooling() <= 0 and now >= S.nextAt and ns.Query.Ready() then send() end
    elseif phase == "settle" then
        if now < S.readAt then return end
        if S.mode == "pages" then return readPage(now) end
        local batch, total = GetNumAuctionItems("list")
        S.count, S.expect, S.index, S.phase = batch or 0, total or 0, 1, "read"
        status("stRead", 0, S.count)
    elseif phase == "hold" then
        hold(now)
    elseif phase == "read" then
        readChunk(now)
    elseif phase == "reread" then
        if now >= S.readAt then reread(now) end
    elseif phase == "wait" then
        local waited = now - S.sentAt
        if S.mode == "pages" then
            if waited <= PAGE_TIMEOUT then return end
            ns.Store.Log("no response page=" .. (S.page + 1) .. " wait=" .. math.floor(waited))
            return pause("sayNoAnswer")
        elseif waited > ALL_TIMEOUT then
            fail("stAllTimeout")
        else
            local secs = math.floor(waited)
            if secs ~= S.shownSecs then
                S.shownSecs = secs
                status("stAllWaitSecs", secs, ALL_TIMEOUT)
            end
        end
    end
end
function Scan.Stop()
    if S.phase == "idle" then return false end
    ns.Store.DB()[Scan.policies.pause.slot] = nil
    if wholeMarket(S.scan) and S.page > 0 then park("sayParked"); return true end
    fail("stStopped")
    return true
end
function Scan.Release()
    if S.phase == "paused" and wholeMarket(S.scan) then
        if S.page > 0 then park("sayParked") else S.phase, S.scan = "idle", nil end
    end
    return S.phase == "idle"
end
function Scan.Parked()
    return (parked(Scan.policies.market))
end
function Scan.DropParked(key)
    store(Scan.policies.market, key or ns.Markets.Key(), nil)
end
function Scan.ResumeParked()
    local p = Scan.Parked()
    if not p then return false end
    if (ns.Buy and ns.Buy.Active()) or S.phase ~= "idle" then ns.say(ns.T("sayBusy")); return false end
    if cooling() > 0 then ns.say(ns.T("tradeCooling", math.ceil(cooling()))); return false end
    if not S.open then ns.say(ns.T("sayNoAuction")); return false end
    if not hooked then
        hooksecurefunc("QueryAuctionItems", onForeign)
        hooked = true
    end
    Scan.DropParked()
    adopt(p)
    rewind()
    S.scan.resumes = (S.scan.resumes or 0) + 1
    ns.Store.Log("rescan page=" .. (S.page + 1) .. "/" .. S.pages .. " lots=" .. #S.scan.lots)
    S.phase, S.nextAt = "send", GetTime()
    status("stPage", S.page + 1, tostring(math.max(S.pages, 1)))
    return true
end
function Scan.CheckpointDisenchant()
    local scan = S.scan
    if not scan or scan.scope ~= "disenchant" or (scan.deScannedPages or S.page) < 1 then return end
    local draft = {}
    for key, value in pairs(scan) do draft[key] = value end
    draft.truncated, draft.deSavedPartial = true, true
    draft.deReadPages = scan.deScannedPages or S.page
    draft.total, draft.expect, draft.miss, draft.secs = #draft.lots, S.expect, S.miss, time() - draft.t
    local db = ns.Store.DB(); db.disenchantDrafts = db.disenchantDrafts or {}
    db.disenchantDrafts[scan.deGroup] = draft
    return draft
end
function Scan.CompletePurchaseRequest()
    local request = Scan.purchaseRequest
    if not request then return false end
    local draft = Scan.CheckpointDisenchant()
    Scan.purchaseRequest = nil
    if not draft then return false end
    fail("stStopped")
    request.ready()
    return true
end
function Scan.SnapshotForPurchase(key, ready)
    if Scan.purchaseRequest or not S.scan or S.scan.deGroup ~= key then return false end
    Scan.purchaseRequest = {key = key, ready = ready}
    if S.phase == "send" or S.phase == "paused" then return Scan.CompletePurchaseRequest() end
    return true
end
function Scan.ResetPace()
    if not Scan.Release() or (ns.Buy and ns.Buy.Active()) then ns.say(ns.T("sayBusy")); return false end
    if cooling() > 0 then ns.say(ns.T("tradeCooling", math.ceil(cooling()))); return false end
    ns.Store.DB().scanGap = nil
    S.gap = ns.Query.Gap()
    ns.Store.Log("pace reset gap=" .. S.gap)
    return true
end
function Scan.OnAfk()
    if not UnitIsAFK("player") or S.mode ~= "pages" then return end
    if S.phase == "idle" or S.phase == "paused" then return end
    pause("sayAfk")
end
function Scan.OnMessage(event, text)
    if S.phase == "idle" or not text then return end
    ns.Store.Log(event .. " page=" .. (S.page + 1) .. "/" .. S.pages .. " t=" .. math.floor(GetTime() - S.startedAt) .. " " .. text)
    if event ~= "UI_ERROR_MESSAGE" or text ~= ERR_AUCTION_DATABASE_ERROR then return end
    if S.mode == "pages" and S.phase ~= "paused" then refused(GetTime(), "error") end
end
function Scan.Save()
    Scan.CheckpointDisenchant()
    local db = ns.Store.DB()
    db[Scan.policies.pause.slot] = nil
    if S.phase == "idle" or S.mode ~= "pages" or not S.scan then return end
    if wholeMarket(S.scan) and S.page > 0 then return park(nil) end
    Scan.Park(S.scan, Scan.policies.pause)
    if S.phase == "paused" then
        ns.Store.Log("saved page=" .. (S.page + 1) .. "/" .. S.pages .. " lots=" .. #S.scan.lots)
    end
end
function Scan.Restore()
    local p, age = parked(Scan.policies.pause)
    ns.Store.DB()[Scan.policies.pause.slot] = nil
    if not p then
        if age then ns.Store.Log("pending stale age=" .. age) end
        return
    end
    adopt(p)
    S.phase, S.pausedAt = "paused", GetTime() - age
    ns.Store.Log("restored page=" .. (S.page + 1) .. "/" .. S.pages .. " lots=" .. #S.scan.lots)
    status("stRestored", S.page + 1, math.max(S.pages, 1))
end
function Scan.OnShow()
    S.open = true
end
function Scan.OnClose()
    S.open = false
    Scan.CheckpointDisenchant()
    if S.phase == "idle" or S.phase == "paused" then return end
    Scan.Trace("AUCTION_HOUSE_CLOSED")
    if S.mode == "pages" then return pause("sayClosed") end
    fail("stClosed")
end
