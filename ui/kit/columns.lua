local _, ns = ...
local K = ns.TradeKit
function K.MarketColumns(width)
    return {item = {0, width - 276}, price = {width - 276, 110},
        margin = {width - 166, 118}, units = {width - 48, 48}}
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
function K.DisenchantColumns(width, target, refresh)
    local action, level, price, margin, rate = refresh and 54 or 30, 40, 86, 92, 58
    local via, viaRate = target and 88 or 0, target and 70 or 0
    local rest = width - action - level - price - margin - rate - via - viaRate
    if target and rest < 200 then rest, viaRate = rest + viaRate, 0 end
    if target and rest < 200 then rest, via = rest + via, 0 end
    local columns, x = {item = {0, rest}}, rest
    for _, column in ipairs({{"ilvl", level}, {"price", price}, {"margin", margin}, {"rate", rate},
        {"via", via}, {"viaRate", viaRate}}) do
        if column[2] > 0 then columns[column[1]] = {x, column[2]}; x = x + column[2] end
    end
    columns.action = {x, action}
    return columns
end
function K.CraftColumns(width)
    local action = 80
    local price, margin, units = 86, 92, 48
    local state = width >= 820 and 72 or 0
    local best = width >= 960 and 180 or 0
    local item = width - action - price - margin - units - state - best
    local columns, x = {item = {0, item}}, item
    columns.price = {x, price}; x = x + price
    if best > 0 then columns.best = {x, best}; x = x + best end
    columns.margin = {x, margin}; x = x + margin
    columns.units = {x, units}; x = x + units
    if state > 0 then columns.state = {x, state}; x = x + state end
    columns.action = {x, action}
    return columns
end
function K.LedgerColumns(width, mode, actions)
    if mode == "sellway" then
        local columns = K.LedgerColumns(width, "sell", actions)
        local right = columns.value or columns.best
        columns.detail = {columns.count[1], right[1] - columns.count[1]}
        columns.count, columns.held, columns.market = nil, nil, nil
        return columns
    end
    local spec, drop, flex
    if mode == "materials" then
        spec = {{"item", 0}, {"stock", 64}, {"posted", 76}, {"unit", 84}, {"market", 84}, {"value", 92}, {"sold", 64}, {"net", 92}}
        drop, flex = {"sold", "posted", "net"}, "item"
    elseif mode == "forecast" then
        spec = {{"item", 0}, {"stock", 64}, {"count", 86}, {"units", 76}, {"market", 94}, {"net", 110}}
        drop, flex = {"market", "units"}, "item"
    elseif mode == "recipes" then
        spec = {{"item", 0}, {"count", 64}, {"cost", 96}, {"net", 110}, {"result", 100}, {"value", 100}}
        drop, flex = {"net", "value"}, "item"
    elseif mode == "journal" then
        spec = {{"item", 0}, {"event", 128}, {"amount", 88}, {"character", 108}, {"source", 92}, {"when", 92}}
        drop, flex = {"source", "when"}, "item"
    elseif mode == "sell" then
        spec = {{"item", 0}, {"count", 54}, {"held", 64}, {"market", 110}, {"value", 114}, {"best", 124}, {"mine", 110}}
        drop, flex = {"value", "held"}, "item"
    elseif mode == "owned" then
        spec = {{"item", 0}, {"stack", 48}, {"unit", 86}, {"buyout", 92}, {"left", 76}, {"standing", 160}}
        drop, flex = {"left", "buyout"}, "item"
    elseif mode == "analysis" then
        spec = {{"item", 0}, {"count", 50}, {"cost", 86}, {"units", 130}, {"expected", 92}, {"gross", 92},
            {"luck", 66}, {"result", 96}}
        drop, flex = {"expected", "units"}, "item"
    else
        spec = {{"item", math.max(170, math.min(250, math.floor(width * 0.24)))}, {"stage", 96}, {"cost", 80},
            {"output", 0}, {"market", 88}, {"net", 96}, {"result", 88}, {"when", 86}}
        drop, flex = {"when", "market"}, "output"
    end
    local action = actions and (mode == "journal" and 86 or (mode == "forecast" or mode == "recipes" or mode == "owned") and 70
        or mode == "sell" and 56 or 134) or 0
    local used, skip = action, {}
    for _, column in ipairs(spec) do used = used + column[2] end
    local minimum = flex == "item" and (mode == "sell" and 170 or 200) or 130
    for _, key in ipairs(drop) do
        if width - used >= minimum then break end
        for _, column in ipairs(spec) do if column[1] == key then used, skip[key] = used - column[2], true end end
    end
    local rest = math.max(flex == "item" and 120 or 96, width - used)
    local columns, x = {}, 0
    for _, column in ipairs(spec) do
        if not skip[column[1]] then
            local size = column[1] == flex and rest or column[2]
            columns[column[1]] = {x, size}; x = x + size
        end
    end
    columns.action = {x, action}
    return columns
end
function K.RecycleColumns(width)
    local action, bags, assemble, split, asIs = 30, 66, 96, 90, 90
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
K.ITEM_TAG = 86
