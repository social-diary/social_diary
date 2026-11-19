-- What the player chose to have on a page of Your Diary
-- (.claude/features/choose-page.md): a moment kept, or left out. The diary
-- still picks everything else; detection never stops recording, a choice only
-- changes what the page shows.
--
-- Saved on the character's route, by the moment's key (Recap.Key, made of
-- what does not change while a piece grows):
--
--   j.chosen = { [key] = "keep" | "out" }   a key not there is the diary's
--
-- Additive, no schema: an old route has no `chosen`, and reads as the diary
-- picks. Recap.Moments leaves an `out` moment off (listed in e.hidden with its
-- key) and marks a `keep` one, which Rank puts above everything, as it does a
-- custom card.
--
-- A card with a record of a kind that may be custom (Core/Custom.lua) keeps
-- its own switch: left out is Custom.Hide, as the map's menu does, so
-- `rec.custom.hidden` and j.chosen never both say it is off. Kept is
-- Custom.Show, and `keep` beside it, which only ranks it: a card back on the
-- page has to win its place too. A card the player inserted has no hiding of
-- its own (Gather reads j.custom as it is), so its choice is j.chosen's.
--
-- A place is a group of moments (Recap.Plates' plate), so its choice is
-- written on them: kept, `keep` on its lead moment (best rank, then the
-- earliest), which opens the plate and wins it its place; left out, `out` on
-- every moment it holds now. One that comes there later (the current piece
-- still growing) is new, and may bring the place back.
--
-- Writers go to the logged-in character's route (Journey.Mine, as custom cards
-- do: it is the player's writing, not capture), and Journey.Touch, so the
-- recap is built again.

local addonName, ns = ...

local Chosen = {}
ns.Chosen = Chosen

local Journey = ns.Journey

local KEEP, OUT = "keep", "out"
Chosen.KEEP, Chosen.OUT = KEEP, OUT

-- A moment's key (or an e.hidden entry's: its own where it has one).
function Chosen.Key(m)
    return m.key or ns.JourneyRecap.Key(m)
end

-- The detected record behind a card whose kind may be custom, which keeps
-- its own switch; nil for anything else, an inserted card included.
local function CustomRecord(m)
    local spec = ns.JourneyRecap.MOMENTS[m.kind]
    if not (spec and spec.custom) then return nil end
    local rec = spec.field and m[spec.field] or m.rec
    if not rec or rec.inserted then return nil end
    return rec.customOf or rec
end
Chosen.CustomRecord = CustomRecord

-- "keep", "out", or nil where the diary chooses.
function Chosen.Of(j, m)
    local rec = CustomRecord(m)
    if rec and rec.custom and rec.custom.hidden then return OUT end
    local chosen = j and j.chosen
    return chosen and chosen[Chosen.Key(m)] or nil
end

local function Set(j, key, value)
    if value then
        j.chosen = j.chosen or {}
        j.chosen[key] = value
    elseif j.chosen then
        j.chosen[key] = nil
        if next(j.chosen) == nil then j.chosen = nil end
    end
end

-- `j` stands in for Journey.Mine() (the tests'); the logged-in character's
-- where nil.
local function Route(j)
    return j or Journey.Mine()
end

-- `m` (a moment, or an e.hidden entry) on the page, above the diary's own.
function Chosen.Keep(j, m)
    j = Route(j)
    if not (j and m) then return false end
    local rec = CustomRecord(m)
    if rec and rec.custom and rec.custom.hidden then ns.Custom.Show(rec) end
    Set(j, Chosen.Key(m), KEEP)
    Journey.Touch()
    return true
end

-- `m` off the page.
function Chosen.Leave(j, m)
    j = Route(j)
    if not (j and m) then return false end
    local rec = CustomRecord(m)
    if rec then
        Set(j, Chosen.Key(m), nil)
        return ns.Custom.Hide(rec)
    end
    Set(j, Chosen.Key(m), OUT)
    Journey.Touch()
    return true
end

-- The moment a plate opened round: the best ranked, then the earliest.
function Chosen.Lead(plate)
    local Rank, lead = ns.JourneyRecap.Rank, nil
    for _, m in ipairs(plate and plate.moments or {}) do
        if not lead then
            lead = m
        else
            local r, best = Rank(m), Rank(lead)
            if r < best or (r == best and m.t < lead.t) then lead = m end
        end
    end
    return lead
end

-- A place (a plate, shown or spare) on the page.
function Chosen.KeepPlace(j, plate)
    local lead = Chosen.Lead(plate)
    return lead ~= nil and Chosen.Keep(j, lead)
end

-- A place off the page: every moment it holds.
function Chosen.LeavePlace(j, plate)
    local any = false
    for _, m in ipairs(plate and plate.moments or {}) do
        any = Chosen.Leave(j, m) or any
    end
    return any
end

-- `m` back to the diary's choice. Not a choice the player is offered (there
-- is no way back to the diary's, the user's, 18 Nov): only a place kept
-- again after it was left out whole (Tick) brings the rest of it back so.
local function Clear(j, m)
    local rec = CustomRecord(m)
    if rec and rec.custom and rec.custom.hidden then ns.Custom.Show(rec) end
    Set(j, Chosen.Key(m), nil)
end

--------------------------------------------------------------------------
-- The page's deaths
--------------------------------------------------------------------------
--
-- A death's moment is its segment (Recap.Moments' "death"), but its cross on a
-- stop is drawn from the route (the trail's pools, UI/Journey/Plate.lua) and
-- its killer's card from the deaths' list (Features/Deaths/Card.lua's pass):
-- both ask here, so a death left out is off the page whole, cross and card
-- (the user's, 18 Nov: "off the page", as the menu's hide).

local function DeathKey(seg)
    return ns.JourneyRecap.Key({ kind = "death", t = seg.from })
end

-- Whether the death at `t` is left out: the moment of the segment that
-- counted it (Journey.CountedOn).
function Chosen.DeathOut(j, t)
    local chosen = j and j.chosen
    if not chosen then return false end
    local seg = Journey.CountedOn(j, t)
    return seg ~= nil and chosen[DeathKey(seg)] == OUT
end

-- How many of the deaths counted on `segs` (`count` in all) are on the page.
function Chosen.DeathsShown(j, segs, count)
    local chosen = j and j.chosen
    if not chosen then return count end
    local n, out = 0, false
    for _, seg in ipairs(segs or {}) do
        if seg.from and chosen[DeathKey(seg)] == OUT then
            out = true
        else
            n = n + (seg.act and seg.act.deaths or 0)
        end
    end
    return out and n or count
end

--------------------------------------------------------------------------
-- The ticklist's model (.claude/features/choose-page.md, "Stable list")
--------------------------------------------------------------------------
--
-- Recap.Choices(j, e, ctx, cover) → choices: for one piece, every moment the
-- diary noticed, by zone, with what the ticklist draws for each. No frames and
-- no words: the looks and reasons are keys.
--
-- The list is stable (the user's, 18 Nov, after the client round: "plates may
-- regroup freely to fit the most, but the items in the selection must be
-- stable and never jump"): it is made from the moments alone (Recap.Moments
-- with the ones left out, and the cards hidden through Core/Custom.lua), never
-- from how the plates are grouped, so a tick changes a row's look and the
-- plate it is on, and never which rows there are, their order or their words.
-- The grouping is only read for where each moment is now.
--
--   choices = {
--     zones     every zone (mapID), in order of its first moment
--     plates    the page's plates, in their order (time, as the page stands
--               them): { mine, mapID } each, `mine` where it holds
--               something the player chose (a keep, or a card they wrote or
--               changed), `mapID` its zone (the cap line's tooltip)
--     max       how many plates fit (Recap.PLATES.max, 3)
--     mine      how many plates on the page are the player's
--     diary     how many are the diary's
--     full      three on the page, all the player's
--   }
--   a zone = { row = "zone", key ("zone:<mapID>"), mapID, t (its first
--     moment's), rows, state ("all" | "some" | "none": how many of its rows
--     are on the page), on (state ~= "none"), look, reason, madeRoomFor,
--     lead (the
--     moment a keep of the whole zone is written on: its best, then the
--     earliest, of what it shows, or of all of it where it shows nothing) }
--   a row = { row = "moment", key (its first moment's), keys, kind, t,
--     moment (its first), moments (every one it stands for, in time order),
--     zone, plate (the index of the plate it is on, top to bottom; nil off
--     the page: the ticklist rings the row's mark on it), on,
--     look, reason, madeRoomFor }
--     One for every moment of the zone, in time order, but one for all the
--     trips through one dungeon's door in the zone (the plate draws one door
--     for them): ticked, they go together.
--
-- Looks: `diary` (a faded tick: on the page, the diary's pick), `diaryOff`
-- (an empty box: the diary left it off), `keep` (a red tick: the player's; a
-- moment kept, or a card they wrote or changed), `out` (a red cross: left out
-- by the player). A zone: `out` where every row is; else `keep` where it shows
-- something and anything of it is the player's (kept or left out), `diary`
-- where it shows something, `diaryOff` where it shows nothing.
--
-- Reasons, for a row not on the page (the ticklist's tooltip): `marginRoom`
-- (its plate is on the page, its margin had no room: UI/Journey/Margin.lua's
-- plate.leftOff), `madeRoom` (on the plate a keep took the place of, Tick:
-- `madeRoomFor` the kept moment's zone's mapID; remembered until another keep
-- moves one off, not saved), `next` (on the best of the plates that did not
-- fit), `noRoom` (on another of them), `minor` (it opens no plate of its own: a
-- second stay in a zone shown, filler, a level's pin; keeping it opens one),
-- `run` (a door whose run was recorded: the run has its page, Recap.Plates
-- drops such a plate unless it is kept), `byYou` (left out by the player). A
-- zone that shows nothing has the first of its rows' reasons in that order,
-- `marginRoom` aside.

local Recap = ns.JourneyRecap

-- The last keep that took another plate's room (Tick), for "made room for":
-- { from (the piece's start), zone (the kept moment's mapID), bumped (the
-- keys of the plate that went) }. Not saved: a reload forgets it.
local last

local function Mine(m)
    return m.chosen ~= OUT and Recap.Rank(m) <= Recap.CUSTOM_RANK
end

-- A card hidden through Core/Custom.lua (an e.hidden entry with its `rec`) as
-- the moment it would be, at its spot. Nil where it has none.
local function Hidden(j, h)
    local spec = Recap.MOMENTS[h.kind]
    local rec = h.rec
    if not (spec and rec) then return nil end
    local m, map, x, y
    if spec.moment then
        local wrap = spec.custom and spec.custom.wrap
        m, map, x, y = spec.moment(j, wrap and wrap(rec) or rec, Recap.Own)
    else
        map, x, y = Recap.Own(j, rec.mapID, rec.x, rec.y, rec.t)
        m = { kind = h.kind, t = rec.t, [spec.field or "rec"] = rec }
    end
    if type(m) ~= "table" or not (map and x) then return nil end
    m.mapID, m.x, m.y, m.chosen = map, x, y, OUT
    return m
end

-- Whether `m` is a card hidden through Core/Custom.lua (Gather leaves those
-- out of the piece, so no grouping of it can show one).
local function CustomHidden(m)
    local rec = CustomRecord(m)
    return rec ~= nil and rec.custom ~= nil and rec.custom.hidden == true
end

-- The page's plates for `e`: as the page drew them (e.plates, grouped at
-- e.cover by UI/Journey/Layouts.lua's PlatesOf, their margins' leftOff
-- on them), else Recap.Plates' at `cover`; and the window they were grouped
-- at.
local function PlatesFor(j, e, ctx, cover)
    if e.plates and e.plates.spare then return e.plates, e.cover or cover end
    return Recap.Plates(j, e, ctx, cover), cover
end

-- The keys of every moment on `plates`.
local function KeysOn(plates)
    local on = {}
    for _, plate in ipairs(plates) do
        for _, m in ipairs(plate.moments) do on[Chosen.Key(m)] = true end
    end
    return on
end

local REASONS = { "madeRoom", "next", "noRoom", "minor", "run" }

function Recap.Choices(j, e, ctx, cover)
    ctx = ctx or {}
    local plates
    plates, cover = PlatesFor(j, e, ctx, cover)

    -- Where each moment is now, by its key.
    local onPlate, spareAt, loose, unwritten = {}, {}, {}, {}
    for i, plate in ipairs(plates) do
        for _, m in ipairs(plate.moments) do onPlate[Chosen.Key(m)] = i end
        for _, it in ipairs(plate.leftOff or {}) do
            for _, m in ipairs(it.moments or {}) do unwritten[Chosen.Key(m)] = true end
        end
    end
    for i, plate in ipairs(plates.spare or {}) do
        for _, m in ipairs(plate.moments) do spareAt[Chosen.Key(m)] = i end
    end
    for _, m in ipairs(plates.loose or {}) do loose[Chosen.Key(m)] = true end
    local bumped = last and last.from == e.from and last.bumped or {}
    -- (next in line: the best of the spare plates, but not the one a keep
    -- just moved off, which says that instead)
    local nextSpare
    for i, plate in ipairs(plates.spare or {}) do
        local moved = false
        for _, m in ipairs(plate.moments) do moved = moved or bumped[Chosen.Key(m)] == true end
        if not moved then
            nextSpare = i
            break
        end
    end

    -- Every moment: the piece's, the ones left out, the hidden cards.
    local all = Recap.Moments(j, e, ctx, true)
    for _, h in ipairs(e.hidden or {}) do
        local m = h.rec and Hidden(j, h)
        if m then all[#all + 1] = m end
    end

    local zones, byMap, doors = {}, {}, {}
    for _, m in ipairs(all) do
        local zone = byMap[m.mapID]
        if not zone then
            zone = { row = "zone", key = "zone:" .. tostring(m.mapID), mapID = m.mapID, t = m.t, rows = {} }
            byMap[m.mapID] = zone
            zones[#zones + 1] = zone
        end
        zone.t = math.min(zone.t, m.t)
        local door = m.kind == "dungeon" and m.name and (tostring(m.mapID) .. ":" .. m.name) or nil
        local row = door and doors[door]
        if row then
            row.moments[#row.moments + 1] = m
        else
            row = { row = "moment", kind = m.kind, moments = { m }, zone = zone }
            zone.rows[#zone.rows + 1] = row
            if door then doors[door] = row end
        end
    end

    local function ByTime(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return a.key < b.key
    end
    for _, zone in ipairs(zones) do
        for _, row in ipairs(zone.rows) do
            table.sort(row.moments, function(a, b)
                if a.t ~= b.t then return a.t < b.t end
                return Chosen.Key(a) < Chosen.Key(b)
            end)
            row.moment, row.t, row.keys = row.moments[1], row.moments[1].t, {}
            for k, m in ipairs(row.moments) do row.keys[k] = Chosen.Key(m) end
            row.key = row.keys[1]

            -- Its look, its plate, why it is not on the page.
            local out, mine, at, margin, reason = true, false, nil, false, nil
            for k, m in ipairs(row.moments) do
                local key = row.keys[k]
                if not (Chosen.Of(j, m) == OUT or m.chosen == OUT) then
                    out = false
                    mine = mine or Mine(m)
                    if onPlate[key] and unwritten[key] then
                        margin = true
                    elseif onPlate[key] then
                        at = math.min(at or onPlate[key], onPlate[key])
                    end
                    local why = bumped[key] and "madeRoom" or spareAt[key] == nextSpare and "next"
                        or spareAt[key] and "noRoom" or loose[key] and "minor" or not onPlate[key] and "run" or nil
                    for _, r in ipairs(REASONS) do
                        if r == why or r == reason then
                            reason = r
                            break
                        end
                    end
                end
            end
            row.plate, row.on = at, at ~= nil
            if out then
                row.look, row.reason = "out", "byYou"
            else
                row.look = mine and "keep" or (row.on and "diary" or "diaryOff")
                if not row.on then row.reason = margin and "marginRoom" or reason end
                if row.reason == "madeRoom" then row.madeRoomFor = last.zone end
            end
        end
        table.sort(zone.rows, ByTime)

        -- The zone: how much of it shows, whose it is, why it does not show.
        local shown, left, theirs, held = 0, 0, false, {}
        for _, row in ipairs(zone.rows) do
            if row.on then shown = shown + 1 end
            if row.look == "out" then left = left + 1 end
            theirs = theirs or row.look == "keep" or row.look == "out"
        end
        zone.state = shown == #zone.rows and "all" or shown > 0 and "some" or "none"
        zone.on = shown > 0
        if zone.on then
            zone.look = theirs and "keep" or "diary"
        elseif left == #zone.rows then
            zone.look, zone.reason = "out", "byYou"
        else
            zone.look = "diaryOff"
            for _, r in ipairs(REASONS) do
                for _, row in ipairs(zone.rows) do
                    if not zone.reason and row.reason == r then
                        zone.reason, zone.madeRoomFor = r, row.madeRoomFor
                    end
                end
            end
        end
        for _, row in ipairs(zone.rows) do
            if left == #zone.rows or row.look ~= "out" then
                for _, m in ipairs(row.moments) do held[#held + 1] = m end
            end
        end
        zone.lead = Chosen.Lead({ moments = held })
    end
    table.sort(zones, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return tostring(a.mapID) < tostring(b.mapID)
    end)

    local choices = { zones = zones, plates = {}, max = Recap.PLATES.max, mine = 0, diary = 0 }
    for i, plate in ipairs(plates) do
        local mine = false
        for _, m in ipairs(plate.moments) do mine = mine or Mine(m) end
        choices.plates[i] = { mine = mine, mapID = plate.mapID }
        if mine then choices.mine = choices.mine + 1 else choices.diary = choices.diary + 1 end
    end
    choices.full = #plates >= choices.max and choices.mine >= choices.max
    return choices
end

-- The plates `e` would have with `keep` kept and `clear` back to the diary's
-- (a scratch copy of j.chosen: nothing is written).
local function Simulate(j, e, ctx, cover, keep, clear)
    local saved, scratch = j.chosen, {}
    for key, v in pairs(saved or {}) do scratch[key] = v end
    for _, m in ipairs(clear) do scratch[Chosen.Key(m)] = nil end
    for _, m in ipairs(keep) do scratch[Chosen.Key(m)] = KEEP end
    j.chosen = scratch
    local ok, plates = pcall(Recap.Plates, j, e, ctx, cover)
    j.chosen = saved
    if not ok then error(plates, 0) end
    return plates
end

-- A row of Recap.Choices' ticked (.claude/features/choose-page.md): one on
-- the page (`on`: a row on a plate, a zone showing anything) is left out, one
-- off it is kept. Returns { did = "out" | "keep", bumped = { mapID } (the
-- plate a keep moved off) }, or { blocked = true }: nothing written, the
-- ticklist says why.
--
-- A row left out: `out` on every moment it stands for (a door's trips
-- together). A zone left out: `out` on every moment of it. A row kept: `keep`
-- on each of its moments. A zone kept: `keep` on its lead; one the player had
-- left out whole comes back whole (its other moments back to the diary's, a
-- hidden card shown).
--
-- A keep that needs a plate of its own moves the diary's weakest off (the
-- ranks do it: a keep outranks any of the diary's). It is blocked only where
-- it cannot fit: grouped again with the keep written in scratch, the kept
-- moment, or anything the player had on the page, would be off it. (Grouped
-- at the window the page grouped at, e.cover; the page may group again at
-- another, as it does whenever the moments change.) `j` as Keep's; ctx and
-- cover as Recap.Choices'.
function Chosen.Tick(j, e, ctx, cover, row)
    j = Route(j)
    if not (j and e and row) then return nil end
    ctx = ctx or {}
    local zone = row.row == "zone" and row or row.zone
    -- A red tick leaves out, wherever it stands: one the margin had no room
    -- for is off the page but still the player's, and they untick it (the
    -- user's, in the client, 18 Nov). A zone likewise, where it holds one.
    if row.on or row.look == KEEP then
        for _, r in ipairs(row.row == "zone" and row.rows or { row }) do
            if r.look ~= "out" then
                for _, m in ipairs(r.moments) do Chosen.Leave(j, m) end
            end
        end
        return { did = OUT }
    end

    local keep, clear = {}, {}
    if row.row == "zone" then
        if not row.lead then return nil end
        keep[1] = row.lead
        if row.look == "out" then
            for _, r in ipairs(row.rows) do
                for _, m in ipairs(r.moments) do
                    if m ~= row.lead then clear[#clear + 1] = m end
                end
            end
        end
    else
        for _, m in ipairs(row.moments) do keep[#keep + 1] = m end
    end

    local before
    before, cover = PlatesFor(j, e, ctx, cover)
    local need = {}
    for _, plate in ipairs(before) do
        for _, m in ipairs(plate.moments) do
            if Mine(m) then need[Chosen.Key(m)] = true end
        end
    end
    for _, m in ipairs(keep) do
        if not CustomHidden(m) then need[Chosen.Key(m)] = true end
    end
    local now = KeysOn(Simulate(j, e, ctx, cover, keep, clear))
    for key in pairs(need) do
        if not now[key] then return { blocked = true } end
    end

    for _, m in ipairs(clear) do Clear(j, m) end
    for _, m in ipairs(keep) do Chosen.Keep(j, m) end
    local result = { did = KEEP }
    -- Which of the page's plates went: the one none of whose moments is on
    -- the page now.
    for _, plate in ipairs(before) do
        local stays = false
        for _, m in ipairs(plate.moments) do stays = stays or now[Chosen.Key(m)] == true end
        if not stays then
            last = { from = e.from, zone = zone and zone.mapID, bumped = KeysOn({ plate }) }
            result.bumped = { mapID = plate.mapID }
            break
        end
    end
    return result
end

-- (the tests': the remembered keep forgotten, as a reload does)
function Chosen.Forget()
    last = nil
end

--------------------------------------------------------------------------
-- Forgetting (PRV-3)
--------------------------------------------------------------------------

-- Someone forgotten leaves every choice keyed by them (`who`, the key's last
-- part), nil being everyone: every key whose `who` is a GUID (a creature's
-- npcID and a pin's in or out are no one).
local function ForgetOn(j, guid)
    if not j.chosen then return end
    for key in pairs(j.chosen) do
        local who = key:match("^[^:]*:[^:]*:(.*)$")
        if who and who ~= "" and (guid == nil or who == guid) and who:find("-", 1, true) then
            j.chosen[key] = nil
        end
    end
    if next(j.chosen) == nil then j.chosen = nil end
end

Journey.RegisterList("chosen", { forget = ForgetOn })
