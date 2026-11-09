local _, ns = ...
local Perf = {SECONDS = 60, TOP = 5, active = false}
ns.Perf = Perf
Perf.TARGETS = {
    {"AccountingEvents", "Update", "AccountingEvents.Update"},
    {"AccountingEvents", "CheckMail", "AccountingEvents.CheckMail"},
    {"AccountingEvents", "Taking", "AccountingEvents.Taking"},
    {"AccountingEvents", "BuyerInvoices", "AccountingEvents.BuyerInvoices"},
    {"AccountingEvents", "Untracked", "AccountingEvents.Untracked"},
    {"AccountingEvents", "Settle", "AccountingEvents.Settle"},
    {"Accounting", "Project", "Accounting.Project"},
    {"Inventory", "OnEvent", "Inventory.OnEvent"},
    {"Collect", "Step", "Collect.Step"},
    {"Collect", "StepGold", "Collect.StepGold"},
    {"CollectUI", "Refresh", "CollectUI.Refresh"},
    {"Posting", "Changed", "Posting.Changed"},
    {"Posting", "Bags", "Posting.Bags"},
    {"Selling", "Track", "Selling.Track"},
    {"Selling", "BagRows", "Selling.BagRows"},
    {"Trader", "Refresh", "Trader.Refresh"},
    {"Trader", "Switch", "Trader.Switch"},
    {"Trader", "RenderStatus", "Trader.RenderStatus"},
    {"CraftPlan", "Build", "CraftPlan.Build"},
    {"CraftPlan", "Rank", "CraftPlan.Rank"},
    {"Markets", "Quote", "Markets.Quote"},
    {"Markets", "Remember", "Markets.Remember"},
    {"Markets", "Offers", "Markets.Offers"},
    {"Store", "Commit", "Store.Commit"},
    {"Shared", "Points", "Shared.Points"},
    {"Obtain", "Best", "Obtain.Best"},
    {"Obtain", "Alternatives", "Obtain.Alternatives"},
    {"Obtain", "Tree", "Obtain.Tree"},
}
Perf.VIEWS = {"ShoppingUI", "SellingUI", "DisenchantUI", "RecycleUI", "ProspectUI", "FamilyUI", "AlchemyUI", "ResaleUI",
    "Leveling2UI", "GatheringUI", "ReagentsUI", "CollectionsUI", "SeasonalUI", "NpcUI", "HiddenUI", "BargainUI", "BidsUI",
    "AccountingUI", "MarketBoardUI"}
local marks = {}
local wrapped = {}
local frame
local fps = {frames = 0, sum = 0, min = nil}
local memoryAt
local function clock()
    if debugprofilestop then return debugprofilestop() end
    return GetTime() * 1000
end
local function wrap(owner, key, label)
    local original = owner and rawget(owner, key)
    if type(original) ~= "function" then return end
    local mark = {label = label, ms = 0, calls = 0, max = 0}
    marks[label] = mark
    local function finish(t, ...)
        local spent = clock() - t
        mark.ms, mark.calls = mark.ms + spent, mark.calls + 1
        if spent > mark.max then mark.max = spent end
        return ...
    end
    local wrapper = function(...) return finish(clock(), original(...)) end
    owner[key] = wrapper
    wrapped[#wrapped + 1] = {owner = owner, key = key, original = original, wrapper = wrapper}
end
local function unwrap()
    for i = #wrapped, 1, -1 do
        local entry = wrapped[i]
        if entry.owner[entry.key] == entry.wrapper then entry.owner[entry.key] = entry.original end
        wrapped[i] = nil
    end
end
local function memory()
    if not UpdateAddOnMemoryUsage or not GetAddOnMemoryUsage then return nil end
    UpdateAddOnMemoryUsage()
    return GetAddOnMemoryUsage(ns.ADDON)
end
function Perf.Left()
    if not Perf.active then return 0 end
    return math.max(0, math.ceil(Perf.deadline - GetTime()))
end
local function tick(_, elapsed)
    fps.frames = fps.frames + 1
    local rate = GetFramerate and GetFramerate() or (elapsed > 0 and 1 / elapsed) or 0
    fps.sum = fps.sum + rate
    if not fps.min or rate < fps.min then fps.min = rate end
    local left = Perf.Left()
    if left ~= Perf.shownLeft then
        Perf.shownLeft = left
        local view = ns.SettingsUI and ns.SettingsUI.view
        if view and view.RenderPerf then view:RenderPerf() end
    end
    if GetTime() >= Perf.deadline then Perf.Stop() end
end
function Perf.Start(seconds)
    if Perf.active then return false end
    for key in pairs(marks) do marks[key] = nil end
    for _, target in ipairs(Perf.TARGETS) do wrap(ns[target[1]], target[2], target[3]) end
    for _, name in ipairs(Perf.VIEWS) do wrap(ns[name], "Render", name .. ":Render") end
    fps = {frames = 0, sum = 0, min = nil}
    memoryAt = memory()
    Perf.active, Perf.startedAt, Perf.deadline, Perf.shownLeft = true, GetTime(), GetTime() + (seconds or Perf.SECONDS), nil
    frame = frame or ns.NewFrame("Frame")
    frame:SetScript("OnUpdate", tick)
    return true
end
function Perf.Report()
    local seconds = math.max(1, math.floor((GetTime() - (Perf.startedAt or GetTime())) + 0.5))
    local lines = {}
    local average = fps.frames > 0 and fps.sum / fps.frames or 0
    lines[1] = ns.T("perfHeader", seconds, fps.frames, ns.Decimal(average, 0), ns.Decimal(fps.min or 0, 0))
    local order = {}
    for _, mark in pairs(marks) do if mark.calls > 0 then order[#order + 1] = mark end end
    table.sort(order, function(a, b)
        if a.ms ~= b.ms then return a.ms > b.ms end
        return a.label < b.label
    end)
    if #order == 0 then lines[#lines + 1] = ns.T("perfNothing") end
    for i = 1, math.min(Perf.TOP, #order) do
        local mark = order[i]
        lines[#lines + 1] = ns.T("perfLine", mark.label, ns.Decimal(mark.ms, 0), mark.calls, ns.Decimal(mark.max, 1))
    end
    local now = memory()
    if now then
        lines[#lines + 1] = ns.T("perfMemory", ns.Decimal(now / 1024, 1), ns.Decimal((now - (memoryAt or now)) / 1024, 1, true))
    end
    return lines
end
function Perf.Stop()
    if not Perf.active then return {} end
    if frame then frame:SetScript("OnUpdate", nil) end
    unwrap()
    Perf.active, Perf.deadline = false, nil
    local ok, lines = pcall(Perf.Report)
    if not ok then lines = {} end
    for _, line in ipairs(lines) do ns.chat(line) end
    local view = ns.SettingsUI and ns.SettingsUI.view
    if view and view.RenderPerf then view:RenderPerf() end
    return lines
end
function Perf.Toggle()
    if Perf.active then Perf.Stop() else Perf.Start() end
end
