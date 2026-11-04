local _, ns = ...
local M = {queue = {}, index = 1}
ns.BuyModal = M
M.LINES = 8
M.WIDTH = 340
function M.Build()
    if M.dim then return end
    local K = ns.TradeKit
    local host = ns.Trader.frame
    local dim = K.Modal(host, "ManaCodeBuyModal")
    local w = dim.window
    dim.Layout = function()
        w:SetWidth(M.WIDTH)
        w:SetHeight(math.max(300, math.min(420, (host:GetHeight() or 480) - 40)))
    end
    dim:Layout()
    w:ClearAllPoints(); w:SetPoint("TOPLEFT", dim, "TOPLEFT", 20, -20)
    M.dim = dim
    M.title = K.Label(w, ns.T("buyModalTitle"), 12, -12, 160, "title")
    M.next = K.Button(w, ">", 22, function() M.Step(1) end, "quiet")
    M.next:SetPoint("TOPRIGHT", w, "TOPRIGHT", -36, -8)
    K.Tooltip(M.next, ns.T("buyModalNext"), ns.T("buyModalStepTip"))
    M.prev = K.Button(w, "<", 22, function() M.Step(-1) end, "quiet")
    M.prev:SetPoint("RIGHT", M.next, "LEFT", -4, 0)
    K.Tooltip(M.prev, ns.T("buyModalPrev"), ns.T("buyModalStepTip"))
    M.count = K.Label(w, "", 0, 0, 60, "secondary"); M.count:SetHeight(12); M.count:SetJustifyH("RIGHT")
    M.count:ClearAllPoints(); M.count:SetPoint("RIGHT", M.prev, "LEFT", -6, 0)
    M.item = K.ItemChoice(w, nil)
    M.item:SetWidth(M.WIDTH - 24); M.item:SetHeight(26)
    M.item:SetPoint("TOPLEFT", w, "TOPLEFT", 12, -36)
    M.needLabel = K.Label(w, ns.T("buyModalNeed"), 12, -73, 90, "secondary"); M.needLabel:SetHeight(12)
    M.need = K.Edit(w, 60)
    M.need:SetNumeric(true); M.need:SetMaxLetters(5)
    M.need:SetPoint("TOPLEFT", w, "TOPLEFT", 104, -68)
    K.Tooltip(M.need, ns.T("buyModalNeed"), ns.T("buyModalNeedTip"))
    K.LiveEdit(M.need, function(edit)
        local value = tonumber(edit:GetText())
        local entry = M.queue[M.index]
        if value and value >= 1 and entry then entry.need = math.min(ns.Plan.MAX_UNITS, value); ns.Shopping.SetNeed(entry.need) end
    end)
    M.search = K.Button(w, ns.T("buyModalSearch"), 80, function() M.Search() end, "quiet")
    M.search:SetHeight(22); K.FitButton(M.search, 24)
    M.search:SetPoint("TOPRIGHT", w, "TOPRIGHT", -12, -68)
    K.Tooltip(M.search, ns.T("buyModalSearch"), ns.T("buyModalSearchTip"))
    M.status = K.Label(w, "", 12, -100, M.WIDTH - 24, "secondary"); M.status:SetHeight(26); M.status:SetJustifyV("TOP")
    M.lines = {}
    for i = 1, M.LINES do
        local line = {}
        line.left = K.Label(w, "", 12, -132 - (i - 1) * 18, 200); line.left:SetHeight(12)
        line.right = K.Label(w, "", 0, 0, 90, "secondary"); line.right:SetHeight(12); line.right:SetJustifyH("RIGHT")
        line.right:ClearAllPoints(); line.right:SetPoint("TOPRIGHT", w, "TOPRIGHT", -12, -132 - (i - 1) * 18)
        M.lines[i] = line
    end
    M.go = K.Button(w, "", M.WIDTH - 24, function() ns.Shopping.Go() end, "main")
    M.go:SetHeight(22)
    M.go:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 12, 12)
    dim:HookScript("OnShow", function() M.Render() end)
end
function M.Open(queue)
    local list = {}
    for _, entry in ipairs(queue or {}) do
        if entry.id and not ns.vendorPrices[entry.id] then
            list[#list + 1] = {id = entry.id, need = math.max(1, math.min(ns.Plan.MAX_UNITS, math.floor(entry.need or 1)))}
        end
    end
    if #list == 0 or not ns.Trader.frame then return false end
    M.Build()
    M.queue, M.index = list, 1
    M.dim:Show()
    M.Search()
    return true
end
function M.Step(delta)
    if #M.queue < 2 or ns.Buy.Active() then return end
    M.index = (M.index - 1 + delta) % #M.queue + 1
    M.Search()
end
function M.Search()
    local entry = M.queue[M.index]
    if not entry then return end
    M.searching = ns.Shopping.Search(ns.Markets.Name(entry.id), entry.id)
    if M.searching then ns.Shopping.SetNeed(entry.need) end
    M.Render()
end
function M.Render()
    if not M.dim or not M.dim:IsShown() then return end
    local K, S, R = ns.TradeKit, ns.Shopping.state, ns.Buy.state
    local entry = M.queue[M.index]
    if not entry then M.dim:Hide(); return end
    K.SetItemChoice(M.item, entry.id, false)
    M.count:SetText(#M.queue > 1 and ns.T("buyModalQueue", M.index, #M.queue) or "")
    for _, b in ipairs({M.prev, M.next}) do
        if #M.queue > 1 then b:Show() else b:Hide() end
        if ns.Buy.Active() then b:Disable() else b:Enable() end
    end
    if not M.need:HasFocus() then M.need:SetText(tostring(entry.need)) end
    local mine = S.itemID == entry.id
    local offers = mine and S.offers or {}
    for i, line in ipairs(M.lines) do
        local offer = offers[i]
        if offer then
            line.left:SetText(ns.T("buyModalOffer", offer.stack, K.Money(offer.buyout / math.max(1, offer.stack))))
            local picked = S.plan and ns.Plan.LotsOf(S.plan, offer) or 0
            line.right:SetText(ns.T("buyPlanRow", picked, offer.count))
            line.right:SetTextColor(unpack(K.theme[picked > 0 and "text" or "secondary"]))
            line.left:Show(); line.right:Show()
        else line.left:Hide(); line.right:Hide() end
    end
    local active, reason = ns.Buy.Active(), nil
    if not M.searching and not mine then M.status:SetText(ns.T("buyModalClosed"))
    elseif not mine then M.status:SetText(ns.T("buyModalSearching"))
    elseif ns.Shopping.Got() > 0 then
        M.status:SetText(ns.T("buyProgress", ns.Shopping.Got(), S.need, K.Money(ns.Shopping.Spent())))
    elseif S.plan then M.status:SetText(ns.T("buyTotal", S.plan.units, K.Money(S.plan.cost)))
    elseif #offers == 0 then M.status:SetText(ns.T("buyModalNoOffers"))
    else M.status:SetText(ns.T("buyAvailable", ns.Plan.Available(offers))) end
    if active then
        local n, cost = ns.Buy.Offer()
        M.go:SetText(R.phase == "ready" and ns.T("buyConfirm", n, K.Money(cost)) or ns.T("buyFinding", (R.page or 0) + 1))
        if R.phase ~= "ready" then reason = ns.T("buyFindingTip") end
    elseif mine and ns.Shopping.Left() == 0 then
        M.go:SetText(ns.T("buyGoReached")); reason = ns.T("buyGoReachedTip")
    elseif mine and S.plan then
        M.go:SetText(ns.T("buyGo", S.plan.units, K.Money(S.plan.cost)))
        if ns.Scan.state.phase ~= "idle" then reason = ns.T("batchBusy") end
    else M.go:SetText(ns.T("buyGoEmpty")); reason = ns.T("buyGoEmptyTip") end
    K.DisabledTip(M.go, ns.T("buyModalTitle"), reason)
    if reason then M.go:Disable() else M.go:Enable() end
end
local shoppingChanged = ns.Shopping.onChange
ns.Shopping.onChange = function()
    if shoppingChanged then shoppingChanged() end
    M.Render()
end
