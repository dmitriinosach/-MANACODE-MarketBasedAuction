local _, ns = ...
local UI = {props = {}, view = "bags", open = {}}
ns.SellingUI = UI
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
    if self.tables then self.tables[view]:ResetScroll() end
    self:Render()
end
function UI:Opened()
    if SetAuctionsTabShowing then SetAuctionsTabShowing(true) end
    if self.view ~= "bags" then self:SetView("bags")
    elseif self.stale then self:Render() end
end
function UI:Closed()
    if SetAuctionsTabShowing and not (AuctionFrameAuctions and AuctionFrameAuctions:IsShown()) then
        SetAuctionsTabShowing(false)
    end
end
function UI:Take(link, id)
    id = id or ns.Lot.FromLink(link)
    if not id then return end
    local name = ns.Compat.ItemInfo(link or id) or ns.Markets.Name(id)
    self.view, self.confirm = "bags", nil
    if ns.Posting.SelectedBag(id, link).count > 0 then
        self.props.id, self.props.link = id, link
        self.props.key = ns.Posting.ItemKey(link) or id
        self.reveal, self.note = self.props.key, ns.T("sellTaken", name)
    else
        self.note = ns.T("sellTakeNone", name)
    end
    self:Render()
end
function UI:DropCursor()
    local item = ns.Posting.CursorItem()
    if not item then return false end
    ClearCursor()
    self:Take(item.link, item.id)
    return true
end
function UI:SlotPlaced()
    if not (self.frame and self.frame:IsVisible()) then return end
    local item = ns.Posting.SlotItem()
    if not item then return end
    ns.Posting.Release()
    self:Take(item.link, item.id)
end
function UI:Bar()
    return self.barFrames
end
function UI:Controls()
    if not self.frame then return end
    self.scan:SetBusy(ns.Trader.Busy() and ns.T("batchBusy") or nil)
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
        mode = "sellway", depth = 1, nested = true, label = wayLabel(way), hasActions = true, actions = actions,
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
    local busy = ns.Scan.state.phase ~= "idle" or ns.Buy.Active()
    local rows = ns.Selling.BagRows(ns.Fee())
    self.bagRows = rows
    rows = self.tables.bags.sorter:Apply(rows, {
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
        local variant = type(row.key) == "string"
        local function sources() return {{id = row.id, auction = true}} end
        local opened = self.open[row.key] and #row.ways > 0
        local best = row.best and ("\n" .. ns.T("sellBestTip", wayLabel(row.best), K.Money(row.best.gain),
            K.Money(row.best.total))) or ""
        entries[#entries + 1] = {key = row.key, id = row.id, link = row.link, width = width, mode = "sell",
            active = row.key == self.props.key, tree = #row.ways > 0, expandable = #row.ways > 0, opened = opened,
            expandTip = {ns.T("sellWaysTitle"), ns.T("sellWaysTip")}, hasActions = true,
            actions = {{label = ns.T("cacheRefreshItem"), icon = "refresh", disabled = busy or variant,
                tip = ns.T(variant and "sellVariantTip" or "cacheRefreshTip"),
                sources = not variant and sources or nil, scanModes = {"hard"},
                fn = function()
                    if variant then return end
                    ns.Batch.Complete(sources(), "hard", true)
                    self:Render()
                end}},
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
    if CursorHasItem and CursorHasItem() and self:DropCursor() then return end
    if self.confirm ~= key then self.confirm = nil end
    for _, entry in ipairs(self.entries or {}) do
        if entry.key == key then
            if entry.parent then return self:Pick(entry.parent) end
            self:SetProps({id = entry.id, link = entry.link}); return
        end
    end
end
function UI:RenderTable()
    local bags = self.view == "bags"
    local tbl = self.tables[self.view]
    self.tables[bags and "owned" or "bags"].frame:Hide()
    tbl.frame:Show()
    ns.TradeKit.ScreenBody(tbl, self.inspector, self.sectionHead)
    local width = tbl:Width()
    local entries = bags and self:BagEntries(width) or self:OwnedEntries(width)
    self.entries = entries
    if not self.props.id or (bags and not self:Has(entries, self.props.key or self.props.id)) then
        local selected = entries[1]
        for _, entry in ipairs(entries) do if entry.id == self.props.id and not entry.parent then selected = entry; break end end
        if selected then
            self.props.id, self.props.link = selected.id, selected.link
            self.props.key = ns.Posting.ItemKey(selected.link) or selected.id
        end
    end
    local reveal
    if self.reveal then
        for i, entry in ipairs(entries) do if entry.key == self.reveal then reveal = i; break end end
        self.reveal = nil
    end
    tbl:SetLines(entries, function(entry)
        entry.active = not entry.parent
            and (ns.Posting.ItemKey(entry.link) or entry.id) == (self.props.key or self.props.id)
        return entry
    end, {reveal = reveal})
end
function UI:Has(entries, key)
    for _, entry in ipairs(entries) do if entry.key == key then return true end end
    return false
end
function UI:RenderSummary()
    local parts = {}
    local shown = #(self.entries or {})
    if self.view == "owned" and (self.ownedTotal or 0) > shown then
        parts[#parts + 1] = ns.T("sellOwnedMore", self.ownedTotal - shown)
    end
    local posting = self.view == "bags" and self.props.id and self.form.progress or ""
    if self.note then parts[#parts + 1] = self.note end
    if posting ~= "" then parts[#parts + 1] = posting end
    self.statusText = #parts > 0 and table.concat(parts, " | ") or nil
    if ns.Trader and ns.Trader.RenderStatus then ns.Trader.RenderStatus() end
end
function UI:RenderPanel()
    local K, id = ns.TradeKit, self.props.id
    if not id then
        self.inspector:Clear()
        self.panelScroll.frame:Hide()
        self.band.frame:Hide()
        self.panelEmpty:Show()
        return
    end
    self.panelEmpty:Hide(); self.panelScroll.frame:Show()
    self.inspector:SetProps({id = id, link = self.props.link})
    self.inspector.item.extraTip = ns.T("itemHistoryOpenTip") .. (type(self.props.key) == "string"
        and ("\n" .. ns.T("sellVariantTip")) or "")
    local Form = K.PostForm
    local width, levels = self.inspector.width or 264, Form.LEVELS_MAX
    local height = self:LayPanel(id, width, levels)
    local room = self.panelScroll:Room()
    while room > 0 and height > room and math.min(levels, self.form.shown) > Form.LEVELS_MIN do
        levels = math.min(levels, self.form.shown) - 1
        height = self:LayPanel(id, width, levels)
    end
    local fitted = self.panelScroll:Fit(height)
    if fitted ~= width then
        height = self:LayPanel(id, fitted, levels)
        self.panelScroll:Fit(height)
    end
end
function UI:LayPanel(id, width, levels)
    self.form:SetProps({id = id, link = self.props.link, fee = ns.Fee(), width = width, levels = levels, band = self.band,
        reference = self:Reference(id),
        onChange = function() self:RenderPanel(); self:RenderSummary() end,
        onPosted = function() self:Render() end,
        onCheckOwned = function() self.note = ns.T("postCheckPendingNote"); self:SetView("owned") end})
    return self.form.height
end
function UI:Reference(id)
    local flow, days = ns.Selling.Flow(id), ns.Selling.FLOW_DAYS
    if not flow.median then return nil end
    local early = flow.compared > 0 and ns.T("sellFlowEarlyValue", flow.earlyUnits, flow.early) or ns.T("sellFlowNone")
    return {text = ns.T("sellReference", days, ns.TradeKit.Money(flow.median)), title = ns.T("sellPricesTitle", days),
        tip = ns.T("sellPricesTip") .. "\n" .. early}
end
function UI:Render()
    if not self.frame then return end
    local K = ns.TradeKit
    self.stale = nil
    self.segment:Select(self.view)
    self:RenderTable()
    local owned = self.view == "owned"
    self.scan:SetText(ns.T(owned and "sellBarOwned" or "sellBarBags"))
    self.scan.tipTitle = ns.T(owned and "sellScanOwned" or "sellScanBags")
    K.FitButton(self.scan, 20)
    self:RenderPanel()
    self:RenderSummary()
    self:Controls()
end
function UI:NewTables(f)
    local K = ns.TradeKit
    local specs = {
        bags = {{key = "item", text = "sellColItem"}, {key = "quality", text = "sellColQuality", tip = "sellQualityTip"},
            {key = "count", text = "matColCount"}, {key = "held", text = "sellColHeld", tip = "sellHeldTip"},
            {key = "market", text = "matColMarket"}, {key = "value", text = "sellColEstimate"},
            {key = "best", text = "sellColBest"}, {key = "mine", text = "sellColMine"}},
        owned = {{key = "item", text = "sellColItem"}, {key = "stack", text = "sellColStack"},
            {key = "unit", text = "buyColUnit"}, {key = "buyout", text = "sellColBuyout"},
            {key = "left", text = "sellColLeft"}, {key = "standing", text = "sellColStanding"}},
    }
    self.tables = {}
    for mode, headers in pairs(specs) do
        local bags = mode == "bags"
        self.tables[mode] = K.Table:New(f, {
            height = K.Table.LINE, headers = headers,
            columns = function(width)
                local cols = K.LedgerColumns(width, bags and "sell" or "owned", true)
                if bags then
                    local itemWidth = cols.item[2]
                    cols.quality = {cols.item[1] + itemWidth - QUALITY, QUALITY}
                    cols.item[2] = itemWidth - QUALITY
                end
                return cols
            end,
            sort = bags and {default = {key = "item", desc = false}} or nil,
            changed = function() self:Render() end,
            empty = bags and "sellBagsEmpty" or "sellOwnedEmpty",
            kinds = {row = {new = function(parent)
                local row = K.LedgerRow:New(parent, function(key) self:Pick(key) end, function(key) self:Toggle(key) end)
                row.frame:HookScript("OnReceiveDrag", function() self:DropCursor() end)
                return row
            end}},
        })
    end
end
function UI:NewPanel(f)
    local K = ns.TradeKit
    self.inspector = K.Inspector:New(f)
    self.panelScroll = K.PanelScroll:New(self.inspector, "ManaCodeSellingPanelScroll", K.PostForm.HEIGHT)
    local panel = self.panelScroll.child
    self.panelChild = panel
    self.band = K.ActionBand:For(self.inspector, self.panelScroll, true)
    self.form = K.PostForm:New(panel)
    self.form:Place(0)
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
    self:NewTables(f)
    self.scan = K.ScanBarButton(f, {label = ns.T("sellBarBags"),
        run = function(mode)
            ns.Batch.Complete(ns.Selling.ScanIds(self.view), mode, true)
            self:Render()
        end,
        sources = function() return ns.Selling.ScanIds(self.view) end,
        body = ns.T("sellScanTip")})
    self.barFrames = {self.scan}
    local hint = ns.NewFrame("Frame", nil, f)
    hint:SetWidth(260); hint:SetHeight(22)
    self.dropHint = K.Label(hint, ns.T("sellDropHint"), 0, -5, 260, "secondary")
    self.dropHint:SetHeight(12)
    self.sectionHead = K.SectionHead:New(f)
    self.sectionHead:SetProps({lead = self.segment.frame, filters = {hint}})
    self:NewPanel(f)
    local function drop() self:DropCursor() end
    for _, frame in ipairs({f, self.inspector.frame, self.panelChild}) do
        frame:EnableMouse(true)
        frame:HookScript("OnReceiveDrag", drop)
        frame:HookScript("OnMouseUp", function() if CursorHasItem and CursorHasItem() then drop() end end)
    end
    local function refresh() if self.frame:IsVisible() then self:Render() else self.stale = true end end
    ns.Posting.Listen(refresh)
    ns.Selling.onChange = refresh
    f:SetScript("OnSizeChanged", function() self:Render() end)
    f:SetScript("OnShow", function() self:Opened() end)
    f:SetScript("OnHide", function() self:Closed() end)
    self:Render()
    return self
end
local slotEvents = ns.NewFrame("Frame")
ns.Listen(slotEvents, "NEW_AUCTION_UPDATE")
slotEvents:SetScript("OnEvent", function() UI:SlotPlaced() end)
