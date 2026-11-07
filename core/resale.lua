local _, ns = ...
local R = {byItem = {}}
ns.Resale = R
for profession, entries in pairs(ns.vendorRecipeCatalogs) do
    for _, entry in ipairs(entries) do
        entry.profession = profession
        R.byItem[entry.raw] = entry
    end
end
function R.Items(profession)
    return ns.vendorRecipeCatalogs[profession] or {}
end
function R.Vendor(entry)
    local faction = UnitFactionGroup("player")
    for _, vendor in ipairs(entry.vendors) do
        if vendor.faction == "Both" or vendor.faction == faction then return vendor end
    end
    return nil
end
function R.Targets(profession)
    local ids = {}
    if profession then
        for _, entry in ipairs(R.Items(profession)) do ids[#ids + 1] = entry.raw end
    else
        for id in pairs(R.byItem) do ids[#ids + 1] = id end
        table.sort(ids)
    end
    return ids
end
function R.Estimate(entry, fee)
    local result = {cost = entry.buy, breakEven = math.ceil(entry.buy / (1 - fee))}
    local quote = ns.Markets.Quote(entry.raw)
    if quote and quote.price and quote.miss == 0 then
        result.revenue = quote.price * (1 - fee)
        result.margin = result.revenue - result.cost
    end
    return result
end
function R.Complete(profession, mode)
    return ns.Batch.Complete(R.Targets(profession), mode, true)
end
