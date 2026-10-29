local _, ns = ...
local UI = {props = ns.Leveling.Options(), states = {},
    rows = {}, groups = {}, collapsed = {}, stepsOpen = {}, mode = "steps"}
ns.LevelingUI = UI
function UI:SetProps(props)
    local profession = props.profession or self.props.profession
    if profession ~= self.props.profession then
        if self.first and (self.first.liveAt or self.target.liveAt or self.reserve.liveAt) then self.read() end
        if ns.Batch.job and ns.Batch.job.levelingProfession then ns.Batch.Stop() end
        self.states[self.props.profession] = {props = self.props, collapsed = self.collapsed,
            stepsOpen = self.stepsOpen, mode = self.mode, formulasOpen = self.formulasOpen}
        local state = self.states[profession] or {props = ns.Leveling.Options({profession = profession}),
            collapsed = {}, stepsOpen = {}, mode = "steps"}
        self.props, self.collapsed, self.stepsOpen, self.mode = state.props, state.collapsed, state.stepsOpen, state.mode
        self.formulasOpen = state.formulasOpen
        for _, edit in ipairs({self.first, self.target, self.reserve}) do
            edit.liveAt = nil; edit:SetScript("OnUpdate", nil); edit:ClearFocus()
        end
    end
    if props.strategy and props.strategy ~= self.props.strategy then
        if ns.Batch.job and ns.Batch.job.levelingProfession then ns.Batch.Stop() end
        self.stepsOpen, self.formulasOpen = {}, nil
    end
    for key, value in pairs(props) do self.props[key] = value end
    self.props = ns.Leveling.Options(self.props)
    self.signature = nil
    if self.scroll then self.scroll.offset = 0 end
    self:Render()
end
function UI:Model()
    local p, parts = self.props, {}
    local c = ns.levelingCatalogs[p.profession]
    for id in pairs(c.vendors) do parts[#parts + 1] = id end
    local freeOptions = ns.Leveling.Options(p); freeOptions.strategy = "free"
    for _, recipe in pairs(c.freeRecipes or c.recipes) do
        for _, input in ipairs(recipe.inputs) do parts[#parts + 1] = input[1] end
        if recipe.acquisition then for _, input in ipairs(recipe.acquisition.inputs) do parts[#parts + 1] = input[1] end end
    end
    for id, obtain in pairs(c.obtains) do
        parts[#parts + 1] = id
        for _, input in ipairs(obtain.inputs) do parts[#parts + 1] = input[1] end
    end
    table.sort(parts)
    local signature, seen = {p.profession, tostring(math.floor(time() / 60))}, {}
    for _, id in ipairs(parts) do
        if not seen[id] then
            seen[id] = true
            local q = ns.Leveling.Quote(id, freeOptions)
            signature[#signature + 1] = id .. ":" .. tostring(q and q.price) .. ":" .. tostring(q and q.scanID)
                .. ":" .. tostring(q and q.complete) .. ":" .. tostring(q and q.miss) .. ":" .. tostring(q and q.via)
                .. ":" .. (p.owned and tostring(GetItemCount(id, true) or 0) or "")
        end
    end
    local key = table.concat(signature, "|")
    if key ~= self.signature then
        self.signature = key
        local lowerOptions = ns.Leveling.Options(p); lowerOptions.reserve = 0; lowerOptions.strategy = "guide"
        local guideLower = ns.Leveling.Route(lowerOptions)
        local guideOptions = ns.Leveling.Options(p); guideOptions.strategy = "guide"
        local guide = p.reserve == 0 and guideLower or ns.Leveling.Route(guideOptions)
        local free = ns.Leveling.FreeRoute(freeOptions)
        local route = p.strategy == "free" and free or guide
        self.model = {route = route, lower = p.strategy == "free" and free or guideLower,
            guide = guide, free = free, basket = ns.Leveling.Basket(route), brackets = ns.Leveling.Brackets(route)}
    end
    return self.model
end
function UI:Controls()
    if not self.frame then return end
    local phase = ns.Scan.state.phase
    if phase == "idle" and not ns.Buy.Active() then self.scan:Enable(); self.all:Enable()
    else self.scan:Disable(); self.all:Disable() end
end
function UI:Action(entry, button)
    local p = self.props
    if entry.kind == "bracket" then
        self.collapsed[entry.key] = not self.collapsed[entry.key] or nil; self:Render()
    elseif entry.kind == "alternative" then
        if p.strategy == "free" then
            for skill = entry.first, entry.target - 1 do p.freeChoices[skill] = entry.spell end
            self:SetProps({freeChoices = p.freeChoices})
        else p.choices[entry.stage] = entry.spell; self:SetProps({choices = p.choices}) end
    elseif entry.kind == "step" then
        self.stepsOpen[entry.stage] = not self.stepsOpen[entry.stage]; self:Render()
    elseif entry.kind == "auto" then
        if p.strategy == "free" then
            for skill = entry.first, entry.target - 1 do p.freeChoices[skill] = nil end
            self:SetProps({freeChoices = p.freeChoices})
        else p.choices[entry.stage] = nil; self:SetProps({choices = p.choices}) end
    elseif entry.kind == "learn" then
        p.known[entry.recipe] = not p.known[entry.recipe]; self:SetProps({known = p.known})
    elseif entry.kind == "material" then
        if entry.expandable and button then p.make[entry.id] = not p.make[entry.id]; self:SetProps({make = p.make})
        elseif entry.quote and entry.quote.via then
            ns.Trader.OpenProcessing("disenchant")
            ns.DisenchantUI:SelectGroup("target" .. entry.id .. "_234")
        elseif entry.need > 0 and not (entry.quote and entry.quote.vendor) then ns.Trader.OpenBuy(entry.id, entry.need) end
    end
end
function UI:Expand(entry)
    if entry.kind == "material" then
        self.props.open[entry.id] = not self.props.open[entry.id]
        self.signature = nil; self:Render()
    else self:Action(entry) end
end
function UI:Entries(model)
    local out, K, p = {}, ns.TradeKit, self.props
    local catalog = ns.levelingCatalogs[p.profession]
    local c = {recipes = p.strategy == "free" and (catalog.freeRecipes or catalog.recipes) or catalog.recipes}
    if self.formulasOpen then
        for _, recipe in ipairs(ns.Leveling.Candidates(p)) do
            if recipe.acquisition or recipe.sourceType == "other" then
                out[#out + 1] = {kind = "learn", spell = recipe.spellID, recipe = recipe.spellID,
                    id = recipe.acquisition and recipe.acquisition.item,
                    action = ns.T(p.known[recipe.spellID] and "levelUnlearn" or "levelLearned"), costText = "",
                    detail = ns.T("levelStepRange", recipe.requiredSkill, recipe.gray), tip = ns.T("levelFormulaTip")}
            end
        end
        return out
    end
    if self.mode == "steps" then
        for _, group in ipairs(model.brackets) do
            out[#out + 1] = {kind = "bracket", key = group.key, group = group}
            if not self.collapsed[group.key] then
                for _, step in ipairs(group.steps) do
                    out[#out + 1] = {kind = "step", spell = step.spell, stage = step.index, depth = 1,
                        expandable = true, opened = self.stepsOpen[step.index], action = ns.T("levelVariants"),
                        detail = ns.T(p.profession == "enchanting" and "levelStep" or "levelStepRange", step.first, step.target, step.gains),
                        quantity = p.strategy == "free" and ns.T("levelExpectedCasts", ns.Decimal(step.count + step.extra, 2)) or ns.T("levelCasts", step.count + step.extra), cost = step.missing == 0 and step.cost or nil,
                        tip = (p.strategy == "free" and ns.T("levelExpectedTip", ns.Decimal(step.count, 2)) or ns.T(step.uncertain and "levelUncertain" or "levelOrange")) .. "\n" .. self:Tip()}
                    if self.stepsOpen[step.index] then
                        out[#out + 1] = {kind = "auto", stage = step.index, first = step.first, target = step.target, depth = 2,
                            label = ns.T("levelAutomatic"), action = ns.T("levelResetChoice"), costText = ""}
                        for _, alt in ipairs(ns.Leveling.Alternatives(model.route, step)) do
                            out[#out + 1] = {kind = alt.locked and "learn" or "alternative", stage = step.index, spell = alt.spell, depth = 2,
                                recipe = alt.spell, first = step.first, target = step.target,
                                active = alt.spell == step.spell, action = ns.T(alt.locked and "levelLearned" or "levelChoose"),
                                detail = ns.T(alt.locked and "levelNeedsKnown" or alt.uncertain and "levelUncertain" or "levelOrange"),
                                quantity = not alt.locked and (p.strategy == "free" and ns.T("levelExpectedCasts", ns.Decimal(alt.count + alt.extra, 2)) or ns.T("levelCasts", alt.count + alt.extra)) or "",
                                cost = alt.missing == 0 and alt.cost or nil,
                                tip = ns.T("levelVariantTip")}
                        end
                        local acquisition = c.recipes[step.spell].acquisition
                        if acquisition then
                            out[#out + 1] = {kind = "learn", recipe = step.spell, id = acquisition.item, depth = 2,
                                action = ns.T(p.known[step.spell] and "levelUnlearn" or "levelLearned"), costText = "",
                                detail = ns.T(p.known[step.spell] and "levelAlreadyKnown" or "levelAcquireFormula"), tip = ns.T("levelFormulaTip")}
                        end
                        for _, tool in ipairs(step.tools) do
                            out[#out + 1] = {id = tool.item, depth = 2, costText = "", quantity = "1",
                                detail = ns.T(tool.gain and "levelToolGain" or "levelToolNoGain"), tip = self:Tip()}
                            local formula = c.recipes[tool.spell].acquisition
                            if formula then
                                out[#out + 1] = {kind = "learn", recipe = tool.spell, id = formula.item, depth = 3,
                                    action = ns.T(p.known[tool.spell] and "levelUnlearn" or "levelLearned"), costText = "",
                                    detail = ns.T(p.known[tool.spell] and "levelAlreadyKnown" or "levelAcquireFormula"),
                                    tip = ns.T("levelFormulaTip")}
                            end
                        end
                    end
                end
            end
        end
    else
        local function add(node)
            local vendor = node.quote and node.quote.vendor
            out[#out + 1] = {kind = "material", id = node.id, depth = node.depth + 1,
                need = node.need, quote = node.quote, expandable = node.expandable, opened = p.open[node.id],
                detail = ns.T("levelMaterial", node.count, node.own, node.need)
                    .. (node.extra and node.extra > 0 and ns.T("levelSurplus", node.extra) or "")
                    .. (node.quote and node.quote.via and " " .. ns.T("levelVia") or ""),
                action = node.quote and node.quote.via and ns.T("levelVia") or node.expandable and ns.T(node.crafted and "levelMake" or "levelBuySource")
                    or (node.need > 0 and not vendor and ns.T("tradeBuy") or nil),
                quantity = K.Money(node.quote and node.quote.price), cost = not node.incomplete and node.cost or nil,
                tip = ns.T("levelMaterialTip") .. (node.quote and node.quote.via and "\n" .. ns.T("levelViaTip") or "") .. (vendor and "\n" .. ns.T("levelVendorTip") or "")
                    .. (node.quote and node.quote.at and "\n" .. ns.T("cacheObserved", date("%d.%m %H:%M", node.quote.at)) or "")}
            if p.open[node.id] then
                if node.crafted then for _, child in ipairs(node.children) do add(child) end
                else
                    local obtain = ns.Leveling.Obtain(node.id, p)
                    if obtain then
                        local crafts = math.ceil(node.need / obtain.count)
                        for _, input in ipairs(obtain.inputs) do
                            out[#out + 1] = {id = input[1], depth = node.depth + 2, costText = "",
                                detail = ns.T("levelPreview"), quantity = tostring(input[2] * crafts)}
                        end
                    end
                end
            end
        end
        for _, node in ipairs(model.basket.roots) do add(node) end
    end
    return out
end
function UI:Tip()
    return ns.T(self.props.strategy == "free" and "levelFreeModelTip" or "levelModelTip") .. (self.props.profession == "enchanting" and "\n" .. ns.T("levelEnchantingTip") or "")
end
function UI:Render()
    if not self.frame or not self.frame:IsVisible() then return end
    local K, p, model = ns.TradeKit, self.props, self:Model()
    for edit, value in pairs({[self.first] = p.first, [self.target] = p.target, [self.reserve] = p.reserve}) do
        if not edit:HasFocus() then edit:SetText(tostring(value)) end
    end
    self.owned:SetChecked(p.owned)
    if #ns.levelingCatalogs[p.profession].tools > 0 then
        self.tool.frame:SetText(ns.T("levelTool" .. p.tool)); self.tool.frame:Show()
    else self.tool.frame:Hide(); self.tool.cover:Hide() end
    self.help.tipFn = function() return self:Tip() end
    self.modes:Select(self.mode)
    self.strategies:Select(p.strategy)
    if p.strategy == "free" then self.reserve:Hide(); self.reserveLabel:Hide()
    else self.reserve:Show(); self.reserveLabel:Show() end
    self.formulas:SetActive(self.formulasOpen == true)
    local values = {model.lower.missing == 0 and model.lower.cost or nil, model.basket.cost, model.basket.cash, model.basket.lotsCost}
    local width = math.floor(((self.frame:GetWidth() or 996) - 38) / 4)
    for i, tile in ipairs(self.tiles) do
        tile.frame:ClearAllPoints(); tile.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10 + (i - 1) * (width + 6), -66)
        tile:SetProps({title = ns.T("levelTile" .. i), value = K.Money(values[i]), width = width, tip = self:Tip()})
    end
    for i, comparison in ipairs(self.comparisons) do
        local half = math.floor(((self.frame:GetWidth() or 996) - 20) / 2)
        comparison.frame:SetWidth(half)
        comparison.frame:ClearAllPoints(); comparison.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10 + (i - 1) * half, -114)
        local route = i == 1 and model.guide or model.free
        comparison.value:SetText(K.Money(route.missing == 0 and route.cost or nil))
    end
    self.statusText = model.route.unavailable and ns.T("levelUnavailable") or model.basket.missing > 0 and ns.T("levelIncomplete")
        or not model.route.comparison and ns.T("levelComparison") or ""
    ns.Trader.RenderStatus()
    local entries = self:Entries(model)
    local visible = K.ListCapacity(self.frame, 152, 46, 38, #self.rows)
    local offset = self.scroll:SetRange(#entries, visible)
    for _, group in ipairs(self.groups) do group.frame:Hide() end
    local used = 0
    for i, row in ipairs(self.rows) do
        local entry = i <= visible and entries[offset + i]
        local y = -152 - (i - 1) * 38
        if entry and entry.kind == "bracket" then
            row.frame:Hide(); used = used + 1
            local view, group = self.groups[used], entry.group
            view.frame:ClearAllPoints(); view.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, y)
            view:SetProps({key = group.key, width = (self.frame:GetWidth() or 996) - 36, height = 38,
                open = not self.collapsed[group.key], name = ns.T("levelRank" .. group.key, group.first, group.target),
                detail = ns.T("levelBracketCosts", K.Money(group.cost), K.Money(group.cash)), tip = self:Tip(),
                sources = function() return self:BracketSources(group) end, scanTip = ns.T("levelBracketScanTip")})
        elseif entry then
            row.frame:ClearAllPoints(); row.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, y)
            entry.width = (self.frame:GetWidth() or 996) - 36; row:SetProps(entry)
        else row.frame:Hide() end
    end
    self:Controls()
end
function UI:BracketSources(group)
    local vendors, ids, seen = ns.levelingCatalogs[self.props.profession].vendors, {}, {}
    for _, step in ipairs(group.steps) do
        for id in pairs(step.inputs) do
            if not seen[id] and not vendors[id] then seen[id] = true; ids[#ids + 1] = id end
        end
    end
    table.sort(ids)
    return ids
end
function UI:New(parent)
    local K = ns.TradeKit
    self.frame = ns.NewFrame("Frame", nil, parent); self.frame:SetAllPoints(parent)
    local f = self.frame
    K.Label(f, ns.T("levelFrom"), 10, -10, 24)
    self.first = K.Edit(f, 42); self.first:SetPoint("TOPLEFT", f, "TOPLEFT", 38, -4)
    K.Label(f, ns.T("levelTo"), 87, -10, 24)
    self.target = K.Edit(f, 42); self.target:SetPoint("TOPLEFT", f, "TOPLEFT", 112, -4)
    self.first:SetNumeric(true); self.target:SetNumeric(true); self.first:SetMaxLetters(3); self.target:SetMaxLetters(3)
    local function read()
        local first, target, reserve = tonumber(self.first:GetText()), tonumber(self.target:GetText()), tonumber(self.reserve:GetText())
        self:SetProps({first = first or self.props.first, target = target or self.props.target, reserve = reserve or 0})
    end
    self.read = read
    K.LiveEdit(self.first, read, 0.8); K.LiveEdit(self.target, read, 0.8)
    self.scan = K.Button(f, ns.T("levelScanRoute"), 166, function() ns.Leveling.Complete(self.props, false, K.ScanMode()); self:Controls() end, "main")
    self.scan:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
    self.all = K.Button(f, ns.T("levelScanProfession"), 166, function() ns.Leveling.Complete(self.props, true, K.ScanMode()); self:Controls() end)
    self.all:SetPoint("RIGHT", self.scan, "LEFT", -6, 0)
    K.ScanTip(self.scan, ns.T("levelScanRoute"), ns.T("levelScanTip"), function() return ns.Leveling.Targets(self.props, false) end)
    K.ScanTip(self.all, ns.T("levelScanProfession"), ns.T("levelScanAllTip"), function() return ns.Leveling.Targets(self.props, true) end)
    self.modes = K.Segment(f, {{key = "steps", label = ns.T("levelSteps")}, {key = "materials", label = ns.T("levelMaterials")}},
        function(mode) self.mode = mode; self.scroll.offset = 0; self:Render() end)
    self.modes.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -34)
    self.strategies = K.Segment(f, {{key = "guide", label = ns.T("levelGuide")}, {key = "free", label = ns.T("levelFree")}},
        function(strategy) self:SetProps({strategy = strategy}) end)
    self.strategies.frame:SetPoint("LEFT", self.modes.frame, "RIGHT", 12, 0)
    self.formulas = K.Button(f, ns.T("levelFormulas"), 100, function()
        self.formulasOpen = not self.formulasOpen; self.scroll.offset = 0; self:Render()
    end, "quiet")
    self.formulas:SetPoint("LEFT", self.strategies.frame, "RIGHT", 12, 0)
    self.comparisons = {}
    for i, key in ipairs({"levelGuide", "levelFree"}) do
        local comparison = {frame = ns.NewFrame("Frame", nil, f)}
        comparison.frame:SetHeight(14)
        comparison.label, comparison.value = K.ValueRow(comparison.frame, ns.T(key), 0, 110, 160)
        self.comparisons[i] = comparison
    end
    local reserveLabel = K.Label(f, ns.T("levelReserve"), 0, 0, 50)
    self.reserveLabel = reserveLabel
    reserveLabel:ClearAllPoints(); reserveLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 14)
    self.reserve = K.Edit(f, 32); self.reserve:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 63, 8)
    self.reserve:SetMaxLetters(2); self.reserve:SetNumeric(true); K.LiveEdit(self.reserve, read)
    K.Tooltip(self.reserve, ns.T("levelReserve"), ns.T("levelReserveTip"))
    for _, edit in ipairs({self.first, self.target, self.reserve}) do
        edit:SetScript("OnEditFocusLost", function(box) K.FlushEdits(box); self:Render() end)
    end
    self.owned = K.Check(f, function(checked) self:SetProps({owned = checked}) end)
    self.owned:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 106, 8)
    local stockLabel = K.Label(f, ns.T("levelStock"), 0, 0, 130)
    stockLabel:ClearAllPoints(); stockLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 127, 14)
    local tools = {}
    for tier = 0, #ns.levelingCatalogs[self.props.profession].tools do tools[#tools + 1] = {key = tier, labelKey = "levelTool" .. tier} end
    self.tool = K.Menu(f, tools, function(tier) self:SetProps({tool = tier}) end)
    self.tool.frame:SetWidth(190); self.tool.frame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -4)
    K.Tooltip(self.tool.frame, ns.T("levelToolTitle"), ns.T("levelToolTip"))
    self.tiles = {}
    for i = 1, 4 do self.tiles[i] = K.StatTile:New(f) end
    self.help = K.InfoButton(f, ns.T("levelTitle"), self:Tip())
    self.help:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -138)
    K.TableHeader(f, -144)
    self.scroll = K.TableScroll(f, function() self:Render() end, 152, 46, 38)
    for i = 1, 40 do
        local row = K.LevelingRow:New(f, function(entry, button) self:Action(entry, button) end, function(entry) self:Expand(entry) end)
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -152 - (i - 1) * 38)
        self.rows[i] = row; self.scroll:Wheel(row.frame)
    end
    for i = 1, 6 do
        local group = K.GroupRow:New(f, function(key) self:Action({kind = "bracket", key = key}) end, function() self:Render() end)
        group.frame:Hide(); self.scroll:Wheel(group.frame); self.groups[i] = group
    end
    f:SetScript("OnSizeChanged", function() self:Render() end)
    self:Render()
    return self
end
