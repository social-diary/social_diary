-- An entry's prose in Your Diary (ns.UI.JourneyText): the prologue, the
-- rubric's title, the paragraphs in their order (the diary's own: the
-- opening, where the time went, who was there; and each kind's, registered
-- with Text.RegisterLines from Features/<Name>/Text.lua), "so far", and
-- the line for a first sighting in hindsight.
--
-- The module and its siblings: UI/Journey/Text/Grammar.lua.

local addonName, ns = ...

local Text = ns.UI.JourneyText
local List = ns.UI.Format.List
local Spoken, Capital, MapName, Who = Text.Spoken, Text.Capital, Text.MapName, Text.Who
local Day, Place, Short = Text.Day, Text.Place, Text.Short
local Upper = Text.Upper
local L, Fmt = ns.L, ns.Fmt

--------------------------------------------------------------------------
-- The prologue (JRN-13)
--------------------------------------------------------------------------

-- "This diary began at level 30, in Ashenvale." Nothing before it is
-- made up.
function Text.Prologue(prologue)
    if not prologue then return nil end
    local zone = MapName(prologue.mapID)
    if zone then
        return Fmt(L["This diary began at level %1$d, in %2$s, on %3$s."], prologue.level, zone, Day(prologue.at))
    end
    return Fmt(L["This diary began at level %1$d, on %2$s."], prologue.level, Day(prologue.at))
end

--------------------------------------------------------------------------
-- An entry (JRN-11, JRN-12)
--------------------------------------------------------------------------

-- "LEVEL 12", "WEEK OF 6 OCTOBER": the rubric over the entry, written in
-- sentence case and set in capitals here (the copywriter's §4).
function Text.Title(e, now)
    if e.kind == "week" then
        return Upper(Fmt(L["Week of %s"], Day(e.week, now)))
    end
    return Upper(Fmt(L["Level %d"], e.level))
end

-- How the entry opens: where and when it began.
local function Opening(e, now)
    if e.kind == "week" then
        local r = e.reached
        if r then
            local where = r.dungeon or Place(r.mapID, r.subZone)
            if where then
                return Fmt(L["Reached level %1$d in %2$s, on %3$s. The road goes on."], e.level or 0, where,
                    Day(r.at, now))
            end
            return Fmt(L["Reached level %1$d, on %2$s. The road goes on."], e.level or 0, Day(r.at, now))
        end
        return nil
    end
    if not e.known then return nil end
    if e.first then
        local place = e.places[1] and (e.places[1].name or MapName(e.places[1].mapID))
        if place then return Fmt(L["Your road begins here, on %1$s, in %2$s."], Day(e.from, now), place) end
        return Fmt(L["Your road begins here, on %s."], Day(e.from, now))
    end
    local r = e.reached
    if not r then return nil end
    local where = r.dungeon or Place(r.mapID, r.subZone)
    if where then return Fmt(L["Reached on %1$s in %2$s."], Day(r.at, now), where) end
    return Fmt(L["Reached on %s."], Day(r.at, now))
end

-- The zones and their times are not told here: the ledger under the entry
-- (the zone rows) carries them, a dungeon's row marked with its doorway.
-- The prose keeps what is a story: where the time went, who was there.

-- Where the longest stops' time went, as a diary puts it, in a sentence or
-- two that vary from entry to entry so a long road does not read as a log.
-- The stops come in the order made. `first`: the earliest, by what was done
-- there, two ways of saying it, each a whole sentence taking the same three
-- values (%1$s the time spoken and capitalised, %2$s as is, %3$s the place),
-- of which it uses those it needs, so a translation can put them where
-- its own sentence wants them. `later`: the stops after it, named (%s),
-- with their deed only where it differs from the first's, listed in one
-- of the `openers`' sentences.
local STOPS = {
    first = {
        fighting = { L["%1$s of fighting at %3$s."], L["%3$s kept you fighting for %2$s."] },
        questing = { L["%1$s of quests round %3$s."], L["Quests kept you at %3$s for %2$s."] },
        resting = { L["%1$s resting at %3$s."], L["You rested %2$s at %3$s."] },
        none = { L["%1$s at %3$s."], L["You lingered at %3$s for %2$s."] },
    },
    later = { fighting = L["fighting near %s"], questing = L["quests at %s"], resting = L["a rest at %s"] },
    openers = { L["Later, %s."], L["Then %s."], L["After that, %s."] },
}

-- Which way an entry says it: the same every time for the same entry, and
-- different from its neighbours.
local function Seed(e)
    return (e.level or 0) + math.floor((e.week or 0) / ns.DAY)
end

local function Stops(e)
    local first = e.stops[1]
    if not first then return nil end
    local seed = Seed(e)
    local where = first.seg.subZone or MapName(first.seg.mapID)
    if not where then return nil end
    local ways = STOPS.first[first.main or "none"] or STOPS.first.none
    local d = Spoken(first.seconds)
    local text = Fmt(ways[seed % #ways + 1], Capital(d), d, where)

    local later, seen = {}, { [where] = true }
    for i = 2, #e.stops do
        local stop = e.stops[i]
        local name = stop.seg.subZone
        if name and not seen[name] then
            seen[name] = true
            local deed = stop.main ~= first.main and stop.main and STOPS.later[stop.main]
            later[#later + 1] = deed and Fmt(deed, name) or name
        end
    end
    if #later > 0 then
        text = text .. " " .. Fmt(STOPS.openers[seed % #STOPS.openers + 1], List(later))
    end
    return text
end

-- "Flew to Orgrimmar." The places, not how many.
local function Flights(e)
    local names, seen = {}, {}
    for _, seg in ipairs(e.flights) do
        local name = MapName(seg.mapID2)
        if name and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    local list = List(names, { max = 3, shown = 2 })
    return list and Fmt(L["Flew to %s."], list) or nil
end

-- "With Tester Testerson for four hours and Kaelith Dawnsong briefly."
local PEOPLE = { max = 4, shown = 3, more = L["others"] }
-- On Text too, for the meeting's tooltip (UI/Journey/Text/Tips.lua) to
-- list people the same way.
Text.PEOPLE = PEOPLE

local function People(e)
    local parts = {}
    for _, person in ipairs(e.people) do
        local name = Who(person.guid)
        if name then
            parts[#parts + 1] = person.seconds >= 300 and Fmt(L["%1$s for %2$s##with"], name, Spoken(person.seconds))
                or Fmt(L["%s briefly"], name)
        end
    end
    local list = List(parts, PEOPLE)
    return list and Fmt(L["With %s."], list) or nil
end

-- A fight in a few words. A stranger the buffer has let go is "a fight",
-- and how it ended (JRN-10).
function Text.Fight(mark, index)
    local guid = ns.Journey.FightWho(mark, index)
    local name = guid and Who(guid)
    if mark.outcome == "won" then
        return name and Fmt(L["beat %s"], name) or L["won a fight"]
    end
    return name and Fmt(L["lost to %s"], name) or L["lost a fight"]
end

local function Fights(e, index)
    local parts = {}
    for _, mark in ipairs(e.fights) do parts[#parts + 1] = Text.Fight(mark, index) end
    local list = List(parts, { max = 4, shown = 3, more = L["more"] })
    if not list then return nil end
    return Fmt(L["%s."], Capital(list))
end

-- Two sentences as one paragraph, either may be missing.
local function Join(a, b)
    if a and b then return a .. " " .. b end
    return a or b
end

-- A quiet stretch still says something, briefly.
local function Quiet(e)
    if e.kind == "week" then return nil end
    if e.seconds <= 0 then return L["Nothing on the road at this level."] end
    return nil
end

-- The entry's paragraphs in the diary's voice (Text.Lines), in order: the
-- opening (where and when it began), where the time went (the stops, the
-- flights), who was there (people, fights), then each kind's paragraph in
-- its place, and a word for a quiet stretch where there is no more than
-- the opening. The player's own note is not among them: Text.Note gives
-- it, to be set in their hand. `index` is Journey.FightIndex's, built
-- once per page.
--
-- What is the diary's own is written here (PARAGRAPHS, numbered by hand).
-- Every other kind with a paragraph of its own registers it
-- (Text.RegisterLines), so a feature's file (Features/<Name>/, loaded
-- after UI/) adds to every entry's prose without this file knowing of it
-- (.claude/skills/new-feature/folder.md). Today's: the
-- diary's opening 10, time 20, people 30; a kind registered from
-- Features/<Name>/ says its number there. Leave gaps. At
-- equal numbers the diary's paragraph goes first, then the kinds in the
-- order they registered.
--
-- `spec` (Text.RegisterLines(key, spec)), `key` the kind's name, never one
-- of PARAGRAPHS' keys; registering a key again replaces it:
--   at      its place among the paragraphs
--   lines   function(e, now, index) → its paragraph (its sentences joined
--           by a space), or nil where it has nothing to say: e the entry
--           (its gathered lists, by the recap moment's `entry`), now and
--           index as Text.Lines has them
--   run     optional: the name of a paragraph several kinds write
--           together ("combat": the fights' paragraph, which more than
--           one feature writes). The first of them with something to
--           say starts it, in its place; each after it with something to
--           say runs on in it, after a space, rather than starting one
--           of its own. So kinds told as one paragraph can live apart.
local PARAGRAPHS = {
    { at = 10, key = "opening", lines = function(e, now) return Opening(e, now) end },
    { at = 20, key = "time", lines = function(e) return Join(Stops(e), Flights(e)) end },
    { at = 30, key = "people", lines = function(e, now, index) return Join(People(e), Fights(e, index)) end },
}
-- The diary's paragraphs are the registry's core entries, first among
-- the kinds at their numbers; Ordered() is every paragraph in its place,
-- sorted again only when a kind registers or leaves.
local paragraphKinds = ns.Registry.New({
    what = "Text.RegisterLines(key, { at, lines = function(e, now, index) ... })",
    key = "key", order = "at",
    check = function(key, spec) return type(spec.at) == "number" and type(spec.lines) == "function" end,
})
for _, p in ipairs(PARAGRAPHS) do paragraphKinds:Core(p.key, p, -1) end

function Text.RegisterLines(key, spec)
    return paragraphKinds:Add(key, spec)
end

-- Takes a kind's paragraph out of every entry's prose again (a test's own
-- kind).
function Text.RemoveLines(key)
    paragraphKinds:Remove(key)
end

-- Every paragraph in its order, the diary's and the kinds': { at, key,
-- lines, run }. For the tests too.
function Text.Paragraphs()
    return paragraphKinds:Ordered()
end

function Text.Lines(e, now, index)
    local lines, runs = {}, {}
    for _, p in ipairs(Text.Paragraphs()) do
        local text = p.lines(e, now, index)
        local at = text and p.run and runs[p.run]
        if at then
            lines[at] = lines[at] .. " " .. text
        elseif text then
            lines[#lines + 1] = text
            if p.run then runs[p.run] = #lines end
        end
    end
    if #lines <= 1 then
        local quiet = Quiet(e)
        if quiet then lines[#lines + 1] = quiet end
    end
    return lines
end

-- "so far" under the level being played now.
function Text.Current(e)
    return e.current and L["so far"] or nil
end

-- JRN-23: the line under a level's prose for a first sighting in
-- hindsight. "You first saw Koko in Mulgore. You'd meet again at level 4."
function Text.Hindsight(f)
    local name = Short(f.guid) or L["someone##whom"]
    local zone = MapName(f.mapID)
    local line = zone and Fmt(L["You first saw %1$s in %2$s."], name, zone) or Fmt(L["You first saw %s."], name)
    if f.metLevel and f.level and f.metLevel > f.level then
        return line .. " " .. Fmt(L["You'd meet again at level %d."], f.metLevel)
    end
    return line .. " " .. L["You'd meet again before the level was out."]
end
