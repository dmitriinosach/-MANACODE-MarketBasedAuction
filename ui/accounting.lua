local _, ns = ...
local UI = {all = {}, serial = 0}
UI.__index = UI
ns.AccountingUI = UI
local F = ns.AccountingFeed
local VIEWS = {"feed", "stock", "stats"}
local PERIODS = {{key = "day", days = 1}, {key = "week", days = 7}, {key = "month", days = 30}, {key = "all"}}
local KINDS = {"purchase", "disenchant", "prospect", "mill", "craft", "use", "post", "sale"}
local FATES = {"converted", "used", "stock", "posted", "sold", "mail"}
local METHODS = {"disenchant", "prospect", "mill", "craft"}
local HEADERS = {feed = {"lead", "item", "cost", "value", "result"}, stock = {"lead", "item", "cost", "value", "result"},
    stats = {"item", "sample", "cost", "fact", "result", "model"}}
local PLAIN = {purchase = true, use = true, post = true}
local DISENCHANT = 130
local function money(value, about)
    local K = ns.TradeKit
    if not value then return ns.T("tradeNoPrice") end
    return about and K.About(value) or K.Money(value)
end
function UI:SetProps(props)
    for key, value in pairs(props) do self.props[key] = value end
    self.table:ResetScroll(); self:Render()
end
function UI.Act(value, err)
    if not value then ns.say(ns.T(err or "acInvalid"), "bad") end
    return value and true or false
end
function UI.Form(title, fields, submit, tip)
    local K = ns.TradeKit
    local form = UI.form
    if not form then
        form = {fields = {}}
        UI.form = form
        local dialog = K.Window(UIParent, "", 440, 310)
        form.dialog = dialog
        for index = 1, 4 do
            local label = K.Label(dialog, "", 16, -44 - (index - 1) * 48, 400)
            local edit = K.Edit(dialog, 400); edit:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -60 - (index - 1) * 48)
            form.fields[index] = {label = label, edit = edit}
        end
        form.tip = K.Label(dialog, "", 16, -244, 400, "secondary"); form.tip:SetHeight(32)
        form.error = K.Label(dialog, "", 16, 0, 400)
        form.error:ClearAllPoints(); form.error:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 16, 42)
        form.error:SetHeight(30)
        form.error:SetTextColor(unpack(K.theme.negative))
        form.submit = K.Button(dialog, ns.T("acSave"), 110, function()
            local values = {}
            for index, field in ipairs(form.spec) do values[field.key] = form.fields[index].edit:GetText() end
            local result, err = form.run(values)
            if result then dialog:Hide() else form.error:SetText(ns.T(err or "acInvalid")) end
        end, "main")
        form.submit:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -16, 12)
    end
    form.spec, form.run = fields, submit
    form.dialog.heading:SetText(title)
    for index, widgets in ipairs(form.fields) do
        local field = fields[index]
        if field then
            widgets.label:SetText(ns.T(field.label)); widgets.edit:SetText(field.value or "")
            widgets.label:Show(); widgets.edit:Show()
        else widgets.label:Hide(); widgets.edit:Hide() end
    end
    form.dialog:SetHeight(#fields * 48 + 150)
    form.tip:ClearAllPoints(); form.tip:SetPoint("TOPLEFT", form.dialog, "TOPLEFT", 16, -48 - #fields * 48)
    form.tip:SetText(tip or ""); form.error:SetText("")
    form.dialog:Show()
end
function UI.Purchase()
    UI.Form(ns.T("acAddPurchase"), {{key = "item", label = "acItemInput"}, {key = "count", label = "acQuantity", value = "1"},
        {key = "price", label = "acTotalGold"}}, function(values)
        local link = values.item:find("item:", 1, true) and values.item or nil
        local itemID, suffix = ns.Lot.FromLink(link)
        itemID = itemID or tonumber(values.item)
        local A = ns.Accounting
        local plan, model = A.Intent(itemID, link)
        if not plan then return nil, "acItemUnknown" end
        local _, _, quality, level = ns.Compat.ItemInfo(link or itemID)
        local id, err = A.Buy({itemID = itemID, suffix = suffix, link = link, count = tonumber(values.count),
            cost = A.Price(values.price), level = model and model.level or level, quality = model and model.quality or quality,
            band = model and model.band, plan = plan}, "manual")
        if id then A.Receive(id, tonumber(values.count), "manual") end
        return id, err
    end, ns.T("acPurchaseTip"))
end
function UI.Output(chain)
    local A = ns.Accounting
    local method = A.ValidMethod(chain.plan) and chain.plan or "craft"
    local units = (method == "prospect" or method == "mill") and math.min(ns.Prospect.OPERATION, chain.count - chain.processed) or 1
    UI.Form(ns.T("acManualDE"), {{key = "item", label = "acMaterialInput"}, {key = "count", label = "acQuantity"}}, function(values)
        local itemID = ns.Lot.FromLink(values.item) or tonumber(values.item)
        return A.Convert({method = method, inputs = {{chain = chain.id, count = units}},
            outputs = {{itemID = itemID, count = tonumber(values.count)}}}, "manual")
    end, ns.T("acManualDETip", units))
end
function UI.SaleCount(sale)
    UI.Form(ns.T("acSaleCount"), {{key = "count", label = "acQuantity"}}, function(values)
        return ns.Accounting.SaleCount(sale.id, tonumber(values.count))
    end, ns.T("acSaleCountTip", ns.Markets.Name(sale.itemID), ns.TradeKit.Money(sale.gross)))
end
function UI:Since()
    for _, period in ipairs(PERIODS) do
        if period.key == self.props.period and period.days then return time() - period.days * 86400 end
    end
    return 0
end
function UI:FeedOptions()
    return {scope = self.scoped and self.props.scope or "character", since = self:Since()}
end
local function traderShown()
    return ns.Trader ~= nil and ns.Trader.frame ~= nil and ns.Trader.frame:IsShown() and true or false
end
function UI.OpenRecipe(recipe)
    if not ns.Trader then return end
    if recipe.family then ns.Trader.OpenFamily(recipe.family, recipe.raw); return end
    ns.Trader.OpenRecipe(recipe.profession, recipe.raw)
end
function UI:Opened(key)
    local set = self.opened[key]
    if set == nil then return key == self.parentKey end
    return set
end
function UI:Toggle(key)
    self.opened[key] = not self:Opened(key)
    local selected = self.index[self.sel[self.props.view] or ""]
    if not self.opened[key] and selected and selected.parent == key then self.sel[self.props.view] = key end
    self:Render()
end
function UI:Select(key)
    self.sel[self.props.view] = key
    if self.opened[key] == false then self.opened[key] = nil end
    self:Render()
end
function UI:Shortcut(kind)
    local off = {}
    for _, key in ipairs(KINDS) do off[key] = key ~= kind or nil end
    self:SetProps({view = "feed", off = off})
end
function UI:Only()
    local only
    for _, kind in ipairs(KINDS) do
        if self.kinds and self.kinds[kind] and not self.props.off[kind] then
            if only then return nil end
            only = kind
        end
    end
    return only
end
local function side(list, total)
    local top, units = list[1], 0
    if not top then return nil, nil end
    for _, item in ipairs(list) do
        units = units + (item.count or 0)
        if (item.count or 0) > (top.count or 0) then top = item end
    end
    local name = ns.Markets.Name(top.itemID)
    if #list > 1 and total then return ns.T("acFeedMany", units), top end
    if not top.count then return ns.T("acFeedUnknown", name), top end
    if #list > 1 then return ns.T("acFeedMore", name, top.count, #list - 1), top end
    return ns.T("acFeedOne", name, top.count), top
end
local function fateShort(fate)
    local parts = {}
    for _, key in ipairs(FATES) do
        if (fate[key] or 0) > 0 then parts[#parts + 1] = ns.T("acFateShort_" .. key, fate[key]) end
    end
    return table.concat(parts, ", ")
end
local function feedCells(row)
    local K = ns.TradeKit
    local cells = {lead = {date("%d.%m %H:%M", row.to), "secondary"}}
    if row.kind ~= "post" then cells.cost = {money(row.invested, row.estimated), row.invested and "text" or "secondary"} end
    if PLAIN[row.kind] then return cells end
    cells.value = {money(row.got, row.basis == "now"), row.basis == "sold" and "text" or "secondary"}
    cells.result = {money(row.result, row.estimated or row.basis == "now"), K.Tone(row.result)}
    return cells
end
local function partCells(row, item)
    if row.kind == "purchase" then
        if item.basis == "free" then return {cost = {ns.T("acFree"), "secondary"}} end
        return {cost = {money(item.cost, item.basis == "model" or item.basis == "vendor"), "text"}}
    end
    return {value = {money(item.value, item.basis == "now"), item.basis == "sold" and "text" or "secondary"}}
end
function UI:FeedLines()
    local rows = F.Feed(self:FeedOptions())
    local kinds, count, off = {}, 0, self.props.off
    for _, row in ipairs(rows) do
        if not kinds[row.kind] then kinds[row.kind] = true; count = count + 1 end
    end
    self.kinds, self.kindCount = kinds, count
    local any = false
    for kind in pairs(kinds) do any = any or not off[kind] end
    if not any or count < 2 then for kind in pairs(kinds) do off[kind] = nil end end
    local lines, sources, seen = {}, {}, {}
    for _, row in ipairs(rows) do
        if not off[row.kind] then
            local key = "f" .. row.owner.key .. ":" .. row.id
            local from, top = side(row.inputs, #row.outputs > 0)
            local to, main = side(row.outputs, false)
            local opened = #row.outputs > 0 and self:Opened(key)
            local shown = main or top or {}
            local cells = feedCells(row)
            lines[#lines + 1] = {key = key, row = row, mode = "feed", id = shown.itemID, link = shown.link,
                spent = PLAIN[row.kind] and cells.cost or nil,
                label = from and to and ns.T("acFeedArrow", from, to) or from or to,
                tag = ns.T(row.unsure and "acFeedUnsure" or ("acKind_" .. row.kind)), tagTone = row.unsure and "accent" or "secondary",
                tree = #row.outputs > 0, expandable = #row.outputs > 0, opened = opened, cells = cells}
            for _, item in ipairs(opened and row.outputs or {}) do
                local part = partCells(row, item)
                lines[#lines + 1] = {key = key .. ">" .. item.itemID, parent = key, row = row, part = item, mode = "feed",
                    spent = part.cost,
                    id = item.itemID, link = item.link, nested = true, depth = 1, wide = true,
                    label = ns.T("acFeedOne", ns.Markets.Name(item.itemID), item.count),
                    tag = fateShort(item.fate), cells = part}
            end
            for _, list in ipairs(row.incomplete and {row.inputs, row.outputs} or {}) do
                for _, item in ipairs(list) do
                    local missing = list == row.inputs and item.cost == nil or list == row.outputs and item.value == nil
                    if missing and not seen[item.itemID] then seen[item.itemID] = true; sources[#sources + 1] = item.itemID end
                end
            end
        end
    end
    self.sources = sources
    return lines, "acEmpty_feed"
end
function UI:StockLines()
    local K = ns.TradeKit
    F.Remember()
    local rows, mode = F.Stock()
    local lines, sources, seen = {}, {}, {}
    local function source(id)
        if not seen[id] then seen[id] = true; sources[#sources + 1] = id end
    end
    for _, row in ipairs(rows) do
        local key = "s" .. row.itemID
        local opened = self:Opened(key)
        source(row.itemID)
        lines[#lines + 1] = {key = key, stock = row, option = row.sell, mode = "stock", id = row.itemID,
            tree = true, expandable = true, opened = opened, tag = row.haveAge and K.Ago(row.haveAge) or nil, tagWidth = 100,
            cells = {lead = {tostring(row.count)}, cost = {money(row.cost, row.estimated), row.cost and "text" or "secondary"},
                value = {money(row.value), row.value and "text" or "secondary"},
                result = {money(row.result, row.estimated), K.Tone(row.result)}}}
        for index, option in ipairs(row.options) do
            local recipe = option.recipe
            if recipe then
                source(recipe.raw)
                for _, input in ipairs(option.inputs) do source(input.itemID) end
            end
            if opened then
                local line = {key = key .. ">" .. index, parent = key, stock = row, option = option, mode = "stock",
                    id = recipe and recipe.raw or row.itemID, nested = true, depth = 1}
                if recipe then
                    line.tag = option.known == false and ns.T("craftRecipeUnknown") or ns.T("acStockPer", option.per)
                    line.cells = {lead = {ns.T("tipItemCount", option.crafts), "secondary"},
                        cost = {money(option.cost, option.market), option.cost and "text" or "secondary"},
                        value = {money(option.revenue), option.revenue and "text" or "secondary"},
                        result = {money(option.profit, option.market), K.Tone(option.profit)}}
                else
                    line.label = ns.T("acStockSellRow")
                    line.cells = {lead = {tostring(option.count), "secondary"},
                        cost = {money(option.cost, row.estimated), option.cost and "text" or "secondary"},
                        value = {money(option.net), option.net and "text" or "secondary"},
                        result = {money(option.result, row.estimated), K.Tone(option.result)}}
                end
                lines[#lines + 1] = line
            end
        end
    end
    self.sources = sources
    return lines, mode and "acStockListEmpty" or "acStockEmpty"
end
local function yieldTitle(row)
    if row.by == "level" then return ns.T("acByLevelTitle", row.key) end
    if row.by ~= "band" then return nil end
    local band = ns.Disenchant.Band(row.key)
    local kind = band and ns.DisenchantUI and ns.DisenchantUI.BandKind and ns.DisenchantUI.BandKind(band)
    return band and kind and ns.T("deBandHeader", kind, band.minLevel, band.maxLevel) or tostring(row.key)
end
local function yieldCell(units, share)
    local K = ns.TradeKit
    if not units then return ns.T("tradeNoPrice") end
    return ns.T("acStatOutput", K.Decimal(units, 2, false, true), K.Chance(share or 0))
end
function UI:StatsLines()
    local K, p = ns.TradeKit, self.props
    local found, count = {}, 0
    for _, method in ipairs(METHODS) do
        local rows = F.Yields(method, method == "disenchant" and p.by or nil)
        if #rows > 0 then found[method] = rows; count = count + 1 end
    end
    if not found[p.method] then
        for _, method in ipairs(METHODS) do if found[method] then p.method = method; break end end
    end
    self.methods, self.methodCount = found, count
    local lines = {}
    for _, row in ipairs(found[p.method] or {}) do
        local key = "y" .. row.method .. row.by .. ":" .. tostring(row.key)
        local opened = #row.outputs > 0 and self:Opened(key)
        local tone = row.small and "secondary" or "text"
        lines[#lines + 1] = {key = key, yield = row, mode = "stats", id = row.itemID, link = row.link, quality = row.quality,
            title = yieldTitle(row), tag = row.small and ns.T("acStatSmall") or nil,
            tree = #row.outputs > 0, expandable = #row.outputs > 0, opened = opened,
            cells = {sample = {K.Decimal(row.count, 1, false, true), tone},
                cost = {money(row.buyout), row.buyout and tone or "secondary"},
                fact = {money(row.got), row.got and tone or "secondary"},
                result = {money(row.result), K.Tone(row.result)},
                model = {money(row.expectedGot), "secondary"}}}
        for _, output in ipairs(opened and row.outputs or {}) do
            local expected = {yieldCell(output.expected, output.chance), "secondary"}
            lines[#lines + 1] = {key = key .. ">" .. output.itemID, parent = key, yield = row, mode = "stats",
                id = output.itemID, nested = true, depth = 1, expected = expected,
                cells = {fact = {yieldCell(output.average, output.rate), tone}, model = expected}}
        end
    end
    self.sources = {}
    return lines, "acEmpty_stats"
end
function UI:Lines()
    local view = self.props.view
    local selected = self.sel[view]
    self.parentKey = selected and (selected:match("^(.-)>") or selected) or nil
    local lines, empty
    if view == "stock" then lines, empty = self:StockLines()
    elseif view == "stats" then lines, empty = self:StatsLines()
    else lines, empty = self:FeedLines() end
    self.index = {}
    for _, line in ipairs(lines) do self.index[line.key] = line end
    return lines, empty
end
local function undoTarget(row, p, shared)
    local own = {}
    for _, id in ipairs(row.events) do own[id] = true end
    local events = ns.Accounting.Book().events
    for index = #events, 1, -1 do
        local event = events[index]
        local mine = own[event.id] or (event.kind == "count" and own[event.target])
        if mine and ns.Accounting.Reversible(p, event) and (not shared or ns.Accounting.Reversible(shared, event)) then
            return event
        end
    end
end
function UI:FeedActions(row)
    local A, actions = ns.Accounting, {}
    if not row.owner.current then return actions end
    local own = A.Project()
    local shared = ns.AccountingPool.View()
    local p = shared or own
    if row.kind == "purchase" then
        local unsure, mail, bag
        for _, id in ipairs(row.events) do
            local chain = p.byChain[id]
            if chain and chain.stage == "unsure" then unsure = unsure or chain
            elseif chain and chain.stage == "mail" then mail = mail or chain
            elseif chain and chain.stage == "bag" then bag = bag or chain end
        end
        if unsure then
            actions[#actions + 1] = {key = "won", label = ns.T("acWon"), tip = ns.T("acWonTip"),
                fn = function() UI.Act(A.Resolve(unsure.id, true, "manual")) end}
            actions[#actions + 1] = {key = "lost", label = ns.T("acLost"), tip = ns.T("acLostTip"),
                fn = function() UI.Act(A.Resolve(unsure.id, false, "manual")) end}
        end
        if mail then
            actions[#actions + 1] = {key = "receive", label = ns.T("acReceive"), tip = ns.T("acReceiveTip"),
                fn = function() UI.Act(A.Receive(mail.id, mail.count - mail.received, "manual")) end}
        end
        if bag then
            actions[#actions + 1] = {key = "output", label = ns.T("acOutputButton"), tip = ns.T("acOutputButtonTip"),
                fn = function() UI.Output(bag) end}
        end
    elseif row.kind == "sale" then
        for _, id in ipairs(row.events) do
            local sale = p.bySale[id]
            if sale and not sale.count then
                actions[#actions + 1] = {key = "count", label = ns.T("acSaleCountButton"), tip = ns.T("acSaleCountButtonTip"),
                    fn = function() UI.SaleCount(sale) end}
                break
            end
        end
    end
    local undo = undoTarget(row, own, shared)
    if undo then
        actions[#actions + 1] = {key = "undo", label = ns.T("acUndo"), tip = ns.T("acUndoTip"),
            fn = function() UI.Act(A.Reverse(undo.id)) end}
    end
    while #actions > 3 do table.remove(actions, 3) end
    return actions
end
function UI:FeedFacts(row)
    local K, facts = ns.TradeKit, {}
    if self.scoped and self.props.scope == "account" then
        facts[#facts + 1] = {label = ns.T("acFactOwner"), value = row.owner.name}
    end
    if row.kind == "post" then
        facts[#facts + 1] = {label = ns.T("acFactAsk"), value = money(row.ask)}
        facts[#facts + 1] = {label = ns.T("acFactActive"), value = tostring(row.active or 0)}
    else
        facts[#facts + 1] = {label = ns.T("acCol_feed_cost"), value = money(row.invested, row.estimated),
            tone = row.invested and "text" or "secondary"}
    end
    if not PLAIN[row.kind] then
        facts[#facts + 1] = {label = ns.T("acCol_feed_value"), value = money(row.got, row.basis == "now"),
            tone = row.basis == "sold" and "text" or "secondary"}
        facts[#facts + 1] = {label = ns.T("acCol_feed_result"), strong = true,
            value = money(row.result, row.estimated or row.basis == "now"), tone = K.Tone(row.result)}
    end
    for index, item in ipairs(row.outputs) do
        local cells = partCells(row, item)
        local cell = cells.value or cells.cost
        facts[#facts + 1] = {id = item.itemID, count = item.count, value = cell[1], tone = cell[2], gap = index == 1}
        for _, key in ipairs(FATES) do
            if (item.fate[key] or 0) > 0 then
                facts[#facts + 1] = {label = ns.T("acFate_" .. key), value = tostring(item.fate[key]), sub = true}
            end
        end
    end
    return facts
end
local function jump(key, label, tip, fn)
    return {{key = key, label = label, tip = tip, reason = not traderShown() and ns.T("deBuyClosed") or nil, fn = fn}}
end
function UI:StockPanel(row, option)
    local K, facts = ns.TradeKit, {}
    local recipe = option.recipe
    if not recipe then
        facts[#facts + 1] = {label = ns.T("acCol_stock_lead"), value = tostring(row.have)}
        if row.posted > 0 then facts[#facts + 1] = {label = ns.T("acFate_posted"), value = tostring(row.posted)} end
        if row.remembered then
            facts[#facts + 1] = {label = ns.T("acStockAlts"),
                value = row.remembered .. "  " .. K.Colored(K.Ago(row.haveAge), "secondary")}
        elseif row.alts > 0 then facts[#facts + 1] = {label = ns.T("acStockAlts"), value = tostring(row.alts)} end
        facts[#facts + 1] = {label = ns.T("acStockUnit"), value = money(row.unit, row.estimated), gap = true,
            tone = row.unit and "text" or "secondary"}
        facts[#facts + 1] = {label = ns.T("acStockPrice"), value = money(row.price), tone = row.price and "text" or "secondary"}
        facts[#facts + 1] = {label = ns.T("acCol_stock_result"), strong = true, gap = true,
            value = money(row.result, row.estimated), tone = K.Tone(row.result)}
        return facts, jump("sell", ns.T("acStockSell"), ns.T("acStockSellTip"), function() ns.Trader.OpenSell(row.itemID) end)
    end
    facts[#facts + 1] = {label = ns.T("acStockCrafts"), value = tostring(option.crafts)}
    for index, input in ipairs(option.inputs) do
        facts[#facts + 1] = {id = input.itemID, value = input.have .. " / " .. input.need, gap = index == 1,
            tone = input.extra > 0 and "secondary" or "text"}
        if input.extra > 0 then
            facts[#facts + 1] = {label = ns.T("acStockBuy"), sub = true,
                value = ns.T("tipItemCount", input.extra) .. "  " .. money(input.price and input.price * input.extra),
                tone = input.price and "text" or "secondary"}
        end
    end
    local status = option.known == true and ns.T("craftRecipeKnown")
        or (#option.owners > 0 and table.concat(option.owners, ", "))
        or ns.T(option.known == false and "craftRecipeUnknown" or "craftRecipeUnchecked")
    facts[#facts + 1] = {label = ns.T("acStockRecipe"), value = status, gap = true, tone = option.known == true and "text" or "secondary"}
    facts[#facts + 1] = {label = ns.T("acCol_stock_cost"), value = money(option.cost, option.market), gap = true,
        tone = option.cost and "text" or "secondary"}
    facts[#facts + 1] = {label = ns.T("acCol_stock_value"), value = money(option.revenue), tone = option.revenue and "text" or "secondary"}
    facts[#facts + 1] = {label = ns.T("acCol_stock_result"), strong = true, value = money(option.profit, option.market),
        tone = K.Tone(option.profit)}
    return facts, jump("recipe", ns.T("nextOpenRecipe"), ns.T("nextOpenRecipeTip"), function() UI.OpenRecipe(recipe) end)
end
function UI:Panel(line)
    local K = ns.TradeKit
    local facts, actions = {}, {}
    if line and line.row then
        facts, actions = self:FeedFacts(line.row), self:FeedActions(line.row)
    elseif line and line.stock then
        facts, actions = self:StockPanel(line.stock, line.option)
    elseif line and line.yield then
        local row = line.yield
        facts = {{label = ns.T("acStatSample"), value = K.Decimal(row.count, 1, false, true)},
            {label = ns.T(row.method == "craft" and "acStatBuyoutCraft" or "acStatBuyout"), value = money(row.buyout),
                tone = row.buyout and "text" or "secondary"},
            {label = ns.T("acStatGot"), value = money(row.got), tone = row.got and "text" or "secondary"}}
        if row.method ~= "craft" then
            facts[#facts + 1] = {label = ns.T("acCol_stats_model"), value = money(row.expectedGot), tone = "secondary"}
            facts[#facts + 1] = {label = ns.T("acStatLuck"), value = row.luck and K.Chance(row.luck / 100) or ns.T("tradeNoPrice"),
                tone = row.luck and K.Tone(row.luck - 100) or "secondary"}
        end
        facts[#facts + 1] = {label = ns.T("acStatResult", K.Decimal(row.costed, 1, false, true)), strong = true, gap = true,
            value = money(row.result), tone = K.Tone(row.result)}
    end
    if line and line.id then self.inspector:SetProps({id = line.id, link = line.link})
    else self.inspector:Clear() end
    self.band:SetProps({actions = actions})
    local width = self.inspector.width or 264
    self.facts:SetProps({rows = facts, width = width, top = 4})
    local fitted = self.panelScroll:Fit(self.facts.height + 8)
    if fitted ~= width then
        self.facts:SetProps({rows = facts, width = fitted, top = 4})
        self.panelScroll:Fit(self.facts.height + 8)
    end
end
function UI:Tiles()
    local K, view = ns.TradeKit, self.props.view
    local s = F.Summary(self:FeedOptions())
    local only = view == "feed" and self:Only() or nil
    local none, click = ns.T("tradeNoPrice"), ns.T("scanKeyClick")
    local function accent(active) return active and K.theme.gold or K.theme.edge end
    local total = (s.list ~= nil or s.purchases == 0 and s.sales > 0) and s.total or nil
    return {
        {title = ns.T("acTileInvested"), value = s.purchases > 0 and K.Money(s.invested) or none, compact = true,
            tip = ns.T("acTileInvestedTip"), accent = accent(only == "purchase"),
            click = s.purchases > 0 and function() self:Shortcut("purchase") end or nil,
            keys = {{key = click, text = ns.T("acTileKeyBought")}}},
        {title = ns.T("acStock"), value = s.list and money(s.stock, s.incomplete) or none, compact = true,
            tip = ns.T("acStockTip"), accent = accent(view == "stock"),
            click = function() self:SetProps({view = "stock"}) end, keys = {{key = click, text = ns.T("acTileKeyStock")}}},
        {title = ns.T("acSold"), value = s.sales > 0 and K.Money(s.sold) or none, compact = true,
            tip = ns.T("acSoldTip"), accent = accent(only == "sale"),
            click = s.sales > 0 and function() self:Shortcut("sale") end or nil,
            keys = {{key = click, text = ns.T("acTileKeySold")}}},
        {title = ns.T("acTileTotal"), value = total and money(total, s.incomplete) or none, compact = true,
            tip = ns.T("acTileTotalTip"), accent = accent(false), valueTone = K.Tone(total)},
    }
end
local function listEntries()
    local C = ns.Collections
    local entries = {{key = "favorites", labelKey = "collectionFavorites"}, {key = "tracked", labelKey = "collectionTracked"}}
    local lists = C.Lists()
    if #lists > 0 then entries[#entries + 1] = {divider = true} end
    for index, list in ipairs(lists) do entries[#entries + 1] = {key = C.ListMode(index), label = list.name} end
    return entries
end
function UI:Head()
    local p, view = self.props, self.props.view
    local filters, actions = {}, {}
    self.views:Select(view)
    for _, frame in ipairs(self.headFrames) do frame:Hide() end
    if view == "feed" then
        self.periods:Select(p.period)
        filters[#filters + 1] = self.periods.frame
        for _, kind in ipairs(self.kindCount > 1 and KINDS or {}) do
            if self.kinds[kind] then
                self.chips[kind]:SetChecked(not p.off[kind])
                filters[#filters + 1] = self.chips[kind]
            end
        end
        if self.scoped then
            self.scope:Select(p.scope)
            filters[#filters + 1] = self.scope.frame
        end
        actions = {self.disenchantSlot, self.intake}
    elseif view == "stock" then
        local mode, name = F.StockList()
        self.listMenu:SetEntries(listEntries())
        self.listMenu.frame:SetText(name or (mode and ns.T(mode == "favorites" and "collectionFavorites" or "collectionTracked"))
            or ns.T("acStockPick"))
        filters[1] = self.listMenu.frame
    else
        if self.methodCount > 1 then
            local labels = {}
            for method in pairs(self.methods) do labels[method] = ns.T("acMethod_" .. method) end
            self.method:Arrange(labels); self.method:Select(p.method)
            filters[#filters + 1] = self.method.frame
        end
        if p.method == "disenchant" and self.methods.disenchant then
            self.by:Select(p.by)
            filters[#filters + 1] = self.by.frame
        end
    end
    for _, frame in ipairs(filters) do frame:Show() end
    for _, frame in ipairs(actions) do frame:Show() end
    self.sectionHead:SetProps({lead = self.views.frame, filters = filters, actions = actions})
    self:PlaceDisenchant(view == "feed")
end
function UI:PlaceDisenchant(shown)
    local b = self.disenchant
    if not b or InCombatLockdown() then return end
    if not shown then b:Hide(); return end
    b:ClearAllPoints()
    b:SetPoint("TOPRIGHT", self.sectionHead.frame, "TOPRIGHT", -(6 + (self.intake:GetWidth() or 0) + 4), -2)
    b:Show()
end
function UI:Bar()
    if self.barred and self.props.view ~= "stats" and #self.sources > 0 then return self.barFrames end
end
function UI:ScanSources()
    return self.sources
end
function UI:Controls()
    local busy = ns.Scan.state.phase ~= "idle" or ns.Batch.job ~= nil or ns.Buy.Active()
    self.scan:SetBusy(busy and ns.T("batchBusy") or nil)
end
function UI:Render()
    if not self.frame or not self.frame:IsVisible() then return end
    local K, p = ns.TradeKit, self.props
    local busy = ns.Scan.state.phase ~= "idle" or ns.Batch.job ~= nil or ns.Buy.Active()
    if self.busy and not busy then F.Reset() end
    self.busy = busy
    self.scoped = #F.Owners() > 1
    local view = p.view
    local lines, empty = self:Lines()
    if not self.index[self.sel[view] or ""] then
        self.sel[view] = lines[1] and lines[1].key or nil
        lines, empty = self:Lines()
    end
    local selected = self.index[self.sel[view] or ""]
    self:Head()
    local head = K.FontHeight(K.SectionHead.HEIGHT)
    K.ScreenBody(self.table, self.inspector, self.sectionHead, K.TileRow(self.frame, self.tiles, head, self:Tiles()))
    for _, key in ipairs(HEADERS[view]) do
        local label = ns.T("acCol_" .. view .. "_" .. key)
        if view == "stats" and key == "cost" and p.method == "craft" then label = ns.T("acCol_stats_costCraft") end
        self.table.headers[key]:SetText(label)
    end
    self.table:SetLines(lines, function(line, _, columns)
        line.active = line.key == self.sel[view]
        if line.wide then line.tagWidth = math.min(190, math.floor(columns.item[2] / 2)) end
        if line.expected then line.cells.result = not columns.model and line.expected or nil end
        if line.spent then line.cells.result = not columns.cost and {line.spent[1], "secondary"} or nil end
        return line
    end, {mode = view, empty = empty})
    self:Panel(selected)
    self.scan:SetText(ns.T("acView_" .. (view == "stock" and "stock" or "feed")))
    self.scan.tipTitle = self.scan:GetText()
    K.FitButton(self.scan, 20)
    self:Controls()
    if self.barred and ns.Trader and ns.Trader.RenderStatus then ns.Trader.RenderStatus() end
end
function UI:NewHead(f)
    local K = ns.TradeKit
    self.sectionHead = K.SectionHead:New(f)
    local entries = {}
    for _, key in ipairs(VIEWS) do entries[#entries + 1] = {key = key, label = ns.T("acView_" .. key)} end
    self.views = K.Segment(f, entries, function(key) self:SetProps({view = key}) end)
    entries = {}
    for _, period in ipairs(PERIODS) do entries[#entries + 1] = {key = period.key, label = ns.T("acPeriod_" .. period.key)} end
    self.periods = K.Segment(f, entries, function(key) self:SetProps({period = key}) end)
    self.chips = {}
    for _, kind in ipairs(KINDS) do
        self.chips[kind] = K.Chip(f, ns.T("acKind_" .. kind), function(checked)
            self.props.off[kind] = not checked or nil
            self.table:ResetScroll(); self:Render()
        end)
    end
    self.scope = K.Segment(f, {{key = "character", label = ns.T("acHistoryCharacter")},
        {key = "account", label = ns.T("acHistoryAccount")}}, function(key) self:SetProps({scope = key}) end)
    self.listMenu = K.Menu(f, {}, function(key)
        F.SetStockList(key)
        self.sel.stock = nil
        self.table:ResetScroll(); self:Render()
    end)
    entries = {}
    for _, method in ipairs(METHODS) do entries[#entries + 1] = {key = method, label = ns.T("acMethod_" .. method)} end
    self.method = K.Segment(f, entries, function(key) self:SetProps({method = key}) end)
    self.by = K.Segment(f, {{key = "item", label = ns.T("acBy_item")}, {key = "level", label = ns.T("acBy_level")},
        {key = "band", label = ns.T("acBy_band")}}, function(key) self:SetProps({by = key}) end)
    self.intake = K.Button(f, ns.T("acIntakeButton"), 110, function() UI.Intake() end, "quiet")
    K.FitButton(self.intake, 24)
    K.Tooltip(self.intake, ns.T("acIntakeTitle"), ns.T("acIntakeButtonTip"))
    self.disenchantSlot = ns.NewFrame("Frame", nil, f)
    self.disenchantSlot:SetWidth(DISENCHANT); self.disenchantSlot:SetHeight(22)
    ns.CollectUI.Attach(f, DISENCHANT, function(b) self.disenchant = b; self:PlaceDisenchant(self.props.view == "feed") end)
    self.headFrames = {self.periods.frame, self.scope.frame, self.listMenu.frame, self.method.frame, self.by.frame,
        self.intake, self.disenchantSlot}
    for _, chip in pairs(self.chips) do self.headFrames[#self.headFrames + 1] = chip end
end
function UI:New(parent)
    local K = ns.TradeKit
    UI.serial = UI.serial + 1
    local view = setmetatable({props = {view = "feed", period = "all", scope = "character", method = "disenchant", by = "item",
        off = {}}, tiles = {}, sel = {}, opened = {}, index = {}, sources = {}, kinds = {}, kindCount = 0,
        methods = {}, methodCount = 0}, self)
    local f = ns.NewFrame("Frame", nil, parent); f:SetAllPoints(parent); view.frame = f
    view:NewHead(f)
    for index = 1, 4 do view.tiles[index] = K.StatTile:New(f) end
    local headers = {}
    for _, key in ipairs({"lead", "item", "cost", "value", "result", "sample", "fact", "model"}) do
        headers[#headers + 1] = {key = key}
    end
    view.table = K.Table:New(f, {
        headers = headers, height = K.Table.LINE,
        columns = function(width, _, layout) return K.LedgerColumns(width, layout.mode) end,
        kinds = {row = {new = function(rows)
            return K.LedgerRow:New(rows, function(key) view:Select(key) end, function(key) view:Toggle(key) end)
        end}},
    })
    view.inspector = K.Inspector:New(f)
    view.panelScroll = K.PanelScroll:New(view.inspector, "ManaCodeLedgerPanelScroll" .. UI.serial, 200)
    view.facts = K.FactList:New(view.panelScroll.child)
    view.band = K.ActionBand:For(view.inspector, view.panelScroll)
    view.scan = K.ScanBarButton(f, {label = ns.T("acView_feed"),
        run = function(mode)
            ns.Batch.Complete(view:ScanSources(), mode, true)
            view:Render()
        end,
        sources = function() return view:ScanSources() end,
        body = function() return ns.T(view.props.view == "stock" and "acScanStockTip" or "acScanFeedTip") end})
    view.barFrames = {view.scan}
    f:SetScript("OnSizeChanged", function() view:Render() end)
    f:SetScript("OnShow", function() F.Reset(); view:Render() end)
    self.all[#self.all + 1] = view
    view:Render(); return view
end
local INTAKE_ROWS = 8
local ROW = 24
function UI.Intake()
    local K, A, E = ns.TradeKit, ns.Accounting, ns.AccountingEvents
    local w = UI.intake
    if not w then
        w = {checked = {}, rows = {}, items = {}}
        UI.intake = w
        local frame = K.Window(UIParent, ns.T("acIntakeTitle"), 540, 404)
        w.frame = frame
        w.purchase = K.Button(frame, ns.T("acAddPurchase"), 150, function() UI.Purchase() end, "quiet")
        K.FitButton(w.purchase, 24)
        w.purchase:SetPoint("RIGHT", frame.close, "LEFT", -6, 0)
        K.Tooltip(w.purchase, ns.T("acAddPurchase"), ns.T("acAddPurchaseTip"))
        local hint = K.Label(frame, ns.T("acIntakeHint"), 14, -36, 510, "secondary"); hint:SetHeight(28)
        w.all = K.Check(frame, function(on)
            for _, item in ipairs(w.items) do w.checked[item.key] = on or nil end
            UI.RenderIntake()
        end)
        w.all:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -68)
        K.Label(frame, ns.T("acIntakeAll"), 34, -71, 200, "secondary")
        w.scroll = K.Scroller:New(frame, UI.RenderIntake, ROW)
        w.scroll.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -90)
        w.scroll.frame:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -10, -90 - INTAKE_ROWS * ROW)
        for index = 1, INTAKE_ROWS do
            local row, y = {}, -90 - (index - 1) * ROW
            row.check = K.Check(frame, function(on)
                if row.item then w.checked[row.item.key] = on or nil; UI.RenderIntake() end
            end)
            row.check:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, y - 3)
            row.name = K.ItemChoice(frame, function()
                if row.item then w.checked[row.item.key] = not w.checked[row.item.key] or nil; UI.RenderIntake() end
            end)
            row.name:SetWidth(270); row.name:SetHeight(ROW); row.name.text:SetWidth(240)
            row.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 34, y)
            row.count = K.Label(frame, "", 310, y - 6, 60); row.count:SetJustifyH("RIGHT")
            row.cost = K.Label(frame, "", 376, y - 6, 130); row.cost:SetJustifyH("RIGHT")
            w.scroll:Wheel(row.name)
            w.rows[index] = row
        end
        w.empty = K.Label(frame, ns.T("acIntakeEmpty"), 34, -96, 470, "secondary"); w.empty:SetHeight(40)
        local y = -100 - INTAKE_ROWS * ROW
        K.Label(frame, ns.T("acIntakeBasis"), 14, y, 200, "secondary")
        local bases = {}
        for _, basis in ipairs(A.BASES) do bases[#bases + 1] = {key = basis, label = ns.T("acBasis_" .. basis)} end
        w.basisSegment = K.Segment(frame, bases, function(key) w.basis = key; UI.RenderIntake() end,
            {ns.T("acIntakeBasis"), ns.T("acIntakeBasisTip")})
        w.basisSegment.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, y - 16)
        w.own = K.Edit(frame, 80)
        w.own:SetPoint("LEFT", w.basisSegment.frame, "RIGHT", 8, 0)
        K.LiveEdit(w.own, function() UI.RenderIntake() end)
        K.Tooltip(w.own, ns.T("acBasis_own"), ns.T("acIntakeOwnTip"))
        w.total = K.Label(frame, "", 14, y - 46, 510)
        w.error = K.Label(frame, "", 14, y - 64, 380); w.error:SetHeight(30)
        w.error:SetTextColor(unpack(K.theme.negative))
        w.add = K.Button(frame, ns.T("acIntakeAdd"), 110, function()
            local list = {}
            for _, item in ipairs(w.items) do if w.checked[item.key] then list[#list + 1] = item end end
            local own = w.basis == "own" and A.Price(w.own:GetText()) or nil
            local added, err, missing = E.Add(list, w.basis, own)
            if not added then w.error:SetText(ns.T(err or "acInvalid", missing or 0)); return end
            frame:Hide()
            ns.say(ns.T("acIntakeDone", added, ns.T("acBasis_" .. w.basis)), "good")
        end, "main")
        w.add:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 12)
        K.Tooltip(w.add, ns.T("acIntakeAdd"), ns.T("acIntakeAddTip"))
    end
    w.items, w.checked, w.basis = E.Untracked(), {}, "model"
    for _, item in ipairs(w.items) do if item.gift > 0 then w.checked[item.key] = true end end
    w.own:SetText(""); w.error:SetText(""); w.scroll.offset = 0
    w.frame:Show(); UI.RenderIntake()
end
function UI.RenderIntake()
    local w = UI.intake
    if not w or not w.frame:IsShown() then return end
    local K, A = ns.TradeKit, ns.Accounting
    local own = w.basis == "own" and A.Price(w.own:GetText()) or nil
    local offset = w.scroll:SetRange(#w.items, INTAKE_ROWS)
    local pieces, total, missing, all = 0, 0, 0, #w.items > 0
    for _, item in ipairs(w.items) do
        local unit = A.UnitCost(item, w.basis, own)
        item.unit = unit
        if w.checked[item.key] then
            pieces = pieces + item.count
            if unit then total = total + unit * item.count else missing = missing + 1 end
        else all = false end
    end
    for index, row in ipairs(w.rows) do
        local item = w.items[offset + index]
        row.item = item
        if item then
            K.SetItemChoice(row.name, item.itemID, false, item.quality)
            row.name.itemLink = item.link
            row.name.extraTip = item.gift > 0 and ns.T("acFromLine", item.from or "?") or nil
            row.check:SetChecked(w.checked[item.key] == true); row.check:Show()
            row.count:SetText("x" .. item.count)
            local text = w.basis == "free" and ns.T("acFree") or (item.unit and K.Money(item.unit * item.count) or ns.T("tradeNoPrice"))
            row.cost:SetText(text)
            row.cost:SetTextColor(unpack(item.unit and K.theme.text or K.theme.secondary))
        else
            row.name:Hide(); row.check:Hide(); row.count:SetText(""); row.cost:SetText("")
        end
    end
    if #w.items == 0 then w.empty:Show() else w.empty:Hide() end
    w.all:SetChecked(all)
    w.basisSegment:Select(w.basis)
    if w.basis == "own" then w.own:Show() else w.own:Hide() end
    local text = ns.T("acIntakeTotal", pieces, w.basis == "free" and ns.T("acFree") or K.Money(total))
    if missing > 0 then text = text .. " " .. ns.T("acIntakeMissing", missing) end
    if w.basis == "free" and pieces > 0 then text = text .. " " .. ns.T("acFreeWarn") end
    w.total:SetText(text)
    w.error:SetText("")
    if pieces > 0 then w.add:Enable() else w.add:Disable() end
end
function UI.Open()
    if not UI.window then
        local width = math.min(1040, (UIParent:GetWidth() or 1080) - 40)
        local height = math.min(620, (UIParent:GetHeight() or 700) - 60)
        local window = ns.TradeKit.Window(UIParent, ns.T("acTitle"), width, height)
        UI.window = window
        local content = ns.NewFrame("Frame", nil, window)
        content:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -40)
        content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -10, 10)
        UI.standalone = UI:New(content)
    end
    UI.window:Show(); UI.standalone:Render()
end
ns.Accounting.onChange = function()
    for _, view in ipairs(UI.all) do if view.frame:IsVisible() then view:Render() end end
    if ns.MarketBoardUI then ns.MarketBoardUI.Refresh() end
    if ns.CollectUI then ns.CollectUI.Refresh() end
end
