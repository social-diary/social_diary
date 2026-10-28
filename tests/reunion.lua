-- Meeting diary entries again: reunion toasts and tooltips, "last seen",
-- and the map of where you saw them.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY, Whisper, Reset = T.DAY, T.Whisper, T.BlankDiary
local ns = T.Boot()

local STRANGER, PUG, SELF = F.STRANGER, F.PUG, F.SELF
local A, B, C = STRANGER.guid, F.GARRICK.guid, PUG.guid

--------------------------------------------------------------------------
Section("reunions and tooltips (REU-1 to REU-4)")

mock.RunTimers()  -- the login's
Eq(ns.UI.ReunionShowing(), nil, "a toast is up before anybody joined")

mock.now = 1792000000
local t = mock.now
ns._test.SettleGroup()

ns.Characters.Observe(A, { first = "Bram", surname = "Redfen", level = 12 })
ns.Characters.Observe(B, { first = "Garrick", surname = "Fallow", level = 20 })
ns.Diary.Add(A, { source = "test", tags = { "friend" }, relationship = "questing buddy",
    note = "helped me with Nagas\nand then some" })
ns.db.sessions[201] = {
    id = 201, me = SELF.guid, source = "group",
    startedAt = t - 3 * DAY - 600, endedAt = t - 3 * DAY,
    participants = { [A] = { since = t - 3 * DAY - 600, last = t - 3 * DAY, seconds = 600 } },
    others = 0, zones = { "Mulgore", "The Barrens" }, deaths = {},
}

-- REU-4: tooltip lines.
local lines = mock.UnitTooltip(A)
Eq(#lines, 3, "tooltip line count")
Check(lines[1]:find("friend") and lines[1]:find("questing buddy"), "tags line: " .. tostring(lines[1]))
Eq(lines[2], "helped me with Nagas", "the note's first line only")
Eq(lines[3], "Met 1 time  ·  last 3 days ago", "times met and last met")
Eq(#mock.UnitTooltip(C), 0, "tooltip lines for somebody outside the diary")
Eq(#mock.UnitTooltip(mock.secret(A)), 0, "tooltip lines for a secret GUID")
Eq(#mock.UnitTooltip(nil), 0, "tooltip lines with no GUID")

-- A long note is cut on a character boundary, never inside one.
ns.Diary.SetNote(A, ("\195\169"):rep(40))  -- 40 x "é", 80 bytes
lines = mock.UnitTooltip(A)
Eq(#lines[2], 29 * 2 + 3, "a long note was not cut on a character boundary")
ns.Diary.SetNote(A, "helped me with Nagas")

-- REU-1: a diary entry joining the group raises a toast about the *previous*
-- meeting.
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.fire("GROUP_ROSTER_UPDATE")

-- The card's text without its inks.
local function Plain(text)
    return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
local function Story(card)
    local lines = {}
    for _, fs in ipairs(card.lines) do
        if fs:IsShown() then lines[#lines + 1] = fs:GetText() end
    end
    return Plain(table.concat(lines, " "))
end

local toast = _G.SocialDiaryToastFrame
Check(toast and toast:IsShown(), "no reunion toast")
Eq(toast.heading:GetText(), "JOINED YOUR GROUP", "toast heading")
Eq(toast.name:GetText(), "BRAM REDFEN", "toast name")
Eq(Plain(toast.tags:GetText()), "FRIEND", "toast tags")
Eq(toast.relationship:GetText(), "questing buddy", "toast relationship")
Check(toast.relationship:IsShown() and not toast.who:IsShown(), "the relationship, not the who line")
Eq(Story(toast), "You've met once, 3 days ago in The Barrens.", "toast story")
Check(ns.Sessions.Current(), "the join did not open a session as well")

mock.RunTimers()
Check(not toast:IsShown(), "the toast did not time out")

-- A rejoin straight after a toast stays quiet: it would say the same thing.
mock.groupSize = 0
mock.SetUnit("party1", nil)
mock.fire("GROUP_ROSTER_UPDATE")
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.fire("GROUP_ROSTER_UPDATE")
Eq(ns.UI.ReunionShowing(), nil, "a second toast within ten minutes of the first")

-- REU-2: in combat it waits.
mock.now = mock.now + 11 * 60
mock.groupSize = 0
mock.SetUnit("party1", nil)
mock.fire("GROUP_ROSTER_UPDATE")
mock.inCombat = true
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.fire("GROUP_ROSTER_UPDATE")
Check(not toast:IsShown(), "a toast appeared in combat")
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
Check(toast:IsShown(), "the queued toast did not appear after combat")

-- The mouse on the card holds it past its time; it goes once the mouse
-- leaves.
toast.button.scripts.OnEnter(toast.button)
mock.RunTimers()
Check(toast:IsShown(), "the toast went from under the mouse")
toast.button.scripts.OnLeave(toast.button)
Check(toast:IsShown(), "the toast went the moment the mouse left")
mock.RunTimers()
Check(not toast:IsShown(), "the toast stayed after the mouse left")

mock.now = mock.now + 11 * 60
mock.groupSize = 0
mock.SetUnit("party1", nil)
mock.fire("GROUP_ROSTER_UPDATE")
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.fire("GROUP_ROSTER_UPDATE")
Check(toast:IsShown(), "no toast for the next join")
Eq(Story(toast), "You've crossed paths 2 times, last today in Mulgore.", "the story after a second meeting")

-- Left-click opens them in the journal.
toast.button:Click("LeftButton")
local J = _G.SocialDiaryJournalFrame
Check(not toast:IsShown(), "clicking did not dismiss the toast")
Check(J:IsShown() and J.profile.name:GetText():find("Bram Redfen"),
    "clicking the toast did not open their profile")
ns.UI.CloseJournal()

-- Two at once: one shows, the next waits; right-click dismisses to the next.
mock.now = mock.now + 11 * 60
mock.groupSize = 0
mock.SetUnit("party1", nil)
mock.fire("GROUP_ROSTER_UPDATE")
ns.Diary.Add(B, { source = "test" })

mock.groupSize = 3
mock.SetUnit("party1", STRANGER)
mock.SetUnit("party2", F.GARRICK)
mock.fire("GROUP_ROSTER_UPDATE")
-- The roster is a hash, so either may come first.
local titles = { toast.name:GetText() }
local histories = { Story(toast) }
local whos = { toast.who:IsShown() }
toast.button:Click("RightButton")
Check(toast:IsShown(), "the second toast did not follow the first")
Check(not J:IsShown(), "right-click opened the journal")
titles[2], histories[2], whos[2] = toast.name:GetText(), Story(toast), toast.who:IsShown()

local both = table.concat(titles, "|")
Check(both:find("BRAM REDFEN") and both:find("GARRICK FALLOW"), "toasts shown: " .. both)
local g = titles[1]:find("GARRICK") and 1 or 2
Eq(histories[g], "Your first time together since you wrote them in.", "never-met toast")
Eq(whos[g], true, "no who line for an entry without tags")
mock.RunTimers()

-- Nobody outside the diary gets a toast.
mock.groupSize = 4
mock.SetUnit("party3", PUG)
mock.fire("GROUP_ROSTER_UPDATE")
Eq(ns.UI.ReunionShowing(), nil, "a toast for somebody outside the diary")

-- A flood is capped: five queued, the rest folded into one last toast.
-- Seven people, since one person is never lined up twice.
local flood = {}
for i = 1, 7 do
    flood[i] = ("Player-4395-0F0000%02d"):format(i)
    ns.Characters.Observe(flood[i], { first = "Flood" .. i, surname = "Tester", level = 10 })
    ns.Diary.Add(flood[i], { source = "test" })
end
for i = 1, 7 do ns.UI.Reunion(flood[i]) end
local shown, last = 0, nil
while ns.UI.ReunionShowing() and shown < 20 do
    shown = shown + 1
    last = toast.name:GetText() .. " " .. Story(toast)
    mock.RunTimers()
end
Eq(shown, 7, "toasts shown for a flood (1 + 5 queued + 1 summary)")
Eq(last, "AND 1 MORE from your diary joined your group too.", "the summary toast for the overflow")
for i = 1, 7 do ns.Characters.Forget(flood[i]) end

-- The same person twice in a row is one toast, showing or waiting.
wipe(ns.db.meta.greeted)
ns.UI.Reunion(A)
wipe(ns.db.meta.greeted)
ns.UI.Reunion(A)
mock.RunTimers()
Eq(ns.UI.ReunionShowing(), nil, "the same person was lined up twice")

mock.groupSize = 0
for i = 1, 4 do mock.SetUnit("party" .. i, nil) end
mock.fire("GROUP_ROSTER_UPDATE")

-- REU-5: a diary entry coming into view, then a per-person cooldown.
wipe(ns.db.meta.greeted)
mock.SetUnit("nameplate1", STRANGER)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Check(toast:IsShown(), "no toast for a diary entry's nameplate")
Eq(toast.heading:GetText(), "NEARBY", "nearby toast heading")
Eq(toast.name:GetText(), "BRAM REDFEN", "nearby toast name")
mock.RunTimers()

mock.now = mock.now + 9 * 60
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
mock.SetUnit("target", STRANGER)
mock.fire("PLAYER_TARGET_CHANGED")
Eq(ns.UI.ReunionShowing(), nil, "a second nearby toast inside the cooldown")

-- The cooldown is saved, so a /reload or a relog does not reset it.
mock.fire("PLAYER_ENTERING_WORLD", false, true)
mock.fire("PLAYER_LOGIN")
mock.fire("PLAYER_TARGET_CHANGED")
Eq(ns.UI.ReunionShowing(), nil, "logging in reset the cooldown")

mock.now = mock.now + 2 * 60
mock.fire("PLAYER_TARGET_CHANGED")
Check(ns.UI.ReunionShowing(), "no toast once the cooldown ran out")
mock.RunTimers()

-- The cooldown is a setting.
ns.db.settings.toastCooldownMinutes = 30
mock.now = mock.now + 11 * 60
mock.fire("PLAYER_TARGET_CHANGED")
Eq(ns.UI.ReunionShowing(), nil, "a longer cooldown was not honoured")
mock.now = mock.now + 20 * 60
mock.fire("PLAYER_TARGET_CHANGED")
Check(ns.UI.ReunionShowing(), "no toast after the longer cooldown")
mock.RunTimers()
ns.db.settings.toastCooldownMinutes = 10

-- Expired stamps are dropped at login; live ones stay.
ns.db.meta.greeted[B] = mock.now - 3600
mock.fire("PLAYER_LOGIN")
Eq(ns.db.meta.greeted[B], nil, "an expired cooldown stamp was kept")
Check(ns.db.meta.greeted[A], "a live cooldown stamp was dropped")

-- Inviting them right after the nearby toast does not toast again.
mock.RunTimers()
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.fire("GROUP_ROSTER_UPDATE")
Eq(ns.UI.ReunionShowing(), nil, "a group toast straight after a nearby one")

-- A group member's nameplate is never "nearby" news.
wipe(ns.db.meta.greeted)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Eq(ns.UI.ReunionShowing(), nil, "a nearby toast for somebody in the group")
mock.groupSize = 0
mock.SetUnit("party1", nil)
mock.fire("GROUP_ROSTER_UPDATE")

-- Nobody outside the diary, no secrets, and the switch works.
mock.SetUnit("nameplate2", PUG)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
Eq(ns.UI.ReunionShowing(), nil, "a nearby toast for somebody outside the diary")

mock.SetUnit("nameplate3", F.Like(STRANGER, { guid = mock.secret(A) }))
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
mock.fire("NAME_PLATE_UNIT_ADDED", mock.secret("nameplate1"))
Eq(ns.UI.ReunionShowing(), nil, "a nearby toast from a secret GUID or token")

ns.db.settings.nearbyToasts = false
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Eq(ns.UI.ReunionShowing(), nil, "a nearby toast with nearby toasts switched off")
ns.db.settings.nearbyToasts = true

-- A foe or someone to avoid gets the warning card: its own heading and a
-- red double rule round it.
Eq(toast.rules.used, 0, "a warning rule on an ordinary card")
ns.Diary.Get(A).tags = { "friend", "foe" }
ns.Touch()
wipe(ns.db.meta.greeted)
ns.UI.Reunion(A, "nearby")
Check(toast:IsShown(), "no toast for a foe nearby")
Eq(toast.heading:GetText(), "A FOE, NEARBY", "the foe's heading")
Eq(toast.text.warning, "foe", "the foe's card is not a warning")
Check(toast.rules.used > 0, "no warning rule round the foe's card")
mock.RunTimers()

ns.Diary.Get(A).tags = { "foe", "avoid" }
ns.Touch()
wipe(ns.db.meta.greeted)
ns.UI.Reunion(A, "group")
Eq(toast.heading:GetText(), "SOMEONE TO AVOID JOINED YOUR GROUP", "in the group, avoid comes before foe")
mock.RunTimers()

ns.Diary.Get(A).tags = { "friend" }
ns.Touch()
wipe(ns.db.meta.greeted)
ns.UI.Reunion(A, "nearby")
Eq(toast.rules.used, 0, "the warning rule stayed on an ordinary card")
mock.RunTimers()
wipe(ns.db.meta.greeted)

for i = 1, 3 do mock.SetUnit("nameplate" .. i, nil) end
mock.SetUnit("target", nil)

--------------------------------------------------------------------------
Section("last seen at ... in ...")

Reset()
ns.db.characters = {}
mock.RunTimers()
wipe(ns.db.meta.greeted)
mock.now = 1793000000
mock.zone, mock.subZone = "Mulgore", "Red Cloud Mesa"

local function Seen(guid)
    local record = ns.Characters.Get(guid)
    return record and record.seen
end

ns.Characters.Observe(A, { first = "Bram", surname = "Redfen" })
ns.Diary.Add(A, { source = "test" })
Eq(Seen(A), nil, "added without a unit token, yet marked as seen")

mock.SetUnit("nameplate1", STRANGER)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Check(Seen(A), "a diary entry's nameplate did not count as seen")
Eq(Seen(A).time, mock.now, "seen time")
Eq(Seen(A).zone, "Mulgore", "seen zone (the user's own)")
Eq(Seen(A).subZone, "Red Cloud Mesa", "seen subzone")
Eq(Seen(A).mapID, 1412, "seen map")
mock.RunTimers()

-- Bursts move only the time; the place is read again after the throttle.
mock.now = mock.now + 5
mock.zone = "Thunder Bluff"
mock.SetUnit("mouseover", STRANGER)
mock.fire("UPDATE_MOUSEOVER_UNIT")
Eq(Seen(A).time, mock.now, "the time did not move inside the throttle")
Eq(Seen(A).zone, "Mulgore", "the place was re-read inside the throttle")
mock.now = mock.now + 20
mock.fire("UPDATE_MOUSEOVER_UNIT")
Eq(Seen(A).zone, "Thunder Bluff", "the place was not re-read after the throttle")
mock.zone = "Mulgore"

-- A token that is not drawn nearby (a party frame across the map) is not seen.
local seenBefore = Seen(A).time
mock.now = mock.now + 60
mock.SetUnit("mouseover", F.Like(STRANGER, { visible = false }))
mock.fire("UPDATE_MOUSEOVER_UNIT")
Eq(Seen(A).time, seenBefore, "an out-of-range unit counted as seen")
mock.SetUnit("mouseover", nil)

-- A whisper is not seeing someone; a trade is, for anyone.
Whisper("CHAT_MSG_WHISPER", "where are you?", "Bram Redfen", 800, A)
Eq(Seen(A).time, seenBefore, "a whisper counted as seen")
ns.Characters.Observe(C, { first = "Norwood", surname = "Sparks" })
ns.Interactions.Add(C, "trade", { time = mock.now - 3600 })
Eq(Seen(C), nil, "a backfilled trade counted as seen")
ns.Interactions.Add(C, "trade", {})
Eq(Seen(C) and Seen(C).time, mock.now, "a trade did not count as seen")

-- Group members in range, on the slow timer.
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
ns.Nearby.ScanGroup()
Eq(Seen(A).time, mock.now, "a group member in range was not seen")
mock.now = mock.now + 30
mock.SetUnit("party1", F.Like(STRANGER, { visible = false }))
ns.Nearby.ScanGroup()
Eq(Seen(A).time, mock.now - 30, "a group member out of range was seen")
mock.groupSize = 0
mock.SetUnit("party1", nil)

-- Nobody outside the diary through nameplates (that is M2's sightings).
ns.Characters.Observe(B, { first = "Garrick", surname = "Fallow" })
mock.SetUnit("nameplate2", { guid = B, name = { "Garrick", "Fallow" } })
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
Eq(Seen(B), nil, "a nameplate outside the diary was recorded")

-- The words.
local at = Seen(A).time
Eq(ns.UI.Format.SeenText(Seen(A), at), "Last seen today at " .. date("%H:%M", at)
    .. " in Red Cloud Mesa, Mulgore", "the last seen line")
Eq(ns.UI.Format.At(at - DAY, at), "yesterday at " .. date("%H:%M", at - DAY), "yesterday")
Check(ns.UI.Format.At(at - 10 * DAY, at):find("^on %d%d %a+ at %d%d:%d%d$"), "this year: " .. ns.UI.Format.At(at - 10 * DAY, at))
Check(ns.UI.Format.At(at - 400 * DAY, at):find("%d%d%d%d at"), "an older year shows the year")
Eq(ns.UI.Format.SeenText(nil), "Not seen nearby yet.", "never seen")
Eq(ns.UI.Format.SeenText({ time = at, zone = "Orgrimmar", subZone = "Orgrimmar" }, at),
    "Last seen today at " .. date("%H:%M", at) .. " in Orgrimmar", "a subzone named like its zone")

-- On the profile, and as a sort. The summary paragraph is gone: where
-- they were last seen is in the facts' tooltips (the tally's, or for
-- somebody never met the first strip's), the person-page copy's gap.
local CL = J.profile.clippings
local function Tip(strip)
    local list, out = strip.tip and strip.tip() or {}, {}
    for _, line in ipairs(list) do out[#out + 1] = line[1] end
    return table.concat(out, "\n")
end
ns.Diary.Add(B, { source = "test" })
ns.UI.ShowJournal(A)
local facts = CL.tally:IsShown() and CL.tally or CL.first
Check(Tip(facts):find("Last seen today at"), "profile facts' tooltip: " .. Tip(facts))
ns.UI.SelectPerson(B)
Check(Tip(CL.first):find("Not seen nearby yet$"), "facts for somebody never seen: " .. Tip(CL.first))
Check(CL.first.name:GetText():find("^Added "), "the first strip for somebody never met: " .. CL.first.name:GetText())
Eq(CL.first:What(), "not met yet", "the first strip's subtitle for somebody never met")
Check(not CL.tally:IsShown(), "a tally for somebody never met")
Check(CL.note:Written():find("No note yet"), "an empty note")

J.sortButton:Click()
Check(mock.MenuClick("Last seen"), "no 'Last seen' sort")
Eq(J.people.data[1].header, "Seen this week", "last seen heading")
Eq(J.people.data[2].guid, A, "last seen sort order")
Eq(J.people.rows[2].detail:GetText(), "today", "last seen on the row")
Eq(J.people.data[3].header, "Not seen yet", "never seen heading")
Eq(J.people.rows[4].detail:GetText(), "", "never seen on the row")
J.sortButton:Click()
mock.MenuClick("Last met")
ns.UI.CloseJournal()

for i = 1, 2 do mock.SetUnit("nameplate" .. i, nil) end
mock.subZone = ""
mock.RunTimers()

--------------------------------------------------------------------------
Section("the journal map (where you saw them)")

Reset()
ns.db.characters = {}
mock.RunTimers()
wipe(ns.db.meta.greeted)
mock.now = 1794000000

local function HeatOf(guid)
    local record = ns.Characters.Get(guid)
    return record and record.heat
end

ns.Characters.Observe(A, { first = "Bram", surname = "Redfen" })
ns.Characters.Observe(B, { first = "Garrick", surname = "Fallow" })
ns.Diary.Add(A, { source = "test" })
ns.Diary.Add(B, { source = "test" })
mock.SetUnit("nameplate1", STRANGER)

-- Instances have no coordinates, so a sighting there adds no heat.
mock.inInstance = true
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
mock.inInstance = false
Check(ns.Characters.Get(A).seen, "not seen inside the instance")
Eq(HeatOf(A), nil, "heat inside an instance")
mock.now = mock.now + 20

-- Then on another map, then twice in Mulgore -- the second read inside the
-- throttle does not count.
mock.mapID, mock.position = 1413, { x = 0.1, y = 0.9 }
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Check(HeatOf(A) and HeatOf(A)[1413], "no heat on the first map")

mock.mapID, mock.position = 1412, { x = 0.4213, y = 0.6157 }
mock.now = mock.now + 20
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
local cell = 30 * 50 + 21  -- row 30, column 21
Eq(HeatOf(A)[1412][cell], 1, "the cell for 0.42, 0.62")
mock.now = mock.now + 5
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Eq(HeatOf(A)[1412][cell], 1, "a read inside the throttle added heat")
mock.now = mock.now + 20
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Eq(HeatOf(A)[1412][cell], 2, "a read after the throttle added no heat")

local cx, cy = ns.Heat.CellXY(cell)
Eq(math.floor(cx * 100 + 0.5), 43, "cell centre x")
Eq(math.floor(cy * 100 + 0.5), 61, "cell centre y")

-- Nobody outside the diary gets heat.
ns.Characters.Observe(C, { first = "Norwood", surname = "Sparks" })
ns.Interactions.Add(C, "trade", {})
Eq(HeatOf(C), nil, "heat for somebody outside the diary")

mock.position = { x = 0.5, y = 0.5 }
mock.SetUnit("nameplate2", { guid = B, name = { "Garrick", "Fallow" } })
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
mock.position = { x = 0.4213, y = 0.6157 }

local maps = ns.Heat.Maps(A)
Eq(#maps, 2, "maps for one person")
Eq(maps[1].mapID, 1412, "busiest map first")
Eq(maps[1].total, 2, "map total")
Eq(ns.Heat.Maps(nil)[1].total, 3, "everyone's total on the busiest map")
local _, max, total = ns.Heat.Cells(nil, 1412)
Eq(max, 2, "hottest cell")
Eq(total, 3, "cells total")

-- Shading, normalised for how much heat a map holds.
do
    local G = ns.Heat.GRID
    local shade = ns.Heat.Shade({ [10] = 1 }, 1)
    Eq(#shade, 1, "one shaded cell")
    Eq(shade[1].t, 1, "a lone sighting is drawn at full strength")
    Eq(shade[1].crowd, 1, "a lone cell is not crowded")
    Eq(ns.Heat.Power(5), 0.5, "a few sightings: the square root")
    Eq(ns.Heat.Power(500), 1, "a busy map: straight")
    Check(ns.Heat.Power(60) > 0.5 and ns.Heat.Power(60) < 1, "between, eased")

    -- A trail of single sightings leading to a spot lingered at.
    local trail = {}
    for row = 0, 9 do trail[row * G + 5] = 1 end
    trail[20 * G + 30], trail[20 * G + 31], trail[21 * G + 30] = 30, 30, 30
    local function T(cells, total)
        local byCell = {}
        for _, e in ipairs(ns.Heat.Shade(cells, total)) do byCell[e.cell] = e end
        return byCell
    end
    local busy = T(trail, 210)
    Eq(busy[20 * G + 30].t, 1, "the lingered spot is strongest")
    Check(busy[5 * G + 5].t < 0.15, "a passing sighting on a busy map is only a trace")
    Eq(busy[5 * G + 5].crowd, 3, "a trail cell touches its two neighbours")
    Eq(busy[0 * G + 5].crowd, 2, "the trail's end touches one")
    Eq(busy[20 * G + 31].crowd, 3, "the spot's cells touch each other")
    local few = T(trail, 10)
    Check(few[5 * G + 5].t > busy[5 * G + 5].t * 2, "a few sightings are drawn stronger than the same on a busy map")

    -- No wrapping round the grid's edge.
    local edge = T({ [G - 1] = 1, [G] = 1 }, 2)
    Eq(edge[G - 1].crowd, 1, "the last column does not touch the next row's first")

    local list = ns.Heat.Shade(trail, 210)
    for i = 2, #list do Check(list[i - 1].t >= list[i].t, "shade sorted strongest first") end
end

-- The view.
ns.UI.ShowJournal(A)
J.profile.tabMap:Click()
local HM = J.profile.map
Check(HM:IsShown(), "the Map tab did not lay the map on the book")
Check(J.profile.tabMap.selected and not J.profile.tabStory.selected, "the map tab is not marked")
Check(J.profile.timeline:IsShown(), "the page under the map sheet is gone")
Eq(HM.themButton:GetText(), "Just Bram", "the scope does not name the person")

-- The sheet is folded and crumpled: its pieces bend at their corners, a
-- little, and the facets are not all lit the same.
Check(HM.bends, "the mock's textures should bend")
local bent, most, lights = 0, 0, {}
for _, region in ipairs(mock.frames) do
    local call = region.parent == HM.sheet and region.recorded.calls.SetVertexOffset
    if call then
        bent = bent + 1
        most = math.max(most, math.abs(call[2]), math.abs(call[3]))
    end
    local colour = region.parent == HM.sheet and region.recorded.calls.SetColorTexture
    if colour and region.recorded.layer == "BACKGROUND" and colour[4] == 1 then lights[colour[1]] = true end
end
Check(bent > 0, "nothing on the sheet bends")
Check(most > 0 and most < 25, "a corner moved " .. most .. " px")
local shades = 0
for _ in pairs(lights) do shades = shades + 1 end
Check(shades > 3, "the facets are lit alike: " .. shades)

-- "Flat paper only" (flatSheets): the sheet stops bending, its facets are
-- lit alike, and the folds lose their creases, wear and grime; all of it
-- comes back when the setting is off.
local function SheetPaper()
    local found, creases, worn = {}, 0, 0
    for _, region in ipairs(mock.frames) do
        local rec = region.parent == HM.sheet and region.shown and region.recorded
        local colour = rec and rec.calls.SetColorTexture
        if colour and rec.layer == "BACKGROUND" and rec.sublevel == -5 then found[colour[1]] = true end
        if rec and rec.layer == "ARTWORK" and rec.sublevel == 4 then creases = creases + 1 end
        local texture = rec and rec.calls.SetTexture
        if texture and texture[1] == ns.Style.Art("grime") then worn = worn + 1 end
        if rec and rec.layer == "ARTWORK" and rec.sublevel == 5 then worn = worn + 1 end
    end
    local n = 0
    for _ in pairs(found) do n = n + 1 end
    return n, creases, worn
end
local litShades, litCreases, litWorn = SheetPaper()
Check(litCreases > 0 and litWorn > 0, "no creases or wear on a folded sheet")
ns.db.settings.flatSheets = true
HM:Refresh()
Check(not HM.bends and HM.flat, "the sheet still bends when laid flat")
local flatShades, flatCreases, flatWorn = SheetPaper()
Eq(flatShades, 1, "the facets of a flat sheet are not lit alike")
Eq(flatCreases, 0, "a flat sheet still has creases")
Eq(flatWorn, 0, "a flat sheet still has wear or grime")
Check(litShades > 1, "the folded sheet's facets were lit alike")
ns.db.settings.flatSheets = false
HM:Refresh()
Check(HM.bends, "the sheet does not bend again")
local _, againCreases, againWorn = SheetPaper()
Check(againCreases > 0 and againWorn > 0, "the creases and wear did not come back")

-- Grime along the folds, and more where they cross.
local grime = 0
for _, region in ipairs(mock.frames) do
    local texture = region.parent == HM.sheet and region.recorded.calls.SetTexture
    if texture and texture[1] == ns.Style.Art("grime") then grime = grime + 1 end
end
Check(grime > 20, "no grime along the folds: " .. grime)

-- The shadow follows the paper's height: its pieces fall different
-- distances, so they bend; the flat shadow is not shown.
local fallen = 0
for _, region in ipairs(mock.frames) do
    local calls = region.parent == HM.sheet and region.recorded.layer == "BACKGROUND"
        and region.recorded.sublevel and region.recorded.sublevel <= -7 and region.recorded.calls
    if calls and calls.SetVertexOffset and region.shown then fallen = fallen + 1 end
end
Check(fallen >= 16, "the shadow does not follow the paper: " .. fallen)

-- The map is printed in a border of ink.
local border = 0
for _, region in ipairs(mock.frames) do
    local rec = region.parent == HM.sheet and region.shown and region.recorded
    if rec and rec.layer == "ARTWORK" and rec.sublevel == 3 then border = border + 1 end
end
Check(border >= 4, "no border round the map: " .. border)
Eq(HM.mapID, 1412, "the map the user is on should come first")
Eq(HM.tileCount, 12, "map art tiles (4 x 3)")
Eq(HM.cellCount, 1, "heat squares for one cell")
Eq(HM.mapButton:GetText(), "Mulgore", "map link")
Check(HM.also[1]:IsShown() and HM.also[1]:GetText() == "The Barrens (1)", "no link to the other map")
Check(not HM.also[2]:IsShown(), "a link to a map they were not seen on")
Check(HM.legend:GetText():find("^Seen here 2 times"), "legend: " .. HM.legend:GetText())
Check(HM.marker:IsShown(), "no last-seen marker")
Check(HM.seen:GetText():find("^Last seen today at"), "the key does not say when the X was: " .. HM.seen:GetText())
Check(HM.themButton.current and not HM.everyoneButton.current, "'Just them' is not the current scope")

HM.everyoneButton:Click()
Eq(HM.cellCount, 2, "everyone's heat squares")
Check(HM.legend:GetText():find("seen here 3 times"), "everyone's legend: " .. HM.legend:GetText())
Check(not HM.marker:IsShown(), "a last-seen marker in the everyone view")
Eq(HM.seen:GetText(), "", "the key explains an X that is not there")
Check(not HM.seenCross:IsShown(), "the key's X shows without a last-seen mark")
Check(HM.everyoneButton.current, "'Everyone' is not the current scope")
HM.themButton:Click()

HM.mapButton:Click()
Check(mock.MenuClick("The Barrens (1)"), "no Barrens entry in the map menu")
Eq(HM.mapID, 1413, "the map menu did not switch maps")
Eq(HM.cellCount, 1, "heat squares on the second map")
Check(not HM.marker:IsShown(), "a last-seen marker on a map they were not last seen on")
Eq(HM.also[1]:GetText(), "Mulgore (2)", "the other map's link is not back to Mulgore")
HM.also[1]:Click()
Eq(HM.mapID, 1412, "the link did not switch maps")
HM.mapButton:Click()
mock.MenuClick("The Barrens (1)")

-- A map the client has no art for still draws its heat.
HeatOf(A)[9999] = { [0] = 5 }
HM:Refresh()
HM.mapButton:Click()
Check(mock.MenuClick("Map 9999 (5)"), "no entry for a map without a name")
Eq(HM.tileCount, 0, "tiles for a map without art")
Eq(HM.cellCount, 1, "heat on a map without art")

-- The heat is ink blots (UI/Ink/Blot.lua): pieces of flat ink with their
-- corners on the sheet, three inks one over another. Where a sheet point
-- lies, for a cell; which levels have ink near a point; and whether every
-- piece stays in the map's box.
local function CellOnSheet(cell)
    local box = HM.box
    local x, y = ns.Heat.CellXY(cell)
    local span = 1 - 2 * box.crop
    return box.x + (x - box.crop) / span * box.w, box.y + (y - box.crop) / span * box.h
end
-- Whether ink of `level` covers the point (each piece is convex, its
-- corners in the screen's turn), and whether any of its corners lies
-- within `reach` of it.
local function InkAt(level, x, y)
    for _, q in ipairs(HM.blot.levels[level]) do
        local inside = true
        for c = 1, 7, 2 do
            local x1, y1 = q[c], q[c + 1]
            local x2, y2 = q[(c + 1) % 8 + 1], q[(c + 2) % 8 + 1]
            if (x2 - x1) * (y - y1) - (y2 - y1) * (x - x1) < 0 then inside = false; break end
        end
        if inside then return true end
    end
    return false
end
local function InkNear(level, x, y, reach)
    for _, q in ipairs(HM.blot.levels[level]) do
        for c = 1, 7, 2 do
            if math.abs(q[c] - x) <= reach and math.abs(q[c + 1] - y) <= reach then return true end
        end
    end
    return false
end
local function InBox()
    local box = HM.box
    for _, quads in ipairs({ HM.blot.levels[1], HM.blot.levels[2], HM.blot.levels[3], HM.blot.rim }) do
        for _, q in ipairs(quads) do
            for c = 1, 7, 2 do
                if q[c] < box.x - 1e-6 or q[c] > box.x + box.w + 1e-6
                    or q[c + 1] < box.y - 1e-6 or q[c + 1] > box.y + box.h + 1e-6 then return false end
            end
        end
    end
    return true
end

-- A lone sighting reads clearly: a round blot with a dark heart, all three
-- inks, edged with its rim, in pieces whose corners are on the paper.
do
    HeatOf(A)[9999] = { [25 * ns.Heat.GRID + 25] = 1 }
    HM:Refresh()
    local blot = HM.blot
    Check(#blot.levels[1] > 0 and #blot.levels[2] > 0 and #blot.levels[3] > 0,
        "a lone sighting is not inked to its heart")
    Check(#blot.rim > 0, "a lone blot has no rim")
    local x0, x1 = math.huge, -math.huge
    for _, q in ipairs(blot.levels[1]) do
        for c = 1, 7, 2 do x0, x1 = math.min(x0, q[c]), math.max(x1, q[c]) end
    end
    local cell = HM.box.w / (1 - 2 * HM.box.crop) / ns.Heat.GRID
    Check((x1 - x0) / cell > 2 and (x1 - x0) / cell < 3.2,
        ("a lone blot is not 2 to 3 cells across: %.2f"):format((x1 - x0) / cell))
    Check(InBox(), "the heat spills past the map's box")
    local bent = 0
    for _, region in ipairs(mock.frames) do
        local rec = region.parent == HM.sheet and region.shown and region.recorded
        if rec and rec.layer == "ARTWORK" and rec.sublevel >= -1 and rec.sublevel <= 2
            and rec.calls.SetVertexOffset and rec.calls.SetColorTexture then bent = bent + 1 end
    end
    Check(bent >= blot.count, ("the blot's pieces are not bent onto the paper: %d of %d"):format(bent, blot.count))

    -- A blot by the map's edge is cut there, not spilled over the border.
    HeatOf(A)[9999] = { [0] = 5 }
    HM:Refresh()
    Check(#HM.blot.levels[1] > 0, "a sighting at the map's corner is not inked")
    Check(InBox(), "a blot at the map's corner spills past its box")
end

-- Each swatch of the key is its ink over the ones under it, as on the map.
Eq(#HM.swatchUnder, 3, "the swatches are not stacked like the inks")

-- On a busy map, a trail walked once is a pale path and only where you
-- lingered goes dark; the whole stays under its cap of pieces.
do
    local G, busy = ns.Heat.GRID, {}
    for col = 10, 20 do busy[10 * G + col] = 1 end
    for row = 29, 31 do
        for col = 29, 31 do busy[row * G + col] = 20 end
    end
    HeatOf(A)[9999] = busy
    HM:Refresh()
    Eq(HM.cellCount, 20, "heat cells on the busy map")
    local tx, ty = CellOnSheet(10 * G + 15)
    local hx, hy = CellOnSheet(30 * G + 30)
    local cell = HM.box.w / (1 - 2 * HM.box.crop) / G
    Check(InkAt(1, tx, ty), "a trail walked once is not inked at all")
    Check(not InkNear(2, tx, ty, 3 * cell) and not InkNear(3, tx, ty, 3 * cell), "a passing sighting is not pale")
    Check(InkAt(3, hx, hy), "where you lingered is not dark")
    Check(HM.blot.count <= 1400, "the busy map passed its cap: " .. HM.blot.count)
    -- One blot along the trail: the pale ink is unbroken from its first
    -- cell to its last.
    for col = 10, 20, 0.25 do
        local x, y = CellOnSheet(10 * G + 10)
        x = x + (col - 10) * cell
        Check(InkAt(1, x, y), "the trail is broken at column " .. col)
    end
    HeatOf(A)[9999] = { [0] = 5 }
    HM:Refresh()
end

-- Somebody never seen on a map.
ns.Diary.Add(C, { source = "test" })
ns.UI.SelectPerson(C)
Check(HM.empty:GetText():find("Not seen on a map yet"), "empty map message")
Eq(HM.cellCount, 0, "heat squares for somebody never seen")
Check(not HM.alsoLabel:IsShown() and not HM.swatches[1]:IsShown(), "a key for an empty map")

-- A click on the book beside the sheet puts it away; the tab brings it
-- back, and puts it away again.
HM.scripts.OnMouseDown(HM)
Check(not HM:IsShown() and J.profile.tabStory.selected, "a click beside the sheet did not put it away")
J.profile.tabMap:Click()
Check(HM:IsShown(), "the tab did not bring the sheet back")
J.profile.tabMap:Click()
Check(not HM:IsShown(), "the open tab did not put the sheet away")

J.profile.tabStory:Click()
Check(J.profile.timeline:IsShown() and not HM:IsShown(), "the story tab did not swap back")

-- The sheet rustles as it is laid on the book and taken off, on the effects
-- channel; shown again where it already lies, it stays silent.
local function Heard()
    local heard = mock.sounds
    mock.sounds = {}
    local ids = {}
    for _, sound in ipairs(heard) do
        Eq(sound[2], "SFX", "a sheet's sound not on the effects channel")
        ids[#ids + 1] = sound[1]
    end
    return table.concat(ids, ",")
end
Heard()
J.profile.tabMap:Click()
Eq(Heard(), "844", "laying the map on the book made no sound")
HM:Refresh()
J.profile.tabMap:Click()
Eq(Heard(), "845", "putting the map away made no sound")
J.profile.tabMap:Click()
Heard()
ns.UI.SelectPerson(A)
Eq(Heard(), "", "the map rustled again for another person while it lay there")
J.profile.tabStory:Click()
Heard()
ns.UI.CloseJournal()

-- Forgetting someone takes their map with them.
ns.Characters.Forget(A)
Eq(#ns.Heat.Maps(A), 0, "a forgotten character still has heat")

--------------------------------------------------------------------------
Section("when a toast is due, without the toast (Core/Reunions.lua)")

local R = ns.Reunions
wipe(ns.db.meta.greeted)
local now = mock.now
Eq(R.Cooldown(), 10 * 60, "the default cooldown")
Eq(R.Due(B, "group", now), B, "a group toast not due")
Eq(R.Due(B, "nearby", now), B, "a nearby toast not due")
Eq(R.Due(mock.secret(B), "group", now), nil, "a secret GUID was due a toast")

R.Greet(B, now)
Eq(ns.db.meta.greeted[B], now, "Greet did not stamp")
Check(R.CoolingDown(B, now + 599), "not cooling down inside the cooldown")
Eq(R.Due(B, "group", now + 599), nil, "due inside the cooldown")
Eq(R.Due(B, "group", now + 600), B, "not due once the cooldown ran out")

-- 0 minutes is no cooldown; a value that is not one falls back to the
-- shipped default, which lives in DB.lua only.
ns.db.settings.toastCooldownMinutes = 0
Eq(R.Due(B, "group", now), B, "a zero cooldown still held the toast back")
ns.db.settings.toastCooldownMinutes = "lots"
Eq(R.Cooldown(), ns.SettingDefault("toastCooldownMinutes") * 60, "a broken setting did not fall back")
ns.db.settings.toastCooldownMinutes = -5
Eq(R.Cooldown(), 600, "a negative setting did not fall back")
ns.db.settings.toastCooldownMinutes = 10

-- The switches, and nobody already in the group gets a nearby toast.
ns.db.settings.toasts = false
Eq(R.Due(C, "group", now), nil, "due with toasts off")
Eq(R.Due(C, "nearby", now), C, "group toasts off held back a nearby toast")
ns.db.settings.toasts = true
ns.db.settings.nearbyToasts = false
Eq(R.Due(C, "nearby", now), nil, "a nearby toast with nearby toasts off")
Eq(R.Due(C, "group", now), C, "nearby toasts off held back a group toast")
ns.db.settings.nearbyToasts = true
ns.db.meta.roster.members[C] = true
Eq(R.Due(C, "nearby", now), nil, "a nearby toast for a group member")
ns.db.meta.roster.members[C] = nil

-- Prune keeps live stamps only; forgetting drops the stamp.
ns.db.meta.greeted[C] = now - 3600
R.Prune(now)
Eq(ns.db.meta.greeted[C], nil, "Prune kept an expired stamp")
Eq(ns.db.meta.greeted[B], now, "Prune dropped a live stamp")
ns.ForgetEverywhere(B)
Eq(ns.db.meta.greeted[B], nil, "forgetting kept the stamp")

--------------------------------------------------------------------------
Section("the foe alert: a raid warning when a foe comes into view")

local RAID_WARNING = 8959

-- What was played since the last call, as "id channel" joined by commas.
local function Played()
    local heard = {}
    for _, sound in ipairs(mock.sounds) do heard[#heard + 1] = sound[1] .. " " .. sound[2] end
    mock.sounds = {}
    return table.concat(heard, ",")
end

if not ns.Diary.IsDiary(C) then ns.Diary.Add(C, { source = "test" }) end
ns.Diary.AddTag(C, "foe")
now = mock.now
Eq(ns.db.settings.foeAlert, false, "the foe alert is on before anybody asked for it")
Eq(R.FoeAlert(C, now), false, "an alert with the foe alert off")

ns.db.settings.foeAlert = true
Eq(R.FoeAlert(C, now), true, "no alert for a foe in view")
Eq(R.FoeAlert(C, now + 59), false, "the same foe alerted again inside a minute")
Eq(R.FoeAlert(C, now + 60), true, "no alert once the minute ran out")
Eq(R.FoeAlert(mock.secret(C), now + 200), false, "an alert from a secret GUID")

ns.Diary.RemoveTag(C, "foe")
Eq(R.FoeAlert(C, now + 300), false, "an alert for someone no longer a foe")
ns.Diary.AddTag(C, "foe")
ns.db.meta.roster.members[C] = true
Eq(R.FoeAlert(C, now + 400), false, "an alert for a foe in the group")
ns.db.meta.roster.members[C] = nil

-- Through capture: the nameplate, in combat, with toasts quiet for them.
mock.now = now + 1000
mock.sounds = {}
ns.Diary.SetQuietNearby(C, true)
mock.SetUnit("nameplate1", PUG)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Eq(Played(), RAID_WARNING .. " Master", "a foe coming into view did not sound the raid warning")
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Eq(Played(), "", "the raid warning sounded twice in a row")

ns.db.settings.foeAlert = false
mock.now = mock.now + 1000
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Eq(Played(), "", "the raid warning with the foe alert off")
mock.SetUnit("nameplate1", nil)
ns.Diary.SetQuietNearby(C, false)

-- Forgetting drops the stamp.
ns.db.settings.foeAlert = true
Eq(R.FoeAlert(C, now + 5000), true, "no alert for the forget test")
ns.ForgetEverywhere(C)
ns.Diary.Add(C, { source = "test", tags = { "foe" } })
Eq(R.FoeAlert(C, now + 5001), true, "forgetting kept the foe alert's stamp")
ns.db.settings.foeAlert = false

--------------------------------------------------------------------------
Section("foes can skip the toast cooldown")

wipe(ns.db.meta.greeted)
ns.Diary.AddTag(C, "foe")
now = mock.now
R.Greet(C, now)
Eq(R.Due(C, "nearby", now + 60), nil, "a foe skipped the cooldown with the switch off")
ns.db.settings.foeToastsUncooled = true
Eq(R.Due(C, "nearby", now + 60), C, "a foe held back by the cooldown with the switch on")
Eq(R.Due(C, "group", now + 60), C, "a foe's group toast held back by the cooldown")
ns.Diary.SetQuietNearby(C, true)
Eq(R.Due(C, "nearby", now + 60), nil, "a foe marked quiet still got a nearby toast")
ns.Diary.SetQuietNearby(C, false)
ns.Diary.RemoveTag(C, "foe")
Eq(R.Due(C, "nearby", now + 60), nil, "someone no longer a foe skipped the cooldown")
ns.Diary.AddTag(C, "foe")

-- With no cooldown a nameplate that comes and goes would line the same
-- person up again and again: one toast per person, showing or waiting.
mock.SetUnit("nameplate1", PUG)
for _ = 1, 3 do mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1") end
Eq(ns.UI.ReunionShowing() and ns.UI.ReunionShowing().guid, C, "the foe's toast is not showing")
mock.RunTimers()
Eq(ns.UI.ReunionShowing(), nil, "the same foe was lined up more than once")
mock.SetUnit("nameplate1", nil)
ns.db.settings.foeToastsUncooled = false

--------------------------------------------------------------------------
Section("placing the toast")

local card = _G.SocialDiaryToastFrame
local function Escapable()
    for _, name in ipairs(UISpecialFrames) do
        if name == "SocialDiaryToastFrame" then return true end
    end
    return false
end
for _ = 1, 10 do mock.RunTimers() end
Eq(ns.UI.ReunionShowing(), nil, "a toast is still up before placing")
ns.db.settings.toastAt = nil

local reopened = false
Check(ns.UI.PlaceToast(function() reopened = true end), "placing was refused out of combat")
Check(card:IsShown() and ns.UI.PlacingToast(), "the card is not laid out to be placed")
Eq(card.heading:GetText(), "PLACING THE TOAST", "the sample card's heading")
Check(card.done:IsShown() and card.reset:IsShown(), "no Done or Reset Position on the card")
Check(Escapable(), "Escape does not end placing")

-- A toast due meanwhile waits for the card to be placed.
wipe(ns.db.meta.greeted)
local someone = next(ns.db.diary)
Check(someone, "nobody left in the diary to toast")
ns.UI.Reunion(someone, "group")
Eq(ns.UI.ReunionShowing(), nil, "a toast showed over the card being placed")

-- A click is not a dismissal while placing; a drag is kept, as an offset
-- from the top middle of the screen.
card.button:Click("LeftButton")
Check(ns.UI.PlacingToast(), "a click ended placing")
card.at, UIParent.at = { 812, 600 }, { 768, 864 }
card.button.scripts.OnDragStart(card.button)
card.button.scripts.OnDragStop(card.button)
Eq(ns.db.settings.toastAt and ns.db.settings.toastAt.x, 44, "where it was dragged across")
Eq(ns.db.settings.toastAt and ns.db.settings.toastAt.y, -264, "where it was dragged down")
card.reset:Click()
Eq(ns.db.settings.toastAt, nil, "Reset Position kept the dragged place")

-- Done: the card goes, the caller hears, and the waiting toast comes.
card.done:Click()
Check(not ns.UI.PlacingToast(), "Done did not end placing")
Check(reopened, "the caller was not told it was placed")
Check(not Escapable(), "a toast would eat Escape during play")
Check(ns.UI.ReunionShowing(), "the waiting toast did not come after placing")
mock.RunTimers()

-- Blizzard's Edit Mode lays it out too, and takes it away.
mock.EditMode(true)
Check(ns.UI.PlacingToast(), "Edit Mode did not lay the card out")
mock.EditMode(false)
Check(not ns.UI.PlacingToast(), "closing Edit Mode left the card out")

-- Escape (the frame hidden), and a fight, end it; in a fight it waits.
ns.UI.PlaceToast()
card:Hide()
Check(not ns.UI.PlacingToast(), "Escape did not end placing")
ns.UI.PlaceToast()
mock.fire("PLAYER_REGEN_DISABLED")
Check(not ns.UI.PlacingToast(), "a fight did not end placing")
mock.inCombat = true
Check(not ns.UI.PlaceToast(), "placing started in a fight")
mock.inCombat = false

-- From Settings: the book closes, and opens on Settings again after.
local settings = ns.UI.SettingsPage()
ns.UI.ShowSettings()
settings.moveToast:Click()
local book = _G.SocialDiaryJournalFrame
Check(ns.UI.PlacingToast() and not book:IsShown(), "Move the toast did not close the book for the card")
card.done:Click()
Check(book:IsShown() and settings:IsVisible(), "the book did not open on Settings again")
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("the journal map: where you met them before adding them")

Reset()
ns.db.characters = {}
mock.RunTimers()
mock.now = 1795000000
local early = mock.now

-- A stranger seen in Northshire, then an hour on in Goldshire; added after.
ns.Characters.Observe(C, { first = "Norwood", surname = "Sparks" })
ns.Sightings.Record(C, { source = "plate" }, { mapID = 1429, x = 0.487, y = 0.417 }, early)
ns.Sightings.Record(C, { source = "plate" }, { mapID = 1429, x = 0.43, y = 0.67 }, early + 3700)
-- A row with no coordinates (an instance) has nowhere to go.
ns.Sightings.Record(C, { source = "plate" }, { zone = "The Deadmines" }, early + 3800)
Eq(ns.Characters.Get(C).heat, nil, "a stranger has heat")
mock.now = early + 4000
ns.Diary.Add(C, { source = "test" })
local map = ns.Characters.Get(C).heat and ns.Characters.Get(C).heat[1429]
Check(map, "the sightings before adding left no heat")
local northshire = 20 * 50 + 24  -- row 20, column 24
Eq(map[northshire], 1, "the first meeting, in Northshire, is not on the map")
local _, _, total = ns.Heat.Cells(C, 1429)
Eq(total, 2, "each row before adding counts once")

-- Removed and added again: what was folded in is not folded in twice; a
-- row from while they were out of the diary is.
mock.now = mock.now + 60
ns.Diary.Remove(C)
mock.now = mock.now + 2 * 3600
ns.Sightings.Record(C, { source = "plate" }, { mapID = 1429, x = 0.8, y = 0.6 }, mock.now)
mock.now = mock.now + 60
ns.Diary.Add(C, { source = "test" })
_, _, total = ns.Heat.Cells(C, 1429)
Eq(total, 3, "added again, the rows were counted twice or the new one not at all")

--------------------------------------------------------------------------
Section("the toast's who line with a guild stays on the card")

Reset()
mock.RunTimers()
mock.now = mock.now + DAY
Eq(UnitFactionGroup("player"), "Horde", "the player is not Horde")
-- Guild names run to 24 characters in the client. Each case: the race and
-- class, the guild, and the line the card should take. The mock counts
-- "·" as two characters, so the whole Night Elf line is 234 px to the
-- 230 there is: it loses the race, and keeps the faction.
local WHO = {
    { { race = "NightElf", class = "WARRIOR", faction = "Alliance" }, "Knights of the Ashen Vow",
        "Level 60 Warrior  ·  Alliance" },
    { { race = "NightElf", class = "WARRIOR", faction = "Alliance" }, nil,
        "Level 60 Warrior  ·  Alliance" },
    { { race = "Tauren", class = "WARRIOR", faction = "Horde" }, "Brotherhood of the Plain",
        "Level 60 Tauren Warrior" },
    { { race = "Troll", class = "SHAMAN", faction = "Horde" }, "Kin", "Level 60 Troll Shaman  <Kin>" },
    { { race = "Scourge", class = "WARLOCK", faction = "Horde" }, nil, "Level 60 Undead Warlock" },
}
-- Where the line ends on the card: the sheet's middle plus its offset.
local function Edge(fs)
    local p = fs.recorded.points[1].args
    return 160 + p[3] + fs.width / 2
end
for i, case in ipairs(WHO) do
    local guid = ("Player-4395-0E0000%02d"):format(i)
    local info = { first = "Probe" .. i, surname = "Tester", level = 60 }
    for k, v in pairs(case[1]) do info[k] = v end
    ns.Characters.Observe(guid, info)
    ns.Diary.Add(guid, { source = "test" })
    ns.db.diary[guid].guildAtAdd = case[2]
    ns.UI.Reunion(guid, "nearby")
    local who = Plain(toast.who:GetText())
    Check(toast.who:IsShown(), "no who line for " .. case[3])
    Eq(who, case[3], "the who line taken")
    Check(Edge(toast.who) <= 300, ("%q runs off the card, to %d"):format(who, Edge(toast.who)))
    Check(not who:find("Horde"), "the player's own faction on the toast: " .. who)
    toast.button:Click("RightButton")
end

-- Shorter still, for a line that will not fit even so: without the race
-- (the portrait shows it), then the class alone, a foe's faction kept to
-- the last.
local text = ns.UI.ReunionText({
    name = "Probe Tester", reason = "nearby", timesMet = 0, guild = "Knights of the Ashen Vow",
    record = { level = 60, race = "NightElf", class = "WARRIOR", faction = "Alliance" },
})
Eq(#text.who, 4, "who lines to choose from")
Eq(Plain(text.who[1]), "Level 60 Night Elf Warrior  ·  Alliance  <Knights of the Ashen Vow>", "the whole who line")
Eq(Plain(text.who[3]), "Level 60 Warrior  ·  Alliance", "the who line without the race")
Eq(Plain(text.who[4]), "Warrior  ·  Alliance", "the shortest who line")
