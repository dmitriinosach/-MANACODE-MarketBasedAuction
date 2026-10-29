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
function K.TableScroll(parent, changed, top, bottom, rowHeight)
    local scroll = K.Scroller:New(parent, changed, rowHeight)
    scroll.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -top)
    scroll.frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -280, bottom)
    return scroll
end
function K.ListCapacity(frame, top, bottom, rowHeight, maximum)
    return math.max(1, math.min(maximum, math.floor(((frame:GetHeight() or 510) - top - bottom) / rowHeight)))
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
function PanelScroll:New(inspector, name, height)
    local view = setmetatable({inspector = inspector}, self)
    local body = inspector.body
    view.frame = ns.NewFrame("ScrollFrame", name, body, "UIPanelScrollFrameTemplate")
    view.frame.scrollBarHideable = 1
    view.frame:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -40)
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
function PanelScroll:Fit(height)
    local body = self.inspector.body
    local room = (body:GetHeight() or 0) - 44
    local fits = room <= 0 or height <= room
    local bar = fits and 0 or K.theme.scrollBar
    local width = (self.inspector.width or 264) - bar
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -40)
    self.frame:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -bar, 4)
    K.PanelScrollBar(self.frame, fits)
    self.child:SetWidth(width); self.child:SetHeight(height)
    return width
end
