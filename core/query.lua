local _, ns = ...
local Q = { gap = 0.3, lastAt = -100 }
ns.Query = Q
function Q.Cooling()
    return math.max(0, (ns.Store.DB().cooldownUntil or 0) - time())
end
function Q.Gap()
    local db = ns.Store.DB()
    return math.max(Q.gap, db.scanGap or Q.gap)
end
function Q.Ready(mass)
    local canQuery, canMass = CanSendAuctionQuery("list")
    return canQuery and (not mass or canMass) and Q.Cooling() == 0
        and GetTime() - Q.lastAt >= (mass and Q.gap or Q.Gap())
end
function Q.Cooldown(seconds)
    local db = ns.Store.DB()
    db.scanGap = math.min(Q.Gap() * 2, 8)
    db.cooldownUntil = math.max(db.cooldownUntil or 0, time() + seconds)
end
function Q.Name(name)
    if #name <= 63 then return name end
    local cut = 63
    while cut > 0 do
        local b = name:byte(cut + 1)
        if not b or b < 128 or b >= 192 then break end
        cut = cut - 1
    end
    return name:sub(1, cut)
end
function Q.Send(name, page, mass, filter)
    if not Q.Ready(mass) then return false end
    local gap = GetTime() - Q.lastAt
    Q.lastAt = GetTime()
    local class = filter and filter.classIndex
    local sub = filter and filter.subClassIndex
    local sort = filter and filter.sort
    if sort then
        SortAuctionClearSort("list")
        SortAuctionSetSort("list", sort[1], sort[2])
    end
    if (page or 0) == 0 or mass then
        ns.Store.Log("query page=" .. tostring(page or 0) .. " name=" .. Q.Name(name)
            .. " class=" .. tostring(class or 0) .. ":" .. tostring(sub or 0)
            .. " gap=" .. string.format("%.2f", gap) .. " all=" .. tostring(mass or false))
    end
    QueryAuctionItems(Q.Name(name), filter and filter.minLevel, filter and filter.maxLevel, nil,
        class, sub, page, nil, filter and filter.minQuality, mass or false)
    return true
end
hooksecurefunc("QueryAuctionItems", function() Q.lastAt = GetTime() end)
