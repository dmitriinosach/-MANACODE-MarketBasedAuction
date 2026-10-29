local _, ns = ...
local K = ns.TradeKit
local Doc = {LIST = 176, PAD = 12, TOP = 40, STEP = 28, BAR = 26}
Doc.__index = Doc
K.Doc = Doc
local function height(fs, fallback)
    local h = fs:GetStringHeight()
    if not h or h < 1 then return fallback end
    return math.ceil(h)
end
function Doc:New(host, name, title)
    local doc = setmetatable({nav = {}, heads = {}, lines = {}, rows = {}}, self)
    local dim = K.Modal(host, name)
    doc.dim, doc.window = dim, dim.window
    local window = dim.window
    doc.heading = K.Label(window, title, Doc.PAD, -12, 400, "heading")
    doc.rule = K.Rule(window, 0)
    doc.rule:ClearAllPoints()
    doc.rule:SetPoint("TOPLEFT", window, "TOPLEFT", Doc.PAD + Doc.LIST + 6, -Doc.TOP)
    doc.rule:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", Doc.PAD + Doc.LIST + 6, Doc.PAD)
    doc.rule:SetWidth(1); doc.rule:SetHeight(0)
    doc.scroll = ns.NewFrame("ScrollFrame", name .. "Scroll", window, "UIPanelScrollFrameTemplate")
    doc.scroll.scrollBarHideable = 1
    doc.child = ns.NewFrame("Frame", nil, doc.scroll)
    doc.child:SetWidth(400); doc.child:SetHeight(300)
    doc.scroll:SetScrollChild(doc.child)
    doc.child:EnableMouseWheel(true)
    doc.child:SetScript("OnMouseWheel", function(_, delta)
        if ScrollFrameTemplate_OnMouseWheel then ScrollFrameTemplate_OnMouseWheel(doc.scroll, delta) end
    end)
    doc.title = K.Label(doc.child, "", 0, 0, 400, "title")
    dim:HookScript("OnShow", function() doc:Render() end)
    window:SetScript("OnSizeChanged", function() if dim:IsShown() then doc:Render() end end)
    return doc
end
function Doc:Ensure(article)
    local window, child = self.window, self.child
    for i = #self.nav + 1, #self.props.entries do
        local b = K.Navigation(window, "", function(button) self:Select(button.key) end)
        b:SetWidth(Doc.LIST); b.text:SetWidth(Doc.LIST - 14)
        b:SetPoint("TOPLEFT", window, "TOPLEFT", Doc.PAD, -Doc.TOP - (i - 1) * Doc.STEP)
        self.nav[i] = b
    end
    local heads, lines, rows = #article.sections, 0, 0
    for _, section in ipairs(article.sections) do
        lines, rows = lines + #section.lines, rows + #(section.rows or {})
    end
    for i = #self.heads + 1, heads do
        local fs = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetJustifyH("LEFT"); fs:SetTextColor(unpack(K.theme.accent))
        self.heads[i] = fs
    end
    for i = #self.lines + 1, lines do
        local line = {dot = child:CreateTexture(nil, "ARTWORK"),
            text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")}
        line.dot:SetTexture(K.theme.dot); line.dot:SetVertexColor(unpack(K.theme.accent))
        line.dot:SetWidth(4); line.dot:SetHeight(4)
        line.text:SetJustifyH("LEFT"); line.text:SetJustifyV("TOP"); line.text:SetTextColor(unpack(K.theme.text))
        self.lines[i] = line
    end
    for i = #self.rows + 1, rows do
        local row = {chip = K.Keycap(child), text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")}
        row.text:SetJustifyH("LEFT"); row.text:SetTextColor(unpack(K.theme.text))
        self.rows[i] = row
    end
end
function Doc:SetProps(props)
    self.props = props
    self:Render()
end
function Doc:Select(key)
    if not self.props then return end
    self.props.selected = key
    self:Render()
    self.scroll:SetVerticalScroll(0)
end
function Doc:Current()
    local p = self.props
    if not p or #p.entries == 0 then return nil end
    for _, entry in ipairs(p.entries) do if entry.key == p.selected then return entry.key end end
    return p.entries[1].key
end
function Doc:Place(article, width)
    local child = self.child
    self.title:ClearAllPoints(); self.title:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    self.title:SetWidth(width); self.title:SetText(article.title)
    local y = -height(self.title, 18) - 4
    local head, line, rowAt = 0, 0, 0
    for _, section in ipairs(article.sections) do
        head = head + 1
        local fs = self.heads[head]
        y = y - 10
        fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
        fs:SetWidth(width); fs:SetText(section.head); fs:Show()
        y = y - height(fs, 14) - 4
        for _, text in ipairs(section.lines) do
            line = line + 1
            local slot = self.lines[line]
            slot.dot:ClearAllPoints(); slot.dot:SetPoint("TOPLEFT", child, "TOPLEFT", 4, y - 5)
            slot.text:ClearAllPoints(); slot.text:SetPoint("TOPLEFT", child, "TOPLEFT", 14, y)
            slot.text:SetWidth(width - 14); slot.text:SetText(text)
            slot.dot:Show(); slot.text:Show()
            y = y - height(slot.text, 14) - 3
        end
        local rows, column = section.rows or {}, 0
        for i, row in ipairs(rows) do
            local slot = self.rows[rowAt + i]
            slot.chip.label:SetText(row.key)
            column = math.max(column, math.ceil((slot.chip.label:GetStringWidth() or 30) + 16), 44)
        end
        if #rows > 0 then y = y - 3 end
        for _, row in ipairs(rows) do
            rowAt = rowAt + 1
            local slot = self.rows[rowAt]
            slot.chip:ClearAllPoints(); slot.chip:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
            slot.chip:SetWidth(column); slot.chip:Show()
            slot.text:ClearAllPoints(); slot.text:SetPoint("TOPLEFT", child, "TOPLEFT", column + 8, y - 3)
            slot.text:SetWidth(width - column - 8); slot.text:SetText(row.text); slot.text:Show()
            y = y - math.max(22, height(slot.text, 14) + 8)
        end
    end
    for i = head + 1, #self.heads do self.heads[i]:Hide() end
    for i = line + 1, #self.lines do self.lines[i].dot:Hide(); self.lines[i].text:Hide() end
    for i = rowAt + 1, #self.rows do self.rows[i].chip:Hide(); self.rows[i].text:Hide() end
    return -y + 8
end
function Doc:Render()
    local p = self.props
    local key = self:Current()
    if not p or not key then return end
    local article = p.article(key)
    self:Ensure(article)
    for i, b in ipairs(self.nav) do
        local entry = p.entries[i]
        b.key = entry and entry.key or nil
        if entry then
            b.text:SetText(entry.label)
            if entry.key == key then b.selected:Show(); b.mark:Show() else b.selected:Hide(); b.mark:Hide() end
            b:Show()
        else b:Hide() end
    end
    local window, left = self.window, Doc.PAD + Doc.LIST + 18
    local width = (window:GetWidth() or 760) - left - Doc.PAD
    local room = (window:GetHeight() or 480) - Doc.TOP - Doc.PAD
    local tall = self:Place(article, width)
    local fits = room <= 0 or tall <= room
    if not fits then tall = self:Place(article, width - Doc.BAR) end
    self.scroll:ClearAllPoints()
    self.scroll:SetPoint("TOPLEFT", window, "TOPLEFT", left, -Doc.TOP)
    self.scroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -Doc.PAD - (fits and 0 or Doc.BAR), Doc.PAD)
    self.child:SetWidth(fits and width or width - Doc.BAR); self.child:SetHeight(math.max(tall, 1))
    K.PanelScrollBar(self.scroll, fits)
end
function Doc:Show()
    self.dim:Show()
    self:Render()
end
function Doc:Hide()
    self.dim:Hide()
end
function Doc:IsShown()
    return self.dim:IsShown() and true or false
end
