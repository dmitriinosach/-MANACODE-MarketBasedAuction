local _, ns = ...
local UI = {props = {mode = "favorites"}}
ns.CollectionsUI = UI
function UI:SetProps(props)
    for key, value in pairs(props) do if key ~= "fee" then self.props[key] = value end end
    self.selected, self.deleting = nil, nil; self.table:ResetScroll(); self:Render()
end
function UI:RenderTabs()
    local C = ns.Collections
    local labels = {favorites = ns.T("collectionFavorites"), tracked = ns.T("collectionTracked")}
    local lists, stamp = C.Lists(), {}
    for i, list in ipairs(lists) do labels[C.ListMode(i)] = list.name; stamp[i] = list.name end
    if #lists < C.LIST_MAX then labels.new = "+" end
    local key = table.concat(stamp, "|")
    if key ~= self.tabStamp then self.tabStamp = key; self.mode:Arrange(labels) end
    self.mode:Select(self.props.mode)
end
function UI:Pick(mode)
    if mode ~= "new" then self:SetProps({mode = mode}); return end
    ns.TradeKit.NewListPrompt(function(index) self:SetProps({mode = ns.Collections.ListMode(index)}) end)
end
function UI:Rename()
    local C = ns.Collections
    local index = C.ListIndex(self.props.mode)
    if not index then return end
    ns.TradeKit.Prompt({title = ns.T("collectionListRename"), text = C.Lists()[index].name,
        accept = ns.T("collectionListSave"), letters = C.LIST_NAME, done = function(text)
            local ok, reason = C.RenameList(index, text)
            if not ok then ns.say(C.Reason(reason), "bad"); return false end
            self:Render()
        end})
end
function UI:Delete()
    local C = ns.Collections
    local index = C.ListIndex(self.props.mode)
    if not index then return end
    if not self.deleting then self.deleting = true; self:Render(); return end
    C.DeleteList(index)
    self:SetProps({mode = "tracked"})
end
function UI:AddItem(id)
    local C = ns.Collections
    local ok, reason = C.Add("item:" .. id, self.props.mode)
    if not ok then ns.say(C.Reason(reason), "bad"); return false end
    self.selected = id
    self:Render()
    return true
end
function UI:TakeItem(id)
    local index = self.frame and self.frame:IsVisible() and ns.Collections.ListIndex(self.props.mode)
    if not index or ns.Collections.InList(index, id) then return false end
    self:AddItem(id)
    return true
end
function UI:DropCursor()
    if self.props.mode == "favorites" then return false end
    local item = ns.Posting.CursorItem()
    if not item then return false end
    ClearCursor()
    self:AddItem(item.id)
    return true
end
function UI:Render()
    if not self.frame then return end
    local K, C, p = ns.TradeKit, ns.Collections, self.props
    local own = C.ListIndex(p.mode)
    if not own and p.mode ~= "favorites" then p.mode = "tracked" end
    local entries = C.Items(p.mode)
    for _, entry in ipairs(entries) do
        local q, margin = ns.Markets.Quote(entry.raw)
        local recipe, family = ns.Crafting.byItem[entry.raw], ns.gemByItem[entry.raw]
        local detail = ""
        if recipe then
            margin = ns.CraftPlan.Build(recipe, {fee = ns.Fee()}).margin
            detail = ns.T(ns.craftCatalogs[recipe.profession].labelKey)
        elseif family and family.raw ~= entry.raw then
            local raw = ns.Markets.Quote(family.raw)
            if q and q.price and raw and raw.price and q.miss == 0 and raw.miss == 0 then margin = q.price * (1 - ns.Fee()) - raw.price end
            detail = ns.T("jewelrySection")
        end
        if q and not q.vendor then detail = detail .. ns.T("cacheAge", math.max(0, math.floor((time() - q.at) / 60))) end
        entry.quote, entry.margin, entry.detail = q, margin, detail
    end
    entries = self.table.sorter:Apply(entries, {
        item = function(entry) return ns.Markets.Name(entry.raw) end,
        price = function(entry) return entry.quote and entry.quote.price end,
        margin = function(entry) return entry.margin end,
        units = function(entry) return entry.quote and entry.quote.units end,
    })
    self:RenderTabs()
    local adding = p.mode ~= "favorites"
    if adding then self.addFilter:Show() else self.addFilter:Hide() end
    if own then self.rename:Show(); self.remove:Show() else self.rename:Hide(); self.remove:Hide() end
    self.remove:SetText(ns.T(self.deleting and "collectionListDeleteConfirm" or "collectionListDelete"))
    K.FitButton(self.remove, 20)
    self.sectionHead:SetProps({lead = self.mode.frame, filters = adding and {self.addFilter} or nil,
        actions = own and {self.rename, self.remove} or nil})
    local selected
    for _, entry in ipairs(entries) do if entry.raw == self.selected then selected = entry end end
    if not selected then selected = entries[1]; self.selected = selected and selected.raw end
    K.ScreenBody(self.table, self.inspector, self.sectionHead)
    self.table:SetLines(entries, function(entry, _, columns)
        return {id = entry.raw, quote = entry.quote, columns = columns,
            active = entry.raw == self.selected, detail = entry.detail, margin = entry.margin,
            tag = ns.Markets.FromVendor(entry.raw) and ns.T("vendorAvailable") or nil}
    end)
    for _, label in ipairs(self.labels) do if selected then label:Show() else label:Hide() end end
    self.summary:ClearAllPoints()
    self.summary:SetPoint("TOPLEFT", self.inspector.body, "TOPLEFT", 12, selected and -98 or -48)
    if selected then
        self.inspector:SetProps({id = selected.raw})
        local q = ns.Markets.Quote(selected.raw)
        self.price:SetText(K.Money(q and q.price))
        self.observed:SetText(q and not q.vendor and date("%d.%m %H:%M", q.at) or ns.T("tradeNoPrice"))
        self.summary:SetText(ns.T("collectionHistoryHint"))
        local id, actions = selected.raw, {K.ActionBand.Buy(selected.raw)}
        if C.CanFavorite(id) then
            actions[2] = {key = "recipe", label = ns.T("collectionOpenRecipe"), tip = ns.T("collectionOpenRecipeTip"),
                fn = function() C.OpenRecipe(id) end}
        end
        self.band:SetProps({actions = actions})
    else
        self.inspector:Clear()
        self.summary:SetText(ns.T("collectionActionsTip")); self.band:SetProps({actions = {}})
        self.price:SetText(""); self.observed:SetText("")
    end
    self.scan:SetBusy((ns.Scan.state.phase ~= "idle" or ns.Buy.Active()) and ns.T("batchBusy") or nil)
end
function UI:Bar()
    return self.barFrames
end
function UI:New(parent)
    local K = ns.TradeKit
    local f = ns.NewFrame("Frame", nil, parent); f:SetAllPoints(parent); self.frame = f
    local tabs = {{key = "favorites", label = ns.T("collectionFavorites"),
            tip = {ns.T("collectionFavorites"), ns.T("collectionFavoriteHint")}},
        {key = "tracked", label = ns.T("collectionTracked")}}
    for i = 1, ns.Collections.LIST_MAX do tabs[#tabs + 1] = {key = ns.Collections.ListMode(i), label = ""} end
    tabs[#tabs + 1] = {key = "new", label = "+", tip = {ns.T("collectionNewList"), ""}}
    self.mode = K.Segment(f, tabs, function(mode) self:Pick(mode) end, {ns.T("collectionTitle"), ""})
    self.sectionHead = K.SectionHead:New(f)
    self.rename = K.Button(f, ns.T("collectionListRename"), 110, function() self:Rename() end, "quiet")
    K.FitButton(self.rename, 20)
    K.Tooltip(self.rename, ns.T("collectionListRename"), "")
    self.remove = K.Button(f, ns.T("collectionListDelete"), 80, function() self:Delete() end, "quiet")
    K.Tooltip(self.remove, ns.T("collectionListDelete"), ns.T("collectionListDeleteTip"))
    self.remove:HookScript("OnLeave", function() if self.deleting then self.deleting = nil; self:Render() end end)
    self.rename:Hide(); self.remove:Hide()
    self.addFilter = ns.NewFrame("Frame", nil, f)
    self.addFilter:SetWidth(310); self.addFilter:SetHeight(22)
    self.input = K.ItemField(K.Edit(self.addFilter, 220)); self.input:SetPoint("TOPLEFT", self.addFilter, "TOPLEFT", 0, 0)
    K.Tooltip(self.input, ns.T("collectionAdd"), ns.T("collectionInputTip"))
    local function add()
        local text, item = self.input:GetText() or "", rawget(self.input, "item")
        if item and item.name == text then text = "item:" .. item.id end
        local ok, reason = ns.Collections.Add(text, self.props.mode)
        if not ok then ns.say(ns.Collections.Reason(reason), "bad"); return end
        self.input.item = nil
        self.input:SetText(""); self.input:ClearFocus(); self:Render()
    end
    self.input:SetScript("OnEnterPressed", add)
    self.add = K.Button(self.addFilter, ns.T("collectionAdd"), 84, add)
    self.add:SetPoint("LEFT", self.input, "RIGHT", 6, 0)
    K.Tooltip(self.add, ns.T("collectionAdd"), ns.T("collectionAddTip"))
    self.scan = K.ScanBarButton(f, {label = ns.T("collectionBar"), kind = "main", body = ns.T("collectionScanTip"),
        run = function(mode) ns.Collections.Scan(self.props.mode, mode); self:Render() end,
        sources = function() return ns.Collections.Targets(self.props.mode) end})
    self.barFrames = {self.scan}
    self.inspector = K.Inspector:New(f)
    self.table = K.Table:New(f, {
        headers = {{key = "item", text = "tradeItem"}, {key = "have", text = "colHave", sort = false}, {key = "gone", text = "colGone", sort = false, tip = "colGoneTip"},
            {key = "price", text = "tradeUnitPrice"}, {key = "margin", text = "familyMargin"}, {key = "units", text = "tradeUnits"}},
        columns = function(width, tbl) return K.MarketColumns(width - tbl:Row("row", 1):Reserve(), true) end,
        more = true,
        kinds = {row = {new = function(parent)
            local row = K.MarketRow:New(parent, function(id) self.selected = id; self:Render() end)
            row.frame:HookScript("OnReceiveDrag", function() self:DropCursor() end)
            return row
        end}},
        sort = {default = {key = "item", desc = false}},
        changed = function() self:Render() end,
        empty = "collectionEmpty",
    })
    local panel = self.inspector.body
    local priceLabel, observedLabel
    priceLabel, self.price = K.ValueRow(panel, ns.T("collectionPrice"), -48)
    observedLabel, self.observed = K.ValueRow(panel, ns.T("collectionObserved"), -70)
    self.labels = {priceLabel, observedLabel}
    self.summary = K.Label(panel, "", 12, -98, 240); self.summary:SetHeight(200); self.summary:SetJustifyV("TOP")
    self.band = K.ActionBand:For(self.inspector)
    local function drop() self:DropCursor() end
    for _, frame in ipairs({f, self.inspector.frame}) do
        frame:EnableMouse(true)
        frame:HookScript("OnReceiveDrag", drop)
        frame:HookScript("OnMouseUp", function() if CursorHasItem and CursorHasItem() then drop() end end)
    end
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render(); return self
end
