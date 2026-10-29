local _, ns = ...
local K = ns.TradeKit
local stack = {shown = {}}
K.overlays = stack
local function remove(frame)
    for i = #stack.shown, 1, -1 do
        if stack.shown[i] == frame then table.remove(stack.shown, i) end
    end
end
local function sync()
    if not stack.escape and #stack.shown > 0 and type(UIMenus) == "table" then
        stack.escape = ns.NewFrame("Frame", "ManaCodeOverlayEscape")
        stack.escape:SetScript("OnHide", function() if not stack.syncing then K.CloseTop() end end)
        table.insert(UIMenus, "ManaCodeOverlayEscape")
    end
    if not stack.escape then return end
    stack.syncing = true
    if #stack.shown > 0 then stack.escape:Show() else stack.escape:Hide() end
    stack.syncing = nil
end
local function push(frame)
    remove(frame)
    stack.shown[#stack.shown + 1] = frame
    frame:Raise()
    sync()
end
function K.TopOverlay()
    for i = #stack.shown, 1, -1 do
        local frame = stack.shown[i]
        if frame:IsVisible() then return frame end
        table.remove(stack.shown, i)
    end
    sync()
    return nil
end
function K.CloseTop()
    local top = K.TopOverlay()
    if not top then return false end
    top:Hide()
    remove(top)
    sync()
    return true
end
function K.Overlay(frame)
    frame:HookScript("OnShow", push)
    frame:HookScript("OnHide", function(self) remove(self); sync() end)
    local show = frame.Show
    frame.Show = function(self)
        show(self)
        if self:IsVisible() then push(self) end
    end
    return frame
end
local function inputs(frame, found)
    for _, child in ipairs({frame:GetChildren()}) do
        if child:GetObjectType() == "EditBox" then found[#found + 1] = child end
        inputs(child, found)
    end
    return found
end
function K.Unsaved(frame)
    for _, edit in ipairs(inputs(frame, {})) do
        if edit:IsShown() and (edit:GetText() or "") ~= ((frame.opened or {})[edit] or "") then return true end
    end
    return false
end
local function remember(frame)
    frame.opened = {}
    for _, edit in ipairs(inputs(frame, {})) do frame.opened[edit] = edit:GetText() or "" end
end
local function pointer(button)
    return button == nil or button == "LeftButton" or button == "RightButton"
end
local function placeCover(frame)
    local host = ns.AuctionWindow and ns.AuctionWindow.frame
    frame.cover:ClearAllPoints()
    if host and host:IsVisible() then frame.cover:SetAllPoints(host); frame.cover:Show()
    else frame.cover:Hide() end
end
function K.Window(parent, title, width, height)
    local frame = ns.NewFrame("Frame", nil, parent)
    frame:SetWidth(width); frame:SetHeight(height)
    frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG"); frame:EnableMouse(true)
    frame:SetMovable(true); frame:SetClampedToScreen(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    K.Panel(frame)
    frame.cover = ns.NewFrame("Frame", nil, frame)
    frame.cover:SetFrameStrata("HIGH"); frame.cover:EnableMouse(true)
    local shade = frame.cover:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints(frame.cover); shade:SetTexture(K.theme.white); shade:SetVertexColor(unpack(K.theme.shade))
    frame.cover:SetScript("OnMouseDown", function(_, button)
        if pointer(button) and not K.Unsaved(frame) then frame:Hide() end
    end)
    frame.heading = K.Label(frame, title, 14, -12, width - 100, "heading")
    frame.close = K.Button(frame, ns.T("acCloseWindow"), 66, function() frame:Hide() end, "quiet")
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -8)
    local show = frame.Show
    frame.Show = function(self)
        if not self:IsShown() then remember(self) end
        placeCover(self)
        show(self)
    end
    K.Overlay(frame)
    frame:Hide()
    return frame
end
function K.Modal(parent, name)
    local dim = ns.NewFrame("Frame", name, parent)
    dim:SetAllPoints(parent)
    dim:SetFrameStrata("DIALOG")
    dim:SetFrameLevel(parent:GetFrameLevel() + 40)
    dim:EnableMouse(true)
    dim:SetScript("OnMouseDown", function(self, button) if pointer(button) then self:Hide() end end)
    local shade = dim:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints(dim); shade:SetTexture(K.theme.white); shade:SetVertexColor(unpack(K.theme.shade))
    local window = ns.NewFrame("Frame", nil, dim)
    window:SetPoint("CENTER", dim, "CENTER", 0, 0)
    window:EnableMouse(true)
    K.Panel(window)
    dim.window = window
    dim.close = ns.NewFrame("Button", nil, window, "UIPanelCloseButton")
    dim.close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -2, -2)
    dim.close:SetScript("OnClick", function() dim:Hide() end)
    dim.Layout = function(self)
        local width = math.max(600, math.min(940, (parent:GetWidth() or 996) - 40))
        local height = math.max(380, math.min(580, (parent:GetHeight() or 540) - 40))
        window:SetWidth(width); window:SetHeight(height)
    end
    dim:SetScript("OnShow", function(self) self:Layout() end)
    dim:Layout()
    K.Overlay(dim)
    dim:Hide()
    return dim
end
