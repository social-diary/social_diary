-- The timeline's words (JNL-2, TLN-2 to TLN-6, TLN-10): what each timeline item says
-- on the profile's page, and in its tooltip.
--
-- Pure functions over ns.Timeline's items, no frames: the page
-- (UI/Journal/Timeline.lua) lays the lines out, this file only writes them.
-- What an episode's rows add up to is Core/Timeline.lua's (Timeline.Tally).

local addonName, ns = ...

local Format = ns.UI.Format
local L, Fmt = ns.L, ns.Fmt
local G = ns.Locale.grammar

local Tally = ns.Timeline.Tally

--------------------------------------------------------------------------
-- Describing timeline items
--------------------------------------------------------------------------

-- A list read out comma by comma ("2x [Linen Cloth], [Copper Ore]"), each
-- join a whole template a language may change: `template` "%1$s, %2$s##list"
-- unless given.
local function Join(list, template)
    local text = list[1]
    for i = 2, #list do text = Fmt(template or L["%1$s, %2$s##list"], text, list[i]) end
    return text or ""
end

local function Items(list)
    local parts = {}
    for i = 1, #list do
        local item = list[i]
        parts[#parts + 1] = (item.count and item.count > 1) and Fmt(L["%1$dx %2$s"], item.count, item.link)
            or item.link
    end
    return Join(parts)
end

local function Quote(text, fallback)
    if not text then return fallback end
    return Fmt(L["%1$s: \"%2$s\""], fallback, text)
end

local ROW_TEXT = {
    group_join = function(row)
        return (row.context and row.context.raid) and L["Raided together"] or L["Grouped"]
    end,
}

-- "in Hillsbrad Foothills", the row's zone as one phrase (ns.ZoneIn, for a
-- template whose key is marked "##zone"), or nil: no zone, or `unplaced`
-- (the kind's text was asked without its place, as the plate's tooltips
-- leave the place to the map). A feature's row, through
-- ns.UI.TimelineText.Place.
local function Place(row, unplaced)
    if unplaced or not row.zone then return nil end
    return ns.ZoneIn(row.mapID, row.zone)
end

-- The creature a row's context names ({ name, rank }, as a witness's row
-- keeps it) as Your Diary names a killer ("a Sunscale Lashtail",
-- Text.KillerName), or nil.
local function Foe(row)
    local c = row.context or {}
    return ns.UI.JourneyText.KillerName({ name = c.name, rank = c.rank })
end

-- Each kind's icon, a Style.ART key.
local ROW_ICON = {
    group_join = "together",
}

-- Told to each kind (Core/Rows.lua: `text`, `icon`), where the page reads
-- them; a feature's own kinds tell theirs from its own folder.
for kind, text in pairs(ROW_TEXT) do ns.Rows.Register(kind, { text = text }) end
for kind, icon in pairs(ROW_ICON) do ns.Rows.Register(kind, { icon = icon }) end

-- "You died to Plainstrider (3 attackers) near Red Cloud Mesa", "Gunther
-- died, probably to Plainstrider". A death on this page is theirs or the
-- user's (Timeline's NewSession), so one that is not theirs is "You".
-- `there`: the line above named the place already, so this one says
-- "there" instead of naming it again.
-- The environment's damage (the combat log's English token, lower case)
-- in the reader's words.
local ENVIRONMENT = { falling = L["falling##death"], drowning = L["drowning##death"],
    fatigue = L["fatigue##death"], fire = L["fire##death"], lava = L["lava##death"], slime = L["slime##death"] }

-- The sentence, one whole template for each how and where: how they died
-- (`plain`, the environment's `env`, a killer the death recap named `to`,
-- one the diary guessed `probably`), and where (`alone`, `there`, or the
-- place's phrase, `near`: the subzone, else the zone). Theirs take the name
-- first.
local DIED = {
    theirs = {
        plain = { alone = L["%s died"], there = L["%s died there"], near = L["%1$s died %2$s##zone"] },
        env = { alone = L["%1$s died (%2$s)"], there = L["%1$s died (%2$s) there"],
            near = L["%1$s died (%2$s) %3$s##zone"] },
        to = { alone = L["%1$s died to %2$s"], there = L["%1$s died to %2$s there"],
            near = L["%1$s died to %2$s %3$s##zone"] },
        probably = { alone = L["%1$s died, probably to %2$s"], there = L["%1$s died, probably to %2$s there"],
            near = L["%1$s died, probably to %2$s %3$s##zone"] },
    },
    you = {
        plain = { alone = L["{You} died"], there = L["{You} died there"], near = L["{You} died %s##zone"] },
        env = { alone = L["{You} died (%s)"], there = L["{You} died (%s) there"],
            near = L["{You} died (%1$s) %2$s##zone"] },
        to = { alone = L["{You} died to %s"], there = L["{You} died to %s there"],
            near = L["{You} died to %1$s %2$s##zone"] },
        probably = { alone = L["{You} died, probably to %s"], there = L["{You} died, probably to %s there"],
            near = L["{You} died, probably to %1$s %2$s##zone"] },
    },
}

local function DeathText(death, guid, there)
    local how, what = "plain", nil
    local killer = death.killer
    local name = killer and (killer.player and killer.guid and ns.Characters.FullName(killer.guid) or killer.name)
    if killer and killer.environment and not name then
        local env = killer.environment:lower()
        how, what = "env", ENVIRONMENT[env] or env
    elseif name then
        what = killer.spell and Fmt(L["%1$s's %2$s"], name, killer.spell) or name
        if (killer.attackers or 0) > 1 then
            what = ns.Plural(killer.attackers, L["%1$s (%2$d attacker)|%1$s (%2$d attackers)##plural"],
                what, killer.attackers)
        end
        how = killer.source == "recap" and "to" or "probably"
    end

    local sub = death.subZone
    if sub == "" or sub == death.zone then sub = nil end
    local place = sub or death.zone
    local where, zone = "alone", nil
    if there and place then
        where = "there"
    elseif place then
        where, zone = "near", ns.ZoneIn(nil, place, "near")
    end

    -- The values in order: the name (theirs), what, the place.
    local values = {}
    local theirs = death.guid == guid
    if theirs then values[1] = ns.Characters.Name(guid) or L["They"] end
    if what then values[#values + 1] = what end
    if zone then values[#values + 1] = zone end
    local template = DIED[theirs and "theirs" or "you"][how][where]
    if not theirs then template = Format.You(death.guid, template) end
    return Fmt(template, unpack(values))
end

-- "Mulgore", "Mulgore and The Barrens", "Mulgore and around", and how many
-- places there were. Never more than two names. A zone the client had no
-- name for when it was written down (an empty string: Core/Location.lua's
-- ns.Where takes GetRealZoneText's "" during a loading screen, and
-- Core/Sessions.lua's TrackZone keeps it) is no place, and is left out;
-- one written down again on coming back is the same place (20 and 21 Oct,
-- in the client: "Quested together for 2 h 36 min through , Stormwind City
-- and 23 more", and "Stormwind City, Deeprun Tram and 22 more").
--
-- `role`, a function of the count, makes it the phrase a "##zone" template
-- takes (ns.ZoneIn: "in Mulgore", "through Mulgore and The Barrens", "in
-- Mulgore and around"); the rows keep names, not ids, so the first name
-- takes the preposition.
local function Places(zones, role)
    local named = ns.Timeline.Unique(zones)
    if #named == 0 then return nil, 0 end
    local first = named[1]
    if role then first = ns.ZoneIn(nil, first, role(#named)) end
    if #named == 1 then return first, 1 end
    if #named == 2 then return Fmt(L["%1$s and %2$s"], first, named[2]), 2 end
    return Fmt(L["%s and around"], first), #named
end

-- A headline's places: "through" two, else "in".
local function Through(count) return count == 2 and "through" or "in" end
local function Around() return "around" end


-- Episodes (ns.Timeline) carry their children; nothing else does.
local function IsEpisode(item)
    return item ~= nil and item.all ~= nil
end

-- "Mor'Ladim", "Mor'Ladim and Rakk", "Mor'Ladim and 2 more". `max` names at
-- most that many.
local function RareNames(rares, max)
    local names = {}
    for i = 1, #rares do names[i] = rares[i].name or L["a rare"] end
    return Format.List(names, max and { max = max }) or ""
end

-- The participant's rare kills, one per rare: a respawn killed again in the
-- same session (Sessions.Rare keeps every kill) is named once, by its npc
-- id, or by its name where an older kill has none. The moment lines stay
-- one per kill.
local function Rares(episode)
    local kills = episode.participant and episode.participant.rares or {}
    local rares, seen = {}, {}
    for i = 1, #kills do
        local kill = kills[i]
        local key = kill.npcID or kill.name or i
        if not seen[key] then
            seen[key] = true
            rares[#rares + 1] = kill
        end
    end
    return rares
end

-- TLN-2's activities in words: how one opens a headline, and how it is
-- added after the first.
local LEAD = {
    quest = L["Quested together"],
    rare = L["Hunted together"],
    group = L["Grouped"],
    trade = L["Traded"],
    chat = L["Chatted"],
    other = L["Crossed paths"],
}

-- The headline and its extras are clauses, not names: "Quested together,
-- killed Mor'Ladim, and traded".
local CLAUSES = { oxford = true }

local EXTRA = {
    quest = L["quested together"],
    rare = function(episode) return Fmt(L["killed %s##timeline"], RareNames(Rares(episode), 1)) end,
    group = L["grouped"],
    trade = L["traded"],
    chat = L["chatted"],
    other = L["crossed paths"],
}

local ACTIVITY_ICON = { quest = "together", rare = "rare", group = "together", trade = "trade",
    chat = "talk", other = "talk" }

-- "Quested together for 3 h 5 min through Westfall and Duskwood, killed
-- Mor'Ladim, and traded".
local function Headline(episode, activities)
    local lead = LEAD[activities[1]] or L["Together"]
    local timed = episode.kind == "session" or episode.seconds >= 60
    local places = Places(episode.zones, Through)
    local text
    if timed and places then
        text = Fmt(L["%1$s for %2$s %3$s##zone"], lead, Format.Duration(episode.seconds), places)
    elseif timed then
        text = Fmt(L["%1$s for %2$s##duration"], lead, Format.Duration(episode.seconds))
    elseif places then
        text = Fmt(L["%1$s %2$s##zone"], lead, places)
    else
        text = lead
    end

    local clauses = { text }
    for i = 2, #activities do
        local extra = EXTRA[activities[i]]
        clauses[#clauses + 1] = type(extra) == "function" and extra(episode) or extra
    end
    return Format.List(clauses, CLAUSES)
end

--------------------------------------------------------------------------
-- A together session's headline: its one strongest story
--------------------------------------------------------------------------
--
-- A session is told by what made it, weighed best first: a dungeon or raid
-- run in it, a level reached, a rough patch, a rare hunted, a journey from
-- one zone to another, a zone it settled in, a capital it never left, else
-- what was done most and where. Then where, then how long (from 15 min).
-- Past an hour, a place story leads and a run or a level follows after a
-- semicolon: "Quested together in Westfall for 1 h 40 min; Feivel reached
-- lv 20". Each story's variants carry the same facts, longest first; the
-- session's id picks one, so a page of sessions does not read the same.
-- `said` tells the details line what the headline already names.

local SHORT = 15 * 60       -- under this, no duration
local SECOND = 60 * 60      -- from this, a second story
local ROUGH, ROUGH_PAIR, ROUGH_GAP = 3, 2, 10 * 60
local JOURNEY_TRAVEL, JOURNEY_END = 0.25, 0.20
local SETTLED, SETTLED_SUB = 0.60, 0.50

-- The capitals (the settings' city list, by name) and the tram between two.
local CAPITALS = { ["Stormwind City"] = true, ["Orgrimmar"] = true, ["Ironforge"] = true,
    ["Thunder Bluff"] = true, ["Darnassus"] = true, ["Undercity"] = true }
local TRAM = "Deeprun Tram"

local function IsCity(name)
    if name == TRAM or CAPITALS[name] then return true end
    local cities = ns.db and ns.db.settings and ns.db.settings.cities or {}
    if cities[name] then return true end
    for key, on in pairs(cities) do
        if on and type(key) == "number" and ns.MapName(key) == name then return true end
    end
    return false
end

-- Rare names as the book sets them: curly apostrophes.
local function Curly(text)
    return (text:gsub("'", "\226\128\153"))
end

local Times = Format.Times

local function Pick(list, seed)
    return list[(seed or 0) % #list + 1]
end

-- Deaths in the session outside its runs: the user's and theirs, and
-- whether two came close together.
local function DeathsOf(episode, guid)
    local mine, theirs, times = 0, 0, {}
    local logged = false
    for _, child in ipairs(episode.all) do
        if child.kind == "death" then
            logged = true
            if child.death.guid == guid then theirs = theirs + 1 else mine = mine + 1 end
            times[#times + 1] = child.time
        end
    end
    local session = episode.session
    if not logged and session and session.deaths then
        mine = math.max(0, (session.deaths[session.me] or 0) - (episode.runDeaths or 0))
        theirs = session.deaths[guid] or 0
    end
    table.sort(times)
    local close = false
    for i = 2, #times do
        if times[i] - times[i - 1] <= ROUGH_GAP then close = true end
    end
    return mine, theirs, close
end

-- The place a session is told in, from where its time went
-- (Timeline.Zones): { top, share, sub, subShare, names (at most two),
-- journey, city }.
local function Where(episode)
    local z = ns.Timeline.Zones(episode.session, episode.zones, episode.participant)
    local where = { zones = z, names = {} }
    local list = z.zones
    if #list == 0 then return where end

    local top = list[1]
    for _, zone in ipairs(list) do
        if zone.seconds > top.seconds then top = zone end
    end
    where.top = top.name
    where.share = z.timed and z.total > 0 and top.seconds / z.total or (#list == 1 and 1 or 0)
    if z.timed and top.seconds > 0 then
        for sub, seconds in pairs(top.sub) do
            if seconds / top.seconds >= SETTLED_SUB and (not where.sub or seconds > where.subSeconds) then
                where.sub, where.subSeconds = sub, seconds
            end
        end
    end

    local city = true
    for _, zone in ipairs(list) do
        if not IsCity(zone.name) then city = false end
    end
    where.city = city

    if z.timed and z.first and z.last and z.first ~= z.last and z.total > 0
        and z.travel / z.total >= JOURNEY_TRAVEL then
        local last
        for _, zone in ipairs(list) do
            if zone.name == z.last then last = zone end
        end
        if last and last.seconds / z.total >= JOURNEY_END then where.journey = { z.first, z.last } end
    end

    for i = 1, math.min(2, #list) do where.names[i] = list[i].name end
    where.count = #list
    return where
end

-- "in Westfall", "in Westfall and Duskwood", "in Westfall and around"
-- (the phrase a "##zone" template takes), or nil without a place.
local function In(where)
    if not where.top then return nil end
    if where.count == 1 or where.share >= SETTLED then return ns.ZoneIn(nil, where.top) end
    local first = ns.ZoneIn(nil, where.names[1])
    if where.count == 2 then return Fmt(L["%1$s and %2$s"], first, where.names[2]) end
    return Fmt(L["%s and around"], first)
end

-- `text` (a whole clause) with In(where) after it.
local function WithIn(text, where)
    local place = In(where)
    return place and Fmt(L["%1$s %2$s##zone"], text, place) or text
end

-- Every run in a session, in the order they happened: "ran Deadmines",
-- "ran Deadmines twice", "ran Stratholme and raided Molten Core"; from
-- three, a count (each has its own row below).
local function RunWords(runs)
    local dungeons, raids = 0, 0
    for _, run in ipairs(runs) do
        if run.raid then raids = raids + 1 else dungeons = dungeons + 1 end
    end
    if #runs >= 3 then
        local ran = ns.Plural(dungeons, L["%d dungeon|%d dungeons##plural"])
        if raids == 0 then return Fmt(L["ran %s"], ran) end
        if dungeons == 0 then return Fmt(L["raided %s##times"], Times(raids)) end
        return Fmt(L["ran %1$s and %2$s"], ran, ns.Plural(raids, L["%d raid|%d raids##plural"]))
    end
    local first, second = runs[1], runs[2]
    if not second then return Fmt(first.raid and L["raided %s"] or L["ran %s"], first.name) end
    if first.raid ~= second.raid then
        return Fmt(first.raid and L["raided %1$s and ran %2$s"] or L["ran %1$s and raided %2$s"],
            first.name, second.name)
    end
    if first.name == second.name then
        return Fmt(first.raid and L["raided %s twice"] or L["ran %s twice"], first.name)
    end
    return Fmt(first.raid and L["raided %1$s and %2$s"] or L["ran %1$s and %2$s"], first.name, second.name)
end

-- The strong stories: a run, then a level. Each gives the headline's
-- variants on its own and the words it takes after a semicolon. A run's
-- `words` keep the session's time off it: the time is the whole session's,
-- not any one dungeon's ("Together for 42 min; ran Sunken Temple").
local function Upper(text)
    return G.Capital(text)
end

local function RunStory(episode)
    local runs = {}
    for _, child in ipairs(episode.all) do
        if child.kind == "visit" and child.visit then
            runs[#runs + 1] = { name = child.visit.name or L["a dungeon"], time = child.time or 0,
                raid = child.visit.instanceType == "raid" }
        end
    end
    if #runs == 0 then return nil end
    table.sort(runs, function(a, b) return a.time < b.time end)
    local words = RunWords(runs)
    return { said = "dungeon", placed = true, words = words,
        lead = { Upper(Fmt(L["%s together"], words)) }, tail = words }
end

local LevelWords

local function LevelStory(episode, guid, name, lead)
    local session, p = episode.session, episode.participant
    local theirs = p and p.levelStart and p.levelEnd and p.levelEnd > p.levelStart and p.levelEnd
    local mine = session.myLevelStart and session.myLevelEnd and session.myLevelEnd > session.myLevelStart
        and session.myLevelEnd
    if not (theirs or mine) then return nil end
    local me = session.me
    local story = LevelWords(me, name, lead, theirs, mine)
    story.said, story.over = "level", true
    return story
end

function LevelWords(me, name, lead, theirs, mine)
    local function You(template, ...) return Fmt(Format.You(me, template), ...) end
    if theirs and mine then
        if theirs == mine then
            return { said = "level", lead = { Fmt(L["Reached lv %d together"], mine) },
                tail = You(L["{you} both reached lv %d"], mine) }
        end
        return { said = "level", lead = { You(L["{You} reached lv %1$d, %2$s lv %3$d"], mine, name, theirs) },
            tail = You(L["{you} reached lv %1$d, %2$s lv %3$d"], mine, name, theirs) }
    elseif theirs then
        return { said = "level",
            lead = { You(L["%1$s reached lv %2$d at {your} side"], name, theirs),
                You(L["%1$s reached lv %2$d with {you}"], name, theirs) },
            tail = Fmt(L["%1$s reached lv %2$d"], name, theirs) }
    end
    local with = lead == "quest" and L["{You} reached lv %1$d while questing with %2$s"]
        or L["{You} reached lv %1$d with %2$s"]
    return { said = "level",
        lead = { You(with, mine, name) },
        tail = You(L["{you} reached lv %d"], mine) }
end

-- A rough patch: three deaths, or two close together. Theirs, the user's
-- or both; plain words, no jokes.
local function RoughStory(episode, guid, name)
    local mine, theirs, close = DeathsOf(episode, guid)
    local total = mine + theirs
    if not (total >= ROUGH or (total >= ROUGH_PAIR and close)) then return nil end
    local me = episode.session.me
    local function You(template, ...) return Fmt(Format.You(me, template), ...) end
    local lead
    if theirs == 0 then
        lead = { You(L["{You} died %1$s with %2$s close by"], Times(mine), name) }
    elseif mine == 0 then
        lead = { You(L["%1$s died %2$s at {your} side"], name, Times(theirs)),
            You(L["%1$s died %2$s with {you} close by"], name, Times(theirs)) }
    else
        lead = { You(L["{You} and %1$s died %2$s between you"], name, Times(total)) }
        -- From three: "3 deaths between you and Feivel".
        if total >= ROUGH then lead[2] = You(L["%1$d deaths between {you} and %2$s"], total, name) end
    end
    return { said = "deaths", lead = lead, over = true }
end

local function RareStory(episode)
    local rares = Rares(episode)
    if #rares == 0 then return nil end
    local names = {}
    for i = 1, math.min(2, #rares) do names[i] = Curly(rares[i].name or L["a rare"]) end
    local hunted = names[2] and Fmt(L["%1$s and %2$s"], names[1], names[2]) or names[1]
    return { said = "rare", lead = { Fmt(L["Hunted %s together"], hunted) }, over = true }
end

-- The place stories, weakest last.
local function PlaceStory(episode, where, lead)
    local verb = LEAD[lead] or L["Together"]
    if where.journey then
        local from, to = ns.ZoneIn(nil, where.journey[1], "from"), ns.ZoneIn(nil, where.journey[2], "to")
        return { lead = { Fmt(L["Went %1$s %2$s together##zone"], from, to),
            Fmt(L["Travelled %1$s %2$s together##zone"], from, to) },
            placed = true, over = true }
    end
    if where.city and where.top then
        local only = where.top == TRAM and where.count == 1
        local place = only and L["on the Deeprun Tram"]
            or ns.ZoneIn(nil, where.top == TRAM and where.names[1] or where.top)
        if where.top == TRAM and not only then
            for _, n in ipairs(where.names) do
                if n ~= TRAM then place = ns.ZoneIn(nil, n) end
            end
        end
        return { lead = { Fmt(L["Kept company %s##zone"], place), Fmt(L["Kept each other company %s##zone"], place) },
            placed = true }
    end
    if where.top and where.share >= SETTLED then
        -- "Quested together at Sentinel Hill in Westfall".
        if where.sub then
            return { lead = { Fmt(L["%1$s %2$s %3$s##zone"], verb, ns.ZoneIn(nil, where.sub, "at"),
                ns.ZoneIn(nil, where.top)) }, placed = true }
        end
        return { lead = { Fmt(L["%1$s %2$s##zone"], verb, ns.ZoneIn(nil, where.top)) }, placed = true }
    end
    return { lead = { WithIn(verb, where) }, placed = true }
end

local function SessionHeadline(episode, guid)
    local seed = episode.session and episode.session.id or 0
    local name = guid and ns.Characters.Name(guid) or L["They"]
    local lead = episode.activities and episode.activities[1]
    local where = Where(episode)
    local said = {}

    local strong = RunStory(episode) or LevelStory(episode, guid, name, lead)
    local story
    if strong and episode.seconds < SECOND then
        story = strong
        strong = nil
    else
        story = RoughStory(episode, guid, name) or RareStory(episode)
            or PlaceStory(episode, where, lead)
    end

    local text = Pick(story.lead, seed)
    if story.said then said[story.said] = true end
    -- A run and the place stories have said where; the rest say it here.
    if not story.placed then text = WithIn(text, where) end
    if episode.seconds >= SHORT then
        if story.words then
            text = Fmt(L["Together for %1$s; %2$s"], Format.Duration(episode.seconds), story.words)
        else
            text = Fmt(story.over and L["%1$s over %2$s"] or L["%1$s for %2$s##duration"], text, Format.Duration(episode.seconds))
        end
    end
    if strong then
        text = Fmt(L["%1$s; %2$s"], text, strong.tail)
        said[strong.said] = true
    end
    return text, said
end

-- Everyone in the visit but the user and the person whose page this is.
local function OtherMembers(visit, guid)
    local others = {}
    for _, member in ipairs(visit.members or {}) do
        if member.guid ~= guid and member.guid ~= ns.ownGUID and member.guid ~= visit.me then
            others[#others + 1] = member
        end
    end
    return others
end

-- "with Kaelith, Brom and 2 others".
local MEMBERS = { max = 3, shown = 2, more = ns.UI.Format.OTHERS }

local function Members(visit, guid)
    local names = {}
    for _, member in ipairs(OtherMembers(visit, guid)) do names[#names + 1] = member.first or L["someone"] end
    local list = Format.List(names, MEMBERS)
    return list and Fmt(L["with %s"], list)
end

-- The counts the details line keeps, each one key (ns.Plural).
local DEATHS = L["%d death|%d deaths##plural"]
local TRADES = L["%d trade|%d trades##plural"]

-- "Wailing Caverns, 52 min, 5 of 8 bosses", then deaths, wipes, who else
-- was there and the bosses by name.
local function VisitText(episode, guid)
    local visit = episode.visit
    local text = Fmt(L["%1$s, %2$s"], visit.name or L["An instance"], Format.Duration(episode.seconds))
    if visit.difficulty and visit.difficulty ~= "Normal" then
        text = Fmt(L["%1$s (%2$s)##difficulty"], text, visit.difficulty)
    end
    local bosses = visit.bossesKilled or {}
    if visit.bossTotal then
        text = Fmt(L["%1$s, %2$s"], text, ns.Plural(visit.bossTotal,
            L["%1$d of %2$d boss|%1$d of %2$d bosses##plural"], #bosses, visit.bossTotal))
    elseif #bosses > 0 then
        text = Fmt(L["%1$s, %2$s"], text, ns.Plural(#bosses, L["%d boss|%d bosses##plural"]))
    end

    local facts = {}
    if (visit.deaths or 0) > 0 then facts[#facts + 1] = ns.Plural(visit.deaths, DEATHS) end
    local wipes = ns.DungeonRun.Wipes(visit)
    if wipes > 0 then facts[#facts + 1] = ns.Plural(wipes, L["%d wipe|%d wipes##plural"]) end
    facts[#facts + 1] = Members(visit, guid)
    if #bosses > 0 then facts[#facts + 1] = Fmt(L["killed %s##timeline"], Format.List(bosses)) end
    return text, facts
end

-- A battleground match (Core/Matches.lua): the map by the name the client
-- gave it, else these.
local MATCH_MAPS = {
    warsong = L["Warsong Gulch"],
    arathi = L["Arathi Basin"],
    alterac = L["Alterac Valley"],
}
local function MatchName(m)
    if m.mapName and m.mapName ~= "" then return m.mapName end
    local map = ns.Matches.MAPS[m.map]
    return map and MATCH_MAPS[map.key] or L["A battleground"]  -- (a match whose map went unread)
end

-- "third", "11th": how many matches you have met in. An ordinal is the
-- locale's grammar (grammar.Nth) where it has its own.
local NTH = { L["first##ordinal"], L["second##ordinal"], L["third##ordinal"], L["fourth##ordinal"],
    L["fifth##ordinal"], L["sixth##ordinal"], L["seventh##ordinal"], L["eighth##ordinal"], L["ninth##ordinal"],
    L["tenth##ordinal"] }
local function Nth(n)
    if G.Nth then return G.Nth(n) end
    if NTH[n] then return NTH[n] end
    local last, tens = n % 10, n % 100
    local suffix = (tens >= 11 and tens <= 13) and "th" or ({ "st", "nd", "rd" })[last] or "th"
    return n .. suffix
end

-- "Warsong Gulch, on your side" ("on Thessaly's side" for another of the
-- user's characters in a shared diary: Format.You) with the result, how often you have met in
-- a match on this side, how long it took and their killing blows.
local MATCH_SIDE = {
    with = L["%s, on {your} side"],
    against = L["%s, against {you}"],
}
-- "your third match together", "your third match against them".
local MATCH_AGAIN = {
    with = L["{your} %s match together"],
    against = L["{your} %s match against them"],
}
local function MatchText(episode, guid)
    local m, row = episode.match, episode.row or {}
    local side = MATCH_SIDE[episode.side]  -- (side unknown: the map alone)
    local text = side and Fmt(Format.You(m.me, side), MatchName(m)) or MatchName(m)

    local facts = {}
    local won = ns.Matches.Won(m)
    if m.state == "left" then
        facts[#facts + 1] = Format.You(m.me, L["{you} left before the end"])
    elseif won == true then
        facts[#facts + 1] = Format.You(m.me, L["{you} won"])
    elseif won == false then
        facts[#facts + 1] = Format.You(m.me, L["{you} lost"])
    end
    local n = episode.side and ns.Matches.Meetings(guid, m, episode.side) or 0
    if n > 1 then
        local again = episode.side == "with" and MATCH_AGAIN.with or MATCH_AGAIN.against
        facts[#facts + 1] = Fmt(Format.You(m.me, again), Nth(n))
    end
    if m.state ~= "open" and (episode.seconds or 0) >= 60 then facts[#facts + 1] = Format.Duration(episode.seconds) end
    if (row.kb or 0) > 0 then facts[#facts + 1] = ns.Plural(row.kb, L["%d killing blow|%d killing blows##plural"]) end
    if m.state == "open" then facts[#facts + 1] = L["still going"] end
    return text, facts
end

-- TLN-6: every trade in the episode, summed, once the headline says "traded".
local function TradeFact(t)
    local parts = {}
    if #t.given > 0 then parts[#parts + 1] = Fmt(L["gave %s"], Items(t.given)) end
    if t.moneyGiven > 0 then parts[#parts + 1] = Fmt(L["gave %s"], Format.Money(t.moneyGiven)) end
    if #t.received > 0 then parts[#parts + 1] = Fmt(L["got %s"], Items(t.received)) end
    if t.moneyReceived > 0 then parts[#parts + 1] = Fmt(L["got %s"], Format.Money(t.moneyReceived)) end
    if #parts == 0 then return t.trades > 1 and ns.Plural(t.trades, TRADES) or nil end
    local text = Join(parts, L["%1$s; %2$s"])
    return t.trades > 1 and ns.Plural(t.trades, L["%1$d trade: %2$s|%1$d trades: %2$s##plural"], t.trades, text)
        or text
end

-- One quest by its title in curly quotes, when the client knows it;
-- else the count.
local function QuestFact(quests)
    if #quests == 1 then
        local Q = C_QuestLog
        local title = Q and Q.GetTitleForQuestID and ns.Plain(Q.GetTitleForQuestID(quests[1]))
        if type(title) == "string" and title ~= "" then return Fmt(L["\226\128\156%s\226\128\157"], title) end
    end
    return #quests > 0 and ns.Plural(#quests, L["%d quest|%d quests##plural"]) or nil
end

-- The details line, in a fixed order: quests, rares, their level, trades,
-- deaths, runs, messages, the rest. What the headline says (`said`) is not
-- said again, a message or two is not worth counting, and moments with a
-- line of their own are not counted here.
local function Facts(episode, guid, said)
    said = said or {}
    local t = Tally(episode)
    local p = episode.participant
    local named = episode.named
    local facts = {}
    local function Add(fact) if fact then facts[#facts + 1] = fact end end

    if named.quest and p then Add(QuestFact(p.quests or {})) end
    if named.rare and not said.rare and #Rares(episode) > 0 then
        Add(Fmt(L["killed %s##timeline"], RareNames(Rares(episode))))
    end

    if not said.level and p and p.levelStart and p.levelEnd and p.levelEnd > p.levelStart then
        Add(Fmt(L["%1$s reached lv %2$d"], guid and ns.Characters.Name(guid) or L["They"], p.levelEnd))
    end

    if named.trade then
        Add(TradeFact(t))
    elseif t.chatterTrades > 0 then
        Add(ns.Plural(t.chatterTrades, TRADES))
    end

    -- Deaths with a line of their own (Timeline's death items) are not
    -- counted again, nor those a dungeon run in it counts (TLN-11); older
    -- sessions only have the count.
    local session = episode.session
    if session and not said.deaths then
        local deaths = (session.deaths[guid] or 0) + (session.deaths[session.me] or 0)
            - (episode.runDeaths or 0)
        for i = 1, #episode.all do
            if episode.all[i].kind == "death" then deaths = deaths - 1 end
        end
        if deaths > 0 then Add(ns.Plural(deaths, DEATHS)) end
    end

    -- TLN-4: a session counts its visits; each one tells its own story.
    -- The headline names or counts them all, so then they are not said again.
    local dungeons, raids = 0, 0
    for i = 1, #episode.all do
        local child = episode.all[i]
        if child.kind == "visit" and not said.dungeon then
            if child.visit.instanceType == "raid" then raids = raids + 1 else dungeons = dungeons + 1 end
        end
    end
    if dungeons > 0 then Add(ns.Plural(dungeons, L["%d dungeon|%d dungeons##plural"])) end
    if raids > 0 then Add(ns.Plural(raids, L["%d raid|%d raids##plural"])) end

    if t.chat >= 3 then Add(ns.Plural(t.chat, L["%d message|%d messages##plural"])) end
    if t.other > 0 then Add(ns.Plural(t.other, L["%d other interaction|%d other interactions##plural"])) end

    return facts
end

-- TLN-3: the headline and details line cut to the episode's length; the
-- tooltip gets all of it.
local function EpisodeText(episode, guid)
    local visitText, facts, sessionText, said
    if episode.kind == "visit" then
        visitText, facts = VisitText(episode, guid)
        for _, fact in ipairs(Facts(episode, guid)) do facts[#facts + 1] = fact end
    elseif episode.kind == "match" then
        visitText, facts = MatchText(episode, guid)
        for _, fact in ipairs(Facts(episode, guid)) do facts[#facts + 1] = fact end
    elseif episode.kind == "session" and episode.session then
        sessionText, said = SessionHeadline(episode, guid)
        facts = Facts(episode, guid, said)
    else
        facts = Facts(episode, guid)
    end
    local _, budget = ns.Timeline.Budget(episode.seconds)

    local shown = {}
    for i = 1, math.min(budget, #facts) do shown[i] = facts[i] end
    if episode.session and not episode.session.endedAt then
        shown[#shown + 1] = L["still going"]
        facts[#facts + 1] = L["still going"]
    end

    local text = visitText or sessionText or Headline(episode, episode.headline)
    -- The row's details run on with commas; the tooltip gives each fact a
    -- line of its own (never a middle dot: the copywriter skill).
    local sub = #shown > 0 and table.concat(shown, ", ") or nil
    local full = visitText or sessionText or Headline(episode, episode.activities)
    if #facts > 0 then full = full .. "\n" .. table.concat(facts, "\n") end

    local icon = (episode.kind == "session" and "together") or (episode.kind == "visit" and "dungeon")
        or (episode.kind == "match" and "match") or ACTIVITY_ICON[episode.headline[1]] or "talk"
    return text, sub, icon, full
end

-- A note the user wrote (DIA-11, TLN-10): its text on one line, and for
-- the tooltip all of it, whom else it is about, and when it was written.
-- Shared by a note of its own and one in a run's description.
local function DescribeNote(note, guid)
    local text = note.text:gsub("%s*\n%s*", " ")
    local full = { note.text }

    local others = {}
    for _, other in ipairs(ns.Notes.Others(note, guid)) do
        others[#others + 1] = ns.Characters.FullName(other) or L["someone"]
    end
    if #others > 0 then full[#full + 1] = Fmt(L["Also about %s."], Format.List(others)) end

    local clock = date("%H:%M", note.time)
    full[#full + 1] = note.zone and Fmt(L["Written at %1$s %2$s.##zone"], clock, ns.ZoneIn(note.mapID, note.zone))
        or Fmt(L["Written at %s."], clock)
    full[#full + 1] = L["Click to change or delete it."]
    return text, table.concat(full, "\n")
end

-- Returns the time, the line, an optional second line, the icon and the
-- whole story for the tooltip (nil: the lines are all of it), coloured for a
-- dark tooltip; the page inks them (Style.Inkify).
function ns.UI.DescribeItem(item, guid)
    local when = date("%H:%M", item.time)

    if IsEpisode(item) then
        local text, sub, icon, full = EpisodeText(item, guid)
        return when, text, sub, icon, full
    elseif item.kind == "climb" then
        -- "Tester went from level 1 to 6", each level and its time in the
        -- tooltip. The climb is the timeline's (Core/Rows.lua's `climb`),
        -- so its words and icon stay here; its rows' context { from, level }
        -- is that flag's contract.
        local ups = item.ups
        local first, last = ups[1].row.context or {}, ups[#ups].row.context or {}
        local from, to = first.from or ((first.level or 1) - 1), last.level or "?"
        local name = guid and ns.Characters.Name(guid)
        local text = name and Fmt(L["%1$s went from level %2$s to %3$s"], name, from, to)
            or Fmt(L["Went from level %1$s to %2$s"], from, to)
        local full = { text }
        for _, up in ipairs(ups) do
            full[#full + 1] = Fmt(L["%1$s  level %2$s"], date("%H:%M", up.time),
                tostring(up.row.context and up.row.context.level or "?"))
        end
        return when, text, nil, "levelup", table.concat(full, "\n")
    elseif item.kind == "deaths" then
        -- "{You} died 4 times, Feivel 3 times", each death in the tooltip.
        local mine, theirs, me = 0, 0, nil
        local full = {}
        for _, d in ipairs(item.deaths) do
            if d.death.guid == guid then theirs = theirs + 1 else mine, me = mine + 1, d.death.guid end
            full[#full + 1] = date("%H:%M", d.time) .. "  " .. DeathText(d.death, guid)
        end
        local parts = {}
        if mine > 0 then parts[#parts + 1] = Fmt(Format.You(me, L["{You} died %s"]), Times(mine)) end
        if theirs > 0 then
            local name = ns.Characters.Name(guid) or L["They"]
            parts[#parts + 1] = Fmt(mine > 0 and L["%1$s %2$s"] or L["%1$s died %2$s"], name, Times(theirs))
        end
        local text = Join(parts)
        table.insert(full, 1, text)
        return when, text, nil, "death", table.concat(full, "\n")
    elseif item.kind == "rare" then
        return when, Fmt(L["Killed %s##timeline"], item.rare.name or L["a rare"]), nil, "rare"
    elseif item.kind == "death" then
        -- Said "there", the tooltip still names the place.
        return when, DeathText(item.death, guid, item.there), nil, "death",
            item.there and DeathText(item.death, guid) or nil
    elseif item.kind == "around" then
        local stretch = item.around
        local places = Places(stretch.zones, Around)
        local seconds = stretch.last - stretch.start
        local long = seconds >= 60 and Format.Duration(seconds)
        local text
        if places and long then text = Fmt(L["Seen %1$s for %2$s##zone"], places, long)
        elseif places then text = Fmt(L["Seen %s##zone"], places)
        elseif long then text = Fmt(L["Seen around for %s"], long)
        else text = L["Seen around"] end
        return when, text, nil, "around"
    elseif item.kind == "note" then
        local text, full = DescribeNote(item.note, guid)
        return when, text, nil, "note", full
    elseif item.kind == "first" then
        local first = item.first
        -- "First seen at Red Rocks, Mulgore, level 12": the subzone "at" its
        -- phrase with the zone after it, else the zone "at" its own.
        local zone = first.mapID and ns.MapName(first.mapID) or nil
        local sub = first.subZone
        if sub == "" or sub == zone then sub = nil end
        local place = sub and ns.ZoneIn(nil, sub, "at") or zone and ns.ZoneIn(first.mapID, zone, "at")
        local text
        if sub and zone and first.level then
            text = Fmt(L["First seen %1$s, %2$s, level %3$s##zone"], place, zone, first.level)
        elseif sub and zone then text = Fmt(L["First seen %1$s, %2$s##zone"], place, zone)
        elseif place and first.level then text = Fmt(L["First seen %1$s, level %2$s##zone"], place, first.level)
        elseif place then text = Fmt(L["First seen %s##zone"], place)
        elseif first.level then text = Fmt(L["First seen, level %s"], first.level)
        else text = L["First seen"] end
        return when, text, nil, "added"
    elseif item.kind == "added" then
        local context = item.entry.addedContext
        local zone = context and context.zone
        return when, zone and Fmt(L["Added to the diary %s##zone"], ns.ZoneIn(context.mapID, zone))
            or L["Added to the diary"], nil, "added"
    end

    local kind = ns.Rows.Get(item.row.type)
    return when, kind.text and kind.text(item.row, guid) or item.row.type, nil, kind.icon
end

-- For the page lines, which lay episodes and visits out, and a note's
-- words (UI/Journal/Timeline.lua).
-- And a row's words shared by its kinds, for a feature's file
-- (Features/<Name>/, .claude/skills/new-feature/folder.md) to tell its own rows
-- (Core/Rows.lua's `text`) as these do: Items(list) "2x [Linen Cloth],
-- [Copper Ore]"; Quote(text, fallback) 'Said: "hello"', or the fallback
-- alone; Place(row, unplaced) "in Hillsbrad Foothills" for the kind's own
-- "##zone" template, or nil (no zone, or the kind's text asked without its
-- place: `text(row, guid, unplaced)`); Join(list, template) a list joined by "%1$s, %2$s##list"
-- (or `template`); Foe(row) the creature in a witness's row as Your Diary
-- names a killer ("a Kobold Vermin"), or nil.
-- MatchName(match) a battleground match's map ("Warsong Gulch"), and
-- Nth(n) "third", for the reunion toast in a match (UI/Windows/Reunion/).
ns.UI.TimelineText = { IsEpisode = IsEpisode, OtherMembers = OtherMembers, DescribeNote = DescribeNote,
    Items = Items, Quote = Quote, Place = Place, Join = Join, Foe = Foe,
    MatchName = MatchName, Nth = Nth }

-- A match's line on the timeline: crossed swords from the battlemasters'
-- gossip, like the other gossip icons the timeline draws.
ns.Style.AddArt("match", { "Interface\\GossipFrame\\BattleMasterGossipIcon", "Interface\\Icons\\Ability_DualWield" })
