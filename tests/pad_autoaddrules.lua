-- Auto-Add's rule sheet with the pad (UI/Settings/RulesPad.lua's
-- `autoaddrules`; the sheet UI/Settings/Rules.lua; .claude/features/
-- auto-add-rules-ui.md §5): reached from Settings, the index and the form,
-- every control for every trigger, the ladder, the trigger cycling and its
-- menu (the pad's own), radios, chips, filters added and removed, the class
-- grid's last tick, the row menu, delete and undo, the tag line, the
-- picker, B one step at a time back to "Auto-Add Players", the backfill
-- sheet taking the pad, combat, the mouse, and the Gamepad UI off.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local A = ns.AutoAdd
local Rules = ns.UI.AutoAddRules
local Sheet = ns.UI.AutoAdd
local MAP = { mapID = 1412, zone = "Mulgore" }
local HOUR = 3600
mock.now = 1790000000
T.BlankDiary()

ns.UI.ShowJournal()
ns.UI.SetJournalView("settings")
local book = ns.UI.JournalFrame()
local page = ns.UI.SettingsPage()
local function ShowAll(frame)
    frame:Show()
    for _, child in ipairs({ frame:GetChildren() }) do ShowAll(child) end
end
ShowAll(page)
page:ShowSection("recording")
page:Refresh()
local auto = page.autoAdd

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(book)

local function Press(key, on)
    mock.PadPress(on or catcher, key, true)
    return mock.PadPress(on or catcher, key, false)
end
local function Top() return Pad.Top() and Pad.Top().key end
local function At() return Pad.Top().focus:Current() end
local function Legend()
    local out = {}
    for _, e in ipairs(Pad.Top().legend(Pad.Top()) or {}) do
        out[type(e[1]) == "table" and e[1][1] or e[1]] = e[2]
    end
    return out
end
local function Rule() return Rules.Rule() end
local function Group(name)
    local out = {}
    for _, it in ipairs(Pad.Top().focus.groups[name].items) do out[#out + 1] = it end
    return out
end
-- Down until `test(At())`, at most `most` presses.
local function Walk(test, most)
    for _ = 1, most or 60 do
        if test(At()) then return true end
        Press("PADDDOWN")
    end
    return test(At())
end

ns.db.settings.autoAddRules = {}
local made = {
    A.NewRule("grouped", { on = true, tag = "group" }),
    A.NewRule("seen", { on = false }),
}
page:Refresh()

--------------------------------------------------------------------------
Section("\"Auto-Add Players\" is reached in Recording, and X lays the sheet")

Pad.Refresh()
Eq(Top(), "settings", "setup: the settings scope")
Press("PADDRIGHT")
Check(Walk(function(at) return at.frame == auto end), "\"Auto-Add Players\" never landed on")
Eq(At().kind, "switch", "the entry's kind")
local master = ns.Setting("autoAdd")
Press("PAD3")
Check(Rules.Shown(), "X on the switch did not lay the sheet")
Eq(ns.Setting("autoAdd"), master, "X switched the master")
Eq(Top(), "autoaddrules", "the sheet's scope has not the pad")
Eq(At().key, "rule:" .. made[1].id, "not on the open rule's line")
local legend = Legend()
Eq(legend.PAD1, "Open the rule", "an index line's A")
Eq(legend.PAD4, "Open the menu", "an index line's Y")
Eq(legend.PAD2, "Put the rules away", "the list's B")

--------------------------------------------------------------------------
Section("A on a line opens its form on the trigger; B back to the line, B again away")

Press("PADDDOWN")
Eq(At().key, "rule:" .. made[2].id, "down: not the next line")
Press("PAD1")
Eq(Rule(), made[2], "A did not open the rule")
Eq(At().key, "field:trigger", "the pad not on the trigger")
Eq(At().group, "form", "not in the form")
Press("PAD2")
Eq(At().key, "rule:" .. made[2].id, "B did not come back to its line")
Press("PAD2")
Check(not Rules.Shown(), "B on the list did not put the sheet away")
Eq(Top(), "settings", "the pad not back on Settings")
Eq(At().frame, auto, "the pad not back on \"Auto-Add Players\"")

--------------------------------------------------------------------------
Section("every control is reachable, for every trigger; rows that don't apply are not")

Press("PAD3")
Eq(Top(), "autoaddrules", "setup: the sheet again")
Press("PAD1")
Eq(At().key, "field:trigger", "setup: on the trigger")
for _, spec in ipairs(A.Triggers()) do
    Rules.SetTrigger(spec.key)
    Rules.AddFilter("level")
    Rules.AddFilter("class")
    Pad.Refresh()
    Pad.Top().focus:Focus("field:trigger", "form")
    local reached = {}
    for _ = 1, 80 do
        reached[At().key] = true
        if At().key == "delete" then break end
        Press("PADDDOWN")
    end
    for _, rec in ipairs(Rules.View().items.form) do
        Check(reached[rec.key], spec.key .. ": " .. rec.key .. " never reached")
    end
    for key in pairs(reached) do
        Check(not key:find("^option:") or spec.option ~= nil, spec.key .. ": an option row walked")
    end
    Rules.RemoveFilter("level")
    Rules.RemoveFilter("class")
end
Rules.SetTrigger("grouped")
Pad.Refresh()

--------------------------------------------------------------------------
Section("the amount: left and right climb the ladder, clamped")

Pad.Top().focus:Focus("field:amount", "form")
Eq(At().key, "field:amount", "setup: on the amount")
Eq(Legend().PADDLEFT, "Less or more", "the amount's prompt")
Rule().amount = 5
Press("PADDRIGHT")
Eq(Rule().amount, 10, "right: not the next rung")
Eq(At().key, "field:amount", "right moved off the amount")
Press("PADDLEFT")
Press("PADDLEFT")
Eq(Rule().amount, 4, "left twice: not two rungs down")
Rule().amount = 60
Press("PADDRIGHT")
Eq(Rule().amount, 60, "past the top")
Rule().amount = 5
Press("PAD1")
Check(At().frame:HasFocus(), "A did not give the amount the cursor")
Press("PAD2")
Check(not At().frame:HasFocus(), "B did not let the amount go")
Check(Rules.Shown(), "B while writing put the sheet away")

--------------------------------------------------------------------------
Section("the trigger: left and right cycle it, A lays the pad's own menu")

Pad.Top().focus:Focus("field:trigger", "form")
Press("PADDRIGHT")
Eq(Rule().trigger, A.Triggers()[2].key, "right did not step the trigger")
Eq(At().key, "field:trigger", "the pad left the trigger as the form was laid again")
Press("PADDLEFT")
Eq(Rule().trigger, "grouped", "left did not step back")
Press("PADDLEFT")
Eq(Rule().trigger, "grouped", "left past the first")
mock.contextMenu = nil
Press("PAD1")
Check(Pad.Menu.IsOpen(), "A did not open the pad's menu")
Eq(mock.contextMenu, nil, "A opened Blizzard's menu")
local function Lines(root)
    local out = {}
    -- (a title is not a choice the pad stands on)
    for _, e in ipairs(root.children) do if e.text and e.kind ~= "title" then out[#out + 1] = e.text end end
    return table.concat(out, " | ")
end
local pad = {}
for _, item in ipairs(Group("menu")) do pad[#pad + 1] = item.element.text end
Eq(table.concat(pad, " | "), Lines(Pad.Menu.Record(Rules.View().trigger, Rules.TriggerMenu())),
    "the pad's choices not the generator's")
for _ = 1, 10 do
    if At().element and At().element.text == "Traded with you" then break end
    Press("PADDDOWN")
end
Press("PAD1")
Check(not Pad.Menu.IsOpen(), "the menu stayed after a pick")
Eq(Rule().trigger, "traded", "the menu's pick not taken")
Rules.SetTrigger("grouped")
Pad.Refresh()

--------------------------------------------------------------------------
Section("ticks, radios and chips with A; left and right along their line")

Pad.Top().focus:Focus("option:world", "form")
Eq(At().key, "option:world", "setup: on a place")
Eq(Legend().PAD1, "Untick", "a place's prompt")
Press("PAD1")
Eq(Rule().option.world, nil, "A did not untick it")
Press("PADDRIGHT")
Eq(At().key, "option:dungeon", "right: not the next place")
Press("PAD1")
Press("PADDRIGHT")
Eq(At().key, "option:raid", "right: not the last place")
Press("PAD1")
Eq(Rule().option.raid, true, "A unticked the last place")
Press("PADDLEFT")
Press("PADDLEFT")
Press("PAD1")
Eq(Rule().option.world, true, "A did not tick it again")
Pad.Top().focus:Focus("tag:dungeon", "form")
Eq(Legend().PAD1, "Add the tag", "a chip's prompt")
Press("PAD1")
Eq(Rule().tag, "dungeon", "A on a chip did not put its tag on")
Press("PADDLEFT")
Eq(At().key, "tag:group", "left along the chips")
Press("PADDLEFT")
Press("PAD1")
Eq(Rule().tag, nil, "A on (none) did not take the tag off")

--------------------------------------------------------------------------
Section("+ Level lands on its first radio; Remove lands on the strip")

Pad.Top().focus:Focus("more:level", "form")
Eq(At().key, "more:level", "setup: on + Level")
Eq(Legend().PAD1, "Add it", "a strip's prompt")
Press("PAD1")
Check(Rule().filters and Rule().filters.level, "A on + Level did not add it")
Eq(At().key, "levelway:within", "not on the level's first radio")
Pad.Top().focus:Focus("off:level", "form")
Eq(Legend().PAD1, "Remove it", "Remove's prompt")
Press("PAD1")
Eq(Rule().filters, nil, "Remove did not remove it")
Eq(At().key, "more:level", "not back on the strip")

-- The class grid: the last tick is refused.
Pad.Top().focus:Focus("more:class", "form")
Press("PAD1")
Eq(At().key, "class:WARRIOR", "+ Class: not on the first class")
Eq(Legend().PAD1, "Untick", "a ticked class's prompt")
for _ = 1, 8 do
    Press("PAD1")
    Press("PADDRIGHT")
end
Eq(At().key, "class:DRUID", "right along the icons")
Press("PAD1")
Eq(Rule().filters.class.DRUID, true, "the last class was unticked")
Press("PADDLEFT")
Eq(Legend().PAD1, "Tick", "an unticked class's prompt")
Rules.RemoveFilter("class")
Pad.Refresh()

--------------------------------------------------------------------------
Section("the tag line: A gives the cursor, B lets go and keeps it, B again to the list")

Pad.Top().focus:Focus("tagline", "form")
Eq(Legend().PAD1, "Write", "the line's prompt")
Press("PAD1")
local line = At().frame
Check(line:HasFocus(), "A did not give the line the cursor")
Eq(Legend().PAD2, "Stop writing", "B's prompt while writing")
line:SetText("Rivals")
Press("PAD2")
Check(not line:HasFocus(), "B did not let the line go")
line:GetScript("OnEditFocusLost")(line)   -- (the client's, as it lets go)
Eq(Rule().tag, "rivals", "the written tag not kept")
Check(Rules.Shown(), "B off the line put the sheet away")
Press("PAD2")
Eq(At().group, "list", "B again did not come back to the list")
Eq(At().key, "rule:" .. Rule().id, "not on the open rule's line")

--------------------------------------------------------------------------
Section("Y on a line: its menu, the mouse's lines; Delete, then Undo")

local rule = Rule()
mock.contextMenu = nil
Check(not Press("PAD4"), "Y went on to the game")
Check(Pad.Menu.IsOpen(), "Y did not open the pad's menu")
Eq(mock.contextMenu, nil, "Y opened Blizzard's menu")
pad = {}
for _, item in ipairs(Group("menu")) do pad[#pad + 1] = item.element.text end
Eq(table.concat(pad, " | "), Lines(Pad.Menu.Record(At().frame, Rules.RowMenu(rule))), "the row menu drifts")
for _ = 1, 5 do
    if At().element.text == "Delete" then break end
    Press("PADDDOWN")
end
Press("PAD1")
Eq(A.RuleById(rule.id), nil, "Delete from the menu did not delete")
Eq(At().key, "undo:" .. rule.id, "the pad not on the Undo line")
Press("PAD1")
Check(A.RuleById(rule.id) ~= nil, "A on Undo did not put it back")
Eq(At().key, "rule:" .. rule.id, "the pad not on the rule put back")

--------------------------------------------------------------------------
Section("the picker: A on a strip adds the rule, the pad on its trigger; B is Cancel")

Pad.Top().focus:Focus("new", "list")
Eq(At().key, "new", "setup: on + New rule")
Press("PAD1")
Check(Rules.State().picking, "A on + New rule: no picker")
Eq(At().key, "start:group", "not on the first strip")
Eq(Legend().PAD1, "Start from it", "a strip's prompt")
Press("PADDDOWN")
Press("PADDDOWN")
Eq(At().key, "start:seen", "down the strips")
local count = #A.Rules()
Press("PAD1")
Eq(#A.Rules(), count + 1, "A on a strip did not add a rule")
Eq(A.Rules()[#A.Rules()].preset, "seen", "not the strip's preset")
Eq(At().key, "field:trigger", "the pad not on the new rule's trigger")
Pad.Top().focus:Focus("new", "list")
Press("PAD1")
Press("PAD2")
Check(not Rules.State().picking, "B did not cancel the picker")
Eq(At().group, "list", "B off the picker: not on the list")
Check(Rules.Shown(), "B off the picker put the sheet away")

--------------------------------------------------------------------------
Section("put away with a widened rule: the backfill sheet takes the pad, and gives it back")

-- (seeded with the master off, then on)
ns.SetSetting("autoAdd", false)
for _, p in ipairs({ { "Player-1-0E000001", "Ivo" }, { "Player-1-0E000002", "Jun" } }) do
    ns.Characters.Observe(p[1], { first = p[2], level = 20, class = "MAGE" })
    for i = 1, 3 do ns.Sightings.Record(p[1], { source = "plate" }, MAP, mock.now + (i - 1) * HOUR) end
end
Rules.Close()
ns.SetSetting("autoAdd", true)
page:Refresh()
Pad.Refresh()
Eq(At().frame, auto, "setup: on the switch")
local seen = A.Rules()[#A.Rules()]
seen.amount = 4   -- (as it was before the visit)
Press("PAD3")
Rules.Show(seen.id)
Pad.Top().focus:Focus("field:amount", "form")
Press("PADDLEFT")
Eq(seen.amount, 3, "setup: the amount not lowered")
Press("PAD2")
Press("PAD2")
Check(not Rules.Shown(), "B twice did not put the sheet away")
Check(Sheet.Shown(), "a widened rule with people waiting: no question")
Eq(Top(), "autoadd", "the backfill sheet has not the pad")
local host = Sheet.Host()
Press("PAD2", Pad.Catcher(host))
Check(not Sheet.Shown(), "B (Not now) left the question up")
Eq(Top(), "settings", "the pad not back on Settings")
Eq(At().frame, auto, "the pad not back on \"Auto-Add Players\"")

--------------------------------------------------------------------------
Section("combat, the mouse, and the Gamepad UI off")

Press("PAD3")
Eq(Top(), "autoaddrules", "setup: the sheet")
mock.fire("PLAYER_REGEN_DISABLED")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher stayed on in a fight")
Check(Rules.Shown(), "a fight put the sheet away")
mock.fire("PLAYER_REGEN_ENABLED")
Check(catcher:IsGamePadButtonEnabled(), "the catcher not back after the fight")
Eq(Top(), "autoaddrules", "the sheet lost the pad after the fight")

local function Red(fs)
    local r, g, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end
Press("PAD1")
Eq(At().key, "field:trigger", "setup: on the trigger")
local words, subhead = At().words, At().subhead
Check(Red(words), "the trigger's words not red where the pad stands")
Check(Red(subhead), "the trigger's label not red where the pad stands")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher stayed on under the mouse")
Check(not Red(words), "the mouse took over: the trigger's words still red")
Check(not Red(subhead), "the mouse took over: the label still red")
Rules.Close()

mock.pad.ui = false
mock.fire("GAME_PAD_ACTIVE_CHANGED", false)
Rules.Open()
Pad.Refresh()
Check(not catcher:IsGamePadButtonEnabled(), "the Gamepad UI off, yet the catcher on")
Rules.Close()
