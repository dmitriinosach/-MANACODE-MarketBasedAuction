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
function K.Segment(parent, entries, choose, tip)
    local seg = {buttons = {}, order = {}}
    seg.frame = ns.NewFrame("Frame", nil, parent)
    seg.frame:SetHeight(22)
    seg.frame:SetBackdrop(K.theme.buttonSkin)
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
function K.Edit(parent, width, large)
    local edit = ns.NewFrame("EditBox", nil, parent)
    edit:SetWidth(width)
    edit:SetHeight(large and 26 or 22)
    edit:SetAutoFocus(false)
    edit:SetFontObject(large and "GameFontHighlight" or "GameFontHighlightSmall")
    edit:SetTextInsets(large and 8 or 6, large and 8 or 6, 0, 0)
    edit:SetBackdrop(K.theme.buttonSkin)
    edit:SetBackdropColor(unpack(K.theme.field))
    edit:SetBackdropBorderColor(unpack(K.theme.edge))
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local native = edit.SetScript
    edit.SetScript = function(self, name, fn)
        if name ~= "OnEditFocusGained" and name ~= "OnEditFocusLost" then native(self, name, fn); return end
        local color = name == "OnEditFocusGained" and K.theme.accent or K.theme.edge
        native(self, name, function(box, ...)
            box:SetBackdropBorderColor(unpack(color))
            if fn then fn(box, ...) end
        end)
    end
    edit:SetScript("OnEditFocusGained", nil)
    edit:SetScript("OnEditFocusLost", nil)
    return edit
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
function K.MoneyEdit(parent, apply)
    local view = setmetatable({edits = {}}, MoneyEdit)
    local f = ns.NewFrame("Frame", nil, parent)
    view.frame = f
    f:SetWidth(138); f:SetHeight(22)
    local x = 0
    for i, coin in ipairs({{40, "Interface\\MoneyFrame\\UI-GoldIcon"}, {24, "Interface\\MoneyFrame\\UI-SilverIcon"},
        {24, "Interface\\MoneyFrame\\UI-CopperIcon"}}) do
        local edit = K.Edit(f, coin[1])
        edit:SetTextInsets(4, 4, 0, 0); edit:SetJustifyH("RIGHT")
        edit:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
        K.LiveEdit(edit, function()
            local copper, ok = view:GetValue()
            if ok then apply(copper) end
        end)
        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(coin[2]); icon:SetWidth(12); icon:SetHeight(12)
        icon:SetPoint("LEFT", edit, "RIGHT", 2, 0)
        view.edits[i] = edit
        x = x + coin[1] + 18
    end
    for i, edit in ipairs(view.edits) do
        local nextEdit = view.edits[i % #view.edits + 1]
        edit:SetScript("OnTabPressed", function() nextEdit:SetFocus() end)
    end
    return view
end
function MoneyEdit:GetValue()
    local total, filled = 0, false
    for i, scale in ipairs({10000, 100, 1}) do
        local text = (self.edits[i]:GetText() or ""):match("^%s*(.-)%s*$")
        if text ~= "" then
            if not text:match("^%d+$") then return nil, false end
            total, filled = total + tonumber(text) * scale, true
        end
    end
    return filled and total or nil, true
end
function MoneyEdit:SetValue(copper)
    if self:HasFocus() then return end
    local rounded = copper and math.floor(copper + 0.5)
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
        if not value or not save(view.props.id, value * 10000) then ns.say(ns.T("alchemyInvalidPrice")); return end
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
    menu.cover:SetFrameLevel(parent:GetFrameLevel() + 20)
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
            button:SetScript("OnEnter", function(self)
                local tip = self.entry and self.entry.tip
                if not tip then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(label(self.entry), unpack(K.theme.text))
                GameTooltip:AddLine(tip, K.theme.text[1], K.theme.text[2], K.theme.text[3], true)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return button
        end,
        fill = function(button, entry, width)
            button.text:SetText(label(entry))
            placeNote(button, entry.note, width, 9)
            if entry.disabled then button:Disable() else button:Enable() end
        end,
        name = label,
        choose = function(entry) menu.cover:Hide(); choose(entry.key) end})
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
        local room = top and bottom and math.floor((top - bottom - 26) / 28) or 10
        local slots = count + #groups - 1
        menu.visible = math.max(1, math.min(slots, room))
        local scrolling = slots > menu.visible
        local width = (notes and 274 or 194) + (scrolling and 20 or 0)
        menu.list:SetProps({groups = groups, rows = menu.visible, width = width - (scrolling and 20 or 0)})
        panel:SetWidth(width + 16)
        panel:SetHeight((scrolling and menu.visible * 28 or menu.list:Height()) + 16)
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
    box:SetBackdrop(K.theme.buttonSkin)
    box:SetBackdropColor(unpack(K.theme.card))
    box:SetBackdropBorderColor(unpack(K.theme.edge))
    box:EnableMouse(true)
    box.entries, box.rows = {}, {}
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
        row:Hide()
        box.rows[i] = row
    end
    box.Render = function(self)
        local width = math.max(160, (edit:GetWidth() or 200) + 8)
        self:SetWidth(width)
        for i, row in ipairs(self.rows) do
            local entry = self.entries[i]
            if entry then
                K.SetItemChoice(row, entry.id, i == rawget(self, "index"), entry.quality)
                row.text:SetText(entry.name)
                row:SetWidth(width - 8); row.text:SetWidth(width - 40)
            else row:Hide() end
        end
        local none = rawget(self, "none") and empty ~= nil
        if none then self.hint:SetWidth(width - 16); self.hint:Show() else self.hint:Hide() end
        self:SetHeight(none and 28 or #self.entries * 22 + 8)
        if (#self.entries > 0 or none) and edit:HasFocus() then self:Show() else self:Hide() end
    end
    box.Update = function(self)
        local entries, short = fetch(edit:GetText() or "")
        self.entries, self.index = entries or {}, nil
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
    box:Hide()
    return box
end
