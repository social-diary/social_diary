-- A feature's own kind of card on the reunion toast (Toast.RegisterKind,
-- SD_TOAST; UI/Windows/Reunion/Queue.lua): it shows for a stranger, by its
-- own rule and switch, once in line, behind the combat gate, gone when its
-- person is forgotten; a flood of it never says a reunion's words; and the
-- reunions themselves go on as before.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

mock.RunTimers()
mock.now = 1792000000
ns._test.SettleGroup()

local Toast = ns.UI.Toast

-- A diary entry, and strangers: seen, never written in.
local function Person(i, first)
    local guid = ("Player-4395-0E1000%02d"):format(i)
    ns.Characters.Observe(guid, { first = first, surname = "Tinkerly", level = 14, class = "WARRIOR" })
    return guid
end
local FRIEND = Person(1, "Odalric")
ns.Diary.Add(FRIEND, { source = "test" })
local STRANGER, OTHER = Person(2, "Wenna"), Person(3, "Pell")

-- The kind under test: everything it was asked, and whether it is due.
local due, asked, snapped = true, 0, 0
local KIND = "testmade"
ns.db.settings.testMadeToasts = true
Toast.RegisterKind(KIND, {
    setting = "testMadeToasts",
    due = function(guid, data, now)
        asked = asked + 1
        return due
    end,
    snapshot = function(guid, data, now)
        snapped = snapped + 1
        local record = ns.Characters.Get(guid)
        if not record then return nil end
        return { name = ns.Characters.FullName(guid) or "?", record = record, item = data }
    end,
    text = function(snap)
        return { heading = "Test made heading", name = snap.name,
            stories = { "Test story about the " .. tostring(snap.item) .. "." } }
    end,
    more = function(count)
        return { heading = "Test made flood", name = "and " .. count .. " more",
            stories = { "Test flood story." } }
    end,
})

local card
local function Showing() return ns.UI.ReunionShowing() end
local function Fight()
    mock.inCombat = true
    mock.fire("PLAYER_REGEN_DISABLED")
end
local function Peace()
    mock.inCombat = false
    mock.fire("PLAYER_REGEN_ENABLED")
end
local function Clear()
    for _ = 1, 30 do mock.RunTimers() end
    wipe(ns.db.meta.greeted)
    Eq(Showing(), nil, "a toast left from before")
    Eq(#Toast.queue, 0, "a toast left in line")
end

--------------------------------------------------------------------------
Section("a registered kind shows for a stranger")

Eq(ns.Diary.Get(STRANGER), nil, "the stranger has a diary entry")
ns.Fire("SD_TOAST", KIND, STRANGER, "boots")
local snap = Showing()
Check(snap and snap.kind == KIND, "the kind's card is not up")
Eq(snap and snap.guid, STRANGER, "the card is about someone else")
Eq(snap and snap.key, "boots", "the card's key")
card = _G.SocialDiaryToastFrame
Check(card and card:IsShown(), "the card is not on the screen")
Eq(card.heading:GetText(), "TEST MADE HEADING", "the kind's heading")
Eq(card.name:GetText(), "WENNA TINKERLY", "the kind's name")
Eq(card.lines[1]:GetText(), "Test story about the boots.", "the kind's story")
Check(not card.tags:IsShown() and not card.relationship:IsShown(), "a reunion's tags or relationship on a kind's card")
Check(not card.who:IsShown(), "a who line the kind did not give")
-- A click opens the stranger's glimpse, not an error.
card.button.scripts.OnClick(card.button, "LeftButton")
Eq(Showing(), nil, "the click did not put the card away")
ns.UI.CloseJournal()
Clear()

-- Nothing to snapshot, nothing shown; unknown kinds and non-players dropped.
ns.Fire("SD_TOAST", KIND, "Player-4395-0E1000FF", "boots")
Eq(Showing(), nil, "a card with no snapshot")
ns.Fire("SD_TOAST", "nosuchkind", STRANGER)
Eq(Showing(), nil, "an unregistered kind showed")
ns.Fire("SD_TOAST", KIND, "Creature-0-1-2-3-4-5", "boots")
Eq(Showing(), nil, "a creature's card showed")
Clear()

--------------------------------------------------------------------------
Section("its own rule and its own switch")

due = false
asked, snapped = 0, 0
ns.Fire("SD_TOAST", KIND, STRANGER, "boots")
Eq(Showing(), nil, "a card not due showed")
Eq(asked, 1, "due was not asked")
Eq(snapped, 0, "a card not due was snapshot")
due = true

ns.db.settings.testMadeToasts = false
ns.Fire("SD_TOAST", KIND, STRANGER, "boots")
Eq(Showing(), nil, "a card switched off showed")
Eq(asked, 1, "due was asked of a kind switched off")
ns.db.settings.testMadeToasts = true

-- None of a reunion's rules: a stranger on the cooldown, the reunion
-- switches off, still gets the kind's card.
ns.db.meta.greeted[STRANGER] = ns.Now()
local toasts = ns.db.settings.toasts
ns.db.settings.toasts, ns.db.settings.nearbyToasts = false, false
ns.Fire("SD_TOAST", KIND, STRANGER, "boots")
Check(Showing() and Showing().kind == KIND, "a reunion's rule held a kind's card")
ns.db.settings.toasts, ns.db.settings.nearbyToasts = toasts, true
Clear()

--------------------------------------------------------------------------
Section("in line once")

asked = 0
ns.Fire("SD_TOAST", KIND, STRANGER, "boots")
ns.Fire("SD_TOAST", KIND, STRANGER, "boots")   -- while it shows
ns.Fire("SD_TOAST", KIND, OTHER, "boots")
ns.Fire("SD_TOAST", KIND, OTHER, "boots")      -- while it waits
Eq(#Toast.queue, 1, "a duplicate was queued")
Eq(asked, 2, "due was asked of a duplicate")
ns.Fire("SD_TOAST", KIND, OTHER, "gloves")     -- another key: another card
Eq(#Toast.queue, 2, "another key was taken for a duplicate")
-- A reunion with the same person waiting is no duplicate of theirs.
ns.UI.Reunion(FRIEND)
ns.Fire("SD_TOAST", KIND, FRIEND, "boots")
Eq(#Toast.queue, 4, "a reunion and a kind's card for one person did not both queue")
Clear()

--------------------------------------------------------------------------
Section("the combat gate holds it")

Fight()
ns.Fire("SD_TOAST", KIND, STRANGER, "boots")
Eq(Showing(), nil, "a kind's card showed in a fight")
Eq(#Toast.queue, 1, "a kind's card was not held for the fight")
Peace()
Eq(Showing() and Showing().guid, STRANGER, "the held card did not come after the fight")
-- The card up when a fight starts goes, and comes again first.
ns.Fire("SD_TOAST", KIND, OTHER, "boots")
Fight()
Check(not card:IsShown(), "the kind's card stayed in a fight")
Eq(Toast.queue[1] and Toast.queue[1].guid, STRANGER, "the card up did not go back first in line")
Peace()
Eq(Showing() and Showing().guid, STRANGER, "the card put back did not come first")
Clear()

--------------------------------------------------------------------------
Section("forgetting takes it away")

ns.Fire("SD_TOAST", KIND, OTHER, "boots")
ns.Fire("SD_TOAST", KIND, STRANGER, "boots")
Eq(#Toast.queue, 1, "the card did not wait")
ns.Characters.Forget(STRANGER)
Eq(#Toast.queue, 0, "a forgotten stranger's card still waits")
ns.Characters.Forget(OTHER)
Eq(Showing(), nil, "a forgotten stranger's card still shows")
Clear()

STRANGER, OTHER = Person(4, "Wenna"), Person(5, "Pell")

--------------------------------------------------------------------------
Section("a flood mixing kinds says each its own words")

local crowd = {}
for i = 1, 7 do
    crowd[i] = Person(10 + i, "Crowd" .. i)
    ns.Diary.Add(crowd[i], { source = "test" })
end
local makers = {}
for i = 1, 3 do makers[i] = Person(30 + i, "Maker" .. i) end

for i = 1, 6 do ns.UI.Reunion(crowd[i]) end      -- one shows, five wait
ns.UI.Reunion(crowd[7])                           -- the reunions' overflow
for i = 1, 3 do ns.Fire("SD_TOAST", KIND, makers[i], "boots") end  -- the kind's
Eq(Toast.more, 1, "the reunions' overflow")
Eq(Toast.moreKinds[KIND], 3, "the kind's overflow")

local seen = {}
while Showing() and #seen < 20 do
    seen[#seen + 1] = { snap = Showing(), heading = card.heading:GetText(), name = card.name:GetText() }
    mock.RunTimers()
end
Eq(#seen, 8, "cards in the flood")
local last, before = seen[#seen], seen[#seen - 1]
Eq(before.snap.more, 1, "the reunions' summary is not second last")
Eq(before.snap.kind, nil, "the reunions' summary is a kind's")
Eq(before.heading, "JOINED YOUR GROUP", "the reunions' summary's heading")
Eq(last.snap.more, 3, "the kind's summary is not last")
Eq(last.snap.kind, KIND, "the kind's summary is not the kind's")
Eq(last.heading, "TEST MADE FLOOD", "the kind's summary said other words")
Eq(last.name, "AND 3 MORE", "the kind's summary's count")
Clear()

-- Its summary up when a fight starts goes back into its own count.
for i = 1, 6 do ns.UI.Reunion(crowd[i]) end      -- one shows, five wait
ns.Fire("SD_TOAST", KIND, makers[1], "boots")
ns.Fire("SD_TOAST", KIND, makers[2], "boots")
for _ = 1, 6 do mock.RunTimers() end
Eq(Showing() and Showing().kind, KIND, "the kind's summary is not up")
Fight()
Eq(Toast.moreKinds[KIND], 2, "the kind's summary did not go back into its count")
Eq(Toast.more, 0, "the kind's summary went into the reunions' count")
Peace()
Eq(card.heading:GetText(), "TEST MADE FLOOD", "the kind's summary came back with other words")
Clear()

-- A kind with no summary of its own is never folded into a count.
Toast.RegisterKind("testplain", {
    snapshot = function(guid) return { name = "Plain" } end,
    text = function(snap) return { heading = "Test plain", name = snap.name, stories = { "Plain." } } end,
})
for i = 1, 6 do ns.UI.Reunion(crowd[i]) end
ns.Fire("SD_TOAST", "testplain", makers[1])
Eq(#Toast.queue, 6, "a kind with no summary was not let past the cap")
Eq(Toast.moreKinds.testplain, nil, "a kind with no summary was counted")
Clear()

--------------------------------------------------------------------------
Section("the reunion path is as it was")

ns.UI.Reunion(FRIEND)
local r = Showing()
Check(r and r.kind == nil and r.guid == FRIEND, "the reunion did not show")
Eq(card.heading:GetText(), "JOINED YOUR GROUP", "the reunion's heading")
Eq(card.name:GetText(), "ODALRIC TINKERLY", "the reunion's name")
ns.UI.Reunion(FRIEND)
Eq(#Toast.queue, 0, "the cooldown did not hold the reunion")
Clear()
