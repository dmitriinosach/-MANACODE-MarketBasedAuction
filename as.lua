local ADDON, ns = ...
ns.ADDON = ADDON
ns.VERSION = "0.1.0"
function ns.chat(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[MANACODE]|r |cffffdb6bAuctionScan|r: " .. tostring(msg))
end
function ns.say(msg)
    local status = ns.Trader and ns.Trader.footerStatus
    if status and status:IsVisible() then ns.Trader.Status(tostring(msg)); return end
    ns.chat(msg)
end
