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
    iconLit = "Interface\\Buttons\\ButtonHilight-Square", iconChecked = "Interface\\Buttons\\CheckButtonHilight",
    actionIcons = {refresh = {"Interface\\PaperDollInfoFrame\\UI-GearManager-Undo", bare = true},
        buy = {"Interface\\Icons\\INV_Misc_Coin_01", bare = true},
        hide = {"Interface\\Buttons\\UI-GroupLoot-Pass-Up", bare = true,
            lit = "Interface\\Buttons\\UI-GroupLoot-Pass-Highlight"},
        go = {"Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", 0.2, 0.8, 0.2, 0.8},
        make = {"Interface\\Icons\\Trade_BlackSmithing", bare = true},
        paths = {"Interface\\Icons\\INV_Misc_Spyglass_02", bare = true},
        lists = {"Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"},
        expand = {"Interface\\Buttons\\UI-PlusButton-Up"}, collapse = {"Interface\\Buttons\\UI-MinusButton-Up"},
        back = {"Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", 0.2, 0.8, 0.2, 0.8},
        settings = {"Interface\\Icons\\INV_Misc_Gear_01", bare = true},
        pin = {"Interface\\AddOns\\ManaCode_AuctionScan\\art\\pin"},
        unlearned = {"Interface\\RaidFrame\\ReadyCheck-NotReady"}},
    text = {0.96, 0.93, 0.87}, heading = {0.96, 0.93, 0.87}, secondary = {0.74, 0.68, 0.58}, off = {0.52, 0.47, 0.40},
    gold = {1, 0.82, 0}, accent = {0.95, 0.78, 0.28},
    plain = {1, 1, 1, 1}, shade = {0, 0, 0, 0.62},
    chance = {high = {0.38, 0.80, 0.48}, mid = {0.38, 0.60, 0.88}, low = {0.60, 0.60, 0.64}},
    skill = {orange = {1, 0.50, 0.25, 0.9}, yellow = {1, 1, 0, 0.8}, green = {0.25, 0.75, 0.25, 0.85}},
    valueStep = 13, inset = 12, fitPad = 18, infoSize = 22, scrollBar = 26,
    positive = {0.40, 0.82, 0.48}, negative = {1, 0.52, 0.44},
    background = {0.135, 0.115, 0.09, 1}, panel = {0.185, 0.16, 0.125, 1}, card = {0.235, 0.205, 0.165, 1},
    field = {0.075, 0.065, 0.05, 1},
    edge = {0.46, 0.40, 0.30, 1}, line = {1, 0.90, 0.70, 0.12},
    row = {1, 0.90, 0.70, 0.05}, selected = {1, 0.82, 0.30, 0.10}, match = {0.40, 0.82, 0.48, 0.20},
    quality = {[0] = {0.62, 0.62, 0.62}, {1, 1, 1}, {0.12, 1, 0}, {0.32, 0.64, 1.0}, {0.78, 0.52, 1.0},
        {1, 0.5, 0}, {0.9, 0.8, 0.5}, {0.9, 0.8, 0.5}},
    hover = {1, 0.90, 0.70, 0.10}, head = {0.26, 0.225, 0.18, 1}, group = {0.165, 0.14, 0.11, 1}, subgroup = {0.125, 0.105, 0.085, 1},
    buttonSkin = {bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16,
        edgeSize = 10, insets = {left = 2, right = 2, top = 2, bottom = 2}},
    keycap = {bg = {0.80, 0.79, 0.76, 1}, edge = {0.36, 0.35, 0.33, 1}, text = {0.10, 0.09, 0.08}},
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
    panelSkin = {edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = {left = 2, right = 2, top = 2, bottom = 2}},
    key = "clean", grain = {alpha = 0},
}
K.LOOKS = {
    flat = {panel = {edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = {left = 2, right = 2, top = 2, bottom = 2}}, fill = 0, grainInset = 3},
    blizzard = {panel = {edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}}, fill = 4, grainInset = 4,
        button = {up = "Interface\\Buttons\\UI-Panel-Button-Up", down = "Interface\\Buttons\\UI-Panel-Button-Down",
            disabled = "Interface\\Buttons\\UI-Panel-Button-Disabled",
            highlight = "Interface\\Buttons\\UI-Panel-Button-Highlight", kinds = {control = true, main = true}},
        highlight = {path = "Interface\\QuestFrame\\UI-QuestTitleHighlight", blend = "ADD"}},
}
K.THEMES = {
    {key = "clean", look = "flat"},
    {key = "dark", look = "flat",
        grain = {path = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", alpha = 0.30, tile = 128}},
    {key = "slate", look = "flat",
        grain = {path = "Interface\\AchievementFrame\\UI-Achievement-AchievementBackground", alpha = 0.15},
        colors = {
            background = {0.105, 0.125, 0.155, 1}, panel = {0.145, 0.17, 0.205, 1}, card = {0.19, 0.215, 0.25, 1},
            head = {0.215, 0.24, 0.275, 1}, group = {0.13, 0.15, 0.18, 1}, subgroup = {0.1, 0.115, 0.14, 1},
            field = {0.07, 0.08, 0.1, 1}, tip = {0.07, 0.085, 0.105, 0.97},
            row = {0.8, 0.88, 1, 0.05}, hover = {0.8, 0.88, 1, 0.09}, selected = {1, 0.82, 0.30, 0.10},
            match = {0.42, 0.84, 0.52, 0.2}, edge = {0.4, 0.46, 0.54, 1}, line = {0.8, 0.88, 1, 0.12},
            shade = {0, 0, 0, 0.62}, text = {0.93, 0.95, 0.98}, heading = {0.93, 0.95, 0.98},
            secondary = {0.7, 0.75, 0.82}, off = {0.48, 0.52, 0.58}, gold = {1, 0.82, 0}, accent = {0.96, 0.78, 0.3},
            positive = {0.45, 0.85, 0.52}, negative = {1, 0.54, 0.46},
            control = {bg = {0.25, 0.29, 0.35, 1}, hover = {0.31, 0.36, 0.43, 1}, down = {0.18, 0.21, 0.26, 1},
                edge = {0.52, 0.58, 0.67, 1}, text = {0.93, 0.95, 0.98}},
            main = {bg = {0.36, 0.29, 0.1, 1}, hover = {0.46, 0.37, 0.13, 1}, down = {0.27, 0.21, 0.06, 1},
                edge = {0.9, 0.74, 0.26, 1}, text = {1, 0.84, 0.1}},
            quiet = {bg = {0.8, 0.88, 1, 0.05}, hover = {0.8, 0.88, 1, 0.11}, down = {0, 0, 0, 0.25},
                edge = {0.4, 0.46, 0.54, 1}, text = {0.84, 0.88, 0.93}},
            nav = {hover = {0.8, 0.88, 1, 0.06}, text = {0.74, 0.79, 0.86}},
            segment = {hover = {0.8, 0.88, 1, 0.07}, text = {0.74, 0.79, 0.86}},
            chosen = {bg = {0.4, 0.46, 0.54, 1}, edge = {0.64, 0.7, 0.78, 1}, text = {1, 1, 1}},
            keycap = {bg = {0.80, 0.79, 0.76, 1}, edge = {0.36, 0.35, 0.33, 1}, text = {0.10, 0.09, 0.08}},
            chart = {tile = {0.13, 0.15, 0.18, 1}, grid = {1, 1, 1, 0.07}},
        },
        quality = {[0] = {0.66, 0.68, 0.7}, {1, 1, 1}, {0.3, 1, 0.2}, {0.42, 0.7, 1}, {0.82, 0.6, 1}, {1, 0.58, 0.12},
            {0.92, 0.82, 0.52}, {0.92, 0.82, 0.52}}},
    {key = "blizzard", look = "blizzard",
        grain = {path = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", alpha = 0.30, tile = 128},
        colors = {
            background = {0.06, 0.06, 0.09, 1}, panel = {0.09, 0.09, 0.16, 1}, card = {0.13, 0.13, 0.21, 1},
            head = {0.17, 0.16, 0.25, 1}, group = {0.11, 0.11, 0.18, 1}, subgroup = {0.08, 0.08, 0.13, 1},
            field = {0.04, 0.04, 0.07, 1}, tip = {0.09, 0.09, 0.19, 0.97},
            row = {1, 1, 1, 0.04}, hover = {1, 1, 1, 0.5}, selected = {1, 1, 1, 0.7},
            match = {0.12, 1, 0, 0.16}, edge = {0.8, 0.66, 0.36, 1}, line = {1, 0.82, 0, 0.14},
            shade = {0, 0, 0, 0.62}, text = {1, 1, 1}, heading = {1, 0.82, 0},
            secondary = {0.8, 0.72, 0.52}, off = {0.52, 0.52, 0.52}, gold = {1, 0.82, 0}, accent = {1, 0.82, 0},
            positive = {0.3, 0.9, 0.3}, negative = {1, 0.4, 0.36},
            control = {bg = {0.34, 0.1, 0.07, 1}, hover = {0.45, 0.15, 0.1, 1}, down = {0.24, 0.07, 0.05, 1},
                edge = {0.76, 0.6, 0.28, 1}, text = {1, 0.82, 0}},
            main = {bg = {0.48, 0.14, 0.09, 1}, hover = {0.58, 0.2, 0.12, 1}, down = {0.34, 0.1, 0.07, 1},
                edge = {1, 0.82, 0, 1}, text = {1, 1, 1}},
            quiet = {bg = {1, 1, 1, 0.04}, hover = {1, 0.82, 0, 0.1}, down = {0, 0, 0, 0.25},
                edge = {0.5, 0.42, 0.26, 1}, text = {0.9, 0.86, 0.74}},
            nav = {hover = {1, 0.82, 0, 0.08}, text = {0.82, 0.76, 0.58}},
            segment = {hover = {1, 0.82, 0, 0.08}, text = {0.82, 0.76, 0.58}},
            chosen = {bg = {0.36, 0.3, 0.14, 1}, edge = {1, 0.82, 0, 1}, text = {1, 1, 1}},
            keycap = {bg = {0.80, 0.79, 0.76, 1}, edge = {0.36, 0.35, 0.33, 1}, text = {0.10, 0.09, 0.08}},
            chart = {tile = {0.11, 0.11, 0.18, 1}, grid = {1, 1, 1, 0.07}},
        },
        quality = {[0] = {0.62, 0.62, 0.62}, {1, 1, 1}, {0.12, 1, 0}, {0.3, 0.62, 1}, {0.78, 0.52, 1}, {1, 0.5, 0},
            {0.9, 0.8, 0.5}, {0.9, 0.8, 0.5}}},
    {key = "night", look = "flat",
        colors = {
            background = {0.035, 0.035, 0.04, 1}, panel = {0.065, 0.065, 0.075, 1}, card = {0.105, 0.105, 0.12, 1},
            head = {0.14, 0.14, 0.16, 1}, group = {0.085, 0.085, 0.095, 1}, subgroup = {0.055, 0.055, 0.065, 1},
            field = {0.02, 0.02, 0.025, 1}, tip = {0.03, 0.03, 0.035, 0.98},
            row = {1, 1, 1, 0.05}, hover = {1, 1, 1, 0.1}, selected = {1, 0.82, 0.30, 0.13},
            match = {0.45, 0.9, 0.55, 0.2}, edge = {0.44, 0.44, 0.48, 1}, line = {1, 1, 1, 0.14},
            shade = {0, 0, 0, 0.7}, text = {0.98, 0.98, 0.98}, heading = {0.98, 0.98, 0.98},
            secondary = {0.76, 0.76, 0.78}, off = {0.55, 0.55, 0.57}, gold = {1, 0.85, 0.1}, accent = {1, 0.72, 0.3},
            positive = {0.45, 0.9, 0.55}, negative = {1, 0.52, 0.46},
            control = {bg = {0.2, 0.2, 0.23, 1}, hover = {0.27, 0.27, 0.31, 1}, down = {0.14, 0.14, 0.16, 1},
                edge = {0.64, 0.64, 0.68, 1}, text = {0.98, 0.98, 0.98}},
            main = {bg = {0.38, 0.3, 0.06, 1}, hover = {0.5, 0.4, 0.09, 1}, down = {0.27, 0.21, 0.04, 1},
                edge = {1, 0.85, 0.1, 1}, text = {1, 0.88, 0.2}},
            quiet = {bg = {1, 1, 1, 0.05}, hover = {1, 1, 1, 0.11}, down = {0, 0, 0, 0.3},
                edge = {0.44, 0.44, 0.48, 1}, text = {0.88, 0.88, 0.9}},
            nav = {hover = {1, 1, 1, 0.06}, text = {0.8, 0.8, 0.82}},
            segment = {hover = {1, 1, 1, 0.07}, text = {0.8, 0.8, 0.82}},
            chosen = {bg = {0.42, 0.42, 0.46, 1}, edge = {0.72, 0.72, 0.76, 1}, text = {1, 1, 1}},
            keycap = {bg = {0.80, 0.79, 0.76, 1}, edge = {0.36, 0.35, 0.33, 1}, text = {0.10, 0.09, 0.08}},
            chart = {tile = {0.085, 0.085, 0.095, 1}, grid = {1, 1, 1, 0.08}},
        },
        quality = {[0] = {0.68, 0.68, 0.68}, {1, 1, 1}, {0.3, 1, 0.2}, {0.4, 0.68, 1}, {0.82, 0.58, 1}, {1, 0.56, 0.1},
            {0.95, 0.85, 0.55}, {0.95, 0.85, 0.55}}},
}
K.THEME = K.THEMES[1].key
K.theme.look = K.LOOKS[K.THEMES[1].look]
K.TOKENS = {"background", "panel", "card", "head", "group", "subgroup", "field", "tip", "row", "hover", "selected",
    "match", "edge", "line", "shade", "text", "heading", "secondary", "off", "gold", "accent", "positive", "negative",
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
        mark.args = {r, g, b, a}
        return mark.native(self, r, g, b, a)
    end
end
local baseColors = {}
for _, path in ipairs(K.TOKENS) do
    local c = K.Token(path)
    baseColors[path] = {c[1], c[2], c[3], c[4]}
end
local baseQuality = {}
for i = 0, 7 do
    local c = K.theme.quality[i]
    baseQuality[i] = {c[1], c[2], c[3]}
end
local panels = setmetatable({}, {__mode = "k"})
local lit = setmetatable({}, {__mode = "k"})
local lookStamp = 1
local shownStamp = 1
function K.Theme(key)
    for _, preset in ipairs(K.THEMES) do
        if preset.key == key then return preset end
    end
    return nil
end
function K.LookStamp()
    return lookStamp
end
function K.ThemeColor(key, path)
    local preset, node = K.Theme(key), nil
    node = preset and preset.colors
    for part in path:gmatch("[^%.]+") do
        if type(node) ~= "table" then node = nil; break end
        node = node[part]
    end
    if type(node) == "table" and type(node[1]) == "number" then
        local fallback = baseColors[path]
        return {node[1], node[2], node[3], fallback[4] ~= nil and (node[4] or fallback[4]) or nil}
    end
    return baseColors[path]
end
function K.SetTheme(key)
    local preset = K.Theme(key)
    if not preset then return false end
    for _, path in ipairs(K.TOKENS) do
        local c = K.ThemeColor(key, path)
        K.SetToken(path, c[1], c[2], c[3], c[4])
    end
    local quality = preset.quality or {}
    for i = 0, 7 do
        local c, color = quality[i] or baseQuality[i], K.theme.quality[i]
        color[1], color[2], color[3] = c[1], c[2], c[3]
    end
    local look, spec, grain = K.LOOKS[preset.look], K.theme.grain, preset.grain or {}
    spec.path, spec.tile, spec.alpha = grain.path, grain.tile, grain.alpha or 0
    if K.theme.look ~= look then
        K.theme.look = look
        local skin = K.theme.panelSkin
        for field in pairs(skin) do skin[field] = nil end
        for field, value in pairs(look.panel) do skin[field] = value end
        lookStamp = lookStamp + 1
    end
    K.theme.key = key
    return true
end
function K.SetGrainAlpha(alpha)
    local spec = K.theme.grain
    spec.alpha = math.max(0, math.min(1, alpha))
    return spec.alpha
end
function K.GrainDefault(key)
    local preset = K.Theme(key or K.theme.key)
    return preset and preset.grain and preset.grain.alpha or 0
end
function K.Highlight(texture, tone)
    lit[texture] = tone
    local look = K.theme.look.highlight
    texture:SetTexture(look and look.path or K.theme.white)
    texture:SetBlendMode(look and look.blend or "BLEND")
    track(texture, "SetVertexColor")
    texture:SetVertexColor(unpack(K.theme[tone]))
    return texture
end
function K.Skin(frame)
    frame:SetBackdrop(K.theme.buttonSkin)
    track(frame, "SetBackdropColor"); track(frame, "SetBackdropBorderColor")
    return frame
end
local function fillPanel(frame)
    local texture, inset = rawget(frame, "tradeBase"), K.theme.look.fill
    if not texture then return end
    texture:ClearAllPoints()
    if inset == 0 then texture:SetAllPoints(frame); return end
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
end
local function skinPanel(frame)
    frame:SetBackdrop(K.theme.panelSkin)
    local marks = painted[frame] or {}
    for _, method in ipairs({"SetBackdropColor", "SetBackdropBorderColor"}) do
        local mark = marks[method]
        local color = mark and (mark.token and K.Token(mark.token) or mark.args)
        if color then mark.native(frame, unpack(color)) end
    end
    fillPanel(frame)
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
    local inset = K.theme.look.grainInset * 2
    local width, height = math.max(1, (frame:GetWidth() or 0) - inset), math.max(1, (frame:GetHeight() or 0) - inset)
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
        frame.tradeGrain = texture
        frame:HookScript("OnSizeChanged", fitGrain)
    end
    local inset = K.theme.look.grainInset
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    texture:SetTexture(spec.path)
    local tint = K.theme.plain
    texture:SetVertexColor(tint[1], tint[2], tint[3], spec.alpha)
    fitGrain(frame)
    texture:Show()
end
local function near(fs, old)
    local r, g, b = fs:GetTextColor()
    if type(r) ~= "number" then return false end
    return math.abs(r - old[1]) < 0.01 and math.abs(g - old[2]) < 0.01 and math.abs(b - old[3]) < 0.01
end
function K.ApplyTheme(quick)
    index()
    if shownStamp ~= lookStamp then
        shownStamp = lookStamp
        for frame in pairs(panels) do skinPanel(frame) end
        for texture, tone in pairs(lit) do K.Highlight(texture, tone) end
    end
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
            if rawget(frame, "tradeKitButton") then K.StyleButton(frame) end
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
    local tone = kind == "title" and "gold" or (kind == "heading" or kind == "secondary") and kind or "text"
    fs:SetTextColor(unpack(K.theme[tone]))
    fs:SetText(text)
    labels[fs] = tone
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
    panels[parent] = true
    parent:SetBackdrop(K.theme.panelSkin)
    fillPanel(parent)
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
    local card = K.Skin(ns.NewFrame("Frame", nil, parent))
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
function K.Unlearned(parent, size)
    local cross = parent:CreateTexture(nil, "OVERLAY")
    cross:SetTexture(K.theme.actionIcons.unlearned[1])
    cross:SetWidth(size or 12); cross:SetHeight(size or 12)
    cross:Hide()
    return cross
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
