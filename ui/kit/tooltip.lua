local _, ns = ...
local K = ns.TradeKit
K.SCAN_MODES = {"soft", "hard", "missing"}
K.SCAN_STALE = 3600
local KEY_LABELS = {"scanKeyClick", "Shift", "Ctrl"}
local MODE_TEXT = {soft = "scanKeySoft", hard = "scanKeyHard", missing = "scanKeyMissing"}
function K.ScanMode(modes)
    modes = modes or K.SCAN_MODES
    if IsShiftKeyDown() and modes[2] then return modes[2] end
    if IsControlKeyDown and IsControlKeyDown() and modes[3] then return modes[3] end
    return modes[1]
end
function K.ScanFresh()
    local ttl = ns.Markets and ns.Markets.ttl
    if not ttl then return nil end
    return ns.T("scanFresh", math.floor(ttl.material / 60 + 0.5), math.floor(ttl.gem / 60 + 0.5),
        math.floor(ttl.product / 3600 + 0.5), math.floor(ttl.resale / 3600 + 0.5))
end
function K.ScanKeys(preview, modes)
    local rows = {}
    for i, mode in ipairs(modes or K.SCAN_MODES) do
        rows[i] = {key = i == 1 and ns.T(KEY_LABELS[1]) or KEY_LABELS[i], text = ns.T(MODE_TEXT[mode]),
            note = preview and ns.T("scanKeySearches", preview[mode] or 0)}
    end
    return rows
end
function K.ScanRule(modes)
    local fresh, rule = K.ScanFresh(), ns.T("scanRule")
    if modes and modes ~= K.SCAN_MODES then
        local parts = {}
        for _, row in ipairs(K.ScanKeys(nil, modes)) do parts[#parts + 1] = row.key .. " — " .. row.text end
        rule = table.concat(parts, " ")
    end
    return rule .. (fresh and ("\n" .. fresh) or "")
end
function K.ScanAge(button)
    local age, sources = rawget(button, "scanAgeFn"), rawget(button, "scanSources")
    if age then return age() end
    local found = sources and ns.Batch and ns.Batch.Age and sources()
    return found and ns.Batch.Age(found, rawget(button, "scanSkip") ~= false) or nil
end
function K.ScanStale(age)
    if not age or age.count == 0 then return false end
    return age.never > 0 or (age.oldest or 0) > K.SCAN_STALE
end
function K.ScanFacts(preview, age)
    local groups, rows = {}, {}
    if age and age.count > 0 then
        rows[#rows + 1] = {label = ns.T("scanAgeLast"), value = age.oldest and K.Ago(age.oldest) or ns.T("scanAgeNever")}
        if age.oldest and age.never > 0 then rows[#rows + 1] = {label = ns.T("scanAgeMissing"), value = tostring(age.never)} end
    end
    if preview then
        for _, pair in ipairs({{"scanSkipFresh", preview.fresh}, {"scanSkipVendor", preview.vendor},
            {"scanSkipUnknown", preview.unknown}}) do
            if (pair[2] or 0) > 0 then rows[#rows + 1] = {label = ns.T(pair[1]), value = tostring(pair[2])} end
        end
    end
    if #rows > 0 then groups[#groups + 1] = {head = ns.T("scanDataHead"), rows = rows} end
    local ttl = ns.Markets and ns.Markets.ttl
    if ttl then
        local function minutes(seconds) return ns.T("scanMinutes", math.floor(seconds / 60 + 0.5)) end
        local function hours(seconds) return ns.T("scanHours", math.floor(seconds / 3600 + 0.5)) end
        groups[#groups + 1] = {head = ns.T("scanFreshHead"), rows = {
            {label = ns.T("scanFreshMaterial"), value = minutes(ttl.material)},
            {label = ns.T("scanFreshGem"), value = minutes(ttl.gem)},
            {label = ns.T("scanFreshProduct"), value = hours(ttl.product)},
            {label = ns.T("scanFreshResale"), value = hours(ttl.resale)}}}
    end
    return groups
end
local Dots = {buttons = setmetatable({}, {__mode = "k"}), tick = 0, SWEEP = 60, STEP = 0.5}
K.ScanDotState = Dots
function K.ScanDot(button)
    button.scanDirty = nil
    local stale = K.ScanStale(K.ScanAge(button))
    local dot = rawget(button, "scanDot")
    if stale and not dot then
        dot = button:CreateTexture(nil, "OVERLAY")
        dot:SetTexture(K.theme.dot); dot:SetVertexColor(unpack(K.theme.gold))
        dot:SetWidth(6); dot:SetHeight(6)
        dot:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -3)
        button.scanDot = dot
    end
    if dot then if stale then dot:Show() else dot:Hide() end end
    return stale
end
function K.ScanDots(force)
    local now, version = GetTime(), ns.Markets and ns.Markets.version
    local sweep = force or version ~= Dots.version or not Dots.swept or now - Dots.swept >= Dots.SWEEP
    if sweep then Dots.version, Dots.swept = version, now end
    for button in pairs(Dots.buttons) do
        if sweep or rawget(button, "scanDirty") then
            if button:IsVisible() then K.ScanDot(button) else button.scanDirty = true end
        end
    end
end
function K.ScanUntrack(button)
    Dots.buttons[button] = nil
    button.scanSources, button.scanAgeFn, button.scanDirty = nil, nil, nil
    local dot = rawget(button, "scanDot")
    if dot then dot:Hide() end
end
local function driver()
    if Dots.frame then return end
    Dots.frame = ns.NewFrame("Frame", nil, UIParent)
    Dots.frame:SetScript("OnUpdate", function(_, elapsed)
        Dots.tick = Dots.tick + elapsed
        if Dots.tick >= Dots.STEP then Dots.tick = 0; K.ScanDots() end
    end)
end
function K.ScanTip(button, title, body, sources, skipUnknown, options)
    local skip = skipUnknown ~= false
    local modes = options and options.modes or K.SCAN_MODES
    local function text() return type(body) == "function" and body() or body end
    local function list() return sources and ns.Batch and sources() or nil end
    K.Tooltip(button, title, "")
    button.scanModes, button.scanSources, button.scanSkip = modes, sources, skip
    button.scanAgeFn = options and options.age or nil
    button.scanDirty = true
    Dots.buttons[button] = true
    driver()
    if not rawget(button, "scanDotHooked") then
        button.scanDotHooked = true
        button:HookScript("OnShow", function(self) if Dots.buttons[self] then self.scanDirty = true end end)
    end
    button.tipKeys = function()
        local found = list()
        local preview = found and ns.Batch.Preview(found, skip)
        return {body = text(), keys = K.ScanKeys(preview, modes), facts = K.ScanFacts(preview, K.ScanAge(button))}
    end
    button.tipFn = function()
        local found, out = list(), text() .. "\n\n" .. K.ScanRule(modes)
        if found then out = out .. "\n\n" .. ns.Batch.PreviewText(found, skip) end
        return out
    end
end
local KeyTip = {WIDTH = 340, PAD = 10, GAP = 8, ROWS = 4, FACTS = 6, FACT_STEP = 14}
K.KeyTip = KeyTip
function K.Keycap(parent)
    local chip = ns.NewFrame("Frame", nil, parent)
    chip:SetBackdrop(K.theme.buttonSkin)
    chip:SetBackdropColor(unpack(K.theme.keycap.bg)); chip:SetBackdropBorderColor(unpack(K.theme.keycap.edge))
    chip:SetHeight(18)
    chip.label = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chip.label:SetPoint("CENTER", chip, "CENTER", 0, 0)
    chip.label:SetTextColor(unpack(K.theme.keycap.text))
    return chip
end
function K.TipPanel(f)
    K.Panel(f)
    f.tradeBase:SetVertexColor(unpack(K.theme.tip))
    f:SetBackdropBorderColor(unpack(K.theme.accent))
end
function KeyTip.Frame()
    if KeyTip.frame then return KeyTip.frame end
    local f = ns.NewFrame("Frame", "ManaCodeKeyTip", UIParent)
    f:SetFrameStrata("TOOLTIP"); f:SetClampedToScreen(true)
    K.TipPanel(f)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText")
    f.body = f:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    f.rule = f:CreateTexture(nil, "BORDER")
    f.rule:SetTexture(K.theme.white); f.rule:SetVertexColor(unpack(K.theme.line)); f.rule:SetHeight(1)
    f.rows = {}
    for i = 1, KeyTip.ROWS do
        f.rows[i] = {chip = K.Keycap(f), text = f:CreateFontString(nil, "OVERLAY", "GameTooltipText"),
            note = f:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")}
    end
    f.groups = {}
    for g = 1, 2 do
        local group = {head = f:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall"), labels = {}, values = {}}
        for i = 1, KeyTip.FACTS do
            group.labels[i] = f:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
            group.values[i] = f:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
        end
        f.groups[g] = group
    end
    f:Hide()
    KeyTip.frame = f
    return f
end
function KeyTip.Show(owner, content)
    local f, pad, gap = KeyTip.Frame(), KeyTip.PAD, KeyTip.GAP
    local inner = KeyTip.WIDTH - pad * 2
    local y = -pad
    local function place(fs, x, width, text, color, justify, top)
        fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", f, "TOPLEFT", x, top or y)
        fs:SetWidth(width); fs:SetJustifyH(justify or "LEFT")
        fs:SetText(text); fs:SetTextColor(unpack(color)); fs:Show()
        return math.ceil(fs:GetStringHeight() or 12)
    end
    y = y - place(f.title, pad, inner, content.title or "", K.theme.accent)
    if content.body and content.body ~= "" then
        y = y - 4
        y = y - place(f.body, pad, inner, content.body, K.theme.text)
    else f.body:Hide() end
    local keys, column, notes = content.keys or {}, 0, 0
    for i, row in ipairs(f.rows) do
        local key = keys[i]
        if key then
            row.chip.label:SetText(key.key)
            column = math.max(column, math.ceil((row.chip.label:GetStringWidth() or 30) + 16), 44)
            row.note:SetText(key.note or "")
            notes = math.max(notes, key.note and math.ceil((row.note:GetStringWidth() or 0) + 8) or 0)
        end
    end
    if #keys > 0 then y = y - gap end
    for i, row in ipairs(f.rows) do
        local key = keys[i]
        if key then
            row.chip:ClearAllPoints(); row.chip:SetPoint("TOPLEFT", f, "TOPLEFT", pad, y)
            row.chip:SetWidth(column); row.chip:Show()
            local x = pad + column + 8
            local height = place(row.text, x, inner - column - 8 - notes, key.text, K.theme.text, "LEFT", y - 3)
            if key.note then place(row.note, pad + inner - notes, notes, key.note, K.theme.secondary, "RIGHT", y - 4)
            else row.note:Hide() end
            y = y - math.max(18, height + 3) - 4
        else row.chip:Hide(); row.text:Hide(); row.note:Hide() end
    end
    local groups = content.facts or {}
    if #groups > 0 then
        y = y - 2
        f.rule:ClearAllPoints()
        f.rule:SetPoint("TOPLEFT", f, "TOPLEFT", pad, y); f.rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, y)
        f.rule:Show()
        y = y - gap
    else f.rule:Hide() end
    local count = math.min(#groups, #f.groups)
    local width = count > 0 and math.floor((inner - (count - 1) * 16) / count) or inner
    local tallest = 0
    for g, group in ipairs(f.groups) do
        local data = g <= count and groups[g]
        local x, rows = pad + (g - 1) * (width + 16), data and data.rows or {}
        if data then
            place(group.head, x, width, data.head, K.theme.accent)
            tallest = math.max(tallest, (#rows + 1) * KeyTip.FACT_STEP)
        else group.head:Hide() end
        for i = 1, KeyTip.FACTS do
            local fact, top = rows[i], y - i * KeyTip.FACT_STEP
            if fact then
                place(group.labels[i], x, width, fact.label, K.theme.secondary, "LEFT", top)
                place(group.values[i], x, width, fact.value, K.theme.text, "RIGHT", top)
            else group.labels[i]:Hide(); group.values[i]:Hide() end
        end
    end
    y = y - tallest
    f:SetWidth(KeyTip.WIDTH); f:SetHeight(-y + pad)
    f:ClearAllPoints(); f:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 0, 0)
    f.owner = owner
    f:Show()
end
function KeyTip.Hide(owner)
    local f = KeyTip.frame
    if f and (not owner or f.owner == owner) then f:Hide(); f.owner = nil end
end
function K.Tooltip(parent, title, body)
    parent.tipTitle, parent.tip, parent.tipKeys = title, body, nil
    if rawget(parent, "tradeTipHooked") then return end
    parent.tradeTipHooked = true
    parent:HookScript("OnEnter", function(self)
        local keys = rawget(self, "tipKeys")
        if keys then
            local content = keys()
            content.title = content.title or self.tipTitle
            KeyTip.Show(self, content)
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.tipTitle, unpack(K.theme.accent))
        GameTooltip:AddLine(self.tipFn and self.tipFn() or self.tip, K.theme.text[1], K.theme.text[2], K.theme.text[3], true)
        GameTooltip:Show()
    end)
    parent:HookScript("OnLeave", function(self)
        GameTooltip:Hide()
        KeyTip.Hide(self)
    end)
end
function K.DisabledTip(b, title, reason)
    b.disabledTipTitle, b.disabledTip = title, reason
    if rawget(b, "disabledTipHooked") then return end
    b.disabledTipHooked = true
    b:HookScript("OnEnter", function(self)
        if not self.btnDisabled or not self.disabledTip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.disabledTipTitle, unpack(K.theme.accent))
        GameTooltip:AddLine(self.disabledTip, K.theme.text[1], K.theme.text[2], K.theme.text[3], true)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
