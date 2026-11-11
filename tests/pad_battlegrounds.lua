-- A battleground's pages with the pad (UI/Journey/Pad.lua's group `match`,
-- the hits' `pad` in UI/Journey/Match.lua; battleground-page.md §4): A on
-- the evening's line opens its overview and the pad goes onto its title;
-- everything on it is walked by where it lies; A on a ticket opens its
-- match (the pad on its title), B comes back to the overview onto that
-- ticket, and so does A on "Back to the evening's battlegrounds"; A on
-- "Turn … over" turns it and the pad stays on the link; A on a diary
-- person's row opens their page; a strip, the title and your note show
-- their tooltip only; B goes back to the left page's line; the mouse takes
-- over cleanly; with the Gamepad UI off nothing takes the pad.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local Look = Pad.Look
local YourDiary = ns.UI.YourDiary
local Matches = ns.Matches

SlashCmdList.SOCIALDIARY("testdata")
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local book = ns.UI.JournalFrame()
local page = ns.UI.JourneyPage()

local catcher = Pad.Catcher(book)
local function Press(key, on)
    local went = mock.PadPress(on or catcher, key, true)
    mock.PadPress(on or catcher, key, false)
    return went
end
local function Scope() return Pad.Top() end
local function At() return Scope().focus:Current() end
local function Items(group) return Scope().focus.groups[group].items end
local function Legend()
    local out = {}
    for _, e in ipairs(Scope().legend(Scope())) do out[type(e[1]) == "table" and e[1][1] or e[1]] = e[2] end
    return out
end
local function Red(fs)
    local r, g, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end

local evening, lone
for _, s in ipairs(Matches.Sessions(ns.ownGUID)) do
    if Matches.HasOverview(s) then evening = s else lone = s end
end
Check(evening and lone, "setup: the evening and the lone match")

--------------------------------------------------------------------------
Section("with the mouse nothing is told to the pad")

Check(not Pad.Input.Active(), "setup: the mouse")
YourDiary.OpenMatches(evening.key)
Eq(page.mode, "matches", "setup: the overview open")
Check(Look.parts[book] == nil or not Look.parts[book].pen:IsShown(), "a box drawn with the mouse")
YourDiary.OpenLevel(page.open)

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Eq(Scope().key, "yourdiary", "setup: the top scope")

--------------------------------------------------------------------------
Section("A on the evening's line opens its overview, the pad onto its title")

local lineKey = "evening:" .. evening.key
Press("PADDDOWN")
Check(Scope().focus:Focus(lineKey, "left"), "the evening's line is not on the left page")
Eq(Legend().PAD1, "Open", "A's prompt on the evening's line")
Press("PAD1")
Eq(page.mode .. ":" .. tostring(page.session), "matches:" .. evening.key, "A did not open the overview")
Eq(At().group .. ":" .. At().key, "match:title", "the pad not on the overview's title")
local parts = Look.parts[book]
Check(parts.pen:IsShown(), "the title not boxed")
Check(GameTooltip.shown, "the title's tooltip not shown")
local L = Legend()
Eq(L.PAD1, nil, "A offered on the title")
Eq(L.PAD2, "Back to the contents", "B's prompt on the overview")
Check(Press("PAD4"), "Y taken on the overview")
Check(Press("PAD3"), "X taken on the overview")

--------------------------------------------------------------------------
Section("everything on the overview is reached, each once")

local function Walk(start)
    local keys = {}
    for _, item in ipairs(Items("match")) do
        Check(not keys[item.key], "a key twice: " .. item.key)
        keys[item.key] = true
        local x, y = item.center()
        Check(type(x) == "number" and type(y) == "number", "no centre: " .. item.key)
    end
    local seen, queue = { [start] = true }, { start }
    while #queue > 0 do
        local from = table.remove(queue, 1)
        for _, dir in ipairs({ "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT" }) do
            Scope().focus:Focus(from, "match")
            Press(dir)
            Eq(At().group, "match", "the D-pad left the page from " .. from)
            local to = At().key
            if not seen[to] then
                seen[to] = true
                queue[#queue + 1] = to
            end
        end
    end
    for key in pairs(keys) do Check(seen[key], "the D-pad never reaches " .. key) end
    return keys
end
local keys = Walk("title")
for _, m in ipairs(evening.matches) do Check(keys["ticket:" .. m.id], "no ticket for match " .. m.id) end
Check(keys.turn and keys.note, "the turn link or your note not reached")
Check(keys["hand:" .. ns.TestData.GUID], "Tester's row not reached")
Eq(page.mode, "matches", "left or right turned the level on the overview")

--------------------------------------------------------------------------
Section("a ticket: outlined; A opens its match, B comes back onto it")

local m3 = evening.matches[3]
Check(Scope().focus:Focus("ticket:" .. m3.id, "match"), "setup: onto the third ticket")
Check(parts.outline and parts.outline.line:IsShown(), "a ticket not outlined")
Check(not parts.pen:IsShown(), "a ticket boxed as words")
Check(GameTooltip.shown, "a ticket's tooltip not shown")
Eq(Legend().PAD1, "Open the match", "A's prompt on a ticket")
Press("PAD1")
Eq(page.mode .. ":" .. tostring(page.matchId), "match:" .. m3.id, "A on a ticket did not open its match")
Eq(At().group .. ":" .. At().key, "match:title", "the pad not on the match's title")
Eq(Legend().PAD2, "Back to the battlegrounds", "B's prompt on a match of an evening")
Press("PAD2")
Eq(page.mode, "matches", "B did not go back to the overview")
Eq(At().key, "ticket:" .. m3.id, "B not back on the ticket it left from")

-- The back link, the same way.
Press("PAD1")
Check(Scope().focus:Focus("back", "match"), "the back link not reached")
Eq(Legend().PAD1, "Back to the battlegrounds", "A's prompt on the back link")
Press("PAD1")
Eq(page.mode, "matches", "A on the back link did not open the overview")
Eq(At().key, "ticket:" .. m3.id, "A on the back link not back on the ticket")

--------------------------------------------------------------------------
Section("a match: its parts reached, a diary person's row opens their page, a strip only its tooltip")

Press("PAD1")
-- (the third Warsong is told by time: its board is the board view, walked
-- here as v1's page; the story's own walk is tests/battleground_story_ui.lua)
YourDiary.OpenMatchBoard(true)
Pad.Refresh()
keys = Walk("title")
Check(keys.back and keys.note, "the back link or your note not reached")
Check(keys["row:" .. ns.TestData.GUID], "Tester's row not reached")
local strips = 0
for key in pairs(keys) do if key:find("^strip:") then strips = strips + 1 end end
Check(strips >= 2, "the strips not reached")
-- A strip: outlined, its heading red, A does nothing.
local strip
for _, item in ipairs(Items("match")) do if item.kind == "strip" then strip = strip or item end end
Check(Scope().focus:Focus(strip.key, "match"), "setup: onto a strip")
Check(parts.outline.line:IsShown(), "a strip not outlined")
Check(Red(strip.heading), "a strip's heading not red")
Eq(Legend().PAD1, nil, "A offered on a strip")
local mode, id = page.mode, page.matchId
Press("PAD1")
Eq(page.mode .. ":" .. tostring(page.matchId), mode .. ":" .. tostring(id), "A on a strip did something")
-- Tester's row.
Check(Scope().focus:Focus("row:" .. ns.TestData.GUID, "match"), "setup: onto Tester's row")
Check(parts.pen:IsShown(), "a diary person's row not boxed")
Check(Red(At().words), "a diary person's name not red")
Eq(Legend().PAD1, "Go to their page", "A's prompt on a diary person's row")
local went
local was = YourDiary.ToPerson
YourDiary.ToPerson = function(guid) went = guid end
Press("PAD1")
YourDiary.ToPerson = was
Eq(went, ns.TestData.GUID, "A on a diary person's row did not open their page")

--------------------------------------------------------------------------
Section("turning the Alterac's board: the pad stays on the link")

YourDiary.OpenMatch(evening.matches[4].id)
Pad.Refresh()
Check(Scope().focus:Focus("turn", "match"), "the turn link not reached")
Eq(Legend().PAD1, "Turn the board over", "A's prompt on the turn link")
Press("PAD1")
Eq(page.bg.faces["match:" .. evening.matches[4].id], 2, "A did not turn the board over")
Eq(At().group .. ":" .. At().key, "match:turn", "the pad left the turn link")

--------------------------------------------------------------------------
Section("B on a lone match goes back to its line; then the book closes")

local loneKey = "match:" .. lone.matches[1].id
YourDiary.OpenLevel(page.open)
Pad.Refresh()
Check(Scope().focus:Focus(loneKey, "left"), "the lone match's line not on the left page")
Press("PAD1")
Eq(page.mode .. ":" .. tostring(page.matchId), "match:" .. lone.matches[1].id, "A did not open the lone match")
Eq(At().group, "match", "the pad did not cross")
Eq(Legend().PAD2, "Back to the contents", "B's prompt on a lone match")
Press("PAD2")
Eq(At().group .. ":" .. At().key, "left:" .. loneKey, "B not back on the lone match's line")
-- A on the line again: straight over, nothing drawn again.
Press("PAD1")
Eq(At().group, "match", "A on the line showing its match did not cross")
Press("PAD2")
Press("PAD2")
Check(not book:IsShown(), "B on the left page did not close the book")

--------------------------------------------------------------------------
Section("unclaimed buttons go on to the game; the mouse takes over cleanly")

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
YourDiary.OpenMatches(evening.key)
Pad.Refresh()
Scope().focus:Focus(lineKey, "left")
Press("PAD1")
Eq(At().group, "match", "setup: on the overview")
Check(Press("PADLTRIGGER"), "LT taken on the overview")
Check(Scope().focus:Focus("ticket:" .. evening.matches[1].id, "match"), "setup: onto a ticket")
parts = Look.parts[book]
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(not parts.pen:IsShown(), "the box left with the mouse")
Check(not parts.outline.line:IsShown() and not parts.outline.shadow:IsShown(), "the outline left with the mouse")
Check(not GameTooltip.shown, "the ticket's tooltip left with the mouse")
Check(not catcher:IsGamePadButtonEnabled(), "the book still takes the pad")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(Pad.Input.Active(), "setup: the pad back")
Eq(At().key, "ticket:" .. evening.matches[1].id, "the pad not back where it was")

--------------------------------------------------------------------------
Section("the Gamepad UI off: nothing takes the pad")

mock.pad.ui = false
mock.fire("GAME_PAD_ACTIVE_CHANGED", false)
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Pad.Refresh()
Check(not catcher:IsGamePadButtonEnabled(), "the book takes the pad with the Gamepad UI off")
