local ADDON, ns = ...
local K = ns.TradeKit
local A = {}
ns.About = A
local PAD, GAP = 14, 8
local LINKS = {{"site", "setSite"}, {"discord", "aboutDiscord"}, {"release", "setDownload"}, {"curseforge", "aboutMirror"}}
local function selectAddress(url)
    local field = A.window.address
    field:SetUrl(url)
    field:SetFocus()
    field:HighlightText()
end
local function placeBody(frame, width)
    local y = PAD
    local contentWidth = width - 2 * PAD
    local labels = {frame.purpose, frame.data}
    if #frame.tiles > 0 then labels[#labels + 1] = frame.others end
    for _, label in ipairs(labels) do
        label:SetPoint("TOPLEFT", frame.scroll.child, "TOPLEFT", PAD, -y)
        label:SetWidth(contentWidth)
        y = y + math.ceil(label:GetStringHeight() or K.FontHeight(12)) + GAP
    end
    local tileWidth = math.floor((contentWidth - GAP) / 2)
    local nameHeight, descHeight = K.FontHeight(14), K.FontHeight(12, 2)
    local tileHeight = 7 + nameHeight + 3 + descHeight + 7
    for i, tile in ipairs(frame.tiles) do
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", frame.scroll.child, "TOPLEFT",
            PAD + ((i - 1) % 2) * (tileWidth + GAP), -y - math.floor((i - 1) / 2) * (tileHeight + GAP))
        tile:SetWidth(tileWidth); tile:SetHeight(tileHeight)
        local stateWidth = math.ceil(tile.state:GetStringWidth() or 80) + 2
        tile.state:SetWidth(stateWidth)
        tile.state:ClearAllPoints(); tile.state:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -10, -7)
        tile.text:ClearAllPoints()
        tile.text:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -7)
        tile.text:SetWidth(math.max(40, tileWidth - 20 - stateWidth - 6))
        tile.desc:ClearAllPoints(); tile.desc:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -7 - nameHeight - 3)
        tile.desc:SetWidth(tileWidth - 20); tile.desc:SetHeight(descHeight)
    end
    y = y + math.ceil(#frame.tiles / 2) * (tileHeight + GAP)
    frame.authors:SetPoint("TOPLEFT", frame.scroll.child, "TOPLEFT", PAD, -y)
    frame.authors:SetWidth(contentWidth)
    return y + math.ceil(frame.authors:GetStringHeight() or K.FontHeight(12)) + PAD
end
local function layout(frame)
    local parent = frame:GetParent()
    local width = math.min(640, (parent:GetWidth() or 832) - 28)
    local maxHeight = (parent:GetHeight() or 447) - 20
    local linkHeight = K.FontHeight(22)
    local top = 39 + 2 * (linkHeight + 6)
    frame:SetWidth(width)
    frame.heading:SetWidth(width - 104)
    local prev
    for _, link in ipairs(frame.links) do
        K.FitButton(link, 20)
        link:SetHeight(linkHeight)
        link:ClearAllPoints()
        if prev then link:SetPoint("LEFT", prev, "RIGHT", GAP, 0)
        else link:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -39) end
        prev = link
    end
    frame.address:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -39 - linkHeight - 6)
    frame.address:SetWidth(width - 2 * PAD)
    frame.address:SetHeight(linkHeight)
    local scroll = frame.scroll
    scroll.top, scroll.inspector.width = top, width
    local height = placeBody(frame, width)
    frame:SetHeight(math.min(maxHeight, top + height + 4))
    local inner = scroll:Fit(height)
    if inner ~= width then scroll:Fit(placeBody(frame, inner)) end
end
local function build(host)
    local frame = K.Window(host, "", 640, 380)
    frame.links, frame.tiles = {}, {}
    frame.address = K.CopyField(frame, 612)
    frame.address:SetScript("OnEscapePressed", function() frame:Hide() end)
    K.Tooltip(frame.address, ns.T("setCopyTip"), "")
    frame.scroll = K.PanelScroll:New({body = frame, width = 640}, "ManaCodeAuctionAboutScroll", 300, 95)
    local child = frame.scroll.child
    local locale = GetLocale and GetLocale() == "ruRU" and "ruRU" or "enUS"
    for _, link in ipairs(LINKS) do
        local url = link[1] == "curseforge" and ns.aboutMirror or ns.aboutLinks[link[1]]
        if url then
            if link[1] == "site" then url = url .. (locale == "ruRU" and "/" or "/en/") end
            frame.links[#frame.links + 1] = K.Button(frame, ns.T(link[2]), 90, function() selectAddress(url) end)
            if #frame.links == 1 then frame.address:SetUrl(url) end
        end
    end
    frame.purpose = K.Label(child, ns.T("setPurpose"), 0, 0, 600)
    frame.data = K.Label(child, ns.T("aboutAuctionData"), 0, 0, 600, "secondary")
    frame.others = K.Label(child, ns.T("setOthers"), 0, 0, 600, "heading")
    for _, addon in ipairs(ns.otherAddons) do
        if addon.folder ~= ADDON then
            local title = addon.name
            if addon.beta then title = title .. " " .. K.Colored(ns.T("setBeta"), "secondary") end
            local tile = K.Button(child, title, 280, function() selectAddress(addon.url) end)
            tile.addon = addon
            tile.tone = "gold"
            tile.text:SetJustifyH("LEFT"); tile.text:SetWordWrap(false)
            tile.state = K.Label(tile, "", 0, 0, 100, "secondary")
            tile.state:SetJustifyH("RIGHT")
            tile.desc = K.Label(tile, addon[locale] or addon.enUS or "", 0, 0, 264, "secondary")
            tile.desc:SetJustifyV("TOP")
            K.StyleButton(tile)
            K.Tooltip(tile, addon.name, addon.url)
            frame.tiles[#frame.tiles + 1] = tile
        end
    end
    if #frame.tiles == 0 then frame.others:Hide() end
    frame.authors = K.Label(child, ns.T("aboutAuthors") .. " - " .. table.concat(ns.aboutAuthors, ", "), 0, 0, 600, "secondary")
    frame:HookScript("OnHide", function() frame.address:ClearFocus() end)
    K.OnFont(function() if frame:IsVisible() then layout(frame) end end)
    return frame
end
function A.Open(host)
    if not host then
        local trader = ns.Trader and ns.Trader.frame
        host = trader and trader:IsVisible() and trader or UIParent
    end
    if not host then return end
    if not A.window then A.window = build(host) end
    local frame = A.window
    if frame:GetParent() ~= host then
        frame:SetParent(host)
        frame:ClearAllPoints(); frame:SetPoint("CENTER", host, "CENTER", 0, 0)
    end
    frame.coverAuction = host ~= UIParent
    local version = ns.Compat.AddonMeta(ADDON, "Version") or "?"
    local title = ns.T("tradeTitle") .. "  " .. K.Colored(ns.T("setVersion", version), "secondary")
    local versions = ns.Version
    local latest = versions and versions.Newest and versions.Newest()
    if latest and versions.Compare and versions.Compare(latest, version) == 1 then
        title = title .. "  " .. K.Colored(ns.T("aboutVersionNew", latest), "positive")
    end
    frame.heading:SetText(title)
    for _, tile in ipairs(frame.tiles) do
        local installed = ns.Compat.AddonState(tile.addon.folder)
        tile.state:SetText(ns.T(installed and "setInstalled" or "setMissing"))
        tile.state:SetTextColor(unpack(K.theme[installed and "positive" or "secondary"]))
    end
    layout(frame)
    frame:Show()
end
