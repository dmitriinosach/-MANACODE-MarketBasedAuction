local ADDON, ns = ...
local K = ns.TradeKit
local Palette = {defaults = {}, rows = {}}
K.Palette = Palette
for _, path in ipairs(K.TOKENS) do
    local c = K.Token(path)
    Palette.defaults[path] = {c[1], c[2], c[3], c[4]}
end
Palette.grainDefault = {key = K.theme.grain.key, alpha = K.theme.grain.alpha}
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
function Palette.Overrides()
    local db = ns.Store.DB()
    db.themeOverrides = db.themeOverrides or {}
    return db.themeOverrides
end
function Palette.Name(path)
    local group, part = path:match("^(%w+)%.(%w+)$")
    if group then return ns.T("palGroup_" .. group) .. ": " .. ns.T("palPart_" .. part) end
    return ns.T("palTok_" .. path)
end
local function store(path)
    local overrides, color = Palette.Overrides(), K.Token(path)
    if same(color, Palette.defaults[path]) then
        overrides[path] = nil
    else
        overrides[path] = {round(color[1]), round(color[2]), round(color[3]), color[4] and round(color[4]) or nil}
    end
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
function Palette.SetGrain(key, alpha)
    if not K.SetGrain(key, alpha) then return false end
    local overrides, spec = Palette.Overrides(), K.theme.grain
    local plain = spec.key == Palette.grainDefault.key and math.abs(spec.alpha - Palette.grainDefault.alpha) < 0.001
    overrides.grain = not plain and spec.key or nil
    overrides.grainAlpha = not plain and round(spec.alpha) or nil
    K.ApplyTheme()
    Palette.Render()
    return true
end
function Palette.CycleGrain()
    local options, at = K.theme.grains, 1
    for i, option in ipairs(options) do if option.key == K.theme.grain.key then at = i end end
    local nextKey = options[at % #options + 1].key
    Palette.SetGrain(nextKey)
    return nextKey
end
function Palette.Strength(step)
    local spec = K.theme.grain
    Palette.SetGrain(spec.key, round(spec.alpha + step))
    return spec.alpha
end
function Palette.Reset()
    if Palette.picking and ColorPickerFrame and ColorPickerFrame:IsShown() then
        ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = nil, nil, nil
        ColorPickerFrame:Hide()
    end
    Palette.picking = nil
    for path, color in pairs(Palette.defaults) do K.SetToken(path, color[1], color[2], color[3], color[4]) end
    K.SetGrain(Palette.grainDefault.key, Palette.grainDefault.alpha)
    ns.Store.DB().themeOverrides = nil
    Palette.pending = nil
    K.ApplyTheme()
    Palette.Render()
end
function Palette.Load()
    local overrides, applied = ns.Store.DB().themeOverrides, 0
    if type(overrides) ~= "table" then return 0 end
    for path, color in pairs(overrides) do
        if type(color) == "table" and K.Token(path) and type(color[1]) == "number" and type(color[2]) == "number"
            and type(color[3]) == "number" then
            K.SetToken(path, color[1], color[2], color[3], color[4])
            applied = applied + 1
        end
    end
    if type(overrides.grain) == "string" then
        K.SetGrain(overrides.grain, type(overrides.grainAlpha) == "number" and overrides.grainAlpha or nil)
    end
    K.ApplyTheme(true)
    return applied
end
local function literal(color)
    local parts = {}
    for i = 1, #color do parts[i] = number(color[i]) end
    return "{" .. table.concat(parts, ", ") .. "}"
end
function Palette.Snapshot()
    local out, groups, order = {}, {}, {}
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
    out[#out + 1] = string.format("grain = {key = %q, alpha = %s}", spec.key, number(spec.alpha))
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
    row.mark:SetAllPoints(row); row.mark:SetTexture(K.theme.white); row.mark:SetVertexColor(unpack(K.theme.selected))
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
    f.grain = K.Button(f, "", 150, function() Palette.CycleGrain() end)
    f.grain:SetPoint("TOPLEFT", f, "TOPLEFT", 12, y)
    f.weaker = K.Button(f, "-", 24, function() Palette.Strength(-Palette.STEP) end)
    f.weaker:SetPoint("LEFT", f.grain, "RIGHT", 6, 0)
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
    f.grain:SetText(ns.T("palGrain", ns.T("palGrain_" .. spec.key)))
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
