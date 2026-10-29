local ADDON, ns = ...
ns.locales = ns.locales or {}
local DEFAULT = "ruRU"
local FOREIGN = "enUS"
function ns.T(key, ...)
    local override = AuctionScanDB and AuctionScanDB.language
    local locale = (override == "enUS" or override == "ruRU") and override or GetLocale()
    local own = ns.locales[locale]
    if own == nil and locale ~= DEFAULT then own = ns.locales[FOREIGN] end
    local s = own and own[key]
    if s == nil then
        local base = ns.locales[DEFAULT]
        s = base and base[key]
    end
    if s == nil then return "[" .. tostring(key) .. "]" end
    if select("#", ...) > 0 then return s:format(...) end
    return s
end
function ns.Decimal(value, digits, signed, trim)
    local text = string.format((signed and "%+." or "%.") .. digits .. "f", value)
    if trim and digits > 0 then text = text:gsub("0+$", ""):gsub("%.$", "") end
    return (text:gsub("%.", ns.T("decimalMark")))
end
