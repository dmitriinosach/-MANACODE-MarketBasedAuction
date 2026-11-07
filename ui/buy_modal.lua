local _, ns = ...
local M = {queue = {}, index = 1}
ns.BuyModal = M
M.WIDTH = 440
M.LIST = 220
M.ROWS = 12
M.ROW = 28
M.PAD = 6
function M.Build()
    if M.dim then return end
    local K = ns.TradeKit
    local host = ns.Trader.frame
    local dim = K.Modal(host, "ManaCodeBuyModal")
    local w = dim.window
    dim.Layout = function()
        w:SetWidth(M.Width())
        w:SetHeight(math.max(340, math.min(460, (host:GetHeight() or 480) - 40)))
    end
    dim:Layout()
    w:ClearAllPoints(); w:SetPoint("TOPLEFT", dim, "TOPLEFT", 20, -20)
    M.dim = dim
    local inset = K.theme.inset
    M.title = K.Label(w, ns.T("buyModalTitle"), inset, -12, 160, "title")
    M.list = K.Card(w)
    M.list:SetPoint("TOPLEFT", w, "TOPLEFT", inset, -38)
    M.list:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", inset, inset)
    M.list:SetWidth(M.LIST)
    local pad, inner = M.PAD, M.LIST - 2 * M.PAD
    M.forLabel = K.Label(M.list, "", pad, -pad, inner, "secondary"); M.forLabel:SetHeight(26); M.forLabel:SetJustifyV("TOP")
    M.rows = {}
    for i = 1, M.ROWS do
        local row = K.ItemChoice(M.list, function() M.Pick(i) end)
        row:SetWidth(inner); row:SetHeight(M.ROW - 2)
        row.text:SetWidth(inner - 28 - 64)
        row.state = K.Label(row, "", 0, 0, 60, "secondary"); row.state:SetHeight(12); row.state:SetJustifyH("RIGHT")
        row.state:ClearAllPoints(); row.state:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row:Hide()
        M.rows[i] = row
    end
    M.more = K.Label(M.list, "", 0, 0, inner, "secondary"); M.more:SetHeight(12)
    M.summaryRule = K.Rule(M.list, 0)
    M.summaryRule:ClearAllPoints()
    M.summaryRule:SetPoint("BOTTOMLEFT", M.list, "BOTTOMLEFT", pad, pad + 32)
    M.summaryRule:SetPoint("BOTTOMRIGHT", M.list, "BOTTOMRIGHT", -pad, pad + 32)
    M.summary = K.Label(M.list, "", 0, 0, inner, "text"); M.summary:SetHeight(14)
    K.BindFont(M.summary, "normal")
    M.summary:ClearAllPoints(); M.summary:SetPoint("BOTTOMLEFT", M.list, "BOTTOMLEFT", pad, pad + 14)
    M.spent = K.Label(M.list, "", 0, 0, inner, "secondary"); M.spent:SetHeight(12)
    M.spent:ClearAllPoints(); M.spent:SetPoint("BOTTOMLEFT", M.list, "BOTTOMLEFT", pad, pad)
    M.module = ns.NewFrame("Frame", nil, w)
    M.module:SetPoint("TOPRIGHT", w, "TOPRIGHT", 0, -36)
    M.module:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", 0, 0)
    M.module:SetWidth(M.WIDTH)
    local m, width = M.module, M.WIDTH - 2 * inset
    M.item = K.ItemChoice(m, nil)
    M.item:SetWidth(width); M.item:SetHeight(26)
    M.item:SetPoint("TOPLEFT", m, "TOPLEFT", inset, 0)
    M.needLabel = K.Label(m, ns.T("buyModalNeed"), inset, -37, 90, "secondary"); M.needLabel:SetHeight(12)
    M.needLabel:SetWidth(math.ceil(M.needLabel.GetStringWidth and M.needLabel:GetStringWidth() or 80) + 2)
    M.need = K.Edit(m, 60)
    M.need:SetNumeric(true); M.need:SetMaxLetters(5)
    M.need:SetPoint("LEFT", M.needLabel, "RIGHT", 8, 0)
    K.Tooltip(M.need, ns.T("buyModalNeed"), ns.T("buyModalNeedTip"))
    K.LiveEdit(M.need, function(edit)
        local value = tonumber(edit:GetText())
        local entry = M.queue[M.index]
        if value and value >= 1 and entry then
            local was = entry.need
            entry.need = math.min(ns.Plan.MAX_UNITS, value)
            entry.done = nil
            if was == 0 then M.Search() else ns.Shopping.SetNeed(entry.need) end
        end
    end)
    M.purchase = K.PurchasePanel:New(m, {refresh = function() M.Search(true) end})
    M.purchase:Place({x = inset, top = 62, width = width, left = inset - 4, right = inset - 4, bottom = inset + 22 + 24})
    M.status = K.Label(m, "", 0, 0, width, "secondary"); M.status:SetHeight(14)
    M.status:ClearAllPoints(); M.status:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", inset, inset + 26)
    M.go = K.BuyButton(m, function() M.Go() end, width)
    M.go:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", inset, inset)
    dim:HookScript("OnShow", function() M.Render() end)
end
function M.Width()
    return M.WIDTH + (M.Listed() and M.LIST + ns.TradeKit.theme.inset or 0)
end
function M.Listed()
    return #M.queue > 1 or M.product ~= nil
end
function M.ListTop()
    return M.PAD + (M.product and 30 or 0)
end
function M.Open(queue, product)
    local list, first, wanted = {}, nil, 0
    for _, entry in ipairs(queue or {}) do
        if entry.id and entry.vendor then
            list[#list + 1] = {id = entry.id, need = 0, vendor = true}
            wanted = wanted + 1
        elseif entry.id and entry.total and (entry.need or 0) <= 0 then
            list[#list + 1] = {id = entry.id, need = 0, total = entry.total, own = entry.own or entry.total, owned = true}
        elseif entry.id and not ns.vendorPrices[entry.id] then
            list[#list + 1] = {id = entry.id, need = math.max(1, math.min(ns.Plan.MAX_UNITS, math.floor(entry.need or 1))),
                total = entry.total, own = entry.own}
            first, wanted = first or #list, wanted + 1
        end
    end
    if wanted == 0 or not ns.Trader.frame then return false end
    M.Build()
    M.queue, M.index, M.product = list, first or 1, product
    M.dim:Layout()
    M.dim:Show()
    M.Search()
    return true
end
function M.Pick(i)
    if not M.queue[i] or M.queue[i].owned or ns.Buy.Active() then return end
    M.index = i
    M.Search()
end
function M.Go()
    local entry = M.queue[M.index]
    if entry and not M.searching and ns.Shopping.state.itemID ~= entry.id then M.Search(); return end
    ns.Shopping.Go()
end
function M.Search(force)
    local entry = M.queue[M.index]
    if not entry then return end
    if entry.need == 0 then M.searching = false; M.Render(); return end
    M.searching = ns.Shopping.Search(ns.Markets.Name(entry.id), entry.id, nil, nil, nil, force)
    if M.searching then ns.Shopping.SetNeed(entry.need) end
    M.Render()
end
function M.Advance()
    local S = ns.Shopping.state
    local entry = M.queue[M.index]
    if not entry or entry.done or S.itemID ~= entry.id or ns.Buy.Active() then return false end
    local got = ns.Shopping.Got()
    if got <= 0 or ns.Shopping.Left() > 0 then return false end
    entry.done, entry.got, entry.spent = true, got, ns.Shopping.Spent()
    for step = 1, #M.queue - 1 do
        local i = (M.index - 1 + step) % #M.queue + 1
        local other = M.queue[i]
        if not other.done and not other.vendor and not other.owned then
            M.index, M.searching = i, nil
            return true
        end
    end
    return false
end
function M.RenderList()
    local K = ns.TradeKit
    local listed = M.Listed()
    if listed then M.list:Show() else M.list:Hide(); return end
    local top = M.ListTop()
    if M.product then
        M.forLabel:SetText(ns.T("buyModalFor", ns.Markets.Name(M.product.id), M.product.count or 1)); M.forLabel:Show()
    else M.forLabel:SetText(""); M.forLabel:Hide() end
    local room = math.max(1, math.floor(((M.dim.window:GetHeight() or 400) - 38 - 60 - top) / M.ROW))
    local shown = math.min(#M.queue, M.ROWS, room)
    local got, total, spent = 0, 0, 0
    for i, row in ipairs(M.rows) do
        local entry = i <= shown and M.queue[i]
        if entry then
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", M.list, "TOPLEFT", M.PAD, -top - (i - 1) * M.ROW)
            K.SetItemChoice(row, entry.id, i == M.index)
            local state, tone = tostring(entry.need), "secondary"
            if entry.total then
                local have = math.min(entry.total, (entry.own or 0) + (entry.done and (entry.got or entry.need) or 0))
                state, tone = ns.T("buyModalHave", have, entry.total), have >= entry.total and "positive" or "secondary"
            elseif entry.done then state, tone = ns.T("buyModalBought", entry.got or entry.need), "positive"
            elseif entry.vendor then state = ns.T("batchWayVendor") end
            row.state:SetText(state); row.state:SetTextColor(unpack(K.theme[tone]))
            row:Show()
        else row:Hide() end
    end
    for _, entry in ipairs(M.queue) do
        if not entry.vendor and not entry.owned then
            total = total + 1
            if entry.done then got = got + 1; spent = spent + (entry.spent or 0) end
        end
    end
    M.more:ClearAllPoints(); M.more:SetPoint("TOPLEFT", M.list, "TOPLEFT", M.PAD + 4, -top - shown * M.ROW - 2)
    M.more:SetText(#M.queue > shown and ns.T("batchMoreItems", #M.queue - shown) or "")
    M.summary:SetText(ns.T("buyModalSummary", got, total))
    M.spent:SetText(ns.T("buyModalSpent", K.Money(spent)))
end
function M.Render()
    if not M.dim or not M.dim:IsShown() then return end
    if M.Advance() then return M.Render() end
    local K, S, R = ns.TradeKit, ns.Shopping.state, ns.Buy.state
    local entry = M.queue[M.index]
    if not entry then M.dim:Hide(); return end
    M.RenderList()
    for _, row in ipairs(M.rows) do if ns.Buy.Active() then row:Disable() else row:Enable() end end
    K.SetItemChoice(M.item, entry.id, false)
    if not M.need:HasFocus() then M.need:SetText(tostring(entry.need)) end
    local mine = S.itemID == entry.id
    local offers = mine and S.offers or {}
    local active = ns.Buy.Active()
    M.purchase:Render({active = active, none = not mine or entry.done,
        empty = mine and (S.pendingID and "buyLotsPending" or "buyNoLots") or "buyModalNext"})
    local state = {title = ns.T("buyModalTitle"), tip = ns.T("buyGoTip")}
    if entry.need == 0 then
        M.status:SetText(ns.T("buyModalVendor"))
        state.reason = ns.T("buyModalVendor")
    elseif entry.done then
        M.status:SetText(ns.T("buyProgress", entry.got or 0, entry.need, K.Money(entry.spent or 0)))
        state.reason = ns.T("buyGoReachedTip")
    elseif not M.searching and not mine then
        M.status:SetText(M.searching == false and ns.T("buyModalClosed") or ns.T("buyModalNext"))
        state.reason = ns.Scan.state.phase ~= "idle" and ns.T("batchBusy") or nil
    elseif not mine then
        M.status:SetText(ns.T("buyModalSearching"))
        state.reason = ns.T("buyModalSearching")
    else
        if ns.Shopping.Got() > 0 then
            M.status:SetText(ns.T("buyProgress", ns.Shopping.Got(), S.need, K.Money(ns.Shopping.Spent())))
        elseif S.plan then M.status:SetText(ns.T("buyTotal", S.plan.units, K.Money(S.plan.cost)))
        elseif #offers == 0 then M.status:SetText(S.pendingID and ns.T("buyModalSearching") or ns.T("buyModalNoOffers"))
        else M.status:SetText(ns.T("buyAvailable", ns.Plan.Available(offers))) end
        if active then
            state.confirm = R.phase == "ready"
            state.searching = not state.confirm
        elseif ns.Shopping.Left() == 0 then state.reason = ns.T("buyGoReachedTip")
        elseif S.plan then state.reason = ns.Scan.state.phase ~= "idle" and ns.T("batchBusy") or nil
        else state.reason = ns.T("buyGoEmptyTip") end
    end
    M.go:SetState(state)
end
local shoppingChanged = ns.Shopping.onChange
ns.Shopping.onChange = function()
    if shoppingChanged then shoppingChanged() end
    M.Render()
end
