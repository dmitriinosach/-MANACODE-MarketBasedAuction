local _, ns = ...
local UI = {props = {}, view = "bags", rows = {}, packs = {}, open = {}}
ns.SellingUI = UI
local ROW = 26
local TOP = 56
local BOTTOM = 10
local PANEL_TOP = 58
local QUALITY = 40
function UI:SetProps(props)
    if props.id then
        self.props.link = props.link
        self.props.key = ns.Posting.ItemKey(props.link) or props.id
    end
    for key, value in pairs(props) do self.props[key] = value end
    self:Render()
end
function UI:SetView(view)
    if view ~= "bags" and view ~= "owned" then return end
    self.view, self.confirm = view, nil
    if self.scroll then self.scroll.offset = 0 end
    self:Render()
end
function UI:Opened()
    if self.view ~= "bags" then self:SetView("bags") end
end
function UI:Controls()
    if not self.frame then return end
    if ns.Scan.state.phase == "idle" and not ns.Buy.Active() then self.scan:Enable() else self.scan:Disable() end
end
local function mineCell(row)
    if row.active == 0 then return {""} end
    if row.undercut > 0 then return {ns.T("sellMineUndercut", row.active, row.undercut), "negative"} end
    return {ns.T("sellMine", row.active), "positive"}
end
local function wayVerb(way)
    if way.kind == "process" then return ns.T(way.entry.mode == "mill" and "sellWayMill" or "sellWayProspect") end
    if way.kind == "recycle" then return ns.T(way.step > 1 and "sellWayAssemble" or "sellWaySplit") end
    return ns.T("sellWay_" .. way.kind)
end
local function wayLabel(way)
    if way.kind == "process" or way.kind == "disenchant" then return wayVerb(way) end
    return ns.T("sellWayOn", wayVerb(way), ns.Markets.Name(way.id))
end
local function wayAble(way)
    local K = ns.TradeKit
    if way.units == 0 then return ns.T("sellWayShort", way.step), "secondary" end
    if way.able == "self" then
        if way.short > 0 then
            return way.buy and ns.T("sellWayBuy", K.Money(way.buy)) or ns.T("sellWayBuyUnknown", way.short), "gold"
        end
        return ns.T("sellAbleSelf"), "positive"
    end
    if way.able == "alt" then return ns.T("sellAbleAlt", way.alt), "gold" end
    if way.reason == "sellWaySkill" then return ns.T("sellWaySkill", way.rank, way.skill), "negative" end
    if way.reason == "sellWayNotLearned" then return ns.T("sellWayNotLearned"), "negative" end
    return ns.T(way.reason, way.profession or "?"), way.able == "no" and "negative" or "secondary"
end
local function wayDetail(id, way)
    if way.entry then return select(2, ns.TradeKit.NextUses.Describe(id, way.entry)) end
    return ns.T("sellWayDisenchantDetail", way.profession, way.skill)
end
local function bestCell(row)
    local best = row.best
    if not best then return {""} end
    return {ns.T("sellBest", wayVerb(best), math.floor(best.gain / row.sell * 100 + 0.5)), "positive"}
end
function UI:WayEntry(row, way, i, width)
    local K = ns.TradeKit
    local able, tone = wayAble(way)
    local detail = wayDetail(row.id, way)
    local gain = way.gain and ns.T("sellWayGain", (way.gain > 0 and "+" or "") .. K.Money(way.gain))
        or way.value and ns.T("sellWayValue", K.Money(way.value)) or ns.T("tradeNoPrice")
    local busy = ns.Scan.state.phase ~= "idle" or ns.Buy.Active()
    local actions = {{label = ns.T("sellWayOpen"), icon = "go", tip = ns.T("sellWayOpenTip"),
        fn = function() self:OpenWay(way) end}}
    if way.value == nil then
        actions[2] = {label = ns.T("nextComplete"), icon = "refresh", tip = ns.T("nextCompleteTip"), disabled = busy,
            fn = function()
                ns.Batch.Complete(ns.Selling.WayGap(row.id, way), K.ScanMode(), true)
                self:Render()
            end}
    end
    local lines = {wayLabel(way), detail, able}
    if way.gain then
        lines[#lines + 1] = ns.T("sellWayGainTip", K.Money(way.gain), way.units, K.Money(way.total))
    end
    lines[#lines + 1] = ns.T("sellWayRowTip")
    return {key = "way:" .. tostring(row.key) .. ":" .. i, parent = row.key, id = way.id, width = width,
        mode = "sellway", tree = true, nested = true, label = wayLabel(way), hasActions = true, actions = actions,
        tip = table.concat(lines, "\n"),
        cells = {detail = {able .. ns.T("sellWayJoin") .. detail, tone},
            value = {way.total and ((way.total > 0 and "+" or "") .. K.Money(way.total)) or "", K.Tone(way.total)},
            best = {gain, way.gain and K.Tone(way.gain) or "secondary"}}}
end
function UI:OpenWay(way)
    if way.entry then ns.TradeKit.OpenNext(way.entry) else ns.Trader.OpenProcessing("disenchant") end
end
function UI:Toggle(key)
    self.open[key] = not self.open[key] or nil
    self:Render()
end
local function held(seconds)
    if seconds < 3600 then return ns.T("sellHeldMin", math.max(1, math.floor(seconds / 60))) end
    if seconds < 172800 then return ns.T("sellHeldHour", math.floor(seconds / 3600)) end
    return ns.T("sellHeldDay", math.floor(seconds / 86400))
end
function UI:BagEntries(width)
    local K = ns.TradeKit
    local rows = ns.Selling.BagRows(ns.Fee())
    self.bagRows = rows
    rows = self.sorter:Apply(rows, {
        item = function(row) return row.name end,
        quality = function(row) return row.quality end,
        count = function(row) return row.count end,
        held = function(row) return row.changed end,
        market = function(row) return row.market end,
        value = function(row) return row.value end,
        best = function(row) return row.best and row.best.total end,
        mine = function(row) return row.active end,
    })
    local entries = {}
    for _, row in ipairs(rows) do
        local opened = self.open[row.key] and #row.ways > 0
        local best = row.best and ("\n" .. ns.T("sellBestTip", wayLabel(row.best), K.Money(row.best.gain),
            K.Money(row.best.total))) or ""
        entries[#entries + 1] = {key = row.key, id = row.id, link = row.link, width = width, mode = "sell",
            active = row.key == self.props.key, tree = true, expandable = #row.ways > 0, opened = opened,
            expandTip = {ns.T("sellWaysTitle"), ns.T("sellWaysTip")}, hasActions = true,
            tip = ns.T("sellBagTip") .. (row.at and "\n" .. ns.T("sellPriceAgeTip", K.Ago(math.max(0, time() - row.at))) or "")
                .. (row.market and "" or "\n" .. ns.T(row.priceState == "variant" and "sellVariantTip"
                or row.priceState == "empty" and "sellPriceEmptyTip" or "sellPriceUnknownTip")) .. best,
            cells = {count = {tostring(row.count)},
                held = {row.changed and held(math.max(0, time() - row.changed)) or "", "secondary"},
                market = {row.market and K.Money(row.market) or ns.T(row.priceState == "variant"
                    and "sellVariantPrice" or row.priceState == "empty" and "sellPriceEmpty" or "sellPriceUnknown"),
                    row.market and "text" or "secondary"},
                value = {K.Money(row.value), row.value and "text" or "secondary"},
                best = bestCell(row),
                mine = mineCell(row)}}
        if opened then
            for i, way in ipairs(row.ways) do entries[#entries + 1] = self:WayEntry(row, way, i, width) end
        end
    end
    return entries
end
local function standingCell(standing)
    local K = ns.TradeKit
    local state = standing.state
    if state == "undercut" then
        return {ns.T("sellStandUndercut", standing.lots, K.Money(standing.lowest)), "negative"}
    end
    local tones = {sold = "positive", first = "positive", alone = "positive", tie = "gold"}
    return {ns.T("sellStand_" .. state), tones[state] or "secondary"}
end
function UI:OwnedEntries(width)
    local K = ns.TradeKit
    local rows, total = ns.Selling.OwnedRows()
    self.ownedRows, self.ownedTotal = rows, total
    local entries = {}
    for _, row in ipairs(rows) do
        local a = row.auction
        local key = table.concat({"owned", a.index, a.id, a.count, a.buyout}, ":")
        local confirm = self.confirm == key
        local actions
        if not a.sold then
            actions = {{label = ns.T(confirm and "sellCancelConfirm" or "sellCancel"), width = 64,
                tip = ns.T("sellCancelTip"), disabled = not a.canCancel,
                fn = function() self:CancelClick(key, a) end}}
        end
        entries[#entries + 1] = {key = key, id = a.id, link = a.link, width = width, mode = "owned", active = a.id == self.props.id,
            actions = actions, hasActions = true, tip = row.standing.at
                and ns.T("sellStandTip", K.Ago(math.max(0, time() - row.standing.at))) or ns.T("sellStandNoScan"),
            cells = {stack = {tostring(a.count)},
                unit = {a.unit and K.Money(a.unit) or ns.T("sellNoBuyout"), a.unit and "text" or "secondary"},
                buyout = {a.buyout > 0 and K.Money(a.buyout) or ns.T("sellNoBuyout"), a.buyout > 0 and "text" or "secondary"},
                left = {a.sold and "" or ns.T("sellLeft" .. math.max(1, math.min(4, a.timeLeft))), "secondary"},
                standing = standingCell(row.standing)}}
    end
    return entries
end
function UI:CancelClick(key, auction)
    if self.confirm ~= key then
        self.confirm = key
        self.note = nil
        return self:Render()
    end
    self.confirm = nil
    local ok, err = ns.Selling.Cancel(auction)
    self.note = ok and ns.T("sellCancelSent", auction.count, ns.Markets.Name(auction.id)) or ns.T(err)
    self:Render()
end
function UI:Pick(key)
    if self.confirm ~= key then self.confirm = nil end
    for _, entry in ipairs(self.entries or {}) do
        if entry.key == key then
            if entry.parent then return self:Pick(entry.parent) end
            self:SetProps({id = entry.id, link = entry.link}); return
        end
    end
end
function UI:RenderTable(width)
    local K = ns.TradeKit
    local bags = self.view == "bags"
    local entries = bags and self:BagEntries(width) or self:OwnedEntries(width)
    self.entries = entries
    if not self.props.id or (bags and not self:Has(entries, self.props.key or self.props.id)) then
        local selected = entries[1]
        for _, entry in ipairs(entries) do if entry.id == self.props.id and not entry.parent then selected = entry; break end end
        if selected then
            self.props.id, self.props.link = selected.id, selected.link
            self.props.key = ns.Posting.ItemKey(selected.link) or selected.id
            selected.active = true
        end
    end
    local columns = K.LedgerColumns(width, bags and "sell" or "owned", true)
    for mode, headers in pairs(self.headers) do
        if (mode == "bags") == bags then K.PlaceHeaders(headers, columns, self.frame, -38, true)
        else for _, label in pairs(headers) do label:Hide() end end
    end
    if bags then
        local item, quality = columns.item, self.headers.bags.quality
        self.headers.bags.item:SetWidth(item[2] - QUALITY - 12)
        quality:ClearAllPoints()
        quality:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10 + item[1] + item[2] - QUALITY - 6, -38)
        quality:SetWidth(QUALITY); quality:Show()
    end
    self.sorter:Mark()
    local visible = K.ListCapacity(self.frame, TOP, BOTTOM, ROW, #self.rows)
    local offset = self.scroll:SetRange(#entries, visible)
    for i, row in ipairs(self.rows) do
        local entry = i <= visible and entries[offset + i]
        if entry then
            entry.active = not entry.parent
                and (ns.Posting.ItemKey(entry.link) or entry.id) == (self.props.key or self.props.id)
            row:SetProps(entry)
        else row.frame:Hide() end
    end
    local empty = ""
    if #entries == 0 then empty = ns.T(bags and "sellBagsEmpty" or "sellOwnedEmpty") end
    self.empty:SetText(empty)
    return #entries
end
function UI:Has(entries, key)
    for _, entry in ipairs(entries) do if entry.key == key then return true end end
    return false
end
function UI:RenderSummary()
    local K = ns.TradeKit
    local text
    if self.view == "owned" then
        local active, undercut, sold = 0, 0, 0
        for _, row in ipairs(self.ownedRows or {}) do
            if row.auction.sold then sold = sold + 1
            else
                active = active + 1
                if row.standing.state == "undercut" then undercut = undercut + 1 end
            end
        end
        text = ns.T("sellOwnedSummary", active, undercut, sold)
        local shown = #(self.entries or {})
        if (self.ownedTotal or 0) > shown then text = text .. ns.T("sellOwnedMore", self.ownedTotal - shown) end
    else
        local value, count, priced, better, extra = 0, 0, 0, 0, 0
        if not self.bagRows then self.bagRows = ns.Selling.BagRows(ns.Fee()) end
        for _, row in ipairs(self.bagRows) do
            count = count + 1
            value = value + (row.value or 0)
            if row.value then priced = priced + 1 end
            if row.best then better, extra = better + 1, extra + row.best.total end
        end
        text = ns.T("sellBagsEstimate", count, priced, priced > 0 and K.Money(value) or ns.T("tradeNoPrice"))
        if better > 0 then text = text .. ns.T("sellBagsBetter", better, K.Money(extra)) end
    end
    if self.note then text = self.note .. " | " .. text end
    self.statusText = text
    if ns.Trader and ns.Trader.RenderStatus then ns.Trader.RenderStatus() end
end
function UI:RenderPanel()
    local K, id = ns.TradeKit, self.props.id
    if not id then
        self.inspector:Clear()
        self.panelScroll.frame:Hide()
        self.panelEmpty:Show()
        return
    end
    self.panelEmpty:Hide(); self.panelScroll.frame:Show()
    self.inspector:SetProps({id = id, link = self.props.link})
    self.inspector.item.extraTip = ns.T("itemHistoryOpenTip") .. (type(self.props.key) == "string"
        and ("\n" .. ns.T("sellVariantTip")) or "")
    local width = self.panelScroll:Fit(PANEL_TOP + ns.TradeKit.PostForm.HEIGHT + 100)
    local flow = ns.Selling.Flow(id)
    local values = {}
    if flow.compared > 0 then
        values[1] = ns.T("sellFlowEarlyValue", flow.earlyUnits, flow.early)
        values[2] = flow.perDay and ns.T("sellFlowPerDay", math.floor(flow.perDay + 0.5))
            or ns.T("sellFlowShort", math.max(1, math.floor((flow.hours or 0) + 0.5)))
    else
        values[1], values[2] = ns.T("sellFlowNone"), ns.T("boardDash")
    end
    values[3] = flow.supply and ns.T("buyStatSupplyValue", flow.supply, flow.lots or 0) or ns.T("boardDash")
    local q = ns.Markets.Quote(id, true)
    values[4] = q and q.at and not q.vendor and K.Ago(math.max(0, time() - q.at)) or ns.T("tradeNoPrice")
    for i, row in ipairs(self.flowRows) do row.value:SetText(values[i]) end
    self.form:SetProps({id = id, link = self.props.link, fee = ns.Fee(), width = width,
        onChange = function() self:RenderPacks(id, width) end,
        onPosted = function() self:Render() end,
        onCheckOwned = function() self.note = ns.T("postCheckPendingNote"); self:SetView("owned") end})
    self:RenderPacks(id, width)
end
function UI:RenderPacks(id, width)
    local K = ns.TradeKit
    local packs, limit = ns.Selling.Packs(id, ns.Fee())
    local variant = self.form.plan and self.form.plan.variant
    if variant then packs = {} end
    self.packLimit:SetText(limit and ns.T("sellPackLimit", limit) or ns.T("sellPackLimitWait"))
    self.packTitle:SetWidth(math.max(60, width - 32 - (self.packLimit:GetStringWidth() or 60)))
    local size = self.form.plan and self.form.plan.size
    local x = 12
    for i, button in ipairs(self.packs) do
        local pack = packs[i]
        if pack then
            button:SetText(ns.T("sellPackSize", pack.size))
            K.FitButton(button, 16)
            button:SetWidth(math.max(28, button:GetWidth() or 28))
        end
        if pack and x + (button:GetWidth() or 28) <= width - 12 then
            button.pack = pack
            button:ClearAllPoints(); button:SetPoint("TOPLEFT", self.panelChild, "TOPLEFT", x, -24)
            x = x + (button:GetWidth() or 28) + 4
            button:SetActive(pack.size > limit and self.form.plan.units == pack.size or size == pack.size)
            button:Show()
        else button.pack = nil; button:Hide() end
    end
    local empty = ""
    if variant then empty = ns.T("sellVariantSingle")
    elseif not limit then empty = ns.T("sellPacksWait")
    elseif limit < 2 then empty = ns.T("sellPacksSingle")
    elseif #packs == 0 then empty = ns.T("sellPacksNone") end
    self.packEmpty:SetText(empty)
end
local function packTip(button)
    local pack = button.pack
    if not pack then return "" end
    local lines = {}
    if pack.size > pack.stack then lines[#lines + 1] = ns.T("sellPackBatch", pack.size, pack.count, pack.stack) end
    if pack.full then lines[#lines + 1] = ns.T("sellPackFull", pack.size)
    elseif pack.common then lines[#lines + 1] = ns.T("sellPackCommon") end
    if #pack.uses > 0 then lines[#lines + 1] = ns.T("sellPackUses", table.concat(pack.uses, ", ")) end
    if pack.lots > 0 then
        local premium = pack.premium and ns.T("sellPackPremium", pack.premium) or ""
        lines[#lines + 1] = ns.T("sellPackWall", pack.lots) .. premium
    else lines[#lines + 1] = ns.T("sellPackNoWall") end
    if pack.best then lines[#lines + 1] = ns.T("sellPackBest") end
    lines[#lines + 1] = ns.T("sellPackClick")
    return table.concat(lines, "\n")
end
function UI:Layout()
    local K = ns.TradeKit
    local width = self.frame:GetWidth() or 996
    local panel = K.CraftPanelWidth(width)
    if self.inspector.width ~= panel then
        self.inspector.width = panel
        self.inspector:Layout()
    end
    self.headBand:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -panel - 38, -33)
    self.scroll.frame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -panel - 16, BOTTOM)
    self.scan:ClearAllPoints(); self.scan:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -panel - 18, -3)
    self.empty:SetWidth(width - panel - 56)
    return width - panel - 46
end
function UI:Render()
    if not self.frame then return end
    local K = ns.TradeKit
    self.segment:Select(self.view)
    self:RenderTable(self:Layout())
    self.scan:SetText(ns.T(self.view == "owned" and "sellScanOwned" or "sellScanBags"))
    self.scan.tipTitle = self.scan:GetText()
    K.FitButton(self.scan, 24)
    self:RenderSummary()
    self:RenderPanel()
    self:Controls()
end
function UI:NewHeaders(f)
    local K = ns.TradeKit
    self.headBand = K.TableHeader(f, -38)
    self.headers = {bags = {}, owned = {}}
    local specs = {
        bags = {{"item", "sellColItem"}, {"quality", "sellColQuality"}, {"count", "matColCount"}, {"held", "sellColHeld"},
            {"market", "matColMarket"}, {"value", "sellColEstimate"}, {"best", "sellColBest"}, {"mine", "sellColMine"}},
        owned = {{"item", "sellColItem"}, {"stack", "sellColStack"}, {"unit", "buyColUnit"}, {"buyout", "sellColBuyout"},
            {"left", "sellColLeft"}, {"standing", "sellColStanding"}},
    }
    for mode, spec in pairs(specs) do
        for _, entry in ipairs(spec) do
            local label = K.Label(f, ns.T(entry[2]), 0, -38, 100, "secondary")
            label:SetHeight(12)
            if entry[1] ~= "item" then label:SetJustifyH("RIGHT") end
            label:Hide()
            self.headers[mode][entry[1]] = label
        end
    end
    self.sorter = K.Sorter(f, self.headers.bags, function() self.scroll.offset = 0; self:Render() end,
        function() return self.view == "bags" end, {key = "item", desc = false})
    K.Tooltip(self.sorter.buttons.held, ns.T("sellColHeld"), ns.T("sellHeldTip"))
    K.Tooltip(self.sorter.buttons.quality, ns.T("sortTitle"), ns.T("sellQualityTip"))
end
function UI:NewPanel(f)
    local K = ns.TradeKit
    self.inspector = K.Inspector:New(f)
    self.panelScroll = K.PanelScroll:New(self.inspector, "ManaCodeSellingPanelScroll", PANEL_TOP + K.PostForm.HEIGHT + 100)
    local panel = self.panelScroll.child
    self.panelChild = panel
    local flowTop = -PANEL_TOP - K.PostForm.HEIGHT - 12
    local flowTitle = K.Label(panel, ns.T("sellFlowTitle", ns.Selling.FLOW_DAYS), 12, flowTop, 220, "heading")
    flowTitle:SetHeight(14)
    local flowHelp = ns.NewFrame("Frame", nil, panel)
    flowHelp:SetAllPoints(flowTitle); flowHelp:EnableMouse(true)
    K.Tooltip(flowHelp, ns.T("sellFlowTitle", ns.Selling.FLOW_DAYS), ns.T("sellFlowTip"))
    self.flowRows = {}
    local texts = {}
    for i, key in ipairs({"sellFlowEarly", "sellFlowRate", "buyStatSupply", "buyStatScan"}) do texts[i] = ns.T(key) end
    local labels, values = K.ValueRows(panel, flowTop - 22, texts, {labelWidth = 110, valueWidth = 130, step = 17})
    for i = 1, #texts do self.flowRows[i] = {label = labels[i], value = values[i]} end
    K.Rule(panel, flowTop + 8)
    local packTitle = K.Label(panel, ns.T("sellPacksTitle"), 12, -4, 220, "heading")
    packTitle:SetHeight(14)
    self.packTitle = packTitle
    local packHelp = ns.NewFrame("Frame", nil, panel)
    packHelp:SetAllPoints(packTitle); packHelp:EnableMouse(true)
    K.Tooltip(packHelp, ns.T("sellPacksTitle"), ns.T("sellPacksTip"))
    self.packLimit = K.Label(panel, "", 0, 0, 100, "secondary")
    self.packLimit:SetHeight(14); self.packLimit:SetJustifyH("RIGHT")
    self.packLimit:ClearAllPoints(); self.packLimit:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -4)
    local limitHelp = ns.NewFrame("Frame", nil, panel)
    limitHelp:SetAllPoints(self.packLimit); limitHelp:EnableMouse(true)
    K.Tooltip(limitHelp, ns.T("sellPackLimitTitle"), ns.T("sellPackLimitTip"))
    for i = 1, ns.Selling.PACKS do
        local button = K.Button(panel, "", 44, function()
            local pack = self.packs[i].pack
            if not pack or not self.props.id then return end
            local d = ns.Posting.Draft(self.props.id, self.props.link)
            d.size, d.lots = pack.stack, pack.size > pack.stack and pack.count or nil
            self:RenderPanel()
        end, "quiet")
        button:SetHeight(20); button:Hide()
        K.Tooltip(button, ns.T("sellPacksTitle"), "")
        button.tipFn = function() return packTip(button) end
        self.packs[i] = button
    end
    self.packEmpty = K.Label(panel, "", 12, -26, 230, "secondary"); self.packEmpty:SetHeight(24)
    K.Rule(panel, -50)
    self.form = K.PostForm:New(panel)
    self.form:Place(-PANEL_TOP)
    self.panelEmpty = K.Label(self.inspector.body, ns.T("sellPanelEmpty"), 12, -48, 230, "secondary")
    self.panelEmpty:SetHeight(40); self.panelEmpty:SetJustifyV("TOP")
end
function UI:New(parent)
    if self.frame then return self end
    local K = ns.TradeKit
    local f = ns.NewFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    self.frame = f
    self.segment = K.Segment(f, {{key = "bags", label = ns.T("sellViewBags")}, {key = "owned", label = ns.T("sellViewOwned")}},
        function(view) self:SetView(view) end,
        {ns.T("sellViewTitle"), ns.T("sellViewTip")})
    self.segment.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -3)
    self:NewHeaders(f)
    self.scroll = K.TableScroll(f, function() self:Render() end, TOP, BOTTOM, ROW)
    for i = 1, 40 do
        local row = K.LedgerRow:New(f, function(key) self:Pick(key) end, function(key) self:Toggle(key) end)
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -TOP - (i - 1) * ROW)
        row.frame:Hide()
        self.rows[i] = row
        self.scroll:Wheel(row.frame)
    end
    self.empty = K.Label(f, "", 10, -66, 420)
    self.empty:SetHeight(60); self.empty:SetJustifyV("TOP")
    self.scan = K.Button(f, ns.T("sellScanBags"), 140, function()
        ns.Batch.Complete(ns.Selling.ScanIds(self.view), K.ScanMode(), true)
        self:Render()
    end, "control")
    self.scan:SetPoint("TOPRIGHT", f, "TOPRIGHT", -282, -3)
    K.ScanTip(self.scan, ns.T("sellScanBags"), ns.T("sellScanTip"), function() return ns.Selling.ScanIds(self.view) end)
    self:NewPanel(f)
    local function refresh() if self.frame:IsVisible() then self:Render() end end
    ns.Posting.Listen(refresh)
    ns.Selling.onChange = refresh
    f:SetScript("OnSizeChanged", function() self:Render() end)
    f:SetScript("OnShow", function() self:Opened() end)
    self:Render()
    return self
end
