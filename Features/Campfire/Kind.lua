-- Campfires (WoW Forever's camps): a minute sat by one, and who sat there
-- too. The diary's first feature in a folder of its own, and the pattern
-- for the rest (.claude/skills/new-feature/folder.md):
--
--   Kind.lua     what a campfire is to the diary: the People row, its
--                icon, the route's list and the recap's moment
--   Text.lua     its words on Your Diary's plates: the slip's, the
--                tooltip's, the caption's
--   Mark.lua     its mark on the plates (a flame on two crossed logs)
--   Slip.lua     its note in the plates' margin ("sat by a campfire")
--   Capture.lua  the countdown watched, and the fire and its sitters
--                written down
--   Dev.lua      its part of /sd testdata (never packaged)
--
-- Everything is registered into the core's and the UI's registries, so no
-- file outside this folder names a campfire. Its own names are on
-- ns.Campfire, made here, the first of its files the TOC loads.
--
-- This file: the "campfire" row on each person who sat there too, the
-- route's list of fires sat by, and the moment that puts them on the
-- plates.

local addonName, ns = ...

local Campfire = {}
ns.Campfire = Campfire

--------------------------------------------------------------------------
-- The People row
--------------------------------------------------------------------------

-- A campfire sat by together (Capture.lua): always a line, one a sitting,
-- however many minutes it was renewed. Within arm's reach, so a live row
-- is also "last seen"; offered by the picker as "sat by a campfire
-- together".
--
-- Its line: "You and Bram sat by a campfire together in Lushwater Oasis,
-- The Barrens". The user's own words (14 Oct), the place "Subzone, Zone"
-- as everywhere; the zone alone where the client gave no subzone, or one
-- with the zone's own name. Its icon: Basic Campfire's own spell icon.
ns.Rows.Register("campfire", {
    proximity = true,
    plate = 6,
    moment = function() return true end,
    reason = "sat by a campfire together",
    text = function(row, guid)
        local them = guid and ns.Characters.Name(guid)
        local subZone = row.context and row.context.subZone
        if subZone == "" then subZone = nil end
        local place = row.zone
        if subZone and place and subZone ~= place then
            place = subZone .. ", " .. place
        elseif subZone then
            place = subZone
        end
        return (them and (ns.UI.Format.You(row.me, "{You} and ") .. them .. " sat") or "Sat") .. " by a campfire together"
            .. (place and (" in " .. place) or "")
    end,
    icon = "campfire",
})
ns.Style.AddArt("campfire", { "Interface\\Icons\\Spell_Fire_Fire", "Interface\\Icons\\INV_Sword_04" })

--------------------------------------------------------------------------
-- The route's list: a minute sat by one, and its benefits had
--------------------------------------------------------------------------
--
-- WoW Forever's campfires give camp benefits after a minute sat nearby
-- (Capture.lua). Only a minute sat out counts; a sitting that renews the
-- buff minute after minute is one campfire, not one a minute.
--
-- j.campfires holds each, oldest first: { t, mapID, x, y, subZone, zone }.
-- `t` is when the first minute was done; the rest is where. The newest 300
-- are kept a character.

local Journey = ns.Journey
Journey.RegisterList("campfires", { cap = 300 })

-- A campfire sat by on route `j`, here and now unless `where` says
-- otherwise (in ns.Where's shape).
function Campfire.Add(j, t, where)
    return Journey.Append(j, "campfires", { t = t, subZone = where and where.subZone or nil,
        zone = where and where.zone or nil }, where)
end

-- One sat by on the logged-in character's route, while it is kept.
function Campfire.Added(t, where)
    local j = Journey.Kept()
    if not j then return nil end
    return Campfire.Add(j, t, where)
end

-- A character's campfires, oldest first.
function Campfire.List(j)
    return Journey.List(j, "campfires")
end

--------------------------------------------------------------------------
-- The recap's moment
--------------------------------------------------------------------------

-- A campfire sat by, where its first minute was done. Its spot is
-- zone-level only; without one, the route's at its time.
--
-- It opens a plate too, but last of everything that does: after a
-- dungeon's door (RANK 5), before a stay (6). It is filler, "kind of
-- unimportant, just filler if we don't have anything better" (the user,
-- 14 Oct), so 5.5 puts it between the two without moving anything else;
-- ranks are only ever compared, never counted.
--
-- Light: with only a small slip ("sat by a campfire") under the caption,
-- or the words saying it where there is no room (the user's choice, 14
-- Oct), a plate of fires and places alone is given a print, not a full
-- slot.
ns.JourneyRecap.RegisterMoment("campfire", { order = 70, list = "campfires", field = "campfire", rank = 5.5,
    light = true })
