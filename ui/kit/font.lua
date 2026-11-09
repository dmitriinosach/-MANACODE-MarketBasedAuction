local _, ns = ...
local K = ns.TradeKit
local roles = {
    small = {"GameFontHighlightSmall", 10},
    button = {"GameFontNormalSmall", 10},
    normal = {"GameFontHighlight", 12},
    heading = {"GameFontNormal", 12},
    nav = {"GameFontNormal", 11},
    rowTitle = {"GameFontNormal", 14},
    large = {"GameFontNormalLarge", 16},
    map = {"GameFontNormal", 12, "OUTLINE"},
}
local fonts, listeners = {}, {}
local bindings = setmetatable({}, {__mode = "k"})
local heights = setmetatable({}, {__mode = "k"})
local delta
local MIN, MAX = -2, 6
local function clamp(value)
    if type(value) ~= "number" or value ~= value then return 0 end
    return math.max(MIN, math.min(MAX, math.floor(value + 0.5)))
end
function K.FontDelta()
    if delta == nil then
        local db = AuctionScanDB
        if type(db) ~= "table" then return 0, MIN, MAX end
        local view = db.view
        delta = clamp(type(view) == "table" and view.fontDelta)
    end
    return delta, MIN, MAX
end
function K.ViewSettings()
    local db = ns.Store.DB()
    if type(db.view) ~= "table" then db.view = {} end
    return db.view
end
function K.FontHeight(base, lines)
    return base + math.max(0, (K.FontDelta())) * (lines or 1)
end
function K.FontRole(name)
    local entry = fonts[name]
    if entry then return entry.font end
    local role = roles[name]
    local source = _G[role[1]]
    local font = CreateFont("ManaCodeAuctionFont_" .. name)
    if font.CopyFontObject then font:CopyFontObject(source) end
    local path, _, flags = source:GetFont()
    path = path or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    entry = {font = font, path = path, size = role[2], flags = role[3] or flags, source = source}
    fonts[name] = entry
    ns.SetFont(font, path, entry.size + K.FontDelta(), entry.flags)
    return font
end
local function bind(region, font)
    local r, g, b, a = region:GetTextColor()
    local sr, sg, sb, sa = region:GetShadowColor()
    local h, v = region:GetJustifyH(), region:GetJustifyV()
    region:SetFontObject(font)
    if r then region:SetTextColor(r, g, b, a) end
    if sr then region:SetShadowColor(sr, sg, sb, sa) end
    if h then region:SetJustifyH(h) end
    if v then region:SetJustifyV(v) end
end
function K.BindFont(region, role)
    local font = K.FontRole(role)
    if bindings[region] ~= font then
        bindings[region] = font
        region:SetFontObject(font)
        if not region:GetFont() then region:SetFontObject(fonts[role].source) end
    end
    return region
end
function K.FontString(parent, role, layer)
    return K.BindFont(parent:CreateFontString(nil, layer or "OVERLAY"), role)
end
function K.SetFontHeight(region, height, lines)
    heights[region] = {height, lines}
    region:SetHeight(K.FontHeight(height, lines))
end
function K.OnFont(callback)
    listeners[#listeners + 1] = callback
end
function K.SetFontDelta(value)
    value = clamp(value)
    local previous = K.FontDelta()
    K.ViewSettings().fontDelta = value
    if value == previous then return end
    delta = value
    for _, entry in pairs(fonts) do
        ns.SetFont(entry.font, entry.path, entry.size + delta, entry.flags)
    end
    for region, font in pairs(bindings) do bind(region, font) end
    for region, height in pairs(heights) do region:SetHeight(K.FontHeight(unpack(height))) end
    for _, callback in ipairs(listeners) do callback() end
end
