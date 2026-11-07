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
    if not rawget(button, "bare") and rawget(button, "tradeKitButton") and button.kind ~= "scan" then
        button.kind = "scan"; K.StyleButton(button)
    end
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
local KeyTip = {WIDTH = 340, WIDE = 400, PAD = 10, GAP = 8, ROWS = 4, FACTS = 6, FACT_STEP = 18, ITEMS = 10, COUNT = 36,
    VALUE = 112}
K.KeyTip = KeyTip
K.KEYCAP_ROUND = {bgFile = K.theme.white, edgeFile = "Interface\\AddOns\\ManaCode_AuctionScan\\art\\round", tile = false,
    edgeSize = 5, insets = {left = 5, right = 5, top = 5, bottom = 5}}
function K.Keycaps(parent)
    local keys = ns.Keycap.New(parent, {
        color = function(role)
            local c = K.theme.keycap[role == "face" and "bg" or role == "side" and "edge" or "text"]
            return c[1], c[2], c[3]
        end,
        text = function(fs, text) K.BindFont(fs, "small"); fs:SetText(text) end,
        backdrop = K.KEYCAP_ROUND, edge = 0.8})
    local draw = keys.Draw
    keys.Draw = function(self, i, text)
        local key = draw(self, i, text)
        key.box.label = key.label
        return key
    end
    return keys
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
    f.title = K.FontString(f, "heading")
    f.body = K.FontString(f, "normal")
    f.rule = f:CreateTexture(nil, "BORDER")
    f.rule:SetTexture(K.theme.white); f.rule:SetVertexColor(unpack(K.theme.line)); f.rule:SetHeight(1)
    f.rows, f.keys = {}, K.Keycaps(f)
    for i = 1, KeyTip.ROWS do
        f.rows[i] = {text = K.FontString(f, "normal"),
            note = K.FontString(f, "small")}
    end
    f.groups = {}
    for g = 1, 2 do
        local group = {head = K.FontString(f, "normal"), labels = {}, values = {}}
        for i = 1, KeyTip.FACTS do
            group.labels[i] = K.FontString(f, "normal")
            group.values[i] = K.FontString(f, "normal")
        end
        f.groups[g] = group
    end
    f.items = {}
    for i = 1, KeyTip.ITEMS + 1 do
        f.items[i] = {name = K.FontString(f, "normal"),
            count = K.FontString(f, "normal"),
            value = K.FontString(f, "normal")}
    end
    f.itemRule = f:CreateTexture(nil, "BORDER")
    f.itemRule:SetTexture(K.theme.white); f.itemRule:SetVertexColor(unpack(K.theme.line)); f.itemRule:SetHeight(1)
    f:Hide()
    KeyTip.frame = f
    return f
end
function KeyTip.Show(owner, content)
    local f, pad, gap = KeyTip.Frame(), KeyTip.PAD, KeyTip.GAP
    f.width = content.items and #content.items > 0 and KeyTip.WIDE or KeyTip.WIDTH
    local inner = f.width - pad * 2
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
    local keys, notes = content.keys or {}, 0
    for i, row in ipairs(f.rows) do
        local key = keys[i]
        if key then
            row.chip = f.keys:Draw(i, key.key).box
            row.note:SetText(key.note or "")
            notes = math.max(notes, key.note and math.ceil((row.note:GetStringWidth() or 0) + 8) or 0)
        end
    end
    f.keys:HideFrom(math.min(#keys, #f.rows) + 1)
    local column = f.keys:Column(math.min(#keys, #f.rows))
    if #keys > 0 then y = y - gap end
    for i, row in ipairs(f.rows) do
        local key = keys[i]
        if key then
            local cap = f.keys.list[i]
            cap.box:ClearAllPoints(); cap.box:SetPoint("TOPLEFT", f, "TOPLEFT", pad, y)
            local x = pad + column + f.keys.gap
            local height = place(row.text, x, inner - column - f.keys.gap - notes, key.text, K.theme.text, "LEFT", y - 3)
            if key.note then place(row.note, pad + inner - notes, notes, key.note, K.theme.secondary, "RIGHT", y - 4)
            else row.note:Hide() end
            y = y - math.max(cap.h, height + 3) - 4
        else row.text:Hide(); row.note:Hide() end
    end
    y = KeyTip.Items(f, content, y, place)
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
            tallest = math.max(tallest, (#rows + 1) * K.FontHeight(KeyTip.FACT_STEP))
        else group.head:Hide() end
        for i = 1, KeyTip.FACTS do
            local fact, top = rows[i], y - i * K.FontHeight(KeyTip.FACT_STEP)
            if fact then
                place(group.labels[i], x, width, fact.label, K.theme.secondary, "LEFT", top)
                place(group.values[i], x, width, fact.value, K.theme.text, "RIGHT", top)
            else group.labels[i]:Hide(); group.values[i]:Hide() end
        end
    end
    y = y - tallest
    f:SetWidth(f.width); f:SetHeight(-y + pad)
    f:ClearAllPoints()
    if KeyTip.FitsRight(owner, f.width) then f:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 0, 0)
    else f:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 2) end
    f.owner = owner
    f:Show()
end
function KeyTip.FitsRight(owner, width)
    local right = owner.GetRight and owner:GetRight()
    local root = UIParent
    if not root then return true end
    local screen = root.GetRight and root:GetRight()
    if type(right) ~= "number" or type(screen) ~= "number" then return true end
    local scale = owner.GetEffectiveScale and owner:GetEffectiveScale()
    local base = root.GetEffectiveScale and root:GetEffectiveScale()
    if type(scale) == "number" and type(base) == "number" and base > 0 then right = right * scale / base end
    return right + width <= screen
end
function KeyTip.Items(f, content, y, place)
    local items, pad = content.items or {}, KeyTip.PAD
    local inner = (f.width or KeyTip.WIDTH) - pad * 2
    local nameWidth = inner - KeyTip.COUNT - KeyTip.VALUE - 16
    local shown = #items > KeyTip.ITEMS and KeyTip.ITEMS - 1 or #items
    if #items > 0 then y = y - KeyTip.GAP end
    for i, row in ipairs(f.items) do
        local item = items[i]
        local top = y - (i - 1) * K.FontHeight(KeyTip.FACT_STEP)
        if item and i <= shown then
            local icon = select(10, ns.Compat.ItemInfo(item.id))
            place(row.name, pad, nameWidth, (icon and "|T" .. icon .. ":16:16|t " or "") .. ns.Markets.Name(item.id), K.theme.text, "LEFT", top)
            row.name:SetHeight(K.FontHeight(16))
            place(row.count, pad + nameWidth + 4, KeyTip.COUNT, item.count and ns.T("tipItemCount", item.count) or "",
                K.theme.secondary, "LEFT", top)
            place(row.value, pad + inner - KeyTip.VALUE, KeyTip.VALUE, item.label or (item.value and K.Money(item.value) or ns.T("batchNoPrice")),
                K.theme[item.tone or ((item.label or item.value) and "text" or "negative")], "RIGHT", top)
        elseif i == shown + 1 and #items > shown then
            place(row.name, pad, nameWidth, ns.T("batchMoreItems", #items - shown), K.theme.secondary, "LEFT", top)
            row.count:Hide(); row.value:Hide()
        else row.name:Hide(); row.count:Hide(); row.value:Hide() end
    end
    local rows = math.min(#items, KeyTip.ITEMS)
    y = y - rows * K.FontHeight(KeyTip.FACT_STEP)
    local total = content.total
    if total and #items > 0 then
        f.itemRule:ClearAllPoints()
        f.itemRule:SetPoint("TOPLEFT", f, "TOPLEFT", pad, y - 2); f.itemRule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, y - 2)
        f.itemRule:Show()
        local last = f.items[KeyTip.ITEMS + 1]
        place(last.name, pad, inner - KeyTip.VALUE - 4, total.label, K.theme.secondary, "LEFT", y - 6)
        place(last.value, pad + inner - KeyTip.VALUE, KeyTip.VALUE, total.value, K.theme.text, "RIGHT", y - 6)
        last.count:Hide()
        y = y - 6 - K.FontHeight(KeyTip.FACT_STEP)
    else f.itemRule:Hide() end
    return y
end
function KeyTip.Hide(owner)
    local f = KeyTip.frame
    if f and (not owner or f.owner == owner) then f:Hide(); f.owner = nil end
end
function K.TipOwner(owner, anchor)
    local tip = GameTooltip
    tip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    local under = rawget(tip, "tradeUnder")
    if not under then
        under = tip.CreateTexture and tip:CreateTexture(nil, "BACKGROUND")
        if not under then return end
        under:SetPoint("TOPLEFT", tip, "TOPLEFT", 3, -3)
        under:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -3, 3)
        under:SetTexture(K.theme.white)
        tip.tradeUnder = under
        tip:HookScript("OnHide", function(self) self.tradeUnder:Hide() end)
    end
    under:SetVertexColor(K.theme.tip[1], K.theme.tip[2], K.theme.tip[3], 1)
    under:Show()
end
local textTip
local function hideTextTip(owner)
    if textTip and textTip.owner == owner then
        textTip:Hide()
        textTip.owner = nil
    end
end
local function showTextTip(owner, title, body)
    if not textTip then
        textTip = ns.NewFrame("Frame", nil, UIParent)
        textTip:SetFrameStrata("TOOLTIP")
        textTip:SetClampedToScreen(true)
        K.TipPanel(textTip)
        textTip.title = K.Label(textTip, "", 10, -10, 320, "heading")
        textTip.body = K.Label(textTip, "", 10, -28, 320)
        K.BindFont(textTip.body, "normal")
    end
    local f = textTip
    f.owner = owner
    f:ClearAllPoints(); f:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 0, 0)
    f.title:SetText(title)
    f.title:SetTextColor(unpack(K.theme.accent))
    f.title:SetWidth(320)
    local width = math.max(1, math.min(320, math.ceil(f.title:GetStringWidth() or 320)))
    local height = 20 + math.ceil(f.title:GetStringHeight() or K.FontHeight(12))
    if body and body ~= "" then
        f.body:Show()
        f.body:SetText(body)
        f.body:SetWidth(320)
        width = math.max(width, math.min(320, math.ceil(f.body:GetStringWidth() or 320)))
        f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 10, 6 - height)
        height = height + 4 + math.ceil(f.body:GetStringHeight() or K.FontHeight(12))
    else f.body:Hide() end
    f:SetWidth(width + 20); f:SetHeight(height)
    f:Show()
end
function K.RefreshTip(owner)
    if textTip and textTip.owner == owner then
        showTextTip(owner, owner.tipTitle, owner.tipFn and owner.tipFn() or owner.tip)
    end
end
function K.Tooltip(parent, title, body)
    parent.tipTitle, parent.tip, parent.tipKeys = title, body, nil
    if rawget(parent, "tradeTipHooked") then return end
    parent.tradeTipHooked = true
    parent:HookScript("OnEnter", function(self)
        local keys = rawget(self, "tipKeys")
        if not keys and rawget(self, "btnDisabled") and rawget(self, "disabledTip") then return end
        if keys then
            local content = keys()
            content.title = content.title or self.tipTitle
            KeyTip.Show(self, content)
            return
        end
        showTextTip(self, self.tipTitle, self.tipFn and self.tipFn() or self.tip)
    end)
    local function hide(self)
        hideTextTip(self)
        KeyTip.Hide(self)
    end
    parent:HookScript("OnLeave", hide)
    parent:HookScript("OnHide", hide)
end
function K.DisabledTip(b, title, reason)
    b.disabledTipTitle, b.disabledTip = title, reason
    if rawget(b, "disabledTipHooked") then return end
    b.disabledTipHooked = true
    b:HookScript("OnEnter", function(self)
        if not self.btnDisabled or not self.disabledTip then return end
        showTextTip(self, self.disabledTipTitle, self.disabledTip)
    end)
    b:HookScript("OnLeave", hideTextTip)
    b:HookScript("OnHide", hideTextTip)
end
