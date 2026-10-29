local _, ns = ...
local T = {seen = {}, base = 0}
ns.AuctionTooltip = T
T.FOREIGN = {"SetMerchantItem", "SetBuybackItem", "SetMerchantCostItem", "SetAction", "SetSocketGem",
    "SetExistingSocketGem", "SetItemByID"}
T.STOCK = {0, 1, 0.6}
function T.AuctionatorShows()
    return type(gAtr_ScanDB) == "table" and AUCTIONATOR_A_TIPS == 1
end
function T.AuctionatorAt(name)
    local full = tonumber(AUCTIONATOR_LAST_SCAN_TIME) or 0
    return math.max(T.seen[name] or 0, full > T.base and full or 0)
end
function T.AuctionatorCovers(name, q)
    if not name or not T.AuctionatorShows() then return false end
    local price = gAtr_ScanDB[name]
    if type(price) ~= "number" then return false end
    if price == math.floor(q.price + 0.5) then return true end
    local at = T.AuctionatorAt(name)
    return at > 0 and at >= (q.at or 0)
end
function T.Quote(id)
    local q = ns.Markets.Quote(id)
    if not q or q.vendor or not q.price or q.complete == false or (q.units or 0) == 0 then return nil end
    return q
end
function T.Price(tip, q)
    local K = ns.TradeKit
    local gold, text, quiet = K.theme.gold, K.theme.text, K.theme.secondary
    tip:AddDoubleLine(ns.T("tipAuction"), ns.T("tipAuctionUnit", K.Money(q.price)), gold[1], gold[2], gold[3], text[1], text[2], text[3])
    if q.at then
        tip:AddDoubleLine(" ", ns.T("tipAuctionAge", K.Ago(math.max(0, time() - q.at))), text[1], text[2], text[3],
            quiet[1], quiet[2], quiet[3])
    end
end
function T.StockText(h)
    local parts = {}
    if h.bags > 0 then parts[#parts + 1] = ns.T("tipStockBags", h.bags) end
    if h.bank > 0 then parts[#parts + 1] = ns.T("tipStockBank", h.bank) end
    if h.mail > 0 then parts[#parts + 1] = ns.T("tipStockMail", h.mail) end
    return table.concat(parts, ", ")
end
function T.Stock(tip, id)
    if not ns.Inventory or ns.Inventory.TooltipElsewhere() then return false end
    local list, total = ns.Inventory.Holdings(id), 0
    local r, g, b = unpack(T.STOCK)
    for _, h in ipairs(list) do
        tip:AddDoubleLine(h.name, T.StockText(h), r, g, b, r, g, b)
        total = total + h.bags + h.bank + h.mail
    end
    if #list > 1 then tip:AddDoubleLine(ns.T("tipStockTotal"), tostring(total), r, g, b, r, g, b) end
    return #list > 0
end
function T.Add(tip)
    if rawget(tip, "manacodePrice") then return end
    local name, link = tip:GetItem()
    local id = ns.Lot.FromLink(link)
    if not id then return end
    tip.manacodePrice = true
    local drawn = false
    local q = T.Quote(id)
    if q and T.AuctionatorCovers(name, q) then tip.manacodePending = q
    elseif q then T.Price(tip, q); drawn = true end
    if T.Stock(tip, id) then drawn = true end
    if drawn then tip:Show() end
end
function T.Flush(tip)
    local q = rawget(tip, "manacodePending")
    if not q then return end
    tip.manacodePending = nil
    T.Price(tip, q)
    tip:Show()
end
function T.Searched(search)
    if type(search) ~= "table" or type(search.items) ~= "table" then return end
    for _, scan in pairs(search.items) do
        if type(scan) == "table" and type(scan.itemName) == "string" then T.seen[scan.itemName] = time() end
    end
end
function T.HookAuctionator()
    if T.hookedAuctionator then return end
    T.hookedAuctionator = true
    T.base = tonumber(AUCTIONATOR_LAST_SCAN_TIME) or 0
    if type(AtrSearch) == "table" and type(AtrSearch.Finish) == "function" then
        hooksecurefunc(AtrSearch, "Finish", T.Searched)
    end
end
function T.Install(tip, foreign)
    if not tip or rawget(tip, "manacodeHooked") then return end
    tip.manacodeHooked = true
    tip:HookScript("OnTooltipSetItem", T.Add)
    tip:HookScript("OnTooltipCleared", function(self) self.manacodePrice, self.manacodePending = nil, nil end)
    for _, method in ipairs(foreign or {}) do
        if type(tip[method]) == "function" then hooksecurefunc(tip, method, T.Flush) end
    end
end
T.Install(GameTooltip, T.FOREIGN)
T.Install(ItemRefTooltip)
local events = ns.NewFrame("Frame")
ns.Listen(events, "PLAYER_LOGIN")
events:SetScript("OnEvent", T.HookAuctionator)
