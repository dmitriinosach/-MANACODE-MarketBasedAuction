local _, ns = ...
local K = ns.TradeKit
local Tour = {WIDTH = 340, PAD = 12, RING = 4, GAP = 10, ROWS = 8, ROW = 22, MARGIN = 8,
    steps = {}, index = 1, lit = {}, running = false, dirty = 0, phase = 0}
K.Tour = Tour
local function shade(parent)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(K.theme.white); t:SetVertexColor(unpack(K.theme.shade))
    return t
end
local function height(fs, fallback)
    local h = fs:GetStringHeight()
    if not h or h < 1 then return fallback end
    return math.ceil(h)
end
local function clamp(value, low, high)
    if high < low then return low end
    return math.max(low, math.min(high, value))
end
local function newRow(card)
    local row = {chip = K.Keycap(card), icon = K.Button(card, "", 22, nil, "quiet"),
        text = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")}
    row.icon:SetHeight(20); row.icon:EnableMouse(false)
    row.text:SetJustifyH("LEFT"); row.text:SetTextColor(unpack(K.theme.text))
    row.chip:Hide(); row.icon:Hide(); row.text:Hide()
    return row
end
function Tour.Build(host)
    if Tour.frame then return Tour.frame end
    local f = ns.NewFrame("Frame", nil, host)
    f:SetAllPoints(host)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f.dim = shade(f); f.dim:SetAllPoints(f)
    f.bands = {}
    for i = 1, 4 do f.bands[i] = shade(f) end
    f.ring = ns.NewFrame("Frame", nil, f)
    f.ring:SetBackdrop({edgeFile = K.theme.buttonSkin.edgeFile, edgeSize = 12})
    f.ring:SetBackdropBorderColor(unpack(K.theme.accent))
    f.ring:Hide()
    local card = ns.NewFrame("Frame", nil, f)
    card:SetFrameLevel(f:GetFrameLevel() + 10)
    card:EnableMouse(true)
    card:SetWidth(Tour.WIDTH)
    K.TipPanel(card)
    card.counter = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.counter:SetPoint("TOPRIGHT", card, "TOPRIGHT", -Tour.PAD, -Tour.PAD)
    card.counter:SetTextColor(unpack(K.theme.secondary))
    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.title:SetJustifyH("LEFT"); card.title:SetTextColor(unpack(K.theme.accent))
    card.body = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.body:SetJustifyH("LEFT"); card.body:SetJustifyV("TOP"); card.body:SetTextColor(unpack(K.theme.text))
    card.rows = {}
    for i = 1, Tour.ROWS do card.rows[i] = newRow(card) end
    card.skip = K.Button(card, ns.T("tourSkip"), 90, function() Tour.Stop() end, "quiet")
    card.skip:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", Tour.PAD, Tour.PAD)
    card.next = K.Button(card, ns.T("tourNext"), 90, function() Tour.Next() end, "main")
    card.next:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -Tour.PAD, Tour.PAD)
    card.back = K.Button(card, ns.T("tourBack"), 70, function() Tour.Back() end)
    card.back:SetHeight(26)
    card.back:SetPoint("RIGHT", card.next, "LEFT", -6, 0)
    K.FitButton(card.skip); K.FitButton(card.back)
    f:SetScript("OnHide", function() Tour.Finish() end)
    f:SetScript("OnSizeChanged", function() Tour.Layout() end)
    f:SetScript("OnUpdate", function(_, elapsed) Tour.Tick(elapsed) end)
    K.Overlay(f)
    f:Hide()
    Tour.frame, Tour.card = f, card
    return f
end
function Tour.Start(host, steps, onFinish)
    if #steps == 0 then return false end
    if Tour.running then Tour.Stop() end
    Tour.Build(host)
    Tour.steps, Tour.index, Tour.onFinish, Tour.running = steps, 1, onFinish, true
    Tour.frame:Show()
    Tour.Render()
    return true
end
function Tour.Active()
    return Tour.running and Tour.frame ~= nil and Tour.frame:IsVisible() and true or false
end
function Tour.Next()
    if not Tour.running then return end
    if Tour.index >= #Tour.steps then Tour.Stop(); return end
    Tour.index = Tour.index + 1
    Tour.Render()
end
function Tour.Back()
    if not Tour.running or Tour.index <= 1 then return end
    Tour.index = Tour.index - 1
    Tour.Render()
end
function Tour.Stop()
    if Tour.frame then Tour.frame:Hide() end
    Tour.Finish()
end
function Tour.Finish()
    if not Tour.running then return end
    Tour.running = false
    Tour.lit = {}
    Tour.Leave(nil)
    if Tour.frame and Tour.frame:IsShown() then Tour.frame:Hide() end
    local done = Tour.onFinish
    Tour.onFinish = nil
    if done then done(Tour.index) end
end
function Tour.Leave(step)
    local shown = Tour.shown
    if not shown or shown == step then return end
    Tour.shown = nil
    if shown.leave then shown.leave() end
end
function Tour.Raise()
    if Tour.running and Tour.frame and Tour.frame:IsShown() then Tour.frame:Show() end
end
function Tour.Targets(step)
    local found = {}
    for _, frame in ipairs(step.target and step.target() or {}) do
        if frame:IsVisible() then found[#found + 1] = frame end
    end
    return found
end
local function placeRows(card, rows, y)
    local pad, inner = Tour.PAD, Tour.WIDTH - Tour.PAD * 2
    local column = 0
    for i, slot in ipairs(card.rows) do
        local row = rows[i]
        if row and row.icon then column = math.max(column, 22)
        elseif row then
            slot.chip.label:SetText(ns.T(row.labelKey))
            column = math.max(column, math.ceil((slot.chip.label:GetStringWidth() or 30) + 16), 44)
        end
    end
    if #rows > 0 then y = y - 10 end
    for i, slot in ipairs(card.rows) do
        local row = rows[i]
        slot.chip:Hide(); slot.icon:Hide(); slot.text:Hide()
        if row then
            if row.icon then
                K.SetGlyph(slot.icon, row.icon)
                slot.icon:ClearAllPoints(); slot.icon:SetPoint("TOPLEFT", card, "TOPLEFT", pad, y)
                slot.icon:Show()
            else
                slot.chip:ClearAllPoints(); slot.chip:SetPoint("TOPLEFT", card, "TOPLEFT", pad, y - 1)
                slot.chip:SetWidth(column); slot.chip:Show()
            end
            local x = pad + column + 8
            slot.text:ClearAllPoints(); slot.text:SetPoint("TOPLEFT", card, "TOPLEFT", x, y - 4)
            slot.text:SetWidth(inner - column - 8)
            slot.text:SetText(ns.T(row.textKey)); slot.text:Show()
            y = y - math.max(Tour.ROW, height(slot.text, 12) + 8)
        end
    end
    return y
end
function Tour.Render()
    local card = Tour.card
    if not card or not Tour.running then return end
    local n = #Tour.steps
    Tour.index = clamp(Tour.index, 1, n)
    local step = Tour.steps[Tour.index]
    Tour.Leave(step)
    if step.action and Tour.shown ~= step then step.action() end
    Tour.shown = step
    local pad, inner = Tour.PAD, Tour.WIDTH - Tour.PAD * 2
    card.counter:SetText(string.format("%d / %d", Tour.index, n))
    card.title:ClearAllPoints(); card.title:SetPoint("TOPLEFT", card, "TOPLEFT", pad, -pad)
    card.title:SetWidth(inner - 50); card.title:SetText(ns.T(step.titleKey))
    local y = -pad - height(card.title, 14) - 6
    card.body:ClearAllPoints(); card.body:SetPoint("TOPLEFT", card, "TOPLEFT", pad, y)
    card.body:SetWidth(inner); card.body:SetText(ns.T(step.textKey))
    y = y - height(card.body, 42)
    y = placeRows(card, step.rows or {}, y)
    local last = Tour.index >= n
    card.next:SetText(ns.T(last and "tourDone" or "tourNext")); K.FitButton(card.next, 28)
    if Tour.index > 1 then card.back:Show() else card.back:Hide() end
    if last then card.skip:Hide() else card.skip:Show() end
    card:SetWidth(Tour.WIDTH); card:SetHeight(-y + 14 + 26 + pad)
    Tour.lit = Tour.Targets(step)
    Tour.dirty = 3
    Tour.Layout()
end
function Tour.Bounds(frames)
    local f = Tour.frame
    local ox, oy = f:GetLeft(), f:GetTop()
    if not ox or not oy then return nil end
    local own = f:GetEffectiveScale() or 1
    local l, t, r, b
    for _, frame in ipairs(frames) do
        local fl, ft, fr, fb = frame:GetLeft(), frame:GetTop(), frame:GetRight(), frame:GetBottom()
        if fl and ft and fr and fb then
            local holder = frame.GetEffectiveScale and frame or frame:GetParent()
            local k = (holder and holder.GetEffectiveScale and holder:GetEffectiveScale() or own) / own
            l, r = math.min(l or fl * k, fl * k), math.max(r or fr * k, fr * k)
            t, b = math.max(t or ft * k, ft * k), math.min(b or fb * k, fb * k)
        end
    end
    if not l then return nil end
    local ring = Tour.RING
    return l - ox - ring, oy - t - ring, r - ox + ring, oy - b + ring
end
local function band(f, tx, x, y, w, h)
    tx:ClearAllPoints()
    tx:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
    tx:SetWidth(math.max(w, 0.01)); tx:SetHeight(math.max(h, 0.01))
    tx:Show()
end
function Tour.Layout()
    local f, card = Tour.frame, Tour.card
    if not f or not Tour.running then return end
    local ow, oh = f:GetWidth() or 0, f:GetHeight() or 0
    local l, t, r, b
    if #Tour.lit > 0 and ow > 0 and oh > 0 then l, t, r, b = Tour.Bounds(Tour.lit) end
    card:ClearAllPoints()
    if not l then
        for _, tx in ipairs(f.bands) do tx:Hide() end
        f.ring:Hide(); f.dim:Show()
        card:SetPoint("CENTER", f, "CENTER", 0, 0)
        return
    end
    l, r = clamp(l, 0, ow), clamp(r, 0, ow)
    t, b = clamp(t, 0, oh), clamp(b, 0, oh)
    f.dim:Hide()
    band(f, f.bands[1], 0, 0, ow, t)
    band(f, f.bands[2], 0, b, ow, oh - b)
    band(f, f.bands[3], 0, t, l, b - t)
    band(f, f.bands[4], r, t, ow - r, b - t)
    f.ring:ClearAllPoints()
    f.ring:SetPoint("TOPLEFT", f, "TOPLEFT", l, -t)
    f.ring:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", r, -b)
    f.ring:Show()
    local w, h, gap, margin = Tour.WIDTH, card:GetHeight() or 160, Tour.GAP, Tour.MARGIN
    local x = clamp((l + r) / 2 - w / 2, margin, ow - w - margin)
    local y
    if (t + b) / 2 < oh / 2 then
        y = b + gap
        if y + h > oh - margin then y = t - gap - h end
    else
        y = t - gap - h
        if y < margin then y = b + gap end
    end
    card:SetPoint("TOPLEFT", f, "TOPLEFT", x, -clamp(y, margin, oh - h - margin))
end
function Tour.Tick(elapsed)
    if not Tour.running or not Tour.frame then return end
    Tour.phase = (Tour.phase + elapsed) % 1.6
    Tour.frame.ring:SetAlpha(0.6 + 0.4 * math.abs(math.sin(Tour.phase / 1.6 * math.pi)))
    if Tour.dirty > 0 then
        Tour.dirty = Tour.dirty - 1
        Tour.Layout()
    end
end
