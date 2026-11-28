-- The free card on a run's map (.claude/features/dungeon-notes.md; the UI
-- proposal .claude/ui-proposal/dungeon-notes.md §1, variant A, approved 28
-- Nov 2026): the face of a note the player put on the Dungeon View
-- (DungeonPage.RegisterNoteFace, UI/Dungeon/Notes.lua). A paper strip as the
-- detected notes' are, laid by the sheet; what makes it the player's:
--   the icon they picked, painted in the strip's lead room before the
--     heading (the free card's sixteen, Icons.lua, at DungeonPage.OWN.icon);
--   their words, quoted under the heading in their hand (the strip's
--     `quote`), at most OWN.lines lines, cut with an ellipsis.
-- Its heading is what the card is about, as its mark's tooltip says it ("With
-- Old Tom", the creature, the item); a card naming nothing has its words for
-- a heading ("A Divine Intervention saved the run."), and an empty card the
-- icon's name. A creature or item not in the heading goes in the faint line
-- under it. An item in the heading has its own square (its tooltip; no click
-- with the pad), as a loot strip's. The mark of a note not pinned to a boss
-- is the free card's own (Mark.lua's, as on the plates: the user, 28 Nov).

local addonName, ns = ...

local L = ns.L
local Note = ns.Note
local DungeonPage = ns.UI.DungeonPage

-- The card's words on one line (none: nil).
local function Words(rec)
    local text = type(rec.text) == "string" and rec.text:gsub("\n", " ") or ""
    return text ~= "" and text or nil
end

local function Filled(v) return type(v) == "string" and v ~= "" and v or nil end

-- The heading, the faint line, the quote, and an item named in the heading.
local function Said(rec)
    local named = Note.Names(rec)[1] ~= nil
    local mob, item = Filled(rec.mob), Filled(rec.item)
    local words = Words(rec)
    if named or mob or item then
        local title = Note.Tip(rec, ns.Now())
        local rest = {}
        if (named or item) and mob and title ~= mob then rest[#rest + 1] = mob end
        if (named or mob) and item then rest[#rest + 1] = ns.Style.Inkify(item) end
        local heading = title == item and ns.Style.Inkify(item) or title
        local what = rest[2] and ns.Fmt(L["%1$s, %2$s"], rest[1], rest[2]) or rest[1]
        return heading, what, words, title == item and item or nil
    end
    if words then return words, nil, nil, nil end
    return Note.IconName(rec), nil, nil, nil
end

-- The strip's tooltip: the mark's account of it (Text.lua's Note.Tip), and
-- with the mouse, on the player's own run, how to change it.
local function Tip(rec)
    local title, lines = Note.Tip(rec, ns.Now())
    local list = ns.Style.TipList(title, lines)
    if ns.RunNotes.Writable(rec.visit) and not ns.UI.Pad.Input.Active() then
        list[#list + 1] = { DungeonPage.NOTE_WORDS.change, 0.6, 0.6, 0.6, true }
    end
    return list
end

DungeonPage.RegisterNoteFace(Note.KIND, {
    -- A strip whose lead room holds the icon, painted through a mark kit on
    -- the strip's own plane, so it turns with it.
    new = function(host)
        local slot
        local hooks = {
            draw = function(strip)
                local kit = slot and slot.kit
                if not kit then return end
                kit.P = strip:Paper()
                kit:Begin()
                local lead = strip.lead
                if lead and slot.icon then
                    local size = DungeonPage.OWN.icon
                    ns.NoteIcons.Draw(kit, slot.icon, lead.lx - DungeonPage.OWN.iconGap / 2, lead.ly, size)
                end
                kit:Finish()
            end,
        }
        slot = DungeonPage.NewNote(host, hooks)
        local strip = slot.strip
        slot.kit = ns.UI.JourneyPlate.MarkKit(strip, function(region, x, y, w, h, turn) strip:Lay(region, x, y, w, h, turn) end,
            function(region, ...) return strip:Bend(region, ...) end, strip:Paper())
        return slot
    end,
    write = function(slot, rec, note)
        local heading, what, quote, item = Said(rec)
        slot.icon = ns.NoteIcons.Known(rec.icon)
        note.name, note.what, note.quote = heading, what, quote
        note.guid, note.onClick = Note.FirstGuid(rec), function(guid) ns.UI.YourDiary.ToPerson(guid) end
        note.tip = function() return Tip(rec) end
        slot.strip:SetNote(note)
        slot.note = { name = heading,
            items = item and { { item = item, text = heading, from = "", line = nil } } or nil }
    end,
    mark = function(kit, x, y, rec)
        Note.Mark.draw(kit, x, y, nil, rec)
    end,
    tips = function(recs, now) return Note.Tips(recs, now) end,
    -- A menu's line where a mark holds several ("Which one?").
    describe = function(rec) return Note.Describe(rec) end,
})
