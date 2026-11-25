-- City trips: one visit to a capital, kept as what the player did there,
-- the errands run in town (.claude/features/city-trips.md). A feature in a
-- folder of its own (.claude/skills/new-feature/folder.md):
--
--   Kind.lua     what a trip is to the diary: the route's list (j.trips),
--                the record field by field, its writers (which merge as a
--                trip grows, so a heavy one stays small), its readers, and
--                what forgetting someone and the login's pruning take off
--                it
--   Capture.lua  the trip's life (opened on arriving in a city, closed on
--                leaving it, kept across a /reload) and the errands, each
--                from the client's own signal: the auction house, the
--                mailbox, the "You create" line, the professions' ranks,
--                recipes learnt, quests taken and handed in, the purse
--   Dev.lua      its part of /sd testdata: three trips on the made-up
--                route's Orgrimmar stops, a thin one, a usual one and a
--                heavy one (never packaged)
--   Text.lua     the sheet's words, every line in its full and folded
--                forms (.claude/ui-proposal/city-trips-copy.md), the
--                ticklist row's words and the tooltips
--   Sheet.lua    the sheet itself: the round laid down the leaf's two
--                halves on a pen thread, a small drawing at each stop, the
--                purse last, folded only where the leaf would overflow;
--                its three drawings (a letter, a lot's tag, a coin)
--
-- The moment ("trip", at this file's foot) is told on a sheet, not on a
-- map: a half-page leaf among the plates (the core's sheet hook,
-- Core/JourneyRecap.lua's RegisterMoment `sheet`, UI/Journey/Sheet.lua).
-- No mark: a sheet's kind has a drawer instead (tests/kinds.lua).
--
-- Everything is registered into the core's registries, so no file outside
-- this folder names a trip. Its own names are on ns.CityTrips, made here,
-- the first of its files the TOC loads.
--
-- What stays core, because it is the diary's substrate and not this
-- feature's detection:
--   - what a city is (ns.City, Core/Location.lua: the settings' city list,
--     SIG-5), and the route's own city stop (Core/Journey.lua: one stop a
--     visit, "Cities take no breadcrumbs"), which tells the same visit as
--     a place and a span; a trip keeps its own span from ns.City and is
--     matched to the stop by time, not by a shared record;
--   - a sitting's gap (ns.Sittings.GAP, Core/Sittings.lua), which says how
--     long away ends a trip as it ends an evening;
--   - quests taken and handed in, counted by the route and passed on as
--     SD_QUEST_ACCEPTED / SD_QUEST_TURNED_IN (Capture/Journey.lua,
--     Core/Events.lua's header);
--   - who the diary knows (ns.db.characters, Characters.FindByName,
--     ns.OwnCharacters): a name read off a letter or an invoice becomes a
--     GUID only through them, and never stays a name;
--   - the route's gate (Journey.Kept), its list and cap (Journey.Append),
--     its login pruning (Journey.Prune) and forgetting someone (the
--     "journey" store), which ask this list's `prune` and `forget`
--     (Journey.RegisterList).
--
-- Additive saved data only: j.trips is a new list on the route, absent on
-- every route kept before it, and every reader here takes its absence as
-- no trips. Nothing older is moved or reread, so there is no schema bump
-- (AGENTS.md).

local addonName, ns = ...

local CityTrips = {}
ns.CityTrips = CityTrips

local Journey = ns.Journey

-- The numbers, to tune once the client round has real trips. Counts are
-- entries on one trip's list; times are seconds.
local T = {
    cap = 200,      -- trips kept a character, the newest (the user's own
                    -- route: 56 city visits in 55 hours, 31 of them five
                    -- minutes or longer, 24 Nov; empty ones are dropped)
    items = 6,      -- things on an item list (put up, bought, sold, made),
                    -- one entry a kind of thing; past it, a last entry
                    -- carries the rest as counts
    people = 4,     -- entries on a list of letters (taken, sent), one a
                    -- person and one for all the unknown; past it, likewise
    who = 3,        -- people named on one entry (buyers, sellers, the party
                    -- on a quest); past it, or not known, they are counted
    quests = 8,     -- quests on the list, taken and handed in together
    skills = 6,     -- professions that climbed (a character has few)
    recipes = 8,    -- recipes learnt, by spell id; past it, a count
    resume = 300,   -- an open trip seen this recently, in the same city,
                    -- carries on after a load (a /reload, a quick relog);
                    -- an older one ended where it was last seen
    beat = 30,      -- the heartbeat: how often a trip under way notes that
                    -- it still is (and finds a taxi or a gate it missed)
    settle = 1,     -- a burst of skill changes read as one (as Profession
                    -- caps gathers them)
}
CityTrips.T = T

--------------------------------------------------------------------------
-- The record
--------------------------------------------------------------------------
--
-- j.trips = { trip, ... }, oldest first, the newest T.cap kept (one trip
-- under way at most, always the last). A trip, every field but the first
-- four optional and absent when there is nothing to say (example invented):
--
--   t        when it began: arriving in the city (ns.Now() seconds)
--   to       when it ended: leaving the city, a taxi taking off, an
--            instance entered, the game left, or the last time it was
--            seen when the player was away longer than a sitting's gap.
--            nil while the trip is under way
--   seen     working state, while the trip may still be under way: the
--            last moment it was known to be going on (the heartbeat, every
--            errand, the logout). Gone once it is settled; a reader never
--            needs it (a logout writes `to` beside it, so a trip left at
--            logout already has its end)
--   mapID    the city's map: the matched id from the city list (1454,
--            Orgrimmar), else, for a sanctuary or a city listed by name,
--            the zone map it lies on. `x`, `y`: where on that map the trip
--            began (Journey.Append's spot; nil where it did not read)
--   level    the character's level on arriving (37)
--   came     the purse on arriving, in copper (41200: 4 gold 12 silver)
--   left     the purse on leaving, in copper (28000); while under way, the
--            purse as last read
--   up       auctions put up: { { id = 2581, n = 6 }, ... }, one entry an
--            item (its item id; how many, all the lots of it together). No
--            asking price (left off, sign-off 24 Nov)
--   bought   auctions bought: { { id = 2589, n = 20, paid = 800,
--            who = { guid }, others = 1 }, ... }, one entry an item. `paid`
--            copper, the sum of what is known (absent when nothing is);
--            `who` the sellers the diary knows; `others` how many purchases'
--            sellers it does not (unknown, or past T.who). A won bid that
--            comes by letter is one too (its invoice: who sold it, what
--            was paid), unless it is a purchase already on the list
--   sold     auctions that had sold, read off the invoice letter as it is
--            taken: { { id = 4241, n = 2, got = 2200, who = { guid } },
--            { name = "Heavy Linen Gloves", n = 1, got = 450, others = 1 },
--            ... }, one entry an item. The invoice names the item and gives
--            no id: the id where the client or an earlier lot puts one to
--            the name, else the item's `name` (a name of a thing, never of
--            a person). `got` the coin taken out of the letters, after
--            the house's cut; `who` and `others` the buyers, as `bought`'s
--   back     how many lots came back by letter, unsold or cancelled (1)
--   letters  letters from players, taken: { { from = guid, own = true,
--            n = 1, items = 2, coin = 5000 }, { n = 3, items = 4 } }, one
--            entry a sender the diary knows (`own`: one of the player's own
--            characters) and one, with no `from`, for every sender it does
--            not. `n` letters, `items` things taken out of them (a stack
--            counts its size), `coin` copper taken out of them
--   sent     letters sent: { { to = guid, own = true, n = 1, items = 3,
--            coin = 0 }, { n = 1, items = 1 } }, likewise by recipient
--   made     what was made, by the client's "You create" line: { { id =
--            2997, n = 12 }, ... }, one entry an item
--   skills   professions that climbed during the trip: { { line = 197,
--            name = "Tailoring", from = 148, to = 165 } }, from the rank on
--            arriving (or the first reading after a load) to the last
--   recipes  recipes learnt, by spell id: { 3915, 3914, more = 2 }, `more`
--            how many past T.recipes
--   quests   quests taken and handed in: { { id = 1064, title = "Forsaken
--            Aid", out = true, with = { guid }, others = 1 }, { id = 1065,
--            title = "Journey to Tarren Mill" } }, one entry a quest a way
--            (`out` true handed in, else taken). `with`: who of the party
--            was on a quest handed in, as the client said, the diary
--            knowing them; `others` party members on it it does not
--
-- Past an item or letter list's cap, the rest goes into one last entry
-- marked `rest = true`, with no `id`, `name`, `from` or `to`: its counts
-- (`n`, `paid`, `got`, `items`, `coin`, `others`) are everything beyond
-- the cap together, so nothing a count can carry is lost and a trip of a
-- hundred errands keeps to a few hundred bytes. The quests' and the
-- professions' lists keep to their caps alone (a trip does not hand in
-- dozens): past them, a quest is counted in `quests.more`.
--
-- People are GUIDs of characters the diary already knows (ns.db.characters,
-- or the player's own, ns.OwnCharacters), and nothing else: a name from a
-- letter, an invoice or an auction that the diary does not know, or knows
-- twice, keeps no name at all and is a count (`others`, or the letters'
-- entry with no `from`). The sign-off (24 Nov): a stranger is counted,
-- never named and never stored.

-- The lists an errand writes, and what makes an entry the same as another
-- (merged into it rather than added).
local ITEMS = { up = true, bought = true, sold = true, made = true }
local PEOPLE = { letters = "from", sent = "to" }
CityTrips.LISTS = { "up", "bought", "sold", "back", "letters", "sent", "made", "skills", "recipes", "quests" }

-- Whether nothing was done on the trip (a stroll through town, or the
-- purse alone changing: vendors and repairs are not a trip's errands).
-- A trip like that is dropped as it ends.
function CityTrips.Empty(rec)
    for _, name in ipairs(CityTrips.LISTS) do
        local v = rec[name]
        if type(v) == "number" and v > 0 then return false end
        if type(v) == "table" and (#v > 0 or (v.more or 0) > 0) then return false end
    end
    return true
end

-- A character's trips that have ended and hold something, oldest first:
-- what a reader draws. One under way, or empty, is left out.
function CityTrips.List(j)
    local list = {}
    for _, rec in ipairs(Journey.List(j, "trips")) do
        if rec.to and not CityTrips.Empty(rec) then list[#list + 1] = rec end
    end
    return list
end

--------------------------------------------------------------------------
-- Writers (Capture.lua calls them; each bumps the route's version, so a
-- page open on it redraws)
--------------------------------------------------------------------------

-- A trip begun on route `j`, in the city `mapID`, now: `rec` brings `t`,
-- `level`, `came` and `seen`. Placed where the player stands (Journey.Append),
-- its map the city's own. Returns it.
function CityTrips.Open(j, mapID, rec)
    rec.left = rec.came
    Journey.Append(j, "trips", rec)
    if rec.mapID ~= mapID then rec.mapID, rec.x, rec.y = mapID, nil, nil end
    return rec
end

-- A trip ended `at`, the purse then `left` (nil: as last read). An empty
-- one leaves the list.
function CityTrips.Close(j, rec, at, left)
    rec.to = math.max(at or ns.Now(), rec.t)
    rec.seen = nil
    if type(left) == "number" then rec.left = left end
    if CityTrips.Empty(rec) then
        local list = j and j.trips or {}
        for i = #list, 1, -1 do
            if list[i] == rec then table.remove(list, i) end
        end
    end
    Journey.Touch()
end

-- A person on an entry: `guid`, known, named on it while there is room;
-- else counted.
local function Who(e, field, guid)
    if guid then
        e[field] = e[field] or {}
        for _, g in ipairs(e[field]) do
            if g == guid then return end
        end
        if #e[field] < T.who then
            table.insert(e[field], guid)
            return
        end
    end
    e.others = (e.others or 0) + 1
end

local function Add(e, key, n)
    if type(n) == "number" and n > 0 then e[key] = (e[key] or 0) + n end
end

-- The entry of list `name` that `match` finds, or a new one made by
-- `make` while the list has room, or the list's last entry for the rest.
local function Entry(rec, name, cap, match, make)
    local list = rec[name] or {}
    rec[name] = list
    local rest
    for _, e in ipairs(list) do
        if e.rest then rest = e elseif match(e) then return e end
    end
    if rest then return rest end
    local plain = #list
    if plain >= cap then
        rest = { rest = true }
        list[#list + 1] = rest
        return rest
    end
    local e = make()
    list[#list + 1] = e
    return e
end

-- An item errand: `n` of item `id` (or of the thing named `name`, for an
-- invoice's) on list `name` ("up", "bought", "sold" or "made"). `extra`:
-- `paid` / `got` copper to add, and `who`, a person known (a GUID) or
-- `stranger` true for one the diary does not know. Returns the entry.
function CityTrips.Item(rec, list, item, n, extra)
    if not (rec and ITEMS[list] and item and (item.id or item.name)) then return nil end
    n = type(n) == "number" and n > 0 and n or 1
    local e = Entry(rec, list, T.items, function(e)
        return (item.id and e.id == item.id) or (item.name and e.name == item.name)
    end, function()
        return { id = item.id, name = not item.id and item.name or nil }
    end)
    e.n = (e.n or 0) + n
    if extra then
        Add(e, "paid", extra.paid)
        Add(e, "got", extra.got)
        if extra.who or extra.stranger then Who(e, "who", extra.who) end
    end
    Journey.Touch()
    return e
end

-- The entry of a letter list ("letters" or "sent") for `guid` (nil: the
-- unknown), made if need be. `own`: one of the player's own characters.
function CityTrips.Correspondent(rec, list, guid, own)
    local field = PEOPLE[list]
    if not (rec and field) then return nil end
    local e = Entry(rec, list, T.people, function(e)
        return e[field] == guid
    end, function()
        return { [field] = guid, own = guid and own and true or nil }
    end)
    return e
end

-- A letter on list `list`: one more letter (`letter` true, the first time
-- it is counted), `items` things and `coin` copper. Returns the entry.
function CityTrips.Letter(rec, list, guid, own, letter, items, coin)
    local e = CityTrips.Correspondent(rec, list, guid, own)
    if not e then return nil end
    if letter then e.n = (e.n or 0) + 1 end
    Add(e, "items", items)
    Add(e, "coin", coin)
    Journey.Touch()
    return e
end

-- A lot come back, unsold or cancelled.
function CityTrips.Back(rec)
    if not rec then return end
    rec.back = (rec.back or 0) + 1
    Journey.Touch()
end

-- Profession `line` (named `name`) climbed from `from` to `to`: one entry
-- a profession, its first rank kept and its last moved on.
function CityTrips.Climbed(rec, line, name, from, to)
    if not (rec and type(line) == "number" and type(to) == "number") then return nil end
    rec.skills = rec.skills or {}
    for _, e in ipairs(rec.skills) do
        if e.line == line then
            if to > e.to then e.to = to end
            Journey.Touch()
            return e
        end
    end
    if #rec.skills >= T.skills then return nil end
    local e = { line = line, name = name, from = from, to = to }
    table.insert(rec.skills, e)
    Journey.Touch()
    return e
end

-- A recipe learnt, by its spell id; each once.
function CityTrips.Learnt(rec, spellID)
    if not (rec and type(spellID) == "number") then return end
    local list = rec.recipes or {}
    rec.recipes = list
    for _, id in ipairs(list) do
        if id == spellID then return end
    end
    if #list < T.recipes then list[#list + 1] = spellID else list.more = (list.more or 0) + 1 end
    Journey.Touch()
end

-- Quest `id` taken (`out` false) or handed in (`out` true), titled
-- `title`; `with` the GUIDs of the party known to the diary on it,
-- `others` how many more were. A quest taken twice (abandoned and taken
-- again) is one entry.
function CityTrips.Quest(rec, id, title, out, with, others)
    if not (rec and type(id) == "number") then return nil end
    out = out and true or nil
    local list = rec.quests or {}
    rec.quests = list
    local e
    for _, q in ipairs(list) do
        if q.id == id and q.out == out then e = q end
    end
    if not e then
        if #list >= T.quests then
            list.more = (list.more or 0) + 1
            Journey.Touch()
            return nil
        end
        e = { id = id, title = title, out = out }
        list[#list + 1] = e
    end
    for _, guid in ipairs(with or {}) do Who(e, "with", guid) end
    Add(e, "others", others)
    Journey.Touch()
    return e
end

--------------------------------------------------------------------------
-- Letting go of people (PRV-3)
--------------------------------------------------------------------------

-- Every GUID a trip keeps, through `drop(guid)`: one it says to let go of
-- leaves its line and is counted with the unknown instead, so the errand
-- stays and only the name goes. A letter whose sender goes joins the
-- unknown senders' entry.
local function Let(rec, drop)
    for _, list in ipairs({ rec.bought or {}, rec.sold or {} }) do
        for _, e in ipairs(list) do
            for i = #(e.who or {}), 1, -1 do
                if drop(e.who[i]) then
                    table.remove(e.who, i)
                    e.others = (e.others or 0) + 1
                end
            end
            if e.who and #e.who == 0 then e.who = nil end
        end
    end
    for _, q in ipairs(rec.quests or {}) do
        for i = #(q.with or {}), 1, -1 do
            if drop(q.with[i]) then
                table.remove(q.with, i)
                q.others = (q.others or 0) + 1
            end
        end
        if q.with and #q.with == 0 then q.with = nil end
    end
    for list, field in pairs(PEOPLE) do
        local entries = rec[list] or {}
        for i = #entries, 1, -1 do
            local e = entries[i]
            if e[field] and drop(e[field]) then
                local into
                for _, other in ipairs(entries) do
                    if other ~= e and not other[field] and not other.rest then into = other end
                end
                if into then
                    Add(into, "n", e.n)
                    Add(into, "items", e.items)
                    Add(into, "coin", e.coin)
                    table.remove(entries, i)
                else
                    e[field], e.own = nil, nil
                end
            end
        end
    end
end
CityTrips.Let = Let

-- At login (Journey.Prune): someone kept on a trip older than the buffer,
-- who has left the diary and is none of the player's own characters, is a
-- stranger's again, as a fight's foe and a gift's giver are. PRV-3 (the
-- "journey" store): a forgotten person leaves every trip (nil: everyone).
Journey.RegisterList("trips", {
    cap = T.cap,
    prune = function(j, now)
        local cutoff = ns.Cutoff(now)
        local own = ns.OwnCharacters and ns.OwnCharacters() or {}
        for _, rec in ipairs(j.trips or {}) do
            if rec.t < cutoff then
                Let(rec, function(guid) return not own[guid] and not ns.Diary.IsDiary(guid) end)
            end
        end
    end,
    forget = function(j, guid)
        for _, rec in ipairs(j.trips or {}) do
            Let(rec, function(g) return guid == nil or g == guid end)
        end
    end,
})

--------------------------------------------------------------------------
-- The moment: a trip told on a sheet
--------------------------------------------------------------------------

-- What "a real round" is (the user, 24 Nov: "only a real round"; the
-- numbers proposed at scope and taken at sign-off as nobody answered
-- them): at least `lines` lines to write, from at least `kinds` of the
-- four errands (auctions, mail, crafting, quests). A quick hand-in and fly
-- out (the Dev thin trip: one quest in, the next taken, two lines of one
-- kind) is not a round and opens no sheet; it stays the city's stay on its
-- map. The lines are counted as the sheet would write them unfolded, by
-- the record's shape alone (no item names, which the client may not have
-- yet when the recap is built):
--   auctions  one for what was put up, one an item sold, one an item
--             bought, one for the lots come back
--   mail      one a correspondent taken from, one sent to
--   crafting  one for what was made, one a profession that climbed, one
--             for the recipes learnt
--   quests    one for those handed in, one for those taken
--   put on   one a thing put on during the trip that the diary counts
--             as worn for good: an errand another kind offered the sheet
--             (RegisterMoment's `errand`, of `kind` "worn"), a kind of its
--             own (the user, 25 Nov 2026: "put-on counts as a kind"), so
--             buying a piece, wearing it and one errand more is a round
-- People round the trip and the purse are on every sheet, so they count
-- for nothing here.
local ROUND = { lines = 3, kinds = 2 }
CityTrips.ROUND = ROUND

-- The errands this sheet tells, by their `kind` (RegisterMoment's
-- `errand`): "worn", a thing first put on in town and kept on, { kind, t,
-- link, from, guid } (`from` how it came, where that is known: "auction",
-- "mail", "vendor", "quest", "craft", "loot", "trade"; `guid` the giver of
-- a gift, only while the diary knows them). Any other kind is passed over.
CityTrips.ERRANDS = { worn = true }

local function Len(list) return type(list) == "table" and #list or 0 end

-- The errands of `kind` among `errands` (a list of errands, or of the
-- sheet moment's { errand, moment } entries).
function CityTrips.Errands(errands, kind)
    local out = {}
    for _, x in ipairs(errands or {}) do
        local errand = x.errand or x
        if errand.kind == kind then out[#out + 1] = errand end
    end
    return out
end

-- How many lines trip `rec` has to write, and from how many errands;
-- `errands` those offered to it (RegisterMoment's `stands`).
function CityTrips.Lines(rec, errands)
    local auctions = (Len(rec.up) > 0 and 1 or 0) + Len(rec.sold) + Len(rec.bought)
        + ((rec.back or 0) > 0 and 1 or 0)
    local mail = Len(rec.letters) + Len(rec.sent)
    local crafting = (Len(rec.made) > 0 and 1 or 0) + Len(rec.skills)
        + ((Len(rec.recipes) > 0 or (type(rec.recipes) == "table" and (rec.recipes.more or 0) > 0)) and 1 or 0)
    local handed, taken = false, false
    for _, q in ipairs(rec.quests or {}) do
        if q.out then handed = true else taken = true end
    end
    local quests = (handed and 1 or 0) + (taken and 1 or 0)
    local worn = #CityTrips.Errands(errands, "worn")
    local kinds = 0
    for _, n in ipairs({ auctions, mail, crafting, quests, worn }) do
        if n > 0 then kinds = kinds + 1 end
    end
    return auctions + mail + crafting + quests + worn, kinds
end

-- Whether trip `rec` is a real round (ROUND): what opens a sheet. Asked
-- when the recap is gathered, never at the trip's close: a thing put on
-- in town is counted as worn only two minutes of play later, maybe after
-- the trip ended, so the round is judged where the trip and its errands
-- are both known (RegisterMoment's `stands`).
function CityTrips.Real(rec, errands)
    local lines, kinds = CityTrips.Lines(rec, errands)
    return lines >= ROUND.lines and kinds >= ROUND.kinds
end

-- rank 5.6: after a campfire (5.5), before a stay (6), the proposal's
-- decision 13 and the user's weight ("about as heavy as a campfire
-- evening, below a death, a dungeon or a lucky find"). Short of room the
-- sheet is the first to step off the page, unless the player kept it.
--
-- Not light. Recap.LIGHT is the whitelist of what a small print can tell:
-- a place with nothing for the margin and a line of words at most (a
-- first visit, a door, a stay, a level's pin, a campfire). A trip is half
-- a page of lines, the opposite of that. The page weighs a sheet `H`
-- whatever LIGHT says (UI/Journey/Layouts.lua's Weight), so the flag
-- would change nothing drawn today; but it would make the sheet's plate
-- `light` (the trip and the stay it tells both light), and any reader of
-- plate.light that forgot to ask for `sheet` first would take half a page
-- of errands for a print. So it stays a full kind, as a new kind is.
--
-- Gathered by hand, not by `list`: trips that have ended and hold
-- something (CityTrips.List). Which of them make a real round
-- (CityTrips.Real) is `stands`', asked by the core once every kind has
-- gathered, with the errands offered to the trip: a thing put on in town
-- is a line, and a kind, of the round. The moment names its span (`from`,
-- `to`) on the city's map, so the city's stay over the same span, and an
-- errand put down in it, are the sheet's to tell (a visit told once, the
-- ticklist's one row for the trip and its stay: RegisterMoment's `sheet`
-- and `errand`).
ns.JourneyRecap.RegisterMoment("trip", {
    order = 72, entry = "trips", field = "trip", rank = 5.6, sheet = true,
    gather = function(j, a, b, e)
        local into = e.trips
        for _, rec in ipairs(CityTrips.List(j)) do
            if rec.t >= a and rec.t < b then into[#into + 1] = rec end
        end
    end,
    stands = function(rec, errands) return CityTrips.Real(rec, errands) end,
    moment = function(j, rec, Own)
        local map, x, y = Own(j, rec.mapID, rec.x, rec.y, rec.t)
        return { kind = "trip", t = rec.t, from = rec.t, to = rec.to, trip = rec }, map, x, y
    end,
})
