local _, ns = ...
local UI = {props = {id = 36919, page = 1, days = 7}, opened = {[36919] = true},
    collapsed = {}, expansions = {wrath = true, bc = false}, batchState = {make = {}, ignore = {}, choice = {}, craftAll = false, owned = false}}
ns.FamilyUI = UI
function UI.Filters()
    local db = ns.Store.DB()
    if type(db.listFilters) ~= "table" then db.listFilters = {} end
    if type(db.listFilters.jewelry) ~= "table" then db.listFilters.jewelry = {} end
    return db.listFilters.jewelry
end
function UI.ShowUnlearned()
    return UI.Filters().unlearned ~= false
end
function UI.SplitLearned(ids, known)
    local learned, unlearned = {}, {}
    for _, id in ipairs(ids) do
        if known(id) == false then unlearned[#unlearned + 1] = id else learned[#learned + 1] = {id = id} end
    end
    if UI.ShowUnlearned() then
        for i, id in ipairs(unlearned) do learned[#learned + 1] = {id = id, divider = i == 1 and #learned > 0} end
    end
    return learned
end
function UI:SetProps(props)
    if props.family then
        self.opened[props.family] = true
        self.props.id = props.family
        self.focus = props.family
    end
    for key, value in pairs(props) do if key ~= "family" and key ~= "fee" then self.props[key] = value end end
    local family = ns.gemByItem[self.props.id]
    if family and family.raw ~= self.props.id then self.opened[family.raw] = true end
    self:Render()
end
local function age(seconds)
    if not seconds then return ns.T("craftGroupNoScan") end
    return ns.T("craftScanAgo", ns.TradeKit.Ago(seconds))
end
local function pinnedFirst(families)
    local result = {}
    for _, family in ipairs(families) do if ns.Collections.IsPinned("jewelry", family.raw) then result[#result + 1] = family end end
    for _, family in ipairs(families) do if not ns.Collections.IsPinned("jewelry", family.raw) then result[#result + 1] = family end end
    return result
end
function UI:Lines(fee)
    local F, H = ns.Family, ns.Hidden
    local lines, hidden = {}, {}
    local groups = F.Groups()
    local cooldowns = F.Cooldowns(self.expansions)
    if #cooldowns > 0 then
        local at = 1
        for i, group in ipairs(groups) do if group.expansion == "wrath" then at = i + 1 end end
        table.insert(groups, at, {key = "cooldowns", expansion = "wrath", families = {}, recipes = cooldowns})
    end
    for _, recipe in ipairs(ns.jewelcraftingRecipes or {}) do
        if self.expansions[recipe.expansion or "wrath"] and H.Is(recipe.raw) then hidden[#hidden + 1] = {cooldown = recipe} end
    end
    for _, group in ipairs(groups) do
        if self.expansions[group.expansion] and ns.Family.QualityShown(group.quality or 3) then
            if H.IsGroup(group.key) then hidden[#hidden + 1] = {group = group}
            else
                lines[#lines + 1] = {group = group}
                if not self.collapsed[group.key] then
                    local byRaw, raws = {}, {}
                    for _, recipe in ipairs(group.recipes or {}) do byRaw[recipe.raw] = recipe; raws[#raws + 1] = recipe.raw end
                    for _, entry in ipairs(UI.SplitLearned(raws, F.Known)) do
                        lines[#lines + 1] = {cooldown = byRaw[entry.id], divider = entry.divider}
                    end
                    for _, family in ipairs(pinnedFirst(group.families)) do
                        if H.Is(family.raw) then hidden[#hidden + 1] = {family = family}
                        else
                            lines[#lines + 1] = {family = family, group = group}
                            if self.opened[family.raw] then
                                local cuts = {}
                                for _, id in ipairs(family.members) do
                                    if id ~= family.raw and not H.Is(id) then cuts[#cuts + 1] = id end
                                end
                                cuts = self.table.sorter:Apply(cuts, {
                                    item = function(id) return ns.Markets.Name(id) end,
                                    price = function(id) local q = ns.Markets.Quote(id); return q and q.price end,
                                    margin = function(id) return F.Margin(id, fee) end,
                                    units = function(id) local q = ns.Markets.Quote(id); return q and q.units end,
                                })
                                for _, entry in ipairs(UI.SplitLearned(cuts, F.Known)) do
                                    lines[#lines + 1] = {cut = entry.id, family = family, group = group, divider = entry.divider}
                                end
                                for _, id in ipairs(family.members) do
                                    if id ~= family.raw and H.Is(id) then hidden[#hidden + 1] = {cut = id, family = family} end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if #hidden > 0 then
        lines[#lines + 1] = {spoiler = true, count = #hidden}
        if self.showHidden then for _, entry in ipairs(hidden) do entry.hidden = true; lines[#lines + 1] = entry end end
    end
    return lines, hidden
end
function UI:ToggleGroup(key)
    self.collapsed[key] = not self.collapsed[key] or nil
    self:Render()
end
function UI:ToggleFamily(raw)
    self.opened[raw] = not self.opened[raw] or nil
    self:Render()
end
local function groupName(group)
    return ns.T("craftGroupName", ns.T(group.expansion == "bc" and "craftBC" or "craftWrath"),
        ns.T("familyQuality" .. group.quality))
end
ns.Hidden.Describe(function(key)
    if key == "cooldowns" then return {name = ns.T("jcCooldowns"), place = ns.T("jewelrySection")} end
    local group = ns.Family.Group(key)
    return group and {name = groupName(group), place = ns.T("jewelrySection")} or nil
end)
function UI:GroupProps(group, width, fee, columns)
    local K, F = ns.TradeKit, ns.Family
    if group.recipes then return self:CooldownGroupProps(group, width, fee, columns) end
    local known, total, best, units = 0, 0, nil, 0
    for _, family in ipairs(group.families) do
        if not ns.Hidden.Is(family.raw) then
            local k, t = F.Learned(family)
            known, total = known + k, total + t
            local _, margin = F.Best(family, fee)
            if margin and (not best or margin > best) then best = margin end
            local q = ns.Markets.Quote(family.raw)
            units = units + (q and q.units or 0)
        end
    end
    return {key = group.key, width = width, open = not self.collapsed[group.key], name = groupName(group),
        detail = K.Details({ns.T("craftGroupDetail", known, total), age(F.GroupAge(group))}),
        tip = ns.T("craftGroupTip"), columns = columns,
        cells = {margin = {best and K.Money(best) or nil, K.Tone(best)}, units = {units > 0 and tostring(units) or nil, "secondary"}},
        sources = function() return F.GroupSources(group.key) end, scanTip = ns.T("craftScanGroupTip"),
        hideKey = group.key}
end
function UI:CooldownGroupProps(group, width, fee, columns)
    local K = ns.TradeKit
    local targets, best = {}, nil
    for _, recipe in ipairs(group.recipes) do
        for _, id in ipairs(ns.Crafting.Targets(recipe)) do targets[#targets + 1] = id end
        local margin = ns.CraftPlan.Build(recipe, {fee = fee}).margin
        if margin and (not best or margin > best) then best = margin end
    end
    return {key = group.key, width = width, open = not self.collapsed[group.key],
        name = ns.T("jcCooldowns"), detail = ns.T("jcCooldownsDetail", #group.recipes),
        tip = ns.T("jcCooldownsTip"), columns = columns, cells = {margin = {best and K.Money(best) or nil, K.Tone(best)}},
        sources = function() return targets end, scanTip = ns.T("jcCooldownScanTip"), hideKey = group.key}
end
function UI:CooldownProps(recipe, width, fee)
    local K, F = ns.TradeKit, ns.Family
    local plan = ns.CraftPlan.Build(recipe, {fee = fee})
    local estimate = ns.Prospect.Estimate(recipe, nil, fee)
    local known = F.Known(recipe.raw)
    local detail = plan.revenue and ns.T("jcCooldownDetail", K.Money(plan.revenue))
        or ns.T("jcCooldownMissing", estimate.missing)
    return {id = recipe.raw, quality = 3, width = width, depth = 0, expandable = false,
        active = recipe.raw == self.props.id, detail = detail, price = plan.cost,
        margin = plan.margin, percent = plan.margin and plan.cost and plan.cost > 0 and plan.margin / plan.cost * 100 or nil,
        unlearned = known == false, tip = ns.T("jcCooldownTip"),
        actions = {{label = ns.T("craftScanRow"), icon = "refresh", tip = ns.T("jcCooldownScanTip"),
                fn = function() ns.Crafting.Complete(recipe, K.ScanMode()); self:Render() end},
            {label = ns.T("hiddenHide"), icon = "hide", tip = ns.T("hiddenHideTip"),
                fn = function(id) ns.Hidden.Set(id, true); self:Render() end}}}
end
function UI:FamilyProps(family, width, fee, columns)
    local K, F = ns.TradeKit, ns.Family
    local raw = family.raw
    local q = ns.Markets.Quote(raw)
    local _, bestMargin, fallback = F.Best(family, fee)
    local known, total = F.Learned(family)
    local detail = ns.T("craftFamilyLearned", known, total, age(q and q.at and not q.vendor and math.max(0, time() - q.at) or nil))
    local actions = {{label = ns.T("craftScanRow"), icon = "refresh", tip = ns.T("craftScanFamilyTip"),
        sources = function() return {{family = family.raw}} end,
        fn = function(id) F.Complete(id, K.ScanMode()); self:Render() end},
        {label = ns.T("tradeToBuy"), icon = "buy", tip = ns.T("craftBuyRaw"), fn = function(id) ns.Trader.OpenBuy(id) end},
        {label = ns.T("hiddenHide"), icon = "hide", tip = ns.T("hiddenHideTip"),
            fn = function(id) ns.Hidden.Set(id, true); self:Render() end}}
    return {id = raw, quality = family.quality, width = width, depth = 0, expandable = true, opened = self.opened[raw],
        pinnable = true, pinned = ns.Collections.IsPinned("jewelry", raw),
        active = raw == self.props.id, detail = detail, price = q and q.price, change = F.Change(raw),
        margin = bestMargin, marginTone = fallback and bestMargin and "off" or nil,
        percent = bestMargin and q and q.price and q.price > 0 and bestMargin / q.price * 100 or nil,
        units = q and q.units, tip = ns.T("craftLearnedTip"), actions = actions}
end
function UI:CutProps(id, family, width, fee)
    local K, F = ns.TradeKit, ns.Family
    local q, raw = ns.Markets.Quote(id), ns.Markets.Quote(family.raw)
    local margin, known = F.Margin(id, fee), F.Known(id)
    local gem = ns.searchGems and ns.searchGems[id]
    return {id = id, quality = family.quality, width = width, depth = 1, expandable = false,
        active = id == self.props.id, detail = gem and ns.Search.Bonus(gem) or "", price = q and q.price, change = F.Change(id),
        margin = margin, percent = margin and raw and raw.price and raw.price > 0 and margin / raw.price * 100 or nil,
        units = q and q.units, unlearned = known == false, favorite = ns.Collections.Favorite(id),
        actions = {{label = ns.T("craftScanRow"), icon = "refresh", tip = ns.T("craftScanRowTip"),
                fn = function(item) ns.Batch.Complete({item}, K.ScanMode()); self:Render() end},
            {label = ns.T("hiddenHide"), icon = "hide", tip = ns.T("hiddenHideTip"),
                fn = function(item) ns.Hidden.Set(item, true); self:Render() end}}}
end
function UI:Render()
    if not self.frame then return end
    local p = self.props
    ns.TradeKit.ScreenBody(self.table, self.inspector)
    local counts = {}
    for _, family in ipairs(ns.gemFamilies) do
        local key = family.expansion or "wrath"
        counts[key] = (counts[key] or 0) + 1
    end
    self.epochs:SetProps({shown = self.expansions, counts = counts, tip = function() return ns.T("familyEpochTip") end})
    self.quality:SetState(UI.Filters().quality or {}, 0)
    local fee = ns.Fee()
    local lines = self:Lines(fee)
    local reveal
    for i, line in ipairs(lines) do
        line.kind = line.spoiler and "spoiler" or line.group and not line.family and "group" or "row"
        line.depth = line.cut and 1 or 0
        line.tree = line.family and not line.cut and not line.hidden
        if self.focus and line.family and not line.cut and line.family.raw == self.focus and not line.hidden then reveal = i end
    end
    self.focus = nil
    self.table:SetLines(lines, function(line, width, columns)
        if line.spoiler then return {count = line.count, open = self.showHidden} end
        if line.kind == "group" then
            local props = self:GroupProps(line.group, width, fee, columns)
            if line.hidden then props.open, props.hidden = true, true end
            return props
        end
        local props = line.cut and self:CutProps(line.cut, line.family, width, fee)
            or line.cooldown and self:CooldownProps(line.cooldown, width, fee)
            or self:FamilyProps(line.family, width, fee, columns)
        if line.hidden then
            props.expandable, props.opened = false, false
            props.detail = props.detail .. ns.T("hiddenRowNote")
            props.actions = {{label = ns.T("hiddenRestore"), tip = ns.T("hiddenRestoreTip"),
                fn = function(id) ns.Hidden.Set(id, false); self:Render() end}}
        end
        return props
    end, {reveal = reveal, align = true})
    self.inspector:SetProps({id = p.id})
    self:RenderBatch()
    self:Controls()
end
function UI:BatchRecipe(id)
    local cooldown = ns.Family.Cooldown(id)
    if cooldown then return cooldown, cooldown.raw end
    local family = ns.gemByItem[id]
    if not family then return nil end
    local cut = id ~= family.raw and id or ns.Family.Best(family, ns.Fee())
    if not cut then
        for _, member in ipairs(family.members) do
            if member ~= family.raw and ns.Family.Known(member) ~= false and not ns.Hidden.Is(member) then cut = member; break end
        end
    end
    if not cut then return nil end
    return {raw = cut, count = 1, inputs = {{family.raw, 1}}, spell = family.spells[cut], category = "jewelrySection"}, cut
end
function UI:RenderBatch()
    local id = self.props.id
    local family = id and ns.gemByItem[id]
    if family and family.raw == id and not ns.Family.Cooldown(id) then
        self.batch:SetProps({})
        self.obtain:SetProps({id = id})
        return
    end
    self.obtain:SetProps({})
    local recipe, cut = self:BatchRecipe(id)
    local state, policy = self.batchState, ns.ReagentPolicy.Get()
    state.craftAll, state.owned = policy.craftAll, policy.owned
    self.batch:SetProps({recipe = recipe, options = state, known = cut and ns.Family.Known(cut) or nil,
        header = self.props.id,
        note = recipe and recipe.noteKey and ns.T(recipe.noteKey) or nil,
        scan = recipe and {run = function() ns.Crafting.Complete(recipe, ns.TradeKit.ScanMode(), state); self:Render() end,
            sources = function() return ns.Crafting.RecipeSources(recipe, state) end} or nil,
        change = function(key, value, id)
            if key == "make" then state.make[id] = value; if state.choice then state.choice[id] = nil end
            elseif key == "ignore" then state.ignore[id] = value or nil
            elseif key == "choice" or key == "craftAll" or key == "owned" then
                if key ~= "choice" then ns.ReagentPolicy.Set(key, value) end
                if key ~= "owned" and state.choice then for chosen in pairs(state.choice) do state.choice[chosen] = nil end end
            elseif key ~= "price" then state[key] = value end
            self:Render()
        end})
end
function UI:Bar()
    return self.barFrames
end
function UI:Controls()
    if not self.scan then return end
    self.scan:SetBusy(ns.Trader.Busy() and ns.T("batchBusy") or nil)
    if self.batch then self.batch:Controls() end
    if self.obtain then self.obtain:Controls() end
end
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent)
    local f = self.frame
    f:SetAllPoints(parent)
    self.epochs = K.EpochChips:New(f, {"wrath", "bc"}, function(key, checked)
        self.expansions[key] = checked; self.table:ResetScroll(); self:Render()
    end, ns.T("craftBCTip"))
    self.learnedFilter = K.Switch(f, ns.T("craftUnlearnedSwitch"), function(on)
        UI.Filters().unlearned = on; self:Render()
    end)
    self.learnedFilter:SetChecked(UI.ShowUnlearned())
    K.Tooltip(self.learnedFilter, ns.T("craftUnlearnedSwitch"), ns.T("craftUnlearnedSwitchTip"))
    self.scan = K.ScanBarButton(f, {label = ns.T("craftBarGems"),
        run = function(mode)
            ns.Family.CompleteAll(self.expansions, mode); self:Render()
        end,
        sources = function() return ns.Family.AllSources(self.expansions) end,
        body = ns.T("familyScanAllTip")})
    self.scan.tipTitle = ns.T("craftListScan")
    self.barFrames = {self.scan}
    self.quality = K.QualityToggles:New(f, {2, 3, 4}, function(quality)
        local filters = UI.Filters()
        if type(filters.quality) ~= "table" then filters.quality = {} end
        if filters.quality[quality] == false then filters.quality[quality] = nil else filters.quality[quality] = false end
        self.table:ResetScroll(); self:Render()
    end)
    self.head = {filters = {self.epochs.frame, self.learnedFilter, self.quality.frame}}
    self.table = K.Table:New(f, {
        headers = {{key = "item", text = "craftColGem"}, {key = "price", text = "craftColPrice"},
            {key = "margin", text = "familyMargin"}, {key = "units", text = "craftColSupply"}},
        columns = K.CraftColumns,
        kinds = {
            row = {new = function(parent)
                return K.CraftRow:New(parent, function(id) self:SetProps({id = id}) end, function(id) self:ToggleFamily(id) end,
                    function(id)
                        if not ns.Collections.TogglePin("jewelry", id) then ns.say(ns.T("craftPinLimit", ns.Collections.PIN_MAX), "bad") end
                        self:Render()
                    end)
            end},
            group = {new = function(parent)
                return K.GroupRow:New(parent, function(key) self:ToggleGroup(key) end, function() self:Render() end)
            end},
        },
        spoiler = {toggle = function() self.showHidden = not self.showHidden; self:Render() end},
        sort = {default = {key = "margin", desc = true}},
        changed = function() self:Render() end,
        empty = "familyTableEmpty",
    })
    self.inspector = K.Inspector:New(f)
    self.historyItem = self.inspector.item
    self.batch = K.BatchPanel:New(self.inspector, "ManaCodeJewelryBatchScroll")
    self.obtain = K.ObtainPanel:New(self.inspector, "ManaCodeJewelryObtainScroll")
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
