local _, ns = ...
local K = ns.TradeKit
local COLUMNS, TILES, TILE = 4, 12, 256
local WIDTH, HEIGHT = 1002, 668
local PIN, SMALL = 22, 12
local ZoneMap = {}
ZoneMap.__index = ZoneMap
K.ZoneMap = ZoneMap
local function pinEnter(pin)
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine(pin.title or "", unpack(K.theme.gold))
    GameTooltip:Show()
end
function ZoneMap:New(parent)
    local map = setmetatable({props = {points = {}, title = "", width = WIDTH}, tiles = {}, pins = {}}, self)
    map.frame = ns.NewFrame("Frame", nil, parent)
    K.Background(map.frame)
    for i = 1, TILES do map.tiles[i] = map.frame:CreateTexture(nil, "ARTWORK") end
    map.layer = ns.NewFrame("Frame", nil, map.frame)
    map.layer:SetAllPoints(map.frame)
    map.layer:SetFrameLevel(map.frame:GetFrameLevel() + 2)
    map.label = map.layer:CreateFontString(nil, "OVERLAY", K.Font("ManaCodeMapPinFont", "GameFontNormal", 12, "OUTLINE"))
    map.label:SetTextColor(unpack(K.theme.pin.label))
    map.label:SetShadowColor(unpack(K.theme.pin.shadow)); map.label:SetShadowOffset(1, -1)
    map.label:Hide()
    return map
end
local function disc(pin, layer, color)
    local texture = K.Picture(pin, K.theme.dot, layer)
    texture:ClearAllPoints(); texture:SetVertexColor(unpack(color))
    return texture
end
function ZoneMap:SetProps(props)
    for key, value in pairs(props) do self.props[key] = value end
    self:Render()
end
function ZoneMap:Pin(i)
    local pin = self.pins[i]
    if pin then return pin end
    pin = ns.NewFrame("Button", nil, self.layer)
    pin.edge = disc(pin, "BORDER", K.theme.pin.edge)
    pin.edge:SetAllPoints(pin)
    pin.fill = disc(pin, "ARTWORK", K.theme.pin.fill)
    pin.core = disc(pin, "OVERLAY", K.theme.pin.core)
    pin:SetScript("OnEnter", pinEnter)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.pins[i] = pin
    return pin
end
function ZoneMap.Tile(file, level, i)
    local floor = level and level > 0 and (level .. "_") or ""
    return "Interface\\WorldMap\\" .. file .. "\\" .. file .. floor .. i
end
function ZoneMap:Render()
    local p = self.props
    local scale = p.width / WIDTH
    self.frame:SetWidth(p.width); self.frame:SetHeight(HEIGHT * scale)
    for i, tile in ipairs(self.tiles) do
        local column, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
        local width, height = math.min(TILE, WIDTH - column * TILE), math.min(TILE, HEIGHT - row * TILE)
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", self.frame, "TOPLEFT", column * TILE * scale, -row * TILE * scale)
        tile:SetWidth(width * scale); tile:SetHeight(height * scale)
        tile:SetTexCoord(0, width / TILE, 0, height / TILE)
        if p.file then tile:SetTexture(ZoneMap.Tile(p.file, p.level, i)); tile:Show() else tile:Hide() end
    end
    local points = p.points or {}
    local size = #points > 1 and SMALL or PIN
    local ring, core = math.max(2, math.floor(size / 7)), math.floor(size / 3)
    for i, point in ipairs(points) do
        local pin = self:Pin(i)
        pin:SetWidth(size); pin:SetHeight(size)
        pin.fill:ClearAllPoints()
        pin.fill:SetPoint("TOPLEFT", pin, "TOPLEFT", ring, -ring); pin.fill:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", -ring, ring)
        pin.core:ClearAllPoints(); pin.core:SetPoint("CENTER", pin, "CENTER", 0, 0)
        pin.core:SetWidth(core); pin.core:SetHeight(core)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", self.layer, "TOPLEFT", point[1] * WIDTH * scale, -point[2] * HEIGHT * scale)
        pin.title = p.title
        pin:Show()
    end
    for i = #points + 1, #self.pins do self.pins[i]:Hide() end
    if #points == 1 then
        self.label:ClearAllPoints()
        self.label:SetPoint("TOP", self.pins[1], "BOTTOM", 0, -2)
        self.label:SetText(p.title)
        self.label:Show()
    else self.label:Hide() end
end
function ZoneMap.Fit(width, height)
    return math.floor(math.min(width, height * WIDTH / HEIGHT))
end
