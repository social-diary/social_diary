-- Strangers, packed (discussion #77; DAT-3).
--
-- Nearly everyone the diary knows is a stranger who walked past once: a
-- character record and a sighting row, kept for bufferDays in case they
-- come to matter. As tables that is five tables and some twenty values a
-- person, which SavedVariables writes a field a line: thirty thousand of
-- them came to 18 MB, and a game exit that hung for a minute.
--
-- So a stranger with nothing in the buffer -- outside the diary, not one of
-- the user's own, no interaction on record -- is saved packed, as the
-- route's segments are (Core/Journey.lua): one line of text, record and
-- rows together.
--
--   db.strangers[guid] = "identity;names;rows" or "identity;names;rows;summary"
--
--   identity  firstSeen,lastSeen,faction,class,race,sex,level,guild
--   names     first,surname[,firstSeen,lastSeen]            one a "/"
--   rows      time,last,level,mapID,x,y,me,src,hostile,zone,subZone   one a "/"
--   summary   first,last,count,levelMin,levelMax,hostile,days,lastDay,zones
--
-- Times after the first are seconds from the record's firstSeen (a row's
-- `last` from its own `time`); positions are thousandths of the map, as
-- Core/Location.lua rounds them; `me` is a place in db.strangerMe, the list of
-- the user's characters that wrote into this diary, which only ever grows.
--
-- Nothing else changes, and a packed stranger is no other kind of person.
-- In memory they are the same record in db.characters and the same rows in
-- db.sightings as before, and every reader gets them that way: they are
-- unpacked the first time anyone asks for that GUID (Attach, below), and
-- packed again at logout and at the next login (Pack). A diary saved
-- before strangers were packed is taken over by Core/DB.lua's
-- STEPS.diary[6]; both shapes are read wherever they are found all the
-- same, so a stranger who is a table is never in the way. What walks every
-- person instead of asking for one -- the roll-up, the Recently nearby
-- page's days, a search by name -- reads what it needs off the lines, or
-- unpacks the ones it wants first; each such place says so.
--
-- A line can say exactly what the tables said, or it is not written:
-- ToLine gives up on a field it does not know or a number it cannot spell,
-- and Pack reads every line it made back and compares before the tables
-- go. A record that does not fit simply stays a table, as all of them were.

local addonName, ns = ...

local Strangers = {}
ns.Strangers = Strangers

local find, sub, match, byte = string.find, string.sub, string.match, string.byte
local floor, concat = math.floor, table.concat

--------------------------------------------------------------------------
-- The words a line shortens
--------------------------------------------------------------------------

-- A class or race id says its token for these, so the line keeps the id
-- alone; any other pair is written out. Only ever a shorthand: a token that
-- is not here, or not the one its id has here, costs a few bytes more.
local CLASS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK",
    "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }
local RACE = { "Human", "Orc", "Dwarf", "NightElf", "Scourge", "Tauren", "Gnome", "Troll", "Goblin", "BloodElf",
    "Draenei" }

local FACTION = { Alliance = "A", Horde = "H", Neutral = "N" }
local SOURCE = { plate = "p", sweep = "w", target = "t", focus = "f", mouse = "m", say = "s", yell = "y",
    emote = "e" }

local function Flipped(codes)
    local words = {}
    for word, code in pairs(codes) do words[code] = word end
    return words
end
local FACTION_OF, SOURCE_OF = Flipped(FACTION), Flipped(SOURCE)

-- Everything a line can carry. A record, name, row or summary with any
-- other key stays a table: a field added later is kept, not dropped.
local RECORD = { guid = true, names = true, firstSeen = true, lastSeen = true, faction = true, level = true,
    class = true, classID = true, race = true, raceID = true, sex = true, guild = true, sightingSummary = true }
local NAME = { first = true, surname = true, firstSeen = true, lastSeen = true }
local ROW = { time = true, last = true, level = true, mapID = true, x = true, y = true, zone = true,
    subZone = true, hostile = true, src = true, me = true }
local SUMMARY = { first = true, last = true, count = true, levelMin = true, levelMax = true, hostile = true,
    zones = true, days = true, lastDay = true }

--------------------------------------------------------------------------
-- One line
--------------------------------------------------------------------------

local function Fits(t, allowed)
    for key in pairs(t) do
        if not allowed[key] then return false end
    end
    return true
end

-- A list with nothing but its 1..n.
local function Listed(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n == #t
end

-- A number tostring writes in full and tonumber reads back the same.
local function Whole(n)
    return type(n) == "number" and n == floor(n) and n > -1e12 and n < 1e12
end

local function Word(s)
    return type(s) == "string" and s ~= ""
end

-- Free text: the separators, the marks and the escape sign itself, as %XX.
local function Escape(s)
    return (s:gsub("[%%;,/:=!]", function(c) return ("%%%02X"):format(byte(c)) end))
end

local function Unescape(s)
    return (s:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function Num(n)
    if n == nil then return "" end
    return tostring(n)
end

local function Text(s)
    if s == nil then return "" end
    return Escape(s)
end

-- A token and its id: "8" where the id says the token, "8:TOKEN" where it
-- does not, "8:!" for an id alone, ":TOKEN" for a token alone, "" for neither.
local function Pair(token, id, known)
    if id == nil then return token == nil and "" or (":" .. Escape(token)) end
    if token ~= nil and known[id] == token then return Num(id) end
    return Num(id) .. ":" .. (token == nil and "!" or Escape(token))
end

local function Unpair(text, known)
    if text == "" then return nil, nil end
    local id, token = match(text, "^(%-?%d*):(.*)$")
    if not id then
        id = tonumber(text)
        return known[id], id
    end
    id = id ~= "" and tonumber(id) or nil
    if token == "!" then return nil, id end
    return Unescape(token), id
end

-- A word with a one-letter code, or itself behind "=".
local function Coded(word, codes)
    if word == nil then return "" end
    return codes[word] or ("=" .. Escape(word))
end

local function Uncoded(text, words)
    if text == "" then return nil end
    if byte(text) == 61 then return Unescape(sub(text, 2)) end
    return words[text]
end

-- Which of the user's characters, as its place in the list.
local function Hand(hands, guid)
    for i = 1, #hands do
        if hands[i] == guid then return i end
    end
    hands[#hands + 1] = guid
    return #hands
end

-- A position as thousandths, or nothing where it is not one exactly.
local function Thousandths(v)
    local n = floor(v * 1000 + 0.5)
    if n / 1000 == v then return n end
end

local function SummaryToLine(s, first)
    if type(s) ~= "table" or not Fits(s, SUMMARY) then return nil end
    for key in pairs(SUMMARY) do
        if key ~= "zones" and s[key] ~= nil and not Whole(s[key]) then return nil end
    end

    local zones = ""
    if s.zones ~= nil then
        if type(s.zones) ~= "table" or next(s.zones) == nil then return nil end
        local list = {}
        for key, n in pairs(s.zones) do
            if not Whole(n) then return nil end
            if Whole(key) then
                list[#list + 1] = Num(key) .. ":" .. Num(n)
            elseif Word(key) then
                list[#list + 1] = "=" .. Escape(key) .. ":" .. Num(n)
            else
                return nil
            end
        end
        table.sort(list)
        zones = concat(list, "/")
    end

    return concat({ Num(s.first and s.first - first), Num(s.last and s.last - first), Num(s.count),
        Num(s.levelMin), Num(s.levelMax), Num(s.hostile), Num(s.days), Num(s.lastDay and s.lastDay - first),
        zones }, ",")
end

-- The record and its rows as a line, or nil where a line cannot say them
-- exactly. `rows` may be nil: someone on record who was never sighted.
local function ToLine(guid, record, rows, hands)
    if type(record) ~= "table" or not Fits(record, RECORD) then return nil end
    if record.guid ~= guid then return nil end

    local first, last = record.firstSeen, record.lastSeen
    if not (Whole(first) and Whole(last)) then return nil end
    for _, key in ipairs({ "level", "sex", "classID", "raceID" }) do
        if record[key] ~= nil and not Whole(record[key]) then return nil end
    end
    for _, key in ipairs({ "faction", "class", "race", "guild" }) do
        if record[key] ~= nil and not Word(record[key]) then return nil end
    end

    local head = concat({ Num(first), Num(last - first), Coded(record.faction, FACTION),
        Pair(record.class, record.classID, CLASS), Pair(record.race, record.raceID, RACE),
        Num(record.sex), Num(record.level), Text(record.guild) }, ",")

    if type(record.names) ~= "table" or not Listed(record.names) then return nil end
    local names = {}
    for i, name in ipairs(record.names) do
        if type(name) ~= "table" or not Fits(name, NAME) then return nil end
        if not Word(name.first) or (name.surname ~= nil and not Word(name.surname)) then return nil end
        if not (Whole(name.firstSeen) and Whole(name.lastSeen)) then return nil end
        -- The one name most people have was first and last seen when they were.
        if name.firstSeen == first and name.lastSeen == last then
            names[i] = Escape(name.first) .. "," .. Text(name.surname)
        else
            names[i] = concat({ Escape(name.first), Text(name.surname), Num(name.firstSeen - first),
                Num(name.lastSeen - first) }, ",")
        end
    end

    local lines = {}
    if rows ~= nil then
        if type(rows) ~= "table" or #rows == 0 or not Listed(rows) then return nil end
        for i, row in ipairs(rows) do
            if type(row) ~= "table" or not Fits(row, ROW) then return nil end
            if not Whole(row.time) or ns.SafeGUID(row.me) == nil then return nil end
            for _, key in ipairs({ "last", "level", "mapID" }) do
                if row[key] ~= nil and not Whole(row[key]) then return nil end
            end
            for _, key in ipairs({ "zone", "subZone", "src" }) do
                if row[key] ~= nil and not Word(row[key]) then return nil end
            end
            if row.hostile ~= nil and row.hostile ~= true then return nil end

            local x, y = row.x, row.y
            if x ~= nil then
                x = type(x) == "number" and Thousandths(x)
                if not x then return nil end
            end
            if y ~= nil then
                y = type(y) == "number" and Thousandths(y)
                if not y then return nil end
            end

            lines[i] = concat({ Num(row.time - first), Num(row.last and row.last - row.time), Num(row.level),
                Num(row.mapID), Num(x), Num(y), Num(Hand(hands, row.me)), Coded(row.src, SOURCE),
                row.hostile and "1" or "", Text(row.zone), Text(row.subZone) }, ",")
        end
    end

    local line = head .. ";" .. concat(names, "/") .. ";" .. concat(lines, "/")
    if record.sightingSummary ~= nil then
        local summary = SummaryToLine(record.sightingSummary, first)
        if not summary then return nil end
        line = line .. ";" .. summary
    end
    return line
end

local function Split(text, sep)
    local list, from = {}, 1
    while true do
        local at = find(text, sep, from, true)
        if not at then
            list[#list + 1] = sub(text, from)
            return list
        end
        list[#list + 1] = sub(text, from, at - 1)
        from = at + 1
    end
end

local function N(s)
    if s ~= "" then return tonumber(s) end
end

local function S(s)
    if s ~= "" then return Unescape(s) end
end

local function SummaryFromLine(text, first)
    local f = Split(text, ",")
    local function From(s)
        local n = N(s)
        return n and first + n
    end
    local summary = { first = From(f[1]), last = From(f[2]), count = N(f[3]), levelMin = N(f[4]),
        levelMax = N(f[5]), hostile = N(f[6]), days = N(f[7]), lastDay = From(f[8]) }
    if f[9] ~= "" then
        summary.zones = {}
        for _, entry in ipairs(Split(f[9], "/")) do
            local key, n = match(entry, "^(.*):(%-?%d+)$")
            if byte(key) == 61 then key = Unescape(sub(key, 2)) else key = tonumber(key) end
            summary.zones[key] = tonumber(n)
        end
    end
    return summary
end

-- A line as the record and the rows it was made from (rows nil where
-- there were none). Raises on a line that is not one: callers pcall.
local function FromLine(guid, line, hands)
    local part = Split(line, ";")
    local h = Split(part[1], ",")
    local first = tonumber(h[1])
    local record = { guid = guid, firstSeen = first, lastSeen = first + tonumber(h[2]), names = {} }
    record.faction = Uncoded(h[3], FACTION_OF)
    record.class, record.classID = Unpair(h[4], CLASS)
    record.race, record.raceID = Unpair(h[5], RACE)
    record.sex, record.level, record.guild = N(h[6]), N(h[7]), S(h[8])

    if part[2] ~= "" then
        for i, entry in ipairs(Split(part[2], "/")) do
            local f = Split(entry, ",")
            record.names[i] = { first = Unescape(f[1]), surname = S(f[2]),
                firstSeen = f[3] and first + tonumber(f[3]) or record.firstSeen,
                lastSeen = f[4] and first + tonumber(f[4]) or record.lastSeen }
        end
    end

    local rows
    if part[3] ~= "" then
        rows = {}
        for i, entry in ipairs(Split(part[3], "/")) do
            local f = Split(entry, ",")
            local time = first + tonumber(f[1])
            local x, y = N(f[5]), N(f[6])
            rows[i] = { time = time, last = f[2] ~= "" and time + tonumber(f[2]) or nil, level = N(f[3]),
                mapID = N(f[4]), x = x and x / 1000, y = y and y / 1000, me = hands[tonumber(f[7])],
                src = Uncoded(f[8], SOURCE_OF), hostile = f[9] == "1" or nil, zone = S(f[10]),
                subZone = S(f[11]) }
        end
    end

    if part[4] then record.sightingSummary = SummaryFromLine(part[4], first) end
    return record, rows
end

ns._test.StrangerToLine, ns._test.StrangerFromLine = ToLine, FromLine

local function Same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not Same(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

--------------------------------------------------------------------------
-- Reading a line without unpacking it
--------------------------------------------------------------------------

-- firstSeen, and where the rows begin and end in the line (`from` past
-- `to` where there are none). Nil for a line that is not one.
local function Parts(line)
    local a = find(line, ";", 1, true)
    local b = a and find(line, ";", a + 1, true)
    if not b then return nil end
    local first = tonumber(match(line, "^%-?%d+"))
    if not first then return nil end
    local c = find(line, ";", b + 1, true)
    return first, b + 1, c and c - 1 or #line
end

-- The next row at `at`: its time, its last, and where the one after begins.
local function Span(line, first, at)
    local _, stop, dt, dl = find(line, "^(%-?%d+),(%-?%d*),[^/;]*", at)
    if not stop then return nil end
    local time = first + dt
    return time, dl ~= "" and time + dl or time, stop + 2
end

local function LastSeen(line)
    local first, more = match(line, "^(%-?%d+),(%-?%d+)")
    return first and first + more
end

--------------------------------------------------------------------------
-- The store
--------------------------------------------------------------------------

-- A line that would not unpack, by GUID: left where it is, not tried again
-- on every lookup this session.
local broken = {}

-- A packed stranger, for Stays: no record to ask.
local LINE = {}

-- The spans UnpackSeen has been over every line for, since a line was last
-- written: nobody seen in one is still packed, so asking again (the
-- Recently nearby page, at every refresh) need not read them all again.
local swept, sweptCount = {}, 0

local function Unswept()
    wipe(swept)
    sweptCount = 0
end

local function Lines(d)
    if type(d.strangers) ~= "table" then d.strangers = {} end
    return d.strangers
end

local function Hands(d)
    if type(d.strangerMe) ~= "table" then d.strangerMe = {} end
    return d.strangerMe
end

-- The lines one by one: `for guid, line in NextLine, lines`. A value that
-- is not text (a save damaged, or edited by hand) is nobody's line: it is
-- passed over and left where it is, and no walk stops at it.
local function NextLine(lines, guid)
    local line
    repeat
        guid, line = next(lines, guid)
    until guid == nil or type(line) == "string"
    return guid, line
end

-- Whether `guid` is packed: a line of theirs is in the diary, opened or not.
function Strangers.Packed(guid)
    local d = ns.db
    return d ~= nil and type(d.strangers) == "table" and type(d.strangers[guid]) == "string"
end

-- `guid` unpacked into the stores: the record into db.characters and the
-- rows into db.sightings, where every reader looks. Returns the record.
--
-- A record already there is the newer word on them (it can only be, with a
-- line still about, if the stores were written past this file), so it
-- stays, and the line gives it what it alone held: the older rows, an
-- earlier first sighting, a summary.
--
-- Everything that can fail is done before anything is written: a line that
-- does not open, or one that will not go together with what is beside it (a
-- record that is not one, a row without its time), is left as it is, with
-- the tables as they were, and marked broken for the session.
function Strangers.Unpack(guid)
    local d = ns.db
    if not d then return nil end
    local lines = Lines(d)
    local line = lines[guid]
    if type(line) ~= "string" or broken[guid] == line then return nil end

    local characters, sightings = d.characters, d.sightings
    local there, newer = rawget(characters, guid), rawget(sightings, guid)

    local ok, record, rows = pcall(function()
        local record, rows = FromLine(guid, line, Hands(d))
        assert(Whole(record.firstSeen) and Whole(record.lastSeen))
        if there ~= nil then
            assert(type(there) == "table")
            assert(there.firstSeen == nil or type(there.firstSeen) == "number")
        end
        if newer ~= nil then
            assert(type(newer) == "table")
            if rows then
                for i = 1, #newer do rows[#rows + 1] = newer[i] end
                table.sort(rows, function(a, b) return a.time < b.time end)
            else
                rows = newer
            end
        end
        return record, rows
    end)
    if not ok then
        broken[guid] = line
        return nil
    end

    lines[guid] = nil
    if there then
        if record.firstSeen < (there.firstSeen or math.huge) then there.firstSeen = record.firstSeen end
        there.sightingSummary = there.sightingSummary or record.sightingSummary
    else
        rawset(characters, guid, record)
    end
    if rows then rawset(sightings, guid, rows) end

    return rawget(characters, guid)
end

-- Asked for someone who is not there as a table: unpacked, if packed.
local UNPACKS = {
    __index = function(store, guid)
        local d = ns.db
        local lines = d and d.strangers
        if not lines or lines[guid] == nil then return nil end
        Strangers.Unpack(guid)
        return rawget(store, guid)
    end,
}

-- db.characters[guid] and db.sightings[guid] unpack a packed stranger, so
-- no reader has to know anyone is packed. On the diary in use; again after
-- anything that replaces the two tables (ns.WipeData).
function Strangers.Attach()
    local d = ns.db
    if not d then return end
    Lines(d)
    Hands(d)
    for _, key in ipairs({ "characters", "sightings" }) do
        local store = d[key]
        if type(store) == "table" and getmetatable(store) ~= UNPACKS then setmetatable(store, UNPACKS) end
    end
end

local function Detach()
    local d = ns.db
    if not d then return end
    for _, key in ipairs({ "characters", "sightings" }) do
        local store = d[key]
        if type(store) == "table" and getmetatable(store) == UNPACKS then setmetatable(store, nil) end
    end
end

-- Whether `guid` has to stay a table: the diary's people and the user's own
-- keep their history as it is, and someone in the buffer may come to
-- matter (Core/JourneyRecap.lua walks the records for those).
local function Stays(d, guid, record, own)
    return record.isSelf or guid == ns.ownGUID or own[guid] ~= nil
        or (type(d.diary) == "table" and d.diary[guid] ~= nil)
        or (type(d.interactions) == "table" and d.interactions[guid] ~= nil)
end

-- Every stranger who can be, packed: in the diary in use, or in `d`, a
-- diary as saved. Each line is read back and compared before the tables
-- go: one that does not come back the same is not kept. Returns how many
-- were packed.
function Strangers.Pack(d)
    d = d or ns.db
    if not d or type(d.characters) ~= "table" then return 0 end
    local characters = d.characters
    local sightings = type(d.sightings) == "table" and d.sightings or {}
    local lines, hands = Lines(d), Hands(d)
    local own = ns.OwnCharacters() or {}

    local n = 0
    for guid, record in pairs(characters) do
        if ns.SafeGUID(guid) and type(record) == "table" and not Stays(d, guid, record, own) then
            -- A line of them as well (Unpack says how that can be): the
            -- record takes what it held, and the two go on as one.
            if lines[guid] ~= nil and d == ns.db then Strangers.Unpack(guid) end
            local rows = rawget(sightings, guid)
            local ok, line = pcall(ToLine, guid, record, rows, hands)
            if ok and line and lines[guid] == nil then
                local read, back, backRows = pcall(FromLine, guid, line, hands)
                if read and Same(record, back) and Same(rows, backRows) then
                    lines[guid] = line
                    characters[guid] = nil
                    if rows ~= nil then sightings[guid] = nil end
                    n = n + 1
                end
            end
        end
    end
    if n > 0 then Unswept() end
    return n
end

-- /sd sightings unpack (Dev/): this session is saved as tables, the diary
-- as it was before strangers were packed, for a build without this file to
-- read. The next login under this one packs them again.
local held = false

function Strangers.Hold(on)
    held = on and true or false
end

-- PLAYER_LOGOUT, once every handler of it has run (Core/Events.lua): the
-- strangers are packed again, and the two stores are left plain tables for
-- the client to write. From here on they no longer unpack: asking for a
-- packed stranger finds nobody, and writing to one would put a blank record
-- beside their line. So nothing may run after this in a logout, and no
-- source listens for ADDONS_UNLOADING, the one event that follows
-- (tests/strangers.lua holds that).
function Strangers.Close()
    Strangers.Attach()
    local n = 0
    if held then Strangers.UnpackAll() else n = Strangers.Pack() end
    Detach()
    return n
end

-- PRV-3, before the stores below it in the list: someone forgotten who is
-- still packed must not be unpacked by a later store asking after them.
-- Everyone (ns.WipeData): the diary is fresh tables by then, so they are
-- attached again.
ns.RegisterStore("strangers", function(guid)
    local d = ns.db
    if not d then return end
    if guid == nil then
        wipe(Lines(d))
        wipe(Hands(d))
        wipe(broken)
        Unswept()
        Strangers.Attach()
        return
    end
    Lines(d)[guid] = nil
    broken[guid] = nil
end)

--------------------------------------------------------------------------
-- For what walks everyone
--------------------------------------------------------------------------
--
-- pairs() over db.characters or db.sightings finds the people who are
-- tables. Each walk that must not miss a packed stranger calls one of
-- these first: to unpack the ones it is about, or to count them as they are.

local function Each()
    if not ns.db then return NextLine, {} end
    Strangers.Attach()
    return NextLine, Lines(ns.db)
end

function Strangers.UnpackAll()
    local n = 0
    for guid in Each() do
        if Strangers.Unpack(guid) then n = n + 1 end
    end
    return n
end

-- Those among `keys` (a table keyed by GUID: the diary, the buffer).
function Strangers.UnpackThose(keys)
    if type(keys) ~= "table" or not ns.db then return end
    local lines = Lines(ns.db)
    if next(lines) == nil then return end
    for guid in pairs(keys) do
        if lines[guid] ~= nil then Strangers.Unpack(guid) end
    end
end

-- Those with a row that began before `cutoff`: the roll-up's (SIG-7).
function Strangers.UnpackRolling(cutoff)
    for guid, line in Each() do
        local first, from, to = Parts(line)
        if first and from <= to then
            local time = Span(line, first, from)
            if time and time < cutoff then Strangers.Unpack(guid) end
        end
    end
end

-- Those with a row that began before `to` and was last seen at or after
-- `from`: a day's people, or everyone seen since.
function Strangers.UnpackSeen(from, to)
    local span = from .. ":" .. to
    if swept[span] then return end

    for guid, line in Each() do
        local first, at, stop = Parts(line)
        while first and at <= stop do
            local time, last, after = Span(line, first, at)
            if not time then break end
            if time < to and last >= from then
                Strangers.Unpack(guid)
                break
            end
            at = after
        end
    end

    -- "Since" is asked with a new moment each time: not kept without end.
    if sweptCount >= 64 then Unswept() end
    swept[span], sweptCount = true, sweptCount + 1
end

-- Those with at least `n` rows.
function Strangers.UnpackSeenOften(n)
    for guid, line in Each() do
        local first, at, stop = Parts(line)
        if first and at <= stop then
            local rows = 1
            while rows < n do
                at = find(line, "/", at, true)
                if not at or at > stop then break end
                rows, at = rows + 1, at + 1
            end
            if rows >= n then Strangers.Unpack(guid) end
        end
    end
end

-- Those with `first` (lower case, as Characters.FindByName compares) among
-- their names. A wide net: the caller compares the names properly.
function Strangers.UnpackNamed(first)
    local needle = Escape(first):lower()
    for guid, line in Each() do
        local a = find(line, ";", 1, true)
        local b = a and find(line, ";", a + 1, true)
        if b and find(sub(line, a + 1, b - 1):lower(), needle, 1, true) then Strangers.Unpack(guid) end
    end
end

-- Sightings.Days for the packed: one more in `people[day]` for each day a
-- packed stranger's rows touch. `DayOf` is the caller's day finder.
function Strangers.Days(people, DayOf)
    local on = {}
    for guid, line in Each() do
        local first, at, stop = Parts(line)
        if first and at <= stop and broken[guid] ~= line then
            local time, last, after = Span(line, first, at)
            if time and after > stop then
                -- One row, as most have: no set to keep.
                local day, lastDay = DayOf(time), DayOf(last)
                people[day] = (people[day] or 0) + 1
                if lastDay ~= day then people[lastDay] = (people[lastDay] or 0) + 1 end
            else
                while time do
                    on[DayOf(time)] = true
                    on[DayOf(last)] = true
                    if after > stop then break end
                    time, last, after = Span(line, first, after)
                end
                for day in pairs(on) do
                    people[day] = (people[day] or 0) + 1
                    on[day] = nil
                end
            end
        end
    end
end

-- A line found broken this session is nobody until it opens: no reader can
-- show them, so no count has them either (the Recently nearby page's days
-- would list a day with nobody on it).

-- How many strangers are packed: Characters.Count's.
function Strangers.People()
    local n = 0
    if not ns.db then return 0 end
    for guid, line in NextLine, Lines(ns.db) do
        if broken[guid] ~= line then n = n + 1 end
    end
    return n
end

-- How many strangers are packed, how many of them were sighted, and their rows.
function Strangers.Count()
    local people, sighted, rows = 0, 0, 0
    if not ns.db then return 0, 0, 0 end
    for guid, line in NextLine, Lines(ns.db) do
        local first, at, stop = Parts(line)
        if broken[guid] == line then
            first = nil
        else
            people = people + 1
        end
        if first and at <= stop then
            sighted = sighted + 1
            rows = rows + 1
            while true do
                at = find(line, "/", at, true)
                if not at or at > stop then break end
                rows, at = rows + 1, at + 1
            end
        end
    end
    return people, sighted, rows
end

-- People.PencilledCount for the packed: those sighted, but for `seen`
-- (already counted), the user's own and the diary's.
function Strangers.Pencilled(seen)
    local n = 0
    if not ns.db then return 0 end
    for guid, line in NextLine, Lines(ns.db) do
        local first, at, stop = Parts(line)
        if first and at <= stop and broken[guid] ~= line and not seen[guid] and guid ~= ns.ownGUID
            and not ns.Diary.IsDiary(guid) then
            n = n + 1
        end
    end
    return n
end

-- Characters.Prune for the packed: one with no row left and not seen
-- since `cutoff` goes, as a record would. Returns how many went.
--
-- So does a line found broken this session and not seen since `cutoff`,
-- rows or not: the roll-up could not open it to fold them, and nothing
-- else ever would. Only where its head still says when, and nothing of
-- theirs is a table beside it (then the line may be sound and the table
-- the trouble). A line whose head cannot be read is left alone.
function Strangers.Prune(cutoff)
    local d = ns.db
    if not d then return 0 end
    local lines, own = Lines(d), ns.OwnCharacters() or {}
    local dropped = 0
    for guid, line in NextLine, lines do
        local first, at, stop = Parts(line)
        local unread = broken[guid] == line and rawget(d.characters, guid) == nil
            and rawget(d.sightings, guid) == nil
        if first and (at > stop or unread) and not Stays(d, guid, LINE, own) then
            local last = LastSeen(line)
            if last and last < cutoff then
                lines[guid] = nil
                broken[guid] = nil
                dropped = dropped + 1
            end
        end
    end
    return dropped
end

-- The other bound beside bufferDays (the setting `strangerLimit`): at most
-- `limit` strangers are kept, and past it those seen longest ago go, record
-- and sightings, whichever shape they are saved in. A stranger here is who
-- Pack would pack: outside the diary, not the user's own, nothing in the
-- interaction buffer. Everyone else is neither counted nor touched. A line
-- whose head cannot be read is left alone. Returns how many went.
function Strangers.Limit(limit)
    local d = ns.db
    if not d then return 0 end
    limit = limit or ns.PositiveSetting("strangerLimit")
    local lines, own = Lines(d), ns.OwnCharacters() or {}

    local guids, seen, n = {}, {}, 0
    for guid, line in NextLine, lines do
        local last = LastSeen(line)
        if last and rawget(d.characters, guid) == nil and not Stays(d, guid, LINE, own) then
            n = n + 1
            guids[n], seen[n] = guid, last
        end
    end
    for guid, record in pairs(d.characters) do
        if ns.SafeGUID(guid) and type(record) == "table" and not Stays(d, guid, record, own) then
            n = n + 1
            guids[n], seen[n] = guid, record.lastSeen or record.firstSeen or 0
        end
    end

    local over = n - limit
    if over <= 0 then return 0 end

    -- The time the last one to go was seen at; those seen at that very
    -- second go only until the count is right.
    local sorted = {}
    for i = 1, n do sorted[i] = seen[i] end
    table.sort(sorted)
    local edge = sorted[over]
    local atEdge = 0
    for i = 1, over do
        if sorted[i] == edge then atEdge = atEdge + 1 end
    end

    local dropped = 0
    for i = 1, n do
        local go = seen[i] < edge
        if not go and seen[i] == edge and atEdge > 0 then
            go, atEdge = true, atEdge - 1
        end
        if go then
            local guid = guids[i]
            lines[guid] = nil
            broken[guid] = nil
            d.characters[guid] = nil
            d.sightings[guid] = nil
            dropped = dropped + 1
        end
    end
    return dropped
end

-- Sightings.Forget(nil) for the packed: the rows and the summaries go,
-- who they were stays.
function Strangers.DropRows()
    local d = ns.db
    if not d then return end
    local lines = Lines(d)
    for guid, line in NextLine, lines do
        local a = find(line, ";", 1, true)
        local b = a and find(line, ";", a + 1, true)
        if b and b < #line then lines[guid] = sub(line, 1, b) end
    end
end

-- The lines' size as saved, for /sd sightings packed (Dev/).
function Strangers.Bytes()
    local bytes = 0
    if not ns.db then return 0 end
    for guid, line in NextLine, Lines(ns.db) do bytes = bytes + #guid + #line + 11 end
    return bytes
end

-- Lines that would not unpack this session.
function Strangers.Broken()
    return ns.CountKeys(broken)
end
