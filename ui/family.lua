local _, ns = ...
local UI = {props = {id = 36919, page = 1, days = 7}, rows = {}, groups = {}, opened = {[36919] = true},
    collapsed = {}, expansions = {wrath = true, bc = false}, batchState = {make = {}, ignore = {}, choice = {}, craftAll = false, owned = false}}
ns.FamilyUI = UI
function UI:SetProps(props)
    if props.family then
        self.opened[props.family] = true
        self.props.id = props.family
        self.focus = props.family
    end
    for key, value in pairs(props) do if key ~= "family" and key ~= "fee" then self.props[key] = value end end
    local family = ns.gemByItem[self.props.id]
    if family then self.opened[family.raw] = true end
    self:Render()
end
local function age(seconds)
    if not seconds then return ns.T("craftGroupNoScan") end
    if seconds >= 3600 then return ns.T("craftGroupAge", ns.T("deHours", math.floor(seconds / 3600))) end
    return ns.T("craftGroupAge", ns.T("tradeAge", math.floor(seconds / 60)))
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
        if self.expansions[group.expansion] then
            if H.IsGroup(group.key) then hidden[#hidden + 1] = {group = group}
            else
                lines[#lines + 1] = {group = group}
                if not self.collapsed[group.key] then
                    for _, recipe in ipairs(group.recipes or {}) do lines[#lines + 1] = {cooldown = recipe} end
                    for _, family in ipairs(ns.Collections.Order(group.families)) do
                        if H.Is(family.raw) then hidden[#hidden + 1] = {family = family}
                        else
                            lines[#lines + 1] = {family = family, group = group}
                            if self.opened[family.raw] then
                                local cuts = {}
                                for _, id in ipairs(family.members) do
                                    if id ~= family.raw and not H.Is(id) then cuts[#cuts + 1] = id end
                                end
                                cuts = self.sorter:Apply(cuts, {
                                    item = function(id) return ns.Markets.Name(id) end,
                                    price = function(id) local q = ns.Markets.Quote(id); return q and q.price end,
                                    margin = function(id) return F.Margin(id, fee) end,
                                    units = function(id) local q = ns.Markets.Quote(id); return q and q.units end,
                                })
                                for _, id in ipairs(cuts) do lines[#lines + 1] = {cut = id, family = family, group = group} end
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
    local families, known, total, best, units = 0, 0, 0, nil, 0
    for _, family in ipairs(group.families) do
        if not ns.Hidden.Is(family.raw) then
            families = families + 1
            local k, t = F.Learned(family)
            known, total = known + k, total + t
            local _, margin = F.Best(family, fee)
            if margin and (not best or margin > best) then best = margin end
            local q = ns.Markets.Quote(family.raw)
            units = units + (q and q.units or 0)
        end
    end
    return {key = group.key, width = width, open = not self.collapsed[group.key], name = groupName(group),
        detail = ns.T("craftGroupDetail", families, known, total, K.Money(best)) .. " | " .. age(F.GroupAge(group)),
        tip = ns.T("craftGroupTip"), columns = columns,
        cells = {margin = {best and K.Money(best) or nil, K.Tone(best)}, units = {units > 0 and tostring(units) or nil, "secondary"},
            state = {ns.T("craftLearned", known, total), "secondary"}},
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
        name = ns.T("jcCooldowns"), detail = ns.T("jcCooldownsDetail", #group.recipes, K.Money(best)),
        tip = ns.T("jcCooldownsTip"), columns = columns, cells = {margin = {best and K.Money(best) or nil, K.Tone(best)}},
        sources = function() return targets end, scanTip = ns.T("jcCooldownScanTip"), hideKey = group.key}
end
function UI:CooldownProps(recipe, width, fee)
    local K, F = ns.TradeKit, ns.Family
    local plan = ns.CraftPlan.Build(recipe, {fee = fee})
    local estimate = ns.Prospect.Estimate(recipe, nil, fee)
    local known = F.Known(recipe.raw)
    local state = known == true and "craftRecipeKnown" or (known == false and "craftRecipeUnknown" or "craftRecipeUnchecked")
    local detail = plan.revenue and ns.T("jcCooldownDetail", K.Money(plan.revenue))
        or ns.T("jcCooldownMissing", estimate.missing)
    return {id = recipe.raw, quality = 3, width = width, depth = 0, expandable = false,
        active = recipe.raw == self.props.id, detail = detail, price = plan.cost,
        margin = plan.margin, percent = plan.margin and plan.cost and plan.cost > 0 and plan.margin / plan.cost * 100 or nil,
        state = ns.T(state), unlearned = known == false,
        stateTone = known == true and "text" or (known == false and "off" or "secondary"),
        tip = ns.T("jcCooldownTip"),
        actions = {{label = ns.T("craftScanRow"), icon = "refresh", tip = ns.T("jcCooldownScanTip"),
                fn = function() ns.Crafting.Complete(recipe, K.ScanMode()); self:Render() end},
            {label = ns.T("hiddenHide"), icon = "hide", tip = ns.T("hiddenHideTip"),
                fn = function(id) ns.Hidden.Set(id, true); self:Render() end}}}
end
function UI:FamilyProps(family, width, fee, columns)
    local K, F = ns.TradeKit, ns.Family
    local raw = family.raw
    local q = ns.Markets.Quote(raw)
    local bestID, bestMargin = F.Best(family, fee)
    local known, total = F.Learned(family)
    local bestQuote = bestID and ns.Markets.Quote(bestID)
    local detail = ns.T("craftFamilyDetail", total, age(q and q.at and not q.vendor and math.max(0, time() - q.at) or nil))
    if not columns.best and bestID then
        detail = ns.T("craftBestCutRow", ns.Markets.Name(bestID), K.Money(bestQuote and bestQuote.price)) .. " | " .. detail
    end
    local actions = {{label = ns.T("craftScanRow"), icon = "refresh", tip = ns.T("craftScanFamilyTip"),
        fn = function(id) F.Complete(id, K.ScanMode()); self:Render() end},
        {label = ns.T("tradeBuy"), icon = "buy", tip = ns.T("craftBuyRaw"), fn = function(id) ns.Trader.OpenBuy(id) end},
        {label = ns.T("hiddenHide"), icon = "hide", tip = ns.T("hiddenHideTip"),
            fn = function(id) ns.Hidden.Set(id, true); self:Render() end}}
    return {id = raw, quality = family.quality, width = width, depth = 0, expandable = true, opened = self.opened[raw],
        active = raw == self.props.id, detail = detail, price = q and q.price, change = F.Change(raw),
        best = bestID, bestPrice = bestQuote and bestQuote.price, margin = bestMargin,
        percent = bestMargin and q and q.price and q.price > 0 and bestMargin / q.price * 100 or nil,
        units = q and q.units, state = ns.T("craftLearned", known, total),
        stateTone = total == 0 and "secondary" or (known == total and "text" or (known == 0 and "off" or "secondary")),
        tip = ns.T("craftLearnedTip"), actions = actions}
end
function UI:CutProps(id, family, width, fee)
    local K, F = ns.TradeKit, ns.Family
    local q, raw = ns.Markets.Quote(id), ns.Markets.Quote(family.raw)
    local margin, known = F.Margin(id, fee), F.Known(id)
    local state = known == true and "craftRecipeKnown" or (known == false and "craftRecipeUnknown" or "craftRecipeUnchecked")
    return {id = id, quality = family.quality, width = width, depth = 1, expandable = false,
        active = id == self.props.id, detail = ns.T(state), price = q and q.price, change = F.Change(id),
        margin = margin, percent = margin and raw and raw.price and raw.price > 0 and margin / raw.price * 100 or nil,
        units = q and q.units, state = ns.T(state), unlearned = known == false,
        stateTone = known == true and "text" or (known == false and "off" or "secondary"),
        actions = {{label = ns.T("craftScanRow"), icon = "refresh", tip = ns.T("craftScanRowTip"),
                fn = function(item) ns.Batch.Complete({item}, K.ScanMode()); self:Render() end},
            {label = ns.T("hiddenHide"), icon = "hide", tip = ns.T("hiddenHideTip"),
                fn = function(item) ns.Hidden.Set(item, true); self:Render() end}}}
end
function UI:Render()
    if not self.frame then return end
    local K, p, F = ns.TradeKit, self.props, ns.Family
    local width = K.CraftLayout(self, -42, 60)
    local columns = K.CraftColumns(width)
    K.PlaceHeaders(self.headers, columns, self.frame, -40, true)
    self.sorter:Mark()
    self.tableWidth = width
    local counts = {}
    for _, family in ipairs(ns.gemFamilies) do
        local key = family.expansion or "wrath"
        counts[key] = (counts[key] or 0) + 1
    end
    self.epochs:SetProps({shown = self.expansions, counts = counts, tip = function() return ns.T("familyEpochTip") end})
    local lines, hidden = self:Lines(ns.Fee())
    if self.focus then
        for i, line in ipairs(lines) do
            if line.family and line.family.raw == self.focus and not line.hidden then self.scroll.offset = i - 1; break end
        end
        self.focus = nil
    end
    local visible = K.ListCapacity(self.frame, 62, 60, 30, #self.rows + #self.groups)
    local offset = self.scroll:SetRange(#lines, visible)
    local usedRows, usedGroups = 0, 0
    self.spoiler:Hide()
    for i = 1, visible do
        local line = lines[offset + i]
        local y = -62 - (i - 1) * 30
        if line and line.spoiler then
            self.spoiler:ClearAllPoints(); self.spoiler:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, y)
            self.spoiler:SetWidth(width); self.spoiler:SetHeight(28)
            self.spoiler:SetText(ns.T(self.showHidden and "hiddenSpoilerOpen" or "hiddenSpoilerClosed", line.count))
            self.spoiler:Show()
        elseif line and line.group and not line.family and not line.cut then
            usedGroups = usedGroups + 1
            local header = self.groups[usedGroups]
            if header then
                header.frame:ClearAllPoints(); header.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, y)
                local props = self:GroupProps(line.group, width, ns.Fee(), columns)
                if line.hidden then props.open, props.hidden = true, true end
                header:SetProps(props)
            end
        elseif line then
            usedRows = usedRows + 1
            local row = self.rows[usedRows]
            if row then
                row.frame:ClearAllPoints(); row.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, y)
                local props = line.cut and self:CutProps(line.cut, line.family, width, ns.Fee())
                    or line.cooldown and self:CooldownProps(line.cooldown, width, ns.Fee())
                    or self:FamilyProps(line.family, width, ns.Fee(), columns)
                if line.hidden then
                    props.expandable, props.opened = false, false
                    props.detail = props.detail .. ns.T("hiddenRowNote")
                    props.actions = {{label = ns.T("hiddenRestore"), tip = ns.T("hiddenRestoreTip"),
                        fn = function(id) ns.Hidden.Set(id, false); self:Render() end}}
                end
                row:SetProps(props)
            end
        end
    end
    for i = usedRows + 1, #self.rows do self.rows[i].frame:Hide() end
    for i = usedGroups + 1, #self.groups do self.groups[i].frame:Hide() end
    self.inspector:SetProps({id = p.id})
    self.current:SetWidth(self.inspector.frame:GetWidth() - 24)
    local q = ns.Markets.Quote(p.id)
    self.current:SetText(ns.T("familyCurrentPrice", K.Money(q and q.price)) .. " | " .. F.Recipe(p.id))
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
    local recipe, cut = self:BatchRecipe(self.props.id)
    local state, policy = self.batchState, ns.ReagentPolicy.Get()
    state.craftAll, state.owned = policy.craftAll, policy.owned
    self.batch:SetProps({recipe = recipe, options = state, known = cut and ns.Family.Known(cut) or nil,
        note = recipe and recipe.noteKey and ns.T(recipe.noteKey) or nil,
        change = function(key, value, id)
            if key == "make" then state.make[id] = value; if state.choice then state.choice[id] = nil end
            elseif key == "ignore" then state.ignore[id] = value or nil
            elseif key == "choice" or key == "craftAll" or key == "owned" then
                if key ~= "choice" then ns.ReagentPolicy.Set(key, value) end
                if key ~= "owned" and state.choice then for chosen in pairs(state.choice) do state.choice[chosen] = nil end end
            elseif key ~= "price" then state[key] = value end
            self:Render()
        end,
        reagent = {open = function(id) ns.Trader.OpenReagent(id) end},
        buy = function(id, need) ns.Trader.OpenBuy(id, need); return ns.Trader.section == "buy" end})
end
function UI:Controls()
    if not self.scan then return end
    if ns.Scan.state.phase == "idle" and not ns.Buy.Active() then self.scan:Enable() else self.scan:Disable() end
    if self.batch then self.batch:Controls() end
end
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent)
    local f = self.frame
    f:SetAllPoints(parent)
    self.epochs = K.EpochChips:New(f, {"wrath", "bc"}, function(key, checked)
        self.expansions[key] = checked; self.scroll.offset = 0; self:Render()
    end, ns.T("craftBCTip"))
    self.scan = K.Button(f, ns.T("craftListScan"), 170, function()
        ns.Family.CompleteAll(self.expansions, K.ScanMode()); self:Render()
    end, "main")
    self.scan:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -282, 4)
    K.ScanTip(self.scan, ns.T("craftListScan"), ns.T("familyScanAllTip"), function()
        return ns.Family.AllSources(self.expansions)
    end)
    self.headerBand = K.TableHeader(f, -42)
    self.headers = {}
    for _, entry in ipairs({{"item", "craftColGem"}, {"price", "craftColPrice"}, {"best", "craftBestCut"},
        {"margin", "familyMargin"}, {"units", "craftColSupply"}, {"state", "craftColRecipes"}}) do
        local label = K.Label(f, ns.T(entry[2]), 0, -40, 100)
        label:SetHeight(12)
        if entry[1] ~= "item" and entry[1] ~= "best" then label:SetJustifyH("RIGHT") end
        self.headers[entry[1]] = label
    end
    self.sorter = K.Sorter(f, self.headers, function() self:Render() end, nil, {key = "margin", desc = true})
    self.scroll = K.TableScroll(f, function() self:Render() end, 62, 60, 30)
    for i = 1, 40 do
        local row = K.CraftRow:New(f, function(id) self:SetProps({id = id}) end, function(id) self:ToggleFamily(id) end)
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -62 - (i - 1) * 30)
        row.frame:Hide()
        self.rows[i] = row
        self.scroll:Wheel(row.frame)
    end
    for i = 1, 8 do
        local header = K.GroupRow:New(f, function(key) self:ToggleGroup(key) end, function() self:Render() end)
        header.frame:Hide(); self.scroll:Wheel(header.frame); self.groups[i] = header
    end
    self.spoiler = K.Button(f, "", 400, function() self.showHidden = not self.showHidden; self:Render() end, "quiet")
    self.spoiler.text:ClearAllPoints(); self.spoiler.text:SetPoint("LEFT", self.spoiler, "LEFT", 10, 0)
    self.spoiler:Hide()
    K.Tooltip(self.spoiler, ns.T("hiddenSection"), ns.T("hiddenSpoilerTip"))
    self.buy = K.Button(f, ns.T("tradeBuy"), 84, function() ns.Trader.OpenBuy(self.props.id) end)
    self.buy:SetPoint("RIGHT", self.scan, "LEFT", -6, 0)
    self.inspector = K.Inspector:New(f)
    local h = self.inspector.body
    self.historyItem = self.inspector.item
    self.history = h
    self.current = K.Label(h, "", 12, -44, 240, "secondary")
    self.current:SetHeight(12)
    self.batch = K.BatchPanel:New(h)
    self.inspector:SetInfo(ns.T("batchTitle"), ns.T("batchTip"))
    self.batch.frame:SetPoint("TOPLEFT", h, "TOPLEFT", 12, -62)
    self.batch.frame:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -6, 8)
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
