-- Custom cards' side of the page (.claude/features/custom-cards.md, the data
-- in Core/Custom.lua): a right click on a plate, close-up or full page, and
-- the form a card is changed or written on.
--
-- A right click on a mark or a card of a kind that may be custom opens the
-- form for its record (a spot merging several asks which, by a menu). Anywhere
-- else on the picture a menu offers a card of each such kind at that spot, and
-- the cards hidden on this page, which have no mark left to click. A mark of
-- any other kind counts as anywhere else: the map under it is still the map.
--
-- Everything is read off the kinds' registered `custom` specs, so this names no
-- feature, and a later kind needs no change here. The time is never asked:
-- Custom.Insert finds it within the page's own (plate.entry: the open piece on
-- a close-up, the level on a full page).
--
-- The form is a slip laid on the book's left page, so the plate it is about
-- stays in sight. It lies straight, as an edit box cannot turn (the note
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
-- `gap` on). links: from the last row to the quiet links' middle, foot: from
-- there, or from the last row where it has none, to Save's. bottom: under Save.
-- Its height comes of its rows: a later kind may have more.
local SHEET = { w = 320, margin = 26, title = 32, first = 66, row = 30, label = 92, line = 176, short = 48, gap = 8,
    links = 34, foot = 28, bottom = 26, linkGap = 18 }
-- Not folded: a slip, not a sheet carried in the book. Its corners curl a
-- little and it is hardly crumpled, as the note sheet's (NoteSheet.lua's CREASE,
-- whose every value is said there).
local CREASE = { columns = { 0, 0.07, 0.93, 1 }, rows = { 0, 0.07, 0.93, 1 }, folds = { columns = {}, rows = {} },
    crumple = 0.5, drift = 0.4, edge = 0.6, wander = 0, shift = 3, lean = 2, curl = { lift = 5, pull = 3 } }

-- The words of the form and the menus, all furniture (the copywriter's §1).
local WORDS = {
    insert = "Add %s here", which = "Which one?", hidden = "Left out of this page", save = "Save", cancel = "Cancel",
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

local function Close(quiet)
    for _, row in ipairs(view.rows or {}) do
        if row.box then row.box:ClearFocus() end
    end
    view:Hide(quiet)
end

-- A field's row. Numbers are a writing line and not Style.NumberField, which
-- will not take the minus of a skull's -1, nor stay empty for "no value".
local function NewRow(field)
    local S = view.sheet
    local row = { field = field, label = Style.Text(S, FONT.heading) }
    row.label:SetText(field.label:upper())
    if field.type == "choice" then
        local choices = { { label = field.empty } }
        for _, value in ipairs(field.values) do
            choices[#choices + 1] = { label = field.names[value], key = value }
        end
        local function Name(value)
            return value and field.names[value] or field.empty
        end
        row.link = K.Link(FONT.body, function(self)
            Style.ChoiceMenu(self, field.label, choices, function() return row.value end, function(value)
                row:Set(value or "")
            end)
        end)
        function row:Set(value)
            self.value = value ~= "" and value or nil
            self.link:SetText(Name(self.value))
        end
        function row:Get() return self.value or "" end
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
        for i, box in ipairs(boxes) do
            box:SetScript("OnTabPressed", function() boxes[i % #boxes + 1]:SetFocus() end)
        end
    end
    return rows
end

local function ShowRow(row, on)
    row.label:SetShown(on)
    for _, part in pairs({ row.box, row.hint, row.link }) do part:SetShown(on) end
end

-- What is to be written: all of an inserted card, of one that exists what
-- changed since the form opened. An edit sent the name unchanged would look the
-- creature up again and might change its picture for nothing.
local function Fields()
    local fields, any = {}, false
    for _, row in ipairs(view.rows) do
        local value = row:Get()
        if view.where or value ~= row.was then
            fields[row.field.key] = value
            any = true
        end
    end
    return fields, any
end

local function Build()
    local book = ns.UI.JournalFrame()
    view, K = ns.UI.LooseSheet(book, SHEET.w, 300, { crease = CREASE, straight = true })
    view.rowsOf = {}
    view.title = Style.Text(view.sheet, FONT.page)

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
    view:Hide()
end

-- Lays the slip for what `view` holds: its height from its rows, on the left
-- page's middle, each row and only the links that apply.
local function Lay(spec)
    local M, W = SHEET.margin, SHEET.w
    local rows = view.rows
    local rec, inserted = view.rec, view.rec and view.rec.inserted
    local detected = rec and not inserted
    local saved = rec and (rec.customOf or rec)
    local changed = detected and saved.custom ~= nil
    local quiet = detected or inserted
    local last = SHEET.first + (#rows - 1) * SHEET.row
    local linksAt = last + SHEET.links
    local footAt = (quiet and linksAt or last + SHEET.links - 6) + SHEET.foot
    local H = footAt + SHEET.bottom

    K.Reshape(W, H)
    K.Fall("custom-card", nil, { BOOK.LEFT_X + BOOK.LEFT_W / 2 - BOOK.BOOK_W / 2, 0 })
    view:Show()
    K.Lay()

    K.PlaceText(view.title, M, SHEET.title)
    for i, row in ipairs(rows) do
        local y = SHEET.first + (i - 1) * SHEET.row
        local x = M + SHEET.label
        K.PlaceText(row.label, M, y)
        if row.link then
            row.link:PlaceAt(x, y)
        else
            local w = row.field.type == "number" and SHEET.short or SHEET.line
            K.PlaceButton(row.box, x, y - 10, w, 20)
            if row.hint then K.PlaceText(row.hint, x + w + SHEET.gap, y) end
        end
    end

    view.hide:SetShown(detected)
    view.reset:SetShown(changed)
    view.remove:SetShown(inserted)
    if detected then
        view.hide:PlaceAt(M, linksAt)
        if changed then view.reset:PlaceAt(M + K.Width(view.hide.label) + SHEET.linkGap, linksAt) end
    elseif inserted then
        view.remove:PlaceAt(M, linksAt)
    end
    view.save:PlaceAt(W - M, footAt, "RIGHT")
    view.cancel:PlaceAt(W - M - K.Width(view.save.label) - SHEET.linkGap, footAt, "RIGHT")
end

-- The form for `rec` of `kind`, or a new one to go `where`.
local function Open(kind, rec, where)
    local spec = ns.Custom.Spec(kind)
    if not spec then return end
    if not view then Build() end
    for key, rows in pairs(view.rowsOf) do
        if key ~= kind then
            for _, row in ipairs(rows) do ShowRow(row, false) end
        end
    end
    view.kind, view.rec, view.where, view.rows = kind, rec, where, RowsOf(kind, spec)
    view.title:SetText(Capital(spec.label))
    local values = rec and ns.Custom.Values(rec) or spec.defaults or {}
    for _, row in ipairs(view.rows) do
        ShowRow(row, true)
        local value = values[row.field.key]
        row.was = value ~= nil and tostring(value) or ""
        row:Set(row.was)
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
function CardSheet.View() return view end

--------------------------------------------------------------------------
-- The right click
--------------------------------------------------------------------------

-- The kinds that may be inserted, in their moments' order.
local function Kinds()
    local list = {}
    for kind, moment in pairs(ns.JourneyRecap.MOMENTS) do
        if moment.custom and moment.custom.label then list[#list + 1] = { kind = kind, moment = moment } end
    end
    table.sort(list, function(a, b) return (a.moment.order or 0) < (b.moment.order or 0) end)
    return list
end

-- The menu of the map itself: a new card at the spot under the cursor, on a
-- zone's map only (Recap's `Own` would put any other spot back on the route),
-- on a page with a time of its own; and this page's hidden cards. No menu where
-- there is neither.
local function PlaceMenu(plate)
    local e, mapID = plate.entry, plate.mapID
    local x, y = plate:MapAtCursor()
    local where = x and e and e.from and e.to and e.to > e.from and ns.ZoneOf(mapID) == mapID
        and { mapID = mapID, x = x, y = y, from = e.from, to = e.to } or nil
    local kinds = where and Kinds() or {}
    local hidden = {}
    for _, h in ipairs(e and e.hidden or {}) do
        if ns.Custom.Spec(h.kind) then hidden[#hidden + 1] = h end
    end
    if not (kinds[1] or hidden[1]) then return end
    MenuUtil.CreateContextMenu(plate.over, function(_, root)
        for _, k in ipairs(kinds) do
            root:CreateButton(WORDS.insert:format(k.moment.custom.label), function() Open(k.kind, nil, where) end)
        end
        if hidden[1] then
            if kinds[1] then root:CreateDivider() end
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
