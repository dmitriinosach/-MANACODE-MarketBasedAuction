local _, ns = ...
local A = {}
ns.AuctionPage = A
local function selected(self, index)
    if not A.frame then return end
    local id = type(index) == "number" and index or self:GetID()
    if id ~= A.index then
        if ns.Buy then ns.Buy.Stop() end
        if ns.Batch then ns.Batch.Stop() end
        A.frame:Hide()
        return
    end
    for _, name in ipairs({"AuctionFrameBrowse", "AuctionFrameBid", "AuctionFrameAuctions", "Atr_Main_Panel"}) do
        local frame = _G[name]
        if frame then frame:Hide() end
    end
    A.frame:Show()
    ns.Trader.Open()
end
function A.Install(frame)
    if A.tab then return A.tab end
    local last, count
    for i = 1, 30 do
        local tab = _G["AuctionFrameTab" .. i]
        if tab then last, count = tab, i end
    end
    A.frame, A.index = frame, (count or 3) + 1
    A.tab = ns.NewFrame("Button", "AuctionFrameTab" .. A.index, AuctionFrame, "AuctionTabTemplate")
    A.tab:SetID(A.index)
    A.tab:SetText(ns.T("tradeTab"))
    if last then
        A.tab:SetPoint("LEFT", last, "RIGHT", -8, 0)
    else
        A.tab:SetPoint("TOPLEFT", AuctionFrame, "BOTTOMLEFT", 15, 11)
    end
    PanelTemplates_SetNumTabs(AuctionFrame, A.index)
    PanelTemplates_TabResize(A.tab, 0)
    PanelTemplates_EnableTab(AuctionFrame, A.index)
    hooksecurefunc("AuctionFrameTab_OnClick", selected)
    A.tab:SetScript("OnClick", function(self) AuctionFrameTab_OnClick(self) end)
    return A.tab
end
