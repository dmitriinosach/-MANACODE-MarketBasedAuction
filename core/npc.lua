local _, ns = ...
local N = {groups = {}, currencies = {}, byCurrency = {}, ladder = {}, rung = {}}
ns.Npc = N
N.UNSOLD_DAYS = 14
for _, group in ipairs(ns.npcGoods) do
    N.groups[group.key] = group
    for _, entry in ipairs(group.items) do entry.group = group.key end
end
for _, currency in ipairs(ns.npcCurrencies) do
    N.currencies[currency.key] = currency
    N.byCurrency[currency.key] = {}
end
for _, good in ipairs(ns.currencyGoods) do
    local list = N.byCurrency[good.currency]
    if list then list[#list + 1] = good end
end
for i, step in ipairs(ns.npcLadder or {}) do
    if i == 1 then N.ladder[1] = step.from end
    N.ladder[#N.ladder + 1] = step.to
end
for i, key in ipairs(N.ladder) do N.rung[key] = i end
N.order = {"exchange", "pets", "limited"}
N.currencyOrder = {"emblems"}
for _, currency in ipairs(ns.npcCurrencies) do
    if not N.rung[currency.key] then N.currencyOrder[#N.currencyOrder + 1] = currency.key end
end
function N.GroupOf(key)
    return N.rung[key] and "emblems" or key
end
function N.GroupKey(key)
    return "npcgroup:" .. key
end
function N.Off(key)
    return ns.Hidden.IsGroup(N.GroupKey(key)) or ns.Hidden.IsGroup(N.GroupKey(N.GroupOf(key)))
end
function N.Items(key)
    local group = N.groups[key]
    return group and group.items or {}
end
function N.RecipeGroups()
    local groups = {}
    for _, key in ipairs(ns.Crafting.order) do
        if ns.vendorRecipeCatalogs[key] then
            groups[#groups + 1] = {key = "recipes:" .. key, profession = key, labelKey = ns.craftCatalogs[key].labelKey}
        end
    end
    if ns.vendorRecipeCatalogs.jewelry then
        groups[#groups + 1] = {key = "recipes:jewelry", profession = "jewelry", labelKey = "jewelrySection"}
    end
    return groups
end
function N.Vendor(entry)
    local faction = UnitFactionGroup("player")
    for _, vendor in ipairs(entry.vendors) do
        if vendor.faction == "Both" or vendor.faction == faction then return vendor end
    end
    return nil
end
function N.Verified(entry)
    if entry.verify then return false end
    for _, vendor in ipairs(entry.vendors) do if vendor.verify then return false end end
    return true
end
local function price(id)
    local quote = ns.Markets.Quote(id)
    if quote and quote.price and (quote.miss or 0) == 0 then return quote.price end
    return nil
end
function N.Cost(entry)
    local cost = entry.buy or 0
    for _, token in ipairs(entry.tokens or {}) do
        local unit = price(token[1])
        if not unit then return nil, token[1] end
        cost = cost + unit * token[2]
    end
    return cost, nil
end
function N.Estimate(entry, fee)
    local cost, missing = N.Cost(entry)
    local result = {cost = cost, missing = missing}
    if cost then result.breakEven = math.ceil(cost / (1 - fee)) end
    local unit = price(entry.raw)
    if unit then
        result.revenue = unit * (1 - fee)
        if cost then
            result.margin = result.revenue - cost
            if cost > 0 then result.rate = math.floor(result.margin / cost * 100 + 0.5) end
        end
    end
    return result
end
function N.Rate(good, fee)
    local unit = price(good.raw)
    if not unit then return nil end
    return math.floor((unit * (1 - fee) - good.money) / good.count)
end
function N.Below(key)
    local from = N.rung[key]
    if not from then return {key} end
    local keys = {}
    for i = from, #N.ladder do keys[#keys + 1] = N.ladder[i] end
    return keys
end
function N.Above(key)
    local keys = {}
    for i = 1, (N.rung[key] or 1) - 1 do keys[#keys + 1] = N.ladder[i] end
    return keys
end
function N.Best(key, fee)
    local best, rate, via
    for _, below in ipairs(N.Below(key)) do
        for _, good in ipairs(N.byCurrency[below] or {}) do
            local value = N.Vendor(good) and not N.Off(below) and not ns.Hidden.IsGroup("npc:" .. good.raw)
                and N.Rate(good, fee)
            if value and (not rate or value > rate) then
                best, rate, via = good, value, below ~= key and below or nil
            end
        end
    end
    return best, rate, via
end
function N.Amount(key)
    local currency = N.currencies[key]
    if not currency then return nil end
    if currency.kind == "honor" then return (GetHonorCurrency()) end
    if currency.kind == "arena" then return (GetArenaCurrency()) end
    if currency.kind == "item" then return GetItemCount(currency.item, true) or 0 end
    for i = 1, GetCurrencyListSize() do
        local _, header, _, _, _, count, _, _, itemID = GetCurrencyListInfo(i)
        if not header and itemID == currency.item then return count or 0 end
    end
    return nil
end
function N.Available(key)
    local own, extra, known = N.Amount(key), 0, false
    for _, above in ipairs(N.Above(key)) do
        local count = N.Amount(above)
        if count then extra, known = extra + count, true end
    end
    if own == nil and not known then return nil, nil, 0 end
    return (own or 0) + extra, own, extra
end
function N.Payment(key, count)
    local own = N.Amount(key)
    local pay, have, known, above = {own = own}, own or 0, own ~= nil, N.Above(key)
    for i = #above, 1, -1 do
        local amount = N.Amount(above[i])
        if amount then
            known = true
            if have < count and have + amount >= count then pay.via = above[i] end
            have = have + amount
        end
    end
    if not known then return pay end
    pay.total, pay.pieces = have, math.floor(have / count)
    if have < count then pay.short = count - have end
    return pay
end
function N.Pick(key, fee)
    local good, rate, via = N.Best(key, fee)
    if not good or not rate then return nil end
    local quote = ns.Markets.Quote(good.raw)
    local pick = {good = good, rate = rate, via = via, amount = N.Amount(key), units = quote and quote.units}
    local unit = price(good.raw)
    if pick.amount and unit then
        pick.pieces = math.floor(pick.amount / good.count)
        pick.revenue = math.floor(pick.pieces * (unit * (1 - fee) - good.money))
    end
    local currency = N.currencies[key]
    local own = currency and currency.kind == "item" and price(currency.item)
    if own and own * (1 - fee) > rate then pick.itself = math.floor(own * (1 - fee)) end
    return pick
end
function N.DefaultPick()
    for _, currency in ipairs(ns.npcCurrencies) do
        if #N.byCurrency[currency.key] > 0 and (N.Amount(currency.key) or 0) > 0 then return currency.key end
    end
    return N.ladder[1]
end
function N.CurrencyName(key)
    local currency = N.currencies[key]
    if currency and currency.item then return ns.Markets.Name(currency.item) end
    return ns.T("npcCurrency" .. key)
end
function N.Icon(key)
    local currency = N.currencies[key]
    if not currency then return nil end
    if currency.kind == "honor" then return "Interface\\PVPFrame\\PVP-Currency-" .. (UnitFactionGroup("player") or "Alliance") end
    return currency.item and select(10, ns.Compat.ItemInfo(currency.item)) or currency.icon
end
function N.Unsold(id)
    local since = time() - N.UNSOLD_DAYS * 86400
    local quote = ns.Markets.Quote(id)
    if not quote or quote.vendor or quote.price or (quote.units or 0) > 0 then return false end
    local item, searched = ns.Markets.Item(id), false
    for _, scanID in ipairs(item and item.order or {}) do
        local observation = item.observations[scanID]
        if observation and (observation.at or 0) >= since then
            if (observation.units or 0) > 0 then return false end
            if observation.complete then searched = true end
        end
    end
    return searched or (quote.complete and (quote.miss or 0) == 0 and (quote.at or 0) >= since) or false
end
function N.QueryName(id)
    local locale = GetLocale()
    local own = ns.locales[locale] or (locale:sub(1, 2) == "en" and ns.locales.enUS)
    return own and own["item" .. id]
end
function N.Targets(segment)
    local ids, seen = {}, {}
    local function add(id) if not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
    if segment ~= "currency" then
        for _, key in ipairs(N.order) do
            for _, entry in ipairs(N.Items(key)) do
                if not ns.Hidden.IsGroup("npc:" .. entry.raw) then
                    for _, token in ipairs(entry.tokens or {}) do add(token[1]) end
                    add(entry.raw)
                end
            end
        end
    end
    if segment ~= "trading" then
        for _, good in ipairs(ns.currencyGoods) do
            if not N.Off(good.currency) and not ns.Hidden.IsGroup("npc:" .. good.raw) then add(good.raw) end
        end
        for _, currency in ipairs(ns.npcCurrencies) do
            if currency.kind == "item" and #N.byCurrency[currency.key] > 0 then add(currency.item) end
        end
    end
    for _, id in ipairs(ids) do
        if not ns.Batch.names[id] then ns.Batch.names[id] = N.QueryName(id) end
    end
    return ids
end
function N.Complete(segment, mode)
    return ns.Batch.Complete(N.Targets(segment), mode, true)
end
