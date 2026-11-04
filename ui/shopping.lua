local _, ns = ...
local UI = { page = 1, choices = {}, options = {}, rows = {}, filters = {} }
ns.ShoppingUI = UI
local LEFT = 236
local PANEL = 272
local BOTTOM = 42
local SEARCH_ROW = 28
local QUERY = 240
local QUERY_MIN = 160
local function money(copper)
    return GetCoinTextureString(math.floor(copper))
end
function UI:Render()
    if not self.frame then return end
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
    local entries = self:ChoiceEntries()
    self.resultsLabel:SetText(ns.T(S.catalog and "searchCatalog" or (#S.items == 0 and entries[1]) and "buyRecent" or "buyResults"))
    local choiceStep = S.catalog and 40 or 28
    local visibleChoices = K.ListCapacity(self.frame, 54 + SEARCH_ROW, 36, choiceStep, #self.choices)
    local choiceOffset = self.choiceScroll:SetRange(#entries, visibleChoices)
    self.rowEntries = {}
    for i, b in ipairs(self.choices) do
        local entry = i <= visibleChoices and entries[choiceOffset + i]
        self.rowEntries[i] = entry or nil
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 6, -54 - SEARCH_ROW - (i - 1) * choiceStep)
        b:SetHeight(choiceStep - 2)
        b:SetWidth(LEFT - 18)
        b.head:Hide(); b.need:SetText(""); b.extraTip = nil
        b.detail:SetText(entry and entry.detail or "")
        b.text:ClearAllPoints(); b.text:SetPoint("LEFT", b, "LEFT", 28, entry and entry.detail and 7 or 0)
        if not entry then b:Hide()
        elseif entry.kind == "head" then b:Hide(); b.head:Show()
        else
            b.text:SetWidth(LEFT - 52 - (entry.kind == "recent" and 54 or 0))
            K.SetItemChoice(b, entry.id, entry.kind == "item" and entry.id == S.itemID)
            if entry.name then b.text:SetText(entry.name) end
            if entry.detail then b.extraTip = ns.T("searchCatalogTip") end
            if entry.kind == "recent" then
                b.need:SetText(ns.T("buyHistoryNeed", entry.need))
                b.extraTip = ns.T("buyHistoryTip", entry.need)
                local last = entry.last
                if last and (last.units or 0) > 0 then
                    b.extraTip = b.extraTip .. "\n" .. ns.T("buyLastTip", last.units,
                        K.Money(math.floor(last.spent / last.units)), K.Ago(math.max(0, time() - (last.at or 0))))
                end
            end
        end
    end
    self.heading:SetText(S.name or ns.T("buyNoSelection"))
    self.need:SetMaxLetters(S.priceLimit and 8 or 5)
    if not (self.pendingNeed and self.need:HasFocus()) then self.need:SetText(tostring(S.need)) end
    self.limit:SetValue(S.priceLimit)
    self.limit:SetEnabled(not active)
    local lastUnit = S.itemID and Shop.LastUnit(S.itemID)
    if lastUnit then self.lastLimit:Show() else self.lastLimit:Hide() end
    if active or not lastUnit or S.priceLimit == lastUnit then self.lastLimit:Disable() else self.lastLimit:Enable() end
    self.need:EnableMouse(not active and not S.priceLimit)
    local optionCount = 0
    for i, b in ipairs(self.options) do
        local plan = S.options[i]
        b:SetWidth(right)
        if plan then
            optionCount = i
            b:SetText(ns.T("buyOpt_" .. plan.kind, plan.units, money(plan.cost)))
            b:SetActive(S.plan ~= nil and S.plan.kind == plan.kind)
            if active then b:Disable() else b:Enable() end
            b:Show()
        else b:Hide() end
    end
    local shown, seen = {}, {}
    if S.plan then
        for _, pick in ipairs(S.plan.picks) do
            if pick.lots > 0 then shown[#shown + 1] = pick.offer; seen[pick.offer] = true end
        end
    end
    for _, offer in ipairs(S.offers) do
        if not seen[offer] and offer.count > 0 then shown[#shown + 1] = offer end
    end
    local top = self:PlaceTable(optionCount)
    local visibleOffers = K.ListCapacity(self.frame, top, BOTTOM, 22, #self.rows)
    local offerOffset = self.offerScroll:SetRange(#shown, visibleOffers)
    local inner = right - 22
    self.offerHead:SetWidth(inner)
    self.tableHint:SetWidth(inner - 24)
    if not S.itemID and not S.catalog and #S.items == 0 and not S.pendingID then self.tableHint:Show() else self.tableHint:Hide() end
    local columns = {plan = {38, 90}, unit = {inner - 264, 110}, lot = {inner - 144, 110}}
    local room = columns.unit[1] - 130 - 6
    if room >= 50 then columns.stack = {130, math.min(80, room)} end
    if columns.unit[1] < 130 then columns.unit = {130, math.max(60, columns.lot[1] - 136)} end
    for key, label in pairs(self.columns) do
        label:ClearAllPoints()
        if columns[key] then
            label:SetPoint("TOPLEFT", self.offerHead, "TOPLEFT", columns[key][1], -4)
            label:SetWidth(columns[key][2]); label:Show()
        else label:Hide() end
    end
    for i, row in ipairs(self.rows) do
        row.frame:SetWidth(inner)
        local offer = i <= visibleOffers and shown[offerOffset + i]
        if offer then
            row.offer = offer
            for key, cell in pairs(row.cells) do
                cell:ClearAllPoints()
                if columns[key] then
                    cell:SetPoint("TOPLEFT", row.frame, "TOPLEFT", columns[key][1], -5)
                    cell:SetWidth(columns[key][2]); cell:Show()
                else cell:Hide() end
            end
            row.frame.extraTip = not columns.stack and ns.T("buyStackRow", offer.stack) or nil
            local picked = S.plan and ns.Plan.LotsOf(S.plan, offer) or 0
            row.cells.plan:SetText(ns.T("buyPlanRow", picked, offer.count))
            row.cells.plan:SetTextColor(unpack(K.theme[picked == 0 and "text" or "positive"]))
            if picked > 0 then row.match:Show(); row.matchBar:Show() else row.match:Hide(); row.matchBar:Hide() end
            row.cells.stack:SetText(ns.T("buyStackRow", offer.stack))
            row.cells.unit:SetText(money(offer.buyout / offer.stack))
            row.cells.lot:SetText(money(offer.buyout))
            if i % 2 == 1 then row.stripe:Show() else row.stripe:Hide() end
            row.frame:Show()
            if active then row.minus:Disable(); row.plus:Disable()
            else
                row.minus:Enable()
                if S.priceLimit and offer.buyout >= S.priceLimit * offer.stack then row.plus:Disable() else row.plus:Enable() end
            end
        else row.frame:Hide() end
    end
    if Shop.Got() > 0 then
        self.summary:SetText(ns.T("buyProgress", Shop.Got(), S.need, money(Shop.Spent())))
    elseif S.plan then
        self.summary:SetText(ns.T("buyTotal", S.plan.units, money(S.plan.cost)))
    else self.summary:SetText(ns.T("buyAvailable", ns.Plan.Available(S.offers))) end
    local reason
    if active then
        local n, cost = ns.Buy.Offer()
        self.go:SetText(R.phase == "ready" and ns.T("buyConfirm", n, money(cost)) or ns.T("buyFinding", R.page + 1))
        if R.phase ~= "ready" then reason = ns.T("buyFindingTip") end
    elseif Shop.Left() == 0 then
        self.go:SetText(ns.T("buyGoReached")); reason = ns.T("buyGoReachedTip")
    elseif S.plan then
        self.go:SetText(ns.T("buyGo", S.plan.units, money(S.plan.cost)))
        if ns.Scan.state.phase ~= "idle" then reason = ns.T("batchBusy") end
    else self.go:SetText(ns.T("buyGoEmpty")); reason = ns.T("buyGoEmptyTip") end
    K.DisabledTip(self.go, ns.T("buySection"), reason)
    if reason then self.go:Disable() else self.go:Enable() end
    K.FitButton(self.go, 40)
    self:RenderPanel()
end
function UI:PlaceTable(options)
    local limitTop = 64 + SEARCH_ROW + options * 25
    local top = limitTop + 43
    if self.tableTop == top then return top end
    self.tableTop = top
    local frame = self.frame
    self.limitLabel:ClearAllPoints()
    self.limitLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT + 10, -limitTop)
    self.offerHead:ClearAllPoints()
    self.offerHead:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT + 10, -(limitTop + 21))
    self.offerScroll.frame:ClearAllPoints()
    self.offerScroll.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT + 10, -top)
    self.offerScroll.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8 - PANEL, BOTTOM)
    for i, row in ipairs(self.rows) do
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT + 10, -top - (i - 1) * 22)
    end
    return top
end
function UI:ChoiceEntries()
    local S = ns.Shopping.state
    local entries, found = {}, {}
    for _, item in ipairs(S.items) do
        entries[#entries + 1] = {kind = "item", id = item.id, name = item.name, detail = item.detail}
        found[item.id] = true
    end
    if S.catalog then return entries end
    local recent = {}
    for _, entry in ipairs(ns.Shopping.History()) do
        if not found[entry.id] then
            recent[#recent + 1] = {kind = "recent", id = entry.id, need = entry.need or 1, last = entry.last}
        end
    end
    if #recent > 0 and #entries > 0 then entries[#entries + 1] = {kind = "head"} end
    for _, entry in ipairs(recent) do entries[#entries + 1] = entry end
    return entries
end
function UI:PickChoice(i, button)
    local entry = self.rowEntries and self.rowEntries[i]
    if not entry then return end
    if entry.kind == "item" then return ns.Shopping.Select(entry.id) end
    if entry.kind ~= "recent" then return end
    if button == "RightButton" then return ns.Shopping.Forget(entry.id) end
    self.query:SetText(ns.Markets.Name(entry.id)); self.query:ClearFocus()
    self.choiceScroll.offset, self.offerScroll.offset = 0, 0
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
    local quote = ns.Markets.Quote(id)
    local values = {
        stats and K.Money(stats.min), stats and K.Money(stats.market), stats and K.Money(stats.median),
        stats and K.Money(stats.mean), stats and ns.T("buyStatSupplyValue", stats.units, stats.lots),
        board and board.median and K.Money(board.median),
        quote and quote.at and not quote.vendor and K.Ago(math.max(0, time() - quote.at)),
    }
    local entry = ns.Shopping.Entry(id)
    local last = entry and entry.last
    values[8] = last and (last.units or 0) > 0
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
    self.panelNow = K.Label(panel, ns.T("buyPanelNow"), 12, -48, PANEL - 40, "heading")
    self.panelNow:SetHeight(14)
    K.Tooltip(panel, ns.T("buyPanelNow"), ns.T("buyPanelTip") .. "\n\n" .. ns.T("buyStatMarketTip"))
    self.stats = {}
    local keys = {"buyStatMin", "buyStatMarket", "buyStatMedian", "buyStatMean", "buyStatSupply", "buyStatWeek", "buyStatScan",
        "buyStatLast"}
    for i, key in ipairs(keys) do
        local y = -68 - (i - 1) * 18 - (i >= 6 and 28 or 0)
        local label, value = K.ValueRow(panel, ns.T(key), y, 110, 124)
        self.stats[i] = {key = label, value = value}
    end
    self.panelHistory = K.Label(panel, ns.T("buyPanelHistory"), 12, -68 - 5 * 18 - 8, PANEL - 40, "heading")
    self.panelHistory:SetHeight(14)
    self.panelEmpty = K.Label(panel, ns.T("buyPanelEmpty"), 12, -48, PANEL - 40, "secondary")
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
    self.choiceScroll.offset, self.offerScroll.offset = 0, 0
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
    self.choiceScroll.offset, self.offerScroll.offset = 0, 0
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
    if S.pages and not S.catalog then
        self.pageCount:SetText(ns.T("searchPage", (S.page or 0) + 1, S.pages))
        self.pageCount:Show(); self.prevPage:Show(); self.nextPage:Show()
        if busy or (S.page or 0) <= 0 then self.prevPage:Disable() else self.prevPage:Enable() end
        if busy or (S.page or 0) + 1 >= S.pages then self.nextPage:Disable() else self.nextPage:Enable() end
    else self.pageCount:Hide(); self.prevPage:Hide(); self.nextPage:Hide() end
    self.catalogEmpty:SetText(S.catalog and #S.items == 0 and ns.T("searchNoCatalogItems") or "")
    self.panelNow:SetText(ns.T(S.pages and "searchCurrentPage" or "buyPanelNow"))
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
    self.nextPage = K.Button(frame, ">", 24, function() ns.Shopping.Page(1) end, "quiet")
    self.nextPage:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PANEL - 16, -34)
    self.pageCount = K.Label(frame, "", 0, 0, 82, "secondary")
    self.pageCount:SetHeight(14); self.pageCount:SetJustifyH("CENTER")
    self.pageCount:ClearAllPoints(); self.pageCount:SetPoint("RIGHT", self.nextPage, "LEFT", -4, 0)
    self.prevPage = K.Button(frame, "<", 24, function() ns.Shopping.Page(-1) end, "quiet")
    self.prevPage:SetPoint("RIGHT", self.pageCount, "LEFT", -4, 0)
    K.Tooltip(self.prevPage, ns.T("searchPrevPage"), ns.T("searchPageTip"))
    K.Tooltip(self.nextPage, ns.T("searchNextPage"), ns.T("searchPageTip"))
    self.catalogEmpty = K.Label(frame, "", 10, -88, LEFT - 24, "secondary")
    self.catalogEmpty:SetHeight(60)
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
    for i = 1, 3 do
        local option = K.Button(frame, "", 550, function() ns.Shopping.Option(i) end, "quiet")
        option:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT + 10, -56 - SEARCH_ROW - (i - 1) * 25)
        option.text:SetJustifyH("LEFT")
        K.Tooltip(option, ns.T("buyOptTitle"), ns.T("buyOptTip"))
        self.options[i] = option
    end
    self.limitLabel = K.Label(frame, ns.T("buyPriceLimit"), LEFT + 10, -139, 90, "secondary")
    self.limitLabel:SetHeight(12)
    self.limit = K.MoneyEdit(frame, function(copper)
        self.pendingNeed = nil
        ns.Shopping.SetPriceLimit(copper)
    end)
    self.limit.frame:SetPoint("LEFT", self.limitLabel, "RIGHT", 4, 0)
    for _, edit in ipairs(self.limit.edits) do K.Tooltip(edit, ns.T("buyPriceLimit"), ns.T("buyPriceLimitTip")) end
    self.lastLimit = K.Button(frame, ns.T("buyLastLimit"), 120, function()
        local unit = ns.Shopping.LastUnit(ns.Shopping.state.itemID)
        if not unit then return end
        self.pendingNeed = nil
        self.limit:ClearFocus()
        ns.Shopping.SetPriceLimit(unit)
    end, "quiet")
    K.FitButton(self.lastLimit, 16)
    self.lastLimit:SetPoint("LEFT", self.limit.frame, "RIGHT", 6, 0)
    self.lastLimit:Hide()
    K.Tooltip(self.lastLimit, ns.T("buyLastLimit"), "")
    self.lastLimit.tipFn = function()
        local entry = ns.Shopping.Entry(ns.Shopping.state.itemID or 0)
        local last = entry and entry.last
        if not last or (last.units or 0) <= 0 then return "" end
        return ns.T("buyLastLimitTip", last.units, K.Money(math.floor(last.spent / last.units)),
            K.Ago(math.max(0, time() - (last.at or 0))))
    end
    self.offerHead = ns.NewFrame("Frame", nil, frame)
    self.offerHead:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT + 10, -160)
    self.offerHead:SetHeight(20); self.offerHead:SetWidth(550)
    K.HeaderBand(self.offerHead)
    self.columns = {}
    for _, entry in ipairs({{"plan", "buyColPlan"}, {"stack", "buyColStack"}, {"unit", "buyColUnit"}, {"lot", "buyColLot"}}) do
        local label = K.Label(self.offerHead, ns.T(entry[2]), 0, -4, 100, "secondary")
        label:SetHeight(12)
        if entry[1] ~= "plan" then label:SetJustifyH("RIGHT") end
        self.columns[entry[1]] = label
    end
    self.tableHint = K.Label(frame, ns.T("buyEmptyTable"), 0, 0, 400, "secondary")
    self.tableHint:SetHeight(48); self.tableHint:SetJustifyH("CENTER"); self.tableHint:SetJustifyV("TOP")
    self.tableHint:ClearAllPoints(); self.tableHint:SetPoint("TOPLEFT", self.offerHead, "BOTTOMLEFT", 12, -28)
    self.offerScroll = K.Scroller:New(frame, function() self:Render() end, 22)
    self.offerScroll.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT + 10, -182)
    self.offerScroll.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8 - PANEL, BOTTOM)
    for i = 1, 40 do
        local row = {cells = {}}
        row.frame = ns.NewFrame("Frame", nil, frame)
        row.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT + 10, -182 - (i - 1) * 22)
        row.frame:SetWidth(550)
        row.frame:SetHeight(22)
        row.stripe = K.Background(row.frame)
        row.stripe:SetVertexColor(unpack(K.theme.row))
        K.MatchMark(row)
        for _, key in ipairs({"plan", "stack", "unit", "lot"}) do
            local cell = K.Label(row.frame, "", 0, -5, 100)
            cell:SetHeight(12)
            if key ~= "plan" then cell:SetJustifyH("RIGHT") end
            row.cells[key] = cell
        end
        row.minus = K.Button(row.frame, "-", 22, function() ns.Shopping.Adjust(row.offer, -1) end, "quiet")
        row.minus:SetHeight(20)
        row.minus:SetPoint("LEFT", row.frame, "LEFT", 8, 0)
        K.Tooltip(row.minus, ns.T("buyLotMinus"), ns.T("buyLotStepTip"))
        row.plus = K.Button(row.frame, "+", 22, function() ns.Shopping.Adjust(row.offer, 1) end, "quiet")
        row.plus:SetHeight(20)
        row.plus:SetPoint("RIGHT", row.frame, "RIGHT", -4, 0)
        K.Tooltip(row.plus, ns.T("buyLotPlus"), ns.T("buyLotStepTip"))
        self.rows[i] = row
        self.offerScroll:Wheel(row.frame)
    end
end
function UI:New(parent)
    if self.frame then return self end
    local K = ns.TradeKit
    local frame = ns.NewFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    self.frame = frame
    self:NewSearch(frame)
    self.resultsLabel = K.Label(frame, ns.T("buyResults"), 10, -37 - SEARCH_ROW, LEFT - 20, "heading")
    self.resultsLabel:SetHeight(14)
    self.choiceScroll = K.Scroller:New(frame, function() self:Render() end, 28)
    self.choiceScroll.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -54 - SEARCH_ROW)
    self.choiceScroll.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", LEFT, 36)
    for i = 1, 40 do
        local choice = K.ItemChoice(frame, function(_, button) self:PickChoice(i, button) end)
        choice:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        choice:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -54 - SEARCH_ROW - (i - 1) * 28)
        choice:SetWidth(LEFT - 18); choice.text:SetWidth(LEFT - 52)
        choice.need = K.Label(choice, "", 0, 0, 52, "secondary")
        choice.need:SetHeight(12); choice.need:SetJustifyH("RIGHT")
        choice.need:ClearAllPoints(); choice.need:SetPoint("RIGHT", choice, "RIGHT", -6, 0)
        choice.detail = K.Label(choice, "", 28, -22, LEFT - 52, "secondary")
        choice.detail:SetHeight(12)
        choice.head = K.Label(frame, ns.T("buyRecent"), 0, 0, LEFT - 20, "heading")
        choice.head:SetHeight(14)
        choice.head:ClearAllPoints(); choice.head:SetPoint("BOTTOMLEFT", choice, "BOTTOMLEFT", 4, 4)
        choice.head:Hide()
        self.choiceScroll:Wheel(choice)
        self.choices[i] = choice
    end
    local divider = K.Rule(frame, 0)
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT, -34 - SEARCH_ROW); divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", LEFT, 36)
    divider:SetWidth(1); divider:SetHeight(0)
    self:NewPlan(frame)
    self:NewPanel(frame)
    local foot = K.Rule(frame, 0)
    foot:ClearAllPoints()
    foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 36); foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 36)
    self.summary = K.Label(frame, "", 10, 0, 400)
    self.summary:SetHeight(12)
    self.summary:ClearAllPoints(); self.summary:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 11)
    self.go = K.Button(frame, "", 300, function()
        self.limit:Flush(); self.limit:ClearFocus()
        ns.Shopping.Go()
    end, "main")
    self.go:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 4)
    K.Tooltip(self.go, ns.T("buySection"), ns.T("buyGoTip"))
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
