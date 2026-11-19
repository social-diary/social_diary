-- Auto-Add's rules, written on a sheet over the book
-- (.claude/features/auto-add-rules-ui.md; the rules are Core/AutoAdd.lua's).
--
-- The words of "Auto-Add Players" in Settings > Recording > People (a link
-- as well as the switch's label) lay a loose sheet
-- of ruled paper across the open book, straight (its lines are written in,
-- and an edit box cannot turn), as the note sheet and the custom card's slip
-- are, and like them the book under it takes no clicks while it lies there.
-- It is the Settings spread's grammar on one sheet: on the left a short
-- index of the rules, one per line with its tick, its words, and under them
-- its tag, its filters and how many it added; on the right the open rule as
-- a labelled form, a label column and one control per row. Choosing a line
-- on the left fills the form on the right.
--
-- Everything is saved as it changes, as every setting is (§4.1): a tick, a
-- choice, a number on Enter or let go, a tag on Enter or let go. There is no
-- Save and nothing to lose. A blank rule starts off, so an unfinished one
-- adds nobody.
--
-- The form is built from the trigger's registered spec (AutoAdd.Triggers:
-- label, amount, option), so it names no feature, and a later trigger needs
-- nothing here. A row that doesn't apply is not drawn; the form closes up
-- under it and the sheet's height follows, up to SHEET.most.
--
--   TRIGGER   a choice (a link and its menu; the pad's own menu with the
--             same generator, Rules.TriggerMenu)
--   AMOUNT    a number on the trigger's ladder (Style.NumberField's steps),
--             its unit after it
--   option    the trigger's one extra choice, if it has one: ticks for a set
--             (grouped's places: at least one stays ticked), else radios
--   FILTERS   each added filter its own line with "Remove"; then "+ Guild",
--             "+ Faction", "+ Level", "+ Class" strips for the rest
--   TAG       a radio row of chips, "(none)", the presets' tags and the tags
--             the diary uses most, then a line to write one
--   foot      why the rule can add nobody, in red (§4.5), and "Delete this
--             rule", red. A delete leaves an "Undo" line in the index for
--             the rest of the visit.
--
-- "+ New rule" turns the form into a picker of four strips: the three
-- presets and a blank rule (§2c). With no rules at all the picker is the
-- form, and the index teaches (§2d). At AutoAdd.MAX_RULES the link gives
-- way to a faded line.
--
-- Put away ("Done", B, turning the page, closing the book), the backfill
-- question is asked once for the visit, about every rule added, switched on
-- or widened in it, while the master switch is on (AutoAdd.AskAbout; the
-- sheet is UI/Windows/AutoAdd.lua's). The pad's scope is RulesPad.lua's.

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local Style = ns.Style
local FONT = Style.FONT
local AutoAdd = ns.AutoAdd

local Rules = {}
ns.UI.AutoAddRules = Rules

-- The sheet (x right, y down, from its top left). w: wide enough for an
-- index and a form side by side, with book showing round it (840 wide).
-- least, most: its height's bounds (the book's pages are 568). margin: its
-- writing's. title: the title's middle; waits: the faded line under it.
-- first: the first line's middle, both columns. list: the index's width;
-- rule: the hairline between the columns; form, formW: the form's column;
-- label: the form's label column, controls from form + label. row: from
-- row to row; wrap: a second line of the same row. toggle: a choice's box
-- and word at least. entry: an index line, its words and the line under
-- them `sub` apart. bottom: under the last. number: a number's line;
-- tagLine: the line to write a tag on.
local SHEET = { w = 640, least = 380, most = 548, margin = 28, title = 34, waits = 55, first = 80,
    list = 196, rule = 236, form = 248, formW = 364, label = 96, row = 30, wrap = 22, toggle = 88,
    entry = 40, sub = 15, bottom = 26, number = 40, tagLine = 150, chipGap = 6 }
Rules.SHEET = SHEET
-- A fresh sheet slipped into the book, not one carried in it: not folded,
-- hardly crumpled, its corners curled (the custom card's slip's).
local CREASE = { columns = { 0, 0.05, 0.95, 1 }, rows = { 0, 0.06, 0.94, 1 }, folds = { columns = {}, rows = {} },
    crumple = 0.5, drift = 0.4, edge = 0.6, wander = 0, shift = 3, lean = 2, curl = { lift = 5, pull = 3 } }
-- The class icons: their size and the gap between, and an unticked one's ink.
local ICON = { size = 20, gap = 3, faded = 0.3 }
-- A "+ Guild" strip (the custom card's "+ Add" strips): its height, its
-- writing's room each side, the gap between, its most turn.
local MORE = { h = 22, pad = 9, gap = 8, turn = 1.2 }
-- A strip of the picker: its height, the gap under it, its writing's room,
-- its most turn, its heading's and its words' middles from its top.
local START = { h = 44, gap = 8, pad = 12, turn = 0.5, title = 15, about = 31 }
-- The open rule's line: a faint wash of ink behind it (a selected row's).
local WASH = 0.06
-- How many of the diary's own tags are offered as chips, most used first.
local TAGS_USED = 6
-- The classes of the classic game, in the class list's order.
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
Rules.CLASSES = CLASSES

-- The sheet's words (draft English: the copywriter's pass follows).
local WORDS = {
    title = L["Auto-Add rules"], done = L["Done"],
    waits = L["Auto-Add Players is off: these rules wait until it’s on."],
    new = L["+ New rule"], most = L["There’s room for ten rules."], ghost = L["New rule"],
    none = L["No rules yet."],
    teach = L["A rule adds people to the diary for you: those you group with, see often, trade or whisper with, or fight. Start from one on the right."],
    start = L["Start from"], blank = L["A blank rule"], blankAbout = L["Choose everything yourself"],
    cancel = L["Cancel"],
    trigger = L["When##autorow"], amount = L["At least##autorow"], option = L["Which"], filters = L["Filters"], tag = L["Tag"],
    guild = L["In my guild"], noGuild = L["You’re not in a guild, so nobody matches."],
    mine = L["My faction"], other = L["The other faction"],
    between = L["Levels"], within = L["Within"], ofMine = L["levels of mine##autolevel"],
    remove = L["Remove"],
    noTag = L["no tag"], write = L["+ write one"],
    delete = L["Delete this rule"], deleted = L["Rule deleted."], undo = L["Undo"],
    switchOn = L["Switch on"], switchOff = L["Switch off"], duplicate = L["Duplicate"], deleteMenu = L["Delete"],
    quietLine = L["can’t add anyone"],
}
local ADD = { guild = L["+ Guild"], faction = L["+ Faction"], level = L["+ Level"], class = L["+ Class"] }

local view, K
-- The visit: the rule open (kept for the login), the list as it was when
-- the sheet was laid (for the backfill question), the deletes that can be
-- undone, the picker up, and what each rule had for a trigger it was
-- turned away from (flipping back restores it).
local state = { open = nil, snapshot = nil, deleted = {}, picking = false, kept = {} }

local function Capital(text) return ns.Locale.grammar.Capital(text or "") end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Copy(v) end
    return out
end

local function OpenRule() return state.open and AutoAdd.RuleById(state.open) or nil end

local function MyGuild()
    if not GetGuildInfo then return nil end
    local guild = ns.Plain((GetGuildInfo("player")))
    if type(guild) ~= "string" or guild == "" then return nil end
    return guild
end

local function MyLevel()
    local level = ns.Plain(UnitLevel("player"))
    return type(level) == "number" and level > 0 and level or 1
end

local function ClassName(class)
    local names = LOCALIZED_CLASS_NAMES_MALE
    return names and names[class] or Capital(class:lower())
end

--------------------------------------------------------------------------
-- What a rule says (the index)
--------------------------------------------------------------------------

-- Its filters in short, in the filters' order: "my guild", "lvl 20–30".
function Rules.FilterWords(rule)
    local out, f = {}, rule.filters or {}
    for _, key in ipairs(AutoAdd.FILTER_KEYS) do
        local v = f[key]
        if v ~= nil then
            if key == "guild" then
                out[#out + 1] = L["my guild"]
            elseif key == "faction" then
                out[#out + 1] = v == "other" and L["the other faction"] or L["my faction"]
            elseif key == "level" and type(v) == "table" then
                if v.within ~= nil then
                    out[#out + 1] = Fmt(L["within %d levels of mine"], tonumber(v.within) or 0)
                else
                    out[#out + 1] = Fmt(L["level %1$d–%2$d"], tonumber(v.min) or 1, tonumber(v.max) or 1)
                end
            elseif key == "class" and type(v) == "table" then
                local n, one = 0, nil
                for _, class in ipairs(CLASSES) do
                    if v[class] then n, one = n + 1, class end
                end
                out[#out + 1] = n == 1 and ClassName(one) or ns.Plural(n, L["%d class|%d classes##plural"])
            end
        end
    end
    return out
end

-- Why `rule` can add nobody (§4.5), or nil: a faction its trigger never
-- counts (AutoAdd's `sides`), the same guild of the other faction, the
-- same guild without one. Saved as it is; only said.
function Rules.Quiet(rule)
    local spec = AutoAdd.Trigger(rule.trigger)
    local f = rule.filters or {}
    if spec and spec.sides and f.faction ~= nil and f.faction ~= spec.sides then
        return spec.sides == "mine" and L["it only counts people of your own faction"]
            or L["it only counts people of the other faction"]
    end
    if f.guild and f.faction == "other" then return L["everyone in your guild is of your faction"] end
    if f.guild and not MyGuild() then return L["you’re not in a guild"] end
    return nil
end

-- The tag as the player reads it, or nil.
local function TagLabel(tag)
    if tag == nil or tag == "" then return nil end
    return ns.Diary.TagLabel(tag)
end

-- Its index line's small print: its tag, its filters, how many it added.
function Rules.Under(rule)
    local parts = { TagLabel(rule.tag) or L["no tag"] }
    for _, w in ipairs(Rules.FilterWords(rule)) do parts[#parts + 1] = w end
    local n = AutoAdd.Count(rule.id)
    if n > 0 then parts[#parts + 1] = ns.Plural(n, L["%d added|%d added##autocount##plural"]) end
    return table.concat(parts, ", ")
end

-- What it says, as a line starts.
function Rules.Words(rule) return Capital(AutoAdd.Describe(rule)) end

--------------------------------------------------------------------------
-- Changing a rule (saved as it changes)
--------------------------------------------------------------------------

local Lay

local function Relay()
    if view and view:IsShown() then Lay() end
    ns.UI.Pad.Refresh()
end

-- Where the pad goes after the next lay: { group, key } (RulesPad.lua).
local function PadTo(group, key)
    if view then view.padTo = { group = group, key = key } end
end

local function SetTrigger(key)
    local rule = OpenRule()
    local spec = AutoAdd.Trigger(key)
    if not (rule and spec) or rule.trigger == key then return end
    state.kept[rule.id] = state.kept[rule.id] or {}
    local kept = state.kept[rule.id]
    kept[rule.trigger] = { amount = rule.amount, option = Copy(rule.option) }
    local back = kept[key]
    rule.trigger = key
    -- (the new trigger's default, never the old number: "5 kills" from "5
    -- minutes" would be a surprise; flipping back gives back what it had)
    rule.amount = back and back.amount or (spec.amount and spec.amount.default or 1)
    if back then rule.option = Copy(back.option)
    else rule.option = spec.option and Copy(spec.option.default) or nil end
    Relay()
end
Rules.SetTrigger = SetTrigger

-- The trigger a step `dir` ("LEFT" / "RIGHT") along the list from the open
-- rule's: the pad's left and right on the trigger.
function Rules.Cycle(dir)
    local rule = OpenRule()
    if not rule then return end
    local list = AutoAdd.Triggers()
    for i, spec in ipairs(list) do
        if spec.key == rule.trigger then
            local to = list[i + (dir == "LEFT" and -1 or 1)]
            if to then SetTrigger(to.key) end
            return
        end
    end
end

-- The menu of triggers, the mouse's and the pad's (Pad.Menu.Open).
function Rules.TriggerMenu()
    local choices = {}
    for _, spec in ipairs(AutoAdd.Triggers()) do choices[#choices + 1] = { label = spec.label, key = spec.key } end
    return Style.ChoiceGenerator(WORDS.trigger, choices,
        function() local rule = OpenRule() return rule and rule.trigger end, SetTrigger)
end

local function Filters(rule)
    rule.filters = rule.filters or {}
    return rule.filters
end

local function Kept(rule)
    state.kept[rule.id] = state.kept[rule.id] or {}
    return state.kept[rule.id]
end

-- A level filter's two ways, from what it had or near the player's level.
local function Between(rule)
    local k, my, top = Kept(rule).level or {}, MyLevel(), ns.Journey.MaxLevel()
    return { min = k.min or math.max(1, my - 5), max = k.max or math.min(top, my + 5) }
end
local function Within(rule)
    local k = Kept(rule).level or {}
    return { within = k.within or 5 }
end

local function KeepLevel(rule)
    local v = rule.filters and rule.filters.level
    if type(v) ~= "table" then return end
    local k = Kept(rule)
    k.level = k.level or {}
    if v.within ~= nil then k.level.within = v.within else k.level.min, k.level.max = v.min, v.max end
end

local DEFAULTS = {
    guild = function() return true end,
    faction = function() return "mine" end,
    level = function(rule) return Within(rule) end,
    class = function()
        local all = {}
        for _, class in ipairs(CLASSES) do all[class] = true end
        return all
    end,
}

function Rules.AddFilter(key)
    local rule = OpenRule()
    if not (rule and DEFAULTS[key]) then return end
    Filters(rule)[key] = DEFAULTS[key](rule)
    PadTo("form", key == "faction" and "faction:mine" or key == "level" and "levelway:within"
        or key == "class" and ("class:" .. CLASSES[1]) or "off:" .. key)
    Relay()
end

function Rules.RemoveFilter(key)
    local rule = OpenRule()
    if not (rule and rule.filters) then return end
    if key == "level" then KeepLevel(rule) end
    rule.filters[key] = nil
    if next(rule.filters) == nil then rule.filters = nil end
    PadTo("form", "more:" .. key)
    Relay()
end

local function SetTag(tag)
    local rule = OpenRule()
    if not rule then return end
    rule.tag = (tag ~= nil and tag ~= "") and tag or nil
    Relay()
end
Rules.SetTag = SetTag

local function ToggleClass(class)
    local rule = OpenRule()
    local set = rule and rule.filters and rule.filters.class
    if type(set) ~= "table" then return end
    if set[class] then
        -- (the last one stays: to match every class, remove the filter)
        local n = 0
        for _, c in ipairs(CLASSES) do if set[c] then n = n + 1 end end
        if n <= 1 then return end
        set[class] = nil
    else
        set[class] = true
    end
    Relay()
end
Rules.ToggleClass = ToggleClass

--------------------------------------------------------------------------
-- The list: open, add, duplicate, delete, undo
--------------------------------------------------------------------------

-- The rule's form, the pad on its trigger.
function Rules.Show(id)
    state.open, state.picking = id, false
    PadTo("form", "field:trigger")
    Relay()
end

function Rules.Pick()
    if #AutoAdd.Rules() >= AutoAdd.MAX_RULES then return end
    state.picking = true
    PadTo("pick", nil)
    Relay()
end

function Rules.CancelPick()
    state.picking = false
    PadTo("list", state.open and ("rule:" .. state.open) or nil)
    Relay()
end

-- A rule from a preset ("group", "dungeon", "seen", on) or a blank one
-- ("blank": grouped, its defaults, off), at the foot, its form open.
function Rules.Start(key)
    local rule
    if key == "blank" then
        rule = AutoAdd.NewRule("grouped", {})
    else
        local preset = AutoAdd.Preset(key)
        rule = preset and AutoAdd.NewRule(preset.trigger, preset)
    end
    if not rule then return nil end
    Rules.Show(rule.id)
    return rule
end

function Rules.Duplicate(rule)
    local fields = Copy(rule)
    fields.id, fields.preset, fields.on = nil, nil, false
    local copy = AutoAdd.NewRule(rule.trigger, fields)
    if copy then Rules.Show(copy.id) end
    return copy
end

local function IndexOf(rule)
    for i, r in ipairs(AutoAdd.Rules()) do if r == rule then return i end end
end

-- Off the list at once; an "Undo" line where it was for the rest of the
-- visit, and the form on the rule above it.
function Rules.Delete(rule)
    local rules = AutoAdd.Rules()
    local i = IndexOf(rule)
    if not i then return end
    table.remove(rules, i)
    state.deleted[#state.deleted + 1] = { rule = rule, at = i }
    local next = rules[i - 1] or rules[i]
    if state.open == rule.id then state.open = next and next.id or nil end
    state.picking = false
    PadTo("list", "undo:" .. rule.id)
    Style.PlaySound("tear")
    Relay()
end

function Rules.Undo(rule)
    local rules = AutoAdd.Rules()
    if #rules >= AutoAdd.MAX_RULES then return false end
    for k, d in ipairs(state.deleted) do
        if d.rule == rule then
            table.remove(state.deleted, k)
            table.insert(rules, math.min(d.at, #rules + 1), rule)
            state.open, state.picking = rule.id, false
            PadTo("list", "rule:" .. rule.id)
            Relay()
            return true
        end
    end
    return false
end

-- An index line's menu, the mouse's right click and the pad's Y.
function Rules.RowMenu(rule)
    return function(_, root)
        root:CreateButton(rule.on and WORDS.switchOff or WORDS.switchOn, function()
            rule.on = not rule.on
            Relay()
        end)
        local dup = root:CreateButton(WORDS.duplicate, function() Rules.Duplicate(rule) end)
        if #AutoAdd.Rules() >= AutoAdd.MAX_RULES and dup and dup.SetEnabled then dup:SetEnabled(false) end
        root:CreateButton(WORDS.deleteMenu, function() Rules.Delete(rule) end)
    end
end

--------------------------------------------------------------------------
-- The sheet
--------------------------------------------------------------------------

-- Everything made on it, and what this lay used: the rest is hidden.
local all, used, boxes = {}, {}, {}
local function TypeOf(w)
    -- (the mock's widgets say frameType, the client's GetObjectType)
    return w.frameType or w:GetObjectType()
end
local function Made(w)
    all[#all + 1] = w
    if TypeOf(w) == "EditBox" then boxes[#boxes + 1] = w end
    return w
end
local function Use(w)
    used[w] = true
    w:Show()
    return w
end

local function Text(font) return Made(Style.Text(view.sheet, font)) end

-- What the pad stands on, recorded as it is laid (RulesPad.lua): by group,
-- in reading order, each { key, frame, kind, x, y, ... }.
local items
local function Item(group, item)
    items[group] = items[group] or {}
    items[group][#items[group] + 1] = item
    return item
end

-- `text` in `fs`, cut with an ellipsis to `width`.
local function Cut(fs, text, width)
    fs:SetText(text)
    if K.Width(fs) <= width then return end
    local cut = text
    while #cut > 0 do
        cut = cut:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
        fs:SetText(cut .. "…")
        if K.Width(fs) <= width then return end
    end
end

-- A frame's labels, made once by key.
local labels = {}
local function Label(key, text)
    local fs = labels[key]
    if not fs then
        fs = Text(FONT.heading)
        labels[key] = fs
    end
    fs:SetText(Style.Upper(text))
    return Use(fs)
end

-- A box to tick (a choice of a row), its width from its words.
local function Toggle(text, get, set)
    local probe = view.probe
    probe:SetText(text)
    local w = math.max(SHEET.toggle, K.Width(probe) + 13 + 7 + 8)
    w = math.min(w, SHEET.formW - SHEET.label)
    local box = Made(Style.Checkbox(view.sheet, w, text, get, set))
    box.width = w
    return box
end

-- The trigger's number field and unit, made once per trigger.
local amounts = {}
local function Amount(spec)
    local a = amounts[spec.key]
    if a then return a end
    local A = spec.amount or { min = 1, max = 99, default = 1 }
    a = {}
    a.box = Made(Style.NumberField(view.sheet, SHEET.number, A.min or 1, A.max or 99,
        function()
            local rule = OpenRule()
            return rule and tonumber(rule.amount) or A.default or A.min or 1
        end,
        function(n)
            local rule = OpenRule()
            if rule then rule.amount = n end
            Relay()
        end, A.steps))
    a.unit = Text(FONT.body)
    a.unit:SetText(A.unit or "")
    Style.Tooltip(a.box, Fmt(L["From %1$d to %2$d"], A.min or 1, A.max or 99))
    amounts[spec.key] = a
    return a
end

-- The trigger's option's boxes, made once per trigger: { [value] = box }.
local options = {}
local function Options(spec)
    local o = options[spec.key]
    if o then return o end
    local O = spec.option
    o = { order = {} }
    for _, choice in ipairs(O.choices) do
        local value = choice[1]
        local box
        if O.multi then
            box = Toggle(choice[2], function()
                local rule = OpenRule()
                return rule and type(rule.option) == "table" and rule.option[value] == true
            end, function(on)
                local rule = OpenRule()
                if not rule then return end
                if type(rule.option) ~= "table" then rule.option = {} end
                if not on then
                    -- (at least one stays: the box doesn't move)
                    local n = 0
                    for _, c in ipairs(O.choices) do if rule.option[c[1]] then n = n + 1 end end
                    if n <= 1 then box:SetChecked(true) return end
                    rule.option[value] = nil
                else
                    rule.option[value] = true
                end
                Relay()
            end)
        else
            box = Toggle(choice[2], function()
                local rule = OpenRule()
                return rule and rule.option == value
            end, function()
                local rule = OpenRule()
                if not rule then return end
                -- (a radio: the one on stays on)
                rule.option = value
                box:SetChecked(true)
                Relay()
            end)
        end
        o[value] = box
        o.order[#o.order + 1] = value
    end
    options[spec.key] = o
    return o
end

-- A level number: "min", "max" (between) or "within".
local function LevelBox(which)
    local top = ns.Journey.MaxLevel()
    local lo, hi = which == "within" and 0 or 1, which == "within" and top - 1 or top
    local box = Made(Style.NumberField(view.sheet, 30, lo, hi,
        function()
            local rule = OpenRule()
            local v = rule and rule.filters and rule.filters.level
            if type(v) ~= "table" then return lo end
            if which == "within" then return tonumber(v.within) or Within(rule).within end
            local b = v.within == nil and v or Between(rule)
            return tonumber(b[which]) or lo
        end,
        function(n)
            local rule = OpenRule()
            if not (rule and rule.filters and rule.filters.level) then return end
            local v
            if which == "within" then
                v = { within = n }
            else
                -- (a number of the other way chooses this way; a > b swap)
                local cur = rule.filters.level
                v = cur.within == nil and { min = cur.min, max = cur.max } or Between(rule)
                v[which] = n
                if (v.min or 1) > (v.max or top) then v.min, v.max = v.max, v.min end
            end
            rule.filters.level = v
            KeepLevel(rule)
            Relay()
        end))
    return box
end

local function NewStrip(words, seed)
    local strip = Made(ns.UI.PaperStrip(view.sheet))
    strip.addKey = seed
    strip.words = Style.Text(strip, FONT.noteWritten)
    strip.words:SetFont(Style.NEUTON_ITALIC, 14, "")
    strip.words:SetJustifyH("CENTER")
    strip.words:SetText(words)
    return strip
end

local function Build()
    local book = ns.UI.JournalFrame()
    view, K = ns.UI.LooseSheet(book, SHEET.w, SHEET.least, { crease = CREASE, straight = true })
    local S = view.sheet
    view.probe = Style.Text(S, FONT.body)
    view.probe:Hide()

    view.title = Text(FONT.page)
    view.title:SetText(WORDS.title)
    view.done = Made(K.Link(FONT.strong, function() Rules.Close() end))
    view.done:SetText(WORDS.done)
    view.waits = Text(FONT.small)
    view.waits:SetText(WORDS.waits)
    view.hairline = Made(K.Texture("ARTWORK", 1))
    local INK = Style.INK
    view.hairline:SetColorTexture(INK[1], INK[2], INK[3], 0.18)

    -- The index.
    view.entries = {}
    view.newRule = Made(K.Link(FONT.body, function() Rules.Pick() end))
    view.newRule:SetText(WORDS.new)
    view.most = Text(FONT.small)
    view.most:SetText(WORDS.most)
    view.ghost = Text(FONT.faded)
    view.ghost:SetText(WORDS.ghost)
    view.none = Text(FONT.strong)
    view.none:SetText(WORDS.none)
    view.teach = {}

    -- The form.
    view.trigger = Made(K.Link(FONT.strong, function(self)
        MenuUtil.CreateContextMenu(self, Rules.TriggerMenu())
    end))
    view.note = Text(FONT.small)
    view.guild = Text(FONT.body)
    view.guild:SetText(WORDS.guild)
    view.noGuild = Text(FONT.small)
    view.noGuild:SetText(WORDS.noGuild)
    view.faction = {
        mine = Toggle(WORDS.mine, function()
            local rule = OpenRule() return rule and rule.filters and rule.filters.faction == "mine"
        end, function()
            local rule = OpenRule() if not rule then return end
            Filters(rule).faction = "mine"
            Relay()
        end),
        other = Toggle(WORDS.other, function()
            local rule = OpenRule() return rule and rule.filters and rule.filters.faction == "other"
        end, function()
            local rule = OpenRule() if not rule then return end
            Filters(rule).faction = "other"
            Relay()
        end),
    }
    local function Way(within)
        return function()
            local rule = OpenRule()
            local v = rule and rule.filters and rule.filters.level
            return type(v) == "table" and ((v.within ~= nil) == within)
        end
    end
    local function SetWay(within)
        return function()
            local rule = OpenRule()
            if not (rule and rule.filters and rule.filters.level) then return end
            KeepLevel(rule)
            rule.filters.level = within and Within(rule) or Between(rule)
            Relay()
        end
    end
    view.levelWay = {
        between = Made(Style.Checkbox(S, 82, WORDS.between, Way(false), SetWay(false))),
        within = Made(Style.Checkbox(S, 82, WORDS.within, Way(true), SetWay(true))),
    }
    view.levelBox = { min = LevelBox("min"), max = LevelBox("max"), within = LevelBox("within") }
    -- (between the two numbers a dash, not a word: "20 – 30")
    view.levelAnd = Text(FONT.body)
    view.levelAnd:SetText("–")
    view.levelOf = Text(FONT.body)
    view.levelOf:SetText(WORDS.ofMine)
    view.icons = {}
    for _, class in ipairs(CLASSES) do
        local icon = Made(CreateFrame("Button", nil, S))
        icon.class = class
        icon.art = icon:CreateTexture(nil, "ARTWORK")
        icon.art:SetAllPoints()
        Style.ClassIconOrInk(icon.art, class)
        icon:SetScript("OnClick", function() ToggleClass(class) end)
        Style.Tooltip(icon, function() return ClassName(class) end)
        view.icons[class] = icon
    end
    view.offs = {}
    view.mores = {}
    for _, key in ipairs(AutoAdd.FILTER_KEYS) do
        local k = key
        view.offs[k] = Made(K.Link(FONT.small, function() Rules.RemoveFilter(k) end))
        view.offs[k]:SetText(WORDS.remove)
        view.mores[k] = NewStrip(ADD[k] or k, k)
    end
    view.chips = {}
    view.tagLine = Made(Style.WritingLine(S, SHEET.tagLine, FONT.note, WORDS.write, function(text)
        local tag = ns.Diary.CleanTag(text)
        view.tagLine:SetValue("")
        if tag then SetTag(tag) end
    end))
    view.tagLine:SetMaxLetters(24)
    view.quiet = {}
    view.delete = Made(K.Link(FONT.body, function()
        local rule = OpenRule()
        if rule then Rules.Delete(rule) end
    end))
    view.delete:SetText(WORDS.delete)
    view.delete:SetColor(Style.ACCENT[1], Style.ACCENT[2], Style.ACCENT[3])

    -- The picker.
    view.starts = {}
    for _, key in ipairs(AutoAdd.PresetKeys()) do view.starts[#view.starts + 1] = { key = key } end
    view.starts[#view.starts + 1] = { key = "blank" }
    for _, s in ipairs(view.starts) do
        s.strip = Made(ns.UI.PaperStrip(S))
        s.title = Style.Text(s.strip, FONT.strong)
        s.about = Style.Text(s.strip, FONT.small)
    end
    view.cancel = Made(K.Link(FONT.body, function() Rules.CancelPick() end))
    view.cancel:SetText(WORDS.cancel)

    -- Put away however it goes, the visit ends (and the question is asked).
    view:HookScript("OnHide", function() Rules.Finish() end)
    view:Hide()
end

-- The settings page going (a ribbon, the book shut) takes the sheet with it.
local hookedPage
local function HookPage()
    local page = ns.UI.Settings.page
    if page and page ~= hookedPage then
        hookedPage = page
        page:HookScript("OnHide", function()
            if Rules.Shown() then Rules.Close() end
        end)
    end
end

-- An index line, made as wanted.
local function Entry(i)
    local e = view.entries[i]
    if e then return e end
    local S = view.sheet
    e = {}
    e.wash = Made(K.Texture("ARTWORK", 1))
    local INK = Style.INK
    e.wash:SetColorTexture(INK[1], INK[2], INK[3], WASH)
    e.tick = Made(Style.Checkbox(S, 20, "", function() return e.rule and e.rule.on end, function(on)
        if not e.rule then return end
        e.rule.on = on and true or false
        Relay()
    end))
    e.words = Text(FONT.body)
    e.under = Text(FONT.small)
    e.hit = Made(CreateFrame("Button", nil, S))
    e.hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    e.hit:SetScript("OnClick", function(self, button)
        if not e.rule then return end
        if button == "RightButton" then
            MenuUtil.CreateContextMenu(self, Rules.RowMenu(e.rule))
        else
            Rules.Show(e.rule.id)
        end
    end)
    e.hit:SetScript("OnEnter", function()
        if e.rule and e.rule.id ~= state.open then e.words:SetFontObject(FONT.strong) end
    end)
    e.hit:SetScript("OnLeave", function()
        if e.rule then e.words:SetFontObject(e.rule.id == state.open and FONT.strong or FONT.body) end
    end)
    e.gone = Text(FONT.small)
    e.gone:SetText(WORDS.deleted)
    e.undo = Made(K.Link(FONT.small, function() if e.deleted then Rules.Undo(e.deleted) end end))
    e.undo:SetText(WORDS.undo)
    view.entries[i] = e
    return e
end

-- The index's lines: the rules, and an undo line where each deleted one was.
local function Lines()
    local out = {}
    for _, rule in ipairs(AutoAdd.Rules()) do out[#out + 1] = { rule = rule } end
    for _, d in ipairs(state.deleted) do
        table.insert(out, math.min(d.at, #out + 1), { deleted = d.rule })
    end
    return out
end

-- The tags offered as chips: none, the presets', the diary's most used,
-- and the rule's own.
local function TagChoices(rule)
    local out, seen = { "" }, { [""] = true }
    local function Offer(tag)
        if tag and not seen[tag] then
            seen[tag] = true
            out[#out + 1] = tag
        end
    end
    for _, preset in ipairs(AutoAdd.Presets()) do Offer(preset.tag) end
    local counts = {}
    for _, entry in ns.Diary.Each() do
        for _, tag in ipairs(entry.tags or {}) do counts[tag] = (counts[tag] or 0) + 1 end
    end
    local most = {}
    for tag in pairs(counts) do most[#most + 1] = tag end
    table.sort(most, function(a, b)
        if counts[a] ~= counts[b] then return counts[a] > counts[b] end
        return a < b
    end)
    for i = 1, math.min(TAGS_USED, #most) do Offer(most[i]) end
    Offer(rule.tag)
    return out
end

local function Chip(tag)
    local chip = view.chips[tag]
    if chip then return chip end
    chip = Made(Style.TagButton(view.sheet))
    chip:SetScript("OnClick", function() SetTag(tag) end)
    view.chips[tag] = chip
    return chip
end

-- Lays the sheet as it stands: the index, the form or the picker, the
-- height from the taller, and records what the pad can stand on.
function Lay()
    wipe(used)
    items = {}
    local M, W = SHEET.margin, SHEET.w
    local FX = SHEET.form
    local CX, RX = FX + SHEET.label, FX + SHEET.formW
    local ops = {}
    local function Put(fn) ops[#ops + 1] = fn end
    local rules = AutoAdd.Rules()
    local rule = OpenRule()
    if not rule and not state.picking then
        rule = rules[1]
        state.open = rule and rule.id or nil
    end
    local picking = state.picking or #rules == 0
    local empty = #rules == 0 and #state.deleted == 0

    -- The head.
    Put(function()
        K.PlaceText(Use(view.title), M, SHEET.title)
        view.done:PlaceAt(W - M, SHEET.title, "RIGHT")
        Use(view.done)
        if not AutoAdd.On() then K.PlaceText(Use(view.waits), M, SHEET.waits) end
    end)

    -- The index.
    local y = SHEET.first
    local listW = SHEET.list
    if empty then
        Put(function() K.PlaceText(Use(view.none), M, SHEET.first) end)
        local lines = K.Wrap(WORDS.teach, listW, FONT.body)
        local ty = SHEET.first + 26
        for i, line in ipairs(lines) do
            local fs = view.teach[i] or Text(FONT.body)
            view.teach[i] = fs
            fs:SetText(line)
            local at = ty
            Put(function() K.PlaceText(Use(fs), M, at) end)
            ty = ty + 16
        end
        y = ty
    else
        for i, line in ipairs(Lines()) do
            local e = Entry(i)
            local at = y
            if line.rule then
                local r = line.rule
                e.rule, e.deleted = r, nil
                local open = r.id == state.open and not picking
                local quiet = Rules.Quiet(r)
                Put(function()
                    if open then K.Place(Use(e.wash), M - 6, at - 12, listW + 12, SHEET.entry - 4) end
                    e.tick:Refresh()
                    K.PlaceButton(Use(e.tick), M, at - 9, 16, 17)
                    e.words:SetFontObject(open and FONT.strong or FONT.body)
                    Cut(e.words, Rules.Words(r), listW - 20)
                    K.PlaceText(Use(e.words), M + 20, at)
                    if quiet then
                        Cut(e.under, WORDS.quietLine, listW - 20)
                        e.under:SetTextColor(Style.RUBRIC[1], Style.RUBRIC[2], Style.RUBRIC[3])
                    else
                        Cut(e.under, Rules.Under(r), listW - 20)
                        e.under:SetTextColor(Style.INK_FADED[1], Style.INK_FADED[2], Style.INK_FADED[3])
                    end
                    K.PlaceText(Use(e.under), M + 20, at + SHEET.sub)
                    -- (switched off: its words faded, as a setting that waits)
                    local a = r.on and 1 or 0.5
                    e.words:SetAlpha(a)
                    e.under:SetAlpha(a)
                    K.PlaceButton(Use(e.hit), M + 18, at - 10, listW - 18, SHEET.entry - 8)
                end)
                Item("list", { key = "rule:" .. r.id, kind = "rule", rule = r, frame = e.hit, words = e.words, y = at })
            else
                local r = line.deleted
                e.rule, e.deleted = nil, r
                local room = #rules < AutoAdd.MAX_RULES
                Put(function()
                    local left, w = K.PlaceText(Use(e.gone), M + 20, at)
                    if room then
                        e.undo:PlaceAt(left + w + 6, at)
                        Use(e.undo)
                    end
                end)
                if room then Item("list", { key = "undo:" .. r.id, kind = "link", frame = e.undo, y = at }) end
            end
            y = y + SHEET.entry
        end
        local at = y - 8
        if state.picking then
            Put(function() K.PlaceText(Use(view.ghost), M + 20, at) end)
        elseif #rules >= AutoAdd.MAX_RULES then
            Put(function() K.PlaceText(Use(view.most), M, at) end)
        else
            Put(function()
                view.newRule:PlaceAt(M, at)
                Use(view.newRule)
            end)
            Item("list", { key = "new", kind = "link", frame = view.newRule, y = at })
        end
        y = at + 16
    end
    Item("list", { key = "done", kind = "link", frame = view.done, y = SHEET.title })
    local listBottom = y

    -- The form, or the picker.
    y = SHEET.first
    if picking then
        local label = Label("start", WORDS.start)
        -- (its own local: Put runs later, after `y` has moved on)
        local labelAt = y
        Put(function() K.PlaceText(label, FX, labelAt) end)
        local top = y + 14
        -- A preset already in the list is not offered again (Duplicate
        -- copies a rule); a blank rule always is.
        local have = {}
        for _, r in ipairs(rules) do if r.preset then have[r.preset] = true end end
        local offer = {}
        for _, s in ipairs(view.starts) do
            if not have[s.key] then offer[#offer + 1] = s end
        end
        for _, s in ipairs(offer) do
            local key, preset = s.key, s.key ~= "blank" and AutoAdd.Preset(s.key) or nil
            local title, about
            if preset then
                title = AutoAdd.PresetName(key)
                local parts = { Rules.Words(preset) }
                if preset.tag then parts[#parts + 1] = TagLabel(preset.tag) end
                about = table.concat(parts, ", ")
            else
                title, about = WORDS.blank, WORDS.blankAbout
            end
            local at = top
            Put(function()
                local strip, w = s.strip, SHEET.formW
                strip:SetNote({ size = { w, START.h }, guid = key, turn = START.turn, seed = "start:" .. key,
                    onClick = function(k) Rules.Start(k) end })
                strip:Layout(FX, at, w)
                strip.padAt = { FX + w / 2, at + START.h / 2 }
                local tw = w - 2 * START.pad
                s.title:SetText(title)
                Cut(s.about, about, tw)
                -- (laid by their middles on the strip, as the custom card's picker's)
                strip:Lay(s.title, 0, START.title - START.h / 2, tw, 18)
                strip:Lay(s.about, 0, START.about - START.h / 2, tw, 16)
                Use(strip)
                s.title:Show()
                s.about:Show()
            end)
            Item("pick", { key = "start:" .. key, kind = "start", strip = s.strip, heading = s.title, y = at })
            top = top + START.h + START.gap
        end
        y = top
        if #rules > 0 then
            local at = y + 4
            Put(function()
                view.cancel:PlaceAt(RX, at, "RIGHT")
                Use(view.cancel)
            end)
            Item("pick", { key = "cancel", kind = "link", frame = view.cancel, y = at })
            y = at + 16
        end
    elseif rule then
        local spec = AutoAdd.Trigger(rule.trigger)
        -- (a rule of a trigger no longer registered: shown, not editable)
        local function Row(key, text)
            local label = Label(key, text)
            local at = y
            Put(function() K.PlaceText(label, FX, at) end)
            return label
        end

        -- Trigger.
        local sub = Row("trigger", WORDS.trigger)
        local at = y
        Put(function()
            view.trigger:SetText(spec and spec.label or tostring(rule.trigger))
            view.trigger:PlaceAt(CX, at)
            Use(view.trigger)
        end)
        Item("form", { key = "field:trigger", kind = "choice", frame = view.trigger, words = view.trigger.label,
            subhead = sub, y = at, x = CX })
        y = y + SHEET.row

        if spec then
            -- Amount.
            sub = Row("amount", WORDS.amount)
            local a = Amount(spec)
            -- (a local of its own: the trigger's Put above is run later and
            -- reads its `at` then, so reusing it moved the trigger here)
            local amountAt = y
            Put(function()
                a.box:Refresh()
                K.PlaceButton(Use(a.box), CX, amountAt - 9, SHEET.number, 18)
                K.PlaceText(Use(a.unit), CX + SHEET.number + 8, amountAt)
            end)
            Item("form", { key = "field:amount", kind = "number", frame = a.box, subhead = sub, y = amountAt, x = CX })
            y = y + SHEET.row

            -- The option: ticks or radios, along the line while they fit.
            if spec.option then
                sub = Row("option:" .. spec.key, spec.option.label or WORDS.option)
                local o = Options(spec)
                local x = CX
                for _, value in ipairs(o.order) do
                    local box = o[value]
                    if x > CX and x + box.width > RX then
                        x, y = CX, y + SHEET.wrap
                    end
                    local bx, by = x, y
                    Put(function()
                        box:Refresh()
                        K.PlaceButton(Use(box), bx, by - box.height / 2, box.width, box.height)
                    end)
                    box.group = sub
                    Item("form", { key = "option:" .. tostring(value), kind = "switch", frame = box, subhead = sub,
                        y = by, x = bx, radio = not spec.option.multi })
                    x = x + box.width
                end
                if spec.option.note then
                    y = y + 18
                    local ny = y
                    view.note:SetText(spec.option.note)
                    Put(function() K.PlaceText(Use(view.note), CX, ny) end)
                end
                y = y + SHEET.row
            end

            -- Filters: each added one a line, then the strips for the rest.
            sub = Row("filters", WORDS.filters)
            local f = rule.filters or {}
            for _, key in ipairs(AutoAdd.FILTER_KEYS) do
                local v = f[key]
                if v ~= nil then
                    local off = view.offs[key]
                    local line = y
                    if key == "guild" then
                        Put(function() K.PlaceText(Use(view.guild), CX, line) end)
                        if not MyGuild() then
                            y = y + 16
                            local ny = y
                            Put(function() K.PlaceText(Use(view.noGuild), CX, ny) end)
                        end
                    elseif key == "faction" then
                        local x = CX
                        for _, side in ipairs({ "mine", "other" }) do
                            local box = view.faction[side]
                            local bx = x
                            Put(function()
                                box:Refresh()
                                K.PlaceButton(Use(box), bx, line - box.height / 2, box.width, box.height)
                            end)
                            box.group = sub
                            Item("form", { key = "faction:" .. side, kind = "switch", frame = box, subhead = sub,
                                y = line, x = bx, radio = true })
                            x = x + box.width
                        end
                    elseif key == "level" then
                        local ways = view.levelWay
                        local lb = view.levelBox
                        local second = y + SHEET.wrap + 2
                        Put(function()
                            for _, w in pairs(ways) do w:Refresh() end
                            for _, b in pairs(lb) do b:Refresh() end
                            K.PlaceButton(Use(ways.between), CX, line - ways.between.height / 2, 82, ways.between.height)
                            K.PlaceButton(Use(lb.min), CX + 84, line - 9, 30, 18)
                            K.PlaceText(Use(view.levelAnd), CX + 120, line)
                            local aw = K.Width(view.levelAnd)
                            K.PlaceButton(Use(lb.max), CX + 126 + aw, line - 9, 30, 18)
                            K.PlaceButton(Use(ways.within), CX, second - ways.within.height / 2, 82, ways.within.height)
                            K.PlaceButton(Use(lb.within), CX + 84, second - 9, 30, 18)
                            K.PlaceText(Use(view.levelOf), CX + 120, second)
                        end)
                        ways.between.group, ways.within.group = sub, sub
                        Item("form", { key = "levelway:between", kind = "switch", frame = ways.between, subhead = sub,
                            y = line, x = CX, radio = true })
                        Item("form", { key = "level:min", kind = "number", frame = lb.min, subhead = sub, y = line, x = CX + 84 })
                        Item("form", { key = "level:max", kind = "number", frame = lb.max, subhead = sub, y = line, x = CX + 140 })
                        Item("form", { key = "levelway:within", kind = "switch", frame = ways.within, subhead = sub,
                            y = second, x = CX, radio = true })
                        Item("form", { key = "level:within", kind = "number", frame = lb.within, subhead = sub,
                            y = second, x = CX + 84 })
                        y = second
                    elseif key == "class" then
                        for i, class in ipairs(CLASSES) do
                            local icon = view.icons[class]
                            local ix = CX + (i - 1) * (ICON.size + ICON.gap)
                            local on = type(v) == "table" and v[class] == true
                            Put(function()
                                K.PlaceButton(Use(icon), ix, line - ICON.size / 2, ICON.size, ICON.size)
                                icon:SetAlpha(on and 1 or ICON.faded)
                                icon.art:SetDesaturated(not on)
                            end)
                            Item("form", { key = "class:" .. class, kind = "icon", frame = icon, subhead = sub,
                                y = line, x = ix, on = on, class = class })
                        end
                    end
                    -- (Remove at the line's right end, the filter's first line)
                    Put(function()
                        off:PlaceAt(RX, line, "RIGHT")
                        Use(off)
                    end)
                    off.group = sub
                    Item("form", { key = "off:" .. key, kind = "link", frame = off, subhead = sub, y = line, x = RX })
                    y = y + SHEET.row
                end
            end
            local x = CX
            local strips = false
            for _, key in ipairs(AutoAdd.FILTER_KEYS) do
                if f[key] == nil then
                    local strip = view.mores[key]
                    view.probe:SetFont(Style.NEUTON_ITALIC, 14, "")
                    view.probe:SetText(strip.words:GetText())
                    local w = K.Width(view.probe) + 2 + 2 * MORE.pad
                    view.probe:SetFontObject(FONT.body)
                    if x > CX and x + w > RX then
                        x, y = CX, y + MORE.h + 6
                    end
                    local sx, sy = x, y
                    Put(function()
                        strip:SetNote({ size = { w, MORE.h }, guid = key, turn = MORE.turn, seed = "more:" .. key,
                            onClick = function(k) Rules.AddFilter(k) end })
                        strip:Layout(sx, sy - MORE.h / 2, w)
                        strip:Lay(strip.words, 0, 0, w - 2 * MORE.pad + 4, 20)
                        strip.words:Show()
                        strip.padAt = { sx + w / 2, sy }
                        Use(strip)
                    end)
                    Item("form", { key = "more:" .. key, kind = "strip", strip = strip, subhead = sub, y = sy, x = sx })
                    x = x + w + MORE.gap
                    strips = true
                end
            end
            if strips then y = y + SHEET.row end
        end

        -- Tag: the chips, a radio row, then the line to write one.
        sub = Row("tag", WORDS.tag)
        local x = CX
        for _, tag in ipairs(TagChoices(rule)) do
            local chip = Chip(tag)
            local on = (rule.tag or "") == tag
            chip:SetTag(tag, on, false, tag == "" and WORDS.noTag or TagLabel(tag))
            local w = K.Width(chip.label) + 14
            if x > CX and x + w > RX then
                x, y = CX, y + SHEET.wrap
            end
            local cx, cy = x, y
            Put(function()
                chip:SetTag(tag, on, false, tag == "" and WORDS.noTag or TagLabel(tag))
                K.PlaceButton(Use(chip), cx, cy - 9, w, 18)
            end)
            chip.group = sub
            Item("form", { key = "tag:" .. tag, kind = "chip", frame = chip, subhead = sub, y = cy, x = cx })
            x = x + w + SHEET.chipGap
        end
        y = y + SHEET.wrap + 4
        local ly = y
        Put(function() K.PlaceButton(Use(view.tagLine), CX, ly - 10, SHEET.tagLine, 20) end)
        view.tagLine.group = sub
        Item("form", { key = "tagline", kind = "field", frame = view.tagLine, subhead = sub, y = ly, x = CX })
        y = y + SHEET.row

        -- The foot: why it adds nobody, then Delete.
        local why = Rules.Quiet(rule)
        if why then
            local lines = K.Wrap(Fmt(L["This rule can’t add anyone: %s."], why), SHEET.formW, FONT.small)
            for i, line in ipairs(lines) do
                local fs = view.quiet[i] or Text(FONT.small)
                view.quiet[i] = fs
                fs:SetText(line)
                fs:SetTextColor(Style.RUBRIC[1], Style.RUBRIC[2], Style.RUBRIC[3])
                local qy = y
                Put(function() K.PlaceText(Use(fs), FX, qy) end)
                y = y + 14
            end
            y = y + 8
        end
        local dy = y
        Put(function()
            view.delete:PlaceAt(RX, dy, "RIGHT")
            Use(view.delete)
        end)
        Item("form", { key = "delete", kind = "link", frame = view.delete, y = dy, x = RX })
        y = y + 16
    end
    local formBottom = y

    local H = math.max(SHEET.least, math.min(SHEET.most, math.max(listBottom, formBottom) + SHEET.bottom))
    K.Reshape(W, H)
    K.Fall("autoaddrules")
    view:Show()
    K.Lay()
    Put(function()
        K.Place(Use(view.hairline), SHEET.rule, SHEET.first - 14, 1, H - SHEET.first - SHEET.bottom + 6)
    end)
    for _, fn in ipairs(ops) do fn() end
    for _, w in ipairs(all) do
        if not used[w] then w:Hide() end
    end
    view.items = items
    view.height = H
end

--------------------------------------------------------------------------
-- Opening and putting away
--------------------------------------------------------------------------

function Rules.Shown() return view ~= nil and view:IsShown() end

-- Lays the sheet on the book, open on Settings. The visit starts: the list
-- as it is now is what the backfill question weighs against.
function Rules.Open()
    if not view then Build() end
    HookPage()
    if not Rules.Shown() then
        state.snapshot = AutoAdd.Snapshot()
        wipe(state.deleted)
        wipe(state.kept)
        state.picking = false
    end
    if not OpenRule() then
        local first = AutoAdd.Rules()[1]
        state.open = first and first.id or nil
    end
    PadTo(state.open and "list" or "pick", state.open and ("rule:" .. state.open) or nil)
    Lay()
    ns.UI.Pad.Refresh()
    return true
end

-- Every line lets go of the cursor (and commits what it holds).
function Rules.LetGo(keep)
    if not view then return end
    for _, w in ipairs(boxes) do
        if w ~= keep and w:HasFocus() then w:ClearFocus() end
    end
end

-- The line with the cursor, or nil.
function Rules.Writing()
    if not view then return nil end
    for _, w in ipairs(boxes) do
        if w:HasFocus() then return w end
    end
    return nil
end

function Rules.Close()
    if not Rules.Shown() then return end
    Rules.LetGo()
    view:Hide()
end

-- The visit's end (the view hidden, however): with the master switch on,
-- the people who already pass a rule added, switched on or widened in it
-- are asked about once.
function Rules.Finish()
    local snapshot = state.snapshot
    if not snapshot then return end
    state.snapshot, state.picking = nil, false
    wipe(state.deleted)
    GameTooltip:Hide()
    ns.UI.Pad.Refresh()
    if AutoAdd.On() then
        local ask = AutoAdd.AskAbout(snapshot)
        if #ask > 0 then ns.UI.AutoAdd.Ask(ask) end
    end
end

-- For the pad and the tests: the view, the open rule, the visit.
function Rules.View() return view end
function Rules.Rule() return OpenRule() end
function Rules.State() return state end
-- A row's label ("start", "trigger", ...), for the tests.
function Rules.Label(key) return labels[key] end
