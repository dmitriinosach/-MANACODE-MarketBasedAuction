local _, ns = ...
local Filters = {}
Filters.__index = Filters
ns.TradeKit.AuctionFilters = Filters
local CLASS = 128
local QUALITY = 112
local LEVEL = 30
local CAPTION = 46
Filters.WIDTH = CLASS + 6 + CLASS + 6 + QUALITY + 8 + CAPTION + 4 + LEVEL + 14 + LEVEL
function Filters:Change(key, value)
    local filter = {}
    for name, old in pairs(self.props.filters) do filter[name] = old end
    filter[key] = value
    if key == "classIndex" then filter.subClassIndex = nil end
    self.props.changed(filter)
end
function Filters:Values()
    local out = {}
    for key, value in pairs(self.props.filters) do out[key] = value end
    local low, high = self.min:GetText(), self.max:GetText()
    local min, max = tonumber(low), tonumber(high)
    if low ~= "" and (not min or min < 1 or min > 80 or min ~= math.floor(min))
        or high ~= "" and (not max or max < 1 or max > 80 or max ~= math.floor(max))
        or min and max and min > max then ns.say(ns.T("searchBadLevel"), "bad"); return nil end
    out.minLevel, out.maxLevel = min, max
    return out
end
function Filters:New(parent, changed)
    local K = ns.TradeKit
    local view = setmetatable({props = {filters = {}, changed = changed}}, self)
    view.frame = ns.NewFrame("Frame", nil, parent)
    view.frame:SetWidth(Filters.WIDTH); view.frame:SetHeight(22)
    view.class = K.Menu(parent, {}, function(index) view:Change("classIndex", index > 0 and index or nil) end)
    view.class.frame:SetPoint("LEFT", view.frame, "LEFT", 0, 0); view.class.frame:SetWidth(CLASS)
    K.Tooltip(view.class.frame, ns.T("searchCategory"), ns.T("searchCategoryTip"))
    view.subclass = K.Menu(parent, {}, function(index) view:Change("subClassIndex", index > 0 and index or nil) end)
    view.subclass.frame:SetPoint("LEFT", view.class.frame, "RIGHT", 6, 0); view.subclass.frame:SetWidth(CLASS)
    K.Tooltip(view.subclass.frame, ns.T("searchSubcategory"), ns.T("searchSubcategoryTip"))
    local qualities = {{key = -1, labelKey = "searchAnyQuality"}}
    for quality = 0, 5 do
        local name = _G["ITEM_QUALITY" .. quality .. "_DESC"]
        if name then qualities[#qualities + 1] = {key = quality, label = name, quality = quality} end
    end
    view.quality = K.Menu(parent, qualities, function(value) view:Change("minQuality", value >= 0 and value or nil) end)
    view.quality.frame:SetPoint("LEFT", view.subclass.frame, "RIGHT", 6, 0); view.quality.frame:SetWidth(QUALITY)
    K.Tooltip(view.quality.frame, ns.T("searchQualityTitle"), ns.T("searchQualityTip"))
    view.level = K.Label(parent, ns.T("searchLevel"), 0, 0, CAPTION, "secondary")
    view.level:SetHeight(12); view.level:ClearAllPoints()
    view.level:SetPoint("LEFT", view.quality.frame, "RIGHT", 8, 0)
    view.min, view.max = K.Edit(parent, LEVEL, nil, "1"), K.Edit(parent, LEVEL, nil, "80")
    view.min:SetPoint("LEFT", view.level, "RIGHT", 4, 0)
    local dash = K.Label(parent, ns.T("searchLevelTo"), 0, 0, 14, "secondary")
    dash:SetHeight(12); dash:SetJustifyH("CENTER"); dash:ClearAllPoints()
    dash:SetPoint("LEFT", view.min, "RIGHT", 0, 0)
    view.max:SetPoint("LEFT", dash, "RIGHT", 0, 0)
    for _, edit in ipairs({view.min, view.max}) do
        edit:SetNumeric(true); edit:SetMaxLetters(2)
        K.Tooltip(edit, ns.T("searchLevel"), ns.T("searchLevelTip"))
        edit:SetScript("OnEnterPressed", function()
            local values = view:Values()
            if not values then return end
            view.min:ClearFocus(); view.max:ClearFocus()
            view.props.changed(values)
            if view.search then view.search() end
        end)
        edit:SetScript("OnEditFocusLost", function()
            local values = view:Values()
            if values then view.props.changed(values) end
        end)
    end
    return view
end
function Filters:SetProps(props)
    self.props = props
    self:Render()
end
function Filters:Render()
    local K, f = ns.TradeKit, self.props.filters
    local quality = f.minQuality and _G["ITEM_QUALITY" .. f.minQuality .. "_DESC"]
    self.quality.frame:SetText(quality and ns.T("searchQuality", quality) or ns.T("searchAnyQuality"))
    if f.minQuality then self.quality.frame.text:SetTextColor(K.QualityColor(f.minQuality))
    else self.quality.frame.text:SetTextColor(unpack(K.theme.text)) end
    local classes, subs = {{key = 0, labelKey = "searchAnyCategory"}}, {{key = 0, labelKey = "searchAnySubcategory"}}
    local className, subName = ns.T("searchAnyCategory"), ns.T("searchAnySubcategory")
    for _, entry in ipairs(ns.Search.Categories()) do
        classes[#classes + 1] = {key = entry.classIndex, label = entry.name}
        if entry.classIndex == f.classIndex then className = entry.name end
    end
    if f.classIndex then
        for _, entry in ipairs(ns.Search.Categories(f.classIndex)) do
            subs[#subs + 1] = {key = entry.subClassIndex, label = entry.name}
            if entry.subClassIndex == f.subClassIndex then subName = entry.name end
        end
    end
    self.class:SetEntries(classes); self.subclass:SetEntries(subs)
    self.class.frame:SetText(className); self.subclass.frame:SetText(subName)
    if not self.min:HasFocus() then self.min:SetText(f.minLevel and tostring(f.minLevel) or "") end
    if not self.max:HasFocus() then self.max:SetText(f.maxLevel and tostring(f.maxLevel) or "") end
    local off = self.props.disabled
    for _, menu in ipairs({self.class, self.quality}) do
        if off then menu.frame:Disable(); menu.cover:Hide() else menu.frame:Enable() end
    end
    if off or not f.classIndex then self.subclass.frame:Disable(); self.subclass.cover:Hide() else self.subclass.frame:Enable() end
    K.DisabledTip(self.subclass.frame, ns.T("searchSubcategory"), ns.T(f.classIndex and "batchBusy" or "searchSubcategoryOff"))
    for _, edit in ipairs({self.min, self.max}) do
        edit:EnableMouse(not off)
        if off then edit:ClearFocus() end
    end
end
