local ADDON, ns = ...
ns.locales = ns.locales or {}
local DEFAULT = "ruRU"
local FOREIGN = "enUS"
function ns.Plural(n, forms)
    local list = {}
    for word in (forms .. "|"):gmatch("([^|]*)|") do list[#list + 1] = word end
    if #list < 3 then return (n == 1 or not list[2]) and list[1] or list[2] end
    local tail = math.abs(math.floor(n)) % 100
    if tail >= 11 and tail <= 14 then return list[3] end
    tail = tail % 10
    if tail == 1 then return list[1] end
    if tail >= 2 and tail <= 4 then return list[2] end
    return list[3]
end
local function plurals(s)
    if not s:find("{", 1, true) then return s end
    return (s:gsub("(%d+)(%s+){([^}]*)}", function(num, gap, forms)
        return num .. gap .. ns.Plural(tonumber(num), forms)
    end))
end
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
    if select("#", ...) > 0 then return plurals(s:format(...)) end
    return s
end
function ns.Decimal(value, digits, signed, trim)
    local text = string.format((signed and "%+." or "%.") .. digits .. "f", value)
    if trim and digits > 0 then text = text:gsub("0+$", ""):gsub("%.$", "") end
    return (text:gsub("%.", ns.T("decimalMark")))
end
