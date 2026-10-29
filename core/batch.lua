local _, ns = ...
local B = {names = {}}
ns.Batch = B
function B.Mode(value)
    if value == true or value == "hard" then return "hard" end
    if value == "missing" then return "missing" end
    return "soft"
end
function B.Cancel()
    B.job = nil
    ns.Markets.Settle(true)
end
local function fresh(task)
    if #task.covered == 0 then return false end
    for _, id in ipairs(task.covered) do if not ns.Markets.Fresh(id, nil, task.auction) then return false end end
    return true
end
local function nextItem()
    local job = B.job
    while job and job.items[job.index] do
        local item = job.items[job.index]
        if job.mode ~= "hard" and fresh(item) then
            job.used = job.used + #item.covered
            job.index = job.index + 1
        else
            if not ns.Scan.Start("pages", item.target)
                or (item.target and not ns.Scan.Same(ns.Scan.state.scan, item.target)) then
                B.Cancel(); return false
            end
            job.scanID = ns.Scan.state.scan.id
            return true
        end
    end
    if job then B.last = job end
    B.Cancel()
    return true
end
local function plan(sources, mode, skipUnknown)
    mode = B.Mode(mode)
    local force, missing = mode == "hard", mode == "missing"
    local items, seen = {}, {}
    local job = {items = items, index = 1, mode = mode, force = force, used = 0, vendor = 0, unknown = 0, missing = 0, stale = 0}
    local failed
    local function have(id, auction)
        if force then return false end
        if missing then
            local q = ns.Markets.Quote(id, auction)
            return q ~= nil and q.price ~= nil
        end
        return ns.Markets.Fresh(id, nil, auction)
    end
    local function addItem(id, auction)
        if seen[id] then return end
        seen[id] = true
        if not auction and ns.vendorPrices and ns.vendorPrices[id] then job.vendor = job.vendor + 1; return end
        if have(id, auction) then job.used = job.used + 1; return end
        local name = ns.Compat.ItemInfo(id) or B.names[id]
        if not name then
            job.unknown = job.unknown + 1
            if not skipUnknown then failed = id end
            return
        end
        local quote = ns.Markets.Quote(id, auction)
        if quote and quote.price then job.stale = job.stale + 1 else job.missing = job.missing + 1 end
        items[#items + 1] = {target = {itemID = id, query = name}, covered = {id}, auction = auction}
    end
    for _, source in ipairs(sources) do
        local family = type(source) == "table" and ns.gemByRaw[source.family]
        if family then
            local stale = 0
            for _, id in ipairs(family.members) do if not seen[id] and not have(id) then stale = stale + 1 end end
            local name = ns.Compat.ItemInfo(family.raw)
            if stale >= 2 and name then
                local covered = {}
                for _, id in ipairs(family.members) do
                    if not seen[id] then covered[#covered + 1] = id; seen[id] = true end
                end
                if #covered > 0 then items[#items + 1] = {target = {family = family.raw, query = name}, covered = covered} end
            else
                for _, id in ipairs(family.members) do addItem(id) end
            end
        elseif type(source) == "table" and source.id then addItem(source.id, source.auction)
        elseif type(source) == "table" and source.target then
            items[#items + 1] = {target = source.target, covered = source.covered or {}}
        elseif type(source) == "number" then addItem(source) end
    end
    return job, failed
end
local function begin(sources, mode, skipUnknown)
    if not ns.Scan.Release() or ns.Buy.Active() then ns.say(ns.T("sayBusy")); return false end
    local job, failed = plan(sources, mode, skipUnknown)
    local items = job.items
    if failed then ns.say(ns.T("alchemyColdItem", ns.Markets.Name(failed))); return false end
    B.last = job
    ns.say(ns.T("cachePlan", #items, job.used, job.vendor, job.unknown))
    if #items == 0 then return true end
    B.job = job
    return nextItem()
end
function B.Preview(sources, skipUnknown)
    local job = plan(sources, "soft", skipUnknown)
    return {soft = #job.items, hard = #plan(sources, "hard", skipUnknown).items,
        missing = #plan(sources, "missing", skipUnknown).items, noPrice = job.missing, stale = job.stale,
        fresh = job.used, vendor = job.vendor, unknown = job.unknown}
end
function B.PreviewText(sources, skipUnknown)
    local p = B.Preview(sources, skipUnknown)
    return ns.T("batchPreview", p.soft, p.noPrice, p.stale, p.fresh, p.vendor, p.unknown)
        .. "\n" .. ns.T("batchPreviewModes", p.hard, p.missing)
end
function B.Age(sources, skipUnknown)
    local result, seen, now = {never = 0, count = 0}, {}, time()
    local function add(id, auction)
        if seen[id] then return end
        seen[id] = true
        if not auction and ns.vendorPrices and ns.vendorPrices[id] then return end
        local q = ns.Markets.Quote(id, auction)
        local at = q and (q.at or q.since)
        if not at and skipUnknown and not (ns.Compat.ItemInfo(id) or B.names[id]) then return end
        result.count = result.count + 1
        if not at then result.never = result.never + 1; return end
        local age = math.max(0, now - at)
        if not result.oldest or age > result.oldest then result.oldest = age end
    end
    for _, source in ipairs(sources or {}) do
        local family = type(source) == "table" and source.family and ns.gemByRaw[source.family]
        if family then for _, id in ipairs(family.members) do add(id) end
        elseif type(source) == "table" and source.id then add(source.id, source.auction)
        elseif type(source) == "table" and source.covered then for _, id in ipairs(source.covered) do add(id) end
        elseif type(source) == "number" then add(source) end
    end
    return result
end
function B.Start(ids)
    return begin(ids, "hard")
end
function B.Complete(sources, mode, skipUnknown)
    return begin(sources, mode, skipUnknown)
end
function B.AllSources()
    local sources = {}
    local shown = ns.FamilyUI and ns.FamilyUI.expansions or {wrath = true}
    for _, family in ipairs(ns.gemFamilies) do
        local expansion = family.expansion or "wrath"
        if shown[expansion] and not ns.Hidden.Is(family.raw) and not ns.Hidden.IsGroup(expansion .. family.quality) then
            sources[#sources + 1] = {family = family.raw}
        end
    end
    if not ns.Hidden.IsGroup("cooldowns") then
        for _, recipe in ipairs(ns.Family.Cooldowns(shown)) do
            for _, id in ipairs(ns.Crafting.Targets(recipe)) do sources[#sources + 1] = id end
        end
    end
    for _, key in ipairs(ns.Crafting.order) do
        if ns.craftCatalogs[key] then
            for _, id in ipairs(ns.Crafting.ProfessionSources(key)) do sources[#sources + 1] = id end
        end
    end
    if ns.Resale then
        for _, id in ipairs(ns.Resale.Targets()) do sources[#sources + 1] = id end
    end
    if ns.Leveling then
        for _, id in ipairs(ns.Leveling.Targets(nil, true)) do sources[#sources + 1] = id end
    end
    return sources
end
function B.All(mode)
    return begin(B.AllSources(), mode, true)
end
function B.Accept(scan)
    local job = B.job
    if not job or job.scanID ~= scan.id then return end
    if (scan.miss or 0) > 0 then job.failed = (job.failed or 0) + 1 end
    job.index = job.index + 1
    nextItem()
end
function B.Stop()
    if not B.job then return end
    B.Cancel()
    ns.Scan.Stop()
end
ns.Scan.onAbort = B.Cancel
