local _, ns = ...
local K = ns.TradeKit
local Panel = {}
Panel.__index = Panel
K.PurchasePanel = Panel
Panel.OPTION_STEP = 25
Panel.HEAD = 22
function Panel:New(parent, opts)
    local panel = setmetatable({parent = parent, options = {}, opts = opts or {}}, self)
    local money = panel.opts.money or K.Money
    panel.money = money
    for i = 1, 3 do
        local option = K.Button(parent, "", 300, function() ns.Shopping.Option(i) end, "quiet")
        option.text:SetJustifyH("LEFT")
        K.Tooltip(option, ns.T("buyOptTitle"), ns.T("buyOptTip"))
        option:Hide()
        panel.options[i] = option
    end
    panel.limitLabel = K.Label(parent, ns.T("buyPriceLimit"), 0, 0, 90, "secondary")
    panel.limitLabel:SetHeight(12)
    panel.limit = K.MoneyEdit(parent, function(copper)
        if panel.opts.onLimit then panel.opts.onLimit() end
        ns.Shopping.SetPriceLimit(copper)
    end)
    panel.limit.frame:SetPoint("LEFT", panel.limitLabel, "RIGHT", 4, 0)
    for _, edit in ipairs(panel.limit.edits) do K.Tooltip(edit, ns.T("buyPriceLimit"), ns.T("buyPriceLimitTip")) end
    panel.lastLimit = K.Button(parent, ns.T("buyLastLimit"), 120, function()
        local unit = ns.Shopping.LastUnit(ns.Shopping.state.itemID)
        if not unit then return end
        if panel.opts.onLimit then panel.opts.onLimit() end
        panel.limit:ClearFocus()
        ns.Shopping.SetPriceLimit(unit)
    end, "quiet")
    K.FitButton(panel.lastLimit, 16)
    panel.lastLimit:SetPoint("LEFT", panel.limit.frame, "RIGHT", 6, 0)
    panel.lastLimit:Hide()
    K.Tooltip(panel.lastLimit, ns.T("buyLastLimit"), "")
    panel.lastLimit.tipFn = function()
        local entry = ns.Shopping.Entry(ns.Shopping.state.itemID or 0)
        local last = entry and entry.last
        if not last or (last.units or 0) <= 0 then return "" end
        return ns.T("buyLastLimitTip", last.units, K.Money(math.floor(last.spent / last.units)),
            K.Ago(math.max(0, time() - (last.at or 0))))
    end
    panel.table = K.Table:New(parent, {
        height = K.Table.LINE, columns = K.ShoppingLotColumns,
        headers = {{key = "unit", text = "buyColUnit"}, {key = "stacks", text = "buyColStacks", justify = "LEFT"},
            {key = "lot", text = "buyColLot"}},
        kinds = {row = {new = function(owner) return K.ShoppingLotRow:New(owner, money, ns.Shopping.Adjust) end}},
    })
    panel.heading = K.Label(parent, ns.T("buyLotsRecent"), 0, 0, 120, "heading")
    panel.heading:SetHeight(14)
    panel.heading:ClearAllPoints(); panel.heading:SetPoint("BOTTOMLEFT", panel.table.frame, "TOPLEFT", 4, 4)
    panel.age = K.Label(parent, "", 0, 0, 180, "secondary")
    panel.age:SetHeight(12)
    panel.age:ClearAllPoints(); panel.age:SetPoint("LEFT", panel.heading, "RIGHT", 8, 0)
    panel.refresh = K.IconButton(parent, "refresh", function()
        if panel.opts.refresh then panel.opts.refresh() else ns.Shopping.Refresh() end
    end, ns.T("buyModalSearch"), ns.T("buyModalSearchTip"))
    panel.refresh:ClearAllPoints(); panel.refresh:SetPoint("BOTTOMRIGHT", panel.table.frame, "TOPRIGHT", 0, 1)
    return panel
end
function Panel:Display(shown)
    if shown then
        self.limitLabel:Show(); self.limit.frame:Show(); self.table.frame:Show()
        self.heading:Show(); self.refresh:Show()
        return
    end
    for _, b in ipairs(self.options) do b:Hide() end
    self.limitLabel:Hide(); self.limit.frame:Hide(); self.lastLimit:Hide(); self.table.frame:Hide()
    self.heading:Hide(); self.age:Hide(); self.refresh:Hide()
end
function Panel:Place(place)
    self.place = place
end
function Panel.AgeText(seconds)
    if seconds < 60 then return ns.T("buyAgoSec", seconds) end
    return K.Ago(seconds)
end
function Panel:Render(props)
    props = props or {}
    local S, place = ns.Shopping.state, self.place or {x = 0, top = 0, width = 300}
    local active = props.active
    local count = 0
    for i, b in ipairs(self.options) do
        local plan = not props.none and S.options[i]
        b:SetWidth(place.width)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", self.parent, "TOPLEFT", place.x, -(place.top + (i - 1) * Panel.OPTION_STEP))
        if plan then
            count = i
            b:SetText(ns.T("buyOpt_" .. plan.kind, plan.units, self.money(plan.cost)))
            b:SetActive(S.plan ~= nil and S.plan.kind == plan.kind)
            if active then b:Disable() else b:Enable() end
            b:Show()
        else b:Hide() end
    end
    local limitTop = place.top + 8 + count * Panel.OPTION_STEP
    self.limitLabel:ClearAllPoints()
    self.limitLabel:SetPoint("TOPLEFT", self.parent, "TOPLEFT", place.x, -limitTop)
    self.limit:SetValue(S.priceLimit)
    self.limit:SetEnabled(not active)
    local lastUnit = S.itemID and ns.Shopping.LastUnit(S.itemID)
    if lastUnit then self.lastLimit:Show() else self.lastLimit:Hide() end
    if active or not lastUnit or S.priceLimit == lastUnit then self.lastLimit:Disable() else self.lastLimit:Enable() end
    self.table:Place({top = limitTop + 20 + Panel.HEAD, left = place.left or place.x - 4, right = place.right, bottom = place.bottom})
    local age = not props.none and not S.pendingID and ns.Shopping.Age() or nil
    if age then self.age:SetText(ns.T("buyLotsAge", Panel.AgeText(age))); self.age:Show() else self.age:Hide() end
    local busy = active or ns.Scan.state.phase ~= "idle"
    K.DisabledTip(self.refresh, ns.T("buyModalSearch"), busy and ns.T("batchBusy") or nil)
    if busy then self.refresh:Disable() else self.refresh:Enable() end
    local R = ns.Buy.state
    local run = active and S.run and R.itemID == S.itemID and R.want or nil
    local shown, seen = {}, {}
    if S.plan and not props.none then
        for _, pick in ipairs(S.plan.picks) do
            if pick.lots > 0 then shown[#shown + 1] = pick.offer; seen[pick.offer] = true end
        end
    end
    for _, offer in ipairs(props.none and {} or S.offers) do
        if not seen[offer] and offer.count > 0 then shown[#shown + 1] = offer end
    end
    self.table:SetLines(shown, function(offer, _, columns)
        local planned = S.plan and ns.Plan.LotsOf(S.plan, offer) or 0
        local picked = run and (run[offer] or 0) or planned
        return {offer = offer, columns = columns, active = active, limit = S.priceLimit, picked = picked,
            bought = run and math.max(0, planned - picked) or 0}
    end, {empty = props.empty})
    return count
end
