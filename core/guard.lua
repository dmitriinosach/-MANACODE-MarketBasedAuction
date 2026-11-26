local ADDON, ns = ...
local G = {VERSION = 1, MAX_WEIGHT = 1000000, state = "ok", checked = false}
ns.Guard = G
G.APPEND_ONLY = {"ledger", "disenchantLog", "recipeBook"}
G.SETTINGS = {auctionFee = true, mailPanel = true, auctionWindow = true, view = true, disenchantUI = true,
    prospectUI = true, bargainUI = true, listFilters = true, levelingRate = true, levelingResale = true, buyUI = true,
    ledgerMode = true}
G.DISMISSED = 8
function G.Weight(value)
    if type(value) ~= "table" then return value == nil and 0 or 1 end
    local count, seen = 0, {}
    local function walk(t)
        for _, v in pairs(t) do
            if count >= G.MAX_WEIGHT then return end
            if type(v) == "table" then
                if not seen[v] then seen[v] = true; walk(v) end
            else
                count = count + 1
            end
        end
    end
    seen[value] = true
    walk(value)
    return count
end
local function clone(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = clone(child) end
    return out
end
local function count(value)
    local n = 0
    for _ in pairs(type(value) == "table" and value or {}) do n = n + 1 end
    return n
end
local function vault()
    local v = AuctionScanVault
    if type(v) ~= "table" or type(v.born) ~= "string" or type(v.copy) ~= "table" then return nil end
    return v
end
local function vaultWeight(v)
    local total = 0
    for _, weight in pairs(type(v.weights) == "table" and v.weights or {}) do total = total + (tonumber(weight) or 0) end
    return total
end
local function birth(born)
    local hex = type(born) == "string" and born:match("^([%da-fA-F]+)%-")
    return hex and tonumber(hex, 16) or nil
end
local function older(db, copy)
    local a, b = birth(db.born), birth(copy.born)
    if a and b and a ~= b then return b < a end
    return db.born == ns.Store.createdBorn
end
local function richer(db, v)
    for _, name in ipairs(ns.Store.VALUABLE) do
        local copy = v.copy[name]
        if not G.SETTINGS[name] and type(copy) == "table" and G.Weight(copy) > G.Weight(db[name]) then return true end
    end
    return false
end
local function dismissed(db, born)
    return type(db.guardDismissed) == "table" and db.guardDismissed[born] ~= nil
end
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function books(current, copy, ledger)
    local result, changed = clone(current or {}), false
    local target, incoming = result, copy
    if ledger then result.characters = result.characters or {}; target, incoming = result.characters, copy.characters or {} end
    for key, book in pairs(incoming) do
        if type(book) == "table" then
            local present = target[key]
            local field = ledger and "events" or "known"
            if type(present) ~= "table" or count(book[field]) > count(present[field]) then
                target[key], changed = clone(book), true
            end
        end
    end
    if ledger and changed then
        result.version = result.version or copy.version
        result.seq = math.max(tonumber(result.seq) or 0, tonumber(copy.seq) or 0)
    end
    return result, changed
end
local function journal(current, copy)
    local result, ids, changed = clone(current or copy), {}, false
    result.entries = result.entries or {}
    for _, entry in ipairs(result.entries) do if entry.id then ids[entry.id] = true end end
    for _, entry in ipairs(copy.entries or {}) do
        local exists = entry.id and ids[entry.id] or false
        if not entry.id then
            for _, present in ipairs(result.entries) do if equal(entry, present) then exists = true; break end end
        end
        if not exists then
            result.entries[#result.entries + 1], changed = clone(entry), true
            if entry.id then ids[entry.id] = true end
        end
    end
    if not current and #result.entries > 0 then changed = true end
    if changed then
        result.seq = math.max(tonumber(result.seq) or 0, tonumber(copy.seq) or 0)
        table.sort(result.entries, function(a, b)
            if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) < (b.at or 0) end
            return tostring(a.id or "") < tostring(b.id or "")
        end)
    end
    return result, changed
end
local function character()
    return (GetRealmName() or "") .. "|" .. (UnitFactionGroup("player") or "") .. "|" .. (UnitName("player") or "")
end
local function when()
    local v = vault()
    return v and date("%d.%m %H:%M", v.at or 0)
end
function G.Merge(lost)
    local db, v = ns.Store.DB(), vault()
    if not v then return false end
    local replaced, names, append = {}, {}, {}
    for _, name in ipairs(G.APPEND_ONLY) do append[name] = true end
    for _, name in ipairs(ns.Store.VALUABLE) do
        local value, changed = nil, false
        local copy = v.copy[name]
        if type(copy) == "table" and append[name] then
            if name == "disenchantLog" then value, changed = journal(db[name], copy)
            else value, changed = books(db[name], copy, name == "ledger") end
        elseif lost and copy ~= nil and not equal(db[name], copy) then
            value, changed = clone(copy), true
        end
        if changed then
            replaced[name], db[name] = db[name], value
            names[#names + 1] = name
        end
    end
    if lost then db.born = v.born end
    if #names > 0 then
        db.replaced = {at = time(), sections = replaced}
        ns.Store.Log("guard merge from=" .. tostring(v.at) .. " character=" .. tostring(v.character or "") .. " sections=" .. table.concat(names, ","))
    end
    return lost or #names > 0
end
function G.Check()
    local db, v = ns.Store.DB(), vault()
    G.state, G.checked, G.pending = "ok", true, nil
    if not v then return G.state end
    if v.born ~= db.born then
        if older(db, v) and not dismissed(db, v.born) and richer(db, v) then G.state, G.pending = "lost", true end
    else G.Merge(false) end
    return G.state
end
function G.Announce()
    local pending = G.pending
    G.pending = nil
    if not pending then return end
    ns.chat(ns.T("guardNoticeLost", when() or "?"))
end
function G.Restore()
    if G.state ~= "lost" then return false end
    if not G.Merge(true) then return false end
    G.state, G.pending = "ok", nil
    if ns.Accounting and ns.Accounting.Changed then ns.Accounting.Changed() end
    return true
end
function G.Forget()
    if G.state ~= "lost" then return false end
    local db, v = ns.Store.DB(), vault()
    if v then
        local list = type(db.guardDismissed) == "table" and db.guardDismissed or {}
        list[v.born] = time()
        local count, oldest, oldestAt = 0, nil, math.huge
        for born, at in pairs(list) do
            count = count + 1
            if at < oldestAt then oldest, oldestAt = born, at end
        end
        if count > G.DISMISSED then list[oldest] = nil end
        db.guardDismissed = list
    end
    ns.Store.Log("guard keep database born=" .. tostring(db.born))
    G.state, G.pending = "ok", nil
    G.Save()
    return true
end
function G.Notice()
    if G.state == "lost" then return ns.T("guardNoticeLost", when() or "?") end
    if ns.Store.overKeys then return ns.T("guardNoticeKeys", ns.Store.overKeys, ns.Store.LUA_KEYS) end
end
function G.Save()
    if not G.checked or G.state ~= "ok" then return nil end
    local db, copy, weights = ns.Store.DB(), {}, {}
    for _, name in ipairs(ns.Store.VALUABLE) do copy[name], weights[name] = db[name], G.Weight(db[name]) end
    AuctionScanVault = {v = G.VERSION, born = db.born, at = time(), character = character(),
        scans = #db.scans, rawBytes = ns.Store.Usage(), weights = weights, copy = copy}
    return AuctionScanVault
end
function G.Status()
    local keys, exact = ns.Store.Keys(true)
    local status = {usage = ns.Store.Usage(), keys = keys, exact = exact and true or false, copyWeight = 0}
    local v = vault()
    if v then status.copyAt, status.copyWeight = when(), vaultWeight(v) end
    return status
end
local events = ns.NewFrame("Frame")
ns.Listen(events, "ADDON_LOADED")
ns.Listen(events, "PLAYER_LOGIN")
ns.Listen(events, "PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then G.Check()
    elseif event == "PLAYER_LOGIN" then G.Announce()
    elseif event == "PLAYER_LOGOUT" then G.Save() end
end)
