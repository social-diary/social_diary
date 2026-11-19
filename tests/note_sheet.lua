-- The free card's form, made easier to read and kinder to write on (19 Nov,
-- the user's picks from the proposal): its rows in three groups with a faint
-- rule between, Delete on the foot left of Cancel and Save (and the pad's way
-- along it: Delete, Cancel, Save, landing on Save), the card beside the form
-- written again as it changes, the chosen icon in full ink on a wash with the
-- rest dimmed (and given back when put away), its sounds, a face just added
-- coming up from nothing. A kind with no groups and no preview is laid as it
-- was.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Custom, Recap, J = ns.Custom, ns.JourneyRecap, ns.Journey
local Pad = ns.UI.Pad
local KIND = "noteCard"

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

local t0 = now - 7200
local MAP = 1412
J.Begin(ns.ownGUID, t0, 10, MAP)
local j = J.Mine()
j.segments = { { kind = "stop", from = t0, to = t0 + 3000, mapID = MAP, x = 0.40, y = 0.60, r = 30, seconds = 3000,
    levelFrom = 10, levelTo = 10 } }
j.open = nil
j.levels[11] = { at = t0 + 3500, mapID = MAP, x = 0.40, y = 0.60 }
J.Touch()

local WHERE = { mapID = MAP, x = 0.42, y = 0.58, from = t0, to = t0 + 3000 }

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local YourDiary = ns.UI.YourDiary
local CardSheet = YourDiary.CardSheet
local BEAT, ICONS, PREVIEW, FACES = CardSheet.BEAT, CardSheet.ICONS, CardSheet.PREVIEW, CardSheet.FACES
ns.UI.RefreshJourneyPage(true)
for i, e in ipairs(page.recap.entries) do
    if e.level == 10 then T.OpenDiaryPage(page, i) end
end

local function Gathered(rec)
    local e = Recap.Gather(j, t0, now, Recap.Context(ns.ownGUID, now))
    for _, list in pairs(e) do
        if type(list) == "table" then
            for _, c in ipairs(list) do
                if type(c) == "table" and c.customOf == rec then return c end
            end
        end
    end
end
local function Rows()
    local rows = {}
    for _, row in ipairs(CardSheet.View().rows) do rows[row.field.key] = row end
    return rows
end
local function Edit(kind, rec)
    CardSheet.Edit(kind, Gathered(rec) or rec)
    return CardSheet.View(), Rows()
end
local function Click(button) button:GetScript("OnClick")(button) end
local function Type(box, text)
    box:SetFocus()
    box:SetText(text)
    box:GetScript("OnTextChanged")(box, true)
end
local function Played(name)
    for _, s in ipairs(mock.sounds) do
        if s[1] == SOUNDKIT[name] then return true end
    end
    return false
end

local rec = Custom.Insert(KIND, { text = "at the pier" }, WHERE)
Check(rec ~= nil, "setup: a free card written")

--------------------------------------------------------------------------
Section("the rows in three groups, a faint rule between")

do
    local view, rows = Edit(KIND, rec)
    Eq(#view.ruleAt, 2, "two rules: between what, who and the page")
    for i = 1, 2 do Check(view.rules[i]:IsShown(), "rule " .. i .. " shown") end
    -- (the text's ruled area: its middle's padAt, its rows' height)
    local textFoot = rows.text.scroll.padAt[2] + rows.text.shown * CardSheet.WRITE.pitch / 2
    Check(view.ruleAt[1] > textFoot and view.ruleAt[1] < rows.people.box.padAt[2] - 10,
        "the first rule in the air between the words and who was there")
    Check(view.ruleAt[2] > rows.mob.add.padAt[2] + 11 and view.ruleAt[2] < rows.caption.flag.padAt[2],
        "the second between the strips and the caption's box")
    Eq(rows.mob.add.padAt[2] - rows.people.box.padAt[2], BEAT.within, "close within a group")
    Eq(rows.caption.flag.padAt[2] - rows.mob.add.padAt[2], BEAT.between, "apart between two")
    view:Hide()
end

--------------------------------------------------------------------------
Section("Delete on the foot, left; Cancel and Save right")

do
    local view = Edit(KIND, rec)
    Check(view.remove:IsShown(), "an inserted card can be deleted")
    Eq(view.remove.padAt[2], view.save.padAt[2], "Delete on the foot's line")
    Check(view.remove.padAt[1] < view.cancel.padAt[1] and view.cancel.padAt[1] < view.save.padAt[1],
        "Delete left, then Cancel, then Save")
    Check(view.save.padAt[2] - Rows().caption.flag.padAt[2] < CardSheet.BEAT.between + 40,
        "no row of links of its own over the foot")
    view:Hide()
end

--------------------------------------------------------------------------
Section("a kind with no groups and no preview: laid as it was")

do
    local close = Custom.Insert("close", { name = "Old Tom", pct = 5 }, WHERE)
    Check(close ~= nil, "setup: a close call written")
    local view, rows = Edit("close", close)
    Eq(view.kind, "close", "setup: its form")
    Eq(#view.ruleAt, 0, "no rules")
    for _, rule in ipairs(view.rules) do Check(not rule:IsShown(), "no rule left from the free card") end
    Check(not view.preview:IsShown(), "no card beside it")
    Eq(rows.foeLevel.box.padAt[2] - rows.name.box.padAt[2], 30, "its rows a row apart, as ever")
    Eq(view.remove.padAt[2], view.save.padAt[2], "its Delete on the foot too")
    view:Hide()
    Custom.Remove(close)
end

--------------------------------------------------------------------------
Section("the card beside the form, written again as it changes")

do
    local view, rows = Edit(KIND, rec)
    local holder = view.preview
    Check(holder:IsShown(), "the card beside the form")
    local card = holder.cards[KIND]
    Check(card ~= nil and card:IsShown(), "the margin's own card")
    Eq(card.face ~= nil and card.freeRec ~= nil, true, "worn with the free card's face")
    Eq(holder.rec.text, "at the pier", "written from what the form holds")
    Eq(card.box[3] <= PREVIEW.w, true, "at the preview's width")
    Check(holder:GetParent() == view and holder:GetParent() ~= view.sheet, "on the view, not the slip")
    Check(not card.link:IsMouseClickEnabled(), "its name opens nothing")
    -- The words.
    Type(rows.text.box, "fished all evening")
    Eq(holder.rec.text, "fished all evening", "the words, as written")
    Eq(card.freeRec.text, "fished all evening", "on the card")
    -- The icon.
    local key = ns.NoteIcons.KEYS[3]
    Click(rows.icon.cells[3])
    Eq(holder.rec.icon, key, "the icon chosen")
    Eq(card.freeIcon and card.freeIcon.key, key, "drawn on the card")
    -- Who was there.
    Type(rows.people.box, "Old Tom")
    rows.people.box:GetScript("OnEnterPressed")(rows.people.box)
    Eq(holder.rec.people and holder.rec.people[1].name, "Old Tom", "someone added")
    Eq(card.name:GetText(), "with Old Tom", "the card's heading names them")
    Click(rows.people.faces[1].cross)
    Eq(holder.rec.people, nil, "taken off again")
    -- The creature: added and written, taken off.
    Click(rows.mob.add.link)
    Type(rows.mob.box, "Murloc Forager")
    Eq(holder.rec.mob, "Murloc Forager", "the creature")
    Click(rows.mob.off)
    Eq(holder.rec.mob, nil, "taken off")
    -- Nothing written by any of it.
    Eq(rec.text, "at the pier", "the card itself untouched")
    -- Cancelled: put away with the form; the picker has none.
    Click(view.cancel)
    Check(not holder:IsShown(), "put away with the form")
end

--------------------------------------------------------------------------
Section("the chosen icon in full ink, the rest dimmed, given back")

do
    local view, rows = Edit(KIND, rec)
    local chosen = rows.icon:Get()
    for _, cell in ipairs(rows.icon.cells) do
        local on = cell.iconKey == chosen
        Eq(cell.picture:GetAlpha(), on and 1 or ICONS.dim, "icon " .. cell.iconKey .. "'s ink")
        Eq(cell.chosen:IsShown(), on, "icon " .. cell.iconKey .. "'s wash")
    end
    view:Hide()
    for _, cell in ipairs(rows.icon.cells) do
        Eq(cell.picture:GetAlpha(), 1, "put away: " .. cell.iconKey .. " in full ink")
        Check(not cell.chosen:IsShown(), "put away: no wash on " .. cell.iconKey)
    end
    view, rows = Edit(KIND, rec)
    Eq(rows.icon.cells[2].picture:GetAlpha(), rows.icon:Get() == rows.icon.cells[2].iconKey and 1 or ICONS.dim,
        "opened again: dimmed again")
    view:Hide()
end

--------------------------------------------------------------------------
Section("sounds: the pen, a slip laid, the card torn up")

do
    local view, rows = Edit(KIND, rec)
    mock.sounds = {}
    local other = rows.icon:Get() == rows.icon.cells[1].iconKey and rows.icon.cells[2] or rows.icon.cells[1]
    Click(other)
    Check(Played("IG_WRITE_QUEST"), "an icon chosen: the pen")
    mock.sounds = {}
    Click(other)
    Eq(#mock.sounds, 0, "the same again: nothing")
    Type(rows.people.box, "Wenna")
    rows.people.box:GetScript("OnEnterPressed")(rows.people.box)
    Check(Played("IG_QUEST_LIST_OPEN"), "a face added: a slip laid")
    mock.sounds = {}
    Click(rows.item.add.link)
    Check(Played("IG_QUEST_LIST_OPEN"), "a field added from its strip: the same")
    -- Deleted: torn up, and no sheet's rustle after.
    mock.sounds = {}
    Click(view.remove)
    mock.AnswerPopup("accept")
    Check(Played("IG_BACKPACK_OPEN"), "deleted: the tear")
    Check(not Played("IG_QUEST_LOG_CLOSE"), "not the sheet put away as well")
    Check(not view:IsShown(), "the form put away")
    rec = Custom.Insert(KIND, { text = "at the pier" }, WHERE)
end

--------------------------------------------------------------------------
Section("a face just added comes up from nothing")

do
    local view, rows = Edit(KIND, rec)
    Type(rows.people.box, "Old Tom")
    rows.people.box:GetScript("OnEnterPressed")(rows.people.box)
    local face = rows.people.faces[1]
    Eq(face:GetAlpha(), 0, "first unseen")
    Eq(face.name:GetAlpha(), 0, "its name too")
    Check(view.fader:IsShown(), "coming up")
    Eq(face.cross:GetAlpha(), 1, "its cross as ever (it comes up with its face)")
    view.fader:GetScript("OnUpdate")(view.fader, FACES.fade / 2)
    local half = face:GetAlpha()
    Check(half > 0.5 and half < 1, "eased out: more than half way at half the time")
    view.fader:GetScript("OnUpdate")(view.fader, FACES.fade)
    Eq(face:GetAlpha(), 1, "then whole")
    Check(not view.fader:IsShown(), "and done")
    -- A second, put away mid-way: whole again.
    Type(rows.people.box, "Wenna")
    rows.people.box:GetScript("OnEnterPressed")(rows.people.box)
    Eq(rows.people.faces[2]:GetAlpha(), 0, "the next unseen")
    Eq(face:GetAlpha(), 1, "the first stays whole")
    view:Hide()
    Eq(rows.people.faces[2]:GetAlpha(), 1, "put away mid-way: whole")
end

--------------------------------------------------------------------------
Section("the pad: Delete, Cancel, Save along the foot, landing on Save")

do
    mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
    mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
    Check(Pad.Input.Active(), "setup: the pad in hand")
    local book = ns.UI.JournalFrame()
    local catcher = Pad.Catcher(book)
    local function Press(key)
        local went = mock.PadPress(catcher, key, true)
        mock.PadPress(catcher, key, false)
        return went
    end
    local view = Edit(KIND, rec)
    Pad.Refresh()
    local scope = Pad.Top()
    Eq(scope.key, "cards", "setup: the slip's scope")
    local function At() return scope.focus:Current() end
    local keys = {}
    for _, item in ipairs(scope.focus.groups.form.items) do keys[#keys + 1] = item.key end
    local order = table.concat(keys, " ")
    Check(order:find("tick:caption link:Delete this card link:Cancel link:Save$") ~= nil,
        "the foot last, Delete, Cancel, Save: " .. order)
    for _, item in ipairs(scope.focus.groups.form.items) do
        local f = item.frame
        while f do
            Check(f ~= view.preview, "the card beside the form is not a control: " .. item.key)
            f = f:GetParent()
        end
    end
    scope.focus:Focus("tick:caption", "form")
    Press("PADDDOWN")
    Eq(At().key, "link:Save", "down onto the foot lands on Save")
    Press("PADDDOWN")
    Eq(At().key, "link:Save", "and stays there")
    Press("PADDLEFT")
    Eq(At().key, "link:Cancel", "left: Cancel")
    Press("PADDLEFT")
    Eq(At().key, "link:Delete this card", "left again: Delete")
    Press("PADDLEFT")
    Eq(At().key, "link:Delete this card", "the foot's end")
    Press("PADDRIGHT")
    Eq(At().key, "link:Cancel", "right: Cancel")
    Press("PADDUP")
    Eq(At().key, "tick:caption", "up off the foot: the control over it")
    -- The icons: the ring is the pad's only mark, the dimming as with the mouse.
    scope.focus:Focus("icon:" .. ns.NoteIcons.KEYS[5], "form")
    Eq(At().key, "icon:" .. ns.NoteIcons.KEYS[5], "setup: on an icon")
    Press("PAD1")
    Eq(Rows().icon:Get(), ns.NoteIcons.KEYS[5], "A chooses it")
    Eq(Rows().icon.cells[5].picture:GetAlpha(), 1, "in full ink")
    Eq(Rows().icon.cells[1].picture:GetAlpha(), ICONS.dim, "the others dimmed")
    Press("PAD2")
    Check(not view:IsShown(), "B puts it away")
    Eq(CardSheet.View().rowsOf[KIND][1].cells[1].picture:GetAlpha(), 1, "every icon given back")
    Eq(rec.icon, ns.NoteIcons.KEYS[1], "nothing written")
end
