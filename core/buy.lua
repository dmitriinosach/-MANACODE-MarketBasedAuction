local _, ns = ...
local Buy = {}
ns.Buy = Buy
local PAGE = 50
local SETTLE = 0.3
local REREAD = 3
local AFTER_BUY = 2
local TIMEOUT = 10
local SEND_LIMIT = 30
local PENDING = 5
local NAME_BYTES = 63
local R = {
    phase = "idle", name = "", plan = nil, want = {}, page = 0, pages = 0, pass = 1, startPage = 0,
    matches = {}, rereads = 0, bought = 0, spent = 0, refused = 0, pending = {},
    sentAt = 0, readAt = 0, nextAt = 0,
}
Buy.state = R
Buy.onChange = nil
Buy.history = {}
local function note(item, offer, sign)
    if not item then return end
    local h = Buy.history[item] or {units = 0, bids = 0, spent = 0, bidSpent = 0, at = 0}
    if offer.bid then
        h.bids, h.bidSpent = math.max(0, h.bids + sign * offer.stack), math.max(0, h.bidSpent + sign * offer.bid)
    else
        h.units, h.spent = math.max(0, h.units + sign * offer.stack), math.max(0, h.spent + sign * offer.buyout)
    end
    if sign > 0 then h.at = time() end
    Buy.history[item] = h
end
function Buy.Bought(item, since)
    local h = Buy.history[item]
    if not h or h.units + h.bids == 0 or h.at < (since or 0) then return nil end
    return h
end
local BID_KEYS = {sayBuyDone = "sayBidDone", sayBuyShort = "sayBidShort", sayBuyStopped = "sayBidStopped",
    sayBuyForeign = "sayBidForeign"}
local sending = false
local hooked = false
local function changed()
    if Buy.onChange then Buy.onChange() end
end
local function utf8cut(s, bytes)
    if #s <= bytes then return s end
    local cut = bytes
    while cut > 0 do
        local b = s:byte(cut + 1)
        if not b or b < 128 or b >= 192 then break end
        cut = cut - 1
    end
    return s:sub(1, cut)
end
local function queryName(name)
    if #name <= NAME_BYTES then return name end
    local out = ""
    for word in name:gmatch("%S+") do
        local cand = out == "" and word or out .. " " .. word
        if #cand > NAME_BYTES then break end
        out = cand
    end
    return out ~= "" and out or utf8cut(name, NAME_BYTES)
end
function Buy.Active()
    return R.phase ~= "idle"
end
function Buy.Left()
    local n = 0
    for _, k in pairs(R.want) do n = n + k end
    return n
end
local function stop(key, ...)
    ns.DisenchantTail.RestoreSort(R.filter)
    R.stopKey = key
    R.phase, R.matches = "idle", {}
    ns.say(ns.T(R.bidding and BID_KEYS[key] or key, ...))
    changed()
end
local function finish(delay)
    R.phase, R.nextAt, R.matches = "finish", GetTime() + delay, {}
    changed()
end
local function onForeign()
    if sending or R.phase == "idle" or R.phase == "finish" then return end
    stop("sayBuyForeign", R.bought, GetCoinTextureString(R.spent))
end
local function nextRoute()
    local routes = R.filter and R.filter.routes
    if not routes then return false end
    R.route = (R.route or 0) + 1
    local route = routes[R.route]
    if not route then return false end
    R.filter.classIndex, R.filter.maxPages = route.classIndex, route.maxPages
    R.filter.minLevel, R.filter.maxLevel = route.minLevel or R.filter.minLevel, route.maxLevel or R.filter.maxLevel
    R.page, R.pages, R.pass = 0, 0, 1
    R.phase, R.nextAt = "send", GetTime()
    return true
end
local function send()
    sending = true
    local class, sub = ns.Compat.AuctionFilter(R.itemID)
    local filter = R.filter or {classIndex = class, subClassIndex = sub}
    filter.sort = ns.DisenchantTail.Sort(filter)
    local sent = ns.Query.Send(queryName(R.name), R.page, false, filter)
    sending = false
    if not sent then return end
    R.phase, R.sentAt = "wait", GetTime()
    changed()
end
local function shortage()
    local need = R.plan.need
    stop("sayBuyShort", R.bought, need, math.max(0, need - R.bought))
end
local function match(i, me, strict, taken)
    local name, _, count, _, _, _, _, _, buyout, _, _, owner = GetAuctionItemInfo("list", i)
    if not name or (strict and not owner) then return nil end
    if R.lookup then
        if not owner or owner == me or not count or not buyout then return false end
        local id, suffix = ns.Lot.FromLink(GetAuctionItemLink("list", i))
        if not id then return nil end
        local offer = R.lookup[ns.Lot.Key(id, suffix, count, buyout, owner)]
        if offer and (R.want[offer] or 0) > (taken[offer] or 0) and (not R.guard or R.guard(i)) then return offer end
        return false
    end
    if not owner or owner == me or (name ~= R.name and not (R.guard and R.itemID)) then return false end
    if R.itemID and ns.Lot.FromLink(GetAuctionItemLink("list", i)) ~= R.itemID then return false end
    for offer, k in pairs(R.want) do
        if k > (taken[offer] or 0) and count == offer.stack and buyout == offer.buyout then return offer end
    end
    return false
end
local function readPage()
    local batch, total = GetNumAuctionItems("list")
    batch, total = batch or 0, total or 0
    if batch == 0 and total > R.page * PAGE then
        ns.Query.Cooldown(120)
        return stop("sayBuyRefused")
    end
    local me = UnitName("player")
    local strict = R.rereads < REREAD
    local found, taken, cold, money = {}, {}, false, GetMoney()
    for i = 1, batch do
        local offer = match(i, me, strict, taken)
        if offer == nil then
            cold = true
        elseif offer then
            found[#found + 1] = { index = i, offer = offer }
            taken[offer] = (taken[offer] or 0) + 1
        end
    end
    if cold and strict then
        R.rereads, R.readAt = R.rereads + 1, GetTime() + SETTLE
        return
    end
    if R.lookup or R.plan.priceLimit then
        table.sort(found, function(a, b)
            local left = a.offer.priority or a.offer.percent or -a.offer.buyout / a.offer.stack
            local right = b.offer.priority or b.offer.percent or -b.offer.buyout / b.offer.stack
            if left ~= right then return left > right end
            return a.offer.buyout < b.offer.buyout
        end)
        local affordable = {}
        for _, entry in ipairs(found) do
            local price = entry.offer.bid or entry.offer.buyout
            if price <= money then
                affordable[#affordable + 1] = entry; money = money - price
            end
        end
        found = affordable
        table.sort(found, function(a, b) return a.index < b.index end)
    end
    R.pages = math.ceil(total / PAGE)
    if R.filter and R.filter.maxPages then R.pages = math.min(R.pages, R.filter.maxPages) end
    if #found > 0 then
        R.matches, R.phase = found, "ready"
        return changed()
    end
    if R.page + 1 < R.pages then
        R.page, R.phase, R.nextAt = R.page + 1, "send", GetTime()
        return changed()
    end
    if R.pass == 1 and R.startPage > 0 then
        R.pass, R.page, R.phase, R.nextAt = 2, 0, "send", GetTime()
        return changed()
    end
    if nextRoute() then return changed() end
    shortage()
end
function Buy.Start(name, plan, itemID, guard, category)
    if Buy.Active() then return false end
    if not ns.Scan.state.open then ns.say(ns.T("sayNoAuction")); return false end
    if not ns.Scan.Release() then ns.say(ns.T("sayBusy")); return false end
    if ns.Query.Cooling() > 0 then ns.say(ns.T("tradeCooling", math.ceil(ns.Query.Cooling()))); return false end
    for _, pending in ipairs(R.pending) do
        if pending.expires > GetTime() then ns.say(ns.T("buySettling")); return false end
    end
    if not plan or plan.lots <= 0 then return false end
    if not hooked then
        hooksecurefunc("QueryAuctionItems", onForeign)
        hooked = true
    end
    R.name, R.plan, R.want, R.itemID = name, ns.Plan.Copy(plan), {}, itemID
    R.guard, R.stopKey = guard, nil
    R.filter, R.lookup = category and category.filter, category and category.lookup
    R.bidding = category and category.bid or false
    local start
    for _, p in ipairs(R.plan.picks) do
        if p.lots > 0 then
            R.want[p.offer] = p.lots
            local page = p.offer.page or 0
            if not start or page < start then start = page end
        end
    end
    R.startPage, R.page, R.pages, R.pass = start or 0, start or 0, 0, 1
    R.bought, R.spent, R.refused, R.pending, R.matches = 0, 0, 0, {}, {}
    R.phase, R.nextAt = "send", GetTime()
    R.route = 0
    if R.filter and R.filter.routes then nextRoute() end
    changed()
    return true
end
function Buy.StartCategory(plan, filter, guard)
    local lookup = {}
    for _, pick in ipairs(plan.picks) do
        local offer = pick.offer
        if not offer.key or lookup[offer.key] then return false end
        lookup[offer.key] = offer
    end
    return Buy.Start("", plan, nil, guard, {filter = filter, lookup = lookup})
end
local function stillThere(m, me)
    local name, _, count, _, _, _, _, _, buyout, _, _, owner = GetAuctionItemInfo("list", m.index)
    local item, suffix = ns.Lot.FromLink(GetAuctionItemLink("list", m.index))
    if R.lookup then
        return item and owner and owner ~= me and count and buyout
            and ns.Lot.Key(item, suffix, count, buyout, owner) == m.offer.key
    end
    return (name == R.name or (R.guard and R.itemID)) and count == m.offer.stack and buyout == m.offer.buyout and owner ~= nil and owner ~= me
        and (not R.itemID or item == R.itemID)
end
function Buy.Confirm()
    if R.phase ~= "ready" or not ns.Scan.state.open then return false end
    local me = UnitName("player")
    if R.guard then
        for _, match in ipairs(R.matches) do
            if not stillThere(match, me) or not R.guard(match.index) then stop("deBuyChanged"); return false end
        end
    end
    local money, now = GetMoney(), GetTime()
    local bids, per, poor = 0, {}, false
    for index = 1, #R.matches do
        local m = R.matches[R.lookup and (#R.matches - index + 1) or index]
        local o = m.offer
        local amount = o.bid or o.buyout
        if (R.want[o] or 0) > 0 and stillThere(m, me) then
            if money < amount then
                poor = true
            else
                local observer = ns.AccountingEvents
                local before = observer and observer.last
                local item = ns.Lot.FromLink(GetAuctionItemLink("list", m.index)) or R.itemID
                PlaceAuctionBid("list", m.index, amount)
                local request = observer and observer.last ~= before and observer.last or nil
                if R.filter then
                    ns.Store.Log("buy group=" .. tostring(R.filter.deGroup) .. " target=" .. tostring(R.filter.deTarget)
                        .. " item=" .. tostring(o.item) .. " suffix=" .. tostring(o.suffix) .. " price=" .. o.buyout)
                end
                money = money - amount
                R.want[o] = R.want[o] - 1
                R.bought, R.spent = R.bought + o.stack, R.spent + amount
                R.pending[#R.pending + 1] = { offer = o, item = item, expires = now + PENDING, request = request }
                note(item, o, 1)
                per[o] = (per[o] or 0) + 1
                bids = bids + 1
            end
        end
    end
    R.matches = {}
    for o, n in pairs(per) do o.count = math.max(0, o.count - n) end
    if bids == 0 then
        if poor then
            stop("sayBuyMoney")
        else
            R.phase, R.nextAt = "send", now
            changed()
        end
        return false
    end
    if Buy.Left() <= 0 then
        finish(PENDING)
    elseif poor then
        stop("sayBuyMoney")
    else
        if R.filter and R.filter.routes then
            local remaining = false
            for offer, count in pairs(R.want) do
                if count > 0 and offer.classIndex == R.filter.classIndex then remaining = true end
            end
            if not remaining and nextRoute() then changed(); return true end
        end
        R.phase, R.nextAt = "send", now + AFTER_BUY
        changed()
    end
    return true
end
function Buy.Offer()
    if R.phase ~= "ready" then return 0, 0 end
    local c = 0
    for _, m in ipairs(R.matches) do c = c + (m.offer.bid or m.offer.buyout) end
    return #R.matches, c
end
function Buy.Stop()
    if not Buy.Active() then return false end
    stop("sayBuyStopped", R.bought, GetCoinTextureString(R.spent))
    return true
end
function Buy.OnListUpdate()
    if R.phase ~= "wait" and R.phase ~= "ready" then return end
    R.phase, R.readAt, R.rereads = "settle", GetTime() + SETTLE, 0
end
local function refund(p)
    note(p.item, p.offer, -1)
    p.offer.count = p.offer.count + 1
    R.bought, R.spent, R.refused = R.bought - p.offer.stack, R.spent - (p.offer.bid or p.offer.buyout), R.refused + 1
    if Buy.Active() then
        R.want[p.offer] = (R.want[p.offer] or 0) + 1
        if R.phase == "finish" then
            R.page, R.pass, R.phase, R.nextAt = R.startPage, 1, "send", GetTime() + AFTER_BUY
        end
    end
    changed()
end
function Buy.OnAnswer(request, won)
    local index
    for i, pending in ipairs(R.pending) do
        if request and pending.request == request then index = i; break end
    end
    if not index then return end
    local p = table.remove(R.pending, index)
    if not won and GetTime() <= p.expires then refund(p) end
end
function Buy.OnError(text)
    if not text then return end
    local active = Buy.Active()
    if ns.AccountingEvents and ns.AccountingEvents.Refusal(text) then
        local now = GetTime()
        for i, pending in ipairs(R.pending) do
            if not pending.request and now <= pending.expires then
                refund(table.remove(R.pending, i))
                break
            end
        end
    end
    if active and text == ERR_AUCTION_DATABASE_ERROR then
        ns.Query.Cooldown(120)
        stop("sayBuyRefused")
    end
end
function Buy.OnClose()
    if Buy.Active() then stop("sayBuyClosed", R.bought, GetCoinTextureString(R.spent)) end
end
function Buy.OnUpdate()
    local phase, now = R.phase, GetTime()
    if phase == "send" then
        if now >= R.nextAt and ns.Query.Ready() then
            send()
        elseif now - R.nextAt > SEND_LIMIT then
            stop("sayBuyTimeout")
        end
    elseif phase == "wait" then
        if now - R.sentAt > TIMEOUT then stop("sayBuyTimeout") end
    elseif phase == "settle" then
        if now >= R.readAt then readPage() end
    elseif phase == "finish" then
        if now >= R.nextAt then stop("sayBuyDone", R.bought, GetCoinTextureString(R.spent)) end
    end
end
