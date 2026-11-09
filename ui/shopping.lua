local _, ns = ...
local UI = { page = 1, options = {}, filters = {} }
ns.ShoppingUI = UI
local LEFT = 236
local PANEL = 272
local BOTTOM = 42
local SEARCH_ROW = 28
local QUERY = 240
local QUERY_MIN = 160
UI.PANEL_TOP = -46
UI.STAT_STEP = 15
local function money(copper)
    return GetCoinTextureString(math.floor(copper))
end
function UI.Sides(width)
    local shrink = math.max(0, math.min(180, 996 - width))
    return math.floor(236 - shrink / 4), math.floor(272 - shrink / 4)
end
function UI:FitSides()
    local left, panel = UI.Sides(self.frame:GetWidth() or 996)
    if left == LEFT and panel == PANEL and self.sidesFitted then return end
    LEFT, PANEL, self.sidesFitted = left, panel, true
    local f = self.frame
    self.resultsLabel:SetWidth(LEFT - 20)
    self.heading:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT + 10, -37 - SEARCH_ROW)
    self.inspector.width = PANEL
    self.inspector:Layout()
    for _, label in ipairs({self.panelNow, self.panelHistory, self.panelEmpty}) do label:SetWidth(PANEL - 40) end
end
function UI:Render()
    if not self.frame then return end
    self:FitSides()
    local Shop, K = ns.Shopping, ns.TradeKit
    local S, R = Shop.state, ns.Buy.state
    local active = ns.Buy.Active()
    local busy = active or ns.Scan.state.phase ~= "idle"
    if S.request and S.request ~= self.lastRequest then
        self.filters = {}
        for key, value in pairs(S.filters or {}) do self.filters[key] = value end
        if S.request.itemID then
            self.intent = {kind = "item", id = S.request.itemID, name = S.request.query}
            self.query:SetText(S.request.query)
        end
    end
    self.lastRequest = S.request
    self:RenderSearch(busy)
    local width = self.frame:GetWidth() or 996
    local right = math.max(300, width - LEFT - 20 - PANEL)
    self.choiceTable:Place({top = 54 + SEARCH_ROW, bottom = 36, right = width - LEFT + 6})
    self.choiceTable:SetLines(self:ChoiceEntries(), function(entry)
        return {entry = entry, selected = entry.id == S.itemID}
    end, {empty = "buyRecentEmpty", tree = false})
    self:RenderCenter(right, active)
    self.need:SetMaxLetters(S.priceLimit and 8 or 5)
    if not (self.pendingNeed and self.need:HasFocus()) then self.need:SetText(tostring(S.need)) end
    self.need:EnableMouse(not active and not S.priceLimit)
    if Shop.Got() > 0 then
        self.summary:SetText(ns.T("buyProgress", Shop.Got(), S.need, money(Shop.Spent())))
    elseif S.plan then
        self.summary:SetText(ns.T("buyTotal", S.plan.units, money(S.plan.cost)))
    elseif S.itemID then self.summary:SetText(ns.T("buyAvailable", ns.Plan.Available(S.offers)))
    else self.summary:SetText("") end
    local state = {title = ns.T("buySection"), tip = ns.T("buyGoTip")}
    if active then
        state.confirm = R.phase == "ready"
        state.searching = not state.confirm
    elseif Shop.Left() == 0 then state.reason = ns.T("buyGoReachedTip")
    elseif S.plan then state.reason = ns.Scan.state.phase ~= "idle" and ns.T("batchBusy") or nil
    else state.reason = ns.T("buyGoEmptyTip") end
    self.go:SetState(state)
    K.FitButton(self.go, 40)
    self:RenderPanel()
end
function UI:RenderCenter(right, active)
    local S = ns.Shopping.state
    local results = S.results
    local slot = {"TOPRIGHT", self.frame, "TOPLEFT", LEFT + 10 + right, -33 - SEARCH_ROW}
    self.back:Hide(); self.more:Hide(); self.next:Hide()
    if S.itemID == nil then
        self.purchase:Display(false)
        local title = S.catalog and ns.T("searchCatalog") or ns.T("buyResults")
        if results and not results.complete and not results.catalog and results.pages then
            title = ns.T("buyResultsPart", title, results.read or 0, results.pages)
            self.more:ClearAllPoints(); self.more:SetPoint(unpack(slot)); self.more:Show()
            self.next:ClearAllPoints(); self.next:SetPoint("RIGHT", self.more, "LEFT", -6, 0); self.next:Show()
            local busy = ns.Scan.state.phase ~= "idle" or active
            for _, b in ipairs({self.more, self.next}) do if busy then b:Disable() else b:Enable() end end
        end
        self.heading:SetText(title)
        self.resultsTable:Place({top = 56 + SEARCH_ROW, left = LEFT + 6, right = self.inspector, bottom = BOTTOM})
        local empty = S.pendingID and "buyLotsPending" or S.catalog and "searchNoCatalogItems"
            or results and "buyNoResults" or "buyEmptyTable"
        local lines = {}
        for i, item in ipairs(results and results.items or {}) do lines[i] = {item = item} end
        self.resultsTable:SetLines(lines, function(line, _, columns)
            local item = line.item
            return {id = item.id, columns = columns, noRefresh = true, marginText = "",
                quote = item.min and {price = item.min, units = item.units} or nil,
                detail = item.detail or item.lots and ns.T("buyResultLots", item.lots) or nil}
        end, {empty = empty})
        self.resultsTable.frame:Show()
        return
    end
    self.resultsTable.frame:Hide()
    self.heading:SetText(S.name or ns.T("buyNoSelection"))
    if results then
        self.back:ClearAllPoints(); self.back:SetPoint(unpack(slot)); self.back:Show()
        if active then self.back:Disable() else self.back:Enable() end
    end
    self.purchase:Display(true)
    self.purchase:Place({x = LEFT + 10, top = 56 + SEARCH_ROW, width = right, left = LEFT + 6, right = self.inspector,
        bottom = BOTTOM})
    self.purchase:Render({active = active, empty = S.pendingID and "buyLotsPending" or "buyNoLots"})
end
function UI:ChoiceEntries()
    local recent = {}
    for _, entry in ipairs(ns.Shopping.History()) do
        recent[#recent + 1] = {result = "recent", id = entry.id, need = entry.need or 1, last = entry.last}
    end
    return recent
end
function UI:PickChoice(entry, button)
    if entry.result ~= "recent" then return end
    if button == "RightButton" then return ns.Shopping.Forget(entry.id) end
    self.query:SetText(ns.Markets.Name(entry.id)); self.query:ClearFocus()
    self.choiceTable:ResetScroll(); self.offerTable:ResetScroll()
    ns.Shopping.Repeat(entry.id)
end
function UI:Show(id, need)
    self.intent, self.filters = nil, {}
    self.query:SetText(ns.Markets.Name(id) or ""); self.query:ClearFocus()
    self.pendingNeed = nil
    ns.Shopping.Show(id, need)
end
function UI:RenderPanel()
    local K, S = ns.TradeKit, ns.Shopping.state
    local id = S.itemID
    local stats = id and ns.Shopping.Stats(S.offers)
    if not id then
        self.inspector:Clear()
        for _, row in ipairs(self.stats) do row.key:Hide(); row.value:Hide() end
        self.panelNow:Hide(); self.panelHistory:Hide()
        self.panelEmpty:Show()
        return
    end
    self.panelEmpty:Hide(); self.panelNow:Show(); self.panelHistory:Show()
    self.inspector:SetProps({id = id})
    local board = ns.Activity and ns.Activity.Board(id, 7)
    local values = {
        stats and K.Money(stats.min), stats and K.Money(stats.market), stats and K.Money(stats.median),
        stats and K.Money(stats.mean), stats and ns.T("buyStatSupplyValue", stats.units, stats.lots),
        board and board.median and K.Money(board.median),
    }
    local entry = ns.Shopping.Entry(id)
    local last = entry and entry.last
    values[7] = last and (last.units or 0) > 0
        and ns.T("buyLastValue", last.units, K.Money(math.floor(last.spent / last.units))) or ns.T("buyLastNone")
    for i, row in ipairs(self.stats) do
        row.key:Show(); row.value:Show()
        row.value:SetText(values[i] or ns.T("tradeNoPrice"))
    end
end
function UI:NewPanel(frame)
    local K = ns.TradeKit
    self.inspector = K.Inspector:New(frame)
    self.inspector:Place(-34 - SEARCH_ROW, 40)
    local panel = self.inspector.body
    self.panel = panel
    self.panelNow = K.Label(panel, ns.T("buyPanelNow"), 12, UI.PANEL_TOP, PANEL - 40, "heading")
    self.panelNow:SetHeight(14)
    K.Tooltip(panel, ns.T("buyPanelNow"), ns.T("buyPanelTip") .. "\n\n" .. ns.T("buyStatMarketTip"))
    self.stats = {}
    local keys = {"buyStatMin", "buyStatMarket", "buyStatMedian", "buyStatMean", "buyStatSupply", "buyStatWeek", "buyStatLast"}
    local step, historyTop = UI.STAT_STEP, UI.PANEL_TOP - 18 - 5 * UI.STAT_STEP - 4
    for i, key in ipairs(keys) do
        local y = i <= 5 and UI.PANEL_TOP - 18 - (i - 1) * step or historyTop - 18 - (i - 6) * step
        local label, value = K.ValueRow(panel, ns.T(key), y, 110, 124)
        self.stats[i] = {key = label, value = value}
    end
    self.panelHistory = K.Label(panel, ns.T("buyPanelHistory"), 12, historyTop, PANEL - 40, "heading")
    self.panelHistory:SetHeight(14)
    self.panelEmpty = K.Label(panel, ns.T("buyPanelEmpty"), 12, UI.PANEL_TOP, PANEL - 40, "secondary")
    self.panelEmpty:SetHeight(40); self.panelEmpty:SetJustifyV("TOP")
end
function UI.InsertLink(text)
    if type(text) ~= "string" or not text:find("item:", 1, true) then return end
    local chat = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if chat and chat:IsShown() then return end
    if ChatFrameEditBox and ChatFrameEditBox:IsShown() and ChatFrameEditBox:HasFocus() then return end
    local trader = ns.Trader and ns.Trader.frame
    if not trader or not trader:IsVisible() then return end
    local id = ns.Lot.FromLink(text)
    if id then ns.Trader.OpenBuy(id) end
end
function UI:ChooseSearch(entry)
    if ns.Buy.Active() or ns.Scan.state.phase ~= "idle" then return end
    if entry.id then entry.kind = "item" end
    self.intent = entry
    self.choiceTable:ResetScroll(); self.offerTable:ResetScroll()
    if entry.kind == "item" then
        self.query:SetText(entry.name); self.query:ClearFocus()
        ns.Shopping.Search(entry.name, entry.id, self.filters)
    elseif entry.kind == "category" then
        self.filters.classIndex, self.filters.subClassIndex = entry.classIndex, entry.subClassIndex
        self.query:SetText("")
        self:Render()
    elseif entry.kind == "preset" then
        self.filters = {minQuality = self.filters.minQuality}
        self.query:SetText("")
        ns.Shopping.Catalog(entry.preset, self.filters)
    end
end
function UI:SearchReason(busy)
    if busy then return ns.T("batchBusy") end
    local intent = self.intent
    if intent and (intent.kind == "item" or intent.kind == "preset") then return nil end
    if (self.query:GetText() or ""):find("%S") or self.filters.classIndex then return nil end
    return ns.T("buySearchEmpty")
end
function UI:Search()
    local filters = self.filtersView:Values()
    if not filters then return end
    self.filters = filters
    if self:SearchReason(false) then self:Render(); return end
    self.query:ClearFocus()
    self.choiceTable:ResetScroll(); self.offerTable:ResetScroll()
    if self.intent and self.intent.kind == "preset" then
        ns.Shopping.Catalog(self.intent.preset, filters)
    else
        ns.Shopping.Search(self.query:GetText(), self.intent and self.intent.kind == "item" and self.intent.id or nil, filters)
    end
end
function UI:RenderSearch(busy)
    local K, S = ns.TradeKit, ns.Shopping.state
    self.filtersView:SetProps({filters = self.filters, disabled = busy, changed = self.filtersChanged})
    local width = self.frame:GetWidth() or 996
    self.query:SetWidth(math.max(QUERY_MIN, math.min(QUERY, width - 34 - K.AuctionFilters.WIDTH - (self.search:GetWidth() or 64))))
    self.query:EnableMouse(not busy)
    if busy then self.query:ClearFocus(); self.suggest:Hide() end
    local reason = self:SearchReason(busy)
    K.DisabledTip(self.search, ns.T("buySearch"), reason)
    if reason then self.search:Disable() else self.search:Enable() end
    local label = self.intent and (self.intent.kind == "preset" and ns.Search.Label(self.intent.preset)
        or self.intent.label or self.intent.name)
    if label then
        self.condition:SetText(ns.T("searchCondition", label)); self.condition:Show()
        K.FitButton(self.condition, 20)
        self.condition:SetWidth(math.min(self.condition:GetWidth() or 200, math.max(100, (self.frame:GetWidth() or 996) - PANEL - 190)))
        if busy then self.condition:Disable() else self.condition:Enable() end
    else self.condition:Hide() end
end
function UI:NewSearch(frame)
    local K = ns.TradeKit
    self.search = K.Button(frame, ns.T("buySearch"), 80, nil)
    K.FitButton(self.search, 32)
    K.Tooltip(self.search, ns.T("buySearch"), ns.T("buySearchTip"))
    self.query = K.Edit(frame, QUERY, true, ns.T("searchPlaceholder"))
    self.query:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -3)
    self.query:SetMaxLetters(120)
    self.search:SetPoint("LEFT", self.query, "RIGHT", 6, 0)
    K.ClearButton(self.query, function() self.intent = nil; self:Render() end)
    self.query:SetScript("OnEnterPressed", function()
        if self.suggest:Pick() then return end
        self:Search()
    end)
    self.query:HookScript("OnTextChanged", function(_, user)
        if user then self.intent = nil; self:Render() end
    end)
    self.suggest = K.Suggest(self.query, function(text) return ns.Search.Suggest(text, self.filters) end,
        function(entry) self:ChooseSearch(entry) end, 17, ns.T("buySuggestNone"))
    K.Tooltip(self.query, ns.T("buyQueryLabel"), ns.T("buySuggestTip"))
    self.search.onClick = function() self:Search() end
    self.filtersChanged = function(filters)
        self.filters = filters
        if self.intent and self.intent.kind == "category" then self.intent = nil end
        self:Render()
    end
    self.filtersView = K.AuctionFilters:New(frame, self.filtersChanged)
    self.filtersView.frame:SetPoint("LEFT", self.search, "RIGHT", 8, 0)
    self.filtersView.search = function() self:Search() end
    self.condition = K.Button(frame, "", 200, function()
        self.intent = nil
        self.query:SetText("")
        self.filters.classIndex, self.filters.subClassIndex = nil, nil
        if ns.Shopping.state.catalog then ns.Shopping.ClearCatalog() else self:Render() end
    end, "quiet")
    self.condition:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -34)
    K.Tooltip(self.condition, ns.T("searchClear"), "")
end
function UI:NewNeed(frame)
    local K = ns.TradeKit
    local reset = K.Button(frame, ns.T("buyReset"), 64, function() ns.Shopping.Reset() end, "quiet")
    reset:SetPoint("RIGHT", self.go, "LEFT", -16, 0)
    K.Tooltip(reset, ns.T("buyReset"), ns.T("buyResetTip"))
    local plus = K.Button(frame, "+", 22, function() ns.Shopping.SetNeed(ns.Shopping.state.need + (IsShiftKeyDown() and 10 or 1)) end, "quiet")
    plus:SetPoint("RIGHT", reset, "LEFT", -10, 0)
    K.Tooltip(plus, ns.T("buyCapNeed"), ns.T("buyNeedStepTip"))
    self.need = K.Edit(frame, 64)
    self.need:SetPoint("RIGHT", plus, "LEFT", -4, 0)
    self.need:SetNumeric(true)
    self.need:SetMaxLetters(5)
    self.need:SetScript("OnTextChanged", function(edit, user)
        if user then self.pendingNeed, self.pendingAt = tonumber(edit:GetText()) or 1, GetTime() + 0.3 end
    end)
    self.need:SetScript("OnEnterPressed", function(edit) edit:ClearFocus() end)
    local minus = K.Button(frame, "-", 22, function() ns.Shopping.SetNeed(ns.Shopping.state.need - (IsShiftKeyDown() and 10 or 1)) end, "quiet")
    minus:SetPoint("RIGHT", self.need, "LEFT", -4, 0)
    K.Tooltip(minus, ns.T("buyCapNeed"), ns.T("buyNeedStepTip"))
    local needLabel = K.Label(frame, ns.T("buyCapNeed"), 0, 0, 86, "secondary")
    needLabel:SetHeight(12); needLabel:SetJustifyH("RIGHT"); needLabel:ClearAllPoints()
    needLabel:SetPoint("RIGHT", minus, "LEFT", -6, 0)
    return needLabel
end
function UI:NewPlan(frame)
    local K = ns.TradeKit
    self.heading = K.Label(frame, "", LEFT + 10, -37 - SEARCH_ROW, 500, "heading")
    self.heading:SetHeight(14)
    self.back = K.Button(frame, ns.T("buyBackResults"), 100, function() ns.Shopping.Back() end, "quiet")
    self.back:SetHeight(20); K.FitButton(self.back, 20); self.back:Hide()
    K.Tooltip(self.back, ns.T("buyBackResults"), "")
    self.more = K.Button(frame, ns.T("buyResultsAll"), 100, function() ns.Shopping.More(true) end, "quiet")
    self.next = K.Button(frame, ns.T("buyResultsNext"), 100, function() ns.Shopping.More(false) end, "quiet")
    self.next:SetHeight(20); K.FitButton(self.next, 20); self.next:Hide()
    K.Tooltip(self.next, ns.T("buyResultsNext"), "")
    self.more:SetHeight(20); K.FitButton(self.more, 20); self.more:Hide()
    K.Tooltip(self.more, ns.T("buyResultsAll"), "")
    self.purchase = K.PurchasePanel:New(frame, {money = money, onLimit = function() self.pendingNeed = nil end})
    self.options, self.limitLabel, self.limit = self.purchase.options, self.purchase.limitLabel, self.purchase.limit
    self.lastLimit, self.offerTable = self.purchase.lastLimit, self.purchase.table
end
function UI:NewTables(frame)
    local K = ns.TradeKit
    local function newItem(parent)
        return K.ShoppingItemRow:New(parent, function(entry, button) self:PickChoice(entry, button) end)
    end
    self.choiceTable = K.Table:New(frame, {
        height = K.Table.LINE,
        kinds = {row = {new = newItem}},
    })
    self.resultsTable = K.Table:New(frame, {
        headers = {{key = "item", text = "buyQueryLabel"}, {key = "price", text = "buyColFrom"},
            {key = "units", text = "tradeUnits"}},
        columns = function(width, tbl) return K.MarketColumns(width - tbl:Row("row", 1):Reserve()) end,
        kinds = {row = {new = function(parent)
            return K.MarketRow:New(parent, function(id)
                self.offerTable:ResetScroll()
                ns.Shopping.Open(id)
            end)
        end}},
    })
end
function UI:New(parent)
    if self.frame then return self end
    local K = ns.TradeKit
    local frame = ns.NewFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    self.frame = frame
    self:NewSearch(frame)
    self.resultsLabel = K.Label(frame, ns.T("buyRecent"), 10, -37 - SEARCH_ROW, LEFT - 20, "heading")
    self.resultsLabel:SetHeight(14)
    self:NewTables(frame)
    self:NewPlan(frame)
    self:NewPanel(frame)
    local foot = K.Rule(frame, 0)
    foot:ClearAllPoints()
    foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 36); foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 36)
    self.summary = K.Label(frame, "", 10, 0, 400)
    self.summary:SetHeight(12)
    self.summary:ClearAllPoints(); self.summary:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 11)
    self.go = K.BuyButton(frame, function()
        self.limit:Flush(); self.limit:ClearFocus()
        ns.Shopping.Go()
    end, 120)
    self.go:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 4)
    self.summary:SetPoint("RIGHT", self:NewNeed(frame), "LEFT", -10, 0)
    frame:SetScript("OnUpdate", function()
        if self.pendingNeed and GetTime() >= self.pendingAt then
            local need = self.pendingNeed
            self.pendingNeed = nil
            ns.Shopping.SetNeed(need)
        end
    end)
    frame:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
ns.Shopping.onChange = function() UI:Render() end
if type(ChatEdit_InsertLink) == "function" then hooksecurefunc("ChatEdit_InsertLink", UI.InsertLink) end
