local _, ns = ...
local UI = { props = { selected = 1, page = 1 }, rows = {}, nav = {}, sections = {} }
UI.professionModes = {}
UI.processKind = "disenchant"
ns.Trader = UI
local PROCESS_KINDS = {
    {key = "disenchant", labelKey = "procDisenchant", module = "DisenchantUI", field = "disenchant"},
    {key = "prospect", labelKey = "procProspect", module = "ProspectUI", field = "prospect"},
    {key = "mill", labelKey = "procMill", module = "ProspectUI", field = "prospect"},
    {key = "recycle", labelKey = "procRecycle", module = "RecycleUI", field = "recycle"},
}
local MODE_VIEWS = {
    jewelry = {module = "FamilyUI", field = "jewelry"},
    craft = {module = "AlchemyUI", field = "alchemy"},
    resources = {module = "GatheringUI", field = "gathering"},
    resale = {module = "ResaleUI", field = "resale"},
    leveling = {module = "LevelingUI", field = "leveling"},
}
local PROFESSION_MODES = {
    {key = "craft", labelKey = "modeCraft"},
    {key = "resources", labelKey = "modeResources"},
    {key = "leveling", labelKey = "modeLeveling"},
    {key = "resale", labelKey = "modeNpc"},
}
local BAR_HEIGHT = 26
local TOUR_VERSION = 2
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
local TOUR = {
    {titleKey = "tourIntroTitle", textKey = "tourIntro"},
    {titleKey = "tourTabsTitle", textKey = "tourTabs", spot = function()
        local list = tourFrames(UI.professionMenu.frame)
        for _, button in pairs(UI.nav) do list[#list + 1] = button end
        return list
    end},
    {titleKey = "tourProcessingTitle", textKey = "tourProcessing", section = "processing", tab = navTab("processing"),
        spot = function() return tourFrames(UI.processSegment and UI.processSegment.frame) end},
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
        spot = function() return tourFrames(UI.seasonSegment and UI.seasonSegment.frame) end},
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
    {titleKey = "tourHelpTitle", textKey = "tourHelp", spot = function() return tourFrames(UI.tourButton, UI.wikiButton) end},
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
function UI.TourSteps()
    local steps = {}
    for _, entry in ipairs(TOUR) do
        if not entry.needs or UI.nav[entry.needs] then steps[#steps + 1] = tourStep(entry) end
    end
    return steps
end
function UI.StartTour()
    local K = ns.TradeKit
    if not UI.frame or K.Tour.running then return false end
    UI.tourPending = nil
    UI.tour = {route = UI.Route(), busy = UI.Busy()}
    ns.Store.DB().tourSeen = TOUR_VERSION
    return K.Tour.Start(UI.frame, UI.TourSteps(), UI.EndTour)
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
    UI.Go(tour.route)
end
function UI.PollTour()
    if not UI.tourPending or not UI.frame or not UI.frame:GetLeft() then return false end
    UI.tourPending = nil
    if (ns.Store.DB().tourSeen or 0) >= TOUR_VERSION or UI.Busy() then return false end
    return UI.StartTour()
end
local KIT_PARTS = {"theme", "Money", "Button", "Tooltip", "ItemChoice", "Menu", "Scroller", "MarketColumns",
    "MarketRow", "Inspector", "OutcomeList", "BatchPanel", "TimeChart", "Modal", "AuctionChrome", "MinimapButton", "CurrencyChip", "PostForm", "Tour", "Doc", "Palette"}
local function kitReady()
    local K = ns.TradeKit
    if not K then return false end
    for _, key in ipairs(KIT_PARTS) do if K[key] == nil then return false end end
    return true
end
function UI.Ready()
    if kitReady() and ns.AuctionPage and ns.Markets and type(ns.Markets.routes) == "table"
        and ns.Query and ns.Plan and ns.Buy and ns.Shopping and ns.ShoppingUI and ns.Selling and ns.SellingUI
        and ns.Family and ns.FamilyUI and ns.gemFamilies and ns.gemByRaw and ns.gemByItem
        and ns.Alchemy and ns.AlchemyUI and ns.Batch and ns.alchemyRecipes
        and ns.Reagents and ns.ReagentsUI and ns.Resale and ns.ResaleUI and ns.CraftPlan and ns.AuctionWindow
        and ns.Activity and ns.Disenchant and ns.DisenchantUI and ns.MarketBoardUI
        and ns.Collections and ns.CollectionsUI and ns.Hidden and ns.HiddenUI and ns.Recipes
        and ns.seasonalEvents and ns.Seasonal and ns.SeasonalUI and ns.OfferPreview and ns.Leveling and ns.LevelingUI
        and ns.levelingCatalogs and ns.levelingCatalogs.enchanting
        and ns.Accounting and ns.AccountingEvents and ns.AccountingUI
        and ns.Recycle and ns.RecycleUI and ns.recyclePairs and ns.GatheringUI and ns.gatheringCatalogs
        and ns.craftCatalogs.engineering and ns.professionUses then return true end
    if not UI.warned then
        UI.warned = true
        ns.say(ns.T("tradeRestartRequired"))
    end
    return false
end
function UI:SetProps(props)
    self.props = props
    self:Render()
end
function UI.Status(text)
    UI.lastStatus = text
    UI.RenderStatus()
    if ns.MarketBoardUI then ns.MarketBoardUI.Status(text) end
    if ns.PathWindow then ns.PathWindow.Controls() end
    if ns.FamilyUI and ns.FamilyUI.frame then ns.FamilyUI:Controls() end
    if ns.AlchemyUI and ns.AlchemyUI.frame then ns.AlchemyUI:Controls() end
    if ns.ReagentsUI and ns.ReagentsUI.frame then ns.ReagentsUI:Controls() end
    if ns.ResaleUI and ns.ResaleUI.frame then ns.ResaleUI:Controls() end
    if ns.DisenchantUI and ns.DisenchantUI.frame then
        if UI.ViewActive("disenchant") then ns.DisenchantUI:Render() else ns.DisenchantUI:Controls() end
    end
    if ns.CollectionsUI and ns.CollectionsUI.frame and UI.section == "collections" then ns.CollectionsUI:Render() end
    if ns.SeasonalUI and ns.SeasonalUI.frame and UI.section == "seasonal" then ns.SeasonalUI:Render() end
    if ns.NpcUI and ns.NpcUI.frame then ns.NpcUI:Controls() end
    if ns.SellingUI and ns.SellingUI.frame then ns.SellingUI:Controls() end
    if ns.LevelingUI and ns.LevelingUI.frame then
        if UI.ViewActive("leveling") then ns.LevelingUI:Render() else ns.LevelingUI:Controls() end
    end
    if ns.RecycleUI and ns.RecycleUI.frame then
        if UI.ViewActive("recycle") then ns.RecycleUI:Render() else ns.RecycleUI:Controls() end
    end
end
function UI.Busy()
    return ns.Scan.state.phase ~= "idle" or ns.Buy.Active() or ns.Batch.job ~= nil
        or (ns.Disenchant and ns.Disenchant.purchase ~= nil) or (ns.Prospect and ns.Prospect.purchase ~= nil)
        or (ns.Bargain and ns.Bargain.Active and ns.Bargain.Active()) or false
end
function UI.StopAll()
    if ns.Disenchant and ns.Disenchant.purchase then ns.Disenchant.CancelBuy() end
    if ns.Prospect and ns.Prospect.purchase then ns.Prospect.CancelBuy() end
    if ns.Bargain and ns.Bargain.Active and ns.Bargain.Active() then ns.Bargain.Cancel() end
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
        leveling = ns.LevelingUI, hidden = ns.HiddenUI, bargain = ns.BargainUI, sell = ns.SellingUI}
    for key, view in pairs(views) do if view.frame and UI.ViewActive(key) then return view.statusText end end
end
function UI.ActivityText()
    local K, state = ns.TradeKit, ns.Scan.state
    if ns.Buy.Active() then
        local R = ns.Buy.state
        return ns.T("deBuyStage", R.page + 1, R.pages > 0 and tostring(R.pages) or "?", ns.Buy.Left(),
            R.bought, K.Money(R.spent))
    end
    if state.phase == "idle" then
        local parts = {ns.Guard and ns.Guard.Notice()}
        local context = UI.ContextText()
        if context and context ~= "" then parts[#parts + 1] = context end
        if UI.lastStatus then parts[#parts + 1] = UI.lastStatus end
        local parked = ns.Scan.Parked()
        if parked then
            parts[#parts + 1] = ns.T("statusParked", parked.page, math.max(parked.pages, 1), K.Ago(time() - parked.at))
        end
        return table.concat(parts, " | ")
    end
    local text
    local D, view = ns.Disenchant, ns.DisenchantUI
    if D and view and view.frame and D.Progress(view.group) then text = view:ProgressText() end
    local job = ns.Batch.job
    if not text and job and state.scan and state.scan.itemID then
        text = ns.T("statusPrices", math.min(job.index, #job.items), #job.items, ns.Markets.Name(state.scan.itemID),
            state.page + 1, state.pages > 0 and tostring(state.pages) or "?")
        if state.phase == "paused" then text = ns.T("deProgressPaused", text) end
    end
    return text or UI.lastStatus or ns.T("deOtherScan")
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
function UI.RenderStatus()
    if not UI.footerStatus then return end
    UI.footerStatus:SetText(UI.ActivityText())
    local busy = UI.Busy()
    local waiting = ns.Scan.state.phase == "paused" or ns.Buy.state.phase == "ready"
    UI.footerProgress:Set(busy and UI.ActivityShare() or nil, busy and not waiting, busy)
    if busy then UI.footerStop:Show() else UI.footerStop:Hide() end
    if ns.Scan.state.phase == "paused" then UI.footerResume:Show() else UI.footerResume:Hide() end
    local parked = not busy and ns.Scan.Parked()
    if parked then UI.footerRescan:Show(); UI.footerRescanDrop:Show()
    else UI.footerRescan:Hide(); UI.footerRescanDrop:Hide() end
    if busy or parked then UI.footerScan:Hide() else UI.footerScan:Show() end
    UI.RenderHistory()
end
function UI.ScanMarket(mode)
    local started = ns.Scan.Start(mode)
    UI.Refresh()
    return started
end
function UI.ViewActive(view)
    if view == "leveling" then return UI.IsProfession(UI.section) and UI.professionModes[UI.section] == "leveling" end
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
        UI.RenderStatus()
        for _, view in ipairs({ns.FamilyUI, ns.AlchemyUI, ns.ReagentsUI, ns.GatheringUI, ns.ResaleUI, ns.DisenchantUI,
            ns.CollectionsUI, ns.SeasonalUI, ns.NpcUI, ns.SellingUI, ns.HiddenUI, ns.LevelingUI, ns.RecycleUI,
            ns.ProspectUI, ns.BargainUI, UI.accountingView}) do
            if view and view.frame and view.frame:IsVisible() then view:Render() end
        end
        if ns.OfferPreview and ns.OfferPreview.frame and ns.OfferPreview.frame:IsShown() then ns.OfferPreview:Render() end
        if ns.PathWindow then ns.PathWindow.Refresh() end
        if ns.MarketWindow then ns.MarketWindow.Refresh() end
    end
    if ns.ShoppingUI then ns.ShoppingUI:Render() end
end
function UI:ShowSection(section)
    UI.Navigate(function() self:Switch(section) end)
end
function UI:Switch(section)
    if section == "leveling" then
        self.professionModes.enchanting = "leveling"; section = "enchanting"
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
    self[shown.field] = self[shown.field] or ns[shown.module]:New(self.processBody).frame
    self[shown.field]:Show()
    if shown.module == "ProspectUI" then ns.ProspectUI:SetProps({mode = kind}) end
    self.processSegment:Select(kind)
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
    self.seasonSegment:Select(key)
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
    local resources = ns.gatheringCatalogs[profession]
    if resources and not ns.craftCatalogs[profession] and mode == "craft" then mode = "resources" end
    if mode == "leveling" and not ns.levelingCatalogs[profession] then mode = "craft" end
    self.professionModes[profession] = mode
    self.professionView:Show()
    local view = mode == "craft" and not ns.craftCatalogs[profession] and "jewelry" or mode
    for _, entry in pairs(MODE_VIEWS) do
        if self[entry.field] then self[entry.field]:Hide() end
    end
    local frame = self:ModeView(view)
    if view ~= "jewelry" then ns[MODE_VIEWS[view].module]:SetProps({profession = profession}) end
    frame:Show()
    local segment = self.modeSegment
    for _, key in ipairs({"craft", "resources", "resale"}) do
        local enabled = key == "resources" and resources ~= nil or key ~= "resources"
            and (key ~= "craft" or profession == "jewelry" or ns.craftCatalogs[profession] ~= nil)
        if enabled then segment.buttons[key]:Enable() else segment.buttons[key]:Disable() end
    end
    segment:Select(mode)
    local leveling = segment.buttons.leveling
    if ns.levelingCatalogs[profession] then leveling:Enable() else leveling:Disable() end
end
function UI.SetProfessionMode(profession, mode)
    if not UI.IsProfession(profession) then return end
    if mode ~= "craft" and mode ~= "resale" and mode ~= "leveling" and mode ~= "resources" then return end
    if mode == "resources" and not ns.gatheringCatalogs[profession] then return end
    if mode == "craft" and profession ~= "jewelry" and not ns.craftCatalogs[profession] then return end
    if mode == "leveling" and not ns.levelingCatalogs[profession] then return end
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
        UI.professionModes[profession] = "craft"
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
    if not name then ns.say(ns.T("tradeUnknownItem")); return end
    UI.Navigate(function()
        UI:Switch("buy")
        if need then
            if need > 1000 then ns.say(ns.T("levelBuyBatch", need)); need = 1000 end
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
        return sub
    end
    return section
end
local function prospectView()
    return {
        scroll = function() return ns.ProspectUI.scroll end,
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
        scroll = function() return ns.ShoppingUI.choiceScroll end,
        read = function(route)
            local S = ns.Shopping.state
            route.item, route.extra = S.itemID, {need = S.need}
        end,
        write = function(route) if route.item then ns.ShoppingUI:Show(route.item, route.extra.need) end end,
    },
    disenchant = {
        scroll = function() return ns.DisenchantUI.scroll end,
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
        scroll = function() return ns.RecycleUI.scroll end,
        read = function(route) route.item = ns.RecycleUI.props.key end,
        write = function(route) ns.RecycleUI:SetProps({key = route.item}) end,
    },
    craft = {
        scroll = function() return ns.AlchemyUI.scroll end,
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
        scroll = function() return ns.FamilyUI.scroll end,
        read = function(route) route.item = ns.FamilyUI.props.id end,
        write = function(route) ns.FamilyUI:SetProps({id = route.item}) end,
    },
    resale = {
        scroll = function() return ns.ResaleUI.scroll end,
        read = function(route) route.item = ns.ResaleUI.props.id end,
        write = function(route) ns.ResaleUI:SetProps({id = route.item}) end,
    },
    leveling = {scroll = function() return ns.LevelingUI.scroll end},
    reagents = {
        scroll = function() return ns.ReagentsUI.scroll end,
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
        scroll = function() return ns.SeasonalUI.scroll end,
        read = function(route) route.item = ns.SeasonalUI.selected end,
        write = function(route) ns.SeasonalUI.selected = route.item; ns.SeasonalUI:Render() end,
    },
    collections = {
        scroll = function() return ns.CollectionsUI.scroll end,
        read = function(route) route.item = ns.CollectionsUI.selected end,
        write = function(route) ns.CollectionsUI.selected = route.item; ns.CollectionsUI:Render() end,
    },
    hidden = {
        scroll = function() return ns.HiddenUI.scroll end,
        read = function(route) route.item = ns.HiddenUI.selected end,
        write = function(route) ns.HiddenUI.selected = route.item; ns.HiddenUI:Render() end,
    },
    bargain = {scroll = function() return ns.BargainUI and ns.BargainUI.scroll end},
    npc = {
        scroll = function() return ns.NpcUI.scroll end,
        read = function(route)
            local p = ns.NpcUI.props
            route.item, route.extra = p.id, {segment = p.segment}
        end,
        write = function(route) ns.NpcUI:SetProps({segment = route.extra.segment, id = route.item}) end,
    },
    sell = {
        scroll = function() return ns.SellingUI.scroll end,
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
        ns.CollectionsUI, ns.SeasonalUI, ns.HiddenUI, ns.LevelingUI, ns.RecycleUI, ns.ProspectUI, ns.BargainUI}) do
        if view and view.frame then view:Render() end
    end
    if ns.NpcUI and ns.NpcUI.frame and UI.section == "npc" then ns.NpcUI:Render() end
    if ns.SellingUI and ns.SellingUI.frame and UI.section == "sell" then ns.SellingUI:Render() end
    if self.accountingView and self.accounting:IsVisible() then self.accountingView:Render() end
    if ns.OfferPreview and ns.OfferPreview.frame and ns.OfferPreview.frame:IsShown() then ns.OfferPreview:Render() end
    if ns.PathWindow then ns.PathWindow.Refresh() end
    if ns.MarketWindow then ns.MarketWindow.Refresh() end
end
local NAV_STEPS = {
    {label = true, gap = 2, group = 17, wide = true},
    {label = false, gap = 2, group = 17, wide = true},
    {label = false, gap = 0, group = 9, wide = true},
    {label = false, gap = 0, group = 9, wide = false},
}
function UI:NavWidth(step, menuWidth)
    local width = step.label and (14 + self.marketsLabel:GetWidth() + 4) or 10
    for i, tab in ipairs(self.navLeft) do
        width = width + (tab == self.professionMenu.frame and menuWidth or tab:GetWidth()) + (i > 1 and step.gap or 0)
    end
    width = width + step.group
    for i, tab in ipairs(self.navGroup) do width = width + tab:GetWidth() + (i > 1 and step.gap or 0) end
    return width + 17 + self.nav.buy:GetWidth() + 2 + self.nav.sell:GetWidth() + 12
end
function UI:LayoutNavigation()
    if not self.frame or not self.content then return end
    local K, menu = ns.TradeKit, self.professionMenu.frame
    local fit = math.ceil((menu.text:GetStringWidth() or 60) + 31)
    local available, chosen, menuWidth = self.frame:GetWidth() or 996, NAV_STEPS[#NAV_STEPS], fit
    for _, step in ipairs(NAV_STEPS) do
        local width = step.wide and self.menuWide or fit
        if self:NavWidth(step, width) <= available then chosen, menuWidth = step, width; break end
    end
    local key = tostring(chosen.label) .. chosen.gap .. ":" .. chosen.group .. ":" .. menuWidth
    if self.navLayout == key then return end
    self.navLayout, self.narrowNav = key, not chosen.label
    if chosen.label then self.marketsLabel:Show() else self.marketsLabel:Hide() end
    menu:SetWidth(menuWidth)
    for i, tab in ipairs(self.navLeft) do
        tab:ClearAllPoints()
        if i > 1 then tab:SetPoint("LEFT", self.navLeft[i - 1], "RIGHT", chosen.gap, 0)
        elseif chosen.label then tab:SetPoint("LEFT", self.marketsLabel, "RIGHT", 4, 0)
        else tab:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -34) end
    end
    local last = self.navLeft[#self.navLeft]
    self.navDivider:ClearAllPoints()
    self.navDivider:SetPoint("LEFT", last, "RIGHT", math.floor((chosen.group - 1) / 2), 0)
    for i, tab in ipairs(self.navGroup) do
        tab:ClearAllPoints()
        tab:SetPoint("LEFT", i > 1 and self.navGroup[i - 1] or last, "RIGHT", i > 1 and chosen.gap or chosen.group, 0)
    end
    if K.StyleButton then K.StyleButton(menu) end
end
function UI.UpdateMoney()
    if UI.money then UI.money:SetText(ns.TradeKit.Money(GetMoney())) end
end
function UI:BuildChrome(parent, root)
    local chrome = ns.TradeKit.AuctionChrome(parent, root)
    self.title, self.money, self.footerStatus = chrome.title, chrome.money, chrome.status
    self.footerStop, self.footerResume, self.footerProgress = chrome.stop, chrome.resume, chrome.progress
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
    self.footerScan = chrome.scan
    chrome.scan.onClick = function() UI.ScanMarket("pages") end
    ns.TradeKit.Tooltip(chrome.scan, ns.T("tradeScan"), ns.T("tradeScanTip"))
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
    self.wikiButton:SetPoint("RIGHT", self.settingsButton, "LEFT", -4, 0)
    self.tourButton = ns.TradeKit.Button(root, ns.T("helpTour"), 80, function() UI.Help("tour") end, "control")
    ns.TradeKit.FitButton(self.tourButton, 22)
    ns.TradeKit.Tooltip(self.tourButton, ns.T("helpTour"), ns.T("helpTourTip"))
    self.tourButton:SetPoint("RIGHT", self.wikiButton, "LEFT", -4, 0)
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
function UI:SegmentBar(container, entries, choose)
    local segment = ns.TradeKit.Segment(container, entries, choose)
    segment.frame:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -2)
    local body = ns.NewFrame("Frame", nil, container)
    body:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -BAR_HEIGHT)
    body:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    return segment, body
end
function UI:BuildProcessing(content)
    local K = ns.TradeKit
    self.processing = self:Container(content)
    local entries = {}
    for _, kind in ipairs(PROCESS_KINDS) do entries[#entries + 1] = {key = kind.key, label = ns.T(kind.labelKey)} end
    self.processSegment, self.processBody = self:SegmentBar(self.processing, entries, UI.OpenProcessing)
    for _, kind in ipairs(PROCESS_KINDS) do
        if not UI.ProcessAvailable(kind.key) then
            local button = self.processSegment.buttons[kind.key]
            button:Disable()
            K.DisabledTip(button, ns.T(kind.labelKey), ns.T("procLater"))
        end
    end
end
function UI:BuildSeasonal(content)
    local K = ns.TradeKit
    self.seasonal = self:Container(content)
    local entries = {}
    for _, event in ipairs(ns.seasonalEvents) do entries[#entries + 1] = {key = event.key, label = ns.T(event.shortKey)} end
    local body
    self.seasonSegment, body = self:SegmentBar(self.seasonal, entries, UI.OpenSeasonal)
    ns.SeasonalUI:New(body)
    for _, event in ipairs(ns.seasonalEvents) do
        local button = self.seasonSegment.buttons[event.key]
        if #event.items > 0 then K.Tooltip(button, ns.T(event.labelKey), ns.T(event.timingKey))
        else
            button:Disable()
            K.DisabledTip(button, ns.T(event.labelKey), ns.T(event.timingKey) .. "\n\n" .. ns.T("seasonNoAuctionItems"))
        end
    end
end
function UI:BuildProfessions(content)
    local K = ns.TradeKit
    self.professionView = self:Container(content)
    local entries = {}
    for _, mode in ipairs(PROFESSION_MODES) do entries[#entries + 1] = {key = mode.key, label = ns.T(mode.labelKey)} end
    self.modeSegment, self.professionBody = self:SegmentBar(self.professionView, entries, function(mode)
        UI.SetProfessionMode(UI.section, mode)
    end)
    K.DisabledTip(self.modeSegment.buttons.leveling, ns.T("modeLeveling"), ns.T("modeNoLeveling"))
end
function UI:ModeView(key)
    local entry = MODE_VIEWS[key]
    if not self[entry.field] then
        local view = ns[entry.module]:New(self.professionBody)
        self[entry.field] = view.frame
        if key == "jewelry" then self.rows = view.rows end
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
        self:BuildProcessing(content)
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
    accounting = function(self, content)
        self.accounting = self:Container(content)
        self.accountingView = ns.AccountingUI:New(self.accounting)
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
        if ns.craftCatalogs[key] then keys[#keys + 1] = {key, ns.craftCatalogs[key].labelKey} end
    end
    for _, key in ipairs({"herbalism", "skinning", "fishing"}) do keys[#keys + 1] = {key, ns.gatheringCatalogs[key].labelKey} end
    local owners, learned, rest = ns.Recipes.Professions(), {}, {}
    for _, pair in ipairs(keys) do
        local label = ns.T(pair[2])
        local entry, who = {key = pair[1], label = label}, owners[label]
        if who then
            local names, lines = {}, {}
            for i, owner in ipairs(who) do
                names[i] = owner.rank and ns.T("profOwnerRank", owner.name, owner.rank) or owner.name
                lines[i] = owner.rank and ns.T("profOwnerLine", owner.name, owner.rank) or owner.name
            end
            entry.note = table.concat(names, ", ")
            entry.tip = ns.T("profOwnersTip") .. "\n\n" .. table.concat(lines, "\n")
            learned[#learned + 1] = entry
        else rest[#rest + 1] = entry end
    end
    local function byLabel(a, b) return a.label < b.label end
    table.sort(learned, byLabel); table.sort(rest, byLabel)
    if #learned > 0 and #rest > 0 then learned[#learned + 1] = {divider = true} end
    for _, entry in ipairs(rest) do learned[#learned + 1] = entry end
    return learned
end
function UI.Open()
    if not UI.host then return end
    if not UI.frame then UI:Build() end
    UI.Refresh()
    if (ns.Store.DB().tourSeen or 0) < TOUR_VERSION then UI.tourPending = true end
end
function UI:Build()
    if self.frame then return self end
    local K = ns.TradeKit
    local root, parent = self.host, self.parent
    self.frame = root
    self:BuildChrome(parent, root)
    self.marketsLabel = K.Label(root, ns.T("tradeMarkets"), 14, -33, 60)
    self.marketsLabel:SetFontObject(K.Font("ManaCodeNavTitleFont", "GameFontNormal", 14))
    self.marketsLabel:SetHeight(26); self.marketsLabel:SetJustifyV("MIDDLE")
    self.marketsLabel:SetWidth(math.ceil((self.marketsLabel:GetStringWidth() or 40) + 2))
    self.marketsLabel:SetTextColor(unpack(K.theme.secondary))
    local processingTab = self:NavButton(root, ns.T("navProcessing"), "processing")
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
    local sell = self:NavButton(root, ns.T("navSell"), "sell")
    sell:SetPoint("TOPRIGHT", root, "TOPRIGHT", -12, -33)
    local purchase = self:NavButton(root, ns.T("buySection"), "buy")
    purchase:SetPoint("RIGHT", sell, "LEFT", -2, 0)
    K.NavDivider(root, purchase, true)
    K.Tooltip(purchase, ns.T("buySection"), ns.T("navBuyTip"))
    K.Tooltip(sell, ns.T("navSell"), ns.T("navSellTip"))
    local content = ns.NewFrame("Frame", nil, root)
    self.content = content
    content:SetPoint("TOPLEFT", root, "TOPLEFT", 8, -64)
    content:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -8, 32)
    self:LayoutNavigation()
    ns.OfferPreview.New(root)
    self:Switch("buy")
    UI.history = {entries = {UI.Route()}, index = 1}
    UI.RenderHistory()
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
