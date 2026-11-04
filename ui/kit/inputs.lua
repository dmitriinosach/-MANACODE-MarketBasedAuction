local _, ns = ...
local K = ns.TradeKit
function K.HoverMenu(menu)
    local away = 0
    menu.frame:HookScript("OnEnter", function() if not menu.frame.btnDisabled then menu.cover:Show() end end)
    menu.cover:HookScript("OnShow", function() away = 0 end)
    menu.cover:SetScript("OnUpdate", function(_, elapsed)
        if MouseIsOver(menu.frame) or MouseIsOver(menu.panel) then away = 0; return end
        away = away + elapsed
        if away > 0.3 then menu.cover:Hide() end
    end)
end
function K.Chip(parent, text, changed)
    local b = K.Button(parent, text, 80, nil, "quiet")
    b.checked = false
    b.dot = b:CreateTexture(nil, "ARTWORK")
    b.dot:SetTexture(K.theme.white); b.dot:SetWidth(6); b.dot:SetHeight(6)
    b.dot:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", b, "LEFT", 19, 0); b.text:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    b.text:SetJustifyH("LEFT")
    b.SetChecked = function(self, value) self.checked = value and true or false; self:SetActive(self.checked) end
    b.GetChecked = function(self) return self.checked end
    b.onClick = function(self) self:SetChecked(not self.checked); changed(self.checked) end
    K.FitButton(b, 32)
    K.StyleButton(b)
    return b
end
function K.Switch(parent, text, changed)
    local b = ns.NewFrame("Button", nil, parent)
    b:SetHeight(22)
    b.track = b:CreateTexture(nil, "BACKGROUND")
    b.track:SetTexture(K.theme.white); b.track:SetWidth(28); b.track:SetHeight(12)
    b.track:SetPoint("LEFT", b, "LEFT", 0, 0)
    b.knob = b:CreateTexture(nil, "ARTWORK")
    b.knob:SetTexture(K.theme.white); b.knob:SetWidth(14); b.knob:SetHeight(14)
    b.text = K.Label(b, text, 0, 0, 200)
    b.text:SetHeight(12); b.text:ClearAllPoints(); b.text:SetPoint("LEFT", b.track, "RIGHT", 8, 0)
    b.Fit = function(self) self:SetWidth(36 + math.ceil(math.max(self.text:GetStringWidth() or 0, 40))) end
    b:Fit()
    b.frame = b
    b.SetChecked = function(self, value)
        self:Fit()
        self.checked = value and true or false
        self.knob:ClearAllPoints()
        self.knob:SetPoint("CENTER", self.track, self.checked and "RIGHT" or "LEFT", self.checked and -6 or 6, 0)
        self.track:SetVertexColor(unpack(self.checked and K.theme.main.bg or K.theme.field))
        self.knob:SetVertexColor(unpack(self.checked and K.theme.gold or K.theme.off))
        self.text:SetTextColor(unpack(self.checked and K.theme.text or K.theme.secondary))
    end
    b.GetChecked = function(self) return self.checked end
    b:SetScript("OnClick", function(self) self:SetChecked(not self.checked); changed(self.checked) end)
    b:SetChecked(false)
    return b
end
function K.Segment(parent, entries, choose, tip)
    local seg = {buttons = {}, order = {}}
    seg.frame = ns.NewFrame("Frame", nil, parent)
    seg.frame:SetHeight(22)
    K.Skin(seg.frame)
    seg.frame:SetBackdropColor(unpack(K.theme.quiet.bg))
    seg.frame:SetBackdropBorderColor(unpack(K.theme.edge))
    local x = 2
    for i, entry in ipairs(entries) do
        local key = entry.key
        local b = K.Button(seg.frame, entry.label, 60, function() choose(key) end, "segment")
        b:SetHeight(18)
        K.FitButton(b, 20)
        b:SetPoint("LEFT", seg.frame, "LEFT", x, 0)
        if entry.tip then b.ownTip = true; K.Tooltip(b, entry.tip[1], entry.tip[2]) end
        x = x + (b:GetWidth() or 60) + 1
        seg.buttons[key], seg.order[i] = b, b
    end
    seg.frame:SetWidth(x + 1)
    seg.Select = function(self, key) for k, b in pairs(self.buttons) do b:SetActive(k == key) end end
    seg.Enable = function(self) for _, b in ipairs(self.order) do b:Enable() end end
    seg.Disable = function(self) for _, b in ipairs(self.order) do b:Disable() end end
    seg.SetTip = function(self, title, body)
        for _, b in ipairs(self.order) do if not rawget(b, "ownTip") then K.Tooltip(b, title, body) end end
    end
    seg.Arrange = function(self, labels)
        local at = 2
        for i, entry in ipairs(entries) do
            local b, label = self.order[i], labels[entry.key]
            if label then
                b:SetText(label); K.FitButton(b, 20)
                b:ClearAllPoints(); b:SetPoint("LEFT", self.frame, "LEFT", at, 0)
                at = at + (b:GetWidth() or 60) + 1
                b:Show()
            else b:Hide() end
        end
        self.frame:SetWidth(at + 1)
    end
    if tip then seg:SetTip(tip[1], tip[2]) end
    return seg
end
local EpochChips = {}
EpochChips.__index = EpochChips
K.EpochChips = EpochChips
EpochChips.order = {"wrath", "bc", "classic"}
EpochChips.labels = {wrath = "craftWrath", bc = "craftBC", classic = "craftClassic"}
function EpochChips:New(parent, keys, changed, empty)
    local view = setmetatable({chips = {}}, self)
    view.frame = ns.NewFrame("Frame", nil, parent)
    view.frame:SetHeight(22)
    local wanted = {}
    for _, key in ipairs(keys or self.order) do wanted[key] = true end
    local x = 0
    for _, key in ipairs(self.order) do
        if wanted[key] then
            local label = ns.T(self.labels[key])
            local chip = K.Chip(view.frame, label, function(checked) changed(key, checked) end)
            chip:SetPoint("LEFT", view.frame, "LEFT", x, 0)
            K.Tooltip(chip, label, "")
            chip.tipFn = function() return view.props and view.props.tip and view.props.tip(key) or "" end
            K.DisabledTip(chip, label, empty)
            x = x + (chip:GetWidth() or 60) + 4
            view.chips[key] = chip
        end
    end
    view.frame:SetWidth(math.max(1, x - 4))
    return view
end
function EpochChips:SetProps(props)
    self.props = props
    self:Render()
end
function EpochChips:Render()
    local p = self.props
    for key, chip in pairs(self.chips) do
        chip:SetChecked(p.shown[key])
        if not p.counts or (p.counts[key] or 0) > 0 then chip:Enable() else chip:Disable() end
    end
end
function K.QualityMenu(parent, changed, qualities)
    local menu = K.Menu(parent, {}, function(key) if type(key) == "number" then changed(key) end end)
    local list = qualities or {1, 2, 3, 4}
    menu.keep = true
    menu.frame:SetHeight(22)
    K.Tooltip(menu.frame, ns.T("qualityFilter"), ns.T("qualityFilterTip"))
    menu.SetState = function(self, state, unknown)
        local entries, on = {}, 0
        for _, quality in ipairs(list) do
            local checked = state[quality] ~= false
            if checked then on = on + 1 end
            entries[#entries + 1] = {key = quality, label = _G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality),
                quality = quality, checked = checked}
        end
        if (unknown or 0) > 0 then
            entries[#entries + 1] = {divider = true}
            entries[#entries + 1] = {key = "unknown", label = ns.T("qualityUnknown", unknown), disabled = true,
                tip = ns.T("qualityUnknownTip")}
        end
        self:SetEntries(entries)
        self.frame:SetText(on == #list and ns.T("qualityFilter") or ns.T("qualityFilterCount", on))
        K.FitButton(self.frame, 36)
    end
    return menu
end
local QualityToggles = {}
QualityToggles.__index = QualityToggles
K.QualityToggles = QualityToggles
QualityToggles.LEVELS = 3
function QualityToggles:New(parent, qualities, changed)
    local view = setmetatable({chips = {}, qualities = qualities, level = 1}, self)
    view.frame = ns.NewFrame("Frame", nil, parent)
    view.frame:SetHeight(22)
    view.label = K.Label(view.frame, ns.T("qualityFilter"), 0, 0, 80, "secondary"); view.label:SetHeight(12)
    view.label:ClearAllPoints(); view.label:SetPoint("LEFT", view.frame, "LEFT", 0, 0)
    for _, quality in ipairs(qualities) do
        local name = _G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality)
        local chip = K.Chip(view.frame, name, function() changed(quality) end)
        chip.quality, chip.name = quality, name
        K.Tooltip(chip, name, ns.T("qualityToggleTip"))
        view.chips[quality] = chip
    end
    view.menu = K.QualityMenu(view.frame, changed, qualities)
    view.menu.frame:ClearAllPoints(); view.menu.frame:SetPoint("LEFT", view.frame, "LEFT", 0, 0)
    view.frame.levels = QualityToggles.LEVELS
    view.frame.Fit = function(_, level) view:Fit(level or 1) end
    view:Fit(1)
    return view
end
function QualityToggles:Fit(level)
    self.level = level
    if level >= 3 then
        self.label:Hide()
        for _, chip in pairs(self.chips) do chip:Hide() end
        self.menu.frame:Show()
        self.frame:SetWidth(self.menu.frame:GetWidth() or 90)
        return
    end
    self.menu.frame:Hide()
    local labelWidth = math.ceil(math.min(80, self.label.GetStringWidth and self.label:GetStringWidth() or 50))
    self.label:SetWidth(labelWidth + 2); self.label:Show()
    local x = labelWidth + 8
    for _, quality in ipairs(self.qualities) do
        local chip = self.chips[quality]
        if level == 1 then chip:SetText(chip.name); K.FitButton(chip, 32)
        else chip:SetText(""); chip:SetWidth(22) end
        chip:ClearAllPoints(); chip:SetPoint("LEFT", self.frame, "LEFT", x, 0); chip:Show()
        x = x + (chip:GetWidth() or 22) + (level == 1 and 4 or 2)
    end
    self.frame:SetWidth(x)
end
function QualityToggles:SetState(state, unknown)
    for quality, chip in pairs(self.chips) do chip:SetChecked(state[quality] ~= false) end
    self.menu:SetState(state, unknown)
end
function K.Edit(parent, width, large, placeholder)
    local edit = ns.NewFrame("EditBox", nil, parent)
    edit:SetWidth(width)
    edit:SetHeight(large and 26 or 22)
    edit:SetAutoFocus(false)
    edit:SetFontObject(large and "GameFontHighlight" or "GameFontHighlightSmall")
    edit:SetTextInsets(large and 8 or 6, large and 8 or 6, 0, 0)
    K.Skin(edit)
    edit:SetBackdropColor(unpack(K.theme.field))
    edit:SetBackdropBorderColor(unpack(K.theme.edge))
    if placeholder then
        edit.placeholder = K.Label(edit, placeholder, 0, 0, width, "secondary")
        edit.placeholder:ClearAllPoints()
        edit.placeholder:SetPoint("LEFT", edit, "LEFT", large and 8 or 6, 0)
        edit.placeholder:SetPoint("RIGHT", edit, "RIGHT", large and -8 or -6, 0)
        edit.placeholder:SetHeight(large and 16 or 14)
        edit.placeholder:SetFontObject(large and "GameFontHighlight" or "GameFontHighlightSmall")
        edit.placeholder:SetTextColor(unpack(K.theme.secondary))
    end
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local native = edit.SetScript
    edit.SetScript = function(self, name, fn)
        if name == "OnTextChanged" and placeholder then
            native(self, name, function(box, ...)
                if (box:GetText() or "") == "" then box.placeholder:Show() else box.placeholder:Hide() end
                if fn then fn(box, ...) end
            end)
            return
        end
        if name ~= "OnEditFocusGained" and name ~= "OnEditFocusLost" then native(self, name, fn); return end
        local color = name == "OnEditFocusGained" and K.theme.accent or K.theme.edge
        native(self, name, function(box, ...)
            box:SetBackdropBorderColor(unpack(color))
            if fn then fn(box, ...) end
        end)
    end
    edit:SetScript("OnEditFocusGained", nil)
    edit:SetScript("OnEditFocusLost", nil)
    if placeholder then edit:SetScript("OnTextChanged", nil) end
    return edit
end
function K.ClearButton(edit, cleared)
    local b = K.Button(edit, "x", 18, function()
        edit:SetText(""); edit:SetFocus()
        if cleared then cleared() end
    end, "quiet")
    b:SetHeight(18)
    b:SetPoint("RIGHT", edit, "RIGHT", -4, 0)
    local left = edit:GetTextInsets()
    edit:SetTextInsets(left or 8, 26, 0, 0)
    if edit.placeholder then edit.placeholder:SetPoint("RIGHT", edit, "RIGHT", -26, 0) end
    K.Tooltip(b, ns.T("editClear"), ns.T("editClearTip"))
    edit:HookScript("OnTextChanged", function(box)
        if (box:GetText() or "") == "" then b:Hide() else b:Show() end
    end)
    b:Hide()
    edit.clear = b
    return b
end
function K.CopyField(parent, width)
    local edit = K.Edit(parent, width)
    edit:SetTextInsets(6, 48, 0, 0)
    edit.keys = K.Label(edit, "Ctrl+C", 0, 0, 44, "secondary")
    edit.keys:ClearAllPoints()
    edit.keys:SetPoint("RIGHT", edit, "RIGHT", -6, 0)
    edit.keys:SetJustifyH("RIGHT")
    edit.SetUrl = function(self, url)
        self.url = url
        self:SetText(url)
        self:SetCursorPosition(0)
    end
    edit:SetScript("OnTextChanged", function(self)
        if self.url and self:GetText() ~= self.url then self:SetText(self.url); self:HighlightText() end
    end)
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    edit:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0); self:SetCursorPosition(0) end)
    edit:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return edit
end
function K.LiveEdit(edit, apply, delay)
    local wait = delay or 0.4
    local function flush(box)
        if not box.liveAt then return end
        box.liveAt = nil
        box:SetScript("OnUpdate", nil)
        apply(box)
    end
    edit:SetScript("OnTextChanged", function(box, typed)
        if not typed then return end
        box.liveAt = GetTime() + wait
        box:SetScript("OnUpdate", function(self) if self.liveAt and GetTime() >= self.liveAt then flush(self) end end)
    end)
    edit:SetScript("OnEnterPressed", function(box)
        box.liveAt = box.liveAt or GetTime()
        flush(box)
        box:ClearFocus()
    end)
    edit.liveFlush = flush
end
function K.FlushEdits(...)
    for i = 1, select("#", ...) do
        local edit = select(i, ...)
        if edit and rawget(edit, "liveFlush") then edit.liveFlush(edit) end
    end
end
local MoneyEdit = {}
MoneyEdit.__index = MoneyEdit
K.MONEY_MAX = 2000000000
local COINS = {
    {width = 58, letters = 7, scale = 10000, icon = "Interface\\MoneyFrame\\UI-GoldIcon"},
    {width = 28, letters = 2, scale = 100, icon = "Interface\\MoneyFrame\\UI-SilverIcon"},
    {width = 28, letters = 2, scale = 1, icon = "Interface\\MoneyFrame\\UI-CopperIcon"},
}
function K.MoneyEdit(parent, apply)
    local view = setmetatable({edits = {}}, MoneyEdit)
    local f = ns.NewFrame("Frame", nil, parent)
    view.frame = f
    f:SetHeight(22)
    local x = 0
    for i, coin in ipairs(COINS) do
        local edit = K.Edit(f, coin.width)
        edit:SetTextInsets(4, 4, 0, 0); edit:SetJustifyH("RIGHT")
        edit:SetNumeric(true); edit:SetMaxLetters(coin.letters)
        edit:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
        K.LiveEdit(edit, function()
            local copper, ok = view:GetValue()
            if ok then apply(copper) end
        end)
        edit:SetScript("OnEditFocusLost", function(box)
            local count = tonumber(box:GetText() or "")
            if count then box:SetText(tostring(math.min(count, math.floor(K.MONEY_MAX / coin.scale)))) end
        end)
        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(coin.icon); icon:SetWidth(12); icon:SetHeight(12)
        icon:SetPoint("LEFT", edit, "RIGHT", 2, 0)
        view.edits[i] = edit
        x = x + coin.width + 16
    end
    f:SetWidth(x - 2)
    for i, edit in ipairs(view.edits) do
        local nextEdit = view.edits[i % #view.edits + 1]
        edit:SetScript("OnTabPressed", function() nextEdit:SetFocus() end)
    end
    return view
end
function MoneyEdit:GetValue()
    local total, filled = 0, false
    for i, coin in ipairs(COINS) do
        local text = (self.edits[i]:GetText() or ""):match("^%s*(.-)%s*$")
        if text ~= "" then
            if not text:match("^%d+$") then return nil, false end
            total, filled = total + tonumber(text) * coin.scale, true
        end
    end
    return filled and math.min(total, K.MONEY_MAX) or nil, true
end
function MoneyEdit:SetValue(copper)
    if self:HasFocus() then return end
    local rounded = copper and math.min(math.max(math.floor(copper + 0.5), 0), K.MONEY_MAX)
    local parts = rounded and {math.floor(rounded / 10000), math.floor(rounded / 100) % 100, rounded % 100} or {}
    for i, edit in ipairs(self.edits) do edit:SetText(parts[i] and tostring(parts[i]) or "") end
end
function MoneyEdit:HasFocus()
    for _, edit in ipairs(self.edits) do if edit:HasFocus() then return true end end
    return false
end
function MoneyEdit:Flush()
    K.FlushEdits(unpack(self.edits))
end
function MoneyEdit:Discard()
    for _, edit in ipairs(self.edits) do
        edit.liveAt = nil; edit:SetScript("OnUpdate", nil); edit:ClearFocus()
    end
end
function MoneyEdit:ClearFocus()
    for _, edit in ipairs(self.edits) do edit:ClearFocus() end
end
function MoneyEdit:SetEnabled(enabled)
    for _, edit in ipairs(self.edits) do
        edit:EnableMouse(enabled)
        if not enabled then edit:ClearFocus() end
        edit:SetTextColor(unpack(enabled and K.theme.text or K.theme.off))
    end
end
function K.Check(parent, changed)
    local check = ns.NewFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetWidth(18); check:SetHeight(18)
    check:SetScript("OnClick", function(self) changed(self:GetChecked() and true or false) end)
    return check
end
local QuoteEditor = {}
QuoteEditor.__index = QuoteEditor
K.QuoteEditor = QuoteEditor
function QuoteEditor:New(parent, save, refresh)
    local view = setmetatable({}, self)
    view.frame = ns.NewFrame("Frame", nil, parent); view.frame:SetHeight(30)
    view.item = K.ItemChoice(view.frame, function() ns.Trader.OpenReagent(view.props.id) end)
    view.item:SetPoint("LEFT", view.frame, "LEFT", 0, 0)
    view.cell = view.frame:CreateTexture(nil, "BACKGROUND")
    view.cell:SetAllPoints(view.frame); view.cell:SetTexture(K.theme.white)
    view.cell:SetVertexColor(unpack(K.theme.row))
    view.edit = K.Edit(view.frame, 70)
    view.edit:SetPoint("RIGHT", view.frame, "RIGHT", -104, 0)
    view.unit = K.Label(view.frame, ns.T("deGold"), 0, 0, 12)
    view.unit:ClearAllPoints(); view.unit:SetPoint("LEFT", view.edit, "RIGHT", 3, 0)
    view.unit:SetTextColor(unpack(K.theme.gold))
    view.coin = K.Label(view.frame, "", 0, 0, 96)
    view.coin:ClearAllPoints(); view.coin:SetPoint("RIGHT", view.edit, "LEFT", -8, 0)
    view.coin:SetJustifyH("RIGHT")
    view.edit:SetScript("OnTextChanged", function(_, user) if user then view.draft = true end end)
    view.edit:SetScript("OnEnterPressed", function()
        if view.props.disabled then return end
        local value = tonumber((view.edit:GetText():gsub(",", ".")))
        if not value or not save(view.props.id, value * 10000) then ns.say(ns.T("alchemyInvalidPrice"), "bad"); return end
        view.draft = false; view.edit:ClearFocus(); ns.Trader.Refresh()
    end)
    view.edit:SetScript("OnEscapePressed", function()
        if view.props.disabled then return end
        save(view.props.id, nil); view.draft = false; view.edit:ClearFocus(); ns.Trader.Refresh()
    end)
    K.Tooltip(view.edit, ns.T("deSellPrice"), ns.T("deSellPriceTip"))
    view.refresh = K.Button(view.frame, ns.T("tradeUpdate"), 84, function()
        save(view.props.id, nil); view.draft = false; refresh(view.props.id)
    end, "quiet")
    view.refresh:SetPoint("RIGHT", view.frame, "RIGHT", 0, 0)
    K.Tooltip(view.refresh, ns.T("cacheRefreshItem"), ns.T("dePriceRefreshTip"))
    return view
end
function QuoteEditor:SetProps(props)
    if not self.props or self.props.id ~= props.id then self.draft = false end
    self.props = props; self:Render()
end
function QuoteEditor:Render()
    local p = self.props
    self.frame:SetWidth(p.width)
    K.SetItemChoice(self.item, p.id, false)
    self.item:SetWidth(p.width - 270); self.item.text:SetWidth(math.max(30, p.width - 300))
    self.coin:SetText(K.Money(p.quote and p.quote.price))
    self.coin:SetTextColor(unpack(K.theme[p.quote and p.quote.manual and "gold" or "text"]))
    if not self.draft then self.edit:SetText(p.quote and p.quote.price and K.Decimal(p.quote.price / 10000, 4) or "") end
    self.edit:EnableMouse(not p.disabled)
    if p.disabled then self.edit:ClearFocus(); self.refresh:Disable() else self.refresh:Enable() end
    self.frame:Show()
end
local DIVIDER = {divider = true}
function K.Sections(groups, query, name)
    local lower = ns.Shopping and ns.Shopping.Lower or string.lower
    local needle = lower((query or ""):match("^%s*(.-)%s*$"))
    local result = {}
    for _, group in ipairs(groups) do
        local opened = false
        for _, entry in ipairs(group) do
            if needle == "" or lower(name(entry) or ""):find(needle, 1, true) then
                if not opened and #result > 0 then result[#result + 1] = DIVIDER end
                opened = true
                result[#result + 1] = entry
            end
        end
    end
    return result
end
local SearchList = {}
SearchList.__index = SearchList
K.SearchList = SearchList
SearchList.GAP = 9
function SearchList:New(panel, options)
    local list = setmetatable({panel = panel, options = options, rows = {}, rules = {}, entries = {}, query = ""}, self)
    list.first = options.top
    if options.search then
        local edit = K.Edit(panel, 100)
        list.edit = edit
        edit:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -options.top)
        edit:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -options.top)
        list.hint = K.Label(edit, ns.T("listSearch"), 0, 0, 200, "secondary")
        list.hint:ClearAllPoints(); list.hint:SetPoint("LEFT", edit, "LEFT", 7, 0)
        edit:SetScript("OnTextChanged", function(box, typed)
            local text = box:GetText() or ""
            if text == "" then list.hint:Show() else list.hint:Hide() end
            if typed then list:Search(text) end
        end)
        edit:SetScript("OnEnterPressed", function()
            for _, entry in ipairs(list.entries) do
                if not entry.divider then options.choose(entry); return end
            end
        end)
        edit:SetScript("OnEscapePressed", function(box)
            if (box:GetText() or "") ~= "" then box:SetText(""); list:Search(""); return end
            box:ClearFocus()
            if options.close then options.close() end
        end)
        list.first = options.top + 28
    end
    list.scroll = K.Scroller:New(panel, function() list:Render() end, options.step)
    list.scroll.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -list.first)
    list.scroll.frame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
    list.empty = K.Label(panel, ns.T("listNothing"), 12, -list.first - 7, 200, "secondary")
    list.empty:Hide()
    return list
end
function SearchList:Ensure(count)
    for slot = #self.rows + 1, count do
        local row = self.options.make(self.panel, function(row) if row.entry then self.options.choose(row.entry) end end)
        row:Hide()
        self.rows[slot] = row
        self.scroll:Wheel(row)
    end
end
function SearchList:SetProps(props)
    self.props = props
    self:Ensure(props.rows)
    for i = #self.rules + 1, #props.groups - 1 do
        local rule = self.panel:CreateTexture(nil, "BORDER")
        rule:SetTexture(K.theme.white); rule:SetVertexColor(unpack(K.theme.line)); rule:SetHeight(1)
        self.rules[i] = rule
    end
    self.entries = K.Sections(props.groups, self.query, self.options.name)
    self:Render()
end
function SearchList:Search(text)
    self.query = text or ""
    self.scroll.offset = 0
    if self.props then self:SetProps(self.props) end
end
function SearchList:Open()
    if not self.edit then return end
    self.query = ""
    self.edit:SetText("")
    self.hint:Show()
    self.edit:SetFocus()
end
function SearchList:Close()
    if self.edit then self.edit:ClearFocus() end
end
function SearchList:Find(match)
    for i, entry in ipairs(self.entries) do
        if not entry.divider and match(entry) then return i end
    end
end
function SearchList:Height()
    local height = 0
    for _, entry in ipairs(self.entries) do height = height + (entry.divider and self.GAP or self.options.step) end
    return height
end
function SearchList:Render()
    local p = self.props
    if not p then return end
    local offset = self.scroll:SetRange(#self.entries, p.rows)
    local y, used, rules = -self.first, 0, 0
    for i = offset + 1, math.min(#self.entries, offset + p.rows) do
        local entry = self.entries[i]
        if entry.divider then
            rules = rules + 1
            local rule = self.rules[rules]
            rule:ClearAllPoints()
            rule:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 12, y - math.floor(self.GAP / 2))
            rule:SetWidth(p.width - 8)
            rule:Show()
            y = y - self.GAP
        else
            used = used + 1
            local row = self.rows[used]
            row.entry = entry
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 8, y)
            self.options.fill(row, entry, p.width)
            row:Show()
            y = y - self.options.step
        end
    end
    for i = used + 1, #self.rows do self.rows[i].entry = nil; self.rows[i]:Hide() end
    for i = rules + 1, #self.rules do self.rules[i]:Hide() end
    if #self.entries == 0 and self.query ~= "" then self.empty:Show() else self.empty:Hide() end
end
local function rowNote(row)
    row.note = K.Label(row, "", 0, 0, 120, "secondary")
    row.note:ClearAllPoints(); row.note:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.note:SetJustifyH("RIGHT"); row.note:SetHeight(14)
    return row.note
end
local function placeNote(row, note, width, left)
    row:SetWidth(width)
    row.note:SetWidth(0)
    row.note:SetText(note or "")
    local room = note and math.min(math.ceil((row.note:GetStringWidth() or 0) + 2), math.floor(width / 2)) or 0
    row.note:SetWidth(math.max(1, room))
    row.text:SetWidth(width - left - 8 - (note and room + 6 or 0))
end
function K.Menu(parent, entries, choose)
    local menu = {}
    menu.frame = K.Button(parent, "", 184, function()
        if menu.cover:IsShown() then menu.cover:Hide() else menu.cover:Show() end
    end)
    K.Selector(menu.frame)
    menu.frame.text:SetJustifyH("LEFT")
    menu.frame.text:ClearAllPoints()
    menu.frame.text:SetPoint("LEFT", menu.frame, "LEFT", 8, 0)
    menu.frame.text:SetPoint("RIGHT", menu.frame, "RIGHT", -23, 0)
    menu.cover = ns.NewFrame("Button", nil, parent)
    menu.cover:SetAllPoints(parent)
    menu.cover:SetFrameLevel(parent:GetFrameLevel() + 50)
    menu.cover:SetScript("OnClick", function() menu.cover:Hide() end)
    menu.cover:Hide()
    parent:HookScript("OnHide", function() menu.cover:Hide() end)
    local panel = ns.NewFrame("Frame", nil, menu.cover)
    menu.panel = panel
    panel:SetPoint("TOPLEFT", menu.frame, "BOTTOMLEFT", 0, -2)
    panel:EnableMouse(true)
    K.Panel(panel)
    local function label(entry) return entry.label or ns.T(entry.labelKey) end
    menu.list = K.SearchList:New(panel, {step = 28, top = 8,
        make = function(owner, click)
            local button = K.Navigation(owner, "", click)
            rowNote(button)
            button.check = button:CreateTexture(nil, "ARTWORK")
            button.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            button.check:SetWidth(16); button.check:SetHeight(16)
            button.check:SetPoint("RIGHT", button, "RIGHT", -6, 0); button.check:Hide()
            button.lead = button:CreateTexture(nil, "ARTWORK")
            button.lead:SetWidth(18); button.lead:SetHeight(18)
            button.lead:SetPoint("LEFT", button, "LEFT", 6, 0); button.lead:Hide()
            button:SetScript("OnEnter", function(self)
                local tip = self.entry and self.entry.tip
                if not tip then return end
                K.TipOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(label(self.entry), unpack(K.theme.text))
                GameTooltip:AddLine(tip, K.theme.text[1], K.theme.text[2], K.theme.text[3], true)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return button
        end,
        fill = function(button, entry, width)
            if entry.icon then button.lead:SetTexture(entry.icon); button.lead:Show() else button.lead:Hide() end
            button.text:ClearAllPoints(); button.text:SetPoint("TOPLEFT", button, "TOPLEFT", entry.icon and 30 or 9, -7)
            button.text:SetText(label(entry))
            if entry.quality then button.text:SetTextColor(K.QualityColor(entry.quality))
            else button.text:SetTextColor(unpack(K.theme.text)) end
            placeNote(button, entry.note, width, 9)
            if entry.checked then button.check:Show() else button.check:Hide() end
            button.text:SetAlpha(entry.checked == false and 0.45 or 1)
            if entry.disabled then button:Disable() else button:Enable() end
        end,
        name = label,
        choose = function(entry)
            if not menu.keep then menu.cover:Hide() end
            choose(entry.key)
        end})
    menu.scroll = menu.list.scroll
    menu.buttons = menu.list.rows
    local function render()
        local groups, count, notes = {{}}, 0, false
        for _, entry in ipairs(menu.entries) do
            if entry.divider then groups[#groups + 1] = {}
            else
                count = count + 1
                local group = groups[#groups]
                group[#group + 1] = entry
                if entry.note then notes = true end
            end
        end
        local top, bottom = (menu.anchor or menu.frame):GetBottom(), parent:GetBottom()
        local room = top and bottom and (top - bottom - 26) or 280
        local slots, height, fit, fitHeight = count + #groups - 1, 0, 0, 0
        for i, group in ipairs(groups) do
            for _ in ipairs(group) do
                height = height + 28
                if height <= room then fit, fitHeight = fit + 1, height end
            end
            if i < #groups then
                height = height + K.SearchList.GAP
                if height <= room then fit, fitHeight = fit + 1, height end
            end
        end
        menu.visible = math.max(1, fit)
        local scrolling = slots > menu.visible
        local width = (notes and 274 or 194) + (scrolling and 20 or 0)
        menu.list:SetProps({groups = groups, rows = menu.visible, width = width - (scrolling and 20 or 0)})
        panel:SetWidth(width + 16)
        panel:SetHeight((scrolling and math.max(28, fitHeight) or menu.list:Height()) + 16)
    end
    menu.SetEntries = function(self, list)
        self.entries = list
        render()
    end
    menu.entries = entries
    menu.cover:HookScript("OnShow", render)
    menu.Layout = render
    render()
    return menu
end
local Picker = {}
Picker.__index = Picker
K.FamilyPicker = Picker
function Picker:New(parent, choose, search)
    local picker = setmetatable({choose = choose}, self)
    picker.frame = K.ItemChoice(parent, function()
        if picker.cover:IsShown() then picker.cover:Hide() else picker.cover:Show(); picker.list:Open(); picker:Render() end
    end)
    K.Selector(picker.frame)
    picker.frame.text:SetPoint("RIGHT", picker.frame, "RIGHT", -24, 0)
    picker.cover = ns.NewFrame("Button", nil, parent)
    picker.cover:SetAllPoints(parent)
    picker.cover:SetFrameLevel(parent:GetFrameLevel() + 15)
    picker.cover:SetScript("OnClick", function() picker.cover:Hide() end)
    picker.cover:Hide()
    parent:HookScript("OnHide", function() picker.cover:Hide() end)
    local menu = ns.NewFrame("Frame", nil, picker.cover)
    menu:SetPoint("TOPLEFT", picker.frame, "BOTTOMLEFT", 0, -2)
    menu:SetWidth(300); menu:SetHeight(search and 392 or 364)
    menu:EnableMouse(true)
    K.Panel(menu)
    picker.heading = K.Label(menu, "", 10, -10, 258, "heading")
    picker.list = K.SearchList:New(menu, {step = 27, top = 31, search = search,
        make = function(owner, click)
            local row = K.ItemChoice(owner, click)
            rowNote(row)
            return row
        end,
        fill = function(row, family, width)
            K.SetItemChoice(row, family.raw, family.raw == picker.props.raw)
            placeNote(row, family.note, width, 28)
        end,
        name = function(family) return ns.Markets.Name(family.raw) end,
        choose = function(family) picker.cover:Hide(); picker.choose(family.raw) end,
        close = function() picker.cover:Hide() end})
    picker.list:Ensure(12)
    picker.rows, picker.scroll = picker.list.rows, picker.list.scroll
    picker.cover:HookScript("OnHide", function() picker.list:Close() end)
    return picker
end
function Picker:SetProps(props)
    local moved = not self.props or self.props.raw ~= props.raw
    self.props = props
    if moved then self.reveal = true end
    self:Render()
end
function Picker:Groups()
    local p = self.props
    local order = ns.Collections and ns.Collections.Order or function(items) return items end
    local top = p.pinned and p.pinned() or {}
    if #top == 0 then return {order(p.families)} end
    local taken, rest = {}, {}
    for _, entry in ipairs(top) do taken[entry.raw] = true end
    for _, family in ipairs(p.families) do if not taken[family.raw] then rest[#rest + 1] = family end end
    return {order(top), order(rest)}
end
function Picker:Render()
    local props = self.props
    if not props then return end
    K.SetItemChoice(self.frame, props.raw, false)
    self.heading:SetText(ns.T(props.headingKey or "familyFamilies"))
    if not self.cover:IsShown() then return end
    local list = self.list
    list:SetProps({groups = self:Groups(), rows = 12, width = 264})
    if not self.reveal then return end
    self.reveal = false
    local index = list:Find(function(family) return family.raw == props.raw end)
    if index then list.scroll.offset = math.max(0, index - 6); list:Render() end
end
function K.Suggest(edit, fetch, choose, limit, empty)
    limit = limit or 8
    local box = ns.NewFrame("Frame", nil, edit:GetParent())
    box:SetFrameStrata("DIALOG")
    box:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -4, -2)
    K.Skin(box)
    box:SetBackdropColor(unpack(K.theme.card))
    box:SetBackdropBorderColor(unpack(K.theme.edge))
    box:EnableMouse(true)
    box.entries, box.rows, box.heads = {}, {}, {}
    for i = 1, 5 do
        local head = K.Label(box, "", 8, -4, 300, "secondary")
        head:SetHeight(16); head:Hide()
        box.heads[i] = head
    end
    box.hint = K.Label(box, empty or "", 8, -7, 300, "secondary")
    box.hint:SetHeight(14); box.hint:Hide()
    local function pick(index)
        local entry = box.entries[index]
        box:Hide()
        if entry then choose(entry) end
    end
    for i = 1, limit do
        local row = K.ItemChoice(box, function() pick(i) end)
        row:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4 - (i - 1) * 22)
        row:SetHeight(22)
        row.icon:SetWidth(18); row.icon:SetHeight(18)
        row.note = K.Label(row, "", 0, 0, 200, "secondary")
        row.note:SetHeight(14); row.note:SetJustifyH("RIGHT")
        row.note:ClearAllPoints(); row.note:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row:Hide()
        box.rows[i] = row
    end
    box.Render = function(self)
        local width = math.max(160, (edit:GetWidth() or 200) + 8)
        self:SetWidth(width)
        local y, group, heads = 4, nil, 0
        for _, head in ipairs(self.heads) do head:Hide() end
        for i, row in ipairs(self.rows) do
            local entry = self.entries[i]
            if entry then
                if entry.group and entry.group ~= group and heads < #self.heads then
                    heads, group = heads + 1, entry.group
                    local head = self.heads[heads]
                    head:ClearAllPoints(); head:SetPoint("TOPLEFT", self, "TOPLEFT", 8, -y)
                    head:SetWidth(width - 16); head:SetText(group); head:Show()
                    y = y + 18
                end
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -y)
                row:SetHeight(24)
                row.text:ClearAllPoints()
                if entry.id then
                    K.SetItemChoice(row, entry.id, i == rawget(self, "index"), entry.quality)
                    row.icon:Show()
                    row.text:SetPoint("LEFT", row, "LEFT", 28, 0)
                else
                    row.itemID, row.itemLink, row.spellID = nil, nil, nil
                    row.icon:Hide()
                    row.text:SetTextColor(unpack(K.theme.text))
                    row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
                    K.SetSelected(row, i == rawget(self, "index"))
                    row:Show()
                end
                row.text:SetText(entry.short or entry.name)
                row.extraTip = nil
                local note = entry.detail and math.min(280, width * 0.46) or 0
                row.note:SetWidth(math.max(1, note)); row.note:SetText(entry.detail or "")
                row:SetWidth(width - 8); row.text:SetWidth(width - (entry.id and 48 or 28) - note)
                y = y + 24
            else row:Hide() end
        end
        local none = rawget(self, "none") and empty ~= nil
        if none then self.hint:SetWidth(width - 16); self.hint:Show() else self.hint:Hide() end
        self:SetHeight(none and 28 or y + 4)
        if (#self.entries > 0 or none) and edit:HasFocus() then self:Show() else self:Hide() end
    end
    box.Update = function(self)
        local entries, short = fetch(edit:GetText() or "")
        self.entries, self.index = {}, nil
        local group
        for _, entry in ipairs(entries or {}) do
            if entry.kind == "head" then group = entry.name
            elseif #self.entries < limit then
                local copy = {}
                for key, value in pairs(entry) do copy[key] = value end
                copy.group = group
                self.entries[#self.entries + 1] = copy
            end
        end
        self.none = #self.entries == 0 and not short
        self:Render()
    end
    box.Move = function(self, delta)
        if #self.entries == 0 then return end
        self.index = ((rawget(self, "index") or (delta > 0 and 0 or 1)) + delta - 1) % #self.entries + 1
        self:Render()
    end
    box.Pick = function(self)
        local index = rawget(self, "index")
        if self:IsShown() and index then pick(index); return true end
        self:Hide()
        return false
    end
    edit:HookScript("OnTextChanged", function(_, user) if user then box:Update() end end)
    edit:HookScript("OnEditFocusLost", function()
        if not (MouseIsOver and MouseIsOver(box)) then box:Hide() end
    end)
    edit:HookScript("OnEscapePressed", function() box:Hide() end)
    edit:HookScript("OnTabPressed", function()
        if box:IsShown() then box:Move(IsShiftKeyDown() and -1 or 1) end
    end)
    edit:HookScript("OnHide", function() box:Hide() end)
    box:Hide()
    return box
end
