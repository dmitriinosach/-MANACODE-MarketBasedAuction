local _, ns = ...
local P = {hosts = {}, names = {}}
ns.MapPin = P
local HEAD, FOOT = 40, 12
P.zones = {
    [14] = "Durotar", [215] = "Mulgore", [17] = "Barrens", [141] = "Teldrassil", [148] = "Darkshore",
    [331] = "Ashenvale", [400] = "ThousandNeedles", [406] = "StonetalonMountains", [405] = "Desolace",
    [357] = "Feralas", [15] = "Dustwallow", [440] = "Tanaris", [16] = "Aszhara", [361] = "Felwood",
    [490] = "UngoroCrater", [493] = "Moonglade", [1377] = "Silithus", [618] = "Winterspring",
    [1637] = "Ogrimmar", [1638] = "ThunderBluff", [1657] = "Darnassis", [3524] = "AzuremystIsle",
    [3557] = "TheExodar", [3525] = "BloodmystIsle",
    [36] = "Alterac", [45] = "Arathi", [3] = "Badlands", [4] = "BlastedLands", [85] = "Tirisfal",
    [130] = "Silverpine", [28] = "WesternPlaguelands", [139] = "EasternPlaguelands", [267] = "Hilsbrad",
    [47] = "Hinterlands", [1] = "DunMorogh", [51] = "SearingGorge", [46] = "BurningSteppes", [12] = "Elwynn",
    [41] = "DeadwindPass", [10] = "Duskwood", [38] = "LochModan", [44] = "Redridge", [33] = "Stranglethorn",
    [8] = "SwampOfSorrows", [40] = "Westfall", [11] = "Wetlands", [1519] = "Stormwind", [1537] = "Ironforge",
    [1497] = "Undercity", [3430] = "EversongWoods", [3433] = "Ghostlands", [3487] = "SilvermoonCity",
    [4080] = "Sunwell",
    [3483] = "Hellfire", [3521] = "Zangarmarsh", [3520] = "ShadowmoonValley", [3522] = "BladesEdgeMountains",
    [3518] = "Nagrand", [3519] = "TerokkarForest", [3523] = "Netherstorm", [3703] = "ShattrathCity",
    [3537] = "BoreanTundra", [65] = "Dragonblight", [394] = "GrizzlyHills", [495] = "HowlingFjord",
    [210] = "IcecrownGlacier", [3711] = "SholazarBasin", [67] = "TheStormPeaks", [66] = "ZulDrak",
    [4197] = "LakeWintergrasp", [4395] = "Dalaran", [2817] = "CrystalsongForest", [4742] = "HrothgarsLanding",
}
P.floors = {Dalaran = 2}
function P.Known(zone)
    return P.zones[zone] ~= nil
end
local function zoneName(zone)
    local name = ns.T("npcZone" .. zone)
    return name:sub(1, 1) == "[" and "" or name
end
local function floorName(file, level)
    return ns.T("mapFloor" .. file .. level)
end
function P.Build(host)
    local K = ns.TradeKit
    local modal = K.Modal(host, "ManaCodeZoneMap" .. (#P.names + 1))
    P.names[#P.names + 1] = modal
    local window = modal.window
    modal.heading = K.Label(window, "", 12, -12, 320, "title")
    modal.caption = K.Label(window, "", 0, 0, 360, "secondary")
    modal.caption:ClearAllPoints(); modal.caption:SetPoint("LEFT", modal.heading, "RIGHT", 10, 0)
    modal.floors = K.Segment(window, {{key = 1, label = floorName("Dalaran", 1)}, {key = 2, label = floorName("Dalaran", 2)}},
        function(level) P.View(level) end)
    modal.floors.frame:SetPoint("TOPRIGHT", window, "TOPRIGHT", -34, -9)
    modal.map = K.ZoneMap:New(window)
    modal.map.frame:SetPoint("TOP", window, "TOP", 0, -HEAD)
    local layout = modal.Layout
    modal.Layout = function(self)
        layout(self)
        local width = K.ZoneMap.Fit((window:GetWidth() or 600) - 24, (window:GetHeight() or 380) - HEAD - FOOT)
        window:SetWidth(width + 24)
        window:SetHeight(math.floor(width * 668 / 1002) + HEAD + FOOT)
        self.map:SetProps({width = width})
    end
    modal:HookScript("OnHide", function(self) if P.modal == self then P.shown = nil end end)
    P.hosts[host] = modal
    return modal
end
local function host()
    local trader = ns.Trader and ns.Trader.frame
    if trader and trader:IsVisible() then return trader end
    return UIParent
end
function P.Show(args)
    local file = P.zones[args.zone]
    local owner = host()
    if not file or not owner then return false end
    local floors = P.floors[file]
    local level = floors and math.max(1, math.min(floors, args.level or 1)) or nil
    local modal = P.hosts[owner] or P.Build(owner)
    P.modal = modal
    P.shown = {title = args.title or "", zone = args.zone, file = file, level = level, view = level, points = args.points or {}}
    modal:Show()
    modal:Layout()
    P.Render()
    return true
end
function P.View(level)
    if not P.shown then return end
    P.shown.view = level
    P.Render()
end
function P.Render()
    local shown, modal = P.shown, P.modal
    if not shown or not modal then return end
    local here = shown.view == shown.level
    modal.heading:SetText(zoneName(shown.zone))
    modal.heading:SetWidth(math.min(320, (modal.heading:GetStringWidth() or 200) + 4))
    local caption = shown.title
    if #shown.points == 0 then caption = ns.T("mapPinNone", shown.title)
    elseif not here then caption = ns.T("mapPinOtherFloor", floorName(shown.file, shown.level)) end
    modal.caption:SetText(caption)
    if shown.level then modal.floors.frame:Show(); modal.floors:Select(shown.view) else modal.floors.frame:Hide() end
    modal.map:SetProps({file = shown.file, level = shown.view or 0, title = shown.title, points = here and shown.points or {}})
end
function P.Clear()
    P.shown = nil
    if P.modal then P.modal:Hide() end
end
