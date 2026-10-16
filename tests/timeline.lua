-- The profile timeline: how rows fold into exchanges, sessions and visits,
-- how they are worded, and the page that draws them. /sd testdata writes
-- the sample entry that exercises all of it at once.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local Reset = T.BlankDiary
local ns = T.Boot()
local SELF = F.SELF

--------------------------------------------------------------------------
Section("timeline taxonomy (TLN-1 to TLN-9)")

-- A virtual list with lines of their own height stays inside its own: a
-- tall line shows fewer below it, and scrolling still reaches the last.
do
    local shown = {}
    local list = ns.UI.VirtualList(UIParent, 20, 5, function(l) return CreateFrame("Frame", nil, l) end,
        function(row, item) shown[#shown + 1] = item.n end)
    list:SetData({ { n = 1 }, { n = 2, height = 58 }, { n = 3 }, { n = 4 }, { n = 5 }, { n = 6, height = 6 } })
    Eq(table.concat(shown, ","), "1,2,3", "lines past the list's height were shown")
    Eq(list.bar.max, 2, "the scroll range does not reach the last line")
    shown = {}
    list:SetOffset(2)
    Eq(table.concat(shown, ","), "3,4,5,6", "scrolled down, the last lines do not fill the list")
    shown = {}
    list:SetData({ { n = 1 }, { n = 2 }, { n = 3 } })
    Eq(list.bar.max, 0, "a list that fits scrolls")
end

-- Whispers and /say look apart: the same bubble, a whisper's in the chat's
-- whisper colour, which follows the player's own chat settings.
do
    local _, _, _, icon = ns.UI.DescribeItem({ kind = "row", time = 0, row = { type = "whisper_in", excerpt = "hi" } })
    Eq(icon, "whisper", "a whisper's icon")
    _, _, _, icon = ns.UI.DescribeItem({ kind = "row", time = 0, row = { type = "say", excerpt = "hi" } })
    Eq(icon, "talk", "a /say's icon")
    Eq(select(2, ns.Style.ArtTint("talk")), 1, "the /say bubble is tinted")
    local r, g, b = ns.Style.ArtTint("whisper")
    Check(r == 1 and g == 0.5 and b == 1, "a whisper's bubble is not the default whisper colour")
    _G.ChatTypeInfo = { WHISPER = { r = 0.6, g = 0.2, b = 0.9 } }
    r = ns.Style.ArtTint("whisper")
    Eq(r, 0.6, "a whisper's bubble does not follow the chat colour")
    _G.ChatTypeInfo = nil

    -- Party lines: the same bubble again, in the chat's party blue.
    _, _, _, icon = ns.UI.DescribeItem({ kind = "row", time = 0, row = { type = "party", excerpt = "hi" } })
    Eq(icon, "party", "a party line's icon")
    r, g, b = ns.Style.ArtTint("party")
    Check(r == 0.667 and g == 0.667 and b == 1, "a party line's bubble is not the default party colour")
    _G.ChatTypeInfo = { PARTY = { r = 0.2, g = 0.4, b = 0.8 } }
    Eq(ns.Style.ArtTint("party"), 0.2, "a party line's bubble does not follow the chat colour")
    _G.ChatTypeInfo = nil
end

local PAL = "Player-4620-00BBBBBB"
local t0 = 1795000000

-- A clean diary with one entry, added at `addedAt`. Sessions go in before
-- the first read: Sessions keeps an in-memory index of who was in which.
local function Fresh(addedAt, sessions)
    Reset()
    mock.now = addedAt
    ns.Characters.Observe(PAL, { first = "Trade", surname = "Partner", level = 6, faction = "Horde" })
    ns.Diary.Add(PAL, { source = "test" })
    for _, session in ipairs(sessions or {}) do ns.db.sessions[session.id] = session end
end

local function Row(kind, time, data, session)
    data = data or {}
    data.time = time
    local row = ns.Interactions.Add(PAL, kind, data)
    row.session = session
    table.sort(ns.db.interactions[PAL], function(a, b) return a.time < b.time end)
    return row
end

local function Kinds(list)
    local out = {}
    for i = 1, #list do out[i] = list[i].kind end
    return table.concat(out, ",")
end

local function Session(id, start, seconds, p, extra)
    p.since, p.last, p.seconds = start, start + seconds, seconds
    local session = { id = id, me = SELF.guid, source = "group", startedAt = start,
        endedAt = start + seconds, participants = { [PAL] = p }, others = 0,
        zones = { "Duskwood" }, deaths = {} }
    for k, v in pairs(extra or {}) do session[k] = v end
    return session
end

-- TLN-5: quality from the link, either way a client writes it.
local JERKY_LINK = "|cnIQ1:|Hitem:117::::::::3:1485:::::::::|h[Tough Jerky]|h|r"
local SWORD_LINK = "|cnIQ2:|Hitem:2:::::::::::::::::|h[Green Sword]|h|r"
Eq(ns.Timeline.Quality(JERKY_LINK), 1, "quality from |cnIQ")
Eq(ns.Timeline.Quality("|cff1eff00|Hitem:2|h[Old Green]|h|r"), 2, "quality from a colour code")
Eq(ns.Timeline.Quality("[Linen Cloth]"), nil, "a bare name has no quality")

-- TLN-3's tiers.
local function Budget(seconds) return table.concat({ ns.Timeline.Budget(seconds) }, "/") end
Eq(Budget(29 * 60), "1/3", "under 30 min")
Eq(Budget(30 * 60), "2/4", "from 30 min")
Eq(Budget(2 * 60 * 60), "3/6", "from 2 h")

-- The exchange that prompted this, as it happened: whispers either side of
-- a trade and its return, the diary entry made, then one more whisper. The
-- add neither splits the exchange nor joins it; it goes above (TLN-8).
local JERKY = { { link = JERKY_LINK, count = 3 } }
Fresh(t0 + 85)
local steps = {
    { "whisper_out", { excerpt = "sup dude. could u help me out real quick?" } },
    { "whisper_out", { excerpt = "Im developing an addon and need to trade" } },
    { "trade", { context = { given = JERKY } } },
    { "whisper_out", { excerpt = "can u trade it back?" } },
    { "whisper_out", { excerpt = "or anything really" } },
    { "trade", { context = { received = JERKY } } },
    { "whisper_out", { excerpt = "tyvm" } },
    { "whisper_in", { excerpt = "<3" } },
}
for i, step in ipairs(steps) do Row(step[1], t0 + i * 10, step[2]) end
Row("whisper_in", t0 + 90, { excerpt = "np" })

local tl = ns.Timeline.For(PAL)
Eq(Kinds(tl), "added,exchange", "the exchange is not one episode under the add")
local ex = tl[2]
Eq(#ex.all, 9, "rows in the exchange")
Eq(ex.all[1].row.excerpt, "sup dude. could u help me out real quick?", "exchange rows not oldest first")
Eq(ex.all[9].row.excerpt, "np", "the whisper after the add is not in the exchange")
Eq(ex.all[1].depth, 1, "exchange rows not one level in")
Eq(ex.key, ns.db.interactions[PAL][1], "exchange key is not its first stored row")
Eq(#ex.lines, 0, "white trades shown as moments")
Eq(ex.hidden, 9, "folded-away count")

local _, text, sub, icon, story = ns.UI.DescribeItem(ex, PAL)
local zone = ex.zones[1]
Eq(text, "Traded for 1 min" .. (zone and (" in " .. zone) or ""), "exchange headline")
Eq(sub, "2 trades: gave 3x " .. JERKY_LINK .. "; got 3x " .. JERKY_LINK .. "  ·  7 messages", "exchange details")
Eq(icon, "trade", "exchange icon is its headline's")
Check(story:find("and chatted\n"), "the tooltip does not name every activity: " .. story)

-- Two rows stay single lines; a long pause starts a new run. An add before
-- a run goes below it.
Fresh(t0)
local gap = ns.Timeline.EXCHANGE_GAP
Row("whisper_in", t0 + 10, { excerpt = "hi" })
Row("whisper_out", t0 + 20, { excerpt = "hey" })
Row("whisper_in", t0 + 20 + gap + 1, { excerpt = "later" })
Row("say", t0 + 30 + gap, { excerpt = "o/" })
Row("yell", t0 + 40 + gap, { excerpt = "HEY" })
Eq(Kinds(ns.Timeline.For(PAL)), "exchange,row,row,added", "runs split on the gap")

-- Any type folds, known or not.
Fresh(t0)
for i = 1, 3 do Row("duel", t0 + 600 + i) end
tl = ns.Timeline.For(PAL)
Eq(Kinds(tl), "exchange,added", "an unknown type did not fold")
_, text, sub = ns.UI.DescribeItem(tl[1], PAL)
Check(text:find("^Crossed paths"), "unknown-type headline: " .. text)
Eq(sub, "3 other interactions", "unknown-type details")

-- A short questing session (TLN-3: one activity). Moments the headline does
-- not name get lines -- the rare and the green trade -- and the rest is
-- counted. Grouped goes unsaid: questing already means it.
local SHORT, LONG = 301, 302
local quests = {}
for i = 1, 18 do quests[i] = i end
Fresh(t0, {
    Session(SHORT, t0 + 1000, 20 * 60, { quests = { 7 },
        rares = { { name = "Mor'Ladim", time = t0 + 1100 } } }),
    Session(LONG, t0 + 10000, 3 * 3600 + 300, { quests = quests, levelStart = 21, levelEnd = 24,
        rares = { { name = "Mor'Ladim", time = t0 + 11000 } } },
        { zones = { "Westfall", "Duskwood" }, deaths = { [SELF.guid] = 2 } }),
})
Row("trade", t0 + 1200, { context = { given = { { link = SWORD_LINK, count = 1 } } } }, SHORT)
Row("trade", t0 + 1300, { context = { given = JERKY } }, SHORT)
Row("whisper_in", t0 + 1400, { excerpt = "nice" }, SHORT)
Row("trade", t0 + 12000, { context = { given = { { link = SWORD_LINK, count = 1 } } } }, LONG)
for i = 1, 5 do Row("whisper_out", t0 + 12000 + i, { excerpt = "w" .. i }, LONG) end

tl = ns.Timeline.For(PAL)
Eq(Kinds(tl), "session,session,added", "sessions")
local short, long = tl[2], tl[1]
Eq(table.concat(short.activities, ","), "quest,rare,trade,chat", "ranked activities (grouped implied)")
Eq(table.concat(short.headline, ","), "quest", "a short session names one activity")
Eq(#short.lines, 2, "moments shown under a folded session")
Eq(short.lines[1].kind, "rare", "the rare is a moment")
Eq(short.lines[2].row.context.given[1].link, SWORD_LINK, "the green trade is a moment")
Eq(short.hidden, 2, "the white trade and the whisper fold away")
_, text, sub = ns.UI.DescribeItem(short, PAL)
Eq(text, "Quested together for 20 min in Duskwood", "short session headline")
Eq(sub, "1 quest  ·  1 message  ·  1 trade", "short session details count only the chatter")
_, text, _, icon = ns.UI.DescribeItem(short.lines[1], PAL)
Eq(text, "Killed Mor'Ladim", "rare moment line")
Eq(icon, "rare", "rare moment icon")

-- Three hours names three activities; what they name is summed up on the
-- details line, not repeated as lines (TLN-6).
Eq(#long.lines, 0, "named moments repeated as lines")
_, text, sub = ns.UI.DescribeItem(long, PAL)
Eq(text, "Quested together for 3 h 5 min through Westfall and Duskwood, killed Mor'Ladim, and traded",
    "long session headline")
Eq(sub, "18 quests  ·  killed Mor'Ladim  ·  gave " .. SWORD_LINK
    .. "  ·  they went from 21 to 24  ·  2 deaths  ·  5 messages", "long session details")

-- Facts past the budget go to the tooltip only.
Fresh(t0, {
    Session(SHORT, t0 + 1000, 10 * 60, { quests = { 1 }, levelStart = 5, levelEnd = 6 },
        { deaths = { [SELF.guid] = 1 } }),
})
Row("whisper_in", t0 + 1100, { excerpt = "x" }, SHORT)
_, _, sub, _, story = ns.UI.DescribeItem(ns.Timeline.For(PAL)[1], PAL)
Eq(sub, "1 quest  ·  they went from 5 to 6  ·  1 death", "details not cut to the budget")
Check(story:find("1 death  ·  1 message"), "the tooltip lost the cut fact: " .. story)

-- The page: folded by default, a click opens it, another folds it.
Fresh(t0, {
    { id = 201, me = SELF.guid, source = "group", startedAt = t0 + 1000, endedAt = t0 + 4000,
        participants = { [PAL] = { since = t0 + 1000, last = t0 + 4000, seconds = 3000 } },
        others = 0, zones = { "Mulgore" }, deaths = {} },
})
for i = 1, 4 do Row("whisper_in", t0 + 1000 + i * 30, { excerpt = "w" .. i }, 201) end
for i = 1, 3 do Row("duel", t0 + 600 + i) end
Eq(Kinds(ns.Timeline.For(PAL)), "session,exchange,added", "page scenario")

ns.UI.ShowJournal(PAL)
local TL = _G.SocialDiaryJournalFrame.profile.timeline
local folded = #TL.data
local function SessionRow()
    for i = 1, #TL.rows do
        local row = TL.rows[i]
        if row:IsShown() and row.item and row.item.item and row.item.item.kind == "session" then return row end
    end
end
local srow = SessionRow()
Check(srow, "no session row on screen")
srow.scripts.OnEnter(srow)
Check(GameTooltip.text and GameTooltip.text:find("Click to show all 4"), "session tooltip: " .. tostring(GameTooltip.text))
-- Folded, it hangs off a dashed bracket that ends at its details, now last,
-- with the same short line under it as when open.
local foldedHead, foldedOn = nil, {}
for i = 1, #TL.data do
    local line = TL.data[i]
    if line.item and line.item.kind == "session" and line.when then foldedHead = i end
    if line.bracket and (line.fold or line.item).kind == "session" then foldedOn[#foldedOn + 1] = line end
end
Check(foldedHead and not TL.data[foldedHead].bracket, "the folded session's own line is on its bracket")
Eq(#foldedOn, 1, "the folded bracket does not hang off the details alone")
Eq(foldedOn[1], TL.data[foldedHead + 1], "the folded details are not right under the session")
Eq(foldedOn[1].font, ns.Style.FONT.small, "the folded bracket does not end at the details")
Eq(foldedOn[1].bracket.dashed, true, "the folded bracket is not dashed")
Eq(foldedOn[1].bracket.last, true, "the folded bracket has no foot")
Check(TL.data[foldedHead + 2].height and not TL.data[foldedHead + 2].text, "no gap under the folded bracket")
srow.scripts.OnMouseUp(srow)
-- Its rows, and still the short line under them so the next entry stands clear.
Eq(#TL.data, folded + 4, "opening a session did not add its rows")
local deepest = 0
for i = 1, #TL.data do deepest = math.max(deepest, TL.data[i].depth or 0) end
Eq(deepest, 1, "opened rows not one level in")
-- They keep the normal line layout, hung off an ink bracket that ends at
-- the session's details, last as when folded: the session's own line stays
-- as it is.
local onBracket, head, gapLine = {}, nil, nil
for i = 1, #TL.data do
    local line = TL.data[i]
    if line.bracket and (line.fold or line.item).kind == "session" then onBracket[#onBracket + 1] = line end
    if line.item and line.item.kind == "session" and line.when and not head then head = line end
    if line.fold and line.fold.kind == "session" and not line.text then gapLine = line end
end
Check(head and not head.bracket, "the session's own line is on its bracket")
Eq(#onBracket, 4 + 1, "the bracket does not run through the rows to the details")
Eq(onBracket[1].item.kind, "row", "the bracket does not start at the session's rows")
local details = onBracket[#onBracket]
Eq(details.item.kind, "session", "the bracket does not end at the session's details")
Eq(details.font, ns.Style.FONT.small, "the open bracket's last line is not the details")
for i = 1, #onBracket do
    Eq(onBracket[i].height, nil, "lines on the bracket changed height")
    Eq(onBracket[i].bracket.depth, 0, "the bracket is not at the session's own depth")
    Eq(onBracket[i].bracket.dashed, nil, "the open bracket is dashed")
    Eq(onBracket[i].bracket.last, i == #onBracket or nil, "only the last line has the bracket's foot")
end
Check(gapLine and gapLine.height and gapLine.height < 20, "the gap under the bracket takes a whole row")
-- A row's time shows only where the minute changes from the line above.
local shown = head.when
for i = 1, #onBracket - 1 do
    local line = onBracket[i]
    Check(line.icon ~= nil, "rows on the bracket lost their icon")
    local when = ns.UI.DescribeItem(line.item, PAL)
    Eq(line.when, when ~= shown and when or nil, "a row's time is not blank exactly where it repeats")
    shown = when
end
-- A click anywhere on the bracket folds it.
local bracketRow
for i = 1, #TL.rows do
    local line = TL.rows[i]:IsShown() and TL.rows[i].item
    if line and line.bracket and line.fold then bracketRow = TL.rows[i] end
end
Check(bracketRow, "no bracket row on screen")
bracketRow.scripts.OnEnter(bracketRow)
bracketRow.scripts.OnLeave(bracketRow)
bracketRow.scripts.OnMouseUp(bracketRow)
Eq(#TL.data, folded, "a click on the bracket did not fold the session")
SessionRow().scripts.OnMouseUp(SessionRow())
SessionRow().scripts.OnMouseUp(SessionRow())
Eq(#TL.data, folded, "a second click did not fold the session")
-- Nothing folded away, nothing to open.
local addedRow
for i = 1, #TL.rows do
    local line = TL.rows[i]:IsShown() and TL.rows[i].item
    if line and line.item and line.item.kind == "added" then addedRow = TL.rows[i] end
end
addedRow.scripts.OnMouseUp(addedRow)
Eq(#TL.data, folded, "a click on a plain line changed the page")
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("instance visits on the timeline (TLN-4) and /sd testdata")

Reset()
mock.now = 1795000000
SlashCmdList.SOCIALDIARY("testdata")
local G = ns.TestData.GUID
Check(ns.Diary.Get(G), "no test entry")
Check(_G.SocialDiaryJournalFrame:IsShown(), "the journal did not open on the test entry")

local tl = ns.Timeline.For(G)
local kinds = {}
for i = 1, #tl do kinds[i] = tl[i].kind end
Eq(table.concat(kinds, ","), "row,around,note,session,visit,session,session,added,exchange", "test timeline")
Eq(tl[3].note.text, "Promised to help with Sludge Fen tomorrow.", "the test data's loose note")
Eq(tl[7].notes and tl[7].notes[1].text, "Tester knows every Kolkar camp by heart.",
    "the test data's note in the first session")

-- A session that was only the dungeon run gives way to the visit, rows
-- and all.
local rfk = tl[5]
Eq(rfk.visit.name, "Razorfen Kraul", "the dungeon-only session did not give way")
Eq(rfk.hidden, 3, "the session's chat did not go with the visit")
local _, text, sub = ns.UI.DescribeItem(rfk, G)
Eq(text, "Razorfen Kraul, 35 min, 4 of 6 bosses", "visit headline")
Check(sub:find("^4 deaths  ·  1 wipe  ·  with Brom, Kaelith and Zuri"), "visit details: " .. sub)

-- Inside a session, the visit is always shown and only counted on the
-- session's details.
local long = tl[6]
local wc
for _, line in ipairs(long.lines) do
    if line.kind == "visit" then wc = line end
end
Check(wc, "the dungeon is not shown inside its session")
Eq(wc.notes and wc.notes[1].text, "Skum took three tries. Tester never gave up.",
    "the test data's note in the dungeon")
Eq(long.notes, nil, "the dungeon's note is also the session's")
Eq(wc.depth, 1, "the dungeon is not one level in")

-- Level-ups and deaths are moments: always lines, in time order around the
-- dungeon, and the level-up that happened in the dungeon is the dungeon's.
local order = {}
for _, line in ipairs(long.lines) do
    order[#order + 1] = line.kind == "visit" and "visit" or (line.row and line.row.type) or line.kind
end
Eq(table.concat(order, ","), "death,level_up,visit,level_up,death",
    "the 3-hour session's lines (the rare is named, so summed)")
local inWC
for _, child in ipairs(wc.all) do
    if child.row and child.row.type == "level_up" then inWC = child.row.context.level end
end
Eq(inWC, 20, "the level-up during the dungeon is not the dungeon's")
_, text, sub = ns.UI.DescribeItem(long, G)
Check(text:find("^Quested together for 3 h 5 min"), "long session: " .. text)
Check(sub:find("1 dungeon"), "the session does not count its dungeon: " .. sub)
-- Three deaths, two of them with lines: only the third is counted.
Check(sub:find("1 death"), "the death without a line is not counted: " .. sub)
-- Tester's death in Wailing Caverns is the run's (TLN-11): no line beside
-- the card (the order above), and not counted on the session.
Check(not sub:find("2 deaths"), "a death in the dungeon is counted on its session: " .. sub)
Eq(select(2, ns.UI.DescribeItem(long.lines[1], G)),
    "You died to Razormane Geomancer's Fireball (3 attackers) near Razormane Grounds", "a recap death's line")
Eq(select(2, ns.UI.DescribeItem(long.lines[5], G)),
    "Tester died, probably to Venture Co. Logger near Stonetalon Mountains", "a guessed death's line")

-- On the page, a visit stands apart.
local lines = _G.SocialDiaryJournalFrame.profile.timeline.data
for i = 1, #lines do
    local line = lines[i]
    if line.item and line.item.kind == "visit" and line.when then
        Check(lines[i - 1].height or lines[i - 1].header, "no space above a visit")
    end
end

-- A visit is one tall entry beside its medallion: red name, duration
-- aside, a mark per boss, the others in the party, deaths and wipes.
local entry
for i = 1, #lines do
    if lines[i].visit and lines[i].item.visit.name == "Razorfen Kraul" then entry = lines[i] end
end
Check(entry, "Razorfen Kraul is not a visit entry on the page")
Eq(entry.text, "RAZORFEN KRAUL", "the visit name is not in capitals")
Eq(entry.font, ns.Style.FONT.rubric, "the visit name is not in red")
Check(entry.height and entry.height > 20, "the visit entry is not taller than a line")
Eq(entry.visit.aside, "35 min", "the visit's duration")
Eq(entry.visit.losses, "4 deaths  ·  1 wipe", "the visit's deaths and wipes")
Eq(#entry.visit.members, 3, "the party, less the user and the page's person")
for i = 1, #lines do
    Check(not (lines[i].item == entry.item and lines[i] ~= entry and lines[i].text),
        "the visit still has a details line")
end
local drawn
for _, row in ipairs(_G.SocialDiaryJournalFrame.profile.timeline.rows) do
    if row:IsShown() and row.item and row.item.visit then drawn = row end
end
Check(drawn and drawn.visit and drawn.visit:IsShown(), "no visit drawn on the page")

-- The group finder's picture, by instance id, else by name; a drop cap
-- where the client has neither.
Eq(ns.Style.InstanceArt({ instanceID = 47, name = "Razorfen Kraul" }),
    "Interface\\LFGFrame\\LFGIcon-RazorfenKraul", "art by instance id")
Eq(ns.Style.InstanceArt({ name = "The Deadmines" }), "Interface\\LFGFrame\\LFGIcon-Deadmines", "art by name")
mock.missingFiles["Interface\\LFGFrame\\LFGIcon-TestVault"] = true
Eq(ns.Style.InstanceArt({ instanceID = 99999, name = "The Test Vault" }), nil, "art for a missing file")
local medallion = ns.Style.Medallion(UIParent, 36)
medallion:SetVisit({ instanceID = 99999, name = "The Test Vault" })
Eq(medallion.initial:GetText(), "T", "the drop cap is not the name's initial")
Check(medallion.initial:IsShown(), "no drop cap without the picture")
medallion:SetVisit({ instanceID = 47, name = "Razorfen Kraul" })
Check(not medallion.initial:IsShown(), "a drop cap over the picture")
local pips = ns.Style.Pips(UIParent, 12)
Check(pips:Set(4, 6) > pips:Set(4, 4), "boss marks do not count the bosses left standing")

-- Writing again replaces; remove takes everything.
local sessions = 0
for _ in pairs(ns.db.sessions) do sessions = sessions + 1 end
SlashCmdList.SOCIALDIARY("testdata")
local again = 0
for _ in pairs(ns.db.sessions) do again = again + 1 end
Eq(again, sessions, "writing twice doubled the sessions")
SlashCmdList.SOCIALDIARY("testdata remove")
Eq(ns.db.characters[G], nil, "test character left behind")
Eq(ns.db.interactions[G], nil, "test rows left behind")
Eq(next(ns.db.instances), nil, "test visits left behind")
Eq(next(ns.db.sessions), nil, "test sessions left behind")
Eq(ns.db.around[G], nil, "test stretch left behind")
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("level-ups (a timeline moment)")

-- Captured where every reading lands: a diary entry seen higher than last
-- time. Only live readings, only rises, only diary entries.
Fresh(t0)
local function LevelRows()
    local list = {}
    for _, row in ipairs(ns.Interactions.For(PAL) or {}) do
        if row.type == "level_up" then list[#list + 1] = row.context.from .. ">" .. row.context.level end
    end
    return table.concat(list, ",")
end
ns.Characters.Observe(PAL, { level = 7 })
Eq(LevelRows(), "6>7", "a level-up was not recorded")
ns.Characters.Observe(PAL, { level = 7 })
Eq(LevelRows(), "6>7", "the same level recorded again")
ns.Characters.Observe(PAL, { level = 9, time = t0 - 60 })
Eq(LevelRows(), "6>7", "a backfilled reading recorded a level-up")
ns.Characters.Observe(PAL, { level = 5 })
ns.Characters.Observe(PAL, { level = 10 })
Eq(LevelRows(), "6>7,5>10", "a fall was recorded, or a jump missed")
ns.Characters.Observe(PAL, { first = "Kaelith" })
Eq(LevelRows(), "6>7,5>10", "a reading without a level recorded one")

-- Strangers too: the row waits in the buffer, so it is on their profile
-- when they are added (flow 2). It is something seen, not done together:
-- it puts nobody in the picker and is not an interaction on record.
local STRANGER = "Player-4620-00CCCCCC"
ns.Characters.Observe(STRANGER, { first = "Nobody", level = 3 })
ns.Characters.Observe(STRANGER, { level = 4 })
local strangerRows = ns.Interactions.For(STRANGER)
Eq(strangerRows and #strangerRows, 1, "a stranger's level-up was not stored")
Eq(strangerRows[1].type, "level_up", "the stranger's row")
Eq(ns.Interactions.Count(STRANGER), 0, "a level-up counted as an interaction")
for _, recent in ipairs(ns.Interactions.Since(t0 - 60)) do
    Check(recent.guid ~= STRANGER, "a level-up made a stranger someone just dealt with")
end
ns.Interactions.Add(STRANGER, "whisper_in", { excerpt = "hi" })
ns.Characters.Observe(STRANGER, { level = 5 })
local dealt
for _, recent in ipairs(ns.Interactions.Since(t0 - 60)) do
    if recent.guid == STRANGER then dealt = recent.type end
end
Eq(dealt, "whisper_in", "a later level-up hid the whisper from the picker")
Eq(ns.Interactions.Count(STRANGER), 1, "interactions on record")

ns.Diary.Add(STRANGER, { source = "test" })
local strangerLines = {}
for _, item in ipairs(ns.Timeline.For(STRANGER)) do
    for _, shown in ipairs(item.lines or { item }) do
        if shown.row then strangerLines[#strangerLines + 1] = (select(2, ns.UI.DescribeItem(shown, STRANGER))) end
    end
end
Check(table.concat(strangerLines, "|"):find("Nobody is now level 4", 1, true),
    "a level-up from before the add is not on the profile: " .. table.concat(strangerLines, "|"))

-- The user's own characters are not strangers.
ns.OwnCharacters()[SELF.guid] = ns.OwnCharacters()[SELF.guid] or {}
ns.Characters.Observe(SELF.guid, { level = 60 })
ns.Characters.Observe(SELF.guid, { level = 61 })
Eq(ns.Interactions.For(SELF.guid), nil, "a level-up stored for the user")

-- The row is Features/LevelUps/'s: the character store only tells the rise
-- (SD_LEVEL_ROSE, Core/Events.lua), for anyone, on a live reading, and the
-- feature decides who gets a row. The kind climbs (Core/Rows.lua).
do
    local heard = {}
    local function Rose(_, guid, from, level) heard[#heard + 1] = guid .. ":" .. from .. ">" .. level end
    ns.On("SD_LEVEL_ROSE", Rose)
    ns.Characters.Observe(SELF.guid, { level = 62 })
    ns.Characters.Observe(STRANGER, { level = 8, time = t0 - 30 })
    ns.Characters.Observe(STRANGER, { level = 9 })
    ns.Characters.Observe(STRANGER, { level = 9 })
    ns.Off("SD_LEVEL_ROSE", Rose)
    Eq(table.concat(heard, ","), SELF.guid .. ":61>62," .. STRANGER .. ":8>9",
        "the store told the wrong rises")
    Eq(ns.Interactions.For(SELF.guid), nil, "a rise the user's told stored a row")
    Check(ns.LevelUps ~= nil, "the feature's namespace is missing")
    Eq(ns.Rows.Get("level_up").climb, true, "a level-up does not climb")
end

-- Worded with the page's person, iconed, and a line even in a folded
-- session, where it names nothing in the headline.
local tl2 = ns.Timeline.For(PAL)
local up = tl2[#tl2 - 1]
Eq(up.row and up.row.type, "level_up", "a lone level-up is not its own line")
local _, upText, _, upIcon = ns.UI.DescribeItem(up, PAL)
Eq(upText, "Kaelith is now level 10", "level-up line")
Eq(upIcon, "levelup", "level-up icon")

Fresh(t0, { Session(401, t0 + 1000, 20 * 60, { quests = { 1 }, levelStart = 6, levelEnd = 7 }) })
Row("level_up", t0 + 1300, { context = { from = 6, level = 7 } }, 401)
Row("whisper_in", t0 + 1400, { excerpt = "grats" }, 401)
local s401 = ns.Timeline.For(PAL)[1]
Eq(#s401.lines, 1, "the level-up is not a line under its session")
Eq(s401.lines[1].row.type, "level_up", "the line under the session")
Eq(table.concat(s401.activities, ","), "quest,chat", "a level-up added an activity")
local _, _, s401sub = ns.UI.DescribeItem(s401, PAL)
Eq(s401sub, "1 quest  ·  they went from 6 to 7  ·  1 message", "a level-up counted on the details line")

-- Level-ups seen in passing are single lines, not an exchange: only
-- things done together count towards one.
Fresh(t0)
for i = 1, 3 do Row("level_up", t0 + 100 + i * 60, { context = { from = 6 + i, level = 7 + i } }) end
Eq(Kinds(ns.Timeline.For(PAL)), "row,row,row,added", "level-ups alone made an exchange")
Row("whisper_in", t0 + 400, { excerpt = "ding" })
Row("whisper_out", t0 + 410, { excerpt = "grats" })
Eq(Kinds(ns.Timeline.For(PAL)), "row,row,row,row,row,added", "two whispers and level-ups made an exchange")
Row("whisper_in", t0 + 420, { excerpt = "ty" })
local withChat = ns.Timeline.For(PAL)
Eq(Kinds(withChat), "exchange,added", "three whispers did not make an exchange")
-- Folded, the three level-ups one after another are one line, a climb.
Eq(#withChat[1].lines, 1, "the level-ups in a row are not one line of the exchange")
Eq(withChat[1].lines[1].kind, "climb", "the level-ups in a row are not a climb")

-- In a session (10 Oct, in the client: five lines of "is now level" under
-- a low-level run): one line folded, "went from level 1 to 6", every level
-- in its tooltip; each its own line again opened. A death between two
-- level-ups keeps them apart, in the order they happened.
Fresh(t0, { Session(402, t0 + 1000, 90 * 60, { quests = { 1 }, levelStart = 1, levelEnd = 6 }) })
for i = 1, 5 do Row("level_up", t0 + 1000 + i * 600, { context = { from = i, level = i + 1 } }, 402) end
local s402 = ns.Timeline.For(PAL)[1]
Eq(#s402.lines, 1, "five level-ups in a row are not one folded line")
local climb = s402.lines[1]
Eq(climb.kind, "climb", "the folded line is not a climb")
Eq(climb.time, t0 + 1600, "the climb is not at its first level-up")
Eq(#s402.all, 5, "opened, the level-ups are not each a line")
Check(s402.hidden > 0, "the climb leaves the session nothing to open")
local climbWhen, climbText, _, climbIcon, climbFull = ns.UI.DescribeItem(climb, PAL)
Eq(climbText, "Trade went from level 1 to 6", "the climb's line")
Eq(climbIcon, "levelup", "the climb's icon")
Eq(climbWhen, date("%H:%M", t0 + 1600), "the climb's time")
local levelsInTip = select(2, climbFull:gsub("  level %d", ""))
Eq(levelsInTip, 5, "the climb's tooltip does not name every level: " .. climbFull)

ns.db.sessions[402].deathLog = { { time = t0 + 2500, guid = PAL } }
s402 = ns.Timeline.For(PAL)[1]
local kinds402 = {}
for _, line in ipairs(s402.lines) do kinds402[#kinds402 + 1] = line.kind == "row" and line.row.type or line.kind end
Eq(table.concat(kinds402, ","), "climb,death,climb", "a death between level-ups did not keep them apart")

-- On the page: the climb is one line under the folded session.
ns.db.sessions[402].deathLog = nil
ns.UI.ShowJournal(PAL)
local climbLines, upLines = 0, 0
for _, line in ipairs(_G.SocialDiaryJournalFrame.profile.timeline.data) do
    if line.text == "Trade went from level 1 to 6" then climbLines = climbLines + 1 end
    if line.text and line.text:find("is now level") then upLines = upLines + 1 end
end
Eq(climbLines, 1, "the folded session does not show its climb")
Eq(upLines, 0, "the folded session still lists each level-up")
ns.UI.CloseJournal()

-- Deaths one after another at the same place name it once, then "there";
-- the tooltip still names it (10 Oct, in the client: "near Fargodeep Mine"
-- three times running).
Fresh(t0, { Session(403, t0 + 1000, 60 * 60, { quests = { 1 } }, { deathLog = {
    { time = t0 + 1100, guid = PAL, subZone = "Fargodeep Mine", killer = { name = "Kobold Tunneler", source = "recap" } },
    { time = t0 + 1110, guid = SELF.guid, subZone = "Fargodeep Mine",
        killer = { name = "Kobold Tunneler", source = "recap", attackers = 6 } },
    { time = t0 + 1400, guid = PAL, subZone = "Jasperlode Mine", killer = { name = "Rumbler", source = "recap" } },
} }) })
ns.UI.ShowJournal(PAL)
local deathLines = {}
for _, line in ipairs(_G.SocialDiaryJournalFrame.profile.timeline.data) do
    if line.item and line.item.kind == "death" and line.text then deathLines[#deathLines + 1] = line end
end
Eq(#deathLines, 3, "the deaths are not lines")
Eq(deathLines[1].text, "Trade died to Kobold Tunneler near Fargodeep Mine", "the first death at a place names it")
Eq(deathLines[2].text, "You died to Kobold Tunneler (6 attackers) there", "a death at the same place names it again")
Check(deathLines[2].full:find("near Fargodeep Mine", 1, true), "said \"there\", the tooltip lost the place")
Eq(deathLines[3].text, "Trade died to Rumbler near Jasperlode Mine", "a death at another place is \"there\"")
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("notes on the timeline (TLN-10)")

-- A note with no run going on is a line of its own, at its own time, and
-- does not split the exchange it comes after.
Fresh(t0)
ns.db.instances = {}
for i = 1, 3 do Row("whisper_in", t0 + 100 + i * 60, { excerpt = "w" .. i }) end
local alone = ns.Notes.Add(PAL, "Good company.", { time = t0 + 100 + 3 * 60 + gap + 1 })
local before = ns.Notes.Add(PAL, "Waiting at the well.", { time = t0 + 50 })
tl = ns.Timeline.For(PAL)
Eq(Kinds(tl), "note,exchange,note,added", "loose notes on the top level")
Eq(tl[1].note, alone, "the note after the exchange")
Eq(tl[3].note, before, "the note before the exchange")
Eq(tl[2].notes, nil, "a note outside the exchange went into it")
Eq(#tl[2].all, 3, "a note became one of the exchange's rows")
local _, noteText, _, noteIcon, noteStory = ns.UI.DescribeItem(tl[1], PAL)
Eq(noteText, "Good company.", "a note's line")
Eq(noteIcon, "note", "a note's icon")
Check(noteStory:find("^Good company%.\nWritten at "), "a note's tooltip: " .. noteStory)

-- Written while an exchange is going on, up to its gap after the last row:
-- part of the exchange's own description, not among what it hides.
local during = ns.Notes.Add(PAL, "They're funny.", { time = t0 + 100 + 2 * 60 + 5 })
local after = ns.Notes.Add(PAL, "Still chatting.", { time = t0 + 100 + 3 * 60 + gap })
tl = ns.Timeline.For(PAL)
Eq(Kinds(tl), "note,exchange,note,added", "a note inside an exchange made a line of its own")
ex = tl[2]
Eq(#ex.notes, 2, "the exchange's notes")
Eq(ex.notes[1], during, "the exchange's notes are not oldest first")
Eq(ex.notes[2], after, "a note within the gap after the last row is not the exchange's")
Eq(ex.hidden, 3, "the notes count among what the exchange hides")

-- On the page: folded, right under the exchange's own line, its details
-- last; a click on one opens it for writing rather than the exchange.
local J = ns.UI.Journal
local function NoteLines(lines)
    local found = {}
    for _, line in ipairs(lines) do
        if line.note then found[#found + 1] = line end
    end
    return found
end
local lines = J.TimelineLines(tl, PAL)
local noted = NoteLines(lines)
Eq(#noted, 4, "notes on the page")
Eq(noted[2].note, during, "the exchange's first note on the page")
Eq(noted[2].item, ex, "the exchange's note is not one of its lines")
Eq(noted[2].font, ns.Style.FONT.noteWritten, "a note is not in the note's hand")
Eq(noted[2].icon, "note", "a note in a run has no icon")
local headAt, subAt
for i, line in ipairs(lines) do
    if line.item == ex and line.when and not headAt then headAt = i end
    if line.item == ex and line.text and line.font == ns.Style.FONT.small then subAt = i end
end
Eq(lines[headAt + 1].note, during, "the note is not right under the folded exchange")
Eq(noted[2].bracket and noted[2].bracket.dashed, true, "the note is not on the folded bracket")
Check(lines[subAt].bracket and lines[subAt].bracket.last, "the folded details do not end the bracket")

-- A session's note, and a visit's inside it: the innermost run wins.
local S = 501
Fresh(t0, { Session(S, t0 + 1000, 3 * 3600, { quests = { 1 } }) })
ns.db.instances = { [1] = { id = 1, name = "Wailing Caverns", startedAt = t0 + 3000, endedAt = t0 + 5000,
    sessionIds = { S }, members = { { guid = PAL, first = "Trade" } } } }
local inSession = ns.Notes.Add(PAL, "Off to the Barrens.", { time = t0 + 2000 })
local inVisit = ns.Notes.Add(PAL, "Mutanus, at last.", { time = t0 + 4000 })
tl = ns.Timeline.For(PAL)
Eq(Kinds(tl), "session,added", "notes in a session made lines of their own")
local session = tl[1]
Eq(#session.notes, 1, "the session's notes")
Eq(session.notes[1], inSession, "the session's note")
local visit
for _, child in ipairs(session.all) do
    if child.kind == "visit" then visit = child end
end
Eq(visit.notes and visit.notes[1], inVisit, "the note during the dungeon is not the dungeon's")

-- A session that was only the visit: the visit has the session's time, and
-- its notes.
Fresh(t0, { Session(S, t0 + 1000, 1800, {}) })
ns.db.instances = { [1] = { id = 1, name = "Wailing Caverns", startedAt = t0 + 1200, endedAt = t0 + 2700,
    sessionIds = { S }, members = { { guid = PAL, first = "Trade" } } } }
local early = ns.Notes.Add(PAL, "Waiting for the tank.", { time = t0 + 1100 })
tl = ns.Timeline.For(PAL)
Eq(Kinds(tl), "visit,added", "the session did not give way to the visit")
Eq(tl[1].notes and tl[1].notes[1], early, "a note in the session's time is not the visit's")
-- On the page its note starts as far under the plate as the plate starts
-- under the line above it.
local vlines = J.TimelineLines(tl, PAL)
local plateAt
for i, line in ipairs(vlines) do
    if line.visit then plateAt = i end
end
Check(vlines[plateAt - 1].height and not vlines[plateAt - 1].text, "no gap above the plate")
Check(vlines[plateAt + 1].height and not vlines[plateAt + 1].text, "no gap under the plate before its note")
Eq(vlines[plateAt + 1].height, vlines[plateAt - 1].height, "the gaps over and under the plate differ")
Eq(vlines[plateAt + 2].note, early, "the visit's note is not under the gap")
-- Two levels in: the visit's bracket runs down its medallion, a level
-- further in than an icon's, and must clear the icons under it.
Eq(vlines[plateAt + 2].depth, 2, "what hangs under a visit is not clear of its medallion")
-- A visit no longer folds open (TLN-12: its card opens the dungeon page,
-- tests/dungeon_ui.lua), so nothing under it hangs on a bracket.
Eq(vlines[plateAt + 2].bracket, nil, "a visit's note hangs on a fold's bracket")
Check(vlines[plateAt].full:find("\nClick to open its page%.$"), "a visit's tooltip does not say what a click does: "
    .. vlines[plateAt].full)
ns.db.instances = {}

-- A note about two people is on both their timelines, and says who else.
Fresh(t0)
mock.SetUnit("target", F.GARRICK)
ns.Diary.Add(F.GARRICK.guid, { unit = "target" })
local both = ns.Notes.Add({ PAL, F.GARRICK.guid }, "Deadmines run.", { time = t0 + 50 })
Eq(ns.Timeline.For(F.GARRICK.guid)[1].note, both, "the group note is missing from Garrick's timeline")
_, _, _, _, noteStory = ns.UI.DescribeItem(ns.Timeline.For(PAL)[1], PAL)
Check(noteStory:find("\nAlso about Garrick Fallow%.\n"), "the tooltip does not say who else: " .. noteStory)

-- Whom a note could also be about: the others in a session going on then.
Fresh(t0, { Session(S, t0 + 1000, 1800, {}) })
mock.SetUnit("target", F.GARRICK)
ns.Diary.Add(F.GARRICK.guid, { unit = "target" })
ns.db.sessions[S].participants[F.GARRICK.guid] = { since = t0 + 1000, last = t0 + 2800, seconds = 1800 }
ns.db.sessions[S].participants[F.PUG.guid] = { since = t0 + 1000, last = t0 + 2800, seconds = 1800 }
Eq(table.concat(ns.Notes.Companions(PAL, t0 + 1500), ","), F.GARRICK.guid,
    "the companions in the session (diary entries only)")
Eq(#ns.Notes.Companions(PAL, t0 + 5000), 0, "companions from a session that was over")

Section("long lines wrap")

-- The mock has no font metrics; a stand-in measures 7 a character and 14 a
-- line, 3 between lines, wrapping at the width it is given (0: no limit).
local J = ns.UI.Journal
local FONT = ns.Style.FONT
local measure = {}
function measure:SetFontObject() end
function measure:SetWidth(width) self.width = width end
function measure:SetMaxLines(n) self.maxLines = n end
function measure:SetText(text) self.text = text end
function measure:GetStringWidth() return #self.text * 7 end
function measure:GetStringHeight()
    local perLine = self.width > 0 and math.floor(self.width / 7) or math.huge
    local n = math.min(self.maxLines, math.max(1, math.ceil(#self.text / perLine)))
    return n * 14 + (n - 1) * 3
end
local list = { measure = measure, GetWidth = function() return 400 end }

local long, short, endless = ("word "):rep(40), "Tester is now level 20", ("x"):rep(2000)
local wrap = J.FitTimelineLines({
    { header = "Today" },
    { text = long, font = FONT.body, depth = 1 },
    { text = short, font = FONT.body },
    { text = endless, font = FONT.noteWritten },
    { height = 6 },
    { text = ("X"):rep(80), font = FONT.rubric, height = 58,
        visit = { aside = "35 min", losses = "" } },
}, list)
Eq(wrap[1].height, nil, "a day heading changed height")
-- 386 wide rows; at depth 1 the text has 386 - 2 - 78 = 306, 43 a line:
-- 200 characters take 4 lines, 65 high, 51 more than one, so 52 in steps of 4.
Eq(wrap[2].height, 20 + 52, "a long line's height")
Eq(wrap[2].top, 3, "where a wrapped line's text starts")
Eq(wrap[3].height, nil, "a short line changed height")
Eq(wrap[3].top, nil, "a short line moved its text")
Eq(wrap[4].height, 20 + 52, "a long note is not held to four lines")
Eq(wrap[5].height, 6, "a gap changed height")
-- The name has 386 - 2 - 2 - 8 - 42 - 12 - 96 = 224, 32 a line: two lines,
-- 31 high, 17 more than one, so 20; the plate grows by that.
Eq(wrap[6].visit.extra, 20, "a long dungeon name did not grow its plate")
Eq(wrap[6].height, 58 + 20, "the plate's height")
Eq(wrap[6].visit.nameTop, 8 + (22 - 14) / 2, "where a wrapped name starts")
