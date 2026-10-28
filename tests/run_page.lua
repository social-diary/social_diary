-- A dungeon run's page in Your Diary, the keepsake page
-- (.claude/ui-proposal/super-plate.md, B, round 5; UI/Journey/Run.lua):
-- what it says (Core/DungeonRun.lua's Inside, LevelSpan, Bosses,
-- Keepsakes, Fallen, in UI/Journey/Text/Run.lua's words), where it lays
-- everything (Core/RunPage.lua's plan: nothing meets, at every count), and
-- the page in the book: a level with runs opens on its first, its rubric
-- steps through them to the plates, a run's ledger row opens it, a
-- keepsake shows the game's item tooltip, the slip the rest, the fallen
-- note every death, a click on the title lays the run out on the table
-- with "Your Diary" on its bookmark, and putting it away gives back the
-- same run's page.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Run, RunPage, Text = ns.DungeonRun, ns.RunPage, ns.UI.JourneyText
local RUN = RunPage.RUN

mock.now = 1795000000

local ME = ns.ownGUID
local BROM, ZURI, GRIM = "Player-1-0000B001", "Player-1-0000B002", "Player-1-0000B003"
local function Link(q, id, name) return ("|cnIQ%d:|Hitem:%d::::::::22:1491::::::::|h[%s]|h|r"):format(q, id, name) end
local function Diary(guid) return guid == BROM end

--------------------------------------------------------------------------
Section("the keepsakes, in the user's order")

local visit = {
    id = 900, me = ME, instanceID = 47, name = "Razorfen Kraul", startedAt = 1000, endedAt = 4000,
    members = { { guid = ME, first = "You", level = 22 }, { guid = BROM, first = "Brom" },
        { guid = ZURI, first = "Zuri" }, { guid = GRIM, first = "Grimble" } },
    loot = {
        { guid = ME, item = Link(2, 101, "Green Boots"), itemID = 101, time = 1100 },
        { guid = ME, item = Link(3, 102, "My Blue"), itemID = 102, time = 1200 },
        { guid = BROM, item = Link(3, 103, "Brom's Blue"), itemID = 103, time = 1300 },
        { guid = BROM, item = Link(2, 104, "Brom's Green"), itemID = 104, time = 1350 },
        { guid = GRIM, item = Link(3, 105, "Grimble's Blue"), itemID = 105, time = 1400 },
        { guid = GRIM, item = Link(4, 106, "Grimble's Epic"), itemID = 106, time = 1500 },
        { guid = ME, item = Link(4, 107, "My Epic"), itemID = 107, time = 1600 },
        { guid = ME, item = Link(4, 107, "My Epic"), itemID = 107, time = 1601 },
    },
    rolls = {
        { key = "r1", item = Link(3, 108, "Rolled Ring"), itemID = 108, time = 1700, winner = ME },
        { key = "r2", item = Link(4, 107, "My Epic"), itemID = 107, time = 1599, winner = ME },
    },
}
local keep = Run.Keepsakes(visit, Diary)
local names = {}
for _, it in ipairs(keep.shown) do names[#names + 1] = it.item:match("%[(.-)%]") end
Eq(table.concat(names, ", "), "My Epic, My Blue, Rolled Ring, Brom's Blue, Grimble's Epic",
    "yours blue and up, then a diary entry's blue, then anyone's epic")
Eq(#keep.rest, 3, "the rest: your green, Brom's green, a stranger's blue")
Eq(keep.shown[1].mine and keep.shown[1].tier, 1, "your epic is yours, tier 1")
Eq(keep.shown[4].tier, 2, "Brom's blue (a diary entry's) is tier 2")
Eq(keep.shown[5].tier, 3, "a stranger's epic is tier 3")
local rest = {}
for _, it in ipairs(keep.rest) do rest[#rest + 1] = it.item:match("%[(.-)%]") end
Check(table.concat(rest, ","):find("Grimble's Blue") ~= nil, "a stranger's blue is counted, never shown")
Eq(#Run.Keepsakes({ id = 1, me = ME }, Diary).shown, 0, "a run with no loot (an old save) shows none")
Eq(#Run.Keepsakes({ id = 1, me = ME }, Diary).rest, 0, "and counts none")
-- Six worth showing: five shown, the sixth counted.
local six = { id = 901, me = ME, loot = {} }
for i = 1, 6 do six.loot[i] = { guid = ME, item = Link(3, 200 + i, "B" .. i), itemID = 200 + i, time = i } end
local k6 = Run.Keepsakes(six, Diary)
Eq(#k6.shown .. "+" .. #k6.rest, "5+1", "at most five shown, the rest counted")

--------------------------------------------------------------------------
Section("the fallen, the bosses, the level span and the time inside")

visit.deathLog = {
    { guid = BROM, time = 1300, killer = { name = "Aggem Thorncurse" } },
    { guid = ME, time = 1200, killer = { name = "Razorfen Defender" } },
    { guid = ME, time = 1800, killer = { name = "Death Speaker Jargba" } },
    { guid = GRIM, time = 1900 },
    { guid = BROM, time = 2000, killer = { name = "Overlord Ramtusk" } },
}
local fallen, deaths = Run.Fallen(visit)
Eq(deaths, 5, "every death counted")
Eq(#fallen, 3, "each one who fell once")
Eq(fallen[1].me and fallen[1].times, 2, "you first (your first death came first), twice")
Eq(fallen[2].first .. fallen[2].times, "Brom2", "Brom, twice")
Eq(fallen[3].first, "Grimble", "a stranger named from the party")

visit.spans = { { from = 1000, to = 1600 }, { from = 1700, to = 2500 } }
Eq(Run.Inside(visit), 1400, "time inside: the spans, the ghost run's time away left out")
Eq(Run.Inside({ startedAt = 0, endedAt = 600 }), 600, "no spans: start to end")

local j = { startLevel = 20, levels = { [21] = { at = 500 }, [22] = { at = 900 }, [23] = { at = 2200 } } }
local from, to = Run.LevelSpan(visit, j)
Eq(from .. "-" .. to, "22-23", "from your level in the party, to the level reached inside")
visit.members[1].level = nil
from, to = Run.LevelSpan(visit, j)
Eq(from .. "-" .. to, "22-23", "from the route where the party has no level")
from, to = Run.LevelSpan(visit, { startLevel = 20, levels = { [22] = { at = 900 } } })
Eq(from .. "-" .. to, "22-22", "no level-up inside")

Eq(Text.RunSubtitle(22, 23, 6720), "Level 22\226\128\14723, 1 hour 52 minutes", "the subtitle, a level-up inside")
Eq(Text.RunSubtitle(22, 22, 2100), "Level 22, 35 minutes", "the subtitle, none")
Eq(Text.RunDuration(7200), "2 hours", "two hours")
Eq(Text.RunBosses(4, 7, false), "4 out of 7 bosses slain", "the boss strip")
Eq(Text.RunBosses(0, 6, false), "0 out of 6 bosses slain", "no kills, no special words")
Eq(Text.RunBosses(6, 6, true), "Full run", "a full run")
Eq(Text.RunMore(11), "and eleven more", "the slip")
Eq(Text.RunFell(1) .. "|" .. Text.RunFell(2) .. "|" .. Text.RunFell(6), "we fell once|we fell twice|we fell six times",
    "how often we fell")
Eq(Text.RunFallen({ "you twice", "Brom", "Zuri", "Grimble", "Oswin" }, function(w) return #w <= 34 end),
    "you twice, Brom, and three others", "names while they fit, the rest counted")
Eq(Text.RunFallen({ "you twice", "Brom", "Zuri" }, function(w) return #w <= 34 end),
    "you twice, Brom, Zuri", "everyone, where they fit")
Eq(Text.RunWhose({ mine = true, atLast = true }), "yours at last", "yours at last")
Eq(Text.RunWhose({}, "Atlas"), "Atlas'", "a name ending in s")
Eq(Text.RunStrangers(1), "and one you didn't keep", "strangers after the signatures")

--------------------------------------------------------------------------
Section("the plan: nothing meets, at every count")

-- Separating axes: whether two convex outlines overlap (touching edges do
-- not count).
local function Meets(a, b)
    for _, poly in ipairs({ a, b }) do
        for i = 1, #poly do
            local p, q = poly[i], poly[i % #poly + 1]
            local nx, ny = q[2] - p[2], p[1] - q[1]
            local function Span(pts)
                local lo, hi = math.huge, -math.huge
                for _, v in ipairs(pts) do
                    local d = v[1] * nx + v[2] * ny
                    lo, hi = math.min(lo, d), math.max(hi, d)
                end
                return lo, hi
            end
            local alo, ahi = Span(a)
            local blo, bhi = Span(b)
            if ahi <= blo + 1e-6 or bhi <= alo + 1e-6 then return false end
        end
    end
    return true
end
local Corners = RunPage.Corners
local tried = 0
for n = 0, 5 do
    for _, more in ipairs({ 0, 11 }) do
        for _, map in ipairs({ true, false }) do
            for _, two in ipairs({ false, true }) do
                for seed = 1, 40, 3 do
                    local lines = {}
                    for i = 1, n do lines[i] = RunPage.Most(i, n, more, two) end
                    local plan = RunPage.Plan({ n = n, more = more, lines = lines, map = map, total = true,
                        twoLines = two, bossW = 140, moreW = 92, seed = seed * 101 })
                    local pieces = {}
                    for i, c in ipairs(plan.cards) do pieces[#pieces + 1] = { "K" .. i, c } end
                    if plan.slip then pieces[#pieces + 1] = { "slip", plan.slip } end
                    if plan.scrap then pieces[#pieces + 1] = { "scrap", plan.scrap } end
                    if plan.boss then pieces[#pieces + 1] = { "boss", plan.boss } end
                    local F = RUN.fallen
                    pieces[#pieces + 1] = { "fallen", { x = F.x, y = F.y, w = F.w, h = 60, turn = 0 } }
                    pieces[#pieces + 1] = { "title", { x = 20, y = 20, w = 426, h = 100 + plan.shift, turn = 0 } }
                    pieces[#pieces + 1] = { "sig", { x = 20, y = 478, w = 420, h = 26, turn = 0 } }
                    -- The slip is pinned on its card, the strip pasted on the scrap: those two pairs meet.
                    local allowed = { ["slip|K" .. n] = true, ["boss|scrap"] = true, ["scrap|boss"] = true,
                        ["K" .. n .. "|slip"] = true }
                    for a = 1, #pieces do
                        local ca = Corners(pieces[a][2])
                        for _, p in ipairs(ca) do
                            Check(p[1] >= 0 and p[1] <= 466 and p[2] >= 0 and p[2] <= 534,
                                ("%s lies on the page (n %d, more %d)"):format(pieces[a][1], n, more))
                        end
                        for b = a + 1, #pieces do
                            local key = pieces[a][1] .. "|" .. pieces[b][1]
                            if not allowed[key] then
                                Check(not Meets(ca, Corners(pieces[b][2])),
                                    ("%s and %s meet (n %d, more %d, map %s, two lines %s, seed %d)"):format(
                                        pieces[a][1], pieces[b][1], n, more, tostring(map), tostring(two), seed))
                            end
                        end
                    end
                    if plan.slip then
                        local last = plan.cards[n]
                        Check(plan.slip.y >= last.y + last.h - RUN.more.up - 0.01,
                            "the slip lies on its card's foot, under its \"whose\" line")
                        Check(Meets(Corners(plan.slip), Corners(last)), "the slip is pinned on the last card")
                    end
                    if plan.boss and plan.scrap then
                        Check(Meets(Corners(plan.boss), Corners(plan.scrap)), "the strip is pasted over the scrap")
                    end
                    tried = tried + 1
                end
            end
        end
    end
end
Check(tried > 300, "every count tried")

Eq(RunPage.Most(5, 5, 3, false), 1, "the card the slip is pinned to (K5) takes one line")
Eq(RunPage.Most(4, 4, 3, false), 1, "and K4 when it is the last")
Eq(RunPage.Most(5, 5, 0, false), 2, "with exactly five, K5 keeps two")
Eq(RunPage.Most(1, 5, 0, true), 1, "under a two-line title, K1 one line")
Eq(RunPage.Most(2, 5, 0, true), 2, "K2 two")
local p0 = RunPage.Plan({ n = 0, map = true, total = true, bossW = 100, seed = 1 })
Eq(p0.scrap.x .. "," .. p0.scrap.y, "148,160", "no keepsakes: the scrap in the middle")
Check(p0.quiet ~= nil and p0.slip == nil, "no keepsakes: the quiet line, no slip")
local pm = RunPage.Plan({ n = 2, lines = { 1, 1 }, map = false, total = true, bossW = 100, seed = 1 })
Eq(pm.scrap, nil, "no map known: no scrap")
Eq(pm.boss.x .. "," .. pm.boss.y, "28,306", "the strip alone in its place")
Eq(RunPage.Plan({ n = 1, lines = { 1 }, map = true, total = false, seed = 1 }).boss, nil,
    "no boss total known: no strip")
local two = RunPage.Plan({ n = 5, more = 2, lines = { 1, 2, 2, 2, 1 }, map = true, total = true, twoLines = true, seed = 3 })
local one = RunPage.Plan({ n = 5, more = 2, lines = { 1, 2, 2, 2, 1 }, map = true, total = true, seed = 3 })
Eq(two.cards[1].y - one.cards[1].y, RUN.title.shift, "a two-line title moves the top row down")
Eq(two.cards[4].y, one.cards[4].y, "and not the lower row")
Eq(two.sub.y - one.sub.y, RUN.title.shift, "nor fails to move the subtitle")
local w = function(s) return s == 28 and 380 or 500 end
local size, twoLines = RunPage.TitleSize(w)
Eq(tostring(size) .. tostring(twoLines), "32true", "past 360 px at 28, two lines at 32")
size = RunPage.TitleSize(function(s) return s * 7 end)
Eq(size, 46, "a short name at its largest")
local a = RunPage.Plan({ n = 3, lines = { 2, 2, 2 }, map = true, total = true, seed = 42 })
local b = RunPage.Plan({ n = 3, lines = { 2, 2, 2 }, map = true, total = true, seed = 42 })
Eq(a.cards[2].x .. a.cards[2].turn, b.cards[2].x .. b.cards[2].turn, "the same run lies the same way every time")

--------------------------------------------------------------------------
Section("the page in the book")

SlashCmdList.SOCIALDIARY("testdata")
local G = ns.TestData.GUID
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local YD = ns.UI.YourDiary
local e = page.recap.entries[page.open]
local R = ns.JourneyRecap
-- Since the pages go by sitting (.claude/sittings-plan.md), a level never
-- opens on a run: its newest sitting's plates. Its runs are pages of the
-- sittings they began in, listed under them.
Eq(page.mode, "plates", "the newest entry opens on its plates")
Eq(e.spliced, false, "setup: the newest entry is read by sitting")
Eq(page.piece, nil, "setup: no sitting chosen yet")
local runs, holder = {}, {}
for k, p in ipairs(e.pieces) do
    Eq(YD.RunsOf(p), p.runs, "a piece's runs are its own")
    for _, visit in ipairs(p.runs) do
        Check(R.RunWorthy(visit), "a piece holds a run with no boss killed")
        runs[#runs + 1] = visit
        holder[visit.id] = k
    end
end
Check(#runs >= 1, "the newest entry has a recorded run")
local RFK
for _, v in ipairs(runs) do
    if v.instanceID == 47 then RFK = v end
end
Check(RFK, "today's Razorfen Kraul is one of them")

-- The ledger's row of a run opens it, in the sitting it began in: that
-- sitting ticked, the run's line and its ledger row inked under.
YD.OpenRun(RFK.id, page.open)
Eq(page.mode .. ":" .. tostring(page.runVisit), "run:" .. RFK.id, "a run's row opens that run")
Eq(page.piece, holder[RFK.id], "in the sitting it began in")
local current, line, chosen
for _, item in ipairs(page.items) do
    if item.zone and item.zone.dungeon and item.zone.dungeon.visit == RFK then current = item.current end
    if item.run == RFK then line = item.current end
    if item.sitting and item.chosen then chosen = item.sitting end
end
Eq(current, true, "its ledger row is marked while it is open")
Eq(line, true, "its line under its sitting is marked while it is open")
Eq(chosen, holder[RFK.id], "its sitting is the one ticked")

-- What the page shows of it.
local run = page.run
local hits = run.used.hit
local kept = run.keepsakes
Check(#kept.shown >= 1, "the run's keepsakes shown")
local items, slip, fallenHit, titleHit = 0, nil, nil, nil
for i = 1, hits.n do
    local h = hits[i]
    if h.item then
        items = items + 1
        h.scripts.OnEnter(h)
        Eq(GameTooltip.link, h.item.item, "a keepsake shows the game's item tooltip")
    end
end
Eq(items, #kept.shown, "every keepsake shown has the item tooltip")
local Spiteful
for _, it in ipairs(kept.shown) do
    if it.item:find("Spiteful Death Charm") then Spiteful = it end
end
Check(Spiteful and Spiteful.atLast and kept.shown[1] == Spiteful, "the charm, yours at last, first")
for i = 1, hits.n do
    local h = hits[i]
    if h.box == run.plan.slip then slip = h end
    if h.box and h.box.x == RUN.fallen.x - 4 then fallenHit = h end
end
if #kept.rest > 0 then
    Check(slip, "the slip has its tooltip")
    slip.scripts.OnEnter(slip)
    Eq(#GameTooltip.lines, #kept.rest, "the slip lists the rest")
end
local _, all = Run.Fallen(RFK)
Check(fallenHit, "the fallen note has its tooltip")
fallenHit.scripts.OnEnter(fallenHit)
Eq(#GameTooltip.lines, all, "the fallen note lists every death")
Check(GameTooltip.lines[1][1]:find(" died to ") ~= nil, "each with what killed them: " .. GameTooltip.lines[1][1])

-- A click on the title lays the run out; putting it away gives this page back.
local J = ns.UI.Journal
ns.UI.OpenVisit(RFK.id, "journey")
Check(J.visit and J.visit.from == "journey", "the run is out, from Your Diary")
local spread = ns.UI.DungeonPage.Spread()
Eq(spread.back.words:GetText(), "Your Diary", "its bookmark leads back to the diary")
Eq(J.view, "journey", "the book is left on Your Diary")
ns.UI.DungeonPage.Close()
Eq(J.visit, nil, "put away")
Eq(page.mode .. ":" .. page.runVisit, "run:" .. RFK.id, "the same run's page is there")

-- Laid flat: nothing turns.
ns.SetSetting("flatSheets", true)
ns.UI.RedrawJourneyPage()
for i = 1, run.used["strip:keepsake1"].n do Eq(run.used["strip:keepsake1"][i].turn, 0, "a keepsake laid flat") end
ns.SetSetting("flatSheets", false)

-- An icon that comes in late: the page drawn again.
ns.UI.RedrawJourneyPage()
-- (The mock has no icons, so every keepsake waits for one.)
Eq(run.waiting, true, "a keepsake whose icon the client has not yet waits for it")
local before = run.plan
mock.fire("GET_ITEM_INFO_RECEIVED", 6685, true)
Check(run.plan ~= before, "drawn again when an item's icon came in")
run.waiting = nil
before = run.plan
mock.fire("GET_ITEM_INFO_RECEIVED", 6685, true)
Check(run.plan == before, "not drawn again when nothing waited")
