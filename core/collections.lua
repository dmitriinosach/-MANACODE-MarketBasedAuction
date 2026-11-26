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
function C.Resolve(input)
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
    return id
end
function C.Add(input, mode)
    local id = C.Resolve(input)
    if not id then return false, "collectionInvalid" end
    local index = mode and C.ListIndex(mode)
    if index then
        if not C.AddToList(index, id) then return false, "collectionListFull" end
        return true
    end
    if C.Tracked(id) then return true end
    return C.ToggleTracked(id), "collectionInvalid"
end
C.LIST_MAX = 6
C.LIST_ITEMS = 200
C.LIST_NAME = 12
local UTF8_CHAR = "[" .. string.char(1) .. "-" .. string.char(127) .. string.char(194) .. "-" .. string.char(244) .. "]["
    .. string.char(128) .. "-" .. string.char(191) .. "]*"
function C.ListName(text)
    if type(text) ~= "string" then return nil end
    local name = text:gsub("[%c|]", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    local out, count = {}, 0
    for char in name:gmatch(UTF8_CHAR) do
        if count >= C.LIST_NAME then break end
        count = count + 1
        out[count] = char
    end
    name = table.concat(out):gsub(" $", "")
    if name == "" then return nil end
    return name
end
function C.Lists()
    local store = saved()
    if type(store.lists) ~= "table" then store.lists = {} end
    local lists = store.lists
    for i = #lists, 1, -1 do
        local list = lists[i]
        if type(list) ~= "table" or type(list.name) ~= "string" or i > C.LIST_MAX then table.remove(lists, i)
        elseif type(list.items) ~= "table" then list.items = {} end
    end
    return lists
end
function C.ListMode(index)
    return "list:" .. index
end
function C.ListIndex(mode)
    local index = type(mode) == "string" and tonumber(mode:match("^list:(%d+)$")) or nil
    if index and C.Lists()[index] then return index end
    return nil
end
local function nameTaken(name, skip)
    for i, list in ipairs(C.Lists()) do
        if i ~= skip and list.name == name then return true end
    end
    return false
end
function C.NewList(text)
    local lists, name = C.Lists(), C.ListName(text)
    if #lists >= C.LIST_MAX then return nil, "collectionListLimit" end
    if not name or nameTaken(name) then return nil, "collectionListInvalid" end
    lists[#lists + 1] = {name = name, items = {}}
    return #lists
end
function C.RenameList(index, text)
    local list, name = C.Lists()[index], C.ListName(text)
    if not list or not name or nameTaken(name, index) then return false, "collectionListInvalid" end
    if ns.AccountingFeed then ns.AccountingFeed.ListRenamed(list.name, name) end
    list.name = name
    return true
end
function C.DeleteList(index)
    local lists = C.Lists()
    if not lists[index] then return false end
    if ns.AccountingFeed then ns.AccountingFeed.ListDeleted(lists[index].name) end
    table.remove(lists, index)
    return true
end
function C.InList(index, id)
    local list = C.Lists()[index]
    return list ~= nil and list.items[id] == true
end
function C.ListCount(index)
    local list, count = C.Lists()[index], 0
    for _ in pairs(list and list.items or {}) do count = count + 1 end
    return count
end
function C.AddToList(index, id)
    local list = C.Lists()[index]
    if not list or type(id) ~= "number" or id < 1 or id > 2147483647 or id ~= math.floor(id) then return false end
    if list.items[id] then return true end
    if C.ListCount(index) >= C.LIST_ITEMS then return false end
    list.items[id] = true
    return true
end
function C.RemoveFromList(index, id)
    local list = C.Lists()[index]
    if not list or not list.items[id] then return false end
    list.items[id] = nil
    return true
end
function C.Reason(key)
    return ns.T(key, key == "collectionListLimit" and C.LIST_MAX or C.LIST_ITEMS)
end
function C.ToggleList(index, id)
    if C.InList(index, id) then return C.RemoveFromList(index, id) end
    return C.AddToList(index, id)
end
C.PIN_MAX = 40
function C.IsPinned(list, id)
    local pins = ns.Store.DB().pins
    local set = type(pins) == "table" and pins[list]
    return type(set) == "table" and set[id] == true
end
function C.TogglePin(list, id)
    local db = ns.Store.DB()
    if type(db.pins) ~= "table" then db.pins = {} end
    if type(db.pins[list]) ~= "table" then db.pins[list] = {} end
    local set = db.pins[list]
    if set[id] then
        set[id] = nil
        if next(set) == nil then db.pins[list] = nil end
        return true
    end
    local count = 0
    for _ in pairs(set) do count = count + 1 end
    if count >= C.PIN_MAX then return false end
    set[id] = true
    return true
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
    local index = C.ListIndex(mode)
    local ids = index and C.Lists()[index].items or mode == "favorites" and saved().favorites or saved().tracked
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
