-- The controller (UI/Pad/, UI/Journal/Pad.lua; .claude/controller-plan.md):
-- nothing without Forever's Gamepad UI, presses nobody takes go on to the
-- game, B on its release, the ribbons on the shoulders, combat, the mouse
-- taking over, the scopes' stack, and the focus model.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local J = ns.UI.Journal

local function PadIn(on)
    mock.pad.ui, mock.pad.enabled, mock.pad.devices = on, on, on and { 1 } or {}
    mock.fire("GAME_PAD_ACTIVE_CHANGED", on)
end

-- The frames taking pad buttons right now.
local function Taking()
    local out = {}
    for _, f in ipairs(mock.frames) do
        if f.padButtons then out[#out + 1] = f end
    end
    return out
end

local function Press(frame, key)
    local down = mock.PadPress(frame, key, true)
    local up = mock.PadPress(frame, key, false)
    return down, up
end

local keys = {}
for _, r in ipairs(J.Ribbons()) do keys[#keys + 1] = r.key end

--------------------------------------------------------------------------
Section("without the Gamepad UI, nothing takes the pad")

ns.UI.ShowJournal()
ns.UI.SetJournalView(keys[1])
local book = ns.UI.JournalFrame()

mock.pad.enabled, mock.pad.devices, mock.pad.using = true, { 1 }, true
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(not Pad.Input.GamepadUI(), "the Gamepad UI on")
Check(not Pad.Input.Active(), "the pad active without the Gamepad UI")
Eq(#Taking(), 0, "frames taking pad buttons")
Eq(Pad.Catcher ~= nil, true, "no catcher maker")

--------------------------------------------------------------------------
Section("with it, the open book takes the pad")

PadIn(true)
Check(Pad.Input.Active(), "the pad not active")
Eq(Pad.Top() and Pad.Top().key, "journal", "the top scope")
local catcher = Pad.Catcher(book)
Check(catcher:IsGamePadButtonEnabled(), "the book's catcher not taking buttons")
Eq(#Taking(), 1, "frames taking pad buttons")

--------------------------------------------------------------------------
Section("presses nobody uses are taken all the same, never passed on")

-- (passed on from our handler, the game's binding runs tainted: the
-- mock errors on a handler that returns true, UI/Pad/Catcher.lua's header)
for _, key in ipairs({ "PAD3", "PAD4", "PADDUP", "PADLTRIGGER", "PADLSTICK", "PADRTRIGGER" }) do
    local down, up = Press(catcher, key)
    Check(down and up, key .. " did something")
end
Eq(J.view, keys[1], "a press nobody takes turned the book")

--------------------------------------------------------------------------
Section("the shoulders turn the ribbons, round the ends")

local down = mock.PadPress(catcher, "PADRSHOULDER", true)
Eq(down, false, "RB went on to the game")
mock.PadPress(catcher, "PADRSHOULDER", false)
Eq(J.view, keys[2], "RB: the next ribbon")
Press(catcher, "PADLSHOULDER")
Eq(J.view, keys[1], "LB: back")
Press(catcher, "PADLSHOULDER")
Eq(J.view, keys[#keys], "LB on the first: round to the last")
Press(catcher, "PADRSHOULDER")
Eq(J.view, keys[1], "RB on the last: round to the first")

--------------------------------------------------------------------------
Section("in combat the pad is the game's; the book stays open")

mock.inCombat = true
mock.fire("PLAYER_REGEN_DISABLED")
Check(book:IsShown(), "the book closed in combat")
Check(not catcher:IsGamePadButtonEnabled(), "the book kept the pad in combat")
Eq(Pad.Top() and Pad.Top().key, "journal", "the book's scope gone in combat")
-- (still lit, as a press could be on its way)
catcher:EnableGamePadButton(true)
Check(mock.PadPress(catcher, "PADRSHOULDER", true), "a press used in combat")
mock.PadPress(catcher, "PADRSHOULDER", false)
Eq(J.view, keys[1], "RB turned the book in combat")
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
Check(catcher:IsGamePadButtonEnabled(), "the pad not back on the book after combat")
Press(catcher, "PADRSHOULDER")
Eq(J.view, keys[2], "RB after combat")

--------------------------------------------------------------------------
Section("Escape's stand-in and the modifiers")

-- Escape's stand-in is taken, and its release puts our windows away from
-- here, as the game's Escape would (never the game's binding).
mock.cvars.GamePadEmulateEsc = "PAD3"
Eq(mock.PadPress(catcher, "PAD3", true), false, "the Escape button's press unused")
Check(book:IsShown(), "closed on Escape's press")
Eq(mock.PadPress(catcher, "PAD3", false), false, "the Escape button's release unused")
Check(not book:IsShown(), "Escape's stand-in did not close the book")
mock.cvars.GamePadEmulateEsc = nil
ns.UI.ShowJournal()
Check(catcher:IsGamePadButtonEnabled(), "the book opened again does not take the pad")
-- (the default stand-in, the Back button)
Press(catcher, "PADBACK")
Check(not book:IsShown(), "the Back button did not close the book")
ns.UI.ShowJournal()
-- (the book names the shoulders, so it takes them set up as Ctrl too)
mock.cvars.GamePadEmulateCtrl = "PADRSHOULDER"
Press(catcher, "PADRSHOULDER")
Eq(J.view, keys[3], "RB set up as Ctrl, named by the book")
mock.cvars.GamePadEmulateCtrl = nil

--------------------------------------------------------------------------
Section("B closes the book on its release, only a press it took")

-- A B held as the book opened: its release is the game's.
Check(mock.PadPress(catcher, "PAD2", false), "a release without its press taken")
Check(book:IsShown(), "closed by a release it never saw pressed")
Eq(mock.PadPress(catcher, "PAD2", true), false, "B's press went on")
Check(book:IsShown(), "closed on the press")
Eq(mock.PadPress(catcher, "PAD2", false), false, "B's release went on")
Check(not book:IsShown(), "B did not close the book")
Check(not catcher:IsGamePadButtonEnabled(), "a closed book takes the pad")

ns.UI.ShowJournal()
Check(catcher:IsGamePadButtonEnabled(), "the book opened again does not take the pad")

--------------------------------------------------------------------------
Section("the mouse taking over puts the pad down")

mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "the pad still in hand after a click")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher still on with the mouse")
-- (a click while a pad button is held is the pad's)
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
mock.keysDown.PAD1 = true
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(Pad.Input.Active(), "a click with a pad button held put the pad down")
mock.keysDown.PAD1 = nil

--------------------------------------------------------------------------
Section("forced: /sd pad on and off")

Pad.Input.Force("off")
Check(not Pad.Input.Active() and not catcher:IsGamePadButtonEnabled(), "forced off still active")
Pad.Input.Force(nil)
Check(Pad.Input.Active(), "auto again: not back")
PadIn(false)
Pad.Input.Force("on")
Check(Pad.Input.Active(), "forced on without a pad")
Pad.Input.Force(nil)
Check(not Pad.Input.Active(), "auto without a pad still active")
PadIn(true)

--------------------------------------------------------------------------
Section("a scope over the book: its focus, then its parent's keys")

local function Button(at)
    local b = CreateFrame("Button", nil, book)
    b:Show()
    b.at = at
    b.clicks = 0
    b.entered = 0
    b:SetScript("OnClick", function(self) self.clicks = self.clicks + 1 end)
    b:SetScript("OnEnter", function(self) self.entered = self.entered + 1 end)
    b:SetScript("OnLeave", function(self) self.entered = self.entered - 1 end)
    return b
end
local a, b, c = Button({ 0, 100 }), Button({ 0, 50 }), Button({ 200, 100 })
local backs = 0
local wanted = true
Pad.RegisterScope("test", {
    layer = 20, parent = "journal",
    host = function() return J.journal end,
    active = function() return wanted end,
    build = function(f)
        f:Group("left", { mode = "list", right = "right" })
        f:Group("right", { mode = "list", left = "left" })
        f:Add("left", { key = "a", frame = a })
        f:Add("left", { key = "b", frame = b })
        f:Add("right", { key = "c", frame = c })
    end,
    back = function()
        backs = backs + 1
        return backs == 1
    end,
    legend = function() return { { "PAD1", "Choose" } } end,
})
Pad.Refresh()
local scope = Pad.Top()
Eq(scope and scope.key, "test", "the higher scope not on top")
Eq(scope.focus:Current().key, "a", "not on the first item")
Eq(a.entered, 1, "its OnEnter (the tooltip) not run")

Eq(mock.PadPress(catcher, "PADDDOWN", true), false, "down went on to the game")
mock.PadPress(catcher, "PADDDOWN", false)
Eq(scope.focus:Current().key, "b", "down: not the next")
Eq(a.entered, 0, "the first's OnLeave not run")
Press(catcher, "PADDDOWN")
Eq(scope.focus:Current().key, "b", "down at the end went somewhere")
Check(not mock.PadPress(catcher, "PADDUP", true), "a direction at the end went on to the game")
mock.PadPress(catcher, "PADDUP", false)
Press(catcher, "PADDRIGHT")
Eq(scope.focus:Current().key, "c", "right: not the next group")
Press(catcher, "PADDLEFT")
Eq(scope.focus:Current().key, "a", "left: not back where it was in the group")
Press(catcher, "PAD1")
Eq(a.clicks, 1, "A did not click it")

local view = J.view
Press(catcher, "PADRSHOULDER")
Check(J.view ~= view, "RB not passed to the book")
Eq(Pad.Top().key, "test", "the test scope lost the pad")
Eq(Pad.Top().focus:Current().key, "a", "a page turned lost the place")

mock.PadPress(catcher, "PAD2", true)
mock.PadPress(catcher, "PAD2", false)
Eq(backs, 1, "B not the scope's first")
Check(book:IsShown(), "the scope's own back closed the book")
mock.PadPress(catcher, "PAD2", true)
mock.PadPress(catcher, "PAD2", false)
Check(not book:IsShown(), "B the scope did not take did not reach the book")
Eq(a.entered, 0, "the item's tooltip left up with the book closed")
ns.UI.ShowJournal()
-- (a page with no scope of its own: the settings have one)
ns.UI.SetJournalView(keys[1])
wanted = false
Pad.Refresh()
Eq(Pad.Top().key, "journal", "an inactive scope on top")

--------------------------------------------------------------------------
Section("held directions repeat")

wanted = true
Pad.Refresh()
local d = CreateFrame("Button", nil, book); d:Show(); d.at = { 0, 0 }
local e = CreateFrame("Button", nil, book); e:Show(); e.at = { 0, -50 }
Pad.Scope("test").build = function(f)
    f:Group("left", { mode = "list" })
    for _, x in ipairs({ a, b, d, e }) do f:Add("left", x) end
end
Pad.Refresh()
scope = Pad.Top()
mock.keysDown.PADDDOWN = true
mock.PadPress(catcher, "PADDDOWN", true)
Eq(scope.focus:Current().frame, b, "the press itself")
catcher.scripts.OnUpdate(catcher, 0.2)
Eq(scope.focus:Current().frame, b, "repeated before the first wait")
catcher.scripts.OnUpdate(catcher, 0.2)
Eq(scope.focus:Current().frame, d, "not repeated after it")
catcher.scripts.OnUpdate(catcher, 0.2)
Eq(scope.focus:Current().frame, e, "not repeated again")
mock.keysDown.PADDDOWN = nil
mock.PadPress(catcher, "PADDDOWN", false)
Check(catcher.scripts.OnUpdate == nil, "still repeating after the release")
Pad.RegisterScope("test", { host = function() end, active = function() return false end })

--------------------------------------------------------------------------
Section("the focus model on its own")

local F = Pad.Focus
local marks = {}
local f = F.New({ mark = function(item) marks[#marks + 1] = item.key end })
f:Group("g", { mode = "list", wrap = true })
local x1 = f:Add("g", { key = "1" })
f:Add("g", { key = "2", available = function() return false end })
f:Add("g", { key = "3" })
f:Done()
f:Show(true)
Eq(f:Current().key, "1", "first")
f:Move("DOWN")
Eq(f:Current().key, "3", "an unavailable item not skipped")
f:Move("DOWN")
Eq(f:Current().key, "1", "wrap")
f:Move("UP")
Eq(f:Current().key, "3", "wrap up")
Eq(table.concat(marks, ","), "1,3,1,3", "marks")

-- Rebuilt: where it was by key.
f:Clear()
f:Add("g", { key = "1" })
f:Add("g", { key = "3" })
f:Done()
Eq(f:Current().key, "3", "a rebuild lost the place")
Check(f:Current() ~= x1, "an old item kept")

-- A step takes left and right before a group jump.
local steps = 0
local g = F.New()
g:Group("s", { mode = "list", right = "t" })
g:Group("t")
g:Add("s", { key = "slider", step = function(dir) steps = steps + (dir == "RIGHT" and 1 or -1); return true end })
g:Add("t", { key = "other" })
g:Done()
g:Move("RIGHT")
Eq(steps, 1, "the step not taken")
Eq(g:Current().key, "slider", "moved off a slider by its step")

-- Spatial: the nearest that way, along before across.
local h = F.New()
h:Group("m", { mode = "spatial" })
local function At(key, x, y) h:Add("m", { key = key, center = function() return x, y end }) end
At("o", 0, 0); At("r", 100, 0); At("far", 300, 5); At("ru", 60, 80); At("u", 0, 100)
h:Focus("o", "m")
h:Move("RIGHT")
Eq(h:Current().key, "r", "right: not the nearest along the way")
h:Focus("o", "m")
h:Move("UP")
Eq(h:Current().key, "u", "up: not straight up")
h:Focus("o", "m")
Check(not h:Move("LEFT"), "left moved where nothing is")
Eq(h:Current().key, "o", "left moved")

--------------------------------------------------------------------------
Section("the look: the words go red and bold, and come back exactly")

local Look, Style = Pad.Look, ns.Style
local RED = Style.RUBRIC
local function Colour(fs) return { fs:GetTextColor() } end
local function Shadow(fs) return { fs:GetShadowColor() } end
local function Offset(fs) return { fs:GetShadowOffset() } end
local function SameAs(a, b) return table.concat(a, ",") == table.concat(b, ",") end
local function IsRed(fs)
    local c = Colour(fs)
    return math.abs(c[1] - RED[1]) < 0.01 and math.abs(c[2] - RED[2]) < 0.01 and math.abs(c[3] - RED[3]) < 0.01
end
local function State(fs) return { Colour(fs), Shadow(fs), Offset(fs) } end
local function Restored(fs, was)
    return SameAs(Colour(fs), was[1]) and SameAs(Shadow(fs), was[2]) and SameAs(Offset(fs), was[3])
end

Check(book:IsShown(), "the book not open for the look")
local words = Style.Text(book, Style.FONT.body)
words:SetText("Show the minimap button")
words:SetTextColor(0.2, 0.3, 0.4, 0.9)
local was = State(words)
Look.Mark(book, { key = "words", words = words })
Check(IsRed(words), "the words not rubric")
Eq(table.concat(Shadow(words), ","), table.concat({ RED[1], RED[2], RED[3], 1 }, ","), "the bold not the same red")
Eq(table.concat(Offset(words), ","), "1,0", "the bold not 1 px right")
Eq(words.recorded.calls.SetFontObject[1], Style.FONT.body, "the font object swapped")
local parts = Look.parts[book]
Check(parts.pen:IsShown(), "no box drawn")
Check(parts.pen.scripts.OnUpdate == nil, "a box drawn in without a press")
Look.Unmark(book, { key = "words", words = words })
Check(Restored(words, was), "the words not given back exactly")
Check(not parts.pen:IsShown(), "the box left up")

-- A colour the widget set meanwhile is its own.
Look.Mark(book, { key = "words", words = words })
words:SetTextColor(0, 0.5, 0, 1)
Look.Unmark(book)
Eq(table.concat(Colour(words), ","), "0,0.5,0,1", "a colour set meanwhile overwritten")
words:SetTextColor(0.2, 0.3, 0.4, 0.9)

-- Pressed there: the pen draws it in, stroke by stroke.
Look.Mark(book, { key = "pressed", words = words }, true)
local pen = parts.pen
Check(pen.scripts.OnUpdate ~= nil, "a press did not draw the box in")
Check(pen.count > 4 and not pen.strokes[pen.count]:IsShown(), "the last stroke there before it is drawn")
pen.scripts.OnUpdate(pen, Look.DRAW_TIME / 4)
Check(pen.strokes[1]:IsShown(), "the first stroke not drawn soon")
pen.scripts.OnUpdate(pen, Look.DRAW_TIME)
Check(pen.strokes[pen.count]:IsShown() and pen.scripts.OnUpdate == nil, "the box not finished in time")
Look.Unmark(book)

-- Words of nobody's: the pen round the frame, nothing recoloured.
local bare = CreateFrame("Button", nil, book)
bare:SetSize(40, 20)
Look.Mark(book, { key = "bare", frame = bare })
Check(parts.pen:IsShown(), "no mark on an item without words")
Look.Unmark(book)

--------------------------------------------------------------------------
Section("the look: its subheading a rubric, given back")

local heading = Style.Text(book, Style.FONT.heading)
heading:SetText("LOOK AND FEEL")
heading.rule = book:CreateTexture(nil, "ARTWORK")
local box = Style.Checkbox(book, 200, "Flat paper only", function() return false end, function() end)
box.group = heading
box:Show()
local wasLabel, wasHeading = State(box.label), State(heading)
Look.Mark(book, { key = "flat", frame = box, room = 7 })
Check(IsRed(box.label), "the checkbox's label not rubric")
Check(IsRed(heading), "the subheading not rubric")
Eq(table.concat(Offset(heading), ","), table.concat(wasHeading[3], ","), "the subheading made bold")
Check(parts.over:IsShown() and parts.rule:IsShown(), "the rule not laid over in red")
Look.Unmark(book)
Check(Restored(box.label, wasLabel), "the label not given back")
Check(Restored(heading, wasHeading), "the subheading not given back")
Check(not parts.over:IsShown(), "the red rule left up")

-- The kit stamps it: a settings control knows its subheading.
local stamped
for _, control in ipairs(ns.UI.Settings.page and ns.UI.Settings.page.controls or {}) do
    if control.group then stamped = control end
end
Check(stamped and stamped.group.rule ~= nil, "no settings control knows its subheading and its rule")

-- A slider: its reading and nib red, a chevron either side, one flashing.
local sliderRow = CreateFrame("Frame", nil, book)
sliderRow.label = Style.Text(sliderRow, Style.FONT.body)
sliderRow.label:SetText("Paper texture")
local slider = Style.Slider(sliderRow, 170, { min = 0, max = 100, step = 10, unit = "%" },
    function() return 50 end, function() end)
Check(slider.nib ~= nil, "the slider keeps no nib")
local wasReading = State(slider.reading)
local sliderItem = { key = "paper", frame = sliderRow, adjust = { reading = slider.reading, nib = slider.nib, scale = slider } }
Look.Mark(book, sliderItem)
Check(IsRed(slider.reading), "the reading not rubric")
Check(parts.nib:IsShown() and parts.chevrons.LEFT:IsShown() and parts.chevrons.RIGHT:IsShown(), "no red nib and chevrons")
Look.Step(book, sliderItem, "RIGHT")
Check(parts.chevrons.RIGHT.scripts.OnUpdate ~= nil, "the step's chevron did not flash")
Look.Unmark(book)
Check(Restored(slider.reading, wasReading), "the reading not given back")

--------------------------------------------------------------------------
Section("the look: put away, and the mouse taking over")

Look.Mark(book, { key = "words", words = words })
Look.Legend(book, { { "PAD2", "Close the book" } })
Check(parts.slip:IsShown(), "no slip")
Look.Hide(book)
Check(Restored(words, was), "Hide left the words red")
Check(not parts.slip:IsShown() and not parts.pen:IsShown(), "Hide left the slip or the box up")

local onScope = true
Pad.RegisterScope("look", {
    layer = 20, parent = "journal",
    host = function() return J.journal end,
    active = function() return onScope end,
    build = function(f)
        f:Group("g", { mode = "list" })
        f:Add("g", { key = "flat", frame = box })
        f:Add("g", { key = "words", words = words, available = function() return true end })
    end,
})
Pad.Refresh()
Check(IsRed(box.label) and IsRed(heading), "the scope's first item not marked")
Check(parts.slip:IsShown(), "the slip not shown with the pad in hand")
Press(catcher, "PADDDOWN")
Check(Restored(box.label, wasLabel) and Restored(heading, wasHeading), "moving on left the last one red")
Check(IsRed(words), "moving on did not mark the next")
Check(parts.pen.scripts.OnUpdate ~= nil, "a D-pad press did not draw the box in")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "the mouse did not take over")
Check(Restored(words, was), "the mouse taking over left the words red")
Check(not parts.slip:IsShown() and not parts.pen:IsShown(), "the mouse taking over left the slip or the box up")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(IsRed(words) and parts.slip:IsShown(), "the pad back: the mark and slip not back")
Check(parts.pen.scripts.OnUpdate == nil, "the pad back drew the box in, not at once")
onScope = false
Pad.Refresh()
Check(Restored(words, was), "the scope gone left the words red")

--------------------------------------------------------------------------
Section("the look: after a ribbon turn the title holds the box")

-- (the turn lands on a page with nothing to stand on: the empty People
-- page's book, there with the pad in hand, put away meanwhile)
local welcomeBook = J.journal.welcome and J.journal.welcome.book
if welcomeBook then welcomeBook:Hide() end

for _, r in ipairs(J.Ribbons()) do
    local spec = J.Page(r.key)
    local title = spec.title and spec.title()
    if title then title:Show() end
end
Eq(Pad.Top().key, "journal", "the book's scope not on top")
Check(parts.keys and parts.keys:IsShown(), "LB / RB not beside the ribbons")
Press(catcher, "PADRSHOULDER")
local title = J.Page(J.view).title and J.Page(J.view).title()
Check(title ~= nil, J.view .. " has no title")
Check(IsRed(title), "the opened page's title not boxed")
Check(parts.pen:IsShown() and parts.pen.scripts.OnUpdate ~= nil, "the turn did not draw the box in")
Eq(mock.PadPress(catcher, "PADDDOWN", true), false, "the first D-pad press went on to the game")
mock.PadPress(catcher, "PADDDOWN", false)
Check(not IsRed(title), "the title kept the box after a D-pad press")
Check(not parts.pen:IsShown(), "the box left up")
Check(mock.PadPress(catcher, "PADDDOWN", true), "a D-pad press after it not the game's")
mock.PadPress(catcher, "PADDDOWN", false)
Press(catcher, "PADRSHOULDER")
local next = J.Page(J.view).title()
Check(IsRed(next), "the next title not boxed")
mock.PadPress(catcher, "PAD2", true)
mock.PadPress(catcher, "PAD2", false)
Check(not IsRed(next), "the book closed with its title red")
ns.UI.ShowJournal()
Check(not IsRed(next), "the book opened again with its title boxed")
Check(parts.slip:IsShown(), "the slip not back with the book")
PadIn(false)
Check(not parts.slip:IsShown() and not parts.keys:IsShown(), "the slip or LB / RB up without the pad")
PadIn(true)
if welcomeBook then welcomeBook:Show() end

--------------------------------------------------------------------------
Section("glyphs by the pad's style")

local G = Pad.Glyphs
mock.pad.style = "Reverse"
G.Changed()
Eq(G.Style(), "Reverse", "the style")
Eq(G.Name("PAD1"), "B", "Switch: the bottom button")
mock.pad.style = "Shapes"
G.Changed()
Eq(G.Name("PAD1"), "Cross", "PlayStation: the bottom button")
Eq(G.Text("PAD2"), "Circle", "no icon: its name")
_G.KEY_PAD2_SHP = "|A:Gamepad_Shp_Circle_64:24:24|a"
Eq(G.Atlas("PAD2"), "Gamepad_Shp_Circle_64", "the game's markup's atlas")
Eq(G.Text("PAD2", 16), "|A:Gamepad_Shp_Circle_64:16:16|a", "inline icon")
_G.KEY_PAD2_SHP = nil
mock.pad.devices = {}
G.Changed()
Eq(G.Style(), "Generic", "no pad: generic")

--------------------------------------------------------------------------
Section("at rest the pad stays in hand; a tap picks it up again (found in the client)")

-- The input watcher: the frame listening for GLOBAL_MOUSE_DOWN.
local watcher
for _, f in ipairs(mock.frames) do
    if f.events.GLOBAL_MOUSE_DOWN and f.events.GAME_PAD_ACTIVE_CHANGED and f.scripts.OnUpdate then watcher = f end
end
Check(watcher ~= nil, "no input watcher")
Pad.Input.Force(nil)
mock.pad.ui, mock.pad.enabled, mock.pad.devices, mock.pad.using = true, true, { 1 }, true
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(Pad.Input.Active(), "not in hand to begin with")
-- At rest: the Gamepad UI moves the hidden cursor, IsUsingGamepad turns false.
for i = 1, 30 do
    mock.pointer = { (i % 2) * 400, (i % 3) * 300 }
    mock.pad.using = (i < 5)
    watcher.scripts.OnUpdate(watcher, 0.2)
end
Check(Pad.Input.Active(), "put down at rest: " .. tostring(Pad.Input.reason))
-- A mouse click puts it down; a single-frame tap picks it up again.
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "a mouse click did not put it down")
watcher.scripts.OnUpdate(watcher, 0.6)   -- (past the click's moment)
mock.keysDown.PAD1 = true
watcher.scripts.OnUpdate(watcher, 0.016)
mock.keysDown.PAD1 = nil
Check(Pad.Input.Active(), "a tap did not pick it up again")
Eq(Pad.Input.reason, "picked up: a pad button", "the reason recorded")

--------------------------------------------------------------------------
Section("after a click, a stick picks the pad up though the game still says pad (found in the client)")

mock.pad.using = true
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
watcher.scripts.OnUpdate(watcher, 0.2)   -- (the watcher has read the game's "pad in use")
Check(Pad.Input.Active(), "not in hand to begin with")
-- A pad whose stick rests off centre (and triggers resting high): the click
-- notes where it lies, and that never counts as moved.
mock.pad.sticks = { { x = 0, y = 0.6, len = 0.6 } }
mock.pad.axes = { 1, 1 }
mock.pad.buttons = { true }
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "the click did not put it down")
for _ = 1, 10 do watcher.scripts.OnUpdate(watcher, 0.1) end
Check(not Pad.Input.Active(), "picked up by a stick, trigger or button at rest: " .. Pad.Input.reason)
mock.pad.axes, mock.pad.buttons = {}, {}
-- While a mouse button is held (a drag of the camera), nothing picks it up.
-- (IsMouseButtonDown only here: the plates' drag tests read its absence.)
local held = {}
_G.IsMouseButtonDown = function(button) return held[button] == true end
held.RightButton = true
mock.pad.sticks = { { x = 0, y = -1, len = 1.0 } }
mock.pad.sticks[1].len = 1.2
watcher.scripts.OnUpdate(watcher, 0.1)
mock.keysDown.PAD1 = true
watcher.scripts.OnUpdate(watcher, 0.1)
mock.keysDown.PAD1 = nil
Check(not Pad.Input.Active(), "picked up while a mouse button was held")
held.RightButton = nil
_G.IsMouseButtonDown = nil
-- Within a moment of a click, nothing either.
mock.pad.sticks = { { x = 0, y = 0.6, len = 0.6 } }
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
mock.pad.sticks = { { x = 0, y = -1, len = 1.2 } }
watcher.scripts.OnUpdate(watcher, 0.1)
Check(not Pad.Input.Active(), "picked up a moment after a click")
-- Then a stick pushed well past where it lay picks it up.
watcher.scripts.OnUpdate(watcher, 0.5)
Check(Pad.Input.Active(), "a pushed stick did not pick it up")
Eq(Pad.Input.reason, "picked up: a stick", "the reason recorded")
mock.pad.sticks = {}

--------------------------------------------------------------------------
Section("the input watcher sleeps while no window of ours is open")

ns.UI.ShowJournal()
Check(Pad.Input.Watching(), "asleep with the book open")
ns.UI.CloseJournal()
Check(not Pad.Input.Watching(), "awake with the book closed")
Check(not watcher:IsShown(), "the watcher frame shown with nothing open")
-- Asleep, the game's own word still reaches it.
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Eq(Pad.Input.reason, "picked up: the game said so", "an event while asleep")
ns.UI.ShowJournal()
Check(Pad.Input.Watching(), "not awake again with the book opened")
