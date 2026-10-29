local _, ns = ...
local W = {lists = {}}
ns.AuctionWindow = W
W.DEFAULT_WIDTH, W.DEFAULT_HEIGHT = 1120, 630
local layouts = {
    {kind = "list", parent = "AuctionFrameBrowse", prefix = "BrowseButton", template = "BrowseButtonTemplate",
        scroll = "BrowseScrollFrame", update = "AuctionFrameBrowse_Update", count = "NUM_BROWSE_TO_DISPLAY",
        original = 8, scrollHeight = 306, sort = "BrowseQualitySort", sortWidth = 214, name = 167,
        widths = {[625] = true, [600] = true, [589] = true, [562] = true}},
    {kind = "bidder", parent = "AuctionFrameBid", prefix = "BidButton", template = "BidButtonTemplate",
        scroll = "BidScrollFrame", update = "AuctionFrameBid_Update", count = "NUM_BIDS_TO_DISPLAY",
        original = 9, scrollHeight = 335, sort = "BidQualitySort", sortWidth = 195, name = 187,
        widths = {[793] = true, [769] = true, [758] = true, [735] = true}},
    {kind = "owner", parent = "AuctionFrameAuctions", prefix = "AuctionsButton", template = "AuctionsButtonTemplate",
        scroll = "AuctionsScrollFrame", update = "AuctionFrameAuctions_Update", count = "NUM_AUCTIONS_TO_DISPLAY",
        original = 9, scrollHeight = 339, sort = "AuctionsQualitySort", sortWidth = 185, name = 142,
        widths = {[599] = true, [576] = true, [565] = true, [543] = true}},
    {kind = "filter", parent = "AuctionFrameBrowse", prefix = "AuctionFilterButton", template = "AuctionClassButtonTemplate",
        scroll = "BrowseFilterScrollFrame", update = "AuctionFrameFilters_Update", count = "NUM_FILTERS_TO_DISPLAY",
        original = 15, scrollHeight = 305, rowHeight = 20, max = 60},
}
local function combat()
    return InCombatLockdown and InCombatLockdown() or false
end
local function region(row, suffix)
    return _G[row:GetName() .. suffix]
end
local function widen(frame, list)
    if not frame then return end
    local width = math.floor(frame:GetWidth() + 0.5)
    if list.widths[width] and W.dx > 0 then frame:SetWidth(width + W.dx) end
end
local function widenRows(list)
    for i = 1, list.visible or list.original do
        local row = list.rows[i]
        if row and row:IsShown() then widen(row, list); widen(region(row, "Highlight"), list) end
    end
end
local function captureFields(row, list)
    local fields = {}
    for _, suffix in ipairs({"Level", "HighBidder", "ClosingTime", "BidStatus"}) do
        local field = region(row, suffix)
        local point, relative, anchor, x, y
        if field then point, relative, anchor, x, y = field:GetPoint(1) end
        if point then fields[#fields + 1] = {frame = field, point = point, relative = relative, anchor = anchor, x = x, y = y} end
    end
    list.fields[row] = fields
end
local function ensureRows(list, count)
    for i = #list.rows + 1, count do
        local row = _G[list.prefix .. i]
        if not row then
            row = ns.NewFrame("Button", list.prefix .. i, list.frame, list.template)
            row:SetID(i)
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", list.rows[i - 1], "BOTTOMLEFT", 0, 0)
            row:Hide()
        end
        list.rows[i] = row
        captureFields(row, list)
    end
end
local function installList(config)
    local parent, scroll = _G[config.parent], _G[config.scroll]
    if not parent or not scroll or not _G[config.prefix .. "1"] or not _G[config.update] then return end
    local list = {}
    for key, value in pairs(config) do list[key] = value end
    list.rows, list.fields, list.frame, list.scroll = {}, {}, parent, scroll
    ensureRows(list, list.original)
    list.track = scroll:CreateTexture(nil, "ARTWORK")
    list.track:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
    list.track:SetTexCoord(0, 0.484375, 0.4, 0.6)
    list.track:SetWidth(31)
    list.track:SetPoint("TOPLEFT", scroll, "TOPRIGHT", -2, 5 - 256)
    list.track:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", -2, -2 + 106)
    list.track:Hide()
    W.lists[#W.lists + 1] = list
    if list.widths then hooksecurefunc(config.update, function() widenRows(list) end) end
end
local function layoutList(list, dx, dy)
    local visible = math.min(list.max or 40, list.original + math.max(0, math.floor(dy / (list.rowHeight or 37))))
    list.visible = visible
    ensureRows(list, visible)
    _G[list.count] = visible
    local height = list.scrollHeight + dy
    list.scroll:SetHeight(height)
    if height + 7 > 256 + 106 then list.track:Show() else list.track:Hide() end
    local sort = _G[list.sort]
    if sort then sort:SetWidth(list.sortWidth + dx) end
    for i, row in ipairs(list.rows) do
        local label = region(row, "Name")
        if label and list.name then label:SetWidth(list.name + dx) end
        for _, field in ipairs(list.fields[row]) do
            field.frame:ClearAllPoints(); field.frame:SetPoint(field.point, field.relative, field.anchor, field.x + dx, field.y)
        end
        if i > visible then row:Hide() end
    end
    if list.frame:IsShown() then _G[list.update]() end
end
function W.Layout()
    if W.layingOut then return end
    W.layingOut = true
    local width, height = W.frame:GetWidth(), W.frame:GetHeight()
    local dx, dy = width - 832, height - 447
    W.dx = dx
    for _, list in ipairs(W.lists) do list.frame:SetWidth(758 + dx); list.frame:SetHeight(447 + dy) end
    ns.TradeKit.LayoutAuctionArt(W.frame, width, height, W.art)
    for _, list in ipairs(W.lists) do layoutList(list, dx, dy) end
    if ns.Trader.frame then ns.Trader.Refresh() end
    W.layingOut = false
end
local function foreign()
    local panel = _G["Atr_Main_Panel"]
    return panel and panel:IsShown() and true or false
end
function W.Apply()
    W.driver:SetScript("OnUpdate", nil)
    local saved = ns.Store.DB().auctionWindow or {width = W.DEFAULT_WIDTH, height = W.DEFAULT_HEIGHT}
    W.native = foreign()
    local width = W.native and 832 or math.max(832, math.min(saved.width, W.maxWidth))
    local height = W.native and 447 or math.max(447, math.min(saved.height, W.maxHeight))
    if W.native then W.grip:Hide() else W.grip:Show() end
    W.frame:SetWidth(width); W.frame:SetHeight(height)
    W.Layout()
end
function W.Queue()
    if W.driver then W.driver:SetScript("OnUpdate", W.Apply) end
end
function W.SetSize(width, height)
    if combat() then ns.say(ns.T("windowCombat")); return false end
    ns.Store.DB().auctionWindow = {width = math.max(832, math.min(width, W.maxWidth)),
        height = math.max(447, math.min(height, W.maxHeight))}
    W.Apply()
    return true
end
function W.Install(frame)
    if W.frame then return end
    W.frame, W.dx = frame, 0
    W.art = ns.TradeKit.AuctionArt(frame)
    W.maxWidth = math.max(832, math.min(1600, (UIParent and UIParent:GetWidth() or 1920) - 35))
    W.maxHeight = math.max(447, math.min(1100, (UIParent and UIParent:GetHeight() or 1080) - 130))
    for _, config in ipairs(layouts) do installList(config) end
    W.grip = ns.TradeKit.ResizeGrip(frame, {832, 447, W.maxWidth, W.maxHeight}, function()
        if combat() then ns.say(ns.T("windowCombat")); return false end
        return not W.native
    end, W.SetSize, function() W.SetSize(W.DEFAULT_WIDTH, W.DEFAULT_HEIGHT) end)
    W.driver = ns.NewFrame("Frame", nil, frame)
    hooksecurefunc("AuctionFrameTab_OnClick", W.Queue)
    local panel = _G["Atr_Main_Panel"]
    if panel then panel:HookScript("OnShow", W.Queue); panel:HookScript("OnHide", W.Queue) end
    W.Apply()
end
