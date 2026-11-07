local _, ns = ...
local UI = {props = {}}
ns.HiddenUI = UI
function UI:SetProps(props)
    for key, value in pairs(props) do self.props[key] = value end
    self.selected = nil; self.table:ResetScroll(); self:Render()
end
function UI:Entries()
    return ns.Hidden.Recipes(self.props.profession, self.props.category)
end
local function syncMenu(menu, entries, all, chosen)
    local shown, present, signature = #entries > 1, false, {}
    for _, entry in ipairs(entries) do
        signature[#signature + 1] = entry.key
        if entry.key == chosen then present = true end
    end
    signature = table.concat(signature, ";")
    if signature ~= menu.signature then
        menu.signature = signature
        local list = {{key = "all", labelKey = all}}
        for _, entry in ipairs(entries) do list[#list + 1] = entry end
        menu:SetEntries(list)
    end
    if not shown then menu.cover:Hide(); menu.frame:Hide() end
    return shown and present and chosen or false, shown
end
function UI:RenderFilters()
    local p, seen, professions = self.props, {}, {}
    for _, recipe in ipairs(ns.Hidden.Recipes(nil, nil)) do seen[recipe.profession] = true end
    for _, key in ipairs(ns.Crafting.order) do
        if seen[key] and ns.craftCatalogs[key] then
            professions[#professions + 1] = {key = key, labelKey = ns.craftCatalogs[key].labelKey}
        end
    end
    local showProfession, showCategory
    p.profession, showProfession = syncMenu(self.profession, professions, "hiddenAllProfessions", p.profession)
    local categories = {}
    seen = {}
    for _, recipe in ipairs(ns.Hidden.Recipes(p.profession or nil, nil)) do seen[recipe.category] = true end
    for _, key in ipairs(ns.Hidden.Categories()) do
        if seen[key] then categories[#categories + 1] = {key = key, labelKey = key} end
    end
    p.category, showCategory = syncMenu(self.category, categories, "hiddenAllCategories", p.category)
    local catalog = p.profession and ns.craftCatalogs[p.profession]
    self.profession.frame:SetText(ns.T(catalog and catalog.labelKey or "hiddenAllProfessions"))
    self.category.frame:SetText(ns.T(p.category or "hiddenAllCategories"))
    local filters = {}
    if showProfession then filters[#filters + 1] = self.profession.frame end
    if showCategory then filters[#filters + 1] = self.category.frame end
    self.sectionHead:SetProps({filters = filters, actions = {self.restoreAll}})
end
function UI:Render()
    if not self.frame then return end
    self:RenderFilters()
    local entries = self.table.sorter:Apply(self:Entries(), {
        item = function(recipe) return ns.Markets.Name(recipe.raw) end,
        price = function(recipe) local q = ns.Markets.Quote(recipe.raw); return q and q.price end,
        units = function(recipe) local q = ns.Markets.Quote(recipe.raw); return q and q.units end,
    })
    local groups = ns.Hidden.Groups()
    local lines = {}
    for _, group in ipairs(groups) do lines[#lines + 1] = {kind = "group", group = group} end
    for _, recipe in ipairs(entries) do lines[#lines + 1] = {recipe = recipe} end
    self.statusText = nil
    ns.Trader.RenderStatus()
    local selected
    for _, recipe in ipairs(entries) do if recipe.raw == self.selected then selected = recipe end end
    if not selected then selected = entries[1]; self.selected = selected and selected.raw end
    ns.TradeKit.ScreenBody(self.table, self.inspector, self.sectionHead)
    self.table:SetLines(lines, function(line, _, columns)
        local group, recipe = line.group, line.recipe
        if group then
            return {key = group.key, name = group.name, detail = group.place, icon = group.icon,
                open = false, hideKey = group.key, hidden = true}
        end
        return {id = recipe.raw, quote = ns.Markets.Quote(recipe.raw), columns = columns, wide = true,
            active = recipe.raw == self.selected, detail = ns.T(ns.craftCatalogs[recipe.profession].labelKey)
                .. " | " .. ns.T(recipe.category),
            hidden = true, hideable = true, noRefresh = true, hideLabel = ns.T("hiddenRestore")}
    end)
    if selected then self.inspector:SetProps({id = selected.raw}) else self.inspector:Clear() end
    self.summary:SetText(ns.T("hiddenHint"))
    if #lines > 0 then self.restoreAll:Enable() else self.restoreAll:Disable() end
end
function UI:New(parent)
    local K = ns.TradeKit
    local f = ns.NewFrame("Frame", nil, parent); f:SetAllPoints(parent); self.frame = f
    self.profession = K.Menu(f, {}, function(key)
        self:SetProps({profession = key ~= "all" and key or false, category = false})
    end)
    self.profession.frame:SetWidth(190)
    self.category = K.Menu(f, {}, function(key) self:SetProps({category = key ~= "all" and key or false}) end)
    self.category.frame:SetWidth(190)
    self.restoreAll = K.Button(f, ns.T("hiddenRestoreAll"), 140, function()
        ns.Hidden.Restore(self.props.profession or nil, self.props.category or nil); ns.Trader.Refresh()
    end, "main")
    self.sectionHead = K.SectionHead:New(f)
    K.Tooltip(self.restoreAll, ns.T("hiddenRestoreAll"), ns.T("hiddenRestoreAllTip"))
    self.inspector = K.Inspector:New(f)
    self.table = K.Table:New(f, {
        headers = {{key = "item", text = "hiddenColumn"}, {key = "price", text = "tradeUnitPrice"}, {key = "units", text = "tradeUnits"}},
        columns = function(width, tbl) return K.MarketColumns(width - tbl:Row("row", 1):Reserve(true)) end,
        kinds = {
            row = {new = function(parent)
                return K.MarketRow:New(parent, function(id) self.selected = id; self:Render() end, nil,
                    function(id) ns.Hidden.Toggle(id); ns.Trader.Refresh() end)
            end},
            group = {new = function(parent)
                return K.GroupRow:New(parent, function() end, function() ns.Trader.Refresh() end)
            end},
        },
        sort = {default = {key = "item", desc = false}},
        changed = function() self:Render() end,
        empty = "hiddenEmpty",
    })
    self.summary = K.Label(self.inspector.body, "", 12, -48, 240)
    self.summary:SetHeight(200); self.summary:SetJustifyV("TOP")
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render(); return self
end
