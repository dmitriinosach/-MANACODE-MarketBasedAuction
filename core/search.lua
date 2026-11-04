local _, ns = ...
local Search = {}
ns.Search = Search
local function lower(text)
    return ns.Shopping.Lower(text or "")
end
local function matches(text, aliases)
    for _, alias in ipairs(aliases) do
        if text:find(alias, 1, true) then return true end
        if #text >= 4 and alias:find(text, 1, true) == 1 then return true end
    end
    return false
end
local function wordAt(text, alias)
    local start = 1
    while start <= #text do
        local at = text:find(alias, start, true)
        if not at then return nil end
        local before, after = text:sub(at - 1, at - 1), text:sub(at + #alias, at + #alias)
        if (at == 1 or before:find("[%s%p%d]")) and (after == "" or after:find("[%s%p%d]")) then return at end
        start = at + 1
    end
end
local function wordMatches(text, aliases)
    for _, alias in ipairs(aliases) do if wordAt(text, alias) then return true end end
    for word in text:gmatch("%S+") do
        if #word >= 4 then
            for _, alias in ipairs(aliases) do if alias:find(word, 1, true) == 1 then return true end end
        end
    end
    return false
end
function Search.Parse(text)
    local query, found, aliases = lower(text), {}, {}
    for _, stat in ipairs(ns.searchStats) do
        for _, alias in ipairs(stat.aliases) do aliases[#aliases + 1] = {text = alias, key = stat.key} end
    end
    table.sort(aliases, function(a, b) return #a.text > #b.text end)
    local start = 1
    while start do
        local tail = query:sub(start):gsub("%s+$", "")
        if tail:find(" ", 1, true) then
            local hit
            for _, alias in ipairs(aliases) do
                if #alias.text > #tail and alias.text:find(tail, 1, true) == 1 then hit = alias; break end
            end
            if hit then
                found[hit.key] = true
                query = query:sub(1, start - 1) .. string.rep(" ", #tail) .. query:sub(start + #tail)
                break
            end
        end
        start = query:find("%s%S", start)
        start = start and start + 1
    end
    for _, alias in ipairs(aliases) do
        local at = wordAt(query, alias.text)
        if at then
            found[alias.key] = true
            query = query:sub(1, at - 1) .. string.rep(" ", #alias.text) .. query:sub(at + #alias.text)
        end
    end
    if not next(found) then
        local words = {}
        for word in query:gmatch("%S+") do words[#words + 1] = word end
        for _, word in ipairs(words) do
            for _, stat in ipairs(ns.searchStats) do
                if wordMatches(word, stat.aliases) then
                    found[stat.key] = true
                    local at = wordAt(query, word)
                    if at then query = query:sub(1, at - 1) .. string.rep(" ", #word) .. query:sub(at + #word) end
                end
            end
        end
    end
    local color
    for _, entry in ipairs(ns.searchColors) do if wordMatches(lower(text), entry.aliases) then color = entry.key; break end end
    local rest = query:gsub("%d+", " ")
    if color then
        for _, entry in ipairs(ns.searchColors) do
            if entry.key == color then
                for _, alias in ipairs(entry.aliases) do rest = rest:gsub(alias, " ") end
            end
        end
    end
    return {stats = found, color = color, value = tonumber(query:match("%f[%d](%d+)%f[%D]")),
        rest = (rest:gsub("^%s+", ""):gsub("%s+$", ""))}
end
function Search.Name(id)
    local name = ns.Compat.ItemInfo(id)
    if name then return name end
    local gem = ns.searchGems[id] or ns.searchItems and ns.searchItems[id]
    local locale = GetLocale() == "ruRU" and "ruRU" or "enUS"
    return gem and (gem[locale] or gem.enUS) or ns.Markets.Name(id)
end
function Search.Bonus(gem)
    local out = {}
    for _, stat in ipairs(ns.searchStats) do
        if gem.stats[stat.key] then out[#out + 1] = ns.T("searchBonus", gem.stats[stat.key], ns.T(stat.label)) end
    end
    if gem.effect then
        local key = ns.searchEffects and ns.searchEffects[gem.effect]
        out[#out + 1] = key and ns.T(key) or ns.T("searchEffect", gem.effect)
    end
    return table.concat(out, ", ")
end
function Search.Label(preset)
    local stats = {}
    for _, stat in ipairs(ns.searchStats) do if preset.stats[stat.key] then stats[#stats + 1] = ns.T(stat.label) end end
    if preset.pool then
        local label = ns.T("searchItems")
        for _, pool in ipairs(ns.searchPools) do if pool.key == preset.pool then label = ns.T(pool.label) end end
        if #stats > 0 then return ns.T("searchPoolQuery", label, table.concat(stats, ", ")) end
        return preset.query and preset.query ~= "" and ns.T("searchPoolQuery", label, preset.query) or label
    end
    local labels = {}
    for _, color in ipairs(ns.searchColors) do if color.key == preset.color then labels[#labels + 1] = ns.T(color.label) end end
    for _, stat in ipairs(ns.searchStats) do if preset.stats[stat.key] then labels[#labels + 1] = ns.T(stat.label) end end
    if preset.value then labels[#labels + 1] = tostring(preset.value) end
    return #labels > 0 and ns.T("searchGemPreset", table.concat(labels, ", ")) or ns.T("searchAllGems")
end
function Search.EffectMatch(gem, key)
    if not gem.effect then return false end
    for _, stat in ipairs(ns.searchStats) do
        if stat.key == key and stat.effect and gem.effect:find(stat.effect, 1, true) then return true end
    end
    return false
end
local function byStat(a, b)
    if a.statCount ~= b.statCount then return a.statCount < b.statCount end
    if a.value ~= b.value then return a.value > b.value end
    if a.quality ~= b.quality then return a.quality > b.quality end
    return a.id < b.id
end
local function statItems(preset, filter)
    local out = {}
    for id, item in pairs(ns.searchItems or {}) do
        local include = item.pool == preset.pool and item.stats ~= nil and Search.RankOf(id) ~= ns.searchRanks.scrolls
            and (not filter or not filter.minQuality or item.quality >= filter.minQuality)
        local value, count = 0, 0
        for key, amount in pairs(include and item.stats or {}) do
            count = count + 1
            if preset.stats[key] then value = math.max(value, amount) end
        end
        for key in pairs(preset.stats) do
            if not include or not item.stats[key] or preset.value and item.stats[key] ~= preset.value then include = false end
        end
        if include then
            out[#out + 1] = {id = id, name = Search.Name(id), quality = item.quality, detail = Search.Bonus(item),
                catalog = true, offers = {}, value = value, statCount = count}
        end
    end
    table.sort(out, byStat)
    return out
end
function Search.Catalog(preset, filter)
    if preset.pool and next(preset.stats or {}) then return statItems(preset, filter) end
    if preset.pool then return Search.Items(preset.query or "", filter, preset.pool) end
    local out = {}
    for id, gem in pairs(ns.searchGems) do
        local include = not preset.color or gem.color == preset.color
        include = include and (not filter or not filter.minQuality or gem.quality >= filter.minQuality)
        local value, count = 0, gem.effect and 1 or 0
        for key, amount in pairs(gem.stats) do
            count = count + 1
            if preset.stats[key] then value = math.max(value, amount) end
        end
        for key in pairs(preset.stats) do
            local effect = Search.EffectMatch(gem, key)
            if not (gem.stats[key] or effect) or preset.value and gem.stats[key] ~= preset.value then include = false end
        end
        if not next(preset.stats) and preset.value then
            local any = false
            for _, amount in pairs(gem.stats) do if amount == preset.value then any = true end end
            include = include and any
        end
        if include then
            out[#out + 1] = {id = id, name = Search.Name(id), quality = gem.quality, detail = Search.Bonus(gem),
                catalog = true, offers = {}, value = value, statCount = count}
        end
    end
    table.sort(out, byStat)
    return out
end
function Search.RankOf(id)
    local ranks = ns.searchRanks
    if ns.searchGems[id] then return ranks.gems end
    local item = ns.searchItems and ns.searchItems[id]
    if not item then return ranks.items end
    if item.pool == "consumables" and (item.enUS or ""):find("^Scroll of ") then return ranks.scrolls end
    return ranks[item.pool] or ranks.items
end
function Search.Rank(list)
    for i, item in ipairs(list) do item.order, item.rank = i, Search.RankOf(item.id) end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.order < b.order
    end)
end
local function inPool(id, pool)
    if not pool or pool == "all" then return true end
    if pool == "scrolls" then return Search.RankOf(id) == ns.searchRanks.scrolls end
    local item = ns.searchItems and ns.searchItems[id]
    return item ~= nil and item.pool == pool
end
function Search.Items(text, filters, pool)
    local out, seen = {}, {}
    local named = ns.Shopping.Suggest(text, math.huge)
    if text == "" then
        named = {}
        for id, item in pairs(ns.searchItems or {}) do
            if inPool(id, pool) then
                named[#named + 1] = {id = id, name = Search.Name(id), quality = item.quality}
            end
        end
        table.sort(named, function(a, b)
            if a.name ~= b.name then return a.name < b.name end
            return a.id < b.id
        end)
    end
    for _, item in ipairs(named) do
        local definition = ns.searchItems and ns.searchItems[item.id]
        local quality = item.quality or definition and definition.quality or ns.searchGems[item.id] and ns.searchGems[item.id].quality
        if inPool(item.id, pool) and (not filters or not filters.minQuality or not quality or quality >= filters.minQuality) then
            out[#out + 1] = {kind = "item", id = item.id, name = item.name, quality = quality, catalog = true, offers = {},
                detail = ns.searchGems[item.id] and Search.Bonus(ns.searchGems[item.id])}
            seen[item.id] = true
        end
    end
    if not pool or pool == "all" then
        local preset = Search.Parse(text)
        if next(preset.stats) or preset.color then
            for _, item in ipairs(Search.Catalog(preset, filters)) do
                if not seen[item.id] then item.kind = "item"; out[#out + 1] = item end
            end
            if preset.rest == "" then Search.Rank(out) end
        end
    end
    return out
end
function Search.Categories(class)
    local out = {}
    local names = class and GetAuctionItemSubClasses and {GetAuctionItemSubClasses(class)}
        or not class and GetAuctionItemClasses and {GetAuctionItemClasses()} or {}
    for index, name in ipairs(names) do
        out[#out + 1] = {kind = "category", name = name, classIndex = class or index, subClassIndex = class and index or nil}
    end
    return out
end
local function categoryMatches(query, category, parent)
    local label = lower(category.name .. " " .. (parent or ""))
    local aliases = label
    for _, entry in ipairs(ns.searchCategoryAliases) do
        if matches(label, entry.names) then aliases = aliases .. " " .. entry.aliases end
    end
    for _, color in ipairs(ns.searchColors) do
        if matches(lower(category.name), color.aliases) then aliases = aliases .. " " .. table.concat(color.aliases, " ") end
    end
    for word in query:gmatch("%S+") do if not aliases:find(word, 1, true) then return false end end
    return true
end
Search.SHORT = 4
local ENCHANT_SLOTS = {["Weapon"] = "searchSlotWeapon", ["2H Weapon"] = "searchSlot2H", ["Staff"] = "searchSlotStaff",
    ["Bracer"] = "searchSlotBracers", ["Bracers"] = "searchSlotBracers", ["Gloves"] = "searchSlotGloves",
    ["Boots"] = "searchSlotBoots", ["Cloak"] = "searchSlotCloak", ["Chest"] = "searchSlotChest", ["Shield"] = "searchSlotShield"}
function Search.ShortName(id)
    local name, item = Search.Name(id), ns.searchItems and ns.searchItems[id]
    local slot = item and item.pool == "enchants" and ENCHANT_SLOTS[(item.enUS or ""):match("^Scroll of Enchant (.-) %- ") or ""]
    local tail = name:match(" %- (.+)$")
    if not slot or not tail then return name end
    return ns.T("searchShortEnchant", ns.T(slot), tail)
end
function Search.Short(preset, filters)
    local groups, shown = {}, {}
    local function short(key, all, keep)
        local list, rows = Search.Catalog(all, filters), {}
        for _, item in ipairs(list) do
            if #rows < Search.SHORT and keep(item.id) then
                item.kind, item.short = "item", Search.ShortName(item.id)
                rows[#rows + 1] = item; shown[item.id] = true
            end
        end
        if #list > #rows then
            rows[#rows + 1] = {kind = "preset", preset = all, name = ns.T("searchShowAll", #list)}
        end
        if #rows > 0 then groups[#groups + 1] = {key = key, rows = rows} end
    end
    short("searchGroupGems", {stats = preset.stats, color = preset.color, value = preset.value}, function(id)
        local gem = ns.searchGems[id]
        return gem.wrath and gem.quality >= 3
    end)
    for _, pool in ipairs({{"enchants", "searchGroupEnchants"}, {"consumables", "searchGroupConsumables"}}) do
        short(pool[2], {pool = pool[1], stats = preset.stats, value = preset.value}, function(id)
            return ns.searchItems[id].wrath
        end)
    end
    return groups, shown
end
function Search.Suggest(text, filters)
    local _, short = ns.Shopping.Suggest(text, 1)
    if short then return {}, true end
    local query, entries, itemRows = lower(text):match("^%s*(.-)%s*$"), {}, {}
    local preset = Search.Parse(query)
    local semantic = next(preset.stats) or preset.color
    local pure = semantic and preset.rest == ""
    local stated = pure and next(preset.stats) ~= nil
    local shortGroups, shown = {}, {}
    if stated then shortGroups, shown = Search.Short(preset, filters) end
    local items, others, scrolls = Search.Items(text, filters), {}, 0
    for _, item in ipairs(items) do
        if pure and Search.RankOf(item.id) == ns.searchRanks.scrolls then scrolls = scrolls + 1
        elseif not (stated and (shown[item.id] or ns.searchGems[item.id])) then others[#others + 1] = item end
    end
    for i = 1, math.min(8, #others) do itemRows[#itemRows + 1] = others[i] end
    if #others > 8 then
        itemRows[#itemRows + 1] = {kind = "preset", preset = {pool = "all", query = text, stats = {}},
            name = ns.T("searchAllMatches", #items)}
    end
    if scrolls > 0 then
        itemRows[#itemRows + 1] = {kind = "preset", preset = {pool = "scrolls", query = text, stats = {}},
            name = ns.T("searchScrollMatches", scrolls)}
    end
    local function group(key, rows)
        if #rows == 0 then return end
        entries[#entries + 1] = {kind = "head", name = ns.T(key)}
        for _, row in ipairs(rows) do entries[#entries + 1] = row end
    end
    if not pure then group("searchItems", itemRows) end
    for _, short in ipairs(shortGroups) do group(short.key, short.rows) end
    local presets = {}
    if not stated and (semantic or matches(query, ns.searchGemWords)) then
        presets[1] = {kind = "preset", preset = preset, name = ns.T("searchFor", Search.Label(preset))}
        if not next(preset.stats) then
            for _, stat in ipairs(ns.searchStats) do
                local specific = {stats = {[stat.key] = true}, color = preset.color, value = preset.value}
                if #presets < 4 and #Search.Catalog(specific, filters) > 0 then
                    presets[#presets + 1] = {kind = "preset", preset = specific, name = ns.T("searchFor", Search.Label(specific))}
                end
            end
        end
    end
    for _, pool in ipairs(ns.searchPools) do
        local direct = matches(query, pool.aliases)
        if #presets < 4 and not (pure and pool.key == "scrolls") and not stated
            and (direct or #Search.Items(text, filters, pool.key) > 0) then
            local scoped = {pool = pool.key, query = not direct and text or "", stats = {}}
            presets[#presets + 1] = {kind = "preset", preset = scoped, name = ns.T("searchFor", Search.Label(scoped))}
        end
    end
    group("searchPresets", presets)
    if pure then group("searchItems", itemRows) end
    local categories = {}
    for _, category in ipairs(Search.Categories()) do
        if categoryMatches(query, category) and #categories < 4 then
            categories[#categories + 1] = {kind = "category", classIndex = category.classIndex,
                name = ns.T("searchFor", category.name), label = category.name}
        end
        for _, sub in ipairs(Search.Categories(category.classIndex)) do
            if categoryMatches(query, sub, category.name) and #categories < 4 then
                local label = category.name .. " — " .. sub.name
                categories[#categories + 1] = {kind = "category", classIndex = sub.classIndex, subClassIndex = sub.subClassIndex,
                    name = ns.T("searchFor", label), label = label}
            end
        end
    end
    group("searchCategories", categories)
    return entries, false
end
