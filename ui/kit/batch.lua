local _, ns = ...
local K = ns.TradeKit
local Batch = {}
Batch.__index = Batch
K.BatchPanel = Batch
Batch.panels = {}
local batchSerial = 0
local BUY_BAND = 32
local EDGE = 6
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
function Batch:Wheel(delta)
    if ScrollFrameTemplate_OnMouseWheel then ScrollFrameTemplate_OnMouseWheel(self.scroll, delta) end
end
function Batch:Scrollable(frame)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) self:Wheel(delta) end)
end
function Batch:New(parent)
    batchSerial = batchSerial + 1
    local panel = setmetatable({rows = {}, queue = 1}, self)
    Batch.panels[#Batch.panels + 1] = panel
    panel.frame = ns.NewFrame("Frame", nil, parent)
    panel.scroll = ns.NewFrame("ScrollFrame", "ManaCodeBatchScroll" .. batchSerial, panel.frame, "UIPanelScrollFrameTemplate")
    panel.scroll:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", 0, 0)
    panel.scroll:SetPoint("BOTTOMRIGHT", panel.frame, "BOTTOMRIGHT", 0, BUY_BAND)
    panel.scroll.scrollBarHideable = 1
    panel.child = ns.NewFrame("Frame", nil, panel.scroll)
    panel.child:SetWidth(220); panel.child:SetHeight(400)
    panel.scroll:SetScrollChild(panel.child)
    panel:Scrollable(panel.child)
    local c = panel.child
    panel.product = K.ItemChoice(c, function()
        if panel.props and panel.props.recipe then K.Inspector.Switch("market", panel.props.recipe.raw) end
    end)
    panel.product:SetHeight(30)
    panel.product.icon:SetWidth(22); panel.product.icon:SetHeight(22)
    panel.product.text:ClearAllPoints(); panel.product.text:SetPoint("TOPLEFT", panel.product, "TOPLEFT", 28, -3)
    panel.product.text:SetHeight(12)
    panel.product.extraTip = ns.T("itemHistoryOpenTip")
    panel.productNote = K.Label(panel.product, "", 28, -16, 120, "secondary"); panel.productNote:SetHeight(12)
    panel.margin = K.Label(panel.product, "", 0, -16, 100); panel.margin:SetHeight(12); panel.margin:SetJustifyH("RIGHT")
    panel.margin:ClearAllPoints(); panel.margin:SetPoint("TOPRIGHT", panel.product, "TOPRIGHT", -2, -16)
    panel:Scrollable(panel.product)
    panel.scan = K.Button(c, ns.T("batchScan"), 60, function()
        if panel.props and panel.props.scan then panel.props.scan.run() end
    end, "quiet")
    panel.scan:SetHeight(20); K.FitButton(panel.scan, 18)
    K.Tooltip(panel.scan, ns.T("scanSelection"), ns.T("scanRecipeSelectionTip"))
    K.DisabledTip(panel.scan, ns.T("scanSelection"), ns.T("batchBusy"))
    panel.scan:Hide()
    panel.status = K.Label(c, "", 0, 0, 220, "secondary"); panel.status:SetHeight(12); panel.status:SetJustifyV("TOP")
    panel.sourceChip = K.Chip(c, ns.T("batchMakeChip"), function(checked) panel:Emit("craftAll", checked) end)
    K.Tooltip(panel.sourceChip, ns.T("batchMakeChip"), ns.T("batchMakeAllTip"))
    panel.ownedChip = K.Chip(c, ns.T("batchOwnedChip"), function(checked) panel:Emit("owned", checked) end)
    K.Tooltip(panel.ownedChip, ns.T("craftOwnedTitle"), ns.T("craftOwnedTip"))
    panel.quantityLabel = K.Label(c, ns.T("batchQuantity"), 0, 0, 80, "secondary"); panel.quantityLabel:SetHeight(12)
    panel.quantity = K.Edit(c, 44)
    panel.quantity:SetNumeric(true); panel.quantity:SetMaxLetters(6)
    K.Tooltip(panel.quantity, ns.T("craftQuantity"), ns.T("craftQuantityTip"))
    K.LiveEdit(panel.quantity, function(edit)
        local value = tonumber(edit:GetText())
        if value and value >= 1 and value <= 100000 then panel:Emit("quantity", value)
        else edit:SetText(tostring(panel.plan and panel.plan.requested or 1)) end
    end)
    local steps = {}
    for i, n in ipairs({1, 10, 20, 100}) do steps[i] = {key = n, label = ns.T("batchStep", n)} end
    panel.steps = K.Segment(c, steps, function(n)
        local edit = panel.quantity
        edit.liveAt = nil; edit:SetScript("OnUpdate", nil)
        edit:ClearFocus(); edit:SetText(tostring(n))
        panel:Emit("quantity", n)
    end)
    compact(panel.steps)
    panel.reagentsTitle = K.Label(c, ns.T("batchReagents"), 0, 0, 200, "heading"); panel.reagentsTitle:SetHeight(14)
    for i = 1, 16 do
        local row = {buttons = {}}
        row.frame = K.ItemChoice(c, function() panel:Select(row.node and row.node.id) end)
        row.frame:SetHeight(30)
        row.frame.selected:SetDrawLayer("BORDER")
        row.frame.icon:SetWidth(22); row.frame.icon:SetHeight(22)
        row.frame.text:SetHeight(12)
        row.detail = K.Label(row.frame, "", 0, -16, 150, "secondary"); row.detail:SetHeight(12)
        row.price = K.Label(row.frame, "", 0, -3, 80); row.price:SetHeight(12); row.price:SetJustifyH("RIGHT")
        row.price:ClearAllPoints(); row.price:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT", -4, -3)
        row.sum = K.Label(row.frame, "", 0, -16, 80, "secondary"); row.sum:SetHeight(12); row.sum:SetJustifyH("RIGHT")
        row.sum:ClearAllPoints(); row.sum:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT", -4, -16)
        row.expand = K.IconButton(row.frame, "make", function()
            if row.node then panel:Emit("make", not row.node.crafted, row.node.id) end
        end, ns.T("batchMakeTitle"), ns.T("batchMakeTip"))
        for slot = 1, 2 do
            local button = K.IconButton(row.frame, "buy", function() panel:RowAction(row, slot) end, ns.T("tradeBuy"), ns.T("batchBuyRowTip"))
            if slot == 1 then button:SetPoint("RIGHT", row.frame, "RIGHT", -88, 0)
            else button:SetPoint("RIGHT", row.buttons[1], "LEFT", -4, 0) end
            button:Hide()
            row.buttons[slot] = button
        end
        panel:Scrollable(row.frame)
        row.frame:Hide()
        panel.rows[i] = row
    end
    panel:NewTools(c)
    panel.totalKeys, panel.totalValues = {}, {}
    for i = 1, 5 do
        local key = K.Label(c, "", 0, 0, 120, "secondary"); key:SetHeight(12)
        local value = K.Label(c, "", 0, 0, 100); value:SetHeight(12); value:SetJustifyH("RIGHT")
        panel.totalKeys[i], panel.totalValues[i] = key, value
    end
    panel.staleNote = K.Label(c, "", 0, 0, 220); panel.staleNote:SetHeight(12)
    panel.staleNote:SetTextColor(unpack(K.theme.accent))
    panel.pathNote = K.Label(c, ns.T("batchPathChosen"), 0, 0, 150, "secondary"); panel.pathNote:SetHeight(12)
    panel.pathReset = K.Button(c, ns.T("batchPathReset"), 66, function() panel:Emit("choice", nil) end, "quiet")
    panel.pathReset:SetHeight(20); K.FitButton(panel.pathReset, 18)
    K.Tooltip(panel.pathReset, ns.T("batchPathResetTitle"), ns.T("batchPathResetTip"))
    panel.supply = K.Label(c, "", 0, 0, 220); panel.supply:SetHeight(12)
    panel.buy = K.Button(panel.frame, "", 220, function() panel:Act() end, "main")
    panel.buy:SetPoint("BOTTOMLEFT", panel.frame, "BOTTOMLEFT", 0, 2)
    K.Tooltip(panel.buy, ns.T("batchBuyMissing"), ns.T("batchBuyTip"))
    panel.frame:Hide()
    return panel
end
function Batch:NewTools(c)
    local tools = ns.NewFrame("Frame", nil, c)
    tools:SetHeight(90); tools:Hide()
    self.tools = tools
    tools.stock = K.Label(tools, "", 0, 0, 220, "secondary"); tools.stock:Hide()
    tools.label = K.Label(tools, ns.T("alchemyPriceLabel"), 0, 0, 220, "secondary"); tools.label:SetHeight(12)
    tools.edit = K.Edit(tools, 52)
    tools.edit:SetPoint("TOPLEFT", tools, "TOPLEFT", 0, -14)
    K.Tooltip(tools.edit, ns.T("alchemyPriceLabel"), ns.T("alchemyPriceHint"))
    tools.edit:SetScript("OnEnterPressed", function() self:SavePrice() end)
    tools.save = K.Button(tools, ns.T("alchemySavePrice"), 66, function() self:SavePrice() end)
    tools.save:SetHeight(22); tools.save:SetPoint("LEFT", tools.edit, "RIGHT", 4, 0)
    tools.reset = K.Button(tools, ns.T("batchPriceReset"), 66, function()
        if self.selected then ns.Alchemy.SetPrice(self.selected, nil); self.editID = nil; self:Emit("price") end
    end, "quiet")
    tools.reset:SetHeight(22); tools.reset:SetPoint("LEFT", tools.save, "RIGHT", 4, 0)
    K.Tooltip(tools.reset, ns.T("batchPriceReset"), ns.T("batchPriceResetTip"))
    tools.own = K.Chip(tools, ns.T("batchOwnChip"), function(checked)
        if self.selected then self:Emit("ignore", checked, self.selected) end
    end)
    tools.own:SetHeight(22)
    K.Tooltip(tools.own, ns.T("batchOwnChip"), ns.T("batchOwnTip"))
    tools.open = K.Button(tools, ns.T("reagentOpen"), 110, function()
        if self.selected and self.props.reagent then self.props.reagent.open(self.selected) end
    end, "quiet")
    tools.open:SetHeight(22)
    K.Tooltip(tools.open, ns.T("reagentOpen"), ns.T("reagentOpenTip"))
    tools.uses = K.NextUses:New(tools)
    self:Scrollable(tools)
end
function Batch:SavePrice()
    local edit, id = self.tools.edit, self.selected
    local price = tonumber((edit:GetText():gsub(",", ".")))
    if not id or not price or not ns.Alchemy.SetPrice(id, price * 10000) then
        ns.say(ns.T("alchemyInvalidPrice")); return
    end
    edit:ClearFocus()
    self.editID = nil
    self:Emit("price")
end
function Batch:Select(id)
    self.selected = id
    if self.props and self.props.select then self.props.select(id) else self:Render() end
end
function Batch:RowAction(row, slot)
    local action = row.props and row.props.actions and row.props.actions[slot]
    local node = row.node
    if not action or not node then return end
    if action.key == "paths" then
        if ns.PathWindow then ns.PathWindow.Open(node.id) end
    elseif self.props.buy then self.props.buy(node.id, node.need) end
end
function Batch.Holders(id)
    local here, _, others = ns.Inventory.Stock(id)
    if #others == 0 then return nil end
    local parts = {}
    if here > 0 then parts[1] = ns.T("batchHolder", UnitName("player") or "", here) end
    for _, h in ipairs(others) do parts[#parts + 1] = ns.T("batchHolder", h.name, h.bags + h.bank + h.mail) end
    return ns.T("batchHolders", table.concat(parts, ", "))
end
function Batch:PlaceTools(node, y, width)
    local tools = self.tools
    tools:SetWidth(width)
    self:Place(tools, 22, y)
    local vendor = ns.vendorPrices[node.id]
    local editable = not vendor and ns.Crafting.IsInput(node.id)
    local quote = ns.Alchemy.Quote(node.id)
    local top = 0
    local who = not vendor and self.props.options.owned and Batch.Holders(node.id)
    if who then
        tools.stock:SetWidth(width); tools.stock:SetText(who); tools.stock:Show()
        top = math.ceil(tools.stock:GetStringHeight() or 12) + 6
    else tools.stock:Hide() end
    tools.label:ClearAllPoints(); tools.label:SetPoint("TOPLEFT", tools, "TOPLEFT", 0, -top)
    tools.edit:ClearAllPoints(); tools.edit:SetPoint("TOPLEFT", tools, "TOPLEFT", 0, -top - 14)
    if vendor then
        tools.label:SetText(ns.T("vendorResaleCost", K.Money(vendor))); tools.label:Show()
        tools.edit:Hide(); tools.save:Hide(); tools.reset:Hide()
        top = top + 16
    elseif editable then
        tools.label:SetText(ns.T("alchemyPriceLabel")); tools.label:Show()
        tools.edit:Show(); tools.save:Show()
        if quote and quote.manual then tools.reset:Show() else tools.reset:Hide() end
        if self.editID ~= node.id and not tools.edit:HasFocus() then
            tools.edit:SetText(quote and quote.manual and K.Decimal(quote.price / 10000, 4) or "")
            self.editID = node.id
        end
        top = top + 40
    else tools.label:Hide(); tools.edit:Hide(); tools.save:Hide(); tools.reset:Hide() end
    tools.own:ClearAllPoints()
    tools.own:SetPoint("TOPLEFT", tools, "TOPLEFT", 0, -top)
    tools.own:SetChecked(node.excluded and true or false)
    top = top + 26
    local family = ns.gemByItem and ns.gemByItem[node.id]
    if not vendor and (editable or family and family.raw == node.id) then
        tools.open:ClearAllPoints(); tools.open:SetPoint("TOPLEFT", tools, "TOPLEFT", 0, -top); tools.open:Show()
        top = top + 30
    else tools.open:Hide() end
    if vendor then tools.uses.frame:Hide()
    else
        tools.uses.frame:ClearAllPoints(); tools.uses.frame:SetPoint("TOPLEFT", tools, "TOPLEFT", 0, -top)
        tools.uses.frame:SetWidth(width)
        tools.uses:SetProps({id = node.id, title = ns.T("batchUsesTitle"), open = K.OpenNext})
        top = top + K.NextUses.HEIGHT
    end
    tools:SetHeight(top)
    return top
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
        self.queue, self.selected, self.editID = 1, nil, nil
    end
    if props.selected ~= nil then self.selected = props.selected or nil end
    self.props = props; self:Render()
end
function Batch:Missing()
    local missing, seen = {}, {}
    for _, node in ipairs(self.plan and self.plan.rows or {}) do
        if not node.excluded and not node.crafted and node.need > 0 and not ns.vendorPrices[node.id] then
            if not seen[node.id] then
                seen[node.id] = {id = node.id, need = 0}
                missing[#missing + 1] = seen[node.id]
            end
            seen[node.id].need = seen[node.id].need + node.need
        end
    end
    return missing
end
function Batch:Act()
    if self.action == "scan" and self.props and self.props.scan then self.props.scan.run()
    elseif self.action == "buy" then self:BuyNext() end
end
function Batch:BuyNext()
    K.FlushEdits(self.quantity)
    local missing = self:Missing()
    if #missing == 0 or not self.props.buy then return end
    local index = math.max(1, math.min(self.queue, #missing))
    local item = missing[index]
    if self.props.buy(item.id, item.need) then self.queue = index % #missing + 1 end
    self:Render()
end
function Batch:Place(frame, x, y)
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", self.child, "TOPLEFT", x or 0, -y); frame:Show()
end
function Batch:Detail(node, price)
    local quote = node.quote
    local need = ns.T("batchNeed", node.need, node.count)
    local detail, tone
    if node.excluded then return ns.T("batchExcluded"), "secondary"
    elseif node.crafted then detail, tone = ns.T("batchNeedMake", node.count, node.crafts or 0), "text"
    elseif node.need == 0 then detail, tone = ns.T("batchEnough") .. " | " .. ns.T("batchHave", node.own, node.count), "positive"
    elseif not price then detail, tone = ns.T("batchNoPrice") .. " | " .. need, "negative"
    elseif (quote.units or 0) == 0 and not quote.vendor and not quote.manual then
        detail, tone = ns.T("batchNotOnAuction") .. " | " .. need, "negative"
    elseif not quote.vendor and not quote.manual and not ns.Markets.Fresh(node.id) then
        detail, tone = ns.T("batchStale") .. " | " .. need, "accent"
    else detail, tone = need, "text" end
    if (node.ownAlts or 0) > 0 then detail = detail .. " | " .. ns.T("batchAlts", node.ownAlts) end
    if node.edge and node.edge.kind ~= "buy" and ns.Obtain then detail = detail .. " | " .. ns.Obtain.Label(node.edge) end
    return detail, tone
end
function Batch:RenderRow(row, node, width)
    row.frame:SetWidth(width)
    local offset = 22 + node.depth * 12
    local buyable = not node.excluded and not node.crafted and node.need > 0 and not ns.vendorPrices[node.id]
    local ways = node.ways or 0
    local paths = ns.PathWindow ~= nil and not node.excluded and (ways > 1 or (ways == 1 and not node.expandable))
    local actions = {}
    if paths then actions[#actions + 1] = {key = "paths", label = ns.T("inspectorPaths"), icon = "paths", tip = ns.T("pathRowTip")} end
    if buyable then actions[#actions + 1] = {key = "buy", label = ns.T("tradeBuy"), icon = "buy", tip = ns.T("batchBuyRowTip")} end
    local textWidth = math.max(1, width - offset - 26 - 92 - 26 * #actions)
    K.SetItemChoice(row.frame, node.id, node.id == self.selected)
    row.frame.icon:ClearAllPoints(); row.frame.icon:SetPoint("LEFT", row.frame, "LEFT", offset, 0)
    row.frame.text:ClearAllPoints(); row.frame.text:SetPoint("TOPLEFT", row.frame, "TOPLEFT", offset + 26, -3)
    row.frame.text:SetWidth(textWidth)
    row.detail:ClearAllPoints(); row.detail:SetPoint("TOPLEFT", row.frame, "TOPLEFT", offset + 26, -16)
    row.detail:SetWidth(textWidth)
    row.expand:ClearAllPoints(); row.expand:SetPoint("LEFT", row.frame, "LEFT", offset - 22, 0)
    row.expand:SetActive(node.crafted)
    if node.expandable and not node.excluded then row.expand:Show() else row.expand:Hide() end
    local quote = node.quote
    local price = quote and quote.miss == 0 and quote.complete ~= false and quote.price or nil
    local detail, tone = self:Detail(node, price)
    row.detail:SetText(detail)
    row.detail:SetTextColor(unpack(K.theme[tone]))
    row.price:SetText(node.crafted and "" or K.Money(price))
    row.price:SetTextColor(unpack(K.theme[(not node.crafted and not node.excluded and not price) and "negative" or "text"]))
    row.sum:SetText(K.Money(node.crafted and node.value or node.cash))
    row.props = {active = node.id == self.selected, actions = actions}
    K.RevealActions(row)
end
function Batch:Render()
    local p = self.props
    if not p or not p.recipe then self.frame:Hide(); return end
    self.frame:Show()
    local o = p.options
    local plan = ns.CraftPlan.Build(p.recipe, {make = o.make, ignore = o.ignore, craftAll = o.craftAll, owned = o.owned,
        fee = ns.Fee(), quantity = o.quantity, choice = o.choice})
    self.plan = plan
    local frameWidth = self.frame:GetWidth() or 240
    local full = math.max(160, frameWidth - (K.theme.inset - EDGE))
    local height = self:Lay(full)
    local room = (self.frame:GetHeight() or 0) - BUY_BAND
    local fits = room <= 0 or height <= room
    if not fits then self:Lay(math.max(160, frameWidth - (K.theme.scrollBar - EDGE))) end
    self.scroll:ClearAllPoints()
    self.scroll:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    self.scroll:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", fits and 0 or EDGE - K.theme.scrollBar, BUY_BAND)
    K.PanelScrollBar(self.scroll, fits)
    self.buy:SetWidth(full)
    self:Controls()
end
function Batch:Lay(width)
    local p, o, plan = self.props, self.props.options, self.plan
    self.child:SetWidth(width)
    self.status:SetWidth(width)
    self.supply:SetWidth(width)
    self.staleNote:SetWidth(width)
    self.product:SetWidth(width)
    self.product.text:SetWidth(width - 30)
    self.productNote:SetWidth(width - 130)
    self:Place(self.product, 0, 0)
    K.SetItemChoice(self.product, p.recipe.raw, false)
    self.productNote:SetText(ns.T("batchProduct", plan.requested))
    self.margin:SetText(K.Money(plan.margin))
    self.margin:SetTextColor(unpack(K.theme[K.Tone(plan.margin)]))
    local status = ns.T("batchOutput", p.recipe.count) .. " | " .. ns.T("batchCrafts", plan.crafts)
    if p.known == true then status = status .. " | " .. ns.T("craftRecipeKnown")
    elseif p.known == false then status = status .. " | " .. ns.T("craftRecipeUnknown") end
    if plan.extra > 0 then status = status .. ns.T("craftExtra", plan.extra) end
    status = status .. (p.note or "")
    self.status:SetText(status)
    local wide = (self.status.GetStringWidth and self.status:GetStringWidth() or 0) > width
    self.status:SetHeight(wide and 26 or 12)
    self:Place(self.status, 0, 34)
    local y = wide and 66 or 52
    local labelWidth = math.ceil(math.min(80, self.quantityLabel.GetStringWidth and self.quantityLabel:GetStringWidth() or 70))
    self.quantityLabel:SetWidth(labelWidth + 2)
    self:Place(self.quantityLabel, 0, y + 5)
    self:Place(self.quantity, labelWidth + 4, y)
    if not self.quantity:HasFocus() then self.quantity:SetText(tostring(plan.requested)) end
    self.steps:Select(plan.requested)
    local stepsAt = labelWidth + 4 + (self.quantity:GetWidth() or 44) + 4
    local stepsWidth = self.steps.frame:GetWidth() or 100
    if stepsAt + stepsWidth > width then
        y = y + 26
        self:Place(self.steps.frame, 0, y)
    else self:Place(self.steps.frame, width - stepsWidth, y) end
    y = y + 28
    self:Place(self.reagentsTitle, 0, y + 3)
    self.scan:ClearAllPoints(); self.scan:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", 0, -y)
    if p.scan then
        self.scan.tipFn = p.scan.tip
        self.scan:Show()
    else self.scan:Hide() end
    y = y + 24
    local toolsAt
    self.tools:Hide()
    for i, row in ipairs(self.rows) do
        local node = plan.rows[i]
        row.node = node
        if node then
            self:Place(row.frame, 0, y)
            self:RenderRow(row, node, width)
            y = y + 30
            if p.reagent and not toolsAt and node.id == self.selected then
                toolsAt = node
                y = y + self:PlaceTools(node, y, width - 22)
            end
        else row.frame:Hide() end
    end
    y = self:RenderTotals(y + 6, width)
    self.sourceChip:SetChecked(o.craftAll and true or false)
    self.ownedChip:SetChecked(o.owned and true or false)
    self:Place(self.sourceChip, 0, y)
    self:Place(self.ownedChip, (self.sourceChip:GetWidth() or 120) + 6, y)
    y = y + 28
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
        {ns.T("batchMargin"), plan.margin, K.Tone(plan.margin), true}}
    for i, total in ipairs(totals) do
        local key, value = self.totalKeys[i], self.totalValues[i]
        if total[4] then
            key:SetWidth(math.max(120, width - 106))
            self:Place(key, 0, y)
            value:ClearAllPoints()
            value:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", 0, -y); value:Show()
            key:SetText(total[1]); value:SetText(K.Money(total[2]))
            value:SetTextColor(unpack(K.theme[total[3]]))
            y = y + K.theme.valueStep
        else key:Hide(); value:Hide() end
    end
    if plan.stale > 0 then
        self.staleNote:SetText(ns.T("batchStaleTotal", plan.stale))
        self:Place(self.staleNote, 0, y)
        y = y + K.theme.valueStep
    else self.staleNote:Hide() end
    if plan.chosen > 0 then
        self.pathNote:SetWidth(math.max(80, width - (self.pathReset:GetWidth() or 66) - 6))
        self:Place(self.pathNote, 0, y + 5)
        self.pathReset:ClearAllPoints(); self.pathReset:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", 0, -(y + 1)); self.pathReset:Show()
        y = y + 24
    else self.pathNote:Hide(); self.pathReset:Hide() end
    if plan.cost then
        self.supply:SetText(plan.short > 0 and ns.T("batchSupplyShort", plan.short) or ns.T("batchSupplyOk"))
        self.supply:SetTextColor(unpack(K.theme[plan.short == 0 and "positive" or "negative"]))
    else
        self.supply:SetText(ns.T("craftBatchMissing", plan.missing))
        self.supply:SetTextColor(unpack(K.theme.negative))
    end
    self:Place(self.supply, 0, y + 2)
    return y + 20
end
function Batch:Controls()
    if not self.props or not self.props.recipe or not self.plan then return end
    if busy() then self.scan:Disable() else self.scan:Enable() end
    self:RenderBuy()
end
function Batch:RenderBuy()
    local b, p, plan = self.buy, self.props, self.plan
    local missing, waiting = self:Missing(), busy()
    local margin = plan.margin
    local title, reason
    if margin == nil and p.scan then
        self.action, title = "scan", ns.T("batchScanPrices")
        b.kind = "control"
        b:SetText(title)
        K.Tooltip(b, title, ns.T("scanRecipeSelectionTip"))
        b.tipFn = p.scan.tip
    elseif #missing == 0 then
        self.action, title, reason = nil, ns.T("batchBuyMissing"), ns.T("batchNothingToBuyTip")
        b.kind = "main"
        b:SetText(ns.T("batchNothingToBuy"))
        K.Tooltip(b, title, reason)
        b.tipFn = nil
    else
        self.action, title = "buy", ns.T("batchBuyMissing")
        local index = math.max(1, math.min(self.queue, #missing))
        local current = missing[index]
        local name = ns.Markets.Name(current.id)
        b.kind = margin and margin > 0 and "main" or "control"
        b:SetText(#missing == 1 and ns.T("batchBuyItem", name, current.need)
            or ns.T("batchBuyNext", name, current.need, index, #missing))
        local rest = {}
        for i = 1, math.min(#missing - 1, 3) do
            local following = missing[(index + i - 1) % #missing + 1]
            rest[#rest + 1] = ns.Markets.Name(following.id) .. " x" .. following.need
        end
        local warning = margin == nil and ns.T("batchMarginUnknown")
            or margin <= 0 and ns.T("batchMarginLoss", K.Money(margin)) or nil
        K.Tooltip(b, title, ns.T("batchBuyTip"))
        b.tipFn = function()
            local note = ns.T("batchQueueNow", name .. " x" .. current.need)
            if #rest > 0 then note = note .. "\n" .. ns.T("batchQueue", table.concat(rest, ", ")) end
            if warning then note = warning .. "\n\n" .. note end
            return note .. "\n\n" .. ns.T("batchBuyTip")
        end
    end
    if waiting then reason = ns.T("batchBusy") end
    K.DisabledTip(b, title, reason)
    if waiting or not self.action then b:Disable() else b:Enable() end
end
