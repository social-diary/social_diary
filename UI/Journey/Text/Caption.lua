-- What is written beside a plate in Your Diary (ns.UI.JourneyText): its
-- heading by hand (Text.PlateHeading) and its few words (Text.PlateCaption),
-- the diary's own leads and every kind's registered words
-- (Text.RegisterCaption, from Features/<Name>/Text.lua). The words are
-- written again and again as UI/Journey/Caption.lua fits the margin, so the
-- helpers are this file's locals, taken as it loads.
--
-- The module and its siblings: UI/Journey/Text/Grammar.lua.

local addonName, ns = ...

local Format = ns.UI.Format

local Text = ns.UI.JourneyText
local List = Format.List
local Spoken, Capital, MapName, Day = Text.Spoken, Text.Capital, Text.MapName, Text.Day
local Duration, NUMBER, Short = Text.Duration, Text.NUMBER, Text.Short
local L, Fmt = ns.L, ns.Fmt

-- "today", "yesterday", "Tuesday", or "4 October" past a week: the day a
-- plate's caption names, as it reads after a comma.
local function PlateDay(t, now)
    local label = Format.DayLabel(t, now)
    if label == L["Today"] then return L["today"] end
    if label == L["Yesterday"] then return L["yesterday"] end
    if now - t < 6 * ns.DAY then return Format.Weekday(t) end
    return Day(t, now)
end

-- "Mulgore, yesterday": the plate's heading, written by hand beside it as
-- under a photograph in an album. Returns the zone and the day too, for a
-- column too narrow for both on one line. A plate the same day as the one
-- `before` it on the page counts on from it instead of saying the day
-- again: "Forty-five minutes later", and ", in The Barrens" when the zone
-- changed.
function Text.PlateHeading(plate, now, before)
    now = now or ns.Now()
    local zone = MapName(plate.mapID) or L["Somewhere"]
    if before and before.t and plate.t and plate.t >= before.t
        and ns.DayStart(plate.t) == ns.DayStart(before.t) then
        local later = Fmt(L["%s later"], Spoken(plate.t - before.t))
        if plate.mapID == before.mapID then return Capital(later), Capital(later), nil end
        return Fmt(L["%1$s, in %2$s"], Capital(later), zone), zone, later
    end
    local day = PlateDay(plate.t, now)
    return Fmt(L["%1$s, %2$s"], zone, day), zone, day
end

--------------------------------------------------------------------------
-- A plate's words (Text.PlateCaption) and the kinds that add to them
-- (Text.RegisterCaption)
--------------------------------------------------------------------------

-- A few words under a plate (JRN-21): what put it there, never a list.
-- The left page already tells the story; this only names the place.
-- They are three parts, in this order. The lead, the clause they open
-- with: "With Koko", "A first green: Wolfskin Bracers", "Into Mulgore for
-- the first time". The tail, what else happened there, after it and as
-- short as it: ", a first bag, and two deaths". And a coda, a sentence of
-- its own after the full stop: "Grisha mercilessly watched you die."
--
-- What is the diary's own is written here: the people you were with
-- (who no margin note names), fights with strangers, the first visit to a
-- zone, a dungeon's door, a long stay, the company a note names already,
-- the level reached, and "On the road" when there is nothing else (LEADS,
-- below). The level is said only when nothing else is ("Level 9."): the
-- rubric names it already, and the words are for what happened. Every
-- other kind of moment with words of its own registers them
-- (Text.RegisterCaption), so a feature's file (Features/<Name>/, loaded
-- after UI/) adds to every plate's words without this file knowing of it
-- (.claude/registry-refactor.md, phase 4).
--
-- The lead is the first in the order of `at` that has something to say;
-- the diary's leads are numbered by hand here and a kind's slot in
-- between by its number. The diary's: people 10, fights 45 (strangers),
-- arrive 100, dungeon 110, stay 120, company 130, level 150, and "On
-- the road" after all; a kind registered from Features/<Name>/ says its
-- number there. At equal numbers the diary's lead goes
-- first, then the kinds in the order they registered. A kind is asked
-- for its lead only when it gathered something.
-- The tail is every kind's words in the order of its tail's `at` (the
-- features' own), less the lead's own kind, which has said itself. A kind
-- ahead of the lead in the chain had nothing to say (or it would have
-- led), so nothing more is left out: a lead that passes has no tail words
-- either (a kind whose card shows it all). "X, and Y"; "X, Y, and Z".
--
-- `spec` (Text.RegisterCaption(key, spec)), `key` the kind's name, which
-- is also its key in `said` and in `c.lists`, and what `c.lead` is while
-- it leads; never one of the diary's own (LEADS' keys, "road"):
--   moment   the kind of plate.moments it gathers, in the plate's order,
--            for its lead and tail. None for a kind with a coda alone
--            (one the margin tells it of).
--   take     optional function(m, said) → what of the moment it keeps
--            (m.call, ...); nil to leave it out (what its card
--            tells). The moment itself where not given.
--   lead     optional { at, say = function(list, c) → text, rest }: its
--            opening clause, capitalised, no full stop; nil to let the
--            next lead have it. `rest` (optional, a list of words) goes in
--            its own place in the tail: a lead may say the first of its
--            list, its tail place the others.
--   tail     optional { at, say = function(list, c) → words }: a phrase
--            or a list of them, lower case, nil for none. Asked only when
--            it gathered something, and never when its own lead led.
--   coda     optional { at, say = function(c) → sentence }: a whole
--            sentence after the words' full stop; nil for none.
-- `c`, the words being written: plate, began, said, named (said.named or
-- {}), of (the first moment of each kind there), lists (each kind's
-- gathered list, by key) and, from the lead on, lead (the key of the one
-- that led: a kind's, or "people", "fights", "arrive", "dungeon", "stay",
-- "company", "level", "road").
--
-- `began` (optional) is when the road began, so the very first place
-- reads as where the diary began. `said` (optional) is what the margin
-- beside the plate tells already (UI/Journey/Margin.lua, its kinds'
-- JourneyMargin `assume` and `say`), for the words not to tell it again:
-- `named` is who its notes name, [guid] = true for each, and `someone`,
-- how many strangers' notes there are ("With Tester." is not written
-- beside Tester's own note; "In good company." is). Every other key is a
-- kind's, by its key, and means what that kind says it does (the
-- features' own: their Text.lua says theirs).
-- The kinds sorted into their places (Chain), built when first asked
-- after a kind registered or left.
local chain

-- The diary's own leads, in their order (`at`), each say(c) → its clause
-- or nil. Kinds slot in between by number (Text.RegisterCaption).
local LEADS = {
    -- Who you were with that no note beside the plate names.
    { at = 10, key = "people", say = function(c)
        if #c.people == 0 then return nil end
        return Fmt(L["With %s"], List(c.people, { max = 3, shown = 2, more = L["others"] }))
    end },
    -- Fights with strangers no note tells: "A fight, won", "Two fights".
    { at = 45, key = "fights", say = function(c)
        local strangers = c.strangers
        if #strangers == 0 then return nil end
        if #strangers == 1 then return strangers[1].outcome == "won" and L["A fight, won"] or L["A fight, lost"] end
        return Fmt(L["%s fights"], Capital(NUMBER[#strangers] or tostring(#strangers)))
    end },
    { at = 100, key = "arrive", say = function(c)
        local arrive = c.of.arrive
        if not arrive then return nil end
        if c.began and arrive.t <= c.began then return L["Where the diary began"] end
        local zone = MapName(c.plate.mapID)
        if not zone then return L["Into a new zone for the first time"] end
        return Fmt(L["Into %s for the first time"], zone)
    end },
    { at = 110, key = "dungeon", say = function(c)
        local dungeon = c.of.dungeon
        if not dungeon then return nil end
        if not dungeon.name then return L["The way into a dungeon"] end
        return Fmt(L["The way into %s"], dungeon.name)
    end },
    { at = 120, key = "stay", say = function(c)
        local stay = c.of.stay
        if not stay then return nil end
        local seg = stay.seg
        local text = seg.subZone and seg.subZone ~= MapName(seg.mapID) and seg.subZone or L["A long stay"]
        return Fmt(L["%1$s, %2$s"], text, Duration(stay.seconds or seg.seconds or 0))
    end },
    -- Someone a note beside the plate names already: what you did together
    -- is said, never who.
    { at = 130, key = "company", say = function(c)
        if c.company == "fight" then return L["Where the fighting was"] end
        if c.company then return L["In good company"] end
        return nil
    end },
    { at = 150, key = "level", say = function(c)
        return c.of.level and Fmt(L["Level %d"], c.of.level.level) or nil
    end },
}
local ROAD = L["On the road"]

-- The kinds, in the order they registered: each sorts into the lead,
-- the tail and the codas by its own `at` there (Chain), so the registry
-- keeps them by name and turn only.
local LEAD_KEYS = { road = true }
for _, lead in ipairs(LEADS) do LEAD_KEYS[lead.key] = true end
local captionKinds = ns.Registry.New({
    what = "Text.RegisterCaption(key, { moment, lead = { at, say }, tail = { at, say }, coda = { at, say } })",
    key = "key",
    check = function(key, spec)
        if not (spec.lead or spec.tail or spec.coda) then return false end
        if LEAD_KEYS[key] then return false, "Text.RegisterCaption: a kind may not be called " .. key end
        return true
    end,
    changed = function() chain = nil end,
})
local CAPTIONS, CAPTION_LIST = captionKinds.specs, captionKinds:Ordered()

function Text.RegisterCaption(key, spec)
    return captionKinds:Add(key, spec)
end

-- Takes a kind's words off every plate again (a feature switched off, a
-- test's own kind).
function Text.RemoveCaption(key)
    captionKinds:Remove(key)
end
-- For the tests: the registered kinds.
Text.CAPTIONS = CAPTIONS

-- By `at`, then the diary's own before a kind's (rank -1 and 0, as the
-- registry ranks its core entries), then their turn: the diary's in
-- LEADS' order, a kind's as it registered.
local function ByAt(a, b)
    if a.at ~= b.at then return a.at < b.at end
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.seq < b.seq
end

local function Chain()
    if chain then return chain end
    chain = { leads = {}, tails = {}, codas = {}, moments = {} }
    for i, lead in ipairs(LEADS) do
        chain.leads[#chain.leads + 1] = { at = lead.at, rank = -1, seq = i, key = lead.key, say = lead.say }
    end
    for _, spec in ipairs(CAPTION_LIST) do
        if spec.lead then
            chain.leads[#chain.leads + 1] = { at = spec.lead.at, rank = 0, seq = spec.seq, key = spec.key, spec = spec }
        end
        if spec.tail then
            chain.tails[#chain.tails + 1] = { at = spec.tail.at, rank = 0, seq = spec.seq, spec = spec }
        end
        if spec.coda then
            chain.codas[#chain.codas + 1] = { at = spec.coda.at, rank = 0, seq = spec.seq, spec = spec }
        end
        if spec.moment then
            local list = chain.moments[spec.moment] or {}
            chain.moments[spec.moment] = list
            list[#list + 1] = spec
        end
    end
    table.sort(chain.leads, ByAt)
    table.sort(chain.tails, ByAt)
    table.sort(chain.codas, ByAt)
    return chain
end

local NONE = {}

function Text.PlateCaption(plate, began, said)
    said = said or {}
    local named = said.named or {}
    local someone = named.someone or 0
    local C = Chain()
    local of, people, strangers, lists = {}, {}, {}, {}
    local c = { plate = plate, began = began, said = said, named = named, of = of, people = people,
        strangers = strangers, lists = lists }
    for _, spec in ipairs(CAPTION_LIST) do lists[spec.key] = {} end
    for _, m in ipairs(plate.moments) do
        for _, spec in ipairs(C.moments[m.kind] or NONE) do
            local kept = m
            if spec.take then kept = spec.take(m, said) end
            if kept then
                local list = lists[spec.key]
                list[#list + 1] = kept
            end
        end
        of[m.kind] = of[m.kind] or m
        if (m.kind == "session" or m.kind == "note" or m.kind == "first" or m.kind == "fight") then
            if m.guid and ns.Diary.IsDiary(m.guid) then
                local name = Short(m.guid)
                if named[m.guid] then
                    c.company = c.company or m.kind
                elseif name and not people[name] then
                    people[name] = true
                    people[#people + 1] = name
                end
            elseif m.kind == "fight" then
                if (m.guid and named[m.guid]) or (not m.guid and someone > 0) then
                    if not m.guid then someone = someone - 1 end
                    c.company = c.company or "fight"
                else
                    strangers[#strangers + 1] = m
                end
            end
        end
    end

    -- The lead: the first in the chain with something to say.
    local text, rest
    for _, lead in ipairs(C.leads) do
        local clause, more
        if lead.spec then
            local list = lists[lead.key]
            if #list > 0 then clause, more = lead.spec.lead.say(list, c) end
        else
            clause = lead.say(c)
        end
        if clause then
            text, rest, c.lead = clause, more, lead.key
            break
        end
    end
    if not text then text, c.lead = ROAD, "road" end

    -- What else happened there, each kind in its tail place.
    local tail = {}
    local function Put(words)
        if type(words) == "table" then
            for _, w in ipairs(words) do tail[#tail + 1] = w end
        elseif words then
            tail[#tail + 1] = words
        end
    end
    for _, t in ipairs(C.tails) do
        local spec = t.spec
        if spec.key == c.lead then
            Put(rest)
        else
            local list = lists[spec.key]
            if #list > 0 then Put(spec.tail.say(list, c)) end
        end
    end
    -- The tail is a list, joined as a list is ("X, and Y"; "X, Y, and Z"):
    -- the lead and each phrase after it are whole units.
    if #tail == 1 then
        text = text .. L[", and "] .. tail[1]
    elseif #tail > 1 then
        text = text .. L[", "] .. table.concat(tail, L[", "], 1, #tail - 1) .. L[", and "] .. tail[#tail]
    end
    -- No second full stop after one a translation's abbreviation brings
    -- ("20 Min."); the English words never end in one.
    if text:sub(-1) ~= "." then text = Fmt(L["%s."], text) end
    for _, coda in ipairs(C.codas) do
        local sentence = coda.spec.coda.say(c)
        if sentence then text = text .. " " .. sentence end
    end
    return text
end
