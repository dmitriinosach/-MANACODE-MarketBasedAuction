local _, ns = ...
local UI = {buttons = {}}
UI.__index = UI
ns.CollectUI = UI
local C = ns.Collect
function UI.DisenchantButton(parent, width)
    local K = ns.TradeKit
    local b = K.Button(parent, "", width, function(self)
        if InCombatLockdown() then return end
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", C.DisenchantMacro((C.NextDisenchant())))
    end, "control", "SecureActionButtonTemplate")
    K.Tooltip(b, ns.T("collectDisenchantTitle"), ns.T("collectDisenchantTip"))
    K.DisabledTip(b, ns.T("collectDisenchantTitle"), ns.T("collectDisenchantNone"))
    b:HookScript("OnShow", function() UI.RenderDisenchant(b) end)
    UI.buttons[#UI.buttons + 1] = b
    UI.RenderDisenchant(b)
    return b
end
function UI.Attach(parent, width, place)
    if InCombatLockdown() then
        UI.waiting = UI.waiting or {}
        UI.waiting[#UI.waiting + 1] = {parent = parent, width = width, place = place}
        return
    end
    place(UI.DisenchantButton(parent, width))
end
function UI.RenderDisenchant(b)
    local target, total = C.NextDisenchant()
    b:SetText(ns.T("collectDisenchant", total))
    if InCombatLockdown() then return end
    if target and ns.Compat.SpellKnown(13262) then b:Enable() else b:Disable() end
end
function UI.Shown()
    return ns.Store.DB().mailPanel ~= false
end
function UI.SetShown(on)
    local db = ns.Store.DB()
    if on then db.mailPanel = nil else db.mailPanel = false end
    UI.Apply()
    for _, check in ipairs(UI.checks) do check:SetChecked(on) end
    if not on then ns.say(ns.T("collectHidden")) end
end
function UI.Apply()
    local panel = UI.panel
    if not panel or InCombatLockdown() then return end
    if UI.Shown() then panel.frame:Show() else panel.frame:Hide() end
end
UI.checks = {}
function UI.ShownCheck(parent)
    local K = ns.TradeKit
    local check = K.Check(parent, function(checked) UI.SetShown(checked) end)
    check:SetChecked(UI.Shown())
    check.label = K.Label(parent, ns.T("collectShow"), 0, 0, 110, "secondary")
    check.label:ClearAllPoints(); check.label:SetPoint("RIGHT", check, "LEFT", -2, 0)
    check.label:SetJustifyH("RIGHT")
    K.Tooltip(check, ns.T("collectShow"), ns.T("collectShowTip"))
    UI.checks[#UI.checks + 1] = check
    return check
end
function UI:New(parent)
    local K = ns.TradeKit
    local view = setmetatable({}, self)
    local f = ns.NewFrame("Frame", nil, parent)
    f:SetWidth(316); f:SetHeight(30)
    f:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 18, 42)
    f:EnableMouse(true)
    K.Panel(f)
    view.frame = f
    view.take = K.Button(f, "", 136, function()
        if C.active then C.Stop() else C.Start() end
        view:Render()
    end, "control")
    view.take:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    K.Tooltip(view.take, ns.T("collectTakeTitle"), ns.T("collectTakeTip"))
    view.disenchant = UI.DisenchantButton(f, 136)
    view.disenchant:SetPoint("LEFT", view.take, "RIGHT", 4, 0)
    view.hide = K.IconButton(f, "hide", function() UI.SetShown(false) end, ns.T("collectHide"), ns.T("collectHideTip"))
    view.hide:SetPoint("LEFT", view.disenchant, "RIGHT", 6, 0)
    view.intake = K.Button(f, "", 136, function() ns.AccountingUI.Intake() end, "control")
    view.intake:SetPoint("TOPLEFT", view.take, "BOTTOMLEFT", 0, -4)
    K.Tooltip(view.intake, ns.T("acIntakeTitle"), ns.T("acIntakeMailTip"))
    view.status = K.Label(f, "", 8, -30, 300, "secondary")
    f:SetScript("OnShow", function() view:Render() end)
    return view
end
function UI:Render()
    local gifts, top = ns.AccountingEvents.GiftCount(), 30
    if gifts > 0 then
        self.intake:SetText(ns.T("acIntakeMail", gifts)); self.intake:Show(); top = 56
    else self.intake:Hide() end
    self.status:ClearAllPoints(); self.status:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 8, -top)
    local mail = C.active and #C.MailTargets(C.budget or {}) or C.MailCount()
    if C.active then
        self.take:SetText(ns.T("collectStop", C.taken)); self.take:Enable()
    else
        self.take:SetText(ns.T("collectTake", mail))
        if mail > 0 then self.take:Enable() else self.take:Disable() end
    end
    UI.RenderDisenchant(self.disenchant)
    local status = C.reason and ns.T(C.reason, C.taken) or ""
    self.status:SetText(status)
    self.frame:SetHeight(top + (status ~= "" and 16 or 0))
end
function UI.Refresh()
    local panel = UI.panel
    if panel and panel.frame:IsVisible() then panel:Render() end
    for _, b in ipairs(UI.buttons) do
        if b:IsVisible() and (not panel or b ~= panel.disenchant) then UI.RenderDisenchant(b) end
    end
end
C.onChange = UI.Refresh
local events = ns.NewFrame("Frame")
for _, event in ipairs({"MAIL_SHOW", "PLAYER_REGEN_ENABLED"}) do ns.Listen(events, event) end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and UI.waiting then
        local waiting = UI.waiting
        UI.waiting = nil
        for _, item in ipairs(waiting) do UI.Attach(item.parent, item.width, item.place) end
    end
    local mail = event == "MAIL_SHOW" or MailFrame and MailFrame:IsShown()
    if mail and not UI.panel and MailFrame and not InCombatLockdown() then
        UI.panel = UI:New(MailFrame)
    end
    UI.Apply()
    UI.Refresh()
end)
