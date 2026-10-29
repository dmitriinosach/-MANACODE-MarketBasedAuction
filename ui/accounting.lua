local _, ns = ...
local UI = {all = {}}
UI.__index = UI
ns.AccountingUI = UI
local PERIODS = {{key = "day", days = 1}, {key = "week", days = 7}, {key = "month", days = 30}, {key = "all"}}
local STAGES = {all = true, wait = {sent = true, unsure = true}, mail = {mail = true}, bag = {bag = true}, done = {done = true}}
local TONE = {sent = "secondary", unsure = "accent", mail = "text", bag = "gold", done = "positive", lost = "negative"}
local ROW = 24
local TABLE_TOP = 180
local function gold(value)
    return ns.TradeKit.Decimal(value / 10000, 4)
end
function UI:SetProps(props)
    for key, value in pairs(props) do self.props[key] = value end
    self.scroll.offset = 0; self:Render()
end
function UI:Result(value, err)
    self.message = value and nil or ns.T(err or "acInvalid")
    self:Render()
    return value and true or false
end
function UI:Form(title, fields, submit, tip)
    local K = ns.TradeKit
    if not self.dialog then
        local dialog = K.Window(UIParent, "", 440, 310)
        self.dialog, self.fields = dialog, {}
        for index = 1, 4 do
            local label = K.Label(dialog, "", 16, -44 - (index - 1) * 48, 400)
            local edit = K.Edit(dialog, 400); edit:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -60 - (index - 1) * 48)
            self.fields[index] = {label = label, edit = edit}
        end
        self.formTip = K.Label(dialog, "", 16, -244, 400, "secondary"); self.formTip:SetHeight(32)
        self.formError = K.Label(dialog, "", 16, 0, 400)
        self.formError:ClearAllPoints(); self.formError:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 16, 42)
        self.formError:SetHeight(30)
        self.formError:SetTextColor(unpack(K.theme.negative))
        self.submit = K.Button(dialog, ns.T("acSave"), 110, function()
            local values = {}
            for index, field in ipairs(self.formFields) do values[field.key] = self.fields[index].edit:GetText() end
            local result, err = self.formSubmit(values)
            if result then dialog:Hide(); self:Result(result) else self.formError:SetText(ns.T(err or "acInvalid")) end
        end, "main")
        self.submit:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -16, 12)
        self.frame:HookScript("OnHide", function() dialog:Hide() end)
    end
    self.formFields, self.formSubmit = fields, submit
    self.dialog.heading:SetText(title)
    for index, widgets in ipairs(self.fields) do
        local field = fields[index]
        if field then
            widgets.label:SetText(ns.T(field.label)); widgets.edit:SetText(field.value or "")
            widgets.label:Show(); widgets.edit:Show()
        else widgets.label:Hide(); widgets.edit:Hide() end
    end
    self.dialog:SetHeight(#fields * 48 + 150)
    self.formTip:ClearAllPoints(); self.formTip:SetPoint("TOPLEFT", self.dialog, "TOPLEFT", 16, -48 - #fields * 48)
    self.formTip:SetText(tip or ""); self.formError:SetText("")
    self.dialog:Show()
end
function UI:Purchase()
    self:Form(ns.T("acAddPurchase"), {{key = "item", label = "acItemInput"}, {key = "count", label = "acQuantity", value = "1"},
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
function UI:Output(chain)
    local A = ns.Accounting
    local method = A.ValidMethod(chain.plan) and chain.plan or "craft"
    local units = (method == "prospect" or method == "mill") and math.min(ns.Prospect.OPERATION, chain.count - chain.processed) or 1
    self:Form(ns.T("acManualDE"), {{key = "item", label = "acMaterialInput"}, {key = "count", label = "acQuantity"}}, function(values)
        local itemID = ns.Lot.FromLink(values.item) or tonumber(values.item)
        return A.Convert({method = method, inputs = {{chain = chain.id, count = units}},
            outputs = {{itemID = itemID, count = tonumber(values.count)}}}, "manual")
    end, ns.T("acManualDETip", units))
end
function UI:Sale(material)
    local A, itemID = ns.Accounting, material.itemID
    self:Form(ns.T("acAddSale"), {
        {key = "count", label = "acQuantity", value = tostring(material.remaining)},
        {key = "gross", label = "acTotalGold"},
        {key = "fee", label = "acFeeGold"},
    }, function(values)
        local gross = A.Price(values.gross)
        local fee = values.fee:match("^%s*$") and gross and math.floor(gross * (A.Book().fee or 0.05)) or A.Price(values.fee)
        return A.Sell({itemID = itemID, count = tonumber(values.count), gross = gross, fee = fee}, "manual")
    end, ns.T("acSaleTip"))
end
function UI:SaleCount(sale)
    self:Form(ns.T("acSaleCount"), {{key = "count", label = "acQuantity"}}, function(values)
        return ns.Accounting.SaleCount(sale.id, tonumber(values.count))
    end, ns.T("acSaleCountTip", ns.Markets.Name(sale.itemID), ns.TradeKit.Money(sale.gross)))
end
function UI:Since()
    for _, period in ipairs(PERIODS) do
        if period.key == self.props.period and period.days then return time() - period.days * 86400 end
    end
    return 0
end
function UI:NewParty()
    local K, A = ns.TradeKit, ns.Accounting
    if not self.partyDialog then
        local dialog = K.Window(UIParent, ns.T("acNewParty"), 450, 180)
        self.partyDialog = dialog
        self.partyCarry = K.Check(dialog, function() end)
        self.partyCarry:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -45)
        K.Label(dialog, ns.T("acPartyCarry"), 38, -49, 390)
        K.Tooltip(self.partyCarry, ns.T("acPartyCarry"), ns.T("acPartyCarryTip"))
        local note = K.Label(dialog, ns.T("acNewPartyTip"), 16, -78, 414, "secondary")
        note:SetHeight(48)
        self.partyStart = K.Button(dialog, ns.T("acPartyStart"), 120, function()
            A.StartParty(self.partyCarry:GetChecked() and true or false)
            dialog:Hide()
            self.message = nil
            self:SetProps({mode = "forecast", plan = "materials", period = "all", stage = "all"})
        end, "main")
        self.partyStart:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -16, 12)
        self.frame:HookScript("OnHide", function() dialog:Hide() end)
    end
    self.partyCarry:SetChecked(true)
    self.partyDialog:Show()
end
function UI:SelectParty(id)
    ns.Accounting.Book().selectedParty = id
    self.message = nil
    self.scroll.offset = 0
    ns.Accounting.Changed()
end
function UI:StepParty(delta)
    local parties = ns.Accounting.Parties()
    local selected = ns.Accounting.Book().selectedParty
    local index = #parties
    for i, party in ipairs(parties) do if party.id == selected then index = i end end
    local party = parties[math.max(1, math.min(#parties, index + delta))]
    if party then self:SelectParty(party.id) end
end
function UI:Forecast(f)
    local A, K, lines = ns.Accounting, ns.TradeKit, {}
    if self.props.plan == "next" then
        for _, row in ipairs(A.NextStep(self.model, nil, 10)) do
            local recipe = row.recipe
            local status = ns.T(row.known == true and "craftRecipeKnown" or row.known == false and "craftRecipeUnknown" or "craftRecipeUnchecked")
            local owners = #row.owners > 0 and ns.T("acNextOwners", table.concat(row.owners, ", ")) or ns.T("acNextNoOwners")
            local tip = ns.T("acNextTip", row.crafts, row.count, K.Money(row.value), K.Money(row.inputsMarket), K.Money(row.margin))
                .. "\n" .. ns.T("acNextStatus", status) .. " " .. owners
            local short = 0
            for _, input in ipairs(row.inputs) do
                tip = tip .. "\n" .. ns.T("acNextInput", ns.Markets.Name(input.itemID), input.need, input.own, input.extra)
                if input.extra > 0 then short = short + 1 end
            end
            if recipe.cooldown then tip = tip .. "\n" .. ns.T("craftCooldown") end
            if row.missing > 0 then tip = tip .. "\n" .. ns.T("acPlanMissing", row.missing) end
            lines[#lines + 1] = {key = "n" .. recipe.raw, id = recipe.raw, mode = "recipes",
                cells = {count = {tostring(row.count)},
                    cost = {row.cash > 0 and K.Money(row.cash) or (short > 0 and ns.T("tradeNoPrice") or ns.T("acNextHaveAll")),
                        short > 0 and "text" or "positive"},
                    net = {row.value and K.Money(row.value) or ns.T("acIncomplete")},
                    result = {row.margin and K.Money(row.margin) or ns.T("acIncomplete"), K.Tone(row.margin)},
                    value = {#row.owners > 0 and (row.known == true and status or table.concat(row.owners, ", ")) or status,
                        row.known == true and "text" or (#row.owners > 0 and "accent" or "secondary")}},
                tip = tip, actions = {{label = ns.T("acNextOpen"), tip = ns.T("acNextOpenTip"),
                    fn = function() UI.OpenRecipe(recipe) end}}}
        end
    elseif self.props.plan == "crafts" then
        for _, row in ipairs(A.CraftForecast(f)) do
            local recipe = row.recipe
            local known = ns.T(row.known == true and "craftRecipeKnown" or row.known == false and "craftRecipeUnknown" or "craftRecipeUnchecked")
            local tip = ns.T("acRecipeForecastTip", row.crafts, row.count, K.Money(row.cash), K.Money(row.net),
                K.Money(row.profit), K.Money(row.gain)) .. "\n" .. known
            for _, input in ipairs(row.inputs) do
                tip = tip .. "\n" .. ns.T("acRecipeInput", ns.Markets.Name(input.itemID), K.Decimal(input.count, 2), K.Decimal(input.own, 2),
                    K.Decimal(input.extra, 2))
            end
            if recipe.cooldown then tip = tip .. "\n" .. ns.T("craftCooldown") end
            if row.missing > 0 then tip = tip .. "\n" .. ns.T("acPlanMissing", row.missing) end
            if row.stale + f.stale > 0 then tip = tip .. "\n" .. ns.T("acPlanStale", row.stale + f.stale) end
            if row.short > 0 then tip = tip .. "\n" .. ns.T("acPlanShort", row.short) end
            lines[#lines + 1] = {key = "r" .. recipe.raw, id = recipe.raw, mode = "recipes",
                cells = {count = {tostring(row.count)}, cost = {row.missing == 0 and K.Money(row.cash) or ns.T("acIncomplete")},
                    net = {row.profit and K.Money(row.net) or ns.T("acIncomplete")},
                    result = {row.profit and K.Money(row.profit) or ns.T("acIncomplete"), K.Tone(row.profit)},
                    value = {row.gain and K.Money(row.gain) or "", K.Tone(row.gain)}},
                tip = tip, actions = {{label = ns.T("acRecipeOpen"), tip = ns.T("acRecipeOpenTip"),
                    fn = function() ns.Trader.OpenRecipe(recipe.profession, recipe.raw) end}}}
        end
    else
        for _, row in ipairs(f.rows) do
            lines[#lines + 1] = {key = "f" .. row.itemID, id = row.itemID, mode = "forecast",
                cells = {stock = {tostring(row.actual)}, count = {"~" .. K.Decimal(row.expected, 2), "secondary"},
                    units = {K.Decimal(row.count, 2)}, market = {K.Money(row.price)},
                    net = {K.Money(row.net)}}, tip = ns.T("acMaterialForecastTip"),
                actions = {{label = ns.T("acMarket"), tip = ns.T("acMarketTip"),
                    fn = function() ns.MarketWindow.Open(row.itemID) end}}}
        end
    end
    return lines
end
function UI.ForecastTile(forecast)
    local K = ns.TradeKit
    local tip = ns.T("acForecastTip")
    if not forecast.profit then return ns.T("acIncomplete"), ns.T("acForecastMissing"), tip end
    local realized, net, cost = K.RoundSilver(forecast.realized), K.RoundSilver(forecast.net), K.RoundSilver(forecast.cost)
    return K.MoneyShort(realized + net - cost), ns.T("acForecastNote", K.MoneyShort(realized), K.MoneyShort(net), K.MoneyShort(cost)),
        tip .. "\n\n" .. ns.T("acForecastExact", K.Money(forecast.profit))
end
function UI.OpenRecipe(recipe)
    if not ns.Trader then return end
    if recipe.family then ns.Trader.OpenFamily(recipe.family, recipe.raw); return end
    ns.Trader.OpenRecipe(recipe.profession, recipe.raw)
end
function UI.OpenNextStep()
    if ns.Trader and ns.Trader.frame and ns.Trader.frame:IsShown() then
        ns.Trader.Navigate(function()
            ns.Trader:ShowSection("accounting")
            if ns.Trader.accountingView then ns.Trader.accountingView:SetProps({mode = "forecast", plan = "next"}) end
        end)
        return
    end
    UI.Open()
    if UI.standalone then UI.standalone:SetProps({mode = "forecast", plan = "next"}) end
end
local function stageText(chain)
    if chain.stage == "done" then return ns.T("acStage_done_" .. ns.Accounting.Kind(chain)) end
    return ns.T("acStage_" .. chain.stage)
end
function UI:ChainCells(chain, fee)
    local K = ns.TradeKit
    local cells = {stage = {stageText(chain), TONE[chain.stage]}, cost = {K.Money(chain.cost)},
        when = {date("%d.%m %H:%M", chain.at), "secondary"}}
    if chain.basis then cells.cost = {chain.basis == "free" and ns.T("acFree") or K.Money(chain.cost), "accent"} end
    if chain.stage == "done" then
        cells.market = {chain.gross and K.Money(chain.gross) or ns.T("tradeNoPrice"), chain.gross and "text" or "secondary"}
        cells.net = {chain.value and K.Money(chain.value) or ns.T("tradeNoPrice"), "secondary"}
        if chain.result then cells.result = {K.Money(chain.result), K.Tone(chain.result)} end
    else
        local estimate = ns.Accounting.Expectation(chain, fee)
        if estimate then
            cells.market = {K.About(estimate.gross), "secondary"}
            cells.net = {K.About(estimate.net), "secondary"}
            cells.result = {K.About(estimate.margin), "secondary"}
        end
    end
    return cells
end
local function outputs(chain)
    if next(chain.outputs) == nil then return nil end
    local list = {}
    for id, count in pairs(chain.outputs) do list[#list + 1] = {id = id, count = count} end
    table.sort(list, function(a, b) return a.count > b.count end)
    return list
end
local function chainTip(chain, fee)
    local K = ns.TradeKit
    local tip = ns.T("acChainTip", chain.level or 0, chain.count, chain.received, chain.processed,
        ns.T("acSource_" .. (chain.source or "manual")))
    tip = tip .. "\n" .. ns.T("acPlanLine", ns.T("acPlan_" .. (chain.plan or "disenchant")))
    if chain.basis then
        tip = tip .. "\n" .. ns.T("acBasisLine", ns.T("acBasis_" .. chain.basis), K.Money(chain.cost))
        if chain.from then tip = tip .. "\n" .. ns.T("acFromLine", chain.from) end
        if chain.basis == "free" then tip = tip .. "\n" .. ns.T("acFreeWarn") end
    end
    if chain.gross then
        local lines = {}
        for id, count in pairs(chain.outputs) do
            local price = ns.Accounting.Market(id)
            lines[#lines + 1] = ns.T("acOutputLine", ns.Markets.Name(id), count, K.Money(price), K.Money(price and price * count))
        end
        tip = tip .. "\n\n" .. table.concat(lines, "\n") .. "\n" .. ns.T("acChainMath", K.Money(chain.gross),
            math.floor(fee * 100 + 0.5), K.Money(chain.cut), K.Money(chain.reserve), K.Money(chain.value),
            K.Money(chain.cost), K.Money(chain.result))
    end
    return tip
end
function UI:ChainActions(chain)
    local A, actions = ns.Accounting, {}
    if chain.stage == "sent" or chain.stage == "unsure" then
        actions[1] = {label = ns.T("acWon"), tip = ns.T("acWonTip"), fn = function() self:Result(A.Resolve(chain.id, true, "manual")) end}
        actions[2] = {label = ns.T("acLost"), tip = ns.T("acLostTip"), fn = function() self:Result(A.Resolve(chain.id, false, "manual")) end}
    elseif chain.stage == "mail" then
        actions[1] = {label = ns.T("acReceive"), tip = ns.T("acReceiveTip"),
            fn = function() self:Result(A.Receive(chain.id, chain.count - chain.received, "manual")) end}
    elseif chain.stage == "bag" then
        actions[1] = {label = ns.T("acOutputButton"), tip = ns.T("acOutputButtonTip"), fn = function() self:Output(chain) end}
    end
    if chain.processed == 0 then
        actions[#actions + 1] = {label = ns.T("acRemove"), tip = ns.T("acRemoveTip"), fn = function() self:Result(A.Reverse(chain.id)) end}
    end
    return actions
end
function UI:Items(p, fee, since)
    local K, A, allowed = ns.TradeKit, ns.Accounting, STAGES[self.props.stage] or true
    local method = self.props.method ~= "all" and self.props.method or nil
    local groups, order = {}, {}
    for i = #p.chains, 1, -1 do
        local chain = p.chains[i]
        if chain.at >= since and chain.stage ~= "lost" and (allowed == true or allowed[chain.stage])
            and (not method or A.Kind(chain) == method) then
            local key = chain.itemID .. ":" .. chain.suffix
            if not groups[key] then groups[key] = {key = key, chains = {}}; order[#order + 1] = groups[key] end
            local list = groups[key].chains
            list[#list + 1] = chain
        end
    end
    local lines = {}
    for _, group in ipairs(order) do
        local first = group.chains[1]
        local open = not self.closed[group.key]
        if #group.chains > 1 then
            local cost, value, units, known, done = 0, 0, 0, true, 0
            for _, chain in ipairs(group.chains) do
                cost, units = cost + chain.cost, units + chain.count
                if chain.stage == "done" then
                    done = done + 1
                    if chain.value then value = value + chain.value else known = false end
                end
            end
            local result = known and done == #group.chains and value - cost or nil
            lines[#lines + 1] = {group = true, key = group.key, open = open,
                name = ns.Markets.Name(first.itemID),
                detail = ns.T("acGroupDetail", units, K.Money(cost), done, #group.chains),
                tag = result and K.Money(result) or "", tone = K.Tone(result)}
        end
        if open or #group.chains == 1 then
            for _, chain in ipairs(group.chains) do
                lines[#lines + 1] = {key = chain.id, id = chain.itemID, link = chain.link, quality = chain.quality,
                    mode = "items", nested = #group.chains > 1, cells = self:ChainCells(chain, fee), icons = outputs(chain),
                    actions = self:ChainActions(chain), tip = chainTip(chain, fee)}
            end
        end
    end
    return lines
end
function UI:Analysis(p)
    local K, lines = ns.TradeKit, {}
    local method = self.props.method ~= "all" and self.props.method or nil
    local by = method == "disenchant" and self.props.by or "item"
    for _, g in ipairs(ns.Accounting.Analysis(p, by, method)) do
        local title
        if by == "level" then title = ns.T("acByLevelTitle", g.key)
        elseif by == "band" then
            local band = ns.Disenchant.Band(g.key)
            local kind = band and ns.DisenchantUI and ns.DisenchantUI.BandKind and ns.DisenchantUI.BandKind(band)
            title = band and kind and ns.T("deBandHeader", kind, band.minLevel, band.maxLevel) or tostring(g.key)
        end
        local units = g.main and ns.T("acUnitsValue", K.Decimal(g.units / g.count, 1),
            K.Decimal(g.expectedUnits / g.count, 1), ns.Markets.Name(g.main)) or ""
        local notes = {ns.T("acKindLine", ns.T("acMethod_" .. g.kind))}
        if g.count < 5 and g.kind ~= "flip" and g.kind ~= "craft" then notes[#notes + 1] = ns.T("acFewSamples") end
        if g.crafted then notes[#notes + 1] = ns.T("acCrafted") end
        if g.kind == "craft" or g.kind == "flip" then notes[#notes + 1] = ns.T("acNoLuck") end
        lines[#lines + 1] = {key = "a" .. tostring(g.key), id = by == "item" and g.itemID or nil, title = title,
            mode = "analysis",
            cells = {count = {tostring(g.count)}, cost = {K.Money(g.cost / g.count), "secondary"},
                units = {units, "secondary"},
                expected = {g.known and K.Money(g.expected / g.count) or ns.T((g.kind == "craft" or g.kind == "flip") and "acNone" or "tradeNoPrice"), "secondary"},
                gross = {K.Money(g.gross / g.count)},
                luck = {g.luck and string.format("%d%%", math.floor(g.luck + 0.5)) or "",
                    g.luck and K.Tone(g.luck - 100) or "secondary"},
                result = {K.Money(g.result), K.Tone(g.result)}},
            tip = ns.T("acAnalysisTip") .. (#notes > 0 and ("\n\n" .. table.concat(notes, "\n")) or "")}
    end
    return lines
end
function UI:Materials(p)
    local K, lines, list = ns.TradeKit, {}, {}
    for _, m in pairs(p.materials) do list[#list + 1] = m end
    table.sort(list, function(a, b)
        if (a.remaining > 0) ~= (b.remaining > 0) then return a.remaining > 0 end
        return a.itemID < b.itemID
    end)
    for _, m in ipairs(list) do
        local unit = m.remaining > 0 and not m.unknownCost and m.cost / m.remaining or nil
        lines[#lines + 1] = {key = "m" .. m.itemID, id = m.itemID, mode = "materials", model = m,
            cells = {stock = {tostring(m.remaining)}, posted = {m.posted > 0 and tostring(m.posted) or "", "gold"},
                unit = {unit and K.Money(unit) or (m.remaining > 0 and "?" or ""), "secondary"},
                market = {m.price and K.Money(m.price) or ns.T("tradeNoPrice"), m.price and "text" or "secondary"},
                value = {m.value and K.Money(m.value) or ""},
                sold = {m.sold > 0 and tostring(m.sold) or "", "secondary"},
                net = {m.net > 0 and K.Money(m.net) or "", m.net > 0 and K.Tone(m.net - m.soldCost) or "secondary"}},
            actions = {
                {label = ns.T("acMarket"), tip = ns.T("acMarketTip"), fn = function() ns.MarketWindow.Open(m.itemID) end},
                m.remaining > 0 and {label = ns.T("acSaleButton"), tip = ns.T("acSaleTip"), fn = function() self:Sale(m) end} or nil,
            },
            tip = ns.T("acMaterialTip", m.received, m.sold, m.remaining, m.posted)}
    end
    return lines
end
function UI:Journal(p, since)
    local K, A, lines = ns.TradeKit, ns.Accounting, {}
    for _, entry in ipairs(A.History(since, self.props.historyScope == "character")) do
        local event, owner = entry.event, entry.owner
        local target = event.target and entry.byEvent[event.target]
        local itemID = event.itemID or (target and (target.itemID or (target.target and entry.byEvent[target.target]
            and entry.byEvent[target.target].itemID)))
        local amount = event.cost or event.gross
        local actions = {}
        if owner.current and A.Reversible(p, event) then
            actions[1] = {label = ns.T("acUndo"), tip = ns.T("acUndoTip"), fn = function() self:Result(A.Reverse(event.id)) end}
        end
        local sale = event.kind == "sale" and (owner.current and p.bySale[event.id] or entry.bySale[event.id])
        if owner.current and sale and not sale.count then
            actions[#actions + 1] = {label = ns.T("acSaleCountButton"), tip = ns.T("acSaleCountButtonTip"),
                fn = function() self:SaleCount(sale) end}
        end
        local label = ns.T(event.kind == "convert" and ("acEvent_convert_" .. (event.method or "craft")) or ("acEvent_" .. event.kind))
        local reversed = entry.reversed[event.id]
        local tip = ns.T("acHistoryOwner", owner.name, owner.realm,
            ns.T(owner.faction == "Alliance" and "acFactionAlliance" or (owner.faction == "Horde" and "acFactionHorde" or "acFactionUnknown")))
            .. "\n" .. ns.T("acHistorySource", ns.T("acSource_" .. (event.source or "manual")))
            .. "\n" .. ns.T("acHistoryAt", date("%d.%m.%Y %H:%M:%S", event.at))
        if reversed then tip = tip .. "\n\n" .. ns.T("acReversed") end
        if event.basis then
            label = ns.T("acEvent_intake")
            tip = tip .. "\n\n" .. ns.T("acBasisLine", ns.T("acBasis_" .. event.basis), K.Money(event.cost))
        end
        if event.kind == "sale" or event.kind == "disenchant" or event.kind == "convert" or event.kind == "post" or event.kind == "use" then
            local count = sale and sale.count or event.count or (event.stack and event.stack * event.stacks)
            if event.outputs then
                count = 0
                for _, output in ipairs(event.outputs) do count = count + output.count end
            end
            if count then label = label .. " x" .. count elseif sale then label = label .. " x?" end
        end
        if event.kind == "convert" then
            local lines = {}
            for _, input in ipairs(event.inputs or {}) do
                local source = input.chain and entry.byEvent[input.chain]
                local id = input.itemID or (source and source.itemID)
                if id then
                    lines[#lines + 1] = ns.T((input.missing or 0) > 0 and "acConvertMissing" or "acConvertInput",
                        ns.Markets.Name(id), input.count, input.missing or 0)
                end
            end
            if #lines > 0 then tip = tip .. "\n\n" .. table.concat(lines, "\n") end
        end
        if event.kind == "sale" then
            if (event.unallocated or 0) > 0 then tip = tip .. "\n\n" .. ns.T("acSaleOver", event.unallocated) end
            if event.stockless then tip = tip .. "\n\n" .. ns.T("acSaleStockless") end
        end
        lines[#lines + 1] = {key = "e" .. owner.key .. ":" .. event.id, id = itemID, title = itemID and nil or label, mode = "journal",
            cells = {event = {label, reversed and "off" or "text"},
                amount = {event.basis == "free" and ns.T("acFree") or (amount and K.Money(amount) or ""),
                    reversed and "off" or (event.basis and "accent" or "text")},
                character = {owner.name, owner.current and "text" or "secondary"},
                source = {ns.T("acSource_" .. (event.source or "manual")), "secondary"},
                when = {date("%d.%m %H:%M", event.at), "secondary"}},
            actions = actions,
            tip = tip}
    end
    return lines
end
function UI:Render()
    if not self.frame or not self.frame:IsVisible() then return end
    local A, K = ns.Accounting, ns.TradeKit
    local since = self:Since()
    local book = A.Book()
    local parties = A.Parties(book)
    local selected = book.selectedParty
    if selected == nil then selected = #parties > 0 and parties[#parties].id or 0 end
    local p = A.Project(book, since, nil, selected)
    local method = self.props.method ~= "all" and self.props.method or nil
    local forecast = A.Forecast(p, nil, self.props.mode == "forecast" and method or nil)
    local fee = book.fee or 0.05
    self.model = p
    self.forecast = forecast
    local width = self.frame:GetWidth() or 780
    self.periods:Select(self.props.period)
    self.fee:Select(fee == 0.15 and 15 or 5)
    self.trackAll:SetChecked(book.trackAll == true)
    self.views:Select(self.props.mode)
    self.partyScope:Select(selected == 0 and "all" or "party")
    local partyIndex
    for i, party in ipairs(parties) do if party.id == selected then partyIndex = i end end
    self.partyLabel:SetText(partyIndex and ns.T("acPartyLabel", partyIndex, date("%d.%m %H:%M", parties[partyIndex].at)) or "")
    if partyIndex then self.partyPrev:Show(); self.partyNext:Show()
    else self.partyPrev:Hide(); self.partyNext:Hide() end
    if partyIndex and partyIndex > 1 then self.partyPrev:Enable() else self.partyPrev:Disable() end
    if partyIndex and partyIndex < #parties then self.partyNext:Enable() else self.partyNext:Disable() end
    if #parties > 0 then self.partyScope.buttons.party:Enable() else self.partyScope.buttons.party:Disable() end
    local tileWidth = (width - 20 - 18) / 4
    local holdingNote = p.holdingUnsure > 0
        and ns.T("acHoldingNoteUnsure", p.holdingCount, p.holdingMail, p.holdingBag, p.holdingUnsure)
        or ns.T("acHoldingNote", p.holdingCount, p.holdingMail, p.holdingBag)
    local tiles = {
        {"acHolding", K.Money(p.holding), holdingNote, "secondary"},
        {"acStock", p.unpriced > 0 and ns.T("acIncomplete") or K.Money(p.stockValue),
            p.unpriced > 0 and ns.T("acStockPartial", K.Money(p.stockValue), p.unpriced)
                or (p.uncosted > 0 and ns.T("acStockUncosted") or ns.T("acStockNote", K.Money(p.stockCost))), "secondary"},
        {"acSold", p.sold > 0 and K.Money(p.net) or ns.T("acNone"),
            p.sold > 0 and ns.T("acSoldNote", K.Money(p.realized)) or ns.T("acSoldNone"), p.sold > 0 and K.Tone(p.realized) or "secondary"},
    }
    local forecastValue, forecastNote, forecastTip = UI.ForecastTile(forecast)
    tiles[#tiles + 1] = {"acForecast", forecastValue, forecastNote, K.Tone(forecast.profit), forecastTip}
    for index, values in ipairs(tiles) do
        local tile = self.tiles[index]
        tile.frame:ClearAllPoints()
        tile.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10 + (index - 1) * (tileWidth + 6), -62)
        tile:SetProps({title = ns.T(values[1]), value = values[2], note = values[3], tone = values[4],
            width = tileWidth, tip = values[5] or ns.T(values[1] .. "Tip")})
    end
    local items = self.props.mode == "items"
    for key, button in pairs(self.stages.buttons) do
        local count = 0
        if key == "all" then
            for stage, n in pairs(p.stages) do if stage ~= "lost" then count = count + n end end
        else for stage in pairs(STAGES[key]) do count = count + p.stages[stage] end end
        button:SetText(ns.T("acStageFilter_" .. key, count))
    end
    self.stages:Select(self.props.stage)
    if items then self.stages.frame:Show() else self.stages.frame:Hide() end
    self.groupBy:Select(self.props.by)
    local analysis = self.props.mode == "analysis"
    if analysis and (method == nil or method == "disenchant") then self.groupBy.frame:Show() else self.groupBy.frame:Hide() end
    if analysis and method ~= nil and method ~= "disenchant" then self.groupBy:Disable() else self.groupBy:Enable() end
    self.historyScope:Select(self.props.historyScope)
    if self.props.mode == "journal" then self.historyScope.frame:Show() else self.historyScope.frame:Hide() end
    local planning = self.props.mode == "forecast"
    self.planMode:Select(self.props.plan)
    if planning then self.planMode.frame:Show(); self.planScan:Show()
    else self.planMode.frame:Hide(); self.planScan:Hide() end
    self.methods:Select(self.props.method)
    local secondary = (items or analysis or planning and self.props.plan == "materials") and self.methods or nil
    if secondary then self.methods.frame:Show() else self.methods.frame:Hide() end
    local context = items and self.stages or analysis and self.groupBy
        or self.props.mode == "journal" and self.historyScope or planning and self.planMode
    local wrapped = context and self.views.frame:GetWidth() + context.frame:GetWidth() + 32 > width
    if context then
        context.frame:ClearAllPoints()
        if wrapped then context.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -152)
        else context.frame:SetPoint("LEFT", self.views.frame, "RIGHT", 12, 0) end
    end
    if secondary then
        secondary.frame:ClearAllPoints()
        local beside = context and wrapped and (context.frame:GetWidth() or 0) + (secondary.frame:GetWidth() or 0) + 32 <= width
        if beside then secondary.frame:SetPoint("LEFT", context.frame, "RIGHT", 12, 0)
        elseif not wrapped and (self.views.frame:GetWidth() or 0) + (context and context.frame:GetWidth() or 0)
            + (secondary.frame:GetWidth() or 0) + 44 <= width then
            secondary.frame:SetPoint("LEFT", context and context.frame or self.views.frame, "RIGHT", 12, 0)
        else
            secondary.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, wrapped and -178 or -152)
            wrapped = wrapped and 2 or true
        end
    end
    local tableTop = TABLE_TOP + (wrapped == 2 and 52 or wrapped and 26 or 0)
    self.headBand:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -tableTop + 26)
    self.headBand:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -28, -tableTop + 26)
    self.scroll.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -tableTop)
    self.empty:ClearAllPoints(); self.empty:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 20, -tableTop - 10)
    if ns.Scan.state.phase == "idle" and not ns.Batch.job and not ns.Buy.Active() then self.planScan:Enable()
    else self.planScan:Disable() end
    local inner = width - 20 - 18
    local lines
    if items then lines = self:Items(p, fee, since)
    elseif self.props.mode == "materials" then lines = self:Materials(p)
    elseif self.props.mode == "analysis" then lines = self:Analysis(p)
    elseif planning then lines = self:Forecast(forecast)
    else lines = self:Journal(selected ~= 0 and A.Project(book, since) or p, since) end
    local hasActions = false
    for _, line in ipairs(lines) do if line.actions and #line.actions > 0 then hasActions = true end end
    local mode = planning and (self.props.plan == "crafts" and "recipes" or self.props.plan == "next" and "next") or self.props.mode
    local columns = K.LedgerColumns(inner, mode == "next" and "recipes" or mode, hasActions)
    for key, label in pairs(self.headers) do
        local column = columns[key]
        label:ClearAllPoints()
        if column then
            label:SetPoint("LEFT", self.headBand, "LEFT", key == "item" and 32 or column[1], 0)
            label:SetWidth(key == "item" and column[2] - 34 or column[2] - 6)
            label:SetText(ns.T("acCol_" .. mode .. "_" .. key))
            label:Show()
        else label:Hide() end
    end
    local visible = K.ListCapacity(self.frame, tableTop, planning and 60 or 30, ROW, #self.rows)
    self.scroll.frame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -10, planning and 60 or 30)
    local offset = self.scroll:SetRange(#lines, visible)
    local rowIndex, groupIndex = 0, 0
    for _, row in ipairs(self.rows) do row.frame:Hide() end
    for _, group in ipairs(self.groups) do group.frame:Hide() end
    for index = 1, math.min(visible, #lines - offset) do
        local line = lines[offset + index]
        local y = -tableTop - (index - 1) * ROW
        local widget
        if line.group then
            groupIndex = groupIndex + 1
            widget = self.groups[groupIndex]
            if widget then
                widget:SetProps({key = line.key, name = line.name, detail = line.detail, tag = line.tag, tone = line.tone,
                    open = line.open, width = inner, height = ROW})
            end
        else
            rowIndex = rowIndex + 1
            widget = self.rows[rowIndex]
            if widget then
                line.width, line.active, line.hasActions = inner, line.key == self.selected, hasActions
                widget:SetProps(line)
            end
        end
        if widget then
            widget.frame:ClearAllPoints(); widget.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, y)
            widget.frame:Show()
        end
    end
    self.empty:SetWidth(width - 40)
    self.empty:SetText(#lines == 0 and ns.T("acEmpty_" .. mode) or "")
    local hint = self.message
    if not hint and p.unknownSales > 0 then hint = ns.T("acUnknownSales", p.unknownSales) end
    if not hint and p.unknownCost then hint = ns.T("acUnknownCostHint") end
    if not hint and p.stages.unsure > 0 then hint = ns.T("acUnsureHint", p.stages.unsure) end
    if not hint and p.free > 0 then hint = ns.T("acFreeHint", p.free) end
    if not hint and self.props.mode == "journal" then hint = ns.T("acHistoryStatus", #lines, A.Text(UnitName("player"))) end
    if not hint and A.lastConvert and GetTime() - A.lastConvert.at < 600 and not (planning and self.props.plan == "next") then
        hint = ns.T("acNextHint", ns.T("acEvent_convert_" .. A.lastConvert.method))
    end
    self.status:SetWidth(width - 160)
    self.status:SetText(hint or "")
    if hint and hint == self.message then self.status:SetTextColor(unpack(K.theme.negative))
    else self.status:SetTextColor(unpack(K.theme.secondary)) end
end
function UI:New(parent)
    local K = ns.TradeKit
    local view = setmetatable({props = {mode = "items", period = "all", stage = "all", by = "item", historyScope = "account",
        plan = "materials", method = "all"}, rows = {}, groups = {},
        tiles = {}, headers = {}, closed = {}}, self)
    local f = ns.NewFrame("Frame", nil, parent); f:SetAllPoints(parent); view.frame = f
    local periods = {}
    for _, period in ipairs(PERIODS) do periods[#periods + 1] = {key = period.key, label = ns.T("acPeriod_" .. period.key)} end
    view.periods = K.Segment(f, periods, function(key) view:SetProps({period = key}) end)
    view.periods.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -4)
    view.fee = K.Segment(f, {{key = 5, label = ns.T("acFeeRate", 5)}, {key = 15, label = ns.T("acFeeRate", 15)}}, function(key)
        ns.Accounting.SetFee(key / 100)
    end, {ns.T("acFeeTitle"), ns.T("acFeeTip")})
    view.fee.frame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -4)
    view.add = K.Button(f, ns.T("acAddPurchase"), 130, function() view:Purchase() end, "quiet")
    view.add:SetHeight(22)
    view.add:SetPoint("RIGHT", view.fee.frame, "LEFT", -8, 0)
    K.Tooltip(view.add, ns.T("acAddPurchase"), ns.T("acAddPurchaseTip"))
    view.intake = K.Button(f, ns.T("acIntakeButton"), 110, function() UI.Intake() end, "quiet")
    view.intake:SetHeight(22)
    view.intake:SetPoint("RIGHT", view.add, "LEFT", -8, 0)
    K.Tooltip(view.intake, ns.T("acIntakeTitle"), ns.T("acIntakeButtonTip"))
    ns.CollectUI.Attach(f, 130, function(b)
        b:SetPoint("RIGHT", view.intake, "LEFT", -8, 0); view.disenchant = b
    end)
    view.partyScope = K.Segment(f, {{key = "all", label = ns.T("acPartyAll")},
        {key = "party", label = ns.T("acParty")}}, function(key)
        local parties = ns.Accounting.Parties()
        view:SelectParty(key == "party" and #parties > 0 and parties[#parties].id or 0)
    end)
    view.partyScope.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -32)
    view.partyPrev = K.Button(f, "<", 22, function() view:StepParty(-1) end, "quiet")
    view.partyPrev:SetPoint("LEFT", view.partyScope.frame, "RIGHT", 8, 0)
    view.partyLabel = K.Label(f, "", 0, 0, 170, "secondary")
    view.partyLabel:ClearAllPoints(); view.partyLabel:SetPoint("LEFT", view.partyPrev, "RIGHT", 6, 0)
    view.partyNext = K.Button(f, ">", 22, function() view:StepParty(1) end, "quiet")
    view.partyNext:SetPoint("LEFT", view.partyLabel, "RIGHT", 6, 0)
    view.newParty = K.Button(f, ns.T("acNewParty"), 130, function() view:NewParty() end)
    view.newParty:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -32)
    K.Tooltip(view.newParty, ns.T("acNewParty"), ns.T("acNewPartyTip"))
    view.trackAll = K.Check(f, function(on) ns.Accounting.SetTrackAll(on) end)
    view.trackAllLabel = K.Label(f, ns.T("acTrackAll"), 0, 0, 90, "secondary")
    view.trackAllLabel:ClearAllPoints(); view.trackAllLabel:SetPoint("RIGHT", view.newParty, "LEFT", -10, 0)
    view.trackAll:SetPoint("RIGHT", view.trackAllLabel, "LEFT", -2, 0)
    K.Tooltip(view.trackAll, ns.T("acTrackAll"), ns.T("acTrackAllTip"))
    for index = 1, 4 do view.tiles[index] = K.StatTile:New(f) end
    local modes = {}
    for _, mode in ipairs({"items", "materials", "journal", "analysis", "forecast"}) do modes[#modes + 1] = {key = mode, label = ns.T("acTab_" .. mode)} end
    view.views = K.Segment(f, modes, function(key) view:SetProps({mode = key}) end, {ns.T("acTitle"), ns.T("acHint")})
    view.views.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -126)
    local stages = {}
    for _, key in ipairs({"all", "wait", "mail", "bag", "done"}) do
        stages[#stages + 1] = {key = key, label = ns.T("acStageFilter_" .. key, 888)}
    end
    view.stages = K.Segment(f, stages, function(key) view:SetProps({stage = key}) end)
    view.stages.frame:SetPoint("LEFT", view.views.frame, "RIGHT", 12, 0)
    view.groupBy = K.Segment(f, {{key = "item", label = ns.T("acBy_item")}, {key = "level", label = ns.T("acBy_level")},
        {key = "band", label = ns.T("acBy_band")}}, function(key) view:SetProps({by = key}) end,
        {ns.T("acTab_analysis"), ns.T("acAnalysisTip")})
    view.groupBy.frame:SetPoint("LEFT", view.views.frame, "RIGHT", 12, 0)
    view.historyScope = K.Segment(f, {{key = "account", label = ns.T("acHistoryAccount")},
        {key = "character", label = ns.T("acHistoryCharacter")}}, function(key) view:SetProps({historyScope = key}) end,
        {ns.T("acHistoryAccount"), ns.T("acHistoryTip")})
    view.historyScope.frame:SetPoint("LEFT", view.views.frame, "RIGHT", 12, 0)
    view.planMode = K.Segment(f, {{key = "materials", label = ns.T("acTab_materials")},
        {key = "crafts", label = ns.T("acPlanCrafts")}, {key = "next", label = ns.T("acPlanNext")}},
        function(key) view:SetProps({plan = key}) end, {ns.T("acPlanNext"), ns.T("acPlanNextTip")})
    view.planMode.frame:SetPoint("LEFT", view.views.frame, "RIGHT", 12, 0)
    local methods = {}
    for _, key in ipairs({"all", "disenchant", "prospect", "mill", "craft", "flip"}) do
        methods[#methods + 1] = {key = key, label = ns.T("acMethod_" .. key)}
    end
    view.methods = K.Segment(f, methods, function(key) view:SetProps({method = key}) end,
        {ns.T("acMethodTitle"), ns.T("acMethodTip")})
    view.methods.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -152)
    view.planScan = K.Button(f, ns.T("acPlanScan"), 150, function()
        ns.Batch.Complete(ns.Accounting.ForecastTargets(view.forecast), K.ScanMode(), true)
    end)
    view.planScan:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 32)
    K.ScanTip(view.planScan, ns.T("acPlanScan"), ns.T("acPlanScanTip"), function()
        return ns.Accounting.ForecastTargets(view.forecast)
    end)
    local head = ns.NewFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -154)
    head:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -154)
    head:SetHeight(22)
    K.HeaderBand(head)
    view.headBand = head
    for _, key in ipairs({"item", "stage", "cost", "output", "value", "result", "when", "stock", "posted", "unit",
        "market", "sold", "net", "event", "amount", "source", "character", "count", "units", "expected", "gross", "luck"}) do
        local label = K.Label(head, "", 0, -5, 80, "secondary")
        label:SetHeight(12)
        if key ~= "item" and key ~= "output" then label:SetJustifyH("RIGHT") end
        view.headers[key] = label
    end
    view.scroll = K.Scroller:New(f, function() view:Render() end, ROW)
    view.scroll.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -TABLE_TOP)
    view.scroll.frame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 60)
    for index = 1, 40 do
        local row = K.LedgerRow:New(f, function(key) view.selected = key; view.message = nil; view:Render() end)
        view.scroll:Wheel(row.frame); view.rows[index] = row
        row.frame:Hide()
    end
    for index = 1, 20 do
        local group = K.GroupRow:New(f, function(key) view.closed[key] = not view.closed[key]; view:Render() end)
        view.scroll:Wheel(group.frame); view.groups[index] = group
        group.frame:Hide()
    end
    view.empty = K.Label(f, "", 20, -TABLE_TOP - 10, 600, "secondary"); view.empty:SetHeight(60)
    view.status = K.Label(f, "", 10, 0, 700, "secondary")
    view.status:ClearAllPoints(); view.status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8); view.status:SetHeight(16)
    view.mailPanel = ns.CollectUI.ShownCheck(f)
    view.mailPanel:SetPoint("RIGHT", view.fee.frame, "LEFT", -16, 0)
    f:SetScript("OnSizeChanged", function() view:Render() end)
    f:SetScript("OnShow", function() view:Render() end)
    self.all[#self.all + 1] = view
    view:Render(); return view
end
local INTAKE_ROWS = 8
function UI.Intake()
    local K, A, E = ns.TradeKit, ns.Accounting, ns.AccountingEvents
    local w = UI.intake
    if not w then
        w = {checked = {}, rows = {}, items = {}}
        UI.intake = w
        local frame = K.Window(UIParent, ns.T("acIntakeTitle"), 540, 404)
        w.frame = frame
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
            ns.say(ns.T("acIntakeDone", added, ns.T("acBasis_" .. w.basis)))
        end, "main")
        w.add:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 12)
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
