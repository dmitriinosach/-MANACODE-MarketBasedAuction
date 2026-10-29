local _, ns = ...
local K = ns.TradeKit
local Tile = {}
Tile.__index = Tile
K.StatTile = Tile
function Tile:New(parent)
    local tile = setmetatable({}, self)
    local f = ns.NewFrame("Frame", nil, parent)
    tile.frame = f
    f:SetHeight(54); f:EnableMouse(true)
    f:SetBackdrop(K.theme.buttonSkin)
    f:SetBackdropColor(unpack(K.theme.chart.tile))
    f:SetBackdropBorderColor(unpack(K.theme.quiet.edge))
    tile.accent = f:CreateTexture(nil, "ARTWORK")
    tile.accent:SetTexture(K.theme.white); tile.accent:SetWidth(2)
    tile.accent:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -6)
    tile.accent:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 6)
    tile.title = K.Label(f, "", 11, -7, 120); tile.title:SetHeight(12)
    tile.title:SetTextColor(unpack(K.theme.secondary))
    tile.value = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tile.value:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -21); tile.value:SetHeight(16)
    tile.value:SetJustifyH("LEFT")
    tile.note = K.Label(f, "", 11, -39, 120); tile.note:SetHeight(12)
    return tile
end
function Tile:SetProps(props)
    self.props = props; self:Render()
end
function Tile:Render()
    local p = self.props
    local inner = math.max(40, (p.width or 140) - 16)
    self.frame:SetWidth(p.width or 140)
    self.title:SetWidth(inner); self.value:SetWidth(inner); self.note:SetWidth(inner)
    self.title:SetText(p.title); self.value:SetText(p.value); self.note:SetText(p.note or "")
    self.note:SetTextColor(unpack(K.theme[p.tone or "secondary"]))
    self.accent:SetVertexColor(unpack(p.accent or K.theme.gold))
    K.Tooltip(self.frame, p.title, p.tip or "")
end
local TimeChart = {}
TimeChart.__index = TimeChart
K.TimeChart = TimeChart
local timeSteps = {3600, 7200, 10800, 21600, 43200, 86400, 172800, 259200, 432000, 604800, 1209600}
local function niceStep(value)
    if value <= 0 then return 1 end
    local power = 10 ^ math.floor(math.log(value) / math.log(10) + 1e-9)
    for _, m in ipairs({1, 2, 5, 10}) do
        if value <= m * power * (1 + 1e-9) then return m * power end
    end
    return 10 * power
end
function K.DayShift()
    local now = time()
    local here, utc = date("*t", now), date("!*t", now)
    if type(here) ~= "table" or type(utc) ~= "table" then return 0 end
    local shift = (here.hour - utc.hour) * 3600 + (here.min - utc.min) * 60
    if here.yday ~= utc.yday then
        shift = shift + ((here.year > utc.year or (here.year == utc.year and here.yday > utc.yday)) and 86400 or -86400)
    end
    return shift
end
function TimeChart:New(parent)
    local chart = setmetatable({texts = {}, textUsed = 0, dots = {},
        pools = {BACKGROUND = {used = 0}, BORDER = {used = 0}, ARTWORK = {used = 0}}}, self)
    local f = ns.NewFrame("Frame", nil, parent)
    chart.frame = f
    f:EnableMouse(true)
    local overlay = ns.NewFrame("Frame", nil, f)
    chart.overlay = overlay
    overlay:SetAllPoints(f); overlay:SetFrameLevel(f:GetFrameLevel() + 5)
    chart.cursor = overlay:CreateTexture(nil, "ARTWORK")
    chart.cursor:SetTexture(K.theme.white); chart.cursor:SetVertexColor(unpack(K.theme.chart.cursor))
    chart.cursor:SetWidth(1)
    chart.stamp = overlay:CreateTexture(nil, "ARTWORK")
    chart.stamp:SetTexture(K.theme.white); chart.stamp:SetVertexColor(unpack(K.theme.chart.shade))
    chart.stamp:SetWidth(84); chart.stamp:SetHeight(14)
    chart.stampText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chart.stampText:SetPoint("CENTER", chart.stamp, "CENTER", 0, 0)
    chart.anchor = ns.NewFrame("Frame", nil, overlay)
    chart.anchor:SetWidth(1); chart.anchor:SetHeight(1)
    chart.empty = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chart.empty:SetPoint("CENTER", f, "CENTER", 0, 0); chart.empty:SetWidth(320)
    chart.empty:SetTextColor(unpack(K.theme.secondary))
    f:SetScript("OnEnter", function() f:SetScript("OnUpdate", function() chart:Hover() end) end)
    f:SetScript("OnLeave", function() f:SetScript("OnUpdate", nil); chart:Unhover() end)
    f:SetScript("OnSizeChanged", function() if chart.props then chart:Render() end end)
    chart:Unhover()
    return chart
end
function TimeChart:SetProps(props)
    self.props = props; self:Render()
end
function TimeChart:Rect(layer, color, x, y, w, h, alpha, gradient)
    local pool = self.pools[layer]
    pool.used = pool.used + 1
    local t = pool[pool.used]
    if not t then
        t = self.frame:CreateTexture(nil, layer); t:SetTexture(K.theme.white)
        pool[pool.used] = t
    end
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, -y)
    t:SetWidth(math.max(1, w)); t:SetHeight(math.max(1, h))
    local a = (color[4] or 1) * (alpha or 1)
    if gradient then
        t:SetVertexColor(unpack(K.theme.plain))
        ns.Gradient(t, "VERTICAL", color[1], color[2], color[3], 0.02, color[1], color[2], color[3], a)
    else
        ns.Gradient(t, "VERTICAL", 1, 1, 1, 1, 1, 1, 1, 1)
        t:SetVertexColor(color[1], color[2], color[3], a)
    end
    t:Show()
    return t
end
function TimeChart:Text(text, x, y, width, justify, color)
    self.textUsed = self.textUsed + 1
    local fs = self.texts[self.textUsed]
    if not fs then
        fs = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.texts[self.textUsed] = fs
    end
    fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, -y)
    fs:SetWidth(width); fs:SetHeight(12); fs:SetJustifyH(justify or "LEFT")
    fs:SetTextColor(unpack(color or K.theme.secondary)); fs:SetText(text); fs:Show()
    return fs
end
function TimeChart:Render()
    local p = self.props
    for _, pool in pairs(self.pools) do
        for i = 1, pool.used do pool[i]:Hide() end
        pool.used = 0
    end
    for i = 1, self.textUsed do self.texts[i]:Hide() end
    self.textUsed, self.layout = 0, nil
    self:Unhover()
    local width, height = self.frame:GetWidth() or 0, self.frame:GetHeight() or 0
    self.empty:SetText(p.empty or "")
    if p.empty or width < 160 or height < 90 then return end
    local gutter, axis = 8, 72
    local plot = width - gutter - axis
    local count = math.max(8, math.min(120, math.floor(plot / 6)))
    local layout = {gutter = gutter, plot = plot, axis = gutter + plot, axisWidth = axis, count = count, slot = plot / count,
        buckets = p.buckets(count), boxes = {}, span = math.max(1, p.to - p.from)}
    self.layout = layout
    local total, gap, top = 0, 8, 0
    for _, track in ipairs(p.tracks) do total = total + track.weight end
    local available = height - 16 - gap * (#p.tracks - 1)
    for _, track in ipairs(p.tracks) do
        local h = math.floor(available * track.weight / total)
        local box = {track = track, top = top + 16, height = h - 16}
        layout.boxes[#layout.boxes + 1] = box
        self:Header(box)
        if track.kind == "price" then self:Price(box) elseif track.kind == "bars" then self:Bars(box) else self:Flow(box) end
        top = top + h + gap
    end
    layout.bottom = top - gap
    self:Ruler()
end
function TimeChart:Header(box)
    local track, x = box.track, self.layout.gutter
    local title = self:Text(track.title, x, box.top - 15, 200, "LEFT", K.theme.text)
    x = x + math.min(200, title:GetStringWidth() or 120) + 10
    if track.change then
        local change = self:Text(track.change, x, box.top - 15, 140, "LEFT", K.theme[track.tone or "secondary"])
        x = x + math.min(140, change:GetStringWidth() or 60) + 14
    end
    local legend = {}
    for _, series in ipairs(track.series) do legend[#legend + 1] = series end
    for _, series in ipairs(track.down or {}) do legend[#legend + 1] = series end
    for _, series in ipairs(track.extraLegend or {}) do legend[#legend + 1] = series end
    if track.median then legend[#legend + 1] = {color = K.theme.chart.median, legend = track.medianLegend} end
    for _, series in ipairs(legend) do
        if series.legend then
            self:Rect("ARTWORK", series.color, x, box.top - 12, 8, 8)
            local label = self:Text(series.legend, x + 11, box.top - 15, 140)
            x = x + 25 + math.min(140, label:GetStringWidth() or 80)
        end
    end
end
function TimeChart:Grid(box, low, high, step)
    local layout = self.layout
    local value = low
    while value <= high + step * 0.001 do
        local y = box.scale(value)
        self:Rect("BACKGROUND", K.theme.chart.grid, layout.gutter, y, layout.plot, 1)
        self:Text(box.track.format(value), layout.axis + 6, y - 6, layout.axisWidth - 8, "LEFT")
        value = value + step
    end
    self:Rect("BACKGROUND", K.theme.chart.axis, layout.axis, box.top, 1, box.height)
end
function TimeChart:Center(i)
    return self.layout.gutter + (i - 0.5) * self.layout.slot
end
function TimeChart:Price(box)
    local layout, track, p = self.layout, box.track, self.props
    local candles = p.mode == "candles" and p.candles and p.candles() or nil
    if candles and #candles == 0 then candles = nil end
    local low, high
    local function widen(value)
        if value then low, high = math.min(low or value, value), math.max(high or value, value) end
    end
    if candles then
        for _, candle in ipairs(candles) do widen(candle.low); widen(candle.high) end
    else
        for i = 1, layout.count do
            local b = layout.buckets[i]
            for _, series in ipairs(b and track.series or {}) do widen(b[series.field]) end
        end
    end
    for _, reference in ipairs(track.references or {}) do widen(reference.value) end
    for _, marker in ipairs(track.markers or {}) do
        if marker.at >= p.from and marker.at <= p.to then widen(marker.value) end
    end
    if not low then return end
    if high - low < math.max(1, high * 0.02) then low, high = low * 0.95, high * 1.05 + 1 end
    local step = niceStep((high - low) / 3)
    low, high = math.floor(low / step) * step, math.ceil(high / step) * step
    local base = box.top + box.height
    box.scale = function(v) return base - (v - low) / math.max(1, high - low) * box.height end
    self:Grid(box, low, high, step)
    if track.median then
        self:Rect("BORDER", K.theme.chart.median, layout.gutter, box.scale(track.median), layout.plot, 1)
    end
    for _, reference in ipairs(track.references or {}) do
        local y = box.scale(reference.value)
        for x = layout.gutter, layout.gutter + layout.plot - 4, 10 do
            self:Rect("BORDER", reference.color, x, y, 5, 1)
        end
    end
    if candles then self:Candles(box, candles) else self:Lines(box) end
    for _, marker in ipairs(track.markers or {}) do
        if marker.at >= p.from and marker.at <= p.to then
            local x = layout.gutter + (marker.at - p.from) / layout.span * layout.plot
            x = math.max(layout.gutter + 3, math.min(layout.gutter + layout.plot - 3, x))
            self:Rect("ARTWORK", marker.color, x - 3, box.scale(marker.value) - 3, 6, 6)
        end
    end
    if track.last then
        local y = math.max(box.top + 7, math.min(base - 7, box.scale(track.last)))
        self:Rect("ARTWORK", K.theme.chart.shade, layout.axis + 2, y - 7, layout.axisWidth - 4, 14, 0.9)
        self:Rect("ARTWORK", K.theme[track.tone or "text"], layout.axis, y, 4, 1)
        self:Text(track.format(track.last), layout.axis + 6, y - 6, layout.axisWidth - 8, "LEFT", K.theme[track.tone or "text"])
    end
end
function TimeChart:Segment(box, series, x0, y0, x1, y1, dim)
    local thick, base = series.thick or 2, box.top + box.height
    local x, dx = x0, math.max(1, x1 - x0)
    while x < x1 do
        local w = math.min(2, x1 - x)
        local ya = y0 + (y1 - y0) * (x - x0) / dx
        local yb = y0 + (y1 - y0) * (x + w - x0) / dx
        local top = math.min(ya, yb) - thick / 2
        self:Rect("ARTWORK", series.color, x, top, w, math.abs(yb - ya) + thick, dim and 0.35 or 1)
        if series.area and base - top - thick > 1 then
            self:Rect("BORDER", series.color, x, top + thick, w, base - top - thick, dim and 0.08 or 0.28, true)
        end
        x = x + w
    end
end
function TimeChart:Lines(box)
    local layout, track = self.layout, box.track
    local limit = math.max(1, math.ceil(43200 / (layout.span / layout.count)))
    for _, series in ipairs(track.series) do
        local last, lastValue
        for i = 1, layout.count do
            local b = layout.buckets[i]
            local value = b and b[series.field]
            if value then
                if last then
                    self:Segment(box, series, self:Center(last), box.scale(lastValue), self:Center(i), box.scale(value),
                        i - last > limit)
                end
                if series.dots and layout.slot >= 4 then
                    self:Rect("ARTWORK", series.color, self:Center(i) - 2, box.scale(value) - 2, 4, 4)
                end
                last, lastValue = i, value
            end
        end
        if last and last < layout.count then
            self:Segment(box, series, self:Center(last), box.scale(lastValue), layout.gutter + layout.plot,
                box.scale(lastValue), true)
        end
    end
end
function TimeChart:Candles(box, candles)
    local layout, p = self.layout, self.props
    local width = math.max(3, math.min(12, math.floor(layout.plot / math.max(1, p.days or 7) * 0.6)))
    for _, candle in ipairs(candles) do
        local x = layout.gutter + (candle.at - p.from) / layout.span * layout.plot
        x = math.max(layout.gutter + width / 2, math.min(layout.gutter + layout.plot - width / 2, x))
        local color = K.theme[candle.close >= candle.open and "positive" or "negative"]
        local top, bottom = box.scale(math.max(candle.open, candle.close)), box.scale(math.min(candle.open, candle.close))
        self:Rect("ARTWORK", color, x - width / 2, top, width, math.max(1, bottom - top))
        self:Rect("BORDER", color, x - 0.5, box.scale(candle.high), 1, math.max(1, box.scale(candle.low) - box.scale(candle.high)))
    end
end
function TimeChart:Bars(box)
    local layout, series = self.layout, box.track.series[1]
    local high = 0
    for i = 1, layout.count do
        local b = layout.buckets[i]
        if b and b[series.field] then high = math.max(high, b[series.field]) end
    end
    local step = niceStep(math.max(1, high) / 2)
    high = math.max(step, math.ceil(high / step) * step)
    local base = box.top + box.height
    box.scale = function(v) return base - v / high * box.height end
    self:Grid(box, 0, high, step)
    local width = math.max(1, math.min(12, layout.slot - 1))
    for i = 1, layout.count do
        local b = layout.buckets[i]
        local v = b and b[series.field]
        if v then
            local h = math.max(1, v / high * box.height)
            self:Rect("ARTWORK", series.color, self:Center(i) - width / 2, base - h, width, h, v > 0 and 0.85 or 0.35)
        end
    end
end
function TimeChart:Flow(box)
    local layout, track = self.layout, box.track
    local high = 0
    for i = 1, layout.count do
        local b = layout.buckets[i]
        if b and b.compared > 0 then
            local up, down = 0, 0
            for _, series in ipairs(track.series) do up = up + b[series.field] end
            for _, series in ipairs(track.down) do down = down + b[series.field] end
            high = math.max(high, up, down)
        end
    end
    local step = niceStep(math.max(1, high))
    high = math.max(step, math.ceil(high / step) * step)
    local middle, half = box.top + box.height / 2, box.height / 2
    box.scale = function(v) return middle - v / high * half end
    self:Grid(box, -high, high, high)
    self:Rect("BORDER", K.theme.chart.axis, layout.gutter, middle, layout.plot, 1)
    local width = math.max(1, math.min(12, layout.slot - 1))
    for i = 1, layout.count do
        local b = layout.buckets[i]
        if b and b.compared > 0 then
            local x, y, moved = self:Center(i) - width / 2, middle, false
            for _, series in ipairs(track.series) do
                local h = b[series.field] / high * half
                if h > 0 then y, moved = y - h, true; self:Rect("ARTWORK", series.color, x, y, width, h, 0.9) end
            end
            y = middle + 1
            for _, series in ipairs(track.down) do
                local h = b[series.field] / high * half
                if h > 0 then moved = true; self:Rect("ARTWORK", series.color, x, y, width, h, 0.9); y = y + h end
            end
            if not moved then self:Rect("ARTWORK", K.theme.chart.late, x, middle - 1, width, 3, 0.5) end
        end
    end
end
function TimeChart:Ruler()
    local layout, p = self.layout, self.props
    local slots = math.max(2, math.floor(layout.plot / 72))
    local step = timeSteps[#timeSteps]
    for _, value in ipairs(timeSteps) do
        if layout.span / value <= slots then step = value; break end
    end
    local shift = K.DayShift()
    local t = math.ceil((p.from + shift) / step) * step - shift
    while t <= p.to do
        local x = layout.gutter + (t - p.from) / layout.span * layout.plot
        self:Rect("BACKGROUND", K.theme.chart.grid, x, 0, 1, layout.bottom)
        local midnight = (t + shift) % 86400 == 0
        self:Text(date((step < 86400 and not midnight) and "%H:%M" or "%d.%m", t), x - 30, layout.bottom + 4, 60, "CENTER")
        t = t + step
    end
end
function TimeChart:Hover()
    local layout = self.layout
    if not layout then return end
    local cursor = GetCursorPosition()
    local x = cursor / (self.frame:GetEffectiveScale() or 1) - (self.frame:GetLeft() or 0)
    for _, box in ipairs(layout.boxes) do
        for index, marker in ipairs(box.scale and box.track.markers or {}) do
            local px = layout.gutter + (marker.at - self.props.from) / layout.span * layout.plot
            if marker.at >= self.props.from and marker.at <= self.props.to and math.abs(x - px) <= 7 and self.props.markerTip then
                local key = "marker:" .. index
                if self.hovered == key then return end
                self:Unhover(); self.hovered = key
                self.anchor:ClearAllPoints(); self.anchor:SetPoint("TOPLEFT", self.frame, "TOPLEFT", px, -box.scale(marker.value))
                GameTooltip:SetOwner(self.anchor, "ANCHOR_RIGHT")
                local title, body = self.props.markerTip(marker)
                GameTooltip:AddLine(title, unpack(K.theme.gold))
                GameTooltip:AddLine(body, unpack(K.theme.text)); GameTooltip:Show()
                return
            end
        end
    end
    local index = math.floor((x - layout.gutter) / layout.slot) + 1
    if index < 1 or index > layout.count then self:Unhover(); return end
    local found
    for d = 0, layout.count do
        if layout.buckets[index - d] then found = index - d; break end
        if layout.buckets[index + d] then found = index + d; break end
    end
    if not found then self:Unhover(); return end
    if found == self.hovered then return end
    self.hovered = found
    local bucket, cx = layout.buckets[found], self:Center(found)
    self.cursor:ClearAllPoints()
    self.cursor:SetPoint("TOPLEFT", self.frame, "TOPLEFT", cx, 0)
    self.cursor:SetHeight(math.max(1, layout.bottom)); self.cursor:Show()
    self.stamp:ClearAllPoints()
    self.stamp:SetPoint("TOP", self.frame, "TOPLEFT", math.max(42, math.min(layout.gutter + layout.plot - 42, cx)),
        -layout.bottom - 2)
    self.stampText:SetText(date("%d.%m %H:%M", bucket.at)); self.stamp:Show(); self.stampText:Show()
    local used = 0
    for _, box in ipairs(layout.boxes) do
        for _, series in ipairs(box.track.kind == "price" and box.scale and self.props.mode ~= "candles" and box.track.series or {}) do
            local value = bucket[series.field]
            if value then
                used = used + 1
                local dot = self.dots[used]
                if not dot then
                    dot = self.overlay:CreateTexture(nil, "OVERLAY"); dot:SetTexture(K.theme.white)
                    dot:SetWidth(7); dot:SetHeight(7); self.dots[used] = dot
                end
                dot:SetVertexColor(unpack(series.color))
                dot:ClearAllPoints(); dot:SetPoint("CENTER", self.frame, "TOPLEFT", cx, -box.scale(value)); dot:Show()
            end
        end
    end
    for i = used + 1, #self.dots do self.dots[i]:Hide() end
    local first = layout.boxes[1]
    self.anchor:ClearAllPoints(); self.anchor:SetPoint("TOPLEFT", self.frame, "TOPLEFT", cx, -(first and first.top or 0))
    GameTooltip:SetOwner(self.anchor, "ANCHOR_NONE")
    if cx > layout.gutter + layout.plot * 0.6 then GameTooltip:SetPoint("TOPRIGHT", self.anchor, "TOPLEFT", -14, 0)
    else GameTooltip:SetPoint("TOPLEFT", self.anchor, "TOPRIGHT", 14, 0) end
    local title, lines = self.props.tip(bucket)
    GameTooltip:AddLine(title, unpack(K.theme.gold))
    local secondary = K.theme.secondary
    for _, line in ipairs(lines) do
        local color = line[3] or K.theme.text
        if line[2] then
            GameTooltip:AddDoubleLine(line[1], line[2], secondary[1], secondary[2], secondary[3], color[1], color[2], color[3])
        else GameTooltip:AddLine(line[1], color[1], color[2], color[3], true) end
    end
    GameTooltip:Show()
end
function TimeChart:Unhover()
    self.hovered = nil
    self.cursor:Hide(); self.stamp:Hide(); self.stampText:Hide()
    for _, dot in ipairs(self.dots) do dot:Hide() end
    if GameTooltip:IsOwned(self.anchor) then GameTooltip:Hide() end
end
