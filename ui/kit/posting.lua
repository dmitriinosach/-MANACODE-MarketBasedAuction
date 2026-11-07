local _, ns = ...
local K = ns.TradeKit
local PostForm = {}
PostForm.__index = PostForm
K.PostForm = PostForm
PostForm.HEIGHT = 330
PostForm.LEVELS, PostForm.LEVELS_MIN, PostForm.LEVELS_MAX = 3, 1, 5
PostForm.STEP = 16
local ROW = 24
local RULE = 5
local HOURS = {12, 24, 48}
local function at(frame, parent, x, y)
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y); frame:Show()
end
local function rule(line, parent, y)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", K.theme.inset, -y)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -K.theme.inset, -y)
    line:Show()
end
local function textWidth(label, fallback, limit)
    return math.ceil(math.min(limit, label:GetStringWidth() or fallback))
end
local function draft(view)
    return ns.Posting.Draft(view.props.id, view.props.link)
end
local function field(view, width, apply)
    local edit = K.Edit(view.frame, width)
    edit:SetJustifyH("RIGHT")
    K.LiveEdit(edit, function(box)
        if not view.props then return end
        apply(draft(view), box:GetText() or "")
        view:Changed()
    end)
    return edit
end
local function help(parent, label, title, tipFn)
    local f = ns.NewFrame("Frame", nil, parent)
    f:SetAllPoints(label); f:EnableMouse(true)
    K.Tooltip(f, title, "")
    f.tipFn = tipFn
    return f
end
function PostForm:New(parent)
    local view = setmetatable({parent = parent, ladder = {}, packs = {}, rules = {}, height = PostForm.HEIGHT, status = "", progress = "", shown = 0}, self)
    local f = ns.NewFrame("Frame", nil, parent)
    view.frame = f
    f:SetHeight(PostForm.HEIGHT); f:SetWidth(258)
    view.caption = K.Label(f, "", 12, 0, 234, "secondary"); view.caption:SetHeight(12); view.caption:SetJustifyV("TOP")
    view.captionHelp = help(f, view.caption, ns.T("sellLadderName"), function()
        return ns.T("sellLadderTip") .. (view.age and "\n" .. ns.T("postWallAgeTip", view.age) or "")
    end)
    view.reference = K.Label(f, "", 0, 0, 100, "secondary"); view.reference:SetHeight(12); view.reference:SetJustifyH("RIGHT")
    view.referenceHelp = help(f, view.reference, "", function()
        local ref = view.props and view.props.reference
        return ref and ref.tip or ""
    end)
    for i = 1, PostForm.LEVELS_MAX do
        local button = K.Button(f, "", 200, function() view:PickLevel(view.ladder[i].level) end, "quiet")
        button:SetHeight(PostForm.STEP - 1)
        button.text:ClearAllPoints(); button.text:SetPoint("LEFT", button, "LEFT", 6, 0)
        button.units = K.Label(button, "", 0, 0, 120, "secondary")
        button.units:ClearAllPoints(); button.units:SetPoint("RIGHT", button, "RIGHT", -6, 0)
        button.units:SetHeight(12); button.units:SetJustifyH("RIGHT")
        K.Tooltip(button, ns.T("sellLadderName"), "")
        button.tipFn = function() return view:LevelTip(button.level) end
        button:Hide()
        view.ladder[i] = button
    end
    view.priceLabel = K.Label(f, ns.T("postPrice"), 12, 0, 80); view.priceLabel:SetHeight(12)
    view.price = K.MoneyEdit(f, function(copper)
        if not view.props then return end
        draft(view).price = copper
        view:Changed()
    end)
    for _, edit in ipairs(view.price.edits) do
        K.Tooltip(edit, ns.T("postPrice"), "")
        edit.tipFn = function() return view:PriceTip() end
    end
    view.place = K.Label(f, "", 12, 0, 100, "secondary"); view.place:SetHeight(24); view.place:SetJustifyV("MIDDLE")
    view.placeHelp = help(f, view.place, ns.T("sellLadderName"), function()
        local plan = view.plan
        return plan and plan.ahead and ns.T("postAheadUnitsTip", plan.ahead[2]) or ""
    end)
    view.mode = K.Segment(f, {{key = "under", label = ns.T("postUnder"), tip = {ns.T("postUnder"), ns.T("postUnderTip")}},
        {key = "near", label = ns.T("postNear"), tip = {ns.T("postNear"), ns.T("postNearTip")}}}, function(mode)
        if not view.props then return end
        local d = draft(view)
        view.price:Discard()
        d.mode, d.price = mode, nil
        view:Changed()
    end)
    view.warning = K.Label(f, "", 12, 0, 234); view.warning:SetHeight(12)
    view.rules[1] = K.Rule(f, 0)
    local hours = {}
    for i, h in ipairs(HOURS) do hours[i] = {key = h, label = ns.T("postHours", h)} end
    view.hours = K.Segment(f, hours, function(h)
        if not view.props then return end
        draft(view).hours = h
        view:Changed()
    end, {ns.T("postHoursTitle"), ns.T("postHoursTip")})
    view.sizeLabel = K.Label(f, ns.T("postSize"), 12, 0, 40, "secondary"); view.sizeLabel:SetHeight(12)
    view.sizeEdit = field(view, 34, function(d, text)
        d.size = tonumber(text) and math.max(1, math.floor(tonumber(text))) or nil
    end)
    K.Tooltip(view.sizeEdit, ns.T("postSize"), ns.T("postSizeTip"))
    view.times = K.Label(f, ns.T("postLots"), 0, 0, 40, "secondary"); view.times:SetHeight(12)
    view.lotsEdit = field(view, 34, function(d, text)
        d.lots = tonumber(text) and math.max(1, math.floor(tonumber(text))) or nil
    end)
    K.Tooltip(view.lotsEdit, ns.T("postLots"), ns.T("postLotsTip"))
    view.quantity = K.Label(f, "", 0, 0, 80, "secondary"); view.quantity:SetHeight(12); view.quantity:SetJustifyH("RIGHT")
    view.quantityHelp = help(f, view.quantity, ns.T("postUnitsTitle"), function()
        local plan = view.plan
        return plan and ns.T("postUnitsTip", plan.lots, plan.size, plan.units, plan.remaining) or ""
    end)
    for i = 1, ns.Selling.PACKS do
        local button = K.Button(f, "", 44, function() view:PickPack(view.packs[i].pack) end, "quiet")
        button:SetHeight(20); button:Hide()
        K.Tooltip(button, ns.T("sellPacksTitle"), "")
        button.tipFn = function() return PostForm.PackTip(button.pack) end
        view.packs[i] = button
    end
    view.packEmpty = K.Label(f, "", 12, 0, 234, "secondary"); view.packEmpty:SetHeight(24); view.packEmpty:SetJustifyV("TOP")
    view.rules[2] = K.Rule(f, 0)
    view.total = K.Label(f, "", 12, 0, 140); view.total:SetHeight(16); K.BindFont(view.total, "normal")
    view.profit = K.Label(f, "", 0, 0, 100, "secondary"); view.profit:SetHeight(12); view.profit:SetJustifyH("RIGHT")
    view.totalHelp = ns.NewFrame("Frame", nil, f); view.totalHelp:EnableMouse(true)
    K.Tooltip(view.totalHelp, ns.T("postGetTitle"), "")
    view.totalHelp.tipFn = function() return view.summary and view.summary.tip or "" end
    view.post = K.Button(f, ns.T("postAction"), 120, function() view:Post() end, "main")
    K.FitButton(view.post, 32)
    K.Tooltip(view.post, ns.T("postAction"), ns.T("postActionTip"))
    view.checkOwned = K.Button(f, ns.T("postCheckOwned"), 160, function() view:CheckOwned() end)
    K.FitButton(view.checkOwned, 24)
    K.Tooltip(view.checkOwned, ns.T("postCheckOwned"), ns.T("postCheckOwnedTip"))
    view.checkOwned:Hide()
    view.note = K.Label(f, "", 12, 0, 234, "secondary"); view.note:SetHeight(28); view.note:SetJustifyV("TOP")
    f:SetScript("OnUpdate", function()
        if view.props and ns.Posting.CanCheckPending() and not view.recover then view:Render() end
    end)
    return view
end
function PostForm:SetProps(props)
    self.props = props; self:Render()
end
function PostForm:Place(top)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 0, top)
end
function PostForm:Changed()
    self.error = nil
    self:Render()
    if self.props and self.props.onChange then self.props.onChange() end
end
function PostForm:Evaluate()
    local p = self.props
    return ns.Posting.Evaluate(p.id, ns.Posting.State(p.id, p.fee, p.link))
end
function PostForm:PickLevel(level)
    if not level or not self.props then return end
    self.price:Discard()
    draft(self).price = math.max(1, level.price - 1)
    self:Changed()
end
function PostForm:PickPack(pack)
    if not pack or not self.props then return end
    local d = draft(self)
    d.size, d.lots = pack.stack, pack.size > pack.stack and pack.count or nil
    self:Changed()
end
function PostForm:LevelTip(level)
    if not level or not self.plan then return "" end
    local lots, units = ns.Posting.Ahead(self.plan.wall, level.price)
    local lines = {ns.T("sellLadderRowTip", K.Money(math.max(1, level.price - 1)), lots, units)}
    if level.ownUnits > 0 then lines[#lines + 1] = ns.T("sellLadderOwnTip", level.ownUnits) end
    return table.concat(lines, "\n")
end
function PostForm:PriceTip()
    local plan = self.plan
    local tip = ns.T("postPriceTip")
    if plan and plan.floor then tip = tip .. "\n" .. ns.T("postFloorTip", K.Money(plan.floor)) end
    return tip
end
function PostForm.PackTip(pack)
    if not pack then return "" end
    local lines = {}
    if pack.size > pack.stack then lines[#lines + 1] = ns.T("sellPackBatch", pack.size, pack.count, pack.stack) end
    if pack.full then lines[#lines + 1] = ns.T("sellPackFull", pack.size)
    elseif pack.common then lines[#lines + 1] = ns.T("sellPackCommon") end
    if #pack.uses > 0 then lines[#lines + 1] = ns.T("sellPackUses", table.concat(pack.uses, ", ")) end
    if pack.lots > 0 then
        local premium = pack.premium and ns.T("sellPackPremium", pack.premium) or ""
        lines[#lines + 1] = ns.T("sellPackWall", pack.lots) .. premium
    else lines[#lines + 1] = ns.T("sellPackNoWall") end
    if pack.best then lines[#lines + 1] = ns.T("sellPackBest") end
    lines[#lines + 1] = ns.T("sellPackClick")
    return table.concat(lines, "\n")
end
function PostForm:Caption(plan)
    local wall = plan.wall
    if plan.variant then return ns.T("sellVariantManual") end
    if wall.lowest then
        local base = ns.T("postWall", wall.lots, wall.units)
        local partial = wall.partial and ns.T("sellLadderPartial") or ""
        if not wall.at then return base .. partial end
        local age = K.Ago(math.max(0, time() - wall.at))
        return base .. ns.T("postWallAge", age) .. partial, base .. partial, age
    end
    local q = ns.Markets.Quote(self.props.id, true)
    return ns.T(q and q.complete ~= false and (q.miss or 0) == 0 and q.lots == 0 and "sellPriceEmptyTip" or "sellPriceUnknownTip")
end
function PostForm.Standing(plan)
    if plan.variant or not plan.unit then return "", "secondary" end
    local lots, units, same = plan.ahead[1], plan.ahead[2], plan.ahead[3] or 0
    if lots > 0 then return ns.T("postAheadOf", lots, units), "secondary" end
    if same > 0 then return ns.T("postAheadTie", same), "gold" end
    return ns.T("postAheadFirst"), "positive"
end
function PostForm:Summary(plan)
    local fee = math.floor((self.props.fee or ns.Fee()) * 100 + 0.5)
    local text = plan.total and ns.T("postGet", K.Money(plan.total)) or ns.T("postGetNone")
    local note, tone = "", "secondary"
    if plan.profit then
        local profit = plan.profit * plan.lots
        note, tone = ns.T("postProfitAll", (profit > 0 and "+" or "") .. K.Money(profit)), K.Tone(profit)
    elseif plan.unit and not plan.variant then note = ns.T("postNoCostShort") end
    local lines = {ns.T("postGetTip", fee)}
    if plan.buyout then
        local lot = ns.T("postLotTip", K.Money(plan.buyout), K.Money(plan.net))
        if plan.profit then lot = lot .. ns.T("postLotProfit", K.Money(plan.profit)) end
        lines[#lines + 1] = lot
    end
    lines[#lines + 1] = ns.T(plan.depositKnown and "postDepositNow" or "postDepositNowMin", K.Money(plan.deposit * plan.lots))
    if plan.floor then lines[#lines + 1] = ns.T("postFloorTip", K.Money(plan.floor))
    elseif not plan.variant then lines[#lines + 1] = ns.T("postNoCostTip") end
    return {text = text, note = note, tone = tone, title = ns.T("postGetTitle"), tip = table.concat(lines, "\n")}
end
function PostForm:Status(plan)
    local p, P = self.props, ns.Posting
    if self.error then return ns.T(self.error), true end
    local open = P.Open()
    if not open then return ns.T("postNoAuction"), false end
    if P.CanCheckPending() then return ns.T("postCheckPendingNote"), true end
    local key = P.ItemKey(p.link) or p.id
    if P.pending and P.pending.id == p.id and (P.ItemKey(P.pending.link) or P.pending.id) == key then
        return P.pending.lots > 1 and ns.T("postBatchProgress", P.pending.created, P.pending.lots)
            or ns.T("postSent", P.pending.size, K.Money(P.pending.buyout)), true
    end
    if P.last and P.last.id == p.id and (P.ItemKey(P.last.link) or P.last.id) == key then
        return P.last.uncertain and ns.T("postCheckPendingNote")
            or P.last.lots and ns.T(P.last.failed and "postBatchFailed" or "postBatchDone", P.last.lots)
            or ns.T("postDone", P.last.size, K.Money(P.last.buyout)), true
    end
    if P.pending then return ns.T("postPending"), true end
    if plan.err then return ns.T(plan.err), false end
    return "", false
end
function PostForm:Action(plan)
    local P = ns.Posting
    if self.recover then
        return {key = "check", label = ns.T("postCheckOwned"), tip = ns.T("postCheckOwnedTip"), fn = function() self:CheckOwned() end}
    end
    local reason = not P.Open() and ns.T("postNoAuction") or P.pending and ns.T("postPending")
        or plan.err and ns.T(plan.err) or nil
    return {key = "post", main = true, label = ns.T("postBatchAction", plan.lots), title = ns.T("postAction"),
        tip = ns.T("postActionTip"), reason = reason, fn = function() self:Post() end}
end
function PostForm:Render()
    local p = self.props
    if not p then return end
    local width = p.width or 258
    local inner = width - 24
    self.frame:SetWidth(width)
    local plan = self:Evaluate()
    self.plan = plan
    local y = self:RenderPrice(plan, inner)
    y = self:RenderLot(plan, inner, y)
    local status, progress = self:Status(plan)
    self.status, self.progress = status, progress and status or ""
    y = self:RenderFoot(plan, inner, y)
    self.height = y
    self.frame:SetHeight(y)
end
function PostForm:RenderCaption(plan, inner)
    local f, ref = self.frame, self.props.reference
    local room = inner
    if ref and ref.text and ref.text ~= "" then
        self.reference:SetText(ref.text)
        local refWidth = textWidth(self.reference, 70, math.floor(inner / 2))
        self.reference:SetWidth(refWidth + 2)
        self.reference:ClearAllPoints(); self.reference:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, 0); self.reference:Show()
        self.referenceHelp.tipTitle = ref.title or ref.text
        self.referenceHelp:Show()
        room = inner - refWidth - 8
    else
        self.reference:SetText(""); self.reference:Hide(); self.referenceHelp:Hide()
    end
    local text, short, age = self:Caption(plan)
    self.caption:SetWidth(room)
    self.caption:SetText(text)
    self.age = nil
    if short and (self.caption:GetStringWidth() or 0) > room then
        self.caption:SetText(short); self.age = age
    end
    local lines = 1
    if plan.variant or not plan.wall.lowest then
        lines = math.max(1, math.min(3, math.ceil((self.caption:GetStringWidth() or 0) / math.max(1, room))))
    end
    self.caption:SetHeight(lines * 12)
    at(self.caption, f, 12, 0)
    return lines * 12 + 1
end
function PostForm:RenderPrice(plan, inner)
    local f, d = self.frame, draft(self)
    local y = self:RenderCaption(plan, inner)
    local levels = plan.variant and {} or plan.wall.levels
    self.shown = 0
    local shown = math.max(1, math.min(PostForm.LEVELS_MAX, self.props.levels or PostForm.LEVELS))
    for i, button in ipairs(self.ladder) do
        local level = i <= shown and levels[i] or nil
        button.level = level
        if level then
            button:SetWidth(inner)
            at(button, f, 12, y)
            button:SetText(K.Money(level.price))
            button.units:SetWidth(math.max(40, inner - 96))
            button.units:SetText(ns.T("sellLadderUnits", level.units, level.lots)
                .. (level.ownUnits > 0 and ns.T("sellLadderOwn", level.ownUnits) or ""))
            button:SetActive(plan.unit and plan.unit < level.price
                and (i == 1 or plan.unit >= levels[i - 1].price) or false)
            y = y + PostForm.STEP
            self.shown = i
        else button:Hide() end
    end
    y = y + 1
    self.priceLabel:SetText(ns.T(d.price and "postOwnPrice" or "postPrice"))
    self.priceLabel:SetWidth(math.max(40, inner - (self.price.frame:GetWidth() or 148) - 6))
    at(self.priceLabel, f, 12, y + 5)
    self.price.frame:ClearAllPoints(); self.price.frame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -y)
    self.price:SetValue(plan.unit)
    y = y + ROW
    self.mode:Select(not d.price and (d.mode or "under") or nil)
    if plan.variant then self.mode:Disable() else self.mode:Enable() end
    self.mode.frame:ClearAllPoints(); self.mode.frame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -y)
    local standing, tone = PostForm.Standing(plan)
    self.place:SetWidth(math.max(40, inner - (self.mode.frame:GetWidth() or 120) - 6))
    self.place:SetText(standing)
    self.place:SetTextColor(unpack(K.theme[tone]))
    at(self.place, f, 12, y - 1)
    self.placeHelp:EnableMouse(standing ~= "" and plan.ahead[1] > 0)
    y = y + ROW
    local warning, warningTone
    if plan.below then warning, warningTone = ns.T("postBelow", K.Money(plan.floor)), "negative"
    elseif plan.raised then warning, warningTone = ns.T("postRaisedTo", K.Money(plan.floor)), "secondary" end
    if warning then
        self.warning:SetWidth(inner); self.warning:SetText(warning)
        self.warning:SetTextColor(unpack(K.theme[warningTone]))
        at(self.warning, f, 12, y)
        y = y + 16
    else self.warning:SetText(""); self.warning:Hide() end
    return y
end
function PostForm:RenderLot(plan, inner, y)
    local f = self.frame
    rule(self.rules[1], f, y + 1)
    y = y + RULE
    self.hours:Select(plan.hours)
    at(self.hours.frame, f, 12, y)
    self.quantity:SetWidth(math.max(30, inner - (self.hours.frame:GetWidth() or 140) - 6))
    self.quantity:SetText(ns.T("postUnits", plan.units, plan.have))
    self.quantity:ClearAllPoints(); self.quantity:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -(y + 5)); self.quantity:Show()
    y = y + ROW
    local sizeWidth = textWidth(self.sizeLabel, 34, 60)
    self.sizeLabel:SetWidth(sizeWidth + 2)
    at(self.sizeLabel, f, 12, y + 5)
    at(self.sizeEdit, f, 12 + sizeWidth + 4, y)
    local x = 12 + sizeWidth + 4 + (self.sizeEdit:GetWidth() or 34) + 10
    local timesWidth = textWidth(self.times, 34, 60)
    self.times:SetWidth(timesWidth + 2)
    at(self.times, f, x, y + 5)
    at(self.lotsEdit, f, x + timesWidth + 4, y)
    if not self.sizeEdit:HasFocus() then self.sizeEdit:SetText(tostring(plan.size)) end
    if not self.lotsEdit:HasFocus() then self.lotsEdit:SetText(tostring(plan.lots)) end
    for _, edit in ipairs({self.sizeEdit, self.lotsEdit}) do
        edit:EnableMouse(not plan.variant); edit:EnableKeyboard(not plan.variant)
        if plan.variant then edit:ClearFocus() end
    end
    self.sizeEdit.tip = ns.T("postSizeTip") .. "\n" .. ns.T("postSize_" .. plan.reason, ns.Posting.StackLimit(self.props.id))
    y = y + ROW
    return self:RenderPacks(plan, inner, y)
end
function PostForm:RenderPacks(plan, inner, y)
    local f = self.frame
    local packs, limit = ns.Selling.Packs(self.props.id, self.props.fee or ns.Fee())
    if plan.variant then packs = {} end
    local x, room = 12, 12 + inner
    for i, button in ipairs(self.packs) do
        local pack = packs[i]
        if pack then
            button:SetText(ns.T("sellPackSize", pack.size))
            K.FitButton(button, 16)
            button:SetWidth(math.max(28, button:GetWidth() or 28))
        end
        if pack and x + (button:GetWidth() or 28) <= room then
            button.pack = pack
            at(button, f, x, y)
            x = x + (button:GetWidth() or 28) + 4
            button:SetActive(pack.size > limit and plan.units == pack.size or plan.size == pack.size)
        else button.pack = nil; button:Hide() end
    end
    local empty = ""
    if plan.variant then empty = ns.T("sellVariantSingle")
    elseif not limit then empty = ns.T("sellPacksWait")
    elseif limit < 2 then empty = ns.T("sellPacksSingle")
    elseif #packs == 0 then empty = ns.T("sellPacksNone") end
    self.packEmpty:SetText(empty)
    if empty ~= "" then
        self.packEmpty:SetWidth(inner)
        at(self.packEmpty, f, 12, y + 1)
    else self.packEmpty:Hide() end
    return y + 22
end
function PostForm:RenderFoot(plan, inner, y)
    local p, f, P = self.props, self.frame, ns.Posting
    local open = P.Open()
    self.recover = open and P.CanCheckPending() or false
    local summary = self:Summary(plan)
    self.summary = summary
    local foot = {self.rules[2], self.total, self.profit, self.totalHelp, self.post, self.checkOwned, self.note}
    if p.band then
        for _, part in ipairs(foot) do part:Hide() end
        p.band:SetProps({actions = {self:Action(plan)}, summary = summary})
        return y
    end
    rule(self.rules[2], f, y + 1)
    y = y + RULE + 2
    self.profit:SetText(summary.note)
    self.profit:SetTextColor(unpack(K.theme[summary.tone]))
    local profitWidth = textWidth(self.profit, 90, math.floor(inner * 0.45))
    self.profit:SetWidth(profitWidth + 2)
    self.profit:ClearAllPoints(); self.profit:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -(y + 3)); self.profit:Show()
    self.total:SetWidth(math.max(60, inner - profitWidth - 8)); self.total:SetText(summary.text)
    at(self.total, f, 12, y)
    self.totalHelp:ClearAllPoints()
    self.totalHelp:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -y); self.totalHelp:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -y)
    self.totalHelp:SetHeight(16); self.totalHelp:Show()
    y = y + 20
    self.post:SetText(ns.T("postBatchAction", plan.lots)); K.FitButton(self.post, 32)
    if self.recover then self.post:Hide(); at(self.checkOwned, f, 12, y)
    else at(self.post, f, 12, y); self.checkOwned:Hide() end
    if open and not plan.err and not P.pending then self.post:Enable() else self.post:Disable() end
    y = y + 26
    self.note:SetWidth(inner); self.note:SetText(self.status)
    at(self.note, f, 12, y)
    return y + 28
end
function PostForm:CheckOwned()
    if ns.Posting.CheckPending() and self.props and self.props.onCheckOwned then self.props.onCheckOwned() end
end
function PostForm:Post()
    local p = self.props
    if not p then return false end
    local P = ns.Posting
    self.price:Flush()
    K.FlushEdits(self.sizeEdit, self.lotsEdit)
    local ok, err = P.Post(self:Evaluate())
    self.error = not ok and err or nil
    self:Render()
    if not ok then
        if p.onChange then p.onChange() end
        return false
    end
    if p.onPosted then p.onPosted() end
    return true
end
