local _, ns = ...
local Plan = {}
ns.Plan = Plan
local MAX_NEED = 1000
local EXTRA_GROUPS = 8
local function solve(offers, limit)
    local cost, lots, choice = { [0] = 0 }, { [0] = 0 }, {}
    for g, o in ipairs(offers) do
        local nc, nl, ch = {}, {}, {}
        for q = 0, limit do
            local base = cost[q]
            if base then
                local maxK = math.min(o.count, math.floor((limit - q) / o.stack))
                for k = 0, maxK do
                    local t = q + k * o.stack
                    local c, l = base + k * o.buyout, lots[q] + k
                    if not nc[t] or c < nc[t] or (c == nc[t] and l < nl[t]) then
                        nc[t], nl[t], ch[t] = c, l, k
                    end
                end
            end
        end
        cost, lots, choice[g] = nc, nl, ch
    end
    return cost, lots, choice
end
function Plan.Recount(plan)
    local units, cost, lots = 0, 0, 0
    for _, p in ipairs(plan.picks) do
        units = units + p.lots * p.offer.stack
        cost = cost + p.lots * p.offer.buyout
        lots = lots + p.lots
    end
    plan.units, plan.cost, plan.lots = units, cost, lots
    return plan
end
local function rebuild(offers, choice, target, kind, need)
    local picks = {}
    local t = target
    for g = #offers, 1, -1 do
        local k = choice[g][t] or 0
        if k > 0 then table.insert(picks, 1, { offer = offers[g], lots = k }) end
        t = t - k * offers[g].stack
    end
    return Plan.Recount({ kind = kind, need = need, picks = picks })
end
local function same(a, b)
    return a ~= nil and a.units == b.units and a.cost == b.cost
end
function Plan.Available(offers)
    local n = 0
    for _, o in ipairs(offers) do n = n + o.stack * o.count end
    return n
end
function Plan.Price(offers, limit, money)
    local sorted, plan = {}, {kind = "price", need = 0, picks = {}, priceLimit = limit}
    for _, offer in ipairs(offers) do
        if offer.stack > 0 and offer.buyout > 0 and offer.buyout < limit * offer.stack and offer.count > 0 then
            sorted[#sorted + 1] = offer
        end
    end
    table.sort(sorted, function(a, b)
        if a.buyout * b.stack ~= b.buyout * a.stack then return a.buyout * b.stack < b.buyout * a.stack end
        return a.buyout < b.buyout
    end)
    for _, offer in ipairs(sorted) do
        local count = math.min(offer.count, math.floor(money / offer.buyout))
        if count > 0 then
            plan.picks[#plan.picks + 1] = {offer = offer, lots = count}
            plan.need, money = plan.need + count * offer.stack, money - count * offer.buyout
        end
    end
    return Plan.Recount(plan)
end
function Plan.Prune(offers, need)
    local sorted = {}
    for i, o in ipairs(offers) do sorted[i] = o end
    table.sort(sorted, function(a, b) return a.buyout * b.stack < b.buyout * a.stack end)
    local out, units, extra = {}, 0, 0
    for _, o in ipairs(sorted) do
        if units >= need then
            extra = extra + 1
            if extra > EXTRA_GROUPS then break end
        end
        out[#out + 1] = o
        units = units + o.stack * o.count
    end
    return out
end
function Plan.Options(offers, need)
    need = math.min(math.floor(need or 0), MAX_NEED)
    if need <= 0 or Plan.Available(offers) < need then return {} end
    offers = Plan.Prune(offers, need)
    local maxStack = 1
    for _, o in ipairs(offers) do maxStack = math.max(maxStack, o.stack) end
    local limit = need + maxStack - 1
    local cost, lots, choice = solve(offers, limit)
    local cheapest, unitBest
    for q = need, limit do
        local c = cost[q]
        if c then
            if not cheapest or c <= cost[cheapest] then
                cheapest = q
            end
            if not unitBest or c * unitBest < cost[unitBest] * q then unitBest = q end
        end
    end
    local out = {}
    local best = rebuild(offers, choice, cheapest, "cheapest", need)
    out[1] = best
    if cost[need] and cheapest ~= need then
        out[#out + 1] = rebuild(offers, choice, need, "exact", need)
    end
    local unit = rebuild(offers, choice, unitBest, "unit", need)
    if not same(best, unit) and unit.cost * best.units < best.cost * unit.units then
        out[#out + 1] = unit
    end
    return out
end
function Plan.Copy(plan)
    local picks = {}
    for i, p in ipairs(plan.picks) do picks[i] = { offer = p.offer, lots = p.lots } end
    return Plan.Recount({ kind = plan.kind, need = plan.need, picks = picks, priceLimit = plan.priceLimit })
end
function Plan.Adjust(plan, offer, delta)
    local pick
    for _, p in ipairs(plan.picks) do
        if p.offer == offer then pick = p end
    end
    if not pick then
        pick = { offer = offer, lots = 0 }
        plan.picks[#plan.picks + 1] = pick
    end
    pick.lots = math.max(0, math.min(offer.count, pick.lots + delta))
    plan.kind = "manual"
    return Plan.Recount(plan)
end
function Plan.LotsOf(plan, offer)
    for _, p in ipairs(plan.picks) do
        if p.offer == offer then return p.lots end
    end
    return 0
end
