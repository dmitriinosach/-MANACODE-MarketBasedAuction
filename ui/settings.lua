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
    return minimapDB().shown == true
end
function UI.SetMinimapShown(on)
    local db = minimapDB()
    db.shown, db.hidden = on and true or nil, nil
    if UI.minimap then UI.minimap:Reveal(on) end
    if UI.view then UI.view:Render() end
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
    view.body = ns.NewFrame("Frame", nil, f)
    view.body:SetAllPoints(f)
    local body = view.body
    heading(body, ns.T("setStorage"), 0)
    local rows = {ns.T("setScans"), ns.T("setRaw"), ns.T("setDays"), ns.T("setKeys"), ns.T("setCopy")}
    view.storage = card(body, -18, #rows)
    view.storage:SetHeight(#rows * ROW + 24)
    local _, values = K.ValueRows(view.storage, -8, rows, {labelWidth = 150, valueWidth = 300, gap = 8})
    view.storageValues = values
    view.forget = K.Button(view.storage, ns.T("setForget"), 110, function() view:Forget() end, "quiet")
    view.forget:SetPoint("TOPRIGHT", view.storage, "TOPRIGHT", -K.theme.inset, -8 - 4 * K.theme.valueStep - 4)
    view.restore = K.Button(view.storage, ns.T("setRestore"), 70, function() view:Restore() end, "quiet")
    view.restore:SetPoint("RIGHT", view.forget, "LEFT", -6, 0)
    K.Tooltip(view.restore, ns.T("setRestore"), ns.T("setRestoreTip") .. "\n\n" .. ns.T("guardFile"))
    K.Tooltip(view.forget, ns.T("setForget"), ns.T("setForgetTip"))
    view.storageNote = K.Label(body, ns.T("setStorageNote"), 14, -18 - #rows * ROW - 30, WIDTH - 28, "secondary")
    local paceY = -18 - #rows * ROW - 68
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
    view.trackAll = K.Check(body, function(on) ns.Accounting.SetTrackAll(on) end)
    view.trackAll:SetPoint("TOPRIGHT", body, "TOPRIGHT", -14, windowsY - 66)
    view.trackAllLabel = K.Label(body, ns.T("acTrackAll"), 0, 0, 150, "secondary")
    view.trackAllLabel:ClearAllPoints(); view.trackAllLabel:SetPoint("RIGHT", view.trackAll, "LEFT", -2, 0)
    view.trackAllLabel:SetJustifyH("RIGHT")
    K.Tooltip(view.trackAll, ns.T("acTrackAll"), ns.T("acTrackAllTip"))
    view.ledgerMode = K.Segment(body, {{key = "character", label = ns.T("acMode_character")},
        {key = "account", label = ns.T("acMode_account")}}, function(key) ns.AccountingPool.SetMode(key); view:Render() end,
        {ns.T("acTitle"), ns.T("acModeTip")})
    view.ledgerMode.frame:SetPoint("TOPLEFT", body, "TOPLEFT", 14, windowsY - 50)
    local themeY = windowsY - 94
    heading(body, ns.T("setWindowTheme"), themeY)
    view.themes = K.ThemeTiles(body)
    view.themes.frame:SetPoint("TOPLEFT", body, "TOPLEFT", 14, themeY - 22)
    local themesHeight = view.themes:Layout(WIDTH - 28)
    view.themeNote = K.Label(body, ns.T("setWindowThemeNote"), 14, themeY - 22 - themesHeight - 8, WIDTH - 28, "secondary")
    local perfY = themeY - 22 - themesHeight - 8 - 30
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
    return self.height
end
function UI:Render()
    local K, Store = ns.TradeKit, ns.Store
    local db, status = Store.DB(), ns.Guard.Status()
    local last = db.scans[#db.scans]
    local values = self.storageValues
    values[1]:SetText(ns.T("setScansValue", #db.scans, last and last.total or 0))
    values[2]:SetText(ns.T("setRawValue", ns.Decimal(status.usage / 1048576, 1), Store.RAW_BYTES / 1048576))
    values[3]:SetText(ns.T("setDaysValue", Store.RAW_DAYS))
    values[4]:SetText(ns.T("setKeysValue", status.exact and "" or "<= ", status.keys, Store.FILE_KEYS, Store.LUA_KEYS))
    if Store.overKeys then values[4]:SetTextColor(unpack(K.theme.negative)) else values[4]:SetTextColor(unpack(K.theme.text)) end
    values[5]:SetText(status.copyAt and ns.T("setCopyValue", status.copyAt, status.copyWeight) or ns.T("setCopyNone"))
    values[5]:ClearAllPoints()
    if ns.Guard.state == "lost" then
        self.restore:Show(); self.forget:Show()
        values[5]:SetPoint("RIGHT", self.restore, "LEFT", -8, 0)
        values[5]:SetWidth(120); values[5]:SetText(status.copyAt or "")
    else
        self.restore:Hide(); self.forget:Hide()
        values[5]:SetPoint("TOPRIGHT", self.storage, "TOPRIGHT", -K.theme.inset, -8 - 4 * K.theme.valueStep - 8)
        values[5]:SetWidth(300)
    end
    local gap = ns.Query.Gap()
    self.gap:SetText(ns.T("setGapValue", ns.Decimal(gap, 1)))
    if gap > ns.Query.gap then self.resetPace:Enable() else self.resetPace:Disable() end
    self.mailPanel:SetChecked(ns.CollectUI.Shown())
    self.minimapCheck:SetChecked(UI.MinimapShown())
    self.trackAll:SetChecked(ns.Accounting.Book().trackAll == true)
    self.ledgerMode:Select(ns.AccountingPool.Mode())
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
    local done = ns.Guard.Restore()
    self:Render()
    if ns.Trader and ns.Trader.frame then ns.Trader.Refresh() end
    return done
end
function UI:Forget()
    local done = ns.Guard.Forget()
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
    return {title = ns.T("setTitle"), body = ns.T("setMinimapDrag"), keys = {
        {key = ns.T("scanKeyClick"), text = ns.T("setMinimapClick")},
        {key = ns.T("tipKeyRight"), text = ns.T("setMinimapRight")}}}
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
end
local events = ns.NewFrame("Frame")
ns.Listen(events, "PLAYER_LOGIN")
events:SetScript("OnEvent", UI.Install)
