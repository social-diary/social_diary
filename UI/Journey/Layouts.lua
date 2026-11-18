-- Which plates a level of Your Diary has, and on which page (JRN-21): a
-- slot's art box (ArtSize), the window each layout's plates are grouped by
-- (SMALLEST), whether a plate holds in a slot (Holds), the page its
-- plates' weights give (LayoutFor: LAYOUT's FL, LFF, ..., or the page for
-- that many), an entry's plates grouped at the largest window that gives
-- a page (PlatesOf), and what a plate draws from, once per recap: a
-- zone's road and meetings (SheetOf), an entry's moments (MomentsOf).
--
-- The module and its siblings: UI/Journey/Look.lua.

local addonName, ns = ...

local Plate = ns.UI.JourneyPlate
local YourDiary = ns.UI.YourDiary

local LAYOUT, SNAPSHOT = YourDiary.LAYOUT, YourDiary.SNAPSHOT

--------------------------------------------------------------------------
-- The plates (right page)
--------------------------------------------------------------------------

-- The art box of a slot: the card less its margin.
local function ArtSize(slot)
    return slot.w - 2 * slot.pad, slot.h - 2 * slot.pad
end

-- The smallest art box of each layout: the window a plate of it must fit.
local SMALLEST = {}
for n, slots in ipairs(LAYOUT) do
    local aw, ah = math.huge, math.huge
    for _, slot in ipairs(slots) do
        local w, h = ArtSize(slot)
        aw, ah = math.min(aw, w), math.min(ah, h)
    end
    SMALLEST[n] = { aw, ah }
end

-- Whether `plate` (Recap.Plates's) holds in `slot`: its moments span no
-- more than PLATES.inset of the slot's art, on its own map.
local function Holds(plate, slot)
    local w, h = Plate.Cover(plate.mapID, ArtSize(slot))
    return ns.JourneyRecap.Holds(plate, w, h)
end

-- The page for `plates`, keyed by their weights in time order (LAYOUT's
-- FL, LFF, ...; any other pattern the page for that many), and that key.
-- A light plate is drawn light only where a snapshot holds it: a level's
-- pin far from the first spot is drawn full, so nothing on it goes
-- missing (the user's choice, 13 Oct). Nil where a slot does not hold its
-- plate, for the plates to be grouped at a smaller window.
local function LayoutFor(plates)
    if #plates == 0 then return {}, "" end
    local key = {}
    for i, p in ipairs(plates) do key[i] = (p.light and Holds(p, SNAPSHOT)) and "L" or "F" end
    key = table.concat(key)
    local layout = LAYOUT[key] or LAYOUT[#plates]
    for i, p in ipairs(plates) do
        if not Holds(p, layout[i]) then return nil end
    end
    return layout, key
end

-- An entry's plates (JRN-21), worked out once per recap and kept on the
-- entry with their page (LayoutFor) and its key: grouped for the one-plate
-- layout's window first, and only where a plate does not hold in its slot
-- on the page that grouping gives, for the windows of the layout that
-- many take, so a level spent on one hillside is one large plate and a
-- level that travelled has three small ones. Slots of one page differ in
-- size now (a snapshot beside a tall plate), so each plate is asked of its
-- own; two plates at the two-plate window always hold, as before, and
-- three where every slot holds them are no longer split smaller.
local function PlatesOf(e)
    local page = YourDiary.page
    if e.plates then return e.plates, e.layout, e.pattern end
    local j = ns.Journey.For(ns.ownGUID)
    local plates, layout, key, cover = {}, nil, nil, nil
    for n = 1, #SMALLEST do
        local aw, ah = SMALLEST[n][1], SMALLEST[n][2]
        cover = function(mapID) return Plate.Cover(mapID, aw, ah) end
        plates = ns.JourneyRecap.Plates(j, e, page.ctx or {}, cover)
        layout, key = LayoutFor(plates)
        if layout then break end
    end
    -- The last window always holds in the page for its count, as before.
    if not layout then layout, key = LAYOUT[#plates], string.rep("F", #plates) end
    -- (and the window they were grouped at, `cover`, for the ticklist's
    -- places, Recap.Choices, to be grouped as the page's are)
    e.plates, e.layout, e.pattern, e.cover = plates, layout, key, cover
    return plates, layout, key
end

-- A zone's road and meetings (Recap.Sheet), and an entry's moments
-- (Recap.Moments), once per recap.
local function SheetOf(mapID)
    local page = YourDiary.page
    local sheet = page.sheets[mapID]
    if not sheet then
        sheet = ns.JourneyRecap.Sheet(ns.Journey.For(ns.ownGUID), mapID, page.ctx or {})
        page.sheets[mapID] = sheet
    end
    return sheet
end

local function MomentsOf(e)
    local page = YourDiary.page
    local list = page.moments[e]
    if not list then
        list = ns.JourneyRecap.Moments(ns.Journey.For(ns.ownGUID), e, page.ctx or {})
        page.moments[e] = list
    end
    return list
end

YourDiary.ArtSize, YourDiary.Holds, YourDiary.LayoutFor, YourDiary.PlatesOf = ArtSize, Holds, LayoutFor, PlatesOf
YourDiary.SheetOf, YourDiary.MomentsOf = SheetOf, MomentsOf
