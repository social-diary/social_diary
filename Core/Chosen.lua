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
-- The ticklist's model (.claude/features/choose-page.md)
--------------------------------------------------------------------------
--
-- Recap.Choices(j, e, ctx, cover) → choices: for one piece, every place the
-- diary noticed and every moment in it, with what the ticklist draws for each.
-- No frames and no words: the looks and reasons are keys (Phase 4 words them).
--
--   choices = {
--     places    every place, in time order (its first moment's)
--     max       how many places fit (Recap.PLATES.max, 3)
--     mine      how many places on the page are the player's (look `keep`)
--     diary     how many are the diary's (look `diary`)
--     full      three on the page, all the player's: a keep is blocked (Tick)
--   }
--   a place = { row = "place", key (its lead moment's), mapID, t, on (on the
--     page), look, reason, madeRoomFor (a place, with reason "madeRoom"),
--     cards, plate (Recap.Plates', where it is one), spare (its place among
--     the spare, best first), lead (the moment a keep is written on) }
--   a card = { row = "card", key, kind, t, moment, place, on, look, reason }
--     one for every moment of the place, in time order: a person's moment, a
--     feature's card, a map mark (arrive, stay, level, ...)
--
-- Looks: `diary` (a faded tick: on the page, the diary's pick), `diaryOff`
-- (an empty box: the diary left it off), `keep` (a red tick: the player's; a
-- moment kept, or a card they wrote or changed, Core/Custom.lua, and the place
-- holding one), `out` (a red cross: left out by the player; a place, when
-- every moment it holds is).
--
-- Reasons, for a row not on the page: `next` (the best spare place, next in
-- line), `noRoom` (the other spare places), `madeRoom` (the place a keep took
-- the place of, Tick: `madeRoomFor` the kept one; remembered until another
-- keep, not saved), `minor` (a place whose moments open no plate of their own:
-- a second stay in a zone shown, filler, a level's pin; keeping it opens one),
-- `marginRoom` (a card on a place on the page the margin had no room for:
-- UI/Journey/Margin.lua's plate.leftOff on the plan), `byYou` (left out by the
-- player). A card on a place off the page has its place's reason.
--
-- The places: the page's (e.plates, where UI/Journey/Layouts.lua's PlatesOf
-- drew this piece: its plates, grouped at e.cover, with their margins' left
-- off), else Recap.Plates' at `cover`; then `plates.spare`; then the moments
-- that are in no place there (Plates' `loose`, the ones the player left out,
-- and the cards hidden through Core/Custom.lua listed in e.hidden), each into
-- the first place it fits at `cover`'s window (Recap.Fits, as Plates groups:
-- one left out goes back to the place it was on, where it still fits), else
-- grouped into places of their own the same way, best rank first. A door that
-- is only a door (Plates drops it where its run was recorded) is not listed:
-- the run has its page, and keeping the door would not bring it back.

local Recap = ns.JourneyRecap

-- The last keep that took another place's room (Tick), for "made room for":
-- { from (the piece's start), kept (its place's keys), bumped (the bumped
-- place's) }. Not saved: a reload forgets it, and the line with it.
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

function Recap.Choices(j, e, ctx, cover)
    ctx = ctx or {}
    local plates = e.plates
    if plates and plates.spare then
        cover = e.cover or cover
    else
        plates = Recap.Plates(j, e, ctx, cover)
    end
    local PLATES = Recap.PLATES
    local function Window(mapID)
        local w, h
        if cover then w, h = cover(mapID) end
        return w or PLATES.window, h or PLATES.window
    end

    local places = {}
    local function Place(plate, on)
        local place = { row = "place", plate = on ~= nil and plate or nil, mapID = plate.mapID, t = plate.t,
            on = on == true, cards = {}, x0 = plate.x0, x1 = plate.x1, y0 = plate.y0, y1 = plate.y1 }
        places[#places + 1] = place
        return place
    end
    local function Card(place, m)
        place.cards[#place.cards + 1] = { row = "card", key = Chosen.Key(m), kind = m.kind, t = m.t, moment = m,
            place = place }
        place.t = math.min(place.t or m.t, m.t)
    end
    for _, plate in ipairs(plates) do
        local place = Place(plate, true)
        for _, m in ipairs(plate.moments) do Card(place, m) end
    end
    for i, plate in ipairs(plates.spare or {}) do
        local place = Place(plate, false)
        place.spare = i
        for _, m in ipairs(plate.moments) do Card(place, m) end
    end

    -- The rest, each into a place it fits, else one of their own.
    local rest = {}
    for _, m in ipairs(plates.loose or {}) do rest[#rest + 1] = m end
    if j and j.chosen then
        for _, m in ipairs(Recap.Moments(j, e, ctx, true)) do
            if m.chosen == OUT then rest[#rest + 1] = m end
        end
    end
    for _, h in ipairs(e.hidden or {}) do
        local m = h.rec and Hidden(j, h)
        if m then rest[#rest + 1] = m end
    end
    table.sort(rest, function(a, b)
        local ra, rb = Recap.Rank(a), Recap.Rank(b)
        if ra ~= rb then return ra < rb end
        return a.t < b.t
    end)
    for _, m in ipairs(rest) do
        local w, h = Window(m.mapID)
        local into
        for _, place in ipairs(places) do
            if Recap.Fits(place, m, w, h) then
                into = place
                break
            end
        end
        if not into then
            into = Place({ mapID = m.mapID, t = m.t, x0 = m.x, x1 = m.x, y0 = m.y, y1 = m.y })
            into.minor = true
        elseif not into.plate then
            into.x0, into.x1 = math.min(into.x0, m.x), math.max(into.x1, m.x)
            into.y0, into.y1 = math.min(into.y0, m.y), math.max(into.y1, m.y)
        end
        Card(into, m)
    end

    -- What the margins had no room for (plate.leftOff, on the page's plans).
    local unwritten = {}
    for _, plate in ipairs(plates) do
        for _, it in ipairs(plate.leftOff or {}) do
            for _, m in ipairs(it.moments or {}) do unwritten[m] = true end
        end
    end

    local choices = { places = places, max = PLATES.max, mine = 0, diary = 0 }
    local bumped, keptAt = {}, nil
    if last and last.from == e.from then
        for _, place in ipairs(places) do
            for _, c in ipairs(place.cards) do
                if last.bumped[c.key] then bumped[place] = true end
                if place.on and last.kept[c.key] then keptAt = place end
            end
        end
    end
    local nextGiven = false
    for _, place in ipairs(places) do
        table.sort(place.cards, function(a, b)
            if a.t ~= b.t then return a.t < b.t end
            return a.key < b.key
        end)
        local mine, out, lead = false, true, nil
        for _, c in ipairs(place.cards) do
            local m = c.moment
            local of = Chosen.Of(j, m)
            if of == OUT or m.chosen == OUT then
                c.look, c.reason = "out", "byYou"
            else
                out = false
                if Mine(m) then
                    c.look, mine = "keep", true
                end
            end
        end
        -- (the lead of what it shows; of all it held, where it shows nothing)
        local held = {}
        for _, c in ipairs(place.cards) do
            if out or c.look ~= "out" then held[#held + 1] = c.moment end
        end
        place.lead = Chosen.Lead({ moments = held })
        place.key = place.lead and Chosen.Key(place.lead) or ("place:%d:%s"):format(place.t or 0, tostring(place.mapID))
        if place.on then
            place.look = mine and "keep" or "diary"
            if mine then choices.mine = choices.mine + 1 else choices.diary = choices.diary + 1 end
        elseif out then
            place.look, place.reason = "out", "byYou"
        else
            place.look = mine and "keep" or "diaryOff"
            if bumped[place] and keptAt then
                place.reason, place.madeRoomFor = "madeRoom", keptAt
            elseif place.spare and not nextGiven then
                place.reason, nextGiven = "next", true
            elseif place.spare then
                place.reason = "noRoom"
            else
                place.reason = "minor"
            end
        end
        for _, c in ipairs(place.cards) do
            if not c.look then
                if not place.on then
                    c.look, c.reason = "diaryOff", place.reason
                elseif unwritten[c.moment] then
                    c.look, c.reason = "diaryOff", "marginRoom"
                else
                    c.look = "diary"
                end
            elseif c.look == "keep" and not place.on then
                c.reason = place.reason
            end
            c.on = place.on and (c.look == "diary" or c.look == "keep")
        end
    end
    table.sort(places, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return a.key < b.key
    end)
    choices.full = #plates >= PLATES.max and choices.mine >= PLATES.max
    return choices
end

-- A row of Recap.Choices' ticked (.claude/features/choose-page.md): one on
-- the page (`on`) is left out, one off it is kept. Returns { did = "out" |
-- "keep" }, or { blocked = true } where a place would be kept onto a page
-- whose three places are all the player's already: nothing written, the
-- ticklist says why. Keeping a place onto a full page moves the diary's
-- weakest off (the ranks do it: a keep outranks any of the diary's); which
-- one went is remembered for its "made room for" line (`bumped`, also
-- returned: the place row it was).
--
-- A place left out: `out` on every moment it shows. A place kept: `keep` on
-- its lead; one the player had left out whole comes back whole (the rest of
-- its moments to the diary's, a hidden card shown). A card: its own moment
-- (Keep, Leave). `j` as Keep's; ctx and cover as Recap.Choices'.
function Chosen.Tick(j, e, ctx, cover, row)
    j = Route(j)
    if not (j and e and row) then return nil end
    local place = row.row == "place" and row or row.place
    local before = Recap.Choices(j, e, ctx, cover)
    if row.on then
        if row.row == "place" then
            local list = {}
            for _, c in ipairs(row.cards) do
                if c.look ~= "out" then list[#list + 1] = c.moment end
            end
            Chosen.LeavePlace(j, { moments = list })
        else
            Chosen.Leave(j, row.moment)
        end
        return { did = OUT }
    end
    if not place.on and before.full then return { blocked = true } end
    if row.row == "place" then
        local lead = row.lead
        if not lead then return nil end
        if row.look == "out" then
            for _, c in ipairs(row.cards) do
                if c.moment ~= lead then Clear(j, c.moment) end
            end
        end
        Chosen.Keep(j, lead)
    else
        Chosen.Keep(j, row.moment)
    end
    local result = { did = KEEP }
    if not place.on then
        -- Which of the page's places went: the one none of whose moments is
        -- on the page now (the diary's weakest, as the ranks put it).
        local after, now = Recap.Plates(j, e, ctx or {}, e.cover or cover), {}
        for _, plate in ipairs(after) do
            for _, m in ipairs(plate.moments) do now[Chosen.Key(m)] = true end
        end
        for _, other in ipairs(before.places) do
            local stays = false
            for _, c in ipairs(other.on and other.cards or {}) do stays = stays or now[c.key] == true end
            if other.on and not stays then
                local kept, gone = {}, {}
                for _, c in ipairs(place.cards) do kept[c.key] = true end
                for _, c in ipairs(other.cards) do gone[c.key] = true end
                last = { from = e.from, kept = kept, bumped = gone }
                result.bumped = other
                break
            end
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
