local _, ns = ...
local K = ns.TradeKit
local Scroller = {}
Scroller.__index = Scroller
K.Scroller = Scroller
local scrollSerial = 0
function Scroller:New(parent, changed, rowHeight)
    scrollSerial = scrollSerial + 1
    local scroll = setmetatable({offset = 0, count = 0, visible = 1, changed = changed, step = rowHeight}, self)
    scroll.frame = ns.NewFrame("Frame", nil, parent)
    scroll.frame:SetFrameLevel(parent:GetFrameLevel())
    scroll.frame:EnableMouse(true)
    scroll.bar = ns.NewFrame("Slider", "ManaCodeAuctionScroll" .. scrollSerial, scroll.frame, "UIPanelScrollBarTemplate")
    scroll.bar:SetPoint("TOPRIGHT", scroll.frame, "TOPRIGHT", 0, -16)
    scroll.bar:SetPoint("BOTTOMRIGHT", scroll.frame, "BOTTOMRIGHT", 0, 16)
    scroll.bar:SetValueStep(rowHeight)
    scroll.bar:SetScript("OnValueChanged", function(_, value)
        if scroll.muted then return end
        scroll:SetOffset(math.floor(value / rowHeight + 0.5))
    end)
    scroll:Wheel(scroll.frame)
    scroll:Wheel(scroll.bar)
    return scroll
end
function Scroller:Wheel(frame)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) self:SetOffset(self.offset - delta * 3) end)
end
function Scroller:SetOffset(offset)
    offset = math.max(0, math.min(math.floor(offset), math.max(0, self.count - self.visible)))
    if offset == self.offset then return end
    self.offset = offset
    self.muted = true
    self.bar:SetValue(offset * self.step)
    self.muted = false
    self.changed()
end
function Scroller:SetRange(count, visible)
    self.count, self.visible = count, math.max(1, visible)
    self.offset = math.max(0, math.min(self.offset, math.max(0, count - self.visible)))
    self.muted = true
    self.bar:SetMinMaxValues(0, math.max(0, count - self.visible) * self.step)
    self.bar:SetValue(self.offset * self.step)
    self.muted = false
    if count > self.visible then self.bar:Show() else self.bar:Hide() end
    return self.offset
end
local Table = {LINE = 24, DOUBLE = 30, HEAD = 22, EDGE = 6, BAR = 16, BAR_GAP = 2, PAD = 4}
Table.__index = Table
K.Table = Table
function Table:New(parent, opts)
    local tbl = setmetatable({parent = parent, opts = opts, offset = 0, headers = {}, pools = {}, lines = {}, starts = {}}, self)
    tbl.frame = ns.NewFrame("Frame", nil, parent)
    K.Panel(tbl.frame)
    tbl.head = ns.NewFrame("Frame", nil, tbl.frame)
    tbl.head:SetHeight(Table.HEAD)
    tbl.band = K.HeaderBand(tbl.head)
    local sortable = {}
    for _, spec in ipairs(opts.headers or {}) do
        local label = K.Label(tbl.head, spec.text and ns.T(spec.text) or "", 0, 0, 100)
        K.SetFontHeight(label, 14)
        label:SetJustifyH(spec.justify or (spec.key == "item" and "LEFT" or "RIGHT"))
        tbl.headers[spec.key] = label
        if spec.sort ~= false then sortable[spec.key] = label end
        if spec.tip and (not opts.sort or spec.sort == false) then
            local hit = ns.NewFrame("Frame", nil, tbl.head)
            hit:SetAllPoints(label); hit:EnableMouse(true)
            K.Tooltip(hit, ns.T(spec.text), ns.T(spec.tip))
            label.tipHit = hit
        end
    end
    if opts.sort then
        tbl.sorter = K.Sorter(tbl.head, sortable, function()
            tbl:ResetScroll(); opts.changed()
        end, opts.sort.active, opts.sort.default)
        for _, spec in ipairs(opts.headers) do
            local button = tbl.sorter.buttons[spec.key]
            if button and spec.tip then K.Tooltip(button, ns.T("sortTitle"), ns.T(spec.tip) .. "\n\n" .. ns.T("sortTip")) end
        end
    end
    if not opts.headers then tbl.head:Hide() end
    tbl.clip = ns.NewFrame("ScrollFrame", nil, tbl.frame)
    tbl.child = ns.NewFrame("Frame", nil, tbl.clip)
    tbl.child:SetPoint("TOPLEFT", tbl.clip, "TOPLEFT", 0, 0)
    tbl.clip:SetScrollChild(tbl.child)
    tbl.scroller = Scroller:New(tbl.frame, function()
        tbl.offset = tbl.scroller.offset
        tbl:Render()
    end, 1)
    tbl.scroller.frame:EnableMouse(false)
    tbl.scroller:Wheel(tbl.clip)
    tbl.empty = K.Label(tbl.child, "", 0, 0, 100, "secondary")
    K.SetFontHeight(tbl.empty, 14)
    return tbl
end
function Table:Place(props)
    local frame, parent = self.frame, self.parent
    local right, left = props.right or Table.EDGE, props.left or Table.EDGE
    local top, bottom = props.top or 0, props.bottom or 4
    local height = math.max(1, (parent:GetHeight() or 510) - top - bottom)
    local rightInset = type(right) == "number" and right or right.frame:GetWidth() + Table.EDGE * 2
    self.outerWidth = math.max(1, (parent:GetWidth() or 996) - left - rightInset)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", left, -top)
    if type(right) == "number" then
        frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -right, -top)
    else
        frame:SetPoint("TOPRIGHT", right.frame, "TOPLEFT", -Table.EDGE, -top - (right.top or 0))
    end
    frame:SetWidth(self.outerWidth)
    frame:SetHeight(height)
    local inset, head = Table.PAD, self.opts.headers and K.FontHeight(Table.HEAD) or 0
    self.head:SetHeight(head)
    self.height = math.max(1, height - 2 * inset - head)
    self.head:ClearAllPoints()
    self.head:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    self.head:SetWidth(math.max(1, self.outerWidth - 2 * inset))
    self.clip:ClearAllPoints()
    self.clip:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -inset - head)
    self.clip:SetHeight(self.height)
    self.scroller.frame:ClearAllPoints()
    self.scroller.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset - head)
    self.scroller.frame:SetWidth(Table.BAR)
    self.scroller.frame:SetHeight(self.height)
    self.empty:ClearAllPoints()
    self.empty:SetPoint("TOPLEFT", self.child, "TOPLEFT", inset + 4, -4)
end
function Table:Width()
    return self.width or math.max(1, (self.outerWidth or 996) - 2 * Table.PAD)
end
function Table:Rows(kind)
    kind = kind or "row"
    if not self.pools[kind] then self.pools[kind] = {} end
    return self.pools[kind]
end
function Table:Row(kind, index)
    local pool = self:Rows(kind)
    if not pool[index] then
        local row
        if kind == "spoiler" then
            local spec = self.opts.spoiler
            local frame = K.Button(self.child, "", 100, spec.toggle, "quiet")
            frame.text:ClearAllPoints(); frame.text:SetPoint("LEFT", frame, "LEFT", 4, 0)
            K.Tooltip(frame, ns.T("hiddenSection"), ns.T(spec.tip or "hiddenSpoilerTip"))
            row = {frame = frame, SetProps = function(_, p)
                frame:SetText(ns.T(p.open and "hiddenSpoilerOpen" or "hiddenSpoilerClosed", p.count))
            end}
        else row = self.opts.kinds[kind].new(self.child) end
        local mark = rawget(row.frame, "mark")
        if mark then
            mark:ClearAllPoints()
            mark:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0); mark:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", 0, 0)
        end
        self.scroller:Wheel(row.frame)
        row.frame:Hide()
        pool[index] = row
    end
    return pool[index]
end
function Table:Height(line)
    local spec = self.opts.kinds[line.kind or "row"]
    local base = spec and spec.height or self.opts.height or Table.DOUBLE
    return K.FontHeight(base, base >= Table.DOUBLE and 2 or 1)
end
function Table:SetLines(lines, build, layout)
    layout = layout or {}
    local groups = 0
    for _, line in ipairs(lines) do if line.kind == "group" then groups = groups + 1 end end
    self.lift = 0
    local inside = groups == 1 and lines[1] and lines[1].kind == "group" and lines[2] ~= nil
    for i = 2, inside and #lines or 0 do
        if (lines[i].depth or 0) <= (lines[1].depth or 0) then inside = false end
    end
    if inside then
        local rest = {}
        for i = 2, #lines do rest[#rest + 1] = lines[i] end
        lines, self.lift = rest, 1
        if layout.reveal then
            local copy = {}
            for key, value in pairs(layout) do copy[key] = value end
            copy.reveal = layout.reveal > 1 and layout.reveal - 1 or nil
            layout = copy
        end
    end
    self.lines, self.build, self.layout = lines, build, layout
    local y, starts, tree = 0, {}, false
    for i, line in ipairs(lines) do
        starts[i] = y
        y = y + self:Height(line) + (line.divider and K.DIVIDER_GAP or 0)
        tree = tree or line.tree
    end
    self.starts, self.tree, self.totalHeight = starts, tree, y
    self.lastTop = math.max(0, y - self.height)
    local tail = #starts
    while tail > 1 and starts[tail - 1] >= self.lastTop do tail = tail - 1 end
    self.lastOffset = math.max(0, tail - 1)
    self.offset = math.min(self.offset, self.lastOffset)
    if self.layout.reveal then
        self.offset = self.layout.align and math.min(self.layout.reveal - 1, self.lastOffset) or self:RevealOffset(self.layout.reveal)
    end
    self.scroller.offset = self.offset
    self.offset = self.scroller:SetRange(self.lastOffset + 1, 1)
    self:Render()
end
function Table:RevealOffset(index)
    if not self.starts[index] then return self.offset end
    local top = self:Top()
    if self.starts[index] >= top and (self.starts[index + 1] or self.totalHeight) <= top + self.height then
        return self.offset
    end
    return math.min(index - 1, self.lastOffset)
end
function Table:Reveal(index)
    self:SetOffset(self:RevealOffset(index))
end
function Table:SetOffset(offset)
    self.scroller:SetOffset(offset)
end
function Table:ResetScroll()
    self.offset, self.scroller.offset = 0, 0
end
function Table:Top()
    return math.min(self.lastTop or 0, self.starts[self.offset + 1] or 0)
end
function Table:Render()
    local inset = Table.PAD
    local gutter = self.lastOffset > 0 and Table.BAR + Table.BAR_GAP or 0
    self.width = math.max(1, self.outerWidth - 2 * inset - gutter)
    self.clip:SetWidth(self.width + inset)
    self.child:SetWidth(self.width + inset); self.child:SetHeight(self.height)
    local columns = self.opts.columns and self.opts.columns(self.width, self, self.layout) or {}
    self.columns = columns
    K.PlaceHeaders(self.headers, columns, self.head, -4, true, 0)
    if self.sorter then self.sorter:Mark() end
    for _, label in pairs(self.headers) do
        if rawget(label, "tipHit") then
            if label:IsShown() then label.tipHit:Show() else label.tipHit:Hide() end
        end
    end
    self.empty:SetWidth(math.max(1, self.width - 4))
    local empty = self.layout.empty or self.opts.empty
    local text = #self.lines == 0 and (type(empty) == "function" and empty() or empty and ns.T(empty))
    self.empty:SetText(text or "")
    if text then self.empty:Show() else self.empty:Hide() end
    local used, top, first = {}, self:Top(), self.offset + 1
    if first > 1 and self.starts[first] > top then first = first - 1 end
    for i = first, #self.lines do
        local line = self.lines[i]
        local y = self.starts[i] - top + (line.divider and K.DIVIDER_GAP or 0)
        if y >= self.height then break end
        local kind = line.kind or "row"
        local n = (used[kind] or 0) + 1
        local row = self:Row(kind, n)
        used[kind] = n
        local height = self:Height(line)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", self.child, "TOPLEFT", inset, -y)
        row.frame:SetWidth(self.width); row.frame:SetHeight(height)
        local p = self.build(line, self.width, columns, i)
        p.width, p.height, p.divider = self.width, height, line.divider
        p.indent = math.max(0, (line.depth or 0) - (self.lift or 0)) * 8
        p.tree = self.layout.tree
        if p.tree == nil then p.tree = self.tree end
        p.toggleX, p.iconX = p.indent + 4, p.indent + (p.tree and 26 or 4) + (self.layout.cross and K.CROSS or 0)
        row:SetProps(p)
        if row.stripe then
            if (i - first) % 2 == 0 then row.stripe:Show() else row.stripe:Hide() end
        end
        row.frame:Show()
    end
    for kind, pool in pairs(self.pools) do
        for i = (used[kind] or 0) + 1, #pool do pool[i].frame:Hide() end
    end
end
function K.PanelScrollBar(scroll, fits)
    local name = scroll:GetName()
    local bar = name and _G[name .. "ScrollBar"]
    if not bar then return end
    local up, down = _G[name .. "ScrollBarScrollUpButton"], _G[name .. "ScrollBarScrollDownButton"]
    scroll:UpdateScrollChildRect()
    if fits then scroll:SetVerticalScroll(0) end
    for _, part in ipairs({bar, up, down}) do
        if fits then part:Hide() else part:Show() end
    end
end
local PanelScroll = {}
PanelScroll.__index = PanelScroll
K.PanelScroll = PanelScroll
function PanelScroll:New(inspector, name, height, top)
    local view = setmetatable({inspector = inspector, top = top or 40}, self)
    local body = inspector.body
    view.frame = ns.NewFrame("ScrollFrame", name, body, "UIPanelScrollFrameTemplate")
    view.frame.scrollBarHideable = 1
    view.frame:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -view.top)
    view.frame:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 4)
    view.child = ns.NewFrame("Frame", nil, view.frame)
    view.child:SetWidth(inspector.width or 264); view.child:SetHeight(height)
    view.frame:SetScrollChild(view.child)
    view.child:EnableMouseWheel(true)
    view.child:SetScript("OnMouseWheel", function(_, delta)
        if ScrollFrameTemplate_OnMouseWheel then ScrollFrameTemplate_OnMouseWheel(view.frame, delta) end
    end)
    return view
end
function PanelScroll:Room()
    return math.max(0, (self.inspector.body:GetHeight() or 0) - self.top - 4 - (self.reserve or 0))
end
function PanelScroll:Fit(height)
    local body, reserve = self.inspector.body, self.reserve or 0
    local room = (body:GetHeight() or 0) - self.top - 4 - reserve
    local fits = room <= 0 or height <= room
    local bar = fits and 0 or K.theme.scrollBar
    local width = (self.inspector.width or 264) - bar
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -self.top)
    self.frame:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -bar, 4 + reserve)
    K.PanelScrollBar(self.frame, fits)
    self.child:SetWidth(width); self.child:SetHeight(height)
    return width
end
