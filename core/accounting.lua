local _, ns = ...
local A = {}
ns.Accounting = A
A.PENDING = 30
local function integer(value, minimum, maximum)
    return type(value) == "number" and value == math.floor(value) and value >= minimum and value <= (maximum or 1000000000000)
end
function A.Text(value)
    local text = tostring(value or ""):gsub("[%c|]", "")
    local cut = math.min(#text, 240)
    while cut > 0 do
        local byte = text:byte(cut + 1)
        if not byte or byte < 128 or byte >= 192 then break end
        cut = cut - 1
    end
    return text:sub(1, cut)
end
function A.Price(text)
    local value = tostring(text or ""):match("^%s*(.-)%s*$"):gsub(",", ".")
    if not value:match("^%d+%.?%d*$") then return nil end
    local decimals = value:match("%.(%d*)$")
    if decimals and #decimals > 4 then return nil end
    local number = tonumber(value)
    if not number or number > 100000000 then return nil end
    return math.floor(number * 10000 + 0.5)
end
function A.CharacterKey()
    return (GetRealmName() or "") .. "|" .. (UnitFactionGroup("player") or "") .. "|" .. (UnitName("player") or "")
end
function A.Book()
    local db = ns.Store.DB()
    db.ledger = db.ledger or {version = 1, seq = 0, characters = {}}
    local root = db.ledger
    local key = A.CharacterKey()
    root.characters[key] = root.characters[key] or {events = {}, fee = 0.05}
    return root.characters[key]
end
function A.History(since, currentOnly)
    local root, current, history = ns.Store.DB().ledger, A.CharacterKey(), {}
    for key, book in pairs(root and root.characters or {}) do
        if not currentOnly or key == current then
            local realm, faction, name = key:match("^(.-)|([^|]*)|(.*)$")
            local owner = {key = key, name = A.Text(name or key), realm = A.Text(realm),
                faction = faction or "", current = key == current}
            local byEvent, reversed, bySale = {}, {}, {}
            for _, event in ipairs(book.events) do
                byEvent[event.id] = event
                if event.kind == "reverse" then reversed[event.target] = event.id end
            end
            for _, event in ipairs(book.events) do
                if not reversed[event.id] then
                    if event.kind == "sale" then bySale[event.id] = {count = event.count}
                    elseif event.kind == "count" and bySale[event.target] then bySale[event.target].count = event.count end
                end
                if event.at >= (since or 0) then
                    history[#history + 1] = {event = event, owner = owner,
                        byEvent = byEvent, reversed = reversed, bySale = bySale}
                end
            end
        end
    end
    table.sort(history, function(a, b)
        if a.event.at ~= b.event.at then return a.event.at > b.event.at end
        if a.event.id ~= b.event.id then return a.event.id > b.event.id end
        return a.owner.key < b.owner.key
    end)
    return history
end
function A.Changed()
    if A.onChange then A.onChange() end
end
local function append(event, source)
    local book = A.Book()
    local root = ns.Store.DB().ledger
    root.seq = root.seq + 1
    event.id, event.at, event.source = root.seq, event.at or time(), source or "manual"
    book.events[#book.events + 1] = event
    A.Changed()
    return event.id
end
A.PLANS = {"disenchant", "prospect", "mill", "craft", "flip"}
function A.ValidPlan(plan)
    for _, known in ipairs(A.PLANS) do if plan == known then return true end end
    return false
end
function A.Plan(itemID, link)
    if not itemID then return nil end
    local model = ns.Disenchant and ns.Disenchant.Candidate(itemID, link)
    if model then return "disenchant", model end
    if ns.Prospect then
        if ns.Prospect.Source("prospect", itemID) then return "prospect" end
        if ns.Prospect.Source("mill", itemID) then return "mill" end
    end
    if ns.Crafting and ns.Crafting.inputs[itemID] then return "craft" end
    if ns.gemByItem and ns.gemByItem[itemID] then return "craft" end
    for _, pair in ipairs(ns.recyclePairs or {}) do
        if pair.small == itemID or pair.big == itemID then return "craft" end
    end
    for _, id in ipairs(ns.disenchantMaterials or {}) do if id == itemID then return "craft" end end
    return nil
end
function A.Intent(itemID, link)
    local plan, model = A.Plan(itemID, link)
    if not plan and itemID and A.Book().trackAll then plan = "flip" end
    return plan, model
end
function A.SetTrackAll(on)
    A.Book().trackAll = on and true or nil
    A.Changed()
end
function A.Market(id)
    local q = ns.Disenchant and ns.Disenchant.Quote(id)
    if not q or q.complete == false or (q.miss or 0) > 0 then return nil end
    return q.price
end
function A.Selling()
    local view = ns.DisenchantUI
    return view and view.selling or {hours = 12, losses = 1}
end
function A.Project(book, since, now, party)
    book = book or A.Book()
    if party and party ~= 0 then return A.Project(A.PartyBook(book, party, now), since, now) end
    now = now or time()
    since = since or 0
    local p = {chains = {}, byChain = {}, batches = {}, byBatch = {}, materials = {}, sales = {}, bySale = {},
        posts = {}, byPost = {}, journal = {}, reversed = {}, byEvent = {}, converts = {},
        stages = {sent = 0, unsure = 0, mail = 0, bag = 0, done = 0, lost = 0},
        holding = 0, holdingCount = 0, holdingMail = 0, holdingBag = 0, holdingUnsure = 0, spent = 0, gross = 0, fees = 0, net = 0, soldCost = 0,
        stockCost = 0, stockValue = 0, unknownStock = false, unpriced = 0, uncosted = 0, unknownSales = book.unassignedSales or 0,
        unknownCost = false, netAll = 0, soldCostAll = 0, sold = 0,
        outputValue = 0, free = 0, parties = {}, party = book.party}
    local memberships, activeParty = {}, 0
    for _, event in ipairs(book.events) do
        p.byEvent[event.id] = event
        if event.kind == "reverse" then p.reversed[event.target] = event.id end
        if event.kind == "buy" then memberships[event.id] = activeParty end
        if event.kind == "party" then
            activeParty = event.id
            p.parties[#p.parties + 1] = event
            for _, id in ipairs(event.chains or {}) do memberships[id] = activeParty end
        end
    end
    local function material(id)
        local m = p.materials[id]
        if not m then
            m = {itemID = id, received = 0, sold = 0, used = 0, remaining = 0, posted = 0, cost = 0, net = 0, soldCost = 0}
            p.materials[id] = m
        end
        return m
    end
    local function flipBatch(chain, event, before)
        local count = chain.received - before
        if count <= 0 then return end
        local cost = math.floor(chain.cost * chain.received / chain.count) - math.floor(chain.cost * before / chain.count)
        local batch = {id = event.id .. ":1", itemID = chain.itemID, count = count, cost = cost, sold = 0, soldCost = 0,
            used = 0, usedCost = 0, chain = chain.id, at = event.at, method = "flip"}
        p.batches[#p.batches + 1], p.byBatch[batch.id] = batch, batch
        chain.outputs[chain.itemID] = (chain.outputs[chain.itemID] or 0) + count
        chain.processed, chain.method = chain.received, "flip"
    end
    local function resolve()
        for _, record in ipairs(p.converts) do
            if not record.known and #record.missing > 0 then
                local settled = true
                for _, miss in ipairs(record.missing) do
                    local left = miss.count
                    for _, chain in ipairs(p.chains) do
                        if left > 0 and chain.itemID == miss.itemID and chain.state ~= "lost" and chain.plan ~= "flip"
                            and chain.received > chain.processed then
                            local take = math.min(left, chain.received - chain.processed)
                            local before = chain.processed
                            chain.processed = chain.processed + take
                            chain.method = record.method
                            record.cost = record.cost + math.floor(chain.cost * chain.processed / chain.count)
                                - math.floor(chain.cost * before / chain.count)
                            left = left - take
                        end
                    end
                    if left > 0 then settled = false end
                end
                local allocated = true
                for _, input in ipairs(record.event.inputs or {}) do
                    for _, allocation in ipairs(input.allocations or {}) do
                        if not allocation.cost then allocated = false end
                    end
                end
                if settled and allocated then
                    record.known = true
                    local outputs = {}
                    for index, output in ipairs(record.event.outputs or {}) do outputs[index] = {itemID = output.itemID, count = output.count} end
                    for index, output in ipairs(A.Split(record.cost, outputs)) do
                        local batch = p.byBatch[record.event.id .. ":" .. index]
                        if batch and not batch.cost then batch.cost = output.cost end
                    end
                end
            end
        end
    end
    for _, event in ipairs(book.events) do
        p.journal[#p.journal + 1] = event
        local live = not p.reversed[event.id] and event.kind ~= "reverse"
        local chain = live and event.target and p.byChain[event.target]
        if live and event.kind == "buy" then
            chain = {id = event.id, itemID = event.itemID, link = event.link, suffix = event.suffix or 0,
                count = event.count, cost = event.cost, owner = event.owner, level = event.level,
                quality = event.quality, band = event.band, at = event.at, source = event.source,
                basis = event.basis, from = event.from, state = event.sent and "sent" or "bought",
                plan = A.ValidPlan(event.plan) and event.plan or "disenchant",
                received = event.basis and event.count or 0, processed = 0, outputs = {}, events = {event.id},
                party = memberships[event.id] or 0}
            p.chains[#p.chains + 1], p.byChain[chain.id] = chain, chain
            if chain.plan == "flip" then flipBatch(chain, event, 0) end
        elseif chain and event.kind == "won" then chain.state = "bought"; chain.events[#chain.events + 1] = event.id
        elseif chain and event.kind == "lost" then chain.state = "lost"; chain.events[#chain.events + 1] = event.id
        elseif chain and event.kind == "receive" then
            if chain.state == "sent" then chain.state = "bought" end
            local before = chain.received
            chain.received = math.min(chain.count, chain.received + event.count)
            chain.events[#chain.events + 1] = event.id
            if chain.plan == "flip" then flipBatch(chain, event, before) end
        elseif live and (event.kind == "disenchant" or event.kind == "convert") then
            local method = event.kind == "disenchant" and "disenchant" or event.method
            local inputs = event.kind == "disenchant" and {{chain = event.target, count = 1}} or event.inputs or {}
            local record = {event = event, method = method, cost = 0, known = true, missing = {}, chains = {}}
            local owner = event.chain and p.byChain[event.chain]
            for _, input in ipairs(inputs) do
                local source = input.chain and p.byChain[input.chain]
                if source then
                    if source.state == "sent" then source.state = "bought" end
                    local before = source.processed
                    source.processed = math.min(source.count, source.processed + input.count)
                    source.received = math.max(source.received, source.processed)
                    source.method = method
                    source.events[#source.events + 1] = event.id
                    record.cost = record.cost + math.floor(source.cost * source.processed / source.count)
                        - math.floor(source.cost * before / source.count)
                    record.chains[#record.chains + 1] = source
                    owner = owner or source
                elseif input.itemID then
                    for _, allocation in ipairs(input.allocations or {}) do
                        local batch = p.byBatch[allocation.batch]
                        if batch then
                            batch.used, batch.usedCost = batch.used + allocation.count, batch.usedCost + (allocation.cost or 0)
                            if allocation.cost then record.cost = record.cost + allocation.cost else record.known = false end
                            owner = owner or p.byChain[batch.chain]
                        end
                    end
                    if (input.missing or 0) > 0 then
                        record.known = false
                        record.missing[#record.missing + 1] = {itemID = input.itemID, count = input.missing}
                    end
                end
            end
            record.chain = owner
            for index, output in ipairs(event.outputs or {}) do
                local batch = {id = event.id .. ":" .. index, itemID = output.itemID, count = output.count,
                    cost = output.cost, sold = 0, soldCost = 0, used = 0, usedCost = 0,
                    chain = owner and owner.id, at = event.at, method = method}
                p.batches[#p.batches + 1], p.byBatch[batch.id] = batch, batch
                for _, source in ipairs(record.chains) do
                    source.outputs[output.itemID] = (source.outputs[output.itemID] or 0) + output.count
                end
                if #record.chains == 0 and owner then
                    owner.outputs[output.itemID] = (owner.outputs[output.itemID] or 0) + output.count
                end
            end
            p.converts[#p.converts + 1] = record
        elseif live and event.kind == "use" then
            for _, allocation in ipairs(event.allocations or {}) do
                local batch = p.byBatch[allocation.batch]
                if batch then batch.used, batch.usedCost = batch.used + allocation.count, batch.usedCost + (allocation.cost or 0) end
            end
        elseif live and event.kind == "post" then
            local post = {id = event.id, itemID = event.itemID, stack = event.stack, stacks = event.stacks,
                bid = event.bid, buyout = event.buyout, at = event.at, ends = event.at + (event.hours or 24) * 3600,
                sold = 0, removed = 0}
            p.posts[#p.posts + 1], p.byPost[post.id] = post, post
        elseif live and event.kind == "unpost" and p.byPost[event.target] then
            p.byPost[event.target].removed = p.byPost[event.target].removed + 1
        elseif live and event.kind == "sale" then
            local sale = {id = event.id, itemID = event.itemID, count = event.count, gross = event.gross,
                fee = event.fee, net = event.gross - event.fee, at = event.at, post = event.post, cost = 0,
                source = event.source, allocations = event.allocations or {}, unallocated = event.unallocated,
                stockless = event.stockless}
            p.sales[#p.sales + 1], p.bySale[sale.id] = sale, sale
            if sale.post and p.byPost[sale.post] then p.byPost[sale.post].sold = p.byPost[sale.post].sold + 1 end
        elseif live and event.kind == "count" and p.bySale[event.target] then
            local sale = p.bySale[event.target]
            sale.count, sale.allocations, sale.unallocated = event.count, event.allocations or {}, event.unallocated
        end
    end
    resolve()
    for _, sale in ipairs(p.sales) do
        if (sale.unallocated or 0) > 0 then sale.unknownCost = true end
        for _, allocation in ipairs(sale.allocations) do
            local batch = p.byBatch[allocation.batch]
            if batch then
                batch.sold, batch.soldCost = batch.sold + allocation.count, batch.soldCost + (allocation.cost or 0)
                sale.cost = sale.cost + (allocation.cost or 0)
                if not allocation.cost then sale.unknownCost = true end
            end
        end
        local m = material(sale.itemID)
        if sale.count then m.sold = m.sold + sale.count - (sale.unallocated or 0) else p.unknownSales = p.unknownSales + 1 end
        if sale.unknownCost then p.unknownCost = true end
        m.net, m.soldCost = m.net + sale.net, m.soldCost + sale.cost
        p.netAll, p.soldCostAll = p.netAll + sale.net, p.soldCostAll + sale.cost
        if sale.at >= since then
            p.gross, p.fees, p.net, p.soldCost = p.gross + sale.gross, p.fees + sale.fee, p.net + sale.net, p.soldCost + sale.cost
            p.sold = p.sold + 1
        end
    end
    for _, batch in ipairs(p.batches) do
        local m = material(batch.itemID)
        local remaining = batch.count - batch.sold - batch.used
        m.received, m.remaining, m.used = m.received + batch.count, m.remaining + remaining, m.used + batch.used
        if batch.cost then m.cost = m.cost + batch.cost - batch.soldCost - batch.usedCost
        elseif remaining > 0 then m.unknownCost = true end
    end
    for _, post in ipairs(p.posts) do
        post.active = post.ends > now and post.sold + post.removed < post.stacks
        if post.active then
            local m = material(post.itemID)
            m.posted = m.posted + post.stack * (post.stacks - post.sold - post.removed)
        end
    end
    local fee = book.fee or 0.05
    for id, m in pairs(p.materials) do
        m.posted = math.min(m.posted, m.remaining)
        m.price = A.Market(id)
        if m.remaining > 0 then
            p.stockCost = p.stockCost + m.cost
            local sale = A.Proceeds(id, m.remaining, fee)
            if sale then
                m.value = sale.net
                p.stockValue = p.stockValue + m.value
            else p.unpriced = p.unpriced + 1 end
            if m.unknownCost then p.uncosted = p.uncosted + 1 end
        end
    end
    p.unknownStock = p.unpriced > 0 or p.uncosted > 0
    for _, chain in ipairs(p.chains) do
        local stage = chain.state
        if stage == "sent" and now - chain.at > A.PENDING then stage = "unsure"
        elseif stage == "bought" then
            stage = chain.processed >= chain.count and "done" or (chain.received > chain.processed and "bag" or "mail")
        end
        chain.stage = stage
        local gross, cut, reserve, value, known = 0, 0, 0, 0, next(chain.outputs) ~= nil
        for id, count in pairs(chain.outputs) do
            local sale = A.Proceeds(id, count, fee)
            if sale then gross, cut, reserve, value = gross + sale.gross, cut + sale.cut, reserve + sale.reserve, value + sale.net
            else known = false end
        end
        chain.gross, chain.cut = known and gross or nil, known and cut or nil
        chain.reserve, chain.value = known and reserve or nil, known and value or nil
        if stage == "done" and chain.value then chain.result = chain.value - chain.cost end
        if chain.at >= since then
            p.stages[stage] = p.stages[stage] + 1
            if chain.basis == "free" then p.free = p.free + 1 end
            if stage ~= "lost" and stage ~= "sent" then p.spent = p.spent + chain.cost end
            if chain.value then p.outputValue = p.outputValue + chain.value end
        end
        if stage == "mail" or stage == "bag" or stage == "unsure" then
            local left = chain.cost - math.floor(chain.cost * chain.processed / chain.count)
            p.holding, p.holdingCount = p.holding + left, p.holdingCount + chain.count - chain.processed
            if stage == "unsure" then p.holdingUnsure = p.holdingUnsure + chain.count - chain.processed
            else
                p.holdingMail = p.holdingMail + chain.count - math.max(chain.received, chain.processed)
                p.holdingBag = p.holdingBag + math.max(0, chain.received - chain.processed)
            end
        end
    end
    p.realized = p.net - p.soldCost
    p.realizedAll = p.netAll - p.soldCostAll
    p.forecast = not p.unknownStock and not p.unknownCost and (p.realizedAll + p.stockValue - p.stockCost) or nil
    return p
end
function A.StartParty(carry)
    local chains = {}
    if carry then
        for _, chain in ipairs(A.Project().chains) do
            if chain.state ~= "lost" and chain.processed < chain.count then chains[#chains + 1] = chain.id end
        end
    end
    local id = append({kind = "party", chains = chains})
    A.Book().selectedParty = id
    A.Changed()
    return id
end
function A.Parties(book)
    local parties = {}
    for _, event in ipairs((book or A.Book()).events) do
        if event.kind == "party" then parties[#parties + 1] = event end
    end
    return parties
end
local partyCache = {}
function A.PartyBook(book, party, now)
    local root = ns.Store.DB().ledger
    local seq, cached = root and root.seq, partyCache
    if cached.book == book and cached.events == book.events and cached.count == #book.events and cached.seq == seq
        and cached.party == party then
        cached.result.fee = book.fee
        return cached.result
    end
    local p, events, included = A.Project(book, 0, now), {}, {}
    local result = {events = events, fee = book.fee, party = party, unassignedSales = 0}
    partyCache = {book = book, events = book.events, count = #book.events, seq = seq, party = party, result = result}
    for _, chain in ipairs(p.chains) do if chain.party == party then included[chain.id] = true end end
    local function touches(event)
        if event.chain and included[event.chain] then return true end
        local lists = {event.allocations or {}}
        for _, input in ipairs(event.inputs or {}) do
            if input.chain and included[input.chain] then return true end
            lists[#lists + 1] = input.allocations or {}
        end
        for _, list in ipairs(lists) do
            for _, allocation in ipairs(list) do
                local batch = p.byBatch[allocation.batch]
                if batch and included[batch.chain] then return true end
            end
        end
        return false
    end
    for _, event in ipairs(book.events) do
        if event.kind == "party" or included[event.id] or included[event.target] and event.kind ~= "reverse"
            or (event.kind == "convert" or event.kind == "use") and touches(event) then
            events[#events + 1] = event
        elseif event.kind == "sale" and not p.reversed[event.id] then
            local sale, count, gross, fee, allocations, offset = p.bySale[event.id], 0, 0, 0, {}, 0
            for _, allocation in ipairs(sale.allocations) do
                local batch = p.byBatch[allocation.batch]
                if sale.count and batch and included[batch.chain] then
                    count = count + allocation.count
                    gross = gross + math.floor(sale.gross * (offset + allocation.count) / sale.count)
                        - math.floor(sale.gross * offset / sale.count)
                    fee = fee + math.floor(sale.fee * (offset + allocation.count) / sale.count)
                        - math.floor(sale.fee * offset / sale.count)
                    allocations[#allocations + 1] = allocation
                end
                offset = offset + allocation.count
            end
            if not sale.count or offset < sale.count then
                for _, batch in ipairs(p.batches) do
                    local eventID = tonumber(batch.id:match("^(%d+):"))
                    if included[batch.chain] and batch.itemID == sale.itemID and eventID < sale.id and batch.at <= sale.at then
                        result.unassignedSales = result.unassignedSales + 1
                        break
                    end
                end
            end
            if count > 0 then
                events[#events + 1] = {id = sale.id, kind = "sale", at = sale.at, source = sale.source,
                    itemID = sale.itemID, count = count, gross = gross, fee = fee, allocations = allocations}
            end
        elseif event.kind == "reverse" then events[#events + 1] = event end
    end
    return result
end
function A.Proceeds(itemID, count, fee)
    if count <= 0 then return {gross = 0, cut = 0, reserve = 0, net = 0} end
    local price, selling = A.Market(itemID), A.Selling()
    if not price then return nil end
    local reserve = 0
    if (selling.losses or 0) > 0 then
        local stack = select(8, ns.Compat.ItemInfo(itemID))
        if not stack or stack <= 0 then return nil end
        local full, rest = math.floor(count / stack), count % stack
        local whole = full > 0 and ns.Disenchant.Deposit(itemID, stack, fee, selling)
        local tail = rest > 0.0000001 and ns.Disenchant.Deposit(itemID, rest, fee, selling)
        if (full > 0 and not whole) or (rest > 0.0000001 and not tail) then return nil end
        reserve = math.floor(((whole or 0) * full + (tail or 0)) * selling.losses + 0.5)
    end
    local gross = math.floor(price * count + 0.5)
    local cut = math.floor(gross * fee + 0.5)
    return {gross = gross, cut = cut, reserve = reserve, net = gross - cut - reserve}
end
local function proceeds(itemID, count, fee)
    local sale = A.Proceeds(itemID, count, fee)
    return sale and sale.net
end
function A.Expected(chain, left)
    local plan, expected = chain.plan or "disenchant", {}
    if plan == "flip" then expected[chain.itemID] = left; return expected end
    if plan == "prospect" or plan == "mill" then
        local source = ns.Prospect and ns.Prospect.Source(plan, chain.itemID)
        if not source then return nil end
        for _, outcome in ipairs(ns.Prospect.Outcomes(source)) do
            expected[outcome.id] = (expected[outcome.id] or 0) + outcome.quantity * left / ns.Prospect.OPERATION
        end
        return expected
    end
    if plan ~= "disenchant" then return nil end
    local band = chain.band and ns.Disenchant.Band(chain.band)
    if not band then
        local candidate = ns.Disenchant.Candidate(chain.itemID, chain.link)
        band = candidate and ns.Disenchant.Band(candidate.band)
    end
    if not band then return nil end
    for _, output in ipairs(band.outputs) do
        expected[output.itemID] = (expected[output.itemID] or 0) + left * output.chance * (output.minCount + output.maxCount) / 2
    end
    return expected
end
function A.Expectation(chain, fee)
    local D, selling = ns.Disenchant, A.Selling()
    if (chain.plan or "disenchant") == "disenchant" then
        local band = chain.band and D and D.Band(chain.band)
        local estimate = band and D.Estimate(band, chain.cost, fee, nil, selling)
        if not estimate or not estimate.net then return nil end
        return {gross = estimate.gross, net = estimate.net, margin = estimate.margin}
    end
    local expected = A.Expected(chain, chain.count)
    if not expected then return nil end
    local gross, net = 0, 0
    for id, count in pairs(expected) do
        local sale = A.Proceeds(id, count, fee)
        if not sale then return nil end
        gross, net = gross + sale.gross, net + sale.net
    end
    return {gross = gross, net = net, margin = net - chain.cost}
end
function A.Forecast(p, fee, method)
    fee = fee or A.Book().fee or 0.05
    local f = {materials = {}, rows = {}, cost = p.stockCost + p.holding, net = 0,
        complete = not p.unknownStock and not p.unknownCost and p.unknownSales == 0, pending = 0, stale = 0,
        realized = p.realizedAll or p.realized}
    local function material(id)
        if not f.materials[id] then
            local row = {itemID = id, actual = 0, expected = 0}
            f.materials[id] = row; f.rows[#f.rows + 1] = row
        end
        return f.materials[id]
    end
    for id, m in pairs(p.materials) do
        if m.remaining > 0 then material(id).actual = m.remaining end
    end
    for _, chain in ipairs(p.chains) do
        local left = chain.count - chain.processed
        if method and A.Kind(chain) ~= method then left = 0 end
        if chain.state == "sent" and left > 0 then f.pending = f.pending + left; f.complete = false
        elseif chain.state == "bought" and left > 0 then
            local expected = A.Expected(chain, left)
            if not expected then f.complete = false
            else
                for id, count in pairs(expected) do
                    local row = material(id)
                    row.expected = row.expected + count
                end
            end
        end
    end
    for _, row in ipairs(f.rows) do
        row.count, row.price = row.actual + row.expected, A.Market(row.itemID)
        row.net = proceeds(row.itemID, row.count, fee)
        if row.net then f.net = f.net + row.net else f.complete = false end
        if not ns.Disenchant.Fresh(row.itemID) then f.stale = f.stale + 1 end
    end
    table.sort(f.rows, function(a, b) return a.itemID < b.itemID end)
    f.profit = f.complete and (f.realized + f.net - f.cost) or nil
    return f
end
function A.CraftForecast(forecast, fee)
    fee = fee or A.Book().fee or 0.05
    local rows = {}
    for _, profession in ipairs(ns.Crafting.order) do
        local catalog = ns.craftCatalogs[profession]
        for _, recipe in ipairs(catalog and catalog.recipes or {}) do
            if not ns.Hidden.Is(recipe.raw) then
                local inputs, crafts = {}, nil
                for _, input in ipairs(recipe.inputs) do inputs[input[1]] = (inputs[input[1]] or 0) + input[2] end
                for id, count in pairs(inputs) do
                    local stock = forecast.materials[id]
                    if stock and stock.count > 0 then
                        local enough = math.floor((stock.count + 0.0000001) / count)
                        crafts = math.min(crafts or enough, enough)
                    end
                end
                if crafts and crafts > 0 then
                    local row = {recipe = recipe, crafts = crafts, count = crafts * recipe.count, cash = 0,
                        net = 0, missing = 0, stale = 0, short = 0, inputs = {}}
                    local known = forecast.complete
                    for id, count in pairs(inputs) do
                        local stock, need = forecast.materials[id], count * crafts
                        local own = math.min(stock and stock.count or 0, need)
                        local extra, quote = need - own, ns.Crafting.Quote(id)
                        row.inputs[#row.inputs + 1] = {itemID = id, count = need, own = own, extra = extra}
                        if extra > 0 then
                            if quote and quote.price and quote.miss == 0 and quote.complete ~= false
                                and (not quote.at or quote.at <= time()) then row.cash = row.cash + extra * quote.price
                            else known = false; row.missing = row.missing + 1 end
                            if quote and not quote.vendor and not quote.manual then
                                if not ns.Markets.Fresh(id) then row.stale = row.stale + 1 end
                                if extra > (quote.units or 0) then row.short = row.short + 1 end
                            end
                        end
                    end
                    for _, stock in ipairs(forecast.rows) do
                        local left = math.max(0, stock.count - (inputs[stock.itemID] or 0) * crafts)
                        local value = proceeds(stock.itemID, left, fee)
                        if value then row.net = row.net + value else known = false end
                    end
                    local value = proceeds(recipe.raw, row.count, fee)
                    if value then row.net = row.net + value else known = false; row.missing = row.missing + 1 end
                    if not ns.Markets.Fresh(recipe.raw) then row.stale = row.stale + 1 end
                    row.net = row.net - row.cash
                    row.profit = known and (forecast.realized + row.net - forecast.cost) or nil
                    row.gain = row.profit and forecast.profit and row.profit - forecast.profit or nil
                    row.known = ns.Recipes.Known(recipe.spell, ns.T(catalog.labelKey))
                    rows[#rows + 1] = row
                end
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.profit == b.profit then return a.recipe.raw < b.recipe.raw end
        if not a.profit then return false end
        if not b.profit then return true end
        return a.profit > b.profit
    end)
    return rows
end
local function recipes()
    local list = {}
    for _, profession in ipairs(ns.Crafting and ns.Crafting.order or {}) do
        local catalog = ns.craftCatalogs[profession]
        for _, recipe in ipairs(catalog and catalog.recipes or {}) do
            if not ns.Hidden.Is(recipe.raw) then
                list[#list + 1] = {raw = recipe.raw, spell = recipe.spell, count = recipe.count, inputs = recipe.inputs,
                    profession = profession, cooldown = recipe.cooldown, label = catalog.labelKey}
            end
        end
    end
    for _, family in ipairs(ns.gemFamilies or {}) do
        for _, member in ipairs(family.members) do
            local spell = family.spells and family.spells[member]
            if member ~= family.raw and spell and not ns.Hidden.Is(member) then
                list[#list + 1] = {raw = member, spell = spell, count = 1, inputs = {{family.raw, 1}},
                    profession = "jewelry", family = family.raw, label = "jewelrySection"}
            end
        end
    end
    return list
end
function A.NextStep(p, fee, limit)
    fee = fee or A.Book().fee or 0.05
    local rows = {}
    for _, recipe in ipairs(recipes()) do
        local need = {}
        local order = {}
        for _, input in ipairs(recipe.inputs) do
            if not need[input[1]] then order[#order + 1] = input[1] end
            need[input[1]] = (need[input[1]] or 0) + input[2]
        end
        local crafts, fromBags = nil, nil
        for _, id in ipairs(order) do
            local m = p.materials[id]
            local party = m and m.remaining or 0
            local bags = GetItemCount and GetItemCount(id, false) or 0
            if party > 0 then
                local enough = math.floor(party / need[id])
                crafts = math.min(crafts or enough, enough)
            elseif bags > 0 then
                local enough = math.floor(bags / need[id])
                fromBags = math.min(fromBags or enough, enough)
            end
        end
        crafts = crafts or fromBags
        if crafts and crafts > 0 then
            local row = {recipe = recipe, crafts = crafts, count = crafts * recipe.count, inputs = {}, cash = 0,
                missing = 0, inputsMarket = 0}
            local known = true
            for _, id in ipairs(order) do
                local m = p.materials[id]
                local total = need[id] * crafts
                local stock = math.max(m and m.remaining or 0, GetItemCount and GetItemCount(id, false) or 0)
                local own = math.min(total, stock)
                local quote = ns.Crafting.Quote(id)
                local price = quote and quote.price and quote.miss == 0 and quote.complete ~= false and quote.price or nil
                row.inputs[#row.inputs + 1] = {itemID = id, need = total, own = own, extra = total - own, price = price}
                if price then
                    row.inputsMarket = row.inputsMarket + price * total
                    row.cash = row.cash + price * (total - own)
                else known = false; row.missing = row.missing + 1 end
            end
            local output = A.Market(recipe.raw)
            if output then row.value = math.floor(output * row.count * (1 - fee)) else known = false; row.missing = row.missing + 1 end
            row.margin = known and row.value - row.inputsMarket or nil
            row.known = ns.Recipes.Known(recipe.spell, ns.T(recipe.label))
            row.owners = ns.Recipes.Owners and ns.Recipes.Owners(recipe.spell) or {}
            rows[#rows + 1] = row
        end
    end
    table.sort(rows, function(a, b)
        if (a.margin == nil) ~= (b.margin == nil) then return a.margin ~= nil end
        if a.margin ~= b.margin then return a.margin > b.margin end
        return a.recipe.raw < b.recipe.raw
    end)
    local cut = {}
    for index = 1, math.min(limit or 10, #rows) do cut[index] = rows[index] end
    return cut
end
function A.ForecastTargets(forecast)
    local targets, seen = {}, {}
    local function add(id)
        if not seen[id] and not ns.vendorPrices[id] then targets[#targets + 1] = id; seen[id] = true end
    end
    for _, stock in ipairs(forecast.rows) do add(stock.itemID) end
    for _, row in ipairs(A.CraftForecast(forecast)) do
        for _, id in ipairs(ns.Crafting.Targets(row.recipe)) do add(id) end
    end
    return targets
end
local function liveChain(p, id)
    p = p or A.Project()
    return p.byChain[id], p
end
function A.Buy(values, source)
    if not integer(values.itemID, 1, 10000000) or not integer(values.count, 1, 1000)
        or not integer(values.cost, 1) or (values.plan ~= nil and not A.ValidPlan(values.plan)) then return nil, "acInvalid" end
    return append({kind = "buy", itemID = values.itemID, link = values.link, suffix = values.suffix or 0,
        count = values.count, cost = values.cost, owner = A.Text(values.owner), level = values.level,
        quality = values.quality, band = values.band, sent = values.sent == true or nil,
        plan = values.plan or "disenchant"}, source)
end
A.BASES = {"free", "model", "vendor", "own"}
function A.UnitCost(item, basis, own)
    if basis == "free" then return 0 end
    if basis == "own" then return integer(own, 0) and own or nil end
    if basis == "vendor" then
        local vendor = select(11, ns.Compat.ItemInfo(item.link or item.itemID))
        return type(vendor) == "number" and vendor > 0 and vendor or nil
    end
    if basis ~= "model" then return nil end
    local fee, plan = A.Book().fee or 0.05, item.plan or "disenchant"
    if plan == "prospect" or plan == "mill" then
        local source = ns.Prospect and ns.Prospect.Source(plan, item.itemID)
        local estimate = source and ns.Prospect.Estimate(source, nil, fee)
        return estimate and estimate.net and estimate.exact and math.max(0, math.floor(estimate.net / ns.Prospect.OPERATION)) or nil
    end
    if plan == "flip" then
        local price = A.Market(item.itemID)
        return price and math.max(0, math.floor(price * (1 - fee))) or nil
    end
    local D = ns.Disenchant
    local band = item.band and D and D.Band(item.band)
    local estimate = band and D.Estimate(band, 0, fee, nil, A.Selling())
    return estimate and estimate.net and math.max(0, math.floor(estimate.net)) or nil
end
function A.Intake(values, source)
    local known = false
    for _, basis in ipairs(A.BASES) do if values.basis == basis then known = true end end
    if not known or not integer(values.itemID, 1, 10000000) or not integer(values.count, 1, 1000)
        or not integer(values.cost, 0) or (values.plan ~= nil and not A.ValidPlan(values.plan)) then return nil, "acInvalid" end
    return append({kind = "buy", itemID = values.itemID, link = values.link, suffix = values.suffix or 0,
        count = values.count, cost = values.cost, basis = values.basis, from = values.from and A.Text(values.from) or nil,
        level = values.level, quality = values.quality, band = values.band, plan = values.plan or "disenchant"}, source or "bags")
end
function A.Resolve(target, won, source)
    local chain = liveChain(nil, target)
    if not chain or chain.state ~= "sent" then return nil, "acState" end
    return append({kind = won and "won" or "lost", target = target}, source)
end
function A.Receive(target, count, source)
    local chain = liveChain(nil, target)
    if not chain or chain.state == "lost" or not integer(count, 1, chain.count - chain.received) then return nil, "acState" end
    return append({kind = "receive", target = target, count = count}, source)
end
function A.Disenchant(target, outputs, source)
    return A.Convert({method = "disenchant", inputs = {{chain = target, count = 1}}, outputs = outputs}, source)
end
function A.Split(cost, outputs)
    local weights, total, priced = {}, 0, true
    for _, output in ipairs(outputs) do if not A.Market(output.itemID) then priced = false end end
    for index, output in ipairs(outputs) do
        weights[index] = output.count * (priced and A.Market(output.itemID) or 1)
        total = total + weights[index]
    end
    if total <= 0 then
        total = 0
        for index, output in ipairs(outputs) do weights[index] = math.max(output.count or 0, 1); total = total + weights[index] end
    end
    local given, copy = 0, {}
    for index, output in ipairs(outputs) do
        local share = index == #outputs and cost - given or math.floor(cost * (weights[index] / total))
        given = given + share
        copy[index] = {itemID = output.itemID, count = output.count, cost = share}
    end
    return copy
end
A.METHODS = {"disenchant", "prospect", "mill", "craft"}
function A.ValidMethod(method)
    for _, known in ipairs(A.METHODS) do if method == known then return true end end
    return false
end
function A.AllowedOutput(method, itemID)
    if not integer(itemID, 1, 10000000) then return false end
    if method == "disenchant" then
        for _, id in ipairs(ns.disenchantMaterials) do if id == itemID then return true end end
        return false
    end
    if method == "prospect" or method == "mill" then return ns.Prospect ~= nil and ns.Prospect.IsTarget(method, itemID) end
    return true
end
function A.Post(values)
    if not integer(values.itemID, 1, 10000000) or not integer(values.stack, 1, 1000)
        or not integer(values.stacks, 1, 100) or not integer(values.bid or 0, 0) then return nil, "acInvalid" end
    return append({kind = "post", itemID = values.itemID, stack = values.stack, stacks = values.stacks,
        bid = values.bid or 0, buyout = values.buyout or 0, hours = values.hours or 24}, "auction")
end
function A.Unpost(target)
    local post = A.Project().byPost[target]
    if not post or not post.active then return nil, "acState" end
    return append({kind = "unpost", target = target}, "auction")
end
local function allocate(p, itemID, count, used)
    local allocations, left = {}, count
    for _, batch in ipairs(p.batches) do
        if batch.itemID == itemID and left > 0 then
            local gone = batch.sold + (batch.used or 0)
            local take = math.min(left, batch.count - gone)
            if take > 0 then
                local cost = batch.cost and (math.floor(batch.cost * (gone + take) / batch.count) - batch.soldCost - (batch.usedCost or 0)) or nil
                allocations[#allocations + 1] = {batch = batch.id, count = take, cost = cost}
                if used then batch.used, batch.usedCost = (batch.used or 0) + take, (batch.usedCost or 0) + (cost or 0)
                else batch.sold, batch.soldCost = batch.sold + take, batch.soldCost + (cost or 0) end
                left = left - take
            end
        end
    end
    return allocations, left
end
function A.Convert(values, source)
    if not A.ValidMethod(values.method) or type(values.inputs) ~= "table" or #values.inputs == 0 then return nil, "acInvalid" end
    local p = A.Project()
    local combined, order = {}, {}
    for _, output in ipairs(values.outputs or {}) do
        if not A.AllowedOutput(values.method, output.itemID) or not integer(output.count, 1, 1000) then return nil, "acInvalid" end
        if not combined[output.itemID] then order[#order + 1] = output.itemID end
        combined[output.itemID] = (combined[output.itemID] or 0) + output.count
    end
    if #order == 0 then return nil, "acInvalid" end
    local inputs, total, known, first = {}, 0, true, nil
    for _, input in ipairs(values.inputs) do
        if input.chain then
            local chain = p.byChain[input.chain]
            if not chain or chain.state == "lost" or not integer(input.count, 1, chain.count - chain.processed) then return nil, "acState" end
            local before = chain.processed
            chain.processed = chain.processed + input.count
            total = total + math.floor(chain.cost * chain.processed / chain.count) - math.floor(chain.cost * before / chain.count)
            first = first or chain
            inputs[#inputs + 1] = {chain = chain.id, count = input.count}
        else
            if not integer(input.itemID, 1, 10000000) or not integer(input.count, 1, 100000) then return nil, "acInvalid" end
            local allocations, left = allocate(p, input.itemID, input.count, true)
            for _, allocation in ipairs(allocations) do
                if allocation.cost then total = total + allocation.cost else known = false end
                local batch = p.byBatch[allocation.batch]
                if not first and batch then first = p.byChain[batch.chain] end
            end
            if left > 0 then known = false end
            inputs[#inputs + 1] = {itemID = input.itemID, count = input.count, allocations = allocations,
                missing = left > 0 and left or nil}
        end
    end
    local outputs = {}
    for index, itemID in ipairs(order) do outputs[index] = {itemID = itemID, count = combined[itemID]} end
    if known then outputs = A.Split(total, outputs) end
    local id = append({kind = "convert", method = values.method, spell = values.spell, inputs = inputs, outputs = outputs,
        chain = first and first.id or nil}, source)
    A.lastConvert = {at = GetTime and GetTime() or 0, method = values.method}
    if values.method == "disenchant" and first and ns.DisenchantLog then
        ns.DisenchantLog.Record({itemID = first.itemID, suffix = first.suffix, link = first.link, level = first.level,
            quality = first.quality, band = first.band, outputs = outputs, bought = first.basis == nil, chain = first.id, ledger = id},
            source == "cast" and "cast" or "manual")
    end
    return id
end
function A.Use(itemID, count, source)
    local p = A.Project()
    local m = p.materials[itemID]
    if not m or not integer(count, 1, m.remaining) then return nil, "acState" end
    local allocations = allocate(p, itemID, count, true)
    return append({kind = "use", itemID = itemID, count = count, allocations = allocations}, source)
end
function A.Sell(values, source)
    if not integer(values.gross, 1) or not integer(values.fee or 0, 0, values.gross)
        or (values.count ~= nil and not integer(values.count, 1, 1000000)) then return nil, "acInvalid" end
    local allocations, left
    if values.count then allocations, left = allocate(A.Project(), values.itemID, values.count) end
    return append({kind = "sale", itemID = values.itemID, count = values.count, gross = values.gross,
        fee = values.fee or 0, post = values.post, allocations = allocations, at = values.at,
        unallocated = left and left > 0 and left or nil, stockless = values.stockless or nil}, source)
end
function A.SaleCount(target, count)
    local p = A.Project()
    local sale = p.bySale[target]
    if not sale or not integer(count, 1, 1000000) then return nil, "acInvalid" end
    for _, allocation in ipairs(sale.allocations) do
        local batch = p.byBatch[allocation.batch]
        if batch then batch.sold, batch.soldCost = batch.sold - allocation.count, batch.soldCost - (allocation.cost or 0) end
    end
    local allocations, left = allocate(p, sale.itemID, count)
    return append({kind = "count", target = target, count = count, allocations = allocations,
        unallocated = left > 0 and left or nil})
end
function A.Reversible(p, event)
    if event.kind == "party" or event.kind == "reverse" or p.reversed[event.id] then return false end
    if event.kind == "post" then
        local post = p.byPost[event.id]
        return post ~= nil and post.sold == 0
    end
    if event.kind == "buy" then
        local chain = p.byChain[event.id]
        if not chain then return false end
        if chain.plan ~= "flip" then return chain.processed == 0 end
        for _, batch in ipairs(p.batches) do
            if batch.chain == chain.id and batch.sold > 0 then return false end
        end
        return true
    end
    if event.kind == "receive" then
        local batch = p.byBatch[event.id .. ":1"]
        return not batch or batch.sold == 0
    end
    if event.kind == "disenchant" or event.kind == "convert" then
        for index = 1, #(event.outputs or {}) do
            local batch = p.byBatch[event.id .. ":" .. index]
            if batch and batch.sold + batch.used > 0 then return false end
        end
        if event.kind == "disenchant" then return p.byChain[event.target] ~= nil end
        for _, input in ipairs(event.inputs or {}) do
            if input.chain and not p.byChain[input.chain] then return false end
        end
        return true
    end
    return true
end
function A.Reverse(target)
    local p = A.Project()
    local event = p.byEvent[target]
    if not event or event.kind == "reverse" or p.reversed[target] then return nil, "acState" end
    if not A.Reversible(p, event) then return nil, "acDepends" end
    local id = append({kind = "reverse", target = target})
    if (event.kind == "disenchant" or event.kind == "convert" and event.method == "disenchant") and ns.DisenchantLog then
        ns.DisenchantLog.CancelLedger(target)
    end
    return id
end
function A.SetFee(fee)
    A.Book().fee = fee; A.Changed()
end
function A.Kind(chain)
    return chain.method or chain.plan or "disenchant"
end
local function expectedGross(chain, fee)
    local kind = A.Kind(chain)
    if kind == "disenchant" then
        local D = ns.Disenchant
        local band = chain.band and D and D.Band(chain.band)
        local estimate = band and D.Estimate(band, chain.cost / chain.count, fee, nil, A.Selling())
        return estimate and estimate.gross and estimate.gross * chain.processed or nil
    end
    if kind == "prospect" or kind == "mill" then
        local source = ns.Prospect and ns.Prospect.Source(kind, chain.itemID)
        local estimate = source and ns.Prospect.Estimate(source, nil, fee)
        return estimate and estimate.exact and estimate.gross and estimate.gross / ns.Prospect.OPERATION * chain.processed or nil
    end
    return nil
end
function A.Analysis(p, by, method)
    local D, fee = ns.Disenchant, A.Book().fee or 0.05
    local groups, order = {}, {}
    for _, chain in ipairs(p.chains) do
        local kind = A.Kind(chain)
        if chain.processed > 0 and chain.gross and (not method or kind == method) then
            local grouped = kind == "disenchant" and by or "item"
            local key = grouped == "level" and (chain.level or 0) or (grouped == "band" and (chain.band or "?") or chain.itemID)
            if grouped == "item" and method == nil then key = kind .. ":" .. chain.itemID end
            local g = groups[key]
            if not g then
                g = {key = key, itemID = chain.itemID, level = chain.level, band = chain.band, kind = kind, count = 0, cost = 0,
                    gross = 0, expected = 0, value = 0, result = 0, units = 0, expectedUnits = 0, known = true,
                    crafted = ns.Crafting and ns.Crafting.byItem and ns.Crafting.byItem[chain.itemID] ~= nil}
                groups[key] = g; order[#order + 1] = g
            end
            local share = chain.processed / chain.count
            g.count = g.count + chain.processed
            g.cost = g.cost + chain.cost * share
            g.gross, g.value = g.gross + chain.gross, g.value + (chain.value or 0)
            g.result = g.result + (chain.value or 0) - chain.cost * share
            local band = kind == "disenchant" and chain.band and D and D.Band(chain.band)
            local main = band and D.MainOutput(band)
            if main then
                g.main = g.main or main.itemID
                g.units = g.units + (chain.outputs[main.itemID] or 0)
                g.expectedUnits = g.expectedUnits + main.chance * (main.minCount + main.maxCount) / 2 * chain.processed
            end
            local expected = expectedGross(chain, fee)
            if expected then g.expected = g.expected + expected else g.known = false end
        end
    end
    for _, g in ipairs(order) do
        g.luck = g.known and g.expected > 0 and g.gross / g.expected * 100 or nil
    end
    table.sort(order, function(a, b)
        if a.result ~= b.result then return a.result < b.result end
        return a.count > b.count
    end)
    return order
end
function A.Levels(itemID)
    local p = A.Project()
    local m = p.materials[itemID]
    if not m then return end
    local fee = A.Book().fee or 0.05
    local levels = {sales = {}, count = m.remaining}
    if m.remaining > 0 and not m.unknownCost then
        levels.cost = m.cost / m.remaining
        levels.breakEven = math.ceil(levels.cost / (1 - fee))
    end
    for _, sale in ipairs(p.sales) do
        if sale.itemID == itemID and sale.count then
            levels.sales[#levels.sales + 1] = {at = sale.at, price = sale.gross / sale.count, count = sale.count}
        end
    end
    return levels
end
