local _, ns = ...
local P = {}
ns.AccountingPool = P
local A = ns.Accounting
P.MODES = {"character", "account"}
function P.Mode()
    return ns.Store.DB().ledgerMode == "account" and "account" or "character"
end
function P.On()
    return ns.Store.DB().ledgerMode == "account"
end
function P.SetMode(mode)
    local db = ns.Store.DB()
    local value = mode == "account" and "account" or nil
    if db.ledgerMode == value then return false end
    db.ledgerMode = value
    if ns.AccountingFeed then ns.AccountingFeed.Reset() end
    A.Changed()
    return true
end
function P.Books(scope)
    A.Book()
    local current, markets, list = A.CharacterKey(), {}, {}
    for _, key in ipairs(ns.Markets.Keys()) do markets[key] = true end
    for key, book in pairs(ns.Store.DB().ledger.characters) do
        local realm, faction, name = key:match("^(.-)|([^|]*)|(.*)$")
        if key == current or (scope == "account" and realm and markets[realm .. "|" .. faction]) then
            list[#list + 1] = {book = book, owner = {key = key, name = A.Text(name or key), realm = A.Text(realm),
                faction = faction or "", current = key == current}}
        end
    end
    table.sort(list, function(a, b) return a.owner.key < b.owner.key end)
    return list
end
local function shelf(index, itemID)
    local list = index[itemID]
    if not list then
        list = {first = 1}
        index[itemID] = list
    end
    return list
end
local function addBatch(s, id, itemID, count, cost, order)
    local batch = {id = id, itemID = itemID, count = count, cost = cost, gone = 0, goneCost = 0, order = order}
    local list = shelf(s.batchItems, itemID)
    s.batches[id] = batch
    list[#list + 1] = batch
end
local function nextBatch(s, itemID)
    local list = s.batchItems[itemID]
    if not list then return nil end
    while list[list.first] and list[list.first].gone >= list[list.first].count do list.first = list.first + 1 end
    return list[list.first]
end
local function nextChain(s, itemID, suffix)
    local list = s.chainItems[itemID]
    if not list then return nil end
    while list[list.first] and (list[list.first].processed >= list[list.first].count or list[list.first].state == "lost") do
        list.first = list.first + 1
    end
    for index = list.first, #list do
        local chain = list[index]
        if chain.state ~= "lost" and not chain.flip and chain.received > chain.processed
            and (suffix == nil or chain.suffix == suffix) then return chain end
    end
    return nil
end
local function takeBatch(batch, count)
    local cost = batch.cost and (math.floor(batch.cost * (batch.gone + count) / batch.count) - batch.goneCost) or nil
    batch.gone, batch.goneCost = batch.gone + count, batch.goneCost + (cost or 0)
    return {batch = batch.id, count = count, cost = cost}
end
local function allocate(s, itemID, count)
    local allocations, left = {}, count
    while left > 0 do
        local batch = nextBatch(s, itemID)
        if not batch then break end
        allocations[#allocations + 1] = takeBatch(batch, math.min(left, batch.count - batch.gone))
        left = left - allocations[#allocations].count
    end
    return allocations, left
end
local function clone(event)
    local copy = {}
    for key, value in pairs(event) do copy[key] = value end
    return copy
end
local function flip(s, chain, event, before)
    local count = chain.received - before
    if count <= 0 then return end
    local cost = math.floor(chain.cost * chain.received / chain.count) - math.floor(chain.cost * before / chain.count)
    addBatch(s, event.id .. ":1", chain.itemID, count, cost, event.id)
    chain.processed = chain.received
end
local function split(total, outputs)
    local stored, sum, priced, worth, costs = true, 0, true, 0, {}
    for _, output in ipairs(outputs) do
        if output.cost then sum = sum + output.cost else stored = false end
        if output.price then worth = worth + output.price * output.count else priced = false end
    end
    if stored and sum == total then
        for index, output in ipairs(outputs) do costs[index] = output.cost end
        return costs
    end
    local weights, whole = {}, 0
    if stored and sum > 0 then
        for index, output in ipairs(outputs) do weights[index] = output.cost end
        whole = sum
    elseif priced and worth > 0 then
        for index, output in ipairs(outputs) do weights[index] = output.price * output.count end
        whole = worth
    else
        for index, share in ipairs(A.Split(total, outputs)) do costs[index] = share.cost end
        return costs
    end
    local given = 0
    for index = 1, #outputs do
        local share = index == #outputs and total - given or math.floor(total * weights[index] / whole)
        given = given + share
        costs[index] = share
    end
    return costs
end
local STEPS = {}
function STEPS.buy(s, event)
    local chain = {id = event.id, itemID = event.itemID, suffix = event.suffix or 0, count = event.count, cost = event.cost,
        received = event.basis and event.count or 0, processed = 0, state = event.sent and "sent" or "bought",
        flip = event.plan == "flip"}
    local list = shelf(s.chainItems, chain.itemID)
    s.chains[chain.id] = chain
    list[#list + 1] = chain
    if chain.flip then flip(s, chain, event, 0) end
end
function STEPS.won(s, event)
    local chain = s.chains[event.target]
    if chain then chain.state = "bought" end
end
function STEPS.lost(s, event)
    local chain = s.chains[event.target]
    if chain then chain.state = "lost" end
end
function STEPS.receive(s, event)
    local chain = s.chains[event.target]
    if not chain then return end
    if chain.state == "sent" then chain.state = "bought" end
    local before = chain.received
    chain.received = math.min(chain.count, chain.received + event.count)
    if chain.flip then flip(s, chain, event, before) end
end
function STEPS.convert(s, event)
    local inputs = event.kind == "disenchant" and {{chain = event.target, count = 1}} or event.inputs or {}
    local list, total, known, tracked, opaque = {}, 0, true, false, false
    local function fromChain(chain, count)
        local before = chain.processed
        chain.processed = before + count
        if chain.received < chain.processed then chain.received = chain.processed end
        if chain.state == "sent" then chain.state = "bought" end
        total = total + math.floor(chain.cost * chain.processed / chain.count) - math.floor(chain.cost * before / chain.count)
        list[#list + 1] = {chain = chain.id, count = count}
        tracked = true
    end
    for _, input in ipairs(inputs) do
        local want = input.count or 0
        local named = s.chains[input.chain or input.pool or 0]
        local itemID, suffix = input.itemID, nil
        if input.chain then itemID, suffix = named and named.itemID, named and named.suffix end
        if named and named.state ~= "lost" and not named.flip then
            local take = math.min(want, (input.chain and named.count or named.received) - named.processed)
            if take > 0 then
                fromChain(named, take)
                want = want - take
            end
        end
        local entry = {itemID = itemID, count = 0, allocations = {}, price = input.price}
        while want > 0 and itemID do
            local chain = nextChain(s, itemID, suffix)
            local batch = (suffix == nil or suffix == 0) and nextBatch(s, itemID) or nil
            if not chain and not batch then break end
            if chain and (not batch or chain.id < batch.order) then
                local take = math.min(want, chain.received - chain.processed)
                fromChain(chain, take)
                want = want - take
            else
                local allocation = takeBatch(batch, math.min(want, batch.count - batch.gone))
                entry.allocations[#entry.allocations + 1] = allocation
                entry.count, want, tracked = entry.count + allocation.count, want - allocation.count, true
                if allocation.cost then total = total + allocation.cost else known = false end
            end
        end
        if want > 0 and itemID then
            entry.count, entry.missing, known = entry.count + want, want, false
        elseif want > 0 then
            list[#list + 1], opaque = {chain = input.chain, count = want}, true
        end
        if entry.count > 0 then list[#list + 1] = entry end
    end
    local copy, outputs = clone(event), {}
    local costs = known and not opaque and split(total, event.outputs or {}) or {}
    for index, output in ipairs(event.outputs or {}) do
        local cost = costs[index]
        if opaque then cost = output.cost end
        outputs[index] = {itemID = output.itemID, count = output.count, cost = cost, price = output.price}
        addBatch(s, event.id .. ":" .. index, output.itemID, output.count, cost, event.id)
    end
    copy.kind, copy.method, copy.target = "convert", event.kind == "disenchant" and "disenchant" or event.method, nil
    copy.inputs, copy.outputs = list, outputs
    copy.outside = event.outside and not tracked or nil
    return copy
end
STEPS.disenchant = STEPS.convert
function STEPS.use(s, event)
    local copy = clone(event)
    local allocations, left = allocate(s, event.itemID, event.count or 0)
    copy.allocations, copy.missing = allocations, left > 0 and left or nil
    return copy
end
function STEPS.sale(s, event)
    if not event.count then
        s.sales[event.id] = {itemID = event.itemID, allocations = {}}
        return nil
    end
    local copy = clone(event)
    local allocations, left = allocate(s, event.itemID, event.count)
    s.sales[event.id] = {itemID = event.itemID, allocations = allocations}
    copy.allocations, copy.unallocated = allocations, left > 0 and left or nil
    return copy
end
function STEPS.count(s, event)
    local sale = s.sales[event.target]
    if not sale then return nil end
    for _, allocation in ipairs(sale.allocations) do
        local batch = s.batches[allocation.batch]
        if batch then batch.gone, batch.goneCost = batch.gone - allocation.count, batch.goneCost - (allocation.cost or 0) end
    end
    local list = s.batchItems[sale.itemID]
    if list then list.first = 1 end
    local copy = clone(event)
    local allocations, left = allocate(s, sale.itemID, event.count or 0)
    sale.allocations = allocations
    copy.allocations, copy.unallocated = allocations, left > 0 and left or nil
    return copy
end
local function merge(list)
    local heads, events, owners = {}, {}, {}
    for index = 1, #list do heads[index] = 1 end
    while true do
        local best, lowest
        for index, entry in ipairs(list) do
            local event = entry.book.events[heads[index]]
            if event and (not lowest or (event.id or 0) < lowest) then best, lowest = index, event.id or 0 end
        end
        if not best then break end
        local event = list[best].book.events[heads[best]]
        heads[best] = heads[best] + 1
        events[#events + 1] = event
        if event.id then owners[event.id] = list[best].owner end
    end
    return events, owners
end
local function build(list)
    local events, owners = merge(list)
    local reversed, out = {}, {}
    local s = {chains = {}, chainItems = {}, batches = {}, batchItems = {}, sales = {}}
    for _, event in ipairs(events) do
        if event.kind == "reverse" then reversed[event.target] = true end
    end
    for _, event in ipairs(events) do
        local step = not reversed[event.id] and STEPS[event.kind]
        if event.kind ~= "party" then out[#out + 1] = step and step(s, event) or event end
    end
    return {events = out, owners = owners, pool = true, fee = ns.Fee()}
end
local pooled
function P.Book()
    local list, root, current = P.Books("account"), ns.Store.DB().ledger, A.CharacterKey()
    local cached = pooled
    if cached and cached.root == root and cached.seq == root.seq and cached.current == current and #cached.list == #list then
        local same = true
        for index, entry in ipairs(list) do
            local old = cached.list[index]
            if old.book ~= entry.book or old.events ~= entry.book.events or old.count ~= #entry.book.events then
                same = false
                break
            end
        end
        if same then return cached.result end
    end
    local marks = {}
    for index, entry in ipairs(list) do marks[index] = {book = entry.book, events = entry.book.events, count = #entry.book.events} end
    pooled = {root = root, seq = root.seq, current = current, list = marks, result = build(list)}
    return pooled.result
end
local projected
function P.Project()
    local book, minute = P.Book(), math.floor(time() / 60)
    if projected and projected.book == book and projected.minute == minute then return projected.result end
    projected = {book = book, minute = minute, result = A.Project(book, 0)}
    return projected.result
end
function P.View()
    if P.On() then return P.Project() end
    return nil
end
