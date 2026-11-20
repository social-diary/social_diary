-- The free card, on the map: see Kind.lua.

local addonName, ns = ...

local Note = ns.Note
local Plate = ns.UI.JourneyPlate
local MARK = Plate.MARK

-- The card's own icon (ns.NoteIcons, Icons.lua), the record's choice, or the
-- first where there is none (the picker draws without a record); the core's
-- ring for time together where the icons are not there. Order
-- 36, as "Someone you met" had: after the close call (30) and before the
-- luck (40). Its marks are kept for the strips' leaders, not joined to
-- plate.people: that would make a second, automatic strip with no moments.
-- Its room and halo are the icons' own (Icons.MARK), the ring's without them.
local ICON = ns.NoteIcons and ns.NoteIcons.MARK or {}
Plate.RegisterMark(Note.KIND, {
    order = 36, cap = 20, count = "noteCards",
    radius = ICON.radius or MARK.together / 2 + 1, halo = ICON.halo or MARK.together + 4,
    tip = function(m, now) return Note.Tip(m.noteCard, now) end,
    -- A row of the ticklist (Text.lua's Note.Label).
    label = function(rec, m) return Note.Label(rec or m.noteCard) end,
    -- Every card on the spot in one account (Text.lua's Note.Tips).
    tips = function(list, now)
        local recs = {}
        for _, m in ipairs(list) do recs[#recs + 1] = m.noteCard end
        return Note.Tips(recs, now)
    end,
    keep = "noteCardMarks",
    draw = function(kit, x, y, _, rec)
        local icons = ns.NoteIcons
        if icons and icons.Draw then
            icons.Draw(kit, rec and rec.icon, x, y)
        else
            Plate.SHAPE.session(kit, x, y)
        end
    end,
})
