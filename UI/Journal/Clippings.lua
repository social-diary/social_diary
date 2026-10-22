-- The top of a person's list (the person-page proposal, variant A,
-- "Clippings"): what the summary paragraph used to say, as things glued
-- and taped onto the page, in one tall line of the list that scrolls away
-- with the timeline under it (and slides under the clipped name sheet,
-- UI/Journal/Header.lua, as it goes):
--   the plate      where something with them happened (UI/Journal/
--                  PersonPlate.lua), glued in with photo corners; none
--                  where nothing of them can be placed
--   the facts      a column of taped strips beside it (UI/Journal/
--                  Strips.lua, words UI/Words/Person.lua): when you first
--                  met, with a pencil leader to the meeting's ring; how
--                  often and how long, its tally drawn beside the number;
--                  their level then struck through and now written beside
--                  it, only where it changed
--   your note      a slip pasted over the plate's corner, in your hand
-- One block of frames, made once: the line that shows it (the list's
-- first) holds it (Hold) and lets it go when handed another (Let), so it
-- costs one plate and four strips however the list scrolls. Laid when the
-- person or their diary changes (Fill), not as it scrolls.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local Strips = ns.UI.PersonStrips
local PersonText = ns.UI.PersonText

local Clippings = {}
ns.UI.Clippings = Clippings

-- The block (x, y from its top left, which is `pad` px under its line's
-- top: the line starts behind the name sheet, its first writing at the
-- sheet's foot; UI/Journal/Header.lua's SHEET.first - SHEET.listTop):
--   column   the facts' strips with a plate: from `x`, each `step` px
--            further in than the one above (a hand's stagger), `gap` px
--            apart, the first `top` px down. Each is as wide as its words
--            measure: one that will not fit before `right` (the list's
--            row, clear of its scrollbar) moves left to make room, as far
--            as `least` (over the plate's right margin, short of its
--            picture), and only then takes a shorter form or wraps
--   alone    the same column without a plate, from the page's left,
--            ending at `right`, clear of the note beside it
--   note     your note's slip: with a plate over its bottom right corner
--            at x, y, as wide as its words up to `right`, turned `tilt`
--            degrees (with the clock); without one beside the facts at
--            `aloneX`
--   foot     the gap under the lowest piece before the timeline
--   width    the block's own width (the list's, less its scrollbar)
--   level    how far over the plate the strips lie (frame levels)
-- (20 Oct, in the client: at a fixed 174 px "First met 11 October" ran to
-- its strip's edge; strips are now sized from their words.)
local BLOCK = {
    pad = 35, width = 458, foot = 10, level = 20,
    column = { x = 284, step = 12, gap = 11, top = 10, right = 452, least = 246 },
    alone = { x = 16, right = 204 },
    note = { x = 214, y = 158, tilt = -1.3, most = 6, aloneX = 214, aloneY = 14 },
}
Clippings.BLOCK = BLOCK

-- The block on `list` (the person's timeline); `open()` opens the map
-- sheet (a click on the plate).
function Clippings.New(list, open)
    local frame = CreateFrame("Frame", nil, list)
    frame:SetSize(BLOCK.width, 1)
    frame:SetFrameLevel(list:GetFrameLevel() + 4)
    frame:Hide()
    local block = { frame = frame }

    block.plate = ns.UI.PersonPlate.New(frame, open)
    local function Over(strip)
        strip:SetFrameLevel(frame:GetFrameLevel() + BLOCK.level)
        return strip
    end
    block.first = Over(Strips.Fact(frame))
    block.tally = Over(Strips.Fact(frame))
    block.level = Over(Strips.Level(frame))
    block.note = Over(Strips.Written(frame))

    -- Lays it for the person `s` (ns.People.Stats) and returns the line's
    -- height. The same person and the same diary lay it once.
    function block:Fill(s, now)
        now = now or ns.Now()
        local key = table.concat({ s.guid, ns.dataVersion or 0, ns.Journey.version or 0, ns.seenVersion or 0,
            tostring(ns.Setting("flatSheets") == true), ns.DayStart(now) }, ":")
        if self.key == key and self.height then return self.height end
        self.key = key

        local pick = ns.PersonPlate.For(s.guid)
        local plated = self.plate:DrawFor(pick, s, now)
        local C = BLOCK.column
        local from = plated and C.x or BLOCK.alone.x
        local least = plated and C.least or BLOCK.alone.x
        local right = plated and C.right or BLOCK.alone.right
        local y, bottom, laid = C.top, 0, 0
        -- Lays a strip as wide as its words: measured first with all the
        -- room it may have, then where it fits, its stagger kept where it
        -- can be.
        local function Fit(strip)
            local x = from + laid * C.step
            local w = strip:Layout(least, y, right - least)
            x = math.max(least, math.min(x, right - w))
            strip:Layout(x, y, right - x)
        end
        local function Next(strip)
            local _, _, _, h = unpack(strip.box)
            y = y + h + C.gap
            bottom = math.max(bottom, strip.box[2] + h)
            laid = laid + 1
        end

        -- When you first met (or were added), and at what level.
        local heading, short, sub = PersonText.FirstMet(s, now)
        self.first:SetNote({ name = heading, short = short, what = sub, strong = true, seed = s.guid .. ":first",
            tip = PersonText.FirstMetTip(s, now) and function()
                return Style.TipList(PersonText.FirstMetTip(s, ns.Now()))
            end or nil })
        Fit(self.first)
        Next(self.first)
        self.plate:Lead(plated and self.first or nil)

        -- How often and how long, its tooltip with when you last met and
        -- where they were last seen.
        local met, strokes, together = PersonText.Tally(s)
        if met then
            self.tally:SetNote({ name = met, what = together, gates = strokes, strong = true, seed = s.guid .. ":tally",
                tip = function() return Style.TipList(PersonText.TallyTip(s, ns.Now())) end })
            Fit(self.tally)
            Next(self.tally)
        else
            self.tally:Hide()
        end

        -- Their level then and now, where it changed.
        local before, after = PersonText.Level(s)
        if before then
            self.level:SetNote({ level = { before, after }, seed = s.guid .. ":level",
                tip = function() return Style.TipList(PersonText.LevelTip(s)) end })
            Fit(self.level)
            Next(self.level)
        else
            self.level:Hide()
        end

        -- Your note, over the plate's corner (or beside the facts).
        local N = BLOCK.note
        local note = s.entry.note
        local text = note and ns.UI.JourneyText.Written(note) or PersonText.NO_NOTE
        self.note:SetNote({ text = text, font = note and FONT.noteWritten or FONT.faded, most = N.most,
            tilt = not (ns.Setting("flatSheets") == true) and N.tilt or nil, seed = s.guid .. ":note",
            tip = note and function()
                if not self.note.cut then return nil end
                return Style.TipList("Your note", { ns.UI.JourneyText.Written(note) })
            end or nil })
        -- (Under the facts where they grew down past its place.)
        local nx, ny = plated and N.x or N.aloneX, plated and math.max(N.y, y) or N.aloneY
        self.note:Layout(nx, ny, C.right - nx)
        bottom = math.max(bottom, ny + self.note.box[4])
        if plated then bottom = math.max(bottom, ns.UI.PersonPlate.SLOT.y + ns.UI.PersonPlate.SLOT.h) end

        local height = math.ceil(bottom + BLOCK.foot)
        frame:SetSize(BLOCK.width, height)
        self.height = BLOCK.pad + height
        self.plated = plated
        return self.height
    end

    -- Shown on `row`, the list's line that holds it.
    function block:Hold(row)
        self.row = row
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -BLOCK.pad)
        frame:Show()
    end
    -- `row` was handed another line: put away if it held it.
    function block:Let(row)
        if self.row == row then
            self.row = nil
            frame:Hide()
        end
    end
    -- Laid again next time (the diary changed under the same key).
    function block:Forget() self.key = nil end

    return block
end
