local _, ns = ...
local UI = {props = {profession = "tailoring"}, kind = "cheap", selected = 1, states = {}}
ns.Leveling2UI = UI
local PANEL = 264
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
function UI:Options()
    local p, line = self.props, UI.Line(self.props.profession)
    return {profession = p.profession, first = p.first or 1, target = p.target or 450,
        faction = UnitFactionGroup("player"), rodTier = p.profession == "enchanting" and UI.RodTier() or 0,
        known = function(spell) return ns.Recipes.Known(spell, line) end}
end
function UI:SetProps(props)
    local profession = props.profession or self.props.profession
    if profession ~= self.props.profession then
        self.states[self.props.profession] = {props = self.props, kind = self.kind, selected = self.selected}
        local state = self.states[profession] or {props = {profession = profession}, kind = "cheap", selected = 1}
        self.props, self.kind, self.selected, self.centered = state.props, state.kind, state.selected, nil
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
        reached = above.reached, rods = above.rods, complexity = above.complexity}
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
function UI:Model()
    local options = self:Options()
    local rank = UI.Rank(options.profession)
    local parts = {options.profession, options.first, options.target, options.rodTier, rank or 0, math.floor(time() / 60)}
    for _, id in ipairs(ns.LevelingPaths.Targets(options)) do
        local q = ns.Markets.Quote(id)
        parts[#parts + 1] = q and (tostring(q.price) .. ":" .. tostring(q.lots) .. ":" .. tostring(q.at)) or "-"
    end
    local key = table.concat(parts, "|")
    if key ~= self.signature or not self.plan then
        self.signature = key
        if rank and rank >= options.target then
            local done = UI.Passed(options)
            self.plan = {options = options, rank = rank, reached = done.reached, missing = {},
                cheap = done.cheap and UI.Join(done.cheap, nil, rank) or nil}
        elseif rank and rank > options.first then
            local low, high = {}, {}
            for k, v in pairs(options) do low[k], high[k] = v, v end
            low.target, high.first = rank, rank
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
    end
    return self.plan
end
function UI:Path()
    local plan = self.plan
    if not plan then return nil end
    return self.kind == "simple" and plan.simple or plan.cheap
end
local function source(segment)
    local K = ns.TradeKit
    if segment.blind then return ns.T("level2Known") end
    if segment.buy == "vendor" then return ns.T("level2Vendor", K.Money(segment.acquire)) end
    if segment.buy == "auction" then return ns.T("level2Auction", K.Money(segment.acquire)) end
    if segment.acquire > 0 then return ns.T("level2Trainer", K.Money(segment.acquire)) end
    return ns.T("level2Known")
end
function UI.SegmentTip(segment)
    local K, r = ns.TradeKit, segment.recipe
    return ns.T("level2SegmentTip", segment.first, segment.target, ns.Decimal(segment.crafts, 1), r.req, r.yellow,
        math.floor((r.yellow + r.gray) / 2), r.gray, segment.cost and K.Money(segment.cost) or ns.T("level2NoPrice"),
        source(segment))
end
function UI:Controls()
    if not self.frame then return end
    if ns.Scan.state.phase == "idle" and not ns.Buy.Active() then self.scan:Enable() else self.scan:Disable() end
end
function UI:Render()
    if not self.frame or not self.frame:IsVisible() then return end
    local K, plan = ns.TradeKit, self:Model()
    local options = plan.options
    for edit, value in pairs({[self.first] = options.first, [self.target] = options.target}) do
        if not edit:HasFocus() then edit:SetText(tostring(value)) end
    end
    if plan.simple then self.kinds.buttons.simple:Enable() else self.kinds.buttons.simple:Disable() end
    if not plan.simple and self.kind == "simple" then self.kind = "cheap" end
    self.kinds:Select(self.kind)
    local path = self:Path()
    local rank = UI.Rank(options.profession)
    local width = self.frame:GetWidth() or 996
    self.chart.canvas.frame:ClearAllPoints()
    self.chart.canvas.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -58)
    self.chart.canvas.frame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -(PANEL + 16), 8)
    self.chart.canvas:Fit()
    local rows = {}
    if path then
        self.selected = math.min(math.max(1, self.selected), #path.segments)
        for i, segment in ipairs(path.segments) do
            local r = segment.recipe
            local name = ns.Compat.SpellIcon(r.spell) or ns.T("levelSpell", r.spell)
            rows[i] = {first = segment.first, target = segment.target, req = r.req, yellow = r.yellow, gray = r.gray,
                name = name .. (segment.buy and " *" or ""), title = name, tip = UI.SegmentTip(segment),
                selected = i == self.selected, done = rank ~= nil and segment.target <= rank}
        end
        local recipes, buys = #path.segments, 0
        for _, segment in ipairs(path.segments) do if segment.buy then buys = buys + 1 end end
        local text
        local done = plan.rank and plan.rank >= path.reached
        if path.cost then
            text = ns.T("level2Summary", options.first, path.reached, K.Money(path.cost), ns.Decimal(path.crafts, 0), recipes, buys)
            if plan.rank and path.left and not done then text = text .. ns.T("level2Left", plan.rank, K.Money(path.left)) end
        elseif not plan.rank then
            text = ns.T("level2Empty")
        elseif done or not path.left then
            text = ns.T("level2Passed", plan.rank, options.first, math.min(plan.rank, path.reached))
        else
            text = ns.T("level2Summary", plan.rank, path.reached, K.Money(path.left), ns.Decimal(path.crafts, 0), recipes, buys)
                .. ns.T("level2BelowMissing", options.first, plan.rank)
        end
        if path.resale > 0 then text = text .. ns.T("level2Resale", K.Money(path.resale)) end
        if plan.simple and self.kind == "cheap" then
            text = text .. ns.T("level2SimpleHint", K.Money(plan.simple.cost - plan.cheap.cost))
        end
        self.summary:SetText(text)
    else
        self.summary:SetText(ns.T("level2Empty"))
    end
    self.summary:SetWidth(math.max(120, width - 360))
    self.chart:SetProps({rows = rows, skill = rank or options.first})
    if not self.centered then self.chart:Center(rank or options.first); self.centered = true end
    self.statusText = #plan.missing > 0 and ns.T("level2Missing", #plan.missing)
        or plan.reached < options.target and ns.T("level2Reached", plan.reached) or ""
    ns.Trader.RenderStatus()
    self:RenderPanel(path and path.segments[self.selected], path)
    self:Controls()
end
function UI:RenderPanel(segment, path)
    local K, panel = ns.TradeKit, self.panel
    if not segment then
        panel.recipe:Hide(); panel.info:SetText(ns.T("level2PickRow"))
        for _, row in ipairs(panel.reagents) do row:Hide() end
        return
    end
    K.SetSpellChoice(panel.recipe, segment.recipe.spell, false)
    local lines = {ns.T("level2Range", segment.first, segment.target), ns.T("level2Crafts", ns.Decimal(segment.crafts, 1)),
        source(segment), ns.T("level2Materials", segment.blind and ns.T("level2NoPrice") or K.Money(segment.materials))}
    if segment.resale > 0 then lines[#lines + 1] = ns.T("level2SegmentResale", K.Money(segment.resale)) end
    if path and #path.rods > 0 and segment == path.segments[1] then
        for _, rod in ipairs(path.rods) do lines[#lines + 1] = ns.T("level2Rod", rod.tier, K.Money(rod.cost)) end
    end
    panel.info:SetText(table.concat(lines, "\n"))
    local ids = {}
    for id in pairs(segment.inputs) do ids[#ids + 1] = id end
    table.sort(ids)
    local y = -(panel.info:GetStringHeight() or 60) - 52
    for i, row in ipairs(panel.reagents) do
        local id = ids[i]
        if id then
            local need = math.ceil(segment.inputs[id] - 0.0000001)
            K.SetItemChoice(row, id, false)
            row.need = need
            row.extraTip = ns.T("level2ReagentTip", need)
            row.count:SetText(tostring(need))
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", K.theme.inset, y - (i - 1) * 24)
            row:Show()
        else row:Hide() end
    end
end
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent); self.frame:SetAllPoints(parent)
    local f = self.frame
    K.Label(f, ns.T("levelFrom"), 10, -10, 24)
    self.first = K.Edit(f, 42); self.first:SetPoint("TOPLEFT", f, "TOPLEFT", 38, -4)
    K.Label(f, ns.T("levelTo"), 87, -10, 24)
    self.target = K.Edit(f, 42); self.target:SetPoint("TOPLEFT", f, "TOPLEFT", 112, -4)
    for _, edit in ipairs({self.first, self.target}) do edit:SetNumeric(true); edit:SetMaxLetters(3) end
    local function read()
        local first, target = tonumber(self.first:GetText()), tonumber(self.target:GetText())
        self.centered = nil
        self:SetProps({first = first, target = target})
    end
    K.LiveEdit(self.first, read, 0.8); K.LiveEdit(self.target, read, 0.8)
    K.Tooltip(self.first, ns.T("level2First"), ns.T("level2FirstTip"))
    self.summary = K.Label(f, "", 166, -10, 600)
    self.summary:SetHeight(12)
    self.kinds = K.Segment(f, {{key = "cheap", label = ns.T("level2Cheap")}, {key = "simple", label = ns.T("level2Simple")}},
        function(kind) self.kind = kind; self.selected = 1; self:Render() end)
    K.Tooltip(self.kinds.buttons.cheap, ns.T("level2Cheap"), ns.T("level2CheapTip"))
    K.Tooltip(self.kinds.buttons.simple, ns.T("level2Simple"), ns.T("level2SimpleTip"))
    K.DisabledTip(self.kinds.buttons.simple, ns.T("level2Simple"), ns.T("level2NoSimple"))
    self.scan = K.Button(f, ns.T("level2Scan"), 120, function()
        local started = ns.Batch.Complete(ns.LevelingPaths.Targets(self:Options()), K.ScanMode(), true)
        if started and ns.Batch.job then ns.Batch.job.levelingProfession = self.props.profession end
        self:Controls()
    end, "main")
    K.FitButton(self.scan, 24)
    K.ScanTip(self.scan, ns.T("level2Scan"), ns.T("level2ScanTip"), function() return ns.LevelingPaths.Targets(self:Options()) end)
    self.head = {filters = {self.kinds.frame}, actions = {self.scan}}
    self.chart = K.SkillChart:New(f, function(index) self.selected = index; self:Render() end)
    self.help = K.InfoButton(f, ns.T("level2Title"), ns.T("level2Help"))
    self.help:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -4)
    local panel = {frame = ns.NewFrame("Frame", nil, f), reagents = {}}
    K.Panel(panel.frame)
    panel.frame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -32)
    panel.frame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 2)
    panel.frame:SetWidth(PANEL)
    panel.recipe = K.ItemChoice(panel.frame)
    panel.recipe:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", K.theme.inset, -6)
    panel.recipe:SetWidth(PANEL - 2 * K.theme.inset)
    panel.info = K.Label(panel.frame, "", K.theme.inset, -40, PANEL - 2 * K.theme.inset)
    panel.info:SetJustifyV("TOP")
    for i = 1, REAGENTS do
        local row = K.ItemChoice(panel.frame, function(b) if b.itemID then ns.Trader.OpenBuy(b.itemID, b.need) end end)
        row:SetWidth(PANEL - 2 * K.theme.inset - 40)
        row.count = K.Label(row, "", 0, 0, 36)
        row.count:ClearAllPoints(); row.count:SetPoint("LEFT", row, "RIGHT", 2, 0); row.count:SetJustifyH("RIGHT")
        row:Hide()
        panel.reagents[i] = row
    end
    self.panel = panel
    f:SetScript("OnSizeChanged", function() self:Render() end)
    f:HookScript("OnShow", function() self.centered = nil end)
    self:Render()
    return self
end
