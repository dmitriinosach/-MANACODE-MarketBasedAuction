local _, ns = ...
local UI = {props = {segment = "trading"}, rows = {}, groups = {}, collapsed = {unsold = true}}
ns.NpcUI = UI
local TOP, BOTTOM, ROW, RIGHT = 56, 40, 29, 310
local function hideKey(id)
    return "npc:" .. id
end
local groupKey = ns.Npc.GroupKey
ns.Hidden.Describe(function(key)
    local id = tonumber(key:match("^npc:(%d+)$"))
    if id then return {name = ns.Markets.Name(id), place = ns.T("navNpc")} end
    local group = key:match("^npcgroup:(.+)$")
    if not group then return nil end
    for _, entry in ipairs(ns.Npc.RecipeGroups()) do
        if group == entry.key then return {name = ns.T(entry.labelKey), place = ns.T("navNpc")} end
    end
    if ns.Npc.currencies[group] then
        return {name = ns.Npc.CurrencyName(group), place = ns.T("navNpc"), icon = ns.Npc.Icon(group)}
    end
    if group == "emblems" then
        return {name = ns.T("npcGroupemblems"), place = ns.T("navNpc"), icon = ns.Npc.Icon(ns.Npc.ladder[1])}
    end
    return {name = ns.T("npcGroup" .. group), place = ns.T("navNpc")}
end)
local function groupSources(segment, key)
    if segment == "currency" and key == "emblems" then
        local ids = {}
        for _, rung in ipairs(ns.Npc.ladder) do
            if not ns.Npc.Off(rung) then
                for _, id in ipairs(groupSources(segment, rung)) do ids[#ids + 1] = id end
            end
        end
        return ids
    end
    local ids, seen = {}, {}
    local function add(id)
        if seen[id] then return end
        seen[id] = true; ids[#ids + 1] = id
        if not ns.Batch.names[id] then ns.Batch.names[id] = ns.Npc.QueryName(id) end
    end
    if segment ~= "currency" then
        local profession = key:match("^recipes:(.+)$")
        local items = profession and ns.Resale.Items(profession) or ns.Npc.Items(key)
        for _, entry in ipairs(items) do
            if ns.Npc.Vendor(entry) and not ns.Hidden.IsGroup(hideKey(entry.raw)) then
                for _, token in ipairs(entry.tokens or {}) do add(token[1]) end
                add(entry.raw)
            end
        end
        return ids
    end
    for _, good in ipairs(ns.Npc.byCurrency[key] or {}) do
        if ns.Npc.Vendor(good) and not ns.Hidden.IsGroup(hideKey(good.raw)) then add(good.raw) end
    end
    local currency = ns.Npc.currencies[key]
    if currency and currency.kind == "item" and #ids > 0 then add(currency.item) end
    return ids
end
local function groupKeys(segment)
    if segment == "recipes" then
        local keys = {}
        for _, group in ipairs(ns.Npc.RecipeGroups()) do keys[#keys + 1] = group.key end
        return keys
    end
    return segment == "trading" and ns.Npc.order or ns.Npc.currencyOrder
end
local function duration(seconds)
    if seconds >= 3600 then return ns.T("npcHours", math.floor(seconds / 3600 + 0.5)) end
    return ns.T("npcMinutes", math.max(1, math.floor(seconds / 60 + 0.5)))
end
local function zoneName(vendor)
    if vendor.zone <= 0 then return ns.T("npcZoneUnknown") end
    if ns.locales.ruRU["npcZone" .. vendor.zone] then return ns.T("npcZone" .. vendor.zone) end
    return ns.T("vendorArea" .. vendor.npc)
end
local function vendorName(vendor)
    if ns.locales.ruRU["npcName" .. vendor.npc] then return ns.T("npcName" .. vendor.npc) end
    return ns.T("vendorNPC" .. vendor.npc)
end
local function place(vendor)
    if not vendor then return ns.T("npcNoVendor") end
    return ns.T("npcVendorAt", vendorName(vendor), zoneName(vendor))
end
local function sellerTip(vendor)
    local zone = zoneName(vendor)
    if not ns.MapPin or not ns.MapPin.Known(vendor.zone) then return ns.T("npcSellerNoMap", zone) end
    return ns.T(vendor.x and "npcSellerTip" or "npcSellerTipZone", zone)
end
local function altsOf(item)
    if not item then return nil end
    local _, alts = ns.Inventory.Stock(item)
    return alts > 0 and alts or nil
end
local function currencyLine(key, need)
    local currency = ns.Npc.currencies[key]
    local line = {need = need, have = (ns.Npc.Available(key)), name = ns.Npc.CurrencyName(key), tex = ns.Npc.Icon(key)}
    if currency and currency.item then line.item, line.alts = currency.item, altsOf(currency.item) end
    return line
end
local function ownedLine(key)
    local currency = ns.Npc.currencies[key]
    local item = currency and currency.item
    return {owned = true, have = ns.Npc.Amount(key), name = ns.Npc.CurrencyName(key), tex = ns.Npc.Icon(key),
        item = item, alts = altsOf(item)}
end
local function tokenLine(token)
    local have, alts = ns.Inventory.Stock(token[1])
    return {need = token[2], have = have, alts = alts > 0 and alts or nil, item = token[1],
        name = ns.Markets.Name(token[1]), tex = select(10, ns.Compat.ItemInfo(token[1]))}
end
local function paymentText(good)
    local pay = ns.Npc.Payment(good.currency, good.count)
    if not pay.total then return ns.T("npcCurrencyUnknown") end
    if pay.short then return ns.T("npcShort", pay.short) end
    if pay.via then return ns.T("npcEnoughVia", pay.pieces, ns.Npc.CurrencyName(pay.via)) end
    local own = math.floor((pay.own or 0) / good.count)
    if own < pay.pieces then return ns.T("npcEnoughOwn", pay.pieces, own) end
    return ns.T("npcEnough", pay.pieces)
end
local function costLines(item)
    if item.good then return {currencyLine(item.good.currency, item.good.count)}, item.good.money end
    local lines = {}
    for _, token in ipairs(item.entry.tokens or {}) do lines[#lines + 1] = tokenLine(token) end
    return lines, item.entry.buy or 0
end
local function stock(vendor)
    if not vendor or vendor.stock == nil then return ns.T("npcStockUnknown") end
    if vendor.stock == 0 then return ns.T("npcStockUnlimited") end
    return ns.T("npcStockLimited", vendor.stock, duration(vendor.restock))
end
local function limit(vendor)
    if not vendor or vendor.stock == nil then return ns.T("npcLimitUnknown") end
    if vendor.stock == 0 then return ns.T("npcLimitNone") end
    return ns.T("npcLimitStock", vendor.stock, duration(vendor.restock))
end
local function verifyText(entry)
    if entry.verify then return ns.T("npcVerify" .. entry.verify) end
    for _, vendor in ipairs(entry.vendors) do
        if vendor.verify then return ns.T("npcVerify" .. vendor.verify) end
    end
    return nil
end
local function tokensText(entry)
    local parts = {}
    for _, token in ipairs(entry.tokens or {}) do parts[#parts + 1] = ns.T("npcToken", ns.Markets.Name(token[1]), token[2]) end
    if entry.buy and entry.buy > 0 then parts[#parts + 1] = ns.TradeKit.Money(entry.buy) end
    return table.concat(parts, ", ")
end
local function viaText(entry)
    return entry.via and ns.T("npcVia", ns.Markets.Name(entry.via)) or nil
end
local function priceText(good)
    local name = ns.Npc.CurrencyName(good.currency)
    if good.money > 0 then return ns.T("npcRowCurrencyMoney", name, good.count, ns.TradeKit.Money(good.money)) end
    return ns.T("npcRowCurrency", name, good.count)
end
function UI:SetProps(props)
    if props.segment and props.segment ~= self.props.segment then
        self.props.id, self.props.good = nil, nil
        if self.scroll then self.scroll.offset = 0 end
    end
    for key, value in pairs(props) do self.props[key] = value end
    self:Render()
end
function UI:AddUnsold(entries, unsold)
    if #unsold == 0 then return end
    unsold = self.sorter:Apply(unsold, self.getters)
    local ids = {}
    for _, item in ipairs(unsold) do ids[#ids + 1] = item.raw end
    entries[#entries + 1] = {group = "unsold", name = ns.T("npcGroupunsold"),
        detail = ns.T("npcUnsoldDetail", #unsold, ns.Npc.UNSOLD_DAYS), tip = ns.T("npcUnsoldTip", ns.Npc.UNSOLD_DAYS),
        sources = function() return ids end}
    if not self.collapsed.unsold then
        for _, item in ipairs(unsold) do entries[#entries + 1] = item end
    end
end
local function summary(items, best)
    local priced, top, units = 0, nil, 0
    for _, item in ipairs(items) do
        local value = best(item)
        if value then priced = priced + 1; top = math.max(top or value, value) end
        if item.quote and item.quote.units then units = units + item.quote.units end
    end
    return priced, top, units
end
function UI:AddGroup(entries, hidden, group, items)
    group.hideKey = groupKey(group.group)
    local segment = self.props.segment
    group.sources = function() return groupSources(segment, group.group) end
    if ns.Hidden.IsGroup(group.hideKey) then hidden[#hidden + 1] = group; return end
    entries[#entries + 1] = group
    if not self.collapsed[group.group] then
        for _, item in ipairs(self.sorter:Apply(items, self.getters)) do entries[#entries + 1] = item end
    end
end
function UI:TradingEntries()
    local fee, entries, hidden, unsold = ns.Fee(), {}, {}, {}
    for _, key in ipairs(ns.Npc.order) do
        local items, off = {}, ns.Hidden.IsGroup(groupKey(key))
        for _, entry in ipairs(ns.Npc.Items(key)) do
            if ns.Npc.Vendor(entry) then
                local estimate = ns.Npc.Estimate(entry, fee)
                local item = {raw = entry.raw, entry = entry, estimate = estimate, quote = ns.Markets.Quote(entry.raw)}
                if ns.Hidden.IsGroup(hideKey(entry.raw)) then hidden[#hidden + 1] = item
                elseif ns.Npc.Unsold(entry.raw) and not off then unsold[#unsold + 1] = item
                else items[#items + 1] = item end
            end
        end
        if #items > 0 then
            local priced, best, units = summary(items, function(item) return item.estimate.margin end)
            self:AddGroup(entries, hidden, {group = key, name = ns.T("npcGroup" .. key),
                detail = ns.T("npcGroupDetail", #items, priced), margin = best, units = units,
                scanTip = ns.T("npcGroupScanTip")}, items)
        end
    end
    self:AddUnsold(entries, unsold)
    return entries, hidden
end
function UI:RecipeEntries()
    local fee, entries, hidden, unsold = ns.Fee(), {}, {}, {}
    for _, group in ipairs(ns.Npc.RecipeGroups()) do
        local items, off = {}, ns.Hidden.IsGroup(groupKey(group.key))
        for _, entry in ipairs(ns.Resale.Items(group.profession)) do
            if ns.Npc.Vendor(entry) then
                local item = {raw = entry.raw, entry = entry, estimate = ns.Resale.Estimate(entry, fee),
                    quote = ns.Markets.Quote(entry.raw)}
                if ns.Hidden.IsGroup(hideKey(entry.raw)) then hidden[#hidden + 1] = item
                elseif ns.Npc.Unsold(entry.raw) and not off then unsold[#unsold + 1] = item
                else items[#items + 1] = item end
            end
        end
        if #items > 0 then
            local priced, best, units = summary(items, function(item) return item.estimate.margin end)
            self:AddGroup(entries, hidden, {group = group.key, name = ns.T(group.labelKey),
                detail = ns.T("npcGroupDetail", #items, priced), margin = best, units = units,
                scanTip = ns.T("npcRecipeScanTip")}, items)
        end
    end
    self:AddUnsold(entries, unsold)
    return entries, hidden
end
local function currencyTip(key, best)
    local lines = {ns.T("npcCurrencyTip")}
    if best then lines[#lines + 1] = ns.T("npcCurrencyBest", ns.Markets.Name(best.raw)) end
    if key == "emblems" then lines[#lines + 1] = ns.T("npcLadderTip") end
    local currency = ns.Npc.currencies[key]
    if currency and currency.kind == "item" then
        local quote = ns.Markets.Quote(currency.item)
        lines[#lines + 1] = quote and quote.price and ns.T("npcItemCurrencyPrice", ns.TradeKit.Money(quote.price))
            or ns.T("npcItemCurrencyNoPrice")
    end
    return table.concat(lines, "\n\n")
end
function UI:PickKey()
    return self.props.pick or ns.Npc.DefaultPick()
end
local function currencyItems(key, fee, hidden, unsold, best)
    local items, off = {}, ns.Npc.Off(key)
    for _, good in ipairs(ns.Npc.byCurrency[key]) do
        if ns.Npc.Vendor(good) then
            local item = {raw = good.raw, good = good, rate = ns.Npc.Rate(good, fee), quote = ns.Markets.Quote(good.raw),
                best = good == best or nil}
            if ns.Hidden.IsGroup(hideKey(good.raw)) then hidden[#hidden + 1] = item
            elseif ns.Npc.Unsold(good.raw) and not off then unsold[#unsold + 1] = item
            else items[#items + 1] = item end
        end
    end
    return items
end
local function currencyHeader(key, name, items, chips, detail, rate)
    local _, top, units = summary(items, function(item) return item.rate end)
    return {group = key, name = name, icon = ns.Npc.Icon(ns.Npc.currencies[key] and key or ns.Npc.ladder[1]),
        chips = chips, detail = detail, margin = rate or top, units = units, hideKey = groupKey(key),
        sources = function() return groupSources("currency", key) end, scanTip = ns.T("npcCurrencyScanTip")}
end
local function emblemHeader(key, items)
    local total, own, extra = ns.Npc.Available(key)
    local have = own and tostring(own) or ns.T("npcCurrencyUnknown")
    local detail = ns.T("npcSubDetail", #items, have)
    if total and extra > 0 then detail = ns.T("npcSubDetailLadder", #items, have, total) end
    local header = currencyHeader(key, ns.Npc.CurrencyName(key), items, nil, detail)
    local best = nil
    for _, item in ipairs(items) do
        if item.rate and (not best or item.rate > best.rate) then best = item end
    end
    header.tip = currencyTip(key, best and best.good)
    return header
end
function UI:AddEmblems(entries, hidden, unsold, fee, pick)
    local all, chips = {}, {}
    for _, key in ipairs(ns.Npc.ladder) do
        local items = currencyItems(key, fee, hidden, unsold, pick)
        if #items > 0 and ns.Hidden.IsGroup(groupKey(key)) then
            local header = emblemHeader(key, items)
            hidden[#hidden + 1] = header
        else
            for _, item in ipairs(items) do all[#all + 1] = item end
        end
        chips[#chips + 1] = ownedLine(key)
    end
    if #all == 0 then return end
    local best, rate = ns.Npc.Best(ns.Npc.ladder[1], fee)
    local group = currencyHeader("emblems", ns.T("npcGroupemblems"), all, chips, ns.T("npcEmblemsDetail", #all), rate)
    group.tip = currencyTip("emblems", best)
    if ns.Hidden.IsGroup(group.hideKey) then hidden[#hidden + 1] = group; return end
    entries[#entries + 1] = group
    if self.collapsed.emblems then return end
    for _, item in ipairs(self.sorter:Apply(all, self.getters)) do entries[#entries + 1] = item end
end
function UI:CurrencyEntries()
    local fee, entries, hidden, unsold = ns.Fee(), {}, {}, {}
    local pick = ns.Npc.Pick(self:PickKey(), fee)
    local best = pick and pick.good
    self:AddEmblems(entries, hidden, unsold, fee, best)
    for _, key in ipairs(ns.Npc.currencyOrder) do
        if key ~= "emblems" then
            local items = currencyItems(key, fee, hidden, unsold, best)
            if #items > 0 then
                local top, rate = ns.Npc.Best(key, fee)
                local group = currencyHeader(key, ns.Npc.CurrencyName(key), items, {ownedLine(key)},
                    ns.T("npcEmblemsDetail", #items), rate)
                group.tip = currencyTip(key, top)
                self:AddGroup(entries, hidden, group, items)
            end
        end
    end
    self:AddUnsold(entries, unsold)
    return entries, hidden
end
local function detailText(item, vendor, columns)
    local limited = (vendor and (vendor.stock or 0) > 0) and stock(vendor) or ""
    local parts = {}
    if item.good and not columns.affordable then parts[#parts + 1] = paymentText(item.good) end
    if not columns.cost then
        if item.good then parts[#parts + 1] = priceText(item.good)
        elseif item.entry.tokens then parts[#parts + 1] = ns.T("npcRowTokens", tokensText(item.entry))
        else parts[#parts + 1] = ns.T("npcRowGold", ns.TradeKit.Money(item.entry.buy)) end
    end
    if not columns.seller then parts[#parts + 1] = place(vendor) end
    if limited ~= "" then parts[#parts + 1] = limited end
    return table.concat(parts, " | ")
end
function UI:ListRow(i, item, width, hidden)
    local p, layout, margin, percent, marginText = self.props, self.layout, nil, nil, nil
    local source = item.entry or item.good
    local vendor = ns.Npc.Vendor(source)
    if item.entry then
        local estimate = item.estimate
        margin = estimate.margin
        if estimate.margin and estimate.cost and estimate.cost > 0 then percent = estimate.margin / estimate.cost * 100 end
    else
        margin = item.rate
        marginText = item.rate and ns.TradeKit.Money(item.rate) or ns.T("tradeNoPrice")
    end
    local verify, detail = verifyText(source), detailText(item, vendor, layout.columns)
    if verify then detail = detail == "" and ns.T("npcVerifyTag") or ns.T("npcVerifyDetail", detail) end
    local lines, money = costLines(item)
    local pay = item.good and ns.Npc.Payment(item.good.currency, item.good.count)
    local tip = item.good and paymentText(item.good) or nil
    if verify then tip = tip and (tip .. "\n\n" .. verify) or verify end
    self.rows[i]:SetProps({id = item.raw, good = item.good, width = width, columns = layout.columns,
        wide = self.showHidden, vendor = vendor, sellerName = vendor and vendorName(vendor),
        sellerZone = vendor and zoneName(vendor), sellerTip = function() return vendor and sellerTip(vendor) or "" end,
        costLines = lines, costMoney = money, affordable = pay and pay.pieces,
        active = item.raw == p.id and (not p.good or item.good == p.good),
        quote = item.quote, margin = margin, marginText = marginText, percent = percent,
        detail = detail, hideable = true, hidden = hidden, nested = not hidden,
        tag = item.best and ns.T("npcBestTag") or nil, match = item.best,
        hideLabel = hidden and ns.T("hiddenRestore") or nil, extraTip = tip})
end
function UI:ShowSeller(vendor)
    if not vendor or not ns.MapPin then return false end
    return ns.MapPin.Show({title = vendorName(vendor), zone = vendor.zone, level = vendor.level,
        points = vendor.x and vendor.y and {{vendor.x, vendor.y}} or {}})
end
function UI:RenderList(entries, width)
    local visible = ns.TradeKit.ListCapacity(self.frame, TOP, BOTTOM, ROW, #self.rows + #self.groups)
    local offset = self.scroll:SetRange(#entries, visible)
    self.spoiler:Hide()
    local usedRows, usedGroups = 0, 0
    for i = 1, visible do
        local entry = entries[offset + i]
        local y = -TOP - (i - 1) * ROW
        if entry and entry.spoiler then
            self.spoiler:ClearAllPoints()
            self.spoiler:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, y)
            self.spoiler:SetWidth(width); self.spoiler:SetHeight(26)
            self.spoiler:SetText(ns.T(self.showHidden and "hiddenSpoilerOpen" or "hiddenSpoilerClosed", entry.count))
            self.spoiler:Show()
        elseif entry and entry.group then
            usedGroups = usedGroups + 1
            local header = self.groups[usedGroups]
            if header then
                local K = ns.TradeKit
                header.frame:ClearAllPoints(); header.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, y)
                header:SetProps({key = entry.group, name = entry.name, detail = entry.detail, width = width,
                    open = entry.hiddenRow or not self.collapsed[entry.group], tip = entry.tip, icon = entry.icon,
                    columns = self.layout.columns, chips = entry.chips, sub = entry.sub,
                    cells = {margin = {entry.margin and K.Money(entry.margin) or nil, K.Tone(entry.margin)},
                        units = {entry.units and entry.units > 0 and tostring(entry.units) or nil, "secondary"}},
                    sources = entry.sources, scanTip = entry.scanTip, hideKey = entry.hideKey, hidden = entry.hiddenRow})
            end
        elseif entry then
            usedRows = usedRows + 1
            local row = self.rows[usedRows]
            if row then
                row.frame:ClearAllPoints(); row.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, y)
                self:ListRow(usedRows, entry, width, entry.hiddenRow)
            end
        end
    end
    for i = usedRows + 1, #self.rows do
        self.rows[i].frame:Hide()
    end
    for i = usedGroups + 1, #self.groups do self.groups[i].frame:Hide() end
end
local function verdict(vendor, cost, gain, breakEven)
    if not vendor then return "" end
    local K, npc = ns.TradeKit, vendorName(vendor)
    if not gain then return ns.T("npcVerdictNoPrice", npc, cost) end
    if gain < 0 then return ns.T("npcVerdictLoss", npc, K.Money(-gain)) end
    if breakEven then return ns.T("npcVerdict", npc, cost, K.Money(breakEven), K.Money(gain)) end
    return ns.T("npcVerdictCurrency", npc, cost, K.Money(gain))
end
function UI:RenderTrading(selected)
    local K, fee = ns.TradeKit, ns.Fee()
    local entry = selected.entry
    local estimate = ns.Npc.Estimate(entry, fee)
    local labels = {"npcCost", "npcRevenue", "npcMargin", "npcBreakEven"}
    local amounts = {estimate.cost, estimate.revenue, estimate.margin, estimate.breakEven}
    for i, label in ipairs(self.valueLabels) do
        label:SetText(ns.T(labels[i], math.floor(fee * 100 + 0.5)))
        self.values[i]:SetText(K.Money(amounts[i]))
        self.values[i]:SetTextColor(unpack(K.theme.text))
    end
    if estimate.margin then
        self.values[3]:SetTextColor(unpack(K.theme[K.Tone(estimate.margin)]))
    end
    local vendor = ns.Npc.Vendor(entry)
    local lines = {}
    if entry.tokens then lines[#lines + 1] = ns.T("npcPay", tokensText(entry)) end
    if entry.via then lines[#lines + 1] = viaText(entry) end
    if estimate.missing then lines[#lines + 1] = ns.T("npcTokenMissing", ns.Markets.Name(estimate.missing)) end
    local cost = entry.tokens and tokensText(entry) or K.Money(entry.buy)
    self:RenderNotes(entry, vendor, lines, verdict(vendor, cost, estimate.margin, estimate.breakEven))
end
function UI:RenderCurrency(selected)
    local K, fee = ns.TradeKit, ns.Fee()
    local good = selected.good
    local quote = ns.Markets.Quote(good.raw)
    local revenue = quote and quote.price and (quote.miss or 0) == 0 and quote.price * (1 - fee) or nil
    local pay = ns.Npc.Payment(good.currency, good.count)
    local labels = {"npcCost", "npcRevenue", "npcRateLabel", "npcOwned"}
    local owned = pay.own and tostring(pay.own) or ns.T("npcCurrencyUnknown")
    local currency = ns.Npc.currencies[good.currency]
    local alts = altsOf(currency and currency.item)
    if alts then owned = ns.T("npcOwnedAlts", owned, alts) end
    local texts = {priceText(good), K.Money(revenue), K.Money(ns.Npc.Rate(good, fee)), owned}
    for i, label in ipairs(self.valueLabels) do
        label:SetText(ns.T(labels[i], math.floor(fee * 100 + 0.5)))
        self.values[i]:SetText(texts[i])
        self.values[i]:SetTextColor(unpack(K.theme.text))
    end
    local vendor = ns.Npc.Vendor(good)
    local lines = {paymentText(good)}
    if pay.via then
        lines[#lines + 1] = ns.T("npcPayVia", ns.Npc.CurrencyName(pay.via), ns.Npc.CurrencyName(good.currency))
    end
    self:RenderNotes(good, vendor, lines, verdict(vendor, priceText(good), ns.Npc.Rate(good, fee)))
end
function UI:RenderNotes(source, vendor, lines, line)
    local width = math.max(200, (self.inspector.frame:GetWidth() or 264) - 24)
    self.verdict:SetWidth(width)
    self.verdict:SetText(line)
    self:ShowVendor(true)
    if vendor then
        ns.TradeKit.SetTextLink(self.where, width, vendorName(vendor), zoneName(vendor))
        self.where.vendor = vendor
        ns.TradeKit.Tooltip(self.where, vendorName(vendor), "")
    else
        self.where:Hide()
        table.insert(lines, 1, place(vendor))
    end
    self.limit:SetText(limit(vendor))
    local verify = verifyText(source)
    if verify then lines[#lines + 1] = verify end
    self.notes:SetWidth(width)
    self.notes:SetText(table.concat(lines, "\n\n"))
end
local function pickText(pick)
    local K = ns.TradeKit
    if not pick then return ns.T("npcPickNoPrice") end
    local name, text = ns.Markets.Name(pick.good.raw), nil
    if not pick.pieces then text = ns.T("npcPickRate", name, K.Money(pick.rate))
    elseif pick.pieces == 0 then text = ns.T("npcPickShort", name, pick.good.count, pick.amount)
    else text = ns.T("npcPickBest", name, pick.pieces, K.Money(pick.revenue)) end
    if pick.via then text = text .. " " .. ns.T("npcPickVia", ns.Npc.CurrencyName(pick.via)) end
    if (pick.pieces or 0) > 0 and pick.units then text = text .. " " .. ns.T("npcPickMarket", pick.units) end
    if pick.itself then text = ns.T("npcPickItself", K.Money(pick.itself)) .. " " .. text end
    return text
end
function UI:RenderPick()
    local key = self:PickKey()
    local entries, signature = {}, {}
    for _, currency in ipairs(ns.npcCurrencies) do
        if #ns.Npc.byCurrency[currency.key] > 0 then
            local amount = ns.Npc.Amount(currency.key)
            local entry = {key = currency.key, label = ns.Npc.CurrencyName(currency.key),
                note = amount and tostring(amount) or ns.T("costUnknownShort")}
            entries[#entries + 1] = entry
            signature[#signature + 1] = entry.label .. entry.note
        end
    end
    signature = table.concat(signature, ";")
    if signature ~= self.pickSignature then self.pickSignature = signature; self.pick:SetEntries(entries) end
    self.pick.frame:SetText(ns.T("npcPickMenu", ns.Npc.CurrencyName(key)))
    self.pick.frame:Show()
    local text = pickText(ns.Npc.Pick(key, ns.Fee()))
    ns.TradeKit.Tooltip(self.pick.frame, ns.T("npcPickTitle"), text .. "\n\n" .. ns.T("npcPickTip"))
end
function UI:Pick(key)
    local pick = ns.Npc.Pick(key, ns.Fee())
    if not pick then self:SetProps({pick = key}); return end
    local currency = pick.good.currency
    self.collapsed[ns.Npc.GroupOf(currency)], self.collapsed[currency] = nil, nil
    self.reveal = true
    self:SetProps({pick = key, id = pick.good.raw, good = pick.good})
end
function UI:Render()
    if not self.frame then return end
    local K, p = ns.TradeKit, self.props
    self.segment:Select(p.segment)
    local trading = p.segment ~= "currency"
    self.headers.margin:SetText(ns.T(trading and "npcHeadMargin" or "npcHeadRate"))
    if trading then
        self.pick.frame:Hide()
    else
        self:RenderPick()
    end
    K.ScanTip(self.scan, ns.T("cacheComplete"), ns.T(p.segment == "recipes" and "npcRecipeScanTip" or trading and "npcScanTip" or "npcScanCurrencyTip"),
        function() return self:Sources() end)
    local entries, hidden
    if p.segment == "recipes" then entries, hidden = self:RecipeEntries()
    elseif trading then entries, hidden = self:TradingEntries() else entries, hidden = self:CurrencyEntries() end
    local selected, loose, first
    for _, list in ipairs({entries, hidden}) do
        for _, entry in ipairs(list) do
            if entry.raw and entry.raw == p.id then
                if not selected and (not p.good or entry.good == p.good) then selected = entry end
                loose = loose or entry
            end
            if entry.raw and not first and list == entries then first = entry end
        end
    end
    selected = selected or loose or first
    p.id, p.good = selected and selected.raw, selected and selected.good
    if self.reveal then
        self.reveal = nil
        for i, entry in ipairs(entries) do
            if entry == selected then self.scroll.offset = math.max(0, i - 3) end
        end
    end
    self.hiddenCount = #hidden
    if #hidden > 0 then
        entries[#entries + 1] = {spoiler = true, count = #hidden}
        if self.showHidden then
            for _, entry in ipairs(hidden) do entry.hiddenRow = true; entries[#entries + 1] = entry end
        end
    end
    local width = (self.frame:GetWidth() or 996) - RIGHT
    local columns, wide = K.SellerColumns(width - self.rows[1]:Reserve(self.showHidden), not trading)
    self.layout = {columns = columns, wide = wide}
    K.PlaceHeaders(self.headers, columns, self.frame, -38)
    self.extraHeaders.cost:SetText(ns.T(trading and "npcHeadPay" or "npcHeadCurrency"))
    K.PlaceHeaders(self.extraHeaders, columns, self.frame, -38)
    self.sorter:Mark()
    self:RenderList(entries, width)
    local shown = false
    for _, entry in ipairs(entries) do if entry.raw then shown = true; break end end
    self.empty:SetText(shown and "" or ns.T("npcEmpty"))
    if selected then
        self.inspector:SetProps({id = selected.raw})
        if trading then self:RenderTrading(selected) else self:RenderCurrency(selected) end
    else
        self.inspector:Clear(); self.notes:SetText(""); self.verdict:SetText(""); self:ShowVendor(false)
        for i, value in ipairs(self.values) do value:SetText(""); self.valueLabels[i]:SetText("") end
    end
    self:Controls()
end
function UI:Sources()
    local ids, seen, segment = {}, {}, self.props.segment
    for _, key in ipairs(groupKeys(segment)) do
        if not ns.Hidden.IsGroup(groupKey(key)) then
            for _, id in ipairs(groupSources(segment, key)) do
                if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
            end
        end
    end
    return ids
end
function UI:Controls()
    if not self.frame then return end
    local ready = ns.Scan.state.phase == "idle" and not ns.Buy.Active()
    if ready then self.scan:Enable() else self.scan:Disable() end
    if ready and self.props.id then self.buy:Enable() else self.buy:Disable() end
end
function UI:ToggleHide(id, props)
    ns.Hidden.SetGroup(hideKey(id), not props.hidden)
    self:Render()
end
function UI:BuildTable(f)
    local K = ns.TradeKit
    K.TableHeader(f, -38)
    self.headers = {}
    for _, entry in ipairs({{"item", "npcHeadGoods"}, {"price", "npcHeadPrice"},
        {"margin", "npcHeadMargin"}, {"units", "tradeUnits"}}) do
        local label = K.Label(f, ns.T(entry[2]), 0, -38, 100)
        if entry[1] ~= "item" then label:SetJustifyH("RIGHT") end
        self.headers[entry[1]] = label
    end
    self.extraHeaders = {seller = K.Label(f, ns.T("npcHeadSeller"), 0, -38, 100), cost = K.Label(f, "", 0, -38, 100),
        affordable = K.Label(f, ns.T("npcHeadAffordable"), 0, -38, 100)}
    self.extraHeaders.cost:SetJustifyH("RIGHT")
    self.extraHeaders.affordable:SetJustifyH("RIGHT")
    self.getters = {
        item = function(item) return ns.Markets.Name(item.raw) end,
        price = function(item) return item.quote and item.quote.price end,
        margin = function(item) if item.estimate then return item.estimate.margin end; return item.rate end,
        units = function(item) return item.quote and item.quote.units end,
        affordable = function(item)
            local good = item.good
            return good and ns.Npc.Payment(good.currency, good.count).pieces
        end,
        seller = function(item)
            local vendor = ns.Npc.Vendor(item.entry or item.good)
            return vendor and vendorName(vendor)
        end,
    }
    local sortable = {seller = self.extraHeaders.seller, affordable = self.extraHeaders.affordable}
    for key, label in pairs(self.headers) do sortable[key] = label end
    self.sorter = K.Sorter(f, sortable, function() self.scroll.offset = 0; self:Render() end, nil, {key = "margin", desc = true})
    K.Tooltip(self.sorter.buttons.affordable, ns.T("npcHeadAffordable"), ns.T("npcAffordableTip") .. "\n\n" .. ns.T("sortTip"))
    self.scroll = K.TableScroll(f, function() self:Render() end, TOP, BOTTOM, ROW)
    for i = 1, 40 do
        local row = K.SellerRow:New(f, function(id, props) self:SetProps({id = id, good = props.good}) end,
            function(id, props) self:ToggleHide(id, props) end, function(vendor) self:ShowSeller(vendor) end)
        row.frame:SetHeight(ROW - 1); row.frame:Hide()
        self.rows[i] = row
        self.scroll:Wheel(row.frame)
    end
    for i = 1, 18 do
        local header = K.GroupRow:New(f, function(key) self.collapsed[key] = not self.collapsed[key] or nil; self:Render() end,
            function() self:Render() end)
        header.frame:SetHeight(ROW - 1); header.frame:Hide()
        self.scroll:Wheel(header.frame); self.groups[i] = header
    end
    self.spoiler = K.Button(f, "", 400, function() self.showHidden = not self.showHidden; self:Render() end, "quiet")
    self.spoiler.text:ClearAllPoints(); self.spoiler.text:SetPoint("LEFT", self.spoiler, "LEFT", 10, 0)
    self.spoiler:Hide()
    K.Tooltip(self.spoiler, ns.T("hiddenSection"), ns.T("npcHiddenTip"))
    self.empty = K.Label(f, "", 10, -TOP - 10, 440)
    self.empty:SetHeight(40); self.empty:SetJustifyV("TOP")
end
function UI:ShowVendor(shown)
    for _, region in ipairs({self.vendorRule, self.vendorHead, self.limitLabel, self.limit}) do
        if shown then region:Show() else region:Hide() end
    end
    if not shown then self.where:Hide() end
end
function UI:BuildInspector(f)
    local K = ns.TradeKit
    self.inspector = K.Inspector:New(f)
    local panel = self.inspector.body
    self.values, self.valueLabels = {}, {}
    self.verdict = K.Label(panel, "", 12, -48, 240)
    self.verdict:SetHeight(28); self.verdict:SetJustifyV("TOP")
    for i = 1, 4 do
        self.valueLabels[i], self.values[i] = K.ValueRow(panel, "", -82 - (i - 1) * 20, 110, 130)
    end
    self.vendorRule = K.Rule(panel, -170)
    self.vendorHead = K.Label(panel, ns.T("npcVendorHead"), K.theme.inset, -180, 240, "heading")
    self.vendorHead:SetHeight(14)
    self.where = K.TextLink(panel, function(link) self:ShowSeller(link.vendor) end)
    self.where:SetPoint("TOPLEFT", panel, "TOPLEFT", K.theme.inset, -200)
    self.where.tipFn = function() return sellerTip(self.where.vendor) end
    self.limitLabel, self.limit = K.ValueRow(panel, ns.T("npcLimitLabel"), -232, 110, 130)
    self:ShowVendor(false)
    self.notes = K.Label(panel, "", 12, -256, 240)
    self.notes:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 8); self.notes:SetJustifyV("TOP")
end
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent)
    local f = self.frame
    f:SetAllPoints(parent)
    self.segment = K.Segment(f, {{key = "trading", label = ns.T("npcSegmentTrading")},
        {key = "currency", label = ns.T("npcSegmentCurrency")}, {key = "recipes", label = ns.T("npcRecipes"),
            tip = {ns.T("npcRecipes"), ns.T("npcRecipesTip")}}},
        function(key) self:SetProps({segment = key}) end)
    self.segment.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -2)
    self.pick = K.Menu(f, {}, function(key) self:Pick(key) end)
    self.pick.frame:SetWidth(200)
    self.pick.frame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -RIGHT, -2)
    self:BuildTable(f)
    self.scan = K.Button(f, ns.T("cacheComplete"), 140, function()
        ns.Batch.Complete(self:Sources(), K.ScanMode(), true); self:Render()
    end, "main")
    self.scan:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -282, 4)
    self.buy = K.Button(f, ns.T("npcAuction"), 92, function() if self.props.id then ns.Trader.OpenBuy(self.props.id) end end)
    K.Tooltip(self.buy, ns.T("npcAuction"), ns.T("npcAuctionTip"))
    self.buy:SetPoint("RIGHT", self.scan, "LEFT", -6, 0)
    self:BuildInspector(f)
    f:SetScript("OnSizeChanged", function() self:Render() end)
    f:SetScript("OnShow", function() self:Render() end)
    self:Render()
    return self
end
