local _, ns = ...
local K = ns.TradeKit
local GAP, TEXT_GAP, ICON = 6, 2, 14
local function chipEnter(chip)
    local line = chip.line
    if not line then return end
    GameTooltip:SetOwner(chip, "ANCHOR_RIGHT")
    if line.item then GameTooltip:SetHyperlink("item:" .. line.item)
    else GameTooltip:AddLine(line.name or "", unpack(K.theme.text)) end
    local have = line.have and tostring(line.have) or ns.T("costUnknown")
    if line.owned then
        GameTooltip:AddLine(ns.T("costOwned", have), unpack(K.theme.secondary))
    else
        local color = line.have == nil and K.theme.secondary or (line.have < line.need and K.theme.negative or K.theme.positive)
        GameTooltip:AddLine(ns.T("costHave", have, line.need), unpack(color))
    end
    if (line.alts or 0) > 0 then GameTooltip:AddLine(ns.T("costAlts", line.alts), unpack(K.theme.secondary)) end
    GameTooltip:Show()
end
local function chipClick(chip, button)
    local host = chip.host
    if host and host.onClick then host.onClick(host, button) end
end
function K.CurrencyChip(parent, host)
    local chip = ns.NewFrame("Button", nil, parent)
    chip.host = host
    chip:SetHeight(20)
    chip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    chip:SetScript("OnEnter", chipEnter)
    chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    chip:SetScript("OnClick", chipClick)
    chip.icon = chip:CreateTexture(nil, "ARTWORK")
    chip.icon:SetWidth(ICON); chip.icon:SetHeight(ICON)
    chip.icon:SetPoint("RIGHT", chip, "RIGHT", 0, 0)
    chip.text = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chip.text:SetPoint("RIGHT", chip.icon, "LEFT", -TEXT_GAP, 0)
    return chip
end
function K.SetCurrencyChip(chip, line)
    chip.line = line
    chip.icon:SetTexture(line.tex)
    local label, short
    if line.owned then
        label = line.have and tostring(line.have) or ns.T("costUnknownShort")
    else
        label, short = line.need > 1 and tostring(line.need) or "", line.have and line.have < line.need
    end
    chip.text:SetText(label)
    chip.text:SetTextColor(unpack(short and K.theme.negative or (line.owned and not line.have) and K.theme.secondary or K.theme.text))
    local width = ICON
    if label ~= "" then width = width + TEXT_GAP + math.ceil(chip.text:GetStringWidth() or 0) end
    chip:SetWidth(width)
    chip:Show()
    return width
end
function K.Cost(parent, host)
    local cost = ns.NewFrame("Frame", nil, parent)
    cost.host = host
    cost:SetHeight(20)
    cost.chips = {}
    cost.gold = cost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cost.gold:SetJustifyH("RIGHT")
    return cost
end
function K.SetCost(cost, lines, money)
    local width, anchor, edge = 0, cost, "RIGHT"
    for i = #lines, 1, -1 do
        local used = #lines - i + 1
        local chip = cost.chips[used]
        if not chip then
            chip = K.CurrencyChip(cost, cost.host)
            cost.chips[used] = chip
        end
        local size = K.SetCurrencyChip(chip, lines[i])
        chip:ClearAllPoints()
        chip:SetPoint("RIGHT", anchor, edge, width > 0 and -GAP or 0, 0)
        anchor, edge = chip, "LEFT"
        width = width + size + (width > 0 and GAP or 0)
    end
    for i = #lines + 1, #cost.chips do cost.chips[i]:Hide() end
    if money and money > 0 then
        cost.gold:SetText(K.Money(money))
        cost.gold:SetTextColor(unpack(money > GetMoney() and K.theme.negative or K.theme.text))
        cost.gold:ClearAllPoints()
        cost.gold:SetPoint("RIGHT", anchor, edge, width > 0 and -GAP or 0, 0)
        cost.gold:Show()
        width = width + math.ceil(cost.gold:GetStringWidth() or 0) + (width > 0 and GAP or 0)
    else cost.gold:Hide() end
    cost:SetWidth(math.max(width, 1))
    cost:Show()
    return width
end
