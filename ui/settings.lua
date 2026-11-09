local _, ns = ...
local UI = {}
UI.__index = UI
ns.SettingsUI = UI
local WIDTH = 580
local ROW = 13
local function minimapDB()
    local db = ns.Store.DB()
    if type(db.minimap) ~= "table" then db.minimap = {} end
    return db.minimap
end
function UI.MinimapAngle(value)
    if value then minimapDB().angle = value end
    return tonumber(minimapDB().angle) or 200
end
function UI.MinimapShown()
    return minimapDB().hidden ~= true
end
function UI.SetMinimapShown(on)
    minimapDB().hidden = (not on) and true or nil
    if UI.minimap then UI.minimap:Reveal(on) end
    if UI.view then UI.view:Render() end
end
local function textHeight(fs, fallback)
    local height = fs:GetHeight()
    return (height and height > 0) and height or fallback
end
local function heading(parent, text, y)
    return ns.TradeKit.Label(parent, text, 14, y, WIDTH - 28, "title")
end
local function card(parent, y, rows)
    local K = ns.TradeKit
    local frame = K.Card(parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, y)
    frame:SetHeight(rows * ROW + 16)
    return frame
end
function UI:New(parent)
    local K = ns.TradeKit
    local view = setmetatable({}, self)
    local f = ns.NewFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    view.frame = f
    view.guard = ns.NewFrame("Frame", nil, f)
    view.guard:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    view.guard:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    view.guardTitle = K.Label(view.guard, "", 14, -2, WIDTH - 28)
    view.guardCopy = K.Label(view.guard, "", 0, 0, WIDTH - 28, "secondary")
    view.guardCopy:ClearAllPoints(); view.guardCopy:SetPoint("TOPLEFT", view.guardTitle, "BOTTOMLEFT", 0, -6)
    view.guardFile = K.Label(view.guard, ns.T("guardFile"), 0, 0, WIDTH - 28, "secondary")
    view.guardFile:ClearAllPoints(); view.guardFile:SetPoint("TOPLEFT", view.guardCopy, "BOTTOMLEFT", 0, -6)
    view.restore = K.Button(view.guard, ns.T("setRestore"), 150, function() view:Restore() end, "main")
    view.restore:SetPoint("TOPLEFT", view.guardFile, "BOTTOMLEFT", 0, -10)
    K.Tooltip(view.restore, ns.T("setRestore"), ns.T("setRestoreTip"))
    view.forget = K.Button(view.guard, ns.T("setForget"), 150, function() view:Forget() end, "quiet")
    view.forget:SetHeight(26)
    view.forget:SetPoint("LEFT", view.restore, "RIGHT", 8, 0)
    K.Tooltip(view.forget, ns.T("setForget"), ns.T("setForgetTip"))
    view.guardDone = K.Label(view.guard, "", 14, -2, WIDTH - 28)
    view.reload = K.Button(view.guard, ns.T("setReload"), 180, function() ReloadUI() end)
    view.reload:SetHeight(26)
    view.reload:SetPoint("TOPLEFT", view.guardDone, "BOTTOMLEFT", 0, -10)
    K.Tooltip(view.reload, ns.T("setReload"), ns.T("setReloadTip"))
    view.body = ns.NewFrame("Frame", nil, f)
    view.body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    local body = view.body
    heading(body, ns.T("setStorage"), 0)
    local rows = {ns.T("setScans"), ns.T("setRaw"), ns.T("setDays"), ns.T("setKeys"), ns.T("setShared"), ns.T("setCopy")}
    view.storage = card(body, -18, #rows)
    local _, values = K.ValueRows(view.storage, -8, rows, {labelWidth = 150, valueWidth = 300})
    view.storageValues = values
    view.storageNote = K.Label(body, ns.T("setStorageNote"), 14, -18 - #rows * ROW - 22, WIDTH - 28, "secondary")
    local paceY = -18 - #rows * ROW - 60
    heading(body, ns.T("setPace"), paceY)
    view.paceCard = card(body, paceY - 18, 3)
    local _, pace = K.ValueRows(view.paceCard, -8, {ns.T("setGap")}, {labelWidth = 150, valueWidth = 120})
    view.gap = pace[1]
    view.resetPace = K.Button(view.paceCard, ns.T("setResetPace"), 150, function() view:ResetPace() end)
    view.resetPace:SetPoint("BOTTOMLEFT", view.paceCard, "BOTTOMLEFT", K.theme.inset, 6)
    view.resetPace:SetHeight(20)
    K.Tooltip(view.resetPace, ns.T("setResetPace"), ns.T("setResetPaceTip"))
    local factionsY = paceY - 18 - 3 * ROW - 30
    heading(body, ns.T("setFactions"), factionsY)
    view.factions = K.Segment(body, {{key = "separate", label = ns.T("setFactionsSeparate")},
        {key = "shared", label = ns.T("setFactionsShared")}}, function(key) view:SetFactions(key == "shared") end,
        {ns.T("setFactions"), ns.T("setFactionsTip")})
    view.factions.frame:SetPoint("TOPLEFT", body, "TOPLEFT", 14, factionsY - 20)
    local windowsY = factionsY - 52
    heading(body, ns.T("setWindows"), windowsY)
    view.ledger = K.Button(body, ns.T("setLedger"), 110, function() UI.OpenLedger() end)
    view.ledger:SetPoint("TOPLEFT", body, "TOPLEFT", 14, windowsY - 20)
    K.Tooltip(view.ledger, ns.T("setLedger"), ns.T("setLedgerTip"))
    view.mailPanel = ns.CollectUI.ShownCheck(body)
    view.mailPanel:SetPoint("TOPRIGHT", body, "TOPRIGHT", -14, windowsY - 22)
    view.minimapCheck = K.Check(body, UI.SetMinimapShown)
    view.minimapCheck:SetPoint("TOPRIGHT", body, "TOPRIGHT", -14, windowsY - 44)
    view.minimapLabel = K.Label(body, ns.T("setMinimap"), 0, 0, 150, "secondary")
    view.minimapLabel:ClearAllPoints(); view.minimapLabel:SetPoint("RIGHT", view.minimapCheck, "LEFT", -2, 0)
    view.minimapLabel:SetJustifyH("RIGHT")
    K.Tooltip(view.minimapCheck, ns.T("setMinimap"), ns.T("setMinimapTip"))
    local perfY = windowsY - 72
    heading(body, ns.T("setPerf"), perfY)
    view.perf = K.Button(body, "", 150, function() ns.Perf.Toggle(); view:RenderPerf() end)
    view.perf:SetPoint("TOPLEFT", body, "TOPLEFT", 14, perfY - 20)
    K.Tooltip(view.perf, ns.T("setPerf"), ns.T("perfTip", ns.Perf.SECONDS))
    view:RenderPerf()
    view.height = -(perfY - 54)
    return view
end
function UI:RenderPerf()
    local Perf = ns.Perf
    if Perf.active then self.perf:SetText(ns.T("perfRunning", Perf.Left()))
    else self.perf:SetText(ns.T("perfButton", Perf.SECONDS)) end
end
function UI:Height()
    return (self.guardTop or 0) + self.height
end
function UI:RenderGuard()
    local K, G = ns.TradeKit, ns.Guard
    local title, copy = G.Warning()
    local top = 0
    if title then
        self.guardTitle:SetText(K.Colored(title, "negative")); self.guardCopy:SetText(copy)
        for _, region in ipairs({self.guardTitle, self.guardCopy, self.guardFile, self.restore, self.forget}) do region:Show() end
        self.guardDone:Hide(); self.reload:Hide()
        top = 2 + textHeight(self.guardTitle, 26) + 6 + textHeight(self.guardCopy, 52) + 6
            + textHeight(self.guardFile, 52) + 10 + 26 + 14
    elseif G.message then
        for _, region in ipairs({self.guardTitle, self.guardCopy, self.guardFile, self.restore, self.forget}) do region:Hide() end
        self.guardDone:SetText(G.message); self.guardDone:Show()
        if self.restored then self.reload:Show() else self.reload:Hide() end
        top = 2 + textHeight(self.guardDone, 26) + (self.restored and 36 or 0) + 14
    end
    self.guardTop = top
    if top > 0 then self.guard:SetHeight(top); self.guard:Show() else self.guard:Hide() end
    self.body:ClearAllPoints()
    self.body:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -top)
    self.body:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
end
function UI:Render()
    local K, Store = ns.TradeKit, ns.Store
    self:RenderGuard()
    local db, status = Store.DB(), ns.Guard.Status()
    local last = db.scans[#db.scans]
    local values = self.storageValues
    values[1]:SetText(ns.T("setScansValue", #db.scans, last and last.total or 0))
    values[2]:SetText(ns.T("setRawValue", ns.Decimal(status.usage / 1048576, 1), Store.RAW_BYTES / 1048576))
    values[3]:SetText(ns.T("setDaysValue", Store.RAW_DAYS))
    values[4]:SetText(ns.T("setKeysValue", status.exact and "" or "<= ", status.keys, Store.FILE_KEYS, Store.LUA_KEYS))
    if Store.overKeys then values[4]:SetTextColor(unpack(K.theme.negative)) else values[4]:SetTextColor(unpack(K.theme.text)) end
    values[5]:SetText(status.shared and ns.T("setSharedValue", ns.T("guardShared_" .. status.shared), status.sharedPoints,
        ns.Shared.limits.points) or ns.T("guardShared_none"))
    values[6]:SetText(status.copyAt and ns.T("setCopyValue", status.copyAt, status.copyWeight) or ns.T("setCopyNone"))
    local gap = ns.Query.Gap()
    self.gap:SetText(ns.T("setGapValue", ns.Decimal(gap, 1)))
    if gap > ns.Query.gap then self.resetPace:Enable() else self.resetPace:Disable() end
    self.mailPanel:SetChecked(ns.CollectUI.Shown())
    self.minimapCheck:SetChecked(UI.MinimapShown())
    self.factions:Select(ns.Markets.Shared() and "shared" or "separate")
    self:RenderPerf()
    UI.Fit()
end
function UI:SetFactions(shared)
    ns.Markets.SetShared(shared)
    self:Render()
    if ns.Trader and ns.Trader.frame then ns.Trader.Refresh() end
    if ns.MarketWindow then ns.MarketWindow.Refresh() end
end
function UI:Restore()
    self.restored = ns.Guard.Restore()
    self:Render()
    if ns.Trader and ns.Trader.frame then ns.Trader.Refresh() end
    return self.restored
end
function UI:Forget()
    local done = ns.Guard.Forget()
    self.restored = false
    self:Render()
    if ns.Trader and ns.Trader.frame then ns.Trader.Refresh() end
    return done
end
function UI:ResetPace()
    local done = ns.Scan.ResetPace()
    self:Render()
    return done
end
function UI.OpenLedger()
    if not ns.AccountingUI then ns.say(ns.T("tradeRestartRequired"), "bad"); return end
    if UI.window then UI.window:Hide() end
    ns.AccountingUI.Open()
end
local INSET, LINE = 14, 26
local CHAR_NAME, CHAR_SOURCE = 170, 130
UI.TABS = {"storage", "characters"}
local function buildCharacters(page)
    local K = ns.TradeKit
    page.source = K.Label(page, "", INSET, -4, WIDTH - INSET * 2, "secondary")
    page.source:SetHeight(28); page.source:SetJustifyV("TOP")
    page.empty = K.Label(page, ns.T("setCharEmpty"), INSET, -40, WIDTH - INSET * 2, "secondary")
    page.rows = {}
end
local function characterRow(page, i)
    local K = ns.TradeKit
    local row = {}
    row.name = K.Label(page, "", INSET, 0, CHAR_NAME - 6)
    row.source = K.Label(page, "", INSET + CHAR_NAME, 0, CHAR_SOURCE - 6, "secondary")
    row.seen = K.Label(page, "", INSET + CHAR_NAME + CHAR_SOURCE, 0, WIDTH - INSET * 2 - CHAR_NAME - CHAR_SOURCE - 120, "secondary")
    row.forget = K.Button(page, ns.T("setCharForget"), 110, function()
        if not row.armed then row.armed = true; row.forget:SetText(ns.T("setCharConfirm")); return end
        ns.Inventory.Forget(row.charName)
        UI.RenderCharacters()
    end, "quiet")
    row.forget:SetHeight(20)
    K.Tooltip(row.forget, ns.T("setCharForget"), ns.T("setCharForgetTip"))
    page.rows[i] = row
    return row
end
function UI.RenderCharacters()
    local K, page = ns.TradeKit, UI.pages and UI.pages.characters
    if not page then return end
    local I = ns.Inventory
    page.source:SetText(ns.T(I.Source() == "bagnon" and "setCharBagnon" or "setCharOwn"))
    local list, y, now = I.Characters(), -40, time()
    for i, entry in ipairs(list) do
        local row = page.rows[i] or characterRow(page, i)
        row.charName, row.armed = entry.name, nil
        row.name:SetText(entry.current and entry.name .. " " .. K.Colored(ns.T("setCharCurrent"), "secondary") or entry.name)
        local sources = {}
        if entry.bagnon then sources[#sources + 1] = "Bagnon" end
        if entry.own then sources[#sources + 1] = "ManaCode" end
        row.source:SetText(table.concat(sources, ", "))
        local seen = entry.seen and ns.T("setCharSeen", K.Ago(now - entry.seen)) or ns.T("setCharNever")
        row.seen:SetText(I.Stale(entry) and K.Colored(seen, "negative") or seen)
        row.forget:SetText(ns.T("setCharForget"))
        if entry.current then row.forget:Disable() else row.forget:Enable() end
        K.DisabledTip(row.forget, ns.T("setCharForget"), ns.T("setCharCurrentTip"))
        for _, region in ipairs({row.name, row.source, row.seen}) do
            region:ClearAllPoints()
        end
        row.name:SetPoint("TOPLEFT", page, "TOPLEFT", INSET, y - 4)
        row.source:SetPoint("TOPLEFT", page, "TOPLEFT", INSET + CHAR_NAME, y - 4)
        row.seen:SetPoint("TOPLEFT", page, "TOPLEFT", INSET + CHAR_NAME + CHAR_SOURCE, y - 4)
        row.forget:ClearAllPoints(); row.forget:SetPoint("TOPRIGHT", page, "TOPRIGHT", -INSET, y)
        for _, region in ipairs({row.name, row.source, row.seen, row.forget}) do region:Show() end
        y = y - LINE
    end
    for i = #list + 1, #page.rows do
        local row = page.rows[i]
        for _, region in ipairs({row.name, row.source, row.seen, row.forget}) do region:Hide() end
    end
    if #list == 0 then page.empty:Show(); y = y - LINE else page.empty:Hide() end
    UI.heights.characters = -y + 8
    UI.Fit()
end
function UI.Fit()
    if not UI.window then return end
    local tab = UI.tab or "storage"
    local height = tab == "storage" and UI.view and UI.view:Height() or (UI.heights and UI.heights[tab]) or 300
    UI.window:SetHeight(height + 50 + 30)
end
function UI.SetTab(key)
    if not UI.pages or not UI.pages[key] then key = "storage" end
    UI.tab = key
    for name, page in pairs(UI.pages) do if name == key then page:Show() else page:Hide() end end
    UI.tabs:Select(key)
    if key == "storage" then UI.view:Render()
    else UI.RenderCharacters() end
    UI.Fit()
end
function UI.Shown()
    return UI.window ~= nil and UI.window:IsShown()
end
function UI.Open(tab)
    local K = ns.TradeKit
    if not UI.window then
        local window = K.Window(UIParent, ns.T("setTitle"), WIDTH, 420)
        UI.window = window
        UI.tabs = K.Segment(window, {{key = "storage", label = ns.T("setStorage")},
            {key = "characters", label = ns.T("setCharacters")}}, UI.SetTab)
        UI.tabs.frame:SetPoint("TOPLEFT", window, "TOPLEFT", 14, -36)
        UI.pages, UI.heights = {}, {}
        for _, key in ipairs(UI.TABS) do
            local page = ns.NewFrame("Frame", nil, window)
            page:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -70)
            page:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 10)
            UI.pages[key] = page
        end
        UI.view = UI:New(UI.pages.storage)
        buildCharacters(UI.pages.characters)
    end
    UI.window:Show()
    UI.SetTab(tab or UI.tab or "storage")
end
function UI.Toggle()
    if UI.Shown() then UI.window:Hide() else UI.Open() end
end
local function minimapTip()
    return {ns.T("setTitle"), ns.T("setMinimapClick"), ns.T("setMinimapRight"), ns.T("setMinimapDrag")}
end
function UI.Install()
    if not UI.minimap then
        UI.minimap = ns.TradeKit.MinimapButton("ManaCodeAuctionScanMinimapButton", function(button)
            if button == "RightButton" then UI.OpenLedger() else UI.Toggle() end
        end, UI.MinimapAngle, minimapTip)
        if UI.minimap then UI.minimap:Reveal(UI.MinimapShown()) end
    end
    if not UI.page and ns.About and ns.TradeKit.FontRole then
        UI.page = ns.TradeKit.OptionsPage(ns.T("setPageTitle"), ns.T("setPageNote"), ns.T("setPageOpen"), UI.Open, {label = ns.T("setAbout"), open = function() ns.About.Open() end})
    end
    if ns.Guard.Warning() then UI.Open() end
end
local events = ns.NewFrame("Frame")
ns.Listen(events, "PLAYER_LOGIN")
events:SetScript("OnEvent", UI.Install)
