local _, ns = ...
local K = ns.TradeKit
local Panel = {}
Panel.__index = Panel
K.ObtainPanel = Panel
Panel.TOP = 8
Panel.POOL = 24
Panel.QUANTITY = 10
Panel.STEPS = {1, 3, 5, 10, 15, 20, 100}
Panel.SHORT = {1, 5, 10, 20, 100}
Panel.INDENT = 12
local SUM = 140
Panel.VENDOR_ICON = "Interface\\Icons\\INV_Misc_Bag_10"
function Panel:New(inspector, name, top)
    local panel = setmetatable({rows = {}, lines = {}, options = {}, open = {}, quantity = Panel.QUANTITY, props = {}}, self)
    panel.view = K.PanelScroll:New(inspector, name, 300, top)
    panel.frame, panel.child = panel.view.frame, panel.view.child
    panel.band = K.ActionBand:For(inspector, panel.view, true)
    local c = panel.child
    panel.head = K.Label(c, ns.T("obtainHead"), 0, 0, 160, "heading"); panel.head:SetHeight(14)
    for i = 1, Panel.POOL do panel.rows[i] = Panel.NewRow(panel, c) end
    panel:NewBuyRow()
    panel.frame:Hide()
    return panel
end
function Panel.NewRow(host, parent)
    local row = {}
    row.frame = K.ItemChoice(parent, function() if row.line and row.line.click then row.line.click() end end)
    row.frame:SetHeight(30)
    row.frame.icon:SetWidth(22); row.frame.icon:SetHeight(22)
    row.frame.text:SetHeight(12)
    row.detail = K.Label(row.frame, "", 0, -16, 150, "secondary"); row.detail:SetHeight(12)
    row.sum = K.Label(row.frame, "", 0, 0, 120); row.sum:SetHeight(12); row.sum:SetJustifyH("RIGHT")
    row.sum:ClearAllPoints(); row.sum:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT", 0, -3)
    row.expand = K.Button(row.frame, "+", 18, function()
        local key = row.line and row.line.key
        if key then host.open[key] = not host.open[key] or nil; host:Render() end
    end, "quiet")
    row.expand:SetHeight(18)
    row.expand.text:ClearAllPoints(); row.expand.text:SetPoint("CENTER", row.expand, "CENTER", 0, 0)
    row.frame:SetScript("OnEnter", function(self) Panel.Tip(self, row.line) end)
    row.frame:SetScript("OnLeave", function(self) GameTooltip:Hide(); K.KeyTip.Hide(self) end)
    row.underline = row.frame:CreateTexture(nil, "ARTWORK")
    row.underline:SetTexture(K.theme.white); row.underline:SetHeight(1); row.underline:Hide()
    row.frame:Hide()
    return row
end
function Panel:NewBuyRow()
    local buyRow = ns.NewFrame("Frame", nil, self.band.frame)
    buyRow:SetHeight(22)
    self.buyRow = buyRow
    self.edit = K.Edit(buyRow, 52)
    self.edit:SetNumeric(true); self.edit:SetMaxLetters(5)
    self.edit:SetPoint("LEFT", buyRow, "LEFT", 0, 0)
    K.Tooltip(self.edit, ns.T("buyModalNeed"), ns.T("buyModalNeedTip"))
    K.LiveEdit(self.edit, function(edit)
        local value = tonumber(edit:GetText())
        if value and value >= 1 and value <= ns.Plan.MAX_UNITS then self.quantity = value; self:Render()
        else edit:SetText(tostring(self.quantity)) end
    end)
    self.unit = K.Label(buyRow, ns.T("obtainPieces"), 0, 0, 24, "secondary"); self.unit:SetHeight(12)
    self.unit:ClearAllPoints(); self.unit:SetPoint("LEFT", self.edit, "RIGHT", 4, 0)
    self.segments = {}
    for _, list in ipairs({Panel.STEPS, Panel.SHORT}) do
        local steps = {}
        for i, n in ipairs(list) do steps[i] = {key = n, label = ns.T("batchStep", n)} end
        local seg = K.Segment(buyRow, steps, function(n)
            local edit = self.edit
            edit.liveAt = nil; edit:SetScript("OnUpdate", nil)
            edit:ClearFocus(); edit:SetText(tostring(n))
            self.quantity = n; self:Render()
        end)
        K.CompactSteps(seg)
        seg.frame:ClearAllPoints(); seg.frame:SetPoint("RIGHT", buyRow, "RIGHT", 0, 0)
        self.segments[#self.segments + 1] = seg
    end
    buyRow:Hide()
end
function Panel:SetProps(props)
    if (props and props.id) ~= self.props.id then self.open = {} end
    self.props = props or {}
    self:Render()
end
local function auction(id)
    local q = ns.Markets.Quote(id)
    return q and q.miss == 0 and q.complete ~= false and q.price or nil
end
local function craftEdge(id)
    for _, option in ipairs(ns.Obtain.Alternatives(id)) do
        local edge = option.edge
        if edge and edge.inputs and (edge.kind == "craft" or edge.kind == "transmute") and not option.hidden then return edge end
    end
end
function Panel.Inputs(edge, depth)
    local lines = {}
    local out = edge.out or 1
    for _, input in ipairs(edge.inputs) do
        local id, count = input[1], input[2] / out
        local price = auction(id)
        local sub = depth < 2 and craftEdge(id) or nil
        lines[#lines + 1] = {depth = depth, key = edge.key .. ">" .. id, title = ns.Markets.Name(id),
            detail = ns.T("obtainInputCount", ns.Obtain.Amount(count)) .. (sub and " | " .. (ns.Obtain.Way(sub)) or ""),
            cost = price and price * count, item = id, link = "item",
            children = sub and function() return Panel.Inputs(sub, depth + 1) end or nil}
    end
    return lines
end
local function itemLabel(id, count)
    local icon = select(10, ns.Compat.ItemInfo(id))
    return (icon and "|T" .. icon .. ":14:14|t " or "") .. ns.Markets.Name(id) .. (count and " x" .. ns.Obtain.Amount(count) or "")
end
function Panel.CraftTip(edge, cost)
    local rows, total, missing = {}, 0, false
    local out = edge.out or 1
    for _, input in ipairs(edge.inputs) do
        local price = auction(input[1])
        local count = input[2] / out
        if price then total = total + price * count else missing = true end
        rows[#rows + 1] = {label = itemLabel(input[1], count), value = price and K.Money(price * count) or ns.T("batchNoPrice")}
    end
    rows[#rows + 1] = {label = ns.T("obtainTotalRow"), value = missing and ns.T("batchNoPrice") or K.Money(total)}
    if cost and not missing and cost < total then rows[#rows + 1] = {label = ns.T("obtainMadeRow"), value = K.Money(cost)} end
    return {title = edge.spell and (ns.Compat.SpellIcon(edge.spell)) or (ns.Obtain.Way(edge)),
        body = edge.cooldown and ns.T("obtainCooldownBody") or nil,
        facts = {{head = ns.T("obtainInputsHead"), rows = rows}}}
end
function Panel.LotteryTip(edge, option)
    local input = edge.inputs and edge.inputs[1]
    local yield = edge.yield or 0
    local rows = {}
    if input and yield > 0 then
        rows[#rows + 1] = {label = itemLabel(input[1], input[2] / yield), value = option.gross and K.Money(option.gross) or ns.T("batchNoPrice")}
        rows[#rows + 1] = {label = ns.T("obtainChanceRow", input[2]), value = K.Decimal(yield * 100, 1, false, true) .. "%"}
    end
    if option.gross and option.cost then rows[#rows + 1] = {label = ns.T("obtainOthersRow"), value = K.Money(option.cost - option.gross)} end
    if option.cost then rows[#rows + 1] = {label = ns.T("obtainTotalRow"), value = K.Money(option.cost)} end
    local title, way = ns.Obtain.Way(edge)
    return {title = title .. ": " .. way, facts = {{head = ns.T("obtainPerPieceHead"), rows = rows}}}
end
function Panel.CurrencyTip(good)
    local N = ns.Npc
    local rows = {}
    local function row(key)
        local icon = N.Icon(key)
        rows[#rows + 1] = {label = (icon and "|T" .. icon .. ":14:14|t " or "") .. N.CurrencyName(key), value = tostring(N.Amount(key) or 0)}
    end
    row(good.currency)
    local above = N.Above(good.currency)
    for i = #above, 1, -1 do row(above[i]) end
    return {title = ns.T("obtainCurrencyTitle", N.CurrencyName(good.currency), good.count), body = N.PaymentText(good),
        facts = {{head = ns.T(#above > 0 and "obtainLadderHead" or "obtainHaveHead"), rows = rows}}}
end
function Panel.Vendors(good)
    local lines, faction = {}, UnitFactionGroup("player")
    for i, vendor in ipairs(good.vendors) do
        if vendor.faction == "Both" or vendor.faction == faction then
            lines[#lines + 1] = {depth = 1, key = "vendor:" .. good.currency .. ":" .. i, title = ns.Npc.VendorName(vendor),
                detail = ns.Npc.ZoneName(vendor), icon = Panel.VENDOR_ICON, link = "zone",
                keytip = {title = ns.Npc.VendorName(vendor), body = ns.Npc.ZoneName(vendor),
                    keys = {{key = ns.T("scanKeyClick"), text = ns.T("obtainVendorMap")}}},
                click = function()
                    if ns.MapPin then
                        ns.MapPin.Show({title = ns.Npc.VendorName(vendor), zone = vendor.zone, level = vendor.level,
                            points = vendor.x and vendor.y and {{vendor.x, vendor.y}} or {}})
                    end
                end}
        end
    end
    return lines
end
function Panel.Options(id)
    local quote = ns.Markets.Quote(id)
    local price = auction(id)
    local age = ns.Markets.Age(id)
    local detail = price and ((age and K.Ago(age) .. ", " or "") .. ns.T("obtainUnits", quote.units or 0)) or ""
    local options = {{depth = 0, key = "auction", title = ns.T("wayAuction"), cost = price, detail = detail, item = id,
        link = "item", icon = K.ProfessionIcon(nil)}}
    for _, option in ipairs(ns.Obtain and ns.Obtain.Alternatives and ns.Obtain.Alternatives(id) or {}) do
        local edge = option.edge
        if edge and edge.kind ~= "buy" and edge.kind ~= "vendor" and not option.hidden and #options < Panel.TOP then
            local title, way, profession = ns.Obtain.Way(edge)
            if (option.missing or 0) > 0 then
                local note = ns.T("craftBatchMissing", option.missing)
                way = way ~= "" and way .. ", " .. note or note
            end
            local line = {depth = 0, key = edge.key, title = title, detail = way, profession = profession,
                cost = (option.missing or 0) == 0 and option.cost or nil, spell = edge.spell, item = id}
            if ns.Obtain.IsLottery(edge) then
                line.keytip = Panel.LotteryTip(edge, option)
            elseif edge.inputs then
                line.keytip = Panel.CraftTip(edge, line.cost)
                line.children = function()
                    local lines = Panel.Inputs(edge, 1)
                    if edge.spell and edge.profession and ns.Trader and ns.Trader.OpenRecipe then
                        lines[#lines + 1] = {depth = 1, key = edge.key .. ":open", title = ns.T("obtainOpenRecipe"),
                            detail = title, icon = K.ProfessionIcon(profession),
                            keytip = {title = ns.T("obtainOpenRecipe"), keys = {{key = ns.T("scanKeyClick"), text = ns.T("obtainOpenRecipeTip")}}},
                            click = function() ns.Trader.OpenRecipe(edge.profession, edge.target) end}
                    end
                    return lines
                end
            end
            options[#options + 1] = line
        end
    end
    local best
    for i, option in ipairs(options) do
        if option.cost and (not best or option.cost < options[best].cost) then best = i end
    end
    if best and #options > 1 then options[best].best = true end
    for _, good in ipairs(ns.Npc and ns.Npc.GoodsFor(id) or {}) do
        if #options >= Panel.TOP then break end
        local icon = ns.Npc.Icon(good.currency)
        local cost = good.count .. (icon and " |T" .. icon .. ":16:16|t" or "")
            .. ((good.money or 0) > 0 and " + " .. K.Money(good.money) or "")
        options[#options + 1] = {depth = 0, key = "currency:" .. good.currency, title = ns.Npc.CurrencyName(good.currency),
            detail = ns.Npc.PaymentText(good), costText = cost, icon = icon, keytip = Panel.CurrencyTip(good),
            children = function() return Panel.Vendors(good) end}
    end
    return options, price
end
function Panel.Others(id)
    local options = Panel.Options(id)
    table.remove(options, 1)
    return options
end
function Panel.HasWays(id)
    return #Panel.Options(id) > 1
end
function Panel.Tip(owner, line)
    if not line then return end
    if line.keytip then K.KeyTip.Show(owner, line.keytip); return end
    if line.link == "item" and line.item then
        K.TipOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. line.item)
        GameTooltip:Show()
    end
end
function Panel.Flatten(open, lines, out)
    for _, line in ipairs(lines) do
        out[#out + 1] = line
        if line.children and open[line.key] then Panel.Flatten(open, line.children(), out) end
    end
    return out
end
function Panel:Render()
    local id = self.props.id
    if not id then self.frame:Hide(); self.band:SetProps({actions = {}}); self.buyRow:Hide(); self.buy = nil; return end
    self.frame:Show()
    local options, price = Panel.Options(id)
    self.options, self.price = options, price
    self.lines = Panel.Flatten(self.open, options, {})
    self:Controls()
    local width = self.view:Fit(self.height or 300)
    local height = self:Lay(width)
    local fitted = self.view:Fit(height)
    if fitted ~= width then self:Lay(fitted); self.view:Fit(self.height) end
end
function Panel.RenderLine(host, row, line, inner, base)
    row.line = line
    local x = (line.depth + (base or 0)) * Panel.INDENT
    row.frame:SetWidth(inner)
    if line.spell and line.link == "spell" then K.SetSpellChoice(row.frame, line.spell, false)
    elseif line.item then K.SetItemChoice(row.frame, line.item, false)
    else row.frame.itemID, row.frame.spellID = nil, nil end
    row.frame.icon:SetTexture(line.icon or (line.link == "item" and line.depth > 0 and select(10, ns.Compat.ItemInfo(line.item)))
        or K.ProfessionIcon(line.profession))
    row.frame.icon:ClearAllPoints(); row.frame.icon:SetPoint("LEFT", row.frame, "LEFT", x + 20, 0)
    row.frame.text:ClearAllPoints(); row.frame.text:SetPoint("TOPLEFT", row.frame, "TOPLEFT", x + 48, -3)
    row.frame.text:SetText(line.title)
    if line.depth == 0 then row.frame.text:SetTextColor(unpack(K.theme.text)) end
    row.detail:ClearAllPoints(); row.detail:SetPoint("TOPLEFT", row.frame, "TOPLEFT", x + 48, -16)
    row.detail:SetWidth(math.max(1, inner - x - 48))
    row.detail:SetText(line.detail or "")
    if line.link == "zone" then
        row.detail:SetTextColor(unpack(K.theme.accent))
        local used = math.min(row.detail:GetWidth() or 100, math.ceil(row.detail.GetStringWidth and row.detail:GetStringWidth() or 60))
        row.underline:SetVertexColor(unpack(K.theme.accent))
        row.underline:ClearAllPoints(); row.underline:SetPoint("TOPLEFT", row.detail, "BOTTOMLEFT", 0, 0)
        row.underline:SetWidth(math.max(1, used)); row.underline:Show()
    else
        row.detail:SetTextColor(unpack(K.theme.secondary)); row.underline:Hide()
    end
    local sum = line.costText or (line.cost and (line.depth == 0 and ns.T("obtainPerUnit", K.Money(line.cost)) or K.Money(line.cost)))
    if line.click and not line.cost and not line.costText then sum = "" end
    row.sum:SetWidth(SUM); row.sum:SetText(sum or ns.T("batchNoPrice"))
    row.sum:SetTextColor(unpack(K.theme[(sum and (line.best and "positive" or "text")) or "negative"]))
    local measured = row.sum.GetStringWidth and row.sum:GetStringWidth()
    local sumWidth = sum == "" and 0 or math.min(SUM, measured and math.ceil(measured) + 2 or 100)
    row.sum:SetWidth(math.max(1, sumWidth))
    row.frame.text:SetWidth(math.max(1, inner - x - 48 - sumWidth - 6))
    row.expand:ClearAllPoints(); row.expand:SetPoint("LEFT", row.frame, "LEFT", x, 0)
    row.expand:SetText(host.open[line.key] and "-" or "+")
    if line.children then row.expand:Show() else row.expand:Hide() end
end
function Panel:Lay(width)
    local inset = K.theme.inset
    local inner = width - 2 * inset
    self.child:SetWidth(width)
    self.head:ClearAllPoints(); self.head:SetPoint("TOPLEFT", self.child, "TOPLEFT", inset, -6); self.head:Show()
    local y = 26
    for i, row in ipairs(self.rows) do
        local line = self.lines[i]
        if line then
            Panel.RenderLine(self, row, line, inner)
            row.frame:ClearAllPoints(); row.frame:SetPoint("TOPLEFT", self.child, "TOPLEFT", inset, -y); row.frame:Show()
            y = y + 32
        else row.frame:Hide(); row.line = nil end
    end
    y = y + 4
    self.height = y
    self.child:SetHeight(y)
    return y
end
function Panel.Exact(id, n)
    local depth = ns.Markets.Depth(id)
    if not depth or #depth.levels == 0 then return nil, 0 end
    local cost, left = 0, n
    for _, level in ipairs(depth.levels) do
        if left <= 0 then break end
        local take = math.min(left, level.units)
        cost, left = cost + take * level.price, left - take
    end
    return cost, n - left
end
function Panel:Controls()
    local id = self.props.id
    if not id then return end
    local busy = ns.Trader and ns.Trader.Busy and ns.Trader.Busy() or ns.Buy.Active()
    local reason = ns.vendorPrices[id] and ns.T("cacheVendor") or busy and ns.T("batchBusy") or nil
    local n = self.quantity
    if not self.edit:HasFocus() then self.edit:SetText(tostring(n)) end
    local width = ((self.band.inspector and self.band.inspector.width) or 264) - 2 * K.theme.inset
    local room = width - 52 - 4 - 26
    local wide = self.segments[1]
    local shown = (wide.frame:GetWidth() or 0) <= room and wide or self.segments[2]
    for _, seg in ipairs(self.segments) do if seg == shown then seg.frame:Show() else seg.frame:Hide() end end
    shown:Select(n)
    self.band:SetProps({top = self.buyRow, inline = true, actions = {{key = "buy", label = ns.T("obtainBuy"),
        title = ns.T("obtainBuyTitle"), tip = ns.T("obtainBuyTip", n), main = true, reason = reason,
        fn = function()
            K.FlushEdits(self.edit)
            if ns.BuyModal then ns.BuyModal.Open({{id = id, need = self.quantity}}) end
        end}},
        summary = self:Summary(id, n)})
    local _, button = self.band:Find("buy")
    self.buy = button
end
function Panel:Summary(id, n)
    local cost, covered = Panel.Exact(id, n)
    local text, tip
    if cost then
        text = K.Money(cost)
        if covered < n then text = text .. "  " .. K.Colored(ns.T("obtainShort", covered), "negative") end
        tip = ns.T("obtainExactTip", covered)
    elseif self.price then text, tip = K.About(self.price * n), ns.T("obtainAboutTip")
    else text, tip = ns.T("batchNoPrice"), ns.T("obtainAboutTip") end
    return {text = text, title = ns.T("obtainTotalTitle"), tip = tip}
end
