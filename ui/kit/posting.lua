local _, ns = ...
local K = ns.TradeKit
local PostForm = {}
PostForm.__index = PostForm
K.PostForm = PostForm
PostForm.HEIGHT = 376
local HOURS = {[12] = 24, [24] = 48, [48] = 12}
local function field(view, width, apply)
    local edit = K.Edit(view.frame, width)
    edit:SetJustifyH("RIGHT")
    K.LiveEdit(edit, function(box)
        if not view.props then return end
        apply(ns.Posting.Draft(view.props.id, view.props.link), box:GetText() or "")
        view:Changed()
    end)
    return edit
end
local function chip(view, change)
    return K.Button(view.frame, "", 60, function()
        if not view.props then return end
        change(ns.Posting.Draft(view.props.id, view.props.link))
        view:Changed()
    end)
end
function PostForm:New(parent)
    local view = setmetatable({parent = parent}, self)
    local f = ns.NewFrame("Frame", nil, parent)
    view.frame = f
    f:SetHeight(PostForm.HEIGHT); f:SetWidth(258)
    view.title = K.Label(f, ns.T("postTitle"), 12, 0, 140, "heading"); view.title:SetHeight(14)
    view.stock = K.Label(f, "", 0, 0, 100, "secondary")
    view.stock:ClearAllPoints(); view.stock:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -1)
    view.stock:SetHeight(12); view.stock:SetJustifyH("RIGHT")
    view.wall1 = K.Label(f, "", 12, -20, 234); view.wall1:SetHeight(26); view.wall1:SetJustifyV("TOP")
    view.wall2 = K.Label(f, "", 12, -48, 234, "secondary"); view.wall2:SetHeight(12)
    view.priceLabel = K.Label(f, ns.T("postPrice"), 12, -73, 80); view.priceLabel:SetHeight(12)
    view.price = K.MoneyEdit(f, function(copper)
        if not view.props then return end
        ns.Posting.Draft(view.props.id, view.props.link).price = copper
        view:Changed()
    end)
    view.price.frame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -68)
    for _, edit in ipairs(view.price.edits) do K.Tooltip(edit, ns.T("postPrice"), ns.T("postPriceTip")) end
    view.mode = chip(view, function(d) d.mode, d.price = d.mode == "near" and "under" or "near", nil end)
    view.mode:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -94)
    K.Tooltip(view.mode, ns.T("postModeTitle"), ns.T("postModeTip"))
    view.hours = chip(view, function(d) d.hours = HOURS[d.hours or 24] or 24 end)
    view.hours:SetPoint("LEFT", view.mode, "RIGHT", 4, 0)
    K.Tooltip(view.hours, ns.T("postHoursTitle"), ns.T("postHoursTip"))
    view.lotsEdit = field(view, 34, function(d, text)
        d.lots = tonumber(text) and math.max(1, math.floor(tonumber(text))) or nil
    end)
    view.lotsEdit:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -124)
    K.Tooltip(view.lotsEdit, ns.T("postLots"), ns.T("postLotsTip"))
    view.times = K.Label(f, ns.T("postLots"), 0, 0, 48, "secondary")
    view.times:ClearAllPoints(); view.times:SetPoint("RIGHT", view.lotsEdit, "LEFT", -6, 0)
    view.times:SetHeight(12); view.times:SetJustifyH("RIGHT")
    view.sizeEdit = field(view, 34, function(d, text)
        d.size = tonumber(text) and math.max(1, math.floor(tonumber(text))) or nil
    end)
    view.sizeEdit:SetPoint("TOPLEFT", f, "TOPLEFT", 84, -124)
    K.Tooltip(view.sizeEdit, ns.T("postSize"), ns.T("postSizeTip"))
    view.sizeLabel = K.Label(f, ns.T("postUnitsPerLot"), 0, 0, 66, "secondary")
    view.sizeLabel:ClearAllPoints(); view.sizeLabel:SetPoint("RIGHT", view.sizeEdit, "LEFT", -6, 0)
    view.sizeLabel:SetHeight(12)
    view.sizeHint = K.Label(f, "", 12, -150, 234, "secondary"); view.sizeHint:SetHeight(12)
    view.floor = K.Label(f, "", 12, -168, 234, "secondary"); view.floor:SetHeight(12)
    local _
    local labels, values = K.ValueRows(f, -192, {ns.T("postBuyout"), ns.T("postNet"), ns.T("postProfit"), ns.T("postDeposit")},
        {labelWidth = 106, valueWidth = 120, step = 17})
    view.valueLabels, view.valueTexts = labels, values
    view.buyout, view.net, view.profit = values[1], values[2], values[3]
    view.depositLabel, view.deposit = labels[4], values[4]
    view.depositHelp = ns.NewFrame("Frame", nil, f)
    view.depositHelp:SetAllPoints(view.depositLabel); view.depositHelp:EnableMouse(true)
    K.Tooltip(view.depositHelp, ns.T("postDeposit"), ns.T("postDepositTip"))
    view.total = K.Label(f, "", 12, -264, 234); view.total:SetHeight(12)
    view.quantity = K.Label(f, "", 12, -282, 234, "secondary"); view.quantity:SetHeight(28); view.quantity:SetJustifyV("TOP")
    view.post = K.Button(f, ns.T("postAction"), 120, function() view:Post() end, "main")
    view.post:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -314)
    K.FitButton(view.post, 32)
    K.Tooltip(view.post, ns.T("postAction"), ns.T("postActionTip"))
    view.checkOwned = K.Button(f, ns.T("postCheckOwned"), 160, function()
        if ns.Posting.CheckPending() and view.props and view.props.onCheckOwned then view.props.onCheckOwned() end
    end)
    view.checkOwned:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -314)
    K.FitButton(view.checkOwned, 24)
    K.Tooltip(view.checkOwned, ns.T("postCheckOwned"), ns.T("postCheckOwnedTip"))
    view.checkOwned:Hide()
    view.note = K.Label(f, "", 12, -344, 234, "secondary"); view.note:SetHeight(28); view.note:SetJustifyV("TOP")
    f:SetScript("OnUpdate", function()
        if view.props and ns.Posting.CanCheckPending() and not view.checkOwned:IsShown() then view:Render() end
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
    self:Render()
    if self.props and self.props.onChange then self.props.onChange() end
end
function PostForm:Evaluate()
    local p = self.props
    return ns.Posting.Evaluate(p.id, ns.Posting.State(p.id, p.fee, p.link))
end
function PostForm:Params(width, mode, hours)
    self.mode:SetText(ns.T(mode == "near" and "postNear" or "postUnder")); K.FitButton(self.mode, 18)
    self.hours:SetText(ns.T("postHours", hours)); K.FitButton(self.hours, 18)
    self.sizeLabel:Show()
end
function PostForm:Render()
    local p = self.props
    if not p then return end
    local P = ns.Posting
    local width = p.width or 258
    local inner = width - 24
    self.frame:SetWidth(width)
    for _, label in ipairs({self.wall1, self.wall2, self.floor, self.sizeHint, self.total, self.quantity, self.note}) do label:SetWidth(inner) end
    for i, label in ipairs(self.valueLabels) do
        label:SetWidth(math.min(106, math.floor(inner * 0.46)))
        self.valueTexts[i]:SetWidth(inner - label:GetWidth() - 6)
    end
    self.priceLabel:SetWidth(math.max(40, inner - (self.price.frame:GetWidth() or 138) - 6))
    local d = P.Draft(p.id, p.link)
    local plan = self:Evaluate()
    self.plan = plan
    local wall = plan.wall
    self.stock:SetText(ns.T("postHave", plan.have))
    if plan.variant then
        self.wall1:SetText(ns.T("sellVariantManual")); self.wall2:SetText("")
    elseif wall.lowest then
        self.wall1:SetText(ns.T("postWall", wall.lots, wall.units, K.Money(wall.lowest)))
        self.wall2:SetText(plan.unit and ns.T("postAhead", plan.ahead[1], plan.ahead[2]) or "")
    else
        local q = ns.Markets.Quote(p.id, true)
        self.wall1:SetText(ns.T(q and q.complete ~= false and (q.miss or 0) == 0 and q.lots == 0
            and "sellPriceEmptyTip" or "sellPriceUnknownTip")); self.wall2:SetText("")
    end
    self.priceLabel:SetText(ns.T(d.price and "postOwnPrice" or "postPrice"))
    self.price:SetValue(plan.unit)
    self:Params(width, d.mode, plan.hours)
    if plan.variant then self.mode:Disable() else self.mode:Enable() end
    if not self.sizeEdit:HasFocus() then self.sizeEdit:SetText(tostring(plan.size)) end
    if not self.lotsEdit:HasFocus() then self.lotsEdit:SetText(tostring(plan.lots)) end
    for _, edit in ipairs({self.sizeEdit, self.lotsEdit}) do
        edit:EnableMouse(not plan.variant); edit:EnableKeyboard(not plan.variant)
        if plan.variant then edit:ClearFocus() end
    end
    self.sizeHint:SetText(ns.T(plan.variant and "sellVariantSingle" or "postStackLimit", P.StackLimit(p.id)))
    self.sizeEdit.tip = ns.T("postSizeTip") .. "\n" .. ns.T("postSize_" .. plan.reason, P.StackLimit(p.id))
    local floorText = plan.floor and ns.T("postFloor", K.Money(plan.floor)) or ns.T("postNoCost")
    if plan.floor and plan.raised then floorText = floorText .. ns.T("postRaised") end
    self.floor:SetText(floorText)
    self.floor:SetTextColor(unpack(K.theme[plan.below and "negative" or "secondary"]))
    self.buyout:SetText(K.Money(plan.buyout))
    self.net:SetText(K.Money(plan.net))
    self.profit:SetText(plan.profit and K.Money(plan.profit) or ns.T("postNoCostShort"))
    self.profit:SetTextColor(unpack(K.theme[K.Tone(plan.profit)]))
    self.deposit:SetText(plan.depositKnown and ns.T("postDepositValue", K.Money(plan.deposit))
        or ns.T("postDepositMin", K.Money(plan.deposit)))
    self.total:SetText(plan.total and ns.T("postBatchNet", K.Money(plan.total)) or "")
    self.quantity:SetText(ns.T("postQuantity", plan.lots, plan.size, plan.units, plan.remaining))
    self.post:SetText(ns.T("postBatchAction", plan.lots)); K.FitButton(self.post, 32)
    local open = P.Open()
    local recover = open and P.CanCheckPending()
    if recover then self.post:Hide(); self.checkOwned:Show()
    else self.post:Show(); self.checkOwned:Hide() end
    if open and not plan.err and not P.pending then self.post:Enable() else self.post:Disable() end
    local note = ""
    if not open then note = ns.T("postNoAuction")
    elseif recover then note = ns.T("postCheckPendingNote")
    elseif P.pending and P.pending.id == p.id
        and (P.ItemKey(P.pending.link) or P.pending.id) == (P.ItemKey(p.link) or p.id) then
        note = P.pending.lots > 1 and ns.T("postBatchProgress", P.pending.created, P.pending.lots)
            or ns.T("postSent", P.pending.size, K.Money(P.pending.buyout))
    elseif P.last and P.last.id == p.id
        and (P.ItemKey(P.last.link) or P.last.id) == (P.ItemKey(p.link) or p.id) then
        note = P.last.uncertain and ns.T("postCheckPendingNote")
            or P.last.lots and ns.T(P.last.failed and "postBatchFailed" or "postBatchDone", P.last.lots)
            or ns.T("postDone", P.last.size, K.Money(P.last.buyout))
    elseif P.pending then note = ns.T("postPending")
    elseif plan.err then note = ns.T(plan.err) end
    self.note:SetText(note)
end
function PostForm:Post()
    local p = self.props
    if not p then return false end
    local P = ns.Posting
    self.price:Flush()
    K.FlushEdits(self.sizeEdit, self.lotsEdit)
    local ok, err = P.Post(self:Evaluate())
    if not ok then
        self.note:SetText(ns.T(err))
        return false
    end
    self:Render()
    if p.onPosted then p.onPosted() end
    return true
end
