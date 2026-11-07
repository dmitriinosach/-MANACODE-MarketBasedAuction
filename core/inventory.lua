local _, ns = ...
local I = {}
ns.Inventory = I
I.CHARACTERS = 40
I.STALE = 180 * 86400
I.ATTACHMENTS = 12
I.BAGS = {0, 1, 2, 3, 4}
I.BANK = {-1, 5, 6, 7, 8, 9, 10, 11}
I.TOOLTIP_ADDONS = {"Bagnon_Tooltips", "BagSync", "Altoholic", "Possessions"}
I.STALE_HINT = 30 * 86400
local state = {ready = false, dirty = true, atBank = false, atMail = false, parsed = {}}
I.state = state
local function characters(faction, create)
    local realm = GetRealmName() or ""
    faction = faction or UnitFactionGroup("player") or ""
    if realm == "" or faction == "" then return nil end
    local db = ns.Store.DB()
    if not db.stock and not create then return nil end
    db.stock = db.stock or {}
    local key = realm .. "|" .. faction
    if not db.stock[key] and create then db.stock[key] = {} end
    return db.stock[key]
end
local function trim(list, keep)
    local now, names = time(), {}
    for name, rec in pairs(list) do
        if name ~= keep and now - (rec.seen or 0) > I.STALE then list[name] = nil
        elseif name ~= keep then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return (list[a].seen or 0) > (list[b].seen or 0) end)
    for i = I.CHARACTERS, #names do list[names[i]] = nil end
end
local function record()
    local name = UnitName("player")
    local list = name and characters(nil, true)
    if not list then return nil end
    local rec = list[name]
    if not rec then rec = {}; list[name] = rec end
    rec.seen = time()
    rec.guid = UnitGUID and UnitGUID("player") or rec.guid
    return rec
end
local function realmLists()
    local realm, lists = (GetRealmName() or "") .. "|", {}
    for key, list in pairs(ns.Store.DB().stock or {}) do
        if type(list) == "table" and key:sub(1, #realm) == realm then lists[#lists + 1] = list end
    end
    return lists
end
local function bagnonRealm()
    if type(BagnonForeverDB) ~= "table" then return nil end
    local realm = BagnonForeverDB[GetRealmName() or ""]
    return type(realm) == "table" and realm or nil
end
function I.Characters()
    local rows, byName, me = {}, {}, UnitName("player")
    local function row(name)
        if not byName[name] then
            byName[name] = {name = name, current = name == me, bagnon = false, own = false}
            rows[#rows + 1] = byName[name]
        end
        return byName[name]
    end
    for _, list in ipairs(realmLists()) do
        for name, rec in pairs(list) do
            if type(name) == "string" and type(rec) == "table" then
                local entry = row(name)
                entry.own, entry.seen = true, math.max(entry.seen or 0, rec.seen or 0)
            end
        end
    end
    for name, data in pairs(bagnonRealm() or {}) do
        if type(name) == "string" and type(data) == "table" then row(name).bagnon = true end
    end
    table.sort(rows, function(a, b)
        if a.current ~= b.current then return a.current end
        return a.name < b.name
    end)
    return rows
end
function I.Stale(row)
    if row.current then return false end
    local now = time()
    if row.seen then return now - row.seen > I.STALE_HINT end
    local since = ns.Store.DB().stockSince
    return since ~= nil and now - since > I.STALE_HINT
end
function I.Forget(name)
    if type(name) ~= "string" or name == UnitName("player") then return false end
    for _, list in ipairs(realmLists()) do list[name] = nil end
    local bagnon = bagnonRealm()
    if bagnon and bagnon[name] and type(BagnonDB) == "table" and type(BagnonDB.RemovePlayer) == "function" then
        BagnonDB:RemovePlayer(name)
    end
    state.parsed[name] = nil
    return true
end
function I.Renamed()
    local me, guid = UnitName("player"), UnitGUID and UnitGUID("player")
    if not me or not guid then return nil end
    local old
    for _, list in ipairs(realmLists()) do
        for name, rec in pairs(list) do
            if name ~= me and type(rec) == "table" and rec.guid == guid then old = name end
        end
    end
    if old then I.Forget(old) end
    return old
end
function I.Source()
    return bagnonRealm() and "bagnon" or "own"
end
function I.TooltipElsewhere()
    if not IsAddOnLoaded then return false end
    for _, name in ipairs(I.TOOLTIP_ADDONS) do
        if IsAddOnLoaded(name) then return true end
    end
    return false
end
function I.ReadBagnon(data)
    local bags, bank = {}, {}
    for key, value in pairs(data) do
        if type(key) == "number" and type(value) == "string" then
            local index = math.abs(key)
            local bag, slot = math.floor(index / 100), index % 100
            local size = data[key > 0 and bag * 100 or -(bag * 100)]
            size = type(size) == "string" and tonumber(size:match("^(%d+)")) or nil
            if slot > 0 and (not size or slot <= size) then
                local into = bags
                if (key > 0 and bag > 4) or (key < 0 and bag == 1) then into = bank end
                local id = tonumber(value:match("^item:(%d+)") or value:match("^(%d+)"))
                if id then into[id] = (into[id] or 0) + (tonumber(value:match(",(%d+)$")) or 1) end
            end
        end
    end
    return bags, bank
end
local function parsed(name, data)
    local cached = state.parsed[name]
    if cached and cached.data == data then return cached end
    local bags, bank = I.ReadBagnon(data)
    cached = {data = data, bags = bags, bank = bank}
    state.parsed[name] = cached
    return cached
end
local function readContainers(list)
    local counts = {}
    if not GetContainerItemLink then return counts end
    for _, bag in ipairs(list) do
        for slot = 1, ns.Compat.BagSlots(bag) or 0 do
            local id = ns.Lot.FromLink(GetContainerItemLink(bag, slot))
            if id then
                local _, count = ns.Compat.BagItemIcon(bag, slot)
                counts[id] = (counts[id] or 0) + (count or 1)
            end
        end
    end
    return counts
end
local function readMail()
    local counts = {}
    if not GetInboxNumItems then return counts end
    for i = 1, GetInboxNumItems() or 0 do
        local cod = select(6, GetInboxHeaderInfo(i))
        if (cod or 0) == 0 then
            for a = 1, I.ATTACHMENTS do
                local id = ns.Lot.FromLink(GetInboxItemLink(i, a))
                if id then
                    local _, _, count = GetInboxItem(i, a)
                    counts[id] = (counts[id] or 0) + (count or 1)
                end
            end
        end
    end
    return counts
end
local function flush()
    if not state.ready or not state.dirty then return end
    state.dirty = false
    if I.Source() ~= "own" then return end
    local rec = record()
    if rec then rec.bags = readContainers(I.BAGS) end
end
local function refreshBank()
    if not state.ready or I.Source() ~= "own" then return end
    local rec = record()
    if rec then rec.bank, rec.bankAt = readContainers(I.BANK), time() end
end
local function refreshMail()
    if not state.ready then return end
    local rec = record()
    if rec then rec.mail, rec.mailAt = readMail(), time() end
end
local function foreign(name, own)
    if own[name] then return false end
    local other = characters(UnitFactionGroup("player") == "Alliance" and "Horde" or "Alliance", false)
    return other ~= nil and other[name] ~= nil
end
function I.Holdings(id)
    local result = {}
    if not state.ready or type(id) ~= "number" then return result end
    flush()
    local me = UnitName("player")
    local own = characters(nil, false) or {}
    local bagnon = bagnonRealm()
    local done = {}
    local function add(name, bags, bank, rec)
        done[name] = true
        local h = {name = name, current = name == me, bags = bags and bags[id] or 0, bank = bank and bank[id] or 0,
            mail = rec and rec.mail and rec.mail[id] or 0, bankAt = rec and rec.bankAt, mailAt = rec and rec.mailAt}
        if h.bags + h.bank + h.mail > 0 then result[#result + 1] = h end
    end
    if bagnon then
        for name, data in pairs(bagnon) do
            if type(name) == "string" and type(data) == "table" and not foreign(name, own) then
                local p = parsed(name, data)
                add(name, p.bags, p.bank, own[name])
            end
        end
    end
    for name, rec in pairs(own) do
        if not done[name] then add(name, not bagnon and rec.bags or nil, not bagnon and rec.bank or nil, rec) end
    end
    table.sort(result, function(a, b)
        if a.current ~= b.current then return a.current end
        return a.name < b.name
    end)
    return result
end
function I.Total(id)
    local all, alts = 0, 0
    for _, h in ipairs(I.Holdings(id)) do
        local n = h.bags + h.bank + h.mail
        all = all + n
        if not h.current then alts = alts + n end
    end
    return all, alts
end
function I.Stock(id)
    local here = math.max(0, GetItemCount and GetItemCount(id, true) or 0)
    local alts, others = 0, {}
    for _, h in ipairs(I.Holdings(id)) do
        if h.current then here = here + h.mail
        else
            others[#others + 1] = h
            alts = alts + h.bags + h.bank + h.mail
        end
    end
    return here, alts, others
end
function I.OnEvent(event, bag)
    if event == "PLAYER_LOGIN" then
        state.ready, state.dirty = true, true
        local list = characters(nil, true)
        if list then trim(list, UnitName("player") or "") end
        local db = ns.Store.DB()
        if list and not db.stockSince then db.stockSince = time() end
        record()
        local old = I.Renamed()
        if old then ns.say(ns.T("invRenamed", old, UnitName("player") or "")) end
        return
    end
    if not state.ready then return end
    if event == "PLAYER_LOGOUT" then flush()
    elseif event == "BAG_UPDATE" then
        state.parsed[UnitName("player") or ""] = nil
        if type(bag) == "number" and bag >= 0 and bag <= 4 then state.dirty = true
        elseif state.atBank then refreshBank() end
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        state.parsed[UnitName("player") or ""] = nil
        if state.atBank then refreshBank() end
    elseif event == "BANKFRAME_OPENED" then
        state.atBank = true
        state.parsed[UnitName("player") or ""] = nil
        refreshBank()
    elseif event == "BANKFRAME_CLOSED" then state.atBank = false
    elseif event == "MAIL_SHOW" then state.atMail = true
    elseif event == "MAIL_INBOX_UPDATE" then
        if state.atMail then refreshMail() end
    elseif event == "MAIL_CLOSED" then state.atMail = false
    end
end
local events = ns.NewFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_LOGOUT", "BAG_UPDATE", "PLAYERBANKSLOTS_CHANGED", "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED", "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED"}) do ns.Listen(events, event) end
events:SetScript("OnEvent", function(_, event, bag) I.OnEvent(event, bag) end)
