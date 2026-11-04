local _, ns = ...
local D = ns.Disenchant
function D.Spread(result, fee, cost)
    local low, high
    for pass = 1, 2 do
        for _, output in ipairs(result.outputs) do
            if output.price and (pass == 2 or output.chance >= D.RARE) then
                local least, most = output.minCount * output.price, output.maxCount * output.price
                low = low and math.min(low, least) or least
                high = high and math.max(high, most) or most
            end
        end
        if low then break end
    end
    if not low then return end
    result.low = low * (1 - fee) - result.reserve - cost
    result.high = high * (1 - fee) - result.reserve - cost
    if cost > 0 then result.lowPercent, result.highPercent = result.low / cost * 100, result.high / cost * 100 end
end
function D.Deposit(itemID, amount, fee, selling)
    local _, _, _, _, _, _, _, stack, _, _, vendor = ns.Compat.ItemInfo(itemID)
    local rate = fee == 0.15 and 0.75 or 0.15
    local value = selling.base and selling.base * amount * (selling.hours or 12) / 12
        or (vendor and math.max(100, math.floor(vendor * amount * rate * (selling.hours or 12) / 12)))
    if not value or not stack or stack < amount then return nil end
    return value
end
local function outcome(band, fee, fixedPrices, selling)
    local result = {outputs = {}, gross = 0, fresh = true, deposit = 0, byCost = {}}
    for _, output in ipairs(band.outputs) do
        local quote = fixedPrices and fixedPrices[output.itemID] or D.Quote(output.itemID)
        local quantity = output.chance * (output.minCount + output.maxCount) / 2
        local price = quote and quote.miss == 0 and quote.complete ~= false and quote.price
        result.outputs[#result.outputs + 1] = {id = output.itemID, quantity = quantity, price = price,
            chance = output.chance, minCount = output.minCount, maxCount = output.maxCount}
        if selling then
            local deposit = 0
            for amount = output.minCount, output.maxCount do
                local value = D.Deposit(output.itemID, amount, fee, selling)
                if not value then deposit = nil; break end
                deposit = deposit + value
            end
            if result.deposit and deposit then
                result.deposit = result.deposit + output.chance * deposit / (output.maxCount - output.minCount + 1)
            else result.deposit = nil end
        end
        result.fresh = result.fresh and D.Fresh(output.itemID)
        if price and result.gross then result.gross = result.gross + quantity * price else result.gross = nil end
    end
    if result.gross then
        result.reserve = selling and result.deposit and result.deposit * (selling.losses or 0) or 0
        if not (selling and not result.deposit and (selling.losses or 0) > 0) then
            result.net = result.gross * (1 - fee) - result.reserve
        end
    end
    return result
end
function D.Estimate(band, cost, fee, fixedPrices, selling, memo)
    local base = memo and memo[band]
    if not base then
        base = outcome(band, fee, fixedPrices, selling)
        if memo then memo[band] = base end
    end
    if base.byCost[cost] then return base.byCost[cost] end
    local result = {cost = cost, outputs = base.outputs, gross = base.gross, fresh = base.fresh,
        deposit = base.deposit, reserve = base.reserve}
    if base.net then
        result.net = base.net
        result.margin = result.net - cost
        D.Spread(result, fee, cost)
        result.percent = cost > 0 and result.margin / cost * 100 or nil
    end
    if memo then base.byCost[cost] = result end
    return result
end
