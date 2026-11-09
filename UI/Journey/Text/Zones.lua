-- A zone in Your Diary's words (ns.UI.JourneyText): its name and line in
-- the zone index (JRN-15), and the line under a full-page plate.
--
-- The module and its siblings: UI/Journey/Text/Grammar.lua.

local addonName, ns = ...

local Text = ns.UI.JourneyText
local List = ns.UI.Format.List
-- Tooltips and single lines keep the plain formatter; what wraps (the
-- prose, captions, margin notes) holds its times together (Text.Duration,
-- UI/Journey/Text/Time.lua).
local Plain = ns.UI.Format.Duration
local MapName = Text.MapName

--------------------------------------------------------------------------
-- The zone index (JRN-15)
--------------------------------------------------------------------------

-- "The Barrens", "levels 10 to 14, 3 h 20 min".
function Text.ZoneName(z)
    return MapName(z.mapID) or ("Map " .. z.mapID)
end

function Text.ZoneLine(z)
    local levels
    if z.levelMin and z.levelMax and z.levelMin ~= z.levelMax then
        levels = ("levels %d to %d"):format(z.levelMin, z.levelMax)
    elseif z.levelMin then
        levels = "level " .. z.levelMin
    end
    local parts = {}
    if levels then parts[#parts + 1] = levels end
    if z.seconds and z.seconds >= 60 then parts[#parts + 1] = Plain(z.seconds) end
    return table.concat(parts, ", ")
end

-- The line under a full-page plate (JRN-15): "levels 1 to 5, 6 h 20 min,
-- with Dos and Koko, 2 fights". `names` are the diary people met there, short.
function Text.ZoneFoot(z, names, fights)
    local line = Text.ZoneLine(z)
    local parts = { line ~= "" and line or nil }
    local list = List(names or {}, { max = 4, shown = 3, more = "others" })
    if list then parts[#parts + 1] = "with " .. list end
    if (fights or 0) > 0 then parts[#parts + 1] = fights == 1 and "a fight" or (fights .. " fights") end
    return table.concat(parts, ", ")
end
