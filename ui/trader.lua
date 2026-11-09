local _, ns = ...
local UI = { props = { selected = 1, page = 1 }, rows = {}, nav = {}, sections = {} }
UI.professionModes = {}
UI.processKind = "disenchant"
ns.Trader = UI
local PROCESS_KINDS = {
    {key = "disenchant", labelKey = "procDisenchant", module = "DisenchantUI", field = "disenchant", spell = 13262},
    {key = "prospect", labelKey = "procProspect", module = "ProspectUI", field = "prospect", spell = 31252},
    {key = "mill", labelKey = "procMill", module = "ProspectUI", field = "prospect", spell = 51005},
    {key = "recycle", labelKey = "procRecycle", module = "RecycleUI", field = "recycle", item = 34055},
}
function UI.ProcessIcon(key)
    for _, kind in ipairs(PROCESS_KINDS) do
        if kind.key == key then
            local icon
            if kind.spell then icon = select(2, ns.Compat.SpellIcon(kind.spell))
            elseif kind.item then icon = select(10, ns.Compat.ItemInfo(kind.item)) end
            return icon or ns.TradeKit.ProfessionIcon("enchanting")
        end
    end
    return ns.TradeKit.ProfessionIcon("enchanting")
end
function UI.ProcessEntries()
    local entries = {}
    for _, kind in ipairs(PROCESS_KINDS) do
        local available = UI.ProcessAvailable(kind.key)
        entries[#entries + 1] = {key = kind.key, labelKey = kind.labelKey, icon = UI.ProcessIcon(kind.key),
            disabled = not available, tip = not available and ns.T("procLater") or nil}
    end
    return entries
end
local MODE_VIEWS = {
    jewelry = {module = "FamilyUI", field = "jewelry"},
    craft = {module = "AlchemyUI", field = "alchemy"},
    resources = {module = "GatheringUI", field = "gathering"},
    resale = {module = "ResaleUI", field = "resale"},
    leveling2 = {module = "Leveling2UI", field = "leveling2"},
}
local function professionViewKey(profession, mode)
    if profession == "jewelry" and mode == "craft" then return "jewelry" end
    if mode == "items" then return "craft" end
    return mode
end
local PROFESSION_MODES = {
    {key = "craft", labelKey = "modeCraft"},
    {key = "items", labelKey = "modeItems"},
    {key = "resources", labelKey = "modeResources"},
    {key = "leveling2", labelKey = "modeLeveling2"},
    {key = "resale", labelKey = "modeNpc"},
}
local CRAFT_TABS = {alchemy = "modePotions", enchanting = "modeScrolls", inscription = "modeGlyphs",
    jewelry = "modeGems", mining = "modeSmelting"}
local NAV_MORE = {{key = "collections", labelKey = "collectionTitle"}, {key = "hidden", labelKey = "hiddenSection"},
    {key = "accounting", labelKey = "acNav"}}
local TOUR_VERSION = 2
local UPDATE_VERSION = 1
local TOUR_SCAN_ROWS = {{labelKey = "scanKeyClick", textKey = "scanKeySoft"},
    {labelKey = "tourKeyShift", textKey = "scanKeyHard"}, {labelKey = "tourKeyCtrl", textKey = "scanKeyMissing"}}
local function tourFrames(...)
    local list = {}
    for i = 1, select("#", ...) do
        local frame = select(i, ...)
        if frame then list[#list + 1] = frame end
    end
    return list
end
local function viewPart(name, field)
    local view = ns[name]
    return view and view.frame and rawget(view, field) or nil
end
local function viewSegment(name, field)
    local segment = viewPart(name, field)
    return segment and segment.frame or nil
end
local function navTab(key)
    return function() return tourFrames(UI.nav[key]) end
end
local function inspectorButton(field)
    return function()
        for _, view in ipairs(ns.TradeKit.Inspector.all) do
            if view.frame:IsVisible() then return tourFrames(rawget(view, field)) end
        end
        return {}
    end
end
local TOUR_ITEM = 34054
function UI.TourItem()
    return ns.TradeKit.Inspector.lastID or TOUR_ITEM
end
function UI.TourProfession()
    if UI.IsProfession(UI.section) then return UI.section end
    local first = UI.ProfessionEntries()[1]
    return first and first.key or "jewelry"
end
local TOUR_THEMES = {titleKey = "tourThemesTitle", textKey = "tourThemes",
    spot = function() return tourFrames(UI.themeButton, UI.settingsButton) end}
local TOUR = {
    {titleKey = "tourIntroTitle", textKey = "tourIntro"},
    {titleKey = "tourTabsTitle", textKey = "tourTabs", spot = function()
        local list = tourFrames(UI.professionMenu.frame)
        for _, button in pairs(UI.nav) do list[#list + 1] = button end
        return list
    end},
    {titleKey = "tourProcessingTitle", textKey = "tourProcessing", section = "processing", tab = navTab("processing"),
        spot = function() return tourFrames(UI.processMenu and UI.processMenu.frame) end},
    {titleKey = "tourProfessionsTitle", textKey = "tourProfessions", section = function() return UI.TourProfession() end,
        tab = function() return tourFrames(UI.professionMenu.frame) end,
        spot = function() return tourFrames(UI.professionMenu.frame, UI.modeSegment and UI.modeSegment.frame) end},
    {titleKey = "tourMaterialsTitle", textKey = "tourMaterials", section = "reagents", tab = navTab("reagents"),
        spot = function() return tourFrames(viewSegment("ReagentsUI", "scopeSegment")) end},
    {titleKey = "tourRefreshTitle", textKey = "tourRefresh", section = "reagents", tab = navTab("reagents"),
        rows = TOUR_SCAN_ROWS, spot = function() return tourFrames(viewPart("ReagentsUI", "scan")) end},
    {titleKey = "tourBargainTitle", textKey = "tourBargain", section = "bargain", tab = navTab("bargain"),
        spot = function() return tourFrames(viewPart("BargainUI", "scan")) end},
    {titleKey = "tourSeasonalTitle", textKey = "tourSeasonal", section = "seasonal", tab = navTab("seasonal"),
        spot = function() return tourFrames(UI.seasonSegments and UI.seasonSegments[1].frame, UI.seasonSegments and UI.seasonSegments[2].frame) end},
    {titleKey = "tourNpcTitle", textKey = "tourNpc", section = "npc", tab = navTab("npc"), needs = "npc",
        spot = function() return tourFrames(viewSegment("NpcUI", "segment")) end},
    {titleKey = "tourNpcCurrencyTitle", textKey = "tourNpcCurrency", section = "npc", tab = navTab("npc"), needs = "npc",
        prepare = function() UI.TourNpcSegment("currency") end,
        spot = function()
            local segment = viewPart("NpcUI", "segment")
            return tourFrames(segment and segment.buttons.currency)
        end},
    {titleKey = "tourCollectionsTitle", textKey = "tourCollections", section = "collections",
        tab = navTab("collections"),
        spot = function()
            local menu = viewPart("CollectionsUI", "mode")
            return tourFrames(menu and menu.frame, viewPart("CollectionsUI", "input"), viewPart("CollectionsUI", "add"))
        end},
    {titleKey = "tourHiddenTitle", textKey = "tourHidden", section = "hidden", tab = navTab("hidden"),
        spot = function() return tourFrames(viewPart("HiddenUI", "restoreAll")) end},
    {titleKey = "tourAccountingTitle", textKey = "tourAccounting", section = "accounting", tab = navTab("accounting"),
        spot = function()
            local view = UI.accountingView
            return tourFrames(view and view.views and view.views.frame)
        end},
    {titleKey = "tourBidsTitle", textKey = "tourBids", section = "bids", tab = navTab("bids"),
        spot = function() return tourFrames(viewSegment("BidsUI", "modes")) end},
    {titleKey = "tourBuyTitle", textKey = "tourBuy", section = "buy", tab = navTab("buy"),
        spot = function() return tourFrames(viewPart("ShoppingUI", "query"), viewPart("ShoppingUI", "search")) end},
    {titleKey = "tourBuyPlanTitle", textKey = "tourBuyPlan", section = "buy", tab = navTab("buy"),
        spot = function()
            local limit = viewPart("ShoppingUI", "limit")
            return tourFrames(viewPart("ShoppingUI", "need"), limit and limit.frame)
        end},
    {titleKey = "tourSellTitle", textKey = "tourSell", section = "sell", tab = navTab("sell"),
        spot = function() return tourFrames(viewPart("SellingUI", "scan")) end},
    {titleKey = "tourInspectorTitle", textKey = "tourInspector", spot = function()
        for _, view in ipairs(ns.TradeKit.Inspector.all) do
            if view.frame:IsVisible() then
                local list = tourFrames(view.item, view.actions and view.actions.frame, view.market, view.paths, view.offers)
                for i = #list, 1, -1 do if not list[i]:IsShown() then table.remove(list, i) end end
                return #list > 0 and list or tourFrames(view.frame)
            end
        end
        return {}
    end},
    {titleKey = "tourMarketTitle", textKey = "tourMarket", tab = inspectorButton("market"),
        window = function(id) ns.MarketWindow.Open(id) end, close = function() ns.MarketWindow.Close() end,
        spot = function()
            local board = ns.MarketWindow.board
            return tourFrames(board and board.frame)
        end},
    {titleKey = "tourPathsTitle", textKey = "tourPaths", tab = inspectorButton("paths"),
        window = function(id) ns.PathWindow.Open(id) end, close = function() ns.PathWindow.Close() end,
        spot = function()
            local view = ns.PathWindow.view
            return tourFrames(view and view.frame)
        end},
    {titleKey = "tourActionsTitle", textKey = "tourActions", rows = {{icon = "refresh", textKey = "tourIconRefresh"},
        {icon = "buy", textKey = "tourIconBuy"}, {icon = "hide", textKey = "tourIconHide"},
        {icon = "go", textKey = "tourIconGo"}, {icon = "make", textKey = "tourIconMake"},
        {icon = "paths", textKey = "tourIconPaths"}, {icon = "lists", textKey = "tourIconLists"},
        {icon = "expand", textKey = "tourIconExpand"}}},
    {titleKey = "tourHistoryTitle", textKey = "tourHistory", rows = {{labelKey = "tourKeyMouse4", textKey = "tourRowBack"},
        {labelKey = "tourKeyMouse5", textKey = "tourRowForward"}},
        spot = function() return tourFrames(UI.historyBack, UI.historyForward) end},
    {titleKey = "tourStatusTitle", textKey = "tourStatus", rows = {{labelKey = "tradeStop", textKey = "tourRowStop"},
        {labelKey = "tradeResume", textKey = "tourRowResume"}},
        spot = function() return tourFrames(UI.footerStatus) end},
    TOUR_THEMES,
    {titleKey = "tourHelpTitle", textKey = "tourHelp", spot = function() return tourFrames(UI.tourButton, UI.wikiButton) end},
}
function UI.TourLevelingProfession()
    if UI.IsProfession(UI.section) and UI.ProfessionHas(UI.section, "leveling2") then return UI.section end
    for _, entry in ipairs(UI.ProfessionEntries()) do
        if UI.ProfessionHas(entry.key, "leveling2") then return entry.key end
    end
    return "enchanting"
end
local function professionTab()
    return tourFrames(UI.professionMenu.frame)
end
local UPDATE = {
    {titleKey = "tourNewsTitle", textKey = "tourNews", rows = {{icon = "settings", textKey = "tourNewsThemes"},
        {icon = "expand", textKey = "tourNewsObtain"}, {icon = "buy", textKey = "tourNewsBatch"},
        {icon = "go", textKey = "tourNewsLeveling"}}},
    TOUR_THEMES,
    {titleKey = "tourObtainTitle", textKey = "tourObtain", section = "jewelry", tab = professionTab,
        prepare = function() UI.TourMode("jewelry", "craft"); UI.TourFamily(ns.rubyFamily.raw) end,
        spot = function()
            local obtain = viewPart("FamilyUI", "obtain")
            return tourFrames(obtain and obtain.frame)
        end},
    {titleKey = "tourBatchTitle", textKey = "tourBatch", section = "jewelry", tab = professionTab,
        prepare = function() UI.TourMode("jewelry", "craft"); UI.TourFamily(ns.rubyFamily.members[2]) end,
        spot = function()
            local batch = viewPart("FamilyUI", "batch")
            return tourFrames(batch and batch.frame, batch and batch.band and batch.band.frame)
        end},
    {titleKey = "tourLevelingTitle", textKey = "tourLeveling", section = function() return UI.TourLevelingProfession() end,
        tab = professionTab,
        prepare = function() UI.TourMode(UI.section, "leveling2") end,
        spot = function()
            local chart = viewPart("Leveling2UI", "chart")
            return tourFrames(chart and chart.canvas.frame)
        end},
    {titleKey = "tourSearchTitle", textKey = "tourSearch", section = "buy", tab = navTab("buy"),
        spot = function() return tourFrames(viewPart("ShoppingUI", "query"), viewPart("ShoppingUI", "search")) end},
}
function UI.TourShow(section)
    local tour = UI.tour
    if not tour or tour.busy or UI.Busy() then return false end
    if UI.section ~= section then
        UI:Switch(section)
        tour.moved = true
    end
    return true
end
function UI.TourNpcSegment(segment)
    local tour, view = UI.tour, ns.NpcUI
    if not tour or not view or not view.frame or view.props.segment == segment then return end
    tour.npcSegment = tour.npcSegment or view.props.segment
    view:SetProps({segment = segment})
    tour.moved = true
end
function UI.TourMode(profession, mode)
    local tour = UI.tour
    if not tour or UI.professionModes[profession] == mode or not UI.ProfessionHas(profession, mode) then return end
    tour.modes = tour.modes or {}
    if tour.modes[profession] == nil then tour.modes[profession] = UI.professionModes[profession] or false end
    UI.professionModes[profession] = mode
    UI:Switch(profession)
    tour.moved = true
end
function UI.TourFamily(id)
    local tour, view = UI.tour, ns.FamilyUI
    if not tour or not view or not view.frame or view.props.id == id then return end
    if tour.family == nil then tour.family = view.props.id or false end
    view:SetProps({id = id})
    tour.moved = true
end
function UI.TourWindow(open)
    local tour = UI.tour
    if not tour or tour.busy or UI.Busy() then return false end
    open(UI.TourItem())
    ns.TradeKit.Tour.Raise()
    return true
end
local function tourStep(entry)
    local step = {titleKey = entry.titleKey, textKey = entry.textKey, rows = entry.rows}
    local shown = false
    if entry.section then
        step.action = function()
            local section = entry.section
            if type(section) == "function" then section = section() end
            shown = UI.TourShow(section)
            if shown and entry.prepare then entry.prepare() end
        end
    elseif entry.window then
        step.action = function() shown = UI.TourWindow(entry.window) end
        step.leave = function()
            if shown then entry.close() end
            shown = false
        end
    end
    if entry.spot then
        step.target = function()
            if (entry.section or entry.window) and not shown then return entry.tab() end
            local list = entry.spot()
            for i = #list, 1, -1 do if not list[i]:IsVisible() then table.remove(list, i) end end
            if #list == 0 and entry.tab then return entry.tab() end
            return list
        end
    end
    return step
end
function UI.TourSteps(entries)
    local steps = {}
    for _, entry in ipairs(entries or TOUR) do
        if not entry.needs or UI.nav[entry.needs] then steps[#steps + 1] = tourStep(entry) end
    end
    return steps
end
local function startTour(entries, field, version)
    local K = ns.TradeKit
    if not UI.frame or K.Tour.running then return false end
    UI.tourPending = nil
    UI.tour = {route = UI.Route(), busy = UI.Busy()}
    local db = ns.Store.DB()
    db[field] = version
    db.updateSeen = UPDATE_VERSION
    return K.Tour.Start(UI.frame, UI.TourSteps(entries), UI.EndTour)
end
function UI.StartTour()
    return startTour(TOUR, "tourSeen", TOUR_VERSION)
end
function UI.StartUpdateTour()
    return startTour(UPDATE, "updateSeen", UPDATE_VERSION)
end
function UI.Help(key)
    if key == "wiki" then
        if ns.MarketWiki then ns.MarketWiki.Open(UI.WikiKey()) end
    else UI.StartTour() end
end
function UI.WikiKey()
    local section = UI.section
    if section and UI.IsProfession(section) then return "professions" end
    if section == "reagents" then return "materials" end
    return section
end
function UI.EndTour()
    local tour = UI.tour
    UI.tour = nil
    if not tour or not tour.moved or UI.Busy() then return end
    if tour.npcSegment and ns.NpcUI then ns.NpcUI:SetProps({segment = tour.npcSegment}) end
    for profession, mode in pairs(tour.modes or {}) do UI.professionModes[profession] = mode or nil end
    if tour.family ~= nil and ns.FamilyUI then ns.FamilyUI:SetProps({id = tour.family or nil}) end
    UI.Go(tour.route)
end
local function unseenTour()
    local db = ns.Store.DB()
    if (db.tourSeen or 0) < TOUR_VERSION then return UI.StartTour end
    if (db.updateSeen or 0) < UPDATE_VERSION then return UI.StartUpdateTour end
    return nil
end
function UI.PollTour()
    if not UI.tourPending or not UI.frame or not UI.frame:GetLeft() then return false end
    UI.tourPending = nil
    local start = unseenTour()
    if not start or UI.Busy() then return false end
    return start()
end
local KIT_PARTS = {"theme", "Money", "Button", "Tooltip", "ItemChoice", "Menu", "AuctionFilters", "Scroller", "MarketColumns",
    "MarketRow", "Inspector", "OutcomeList", "BatchPanel", "TimeChart", "Modal", "FontRole", "AuctionChrome", "MinimapButton", "CurrencyChip", "PostForm", "Tour", "Doc", "Palette"}
local function kitReady()
    local K = ns.TradeKit
    if not K then return false end
    for _, key in ipairs(KIT_PARTS) do if K[key] == nil then return false end end
    return true
end
function UI.Ready()
    if kitReady() and ns.About and ns.AuctionPage and ns.Markets and type(ns.Markets.routes) == "table"
        and ns.Query and ns.Plan and ns.Buy and ns.Shopping and ns.ShoppingUI and ns.Selling and ns.SellingUI
        and ns.Family and ns.FamilyUI and ns.gemFamilies and ns.gemByRaw and ns.gemByItem
        and ns.Alchemy and ns.AlchemyUI and ns.Batch and ns.alchemyRecipes
        and ns.Reagents and ns.ReagentsUI and ns.Resale and ns.ResaleUI and ns.CraftPlan and ns.AuctionWindow
        and ns.Activity and ns.Disenchant and ns.DisenchantUI and ns.MarketBoardUI
        and ns.Collections and ns.CollectionsUI and ns.Hidden and ns.HiddenUI and ns.Recipes
        and ns.seasonalEvents and ns.Seasonal and ns.SeasonalUI and ns.BuyModal
        and ns.Accounting and ns.AccountingEvents and ns.AccountingUI
        and ns.Recycle and ns.RecycleUI and ns.recyclePairs and ns.GatheringUI and ns.gatheringCatalogs
        and ns.craftCatalogs.engineering and ns.professionUses then return true end
    if not UI.warned then
        UI.warned = true
        ns.say(ns.T("tradeRestartRequired"), "bad")
    end
    return false
end
function UI:SetProps(props)
    self.props = props
    self:Render()
end
function UI.Status(text, tone, ttl)
    UI.lastStatus, UI.lastTone = text, tone
    if ttl then
        UI.statusTimer = UI.statusTimer or ns.NewFrame("Frame")
        local left = ttl
        UI.statusTimer:SetScript("OnUpdate", function(self, elapsed)
            left = left - (elapsed or 0)
            if left > 0 then return end
            self:SetScript("OnUpdate", nil)
            if UI.lastStatus == text then UI.lastStatus, UI.lastTone = nil, nil; UI.RenderStatus() end
        end)
    end
    UI.RenderStatus()
    if ns.MarketBoardUI then ns.MarketBoardUI.Status(text) end
    if ns.PathWindow then ns.PathWindow.Controls() end
    if ns.FamilyUI and ns.FamilyUI.frame then ns.FamilyUI:Controls() end
    if ns.AlchemyUI and ns.AlchemyUI.frame then ns.AlchemyUI:Controls() end
    if ns.ReagentsUI and ns.ReagentsUI.frame then ns.ReagentsUI:Controls() end
    if ns.ResaleUI and ns.ResaleUI.frame then ns.ResaleUI:Controls() end
    if ns.GatheringUI and ns.GatheringUI.frame then ns.GatheringUI:Controls() end
    if ns.ProspectUI and ns.ProspectUI.frame then ns.ProspectUI:Controls() end
    if ns.BargainUI and ns.BargainUI.frame then ns.BargainUI:Controls() end
    if ns.BidsUI and ns.BidsUI.frame then ns.BidsUI:Controls() end
    if ns.DisenchantUI and ns.DisenchantUI.frame then
        if UI.ViewActive("disenchant") then ns.DisenchantUI:Render() else ns.DisenchantUI:Controls() end
    end
    if ns.CollectionsUI and ns.CollectionsUI.frame and UI.section == "collections" then ns.CollectionsUI:Render() end
    if ns.SeasonalUI and ns.SeasonalUI.frame and UI.section == "seasonal" then ns.SeasonalUI:Render() end
    if ns.NpcUI and ns.NpcUI.frame then ns.NpcUI:Controls() end
    if ns.SellingUI and ns.SellingUI.frame then ns.SellingUI:Controls() end
    if ns.Leveling2UI and ns.Leveling2UI.frame then
        if UI.ViewActive("leveling2") then ns.Leveling2UI:Render() else ns.Leveling2UI:Controls() end
    end
    if ns.RecycleUI and ns.RecycleUI.frame then
        if UI.ViewActive("recycle") then ns.RecycleUI:Render() else ns.RecycleUI:Controls() end
    end
end
function UI.Busy()
    return ns.Scan.state.phase ~= "idle" or ns.Buy.Active() or ns.Batch.job ~= nil
        or (ns.Disenchant and ns.Disenchant.purchase ~= nil) or (ns.Prospect and ns.Prospect.purchase ~= nil)
        or (ns.Bargain and ns.Bargain.Active and ns.Bargain.Active()) or (ns.Bids and ns.Bids.Active()) or false
end
function UI.StopAll()
    if ns.Disenchant and ns.Disenchant.purchase then ns.Disenchant.CancelBuy() end
    if ns.Prospect and ns.Prospect.purchase then ns.Prospect.CancelBuy() end
    if ns.Bargain and ns.Bargain.Active and ns.Bargain.Active() then ns.Bargain.Cancel() end
    if ns.Bids and (ns.Bids.job or ns.Bids.raise) then ns.Bids.Cancel() end
    ns.Buy.Stop()
    ns.Batch.Stop()
    ns.Scan.Stop()
    UI.Refresh()
end
function UI.ResumeScan()
    if ns.Scan.state.phase == "paused" then ns.Scan.Start("pages") end
    UI.Refresh()
end
function UI.ContextText()
    local views = {prospect = ns.ProspectUI, mill = ns.ProspectUI, disenchant = ns.DisenchantUI,
        craft = ns.AlchemyUI, leveling2 = ns.Leveling2UI, hidden = ns.HiddenUI, bargain = ns.BargainUI, sell = ns.SellingUI, bids = ns.BidsUI}
    for key, view in pairs(views) do if view.frame and UI.ViewActive(key) then return view.statusText end end
end
function UI.StatusLink()
    if ns.Scan.state.phase ~= "idle" or ns.Buy.Active() then return nil end
    local view = ns.AlchemyUI
    if view and view.frame and UI.ViewActive("craft") then return view.statusLink end
end
function UI.RenderStatusLink()
    local link, spec = UI.footerLink, UI.StatusLink()
    if not link or (InCombatLockdown and InCombatLockdown()) then return link ~= nil and link:IsShown() end
    if spec and spec.spell and link:SetLink(spec.spell, spec.text) then
        ns.TradeKit.Tooltip(link, spec.title or spec.text, spec.tip or "")
    else link:Hide() end
    local shown = link:IsShown()
    local x = (UI.statusLeft or 190) + (shown and (link:GetWidth() or 0) + 4 or 0)
    UI.footerStatus:SetPoint("BOTTOMLEFT", UI.footerRoot or UI.footerStatus:GetParent(), "BOTTOMLEFT", x, 10)
    return shown
end
function UI.StatusParts()
    local K, state = ns.TradeKit, ns.Scan.state
    if state.phase == "idle" and not ns.Buy.Active() then
        local parts = {}
        local notice = ns.Guard and ns.Guard.Notice()
        if notice and notice ~= "" then parts[#parts + 1] = {text = notice, tone = "bad"} end
        local context = UI.ContextText()
        if context and context ~= "" then parts[#parts + 1] = {text = context} end
        if UI.lastStatus then parts[#parts + 1] = {text = UI.lastStatus, tone = UI.lastTone} end
        local parked = ns.Scan.Parked()
        if parked then
            parts[#parts + 1] = {text = ns.T("statusParked", parked.page, math.max(parked.pages, 1), K.Ago(time() - parked.at))}
        end
        return parts
    end
    return {}
end
function UI.ActivityText()
    local job = UI.JobText()
    if job then return job end
    local list = {}
    for i, part in ipairs(UI.StatusParts()) do list[i] = part.text end
    return table.concat(list, " | ")
end
local STATUS_COLORS = {bad = "negative", good = "positive"}
local function statusLine(parts, words)
    local out, left = {}, words
    for _, part in ipairs(parts) do
        if left and left <= 0 then break end
        local text = part.text
        if left then
            local kept, n = {}, 0
            for word in text:gmatch("%S+") do
                if n >= left then break end
                n = n + 1; kept[n] = word
            end
            left = left - n
            text = table.concat(kept, " ")
        end
        out[#out + 1] = STATUS_COLORS[part.tone] and ns.TradeKit.Colored(text, STATUS_COLORS[part.tone]) or text
    end
    return table.concat(out, " | ") .. (words and "..." or "")
end
function UI.FitStatus(fs, parts)
    local full = {}
    for i, part in ipairs(parts) do full[i] = part.text end
    UI.statusFull = table.concat(full, " | ")
    fs:SetText(statusLine(parts))
    local width, cut = fs.GetStringWidth and fs:GetWidth() or 0, false
    if width > 0 and (fs:GetStringWidth() or 0) > width then
        local total = 0
        for _, part in ipairs(parts) do for _ in part.text:gmatch("%S+") do total = total + 1 end end
        local low, high = 0, total - 1
        while low < high do
            local mid = math.ceil((low + high) / 2)
            fs:SetText(statusLine(parts, mid))
            if (fs:GetStringWidth() or 0) <= width then low = mid else high = mid - 1 end
        end
        fs:SetText(statusLine(parts, low))
        cut = true
    end
    UI.statusCut = cut
    if UI.footerStatusHit then UI.footerStatusHit:EnableMouse(cut) end
end
function UI.ActivityShare()
    if ns.Buy.Active() then
        local R = ns.Buy.state
        return R.pages > 0 and math.min(1, R.page / R.pages) or nil
    end
    local S, job = ns.Scan.state, ns.Batch.job
    if S.mode == "all" and S.phase ~= "idle" then
        return S.count > 0 and S.phase ~= "wait" and math.min(1, S.index / S.count) or nil
    end
    local page = S.phase ~= "idle" and S.pages > 0 and math.min(1, S.page / S.pages) or nil
    if job and #job.items > 1 then return math.min(1, (job.index - 1 + (page or 0)) / #job.items) end
    local classes = S.phase ~= "idle" and S.scan and S.scan.deClasses
    if classes and #classes > 1 and page then return math.min(1, ((S.scan.deRoute or 1) - 1 + page) / #classes) end
    return page
end
local LEAD_VIEWS = {
    disenchant = function() return ns.DisenchantUI end,
}
function UI.RenderLead()
    local slot = UI.leadSlot
    if not slot then return 0 end
    local frames
    for key, get in pairs(LEAD_VIEWS) do
        local view = get()
        if view and view.frame and view.Lead and UI.ViewActive(key) then frames = view:Lead() end
    end
    if frames ~= UI.leadFrames then
        for _, frame in ipairs(UI.leadFrames or {}) do
            frame:Hide()
            local home = rawget(frame, "leadHome")
            if home then frame:SetParent(home); frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", home, "TOPLEFT", 0, 0) end
        end
        UI.leadFrames = frames
    end
    local width, left = 0, nil
    local attached = frames ~= nil and rawget(slot, "attached") ~= frames
    slot.attached = frames
    for _, frame in ipairs(frames or {}) do
        if not rawget(frame, "leadHome") then frame.leadHome = frame:GetParent() end
        frame:SetParent(slot); frame:ClearAllPoints()
        if attached and rawget(frame, "text") and frame.GetText then
            local text = frame:GetText()
            if text and text ~= "" then frame:SetText(""); frame:SetText(text) end
        end
        if frame:IsShown() then
            if left then frame:SetPoint("LEFT", left, "RIGHT", 6, 0) else frame:SetPoint("LEFT", slot, "LEFT", 0, 0) end
            width = width + (frame:GetWidth() or 0) + (left and 6 or 0)
            left = frame
        else frame:SetPoint("LEFT", slot, "LEFT", 0, 0) end
    end
    slot:SetWidth(math.max(1, width))
    if width > 0 then UI.leadDivider:Show() else UI.leadDivider:Hide() end
    return width
end
function UI.JobText()
    local K, S = ns.TradeKit, ns.Scan.state
    if ns.Buy.Active() then
        local R = ns.Buy.state
        return ns.T("jobBuy", R.page + 1, R.pages > 0 and tostring(R.pages) or "?", R.bought, K.Money(R.spent))
    end
    if S.phase == "idle" then return nil end
    local D, view = ns.Disenchant, ns.DisenchantUI
    if D and view and view.frame and D.Progress(view.group) then return view:ProgressText() end
    local job = ns.Batch.job
    local pages = S.pages > 0 and tostring(S.pages) or "?"
    if job and S.scan and S.scan.itemID then
        local text = ns.T("jobPrices", math.min(job.index, #job.items), #job.items, ns.Markets.Name(S.scan.itemID),
            S.page + 1, pages)
        return S.phase == "paused" and ns.T("deProgressPaused", text) or text
    end
    if S.mode == "all" and S.count > 0 then return ns.T("jobMarket", S.index, S.count) end
    return UI.lastStatus or ns.T("deOtherScan")
end
local BAR_VIEWS = {
    disenchant = function() return ns.DisenchantUI end,
    recycle = function() return ns.RecycleUI end,
    accounting = function() return UI.accountingView end,
    reagents = function() return ns.ReagentsUI end,
    npc = function() return ns.NpcUI end,
    collections = function() return ns.CollectionsUI end,
    seasonal = function() return ns.SeasonalUI end,
    prospect = function() return ns.ProspectUI end,
    mill = function() return ns.ProspectUI end,
    bargain = function() return ns.BargainUI end,
    sell = function() return ns.SellingUI end,
    bids = function() return ns.BidsUI end,
}
for key, entry in pairs(MODE_VIEWS) do
    BAR_VIEWS[key] = function() return ns[entry.module] end
end
function UI.RenderBar()
    local slot = UI.barSlot
    if not slot then return 0 end
    local frames
    for key, get in pairs(BAR_VIEWS) do
        local view = get()
        if view and view.frame and view.Bar and UI.ViewActive(key) then frames = view:Bar() end
    end
    if frames ~= UI.barFrames then
        for _, frame in ipairs(UI.barFrames or {}) do
            frame:Hide(); frame:ClearAllPoints()
            if rawget(frame, "barHome") then frame:SetParent(rawget(frame, "barHome")) end
        end
        UI.barFrames = frames
    end
    local width, right = 0, nil
    for i = #(frames or {}), 1, -1 do
        local frame = frames[i]
        if not rawget(frame, "barHome") then frame.barHome = frame:GetParent() end
        local gap = rawget(frame, "barGap") or 4
        frame:SetParent(slot); frame:ClearAllPoints()
        if right then frame:SetPoint("RIGHT", right, "LEFT", -gap, 0)
        else frame:SetPoint("RIGHT", slot, "RIGHT", 0, 0) end
        frame:Show()
        width = width + (frame:GetWidth() or 0) + (right and gap or 0)
        right = frame
    end
    local label = UI.barLabel
    if label and right then
        local text = math.ceil(label:GetStringWidth() or 60)
        label:SetWidth(text + 2)
        label:ClearAllPoints(); label:SetPoint("RIGHT", right, "LEFT", -6, 0); label:Show()
        width = width + text + 8
    elseif label then label:Hide() end
    width = math.max(1, width)
    slot:SetWidth(width)
    return width
end
function UI.RenderStatus()
    if not UI.footerStatus then return end
    local busy = UI.Busy()
    local waiting = ns.Scan.state.phase == "paused" or ns.Buy.state.phase == "ready"
    if busy then UI.footerStop:Show() else UI.footerStop:Hide() end
    if ns.Scan.state.phase == "paused" then UI.footerResume:Show() else UI.footerResume:Hide() end
    local parked = not busy and ns.Scan.Parked()
    if parked then UI.footerRescan:Show(); UI.footerRescanDrop:Show()
    else UI.footerRescan:Hide(); UI.footerRescanDrop:Hide() end
    if UI.fullScanButton then
        ns.TradeKit.DisabledTip(UI.fullScanButton, ns.T("tradeFullScan"), busy and ns.T("batchBusy") or nil)
        if busy then UI.fullScanButton:Disable() else UI.fullScanButton:Enable() end
    end
    local right = 30 + UI.RenderBar() + 10
    for _, button in ipairs({UI.footerStop, UI.footerResume, UI.footerRescan, UI.footerRescanDrop}) do
        if button:IsShown() then right = right + (button:GetWidth() or 0) + 6 end
    end
    local lead = UI.RenderLead()
    local left = 190
    if UI.money then
        left = ns.TradeKit.WINDOW_PAD + math.ceil(UI.money:GetStringWidth() or 120) + 17 + (lead > 0 and lead + 12 or 0)
    end
    UI.statusLeft = left
    local job, text = UI.footerJob, UI.JobText()
    if job and UI.footerRoot then
        if text then
            job:ClearAllPoints()
            job:SetPoint("BOTTOMLEFT", UI.footerRoot, "BOTTOMLEFT", left, 9)
            job:SetPoint("BOTTOMRIGHT", UI.footerRoot, "BOTTOMRIGHT", -right, 9)
            UI.FitStatus(job.line, {{text = text}})
            job:Show()
        else job:Hide() end
    end
    if UI.footerRoot then
        UI.footerStatus:SetPoint("BOTTOMRIGHT", UI.footerRoot, "BOTTOMRIGHT", -right, 10)
        UI.footerStatus:SetPoint("BOTTOMLEFT", UI.footerRoot, "BOTTOMLEFT", left, 10)
    end
    local parts = UI.StatusParts()
    if UI.footerLink then UI.footerLink:ClearAllPoints()
        UI.footerLink:SetPoint("BOTTOMLEFT", UI.footerRoot or UI.footerLink:GetParent(), "BOTTOMLEFT", UI.statusLeft or 190, 8) end
    if UI.RenderStatusLink() and parts[1] then parts[1] = {text = "| " .. parts[1].text, tone = parts[1].tone} end
    if text then parts = {} end
    UI.FitStatus(UI.footerStatus, parts)
    UI.footerProgress:Set(busy and UI.ActivityShare() or nil, busy and not waiting, busy)
    UI.UpdateMoney()
    UI.RenderHistory()
end
function UI.ScanMarket(mode)
    local started = ns.Scan.Start(mode)
    UI.Refresh()
    return started
end
function UI.ViewActive(view)
    if MODE_VIEWS[view] then
        return UI.IsProfession(UI.section) and professionViewKey(UI.section, UI.professionModes[UI.section]) == view
    end
    for _, kind in ipairs(PROCESS_KINDS) do
        if kind.key == view then return UI.section == "processing" and UI.processKind == view end
    end
    return UI.section == view
end
function UI.IsProfession(section)
    return section == "jewelry" or (section ~= nil and (ns.craftCatalogs[section] ~= nil or ns.gatheringCatalogs[section] ~= nil))
end
function UI.ProcessAvailable(kind)
    for _, entry in ipairs(PROCESS_KINDS) do
        if entry.key == kind then return ns[entry.module] ~= nil end
    end
    return false
end
function UI.Refresh()
    if UI.frame then
        UI:LayoutNavigation()
        if UI.viewControls then UI.viewControls:Refresh() end
        UI.RenderStatus()
        for _, view in ipairs({ns.FamilyUI, ns.AlchemyUI, ns.ReagentsUI, ns.GatheringUI, ns.ResaleUI, ns.DisenchantUI,
            ns.CollectionsUI, ns.SeasonalUI, ns.NpcUI, ns.SellingUI, ns.HiddenUI, ns.RecycleUI,
            ns.ProspectUI, ns.BargainUI, ns.BidsUI, UI.accountingView}) do
            if view and view.frame and view.frame:IsVisible() then view:Render() end
        end
        if ns.PathWindow then ns.PathWindow.Refresh() end
        if ns.MarketWindow then ns.MarketWindow.Refresh() end
    end
    local shopping = ns.ShoppingUI
    if shopping and shopping.frame and shopping.frame:IsVisible() then shopping:Render() end
end
function UI:ShowSection(section)
    UI.Navigate(function() self:Switch(section) end)
end
function UI:Switch(section)
    if section == "leveling" then
        self.professionModes.enchanting = "leveling2"; section = "enchanting"
    else
        for _, kind in ipairs(PROCESS_KINDS) do
            if kind.key == section then self.processKind = section; section = "processing" end
        end
    end
    if self.section ~= section and ns.Buy.Active() then ns.Buy.Stop() end
    self.section = section
    local key = UI.SectionKey(section)
    for _, frame in pairs(self.sections) do frame:Hide() end
    self:Section(key):Show()
    local profession = key == "profession"
    if section == "processing" then self:ShowProcessKind()
    elseif section == "seasonal" then self:ShowSeasonEvent()
    elseif profession then self:ShowProfession(section) end
    local labelKey = section == "jewelry" and "jewelrySection"
        or (ns.craftCatalogs[section] and ns.craftCatalogs[section].labelKey)
        or (ns.gatheringCatalogs[section] and ns.gatheringCatalogs[section].labelKey) or "craftProfessions"
    self.professionMenu.frame:SetText(ns.T(labelKey))
    self:LayoutNavigation()
    for key, button in pairs(self.nav) do button:SetActive(key == section) end
    self.professionMenu.frame:SetActive(profession)
    local moreKey
    for _, entry in ipairs(NAV_MORE) do if entry.key == section then moreKey = entry.labelKey end end
    self.moreMenu.frame:SetText(ns.T(moreKey or "navMore"))
    self.moreMenu.frame:SetActive(moreKey ~= nil)
    UI.Refresh()
end
function UI:ShowProcessKind()
    if not UI.ProcessAvailable(self.processKind) then self.processKind = "disenchant" end
    local kind, shown = self.processKind, nil
    self.processing:Show()
    for _, entry in ipairs(PROCESS_KINDS) do
        if entry.key == kind then shown = entry end
        if self[entry.field] then self[entry.field]:Hide() end
    end
    self[shown.field] = self[shown.field] or ns[shown.module]:New(self.processing).frame
    self[shown.field]:Show()
    if shown.module == "ProspectUI" then ns.ProspectUI:SetProps({mode = kind}) end
    self.processMenu.frame:SetText(ns.T("recycleNav"))
end
function UI.OpenProcessing(kind)
    UI.Navigate(function()
        if not UI.ProcessAvailable(kind) then kind = "disenchant" end
        UI.processKind = kind
        UI:Switch("processing")
    end)
end
function UI:ShowSeasonEvent()
    local key = ns.SeasonalUI.props.event
    self.seasonal:Show()
    ns.SeasonalUI:SetProps({event = key})
    for _, segment in ipairs(self.seasonSegments) do segment:Select(key) end
end
function UI.OpenSeasonal(key)
    UI.Navigate(function()
        local event = ns.Seasonal.Event(key)
        if event and #event.items > 0 then ns.SeasonalUI.props.event = key end
        UI:Switch("seasonal")
    end)
end
function UI:ShowProfession(profession)
    local job = ns.Batch.job
    if job and job.levelingProfession and job.levelingProfession ~= profession then ns.Batch.Stop() end
    local mode = self.professionModes[profession] or "craft"
    if not UI.ProfessionHas(profession, mode) then mode = UI.ProfessionHas(profession, "craft") and "craft" or "resources" end
    self.professionModes[profession] = mode
    self.professionView:Show()
    local view = professionViewKey(profession, mode)
    for _, entry in pairs(MODE_VIEWS) do
        if self[entry.field] then self[entry.field]:Hide() end
    end
    local frame = self:ModeView(view)
    frame:Show()
    if view ~= "jewelry" then ns[MODE_VIEWS[view].module]:SetProps({profession = profession}) end
    local segment, labels = self.modeSegment, UI.ProfessionTabs(profession)
    segment:Arrange(labels)
    if next(labels) then segment.frame:Show() else segment.frame:Hide() end
    segment:Select(mode)
    local head = ns[MODE_VIEWS[view].module].head or {}
    self.professionHead:SetProps({lead = segment.frame, filters = head.filters, actions = head.actions, extra = head.extra})
end
function UI.ProfessionHas(profession, mode)
    if mode == "craft" then return profession == "jewelry" or ns.craftCatalogs[profession] ~= nil end
    if mode == "items" then return profession == "jewelry" and ns.craftCatalogs.jewelry ~= nil end
    if mode == "resources" then return ns.gatheringCatalogs[profession] ~= nil end
    if mode == "leveling2" then return ns.levelingPaths ~= nil and ns.levelingPaths[profession] ~= nil end
    if mode == "resale" then return next(ns.Resale.Items(profession)) ~= nil end
    return false
end
function UI.ProfessionTabs(profession)
    local labels, count = {}, 0
    for _, mode in ipairs(PROFESSION_MODES) do
        if UI.ProfessionHas(profession, mode.key) then
            labels[mode.key] = ns.T(mode.key == "craft" and CRAFT_TABS[profession] or mode.labelKey)
            count = count + 1
        end
    end
    if count == 1 then return {} end
    return labels
end
function UI.SetProfessionMode(profession, mode)
    if not UI.IsProfession(profession) or not UI.ProfessionHas(profession, mode) then return end
    UI.Navigate(function()
        UI.professionModes[profession] = mode
        UI:Switch(profession)
    end)
end
function UI.OpenProfession(profession)
    UI:ShowSection(profession)
end
function UI.OpenRecipe(profession, id)
    local catalog = ns.craftCatalogs[profession]
    if not catalog or not catalog.byItem[id] then return end
    UI.Navigate(function()
        UI.professionModes[profession] = profession == "jewelry" and "items" or "craft"
        UI:Switch(profession)
        ns.AlchemyUI:SetProps({recipe = id, id = id, reveal = true})
    end)
end
function UI.OpenFamily(family, id)
    UI.Navigate(function()
        UI:Switch("jewelry")
        if ns.FamilyUI then ns.FamilyUI:SetProps({family = family, id = id}) end
    end)
end
function UI.OpenReagent(id)
    UI.Navigate(function()
        UI:Switch("reagents")
        ns.ReagentsUI:SetProps({id = id})
    end)
end
function UI.OpenBuy(id, need)
    if ns.vendorPrices and ns.vendorPrices[id] then ns.say(ns.T("cacheVendor")); return end
    local name = ns.Compat.ItemInfo(id)
    if not name then ns.say(ns.T("tradeUnknownItem"), "bad"); return end
    UI.Navigate(function()
        UI:Switch("buy")
        if need then
            if need > ns.Plan.MAX_UNITS then ns.say(ns.T("levelBuyBatch", need, ns.Plan.MAX_UNITS)); need = ns.Plan.MAX_UNITS end
            ns.Shopping.Reset()
            ns.Shopping.SetNeed(need)
            UI.buyView.pendingNeed = nil
        end
        UI.buyView.query:SetText(name)
        ns.Shopping.Search(name, id)
    end)
end
function UI.OpenSell(id)
    UI.Navigate(function()
        UI:Switch("sell")
        ns.SellingUI:SetProps({id = id})
    end)
end
local HISTORY = 50
local function viewOf(section, sub)
    if section == "processing" then return sub end
    if UI.IsProfession(section) then
        if sub == "craft" then return section == "jewelry" and "jewelry" or "craft" end
        if sub == "items" then return "craft" end
        return sub
    end
    return section
end
local function prospectView()
    return {
        scroll = function() return ns.ProspectUI.table end,
        read = function(route)
            local s = ns.ProspectUI:S()
            route.extra = {view = s.view, target = s.target}
            if s.selected ~= nil and s.selected == s.chosen then route.item = s.selected end
        end,
        write = function(route)
            local view = ns.ProspectUI
            view:SetProps({view = route.extra.view, target = route.extra.target})
            local s = view:S()
            s.selected, s.chosen = route.item, route.item
            view:Render()
        end,
    }
end
local VIEWS = {
    buy = {
        scroll = function() return ns.ShoppingUI.choiceTable end,
        read = function(route)
            local S = ns.Shopping.state
            route.item, route.extra = S.itemID, {need = S.need}
        end,
        write = function(route) if route.item then ns.ShoppingUI:Show(route.item, route.extra.need) end end,
    },
    disenchant = {
        scroll = function() return ns.DisenchantUI.table end,
        read = function(route)
            local view = ns.DisenchantUI
            route.extra = {group = view.group}
            if view.selected ~= nil and view.selected == view.chosen then route.item = view.selected end
        end,
        write = function(route)
            local view = ns.DisenchantUI
            if route.extra.group ~= view.group then view:SelectGroup(route.extra.group) end
            view.selected, view.chosen = route.item, route.item
            view:Render()
        end,
    },
    prospect = prospectView(),
    mill = prospectView(),
    recycle = {
        scroll = function() return ns.RecycleUI.table end,
        read = function(route) route.item = ns.RecycleUI.props.key end,
        write = function(route) ns.RecycleUI:SetProps({key = route.item}) end,
    },
    craft = {
        scroll = function() return ns.AlchemyUI.table end,
        read = function(route)
            local p = ns.AlchemyUI.props
            route.item, route.extra = p.recipe, {id = p.id}
        end,
        write = function(route)
            ns.AlchemyUI:SetProps({recipe = route.item})
            ns.AlchemyUI:SetProps({id = route.extra.id or route.item})
        end,
    },
    jewelry = {
        scroll = function() return ns.FamilyUI.table end,
        read = function(route) route.item = ns.FamilyUI.props.id end,
        write = function(route) ns.FamilyUI:SetProps({id = route.item}) end,
    },
    resale = {
        scroll = function() return ns.ResaleUI.table end,
        read = function(route) route.item = ns.ResaleUI.props.id end,
        write = function(route) ns.ResaleUI:SetProps({id = route.item}) end,
    },
    reagents = {
        scroll = function() local view = ns.ReagentsUI; return view.tables[view.scope] end,
        read = function(route)
            local view = ns.ReagentsUI
            route.item, route.extra = view.props.id, {scope = view.scope, mode = view.mode}
        end,
        write = function(route)
            local view = ns.ReagentsUI
            if route.extra.scope ~= view.scope then view:SetScope(route.extra.scope) end
            view.mode = route.extra.mode
            view:SetProps({id = route.item})
        end,
    },
    seasonal = {
        scroll = function() return ns.SeasonalUI.table end,
        read = function(route) route.item = ns.SeasonalUI.selected end,
        write = function(route) ns.SeasonalUI.selected = route.item; ns.SeasonalUI:Render() end,
    },
    collections = {
        scroll = function() return ns.CollectionsUI.table end,
        read = function(route) route.item = ns.CollectionsUI.selected end,
        write = function(route) ns.CollectionsUI.selected = route.item; ns.CollectionsUI:Render() end,
    },
    hidden = {
        scroll = function() return ns.HiddenUI.table end,
        read = function(route) route.item = ns.HiddenUI.selected end,
        write = function(route) ns.HiddenUI.selected = route.item; ns.HiddenUI:Render() end,
    },
    bargain = {scroll = function() return ns.BargainUI and ns.BargainUI.table end},
    npc = {
        scroll = function() return ns.NpcUI.table end,
        read = function(route)
            local p = ns.NpcUI.props
            route.item, route.extra = p.id, {segment = p.segment}
        end,
        write = function(route) ns.NpcUI:SetProps({segment = route.extra.segment, id = route.item}) end,
    },
    sell = {
        scroll = function() return ns.SellingUI.tables[ns.SellingUI.view] end,
        read = function(route)
            local view = ns.SellingUI
            route.item, route.extra = view.props.id, {view = view.view}
        end,
        write = function(route)
            local view = ns.SellingUI
            view.view, view.confirm = route.extra.view == "owned" and "owned" or "bags", nil
            view:SetProps({id = route.item})
        end,
    },
}
function UI.Route()
    local section = UI.section
    local route = {section = section, offset = 0}
    if section == "processing" then route.sub = UI.processKind
    elseif UI.IsProfession(section) then route.sub = UI.professionModes[section] or "craft"
    elseif section == "seasonal" then route.sub = ns.SeasonalUI.props.event end
    local view = VIEWS[viewOf(section, route.sub) or ""]
    if view then
        if view.read then view.read(route) end
        local scroll = view.scroll()
        route.offset = scroll and scroll.offset or 0
    end
    return route
end
function UI.HistoryLocked()
    return UI.Busy()
end
function UI.Go(route)
    if not UI.frame or not route then return false end
    local section = route.section
    if section == "processing" then UI.processKind = route.sub
    elseif UI.IsProfession(section) then UI.professionModes[section] = route.sub
    elseif section == "seasonal" and route.sub then ns.SeasonalUI.props.event = route.sub end
    UI:Switch(section)
    local view = VIEWS[viewOf(section, route.sub) or ""]
    if view then
        if view.write then view.write(route) end
        local scroll = view.scroll()
        if scroll then scroll:SetOffset(route.offset or 0) end
    end
    UI.RenderHistory()
    return true
end
local function samePlace(a, b)
    return a.section == b.section and a.sub == b.sub and a.item == b.item
end
function UI.Navigate(fn)
    if UI.navigating or not UI.history then return fn() end
    local H = UI.history
    H.entries[H.index] = UI.Route()
    UI.navigating = true
    local ok, err = pcall(fn)
    UI.navigating = nil
    if not ok then error(err, 0) end
    local route = UI.Route()
    if samePlace(H.entries[H.index], route) then H.entries[H.index] = route
    else
        for i = #H.entries, H.index + 1, -1 do H.entries[i] = nil end
        H.entries[#H.entries + 1] = route
        if #H.entries > HISTORY then table.remove(H.entries, 1) end
        H.index = #H.entries
    end
    UI.RenderHistory()
end
local function closeOverlay(step)
    local K, paths = ns.TradeKit, ns.PathWindow
    local top = K.TopOverlay()
    if not top then return false end
    if step < 0 and paths and top == paths.frame and #top.view.history > 0 then
        top.view:Back()
        return true
    end
    return K.CloseTop()
end
function UI.Step(step)
    if not UI.frame or not UI.frame:IsVisible() or not UI.history then return false end
    if closeOverlay(step) then return false end
    local H = UI.history
    local target = H.entries[H.index + step]
    if not target or UI.HistoryLocked() then return false end
    H.entries[H.index] = UI.Route()
    H.index = H.index + step
    return UI.Go(target)
end
function UI.Back() return UI.Step(-1) end
function UI.Forward() return UI.Step(1) end
function UI.RouteLabel(route)
    local section, label = route.section, nil
    if section == "processing" then
        for _, kind in ipairs(PROCESS_KINDS) do if kind.key == route.sub then label = ns.T(kind.labelKey) end end
    elseif section == "jewelry" then label = ns.T("jewelrySection")
    elseif ns.craftCatalogs[section] then label = ns.T(ns.craftCatalogs[section].labelKey)
    elseif ns.Obtain and ns.Obtain.gatherKeys[section] then label = ns.T(ns.Obtain.gatherKeys[section])
    elseif UI.nav[section] then label = UI.nav[section]:GetText() end
    label = label or section
    if type(route.item) == "number" then label = label .. ": " .. (ns.Markets.Name(route.item) or "") end
    return label
end
function UI.HistoryTip(step)
    if UI.HistoryLocked() then return ns.T("navHistoryBusy") end
    local H = UI.history
    local route = H and H.entries[H.index + step]
    if not route then return ns.T(step < 0 and "navBackEmpty" or "navForwardEmpty") end
    return ns.T("navHistoryTo", UI.RouteLabel(route)) .. "\n\n" .. ns.T("navHistoryKeys")
end
local function setEnabled(button, enabled)
    if enabled == not button.btnDisabled then return end
    if enabled then button:Enable() else button:Disable() end
end
function UI.RenderHistory()
    local H = UI.history
    if not UI.historyBack or not H then return end
    local locked = UI.HistoryLocked()
    setEnabled(UI.historyBack, not locked and H.index > 1)
    setEnabled(UI.historyForward, not locked and H.index < #H.entries)
end
local SIDE_BUTTONS = {Button4 = -1, Button5 = 1}
function UI.PollSideButtons()
    if not IsMouseButtonDown or not UI.frame then return end
    UI.sideDown = UI.sideDown or {}
    for button, step in pairs(SIDE_BUTTONS) do
        local down = IsMouseButtonDown(button) and true or false
        if down and not UI.sideDown[button] and MouseIsOver(UI.frame) then UI.Step(step) end
        UI.sideDown[button] = down
    end
end
BINDING_HEADER_MANACODE = ns.T("bindHeader")
BINDING_NAME_MANACODE_BACK = ns.T("navBack")
BINDING_NAME_MANACODE_FORWARD = ns.T("navForward")
function ManaCodeAuctionScan_Back() UI.Back() end
function ManaCodeAuctionScan_Forward() UI.Forward() end
function UI:Render()
    self:LayoutNavigation()
    UI.RenderStatus()
    for _, view in ipairs({ns.FamilyUI, ns.AlchemyUI, ns.ReagentsUI, ns.GatheringUI, ns.ResaleUI, ns.DisenchantUI,
        ns.CollectionsUI, ns.SeasonalUI, ns.HiddenUI, ns.RecycleUI, ns.ProspectUI, ns.BargainUI, ns.BidsUI}) do
        if view and view.frame then view:Render() end
    end
    if ns.NpcUI and ns.NpcUI.frame and UI.section == "npc" then ns.NpcUI:Render() end
    if ns.SellingUI and ns.SellingUI.frame and UI.section == "sell" then ns.SellingUI:Render() end
    if self.accountingView and self.accounting:IsVisible() then self.accountingView:Render() end
    if ns.PathWindow then ns.PathWindow.Refresh() end
    if ns.MarketWindow then ns.MarketWindow.Refresh() end
end
local NAV_STEPS = {
    {label = true, gap = 2, group = 17, wide = true},
    {label = false, gap = 2, group = 17, wide = true},
    {label = false, gap = 0, group = 9, wide = true},
    {label = false, gap = 0, group = 9, wide = false},
    {label = false, gap = 0, group = 9, wide = false, more = true},
}
function UI:NavWidth(step, menuWidth)
    local width = step.label and (14 + self.marketsLabel:GetWidth() + 4) or 10
    for i, tab in ipairs(self.navLeft) do
        width = width + (tab == self.professionMenu.frame and menuWidth or tab:GetWidth()) + (i > 1 and step.gap or 0)
    end
    width = width + step.group
    if step.more then width = width + self.moreMenu.frame:GetWidth()
    else for i, tab in ipairs(self.navGroup) do width = width + tab:GetWidth() + (i > 1 and step.gap or 0) end end
    return width + 17 + self.nav.bids:GetWidth() + 2 + self.nav.buy:GetWidth() + 2 + self.nav.sell:GetWidth() + 12
end
function UI:LayoutNavigation()
    if not self.frame or not self.content then return end
    local K, menu = ns.TradeKit, self.professionMenu.frame
    local process = self.processMenu.frame
    local processWidth = math.ceil((process.text:GetStringWidth() or 60) + 31)
    process:SetWidth(processWidth)
    local fit = math.ceil((menu.text:GetStringWidth() or 60) + 31)
    local available, chosen, menuWidth = self.frame:GetWidth() or 996, NAV_STEPS[#NAV_STEPS], fit
    for _, step in ipairs(NAV_STEPS) do
        local width = step.wide and self.menuWide or fit
        if self:NavWidth(step, width) <= available then chosen, menuWidth = step, width; break end
    end
    local key = tostring(chosen.label) .. chosen.gap .. ":" .. chosen.group .. ":" .. menuWidth .. ":" .. processWidth .. ":" .. tostring(chosen.more)
    if self.navLayout == key then return end
    self.navLayout, self.narrowNav = key, not chosen.label
    if chosen.label then self.marketsLabel:Show() else self.marketsLabel:Hide() end
    menu:SetWidth(menuWidth)
    for i, tab in ipairs(self.navLeft) do
        tab:ClearAllPoints()
        if i > 1 then tab:SetPoint("LEFT", self.navLeft[i - 1], "RIGHT", chosen.gap, 0)
        elseif chosen.label then tab:SetPoint("LEFT", self.marketsLabel, "RIGHT", 4, 0)
        else
            local inset = math.floor(((tab:GetWidth() or 0) - (tab.text:GetStringWidth() or 0)) / 2)
            tab:SetPoint("TOPLEFT", self.frame, "TOPLEFT", math.max(2, K.WINDOW_PAD - inset), -34)
        end
    end
    local sell = self.nav.sell
    if sell then
        local inset = math.floor(((sell:GetWidth() or 0) - (sell.text:GetStringWidth() or 0)) / 2)
        sell:ClearAllPoints(); sell:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -math.max(2, K.WINDOW_PAD - inset), -33)
    end
    local last = self.navLeft[#self.navLeft]
    self.navDivider:ClearAllPoints()
    self.navDivider:SetPoint("LEFT", last, "RIGHT", math.floor((chosen.group - 1) / 2), 0)
    local more = self.moreMenu.frame
    more:ClearAllPoints()
    if chosen.more then
        for _, tab in ipairs(self.navGroup) do tab:Hide() end
        more:SetPoint("LEFT", last, "RIGHT", chosen.group, 0); more:Show()
    else
        more:Hide()
        for i, tab in ipairs(self.navGroup) do
            tab:ClearAllPoints()
            tab:SetPoint("LEFT", i > 1 and self.navGroup[i - 1] or last, "RIGHT", i > 1 and chosen.gap or chosen.group, 0)
            tab:Show()
        end
    end
    if K.StyleButton then K.StyleButton(process); K.StyleButton(menu); K.StyleButton(more) end
end
function UI.UpdateMoney()
    if UI.money then UI.money:SetText(ns.TradeKit.Money(GetMoney())) end
end
function UI:BuildChrome(parent, root)
    local K = ns.TradeKit
    local chrome = K.AuctionChrome(parent, root)
    self.title, self.money, self.footerStatus = chrome.title, chrome.money, chrome.status
    self.footerStatusHit = chrome.statusHit
    self.footerLink = chrome.statusLink
    self.footerLink.onPreClick = function()
        local link = self.StatusLink()
        if link and link.preClick then link.preClick() end
    end
    ns.TradeKit.Tooltip(chrome.statusHit, ns.T("tourStatusTitle"), "")
    chrome.statusHit.tipFn = function() return UI.statusFull or "" end
    self.footerStop, self.footerResume, self.footerProgress = chrome.stop, chrome.resume, chrome.progress
    self.barSlot, self.barLabel, self.footerRoot = chrome.actions, chrome.actionsLabel, root
    self.leadSlot, self.leadDivider, self.footerJob = chrome.lead, chrome.leadDivider, chrome.job
    chrome.stop.onClick = UI.StopAll
    chrome.resume.onClick = UI.ResumeScan
    ns.TradeKit.Tooltip(chrome.stop, ns.T("tradeStop"), ns.T("statusStopTip"))
    ns.TradeKit.Tooltip(chrome.resume, ns.T("tradeResume"), ns.T("statusResumeTip"))
    self.footerRescan, self.footerRescanDrop = chrome.rescan, chrome.rescanDrop
    chrome.rescan.onClick = function() ns.Scan.ResumeParked(); UI.Refresh() end
    chrome.rescanDrop.onClick = function() ns.Scan.DropParked(); UI.Refresh() end
    ns.TradeKit.Tooltip(chrome.rescan, ns.T("tradeRescan"), "")
    chrome.rescan.tipFn = function()
        local parked = ns.Scan.Parked()
        if not parked then return "" end
        return ns.T("tradeRescanTip", parked.page, math.max(parked.pages, 1), ns.TradeKit.Ago(time() - parked.at))
    end
    ns.TradeKit.Tooltip(chrome.rescanDrop, ns.T("tradeRescanDrop"), ns.T("tradeRescanDropTip"))
    self.historyBack, self.historyForward = chrome.back, chrome.forward
    chrome.back.onClick, chrome.forward.onClick = UI.Back, UI.Forward
    ns.TradeKit.Tooltip(chrome.back, ns.T("navBack"), "")
    chrome.back.tipFn = function() return UI.HistoryTip(-1) end
    ns.TradeKit.Tooltip(chrome.forward, ns.T("navForward"), "")
    chrome.forward.tipFn = function() return UI.HistoryTip(1) end
    self.settingsButton = ns.TradeKit.Button(root, "", 22, function() ns.SettingsUI.Toggle() end, "control")
    ns.TradeKit.SetGlyph(self.settingsButton, "settings")
    ns.TradeKit.Tooltip(self.settingsButton, ns.T("setButton"), ns.T("setButtonTip"))
    self.settingsButton:SetPoint("RIGHT", chrome.back, "LEFT", -8, 0)
    self.wikiButton = ns.TradeKit.Button(root, ns.T("helpWiki"), 120, function() UI.Help("wiki") end, "control")
    ns.TradeKit.FitButton(self.wikiButton, 22)
    ns.TradeKit.Tooltip(self.wikiButton, ns.T("helpWiki"), ns.T("helpWikiTip"))
    self.themeButton = ns.TradeKit.ThemeButton(root)
    self.themeButton:SetPoint("RIGHT", self.settingsButton, "LEFT", -4, 0)
    self.wikiButton:SetPoint("RIGHT", self.themeButton, "LEFT", -4, 0)
    self.tourButton = ns.TradeKit.Button(root, ns.T("helpTour"), 80, function() UI.Help("tour") end, "control")
    ns.TradeKit.FitButton(self.tourButton, 22)
    ns.TradeKit.Tooltip(self.tourButton, ns.T("helpTour"), ns.T("helpTourTip"))
    self.fullScanButton = ns.TradeKit.Button(root, ns.T("tradeFullScan"), 120, function() UI.ScanMarket("all") end, "scan")
    ns.TradeKit.FitButton(self.fullScanButton, 22)
    ns.TradeKit.Tooltip(self.fullScanButton, ns.T("tradeFullScan"), ns.T("tradeFullScanTip"))
    self.tourButton:SetPoint("RIGHT", self.wikiButton, "LEFT", -4, 0)
    self.fullScanButton:SetPoint("RIGHT", self.tourButton, "LEFT", -16, 0)
    self.footerRule = chrome.footerRule
    self.viewControls = K.ViewControls(root, function() ns.About.Open(root) end)
    chrome.title:SetHeight(22); chrome.title:SetJustifyV("MIDDLE")
    chrome.title:SetWordWrap(false)
    chrome.title:SetPoint("TOPLEFT", root, "TOPLEFT", K.WINDOW_PAD, -6)
    self.viewControls:SetPoint("LEFT", chrome.title, "RIGHT", 8, 0)
    self:FitTitle()
    root:SetScript("OnUpdate", function(_, elapsed)
        UI.statusTick = (UI.statusTick or 0) + elapsed
        UI.footerProgress:Tick(elapsed)
        UI.PollSideButtons()
        UI.PollTour()
        if UI.statusTick >= 0.25 then UI.statusTick = 0; UI.RenderStatus() end
    end)
    self.background = rawget(root, "tradeBase")
    local events = ns.NewFrame("Frame", nil, root)
    ns.Listen(events, "PLAYER_MONEY")
    events:SetScript("OnEvent", UI.UpdateMoney)
    root:SetScript("OnShow", UI.UpdateMoney)
end
function UI:FitTitle()
    self.title:SetWidth(300)
    self.title:SetWidth(math.ceil(self.title:GetStringWidth() or 160) + 2)
end
function UI:NavButton(root, label, section)
    local K = ns.TradeKit
    local b = K.Button(root, label, 80, function() self:ShowSection(section) end, "nav")
    K.FitButton(b, 18)
    self.nav[section] = b
    return b
end
function UI:Container(parent)
    local frame = ns.NewFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    return frame
end
function UI:SectionBody(container, rows)
    local body = ns.NewFrame("Frame", nil, container)
    local K = ns.TradeKit
    body:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -rows * K.FontHeight(K.SectionHead.HEIGHT))
    self.sectionBodies = self.sectionBodies or {}
    self.sectionBodies[body] = rows
    body:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    return body
end
function UI:BuildSeasonal(content)
    local K = ns.TradeKit
    self.seasonal = self:Container(content)
    self.seasonSegments, self.seasonButtons = {}, {}
    local rows = {{}, {}}
    local split = math.ceil(#ns.seasonalEvents / 2)
    for i, event in ipairs(ns.seasonalEvents) do
        local row = rows[i <= split and 1 or 2]
        row[#row + 1] = {key = event.key, label = ns.T(event.shortKey)}
    end
    for i, entries in ipairs(rows) do
        local segment = K.Segment(self.seasonal, entries, UI.OpenSeasonal)
        segment.frame:SetPoint("TOPLEFT", self.seasonal, "TOPLEFT", 8, -2 - (i - 1) * K.FontHeight(K.SectionHead.HEIGHT))
        self.seasonSegments[i] = segment
        for key, button in pairs(segment.buttons) do self.seasonButtons[key] = button end
    end
    ns.SeasonalUI:New(self:SectionBody(self.seasonal, #rows))
    for _, event in ipairs(ns.seasonalEvents) do
        local button = self.seasonButtons[event.key]
        if #event.items > 0 then K.Tooltip(button, ns.T(event.labelKey), ns.Seasonal.Tip(event))
        else
            button:Disable()
            K.DisabledTip(button, ns.T(event.labelKey), ns.Seasonal.Tip(event) .. "\n\n" .. ns.T("seasonNoAuctionItems"))
        end
    end
end
function UI:BuildProfessions(content)
    local K = ns.TradeKit
    self.professionView = self:Container(content)
    local entries = {}
    for _, mode in ipairs(PROFESSION_MODES) do entries[#entries + 1] = {key = mode.key, label = ns.T(mode.labelKey)} end
    self.professionBody = self:SectionBody(self.professionView, 1)
    self.modeSegment = K.Segment(self.professionView, entries, function(mode)
        UI.SetProfessionMode(UI.section, mode)
    end)
    self.professionHead = K.SectionHead:New(self.professionView)
end
function UI:ModeView(key)
    local entry = MODE_VIEWS[key]
    if not self[entry.field] then
        local view = ns[entry.module]:New(self.professionBody)
        self[entry.field] = view.frame
    end
    return self[entry.field]
end
local SECTIONS = {
    buy = function(self, content)
        self.buyView = ns.ShoppingUI:New(content)
        return self.buyView.frame
    end,
    sell = function(self, content)
        self.sellView = ns.SellingUI:New(content).frame
        return self.sellView
    end,
    processing = function(self, content)
        self.processing = self:Container(content)
        return self.processing
    end,
    profession = function(self, content)
        self:BuildProfessions(content)
        return self.professionView
    end,
    reagents = function(self, content)
        self.reagents = ns.ReagentsUI:New(content).frame
        return self.reagents
    end,
    collections = function(self, content)
        self.collections = ns.CollectionsUI:New(content).frame
        return self.collections
    end,
    seasonal = function(self, content)
        self:BuildSeasonal(content)
        return self.seasonal
    end,
    npc = function(self, content)
        self.npcView = self:Container(content)
        if ns.NpcUI then ns.NpcUI:New(self.npcView) end
        return self.npcView
    end,
    hidden = function(self, content)
        self.hiddenView = ns.HiddenUI:New(content).frame
        return self.hiddenView
    end,
    bargain = function(self, content)
        self.bargain = self:Container(content)
        if ns.BargainUI then ns.BargainUI:New(self.bargain)
        else
            self.bargainStub = ns.TradeKit.Label(self.bargain, ns.T("bargainStub"), 0, 0, 400, "secondary")
            self.bargainStub:ClearAllPoints()
            self.bargainStub:SetPoint("CENTER", self.bargain, "CENTER", 0, 0)
            self.bargainStub:SetJustifyH("CENTER")
        end
        return self.bargain
    end,
    bids = function(self, content)
        self.bidsView = self:Container(content)
        ns.BidsUI:New(self.bidsView)
        return self.bidsView
    end,
    accounting = function(self, content)
        self.accounting = self:Container(content)
        self.accountingView = ns.AccountingUI:New(self.accounting)
        self.accountingView.barred = true
        return self.accounting
    end,
}
function UI.SectionKey(section)
    return SECTIONS[section] and section or "profession"
end
function UI:Section(key)
    local frame = self.sections[key]
    if not frame then
        frame = SECTIONS[key](self, self.content)
        self.sections[key] = frame
    end
    return frame
end
function UI:New(parent)
    if not UI.Ready() then return nil end
    if self.host then return self end
    local root = ns.NewFrame("Frame", nil, parent)
    self.host, self.parent = root, parent
    root:Hide()
    self.tab = ns.AuctionPage.Install(root)
    ns.AuctionWindow.Install(parent)
    return self
end
function UI.ProfessionEntries()
    local keys = {{"jewelry", "jewelrySection"}}
    for _, key in ipairs(ns.Crafting.order) do
        if ns.craftCatalogs[key] and key ~= "jewelry" then keys[#keys + 1] = {key, ns.craftCatalogs[key].labelKey} end
    end
    for _, key in ipairs({"herbalism", "skinning", "fishing"}) do keys[#keys + 1] = {key, ns.gatheringCatalogs[key].labelKey} end
    local owners, mine, learned, rest = ns.Recipes.Professions(), {}, {}, {}
    for _, pair in ipairs(keys) do
        local label = ns.T(pair[2])
        local entry, who = {key = pair[1], label = label, icon = ns.TradeKit.ProfessionIcon(pair[1])}, owners[label]
        if who then
            local names, lines = {}, {}
            for i, owner in ipairs(who) do
                names[i] = owner.rank and ns.T("profOwnerRank", owner.name, owner.rank) or owner.name
                lines[i] = owner.rank and ns.T("profOwnerLine", owner.name, owner.rank) or owner.name
            end
            entry.note = table.concat(names, ", ")
            entry.tip = ns.T("profOwnersTip") .. "\n\n" .. table.concat(lines, "\n")
            local group = who[1].me and mine or learned
            group[#group + 1] = entry
        else rest[#rest + 1] = entry end
    end
    local secondary = {cooking = true, firstaid = true, fishing = true}
    local function byLabel(a, b)
        if (secondary[a.key] or false) ~= (secondary[b.key] or false) then return not secondary[a.key] end
        return a.label < b.label
    end
    local entries = {}
    for _, group in ipairs({mine, learned, rest}) do
        table.sort(group, byLabel)
        if #group > 0 then
            if #entries > 0 then entries[#entries + 1] = {divider = true} end
            for _, entry in ipairs(group) do entries[#entries + 1] = entry end
        end
    end
    return entries
end
function UI.Open()
    if not UI.host then return end
    if not UI.frame then UI:Build() end
    UI.Refresh()
    if unseenTour() then UI.tourPending = true end
end
function UI:Build()
    if self.frame then return self end
    local K = ns.TradeKit
    local root, parent = self.host, self.parent
    self.frame = root
    self:BuildChrome(parent, root)
    self.marketsLabel = K.Label(root, ns.T("tradeMarkets"), ns.TradeKit.WINDOW_PAD, -33, 60)
    K.BindFont(self.marketsLabel, "rowTitle")
    K.SetFontHeight(self.marketsLabel, 26); self.marketsLabel:SetJustifyV("MIDDLE")
    self.marketsLabel:SetWidth(math.ceil((self.marketsLabel:GetStringWidth() or 40) + 2))
    self.marketsLabel:SetTextColor(unpack(K.theme.secondary))
    self.processMenu = K.Menu(root, UI.ProcessEntries(), UI.OpenProcessing)
    self.processMenu.cover:HookScript("OnShow", function() self.processMenu:SetEntries(UI.ProcessEntries()) end)
    local processingTab = self.processMenu.frame
    processingTab:SetText(ns.T("recycleNav"))
    self.nav.processing = K.MakeNav(processingTab)
    K.HoverMenu(self.processMenu)
    processingTab:SetPoint("LEFT", self.marketsLabel, "RIGHT", 4, 0)
    self.professionMenu = K.Menu(root, UI.ProfessionEntries(), UI.OpenProfession)
    self.professionMenu.cover:HookScript("OnShow", function()
        self.professionMenu:SetEntries(UI.ProfessionEntries())
    end)
    K.MakeNav(self.professionMenu.frame)
    K.HoverMenu(self.professionMenu)
    local menu, widest = self.professionMenu.frame, 0
    for _, entry in ipairs(UI.ProfessionEntries()) do
        if entry.label then menu.text:SetText(entry.label); widest = math.max(widest, menu.text:GetStringWidth() or 60) end
    end
    menu.text:SetText(ns.T("craftProfessions")); widest = math.max(widest, menu.text:GetStringWidth() or 60)
    menu:SetText(ns.T("craftProfessions"))
    self.menuWide = math.ceil(widest + 31)
    menu:SetWidth(self.menuWide)
    menu:SetPoint("LEFT", processingTab, "RIGHT", 2, 0)
    local materialsTab = self:NavButton(root, ns.T("navMaterials"), "reagents")
    materialsTab:SetPoint("LEFT", self.professionMenu.frame, "RIGHT", 2, 0)
    local bargainTab = self:NavButton(root, ns.T("navBelowMarket"), "bargain")
    bargainTab:SetPoint("LEFT", materialsTab, "RIGHT", 2, 0)
    local seasonalTab = self:NavButton(root, ns.T("navSeasonal"), "seasonal")
    seasonalTab:SetPoint("LEFT", bargainTab, "RIGHT", 2, 0)
    local lastMarket = seasonalTab
    if ns.NpcUI then
        lastMarket = self:NavButton(root, ns.T("navNpc"), "npc")
        lastMarket:SetPoint("LEFT", seasonalTab, "RIGHT", 2, 0)
    end
    self.navDivider = K.NavDivider(root, lastMarket)
    self:NavButton(root, ns.T("collectionTitle"), "collections"):SetPoint("LEFT", lastMarket, "RIGHT", 17, 0)
    self:NavButton(root, ns.T("hiddenSection"), "hidden"):SetPoint("LEFT", self.nav.collections, "RIGHT", 2, 0)
    self:NavButton(root, ns.T("acNav"), "accounting"):SetPoint("LEFT", self.nav.hidden, "RIGHT", 2, 0)
    self.navLeft = {processingTab, menu, materialsTab, bargainTab, seasonalTab}
    if lastMarket ~= seasonalTab then self.navLeft[#self.navLeft + 1] = lastMarket end
    self.navGroup = {self.nav.collections, self.nav.hidden, self.nav.accounting}
    self.moreMenu = K.Menu(root, NAV_MORE, function(section) self:ShowSection(section) end)
    K.MakeNav(self.moreMenu.frame)
    K.HoverMenu(self.moreMenu)
    local more, moreWide = self.moreMenu.frame, 0
    for _, entry in ipairs(NAV_MORE) do
        more.text:SetText(ns.T(entry.labelKey)); moreWide = math.max(moreWide, more.text:GetStringWidth() or 40)
    end
    more:SetText(ns.T("navMore"))
    more:SetWidth(math.ceil(moreWide + 31))
    K.Tooltip(more, ns.T("navMore"), ns.T("navMoreTip"))
    more:Hide()
    local sell = self:NavButton(root, ns.T("navSell"), "sell")
    sell:SetPoint("TOPRIGHT", root, "TOPRIGHT", -12, -33)
    local purchase = self:NavButton(root, ns.T("buySection"), "buy")
    purchase:SetPoint("RIGHT", sell, "LEFT", -2, 0)
    local bids = self:NavButton(root, ns.T("bidsTitle"), "bids")
    bids:SetPoint("RIGHT", purchase, "LEFT", -2, 0)
    K.NavDivider(root, bids, true)
    K.Tooltip(bids, ns.T("bidsTitle"), ns.T("navBidsTip"))
    K.Tooltip(purchase, ns.T("buySection"), ns.T("navBuyTip"))
    K.Tooltip(sell, ns.T("navSell"), ns.T("navSellTip"))
    local content = ns.NewFrame("Frame", nil, root)
    self.content = content
    local side = K.WINDOW_PAD - K.Table.EDGE
    content:SetPoint("TOPLEFT", root, "TOPLEFT", side, -64)
    content:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -side, K.FontHeight(32))
    self:LayoutNavigation()
    self:Switch("buy")
    UI.history = {entries = {UI.Route()}, index = 1}
    UI.RenderHistory()
    K.OnFont(function()
        self.navLayout = nil
        self:FitTitle()
        K.PlaceFooterRule(self.footerRule, root)
        content:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -side, K.FontHeight(32))
        local sectionHeight = K.FontHeight(K.SectionHead.HEIGHT)
        for body, rows in pairs(self.sectionBodies or {}) do
            body:SetPoint("TOPLEFT", body:GetParent(), "TOPLEFT", 0, -rows * sectionHeight)
        end
        for i, segment in ipairs(self.seasonSegments or {}) do
            segment.frame:SetPoint("TOPLEFT", self.seasonal, "TOPLEFT", 8, -2 - (i - 1) * sectionHeight)
        end
        self.marketsLabel:SetWidth(math.ceil((self.marketsLabel:GetStringWidth() or 40) + 2))
        for _, button in ipairs({self.wikiButton, self.tourButton, self.fullScanButton}) do K.FitButton(button, 22) end
        for _, button in pairs(self.nav) do
            if button ~= self.processMenu.frame then K.FitButton(button, 18) end
        end
        UI.Refresh()
    end)
    root:SetScript("OnSizeChanged", function() self:LayoutNavigation() end)
    return self
end
local events = ns.NewFrame("Frame")
ns.Listen(events, "AUCTION_HOUSE_SHOW")
events:SetScript("OnEvent", function()
    if AuctionFrame then
        if not UI:New(AuctionFrame) then return end
        if PanelTemplates_GetSelectedTab(AuctionFrame) == ns.AuctionPage.index then UI.Open()
        else UI.host:Hide() end
    end
end)
ns.Scan.onComplete = function(scan)
    if ns.Shopping then ns.Shopping.Accept(scan) end
    if ns.Batch then ns.Batch.Accept(scan) end
    UI.Refresh()
end
