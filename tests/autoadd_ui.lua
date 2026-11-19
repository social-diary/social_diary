-- Auto-Add's rules with the mouse (UI/Settings/Rules.lua, the entry in
-- UI/Settings/Sections/Recording.lua, the backfill sheet UI/Windows/AutoAdd.lua;
-- .claude/features/auto-add-rules-ui.md): the master switch alone, its box
-- switching and its underlined words opening the rule sheet, the
-- switch opening the rule sheet when no rule is on, the index and the form
-- for every trigger, the ladder, the places' last tick, radios, filters,
-- classes, tags, the quiet warning, delete and undo, the picker, the most
-- rules, the empty state, the row menu, and the backfill question asked
-- once as the sheet is put away, over several rules.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local A = ns.AutoAdd
local Rules = ns.UI.AutoAddRules
local Sheet = ns.UI.AutoAdd
local MAP = { mapID = 1412, zone = "Mulgore" }
local HOUR = 3600

mock.now = 1790000000
T.BlankDiary()

ns.UI.ShowJournal()
ns.UI.SetJournalView("settings")
local page = ns.UI.SettingsPage()
local function ShowAll(frame)
    frame:Show()
    for _, child in ipairs({ frame:GetChildren() }) do ShowAll(child) end
end
ShowAll(page)
page:ShowSection("recording")

local function Items(group)
    local out = {}
    for _, it in ipairs(Rules.View().items[group] or {}) do out[it.key] = it end
    return out
end
local function Keys(group)
    local out = {}
    for _, it in ipairs(Rules.View().items[group] or {}) do out[#out + 1] = it.key end
    return table.concat(out, " ")
end
local function Rule() return Rules.Rule() end

-- A fresh list of `list` (NewRule's fields, each with a trigger), the
-- master `master`.
local function Fresh(list, master)
    ns.SetSetting("autoAdd", false)
    ns.db.settings.autoAddRules = {}
    local made = {}
    for i, fields in ipairs(list or {}) do
        local f = {}
        for k, v in pairs(fields) do if k ~= "trigger" then f[k] = v end end
        made[i] = A.NewRule(fields.trigger, f)
    end
    ns.SetSetting("autoAdd", master == true)
    return made
end

--------------------------------------------------------------------------
Section("a new character: three presets, off; the entry is the switch alone")

Eq(#A.Rules(), 3, "a new character's presets")
for _, rule in ipairs(A.Rules()) do Check(not rule.on, "a preset started on: " .. tostring(rule.preset)) end
page:Refresh()
local auto = page.autoAdd
Eq(auto.label:GetText(), "Auto-Add Players", "the switch's words")
Check(auto.hint == nil, "the switch still has a hint")
Check(page.autoAddRules == nil, "the summary is still built")
Check(type(auto.follow) == "function" and auto.labelHit, "the words are not a link")
Check(auto.line and auto.line:GetWidth() >= 8, "the words are not underlined")
Eq(auto.followPrompt, "Open the rules", "the pad's words for the link")
-- (nothing laid out under the switch in its section)
local pane = page.panes.recording
local _, _, _, _, top = auto:GetPoint(1)
for _, child in ipairs({ pane:GetChildren() }) do
    if child ~= auto then
        local _, _, _, _, y = child:GetPoint(1)
        Check(not (y and top and y < top), "something laid out under the switch")
    end
end

--------------------------------------------------------------------------
Section("the underlined words open the rule sheet; the box alone switches")

Check(not Rules.Shown(), "setup: the sheet up")
auto.labelHit:Click()
Check(Rules.Shown(), "a click on the words did not lay the rule sheet")
Eq(ns.Setting("autoAdd"), false, "a click on the words switched auto-add")
Eq(auto:GetChecked(), false, "a click on the words ticked the box")
Rules.Close()
Check(not Rules.Shown(), "setup: the sheet stayed up")
Check(not Sheet.Shown(), "the words, then put away with the master off: a question")
-- (the box's own click switches, and the words light as a link's under the mouse)
local INK, STRONG = ns.Style.INK, ns.Style.INK_STRONG
auto.labelHit:GetScript("OnEnter")(auto.labelHit)
local r = auto.label:GetTextColor()
Eq(r, STRONG[1], "the words did not darken under the mouse")
auto.labelHit:GetScript("OnLeave")(auto.labelHit)
r = auto.label:GetTextColor()
Eq(r, INK[1], "the words kept their dark ink")

--------------------------------------------------------------------------
Section("switched on with no rule on: the rule sheet opens")

Check(not Rules.Shown(), "setup: the sheet up")
page.autoAdd:Click()
Eq(ns.Setting("autoAdd"), true, "the switch did not go on")
Check(Rules.Shown(), "on with no rule on: no rule sheet")
Check(not Sheet.Shown(), "the backfill sheet came up as well")
Rules.Close()
Check(not Rules.Shown(), "Done did not put it away")
Check(not Sheet.Shown(), "nothing switched on, yet a question")
page.autoAdd:Click()
Eq(ns.Setting("autoAdd"), false, "setup: off again")

--------------------------------------------------------------------------
Section("the words open the sheet with the master on, too, and asking nothing")

Fresh({ { trigger = "grouped", on = true, tag = "group" } }, true)
page:Refresh()
Eq(auto:GetChecked(), true, "setup: the master on")
auto.labelHit:Click()
Check(Rules.Shown(), "the words, master on: no rule sheet")
Eq(ns.Setting("autoAdd"), true, "the words switched the master off")
Rules.Close()
Check(not Sheet.Shown(), "nothing changed, yet a question")
auto:Click()
Eq(ns.Setting("autoAdd"), false, "the box did not switch the master off")
Check(not Rules.Shown(), "switched off: the sheet laid")

--------------------------------------------------------------------------
Section("the index: a line per rule; a click opens its form, the tick switches it")

local made = Fresh({ { trigger = "grouped", on = true, tag = "group" }, { trigger = "seen", on = false } }, false)
Rules.Open()
Check(Rules.Shown(), "the link's open did not lay the sheet")
local view = Rules.View()
Check(view.waits:IsShown(), "master off: no line under the title")
Eq(Keys("list"), "rule:" .. made[1].id .. " rule:" .. made[2].id .. " new done", "the index's items")
local e1, e2 = view.entries[1], view.entries[2]
-- (cut with an ellipsis to the index's width)
Check(e1.words:GetText():find("^Grouped with you for") and e1.words:GetText():find("…$"), "the first line's words: " .. e1.words:GetText())
Eq(e1.under:GetText(), "group", "the first line's small print")
Eq(e2.under:GetText(), "no tag", "an untagged rule's small print")
Check(e1.wash:IsShown(), "the open rule has no wash")
Check(not e2.wash:IsShown(), "a closed rule has a wash")
Eq(Rule(), made[1], "opened on the first rule")
e2.hit:Click("LeftButton")
Eq(Rule(), made[2], "a click on a line did not open it")
Check(e2.wash:IsShown(), "the line opened has no wash")
e2.tick:Click()
Eq(made[2].on, true, "the tick did not switch it on")
e2.tick:Click()
Eq(made[2].on, false, "the tick did not switch it off")

--------------------------------------------------------------------------
Section("the form follows the trigger, and keeps what it had for the visit")

e1.hit:Click("LeftButton")
for _, spec in ipairs(A.Triggers()) do
    Rules.SetTrigger(spec.key)
    Eq(Rule().trigger, spec.key, "the trigger did not change to " .. spec.key)
    local it = Items("form")
    Check(it["field:trigger"] and it["field:amount"], spec.key .. ": no trigger or amount")
    Eq(view.trigger:GetText(), spec.label, spec.key .. ": the trigger's words")
    Eq(Rule().amount, spec.amount.default, spec.key .. ": not the new trigger's default amount")
    local any = false
    for key in pairs(it) do if key:find("^option:") then any = true end end
    Eq(any, spec.option ~= nil, spec.key .. ": the option's row drawn or not")
    for _, f in ipairs(A.FILTER_KEYS) do Check(it["more:" .. f], spec.key .. ": no + strip for " .. f) end
    Check(it["tag:"] and it["tagline"] and it["delete"], spec.key .. ": no tag row or delete")
    -- (the trigger's link on its own row, above the amount: a deferred
    -- placement once read the amount's row and laid the two over each other)
    local tAt, aAt = view.trigger.padAt, it["field:amount"].frame.padAt
    Check(tAt and aAt and aAt[2] - tAt[2] >= 20, spec.key .. ": the trigger's link not above the amount")
    -- (the label row's words, from the spec)
    if spec.option then Check(it["option:" .. spec.option.choices[1][1]].subhead:GetText() ~= "", "no option label") end
end
Rules.SetTrigger("grouped")
local amountItem = Items("form")["field:amount"]
local box = amountItem.frame
box:SetText("15")
box:GetScript("OnEnterPressed")(box)
Eq(Rule().amount, 15, "a typed amount not saved")
Rules.SetTrigger("seen")
Eq(Rule().amount, 3, "seen's default not taken")
Rules.SetTrigger("grouped")
Eq(Rule().amount, 15, "flipping back did not give back the amount")
-- The menu: the same choices for the mouse.
mock.contextMenu = nil
view.trigger:Click()
Check(mock.contextMenu ~= nil, "a click on the trigger opened no menu")
Check(mock.MenuClick("Whispered"), "no Whispered in the trigger menu")
Eq(Rule().trigger, "whispered", "the menu's pick did not change the trigger")
Rules.SetTrigger("grouped")

--------------------------------------------------------------------------
Section("the amount's ladder: rung by rung, clamped")

box = Items("form")["field:amount"].frame
Rule().amount = 5
box:Nudge(1)
Eq(Rule().amount, 10, "up from 5 is not 10")
box:Nudge(-1)
Eq(Rule().amount, 5, "down from 10 is not 5")
Rule().amount = 7
box:Nudge(1)
Eq(Rule().amount, 10, "up from 7 is not the next rung")
Rule().amount = 7
box:Nudge(-1)
Eq(Rule().amount, 5, "down from 7 is not the rung under")
Rule().amount = 60
box:Nudge(1)
Eq(Rule().amount, 60, "past the top")
Rule().amount = 1
box:Nudge(-1)
Eq(Rule().amount, 1, "past the bottom")
Rule().amount = 5
-- (without steps, the settings' numbers count by one, as ever)
local nudged
local plain = ns.Style.NumberField(page, 30, 1, 9, function() return 3 end, function(n) nudged = n end)
plain:Nudge(1)
Eq(nudged, 4, "a number without a ladder no longer counts by one")

--------------------------------------------------------------------------
Section("places: three ticks, the last stays ticked")

local it = Items("form")
for _, value in ipairs({ "world", "dungeon" }) do it["option:" .. value].frame:Click() end
Eq(Rule().option.world, nil, "world not unticked")
Eq(Rule().option.dungeon, nil, "dungeon not unticked")
Items("form")["option:raid"].frame:Click()
Eq(Rule().option.raid, true, "the last place was unticked")
Check(Items("form")["option:raid"].frame:GetChecked(), "the last box moved")
Items("form")["option:world"].frame:Click()
Eq(Rule().option.world, true, "a place not ticked again")
Check(view.note:IsShown(), "no small print under the places")
Eq(A.Describe(Rule()), "grouped with you for 5 minutes in the open world and raids", "the words after the ticks")

--------------------------------------------------------------------------
Section("radios: one of three, the one on stays on")

Rules.SetTrigger("whispered")
Items("form")["option:out"].frame:Click()
Eq(Rule().option, "out", "the radio did not choose")
Items("form")["option:out"].frame:Click()
Eq(Rule().option, "out", "a second click took it off")
Check(Items("form")["option:out"].frame:GetChecked(), "the radio on is unticked")
Check(not Items("form")["option:either"].frame:GetChecked(), "another radio still on")
Rules.SetTrigger("grouped")

--------------------------------------------------------------------------
Section("filters: added, changed, removed")

Rules.AddFilter("guild")
Eq(Rule().filters.guild, true, "+ Guild did not add it")
it = Items("form")
Check(it["off:guild"] and not it["more:guild"], "an added filter keeps its strip, or has no Remove")
Rules.AddFilter("faction")
Eq(Rule().filters.faction, "mine", "faction's default")
Items("form")["faction:other"].frame:Click()
Eq(Rule().filters.faction, "other", "the other faction not chosen")
Rules.AddFilter("level")
Eq(Rule().filters.level.within, 5, "level's default")
it = Items("form")
Check(it["level:min"] and it["level:max"] and it["level:within"] and it["levelway:between"], "level's controls")
it["levelway:between"].frame:Click()
Check(Rule().filters.level.min ~= nil and Rule().filters.level.within == nil, "Levels did not choose between")
local lo, hi = Items("form")["level:min"].frame, Items("form")["level:max"].frame
Rule().filters.level = { min = 20, max = 25 }
lo:SetText("40")
lo:GetScript("OnEnterPressed")(lo)
Eq(Rule().filters.level.min, 25, "a > b did not swap (min)")
Eq(Rule().filters.level.max, 40, "a > b did not swap (max)")
Items("form")["levelway:within"].frame:Click()
Eq(Rule().filters.level.within, 5, "back to within: not what it had")
Items("form")["levelway:between"].frame:Click()
Eq(Rule().filters.level.min, 25, "back to between: not what it had")
Rules.AddFilter("class")
local n = 0
for _ in pairs(Rule().filters.class) do n = n + 1 end
Eq(n, 9, "+ Class: not every class ticked")
for i = 1, 8 do Items("form")["class:" .. Rules.CLASSES[i]].frame:Click() end
Items("form")["class:DRUID"].frame:Click()
Eq(Rule().filters.class.DRUID, true, "the last class was unticked")
Eq(table.concat(Rules.FilterWords(Rule()), ", "), "my guild, the other faction, level 25–40, Druid", "the filters in short")
Check(not Items("form")["more:class"], "all four added, yet a + strip")
for _, key in ipairs(A.FILTER_KEYS) do Items("form")["off:" .. key].frame:Click() end
Eq(Rule().filters, nil, "every filter removed, yet a table")
Check(Items("form")["more:class"], "removed, no + strip back")

--------------------------------------------------------------------------
Section("tags: chips as radios, and a line to write one")

it = Items("form")
Check(it["tag:"] and it["tag:group"] and it["tag:dungeon"] and it["tag:seen"], "the chips: none and the presets' tags")
it["tag:dungeon"].frame:Click()
Eq(Rule().tag, "dungeon", "a chip did not put its tag on")
Check(Items("form")["tag:dungeon"].frame.on, "the chip on is not shown on")
Check(not Items("form")["tag:group"].frame.on, "another chip still on")
Items("form")["tag:"].frame:Click()
Eq(Rule().tag, nil, "(none) did not take the tag off")
local line = Items("form")["tagline"].frame
line:SetText("  Rivals ")
line:GetScript("OnEditFocusLost")(line)
Eq(Rule().tag, "rivals", "a written tag not cleaned and put on")
Eq(line:GetText(), "", "the line not cleared")
Check(Items("form")["tag:rivals"], "the written tag has no chip")
-- The diary's own tags are offered, most used first.
local FRIEND = "Player-1-0D000002"
ns.Characters.Observe(FRIEND, { first = "Fenn" })
ns.Diary.Add(FRIEND, { tags = { "healer" }, quiet = true })
Rules.Open()
Check(Items("form")["tag:healer"], "a tag the diary uses is not offered")

--------------------------------------------------------------------------
Section("a rule that can add nobody says so, in red")

Rules.SetTrigger("seen")
Check(not Rules.Quiet(Rule()), "a plain seen rule is quiet")
Rules.AddFilter("faction")
Items("form")["faction:other"].frame:Click()
Check(Rules.Quiet(Rule()) ~= nil, "seen of the other faction not quiet")
Check(view.quiet[1] and view.quiet[1]:IsShown(), "no red line under the form")
Eq(view.entries[1].under:GetText(), "can’t add anyone", "the index line does not say it")
Rules.SetTrigger("pvp")
Check(Rules.Quiet(Rule()) == nil, "pvp of the other faction quiet")
Items("form")["faction:mine"].frame:Click()
Check(Rules.Quiet(Rule()) ~= nil, "pvp of my faction not quiet")
Rules.RemoveFilter("faction")
Rules.AddFilter("guild")
Check(Rules.Quiet(Rule()) ~= nil, "same guild without a guild not quiet")
Rules.RemoveFilter("guild")
Rules.SetTrigger("grouped")

--------------------------------------------------------------------------
Section("delete leaves an Undo line; Undo puts it back where it was")

Rules.Close()
made = Fresh({ { trigger = "grouped", on = true }, { trigger = "seen", on = true }, { trigger = "traded" } }, false)
Rules.Open()
Rules.Show(made[2].id)
Items("form")["delete"].frame:Click()
Eq(#A.Rules(), 2, "Delete did not take it off")
Eq(A.RuleById(made[2].id), nil, "the deleted rule still listed")
Eq(Rule(), made[1], "the form not on the rule above")
Eq(Keys("list"), "rule:" .. made[1].id .. " undo:" .. made[2].id .. " rule:" .. made[3].id .. " new done",
    "the Undo line not where the rule was")
Items("list")["undo:" .. made[2].id].frame:Click()
Eq(A.Rules()[2], made[2], "Undo did not put it back in its place")
Eq(Rule(), made[2], "Undo did not open it")
Eq(Keys("list"), "rule:" .. made[1].id .. " rule:" .. made[2].id .. " rule:" .. made[3].id .. " new done", "after Undo")
-- Put away, the delete is final.
Rules.Delete(made[3])
Rules.Close()
Rules.Open()
Eq(Keys("list"), "rule:" .. made[1].id .. " rule:" .. made[2].id .. " new done", "the Undo line outlived the visit")

--------------------------------------------------------------------------
Section("the row menu: switch, duplicate, delete")

mock.contextMenu = nil
view.entries[1].hit:Click("RightButton")
Check(mock.contextMenu ~= nil, "a right click opened no menu")
local lines = {}
for _, c in ipairs(mock.contextMenu.children) do lines[#lines + 1] = c.text end
Eq(table.concat(lines, " | "), "Switch off | Duplicate | Delete", "the row menu's lines")
Check(mock.MenuClick("Duplicate"), "no Duplicate")
Eq(#A.Rules(), 3, "Duplicate did not add a rule")
local copy = A.Rules()[3]
Eq(copy.trigger, made[1].trigger, "the copy's trigger")
Eq(copy.on, false, "a copy starts on")
Eq(Rule(), copy, "the copy's form not open")
mock.contextMenu = nil
view.entries[1].hit:Click("RightButton")
mock.MenuClick("Switch off")
Eq(made[1].on, false, "Switch off did not")

--------------------------------------------------------------------------
Section("+ New rule: the picker, a preset on, a blank rule off")

made[2].preset = "seen"   -- (as a preset's rule would say)
Rules.Pick()
Check(Rules.State().picking, "the picker not up")
Eq(Keys("pick"), "start:group start:dungeon start:blank cancel", "the picker's strips (a preset in the list not offered again)")
-- (Start from above the strips: a deferred placement once read `y` after
-- it had moved past them, and laid the label under Cancel)
local function ScreenY(region) return select(5, region:GetPoint()) end
Check(ScreenY(Rules.Label("start")) > ScreenY(view.cancel), "Start from not above the strips")
Check(view.ghost:IsShown(), "no New rule line at the index's foot")
Check(not view.newRule:IsShown(), "+ New rule still shown while picking")
Check(not view.starts[3].strip:IsShown(), "the preset in the list still shown")
Items("pick")["cancel"].frame:Click()
Check(not Rules.State().picking, "Cancel left the picker")
Rules.Pick()
view.starts[2].strip.link:Click()
local new = A.Rules()[#A.Rules()]
Eq(new.preset, "dungeon", "the strip did not start its preset")
Eq(new.on, true, "a preset starts off")
Eq(Rule(), new, "its form not open")
Rules.Pick()
Rules.Start("blank")
new = A.Rules()[#A.Rules()]
Eq(new.trigger, "grouped", "a blank rule's trigger")
Eq(new.on, false, "a blank rule starts on")
Eq(new.tag, nil, "a blank rule has a tag")

--------------------------------------------------------------------------
Section("ten rules at most")

while #A.Rules() < A.MAX_RULES do Rules.Start("blank") end
Check(not view.newRule:IsShown(), "+ New rule at the most")
Check(view.most:IsShown(), "no line saying it is the most")
Rules.Pick()
Check(not Rules.State().picking, "the picker opened at the most")
Eq(Rules.Duplicate(A.Rules()[1]), nil, "a duplicate past the most")
Check(view.height <= Rules.SHEET.most, "the sheet grew past its most")

--------------------------------------------------------------------------
Section("every rule deleted: the index teaches, the form offers the presets")

for i = #A.Rules(), 1, -1 do Rules.Delete(A.Rules()[i]) end
Rules.Close()
Rules.Open()
Check(view.none:IsShown(), "no 'No rules yet.'")
Check(view.teach[1] and view.teach[1]:IsShown(), "no words to teach")
Eq(Keys("pick"), "start:group start:dungeon start:seen start:blank", "the empty state's picker (no Cancel)")
Rules.Start("group")
Eq(#A.Rules(), 1, "a start from the empty state")
Rules.Close()

--------------------------------------------------------------------------
Section("put away: one question for the visit, about the rules it changed")

-- Ana and Bo seen 3 times; Bo and Cy traded with. Seeded with the master off.
local ANA, BO, CY, DEE = "Player-1-0D000011", "Player-1-0D000012", "Player-1-0D000013", "Player-1-0D000014"
local function Seed()
    ns.SetSetting("autoAdd", false)
    T.BlankDiary()
    ns.db.sightings, ns.db.interactions, ns.db.meta.declined = {}, {}, {}
    for _, p in ipairs({ { ANA, "Ana" }, { BO, "Bo" }, { CY, "Cy" }, { DEE, "Dee" } }) do
        ns.Characters.Observe(p[1], { first = p[2], level = 20, class = "MAGE" })
    end
    for _, guid in ipairs({ ANA, BO }) do
        for i = 1, 3 do ns.Sightings.Record(guid, { source = "plate" }, MAP, mock.now + (i - 1) * HOUR) end
    end
    ns.Interactions.Add(BO, "trade", {})
    ns.Interactions.Add(CY, "trade", {})
end
local function Words()
    local out = {}
    for _, fs in ipairs(Sheet.View().texts) do
        if fs:IsShown() then out[#out + 1] = fs:GetText() end
    end
    return table.concat(out, " ")
end

-- Two rules new in the visit, their people overlapping: one sheet, each once.
Seed()
Fresh({ { trigger = "grouped", on = true } }, true)
Rules.Open()
local seen = Rules.Start("seen")
local traded = Rules.Start("blank")
Rules.SetTrigger("traded")
traded.on = true
Rules.Close()
Check(Sheet.Shown(), "two new rules with people waiting: no question")
Eq(#Sheet.View().list, 3, "not three people, each once")
local by = {}
for _, item in ipairs(Sheet.View().list) do by[item.guid] = item.rule end
Eq(by[BO], seen, "Bo passes both: not the first rule's")
Eq(by[CY], traded, "Cy's rule")
Eq(Sheet.View().title:GetText(), "People who already match your rules", "the title for several rules")
local words = Words()
Check(words:find("3 people already match your rules.", 1, true), "the count: " .. words)
Check(words:find("Seen 3 times: 2 people", 1, true), "seen's line: " .. words)
Check(words:find("Traded with you once: 1 person", 1, true), "traded's line: " .. words)
Sheet.Add()
Eq(ns.Diary.Count(), 3, "Add them did not add the three")
Eq(ns.Diary.Get(BO).addedContext.rule, seen.id, "Bo not added by the first rule")

-- One widened, one new: both asked about.
Seed()
made = Fresh({ { trigger = "seen", on = true, amount = 4 } }, true)
Rules.Open()
Rules.Show(made[1].id)
Items("form")["field:amount"].frame:Nudge(-1)
Eq(made[1].amount, 3, "setup: the amount not lowered")
traded = Rules.Start("blank")
Rules.SetTrigger("traded")
traded.on = true
Rules.Close()
Check(Sheet.Shown(), "widened and new: no question")
Eq(#Sheet.View().list, 3, "widened and new: not three")
Sheet.Close()

-- Switched on, then off again: nothing asked.
Seed()
made = Fresh({ { trigger = "seen", on = false } }, true)
Rules.Open()
view.entries[1].tick:Click()
view.entries[1].tick:Click()
Rules.Close()
Check(not Sheet.Shown(), "a rule switched on and off again asked")

-- Only the rules changed: a rule on before the visit, untouched, is not asked about.
Seed()
made = Fresh({ { trigger = "seen", on = true } }, true)
Rules.Open()
Rules.Close()
Check(not Sheet.Shown(), "an untouched rule asked")

-- The master off: nothing asked.
Seed()
made = Fresh({ { trigger = "seen", on = false } }, false)
Rules.Open()
view.entries[1].tick:Click()
Rules.Close()
Check(not Sheet.Shown(), "the master off, yet a question")

-- Everyone already in the diary: no sheet.
Seed()
made = Fresh({ { trigger = "seen", on = false } }, true)
ns.Diary.Add(ANA, { quiet = true })
ns.Diary.Add(BO, { quiet = true })
Rules.Open()
view.entries[1].tick:Click()
Rules.Close()
Check(not Sheet.Shown(), "nobody waiting, yet a sheet")

-- One rule: its name for a title, its line.
Seed()
made = Fresh({ { trigger = "seen", on = false } }, true)
Rules.Open()
view.entries[1].tick:Click()
Rules.Close()
Check(Sheet.Shown(), "one rule switched on: no question")
Eq(Sheet.View().title:GetText(), "Your rule", "a rule of no preset's title")
Sheet.Close()

-- Turning the page puts it away too, and asks.
Seed()
made = Fresh({ { trigger = "seen", on = false } }, true)
Rules.Open()
view.entries[1].tick:Click()
page:Hide()
Check(not Rules.Shown(), "the page hidden, the sheet stayed")
Check(Sheet.Shown(), "put away by the page: no question")
Sheet.Close()
page:Show()

