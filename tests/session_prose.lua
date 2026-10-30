-- Together sessions in prose (experimental, UI/Words/SessionProse.lua): the
-- facts a session hands the page writer, the row it writes in each voice,
-- and the timeline's own headline whenever prose is off.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Prose = ns.UI.SessionProse
local Slash = SlashCmdList.SOCIALDIARY

local PAL = "Player-4620-00CCCCCC"
local t0 = 1795000000

local function Fresh(sessions)
    T.BlankDiary()
    for id in pairs(ns.db.instances) do ns.db.instances[id] = nil end
    mock.now = t0
    ns.Characters.Observe(PAL, { first = "Feivel", level = 16, faction = "Alliance",
        sex = 2, race = "NightElf", class = "HUNTER" })
    ns.Diary.Add(PAL, { source = "test" })
    for _, session in ipairs(sessions) do ns.db.sessions[session.id] = session end
end

-- The session in the screenshot: 2 h 36 min in Westfall, seven deaths
-- between them, and Feivel reached 16.
local function Westfall(source)
    return { id = 501, me = SELF.guid, source = source, startedAt = t0 + 3600,
        endedAt = t0 + 3600 + 9360,
        participants = { [PAL] = { since = t0 + 3600, last = t0 + 3600 + 9360, seconds = 9360,
            levelStart = 15, levelEnd = 16 } },
        others = 0, zones = { "Westfall" }, deaths = { [SELF.guid] = 3, [PAL] = 4 } }
end

local function Row()
    return ns.Timeline.For(PAL)[1]
end

--------------------------------------------------------------------------
Section("off: the timeline's own headline")

Prose.voice = nil
Fresh({ Westfall("group") })
local _, text, sub = ns.UI.DescribeItem(Row(), PAL)
local before = text
Check(before:find("Feivel", 1, true) and not before:find("%. "), "prose while off: " .. before)

--------------------------------------------------------------------------
Section("the facts a session hands the page writer")

local function ById()
    local by = {}
    for _, c in ipairs((Prose.Candidates(Row(), PAL))) do by[c.id] = c end
    return by
end

local by = ById()
local together, deaths, ding = by.time.facts, by.deaths.facts, by["their-level"].facts
Eq(together.who.name, "Feivel", "who")
Eq(together.who.race, "Night Elf", "the race token in words")
Eq(together.who.sex, 2, "sex")
Eq(together.seconds, 9360, "seconds together")
Eq(together.grouped, true, "a group session is grouped")
Eq(together.zone, "Westfall", "the main zone")
Eq(deaths.myDeaths, 3, "my deaths")
Eq(deaths.theirDeaths, 4, "their deaths")
Check(by.rares == nil, "no rares")
Eq(ding.level, 16, "their new level")
Eq(ding.levels, 1, "levels gained")
Eq(by.deaths.said, "deaths", "deaths stand for the timeline's deaths")
Eq(by["their-level"].said, "level", "the ding stands for the level")
local plan = Prose.Plan(Row(), PAL)
Eq(plan.key, "session/501/" .. PAL, "seeded by the session and the person")
Eq(plan.page.part, ns.Pages.Lang.PartOfDay(t0 + 3600), "the part of the day")

Fresh({ Westfall("nearby") })
by = ById()
Eq(by.time.facts.grouped, false, "nearby only is not grouped")
Eq(by["their-level"].facts.together, false, "a nearby ding is not in my group")

--------------------------------------------------------------------------
Section("on: the row in prose, in every voice")

Fresh({ Westfall("group") })
for _, voice in ipairs({ "plain", "warm", "wry", "terse", "mixed" }) do
    Prose.voice = voice
    local _, prose, details = ns.UI.DescribeItem(Row(), PAL)
    Check(prose ~= before, voice .. ": still the old headline")
    Check(not prose:find("[{}<>|]") and not prose:find("nil"), voice .. ": leftover syntax: " .. prose)
    Check(prose:find("Feivel", 1, true) ~= nil, voice .. ": Feivel not named: " .. prose)
    local again = select(2, ns.UI.DescribeItem(Row(), PAL))
    Eq(again, prose, voice .. ": the same row twice")
    -- Nothing said twice: what the prose tells, the details line leaves out.
    local d = details or ""
    Check(not (prose:find("death") and d:find("death")), voice .. ": deaths said twice: " .. d)
    Check(not (prose:find("16") and d:find("lv 16")), voice .. ": the level said twice: " .. d)
    if os.getenv("SD_SHOW") then print("    " .. voice .. ": " .. prose .. "\n        details: " .. tostring(details)) end
end

--------------------------------------------------------------------------
Section("candidates: a run, a roll, a rescue and a gift (planner stage 1)")

local STRANGER = "Player-4620-00CCCCC1"
local ELIXIR = "|cffffffff|Hitem:2457::::::::16:::::::|h[Elixir of Minor Agility]|h|r"
local STRIKE = "|cff1eff00|Hitem:6660::::::::16:::::::|h[Strike of the Hydra]|h|r"

local function Add(kind, time, data)
    data.time = time
    local row = ns.Interactions.Add(PAL, kind, data)
    row.session = 502
    table.sort(ns.db.interactions[PAL], function(a, b) return a.time < b.time end)
    return row
end

-- Three hours, an hour and forty minutes of it in the Deadmines.
Fresh({ { id = 502, me = SELF.guid, source = "group", startedAt = t0, endedAt = t0 + 3 * 3600,
    participants = { [PAL] = { since = t0, last = t0 + 3 * 3600, seconds = 3 * 3600, quests = { 1, 2 } } },
    others = 1, zones = { "Westfall" }, deaths = {} } })
ns.db.instances[77] = { id = 77, me = SELF.guid, instanceID = 36, name = "The Deadmines", instanceType = "party",
    startedAt = t0 + 3600, endedAt = t0 + 3600 + 6000, sessionIds = { 502 },
    members = { { guid = PAL, first = "Feivel" }, { guid = STRANGER, first = "Dorn" } },
    bossesKilled = { "Rhahk'Zor", "Sneed", "Gilnid", "Mr. Smite", "Captain Greenskin", "Edwin VanCleef" },
    bossTotal = 6, deaths = 3, wipes = 2,
    deathLog = { { guid = PAL, time = t0 + 4000 }, { guid = PAL, time = t0 + 5000 }, { guid = SELF.guid, time = t0 + 5000 } },
    loot = {}, pulls = {}, spans = { { from = t0 + 3600, to = t0 + 9600 } },
    rolls = { { key = 1, item = STRIKE, itemID = 6660, time = t0 + 9000,
        need = { [SELF.guid] = 86, [PAL] = 87 }, winner = PAL, winRoll = 87, winNeed = true } } }
Add("saved_you", t0 + 600, { zone = "Westfall", context = { pct = 6, name = "Defias Pillager", rank = "normal" } })
Add("trade", t0 + 10000, { context = { received = { { link = ELIXIR, count = 5 } } } })

local list = Prose.Candidates(Row(), PAL)
local byId = {}
for _, c in ipairs(list) do byId[c.id] = c end
local run, trouble, roll = byId["visit:77/run"], byId["visit:77/trouble"], byId["visit:77/roll:1"]
Check(run ~= nil, "no run candidate")
Eq(run.angle .. "/" .. run.move, "dungeon/run", "the run's angle")
Eq(run.involvement, "together", "a run is together")
Eq(run.facts.friend.name, "Feivel", "the person goes in as the run's friend")
Eq(run.facts.fullClear, true, "every boss down")
Eq(run.facts.firstClear, true, "our first clear")
Eq(run.facts.firstVisit, true, "my first visit")
Eq(run.facts.strangers, 1, "strangers in the run")
Eq(byId.time.coveredBy, "dungeon", "the run fills most of the session")
Eq(trouble.facts.wipes, 2, "wipes")
Eq(trouble.facts.deadliest.name, "Feivel", "who died most")
Eq(trouble.sensitive, true, "their deaths are sensitive on their page")
Eq(roll.involvement, "between", "a roll we both needed on is between us")
Eq(roll.facts.winner.name, "Feivel", "the roll's winner")
Eq(roll.facts.myRoll, 86, "my roll")
Eq(roll.facts.close, true, "one point is close")
local saved = byId["row:1/saved"]
Check(saved ~= nil, "no rescue candidate")
Eq(saved.facts.pct, 6, "health left")
Eq(saved.facts.foe.name, "Defias Pillager", "the foe")
local gift = byId["trade/gift"]
Check(gift ~= nil, "no gift candidate")
Eq(gift.facts.received[1].count, 5, "the gift's items")

local trace = Prose.Trace(Row(), PAL)
Check(trace:find("visit:77/run  Notable -> Headline", 1, true), "trace lacks the run: " .. trace)
Check(trace:find("covered by dungeon", 1, true), "trace lacks the cover: " .. trace)

-- The trace goes on the tooltip only with prose on and debug.
Prose.voice = "plain"
Check(not select(5, ns.UI.DescribeItem(Row(), PAL)):find("dungeon/run", 1, true), "a trace without debug")
ns.db.settings.debug = true
Check(select(5, ns.UI.DescribeItem(Row(), PAL)):find("dungeon/run", 1, true), "no trace with debug")
ns.db.settings.debug = false
Prose.voice = nil
if os.getenv("SD_SHOW") then print(trace) end

--------------------------------------------------------------------------
Section("tiers and the point: the design's examples (planner stage 2)")

local DAY = 86400

-- A session together `id`, `start` seconds after t0, `seconds` long.
local function S(id, start, seconds, p, extra)
    p = p or {}
    p.since, p.last, p.seconds = t0 + start, t0 + start + seconds, seconds
    local session = { id = id, me = SELF.guid, source = "group", startedAt = t0 + start,
        endedAt = t0 + start + seconds, participants = { [PAL] = p }, others = 0,
        zones = { "Westfall" }, deaths = {} }
    for k, v in pairs(extra or {}) do session[k] = v end
    return session
end

local function Weighed()
    local row = Row()
    local list, h = Prose.Candidates(row, PAL)
    Prose.Weigh(list, h)
    local by = {}
    for _, c in ipairs(list) do by[c.id] = c end
    return by, Prose.Point(list), h
end

-- The row's prose in the plain voice, and its plan, printed with SD_SHOW.
local function Show(label)
    Prose.voice = "plain"
    local row = Row()
    local text = Prose.Write(row, PAL)
    local beats = Prose.Choice(row, PAL) or {}
    Prose.voice = nil
    if os.getenv("SD_SHOW") then
        local roles = {}
        for i, b in ipairs(beats) do roles[i] = b.role .. " " .. b.c.id end
        print("    " .. label .. ": " .. tostring(text) .. "\n        plan: " .. table.concat(roles, "; "))
    end
    return text, beats
end

local function Visit(id, start, seconds, opts)
    local v = { id = id, me = SELF.guid, instanceType = "party", startedAt = t0 + start,
        endedAt = t0 + start + seconds, members = { { guid = PAL, first = "Feivel" } },
        bossesKilled = {}, deaths = 0, wipes = 0, deathLog = {}, loot = {}, pulls = {}, rolls = {} }
    for k, v2 in pairs(opts) do v[k] = v2 end
    ns.db.instances[id] = v
    return v
end

-- 1. A first full clear, and a one-point roll between us.
Fresh({ S(600, 0, 1800), S(601, 2 * DAY, 1800), S(602, 4 * DAY, 3 * 3600) })
Visit(700, 4 * DAY + 600, 6000, { instanceID = 36, name = "The Deadmines", sessionIds = { 602 },
    bossesKilled = { "a", "b", "c", "d", "e", "f" }, bossTotal = 6, wipes = 2, deaths = 7,
    rolls = { { key = 1, item = STRIKE, time = t0 + 4 * DAY + 6000,
        need = { [SELF.guid] = 86, [PAL] = 87 }, winner = PAL, winRoll = 87, winNeed = true } } })
local by, point = Weighed()
Eq(point and point.id, "visit:700/run", "1: the run leads")
Eq(by["visit:700/run"].tier, Prose.TIERS.HEADLINE, "1: a first full clear is a Headline")
Eq(by["visit:700/roll:1"].tier, Prose.TIERS.NOTABLE, "1: a one-point roll between us is Notable")
Eq(by.time.tier, Prose.TIERS.LEDGER, "1: the run covers the time")
Check(by["first/meet"] == nil, "1: not a first meeting")
local text, beats = Show("1")
Eq(beats[1].c.id, "visit:700/run", "1: the run is the lead")
Eq(beats[1].role, "point", "1: as the point")
Eq(#beats, 3, "1: three sentences")
Eq(beats[2].c.id, "visit:700/roll:1", "1: the roll elaborates the run")
Eq(beats[3].c.id, "visit:700/trouble", "1: the wipes cut against it")
Eq(beats[3].rel, "but", "1: with a but")
Check(text and text:find("Deadmines", 1, true), "1: the run unnamed: " .. tostring(text))
Check(not text:find("Not one death") and not text:lower():find("no deaths"), "1: two wipes told as deathless: " .. text)
local plan1 = Prose.Plan(Row(), PAL)
Eq(plan1.paragraphs[1][1].must[1], "firstClear", "1: the lead must say why it won")
Eq(plan1.paragraphs[1][1].required[1], "run", "1: and its move is required")

-- 2. Our fifteenth Wailing Caverns, and her first gift.
local sessions = {}
for i = 1, 15 do sessions[i] = S(800 + i, (i - 1) * DAY, 3600) end
sessions[16] = S(900, 16 * DAY, 7200)
Fresh(sessions)
for i = 1, 15 do
    Visit(820 + i, (i - 1) * DAY + 60, 3000, { instanceID = 43, name = "Wailing Caverns", sessionIds = { 800 + i },
        bossesKilled = { "a", "b", "c" }, bossTotal = 8 })
end
Visit(850, 16 * DAY + 60, 3000, { instanceID = 43, name = "Wailing Caverns", sessionIds = { 900 },
    bossesKilled = { "a", "b", "c" }, bossTotal = 8 })
local gift = ns.Interactions.Add(PAL, "trade", { time = t0 + 16 * DAY + 3300,
    context = { received = { { link = ELIXIR, count = 5 } } } })
gift.session = 900
by, point = Weighed()
Eq(point and point.id, "trade/gift", "2: the first gift leads")
Eq(by["trade/gift"].tier, Prose.TIERS.HEADLINE, "2: a first trade is a Headline")
Eq(by["visit:850/run"].tier, Prose.TIERS.TEXTURE, "2: the fifteenth run is Texture")
text, beats = Show("2")
Eq(beats[1].c.id, "trade/gift", "2: the gift is the lead")
Check(text and text:find("Elixir", 1, true), "2: the gift unnamed: " .. tostring(text))

-- 3. A daily companion, nothing new: a quiet row.
sessions = {}
for i = 1, 5 do sessions[i] = S(1000 + i, (i - 1) * DAY, 7200, { levelStart = 27 + i, levelEnd = 28 + i }) end
sessions[6] = S(1010, 5 * DAY, 7200, { levelStart = 33, levelEnd = 34, quests = { 1, 2, 3, 4, 5, 6, 7, 8, 9 } },
    { deaths = { [SELF.guid] = 1 }, myLevelStart = 34, myLevelEnd = 34 })
Fresh(sessions)
by, point = Weighed()
Eq(point, nil, "3: nothing reaches Notable, a quiet row")
Eq(by["their-level"].tier, Prose.TIERS.TEXTURE, "3: an ordinary level is Texture")
Eq(by.deaths.tier, Prose.TIERS.LEDGER, "3: one death is Ledger")
text, beats = Show("3")
Eq(#beats, 1, "3: a quiet row is one sentence")
Eq(beats[1].role, "quiet", "3: told as quiet")
-- The time together led the last rows (the told-ledger), so the row is
-- told from their level, as the design has it.
Eq(beats[1].c.id, "their-level", "3: from their level")
Check(text ~= nil, "3: nothing written")

-- 4. Just nearby for fifteen minutes.
Fresh({ S(1100, 0, 1800), S(1101, DAY, 900, nil, { source = "nearby" }) })
by, point = Weighed()
Eq(point, nil, "4: a nearby quarter of an hour is quiet")
Eq(by.time.tier, Prose.TIERS.TEXTURE, "4: the time is Texture")
text, beats = Show("4")
Eq(#beats, 1, "4: one sentence")
Eq(beats[1].c.id, "time", "4: the time alone")
Eq(beats[1].short, true, "4: short")
Check(not text:find("whole"), "4: a quarter of an hour told as the whole of it: " .. text)

-- Back after our longest gap; a short gap is no reunion.
Fresh({ S(1200, 0, 1800), S(1201, 2 * DAY, 1800), S(1202, 4 * DAY, 1800), S(1203, 24 * DAY, 1800) })
by, point = Weighed()
Eq(point and point.id, "reunion", "a long gap leads")
Eq(by.reunion.facts.gapDays, 19, "the gap in days")
Eq(by.reunion.facts.isRecordGap, true, "our longest gap")
text = Show("reunion")
Check(text ~= nil, "a reunion row unwritten")
Fresh({ S(1300, 0, 1800), S(1301, 3 * DAY, 1800) })
by = Weighed()
Check(by.reunion == nil, "three days is no reunion")

-- My own milestones, with them there (the user's decision).
Fresh({ S(1400, 0, 1800), S(1401, DAY, 3600, { levelStart = 25, levelEnd = 25 },
    { myLevelStart = 29, myLevelEnd = 30 }) })
by = Weighed()
Eq(by["my-level"].tier, Prose.TIERS.NOTABLE, "my level 30 with them there is Notable")
Fresh({ S(1500, 0, 1800), S(1501, DAY, 3600, { levelStart = 55, levelEnd = 55 },
    { myLevelStart = 59, myLevelEnd = 60 }) })
by, point = Weighed()
Eq(by["my-level"].tier, Prose.TIERS.HEADLINE, "the cap with them there is a Headline")
Eq(point and point.id, "my-level", "the cap leads")
text = Show("cap")
Check(text ~= nil, "the cap row unwritten")
Eq(by.parity.facts.aheadMe, true, "levels side by side: ahead")

-- Their deaths never lead on their page.
Fresh({ S(1600, 0, 1800), S(1601, DAY, 3600, nil, { deaths = { [PAL] = 9 } }) })
by = Weighed()
Eq(by.deaths.noLead, true, "their deaths can't lead")

-- A lead that can't say why it was chosen gives way to the next candidate.
Fresh({ S(1700, 0, 1800), S(1701, DAY, 3600, { levelStart = 29, levelEnd = 30 }) })
local Render, calls = ns.Pages.Render, 0
ns.Pages.Render = function(plan, opts)
    -- The earlier rows' words (SessionProse.PicksFor) aren't this row.
    if opts.memory then return Render(plan, opts) end
    calls = calls + 1
    if calls == 1 then return "", { skipped = { "beat 1/1 (" .. plan.paragraphs[1][1].angle .. ")" }, picks = {} } end
    return Render(plan, opts)
end
Prose.voice = "plain"
local first = Prose.Choice(Row(), PAL)[1].c
text = Prose.Write(Row(), PAL)
ns.Pages.Render = Render
Prose.voice = nil
Eq(calls, 2, "tried a second point")
Check(text ~= nil and text ~= "", "nothing written after the fallback")
Check(first ~= nil, "no first point")

--------------------------------------------------------------------------
Section("the told-ledger: what led recently (planner stage 4)")

-- Each session row's lead, oldest first.
local function Leads()
    local rows = {}
    for _, item in ipairs(ns.Timeline.For(PAL)) do
        if item.kind == "session" then rows[#rows + 1] = item end
    end
    table.sort(rows, function(a, b) return a.time < b.time end)
    local leads = {}
    for i, row in ipairs(rows) do
        local beats = Prose.Choice(row, PAL)
        leads[i] = beats and beats[1].c.id or "-"
    end
    return leads
end

-- A daily companion: two hours of questing every day, a level each time.
sessions = {}
for i = 1, 8 do
    sessions[i] = S(2000 + i, (i - 1) * DAY, 7200, { levelStart = 20 + i, levelEnd = 21 + i, quests = { 1, 2, 3 } })
end
Fresh(sessions)
local leads = Leads()
for i = 3, #leads do
    Check(not (leads[i] == leads[i - 1] and leads[i] == leads[i - 2]),
        "the same lead three rows running: " .. table.concat(leads, ", "))
end

-- A bigger run still leads after two runs led: a full clear after two
-- partial ones.
sessions = {}
for i = 1, 3 do sessions[i] = S(2100 + i, (i - 1) * DAY, 7200) end
sessions[4] = S(2100, -DAY, 1800)
Fresh(sessions)
Visit(2201, 600, 3000, { instanceID = 48, name = "Blackfathom Deeps", sessionIds = { 2101 },
    bossesKilled = { "a", "b" }, bossTotal = 7 })
Visit(2202, DAY + 600, 3000, { instanceID = 48, name = "Blackfathom Deeps", sessionIds = { 2102 },
    bossesKilled = { "a", "b", "c" }, bossTotal = 7 })
Visit(2203, 2 * DAY + 600, 3000, { instanceID = 48, name = "Blackfathom Deeps", sessionIds = { 2103 },
    bossesKilled = { "a", "b", "c", "d", "e", "f", "g" }, bossTotal = 7 })
leads = Leads()
Eq(table.concat(leads, ", "), "first/meet, visit:2201/run, visit:2202/run, visit:2203/run",
    "the full clear leads although runs led the two rows before")
by = Weighed()
Eq(by["visit:2203/run"].tier, Prose.TIERS.HEADLINE, "and is still a Headline")

-- The ledger follows the data: a new session is planned with the rest.
Prose.voice = "plain"
ns.db.settings.debug = true
local traced = select(5, ns.UI.DescribeItem(Row(), PAL))
Check(traced:find("led recently: dungeon/run, dungeon/run, new_face/meet", 1, true), "the trace lacks the ledger: " .. traced)
local later = S(0, 3 * DAY, 1800)
later.id = nil
ns.Sessions.New(later)
local after = select(5, ns.UI.DescribeItem(Row(), PAL))
Check(after:find("led recently: dungeon/run, dungeon/run, dungeon/run", 1, true),
    "a new session left the ledger stale: " .. after)
ns.db.settings.debug = false
Prose.voice = nil

-- How long a long profile takes: every row of sixty sessions, in prose
-- (printed with SD_SHOW; the ledger is built once and kept).
if os.getenv("SD_SHOW") then
    sessions = {}
    for i = 1, 60 do
        sessions[i] = S(3000 + i, (i - 1) * DAY, 3600 + (i % 5) * 900,
            { levelStart = 10 + i % 40, levelEnd = 11 + i % 40, quests = { 1, 2 } },
            { deaths = { [SELF.guid] = i % 4, [PAL] = i % 3 } })
    end
    Fresh(sessions)
    Prose.voice = "plain"
    local clock = os.clock()
    for _, item in ipairs(ns.Timeline.For(PAL)) do ns.UI.DescribeItem(item, PAL) end
    local first = os.clock() - clock
    clock = os.clock()
    for _, item in ipairs(ns.Timeline.For(PAL)) do ns.UI.DescribeItem(item, PAL) end
    print(("    sixty rows: %.0f ms the first time, %.0f ms again"):format(first * 1000, (os.clock() - clock) * 1000))
    Prose.voice = nil
end

-- A favour returned is told once: the later gifts are only gifts. (Spaced
-- out, or trading would be routine between us.)
sessions = {}
for i = 1, 7 do sessions[i] = S(3100 + i, (i - 1) * DAY, 3600) end
Fresh(sessions)
local function Trade(session, context)
    local row = ns.Interactions.Add(PAL, "trade", { time = t0 + (session - 3101) * DAY + 600, context = context })
    row.session = session
end
Trade(3101, { given = { { link = ELIXIR, count = 1 } } })
Trade(3104, { received = { { link = ELIXIR, count = 1 } } })
Trade(3107, { received = { { link = ELIXIR, count = 1 } } })
local function Gift(time)
    for _, item in ipairs(ns.Timeline.For(PAL)) do
        if item.session and item.session.startedAt == time then
            local gifts, h = Prose.Candidates(item, PAL)
            Prose.Weigh(gifts, h, Prose.LedgerBefore(item, PAL))
            for _, c in ipairs(gifts) do
                if c.id == "trade/gift" then return c, item end
            end
        end
    end
end
local firstGift = Gift(sessions[4].startedAt)
Eq(firstGift.facts.returned, true, "the first gift back returns a favour")
Eq(firstGift.tier, Prose.TIERS.HEADLINE, "and rises for it")
Eq(Prose.LedgerBefore(Row(), PAL).told.returned, true, "the ledger keeps it as told")
local secondGift = Gift(sessions[7].startedAt)
Eq(secondGift.facts.returned, nil, "the second gift doesn't say it again")
Eq(secondGift.tier, Prose.TIERS.NOTABLE, "and doesn't rise for it")

-- Each row's words are varied against the rows before it, and stay put.
sessions = {}
for i = 1, 12 do
    sessions[i] = S(3200 + i, (i - 1) * DAY, 7200, { levelStart = 20 + i, levelEnd = 21 + i, quests = { 1, 2, 3 } })
end
Fresh(sessions)
Prose.voice = "plain"
local function Texts()
    local rows, out = {}, {}
    for _, item in ipairs(ns.Timeline.For(PAL)) do
        if item.kind == "session" then rows[#rows + 1] = item end
    end
    table.sort(rows, function(a, b) return a.time < b.time end)
    for i, row in ipairs(rows) do out[i] = select(2, ns.UI.DescribeItem(row, PAL)) end
    return out
end
local texts = Texts()
-- Memory only draws recent words less, so they may come back later on.
for i = 1, #texts do
    for j = math.max(1, i - 4), i - 1 do
        Check(texts[i] ~= texts[j], "the same words on nearby rows: " .. texts[i])
    end
end
local PicksFor, unvaried, differs = Prose.PicksFor, nil, false
Prose.PicksFor = function() return nil end
unvaried = Texts()
Prose.PicksFor = PicksFor
for i = 1, #texts do differs = differs or texts[i] ~= unvaried[i] end
Check(differs, "the earlier rows' words changed nothing")
-- Drawn again: the same words.
local again = Texts()
for i = 1, #texts do Eq(again[i], texts[i], "a row changed when drawn again") end
ns.Sessions.New((function()
    local later = S(0, 12 * DAY, 3600)
    later.id = nil
    return later
end)())
local withLater = Texts()
for i = 1, #texts do Eq(withLater[i], texts[i], "a later session changed an earlier row") end
Prose.voice = nil

--------------------------------------------------------------------------
Section("/sd testdata: Tessa, a timeline of every case")

ns.TestData.Write()
local TESSA = ns.TestData.PROSE_GUID
local function TessaRows()
    local rows = {}
    for _, item in ipairs(ns.Timeline.For(TESSA)) do
        if item.kind == "session" then rows[#rows + 1] = item end
    end
    table.sort(rows, function(a, b) return a.session.startedAt < b.session.startedAt end)
    return rows
end
local tessaLeads, tessaShown = {}, {}
for i, row in ipairs(TessaRows()) do
    local beats = Prose.Choice(row, TESSA)
    Check(beats ~= nil, "row " .. i .. ": nothing to say")
    tessaLeads[beats[1].c.angle .. "/" .. beats[1].c.move] = true
    tessaShown[i] = beats[1].c.id .. " (" .. beats[1].role .. ")"
    for _, entry in ipairs(beats) do tessaLeads["any:" .. entry.c.angle .. "/" .. entry.c.move] = true end
end
if os.getenv("SD_SHOW") then print("    tessa: " .. table.concat(tessaShown, ", ")) end
for _, kind in ipairs({ "new_face/added", "any:new_face/meet", "rescue/saved", "rescue/helped", "trade/given",
    "trade/gift", "dungeon/run", "any:dungeon/trouble", "any:dungeon/roll", "reunion/gap", "open/climb",
    "campfire/sat", "chat/heard", "together/rares", "ding/level" }) do
    Check(tessaLeads[kind], "no row leads with " .. kind .. ": " .. table.concat(tessaShown, ", "))
end
for _, voice in ipairs({ "plain", "warm", "wry", "terse", "mixed" }) do
    Prose.voice = voice
    for i, row in ipairs(TessaRows()) do
        local _, prose = ns.UI.DescribeItem(row, TESSA)
        if os.getenv("SD_SHOW") then print("    " .. voice .. " " .. i .. ": " .. prose) end
        Check(not prose:find("[{}<>]") and not prose:find("nil"), voice .. " row " .. i .. ": leftover syntax: " .. prose)
        Eq(select(2, ns.UI.DescribeItem(row, TESSA)), prose, voice .. " row " .. i .. " changed")
    end
end
Prose.voice = nil
local witnessed = false
for _, row in ipairs(TessaRows()) do
    for _, c in ipairs((Prose.Candidates(row, TESSA))) do witnessed = witnessed or c.id:find("/watched", 1, true) ~= nil end
end
Check(witnessed, "no row has her watching me die")
Eq(ns.Characters.Get(TESSA).sex, 3, "she is a woman, for the pronouns")
ns.TestData.Remove()
Check(not ns.Diary.IsDiary(TESSA), "Tessa outlived /sd testdata remove")
Eq(#ns.Sessions.For(TESSA), 0, "her sessions outlived it")
Eq(#ns.Instances.For(TESSA), 0, "her runs outlived it")

--------------------------------------------------------------------------
Section("/sd prose")

Fresh({ Westfall("group") })
Slash("prose wry")
Eq(Prose.voice, "wry", "/sd prose wry")
Slash("prose nonsense")
Eq(Prose.voice, "wry", "an unknown voice changes nothing")
Slash("prose off")
Eq(Prose.voice, nil, "/sd prose off")
Eq(select(2, ns.UI.DescribeItem(Row(), PAL)), before, "off again: the old headline")
