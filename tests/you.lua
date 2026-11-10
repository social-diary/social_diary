-- "You" in a record's words (Format.You, UI/Words/Format.lua): the
-- character playing is "you"; in a shared diary another of the user's
-- characters is named, so a line from an alt says whose it was.

local T = ...
local F = T.F
local Section, Eq = T.Section, T.Eq
local ns = T.Boot()

local Format = ns.UI.Format
local You = Format.You
local SELF, STRANGER = F.SELF, F.STRANGER

local ALT = "Player-4707-0A17A17A"
ns.OwnCharacters()[ALT] = { first = "Thessaly", surname = "Vane" }
ns.db.characters[STRANGER.guid] = { guid = STRANGER.guid, names = { { first = "Bram", surname = "Redfen" } } }

-- A row's line on Bram's timeline, as the page asks for it.
local function Line(kind, me, context, extra)
    local row = { type = kind, me = me, time = ns.Now(), zone = "Mulgore", context = context }
    for key, value in pairs(extra or {}) do row[key] = value end
    return ns.Rows.Get(kind).text(row, STRANGER.guid)
end

local function Death(guid)
    local _, text = ns.UI.DescribeItem({ kind = "death", time = ns.Now(),
        death = { guid = guid, zone = "Mulgore", killer = { name = "Plainstrider", source = "recap" } } },
        STRANGER.guid)
    return text
end

--------------------------------------------------------------------------
Section("a diary of its own: always you")

ns.diaryShared = false
Eq(You(ALT, "{You} killed Bram"), "You killed Bram", "an alt was named in a diary of its own")
Eq(You(SELF.guid, "Bram saved {you}"), "Bram saved you", "the braces were left in")
Eq(Line("pvp_kill", ALT), "You killed Bram in Mulgore", "a kill in a diary of its own")

--------------------------------------------------------------------------
Section("a shared diary: the one playing is you, an alt by name")

ns.diaryShared = true
Eq(You(SELF.guid, "{You} killed Bram"), "You killed Bram", "the one playing was named")
Eq(You(nil, "{Your} group killed Bram"), "Your group killed Bram", "a row from before `me` was named")
Eq(You("Player-4707-0BADBAD0", "{You} killed Bram"), "You killed Bram", "a nameless character")

Eq(You(ALT, "{You} killed Bram"), "Thessaly killed Bram", "subject")
Eq(You(ALT, "Bram saved {you}"), "Bram saved Thessaly", "object")
Eq(You(ALT, "{Your} group killed Bram"), "Thessaly's group killed Bram", "possessive")
Eq(You(ALT, "{You've} met twice"), "Thessaly has met twice", "you've")
Eq(You(ALT, "{you're} nearby"), "Thessaly is nearby", "you're")
Eq(You(ALT, "{You were} there"), "Thessaly was there", "you were")
Eq(You(ALT, "{them}"), "them", "an unknown word kept its braces")

-- Each row kind that speaks of the user.
Eq(Line("pvp_kill", ALT), "Thessaly killed Bram in Mulgore", "pvp_kill")
Eq(Line("pvp_kill", ALT, { by = STRANGER.guid }), "Thessaly's group killed Bram in Mulgore (Bram's killing blow)",
    "pvp_kill by the group")
Eq(Line("pvp_death", ALT, { probable = true }), "Bram probably killed Thessaly in Mulgore", "pvp_death")
Eq(Line("pvp_death", SELF.guid), "Bram killed you in Mulgore", "pvp_death, the one playing")
Eq(Line("whisper_out", ALT, nil, { excerpt = "hi" }), 'Thessaly whispered: "hi"', "whisper_out")
Eq(Line("watched_death", ALT), "Bram watched Thessaly die in Mulgore", "watched_death")
Eq(Line("tried_to_help", ALT), "Bram tried to save Thessaly in Mulgore", "tried_to_help")
Eq(Line("saved_you", ALT, { pct = 6 }), "Bram saved Thessaly at 6%\194\160health in Mulgore", "saved_you")
Eq(Line("campfire", ALT), "Thessaly and Bram sat by a campfire together in Mulgore", "campfire")
Eq(Line("duel_series", ALT, { won = 2, fled = 1 }), "Won 2 duels against Bram and lost 1 in Mulgore"
    .. ", and Thessaly fled once", "duel")

Eq(Death(ALT), "Thessaly died to Plainstrider near Mulgore", "a death on the timeline")
Eq(Death(SELF.guid), "You died to Plainstrider near Mulgore", "a death on the timeline, the one playing")
Eq(Death(STRANGER.guid), "Bram died to Plainstrider near Mulgore", "their death")

--------------------------------------------------------------------------
Section("no bare you in an alt's lines: every row kind, and /sd testdata")

-- A "you" word outside a quote: a line that skipped Format.You. Chat keeps
-- what was said, which may say "you" to anyone.
local function Bare(text)
    if type(text) ~= "string" then return nil end
    local plain = text:gsub('"[^"]*"', ""):lower()
    return plain:match("%f[%a]you%f[%A]") or plain:match("%f[%a]your%f[%A]")
        or plain:match("%f[%a]yours%f[%A]")
end

local function NoYou(text, what)
    Eq(Bare(text), nil, what .. " says you for another character: " .. tostring(text))
end

-- Every kind's words on a row the alt wrote, with a context rich enough to
-- reach each branch a kind has, and with none.
local RICH = { by = STRANGER.guid, probable = true, spell = "Ambush", pct = 6, watched = 6, won = 2, lost = 1,
    fled = 1, theyFled = 1, last = "fled", level = 12, raid = true, subZone = "Red Cloud Mesa",
    name = "Plainstrider" }
for _, kind in ipairs(ns.Rows.All()) do
    if ns.Rows.Get(kind).text then
        NoYou(Line(kind, ALT, RICH, { excerpt = "hi" }), kind)
        NoYou(Line(kind, ALT, {}), kind .. " (bare)")
        NoYou(Line(kind, ALT, nil), kind .. " (no context)")
    end
end

-- The test entry and the features' strangers, written by the character
-- playing; then another character plays, and all of it is the alt's.
T.BlankDiary()
SlashCmdList.SOCIALDIARY("testdata")
ns.UI.CloseJournal()
local playing = ns.ownGUID
ns.ownGUID = ALT

local function Describe(item, guid, what)
    local _, text, sub, _, full = ns.UI.DescribeItem(item, guid)
    NoYou(text, what)
    NoYou(sub, what .. "'s details")
    NoYou(full, what .. "'s tooltip")
    for _, child in ipairs(item.all or {}) do Describe(child, guid, what .. " > " .. tostring(child.kind)) end
end

local people = 0
for guid in pairs(ns.db.interactions) do
    people = people + 1
    for _, item in ipairs(ns.Timeline.For(guid)) do Describe(item, guid, tostring(item.kind)) end
end
T.Check(people > 1, "/sd testdata wrote nobody's rows")

ns.ownGUID = playing
SlashCmdList.SOCIALDIARY("testdata remove")
ns.UI.CloseJournal()

ns.diaryShared = false
ns.OwnCharacters()[ALT] = nil
ns.db.characters[STRANGER.guid] = nil
