local _, ns = ...
local K = ns.TradeKit
local QUARTERS = {
    ROUND = {true, true, true, true}, SQUARE = {false, false, false, false},
    ["CORNER-TOPRIGHT"] = {true, false, false, false}, ["CORNER-TOPLEFT"] = {false, true, false, false},
    ["CORNER-BOTTOMLEFT"] = {false, false, true, false}, ["CORNER-BOTTOMRIGHT"] = {false, false, false, true},
    ["SIDE-LEFT"] = {false, true, true, false}, ["SIDE-RIGHT"] = {true, false, false, true},
    ["SIDE-TOP"] = {true, true, false, false}, ["SIDE-BOTTOM"] = {false, false, true, true},
    ["TRICORNER-TOPRIGHT"] = {true, false, true, true}, ["TRICORNER-TOPLEFT"] = {false, true, true, true},
    ["TRICORNER-BOTTOMRIGHT"] = {true, true, false, true}, ["TRICORNER-BOTTOMLEFT"] = {true, true, true, false},
}
function K.MinimapButton(name, onClick, angle, tip)
    if not Minimap then return nil end
    local art = K.theme.minimap
    local mm = {angle = angle}
    local b = ns.NewFrame("Button", name, Minimap)
    mm.frame = b
    b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
    b:SetWidth(31); b:SetHeight(31)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture(art.lit)
    local ring = b:CreateTexture(nil, "OVERLAY")
    ring:SetWidth(53); ring:SetHeight(53)
    ring:SetTexture(art.ring)
    ring:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20); icon:SetHeight(20)
    icon:SetTexture(art.icon[1]); icon:SetTexCoord(art.icon[2], art.icon[3], art.icon[4], art.icon[5])
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -5)
    mm.Place = function(self)
        local radians = math.rad(self.angle())
        local cos, sin = math.cos(radians), math.sin(radians)
        local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
        local quarter = cos >= 0 and (sin >= 0 and 1 or 4) or (sin >= 0 and 2 or 3)
        local x, y
        if (QUARTERS[shape] or QUARTERS.ROUND)[quarter] then x, y = cos * 80, sin * 80
        else x, y = math.max(-82, math.min(110 * cos, 84)), math.max(-86, math.min(110 * sin, 82)) end
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    mm.Reveal = function(self, on)
        if on then self.frame:Show() else self.frame:Hide() end
    end
    local function follow()
        local cx, cy = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        mm.angle(math.deg(math.atan2(py / scale - cy, px / scale - cx)) % 360)
        mm:Place()
    end
    b:SetScript("OnClick", function(_, button) onClick(button) end)
    b:SetScript("OnDragStart", function(self)
        self.dragging = true
        GameTooltip:Hide()
        self:SetScript("OnUpdate", follow)
    end)
    b:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
    end)
    b:SetScript("OnEnter", function(self)
        if self.dragging then return end
        local lines = tip()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(lines[1], unpack(K.theme.text))
        for i = 2, #lines do GameTooltip:AddLine(lines[i], K.theme.gold[1], K.theme.gold[2], K.theme.gold[3], true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    mm:Place()
    return mm
end
function K.OptionsPage(title, note, label, open)
    if not UIParent then return nil end
    local page = ns.NewFrame("Frame", nil, UIParent)
    page.name = title
    page:Hide()
    local heading = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -16)
    heading:SetText(title)
    local body = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    body:SetWidth(520); body:SetJustifyH("LEFT")
    body:SetText(note)
    page.open = ns.NewFrame("Button", nil, page, "UIPanelButtonTemplate")
    page.open:SetWidth(220); page.open:SetHeight(24)
    page.open:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -16)
    page.open:SetText(label)
    page.open:SetScript("OnClick", function()
        for _, frame in ipairs({InterfaceOptionsFrame, GameMenuFrame}) do
            if frame and frame:IsShown() then HideUIPanel(frame) end
        end
        open()
    end)
    if not ns.Compat.AddOptions(page) then return nil end
    return page
end
