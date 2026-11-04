local _, ns = ...
local K = ns.TradeKit
local Batch = {}
Batch.__index = Batch
K.BatchPanel = Batch
Batch.panels = {}
local HEAD = 22
local SUM = 96
local function busy()
    if ns.Trader and ns.Trader.Busy then return ns.Trader.Busy() and true or false end
    return ns.Scan.state.phase ~= "idle" or ns.Buy.Active() and true or false
end
local function compact(seg)
    local x = 2
    for _, b in ipairs(seg.order) do
        K.FitButton(b, K.theme.fitPad)
        b:ClearAllPoints(); b:SetPoint("LEFT", seg.frame, "LEFT", x, 0)
        x = x + (b:GetWidth() or 24) + 1
    end
    seg.frame:SetWidth(x + 1)
end
K.CompactSteps = compact
function Batch:Wheel(delta)
    if ScrollFrameTemplate_OnMouseWheel then ScrollFrameTemplate_OnMouseWheel(self.frame, delta) end
end
function Batch:Scrollable(frame)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) self:Wheel(delta) end)
end
function Batch:New(inspector, name, top)
    local panel = setmetatable({rows = {}, ways = {}, open = {}}, self)
    Batch.panels[#Batch.panels + 1] = panel
    panel.view = K.PanelScroll:New(inspector, name, 400, top)
    panel.frame, panel.child = panel.view.frame, panel.view.child
    panel.band = K.ActionBand:For(inspector, panel.view, true)
    local c = panel.child
    panel.head = K.Label(c, ns.T("batchReagents"), 0, 0, 160, "heading"); panel.head:SetHeight(14)
    panel.rule = K.Rule(c, 0)
    panel.product = K.ItemChoice(c, function()
        if panel.props and panel.props.recipe then K.Inspector.Switch("market", panel.props.recipe.raw) end
    end)
    panel.product:SetHeight(26)
    panel.product.icon:SetWidth(20); panel.product.icon:SetHeight(20)
    panel.product.text:SetHeight(12)
    panel.product.extraTip = ns.T("itemHistoryOpenTip")
    panel:Scrollable(panel.product)
    panel.scan = K.Button(c, ns.T("batchScan"), 60, function()
        if panel.props and panel.props.scan then panel.props.scan.run() end
    end, "quiet")
    panel.scan:SetHeight(20); K.FitButton(panel.scan, 18)
    K.Tooltip(panel.scan, ns.T("scanSelection"), ns.T("scanRecipeSelectionTip"))
    K.DisabledTip(panel.scan, ns.T("scanSelection"), ns.T("batchBusy"))
    panel.scan:Hide()
    panel.status = K.Label(c, "", 0, 0, 220, "secondary"); panel.status:SetHeight(12); panel.status:SetJustifyV("TOP")
    panel.qtyRow = ns.NewFrame("Frame", nil, panel.band.frame)
    panel.qtyRow:SetHeight(22); panel.qtyRow:Hide()
    panel.quantity = K.Edit(panel.qtyRow, 52)
    panel.quantity:SetNumeric(true); panel.quantity:SetMaxLetters(6)
    panel.quantity:SetPoint("LEFT", panel.qtyRow, "LEFT", 0, 0)
    panel.unit = K.Label(panel.qtyRow, ns.T("obtainPieces"), 0, 0, 24, "secondary"); panel.unit:SetHeight(12)
    panel.unit:ClearAllPoints(); panel.unit:SetPoint("LEFT", panel.quantity, "RIGHT", 4, 0)
    K.Tooltip(panel.quantity, ns.T("craftQuantity"), ns.T("craftQuantityTip"))
    K.LiveEdit(panel.quantity, function(edit)
        local value = tonumber(edit:GetText())
        if value and value >= 1 and value <= 100000 then panel:Emit("quantity", value)
        else edit:SetText(tostring(panel.plan and panel.plan.requested or 1)) end
    end)
    local steps = {}
    for i, n in ipairs({1, 10, 20, 100}) do steps[i] = {key = n, label = ns.T("batchStep", n)} end
    panel.steps = K.Segment(panel.qtyRow, steps, function(n)
        local edit = panel.quantity
        edit.liveAt = nil; edit:SetScript("OnUpdate", nil)
        edit:ClearFocus(); edit:SetText(tostring(n))
        panel:Emit("quantity", n)
    end)
    compact(panel.steps)
    panel.steps.frame:ClearAllPoints(); panel.steps.frame:SetPoint("RIGHT", panel.qtyRow, "RIGHT", 0, 0)
    for i = 1, 16 do
        local row = {buttons = {}}
        row.frame = K.ItemChoice(c, function() panel:Select(row.node and row.node.id) end)
        row.frame:SetHeight(30)
        row.frame.selected:SetDrawLayer("BORDER")
        row.frame.icon:SetWidth(22); row.frame.icon:SetHeight(22)
        row.frame.text:SetHeight(12)
        row.detail = K.Label(row.frame, "", 0, -16, 150, "secondary"); row.detail:SetHeight(12)
        row.sum = K.Label(row.frame, "", 0, -3, SUM); row.sum:SetHeight(12); row.sum:SetJustifyH("RIGHT")
        row.sum:ClearAllPoints(); row.sum:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT", -4, -3)
        row.expand = K.Button(row.frame, "+", 18, function()
            local key = row.node and "reagent:" .. row.node.id
            if key then panel.open[key] = not panel.open[key] or nil; panel:Render() end
        end, "quiet")
        row.expand:SetHeight(18); row.expand:SetPoint("LEFT", row.frame, "LEFT", 2, 0)
        row.expand.text:ClearAllPoints(); row.expand.text:SetPoint("CENTER", row.expand, "CENTER", 0, 0)
        for slot = 1, 2 do
            local button = K.IconButton(row.frame, "buy", function() panel:RowAction(row, slot) end, ns.T("tradeToBuyTitle"), ns.T("batchBuyRowTip"))
            if slot == 1 then button:SetPoint("RIGHT", row.frame, "RIGHT", -(SUM + 8), 0)
            else button:SetPoint("RIGHT", row.buttons[1], "LEFT", -4, 0) end
            button:Hide()
            row.buttons[slot] = button
        end
        panel:Scrollable(row.frame)
        row.frame:Hide()
        panel.rows[i] = row
    end
    panel.totalKeys, panel.totalValues = {}, {}
    for i = 1, 5 do
        local key = K.Label(c, "", 0, 0, 120); key:SetHeight(16); key:SetFontObject("GameFontHighlight")
        local value = K.Label(c, "", 0, 0, 140); value:SetHeight(16); value:SetJustifyH("RIGHT"); value:SetFontObject("GameFontHighlight")
        panel.totalKeys[i], panel.totalValues[i] = key, value
    end
    panel.marginTip = ns.NewFrame("Frame", nil, c)
    panel.marginTip:SetHeight(16); panel.marginTip:EnableMouse(true)
    K.Tooltip(panel.marginTip, ns.T("batchMargin"), "")
    panel.marginTip.tipFn = function() return table.concat(panel:Notes(), "\n") end
    panel:Scrollable(panel.marginTip)
    panel.pathNote = K.Label(c, ns.T("batchPathChosen"), 0, 0, 150, "secondary"); panel.pathNote:SetHeight(12)
    panel.pathReset = K.Button(c, ns.T("batchPathReset"), 66, function() panel:Emit("choice", nil) end, "quiet")
    panel.pathReset:SetHeight(20); K.FitButton(panel.pathReset, 18)
    K.Tooltip(panel.pathReset, ns.T("batchPathResetTitle"), ns.T("batchPathResetTip"))
    panel.frame:Hide()
    return panel
end
function Batch:Select(id)
    if id and id == self.selected then id = nil end
    self.selected = id
    if self.props and self.props.select then self.props.select(id) else self:Render() end
end
function Batch:RowAction(row, slot)
    local action = row.props and row.props.actions and row.props.actions[slot]
    local node = row.node
    if not action or not node then return end
    if action.key == "paths" then
        if ns.PathWindow then ns.PathWindow.Open(node.id) end
    elseif ns.BuyModal then ns.BuyModal.Open({{id = node.id, need = node.need}}) end
end
function Batch:Emit(key, value, id)
    if self.props and self.props.change then self.props.change(key, value, id) end
end
function Batch.Reagents()
    local ids = {}
    for _, panel in ipairs(Batch.panels) do
        local recipe = panel.props and panel.props.recipe
        for _, input in ipairs(recipe and recipe.inputs or {}) do ids[#ids + 1] = input[1] end
    end
    return ids
end
function Batch:SetProps(props)
    if not self.props or not props.recipe or not self.props.recipe or self.props.recipe.raw ~= props.recipe.raw then
        self.selected, self.open = nil, {}
    end
    if props.selected ~= nil then self.selected = props.selected or nil end
    self.props = props; self:Render()
end
function Batch:Missing()
    local missing, seen = {}, {}
    for _, node in ipairs(self.top or {}) do
        if not node.crafted and node.need > 0 and not ns.vendorPrices[node.id] then
            if not seen[node.id] then
                seen[node.id] = {id = node.id, need = 0}
                missing[#missing + 1] = seen[node.id]
            end
            seen[node.id].need = seen[node.id].need + node.need
        end
    end
    return missing
end
function Batch:MakeCount(station)
    local crafts = math.max(1, self.plan and self.plan.crafts or 1)
    if not station then return crafts end
    if station.verb then return 1 end
    if station.available < 1 then return crafts end
    return math.min(crafts, station.available)
end
function Batch:Make()
    local spell = self.props and self.props.recipe and self.props.recipe.spell
    if not spell then return end
    K.FlushEdits(self.quantity)
    ns.Recipes.Craft(spell, self:MakeCount(ns.Recipes.Station(spell)))
end
function Batch:Place(frame, x, y)
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", self.child, "TOPLEFT", K.theme.inset + (x or 0), -y); frame:Show()
end
function Batch:PlaceRight(frame, y)
    frame:ClearAllPoints(); frame:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", -K.theme.inset, -y); frame:Show()
end
function Batch:Head(y)
    local head, rule = self.head, self.rule
    self:Place(head, 0, y + 2)
    rule:ClearAllPoints()
    rule:SetPoint("TOPLEFT", self.child, "TOPLEFT", K.theme.inset, -(y + 18))
    rule:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", -K.theme.inset, -(y + 18))
    return y + HEAD
end
function Batch.Cheaper(id, price)
    if not price or not ns.Obtain or not ns.Obtain.Alternatives then return nil end
    for _, option in ipairs(ns.Obtain.Alternatives(id)) do
        local kind = option.edge and option.edge.kind
        if kind ~= "buy" and kind ~= "vendor" and not option.hidden and option.cost and (option.missing or 0) == 0
            and option.cost < price then
            return option
        end
    end
end
function Batch:Detail(node, price)
    local quote = node.quote
    local detail, tone, tip = ns.T("batchNeed", node.need, node.count), "text", {}
    local cheaper = not node.crafted and node.need > 0 and Batch.Cheaper(node.id, price) or nil
    if cheaper then tip[1] = ns.T("batchCheaper", (ns.Obtain.Way(cheaper.edge)), K.Money(cheaper.cost)) end
    if node.crafted then
        local way = node.edge and ns.Obtain and (ns.Obtain.Way(node.edge))
        return ns.T("batchNeedMake", node.count, node.crafts or 0) .. (way and " | " .. way or ""), "text", tip, nil
    elseif node.need == 0 then return ns.T("batchHave", node.own, node.count), "positive", tip, cheaper
    elseif not price then tone = "negative"
    elseif quote.vendor then detail = detail .. " | " .. ns.T("batchWayVendor")
    elseif (quote.units or 0) == 0 and not quote.manual then
        detail, tone = detail .. " | " .. ns.T("batchNotOnAuction"), "negative"
    elseif not quote.manual and not ns.Markets.Fresh(node.id) then
        local age = ns.Markets.Age(node.id)
        detail = detail .. " | " .. ns.T("batchWayAuction") .. (age and ", " .. K.Ago(age) or "")
    else detail = detail .. " | " .. ns.T("batchWayAuction") end
    return detail, tone, tip, cheaper
end
function Batch:RenderRow(row, node, width)
    row.frame:SetWidth(width)
    local offset = 24
    local buyable = not node.crafted and node.need > 0 and not ns.vendorPrices[node.id]
    local actions = {}
    if buyable then actions[#actions + 1] = {key = "buy", label = ns.T("tradeToBuy"), icon = "buy", tip = ns.T("batchBuyRowTip")} end
    local quote = node.quote
    local price = quote and quote.miss == 0 and quote.complete ~= false and quote.price or nil
    local detail, tone, tip, cheaper = self:Detail(node, price)
    local unpriced = not node.crafted and node.need > 0 and not price
    local sum = unpriced and ns.T("batchNoPrice") or (node.crafted or node.need > 0) and K.Money(node.crafted and node.value or node.cash) or ""
    row.sum:SetWidth(SUM); row.sum:SetText(sum)
    row.sum:SetTextColor(unpack(K.theme[unpriced and "negative" or "text"]))
    local measured = sum ~= "" and row.sum.GetStringWidth and row.sum:GetStringWidth()
    local sumWidth = sum == "" and 0 or math.min(SUM, measured and math.ceil(measured) + 2 or 70)
    row.sum:SetWidth(math.max(1, sumWidth))
    local column = sumWidth
    local expandable = K.ObtainPanel.HasWays(node.id)
    if expandable then
        row.expand:SetText(self.open["reagent:" .. node.id] and "-" or "+"); row.expand:Show()
    else row.expand:Hide() end
    if cheaper then detail = detail .. " | " .. K.Colored(ns.T("batchCheaperMark"), "positive") end
    row.buttons[1]:ClearAllPoints(); row.buttons[1]:SetPoint("RIGHT", row.frame, "RIGHT", -(column + 8), 0)
    local textWidth = math.max(1, width - offset - 26 - column - 12 - 26 * #actions)
    local detailWidth = #actions == 0 and math.max(1, width - offset - 26 - 4) or textWidth
    K.SetItemChoice(row.frame, node.id, node.id == self.selected)
    row.frame.extraTip = tip[1]
    row.frame.icon:ClearAllPoints(); row.frame.icon:SetPoint("LEFT", row.frame, "LEFT", offset, 0)
    row.frame.text:ClearAllPoints(); row.frame.text:SetPoint("TOPLEFT", row.frame, "TOPLEFT", offset + 26, -3)
    row.frame.text:SetWidth(textWidth)
    row.detail:ClearAllPoints(); row.detail:SetPoint("TOPLEFT", row.frame, "TOPLEFT", offset + 26, -16)
    row.detail:SetWidth(detailWidth)
    row.detail:SetText(detail)
    row.detail:SetTextColor(unpack(K.theme[tone]))
    row.props = {active = node.id == self.selected, actions = actions}
    K.RevealActions(row)
end
function Batch:Render()
    local p = self.props
    if not p or not p.recipe then
        self.frame:Hide(); self.band:SetProps({actions = {}}); self.buy, self.ready, self.make = nil, nil, nil
        return
    end
    self.frame:Show()
    local o = p.options or {}
    local plan = ns.CraftPlan.Build(p.recipe, {make = {}, ignore = {}, craftAll = false, owned = true,
        fee = ns.Fee(), quantity = o.quantity, choice = o.choice})
    self.plan = plan
    self.top = {}
    for _, node in ipairs(plan.rows) do
        if node.depth == 0 then self.top[#self.top + 1] = node end
    end
    self:Controls()
    local width = self.view:Fit(self.height or 400)
    local height = self:Lay(width)
    local fitted = self.view:Fit(height)
    if fitted ~= width then self:Lay(fitted); self.view:Fit(self.height) end
end
function Batch:Lay(width)
    local p, plan = self.props, self.plan
    local inner = width - 2 * K.theme.inset
    self.child:SetWidth(width)
    self.status:SetWidth(inner)
    local y = 4
    if p.header and p.header ~= p.recipe.raw then
        self.product:SetWidth(inner)
        self.product.text:ClearAllPoints(); self.product.text:SetPoint("LEFT", self.product, "LEFT", 26, 0)
        self.product.text:SetWidth(inner - 28)
        self.product.icon:ClearAllPoints(); self.product.icon:SetPoint("LEFT", self.product, "LEFT", 0, 0)
        K.SetItemChoice(self.product, p.recipe.raw, false)
        self:Place(self.product, 0, y)
        y = y + 28
    else self.product:Hide() end
    local status = ""
    if p.recipe.count > 1 then status = ns.T("batchOutput", p.recipe.count) .. " | " .. ns.T("batchCrafts", plan.crafts) end
    if plan.extra > 0 then status = status .. ns.T("craftExtra", plan.extra) end
    status = (status .. (p.note or "")):gsub("^ | ", "")
    if status ~= "" then
        self.status:SetText(status)
        local wide = (self.status.GetStringWidth and self.status:GetStringWidth() or 0) > inner
        self.status:SetHeight(wide and 26 or 12)
        self:Place(self.status, 0, y)
        y = y + (wide and 30 or 18)
    else self.status:SetText(""); self.status:Hide() end
    y = self:Head(y + 4)
    if p.scan then
        K.ScanTip(self.scan, ns.T("scanSelection"), ns.T("scanRecipeSelectionTip"), p.scan.sources, false)
        self:PlaceRight(self.scan, y - HEAD - 2)
    else self.scan:Hide() end
    local used = 0
    for i, row in ipairs(self.rows) do
        local node = self.top[i]
        row.node = node
        if node then
            self:Place(row.frame, 0, y)
            self:RenderRow(row, node, inner)
            y = y + 30
            if self.open["reagent:" .. node.id] then
                for _, line in ipairs(K.ObtainPanel.Flatten(self.open, K.ObtainPanel.Others(node.id), {})) do
                    used = used + 1
                    local way = self.ways[used] or K.ObtainPanel.NewRow(self, self.child)
                    self.ways[used] = way
                    K.ObtainPanel.RenderLine(self, way, line, inner, 1)
                    self:Place(way.frame, 0, y)
                    y = y + 32
                end
            end
        else row.frame:Hide() end
    end
    for i = used + 1, #self.ways do self.ways[i].frame:Hide(); self.ways[i].line = nil end
    if plan.chosen > 0 then
        self.pathNote:SetWidth(math.max(80, inner - (self.pathReset:GetWidth() or 66) - 6))
        self:Place(self.pathNote, 0, y + 5)
        self:PlaceRight(self.pathReset, y + 1)
        y = y + 24
    else self.pathNote:Hide(); self.pathReset:Hide() end
    y = self:RenderTotals(y + 6, inner)
    self.height = y
    self.child:SetHeight(y)
    return y
end
function Batch:RenderTotals(y, width)
    local plan = self.plan
    local fee = math.floor(ns.Fee() * 100 + 0.5)
    local function round(copper) return copper and math.floor(copper + 0.5) end
    local cost, unitCost = round(plan.cost), round(plan.unitCost)
    local totals = {{ns.T("batchCost"), plan.cost, "text", true},
        {ns.T("batchUnitCost"), unitCost, "text", unitCost ~= cost},
        {ns.T("batchCash"), plan.cash, "text", round(plan.cash) ~= cost},
        {ns.T("batchRevenue", fee), plan.revenue, "text", true},
        {ns.T("batchMargin"), plan.margin, plan.margin and K.Tone(plan.margin) or "negative", true}}
    for i, total in ipairs(totals) do
        local key, value = self.totalKeys[i], self.totalValues[i]
        if total[4] then
            value:SetWidth(140)
            value:SetText(i == #totals and not total[2] and ns.T("craftBatchMissing", plan.missing) or K.Money(total[2]))
            local used = value.GetStringWidth and value:GetStringWidth()
            local valueWidth = math.min(140, used and math.ceil(used) + 2 or 100)
            value:SetWidth(valueWidth)
            key:SetWidth(math.max(60, width - valueWidth - 8))
            self:Place(key, 0, y)
            self:PlaceRight(value, y)
            key:SetText(total[1])
            value:SetTextColor(unpack(K.theme[total[3]]))
            if i == #totals then
                self.marginTip:ClearAllPoints()
                self.marginTip:SetPoint("TOPLEFT", self.child, "TOPLEFT", K.theme.inset, -y)
                self.marginTip:SetWidth(width); self.marginTip:Show()
            end
            y = y + 18
        else key:Hide(); value:Hide() end
    end
    return y + 8
end
function Batch:Notes()
    local plan, notes = self.plan, {}
    if plan.stale > 0 then notes[#notes + 1] = ns.T("batchStaleTotal", plan.stale) end
    if plan.cost then
        notes[#notes + 1] = plan.short > 0 and ns.T("batchSupplyShort", plan.short) or ns.T("batchSupplyOk")
    else notes[#notes + 1] = ns.T("craftBatchMissing", plan.missing) end
    return notes
end
function Batch:Controls()
    if not self.props or not self.props.recipe or not self.plan then return end
    if busy() then self.scan:Disable() else self.scan:Enable() end
    local buy = self:BuyAction()
    local ready = self:ReadyAction()
    local make = self:MakeAction()
    local actions = {}
    if buy then actions[#actions + 1] = buy end
    actions[#actions + 1] = ready
    if make then
        actions[#actions + 1] = make
        if not (buy and buy.main) and not make.reason then make.main = true end
    end
    if not self.quantity:HasFocus() then self.quantity:SetText(tostring(self.plan.requested)) end
    self.steps:Select(self.plan.requested)
    self.band:SetProps({top = self.qtyRow, actions = actions})
    local _, buyButton = self.band:Find("buy")
    local _, readyButton = self.band:Find("ready")
    local _, makeButton = self.band:Find("make")
    self.buy, self.ready, self.make = buyButton, readyButton, makeButton
end
function Batch:MakeAction()
    local p = self.props
    local spell = p.recipe.spell
    if not spell then return nil end
    if p.known == false then
        return {key = "make", label = ns.T("batchMakeButton"), tip = ns.T("batchUnlearnedTip"),
            reason = ns.T("batchUnlearned"), fn = function() end}
    end
    local station, why = ns.Recipes.Station(spell)
    local reason = why and ns.T(why) or station.available < 1 and ns.T("batchMakeShort") or nil
    local count = self:MakeCount(station)
    local tip = ns.T("batchMakeCountTip", count)
    if station and station.verb then tip = tip .. "\n\n" .. ns.T("batchMakeVerbTip") end
    return {key = "make", label = ns.T("batchMakeButton"), tip = tip, reason = reason, fn = function() self:Make() end}
end
function Batch:ReadyAction()
    local plan, raw = self.plan, self.props.recipe.raw
    local reason = ns.vendorPrices[raw] and ns.T("cacheVendor") or busy() and ns.T("batchBusy") or nil
    return {key = "ready", label = ns.T("batchReadyButton"), title = ns.T("batchReadyTitle"),
        tip = ns.T("batchReadyTip", plan.requested), reason = reason,
        fn = function()
            K.FlushEdits(self.quantity)
            if ns.BuyModal then ns.BuyModal.Open({{id = raw, need = self.plan.requested}}) end
        end}
end
function Batch:BuyAction()
    local p, plan = self.props, self.plan
    local missing = self:Missing()
    local margin = plan.margin
    self.queueNote = nil
    if margin == nil and p.scan then
        self.action = "scan"
        return {key = "buy", label = ns.T("cacheComplete"), title = ns.T("batchScanPrices"),
            tip = ns.T("scanRecipeSelectionTip"), sources = p.scan.sources,
            reason = busy() and ns.T("batchBusy") or nil, fn = function() p.scan.run() end}
    end
    if #missing == 0 then self.action = nil; return nil end
    self.action = "buy"
    local names = {}
    for i = 1, math.min(#missing, 4) do names[i] = ns.Markets.Name(missing[i].id) .. " x" .. missing[i].need end
    if #missing > 4 then names[#names + 1] = ns.T("batchMoreItems", #missing - 4) end
    self.queueNote = ns.T("batchBuyList", table.concat(names, ", "))
    local warning = margin == nil and ns.T("batchMarginUnknown")
        or margin <= 0 and ns.T("batchMarginLoss", K.Money(margin)) or nil
    return {key = "buy", label = ns.T("batchReagentsButton"), title = ns.T("batchBuyMissing"),
        tip = (warning and warning .. "\n\n" or "") .. self.queueNote .. "\n\n" .. ns.T("batchBuyTip"),
        main = margin ~= nil and margin > 0, reason = busy() and ns.T("batchBusy") or nil,
        fn = function()
            K.FlushEdits(self.quantity)
            if ns.BuyModal then ns.BuyModal.Open(self:Missing()) end
        end}
end
