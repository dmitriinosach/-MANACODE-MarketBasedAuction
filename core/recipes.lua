local _, ns = ...
local R = {}
ns.Recipes = R
local function book()
    local db = ns.Store.DB()
    local key = (GetRealmName() or "") .. "|" .. (UnitName("player") or "")
    db.recipeBook = db.recipeBook or {}
    db.recipeBook[key] = db.recipeBook[key] or {known = {}, checked = {}}
    return db.recipeBook[key]
end
local function complete()
    local box = _G["TradeSkillFrameAvailableFilterCheckButton"]
    if box and box:GetChecked() then return false end
    local text = GetTradeSkillItemNameFilter and GetTradeSkillItemNameFilter()
    if text and text ~= "" then return false end
    if GetTradeSkillSubClassFilter and not GetTradeSkillSubClassFilter(0) then return false end
    if GetTradeSkillInvSlotFilter and not GetTradeSkillInvSlotFilter(0) then return false end
    return true
end
function R.Read()
    if not GetTradeSkillLine or not GetNumTradeSkills or not GetTradeSkillRecipeLink then return false end
    if IsTradeSkillLinked and IsTradeSkillLinked() then return false end
    local line, rank = GetTradeSkillLine()
    if not line or line == "UNKNOWN" then return false end
    local entry, seen, full = book(), {}, complete()
    if tonumber(rank) and rank > 0 then entry.ranks = entry.ranks or {}; entry.ranks[line] = rank end
    for i = 1, GetNumTradeSkills() do
        local _, kind, _, expanded = GetTradeSkillInfo(i)
        if kind == "header" then
            if not expanded then full = false end
        else
            local link = GetTradeSkillRecipeLink(i)
            local spell = link and tonumber(link:match("enchant:(%d+)"))
            if spell then seen[spell] = true end
        end
    end
    entry.faction = UnitFactionGroup("player") or entry.faction
    for spell in pairs(seen) do entry.known[spell] = line end
    if full then
        for spell, owner in pairs(entry.known) do
            if owner == line and not seen[spell] then entry.known[spell] = nil end
        end
        entry.checked[line] = time()
    end
    return true
end
function R.Known(spell, profession)
    if not spell then return nil end
    local entry = book()
    if entry.known[spell] then return true end
    if profession and entry.checked[profession] then return false end
    return nil
end
function R.KnownBy(spell, profession)
    local list = {}
    if not spell then return list end
    local prefix = (GetRealmName() or "") .. "|"
    local me, mine = UnitName("player") or "", UnitFactionGroup("player")
    for key, entry in pairs(ns.Store.DB().recipeBook or {}) do
        if key:sub(1, #prefix) == prefix then
            local name = key:sub(#prefix + 1)
            local known
            if entry.known[spell] then known = true
            elseif profession and entry.checked[profession] then known = false end
            list[#list + 1] = {name = name, known = known, faction = entry.faction, me = name == me,
                other = entry.faction ~= nil and mine ~= nil and entry.faction ~= mine}
        end
    end
    local rank = {[true] = 1, [false] = 2}
    table.sort(list, function(a, b)
        if a.me ~= b.me then return a.me end
        local left, right = rank[a.known] or 3, rank[b.known] or 3
        if left ~= right then return left < right end
        return a.name < b.name
    end)
    return list
end
function R.Checked(profession)
    return book().checked[profession]
end
function R.Rank(profession)
    local entry = book()
    local rank = entry.ranks and entry.ranks[profession]
    if rank then return rank end
    if entry.skillsRead then return false end
    return nil
end
function R.Owners(spell)
    local names, realm = {}, GetRealmName() or ""
    if not spell then return names end
    for key, entry in pairs(ns.Store.DB().recipeBook or {}) do
        local owner, name = key:match("^(.-)|(.*)$")
        if owner == realm and entry.known and entry.known[spell] then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end
local function professionNames()
    local names = {[ns.T("jewelrySection")] = true}
    for _, catalogs in ipairs({ns.craftCatalogs or {}, ns.gatheringCatalogs or {}}) do
        for _, catalog in pairs(catalogs) do names[ns.T(catalog.labelKey)] = true end
    end
    return names
end
function R.ReadSkills()
    if not GetNumSkillLines or not GetSkillLineInfo then return false end
    local names, seen, full = professionNames(), {}, true
    for i = 1, GetNumSkillLines() or 0 do
        local name, header, expanded, rank = GetSkillLineInfo(i)
        if header then
            if not expanded then full = false end
        elseif name and names[name] then seen[name] = tonumber(rank) or 0 end
    end
    local entry = book()
    entry.ranks = entry.ranks or {}
    for name, rank in pairs(seen) do entry.ranks[name] = rank end
    if full then
        for name in pairs(entry.ranks) do if not seen[name] then entry.ranks[name] = nil end end
        entry.skillsRead = time()
    end
    return true
end
function R.Professions()
    local result, prefix, me = {}, (GetRealmName() or "") .. "|", UnitName("player") or ""
    for key, entry in pairs(ns.Store.DB().recipeBook or {}) do
        if key:sub(1, #prefix) == prefix then
            local ranks, lines = entry.ranks or {}, {}
            for line, rank in pairs(ranks) do lines[line] = rank end
            if not entry.skillsRead then
                for line in pairs(entry.checked or {}) do lines[line] = lines[line] or false end
                for _, line in pairs(entry.known or {}) do lines[line] = lines[line] or false end
            end
            local name = key:sub(#prefix + 1)
            for line, rank in pairs(lines) do
                result[line] = result[line] or {}
                local list = result[line]
                list[#list + 1] = {name = name, rank = rank or nil, me = name == me}
            end
        end
    end
    for _, list in pairs(result) do
        table.sort(list, function(a, b)
            if a.me ~= b.me then return a.me end
            if (a.rank or 0) ~= (b.rank or 0) then return (a.rank or 0) > (b.rank or 0) end
            return a.name < b.name
        end)
    end
    return result
end
local events = ns.NewFrame("Frame")
ns.Listen(events, "TRADE_SKILL_SHOW")
ns.Listen(events, "TRADE_SKILL_UPDATE")
ns.Listen(events, "SKILL_LINES_CHANGED")
ns.Listen(events, "PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event)
    if event == "SKILL_LINES_CHANGED" or event == "PLAYER_ENTERING_WORLD" then R.ReadSkills(); return end
    if R.Read() and ns.Trader and ns.Trader.frame and ns.Trader.frame:IsShown() then ns.Trader.Refresh() end
end)
