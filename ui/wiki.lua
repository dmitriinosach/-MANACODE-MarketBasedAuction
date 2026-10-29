local _, ns = ...
local W = {hosts = {}, selected = "processing"}
ns.MarketWiki = W
local function scanRows()
    return {{key = ns.T("scanKeyClick"), text = ns.T("scanKeySoft")}, {key = ns.T("tourKeyShift"), text = ns.T("scanKeyHard")},
        {key = ns.T("tourKeyCtrl"), text = ns.T("scanKeyMissing")}}
end
local ARTICLES = {
    {key = "processing", title = "tourProcessingTitle", fresh = true, keep = true, own = true},
    {key = "professions", title = "tourProfessionsTitle", fresh = true, keep = true, own = true, math = {"alchemyInfo"}},
    {key = "materials", title = "tourMaterialsTitle", fresh = true, keep = true},
    {key = "bargain", title = "bargainNav", keep = true, own = true, math = {"bargainInfo"},
        rows = function()
            return {{key = ns.T("scanKeyClick"), text = ns.T("wikiKeyBargainSoft")},
                {key = ns.T("tourKeyShift"), text = ns.T("wikiKeyBargainHard")},
                {key = ns.T("tourKeyCtrl"), text = ns.T("scanKeyMissing")}}
        end,
        args = {Prices = function() return ns.Bargain.HISTORY_DAYS, ns.Bargain.HISTORY_MIN end,
            Refresh = function() return ns.Bargain.LIMIT end}},
    {key = "seasonal", title = "tourSeasonalTitle", fresh = true, keep = true},
    {key = "npc", title = "tourNpcTitle", fresh = true, keep = true, math = {"npcInfoTip", "npcCaveat"}},
    {key = "collections", title = "tourCollectionsTitle", fresh = true, keep = true, own = true},
    {key = "hidden", title = "tourHiddenTitle", rows = false, own = true},
    {key = "accounting", title = "tourAccountingTitle", fresh = true, own = true},
    {key = "buy", title = "tourBuyTitle", own = true,
        rows = function() return {{key = ns.T("scanKeyClick"), text = ns.T("wikiKeyBuy")}} end,
        args = {Keep = function() return ns.Shopping.HISTORY, ns.Shopping.HISTORY_DAYS end}},
    {key = "sell", title = "tourSellTitle", fresh = true, keep = true},
}
local function split(text, into)
    local list = into or {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if line:match("%S") then list[#list + 1] = line end
    end
    return list
end
local function text(entry, part)
    local args = entry.args and entry.args[part]
    if args then return ns.T("wiki" .. part .. "_" .. entry.key, args()) end
    return ns.T("wiki" .. part .. "_" .. entry.key)
end
local function find(key)
    for _, entry in ipairs(ARTICLES) do if entry.key == key then return entry end end
end
function W.Article(key)
    local entry = find(key) or ARTICLES[1]
    local sections = {{head = ns.T("wikiHeadAbout"), lines = split(text(entry, "About"))},
        {head = ns.T("wikiHeadPrices"), lines = split(text(entry, "Prices"))}}
    if entry.math then
        local lines = {}
        for _, mathKey in ipairs(entry.math) do split(ns.T(mathKey), lines) end
        sections[#sections + 1] = {head = ns.T("wikiHeadMath"), lines = lines}
    end
    local refresh = split(text(entry, "Refresh"))
    local fresh = entry.fresh and ns.TradeKit.ScanFresh()
    if fresh then refresh[#refresh + 1] = fresh end
    local rows = entry.rows
    if rows == nil then rows = scanRows() elseif rows then rows = rows() else rows = nil end
    sections[#sections + 1] = {head = ns.T("wikiHeadRefresh"), lines = refresh, rows = rows}
    local keep = {}
    if entry.keep then
        local days = ns.Store.RAW_DAYS or 30
        keep[1] = ns.T("wikiKeepScans", days)
        keep[2] = ns.T("wikiKeepFull")
        keep[3] = ns.T("wikiKeepChart", ns.Activity and ns.Activity.limits and ns.Activity.limits.days or days)
    end
    if entry.own then split(text(entry, "Keep"), keep) end
    sections[#sections + 1] = {head = ns.T("wikiHeadKeep"), lines = keep}
    sections[#sections + 1] = {head = ns.T("wikiHeadBest"), lines = split(text(entry, "Best"))}
    return {title = ns.T(entry.title), sections = sections}
end
function W.Entries()
    local list = {}
    for i, entry in ipairs(ARTICLES) do list[i] = {key = entry.key, label = ns.T(entry.title)} end
    return list
end
function W.Open(key)
    local trader = ns.Trader and ns.Trader.frame
    local host = trader and trader:IsVisible() and trader or UIParent
    if not host then return nil end
    local doc = W.hosts[host]
    if not doc then
        doc = ns.TradeKit.Doc:New(host, "ManaCodeMarketWiki" .. (#W.Names() + 1), ns.T("wikiTitle"))
        W.hosts[host] = doc
        doc.dim:HookScript("OnHide", function() W.selected = doc:Current() or W.selected end)
    end
    W.doc = doc
    if key and find(key) then W.selected = key end
    doc.props = {entries = W.Entries(), selected = W.selected, article = W.Article}
    doc:Show()
    return doc
end
function W.Names()
    local list = {}
    for _, doc in pairs(W.hosts) do list[#list + 1] = doc end
    return list
end
function W.Close()
    for _, doc in pairs(W.hosts) do doc:Hide() end
end
function W.IsOpen()
    for _, doc in pairs(W.hosts) do if doc:IsShown() then return true end end
    return false
end
