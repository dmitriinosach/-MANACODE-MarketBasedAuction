local _, ns = ...
local K = ns.TradeKit
function K.Money(copper)
    if not copper then return ns.T("tradeNoPrice") end
    return (copper < 0 and "-" or "") .. GetCoinTextureString(math.floor(math.abs(copper) + 0.5))
end
function K.MoneyShort(copper, size)
    if not copper then return ns.T("tradeNoPrice") end
    local rounded = K.RoundSilver(copper)
    return (rounded < 0 and "-" or "") .. GetCoinTextureString(math.abs(rounded), size or 10)
end
function K.RoundSilver(copper)
    local rounded = math.floor(math.abs(copper) / 100 + 0.5) * 100
    return copper < 0 and -rounded or rounded
end
function K.About(copper)
    if not copper then return ns.T("tradeNoPrice") end
    return (copper < 0 and "-" or "") .. "~" .. K.Money(math.abs(copper))
end
function K.Chance(chance)
    local value = chance * 100
    return K.Decimal(value, value >= 10 and 0 or 1, false, true) .. "%"
end
function K.Ago(seconds)
    if seconds < 3600 then return ns.T("buyAgoMin", math.max(1, math.floor(seconds / 60))) end
    if seconds < 172800 then return ns.T("buyAgoHour", math.floor(seconds / 3600)) end
    return ns.T("buyAgoDay", math.floor(seconds / 86400))
end
function K.Tone(value)
    if not value or value == 0 then return "secondary" end
    return value > 0 and "positive" or "negative"
end
function K.Decimal(value, digits, signed, trim)
    return ns.Decimal(value, digits, signed, trim)
end
