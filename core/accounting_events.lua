local _, ns = ...
local E = {mailOpen = false, queue = {}, echo = {}, taken = {}, gifts = {}, arriving = {}}
ns.AccountingEvents = E
local CAPTURE = 60
local QUIET = 0.6
local ATTACHMENTS = 12
function E.BagCount(itemID, suffix)
    if not GetContainerNumSlots or not GetContainerItemLink or not GetContainerItemInfo then return nil end
    local count = 0
    for bag = 0, 4 do
        for slot = 1, ns.Compat.BagSlots(bag) or 0 do
            local id, random = ns.Lot.FromLink(GetContainerItemLink(bag, slot))
            if id == itemID and random == (suffix or 0) then
                local quantity = select(2, ns.Compat.BagItemIcon(bag, slot))
                if not quantity then return nil end
                count = count + quantity
            end
        end
    end
    return count
end
function E.WonName(text)
    if type(text) ~= "string" or type(ERR_AUCTION_WON_S) ~= "string" then return nil end
    local prefix, suffix = ERR_AUCTION_WON_S:match("^(.-)%%s(.-)$")
    if not prefix or #text <= #prefix + #suffix then return nil end
    if text:sub(1, #prefix) ~= prefix or text:sub(#text - #suffix + 1) ~= suffix then return nil end
    return text:sub(#prefix + 1, #text - #suffix)
end
local refusals
function E.Refusal(text)
    if not refusals then
        refusals = {}
        for _, key in ipairs({"ERR_ITEM_NOT_FOUND", "ERR_AUCTION_HIGHER_BID", "ERR_NOT_ENOUGH_MONEY",
            "ERR_AUCTION_BID_OWN", "ERR_AUCTION_DATABASE_ERROR", "ERR_ITEM_MAX_COUNT"}) do
            if type(_G[key]) == "string" then refusals[_G[key]] = true end
        end
    end
    return text ~= nil and refusals[text] == true
end
local function intent(itemID, link)
    local plan, model = ns.Accounting.Intent(itemID, link)
    if not plan then return nil end
    if model then return plan, {level = model.level, quality = model.quality, band = model.band} end
    local _, _, quality, level = ns.Compat.ItemInfo(link or itemID)
    return plan, {level = level, quality = quality}
end
function E.Bid(kind, index, amount)
    if not GetAuctionItemInfo or (kind ~= "list" and kind ~= "bidder") then return end
    local name, _, count, _, _, _, _, _, buyout, _, _, owner = GetAuctionItemInfo(kind, index)
    if not name then return end
    local entry = {name = name, buyout = buyout and buyout > 0 and amount and amount >= buyout or false, at = GetTime()}
    if entry.buyout then
        local link = GetAuctionItemLink and GetAuctionItemLink(kind, index)
        local itemID, suffix = ns.Lot.FromLink(link)
        local plan, info = intent(itemID, link)
        if plan then
            entry.event = ns.Accounting.Buy({itemID = itemID, link = link, suffix = suffix, count = count or 1,
                cost = amount, owner = owner, level = info.level, quality = info.quality, band = info.band,
                sent = true, plan = plan}, "auction")
        end
    end
    E.queue[#E.queue + 1] = entry
    E.last = entry
end
local function prune(now)
    while E.queue[1] and now - E.queue[1].at > ns.Accounting.PENDING do table.remove(E.queue, 1) end
end
function E.PageError(text)
    if text == nil or text ~= ERR_AUCTION_DATABASE_ERROR or not ns.Query then return false end
    prune(GetTime())
    local first = E.queue[1]
    return first ~= nil and (ns.Query.lastAt or 0) > first.at
end
function E.Answer(won, name)
    prune(GetTime())
    local index = E.queue[1] and 1 or nil
    if name then
        index = nil
        for i, entry in ipairs(E.queue) do
            if entry.buyout and entry.name == name then index = i; break end
        end
    end
    local entry = index and table.remove(E.queue, index)
    if not entry then return end
    if entry.event then ns.Accounting.Resolve(entry.event, won, "auction") end
    if ns.Buy and ns.Buy.OnAnswer then ns.Buy.OnAnswer(entry, won) end
end
function E.Message(event, text)
    if event == "UI_ERROR_MESSAGE" then
        if E.Refusal(text) and not E.PageError(text) then E.Answer(false) end
        if E.posting and text ~= ERR_AUCTION_DATABASE_ERROR and E.Refusal(text) then
            local posting = E.posting
            E.posting = nil
            if posting.stacks > 1 and (posting.created or 0) > 0 then
                posting.stacks = posting.created
                ns.Accounting.Post(posting)
            end
        end
        return
    end
    if text == ERR_AUCTION_BID_PLACED then
        local first = E.queue[1]
        if first and first.buyout then E.echo[first.name] = (E.echo[first.name] or 0) + 1 end
        E.Answer(true)
    elseif text == ERR_AUCTION_STARTED then
        local posting = E.posting
        if posting and posting.stacks == 1 then E.posting = nil; ns.Accounting.Post(posting) end
    else
        local name = E.WonName(text)
        if not name then return end
        if (E.echo[name] or 0) > 0 then E.echo[name] = E.echo[name] - 1; return end
        E.Answer(true, name)
    end
end
function E.ItemByName(name, p)
    if not name then return nil end
    p = p or ns.Accounting.Project()
    for id in pairs(p.materials) do
        if ns.Compat.ItemInfo(id) == name then return id end
    end
    for _, id in ipairs(ns.disenchantMaterials) do
        if ns.Compat.ItemInfo(id) == name then return id end
    end
end
function E.Posting(bid, buyout, runTime, stackSize, numStacks)
    if not GetAuctionSellItemInfo then return end
    local name, _, count = GetAuctionSellItemInfo()
    local p = ns.Accounting.Project()
    local itemID = E.ItemByName(name, p)
    local m = itemID and p.materials[itemID]
    if not m or m.remaining <= 0 then E.posting = nil; return end
    E.posting = {itemID = itemID, stack = stackSize or count or 1, stacks = numStacks or 1, bid = bid or 0,
        buyout = buyout or 0, hours = ({12, 24, 48})[runTime] or 24, created = 0}
end
function E.Cancelling(index)
    if not GetAuctionItemInfo then return end
    local name, _, count, _, _, _, _, _, buyout = GetAuctionItemInfo("owner", index)
    local p = ns.Accounting.Project()
    local itemID = E.ItemByName(name, p)
    if not itemID then return end
    for _, post in ipairs(p.posts) do
        if post.active and post.itemID == itemID and post.stack == count and post.buyout == (buyout or 0) then
            ns.Accounting.Unpost(post.id); return
        end
    end
end
local function invoice(index)
    local kind, itemName, _, bid, buyout, deposit, fee = GetInboxInvoiceInfo(index)
    if kind ~= "seller" or not itemName or not bid or bid <= 0 then return nil end
    return table.concat({index, itemName, bid, buyout or 0, deposit or 0, fee or 0}, "|"), itemName, bid, fee
end
local function inboxSize()
    return GetInboxNumItems and GetInboxNumItems() or 0
end
function E.InboxChanged()
    if not GetInboxInvoiceInfo then return end
    local size = inboxSize()
    for key, taken in pairs(E.taken) do
        if taken.size ~= size or invoice(taken.index) ~= key or GetTime() - taken.at > 30 then E.taken[key] = nil end
    end
end
function E.Taking(index)
    if not GetInboxInvoiceInfo then return end
    local key, itemName, bid, fee = invoice(index)
    if not key then return end
    local daysLeft = GetInboxHeaderInfo and select(7, GetInboxHeaderInfo(index))
    if E.taken[key] and GetTime() - E.taken[key].at < 30 then return end
    E.taken[key] = {at = GetTime(), index = index, size = inboxSize()}
    local A = ns.Accounting
    local p = A.Project()
    local itemID = E.ItemByName(itemName, p)
    local m = itemID and p.materials[itemID]
    if not m then return end
    local stockless = m.remaining <= 0 and m.posted <= 0
    local now, post = time(), nil
    for _, candidate in ipairs(p.posts) do
        local open = candidate.sold + candidate.removed < candidate.stacks and candidate.ends + 7200 > now
        local exact = candidate.buyout == bid
        local byBid = candidate.bid <= bid and (candidate.buyout == 0 or bid < candidate.buyout)
        if candidate.itemID == itemID and open and (exact or byBid) and (not post or (exact and post.buyout ~= bid)) then
            post = candidate
        end
    end
    local count = post and post.stack or nil
    local at = type(daysLeft) == "number" and math.min(now, math.floor(now + (daysLeft - 30) * 86400)) or now
    A.Sell({itemID = itemID, count = count, gross = bid, fee = fee or 0, post = post and post.id, at = at,
        stockless = stockless}, "mail")
end
local projection = {}
function E.Projection()
    local book, root = ns.Accounting.Book(), ns.Store.DB().ledger
    local seq, minute, cached = root and root.seq, math.floor(time() / 60), projection
    if cached.book == book and cached.events == book.events and cached.count == #book.events and cached.seq == seq
        and cached.minute == minute then
        return cached.result
    end
    local result = ns.Accounting.Project(book)
    projection = {book = book, events = book.events, count = #book.events, seq = seq, minute = minute, result = result}
    return result
end
local function awaited()
    local keys = {}
    for _, chain in ipairs(E.Projection().chains) do
        if chain.stage == "sent" or chain.stage == "unsure" or chain.stage == "mail" then
            local key = chain.itemID .. ":" .. chain.suffix
            keys[key] = keys[key] or {itemID = chain.itemID, suffix = chain.suffix, chains = {}}
            local list = keys[key].chains
            list[#list + 1] = chain
        end
    end
    return keys
end
function E.CheckMail()
    if not E.mailOpen then return end
    E.mailCounts = E.mailCounts or {}
    for key, info in pairs(awaited()) do
        local count = E.BagCount(info.itemID, info.suffix)
        local before = E.mailCounts[key]
        if count and before and count > before then
            local left = count - before
            local gift = math.min(left, E.arriving[key] or 0)
            E.arriving[key], left = (E.arriving[key] or 0) - gift, left - gift
            for _, chain in ipairs(info.chains) do
                local take = math.min(left, chain.count - chain.received)
                if take > 0 then
                    if chain.state == "sent" then ns.Accounting.Resolve(chain.id, true, "mail") end
                    ns.Accounting.Receive(chain.id, take, "mail")
                    left = left - take
                end
            end
        end
        if count then E.mailCounts[key] = count end
    end
end
function E.Gift(index, attach)
    if not GetInboxHeaderInfo or not GetInboxItemLink then return end
    local _, _, sender, _, _, _, _, items, _, _, _, canReply = GetInboxHeaderInfo(index)
    if not canReply or (items or 0) == 0 or (GetInboxInvoiceInfo and GetInboxInvoiceInfo(index)) then return end
    for a = attach or 1, attach or ATTACHMENTS do
        local link = GetInboxItemLink(index, a)
        local itemID, suffix = ns.Lot.FromLink(link)
        if itemID and intent(itemID, link) then
            local key = itemID .. ":" .. suffix
            local count = GetInboxItem and select(3, GetInboxItem(index, a)) or 1
            local gift = E.gifts[key] or {count = 0}
            gift.count, gift.from = gift.count + (count or 1), sender
            E.gifts[key] = gift
            E.arriving[key] = (E.arriving[key] or 0) + (count or 1)
        end
    end
    if ns.CollectUI then ns.CollectUI.Refresh() end
end
function E.Untracked()
    local bags = ns.DisenchantLog.BagSnapshot()
    if not bags then return {} end
    local held, p = {}, E.Projection()
    for _, chain in ipairs(p.chains) do
        if chain.state ~= "lost" then
            local key = chain.itemID .. ":" .. chain.suffix
            held[key] = (held[key] or 0) + math.max(0, chain.received - chain.processed)
        end
    end
    for id, m in pairs(p.materials) do
        local key = id .. ":0"
        held[key] = (held[key] or 0) + math.max(0, m.remaining)
    end
    local out = {}
    for key, item in pairs(bags) do
        local count = item.count - (held[key] or 0)
        local plan, info = nil, nil
        if count > 0 then plan, info = intent(item.itemID, item.link) end
        if plan then
            local gift = E.gifts[key]
            out[#out + 1] = {key = key, itemID = item.itemID, suffix = item.suffix, link = item.link, count = count,
                level = info.level or 0, quality = info.quality, band = info.band, plan = plan,
                gift = gift and math.min(gift.count, count) or 0, from = gift and gift.from}
        end
    end
    table.sort(out, function(a, b)
        if (a.gift > 0) ~= (b.gift > 0) then return a.gift > 0 end
        if a.level ~= b.level then return a.level > b.level end
        return a.key < b.key
    end)
    return out
end
function E.GiftCount()
    if not next(E.gifts) then return 0 end
    local total = 0
    for _, item in ipairs(E.Untracked()) do total = total + item.gift end
    return total
end
function E.Add(items, basis, own)
    if #items == 0 then return nil, "acIntakeNone" end
    local A, costs, missing = ns.Accounting, {}, 0
    for index, item in ipairs(items) do
        costs[index] = A.UnitCost(item, basis, own)
        if not costs[index] then missing = missing + 1 end
    end
    if missing > 0 then return nil, basis == "own" and "acInvalid" or "acIntakeNoPrice", missing end
    local added = 0
    for index, item in ipairs(items) do
        local gift = item.gift > 0 and E.gifts[item.key]
        local id = A.Intake({itemID = item.itemID, link = item.link, suffix = item.suffix, count = item.count,
            cost = costs[index] * item.count, basis = basis, from = gift and gift.from or nil, level = item.level,
            quality = item.quality, band = item.band, plan = item.plan}, gift and "mail" or "bags")
        if id then
            added = added + item.count
            if gift then
                gift.count = gift.count - item.count
                if gift.count <= 0 then E.gifts[item.key] = nil end
            end
        end
    end
    return added
end
local function disenchantable()
    local keys = {}
    for _, chain in ipairs(ns.Accounting.Project().chains) do
        if chain.state ~= "lost" and chain.received > chain.processed and chain.plan == "disenchant" then
            local key = chain.itemID .. ":" .. chain.suffix
            keys[key] = keys[key] or {}
            local list = keys[key]
            list[#list + 1] = chain
        end
    end
    return keys
end
local METHOD_SPELLS = {[13262] = "disenchant", [31252] = "prospect", [51005] = "mill"}
local spellNames
local function nameEntry(name, entry)
    if name and not spellNames[name] then spellNames[name] = entry end
end
function E.SpellKind(name)
    if not spellNames then
        spellNames = {}
        for spell, method in pairs(METHOD_SPELLS) do nameEntry(ns.Compat.SpellIcon(spell), {method = method, spell = spell}) end
        for _, profession in ipairs(ns.Crafting and ns.Crafting.order or {}) do
            local catalog = ns.craftCatalogs[profession]
            for _, recipe in ipairs(catalog and catalog.recipes or {}) do
                nameEntry(ns.Compat.SpellIcon(recipe.spell), {method = "craft", spell = recipe.spell,
                    recipe = {inputs = recipe.inputs, raw = recipe.raw, count = recipe.count}})
            end
        end
        for _, family in ipairs(ns.gemFamilies or {}) do
            for member, spell in pairs(family.spells or {}) do
                nameEntry(ns.Compat.SpellIcon(spell), {method = "craft", spell = spell,
                    recipe = {inputs = {{family.raw, 1}}, raw = member, count = 1}})
            end
        end
        for _, use in ipairs(ns.professionUses or {}) do
            nameEntry(ns.Compat.SpellIcon(use.spell), {method = "craft", spell = use.spell, recipe = {inputs = use.inputs}})
        end
    end
    return spellNames[name]
end
function E.ForgetSpells()
    spellNames = nil
end
function E.TradeSkill(index, repeats)
    if not GetTradeSkillRecipeLink or not GetTradeSkillInfo then return end
    local link = GetTradeSkillRecipeLink(index)
    local spell = link and tonumber(link:match("enchant:(%d+)"))
    local name = GetTradeSkillInfo(index)
    local itemLink = GetTradeSkillItemLink and GetTradeSkillItemLink(index)
    local raw = itemLink and ns.Lot.FromLink(itemLink) or nil
    local inputs = {}
    for r = 1, GetTradeSkillNumReagents and GetTradeSkillNumReagents(index) or 0 do
        local reagentLink = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(index, r)
        local id = reagentLink and ns.Lot.FromLink(reagentLink) or nil
        local _, _, count = GetTradeSkillReagentInfo(index, r)
        if id and count then inputs[#inputs + 1] = {id, count} end
    end
    local made = GetTradeSkillNumMade and GetTradeSkillNumMade(index) or 1
    local spellName = spell and ns.Compat.SpellIcon(spell) or name
    if not spellName then return end
    E.pending = {name = spellName, method = spell and METHOD_SPELLS[spell] or "craft", spell = spell,
        recipe = {inputs = inputs, raw = raw, count = made}, repeats = repeats or 1, at = GetTime()}
end
local function snapshot(kind)
    local counts, watch = {}, {}
    for _, id in ipairs(ns.disenchantMaterials) do watch[id] = true end
    if ns.Prospect and (kind.method == "prospect" or kind.method == "mill") then
        for _, id in ipairs(ns.Prospect.Targets(kind.method)) do watch[id] = true end
    end
    if kind.recipe then
        if kind.recipe.raw then watch[kind.recipe.raw] = true end
        for _, input in ipairs(kind.recipe.inputs or {}) do watch[input[1]] = true end
    end
    if GetItemCount then for id in pairs(watch) do counts[id] = GetItemCount(id, false) or 0 end end
    return {bags = ns.DisenchantLog.BagSnapshot(), counts = counts}
end
local function begin(kind, name, state)
    E.Settle(true)
    local shot = snapshot(kind)
    E.capture = {name = name, method = kind.method, spell = kind.spell, recipe = kind.recipe, bags = shot.bags,
        counts = shot.counts, state = state or "cast", at = GetTime()}
    if state == "done" then E.capture.deadline, E.capture.changed = GetTime() + CAPTURE, GetTime() end
end
function E.Spell(event, unit, spell)
    if unit ~= "player" or not spell then return end
    local c = E.capture
    local pending = E.pending
    local kind = pending and pending.name == spell and pending or E.SpellKind(spell)
    if event == "UNIT_SPELLCAST_SENT" or event == "UNIT_SPELLCAST_START" then
        if c and c.name == spell and c.state == "cast" then return end
        if pending and pending.name ~= spell and GetTime() - pending.at > 2 then E.pending = nil end
        if kind then begin(kind, spell) end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if c and c.name == spell then
            if c.state == "cast" then c.state, c.deadline, c.changed = "done", GetTime() + CAPTURE, GetTime()
            elseif kind then begin(kind, spell, "done") end
        elseif not c and kind and E.after and E.after.name == spell and GetTime() - E.after.at < CAPTURE then
            E.capture = {name = spell, method = kind.method, spell = kind.spell, recipe = kind.recipe, bags = E.after.bags,
                counts = E.after.counts, state = "done", at = GetTime(), deadline = GetTime() + CAPTURE, changed = GetTime()}
        end
    elseif c and c.state == "cast" and c.name == spell then
        E.capture = nil
    end
end
local function ledgerInputs(p, itemID, suffix, count)
    local inputs, left, tracked = {}, count, 0
    for _, chain in ipairs(p.chains) do
        local take = math.min(left, chain.received - chain.processed)
        if chain.itemID == itemID and chain.suffix == suffix and chain.state ~= "lost" and chain.plan ~= "flip" and take > 0 then
            inputs[#inputs + 1] = {chain = chain.id, count = take}
            left, tracked = left - take, tracked + take
        end
    end
    if left > 0 then
        local m = p.materials[itemID]
        tracked = tracked + math.min(left, m and suffix == 0 and m.remaining or 0)
        inputs[#inputs + 1] = {itemID = itemID, count = left}
    end
    return inputs, tracked
end
function E.Record(c, consumed, produced)
    local A = ns.Accounting
    local p = A.Project()
    if c.method == "disenchant" then
        local bought, others, material, chains = nil, {}, {}, disenchantable()
        for _, id in ipairs(ns.disenchantMaterials) do material[id] = true end
        for _, item in ipairs(consumed) do
            if item.count == 1 and not material[item.itemID] then
                if chains[item.key] then bought = bought or item
                elseif ns.DisenchantLog.Plausible(item.itemID, item.link) then others[#others + 1] = item end
            end
        end
        local outputs = {}
        for _, out in ipairs(produced) do if material[out.itemID] then outputs[#outputs + 1] = out end end
        local target = bought or (#others == 1 and others[1]) or nil
        if not target or #outputs == 0 then return nil end
        if not bought then
            return ns.DisenchantLog.Record({itemID = target.itemID, suffix = target.suffix, link = target.link,
                outputs = outputs, bought = false}, "cast") ~= nil
        end
        return A.Convert({method = "disenchant", spell = c.spell, inputs = {{chain = chains[target.key][1].id, count = 1}},
            outputs = outputs}, "cast") ~= nil
    end
    if c.method == "prospect" or c.method == "mill" then
        local source
        for _, item in ipairs(consumed) do
            if ns.Prospect.Source(c.method, item.itemID) and item.count == ns.Prospect.OPERATION then source = source or item end
        end
        local outputs = {}
        for _, out in ipairs(produced) do if ns.Prospect.IsTarget(c.method, out.itemID) then outputs[#outputs + 1] = out end end
        if not source or #outputs == 0 then return nil end
        local inputs, tracked = ledgerInputs(p, source.itemID, source.suffix, ns.Prospect.OPERATION)
        if tracked == 0 then return false end
        return A.Convert({method = c.method, spell = c.spell, inputs = inputs, outputs = outputs}, "cast") ~= nil
    end
    local recipe = c.recipe
    if not recipe then return false end
    local delta = {}
    for _, item in ipairs(consumed) do delta[item.itemID] = (delta[item.itemID] or 0) + item.count end
    for id, before in pairs(c.counts) do
        local gone = before - (GetItemCount(id, false) or 0)
        if gone > 0 and not delta[id] then delta[id] = gone end
    end
    local inputs, tracked = {}, 0
    for _, input in ipairs(recipe.inputs or {}) do
        if (delta[input[1]] or 0) < input[2] then return nil end
        local list, found = ledgerInputs(p, input[1], 0, input[2])
        for _, entry in ipairs(list) do inputs[#inputs + 1] = entry end
        tracked = tracked + found
    end
    if tracked == 0 then return false end
    if #produced == 0 then
        if recipe.raw then return nil end
        for _, input in ipairs(inputs) do
            local m = input.itemID and p.materials[input.itemID]
            if m and m.remaining > 0 then A.Use(input.itemID, math.min(input.count, m.remaining), "cast") end
        end
        return true
    end
    return A.Convert({method = "craft", spell = c.spell, inputs = inputs, outputs = produced}, "cast") ~= nil
end
function E.Settle(force)
    local c = E.capture
    if not c or c.state ~= "done" then return false end
    local now = GetTime()
    if now > c.deadline then E.capture = nil; return false end
    if not force and (now - c.changed < QUIET or c.checked == c.changed) then return false end
    c.checked = c.changed
    local after = c.bags and ns.DisenchantLog.BagSnapshot()
    if not after then
        if force then E.capture = nil end
        return false
    end
    local consumed, produced, seen = {}, {}, {}
    for key, item in pairs(c.bags) do
        local left = after[key] and after[key].count or 0
        if item.count > left then
            consumed[#consumed + 1] = {key = key, itemID = item.itemID, suffix = item.suffix, link = item.link, count = item.count - left}
        end
    end
    for id, before in pairs(c.counts) do
        local delta = (GetItemCount(id, false) or 0) - before
        if delta > 0 then produced[#produced + 1] = {itemID = id, count = delta} end
        seen[id] = true
    end
    for key, item in pairs(after) do
        local before = c.bags[key] and c.bags[key].count or 0
        if item.count > before and not seen[item.itemID] then produced[#produced + 1] = {itemID = item.itemID, count = item.count - before} end
    end
    table.sort(produced, function(a, b) return a.itemID < b.itemID end)
    local done = E.Record(c, consumed, produced)
    if done == nil then
        if force then E.capture = nil end
        return false
    end
    local counts = {}
    for id in pairs(c.counts) do counts[id] = GetItemCount(id, false) or 0 end
    E.capture, E.after = nil, {bags = after, counts = counts, at = now, name = c.name}
    return done
end
function E.BagChanged()
    if E.capture and E.capture.state == "done" then E.capture.changed = GetTime() end
    E.dirty = true
end
function E.Update()
    if E.dirty then
        E.dirty = false; E.CheckMail()
        if next(E.gifts) and ns.CollectUI then ns.CollectUI.Refresh() end
    end
    if E.capture then E.Settle() end
end
function E.MailShow()
    E.mailOpen, E.mailCounts, E.arriving = true, {}, {}
    for key, info in pairs(awaited()) do E.mailCounts[key] = E.BagCount(info.itemID, info.suffix) end
end
function E.Install()
    E.hooked = E.hooked or {}
    local function hook(name, fn)
        if type(_G[name]) == "function" and not E.hooked[name] then
            E.hooked[name] = true
            hooksecurefunc(name, fn)
        end
    end
    hook("PlaceAuctionBid", function(kind, index, amount) E.Bid(kind, index, amount) end)
    hook("StartAuction", function(...) E.Posting(...) end)
    hook("CancelAuction", function(index) E.Cancelling(index) end)
    hook("TakeInboxMoney", function(index) E.Taking(index) end)
    hook("AutoLootMailItem", function(index) E.Taking(index); E.Gift(index) end)
    hook("TakeInboxItem", function(index, attach) E.Gift(index, attach) end)
    hook("DoTradeSkill", function(index, repeats) E.TradeSkill(index, repeats) end)
end
E.Install()
local frame = ns.NewFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "BAG_UPDATE", "CHAT_MSG_SYSTEM",
    "UI_ERROR_MESSAGE", "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED", "AUCTION_MULTISELL_UPDATE", "AUCTION_MULTISELL_FAILURE"}) do ns.Listen(frame, event) end
frame:SetScript("OnEvent", function(_, event, first, second)
    if event == "PLAYER_LOGIN" then E.Install()
    elseif event == "MAIL_SHOW" then E.MailShow()
    elseif event == "MAIL_CLOSED" then E.mailOpen, E.mailCounts, E.arriving, E.taken = false, nil, {}, {}
    elseif event == "MAIL_INBOX_UPDATE" then E.InboxChanged()
    elseif event == "BAG_UPDATE" then E.BagChanged()
    elseif event == "CHAT_MSG_SYSTEM" or event == "UI_ERROR_MESSAGE" then E.Message(event, first)
    elseif event == "AUCTION_MULTISELL_UPDATE" then
        local posting = E.posting
        if posting then
            posting.created = first or posting.created
            if second and first and first >= second then
                E.posting = nil; posting.stacks = first; ns.Accounting.Post(posting)
            end
        end
    elseif event == "AUCTION_MULTISELL_FAILURE" then
        local posting = E.posting
        E.posting = nil
        if posting and (posting.created or 0) > 0 then posting.stacks = posting.created; ns.Accounting.Post(posting) end
    else E.Spell(event, first, second) end
end)
frame:SetScript("OnUpdate", function() E.Update() end)
