local ADDON, ns = ...
local Lot = {}
ns.Lot = Lot
local LINK = "item:(%-?%d+):%-?%d+:%-?%d+:%-?%d+:%-?%d+:%-?%d+:(%-?%d+)"
function Lot.FromLink(link)
    if not link then return nil, 0 end
    local id, suffix = link:match(LINK)
    if not id then return nil, 0 end
    return tonumber(id), tonumber(suffix) or 0
end
local function clean(s)
    if not s then return "" end
    return (s:gsub("[:|%c]", ""))
end
function Lot.Key(item, suffix, count, buyout, owner)
    return table.concat({item, suffix, count, buyout, clean(owner)}, ":")
end
function Lot.Encode(l)
    return table.concat({
        l.item, l.suffix, l.count, l.minBid, l.buyout, l.bid, l.timeLeft, clean(l.owner),
    }, ":")
end
function Lot.Decode(s)
    local item, suffix, count, minBid, buyout, bid, timeLeft, owner =
        s:match("^(%-?%d+):(%-?%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(.*)$")
    if not item then return nil end
    return {
        item = tonumber(item), suffix = tonumber(suffix), count = tonumber(count),
        minBid = tonumber(minBid), buyout = tonumber(buyout), bid = tonumber(bid),
        timeLeft = tonumber(timeLeft), owner = owner,
    }
end
