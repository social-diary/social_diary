-- A fight's strip on Your Diary's plates (20 Nov 2026, the user: a foe's
-- strip should read as a fight, not as company): the foe the subject of
-- what follows ("Mika / killed you again"), counted by the play session
-- (a sitting), one phrase for several fights, the score the other way in a
-- second sentence, the spell only on a repeat, and someone inked in after
-- their fights given one strip.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local J = ns.Journey
local Text = ns.UI.JourneyText

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

local t0 = now - 7200
local MAP = 1412
J.Begin(ns.ownGUID, t0, 10, MAP)
local j = J.Mine()
j.segments = { { kind = "stop", from = t0, to = t0 + 3000, mapID = MAP, x = 0.40, y = 0.60, r = 30, seconds = 3000,
    levelFrom = 10, levelTo = 10 } }
j.open = nil
j.levels[11] = { at = t0 + 3500, mapID = MAP, x = 0.40, y = 0.60 }
-- Two evenings: the one the plate shows, and one the day before.
local DAY = 24 * 3600
j.sittings = { ("%d;%d"):format(t0 - DAY, t0 - DAY + 3000), ("%d;%d"):format(t0, t0 + 3000) }
J.Touch()

-- Words held together by no-break spaces, as the strip's short phrases are.
local function N(text) return (text:gsub(" ", "\194\160")) end

local function Person(guid, first, faction, sex, inDiary)
    ns.db.characters[guid] = { guid = guid, names = { { first = first, surname = "" } }, faction = faction, sex = sex,
        level = 20, class = "ROGUE", race = "Human" }
    if inDiary then ns.db.diary[guid] = { tags = {}, addedAt = now } end
end
local MIKA, ALLY, KOR, LATE, STRANGER = "Player-1-0F160001", "Player-1-0F160002", "Player-1-0F160003",
    "Player-1-0F160004", "Player-1-0F160005"
Person(MIKA, "Mika", "Alliance", 3, true)
Person(ALLY, "Ally", "Horde", 2, true)
Person(KOR, "Kor", "Alliance", 2, true)
Person(LATE, "Late", "Alliance", 2, false)
Person(STRANGER, "Grim", "Alliance", 2, false)

-- A fight mark (the diary person's GUID on it only where they are in the
-- diary, as Journey.Fight keeps it) and its moment.
local function Mark(t, outcome, guid, x)
    local mark = { t = t, kind = "fight", outcome = outcome, mapID = MAP, x = x or 0.41, y = 0.60,
        guid = guid and ns.Diary.IsDiary(guid) and guid or nil }
    j.marks[#j.marks + 1] = mark
    return mark
end
local function Moment(mark) return { kind = "fight", outcome = mark.outcome, t = mark.t, mark = mark, guid = mark.guid } end
local function Words(moments, who)
    return Text.MarginWhat(moments, 10, { who = who, j = j, index = J.FightIndex() })
end

--------------------------------------------------------------------------
Section("the words: the first plain, a repeat counted that evening")

j.marks = {}
local a = Mark(t0 + 100, "lost", MIKA)
Eq(Words({ Moment(a) }, MIKA), N("killed you"), "the first death of the evening")
local b = Mark(t0 + 200, "lost", MIKA)
Eq(Words({ Moment(b) }, MIKA), N("killed you again"), "the second")
Mark(t0 + 300, "lost", MIKA)
local d = Mark(t0 + 400, "lost", MIKA)
Eq(Words({ Moment(d) }, MIKA), "killed you for the fourth time", "the fourth")
-- Two on the plate are one phrase, the latest's count.
Eq(Words({ Moment(a), Moment(b) }, MIKA), N("killed you again"), "two on a plate fold into one")
-- The evening before does not count.
j.marks = {}
Mark(t0 - DAY + 100, "lost", MIKA)
Mark(t0 - DAY + 200, "lost", MIKA)
local fresh = Mark(t0 + 100, "lost", MIKA)
Eq(Words({ Moment(fresh) }, MIKA), N("killed you"), "a new evening starts plain")
Eq(Words({ Moment(j.marks[2]) }, MIKA), N("killed you again"), "the evening before counted on its own")

Section("the words: won, both ways, the score the other way")

j.marks = {}
local w1 = Mark(t0 + 100, "won", MIKA)
Eq(Words({ Moment(w1) }, MIKA), N("fell to you"), "won once")
local w2 = Mark(t0 + 200, "won", MIKA)
Eq(Words({ Moment(w2) }, MIKA), N("fell to you again"), "won again")
Mark(t0 + 300, "won", MIKA)
Eq(Words({ Moment(j.marks[3]) }, MIKA), "fell to you for the third time", "won a third time")
local l1 = Mark(t0 + 400, "lost", MIKA)
Eq(Words({ Moment(l1) }, MIKA), N("killed you") .. ". You killed them three times.",
    "the score the other way, in words")
local l2 = Mark(t0 + 500, "lost", MIKA)
Eq(Words({ Moment(l2) }, MIKA), N("killed you again") .. ". You killed them three times.", "and again")
j.marks = {}
local x1, x2 = Mark(t0 + 100, "won", MIKA), Mark(t0 + 200, "lost", MIKA)
Eq(Words({ Moment(x2) }, MIKA), N("killed you") .. ". You killed them once.", "once")
local x3 = Mark(t0 + 300, "won", MIKA)
Eq(Words({ Moment(x3) }, MIKA), N("fell to you again") .. ". They killed you once.", "their side, won after")
Mark(t0 + 50, "won", MIKA)
local x4 = Mark(t0 + 400, "lost", MIKA)
Eq(Words({ Moment(x4) }, MIKA), N("killed you again") .. ". You killed them three times.", "three")
j.marks = {}
local y1, y2 = Mark(t0 + 100, "won", MIKA), Mark(t0 + 150, "won", MIKA)
local y3 = Mark(t0 + 200, "lost", MIKA)
Eq(Words({ Moment(y3) }, MIKA), N("killed you") .. ". You killed them twice.", "twice")
-- Both ways on one plate: in their order.
Eq(Words({ Moment(y2), Moment(y3) }, MIKA), "fell to you, then killed you", "won, then lost, in order")
Eq(Words({ Moment(y3), Moment(y2) }, MIKA), "fell to you, then killed you", "the order is by time, not by the list")
j.marks = {}
local z1, z2 = Mark(t0 + 100, "lost", MIKA), Mark(t0 + 200, "won", MIKA)
Eq(Words({ Moment(z1), Moment(z2) }, MIKA), "killed you, then fell to you", "killed, then fell")
Check(not Words({ Moment(z1), Moment(z2) }, MIKA):find(" and "), "two fights said with and")

Section("the words: a stranger counted through the buffer, else plain")

j.marks = {}
local s1, s2 = Mark(t0 + 100, "lost", nil), Mark(t0 + 200, "lost", nil)
Eq(Words({ Moment(s2) }, nil), N("killed you"), "a stranger the buffer has let go is plain")
ns.db.interactions[STRANGER] = { { type = "pvp_death", time = s1.t, context = {} },
    { type = "pvp_death", time = s2.t, context = {} } }
Eq(J.FightWho(s2, J.FightIndex()), STRANGER, "setup: the buffer has them")
Eq(Words({ Moment(s2) }, STRANGER), N("killed you again"), "a stranger matched in the buffer is counted")

Section("the words: the spell, only on a repeat, and only where it fits")

ns.db.interactions[STRANGER] = { { type = "pvp_death", time = s1.t, context = { spell = "Ambush" } },
    { type = "pvp_death", time = s2.t, context = { spell = "Backstab" } } }
Eq(Words({ Moment(s1) }, STRANGER), N("killed you"), "a spell on the first death")
local said, shorter = Words({ Moment(s2) }, STRANGER)
Eq(said, "killed you again, with Backstab", "the spell on a repeat")
Eq(shorter and shorter[1], N("killed you again"), "without it, where it does not fit")
local s3 = Mark(t0 + 300, "lost", nil)
ns.db.interactions[STRANGER][3] = { type = "pvp_death", time = s3.t, context = { spell = "Ambush" } }
Eq((Words({ Moment(s3) }, STRANGER)), "killed you for the third time, with Ambush", "the spell on a third")
ns.db.interactions[STRANGER] = nil
-- Whole strip: a what too long for its lines takes the shorter form.
do
    local strip = ns.UI.PaperStrip(UIParent)
    strip:SetNote({ name = "Mika", what = "killed you again, with Shadowstrike of the Long Night",
        whats = { "killed you again" } })
    strip:Layout(0, 0, 60)
    Eq(strip:What(), "killed you again", "the strip did not give up the spell")
    strip:SetNote({ name = "Mika", what = "killed you again, with Ambush", whats = { "killed you again" } })
    strip:Layout(0, 0, 200)
    Eq(strip:What(), "killed you again, with Ambush", "the strip gave up a spell that fits")
    strip:Hide()
end

--------------------------------------------------------------------------
Section("on the page: a foe's strip, a friend's, company and a fight")

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()

local function Open()
    J.Touch()
    ns.UI.RefreshJourneyPage(true)
    for i, e in ipairs(page.recap.entries) do
        if e.level == 10 then T.OpenDiaryPage(page, i) end
    end
end
local function Strips()
    local list = {}
    for i = 1, page.notePool.used do
        local strip = page.notePool[i]
        if strip:IsShown() then list[#list + 1] = strip end
    end
    return list
end
local function Strip(name)
    for _, strip in ipairs(Strips()) do
        if strip.name:GetText() == name then return strip end
    end
end
local function Caption()
    local all = {}
    for i = 1, page.captionPool.used do all[#all + 1] = page.captionPool[i]:GetText() or "" end
    return table.concat(all, " ")
end

-- The other faction, only fights here: their name alone.
j.marks = {}
Mark(t0 + 100, "lost", MIKA)
Mark(t0 + 200, "lost", MIKA, 0.42)
Open()
local mika = Strip("Mika")
Check(mika ~= nil, "a foe's strip is not headed by their name alone")
Eq(mika and mika:What(), N("killed you again"), "a foe's two deaths")
Eq(mika and mika.guid, MIKA, "a foe's name does not open their page")
Eq(#Strips(), 1, "one strip for two fights")
Check(mika and mika.fightBlood ~= nil, "the blood went")
Eq(Strip("with Mika"), nil, "a foe written as company")

-- The same faction: still "with".
j.marks = {}
Mark(t0 + 100, "lost", ALLY)
Open()
Check(Strip("with Ally") ~= nil, "a friend's fight strip is not with them")
Eq(Strip("with Ally") and Strip("with Ally"):What(), N("killed you"), "a friend's fight")

-- Unknown faction: only fights here will do.
ns.db.characters[ALLY].faction = nil
Open()
Check(Strip("Ally") ~= nil, "unknown faction, only fights: not their name alone")
ns.db.characters[ALLY].faction = "Horde"

-- Company and a fight: "with", the fight after it.
j.marks = {}
Mark(t0 + 2500, "lost", KOR)
ns.Sessions.New({ me = SELF.guid, source = "group", startedAt = t0 + 300, endedAt = t0 + 2400,
    participants = { [KOR] = { since = t0 + 300, last = t0 + 2400, seconds = 2100, levelStart = 10 } } })
Open()
local kor = Strip("with Kor")
Check(kor ~= nil, "a foe you spent time with is not with them")
Eq(kor and kor:What(), "35\194\160min together, then " .. N("killed you"), "company, then the fight")

--------------------------------------------------------------------------
Section("on the page: someone inked in after their fights, one strip")

j.marks = {}
local m1, m2 = Mark(t0 + 100, "lost", LATE), Mark(t0 + 200, "lost", LATE, 0.43)
Eq(m1.guid, nil, "setup: not in the diary at the fight")
ns.db.interactions[LATE] = { { type = "pvp_death", time = m1.t, context = {} },
    { type = "pvp_death", time = m2.t, context = { spell = "Ambush" } } }
Open()
local before = 0
for _, strip in ipairs(Strips()) do
    if strip:What():find("killed") then before = before + 1 end
end
Eq(before, 2, "setup: a stranger's fights are a strip each")
Check(not Caption():find("fight"), "the caption tells the strangers' fights again: " .. Caption())
ns.db.diary[LATE] = { tags = {}, addedAt = now }
Open()
local late = Strip("Late")
Check(late ~= nil, "someone inked in since has no strip of their own")
local fightStrips = 0
for _, strip in ipairs(Strips()) do
    if strip:What():find("killed") then fightStrips = fightStrips + 1 end
end
Eq(fightStrips, 1, "their fights are not one strip")
Eq(late and late:What(), "killed you again, with Ambush", "their fights, counted, the spell on the repeat")
Eq(page.notesWritten, 2, "one note written for them, one for Kor's time together")
Check(not Caption():find("fight") and not Caption():find("Late"), "the caption tells them again: " .. Caption())
for _, m in ipairs(page.plates[1].moments or {}) do
    if m.kind == "fight" then Eq(m.guid, nil, "a moment's GUID changed") end
end
ns.db.diary[LATE], ns.db.interactions[LATE] = nil, nil

--------------------------------------------------------------------------
Section("a first sighting or a crossed path is not company")

do
    local fight = Moment(Mark(t0 + 100, "lost", MIKA))
    local first = { kind = "first", guid = MIKA, metLevel = 12, t = t0 + 50 }
    local crossed = { kind = "crossed", guid = MIKA, t = t0 + 60 }
    local session = { kind = "session", guid = KOR, seconds = 2100 }
    local gift = { kind = "find", person = { tier = 1, say = function() return "gave you your first blue" end } }
    local seen = { kind = "find", person = { tier = 2, say = function() return "saw your first blue" end } }
    Eq(Text.HasCompany({ fight, first, crossed }), false, "a first sighting or a crossed path counted as company")
    Eq(Text.HasCompany({ fight, session }), true, "time together not company")
    Eq(Text.HasCompany({ fight, gift }), true, "a gift not company")
    Eq(Text.HasCompany({ seen }), false, "a tier 2 moment counted as company")
    j.marks = { fight.mark }
    -- A foe (or a stranger, or a friend) with a fight: the fight is the
    -- story, the first sighting not said.
    Eq((Words({ fight, first }, MIKA)), N("killed you"), "a fight and a first sighting")
    Eq((Words({ fight, crossed }, MIKA)), N("killed you"), "a fight and a crossed path")
    Eq((Words({ { kind = "fight", outcome = "lost", t = t0 + 100 }, first }, nil)), N("killed you"),
        "a stranger's fight and first sighting")
    Eq((Words({ fight, seen }, MIKA)), N("killed you"), "a tier 2 moment said before a fight")
    -- Company and a fight: the first sighting is not joined on either.
    Eq((Words({ session, fight, first }, MIKA)), "35\194\160min together, then " .. N("killed you"),
        "company, a fight and a first sighting")
    Eq((Words({ gift, fight }, MIKA)), "gave you your first blue, then " .. N("killed you"), "a gift, then a fight")
    -- No fight: as before.
    Eq((Words({ first }, MIKA)), "first seen, and you'd meet again at level 12", "a first sighting alone")
    Eq((Words({ session, first }, MIKA)), "35\194\160min together and first seen, and you'd meet again at level 12",
        "time together and a first sighting")
end

Section("on the page: a foe first seen here, a friend first seen here")

do
    for _, guid in ipairs({ MIKA, ALLY }) do
        ns.db.characters[guid].firstSeen = t0 + 50
        ns.db.diary[guid].addedAt = now
    end
    j.marks = {}
    Mark(t0 + 100, "lost", MIKA)
    Open()
    local firstHere = false
    for _, m in ipairs(page.plates[1].people or {}) do
        if m.kind == "first" and m.guid == MIKA then firstHere = true end
    end
    Check(firstHere, "setup: Mika's first sighting is not on the plate")
    local mika = Strip("Mika")
    Check(mika ~= nil, "a foe first seen here is not headed by their name alone")
    Eq(mika and mika:What(), N("killed you"), "a foe first seen here: more than the fight")
    Eq(Strip("with Mika"), nil, "a foe first seen here written as company")
    -- The same faction: still with them, the fight alone said.
    j.marks = {}
    Mark(t0 + 100, "lost", ALLY)
    Open()
    local ally = Strip("with Ally")
    Check(ally ~= nil, "a friend first seen here is not with them")
    Eq(ally and ally:What(), N("killed you"), "a friend first seen here: more than the fight")
    for _, guid in ipairs({ MIKA, ALLY }) do ns.db.characters[guid].firstSeen = nil end
end
