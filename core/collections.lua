local _, ns = ...
local C = {}
ns.Collections = C
local function saved()
    local db = ns.Store.DB()
    db.collections = db.collections or {favorites = {}, tracked = {}}
    db.collections.favorites = db.collections.favorites or {}
    db.collections.tracked = db.collections.tracked or {}
    return db.collections
end
function C.CanFavorite(id)
    local family = ns.gemByItem[id]
    return ns.Crafting.byItem[id] ~= nil or (family and family.raw ~= id) or false
end
function C.Favorite(id)
    return saved().favorites[id] == true
end
function C.ToggleFavorite(id)
    if not C.CanFavorite(id) then return false end
    saved().favorites[id] = not C.Favorite(id) or nil
    return true
end
function C.Tracked(id)
    return saved().tracked[id] == true
end
function C.ToggleTracked(id)
    if type(id) ~= "number" or id < 1 or id > 2147483647 or id ~= math.floor(id) then return false end
    saved().tracked[id] = not C.Tracked(id) or nil
    return true
end
function C.Add(input)
    local id = tonumber(input:match("^%s*(%d+)%s*$")) or tonumber(input:match("item:(%d+)"))
    if not id then
        local _, link = ns.Compat.ItemInfo(input)
        id = link and tonumber(link:match("item:(%d+)"))
    end
    if not id then
        for itemID, text in pairs(ns.Store.DB().items) do
            if text:match("^[^\t]+") == input then id = itemID; break end
        end
    end
    if not id then return false end
    if C.Tracked(id) then return true end
    return C.ToggleTracked(id)
end
function C.Pinned(id)
    if C.Favorite(id) then return true end
    local family = ns.gemByRaw[id]
    for _, member in ipairs(family and family.members or {}) do if C.Favorite(member) then return true end end
    return false
end
function C.Order(items)
    local result = {}
    for _, item in ipairs(items) do if C.Pinned(item.raw) then result[#result + 1] = item end end
    for _, item in ipairs(items) do if not C.Pinned(item.raw) then result[#result + 1] = item end end
    return result
end
function C.OrderIDs(ids)
    local result = {ids[1]}
    for i = 2, #ids do if C.Favorite(ids[i]) then result[#result + 1] = ids[i] end end
    for i = 2, #ids do if not C.Favorite(ids[i]) then result[#result + 1] = ids[i] end end
    return result
end
function C.Items(mode)
    local result = {}
    local ids = mode == "favorites" and saved().favorites or saved().tracked
    for id in pairs(ids) do
        if mode ~= "favorites" or (C.CanFavorite(id) and not ns.Hidden.Is(id)) then result[#result + 1] = {raw = id} end
    end
    table.sort(result, function(a, b) return ns.Markets.Name(a.raw) < ns.Markets.Name(b.raw) end)
    return result
end
function C.Targets(mode)
    local ids = {}
    for _, item in ipairs(C.Items(mode)) do ids[#ids + 1] = item.raw end
    return ids
end
function C.Scan(mode, scanMode)
    return ns.Batch.Complete(C.Targets(mode), scanMode, true)
end
function C.OpenRecipe(id)
    local recipe, family = ns.Crafting.byItem[id], ns.gemByItem[id]
    if recipe then ns.Trader.OpenRecipe(recipe.profession, id)
    elseif family then
        ns.Trader.OpenFamily(family.raw, id)
    end
end
