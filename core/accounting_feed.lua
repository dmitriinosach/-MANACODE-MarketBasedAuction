local _, ns = ...
local F = {}
ns.AccountingFeed = F
local A = ns.Accounting
F.GAP = A.FEED_GAP
F.THEN_WINDOW = 86400
F.HISTORY_DAYS = 30
F.SMALL_SAMPLE = 5
F.STOCK_CHARS = 60
F.HAVE_CHARS, F.HAVE_ITEMS = 60, 200
F.serial = 0
local RANK = {now = 1, ["then"] = 2, sold = 3}
local FATES = {"converted", "used", "stock", "posted", "sold", "mail"}
local function net(price, count, fee)
    local gross = math.floor(price * count + 0.5)
    return gross - math.floor(gross * fee + 0.5), gross
end
local function prices()
    return {fee = ns.Fee(), now = {}, history = {}}
end
local function priceNow(ctx, id)
    local value = ctx.now[id]
    if value == nil then
        value = A.Quoted(id) or false
        ctx.now[id] = value
    end
    return value or nil
end
local function priceThen(ctx, id, at)
    if ns.vendorPrices and ns.vendorPrices[id] then return ns.vendorPrices[id] end
    local points = ctx.history[id]
    if not points then
        points = ns.Activity and ns.Activity.History(id, F.HISTORY_DAYS).points or {}
        ctx.history[id] = points
    end
    local low, high = 1, #points
    if high == 0 then return nil end
    while low < high do
        local middle = math.floor((low + high) / 2)
        if points[middle].at < at then low = middle + 1 else high = middle end
    end
    local best, before = points[low], points[low - 1]
    if before and math.abs(before.at - at) <= math.abs(best.at - at) then best = before end
    if math.abs(best.at - at) > F.THEN_WINDOW then return nil end
    return best.price
end
local function priceAt(ctx, id, at, snapshot)
    local price = snapshot or priceThen(ctx, id, at)
    if price then return price, "then" end
    price = priceNow(ctx, id)
    return price, price and "now" or nil
end
local function batchFate(b, batch)
    local own, on = b.self[batch.id] or 0, b.posted[batch.id] or 0
    return {converted = math.max(0, batch.used - own), used = own, sold = batch.sold, posted = on,
        stock = math.max(0, batch.count - batch.sold - batch.used - on), mail = 0}, b.soldNet[batch.id] or 0
end
local function chainFate(b, chain)
    local fate = {converted = 0, used = 0, stock = 0, posted = 0, sold = 0,
        mail = math.max(0, chain.count - math.max(chain.received, chain.processed))}
    if chain.plan ~= "flip" then
        fate.converted = chain.processed
        fate.stock = math.max(0, chain.received - chain.processed)
        return fate, 0
    end
    local money = 0
    for _, batch in ipairs(b.flips[chain.id] or {}) do
        local part, sold = batchFate(b, batch)
        for _, key in ipairs(FATES) do fate[key] = fate[key] + part[key] end
        money = money + sold
    end
    return fate, money
end
local function allocationCost(b, allocation)
    if allocation.cost then return allocation.cost, false end
    local batch = b.p.byBatch[allocation.batch]
    local total = batch and (batch.cost or b.est[batch.id])
    if not total or batch.count <= 0 then return nil, false end
    return math.floor(total * allocation.count / batch.count), true
end
local function purchaseStep(b, event)
    local chain = b.p.byChain[event.id]
    if not chain or chain.state == "lost" or chain.stage == "sent" then return nil end
    local fate, money = chainFate(b, chain)
    return {kind = "purchase", key = "purchase", id = event.id, at = event.at, count = 1,
        money = (event.basis == nil or event.basis == "own") and chain.cost or 0, cost = chain.cost,
        unsure = chain.stage == "unsure" or nil, inputs = {},
        outputs = {{itemID = chain.itemID, link = chain.link, count = chain.count, cost = chain.cost, basis = event.basis,
            fate = fate, soldNet = money}}}
end
local function convertStep(b, event)
    local record = b.p.byConvert[event.id]
    if not record then return nil end
    local step = {kind = record.method, key = record.method, id = event.id, at = event.at, to = event.to,
        count = event.casts or 1, inputs = {}, outputs = {}, spell = event.spell}
    local invested = 0
    for _, entry in ipairs(record.inputs) do
        local input = {itemID = entry.itemID, count = entry.count, cost = entry.cost, basis = entry.basis}
        if not entry.chain then
            for index = 1, entry.uncosted and #entry.uncosted or 0 do
                local cost = allocationCost(b, entry.uncosted[index])
                if cost and input.cost then input.cost, input.estimated = input.cost + cost, true else input.cost = nil end
            end
            local outside = entry.missing - entry.settled
            if outside > 0 then
                local price = priceAt(b.ctx, entry.itemID, event.at, entry.price)
                input.outside = outside
                if price and input.cost then input.cost, input.estimated = input.cost + math.floor(price * outside + 0.5), true
                else input.cost = nil end
            end
        end
        invested = invested and input.cost and invested + input.cost or nil
        step.inputs[#step.inputs + 1] = input
    end
    local parts, costed = {}, true
    for index, output in ipairs(event.outputs or {}) do
        local batch = b.p.byBatch[event.id .. ":" .. index]
        if batch then
            local fate, money = batchFate(b, batch)
            local out = {itemID = output.itemID, count = batch.count, fate = fate, soldNet = money}
            local rest = batch.count - batch.sold
            if rest <= 0 then out.value, out.basis = money, "sold"
            else
                local price, basis = priceAt(b.ctx, output.itemID, event.at, output.price)
                if price then out.value, out.basis, out.price = money + net(price, rest, b.ctx.fee), basis, price end
            end
            step.outputs[#step.outputs + 1] = out
            parts[#parts + 1] = {itemID = output.itemID, count = batch.count, batch = batch}
            if not batch.cost then costed = false end
        end
    end
    if record.method == "craft" then
        step.product = event.outputs and event.outputs[1] and event.outputs[1].itemID
        step.key = "craft:" .. tostring(event.spell or step.product)
    end
    if not costed and invested then
        for index, share in ipairs(A.Split(invested, parts)) do
            if not parts[index].batch.cost then b.est[parts[index].batch.id] = share.cost end
        end
    end
    return step
end
local function useStep(b, event)
    local input = {itemID = event.itemID, count = event.count, cost = 0}
    for _, allocation in ipairs(event.allocations or {}) do
        local cost, estimated = allocationCost(b, allocation)
        if cost and input.cost then input.cost = input.cost + cost else input.cost = nil end
        if estimated then input.estimated = true end
    end
    local outside = event.missing or 0
    if outside > 0 then
        local price = priceAt(b.ctx, event.itemID, event.at)
        input.outside = outside
        if price and input.cost then input.cost, input.estimated = input.cost + math.floor(price * outside + 0.5), true
        else input.cost = nil end
    end
    return {kind = "use", key = "use", id = event.id, at = event.at, count = 1, inputs = {input}, outputs = {}}
end
local function postStep(b, event)
    local post = b.p.byPost[event.id]
    if not post then return nil end
    return {kind = "post", key = "post", id = event.id, at = event.at, count = post.stacks,
        active = post.active and math.max(0, post.stacks - post.sold - post.removed) or 0,
        inputs = {{itemID = post.itemID, count = post.stack * post.stacks, ask = (post.buyout or 0) * post.stacks}}, outputs = {}}
end
local function saleStep(b, event)
    local sale = b.p.bySale[event.id]
    if not sale then return nil end
    local input = {itemID = sale.itemID, count = sale.count, cost = sale.count and 0 or nil}
    for _, allocation in ipairs(sale.allocations) do
        local cost, estimated = allocationCost(b, allocation)
        if cost and input.cost then input.cost = input.cost + cost else input.cost = nil end
        if estimated then input.estimated = true end
    end
    local outside = sale.unallocated or 0
    if outside > 0 then
        local price = priceAt(b.ctx, sale.itemID, sale.at)
        input.outside = outside
        if price and input.cost then input.cost, input.estimated = input.cost + math.floor(price * outside + 0.5), true
        else input.cost = nil end
    end
    return {kind = "sale", key = "sale", id = event.id, at = sale.at, count = 1, inputs = {input}, outputs = {},
        net = sale.net, gross = sale.gross, fee = sale.fee}
end
local STEPS = {buy = purchaseStep, disenchant = convertStep, convert = convertStep, use = useStep, post = postStep,
    sale = saleStep}
local function plus(sum, value)
    return sum and value and sum + value or nil
end
local function slot(list, index, item)
    local sum = index[item.itemID]
    if sum then return sum, false end
    sum = {itemID = item.itemID, link = item.link, count = 0}
    index[item.itemID] = sum
    list[#list + 1] = sum
    return sum, true
end
local function place(b, step)
    local row = b.open[step.key]
    if not row or step.at - row.to > F.GAP or row.from - step.at > F.GAP then
        row = {id = step.id, kind = step.kind, owner = step.owner or b.owner, from = step.at, to = step.at, events = {}, count = 0,
            inputs = {}, outputs = {}, spell = step.spell, product = step.product, byInput = {}, byOutput = {}}
        if step.kind == "purchase" then row.money, row.cost = 0, 0 end
        if step.kind == "sale" then row.net, row.gross, row.fee = 0, 0, 0 end
        if step.kind == "post" then row.ask, row.active = 0, 0 end
        b.rows[#b.rows + 1] = row
        b.open[step.key] = row
    end
    row.from, row.to = math.min(row.from, step.at), math.max(row.to, step.to or step.at)
    row.events[#row.events + 1] = step.id
    row.count = row.count + step.count
    for _, item in ipairs(step.inputs) do
        local sum, created = slot(row.inputs, row.byInput, item)
        if created then sum.cost = 0 end
        sum.count, sum.cost = plus(sum.count, item.count), plus(sum.cost, item.cost)
        sum.estimated = sum.estimated or item.estimated
        sum.basis = sum.basis or item.basis
        if item.outside then sum.outside = (sum.outside or 0) + item.outside end
        if item.ask then sum.ask = (sum.ask or 0) + item.ask end
    end
    for _, item in ipairs(step.outputs) do
        local sum, created = slot(row.outputs, row.byOutput, item)
        if created then
            sum.fate, sum.soldNet = {converted = 0, used = 0, stock = 0, posted = 0, sold = 0, mail = 0}, 0
            if step.kind == "purchase" then sum.cost, sum.basis = 0, item.basis else sum.value, sum.basis = 0, "sold" end
        end
        sum.count = sum.count + item.count
        for _, key in ipairs(FATES) do sum.fate[key] = sum.fate[key] + item.fate[key] end
        sum.soldNet = sum.soldNet + item.soldNet
        if step.kind == "purchase" then sum.cost = sum.cost + item.cost
        else
            sum.value = plus(sum.value, item.value)
            if item.basis and RANK[item.basis] < RANK[sum.basis] then sum.basis = item.basis end
            sum.price = item.price or sum.price
        end
    end
    if step.kind == "purchase" then
        row.money, row.cost, row.unsure = row.money + step.money, row.cost + step.cost, row.unsure or step.unsure
    elseif step.kind == "sale" then
        row.net, row.gross, row.fee = row.net + step.net, row.gross + step.gross, row.fee + step.fee
    elseif step.kind == "post" then
        row.ask, row.active = row.ask + step.inputs[1].ask, row.active + step.active
    end
end
local function finish(row)
    row.byInput, row.byOutput = nil, nil
    if row.kind == "post" then return end
    if row.kind == "purchase" then
        row.invested, row.money = row.money, nil
        return
    end
    local invested, got, basis = 0, 0, "sold"
    for _, input in ipairs(row.inputs) do
        invested = plus(invested, input.cost)
        if input.estimated then row.estimated = true end
    end
    row.invested = invested
    if row.kind == "use" then
        row.incomplete = invested == nil or nil
        return
    end
    if row.kind == "sale" then
        row.got, row.basis, row.net = row.net, "sold", nil
    else
        for _, output in ipairs(row.outputs) do
            got = plus(got, output.value)
            if output.value == nil then output.basis = nil
            elseif RANK[output.basis] < RANK[basis] then basis = output.basis end
        end
        row.got, row.basis = got, got and basis or nil
    end
    row.result = row.got and invested and row.got - invested or nil
    row.incomplete = (row.got == nil or invested == nil) or nil
end
local function lots(b)
    local index = {}
    local function lot(id)
        if not index[id] then index[id] = {count = 0, unknown = 0, cost = 0, posted = 0} end
        return index[id]
    end
    for _, chain in ipairs(b.p.chains) do
        local left = chain.count - chain.processed
        if chain.state == "bought" and chain.plan ~= "flip" and left > 0 then
            local entry = lot(chain.itemID)
            entry.count = entry.count + left
            entry.cost = entry.cost + chain.cost - math.floor(chain.cost * chain.processed / chain.count)
        end
    end
    for _, batch in ipairs(b.p.batches) do
        local left = batch.count - batch.sold - batch.used
        if left > 0 then
            local entry = lot(batch.itemID)
            entry.count = entry.count + left
            if batch.cost then entry.cost = entry.cost + batch.cost - batch.soldCost - batch.usedCost
            elseif b.est[batch.id] then
                entry.cost, entry.estimated = entry.cost + math.floor(b.est[batch.id] * left / batch.count), true
            else entry.unknown = entry.unknown + left end
        end
    end
    for id, m in pairs(b.p.materials) do
        if m.posted > 0 then lot(id).posted = m.posted end
    end
    return index
end
local function build(book, owner)
    local p = book.pool and ns.AccountingPool.Project() or A.Project(book, 0)
    local b = {p = p, ctx = prices(), owner = owner, est = {}, self = {}, soldNet = {}, posted = {}, flips = {},
        rows = {}, open = {}}
    for _, event in ipairs(book.events) do
        if event.kind == "use" and not p.reversed[event.id] then
            for _, allocation in ipairs(event.allocations or {}) do
                b.self[allocation.batch] = (b.self[allocation.batch] or 0) + allocation.count
            end
        end
    end
    for _, sale in ipairs(p.sales) do
        local offset = 0
        for _, allocation in ipairs(sale.count and sale.count > 0 and sale.allocations or {}) do
            local share = math.floor(sale.net * (offset + allocation.count) / sale.count)
                - math.floor(sale.net * offset / sale.count)
            b.soldNet[allocation.batch] = (b.soldNet[allocation.batch] or 0) + share
            offset = offset + allocation.count
        end
    end
    local waiting = {}
    for id, m in pairs(p.materials) do
        if m.posted > 0 then waiting[id] = m.posted end
    end
    for _, batch in ipairs(p.batches) do
        local take = math.min(waiting[batch.itemID] or 0, batch.count - batch.sold - batch.used)
        if take > 0 then b.posted[batch.id], waiting[batch.itemID] = take, waiting[batch.itemID] - take end
        if batch.method == "flip" and batch.chain then
            b.flips[batch.chain] = b.flips[batch.chain] or {}
            table.insert(b.flips[batch.chain], batch)
        end
    end
    for _, event in ipairs(book.events) do
        local make = not p.reversed[event.id] and STEPS[event.kind]
        local step = make and make(b, event)
        local actor = step and book.owners and book.owners[event.id]
        if actor then step.owner, step.key = actor, actor.key .. ":" .. step.key end
        if step then place(b, step) end
    end
    for _, row in ipairs(b.rows) do finish(row) end
    return {rows = b.rows, lots = lots(b)}
end
local cache = setmetatable({}, {__mode = "k"})
local function built(book, owner)
    local root = ns.Store.DB().ledger
    local seq, minute, fee, entry = root and root.seq, math.floor(time() / 60), ns.Fee(), cache[book]
    if entry and entry.events == book.events and entry.count == #book.events and entry.seq == seq
        and entry.minute == minute and entry.fee == fee and entry.serial == F.serial then
        return entry.result
    end
    local result = build(book, owner)
    cache[book] = {events = book.events, count = #book.events, seq = seq, minute = minute, fee = fee,
        serial = F.serial, result = result}
    return result
end
function F.Reset()
    F.serial = F.serial + 1
end
local function books(scope)
    return ns.AccountingPool.Books(scope)
end
function F.Feed(options)
    options = options or {}
    local rows, since = {}, options.since or 0
    if ns.AccountingPool.On() then
        for _, row in ipairs(built(ns.AccountingPool.Book()).rows) do
            if row.to >= since and (options.scope == "account" or row.owner.current) then rows[#rows + 1] = row end
        end
    else
        for _, entry in ipairs(books(options.scope)) do
            for _, row in ipairs(built(entry.book, entry.owner).rows) do
                if row.to >= since then rows[#rows + 1] = row end
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.to ~= b.to then return a.to > b.to end
        return a.id > b.id
    end)
    return rows
end
function F.Owners()
    local list = {}
    for _, entry in ipairs(books("account")) do
        if entry.owner.current or #entry.book.events > 0 then list[#list + 1] = entry.owner end
    end
    return list
end
local function choices()
    local db = ns.Store.DB()
    if type(db.ledgerStock) ~= "table" then db.ledgerStock = {} end
    return db.ledgerStock
end
local function listMode(value)
    if type(value) ~= "string" then return nil end
    local name = value:match("^list:(.*)$")
    if not name then return (value == "tracked" or value == "favorites") and value or nil end
    for index, list in ipairs(ns.Collections.Lists()) do
        if list.name == name then return ns.Collections.ListMode(index), name end
    end
    return nil
end
function F.StockList()
    return listMode(choices()[A.CharacterKey()])
end
local function memory()
    local db = ns.Store.DB()
    if type(db.ledgerHave) ~= "table" then db.ledgerHave = {} end
    return db.ledgerHave
end
local function watched()
    local store, current, modes, keys, ids, seen = choices(), A.CharacterKey(), {}, {}, {}, {}
    modes[1] = listMode(store[current])
    for key in pairs(store) do
        if key ~= current then keys[#keys + 1] = key end
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local mode = listMode(store[key])
        if mode then modes[#modes + 1] = mode end
    end
    for _, mode in ipairs(modes) do
        for _, item in ipairs(ns.Collections.Items(mode)) do
            if not seen[item.raw] and #ids < F.HAVE_ITEMS then
                seen[item.raw] = true
                ids[#ids + 1] = item.raw
            end
        end
    end
    return ids
end
function F.Remember()
    if not GetItemCount then return 0 end
    local store, key, items, kept = memory(), A.CharacterKey(), {}, 0
    for _, id in ipairs(watched()) do
        local count = GetItemCount(id, true) or 0
        if count > 0 then items[id], kept = count, kept + 1 end
    end
    store[key] = nil
    if kept == 0 then return 0 end
    local count = 0
    for _ in pairs(store) do count = count + 1 end
    while count >= F.HAVE_CHARS do
        local oldest, at
        for other, entry in pairs(store) do
            local seen = type(entry) == "table" and tonumber(entry.at) or 0
            if not at or seen < at or (seen == at and other < oldest) then oldest, at = other, seen end
        end
        store[oldest], count = nil, count - 1
    end
    store[key] = {at = time(), items = items}
    return kept
end
local function others()
    local current, markets, list = A.CharacterKey(), {}, {}
    for _, key in ipairs(ns.Markets.Keys()) do markets[key] = true end
    for key, entry in pairs(memory()) do
        local realm, faction = key:match("^(.-)|([^|]*)|")
        if key ~= current and realm and markets[realm .. "|" .. faction] and type(entry) == "table"
            and type(entry.items) == "table" then
            list[#list + 1] = {at = tonumber(entry.at) or 0, items = entry.items}
        end
    end
    return list
end
function F.SetStockList(mode)
    local store, key = choices(), A.CharacterKey()
    if mode == nil then store[key] = nil; return true end
    local index = ns.Collections.ListIndex(mode)
    local value = index and ("list:" .. ns.Collections.Lists()[index].name)
        or ((mode == "tracked" or mode == "favorites") and mode) or nil
    if not value then return false end
    if store[key] == nil then
        local count, characters = 0, ns.Store.DB().ledger and ns.Store.DB().ledger.characters or {}
        for _ in pairs(store) do count = count + 1 end
        for pass = 1, 2 do
            for other in pairs(store) do
                local book = characters[other]
                if count >= F.STOCK_CHARS and (pass == 2 or not book or #book.events == 0) then
                    store[other], count = nil, count - 1
                end
            end
        end
    end
    store[key] = value
    return true
end
function F.ListRenamed(old, new)
    for key, value in pairs(choices()) do
        if value == "list:" .. old then choices()[key] = "list:" .. new end
    end
end
function F.ListDeleted(name)
    local store = choices()
    for key, value in pairs(store) do
        if value == "list:" .. name then store[key] = nil end
    end
end
local recipeIndex
local function recipesByInput()
    local crafting = ns.Crafting
    if recipeIndex and recipeIndex.catalogs == ns.craftCatalogs and recipeIndex.order == crafting.order
        and recipeIndex.families == ns.gemFamilies then return recipeIndex.byInput end
    local byInput = {}
    local function add(recipe, inputs)
        recipe.need, recipe.order = {}, {}
        for _, input in ipairs(inputs) do
            if not recipe.need[input[1]] then recipe.order[#recipe.order + 1] = input[1] end
            recipe.need[input[1]] = (recipe.need[input[1]] or 0) + input[2]
        end
        for _, id in ipairs(recipe.order) do
            byInput[id] = byInput[id] or {}
            table.insert(byInput[id], recipe)
        end
    end
    for _, profession in ipairs(crafting.order or {}) do
        local catalog = ns.craftCatalogs[profession]
        for _, recipe in ipairs(catalog and catalog.recipes or {}) do
            add({raw = recipe.raw, spell = recipe.spell, count = recipe.count or 1, profession = profession,
                cooldown = recipe.cooldown, label = catalog.labelKey, source = recipe}, recipe.inputs)
        end
    end
    for _, family in ipairs(ns.gemFamilies or {}) do
        for _, member in ipairs(family.members) do
            local spell = family.spells and family.spells[member]
            if member ~= family.raw and spell then
                add({raw = member, spell = spell, count = 1, profession = "jewelry", family = family.raw,
                    label = "jewelrySection"}, {{family.raw, 1}})
            end
        end
    end
    recipeIndex = {catalogs = ns.craftCatalogs, order = crafting.order, families = ns.gemFamilies, byInput = byInput}
    return byInput
end
local function stockState()
    local result, list
    if ns.AccountingPool.On() then
        result, list = built(ns.AccountingPool.Book()), others()
    else
        local entry = books("character")[1]
        result = built(entry.book, entry.owner)
    end
    return {lots = result.lots, ctx = prices(), have = {}, others = list, extra = {}, oldest = {}, now = time()}
end
local function have(s, id)
    if not s.have[id] then
        local count = math.max(0, GetItemCount and GetItemCount(id, true) or 0)
        for _, entry in ipairs(s.others or {}) do
            local kept = tonumber(entry.items[id]) or 0
            if kept > 0 then
                count, s.extra[id] = count + kept, (s.extra[id] or 0) + kept
                s.oldest[id] = math.min(s.oldest[id] or entry.at, entry.at)
            end
        end
        s.have[id] = count
    end
    return s.have[id]
end
local function ownCost(s, id)
    local lot = s.lots[id]
    local booked = lot and lot.count - lot.unknown or 0
    if booked <= 0 then return nil, 0 end
    return lot.cost / booked, booked
end
local function craftOption(s, row, recipe)
    local per = recipe.need[row.itemID]
    local crafts = math.floor(row.have / per)
    if recipe.cooldown then crafts = math.min(crafts, 1) end
    if crafts <= 0 then return nil end
    local fee = s.ctx.fee
    local option = {kind = "craft", recipe = recipe, per = per, crafts = crafts, units = per * crafts,
        count = crafts * recipe.count, inputs = {}, cost = 0, buy = 0}
    local complete, others = true, 0
    for _, id in ipairs(recipe.order) do
        local need = recipe.need[id] * crafts
        local own = math.min(need, have(s, id))
        local unit, booked = ownCost(s, id)
        local price = priceNow(s.ctx, id)
        local covered = unit and math.min(own, booked) or 0
        local cost = unit and math.floor(unit * covered + 0.5) or 0
        local input = {itemID = id, need = need, have = own, extra = need - own, unit = unit, price = price}
        if need > covered then
            input.market = true
            if id == row.itemID then option.market = true end
            if price then cost = cost + math.floor(price * (need - covered) + 0.5) else cost, complete = nil, false end
        end
        if need > own and price then option.buy = option.buy + math.floor(price * (need - own) + 0.5) end
        input.cost = cost
        option.cost = option.cost + (cost or 0)
        if id ~= row.itemID then others = others + (cost or 0) end
        option.inputs[#option.inputs + 1] = input
    end
    if recipe.source and recipe.source.slots then
        local expected = ns.Crafting.Expected(recipe.source, fee)
        option.revenue = expected and math.floor(expected * crafts + 0.5) or nil
    else
        local price = priceNow(s.ctx, recipe.raw)
        option.revenue = price and net(price, option.count, fee) or nil
    end
    if not complete then option.cost = nil end
    option.profit = option.revenue and option.cost and option.revenue - option.cost or nil
    if option.revenue and complete and row.price then
        option.gain = option.revenue - others - net(row.price, option.units, fee)
    end
    option.known = ns.Recipes.Known(recipe.spell, ns.T(recipe.label))
    option.owners = ns.Recipes.Owners(recipe.spell)
    return option
end
local function stockRow(s, itemID, plain)
    local lot, fee = s.lots[itemID], s.ctx.fee
    local unit, booked = ownCost(s, itemID)
    local row = {itemID = itemID, have = have(s, itemID), posted = lot and lot.posted or 0, booked = booked, unit = unit,
        estimated = lot and lot.estimated or nil, price = priceNow(s.ctx, itemID),
        age = ns.Markets.Age(itemID), alts = 0}
    if ns.Inventory then row.alts = select(2, ns.Inventory.Stock(itemID)) or 0 end
    if s.extra[itemID] then row.remembered, row.haveAge = s.extra[itemID], math.max(0, s.now - s.oldest[itemID]) end
    row.count = row.have + row.posted
    row.known = math.min(row.count, booked)
    row.cost = unit and math.floor(unit * row.known + 0.5) or nil
    row.partial = row.count > row.known or nil
    if row.price then
        row.value, row.gross = net(row.price, row.count, fee)
        if row.cost then row.result = net(row.price, row.known, fee) - row.cost end
    end
    row.sell = {kind = "sell", count = row.count, gross = row.gross, net = row.value, cost = row.cost, result = row.result}
    if plain then return row end
    row.options = {row.sell}
    local crafts = {}
    for _, recipe in ipairs(recipesByInput()[itemID] or {}) do
        local option = not ns.Hidden.Is(recipe.raw) and craftOption(s, row, recipe)
        if option then crafts[#crafts + 1] = option end
    end
    local rank = {[true] = 1, [false] = 3}
    table.sort(crafts, function(a, b)
        local left, right = rank[a.known] or 2, rank[b.known] or 2
        if left ~= right then return left < right end
        if (a.profit == nil) ~= (b.profit == nil) then return a.profit ~= nil end
        if a.profit ~= b.profit then return a.profit > b.profit end
        return a.recipe.raw < b.recipe.raw
    end)
    for _, option in ipairs(crafts) do row.options[#row.options + 1] = option end
    return row
end
function F.Stock(options)
    local mode, rows = F.StockList(), {}
    if not mode then return rows, nil end
    local s = stockState()
    for _, item in ipairs(ns.Collections.Items(mode)) do
        rows[#rows + 1] = stockRow(s, item.raw, options and options.plain)
    end
    return rows, mode
end
function F.StockItem(itemID)
    return stockRow(stockState(), itemID)
end
function F.Summary(options)
    local s = {invested = 0, sold = 0, stock = 0, purchases = 0, sales = 0, unpriced = 0}
    for _, row in ipairs(F.Feed(options)) do
        if row.kind == "purchase" then s.invested, s.purchases = s.invested + row.invested, s.purchases + 1
        elseif row.kind == "sale" then s.sold, s.sales = s.sold + row.got, s.sales + 1 end
    end
    local rows, mode = F.Stock({plain = true})
    for _, row in ipairs(rows) do
        if row.value then s.stock = s.stock + row.value
        elseif row.count > 0 then s.unpriced = s.unpriced + 1 end
    end
    s.total, s.list = s.sold + s.stock - s.invested, mode
    s.incomplete = s.unpriced > 0 or nil
    return s
end
local function yieldGroup(groups, order, method, by, key)
    local group = groups[key]
    if not group then
        group = {method = method, by = by, key = key, count = 0, modelled = 0, seen = {}, ids = {}, costed = 0, cost = 0, paid = {}}
        groups[key] = group
        order[#order + 1] = group
    end
    return group
end
local function yieldOutput(group, id)
    local output = group.seen[id]
    if not output then
        output = {itemID = id, units = 0, hits = 0, expected = 0, chance = 0}
        group.seen[id] = output
        group.ids[#group.ids + 1] = id
    end
    return output
end
local function observe(group, count, outputs, model, cost)
    group.count = group.count + count
    if cost then
        group.costed, group.cost = group.costed + count, group.cost + cost
        group.paid[#group.paid + 1] = outputs
    end
    for _, output in ipairs(outputs) do
        local entry = yieldOutput(group, output.itemID)
        entry.units, entry.hits = entry.units + output.count, entry.hits + count
    end
    if model then
        group.modelled = group.modelled + count
        for _, outcome in ipairs(model) do
            local entry = yieldOutput(group, outcome.itemID)
            entry.expected, entry.chance = entry.expected + outcome.quantity * count, entry.chance + outcome.chance * count
        end
    end
end
local function yieldRows(order)
    local ctx = prices()
    for _, group in ipairs(order) do
        local value, expected = 0, group.modelled == group.count and 0 or nil
        group.outputs = {}
        for _, id in ipairs(group.ids) do
            local entry = group.seen[id]
            entry.average, entry.rate = entry.units / group.count, entry.hits / group.count
            if group.modelled > 0 then
                entry.expected, entry.chance = entry.expected / group.modelled, entry.chance / group.modelled
            else entry.expected, entry.chance = nil, nil end
            local price = priceNow(ctx, id)
            if entry.units > 0 then value = plus(value, price and entry.average * price) end
            if (entry.expected or 0) > 0 then expected = plus(expected, price and entry.expected * price) end
            group.outputs[#group.outputs + 1] = entry
        end
        table.sort(group.outputs, function(a, b)
            local left, right = a.expected or a.average, b.expected or b.average
            if left ~= right then return left > right end
            return a.itemID < b.itemID
        end)
        group.value, group.expectedValue = value, expected
        group.luck = value and expected and expected > 0 and value / expected * 100 or nil
        group.small = group.count < F.SMALL_SAMPLE or nil
        if group.bands then
            local only, several = nil, false
            for band in pairs(group.bands) do
                if only then several = true end
                only = band
            end
            group.band = not several and only or nil
        end
        group.got = value and (net(value, 1, ctx.fee))
        group.expectedGot = expected and (net(expected, 1, ctx.fee))
        if group.costed > 0 then
            local got = 0
            for _, outputs in ipairs(group.paid) do
                for _, output in ipairs(outputs) do
                    local price = priceNow(ctx, output.itemID)
                    got = plus(got, price and (net(price, output.count, ctx.fee)))
                end
            end
            group.buyout = group.cost / group.costed
            group.result = got and got - group.cost
        end
        group.seen, group.ids, group.bands, group.paid, group.cost = nil, nil, nil, nil, nil
    end
    return order
end
local function yieldOrder(order)
    table.sort(order, function(a, b)
        if (a.result ~= nil) ~= (b.result ~= nil) then return a.result ~= nil end
        if a.result and a.result ~= b.result then return a.result < b.result end
        if a.count ~= b.count then return a.count > b.count end
        return tostring(a.key) < tostring(b.key)
    end)
    return order
end
local function paidUnits()
    local units = {}
    local root = ns.Store.DB().ledger
    for _, book in pairs(root and root.characters or {}) do
        for _, event in ipairs(book.events) do
            if event.kind == "buy" and event.cost and (event.count or 0) > 0 and (event.basis == nil or event.basis == "own") then
                units[event.id] = event.cost / event.count
            end
        end
    end
    return units
end
local function disenchants(units)
    local list, logged = {}, {}
    local L = ns.DisenchantLog
    if L then
        local cancelled = L.Cancelled()
        for _, entry in ipairs(L.Root().entries) do
            if entry.kind == "disenchant" then
                if entry.ledger then logged[entry.ledger] = true end
                if not cancelled[entry.id] and entry.outputs then
                    list[#list + 1] = {itemID = entry.itemID, link = entry.link, level = entry.level, quality = entry.quality,
                        band = entry.band, outputs = entry.outputs, cost = entry.chain and units[entry.chain]}
                end
            end
        end
    end
    local root = ns.Store.DB().ledger
    for _, book in pairs(root and root.characters or {}) do
        local byEvent, reversed = {}, {}
        for _, event in ipairs(book.events) do
            byEvent[event.id] = event
            if event.kind == "reverse" then reversed[event.target] = true end
        end
        for _, event in ipairs(book.events) do
            local found = event.kind == "disenchant" or (event.kind == "convert" and event.method == "disenchant")
            if found and not reversed[event.id] and not logged[event.id] and event.outputs then
                local input = event.inputs and event.inputs[1]
                local buy = byEvent[event.target or (input and input.chain) or event.chain or 0]
                if buy and buy.itemID then
                    list[#list + 1] = {itemID = buy.itemID, link = buy.link, level = buy.level, quality = buy.quality,
                        band = buy.band, outputs = event.outputs, cost = units[buy.id]}
                end
            end
        end
    end
    return list
end
local function disenchantYields(method, by)
    local D, groups, order, models = ns.Disenchant, {}, {}, {}
    for _, entry in ipairs(disenchants(paidUnits())) do
        local bandKey = entry.band
        if not bandKey then
            local candidate = D.Candidate(entry.itemID, entry.link)
            bandKey = candidate and candidate.band or nil
        end
        local key = by == "level" and (entry.level or 0) or (by == "band" and (bandKey or "?") or entry.itemID)
        local group = yieldGroup(groups, order, method, by, key)
        local band = bandKey and D.Band(bandKey)
        local model = band and models[band]
        if band and not model then
            model = {}
            for _, output in ipairs(band.outputs) do
                model[#model + 1] = {itemID = output.itemID, chance = output.chance,
                    quantity = output.chance * (output.minCount + output.maxCount) / 2}
            end
            models[band] = model
        end
        observe(group, 1, entry.outputs, model, entry.cost)
        group.bands = group.bands or {}
        if bandKey then group.bands[bandKey] = true end
        if by == "item" then group.itemID, group.link = entry.itemID, group.link or entry.link end
        if by ~= "band" then group.level = group.level or entry.level end
        group.quality = group.quality or entry.quality
        if entry.level then
            group.minLevel = math.min(group.minLevel or entry.level, entry.level)
            group.maxLevel = math.max(group.maxLevel or entry.level, entry.level)
        end
    end
    return yieldOrder(yieldRows(order))
end
local function processingYields(method)
    local P, groups, order, models, paid = ns.Prospect, {}, {}, {}, paidUnits()
    local root = ns.Store.DB().ledger
    for _, book in pairs(root and root.characters or {}) do
        local byEvent, reversed = {}, {}
        for _, event in ipairs(book.events) do
            byEvent[event.id] = event
            if event.kind == "reverse" then reversed[event.target] = true end
        end
        for _, event in ipairs(book.events) do
            if event.kind == "convert" and event.method == method and not reversed[event.id] and event.outputs then
                local source, units, cost = nil, 0, 0
                for _, input in ipairs(event.inputs or {}) do
                    local buy = input.chain and byEvent[input.chain]
                    source = source or input.itemID or (buy and buy.itemID)
                    units = units + (input.count or 0)
                    local unit = input.chain and paid[input.chain]
                    cost = plus(cost, unit and unit * (input.count or 0))
                end
                if source and units > 0 then
                    local group = yieldGroup(groups, order, method, "item", source)
                    group.itemID = source
                    local model = models[source]
                    if model == nil then
                        local known = P and P.Source(method, source)
                        model = false
                        if known then
                            model = {}
                            for _, outcome in ipairs(P.Outcomes(known)) do
                                model[#model + 1] = {itemID = outcome.id, quantity = outcome.quantity, chance = outcome.chance}
                            end
                        end
                        models[source] = model
                    end
                    observe(group, units / (P and P.OPERATION or 5), event.outputs, model or nil, cost)
                end
            end
        end
    end
    return yieldOrder(yieldRows(order))
end
local function craftYields()
    local groups, order = {}, {}
    for _, row in ipairs(F.Feed({scope = "account"})) do
        if row.kind == "craft" and row.product then
            local group = groups[row.product]
            if not group then
                group = {method = "craft", by = "item", key = row.product, itemID = row.product, count = 0, modelled = 0,
                    costed = 0, outputs = {}, gotSum = 0, gotCount = 0, cost = 0, sum = 0}
                groups[row.product] = group
                order[#order + 1] = group
            end
            group.count = group.count + row.count
            if row.got then group.gotSum, group.gotCount = group.gotSum + row.got, group.gotCount + row.count end
            if row.got and row.invested then
                group.costed, group.cost = group.costed + row.count, group.cost + row.invested
                group.sum = group.sum + row.got - row.invested
            end
        end
    end
    for _, group in ipairs(order) do
        group.got = group.gotCount > 0 and group.gotSum / group.gotCount or nil
        if group.costed > 0 then group.buyout, group.result = group.cost / group.costed, group.sum end
        group.small = group.count < F.SMALL_SAMPLE or nil
        group.gotSum, group.gotCount, group.cost, group.sum = nil, nil, nil, nil
    end
    return yieldOrder(order)
end
function F.Yields(method, by)
    method = method or "disenchant"
    if method == "disenchant" then
        return disenchantYields(method, (by == "level" or by == "band") and by or "item")
    end
    if method == "craft" then return craftYields() end
    return processingYields(method)
end
local frame = ns.NewFrame("Frame")
ns.Listen(frame, "PLAYER_LOGOUT")
frame:SetScript("OnEvent", function() F.Remember() end)
