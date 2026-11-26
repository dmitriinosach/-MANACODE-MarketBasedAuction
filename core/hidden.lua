local _, ns = ...
local H = {}
ns.Hidden = H
local function saved()
    local db = ns.Store.DB()
    db.hidden = db.hidden or {}
    return db.hidden
end
function H.Is(id)
    return saved()[id] == true
end
function H.Set(id, hidden)
    if not ns.Crafting.byItem[id] and not (ns.gemByItem and ns.gemByItem[id]) then return false end
    saved()[id] = hidden or nil
    return true
end
function H.IsGroup(key)
    return saved()["group:" .. key] == true
end
function H.SetGroup(key, hidden)
    saved()["group:" .. key] = hidden or nil
end
H.describers = {}
function H.Describe(fn)
    H.describers[#H.describers + 1] = fn
end
function H.Groups()
    local result = {}
    for key, value in pairs(saved()) do
        if value == true and type(key) == "string" and key:sub(1, 6) == "group:" then
            local id, info = key:sub(7), nil
            for _, fn in ipairs(H.describers) do
                info = fn(id)
                if info then break end
            end
            result[#result + 1] = {key = id, name = info and info.name or id, place = info and info.place or "",
                icon = info and info.icon}
        end
    end
    table.sort(result, function(a, b)
        if a.place ~= b.place then return a.place < b.place end
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
    return result
end
function H.Toggle(id)
    return H.Set(id, not H.Is(id))
end
function H.Filter(recipes, hidden)
    local result = {}
    for _, recipe in ipairs(recipes) do
        if H.Is(recipe.raw) == hidden then result[#result + 1] = recipe end
    end
    return result
end
function H.Recipes(profession, category)
    local result = {}
    for _, key in ipairs(ns.Crafting.order) do
        local catalog = ns.craftCatalogs[key]
        if catalog and (not profession or profession == key) then
            for _, recipe in ipairs(H.Filter(catalog.recipes, true)) do
                if not category or recipe.category == category then result[#result + 1] = recipe end
            end
        end
    end
    table.sort(result, function(a, b)
        local left, right = ns.Markets.Name(a.raw), ns.Markets.Name(b.raw)
        if left == right then return a.raw < b.raw end
        return left < right
    end)
    return result
end
function H.Restore(profession, category)
    local count = 0
    for _, recipe in ipairs(H.Recipes(profession, category)) do
        saved()[recipe.raw] = nil
        count = count + 1
    end
    if not profession and not category then
        for _, group in ipairs(H.Groups()) do
            H.SetGroup(group.key, false)
            count = count + 1
        end
    end
    return count
end
function H.Categories()
    local result, seen = {}, {}
    for _, key in ipairs(ns.Crafting.order) do
        local catalog = ns.craftCatalogs[key]
        for _, recipe in ipairs(catalog and catalog.recipes or {}) do
            if not seen[recipe.category] then
                seen[recipe.category] = true
                result[#result + 1] = recipe.category
            end
        end
    end
    return result
end
