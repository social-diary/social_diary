-- The add / edit page (DIA-4, DIA-6, DIA-7).
--
-- DIA-4 caps adding at two actions: "Remember this", then Done. Until Done
-- the page writes on a draft (ns.Diary.Draft), and Done is what adds them,
-- with the note and the tags if any were written -- they stay *optional*.
-- Closing the page instead adds nobody. Remove is the undo after that
-- (ns.UI.ConfirmRemove, DIA-7's popup, in UI/Kit/Confirm.lua).
--
-- One form, written on like a page (ns.UI.Entry.Form), shown in two places:
-- on the journal's right page when the journal is open (Edit turns the page
-- to writing mode), and otherwise as a loose sheet of its own -- the quick
-- add from the keybind or a menu, mid-play, where the whole book would be in
-- the way. After a quick add the note has the cursor.
--
-- Everything edits through ns.Diary (or the draft, which answers the same
-- calls), never the tables directly, so the caps and normalisation in DIA-6
-- apply wherever the edit came from. It saves as you write: a chip saves on
-- click, the lines on Enter or losing focus.

local addonName, ns = ...

local Format = ns.UI.Format

-- What the journal's pages and the note sheet build from this file: the
-- form, its ruled note and meta line, and the loose sheet's refresh and
-- close. ShowEntry and Remember are the entry points.
local Entry = {}
ns.UI.Entry = Entry

local Style = ns.Style
local FONT = Style.FONT

local MAX_CHIPS = #ns.Diary.PRESET_TAGS + 12
local CHIP_GAP, CHIP_ROW = 6, 24
local NOTE_LINE = 22                -- ruled line spacing, and the note's line height
-- The note font's own line height in this client, measured in game (7 Oct):
-- SetSpacing adds to it, so the gap between text lines is the difference.
local NOTE_FONT_LINE = 14
-- Where a rule sits in its 22px band: just under the 14px of text.
local NOTE_RULE_AT = 16
local NOTE_LIMIT, NOTE_WARN = 2000, 1800

local SHEET_W, SHEET_H, SHEET_MARGIN = 500, 560, 26

local sheet

--------------------------------------------------------------------------
-- The form
--------------------------------------------------------------------------

-- "Added 6 October in Mulgore, 6 interactions on record". On a draft,
-- that it is not added yet.
function Entry.Meta(guid, draft)
    local entry = (draft or ns.Diary).Get(guid)
    if not entry then return "" end
    local rows = ns.Interactions.Count(guid)
    local count = rows == 0 and "no interactions yet" or (Format.Count(rows, "interaction", "interactions") .. " on record")
    if draft then return "  " .. count end
    local place = entry.addedContext and entry.addedContext.zone
    return ("Added %s%s, %s"):format(Format.DayMonth(entry.addedAt, ns.Now()), place and (" in " .. place) or "", count)
end

local function Label(parent, text)
    local label = Style.Text(parent, FONT.heading)
    label:SetText(text:upper())
    return label
end

-- The note: a multi-line EditBox on ruled lines, scrolled by its own frame.
-- The lines belong to the box, so they move with the text. `form` gives it
-- its `width` and a `count` to show the length in, and gets `noteScroll`
-- to anchor; `onCommit`, if any, has the text when the box lets go. Shared
-- with the page a timeline note is written on (UI/Journal/Profile.lua).
local function BuildNote(form, onCommit, hint)
    local scroll = CreateFrame("ScrollFrame", nil, form)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)

    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetMaxLetters(NOTE_LIMIT)
    box:SetFontObject(FONT.note)
    box:SetSpacing(NOTE_LINE - NOTE_FONT_LINE)
    box:SetWidth(form.width)
    box:SetHeight(NOTE_LINE)
    scroll:SetScrollChild(box)

    box.lines = {}
    for i = 1, math.ceil(NOTE_LIMIT / 40) do
        local line = box:CreateTexture(nil, "BACKGROUND")
        line:SetHeight(1)
        local y = -((i - 1) * NOTE_LINE + NOTE_RULE_AT)
        line:SetPoint("TOPLEFT", 0, y)
        line:SetPoint("TOPRIGHT", 0, y)
        line:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], 0.22)
        box.lines[i] = line
    end

    Style.Placeholder(box, hint or "What happened? What should you remember about them?", true)
        :SetPoint("TOPLEFT", 0, -2)

    -- Clicking anywhere on the ruled area writes there.
    scroll:SetScript("OnMouseDown", function() box:SetFocus() end)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * NOTE_LINE)))
    end)

    -- Keep the cursor in view while writing.
    box:SetScript("OnCursorChanged", function(self, _, y, _, height)
        local offset, view = scroll:GetVerticalScroll(), scroll:GetHeight()
        y = -y
        if y < offset then
            scroll:SetVerticalScroll(y)
        elseif y + height > offset + view then
            scroll:SetVerticalScroll(y + height - view)
        end
    end)

    local function Update(self)
        self:UpdateHint()
        local length = #(self:GetText() or "")
        form.count:SetText(length >= NOTE_WARN and ("%d / %d"):format(length, NOTE_LIMIT) or "")
        scroll:UpdateScrollChildRect()
    end
    box:SetScript("OnTextChanged", Update)
    box:SetScript("OnEditFocusGained", Update)
    box:SetScript("OnEditFocusLost", function(self)
        Update(self)
        if onCommit then onCommit(self:GetText()) end
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    function box:SetValue(text)
        self:SetText(text or "")
        Update(self)
    end

    form.noteScroll = scroll
    return box
end
Entry.RuledNote = BuildNote

-- The editable part of a person's page: tags, relationship, note, and the
-- footer. `width` and `height` are fixed; the tags flow and push the rest.
-- `form.store` is what it writes on: ns.Diary, or a draft (SetPerson).
function Entry.Form(parent, width, height)
    local form = CreateFrame("Frame", nil, parent)
    form:SetSize(width, height)
    form.width = width
    form.store = ns.Diary

    -- A draft is nobody else's business until Done.
    local function Changed()
        if form.onChanged then form.onChanged() end
        form:Refresh()
        if form.store == ns.Diary then ns.Fire("SD_DIARY_CHANGED") end
    end

    -- Writes whatever is typed but not yet committed, so a click elsewhere
    -- on the form cannot lose it.
    function form:CommitText()
        if not self.guid then return end
        if self.relationship:HasFocus() then self.store.SetRelationship(self.guid, self.relationship:GetText()) end
        if self.note:HasFocus() then self.store.SetNote(self.guid, self.note:GetText()) end
    end

    -- Commits and lets go of the keyboard.
    function form:Commit()
        self:CommitText()
        self.addTag:ClearFocus()
        self.relationship:ClearFocus()
        self.note:ClearFocus()
    end

    local function Commit(setter)
        return function(text)
            if not form.guid then return end
            form.store[setter](form.guid, text)
            Changed()
        end
    end

    ----------------------------------------------------------------------
    -- Tags

    form.tagsLabel = Label(form, "Tags")
    form.tagsLabel:SetPoint("TOPLEFT")

    form.chips, form.presets = {}, {}
    for i = 1, MAX_CHIPS do
        local chip = Style.TagButton(form)
        chip:SetScript("OnClick", function(self)
            if not form.guid or self.removable then return end
            form:CommitText()
            form.store.ToggleTag(form.guid, self.tag)
            Changed()
        end)
        chip.cross:SetScript("OnClick", function()
            if not form.guid then return end
            form:CommitText()
            form.store.RemoveTag(form.guid, chip.tag)
            Changed()
        end)
        chip:Hide()
        form.chips[i] = chip
    end

    -- DIA-6 allows custom tags alongside the presets. Enter adds the tag and
    -- keeps the line, for the next one.
    form.addTag = Style.WritingLine(form, 120, FONT.body, "+ add a tag")
    form.addTag:SetScript("OnEnterPressed", function(self)
        local text = self:GetText() or ""
        if form.guid and text:match("%S") then
            form:CommitText()
            form.store.AddTag(form.guid, text)
            self:SetValue("")
            Changed()
        else
            self:ClearFocus()
        end
    end)

    ----------------------------------------------------------------------
    -- Relationship, note

    form.relLabel = Label(form, "Relationship")
    form.relationship = Style.WritingLine(form, width, FONT.note,
        "'leveling buddy', 'weirdo', 'Sulfuras Guy', …", Commit("SetRelationship"))
    form.relationship:SetPoint("TOPLEFT", form.relLabel, "BOTTOMLEFT", 0, -6)

    form.noteLabel = Label(form, "Note")
    form.noteLabel:SetPoint("TOPLEFT", form.relationship, "BOTTOMLEFT", 0, -18)

    form.count = Style.Text(form, FONT.small)
    form.count:SetPoint("BOTTOMRIGHT", 0, 28)
    form.count:SetJustifyH("RIGHT")

    form.note = BuildNote(form, Commit("SetNote"))
    form.noteScroll:SetPoint("TOPLEFT", form.noteLabel, "BOTTOMLEFT", 0, -6)
    form.noteScroll:SetPoint("BOTTOMRIGHT", 0, 44)

    -- Tab walks the three lines.
    form.addTag:SetScript("OnTabPressed", function() form.relationship:SetFocus() end)
    form.relationship:SetScript("OnTabPressed", function() form.note:SetFocus() end)
    form.note:SetScript("OnTabPressed", function() form.addTag:SetFocus() end)

    -- Each line's label over it: the pad's subheading as it stands on one
    -- (UI/Pad/Controls.lua, Pad.Look), as the settings kit stamps its rows.
    form.addTag.group, form.relationship.group, form.noteScroll.group =
        form.tagsLabel, form.relLabel, form.noteLabel
    for _, chip in ipairs(form.chips) do chip.group = form.tagsLabel end

    ----------------------------------------------------------------------
    -- Footer: a quiet way out, and Done. The removal keeps its game pop-up;
    -- on a draft the way out just closes, and Done adds them.

    form.remove = Style.Link(form, FONT.body, function()
        if not form.guid then return end
        form:Commit()
        if form.store ~= ns.Diary then
            if form.onDone then form.onDone() end
            return
        end
        ns.UI.ConfirmRemove(form.guid)
    end)
    form.remove:SetText("Remove from the diary")
    form.remove:SetColor(Style.ACCENT[1], Style.ACCENT[2], Style.ACCENT[3])
    form.remove:SetPoint("BOTTOMLEFT", 0, 2)

    form.done = Style.Link(form, FONT.strong, function()
        form:Commit()
        if form.guid and form.store ~= ns.Diary then
            local _, added = form.store.Save()
            form.store = ns.Diary
            if added then Style.PlaySound("write") end
            ns.Fire("SD_DIARY_CHANGED")
        end
        if form.onDone then form.onDone() end
    end)
    form.done:SetText("Done")
    form.done:SetPoint("BOTTOMRIGHT", 0, 2)

    ----------------------------------------------------------------------
    -- Filling it

    -- Presets first, on or off; then the custom tags, removable; then the
    -- line to add one. Rows wrap at the form's width.
    local function LayoutTags(entry)
        local list = {}
        for _, tag in ipairs(ns.Diary.PRESET_TAGS) do
            list[#list + 1] = { tag, form.store.HasTag(form.guid, tag), false }
        end
        local preset = {}
        for _, tag in ipairs(ns.Diary.PRESET_TAGS) do preset[tag] = true end
        for _, tag in ipairs(entry.tags) do
            if not preset[tag] then list[#list + 1] = { tag, true, true } end
        end

        wipe(form.presets)
        local x, y = 0, -18
        local function Place(widget, w)
            if x > 0 and x + w > width then x, y = 0, y - CHIP_ROW end
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", form, "TOPLEFT", x, y)
            x = x + w + CHIP_GAP
        end

        for i, chip in ipairs(form.chips) do
            local item = list[i]
            if item then
                chip:SetTag(item[1], item[2], item[3])
                chip.removable = item[3]
                if not item[3] then form.presets[item[1]] = chip end
                Place(chip, chip:GetWidth())
                chip:Show()
            else
                chip:Hide()
            end
        end
        Place(form.addTag, form.addTag:GetWidth())

        form.relLabel:ClearAllPoints()
        form.relLabel:SetPoint("TOPLEFT", form, "TOPLEFT", 0, y - 18 - 16)
    end

    function form:Refresh()
        local entry = self.guid and self.store.Get(self.guid)
        if not entry then return end
        LayoutTags(entry)
        -- Never overwrite a line someone is writing on.
        if not self.relationship:HasFocus() then self.relationship:SetValue(entry.relationship) end
        if not self.note:HasFocus() then self.note:SetValue(entry.note) end
    end

    -- `draft`, if any, is written on instead of the diary.
    function form:SetPerson(guid, draft)
        local store = draft or ns.Diary
        if guid ~= self.guid or store ~= self.store then
            self:Commit()
            self.noteScroll:SetVerticalScroll(0)
        end
        self.guid, self.store = guid, store
        self.remove:SetText(draft and "Cancel" or "Remove from the diary")
        self:Refresh()
    end

    form:SetScript("OnHide", function(self) self:Commit() end)

    return form
end

--------------------------------------------------------------------------
-- The loose sheet
--------------------------------------------------------------------------

local function BuildSheet()
    local panel = ns.UI.Chrome.Panel("SocialDiaryEntryFrame", SHEET_W, SHEET_H, nil, { bare = true, closeOutset = 10 })
    Style.EntryPaper(panel)
    Style.Ribbon(panel, SHEET_W - 96, 22, 82)
    ns.On("SD_PAPER_CHANGED", function() panel:ApplyGrain() end)

    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", SHEET_MARGIN, -SHEET_MARGIN)
    content:SetPoint("BOTTOMRIGHT", -SHEET_MARGIN, SHEET_MARGIN)
    local width = SHEET_W - 2 * SHEET_MARGIN

    Style.PersonHeading(panel, content, width, 70)

    panel.meta = Style.Text(content, FONT.small)
    panel.meta:SetPoint("TOPLEFT", panel.who, "BOTTOMLEFT", 0, -6)

    panel.form = Entry.Form(content, width, SHEET_H - 2 * SHEET_MARGIN - 90)
    panel.form:SetPoint("TOPLEFT", 0, -90)
    panel.form.onDone = function() panel:Hide() end
    -- Closed without Done: the draft goes, and nobody was added.
    panel:HookScript("OnHide", function()
        if panel.form.store ~= ns.Diary then panel.form:SetPerson(nil) end
    end)

    return panel
end

local function FillSheet(guid, draft)
    local record = ns.Characters.Get(guid)
    local entry = (draft or ns.Diary).Get(guid)
    Style.SetPersonHeading(sheet, record, ns.Characters.FullName(guid) or guid,
        Format.WhoLine(record, entry.guildAtAdd))
    sheet.meta:SetText(Entry.Meta(guid, draft))
    sheet.form:SetPerson(guid, draft)
end

-- The sheet's draft, when it is showing one.
local function SheetDraft()
    if sheet and sheet:IsShown() and sheet.form.store ~= ns.Diary then return sheet.form.store end
end

--------------------------------------------------------------------------
-- Entry points
--------------------------------------------------------------------------

-- The sheet opened by the player (every way in is theirs: the key, a
-- menu's line, /sd, the picker): it takes the pad while it is shown
-- (UI/Windows/Pad.lua). `toNote`: the note is what they came to write, so it
-- has the cursor; with the pad in hand it waits for A instead (there is no
-- on-screen keyboard to rely on), and the pad lands on it.
function Entry.Opened(toNote)
    local Pad = ns.UI.Pad
    sheet.padNote = toNote and true or nil
    if toNote and not Pad.Input.Active() then sheet.form.note:SetFocus() end
    Pad.Opened(sheet)
end

-- The loose sheet, if it was ever made (the pad's scope).
function Entry.Sheet() return sheet end

-- After an edit from anywhere: whichever form is showing follows it.
function Entry.Refresh()
    local draft = SheetDraft()
    if draft then
        FillSheet(draft.guid, draft)
    elseif sheet and sheet:IsShown() and sheet.form.guid then
        if ns.Diary.Get(sheet.form.guid) then
            FillSheet(sheet.form.guid)
        else
            sheet:Hide()
        end
    end
end

-- Only ever on somebody already in the diary. `focusNote` puts the cursor
-- in the note, for the quick add.
function ns.UI.ShowEntry(guid, focusNote)
    guid = ns.SafeGUID(guid)
    if not guid or not ns.Diary.Get(guid) then return false end

    -- The journal is open: write on its page instead.
    if ns.UI.Journal and ns.UI.Journal.Edit(guid, focusNote) then
        if sheet then sheet:Hide() end
        return true
    end

    sheet = sheet or BuildSheet()
    sheet:Show()
    sheet:Raise()
    FillSheet(guid)
    Entry.Opened(focusNote)

    return true
end

-- Closes the editor wherever it is.
function Entry.Close()
    if sheet then sheet:Hide() end
    if ns.UI.Journal.EndEdit then ns.UI.Journal.EndEdit() end
    ns.Fire("SD_DIARY_CHANGED")
end

-- The two-action path (DIA-4): the page on a draft of them, with the note
-- ready to write in; Done adds them. Always the loose sheet, open journal
-- or not: the book's page is for people in it.
function ns.UI.Remember(guid, opts)
    -- Asked twice: the page already open keeps what was written on it.
    local open = SheetDraft()
    if open and open.guid == ns.SafeGUID(guid) then
        sheet:Raise()
        ns.UI.Pad.Opened(sheet)
        return true
    end

    local draft = ns.Diary.Draft(guid, opts)
    if not draft then
        ns.Print("could not identify that character.")
        return false
    end

    if ns.Diary.IsDiary(draft.guid) then
        ns.Print("|cffffffff%s|r is already in the diary.",
            ns.Characters.FullName(draft.guid) or draft.guid)
        ns.UI.ShowEntry(draft.guid, true)
        return true
    end

    sheet = sheet or BuildSheet()
    sheet:Show()
    sheet:Raise()
    FillSheet(draft.guid, draft)
    Entry.Opened(true)
    return true
end
