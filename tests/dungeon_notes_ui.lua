-- The player's own notes on a run's map (UI/Dungeon/Notes.lua's LayOwn,
-- UI/Dungeon/Print.lua's own marks, UI/Dungeon/NoteMenu.lua, the form on the
-- table, Features/Note/Sheet.lua; .claude/ui-proposal/dungeon-notes.md):
-- laid first and never cut, detected strips get what is left of the seven;
-- pinned to a face or marked by the icon picked; on their own floor only;
-- still laid on a crowded sheet; the right click's menu and where it is
-- refused; the form on the table, far from the spot, with no caption row;
-- moving and removing. The pad's side is tests/pad_dungeon.lua's.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local J = ns.UI.Journal
local D = ns.Dungeons
local Page = ns.UI.DungeonPage
local RunNotes = ns.RunNotes
local CardSheet = ns.UI.YourDiary.CardSheet

mock.missingFiles["Interface\\LFGFrame\\LFGIcon-HallofThanes"] = true
mock.missingFiles["Interface\\LFGFrame\\LFGIcon-TestVault"] = true
mock.now = 1795000000
SlashCmdList.SOCIALDIARY("testdata")
ns.SetSetting("dungeonTutorialSeen", true)
local G = ns.TestData.GUID
ns.UI.ShowJournal(G)

local KIND = "noteCard"

--------------------------------------------------------------------------
Section("Pen.Ring draws what the plate's ring drew before it was lifted out")

-- The plate's DrawRing as it stood before 28 Nov 2026, word for word.
local function OldRing(cx, cy, look, seed)
    local Pen = ns.UI.Pen
    local rand = Pen.Random(seed)
    local out = {}
    for d = 1, look.dashes do
        local arc = 2 * math.pi / look.dashes
        local a0 = (d - 1 + (rand() - 0.5) * look.uneven) * arc
        local a1 = a0 + arc * look.share
        local radius = look.r + (rand() - 0.5) * look.wander
        local pts = {}
        for i = 0, look.bends do
            local a = a0 + (a1 - a0) * i / look.bends
            pts[#pts + 1] = cx + radius * math.cos(a)
            pts[#pts + 1] = cy + radius * math.sin(a)
        end
        local line = Pen.Resample(pts, look.step)
        if #line >= 2 then
            local prims, n = {}, #line
            Pen.Stroke(prims, 0, line, Pen.Mitres(line), function(i)
                local a, b = line[math.max(i - 1, 1)], line[math.min(i + 1, n)]
                return look.width / 2 * Pen.Nib(b.x - a.x, b.y - a.y, look.nib)
            end, function() return 0 end, function() return look.alpha end, look.colour, nil, look.bends * 2)
            for _, p in ipairs(prims) do out[#out + 1] = p end
        end
    end
    return out
end
local L_ = ns.UI.YourDiary.LEADER
local look = setmetatable({ colour = L_.colour, alpha = L_.alpha, nib = L_.pen.nib }, { __index = CardSheet.RING })
for _, at in ipairs({ { 12.5, 40.25, 0.31, 0.62 }, { 200, 3, 0.9, 0.07 } }) do
    local seed = 1 + (at[3] * 7919 + at[4] * 104729) * 1000
    local old, new = OldRing(at[1], at[2], look, seed), ns.UI.Pen.Ring({}, at[1], at[2], look, seed)
    Eq(#new, #old, "the ring's pieces")
    local same = true
    for i, p in ipairs(old) do
        for _, k in ipairs({ "x1", "y1", "x2", "y2", "x3", "y3", "x4", "y4", "a" }) do
            if p[k] ~= new[i][k] then same = false end
        end
    end
    Check(same, "a piece of the ring moved")
end

--------------------------------------------------------------------------
-- A run of the player's on the Deadmines: kills on the lower floor.

local onFloor = {}
for _, b in ipairs(D.Bosses(36)) do
    if not b.trash and b.floor and b.x and not D.IsRare(36, b.name) then
        local f = tonumber(b.floor)
        onFloor[f] = onFloor[f] or {}
        table.insert(onFloor[f], b)
    end
end
local UP, DOWN = onFloor[291], onFloor[292]
Check(UP and DOWN and DOWN[2], "the Deadmines' bosses on each floor")
local START = mock.now - 3000
local killed = {}
for _, b in ipairs(DOWN) do killed[#killed + 1] = b.name end
local visit = ns.Instances.New({ instanceID = 36, name = "The Deadmines", instanceType = "party",
    startedAt = START, endedAt = mock.now - 600, bossesKilled = killed,
    members = { { guid = ns.ownGUID, first = "Me", level = 20 }, { guid = G, first = "Tester" } } })
Check(RunNotes.Writable(visit), "setup: the player's own run")

local function Open()
    Page.Close(true)
    ns.UI.OpenVisit(visit.id, "journey")
    local spread = Page.Spread()
    return spread.map, spread
end
local view, spread = Open()
Eq(view.floors[view.floorIndex].uiMapID, 292, "setup: on the floor of the kills")

-- Notes written straight into the run (the form is its own section).
local function Put(fields, where)
    return RunNotes.Insert(visit, KIND, fields, where)
end
local function Clear() visit.custom = nil end
local function Relay() Page.Refresh() return view end

-- Every detected note `n` of them, made up: one about each boss in turn.
local choose = Page.Choose
local function Detected(n)
    Page.Choose = function(v, notes, guid)
        local list = {}
        for i = 1, n do
            local b = DOWN[(i - 1) % #DOWN + 1]
            list[i] = { rank = 3, order = i, kind = "tries", boss = b, name = "Tried " .. i .. " times",
                seed = "made:" .. i }
        end
        return list
    end
end

--------------------------------------------------------------------------
Section("own notes first, oldest first, never counted; detected get what is left")

Detected(9)
for i = 1, 3 do Put({ icon = "heart", text = "note " .. i }, { f = 292, x = 0.2 + i * 0.12, y = 0.3 }) end
Relay()
Eq(#view.ownStrips, 3, "every own note laid")
Eq(#view.noteStrips, 4, "detected strips: 7 less the three own")
Eq(view.notesMore, 5, "the rest of the detected counted")
for i, entry in ipairs(view.ownStrips) do
    Eq(entry.rec.text, "note " .. i, "own notes oldest first")
    Check(entry.strip:IsShown(), "an own note not shown")
    Check(entry.strip.lead ~= nil, "no room for the icon before its heading")
end
Eq(view.ownStrips[1].strip.name:GetText(), "note 1", "a card naming nothing has its words for a heading")
Clear()
for i = 1, 9 do Put({ icon = "quill", text = "many " .. i }, { f = 292, x = 0.1 + i * 0.08, y = 0.5 }) end
Relay()
Eq(#view.ownStrips, 9, "nine own notes all laid")
Eq(#view.noteStrips, 0, "no room left for a detected one")
Eq(view.notesMore, 9, "every detected one counted, no own one")
Clear()
Page.Choose = choose
Relay()
local plain = #view.noteStrips

--------------------------------------------------------------------------
Section("a note pinned to a boss: its leader to the face, no mark of its own")

local B = DOWN[1]
local pinned = Put({ icon = "skull", people = { { name = "Tester", guid = G } }, text = "Saved by a Divine Intervention." },
    { f = tonumber(B.floor), x = B.x, y = B.y, boss = B.name })
Relay()
Eq(#view.ownStrips, 1, "the pinned note laid")
Eq(#view.plan.ownMarks, 0, "a pinned note has a mark of its own")
local e = view.ownStrips[1]
local t = view.plan.targets[B.name]
Eq(e.target, t, "its leader not to the boss's face")
Eq(e.boss, B.name, "not pinned")
if e.tip then
    local d = math.sqrt((e.tip[1] - t.x) ^ 2 + (e.tip[2] - t.y) ^ 2)
    Check(math.abs(d - (t.r + Page.LEADER.gap)) < 0.01, "the arrow not gap short of the face's edge")
else
    Eq(e.leader, "tick", "neither an arrow nor a tick")
end
-- The face moved apart from where the boss stands: the leader follows it.
local mark
for _, m in ipairs(view.plan.marks) do if m.name == B.name then mark = m end end
Eq(t.x, mark.x, "the target is not the face where it was moved")
Eq(e.strip.name:GetText(), "With Tester", "its heading: who it names")
Check(e.strip:Quote():find("Saved by a Divine Intervention.", 1, true), "its words not quoted in the hand")
Eq(e.strip.guid, G, "its name not a way to their page")
Eq(#view.noteStrips, plain, "a pinned note took a detected strip's place")

--------------------------------------------------------------------------
Section("a note on the floor: the icon picked, at its spot; two close share one")

Clear()
local a = Put({ icon = "chest", text = "the chest was empty" }, { f = 292, x = 0.5, y = 0.6 })
local b = Put({ icon = "fish", text = "a second" }, { f = 292, x = 0.5005, y = 0.6005 })
Relay()
Eq(#view.plan.ownMarks, 1, "two notes within merge px not one mark")
local m = view.plan.ownMarks[1]
local x, y = view.At(292, 0.5, 0.6)
Check(math.abs(m.x - x) < 1e-6 and math.abs(m.y - y) < 1e-6, "the mark not at its spot")
Eq(#m.recs, 2, "the mark does not hold both")
local hit
for i = 1, view.pools.hit.used do if view.pools.hit[i].what == "note" then hit = view.pools.hit[i] end end
Check(hit and hit.own == m.recs, "no hover square for the mark")
Eq(hit.tip[1][1], (ns.Note.Tips(m.recs, ns.Now())), "the mark's tooltip is not the free card's account")
Check(view.placer.ownKit.ink.used + view.placer.ownKit.inner.used > 0, "the icon not drawn")
Check(view.placer.ownKit.halo.used > 0, "no paper under the mark")
local last = hit.tip[#hit.tip][1]
Eq(last, "Right-click to change it", "the mouse not told how to change it")
for _, entry in ipairs(view.ownStrips) do
    Eq(entry.target, view.plan.targets["own:1"], "a strip's leader not to the shared mark")
end
-- Two apart: two marks.
b.x = 0.7
Relay()
Eq(#view.plan.ownMarks, 2, "notes apart not their own marks")

--------------------------------------------------------------------------
Section("floors: a note on another floor is neither shown nor counted")

Clear()
local upper = Put({ icon = "boot", text = "upstairs" }, { f = 291, x = 0.5, y = 0.5 })
Relay()
Eq(#view.ownStrips, 0, "a note of the floor above laid on the floor below")
Eq(#view.plan.own, 0, "and planned there")
view.links[1].scripts.OnClick(view.links[1])
Eq(view.floorIndex, 1, "setup: the floor above")
Eq(#view.ownStrips, 1, "the note not on its own floor")
view.links[2].scripts.OnClick(view.links[2])

--------------------------------------------------------------------------
Section("a crowded sheet: every own note still lies, shingled or stacked")

Clear()
for i = 1, 60 do Put({ icon = "music", text = "crowd " .. i }, { f = 292, x = 0.5, y = 0.5 }) end
Detected(7)
Relay()
Page.Choose = choose
Eq(#view.ownStrips, 60, "an own note not laid")
local forced = {}
for _, entry in ipairs(view.ownStrips) do
    if entry.forced then forced[entry.forced] = (forced[entry.forced] or 0) + 1 end
    local bx = entry.box
    Check(bx[3] > 0 and bx[1] < view.w and bx[4] > 0 and bx[2] < view.h, "an own note off the paper")
end
Check((forced.edge or 0) + (forced.stack or 0) > 0, "nothing forced on a crowded sheet")
Check((forced.stack or 0) > 0, "none stacked along the foot")
Eq(#view.noteStrips, 0, "detected strips beside 60 own")
Clear()
Relay()

--------------------------------------------------------------------------
Section("the menu: what a right click offers, and where it offers nothing")

local function Lines(root)
    local out = {}
    for _, c in ipairs(root and root.children or {}) do out[#out + 1] = c.text end
    return table.concat(out, "|")
end
local cursor
view.K.Cursor = function() return cursor[1], cursor[2] end
-- On the floor, away from everything.
cursor = { view.w * 0.5, view.h * 0.5 }
local where = Page.NoteWhereAt(view, cursor[1], cursor[2])
mock.contextMenu = nil
Page.NoteRight(view)
Eq(Lines(mock.contextMenu), "Add a note here", "the floor's menu")
-- Near a face: pinned (t.r + SNAP.reach, not past it).
local tB = view.plan.targets[B.name]
Eq(Page.NoteSnap(view, tB.x + tB.r + Page.NOTE_SNAP.reach - 0.01, tB.y).name, B.name, "a press at the reach not pinned")
local far = Page.NoteSnap(view, tB.x + tB.r + Page.NOTE_SNAP.reach + 1, tB.y)
Check(far == nil or far.name ~= B.name, "a press past the reach pinned")
cursor = { tB.x + 2, tB.y }
Eq(Page.NoteWhereAt(view, cursor[1], cursor[2]).boss, B.name, "a press on the face not pinned")
-- A boss's square, the door's.
local bossHit, doorHit
for i = 1, view.pools.hit.used do
    local h = view.pools.hit[i]
    if h.what == "boss" then bossHit = bossHit or h end
    if h.what == "door" then doorHit = h end
end
mock.contextMenu = nil
bossHit.scripts.OnMouseUp(bossHit, "RightButton")
Eq(Lines(mock.contextMenu), "Add a note here", "a boss's menu")
Check(Page.NoteWhereOfHit(view, bossHit).boss ~= nil, "a boss's note not pinned")
if doorHit then
    local w = Page.NoteWhereOfHit(view, doorHit)
    Check(w and w.f and not w.boss, "the way in gives no spot")
end
-- A detected strip: nothing.
if view.noteStrips[1] then
    mock.contextMenu = nil
    local strip = view.noteStrips[1].strip
    strip.link.scripts.OnMouseUp(strip.link, "RightButton")
    Eq(mock.contextMenu, nil, "a detected strip offered a menu")
end
-- The player's own note: Edit, Move, Remove; a mark of two asks which.
local own = Put({ icon = "heart", text = "mine" }, { f = 292, x = 0.3, y = 0.7 })
local own2 = Put({ icon = "heart", text = "mine too" }, { f = 292, x = 0.3, y = 0.7 })
Relay()
mock.contextMenu = nil
view.ownStrips[1].strip.link.scripts.OnMouseUp(view.ownStrips[1].strip.link, "RightButton")
Eq(Lines(mock.contextMenu), "Edit|Move|Remove", "an own strip's menu")
for i = 1, view.pools.hit.used do if view.pools.hit[i].what == "note" then hit = view.pools.hit[i] end end
mock.contextMenu = nil
hit.scripts.OnMouseUp(hit, "RightButton")
Eq(mock.contextMenu.children[1].text, "Which one?", "a mark of two does not ask which")
Eq(#mock.contextMenu.children, 3, "a line each")
Eq(Lines(mock.contextMenu.children[2]), "Edit|Move|Remove", "each its own lines")
-- No menu: another character's run, the pen up, off the floor, a bare sheet.
cursor = { view.w * 0.5, view.h * 0.5 }
local function Refused(what)
    mock.contextMenu = nil
    Page.NoteRight(view)
    Eq(mock.contextMenu, nil, what)
end
visit.me = "Player-1-0ABCDEF0"
Refused("a menu on another character's run")
visit.me = ns.ownGUID
view.way = view.way or {}
local wasDrawing = view.way.drawing
view.way.drawing = true
Refused("a menu while the pen is out")
view.way.drawing = wasDrawing
local from = view.From
view.From = function() return nil end
Refused("a menu off the printed floor")
view.From = from
local box = view.box
view.box = nil
Refused("a menu on a bare sheet")
view.box = box
local tut = Page.TutorialNote
Page.TutorialNote = function() return { IsShown = function() return true end } end
Refused("a menu under the first run's note")
Page.TutorialNote = tut

--------------------------------------------------------------------------
Section("the form on the table: no caption row, written on the run, far from the spot")

Clear()
Relay()
local function Row(key)
    for _, row in ipairs(CardSheet.View().rows) do if row.field.key == key then return row end end
end
-- A spot on the right of the sheet: the form on its left.
cursor = { view.w * 0.8, view.h * 0.5 }
Page.NoteRight(view)
mock.MenuClick("Add a note here")
local form = CardSheet.View()
Check(form and form:IsShown(), "the form did not open")
Eq(form:GetParent(), spread, "the form not on the spread")
Eq(CardSheet.Run() and CardSheet.Run().host, spread, "the form not scoped to the run")
Eq(Row("caption"), nil, "the caption row on a run's form")
Check(not form.another:IsShown(), "the picker offered on a run")
Check(view.ring.used > 0, "no ring at the spot")
Check(form.runAt.left < 0, "a spot on the right: the form not on the left")
Eq(UISpecialFrames[#UISpecialFrames] == CardSheet.TABLE.name or (function()
    for _, n in ipairs(UISpecialFrames) do if n == CardSheet.TABLE.name then return true end end
end)(), true, "the form does not hold Escape's place")
Row("text").box:SetText("Divine Intervention saved the run.")
local floorShown = view.floorIndex
form.save.scripts.OnClick(form.save)
Eq(visit.custom and #visit.custom, 1, "Save did not write the run's note")
Eq(visit.custom[1].text, "Divine Intervention saved the run.", "its words")
Eq(visit.custom[1].caption, nil, "a caption on a run's note")
Eq(view.floorIndex, floorShown, "the floor shown changed")
Check(not form:IsShown(), "the form left up")
Eq(view.ring.used, 0, "the ring left after the form")
Eq(#view.ownStrips, 1, "the note not laid at once")
Check(form:GetParent() ~= spread, "the form left on the spread")
local spreadHolds = false
for _, n in ipairs(UISpecialFrames) do if n == Page.SPREAD.name then spreadHolds = true end end
Check(spreadHolds, "Escape's place not the spread's again")
-- A spot on the left: the form on the right.
cursor = { view.w * 0.15, view.h * 0.5 }
Page.NoteRight(view)
mock.MenuClick("Add a note here")
Check(form.runAt.left + form.runAt.total > 0 and form.runAt.left > -50, "a spot on the left: the form not on the right")
-- Escape puts the form away, not the run.
_G[CardSheet.TABLE.name]:Hide()
Check(not form:IsShown(), "Escape left the form up")
Check(spread:IsShown(), "Escape put the run away with the form")
-- The run put away takes the form with it.
Page.NoteRight(view)
mock.MenuClick("Add a note here")
Check(form:IsShown(), "setup: the form up")
Page.Close(true)
Check(not form:IsShown(), "the form outlived the run")
view, spread = Open()
view.K.Cursor = function() return cursor[1], cursor[2] end
-- Edit from the menu: the same form, the note's words.
view.ownStrips[1].strip.link.scripts.OnMouseUp(view.ownStrips[1].strip.link, "RightButton")
mock.MenuClick("Edit")
Eq(Row("text"):Get(), "Divine Intervention saved the run.", "Edit did not load the note")
Row("text").box:SetText("It was a Divine Intervention.")
form.save.scripts.OnClick(form.save)
Eq(visit.custom[1].text, "It was a Divine Intervention.", "Edit did not write")

--------------------------------------------------------------------------
Section("Move with the mouse: a click puts it down, right-click or Escape leaves it")

local rec = visit.custom[1]
local function Strip()
    for _, entry in ipairs(view.ownStrips) do if entry.rec.customOf == rec then return entry end end
end
view.ownStrips[1].strip.link.scripts.OnMouseUp(view.ownStrips[1].strip.link, "RightButton")
mock.MenuClick("Move")
local c = _G[Page.NOTE_MOVE.name]
Check(view.moving and c and c:IsShown(), "Move did not pick the note up")
Eq(Strip().strip:GetAlpha(), Page.NOTE_MOVE.alpha, "the note moved not faded")
Check(view.links.used < 2 or view.links[1]:GetFrameLevel() > c:GetFrameLevel(), "the floors' links under the catcher")
local held = false
for _, n in ipairs(UISpecialFrames) do if n == Page.NOTE_MOVE.name then held = true end end
Check(held, "the move does not hold Escape's place")
-- Right-click: left where it was.
local wasX = rec.x
c.scripts.OnMouseUp(c, "RightButton")
Check(not view.moving and not c:IsShown(), "a right click did not end the move")
Eq(rec.x, wasX, "a right click moved it")
Eq(Strip().strip:GetAlpha(), 1, "the strip left faded")
-- Escape: left too.
Page.NoteMove(view, rec)
c:Hide()
Check(not view.moving, "Escape did not end the move")
Eq(rec.x, wasX, "Escape moved it")
-- A click on a boss's face: pinned there.
Page.NoteMove(view, rec)
cursor = { tB.x + 1, tB.y + 1 }
c.scripts.OnUpdate(c, 0.1)
Check(view.ring.used > 0, "no ring under the cursor")
c.scripts.OnMouseUp(c, "LeftButton")
Eq(rec.boss, B.name, "a click on a face did not pin it")
Check(not view.moving, "the move left on")
-- And on the floor: unpinned, at the spot.
Page.NoteMove(view, rec)
cursor = { view.w * 0.6, view.h * 0.75 }
local want = Page.NoteWhereAt(view, cursor[1], cursor[2])
c.scripts.OnMouseUp(c, "LeftButton")
Eq(rec.boss, nil, "put on the floor: still pinned")
Check(math.abs(rec.x - want.x) < 1e-9 and math.abs(rec.y - want.y) < 1e-9, "not where it was put")
-- Another floor while moving: the link works, the note goes there.
Page.NoteMove(view, rec)
view.links[1].scripts.OnClick(view.links[1])
Check(view.moving and view.floorIndex == 1, "the floor's link while moving")
cursor = { view.w * 0.5, view.h * 0.5 }
c.scripts.OnMouseUp(c, "LeftButton")
Eq(rec.f, 291, "not moved to the other floor")
view.links[2].scripts.OnClick(view.links[2])

--------------------------------------------------------------------------
Section("Remove asks first, then the note is gone")

view.links[1].scripts.OnClick(view.links[1])
local confirm = ns.UI.Dialog.Confirm
local asked
ns.UI.Dialog.Confirm = function(text, action) asked = text; action() end
view.ownStrips[1].strip.link.scripts.OnMouseUp(view.ownStrips[1].strip.link, "RightButton")
mock.MenuClick("Remove")
ns.UI.Dialog.Confirm = confirm
Eq(asked, "Delete this note you wrote?\n\nIt comes off the map. This cannot be undone.", "not asked first")
Eq(visit.custom, nil, "not removed")
Eq(#view.ownStrips, 0, "its strip left on the map")
Page.Close(true)
