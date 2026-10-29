local _, ns = ...
local K = {}
ns.TradeKit = K
K.theme = {
    white = "Interface\\Buttons\\WHITE8X8",
    dot = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
    pin = {edge = {0.04, 0.03, 0.02, 0.95}, fill = {0.40, 0.93, 1, 1}, core = {1, 1, 1, 1}, label = {1, 1, 1},
        shadow = {0, 0, 0, 1}},
    grip = {art = "Interface\\AddOns\\ManaCode_AuctionScan\\art\\grip",
        cursor = "Interface\\AddOns\\ManaCode_AuctionScan\\art\\grip_cursor",
        blank = "Interface\\AddOns\\ManaCode_AuctionScan\\art\\blank",
        color = {1, 0.80, 0.30}, lit = {1, 0.93, 0.62}, press = {0.78, 0.58, 0.18}},
    minimap = {icon = {"Interface\\Icons\\INV_Misc_Coin_01", 0.08, 0.92, 0.08, 0.92},
        ring = "Interface\\Minimap\\MiniMap-TrackingBorder", lit = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"},
    marble = "Interface\\PaperDollInfoFrame\\UI-Character-CharacterTab-L1",
    highlight = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
    actionIcons = {refresh = {"Interface\\PaperDollInfoFrame\\UI-GearManager-Undo"},
        buy = {"Interface\\Icons\\INV_Misc_Coin_01", 0.08, 0.92, 0.08, 0.92},
        hide = {"Interface\\Buttons\\UI-GroupLoot-Pass-Up"},
        go = {"Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", 0.2, 0.8, 0.2, 0.8},
        make = {"Interface\\Icons\\Trade_BlackSmithing", 0.08, 0.92, 0.08, 0.92},
        paths = {"Interface\\Icons\\INV_Misc_Spyglass_02", 0.08, 0.92, 0.08, 0.92},
        lists = {"Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"},
        expand = {"Interface\\Buttons\\UI-PlusButton-Up"}, collapse = {"Interface\\Buttons\\UI-MinusButton-Up"},
        back = {"Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", 0.2, 0.8, 0.2, 0.8},
        settings = {"Interface\\Icons\\INV_Misc_Gear_01", 0.08, 0.92, 0.08, 0.92}},
    text = {0.96, 0.93, 0.87}, secondary = {0.74, 0.68, 0.58}, off = {0.52, 0.47, 0.40},
    gold = {1, 0.82, 0}, accent = {0.95, 0.78, 0.28},
    plain = {1, 1, 1, 1}, shade = {0, 0, 0, 0.62},
    chance = {high = {0.38, 0.80, 0.48}, mid = {0.38, 0.60, 0.88}, low = {0.60, 0.60, 0.64}},
    valueStep = 13, inset = 12, fitPad = 18, infoSize = 22, scrollBar = 26,
    positive = {0.40, 0.82, 0.48}, negative = {0.94, 0.42, 0.34},
    background = {0.135, 0.115, 0.09, 1}, panel = {0.185, 0.16, 0.125, 1}, card = {0.235, 0.205, 0.165, 1},
    field = {0.075, 0.065, 0.05, 1},
    edge = {0.46, 0.40, 0.30, 1}, line = {1, 0.90, 0.70, 0.12},
    row = {1, 0.90, 0.70, 0.05}, selected = {1, 1, 1, 0.08}, match = {0.40, 0.82, 0.48, 0.20},
    quality = {[0] = {0.62, 0.62, 0.62}, {1, 1, 1}, {0.12, 1, 0}, {0.25, 0.60, 1.0}, {0.78, 0.52, 1.0},
        {1, 0.5, 0}, {0.9, 0.8, 0.5}, {0.9, 0.8, 0.5}},
    hover = {1, 0.90, 0.70, 0.10}, head = {0.26, 0.225, 0.18, 1}, group = {0.165, 0.14, 0.11, 1}, subgroup = {0.125, 0.105, 0.085, 1},
    buttonSkin = {bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16,
        edgeSize = 10, insets = {left = 2, right = 2, top = 2, bottom = 2}},
    keycap = {bg = {0.06, 0.05, 0.04, 1}, edge = {0.70, 0.61, 0.47, 1}, text = {1, 0.82, 0}},
    tip = {0.085, 0.07, 0.055, 0.97},
    control = {bg = {0.32, 0.275, 0.215, 1}, hover = {0.40, 0.345, 0.27, 1},
        down = {0.24, 0.205, 0.16, 1}, edge = {0.60, 0.52, 0.40, 1}, text = {0.96, 0.93, 0.87}},
    main = {bg = {0.40, 0.30, 0.08, 1}, hover = {0.50, 0.38, 0.11, 1},
        down = {0.30, 0.22, 0.05, 1}, edge = {0.88, 0.72, 0.24, 1}, text = {1, 0.82, 0}},
    quiet = {bg = {1, 0.90, 0.70, 0.05}, hover = {1, 0.90, 0.70, 0.11},
        down = {0, 0, 0, 0.25}, edge = {0.46, 0.40, 0.30, 1}, text = {0.88, 0.84, 0.76}},
    nav = {bg = {0, 0, 0, 0}, hover = {1, 0.90, 0.70, 0.06},
        down = {0, 0, 0, 0.2}, edge = {0, 0, 0, 0}, text = {0.78, 0.72, 0.62}},
    segment = {bg = {0, 0, 0, 0}, hover = {1, 0.90, 0.70, 0.07},
        down = {0, 0, 0, 0.2}, edge = {0, 0, 0, 0}, text = {0.78, 0.72, 0.62}},
    chosen = {bg = {0.46, 0.40, 0.31, 1}, edge = {0.70, 0.61, 0.47, 1}, text = {1, 1, 1}},
    chart = {grid = {1, 1, 1, 0.07}, axis = {1, 1, 1, 0.20}, cursor = {1, 0.95, 0.75, 0.6},
        shade = {0, 0, 0, 0.8}, median = {0.72, 0.80, 0.92, 0.55}, minimum = {1, 0.82, 0},
        quartile = {0.38, 0.80, 0.48}, supply = {0.38, 0.60, 0.88}, added = {0.38, 0.80, 0.48},
        early = {0.86, 0.62, 0.30}, late = {0.60, 0.60, 0.64}, tile = {0.165, 0.145, 0.115, 1}},
    grain = {key = "stone", path = "Interface\\AchievementFrame\\UI-Achievement-AchievementBackground", alpha = 0.20},
    grains = {
        {key = "stone", path = "Interface\\AchievementFrame\\UI-Achievement-AchievementBackground", alpha = 0.20},
        {key = "grain", path = "Interface\\AddOns\\ManaCode_AuctionScan\\art\\grain", alpha = 0.14, tile = 128},
        {key = "dark", path = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", alpha = 0.30, tile = 128},
        {key = "none", alpha = 0},
    },
}
K.TOKENS = {"background", "panel", "card", "head", "group", "subgroup", "field", "tip", "row", "hover", "selected",
    "match", "edge", "line", "shade", "text", "secondary", "off", "gold", "accent", "positive", "negative",
    "control.bg", "control.hover", "control.down", "control.edge", "control.text",
    "main.bg", "main.hover", "main.down", "main.edge", "main.text",
    "quiet.bg", "quiet.hover", "quiet.down", "quiet.edge", "quiet.text",
    "nav.hover", "nav.text", "segment.hover", "segment.text", "chosen.bg", "chosen.edge", "chosen.text",
    "keycap.bg", "keycap.edge", "keycap.text", "chart.tile", "chart.grid"}
function K.Token(path)
    local node = K.theme
    for part in path:gmatch("[^%.]+") do
        if type(node) ~= "table" then return nil end
        node = node[part]
    end
    if type(node) == "table" and type(node[1]) == "number" then return node end
    return nil
end
local painted = setmetatable({}, {__mode = "k"})
local labels = setmetatable({}, {__mode = "k"})
local grained = setmetatable({}, {__mode = "k"})
local byValue
local changed = {}
function K.Milli(x)
    return math.floor(x * 1000 + 0.5)
end
local function valueKey(r, g, b, a)
    local milli = K.Milli
    return string.format("%d %d %d %d", milli(r or 0), milli(g or 0), milli(b or 0), milli(a or 1))
end
local function index()
    byValue = {}
    for _, path in ipairs(K.TOKENS) do
        local c = K.Token(path)
        if c then
            local key = valueKey(c[1], c[2], c[3], c[4])
            if not byValue[key] then byValue[key] = path end
        end
    end
    return byValue
end
local function track(object, method)
    local marks = painted[object]
    if not marks then marks = {}; painted[object] = marks end
    if marks[method] then return end
    local mark = {native = object[method]}
    marks[method] = mark
    object[method] = function(self, r, g, b, a)
        mark.token = (byValue or index())[valueKey(r, g, b, a)]
        return mark.native(self, r, g, b, a)
    end
end
function K.SetToken(path, r, g, b, a)
    local color = K.Token(path)
    if not color then return false end
    if not changed[path] then changed[path] = {color[1], color[2], color[3], color[4]} end
    color[1], color[2], color[3] = r, g, b
    if color[4] ~= nil and a ~= nil then color[4] = a end
    byValue = nil
    return true
end
local function fitGrain(frame)
    local texture, tile = rawget(frame, "tradeGrain"), K.theme.grain.tile
    if not texture then return end
    if not tile then texture:SetTexCoord(0, 1, 0, 1); return end
    local width, height = math.max(1, (frame:GetWidth() or 0) - 6), math.max(1, (frame:GetHeight() or 0) - 6)
    texture:SetTexCoord(0, width / tile, 0, height / tile)
end
function K.Grain(frame)
    grained[frame] = true
    local spec, texture = K.theme.grain, rawget(frame, "tradeGrain")
    if not spec.path then
        if texture then texture:Hide() end
        return
    end
    if not texture then
        texture = frame:CreateTexture(nil, "BORDER")
        texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
        texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
        frame.tradeGrain = texture
        frame:HookScript("OnSizeChanged", fitGrain)
    end
    texture:SetTexture(spec.path)
    local tint = K.theme.plain
    texture:SetVertexColor(tint[1], tint[2], tint[3], spec.alpha)
    fitGrain(frame)
    texture:Show()
end
function K.SetGrain(key, alpha)
    for _, option in ipairs(K.theme.grains) do
        if option.key == key then
            local spec = K.theme.grain
            spec.key, spec.path, spec.tile = option.key, option.path, option.tile
            spec.alpha = math.max(0, math.min(1, alpha or option.alpha))
            return true
        end
    end
    return false
end
local function near(fs, old)
    local r, g, b = fs:GetTextColor()
    if type(r) ~= "number" then return false end
    return math.abs(r - old[1]) < 0.01 and math.abs(g - old[2]) < 0.01 and math.abs(b - old[3]) < 0.01
end
function K.ApplyTheme(quick)
    index()
    for object, marks in pairs(painted) do
        for _, mark in pairs(marks) do
            local color = mark.token and K.Token(mark.token)
            if color then mark.native(object, unpack(color)) end
        end
    end
    for fs, path in pairs(labels) do
        local old, color = changed[path], K.Token(path)
        if old and color and near(fs, old) then fs:SetTextColor(unpack(color)) end
    end
    for path in pairs(changed) do changed[path] = nil end
    for frame in pairs(grained) do K.Grain(frame) end
    if quick then return end
    if EnumerateFrames and K.StyleButton then
        local frame = EnumerateFrames()
        while frame do
            if rawget(frame, "btnDisabled") ~= nil and rawget(frame, "text") then K.StyleButton(frame) end
            frame = EnumerateFrames(frame)
        end
    end
    if ns.Trader and ns.Trader.frame and ns.Trader.Refresh then ns.Trader.Refresh() end
end
function K.QualityColor(quality)
    local color = quality and K.theme.quality[quality] or K.theme.text
    return color[1], color[2], color[3]
end
function K.SetSelected(b, active)
    if active then b.selected:Show(); b.mark:Show() else b.selected:Hide(); b.mark:Hide() end
end
function K.Label(parent, text, x, y, width, kind)
    local font = (kind == "heading" or kind == "title") and "GameFontNormal" or "GameFontHighlightSmall"
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    local color = kind == "title" and K.theme.gold or (kind == "secondary" and K.theme.secondary or K.theme.text)
    fs:SetTextColor(unpack(color))
    fs:SetText(text)
    labels[fs] = kind == "title" and "gold" or (kind == "secondary" and "secondary" or "text")
    return fs
end
function K.Background(parent)
    local base = parent:CreateTexture(nil, "BACKGROUND")
    base:SetAllPoints(parent)
    base:SetTexture(K.theme.white)
    track(base, "SetVertexColor")
    base:SetVertexColor(unpack(K.theme.background))
    return base
end
function K.Panel(parent)
    if not rawget(parent, "tradeBase") then parent.tradeBase = K.Background(parent) end
    parent.tradeBase:SetVertexColor(unpack(K.theme.panel))
    parent:SetBackdrop({edgeFile = K.theme.buttonSkin.edgeFile, edgeSize = 12,
        insets = K.theme.buttonSkin.insets})
    parent:SetAlpha(1)
    parent:SetBackdropColor(unpack(K.theme.panel))
    track(parent, "SetBackdropBorderColor")
    parent:SetBackdropBorderColor(unpack(K.theme.edge))
    K.Grain(parent)
end
function K.Font(name, base, size, flags)
    if not _G[name] then
        local font = CreateFont(name)
        local source = _G[base]
        font:SetFontObject(source)
        ns.SetFont(font, source:GetFont(), size, flags or select(3, source:GetFont()))
    end
    return name
end
function K.Card(parent)
    local card = ns.NewFrame("Frame", nil, parent)
    card:SetBackdrop(K.theme.buttonSkin)
    track(card, "SetBackdropColor"); track(card, "SetBackdropBorderColor")
    card:SetBackdropColor(unpack(K.theme.card))
    card:SetBackdropBorderColor(unpack(K.theme.edge))
    K.Grain(card)
    return card
end
function K.Colored(text, tone)
    local color = K.theme[tone]
    return string.format("|cff%02x%02x%02x", math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5),
        math.floor(color[3] * 255 + 0.5)) .. text .. "|r"
end
function K.Picture(parent, texture, layer)
    local picture = parent:CreateTexture(nil, layer or "ARTWORK")
    picture:SetAllPoints(parent)
    if texture then picture:SetTexture(texture) end
    return picture
end
function K.Rule(parent, y)
    local line = parent:CreateTexture(nil, "BORDER")
    line:SetTexture(K.theme.white); track(line, "SetVertexColor"); line:SetVertexColor(unpack(K.theme.line))
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", K.theme.inset, y)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -K.theme.inset, y); line:SetHeight(1)
    return line
end
