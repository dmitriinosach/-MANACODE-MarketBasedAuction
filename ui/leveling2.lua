local _, ns = ...
local UI = {props = {profession = "tailoring"}, kind = "cheap", selected = 1, states = {}}
ns.Leveling2UI = UI
local REAGENTS = 10
function UI.Line(profession)
    if profession == "jewelry" then return ns.T("jewelrySection") end
    local catalog = ns.craftCatalogs[profession]
    return catalog and ns.T(catalog.labelKey) or profession
end
function UI.Rank(profession)
    for _, owner in ipairs(ns.Recipes.Professions()[UI.Line(profession)] or {}) do
        if owner.me then return owner.rank end
    end
end
function UI.RodTier()
    local tools = ns.levelingRods or {}
    for tier = #tools, 1, -1 do
        if (GetItemCount(tools[tier].item, true) or 0) > 0 then return tier end
    end
    return 0
end
function UI.Rate()
    local rates = ns.Store.DB().levelingRate
    return ns.LevelingPaths.Rate(type(rates) == "table" and rates[GetRealmName() or ""] or 1)
end
function UI.SetRate(rate)
    local db = ns.Store.DB()
    rate = ns.LevelingPaths.Rate(rate)
    if type(db.levelingRate) ~= "table" then db.levelingRate = {} end
    db.levelingRate[GetRealmName() or ""] = rate > 1 and rate or nil
    if not next(db.levelingRate) then db.levelingRate = nil end
end
function UI.Resale()
    return ns.Store.DB().levelingResale == true
end
function UI:Options()
    local p, line = self.props, UI.Line(self.props.profession)
    return {profession = p.profession, first = p.first or 1, target = p.target or 450, rate = UI.Rate(), resale = UI.Resale(),
        faction = UnitFactionGroup("player"), rodTier = p.profession == "enchanting" and UI.RodTier() or 0,
        known = function(spell) return ns.Recipes.Known(spell, line) end,
        owned = function(id) return GetItemCount(id, true) or 0 end}
end
function UI:ScanOptions()
    local options = ns.LevelingPaths.Options(self:Options())
    local rank = UI.Rank(options.profession)
    if rank and rank >= options.target then return nil end
    options.first = math.max(options.first, rank or 0)
    return options
end
function UI:ScanTargets()
    local options = self:ScanOptions()
    return options and ns.LevelingPaths.Targets(options) or {}
end
function UI:SetProps(props)
    local profession = props.profession or self.props.profession
    if profession ~= self.props.profession then
        self.states[self.props.profession] = {props = self.props, kind = self.kind, selected = self.selected, picked = self.picked, chosen = self.chosen}
        local state = self.states[profession] or {props = {profession = profession}, kind = "cheap", selected = 1}
        self.props, self.kind, self.selected, self.picked, self.centered = state.props, state.kind, state.selected, state.picked, nil
        self.chosen = state.chosen
    end
    for key, value in pairs(props) do self.props[key] = value end
    self.signature = nil
    self:Render()
end
function UI.Join(below, above, rank)
    if not above then return below end
    if not below then
        local path = {}
        for key, value in pairs(above) do path[key] = value end
        path.left = above.cost
        return path
    end
    local segments = {}
    for _, segment in ipairs(below.segments) do segments[#segments + 1] = segment end
    for _, segment in ipairs(above.segments) do segments[#segments + 1] = segment end
    return {segments = segments, crafts = below.crafts + above.crafts, resale = below.resale + above.resale,
        materials = below.materials + above.materials, acquire = below.acquire + above.acquire,
        cost = below.cost and below.reached >= rank and below.cost + above.cost or nil, left = above.cost,
        reached = above.reached, rods = above.rods, complexity = above.complexity, remainingStock = above.remainingStock}
end
function UI.Passed(options)
    local plan = ns.LevelingPaths.Plan(options)
    if plan.cheap and plan.cheap.reached >= options.target then return plan end
    local blind = {}
    for k, v in pairs(options) do blind[k] = v end
    blind.blind = true
    local passed = ns.LevelingPaths.Plan(blind)
    if not passed.cheap then return plan end
    passed.missing = plan.missing
    return passed
end
function UI.Extend(path, options, rank)
    if not path or path.reached >= options.target then return path end
    local rest = {}
    for k, v in pairs(options) do rest[k] = v end
    rest.first, rest.blind = path.reached, true
    rest.owned = function(id)
        local count
        if not rank or path.reached > rank then count = path.remainingStock and path.remainingStock[id] end
        if count ~= nil then return count end
        return options.owned and options.owned(id)
    end
    local tail = ns.LevelingPaths.Plan(rest).cheap
    if not tail then return path end
    local out = {}
    for k, v in pairs(path) do out[k] = v end
    out.segments = {}
    for _, list in ipairs({path.segments, tail.segments}) do
        for _, segment in ipairs(list) do out.segments[#out.segments + 1] = segment end
    end
    return out
end
function UI:Model()
    local options = self:Options()
    local rank = UI.Rank(options.profession)
    local parts = {options.profession, options.first, options.target, options.rodTier, options.rate, tostring(options.resale),
        rank or 0, ns.Inventory.version, ns.Recipes.version, math.floor(time() / 60)}
    for _, id in ipairs(ns.LevelingPaths.Targets(options)) do
        local q = ns.Markets.Quote(id)
        parts[#parts + 1] = q and (tostring(q.price) .. ":" .. tostring(q.lots) .. ":" .. tostring(q.at)) or "-"
    end
    local key = table.concat(parts, "|")
    if key ~= self.signature or not self.plan then
        self.signature = key
        if self.plan and self.plan.options.profession == options.profession and self.plan.rank ~= rank then
            self.picked, self.chosen = nil, nil
        end
        if rank and rank >= options.target then
            local history = {}
            for k, v in pairs(options) do history[k] = v end
            history.owned = nil
            local done = UI.Passed(history)
            self.plan = {options = options, rank = rank, reached = done.reached, missing = {},
                cheap = done.cheap and UI.Join(done.cheap, nil, rank) or nil}
        elseif rank and rank > options.first then
            local low, high = {}, {}
            for k, v in pairs(options) do low[k], high[k] = v, v end
            low.target, low.owned, high.first = rank, nil, rank
            local below, above = UI.Passed(low), ns.LevelingPaths.Plan(high)
            local missing, seen = {}, {}
            for _, list in ipairs({above.missing, below.missing}) do
                for _, id in ipairs(list) do if not seen[id] then seen[id] = true; missing[#missing + 1] = id end end
            end
            self.plan = {options = options, rank = rank, reached = above.reached, missing = missing,
                cheap = UI.Join(below.cheap, above.cheap, rank),
                simple = above.simple and UI.Join(below.cheap, above.simple, rank) or nil}
        else
            self.plan = ns.LevelingPaths.Plan(options)
            if not self.plan.cheap then self.plan.cheap = UI.Passed(options).cheap end
        end
        self.plan.cheap, self.plan.simple = UI.Extend(self.plan.cheap, options, rank), UI.Extend(self.plan.simple, options, rank)
    end
    return self.plan
end
function UI:Pick(index)
    if IsShiftKeyDown() then
        self.chosen = {}
        for i = math.min(self.selected, index), math.max(self.selected, index) do self.chosen[i] = true end
    elseif IsControlKeyDown() then
        local set = self.chosen or {[self.selected] = true}
        if set[index] then set[index] = nil else set[index] = true end
        if next(set) then
            if set[index] then self.selected = index
            elseif not set[self.selected] then
                for i in pairs(set) do if not set[self.selected] or i < self.selected then self.selected = i end end
            end
            self.chosen = set
        else self.selected, self.chosen = index, nil end
    else self.selected, self.chosen = index, nil end
    self.picked = true
    self:Render()
end
function UI:Path()
    local plan = self.plan
    if not plan then return nil end
    return self.kind == "simple" and plan.simple or plan.cheap
end
local function source(segment)
    local K, r = ns.TradeKit, segment.recipe
    local known = ns.Recipes.Known(r.spell, UI.Line(UI.props.profession))
    if known then return ns.T("level2Known") end
    local way
    if r.source == "vendor" then way = ns.T("level2Vendor", K.Money(segment.acquire))
    elseif r.source == "token" then way = ns.T("level2Token")
    elseif r.source == "auction" then way = segment.blind and ns.T("level2AuctionNoPrice") or ns.T("level2Auction", K.Money(segment.acquire))
    elseif segment.acquire > 0 then way = ns.T("level2Trainer", K.Money(segment.acquire))
    else way = ns.T("level2Free") end
    return ns.T(known == false and "level2NotKnown" or "level2Unchecked", way)
end
function UI.SegmentTip(segment)
    local K, r = ns.TradeKit, segment.recipe
    return ns.T("level2SegmentTip", segment.first, segment.target, ns.Decimal(segment.crafts, 1), r.req, r.yellow,
        math.floor((r.yellow + r.gray) / 2), r.gray, segment.cost and K.Money(segment.cost) or ns.T("level2NoPrice"),
        source(segment))
end
function UI:Bar()
    return self.barFrames
end
function UI:Controls()
    if not self.frame then return end
    local options = self:ScanOptions()
    local label = options and ns.T("level2BarFrom", options.first) or ns.T("level2BarPath")
    local range = options and table.concat({options.profession, options.first, options.target, tostring(options.resale),
        ns.Recipes.version}, ":")
    if label ~= self.scan:GetText() then
        self.scan:SetText(label)
        ns.TradeKit.FitButton(self.scan, 20)
    end
    self.scan:SetBusy(ns.Trader.Busy() and ns.T("batchBusy") or not options and ns.T("level2ScanDone") or nil)
    if self.scanRange ~= range then
        self.scanRange, self.scan.scanDirty = range, true
        ns.TradeKit.RefreshTip(self.scan)
    end
    self:BuyState()
end
function UI:Render()
    if not self.frame or not self.frame:IsVisible() then return end
    local K, plan = ns.TradeKit, self:Model()
    local options = plan.options
    self.resale:SetChecked(options.resale)
    for edit, value in pairs({[self.first] = options.first, [self.target] = options.target, [self.rate] = options.rate}) do
        if not edit:HasFocus() then edit:SetText(tostring(value)) end
    end
    if not plan.simple and self.kind == "simple" then self.kind = "cheap" end
    local path = self:Path()
    local rank = UI.Rank(options.profession)
    local panel = self.panel
    local width = K.ScreenColumns(self.frame, self.chartPane, panel.frame) - 2 * K.theme.inset
    panel.recipe:SetWidth(width); panel.recipe.text:SetWidth(width - 32)
    panel.info:SetWidth(width); panel.buy:SetWidth(width)
    for _, row in ipairs(panel.reagents) do row:SetWidth(width - 40); row.text:SetWidth(width - 72) end
    self.chart.canvas:Fit()
    local rows = {}
    if path then
        if not self.picked and rank then
            self.chosen = nil
            for i, segment in ipairs(path.segments) do
                if segment.first <= rank and rank < segment.target then self.selected = i end
            end
        end
        self.selected = math.min(math.max(1, self.selected), #path.segments)
        for i in pairs(self.chosen or {}) do if i > #path.segments then self.chosen[i] = nil end end
        if self.chosen and not next(self.chosen) then self.chosen = nil end
        rows = UI.ChartRows(path, rank, function(i) return self.chosen and self.chosen[i] or (not self.chosen and i == self.selected) end)
        local recipes, buys = #path.segments, 0
        for _, segment in ipairs(path.segments) do if segment.buy then buys = buys + 1 end end
        local text
        local done = plan.rank and plan.rank >= path.reached
        if path.cost then
            local parts = {ns.T("level2Summary", options.first, path.reached, K.Money(path.cost))}
            if plan.rank and path.left and not done then parts[#parts + 1] = ns.T("level2Left", plan.rank, K.Money(path.left)) end
            parts[#parts + 1] = ns.T("level2PathCrafts", ns.Decimal(path.crafts, 0), recipes, buys)
            text = K.Details(parts)
        elseif not plan.rank then
            text = ns.T("level2Empty")
        elseif done or not path.left then
            text = ns.T("level2Passed", plan.rank, options.first, math.min(plan.rank, path.reached))
        else
            text = K.Details({ns.T("level2Summary", plan.rank, path.reached, K.Money(path.left)),
                ns.T("level2PathCrafts", ns.Decimal(path.crafts, 0), recipes, buys), ns.T("level2BelowMissing", options.first, plan.rank)})
        end
        if path.resale > 0 then text = K.Details({text, ns.T("level2Resale", K.Money(path.resale))}) end
        self.summary:SetText(text)
    else
        self.summary:SetText(ns.T("level2Empty"))
    end
    self.summary:SetWidth(math.max(120, (self.chartPane:GetWidth() or 660) - 2 * K.theme.inset))
    self.chart:SetProps({rows = rows, skill = rank or options.first, alt = self:Alt(path, rank)})
    if not self.centered then self.chart:Center(rank or options.first); self.centered = true end
    self.statusText = #plan.missing > 0 and ns.T("level2Missing", #plan.missing)
        or plan.reached < options.target and ns.T("level2Reached", plan.reached) or ""
    self:Controls()
    ns.Trader.RenderStatus()
    local picked = {}
    if path then
        for i, segment in ipairs(path.segments) do
            if self.chosen and self.chosen[i] or (not self.chosen and i == self.selected) then picked[#picked + 1] = segment end
        end
    end
    self:RenderPanel(picked, path, rank)
end
function UI.ChartRows(path, rank, selected)
    local rows = {}
    for i, segment in ipairs(path.segments) do
        local r = segment.recipe
        local name = ns.Compat.SpellIcon(r.spell) or ns.T("levelSpell", r.spell)
        rows[i] = {first = segment.first, target = segment.target, req = r.req, yellow = r.yellow, gray = r.gray,
            name = name .. (segment.buy and " *" or ""), title = name, tip = UI.SegmentTip(segment),
            selected = selected(i), done = rank ~= nil and segment.target <= rank}
    end
    return rows
end
function UI:Alt(path, rank)
    local plan = self.plan
    local other = plan and (self.kind == "simple" and plan.cheap or plan.simple)
    if not path or not other or other == path then return nil end
    local K = ns.TradeKit
    local mine, theirs = path.left or path.cost, other.left or other.cost
    local diff = mine and theirs and theirs - mine or nil
    local simple = self.kind == "cheap"
    local label = ns.T(simple and "level2AltSimple" or "level2AltCheap",
        diff and K.Money(math.abs(diff)) or ns.T("level2NoPrice"), #other.segments)
    return {label = label, tip = ns.T(simple and "level2SimpleTip" or "level2CheapTip") .. "\n\n" .. ns.T("level2AltPick"),
        rows = UI.ChartRows(other, rank, function() return false end),
        pick = function()
            self.kind = simple and "simple" or "cheap"
            self.selected, self.picked, self.chosen = 1, nil, nil
            self:Render()
        end}
end
local function recipeName(recipe)
    return ns.Compat.SpellIcon(recipe.spell) or ns.T("levelSpell", recipe.spell)
end
function UI:RenderPanel(list, path, rank)
    local K, panel = ns.TradeKit, self.panel
    local segment = list[1]
    if not segment then
        panel.recipe:Hide(); panel.info:SetText(ns.T("level2PickRow"))
        for _, row in ipairs(panel.reagents) do row:Hide() end
        self.buyQueue = nil
        panel.buy:Hide()
        return
    end
    local line = UI.Line(self.props.profession)
    local need, total, left, live, materials, blind = {}, 0, 0, 0, 0, false
    local unknown, unchecked, prep = {}, {}, {}
    for _, s in ipairs(list) do
        total, materials, blind = total + s.crafts, materials + s.materials, blind or s.blind
        if not (rank and s.target <= rank) then
            live = live + 1
            local part, crafts = ns.LevelingPaths.Need(s, rank and rank > s.first and rank or nil)
            left = left + crafts
            for id, count in pairs(part) do need[id] = (need[id] or 0) + count end
            for _, step in ipairs(s.prep or {}) do
                prep[#prep + 1] = step
                for _, input in ipairs(step.recipe.inputs) do
                    need[input[1]] = (need[input[1]] or 0) + step.crafts * input[2]
                end
                local known = ns.Recipes.Known(step.recipe.spell, line)
                if known == false then unknown[#unknown + 1] = recipeName(step.recipe)
                elseif known == nil then unchecked[#unchecked + 1] = recipeName(step.recipe) end
            end
        end
        local known = ns.Recipes.Known(s.recipe.spell, line)
        if known == false then unknown[#unknown + 1] = recipeName(s.recipe)
        elseif known == nil then unchecked[#unchecked + 1] = recipeName(s.recipe) end
    end
    if live == 0 then
        for _, s in ipairs(list) do
            for id, count in pairs((ns.LevelingPaths.Need(s, nil))) do need[id] = (need[id] or 0) + count end
        end
    end
    local crafts = ns.T("level2Crafts", ns.Decimal(total, 1))
    if live > 0 and rank and left < total - 0.05 then crafts = crafts .. ns.T("level2CraftsLeft", rank, ns.Decimal(left, 1)) end
    local lines
    if #list == 1 then
        K.SetSpellChoice(panel.recipe, segment.recipe.spell, false)
        lines = {ns.T("level2Range", segment.first, segment.target), crafts, source(segment)}
    else
        panel.recipe:Hide()
        local first, target = segment.first, segment.target
        for _, s in ipairs(list) do first, target = math.min(first, s.first), math.max(target, s.target) end
        lines = {ns.T("level2Many", #list, first, target), crafts}
        if #unknown > 0 then lines[#lines + 1] = ns.T("level2ManyUnknown", table.concat(unknown, ", ")) end
        if #unchecked > 0 then lines[#lines + 1] = ns.T("level2ManyUnchecked", table.concat(unchecked, ", ")) end
        if #unknown + #unchecked == 0 then lines[#lines + 1] = ns.T("level2ManyKnown") end
    end
    lines[#lines + 1] = ns.T("level2Materials", blind and ns.T("level2NoPrice") or K.Money(materials))
    if #list == 1 and segment.resale > 0 then lines[#lines + 1] = ns.T("level2SegmentResale", K.Money(segment.resale)) end
    if path and #path.rods > 0 and segment == path.segments[1] then
        for _, rod in ipairs(path.rods) do lines[#lines + 1] = ns.T("level2Rod", rod.tier, K.Money(rod.cost)) end
    end
    panel.info:SetText(table.concat(lines, "\n"))
    local shopping = ns.LevelingPaths.Shopping({segments = list}, rank, true)
    local ids = {}
    for id in pairs(need) do ids[#ids + 1] = id end
    table.sort(ids)
    local queue, stock, items, cash = {}, {}, {}, 0
    for _, id in ipairs(ids) do
        local missing = shopping[id] or 0
        if missing > 0 then
            if ns.vendorPrices[id] then
                stock[#stock + 1] = {id = id, need = 0, vendor = true}
                items[#items + 1] = {id = id, count = missing, label = ns.T("batchWayVendor")}
            else
                queue[#queue + 1] = {id = id, need = missing}
                local item = K.BatchPanel.Item(id, missing)
                items[#items + 1] = item
                cash = cash and item.value and cash + item.value or nil
            end
        end
    end
    for _, entry in ipairs(stock) do queue[#queue + 1] = entry end
    local y = -(panel.info:GetStringHeight() or 60) - 52
    for i, row in ipairs(panel.reagents) do
        local step, id = prep[i], ids[i - #prep]
        if step then
            K.SetSpellChoice(row, step.recipe.spell, false)
            row.need = nil
            row.extraTip = ns.T("level2PrepCrafts")
            row.count:SetText(tostring(step.crafts))
        elseif id then
            K.SetItemChoice(row, id, false)
            local missing = shopping[id]
            row.need = missing
            row.extraTip = missing and ns.T("level2ReagentTip", missing) or nil
            row.count:SetText(tostring(need[id]))
        end
        if step or id then
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", K.theme.inset, y - (i - 1) * 24)
            row:Show()
        else row:Hide() end
    end
    self.buyQueue = live > 0 and queue or {}
    local warning = #unknown > 0 and K.Colored(ns.T("level2BuyUnknown"), "negative")
        or #unchecked > 0 and K.Colored(ns.T("level2BuyUnchecked"), "negative") or nil
    self.buyTip = warning or ""
    self.buyItems = #items > 0 and items or nil
    self.buyTotal = #queue > 0 and {label = ns.T("batchCash"), value = cash and K.Money(cash) or ns.T("batchNoPrice")} or nil
    self.buyReason = live == 0 and ns.T("level2BuyDone") or #queue == 0 and ns.T("level2BuyHave") or nil
    panel.buy:Show()
    self:BuyState()
end
function UI:BuyState()
    local b = self.panel and self.panel.buy
    if not b or not b:IsShown() then return end
    local K = ns.TradeKit
    local reason = self.buyReason
        or (ns.Scan.state.phase ~= "idle" or ns.Buy.Active()) and ns.T("batchBusy") or nil
    K.Tooltip(b, ns.T("level2Buy"), self.buyTip or "")
    if self.buyItems and not reason then
        local body, items, total = self.buyTip ~= "" and self.buyTip or nil, self.buyItems, self.buyTotal
        b.tipKeys = function() return {body = body, items = items, total = total} end
    end
    K.DisabledTip(b, ns.T("level2Buy"), reason)
    if reason then b:Disable() else b:Enable() end
end
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent); self.frame:SetAllPoints(parent)
    local f = self.frame
    local fields = ns.NewFrame("Frame", nil, f)
    fields:SetHeight(22)
    self.first, self.target, self.rate = K.Edit(fields, 42), K.Edit(fields, 42), K.Edit(fields, 30)
    local x = 0
    for _, entry in ipairs({{"levelFrom", self.first, 0}, {"levelTo", self.target, 8}, {"level2Rate", self.rate, 20}}) do
        x = x + entry[3]
        local label = K.Label(fields, ns.T(entry[1]), x, -5, 60); label:SetHeight(12)
        local width = math.ceil(label.GetStringWidth and label:GetStringWidth() or 0)
        width = width > 0 and width + 2 or 24
        label:SetWidth(width)
        entry[2]:SetPoint("TOPLEFT", fields, "TOPLEFT", x + width + 6, 0)
        x = x + width + 6 + entry[2]:GetWidth()
    end
    fields:SetWidth(x)
    local function range(final)
        if not final then return end
        self.centered, self.picked, self.chosen = nil, nil, nil
        self:SetProps({first = tonumber(self.first:GetText()), target = tonumber(self.target:GetText())})
    end
    local function rate(edit, final)
        local value = tonumber(edit:GetText())
        if not final and (not value or value < 1 or value > ns.LevelingPaths.RATE_MAX) then return end
        UI.SetRate(value)
        if final then edit:SetText(tostring(UI.Rate())) end
        self.signature = nil
        self:Render()
    end
    for _, edit in ipairs({self.first, self.target, self.rate}) do
        edit:SetNumeric(true)
        edit:SetScript("OnEditFocusGained", function(box) box:HighlightText() end)
        edit:SetScript("OnEditFocusLost", function(box)
            box.liveAt = nil; box:SetScript("OnUpdate", nil)
            if box == self.rate then rate(box, true) else range(true) end
        end)
    end
    self.first:SetMaxLetters(3); self.target:SetMaxLetters(3); self.rate:SetMaxLetters(2)
    K.LiveEdit(self.first, function() range(false) end, 0.8); K.LiveEdit(self.target, function() range(false) end, 0.8)
    K.Tooltip(self.first, ns.T("level2First"), ns.T("level2FirstTip"))
    K.LiveEdit(self.rate, function(edit) rate(edit, false) end, 0.8)
    K.Tooltip(self.rate, ns.T("level2RateTitle"), ns.T("level2RateTip"))
    self.chartPane = ns.NewFrame("Frame", nil, f)
    K.Panel(self.chartPane)
    self.summary = K.Label(self.chartPane, "", K.theme.inset, -8, 600, "secondary")
    self.summary:SetHeight(12)
    self.scan = K.ScanBarButton(f, {label = ns.T("level2BarPath"),
        run = function(mode)
            local started = ns.Batch.Complete(self:ScanTargets(), mode, true)
            if started and ns.Batch.job then ns.Batch.job.levelingProfession = self.props.profession end
            self:Controls()
        end,
        sources = function() return self:ScanTargets() end,
        body = function()
            local options = self:ScanOptions()
            return options and ns.T("level2ScanTip", options.first, options.target) or ns.T("level2ScanDone")
        end})
    self.scan.tipTitle = ns.T("level2Scan")
    self.barFrames = {self.scan}
    self.resale = K.Switch(f, ns.T("level2ResaleSwitch"), function(on)
        ns.Store.DB().levelingResale = on or nil
        self.signature = nil
        self:Render()
    end)
    K.Tooltip(self.resale, ns.T("level2ResaleSwitch"), ns.T("level2ResaleSwitchTip"))
    self.chart = K.SkillChart:New(self.chartPane, function(index) self:Pick(index) end)
    self.chart.canvas.frame:SetPoint("TOPLEFT", self.chartPane, "TOPLEFT", 4, -24)
    self.chart.canvas.frame:SetPoint("BOTTOMRIGHT", self.chartPane, "BOTTOMRIGHT", -4, 4)
    self.help = K.InfoButton(f, ns.T("level2Title"), ns.T("level2Help"))
    self.head = {filters = {self.resale, fields}, actions = {self.help}}
    local panel = {frame = ns.NewFrame("Frame", nil, f), reagents = {}}
    K.Panel(panel.frame)
    panel.recipe = K.ItemChoice(panel.frame)
    panel.recipe:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", K.theme.inset, -6)
    panel.info = K.Label(panel.frame, "", K.theme.inset, -40, 240)
    panel.info:SetJustifyV("TOP")
    for i = 1, REAGENTS do
        local row = K.ItemChoice(panel.frame, function(b)
            local id = rawget(b, "itemID")
            if not id or not rawget(b, "need") then return end
            self:Render()
            local missing = rawget(b, "need")
            if b:IsShown() and rawget(b, "itemID") == id and missing then ns.Trader.OpenBuy(id, missing) end
        end)
        row.count = K.Label(row, "", 0, 0, 36)
        row.count:ClearAllPoints(); row.count:SetPoint("LEFT", row, "RIGHT", 2, 0); row.count:SetJustifyH("RIGHT")
        row:Hide()
        panel.reagents[i] = row
    end
    panel.buy = K.Button(panel.frame, ns.T("level2Buy"), 240, function()
        self:Render()
        if panel.buy:IsEnabled() and self.buyQueue and #self.buyQueue > 0 and ns.BuyModal then
            ns.BuyModal.Open(self.buyQueue)
        end
    end)
    panel.buy:SetPoint("BOTTOMLEFT", panel.frame, "BOTTOMLEFT", K.theme.inset, K.theme.inset)
    panel.buy:Hide()
    self.panel = panel
    ns.Posting.Listen(function()
        if ns.Trader.ViewActive("leveling2") then self:Render() end
    end)
    f:SetScript("OnSizeChanged", function() self:Render() end)
    f:HookScript("OnShow", function() self.centered = nil end)
    self:Render()
    return self
end
