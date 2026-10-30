-- REU-2 for what is already out when a fight starts: the card showing goes
-- and comes again after, its old timers none the wiser; placing ends, and
-- what was to run after (Settings' book) waits for the fight's end.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

mock.RunTimers()
mock.now = 1792000000
ns._test.SettleGroup()

local function Person(i)
    local guid = ("Player-4395-0E0000%02d"):format(i)
    ns.Characters.Observe(guid, { first = "Fighter" .. i, surname = "Tester", level = 10 })
    ns.Diary.Add(guid, { source = "test" })
    return guid
end
local A, B = Person(1), Person(2)

local function Fight()
    mock.inCombat = true
    mock.fire("PLAYER_REGEN_DISABLED")
end
local function Peace()
    mock.inCombat = false
    mock.fire("PLAYER_REGEN_ENABLED")
end
-- Everything out of the way between sections.
local function Clear()
    for _ = 1, 20 do mock.RunTimers() end
    wipe(ns.db.meta.greeted)
    Eq(ns.UI.ReunionShowing(), nil, "a toast left from before")
end

--------------------------------------------------------------------------
Section("the card showing when a fight starts")

ns.UI.Reunion(A)
ns.UI.Reunion(B)
local card = _G.SocialDiaryToastFrame
local first = ns.UI.ReunionShowing()
Eq(first.guid, A, "the first toast")

-- Its seven seconds are running when the fight starts.
Fight()
Eq(ns.UI.ReunionShowing(), nil, "the card stayed in the fight")
Check(not card:IsShown(), "the card is still on the screen")
mock.RunTimers()
Check(not card:IsShown(), "a timer brought a card up in the fight")

-- It comes first, before the one that was waiting. The old timer ran above;
-- one left to run now must not take the card for its own.
Peace()
Eq(ns.UI.ReunionShowing() and ns.UI.ReunionShowing().guid, A, "the card did not come back first")
Check(card:IsShown(), "the card is not on the screen after the fight")
mock.RunTimers()
Eq(ns.UI.ReunionShowing() and ns.UI.ReunionShowing().guid, B, "the card's own time did not put it away")
Clear()

-- A timer from the first showing still due in the second: the same snapshot
-- is up again, and must not be taken for its own.
ns.UI.Reunion(A)
local firstTimers = mock.timers
mock.timers = {}
Fight()
Peace()
for _, timer in ipairs(firstTimers) do timer.fn() end
Eq(ns.UI.ReunionShowing() and ns.UI.ReunionShowing().guid, A, "the first showing's timer put the second away")
Clear()

-- The same for the linger after the mouse leaves a card past its time.
ns.UI.Reunion(A)
card.button.scripts.OnEnter(card.button)
mock.RunTimers()
card.button.scripts.OnLeave(card.button)
firstTimers = mock.timers
mock.timers = {}
Fight()
Peace()
for _, timer in ipairs(firstTimers) do timer.fn() end
Eq(ns.UI.ReunionShowing() and ns.UI.ReunionShowing().guid, A, "the first showing's linger put the second away")
Clear()

-- The mouse on it does not hold it in a fight, and is forgotten after.
ns.UI.Reunion(A)
card.button.scripts.OnEnter(card.button)
mock.RunTimers()
Check(card:IsShown(), "the mouse did not hold the card")
Fight()
Check(not card:IsShown(), "the mouse held the card in a fight")
Peace()
Eq(ns.UI.ReunionShowing().guid, A, "the held card did not come back")
mock.RunTimers()
Eq(ns.UI.ReunionShowing(), nil, "the mouse from before the fight still holds the card")
Clear()

-- Nobody is lost at a full queue, and "and N more" goes back to the count,
-- to come last and once.
local crowd = {}
for i = 1, 7 do crowd[i] = Person(10 + i) end
for i = 1, 7 do ns.UI.Reunion(crowd[i]) end
Eq(#ns.UI.Toast.queue, 5, "the queue before the fight")
Fight()
Eq(#ns.UI.Toast.queue, 6, "the card did not go back in a full queue")
Eq(ns.UI.Toast.more, 1, "the overflow changed")
Peace()
local seen = {}
while ns.UI.ReunionShowing() and #seen < 20 do
    seen[#seen + 1] = ns.UI.ReunionShowing()
    mock.RunTimers()
end
Eq(#seen, 7, "toasts shown after a fight at a full queue")
Eq(seen[1].guid, crowd[1], "the card put back was not first")
Eq(seen[7].more, 1, "the summary was not last")
Clear()

for i = 1, 7 do ns.UI.Reunion(crowd[i]) end
for _ = 1, 6 do mock.RunTimers() end
Eq(ns.UI.ReunionShowing().more, 1, "the summary is not up")
ns.UI.Reunion(A)  -- behind the summary, in line
Fight()
Eq(ns.UI.Toast.more, 1, "the summary did not go back into the count")
Eq(#ns.UI.Toast.queue, 1, "the summary went in the queue")
Peace()
Eq(ns.UI.ReunionShowing().guid, A, "the summary came before the person in line")
mock.RunTimers()
Eq(ns.UI.ReunionShowing().more, 1, "the summary did not come after")
Clear()

-- Forgetting someone put back takes them out of the line as well.
ns.UI.Reunion(A)
Fight()
ns.Characters.Forget(A)
Peace()
Eq(ns.UI.ReunionShowing(), nil, "a forgotten person came back after the fight")
Clear()

--------------------------------------------------------------------------
Section("a fight ends placing, and the book waits for its end")

local done = 0
local function Done() done = done + 1 end

Check(ns.UI.PlaceToast(Done), "placing was refused")
Fight()
Check(not ns.UI.PlacingToast(), "a fight did not end placing")
Eq(done, 0, "onDone ran in the fight")
Peace()
Eq(done, 1, "onDone did not run after the fight")
mock.fire("PLAYER_REGEN_DISABLED")
mock.fire("PLAYER_REGEN_ENABLED")
Eq(done, 1, "onDone ran twice")

-- Done, Escape and Edit Mode closing run it at once.
ns.UI.PlaceToast(Done)
card.done:Click()
Eq(done, 2, "Done did not run onDone at once")
ns.UI.PlaceToast(Done)
card:Hide()
Eq(done, 3, "Escape did not run onDone at once")

-- Held, then placing again: the old one is dropped. A refusal in the fight
-- drops nothing.
ns.UI.PlaceToast(Done)
Fight()
Check(not ns.UI.PlaceToast(), "placing started in a fight")
Peace()
Eq(done, 4, "a refused try dropped what was held")
ns.UI.PlaceToast(Done)
Fight()
mock.inCombat = false
local second = 0
Check(ns.UI.PlaceToast(function() second = second + 1 end), "placing again was refused")
mock.fire("PLAYER_REGEN_ENABLED")
Eq(done, 4, "the held onDone ran after placing started again")
Check(ns.UI.PlacingToast(), "the end of a fight ended placing")
card.done:Click()
Eq(second, 1, "the new placing's onDone did not run")
Eq(done, 4, "the dropped onDone ran at the end")

-- From Settings, through its own link: the book opens after the fight, not in it.
local settings = ns.UI.SettingsPage()
ns.UI.ShowSettings()
settings.moveToast:Click()
local book = _G.SocialDiaryJournalFrame
Check(ns.UI.PlacingToast() and not book:IsShown(), "Move the toast did not close the book")
Fight()
Check(not book:IsShown(), "the book opened in the fight")
Peace()
Check(book:IsShown() and settings:IsVisible(), "the book did not open on Settings after the fight")
ns.UI.CloseJournal()
