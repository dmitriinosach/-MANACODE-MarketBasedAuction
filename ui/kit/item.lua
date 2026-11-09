local _, ns = ...
local K = ns.TradeKit
function K.ModifiedItemClick(item)
    if not (IsModifiedClick and HandleModifiedItemClick) then return false end
    if not (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP")) then return false end
    local link = type(item) == "string" and item or select(2, ns.Compat.ItemInfo(item))
    if not link then return false end
    HandleModifiedItemClick(link)
    return true
end
K.PROFESSION_ICONS = {
    alchemy = "Interface\\Icons\\Trade_Alchemy", blacksmithing = "Interface\\Icons\\Trade_BlackSmithing",
    enchanting = "Interface\\Icons\\Trade_Engraving", engineering = "Interface\\Icons\\Trade_Engineering",
    inscription = "Interface\\Icons\\INV_Inscription_Tradeskill01", jewelry = "Interface\\Icons\\INV_Misc_Gem_01",
    leatherworking = "Interface\\Icons\\INV_Misc_ArmorKit_17", tailoring = "Interface\\Icons\\Trade_Tailoring",
    cooking = "Interface\\Icons\\INV_Misc_Food_15", firstaid = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    mining = "Interface\\Icons\\Trade_Mining", herbalism = "Interface\\Icons\\Spell_Nature_NatureTouchGrow",
    skinning = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", fishing = "Interface\\Icons\\Trade_Fishing",
}
function K.ProfessionIcon(profession)
    return profession and K.PROFESSION_ICONS[profession] or "Interface\\Icons\\INV_Misc_Coin_01"
end
function K.ItemChoice(parent, fn)
    local b = K.Navigation(parent, "", function(self, button)
        local id = not rawget(self, "spellID") and rawget(self, "itemID")
        if id and K.ModifiedItemClick(rawget(self, "itemLink") or id) then return end
        if fn then fn(self, button) end
    end)
    b:SetWidth(192)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetWidth(20)
    b.icon:SetHeight(20)
    b.icon:SetPoint("LEFT", b, "LEFT", 2, 0)
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", b, "LEFT", 28, 0)
    b.text:SetWidth(160)
    K.SetFontHeight(b.text, 14)
    b:SetScript("OnEnter", function(self)
        if not self.itemID and not self.spellID then return end
        K.TipOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.spellID and ("spell:" .. self.spellID) or self.itemLink or ("item:" .. self.itemID))
        if self.itemID and ns.Markets then
            local q = ns.Markets.Quote(self.itemID)
            if q and q.vendor then
                GameTooltip:AddLine(ns.T("cacheVendorPrice", K.Money(q.price)), K.theme.gold[1], K.theme.gold[2], K.theme.gold[3], true)
            elseif q and q.at and rawget(GameTooltip, "manacodePending") then
                GameTooltip:AddLine(ns.T("tipScanAgo", K.Ago(math.max(0, time() - q.at)))
                    .. (q.shared and ns.T("boardShared") or ""), K.theme.secondary[1], K.theme.secondary[2], K.theme.secondary[3], true)
            end
        end
        if self.extraTip then GameTooltip:AddLine(self.extraTip, K.theme.gold[1], K.theme.gold[2], K.theme.gold[3], true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end
function K.ItemsArrived()
    if ns.Trader and ns.Trader.frame then ns.Trader.Refresh() end
end
function K.SetItemChoice(b, id, active, quality, link)
    b.spellID = nil
    b.itemID = id
    b.itemLink = link
    local name, _, rarity = ns.Compat.ItemInfo(link or id)
    if not rarity then ns.Compat.RequestItem(id, K.ItemsArrived) end
    b.quality = quality or rarity
    b.text:SetText(name or ns.Markets.Name(id))
    b.text:SetTextColor(K.QualityColor(b.quality))
    b.icon:SetTexture(select(10, ns.Compat.ItemInfo(link or id)))
    K.SetSelected(b, active)
    b:Show()
end
function K.SetSpellChoice(b, spell, active)
    local name, icon = ns.Compat.SpellIcon(spell)
    b.itemID, b.itemLink, b.quality, b.spellID = nil, nil, nil, spell
    b.text:SetText(name or ns.T("levelSpell", spell))
    b.text:SetTextColor(unpack(K.theme.text))
    b.icon:SetTexture(icon)
    K.SetSelected(b, active)
    b:Show()
end
