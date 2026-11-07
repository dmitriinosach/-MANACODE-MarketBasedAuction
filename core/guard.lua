local ADDON, ns = ...
local G = {}
ns.Guard = G
G.VERSION = 1
G.MIN_WEIGHT = 20
G.APPEND_ONLY = {"ledger", "disenchantLog", "recipeBook"}
G.MAX_WEIGHT = 1000000
G.state = "ok"
G.sections = nil
G.checked = false
G.message = nil
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
local function vault()
    local v = AuctionScanVault
    if type(v) ~= "table" or type(v.born) ~= "string" or type(v.copy) ~= "table" then return nil end
    return v
end
local function vaultWeight(v)
    local total = 0
    for _, w in pairs(type(v.weights) == "table" and v.weights or {}) do total = total + (tonumber(w) or 0) end
    return total
end
local function character()
    return (GetRealmName() or "") .. "|" .. (UnitFactionGroup("player") or "") .. "|" .. (UnitName("player") or "")
end
function G.Check()
    local db, v = ns.Store.DB(), vault()
    G.state, G.sections, G.checked = "ok", nil, true
    if not v then return G.state end
    if v.born ~= db.born then
        if vaultWeight(v) > 0 or (tonumber(v.scans) or 0) > 0 then G.state = "lost" end
        return G.state
    end
    local shrunk = {}
    for _, name in ipairs(G.APPEND_ONLY) do
        local before = tonumber(v.weights and v.weights[name]) or 0
        if before >= G.MIN_WEIGHT and G.Weight(db[name]) * 2 < before then shrunk[#shrunk + 1] = name end
    end
    if #shrunk > 0 then G.state, G.sections = "shrunk", shrunk end
    return G.state
end
local function sectionNames(names)
    local parts = {}
    for _, name in ipairs(names) do parts[#parts + 1] = ns.T("guardSection_" .. name) end
    return table.concat(parts, ", ")
end
local function when()
    local v = vault()
    return v and date("%d.%m %H:%M", v.at or 0)
end
local function red(text)
    local K = ns.TradeKit
    return K and K.Colored and K.Colored(text, "negative") or text
end
function G.Alarm()
    local title, copy = G.Warning()
    if not title then return end
    ns.chat(red(title))
    ns.chat(copy)
    ns.chat(ns.T("guardFile"))
    ns.chat(ns.T("guardChoose"))
end
function G.Notice()
    if G.state == "lost" then return red(ns.T("guardNoticeLost", when() or "?")) end
    if G.state == "shrunk" then return red(ns.T("guardNoticeShrunk", when() or "?")) end
    if ns.Store.overKeys then
        return red(ns.T("guardNoticeKeys", ns.Store.overKeys, ns.Store.LUA_KEYS))
    end
    return nil
end
function G.Restore()
    local v = vault()
    if G.state == "ok" or not v then G.message = ns.T("guardNothing"); return false end
    local db = ns.Store.DB()
    local names = G.state == "shrunk" and G.sections or ns.Store.VALUABLE
    local replaced, restored = {}, {}
    for _, name in ipairs(names) do
        if v.copy[name] ~= nil then
            replaced[name] = db[name]
            db[name] = v.copy[name]
            restored[#restored + 1] = name
        end
    end
    db.replaced = {at = time(), sections = replaced}
    if G.state == "lost" then db.born = v.born end
    ns.Store.Log("guard restore " .. G.state .. " from=" .. tostring(v.at) .. " sections=" .. table.concat(restored, ","))
    G.state, G.sections = "ok", nil
    if ns.Accounting and ns.Accounting.Changed then ns.Accounting.Changed() end
    G.message = ns.T("guardRestored", when(), sectionNames(restored))
    return true
end
function G.Forget()
    if G.state == "ok" then G.message = ns.T("guardNothing"); return false end
    ns.Store.Log("guard forget " .. G.state)
    G.state, G.sections = "ok", nil
    G.message = ns.T("guardForgot")
    return true
end
function G.Save()
    if not G.checked or G.state ~= "ok" then return nil end
    local db = ns.Store.DB()
    local copy, weights = {}, {}
    for _, name in ipairs(ns.Store.VALUABLE) do
        copy[name] = db[name]
        weights[name] = G.Weight(db[name])
    end
    AuctionScanVault = {v = G.VERSION, born = db.born, at = time(), character = character(),
        scans = #db.scans, rawBytes = ns.Store.Usage(), weights = weights, copy = copy}
    return AuctionScanVault
end
function G.Status()
    local keys, exact = ns.Store.Keys(true)
    local status = {usage = ns.Store.Usage(), keys = keys, exact = exact and true or false, sharedPoints = 0, copyWeight = 0}
    if ns.Shared then status.shared, status.sharedPoints = ns.Shared.Status() end
    local v = vault()
    if v then status.copyAt, status.copyWeight = when(), vaultWeight(v) end
    return status
end
function G.Warning()
    local v = vault()
    if G.state == "ok" or not v then return nil end
    local who = tostring(v.character or ""):match("([^|]*)$") or ""
    if G.state == "lost" then
        return ns.T("guardLost"), ns.T("guardLostCopy", when(), who, (tonumber(v.rawBytes) or 0) / 1048576, tonumber(v.scans) or 0)
    end
    return ns.T("guardShrunk", sectionNames(G.sections or {})), ns.T("guardShrunkCopy", when(), who)
end
local events = ns.NewFrame("Frame")
ns.Listen(events, "ADDON_LOADED")
ns.Listen(events, "PLAYER_LOGIN")
ns.Listen(events, "PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        G.Check()
    elseif event == "PLAYER_LOGIN" then
        G.Alarm()
    elseif event == "PLAYER_LOGOUT" then
        G.Save()
    end
end)
