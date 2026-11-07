-- A plate glued in on Your Diary's right page (JRN-21, JRN-22): its
-- heading by hand (Heading), its words and margin written until they agree
-- (Plated, over the plate with its notes in a row where the caption is
-- short), and the open level's plates on the page their weights give
-- (DrawPlates, which tries FL's print tucked in first: F+L). The words are
-- UI/Journey/Text/Caption.lua's, the margin UI/Journey/Margin.lua's.
--
-- The module and its siblings: UI/Journey/Look.lua.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local Text = ns.UI.JourneyText
local Plate = ns.UI.JourneyPlate
local YourDiary = ns.UI.YourDiary

local CAPTION = YourDiary.CAPTION
local ArtSize, Holds, PlatesOf = YourDiary.ArtSize, YourDiary.Holds, YourDiary.PlatesOf
local SheetOf, MomentsOf = YourDiary.SheetOf, YourDiary.MomentsOf
local PlateAt, Leader = YourDiary.PlateAt, YourDiary.Leader
local People, Named = YourDiary.People, YourDiary.Named
local NONE, MARGIN, MARGIN_ORDER = YourDiary.NONE, YourDiary.MARGIN, YourDiary.MARGIN_ORDER
local Mark, Undo, WriteMargin = YourDiary.Mark, YourDiary.Undo, YourDiary.WriteMargin

-- Text at x, y of the right page (its top left), `width` wide and wrapped,
-- set flush to `align` (left by default); returns its height. `font` nil
-- keeps the font the string already has (a heading fitted by hand).
local function Write(text, font, words, x, y, width, align)
    local page = YourDiary.page
    if font then text:SetFontObject(font) end
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", page.right, "TOPLEFT", x, -y)
    text:SetWidth(width)
    text:SetJustifyH(align or "LEFT")
    text:SetText(words)
    return math.ceil(text:GetStringHeight() or 0)
end

-- A plate's heading by hand, "The Barrens, yesterday", in ink: on one line
-- at the first of CAPTION.hand's sizes that fits `width`. Where none does,
-- the zone alone (at the size that fits, else the smallest, wrapping), and
-- the day is returned to open the words under it. Returns the heading and
-- that day, if moved. A plate the same day as the one `before` it counts
-- on from it ("Forty-five minutes later").
local function Heading(text, p, width, before)
    local page = YourDiary.page
    local line, zone, day = Text.PlateHeading(p, page.now, before)
    local file = CAPTION.handFile
    local function Fits(words)
        for _, size in ipairs(CAPTION.hand) do
            text:SetFontObject(FONT.noteWritten)
            if file and size ~= CAPTION.hand[1] then text:SetFont(file, size, "") end
            text:SetText(words)
            if (text:GetUnboundedStringWidth() or 0) <= width then return true end
            if not file then return false end
        end
        return false
    end
    if Fits(line) then return line, nil end
    Fits(zone)
    return zone, day
end

-- One plate (ctx: the entry `e`, its plan `p`, the `plate`, its
-- `heading` and `words`, the plate `before` it, when the road `began`,
-- the journey `j`) drawn in `slot`, with its caption and margin notes.
-- `over`: the caption over the plate and its notes in a row under it
-- (TOP), which holds only while the caption is short: its heading on one
-- line and its words on one at most, as first written and again once the
-- margin is laid and whatever had no room is named in them. Where it is
-- not, nothing is left laid and it returns false (the plate goes under its
-- caption instead: decided once, on the words as written last, so it
-- never flips back). A slot that must hold its plate's margin `whole`
-- (FL's `tucked`, its row shared with a print) returns false in the same
-- way when anything of it had no room in the row. Returns true.
local function Plated(ctx, slot, over)
    local page = YourDiary.page
    local e, p, plate, heading, words = ctx.e, ctx.p, ctx.plate, ctx.heading, ctx.words
    plate:SetSlot(slot)
    local aw, ah = ArtSize(slot)
    plate:Draw(SheetOf(p.mapID), e, Plate.Window(p.mapID, p.cx, p.cy, aw, ah), { moments = MomentsOf(e),
        cap = Plate.Share(slot), fights = page.fights, witnesses = page.witnesses, now = page.now })
    plate.share, plate.plan = Plate.Share(slot), p
    -- A close-up looks at nothing closer. The first plate is the one a full
    -- page was just drawn on, shown all along, so its view would stay (only
    -- its hiding clears it): the wheel would still work here, and the cursor
    -- would read through the full page's view (plate:MapAtCursor).
    plate:Look(nil)
    plate:SetClick(function()
        Style.PlaySound("pageTurn")
        YourDiary.OpenFull(p.mapID)
    end)
    plate:Show()

    -- Its caption, written by hand on the page beside it; who its
    -- notes name is not named again in the words.
    local cap = slot.cap
    local groups = People(plate)
    local headingWords, day = Heading(heading, p, cap.w, ctx.before)
    -- A line of each, measured as written, for what "short" means.
    local oneHeading = Write(heading, nil, "Ag", cap.x, cap.y, cap.w, cap.align)
    local h = Write(heading, nil, headingWords, cap.x, cap.y, cap.w, cap.align)
    local oneLine = Write(words, FONT.body, "Ag", cap.x, cap.y, cap.w, cap.align)
    local function Short(tall) return tall <= oneLine * 1.5 end
    if over and h > oneHeading * 1.5 then return false end
    -- The words, told what the margin shows (Text.PlateCaption's `said`),
    -- the day first where the heading had no room for it.
    local function Words(said)
        local text = Text.PlateCaption(p, ctx.began, said)
        return day and (day:sub(1, 1):upper() .. day:sub(2) .. ". " .. text) or text
    end
    -- The margin (WriteMargin) under the words, and the words naming
    -- what had no room in the margin: written once more and the margin
    -- laid again until the words are as tall as the margin was laid
    -- under (11 Oct, in the client: a strip lay over the words' second
    -- line, written longer after it was placed). Over the plate the words
    -- are clear of the margin, so once is enough.
    local top = cap.y + h + CAPTION.under
    -- First as if the margin had room for all of it: the people's notes
    -- and every kind's (its `assume`: what its cards would show), each
    -- taken as shown until it is left off.
    local first = { named = Named(groups, #groups) }
    for _, spec in ipairs(MARGIN_ORDER) do
        if spec.assume then spec.assume(first, plate, slot, p) end
    end
    local tall = Write(words, FONT.body, Words(first), cap.x, top, cap.w, cap.align)
    if over and not Short(tall) then return false end
    local at, shown, all = Mark(), nil, 0
    local people, byKind, left, rewrite, quiet
    for pass = 1, 4 do
        -- Its notes: in their own column first and then under the
        -- caption, or under the caption; over the plate, in the row
        -- under it.
        local boxes
        if over then
            boxes = { row = true }
            for k, box in ipairs(slot.row) do boxes[k] = box end
        else
            local under = { x = cap.x, y = top + tall + CAPTION.notes, w = cap.w, limit = cap.limit,
                align = cap.align }
            boxes = slot.notes and { slot.notes, under } or { under }
        end
        local order
        shown, order = WriteMargin(plate, e, groups, boxes)
        all = #order
        -- What it showed, by kind, and the filler it left off: a kind
        -- with an item in the margin and none of it shown.
        people, byKind, left = {}, {}, {}
        for _, it in ipairs(shown) do
            if it.kind == "person" then
                people[#people + 1] = it.g
            else
                local list = byKind[it.kind] or {}
                byKind[it.kind] = list
                list[#list + 1] = it
            end
        end
        local filler = false
        for _, it in ipairs(order) do
            local spec = MARGIN[it.kind]
            if spec and spec.filler and not byKind[it.kind] then left[it.kind], filler = true, true end
        end
        -- Whoever and whatever has no note goes back into the words: each
        -- kind's `say`, in the margin's order, told what of it showed (a
        -- witness in a sentence of their own, and the creature their card
        -- did not name; a killer whose card had no room). Filler only
        -- with `withFiller`.
        rewrite = function(withFiller)
            local said = { named = Named(people, #people) }
            for _, spec in ipairs(MARGIN_ORDER) do
                if spec.say and (withFiller or not spec.filler) then
                    spec.say(said, byKind[spec.kind] or NONE, plate)
                end
            end
            return Write(words, FONT.body, Words(said), cap.x, top, cap.w, cap.align)
        end
        local again = rewrite(filler)
        if over or again <= tall or pass == 4 then
            -- Over the plate, filler's words never cost the caption its
            -- place there (the user, 14 Oct): it is left to its mark.
            if over and not Short(again) and filler then
                local plain = rewrite(false)
                if Short(plain) then again, quiet = plain, true end
            end
            tall = math.max(tall, again)
            if over and (not Short(again) or (slot.whole and #shown < all)) then
                Undo(at)
                return false
            end
            break
        end
        tall = again
        Undo(at)
    end
    -- Nor where saying it would run the words past their foot: they leave
    -- it to its mark on the plate and its tooltip. (14 Oct, rasterised:
    -- level 13's FL print, whose caption has two lines, ran a third off the
    -- page.) Each filler kind's `flag` on the plate says whether the words
    -- told it.
    local told = next(left) ~= nil and not quiet
    if told and not over and top + tall > (cap.limit or CAPTION.limit) then
        tall = math.min(tall, rewrite(false))
        told = false
    end
    for _, spec in ipairs(MARGIN_ORDER) do
        if spec.filler and spec.flag then plate[spec.flag] = told and left[spec.kind] == true end
    end
    page.notesWritten = page.notesWritten + #people
    for _, spec in ipairs(MARGIN_ORDER) do
        if spec.count then
            local list = byKind[spec.kind] or NONE
            page[spec.count] = (page[spec.count] or 0) + (spec.counted and spec.counted(list, plate) or #list)
        end
    end
    -- What a kind draws besides its notes (good luck's leader up its print).
    local drawn = { Leader = function(from, mark) Leader(from, mark, plate) end }
    for _, spec in ipairs(MARGIN_ORDER) do
        if spec.after then spec.after(plate, drawn) end
    end
    -- For the tests: where the words end, what the margin shows, and
    -- whether the caption is over the plate.
    plate.captionFoot, plate.margin, plate.captionOver = top + tall, shown, over
    -- Its heading: the plate's words for the pad (UI/Journey/Pad.lua),
    -- red while the pad is on it or among its marks.
    plate.heading = heading
    return true
end

-- The open level's plates, laid out on the page their weights and count
-- give (PlatesOf), each with its caption and margin notes.
local function DrawPlates(e)
    local page = YourDiary.page
    local plates, layout, pattern = PlatesOf(e)
    page.layout, page.pattern = #plates, pattern
    page.notesWritten = 0
    for _, spec in ipairs(MARGIN_ORDER) do
        if spec.count then page[spec.count] = 0 end
    end
    if #plates == 0 then
        -- JRN-21: a level whose road was not kept says so, faded.
        page.nothing:SetText("Nothing of this level's road was kept.")
        page.nothing:Show()
        return 0
    end
    local j = ns.Journey.For(ns.ownGUID)
    local began = j and j.startedAt
    -- FL tries its print tucked into the full plate's row first (`tucked`,
    -- F+L) where both plates are held by their windows there; whether it
    -- stays is the full plate's to say (Plated: its caption short, its
    -- margin whole), decided once, so the print follows it.
    local tucked = layout.tucked
    if tucked and not (Holds(plates[1], tucked[1]) and Holds(plates[2], tucked[2])) then tucked = nil end
    -- Nor where what a kind puts on the print will not go on the smaller
    -- one (its `fits`: good luck's S, Features/Hunts/LuckyCard.lua):
    -- nothing may be lost by tucking it in, and FL's snapshot has room
    -- for it.
    for _, spec in ipairs(MARGIN_ORDER) do
        if tucked and spec.fits and not spec.fits(plates[2], tucked[2]) then tucked = nil end
    end
    for i, p in ipairs(plates) do
        local slot = layout[i]
        local plate = PlateAt(i)
        local heading, words = page.headingPool:Next(), page.captionPool:Next()
        local ctx = { e = e, p = p, plate = plate, heading = heading, words = words, before = plates[i - 1],
            began = began, j = j }
        if i == 1 and tucked then
            if Plated(ctx, tucked[1], true) then
                layout, page.pattern = tucked, "F+L"
            else
                Plated(ctx, slot, false)
            end
        -- One plate with a short caption has it over the plate (TOP); a
        -- caption that will not stay short is under it, as on every other
        -- page.
        elseif not (slot.top and Plated(ctx, slot.top, true)) then
            Plated(ctx, slot, false)
        end
    end
    return #plates
end

YourDiary.DrawPlates = DrawPlates
