-- The table spread's host (UI/Dungeon/Spread.lua; DGN-1, DGN-2): a run
-- laid out on a table on a host as big as the screen, the book put aside
-- while it is out (nothing of it shows) and given back exactly as it was,
-- the sheet where the book lay (the book never moves or changes size),
-- slid or, on a screen too small for it, shrunk to stay on the screen, and
-- every way back to the person's page: the bookmark, a click
-- beside the sheet, Escape (the spread, the book with the next
-- press), the card again, someone else, another page,
-- the book shut. Nothing is laid under it: the world shows round the
-- sheet. What is on the map is tests/dungeon_ui.lua's;
-- the light and the shadows are tests/dungeon_light.lua's.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local J = ns.UI.Journal
local Page = ns.UI.DungeonPage

mock.now = 1795000000
SlashCmdList.SOCIALDIARY("testdata")
local G = ns.TestData.GUID
local panel = _G.SocialDiaryJournalFrame
-- The first run's note and its Escape are tests/dungeon_tutorial.lua's.
ns.db.settings.dungeonTutorialSeen = true
local TL = panel.profile.timeline

local RFK
for _, visit in ipairs(ns.Instances.For(G)) do
    if visit.instanceID == 47 then RFK = visit end
end
Check(RFK, "the test data's Razorfen Kraul")

local OPEN, CLOSE = "844", "845"
local function Heard()
    local ids = {}
    for _, sound in ipairs(mock.sounds) do ids[#ids + 1] = tostring(sound[1]) end
    mock.sounds = {}
    return table.concat(ids, ",")
end
local function Out() return J.visit and J.visit.id end
local function Near(a, b) return math.abs(a - b) < 1e-6 end
local function Listed(name)
    for _, n in ipairs(UISpecialFrames) do
        if n == name then return true end
    end
    return false
end
-- What Escape does in the client (CloseSpecialWindows): every frame on
-- the list that is shown, hidden.
local function Escape()
    local found = false
    for _, name in pairs(UISpecialFrames) do
        local frame = _G[name]
        if frame and frame:IsShown() then
            frame:Hide()
            found = true
        end
    end
    return found
end

--------------------------------------------------------------------------
Section("where the sheet lies: on the book, slid only to stay on the screen")

local Lie = Page.Lie
local SH = Page.SHEET
local a = math.rad(SH.turn)
local half = (SH.w * math.cos(a) + SH.h * math.sin(a)) / 2 + Page.SPREAD.shadow
local halfH = (SH.w * math.sin(a) + SH.h * math.cos(a)) / 2 + Page.SPREAD.shadow
local edge = Page.SPREAD.edge
-- The book in the middle of a 1920 by 1080 screen: on it, a little under.
local dx, dy, k, slid = Lie(1920, 1080, 960, 540)
Check(Near(dx, 0) and Near(dy, -SH.down) and k == 1 and not slid, "not on the book: " .. dx .. "," .. dy)
-- No book known: on the screen's middle.
dx, dy, k = Lie(1920, 1080)
Check(Near(dx, 0) and Near(dy, -SH.down) and k == 1, "not on the middle with no book")
-- A screen of no size yet: on the book, as it is.
dx, dy, k, slid = Lie(0, 0, 100, 100)
Check(dx == 0 and dy == -SH.down and k == 1 and not slid, "a screen of no size moved it")
-- The book dragged to the right edge: the sheet slides left just enough.
dx, dy, k, slid = Lie(1920, 1080, 1920 - 420, 540)
Check(slid and k == 1, "the sheet did not slide off the edge")
Check(Near(960 + dx + half, 1920 - edge), "the sheet slid further than it must: " .. (960 + dx + half))
Check(Near(dy, -SH.down), "it slid up or down as well")
-- And to the top: down just enough.
dx, dy = Lie(1920, 1080, 960, 1080 - 300)
Check(Near(540 + dy + halfH, 1080 - edge), "the sheet runs off the top")
-- A 1365 by 768 screen is not tall enough for the bare sheet, a fifth
-- bigger since the book was put aside: it shrinks, just enough.
dx, dy, k = Lie(1365, 768, 682.5, 384)
Check(k < 1 and Near(k, (768 - 2 * edge) / (2 * halfH)), "not shrunk to the screen's height: " .. k)
-- A screen too small for the sheet: it shrinks, the book not, and lies on
-- the middle across.
dx, dy, k = Lie(1024, 768, 512, 384)
Check(k < 1 and Near(k, (1024 - 2 * edge) / (2 * half)), "not shrunk just enough: " .. k)
Check(Near(512 + dx * k - half * k, edge), "shrunk, it runs off the screen")
for _, screen in ipairs({ { 1365, 768 }, { 1024, 768 }, { 1920, 1080 } }) do
    for _, bx in ipairs({ screen[1] / 2, screen[1] - 420, 420 }) do
        local x, y, kk = Lie(screen[1], screen[2], bx, screen[2] / 2)
        local cx, cy = screen[1] / 2 + x * kk, screen[2] / 2 + y * kk
        Check(cx - half * kk >= edge - 1e-6 and cx + half * kk <= screen[1] - edge + 1e-6
            and cy - halfH * kk >= edge - 1e-6 and cy + halfH * kk <= screen[2] - edge + 1e-6,
            ("the sheet off a %dx%d screen, the book at %d"):format(screen[1], screen[2], bx))
    end
end

--------------------------------------------------------------------------
Section("the host: as big as the screen, over the book, which is put aside and stays")

UIParent.width, UIParent.height = 1920, 1080
ns.UI.ShowJournal(G)
-- Where the book is, as the tests read it back (the mock lays nothing out).
local bookAt = { 960, 540 }
panel.GetCenter = function() return bookAt[1], bookAt[2] end
local function Points(frame)
    local out = {}
    for _, pt in ipairs(frame.recorded.points) do
        local args = {}
        for i = 1, pt.args.n do args[i] = tostring(pt.args[i]) end
        out[#out + 1] = pt.point .. ":" .. table.concat(args, ",")
    end
    return table.concat(out, ";")
end
local before = Points(panel)
Heard()
Eq(ns.UI.OpenVisit(RFK.id, G), true, "the run did not come out")
local host = Page.Spread()
Check(host and host:IsShown(), "no host")
Eq(host.parent, UIParent, "the host is the book's: it would go with it")
-- The book put aside: see-through, still open, every part of it with it
-- (the cover is the frame's own), and nothing of the spread inside it.
Eq(panel:GetAlpha(), 0, "the book shows round the run")
Check(panel:IsShown(), "the book shut as the run came out")
local function Inside(frame, root)
    while frame do
        if frame == root then return true end
        frame = frame.parent
    end
    return false
end
for name, part in pairs({ close = panel.close, cover = panel.book, ribbon = panel.ribbons.people,
    tab = panel.profile.tabStory, timeline = TL, intro = panel.views.people }) do
    Check(Inside(part, panel), "the book's " .. name .. " not put aside with it")
end
Check(not Inside(host, panel), "the spread put aside with the book")
-- The wheel stops at the table, so the book's timeline stays where it was.
Eq(host.map.recorded.calls.EnableMouseWheel[1], true, "the wheel reaches the book under the table")
Check(host.map.scripts.OnMouseWheel, "the table does not take the wheel")
Eq(_G.SocialDiaryTableSpread, host, "the host's name")
local points = host.recorded.points
Eq(#points, 2, "the host does not cover the screen")
Eq(points[1].args[1], UIParent, "the host is not the screen's size")
Eq(host.recorded.calls.SetFrameStrata[1], "DIALOG", "the host does not lie over the book")
Eq(panel.recorded.calls.SetFrameStrata[1], "HIGH", "the book's strata")
-- Over the book's side tabs too: the host's strata fixed, set again as it
-- comes out (after everything on it is made), and no tab above the book's.
Eq(host.recorded.calls.SetFixedFrameStrata[1], true, "the host's strata not fixed")
Check(host.recorded.calls.SetFrameStrata.seq > host.map.sheet.recorded.calls.SetFrameLevel.seq,
    "the host's strata not set after its sheet was made")
for _, tab in ipairs({ panel.profile.tabStory, panel.profile.tabMap, panel.profile.tabNote, panel.profile.tabEdit }) do
    Eq(tab.recorded.calls.SetFrameStrata, nil, "a side tab in a strata of its own")
end
-- The sheet covers the host: a click beside it lands on the table.
local map = host.map
Eq(map.parent, host, "the sheet is not on the host")
Eq(map.recorded.points[1].args[1], host, "the sheet does not cover the host")
Eq(Heard(), OPEN, "the sheet did not rustle as it came out")
-- The book does not move or change size; the sheet comes down on it.
Eq(Points(panel), before, "the book moved as the run came out")
Eq(panel.recorded.calls.SetScale, nil, "the book changed size as the run came out")
Eq(host:GetScale(), 1, "the spread shrunk on a screen with room")
-- On the book, slid only as far as this map's sheet (3:2, as tall as
-- the screen leaves) must.
local sp = map.sheet.recorded.points[1].args
local ex, ey = Lie(1920, 1080, 960, 540, map.w, map.h, host.flank, 0)
Check(sp[1] == map and Near(sp[3], 0) and Near(sp[3], ex) and Near(sp[4], ey), "the sheet is not on the book")
Check(sp[4] <= 0 and sp[4] >= -SH.down, "the sheet not on the book's middle, as near as it can")
-- Escape stands in the book's place.
Check(Listed("SocialDiaryTableSpread") and not Listed("SocialDiaryJournalFrame"), "Escape still closes the book first")
Page.Close()
Eq(Out(), nil, "the run is still out")
Check(not host:IsShown(), "the host stayed")
Eq(panel:GetAlpha(), 1, "the book not given back")
Eq(Points(panel), before, "the book moved as the run went")
Eq(panel.recorded.calls.SetScale, nil, "the book changed size as the run went")
Check(Listed("SocialDiaryJournalFrame") and not Listed("SocialDiaryTableSpread"), "Escape not given back to the book")
Eq(Heard(), CLOSE, "the sheet did not rustle as it went")

--------------------------------------------------------------------------
Section("the book near an edge, a small screen: the sheet slides or shrinks, never the book")

-- Dragged to the right edge: the sheet slides left, the book stays.
bookAt = { 1920 - 420, 540 }
ns.UI.OpenVisit(RFK.id, G)
Check(host.lie.slid, "the sheet did not slide")
Eq(host:GetScale(), 1, "the sheet shrank where it could slide")
sp = map.sheet.recorded.points[1].args
local wantX = Lie(1920, 1080, bookAt[1], bookAt[2], map.w, map.h, host.flank, 0)
Check(Near(sp[3], wantX) and sp[3] < bookAt[1] - 960, "the sheet not slid off the edge: " .. sp[3])
Eq(Points(panel), before, "the book moved to make room")
Page.Close()
-- A book shrunk by something else: the sheet at the book's scale (it is
-- the book's child), fitted in the book's own units.
panel:SetScale(0.8)
bookAt = { 960 / 0.8, 540 / 0.8 }
ns.UI.OpenVisit(RFK.id, G)
Eq(host.lie.scale, 1, "the sheet shrank on a book small enough")
Check(Near(host:GetScale(), 0.8), "the spread not at the book's scale: " .. host:GetScale())
Eq(panel:GetScale(), 0.8, "the book's own scale changed")
Page.Close()
-- A book already a little see-through (another addon's fade) gets its
-- own alpha back.
panel:SetAlpha(0.9)
ns.UI.OpenVisit(RFK.id, G)
Eq(panel:GetAlpha(), 0, "the book shows round the run")
Page.Close()
Eq(panel:GetAlpha(), 0.9, "the book not given back as it was")
panel:SetAlpha(1)
panel:SetScale(1)
panel.recorded.calls.SetScale = nil
-- A screen too small for a 3:2 map's sheet (800 wide): only the spread
-- shrinks.
UIParent.width = 800
bookAt = { 400, 540 }
ns.UI.OpenVisit(RFK.id, G)
local s = select(3, Lie(800, 1080, 400, 540, map.w, map.h, host.flank, 0))
Check(s < 1 and Near(host:GetScale(), s), "the spread not shrunk to fit: " .. host:GetScale())
Eq(panel.recorded.calls.SetScale, nil, "the book shrank with the spread")
-- The screen grows under it: fitted again.
UIParent.width = 1920
bookAt = { 960, 540 }
mock.fire("DISPLAY_SIZE_CHANGED")
Eq(host:GetScale(), 1, "not fitted again as the screen grew")
UIParent.width = 800
bookAt = { 400, 540 }
mock.fire("UI_SCALE_CHANGED")
Check(Near(host:GetScale(), s), "not fitted again as the UI scale changed")
ns.UI.OpenVisit(RFK.id, G)
Eq(Points(panel), before, "the book moved on a small screen")
UIParent.width, UIParent.height = 1920, 1080
bookAt = { 960, 540 }

--------------------------------------------------------------------------
Section("every test map's floors: the sheet their shape, on the screen, the book still")

local function New(instanceID, name, killed)
    return ns.Instances.New({ instanceID = instanceID, name = name, bossesKilled = killed, instanceType = "party",
        members = { { guid = G, first = "Tester" } }, startedAt = mock.now - 3000, endedAt = mock.now - 1000 })
end
local WC
for _, visit in ipairs(ns.Instances.For(G)) do
    if visit.instanceID == 43 then WC = visit end
end
local runs = { RFK, WC, New(36, "The Deadmines", { "Rhahk'Zor", "Gilnid", "Mr. Smite" }),
    New(3065, "The Hall of Thanes", { "Faldrim Anvilmar" }) }
local seen = 0
for _, screen in ipairs({ { 1365, 768 }, { 1024, 768 } }) do
    UIParent.width, UIParent.height = screen[1], screen[2]
    for _, at in ipairs({ { screen[1] / 2, 384 }, { screen[1] - 420, 384 } }) do
        bookAt = at
        for _, run in ipairs(runs) do
            ns.UI.OpenVisit(run.id, G)
            for f = 1, #(map.floors or {}) do
                map.chosen[run.id] = f
                map:Open(run, G)
                seen = seen + 1
                local kept = map.kept
                Check(Near(map.w / map.h, (kept[3] - kept[1]) / (kept[4] - kept[2])),
                    "a sheet not its map's shape: " .. run.name .. " " .. f)
                -- Its turned outline and shadow inside the screen's edge.
                local k = host:GetScale()
                local p = map.sheet.recorded.points[1].args
                local cx, cy = screen[1] / 2 + p[3] * k, screen[2] / 2 + p[4] * k
                local hw = (map.w * math.cos(a) + map.h * math.sin(a)) / 2 + Page.SPREAD.shadow
                local hh = (map.w * math.sin(a) + map.h * math.cos(a)) / 2 + Page.SPREAD.shadow
                Check(cx - hw * k >= edge - 1e-6 and cx + hw * k <= screen[1] - edge + 1e-6
                    and cy - hh * k >= edge - 1e-6 and cy + hh * k <= screen[2] - edge + 1e-6,
                    ("%s floor %d off a %dx%d screen"):format(run.name, f, screen[1], screen[2]))
            end
            map.chosen[run.id] = nil
            Page.Close()
            Eq(Points(panel), before, "the book moved for " .. run.name)
            Eq(panel.recorded.calls.SetScale, nil, "the book changed size for " .. run.name)
        end
    end
end
Eq(seen, 2 * 2 * 5, "not every floor laid")
-- Strips that stick out past the sheet stay on the screen: a small screen,
-- the book at its right edge, every strip pushed out to the paper's edge.
UIParent.width, UIParent.height = 1024, 768
bookAt = { 1024 - 420, 384 }
local gaps = Page.PLACE.gap
Page.PLACE.gap = { 2000 }
ns.UI.OpenVisit(RFK.id, G)
Check(map.screen and #map.noteStrips > 0, "no strips laid on a small screen")
for _, e in ipairs(map.noteStrips) do
    local b = e.box
    for _, p in ipairs({ { b[1], b[2] }, { b[3], b[2] }, { b[3], b[4] }, { b[1], b[4] } }) do
        local X, Y = map.K.Screen(p[1], p[2])
        local k = host:GetScale()
        local sx, sy = 512 + (map.lie[1] + X) * k, 384 + (map.lie[2] + Y) * k
        Check(sx >= 0 and sx <= 1024 and sy >= 0 and sy <= 768, "a strip off the screen: " .. sx .. "," .. sy)
    end
end
Page.PLACE.gap = gaps
Page.Close()
UIParent.width, UIParent.height = 1365, 768
bookAt = { 682.5, 384 }

--------------------------------------------------------------------------
Section("the way back: a bookmark beside the sheet with their name in pencil")

TL:SetOffset(3)
local offset = TL.offset
ns.UI.OpenVisit(RFK.id, G)
local back = host.back
Check(back:IsShown() and back:IsVisible(), "no bookmark")
Eq(back.words:GetText(), "Tester's story", "the bookmark's words")
Eq(back.words.recorded.calls.SetFontObject[1], ns.Style.FONT.pencil, "the bookmark's words not in pencil")
Check(back.w >= Page.BOOKMARK.least and back.w >= Page.BOOKMARK.ribbon + back.textW, "the words not on the bookmark")
-- By the map's top-left corner, its right end under the
-- sheet's left edge: over the ground's shadows, under the sheet.
Check(back:GetFrameLevel() > map.ground:GetFrameLevel() and back:GetFrameLevel() < map.sheet:GetFrameLevel(),
    "the bookmark does not lie between the ground and the sheet")
local bp = back.recorded.points[1]
Check(bp.point == "CENTER" and bp.args[1] == map, "the bookmark not on the table")
local bx, by = Page.BookmarkAt(host.lie[1], host.lie[2], map.w, map.h, back.w)
Check(Near(bp.args[3], bx) and Near(bp.args[4], by), "the bookmark not by the sheet's corner")
local ta = math.rad(SH.turn)
local cornerX = host.lie[1] - map.w / 2 * math.cos(ta) - map.h / 2 * math.sin(ta)
local cornerY = host.lie[2] - map.w / 2 * math.sin(ta) + map.h / 2 * math.cos(ta)
Check(bx + back.w / 2 > cornerX and bx + back.w / 2 < cornerX + Page.BOOKMARK.tuck + 4, "its end not tucked under the sheet")
Check(bx < cornerX and by < cornerY and by > cornerY - 60, "the bookmark not by the top-left corner")
-- Room for it beside the sheet, on the screen.
Check(host.flank >= back.w - Page.BOOKMARK.tuck, "no room beside the sheet for the bookmark")
Check((bx - back.w / 2) * host:GetScale() >= -1365 / 2, "the bookmark off the screen")
-- Physical: its ribbon, its paper lit, its shadow on the world.
Check(back.ribbon and back.paper, "no ribbon or no paper")
Check(#back.shadows == ns.UI.Light.CAST.layers, "no shadow under the bookmark")
-- Picked up under the mouse: the words darken and it stands higher.
local lying = back.height
back.scripts.OnEnter(back)
Eq(back.words.recorded.calls.SetTextColor[1], ns.Style.INK_STRONG[1], "the words do not darken under the mouse")
Check(back.height > lying, "the bookmark not picked up under the mouse")
back.scripts.OnLeave(back)
Eq(back.words.recorded.calls.SetTextColor[1], ns.Style.GRAPHITE[1], "the words stay dark")
Eq(back.height, lying, "the bookmark not laid down again")
Heard()
back.scripts.OnClick(back)
Eq(Out(), nil, "the bookmark did not put the run away")
Eq(Heard(), CLOSE, "the bookmark put it away without a sound")
Eq(panel:GetAlpha(), 1, "the book not back")
Check(TL:IsShown() and TL.offset == offset, "their story not as it was under the spread")
Check(panel.profile.tabStory.selected, "their story's tab is not lit")
Eq(Points(panel), before, "the book moved while it was put aside")
-- No one's name: the story still.
back:Set(nil)
Eq(back.words:GetText(), "Their story", "the bookmark without a name")

--------------------------------------------------------------------------
Section("the other ways back")

-- A click on the table beside the sheet: the book's corners that show, or
-- the bare table.
ns.UI.OpenVisit(RFK.id, G)
map.scripts.OnMouseDown(map)
Eq(Out(), nil, "a click beside the sheet did not put it away")
-- A click on the sheet itself does not.
ns.UI.OpenVisit(RFK.id, G)
Check(map.sheet.recorded.calls.EnableMouse[1], "the sheet lets clicks through to the table")
-- Escape: the spread, the book with the next press.
Check(Escape(), "Escape found nothing to close")
Eq(Out(), nil, "Escape did not put the run away")
Check(panel:IsShown(), "Escape shut the book with the spread")
Eq(panel:GetAlpha(), 1, "Escape did not give the book back")
Check(not map:IsShown(), "the sheet still lies out after Escape")
Check(Listed("SocialDiaryJournalFrame"), "the book not back on Escape's list")
Eq(Points(panel), before, "the book moved on Escape")
-- A second press shuts the book.
Check(Escape(), "the second Escape found nothing to close")
Check(not panel:IsShown(), "the second Escape did not shut the book")
Check(not Listed("SocialDiaryTableSpread"), "the spread still on Escape's list")
ns.UI.ShowJournal(G)
Check(panel:IsShown() and panel:GetAlpha() == 1 and J.selected == G, "the book not back on their page")
-- Out again after Escape: it rustles out again.
Heard()
ns.UI.OpenVisit(RFK.id, G)
Eq(Heard(), OPEN, "out again after Escape, no sound")
Check(map:IsShown(), "the sheet not out again after Escape")
-- The card again.
Eq(ns.UI.OpenVisit(RFK.id, G), false, "the card again did not put it away")
-- Someone else.
ns.UI.OpenVisit(RFK.id, G)
Heard()
ns.UI.SelectPerson(ns.ownGUID)
Eq(Out(), nil, "another person's page kept the run out")
Eq(Heard(), "", "putting it away for someone else rustled")
ns.UI.SelectPerson(G)
Check(not host:IsShown(), "back on their page, the run came back")
-- Writing.
ns.UI.OpenVisit(RFK.id, G)
J.Edit(G)
Eq(Out(), nil, "writing kept the run out")
J.EndEdit()
-- Another page of the book.
ns.UI.OpenVisit(RFK.id, G)
ns.UI.SetJournalView("journey")
Eq(Out(), nil, "another page kept the run out")
ns.UI.SetJournalView("people")
Check(not host:IsShown(), "back on People, the run came back")
-- The book shut, with the book's own sound only.
ns.UI.SelectPerson(G)
ns.UI.OpenVisit(RFK.id, G)
UIParent.width = 1024
mock.fire("DISPLAY_SIZE_CHANGED")
Heard()
ns.UI.CloseJournal()
Eq(Out(), nil, "the book shut with the run out")
Eq(Heard(), "", "the sheet rustled as the book shut")
Eq(panel:GetAlpha(), 1, "the book shut see-through")
Eq(panel.recorded.calls.SetScale, nil, "the book shut at another size")
Check(not host:IsShown(), "the host stayed with the book shut")
ns.UI.ShowJournal(G)
Check(not host:IsShown() and TL:IsShown(), "the book opened again on the run")
UIParent.width = 1365
-- A run that is not theirs.
Eq(ns.UI.OpenVisit(424242, G), false, "a visit that is not theirs came out")
Eq(Out(), nil, "a visit that is not theirs is out")
-- From a closed book: it opens on their page, the run over it.
ns.UI.CloseJournal()
Eq(ns.UI.OpenVisit(RFK.id, G), true, "the run did not come out of a shut book")
Check(panel:IsShown() and ns.UI.JournalShowing("people") and J.selected == G, "the book not open on their page")
Check(host:IsShown(), "no spread over the book opened for it")
Eq(panel:GetAlpha(), 0, "the book opened for the run shows round it")
Page.Close()

--------------------------------------------------------------------------
Section("Flat paper only: the sheet lies flat, turned all the same")

ns.SetSetting("flatSheets", true)
ns.UI.OpenVisit(RFK.id, G)
Check(map.flat and not map.bends, "the sheet bends with Flat paper only")
Check(map.printer.cuts > 0, "no art laid flat")
Check(Near(map.pools.number[1].recorded.calls.SetRotation[1], math.rad(Page.SHEET.turn)), "a flat sheet not turned")
Page.Close()
ns.SetSetting("flatSheets", false)

SlashCmdList.SOCIALDIARY("testdata remove")
ns.UI.CloseJournal()
