local _, ns = ...
local C = {active = false, taken = 0}
ns.Collect = C
local WAIT = 10
local ATTACHMENTS = 12
local STOPS = {"ERR_INV_FULL", "ERR_ITEM_MAX_COUNT", "ERR_MAIL_DATABASE_ERROR"}
function C.Budget()
    local budget = {}
    for _, chain in ipairs(ns.AccountingEvents.Projection().chains) do
        if chain.stage == "sent" or chain.stage == "unsure" or chain.stage == "mail" then
            local key = chain.itemID .. ":" .. chain.suffix
            budget[key] = (budget[key] or 0) + chain.count - chain.received
        end
    end
    return budget
end
function C.MailTargets(budget)
    local out = {}
    if not GetInboxNumItems or not GetInboxHeaderInfo or not GetInboxItemLink or not GetInboxInvoiceInfo then return out end
    local left = {}
    for key, count in pairs(budget) do left[key] = count end
    for index = 1, GetInboxNumItems() or 0 do
        local _, _, _, _, _, cod, _, items = GetInboxHeaderInfo(index)
        if (items or 0) > 0 and (cod or 0) == 0 and GetInboxInvoiceInfo(index) == "buyer" then
            for attach = 1, ATTACHMENTS do
                local link = GetInboxItemLink(index, attach)
                local itemID, suffix = ns.Lot.FromLink(link)
                local key = itemID and itemID .. ":" .. suffix
                if key and (left[key] or 0) > 0 then
                    local count = GetInboxItem and select(3, GetInboxItem(index, attach)) or 1
                    left[key] = left[key] - (count or 1)
                    out[#out + 1] = {index = index, attach = attach, link = link, itemID = itemID, suffix = suffix,
                        count = count or 1, key = key}
                end
            end
        end
    end
    return out
end
function C.MailCount()
    if not ns.AccountingEvents.mailOpen then return 0 end
    return #C.MailTargets(C.Budget())
end
function C.Finish(reason)
    C.active, C.pending, C.budget, C.dirty = false, nil, nil, false
    C.reason = reason
    if C.onChange then C.onChange() end
end
function C.Start()
    if C.active then return false, "collectBusy" end
    if not ns.AccountingEvents.mailOpen or not TakeInboxItem then return false, "collectNoMail" end
    C.active, C.taken, C.reason, C.pending = true, 0, nil, nil
    C.budget = C.Budget()
    C.Step()
    return C.active or C.taken > 0, C.reason
end
function C.Stop()
    if C.active then C.Finish("collectStopped") end
end
function C.Step()
    if not C.active then return end
    local pending = C.pending
    if pending then
        local now = ns.AccountingEvents.BagCount(pending.itemID, pending.suffix)
        if not (now and pending.bag and now > pending.bag) then
            if GetTime() - pending.at > WAIT then C.Finish("collectTimeout") end
            return
        end
        C.budget[pending.key] = (C.budget[pending.key] or 0) - pending.count
        C.taken, C.pending = C.taken + 1, nil
        if C.onChange then C.onChange() end
    end
    local target = C.MailTargets(C.budget)[1]
    if not target then C.Finish(C.taken > 0 and "collectDone" or "collectNothing"); return end
    target.bag, target.at = ns.AccountingEvents.BagCount(target.itemID, target.suffix), GetTime()
    if not target.bag then C.Finish("collectTimeout"); return end
    C.pending = target
    local wasRead = select(9, GetInboxHeaderInfo(target.index))
    if not wasRead and GetInboxText then GetInboxText(target.index) end
    TakeInboxItem(target.index, target.attach)
end
local stops
function C.Error(text)
    if not C.active or not text then return end
    if not stops then
        stops = {}
        for _, key in ipairs(STOPS) do if type(_G[key]) == "string" then stops[_G[key]] = true end end
    end
    if stops[text] then C.Finish("collectRefused") end
end
function C.InBag()
    local keys = {}
    for _, chain in ipairs(ns.AccountingEvents.Projection().chains) do
        if chain.stage == "bag" and chain.plan == "disenchant" then
            local key = chain.itemID .. ":" .. chain.suffix
            keys[key] = (keys[key] or 0) + chain.received - chain.processed
        end
    end
    return keys
end
function C.NextDisenchant()
    if not GetContainerItemLink then return nil, 0 end
    local left, first, total = C.InBag(), nil, 0
    for bag = 0, 4 do
        for slot = 1, ns.Compat.BagSlots(bag) or 0 do
            local link = GetContainerItemLink(bag, slot)
            local itemID, suffix = ns.Lot.FromLink(link)
            local key = itemID and itemID .. ":" .. suffix
            if key and (left[key] or 0) > 0 then
                local _, count, locked = ns.Compat.BagItemIcon(bag, slot)
                left[key] = left[key] - (count or 1)
                total = total + (count or 1)
                if not first and not locked then first = {bag = bag, slot = slot, link = link, itemID = itemID} end
            end
        end
    end
    return first, total
end
function C.DisenchantMacro(target)
    local spell = ns.Compat.SpellIcon(13262)
    if not target or not spell then return nil end
    return "/cast " .. spell .. "\n/use " .. target.bag .. " " .. target.slot
end
local frame = ns.NewFrame("Frame")
for _, event in ipairs({"MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "BAG_UPDATE", "UI_ERROR_MESSAGE"}) do
    ns.Listen(frame, event)
end
frame:SetScript("OnEvent", function(_, event, first)
    if event == "MAIL_CLOSED" then
        if C.active then C.Finish("collectNoMail") else C.reason = nil end
    elseif event == "UI_ERROR_MESSAGE" then C.Error(first)
    else
        C.dirty = true
        if event == "MAIL_SHOW" then C.reason = nil end
    end
end)
frame:SetScript("OnUpdate", function()
    if not C.dirty then
        if C.active and C.pending and GetTime() - C.pending.at > WAIT then C.Step() end
        return
    end
    C.dirty = false
    if C.active then C.Step() end
    if C.onChange then C.onChange() end
end)
