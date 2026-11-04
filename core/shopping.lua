local _, ns = ...
local S = { items = {}, offers = {}, options = {}, need = 1, got = 0, spent = 0, run = false, selected = 1 }
local Shop = { state = S }
ns.Shopping = Shop
Shop.onChange = nil
Shop.HISTORY = 15
Shop.HISTORY_DAYS = 30
local PAST = 10
Shop.past = {}
function Shop.History()
    local db = ns.Store.DB()
    if type(db.buyHistory) ~= "table" then db.buyHistory = {} end
    local list, oldest = db.buyHistory, time() - Shop.HISTORY_DAYS * 86400
    for i = #list, 1, -1 do
        local entry = list[i]
        if type(entry) ~= "table" or type(entry.id) ~= "number" or (entry.at or 0) < oldest or i > Shop.HISTORY then
            table.remove(list, i)
        end
    end
    return list
end
function Shop.Entry(id)
    for _, entry in ipairs(Shop.History()) do
        if entry.id == id then return entry end
    end
end
function Shop.RememberPurchase()
    local got = Shop.Got()
    if not S.itemID or not S.run or not S.runID or got <= 0 or ns.Buy.state.itemID ~= S.itemID then return end
    local entry = Shop.Entry(S.itemID)
    if not entry then return end
    local last = entry.last
    if last and last.run == S.runID then last.units, last.spent = got, Shop.Spent(); return end
    entry.last = {units = got, spent = Shop.Spent(), at = time(), run = S.runID}
end
function Shop.LastUnit(id)
    local entry = Shop.Entry(id)
    local last = entry and entry.last
    if not last or (last.units or 0) <= 0 then return nil end
    return math.floor(last.spent / last.units) + 1
end
local function remember(id, name)
    local list = Shop.History()
    local last
    for i = #list, 1, -1 do
        if list[i].id == id then last = list[i].last; table.remove(list, i) end
    end
    table.insert(list, 1, {id = id, name = name, need = S.need, at = time(), last = last})
    while #list > Shop.HISTORY do table.remove(list) end
end
function Shop.Forget(id)
    local list = Shop.History()
    for i = #list, 1, -1 do
        if list[i].id == id then table.remove(list, i) end
    end
    if Shop.onChange then Shop.onChange() end
end
function Shop.Repeat(id)
    for _, entry in ipairs(Shop.History()) do
        if entry.id == id then
            if not Shop.Search(entry.name or ns.Markets.Name(id), id) then return false end
            if not S.priceLimit and S.itemID ~= id then S.need = math.max(1, entry.need or 1) end
            return true
        end
    end
    return false
end
function Shop.Got()
    return S.got + (S.run and ns.Buy.state.bought or 0)
end
function Shop.Spent()
    return S.spent + (S.run and ns.Buy.state.spent or 0)
end
function Shop.Left()
    if S.priceLimit then
        return ns.Plan.Price(S.offers, S.priceLimit, math.huge).units
    end
    return math.max(0, S.need - Shop.Got())
end
local function changed()
    if Shop.onChange then Shop.onChange() end
end
function Shop.Replan()
    if S.priceLimit then
        local plan = ns.Plan.Price(S.offers, S.priceLimit, GetMoney())
        S.options = plan.lots > 0 and {plan} or {}
        S.need = Shop.Got() + plan.units
    else S.options = Shop.Left() > 0 and ns.Plan.Options(S.offers, Shop.Left()) or {} end
    S.plan = S.options[1] and ns.Plan.Copy(S.options[1]) or nil
    changed()
end
function Shop.SetPriceLimit(copper)
    if ns.Buy.Active() then return false end
    if copper and (copper ~= copper or copper <= 0 or copper > 1000000000 or copper ~= math.floor(copper)) then return false end
    if copper == S.priceLimit then return true end
    if copper and not S.priceLimit then S.quantityNeed = S.need end
    if not copper then S.need = S.quantityNeed or 1 end
    S.priceLimit = copper
    S.got, S.spent, S.run = 0, 0, false
    Shop.Replan()
    return true
end
function Shop.SetNeed(need)
    if ns.Buy.Active() then return end
    local limited = S.priceLimit ~= nil
    S.priceLimit = nil
    need = math.max(1, math.min(ns.Plan.MAX_UNITS, math.floor(need or 1)))
    if need == S.need and not limited then return end
    if Shop.Left() == 0 then S.got, S.spent, S.run = 0, 0, false end
    S.need = need
    local head = Shop.History()[1]
    if head and head.id == S.itemID then head.need = need end
    Shop.Replan()
end
function Shop.Select(id)
    if ns.Buy.Active() then return end
    for _, item in ipairs(S.items) do
        if item.id == id then
            if item.catalog then return Shop.Search(item.name, id, S.filters) end
            if S.itemID ~= id then S.got, S.spent, S.run = 0, 0, false end
            S.itemID, S.name, S.offers = id, item.name, item.offers
            remember(id, item.name)
            Shop.Replan()
            return
        end
    end
end
function Shop.Option(option)
    if ns.Buy.Active() or not S.options[option] then return end
    S.plan = ns.Plan.Copy(S.options[option])
    changed()
end
function Shop.Adjust(offer, delta)
    if ns.Buy.Active() or not S.plan then return end
    if S.priceLimit and (delta > 0 and offer.buyout >= S.priceLimit * offer.stack) then return end
    ns.Plan.Adjust(S.plan, offer, delta)
    changed()
end
function Shop.Reset()
    if ns.Buy.Active() then return end
    if S.priceLimit then S.need = S.quantityNeed or 1 end
    S.priceLimit = nil
    S.got, S.spent, S.run = 0, 0, false
    Shop.Replan()
end
function Shop.Search(query, itemID, filters, page)
    query = (query or ""):match("^%s*(.-)%s*$")
    if ns.Buy.Active() then ns.Scan.SayBusy(); return false end
    if ns.Scan.state.browse and ns.Scan.state.phase == "paused" then ns.Scan.Stop() end
    local filter = {}
    for key, value in pairs(filters or {}) do filter[key] = value end
    if query == "" and not itemID and not filter.classIndex then return false end
    page = math.max(0, math.floor(page or 0))
    if not ns.Scan.Start("pages", {itemID = itemID, query = query, browse = {page = page, filter = filter}}) then return false end
    S.pendingID = ns.Scan.state.scan.id
    S.request = {query = query, itemID = itemID, filters = filter}
    S.filters, S.catalog, S.page, S.pages, S.pageTotal = filter, nil, page, nil, nil
    S.itemID, S.name, S.items, S.offers, S.plan, S.options = nil, nil, {}, {}, nil, {}
    S.got, S.spent, S.run = 0, 0, false
    changed()
    return true
end
function Shop.Page(delta)
    if not S.request or not S.pages or ns.Scan.state.phase ~= "idle" or ns.Buy.Active() then return false end
    local page = (S.page or 0) + delta
    if page < 0 or page >= S.pages then return false end
    local request = S.request
    local pages, total = S.pages, S.pageTotal
    if not Shop.Search(request.query, request.itemID, request.filters, page) then return false end
    S.pages, S.pageTotal = pages, total
    changed()
    return true
end
function Shop.Catalog(preset, filters)
    if ns.Buy.Active() or ns.Scan.state.phase ~= "idle" then return false end
    S.items = ns.Search.Catalog(preset, filters)
    S.filters, S.catalog, S.request, S.pendingID = filters or {}, preset, nil, nil
    S.page, S.pages, S.pageTotal = nil, nil, nil
    S.itemID, S.name, S.offers, S.plan, S.options = nil, nil, {}, nil, {}
    S.got, S.spent, S.run = 0, 0, false
    changed()
    return true
end
function Shop.ClearCatalog()
    if ns.Buy.Active() then return end
    S.catalog, S.items = nil, {}
    S.itemID, S.name, S.offers, S.plan, S.options = nil, nil, {}, nil, {}
    changed()
end
local function found(items, id)
    for _, item in ipairs(items) do if item.id == id then return item end end
end
function Shop.Show(id, need)
    if ns.Buy.Active() then return false end
    local items = found(S.items, id) and S.items
    if not items then
        for _, past in ipairs(Shop.past) do
            if found(past, id) then items = past; break end
        end
    end
    if S.itemID ~= id then S.got, S.spent, S.run = 0, 0, false end
    local item = items and found(items, id)
    S.items = items or {}
    S.catalog, S.request, S.page, S.pages, S.pageTotal = nil, nil, nil, nil, nil
    S.itemID, S.name, S.offers = id, item and item.name or ns.Markets.Name(id), item and item.offers or {}
    if need and not S.priceLimit then S.need = math.max(1, math.min(ns.Plan.MAX_UNITS, math.floor(need))) end
    Shop.Replan()
    return item ~= nil
end
ns.Scan.onBrowse = function(scan, page, total)
    if scan.id ~= S.pendingID then return end
    S.page, S.pages, S.pageTotal = page, math.max(1, math.ceil(total / 50)), total
    Shop.Accept(scan)
end
ns.Scan.onBrowseAbort = function()
    S.pendingID = nil
    changed()
end
function Shop.Accept(scan)
    if not scan or scan.id ~= S.pendingID then return end
    S.pendingID = nil
    if (scan.miss or 0) > 0 then
        S.items, S.offers, S.plan, S.options = {}, {}, nil, {}
        ns.say(ns.T("buyIncomplete"), "bad")
        return changed()
    end
    local byID, items = {}, {}
    local me = UnitName("player")
    for _, text in ipairs(scan.lots) do
        local lot = ns.Lot.Decode(text)
        if lot and lot.buyout > 0 and lot.count > 0 and lot.owner ~= "" and lot.owner ~= me then
            local item = byID[lot.item]
            if not item then
                local stored = ns.Store.DB().items[lot.item]
                item = { id = lot.item, name = stored and stored:match("^[^\t]+") or ns.Markets.Name(lot.item), offers = {}, groups = {} }
                byID[lot.item], items[#items + 1] = item, item
            end
            local key = lot.count .. ":" .. lot.buyout
            local offer = item.groups[key]
            if not offer then
                offer = { stack = lot.count, buyout = lot.buyout, count = 0, page = 0 }
                item.groups[key] = offer
                item.offers[#item.offers + 1] = offer
            end
            offer.count = offer.count + 1
        end
    end
    table.sort(items, function(a, b) return a.name < b.name end)
    for _, item in ipairs(items) do
        table.sort(item.offers, function(a, b) return a.buyout * b.stack < b.buyout * a.stack end)
    end
    S.items = items
    if items[1] then
        table.insert(Shop.past, 1, items)
        while #Shop.past > PAST do table.remove(Shop.past) end
        Shop.Select(byID[S.itemID] and S.itemID or items[1].id)
    else
        S.itemID, S.name, S.offers = nil, nil, {}
        Shop.Replan()
    end
end
function Shop.Go()
    if ns.Buy.Active() then return ns.Buy.Confirm() end
    if not S.plan or S.plan.lots == 0 or Shop.Left() == 0 then return false end
    local got, spent = Shop.Got(), Shop.Spent()
    local limit = S.plan.priceLimit
    local guard
    if limit then
        guard = function(index)
            local _, _, count, _, _, _, _, _, buyout = GetAuctionItemInfo("list", index)
            return count and count > 0 and buyout and buyout > 0 and buyout < limit * count
        end
    end
    if not ns.Buy.Start(S.name, S.plan, S.itemID, guard) then return false end
    if got == 0 or not S.runID then
        Shop.runs = (Shop.runs or 0) + 1
        S.runID = time() .. "-" .. Shop.runs
    end
    S.got, S.spent, S.run = got, spent, true
    changed()
    return true
end
function Shop.Stats(offers)
    local list, units, lots, total = {}, 0, 0, 0
    for _, offer in ipairs(offers or {}) do
        if offer.count > 0 and offer.stack > 0 and offer.buyout > 0 then
            local amount = offer.stack * offer.count
            list[#list + 1] = {offer.buyout / offer.stack, amount}
            units, lots, total = units + amount, lots + offer.count, total + offer.buyout * offer.count
        end
    end
    if units == 0 then return nil end
    local copy = {}
    for i, entry in ipairs(list) do copy[i] = {entry[1], entry[2]} end
    local market = ns.Markets.MarketPrice(copy)
    table.sort(list, function(a, b) return a[1] < b[1] end)
    local half, seen, median = units / 2, 0, nil
    for _, entry in ipairs(list) do
        seen = seen + entry[2]
        if seen >= half then median = entry[1]; break end
    end
    return {min = list[1][1], market = market, median = median, mean = total / units, units = units, lots = lots}
end
local lowerMap
function Shop.Lower(text)
    local lead, tail = string.char(0xD0), string.char(0xD1)
    if not lowerMap then
        lowerMap = {}
        for byte = 0x90, 0x9F do lowerMap[lead .. string.char(byte)] = lead .. string.char(byte + 0x20) end
        for byte = 0xA0, 0xAF do lowerMap[lead .. string.char(byte)] = tail .. string.char(byte - 0x20) end
        local e = lead .. string.char(0xB5)
        lowerMap[lead .. string.char(0x81)], lowerMap[tail .. string.char(0x91)] = e, e
        lowerMap.pattern = "[" .. lead .. tail .. "][" .. string.char(0x80) .. "-" .. string.char(0xBF) .. "]"
    end
    return (text:lower():gsub(lowerMap.pattern, function(char) return lowerMap[char] end))
end
local names
local namesVersion = -1
local function index()
    local version = ns.Store.itemsVersion or 0
    if names and namesVersion == version then return names end
    names, namesVersion = {}, version
    local seen = {}
    for id, stored in pairs(ns.Store.DB().items) do
        local name, quality = stored:match("^([^\t]+)\t?(%d*)")
        if name then
            seen[id] = true
            names[#names + 1] = {id = id, name = name, key = Shop.Lower(name), quality = tonumber(quality)}
        end
    end
    for id in pairs(ns.Crafting and ns.Crafting.items or {}) do
        local name = not seen[id] and ns.Compat.ItemInfo(id)
        if name then
            seen[id] = true
            local quality = select(3, ns.Compat.ItemInfo(id))
            names[#names + 1] = {id = id, name = name, key = Shop.Lower(name), quality = quality}
        end
    end
    for _, catalog in ipairs({ns.searchItems or {}, ns.searchGems or {}}) do
        for id, item in pairs(catalog) do
            if not seen[id] then
                local name = ns.Compat.ItemInfo(id) or item[GetLocale()] or item.enUS
                if name then
                    names[#names + 1] = {id = id, name = name, key = Shop.Lower(name), quality = item.quality}
                    seen[id] = true
                end
            end
        end
    end
    return names
end
function Shop.Suggest(text, limit)
    local query = Shop.Lower((text or ""):match("^%s*(.-)%s*$"))
    local continuation = "[" .. string.char(0x80) .. "-" .. string.char(0xBF) .. "]"
    if #(query:gsub(continuation, "")) < 2 then return {}, true end
    local ranked = {}
    for _, entry in ipairs(index()) do
        local at = entry.key:find(query, 1, true)
        if at then
            local rank = at == 1 and 1 or (entry.key:sub(at - 1, at - 1) == " " and 2 or 3)
            ranked[#ranked + 1] = {entry = entry, rank = rank}
        end
    end
    table.sort(ranked, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if #a.entry.name ~= #b.entry.name then return #a.entry.name < #b.entry.name end
        if a.entry.name ~= b.entry.name then return a.entry.name < b.entry.name end
        return a.entry.id < b.entry.id
    end)
    local out = {}
    for i = 1, math.min(limit, #ranked) do out[i] = ranked[i].entry end
    return out, false
end
ns.Buy.onChange = function()
    if ns.Buy.Active() then changed()
    else
        Shop.RememberPurchase()
        Shop.Replan()
    end
    if ns.Disenchant then ns.Disenchant.BuyChanged() end
    if ns.Prospect then ns.Prospect.BuyChanged() end
end
