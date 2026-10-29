local _, ns = ...
local S = {}
ns.Seasonal = S
function S.Event(key)
    for _, event in ipairs(ns.seasonalEvents or {}) do
        if event.key == key then return event end
    end
end
function S.Default(month)
    month = month or tonumber(date("%m")) or 1
    local best, bestGap, first
    for _, event in ipairs(ns.seasonalEvents or {}) do
        if #event.items > 0 then
            first = first or event.key
            if event.month then
                local gap = (event.month - month) % 12
                if not bestGap or gap < bestGap then best, bestGap = event.key, gap end
            end
        end
    end
    return best or first
end
local HOLIDAYS = "Interface\\Calendar\\Holidays\\"
local SEQUENCE = {START = "Start", ONGOING = "Ongoing", END = "End"}
local calendar
local YO, YE = string.char(209, 145), string.char(208, 181)
local YO_UP, YE_UP = string.char(208, 129), string.char(208, 149)
local function plain(text)
    return (text:gsub(YO, YE):gsub(YO_UP, YE_UP))
end
local function matches(event, title, texture)
    if texture and texture:lower():find(event.calendar, 1, true) then return true end
    return title ~= nil and plain(title):find(plain(ns.T(event.labelKey)), 1, true) == 1
end
local function scan(today, month, year)
    local savedMonth, savedYear = CalendarGetMonth(0)
    local found, runs = {}, {}
    local m, y = month - 1, year
    if m < 1 then m, y = 12, y - 1 end
    for _ = 1, 14 do
        CalendarSetAbsMonth(m, y)
        local _, _, days = CalendarGetMonth(0)
        for d = 1, days or 0 do
            local at = time({year = y, month = m, day = d, hour = 12})
            for i = 1, CalendarGetNumDayEvents(0, d) do
                local title, _, _, kind, sequence, _, texture = CalendarGetDayEvent(0, d, i)
                if kind == "HOLIDAY" then
                    for _, event in ipairs(ns.seasonalEvents) do
                        local key = event.key
                        if not found[key] and matches(event, title, texture) then
                            local run = runs[key]
                            if run and at - run.to > 129600 then
                                if run.to >= today then found[key] = run end
                                run = nil
                            end
                            if not found[key] then
                                run = run or {from = at}
                                run.to = at
                                if texture and (not run.texture or sequence == "START") then
                                    run.texture = HOLIDAYS .. texture .. (SEQUENCE[sequence] or "")
                                end
                                runs[key] = run
                            end
                        end
                    end
                end
            end
        end
        m = m + 1
        if m > 12 then m, y = 1, y + 1 end
    end
    for key, run in pairs(runs) do
        if not found[key] and run.to >= today then found[key] = run end
    end
    for _, run in pairs(found) do run.days = math.max(0, math.floor((run.from - today) / 86400 + 0.5)) end
    if savedMonth then CalendarSetAbsMonth(savedMonth, savedYear) end
    return found
end
function S.Dates(key)
    if not (CalendarGetDate and CalendarSetAbsMonth and CalendarGetDayEvent and CalendarGetMonth) then return nil end
    local _, month, day, year = CalendarGetDate()
    if not year then return nil end
    local stamp = string.format("%04d%02d%02d", year, month, day)
    if not calendar or calendar.day ~= stamp or (calendar.retry and time() >= calendar.retry) then
        local events = scan(time({year = year, month = month, day = day, hour = 12}), month, year)
        calendar = {day = stamp, events = events, retry = next(events) == nil and time() + 60 or nil}
    end
    return calendar.events[key]
end
function S.RequestCalendar()
    if OpenCalendar and not S.requested then S.requested = true; OpenCalendar() end
end
function S.Items(key)
    local result, event = {}, S.Event(key)
    for _, item in ipairs(event and event.items or {}) do
        result[#result + 1] = {raw = item.id, noteKey = item.noteKey, count = item.count, event = event, vendor = item.vendor}
    end
    return result
end
function S.Targets(key)
    local ids = {}
    for _, item in ipairs(S.Items(key)) do ids[#ids + 1] = item.raw end
    return ids
end
function S.Scan(key, mode)
    return ns.Batch.Complete(S.Targets(key), mode, true)
end
