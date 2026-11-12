-- Fishing's words on Your Diary's plates: the mark's tooltip. Copy changes
-- go through the copywriter skill, as every player-read word does.

local addonName, ns = ...

local Fishing = ns.Fishing
local Text = ns.UI.JourneyText
local List = Text.List
local L, Fmt = ns.L, ns.Fmt

-- The most names a tooltip lists; past it the last says how many more.
local NAMES = 4

-- The tooltip's title for the catches on one spot (a list of one for a
-- single catch): "Fished up Raw Spotted Yellowtail", "Fished something up"
-- where the loot held no item, and for several "Fished here twice",
-- "Fished here 12 times".
local function Title(catches)
    if #catches == 1 then
        local name = catches[1].name
        if name then return Fmt(L["Fished up %s"], name) end
        return L["Fished something up"]
    end
    return Fmt(L["Fished here %s##times"], ns.UI.Format.Times(#catches))
end

-- The catches' tooltip (the mark's, a spot's catches told together): the
-- title, then, for several, each name once, and last when and at what
-- level, as every mark's tooltip on the plates ends (the core's Text.Foot):
-- "Today at 12:47 and 15:10, level 20".
function Fishing.Tips(catches, now)
    local names, seen = {}, {}
    local ts, lo, hi = {}, nil, nil
    local j = ns.Journey.For and ns.Journey.For(ns.ownGUID)
    for _, c in ipairs(catches) do
        if c.name and not seen[c.name] then
            seen[c.name] = true
            names[#names + 1] = c.name
        end
        ts[#ts + 1] = c.t or 0
        local level = j and ns.JourneyRecap and ns.JourneyRecap.LevelAt(j, c.t or 0) or nil
        if level then
            lo = (not lo or level < lo) and level or lo
            hi = (not hi or level > hi) and level or hi
        end
    end
    if #names > NAMES then
        local rest = #names - (NAMES - 1)
        for i = #names, NAMES, -1 do names[i] = nil end
        names[NAMES] = Fmt(L["%d more"], rest)
    end
    local lines = {}
    if #catches > 1 and names[1] then lines[#lines + 1] = List(names) end
    lines[#lines + 1] = Text.Foot({ times = ts, levelFrom = lo, levelTo = hi }, now)
    return Title(catches), lines
end

-- One catch's tooltip, as its spot's alone (Fishing.Tips).
function Fishing.Tip(catch, now)
    return Fishing.Tips({ catch }, now)
end
