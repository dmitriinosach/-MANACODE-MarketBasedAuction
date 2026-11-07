local _, ns = ...
local K = ns.TradeKit
K.WINDOW_PAD = 10
local CLOSE_MARGIN = 5
function K.AuctionChrome(parent, root)
    root:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    root:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 12)
    root:SetFrameLevel(parent:GetFrameLevel() + 6)
    root:EnableMouse(true)
    K.Panel(root)
    root.tradeBase:SetVertexColor(unpack(K.theme.background))
    local chrome = {}
    chrome.title = K.Label(root, ns.T("tradeTitle"), K.WINDOW_PAD, -11, 300, "title")
    chrome.close = ns.NewFrame("Button", nil, root, "UIPanelCloseButton")
    chrome.close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -(K.WINDOW_PAD - CLOSE_MARGIN), -1)
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
    chrome.forward:SetPoint("TOPRIGHT", root, "TOPRIGHT", -(K.WINDOW_PAD + 32 - 2 * CLOSE_MARGIN + 4), -6)
    chrome.back = arrow("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    chrome.back:SetPoint("RIGHT", chrome.forward, "LEFT", -4, 0)
    for _, y in ipairs({-33, -61}) do
        local line = K.Rule(root, y)
        line:SetPoint("TOPLEFT", root, "TOPLEFT", 6, y); line:SetPoint("TOPRIGHT", root, "TOPRIGHT", -6, y)
    end
    local foot = K.Rule(root, 0)
    foot:ClearAllPoints()
    chrome.footerRule = foot
    chrome.money = K.FontString(root, "normal")
    chrome.money:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", K.WINDOW_PAD, 10)
    chrome.money:SetJustifyH("LEFT")
    chrome.status = K.FontString(root, "small")
    chrome.status:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 190, 10)
    chrome.status:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -212, 10)
    chrome.status:SetJustifyH("LEFT")
    chrome.status:SetTextColor(unpack(K.theme.secondary))
    chrome.statusHit = ns.NewFrame("Frame", nil, root)
    chrome.statusHit:SetPoint("BOTTOMLEFT", chrome.status, "BOTTOMLEFT", 0, -2)
    chrome.statusHit:SetPoint("BOTTOMRIGHT", chrome.status, "BOTTOMRIGHT", 0, -2)
    chrome.statusHit:SetHeight(16)
    chrome.statusHit:EnableMouse(false)
    chrome.statusLink = K.SpellLink(root)
    chrome.statusLink:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 190, 8)
    chrome.actions = ns.NewFrame("Frame", nil, root)
    chrome.actions:SetHeight(22); chrome.actions:SetWidth(1)
    chrome.actions:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -30, 5)
    chrome.actionsLabel = K.Label(root, ns.T("barRefresh"), 0, 0, 120, "secondary")
    K.SetFontHeight(chrome.actionsLabel, 12); chrome.actionsLabel:SetJustifyH("RIGHT"); chrome.actionsLabel:Hide()
    chrome.stop = K.Button(root, ns.T("tradeStop"), 70, nil)
    chrome.stop:SetHeight(20)
    chrome.stop:SetPoint("RIGHT", chrome.actions, "LEFT", -8, 0)
    chrome.resume = K.Button(root, ns.T("tradeResume"), 92, nil)
    chrome.resume:SetHeight(20)
    chrome.resume:SetPoint("RIGHT", chrome.stop, "LEFT", -6, 0)
    chrome.stop:Hide(); chrome.resume:Hide()
    chrome.rescan = K.Button(root, ns.T("tradeRescan"), 92, nil)
    chrome.rescan:SetHeight(20)
    chrome.rescan:SetPoint("RIGHT", chrome.actions, "LEFT", -8, 0)
    chrome.rescanDrop = K.Button(root, ns.T("tradeRescanDrop"), 80, nil, "quiet")
    chrome.rescanDrop:SetHeight(20)
    chrome.rescanDrop:SetPoint("RIGHT", chrome.rescan, "LEFT", -6, 0)
    chrome.rescan:Hide(); chrome.rescanDrop:Hide()
    chrome.lead = ns.NewFrame("Frame", nil, root)
    chrome.lead:SetHeight(22); chrome.lead:SetWidth(1)
    chrome.lead:SetPoint("LEFT", chrome.money, "RIGHT", 17, 0)
    chrome.leadDivider = K.NavDivider(root, chrome.money)
    chrome.leadDivider:Hide()
    chrome.job = ns.NewFrame("Frame", nil, root)
    K.SetFontHeight(chrome.job, 14)
    chrome.job.line = K.FontString(chrome.job, "small")
    chrome.job.line:SetPoint("TOPLEFT", chrome.job, "TOPLEFT", 0, 0)
    chrome.job.line:SetPoint("TOPRIGHT", chrome.job, "TOPRIGHT", 0, 0)
    K.SetFontHeight(chrome.job.line, 12); chrome.job.line:SetJustifyH("LEFT")
    chrome.job.line:SetTextColor(unpack(K.theme.secondary))
    chrome.job:Hide()
    chrome.progress = K.Progress(chrome.job)
    chrome.progress.frame:SetPoint("BOTTOMLEFT", chrome.job, "BOTTOMLEFT", 0, -3)
    chrome.progress.frame:SetPoint("BOTTOMRIGHT", chrome.job, "BOTTOMRIGHT", 0, -3)
    K.PlaceFooterRule(foot, root)
    return chrome
end
function K.PlaceFooterRule(rule, root)
    local height = K.FontHeight(30)
    rule:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 6, height)
    rule:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -6, height)
end
function K.ViewControls(parent, about)
    local group = ns.NewFrame("Frame", nil, parent)
    group:SetHeight(K.theme.infoSize)
    group:EnableMouse(false)
    local window = ns.AuctionWindow
    group.about = K.InfoButton(group, ns.T("setAbout"), "")
    group.about.onClick = about
    group.less = K.Button(group, ns.T("viewFontLess"), 22, function()
        K.SetFontDelta(K.FontDelta() - 1)
    end)
    group.more = K.Button(group, ns.T("viewFontMore"), 22, function()
        K.SetFontDelta(K.FontDelta() + 1)
    end)
    group.out = K.Button(group, ns.T("viewZoomOut"), 22, function()
        local _, _, _, step = window.Scale()
        window.SetScale(window.frame:GetScale() - step)
    end)
    group.zoom = K.Button(group, ns.T("viewZoomIn"), 22, function()
        local _, _, _, step = window.Scale()
        window.SetScale(math.min(window.scaleLimit, window.frame:GetScale() + step))
    end)
    local x, size = 0, K.theme.infoSize
    for i, button in ipairs({group.about, group.less, group.more, group.out, group.zoom}) do
        if i == 2 or i == 4 then x = x + 6 end
        button:ClearAllPoints(); button:SetPoint("LEFT", group, "LEFT", x, 0)
        if button ~= group.about then
            button:SetWidth(size); button:SetHeight(size)
            button.text:ClearAllPoints()
            button.text:SetPoint("CENTER", button, "CENTER", 0, 1)
            button.tone = "gold"
            K.StyleButton(button)
        end
        x = x + size + 3
    end
    group:SetWidth(x - 3)
    group.Refresh = function(self)
        local delta, minFont, maxFont = K.FontDelta()
        local scale, minScale, maxScale = window.Scale()
        local shownScale = window.frame and window.frame:GetScale() or scale
        local fontTip = ns.T("viewFontValue", delta)
        local scaleTip = ns.T("viewZoomValue", math.floor(shownScale * 100 + 0.5))
        for _, state in ipairs({{self.less, fontTip, delta > minFont}, {self.more, fontTip, delta < maxFont},
            {self.out, scaleTip, shownScale > minScale}, {self.zoom, scaleTip, shownScale < (window.scaleLimit or maxScale)}}) do
            local button, title, enabled = unpack(state)
            if enabled ~= (button:IsEnabled() and true or false) then
                if enabled then button:Enable() else button:Disable() end
            end
            K.Tooltip(button, title, "")
            K.RefreshTip(button)
        end
    end
    group:Refresh()
    return group
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
local SectionHead = {}
SectionHead.__index = SectionHead
K.SectionHead = SectionHead
SectionHead.HEIGHT = 26
SectionHead.GAP = 8
function SectionHead:New(parent)
    local head = setmetatable({props = {filters = {}, actions = {}, extra = {}}, folded = {}}, self)
    head.frame = ns.NewFrame("Frame", nil, parent)
    head.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    head.frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    K.SetFontHeight(head.frame, SectionHead.HEIGHT)
    head.more = K.Button(head.frame, ns.T("headFilters", 0), 90, function()
        if head.drop:IsShown() then head.drop:Hide() else head.drop:Show() end
    end)
    K.Tooltip(head.more, ns.T("headFiltersTitle"), ns.T("headFiltersTip"))
    head.more:Hide()
    head.drop = ns.NewFrame("Frame", nil, head.frame)
    K.Panel(head.drop)
    head.drop:EnableMouse(true)
    head.drop:SetFrameLevel(parent:GetFrameLevel() + 40)
    head.drop:Hide()
    head.frame:HookScript("OnHide", function() head.drop:Hide() end)
    parent:HookScript("OnSizeChanged", function() head:Render() end)
    return head
end
function SectionHead:SetProps(props)
    local p = {lead = props.lead, filters = props.filters or {}, actions = props.actions or {}, extra = props.extra or {}}
    local old, keep = self.props, {}
    for _, list in ipairs({p.filters, p.extra}) do
        for _, filter in ipairs(list) do
            keep[filter] = true
            if rawget(filter, "headHome") == nil then filter.headHome = filter:GetParent() or false end
        end
    end
    local changed = old.lead ~= p.lead
    for _, list in ipairs({old.filters, old.extra}) do
        for _, filter in ipairs(list) do
            if not keep[filter] then
                if filter.headHome then filter:SetParent(filter.headHome) end
                changed = true
            end
        end
    end
    self.props = p
    if changed then self.drop:Hide() end
    self:Render()
end
function SectionHead:Render()
    local p, gap = self.props, SectionHead.GAP
    local width = self.frame:GetWidth() or 0
    local edge = 6
    for i = #p.actions, 1, -1 do
        local b = p.actions[i]
        if b:IsShown() then
            b:ClearAllPoints(); b:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -edge, -2)
            edge = edge + (b:GetWidth() or 80) + 4
        end
    end
    local x = 8
    if p.lead and p.lead:IsShown() then
        p.lead:ClearAllPoints(); p.lead:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 8, -2)
        x = 8 + (p.lead:GetWidth() or 0) + 2 * gap
    end
    local limit = width - edge - gap + 4
    local levels = 1
    local function steps(filter) local n = rawget(filter, "levels"); return type(n) == "number" and n or 1 end
    for _, filter in ipairs(p.filters) do levels = math.max(levels, steps(filter)) end
    local function measure(level)
        local total = x
        for i, filter in ipairs(p.filters) do
            if filter.Fit then filter:Fit(math.min(level, steps(filter))) end
            total = total + (i > 1 and gap or 0) + (filter:GetWidth() or 0)
        end
        return total
    end
    local level = 1
    local total = measure(level)
    while total > limit and level < levels do
        level = level + 1
        total = measure(level)
    end
    local overflow = total > limit or #p.extra > 0
    if overflow then
        self.more:SetText(ns.T("headFilters", #p.filters + #p.extra)); K.FitButton(self.more, 24)
        limit = limit - (self.more:GetWidth() or 90) - gap
    end
    self.folded = {}
    local fold = false
    for _, filter in ipairs(p.filters) do
        local w = filter:GetWidth() or 0
        if overflow and x + w > limit then fold = true end
        filter:ClearAllPoints()
        if fold then self.folded[#self.folded + 1] = filter
        else
            if filter.headHome then filter:SetParent(filter.headHome) end
            filter:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, -2)
            filter:Show()
            x = x + w + gap
        end
    end
    for _, filter in ipairs(p.extra) do self.folded[#self.folded + 1] = filter end
    self:Fold(x)
end
function SectionHead:Fold(x)
    if #self.folded == 0 then self.more:Hide(); self.drop:Hide(); return end
    self.more:SetText(ns.T("headFilters", #self.folded)); K.FitButton(self.more, 24)
    self.more:ClearAllPoints(); self.more:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, -2)
    self.more:Show()
    local y, wide = 8, 0
    for _, filter in ipairs(self.folded) do
        filter:SetParent(self.drop)
        filter:ClearAllPoints()
        filter:SetPoint("TOPLEFT", self.drop, "TOPLEFT", 8, -y)
        filter:Show()
        y = y + (filter:GetHeight() or 22) + 4
        wide = math.max(wide, filter:GetWidth() or 0)
    end
    local width = wide + 16
    self.drop:SetWidth(width); self.drop:SetHeight(y + 4)
    self.drop:ClearAllPoints()
    self.drop:SetPoint("TOPLEFT", self.frame, "TOPLEFT", math.max(0, math.min(x, (self.frame:GetWidth() or width) - width)), -K.FontHeight(SectionHead.HEIGHT))
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
    outline.size = K.FontString(outline, "large")
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
function K.ThemeButton(root)
    local b = K.Button(root, "", 22, nil, "control")
    b.swatches = {}
    for i = 1, 4 do
        local swatch = b:CreateTexture(nil, "ARTWORK")
        swatch:SetTexture(K.theme.white); swatch:SetWidth(6); swatch:SetHeight(6)
        swatch:SetPoint("CENTER", b, "CENTER", i % 2 == 1 and -4 or 4, i <= 2 and 4 or -4)
        b.swatches[i] = swatch
    end
    local menu = K.Menu(root, {}, function(key)
        if key == "palette" then K.Palette.Toggle() else K.Palette.SetTheme(key) end
    end)
    b.menu = menu
    menu.frame:Hide()
    menu.frame:ClearAllPoints(); menu.frame:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0); menu.frame:SetWidth(210)
    menu.anchor = b
    local function entries()
        local list = {}
        for _, preset in ipairs(K.THEMES) do
            list[#list + 1] = {key = preset.key, label = ns.T("setTheme_" .. preset.key),
                note = preset.key == K.theme.key and ns.T("themeCurrent") or nil, tip = ns.T("setThemeTip_" .. preset.key)}
        end
        list[#list + 1] = {divider = true}
        list[#list + 1] = {key = "palette", label = ns.T("setPalette"), tip = ns.T("setPaletteTip")}
        return list
    end
    menu.cover:HookScript("OnShow", function() menu:SetEntries(entries()) end)
    b.onClick = function()
        if menu.cover:IsShown() then menu.cover:Hide() else menu.cover:Show() end
    end
    b.Refresh = function(self)
        local colors = {K.theme.gold, K.theme.positive, K.theme.quality[3], K.theme.quality[4]}
        for i, swatch in ipairs(self.swatches) do swatch:SetVertexColor(colors[i][1], colors[i][2], colors[i][3]) end
        self:SetActive(self.menu.cover:IsShown())
    end
    menu.cover:HookScript("OnShow", function() b:Refresh() end)
    menu.cover:HookScript("OnHide", function() b:Refresh() end)
    hooksecurefunc(K.Palette, "Render", function() b:Refresh() end)
    K.Tooltip(b, ns.T("setTheme"), ns.T("themeButtonTip"))
    b:Refresh()
    return b
end
local Banner = {}
Banner.__index = Banner
K.Banner = Banner
Banner.HEIGHT = 46
local ART = 0.7109375
function Banner:New(parent)
    local banner = setmetatable({}, self)
    local f = K.Card(parent)
    f:SetHeight(Banner.HEIGHT)
    banner.frame = f
    banner.back = K.Picture(f, nil, "BORDER")
    banner.back:ClearAllPoints()
    banner.back:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1); banner.back:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    banner.art = K.Picture(f, nil, "ARTWORK")
    banner.art:ClearAllPoints()
    banner.art:SetPoint("LEFT", f, "LEFT", 1, 0)
    banner.art:SetWidth(Banner.HEIGHT - 2); banner.art:SetHeight(Banner.HEIGHT - 2)
    banner.title = K.Label(f, "", 0, -6, 200, "heading")
    banner.title:SetHeight(14)
    banner.status = K.Label(f, "", 0, -26, 200)
    banner.status:SetHeight(12)
    f:Hide()
    return banner
end
function Banner:SetProps(props)
    local f = self.frame
    if not props then f:Hide(); return end
    f:SetWidth(props.width)
    local left = 10
    if props.art then
        self.art:SetTexture(props.art); self.art:SetTexCoord(0, ART, 0, ART); self.art:Show()
        local band = ART * (Banner.HEIGHT - 2) / math.max(1, props.width - 2)
        self.back:SetTexture(props.art)
        self.back:SetTexCoord(0, ART, (ART - band) / 2, (ART + band) / 2)
        ns.Gradient(self.back, "HORIZONTAL", 1, 1, 1, 0.35, 1, 1, 1, 0)
        self.back:Show()
        left = Banner.HEIGHT + 8
    else self.art:Hide(); self.back:Hide() end
    local room = math.max(20, props.width - left - 8)
    for _, label in ipairs({self.title, self.status}) do
        label:ClearAllPoints(); label:SetWidth(room)
    end
    self.title:SetPoint("TOPLEFT", f, "TOPLEFT", left, -7)
    self.status:SetPoint("TOPLEFT", f, "TOPLEFT", left, -27)
    self.title:SetText(props.title or "")
    self.status:SetText(props.status or "")
    self.status:SetTextColor(unpack(K.theme[props.tone or "secondary"]))
    f:Show()
end
