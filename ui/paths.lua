local _, ns = ...
local CARD = 210
local GAP_X = 56
local GAP_Y = 10
local SIDE = 248
local FOOT = 36
local TOP = 30
local GATHER_SPELLS = {herbalism = 2366, mining = 2575, skinning = 8613, fishing = 7620}
local function signed(value)
    if value == nil then return ns.T("tradeNoPrice") end
    return (value > 0 and "+" or "") .. ns.TradeKit.MoneyShort(value)
end
local UI = {}
UI.__index = UI
ns.PathsUI = UI
local serial = 0
function UI:New(parent)
    local K = ns.TradeKit
    serial = serial + 1
    local view = setmetatable({mode = "scheme", choice = {}, open = {}, history = {}, cards = {}, links = {}, placed = {},
        pathRows = {}, useRows = {}}, self)
    local f = ns.NewFrame("Frame", nil, parent)
    view.frame = f
    f:EnableMouse(true)
    view.segment = K.Segment(f, {{key = "scheme", label = ns.T("pathViewScheme")}, {key = "table", label = ns.T("pathViewTable")}},
        function(key) view:SetView(key) end, {ns.T("pathWindowTitle"), ns.T("pathViewTip")})
    view.segment.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    view.back = K.Button(f, ns.T("pathBack"), 70, function() view:Back() end, "quiet")
    view.back:SetPoint("LEFT", view.segment.frame, "RIGHT", 8, 0)
    view.craftChip = K.Chip(f, ns.T("batchMakeChip"), function(checked) view:SetPolicy("craftAll", checked) end)
    view.craftChip:SetPoint("LEFT", view.back, "RIGHT", 12, 0)
    K.Tooltip(view.craftChip, ns.T("batchMakeChip"), ns.T("pathPolicyCraftTip"))
    view.ownedChip = K.Chip(f, ns.T("batchOwnedChip"), function(checked) view:SetPolicy("owned", checked) end)
    view.ownedChip:SetPoint("LEFT", view.craftChip, "RIGHT", 6, 0)
    K.Tooltip(view.ownedChip, ns.T("batchOwnedChip"), ns.T("pathPolicyOwnedTip"))
    view.canvas = K.Canvas:New(f, function() view:Cull() end)
    view.reset = K.Button(f, "", 90, function() view:ResetView() end, "quiet")
    view.reset:SetPoint("TOPRIGHT", view.canvas.frame, "TOPRIGHT", -6, -6)
    view.reset:SetFrameLevel(view.canvas.frame:GetFrameLevel() + 30)
    K.Tooltip(view.reset, ns.T("pathResetView"), ns.T("pathResetViewTip"))
    view.handlers = {
        select = function(card, row) view:Select(card.data, row) end,
        center = function(card, row) view:Center(card.data, row) end,
        toggle = function(card, row) view:Toggle(card.data, row) end,
    }
    view.scroll = ns.NewFrame("ScrollFrame", "ManaCodePathScroll" .. serial, f, "UIPanelScrollFrameTemplate")
    view.scroll.scrollBarHideable = 1
    view.child = ns.NewFrame("Frame", nil, view.scroll)
    view.child:SetWidth(400); view.child:SetHeight(300)
    view.scroll:SetScrollChild(view.child)
    view:BuildTable()
    view:BuildSide()
    view.apply = K.Button(f, ns.T("pathApply"), 200, function() view:Apply() end, "main")
    view.apply:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 4)
    K.Tooltip(view.apply, ns.T("pathApply"), ns.T("pathApplyTip"))
    view.complete = K.Button(f, ns.T("pathComplete"), 130, function() view:Complete() end)
    view.complete:SetPoint("LEFT", view.apply, "RIGHT", 6, 0)
    K.ScanTip(view.complete, ns.T("pathComplete"), ns.T("pathCompleteTip"), function() return view:Sources() end)
    K.DisabledTip(view.complete, ns.T("pathComplete"), ns.T("deMainWait"))
    view.disenchant = K.Button(f, ns.T("pathDisenchant"), 80, function()
        local id = view.props and view.props.id
        ns.PathWindow.Close()
        ns.DisenchantUI.Open(id)
    end, "quiet")
    view.disenchant:SetPoint("LEFT", view.complete, "RIGHT", 6, 0)
    K.Tooltip(view.disenchant, ns.T("pathDisenchant"), ns.T("pathDisenchantTip"))
    view.info = K.InfoButton(f, ns.T("pathWindowTitle"), ns.T("pathInfo") .. "\n\n" .. ns.T("pathNextTip"))
    view.info:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 4)
    f:SetScript("OnSizeChanged", function() if view.props then view:Render() end end)
    return view
end
function UI:BuildTable()
    local K, c = ns.TradeKit, self.child
    local level = c:GetFrameLevel()
    self.tableHead = ns.NewFrame("Frame", nil, c)
    self.tableHead:SetHeight(20); K.HeaderBand(self.tableHead)
    self.headers = {}
    for _, entry in ipairs({{"path", "pathColPath"}, {"cost", "pathColCost"}, {"margin", "pathColMargin"}, {"limits", "pathColLimits"}}) do
        local label = K.Label(self.tableHead, ns.T(entry[2]), 0, -4, 100)
        label:SetHeight(12)
        self.headers[entry[1]] = label
    end
    self.tableHead:Hide()
    for i = 1, 12 do
        local row = {}
        row.frame = K.Button(c, "", 100, function() self:ChoosePath(row.path) end, "quiet")
        row.frame:SetHeight(34); row.frame:SetFrameLevel(level + 2)
        row.frame.text:SetText("")
        row.name = K.Label(row.frame, "", 8, -4, 200); row.name:SetHeight(26); row.name:SetJustifyV("TOP")
        row.cost = K.Label(row.frame, "", 0, -4, 90); row.cost:SetHeight(12); row.cost:SetJustifyH("RIGHT")
        row.margin = K.Label(row.frame, "", 0, -4, 90); row.margin:SetHeight(12); row.margin:SetJustifyH("RIGHT")
        row.limits = K.Label(row.frame, "", 0, -4, 150, "secondary"); row.limits:SetHeight(26); row.limits:SetJustifyV("TOP")
        row.frame:Hide()
        self.pathRows[i] = row
    end
    self.usesHead = ns.NewFrame("Frame", nil, c)
    self.usesHead:SetHeight(20); K.HeaderBand(self.usesHead)
    self.usesTitle = K.Label(self.usesHead, ns.T("pathColUse"), 8, -4, 300); self.usesTitle:SetHeight(12)
    self.usesGain = K.Label(self.usesHead, ns.T("pathColGain"), 0, -4, 120); self.usesGain:SetHeight(12)
    self.usesGain:SetJustifyH("RIGHT")
    self.usesHead:Hide()
    for i = 1, 16 do
        local row = K.ItemChoice(c, function(b) if b.itemID then self:Push(b.itemID) end end)
        row:SetHeight(22)
        row.extraTip = ns.T("pathUseRowTip")
        row.value = K.Label(row, "", 0, 0, 110); row.value:SetHeight(12); row.value:SetJustifyH("RIGHT")
        row.value:ClearAllPoints(); row.value:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row:Hide()
        self.useRows[i] = row
    end
    self.empty = K.Label(c, "", 8, -28, 400, "secondary"); self.empty:SetHeight(40)
end
function UI:BuildSide()
    local K = ns.TradeKit
    local s = ns.NewFrame("Frame", nil, self.frame)
    self.side = s
    K.Panel(s)
    self.sideTitle = K.ItemChoice(s, function(b) if b.itemID then ns.MarketWindow.Open(b.itemID) end end)
    self.sideTitle:SetPoint("TOPLEFT", s, "TOPLEFT", 8, -6)
    self.sideTitle:SetHeight(22)
    self.values = {}
    local labels, values = K.ValueRows(s, -32, {"", "", "", ""}, {labelWidth = 104, valueWidth = 120})
    for i = 1, 4 do self.values[i] = {label = labels[i], value = values[i]} end
    self.note = K.Label(s, "", 12, -92, SIDE - 24, "secondary"); self.note:SetHeight(52); self.note:SetJustifyV("TOP")
    self.choose = K.Button(s, ns.T("pathChoose"), 110, function() self:ChooseFocus() end, "control")
    self.choose:SetPoint("TOPLEFT", s, "TOPLEFT", 12, -148)
    K.Tooltip(self.choose, ns.T("pathChoose"), ns.T("pathChooseTip"))
    self.pin = K.Button(s, ns.T("pathOnMap"), 100, function() self:ShowOnMap() end, "quiet")
    self.pin:SetPoint("LEFT", self.choose, "RIGHT", 6, 0)
    K.Tooltip(self.pin, ns.T("pathOnMap"), ns.T("pathOnMapTip"))
    self.go = K.Button(s, ns.T("pathOpenSection"), 110, function() self:OpenFocus() end, "control")
    self.go:SetPoint("TOPLEFT", s, "TOPLEFT", 12, -148)
    K.Tooltip(self.go, ns.T("pathOpenSection"), ns.T("pathOpenSectionTip"))
    self.recenter = K.Button(s, ns.T("pathRecenter"), 100, function() self:CenterFocus() end, "quiet")
    self.recenter:SetPoint("LEFT", self.go, "RIGHT", 6, 0)
    K.Tooltip(self.recenter, ns.T("pathRecenter"), ns.T("pathRecenterTip"))
    self.next = K.NextUses:New(s)
    self.next.frame:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", 12, 8)
    self.next.frame:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -12, 8)
end
function UI:SetProps(props)
    local changed = not self.props or self.props.id ~= props.id
    if changed then self.choice, self.open, self.focus = {}, {}, nil end
    self.props = props
    self:Render(changed)
end
function UI:Push(id)
    if not self.props or id == self.props.id then return end
    self.history[#self.history + 1] = self.props.id
    self:SetProps({id = id})
end
function UI:Back()
    local id = table.remove(self.history)
    if id then self:SetProps({id = id}) end
end
function UI:SetView(mode)
    self.mode = mode
    self:Render(mode == "scheme")
end
function UI:Choose(id, key)
    self.choice[id] = key
    self:Render()
end
function UI:ChoosePath(path)
    if not path then return end
    self.choice = {}
    for id, key in pairs(path.choice) do self.choice[id] = key end
    self:Render()
end
function UI:SetPolicy(key, value)
    ns.ReagentPolicy.Set(key, value)
    if ns.Trader and ns.Trader.frame and ns.Trader.frame:IsVisible() then ns.Trader.Refresh() else self:Render() end
end
function UI:ResetView()
    local width = self.canvas:Size()
    local zoom = math.floor(math.min(1, width / (3 * CARD + 2 * GAP_X + 24)) * 10) / 10
    local center = self.placed[1]
    if not center then return end
    self.focused = width > 50
    self.canvas:Focus(center.x + CARD / 2, center.y + center.height / 2, math.max(ns.TradeKit.Canvas.MIN, zoom))
end
function UI:BatchTarget()
    local T = ns.Trader
    if not T or not T.frame then return nil end
    if T.section == "jewelry" and ns.FamilyUI and ns.FamilyUI.frame then
        local view = ns.FamilyUI
        view.batchState.choice = view.batchState.choice or {}
        local recipe = view:BatchRecipe(view.props.id)
        return {choice = view.batchState.choice, product = recipe and recipe.raw, plan = view.batch and view.batch.plan,
            refresh = function() view:Render() end}
    end
    if ns.craftCatalogs[T.section] and ns.AlchemyUI and ns.AlchemyUI.frame then
        local view = ns.AlchemyUI
        view.choice = view.choice or {}
        return {choice = view.choice, product = view.props.recipe, plan = view.batch and view.batch.plan,
            refresh = function() view:Render() end}
    end
    return nil
end
function UI:InBatch(target)
    if not target or not target.product or not self.props then return false end
    local id = self.props.id
    if id == target.product then return true end
    for _, node in ipairs(target.plan and target.plan.rows or {}) do
        if node.id == id then return true end
    end
    return false
end
function UI:Apply()
    local target = self:BatchTarget()
    if not self.selected or not self:InBatch(target) then ns.say(ns.T("pathApplyNone")); return end
    for id, key in pairs(ns.Obtain.Choice(self.selected)) do
        if id ~= target.product and key ~= "gather" and not key:find("^disenchant:") then target.choice[id] = key end
    end
    target.refresh()
    ns.say(ns.T("pathApplied"))
end
function UI:Sources()
    local ids, seen = {}, {}
    local function add(id)
        if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
    if self.selected then for _, id in ipairs(ns.Obtain.Ids(self.selected)) do add(id) end end
    if self.map then for _, id in ipairs(self.map.missing) do add(id) end end
    local D = ns.Disenchant
    for material, qualities in pairs(self.map and self.map.scans or {}) do
        local key = D.Selection("target" .. material, qualities)
        if key and D.Group(key) then
            for _, source in ipairs(D.ScanSources(key, nil, "equipment")) do ids[#ids + 1] = source end
        end
    end
    if self.props then
        local _, list = ns.Reagents.Next(self.props.id, ns.Fee(), ns.TradeKit.NextUses.MAX)
        for _, entry in ipairs(list) do
            if entry.gain == nil then add((ns.TradeKit.NextUses.Describe(self.props.id, entry))) end
        end
    end
    return ids
end
function UI:Complete()
    if not self.selected then return end
    ns.Batch.Complete(self:Sources(), ns.TradeKit.ScanMode(), true)
    if ns.Trader then ns.Trader.Refresh() end
    self:Controls()
end
function UI:Controls()
    if not self.props then return end
    local K = ns.TradeKit
    if ns.Scan.state.phase == "idle" and not ns.Buy.Active() then self.complete:Enable() else self.complete:Disable() end
    local target = self:BatchTarget()
    if target and target.product then
        self.apply:SetText(ns.T("pathApplyTo", ns.Markets.Name(target.product)))
    else self.apply:SetText(ns.T("pathApply")) end
    if self:InBatch(target) then
        self.apply:Enable()
        K.DisabledTip(self.apply, ns.T("pathApply"), nil)
    else
        self.apply:Disable()
        K.DisabledTip(self.apply, ns.T("pathApply"), ns.T(target and target.product and "pathApplyOther" or "pathApplyNone"))
    end
end
function UI:Layout()
    local f = self.frame
    self.side:ClearAllPoints()
    self.side:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -TOP)
    self.side:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT)
    self.side:SetWidth(SIDE)
    for _, frame in ipairs({self.canvas.frame, self.scroll}) do
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -TOP)
    end
    self.canvas.frame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -SIDE - 8, FOOT)
    self.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -SIDE - 30, FOOT)
    self.canvas:Fit()
end
function UI:Render(refocus)
    if not self.props then return end
    local O, K = ns.Obtain, ns.TradeKit
    local policy = ns.ReagentPolicy.Get()
    self.map = O.Map(self.props.id, {choice = self.choice, policy = policy, open = self.open})
    self.selected = self.map.root
    self.cardByKey = {}
    for _, card in ipairs(self.map.cards) do self.cardByKey[card.key] = card end
    if self.focus and not self.cardByKey[self.focus.key] then self.focus = nil end
    self.segment:Select(self.mode)
    self.craftChip:SetChecked(policy.craftAll)
    self.ownedChip:SetChecked(policy.owned)
    local back = self.history[#self.history]
    if back then
        self.back:Show()
        K.Tooltip(self.back, ns.T("pathBack"), ns.T("pathBackTo", ns.Markets.Name(back)))
    else self.back:Hide() end
    if self.header then K.SetItemChoice(self.header, self.props.id, false) end
    self:Layout()
    if self.mode == "table" then
        self.canvas.frame:Hide(); self.reset:Hide()
        self.scroll:Show()
        self:RenderTable(math.max(200, (self.scroll:GetWidth() or 600) - 4))
    else
        self.scroll:Hide()
        self.canvas.frame:Show(); self.reset:Show()
        self:LayoutMap()
        if refocus or not self.focused then self:ResetView() else self:Cull() end
    end
    self:RenderSide()
    local material = false
    for _, id in ipairs(ns.disenchantMaterials or {}) do if id == self.props.id then material = true end end
    if material then self.disenchant:Show() else self.disenchant:Hide() end
    self:Controls()
end
function UI:LayoutMap()
    local K = ns.TradeKit
    local placed, byKey, next = {}, {}, {[-1] = {}, [1] = {}}
    for _, card in ipairs(self.map.cards) do
        local height = card.kind == "center" and K.MapCard.Height(2) or K.MapCard.Height(#card.rows, card.limit)
        local entry = {card = card, height = height, x = card.side * card.depth * (CARD + GAP_X), y = 0}
        if card.kind ~= "center" then
            local parent = byKey[card.parent]
            local anchor = parent and parent.y or 0
            if parent and card.parentRow then anchor = parent.y + K.MapCard.HEAD + (card.parentRow - 1) * K.MapCard.ROW end
            local column = next[card.side]
            entry.y = math.max(column[card.depth] or 0, anchor)
            column[card.depth] = entry.y + height + GAP_Y
        end
        placed[#placed + 1] = entry
        byKey[card.key] = entry
    end
    local center = placed[1]
    local span = math.max(next[-1][1] or 0, next[1][1] or 0)
    center.y = math.max(0, math.floor((span - GAP_Y - center.height) / 2))
    self.placed, self.byKey = placed, byKey
end
local function toggle(row)
    if row.deeper then return "deeper" end
    if row.expand then return row.open and "open" or "closed" end
    return nil
end
local function wayName(member)
    local O, edge = ns.Obtain, member.edge
    if edge.kind == "disenchant" then return O.BandName(edge.ref) .. " " .. O.BandLevels(edge.ref) end
    if edge.inputs[1] then return ns.Markets.Name(edge.inputs[1][1]) end
    return O.Label(edge)
end
function UI:GroupRows(card)
    local K = ns.TradeKit
    local rows = {}
    for i, row in ipairs(card.rows) do
        if row.more then rows[i] = {text = ns.T("pathGroupMore", row.more), icon = K.theme.actionIcons.expand[1], toggle = "closed"}
        elseif row.less then rows[i] = {text = ns.T("pathGroupLess"), icon = K.theme.actionIcons.collapse[1], toggle = "open"}
        elseif row.member.kind == "use" then
            local gain = row.member.gain
            rows[i] = {itemID = row.id, text = ns.Markets.Name(row.id), value = signed(gain), tone = K.Tone(gain), toggle = toggle(row)}
        else
            local member = row.member
            local input = member.edge.inputs[1]
            rows[i] = {text = wayName(member), value = K.MoneyShort(member.cost), tone = member.cost and "secondary" or "off",
                itemID = input and input[1] or nil, icon = not input and select(10, ns.Compat.ItemInfo(card.item)) or nil,
                path = row.path, toggle = toggle(row)}
        end
    end
    return rows
end
function UI:BandRows(card)
    local K, band = ns.TradeKit, card.edge.ref
    local output = ns.Disenchant.Output(band, card.item)
    local count = output.minCount == output.maxCount and tostring(output.minCount) or (output.minCount .. "-" .. output.maxCount)
    local offer = card.offer
    return {{text = ns.T("pathBandLevels", ns.Obtain.BandLevels(band), band.skill), icon = K.theme.actionIcons.make[1]},
        {text = ns.T("pathBandChance", K.Chance(output.chance), count), itemID = card.item},
        offer and {text = ns.T("pathBandOffer", #offer.units), value = K.MoneyShort(offer.units[1]), tone = "secondary",
            icon = K.theme.actionIcons.buy[1]}
            or {text = ns.T("pathBandNoOffer"), tone = "off", icon = K.theme.actionIcons.buy[1]}}
end
function UI:CardProps(card)
    local K, O = ns.TradeKit, ns.Obtain
    local focus = self.focus and self.focus.key == card.key and not self.focus.row
    local props = {side = card.side, chosen = card.chosen, path = card.path, focus = focus, rows = {}, width = CARD,
        limit = card.limit}
    if card.kind == "center" then
        props.itemID, props.title, props.path = card.item, nil, true
        props.rows = {{text = ns.T("pathViaCost"), value = K.MoneyShort(card.cost), tone = card.cost and "text" or "secondary"},
            {text = ns.T("pathSell"), value = K.MoneyShort(card.sale), tone = card.sale and "text" or "secondary"}}
        return props
    end
    if card.kind == "more" then
        props.title, props.icon = ns.T("pathMoreUses", card.more), K.theme.actionIcons.go[1]
        return props
    end
    if card.kind == "group" then
        local rule, best = card.rule, card.best
        props.title = rule.byProfession and ns.T(rule.labelKey, O.ProfessionName(best.use.edge) or "", card.count)
            or ns.T(rule.labelKey, card.count)
        props.spellID = rule.spell or (best.kind == "use" and best.use.edge.spell) or nil
        if not props.spellID then props.icon = select(10, ns.Compat.ItemInfo(card.item)) end
        if card.side < 0 then props.value, props.tone = K.MoneyShort(card.cost), card.cost and "text" or "secondary"
        else props.value, props.tone = signed(card.gain), K.Tone(card.gain) end
        props.tip = ns.T("pathGroupTip")
        props.rows = self:GroupRows(card)
        return props
    end
    if card.kind == "use" then
        local use = card.use
        if use.edge.spell then props.spellID = use.edge.spell
        else props.icon = select(10, ns.Compat.ItemInfo(use.outputs[1].id)) end
        props.title = O.UseLabel(use)
        props.value, props.tone = signed(card.gain), K.Tone(card.gain)
        for i, row in ipairs(card.rows) do
            props.rows[i] = {itemID = row.id, text = ns.T("pathRowQty", O.Amount(row.qty), ns.Markets.Name(row.id)),
                value = K.MoneyShort(row.cost), tone = row.cost and "secondary" or "off", toggle = toggle(row)}
        end
        return props
    end
    props.value = K.MoneyShort(card.cost)
    props.tone = card.cost and "text" or "secondary"
    if card.kind == "way" and card.edge.kind == "disenchant" then
        props.title, props.icon = O.BandName(card.edge.ref), select(10, ns.Compat.ItemInfo(card.item))
        props.tip = ns.T("pathBandTip")
        props.rows = self:BandRows(card)
        return props
    end
    if card.kind == "way" then
        if card.edge.spell then props.spellID = card.edge.spell
        elseif card.edge.inputs[1] then props.icon = select(10, ns.Compat.ItemInfo(card.edge.inputs[1][1])) end
        props.title = O.Label(card.edge)
        for i, row in ipairs(card.rows) do
            props.rows[i] = {itemID = row.id, text = ns.T("pathRowQty", O.Amount(row.qty), ns.Markets.Name(row.id)),
                value = K.MoneyShort(row.cost), tone = row.cost and "secondary" or "off", path = row.path,
                toggle = toggle(row)}
        end
        return props
    end
    local source = card.source
    if source == "auction" then
        props.title, props.icon = ns.T("pathSourceAuction"), K.theme.actionIcons.buy[1]
        local row = card.rows[1]
        props.rows = {{itemID = card.item, text = ns.Markets.Name(card.item),
            value = row and row.units and ns.T("pathUnits", row.units) or nil, tone = "secondary"}}
    elseif source == "vendor" then
        props.title, props.icon = ns.T("pathSourceVendor"), K.theme.actionIcons.buy[1]
        for i, row in ipairs(card.rows) do
            local vendor = row.vendor
            props.rows[i] = {text = O.NpcName(vendor.npc) .. ", " .. O.ZoneName(vendor.zone), value = K.MoneyShort(vendor.price),
                icon = K.theme.actionIcons.buy[1]}
        end
    elseif source == "gather" then
        local gather = card.edge.ref
        props.title, props.spellID = ns.T("pathSourceGather", O.GatherName(gather), gather.skill or 0), GATHER_SPELLS[gather.profession]
        props.tone = card.cost and "secondary" or "off"
        props.tip = ns.T("pathGatherNote")
        for i, row in ipairs(card.rows) do
            props.rows[i] = {text = O.ZoneName(row.zone.zone), value = ns.T("pathShare", (row.zone.share or 0) * 100),
                spellID = GATHER_SPELLS[gather.profession]}
        end
    else
        props.title, props.icon, props.value = ns.T("pathSourceDrop"), select(10, ns.Compat.ItemInfo(card.item)), nil
        for i, row in ipairs(card.rows) do props.rows[i] = {text = ns.T(row.note), icon = select(10, ns.Compat.ItemInfo(card.item))} end
    end
    return props
end
function UI:CardAt(i)
    if not self.cards[i] then self.cards[i] = ns.TradeKit.MapCard:New(self.canvas.world, self.handlers) end
    return self.cards[i]
end
function UI:LinkAt(i)
    if not self.links[i] then self.links[i] = ns.TradeKit.Connector:New(self.canvas.world) end
    return self.links[i]
end
function UI:Cull()
    if not self.placed[1] or self.mode ~= "scheme" then return end
    local K = ns.TradeKit
    local left, top, right, bottom = self.canvas:Visible(0.5)
    local used, lines = 0, 0
    for _, entry in ipairs(self.placed) do
        local visible = entry.x + CARD >= left and entry.x <= right and entry.y + entry.height >= top and entry.y <= bottom
        entry.view = nil
        if visible then
            used = used + 1
            local card = self:CardAt(used)
            card.data = entry.card
            card.frame:ClearAllPoints()
            card.frame:SetPoint("TOPLEFT", self.canvas.world, "TOPLEFT", entry.x, -entry.y)
            card:SetProps(self:CardProps(entry.card))
            entry.view = card
        end
    end
    for i = used + 1, #self.cards do self.cards[i]:Hide(); self.cards[i].data = nil end
    for _, entry in ipairs(self.placed) do
        local card = entry.card
        local parent = card.parent and self.byKey[card.parent]
        if parent and (entry.view or parent.view) then
            lines = lines + 1
            local anchor = parent.y + K.MapCard.HEAD / 2
            if card.parentRow then anchor = parent.y + K.MapCard.HEAD + (card.parentRow - 0.5) * K.MapCard.ROW
            elseif parent.card.kind == "center" then anchor = parent.y + parent.height / 2 end
            local mid = entry.y + K.MapCard.HEAD / 2
            local props
            if card.side < 0 then props = {x0 = entry.x + CARD, y0 = mid, x1 = parent.x, y1 = anchor}
            else props = {x0 = parent.x + CARD, y0 = anchor, x1 = entry.x, y1 = mid} end
            props.tone = card.path and "selected" or "edge"
            self:LinkAt(lines):SetProps(props)
        end
    end
    for i = lines + 1, #self.links do self.links[i]:Hide() end
    self.reset:SetText(ns.T("pathZoom", math.floor(self.canvas.zoom * 100 + 0.5)))
end
function UI:Select(card, row)
    if not card then return end
    if card.kind == "more" then self.open[card.key] = true; self:Render(); return end
    local entry = row and card.rows[row]
    if entry and (entry.more or entry.less) then self:Toggle(card, row); return end
    self.focus = {key = card.key, row = row}
    local target = entry and entry.member or (not row and card) or nil
    if target and target.side < 0 and target.edge and not target.chosen then
        self.choice[target.item] = target.edge.key
        self:Render()
        return
    end
    self:Cull()
    self:RenderSide()
end
function UI:Center(card, row)
    if not card then return end
    local entry = row and card.rows[row]
    local id = entry and entry.id or (card.kind == "use" and card.use.outputs[1].id) or card.item
    if entry and entry.member and entry.member.kind == "use" then id = entry.member.use.outputs[1].id end
    if id then self:Push(id) end
end
function UI:Toggle(card, row)
    local entry = card and card.rows[row]
    if not entry then return end
    if entry.deeper then self:Push(entry.id); return end
    self.open[entry.key] = not entry.open
    self:Render()
end
function UI:FocusCard()
    return self.focus and self.cardByKey and self.cardByKey[self.focus.key] or nil
end
function UI:FocusTarget()
    local card = self:FocusCard()
    local row = card and self.focus.row and card.rows[self.focus.row]
    return row and row.member or card
end
function UI:FocusItem()
    local focus, card = self.focus, self:FocusCard()
    if not card then return self.props.id end
    if card.kind == "center" then return card.item end
    local row = focus.row and card.rows[focus.row]
    if row and not row.member then return row.id end
    return nil
end
function UI:Flags(limits, edge)
    local parts = {}
    if limits.cooldown then parts[#parts + 1] = ns.T("pathFlagCooldown") end
    if limits.lottery then
        parts[#parts + 1] = edge and edge.chance and ns.T("pathFlagLotteryChance", ns.TradeKit.Chance(edge.chance)) or ns.T("pathFlagLottery")
    end
    if (limits.missing or 0) > 0 then parts[#parts + 1] = ns.T("pathFlagMissing") end
    if limits.stale then parts[#parts + 1] = ns.T("pathFlagStale") end
    if limits.hidden then parts[#parts + 1] = ns.T("pathFlagHidden") end
    if limits.short then parts[#parts + 1] = ns.T("pathFlagShort") end
    if limits.own then parts[#parts + 1] = ns.T("pathFlagOwn") end
    return table.concat(parts, " | ")
end
function UI:Owners(edge)
    if not edge.spell then return nil end
    local K = ns.TradeKit
    local names = {}
    for _, owner in ipairs(ns.Obtain.KnownBy(edge)) do
        local tone = owner.known == true and "text" or (owner.known == false and "off" or "secondary")
        names[#names + 1] = K.Colored(owner.name .. (owner.other and ns.T("pathOtherFaction") or ""), tone)
    end
    if #names == 0 then return ns.T("pathKnownNone") end
    return ns.T("pathKnownBy", table.concat(names, ", "))
end
function UI:SideValues(values, note)
    local K = ns.TradeKit
    for i, entry in ipairs(self.values) do
        local value = values[i]
        entry.label:SetText(value and value[1] or "")
        entry.value:SetText(value and value[2] or "")
        entry.value:SetTextColor(unpack(K.theme[value and value[3] or "text"]))
    end
    self.note:SetWidth((self.side:GetWidth() or SIDE) - 24)
    self.note:SetText(note or "")
end
function UI:ItemValues(id)
    local K, O = ns.TradeKit, ns.Obtain
    local fee = ns.Fee()
    local node = id == self.props.id and self.selected or O.Evaluate(id, self.choice, ns.ReagentPolicy.Get())
    local sale, buy = O.Sale(id), nil
    for _, option in ipairs(O.Alternatives(id)) do if O.IsBuy(option.edge) then buy = option.cost end end
    local lines = {}
    local flags = self:Flags(node.limits, node.edge)
    if flags ~= "" then lines[#lines + 1] = flags end
    if node.limits.cooldown then lines[#lines + 1] = ns.T("pathCooldownLimit") end
    if node.limits.own then lines[#lines + 1] = ns.T("pathOwnNote") end
    if node.edge.yield and node.gross then
        lines[#lines + 1] = ns.T("pathGross", K.MoneyShort(node.gross), math.ceil(1 / node.edge.yield - 0.000001))
    end
    local made = false
    for _, edge in ipairs(O.Edges(id)) do if edge.kind ~= "disenchant" then made = true end end
    if not made then
        local _, best = ns.Reagents.Next(id, fee, 1)
        local first = best[1]
        if first then lines[#lines + 1] = ns.T("pathBestUseName", ns.Markets.Name((K.NextUses.Describe(id, first)))) end
        return {{ns.T("pathBuyPrice"), K.Money(buy), "text"},
            {ns.T("pathSell"), K.Money(sale and sale * (1 - fee)), sale and "text" or "secondary"},
            {ns.T("pathBestUse"), first and signed(first.gain) or "—", ns.TradeKit.Tone(first and first.gain)},
            {ns.T("pathNoAuction"), self:OffAuction(id), "text"}}, table.concat(lines, "\n")
    end
    local margin = sale and node.cost and sale * (1 - fee) - node.cost or nil
    local best = O.Best(id)
    return {{ns.T("pathBuyPrice"), K.Money(buy), "text"},
        {ns.T("pathViaCost"), K.Money(node.cost), node.cost and "text" or "secondary"},
        {ns.T("pathMargin"), margin and (K.Money(margin) .. (sale > 0 and ns.T("pathPercent", margin / sale * 100) or "")) or K.Money(nil),
            ns.TradeKit.Tone(margin)},
        {ns.T("pathBest"), O.Label(best) .. " " .. K.MoneyShort(O.Cost(id)), "text"}}, table.concat(lines, "\n")
end
function UI:OffAuction(id)
    local K, O = ns.TradeKit, ns.Obtain
    local vendor = O.Vendors(id)[1]
    if vendor then return ns.T("pathOffVendor", K.MoneyShort(vendor.price)) end
    local gather = O.Gather(id)
    if gather then return O.GatherName(gather) end
    for _, edge in ipairs(O.Edges(id)) do
        if edge.kind == "exchange" then return O.Label(edge) end
    end
    for _, option in ipairs(O.Alternatives(id)) do
        if option.edge.kind == "disenchant" then
            return option.cost and ns.T("pathOffDisenchant", K.MoneyShort(option.cost)) or ns.T("pathGroupDisenchantShort")
        end
    end
    return ns.T("pathNone")
end
function UI:CardValues(card)
    local K, O = ns.TradeKit, ns.Obtain
    local fee = ns.Fee()
    if card.kind == "use" then
        local use = card.use
        local lines = {O.UseLabel(use)}
        local owners = self:Owners(use.edge)
        if owners then lines[#lines + 1] = owners end
        local out = use.outputs[1]
        local sale = out and O.Sale(out.id)
        sale = sale and sale * (1 - fee)
        return {{ns.T("pathUseGain"), signed(card.gain), ns.TradeKit.Tone(card.gain)},
            {ns.T("pathUsePer"), O.Amount(use.count), "text"},
            {ns.T("pathUseOut"), out and O.Amount(out.qty) or "—", "text"},
            {ns.T("pathSell"), K.Money(sale), sale and "text" or "secondary"}}, table.concat(lines, "\n")
    end
    if card.kind == "group" then
        local best = card.best
        local name = best.kind == "use" and ns.Markets.Name(best.use.outputs[1].id) or ns.Obtain.Label(best.edge)
        local value = card.side < 0 and K.MoneyShort(card.cost) or signed(card.gain)
        return {{ns.T("pathGroupCount"), tostring(card.count), "text"},
            {ns.T("pathGroupBest"), value, card.side < 0 and (card.cost and "text" or "secondary") or K.Tone(card.gain)}},
            ns.T("pathGroupBestName", name) .. "\n" .. ns.T("pathGroupTip")
    end
    if card.edge and card.edge.kind == "disenchant" then
        local option, band = card.option, card.edge.ref
        local output = ns.Disenchant.Output(band, card.item)
        local offer = card.offer
        local lines = {ns.T("pathBandAbout", O.BandName(band), O.BandLevels(band), band.skill, K.Chance(output.chance))}
        local flags = self:Flags(option, card.edge)
        if flags ~= "" then table.insert(lines, 1, flags) end
        lines[#lines + 1] = offer and ns.T("pathBandFrom", #offer.units, K.MoneyShort(offer.units[1]), K.Ago(math.max(0, time() - offer.at)))
            or ns.T("pathBandMissing")
        lines[#lines + 1] = ns.T("pathBandTip")
        return {{ns.T("pathWayCost"), K.Money(option.cost), option.cost and "text" or "secondary"},
            {ns.T("pathWayGross"), K.Money(option.gross), "text"},
            {ns.T("pathBandItem"), K.Money(offer and offer.item), offer and "text" or "secondary"}}, table.concat(lines, "\n")
    end
    if card.source == "vendor" then
        local lines = {}
        for i, row in ipairs(card.rows) do
            local vendor = row.vendor
            if i <= 3 then
                local stock = (vendor.stock or 0) > 0 and ns.T("pathStock", vendor.stock) or ""
                lines[#lines + 1] = ns.T("pathVendorLine", O.NpcName(vendor.npc), O.ZoneName(vendor.zone), K.MoneyShort(vendor.price)) .. stock
            end
        end
        return {{ns.T("pathVendorPrice"), K.Money(card.cost), "text"}}, table.concat(lines, "\n")
    end
    if card.source == "gather" then
        local gather = card.edge.ref
        local zones = {}
        for i, row in ipairs(card.rows) do
            if i <= 3 then zones[#zones + 1] = ns.T("pathZoneLine", O.ZoneName(row.zone.zone), (row.zone.share or 0) * 100) end
        end
        return {{ns.T("pathGatherSkill"), tostring(gather.skill or 0), "text"},
            {ns.T("pathGatherValue"), K.Money(card.cost), card.cost and "text" or "secondary"}},
            ns.T("pathGatherNote") .. "\n" .. table.concat(zones, "\n")
    end
    if card.source == "drop" then
        local notes = {}
        for _, row in ipairs(card.rows) do notes[#notes + 1] = ns.T(row.note) end
        return {}, table.concat(notes, "\n")
    end
    if card.source == "auction" then
        local q = ns.Markets.Quote(card.item)
        return {{ns.T("pathAuctionPrice"), K.Money(card.cost), card.cost and "text" or "secondary"},
            {ns.T("pathAuctionUnits"), q and tostring(q.units or 0) or "—", "text"}}, card.cost and "" or ns.T("pathFlagMissing")
    end
    local option = card.option
    if not option then return {}, "" end
    local lines = {}
    local flags = self:Flags(option, card.edge)
    if flags ~= "" then lines[#lines + 1] = flags end
    local owners = self:Owners(card.edge)
    if owners then lines[#lines + 1] = owners end
    return {{ns.T("pathWayCost"), K.Money(option.cost), option.cost and "text" or "secondary"},
        {ns.T("pathWayGross"), K.Money(option.gross), "text"}}, table.concat(lines, "\n")
end
function UI:RenderSide()
    local K = ns.TradeKit
    local id = self:FocusItem()
    local card = self:FocusTarget()
    self.choose:Hide(); self.pin:Hide(); self.go:Hide(); self.recenter:Hide()
    if id then
        K.SetItemChoice(self.sideTitle, id, false)
        self.sideTitle.extraTip = ns.T("pathSideItemTip")
        local values, note = self:ItemValues(id)
        self:SideValues(values, note)
        local free = (self.side:GetHeight() or 400) - (id ~= self.props.id and 178 or 152) - 8
        local limit = math.max(1, math.min(K.NextUses.MAX, math.floor((free - 36) / 30)))
        self.next.frame:SetHeight(K.NextUses.Height(limit))
        self.next:SetProps({id = id, title = ns.T("pathNext"), limit = limit,
            pick = function(_, target) self:Push(target) end,
            open = function(entry) ns.PathWindow.Close(); K.OpenNext(entry) end})
        if id ~= self.props.id then
            self.recenter:SetPoint("TOPLEFT", self.side, "TOPLEFT", 12, -148)
            self.recenter:Show()
        end
        return
    end
    self.next:SetProps({})
    local props = self:CardProps(card)
    self.sideTitle.itemID, self.sideTitle.spellID, self.sideTitle.itemLink = nil, nil, nil
    self.sideTitle.icon:SetTexture(props.icon)
    if props.spellID then K.SetSpellChoice(self.sideTitle, props.spellID, false) end
    self.sideTitle.text:SetText(props.title or "")
    self.sideTitle.text:SetTextColor(unpack(K.theme.text))
    self.sideTitle.extraTip = nil
    self.sideTitle:Show()
    local values, note = self:CardValues(card)
    self:SideValues(values, note)
    if card.side < 0 and card.edge and not card.chosen then self.choose:Show() end
    if self:PinTarget(card) then
        self.pin:ClearAllPoints()
        if self.choose:IsShown() then self.pin:SetPoint("LEFT", self.choose, "RIGHT", 6, 0)
        else self.pin:SetPoint("TOPLEFT", self.side, "TOPLEFT", 12, -148) end
        self.pin:Show()
    end
    local band = card.edge and card.edge.kind == "disenchant"
    if card.kind == "use" or band then
        self.go:ClearAllPoints()
        if self.choose:IsShown() then self.go:SetPoint("LEFT", self.choose, "RIGHT", 6, 0)
        else self.go:SetPoint("TOPLEFT", self.side, "TOPLEFT", 12, -148) end
        self.go:SetText(ns.T(band and "pathOpenDisenchant" or "pathOpenSection"))
        self.go:Show()
    end
    if card.kind == "use" then
        self.recenter:ClearAllPoints(); self.recenter:SetPoint("LEFT", self.go, "RIGHT", 6, 0)
        self.recenter:Show()
    end
end
function UI:PinTarget(card)
    if not ns.MapPin or not card then return nil end
    local O = ns.Obtain
    if card.source == "vendor" then
        for _, row in ipairs(card.rows) do
            local vendor = row.vendor
            if vendor.zone and vendor.zone > 0 and vendor.x and vendor.y then
                return {title = O.NpcName(vendor.npc), zone = vendor.zone, level = vendor.level, points = {{vendor.x, vendor.y}}}
            end
        end
    elseif card.source == "gather" then
        for _, row in ipairs(card.rows) do
            if row.zone.points and row.zone.points[1] then
                return {title = ns.Markets.Name(card.item), zone = row.zone.zone, points = row.zone.points}
            end
        end
    end
    return nil
end
function UI:ShowOnMap()
    local target = self:PinTarget(self:FocusTarget())
    if target then ns.MapPin.Show(target) end
end
function UI:ChooseFocus()
    local card = self:FocusTarget()
    if card and card.edge then self:Choose(card.item, card.edge.key) end
end
function UI:CenterFocus()
    local id = self:FocusItem()
    local card = self:FocusTarget()
    if not id and card and card.kind == "use" then id = card.use.outputs[1].id end
    if id then self:Push(id) end
end
function UI:OpenFocus()
    local card = self:FocusTarget()
    if card and card.edge and card.edge.kind == "disenchant" then
        ns.PathWindow.Close()
        ns.DisenchantUI.Open(card.item, card.edge.ref.key)
        return
    end
    if not card or card.kind ~= "use" then return end
    local use, K = card.use, ns.TradeKit
    ns.PathWindow.Close()
    if use.kind == "mill" or use.kind == "prospect" then K.OpenProcess(use.kind, use.edge.ref)
    elseif use.kind == "recycle" then ns.Trader.OpenProcessing("recycle")
    elseif use.kind == "exchange" then ns.Trader:ShowSection("npc")
    elseif use.kind == "cut" then ns.Trader.OpenProfession("jewelry")
    else ns.Trader.OpenRecipe(use.edge.profession, use.edge.target) end
end
function UI:PathText(node)
    local parts = {ns.Obtain.Label(node.edge)}
    local function walk(current)
        for _, child in ipairs(current.children) do
            if not ns.Obtain.IsBuy(child.edge) then
                parts[#parts + 1] = ns.T("pathStep", ns.Markets.Name(child.id), ns.Obtain.Label(child.edge))
            end
            walk(child)
        end
    end
    walk(node)
    return table.concat(parts, "; ")
end
function UI:HideTable()
    for _, row in ipairs(self.pathRows) do row.frame:Hide(); row.path = nil end
    for _, row in ipairs(self.useRows) do row:Hide() end
    self.tableHead:Hide(); self.usesHead:Hide()
    self.empty:SetText("")
end
function UI:RenderTable(width)
    local K, O = ns.TradeKit, ns.Obtain
    self:HideTable()
    self.child:SetWidth(width)
    self.paths = O.Paths(self.props.id, #self.pathRows)
    local current = O.Signature(self.selected)
    local costX, marginX, limitsX = width - 340, width - 250, width - 156
    self.tableHead:ClearAllPoints(); self.tableHead:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, 0)
    self.tableHead:SetWidth(width); self.tableHead:Show()
    for key, label in pairs(self.headers) do
        label:ClearAllPoints()
        local x = key == "path" and 8 or (key == "cost" and costX or (key == "margin" and marginX or limitsX))
        label:SetPoint("TOPLEFT", self.tableHead, "TOPLEFT", x, -4)
        label:SetWidth(key == "path" and costX - 16 or (key == "limits" and 150 or 86))
        if key == "cost" or key == "margin" then label:SetJustifyH("RIGHT") else label:SetJustifyH("LEFT") end
    end
    local y = 24
    for i, row in ipairs(self.pathRows) do
        local path = self.paths[i]
        if path then
            row.path = path
            row.frame:ClearAllPoints(); row.frame:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -y)
            row.frame:SetWidth(width)
            row.frame:SetActive(O.Signature(path.node) == current)
            row.name:SetWidth(math.max(60, costX - 16)); row.name:SetText(self:PathText(path.node))
            row.cost:ClearAllPoints(); row.cost:SetPoint("TOPLEFT", row.frame, "TOPLEFT", costX, -4); row.cost:SetWidth(86)
            row.cost:SetText(K.Money(path.cost))
            row.cost:SetTextColor(unpack(K.theme[path.cost and "text" or "secondary"]))
            row.margin:ClearAllPoints(); row.margin:SetPoint("TOPLEFT", row.frame, "TOPLEFT", marginX, -4); row.margin:SetWidth(86)
            row.margin:SetText(K.Money(path.margin))
            row.margin:SetTextColor(unpack(K.theme[ns.TradeKit.Tone(path.margin)]))
            row.limits:ClearAllPoints(); row.limits:SetPoint("TOPLEFT", row.frame, "TOPLEFT", limitsX, -4); row.limits:SetWidth(150)
            local limits = self:Flags(path.limits, path.node.edge)
            local owners = self:Owners(path.node.edge)
            if owners then limits = limits == "" and owners or (limits .. " | " .. owners) end
            row.limits:SetText(limits)
            row.frame:Show()
            y = y + 36
        end
    end
    if #self.paths == 0 then self.empty:SetText(ns.T("pathNoPaths")) end
    local uses = O.Uses(self.props.id)
    local gains = O.UseGains(self.props.id, ns.Fee())
    for _, use in ipairs(uses) do use.gain = gains[use.key] end
    table.sort(uses, function(a, b)
        if a.gain ~= b.gain then
            if a.gain == nil then return false end
            if b.gain == nil then return true end
            return a.gain > b.gain
        end
        return a.index < b.index
    end)
    if #uses > 0 then
        y = y + 8
        self.usesHead:ClearAllPoints(); self.usesHead:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -y)
        self.usesHead:SetWidth(width); self.usesHead:Show()
        self.usesGain:ClearAllPoints(); self.usesGain:SetPoint("TOPRIGHT", self.usesHead, "TOPRIGHT", -8, -4)
        y = y + 24
        for i, row in ipairs(self.useRows) do
            local use = uses[i]
            if use then
                local out = use.outputs[1]
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -y)
                row:SetWidth(width)
                K.SetItemChoice(row, out.id, false)
                row.text:SetWidth(math.max(60, width - 150))
                row.text:SetText(ns.Markets.Name(out.id) .. " — " .. O.UseLabel(use))
                row.value:SetText(signed(use.gain)); row.value:SetTextColor(unpack(K.theme[ns.TradeKit.Tone(use.gain)]))
                y = y + 24
            end
        end
    end
    self.child:SetHeight(math.max(y + 8, (self.scroll:GetHeight() or 200)))
end
local W = {hosts = {}, names = {}}
ns.PathWindow = W
function W.Build(host)
    local K = ns.TradeKit
    local modal = K.Modal(host, "ManaCodePathWindow" .. (#W.names + 1))
    W.names[#W.names + 1] = modal
    local window = modal.window
    modal.item = K.ItemChoice(window, function() if modal.view.props then ns.MarketWindow.Open(modal.view.props.id) end end)
    modal.item:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -8)
    modal.item:SetWidth(360); modal.item.text:SetWidth(320)
    modal.item.text:SetFontObject("GameFontNormal")
    modal.caption = K.Label(window, ns.T("pathWindowTitle"), 0, 0, 200, "secondary")
    modal.caption:SetHeight(12); modal.caption:ClearAllPoints()
    modal.caption:SetPoint("LEFT", modal.item, "RIGHT", 10, 0)
    modal.view = UI:New(window)
    modal.view.header = modal.item
    modal.view.frame:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -40)
    modal.view.frame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -12, 6)
    W.hosts[host] = modal
    return modal
end
function W.Open(id)
    local trader = ns.Trader and ns.Trader.frame
    local host = trader and trader:IsVisible() and trader or UIParent
    if not host then return end
    local modal = W.hosts[host] or W.Build(host)
    W.frame, W.view = modal, modal.view
    ns.TradeKit.SetItemChoice(modal.item, id, false)
    modal:Show()
    modal:Layout()
    modal.view.history = {}
    modal.view.focused = false
    modal.view:SetProps({id = id})
end
function W.Close()
    for _, modal in pairs(W.hosts) do modal:Hide() end
end
function W.IsOpen()
    for _, modal in pairs(W.hosts) do if modal:IsShown() then return true end end
    return false
end
function W.Refresh()
    for _, modal in pairs(W.hosts) do
        if modal:IsShown() and modal.view.props then modal.view:Render() end
    end
end
function W.Controls()
    for _, modal in pairs(W.hosts) do
        if modal:IsShown() and modal.view.props then modal.view:Controls() end
    end
end
