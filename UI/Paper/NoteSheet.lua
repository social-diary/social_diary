-- A note for the timeline (DIA-11), written on a loose sheet laid across the
-- book like the map (UI/Paper/Sheet.lua), from the profile's "Add a note"
-- tab or a note clicked on the timeline. The Remember this keybind lays the
-- same sheet over the game, on nobody yet (ns.UI.QuickNote, below).
--
-- The sheet was folded once across the middle, its corners curl up a
-- little, and it lies straight: the box being written in cannot turn with
-- it. At the top, whom the note is about,
-- as round portraits: the open person, and everyone else linked to it, each
-- with a cross to unlink them. "Link others..." opens a card to link
-- anyone in the diary, the group they were in at the time first, with a
-- search (UI/Paper/LinkSheet.lua), so a group evening can be one note.
--
-- Unlike the map, a click on the book beside it does not put it away: it
-- stays until it is saved, cancelled or deleted, and the book under it
-- takes no clicks. Turning to another tab or person hides it with the
-- draft kept for the next time it opens on the same person; Cancel throws
-- the draft away.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT

-- The sheet and what is on it, in its own coordinates (x right, y down).
local SHEET = { w = 440, h = 430, margin = 30, title = 36, about = 70, portraits = 98,
    box = 132, footer = 30 }
-- The portraits: their size, the gap between them, how many before "+N",
-- and the cross on each: its size, and how far it sits out on the rim.
local PORTRAIT = { size = 34, gap = 10, most = 6, cross = 14, out = 3 }
-- Folded once across the middle, a valley, and hardly crumpled: a mesh of
-- the fold and narrow strips round the edges, for the corners to curl up
-- in. Its other lines stay true, so the paper does not break into patches.
local CREASE = {
    columns = { 0, 0.07, 0.93, 1 },
    rows = { 0, 0.07, 0.5, 0.93, 1 },
    folds = { columns = {}, rows = { [3] = -1 } },
    crumple = 0.5, drift = 0.4, edge = 0.6, wander = 0, shift = 3, lean = 2,
    curl = { lift = 5, pull = 3 },
}

local ELLIPSIS = "\226\128\166"

-- A round portrait with a paper button on its rim to unlink them.
local function Ornament(S, onUnlink)
    local o = Style.Portrait(S, PORTRAIT.size)
    Style.Tooltip(o, function(self) return self.guid and ns.Characters.FullName(self.guid) end)

    local cross = CreateFrame("Button", nil, o)
    cross:SetSize(PORTRAIT.cross, PORTRAIT.cross)
    cross:SetPoint("CENTER", o, "TOPRIGHT", -PORTRAIT.out, -PORTRAIT.out)
    local disc = cross:CreateTexture(nil, "BACKGROUND", nil, 0)
    disc:SetAllPoints()
    local INK, P = Style.INK, Style.PAPER
    Style.Disc(disc, INK[1], INK[2], INK[3], 0.85)
    local face = cross:CreateTexture(nil, "BACKGROUND", nil, 1)
    face:SetPoint("TOPLEFT", 1, -1)
    face:SetPoint("BOTTOMRIGHT", -1, 1)
    Style.Disc(face, P[1], P[2], P[3], 1)
    local mark = Style.Text(cross, FONT.tag)
    mark:SetPoint("CENTER", 0, 1)
    mark:SetText("\195\151")  -- the multiplication sign, U+00D7
    mark:SetTextColor(Style.INK_STRONG[1], Style.INK_STRONG[2], Style.INK_STRONG[3])
    cross:SetScript("OnClick", function() onUnlink(o.guid) end)
    Style.Tooltip(cross, function() return "Unlink " .. (ns.Characters.Name(o.guid) or "them") end)
    o.cross = cross
    return o
end

ns.UI.NoteSheet = {}

-- `parent` is the book. Returns the sheet; :Open(guid, note) lays it on
-- the book for a new note about `guid`, or to change `note`. `onDone` runs
-- once it is saved, cancelled or deleted.
function ns.UI.NoteSheet.New(parent)
    local W, H, M = SHEET.w, SHEET.h, SHEET.margin
    local view, K = ns.UI.LooseSheet(parent, W, H, { crease = CREASE, straight = true })
    local S = view.sheet

    -- What it holds: `guid`, the person it was opened on, if anyone;
    -- `editing`, the note being changed, if any; `others`, everyone else
    -- linked, in the order they were linked; `kept`, whether there is a
    -- draft to keep when it opens again.
    view.others = {}

    -- `quiet`: the sheet goes without its rustle, as the quill said it.
    local function Done(quiet)
        view.box:ClearFocus()
        view:Hide(quiet)
        if view.onDone then view.onDone() end
    end

    ----------------------------------------------------------------------
    -- The pieces

    view.title = Style.Text(S, FONT.page)
    view.written = Style.Text(S, FONT.small)
    view.aboutLabel = Style.Text(S, FONT.heading)
    view.aboutLabel:SetText("ABOUT")

    local Refresh

    local function Linked(guid)
        for i, other in ipairs(view.others) do
            if other == guid then return i end
        end
    end

    local function Unlink(guid)
        local i = Linked(guid)
        if i then table.remove(view.others, i) end
        Refresh()
    end

    view.portraits = {}
    for i = 1, PORTRAIT.most do view.portraits[i] = Ornament(S, Unlink) end
    view.more = Style.Text(S, FONT.small)

    -- Link others: a card laid over this one (UI/Paper/LinkSheet.lua), with the
    -- group they were in first and a search over the whole diary. Hidden
    -- with this sheet.
    view.picker = ns.UI.LinkSheet.New(parent)
    view:SetScript("OnHide", function() if view.picker:IsShown() then view.picker:Close() end end)

    local function OpenPicker()
        view.box:ClearFocus()
        view.picker:Open({
            guid = view.guid,
            time = view.editing and view.editing.time or ns.Now(),
            linked = function(guid) return Linked(guid) ~= nil end,
            toggle = function(guid)
                if Linked(guid) then Unlink(guid) else
                    view.others[#view.others + 1] = guid
                    Refresh()
                end
            end,
        })
    end
    view.link = K.Link(FONT.small, OpenPicker)

    -- The ruled box, the entry form's (UI/Windows/Entry.lua), on a frame of
    -- its own that gives it its width and length counter.
    local page = CreateFrame("Frame", nil, S)
    page:SetAllPoints(S)
    page.width = W - 2 * M
    page.count = Style.Text(page, FONT.small)
    view.box = ns.UI.Entry.RuledNote(page, nil, "What happened? Write it down while you remember it.")
    view.page = page

    view.delete = K.Link(FONT.body, function()
        if view.editing then ns.Notes.Delete(view.editing.id) end
        view.guid, view.kept = nil, false
        Done()
    end)
    view.delete:SetText("Delete this note")
    view.delete:SetColor(Style.ACCENT[1], Style.ACCENT[2], Style.ACCENT[3])

    view.cancel = K.Link(FONT.body, function()
        view.guid, view.kept = nil, false
        Done()
    end)
    view.cancel:SetText("Cancel")

    -- The note goes into the diary, or the changed one back, about everyone
    -- linked; a note being changed and emptied goes. Written but about
    -- nobody yet, it asks whom first.
    view.save = K.Link(FONT.strong, function()
        local note, text, written = view.editing, view.box:GetText(), false
        if not note and not view.guid and #view.others == 0 and (text or ""):match("%S") then
            OpenPicker()
            return
        end
        if note then
            ns.Notes.Edit(note.id, text)
            if ns.Notes.Get(note.id) then
                for _, guid in ipairs(view.others) do ns.Notes.AddPerson(note.id, guid) end
                for _, guid in ipairs(ns.Notes.Others(note, view.guid)) do
                    if not Linked(guid) then ns.Notes.RemovePerson(note.id, guid) end
                end
            end
        else
            local guids = { view.guid }
            for _, guid in ipairs(view.others) do guids[#guids + 1] = guid end
            written = ns.Notes.Add(guids, text) ~= nil
        end
        -- A new note written down: the quill, not the paper.
        if written then Style.PlaySound("write") end
        view.guid, view.kept = nil, false
        Done(written)
    end)
    view.save:SetText("Save")

    ----------------------------------------------------------------------
    -- Laying it out

    -- The portraits, them first and without a cross, then the rest of the
    -- linked; then the link to add more, always.
    local function PlacePortraits()
        local list = { view.guid }
        for _, guid in ipairs(view.others) do list[#list + 1] = guid end
        view.link:SetText((#list == 0 and "Link who it is about" or "Link others") .. ELLIPSIS)
        local size, y = PORTRAIT.size, SHEET.portraits
        local x, shown = M, 0
        for i, o in ipairs(view.portraits) do
            local guid = list[i]
            if guid and (i < PORTRAIT.most or #list == PORTRAIT.most) then
                o.guid = guid
                o:SetCharacter(ns.Characters.Get(guid))
                o.cross:SetShown(guid ~= view.guid)
                K.PlaceButton(o, x, y - size / 2, size, size)
                o:Show()
                x, shown = x + size + PORTRAIT.gap, shown + 1
            else
                o:Hide()
            end
        end
        local rest = #list - shown
        view.more:SetText(rest > 0 and ("+" .. rest) or "")
        if rest > 0 then
            local _, w = K.PlaceText(view.more, x, y)
            x = x + w + PORTRAIT.gap
        end
        view.link:PlaceAt(x + 4, y)
        view.link:Show()
    end

    function Refresh()
        K.Lay()
        view.title:SetText(view.editing and "Your note" or "A new note")
        K.PlaceText(view.title, M, SHEET.title)
        local note = view.editing
        view.written:SetText(note and ("Written " .. ns.UI.Format.DayMonth(note.time, ns.Now())
            .. (note.zone and (" in " .. note.zone) or "")) or "")
        K.PlaceText(view.written, W - M, SHEET.title, "RIGHT")
        K.PlaceText(view.aboutLabel, M, SHEET.about)
        PlacePortraits()

        K.PlaceButton(view.page.noteScroll, M, SHEET.box, W - 2 * M, H - SHEET.box - SHEET.footer - 30)
        K.PlaceText(page.count, W - M, H - SHEET.footer - 18, "RIGHT")

        local y = H - SHEET.footer
        view.delete:SetShown(note ~= nil)
        view.delete:PlaceAt(M, y)
        view.save:PlaceAt(W - M, y, "RIGHT")
        view.cancel:PlaceAt(W - M - K.Width(view.save.label) - 18, y, "RIGHT")
    end

    -- A new note about `guid` keeps the draft it was hidden with; a note
    -- to change opens as it is. Without `guid`, a note about whoever gets
    -- linked.
    function view:Open(guid, note)
        local keep = not note and not self.editing and self.kept and self.guid == guid
        if not keep then
            self.guid, self.editing, self.others, self.kept = guid, note, {}, true
            if note then
                for _, other in ipairs(ns.Notes.Others(note, guid)) do self.others[#self.others + 1] = other end
            end
            self.box:SetValue(note and note.text or "")
            page.noteScroll:SetVerticalScroll(0)
        end
        K.Fall(guid)
        self:Show()
        Refresh()
        -- (with the pad in hand the box waits for A: UI/Journal/NotePad.lua)
        if not ns.UI.Pad.Input.Active() then self.box:SetFocus() end
    end

    -- Links one more, unless they are on it already.
    function view:Link(guid)
        guid = ns.SafeGUID(guid)
        if not guid or guid == self.guid or Linked(guid) then return end
        self.others[#self.others + 1] = guid
        Refresh()
    end

    view:Hide()
    return view
end

--------------------------------------------------------------------------
-- The keybind's note
--------------------------------------------------------------------------

-- The Remember this keybind with nobody to add (UI/Blizzard/Bindings.lua): the
-- same sheet, laid over the game on a frame of its own rather than on the
-- book, so it works mid-play with the journal shut. It is about nobody until
-- someone is linked: from its own link, or the keybind again on a target
-- already in the diary. Escape puts it away with the draft kept, like
-- turning away from the book's; Cancel throws the draft away.

local quick

local function BuildQuick()
    local host = CreateFrame("Frame", "SocialDiaryNoteFrame", UIParent)
    host:SetSize(SHEET.w + 60, SHEET.h + 60)
    host:SetPoint("CENTER")
    host:SetFrameStrata("DIALOG")
    host:SetToplevel(true)
    host:Hide()
    UISpecialFrames[#UISpecialFrames + 1] = "SocialDiaryNoteFrame"

    host.note = ns.UI.NoteSheet.New(host)
    host.note.onDone = function() host:Hide() end
    return host
end

-- Opens it, keeping a draft, and links `guid` on it if given. Without
-- `guid` and already open, it puts it away.
function ns.UI.QuickNote(guid)
    quick = quick or BuildQuick()
    local open = quick:IsShown() and quick.note:IsShown()
    if open and not guid then
        quick:Hide()
        return
    end
    if not open then
        quick:Show()
        quick:Raise()
        quick.note:Open(nil)
    end
    if guid then quick.note:Link(guid) end
end
