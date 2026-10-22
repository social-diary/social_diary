-- The timeline's words (JNL-2, TLN-2 to TLN-6, TLN-10): what each timeline item says
-- on the profile's page, and in its tooltip.
--
-- Pure functions over ns.Timeline's items, no frames: the page
-- (UI/Journal/Timeline.lua) lays the lines out, this file only writes them.
-- What an episode's rows add up to is Core/Timeline.lua's (Timeline.Tally).

local addonName, ns = ...

local Format = ns.UI.Format

local Tally = ns.Timeline.Tally

--------------------------------------------------------------------------
-- Describing timeline items
--------------------------------------------------------------------------

local function Items(list)
    local parts = {}
    for i = 1, #list do
        local item = list[i]
        parts[#parts + 1] = (item.count and item.count > 1 and (item.count .. "x ") or "") .. item.link
    end
    return table.concat(parts, ", ")
end

local function Quote(text, fallback)
    if not text then return fallback end
    return fallback .. ': "' .. text .. '"'
end

local ROW_TEXT = {
    group_join = function(row)
        return (row.context and row.context.raid) and "Raided together" or "Grouped"
    end,
}

-- " in Hillsbrad Foothills", the row's zone, or "" (a feature's row,
-- through ns.UI.TimelineText.Place).
local function Place(row)
    return row.zone and (" in " .. row.zone) or ""
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
local function DeathText(death, guid, there)
    local who = death.guid == guid and (ns.Characters.Name(guid) or "They") or Format.You(death.guid, "{You}")
    local text = who .. " died"

    local killer = death.killer
    local name = killer and (killer.player and killer.guid and ns.Characters.FullName(killer.guid) or killer.name)
    if killer and killer.environment and not name then
        text = text .. " (" .. killer.environment:lower() .. ")"
    elseif name then
        local to = name .. (killer.spell and ("'s " .. killer.spell) or "")
        text = text .. (killer.source == "recap" and " to " or ", probably to ") .. to
        if (killer.attackers or 0) > 1 then text = text .. " (" .. killer.attackers .. " attackers)" end
    end

    local place = death.subZone or death.zone
    if there and place then
        text = text .. " there"
    elseif place then
        text = text .. " near " .. place
    end
    return text
end

-- "Mulgore", "Mulgore and The Barrens", "Mulgore and around", and how many
-- places there were. Never more than two names. A zone the client had no
-- name for when it was written down (an empty string: Core/Location.lua's
-- ns.Where takes GetRealZoneText's "" during a loading screen, and
-- Core/Sessions.lua's TrackZone keeps it) is no place, and is left out;
-- one written down again on coming back is the same place (20 and 21 Oct,
-- in the client: "Quested together for 2 h 36 min through , Stormwind City
-- and 23 more", and "Stormwind City, Deeprun Tram and 22 more").
local function Places(zones)
    local named = ns.Timeline.Unique(zones)
    if #named == 0 then return nil, 0 end
    if #named == 1 then return named[1], 1 end
    if #named == 2 then return named[1] .. " and " .. named[2], 2 end
    return named[1] .. " and around", #named
end

local Count = Format.Count

-- Episodes (ns.Timeline) carry their children; nothing else does.
local function IsEpisode(item)
    return item ~= nil and item.all ~= nil
end

-- "Mor'Ladim", "Mor'Ladim and Rakk", "Mor'Ladim and 2 more". `max` names at
-- most that many.
local function RareNames(rares, max)
    local names = {}
    for i = 1, #rares do names[i] = rares[i].name or "a rare" end
    return Format.List(names, max and { max = max }) or ""
end

local function Rares(episode)
    return episode.participant and episode.participant.rares or {}
end

-- TLN-2's activities in words: how one opens a headline, and how it is
-- added after the first.
local LEAD = {
    quest = "Quested together",
    rare = "Hunted together",
    group = "Grouped",
    trade = "Traded",
    chat = "Chatted",
    other = "Crossed paths",
}

-- The headline and its extras are clauses, not names: "Quested together,
-- killed Mor'Ladim, and traded".
local CLAUSES = { oxford = true }

local EXTRA = {
    quest = "quested together",
    rare = function(episode) return "killed " .. RareNames(Rares(episode), 1) end,
    group = "grouped",
    trade = "traded",
    chat = "chatted",
    other = "crossed paths",
}

local ACTIVITY_ICON = { quest = "together", rare = "rare", group = "together", trade = "trade",
    chat = "talk", other = "talk" }

-- "Quested together for 3 h 5 min through Westfall and Duskwood, killed
-- Mor'Ladim, and traded".
local function Headline(episode, activities)
    local text = LEAD[activities[1]] or "Together"
    if episode.kind == "session" or episode.seconds >= 60 then
        text = text .. " for " .. Format.Duration(episode.seconds)
    end

    local places, count = Places(episode.zones)
    if places then text = text .. (count == 2 and " through " or " in ") .. places end

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

local function Times(n)
    return n == 1 and "once" or (n == 2 and "twice") or (n .. " times")
end

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
    local z = ns.Timeline.Zones(episode.session, episode.zones)
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

-- " in Westfall", " in Westfall and Duskwood", " in Westfall and around",
-- or "" without a place.
local function In(where)
    if not where.top then return "" end
    if where.count == 1 or where.share >= SETTLED then return " in " .. where.top end
    if where.count == 2 then return " in " .. where.names[1] .. " and " .. where.names[2] end
    return " in " .. where.names[1] .. " and around"
end

-- The strong stories: a run, then a level. Each gives the headline's
-- variants on its own and the words it takes after a semicolon.
local function RunStory(episode)
    for _, child in ipairs(episode.all) do
        if child.kind == "visit" and child.visit then
            local name = child.visit.name or "a dungeon"
            local raid = child.visit.instanceType == "raid"
            local verb = raid and "Raided " or "Ran "
            return { said = "dungeon", placed = true, over = true,
                lead = { verb .. name .. " together" },
                tail = (raid and "raided " or "ran ") .. name .. " together" }
        end
    end
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
    if theirs and mine then
        if theirs == mine then
            return { said = "level", lead = { "Reached lv " .. mine .. " together" },
                tail = Format.You(me, "{you}") .. " both reached lv " .. mine }
        end
        local text = Format.You(me, "{You}") .. " reached lv " .. mine .. ", " .. name .. " lv " .. theirs
        return { said = "level", lead = { text }, tail = Format.You(me, "{you}") .. " reached lv " .. mine
            .. ", " .. name .. " lv " .. theirs }
    elseif theirs then
        return { said = "level",
            lead = { name .. " reached lv " .. theirs .. " at " .. Format.You(me, "{your}") .. " side",
                name .. " reached lv " .. theirs .. " with " .. Format.You(me, "{you}") },
            tail = name .. " reached lv " .. theirs }
    end
    local with = lead == "quest" and " while questing with " or " with "
    return { said = "level",
        lead = { Format.You(me, "{You}") .. " reached lv " .. mine .. with .. name },
        tail = Format.You(me, "{you}") .. " reached lv " .. mine }
end

-- A rough patch: three deaths, or two close together. Theirs, the user's
-- or both; plain words, no jokes.
local function RoughStory(episode, guid, name)
    local mine, theirs, close = DeathsOf(episode, guid)
    local total = mine + theirs
    if not (total >= ROUGH or (total >= ROUGH_PAIR and close)) then return nil end
    local me = episode.session.me
    local You, you, your = Format.You(me, "{You}"), Format.You(me, "{you}"), Format.You(me, "{your}")
    local lead
    if theirs == 0 then
        lead = { You .. " died " .. Times(mine) .. " with " .. name .. " close by" }
    elseif mine == 0 then
        lead = { name .. " died " .. Times(theirs) .. " at " .. your .. " side",
            name .. " died " .. Times(theirs) .. " with " .. you .. " close by" }
    else
        lead = { You .. " and " .. name .. " died " .. Times(total) .. " between you",
            Times(total):gsub("^(%d+) times$", "%1 deaths") .. " between " .. you .. " and " .. name }
        if total < ROUGH then lead[2] = nil end
    end
    return { said = "deaths", lead = lead, over = true }
end

local function RareStory(episode)
    local rares = Rares(episode)
    if #rares == 0 then return nil end
    local names = {}
    for i = 1, math.min(2, #rares) do names[i] = Curly(rares[i].name or "a rare") end
    return { said = "rare", lead = { "Hunted " .. table.concat(names, " and ") .. " together" }, over = true }
end

-- The place stories, weakest last.
local function PlaceStory(episode, where, lead)
    local verb = LEAD[lead] or "Together"
    if where.journey then
        return { lead = { "Went from " .. where.journey[1] .. " to " .. where.journey[2] .. " together",
            "Travelled from " .. where.journey[1] .. " to " .. where.journey[2] .. " together" },
            placed = true, over = true }
    end
    if where.city and where.top then
        local only = where.top == TRAM and where.count == 1
        local place = only and "on the Deeprun Tram" or (where.top == TRAM and ("in " .. where.names[1]) or ("in " .. where.top))
        if where.top == TRAM and not only then
            for _, n in ipairs(where.names) do
                if n ~= TRAM then place = "in " .. n end
            end
        end
        return { lead = { "Kept company " .. place, "Kept each other company " .. place }, placed = true }
    end
    if where.top and where.share >= SETTLED then
        local place = where.sub and (" at " .. where.sub .. " in " .. where.top) or (" in " .. where.top)
        return { lead = { verb .. place }, placed = true }
    end
    return { lead = { verb .. In(where) }, placed = true }
end

local function SessionHeadline(episode, guid)
    local seed = episode.session and episode.session.id or 0
    local name = guid and ns.Characters.Name(guid) or "They"
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
    if not story.placed then text = text .. In(where) end
    if episode.seconds >= SHORT then
        text = text .. (story.over and " over " or " for ") .. Format.Duration(episode.seconds)
    end
    if strong then
        text = text .. "; " .. strong.tail
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
local MEMBERS = { max = 3, shown = 2, more = "others" }

local function Members(visit, guid)
    local names = {}
    for _, member in ipairs(OtherMembers(visit, guid)) do names[#names + 1] = member.first or "someone" end
    local list = Format.List(names, MEMBERS)
    return list and ("with " .. list)
end

-- "Wailing Caverns, 52 min, 5 of 8 bosses", then deaths, wipes, who else
-- was there and the bosses by name.
local function VisitText(episode, guid)
    local visit = episode.visit
    local text = (visit.name or "An instance") .. ", " .. Format.Duration(episode.seconds)
    if visit.difficulty and visit.difficulty ~= "Normal" then
        text = text .. " (" .. visit.difficulty .. ")"
    end
    local bosses = visit.bossesKilled or {}
    if visit.bossTotal then
        text = text .. (", %d of %d bosses"):format(#bosses, visit.bossTotal)
    elseif #bosses > 0 then
        text = text .. ", " .. Count(#bosses, "boss", "bosses")
    end

    local facts = {}
    if (visit.deaths or 0) > 0 then facts[#facts + 1] = Count(visit.deaths, "death", "deaths") end
    local wipes = ns.DungeonRun.Wipes(visit)
    if wipes > 0 then facts[#facts + 1] = Count(wipes, "wipe", "wipes") end
    facts[#facts + 1] = Members(visit, guid)
    if #bosses > 0 then facts[#facts + 1] = "killed " .. table.concat(bosses, ", ") end
    return text, facts
end

-- TLN-6: every trade in the episode, summed, once the headline says "traded".
local function TradeFact(t)
    local parts = {}
    if #t.given > 0 then parts[#parts + 1] = "gave " .. Items(t.given) end
    if t.moneyGiven > 0 then parts[#parts + 1] = "gave " .. Format.Money(t.moneyGiven) end
    if #t.received > 0 then parts[#parts + 1] = "got " .. Items(t.received) end
    if t.moneyReceived > 0 then parts[#parts + 1] = "got " .. Format.Money(t.moneyReceived) end
    if #parts == 0 then return t.trades > 1 and Count(t.trades, "trade", "trades") or nil end
    local text = table.concat(parts, "; ")
    return t.trades > 1 and (t.trades .. " trades: " .. text) or text
end

-- One quest by its title in curly quotes, when the client knows it;
-- else the count.
local function QuestFact(quests)
    if #quests == 1 then
        local Q = C_QuestLog
        local title = Q and Q.GetTitleForQuestID and ns.Plain(Q.GetTitleForQuestID(quests[1]))
        if type(title) == "string" and title ~= "" then return "\226\128\156" .. title .. "\226\128\157" end
    end
    return #quests > 0 and Count(#quests, "quest", "quests") or nil
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
        Add("killed " .. RareNames(Rares(episode)))
    end

    if not said.level and p and p.levelStart and p.levelEnd and p.levelEnd > p.levelStart then
        Add((guid and ns.Characters.Name(guid) or "They") .. " reached lv " .. p.levelEnd)
    end

    if named.trade then
        Add(TradeFact(t))
    elseif t.chatterTrades > 0 then
        Add(Count(t.chatterTrades, "trade", "trades"))
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
        if deaths > 0 then Add(Count(deaths, "death", "deaths")) end
    end

    -- TLN-4: a session counts its visits; each one tells its own story.
    local dungeons, raids = 0, 0
    for i = 1, #episode.all do
        local child = episode.all[i]
        if child.kind == "visit" then
            if child.visit.instanceType == "raid" then raids = raids + 1 else dungeons = dungeons + 1 end
        end
    end
    -- The headline names one run; any more are counted.
    if said.dungeon then
        if raids > 0 then raids = raids - 1 else dungeons = dungeons - 1 end
    end
    if dungeons > 0 then Add(Count(dungeons, "dungeon", "dungeons")) end
    if raids > 0 then Add(Count(raids, "raid", "raids")) end

    if t.chat >= 3 then Add(Count(t.chat, "message", "messages")) end
    if t.other > 0 then Add(Count(t.other, "other interaction", "other interactions")) end

    return facts
end

-- TLN-3: the headline and details line cut to the episode's length; the
-- tooltip gets all of it.
local function EpisodeText(episode, guid)
    local visitText, facts, sessionText, said
    if episode.kind == "visit" then
        visitText, facts = VisitText(episode, guid)
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
        shown[#shown + 1] = "still going"
        facts[#facts + 1] = "still going"
    end

    local text = visitText or sessionText or Headline(episode, episode.headline)
    local sub = #shown > 0 and table.concat(shown, "  ·  ") or nil
    local full = visitText or sessionText or Headline(episode, episode.activities)
    if #facts > 0 then full = full .. "\n" .. table.concat(facts, "  ·  ") end

    local icon = (episode.kind == "session" and "together") or (episode.kind == "visit" and "dungeon")
        or ACTIVITY_ICON[episode.headline[1]] or "talk"
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
        others[#others + 1] = ns.Characters.FullName(other) or "someone"
    end
    if #others > 0 then full[#full + 1] = "Also about " .. Format.List(others) .. "." end

    local written = "Written at " .. date("%H:%M", note.time)
    if note.zone then written = written .. " in " .. note.zone end
    full[#full + 1] = written .. "."
    full[#full + 1] = "Click to change or delete it."
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
        local text = ("%s from level %s to %s"):format(name and (name .. " went") or "Went", from, to)
        local full = { text }
        for _, up in ipairs(ups) do
            full[#full + 1] = date("%H:%M", up.time) .. "  level " .. tostring(up.row.context and up.row.context.level or "?")
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
        local function Times(n) return n == 1 and "once" or (n == 2 and "twice") or (n .. " times") end
        local parts = {}
        if mine > 0 then parts[#parts + 1] = Format.You(me, "{You}") .. " died " .. Times(mine) end
        if theirs > 0 then
            local name = ns.Characters.Name(guid) or "They"
            parts[#parts + 1] = (mine > 0 and name or (name .. " died")) .. " " .. Times(theirs)
        end
        local text = table.concat(parts, ", ")
        table.insert(full, 1, text)
        return when, text, nil, "death", table.concat(full, "\n")
    elseif item.kind == "rare" then
        return when, "Killed " .. (item.rare.name or "a rare"), nil, "rare"
    elseif item.kind == "death" then
        -- Said "there", the tooltip still names the place.
        return when, DeathText(item.death, guid, item.there), nil, "death",
            item.there and DeathText(item.death, guid) or nil
    elseif item.kind == "around" then
        local stretch = item.around
        local text = "Seen around"
        local places = Places(stretch.zones)
        if places then text = text .. " " .. places end
        local seconds = stretch.last - stretch.start
        if seconds >= 60 then text = text .. " for " .. Format.Duration(seconds) end
        return when, text, nil, "around"
    elseif item.kind == "note" then
        local text, full = DescribeNote(item.note, guid)
        return when, text, nil, "note", full
    elseif item.kind == "first" then
        local first = item.first
        local place = ns.UI.JourneyText.Place(first.mapID, first.subZone)
        return when, "First seen" .. (place and (" at " .. place) or "")
            .. (first.level and (", level " .. first.level) or ""), nil, "added"
    elseif item.kind == "added" then
        local context = item.entry.addedContext
        local place = context and context.zone and (" in " .. context.zone) or ""
        return when, "Added to the diary" .. place, nil, "added"
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
-- alone; Place(row) " in Hillsbrad Foothills", or ""; Foe(row) the
-- creature in a witness's row as Your Diary names a killer ("a Kobold
-- Vermin"), or nil.
ns.UI.TimelineText = { IsEpisode = IsEpisode, OtherMembers = OtherMembers, DescribeNote = DescribeNote,
    Items = Items, Quote = Quote, Place = Place, Foe = Foe }
