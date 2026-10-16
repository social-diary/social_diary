-- The dungeon page (UI/Dungeon/, UI/Map/Dungeon.lua; TLN-12, DGN-1 to
-- DGN-3, MAP-1 to MAP-4, MAP-7): a click on a visit's card opens the run's
-- map on the right page only, and every way back returns to the person's
-- page. /sd testdata writes the two visits: Razorfen Kraul (client art,
-- a rare killed) and Wailing Caverns (drawn art, inside a session).

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local J = ns.UI.Journal
local D = ns.Dungeons

-- A Forever dungeon: the client has no group finder picture of it.
mock.missingFiles["Interface\\LFGFrame\\LFGIcon-HallofThanes"] = true
mock.missingFiles["Interface\\LFGFrame\\LFGIcon-TestVault"] = true
mock.now = 1795000000
SlashCmdList.SOCIALDIARY("testdata")
local G = ns.TestData.GUID
local panel = _G.SocialDiaryJournalFrame
local p = panel.profile
local TL = p.timeline

local function VisitOf(instanceID)
    for _, visit in ipairs(ns.Instances.For(G)) do
        if visit.instanceID == instanceID then return visit end
    end
end
local RFK, WC = VisitOf(47), VisitOf(43)
Check(RFK and WC, "the test data's visits")

-- The card on the timeline for `visit`, scrolled into view.
local function Card(visit)
    for offset = 0, #TL.data do
        TL:SetOffset(offset)
        for _, row in ipairs(TL.rows) do
            local line = row:IsShown() and row.item
            if line and line.visit and line.visit.visit == visit then return row end
        end
    end
end

local function Open() return J.visit and J.visit.id end

--------------------------------------------------------------------------
Section("the card opens the dungeon page (TLN-12)")

local card = Card(RFK)
Check(card, "no Razorfen Kraul card on the timeline")
card.scripts.OnEnter(card)
Check(GameTooltip.text and GameTooltip.text:find("Click to open its map%."), "the card's tooltip: "
    .. tostring(GameTooltip.text))
Eq(card.visit.hot, true, "the card does not lift under the mouse")
card.scripts.OnLeave(card)
Eq(card.visit.hot, nil, "the card stays lifted after the mouse left")

-- No more folding: the click does not change the timeline's lines.
local before = #TL.data
TL:SetOffset(2)
card = Card(RFK)
local offset = TL.offset
card.scripts.OnMouseUp(card)
Eq(Open(), RFK.id, "the click did not open the visit")
local view = p.dungeon
Check(view:IsShown(), "the dungeon page is not shown")
Eq(#TL.data, before, "the visit folded open in place")
Check(not TL:IsShown(), "the timeline is still on the page")
Check(not p.name:IsShown() and not p.portrait:IsShown() and not p.edit:IsShown(), "the person's heading is still on the page")
-- The right page only: the People list and the tabs stay.
Check(panel.people:IsShown(), "the People list went with it")
Check(p.tabStory.recorded.toldShown ~= false and not p.tabStory.selected, "their story's tab is not the way back")
Eq(ns.UI.JournalView(), "people", "the book turned")

-- The head: the day and the same card, at the top level, saying a click
-- goes back.
Check(view.head:IsShown() and view.head.item.visit.visit == RFK, "the card is not the page's head")
Eq(view.head.item.depth, nil, "the head card is indented")
Eq(view.day.text:GetText(), ns.UI.Format.DayLabel(view.head.item.item.time, ns.Now()):upper(), "the day over the card")
Check(view.head.item.full:find("Click to go back to their story%.$"), "the head card's tooltip: " .. view.head.item.full)
Eq(view.back:GetText(), "Back to Tester's story", "the way back's words")
-- The day says when: the card on this page has no time beside it.
Eq(view.head.item.when, nil, "the head card shows its time")
Eq(view.head.when:GetText(), "", "the head card's time is written")

--------------------------------------------------------------------------
Section("the print: the main floor's art")

local floor, index = D.MainFloor(RFK)
Eq(view.floorIndex, index, "not on the main floor")
local canvas = view.print.canvas
Eq(canvas.floor, floor, "the print is not of the main floor")
Eq(canvas.tiles.used, 12, "Razorfen Kraul's twelve tiles")
local drawn = {}
for i = 1, canvas.tiles.used do drawn[i] = canvas.tiles[i].recorded.calls.SetTexture[1] end
Eq(drawn[1], floor.tiles[1][1], "the first tile")
Eq(drawn[12], floor.tiles[3][4], "the last tile")
-- Printed on stock: toned, not as a screen shows it.
local tint = canvas.tiles[1].recorded.calls.SetVertexColor
Eq(tint[1], ns.UI.JourneyPlate.PLATE.plain[1], "the art is not toned where it cannot be greyed")
-- A drawn map's artist is credited on the About page, not on the print.
Eq(view.print.credit, nil, "a credit on the print")
Eq(view.thumbs.used, 0, "small prints for a one-floor dungeon")

--------------------------------------------------------------------------
Section("bosses: inked when killed, pencil when not, rares when killed, trash never")

local marks = {}
for _, mark in ipairs(view.print.marks) do marks[mark.name] = mark end
Eq(#view.print.marks, 6, "Razorfen Kraul's marks")
Check(marks.Roogug and marks.Roogug.killed and marks.Roogug.rare, "the rare killed is not marked")
Eq(marks.Roogug.order, 1, "the first to fall")
Eq(marks["Overlord Ramtusk"].order, 4, "the fourth to fall")
Check(marks["Aggem Thorncurse"].killed and marks["Death Speaker Jargba"].killed, "a kill not inked")
Check(not marks["Agathelos the Raging"].killed and not marks["Charlga Razorflank"].killed,
    "a boss left standing is inked")
Eq(marks.Trash, nil, "the trash is marked")
-- Each boss is its own face: the kills in brass (the rare in silver), with
-- their numbers; the standing ones greyed in pencil. A face from the
-- creature's display where it has one, else its portrait texture.
local pools = view.print.pools
Eq(pools.medal.used, 4, "a face per kill")
Eq(pools.sketch.used, 2, "a face per boss standing")
Eq(pools.fill.used, 0, "a lozenge where there is a face")
Eq(pools.number.used, 4, "a number per kill")
Eq(pools.number[4]:GetText(), "4", "the last number")
local looks, byDisplay = {}, {}
for i = 1, pools.medal.used do
    local medal = pools.medal[i]
    looks[medal.look] = (looks[medal.look] or 0) + 1
    if medal.icon.portrait then byDisplay[medal.icon.portrait] = medal end
end
Eq(looks.rare, 1, "the rare killed is not in silver")
Eq(looks.killed, 3, "the kills are not in brass")
Eq(marks.Roogug.face, "portrait", "Roogug's face is not his portrait")
Eq(marks["Aggem Thorncurse"].face, "display", "Aggem's face is not from his display")
Check(byDisplay[6097] and byDisplay[6097].look == "killed", "Aggem's display is not on a brass face")
local standing = pools.sketch[1]
Eq(standing.look, "standing", "a boss standing is not in pencil")
Eq(standing.icon.recorded.calls.SetDesaturated[1], true, "a boss standing is not greyed")
Eq(standing.icon.recorded.calls.SetAlpha[1], 0.55, "a boss standing is not faded")
Eq(byDisplay[6097].icon.recorded.calls.SetDesaturated[1], false, "a kill is greyed")
-- A rare not killed is left off.
local unkilled = { id = 9001, instanceID = 47, bossesKilled = { "Aggem Thorncurse" } }
local names = {}
for _, mark in ipairs(ns.UI.DungeonPage.Marks(unkilled)) do names[mark.boss.name] = mark.killed end
Eq(names.Roogug, nil, "a rare left standing is marked")
Eq(names["Aggem Thorncurse"], true, "a kill")
Eq(names["Charlga Razorflank"], false, "a boss standing")

-- Tooltips say what each mark is; there is no key.
local tips = {}
for i = 1, view.print.pools.hit.used do
    local tip = view.print.pools.hit[i].tip
    local lines = {}
    for j = 2, #tip do lines[#lines + 1] = tip[j][1] end
    tips[tip[1][1]] = table.concat(lines, " / ")
end
Eq(tips.Roogug, "Rare / Killed on this run", "the rare's tooltip")
Eq(tips["Charlga Razorflank"], "Not killed on this run", "a standing boss's tooltip")
Eq(tips["Death Speaker Jargba"], "Killed on this run", "a kill's tooltip")
-- What happened at a boss, under its name (MAP-13's words, all of them).
Eq(tips["Aggem Thorncurse"], "Killed on this run / Wiped once / Killed on the second try / "
    .. ns.Style.Inkify(RFK.loot[1].item) .. ", dropped for Tester", "what happened at Aggem")
Check(view.print.door, "no way in on the print")
local door
for i = 1, view.print.pools.hit.used do
    if view.print.pools.hit[i].tip[1][1] == "The way in" then door = view.print.pools.hit[i] end
end
Check(door, "the way in has no tooltip")
Eq(door.tip[2] and door.tip[2][1], "Ran back once as a ghost", "the runs back are not on the way in's tooltip")

-- No face to show (no client call for a display's portrait): a portrait
-- texture still comes; the rest fall back to the lozenge and the ring,
-- never an empty circle.
local Portrait = _G.SetPortraitTextureFromCreatureDisplayID
_G.SetPortraitTextureFromCreatureDisplayID = nil
view:Open(RFK, G, "Tester")
marks = {}
for _, mark in ipairs(view.print.marks) do marks[mark.name] = mark end
Eq(marks.Roogug.face, "portrait", "a portrait texture needs the display call")
Eq(marks["Aggem Thorncurse"].face, nil, "a face without the call")
Eq(pools.medal.used, 1, "faces without the call")
Eq(pools.fill.used, 3, "no lozenge for a kill without a face")
Eq(pools.sketch.used, 1, "Charlga's portrait is not shown")
Check(pools.ink.used > 3 * 2, "no pencil ring for Agathelos without a face")
Eq(pools.number.used, 4, "a kill without a face lost its number")
_G.SetPortraitTextureFromCreatureDisplayID = Portrait
local faceless = ns.Style.BossMedallion(UIParent, 24)
Eq(faceless:SetBoss("killed", nil, nil), nil, "a face from nothing")
Eq(faceless:SetBoss("killed", 6097, nil), "display", "a face from a display")
Eq(faceless.icon.portrait, 6097, "the display's portrait is not on the face")
view:Open(RFK, G, "Tester")

--------------------------------------------------------------------------
Section("the usual way through (MAP-4)")

local counts = view.print.routeCounts
Check(counts.ink > 0, "no ink to the last boss killed")
Check(counts.pencil > 0, "no pencil past the last boss killed")
-- Whether it is drawn is a setting now, on Interface's Dungeons and Raids
-- page; the dungeon page has no switch of its own.
Eq(view.toggle, nil, "the dungeon page still has its switch")
Eq(ns.SettingDefault("dungeonRoute"), true, "the usual way is not drawn by default")
Eq(ns.IsAccountSetting("dungeonRoute"), false, "the usual way is not the character's setting")
local SP = ns.UI.SettingsPage()
Eq(ns.UI.Settings.Sections()[5].key, "dungeons", "Dungeons and Raids is not after Keybinds & Shortcuts")
Eq(ns.UI.Settings.Sections()[5].parent, "interface", "Dungeons and Raids is not Interface's subpage")
Eq(SP.nav.dungeons.label:GetText(), "Dungeons and Raids", "the subpage's name")
ns.UI.ShowSettings("dungeons")
Check(SP.dungeonRoute:GetChecked(), "the switch is not on by default")
SP.dungeonRoute.scripts.OnClick(SP.dungeonRoute)
Eq(ns.Setting("dungeonRoute"), false, "the switch did not turn the setting off")
Eq(view.print.routeCounts.ink + view.print.routeCounts.pencil, 0, "the open page kept the way with it off")
ns.UI.SetJournalView("people")
Check(view:IsShown() and J.visit and J.visit.id == RFK.id, "back on the person's page, the dungeon page went")
Eq(view.print.routeCounts.ink + view.print.routeCounts.pencil, 0, "the way drawn with the setting off")
ns.UI.ShowSettings("dungeons")
SP.dungeonRoute.scripts.OnClick(SP.dungeonRoute)
Eq(ns.Setting("dungeonRoute"), true, "the switch did not turn the setting on")
Check(view.print.routeCounts.ink > 0, "the way not drawn again")
ns.UI.SetJournalView("people")

--------------------------------------------------------------------------
Section("the way back (DGN-2)")

-- The link: back to the timeline where it was read.
view.back.scripts.OnClick(view.back)
Eq(Open(), nil, "the link did not go back")
Check(TL:IsShown() and not view:IsShown(), "the timeline is not back")
Check(p.name:IsShown() and p.edit:IsShown(), "the heading is not back")
Eq(TL.offset, offset, "the timeline lost its place")
Check(p.tabStory.selected, "their story's tab is not lit again")

-- A second click on the card: on the page, the card is the head.
ns.UI.OpenVisit(RFK.id, G)
Eq(Open(), RFK.id, "the entry point did not open the visit")
view.head.scripts.OnMouseUp(view.head)
Eq(Open(), nil, "a second click on the card did not go back")
Check(TL:IsShown(), "the timeline is not back after the second click")

-- Their story's tab.
ns.UI.OpenVisit(RFK.id, G)
p.tabStory.scripts.OnClick(p.tabStory)
Eq(Open(), nil, "their story's tab did not go back")

-- Closing the book and opening it again.
ns.UI.OpenVisit(RFK.id, G)
ns.UI.CloseJournal()
ns.UI.ShowJournal(G)
Eq(Open(), nil, "the book opened again on the dungeon page")
Check(TL:IsShown() and not view:IsShown(), "the person's page is not back after closing the book")

-- Someone else's page opens on their story.
ns.UI.OpenVisit(RFK.id, G)
ns.UI.SelectPerson(ns.ownGUID)
Eq(Open(), nil, "another page kept the dungeon page")
ns.UI.SelectPerson(G)
Check(TL:IsShown(), "back on the page, the dungeon page came back")
Eq(ns.UI.OpenVisit(424242, G), false, "a visit that is not theirs opened")

--------------------------------------------------------------------------
Section("a run inside a session, on drawn art")

card = Card(WC)
Check(card and card.item.depth == 1, "the Wailing Caverns card is not inside its session")
card.scripts.OnMouseUp(card)
Eq(Open(), WC.id, "the Wailing Caverns card did not open")
Eq(view.head.item.depth, nil, "the head of a run inside a session is indented")
canvas = view.print.canvas
Check(canvas.floor.custom, "Wailing Caverns is not on its drawn map")
Eq(canvas.tiles.used, 24, "Wailing Caverns' tiles")
Check(canvas.tiles[1].recorded.calls.SetTexture[1]:find("social_diary\\Vendor\\DungeonCrawlerForever\\Art\\43_", 1, true),
    "a drawn tile is not ours")
-- A run with nothing to say (no pulls, deaths or loot kept): no strips,
-- no leaders, no crosses.
Eq(#view.noteStrips, 0, "notes for a run with nothing to say")
Check(not view.more:IsShown(), "a count of notes for a run with nothing to say")
Eq(view.print.pools.leader.used, 0, "leaders for a run with nothing to say")
Eq(#view.print.crosses, 0, "crosses for a run without deaths")
ns.UI.OpenVisit(WC.id, G)

--------------------------------------------------------------------------
Section("floors to choose, and a drawn map's credit")

local function Visit(fields)
    fields.members = { { guid = G, first = "Tester" }, { guid = ns.ownGUID, first = "Me" } }
    fields.startedAt, fields.endedAt = mock.now - 3000, mock.now - 1200
    fields.instanceType = "party"
    return ns.Instances.New(fields)
end

-- The Deadmines: two floors, the kills on the second.
local vc = Visit({ instanceID = 36, name = "The Deadmines", bossesKilled = { "Rhahk'Zor", "Gilnid", "Mr. Smite" },
    bossTotal = 8 })
Eq(ns.UI.OpenVisit(vc.id, G), true, "the Deadmines did not open")
Eq(view.floorIndex, 2, "not on the floor of most kills")
Eq(view.thumbs.used, 2, "a small print per floor")
Check(view.thumbs[2].current and not view.thumbs[1].current, "the floor shown is not marked")
Eq(view.thumbs[1].name:GetText(), "The Deadmines", "a floor's name")
Eq(view.thumbs[1].marks.used, 1, "the first floor's kills")
view.thumbs[1].scripts.OnClick(view.thumbs[1])
Eq(view.floorIndex, 1, "a small print does not show its floor")
Eq(view.print.canvas.floor.uiMapID, 291, "the print is not of the floor chosen")
-- Rhahk'Zor and Sneed; Miner Johnson is a rare nobody killed.
Eq(D.IsRare(36, "Miner Johnson"), true, "Miner Johnson is no rare now: count him")
Eq(#view.print.marks, 2, "the first floor's bosses")
Eq(Open(), vc.id, "choosing a floor went back")
ns.UI.OpenVisit(vc.id, G)

-- The Hall of Thanes: drawn art with its artist's name.
local thanes = Visit({ instanceID = 3065, name = "The Hall of Thanes", bossesKilled = { "Faldrim Anvilmar" } })
ns.UI.OpenVisit(thanes.id, G)
Check(view.print.canvas.floor.custom, "The Hall of Thanes is not on its drawn map")
Eq(view.print.credit, nil, "a credit on a drawn map's print")
-- No picture of it in the client: the card's medallion wears its last
-- boss's face, as the map does, and no drop cap over it.
local medal = view.head.visit.medallion
Eq(ns.Style.InstanceArt(thanes), nil, "a picture of The Hall of Thanes")
Eq(medal.how, "face", "no face on a dungeon the client has no picture of")
Eq(medal.initial:IsShown(), false, "a drop cap over the face")
local durgen = D.Boss(3065, "Durgen Dirgehammer")
Eq(D.Bosses(3065)[#D.Bosses(3065)].name, "Durgen Dirgehammer", "the last boss")
Eq(ns.UI.DungeonPage.Face(thanes).display, durgen.display, "the face is not the last boss's")
-- Neither picture nor face: the drop cap, on its own layer over the ring.
local bare = ns.Style.Medallion(UIParent, 36)
bare:SetVisit({ instanceID = 999999, name = "The Test Vault" }, nil)
Eq(bare.how, "initial", "no drop cap without a picture or a face")
Check(bare.initial:IsShown(), "the drop cap is hidden")
Check(bare.initial.parent:GetFrameLevel() > bare:GetFrameLevel() + 1, "the drop cap lies under the face")
bare:SetVisit({ instanceID = 47, name = "Razorfen Kraul" }, nil)
Eq(bare.how, "art", "the group finder's picture")
ns.UI.OpenVisit(thanes.id, G)

-- A kill the pull events missed, proven by its loot (MAP-16): a kill,
-- with no number, and the tooltip says how the diary knows.
local proven = Visit({ instanceID = 3065, name = "The Hall of Thanes", bossesKilled = { "Faldrim Anvilmar", "Magmatus" },
    inferred = { Magmatus = "loot" } })
ns.UI.OpenVisit(proven.id, G)
local byName = {}
for _, mark in ipairs(view.print.marks) do byName[mark.name] = mark end
Check(byName.Magmatus.killed and byName.Magmatus.inferred, "the proven kill is not a kill")
Eq(byName.Magmatus.order, nil, "the proven kill is numbered")
Eq(byName["Faldrim Anvilmar"].order, 1, "the kill the diary saw")
Eq(byName.Magmatus.face, "display", "the proven kill has no face")
Eq(view.print.pools.number.used, 1, "numbers for the kills")
local magTip
for i = 1, view.print.pools.hit.used do
    local tip = view.print.pools.hit[i].tip
    if tip[1][1] == "Magmatus" then magTip = tip end
end
Eq(magTip[2][1], "Killed on this run, going by its loot", "the proven kill's tooltip")
ns.UI.OpenVisit(proven.id, G)
-- An older run: only its notes prove it (the grips off Magmatus' table).
local older = Visit({ instanceID = 3065, name = "The Hall of Thanes", bossesKilled = {},
    loot = { { guid = ns.ownGUID, itemID = 270231, time = mock.now - 2000,
        item = "|cnIQ3:|Hitem:270231::::::::22:1491::::::::|h[Flamefist Grips]|h|r" } } })
ns.UI.OpenVisit(older.id, G)
byName = {}
for _, mark in ipairs(view.print.marks) do byName[mark.name] = mark end
Check(byName.Magmatus.killed and byName.Magmatus.inferred, "an older run's proven kill is not a kill")
ns.UI.OpenVisit(older.id, G)

--------------------------------------------------------------------------
Section("the run's notes: strips with arrows, and its deaths (MAP-13 to MAP-15)")

local Page = ns.UI.DungeonPage
local runNotes = ns.DungeonRun.Notes(RFK)
-- Chosen in order: the wipe, then the loot (for Tester, a diary entry, and
-- for the user), then the run back. Aggem's two tries are told by the wipe.
local chosen = Page.Choose(RFK, runNotes, G)
local kinds = {}
for i, note in ipairs(chosen) do kinds[i] = note.kind end
Eq(table.concat(kinds, ","), "wipe,loot,loot,ranBack", "the notes chosen, in order")
Eq(chosen[1].name, "Wiped once", "the wipe's words")
Eq(chosen[1].what, "killed on the second try", "under the wipe")
Eq(#chosen[2].items, 1, "Aggem's loot")
Eq(chosen[2].items[1].item, RFK.loot[1].item, "the first loot is not Thornspike")
Eq(chosen[2].name, ns.Style.Inkify(RFK.loot[1].item), "the item not in its quality's ink")
Eq(chosen[2].what, "dropped for Tester", "Tester's loot")
Eq(chosen[2].guid, nil, "on Tester's own page, Tester's loot opens their page")
Eq(chosen[3].what, "dropped for you", "the user's loot")
Eq(chosen[4].name, "Ran back once", "the run back")
Eq(chosen[4].what, "as a ghost", "under the run back")
-- On anyone else's page, Tester's name opens their page.
Eq(Page.Choose(RFK, runNotes, ns.ownGUID)[2].guid, G, "Tester's loot does not open their page")

ns.UI.OpenVisit(RFK.id, G)
local strips = view.noteStrips
Eq(#strips, 4, "the strips on Razorfen Kraul's print")
Eq(view.notesMore, 0, "notes counted that were shown")
local printBottom = view.print.origin[2] + view.print.size[2]
for i, a in ipairs(strips) do
    -- Each leader ends in its arrow just short of its mark.
    local t = a.note.door and view.print.targets.door or view.print.targets[a.note.boss.name]
    local tx, ty = view.print.origin[1] + t.x, view.print.origin[2] + t.y
    Eq(a.target[1], tx, "a leader does not go to its mark")
    Check(a.tip, "a strip without its arrow: " .. tostring(a.note.name))
    local d = math.sqrt((a.tip[1] - tx) ^ 2 + (a.tip[2] - ty) ^ 2)
    Check(math.abs(d - (t.r + Page.LEADER.gap)) < 0.01, "an arrow not at its mark's edge: " .. d)
    -- Under the print, and clear of one another.
    Check(a.box[2] >= printBottom, "a strip on the print")
    for j = i + 1, #strips do
        local b = strips[j].box
        Check(a.box[1] + a.box[3] <= b[1] or b[1] + b[3] <= a.box[1] or a.box[2] + a.box[4] <= b[2]
            or b[2] + b[4] <= a.box[2], "two strips overlap")
    end
end
Check(view.print.pools.leader.used > 0, "no leaders drawn")
-- A loot strip gives the item's own tooltip.
local loot
for i = 1, view.notes.used do
    if view.notes[i].note.kind == "loot" then loot = loot or view.notes[i] end
end
local link = loot.links[1]
Eq(loot.links.used, 1, "a hover per item named")
link.scripts.OnEnter(link)
Eq(GameTooltip.link, loot.note.items[1].item, "no item tooltip on a loot strip")
Check(GameTooltip.lines and GameTooltip.lines[1] and GameTooltip.lines[1][1]:find("^Dropped for "),
    "the item's tooltip does not say for whom")
link.scripts.OnLeave(link)

-- Deaths: the wipe's three in ink round Aggem, the user's on the way to
-- Jargba in pencil, with who died to what and where about.
local aggem = view.print.targets["Aggem Thorncurse"]
local atAggem, onTheWay = 0, nil
for _, c in ipairs(view.print.crosses) do
    local d = math.sqrt((c.x - aggem.x) ^ 2 + (c.y - aggem.y) ^ 2)
    if not c.pencil and math.abs(d - (aggem.r + Page.DEATH.ring)) < 0.01 then atAggem = atAggem + 1 end
    if c.pencil then onTheWay = c end
end
Eq(atAggem, 3, "the wipe's deaths are not crossed round Aggem")
Check(onTheWay, "no cross on the way to Jargba")
Eq(onTheWay.tip[1][1], "You died, probably to a Razorfen Defender", "the death on the way's tooltip")
Eq(onTheWay.tip[2][1], "On the way to Death Speaker Jargba", "where about it was")
local jargba = view.print.targets["Death Speaker Jargba"]
Check(math.sqrt((onTheWay.x - jargba.x) ^ 2 + (onTheWay.y - jargba.y) ^ 2) > jargba.r
    and math.sqrt((onTheWay.x - aggem.x) ^ 2 + (onTheWay.y - aggem.y) ^ 2) > aggem.r, "the death on the way is at a boss")
local brom
for _, c in ipairs(view.print.crosses) do
    if c.tip[1][1]:find("^Brom") then brom = c end
end
Eq(brom and brom.tip[1][1], "Brom died, probably to Aggem Thorncurse", "a wipe death's tooltip")
ns.UI.OpenVisit(RFK.id, G)

-- At most five strips; the rest counted, and a stranger's loot never a
-- strip, only counted in its boss's tooltip.
local STRANGER = "Player-4620-00EEEEEE"
local pulls = {}
for i, name in ipairs({ "Roogug", "Aggem Thorncurse", "Death Speaker Jargba", "Overlord Ramtusk",
    "Agathelos the Raging", "Charlga Razorflank" }) do
    local at = mock.now - 3000 + i * 200
    pulls[#pulls + 1] = { name = name, start = at, stop = at + 30 }
    if i <= 4 then pulls[#pulls + 1] = { name = name, start = at + 60, stop = at + 90, killed = true } end
    if i > 4 then pulls[#pulls + 1] = { name = name, start = at + 60, stop = at + 90 } end
end
local busy = Visit({ instanceID = 47, name = "Razorfen Kraul",
    bossesKilled = { "Roogug", "Aggem Thorncurse", "Death Speaker Jargba", "Overlord Ramtusk" }, pulls = pulls,
    spans = { { from = mock.now - 3000, to = mock.now - 2500, ghost = true }, { from = mock.now - 2400, to = mock.now - 1200 } },
    loot = { { guid = STRANGER, item = "|cnIQ2:|Hitem:6686::::::::22:1491::::::::|h[Tusken Helm]|h|r", itemID = 6686,
        time = mock.now - 3000 + 4 * 200 + 100 } } })
Eq(#Page.Choose(busy, ns.DungeonRun.Notes(busy), G), 7, "six tries and the run back")
local busyNotes = Page.Choose(busy, ns.DungeonRun.Notes(busy), G)
Eq(busyNotes[1].name, "Killed on the second try", "a kill's tries without a wipe")
Eq(busyNotes[1].what, nil, "under a kill's tries")
Eq(busyNotes[5].name, "Tried twice", "a boss still standing")
Eq(busyNotes[5].what, "left standing", "under a boss still standing")
local Words = Page.Words
Eq(Words.Wipes(3), "Wiped three times", "wipes in words")
Eq(Words.Wipes(11), "Wiped 11 times", "wipes past ten")
Eq(Words.Facts(busy, { wipes = 2, tries = 2 })[2], nil, "a standing boss's tries told twice")
Eq(Words.Death(busy, { guid = ns.ownGUID, killer = { environment = "FALLING" } }), "You died (falling)",
    "a fall's words")
ns.UI.OpenVisit(busy.id, G)
Eq(#view.noteStrips, Page.NOTES.most, "more strips than the page takes")
-- Everything still on the page.
local lowest = 0
for _, a in ipairs(view.noteStrips) do lowest = math.max(lowest, a.box[2] + a.box[4]) end
Check(lowest <= view.h, "the strips run off the page: " .. lowest)
Eq(view.notesMore, 2, "the notes left off are not counted")
Check(view.more:IsShown() and view.more:GetText() == "and 2 more", "no count of the rest: " .. tostring(view.more:GetText()))
for _, a in ipairs(view.noteStrips) do
    Check(a.note.kind ~= "loot", "a stranger's loot is a strip")
end
local ramtuskTip
for i = 1, view.print.pools.hit.used do
    local tip = view.print.pools.hit[i].tip
    if tip[1][1] == "Overlord Ramtusk" then ramtuskTip = tip end
end
Eq(ramtuskTip[#ramtuskTip][1], "One item for someone else", "a stranger's loot is not counted")
ns.UI.OpenVisit(busy.id, G)

--------------------------------------------------------------------------
Section("kills by id under the game's own names, merged loot, a wipe on the way")

-- The game says "Infurnus" for the boss the data calls Magmatus (id 3495).
-- Garrick is in the diary; Pell, Odo and the stranger are not.
local F = T.F
mock.SetUnit("target", F.GARRICK)
ns.Diary.Add(F.GARRICK.guid, { unit = "target" })
local PELL, ODO, STRANGER2 = "Player-4620-00F1F1F1", "Player-4620-00F2F2F2", "Player-4620-00F3F3F3"
local t0 = mock.now - 4000
local function At(m) return t0 + m * 60 end
local function Link(id, name, q) return ("|cnIQ%d:|Hitem:%d::::::::22:1491::::::::|h[%s]|h|r"):format(q, id, name) end
local hall = ns.Instances.New({
    instanceID = 3065, name = "The Hall of Thanes", instanceType = "party", startedAt = At(0), endedAt = At(50),
    members = { { guid = G, first = "Tester" }, { guid = ns.ownGUID, first = "Me" },
        { guid = F.GARRICK.guid, first = "Garrick" }, { guid = PELL, first = "Pell" }, { guid = ODO, first = "Odo" } },
    bossesKilled = { "Faldrim Anvilmar", "Infurnus", "Plunder", "Durgen Dirgehammer" },
    pulls = {
        { id = 3493, name = "Faldrim Anvilmar", start = At(5), stop = At(7), killed = true },
        { id = 3495, name = "Infurnus", start = At(12), stop = At(14), killed = true },
        { id = 3494, name = "Plunder", start = At(25), stop = At(27), killed = true },
        { id = 3496, name = "Durgen Dirgehammer", start = At(33), stop = At(35) },
        { id = 3496, name = "Durgen Dirgehammer", start = At(40), stop = At(42), killed = true },
    },
    deathLog = {
        -- Three of five to trash on the way to Plunder: a wipe on the way.
        { guid = PELL, time = At(18), killer = { name = "Dark Iron Looter" } },
        { guid = ODO, time = At(18) + 10, killer = { name = "Dark Iron Looter" } },
        { guid = ns.ownGUID, time = At(18) + 20, killer = { name = "Dark Iron Looter" } },
        -- And three in Durgen's first pull.
        { guid = PELL, time = At(34), pull = 4, killer = { name = "Durgen Dirgehammer" } },
        { guid = ODO, time = At(34) + 5, pull = 4, killer = { name = "Durgen Dirgehammer" } },
        { guid = G, time = At(34) + 9, pull = 4, killer = { name = "Durgen Dirgehammer" } },
    },
    loot = {
        { guid = STRANGER2, item = Link(270227, "Drape of the Test", 3), itemID = 270227, time = At(7) + 10 },
        { guid = F.GARRICK.guid, item = Link(270231, "Grips of the Test", 3), itemID = 270231, time = At(14) + 10 },
        { guid = ns.ownGUID, item = Link(270230, "Girdle of the Test", 3), itemID = 270230, time = At(14) + 20 },
        { guid = G, item = Link(271098, "Chest of the Test", 3), itemID = 271098, time = At(27) + 10 },
        { guid = ns.ownGUID, item = Link(270256, "Axe of the Test", 4), itemID = 270256, time = At(42) + 10 },
    },
    spans = { { from = At(0), to = At(19), ghost = true }, { from = At(21), to = At(35), ghost = true },
        { from = At(37), to = At(50) } },
})
local hallNotes = ns.DungeonRun.Notes(hall)
local hallChosen = Page.Choose(hall, hallNotes, G)
kinds = {}
for i, note in ipairs(hallChosen) do kinds[i] = note.kind end
Eq(table.concat(kinds, ","), "wayWipe,wipe,loot,loot,loot,ranBack", "the Hall's notes, in order")
Eq(hallChosen[1].name, "Wiped on the way", "the wipe on the way's words")
Eq(hallChosen[1].what, "to a Dark Iron Looter", "what the wipe on the way was to")
-- Each kind of killer once, in the order they killed; no plural guessed.
local function WayWipe(...)
    local deaths = {}
    for i, name in ipairs({ ... }) do deaths[i] = { killer = name ~= "" and { name = name } or nil } end
    return Page.Words.WipedTo(hall, { deaths = deaths })
end
Eq(WayWipe("Dark Iron Looter", "Anvilrage Guardsman", "Dark Iron Looter"),
    "to a Dark Iron Looter and an Anvilrage Guardsman", "a wipe to two kinds")
Eq(WayWipe("Dark Iron Looter", "Anvilrage Guardsman", "Ironforge Thug"),
    "to a Dark Iron Looter and others", "a wipe to three kinds")
Eq(WayWipe(""), nil, "a wipe no death names a killer for")
-- Magmatus' two items on one strip, each its own piece of the heading.
local merged = hallChosen[3]
Eq(merged.boss.name, "Magmatus", "the first loot is not Magmatus'")
Eq(#merged.items, 2, "Magmatus' loot is not on one strip")
Eq(merged.name, ns.Style.Inkify(hall.loot[2].item) .. " and " .. ns.Style.Inkify(hall.loot[3].item),
    "the merged heading")
Eq(merged.items[2].from, ns.Style.Inkify(hall.loot[2].item) .. " and ", "where the second item starts")
Eq(merged.what, "dropped for Garrick and you", "for whom")
Eq(merged.guid, F.GARRICK.guid, "Garrick's name does not open his page")
Eq(merged.items[1].guid, F.GARRICK.guid, "Garrick's item does not open his page")
Eq(merged.items[2].guid, nil, "the user's item opens a page")
Eq(hallChosen[4].what, "dropped for Tester", "Plunder's chest for the page's person")
Eq(hallChosen[4].guid, nil, "on Tester's own page, Tester's name opens it")
for _, note in ipairs(hallChosen) do
    if note.kind == "loot" then
        for _, it in ipairs(note.items) do Check(it.item ~= hall.loot[1].item, "a stranger's loot is a strip") end
    end
end

ns.UI.OpenVisit(hall.id, G)
-- Kills by id: "Infurnus" marks Magmatus killed, numbered in the order the
-- notes give, and the page calls it what the game did.
byName = {}
for _, mark in ipairs(view.print.marks) do byName[mark.name] = mark end
Check(byName.Magmatus.killed and not byName.Magmatus.inferred, "Infurnus did not kill Magmatus")
Eq(byName.Magmatus.order, 2, "Magmatus is not the second to fall")
Eq(byName["Durgen Dirgehammer"].order, 4, "Durgen is not the fourth")
local titles = {}
for i = 1, view.print.pools.hit.used do titles[view.print.pools.hit[i].tip[1][1]] = true end
Check(titles.Infurnus and not titles.Magmatus, "the tooltip does not use the game's name")
Eq(Page.Wing(hall), D.WingOf(3065, "Faldrim Anvilmar"), "the wing from the first kill by id")
-- Five strips of six; the run back is counted.
Eq(#view.noteStrips, 5, "the Hall's strips")
Eq(view.notesMore, 1, "the Hall's notes left off")
Eq(view.more:GetText(), "and 1 more", "the count of the rest")
local wayStrip
for _, a in ipairs(view.noteStrips) do
    if a.note.kind == "wayWipe" then wayStrip = a end
end
Check(wayStrip and wayStrip.tip, "the wipe on the way has no arrow")
local wt = view.print.targets["wipe:1"]
Eq(wayStrip.target[1], view.print.origin[1] + wt.x, "the wipe on the way's arrow is not at its place")
-- One hover per item named on the merged strip.
local mergedSlot
for i = 1, view.notes.used do
    local n = view.notes[i].note
    if n.kind == "loot" and n.boss.name == "Magmatus" then mergedSlot = view.notes[i] end
end
Eq(mergedSlot.links.used, 2, "a hover per item on the merged strip")
Check(mergedSlot.links[2].recorded.points[1].args[3] > mergedSlot.links[1].recorded.points[1].args[3],
    "the second item's hover is not after the first's")
mergedSlot.links[1].scripts.OnEnter(mergedSlot.links[1])
Eq(GameTooltip.link, hall.loot[2].item, "the first item's tooltip")
Eq(GameTooltip.lines[1][1], "Dropped for Garrick", "for whom the first item dropped")
mergedSlot.links[1].scripts.OnLeave(mergedSlot.links[1])
ns.UI.OpenVisit(hall.id, G)

--------------------------------------------------------------------------
Section("a dungeon the diary has no map of (MAP-7)")

local vault = Visit({ instanceID = 999999, name = "The Test Vault", bossesKilled = { "Nobody" } })
Eq(ns.UI.OpenVisit(vault.id, G), true, "an unknown dungeon did not open")
Check(view.none:IsShown(), "no word for a dungeon without a map")
Eq(view.none.text:GetText(), "The diary has no map of The Test Vault yet.", "the words without a map")
Check(not view.print:IsShown(), "a print without a map")
Check(view.head:IsShown(), "no card at the head without a map")
ns.UI.OpenVisit(vault.id, G)
Check(TL:IsShown(), "no way back from a dungeon without a map")

--------------------------------------------------------------------------
Section("the canvas draws every kind of art")

local Map = ns.UI.DungeonMap
local c = Map.New(UIParent)
local yards = D.Floor(3065, 930651)
c:Draw(yards, 200, 200 * yards.h / yards.w)
Eq(c.tiles.used, #yards.tiles, "Forever's tiles in yards")
local w, h = Map.Fit(yards, 300, 300)
Check(math.abs(w / h - yards.w / yards.h) < 1e-9 and h <= 300 and w <= 300, "a floor fitted out of shape")
Eq(c:Place(930651, 0.5, 0.25), 100, "a point on the floor drawn")
Eq(c:Place(301, 0.5, 0.5), nil, "a point on another floor is placed")
-- A combined map: crops of the floors, feathered.
local combined = { uiMapID = 900047, combined = true, instanceID = 47, w = 400, h = 300,
    data = { pieces = { { floor = 301, x0 = 0, y0 = 0, x1 = 500, y1 = 400, dx = 0, dy = 0, s = 0.5 } } } }
c:Draw(combined, 400, 300)
Check(c.masked[1] and c.masked[1].used > 0, "a combined map's piece is not drawn")
Eq(c.masked[1][1].recorded.calls.AddMaskTexture[1], c.masks[1], "a piece's tile is not feathered")
c:Draw(nil, 10, 10)
Eq(c.tiles.used, 0, "tiles left on an empty canvas")

SlashCmdList.SOCIALDIARY("testdata remove")
ns.UI.CloseJournal()
