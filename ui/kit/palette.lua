local ADDON, ns = ...
local K = ns.TradeKit
local Palette = {defaults = {}, rows = {}}
K.Palette = Palette
local function remember()
    for _, path in ipairs(K.TOKENS) do
        local c = K.ThemeColor(K.theme.key, path)
        Palette.defaults[path] = {c[1], c[2], c[3], c[4]}
    end
end
remember()
Palette.COLUMNS = 3
Palette.ROW = 18
Palette.COLUMN = 172
Palette.SETTLE = 0.15
Palette.STEP = 0.05
local function round(x)
    return math.floor(x * 1000 + 0.5) / 1000
end
local function number(x)
    local milli = math.floor(math.abs(x) * 1000 + 0.5)
    local whole, frac = math.floor(milli / 1000), milli % 1000
    local text = tostring(whole)
    if frac > 0 then text = text .. "." .. (string.format("%03d", frac):gsub("0+$", "")) end
    return (x < 0 and milli > 0) and "-" .. text or text
end
local function same(a, b)
    for i = 1, 4 do
        if (a[i] == nil) ~= (b[i] == nil) then return false end
        if a[i] and math.abs(a[i] - b[i]) > 0.0005 then return false end
    end
    return true
end
function Palette.Overrides(create)
    local db = ns.Store.DB()
    if create and type(db.themeOverrides) ~= "table" then db.themeOverrides = {} end
    return type(db.themeOverrides) == "table" and db.themeOverrides or nil
end
local function edits(create)
    local overrides, key = Palette.Overrides(create), K.theme.key
    if not overrides then return nil end
    if create and type(overrides[key]) ~= "table" then overrides[key] = {} end
    return type(overrides[key]) == "table" and overrides[key] or nil
end
local function tidy()
    local overrides = Palette.Overrides()
    if not overrides then return end
    for _, preset in ipairs(K.THEMES) do
        if type(overrides[preset.key]) == "table" and next(overrides[preset.key]) == nil then overrides[preset.key] = nil end
    end
    if next(overrides) == nil then ns.Store.DB().themeOverrides = nil end
end
function Palette.Name(path)
    local group, part = path:match("^(%w+)%.(%w+)$")
    if group then return ns.T("palGroup_" .. group) .. ": " .. ns.T("palPart_" .. part) end
    return ns.T("palTok_" .. path)
end
local function store(path)
    local color = K.Token(path)
    if same(color, Palette.defaults[path]) then
        local list = edits()
        if list then list[path] = nil end
    else
        edits(true)[path] = {round(color[1]), round(color[2]), round(color[3]), color[4] and round(color[4]) or nil}
    end
    tidy()
end
function Palette.Set(path, r, g, b, a, quick)
    if not K.SetToken(path, r, g, b, a) then return false end
    store(path)
    if quick then
        K.ApplyTheme(true)
        Palette.pending = Palette.SETTLE
    else
        Palette.pending = nil
        K.ApplyTheme()
    end
    Palette.Render()
    return true
end
local function apply(list)
    if type(list) ~= "table" then return 0 end
    local applied = 0
    for path, color in pairs(list) do
        if type(path) == "string" and type(color) == "table" and K.Token(path) and type(color[1]) == "number"
            and type(color[2]) == "number" and type(color[3]) == "number" then
            K.SetToken(path, color[1], color[2], color[3], color[4])
            applied = applied + 1
        end
    end
    if type(list.grainAlpha) == "number" then K.SetGrainAlpha(list.grainAlpha) end
    return applied
end
function Palette.SetTheme(key)
    if not K.SetTheme(key) then return false end
    remember()
    local overrides = Palette.Overrides(key ~= K.THEME)
    if overrides then
        overrides.theme = key ~= K.THEME and key or nil
        apply(overrides[key])
    end
    tidy()
    Palette.pending = nil
    K.ApplyTheme()
    Palette.Render()
    return true
end
function Palette.CycleTheme()
    local at = 1
    for i, preset in ipairs(K.THEMES) do if preset.key == K.theme.key then at = i end end
    local nextKey = K.THEMES[at % #K.THEMES + 1].key
    Palette.SetTheme(nextKey)
    return nextKey
end
function Palette.Strength(step)
    local spec = K.theme.grain
    if not spec.path then return spec.alpha end
    local alpha = K.SetGrainAlpha(round(spec.alpha + step))
    if math.abs(alpha - K.GrainDefault()) < 0.001 then
        local list = edits()
        if list then list.grainAlpha = nil end
    else
        edits(true).grainAlpha = round(alpha)
    end
    tidy()
    K.ApplyTheme()
    Palette.Render()
    return alpha
end
function Palette.Reset()
    if Palette.picking and ColorPickerFrame and ColorPickerFrame:IsShown() then
        ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = nil, nil, nil
        ColorPickerFrame:Hide()
    end
    Palette.picking = nil
    local overrides = Palette.Overrides()
    if overrides then overrides[K.theme.key] = nil end
    tidy()
    K.SetTheme(K.theme.key)
    Palette.pending = nil
    K.ApplyTheme()
    Palette.Render()
end
function Palette.Migrate(overrides)
    local flat = type(overrides.grain) == "string" or type(overrides.grainAlpha) == "number"
    for path in pairs(overrides) do
        if type(path) == "string" and K.Token(path) then flat = true end
    end
    if not flat then return false end
    local key = overrides.grain == "dark" and "dark" or K.THEME
    local list = {}
    for path, value in pairs(overrides) do
        if type(path) == "string" and K.Token(path) then list[path] = value end
    end
    for path in pairs(list) do overrides[path] = nil end
    if key == "dark" and type(overrides.grainAlpha) == "number" then list.grainAlpha = overrides.grainAlpha end
    overrides.grain, overrides.grainAlpha = nil, nil
    overrides.theme = key ~= K.THEME and key or nil
    if next(list) then overrides[key] = list end
    return true
end
function Palette.Load()
    local overrides = Palette.Overrides()
    if overrides then Palette.Migrate(overrides) end
    local key = overrides and type(overrides.theme) == "string" and K.Theme(overrides.theme) and overrides.theme or K.THEME
    if overrides and overrides.theme ~= nil and key == K.THEME then overrides.theme = nil end
    K.SetTheme(key)
    remember()
    local applied = apply(overrides and overrides[key])
    tidy()
    K.ApplyTheme(true)
    return applied
end
local function literal(color)
    local parts = {}
    for i = 1, #color do parts[i] = number(color[i]) end
    return "{" .. table.concat(parts, ", ") .. "}"
end
function Palette.Snapshot()
    local out, groups, order = {string.format("key = %q", K.theme.key)}, {}, {}
    for _, path in ipairs(K.TOKENS) do
        local group, part = path:match("^(%w+)%.(%w+)$")
        if group then
            if not groups[group] then groups[group] = {}; order[#order + 1] = group; out[#out + 1] = group end
            local list = groups[group]
            list[#list + 1] = part .. " = " .. literal(K.Token(path))
        else
            out[#out + 1] = path .. " = " .. literal(K.Token(path))
        end
    end
    for i, entry in ipairs(out) do
        if groups[entry] then out[i] = entry .. " = {" .. table.concat(groups[entry], ", ") .. "}" end
    end
    local spec = K.theme.grain
    local quality = {"[0] = " .. literal(K.theme.quality[0])}
    for i = 1, 7 do quality[#quality + 1] = literal(K.theme.quality[i]) end
    out[#out + 1] = "quality = {" .. table.concat(quality, ", ") .. "}"
    out[#out + 1] = string.format("grain = {alpha = %s}", number(spec.alpha))
    return "{" .. table.concat(out, ", ") .. "}"
end
function Palette.Pick(path)
    local color, picker = K.Token(path), ColorPickerFrame
    if not color or not picker then return false end
    picker.func, picker.opacityFunc, picker.cancelFunc = nil, nil, nil
    picker:Hide()
    Palette.picking = path
    local previous, alpha = {color[1], color[2], color[3], color[4]}, color[4] ~= nil
    picker.hasOpacity = alpha
    picker.opacity = alpha and 1 - color[4] or nil
    picker.previousValues = previous
    picker:SetColorRGB(color[1], color[2], color[3])
    local function step()
        local r, g, b = picker:GetColorRGB()
        local a = alpha and OpacitySliderFrame and 1 - OpacitySliderFrame:GetValue() or nil
        Palette.Set(path, r, g, b, a, true)
    end
    picker.func, picker.opacityFunc = step, step
    picker.cancelFunc = function(values)
        local v = type(values) == "table" and values or previous
        Palette.Set(path, v[1], v[2], v[3], v[4])
    end
    ShowUIPanel(picker)
    Palette.Render()
    return true
end
local function swatchRow(parent, path, i)
    local per = math.ceil(#K.TOKENS / Palette.COLUMNS)
    local column, line = math.floor((i - 1) / per), (i - 1) % per
    local row = ns.NewFrame("Button", nil, parent)
    row:SetWidth(Palette.COLUMN - 4); row:SetHeight(Palette.ROW)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12 + column * Palette.COLUMN, -38 - line * Palette.ROW)
    row.mark = row:CreateTexture(nil, "BACKGROUND")
    row.mark:SetAllPoints(row); K.Highlight(row.mark, "selected")
    row.well = row:CreateTexture(nil, "BORDER")
    row.well:SetWidth(16); row.well:SetHeight(16); row.well:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.well:SetTexture(K.theme.white); row.well:SetVertexColor(unpack(K.theme.edge))
    row.swatch = row:CreateTexture(nil, "ARTWORK")
    row.swatch:SetWidth(14); row.swatch:SetHeight(14); row.swatch:SetPoint("CENTER", row.well, "CENTER", 0, 0)
    row.swatch:SetTexture(K.theme.white)
    row.label = K.Label(row, Palette.Name(path), 24, -3, Palette.COLUMN - 30)
    row.label:SetHeight(12)
    row.path = path
    row:SetScript("OnClick", function(self) Palette.Pick(self.path) end)
    return row
end
function Palette.Build()
    if Palette.frame then return Palette.frame end
    local per = math.ceil(#K.TOKENS / Palette.COLUMNS)
    local width, height = 24 + Palette.COLUMNS * Palette.COLUMN, 38 + per * Palette.ROW + 76
    local f = ns.NewFrame("Frame", nil, UIParent)
    f:SetWidth(width); f:SetHeight(height)
    f:SetPoint("LEFT", UIParent, "LEFT", 40, 40)
    f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
    f:SetMovable(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    K.Panel(f)
    Palette.frame = f
    f.heading = K.Label(f, ns.T("palTitle"), 14, -12, width - 100, "heading")
    f.close = K.Button(f, ns.T("acCloseWindow"), 66, function() f:Hide() end, "quiet")
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -8)
    for i, path in ipairs(K.TOKENS) do Palette.rows[i] = swatchRow(f, path, i) end
    local y = -38 - per * Palette.ROW - 8
    f.theme = K.Button(f, "", 150, function() Palette.CycleTheme() end)
    f.theme:SetPoint("TOPLEFT", f, "TOPLEFT", 12, y)
    f.weaker = K.Button(f, "-", 24, function() Palette.Strength(-Palette.STEP) end)
    f.weaker:SetPoint("LEFT", f.theme, "RIGHT", 6, 0)
    f.strength = K.Label(f, "", 0, 0, 80)
    f.strength:ClearAllPoints(); f.strength:SetPoint("LEFT", f.weaker, "RIGHT", 6, 0)
    f.stronger = K.Button(f, "+", 24, function() Palette.Strength(Palette.STEP) end)
    f.stronger:SetPoint("LEFT", f.weaker, "RIGHT", 90, 0)
    f.copy = K.Button(f, ns.T("palCopy"), 100, function() Palette.Copy() end)
    f.copy:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, y)
    f.reset = K.Button(f, ns.T("palReset"), 100, function() Palette.Reset() end)
    f.reset:SetPoint("RIGHT", f.copy, "LEFT", -6, 0)
    f.code = K.Edit(f, width - 24)
    f.code:SetMaxLetters(0)
    f.code:SetPoint("TOPLEFT", f, "TOPLEFT", 12, y - 30)
    f:SetScript("OnUpdate", function(_, elapsed)
        if not Palette.pending then return end
        Palette.pending = Palette.pending - elapsed
        if Palette.pending <= 0 then Palette.pending = nil; K.ApplyTheme() end
    end)
    K.Overlay(f)
    f:HookScript("OnHide", function()
        if Palette.pending then Palette.pending = nil; K.ApplyTheme() end
    end)
    f:Hide()
    return f
end
function Palette.Copy()
    local f, text = Palette.Build(), Palette.Snapshot()
    f.code:SetText(text)
    f.code:SetFocus()
    f.code:HighlightText()
    return text
end
function Palette.Render()
    local f = Palette.frame
    if not f then return end
    for _, row in ipairs(Palette.rows) do
        local color = K.Token(row.path)
        row.swatch:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        if row.path == Palette.picking then row.mark:Show() else row.mark:Hide() end
    end
    local spec = K.theme.grain
    f.theme:SetText(ns.T("palTheme", ns.T("setTheme_" .. K.theme.key)))
    f.strength:SetText(ns.T("palStrength", math.floor(spec.alpha * 100 + 0.5)))
    if spec.path then f.weaker:Enable(); f.stronger:Enable() else f.weaker:Disable(); f.stronger:Disable() end
end
function Palette.Toggle()
    local f = Palette.Build()
    if f:IsShown() then f:Hide() else f:Show(); Palette.Render() end
    return f:IsShown()
end
local function loaded(frame, event, name)
    if name ~= ADDON then return end
    Palette.Load()
end
if ns.Listen then
    local events = ns.NewFrame("Frame")
    ns.Listen(events, "ADDON_LOADED")
    events:SetScript("OnEvent", loaded)
end
