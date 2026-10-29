local _, ns = ...
local UI = {props = {}, rows = {}, groups = {}}
ns.HiddenUI = UI
function UI:SetProps(props)
    for key, value in pairs(props) do self.props[key] = value end
    self.selected = nil; self.scroll.offset = 0; self:Render()
end
function UI:Entries()
    return ns.Hidden.Recipes(self.props.profession, self.props.category)
end
function UI:Render()
    if not self.frame then return end
    local K, p = ns.TradeKit, self.props
    local entries = self.sorter:Apply(self:Entries(), {
        item = function(recipe) return ns.Markets.Name(recipe.raw) end,
        price = function(recipe) local q = ns.Markets.Quote(recipe.raw); return q and q.price end,
        units = function(recipe) local q = ns.Markets.Quote(recipe.raw); return q and q.units end,
    })
    local groups = ns.Hidden.Groups()
    local lines = {}
    for _, group in ipairs(groups) do lines[#lines + 1] = {group = group} end
    for _, recipe in ipairs(entries) do lines[#lines + 1] = {recipe = recipe} end
    local catalog = p.profession and ns.craftCatalogs[p.profession]
    self.profession.frame:SetText(ns.T(catalog and catalog.labelKey or "hiddenAllProfessions"))
    self.category.frame:SetText(ns.T(p.category or "hiddenAllCategories"))
    local width = (self.frame:GetWidth() or 996) - 310
    local columns = K.MarketColumns(width - self.rows[1]:Reserve(true))
    K.PlaceHeaders(self.headers, columns, self.frame, -38)
    self.sorter:Mark()
    self.statusText = ns.T("hiddenTitle", #groups, #entries)
    ns.Trader.RenderStatus()
    local visible = K.ListCapacity(self.frame, 56, 56, 29, #self.rows + #self.groups)
    local offset = self.scroll:SetRange(#lines, visible)
    local selected
    for _, recipe in ipairs(entries) do if recipe.raw == self.selected then selected = recipe end end
    if not selected then selected = entries[1]; self.selected = selected and selected.raw end
    local usedRows, usedGroups = 0, 0
    for i = 1, visible do
        local line = lines[offset + i]
        local y = -56 - (i - 1) * 29
        if line and line.group then
            usedGroups = usedGroups + 1
            local header, group = self.groups[usedGroups], line.group
            if header then
                header.frame:ClearAllPoints(); header.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, y)
                header:SetProps({key = group.key, name = group.name, detail = group.place, icon = group.icon,
                    width = width, height = 28, open = false, hideKey = group.key, hidden = true})
            end
        elseif line then
            usedRows = usedRows + 1
            local row, recipe = self.rows[usedRows], line.recipe
            if row then
                row.frame:ClearAllPoints(); row.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, y)
                local q = ns.Markets.Quote(recipe.raw)
                row:SetProps({id = recipe.raw, quote = q, width = width, wide = true, active = recipe.raw == self.selected,
                    detail = ns.T(ns.craftCatalogs[recipe.profession].labelKey) .. " | " .. ns.T(recipe.category),
                    hidden = true, hideable = true, noRefresh = true, hideLabel = ns.T("hiddenRestore")})
            end
        end
    end
    for i = usedRows + 1, #self.rows do self.rows[i].frame:Hide() end
    for i = usedGroups + 1, #self.groups do self.groups[i].frame:Hide() end
    self.empty:SetText(#lines == 0 and ns.T("hiddenEmpty") or "")
    if selected then self.inspector:SetProps({id = selected.raw}) else self.inspector:Clear() end
    self.summary:SetText(ns.T("hiddenHint"))
    if #lines > 0 then self.restoreAll:Enable() else self.restoreAll:Disable() end
end
function UI:New(parent)
    local K = ns.TradeKit
    local f = ns.NewFrame("Frame", nil, parent); f:SetAllPoints(parent); self.frame = f
    local professions = {{key = "all", labelKey = "hiddenAllProfessions"}}
    for _, key in ipairs(ns.Crafting.order) do
        if ns.craftCatalogs[key] then professions[#professions + 1] = {key = key, labelKey = ns.craftCatalogs[key].labelKey} end
    end
    self.profession = K.Menu(f, professions, function(key)
        self:SetProps({profession = key ~= "all" and key or false, category = false})
    end)
    self.profession.frame:SetWidth(190); self.profession.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -3)
    local categories = {{key = "all", labelKey = "hiddenAllCategories"}}
    for _, key in ipairs(ns.Hidden.Categories()) do categories[#categories + 1] = {key = key, labelKey = key} end
    self.category = K.Menu(f, categories, function(key) self:SetProps({category = key ~= "all" and key or false}) end)
    self.category.frame:SetWidth(190); self.category.frame:SetPoint("LEFT", self.profession.frame, "RIGHT", 8, 0)
    self.restoreAll = K.Button(f, ns.T("hiddenRestoreAll"), 140, function()
        ns.Hidden.Restore(self.props.profession or nil, self.props.category or nil); ns.Trader.Refresh()
    end, "main")
    self.restoreAll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -282, 4)
    K.Tooltip(self.restoreAll, ns.T("hiddenRestoreAll"), ns.T("hiddenRestoreAllTip"))
    K.TableHeader(f, -38)
    self.headers = {}
    for _, entry in ipairs({{"item", "hiddenColumn"}, {"price", "tradeUnitPrice"}, {"units", "tradeUnits"}}) do
        self.headers[entry[1]] = K.Label(f, ns.T(entry[2]), 0, -38, 100)
        if entry[1] ~= "item" then self.headers[entry[1]]:SetJustifyH("RIGHT") end
    end
    self.sorter = K.Sorter(f, self.headers, function() self.scroll.offset = 0; self:Render() end, nil, {key = "item", desc = false})
    self.headers.margin = K.Label(f, "", 0, -38, 100)
    self.scroll = K.TableScroll(f, function() self:Render() end, 56, 56, 29)
    for i = 1, 40 do
        local row = K.MarketRow:New(f, function(id) self.selected = id; self:Render() end, nil,
            function(id) ns.Hidden.Toggle(id); ns.Trader.Refresh() end)
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -56 - (i - 1) * 29)
        row.frame:SetHeight(28); self.rows[i] = row; self.scroll:Wheel(row.frame)
    end
    for i = 1, 20 do
        local header = K.GroupRow:New(f, function() end, function() ns.Trader.Refresh() end)
        header.frame:Hide(); self.scroll:Wheel(header.frame); self.groups[i] = header
    end
    self.empty = K.Label(f, "", 10, -66, 440); self.empty:SetHeight(64)
    self.inspector = K.Inspector:New(f)
    self.summary = K.Label(self.inspector.body, "", 12, -48, 240)
    self.summary:SetHeight(200); self.summary:SetJustifyV("TOP")
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render(); return self
end
