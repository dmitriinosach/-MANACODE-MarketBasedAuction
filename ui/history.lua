local _, ns = ...
local P = {rows = {}, sellers = {}}
ns.OfferPreview = P
P.WIDTH = 560
function P.Open(id)
    if P.id ~= id then
        P.level, P.scanID = nil, nil
        P.scroll.offset = 0; P.sellerScroll.offset = 0
    end
    P.id = id; P.frame:Show(); P:Render()
end
function P:Render()
    if not self.id then return end
    local K, selected = ns.TradeKit
    self.sources = ns.Markets.Sources(self.id)
    self.scanID = self.sources[1] and self.sources[1].id
    local depth = ns.Markets.Depth(self.id, self.scanID)
    self.depth = depth
    local shared = #self.sources == 0 and depth.quote and depth.quote.shared
    local at = depth.quote and depth.quote.at and date("%d.%m %H:%M", depth.quote.at) or ""
    K.SetItemChoice(self.item, self.id, false)
    for _, level in ipairs(depth.levels) do if level.price == self.level then selected = level end end
    if not selected then selected = depth.levels[1]; self.level = selected and selected.price end
    local offset = self.scroll:SetRange(#depth.levels, #self.rows)
    for i, row in ipairs(self.rows) do
        local level = depth.levels[offset + i]
        if level then
            row.level = level.price
            row.text:SetText(K.Money(level.price)); row.units:SetText(tostring(level.units))
            row.lots:SetText(tostring(level.lots)); row.total:SetText(tostring(level.cumulative))
            K.SetSelected(row, level.price == self.level)
            row:Show()
        else row:Hide() end
    end
    local sellers = selected and selected.sellers or {}
    local sellerOffset = self.sellerScroll:SetRange(#sellers, #self.sellers)
    for i, row in ipairs(self.sellers) do
        local seller = sellers[sellerOffset + i]
        if seller then
            row.text:SetText(seller.owner ~= "" and seller.owner or ns.T("cacheUnknownSeller"))
            row.amount:SetText(ns.T("offersStack", seller.stack, seller.lots)); row:Show()
        else row:Hide() end
    end
    self.sellerTitle:SetText(selected and ns.T("offersSellersAt", K.Money(selected.price), selected.sellerCount)
        or ns.T("offersSellers"))
    local q, low = depth.quote, depth.levels[1]
    if shared then self.summary:SetText(ns.T("offersSharedEmpty", at, q.lots or 0))
    elseif low then
        local total = q and q.lots or depth.lots
        self.summary:SetText(ns.T("offersSummary", low.units, low.lots, q and q.units or depth.units, at)
            .. (depth.lots < total and "  " .. ns.T("offersPartial", depth.lots, total) or ""))
    else self.summary:SetText(ns.T(depth.lost and "offersLost" or "offersEmpty")) end
    local need = selected and selected.cumulative or 0
    self.buy:SetText(need > 0 and ns.T("offersBuy", need) or ns.T("obtainBuy")); K.FitButton(self.buy, 24)
    local busy = ns.Scan.state.phase ~= "idle" or ns.Buy.Active()
    if busy then self.refresh:Disable() else self.refresh:Enable() end
    K.DisabledTip(self.buy, ns.T("obtainBuyTitle"), busy and ns.T("batchBusy") or nil)
    if busy then self.buy:Disable() else self.buy:Enable() end
end
function P.New(parent)
    local K = ns.TradeKit
    local f = ns.NewFrame("Frame", nil, parent)
    P.frame = f; f:SetWidth(P.WIDTH); f:SetHeight(420)
    f:SetPoint("CENTER", parent, "CENTER", 0, 0)
    f:SetFrameLevel(parent:GetFrameLevel() + 45); f:SetClampedToScreen(true); f:EnableMouse(true); K.Panel(f)
    P.item = K.ItemChoice(f, function() f:Hide(); K.Inspector.Switch("market", P.id) end)
    P.item:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -8); P.item:SetWidth(470); P.item.text:SetWidth(438)
    local close = K.Button(f, ns.T("historyClose"), 84, function() f:Hide() end, "quiet")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -10)
    P.summary = K.Label(f, "", 12, -44, P.WIDTH - 24, "secondary"); P.summary:SetHeight(28); P.summary:SetJustifyV("TOP")
    K.Rule(f, -82)
    for _, entry in ipairs({{"tradeUnitPrice", 12, 110}, {"tradeUnits", 130, 50},
        {"offersLots", 184, 50}, {"offersCumulative", 238, 72}}) do
        K.Label(f, ns.T(entry[1]), entry[2], -92, entry[3])
    end
    P.sellerTitle = K.Label(f, "", 338, -90, P.WIDTH - 350); P.sellerTitle:SetHeight(28)
    P.scroll = K.Scroller:New(f, function() P:Render() end, 24)
    P.scroll.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -120)
    P.scroll.frame:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", 328, -360)
    P.sellerScroll = K.Scroller:New(f, function() P:Render() end, 24)
    P.sellerScroll.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 338, -120)
    P.sellerScroll.frame:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -10, -360)
    for i = 1, 10 do
        local row = K.Navigation(f, "", function(button)
            P.level = button.level; P.sellerScroll.offset = 0; P:Render()
        end)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -120 - (i - 1) * 24)
        row:SetWidth(298); row:SetHeight(24); row.text:SetWidth(112)
        row.units = K.Label(row, "", 118, -7, 48)
        row.lots = K.Label(row, "", 172, -7, 48)
        row.total = K.Label(row, "", 226, -7, 68)
        P.rows[i] = row; P.scroll:Wheel(row)
        local seller = K.Navigation(f, "", function() end)
        seller:SetPoint("TOPLEFT", f, "TOPLEFT", 338, -120 - (i - 1) * 24)
        seller:SetWidth(P.WIDTH - 350); seller:SetHeight(24); seller.text:SetWidth(P.WIDTH - 450)
        seller.amount = K.Label(seller, "", P.WIDTH - 446, -7, 90)
        P.sellers[i] = seller; P.sellerScroll:Wheel(seller)
    end
    P.refresh = K.Button(f, ns.T("tradeUpdate"), 100, function()
        ns.Markets.Scan(P.id); P:Render()
    end)
    P.refresh:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 8)
    K.Tooltip(P.refresh, ns.T("cacheRefreshItem"), ns.T("cacheRefreshTip"))
    P.buy = K.Button(f, ns.T("obtainBuy"), 116, function()
        local level
        for _, l in ipairs(P.depth and P.depth.levels or {}) do if l.price == P.level then level = l end end
        f:Hide()
        if ns.BuyModal then ns.BuyModal.Open({{id = P.id, need = level and level.cumulative or 1}}) end
    end, "main")
    P.buy:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 8)
    K.Tooltip(P.buy, ns.T("obtainBuyTitle"), ns.T("offersBuyTip"))
    K.Overlay(f)
    f:Hide()
end
