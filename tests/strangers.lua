-- Strangers packed, a line each (Core/Strangers.lua): a line says exactly what
-- the tables said, nothing a reader asks comes out differently for it, the
-- diary survives a logout and a login as text, and a diary saved before
-- there were lines is taken over whole.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY, HOUR = T.DAY, 3600
local ns = T.Boot()

local function Copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for key, value in pairs(v) do out[key] = Copy(value) end
    return out
end

-- Where two values first differ, or nil when they are the same.
local function Differs(a, b, path)
    path = path or "it"
    if type(a) ~= type(b) then return ("%s: %s against %s"):format(path, tostring(a), tostring(b)) end
    if type(a) ~= "table" then
        if a ~= b then return ("%s: %s against %s"):format(path, tostring(a), tostring(b)) end
        return nil
    end
    for key, value in pairs(a) do
        local why = Differs(value, b[key], path .. "." .. tostring(key))
        if why then return why end
    end
    for key in pairs(b) do
        if a[key] == nil then return ("%s.%s: missing on the left"):format(path, tostring(key)) end
    end
    return nil
end

local function Same(a, b, what)
    local why = Differs(a, b)
    Check(why == nil, what .. (why and (" -- " .. why) or ""))
end

local ME = F.SELF.guid
local ALT = "Player-4707-0ABCDEF2"

--------------------------------------------------------------------------
Section("a line says what the tables said")

local ToLine, FromLine = ns._test.StrangerToLine, ns._test.StrangerFromLine
local T0 = 1795296088

-- A field a variant leaves out.
local NONE = {}

local function Record(guid, more)
    local record = { guid = guid, firstSeen = T0, lastSeen = T0 + 7200, faction = "Horde", level = 26,
        class = "MAGE", classID = 8, race = "Troll", raceID = 8, sex = 2,
        names = { { first = "Aldren", surname = "Voss", firstSeen = T0, lastSeen = T0 + 7200 } } }
    for key, value in pairs(more or {}) do
        if value == NONE then record[key] = nil else record[key] = value end
    end
    return record
end

local function Row(more)
    local row = { time = T0, me = ME, level = 26, mapID = 1412, x = 0.421, y = 0.616, subZone = "Bloodhoof Village",
        src = "plate" }
    for key, value in pairs(more or {}) do
        if value == NONE then row[key] = nil else row[key] = value end
    end
    return row
end

local G = "Player-4620-00C0FFEE"

local function Round(what, record, rows)
    local hands = {}
    local line = ToLine(G, record, rows, hands)
    Check(type(line) == "string", what .. ": not packed")
    local back, backRows = FromLine(G, line, hands)
    Same(record, back, what .. ": the record")
    Same(rows, backRows, what .. ": the rows")
    return line
end

local plain = Round("someone seen once", Record(G), { Row() })
Check(#plain < 100, "a stranger seen once takes more than a hundred bytes: " .. #plain)
Check(not plain:find(G, 1, true) and not plain:find(ME, 1, true), "a GUID is spelled out in the line")

Round("never sighted", Record(G), nil)
Round("several rows", Record(G), {
    Row(),
    Row({ time = T0 + 4000, last = T0 + 4900, hostile = true, mapID = 1413, subZone = NONE, me = ALT }),
    Row({ time = T0 + 9000, mapID = NONE, x = NONE, y = NONE, zone = "The Deeprun",
        level = NONE, src = "whistle" }),
    Row({ time = T0 + 90000, x = 0, y = 1, src = "emote", last = T0 + 90001 }),
})
Round("a row from before they were first seen", Record(G), { Row({ time = T0 - 3 }) })
Round("names over time", Record(G, { names = {
    { first = "Aldren", surname = "Voss", firstSeen = T0, lastSeen = T0 + 100 },
    { first = "Aldren", firstSeen = T0 + 200, lastSeen = T0 + 7200 },
} }), { Row() })
Round("no name yet", Record(G, { names = {} }), { Row() })
Round("tokens their ids do not say", Record(G, { class = "TINKER", classID = 8, race = "Troll", raceID = 99 }), { Row() })
Round("an id alone, a token alone", Record(G, { class = NONE, race = "Troll", raceID = NONE }), nil)
Round("nothing read but the name", Record(G, { faction = NONE, level = NONE, class = NONE,
    classID = NONE, race = NONE, raceID = NONE, sex = NONE }), nil)
Round("words with the line's own marks in them", Record(G, { faction = "A", guild = "Ash; Oak, Elm/Yew: 100% = more!",
    names = { { first = "Él=an", surname = "D'Or,", firstSeen = T0, lastSeen = T0 + 7200 } } }),
    { Row({ subZone = "Thoradin's Wall; east/west", zone = "A:B", src = "p" }) })
Round("a summary", Record(G, { sightingSummary = { first = T0 - 40 * DAY, last = T0 - 31 * DAY, count = 7, levelMin = 12,
    levelMax = 26, hostile = 2, days = 4, lastDay = T0 - 31 * DAY - 500, zones = { [1412] = 5, ["The Deeprun"] = 2 } } }),
    { Row() })
Round("a summary of nothing", Record(G, { sightingSummary = {} }), nil)

-- What a line cannot say exactly is not written, and stays a table.
local function Refused(what, record, rows)
    Eq(ToLine(G, record, rows, {}), nil, what .. " was packed")
end
Refused("a field the line does not know", Record(G, { seen = { time = T0 } }), nil)
Refused("one of the user's own", Record(G, { isSelf = true }), nil)
Refused("a row's field it does not know", Record(G), { Row({ note = "x" }) })
Refused("a position finer than a thousandth", Record(G), { Row({ x = 0.42137 }) })
Refused("a time that is not whole", Record(G, { lastSeen = T0 + 0.5 }), nil)
Refused("an empty word", Record(G, { guild = "" }), nil)
Refused("an empty list of rows", Record(G), {})
Refused("a row without its character", Record(G), { Row({ me = NONE }) })
Refused("a record under another key", Record("Player-4620-00C0FFEF"), nil)
Refused("a summary with a field it does not know", Record(G, { sightingSummary = { count = 1, note = 2 } }), nil)

--------------------------------------------------------------------------
Section("nothing a reader asks comes out differently")

local MULGORE = { mapID = 1412, x = 0.421, y = 0.616, zone = "Mulgore", subZone = "Bloodhoof Village" }
local BARRENS = { mapID = 1413, x = 0.5, y = 0.31, zone = "The Barrens" }
local DEEPRUN = { zone = "The Deeprun" }

local P = {
    once = "Player-4620-00D00001", often = "Player-4620-00D00002", thrice = "Player-4620-00D00003",
    namesake = "Player-4620-00D00004", unseen = "Player-4620-00D00005", old = "Player-4620-00D00006",
    regular = "Player-4620-00D00007", nomap = "Player-4620-00D00008",
    friend = "Player-4620-00D00009", trader = "Player-4620-00D0000A", alt = ALT,
}

-- The same people either way; `packed` packs every stranger before each
-- question, so each answer has to come through the lines.
local function World(packed)
    mock.Reset()
    local ns = T.Boot()
    local now = mock.now
    local function Meet(guid, first, surname, at, more)
        local info = { first = first, surname = surname, class = "MAGE", classID = 8, race = "Troll", raceID = 8,
            faction = "Horde", sex = 2, level = 20, time = at }
        for key, value in pairs(more or {}) do info[key] = value end
        ns.Characters.Observe(guid, info)
    end
    local function See(guid, at, where, data)
        data = data or {}
        data.source = data.source or "plate"
        data.level = data.level or 20
        ns.Sightings.Record(guid, data, where or MULGORE, at)
    end

    Meet(P.once, "Aldren", "Voss", now - 2 * DAY - 5 * HOUR)
    See(P.once, now - 2 * DAY - 5 * HOUR)

    Meet(P.often, "Berit", "Okane", now - 20 * DAY, { guild = "Ash and Oak" })
    See(P.often, now - 20 * DAY)
    See(P.often, now - 10 * DAY, BARRENS, { hostile = true, source = "target" })
    See(P.often, now - DAY - 700)
    See(P.often, now - DAY, nil, { level = 21 })

    Meet(P.thrice, "Corin", "Hale", now - 3 * DAY)
    See(P.thrice, now - 3 * DAY)
    See(P.thrice, now - 3 * DAY + 2 * HOUR)
    See(P.thrice, now - 3 * DAY + 5 * HOUR, BARRENS, { source = "mouse" })

    Meet(P.namesake, "Aldren", "Mire", now - 4 * DAY)
    See(P.namesake, now - 4 * DAY + 60)

    Meet(P.unseen, "Dessa", "Wynn", now - 40 * DAY)

    Meet(P.old, "Edda", "Roon", now - 35 * DAY)
    See(P.old, now - 35 * DAY)

    Meet(P.regular, "Fenna", "Tull", now - 36 * DAY)
    See(P.regular, now - 36 * DAY, BARRENS)
    See(P.regular, now - 6 * DAY)
    ns.db.characters[P.regular].lastSeen = now - 6 * DAY

    Meet(P.nomap, "Garrow", "Finch", now - 7 * DAY)
    See(P.nomap, now - 7 * DAY, DEEPRUN, { source = "say" })

    -- Who stays a table: the diary's, the buffer's, the user's own.
    Meet(P.friend, "Hale", "Brannock", now - 8 * DAY)
    See(P.friend, now - 8 * DAY)
    ns.Diary.Add(P.friend, { quiet = true })
    Meet(P.trader, "Ione", "Starke", now - 9 * DAY)
    See(P.trader, now - 9 * DAY)
    ns.Interactions.Add(P.trader, "trade", { time = now - 9 * DAY + 50 })
    ns.OwnCharacters()[P.alt] = { first = "Jory", surname = "Pell" }
    Meet(P.alt, "Jory", "Pell", now - 2 * DAY)
    See(P.alt, now - 2 * DAY)

    local function Away()
        if not packed then return end
        ns.Strangers.Pack()
    end
    local r = {}
    local function Ask(key, fn)
        Away()
        r[key] = Copy(fn())
    end

    if packed then
        Eq(ns.Strangers.Pack(), 8, "the eight strangers were not all packed")
        Eq(type(ns.db.strangers[P.once]), "string", "no line for a stranger")
        Eq(rawget(ns.db.characters, P.once), nil, "a stranger's record is still a table")
        Eq(rawget(ns.db.sightings, P.once), nil, "a stranger's rows are still a table")
        for _, who in ipairs({ "friend", "trader", "alt" }) do
            Eq(ns.db.strangers[P[who]], nil, who .. " went into a line")
            Check(rawget(ns.db.characters, P[who]) ~= nil, who .. "'s record is gone")
        end
    end

    Ask("days", ns.Sightings.Days)
    for i, day in ipairs(Copy(r.days)) do
        Ask("onDay" .. i, function()
            local list = ns.Sightings.OnDay(day.start)
            table.sort(list, function(a, b) return a.guid < b.guid end)
            return list
        end)
        Ask("entries" .. i, function()
            local by = {}
            for _, e in ipairs(ns.Sightings.DayEntries(day.start)) do
                by[e.guid] = { e.name, e.zone, e.subZone or false, e.level, e.last, e.hostile, e.days, e.first,
                    e.firstLevel or false, e.dealt or false, e.row }
            end
            return by
        end)
    end
    Ask("since", function()
        local guids = {}
        for i, seen in ipairs(ns.Sightings.Since(now - 5 * DAY)) do guids[i] = seen.guid end
        return guids
    end)
    Ask("counts", function()
        return { { ns.Sightings.Count() }, ns.Characters.Count(), ns.People.PencilledCount() }
    end)
    Ask("byFirstName", function() return { ns.Characters.FindByName("aldren") } end)
    Ask("byFullName", function() return { ns.Characters.FindByName("Aldren", "Voss") } end)
    Ask("byNameAlone", function() return { ns.Characters.FindByName("CORIN") } end)
    Ask("byNoName", function() return { ns.Characters.FindByName("Zebedee") } end)
    Ask("waiting", ns.AutoAdd.Waiting)
    Ask("summary", function() return { ns.Sightings.Summary(P.often) or false, ns.Sightings.Summary(P.unseen) or false } end)
    Ask("seenBefore", function() return { ns.Sightings.SeenBefore(P.often, now) } end)
    Ask("latest", function() return ns.Sightings.Latest(P.often) end)
    Ask("name", function() return { ns.Characters.FullName(P.nomap), ns.Characters.Get(P.nomap).level } end)
    Ask("record", function() return ns.db.characters[P.often] end)
    Ask("rows", function() return ns.db.sightings[P.thrice] end)
    Ask("until", function() return { ns.Glimpse.Until(P.once) } end)
    Ask("glimpse", function()
        local g = ns.Glimpse.Of(P.thrice, now)
        return g and { g.name, g.seen or false, g["until"] } or false
    end)
    Ask("firstSightings", function()
        return ns.JourneyRecap.FirstSightings({ startedAt = 0 }, ns.JourneyRecap.Context(ME, now))
    end)
    Ask("heat", function() return ns.Heat.Backfill(P.thrice, now) end)

    -- Seen again inside their last row's hour: the row goes on, no new one.
    Ask("again", function()
        local what = ns.Sightings.Record(P.often, { source = "sweep", level = 22 }, MULGORE, now - DAY + 900)
        return { what, ns.Sightings.For(P.often) }
    end)
    -- And an hour on: a new one.
    Ask("later", function()
        local what = ns.Sightings.Record(P.once, { source = "plate" }, BARRENS, now)
        return { what, #ns.Sightings.For(P.once) }
    end)

    Ask("rollup", function() return { ns.Sightings.Rollup(now) } end)
    Ask("prune", function() return ns.Characters.Prune() end)
    Ask("afterRollup", function()
        return { ns.Characters.Get(P.old) or false, ns.Characters.Get(P.unseen) or false,
            ns.Characters.Get(P.regular) or false, ns.Sightings.For(P.regular), ns.Sightings.Summary(P.regular) or false,
            { ns.Sightings.Count() }, ns.Characters.Count(), ns.Sightings.Days() }
    end)
    if packed then
        ns.Strangers.Pack()
        Eq(type(ns.db.strangers[P.regular]), "string", "a stranger with a summary does not go into a line")
    end

    Ask("forget", function()
        return { ns.Characters.Forget(P.thrice), ns.Characters.Get(P.thrice) or false, #ns.Sightings.For(P.thrice),
            ns.Characters.Forget(P.thrice) }
    end)
    if packed then Eq(ns.db.strangers[P.thrice], nil, "someone forgotten kept their line") end

    Ask("shorter", function()
        -- The retention turned down (the Memory page does these three).
        ns.db.settings.bufferDays = 5
        ns.Interactions.Prune(now)
        local rolled = { ns.Sightings.Rollup(now) }
        return { rolled, ns.Characters.Prune() }
    end)
    Ask("afterShorter", function() return { { ns.Sightings.Count() }, ns.Characters.Count(), ns.Sightings.Days() } end)

    Ask("deleteAll", ns.Sightings.DeleteAll)

    Away()
    ns.Strangers.UnpackAll()
    Eq(next(ns.db.strangers), nil, "a line was left after all were unpacked")
    r.characters, r.sightings = Copy(ns.db.characters), Copy(ns.db.sightings)
    return r
end

local tables, lines = World(false), World(true)
local keys = {}
for key in pairs(tables) do keys[#keys + 1] = key end
for key in pairs(lines) do
    if tables[key] == nil then keys[#keys + 1] = key end
end
table.sort(keys)
for _, key in ipairs(keys) do Same(tables[key], lines[key], key) end

-- The answers are worth comparing: the questions found people.
Check(#tables.days >= 6, "the world has too few days to prove anything")
Eq(tables.byFirstName[2], 2, "two strangers share a first name")
Eq(tables.byFullName[1], P.once, "the full name finds the one")
Eq(tables.waiting[1], P.thrice, "nobody waits to be added")
Eq(tables.again[1], "updated", "seen again inside the hour started a new row")
Eq(tables.later[1], "new", "seen an hour on did not start a row")
Eq(tables.rollup[1], 2, "the old rows were not rolled up")
Eq(tables.prune, 2, "the two with nothing left were not forgotten")
Eq(tables.afterRollup[1], false, "someone only seen long ago is still on record")
Eq(tables.afterRollup[5].count, 2, "the regular's summary lost a row")

--------------------------------------------------------------------------
Section("logging out and in again, as text")

-- The saved tables as the client writes them and reads them back. Logged
-- out (`plain`), every one of them is a table and nothing more.
local function Write(v, out, plain)
    if type(v) == "table" then
        if plain then Check(getmetatable(v) == nil, "a saved table is not a plain one") end
        out[#out + 1] = "{\n"
        for key, value in pairs(v) do
            out[#out + 1] = type(key) == "string" and ("[%q] = "):format(key) or ("[%s] = "):format(tostring(key))
            Write(value, out, plain)
            out[#out + 1] = ",\n"
        end
        out[#out + 1] = "}"
    elseif type(v) == "string" then
        out[#out + 1] = ("%q"):format(v)
    else
        out[#out + 1] = tostring(v)
    end
end

local function Saved(midSession)
    local out = { "SocialDiaryDB = " }
    Write(_G.SocialDiaryDB, out, not midSession)
    out[#out + 1] = "\nSocialDiaryCharDB = "
    Write(_G.SocialDiaryCharDB, out, not midSession)
    return table.concat(out)
end

-- A fresh client with that text for its saved variables.
local function Relog(text)
    local now = mock.now
    mock.Reset()
    mock.now = now
    local fresh = T.Load()
    mock.SetUnit("player", F.SELF)
    local env = {}
    setfenv(assert(loadstring(text)), env)()
    _G.SocialDiaryDB, _G.SocialDiaryCharDB = env.SocialDiaryDB, env.SocialDiaryCharDB
    mock.fire("ADDON_LOADED", fresh.addonName)
    mock.fire("PLAYER_LOGIN")
    return fresh
end

mock.Reset()
ns = T.Boot()
local now = mock.now
local PAT, QUIN = "Player-4620-00E00001", "Player-4620-00E00002"
ns.Characters.Observe(PAT, { first = "Élan", surname = "D'Or", class = "DRUID", classID = 11, race = "Tauren", raceID = 6,
    faction = "Horde", sex = 3, level = 31, guild = 'The "Quiet" Few; est. 12/3', time = now - 3 * DAY })
ns.Sightings.Record(PAT, { source = "plate", level = 31 }, MULGORE, now - 3 * DAY)
ns.Sightings.Record(PAT, { source = "yell", level = 31, hostile = true }, DEEPRUN, now - 2 * DAY)
ns.Characters.Observe(QUIN, { first = "Quin", surname = "Marsh", class = "MAGE", classID = 8, time = now - DAY })
ns.Sightings.Record(QUIN, { source = "plate" }, BARRENS, now - DAY)
ns.Diary.Add(QUIN, { quiet = true })

local was = { record = Copy(ns.db.characters[PAT]), rows = Copy(ns.db.sightings[PAT]),
    friend = Copy(ns.db.characters[QUIN]), friendRows = Copy(ns.db.sightings[QUIN]) }
local before = #Saved(true)

mock.fire("PLAYER_LOGOUT")
local diary = _G.SocialDiaryCharDB.data
Eq(type(diary.strangers[PAT]), "string", "logging out did not pack the stranger")
Eq(diary.characters[PAT], nil, "the stranger's record is saved twice")
Eq(diary.sightings[PAT], nil, "the stranger's rows are saved twice")
Check(diary.characters[QUIN] ~= nil and diary.sightings[QUIN] ~= nil, "a diary entry went into a line")
Eq(getmetatable(diary.characters), nil, "the records are not a plain table for the client to write")
Eq(getmetatable(diary.sightings), nil, "the sightings are not a plain table for the client to write")
Eq(diary.strangerMe[1], ME, "the line's character is not on the list")

local text = Saved()
Check(#text < before, "the saved text did not get smaller")

ns = Relog(text)
Eq(type(ns.db.strangers[PAT]), "string", "the login unpacked a stranger nobody asked for")
Eq(ns.Characters.FullName(PAT), "Élan D'Or", "the stranger's name after a login")
Eq(ns.db.strangers[PAT], nil, "asked for, the line is still there")
Same(was.record, ns.db.characters[PAT], "the stranger's record after a login")
Same(was.rows, ns.db.sightings[PAT], "the stranger's rows after a login")
Same(was.friend, ns.db.characters[QUIN], "the diary entry's record after a login")
Same(was.friendRows, ns.db.sightings[QUIN], "the diary entry's rows after a login")

-- A second time round, unpacked or not, nothing moves.
mock.fire("PLAYER_LOGOUT")
ns = Relog(Saved())
Same(was.rows, ns.Sightings.For(PAT), "the rows after a second login")
mock.fire("PLAYER_LOGOUT")
ns = Relog(Saved())
mock.fire("PLAYER_LOGOUT")
ns = Relog(Saved())
Same(was.record, ns.Characters.Get(PAT), "the record after two logins packed")

-- Seen again through the capture, as a player would be.
mock.mapID, mock.zone, mock.inInstance, mock.pvpType = 1412, "Mulgore", false, nil
mock.position = { x = 0.4213, y = 0.6157 }
mock.fire("PLAYER_ENTERING_WORLD", false, false)
mock.fire("PLAYER_LOGOUT")
ns = Relog(Saved())
mock.mapID, mock.zone, mock.inInstance, mock.pvpType = 1412, "Mulgore", false, nil
mock.position = { x = 0.4213, y = 0.6157 }
mock.fire("PLAYER_ENTERING_WORLD", false, false)
local STRANGER = F.STRANGER
mock.SetUnit("nameplate3", STRANGER)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
ns._test.DrainSightings()
Eq(#ns.Sightings.For(STRANGER.guid), 1, "a stranger's nameplate left no row")
mock.fire("PLAYER_LOGOUT")
ns = Relog(Saved())
mock.mapID, mock.zone, mock.inInstance, mock.pvpType = 1412, "Mulgore", false, nil
mock.position = { x = 0.4213, y = 0.6157 }
mock.fire("PLAYER_ENTERING_WORLD", false, false)
Eq(type(ns.db.strangers[STRANGER.guid]), "string", "the stranger was not packed")
mock.now = mock.now + 600
mock.SetUnit("nameplate3", STRANGER)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
ns._test.DrainSightings()
local again = ns.Sightings.For(STRANGER.guid)
Eq(#again, 1, "ten minutes on, the same stranger got a second row")
Eq(again[1].last, mock.now, "the row was not carried on")
Eq(ns.db.strangers[STRANGER.guid], nil, "seen again, their line is still there")
Eq(ns.Characters.FullName(STRANGER.guid), "Bram Redfen", "the stranger's name")

--------------------------------------------------------------------------
Section("a diary saved before there were lines")

mock.Reset()
local old = T.Load()
mock.SetUnit("player", F.SELF)
local then_ = mock.now
local function OldRecord(guid, first, surname, at)
    return { guid = guid, firstSeen = at, lastSeen = at, faction = "Alliance", level = 14, class = "ROGUE", classID = 4,
        race = "Gnome", raceID = 7, sex = 3, names = { { first = first, surname = surname, firstSeen = at, lastSeen = at } } }
end
local function OldRow(at)
    return { time = at, me = ME, level = 14, mapID = 1429, x = 0.3, y = 0.71, subZone = "Goldshire", src = "plate" }
end
local R1, R2, R3, R4 = "Player-4620-00F00001", "Player-4620-00F00002", "Player-4620-00F00003", "Player-4620-00F00004"
local saved = {
    schema = 5,
    characters = {
        [R1] = OldRecord(R1, "Rosa", "Kettle", then_ - 2 * DAY),
        [R2] = OldRecord(R2, "Sten", "Arrow", then_ - 3 * DAY),
        [R3] = OldRecord(R3, "Tove", "Lind", then_ - 4 * DAY),
        [R4] = OldRecord(R4, "Ulla", "Brand", then_ - 5 * DAY),
    },
    sightings = { [R1] = { OldRow(then_ - 2 * DAY) }, [R2] = { OldRow(then_ - 3 * DAY) }, [R3] = { OldRow(then_ - 4 * DAY) },
        [R4] = { OldRow(then_ - 5 * DAY) } },
    diary = { [R2] = { guid = R2, addedAt = then_ - 3 * DAY, addedBy = ME } },
    interactions = { [R3] = { { type = "trade", time = then_ - 4 * DAY, me = ME } } },
}
-- A record with something on it the lines do not know.
saved.characters[R4].seen = { time = then_ - 5 * DAY, zone = "Elwynn Forest" }
local asSaved = Copy(saved)

_G.SocialDiaryCharDB = { schema = 2, settings = {}, data = saved }
mock.fire("ADDON_LOADED", old.addonName)
-- STEPS.diary[6]: the strangers are packed as the diary loads, and only they.
Eq(saved.schema, 6, "the diary was not brought to the new schema")
Eq(type(saved.strangers[R1]), "string", "the old stranger did not go into a line")
Eq(rawget(saved.characters, R1), nil, "the old stranger's record is saved twice")
Eq(rawget(saved.sightings, R1), nil, "the old stranger's rows are saved twice")
for _, guid in ipairs({ R2, R3, R4 }) do
    Eq(saved.strangers[guid], nil, "someone who is no stranger went into a line")
    Same(asSaved.characters[guid], rawget(saved.characters, guid), "a record that stays was touched")
    Same(asSaved.sightings[guid], rawget(saved.sightings, guid), "rows that stay were touched")
end
mock.fire("PLAYER_LOGIN")
-- (The login fills in where a diary entry was last seen, as it always has.)
asSaved.characters[R2].seen = Copy(rawget(saved.characters, R2).seen)
for _, guid in ipairs({ R2, R3, R4 }) do
    Eq(saved.strangers[guid], nil, "someone who is no stranger went into a line")
    Same(asSaved.characters[guid], rawget(saved.characters, guid), "a record that stays was touched")
    Same(asSaved.sightings[guid], rawget(saved.sightings, guid), "rows that stay were touched")
end
Same(asSaved.characters[R1], old.Characters.Get(R1), "the old stranger's record")
Same(asSaved.sightings[R1], old.Sightings.For(R1), "the old stranger's rows")
Eq(old.Characters.FullName(R1), "Rosa Kettle", "the old stranger's name")

-- The step alone, on a table of that shape and on one with nothing in it.
local shape = Copy(asSaved)
old._test.Migrate(shape, 6, old._test.DiarySteps)
Eq(shape.schema, 6, "the step did not run")
Eq(type(shape.strangers[R1]), "string", "the step made no line")
Eq(shape.characters[R1], nil, "the step left the record beside its line")
Same(asSaved.characters[R3], shape.characters[R3], "the step touched someone in the buffer")
local empty = { schema = 5 }
old._test.Migrate(empty, 6, old._test.DiarySteps)
Eq(empty.schema, 6, "a diary with no records stopped the step")

-- Packing that fails as the diary loads is reported and nothing more: the
-- diary loads as it was saved, and is read that way.
mock.Reset()
local failing = T.Load()
mock.SetUnit("player", F.SELF)
local pack, reported = failing.Strangers.Pack, 0
local handler = _G.geterrorhandler
_G.geterrorhandler = function() return function() reported = reported + 1 end end
failing.Strangers.Pack = function() error("packing failed") end
local unpacked = Copy(asSaved)
_G.SocialDiaryCharDB = { schema = 2, settings = {}, data = unpacked }
mock.fire("ADDON_LOADED", failing.addonName)
Eq(reported, 1, "a failed packing was not reported")
Check(failing.db ~= nil, "a failed packing stopped the diary from loading")
Eq(unpacked.schema, 6, "the diary's number after a failed packing")
Eq(next(unpacked.strangers), nil, "a failed packing left lines")
Same(asSaved.characters[R1], failing.Characters.Get(R1), "after a failed packing, the stranger as saved")
Same(asSaved.sightings[R1], failing.Sightings.For(R1), "after a failed packing, the stranger's rows as saved")
-- The login packs them, once packing works again.
failing.Strangers.Pack = pack
mock.fire("PLAYER_LOGIN")
_G.geterrorhandler = handler
Eq(type(unpacked.strangers[R1]), "string", "the login did not pack what the load could not")

-- A diary whose number is already past this step, its strangers still
-- tables (a build that numbered steps of its own first): the number is
-- left alone, the diary is read as it is, and the login puts them away.
mock.Reset()
local later = T.Load()
mock.SetUnit("player", F.SELF)
local ahead = Copy(asSaved)
ahead.schema = 7
_G.SocialDiaryCharDB = { schema = 2, settings = {}, data = ahead }
mock.fire("ADDON_LOADED", later.addonName)
Eq(ahead.schema, 7, "a later diary's number was moved")
Eq(next(ahead.strangers), nil, "a later diary was converted as it loaded")
Same(asSaved.characters[R1], later.Characters.Get(R1), "a later diary's stranger, read as saved")
mock.fire("PLAYER_LOGIN")
Eq(type(ahead.strangers[R1]), "string", "a later diary's stranger was not packed at the login")
Same(asSaved.sightings[R1], later.Sightings.For(R1), "a later diary's stranger's rows")

--------------------------------------------------------------------------
Section("a line that is not one, and a record beside its line")

mock.Reset()
ns = T.Boot()
now = mock.now
local BAD, BOTH = "Player-4620-00F0000B", "Player-4620-00F0000C"
ns.db.strangers[BAD] = "not a line at all"
Eq(ns.Characters.Get(BAD), nil, "a broken line made a record")
Eq(ns.db.strangers[BAD], "not a line at all", "a broken line was thrown away")
Eq(ns.Characters.Get(BAD), nil, "asked again")
Eq(ns.Strangers.Broken(), 1, "the broken line is not counted")
ns.Sightings.Days()
ns.Sightings.OnDay(ns.DayStart(now))
ns.Sightings.Rollup(now)
ns.Characters.Prune()
ns.Characters.FindByName("not")
ns.AutoAdd.Waiting()
Eq((ns.Sightings.Count()), 0, "a broken line counts as rows")
Eq(ns.db.strangers[BAD], "not a line at all", "housekeeping threw a broken line away")

-- Written past the store while a line was about: nothing of either is lost.
ns.Characters.Observe(BOTH, { first = "Vera", surname = "Holt", time = now - 5 * DAY })
ns.Sightings.Record(BOTH, { source = "plate" }, MULGORE, now - 5 * DAY)
Eq(ns.Strangers.Pack(), 1, "not packed")
rawset(ns.db.characters, BOTH, { guid = BOTH, firstSeen = now - 100, lastSeen = now - 100,
    names = { { first = "Vera", surname = "Holt", firstSeen = now - 100, lastSeen = now - 100 } } })
rawset(ns.db.sightings, BOTH, { { time = now - 100, me = ME, mapID = 1413, x = 0.5, y = 0.31, src = "target" } })
ns.Strangers.Pack()
Eq(ns.db.characters[BOTH].firstSeen, now - 5 * DAY, "the line's first sighting was lost")
local both = ns.Sightings.For(BOTH)
Eq(#both, 2, "a row was lost between the line and the record")
Eq(both[1].time, now - 5 * DAY, "the rows are not oldest first")
Eq(both[2].src, "target", "the newer row")

-- /sd sightings unpack: this session is saved as it was before there were
-- lines, and /sd sightings pack takes that back.
ns.Strangers.Pack()
ns.db.settings.debug = true
SlashCmdList.SOCIALDIARY("sightings unpack")
Eq(next(ns.db.strangers) == BAD and next(ns.db.strangers, BAD) == nil, true, "unpack left a line that can be read")
mock.fire("PLAYER_LOGOUT")
Eq(ns.db.strangers[BOTH], nil, "held, the logout packed a stranger")
Check(rawget(ns.db.characters, BOTH) ~= nil, "held, the stranger is not saved as a table")
ns.Strangers.Attach()
SlashCmdList.SOCIALDIARY("sightings pack")
Eq(type(ns.db.strangers[BOTH]), "string", "pack did not pack the stranger")
mock.fire("PLAYER_LOGOUT")
Eq(type(ns.db.strangers[BOTH]), "string", "after pack, the logout left them a table")
ns.Strangers.Attach()
ns.db.settings.debug = false

-- Delete everything: the lines go with the rest, and the stores still unpack
-- whoever comes after.
ns.Characters.Observe(BOTH, { first = "Vera", surname = "Holt" })
ns.Strangers.Pack()
ns.WipeData()
Eq(next(ns.db.strangers), nil, "delete everything left a line")
Eq(#ns.db.strangerMe, 0, "delete everything left the list of characters")
ns.Characters.Observe(BOTH, { first = "Vera", surname = "Holt", time = now - 50 })
ns.Strangers.Pack()
Eq(ns.Characters.FullName(BOTH), "Vera Holt", "after delete everything a packed stranger is not unpacked")

--------------------------------------------------------------------------
Section("what is wrong in the save stops nothing and loses nothing")

mock.Reset()
ns = T.Boot()
now = mock.now
local JUNK, TORN, STALE, MIXED, ROLLED, FINE = "Player-4620-00F00010", "Player-4620-00F00011",
    "Player-4620-00F00012", "Player-4620-00F00013", "Player-4620-00F00014", "Player-4620-00F00015"

local function Housekeeping()
    ns.Sightings.Days()
    ns.Sightings.OnDay(ns.DayStart(now))
    ns.Sightings.Since(now - DAY)
    ns.Sightings.Rollup(now)
    ns.Characters.Prune()
    ns.Characters.FindByName("vera")
    ns.AutoAdd.Waiting()
    ns.People.PencilledCount()
    ns.Sightings.Count()
    ns.Strangers.Bytes()
    ns.Strangers.Pack()
end

-- A stranger's line with its names made unreadable: the head and the rows
-- still say when, the line as a whole does not open.
local function Torn(guid, when)
    ns.Characters.Observe(guid, { first = "Vera", surname = "Holt", time = when })
    ns.Sightings.Record(guid, { source = "plate" }, MULGORE, when)
    ns.Strangers.Pack()
    local line = ns.db.strangers[guid]
    local a = line:find(";", 1, true)
    local b = line:find(";", a + 1, true)
    ns.db.strangers[guid] = line:sub(1, a) .. "Vera,Holt,x,y" .. line:sub(b)
    return ns.db.strangers[guid]
end

-- Something that is not text among the lines: passed over by every walk,
-- left where it is, and nobody.
ns.Characters.Observe(FINE, { first = "Odo", surname = "Marsh", time = now - 100 })
ns.Sightings.Record(FINE, { source = "plate" }, MULGORE, now - 100)
ns.Strangers.Pack()
local junk = {}
ns.db.strangers[JUNK] = junk
local people = ns.Characters.Count()
local okay, why = pcall(Housekeeping)
Check(okay, "a value that is not a line stopped the housekeeping -- " .. tostring(why))
Eq(ns.db.strangers[JUNK], junk, "a value that is not a line was thrown away")
Eq(ns.Characters.Get(JUNK), nil, "a value that is not a line made a record")
Eq(ns.Characters.Count(), people, "a value that is not a line counts as someone")
Eq(ns.Characters.FullName(FINE), "Odo Marsh", "the stranger beside it is not read")
okay, why = pcall(ns.Sightings.Forget, nil)
Check(okay, "a value that is not a line stopped the rows from being dropped -- " .. tostring(why))
ns.db.strangers[JUNK] = nil

-- A line that will not open, seen inside the buffer: it stays, its person
-- is in no count, and they keep their place in what names them.
local torn = Torn(TORN, now - 2 * DAY)
ns.db.around[TORN] = true
local counted = ns.Characters.Count()
local days = ns.Sightings.Days()
Eq(ns.Characters.Get(TORN), nil, "a torn line made a record")
Eq(ns.Characters.Count(), counted - 1, "someone whose line will not open is still counted")
local after = ns.Sightings.Days()
local day = ns.DayStart(now - 2 * DAY)
local function On(list)
    for _, entry in ipairs(list) do
        if entry.start == day then return entry.count end
    end
    return 0
end
Eq(On(after), On(days) - 1, "a day still counts someone nobody can show")
Eq(#ns.Sightings.OnDay(day), On(after), "the day's people and its count differ")
okay, why = pcall(Housekeeping)
Check(okay, "a torn line stopped the housekeeping -- " .. tostring(why))
Eq(ns.db.strangers[TORN], torn, "a torn line inside the buffer was thrown away")
Eq(ns.db.around[TORN], true, "someone whose line will not open left what names them")

-- Past the buffer it goes, as a record would, and they leave with it.
local stale = Torn(STALE, now - 400 * DAY)
ns.db.around[STALE] = true
Housekeeping()
Eq(ns.db.strangers[STALE], nil, "a torn line past the buffer is kept for ever")
Eq(ns.db.around[STALE], nil, "someone gone with their line is still named")
Eq(ns.db.strangers[TORN], torn, "the one inside the buffer went with it")
ns.db.strangers[TORN], ns.db.around[TORN] = nil, nil

-- A line and, beside it, rows that will not sort (one has no time): the
-- line stays, the rows stay, and the packing goes on to everyone else.
ns.Characters.Observe(MIXED, { first = "Ines", surname = "Roe", time = now - 3 * DAY })
ns.Sightings.Record(MIXED, { source = "plate" }, MULGORE, now - 3 * DAY)
ns.Strangers.Pack()
local sound = ns.db.strangers[MIXED]
local odd = { { time = now - 50, me = ME, mapID = 1413, src = "target" }, { me = ME, mapID = 1413 } }
rawset(ns.db.sightings, MIXED, odd)
Eq(ns.Strangers.Unpack(MIXED), nil, "a line was merged into rows that cannot be sorted")
Eq(ns.db.strangers[MIXED], sound, "a merge that failed lost the line")
Eq(rawget(ns.db.sightings, MIXED), odd, "a merge that failed replaced the rows")
Eq(#odd, 2, "a merge that failed changed the rows")
Eq(rawget(ns.db.characters, MIXED), nil, "a merge that failed left a record")
ns.Characters.Observe(FINE, { first = "Odo", surname = "Marsh", time = now - 60 })
okay, why = pcall(ns.Strangers.Pack)
Check(okay, "a merge that failed stopped the packing -- " .. tostring(why))
Eq(type(ns.db.strangers[FINE]), "string", "the packing stopped at the merge that failed")
ns.ForgetEverywhere(MIXED)

-- Rows as a table and a line with more of them, no record: the roll-up
-- folds the old one and keeps the line's two.
ns.Characters.Observe(ROLLED, { first = "Bram", surname = "Ash", time = now - 10 * DAY })
ns.Sightings.Record(ROLLED, { source = "plate" }, MULGORE, now - 10 * DAY)
ns.Sightings.Record(ROLLED, { source = "plate" }, MULGORE, now - 9 * DAY)
ns.Strangers.Pack()
Eq(type(ns.db.strangers[ROLLED]), "string", "not packed")
rawset(ns.db.sightings, ROLLED, { { time = now - 40 * DAY, me = ME, mapID = 1412, src = "plate" } })
ns.Sightings.Rollup(now)
Eq(#ns.Sightings.For(ROLLED), 2, "the roll-up lost the rows a line held")
Eq(ns.Characters.Get(ROLLED).sightingSummary.count, 1, "the roll-up did not fold the old row")

--------------------------------------------------------------------------
Section("every walk over the records and the sightings knows of the lines")

-- pairs(), next() or a count over db.characters or db.sightings finds the
-- people who are tables, not the packed strangers. Each walk in the
-- sources is counted here, by file, once it unpacks or counts the packed
-- first (ns.Strangers' helpers) or is known not to need them. A new one fails
-- this until it does the same and is added: asking by GUID needs nothing.
local WALKS = {
    ["Core/AutoAdd.lua"] = 1,       -- Waiting: UnpackSeenOften
    ["Core/Characters.lua"] = 3,    -- FindByName: UnpackNamed; Count: the lines counted; Prune: Strangers.Prune
    ["Core/JourneyRecap.lua"] = 1,  -- FirstSightings: UnpackThose (only the diary's and the buffer's can matter)
    ["Core/People.lua"] = 1,        -- PencilledCount: Strangers.Pencilled
    -- Forget(nil): DropRows; DeleteAll: a line has no `seen` to clear;
    -- Rollup: UnpackRolling; Count: Strangers.Count; Since and OnDay: UnpackSeen;
    -- Days: Strangers.Days.
    ["Core/Sightings.lua"] = 7,
}

-- The same stores named without a GUID asked of them and no walk on the
-- line: put in a local, a table or an argument, where a walk on another line
-- would not be seen above. Each is listed once whoever takes it is known to
-- ask by GUID only, or to unpack first.
local HANDED = {
    ["Core/Characters.lua"] = 1,    -- the store's Forget: wipe
    ["Core/Glimpse.lua"] = 1,       -- Hinge's ctx: asked by GUID
    -- Hinge and Why: asked by GUID (2); FirstSightings' guard, its walk
    -- listed above; the two ctx tables the plates and the recap build.
    ["Core/JourneyRecap.lua"] = 4,
    -- Record: ListFor asks by GUID; Forget(nil): wipe, with DropRows;
    -- Rollup: UnpackThose.
    ["Core/Sightings.lua"] = 3,
}

-- Dev/ is read as well: its two walks say what they count (the tables,
-- beside the lines' own numbers).
WALKS["Dev/Diagnostics.lua"] = 1
WALKS["Dev/SightingsDebug.lua"] = 1

local function Bare(code)
    for _, name in ipairs({ "db.characters", "db.sightings", "ctx.characters" }) do
        local from = 1
        while true do
            local _, stop = code:find(name, from, true)
            if not stop then break end
            if not code:find("^[%w_%[]", stop + 1) then return true end
            from = stop + 1
        end
    end
    return false
end

local found, handed, total, late = {}, {}, 0, nil
local sources = assert(io.popen("find Core Capture UI Features Dev -name '*.lua' 2>/dev/null | sort"))
for file in sources:lines() do
    total = total + 1
    for line in io.lines(file) do
        local code = line:gsub("%-%-.*$", "")
        local walks = code:find("pairs(", 1, true) or code:find("next(", 1, true) or code:find("CountKeys(", 1, true)
        local store = code:find("db.characters", 1, true) or code:find("db.sightings", 1, true)
            or code:find("ctx.characters", 1, true)
        if walks and store then
            found[file] = (found[file] or 0) + 1
        elseif file ~= "Core/Strangers.lua" and Bare(code) then
            handed[file] = (handed[file] or 0) + 1
        end
        if code:find("ADDONS_UNLOADING", 1, true) then late = file end
    end
end
sources:close()
-- Strangers.Close leaves the stores plain: nothing may follow it.
Check(late == nil, tostring(late)
    .. " listens past PLAYER_LOGOUT, after the strangers are packed and the stores no longer unpack")
Check(total >= 50, "the sources not found from " .. (os.getenv("PWD") or "?"))
for file, n in pairs(found) do
    Eq(n, WALKS[file] or 0, "walks over the records or the sightings in " .. file
        .. " (unpack or count the packed strangers first, Core/Strangers.lua, then list it in tests/strangers.lua)")
end
for file, n in pairs(WALKS) do
    Eq(found[file] or 0, n, "a walk listed for " .. file .. " is gone: take it off the list in tests/strangers.lua")
end
for file, n in pairs(handed) do
    Eq(n, HANDED[file] or 0, "the records or the sightings handed on whole in " .. file
        .. " (whoever takes them must ask by GUID or unpack first, then list it in tests/strangers.lua)")
end
for file, n in pairs(HANDED) do
    Eq(handed[file] or 0, n, "a hand-on listed for " .. file .. " is gone: take it off the list in tests/strangers.lua")
end
