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
local GROUPS = { { key = "combat", words = "Combat" }, { key = "lore", words = "Quests and Lore" },
    { key = "social", words = "Social" }, { key = "other", words = "Other" } }
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
local PERSON = { most = 4, row = 18, level = 20, out = 4, foot = 2, hot = 0.12, paper = { 0.93, 0.88, 0.74 } }

-- The words of the form and the menus, all furniture (the copywriter's §1). Add,
-- pick and another are the user's own, word for word.
local WORDS = {
    add = "Add custom event...", pick = "What happened here?", another = "Choose another", which = "Which one?", hidden = "Left out of this page", save = "Save", cancel = "Cancel",
    hide = "Leave it out", reset = "Undo my changes", remove = "Delete this card",
    confirm = "Delete this card you wrote?\n\nIt comes off the map and the page. This cannot be undone.",
}

local CardSheet = {}
YourDiary.CardSheet = CardSheet

local view, K

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

local function LetGo()
    for _, row in ipairs(view.rows or {}) do
        if row.box then row.box:ClearFocus() end
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
local function NewRow(field)
    local S = view.sheet
    local row = { field = field, label = Style.Text(S, FONT.heading) }
    row.label:SetText(field.label:upper())
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
            row.toggles[value] = box
        end
        function row:Set(value)
            self.value = value ~= "" and value or nil
            Tick()
        end
        function row:Get() return self.value or "" end
    elseif field.type == "person" then
        row.box = Style.WritingLine(S, SHEET.line, FONT.note, field.hint)
        row.box:SetMaxLetters(field.most or 60)
        local found = CreateFrame("Frame", nil, S)
        found:SetFrameLevel(S:GetFrameLevel() + PERSON.level)
        found:SetPoint("TOPLEFT", row.box, "BOTTOMLEFT", -PERSON.out, -1)
        found:SetPoint("TOPRIGHT", row.box, "BOTTOMRIGHT", PERSON.out, -1)
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
        row.found, row.rows = found, {}
        local function Offer()
            local people = row.box:HasFocus() and ns.Custom.FindPeople(row.box:GetText(), PERSON.most) or {}
            for i, person in ipairs(people) do
                local line = row.rows[i]
                if not line then
                    line = CreateFrame("Button", nil, found)
                    line:SetHeight(PERSON.row)
                    line:SetPoint("TOPLEFT", PERSON.out, -(i - 1) * PERSON.row)
                    line:SetPoint("TOPRIGHT", -PERSON.out, -(i - 1) * PERSON.row)
                    line.text = Style.Text(line, FONT.note)
                    line.text:SetPoint("LEFT")
                    local hot = line:CreateTexture(nil, "HIGHLIGHT")
                    hot:SetAllPoints()
                    hot:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], PERSON.hot)
                    line:SetScript("OnClick", function(self)
                        row:Set(self.person.name, self.person.guid)
                        found:Hide()
                    end)
                    row.rows[i] = line
                end
                line.person = person
                line.text:SetText(person.name)
                line:Show()
            end
            for i = #people + 1, #row.rows do row.rows[i]:Hide() end
            found:SetHeight(#people * PERSON.row + PERSON.foot)
            found:SetShown(#people > 0)
        end
        -- Typing is not picking: whatever was linked lets go at the first key.
        row.box:HookScript("OnTextChanged", function(_, typed)
            if typed then
                row.guid = nil
                Offer()
            end
        end)
        function row:Set(value, guid)
            self.guid = guid
            self.box:SetValue(value)
            self.found:Hide()
        end
        function row:Get() return self.box:GetText() or "" end
    else
        local number = field.type == "number"
        row.box = Style.WritingLine(S, number and SHEET.short or SHEET.line, number and FONT.strong or FONT.note,
            not number and field.hint or nil)
        row.box:SetMaxLetters(number and 4 or (field.most or 60))
        if number and field.hint then
            row.hint = Style.Text(S, FONT.small)
            row.hint:SetText(field.hint)
        end
        function row:Set(value) self.box:SetValue(value) end
        function row:Get() return self.box:GetText() or "" end
    end
    return row
end

local function RowsOf(kind, spec)
    view.rowsOf[kind] = view.rowsOf[kind] or {}
    local rows = view.rowsOf[kind]
    if not rows[1] then
        local boxes = {}
        for i, field in ipairs(spec.fields) do
            rows[i] = NewRow(field)
            if rows[i].box then boxes[#boxes + 1] = rows[i].box end
        end
        -- Tab walks the lines, as on the entry form.
        -- Enter saves the card, on any line of any kind's form.
        for i, box in ipairs(boxes) do
            box:SetScript("OnTabPressed", function()
                for _, row in ipairs(rows) do
                    if row.found then row.found:Hide() end
                end
                boxes[i % #boxes + 1]:SetFocus()
            end)
            box:SetScript("OnEnterPressed", function() view.save:GetScript("OnClick")(view.save) end)
        end
    end
    return rows
end

local function ShowRow(row, on)
    row.label:SetShown(on)
    for _, part in pairs({ row.box, row.hint }) do part:SetShown(on) end
    if row.found and not on then row.found:Hide() end
    for _, box in pairs(row.toggles or {}) do box:SetShown(on) end
end

-- What is to be written: all of an inserted card, of one that exists what
-- changed since the form opened. An edit sent the name unchanged would look the
-- creature up again and might change its picture for nothing.
local function Fields()
    local fields, any = {}, false
    for _, row in ipairs(view.rows) do
        local value = row:Get()
        local guidKey = row.field.type == "person" and ns.Custom.GuidKey(row.field)
        if view.where or value ~= row.was or (guidKey and row.guid ~= row.guidWas) then
            fields[row.field.key] = value
            if guidKey then fields[guidKey] = row.guid end
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
    cell.eyebrow:SetText(k.words:upper())
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
    if not on then
        view.another:Hide()
        view.hide:Hide()
        view.reset:Hide()
        view.remove:Hide()
    end
end

-- Lays the slip for what `view` holds: its height from its rows, each row and
-- only the links that apply.
local function Lay(spec)
    local M, W = SHEET.margin, SHEET.w
    local rows = view.rows
    local rec, inserted = view.rec, view.rec and view.rec.inserted
    local detected = rec and not inserted
    local saved = rec and (rec.customOf or rec)
    local changed = detected and saved.custom ~= nil
    local quiet = detected or inserted
    -- A row's middle: the rows before it, one taller for each line its toggles
    -- wrap to.
    local across = math.max(1, math.floor(SHEET.line / SHEET.toggle))
    local ys, last = {}, SHEET.first
    for i, row in ipairs(rows) do
        ys[i] = last
        local lines = row.field.values and math.ceil(#row.field.values / across) or 1
        last = last + (lines - 1) * SHEET.wrap + (i < #rows and SHEET.row or 0)
    end
    local linksAt = last + SHEET.links
    local footAt = (quiet and linksAt or last + SHEET.links - 6) + SHEET.foot
    local H = footAt + SHEET.bottom

    Place(W, H)

    K.PlaceText(view.title, M, SHEET.title)
    for i, row in ipairs(rows) do
        local y = ys[i]
        local x = M + SHEET.label
        K.PlaceText(row.label, M, y)
        if row.toggles then
            for _, box in pairs(row.toggles) do
                K.PlaceButton(box, x + box.at % across * SHEET.toggle,
                    y + math.floor(box.at / across) * SHEET.wrap - box.height / 2,
                    #row.field.values == 1 and SHEET.line or SHEET.toggle, box.height)
            end
        else
            local w = row.field.type == "number" and SHEET.short or SHEET.line
            K.PlaceButton(row.box, x, y - 10, w, 20)
            if row.hint then K.PlaceText(row.hint, x + w + SHEET.gap, y) end
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
        if row.field.type == "person" then
            row.guidWas = values[ns.Custom.GuidKey(row.field)]
            row:Set(row.was, row.guidWas)
        else
            row:Set(row.was)
        end
    end
    Lay(spec)
    -- A new card is to be written on at once; a card opened may be only to
    -- leave it out, and a line with the cursor would take the keys from play.
    if where then
        local first = view.rows[1]
        if first and first.box then first.box:SetFocus() end
    end
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
end

-- The picker for a new card at `where` on `plate`, and the ring there.
local function StartAdding(plate, where)
    if not view then Build() end
    view.where = where
    local L = YourDiary.LEADER
    RingOff()
    plate:SetRing({ mapID = where.mapID, x = where.x, y = where.y, look = setmetatable({ colour = L.colour, alpha = L.alpha,
        nib = L.pen.nib }, { __index = RING }) })
    view.ringOn = plate
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
local function PlaceMenu(plate)
    local e, mapID = plate.entry, plate.mapID
    local x, y = plate:MapAtCursor()
    local where = x and e and e.from and e.to and e.to > e.from and ns.ZoneOf(mapID) == mapID
        and { mapID = mapID, x = x, y = y, from = e.from, to = e.to } or nil
    local adds = where and Kinds()[1] ~= nil
    local hidden = {}
    for _, h in ipairs(e and e.hidden or {}) do
        if ns.Custom.Spec(h.kind) then hidden[#hidden + 1] = h end
    end
    if not (adds or hidden[1]) then return end
    MenuUtil.CreateContextMenu(plate.over, function(_, root)
        if adds then root:CreateButton(WORDS.add, function() StartAdding(plate, where) end) end
        if hidden[1] then
            if adds then root:CreateDivider() end
            root:CreateTitle(WORDS.hidden)
            for _, h in ipairs(hidden) do
                root:CreateButton(Described(ns.Custom.Spec(h.kind), h.rec), function()
                    ns.Custom.Show(h.rec)
                    Redraw()
                end)
            end
        end
    end)
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
