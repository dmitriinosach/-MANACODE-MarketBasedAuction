local _, ns = ...
local K = ns.TradeKit
function K.AuctionChrome(parent, root)
    root:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    root:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 12)
    root:SetFrameLevel(parent:GetFrameLevel() + 6)
    root:EnableMouse(true)
    K.Panel(root)
    root.tradeBase:SetVertexColor(unpack(K.theme.background))
    local chrome = {}
    chrome.title = K.Label(root, ns.T("tradeTitle"), 14, -11, 300, "title")
    chrome.close = ns.NewFrame("Button", nil, root, "UIPanelCloseButton")
    chrome.close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -2, -2)
    chrome.close:SetScript("OnClick", function() HideUIPanel(parent) end)
    local function arrow(texture)
        local b = K.Button(root, "", 24, nil)
        b.glyph = b:CreateTexture(nil, "ARTWORK")
        b.glyph:SetWidth(16); b.glyph:SetHeight(16)
        b.glyph:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.glyph:SetTexture(texture); b.glyph:SetTexCoord(0.2, 0.8, 0.2, 0.8)
        K.StyleButton(b)
        return b
    end
    chrome.forward = arrow("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    chrome.forward:SetPoint("TOPRIGHT", root, "TOPRIGHT", -34, -7)
    chrome.back = arrow("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    chrome.back:SetPoint("RIGHT", chrome.forward, "LEFT", -4, 0)
    for _, y in ipairs({-33, -61}) do
        local line = K.Rule(root, y)
        line:SetPoint("TOPLEFT", root, "TOPLEFT", 6, y); line:SetPoint("TOPRIGHT", root, "TOPRIGHT", -6, y)
    end
    local foot = K.Rule(root, 0)
    foot:ClearAllPoints()
    foot:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 6, 30); foot:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -6, 30)
    chrome.money = root:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    chrome.money:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 14, 10)
    chrome.money:SetJustifyH("LEFT")
    chrome.status = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chrome.status:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 190, 10)
    chrome.status:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -212, 10)
    chrome.status:SetJustifyH("LEFT")
    chrome.status:SetTextColor(unpack(K.theme.secondary))
    chrome.stop = K.Button(root, ns.T("tradeStop"), 70, nil)
    chrome.stop:SetHeight(20)
    chrome.stop:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -34, 6)
    chrome.resume = K.Button(root, ns.T("tradeResume"), 92, nil)
    chrome.resume:SetHeight(20)
    chrome.resume:SetPoint("RIGHT", chrome.stop, "LEFT", -6, 0)
    chrome.stop:Hide(); chrome.resume:Hide()
    chrome.rescan = K.Button(root, ns.T("tradeRescan"), 92, nil)
    chrome.rescan:SetHeight(20)
    chrome.rescan:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -34, 6)
    chrome.rescanDrop = K.Button(root, ns.T("tradeRescanDrop"), 80, nil, "quiet")
    chrome.rescanDrop:SetHeight(20)
    chrome.rescanDrop:SetPoint("RIGHT", chrome.rescan, "LEFT", -6, 0)
    chrome.rescan:Hide(); chrome.rescanDrop:Hide()
    chrome.scan = K.Button(root, ns.T("tradeScan"), 92, nil)
    chrome.scan:SetHeight(20)
    chrome.scan:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -34, 6)
    chrome.scan:Hide()
    chrome.progress = K.Progress(root)
    chrome.progress.frame:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 190, 5)
    chrome.progress.frame:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -212, 5)
    return chrome
end
function K.Progress(parent)
    local bar = {shown = 0, active = false, visible = false, phase = 0}
    bar.frame = ns.NewFrame("Frame", nil, parent)
    bar.frame:SetHeight(3)
    local track = bar.frame:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(K.theme.white); track:SetVertexColor(unpack(K.theme.field)); track:SetAllPoints(bar.frame)
    bar.fill = bar.frame:CreateTexture(nil, "ARTWORK")
    bar.fill:SetTexture(K.theme.white)
    bar.fill:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", 0, 0); bar.fill:SetPoint("BOTTOMLEFT", bar.frame, "BOTTOMLEFT", 0, 0)
    local glintFrame = ns.NewFrame("Frame", nil, bar.frame)
    glintFrame:SetAllPoints(bar.frame)
    bar.glint = glintFrame:CreateTexture(nil, "OVERLAY")
    bar.glint:SetTexture(K.theme.white)
    bar.glint:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", 0, 0); bar.glint:SetPoint("BOTTOMLEFT", bar.frame, "BOTTOMLEFT", 0, 0)
    bar.frame:Hide()
    bar.Set = function(self, share, active, visible)
        if visible and not self.visible then self.shown, self.phase = 0, 0 end
        if share and share < self.shown then self.shown = share end
        self.share, self.active, self.visible = share, active and true or false, visible and true or false
        if self.visible then self.frame:Show() else self.frame:Hide() end
    end
    bar.Tick = function(self, elapsed)
        if not self.visible then return end
        local width = self.frame:GetWidth() or 0
        if width <= 0 then return end
        if self.active then self.phase = (self.phase + elapsed / 1.4) % 1 end
        local span, segment
        if self.share then
            self.shown = self.shown + (self.share - self.shown) * math.min(1, elapsed * 6)
            span, segment = math.max(1, width * math.min(1, self.shown)), 48
            self.fill:SetWidth(span); self.fill:Show()
            self.fill:SetVertexColor(unpack(self.active and K.theme.accent or K.theme.off))
            ns.Gradient(self.glint, "HORIZONTAL", 1, 1, 1, 0, 1, 0.95, 0.80, 0.75)
        else
            span, segment = width, math.max(24, width * 0.25)
            self.fill:Hide()
            local a = K.theme.accent
            ns.Gradient(self.glint, "HORIZONTAL", a[1], a[2], a[3], 0, a[1], a[2], a[3], self.active and 1 or 0.4)
        end
        local head = self.phase * (span + segment)
        local left, right = math.max(0, head - segment), math.min(span, head)
        if (self.share and not self.active) or right - left < 1 then self.glint:Hide(); return end
        self.glint:ClearAllPoints()
        self.glint:SetPoint("TOPLEFT", self.frame, "TOPLEFT", left, 0)
        self.glint:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", left, 0)
        self.glint:SetWidth(right - left); self.glint:Show()
    end
    return bar
end
function K.NavDivider(parent, after, before)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetTexture(K.theme.white); divider:SetVertexColor(unpack(K.theme.edge))
    divider:SetWidth(1); divider:SetHeight(16)
    if before then divider:SetPoint("RIGHT", after, "LEFT", -8, 0)
    else divider:SetPoint("LEFT", after, "RIGHT", 8, 0) end
    return divider
end
local function cursor(parent)
    local x, y = GetCursorPosition()
    local scale = parent:GetEffectiveScale() or 1
    return x / scale, y / scale
end
local function clamp(value, low, high)
    return math.max(low, math.min(high, math.floor(value + 0.5)))
end
function K.ResizeGrip(parent, limits, allowed, apply, reset)
    local outline = ns.NewFrame("Frame", nil, parent)
    outline:SetFrameStrata("DIALOG")
    outline:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    outline:SetBackdrop({bgFile = K.theme.white, edgeFile = K.theme.white, edgeSize = 2})
    outline:SetBackdropColor(K.theme.gold[1], K.theme.gold[2], K.theme.gold[3], 0.08)
    outline:SetBackdropBorderColor(K.theme.gold[1], K.theme.gold[2], K.theme.gold[3], 0.9)
    outline.size = outline:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    outline.size:SetPoint("BOTTOMRIGHT", outline, "BOTTOMRIGHT", -28, 14)
    outline:Hide()
    local function measure()
        local x, y = cursor(parent)
        return clamp(outline.width0 + x - outline.x0, limits[1], limits[3]),
            clamp(outline.height0 + outline.y0 - y, limits[2], limits[4])
    end
    local function follow(self)
        local width, height = measure()
        if width == self.width and height == self.height then return end
        self.width, self.height = width, height
        self:SetWidth(width); self:SetHeight(height)
        self.size:SetFormattedText("%d x %d", width, height)
    end
    local function stop()
        outline.active = false
        outline:SetScript("OnUpdate", nil)
        outline:Hide()
    end
    local grip = ns.NewFrame("Button", nil, parent)
    grip:SetWidth(22); grip:SetHeight(22)
    grip:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -3, 15)
    grip:SetFrameStrata("FULLSCREEN")
    grip:RegisterForClicks("RightButtonUp")
    grip:SetScript("OnClick", function(_, button)
        if button == "RightButton" and reset and allowed() then reset() end
    end)
    grip.art = grip:CreateTexture(nil, "ARTWORK")
    grip.art:SetAllPoints(grip); grip.art:SetTexture(K.theme.grip.art)
    grip.art:SetVertexColor(unpack(K.theme.grip.color))
    local glow = grip:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints(grip); glow:SetTexture(K.theme.grip.art); glow:SetBlendMode("ADD")
    glow:SetVertexColor(unpack(K.theme.grip.lit)); glow:SetAlpha(0.35)
    local screen = UIParent or parent
    local badge = ns.NewFrame("Frame", nil, screen)
    badge:SetFrameStrata("TOOLTIP"); badge:SetWidth(24); badge:SetHeight(24); badge:Hide()
    local arrow = badge:CreateTexture(nil, "OVERLAY")
    arrow:SetAllPoints(badge); arrow:SetTexture(K.theme.grip.cursor); arrow:SetTexCoord(0, 0.78125, 0, 0.78125)
    badge:SetScript("OnUpdate", function(self)
        if not GetCursorPosition or not SetCursor then return end
        local scale = screen:GetEffectiveScale()
        local x, y = GetCursorPosition()
        self:ClearAllPoints(); self:SetPoint("CENTER", screen, "BOTTOMLEFT", x / scale, y / scale)
        SetCursor(K.theme.grip.blank)
    end)
    badge:SetScript("OnHide", function() if ResetCursor then ResetCursor() end end)
    grip.badge = badge
    grip:HookScript("OnEnter", function(self) badge:Show(); self.art:SetVertexColor(unpack(K.theme.grip.lit)) end)
    grip:HookScript("OnLeave", function(self)
        if outline.active then return end
        badge:Hide(); self.art:SetVertexColor(unpack(K.theme.grip.color))
    end)
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not allowed() then return end
        grip.art:SetVertexColor(unpack(K.theme.grip.press))
        outline.x0, outline.y0 = cursor(parent)
        outline.width0, outline.height0 = parent:GetWidth(), parent:GetHeight()
        outline.width, outline.height = nil, nil
        outline.active = true
        follow(outline)
        outline:SetScript("OnUpdate", follow)
        outline:Show()
        GameTooltip:Hide()
    end)
    grip:SetScript("OnMouseUp", function(self)
        local over = self:IsMouseOver()
        self.art:SetVertexColor(unpack(over and K.theme.grip.lit or K.theme.grip.color))
        if not over then badge:Hide() end
        if not outline.active then return end
        local width, height = measure()
        stop()
        apply(width, height)
    end)
    grip:SetScript("OnHide", function() stop(); badge:Hide() end)
    K.Tooltip(grip, ns.T("windowResize"), ns.T("windowResizeTip"))
    grip.outline = outline
    return grip
end
function K.AuctionArt(parent)
    local fills = {}
    for i = 1, 3 do fills[i] = parent:CreateTexture(nil, "ARTWORK") end
    return fills
end
function K.LayoutAuctionArt(parent, width, height, fills)
    local delta = height - 447
    if AuctionFrameTop then AuctionFrameTop:SetWidth(width - 512) end
    for i, suffix in ipairs({"Left", "", "Right"}) do
        local source = _G["AuctionFrameBot" .. suffix]
        local left = i == 1 and 0 or (i == 2 and 256 or width - 256)
        local size = i == 2 and width - 512 or 256
        if source then
            source:ClearAllPoints(); source:SetPoint("TOPLEFT", parent, "TOPLEFT", left, -256 - delta)
            source:SetWidth(size); source:SetHeight(256)
        end
        local fill = fills[i]
        if delta > 0 and source and source:GetTexture() then
            fill:SetTexture(source:GetTexture()); fill:SetTexCoord(0, 1, 0, 0.25)
            fill:ClearAllPoints(); fill:SetPoint("TOPLEFT", parent, "TOPLEFT", left, -256)
            fill:SetWidth(size); fill:SetHeight(delta); fill:Show()
        else fill:Hide() end
    end
end
