local ADDON, ns = ...
local UI = {links = {}, rows = {}}
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
    local windowsY = paceY - 18 - 3 * ROW - 30
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
    view.height = -(windowsY - 66)
    return view
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
    UI.Fit()
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
    if not ns.AccountingUI then ns.say(ns.T("tradeRestartRequired")); return end
    if UI.window then UI.window:Hide() end
    ns.AccountingUI.Open()
end
local INSET = 14
local CAPTION = 96
local LINE = 26
local NAME, STATE = 150, 100
UI.PRESETS = {"stone", "grain", "dark", "none"}
UI.TABS = {"storage", "look", "about"}
function UI.Others()
    local list = {}
    for _, addon in ipairs(ns.otherAddons or {}) do
        if addon.folder ~= ADDON then list[#list + 1] = addon end
    end
    return list
end
function UI.Title()
    for _, addon in ipairs(ns.otherAddons or {}) do
        if addon.folder == ADDON then return addon.name end
    end
    return ns.T("tradeTitle")
end
function UI.Version()
    return ns.Compat.AddonMeta(ADDON, "Version") or "?"
end
local function info(addon)
    return addon[GetLocale and GetLocale() == "ruRU" and "ruRU" or "enUS"] or addon.enUS or ""
end
local function copyRow(page, key, label, url, y)
    local K = ns.TradeKit
    K.Label(page, ns.T(label), INSET, y - 5, CAPTION - 6)
    local link = K.CopyField(page, WIDTH - INSET * 2 - CAPTION)
    link:SetPoint("TOPLEFT", page, "TOPLEFT", INSET + CAPTION, y)
    link:SetUrl(url)
    K.Tooltip(link, ns.T(label), ns.T(label .. "Tip") .. "\n" .. ns.T("setCopyTip"))
    UI.links[key] = link
    return y - LINE
end
local function buildLook(page)
    local K = ns.TradeKit
    local P, y = K.Palette, -4
    K.Label(page, ns.T("setTheme"), INSET, y, 200, "heading")
    y = y - 22
    local entries = {}
    for i, key in ipairs(UI.PRESETS) do entries[i] = {key = key, label = ns.T("setPreset_" .. key)} end
    UI.presets = K.Segment(page, entries, function(key) P.SetGrain(key) end, {ns.T("setTheme"), ns.T("setPresetTip")})
    UI.presets.frame:SetPoint("TOPLEFT", page, "TOPLEFT", INSET, y)
    page.weaker = K.Button(page, "-", 24, function() P.Strength(-P.STEP) end)
    page.weaker:SetPoint("LEFT", UI.presets.frame, "RIGHT", 12, 0)
    K.Tooltip(page.weaker, ns.T("setTheme"), ns.T("setWeakerTip"))
    page.strength = K.Label(page, "", 0, 0, 74)
    page.strength:ClearAllPoints()
    page.strength:SetPoint("LEFT", page.weaker, "RIGHT", 4, 0)
    page.strength:SetJustifyH("CENTER")
    page.stronger = K.Button(page, "+", 24, function() P.Strength(P.STEP) end)
    page.stronger:SetPoint("LEFT", page.weaker, "RIGHT", 82, 0)
    K.Tooltip(page.stronger, ns.T("setTheme"), ns.T("setStrongerTip"))
    y = y - 30
    page.palette = K.Button(page, ns.T("setPalette"), 100, function() P.Toggle() end)
    K.FitButton(page.palette)
    page.palette:SetPoint("TOPLEFT", page, "TOPLEFT", INSET, y)
    K.Tooltip(page.palette, ns.T("setPalette"), ns.T("setPaletteTip"))
    page.reset = K.Button(page, ns.T("setReset"), 100, function() P.Reset() end, "quiet")
    K.FitButton(page.reset)
    page.reset:SetPoint("LEFT", page.palette, "RIGHT", 6, 0)
    K.Tooltip(page.reset, ns.T("setReset"), ns.T("setResetTip"))
    return -(y - 34)
end
local function buildAbout(page)
    local K = ns.TradeKit
    local width, links, y = WIDTH - INSET * 2, ns.aboutLinks or {}, -4
    page.name = K.Label(page, "", INSET, y, width)
    y = y - 16
    K.Label(page, ns.T("setPurpose"), INSET, y, width, "secondary")
    y = y - 22
    local locale = GetLocale and GetLocale() == "ruRU" and "/" or "/en/"
    if links.release then y = copyRow(page, "release", "setDownload", links.release, y) end
    if links.site then y = copyRow(page, "site", "setSite", links.site .. locale, y) end
    if links.updater then y = copyRow(page, "updater", "setUpdater", links.updater, y) end
    y = y - 4
    local others = UI.Others()
    if #others > 0 then
        K.Label(page, ns.T("setOthers"), INSET, y, 200, "heading")
        y = y - 22
    end
    for i, addon in ipairs(others) do
        local row = {addon = addon}
        local title = addon.beta and addon.name .. " " .. K.Colored(ns.T("setBeta"), "secondary") or addon.name
        row.name = K.Label(page, title, INSET, y - 5, NAME - 6)
        row.state = K.Label(page, "", INSET + NAME, y - 5, STATE - 6)
        row.link = K.CopyField(page, width - NAME - STATE)
        row.link:SetPoint("TOPLEFT", page, "TOPLEFT", INSET + NAME + STATE, y)
        row.link:SetUrl(addon.url)
        K.Tooltip(row.link, addon.name, info(addon) .. "\n" .. ns.T("setCopyTip"))
        UI.rows[i] = row
        y = y - LINE
    end
    return -y
end
function UI.RenderLook()
    local K, look, about = ns.TradeKit, UI.pages and UI.pages.look, UI.pages and UI.pages.about
    if not look or not UI.presets then return end
    local spec = K.theme.grain
    UI.presets:Select(spec.key)
    look.strength:SetText(ns.T("palStrength", math.floor(spec.alpha * 100 + 0.5)))
    if spec.path then look.weaker:Enable(); look.stronger:Enable() else look.weaker:Disable(); look.stronger:Disable() end
    about.name:SetText(UI.Title() .. "  " .. K.Colored(ns.T("setVersion", UI.Version()), "secondary"))
    for _, row in ipairs(UI.rows) do
        local installed = ns.Compat.AddonState(row.addon.folder)
        row.state:SetText(ns.T(installed and "setInstalled" or "setMissing"))
        row.state:SetTextColor(unpack(installed and K.theme.positive or K.theme.secondary))
    end
end
function UI.Fit()
    if not UI.window then return end
    local tab = UI.tab or "storage"
    local height = tab == "storage" and UI.view and UI.view:Height() or (UI.heights and UI.heights[tab]) or 300
    UI.window:SetHeight(height + 50 + 30)
end
function UI.SetTab(key)
    if not UI.pages or not UI.pages[key] then return end
    UI.tab = key
    for name, page in pairs(UI.pages) do if name == key then page:Show() else page:Hide() end end
    UI.tabs:Select(key)
    if key == "storage" then UI.view:Render() else UI.RenderLook() end
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
        UI.tabs = K.Segment(window, {{key = "storage", label = ns.T("setStorage")}, {key = "look", label = ns.T("setTheme")},
            {key = "about", label = ns.T("setAbout")}}, UI.SetTab)
        UI.tabs.frame:SetPoint("TOPLEFT", window, "TOPLEFT", 14, -36)
        UI.pages, UI.heights = {}, {}
        for _, key in ipairs(UI.TABS) do
            local page = ns.NewFrame("Frame", nil, window)
            page:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -70)
            page:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 10)
            UI.pages[key] = page
        end
        UI.view = UI:New(UI.pages.storage)
        UI.heights.look = buildLook(UI.pages.look)
        UI.heights.about = buildAbout(UI.pages.about)
        hooksecurefunc(K.Palette, "Render", UI.RenderLook)
        window:HookScript("OnHide", function()
            for _, link in pairs(UI.links) do link:ClearFocus() end
            for _, row in ipairs(UI.rows) do row.link:ClearFocus() end
        end)
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
    if not UI.page then
        UI.page = ns.TradeKit.OptionsPage(ns.T("setPageTitle"), ns.T("setPageNote"), ns.T("setPageOpen"), UI.Open)
    end
    if ns.Guard.Warning() then UI.Open() end
end
local events = ns.NewFrame("Frame")
ns.Listen(events, "PLAYER_LOGIN")
events:SetScript("OnEvent", UI.Install)
