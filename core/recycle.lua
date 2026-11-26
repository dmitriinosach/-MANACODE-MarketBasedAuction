local _, ns = ...
local R = {}
ns.Recycle = R
local function price(id)
    local q = ns.Markets.Quote(id)
    if q and q.price and (q.miss or 0) == 0 and q.complete ~= false then return q.price end
    return nil
end
function R.Pair(key)
    for _, pair in ipairs(ns.recyclePairs) do if pair.key == key then return pair end end
end
function R.Groups()
    local order, byGroup = {}, {}
    for _, pair in ipairs(ns.recyclePairs) do
        if not byGroup[pair.group] then
            byGroup[pair.group] = {group = pair.group, labelKey = ns.recycleGroups[pair.group], pairs = {}}
            order[#order + 1] = byGroup[pair.group]
        end
        table.insert(byGroup[pair.group].pairs, pair)
    end
    return order
end
function R.Evaluate(pair, fee)
    local small, big = price(pair.small), price(pair.big)
    local result = {smallPrice = small, bigPrice = big,
        haveSmall = GetItemCount and GetItemCount(pair.small, true) or 0,
        haveBig = GetItemCount and GetItemCount(pair.big, true) or 0}
    if big then result.asIs = big * (1 - fee) end
    if small and pair.both then result.split = pair.ratio * small * (1 - fee) end
    if small and big then result.assemble = big * (1 - fee) - pair.ratio * small end
    if result.asIs and result.split then
        result.best = result.split > result.asIs * 1.02 and "split" or "asIs"
    elseif result.asIs then result.best = "asIs"
    elseif result.split then result.best = "split" end
    if not result.asIs and not result.split then result.advice = "recycleAdviceNoPrice"
    elseif result.assemble and result.assemble > 0 and (not result.asIs or result.assemble > result.asIs * 0.1) then
        result.advice = "recycleAdviceAssemble"
    elseif result.best == "split" then result.advice = "recycleAdviceSplit"
    else result.advice = "recycleAdviceKeep" end
    return result
end
function R.HideKey(group)
    return "recycle:" .. group
end
function R.Targets(group)
    local ids = {}
    for _, pair in ipairs(ns.recyclePairs) do
        if group and pair.group == group or not group and not ns.Hidden.IsGroup(R.HideKey(pair.group)) then
            ids[#ids + 1] = pair.small; ids[#ids + 1] = pair.big
        end
    end
    return ids
end
function R.Complete(pair, mode)
    return ns.Batch.Complete({pair.small, pair.big}, mode, true)
end
function R.CompleteAll(mode)
    return ns.Batch.Complete(R.Targets(), mode, true)
end
function R.Stacks(id)
    local bySize, order, reference = {}, {}, nil
    for _, offer in ipairs(ns.Markets.Offers(id)) do
        if offer.price and offer.count > 0 and offer.owner ~= UnitName("player") then
            reference = math.min(reference or offer.price, offer.price)
            local stack = bySize[offer.count]
            if not stack then
                stack = {size = offer.count, unit = offer.price, lots = 0}
                bySize[offer.count] = stack
                order[#order + 1] = stack
            end
            stack.unit = math.min(stack.unit, offer.price)
            stack.lots = stack.lots + 1
        end
    end
    table.sort(order, function(a, b) return a.size < b.size end)
    local best
    for _, stack in ipairs(order) do
        if reference and reference > 0 then stack.premium = (stack.unit / reference - 1) * 100 end
        if stack.premium and stack.premium > 0 and (not best or stack.premium > best.premium) then best = stack end
    end
    return order, best, reference
end
