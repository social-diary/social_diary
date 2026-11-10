-- The killer card on Your Diary's plates (Features/Deaths/Card.lua; option A, "Cut
-- in ink", of .claude/ui-proposal/killer-models-proposal.md): which deaths
-- get one, which killer a plate shows, the ladder its picture walks down
-- (ink silhouette, 2D print, name alone), its place after the people in
-- the margin, its leader to the death cross, and the words when it is left
-- off. The model's look is for the client: here its calls are recorded.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()
local SELF = F.SELF
local Card = ns.Deaths.Card
local Text = ns.UI.JourneyText

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)

local function Any(list, pattern)
    for _, text in ipairs(list) do
        if text:find(pattern) then return true end
    end
    return false
end

--------------------------------------------------------------------------
Section("which killer a plate shows")

local function Cross(x, y, from, to, count)
    return { x = x, y = y, segs = { { from = from, to = to } }, count = count or 1 }
end
local function Death(t, name, extra)
    local d = { t = t, npcID = name and (#name * 7) or nil, name = name, display = name and 500 + #name or nil }
    for key, value in pairs(extra or {}) do d[key] = value end
    return d
end

-- Most deaths wins; the others are in the cross's tooltip.
local crosses = { Cross(10, 10, 100, 200), Cross(80, 40, 300, 400) }
Card.Match(crosses, { Death(120, "Sunscale Lashtail"), Death(150, "Sunscale Lashtail"), Death(320, "Kolkar Stormer") },
    1412)
Eq(#crosses[1].deaths, 2, "the deaths in a stop's time are not its cross's")
Eq(#crosses[2].deaths, 1, "the death on the road is not its cross's")
local k = Card.Choose(crosses)
Eq(k.name, "Sunscale Lashtail", "the killer that got you most is not the card")
Eq(k.count, 2, "the card's count")
Check(k.cross == crosses[1], "the card's leader does not go to where it got you")
Eq(k.display, 500 + #"Sunscale Lashtail", "the card has no display")

-- A tie goes to the latest.
Card.Match(crosses, { Death(120, "Sunscale Lashtail"), Death(320, "Kolkar Stormer") }, 1412)
Eq(Card.Choose(crosses).name, "Kolkar Stormer", "a tie does not go to the latest")

-- A rare or an elite outranks any number of common kills (Q6), the higher
-- rank first.
Card.Match(crosses, { Death(110, "Sunscale Lashtail"), Death(120, "Sunscale Lashtail"), Death(130, "Sunscale Lashtail"),
    Death(320, "Kolkar Stormer", { rank = "elite" }) }, 1412)
Eq(Card.Choose(crosses).name, "Kolkar Stormer", "an elite does not outrank three common kills")
Eq(Card.Choose(crosses).rank, "elite", "the card does not keep the rank")
Card.Match(crosses, { Death(110, "Mottled Boar", { rank = "rare" }), Death(320, "Kolkar Stormer", { rank = "elite" }),
    Death(330, "Kolkar Stormer", { rank = "elite" }) }, 1412)
Eq(Card.Choose(crosses).name, "Mottled Boar", "a rare does not outrank an elite")

-- Falls and players get no card; nor do deaths kept before killers were.
Card.Match(crosses, { Death(120, nil, { environment = "FALLING" }), Death(320) }, 1412)
Eq(#crosses[1].deaths + #crosses[2].deaths, 2, "a fall or a player's death is not on its cross")
Check(Card.Choose(crosses) == nil, "a fall or a player's death has a card")
Card.Match(crosses, {}, 1412)
Check(Card.Choose(crosses) == nil, "a cross with no kept death has a card")

-- Another map's death is not this plate's; a death placed on the map in no
-- stop's time goes to the nearest cross close by, within the entry.
Card.Match(crosses, { Death(120, "Sunscale Lashtail", { mapID = 1413 }) }, 1412)
Eq(#crosses[1].deaths, 0, "another map's death is on this plate")
local function Place(d) return d.x, d.y end
Card.Match(crosses, { Death(250, "Sunscale Lashtail", { mapID = 1412, x = 78, y = 44 }) }, 1412, Place,
    { from = 0, to = 1000 })
Eq(#crosses[2].deaths, 1, "a death by its spot does not go to the nearest cross")
Card.Match(crosses, { Death(250, "Sunscale Lashtail", { mapID = 1412, x = 200, y = 200 }) }, 1412, Place,
    { from = 0, to = 1000 })
Eq(#crosses[1].deaths + #crosses[2].deaths, 0, "a death far from any cross is put on one")
-- The probable guess is the card's only while none was confirmed.
Card.Match(crosses, { Death(120, "Sunscale Lashtail", { probable = true }), Death(150, "Sunscale Lashtail") }, 1412)
Check(not Card.Choose(crosses).probable, "a confirmed death is called a guess")

--------------------------------------------------------------------------
Section("the card's words")

Eq(ns.Deaths.Killed(1), "killed\194\160you", "one death")
Eq(ns.Deaths.Killed(2), "killed\194\160you\194\160twice", "two deaths")
Eq(ns.Deaths.Killed(3), "killed\194\160you\194\160three\194\160times", "three deaths")
Eq(Text.KillerName({ name = "Sunscale Lashtail" }), "a Sunscale Lashtail", "a common creature's article")
Eq(Text.KillerName({ name = "Ornery Plainstrider" }), "an Ornery Plainstrider", "an article before a vowel")
Eq(Text.KillerName({ name = "Hogger", rank = "rare" }), "Hogger", "a rare is named bare")
Eq(Text.KillerName({ name = "The Rake" }), "The Rake", "a name with its own article")
local title, lines = ns.Deaths.DeathCross(3, { Death(1, "Sunscale Lashtail", { spell = "Bite" }),
    Death(2, "Sunscale Lashtail", { spell = "Bite" }), Death(3, nil, { environment = "FALLING" }) })
Eq(title, "Died here 3 times", "a cross's tooltip title")
Eq(lines[1], "Sunscale Lashtail, with Bite, twice", "a cross's killer line")
Eq(lines[2], "A fall", "a fall in a cross's tooltip")
-- When and at what level, once for them all (Deaths.Foot): a span, a range.
title, lines = ns.Deaths.DeathCross(2, { Death(now - 3600, "Sunscale Lashtail", { level = 19 }),
    Death(now - 1800, "Sunscale Lashtail", { level = 20 }) }, now)
Eq(#lines, 2, "one killer line and the foot")
Eq(lines[2], date("Today from %H:%M", now - 3600) .. date(" to %H:%M", now - 1800) .. ", levels 19 to 20",
    "the deaths' span and levels")
title, lines = ns.Deaths.DeathCross(1, { Death(now - 3600, "Sunscale Lashtail", { level = 19 }) }, now)
Eq(title, "Died here", "a lone death")
Eq(table.concat(lines, "|"), "Sunscale Lashtail|" .. date("Today at %H:%M", now - 3600) .. ", level 19",
    "a lone death: its killer, then when, each once")
-- The one that killed you most first, at most three lines of them.
title, lines = ns.Deaths.DeathCross(6, { Death(1, "Kolkar Stormer"), Death(2, "Sunscale Lashtail"),
    Death(3, "Sunscale Lashtail"), Death(4, "Hecklefang Hyena"), Death(5, nil, { environment = "FALLING" }),
    Death(6, "Razormane Hunter") })
Eq(title, "Died here 6 times", "all of them counted")
Eq(lines[1], "Sunscale Lashtail, twice", "the most first")
Eq(lines[2], "Kolkar Stormer", "then in the order they did")
Eq(lines[3], "And others", "the rest not counted")
Eq(#lines, 4, "three and the foot")
Eq(ns.Deaths.Foot({}, now), nil, "no time, no level: no foot")
Eq(ns.Deaths.Foot({ { level = 12 } }, now), "Level 12", "a level alone")
-- Across midnight, both ends, as the core's foot says them (Text.Foot).
Eq(ns.Deaths.Foot({ { t = now - DAY }, { t = now } }, now),
    date("From yesterday at %H:%M", now - DAY) .. date(" to today at %H:%M", now), "over two days: both ends")
Eq(Text.PlateCaption({ moments = { { kind = "level", level = 12 }, { kind = "death" }, { kind = "death" } } }, nil,
    { death = "a Sunscale Lashtail" }), "Two deaths, to a Sunscale Lashtail.", "the caption with a left-off card")

--------------------------------------------------------------------------
Section("the card on the plate")

ns.UI.ShowJournal()
local page = ns.UI.JourneyPage()
local t0 = now - 2 * DAY
ns.db.journey[SELF.guid] = nil
local j = ns.Journey.Begin(SELF.guid, t0, 10, 1412)
local function Seg(seg)
    j.segments[#j.segments + 1] = seg
    return seg
end
Seg({ kind = "stop", from = t0, to = t0 + 1800, mapID = 1412, x = 0.40, y = 0.60, r = 50, seconds = 1800,
    act = { combat = 900, deaths = 2 }, subZone = "Red Rocks", levelFrom = 10, levelTo = 10 })
Seg({ kind = "road", from = t0 + 1800, to = t0 + 2400, mapID = 1412, levelFrom = 10, levelTo = 10, act = { deaths = 1 },
    pts = { 0.40, 0.60, 0.45, 0.55, 0.50, 0.50, 0.55, 0.52, 0.60, 0.45 } })
Seg({ kind = "stop", from = t0 + 2400, to = t0 + 4200, mapID = 1412, x = 0.60, y = 0.45, r = 30, seconds = 1800,
    act = { resting = 1500 }, subZone = "Bloodhoof Village", levelFrom = 10, levelTo = 11 })
j.levels[11] = { at = t0 + 4000, mapID = 1412, x = 0.60, y = 0.45 }
Seg({ kind = "stop", from = t0 + 5000, to = t0 + 6000, mapID = 1412, x = 0.62, y = 0.44, r = 20, seconds = 1000,
    levelFrom = 11, levelTo = 11 })
local LASHTAIL = { t = t0 + 600, mapID = 1412, x = 0.40, y = 0.60, npcID = 3255, name = "Sunscale Lashtail",
    spell = "Bite", display = 1234 }
local STORMER = { t = t0 + 2100, mapID = 1412, x = 0.50, y = 0.50, npcID = 3263, name = "Kolkar Stormer",
    spell = "Lightning Bolt", display = 2000 }
j.deaths = { LASHTAIL, { t = t0 + 1200, mapID = 1412, x = 0.40, y = 0.60, npcID = 3255, name = "Sunscale Lashtail",
    spell = "Bite", display = 1234 }, STORMER }
ns.Journey.Touch()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")

local function Open(level)
    for i, e in ipairs(page.recap.entries) do
        if e.level == level then
            page.entries:SetOffset(page.rubrics[i] - 1)
            for _, row in ipairs(page.entries.rows) do
                if row:IsShown() and row.item and row.item.title and row.item.entry == i then row:Click() end
            end
            return e
        end
    end
end

-- The shown cards, and the plates' hover squares' tooltips.
local function Cards()
    local list = {}
    for i = 1, page.killerPool.used do
        if page.killerPool[i]:IsShown() then list[#list + 1] = page.killerPool[i] end
    end
    return list
end
local function Tips(plate)
    local said = {}
    for i = 1, plate.hover.used do
        local list = plate.hover[i].tip and plate.hover[i].tip()
        if list then
            local parts = {}
            for _, line in ipairs(list) do parts[#parts + 1] = line[1] end
            said[#said + 1] = table.concat(parts, "|")
        end
    end
    return said
end

Open(10)
local plate = page.plates[1]
Eq(page.layout, 1, "level 10 is not one plate")
Eq(#plate.crosses, 2, "the stop's and the road's death crosses")
local cards = Cards()
Eq(#cards, 1, "one killer card on the plate")
Eq(page.killersWritten, 1, "the page's count of cards")
local card = cards[1]
Eq(card.name:GetText(), "Sunscale Lashtail", "the card is not the killer that got you most")
Eq(card:What(), "killed\194\160you\194\160twice", "the card's deed")
Eq(card.mode, "ink", "the card is not cut in ink")
-- The name in INK_STRONG, in the hand; the deed in ink.
local S = ns.Style.INK_STRONG
Eq(card.name.recorded.calls.SetTextColor[1], S[1], "the name is not in strong ink")
Eq(card.lines[1].recorded.calls.SetTextColor[1], ns.Style.INK[1], "the deed is not in ink")

-- The model: the strip's child, never in a plate's clipping frame, drawn
-- from the display, in profile, still, its lights out (black).
local model = card.model
Check(model and model.frameType == "PlayerModel" and model.parent == card, "the card's model is not its own child")
Check(model:IsShown(), "the model is not shown")
Eq(model:GetFrameLevel(), card:GetFrameLevel() + 1, "the model is not a level over the slip")
Eq(model.model.SetDisplayInfo[1], 1234, "the model is not drawn from the kept display")
-- Framed whole on its own camera (KILLER.frame "body"), the model turned.
Eq(model.model.SetPortraitZoom[1], 0, "the model is not on its own camera")
Eq(model.model.SetCamDistanceScale[1], Card.KILLER.distance, "the body framing's camera distance")
Eq(model.model.SetViewTranslation[1] .. "," .. model.model.SetViewTranslation[2], "0,0", "the body framing moves the view")
Check(math.abs(math.abs(model.model.SetFacing[1]) - math.pi / 2) < 1e-9, "the model is not in profile")
Eq(model.model.FreezeAnimation[1], 0, "the model is not held still")
Check(model.model.SetLight[1] == true and model.model.SetLight[2].ambientIntensity == 0
    and model.model.SetLight[2].diffuseIntensity == 0, "the model's lights are not out")
Check(model.model.SetFogColor == nil, "the model is fogged (fog does nothing in the client)")
local mark = plate.killer.mark
local left = mark[1] < card.box[1] + card.box[3] / 2
Eq(model.model.SetFacing[1], left and Card.KILLER.face.left or Card.KILLER.face.right, "the model does not face its cross")
-- Placed at the picture's room, its size.
local pic = card.picture
Eq(model.recorded.width, 70, "the model's width")
local anchor = model.recorded.points[1].args
Check(anchor[1] == card and math.abs(anchor[3] - pic.X) < 1e-9 and math.abs(anchor[4] - pic.Y) < 1e-9,
    "the model is not at the picture's room")

-- The picture over the name; the tape clear of it; the slip turned little.
Check(pic.y + pic.h / 2 <= card.box[2] + card.box[4], "the picture is off the slip")
Check(card.tapeRect[1] >= pic.x + pic.w / 2, "the tape lies on the picture")
Check(math.abs(math.deg(card.turn)) <= Card.KILLER.turn + 1e-9, "the card turns more than a model can be forgiven")

-- After the people: no one is on this plate, so it is the margin's first;
-- its leader goes to the cross where it got you, from the card.
local link
for _, l in ipairs(page.links) do if l.strip == card then link = l end end
Check(link and link.mark == mark, "the card has no leader to its cross")
Check(link.dot:IsShown(), "the card's leader has no end")
local cross = plate.killer.cross
Check(cross.deaths[1] == LASHTAIL, "the card's cross is not where the Lashtail got you")

-- Under the mouse: its tooltip; the crosses tell their killers.
GameTooltip.text = nil
card.link.scripts.OnEnter(card.link)
Eq(GameTooltip.text, "Sunscale Lashtail", "the card has no tooltip")
card.link.scripts.OnLeave(card.link)
Eq(card.lift, 0, "the card lifts like a person's strip, but opens nothing")
local tips = Tips(plate)
Check(Any(tips, "^Died here twice|Sunscale Lashtail, with Bite, twice|[^|]* from %d+:%d+ to %d+:%d+, level 10$"),
    "the stop's cross, its deaths' span and level once: " .. table.concat(tips, "; "))
Check(Any(tips, "^Died here|Kolkar Stormer, with Lightning Bolt|[^|]* at %d+:%d+, level 10$"),
    "the road's cross: " .. table.concat(tips, "; "))
-- The caption still counts the deaths, and names no killer the card names.
local caption = page.captionPool[1]:GetText()
Check(caption:find("deaths%.$") and not caption:find("Lashtail"), "the caption: " .. caption)

-- An elite on the road outranks the two common deaths at the stop.
STORMER.rank = "elite"
ns.UI.RedrawJourneyPage()
Eq(Cards()[1].name:GetText(), "Kolkar Stormer", "an elite does not outrank the most kills on the plate")
Eq(Cards()[1]:What(), "killed\194\160you", "the elite's deed")
STORMER.rank = nil

-- Head and shoulders (KILLER.frame "head"), cropped from the whole on the
-- model's own camera: the camera closer, the view moved down and away
-- from the way it faces, by shares of the window.
Card.KILLER.frame = "head"
local head = Card.New(page.right)
head:SetKiller({ name = "Murloc Streamrunner", count = 1, display = 527, mark = { 0, 0 } }, "h", now)
head:Layout(300, 10, 150)
local hm, H = head.model, Card.KILLER.head
Eq(head.facing, Card.KILLER.face.left, "the card does not face its cross on the left")
Eq(hm.model.SetPortraitZoom[1], 0, "head and shoulders is not cropped from the model's own camera")
Eq(hm.model.SetCamDistanceScale[1], H.distance, "head and shoulders is not closer")
Check(math.abs(hm.model.SetViewTranslation[1] - H.shift[1] * 70) < 1e-9
    and math.abs(hm.model.SetViewTranslation[2] + H.shift[2] * 48) < 1e-9, "the view is not moved to the head")
-- Where the view cannot be moved: the body framing.
mock.modelLacks = { SetViewTranslation = true }
local headless = Card.New(page.right)
headless:SetKiller({ name = "Murloc Streamrunner", count = 1, display = 527, mark = { 0, 0 } }, "h", now)
headless:Layout(300, 10, 150)
Eq(headless.model.model.SetCamDistanceScale[1], Card.KILLER.distance, "with no view to move, head is not body")
mock.modelLacks = nil
Card.KILLER.frame = "body"
head:Hide()
headless:Hide()

-- The model found nothing to draw (P8): the print, in the same room.
mock.blankDisplays = { [1234] = true }
ns.UI.RedrawJourneyPage()
card = Cards()[1]
Eq(card.mode, "ink", "the card gave up before the model could load")
mock.RunTimers()
Eq(card.mode, "print", "a model that drew nothing does not give way to the print")
Check(not card.model:IsShown() and card.print:IsShown(), "the print does not replace the model")
Eq(card.print.portrait, 1234, "the print is not the creature's portrait")
Check(card.print.recorded.calls.SetDesaturated[1] == true, "the print is not desaturated")
Eq(card.print.recorded.calls.SetTexCoord[1], 0, "the print is not cropped to its window")
mock.blankDisplays = nil
-- And it is not waited on again: drawn again, the print from the start.
ns.UI.RedrawJourneyPage()
Eq(Cards()[1].mode, "print", "a display that drew nothing is tried again")

-- Put away before its model could load (another level opened at once):
-- no verdict, and it stays put away, not laid again on the page open now
-- (11 Oct, in the client: level 8's close call lay on level 7 as a print).
do
    local early = Card.New(page.right)
    early:SetKiller({ name = "Murloc Forager", count = 1, display = 4321, mark = { 0, 0 } }, "e", now)
    early:Layout(300, 10, 150)
    Eq(early.mode, "ink", "setup: the card is not the silhouette")
    mock.blankDisplays = { [4321] = true }
    early:Hide()
    mock.RunTimers()
    Check(not early:IsShown(), "a card put away before its model loaded was shown again")
    Eq(early.mode, "ink", "a card put away before its model loaded was given up for the print")
    mock.blankDisplays = nil
    early:SetKiller({ name = "Murloc Forager", count = 1, display = 4321, mark = { 0, 0 } }, "e", now)
    Eq(early.mode, "ink", "a display not yet loaded was taken for one that draws nothing")
    early:Layout(300, 10, 150)
    Eq(early.shownDisplay, 4321, "shown again, the model is not given its display again")
    mock.RunTimers()
    Eq(early.mode, "ink", "shown again and loaded, the card did not keep its silhouette")
    early:Hide()
end

--------------------------------------------------------------------------
Section("the ladder: print, name alone, and left off")

-- A client whose lights cannot be put out: the print, from the start.
mock.modelLacks = { SetLight = true }
local fogless = Card.New(page.right)
fogless:SetKiller({ name = "Mottled Boar", count = 1, display = 77, mark = { 0, 0 } }, "x", now)
Eq(fogless.mode, "print", "a model whose lights stay on is not the print")
fogless:Layout(10, 10, 150)
Check(fogless.print:IsShown() and fogless.printEdge:IsShown(), "the print is not drawn")
Check(not fogless.model:IsShown(), "the model shows in colour")
mock.modelLacks = nil

-- Nor the print: the name alone, with no room kept for a picture.
local portrait = _G.SetPortraitTextureFromCreatureDisplayID
_G.SetPortraitTextureFromCreatureDisplayID = nil
mock.modelLacks = { FreezeAnimation = true, SetPaused = true }
local bare = Card.New(page.right)
bare:SetKiller({ name = "Mottled Boar", count = 1, display = 77, mark = { 0, 0 } }, "x", now)
Eq(bare.mode, "name", "with neither the ink nor the print, the card is not its name alone")
bare:Layout(10, 10, 150)
Check(bare.picture == nil and not bare.print:IsShown(), "a name-only card keeps room for a picture")
_G.SetPortraitTextureFromCreatureDisplayID = portrait
mock.modelLacks = nil

-- No display kept: the name alone, and no model is made for it.
local plain = Card.New(page.right)
plain:SetKiller({ name = "Mottled Boar", count = 1, mark = { 0, 0 } }, "x", now)
Eq(plain.mode, "name", "a killer with no display has a picture")
local _, hPlain = plain:Layout(10, 10, 150)
Check(plain.model == nil, "a model was made for a card with no picture")
Eq(plain.name:GetText(), "Mottled Boar", "the name is not written")
-- With a picture the card is the picture's height taller.
local inked = Card.New(page.right)
inked:SetKiller({ name = "Mottled Boar", count = 1, display = 77, mark = { 0, 0 } }, "x", now)
local wInk, hInk = inked:Layout(10, 10, 150)
Eq(hInk - hPlain, Card.KILLER.picture.h + Card.KILLER.picture.gap, "the picture's room")
Check(wInk >= Card.KILLER.picture.w + 15, "the card is narrower than its picture")
-- In a narrow column (the two-plate layout's), the smaller picture; the
-- tape still clear of it.
inked:Layout(10, 10, 122)
Eq(inked.picture.w .. "x" .. inked.picture.h, "62x42", "the narrow column's picture")
Check(inked.tapeRect[1] >= inked.picture.x + inked.picture.w / 2, "the tape lies on the narrow picture")
-- Laid flat: straight.
ns.SetSetting("flatSheets", true)
inked:Layout(10, 10, 150)
Eq(inked.turn, 0, "a card laid flat is turned")
ns.SetSetting("flatSheets", false)

-- No room in the margin: the card is left off and the caption names the
-- killer instead (nothing is only in the picture).
local C = ns.UI.JourneyLook.CAPTION
local limit, offLimit = C.limit, C.offLimit
C.limit, C.offLimit = 380, 380
ns.UI.RedrawJourneyPage()
Eq(#Cards(), 0, "the card is drawn with no room for it")
Eq(page.killersWritten, 0, "a card left off is counted")
caption = page.captionPool[1]:GetText()
Check(caption:find("deaths, to a Sunscale Lashtail%.$"), "the caption does not name the left-off killer: " .. caption)
C.limit, C.offLimit = limit, offLimit
ns.UI.RedrawJourneyPage()
Eq(#Cards(), 1, "the card does not come back with room for it")

-- The models: one a card, the page's six cards at most (a killer's and a
-- close call's a plate); drawing again makes none.
local before = page.killerPool[1].model
for _ = 1, 3 do ns.UI.RedrawJourneyPage() end
Check(page.killerPool[1].model == before and #page.killerPool <= 6, "drawing again makes new cards or models")
Open(11)
Eq(#Cards(), 0, "a level with no deaths has a card")
Check(not before:IsVisible() or not page.killerPool[1]:IsShown(), "a put-away card's model still shows")

--------------------------------------------------------------------------
Section("the margin by importance, and the words above it")

-- On level 10's plate now: Bram, grouped with you (did something together),
-- and Numa, only first seen there and put in the diary later (a first
-- sighting in hindsight). The margin gives room to Bram, then the killer,
-- then Numa (11 Oct, in the client: two first sightings took the column
-- and the killer card was left off).
Open(10)
local BRAM, NUMA = F.STRANGER.guid, F.FRIEND.guid
ns.Characters.Observe(BRAM, { first = "Bram", surname = "Redfen", level = 10, faction = "Horde" })
ns.Diary.Add(BRAM, { source = "test" })
ns.Characters.Observe(NUMA, { first = "Numa", surname = "Pompilius", level = 10, faction = "Horde" })
ns.Diary.Add(NUMA, { source = "test" })
ns.db.characters[NUMA].firstSeen = t0 + 700
ns.db.diary[NUMA].addedAt = t0 + 5000
ns.Sessions.New({ me = SELF.guid, source = "group", startedAt = t0 + 300, endedAt = t0 + 1500,
    participants = { [BRAM] = { since = t0 + 300, last = t0 + 1500, seconds = 1200, levelStart = 10 } } })
ns.Journey.Touch()
ns.UI.RefreshJourneyPage(false)
Open(10)

-- The words wrap as the client's do: as tall as their lines at the mock's
-- 6 px a letter, so naming what had no room makes them taller.
local function Wrapping()
    for i = 1, page.captionPool.used + 2 do
        local words = page.captionPool[i]
        if words and not words.wraps then
            words.wraps = true
            words.GetStringHeight = function(self)
                local width = (self.width or 0) > 0 and self.width or 1e9
                return self.text ~= "" and 14 * math.ceil(#self.text * 6 / width) or 0
            end
        end
    end
end
Wrapping()

local function Shown(name)
    for i = 1, page.notePool.used do
        local strip = page.notePool[i]
        if strip:IsShown() and strip.name:GetText() == "with " .. name then return strip end
    end
end
local function Margin()
    local list = {}
    for _, it in ipairs(page.plates[1].margin) do list[#list + 1] = it.kind end
    return table.concat(list, ",")
end

ns.UI.RedrawJourneyPage()
Check(Shown("Bram") and Shown("Numa") and #Cards() == 1, "with room for all, the margin is not all: " .. Margin())

-- Swept down the page's foot. In the row under a short caption (TOP) each
-- note has a box of its own, side by side, so the killer's card and Numa's
-- strip never stand in each other's way there and the ladder alone is
-- checked. Under a long caption the killer's card goes in the column after
-- Bram and Numa, pushed out of it, under the words: words long enough
-- that the room under them ends no higher than the killer's in the column,
-- so the two want the same foot, and there one is found where the
-- killer's card has room and Numa none.
local function Sweep(where)
    local killerOverFirst, firstLeftOff = false, false
    for L = 380, 528, 4 do
        C.limit, C.offLimit = L, L
        ns.UI.RedrawJourneyPage()
        Wrapping()
        ns.UI.RedrawJourneyPage()
        local bram, numa, card = Shown("Bram"), Shown("Numa"), Cards()[1]
        -- A first sighting never takes the killer's room; the killer never
        -- takes the room of someone you were with.
        Check(not numa or card, "a first sighting is shown and the killer left off, " .. where .. ", at " .. L .. ": "
            .. Margin())
        Check(not card or bram, "the killer is shown and Bram left off, " .. where .. ", at " .. L .. ": " .. Margin())
        if card and not numa then firstLeftOff = true end
        if os.getenv("KDEBUG") then print(where, L, Margin(), page.plates[1].captionFoot) end
        if card then killerOverFirst = true end
        -- Nothing under the words lies on them, however long the words grew.
        local plate = page.plates[1]
        local caption = page.captionPool[1]
        local notes = {}
        for i = 1, page.notePool.used do notes[#notes + 1] = page.notePool[i] end
        for i = 1, page.killerPool.used do notes[#notes + 1] = page.killerPool[i] end
        for _, note in ipairs(notes) do
            if note:IsShown() and note.box[1] < 300 then
                Check(note.box[2] >= plate.captionFoot, ("a note lies on the words at %d: %s at %.1f, the words to %.1f")
                    :format(L, note.name:GetText(), note.box[2], plate.captionFoot))
            end
        end
        Eq(plate.captionFoot, -caption.recorded.points[1].args[4] + math.ceil(caption:GetStringHeight()),
            "the words do not end where the margin was laid under, at " .. L)
        -- Who has no strip is in the words.
        if bram == nil then Check(caption:GetText():find("Bram"), "Bram is nowhere, at " .. L) end
    end
    C.limit, C.offLimit = limit, offLimit
    ns.UI.RedrawJourneyPage()
    return killerOverFirst and firstLeftOff
end
Check(page.plates[1].captionOver, "setup: the short caption is not over the plate")
Sweep("in the row")
do
    local real = Text.PlateCaption
    Text.PlateCaption = function(...)
        return real(...) .. " And then the road went on a long way, past the mill and over the hill and home."
            .. " It rained all the way, and the wind was cold."
    end
    ns.UI.RedrawJourneyPage()
    Wrapping()
    ns.UI.RedrawJourneyPage()
    Check(not page.plates[1].captionOver, "setup: the long caption is over the plate")
    Check(Sweep("in the column"), "no room was found where the killer won over the first sighting")
    Text.PlateCaption = real
end
ns.UI.RedrawJourneyPage()

--------------------------------------------------------------------------
Section("the passes after the marks (Plate.RegisterPass)")

-- The killer is chosen in a pass the card's folder registers
-- (Features/Deaths/Card.lua), after the marks: the close call's and the
-- witness's after it. A pass registered between them sees the crosses as
-- the killer's left them (their deaths matched) and the killer chosen;
-- taken out, the passes are as they were.
do
    local Plate = ns.UI.JourneyPlate
    local function Passes()
        local list = {}
        for _, spec in ipairs(Plate.PASS_ORDER) do list[#list + 1] = spec.key .. " " .. spec.order end
        return table.concat(list, ", ")
    end
    Eq(Passes(), "killer 10, foe 20, witness 30, print 90, duelPrint 95", "the passes")
    Open(10)
    local seen
    Plate.RegisterPass("probe", { order = 15, draw = function(p, c)
        local deaths = 0
        for _, cross in ipairs(c.crosses) do deaths = deaths + #(cross.deaths or {}) end
        seen = { plate = p, killer = p.killer, crosses = c.crosses, deaths = deaths, mapID = c.mapID }
    end })
    Eq(Passes(), "killer 10, probe 15, foe 20, witness 30, print 90, duelPrint 95", "the probe's pass is out of place")
    ns.UI.RedrawJourneyPage()
    local plate = page.plates[1]
    Check(seen and seen.plate == plate, "the probe's pass did not run on the plate")
    Check(seen.crosses == plate.crosses, "a pass is not given the plate's crosses")
    Eq(seen.deaths, 3, "the deaths were not on the crosses before the next pass")
    Check(seen.killer ~= nil and seen.killer == plate.killer, "the killer was not chosen before the next pass")
    Eq(seen.mapID, 1412, "a pass's map")
    Plate.RemovePass("probe")
    Eq(Passes(), "killer 10, foe 20, witness 30, print 90, duelPrint 95", "the probe's pass stayed")

    -- Without the killer's pass, no cross knows its killers and no card is
    -- drawn (what a pass leaves on the plate is its own to set each time,
    -- so the last drawing's killer is cleared by hand); back, the plate is
    -- as it was.
    local killer = Plate.PASSES.killer
    Plate.RemovePass("killer")
    page.plates[1].killer = nil
    ns.UI.RedrawJourneyPage()
    Eq(page.plates[1].killer, nil, "a killer without its pass")
    Eq(#Cards(), 0, "a card without its pass")
    Check(not Any(Tips(page.plates[1]), "Sunscale Lashtail"), "a cross told its killer without the pass")
    Plate.RegisterPass("killer", killer)
    ns.UI.RedrawJourneyPage()
    Check(page.plates[1].killer ~= nil and #Cards() == 1, "the killer's pass back, no card")
    Eq(Passes(), "killer 10, foe 20, witness 30, print 90, duelPrint 95", "the passes once the killer's is back")

    -- A pass that lays something over the picture (its `new`, as good
    -- luck's S does, Features/Hunts/LuckyCard.lua): asked once for each
    -- plate made after it registered, with the plate's over-kit; its pools
    -- are on the frame over the picture, begun and finished with every
    -- drawing (one texture reused, the rest hidden) and counted with the
    -- plate's textures; its buttons are there too, a press on them the
    -- plate's.
    local made, drawn, kit0 = {}, 1, nil
    local pools = {}
    Plate.RegisterPass("overprobe", { order = 95,
        new = function(p, kit)
            made[#made + 1] = p
            kit0 = kit
            pools[p] = { tex = kit.Pool("ARTWORK", 4), text = kit.TextPool(ns.Style.FONT.small, "OVERLAY", -1),
                button = kit.Button() }
        end,
        draw = function(p)
            local own = pools[p]
            if not own then return end
            for _ = 1, drawn do own.tex:Next() end
            for _ = 1, drawn do own.text:Next():SetText("probe") end
        end })
    local host = CreateFrame("Frame")
    local slot = { x = 8, y = 14, w = 300, h = 204, t = -1.4, pad = 8, pc = 24, corners = { "tl", "tr", "bl", "br" } }
    local probe = Plate(host, slot)
    Eq(#made, 1, "a pass's new not asked once for a plate made after it")
    Check(made[1] == probe and kit0.over == probe.over, "a pass's new not given the plate and its frame over the picture")
    local own = pools[probe]
    local sheet = { mapID = 1412, stops = {}, roads = {}, flights = {}, pins = {}, dungeons = {}, meetings = {} }
    local window = Plate.Window(1412, 0.5, 0.5, slot.w - 2 * slot.pad, slot.h - 2 * slot.pad)
    local function Draw() probe:Draw(sheet, { from = 0, to = 1e12 }, window, { moments = {}, fights = {}, now = 1000 }) end
    Draw()
    local one = probe.counts.textures
    Draw()
    Eq(#own.tex, 1, "a pass's pool not begun again with the drawing")
    Check(own.tex[1].parent == probe.over and own.tex[1]:IsShown(), "a pass's texture not on the frame over the picture")
    Check(own.text[1]:IsShown() and #own.text == 1, "a pass's font string not begun again with the drawing")
    drawn = 0
    Draw()
    Check(not own.tex[1]:IsShown() and not own.text[1]:IsShown(), "a pass's pools not finished with the drawing")
    Eq(probe.counts.textures, one - 1, "a pass's textures not counted with the plate's")
    Check(own.button.parent == probe.over and not own.button:IsShown(), "a pass's button not on the frame, hidden")
    local pressed
    local Press = probe.Press
    probe.Press = function(_, which) pressed = which end
    own.button.scripts.OnMouseDown(own.button, "LeftButton")
    probe.Press = Press
    Eq(pressed, "LeftButton", "a press on a pass's button not the plate's")
    Plate.RemovePass("overprobe")
    Eq(Passes(), "killer 10, foe 20, witness 30, print 90, duelPrint 95", "the over-picture probe stayed")
end

--------------------------------------------------------------------------
Section("another feature's face on the card (Card.RegisterFace)")

-- The card is shared: the close calls wear it with a face of their own
-- (Features/CloseCalls/Card.lua). A throwaway face registered from here
-- puts its method on every card made after, is laid while worn (its plan,
-- its drawings over the name before the picture and under it after),
-- asked to put away what it drew on every laying, worn or not, and taken
-- off when the card is given a killer. Taken out, cards are as they were.
do
    local function Faces()
        local list = {}
        for _, face in ipairs(Card.FACES) do list[#list + 1] = face.key end
        return table.concat(list, ", ")
    end
    Eq(Faces(), "foe", "the faces")
    local calls = {}
    local function Called(what) calls[#calls + 1] = what end
    local FACE
    FACE = Card.RegisterFace("scrap", {
        methods = { SetScrap = function(card, k) card:Wear(FACE, k, { name = k.name, what = "scrapped" }) end },
        plan = function(card, note, width, room, pic, Least)
            Called("plan")
            Check(type(room) == "number" and room < width and type(Least) == "function", "the plan's room")
            note.under = { w = 20, h = 6, gap = 2, after = 2 }
            return { width = width }
        end,
        top = function(card, plan)
            Called("top")
            Check(plan.width ~= nil, "the plan is not handed to the drawing")
        end,
        under = function() Called("under") end,
        hide = function() Called("hide") end,
        off = function(card) card.scrap = nil; Called("off") end,
        smaller = function() Called("smaller"); return false end,
    })
    Eq(Faces(), "foe, scrap", "the scrap's face")
    local card = Card.New(page.right)
    Check(type(card.SetScrap) == "function" and type(card.SetFoe) == "function", "a face's method is not on the card")
    card:SetScrap({ name = "Mottled Boar" })
    Eq(card.face, FACE, "the card does not wear the scrap's face")
    card.scrap = true
    calls = {}
    card:Layout(10, 10, 150)
    Eq(table.concat(calls, " "), "plan hide top under", "the face's laying")
    Eq(card.name:GetText(), "Mottled Boar", "the face's subject")
    Check(card.under ~= nil, "the face's room under the name")
    Eq(card:Smaller(), false, "the face's smaller")
    calls = {}
    card:SetKiller({ name = "Sunscale Lashtail", count = 1 }, "t", mock.now)
    Check(card.face == nil and card.scrap == nil and calls[1] == "off", "the face was not taken off for a killer")
    calls = {}
    card:Layout(10, 10, 150)
    Eq(table.concat(calls, " "), "hide", "a killer's card asks a face to put away what it drew")
    Eq(card:Smaller(), false, "a killer's card gave something up")
    card:Hide()
    Card.RemoveFace("scrap")
    Eq(Faces(), "foe", "the scrap's face stayed")
    local after = Card.New(page.right)
    Check(rawget(after, "SetScrap") == nil and rawget(after, "SetFoe") ~= nil,
        "a face taken out still puts its method on a card")
    after:Hide()
end
