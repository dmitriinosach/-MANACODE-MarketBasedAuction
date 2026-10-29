local _, ns = ...
ns.pathGroups = {
    {key = "disenchant", side = -1, kinds = {disenchant = true}, labelKey = "pathGroupDisenchant", min = 2, open = true,
        spell = 13262},
    {key = "mill", side = -1, kinds = {mill = true}, labelKey = "pathGroupMill", min = 3, open = false, spell = 51005},
    {key = "prospect", side = -1, kinds = {prospect = true}, labelKey = "pathGroupProspect", min = 3, open = false,
        spell = 31252},
    {key = "scrolls", side = 1, categories = {enchantingScrolls = true, enchantingScrollsBC = true},
        labelKey = "pathGroupScrolls", min = 3, open = false},
    {key = "potions", side = 1, categories = {alchemyPotions = true}, labelKey = "pathGroupPotions", min = 3, open = false},
    {key = "elixirs", side = 1, categories = {alchemyElixirs = true}, labelKey = "pathGroupElixirs", min = 3, open = false},
    {key = "flasks", side = 1, categories = {alchemyFlasks = true}, labelKey = "pathGroupFlasks", min = 3, open = false},
    {key = "transmutes", side = 1, categories = {alchemyTransmutes = true}, labelKey = "pathGroupTransmutes", min = 3,
        open = false},
    {key = "cuts", side = 1, kinds = {cut = true}, labelKey = "pathGroupCuts", min = 3, open = false},
    {key = "craft", side = 1, kinds = {craft = true, transmute = true}, byProfession = true,
        labelKey = "pathGroupProfession", min = 4, open = false},
}
