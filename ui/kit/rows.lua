local _, ns = ...
local K = ns.TradeKit
local GROUP_ICON = 20
function K.RowStripe(row, parent, counter, match)
    row.frame.selected:SetDrawLayer("BORDER")
    local mark = row.frame.mark
    mark:ClearAllPoints()
    mark:SetPoint("TOPRIGHT", row.frame, "TOPLEFT", -2, 0)
    mark:SetPoint("BOTTOMRIGHT", row.frame, "BOTTOMLEFT", -2, 0)
    parent[counter] = (rawget(parent, counter) or 0) + 1
    row.stripe = row.frame:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints(row.frame); row.stripe:SetTexture(K.theme.white)
    row.stripe:SetVertexColor(unpack(K.theme.row))
    if parent[counter] % 2 == 0 then row.stripe:Hide() end
    if match then K.MatchMark(row) end
end
function K.MatchMark(row)
    row.match = row.frame:CreateTexture(nil, "BACKGROUND")
    row.match:SetAllPoints(row.frame); row.match:SetTexture(K.theme.white)
    row.match:SetVertexColor(unpack(K.theme.match)); row.match:Hide()
    row.matchBar = row.frame:CreateTexture(nil, "BORDER")
    row.matchBar:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
    row.matchBar:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", 0, 0)
    row.matchBar:SetWidth(4); row.matchBar:SetTexture(K.theme.white)
    row.matchBar:SetVertexColor(unpack(K.theme.positive)); row.matchBar:Hide()
end
function K.LineRow(row, parent, click, counter, match)
    row.frame = K.ItemChoice(parent, click)
    row.frame:SetHeight(24)
    K.RowStripe(row, parent, counter, match)
    row.frame.icon:ClearAllPoints(); row.frame.icon:SetPoint("LEFT", row.frame, "LEFT", 8, 0)
    row.frame.icon:SetWidth(18); row.frame.icon:SetHeight(18)
    row.frame.text:ClearAllPoints(); row.frame.text:SetPoint("LEFT", row.frame, "LEFT", 32, 0)
    K.SetFontHeight(row.frame.text, 12)
end
function K.NestLine(row, nested)
    local icon, text = 8, 32
    if row.props and row.props.iconX then icon, text = row.props.iconX, row.props.iconX + 24
    elseif nested then icon, text = K.NEST_ICON, K.NEST_TEXT end
    row.frame.icon:ClearAllPoints(); row.frame.icon:SetPoint("LEFT", row.frame, "LEFT", icon, 0)
    row.frame.text:ClearAllPoints(); row.frame.text:SetPoint("LEFT", row.frame, "LEFT", text, 0)
    row.frame.textLeft = text
end
function K.RowCell(row, key)
    local cell = row.cells[key]
    if not cell then
        cell = K.Label(row.frame, "", 0, -6, 80)
        K.SetFontHeight(cell, 12); cell:SetJustifyH("RIGHT")
        row.cells[key] = cell
    end
    return cell
end
function K.PlaceCells(row, columns)
    for key, cell in pairs(row.cells) do
        local column = columns[key]
        cell:ClearAllPoints()
        if column then
            cell:SetPoint("LEFT", row.frame, "LEFT", column[1], 0)
            cell:SetWidth(column[2] - 6); cell:Show()
        else cell:Hide() end
    end
end
function K.MoreCells(row, columns, p)
    if not (columns.have or columns.gone) then return end
    local id = type(p.id) == "number" and not p.spell and p.id or nil
    if columns.have then
        local have = p.have
        if have == nil and id then
            local here, alts = ns.Inventory.Stock(id)
            have = here + alts
        end
        K.RowCell(row, "have"):SetText(have and have > 0 and tostring(have) or "")
    end
    if columns.gone then
        local gone = p.gone
        if gone == nil and id then gone = ns.Selling.Gone(id) end
        K.RowCell(row, "gone"):SetText(gone and tostring(gone) or "")
    end
end
function K.FillCells(row, columns, cells)
    for key, cell in pairs(row.cells) do if not columns[key] or not cells[key] then cell:Hide() end end
    for key, value in pairs(cells) do
        local column = columns[key]
        if column then
            local cell = K.RowCell(row, key)
            cell:ClearAllPoints(); cell:SetPoint("LEFT", row.frame, "LEFT", column[1], 0)
            cell:SetWidth(column[2] - 6)
            cell:SetText(value[1] or "")
            cell:SetTextColor(unpack(K.theme[value[2] or "text"]))
            cell:Show()
        end
    end
end
function K.ActionButtons(row, count, field, width, first)
    for i = 1, count do
        local button = K.Button(row.frame, "", width, function()
            local p = row.props
            local actions = row.actions or (p and p.actions)
            local action = actions and actions[i]
            if action then action.fn(p[field], p) end
        end, "quiet")
        button:SetHeight(20); button:Hide()
        row.buttons[i] = button
    end
    for i = 1, count do
        local neighbour = row.buttons[first and i - 1 or i + 1]
        if neighbour then row.buttons[i]:SetPoint("RIGHT", neighbour, "LEFT", -3, 0)
        else row.buttons[i]:SetPoint("RIGHT", row.frame, "RIGHT", -4, 0) end
    end
end
function K.PlaceHeaders(headers, columns, anchor, y, inset, left)
    for key, label in pairs(headers) do
        local column = columns[key]
        label:ClearAllPoints()
        if column then
            label:SetPoint("TOPLEFT", anchor, "TOPLEFT", (left or 10) + column[1] + (inset and key == "item" and 6 or 0), y)
            label:SetWidth(column[2] - 6); label:Show()
        else label:Hide() end
    end
end
function K.HeaderBand(parent)
    local band = parent:CreateTexture(nil, "BACKGROUND")
    band:SetTexture(K.theme.white); band:SetVertexColor(unpack(K.theme.head))
    band:SetAllPoints(parent)
    local line = parent:CreateTexture(nil, "BORDER")
    line:SetTexture(K.theme.white); line:SetVertexColor(unpack(K.theme.edge))
    line:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0); line:SetHeight(1)
    return band
end
local Sorter = {}
Sorter.__index = Sorter
function K.Sorter(frame, headers, changed, active, default)
    local sorter = setmetatable({buttons = {}, headers = headers, changed = changed, active = active, default = default}, Sorter)
    for key, label in pairs(headers) do
        local button = ns.NewFrame("Button", nil, frame)
        button:SetAllPoints(label)
        button:EnableMouse(true)
        button.arrow = button:CreateTexture(nil, "OVERLAY")
        button.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
        button.arrow:SetWidth(9); button.arrow:SetHeight(9); button.arrow:Hide()
        button:SetScript("OnClick", function() sorter:Click(key) end)
        K.SortTip(button)
        sorter.buttons[key] = button
    end
    return sorter
end
function Sorter:Click(key)
    local current = self.sort or self.default
    if current and current.key == key then
        if current.desc == (key ~= "item") then self.sort = {key = key, desc = not current.desc}
        else self.sort = nil end
    else self.sort = {key = key, desc = key ~= "item"} end
    self.changed()
end
function Sorter:Mark()
    local usable = not self.active or self.active()
    local chosen = self.sort and self.headers[self.sort.key]
    if chosen and not chosen:IsShown() then self.sort = nil end
    for key, button in pairs(self.buttons) do
        local label = self.headers[key]
        if usable and label:IsShown() then button:Show() else button:Hide() end
        local current = self.sort or self.default
        button.arrow:ClearAllPoints()
        if usable and current and current.key == key then
            local width = (label.GetStringWidth and label:GetStringWidth()) or 40
            if key == "item" then button.arrow:SetPoint("LEFT", button, "LEFT", width + 4, 0)
            else button.arrow:SetPoint("RIGHT", button, "RIGHT", -(width + 4), 0) end
            if current.desc then button.arrow:SetTexCoord(0, 0.5625, 0, 1) else button.arrow:SetTexCoord(0, 0.5625, 1, 0) end
            button.arrow:Show()
        else button.arrow:Hide() end
    end
end
function Sorter:Apply(entries, getters, group)
    local current = self.sort or self.default
    local label = current and self.headers[current.key]
    if label and not label:IsShown() then current = {key = "item", desc = false} end
    local get = current and getters[current.key]
    if not get then return entries end
    local keyed = {}
    for i, entry in ipairs(entries) do keyed[i] = {entry = entry, value = get(entry), index = i, first = group and group(entry) or false} end
    table.sort(keyed, function(a, b)
        if a.first ~= b.first then return a.first end
        if a.value ~= b.value then
            if a.value == nil then return false end
            if b.value == nil then return true end
            if current.desc then return a.value > b.value end
            return a.value < b.value
        end
        return a.index < b.index
    end)
    local result = {}
    for i, item in ipairs(keyed) do result[i] = item.entry end
    return result
end
local MarketRow = {}
MarketRow.__index = MarketRow
K.MarketRow = MarketRow
function MarketRow:New(parent, selectRow, toggleMaterial, toggleHide, openRow)
    local row = setmetatable({}, self)
    row.frame = K.ItemChoice(parent, function() selectRow(row.props.id, row.props) end)
    K.RowStripe(row, parent, "marketRowCount", true)
    row.frame:SetHeight(30)
    row.frame.text:SetWidth(205)
    row.price = K.Label(row.frame, "", 240, -3, 120)
    row.margin = K.Label(row.frame, "", 365, -3, 120)
    row.marginRate = K.Label(row.frame, "", 0, 0, 118)
    row.marginRate:SetTextColor(unpack(K.theme.secondary))
    row.units = K.Label(row.frame, "", 490, -3, 50)
    row.cells = {price = row.price, margin = row.margin, units = row.units}
    for _, cell in pairs(row.cells) do K.SetFontHeight(cell, 12) end
    row.tag = K.Label(row.frame, "", 0, -3, K.ITEM_TAG)
    K.SetFontHeight(row.tag, 12); row.tag:SetJustifyH("RIGHT"); row.tag:Hide()
    row.detail = K.Label(row.frame, "", 28, -17, 440)
    row.detail:ClearAllPoints()
    row.detail:SetPoint("TOPLEFT", row.frame.text, "BOTTOMLEFT", 0, 0)
    K.SetFontHeight(row.detail, 12)
    row.cross = K.Unlearned(row.frame, 12)
    row.cross:SetPoint("BOTTOMRIGHT", row.frame.icon, "BOTTOMRIGHT", 3, -2)
    row.frame.text:ClearAllPoints()
    row.frame.text:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 28, -2)
    K.SetFontHeight(row.frame.text, 12)
    row.refresh = K.IconButton(row.frame, "refresh", function()
        if row.props.action then row.props.action(row.props.id) else ns.Markets.Scan(row.props.id) end
    end, ns.T("cacheRefreshItem"), ns.T("cacheRefreshTip"))
    if toggleHide then
        row.hide = K.Button(row.frame, ns.T("hiddenHide"), 66, function() toggleHide(row.props.id, row.props) end, "quiet")
        row.hide:SetHeight(20)
    end
    if openRow then
        row.go = K.IconButton(row.frame, "go", function() openRow(row.props.id, row.props) end, "", "")
    end
    if toggleMaterial then
        row.expand = K.ExpandButton(row.frame, function() toggleMaterial(row.props.id, row.props) end)
        K.Tooltip(row.expand, ns.T("craftMaterialSource"), ns.T("craftTreeTip"))
    end
    row.buttons = {row.refresh}
    row.actions = {{icon = "refresh"}}
    if row.go then row.buttons[#row.buttons + 1] = row.go end
    if row.go then row.actions[#row.actions + 1] = {icon = "go"} end
    if row.hide then
        row.buttons[#row.buttons + 1] = row.hide
        row.actions[#row.actions + 1] = {icon = "hide"}
    end
    return row
end
function MarketRow:Reserve(wide, noGo)
    local actions = {{icon = "refresh"}}
    if self.go and not noGo then actions[#actions + 1] = {icon = "go"} end
    if self.hide then actions[#actions + 1] = {icon = not wide and "hide" or nil, width = 66} end
    return K.ActionReserve(actions)
end
function MarketRow:Reveal()
    if self.refreshWanted then self.refresh:Show() else self.refresh:Hide() end
    if self.hide then
        if self.hideWanted then self.hide:Show() else self.hide:Hide() end
    end
    if self.go then
        if self.props.go then self.go:Show() else self.go:Hide() end
    end
end
function MarketRow:SetProps(props)
    self.props = props
    self:Render()
end
function MarketRow:Render()
    local p = self.props
    self.frame.extraTip = p.extraTip
    self.frame.tipKeys = p.keys and function() return {body = p.extraTip, keys = p.keys} end or nil
    if p.spell then K.SetSpellChoice(self.frame, p.spell, p.active)
    else K.SetItemChoice(self.frame, p.id, p.active, p.quality) end
    local columns = p.width and (p.columns or K.MarketColumns(p.width - self:Reserve(p.wide, p.noGo), p.more))
    self.buttons, self.actions = {self.refresh}, {{icon = "refresh"}}
    if self.go and not p.noGo then
        self.buttons[#self.buttons + 1] = self.go
        self.actions[#self.actions + 1] = {icon = "go"}
    end
    if self.hide then
        self.buttons[#self.buttons + 1] = self.hide
        self.actions[#self.actions + 1] = {icon = not p.hideLabel and "hide" or nil, width = 66}
        if p.hideable then
            if p.hideLabel then
                K.SetGlyph(self.hide, nil); self.hide:SetText(p.hideLabel); self.hide:SetWidth(66)
            else K.SetGlyph(self.hide, "hide") end
            K.Tooltip(self.hide, p.hideLabel or ns.T("hiddenHide"), ns.T(p.hidden and "hiddenRestoreTip" or "hiddenHideTip"))
            self.hideWanted = true
        else self.hideWanted = false end
    end
    if p.match then self.match:Show(); self.matchBar:Show() else self.match:Hide(); self.matchBar:Hide() end
    if p.width then
        self.frame:SetWidth(p.width)
        self.frame.text:SetWidth(columns.item[2] - 34)
        self.detail:SetWidth(columns.item[2] - 34)
        K.MoreCells(self, columns, p)
        K.PlaceCells(self, columns)
        for _, cell in pairs(self.cells) do cell:SetJustifyH("RIGHT") end
    end
    if p.iconX then
        local text = p.iconX + 26
        self.frame.icon:ClearAllPoints(); self.frame.icon:SetPoint("LEFT", self.frame, "LEFT", p.iconX, 0)
        self.frame.text:ClearAllPoints(); self.frame.text:SetPoint("TOPLEFT", self.frame, "TOPLEFT", text, -3)
        self.detail:ClearAllPoints(); self.detail:SetPoint("TOPLEFT", self.frame, "TOPLEFT", text, -15)
        if columns then
            local room = math.max(24, columns.item[2] - text - 6)
            self.frame.text:SetWidth(room); self.detail:SetWidth(room)
        end
        if self.expand then
            if p.expandTip then K.Tooltip(self.expand, p.expandTitle, p.expandTip) end
            self.expand:ClearAllPoints(); self.expand:SetPoint("LEFT", self.frame, "LEFT", p.toggleX, 0)
            self.expand:SetText(p.crafted and "-" or "+")
            if p.expandable then self.expand:Show() else self.expand:Hide() end
        end
    else
        if not self.expand then
            local icon, text = 2, 28
            if p.nested then icon, text = K.NEST_ICON, K.NEST_TEXT end
            self.frame.icon:ClearAllPoints(); self.frame.icon:SetPoint("LEFT", self.frame, "LEFT", icon, 0)
            self.frame.text:ClearAllPoints(); self.frame.text:SetPoint("TOPLEFT", self.frame, "TOPLEFT", text, -2)
            self.detail:ClearAllPoints(); self.detail:SetPoint("TOPLEFT", self.frame, "TOPLEFT", text, -14)
            if columns then
                self.frame.text:SetWidth(math.max(24, columns.item[2] - text - 6))
                self.detail:SetWidth(math.max(24, columns.item[2] - text - 6))
            end
        end
        if self.expand then
            local offset = p.depth ~= nil and (34 + p.depth * 12) or 0
            self.frame.icon:ClearAllPoints(); self.frame.icon:SetPoint("LEFT", self.frame, "LEFT", offset + 2, 0)
            self.frame.text:ClearAllPoints(); self.frame.text:SetPoint("TOPLEFT", self.frame, "TOPLEFT", offset + 28, -2)
            self.detail:ClearAllPoints(); self.detail:SetPoint("TOPLEFT", self.frame, "TOPLEFT", offset + 28, -14)
            self.frame.text:SetWidth(math.max(24, columns.item[2] - offset - 34))
            self.detail:SetWidth(math.max(24, columns.item[2] - offset - 34))
            self.expand:ClearAllPoints(); self.expand:SetPoint("LEFT", self.frame, "LEFT", math.max(0, offset - 16), 0)
            self.expand:SetText(p.crafted and "-" or "+")
            if p.expandable then self.expand:Show() else self.expand:Hide() end
        end
    end
    if p.tag and columns then
        self.tag:ClearAllPoints()
        self.tag:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", columns.item[2] - 6, -2)
        self.tag:SetText(p.tag); self.tag:SetTextColor(unpack(K.theme.accent)); self.tag:Show()
        self.frame.text:SetWidth(math.max(40, (self.frame.text:GetWidth() or columns.item[2]) - K.ITEM_TAG))
    else self.tag:Hide() end
    self.price:SetText(K.Money(p.quote and p.quote.price))
    self.margin:SetText(p.marginText or K.Money(p.margin))
    if p.percent then
        self.margin:ClearAllPoints()
        self.margin:SetPoint("TOPRIGHT", self.marginRate, "TOPRIGHT", 0, 13)
        self.marginRate:ClearAllPoints()
        self.marginRate:SetPoint("TOPLEFT", self.frame, "TOPLEFT", columns.margin[1], -15)
        self.marginRate:SetWidth(columns.margin[2] - 6)
        self.marginRate:SetJustifyH("RIGHT"); self.marginRate:SetText(ns.T("deMarginRate", K.Decimal(p.percent, 1, true))); self.marginRate:Show()
    else self.marginRate:Hide() end
    self.margin:SetTextColor(unpack(K.theme[p.tone or K.Tone(p.margin)]))
    self.units:SetText(p.quote and tostring(p.quote.units) or ns.T("tradeNoPrice"))
    self.detail:SetText((p.detail or "") .. (p.quote and (p.quote.miss or 0) > 0 and ns.T("cacheIncomplete") or ""))
    self.detail:SetTextColor(unpack(K.theme.secondary))
    self.refreshWanted = not (p.noRefresh or (p.quote and p.quote.vendor))
    K.PlaceActions(self)
    self:Reveal()
    if self.go and p.go then
        K.Tooltip(self.go, p.go.title, p.go.tip)
        local glyph = p.go.icon and {p.go.icon, bare = true} or "go"
        if rawget(self, "goGlyph") ~= p.go.icon then self.goGlyph = p.go.icon; K.SetGlyph(self.go, glyph) end
    end
    if p.actionDisabled then self.refresh:Disable() else self.refresh:Enable() end
    if p.actionTip then K.Tooltip(self.refresh, p.actionLabel, p.actionTip) end
    if p.unlearned then
        if p.iconX then
            self.cross:ClearAllPoints(); self.cross:SetPoint("LEFT", self.frame, "LEFT", math.max(0, p.iconX - K.CROSS), 0)
        end
        self.cross:Show()
    else self.cross:Hide() end
end
local SellerRow = setmetatable({}, {__index = MarketRow})
SellerRow.__index = SellerRow
K.SellerRow = SellerRow
function SellerRow:New(parent, selectRow, toggleHide, openSeller)
    local row = MarketRow.New(self, parent, selectRow, nil, toggleHide)
    row.seller = K.TextLink(row.frame, function() openSeller(row.props.vendor) end)
    row.seller.tipFn = function() return row.props.sellerTip() end
    row.cost = K.Cost(row.frame, row.frame)
    K.RowCell(row, "affordable")
    return row
end
function SellerRow:SetProps(props)
    self.props = props; self:Render()
end
function SellerRow:Render()
    MarketRow.Render(self)
    local p, columns = self.props, self.props.columns
    local column = columns.seller
    if column and p.vendor then
        self.seller:ClearAllPoints(); self.seller:SetPoint("LEFT", self.frame, "LEFT", column[1], 0)
        K.SetTextLink(self.seller, column[2] - 6, p.sellerName, p.sellerZone)
        K.Tooltip(self.seller, p.sellerName, "")
    else self.seller:Hide() end
    column = columns.cost
    if column then
        self.cost:ClearAllPoints()
        self.cost:SetPoint("RIGHT", self.frame, "LEFT", column[1] + column[2] - 6, 0)
        K.SetCost(self.cost, p.costLines, p.costMoney)
    else self.cost:Hide() end
    self.cells.affordable:SetText(p.affordable and tostring(p.affordable) or ns.T("costUnknownShort"))
end
K.DIVIDER_GAP = 5
function K.Details(parts)
    return table.concat(parts, "     ")
end
K.NEST_ICON, K.NEST_TEXT = 28, 54
local GroupRow = {}
GroupRow.__index = GroupRow
K.GroupRow = GroupRow
function GroupRow:New(parent, toggle, changed)
    local row = setmetatable({cells = {}, changed = changed}, self)
    row.frame = ns.NewFrame("Button", nil, parent)
    row.frame:SetHeight(30)
    row.back = row.frame:CreateTexture(nil, "BACKGROUND")
    row.back:SetAllPoints(row.frame); row.back:SetTexture(K.theme.white)
    row.back:SetVertexColor(unpack(K.theme.group))
    local hover = row.frame:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(row.frame); K.Highlight(hover, "hover"); row.frame:SetHighlightTexture(hover)
    row.caret = K.Label(row.frame, "", 4, -6, 12, "secondary")
    row.caret:ClearAllPoints(); row.caret:SetPoint("LEFT", row.frame, "LEFT", 4, 0)
    row.icon = row.frame:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(GROUP_ICON); row.icon:SetHeight(GROUP_ICON)
    row.icon:SetPoint("LEFT", row.frame, "LEFT", 16, 0)
    row.icon:Hide()
    row.name = K.Label(row.frame, "", 16, -6, 200)
    K.SetFontHeight(row.name, 12)
    row.name:ClearAllPoints(); row.name:SetPoint("LEFT", row.frame, "LEFT", 16, 0)
    row.detail = K.Label(row.frame, "", 0, -6, 300, "secondary")
    K.SetFontHeight(row.detail, 12)
    row.detail:ClearAllPoints(); row.detail:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    row.tag = K.Label(row.frame, "", 0, -6, 180, "secondary")
    K.SetFontHeight(row.tag, 12); row.tag:SetJustifyH("RIGHT")
    row.tag:ClearAllPoints(); row.tag:SetPoint("RIGHT", row.frame, "RIGHT", -8, 0)
    if toggle then
        row.frame:SetScript("OnClick", function() toggle(row.props.key) end)
        row.frame.onClick = function() toggle(row.props.key) end
    else
        row.frame:EnableMouse(false)
        row.caret:Hide()
    end
    row.chips = K.Cost(row.frame, row.frame)
    row.chips:Hide()
    row.buttons = {}
    K.ActionButtons(row, 4, "key", 60)
    return row
end
local function groupActions(p, changed)
    local function done() if changed then changed() end end
    if p.hidden and p.hideKey then
        return {{label = ns.T("hiddenRestore"), width = 64, tip = ns.T("groupRestoreTip"),
            fn = function() ns.Hidden.SetGroup(p.hideKey, false); done() end}}
    end
    local actions = {}
    for _, action in ipairs(p.actions or {}) do actions[#actions + 1] = action end
    if p.sources then
        local busy = ns.Scan.state.phase ~= "idle" or ns.Buy.Active()
        actions[#actions + 1] = {label = ns.T("craftScanGroup"), icon = "refresh", disabled = busy,
            tip = p.scanTip or ns.T("groupScanTip"), sources = p.sources,
            fn = function()
                ns.Batch.Complete(p.sources(), K.ScanMode(), true)
                done()
            end}
    end
    if p.hideKey then
        actions[#actions + 1] = {label = ns.T("groupHide"), icon = "hide", tip = ns.T("groupHideTip"),
            fn = function() ns.Hidden.SetGroup(p.hideKey, true); done() end}
    end
    return actions
end
local function summaryEdge(p, right)
    for key, value in pairs(p.cells or {}) do
        local column = p.columns and p.columns[key]
        if column and value[1] and value[1] ~= "" then right = math.min(right, column[1]) end
    end
    return right
end
function GroupRow:SetProps(props)
    self.props = props; self:Render()
end
function GroupRow:Render()
    local p = self.props
    self.frame:SetWidth(p.width)
    if p.height then self.frame:SetHeight(p.height) end
    self.back:SetVertexColor(unpack(K.theme[p.sub and "subgroup" or "group"]))
    self.actions = groupActions(p, self.changed)
    local reserve = K.ActionReserve(self.actions)
    local nest = p.indent or (p.sub and K.NEST_ICON - 16 or 0)
    local left = (p.iconX and p.icon and 26 or 16) + nest
    self.caret:ClearAllPoints(); self.caret:SetPoint("LEFT", self.frame, "LEFT", p.toggleX or 4 + nest, 0)
    self.icon:ClearAllPoints(); self.icon:SetPoint("LEFT", self.frame, "LEFT", left, 0)
    if p.icon then
        self.icon:SetTexture(p.icon); self.icon:Show()
        left = left + GROUP_ICON + 6
    else self.icon:Hide() end
    K.FillCells(self, p.columns or {}, p.cells or {})
    local tag = p.tag or ""
    local right = summaryEdge(p, p.width - reserve - (tag ~= "" and 180 or 0)) - 8
    local inline = 0
    if p.chips and #p.chips > 0 then
        local size = K.SetCost(self.chips, p.chips)
        local column = p.columns and p.columns[p.chipsAt or "cost"]
        self.chips:ClearAllPoints()
        if column then
            local edge = column[1] + column[2] - 6
            self.chips:SetPoint("RIGHT", self.frame, "LEFT", edge, 0)
            right = math.min(right, edge - size - 8)
        else inline = size + 6 end
    else self.chips:Hide() end
    self.caret:SetText(p.open and "-" or "+")
    self.name:ClearAllPoints(); self.name:SetPoint("LEFT", self.frame, "LEFT", left, 0)
    self.name:SetWidth(300)
    self.name:SetText(p.name)
    local name = math.min(240, math.max(40, (self.name:GetStringWidth() or 120) + 4), math.max(40, right - left - inline))
    self.name:SetWidth(name)
    local after = self.name
    if inline > 0 then
        self.chips:SetPoint("LEFT", self.name, "RIGHT", 6, 0)
        after = self.chips
    end
    local detail = p.detail or ""
    if p.hidden then detail = ns.T("craftHiddenGroup", detail) end
    self.detail:ClearAllPoints()
    if p.below and detail ~= "" then
        self.name:ClearAllPoints(); self.name:SetPoint("LEFT", self.frame, "LEFT", left, 7)
        self.detail:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -2)
        self.detail:SetWidth(math.max(20, right - left))
    else
        self.detail:SetPoint("LEFT", after, "RIGHT", 6, 0)
        self.detail:SetWidth(math.max(20, right - left - name - 6 - inline))
    end
    self.detail:SetText(detail)
    self.tag:ClearAllPoints(); self.tag:SetPoint("RIGHT", self.frame, "RIGHT", -reserve, 0)
    self.tag:SetText(tag)
    self.tag:SetTextColor(unpack(K.theme[p.tone or "secondary"]))
    K.Tooltip(self.frame, p.name or "", p.tip or "")
    K.PlaceActions(self)
    K.RevealActions(self)
    self.frame:Show()
end
local DRow = {}
DRow.__index = DRow
K.DisenchantRow = DRow
function DRow:New(parent, select, buy, refresh, expand)
    local row = setmetatable({}, self)
    K.LineRow(row, parent, function() select(row.props.id, row.props) end, "disenchantRowCount", true)
    row.cells = {}
    for _, key in ipairs({"ilvl", "price", "bid", "margin", "rate", "via", "viaRate"}) do
        local cell = K.Label(row.frame, "", 0, -6, 80, (key == "ilvl" or key == "rate") and "secondary" or nil)
        K.SetFontHeight(cell, 12); cell:SetJustifyH("RIGHT")
        row.cells[key] = cell
    end
    row.tag = K.Label(row.frame, "", 0, -6, K.ITEM_TAG)
    K.SetFontHeight(row.tag, 12); row.tag:SetJustifyH("RIGHT"); row.tag:Hide()
    if buy then
        row.buy = K.IconButton(row.frame, "buy", function() buy(row.props.id) end, ns.T("deBuyRow"), ns.T("deBuyRowTip"))
        row.buy:SetPoint("RIGHT", row.frame, "RIGHT", -4, 0)
    end
    if refresh then
        row.refresh = K.IconButton(row.frame, "refresh", function() refresh(row.props.id) end,
            ns.T("cacheComplete"), ns.T("deRefreshRowTip"))
        row.refresh.tipKeys = function() return {body = ns.T("deRefreshRowTip"), keys = K.ScanKeys()} end
        if row.buy then row.refresh:SetPoint("RIGHT", row.buy, "LEFT", -3, 0)
        else row.refresh:SetPoint("RIGHT", row.frame, "RIGHT", -4, 0) end
    end
    if expand then
        row.expand = K.ExpandButton(row.frame, function() expand(row.props.id, row.props) end)
        row.expand:Hide()
    end
    return row
end
function DRow:Reveal()
    if self.buy then
        if self.props.action ~= false then self.buy:Show() else self.buy:Hide() end
    end
    if self.refresh then self.refresh:Show() end
end
function DRow:SetProps(props)
    self.props = props; self:Render()
end
function DRow:FillCustom(cells)
    for key, cell in pairs(self.cells) do
        local value = cells[key]
        cell:SetText(value and value[1] or "")
        cell:SetTextColor(unpack(K.theme[value and value[2] or "text"]))
    end
    self.custom = true
end
function DRow:Render()
    local p = self.props
    local columns = p.columns or K.DisenchantColumns(p.width, p.target, self.refresh ~= nil, p.bids)
    self.frame:SetWidth(p.width)
    K.SetItemChoice(self.frame, p.id, p.active, p.quality)
    self.frame.extraTip = p.tip
    K.NestLine(self, true)
    if self.expand then
        self.expand:ClearAllPoints(); self.expand:SetPoint("LEFT", self.frame, "LEFT", p.toggleX or 4, 0)
        self.expand:SetText(p.opened and "-" or "+")
        if p.expandable then self.expand:Show() else self.expand:Hide() end
    end
    K.ItemTag(self.frame, self.tag, columns.item, p.tag, p.tagTone)
    K.PlaceCells(self, columns)
    self.cells.ilvl:SetText(p.level and tostring(p.level) or "")
    self.cells.price:SetText(K.Money(p.cost))
    self.cells.bid:SetText(p.bid and K.Money(p.bid) or "")
    self.cells.bid:SetTextColor(unpack(K.theme[p.bidProfit and "positive" or "secondary"]))
    self.cells.margin:SetText(K.Money(p.margin))
    self.cells.margin:SetTextColor(unpack(K.theme[K.Tone(p.margin)]))
    self.cells.rate:SetText(p.percent and ns.T("deMarginRate", K.Decimal(p.percent, 1, true)) or "")
    self.cells.via:SetText(p.via and K.Money(p.via) or "")
    self.cells.viaRate:SetText(p.viaRate and ns.T("deViaShort", p.viaRate) or "")
    self.cells.viaRate:SetTextColor(unpack(K.theme[K.Tone(p.viaRate and -p.viaRate)]))
    if p.cells then self:FillCustom(p.cells)
    elseif self.custom then
        self.custom = nil
        for _, key in ipairs({"ilvl", "rate"}) do self.cells[key]:SetTextColor(unpack(K.theme.secondary)) end
        for _, key in ipairs({"price", "via"}) do self.cells[key]:SetTextColor(unpack(K.theme.text)) end
    end
    if p.match then self.match:Show(); self.matchBar:Show() else self.match:Hide(); self.matchBar:Hide() end
    if self.buy then
        if p.actionDisabled then self.buy:Disable() else self.buy:Enable() end
    end
    if self.refresh then
        if p.refreshDisabled then self.refresh:Disable() else self.refresh:Enable() end
    end
    self:Reveal()
end
function K.OutcomeOrder(outputs)
    local list = {}
    for i, output in ipairs(outputs) do
        list[i] = {output = output, value = output.price and output.quantity * output.price or nil, index = i}
    end
    table.sort(list, function(a, b)
        if a.value ~= b.value then
            if a.value == nil then return false end
            if b.value == nil then return true end
            return a.value > b.value
        end
        return a.index < b.index
    end)
    return list
end
function K.OutcomeCells(output, value)
    local count = output.minCount == output.maxCount and tostring(output.minCount)
        or output.minCount .. "-" .. output.maxCount
    return {ilvl = {count, "secondary"}, margin = {K.Money(value), value and "text" or "secondary"},
        rate = {K.Chance(output.chance), "secondary"}}
end
function K.ActionWidth(action, default)
    return action.icon and 22 or action.width or default
end
function K.ActionReserve(actions)
    local width = 8
    for i, action in ipairs(actions) do
        width = width + K.ActionWidth(action, 60) + (i > 1 and 3 or 0)
    end
    return width
end
function K.PlaceActions(row)
    local actions = row.actions or (row.props and row.props.actions) or {}
    local right
    for i = #actions, 1, -1 do
        local button = row.buttons[i]
        if button then
            button:SetWidth(K.ActionWidth(actions[i], 60))
            button:ClearAllPoints()
            if right then button:SetPoint("RIGHT", right, "LEFT", -3, 0)
            else button:SetPoint("RIGHT", row.frame, "RIGHT", -4, 0) end
            right = button
        end
    end
end
function K.RevealActions(row)
    local p = row.props
    local actions = row.actions or (p and p.actions)
    for i, button in ipairs(row.buttons) do
        local action = actions and actions[i]
        if action then
            if not K.SetGlyph(button, action.icon) then button:SetText(action.label) end
            if action.disabled then button:Disable() else button:Enable() end
            if action.sources then K.ScanTip(button, action.label, action.tip or "", action.sources, nil, {modes = action.scanModes, solo = action.solo})
            else
                K.ScanUntrack(button)
                if action.tip then button.tipFn, button.tipKeys = nil, nil; K.Tooltip(button, action.label, action.tip) end
            end
            button:Show()
        else button:Hide() end
    end
end
local CraftRow = {}
CraftRow.__index = CraftRow
K.CraftRow = CraftRow
CraftRow.PIN = 16
K.CROSS = 13
local function craftOffsets(depth, compact)
    local base = (depth or 0) * 8
    if compact then return base + 4, base + 13, base + 26 end
    return base + 4, base + 21, base + 34
end
function CraftRow:New(parent, select, expand, pin)
    local row = setmetatable({buttons = {}}, self)
    row.frame = K.ItemChoice(parent, function() select(row.props.id, row.props) end)
    row.frame:SetHeight(30)
    K.RowStripe(row, parent, "craftRowCount")
    row.expand = K.ExpandButton(row.frame, function() expand(row.props.id, row.props) end)
    row.frame.icon:SetWidth(22); row.frame.icon:SetHeight(22)
    K.SetFontHeight(row.frame.text, 12)
    row.cross = K.Unlearned(row.frame, 12)
    row.crossTip = ns.NewFrame("Frame", nil, row.frame)
    row.crossTip:SetAllPoints(row.cross); row.crossTip:EnableMouse(true)
    K.Tooltip(row.crossTip, ns.T("batchUnlearned"), ns.T("craftRowUnlearnedTip"))
    row.crossTip:Hide()
    row.star = row.frame:CreateTexture(nil, "OVERLAY")
    row.star:SetTexture(K.theme.actionIcons.lists[1]); row.star:SetWidth(11); row.star:SetHeight(11)
    row.star:SetPoint("TOPLEFT", row.frame.icon, "TOPLEFT", -4, 4); row.star:Hide()
    row.divider = row.frame:CreateTexture(nil, "ARTWORK")
    row.divider:SetTexture(K.theme.white); row.divider:SetVertexColor(unpack(K.theme.edge)); row.divider:SetHeight(1)
    row.divider:Hide()
    row.detail = K.Label(row.frame, "", 0, -16, 200, "secondary"); K.SetFontHeight(row.detail, 12)
    row.cells = {}
    for _, key in ipairs({"price", "margin", "units"}) do
        local cell = K.Label(row.frame, "", 0, -3, 80); K.SetFontHeight(cell, 12); cell:SetJustifyH("RIGHT")
        row.cells[key] = cell
    end
    row.marginRate = K.Label(row.frame, "", 0, -16, 80, "secondary"); K.SetFontHeight(row.marginRate, 12); row.marginRate:SetJustifyH("RIGHT")
    row.arrow = row.frame:CreateTexture(nil, "ARTWORK")
    row.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow"); row.arrow:SetWidth(9); row.arrow:SetHeight(9)
    row.change = K.Label(row.frame, "", 0, -16, 70, "secondary"); K.SetFontHeight(row.change, 12); row.change:SetJustifyH("RIGHT")
    K.ActionButtons(row, 3, "id", 60)
    if pin then
        row.pin = ns.NewFrame("Button", nil, row.frame)
        row.pin:SetWidth(CraftRow.PIN); row.pin:SetHeight(CraftRow.PIN)
        row.pin.icon = row.pin:CreateTexture(nil, "OVERLAY")
        row.pin.icon:SetAllPoints(row.pin); row.pin.icon:SetTexture(K.theme.actionIcons.pin[1])
        row.pin:SetScript("OnClick", function() pin(row.props.id, row.props) end)
        K.Tooltip(row.pin, ns.T("craftPin"), ns.T("craftPinTip"))
        row.pin:Hide()
        local function hover() row:RevealPin(true) end
        local function leave() row:RevealPin(row.frame.IsMouseOver and row.frame:IsMouseOver() or false) end
        row.frame:HookScript("OnEnter", hover); row.frame:HookScript("OnLeave", leave)
        row.pin:HookScript("OnEnter", hover); row.pin:HookScript("OnLeave", leave)
    end
    return row
end
function CraftRow:RevealPin(hovered)
    local pin, p = self.pin, self.props
    if not pin then return end
    if p and p.pinnable and (p.pinned or hovered) then
        K.Tooltip(pin, ns.T(p.pinned and "craftUnpin" or "craftPin"), ns.T(p.pinned and "craftUnpinTip" or "craftPinTip"))
        local color = K.theme[p.pinned and "gold" or "secondary"]
        pin.icon:SetVertexColor(color[1], color[2], color[3]); pin:Show()
    else pin:Hide() end
end
function CraftRow:SetProps(props)
    self.props = props; self:Render()
end
function CraftRow:Render()
    local p = self.props
    local columns = K.CraftColumns(p.width, p.more)
    local expandAt, crossAt, offset = craftOffsets(p.depth, rawget(self, "compact"))
    if p.iconX then expandAt, crossAt, offset = p.toggleX, math.max(0, p.iconX - K.CROSS), p.iconX end
    self.frame:SetWidth(p.width)
    K.SetItemChoice(self.frame, p.id, p.active, p.quality)
    self.frame.extraTip = p.tip
    self.frame.tipKeys = p.keys and function() return {body = p.tip, keys = p.keys} end or nil
    self.frame.icon:ClearAllPoints(); self.frame.icon:SetPoint("LEFT", self.frame, "LEFT", offset, 0)
    self.frame.text:ClearAllPoints(); self.frame.text:SetPoint("TOPLEFT", self.frame, "TOPLEFT", offset + 26, -3)
    local room = math.max(40, columns.item[2] - offset - 30 - (p.pinnable and CraftRow.PIN + 4 or 0))
    self.frame.text:SetWidth(room)
    if self.pin then
        local used = math.min(room, math.ceil(self.frame.text:GetStringWidth() or room))
        self.pin:ClearAllPoints(); self.pin:SetPoint("LEFT", self.frame.text, "LEFT", used + 4, 0)
    end
    if p.unlearned then
        self.cross:ClearAllPoints(); self.cross:SetPoint("LEFT", self.frame, "LEFT", crossAt, 0)
        self.cross:Show()
        self.crossTip:Show()
    else self.cross:Hide(); self.crossTip:Hide() end
    if p.favorite then self.star:Show() else self.star:Hide() end
    if p.divider then
        self.divider:ClearAllPoints()
        self.divider:SetPoint("TOPLEFT", self.frame, "TOPLEFT", expandAt, 3)
        self.divider:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 3)
        self.divider:Show()
    else self.divider:Hide() end
    self.detail:ClearAllPoints(); self.detail:SetPoint("TOPLEFT", self.frame, "TOPLEFT", offset + 26, -K.FontHeight(16))
    self.detail:SetWidth(math.max(40, columns.item[2] - offset - 30))
    self.detail:SetText(p.detail or "")
    self.expand:ClearAllPoints(); self.expand:SetPoint("LEFT", self.frame, "LEFT", expandAt, 0)
    self.expand:SetText(p.opened and "-" or "+")
    if p.expandable then self.expand:Show() else self.expand:Hide() end
    K.MoreCells(self, columns, p)
    for key, cell in pairs(self.cells) do
        local column = columns[key]
        cell:ClearAllPoints()
        if column then
            local single = key == "units" or key == "have" or key == "gone"
            cell:SetPoint("TOPLEFT", self.frame, "TOPLEFT", column[1], single and -9 or -3)
            cell:SetWidth(column[2] - 6); cell:Show()
        else cell:Hide() end
    end
    self.cells.price:SetText(K.Money(p.price))
    self.change:ClearAllPoints(); self.change:SetPoint("TOPLEFT", self.frame, "TOPLEFT", columns.price[1], -K.FontHeight(16))
    self.change:SetWidth(columns.price[2] - 6)
    if p.change then
        local up = p.change >= 0
        self.change:SetText(ns.T("craftChange", K.Decimal(math.abs(p.change), 1)))
        self.change:SetTextColor(unpack(K.theme[up and "positive" or "negative"]))
        self.arrow:ClearAllPoints(); self.arrow:SetPoint("RIGHT", self.change, "LEFT", -1, 0)
        if up then self.arrow:SetTexCoord(0, 0.5625, 1, 0) else self.arrow:SetTexCoord(0, 0.5625, 0, 1) end
        self.arrow:SetVertexColor(unpack(K.theme[up and "positive" or "negative"]))
        self.arrow:Show(); self.change:Show()
    else self.arrow:Hide(); self.change:Hide() end
    self.cells.margin:SetText(p.marginText or K.Money(p.margin))
    self.cells.margin:SetTextColor(unpack(K.theme[p.marginTone or K.Tone(p.margin)]))
    self.marginRate:ClearAllPoints(); self.marginRate:SetPoint("TOPLEFT", self.frame, "TOPLEFT", columns.margin[1], -K.FontHeight(16))
    self.marginRate:SetWidth(columns.margin[2] - 6)
    self.marginRate:SetText(p.percent and ns.T("deMarginRate", K.Decimal(p.percent, 1, true)) or "")
    self.cells.units:SetText(p.units and tostring(p.units) or ns.T("tradeNoPrice"))
    K.PlaceActions(self)
    K.RevealActions(self)
    self:RevealPin(self.frame.IsMouseOver and self.frame:IsMouseOver() or false)
    self.frame:Show()
end
local LedgerRow = {}
LedgerRow.__index = LedgerRow
K.LedgerRow = LedgerRow
function LedgerRow:New(parent, select, expand)
    local row = setmetatable({cells = {}, buttons = {}}, self)
    row.parent = parent
    K.LineRow(row, parent, function() if row.props then select(row.props.key) end end, "ledgerRowCount")
    K.ActionButtons(row, 2, "key", 64, true)
    if expand then
        row.expand = K.ExpandButton(row.frame, function() if row.props then expand(row.props.key, row.props) end end)
        row.expand:SetPoint("LEFT", row.frame, "LEFT", 6, 0)
        row.expand:Hide()
    end
    return row
end
LedgerRow.Cell = K.RowCell
function LedgerRow:SetProps(props)
    self.props = props; self:Render()
end
function LedgerRow:PlaceTree(lead)
    local p, frame = self.props, self.frame
    local icon = p.iconX or (p.nested and 50 or 26)
    if lead > 0 then icon = lead + (p.nested and K.EXPAND or 0) end
    if p.toggleX then
        self.expand:ClearAllPoints(); self.expand:SetPoint("LEFT", frame, "LEFT", p.toggleX, 0)
    end
    frame.icon:ClearAllPoints(); frame.icon:SetPoint("LEFT", frame, "LEFT", icon, 0)
    frame.text:ClearAllPoints(); frame.text:SetPoint("LEFT", frame, "LEFT", icon + 24, 0)
    frame.textLeft = icon + 24
    self.expand:SetText(p.opened and "-" or "+")
    if p.expandTip then K.Tooltip(self.expand, p.expandTip[1], p.expandTip[2]) end
    if p.expandable and not p.nested then self.expand:Show() else self.expand:Hide() end
end
function LedgerRow:Render()
    local p, frame = self.props, self.frame
    local columns = p.columns or K.LedgerColumns(p.width, p.mode, p.hasActions)
    frame:SetWidth(p.width)
    if p.id then
        K.SetItemChoice(frame, p.id, p.active, p.quality, p.link)
    else
        frame.itemID, frame.itemLink = nil, nil
        frame.icon:SetTexture(nil); frame.text:SetText(p.title or "")
        frame.text:SetTextColor(unpack(K.theme.text))
        K.SetSelected(frame, p.active)
        frame:Show()
    end
    if p.label then frame.text:SetText(p.label) end
    frame.extraTip = p.tip
    frame.tipKeys = p.keys and function() return {body = p.tip, keys = p.keys} end or nil
    local lead = columns.item[1]
    if self.expand and p.tree then self:PlaceTree(lead)
    else
        if self.expand then self.expand:Hide() end
        K.NestLine(self, p.nested)
        if lead > 0 then
            frame.icon:ClearAllPoints(); frame.icon:SetPoint("LEFT", frame, "LEFT", lead, 0)
            frame.text:ClearAllPoints(); frame.text:SetPoint("LEFT", frame, "LEFT", lead + 24, 0)
            frame.textLeft = lead + 24
        end
    end
    K.FillCells(self, columns, p.cells)
    K.ItemTag(frame, p.tag and K.RowCell(self, "tag") or self.cells.tag, columns.item, p.tag, p.tagTone or "secondary", p.tagWidth)
    for i, button in ipairs(self.buttons) do
        local action = p.actions and p.actions[i]
        if action then button:SetWidth(K.ActionWidth(action, 64)) end
    end
    K.RevealActions(self)
end
local RecycleRow = {}
RecycleRow.__index = RecycleRow
K.RecycleRow = RecycleRow
function RecycleRow:New(parent, select)
    local row = setmetatable({buttons = {}}, self)
    K.LineRow(row, parent, function() select(row.props.key) end, "recycleRowCount")
    row.cells = {}
    for _, key in ipairs({"asIs", "split", "assemble", "bags"}) do
        local cell = K.Label(row.frame, "", 0, -6, 80, key == "bags" and "secondary" or nil)
        K.SetFontHeight(cell, 12); cell:SetJustifyH("RIGHT")
        row.cells[key] = cell
    end
    K.ActionButtons(row, 1, "key", 62)
    return row
end
function RecycleRow:SetProps(props)
    self.props = props; self:Render()
end
function RecycleRow:Render()
    local p, e = self.props, self.props.estimate
    local columns = K.RecycleColumns(p.width)
    self.frame:SetWidth(p.width)
    K.SetItemChoice(self.frame, p.id, p.active)
    self.frame.extraTip = p.tip
    self.frame.tipKeys = function() return {body = p.tip,
        keys = {{key = ns.T("scanKeyClick"), text = ns.T("recyclePick")}}} end
    K.NestLine(self, true)
    self.frame.text:SetWidth(math.max(40, columns.item[2] - K.NEST_TEXT - 6))
    K.PlaceCells(self, columns)
    self.cells.asIs:SetText(K.Money(e.asIs))
    self.cells.split:SetText(p.oneWay and ns.T("tradeNoPrice") or K.Money(e.split))
    self.cells.assemble:SetText(K.Money(e.assemble))
    self.cells.asIs:SetTextColor(unpack(K.theme[e.best == "asIs" and "accent" or "text"]))
    self.cells.split:SetTextColor(unpack(K.theme[e.best == "split" and "accent" or "text"]))
    self.cells.assemble:SetTextColor(unpack(K.theme[K.Tone(e.assemble)]))
    self.cells.bags:SetText((e.haveBig > 0 or e.haveSmall > 0) and ns.T("recycleBags", e.haveBig, e.haveSmall) or "")
    K.RevealActions(self)
    self.frame:Show()
end
local BagRow = {}
BagRow.__index = BagRow
K.BagRow = BagRow
function BagRow:New(parent, select)
    local row = setmetatable({cells = {}}, self)
    K.LineRow(row, parent, function() if row.props then select(row.props.id) end end, "bagRowCount")
    return row
end
BagRow.Cell = K.RowCell
function BagRow:SetProps(props)
    self.props = props; self:Render()
end
function BagRow:Render()
    local p, frame = self.props, self.frame
    local columns = K.BagColumns(p.width)
    frame:SetWidth(p.width)
    K.SetItemChoice(frame, p.id, p.active)
    frame.extraTip = p.tip
    K.NestLine(self, false)
    frame.text:SetWidth(math.max(40, columns.item[2] - (p.iconX or 8) - 30))
    K.FillCells(self, columns, p.cells)
end
function K.ValueRow(parent, text, y, labelWidth, valueWidth)
    local label = K.Label(parent, text, K.theme.inset, y, labelWidth or 118, "secondary")
    K.SetFontHeight(label, 12)
    local value = K.Label(parent, "", 0, y, valueWidth or 124)
    K.SetFontHeight(value, 12); value:SetJustifyH("RIGHT")
    value:ClearAllPoints(); value:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -K.theme.inset, y)
    return label, value
end
function K.ValueRows(parent, y, texts, options)
    local o = options or {}
    local step, labels, values = o.step or K.theme.valueStep, {}, {}
    for i, text in ipairs(texts) do
        local last = i == #texts
        local top = y - (i - 1) * step - (last and o.gap or 0)
        labels[i], values[i] = K.ValueRow(parent, text, top, o.labelWidth, o.valueWidth)
        if last and o.strong then labels[i]:SetTextColor(unpack(K.theme.text)) end
    end
    return labels, values
end
function K.FitValue(label, value, room)
    value:SetWidth(room)
    local used = math.min(room, math.ceil(value:GetStringWidth() or room / 2) + 2)
    value:SetWidth(used)
    label:SetWidth(math.max(1, room - used - 6))
end
local FactList = {STEP = 16, ITEM = 22, GAP = 6}
FactList.__index = FactList
K.FactList = FactList
function FactList:New(parent)
    local list = setmetatable({lines = {}, items = {}, height = 0}, self)
    list.frame = ns.NewFrame("Frame", nil, parent)
    list.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    return list
end
function FactList:Line(i)
    local line = self.lines[i]
    if not line then
        local label, value = K.ValueRow(self.frame, "", 0)
        line = {label = label, value = value}
        self.lines[i] = line
    end
    return line
end
function FactList:Item(i)
    local item = self.items[i]
    if not item then
        item = K.ItemChoice(self.frame, function(b) if b.itemID then K.Inspector.Switch("market", b.itemID) end end)
        item:SetHeight(FactList.ITEM - 2)
        item.icon:SetWidth(16); item.icon:SetHeight(16)
        item.text:ClearAllPoints(); item.text:SetPoint("LEFT", item, "LEFT", 22, 0)
        K.SetFontHeight(item.text, 12)
        self.items[i] = item
    end
    return item
end
function FactList:SetProps(props)
    self.props = props; self:Render()
end
function FactList:Render()
    local p = self.props
    local inset = K.theme.inset
    local room = p.width - 2 * inset
    local y, used = 0, 0
    self.frame:ClearAllPoints(); self.frame:SetPoint("TOPLEFT", self.frame:GetParent(), "TOPLEFT", 0, -(p.top or 0))
    self.frame:SetWidth(p.width)
    for i, fact in ipairs(p.rows or {}) do
        if fact.gap and i > 1 then y = y + FactList.GAP end
        local line = self:Line(i)
        local step = fact.id and FactList.ITEM or K.FontHeight(FactList.STEP)
        local top = -y - (fact.id and 4 or 2)
        line.value:ClearAllPoints(); line.value:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -inset, top)
        line.value:SetText(fact.value or "")
        line.value:SetTextColor(unpack(K.theme[fact.tone or "text"]))
        line.label:ClearAllPoints(); line.label:SetPoint("TOPLEFT", self.frame, "TOPLEFT", inset + (fact.sub and 22 or 0), top)
        K.FitValue(line.label, line.value, room - (fact.sub and 22 or 0))
        line.value:Show()
        if fact.id then
            used = used + 1
            local item = self:Item(used)
            item:ClearAllPoints(); item:SetPoint("TOPLEFT", self.frame, "TOPLEFT", inset - 2, -y)
            K.SetItemChoice(item, fact.id, false)
            if fact.count then item.text:SetText((item.text:GetText() or "") .. " " .. ns.T("tipItemCount", fact.count)) end
            local width = math.max(40, (line.label:GetWidth() or room) + 2)
            item:SetWidth(width); item.text:SetWidth(math.max(20, width - 24))
            line.label:Hide()
        else
            line.label:SetText(fact.label or "")
            line.label:SetTextColor(unpack(K.theme[fact.strong and "text" or "secondary"]))
            line.label:Show()
        end
        y = y + step
    end
    for i = #(p.rows or {}) + 1, #self.lines do self.lines[i].label:Hide(); self.lines[i].value:Hide() end
    for i = used + 1, #self.items do self.items[i]:Hide() end
    self.height = y
    self.frame:SetHeight(math.max(1, y))
end
local BargainRow = setmetatable({}, {__index = K.LedgerRow})
BargainRow.__index = BargainRow
K.BargainRow = BargainRow
function K.ItemTag(frame, label, item, text, tone, width)
    local room = item[1] + item[2] - (rawget(frame, "textLeft") or 32) - 6
    if label and text and text ~= "" then
        width = width or K.ITEM_TAG
        label:SetWidth(width - 6); label:SetText(text)
        local fit = label.GetStringWidth and math.ceil(label:GetStringWidth() or 0) or 0
        if fit > 0 and fit + 14 < width then width = fit + 14; label:SetWidth(width - 6) end
        label:ClearAllPoints(); label:SetPoint("LEFT", frame, "LEFT", item[1] + item[2] - width, 0)
        label:SetTextColor(unpack(K.theme[tone or "positive"])); label:Show()
        room = room - width
    elseif label then label:Hide() end
    frame.text:SetWidth(math.max(40, room))
end
function K.BoughtMark(id, since)
    local h = ns.Buy and ns.Buy.Bought(id, since)
    if not h then return nil end
    local tips = {}
    if h.units > 0 then tips[#tips + 1] = ns.T("boughtTip", h.units, K.Money(h.spent)) end
    if h.bids > 0 then tips[#tips + 1] = ns.T("boughtBidTip", h.bids, K.Money(h.bidSpent)) end
    if h.units > 0 then return ns.T("boughtTag", h.units), "accent", table.concat(tips, "\n") end
    return ns.T("boughtBidTag", h.bids), "secondary", table.concat(tips, "\n")
end
local BidRow = setmetatable({}, {__index = K.LedgerRow})
BidRow.__index = BidRow
K.BidRow = BidRow
function BidRow:Render()
    local p, frame = self.props, self.frame
    local columns = K.BidColumns(p.width, p.mode)
    frame:SetWidth(p.width)
    K.SetItemChoice(frame, p.id, p.active, p.quality, p.link)
    frame.extraTip = p.tip
    K.FillCells(self, columns, p.cells)
    K.NestLine(self, false)
    K.ItemTag(frame, p.tag and self:Cell("tag") or self.cells.tag, columns.item, p.tag, p.tagTone)
    for i, button in ipairs(self.buttons) do
        local action = p.actions and p.actions[i]
        if action then button:SetWidth(K.ActionWidth(action, 74)) end
    end
    K.RevealActions(self)
end
function BargainRow:Render()
    local p, frame = self.props, self.frame
    local columns = K.BargainColumns(p.width)
    frame:SetWidth(p.width)
    K.SetItemChoice(frame, p.id, p.active, p.quality)
    frame.extraTip = p.tip
    K.FillCells(self, columns, p.cells)
    K.NestLine(self, false)
    K.ItemTag(frame, p.tag and self:Cell("tag") or self.cells.tag, columns.item, p.tag, p.tagTone)
    for i, button in ipairs(self.buttons) do
        local action = p.actions and p.actions[i]
        if action then button:SetWidth(K.ActionWidth(action, 74)) end
    end
    K.RevealActions(self)
end
local ShoppingLotRow = {}
ShoppingLotRow.__index = ShoppingLotRow
K.ShoppingLotRow = ShoppingLotRow
function ShoppingLotRow:New(parent, money, adjust, pick)
    local row = setmetatable({frame = ns.NewFrame("Button", nil, parent), cells = {}, money = money}, self)
    row.stripe = K.Background(row.frame)
    row.stripe:SetVertexColor(unpack(K.theme.row))
    if pick then
        local hover = row.frame:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(row.frame); K.Highlight(hover, "hover"); row.frame:SetHighlightTexture(hover)
        row.frame:RegisterForClicks("LeftButtonUp")
        row.frame:SetScript("OnClick", function()
            if row.offer and not row.active then pick(row.offer, IsShiftKeyDown() and true or false) end
        end)
    end
    K.MatchMark(row)
    K.RowCell(row, "stacks"):SetJustifyH("LEFT")
    row.minus = K.Button(row.frame, "-", 22, function() adjust(row.offer, -1) end, "quiet")
    row.minus:SetHeight(20); row.minus:SetPoint("LEFT", row.frame, "LEFT", 4, 0)
    K.Tooltip(row.minus, ns.T("buyLotMinus"), ns.T("buyLotStepTip"))
    row.plus = K.Button(row.frame, "+", 22, function() adjust(row.offer, 1) end, "quiet")
    row.plus:SetHeight(20); row.plus:SetPoint("RIGHT", row.frame, "RIGHT", -4, 0)
    K.Tooltip(row.plus, ns.T("buyLotPlus"), ns.T("buyLotStepTip"))
    row.frame:EnableMouse(true)
    K.Tooltip(row.frame, ns.T("offersSellers"), "")
    row.frame.tipFn = function() return row.offer and table.concat(ns.Offers.Sellers(row.offer), "\n") or "" end
    if pick then
        row.frame.tipKeys = function()
            local body = row.offer and table.concat(ns.Offers.Sellers(row.offer), "\n") or ""
            if row.active then return {body = body} end
            return {body = body, keys = {{key = ns.T("scanKeyClick"), text = ns.T("buyLotOnly")},
                {key = "Shift", text = ns.T("buyLotToggle")}}}
        end
    end
    return row
end
function ShoppingLotRow:SetProps(p)
    local offer, picked, bought = p.offer, p.picked, p.bought or 0
    self.offer, self.active = offer, p.active
    local stacks
    if bought > 0 then
        stacks = picked > 0 and ns.T("buyBoughtMore", bought, bought + picked, offer.stack)
            or ns.T("buyBoughtRow", bought, offer.stack)
    elseif picked > 0 then stacks = ns.T("buyPickedRow", picked, offer.count, offer.stack)
    else stacks = ns.T("buyStacksRow", offer.count, offer.stack) end
    K.FillCells(self, p.columns, {
        stacks = {stacks, (picked > 0 or bought > 0) and "positive" or "text"},
        unit = {self.money(offer.buyout / offer.stack)},
        lot = {self.money(offer.buyout)},
    })
    if picked > 0 then self.match:Show(); self.matchBar:Show() else self.match:Hide(); self.matchBar:Hide() end
    if p.active then self.minus:Disable() else self.minus:Enable() end
    if p.active or (p.limit and offer.buyout >= p.limit * offer.stack) then self.plus:Disable() else self.plus:Enable() end
end
local ShoppingItemRow = {}
ShoppingItemRow.__index = ShoppingItemRow
K.ShoppingItemRow = ShoppingItemRow
function ShoppingItemRow:New(parent, choose)
    local row = setmetatable({}, self)
    K.LineRow(row, parent, function(_, button) choose(row.props.entry, button) end, "shoppingItems")
    local frame = row.frame
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.need = K.Label(frame, "", 0, 0, 52, "secondary")
    K.SetFontHeight(row.need, 12); row.need:SetJustifyH("RIGHT")
    row.need:ClearAllPoints(); row.need:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
    row.detail = K.Label(frame, "", 28, -16, 110, "secondary")
    row.detail:ClearAllPoints(); row.detail:SetPoint("TOPLEFT", frame.text, "BOTTOMLEFT", 0, -1)
    K.SetFontHeight(row.detail, 12)
    return row
end
function ShoppingItemRow:SetProps(p)
    self.props = p
    local frame, entry = self.frame, p.entry
    K.NestLine(self, false)
    K.SetItemChoice(frame, entry.id, p.selected)
    if entry.name then frame.text:SetText(entry.name) end
    local recent = entry.result == "recent"
    frame.text:SetWidth(math.max(1, p.width - frame.textLeft - (recent and 60 or 4)))
    frame.extraTip = entry.detail and ns.T("searchCatalogTip") or nil
    frame.tipKeys = nil
    self.need:SetText(recent and ns.T("buyHistoryNeed", entry.need) or "")
    self.detail:SetText(entry.detail or "")
    if entry.detail then
        frame.text:ClearAllPoints(); frame.text:SetPoint("LEFT", frame, "LEFT", frame.textLeft, 7)
        self.detail:SetWidth(frame.text:GetWidth())
    end
    if recent then
        frame.tipKeys = function()
            return {body = frame.extraTip, keys = {
                {key = ns.T("scanKeyClick"), text = ns.T("buyHistoryTip", entry.need)},
                {key = ns.T("tipKeyRight"), text = ns.T("buyHistoryRemove")}}}
        end
        local last = entry.last
        if last and (last.units or 0) > 0 then
            frame.extraTip = ns.T("buyLastTip", last.units,
                K.Money(math.floor(last.spent / last.units)), K.Ago(math.max(0, time() - (last.at or 0))))
        end
    end
end
