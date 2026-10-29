local _, ns = ...
local UI = { page = 1, choices = {}, options = {}, rows = {} }
ns.ShoppingUI = UI
local LEFT = 236
local PANEL = 272
local BOTTOM = 42
local function money(copper)
    return GetCoinTextureString(math.floor(copper))
end
function UI:Render()
    if not self.frame then return end
    local Shop, K = ns.Shopping, ns.TradeKit
    local S, R = Shop.state, ns.Buy.state
    local active = ns.Buy.Active()
    local width = self.frame:GetWidth() or 996
    local right = math.max(300, width - LEFT - 20 - PANEL)
    local entries = self:ChoiceEntries()
    self.resultsLabel:SetText(ns.T((#S.items == 0 and entries[1]) and "buyRecent" or "buyResults"))
    local visibleChoices = K.ListCapacity(self.frame, 54, 36, 28, #self.choices)
    local choiceOffset = self.choiceScroll:SetRange(#entries, visibleChoices)
    self.rowEntries = {}
    for i, b in ipairs(self.choices) do
        local entry = i <= visibleChoices and entries[choiceOffset + i]
        self.rowEntries[i] = entry or nil
        b:SetWidth(LEFT - 18)
        b.head:Hide(); b.need:SetText(""); b.extraTip = nil
        if not entry then b:Hide()
        elseif entry.kind == "head" then b:Hide(); b.head:Show()
        else
            b.text:SetWidth(LEFT - 52 - (entry.kind == "recent" and 54 or 0))
            K.SetItemChoice(b, entry.id, entry.kind == "item" and entry.id == S.itemID)
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
    self.need:SetMaxLetters(S.priceLimit and 8 or 4)
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
    local columns = {plan = {38, 90}, stack = {130, 80}, unit = {inner - 264, 110}, lot = {inner - 144, 110}}
    for key, label in pairs(self.columns) do
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", self.offerHead, "TOPLEFT", columns[key][1], -4)
        label:SetWidth(columns[key][2])
    end
    for i, row in ipairs(self.rows) do
        row.frame:SetWidth(inner)
        local offer = i <= visibleOffers and shown[offerOffset + i]
        if offer then
            row.offer = offer
            for key, cell in pairs(row.cells) do
                cell:ClearAllPoints()
                cell:SetPoint("TOPLEFT", row.frame, "TOPLEFT", columns[key][1], -5)
                cell:SetWidth(columns[key][2])
            end
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
    self.go:Disable()
    if active then
        local n, cost = ns.Buy.Offer()
        self.go:SetText(R.phase == "ready" and ns.T("buyConfirm", n, money(cost)) or ns.T("buyFinding", R.page + 1))
        if R.phase == "ready" then self.go:Enable() end
    elseif Shop.Left() == 0 then
        self.go:SetText(ns.T("buyGoReached"))
    elseif S.plan then
        self.go:SetText(ns.T("buyGo", S.plan.units, money(S.plan.cost)))
        if ns.Scan.state.phase == "idle" then self.go:Enable() end
    else self.go:SetText(ns.T("buyGoEmpty")) end
    K.FitButton(self.go, 40)
    self:RenderPanel()
end
function UI:PlaceTable(options)
    local limitTop = 64 + options * 25
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
        entries[#entries + 1] = {kind = "item", id = item.id}
        found[item.id] = true
    end
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
    self.inspector:Place(-34, 40)
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
function UI:NewSearch(frame)
    local K = ns.TradeKit
    local caption = K.Label(frame, ns.T("buyQueryLabel"), 10, -10, 54, "secondary")
    caption:SetHeight(12)
    self.search = K.Button(frame, ns.T("buySearch"), 80, nil)
    self.search:SetHeight(26); K.FitButton(self.search, 32)
    self.search:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PANEL - 16, -3)
    self.query = K.Edit(frame, 260, true)
    self.query:SetPoint("TOPLEFT", frame, "TOPLEFT", 66, -3)
    self.query:SetPoint("RIGHT", self.search, "LEFT", -6, 0)
    self.query:SetMaxLetters(120)
    local function search()
        self.query:ClearFocus()
        self.choiceScroll.offset, self.offerScroll.offset = 0, 0
        ns.Shopping.Search(self.query:GetText())
    end
    self.query:SetScript("OnEnterPressed", function()
        if self.suggest:Pick() then return end
        search()
    end)
    self.suggest = K.Suggest(self.query, function(text) return ns.Shopping.Suggest(text, 8) end, function(entry)
        self.query:SetText(entry.name); self.query:ClearFocus()
        self.choiceScroll.offset, self.offerScroll.offset = 0, 0
        ns.Shopping.Search(entry.name, entry.id)
    end, 8, ns.T("buySuggestNone"))
    K.Tooltip(self.query, ns.T("buyQueryLabel"), ns.T("buySuggestTip"))
    self.search.onClick = search
end
function UI:NewNeed(frame)
    local K = ns.TradeKit
    local reset = K.Button(frame, ns.T("buyReset"), 64, function() ns.Shopping.Reset() end, "quiet")
    reset:SetPoint("RIGHT", self.go, "LEFT", -16, 0)
    local plus = K.Button(frame, "+", 22, function() ns.Shopping.SetNeed(ns.Shopping.state.need + (IsShiftKeyDown() and 10 or 1)) end, "quiet")
    plus:SetPoint("RIGHT", reset, "LEFT", -10, 0)
    self.need = K.Edit(frame, 48)
    self.need:SetPoint("RIGHT", plus, "LEFT", -4, 0)
    self.need:SetNumeric(true)
    self.need:SetMaxLetters(4)
    self.need:SetScript("OnTextChanged", function(edit, user)
        if user then self.pendingNeed, self.pendingAt = tonumber(edit:GetText()) or 1, GetTime() + 0.3 end
    end)
    self.need:SetScript("OnEnterPressed", function(edit) edit:ClearFocus() end)
    local minus = K.Button(frame, "-", 22, function() ns.Shopping.SetNeed(ns.Shopping.state.need - (IsShiftKeyDown() and 10 or 1)) end, "quiet")
    minus:SetPoint("RIGHT", self.need, "LEFT", -4, 0)
    local needLabel = K.Label(frame, ns.T("buyCapNeed"), 0, 0, 86, "secondary")
    needLabel:SetHeight(12); needLabel:SetJustifyH("RIGHT"); needLabel:ClearAllPoints()
    needLabel:SetPoint("RIGHT", minus, "LEFT", -6, 0)
    return needLabel
end
function UI:NewPlan(frame)
    local K = ns.TradeKit
    self.heading = K.Label(frame, "", LEFT + 10, -37, 500, "heading")
    self.heading:SetHeight(14)
    for i = 1, 3 do
        local option = K.Button(frame, "", 550, function() ns.Shopping.Option(i) end, "quiet")
        option:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT + 10, -56 - (i - 1) * 25)
        option.text:SetJustifyH("LEFT")
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
        row.plus = K.Button(row.frame, "+", 22, function() ns.Shopping.Adjust(row.offer, 1) end, "quiet")
        row.plus:SetHeight(20)
        row.plus:SetPoint("RIGHT", row.frame, "RIGHT", -4, 0)
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
    self.resultsLabel = K.Label(frame, ns.T("buyResults"), 10, -37, LEFT - 20, "heading")
    self.resultsLabel:SetHeight(14)
    self.choiceScroll = K.Scroller:New(frame, function() self:Render() end, 28)
    self.choiceScroll.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -54)
    self.choiceScroll.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", LEFT, 36)
    for i = 1, 40 do
        local choice = K.ItemChoice(frame, function(_, button) self:PickChoice(i, button) end)
        choice:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        choice:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -54 - (i - 1) * 28)
        choice:SetWidth(LEFT - 18); choice.text:SetWidth(LEFT - 52)
        choice.need = K.Label(choice, "", 0, 0, 52, "secondary")
        choice.need:SetHeight(12); choice.need:SetJustifyH("RIGHT")
        choice.need:ClearAllPoints(); choice.need:SetPoint("RIGHT", choice, "RIGHT", -6, 0)
        choice.head = K.Label(frame, ns.T("buyRecent"), 0, 0, LEFT - 20, "heading")
        choice.head:SetHeight(14)
        choice.head:ClearAllPoints(); choice.head:SetPoint("BOTTOMLEFT", choice, "BOTTOMLEFT", 4, 4)
        choice.head:Hide()
        self.choiceScroll:Wheel(choice)
        self.choices[i] = choice
    end
    local divider = K.Rule(frame, 0)
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT, -34); divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", LEFT, 36)
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
