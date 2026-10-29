local _, ns = ...
local UI = {group = "wrathArmor", rows = {}, groups = {}, chips = {}, qualities = {[2] = true},
    mode = "equipment", target = 10940, equipmentGroup = "wrathArmor",
    selling = {hours = 12, losses = 1}, tail = true, tailPercent = -10, buyPercent = 0, minItemLevel = 0, maxItemLevel = 0,
    includeNoLevel = false, buyMode = "margin", buyPrice = 150000, excludedBands = {}, collapsed = {}}
ns.DisenchantUI = UI
local kindKeys = {dust = "deKindDust", essence = "deKindEssence", shard = "deKindShard", crystal = "deKindCrystal"}
local function percent(chance)
    return math.floor(chance * 100 + 0.5)
end
function UI.Kind(id)
    local kind = ns.disenchantMaterialKinds and ns.disenchantMaterialKinds[id]
    return kind and ns.T(kindKeys[kind]) or ns.Markets.Name(id)
end
function UI.KindTitle(id)
    local kind = ns.disenchantMaterialKinds and ns.disenchantMaterialKinds[id]
    return kind and ns.T(kindKeys[kind] .. "Title") or ns.Markets.Name(id)
end
function UI.BandKind(band)
    if band.kind == "weapon" then return ns.T("deKindWeapon") end
    if band.kind == "armor" then return ns.T("deKindArmor") end
    return ns.T((band.quality or 2) == 4 and "deKindEpicItems" or "deKindRareItems")
end
function UI:Save()
    local db = ns.Store.DB()
    local saved = type(db.disenchantUI) == "table" and db.disenchantUI or {}
    saved.group, saved.target, saved.equipmentGroup = self.group, self.target, self.equipmentGroup
    saved.minItemLevel, saved.maxItemLevel, saved.includeNoLevel = self.minItemLevel, self.maxItemLevel, self.includeNoLevel
    saved.buyMode, saved.buyPrice = self.buyMode, self.buyPrice
    saved.bands = type(saved.bands) == "table" and saved.bands or {}
    if ns.Disenchant.Group(self.group).targetID then
        local list = {}
        for band, off in pairs(self.excludedBands) do if off then list[#list + 1] = band end end
        saved.bands[self.target] = list
    end
    db.disenchantUI = saved
end
function UI:LoadBands()
    local group = ns.Disenchant.Group(self.group)
    self.excludedBands = {}
    if not group.targetID then return end
    local saved = ns.Store.DB().disenchantUI
    local list = type(saved) == "table" and type(saved.bands) == "table" and saved.bands[group.targetID]
    if type(list) == "table" then
        for _, band in ipairs(list) do if type(band) == "string" then self.excludedBands[band] = true end end
    else self.excludedBands = ns.Disenchant.DefaultExcluded(self.group) end
end
function UI:SetBand(band, enabled)
    self.excludedBands[band] = (not enabled) or nil
    self:Save(); self:Render()
end
function UI:Excluded()
    if ns.Disenchant.Group(self.group).targetID then return self.excludedBands end
    return nil
end
function UI:Roles()
    local families, roles, target = {}, {}, ns.Disenchant.Group(self.group).targetID
    for _, band in ipairs(ns.Disenchant.TargetBands(self.group)) do
        if band.kind ~= "weapon" then
            local family = band.kind .. (band.quality or 2)
            families[family] = families[family] or {}
            table.insert(families[family], band)
        else roles[band.key] = "weapon" end
    end
    for _, bands in pairs(families) do
        if #bands > 1 then
            local low, high = bands[1], bands[1]
            for _, band in ipairs(bands) do
                if ns.Disenchant.Average(band, target) < ns.Disenchant.Average(low, target) then low = band end
                if ns.Disenchant.Average(band, target) > ns.Disenchant.Average(high, target) then high = band end
            end
            if low ~= high then roles[low.key], roles[high.key] = "low", "top" end
        end
    end
    return roles
end
function UI:SelectGroup(key)
    local group = ns.Disenchant.Group(key)
    local old = ns.Disenchant.Group(self.group)
    if not group then return end
    if self.group ~= key then ns.Disenchant.CancelBuy(); ns.Batch.Stop(); self.scroll.offset = 0; self.selected = nil end
    if group.targetID then self.mode, self.target = "target", group.targetID
    else self.mode, self.equipmentGroup = "equipment", key end
    if group.targetID and (old.targetID ~= group.targetID or self.minItemLevel == 0) then
        self.minItemLevel = group.minItemLevel or 0
        self.maxItemLevel = group.maxItemLevel or 0
    elseif not group.targetID and old.targetID then self.minItemLevel, self.maxItemLevel = 0, 0 end
    if self.ilvlEdit then self.ilvlEdit:SetText(tostring(self.minItemLevel)) end
    if self.maxIlvlEdit then self.maxIlvlEdit:SetText(tostring(self.maxItemLevel)) end
    self.qualities = {}
    for quality = 2, 4 do self.qualities[quality] = ns.Disenchant.HasQuality(group, quality) end
    self.group = key
    self:LoadBands()
    self:Save()
    self:Render()
end
function UI.Open(targetID, bandKey)
    ns.Trader.Navigate(function()
        ns.Trader.OpenProcessing("disenchant")
        local D = ns.Disenchant
        local band = bandKey and D.Band(bandKey)
        local key = targetID and D.Selection("target" .. targetID, band and {[band.quality or 2] = true}
            or {[2] = true, [3] = true, [4] = true})
        if not key or not D.Group(key) or not UI.scroll then return end
        UI:SelectGroup(key)
        if band then
            UI.excludedBands[band.key], UI.collapsed[band.key] = nil, nil
            UI:Save()
            UI:Render()
        end
    end)
end
function UI:RestoreSelection()
    local saved = ns.Store.DB().disenchantUI
    if type(saved) ~= "table" or type(saved.group) ~= "string" then return end
    local group = ns.Disenchant.Group(saved.group)
    if not group then return end
    self.group, self.mode = group.key, group.targetID and "target" or "equipment"
    local target = type(saved.target) == "number" and ns.Disenchant.Group("target" .. saved.target .. "_234")
    self.target = group.targetID or (target and target.targetID) or self.target
    self.minItemLevel = type(saved.minItemLevel) == "number" and saved.minItemLevel
        or group.minItemLevel or 0
    self.maxItemLevel = type(saved.maxItemLevel) == "number" and saved.maxItemLevel
        or group.maxItemLevel or 0
    self.includeNoLevel = saved.includeNoLevel == true
    self.buyMode = saved.buyMode == "price" and "price" or "margin"
    if type(saved.buyPrice) == "number" and saved.buyPrice >= 1 and saved.buyPrice <= 1000000000 then
        self.buyPrice = math.floor(saved.buyPrice)
    end
    local equipment = type(saved.equipmentGroup) == "string" and ns.Disenchant.Group(saved.equipmentGroup)
    if equipment and not equipment.targetID then self.equipmentGroup = equipment.key end
    self.qualities = {}
    for quality = 2, 4 do self.qualities[quality] = ns.Disenchant.HasQuality(group, quality) end
    self:LoadBands()
end
function UI:SelectMode(mode)
    if mode == "target" then
        self:SelectGroup(ns.Disenchant.Selection("target" .. self.target, {[2] = true, [3] = true, [4] = true}))
    else self:SelectGroup(self.equipmentGroup) end
end
function UI:PriceLimit()
    return self.buyMode == "price" and self.buyPrice or nil
end
function UI:SetBuyMode(mode)
    ns.Disenchant.CancelBuy()
    self.buyMode = mode
    self.buyEdit:SetText(tostring(self:PriceLimit() and self.buyPrice / 10000 or self.buyPercent))
    self:ReadSettings()
    self:Render()
end
function UI:Controls()
    local phase = ns.Scan.state.phase
    local group = ns.Disenchant.Group(self.group)
    if phase == "idle" and not ns.Buy.Active() and (not group.targetID or #ns.Disenchant.Materials(self.group) > 0) then
        self.scan:Enable()
    else self.scan:Disable() end
    for _, button in ipairs({self.scanMaterials, self.scanAll}) do
        if self.scan:IsEnabled() then button:Enable() else button:Disable() end
    end
    local purchase, primary = ns.Disenchant.purchase, self:Primary()
    self.buy:SetWidth(purchase and 220 or 170)
    self.mainReason, self.mainPart = nil, nil
    if purchase then
        local count, cost = ns.Buy.Offer()
        self.buy:SetText(ns.Buy.state.phase == "ready" and ns.T("deBuyConfirm", count, ns.TradeKit.Money(cost))
            or ns.T("deBuySearching"))
        if ns.Buy.state.phase == "ready" then self.buy:Enable() else self.buy:Disable() end
        self.buy.tipTitle, self.mainTip = ns.T(self:PriceLimit() and "deBuyByPrice" or "deBuyByMargin"), ns.T("deBuyTip")
    elseif primary == "buy" then
        self.buy:SetText(ns.T(ns.Scan.purchaseRequest and "deBuyWaitingPage"
            or (self:PriceLimit() and "deBuyByPrice" or "deBuyByMargin")))
        local can = self:CanPurchase()
        if can and self.preview and self.preview.count > 0 then self.buy:Enable() else self.buy:Disable() end
        self.mainReason = not ns.Scan.state.open and ns.T("deBuyClosed") or not can and ns.T("deMainWait")
            or self.previewText
        self.buy.tipTitle = ns.T(self:PriceLimit() and "deBuyByPrice" or "deBuyByMargin")
        self.mainTip = ns.T("deBuyContext", self.buyContext or "") .. "\n\n"
            .. ns.T(self:PriceLimit() and "deBuyModeTip" or "deBuyTip")
    else
        self.mainPart = primary == "scan" and "all" or "materials"
        self.buy:SetText(ns.T(primary == "scan" and "deMainScan" or "deMainMaterials"))
        if self.scan:IsEnabled() then self.buy:Enable() else self.buy:Disable() end
        self.mainReason = phase ~= "idle" and ns.T("deMainWait") or ns.Buy.Active() and ns.T("deMainWait")
            or ns.T("deTargetNoBands")
        self.buy.tipTitle = ns.T(primary == "scan" and "deMainScan" or "deMainMaterials")
        local age, blocked = self:SnapshotAge(), ns.Disenchant.blocked
        if primary == "materials" then
            self.mainTip = ns.T("deMainMaterialsTip") .. (blocked and ("\n\n" .. ns.Disenchant.BlockedText(blocked)) or "")
        else self.mainTip = age and ns.T("deMainScanAgedTip", ns.TradeKit.Ago(age)) or ns.T("deMainScanTip") end
    end
    local ready = phase == "idle" and not ns.Buy.Active()
    if ready then self.buyEdit:Show(); self.buyLabel:Show(); self.buyUnit:Show(); self.shownFrom:Show()
    else self.buyEdit:Hide(); self.buyLabel:Hide(); self.buyUnit:Hide(); self.shownFrom:Hide() end
    self.buyLabel:SetText(ns.T(self:PriceLimit() and "deBarPrice" or "deBarMargin"))
    self.buyUnit:SetText(ns.T(self:PriceLimit() and "deGold" or "dePercent"))
    self.buyModes:Select(self.buyMode)
    for _, control in ipairs({self.buyModes, self.tailCheck, self.durationSegment, self.groupMenu.frame,
        self.modeSegment, self.targetPicker.frame, self.noLevelCheck}) do
        if ready then control:Enable() else control:Disable() end
    end
    if not ready then self.targetPicker.cover:Hide(); self.groupMenu.cover:Hide() end
    for _, control in pairs(self.qualityChecks) do if ready then control:Enable() else control:Disable() end end
    for _, chip in ipairs(self.chips) do if ready then chip:Enable() else chip:Disable() end end
    if self:PriceLimit() then self.tailCheck:Disable() end
    self.tailCheck:SetChecked(self.tail and not self:PriceLimit())
    for _, edit in ipairs({self.tailEdit, self.lossEdit, self.depositEdit, self.ilvlEdit, self.maxIlvlEdit}) do
        edit:EnableMouse(ready); if not ready then edit:ClearFocus() end
    end
    self.tailEdit:EnableMouse(ready and not self:PriceLimit())
end
function UI:Primary()
    local D = ns.Disenchant
    if D.purchase then return "buy" end
    if D.blocked and D.blocked.key == self.group then return "materials" end
    local progress = D.Progress(self.group)
    if progress and progress.stage == "equipment" then return "buy" end
    local age = self:SnapshotAge()
    if age and age <= D.priceSeconds then return "buy" end
    return "scan"
end
function UI:SnapshotAge()
    local shot = ns.Disenchant.Snapshot(self.group)
    return shot and math.max(0, time() - (shot.t + (shot.secs or 0))) or nil
end
function UI:EquipmentAge(materials)
    local age = materials and ns.Batch.Age(materials, true) or {never = 0, count = 0}
    local shot = self:SnapshotAge()
    age.count = age.count + 1
    if not shot then age.never = age.never + 1
    elseif not age.oldest or shot > age.oldest then age.oldest = shot end
    return age
end
function UI:Main()
    if self.mainPart then self:StartScan(self.mainPart) else self:Purchase() end
end
function UI:CanPurchase()
    if not ns.Scan.state.open or ns.Buy.Active() or ns.Scan.purchaseRequest then return false end
    local progress = ns.Disenchant.Progress(self.group)
    return ns.Scan.state.phase == "idle" or progress and progress.stage == "equipment"
        and (ns.Scan.state.scan.deScannedPages or ns.Scan.state.page) > 0
end
function UI:Options()
    return {fee = ns.Fee(), percent = self.buyPercent, priceLimit = self:PriceLimit(),
        minItemLevel = self.minItemLevel, maxItemLevel = self.maxItemLevel, includeNoLevel = self.includeNoLevel,
        excludedBands = self:Excluded(),
        selling = {hours = self.selling.hours, losses = self.selling.losses, base = self.selling.base}}
end
function UI:Purchase(itemID)
    if not self:ReadSettings() then return end
    local options = self:Options()
    options.itemID = itemID or (ns.Disenchant.purchase and ns.Disenchant.purchase.options.itemID)
    ns.Disenchant.Purchase(self.group, options)
    self:Render()
end
function UI:ScanOptions()
    local limit = self:PriceLimit()
    return {fee = ns.Fee(), cut = limit ~= nil or self.tail, priceLimit = limit,
        percent = self.tailPercent, minItemLevel = self.minItemLevel, maxItemLevel = self.maxItemLevel,
        includeNoLevel = self.includeNoLevel,
        selling = {hours = self.selling.hours, losses = self.selling.losses, base = self.selling.base}}
end
function UI:StartScan(part)
    if part ~= "materials" and not self:ReadSettings() then return end
    ns.Disenchant.Scan(self.group, ns.TradeKit.ScanMode(), self:ScanOptions(), part)
    self:Render()
end
function UI:ReadSettings()
    ns.TradeKit.FlushEdits(self.ilvlEdit, self.maxIlvlEdit, self.tailEdit, self.lossEdit, self.depositEdit, self.buyEdit)
    local levelText = self.ilvlEdit:GetText()
    local level = levelText == "" and 0 or tonumber(levelText)
    local maximumText = self.maxIlvlEdit:GetText()
    local maximum = maximumText == "" and 0 or tonumber(maximumText)
    if not level or level < 0 or level > 999 or level ~= math.floor(level)
        or not maximum or maximum < 0 or maximum > 999 or maximum ~= math.floor(maximum)
        or maximum > 0 and level > maximum then
        ns.say(ns.T("deInvalidItemLevel")); return false
    end
    local tail, buy = tonumber((self.tailEdit:GetText():gsub(",", "."))), tonumber((self.buyEdit:GetText():gsub(",", ".")))
    if not tail or tail <= -100 or tail > 1000 then ns.say(ns.T("alchemyInvalidPrice")); return false end
    if self:PriceLimit() then
        if not buy or buy < 0.0001 or buy > 100000 then ns.say(ns.T("buyPriceInvalid")); return false end
        self.buyPrice = math.floor(buy * 10000 + 0.5)
    elseif not buy or buy <= -100 or buy > 1000 then
        ns.say(ns.T("alchemyInvalidPrice")); return false
    else self.buyPercent = buy
    end
    self.tailPercent, self.minItemLevel = tail, level
    self.maxItemLevel = maximum
    self:Save()
    return true
end
function UI:Commit(edit, apply, show)
    local K = ns.TradeKit
    K.LiveEdit(edit, function(box)
        apply((box:GetText():gsub(",", ".")))
        self:Render()
    end)
    edit:SetScript("OnEscapePressed", function(box) box:SetText(show()); box:ClearFocus() end)
    edit:SetScript("OnEditFocusLost", function(box)
        K.FlushEdits(box)
        box:SetText(show())
    end)
end
function UI:NewSettings(parent)
    local K = ns.TradeKit
    local x = 10
    local function put(frame, width, gap, y)
        frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        if frame.SetWidth and width then frame:SetWidth(width) end
        x = x + (width or frame:GetWidth() or 60) + gap
    end
    local function caption(text, width, y)
        local label = K.Label(parent, text, 0, 0, width, "secondary")
        label:SetHeight(12); put(label, width, 4, y - 5)
        return label
    end
    caption(ns.T("deFilterQuality"), 54, -8)
    self.qualityLabels = {[2] = "deUncommon", [3] = "deRare", [4] = "deEpic"}
    self.qualityChecks = {}
    for quality = 2, 4 do
        local q = quality
        local chip = K.Chip(parent, ns.T(self.qualityLabels[q]), function(checked)
            self.qualities[q] = checked
            local group = ns.Disenchant.Group(self.group)
            local key = ns.Disenchant.Selection(group.base or group.key, self.qualities)
            if key then self:SelectGroup(key) else self.qualities[q] = true; self:Render() end
        end)
        put(chip, nil, 4, -8)
        self.qualityChecks[q] = chip
    end
    x = x + 10
    caption(ns.T("deFilterLevels"), 24, -8)
    self.ilvlEdit = K.Edit(parent, 46); self.ilvlEdit:SetText(tostring(self.minItemLevel))
    put(self.ilvlEdit, 46, 4, -8)
    self:Commit(self.ilvlEdit, function(text)
        local value = text == "" and 0 or tonumber(text)
        if value and value >= 0 and value <= 999 and value == math.floor(value) then self.minItemLevel = value end
    end, function() return tostring(self.minItemLevel) end)
    K.Tooltip(self.ilvlEdit, ns.T("deMinItemLevel"), ns.T("deMinItemLevelTip"))
    caption("-", 8, -8)
    self.maxIlvlEdit = K.Edit(parent, 46); self.maxIlvlEdit:SetText(tostring(self.maxItemLevel))
    put(self.maxIlvlEdit, 46, 8, -8)
    self:Commit(self.maxIlvlEdit, function(text)
        local value = text == "" and 0 or tonumber(text)
        if value and value >= 0 and value <= 999 and value == math.floor(value) then self.maxItemLevel = value end
    end, function() return tostring(self.maxItemLevel) end)
    K.Tooltip(self.maxIlvlEdit, ns.T("deMaxItemLevel"), ns.T("deMaxItemLevelTip"))
    self.noLevelCheck = K.Chip(parent, ns.T("deNoLevel"), function(value)
        self.includeNoLevel = value; self:Save(); self:Render()
    end)
    put(self.noLevelCheck, nil, 10, -8)
    self.noLevelCheck:SetChecked(self.includeNoLevel)
    K.Tooltip(self.noLevelCheck, ns.T("deNoLevel"), ns.T("deNoLevelTip"))
    self.tailCheck = K.Chip(parent, ns.T("deFilterTail"), function(value) self.tail = value; self:Render() end)
    put(self.tailCheck, nil, 4, -8)
    self.tailCheck:SetChecked(self.tail)
    K.Tooltip(self.tailCheck, ns.T("deTail"), ns.T("deTailTip"))
    self.tailEdit = K.Edit(parent, 50); self.tailEdit:SetText(tostring(self.tailPercent))
    put(self.tailEdit, 50, 2, -8)
    self:Commit(self.tailEdit, function(text)
        local value = tonumber(text)
        if value and value > -100 and value <= 1000 then self.tailPercent = value end
    end, function() return tostring(self.tailPercent) end)
    caption(ns.T("dePercent"), 14, -8)
    x = 10
    caption(ns.T("deDuration"), 34, -34)
    self.durationSegment = K.Segment(parent, {{key = 12, label = ns.T("de12Hours")},
        {key = 24, label = ns.T("de24Hours")}, {key = 48, label = ns.T("de48Hours")}}, function(hours)
        self.selling.hours = hours; self:Render()
    end)
    put(self.durationSegment.frame, nil, 12, -34)
    caption(ns.T("deLosses"), 44, -34)
    self.lossEdit = K.Edit(parent, 36); self.lossEdit:SetText("1")
    put(self.lossEdit, 36, 12, -34)
    self:Commit(self.lossEdit, function(text)
        local value = tonumber(text)
        if value and value >= 0 and value <= 100 then self.selling.losses = math.floor(value) end
    end, function() return tostring(self.selling.losses) end)
    K.Tooltip(self.lossEdit, ns.T("deLosses"), ns.T("deDepositTip"))
    caption(ns.T("deDepositShort"), 58, -34)
    self.depositEdit = K.Edit(parent, 66)
    put(self.depositEdit, 66, 12, -34)
    self:Commit(self.depositEdit, function(text)
        local value = tonumber(text)
        if text == "" then self.selling.base = nil
        elseif value and value >= 0 and value <= 10000 then self.selling.base = math.floor(value * 10000 + 0.5) end
    end, function() return self.selling.base and tostring(self.selling.base / 10000) or "" end)
    K.Tooltip(self.depositEdit, ns.T("deDepositOverride"), ns.T("deDepositOverrideTip"))
    self.priceToggle = K.Button(parent, ns.T("dePrices"), 130, function()
        self.pricesExpanded = not self.showPrices; self:Render()
    end, "quiet")
    put(self.priceToggle, 130, 0, -34)
    self.priceEditors = {}
    for i = 1, #ns.disenchantMaterials do
        self.priceEditors[i] = K.QuoteEditor:New(parent, ns.Disenchant.SetPrice, function(id)
            ns.Markets.Scan(id); self:Render()
        end)
    end
end
function UI:Prices()
    local ids = ns.Disenchant.Materials(self.group)
    local width = (self.frame:GetWidth() or 996) - 16
    local columns = math.max(1, math.floor(width / 400))
    local cell = math.floor(width / columns)
    local open = self.filtersOpen
    if open then self.filters:Show() else self.filters:Hide() end
    self.filterToggle:SetActive(open)
    self.filterToggle:SetText(ns.T(open and "deFiltersOpen" or "deFilters"))
    self.showPrices = open and self.pricesExpanded or false
    self.priceToggle:SetActive(self.showPrices)
    self.durationSegment:Select(self.selling.hours)
    for i, editor in ipairs(self.priceEditors) do
        local id = self.showPrices and ids[i]
        if id then
            editor.frame:ClearAllPoints()
            editor.frame:SetPoint("TOPLEFT", self.filters, "TOPLEFT", 8 + ((i - 1) % columns) * cell,
                -64 - math.floor((i - 1) / columns) * 32)
            editor:SetProps({id = id, quote = ns.Disenchant.Quote(id), width = cell - 16,
                disabled = ns.Scan.state.phase ~= "idle" or ns.Buy.Active()})
        else editor.frame:Hide() end
    end
    if not open then return 0 end
    local height = 62 + (self.showPrices and math.ceil(#ids / columns) * 32 + 4 or 0)
    self.filters:SetHeight(height)
    return height + 6
end
function UI:FilterSummary()
    local parts, names = {}, {}
    for quality = 2, 4 do
        if self.qualityChecks[quality]:GetChecked() then names[#names + 1] = ns.T(self.qualityLabels[quality]) end
    end
    parts[#parts + 1] = table.concat(names, ", ")
    if self.maxItemLevel > 0 then parts[#parts + 1] = ns.T("deSummaryLevels", self.minItemLevel, self.maxItemLevel)
    elseif self.minItemLevel > 0 then parts[#parts + 1] = ns.T("deSummaryFrom", self.minItemLevel) end
    if self.tail and not self:PriceLimit() then parts[#parts + 1] = ns.T("deSummaryTail", self.tailPercent) end
    parts[#parts + 1] = ns.T("deHours", self.selling.hours)
    parts[#parts + 1] = ns.T("deSummaryLosses", self.selling.losses)
    parts[#parts + 1] = ns.T("auctionFeeShort", math.floor(ns.Fee() * 100 + 0.5))
    return table.concat(parts, " | ")
end
function UI:LayoutChips(startY)
    local K, D = ns.TradeKit, ns.Disenchant
    local group, f = D.Group(self.group), self.frame
    local target, width = group.targetID, f:GetWidth() or 996
    for _, chip in ipairs(self.chips) do chip:Hide() end
    if not target then self.sourcesLabel:Hide(); return 0 end
    self.sourcesLabel:Show()
    self.sourcesLabel:ClearAllPoints(); self.sourcesLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -startY - 5)
    local roles, weapons, used = self:Roles(), {}, 0
    local function assign(chip, keys, checked, tip)
        chip.bands = keys
        chip:SetChecked(checked)
        K.Tooltip(chip, ns.T("deSources"), tip)
        K.FitButton(chip, 32)
    end
    for _, band in ipairs(D.TargetBands(self.group)) do
        if band.kind == "weapon" then weapons[#weapons + 1] = band
        elseif used < #self.chips then
            used = used + 1
            local chip, out = self.chips[used], D.MainOutput(band, target)
            chip:SetText(ns.T("deBandChip", UI.BandKind(band), band.minLevel, band.maxLevel,
                out.minCount, out.maxCount, ns.TradeKit.Decimal(D.Average(band, target), 2)))
            local role = roles[band.key]
            assign(chip, {band.key}, not self.excludedBands[band.key],
                ns.T(role == "top" and "deBandTopTip" or (role == "low" and "deBandLowTip" or "deBandChipTip")))
        end
    end
    if #weapons > 0 and used < #self.chips then
        used = used + 1
        local chip, keys, enabled = self.chips[used], {}, false
        for _, band in ipairs(weapons) do
            keys[#keys + 1] = band.key
            if not self.excludedBands[band.key] then enabled = true end
        end
        local chance = percent(D.MainOutput(weapons[1], target).chance)
        chip:SetText(ns.T("deWeaponChip", UI.Kind(target), chance))
        assign(chip, keys, enabled, ns.T("deWeaponChipTip", chance))
    end
    local x, line, left = 90, 0, 90
    for i = 1, used do
        local chip = self.chips[i]
        local chipWidth = chip:GetWidth() or 120
        if x + chipWidth > width - 8 and x > left then line, x = line + 1, left end
        chip:ClearAllPoints(); chip:SetPoint("TOPLEFT", f, "TOPLEFT", x, -startY - line * 24)
        chip:Show()
        x = x + chipWidth + 6
    end
    return line + 1
end
function UI:Layout()
    local K, D = ns.TradeKit, ns.Disenchant
    local f, group = self.frame, D.Group(self.group)
    local width, target = f:GetWidth() or 996, group.targetID
    self.modeSegment:Select(target and "target" or "equipment")
    local pickerWidth = math.max(150, math.min(230, width - 700))
    self.groupMenu.frame:SetWidth(pickerWidth); self.targetPicker.frame:SetWidth(pickerWidth)
    self.targetPicker.frame.text:SetWidth(pickerWidth - 34)
    if target then
        self.groupMenu.frame:Hide(); self.groupMenu.cover:Hide(); self.targetPicker.frame:Show()
        self.targetPicker:SetProps({families = D.TargetItems(), raw = target, headingKey = "deTargetMode"})
    else
        self.groupMenu.frame:Show(); self.targetPicker.frame:Hide(); self.targetPicker.cover:Hide()
        self.groupMenu.frame:SetText(ns.T(group.labelKey))
    end
    for quality, chip in pairs(self.qualityChecks) do chip:SetChecked(D.HasQuality(group, quality)) end
    local y = 30 + self:LayoutChips(30) * 24
    if not target then y = 30 end
    self.filters:ClearAllPoints()
    self.filters:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
    self.filters:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -y)
    return y + self:Prices() + 26
end
function UI:Freshness(stale)
    local K, D = ns.TradeKit, ns.Disenchant
    local target, text = D.Group(self.group).targetID, nil
    if target then
        local quote = D.Quote(target)
        if not (quote and quote.price) then text = ns.T("deTargetQuoteNone")
        elseif stale then text = ns.T("deTargetQuoteStale", K.Money(quote.price))
        elseif quote.manual then text = ns.T("deTargetQuoteManual", K.Money(quote.price))
        else text = ns.T("deTargetQuote", K.Money(quote.price), K.Ago(math.max(0, time() - (quote.at or time())))) end
    end
    self.targetQuote:SetText(text or "")
    self.targetQuote:SetJustifyH(target and "LEFT" or "RIGHT")
    self.targetQuote:SetTextColor(unpack(K.theme[stale and "negative" or "secondary"]))
    if text then self.targetQuote:Show(); self.targetQuoteTip:Show()
    else self.targetQuote:Hide(); self.targetQuoteTip:Hide() end
end
function UI:Lines(rows)
    local D = ns.Disenchant
    local byBand, order, lines = {}, {}, {}
    for _, entry in ipairs(rows) do
        local key = entry.meta.band
        if not byBand[key] then
            byBand[key] = {band = D.Band(key), entries = {}, lots = 0}
            order[#order + 1] = byBand[key]
        end
        local bucket = byBand[key]
        bucket.entries[#bucket.entries + 1] = entry
        bucket.lots = bucket.lots + entry.lots
    end
    table.sort(order, function(a, b)
        local weaponA, weaponB = a.band.kind == "weapon", b.band.kind == "weapon"
        if weaponA ~= weaponB then return weaponB end
        if (a.band.quality or 2) ~= (b.band.quality or 2) then return (a.band.quality or 2) < (b.band.quality or 2) end
        return a.band.minLevel > b.band.minLevel
    end)
    for _, bucket in ipairs(order) do
        lines[#lines + 1] = {group = bucket}
        if not self.collapsed[bucket.band.key] then
            for _, entry in ipairs(bucket.entries) do lines[#lines + 1] = {entry = entry, group = bucket} end
        end
    end
    return lines, order
end
function UI:Formula(entry)
    local K, e, lines = ns.TradeKit, entry.estimate, {}
    for _, output in ipairs(e.outputs) do
        lines[#lines + 1] = ns.T("deFormulaLine", ns.Markets.Name(output.id), percent(output.chance),
            ns.TradeKit.Decimal((output.minCount + output.maxCount) / 2, 2), K.Money(output.price),
            K.Money(output.price and output.quantity * output.price))
    end
    if e.margin then
        lines[#lines + 1] = ns.T("deFormulaGross", K.Money(e.gross))
        lines[#lines + 1] = ns.T("deFormulaFee", math.floor(ns.Fee() * 100 + 0.5), K.Money(e.gross * ns.Fee()))
        lines[#lines + 1] = ns.T("deFormulaReserve", K.Money(e.reserve))
        lines[#lines + 1] = ns.T("deFormulaCost", K.Money(entry.cost))
        lines[#lines + 1] = ns.T("deFormulaMargin", K.Money(e.margin), ns.T("deMarginRate", K.Decimal(e.percent or 0, 1, true)))
    else lines[#lines + 1] = ns.T("deFormulaUnknown") end
    return table.concat(lines, "\n")
end
function UI:VendorTip(entry)
    local K, v, e = ns.TradeKit, entry.vendor, entry.estimate
    local compare = e.net and ns.T("vendorDeCompare", K.Money(e.net), K.Money(v.unit))
        or ns.T("vendorDeUnknown", K.Money(v.unit))
    return ns.T("vendorDeLots", v.lots, v.units, K.Money(v.unit), K.Money(v.profit)) .. "\n" .. compare
end
function UI:Via(entry)
    return ns.Disenchant.Via(entry, ns.Disenchant.Group(self.group).targetID)
end
function UI:Yield(entry)
    local parts = {}
    for _, output in ipairs(entry.estimate.outputs) do
        parts[#parts + 1] = ns.T("deYieldPart", UI.Kind(output.id), ns.TradeKit.Decimal(output.quantity, 2))
    end
    return table.concat(parts, " | ")
end
function UI:Outcomes(estimate)
    local outputs, target = {}, ns.Disenchant.Group(self.group).targetID
    for _, output in ipairs(estimate and estimate.outputs or {}) do
        if output.id == target then table.insert(outputs, 1, output) else outputs[#outputs + 1] = output end
    end
    self.outcomes:SetProps({source = self.selected, target = target, outputs = outputs})
end
function UI:Panel(selected, roles)
    local K, D = ns.TradeKit, ns.Disenchant
    local group = D.Group(self.group)
    local parts = {self.note, self.outcomes.frame, self.profitLabel, self.profitValue,
        self.viaLabel, self.viaValue}
    for _, label in ipairs(self.calcKeys) do parts[#parts + 1] = label end
    for _, label in ipairs(self.calcValues) do parts[#parts + 1] = label end
    for _, tile in ipairs(self.scenarios) do parts[#parts + 1] = tile.frame end
    if not selected then
        for _, part in ipairs(parts) do part:Hide() end
        self.outcomes:SetProps({outputs = {}})
        self.panelSelected = nil
        self:ShowNext()
        self.summary:Show()
        self.summary:SetText(ns.T(D.Progress(self.group) and "deRunningGuide"
            or (group.targetID and "deTargetIntro" or "deIntro")) .. "\n\n" .. ns.T("deSelectHint"))
        self:FitPanel(false)
        return
    end
    for _, part in ipairs(parts) do part:Show() end
    self.summary:Hide()
    local band, e = D.Band(selected.meta.band), selected.estimate
    local out, role = D.MainOutput(band, group.targetID), roles[selected.meta.band]
    local note
    if role == "top" then note = nil
    elseif role == "weapon" then note = ns.T("deNoteWeapon", UI.Kind(out.itemID), percent(out.chance))
    elseif role == "low" then
        local upper
        for _, candidate in ipairs(D.TargetBands(self.group)) do
            if candidate.kind == band.kind and candidate.minLevel > band.maxLevel
                and (not upper or candidate.minLevel < upper.minLevel) then upper = candidate end
        end
        local up = upper and D.MainOutput(upper, group.targetID)
        note = up and ns.T("deNoteLow", out.minCount, out.maxCount, upper.minLevel, up.minCount, up.maxCount)
            or ns.T("deNoteSingle", UI.BandKind(band), band.minLevel, band.maxLevel, UI.Kind(out.itemID),
                out.minCount, out.maxCount, percent(out.chance))
    end
    self.note:SetText(note or "")
    self:FitPanel(note ~= nil, not (group.targetID and self:Via(selected)))
    self:Outcomes(e)
    self.panelSelected, self.panelRoles = selected, roles
    local values = {K.Money(e.gross), K.Money(e.gross and -e.gross * ns.Fee()),
        K.Money(e.reserve and -e.reserve), K.Money(-selected.cost),
        K.Money(e.margin) .. (e.percent and (" " .. ns.T("deMarginRate", K.Decimal(e.percent, 1, true))) or "")}
    self.calcKeys[2]:SetText(ns.T("deCalcFee", math.floor(ns.Fee() * 100 + 0.5)))
    for i, label in ipairs(self.calcValues) do label:SetText(values[i]) end
    self.calcValues[5]:SetTextColor(unpack(K.theme[K.Tone(e.margin)]))
    local scenarios = {e.low, e.margin, e.high}
    for i, tile in ipairs(self.scenarios) do
        local value = scenarios[i]
        tile.value:SetText(K.MoneyShort(value))
        tile.value:SetTextColor(unpack(K.theme[K.Tone(value)]))
    end
    local verdict
    if self:PriceLimit() then verdict = ns.T(selected.cost < self.buyPrice and "deProfitCheap" or "deProfitDear")
    elseif e.percent == nil then verdict = ns.T("deProfitUnknown")
    elseif e.percent > self.buyPercent then verdict = ns.T("deProfitYes")
    elseif e.margin > 0 then verdict = ns.T("deProfitLow")
    else verdict = ns.T("deProfitNo") end
    self.profitValue:SetText(verdict)
    local tone = K.Tone(e.margin)
    if self:PriceLimit() then tone = selected.cost < self.buyPrice and "positive" or "secondary" end
    self.profitValue:SetTextColor(unpack(K.theme[tone]))
    local via, rate = self:Via(selected)
    if group.targetID and via then
        self.viaLabel:SetText(ns.T("deViaLabel", UI.KindTitle(group.targetID)))
        self.viaValue:SetText(K.Money(via) .. (rate and (" " .. ns.T("deViaRate", rate)) or ""))
        self.viaValue:SetTextColor(unpack(K.theme[K.Tone(rate and -rate)]))
    else self.viaLabel:Hide(); self.viaValue:Hide() end
    self:ShowNext()
end
function UI:FocusOutcome()
    local selected = self.panelSelected
    if not selected then return end
    self.inspector:SetProps({id = self.outcomes:Focus(selected.id) or selected.id})
    self:Panel(selected, self.panelRoles)
end
function UI:ShowNext()
    local focus = self.outcomes:Focus()
    if not focus then self.next.frame:Hide(); self.calcRule:Show(); return end
    local parts = {self.profitLabel, self.profitValue, self.viaLabel, self.viaValue, self.calcRule}
    for _, label in ipairs(self.calcKeys) do parts[#parts + 1] = label end
    for _, label in ipairs(self.calcValues) do parts[#parts + 1] = label end
    for _, tile in ipairs(self.scenarios) do parts[#parts + 1] = tile.frame end
    for _, part in ipairs(parts) do part:Hide() end
    self.next:SetProps({id = focus, back = function() self.outcomes:Toggle(focus) end, open = ns.TradeKit.OpenNext})
end
function UI:FitPanel(withNote, short)
    local inset = ns.TradeKit.theme.inset
    local height = (withNote and 30 or 0) + self.calcHeight - (short and ns.TradeKit.theme.valueStep or 0)
    if withNote then self.note:Show() else self.note:Hide() end
    self.calc:ClearAllPoints(); self.calc:SetPoint("TOPLEFT", self.panelChild, "TOPLEFT", 0, withNote and -30 or 0)
    local width = self.panelScroll:Fit(height)
    local inner = width - 2 * inset
    self.calc:SetWidth(width)
    self.note:SetWidth(inner); self.summary:SetWidth(inner)
    local tile = math.floor((inner - 8) / 3)
    for i, card in ipairs(self.scenarios) do
        local x = inset + (i - 1) * (tile + 4)
        local last = i == #self.scenarios and inner - 2 * (tile + 4) or tile
        card.frame:SetWidth(last); card.frame:ClearAllPoints()
        card.frame:SetPoint("TOPLEFT", self.calc, "TOPLEFT", x, -228)
        card.title:SetWidth(last - 8); card.value:SetWidth(last - 8)
    end
    self.outcomes.frame:SetWidth(inner)
    self.next.frame:SetWidth(inner)
end
function UI:Render()
    if not self.frame then return end
    local K, D, selected = ns.TradeKit, ns.Disenchant
    local group = D.Group(self.group)
    local target = group.targetID
    local rows = self.sorter:Apply(D.Rows(self.group, ns.Fee(), self.selling, self.minItemLevel,
        self.tail and not self:PriceLimit() and self.tailPercent or nil, self.maxItemLevel, self.includeNoLevel,
        self:Excluded()), {
        item = function(entry) return ns.Markets.Name(entry.id) end,
        price = function(entry) return entry.cost end,
        ilvl = function(entry) return entry.meta.level end,
        margin = function(entry) return entry.estimate.margin end,
        rate = function(entry) return entry.estimate.percent end,
        via = function(entry) local via = self:Via(entry); return via and -via or nil end,
        viaRate = function(entry) local _, rate = self:Via(entry); return rate and -rate or nil end,
    })
    local progress = D.Progress(self.group)
    local top = self:Layout()
    local f = self.frame
    local width = (f:GetWidth() or 996) - 300
    local columns = K.DisenchantColumns(width, target ~= nil)
    self.headers.via:SetText(ns.T("deColVia", target and UI.KindTitle(target) or ""))
    K.PlaceHeaders(self.headers, columns, f, -(top - 18), true)
    self.sorter:Mark()
    self.headerBand:ClearAllPoints()
    self.headerBand:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(top - 20))
    self.headerBand:SetPoint("TOPRIGHT", f, "TOPRIGHT", -290, -(top - 20))
    local lines, order = self:Lines(rows)
    local roles = self:Roles()
    local bottom = self:PlaceFooter()
    local visible = K.ListCapacity(f, top, bottom, 24, #self.rows + #self.groups)
    self.scroll.frame:ClearAllPoints()
    self.scroll.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -top)
    self.scroll.frame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -272, bottom)
    self.inspector:Place(-(top - 25), 30)
    self.empty:ClearAllPoints(); self.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -top - 10)
    self.empty:SetWidth(math.max(100, width - 20))
    local offset = self.scroll:SetRange(#lines, visible)
    for _, entry in ipairs(rows) do if entry.id == self.selected then selected = entry end end
    if not selected then selected = order[1] and order[1].entries[1]; self.selected = selected and selected.id end
    local usedRows, usedGroups = 0, 0
    local shot = D.Snapshot(self.group)
    local since = shot and (shot.t + (shot.secs or 0))
    for i = 1, visible do
        local line = lines[offset + i]
        if line and line.entry then
            usedRows = usedRows + 1
            local row, entry = self.rows[usedRows], line.entry
            if row then
                row.frame:ClearAllPoints(); row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -top - (i - 1) * 24)
                local via, rate = self:Via(entry)
                local bought, boughtTone, boughtTip = K.BoughtMark(entry.id, since)
                row:SetProps({id = entry.id, width = width, target = target ~= nil, quality = entry.meta.quality or 2,
                    level = entry.meta.level, cost = entry.cost,
                    margin = entry.estimate.margin, percent = entry.estimate.percent, via = via, viaRate = rate,
                    active = entry.id == self.selected,
                    match = self:PriceLimit() and entry.cost < self.buyPrice or not self:PriceLimit()
                        and entry.estimate.percent ~= nil and entry.estimate.percent > self.buyPercent,
                    tip = ns.T("deRow", entry.meta.level, entry.meta.skill) .. "\n" .. self:Formula(entry)
                        .. (entry.vendor and ("\n\n" .. self:VendorTip(entry)) or "")
                        .. (boughtTip and ("\n\n" .. boughtTip) or ""),
                    tag = bought or (entry.vendor and ns.T("vendorTag", K.MoneyShort(entry.vendor.profit)) or nil),
                    tagTone = boughtTone,
                    actionDisabled = not self:CanPurchase() or (self:PriceLimit() and entry.cost >= self.buyPrice)
                        or (not self:PriceLimit() and not entry.estimate.percent)
                        or entry.cost > GetMoney()})
            end
        elseif line then
            usedGroups = usedGroups + 1
            local header, bucket = self.groups[usedGroups], line.group
            if header then
                header.frame:ClearAllPoints(); header.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -top - (i - 1) * 24)
                local band, out = bucket.band, D.MainOutput(bucket.band, target)
                local role = roles[band.key]
                header:SetProps({key = band.key, width = width, open = not self.collapsed[band.key], height = 24,
                    name = ns.T("deBandHeader", UI.BandKind(band), band.minLevel, band.maxLevel),
                    detail = ns.T("deBandLots", bucket.lots) .. "   " .. ns.T("deBandYield", UI.Kind(out.itemID),
                        out.minCount, out.maxCount),
                    tag = role == "top" and ns.T("deBandTop") or (role == "low" and ns.T("deBandLow")
                        or (role == "weapon" and ns.T("deBandWeapon") or nil)),
                    tip = (role == "top" and ns.T("deBandTopTip") .. "\n\n" or (role == "low" and ns.T("deBandLowTip")
                        .. "\n\n" or "")) .. ns.T("deBandTip")})
            end
        end
    end
    for i = usedRows + 1, #self.rows do self.rows[i].frame:Hide() end
    for i = usedGroups + 1, #self.groups do self.groups[i].frame:Hide() end
    local scan = D.Snapshot(self.group)
    local emptyKey = progress and (progress.stage == "materials" and "dePreparingEmpty" or "deSearchingEmpty")
        or (scan and "deFinishedEmpty" or "deEmpty")
    self.empty:SetText(#rows == 0 and ns.T(emptyKey) or "")
    local snapshot = scan and ns.T("deSnapshot", date("%d.%m %H:%M", scan.t + scan.secs)) or ns.T("deNotScanned")
    if scan and (scan.miss or 0) > 0 then snapshot = snapshot .. ns.T("deUnread", scan.miss) end
    if scan and not progress then
        if scan.deSavedPartial then snapshot = ns.T("dePartialSaved", scan.deReadPages or 0, #scan.lots)
        elseif scan.deCut and scan.dePriceLimit then
            snapshot = ns.T("deCutPriceStatus", scan.deReadPages, K.Money(scan.dePriceLimit))
        elseif scan.deCut then snapshot = ns.T("deCutStatus", scan.deReadPages, scan.dePercent)
        elseif scan.deCutStopped then snapshot = ns.T("deCutStopped", ns.T("deCutReason" .. scan.deCutStopped))
        elseif scan.deCutDisabled then snapshot = ns.T("deCutUnavailable") end
    end
    if selected then self.inspector:SetProps({id = self.outcomes:Focus(selected.id) or selected.id}); self.item:Show()
    else self.inspector:Clear() end
    self:Panel(selected, roles)
    self.preview = D.PurchasePlan(self.group, self:Options())
    local buyGroup = D.Group(D.purchase and D.purchase.key or self.group)
    self.buyContext = buyGroup.targetID and ns.Markets.Name(buyGroup.targetID) or ns.T(buyGroup.labelKey)
    local plan, primary, age = self.preview, self:Primary(), self:SnapshotAge()
    local aged = primary == "scan" and age
    local previewText = plan.margin and ns.T("deBuyPreviewMargin", plan.count, K.Money(plan.cost), K.Money(plan.margin))
        or ns.T("deBuyPreview", plan.count, K.Money(plan.cost))
    if primary ~= "buy" and not aged then previewText = ""
    elseif plan.count == 0 and not D.purchase then
        local rejected = plan.rejected
        previewText = not aged and not ns.Scan.state.open and ns.T("deBuyClosed")
            or rejected.money > 0 and ns.T("deBuyNoMoney")
            or rejected.unknown > 0 and ns.T("deBuyUnknown")
            or self:PriceLimit() and ns.T("deBuyBelowPrice", K.Money(self.buyPrice))
            or rejected.threshold > 0 and ns.T("deBuyBelowThreshold", self.buyPercent)
            or ns.T("deBuyEmpty")
    end
    self.previewText = previewText
    local parts = {ns.T("deResultCount", #rows), snapshot}
    if previewText ~= "" then parts[#parts + 1] = previewText end
    self.statusText = table.concat(parts, " | ")
    ns.Trader.RenderStatus()
    self:Freshness(self.preview.stale > 0)
    self:Controls()
end
function UI:ProgressText()
    local progress = ns.Disenchant.Progress(self.group)
    if not progress then return nil end
    local pages = progress.pages > 0 and tostring(progress.pages) or "?"
    local text = progress.stage == "materials"
        and ns.T("deProgressMaterials", progress.index, progress.total, progress.name, progress.page, pages)
        or ns.T("deProgressEquipment", progress.page, pages, progress.lots)
    if progress.paused then text = ns.T("deProgressPaused", text) end
    if progress.stage == "equipment" and progress.classIndex and GetAuctionItemClasses then
        local class = ({GetAuctionItemClasses()})[progress.classIndex]
        if progress.minLevel then class = ns.T("deQueryLevels", class, progress.minLevel, progress.maxLevel) end
        text = ns.T("deProgressClass", class, text)
    end
    return text
end
function UI:NewTop(f)
    local K = ns.TradeKit
    self.modeSegment = K.Segment(f, {{key = "target", label = ns.T("deModeTarget")},
        {key = "equipment", label = ns.T("deEquipmentMode")}}, function(mode) self:SelectMode(mode) end,
        {ns.T("deTargetMode"), ns.T("deTargetModeTip")})
    self.modeSegment.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -3)
    local entries = {}
    for _, group in ipairs(ns.Disenchant.groups) do
        if group.quality == 2 then entries[#entries + 1] = {key = group.key, labelKey = group.labelKey} end
    end
    self.groupMenu = K.Menu(f, entries, function(key)
        local selection = ns.Disenchant.Selection(key, self.qualities)
        if selection then self:SelectGroup(selection) end
    end)
    self.groupMenu.frame:SetPoint("LEFT", self.modeSegment.frame, "RIGHT", 8, 0)
    self.targetPicker = K.FamilyPicker:New(f, function(id)
        self:SelectGroup(ns.Disenchant.Selection("target" .. id, self.qualities))
    end)
    self.targetPicker.frame:SetPoint("LEFT", self.modeSegment.frame, "RIGHT", 8, 0)
    self.targetQuote = K.Label(f, "", 0, 0, 260, "secondary")
    self.targetQuote:SetHeight(12)
    self.targetQuote:ClearAllPoints(); self.targetQuote:SetPoint("LEFT", self.targetPicker.frame, "RIGHT", 10, 0)
    self.targetQuoteTip = ns.NewFrame("Frame", nil, f)
    self.targetQuoteTip:SetAllPoints(self.targetQuote)
    self.targetQuoteTip:EnableMouse(true)
    K.Tooltip(self.targetQuoteTip, ns.T("deTargetQuoteTitle"), ns.T("deTargetQuoteTip"))
    K.Tooltip(self.targetPicker.frame, ns.T("deTargetMode"), ns.T("deTargetModeTip"))
    self.scanAll = K.Button(f, ns.T("deScanAll"), 52, function() self:StartScan("all") end)
    self.scanAll:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -3)
    self.scan = K.Button(f, ns.T("deScanEquipment"), 62, function() self:StartScan("equipment") end)
    self.scan:SetPoint("RIGHT", self.scanAll, "LEFT", -4, 0)
    self.scanMaterials = K.Button(f, ns.T("deScanMaterials"), 80, function() self:StartScan("materials") end)
    self.scanMaterials:SetPoint("RIGHT", self.scan, "LEFT", -4, 0)
    local refresh = K.Label(f, ns.T("deRefresh"), 0, 0, 70, "secondary")
    refresh:ClearAllPoints(); refresh:SetPoint("RIGHT", self.scanMaterials, "LEFT", -6, 0)
    refresh:SetJustifyH("RIGHT")
    K.ScanTip(self.scan, ns.T("deScanEquipment"), ns.T("deScanEquipmentTip"), function()
        return ns.Disenchant.ScanSources(self.group, self:ScanOptions(), "equipment")
    end, true, {modes = {"hard"}, age = function() return self:EquipmentAge() end})
    K.ScanTip(self.scanMaterials, ns.T("deScanMaterials"), ns.T("deScanMaterialsTip"), function()
        return ns.Disenchant.ScanSources(self.group, self:ScanOptions(), "materials")
    end)
    K.ScanTip(self.scanAll, ns.T("deScanAll"), ns.T("deScanAllTip"), function()
        return ns.Disenchant.ScanSources(self.group, self:ScanOptions(), "all")
    end, true, {age = function() return self:EquipmentAge(ns.Disenchant.ScanSources(self.group, nil, "materials")) end})
    self.filterToggle = K.Button(f, ns.T("deFilters"), 84, function()
        self.filtersOpen = not self.filtersOpen; self:Render()
    end, "quiet")
    self.filterToggle:SetPoint("RIGHT", refresh, "LEFT", -14, 0)
    K.Tooltip(self.filterToggle, ns.T("deFilters"), ns.T("deFiltersTip"))
    self.filterToggle.tipFn = function() return ns.T("deFiltersTip") .. "\n\n" .. self:FilterSummary() end
    self.targetQuote:SetPoint("RIGHT", self.filterToggle, "LEFT", -8, 0)
    self.sourcesLabel = K.Label(f, ns.T("deSources"), 10, -35, 76, "secondary")
    self.sourcesLabel:SetHeight(12)
    for i = 1, 8 do
        local chip
        chip = K.Chip(f, "", function(checked)
            for _, key in ipairs(chip.bands or {}) do self.excludedBands[key] = (not checked) or nil end
            self:Save(); self:Render()
        end)
        chip:Hide()
        self.chips[i] = chip
    end
    self.filters = K.Card(f)
    self.filters:SetHeight(62)
    self:NewSettings(self.filters)
end
function UI:NewTable(f)
    local K = ns.TradeKit
    self.headerBand = K.TableHeader(f, -60)
    self.headers = {}
    for _, entry in ipairs({{"item", "deColItem"}, {"ilvl", "deColIlvl"}, {"price", "deColBuy"},
        {"margin", "deColMargin"}, {"rate", "deColRate"}, {"via", "deColVia"}, {"viaRate", "deColViaRate"}}) do
        local label = K.Label(f, ns.T(entry[2], 5), 0, -38, 100)
        label:SetHeight(12)
        if entry[1] ~= "item" then label:SetJustifyH("RIGHT") end
        self.headers[entry[1]] = label
    end
    self.sorter = K.Sorter(f, self.headers, function() self.scroll.offset = 0; self:Render() end, nil, {key = "margin", desc = true})
    for key, tipKey in pairs({margin = "deColMarginTip", rate = "deColRateTip", via = "deColViaTip", viaRate = "deColViaRateTip"}) do
        local button = self.sorter.buttons[key]
        K.Tooltip(button, ns.T("sortTitle"), ns.T(tipKey) .. "\n\n" .. ns.T("sortTip"))
    end
    self.scroll = K.Scroller:New(f, function() self:Render() end, 24)
    for i = 1, 40 do
        local row = K.DisenchantRow:New(f, function(id) self.selected, self.chosen = id, id; self:Render() end, self.buyRow)
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -80 - (i - 1) * 24)
        row.frame:Hide(); self.scroll:Wheel(row.frame); self.rows[i] = row
    end
    for i = 1, 12 do
        local header = K.GroupRow:New(f, function(key) self.collapsed[key] = not self.collapsed[key]; self:Render() end)
        header.frame:Hide(); self.scroll:Wheel(header.frame); self.groups[i] = header
    end
    self.empty = K.Label(f, "", 10, -90, 400, "secondary"); self.empty:SetHeight(80)
end
function UI:NewBottom(f)
    local K = ns.TradeKit
    self.buyModes = K.Segment(f, {{key = "margin", label = ns.T("buyModeMargin")},
        {key = "price", label = ns.T("buyModePrice")}}, function(mode)
        if self.buyMode ~= mode then self:SetBuyMode(mode) end
    end, {ns.T("buyModePrice"), ns.T("deBuyModeTip")})
    self.buyModes.frame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 6)
    self.buyLabel = K.Label(f, ns.T("deBuyThreshold"), 0, 0, 90, "secondary")
    self.buyLabel:SetHeight(12)
    self.buyLabel:ClearAllPoints(); self.buyLabel:SetPoint("LEFT", self.buyModes.frame, "RIGHT", 12, 0)
    self.buyEdit = K.Edit(f, 60); self.buyEdit:SetText(tostring(self:PriceLimit() and self.buyPrice / 10000 or self.buyPercent))
    self.buyEdit:SetPoint("LEFT", self.buyLabel, "RIGHT", 4, 0)
    self:Commit(self.buyEdit, function(text)
        local value = tonumber(text)
        if self:PriceLimit() then
            if value and value >= 0.0001 and value <= 100000 then self.buyPrice = math.floor(value * 10000 + 0.5) end
        elseif value and value > -100 and value <= 1000 then self.buyPercent = value end
    end, function() return tostring(self:PriceLimit() and self.buyPrice / 10000 or self.buyPercent) end)
    K.Tooltip(self.buyEdit, ns.T("buyPriceLimit"), ns.T("deBuyModeTip"))
    self.buyUnit = K.Label(f, ns.T("dePercent"), 0, 0, 16, "secondary")
    self.buyUnit:SetHeight(12)
    self.buyUnit:ClearAllPoints(); self.buyUnit:SetPoint("LEFT", self.buyEdit, "RIGHT", 3, 0)
    self.shownFrom = K.Label(f, "", 0, 0, 110, "secondary")
    self.shownFrom:SetHeight(12)
    self.shownFrom:ClearAllPoints(); self.shownFrom:SetPoint("LEFT", self.buyUnit, "RIGHT", 8, 0)
    self.buy = K.Button(f, ns.T("deBuyByMargin"), 170, function() self:Main() end, "main")
    self.buy:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -282, 4)
    K.Tooltip(self.buy, ns.T("deBuyByMargin"), "")
    self.buy.tipFn = function()
        local body = self.mainTip or ""
        if self.mainPart then
            body = body .. "\n\n" .. K.ScanRule() .. "\n\n"
                .. ns.Batch.PreviewText(ns.Disenchant.ScanSources(self.group, self:ScanOptions(), self.mainPart), true)
        end
        local preview = self.previewText or ""
        if self.buy.btnDisabled and self.mainReason and self.mainReason ~= "" then body = self.mainReason .. "\n\n" .. body
        elseif preview ~= "" then body = preview .. "\n\n" .. body end
        return body
    end
    self.nextStep = K.Button(f, ns.T("deNextStep"), 262, function() ns.AccountingUI.OpenNextStep() end, "quiet")
    self.nextStep:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 4)
    K.Tooltip(self.nextStep, ns.T("deNextStep"), ns.T("deNextStepTip"))
end
function UI:PlaceFooter()
    local shown = not self:PriceLimit() and (not self.tail and ns.T("deShownAll")
        or self.tailPercent ~= self.buyPercent and ns.T("deShownFrom", self.tailPercent)) or ""
    self.shownFrom:SetText(shown); self.shownFrom:SetWidth(shown == "" and 1 or 110)
    return 40
end
function UI:NewPanel()
    local K = ns.TradeKit
    self.inspector = K.Inspector:New(self.frame)
    local panel = self.inspector.body
    self.item = self.inspector.item
    self.panelScroll = K.PanelScroll:New(self.inspector, "ManaCodeDisenchantPanelScroll", 356)
    self.scrollBody, self.panelChild = self.panelScroll.frame, self.panelScroll.child
    local c = self.panelChild
    self.note = K.Label(c, "", 12, -4, 210, "secondary")
    self.note:SetHeight(26); self.note:SetJustifyV("TOP")
    local k = ns.NewFrame("Frame", nil, c)
    k:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -30); k:SetWidth(264)
    self.calc, self.calcHeight = k, 303
    k:SetHeight(self.calcHeight)
    self.outcomes = K.OutcomeList:New(k, function() self:FocusOutcome() end)
    self.outcomes.frame:ClearAllPoints()
    self.outcomes.frame:SetPoint("TOPLEFT", k, "TOPLEFT", 12, -4)
    self.outcomes.frame:SetWidth(240); self.outcomes.frame:SetHeight(3 * 46)
    self.cards = self.outcomes.cards
    local texts = {}
    for i, key in ipairs({"deCalcGross", "deCalcFee", "deCalcReserve", "deCalcCost", "deCalcMargin"}) do texts[i] = ns.T(key, 5) end
    self.calcKeys, self.calcValues = K.ValueRows(k, -148, texts, {labelWidth = 120, valueWidth = 130, gap = 4, strong = true})
    for i = 1, 4 do self.calcValues[i]:SetTextColor(unpack(K.theme.secondary)) end
    self.calcRule = K.Rule(k, -220)
    self.next = K.NextUses:New(k)
    self.next.frame:SetPoint("TOPLEFT", k, "TOPLEFT", 12, -148); self.next.frame:SetWidth(240)
    self.scenarios = {}
    for i, key in ipairs({"deScenarioLow", "deScenarioAverage", "deScenarioHigh"}) do
        local tile = {frame = K.Card(k)}
        tile.frame:SetHeight(40); tile.frame:EnableMouse(true)
        tile.frame:SetPoint("TOPLEFT", k, "TOPLEFT", 12 + (i - 1) * 80, -228)
        tile.frame:SetWidth(76)
        tile.title = K.Label(tile.frame, ns.T(key), 4, -6, 68, "secondary")
        tile.title:SetHeight(12); tile.title:SetJustifyH("CENTER")
        tile.value = K.Label(tile.frame, "", 4, -21, 68)
        tile.value:SetHeight(12); tile.value:SetJustifyH("CENTER")
        K.Tooltip(tile.frame, ns.T("deScenarios"), ns.T("deScenarioTip"))
        self.scenarios[i] = tile
    end
    self.profitLabel, self.profitValue = K.ValueRow(k, ns.T("deProfitable"), -278, 80, 170)
    self.viaLabel, self.viaValue = K.ValueRow(k, "", -278 - K.theme.valueStep, 110, 140)
    self.summary = K.Label(c, "", 12, -4, 222, "secondary")
    self.summary:SetHeight(300); self.summary:SetJustifyV("TOP")
    self.inspector:SetInfo(ns.T("deTitle"), ns.T("deModelTip"))
end
function UI:New(parent)
    self:RestoreSelection()
    self.buyRow = function(id) self:Purchase(id) end
    self.frame = ns.NewFrame("Frame", nil, parent)
    local f = self.frame; f:SetAllPoints(parent)
    self:NewTop(f)
    self:NewTable(f)
    self:NewBottom(f)
    self:NewPanel()
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
