-- The campfire slip (Your Diary's plates; .claude/ui-proposal/campfire.md,
-- the user's decisions of 14 Oct): a campfire sat by on a plate, told in the
-- margin by one small cut slip of the strip family (UI/Paper/Strip.lua) with
-- one line in the diary's hand, exactly "sat by a campfire"
-- (Campfire.WORDS, Text.lua: the user's words), and a pencil leader to the
-- fire's mark (Mark.lua).
--
-- It is the lucky card's S size (Features/Hunts/LuckyCard.lua's tag): the hand at
-- 14 px, not a person's 16, so it fits the narrowest column (122 px); the
-- tag's small tape slanted over its top left corner, clear of the words. No
-- heading, icon, count or struck words: one slip a plate however many fires
-- (each keeps its own mark), and its tooltip tells every sitting there as one
-- account (Campfire.Tips). A left click opens nothing; a right click opens
-- the form (Core/Custom.lua).
--
-- A fire the player changed or wrote is outside that one slip: it has a slip of
-- its own, the same slip in the same pool, that is not filler (Slip.Customs and
-- "campfireCustom", below; .claude/features/custom-cards.md).
--
-- It is filler ("kind of unimportant, just filler if we don't have
-- anything better", the user, 14 Oct): last in the margin, so the first
-- left off, and it never grows smaller. Either it fits or it is left off
-- and the caption's words say it (`said.campfire`, Text.lua), unless that
-- would run them past their foot (plate.camped, below).
--
-- Laid flat ("Flat paper only") it lies square, without shadows, as every
-- slip does.

local addonName, ns = ...

local Style = ns.Style
local Campfire = ns.Campfire
local Slip = {}
Campfire.Slip = Slip

-- The slip: the hand's file and size (the lucky tag's 14 px, PRINT.hand),
-- the most it turns (degrees, the strip's), and its tape (LuckyCard's TAG:
-- `w` by `h`, its middle at `x`, `y` px of the slip from its top left, i.e.
-- on the corner, slanted between the two `slant`s, degrees, seeded), which
-- crosses the corner on the slip's margin (7 px left, 4 px top), so the
-- words start clear of it.
local SLIP = { file = Style.NEUTON_ITALIC, size = 14, turn = 1.4,
    tape = { x = 1, y = 1, w = 22, h = 10, slant = { 39, 51 } } }

-- A number from a string, the same every time (the strip's,
-- UI/Paper/Surface.lua).
local Seed = ns.UI.Surface.Seed

-- The plate's one slip, from its fires (plate.campfireMarks: { x, y on the
-- card, list of moments, at = { x, y } on the page }): every sitting on the
-- plate (`list`, oldest first, for the tooltip), the latest fire's mark on
-- the page (`mark`, which stands in for the slip's place in the margin's
-- order before it is laid), and every mark (`marks`, page points, for its
-- leader to go to the nearest). Nil without a fire. Only the fires as detected:
-- one the player changed or wrote has its own slip (Slip.Customs), so it is not
-- told twice, and a mark holding only those is no place for this slip's leader.
function Slip.Choose(marks)
    local list, latest, at, points = {}, nil, nil, {}
    for _, mark in ipairs(marks or {}) do
        local detected = false
        for _, m in ipairs(mark.list or {}) do
            if not (m.campfire and m.campfire.customOf) then
                detected = true
                list[#list + 1] = m
                if not latest or (m.t or 0) >= (latest.t or 0) then latest, at = m, mark end
            end
        end
        if detected then points[#points + 1] = mark.at end
    end
    if not latest then return nil end
    table.sort(list, function(a, b) return (a.t or 0) < (b.t or 0) end)
    return { list = list, mark = at.at, marks = points, x = at.x, y = at.y }
end

-- The fires on the plate the player changed or wrote, each as Choose's shape
-- over itself alone, so the same slip writes it: its tooltip tells that sitting,
-- its leader goes to that fire's mark. The newest first, so that where the margin
-- runs out the oldest are the ones left to their marks.
function Slip.Customs(marks)
    local list = {}
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            if m.campfire and m.campfire.customOf then
                list[#list + 1] = { list = { m }, mark = mark.at, marks = { mark.at }, x = mark.x, y = mark.y,
                    fire = m.campfire }
            end
        end
    end
    table.sort(list, function(a, b) return (a.fire.t or 0) > (b.fire.t or 0) end)
    return list
end

-- The mark its leader goes to: of the fires on the plate, the one nearest
-- the slip as laid (the fires are equals, as a person's marks are).
function Slip.Mark(chosen, slip)
    local best, gap
    for _, at in ipairs(chosen.marks or {}) do
        local sx, sy = slip:Nearest(at[1], at[2])
        local d = (sx - at[1]) ^ 2 + (sy - at[2]) ^ 2
        if not best or d < gap then best, gap = at, d end
    end
    return best or chosen.mark
end

-- The slip as a card on the strip (UI/Paper/Strip.lua's hooks): laid as a
-- strip is, `overfull` where its line is wider than the column (it does
-- not wrap or shrink, so the page leaves it off).
local CARD = {
    plan = function(slip, note, width)
        local l, _, r = slip:Pad()
        local text = slip.name
        local natural = (text.GetUnboundedStringWidth and text:GetUnboundedStringWidth() or text:GetStringWidth() or 0)
            + 2 + l + r
        slip.overfull = natural > width
    end,
}

-- A slip on `parent`. slip:SetCampfire(chosen, seed, now), then
-- slip:Layout(x, y, width) as a strip's (CARD).
function Slip.New(parent)
    local slip = ns.UI.PaperStrip(parent, CARD)
    slip.name:SetFont(SLIP.file, SLIP.size, "")

    function slip:SetCampfire(chosen, seed, now)
        self.chosen = chosen
        -- Every sitting on the plate in one account, as a fire's mark
        -- tells its own (Campfire.Tips).
        local function Tip()
            local fires = {}
            for _, m in ipairs(chosen.list) do fires[#fires + 1] = m.campfire or m end
            return Style.TipList(Campfire.Tips(fires, now))
        end
        local rand = ns.UI.Pen.Random(Seed(seed .. ":tape"))
        local T = SLIP.tape
        self:SetNote({ name = Campfire.WORDS, strong = true, seed = seed, turn = SLIP.turn, tip = Tip,
            tapeAt = { x = T.x, y = T.y, w = T.w, h = T.h, slant = T.slant[1] + (T.slant[2] - T.slant[1]) * rand() } })
    end

    -- The words as written (for the tests).
    function slip:Words() return self.name:GetText() end

    return slip
end

-- The slip in the plates' margin (ns.UI.JourneyMargin.Register,
-- UI/Journey/Margin.lua): one, "sat by a campfire", order 90, last of all,
-- after the people only seen (80), so it is the first left off: filler
-- (the user, 14 Oct), and the caption's words say it then
-- (`said.campfire`), unless that would cost the caption its place over
-- the plate or run it past its foot (plate.camped false then: the mark
-- alone tells it). It goes in a light plate's margin too (under its
-- caption), never on the print: there is room under the print's caption
-- in LF, LFF, LFL, FLF (and FFL with the route kept); under FL's print
-- (its caption from y 474) and often F+L's tucked one there is none, so it
-- is left off there and the words say it. The layouts stay as they are for
-- it, never FL turned FF for a campfire (the user's choice, 14 Oct). Its
-- leader goes to the fire nearest the slip.
ns.UI.JourneyMargin.Register("campfire", {
    order = 90, pool = "campfirePool", count = "campfiresWritten", filler = true, flag = "camped",
    new = function(parent) return Slip.New(parent) end,
    item = function(plate)
        local f = plate.campfire
        return f and { campfire = f, top = f.mark[2], x = f.mark[1] } or nil
    end,
    write = function(slip, it, c)
        local first = it.campfire.list[1]
        slip:SetCampfire(it.campfire, c.Seed("campfire", first and first.t or 0), c.now)
    end,
    mark = function(it, slip) return Slip.Mark(it.campfire, slip) end,
    -- The slip speaks for several sittings and the form holds one: the newest,
    -- the one its place in the margin stands for. The others are the marks' to
    -- open, whose menu tells them apart.
    custom = function(it)
        local list = it.campfire.list
        return "campfire", list[#list].campfire
    end,
    -- Where a fire of the player's has its slip on the page, "sat by a campfire"
    -- is already said there, and the words saying it too would read as a second
    -- telling (campfireCustom's `say`, asked first, its order being lower).
    say = function(said, shown, plate)
        if plate.campfire and not shown[1] and not said.campfireWritten then said.campfire = true end
    end,
})

-- The fires the player changed or wrote: a slip each, past the plate's one and
-- not filler, so they are not the first to go (custom-cards.md's order, 9: after
-- the other custom cards, before the people). Having no `filler`, what it left
-- off is told whatever the words' length, as a killer's card left off is, and
-- the words say it only where none of its slips found room: "sat by a campfire"
-- once on the page is enough for two fires, as it is on the detected slip.
ns.UI.JourneyMargin.Register("campfireCustom", {
    order = 9, pool = "campfirePool", count = "customCampfiresWritten",
    new = function(parent) return Slip.New(parent) end,
    items = function(plate)
        local items = {}
        for _, f in ipairs(Slip.Customs(plate.campfireMarks)) do
            items[#items + 1] = { campfire = f, top = f.mark[2], x = f.mark[1] }
        end
        return items
    end,
    write = function(slip, it, c)
        slip:SetCampfire(it.campfire, c.Seed("campfire", it.campfire.fire.t or 0), c.now)
    end,
    mark = function(it) return it.campfire.mark end,
    custom = function(it) return "campfire", it.campfire.fire end,
    say = function(said, shown, plate)
        if shown[1] then
            said.campfireWritten = true
        elseif Slip.Customs(plate.campfireMarks)[1] then
            said.campfire = true
        end
    end,
})
