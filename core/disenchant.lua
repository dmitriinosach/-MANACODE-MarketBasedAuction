local _, ns = ...
local D = {}
ns.Disenchant = D
D.priceSeconds = 1800
D.RARE = 0.05
D.groups = {
    {key = "wrathArmor", labelKey = "deWrathArmor", expansion = "wrath", classIndex = 2, minLevel = 68, maxLevel = 80},
    {key = "wrathWeapon", labelKey = "deWrathWeapon", expansion = "wrath", classIndex = 1, minLevel = 68, maxLevel = 80},
    {key = "bcArmor", labelKey = "deBCArmor", expansion = "bc", classIndex = 2, minLevel = 57, maxLevel = 70},
    {key = "bcWeapon", labelKey = "deBCWeapon", expansion = "bc", classIndex = 1, minLevel = 57, maxLevel = 70},
}
for i = 1, 4 do
    local base = D.groups[i]
    base.quality = 2
    for quality = 3, 4 do
        D.groups[#D.groups + 1] = {key = base.key .. "_" .. quality, base = base.key,
            labelKey = base.labelKey, expansion = base.expansion, classIndex = base.classIndex,
            minLevel = base.minLevel, maxLevel = base.maxLevel, quality = quality}
    end
end
function D.Group(key)
    if D.targetGroups and D.targetGroups[key] then return D.targetGroups[key] end
    if D.maskedGroups and D.maskedGroups[key] then return D.maskedGroups[key] end
    for _, group in ipairs(D.groups) do if group.key == key then return group end end
    local target, targetMask = key:match("^target(%d+)_(%d+)$")
    if target then
        local id, qualities, minimum, maximum, found = tonumber(target), {}, 4, 0, false
        for digit in targetMask:gmatch("%d") do
            local quality = tonumber(digit)
            if quality < 2 or quality > 4 then return nil end
            qualities[quality], minimum = true, math.min(minimum, quality)
        end
        local group = {key = key, base = "target" .. target, labelKey = "deTargetMode",
            targetID = id, qualities = qualities, quality = minimum, minLevel = 0, maxLevel = 80}
        for _, band in ipairs(ns.disenchantBands) do
            if D.Matches(group, band) then
                found = true; maximum = math.max(maximum, band.maxRequiredLevel or 80)
                group.minItemLevel = math.min(group.minItemLevel or math.huge, band.minLevel)
                group.maxItemLevel = math.max(group.maxItemLevel or 0, band.maxLevel)
            end
        end
        if not found then
            local valid = false
            for _, material in ipairs(ns.disenchantMaterials) do if id == material then valid = true end end
            if not valid then return nil end
        end
        group.maxLevel = found and maximum or 80
        D.targetGroups = D.targetGroups or {}
        D.targetGroups[key] = group
        return group
    end
    local base, mask = key:match("^(%a+)_(%d+)$")
    if not base then return nil end
    local source = D.Group(base)
    if not source then return nil end
    local qualities, minimum = {}, 4
    for digit in mask:gmatch("%d") do
        local quality = tonumber(digit)
        if quality < 2 or quality > 4 then return nil end
        qualities[quality], minimum = true, math.min(minimum, quality)
    end
    D.maskedGroups = D.maskedGroups or {}
    D.maskedGroups[key] = {key = key, base = base, labelKey = source.labelKey, expansion = source.expansion,
        classIndex = source.classIndex, minLevel = source.minLevel, maxLevel = source.maxLevel,
        qualities = qualities, quality = minimum}
    return D.maskedGroups[key]
end
function D.HasQuality(group, quality)
    return group.qualities and group.qualities[quality] or (not group.qualities and group.quality == quality)
end
function D.Selection(base, qualities)
    local mask = ""
    for quality = 2, 4 do if qualities[quality] then mask = mask .. quality end end
    if mask == "" then return nil end
    if base:match("^target%d+$") then return base .. "_" .. mask end
    return mask == "2" and base or base .. "_" .. mask
end
function D.Matches(group, band)
    if group.targetID then
        return D.HasQuality(group, band.quality or 2) and D.Output(band, group.targetID) ~= nil
    end
    local kind = group.classIndex == 1 and "weapon" or "armor"
    return band.expansion == group.expansion and D.HasQuality(group, band.quality or 2)
        and (band.kind == kind or band.kind == "any" or (group.classIndex == 2 and (band.quality or 2) == 2)
            or band.searchClasses and band.searchClasses[group.classIndex])
end
function D.Output(band, id)
    for _, output in ipairs(band and band.outputs or {}) do
        if output.itemID == id and output.chance > 0 then return output end
    end
end
function D.Accepts(group, meta)
    if not group or not meta or not D.HasQuality(group, meta.quality or 2) then return false end
    local band = D.Band(meta.band)
    if group.targetID then return D.Output(band, group.targetID) ~= nil end
    return band and band.expansion == group.expansion and meta.classIndex == group.classIndex
end
function D.WithinLevels(meta, minimum, maximum)
    return meta.level >= (minimum or 0) and (not maximum or maximum == 0 or meta.level <= maximum)
end
function D.RequiredRange(key, classIndex, options)
    options = options or {}
    local group, minimum, maximum = D.Group(key), 81, 0
    if options.includeNoLevel then return 0, group.maxLevel end
    for _, band in ipairs(ns.disenchantBands) do
        local levels = ns.disenchantRequiredLevels[band.key]
        levels = levels and levels[classIndex]
        if levels and D.Matches(group, band) then
            for level, range in pairs(levels) do
                if D.WithinLevels({level = level}, options.minItemLevel, options.maxItemLevel) and range[2] > 0 then
                    minimum, maximum = math.min(minimum, range[1]), math.max(maximum, range[2])
                end
            end
        end
    end
    if maximum == 0 then return math.max(1, group.minLevel), group.maxLevel end
    return minimum, maximum
end
function D.TargetItems()
    local out = {}
    for _, id in ipairs(ns.disenchantMaterials) do out[#out + 1] = {raw = id} end
    return out
end
function D.Materials(key)
    local ids, seen, group = {}, {}, D.Group(key)
    for _, band in ipairs(ns.disenchantBands) do
        if D.Matches(group, band) then
            for _, output in ipairs(band.outputs) do
                if not seen[output.itemID] then ids[#ids + 1] = output.itemID; seen[output.itemID] = true end
            end
        end
    end
    table.sort(ids)
    return ids
end
local function prices()
    local db = ns.Store.DB()
    local key = ns.Markets.Key()
    db.disenchantPrices = db.disenchantPrices or {}
    db.disenchantPrices[key] = db.disenchantPrices[key] or {}
    return db.disenchantPrices[key]
end
function D.SetPrice(id, copper)
    local valid = false
    for _, material in ipairs(ns.disenchantMaterials) do if material == id then valid = true end end
    if not valid or (copper and (copper ~= copper or copper < 0 or copper > 1000000000)) then return false end
    prices()[id] = copper and math.floor(copper + 0.5) or nil
    return true
end
function D.Quote(id)
    local q, value = ns.Markets.Quote(id), prices()[id]
    if value == nil then return q end
    return {price = value, miss = 0, complete = true, manual = true, at = time()}
end
function D.Fresh(id)
    local quote = D.Quote(id)
    return quote and quote.manual or ns.Markets.Fresh(id, D.priceSeconds)
end
function D.Candidate(id, link)
    if ns.disenchantExcluded and ns.disenchantExcluded[id] then return false end
    local name, _, quality, level, required, class, _, _, equip = ns.Compat.ItemInfo(link or id)
    if not name or not quality or not level or not class then return nil end
    if quality < 2 or quality > 4 or not GetAuctionItemClasses then return false end
    local weapon, armor = GetAuctionItemClasses()
    local kind = class == weapon and "weapon" or (class == armor and "armor")
    if not kind or equip == "INVTYPE_BAG" or equip == "INVTYPE_BODY" or equip == "INVTYPE_TABARD"
        or equip == "INVTYPE_QUIVER" or equip == "" then return false end
    local override = ns.disenchantOverrides[id]
    if override and override.band then
        if level ~= override.level or quality ~= override.quality then return false end
        return {band = override.band, level = level, skill = override.skill,
            classIndex = class == weapon and 1 or 2, required = required, quality = quality}
    end
    if quality == 2 and (equip == "INVTYPE_SHIELD" or equip == "INVTYPE_HOLDABLE") then kind = "weapon" end
    if override then kind = override.kind end
    for _, band in ipairs(ns.disenchantBands) do
        if not band.exactOnly and (band.quality or 2) == quality and (band.kind == kind or band.kind == "any")
            and level >= band.minLevel and level <= band.maxLevel
            and (not override or override.lootId == band.lootId) then
            return {band = band.key, level = level, skill = override and override.skill or band.skill,
                classIndex = class == weapon and 1 or 2, required = required, quality = quality}
        end
    end
    return false
end
function D.Band(key)
    if not D.byBand then
        D.byBand = {}
        for _, band in ipairs(ns.disenchantBands) do D.byBand[band.key] = band end
    end
    return D.byBand[key]
end
function D.Via(entry, targetID)
    local target = entry.target
    if not target then return nil end
    local average = target.chance * (target.minCount + target.maxCount) / 2
    if average <= 0 then return nil end
    local via = entry.cost / average
    local quote = D.Quote(targetID)
    local price = quote and quote.price
    return via, price and price > 0 and (via / price - 1) * 100 or nil
end
function D.MaterialVia(id)
    local snapshot
    local function consider(scan)
        local group = scan.deGroup and D.Group(scan.deGroup)
        if group and group.targetID == id and (not snapshot or scan.t + scan.secs > snapshot.t + snapshot.secs) then
            snapshot = scan
        end
    end
    for _, scan in ipairs(ns.Store.DB().scans) do if scan.deGroup then consider(scan) end end
    for _, scan in pairs(ns.Store.DB().disenchantDrafts or {}) do consider(scan) end
    if not snapshot then return nil end
    local best
    for _, text in ipairs(snapshot.lots) do
        local lot = ns.Lot.Decode(text)
        local meta = lot and snapshot.disenchantItems and snapshot.disenchantItems[lot.item]
        local band = meta and D.Band(meta.band)
        local output = band and D.Output(band, id)
        if output and lot.count > 0 and lot.buyout > 0 and lot.owner ~= "" and lot.owner ~= UnitName("player") then
            local value = D.Via({cost = lot.buyout / lot.count, target = output}, id)
            if value and (not best or value < best.price) then
                best = {price = value, via = true, complete = true, miss = 0, itemID = lot.item,
                    scanID = snapshot.id, at = snapshot.t + snapshot.secs, limited = snapshot.complete == false
                        or snapshot.truncated or (snapshot.miss or 0) > 0}
            end
        end
    end
    return best
end
function D.TargetBands(key)
    local group, list = D.Group(key), {}
    if not group or not group.targetID then return list end
    for _, band in ipairs(ns.disenchantBands) do
        if D.Matches(group, band) then list[#list + 1] = band end
    end
    table.sort(list, function(a, b)
        local weaponA, weaponB = a.kind == "weapon", b.kind == "weapon"
        if weaponA ~= weaponB then return weaponB end
        if (a.quality or 2) ~= (b.quality or 2) then return (a.quality or 2) < (b.quality or 2) end
        return a.minLevel > b.minLevel
    end)
    return list
end
function D.MainOutput(band, targetID)
    local output = targetID and D.Output(band, targetID)
    if output then return output end
    local best = band.outputs[1]
    for _, candidate in ipairs(band.outputs) do if candidate.chance > best.chance then best = candidate end end
    return best
end
function D.DefaultExcluded(key)
    local excluded, groups, group = {}, {}, D.Group(key)
    for _, band in ipairs(D.TargetBands(key)) do
        if band.kind == "weapon" then excluded[band.key] = true
        else
            local family = band.kind .. (band.quality or 2)
            groups[family] = groups[family] or {}
            table.insert(groups[family], band)
        end
    end
    for _, bands in pairs(groups) do
        if #bands > 1 then
            local low, high = bands[1], bands[1]
            for _, band in ipairs(bands) do
                if D.Average(band, group.targetID) < D.Average(low, group.targetID) then low = band end
                if D.Average(band, group.targetID) > D.Average(high, group.targetID) then high = band end
            end
            if low ~= high then excluded[low.key] = true end
        end
    end
    return excluded
end
function D.Average(band, targetID)
    local output = D.MainOutput(band, targetID)
    return output.chance * (output.minCount + output.maxCount) / 2
end
function D.ScanSources(key, options, part)
    part = part or "all"
    local group, sources = D.Group(key), {}
    if not group then return sources end
    if part ~= "equipment" then
        for _, id in ipairs(D.Materials(key)) do
            local quote = D.Quote(id)
            if not (quote and quote.manual) then sources[#sources + 1] = id end
        end
    end
    if part ~= "materials" then
        local ranges = {}
        for _, class in ipairs(group.targetID and {2, 1} or {group.classIndex}) do
            local low, high = D.RequiredRange(key, class, options)
            ranges[class] = {minLevel = low, maxLevel = high}
        end
        sources[#sources + 1] = {target = {scope = "disenchant", deGroup = key, query = "",
            classIndex = group.classIndex, deClasses = group.targetID and {2, 1} or nil,
            deRanges = ranges,
            minLevel = group.minLevel, maxLevel = group.maxLevel,
            minQuality = group.quality, deOptions = options}, covered = {}}
    end
    return sources
end
function D.Scan(key, mode, options, part)
    local group = D.Group(key)
    if not group or not GetAuctionItemClasses or (not group.targetID and not ({GetAuctionItemClasses()})[group.classIndex]) then
        ns.say(ns.T("deNoClasses")); return false
    end
    if group.targetID and #D.Materials(key) == 0 then ns.say(ns.T("deTargetNoBands")); return false end
    if D.blocked and D.blocked.key == key then D.blocked = nil end
    local started = ns.Batch.Complete(D.ScanSources(key, options, part), mode, true)
    if started and ns.Batch.job then ns.Batch.job.deGroup = key end
    return started
end
