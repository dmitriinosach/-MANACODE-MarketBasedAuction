local _, ns = ...
local K = ns.TradeKit
K.MORE_ITEM = 280
function K.MoreColumns(columns)
    local item = columns.item
    local gone, have = 92, 56
    if item[2] - gone < K.MORE_ITEM then return columns end
    if item[2] - gone - have < K.MORE_ITEM then have = 0 end
    item[2] = item[2] - gone - have
    local x = item[1] + item[2]
    if have > 0 then columns.have = {x, have}; x = x + have end
    columns.gone = {x, gone}
    return columns
end
function K.MarketColumns(width, more)
    local columns = {item = {0, width - 276}, price = {width - 276, 110},
        margin = {width - 166, 118}, units = {width - 48, 48}}
    return more and K.MoreColumns(columns) or columns
end
function K.SellerColumns(width, currency)
    local columns = K.MarketColumns(width)
    local seller, cost, affordable = 174, currency and 76 or 120, currency and 68 or 0
    local item = columns.item[2]
    if item - cost < 200 then return columns, false end
    item = item - cost
    if affordable > 0 and item - affordable >= 200 then item = item - affordable
    else affordable = 0 end
    if item - seller >= 200 then item = item - seller else seller = 0 end
    columns.item = {0, item}
    if seller > 0 then columns.seller = {item, seller} end
    columns.cost = {item + seller, cost}
    if affordable > 0 then columns.affordable = {item + seller + cost, affordable} end
    return columns, seller > 0
end
function K.DisenchantColumns(width, target, refresh, bids)
    local action, level, price, margin, rate = refresh and 54 or 30, 40, 86, 92, 58
    local via, viaRate, bid = target and 88 or 0, target and 70 or 0, bids and 80 or 0
    local rest = width - action - level - price - margin - rate - via - viaRate - bid
    if target and rest < 200 then rest, viaRate = rest + viaRate, 0 end
    if target and rest < 200 then rest, via = rest + via, 0 end
    if bids and rest < 200 then rest, bid = rest + bid, 0 end
    local columns, x = {item = {0, rest}}, rest
    for _, column in ipairs({{"ilvl", level}, {"price", price}, {"bid", bid}, {"margin", margin}, {"rate", rate},
        {"via", via}, {"viaRate", viaRate}}) do
        if column[2] > 0 then columns[column[1]] = {x, column[2]}; x = x + column[2] end
    end
    columns.action = {x, action}
    return columns
end
function K.CraftColumns(width, more)
    local action = 80
    local price, margin, units = 86, 112, 48
    local item = width - action - price - margin - units
    local columns, x = {item = {0, item}}, item
    columns.price = {x, price}; x = x + price
    columns.margin = {x, margin}; x = x + margin
    columns.units = {x, units}; x = x + units
    columns.action = {x, action}
    return more and K.MoreColumns(columns) or columns
end
function K.LedgerColumns(width, mode, actions, base)
    if mode == "sellway" then
        local columns = {}
        for key, value in pairs(base or K.LedgerColumns(width, "sell", actions)) do columns[key] = {value[1], value[2]} end
        local right = columns.value or columns.best or columns.mine or columns.action
        columns.detail = {columns.count[1], right[1] - columns.count[1]}
        columns.count, columns.held, columns.market = nil, nil, nil
        return columns
    end
    local spec, drop
    local start, minimum = 0, 200
    if mode == "feed" or mode == "stock" then
        start, minimum = K.EXPAND + 8, mode == "feed" and 300 or 200
        spec = {{"lead", mode == "feed" and 80 or 50}, {"item", 0}, {"cost", 90}, {"value", 94}, {"result", 90}}
        drop = {"cost", "value"}
    elseif mode == "stats" then
        spec = {{"item", 0}, {"sample", 54}, {"cost", 86}, {"fact", 90}, {"result", 92}, {"model", 96}}
        drop = {"model"}
    elseif mode == "owned" then
        spec = {{"item", 0}, {"stack", 48}, {"unit", 86}, {"buyout", 92}, {"left", 76}, {"standing", 160}}
        drop = {"left", "buyout"}
    else
        minimum = 170
        spec = {{"item", 0}, {"count", 54}, {"held", 64}, {"market", 110}, {"value", 114}, {"best", 124}, {"mine", 110}}
        drop = {"value", "held"}
    end
    local action = actions and (mode == "owned" and 70 or 56) or 0
    local used, skip = action + start, {}
    for _, column in ipairs(spec) do used = used + column[2] end
    for _, key in ipairs(drop) do
        if width - used >= minimum then break end
        for _, column in ipairs(spec) do if column[1] == key then used, skip[key] = used - column[2], true end end
    end
    local rest = math.max(120, width - used)
    local columns, x = {}, start
    for _, column in ipairs(spec) do
        if not skip[column[1]] then
            local size = column[1] == "item" and rest or column[2]
            columns[column[1]] = {x, size}; x = x + size
        end
    end
    columns.action = {x, action}
    return columns
end
function K.RecycleColumns(width)
    local action, bags, assemble, split, asIs = K.ActionReserve({{icon = "refresh"}, {icon = "hide"}}), 66, 96, 90, 90
    local item = width - action - bags - assemble - split - asIs
    if item < 230 then item, bags = item + bags, 0 end
    local columns, x = {item = {0, item}}, item
    for _, column in ipairs({{"asIs", asIs}, {"split", split}, {"assemble", assemble}, {"bags", bags}}) do
        if column[2] > 0 then columns[column[1]] = {x, column[2]}; x = x + column[2] end
    end
    columns.action = {x, action}
    return columns
end
function K.BagColumns(width)
    local spec = {{"count", 56}, {"cost", 86}, {"market", 86}, {"value", 96}, {"posted", 80}}
    local used, skip = 0, {}
    for _, column in ipairs(spec) do used = used + column[2] end
    for _, key in ipairs({"posted", "cost"}) do
        if width - used >= 200 then break end
        for _, column in ipairs(spec) do if column[1] == key then used, skip[key] = used - column[2], true end end
    end
    local rest = math.max(120, width - used)
    local columns, x = {item = {0, rest}}, rest
    for _, column in ipairs(spec) do
        if not skip[column[1]] then columns[column[1]] = {x, column[2]}; x = x + column[2] end
    end
    return columns
end
function K.BargainColumns(width)
    local spec = {{"lots", 46}, {"price", 90}, {"market", 90}, {"discount", 58}, {"age", 76}}
    local drop = {"age", "lots", "market"}
    local action = 82
    local used, skip = action, {}
    for _, column in ipairs(spec) do used = used + column[2] end
    for _, key in ipairs(drop) do
        if width - used >= 200 then break end
        for _, column in ipairs(spec) do if column[1] == key then used, skip[key] = used - column[2], true end end
    end
    local rest = math.max(120, width - used)
    local columns, x = {item = {0, rest}}, rest
    for _, column in ipairs(spec) do
        if not skip[column[1]] then columns[column[1]] = {x, column[2]}; x = x + column[2] end
    end
    columns.action = {x, action}
    return columns
end
function K.BidColumns(width, mode)
    local spec = mode == "mine" and {{"bid", 90}, {"next", 90}, {"buyout", 90}, {"state", 84}, {"ends", 76}}
        or {{"cost", 90}, {"buyout", 90}, {"value", 90}, {"profit", 90}, {"ends", 100}}
    local drop = {"buyout", "ends"}
    local action = 82
    local used, skip = action, {}
    for _, column in ipairs(spec) do used = used + column[2] end
    for _, key in ipairs(drop) do
        if width - used >= 200 then break end
        for _, column in ipairs(spec) do if column[1] == key then used, skip[key] = used - column[2], true end end
    end
    local rest = math.max(120, width - used)
    local columns, x = {item = {0, rest}}, rest
    for _, column in ipairs(spec) do
        if not skip[column[1]] then columns[column[1]] = {x, column[2]}; x = x + column[2] end
    end
    columns.action = {x, action}
    return columns
end
K.ITEM_TAG = 86
function K.ShoppingLotColumns(width)
    local price = math.min(110, math.max(70, math.floor((width - 34 - 30 - 8 - 120) / 2)))
    local lot = {width - 34 - price, price}
    local unit = {30, price}
    return {unit = unit, stacks = {unit[1] + unit[2] + 4, lot[1] - 4 - (unit[1] + unit[2] + 4)}, lot = lot}
end
