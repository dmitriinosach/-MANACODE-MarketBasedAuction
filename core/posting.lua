local _, ns = ...
local P = {listeners = {}, drafts = {}}
ns.Posting = P
P.HOURS = {12, 24, 48}
P.PENDING = 8
P.MAX_LOTS = 100
P.CLICKS = 10
function P.ItemKey(link)
    local id = ns.Lot.FromLink(link)
    if not id then return nil end
    local text = link:match("item:([%d:%-]+)")
    local fields, changed = {}, false
    for value in (text .. ":"):gmatch("(.-):") do
        if #fields >= 8 then break end
        fields[#fields + 1] = tonumber(value) or 0
        if #fields >= 2 and #fields <= 7 and fields[#fields] ~= 0 then changed = true end
    end
    while #fields < 8 do fields[#fields + 1] = 0 end
    return changed and ("item:" .. table.concat(fields, ":")) or id
end
function P.Draft(id, link)
    local key = P.ItemKey(link) or id
    local draft = P.drafts[key]
    if not draft then
        draft = {mode = "under", hours = 24}
        P.drafts[key] = draft
    end
    return draft
end
function P.State(id, fee, link)
    local d = P.Draft(id, link)
    return {fee = fee, mode = d.mode, price = d.price, size = d.size, lots = d.lots, hours = d.hours,
        have = P.Have(id, link), link = link}
end
function P.Bags()
    local items = {}
    if not GetContainerItemLink then return items end
    for bag = 0, 4 do
        for slot = 1, ns.Compat.BagSlots(bag) or 0 do
            local link = GetContainerItemLink(bag, slot)
            local id = ns.Lot.FromLink(link)
            if id and ns.Compat.CanAuction(bag, slot) then
                local _, count, locked = ns.Compat.BagItemIcon(bag, slot)
                count = count or 1
                local entry = items[id] or {count = 0, slots = {}}
                items[id] = entry
                entry.count = entry.count + count
                entry.slots[#entry.slots + 1] = {bag = bag, slot = slot, count = count, locked = locked and true or false,
                    link = link, key = P.ItemKey(link)}
            end
        end
    end
    return items
end
function P.SelectedBag(id, link)
    local entry, selected = P.Bags()[id], {count = 0, slots = {}, id = id, link = link}
    local key = P.ItemKey(link) or id
    for _, slot in ipairs(entry and entry.slots or {}) do
        if slot.key == key then
            selected.count = selected.count + slot.count
            selected.slots[#selected.slots + 1] = slot
        end
    end
    return selected
end
function P.BagVariants()
    local variants = {}
    for id, entry in pairs(P.Bags()) do
        for _, slot in ipairs(entry.slots) do
            local variant = variants[slot.key] or {count = 0, slots = {}, id = id, link = slot.link}
            variants[slot.key] = variant
            variant.count = variant.count + slot.count
            variant.slots[#variant.slots + 1] = slot
        end
    end
    return variants
end
function P.Have(id, link)
    return P.SelectedBag(id, link).count
end
function P.StackLimit(id)
    local limit = select(8, ns.Compat.ItemInfo(id))
    return type(limit) == "number" and limit > 0 and limit or 1
end
function P.Wall(id)
    local depth = ns.Markets.Depth(id)
    local me = UnitName and UnitName("player")
    local q = ns.Markets.Quote(id, true)
    local wall = {levels = {}, units = 0, lots = 0, partial = depth.partial, at = q and q.at}
    for _, level in ipairs(depth.levels) do
        local ownUnits, ownLots = 0, 0
        for _, seller in ipairs(level.sellers) do
            if seller.owner == me then ownUnits, ownLots = ownUnits + seller.units, ownLots + seller.lots end
        end
        local units, lots = level.units - ownUnits, level.lots - ownLots
        if units > 0 then
            wall.levels[#wall.levels + 1] = {price = level.price, units = units, lots = lots, ownUnits = ownUnits}
            wall.units, wall.lots = wall.units + units, wall.lots + lots
        end
    end
    wall.lowest = wall.levels[1] and wall.levels[1].price
    return wall
end
function P.Ahead(wall, price)
    local lots, units, same = 0, 0, 0
    for _, level in ipairs(wall.levels) do
        if level.price < price then lots, units = lots + level.lots, units + level.units
        elseif level.price == price then same = same + level.units end
    end
    return lots, units, same
end
function P.Cost(id, fee, project)
    local m = (project or ns.Accounting.Project()).materials[id]
    if not m or m.remaining <= 0 or m.unknownCost then return nil, nil end
    local cost = m.cost / m.remaining
    return cost, math.ceil(cost / (1 - fee))
end
function P.Suggest(wall, mode, floor, market)
    local target
    if wall.lowest then target = mode == "near" and wall.lowest or math.max(1, wall.lowest - 1)
    elseif market then target = math.max(1, math.floor(market)) end
    if not target then return floor, false end
    if floor and target < floor then return floor, true end
    return target, false
end
function P.Size(id, have)
    local limit = math.max(1, math.min(P.StackLimit(id), have))
    local stacks = ns.Recycle.Stacks(id)
    local premium, popular
    for _, stack in ipairs(stacks) do
        if stack.size <= limit then
            local reachable = math.ceil(have / stack.size) <= P.CLICKS
            if reachable and stack.premium and stack.premium > 0
                and (not premium or stack.premium > premium.premium) then premium = stack end
            if stack.lots >= 2 and (not popular or stack.lots > popular.lots
                or (stack.lots == popular.lots and stack.size > popular.size)) then popular = stack end
        end
    end
    if premium then return premium.size, "premium" end
    if popular then return popular.size, "popular" end
    return limit, "max"
end
function P.Deposit(id, size, hours, fee)
    local vendor = select(11, ns.Compat.ItemInfo(id))
    if type(vendor) ~= "number" then return 100, false end
    local rate = fee == 0.15 and 0.75 or 0.15
    return math.max(100, math.floor(vendor * size * rate * hours / 12)), true
end
function P.Evaluate(id, state)
    local fee = state.fee or 0.05
    local have = state.have or P.Have(id, state.link)
    local variant = type(P.ItemKey(state.link)) == "string"
    local plan = {id = id, link = state.link, variant = variant, have = have, hours = state.hours or 24,
        raised = false, below = false}
    local size, reason = P.Size(id, math.max(1, have))
    plan.reason = state.size and "manual" or reason
    local limit = math.min(P.StackLimit(id), math.max(1, have))
    plan.size = math.max(1, math.min(limit, math.floor(state.size or size)))
    local maxLots = math.max(1, math.min(P.MAX_LOTS, math.floor(have / plan.size)))
    plan.lots = math.max(1, math.min(maxLots, math.floor(state.lots or maxLots)))
    if variant then plan.size, plan.lots = 1, 1 end
    plan.units = math.min(have, plan.size * plan.lots)
    plan.remaining = math.max(0, have - plan.units)
    plan.wall = variant and {levels = {}, units = 0, lots = 0} or P.Wall(id)
    if not variant then plan.cost, plan.floor = P.Cost(id, fee) end
    local q = ns.Markets.Quote(id, true)
    if not variant then
        plan.suggested, plan.raised = P.Suggest(plan.wall, state.mode or "under", plan.floor,
            q and not q.vendor and (q.market or q.price) or nil)
    end
    plan.unit = state.price or plan.suggested
    if plan.unit then plan.unit = math.floor(plan.unit) end
    plan.ahead = {0, 0}
    plan.deposit, plan.depositKnown = P.Deposit(id, plan.size, plan.hours, fee)
    if plan.unit then
        plan.buyout = plan.unit * plan.size
        plan.bid = plan.buyout
        plan.net = math.floor(plan.buyout * (1 - fee))
        plan.total = plan.net * plan.lots
        plan.ahead[1], plan.ahead[2] = P.Ahead(plan.wall, plan.unit)
        if plan.cost then
            plan.profit = plan.net - math.floor(plan.cost * plan.size + 0.5)
            plan.below = plan.unit < plan.floor
        end
    end
    if have < 1 then plan.err = "postNoItem"
    elseif not plan.unit or plan.unit < 1 then plan.err = "postNoPrice"
    elseif plan.buyout > 1000000000 then plan.err = "postPriceHigh" end
    return plan
end
function P.Open()
    return ns.Scan and ns.Scan.state.open and GetAuctionSellItemInfo ~= nil
end
function P.Slot(entry, size)
    local pick, largest
    for _, slot in ipairs(entry.slots) do
        if not slot.locked then
            if slot.count >= size and (not pick or slot.count < pick.count) then pick = slot end
            if not largest or slot.count > largest.count then largest = slot end
        end
    end
    if pick then return pick, size end
    if largest then return largest, largest.count end
end
function P.Release()
    if GetAuctionSellItemInfo and GetAuctionSellItemInfo() and not (CursorHasItem and CursorHasItem()) then
        ClickAuctionSellItemButton()
        ClearCursor()
    end
end
function P.Listen(fn)
    P.listeners[#P.listeners + 1] = fn
end
function P.Changed()
    for _, fn in ipairs(P.listeners) do fn() end
end
function P.CanCheckPending()
    return P.pending ~= nil and P.pending.lots == 1
        and (GetTime() - P.pending.at) >= P.PENDING
end
function P.CheckPending()
    if not P.CanCheckPending() then return false end
    local pending = P.pending
    P.pending = nil
    P.last = {id = pending.id, link = pending.link, size = pending.size, buyout = pending.buyout, uncertain = true}
    if GetAuctionSellItemInfo and GetAuctionSellItemInfo() == ns.Compat.ItemInfo(pending.link or pending.id) then P.Release() end
    P.Changed()
    return true
end
function P.Post(plan)
    if not P.Open() then return false, "postNoAuction" end
    local now = GetTime and GetTime() or 0
    if P.pending then return false, "postPending" end
    if plan.err then return false, plan.err end
    if CursorHasItem and CursorHasItem() then return false, "postCursor" end
    if GetAuctionSellItemInfo() then return false, "postSlotBusy" end
    ns.Compat.ResetAuctionItems()
    local entry = P.SelectedBag(plan.id, plan.link)
    local slot = P.Slot(entry or {slots = {}}, plan.size)
    if not slot then return false, "postNoItem" end
    local available = 0
    for _, stack in ipairs(entry.slots) do if not stack.locked then available = available + stack.count end end
    if available < plan.size * plan.lots then return false, "postPickup" end
    local key = P.ItemKey(plan.link) or plan.id
    if P.ItemKey(GetContainerItemLink(slot.bag, slot.slot)) ~= key then return false, "postItemChanged" end
    PickupContainerItem(slot.bag, slot.slot)
    if not (CursorHasItem and CursorHasItem()) then return false, "postPickup" end
    ClickAuctionSellItemButton()
    ClearCursor()
    local name = GetAuctionSellItemInfo()
    if not name or name ~= ns.Compat.ItemInfo(plan.link or plan.id) then
        P.Release()
        return false, "postSlot"
    end
    local size = plan.size
    local buyout = plan.unit * size
    P.last = nil
    P.pending = {id = plan.id, link = plan.link, size = size, lots = plan.lots, created = 0, at = now, buyout = buyout}
    StartAuction(buyout, buyout, plan.hours == 12 and 1 or (plan.hours == 48 and 3 or 2), size, plan.lots)
    return true, nil, size
end
function P.Message(event, text, total)
    if event == "AUCTION_HOUSE_CLOSED" then
        P.pending = nil
    elseif event == "CHAT_MSG_SYSTEM" then
        if text == nil or text ~= ERR_AUCTION_STARTED then return end
        if P.pending and P.pending.lots > 1 then return end
        if P.pending then P.last = {id = P.pending.id, link = P.pending.link, size = P.pending.size, buyout = P.pending.buyout} end
        P.pending = nil
    elseif event == "AUCTION_MULTISELL_UPDATE" then
        if not P.pending then return end
        P.pending.created = text or P.pending.created
        if not total or P.pending.created < total then P.Changed(); return end
        P.last = {id = P.pending.id, link = P.pending.link, size = P.pending.size, lots = P.pending.created, buyout = P.pending.buyout}
        P.pending = nil
    elseif event == "AUCTION_MULTISELL_FAILURE" then
        if not P.pending then return end
        P.last = {id = P.pending.id, link = P.pending.link, size = P.pending.size,
            lots = P.pending.created, failed = true, buyout = P.pending.buyout}
        P.pending = nil
        P.Release()
    elseif event == "UI_ERROR_MESSAGE" then
        if not P.pending then return end
        if P.pending.lots > 1 then
            P.last = {id = P.pending.id, link = P.pending.link, size = P.pending.size,
                lots = P.pending.created, failed = true, buyout = P.pending.buyout}
        end
        P.pending = nil
        P.Release()
    end
    P.Changed()
end
local frame = ns.NewFrame("Frame")
for _, event in ipairs({"CHAT_MSG_SYSTEM", "UI_ERROR_MESSAGE", "AUCTION_HOUSE_CLOSED", "BAG_UPDATE",
    "AUCTION_MULTISELL_UPDATE", "AUCTION_MULTISELL_FAILURE"}) do
    ns.Listen(frame, event)
end
frame:SetScript("OnEvent", function(_, event, text, total)
    if event == "BAG_UPDATE" then ns.Compat.ResetAuctionItems(); P.Changed() else P.Message(event, text, total) end
end)
