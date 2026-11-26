local _, ns = ...
ns.recyclePairs = {
    {key = "magic", group = "essence", small = 10938, big = 10939, ratio = 3, both = true},
    {key = "astral", group = "essence", small = 10998, big = 11082, ratio = 3, both = true},
    {key = "mystic", group = "essence", small = 11134, big = 11135, ratio = 3, both = true},
    {key = "nether", group = "essence", small = 11174, big = 11175, ratio = 3, both = true},
    {key = "eternal", group = "essence", small = 16202, big = 16203, ratio = 3, both = true},
    {key = "planar", group = "essence", small = 22447, big = 22446, ratio = 3, both = true},
    {key = "cosmic", group = "essence", small = 34056, big = 34055, ratio = 3, both = true},
    {key = "earth", group = "element", small = 37701, big = 35624, ratio = 10, both = true},
    {key = "fire", group = "element", small = 37702, big = 36860, ratio = 10, both = true},
    {key = "water", group = "element", small = 37705, big = 35622, ratio = 10, both = true},
    {key = "air", group = "element", small = 37700, big = 35623, ratio = 10, both = true},
    {key = "shadow", group = "element", small = 37703, big = 35627, ratio = 10, both = true},
    {key = "life", group = "element", small = 37704, big = 35625, ratio = 10, both = true},
    {key = "moteAir", group = "mote", small = 22572, big = 22451, ratio = 10, both = false},
    {key = "moteEarth", group = "mote", small = 22573, big = 22452, ratio = 10, both = false},
    {key = "moteFire", group = "mote", small = 22574, big = 21884, ratio = 10, both = false},
    {key = "moteLife", group = "mote", small = 22575, big = 21886, ratio = 10, both = false},
    {key = "moteMana", group = "mote", small = 22576, big = 22457, ratio = 10, both = false},
    {key = "moteShadow", group = "mote", small = 22577, big = 22456, ratio = 10, both = false},
    {key = "moteWater", group = "mote", small = 22578, big = 21885, ratio = 10, both = false},
}
ns.recycleGroups = {essence = "recycleEssences", element = "recycleElements", mote = "recycleMotes"}
