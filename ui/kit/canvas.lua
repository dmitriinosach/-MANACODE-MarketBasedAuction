local _, ns = ...
local K = ns.TradeKit
local Canvas = {MIN = 0.6, MAX = 1.4, STEP = 0.1}
Canvas.__index = Canvas
K.Canvas = Canvas
function Canvas:New(parent, changed)
    local view = setmetatable({zoom = 1, x = 0, y = 0, changed = changed}, self)
    local clip = ns.NewFrame("ScrollFrame", nil, parent)
    view.frame = clip
    local stage = ns.NewFrame("Frame", nil, clip)
    stage:SetWidth(400); stage:SetHeight(300)
    clip:SetScrollChild(stage)
    view.stage = stage
    local base = stage:CreateTexture(nil, "BACKGROUND")
    base:SetAllPoints(stage); base:SetTexture(K.theme.white); base:SetVertexColor(unpack(K.theme.field))
    local world = ns.NewFrame("Frame", nil, stage)
    world:SetWidth(1); world:SetHeight(1)
    view.world = world
    stage:EnableMouse(true)
    stage:EnableMouseWheel(true)
    stage:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then view:BeginDrag() end end)
    stage:SetScript("OnMouseUp", function() view:EndDrag() end)
    stage:SetScript("OnHide", function() view:EndDrag() end)
    stage:SetScript("OnMouseWheel", function(_, delta) view:Zoom(delta) end)
    clip:SetScript("OnSizeChanged", function() view:Fit() end)
    view:Place()
    return view
end
function Canvas:Fit()
    self.stage:SetWidth(math.max(1, self.frame:GetWidth() or 400))
    self.stage:SetHeight(math.max(1, self.frame:GetHeight() or 300))
end
function Canvas:Size()
    return self.frame:GetWidth() or 400, self.frame:GetHeight() or 300
end
function Canvas:Cursor()
    local x, y = GetCursorPosition()
    local scale = self.stage:GetEffectiveScale() or 1
    local left, top = self.stage:GetLeft() or 0, self.stage:GetTop() or 0
    return (x or 0) / scale - left, top - (y or 0) / scale
end
function Canvas:Place()
    self.world:SetScale(self.zoom)
    self.world:ClearAllPoints()
    self.world:SetPoint("TOPLEFT", self.stage, "TOPLEFT", self.x / self.zoom, -self.y / self.zoom)
end
function Canvas:Changed()
    if self.changed then self.changed(self) end
end
function Canvas:BeginDrag()
    local cx, cy = self:Cursor()
    self.drag = {cx = cx, cy = cy, x = self.x, y = self.y, lx = self.x, ly = self.y}
    self.stage:SetScript("OnUpdate", function() self:DragStep() end)
end
function Canvas:DragStep()
    local drag = self.drag
    if not drag then return end
    local cx, cy = self:Cursor()
    self.x, self.y = drag.x + cx - drag.cx, drag.y + cy - drag.cy
    self:Place()
    local width, height = self:Size()
    if math.abs(self.x - drag.lx) > width / 4 or math.abs(self.y - drag.ly) > height / 4 then
        drag.lx, drag.ly = self.x, self.y
        self:Changed()
    end
end
function Canvas:EndDrag()
    if not self.drag then return end
    self.drag = nil
    self.stage:SetScript("OnUpdate", nil)
    self:Changed()
end
function Canvas:Zoom(delta)
    local zoom = math.floor((self.zoom + delta * self.STEP) * 10 + 0.5) / 10
    zoom = math.max(self.MIN, math.min(self.MAX, zoom))
    if zoom == self.zoom then return end
    local cx, cy = self:Cursor()
    local wx, wy = (cx - self.x) / self.zoom, (cy - self.y) / self.zoom
    self.zoom = zoom
    self.x, self.y = cx - wx * zoom, cy - wy * zoom
    self:Place()
    self:Changed()
end
function Canvas:Focus(wx, wy, zoom)
    self.zoom = zoom or self.zoom
    local width, height = self:Size()
    self.x, self.y = width / 2 - wx * self.zoom, height / 2 - wy * self.zoom
    self:Place()
    self:Changed()
end
function Canvas:Visible(margin)
    local width, height = self:Size()
    local padX, padY = width * (margin or 0), height * (margin or 0)
    return (-self.x - padX) / self.zoom, (-self.y - padY) / self.zoom,
        (width - self.x + padX) / self.zoom, (height - self.y + padY) / self.zoom
end
local Connector = {}
Connector.__index = Connector
K.Connector = Connector
function Connector:New(parent)
    local view = setmetatable({parts = {}}, self)
    for i = 1, 3 do
        local line = parent:CreateTexture(nil, "ARTWORK")
        line:SetTexture(K.theme.white)
        line:Hide()
        view.parts[i] = line
    end
    view.parent = parent
    return view
end
function Connector:SetProps(props)
    local mid = math.floor((props.x0 + props.x1) / 2 + 0.5)
    local thick = props.tone == "selected" and 2 or 1
    local color = props.tone == "selected" and {K.theme.accent[1], K.theme.accent[2], K.theme.accent[3], 0.9}
        or K.theme[props.tone] or K.theme.edge
    local top, height = math.min(props.y0, props.y1), math.abs(props.y0 - props.y1)
    local segments = {{math.min(props.x0, mid), props.y0, math.abs(mid - props.x0), thick},
        {mid, top, thick, height + thick},
        {math.min(mid, props.x1), props.y1, math.abs(props.x1 - mid), thick}}
    for i, line in ipairs(self.parts) do
        local s = segments[i]
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", self.parent, "TOPLEFT", s[1], -s[2])
        line:SetWidth(math.max(1, s[3])); line:SetHeight(math.max(1, s[4]))
        line:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        line:Show()
    end
end
function Connector:Hide()
    for _, line in ipairs(self.parts) do line:Hide() end
end
local MapCard = {HEAD = 24, ROW = 18, MAX_ROWS = 8}
MapCard.__index = MapCard
K.MapCard = MapCard
local GLYPHS = {open = "collapse", closed = "expand"}
function MapCard.Height(rows, limit)
    return MapCard.HEAD + math.min(rows, limit or MapCard.MAX_ROWS) * MapCard.ROW + 6
end
function MapCard:New(parent, handlers)
    local view = setmetatable({rows = {}, handlers = handlers}, self)
    local f = K.Card(parent)
    view.frame = f
    view.head = K.ItemChoice(f, function() handlers.select(view, nil) end)
    view.head:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    view.head:SetHeight(self.HEAD - 4)
    view.head.icon:SetWidth(16); view.head.icon:SetHeight(16)
    view.head.text:ClearAllPoints(); view.head.text:SetPoint("LEFT", view.head, "LEFT", 22, 0)
    view.head:SetScript("OnDoubleClick", function() handlers.center(view, nil) end)
    view.value = K.Label(view.head, "", 0, 0, 70); view.value:SetHeight(12); view.value:SetJustifyH("RIGHT")
    view.value:ClearAllPoints(); view.value:SetPoint("RIGHT", view.head, "RIGHT", -4, 0)
    f:Hide()
    return view
end
function MapCard:Row(i)
    if self.rows[i] then return self.rows[i] end
    local view, f = self, self.frame
    local row = K.ItemChoice(f, function() view.handlers.select(view, i) end)
    row:SetHeight(self.ROW)
    row.icon:SetWidth(14); row.icon:SetHeight(14)
    row:SetScript("OnDoubleClick", function() view.handlers.center(view, i) end)
    row.value = K.Label(row, "", 0, 0, 64); row.value:SetHeight(12); row.value:SetJustifyH("RIGHT")
    row.toggle = K.Button(f, "", 16, function() view.handlers.toggle(view, i) end, "quiet")
    K.SetGlyph(row.toggle, "expand")
    row.toggle:SetWidth(16); row.toggle:SetHeight(16)
    K.Tooltip(row.toggle, ns.T("mapToggle"), ns.T("mapToggleTip"))
    self.rows[i] = row
    return row
end
function MapCard:SetProps(props)
    self.props = props
    self:Render()
end
local function fill(b, entry)
    if entry.itemID then K.SetItemChoice(b, entry.itemID, false)
    elseif entry.spellID then K.SetSpellChoice(b, entry.spellID, false)
    else
        b.itemID, b.itemLink, b.spellID = nil, nil, nil
        b.icon:SetTexture(entry.icon)
        K.SetSelected(b, false)
        b:Show()
    end
    if entry.icon and (entry.itemID or entry.spellID) then b.icon:SetTexture(entry.icon) end
    b.text:SetText(entry.text or entry.title or b.text:GetText())
    if entry.color or entry.titleColor then b.text:SetTextColor(unpack(entry.color or entry.titleColor))
    elseif not entry.itemID then b.text:SetTextColor(unpack(K.theme.text)) end
end
function MapCard:Render()
    local p, f = self.props, self.frame
    local width = p.width
    f:SetWidth(width)
    local edge = p.path and K.theme.accent or (p.chosen and K.theme.chosen.edge or K.theme.edge)
    f:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
    fill(self.head, p)
    K.SetSelected(self.head, p.focus)
    self.head.extraTip = p.tip
    self.head:SetWidth(width - 6)
    self.head.text:SetWidth(math.max(40, width - 6 - 22 - 74))
    self.value:SetText(p.value or "")
    self.value:SetTextColor(unpack(K.theme[p.tone or "text"]))
    local inset, limit = p.side < 0 and 20 or 4, p.limit or self.MAX_ROWS
    f:SetHeight(MapCard.Height(#p.rows, limit))
    for i = 1, math.max(#self.rows, math.min(#p.rows, limit)) do
        local entry = i <= limit and p.rows[i] or nil
        local row = entry and self:Row(i) or self.rows[i]
        if entry then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -(self.HEAD + (i - 1) * self.ROW))
            row:SetWidth(width - 24)
            fill(row, entry)
            K.SetSelected(row, entry.path)
            row.text:ClearAllPoints(); row.text:SetPoint("LEFT", row, "LEFT", 18, 0)
            row.text:SetWidth(math.max(30, width - 24 - 18 - 66))
            row.value:ClearAllPoints(); row.value:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            row.value:SetText(entry.value or "")
            row.value:SetTextColor(unpack(K.theme[entry.tone or "secondary"]))
            row.toggle:ClearAllPoints()
            if p.side < 0 then row.toggle:SetPoint("RIGHT", row, "LEFT", -2, 0)
            else row.toggle:SetPoint("LEFT", row, "RIGHT", 2, 0) end
            if entry.toggle then
                K.SetGlyph(row.toggle, GLYPHS[entry.toggle] or (p.side < 0 and "back" or "go"))
                row.toggle:SetWidth(16)
                row.toggle.state = entry.toggle
                row.toggle:Show()
            else row.toggle:Hide() end
        elseif row then
            row:Hide(); row.toggle:Hide()
        end
    end
    f:Show()
end
function MapCard:Hide()
    self.frame:Hide()
    self.props = nil
end
