-- The free card's form, made easier to read and kinder to write on (19 Nov,
-- the user's picks from the proposal): its rows in three groups, air
-- between (the faint rule there taken out on 26 Nov), Delete on the foot left of Cancel and Save (and the pad's way
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
Section("the rows in three groups, air between and no rule")

do
    local view, rows = Edit(KIND, rec)
    -- (26 Nov, in the client: the short centred rules looked displaced; gone)
    Eq(view.rules, nil, "no rules made")
    Eq(view.ruleAt, nil, "none laid")
    Eq(rows.mob.add.padAt[2] - rows.people.box.padAt[2], BEAT.within, "close within a group")
    Eq(rows.caption.flag.padAt[2] - rows.mob.add.padAt[2], BEAT.between, "apart between two")
    view:Hide()
end

--------------------------------------------------------------------------
Section("the labels' column as wide as its widest label; a hint ends at its line")

do
    local LABEL, SHEET = CardSheet.LABEL, CardSheet.SHEET
    local M = SHEET.margin
    local view, rows = Edit(KIND, rec)
    Eq(view.col, SHEET.label, "short labels: the narrowest column")
    Eq(view.W, SHEET.w, "and the slip as it was")
    local function LineLeft(row) return row.box.padAt[1] - row.box:GetWidth() / 2 end
    -- A longer label (a translation's): the column and the slip widen, the
    -- line keeps its width and starts past the label.
    local label = rows.people.label
    local was = label:GetText()
    label:SetText("QUI ETAIT DONC LA")
    view, rows = Edit(KIND, rec)
    local wide = label:GetUnboundedStringWidth() + 2
    Eq(view.col, wide + LABEL.gap, "the column from the widest label")
    Eq(view.W, 2 * M + view.col + SHEET.line, "the slip as much wider")
    Eq(rows.people.box:GetWidth(), SHEET.line, "the line keeps its width")
    Check(LineLeft(rows.people) >= M + wide + LABEL.gap - 0.01, "the line starts past the label, with air")
    Eq(LineLeft(rows.text), LineLeft(rows.people), "every line on one column")
    -- Longer than the column may be: it wraps inside it.
    label:SetText("LES GENS QUI ETAIENT LA AVEC MOI")
    view, rows = Edit(KIND, rec)
    Eq(view.col, LABEL.most, "the column at its most")
    Eq(label:GetWidth(), LABEL.most - LABEL.gap, "the label held to the column, to wrap")
    Check(LineLeft(rows.people) >= M + LABEL.most - 0.01, "the line still past it")
    label:SetText(was)
    view:Hide()
    view, rows = Edit(KIND, rec)
    Eq(view.W, SHEET.w, "back to the narrowest with the label as it was")
    -- The creature's line: its hint held by both ends of the line, one line
    -- cut short, and the line ending before Remove.
    -- (26 Nov, in the client: "As the game names it" ran under the R of Remove)
    Click(rows.mob.add.link)
    local box, off = rows.mob.box, rows.mob.off
    Eq(box.hint:GetNumPoints(), 2, "the hint held at both ends")
    Eq(select(1, box.hint:GetPoint(1)), "LEFT", "by its left")
    Eq(select(1, box.hint:GetPoint(2)), "RIGHT", "and its right")
    Eq(box.hint.recorded.calls.SetWordWrap[1], false, "on one line, cut short")
    Check(box.padAt[1] + box:GetWidth() / 2 <= off.padAt[1] - off:GetWidth() / 2,
        "the line ends before Remove begins")
    Check(off.padAt[1] + off:GetWidth() / 2 <= view.W - M + 4.01, "Remove inside the margin (its button 2 px past its words)")
    local items = rows.item
    Click(items.add.link)
    Check(items.box.padAt[1] + items.box:GetWidth() / 2 <= items.off.padAt[1] - items.off:GetWidth() / 2,
        "the item's line too")
    Eq(items.box.hint:GetNumPoints(), 2, "and its hint held")
    Eq(rows.people.box.hint:GetNumPoints(), 2, "who was there's hint held too")
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
    Eq(view.W, CardSheet.SHEET.w, "its slip as wide as ever")
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

--------------------------------------------------------------------------
Section("the card's item: boxed on XL and L, its icon alone on M and S")

do
    mock.pad.ui, mock.pad.enabled, mock.pad.devices = false, false, {}
    mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
    mock.itemInfo[4242] = { icon = 5005, quality = 3 }
    local FREE = ns.Note.Card.FREE
    local ItemBox = ns.UI.ItemBox
    local card = ns.Deaths.Card.New(UIParent)
    local with = { t = now, icon = "chest", text = "Cool thing looted!", item = "Dark Leather Boots", itemID = 4242 }
    local function Lay(r, width, room)
        card:SetNoteCard(r, { 300, 200 }, "item-test", now, function() end)
        return card:Layout(0, 0, width, room)
    end
    local function Bits() return card.freeBits end
    local function Small() return Bits().small end
    local pad = { card:Pad() }
    -- XL and L: the box under the name, no icon before it.
    for _, width in ipairs({ 220, 176 }) do
        Lay(with, width)
        Check(Bits().box.button:IsShown(), width .. ": the item boxed")
        Check(not Small().icon:IsShown(), width .. ": no icon alone")
        Eq(card.lead, nil, width .. ": nothing kept before the heading")
        Check(not card.overfull, width .. ": it fits")
    end
    -- M and the narrowest: the icon alone before the heading, no box.
    for _, width in ipairs({ 142, 122 }) do
        local W = Lay(with, width)
        Eq(card.freeSize, "m", width .. ": M")
        Check(not Bits().box.button:IsShown(), width .. ": no box")
        Check(Small().icon:IsShown() and Small().edge:IsShown() and Small().button:IsShown(), width .. ": its icon")
        Eq(Small().icon.recorded.calls.SetTexture[1], 5005, width .. ": the item's own")
        local E = ItemBox.Edge(3)
        local painted = Small().edge.recorded.calls.SetColorTexture
        Check(math.abs(painted[1] - E[1]) < 1e-6 and math.abs(painted[3] - E[3]) < 1e-6, width .. ": edged in its quality's colour")
        Eq(card.lead and card.lead.w, FREE.small.icon + 2 + FREE.small.gap, width .. ": room kept before the heading")
        Eq(card.nameBox[1], -W / 2 + pad[1] + card.lead.w, width .. ": the heading moved past it")
        Check(not card.overfull, width .. ": it fits")
    end
    -- Under the mouse: the item's own tooltip; never a click.
    Lay(with, 142)
    GameTooltip.link, GameTooltip.shown = nil, nil
    Small().button:GetScript("OnEnter")(Small().button)
    Check(GameTooltip.shown and GameTooltip.link == "item:4242", "the item's own tooltip over its icon")
    Small().button:GetScript("OnLeave")(Small().button)
    Check(not GameTooltip.shown, "and gone off it")
    Eq(Small().button:GetScript("OnClick"), nil, "an item is never clicked")
    -- Short of height on XL: the box given up, its icon before the heading.
    Lay(with, 220)
    local n = 0
    while Bits().box.button:IsShown() and card:Smaller() and n < 10 do
        n = n + 1
        card:Layout(0, 0, 220)
    end
    Check(not Bits().box.button:IsShown() and Small().icon:IsShown(), "the box given up: the icon kept")
    -- At S (the band given up): still the icon.
    while card:Smaller() and n < 20 do
        n = n + 1
        card:Layout(0, 0, 220)
    end
    Check(card.freeIcon == nil, "setup: the band given up")
    Check(Small().icon:IsShown(), "S: the item's icon before the heading")
    -- A name only typed (no icon the client knows): the box at M, as before.
    local typed = { t = now, icon = "chest", text = "Cool thing looted!", item = "Dark Leather Boots" }
    Lay(typed, 142)
    Check(Bits().box.button:IsShown() and not Small().icon:IsShown(), "a typed item keeps its box at M")
    Eq(card.lead, nil, "and nothing before the heading")
    -- No item: as it was.
    local none = { t = now, icon = "chest", text = "Cool thing looted!" }
    for _, width in ipairs({ 220, 176, 142, 122 }) do
        local W = Lay(none, width)
        Check(not Bits().box.button:IsShown() and not Small().icon:IsShown(), width .. ": no item, nothing of one")
        Eq(card.lead, nil, width .. ": nothing before the heading")
        Eq(card.nameBox[1], -W / 2 + pad[1], width .. ": the heading at the margin")
    end
    -- A killer's card after: nothing of the item left on it.
    Lay(with, 142)
    card:SetKiller({ name = "Kobold Miner", count = 1, last = now }, "k", now)
    card:Layout(0, 0, 142)
    Check(not Small().icon:IsShown() and not Small().button:IsShown(), "a killer's card has no item icon")
end

--------------------------------------------------------------------------
Section("the card beside the form: its item shown, and inert")

do
    local boots = Custom.Insert(KIND, { text = "Cool thing looted!", item = "Dark Leather Boots", itemID = 4242,
        icon = "chest" }, WHERE)
    local view = Edit(KIND, boots)
    local card = view.preview.cards[KIND]
    Check(view.preview:IsShown() and card:IsShown(), "setup: the card beside the form")
    Check(card.freeBits.box.button:IsShown(), "its item boxed (L)")
    Check(not card.freeBits.box.button:IsMouseClickEnabled(), "the box takes no mouse")
    Check(not card.freeBits.small.button:IsMouseClickEnabled(), "nor the icon")
    Check(not card.link:IsMouseClickEnabled(), "nor the name")
    view:Hide()
    Custom.Remove(boots)
end

--------------------------------------------------------------------------
Section("the creature's line taken from the target")

do
    -- (with the mouse: the line added takes the cursor after it is filled)
    mock.pad.ui, mock.pad.enabled, mock.pad.devices = false, false, {}
    mock.fire("GAME_PAD_ACTIVE_CHANGED", false)
    local VERMIN = "Creature-0-1-2-3-3100-0000000001"
    local NPC = { guid = VERMIN, name = { "Kobold Vermin" }, isPlayer = false, hostile = true }
    mock.creatureDisplays[3100] = 4711
    local function Target(def)
        mock.SetUnit("target", def)
        mock.fire("PLAYER_TARGET_CHANGED")
    end
    local function Fresh()
        local view, rows = Edit(KIND, rec)
        if rows.mob.on then Click(rows.mob.off) end
        return view, rows
    end

    -- An NPC targeted: the line added from its strip is its name.
    mock.SetUnit("target", NPC)
    local view, rows = Fresh()
    Click(rows.mob.add.link)
    Eq(rows.mob:Get(), "Kobold Vermin", "the target's name on the line added")
    Check(view.watch.events.PLAYER_TARGET_CHANGED, "the target watched while the form is open")
    Eq(view.preview.rec.npcID, 3100, "its npcID from the target, though no record knows it")
    for _ = 1, 3 do mock.RunTimers() end
    Eq(view.preview.rec.display, 4711, "and its picture, once read")
    -- The cursor on it (the mouse's way): a retarget still replaces the
    -- target's name, with the new creature's npcID and picture.
    -- (26 Nov, in the client: "It should update on a retarget.")
    Check(rows.mob.box:HasFocus(), "setup: the line has the cursor")
    mock.creatureDisplays[3101] = 4712
    local WORKER = { guid = "Creature-0-1-2-3-3101-0000000002", name = { "Kobold Worker" }, isPlayer = false }
    Target(WORKER)
    Eq(rows.mob:Get(), "Kobold Worker", "a retarget replaces the target's name, the cursor in the line")
    Check(rows.mob.box:HasFocus(), "the cursor kept")
    Eq(view.preview.rec.npcID, 3101, "the new creature's npcID")
    Eq(view.preview.rec.display, nil, "the old picture gone till the new one is read")
    for _ = 1, 3 do mock.RunTimers() end
    Eq(view.preview.rec.display, 4712, "the new creature's picture")
    -- A player, a pet or no target: the name stays.
    Target({ guid = "Player-1-0000AAAA", name = { "Wenna" }, isPlayer = true })
    Eq(rows.mob:Get(), "Kobold Worker", "a player targeted: as it was")
    Target(nil)
    Eq(rows.mob:Get(), "Kobold Worker", "the target cleared: as it was")
    -- Something typed is never written over.
    Type(rows.mob.box, "Plainstrider")
    Target(NPC)
    Eq(rows.mob:Get(), "Plainstrider", "what was typed stays")
    -- Emptied by hand with the cursor in it: left for typing.
    Type(rows.mob.box, "")
    Target(WORKER)
    Eq(rows.mob:Get(), "", "an empty line being written on is not touched")
    -- Let go, empty: a new target fills it.
    rows.mob.box:ClearFocus()
    Target(NPC)
    Eq(rows.mob:Get(), "Kobold Vermin", "an empty line filled as the target changes")
    view:Hide()
    Check(not view.watch.events.PLAYER_TARGET_CHANGED, "the target not watched once the form is put away")

    -- A player targeted: nothing.
    mock.SetUnit("target", { guid = "Player-1-0000AAAA", name = { "Wenna" }, isPlayer = true })
    view, rows = Fresh()
    Click(rows.mob.add.link)
    Eq(rows.mob:Get(), "", "no player's name")
    view:Hide()

    -- A pet or a minion (player controlled): nothing. (UnitPlayerControlled
    -- set here alone, so no other test's code finds it.)
    _G.UnitPlayerControlled = function(token) return token == "target" end
    mock.SetUnit("target", { guid = "Pet-0-1-2-3-416-0000000003", name = { "Grubthak" }, isPlayer = false })
    view, rows = Fresh()
    Click(rows.mob.add.link)
    Eq(rows.mob:Get(), "", "no pet's name")
    view:Hide()
    mock.SetUnit("target", { guid = "Creature-0-1-2-3-3573-0000000004", name = { "Mana Spring Totem" }, isPlayer = false })
    view, rows = Fresh()
    Click(rows.mob.add.link)
    Eq(rows.mob:Get(), "", "nor a totem's")
    view:Hide()
    _G.UnitPlayerControlled = nil

    -- A secret name (identity restricted): nothing, and no error.
    mock.SetUnit("target", { guid = VERMIN, name = mock.secret("Kobold Vermin"), isPlayer = false })
    view, rows = Fresh()
    Click(rows.mob.add.link)
    Eq(rows.mob:Get(), "", "no secret name")
    view:Hide()

    -- A creature already saved on the card is never written over, nor is a
    -- line not added (its strip stays a strip).
    local fought = Custom.Insert(KIND, { text = "by the shore", mob = "Murloc Forager" }, WHERE)
    view, rows = Edit(KIND, fought)
    Check(rows.mob.on, "setup: the saved creature's line on")
    Target(NPC)
    Eq(rows.mob:Get(), "Murloc Forager", "the saved creature stays")
    rows.mob.box:SetFocus()
    Target({ guid = "Creature-0-1-2-3-3101-0000000002", name = { "Kobold Worker" }, isPlayer = false })
    Eq(rows.mob:Get(), "Murloc Forager", "with the cursor in it too")
    view:Hide()
    view, rows = Fresh()
    Target(NPC)
    Check(not rows.mob.on and rows.mob:Get() == "", "a line not added is not added by the target")
    view:Hide()
    Custom.Remove(fought)

    -- The pad: A on the strip fills it the same way.
    mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
    mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
    local catcher = Pad.Catcher(ns.UI.JournalFrame())
    mock.SetUnit("target", NPC)
    view, rows = Fresh()
    Pad.Refresh()
    local scope = Pad.Top()
    scope.focus:Focus("more:mob", "form")
    mock.PadPress(catcher, "PAD1", true)
    mock.PadPress(catcher, "PAD1", false)
    Check(rows.mob.on, "A added the creature's line")
    Eq(rows.mob:Get(), "Kobold Vermin", "with the target's name: the pad's way to one")
    Check(not rows.mob.box:HasFocus(), "and no cursor till A")
    Target({ guid = "Creature-0-1-2-3-3101-0000000002", name = { "Kobold Worker" }, isPlayer = false })
    Eq(rows.mob:Get(), "Kobold Worker", "a retarget follows with the pad too")
    view:Hide()
    mock.SetUnit("target", nil)
end
