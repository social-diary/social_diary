-- Custom cards' side of the page (.claude/features/custom-cards.md, the data
-- in Core/Custom.lua): a right click on a plate, close-up or full page, and
-- the form a card is changed or written on.
--
-- A right click on a mark or a card of a kind that may be custom opens the
-- form for its record (a spot merging several asks which, by a menu). Anywhere
-- else on the picture a menu offers "Add custom event..." at that spot, and the
-- cards hidden on this page, which have no mark left to click. A mark of any
-- other kind counts as anywhere else: the map under it is still the map.
--
-- Adding goes by the picker, a sheet of one card per kind that may be custom,
-- each its type, its name and its map mark (.claude/features/custom-cards.md,
-- "Adding a card"), and on to the form on the same sheet. "Choose another" goes
-- back and what was typed goes with it. A dashed ring in pencil lies on the plate
-- at the spot while either is open (plate:SetRing).
--
-- Everything is read off the kinds' registered `custom` specs, so this names no
-- feature, and a later kind needs no change here. The time is never asked:
-- Custom.Insert finds it within the page's own (plate.entry: the open piece on
-- a close-up, the level on a full page).
--
-- The form is a slip laid from the book's left edge (Lay), so the plate it is
-- about stays in sight, nearly all of it. It lies straight, as an edit box cannot turn (the note
-- sheet's reason, UI/Paper/NoteSheet.lua), and like that sheet the book under
-- it takes no clicks until it is saved or cancelled, so the page cannot turn
-- from under it. Nothing here is protected, so it all works in combat; and it
-- writes through Journey.Mine, so it works with "Keep my own route" off.
--
-- The module and its siblings: UI/Journey/Look.lua.

local addonName, ns = ...

local L = ns.L

local Style = ns.Style
local FONT = Style.FONT
local YourDiary = ns.UI.YourDiary
local BOOK = ns.UI.Journal.BOOK

-- The slip (x right, y down, from its top left). w: wide enough for a label
-- column, a line for a long creature's name ("Razormane Battleguard") and the
-- margins. margin: its writing's. title: the heading's middle. first: the first
-- row's middle. row: from row to row. label: the labels' column. line, short:
-- the width of a text's line and of a number's (a number's hint goes beside it,
-- `gap` on). toggle: a choice's box and its word, one after another along the
-- line, as many as fit its width (`wrap` on from there, a first found's five
-- firsts running to three lines). links: from the last row to the quiet links' middle, foot: from
-- there, or from the last row where it has none, to Save's. bottom: under Save.
-- Its height comes of its rows: a later kind may have more.
local SHEET = { w = 320, margin = 26, title = 32, first = 66, row = 30, label = 92, line = 176, short = 48, gap = 8, toggle = 86, wrap = 22,
    links = 34, foot = 28, bottom = 26, linkGap = 18 }
-- Not folded: a slip, not a sheet carried in the book. Its corners curl a
-- little and it is hardly crumpled, as the note sheet's (NoteSheet.lua's CREASE,
-- whose every value is said there).
local CREASE = { columns = { 0, 0.07, 0.93, 1 }, rows = { 0, 0.07, 0.93, 1 }, folds = { columns = {}, rows = {} },
    crumple = 0.5, drift = 0.4, edge = 0.6, wander = 0, shift = 3, lean = 2, curl = { lift = 5, pull = 3 } }

-- The picker. edge: how far in from the book's left edge the sheet (form too) is
-- laid, x from the pages, so neither lies on the cover; both are wider than the
-- left page (286), and run over the gutter. margin, title: its writing's, and
-- the heading's middle. top: where the list starts. card: a kind's slip, w being
-- the 176 of the margin's L cards; turn its most, degrees; pad its writing's
-- left, eyebrow and name their middles from its top, mark its mark's middle from
-- its right. row: a row of cards and the air under it. gap: between two cards.
-- most: the rows shown before it scrolls, what the book's 568 px of height holds
-- with the heading and foot. foot: from the list to Cancel's middle; bottom:
-- under it. The list's bar is SCROLLBAR_WIDTH + 2 on its right, always kept.
local PICKER = { edge = 8, margin = 26, title = 30, top = 54, row = 78, gap = 22, most = 5, foot = 8, bottom = 24,
    card = { w = 176, h = 62, turn = 0.8, pad = 10, eyebrow = 17, name = 39, mark = 20 } }
-- The types, in their order. The kinds say which by its key; the words are here
-- alone, so a kind cannot make a fifth. One not among them is Other.
local GROUPS = { { key = "combat", words = L["Combat"] }, { key = "lore", words = L["Quests and Lore"] },
    { key = "social", words = L["Social"] }, { key = "other", words = L["Other"] } }
-- The pencil ring (plate:SetRing): the leaders' pencil in colour, alpha and nib,
-- a little lighter in hand. r: its radius, a few px past a mark's, so a card
-- written beside one does not hide it. dashes, share: how many, and how much of
-- its share of the round each draws. uneven, wander: how far a dash starts off
-- its place (in shares of its arc) and off the radius (px). bends, step: the
-- points of each dash, and the pen's step along them; width in px.
local RING = { r = 10, dashes = 9, share = 0.62, uneven = 0.25, wander = 0.8, bends = 4, step = 1.5, width = 1.4 }

-- A person's line offers who the search finds, hanging from its underline as a part
-- of it, over the rows below, on a patch of paper ruled like the line. most: how
-- many. row: their height. level: over the form's rows. out: how far the paper runs
-- past the line each side, so the names start where what is typed does. foot: under
-- the last name. hot: the ink under the mouse, faint so the name stays readable.
-- (2 Nov, in the client: laid by its middle at its full height, one
-- name floated a row and a half under the line.)
-- inset: the room a row's picture takes before its words (an item's). edge:
-- how near the sheet's foot and head the paper may come; it opens upward
-- where there is more room over the line than under it, and shows only the
-- rows that room holds, so it never runs off the sheet. Its words are cut
-- with an ellipsis at the paper's width, never past it.
-- (19 Nov, in the client: long item names ran past the paper and the sheet,
-- and the paper lay over the caption's box and the foot's links.)
local PERSON = { most = 4, row = 18, level = 40, out = 4, foot = 2, hot = 0.12, paper = { 0.93, 0.88, 0.74 },
    inset = 18, edge = 8 }

-- The words of the form and the menus, all furniture (the copywriter's §1). Add,
-- pick and another are the user's own, word for word.
local WORDS = {
    add = L["Add custom event..."], pick = L["What happened here?"], another = L["Choose another"], which = L["Which one?"],
    save = L["Save"], cancel = L["Cancel"],
    hide = L["Leave it out"], reset = L["Undo my changes"], remove = L["Delete this card"],
    confirm = L["Delete this card you wrote?\n\nIt comes off the map and the page. This cannot be undone."],
    -- The page's own choice (.claude/features/choose-page.md, Phase 4): only
    -- ever leaving out, as "Leave it out" does; back is the ticklist's alone.
    leavePlace = L["Leave this place out"], choose = L["Choose what's on this page..."],
    leavePerson = L["Leave %1$s off this page"],
}

local CardSheet = {}
YourDiary.CardSheet = CardSheet

local view, K

-- The pad's Y while it is asking (CardSheet.PadRight): { plate, frame, dry,
-- did }. Nil the rest of the time, so the mouse's right click is as it was.
local padCall

-- Who has the pad may have changed: the slip shown, its form or picker laid,
-- or put away (UI/Journey/CardPad.lua; with the pad down this does nothing).
local function PadRefresh() ns.UI.Pad.Refresh() end

local function Capital(text)
    return (text:gsub("^%l", string.upper))
end

local function Described(spec, rec)
    return spec.describe and spec.describe(ns.Custom.Values(rec)) or Capital(spec.label)
end

--------------------------------------------------------------------------
-- After a change: the page drawn again, staying where it is
--------------------------------------------------------------------------

-- The recap is cached by the route's version, which Custom's writers have just
-- moved, so a refresh makes a new one and draws it. It would fall back to the
-- newest sitting and a fitted map; these two say otherwise (RefreshJourneyPage,
-- DrawFull). `t` is the time to stay at: an inserted card's, so a full page's way
-- back is to the sitting that holds it; else the sitting open.
local function Redraw(t)
    local page = YourDiary.page
    if not page then return end
    local e = page.recap and page.recap.entries[page.open]
    local piece = e and YourDiary.OpenPieceOf(e)
    page.holdAt = t or (piece and piece.from)
    local look = page.mode == "full" and page.plates[1] and page.plates[1].look
    if look then
        local g = look.goal
        page.fullView = { f = g.f, cx = g.cx, cy = g.cy, redraws = look.redraws }
    end
    GameTooltip:Hide()
    ns.UI.RefreshJourneyPage(false)
end

--------------------------------------------------------------------------
-- The form
--------------------------------------------------------------------------

local Lines

local function LetGo()
    for _, row in ipairs(view.rows or {}) do
        for _, line in ipairs(Lines(row)) do line.box:ClearFocus() end
    end
end

-- The ring off whichever plate has it. Called as the view hides, however it
-- came to (Build), so nothing can leave one behind.
local function RingOff()
    if view.ringOn then
        view.ringOn:SetRing(nil)
        view.ringOn = nil
    end
end

local function Close(quiet)
    LetGo()
    view:Hide(quiet)
end

-- A field's row. Numbers are a writing line and not Style.NumberField, which
-- will not take the minus of a skull's -1, nor stay empty for "no value".
--
-- Every row answers Set and Get; a row of the free card's field types
-- (note-card.md, phase 3: icon, people, item, flag, a text of several lines)
-- also Load(values), what it has from the card, Key(), what it holds as a
-- string to tell a change by, and Extra(fields), what it writes under keys
-- of its own (an item's ID). Lines(row) is every line written on in it, a
-- person's names hung under one (`found`, `rows`) where it has them.
--
-- An optional field (`optional`, the mob and the item) is not on the form
-- until it is added: a paper strip, "+ A creature", stands for it (row.add,
-- among the others' on one row, where the first of them would be), and
-- added, the field has a link after its line to take it off again, which
-- clears it. A card that has one opens with it on.

-- What a person's line, a list of people and an item's line offer as they
-- are written on: the rows the search finds hang from the underline, over
-- the rows below. `find(text)` the entries, `fill(line, entry)` one written
-- on its line, `pick(entry)` one chosen. `holder` has its box; it gets found
-- (the paper they lie on) and rows (theirs), and Offer().
local function Offering(holder, find, fill, pick)
    local S = view.sheet
    local found = CreateFrame("Frame", nil, S)
    found:SetFrameLevel(S:GetFrameLevel() + PERSON.level)
    local paper = found:CreateTexture(nil, "BACKGROUND")
    paper:SetAllPoints()
    paper:SetColorTexture(PERSON.paper[1], PERSON.paper[2], PERSON.paper[3], 1)
    -- Ruled down its sides and foot, in the line's own ink, so it reads as the
    -- line opened out and not as a slip lying near it.
    for _, edge in ipairs({ { "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 },
        { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 } }) do
        local rule = found:CreateTexture(nil, "BORDER")
        rule:SetPoint(edge[1])
        rule:SetPoint(edge[2])
        if edge[3] then rule:SetWidth(edge[3]) else rule:SetHeight(edge[4]) end
        rule:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], Style.HAIRLINE_HOT)
    end
    found:Hide()
    holder.found, holder.rows = found, {}
    -- Where the paper goes, for `n` rows: under the line, or over it where
    -- there is more room there; as wide as the line's column, never past the
    -- sheet's margin. How many rows the room holds.
    local function Hang(n)
        local at, H = holder.box.padAt, view.H
        local w = SHEET.line
        found:ClearAllPoints()
        if not (at and H) then
            found:SetPoint("TOPLEFT", holder.box, "BOTTOMLEFT", -PERSON.out, -1)
            found:SetWidth(w + 2 * PERSON.out)
            return n, w
        end
        local left = at[1] - (holder.box:GetWidth() or 0) / 2
        w = math.min(SHEET.line, SHEET.w - SHEET.margin - left)
        local below = math.floor((H - PERSON.edge - (at[2] + 11) - PERSON.foot) / PERSON.row)
        local above = math.floor((at[2] - 11 - PERSON.edge - PERSON.foot) / PERSON.row)
        local up = below < n and above > below
        if up then
            found:SetPoint("BOTTOMLEFT", holder.box, "TOPLEFT", -PERSON.out, 1)
        else
            found:SetPoint("TOPLEFT", holder.box, "BOTTOMLEFT", -PERSON.out, -1)
        end
        found:SetWidth(w + 2 * PERSON.out)
        holder.up = up
        return math.max(0, math.min(n, up and above or below)), w
    end
    function holder.Offer()
        local list = holder.box:HasFocus() and find(holder.box:GetText()) or {}
        local n, w = Hang(#list)
        for i = n + 1, #list do list[i] = nil end
        for i, entry in ipairs(list) do
            local line = holder.rows[i]
            if not line then
                line = CreateFrame("Button", nil, found)
                line:SetHeight(PERSON.row)
                line:SetPoint("TOPLEFT", PERSON.out, -(i - 1) * PERSON.row)
                line:SetPoint("TOPRIGHT", -PERSON.out, -(i - 1) * PERSON.row)
                line.text = Style.Text(line, FONT.note)
                line.text:SetPoint("LEFT")
                line.text:SetWordWrap(false)
                line.text:SetMaxLines(1)
                local hot = line:CreateTexture(nil, "HIGHLIGHT")
                hot:SetAllPoints()
                hot:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], PERSON.hot)
                line:SetScript("OnClick", function(self)
                    pick(self.entry)
                    found:Hide()
                end)
                holder.rows[i] = line
            end
            line.entry = entry
            fill(line, entry)
            -- (cut with an ellipsis at the paper's width: the client's, for a
            -- line of fixed width that may not wrap)
            line.text:SetWidth(w - (line.picture and line.picture:IsShown() and PERSON.inset or 0) - 2)
            line:Show()
        end
        for i = #list + 1, #holder.rows do holder.rows[i]:Hide() end
        found:SetHeight(#list * PERSON.row + PERSON.foot)
        found:SetShown(#list > 0)
    end
end

-- A person's line: who the search finds (Custom.FindPeople). Typing is not
-- picking: whatever was linked lets go at the first key.
local function PersonLine(holder, width, field)
    holder.box = Style.WritingLine(view.sheet, width, FONT.note, field.hint)
    holder.box:SetMaxLetters(field.most or 60)
    Offering(holder, function(text) return ns.Custom.FindPeople(text, PERSON.most) end,
        function(line, person)
            line.person = person
            line.text:SetText(person.name)
        end,
        function(person) holder:Set(person.name, person.guid) end)
    holder.box:HookScript("OnTextChanged", function(_, typed)
        if typed then
            holder.guid = nil
            holder.Offer()
        end
    end)
    function holder:Set(value, guid)
        self.guid = guid
        self.box:SetValue(value)
        self.box:SetCursorPosition(0)
        self.found:Hide()
    end
    function holder:Get() return self.box:GetText() or "" end
    return holder
end

-- Every line written on in `row` (its own, if it has one).
function Lines(row)
    return row.box and { row } or {}
end
CardSheet.Lines = Lines

-- Tab walks the lines shown, as on the entry form; Enter on a line of one
-- line saves the card, on any line of any kind's form (a text of several
-- takes it as a new line).
local function Save() view.save:GetScript("OnClick")(view.save) end
local function Writable(box, multi)
    box:SetScript("OnTabPressed", function(self)
        local all = {}
        for _, row in ipairs(view.rows or {}) do
            for _, line in ipairs(Lines(row)) do
                if line.found then line.found:Hide() end
                if line.box:IsShown() then all[#all + 1] = line.box end
            end
        end
        for i, other in ipairs(all) do
            if other == self then return all[i % #all + 1]:SetFocus() end
        end
    end)
    if not multi then box:SetScript("OnEnterPressed", function() Save() end) end
end

-- The free card's controls, each on the line's column (SHEET.label in):
--   ICONS   the icon grid: `across` a row, each in a `cell` px square drawn
--           `size` px (ns.NoteIcons, at a card's hand, no mark's blot); the
--           chosen one on a wash of ink at `chosen`, as a word circled
--   WRITE   a text of several lines: ruled every `pitch` px, as many rows as
--           the field keeps lines and `more` (it wraps: three lines of the
--           player's run longer than three rows), scrolled past that
--   MORE    the "+ Add" strips: `h` px tall, their words `pad` px in from
--           each end, `gap` between two, turned at most `turn` degrees
--   OFF     the link that takes an added field off: `gap` px after its line
--   FACES   who was there: round portraits `size` px, `pitch` apart, their
--           names small under them (`name` px tall, cut with an ellipsis at
--           the pitch); the cross on the rim `cross` px, `out` in from the
--           frame's corner; a name only typed its `initial` in Morpheus
--           capitals on a `blank` of paper. `line`: from the faces' top to
--           the search line's middle under them
local ICONS = { across = 8, cell = 22, size = 18, chosen = 0.13 }
local WRITE = { pitch = 20, more = 1 }
local MORE = { h = 22, pad = 9, gap = 10, turn = 1.2 }
local OFF = { gap = 8 }
local FACES = { size = 30, pitch = 44, name = 12, cross = 13, out = 3, initial = 16,
    blank = { 0.86, 0.80, 0.66 }, line = 58 }
CardSheet.ICONS, CardSheet.WRITE, CardSheet.MORE, CardSheet.FACES = ICONS, WRITE, MORE, FACES

local AddField, TakeOff, AddPerson, TakePerson

local function NewRow(field)
    local S = view.sheet
    local row = { field = field, label = Style.Text(S, FONT.heading) }
    row.label:SetText(ns.UI.JourneyText.Upper(field.label))
    if field.type == "choice" then
        -- A box per value, always in sight, and at most one ticked: ticking one
        -- unticks the rest, unticking leaves no value. `value` may be one no box
        -- offers (a detected record's, which the form cannot choose): no box is
        -- ticked for it, and it stays what Get says, so a save that never touched
        -- these writes nothing over it (Fields).
        row.toggles = {}
        local function Tick()
            for value, box in pairs(row.toggles) do box:SetChecked(row.value == value) end
        end
        for i, value in ipairs(field.values) do
            -- A lone box says more than a word, and has the line to say it on.
            local box = Style.Checkbox(S, #field.values == 1 and SHEET.line or SHEET.toggle, field.names[value], function() return row.value == value end,
                function(on)
                    row.value = on and value or nil
                    Tick()
                end)
            box.at = i - 1
            -- (its row's label is its subheading where the pad stands on it,
            -- as a settings group's heading is: UI/Pad/Look.lua's `group`)
            box.group = row.label
            row.toggles[value] = box
        end
        function row:Set(value)
            self.value = value ~= "" and value or nil
            Tick()
        end
        function row:Get() return self.value or "" end
    elseif field.type == "person" then
        PersonLine(row, SHEET.line, field)
        row.box.group = row.label
        Writable(row.box)
    elseif field.type == "people" then
        -- Who was there, as round faces in a row (the note sheet's, UI/Paper/
        -- NoteSheet.lua: the portrait, a paper cross on its rim to take them
        -- off), each with their name small under it; under the faces one
        -- line to search on and add the next, gone once `count` are there.
        -- A name picked from the search is the diary's face; one only typed
        -- (Enter, or left on the line when the card is saved) is its
        -- initial on a blank of paper.
        row.people, row.most, row.faces = {}, field.count or ns.Custom.PEOPLE_MOST, {}
        local function Same(a, b)
            if a.guid or b.guid then return a.guid == b.guid end
            return a.name:lower() == b.name:lower()
        end
        -- Someone on the card, once, while there is room; the line cleared.
        function row:Add(name, guid)
            name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
            if name == "" then return false end
            local p = { name = name, guid = guid }
            for _, other in ipairs(self.people) do
                if Same(other, p) then return false end
            end
            if #self.people >= self.most then return false end
            self.people[#self.people + 1] = p
            self.box:SetValue("")
            self.found:Hide()
            return true
        end
        function row:Drop(i)
            table.remove(self.people, i)
        end
        row.box = Style.WritingLine(S, SHEET.line, FONT.note, field.hint)
        row.box:SetMaxLetters(field.most or 60)
        row.box.group = row.label
        Writable(row.box)
        Offering(row, function(text) return ns.Custom.FindPeople(text, PERSON.most) end,
            function(line, person)
                line.person = person
                line.text:SetText(person.name)
            end,
            function(person)
                if row:Add(person.name, person.guid) then AddPerson(row) end
            end)
        row.box:HookScript("OnTextChanged", function(_, typed)
            if typed then row.Offer() end
        end)
        -- Enter adds what is typed as a name of its own; on an empty line,
        -- it saves the card as on every other line.
        row.box:SetScript("OnEnterPressed", function(self)
            if (self:GetText() or ""):find("%S") then
                if row:Add(self:GetText()) then AddPerson(row) end
            else
                Save()
            end
        end)
        function row:Face(i)
            local o = self.faces[i]
            if o then return o end
            o = Style.Portrait(S, FACES.size)
            o.group = row.label
            o.initial = Style.Text(o, FONT.title)
            o.initial:SetFont(Style.MORPHEUS, FACES.initial, "")
            o.initial:SetPoint("CENTER", 0, -1)
            o.initial:SetJustifyH("CENTER")
            o.initial:SetTextColor(Style.INK_STRONG[1], Style.INK_STRONG[2], Style.INK_STRONG[3])
            o.name = Style.Text(S, FONT.small)
            o.name:SetJustifyH("CENTER")
            o.name:SetWordWrap(false)
            o.name:SetMaxLines(1)
            Style.Tooltip(o, function(self)
                local p = self.person
                return p and (p.guid and ns.Characters.FullName(p.guid) or p.name) or nil
            end)
            -- Its cross on the rim, in paper and ink, as the note sheet's.
            local cross = CreateFrame("Button", nil, o)
            cross:SetSize(FACES.cross, FACES.cross)
            cross:SetPoint("CENTER", o, "TOPRIGHT", -FACES.out, -FACES.out)
            cross:SetFrameLevel(o:GetFrameLevel() + 2)
            local INK, P = Style.INK, Style.PAPER
            local disc = cross:CreateTexture(nil, "BACKGROUND", nil, 0)
            disc:SetAllPoints()
            Style.Disc(disc, INK[1], INK[2], INK[3], 0.85)
            local face = cross:CreateTexture(nil, "BACKGROUND", nil, 1)
            face:SetPoint("TOPLEFT", 1, -1)
            face:SetPoint("BOTTOMRIGHT", -1, 1)
            Style.Disc(face, P[1], P[2], P[3], 1)
            local mark = Style.Text(cross, FONT.tag)
            mark:SetPoint("CENTER", 0, 1)
            mark:SetText("\195\151")  -- the multiplication sign, U+00D7
            mark:SetTextColor(Style.INK_STRONG[1], Style.INK_STRONG[2], Style.INK_STRONG[3])
            cross:SetScript("OnClick", function() TakePerson(row, o.at) end)
            Style.Tooltip(cross, function()
                local p = o.person
                return p and ns.Fmt(L["Click to take %s off the card."], p.guid and ns.UI.JourneyText.Short(p.guid) or p.name) or nil
            end)
            o.cross = cross
            self.faces[i] = o
            return o
        end
        -- Each face as who it shows: the diary's portrait, else the initial.
        function row:Faces()
            for i, o in ipairs(self.faces) do
                if not self.people[i] then
                    o:Hide()
                    o.name:Hide()
                end
            end
            for i, p in ipairs(self.people) do
                local o = self:Face(i)
                o.person, o.at = p, i
                local record = p.guid and ns.Characters.Get(p.guid) or nil
                if record then
                    o:SetCharacter(record)
                    o.initial:Hide()
                else
                    local B = FACES.blank
                    o.icon:SetColorTexture(B[1], B[2], B[3], 1)
                    o.icon:SetTexCoord(0, 1, 0, 1)
                    o.initial:SetText(ns.UI.JourneyText.Upper((p.name:match("^[%z\1-\127\194-\244][\128-\191]*") or "?")))
                    o.initial:Show()
                end
                o.name:SetText(p.guid and ns.UI.JourneyText.Short(p.guid) or p.name)
            end
        end
        function row:Set(list)
            self.people = {}
            for _, p in ipairs(type(list) == "table" and list or {}) do
                if type(p) == "table" then self:Add(p.name, p.guid) end
            end
            self.box:SetValue("")
            self.found:Hide()
            self:Faces()
        end
        -- The people on the card, and a name left on the line with room for it.
        function row:Get()
            local out = {}
            for i, p in ipairs(self.people) do out[i] = { name = p.name, guid = p.guid } end
            local typed = (self.box:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if typed ~= "" and #out < self.most then
                local dup = false
                for _, p in ipairs(out) do
                    if not p.guid and p.name:lower() == typed:lower() then dup = true end
                end
                if not dup then out[#out + 1] = { name = typed } end
            end
            return out
        end
        function row:Key()
            local parts = {}
            for _, p in ipairs(self:Get()) do parts[#parts + 1] = p.name .. "\1" .. tostring(p.guid) end
            return table.concat(parts, "\2")
        end
        function row:Load(values) self:Set(values[field.key]) end
    elseif field.type == "icon" then
        -- The sixteen, always in sight (one click, nothing to open), a row of
        -- eight twice; the chosen one washed. Their names are their tooltips.
        local icons = ns.NoteIcons
        row.cells = {}
        for i, key in ipairs(icons and icons.KEYS or {}) do
            local cell = CreateFrame("Button", nil, S)
            cell.iconKey, cell.at = key, i
            cell.chosen = cell:CreateTexture(nil, "BACKGROUND")
            cell.chosen:SetPoint("CENTER")
            cell.chosen:SetSize(ICONS.cell, ICONS.cell)
            Style.Disc(cell.chosen, Style.INK[1], Style.INK[2], Style.INK[3], ICONS.chosen)
            cell.picture = icons.New(cell, ICONS.size)
            cell.picture:SetPoint("CENTER")
            cell.picture:SetIcon(key)
            cell.group = row.label
            Style.Tooltip(cell, function() return { { icons.NAMES[key] or key } } end)
            cell:SetScript("OnClick", function() row:Set(key) end)
            row.cells[i] = cell
        end
        function row:Set(value)
            self.value = icons and icons.Known(value) or value
            for _, cell in ipairs(self.cells) do cell.chosen:SetShown(cell.iconKey == self.value) end
        end
        function row:Get() return self.value end
        function row:Key() return tostring(self.value) end
        function row:Load(values) self:Set(values[field.key]) end
    elseif field.type == "flag" then
        -- Its label is its words, beside the box: no label in the column.
        row.flag = Style.Checkbox(S, SHEET.w - 2 * SHEET.margin, field.label, function() return row.value end,
            function(on) row.value = on end)
        function row:Set(value)
            self.value = value == true
            self.flag:SetChecked(self.value)
        end
        function row:Get() return self.value == true end
        function row:Key() return tostring(self.value == true) end
        function row:Load(values) self:Set(values[field.key]) end
    elseif field.type == "item" then
        -- A line to write its name on, the player's own items offered as it
        -- is written (Custom.FindItems: picture and name in its quality's
        -- ink), or a shift-click of an item (CardSheet.InsertLink). Picked,
        -- it wears its picture at the line's start and its name its ink.
        row.box = Style.WritingLine(S, SHEET.line, FONT.note, field.hint)
        row.box:SetMaxLetters(field.most or 60)
        row.box.group = row.label
        Writable(row.box)
        row.picture = row.box:CreateTexture(nil, "ARTWORK")
        row.picture:SetSize(14, 14)
        row.picture:SetPoint("LEFT", 0, 0)
        row.picture:Hide()
        local function Look()
            local on = row.id ~= nil and row.iconFile ~= nil
            row.picture:SetShown(on)
            if on then row.picture:SetTexture(row.iconFile) end
            row.box:SetTextInsets(on and PERSON.inset or 0, 0, 0, 0)
            local ink = row.id and ns.UI.ItemBox.Ink(row.quality) or Style.INK_STRONG
            row.box:SetTextColor(ink[1], ink[2], ink[3])
        end
        Offering(row, function(text) return ns.Custom.FindItems(text, PERSON.most) end,
            function(line, it)
                line.item = it
                if not line.picture then
                    line.picture = line:CreateTexture(nil, "ARTWORK")
                    line.picture:SetSize(14, 14)
                    line.picture:SetPoint("LEFT")
                    line.text:ClearAllPoints()
                    line.text:SetPoint("LEFT", PERSON.inset, 0)
                    line:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        local ok = type(GameTooltip.SetHyperlink) == "function"
                            and pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. self.item.itemID)
                        if not ok then GameTooltip:SetText(self.item.name) end
                        GameTooltip:Show()
                    end)
                    line:SetScript("OnLeave", function() GameTooltip:Hide() end)
                end
                line.picture:SetTexture(it.icon)
                line.picture:SetShown(it.icon ~= nil)
                line.text:SetText(it.name)
                local ink = ns.UI.ItemBox.Ink(it.quality)
                line.text:SetTextColor(ink[1], ink[2], ink[3])
            end,
            function(it) row:Set(it.name, it.itemID, it.quality, it.icon) end)
        row.box:HookScript("OnEditFocusLost", function(self) self:SetCursorPosition(0) end)
        row.box:HookScript("OnTextChanged", function(_, typed)
            if typed then
                row.id, row.quality, row.iconFile = nil, nil, nil
                Look()
                row.Offer()
            end
        end)
        function row:Set(name, id, quality, icon)
            self.id = id
            local link = id and ("item:" .. id) or nil
            self.quality = id and (quality or ns.UI.ItemBox.Quality(link)) or nil
            self.iconFile = id and (icon or ns.UI.ItemBox.Icon(link)) or nil
            self.box:SetValue(name or "")
            -- (from its first letter, its picture's inset kept: an edit box
            -- given its text keeps the scroll it had, 19 Nov in the client:
            -- "ather Boots")
            self.box:SetCursorPosition(0)
            self.found:Hide()
            Look()
        end
        function row:Get() return self.box:GetText() or "" end
        function row:Key() return self:Get() .. "\1" .. tostring(self.id) end
        function row:Extra(fields) fields[ns.Custom.ItemKey(field)] = self.id or false end
        function row:Load(values) self:Set(values[field.key], values[ns.Custom.ItemKey(field)]) end
    elseif field.type == "text" and (field.lines or 1) > 1 then
        -- A text of several lines: ruled as the entry form's note is
        -- (UI/Windows/Entry.lua's BuildNote), on a frame that scrolls it.
        local rows = (field.lines or 1) + WRITE.more
        local scroll = CreateFrame("ScrollFrame", nil, S)
        scroll:EnableMouse(true)
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetMaxLetters(field.most or 60)
        box:SetFontObject(FONT.note)
        box:SetSpacing(WRITE.pitch - 14)
        box:SetWidth(SHEET.line)
        box:SetHeight(WRITE.pitch)
        scroll:SetScrollChild(box)
        -- (its rules on the box, so they move with what is written)
        for i = 1, rows + 4 do
            local rule = box:CreateTexture(nil, "BACKGROUND")
            rule:SetHeight(1)
            rule:SetPoint("TOPLEFT", 0, -(i * WRITE.pitch - 1))
            rule:SetPoint("TOPRIGHT", 0, -(i * WRITE.pitch - 1))
            rule:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], Style.HAIRLINE)
            if i == 1 then box.line = rule end
        end
        Style.Placeholder(box, field.hint, true):SetPoint("TOPLEFT", 0, -3)
        scroll:SetScript("OnMouseDown", function() box:SetFocus() end)
        box:SetScript("OnCursorChanged", function(_, _, y, _, height)
            local offset, shown = scroll:GetVerticalScroll(), rows * WRITE.pitch
            y = -y
            if y < offset then
                scroll:SetVerticalScroll(y)
            elseif y + height > offset + shown then
                scroll:SetVerticalScroll(y + height - shown)
            end
        end)
        box:SetScript("OnTextChanged", function(self)
            self:UpdateHint()
            scroll:UpdateScrollChildRect()
        end)
        box:SetScript("OnEditFocusGained", function(self) self:UpdateHint() end)
        box:SetScript("OnEditFocusLost", function(self) self:UpdateHint() end)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        function box:SetValue(text)
            self:SetText(text or "")
            self:UpdateHint()
        end
        box.group = row.label
        Writable(box, true)
        row.box, row.scroll, row.shown = box, scroll, rows
        function row:Set(value) self.box:SetValue(value) end
        function row:Get() return self.box:GetText() or "" end
    else
        local number = field.type == "number"
        row.box = Style.WritingLine(S, number and SHEET.short or SHEET.line, number and FONT.strong or FONT.note,
            not number and field.hint or nil)
        row.box:SetMaxLetters(number and 4 or (field.most or 60))
        row.box.group = row.label
        Writable(row.box)
        if number and field.hint then
            row.hint = Style.Text(S, FONT.small)
            row.hint:SetText(field.hint)
        end
        function row:Set(value) self.box:SetValue(value) end
        function row:Get() return self.box:GetText() or "" end
    end
    if field.optional then
        -- Its "+ Add" strip, a blank paper slip written on (the picker's
        -- cards are), whose tape lifts under the mouse; a click is `guid`'s.
        local strip = ns.UI.PaperStrip(S)
        strip.addKey = field.key
        strip.words = Style.Text(strip, FONT.noteWritten)
        strip.words:SetFont(Style.NEUTON_ITALIC, 14, "")
        strip.words:SetJustifyH("CENTER")
        strip.words:SetText(field.add or ns.Fmt(L["+ Add %s"], field.label))
        row.add = strip
        row.off = K.Link(FONT.small, function() TakeOff(row) end)
        row.off:SetText(L["Remove"])
        row.off.group = row.label
    end
    return row
end

local function RowsOf(kind, spec)
    view.rowsOf[kind] = view.rowsOf[kind] or {}
    local rows = view.rowsOf[kind]
    if not rows[1] then
        for i, field in ipairs(spec.fields) do rows[i] = NewRow(field) end
    end
    return rows
end

-- Everything of a row on the form or off it. What Lay decides as it lays
-- (an optional field's strip or its line, a people's lines past the first,
-- a people's faces) it shows again there.
local function ShowRow(row, on)
    row.label:SetShown(on and not row.flag)
    for _, part in pairs({ row.box, row.hint, row.scroll, row.flag, row.off, row.add }) do
        part:SetShown(on)
    end
    -- (the faces Lay shows, as many as there are people)
    for _, o in ipairs(row.faces or {}) do
        o:Hide()
        o.name:Hide()
    end
    if row.found and not on then row.found:Hide() end
    for _, box in pairs(row.toggles or {}) do box:SetShown(on) end
    for _, cell in ipairs(row.cells or {}) do cell:SetShown(on) end
end

-- Whether a row holds anything: an optional field opens on where it does.
local function Filled(row)
    local value = row:Get()
    if row.field.type == "item" and row.id then return true end
    return value ~= nil and value ~= "" and value ~= false
end

-- What is to be written: all of an inserted card, of one that exists what
-- changed since the form opened. An edit sent the name unchanged would look the
-- creature up again and might change its picture for nothing. A row of the
-- free card's types tells a change by its Key; an optional field taken off
-- (or never added) holds nothing, so it is written cleared.
local function Fields()
    local fields, any = {}, false
    for _, row in ipairs(view.rows) do
        local value = row:Get()
        local now = row.Key and row:Key() or value
        local guidKey = row.field.type == "person" and ns.Custom.GuidKey(row.field)
        if view.where or now ~= row.was or (guidKey and row.guid ~= row.guidWas) then
            fields[row.field.key] = value
            if guidKey then fields[guidKey] = row.guid end
            if row.Extra then row:Extra(fields) end
            any = true
        end
    end
    return fields, any
end

-- The kinds that may be added, by their types' order, then their `at` within a
-- type, then by name, so the order does not hang on `pairs`. A kind whose
-- `offer` says no (a class's moment on another class) is left out.
local function Kinds()
    local order, list = {}, {}
    for i, group in ipairs(GROUPS) do order[group.key] = i end
    for kind, moment in pairs(ns.JourneyRecap.MOMENTS) do
        local spec = moment.custom
        if spec and spec.label and ns.Custom.Offered(kind) then
            local at = order[spec.group] or order.other
            list[#list + 1] = { kind = kind, spec = spec, type = at, words = GROUPS[at].words, at = spec.at or 0 }
        end
    end
    table.sort(list, function(a, b)
        if a.type ~= b.type then return a.type < b.type end
        if a.at ~= b.at then return a.at < b.at end
        return a.kind < b.kind
    end)
    return list
end
CardSheet.Kinds = Kinds

local Open

-- A card of the picker, on a blank paper strip written on by its caller
-- (`size`, as the run page's are), through the strip's own plane so the words
-- and the mark turn with it. `guid` is what makes a strip open something: under
-- the mouse its tape lifts and a click calls onClick(guid). Here it is the kind.
local function NewCell(row)
    local strip = ns.UI.PaperStrip(row)
    local cell = { strip = strip, eyebrow = Style.Text(strip, FONT.heading), title = Style.Text(strip, FONT.noteWritten) }
    cell.eyebrow:SetJustifyH("LEFT")
    cell.title:SetJustifyH("LEFT")
    cell.kit = ns.UI.JourneyPlate.MarkKit(strip, function(region, x, y, w, h, turn) strip:Lay(region, x, y, w, h, turn) end,
        function(region, ...) return strip:Bend(region, ...) end, strip:Paper())
    return cell
end

local function FillCell(cell, x, k)
    local C = PICKER.card
    local strip = cell.strip
    strip:SetNote({ size = { C.w, C.h }, guid = k.kind, turn = C.turn, seed = "picker:" .. k.kind,
        onClick = function(kind) Open(kind, nil, view.where) end })
    strip:Layout(x, 0, C.w)
    cell.kind = k.kind
    cell.eyebrow:SetText(ns.UI.JourneyText.Upper(k.words))
    cell.title:SetText(k.spec.label)
    local w = C.w - 2 * C.pad - 2 * C.mark
    local left = -C.w / 2 + C.pad + w / 2
    -- A turned string is clipped to its box: room for the rise of its turn (the
    -- run page's StripText has the same).
    local rise = w * math.abs(math.sin(strip.turn or 0)) + 4
    strip:Lay(cell.eyebrow, left, C.eyebrow - C.h / 2, w, 14 + rise)
    strip:Lay(cell.title, left, C.name - C.h / 2, w, 20 + rise)
    cell.eyebrow:Show()
    cell.title:Show()
    cell.kit.P = strip:Paper()
    cell.kit:Begin()
    local mark = ns.UI.JourneyPlate.MARKS[k.kind]
    if mark then mark.draw(cell.kit, C.w / 2 - C.mark, 0) end
    cell.kit:Finish()
end

local function BuildList()
    local C, W = PICKER.card, 2 * PICKER.card.w + PICKER.gap + ns.UI.SCROLLBAR_WIDTH + 2
    -- A row on the list, not the sheet (1 Nov, in the client: on the sheet its
    -- bare "TOPLEFT" anchors, the list's, landed on the sheet's corner over the
    -- title, and hiding the list left the cards lying over the form).
    return ns.UI.Journal.List(view.sheet, PICKER.row, PICKER.most, function(list)
        local row = CreateFrame("Frame", nil, list)
        row.cells = { NewCell(row), NewCell(row) }
        return row
    end, function(row, item)
        for i, cell in ipairs(row.cells) do
            local k = item[i]
            if k then
                FillCell(cell, (i - 1) * (C.w + PICKER.gap), k)
            else
                cell.kind = nil
                cell.strip:Hide()
            end
        end
    end, W)
end

local function Build()
    local book = ns.UI.JournalFrame()
    view, K = ns.UI.LooseSheet(book, SHEET.w, 300, { crease = CREASE, straight = true })
    view.rowsOf = {}
    CardSheet.Hook()
    view.title = Style.Text(view.sheet, FONT.page)
    view.heading = Style.Text(view.sheet, FONT.noteWritten)
    view.heading:SetText(WORDS.pick)
    view.list = BuildList()
    view.another = K.Link(FONT.body, function()
        LetGo()
        CardSheet.Pick()
    end)
    view.another:SetText(WORDS.another)

    view.save = K.Link(FONT.strong, function()
        local t
        if view.where then
            local rec = ns.Custom.Insert(view.kind, (Fields()), view.where)
            t = rec and rec.t
        else
            local fields, any = Fields()
            if any then ns.Custom.Edit(view.kind, view.rec, fields) end
        end
        Style.PlaySound("write")
        Close(true)
        Redraw(t)
    end)
    view.save:SetText(WORDS.save)
    view.cancel = K.Link(FONT.body, function() Close() end)
    view.cancel:SetText(WORDS.cancel)

    view.hide = K.Link(FONT.body, function()
        ns.Custom.Hide(view.rec)
        Close()
        Redraw()
    end)
    view.hide:SetText(WORDS.hide)
    view.reset = K.Link(FONT.body, function()
        ns.Custom.Reset(view.rec)
        Close()
        Redraw()
    end)
    view.reset:SetText(WORDS.reset)
    -- It destroys what they wrote: asked first, and the slip stays till answered.
    view.remove = K.Link(FONT.body, function()
        local rec = view.rec
        ns.UI.Dialog.Confirm(WORDS.confirm, function()
            ns.Custom.Remove(rec)
            Close()
            Redraw()
        end)
    end)
    view.remove:SetText(WORDS.remove)
    view.remove:SetColor(Style.ACCENT[1], Style.ACCENT[2], Style.ACCENT[3])

    -- Turning to another page, or shutting the book, puts it away unwritten.
    YourDiary.page.right:HookScript("OnHide", function()
        if view:IsShown() then view:Hide(true) end
    end)
    view:HookScript("OnHide", RingOff)
    view:HookScript("OnHide", PadRefresh)
    view:Hide()
end

-- The sheet's size, and laid: its left edge PICKER.edge in from the pages',
-- upright in the middle of their height. `dx` is from the view's middle, which
-- is the book frame's and so the pages' (Style.Book, inset by COVER each side).
local function Place(W, H)
    K.Reshape(W, H)
    K.Fall("custom-card", nil, { PICKER.edge + W / 2 - BOOK.BOOK_W / 2, 0 })
    view:Show()
    K.Lay()
end

-- The form's pieces and the picker's, one set shown.
local function ShowForm(on)
    view.heading:SetShown(not on)
    view.list:SetShown(not on)
    view.title:SetShown(on)
    view.save:SetShown(on)
    -- (on both; said, so the pad finds it shown: CardPad.lua)
    view.cancel:Show()
    if not on then
        view.another:Hide()
        view.hide:Hide()
        view.reset:Hide()
        view.remove:Hide()
    end
end

-- Lays the slip for what `view` holds: its height from its rows, each row and
-- only the links that apply. An optional field not added has no row: its
-- strip goes on one row with the others', where the first of them would be.
local function Lay(spec)
    local M, W = SHEET.margin, SHEET.w
    local rec, inserted = view.rec, view.rec and view.rec.inserted
    local detected = rec and not inserted
    local saved = rec and (rec.customOf or rec)
    local changed = detected and saved.custom ~= nil
    local quiet = detected or inserted
    local across = math.max(1, math.floor(SHEET.line / SHEET.toggle))
    local list, strips = {}, nil
    for _, row in ipairs(view.rows) do
        if row.field.optional and not row.on then
            if not strips then
                strips = {}
                list[#list + 1] = { strips = strips }
            end
            strips[#strips + 1] = row
        else
            list[#list + 1] = { row = row }
        end
    end
    -- How much taller than one line a row stands: a line for each its
    -- toggles wrap to, the icon grid's second row, a text's rows, the
    -- faces of who was there over their line.
    local function Extra(row)
        if not row then return 0 end
        if row.field.values then return (math.ceil(#row.field.values / across) - 1) * SHEET.wrap end
        if row.cells then
            return (math.ceil(#row.cells / ICONS.across) - 1) * ICONS.cell + ICONS.cell - 20
        end
        if row.scroll then return (row.shown - 1) * WRITE.pitch end
        if row.faces then
            -- (the faces over the line; with everyone there, the faces alone)
            if not row.people[1] then return 0 end
            return #row.people < row.most and FACES.line - 10 or FACES.size + FACES.name - 20
        end
        return 0
    end
    -- A row's middle: the rows before it, and what each stands taller.
    local ys, last = {}, SHEET.first
    for i, at in ipairs(list) do
        ys[i] = last
        last = last + Extra(at.row) + (i < #list and SHEET.row or 0)
    end
    local linksAt = last + SHEET.links
    local footAt = (quiet and linksAt or last + SHEET.links - 6) + SHEET.foot
    local H = footAt + SHEET.bottom
    -- (the sheet's height, for what hangs from a line: Offering's Hang)
    view.H = H

    Place(W, H)

    K.PlaceText(view.title, M, SHEET.title)
    local x = M + SHEET.label
    for i, at in ipairs(list) do
        local y, row = ys[i], at.row
        if at.strips then
            -- The "+ Add" strips, one after another along the line.
            local sx = x
            for _, r in ipairs(at.strips) do
                local strip = r.add
                local w = K.Width(strip.words) + 2 + 2 * MORE.pad
                strip:SetNote({ size = { w, MORE.h }, guid = r.field.key, turn = MORE.turn,
                    seed = "more:" .. r.field.key, onClick = function() AddField(r) end })
                strip:Layout(sx, y - MORE.h / 2, w)
                strip:Lay(strip.words, 0, 0, w - 2 * MORE.pad + 4, 20)
                strip.words:Show()
                -- (where the pad reads it, as a button the sheet placed: CardPad)
                strip.padAt = { sx + w / 2, y }
                sx = sx + w + MORE.gap
            end
        elseif row.flag then
            K.PlaceButton(row.flag, M, y - row.flag.height / 2, W - 2 * M, row.flag.height)
        else
            K.PlaceText(row.label, M, y)
            if row.add then
                row.add:Hide()
                row.box:Show()
                row.off:Show()
                row.label:Show()
            end
            if row.toggles then
                for _, box in pairs(row.toggles) do
                    K.PlaceButton(box, x + box.at % across * SHEET.toggle,
                        y + math.floor(box.at / across) * SHEET.wrap - box.height / 2,
                        #row.field.values == 1 and SHEET.line or SHEET.toggle, box.height)
                end
            elseif row.cells then
                for _, cell in ipairs(row.cells) do
                    local c = cell.at - 1
                    K.PlaceButton(cell, x + c % ICONS.across * ICONS.cell,
                        y - ICONS.cell / 2 + math.floor(c / ICONS.across) * ICONS.cell, ICONS.cell, ICONS.cell)
                end
            elseif row.scroll then
                K.PlaceButton(row.scroll, x, y - 10, SHEET.line, row.shown * WRITE.pitch)
                row.box.padAt = row.scroll.padAt
            elseif row.faces then
                local top = y - 10
                row:Faces()
                for i in ipairs(row.people) do
                    local o = row.faces[i]
                    -- (each in its pitch, the name under it as wide)
                    local px = x + (i - 1) * FACES.pitch
                    K.PlaceButton(o, px + (FACES.pitch - FACES.size) / 2, top, FACES.size, FACES.size)
                    o:Show()
                    K.Place(o.name, px + 1, top + FACES.size + 1, FACES.pitch - 2, FACES.name)
                    o.name:SetWidth(FACES.pitch - 2)
                    o.name:Show()
                end
                local room = #row.people < row.most
                row.box:SetShown(room)
                if not room then row.found:Hide() end
                if room then
                    K.PlaceButton(row.box, x, (row.people[1] and top + FACES.line or y) - 10, SHEET.line, 20)
                end
            else
                local w = row.field.type == "number" and SHEET.short or SHEET.line
                if row.off then w = w - K.Width(row.off.label) - OFF.gap end
                K.PlaceButton(row.box, x, y - 10, w, 20)
                if row.hint then K.PlaceText(row.hint, x + w + SHEET.gap, y) end
                if row.off then row.off:PlaceAt(x + w + OFF.gap, y) end
            end
        end
    end
    -- An optional field not added: its strip stands for it, nothing else.
    for _, row in ipairs(view.rows) do
        if row.add and not row.on then
            row.add:Show()
            for _, part in ipairs({ row.label, row.box, row.off, row.found }) do part:Hide() end
        end
    end

    view.hide:SetShown(detected)
    view.reset:SetShown(changed)
    view.remove:SetShown(inserted)
    view.another:SetShown(view.where ~= nil)
    if view.where then view.another:PlaceAt(M, footAt) end
    if detected then
        view.hide:PlaceAt(M, linksAt)
        if changed then view.reset:PlaceAt(M + K.Width(view.hide.label) + SHEET.linkGap, linksAt) end
    elseif inserted then
        view.remove:PlaceAt(M, linksAt)
    end
    view.save:PlaceAt(W - M, footAt, "RIGHT")
    view.cancel:PlaceAt(W - M - K.Width(view.save.label) - SHEET.linkGap, footAt, "RIGHT")
end

-- Laid again, as the rows that are on have changed: the pad, if in hand, put
-- on `key` (the field added, the strip of the one taken off), the cursor on
-- `box` with the mouse.
local function Relay(key, box)
    Lay(ns.Custom.Spec(view.kind))
    if ns.UI.Pad.Input.Active() then
        view.padFocus = key
    elseif box then
        box:SetFocus()
    end
    PadRefresh()
end

-- An optional field added from its strip: on the form, and written on.
function AddField(row)
    row.on = true
    Relay("field:" .. row.field.key, row.box)
end

-- An optional field taken off again: cleared, and its strip back.
function TakeOff(row)
    row:Set("", nil)
    row.on = false
    Relay("more:" .. row.field.key)
end

-- Someone added to who was there: their face shown, the form laid again
-- (the line moves under the faces), the cursor kept on the line to add the
-- next; with the pad, the pad on it.
function AddPerson(row)
    local room = #row.people < row.most
    Relay(room and ("field:" .. row.field.key) or ("face:" .. row.field.key .. ":" .. #row.people),
        room and row.box or nil)
end

-- Someone taken off the card (their face's cross): the pad on the next
-- face, else the line.
function TakePerson(row, i)
    row:Drop(i)
    local next = row.people[i] or row.people[i - 1]
    Relay(next and ("face:" .. row.field.key .. ":" .. (row.people[i] and i or i - 1)) or ("field:" .. row.field.key))
end

-- A shift-clicked item (HandleModifiedItemClick, through the chat's
-- ChatEdit_InsertLink: CardSheet.Hook) while the form lies open for a kind
-- with an item's field and no chat line is being written: into that field,
-- added if it was not. True where it was taken.
function CardSheet.InsertLink(link)
    if not (view and view:IsShown() and view.rows and type(link) == "string") then return false end
    local active = _G.ChatEdit_GetActiveWindow
    if type(active) == "function" and active() then return false end
    local it = ns.Custom.ItemOf(link)
    if not it then return false end
    for _, row in ipairs(view.rows) do
        if row.field.type == "item" then
            row:Set(it.name, it.itemID, ns.UI.ItemBox.Quality(link), ns.UI.ItemBox.Icon(link))
            row.box:ClearFocus()
            if row.field.optional and not row.on then
                row.on = true
                Lay(ns.Custom.Spec(view.kind))
                PadRefresh()
            end
            return true
        end
    end
    return false
end

-- Hooked once, after the client's own (hooksecurefunc: a post-hook, so the
-- chat's link goes where it always did and nothing of the client's is
-- touched). Both the old global and its namespaced successor where the
-- client has them; one shift-click reaching both is taken once.
local hooked, lastLink, lastAt
function CardSheet.Hook()
    if hooked or type(hooksecurefunc) ~= "function" then return end
    hooked = true
    local function Insert(link)
        local at = GetTime and GetTime() or 0
        if link == lastLink and at == lastAt then return end
        lastLink, lastAt = link, at
        CardSheet.InsertLink(link)
    end
    if type(_G.ChatEdit_InsertLink) == "function" then hooksecurefunc("ChatEdit_InsertLink", Insert) end
    local util = _G.ChatFrameUtil
    if type(util) == "table" and type(util.InsertLink) == "function" then hooksecurefunc(util, "InsertLink", Insert) end
end

-- Each kind's rows off but `kind`'s.
local function RowsOff(kind)
    for key, rows in pairs(view.rowsOf) do
        if key ~= kind then
            for _, row in ipairs(rows) do ShowRow(row, false) end
        end
    end
end

-- The form for `rec` of `kind`, or a new one to go `where`. A new one always
-- starts from the kind's defaults: nothing typed outlives its form.
function Open(kind, rec, where)
    local spec = ns.Custom.Spec(kind)
    if not spec then return end
    if not view then Build() end
    RowsOff(kind)
    ShowForm(true)
    view.kind, view.rec, view.where, view.rows = kind, rec, where, RowsOf(kind, spec)
    view.title:SetText(spec.heading or Capital(spec.label))
    local values = rec and ns.Custom.Values(rec) or spec.defaults or {}
    -- What a detected card shows but keeps elsewhere (Core/Custom.lua's `values`).
    if rec and spec.values then spec.values(values, rec.customOf or rec) end
    for _, row in ipairs(view.rows) do
        ShowRow(row, true)
        local value = values[row.field.key]
        row.was = value ~= nil and tostring(value) or ""
        if row.Load then
            row:Load(values)
            row.was = row:Key()
        elseif row.field.type == "person" then
            row.guidWas = values[ns.Custom.GuidKey(row.field)]
            row:Set(row.was, row.guidWas)
        else
            row:Set(row.was)
        end
        if row.field.optional then row.on = Filled(row) end
    end
    Lay(spec)
    -- A new card is to be written on at once; a card opened may be only to
    -- leave it out, and a line with the cursor would take the keys from play.
    -- With the pad in hand no line takes the cursor by itself: A gives it one
    -- (UI/Journey/CardPad.lua), and a line holding it unasked would take the
    -- keyboard's keys from play with no sign of it under the pad's box.
    if where and not ns.UI.Pad.Input.Active() then
        for _, row in ipairs(view.rows) do
            local first = Lines(row)[1]
            if first and first.box:IsShown() then
                first.box:SetFocus()
                break
            end
        end
    end
    PadRefresh()
end

CardSheet.Edit = function(kind, rec) Open(kind, rec) end

-- The picker, for the spot already held (view.where): from the menu, or back
-- from the form.
function CardSheet.Pick()
    local P, kinds = PICKER, Kinds()
    RowsOff(nil)
    ShowForm(false)
    view.kind, view.rec, view.rows = nil, nil, nil
    local cols = #kinds > 1 and 2 or 1
    local items = {}
    for i, k in ipairs(kinds) do
        local at = math.ceil(i / cols)
        items[at] = items[at] or {}
        items[at][#items[at] + 1] = k
    end
    local rows = math.min(#items, P.most)
    local listW = cols * P.card.w + (cols - 1) * P.gap + ns.UI.SCROLLBAR_WIDTH + 2
    local W, H = 2 * P.margin + listW, P.top + rows * P.row + P.foot + 2 * P.bottom
    Place(W, H)
    K.PlaceText(view.heading, P.margin, P.title)
    view.list:SetNumRows(rows)
    view.list:SetWidth(listW)
    K.PlaceButton(view.list, P.margin, P.top, listW, rows * P.row)
    view.list:SetData(items)
    view.cancel:PlaceAt(W - P.margin, H - P.bottom, "RIGHT")
    PadRefresh()
end

-- The picker for a new card at `where` on `plate`, and the ring there.
local function StartAdding(plate, where)
    if not view then Build() end
    view.where = where
    local L = YourDiary.LEADER
    RingOff()
    -- (only where the spot is on the picture: the pad's spot, where the player
    -- stands, may be elsewhere on the zone, and a ring held at the edge would
    -- say a place that is not it)
    if not plate.At or plate.At(where.x, where.y) then
        plate:SetRing({ mapID = where.mapID, x = where.x, y = where.y, look = setmetatable({ colour = L.colour,
            alpha = L.alpha, nib = L.pen.nib }, { __index = RING }) })
        view.ringOn = plate
    end
    CardSheet.Pick()
end
function CardSheet.View() return view end

--------------------------------------------------------------------------
-- The right click
--------------------------------------------------------------------------

-- The menu of the map itself: a new card at the spot under the cursor, on a
-- zone's map only (Recap's `Own` would put any other spot back on the route),
-- on a page with a time of its own; and this page's hidden cards. No menu where
-- there is neither.
-- Where a card added with the pad goes (.claude/controller-plan.md, step 4,
-- the user's decision 1: there is no cursor to say a spot, so where the player
-- stands). On a page with a time of its own, on a zone's map only, as the
-- menu's. The player not on this plate's zone (elsewhere, or in an instance,
-- where the position is not given) has no place here to lend: then the spot of
-- the mark Y was pressed on, which is the very spot a right click on it gives;
-- on the plate itself, nothing (nil): no add line (Y still opens a close-up's
-- menu for the page's own lines, PlaceMenu). Never a made-up
-- place: the middle of the picture would be a spot the player never stood on.
local function PadWhere(plate, frame)
    local e, mapID = plate.entry, plate.mapID
    if not (e and e.from and e.to and e.to > e.from and ns.ZoneOf(mapID) == mapID) then return nil end
    local zone, x, y = ns.ZoneWhere()
    if zone ~= mapID then
        x, y = nil, nil
        local at = frame and frame.padAt
        if at and plate.MapAtCard then x, y = plate:MapAtCard(at[1], at[2]) end
    end
    if not x then return nil end
    return { mapID = mapID, x = x, y = y, from = e.from, to = e.to }
end

-- The plate's menu, as a generator (its lines, for the mouse's
-- MenuUtil.CreateContextMenu and the pad's Pad.Menu.Open alike, so the two
-- can never drift: the controller-support skill's rule 6): "Add custom
-- event..." at `where` (the spot under the cursor, or the pad's, PadWhere)
-- where a card can be added there; "Leave this place out" and "Choose what's
-- on this page..." on a close-up of the plates' page. Nil where it would hold
-- nothing; `leaves` whether it holds the page's own lines.
local function PlaceGenerator(plate, where)
    local adds = where ~= nil and Kinds()[1] ~= nil
    -- (no "Left out of this page" list here: whatever is left out, a card
    -- hidden from its own menu too, comes back on the ticklist alone,
    -- Core/Chosen.lua, the user's, 18 Nov)
    -- The page's own choice (.claude/features/choose-page.md): a close-up of
    -- the plates' page only (a full page's plate has no plan: it is the
    -- level's whole zone, not a place of this page). The menu only hides
    -- (the user's, 18 Nov): a place left out comes back on the ticklist
    -- alone, which the pad reaches too (UI/Journey/Pad.lua).
    local leaves = plate.plan ~= nil and plate.plan.moments ~= nil and plate.plan.moments[1] ~= nil
    local page = YourDiary.page
    local piece = leaves and YourDiary.ShownPiece and YourDiary.ShownPiece()
    local chooses = piece and not page.choosing and YourDiary.CanChoose(piece)
    if not (adds or leaves) then return nil, false end
    return function(_, root)
        if adds then root:CreateButton(WORDS.add, function() StartAdding(plate, where) end) end
        if leaves then
            root:CreateButton(WORDS.leavePlace, function()
                -- (eased, as a tick on the ticklist: UI/Journey/Glide.lua)
                if ns.Chosen.LeavePlace(nil, plate.plan) then YourDiary.Glide.Around(Redraw) end
            end)
            if chooses then root:CreateButton(WORDS.choose, function() YourDiary.Choose() end) end
        end
    end, leaves
end
CardSheet.PlaceGenerator = PlaceGenerator

local function PlaceMenu(plate)
    -- The pad (its Y, CardSheet.PadRight): where the menu holds the page's
    -- own lines, the same menu on the pad's slip (Pad.Menu), its add line at
    -- the pad's spot; where it would only add, straight to the picker there,
    -- as before (the lead's decision, 18 Nov).
    if padCall then
        local where = PadWhere(plate, padCall.frame)
        local generator, leaves = PlaceGenerator(plate, where)
        if generator and leaves then
            padCall.did = "menu"
            if not padCall.dry then ns.UI.Pad.Menu.Open(plate.over or plate, generator) end
        elseif generator then
            padCall.did = "add"
            if not padCall.dry then StartAdding(plate, where) end
        end
        return
    end
    local e, mapID = plate.entry, plate.mapID
    local x, y = plate:MapAtCursor()
    local where = x and e and e.from and e.to and e.to > e.from and ns.ZoneOf(mapID) == mapID
        and { mapID = mapID, x = x, y = y, from = e.from, to = e.to } or nil
    local generator = PlaceGenerator(plate, where)
    if generator then MenuUtil.CreateContextMenu(plate.over, generator) end
end

-- A person's strip's menu, as a generator (the mouse's and the pad's alike):
-- "Leave <name> off this page", `out` on every moment of theirs on the
-- page, the strip's own (a gift of theirs joined to it too) and theirs on the
-- page's other plates. As a place left out, they come back on the ticklist
-- alone (the user's, 18 Nov). Nil where there is no name to say.
local function PersonGenerator(g)
    local page = YourDiary.page
    local name = g and g.guid and ns.UI.JourneyText.Short(g.guid)
    if not (page and name) then return nil end
    local list, seen = {}, {}
    local function Add(m)
        if not seen[m] then seen[m] = true list[#list + 1] = m end
    end
    for _, m in ipairs(g.moments) do Add(m) end
    for i = 1, page.layout or 0 do
        local plan = page.plates[i] and page.plates[i].plan
        for _, m in ipairs(plan and plan.moments or {}) do
            if m.guid == g.guid then Add(m) end
        end
    end
    return function(_, root)
        root:CreateButton(ns.Fmt(WORDS.leavePerson, name), function()
            local any = false
            for _, m in ipairs(list) do any = ns.Chosen.Leave(nil, m) or any end
            if any then YourDiary.Glide.Around(Redraw) end
        end)
    end
end
CardSheet.PersonGenerator = PersonGenerator

-- A person's strip's right click (UI/Journey/Margin.lua: strip:SetRight's
-- `menu`): their menu; `pad`, the pad's Y (UI/Journey/Pad.lua's CardAt),
-- the same menu on the pad's slip (Pad.Menu), never MenuUtil. The pad has
-- the way back since the ticklist took it (choose-page.md, "Later: the
-- gamepad").
function CardSheet.Person(strip, g, pad)
    local generator = PersonGenerator(g)
    if not generator then return end
    if pad then return ns.UI.Pad.Menu.Open(strip, generator) end
    MenuUtil.CreateContextMenu(strip, generator)
end

-- plate.onRight (UI/Journey/Leaders.lua; plate:Right). `spot`: a registered
-- mark's kind and its merged moments.
function CardSheet.Right(plate, spot)
    local spec = spot and ns.Custom.Spec(spot.kind)
    local field = spec and ns.JourneyRecap.MOMENTS[spot.kind].field
    if field then
        local recs = {}
        for _, m in ipairs(spot.list) do
            if m[field] then recs[#recs + 1] = m[field] end
        end
        -- (the pad has no menu: a spot merging several opens the first, as the
        -- menu lists them first)
        if padCall and recs[1] then
            padCall.did = "edit"
            if not padCall.dry then Open(spot.kind, recs[1]) end
            return
        end
        if #recs == 1 then
            Open(spot.kind, recs[1])
            return
        elseif recs[1] then
            MenuUtil.CreateContextMenu(plate.over, function(_, root)
                root:CreateTitle(WORDS.which)
                for _, rec in ipairs(recs) do
                    root:CreateButton(Described(spec, rec), function() Open(spot.kind, rec) end)
                end
            end)
            return
        end
    end
    PlaceMenu(plate)
end

-- The pad's Y (UI/Journey/CardPad.lua): what a right click does, there being
-- no right button. `frame` is what the pad stands on among a plate's marks (a
-- mark's square or a pass's button, whose own right click is asked, so a
-- print's or a slip's says its card as under the mouse), nil for the plate
-- itself. Returns what it did, "edit", "add" or "menu" (the plate's menu on
-- the pad's slip, PlaceMenu), or nil for nothing; `dry` only says what it
-- would do (the prompt's words), doing nothing.
function CardSheet.PadRight(plate, frame, dry)
    local call = { plate = plate, frame = frame, dry = dry }
    padCall = call
    local ok, err = pcall(function()
        local up = frame and frame:GetScript("OnMouseUp")
        if up then up(frame, "RightButton") else plate:Right() end
    end)
    padCall = nil
    if not ok then error(err, 0) end
    return call.did
end
