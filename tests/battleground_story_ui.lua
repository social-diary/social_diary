-- A Warsong told by time on Your Diary's right page
-- (.claude/ui-proposal/battleground-page-v2.md, round 8, S1;
-- Core/MatchStoryPage.lua's plan, UI/Journey/MatchStory.lua's drawing):
-- /sd testdata's two told Warsongs (the first: 17 minutes, 3-1, a zerg;
-- the third: 11 minutes, 3-1, a nemesis, the evening, revenge) open on
-- their story; the second (untold) keeps the board. The plan's lines,
-- branches, stains, names and band; the page's parts on the page and
-- clear of each other; the stub opening the board view and the way back;
-- a diary person's strip; "Flat paper only"; then the pad: everything
-- reached, A on the stub and on a line, B back one level each time, a
-- diary person's strip opening their page, the mouse taking over, the
-- Gamepad UI off. Invented names only.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local SP = ns.MatchStoryPage
local STORY = SP.STORY
local Matches, Story = ns.Matches, ns.MatchStory
local W, H = 466, 534

local function Meet(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
local function OnPage(corners, what)
    for _, c in ipairs(corners) do
        Check(c[1] >= 0 and c[1] <= W and c[2] >= 0 and c[2] <= H,
            ("%s off the page at %.1f, %.1f"):format(what, c[1], c[2]))
    end
end

SlashCmdList.SOCIALDIARY("testdata")
local evening
for _, s in ipairs(Matches.Sessions(ns.ownGUID)) do
    if Matches.HasOverview(s) then evening = s end
end
Check(evening and #evening.matches == 4, "setup: the evening of four")
local told, untold = { evening.matches[1], evening.matches[3] }, evening.matches[2]
Check(Story.Has(told[1]) and Story.Has(told[2]), "setup: the first and third Warsongs told")
Check(not Story.Has(untold), "setup: the second Warsong untold")
local own = ns.JoinName(ns.Characters.Name(ns.ownGUID))

--------------------------------------------------------------------------
Section("the plan: two lines at one scale, on the page")

for _, m in ipairs(told) do
    local story = Story.Build(m, { own = own, session = evening })
    local lines = SP.Lines(story)
    Eq(#lines, 2, "the match not in two lines")
    Eq(lines[1].pps, lines[2].pps, "the lines not at one scale")
    local longest = math.max(lines[1].to - lines[1].from, lines[2].to - lines[2].from)
    Check(math.abs(longest * lines[1].pps - STORY.lines.w) < 0.01, "the longer line does not fill the width")
    Check(lines[2].top >= lines[1].bottom, "the second line over the first's band")
    Check(lines[2].bottom <= STORY.foot.y, "the second band over your line at the foot")
    for _, ln in ipairs(lines) do
        Check(ln.X(ln.to) <= W - 10, "a line past the page's edge")
        local branches, by = SP.Branches(story, ln)
        for _, g in ipairs(branches) do
            Check(g.xb >= g.xa, "a branch ending before its fork")
            Eq(g.s, g.c.side == "us" and -1 or 1, "a branch on the wrong side of the line")
            if g.c.ends == "captured" and g.c.to <= ln.to then
                Check(g.cap ~= nil, "a captured carry has no circled score")
                Check(g.H(g.xb) > 1.4, "a captured branch does not rise into its score")
            end
            if g.c.ends == "returned" and g.c.to <= ln.to then
                Check(g.back ~= nil and g.back.x1 > g.back.x0, "a returned flag does not come back down forward")
                Eq(g.back.y1, ln.Y, "a returned flag does not come back onto the base line")
            end
            for _, d in ipairs(g.drops) do Eq(d.y, ln.Y + g.s * STORY.lines.lift, "a carrier's cross off its branch") end
        end
        -- The names never meet nor run off.
        local names = SP.Names(story, ln, function(key) return 8 * #(ns.UI.JourneyText.StoryPhase(key) or "The Zerg") end)
        for k, n in ipairs(names) do
            Check(n.x + n.w <= W, "a phase's name off the page")
            if k > 1 then Check(n.x >= names[k - 1].x + names[k - 1].w, "two names meet") end
        end
        -- The base line's gap at every capture inside the line.
        for _, cap in ipairs(story.caps) do
            if cap.t > ln.from and cap.t < ln.to then
                local x = ln.X(cap.t)
                for _, p in ipairs(SP.Base(story, ln)) do
                    Check(not (p.xa < x and p.xb > x), "the base line has no gap at a capture")
                end
            end
        end
    end
end

--------------------------------------------------------------------------
Section("the plan: the first Warsong's branches, the zerg's one stain")

do
    local story = Story.Build(told[1], { own = own, session = evening })
    local lines = SP.Lines(story)
    local branches = SP.Branches(story, lines[1])
    -- Carry 3: you dropped it, Tester picked it up again and took it home.
    local relay
    for _, g in ipairs(branches) do if g.c.n == 3 then relay = g end end
    Check(relay, "setup: the relayed carry")
    Eq(#relay.holds, 2, "the relay not two holds")
    Eq(#relay.lying, 1, "the flag lying between them not dotted")
    Eq(#relay.drops, 1, "the carrier's cross not at the drop")
    Check(relay.cap and not relay.back, "picked up again, it does not go on home")
    Check(relay.holds[2].xa >= relay.lying[1].xb, "the branch does not go on after the dots")
    local _, by = SP.Branches(story, lines[1])
    local stains = SP.Stains(story, lines[1], by)
    local zergs = 0
    for _, g in ipairs(stains) do
        if g.zerg then
            zergs = zergs + 1
            Eq(#g.fights, story.zerg.fights, "the zerg's fights not one stain")
            for k = 2, #g.pieces do
                local a, b = g.pieces[k - 1], g.pieces[k]
                Check(a.x + a.a1 >= b.x - b.a1, "the zerg's stain broken between its pieces")
            end
            for _, p in ipairs(g.pieces) do Eq(p.y, lines[1].Y, "the zerg's stain off the base line") end
        else
            Check(g.carry ~= nil, "setup: the other stain is a carry's")
        end
    end
    Eq(zergs, 1, "the zerg not one stain")
    -- Theirs returned on the second line: under it, back down onto it.
    local back
    for _, g in ipairs(SP.Branches(story, lines[2])) do if g.c.ends == "returned" then back = g end end
    Check(back and back.s == 1 and back.back, "their carry returned not under the line and back down")
end

--------------------------------------------------------------------------
Section("the plan: the band's row never meets, never leaves the page")

for seed = 1, 80 do
    local strips = {}
    local kinds = { "friend", "nemesis", "zerg", "carry", "escort", "duel" }
    for i = 1, 1 + seed % 4 do
        strips[i] = { kind = kinds[(seed + i) % #kinds + 1], t = (seed * 37 + i * 101) % 700, rank = (seed + i) % 13 }
    end
    local row = SP.Row(strips, function(s) return 24 + s.t * 0.56 end)
    Check(#row <= STORY.band.most, "more strips than a line takes")
    for k, r in ipairs(row) do
        Check(r.x >= STORY.band.x0 - 0.01 and r.x + r.w <= STORY.band.x1 + 0.01, "a strip off the band")
        if k > 1 then Check(row[k - 1].x + row[k - 1].w <= r.x + 0.01, "two strips meet") end
        if #row == 3 then Eq(r.band, "M", "three in a row not all M") end
    end
end

--------------------------------------------------------------------------
Section("the page: a told Warsong opens on its story")

ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local YD = ns.UI.YourDiary

local function Parts(kind)
    local out = {}
    for _, part in ipairs(YD.MatchParts()) do
        if not kind or part.pad.kind == kind then out[#out + 1] = part end
    end
    return out
end
local function Used(kind)
    local list = page.bg.used[kind]
    return list and list.n or 0
end

for i, m in ipairs(told) do
    YD.OpenMatch(m.id)
    local bg = page.bg
    Eq(page.mode .. ":" .. tostring(page.matchId), "match:" .. m.id, "setup: the match open")
    Check(bg.story ~= nil, "a told Warsong not on its story")
    Eq(Used("strip:clip"), 0, "the board clipped in on the story")
    Eq(bg.title[1]:GetText(), "Warsong Gulch", "the title")
    Eq(bg.sub:GetText(), ns.UI.JourneyText.StorySub(bg.story), "the subtitle not Text.StorySub")
    Eq(Parts("title")[1].pad.key, "title", "the title not first")
    Eq(YD.MatchParts()[1].pad.kind, "title", "the title not first (the pad lands on it)")
    Eq(#Parts("back"), 1, "no way back to the evening")
    Eq(#Parts("stub"), 1, "no corner stub")
    Eq(#Parts("note"), 1, "no foot line")
    Check(Used("storyQuad") > 50, "the lines not drawn")
    Check(Used("storyStain") > 20, "the stains not drawn")
    Check(Used("storyBox") >= 4, "no crosses")
    Check(Used("storyName") >= 2, "the phases' names not written")
    -- The stub: its word and its link.
    local stub = page.bg.used["strip:stub"][1]
    local said = {}
    for _, fs in ipairs(stub.bg.texts) do if fs:IsShown() then said[#said + 1] = fs:GetText() end end
    Eq(said[1], "VICTORY", "the stub's word")
    Eq(said[#said], ns.UI.JourneyText.StorySeeBoard(), "the stub's link")
    OnPage(stub:Focus().corners, "the stub")
    -- The lines: their marks; the strips: on the page, clear of each other
    -- and of the line over them.
    local lines = YD.StoryLines()
    Eq(#lines, 2, "the story not two lines")
    local boxes = {}
    for _, line in ipairs(lines) do
        Check(#line.marks > 0, "a line with no marks")
        Check(#line.branches > 0, "a line with no branch")
        for _, st in ipairs(line.strips) do
            OnPage(st.strip:Focus().corners, "a strip")
            Check(st.box.y >= line.ln.Y + STORY.lines.down, "a strip over its line")
            Check(st.box.y + st.box.h <= line.ln.band + STORY.band.h + 0.01, "a strip past its band")
            for _, b in ipairs(boxes) do Check(not Meet(b, st.box), "two strips meet") end
            boxes[#boxes + 1] = st.box
        end
        for _, n in ipairs(line.names) do Check(n.x >= 0 and n.x + n.w <= W, "a name off the page") end
    end
    Eq(#boxes, i == 1 and 5 or 6, "the strips drawn")
    local foot = page.bg.storyFoot
    Check(foot.y + foot.h <= H and foot.y >= lines[2].ln.bottom - 0.01, "your line off the page or over the band")
    Eq(page.bg.used.noteText[1]:GetText(), ns.UI.JourneyText.StoryFoot(page.bg.story), "your line not Text.StoryFoot")
end

--------------------------------------------------------------------------
Section("a diary person's strip: underlined in rubric, opening their page")

do
    YD.OpenMatch(told[1].id)
    local tester
    for _, part in ipairs(Parts("strip")) do if part.frame.guid == ns.TestData.GUID then tester = part end end
    Check(tester and tester.pad.kept, "Tester's strip not kept as theirs")
    local R = ns.Style.RUBRIC
    local red = 0
    for _, seg in ipairs(tester.pad.strip.bg.lines) do
        local c = seg.recorded.calls.SetColorTexture
        if seg:IsShown() and c and math.abs(c[1] - R[1]) < 0.01 and math.abs(c[2] - R[2]) < 0.01 then red = red + 1 end
    end
    Check(red > 0, "Tester's name not underlined in rubric")
    local went
    local was = YD.ToPerson
    YD.ToPerson = function(guid) went = guid end
    tester.frame:Click("LeftButton")
    YD.ToPerson = was
    Eq(went, ns.TestData.GUID, "Tester's strip does not open their page")
    -- A stranger's strip opens nothing.
    for _, part in ipairs(Parts("strip")) do
        if not part.frame.guid then Check(part.frame.scripts.OnClick == nil, "a stranger's strip opens something") end
    end
    -- Its tooltip, and its leader inked under the mouse.
    tester.frame.scripts.OnEnter(tester.frame)
    Check(GameTooltip.shown, "a strip's tooltip")
    tester.frame.scripts.OnLeave(tester.frame)
end

--------------------------------------------------------------------------
Section("the stub opens the board view; its way back returns to the story")

do
    YD.OpenMatch(told[2].id)
    Parts("stub")[1].frame:Click("LeftButton")
    Eq(page.matchBoard, told[2].id, "the stub does not open the board view")
    Check(page.bg.story == nil and Used("strip:clip") == 1, "the board view not the board clipped in")
    Eq(#Parts("stub"), 0, "the stub on the board view")
    local back = Parts("story")[1]
    Check(back, "the board view has no way back to the story")
    Eq(back.pad.words:GetText(), YD.STORY_WORDS.backToMatch, "the way back's words")
    Eq(#Parts("back"), 1, "the board view lost the way back to the evening")
    back.frame:Click("LeftButton")
    Eq(page.matchBoard, nil, "the way back does not leave the board view")
    Check(page.bg.story ~= nil, "the way back does not return to the story")
    -- Opened anew, a match is on its story, not the board view it was left on.
    YD.OpenMatchBoard(true)
    YD.OpenMatches(evening.key)
    YD.OpenMatch(told[2].id)
    Check(page.bg.story ~= nil, "a match opened again on its board view")
end

--------------------------------------------------------------------------
Section("the untold Warsong keeps the board")

YD.OpenMatch(untold.id)
Check(page.bg.story == nil, "an untold Warsong drawn as a story")
Eq(Used("strip:clip"), 1, "the untold Warsong's board not clipped in")
Eq(#Parts("stub"), 0, "the untold Warsong has the stub")
Eq(#YD.StoryLines(), 0, "the untold Warsong has lines")

--------------------------------------------------------------------------
Section("Flat paper only: the story's paper lies flat")

ns.db.settings.flatSheets = true
YD.OpenMatch(told[1].id)
Eq(page.bg.used["strip:stub"][1].turn or 0, 0, "the stub turned with Flat paper only")
for _, line in ipairs(YD.StoryLines()) do
    for _, st in ipairs(line.strips) do Eq(st.strip.turn or 0, 0, "a strip turned with Flat paper only") end
end
ns.db.settings.flatSheets = nil

--------------------------------------------------------------------------
Section("with the pad: everything reached, A and B one level each")

local Pad = ns.UI.Pad
local Look = Pad.Look
local book = ns.UI.JournalFrame()
YD.OpenMatch(told[1].id)
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(book)
local function Press(key)
    local went = mock.PadPress(catcher, key, true)
    mock.PadPress(catcher, key, false)
    return went
end
local function Scope() return Pad.Top() end
local function At() return Scope().focus:Current() end
local function Items(group) return Scope().focus.groups[group].items end
local function Legend()
    local out = {}
    for _, e in ipairs(Scope().legend(Scope())) do out[type(e[1]) == "table" and e[1][1] or e[1]] = e[2] end
    return out
end
Pad.Refresh()
Eq(Scope().key, "yourdiary", "setup: the top scope")
Check(Scope().focus:EnterGroup("match"), "setup: onto the story")

-- Everything reached by the D-pad, each once; no mark in the page's walk.
local keys = {}
for _, item in ipairs(Items("match")) do
    Check(not keys[item.key], "a key twice: " .. item.key)
    Check(item.kind ~= "mark", "a line's mark walked with the page")
    keys[item.key] = true
end
local seen, queue = { title = true }, { "title" }
while #queue > 0 do
    local from = table.remove(queue, 1)
    for _, dir in ipairs({ "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT" }) do
        Scope().focus:Focus(from, "match")
        Press(dir)
        Eq(At().group, "match", "the D-pad left the page from " .. from)
        if not seen[At().key] then
            seen[At().key] = true
            queue[#queue + 1] = At().key
        end
    end
end
for key in pairs(keys) do Check(seen[key], "the D-pad never reaches " .. key) end
Check(keys.back and keys.stub and keys.note and keys["line:1"] and keys["line:2"], "the story's parts not all there")
local strips = 0
for key in pairs(keys) do if key:find("^story:") then strips = strips + 1 end end
Eq(strips, 5, "the strips not all reached")

-- The stub: outlined; A opens the board view; B comes back onto it.
local parts = Look.parts[book]
Check(Scope().focus:Focus("stub", "match"), "setup: onto the stub")
Check(parts.outline and parts.outline.line:IsShown(), "the stub not outlined")
Eq(Legend().PAD1, ns.UI.JourneyText.StorySeeBoard(), "A's prompt on the stub")
Press("PAD1")
Eq(page.matchBoard, told[1].id, "A on the stub did not open the board view")
Eq(At().group .. ":" .. At().key, "match:title", "the pad not on the board view's title")
Eq(Legend().PAD2, "Back to the match", "B's prompt on the board view")
Press("PAD2")
Eq(page.matchBoard, nil, "B on the board view did not go back to the story")
Eq(At().group .. ":" .. At().key, "match:stub", "B not back on the stub")
-- The board view's own way back, the same.
Press("PAD1")
Check(Scope().focus:Focus("story", "match"), "the board view's way back not reached")
Eq(Legend().PAD1, "Back to the match", "A's prompt on the way back to the story")
Press("PAD1")
Eq(page.matchBoard, nil, "A on the way back did not return to the story")
Eq(At().key, "stub", "A on the way back not back on the stub")

-- A line: A goes in among its marks, left and right along it; B leaves.
Check(Scope().focus:Focus("line:1", "match"), "setup: onto the first line")
Check(parts.outline.line:IsShown(), "a line not outlined")
Eq(Legend().PAD1, "Look along the line", "A's prompt on a line")
Press("PAD1")
Eq(At().group, "storymarks", "A on a line did not go in")
Check(GameTooltip.shown, "a mark's tooltip not shown")
Eq(Legend().PAD2, "Back to the line", "B's prompt among the marks")
local marks = #Items("storymarks")
Eq(marks, #YD.StoryLines()[1].marks, "a line's marks not all walked")
local first = At().key
Press("PADDRIGHT")
Check(At().group == "storymarks", "right left the line")
Check(At().key ~= first or marks == 1, "right did not move along the line")
local mode, id = page.mode, page.matchId
Press("PAD1")
Eq(page.mode .. ":" .. tostring(page.matchId), mode .. ":" .. tostring(id), "A on a mark did something")
Press("PAD2")
Eq(At().group .. ":" .. At().key, "match:line:1", "B not back on the line")

-- A diary person's strip: A opens their page; a stranger's: tooltip only.
local tester, stranger
for _, item in ipairs(Items("match")) do
    if item.kind == "strip" and item.kept then tester = item end
    if item.kind == "strip" and not item.kept then stranger = stranger or item end
end
Check(tester and stranger, "setup: Tester's strip and a stranger's")
Check(Scope().focus:Focus(tester.key, "match"), "setup: onto Tester's strip")
Check(parts.outline.line:IsShown(), "a strip not outlined")
Eq(Legend().PAD1, "Go to their page", "A's prompt on a diary person's strip")
local went
local was = YD.ToPerson
YD.ToPerson = function(guid) went = guid end
Press("PAD1")
YD.ToPerson = was
Eq(went, ns.TestData.GUID, "A on Tester's strip did not open their page")
Check(Scope().focus:Focus(stranger.key, "match"), "setup: onto a stranger's strip")
Eq(Legend().PAD1, nil, "A offered on a stranger's strip")
Press("PAD1")
Eq(page.mode .. ":" .. tostring(page.matchId), "match:" .. told[1].id, "A on a stranger's strip did something")

-- B on the story: back to the evening's overview, onto its ticket.
Eq(Legend().PAD2, "Back to the battlegrounds", "B's prompt on a match of an evening")
Press("PAD2")
Eq(page.mode, "matches", "B on the story did not go back to the overview")
Eq(At().key, "ticket:" .. told[1].id, "B not back on the ticket")

--------------------------------------------------------------------------
Section("unclaimed buttons go on; the mouse takes over; the Gamepad UI off")

Press("PAD1")
Eq(page.mode .. ":" .. tostring(page.matchId), "match:" .. told[1].id, "setup: the story open")
Check(Press("PADLTRIGGER"), "LT taken on the story")
Check(Scope().focus:Focus("stub", "match"), "setup: onto the stub")
parts = Look.parts[book]
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(not parts.outline.line:IsShown() and not parts.outline.shadow:IsShown(), "the outline left with the mouse")
Check(not catcher:IsGamePadButtonEnabled(), "the book still takes the pad")
mock.pad.ui = false
mock.fire("GAME_PAD_ACTIVE_CHANGED", false)
Pad.Refresh()
Check(not catcher:IsGamePadButtonEnabled(), "the book takes the pad with the Gamepad UI off")
