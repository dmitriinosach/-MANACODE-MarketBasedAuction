local _, ns = ...
local L = {}
ns.DisenchantLog = L
L.VERSION = 1
function L.Root()
    local db = ns.Store.DB()
    local root = db.disenchantLog
    if type(root) ~= "table" then
        root = {v = L.VERSION, seq = 0, entries = {}}
        db.disenchantLog = root
    end
    if type(root.gen) ~= "string" or root.gen == "" then
        root.gen = string.format("%x%04x", time(), math.random(0, 65535))
    end
    root.seq = root.seq or 0
    root.entries = root.entries or {}
    return root
end
local function append(entry)
    local root = L.Root()
    root.seq = root.seq + 1
    entry.id, entry.at = root.gen .. "-" .. root.seq, entry.at or time()
    root.entries[#root.entries + 1] = entry
    return entry.id
end
function L.Describe(itemID, link)
    local info = {}
    local name, _, quality, level, _, className, subName, _, equip = ns.Compat.ItemInfo(link or itemID)
    if not name then return info end
    info.level, info.quality = level, quality
    info.slot = equip ~= "" and equip or nil
    if className and GetAuctionItemClasses then
        local classes = {GetAuctionItemClasses()}
        info.class = className == classes[1] and "weapon" or (className == classes[2] and "armor" or "other")
        local index = info.class == "weapon" and 1 or (info.class == "armor" and 2 or nil)
        if index and subName and GetAuctionItemSubClasses then
            for subIndex, sub in ipairs({GetAuctionItemSubClasses(index)}) do
                if sub == subName then info.subclass = subIndex end
            end
        end
    end
    local model = ns.Disenchant and ns.Disenchant.Candidate(itemID, link)
    if model then info.band = model.band end
    ns.Store.Item(itemID, name, quality)
    return info
end
function L.Plausible(itemID, link)
    local name, _, quality, _, _, _, _, _, equip = ns.Compat.ItemInfo(link or itemID)
    if not name then return true end
    return quality ~= nil and quality >= 2 and quality <= 4 and equip ~= nil and equip ~= ""
end
function L.Record(values, source)
    if type(values.itemID) ~= "number" or type(values.outputs) ~= "table" or #values.outputs == 0 then return nil end
    local info = L.Describe(values.itemID, values.link)
    local outputs = {}
    for _, output in ipairs(values.outputs) do
        outputs[#outputs + 1] = {itemID = output.itemID, count = output.count}
        local name, _, quality = ns.Compat.ItemInfo(output.itemID)
        ns.Store.Item(output.itemID, name, quality)
    end
    return append({kind = "disenchant", source = source or "manual",
        realm = GetRealmName() or "", faction = UnitFactionGroup("player") or "",
        itemID = values.itemID, suffix = values.suffix or 0,
        level = values.level or info.level, quality = values.quality or info.quality,
        class = info.class, subclass = info.subclass, slot = info.slot, band = values.band or info.band,
        outputs = outputs, bought = values.bought == true, chain = values.chain, ledger = values.ledger})
end
function L.Cancel(id)
    local found
    for _, entry in ipairs(L.Root().entries) do
        if entry.kind == "disenchant" and entry.id == id then found = entry end
        if entry.kind == "cancel" and entry.target == id then return nil end
    end
    if not found then return nil end
    return append({kind = "cancel", source = "manual", target = id})
end
function L.CancelLedger(ledger)
    local entries = L.Root().entries
    for index = #entries, 1, -1 do
        local entry = entries[index]
        if entry.kind == "disenchant" and entry.ledger == ledger then return L.Cancel(entry.id) end
    end
end
function L.Cancelled()
    local cancelled = {}
    for _, entry in ipairs(L.Root().entries) do
        if entry.kind == "cancel" then cancelled[entry.target] = entry.id end
    end
    return cancelled
end
function L.BagSnapshot()
    if not GetContainerNumSlots or not GetContainerItemLink or not GetContainerItemInfo then return nil end
    local items = {}
    for bag = 0, 4 do
        for slot = 1, ns.Compat.BagSlots(bag) or 0 do
            local link = GetContainerItemLink(bag, slot)
            local id, suffix = ns.Lot.FromLink(link)
            if id then
                local quantity = select(2, ns.Compat.BagItemIcon(bag, slot))
                if not quantity then return nil end
                local key = id .. ":" .. suffix
                local item = items[key]
                if not item then
                    item = {itemID = id, suffix = suffix, link = link, count = 0}
                    items[key] = item
                end
                item.count = item.count + quantity
            end
        end
    end
    return items
end
