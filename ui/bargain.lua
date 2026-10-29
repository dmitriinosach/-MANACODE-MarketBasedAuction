local _, ns = ...
local UI = {props = {group = "deals", percent = 20}, pool = {}, list = {}}
ns.BargainUI = UI
local GROUP_LABELS = {deals = "bargainGroupDeals", gear = "bargainGroupGear", mounts = "bargainGroupMounts",
    recipes = "bargainGroupRecipes", reagents = "bargainGroupReagents", own = "bargainGroupOwn", off = "bargainGroupOff"}
local FROM_LABELS = {icc = "bargainFromIcc", ulduar = "bargainFromUlduar", naxx = "bargainFromNaxx",
    toc = "bargainFromToc", os = "bargainFromOs", eoe = "bargainFromEoe", ony = "bargainFromOny", rs = "bargainFromRs",
    voa = "bargainFromVoa", dungeon = "bargainFromDungeon", world = "bargainFromWorld", drop = "bargainFromDrop"}
local PANEL = 362
local function saved()
    local db = ns.Store.DB()
    if type(db.bargainUI) ~= "table" then db.bargainUI = {} end
    return db.bargainUI
end
function UI:Save()
    local s, p = saved(), self.props
    s.kind, s.fee = nil, nil
    s.group, s.percent = p.group, p.percent
end
function UI:Restore()
    local s, p = saved(), self.props
    if GROUP_LABELS[s.group] then p.group = s.group end
    local value = tonumber(s.percent)
    if value and value >= 1 and value <= 95 then p.percent = math.floor(value) end
end
function UI:SetProps(props)
    local p = self.props
    if props.group and props.group ~= p.group then
        p.group, p.key = props.group, nil
        self.scroll.offset = 0
    end
    if type(props.percent) == "number" then p.percent = props.percent end
    if props.key ~= nil then p.key = props.key end
    if self.frame then self:Save() end
    self:Render()
end
local function age(seconds)
    if seconds < 60 then return ns.T("bargainAgeNow") end
    if seconds < 3600 then return ns.T("bargainAgeMinutes", math.floor(seconds / 60)) end
    if seconds < 86400 then return ns.T("bargainAgeHours", math.floor(seconds / 3600)) end
    return ns.T("bargainAgeDays", math.floor(seconds / 86400))
end
function UI:Options()
    return {percent = self.props.percent, fee = ns.Fee()}
end
local function idle()
    return ns.Scan.state.phase == "idle" and not ns.Buy.Active()
end
function UI:Controls()
    if not self.frame then return end
    local B, K = ns.Bargain, ns.TradeKit
    if idle() then self.scan:Enable(); self.add:Enable() else self.scan:Disable(); self.add:Disable() end
    local row = self.selected
    if B.Active() then
        local count, cost = ns.Buy.Offer()
        local bid = B.job and B.job.kind == "bid"
        if ns.Buy.state.phase == "ready" and count > 0 then
            self.act:SetText(ns.T(bid and "bargainConfirmBid" or "bargainConfirmBuyout", K.Money(cost)))
            self.act:Enable()
        else
            self.act:SetText(ns.T("bargainSearching")); self.act:Disable()
        end
    elseif row and row.deal then
        local deal = row.deal
        self.act:SetText(ns.T(deal.kind == "bid" and "bargainDoBid" or "bargainDoBuyout", K.Money(deal.cost)))
        if idle() and ns.Scan.state.open then self.act:Enable() else self.act:Disable() end
    else
        self.act:SetText(ns.T("bargainPick")); self.act:Disable()
    end
end
function UI:Find(id)
    for _, row in ipairs(self.list) do
        if row.id == id then return row end
    end
    return nil
end
function UI.Cells(row, now)
    local K, deal = ns.TradeKit, row.deal
    local none = ns.T("bargainNone")
    local price = deal and deal.unit or row.min
    local cells = {
        lots = {row.checked and tostring(row.lots) or none, "secondary"},
        price = {price and K.Money(price) or none},
        market = {row.ref and K.Money(row.ref) or ns.T("bargainNoRef"), "secondary"},
        age = {row.checked and age(math.max(0, now - row.checked)) or ns.T("bargainNever"), "secondary"},
    }
    if deal then
        cells.discount = {ns.T("bargainDiscount", math.floor(deal.discount + 0.5)), "positive"}
    elseif row.discount then
        cells.discount = {ns.T("bargainDiscount", math.floor(row.discount + 0.5)), "secondary"}
    end
    return cells
end
function UI.Tag(row)
    if row.placed then return ns.TradeKit.BoughtMark(row.id, row.checked) end
    local deal = row.deal
    if not deal then return nil end
    if deal.kind == "bid" then return ns.T("bargainTagBid"), "positive" end
    return ns.T(deal.cheapest and "bargainTagCheapest" or "bargainTagDeal"), "positive"
end
function UI.RowTip(row, extra)
    local lines = {ns.T("bargainRowTip")}
    local from = row.entry.from and FROM_LABELS[row.entry.from]
    if from then lines[#lines + 1] = ns.T("bargainRowFrom", ns.T(from)) end
    if row.entry.own then lines[#lines + 1] = ns.T("bargainRowOwn") end
    if extra then lines[#lines + 1] = extra end
    return table.concat(lines, "\n\n")
end
function UI:Steps(entries)
    local K = ns.TradeKit
    for i, label in ipairs(self.stepLabels) do
        local entry, value = entries[i], self.stepValues[i]
        if entry then
            local last = i == #entries
            local y = self.stepsTop - (i - 1) * 14 - (last and 4 or 0)
            label:ClearAllPoints(); label:SetPoint("TOPLEFT", self.body, "TOPLEFT", 12, y)
            value:ClearAllPoints(); value:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", -12, y)
            label:SetText(entry[1]); value:SetText(entry[2])
            label:SetTextColor(unpack(K.theme[last and "text" or "secondary"]))
            value:SetTextColor(unpack(K.theme[entry[3] or "text"]))
            label:Show(); value:Show()
        else label:Hide(); value:Hide() end
    end
end
function UI:Calculation(row)
    local K, B = ns.TradeKit, ns.Bargain
    local deal = row.deal
    if not row.ref or not (deal or row.min) then self:Steps({}); return end
    local count = deal and deal.lot.count or 1
    local resale = deal and deal.resale or B.Resale(row.id, row.ref, 1, ns.Fee())
    local cost = deal and deal.cost or row.min
    local costLabel = deal and (deal.kind == "bid" and "bargainStepBid" or "bargainStepBuyout") or "bargainStepMin"
    local profit = resale.revenue - cost
    self:Steps({
        {ns.T("bargainStepMarket"), K.Money(deal and deal.ref or row.ref)},
        {ns.T("bargainStepGross", count), K.Money(resale.gross)},
        {ns.T("bargainStepFee", math.floor(ns.Fee() * 100 + 0.5)), K.Money(-resale.commission), "secondary"},
        {ns.T(resale.depositKnown and "bargainStepDeposit" or "bargainStepDepositMin"), K.Money(-resale.deposit), "secondary"},
        {ns.T("bargainStepRevenue"), K.Money(resale.revenue)},
        {ns.T(costLabel), K.Money(-cost), "secondary"},
        {ns.T("bargainStepProfit"), K.Money(profit), K.Tone(profit)},
    })
end
function UI:Panel(row)
    local K, B = ns.TradeKit, ns.Bargain
    local stats, deal = row.stats, row.deal
    self.worth:SetValue(B.Worth(row.id))
    local source = deal and deal.source or row.source
    local refLabel = source == "own" and ns.T("bargainRefOwn")
        or (source == "history" and ns.T("bargainRefHistory", stats.count))
        or (source == "offers" and ns.T("bargainRefOffers")) or ns.T("bargainRefNone")
    self.refLabel:SetText(refLabel)
    self.ref:SetText(row.ref and K.Money(deal and deal.ref or row.ref) or ns.T("bargainNoRef"))
    self.range:SetText(stats.min and ns.T("bargainRangeValue", K.Money(stats.min), K.Money(stats.max)) or ns.T("bargainNone"))
    local notes = {}
    if not row.checked then notes[#notes + 1] = ns.T("bargainNoteNever") end
    if deal and deal.cheapest then notes[#notes + 1] = ns.T("bargainNoteCheapest") end
    if stats.jumpy then notes[#notes + 1] = ns.T("bargainNoteJumpy") end
    if row.checked and stats.count < B.HISTORY_MIN and source ~= "own" then notes[#notes + 1] = ns.T("bargainNoteNoHistory") end
    self.note:SetText(table.concat(notes, " "))
    self:Calculation(row)
    local levels, summary = B.Depth(row.id, #self.depthLines)
    self.depthSummary:SetText(summary.lots > 0 and ns.T("bargainDepthSummary", summary.units, summary.lots)
        or ns.T("bargainDepthEmpty"))
    for i, line in ipairs(self.depthLines) do
        local level = levels[i]
        if level then
            line.price:SetText(K.Money(level.price))
            line.units:SetText(ns.T("bargainDepthRow", level.units, level.cumulative))
            line.price:Show(); line.units:Show()
        else line.price:Hide(); line.units:Hide() end
    end
    local entry = row.entry
    if entry.off then
        self.watch:SetText(ns.T("bargainShow")); K.Tooltip(self.watch, ns.T("bargainShow"), ns.T("bargainShowTip"))
    else
        local key = entry.group == "own" and "bargainHideOwn" or "bargainHide"
        self.watch:SetText(ns.T(key)); K.Tooltip(self.watch, ns.T(key), ns.T("bargainHideTip"))
    end
end
function UI:Render()
    if not self.frame then return end
    local K, B, p = ns.TradeKit, ns.Bargain, self.props
    local width = (self.frame:GetWidth() or 996) - 310
    local columns = K.BargainColumns(width)
    K.PlaceHeaders(self.headers, columns, self.frame, -40, true)
    local rows, info = B.Rows(p.group, self:Options())
    self.list = rows
    local visible = K.ListCapacity(self.frame, 62, 40, 24, #self.pool)
    local offset = self.scroll:SetRange(#rows, visible)
    local selected = self:Find(p.key) or rows[1]
    self.selected = selected
    local now, open = time(), ns.Scan.state.open and idle()
    for i, view in ipairs(self.pool) do
        local row = i <= visible and rows[offset + i]
        if row then
            local tag, tone, boughtTip = UI.Tag(row)
            local actions
            if row.deal then
                local bid = row.deal.kind == "bid"
                actions = {{label = ns.T(bid and "bargainActBid" or "bargainActBuyout"),
                    tip = ns.T(bid and "bargainActBidTip" or "bargainActBuyoutTip"),
                    disabled = not open, fn = function(key) self:Act(key) end}}
            end
            view.frame:ClearAllPoints(); view.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -62 - (i - 1) * 24)
            view:SetProps({key = row.id, id = row.id, width = width, cells = UI.Cells(row, now),
                tag = tag, tagTone = tone, active = selected == row, tip = UI.RowTip(row, boughtTip), actions = actions})
        else view.frame:Hide() end
    end
    local empty = ""
    if #rows == 0 then
        empty = ns.T(p.group == "deals" and "bargainEmptyDeals" or (p.group == "own" and "bargainEmptyOwn")
            or (p.group == "off" and "bargainEmptyOff") or "bargainEmpty")
    end
    self.empty:SetText(empty)
    if selected then
        self.inspector:SetProps({id = selected.id})
        self:Panel(selected)
        self.body:Show()
    else
        self.inspector:Clear()
        self.body:Hide()
    end
    self.menu.frame:SetText(ns.T(GROUP_LABELS[p.group]))
    if not self.edit:HasFocus() then self.edit:SetText(tostring(p.percent)) end
    self.statusText = ns.T("bargainStatus", ns.T(GROUP_LABELS[p.group]), info.total, info.checked, info.deals)
    ns.Trader.RenderStatus()
    self:FitPanel()
    self:Controls()
end
function UI:FitPanel()
    local width = self.panelScroll:Fit(PANEL)
    for _, label in ipairs(self.stepLabels) do label:SetWidth(width - 130) end
    self.refLabel:SetWidth(width - 130); self.rangeLabel:SetWidth(width - 130)
    self.note:SetWidth(width - 24); self.depthSummary:SetWidth(width - 24)
end
function UI:Act(id)
    local row = self:Find(id)
    if not row then return end
    self.props.key = id
    ns.Bargain.Act(row)
    self:Render()
end
function UI:ApplyPercent(value)
    local number = tonumber(value)
    if number and number >= 1 and number <= 95 and number == math.floor(number) then
        self.props.percent = number
        self:Save()
    else
        ns.say(ns.T("bargainInvalidPercent"))
    end
    self:Render()
end
function UI:AddItem()
    local id = ns.Bargain.Add(self.input:GetText())
    if not id then ns.say(ns.T("bargainAddInvalid")); return end
    self.input:SetText(""); self.input:ClearFocus()
    ns.say(ns.T("bargainAdded", ns.Markets.Name(id)))
    self.props.key = id
    if self.props.group ~= "own" then self:SetProps({group = "own", key = id}) else self:Render() end
end
function UI:ToggleWatch()
    local row = self.selected
    if not row then return end
    if row.entry.off then ns.Bargain.Show(row.id) else ns.Bargain.Hide(row.id) end
    self.props.key = nil
    self:Render()
end
function UI:NewPanel()
    local K = ns.TradeKit
    self.inspector = K.Inspector:New(self.frame)
    self.panelScroll = K.PanelScroll:New(self.inspector, "ManaCodeBargainPanelScroll", PANEL)
    self.scrollBody, self.panelChild = self.panelScroll.frame, self.panelScroll.child
    local body = ns.NewFrame("Frame", nil, self.panelChild)
    body:SetAllPoints(self.panelChild)
    self.body = body
    self.inspector:SetInfo(ns.T("bargainPanelValue"), ns.T("bargainValueTip"))
    local worthLabel = K.Label(body, ns.T("bargainWorth"), 12, -8, 90, "secondary")
    worthLabel:SetHeight(12)
    self.worth = K.MoneyEdit(body, function(copper)
        if self.selected then ns.Bargain.SetWorth(self.selected.id, copper); self:Render() end
    end)
    self.worth.frame:SetPoint("TOPRIGHT", body, "TOPRIGHT", -12, -3)
    K.Tooltip(self.worth.frame, ns.T("bargainWorth"), ns.T("bargainWorthTip"))
    for _, edit in ipairs(self.worth.edits) do K.Tooltip(edit, ns.T("bargainWorth"), ns.T("bargainWorthTip")) end
    self.refLabel, self.ref = K.ValueRow(body, ns.T("bargainRefNone"), -32, 130, 100)
    self.rangeLabel, self.range = K.ValueRow(body, ns.T("bargainRange"), -48, 130, 100)
    self.note = K.Label(body, "", 12, -66, 240, "secondary")
    self.note:SetHeight(36); self.note:SetJustifyV("TOP")
    K.Rule(body, -106)
    K.Label(body, ns.T("bargainPanelSteps"), 12, -114, 200, "heading")
    local stepsHelp = K.InfoButton(body, ns.T("bargainPanelSteps"), ns.T("bargainStepsTip"))
    stepsHelp:SetPoint("TOPRIGHT", body, "TOPRIGHT", -12, -110)
    self.stepsTop = -136
    self.stepLabels, self.stepValues = {}, {}
    for i = 1, 7 do
        local name, value = K.ValueRow(body, "", self.stepsTop - (i - 1) * 14, 130, 100)
        self.stepLabels[i], self.stepValues[i] = name, value
    end
    K.Rule(body, -240)
    local depthTitle = K.Label(body, ns.T("bargainPanelDepth"), 12, -248, 200, "heading")
    depthTitle:SetHeight(14)
    local depthHelp = K.InfoButton(body, ns.T("bargainPanelDepth"), ns.T("bargainDepthTip"))
    depthHelp:SetPoint("TOPRIGHT", body, "TOPRIGHT", -12, -244)
    self.depthSummary = K.Label(body, "", 12, -268, 240, "secondary"); self.depthSummary:SetHeight(12)
    self.depthLines = {}
    for i = 1, 4 do
        local y = -284 - (i - 1) * 14
        local price = K.Label(body, "", 12, y, 110); price:SetHeight(12)
        local units = K.Label(body, "", 0, y, 120, "secondary"); units:SetHeight(12); units:SetJustifyH("RIGHT")
        units:ClearAllPoints(); units:SetPoint("TOPRIGHT", body, "TOPRIGHT", -12, y)
        self.depthLines[i] = {price = price, units = units}
    end
    self.watch = K.Button(body, ns.T("bargainHide"), 150, function() self:ToggleWatch() end, "quiet")
    self.watch:SetPoint("TOPLEFT", body, "TOPLEFT", 12, -344)
end
function UI:New(parent)
    local K = ns.TradeKit
    self:Restore()
    self.frame = ns.NewFrame("Frame", nil, parent)
    local f = self.frame
    f:SetAllPoints(parent)
    self.title = K.Label(f, ns.T("bargainTitle"), 10, -9, 100, "heading")
    self.title:SetHeight(14)
    local entries = {}
    for _, key in ipairs(ns.Bargain.GROUPS) do entries[#entries + 1] = {key = key, labelKey = GROUP_LABELS[key]} end
    self.menu = K.Menu(f, entries, function(group) self:SetProps({group = group}) end)
    self.menu.frame:SetWidth(160); self.menu.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 110, -3)
    K.Tooltip(self.menu.frame, ns.T("bargainTitle"), ns.T("bargainGroupTip"))
    local label = K.Label(f, ns.T("bargainThreshold"), 0, 0, 70, "secondary")
    label:SetHeight(12)
    label:ClearAllPoints(); label:SetPoint("LEFT", self.menu.frame, "RIGHT", 12, 0)
    self.edit = K.Edit(f, 40)
    self.edit:SetPoint("LEFT", label, "RIGHT", 4, 0)
    K.LiveEdit(self.edit, function(box) self:ApplyPercent(box:GetText()) end, 0.8)
    self.edit:SetScript("OnEditFocusLost", function(box) K.FlushEdits(box); self:Render() end)
    K.Tooltip(self.edit, ns.T("bargainThreshold"), ns.T("bargainThresholdTip"))
    local unit = K.Label(f, ns.T("bargainPercent"), 0, 0, 16, "secondary")
    unit:SetHeight(12)
    unit:ClearAllPoints(); unit:SetPoint("LEFT", self.edit, "RIGHT", 3, 0)
    self.scan = K.Button(f, ns.T("bargainScan"), 130, function()
        ns.Bargain.Scan(self.props.group, K.ScanMode(), self:Options()); self:Render()
    end, "main")
    self.scan:SetPoint("TOPRIGHT", f, "TOPRIGHT", -282, -3)
    K.ScanTip(self.scan, ns.T("bargainScan"), ns.T("bargainScanTip"), nil, nil, {age = function()
        return ns.Batch.Age(ns.Bargain.Targets(self.props.group, self:Options()), false)
    end})
    local base = self.scan.tipFn
    self.scan.tipFn = function()
        local soft, hard, missing, more = ns.Bargain.Preview(self.props.group)
        local text = base() .. "\n\n" .. ns.T("bargainPreview", soft, hard, missing, ns.Bargain.LIMIT)
        if more > 0 then text = text .. " " .. ns.T("bargainPreviewMore", more) end
        return text
    end
    K.TableHeader(f, -42)
    self.headers = {}
    for _, entry in ipairs({{"item", "bargainColItem"}, {"lots", "bargainColLots", "bargainTipLots"},
        {"price", "bargainColPrice", "bargainTipPrice"}, {"market", "bargainColMarket", "bargainTipMarket"},
        {"discount", "bargainColDiscount", "bargainTipDiscount"}, {"age", "bargainColAge", "bargainTipAge"}}) do
        local header = K.Label(f, ns.T(entry[2]), 0, -40, 100)
        header:SetHeight(12)
        if entry[1] ~= "item" then header:SetJustifyH("RIGHT") end
        self.headers[entry[1]] = header
        if entry[3] then
            local cover = ns.NewFrame("Button", nil, f)
            cover:SetAllPoints(header); cover:EnableMouse(true)
            K.Tooltip(cover, ns.T(entry[2]), ns.T(entry[3]))
        end
    end
    self.scroll = K.TableScroll(f, function() self:Render() end, 62, 40, 24)
    for i = 1, 30 do
        local row = K.BargainRow:New(f, function(key) self:SetProps({key = key}) end)
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -62 - (i - 1) * 24)
        row.frame:Hide()
        self.pool[i] = row
        self.scroll:Wheel(row.frame)
    end
    self.empty = K.Label(f, "", 10, -72, 440, "secondary"); self.empty:SetHeight(40); self.empty:SetJustifyV("TOP")
    self.input = K.Edit(f, 180)
    self.input:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    K.Tooltip(self.input, ns.T("bargainAdd"), ns.T("bargainAddTip"))
    self.input:SetScript("OnEnterPressed", function() self:AddItem() end)
    self.add = K.Button(f, ns.T("bargainAdd"), 84, function() self:AddItem() end)
    self.add:SetPoint("LEFT", self.input, "RIGHT", 6, 0)
    K.Tooltip(self.add, ns.T("bargainAdd"), ns.T("bargainAddTip"))
    self.act = K.Button(f, ns.T("bargainPick"), 210, function() if self.selected then self:Act(self.selected.id) end end, "main")
    self.act:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -282, 4)
    self:NewPanel()
    f:HookScript("OnShow", function()
        ns.Bargain.Warm(function() if self.frame:IsVisible() then self:Render() end end)
        self:Render()
    end)
    f:SetScript("OnSizeChanged", function() self:Render() end)
    ns.Bargain.onChange = function()
        if self.frame and self.frame:IsVisible() then self:Render() end
    end
    self:Render()
    return self
end
