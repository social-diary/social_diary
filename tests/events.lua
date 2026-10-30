-- The event dispatcher under everything else.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

--------------------------------------------------------------------------
Section("event dispatcher")

local handler = function() end
ns.On("TEST_EVENT", handler)
Check(mock.registered.TEST_EVENT, "event not registered")
ns.Off("TEST_EVENT", handler)
Check(not mock.registered.TEST_EVENT, "event not unregistered after the last handler")

-- SIG-5 needs a handler to be able to remove itself mid-dispatch.
local seen, a, b = {}, nil, nil
a = function() seen[#seen + 1] = "a"; ns.Off("DISPATCH_TEST", a) end
b = function() seen[#seen + 1] = "b" end
ns.On("DISPATCH_TEST", a)
ns.On("DISPATCH_TEST", b)
mock.fire("DISPATCH_TEST")
Eq(table.concat(seen, ","), "a,b", "handler skipped")
mock.fire("DISPATCH_TEST")
Eq(table.concat(seen, ","), "a,b,b", "removed handler still ran")

--------------------------------------------------------------------------
Section("the addon's own messages (SD_*)")

-- ns.Fire dispatches at once, with its arguments, and never touches the
-- client's event registration.
local got = {}
local m1 = function(msg, x, y) got[#got + 1] = msg .. ":" .. tostring(x) .. ":" .. tostring(y) end
local m2 = function(_, x) got[#got + 1] = "second:" .. tostring(x) end
ns.On("SD_TEST", m1)
ns.On("SD_TEST", m2)
Check(not mock.registered.SD_TEST, "an SD_ message was registered as a client event")
Check(ns.IsRegistered("SD_TEST"), "an SD_ message has no handlers")
ns.Fire("SD_TEST", 1, "two")
Eq(table.concat(got, ","), "SD_TEST:1:two,second:1", "handlers not run in order with the arguments")

-- The same tombstones: a handler can drop itself mid-dispatch, and m1's
-- freed slot is reused, so `once` runs first.
got = {}
local once
once = function() got[#got + 1] = "once"; ns.Off("SD_TEST", once) end
ns.Off("SD_TEST", m1)
ns.On("SD_TEST", once)
ns.Fire("SD_TEST")
ns.Fire("SD_TEST")
Eq(table.concat(got, ","), "once,second:nil,second:nil", "removal during an SD_ dispatch")
ns.Off("SD_TEST", m2)
Check(not ns.IsRegistered("SD_TEST"), "the last SD_ handler did not drop the list")
ns.Fire("SD_TEST")  -- nobody listening: nothing happens

-- A client event's name is refused, and nothing ran.
ns.On("FIRE_TEST", m2)
got = {}
Check(not pcall(ns.Fire, "FIRE_TEST", 1), "ns.Fire accepted a client event")
Eq(#got, 0, "a refused Fire still ran handlers")
ns.Off("FIRE_TEST", m2)

-- The client's own dispatch does not reach a message by its name.
ns.On("SD_CLIENT", m2)
mock.fire("SD_CLIENT", 5)
Eq(#got, 0, "a client event reached an SD_ handler")
ns.Off("SD_CLIENT", m2)

-- Who listens to what, after the addon loaded.
Check(ns.IsRegistered("SD_REUNION"), "UI/Windows/Reunion/Queue.lua does not listen for SD_REUNION")
Check(ns.IsRegistered("SD_DIARY_CHANGED"), "the journal does not listen for SD_DIARY_CHANGED")

-- The paper: the journal's book listens once it is built (/sd art).
local before = ns.IsRegistered("SD_PAPER_CHANGED")
ns.UI.ShowJournal()
Check(not before and ns.IsRegistered("SD_PAPER_CHANGED"), "the book does not listen for SD_PAPER_CHANGED")
local book = _G.SocialDiaryJournalFrame.book
local painted = 0
local apply = book.ApplyGrain
book.ApplyGrain = function(self) painted = painted + 1; return apply(self) end
ns.Style.NextPaper()
ns.Style.SetGrain(50)
Eq(painted, 2, "the book did not repaint on a paper or grain change")
ns.Style.SetGrain(100)
ns.UI.CloseJournal()

-- The loose sheet's grain follows /sd art grain too, as the book's does.
-- Its alpha is only on what the mock recorded (wowmock.lua, `recorded`).
ns.TestData.Write()
ns.UI.ShowEntry(ns.TestData.GUID)
local sheet = _G.SocialDiaryEntryFrame
local function GrainAlpha()
    return sheet.grain[1].texture.recorded.calls.SetAlpha[1]
end
Check(#sheet.grain > 0, "setup: the sheet has no grain")
local designed = GrainAlpha()
ns.Style.SetGrain(50)
Eq(GrainAlpha(), designed / 2, "the sheet's grain ignored /sd art grain")
ns.Style.SetGrain(100)
Eq(GrainAlpha(), designed, "the sheet's grain did not come back")
sheet:Hide()

-- One handler's error cannot silence the next for the same event: with the
-- client's error handler present, the error goes there and dispatch goes on.
Section("a failing handler is contained")
local caught, after = {}, 0
_G.geterrorhandler = function() return function(err) caught[#caught + 1] = err end end
local function Boom() error("boom") end
local function Next() after = after + 1 end
ns.On("SD_TEST_GUARD", Boom)
ns.On("SD_TEST_GUARD", Next)
ns.Fire("SD_TEST_GUARD")
Eq(#caught, 1, "the error did not reach the error handler")
Eq(after, 1, "the next handler did not run after an error")
Check(tostring(caught[1]):find("boom") ~= nil, "the error handler got something else")
ns.Off("SD_TEST_GUARD", Boom)
ns.Off("SD_TEST_GUARD", Next)

-- The same for the jobs on a shared ticker: the one after still runs.
caught, after = {}, 0
ns.Every(777, Boom)
ns.Every(777, Next)
mock.tickers[#mock.tickers].fn()
Eq(#caught, 1, "a job's error did not reach the error handler")
Eq(after, 1, "the job after a failing one did not run")

-- And for the cleanups at login: the ones after still run.
caught = {}
local realPrune, pruned = ns.Interactions.Prune, 0
local realReunions = ns.Reunions.Prune
ns.Interactions.Prune = Boom
ns.Reunions.Prune = function() pruned = pruned + 1 end
mock.fire("PLAYER_LOGIN")
ns.Interactions.Prune, ns.Reunions.Prune = realPrune, realReunions
Eq(#caught, 1, "a failing cleanup did not reach the error handler")
Eq(pruned, 1, "the cleanups after a failing one did not run")
_G.geterrorhandler = nil

--------------------------------------------------------------------------
Section("a duel under way (ns.Duelling)")

-- SD_DUEL_STARTED to SD_DUEL_FINISHED, kept for the readers a duel's fight
-- would fool (close calls, the route, the sightings).
local A, B = "Player-4620-00AAAA0D", "Player-4620-00AAAA0E"
Eq(ns.Duelling(), false, "a duel before any")
ns.Fire("SD_DUEL_STARTED", A)
Eq(ns.Duelling(), true, "a duel begun is not on")
Eq(ns.Duelling(A), true, "a duel with them is not on")
Eq(ns.Duelling(B), false, "a duel with someone else")
mock.now = mock.now + 60
ns.Fire("SD_DUEL_FINISHED", A, "won")
Eq(ns.Duelling(), false, "a duel over is still on")
Eq(ns.Duelling(A, true), true, "no grace just after the end")
mock.now = mock.now + 6
Eq(ns.Duelling(A, true), false, "the grace never ends")
-- An opponent not read counts for anyone; an end never heard frees them.
ns.Fire("SD_DUEL_STARTED", nil)
Eq(ns.Duelling(B), true, "a duel with someone unread is not on for them")
mock.now = mock.now + 10 * 60 + 1
Eq(ns.Duelling(), false, "a duel whose end never came lasts for ever")

