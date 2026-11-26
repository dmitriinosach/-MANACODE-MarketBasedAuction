local _, ns = ...
local W = {lists = {}}
ns.AuctionWindow = W
local MIN_WIDTH, MIN_HEIGHT, TAB_SPACE = 832, 447, 27
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.70, 1.30, 0.05
W.DEFAULT_WIDTH, W.DEFAULT_HEIGHT = 1120, 630
W.KEEP_WIDTH, W.KEEP_HEIGHT = 120, 40
W.GRAB = 33
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
local function clampScale(value)
    if type(value) ~= "number" or value ~= value then return 1 end
    return math.max(SCALE_MIN, math.min(SCALE_MAX, math.floor(value * 100 + 0.5) / 100))
end
function W.Scale()
    local db = ns.Store.DB()
    local view = type(db.view) == "table" and db.view
    return clampScale(type(view) == "table" and view.scale), SCALE_MIN, SCALE_MAX, SCALE_STEP
end
local function screenSize()
    return UIParent and UIParent:GetWidth() or 1920, UIParent and UIParent:GetHeight() or 1080
end
local function applyScale(screenWidth, screenHeight)
    local frame = W.frame
    local old = frame:GetScale() or 1
    local screenScale = UIParent and UIParent:GetEffectiveScale() or 1
    local oldRatio = (frame:GetEffectiveScale() or screenScale) / screenScale
    local left, top = frame:GetLeft(), frame:GetTop()
    local base = oldRatio / old
    local fits = math.min(screenWidth / (MIN_WIDTH * base), screenHeight / ((MIN_HEIGHT + TAB_SPACE) * base))
    W.scaleLimit = math.min(SCALE_MAX, math.max(SCALE_MIN, math.floor(fits * 100) / 100))
    local scale = math.min(W.Scale(), W.scaleLimit)
    if old ~= scale then frame:SetScale(scale) end
    return scale * base, left and left * oldRatio, top and top * oldRatio
end
function W.Position()
    local saved = ns.Store.DB().auctionWindow
    if type(saved) == "table" and type(saved.x) == "number" and type(saved.y) == "number" then return saved end
    return nil
end
function W.Clamp(x, y, width, screenWidth, screenHeight)
    return math.max(W.KEEP_WIDTH - width, math.min(x, screenWidth - W.KEEP_WIDTH)),
        math.max(W.KEEP_HEIGHT, math.min(y, screenHeight))
end
local function fitPosition(left, top, ratio, screenWidth, screenHeight)
    if not UIParent or W.moving then return end
    local frame = W.frame
    local saved = W.Position()
    local x, y
    if saved then
        x, y = W.Clamp(saved.x, saved.y, frame:GetWidth() * ratio, screenWidth, screenHeight)
    elseif left and top then
        x = math.max(0, math.min(left, screenWidth - frame:GetWidth() * ratio))
        local block = (frame:GetHeight() + TAB_SPACE) * ratio
        y = top >= block and math.min(screenHeight, top) or math.min(screenHeight, (screenHeight + block) / 2)
    else return end
    local nowLeft, nowTop = frame:GetLeft(), frame:GetTop()
    if nowLeft and nowTop and math.abs(x - nowLeft * ratio) < 0.1 and math.abs(y - nowTop * ratio) < 0.1 then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / ratio, y / ratio)
end
function W.Apply()
    W.driver:SetScript("OnUpdate", nil)
    local screenWidth, screenHeight = screenSize()
    local ratio, left, top = applyScale(screenWidth, screenHeight)
    local maxWidth = math.max(MIN_WIDTH, math.min(1600, math.floor(screenWidth / ratio)))
    local maxHeight = math.max(MIN_HEIGHT, math.min(1100, math.floor(screenHeight / ratio - TAB_SPACE)))
    W.maxWidth, W.maxHeight = maxWidth, maxHeight
    W.limits[3], W.limits[4] = maxWidth, maxHeight
    local saved = ns.Store.DB().auctionWindow or {width = W.DEFAULT_WIDTH, height = W.DEFAULT_HEIGHT}
    W.native = foreign()
    local width = W.native and MIN_WIDTH or math.max(MIN_WIDTH, math.min(saved.width, maxWidth))
    local height = W.native and MIN_HEIGHT or math.max(MIN_HEIGHT, math.min(saved.height, maxHeight))
    if W.native then W.grip:Hide() else W.grip:Show() end
    W.frame:SetWidth(width); W.frame:SetHeight(height)
    fitPosition(left, top, ratio, screenWidth, screenHeight)
    W.Layout()
end
function W.Queue()
    if W.driver then W.driver:SetScript("OnUpdate", W.Apply) end
end
function W.SetSize(width, height)
    if combat() then ns.say(ns.T("windowCombat"), "bad"); return false end
    local position = W.Position()
    ns.Store.DB().auctionWindow = {width = math.max(832, math.min(width, W.maxWidth)),
        height = math.max(447, math.min(height, W.maxHeight)), x = position and position.x, y = position and position.y}
    W.Apply()
    return true
end
local function ratios()
    local screenScale = UIParent and UIParent:GetEffectiveScale() or 1
    return (W.frame:GetEffectiveScale() or screenScale) / screenScale, screenScale
end
function W.Place()
    if not W.frame or W.moving or not W.frame:IsShown() or not W.Position() then return end
    local screenWidth, screenHeight = screenSize()
    fitPosition(nil, nil, (ratios()), screenWidth, screenHeight)
end
function W.MoveTo(x, y)
    local frame = W.frame
    local ratio = ratios()
    local screenWidth, screenHeight = screenSize()
    x, y = W.Clamp(x, y, frame:GetWidth() * ratio, screenWidth, screenHeight)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / ratio, y / ratio)
    return x, y
end
local function follow()
    local m = W.moving
    if not m then return end
    local _, screenScale = ratios()
    local cx, cy = GetCursorPosition()
    m.x, m.y = W.MoveTo(m.left + cx / screenScale - m.cx, m.top + cy / screenScale - m.cy)
end
function W.StartMove()
    if W.moving or not (W.frame and UIParent and GetCursorPosition) then return false end
    if combat() then ns.say(ns.T("windowCombat"), "bad"); return false end
    local left, top = W.frame:GetLeft(), W.frame:GetTop()
    if not (left and top) then return false end
    local ratio, screenScale = ratios()
    local cx, cy = GetCursorPosition()
    W.moving = {left = left * ratio, top = top * ratio, cx = cx / screenScale, cy = cy / screenScale}
    W.mover:SetScript("OnUpdate", follow)
    return true
end
function W.StopMove()
    local m = W.moving
    if not m then return end
    follow()
    W.moving = nil
    W.mover:SetScript("OnUpdate", nil)
    if not (m.x and m.y) then return end
    local db = ns.Store.DB()
    if type(db.auctionWindow) ~= "table" then
        db.auctionWindow = {width = W.DEFAULT_WIDTH, height = W.DEFAULT_HEIGHT}
    end
    db.auctionWindow.x, db.auctionWindow.y = m.x, m.y
end
function W.SetScale(value)
    if not W.frame or combat() then return false end
    ns.TradeKit.ViewSettings().scale = clampScale(value)
    W.Apply()
    return true
end
function W.Install(frame, root)
    if W.frame then return end
    W.frame, W.dx = frame, 0
    W.art = ns.TradeKit.AuctionArt(frame)
    W.limits = {MIN_WIDTH, MIN_HEIGHT, 1600, 1100}
    for _, config in ipairs(layouts) do installList(config) end
    W.grip = ns.TradeKit.ResizeGrip(frame, W.limits, function()
        if combat() then ns.say(ns.T("windowCombat"), "bad"); return false end
        return not W.native
    end, W.SetSize, function() W.SetSize(W.DEFAULT_WIDTH, W.DEFAULT_HEIGHT) end)
    W.driver = ns.NewFrame("Frame", nil, frame)
    ns.Listen(W.driver, "UI_SCALE_CHANGED")
    ns.Listen(W.driver, "DISPLAY_SIZE_CHANGED")
    W.driver:SetScript("OnEvent", W.Queue)
    frame:HookScript("OnShow", W.Queue)
    hooksecurefunc("AuctionFrameTab_OnClick", W.Queue)
    W.mover = ns.NewFrame("Frame", nil, frame)
    ns.TradeKit.DragHandle(frame, W.GRAB, W.StartMove, W.StopMove)
    if root then ns.TradeKit.DragHandle(root, W.GRAB, W.StartMove, W.StopMove) end
    if type(UpdateUIPanelPositions) == "function" then hooksecurefunc("UpdateUIPanelPositions", W.Place) end
    local panel = _G["Atr_Main_Panel"]
    if panel then panel:HookScript("OnShow", W.Queue); panel:HookScript("OnHide", W.Queue) end
    W.Apply()
end
