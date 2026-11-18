-- "Choose what's on this page" (.claude/features/choose-page.md, Phase 3,
-- and "Stable list"): the left page of Your Diary turned into a ticklist for
-- the piece the right page shows. Everything the diary noticed there, by
-- zone (a zone's heading with a box of its own), and under each zone a row
-- for every moment, in time order: its box, its words and its time.
--
-- The list never moves (the user's, 18 Nov, after the client round: rows
-- jumped, places split and merged and headings changed as the plates were
-- grouped again after a tick): it is made from the moments, not from the
-- plates (Recap.Choices, Core/Chosen.lua), every zone is always open, and no
-- row changes its height. A tick changes a row's box and ink, nothing else. Why a row is not on the page is its tooltip; what a
-- tick did beyond its row (a map moved off to make room, a keep blocked) is
-- said once, on the fixed line under the cap line.
--
-- The cap line's three small frames are the three maps, top to bottom as they
-- stand on the right page: red filled where a map holds the player's choice,
-- faded the diary's, empty where there is no such map. The maps carry no
-- numbers (the user's, 18 Nov, after a round with I, II, III on the rows, the
-- frames and paper labels on the plates: not meaningful enough for the
-- clutter); a row on the page is in ink, and hovering links a row and its mark
-- both ways: a row under the mouse rings its mark on its map (the card
-- sheet's pencil ring); a mark under the mouse lights its rows
-- (Plate.Hovered).
--
-- A box has the four looks of Recap.Choices: the diary's pick a faded tick,
-- the diary's leaving off an empty box, the player's keep a red tick in a red
-- box, the player's leaving out a red cross in a faint box with the words
-- struck through (the user's, 18 Nov: the diary's is faded, the player's is
-- the rubric's red; no "the diary's" link and no way back to the diary's
-- choice). A zone's box is a tick where all of it is on the page, a dash
-- where some is, empty where none is (red where anything in it is the
-- player's choice). On or off the page is the first thing the eye gets: a row
-- on the page is written in ink, a row off it recedes, and only the mark that
-- the player chose it is red (18 Nov, in the client: red names, strikes and
-- reasons made the page a wall of red that could not be skimmed).
--
-- A click on a row that shows leaves it out, on one that doesn't keeps it
-- (Chosen.Tick); a zone's box does the same for the whole zone (showing
-- anything: all of it left out; nothing: its best moment kept). The recap is
-- built again, the right page redrawn, then the ticklist filled from the new
-- piece. A keep that cannot fit is blocked: the line under the cap line says
-- why in red, the box shakes, nothing is written.
--
-- Reached by the link under the open level's sittings (Left.lua's EntryItems,
-- `choose`; YourDiary.Choose), left by "Done", the ribbon (the page turned to
-- again: RefreshJourneyPage's opening), or another level, sitting, run, match
-- or map opened (Page.lua's Open*, which call Unchoose). With the pad in hand
-- the link is not offered (the gamepad is a later phase, the user's): the
-- ticklist is mouse-only, so it closes as the pad is picked up.
--
-- The module and its siblings: UI/Journey/Look.lua.

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local Style = ns.Style
local FONT = Style.FONT
local Text = ns.UI.JourneyText
local Format = ns.UI.Format
local YourDiary = ns.UI.YourDiary
local Plate = ns.UI.JourneyPlate

local BOOK = ns.UI.Journal.BOOK
local LEFT_X, LEFT_W, BOOK_H = BOOK.LEFT_X, BOOK.LEFT_W, BOOK.BOOK_H
local SCROLLBAR_WIDTH = ns.UI.SCROLLBAR_WIDTH

local HEAD, ENTRY = YourDiary.HEAD, YourDiary.ENTRY

-- The ticklist's look, down from the left page's top as the entries are
-- (HEAD): the level's rubric where the character's name stands (`rubric`, its
-- paraph and fading rule as an entry's, ENTRY), the title in the hand under it
-- (`title`), the cap line (`cap`: its three small frames, the maps, `frame` px
-- wide and `frameH` tall, `frameGap` apart, the words `capGap` past the last), the line under it (`note`, two lines high, always
-- there so the list never moves: what a tick did, or why it was blocked), and
-- the list from `list` down to `bottom` px above the page's foot, where "Done"
-- stands (`done`, its top that far above the foot, clear of the ribbons as the
-- entries are).
-- A zone's row: its box `box` px at `boxX`, its name in the hand `nameX` in,
-- `place` px tall. A moment's row: `indent` px further in, its box `cardBox`,
-- its words in small type, `card` px tall; at its right the time. `gap` under a zone's last
-- row, so the next zone stands apart. No row has a second line: a row's
-- height never changes with its look.
-- The boxes are drawn by hand (Box): an outline a little off square, a tick
-- that runs past the box's top as a quick hand's does, a cross, a dash (a
-- zone partly on the page). The diary's in graphite (`faded`: its outline and
-- tick alpha, `thin` px, the tick `tickW` px, lighter than the player's so the
-- two part on a card's 10 px box too), the player's in the rubric (`red`,
-- `bold` px for the tick and cross, `edge` px for a kept box's outline). A box
-- off the page, the diary's empty one or the player's crossed one, has the
-- faint outline `faded.off`: the red frame is the kept rows' alone.
-- `off`: a row off the page, its words in faded ink at that alpha, back to
-- full faded ink under the mouse (or lit from its mark).
-- `strike` is the line through words left out, in their faded ink: `strikeW`
-- px thick, a little longer than the words (`strikeOver`).
-- `frames`: the cap line's frames' outline alpha and fill, the player's
-- (`mine`, red, filled with red at `fill`), the diary's (`diary`, graphite,
-- a faint fill `diaryFill`), a map not there (`free`, an outline alone).
-- `ring`: the pencil ring round a row's mark on its map (plate:SetRing, as
-- UI/Journey/CardSheet.lua's: radius, dashes, ...), in the leaders' pencil.
-- `shake`: the box on a blocked tick, `amp` px either way, `times` there and
-- back over `secs`, dying away.
local CHOOSE = {
    rubric = 20, title = 38, cap = 64, frame = 13, frameH = 10, frameGap = 3, capGap = 7, note = 84, noteH = 28,
    list = 114, bottom = 42, done = 30,
    box = 13, boxX = 1, nameX = 21, place = 23, indent = 18, cardBox = 10, card = 18, gap = 5,
    faded = { outline = 0.55, tick = 0.80, tickW = 1, off = 0.38 }, thin = 1, red = 0.95, bold = 1.8, edge = 1.25,
    off = { name = 0.72 },
    strikeW = 1.2, strikeOver = 3,
    frames = { mine = 0.95, fill = 0.85, diary = 0.55, diaryFill = 0.30, free = 0.5 },
    ring = { r = 9, dashes = 9, share = 0.62, uneven = 0.25, wander = 0.8, bends = 4, step = 1.5, width = 1.4 },
    shake = { amp = 2.5, times = 3, secs = 0.45 },
}
YourDiary.CHOOSE = CHOOSE

-- The words, furniture and ledger (the copywriter's §1; choose-page.md's
-- "Stable list"). A row's reason is its tooltip's line (ledger, capitalised);
-- the cap line and the line under it are furniture.
local WORDS = {
    title = L["Choose what's on this page"],
    cap = L["Three maps fit."],
    blocked = L["All three maps hold what you chose. Leave something out first."],
    bumped = L["%s came off to make room."],
    done = L["Done"],
    reason = {
        next = L["Next in line"],
        noRoom = L["No room on the page"],
        minor = L["Too small for a map of its own"],
        marginRoom = L["No room in the margin"],
        run = L["Its run has a page of its own"],
    },
    madeRoom = L["Came off to make room for %s"],
}
YourDiary.CHOOSE_WORDS = WORDS

--------------------------------------------------------------------------
-- What the ticklist reads
--------------------------------------------------------------------------

-- The piece the right page shows (the open entry's open piece, or the entry
-- whole where it is spliced), and its entry.
local function Shown()
    local page = YourDiary.page
    local e = page and page.recap and page.recap.entries[page.open]
    if not e then return nil end
    return YourDiary.OpenPieceOf(e) or e, e
end

-- Whether `piece` has anything to choose from: a place on the page, one cut,
-- or a moment that opens none (Recap.Plates' spare and loose).
local function CanChoose(piece)
    if not piece then return false end
    local plates = YourDiary.PlatesOf(piece)
    return #plates > 0 or #(plates.spare or {}) > 0 or #(plates.loose or {}) > 0
end

local function Capital(text)
    return (text:gsub("^%l", string.upper))
end

local function ZoneName(mapID)
    return Text.MapName(mapID) or L["A stop"]
end

-- What a moment's row says: a person's name; a feature's card as its editor
-- describes it (Core/Custom.lua), else its mark's tooltip's title
-- (Plate.RegisterMark's `tip`); the route's own kinds in their words (a stop
-- and an arrival by their sub-zone, which is never a heading).
local PEOPLE = { session = true, fight = true, note = true, first = true }

local function CardLabel(m, now)
    if PEOPLE[m.kind] and m.guid then
        return ns.Characters.FullName(m.guid) or ns.Characters.Name(m.guid) or L["Someone"]
    end
    if m.kind == "level" then return Fmt(L["Level %d"], m.level or 0) end
    if m.kind == "death" then return L["A death"] end
    if m.kind == "road" then return L["On the road"] end
    if m.kind == "dungeon" then return m.name or L["An instance"] end
    if m.kind == "stay" then return m.seg and Text.StopLabel(m.seg, m.seconds) or L["A stop"] end
    if m.kind == "arrive" then
        local sub = m.seg and m.seg.subZone
        if sub and sub ~= "" then return Fmt(L["Arrived %s##zone"], ns.ZoneIn(nil, sub)) end
        local zone = Text.MapName(m.mapID)
        return zone and Fmt(L["Arrived %s##zone"], ns.ZoneIn(m.mapID, zone)) or L["A stop"]
    end
    local spec = ns.Custom.Spec(m.kind)
    local field = ns.JourneyRecap.MOMENTS[m.kind] and ns.JourneyRecap.MOMENTS[m.kind].field
    local rec = field and m[field]
    if spec and type(rec) == "table" then
        return spec.describe and spec.describe(ns.Custom.Values(rec.customOf or rec)) or Capital(spec.label)
    end
    local mark = Plate.MARKS[m.kind]
    local title = mark and mark.tip and mark.tip(m, now)
    if type(title) == "string" and title ~= "" then return title end
    return spec and Capital(spec.label) or Capital(m.kind)
end

-- A row's words: its moment's; a door's trips together with how many.
local function RowLabel(row, now)
    local label = CardLabel(row.moment, now)
    if #row.moments > 1 then label = Fmt(L["%1$s, %2$s"], label, Format.Times(#row.moments)) end
    return label
end

-- The tooltip's line for why a row (or a zone) is not on the page; nil where
-- it is, and where the player left it out (its cross and strike say so).
local function Reason(row)
    if not row.reason or row.reason == "byYou" then return nil end
    if row.reason == "madeRoom" then
        return Fmt(WORDS.madeRoom, row.madeRoomFor and ZoneName(row.madeRoomFor) or L["A stop"])
    end
    return WORDS.reason[row.reason]
end

-- The list's items for `choices`: a zone, then every row of it.
local function Items(choices, now)
    local items = {}
    for _, zone in ipairs(choices.zones) do
        items[#items + 1] = { zone = zone, row = zone, label = ZoneName(zone.mapID), height = CHOOSE.place }
        for _, row in ipairs(zone.rows) do
            items[#items + 1] = { card = row, row = row, label = RowLabel(row, now),
                time = Format.Clock(row.t or 0), height = CHOOSE.card }
        end
        items[#items].height = items[#items].height + CHOOSE.gap
    end
    return items
end

-- A row's tooltip: its words, then why it is not on the page (a row on it
-- says so by its ink, and by its mark ringed on its map).
local function Tip(item)
    if not item then return nil end
    local list = { { item.label } }
    local why = Reason(item.row)
    if why then list[#list + 1] = { Capital(why), 1, 1, 1, true } end
    return list
end

--------------------------------------------------------------------------
-- The box, drawn by hand
--------------------------------------------------------------------------

-- A box `s` px: its outline a little off square, a tick, a cross, a dash;
-- each a pen stroke (Style.Stroke) whose ink and weight Look sets.
local function Box(parent, s)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(s, s)
    local INK = Style.GRAPHITE
    local function Line(x1, y1, x2, y2) return Style.Stroke(box, "ARTWORK", x1, y1, x2, y2, INK, 1, 1) end
    local a, b, c, d = { 0.4, 0.9 }, { s - 0.3, 0.4 }, { s - 0.6, s - 0.3 }, { 0.2, s - 0.6 }
    box.outline = { Line(a[1], a[2], b[1], b[2]), Line(b[1], b[2], c[1], c[2]), Line(c[1], c[2], d[1], d[2]),
        Line(d[1], d[2], a[1], a[2]) }
    box.tick = { Line(0.2 * s, 0.52 * s, 0.42 * s, 0.8 * s), Line(0.42 * s, 0.8 * s, 0.98 * s, 0.02 * s) }
    box.cross = { Line(0.22 * s, 0.22 * s, 0.8 * s, 0.8 * s), Line(0.8 * s, 0.2 * s, 0.22 * s, 0.82 * s) }
    box.dash = { Line(0.24 * s, 0.53 * s, 0.78 * s, 0.49 * s) }
    box.size = s
    return box
end

local function Ink(strokes, colour, alpha, thick, shown)
    for _, stroke in ipairs(strokes) do
        stroke:SetColorTexture(colour[1], colour[2], colour[3], alpha)
        stroke:SetHeight(thick)
        stroke:SetShown(shown)
    end
end

-- The box as `look` has it (Recap.Choices' looks); a zone's `state` says
-- whether its mark is a tick (all on the page) or a dash (some).
local function Look(box, look, state)
    local R, G, F = Style.RUBRIC, Style.GRAPHITE, CHOOSE.faded
    local mine = look == "keep"
    if mine then
        Ink(box.outline, R, CHOOSE.red, CHOOSE.edge, true)
    else
        Ink(box.outline, G, look == "diary" and F.outline or F.off, CHOOSE.thin, true)
    end
    local marked = look == "keep" or look == "diary"
    local some = state == "some"
    Ink(box.tick, mine and R or G, mine and CHOOSE.red or F.tick, mine and CHOOSE.bold or F.tickW, marked and not some)
    Ink(box.dash, mine and R or G, mine and CHOOSE.red or F.tick, mine and CHOOSE.bold or F.tickW * 1.3,
        marked and some)
    Ink(box.cross, R, CHOOSE.red, CHOOSE.bold * 0.85, look == "out")
    box.look, box.state = look, state
end

-- A blocked tick: the box shakes its head, there and back, dying away.
local function Shaking(box, elapsed)
    local S = CHOOSE.shake
    box.t = box.t + elapsed
    local p = math.min(box.t / S.secs, 1)
    local dx = S.amp * (1 - p) * math.sin(p * S.times * 2 * math.pi)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", box.x + dx, box.y)
    if p >= 1 then box:SetScript("OnUpdate", nil) end
end

local function Shake(box)
    box.t = 0
    box:SetScript("OnUpdate", Shaking)
end

local function PlaceBox(box, x, y)
    box:SetScript("OnUpdate", nil)
    box.x, box.y = x, y
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", x, y)
end

--------------------------------------------------------------------------
-- The link between a row and its mark
--------------------------------------------------------------------------

-- The plate showing map `n` while the ticklist is open, nil for any other.
local function PlateOf(n)
    local page = YourDiary.page
    if not (page and page.choosing and page.mode == "plates" and n and n <= (page.layout or 0)) then return nil end
    return page.plates[n]
end

-- A plate's place on the page, top to bottom (nil where the ticklist is
-- closed, or the plate is not on the page).
local function IndexOn(plate)
    local page = YourDiary.page
    if not (page and page.choosing and page.mode == "plates") then return nil end
    for i = 1, page.layout or 0 do
        if page.plates[i] == plate then return i end
    end
    return nil
end

local function RingOff()
    local page = YourDiary.page
    local plate = page and page.chooseRing
    if plate then
        page.chooseRing = nil
        plate:SetRing(nil)
    end
end

-- A row under the mouse: the pencil ring round its mark on its map.
local function RingOn(item)
    RingOff()
    local row = item and item.card
    local plate = row and PlateOf(row.plate)
    local m = row and row.moment
    if not (plate and m and m.x) then return end
    local LEAD = YourDiary.LEADER
    plate:SetRing({ mapID = m.mapID, x = m.x, y = m.y, look = setmetatable({ colour = LEAD.colour,
        alpha = LEAD.alpha, nib = LEAD.pen.nib }, { __index = CHOOSE.ring }) })
    YourDiary.page.chooseRing = plate
end

--------------------------------------------------------------------------
-- The rows
--------------------------------------------------------------------------

local Tick, RowInk

local function Hover(row, over)
    row.hot = over or nil
    RowInk(row)
    if over then RingOn(row.item) else RingOff() end
end

local function BuildRow(list)
    local row = CreateFrame("Button", nil, list)
    row.placeBox = Box(row, CHOOSE.box)
    row.cardBox = Box(row, CHOOSE.cardBox)
    row.name = Style.Text(row, FONT.noteWritten)
    row.name:SetWordWrap(false)
    row.time = Style.Text(row, FONT.small)
    row.time:SetPoint("TOPRIGHT", -2, -4)
    row.time:SetJustifyH("RIGHT")
    row.strike = row:CreateTexture(nil, "OVERLAY")
    row.strike:SetHeight(CHOOSE.strikeW)
    -- Under the mouse its words darken, as a ledger's row does (no light),
    -- its mark is ringed on its map, and its tooltip says where it is.
    Style.Tooltip(row, function(self) return Tip(self.item) end, "ANCHOR_RIGHT", Hover)
    row:SetScript("OnClick", function(self) Tick(self) end)
    return row
end

-- Whether a row's item stands for any of `keys` (a mark's moments).
local function Lit(item, keys)
    if not (keys and item and item.card) then return false end
    for _, key in ipairs(item.card.keys) do
        if keys[key] then return true end
    end
    return false
end

-- A row's words in their ink: on the page in ink (a zone's darker), darker
-- under the mouse or lit from its mark; off the page (the diary's or the
-- player's) faded, its strike with it, and the whole faded ink under the
-- mouse.
function RowInk(row)
    local item = row.item
    if not item then return end
    local page = YourDiary.page
    local hot = row.hot or Lit(item, page and page.chooseLit)
    local off = not item.row.on
    local ink, alpha = Style.INK_STRONG, 1
    if off then
        ink, alpha = Style.INK_FADED, hot and 1 or CHOOSE.off.name
    elseif item.card then
        ink = hot and Style.INK_STRONG or Style.INK
    end
    row.name:SetTextColor(ink[1], ink[2], ink[3], alpha)
    row.strike:SetColorTexture(ink[1], ink[2], ink[3], alpha)
    local T = Style.INK_FADED
    row.time:SetTextColor(T[1], T[2], T[3], off and CHOOSE.off.name or 1)
end
YourDiary.ChooseRowInk = RowInk

local function UpdateRow(row, item)
    local card = item.card ~= nil
    local x = card and CHOOSE.indent or 0
    local box = card and row.cardBox or row.placeBox
    row.placeBox:SetShown(not card)
    row.cardBox:SetShown(card)
    local h = card and CHOOSE.card or CHOOSE.place
    PlaceBox(box, x + CHOOSE.boxX, -math.floor((h - box.size) / 2) + (card and 1 or 0))
    Look(box, item.row.look, item.zone and item.zone.state or nil)

    row.name:SetFontObject(card and FONT.small or FONT.noteWritten)
    row.name:ClearAllPoints()
    local nameX = x + CHOOSE.nameX - (card and 3 or 0)
    row.name:SetPoint("TOPLEFT", nameX, -3)
    row.name:SetWidth(0)
    row.name:SetText(item.label)
    row.time:SetText(item.time or "")
    local rowW = LEFT_W - SCROLLBAR_WIDTH - 2
    local right = card and ((row.time:GetUnboundedStringWidth() or 0) + 6) or 0
    local most = rowW - nameX - right - 4
    local nameW = row.name:GetUnboundedStringWidth() or 0
    if nameW > most then
        row.name:SetWidth(most)
        nameW = most
    end

    -- Left out by the player: struck through, a little past both ends (its
    -- ink is the words', RowInk).
    local out = item.row.look == "out"
    row.strike:ClearAllPoints()
    row.strike:SetPoint("LEFT", row.name, "LEFT", -CHOOSE.strikeOver / 2, card and 0 or -1)
    row.strike:SetWidth(math.max(1, nameW + CHOOSE.strikeOver))
    row.strike:SetShown(out)
    RowInk(row)
end

-- The rows lit from a mark under the mouse (nil: none): their words darken.
local function Light(keys)
    local page = YourDiary.page
    local ch = page and page.chooser
    if not ch then return end
    page.chooseLit = keys
    for _, row in ipairs(ch.list.rows or {}) do
        if row:IsShown() and row.item then RowInk(row) end
    end
end

-- A mark under the mouse (Plate.Hovered): the rows of what it stands for lit.
-- A square that knows its moments (a person's spot, a door, a registered
-- mark) says them; a pool, a pin or a cross is matched to the moments of its
-- map drawn within the square.
Plate.Hovered = function(plate, button, entered)
    local page = YourDiary.page
    if not (page and page.choosing and page.chooser) then return end
    if not entered then return Light(nil) end
    if not IndexOn(plate) then return end
    local keys, any = {}, false
    local Key = ns.Chosen.Key
    for _, m in ipairs(button.moments or {}) do keys[Key(m)], any = true, true end
    if not any and button.padAt and plate.At then
        local reach = (button:GetWidth() or 12) / 2 + 3
        for _, m in ipairs(plate.plan and plate.plan.moments or {}) do
            local x, y = plate.At(m.x, m.y)
            if x and math.abs(x - button.padAt[1]) <= reach and math.abs(y - button.padAt[2]) <= reach then
                keys[Key(m)], any = true, true
            end
        end
    end
    Light(any and keys or nil)
end

--------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------

-- One of the cap line's frames, a map: an outline, and its fill.
local function Frame(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(CHOOSE.frame, CHOOSE.frameH)
    f.fill = f:CreateTexture(nil, "ARTWORK", nil, 0)
    f.fill:SetPoint("TOPLEFT", 1, -1)
    f.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    f.edges = {}
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = f:CreateTexture(nil, "ARTWORK", nil, 1)
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        if side[3] then t:SetHeight(1) else t:SetWidth(1) end
        f.edges[#f.edges + 1] = t
    end
    return f
end

-- `kind`: "mine" (red), "diary" (faded), or nil (no such map on the page).
local function FrameLook(f, kind)
    local FR = CHOOSE.frames
    local c, edge, fill = Style.INK, FR.free, nil
    if kind == "mine" then
        c, edge, fill = Style.RUBRIC, FR.mine, FR.fill
    elseif kind == "diary" then
        c, edge, fill = Style.GRAPHITE, FR.diary, FR.diaryFill
    end
    for _, t in ipairs(f.edges) do t:SetColorTexture(c[1], c[2], c[3], edge) end
    f.fill:SetColorTexture(c[1], c[2], c[3], fill or 0)
    f.fill:SetShown(fill ~= nil)
    f.kind = kind
end

local function Build(page)
    local parent = page.parent
    local ch = CreateFrame("Frame", nil, parent)
    ch:SetPoint("TOPLEFT", LEFT_X, 0)
    ch:SetSize(LEFT_W, BOOK_H)
    ch:Hide()

    -- The level's rubric, as an entry's: paraph, red capitals, the sitting
    -- beside them, a red rule fading out.
    ch.rubric = Style.Text(ch, FONT.headingRubric)
    ch.rubric:SetPoint("TOPLEFT", ENTRY.indent, -CHOOSE.rubric)
    ch.paraph = ch:CreateTexture(nil, "ARTWORK")
    ch.paraph:SetSize(ENTRY.paraph, ENTRY.paraph)
    ch.paraph:SetRotation(math.pi / 4)
    ch.paraph:SetPoint("CENTER", ch.rubric, "LEFT", -ENTRY.indent / 2 - 1, 0)
    local R = Style.RUBRIC
    ch.paraph:SetColorTexture(R[1], R[2], R[3], 1)
    ch.aside = Style.Text(ch, FONT.small)
    ch.aside:SetPoint("LEFT", ch.rubric, "RIGHT", 7, 0)
    ch.rule = ch:CreateTexture(nil, "ARTWORK")
    ch.rule:SetHeight(1)
    ch.rule:SetPoint("LEFT", ch.aside, "RIGHT", ENTRY.rule, 0)
    ch.rule:SetPoint("RIGHT", ch, "RIGHT", -2, 0)
    Style.Shade(ch.rule, "HORIZONTAL", R[1], R[2], R[3], ENTRY.ruleAlpha, 0)

    ch.title = Style.Text(ch, FONT.noteWritten)
    ch.title:SetPoint("TOPLEFT", 0, -CHOOSE.title)
    ch.title:SetText(WORDS.title)

    ch.frames = {}
    for k = 1, 3 do
        local f = Frame(ch)
        f:SetPoint("TOPLEFT", (k - 1) * (CHOOSE.frame + CHOOSE.frameGap), -CHOOSE.cap)
        ch.frames[k] = f
    end
    local capX = 3 * (CHOOSE.frame + CHOOSE.frameGap) - CHOOSE.frameGap + CHOOSE.capGap
    ch.cap = Style.Text(ch, FONT.small)
    ch.cap:SetPoint("LEFT", ch.frames[3], "RIGHT", CHOOSE.capGap, 0)
    ch.cap:SetWidth(LEFT_W - capX)
    ch.cap:SetJustifyH("LEFT")
    ch.note = Style.Text(ch, FONT.small)
    ch.note:SetPoint("TOPLEFT", 0, -CHOOSE.note)
    ch.note:SetSize(LEFT_W - 4, CHOOSE.noteH)
    ch.note:SetJustifyH("LEFT")
    ch.note:SetJustifyV("TOP")
    ch.note:SetWordWrap(true)

    local listH = BOOK_H - CHOOSE.list - CHOOSE.bottom
    ch.list = ns.UI.Journal.List(ch, ENTRY.unit, math.ceil(listH / ENTRY.unit), BuildRow, UpdateRow, LEFT_W,
        "TOPLEFT", 0, -CHOOSE.list)
    ch.list:SetNumRows(math.floor(listH / ENTRY.unit))

    ch.done = Style.Link(ch, FONT.body, function() YourDiary.Unchoose() end)
    ch.done:SetPoint("TOPLEFT", 0, -(BOOK_H - CHOOSE.done - 18))
    ch.done:SetText(WORDS.done)
    page.chooser = ch
    return ch
end

-- The left page's own parts, hidden while the ticklist stands there.
local function LeftShown(page, shown)
    for _, part in ipairs({ page.name, page.who, page.rule }) do part:SetShown(shown) end
    -- (the entries only where the page has them: not over its empty state)
    page.entries:SetShown(shown and (page.state == nil or page.state == "entries"))
end

-- The ticklist as the piece on the right page has it now: built on the page
-- drawn last (its plates and their margins), so call it after DrawRight.
local function Fill()
    local page = YourDiary.page
    local ch = page and page.chooser
    if not (ch and page.choosing) then return end
    local piece, e = Shown()
    if not piece then return YourDiary.Unchoose() end
    YourDiary.PlatesOf(piece)
    local now = page.now or ns.Now()
    local choices = ns.JourneyRecap.Choices(ns.Journey.For(ns.ownGUID), piece, page.ctx or {}, piece.cover)
    page.choices = choices

    ch.rubric:SetText(Text.Title(e, now))
    ch.aside:SetText(piece ~= e and Text.SittingLabel(piece, now) or (Text.Current(e) or ""))

    for k, f in ipairs(ch.frames) do
        local p = choices.plates[k]
        FrameLook(f, p and (p.mine and "mine" or "diary") or nil)
    end
    ch.cap:SetText(WORDS.cap)
    local blocked = page.chooseBlocked == true
    ch.note:SetText(blocked and WORDS.blocked or page.chooseNote or "")
    local ink = blocked and Style.RUBRIC or Style.INK_FADED
    ch.note:SetTextColor(ink[1], ink[2], ink[3], 1)

    page.chooseLit = nil
    ch.list:SetData(Items(choices, now), true)
end

-- The ticklist for the piece the right page shows, in place of the left
-- page; where a run, a match or a map was on the right page, the piece's
-- plates drawn in its place.
local function Choose()
    local page = YourDiary.page
    if not page or YourDiary.Solo() then return end
    local piece = Shown()
    if not CanChoose(piece) then return end
    local ch = page.chooser or Build(page)
    GameTooltip:Hide()
    page.choosing, page.chooseBlocked, page.chooseNote = true, nil, nil
    LeftShown(page, false)
    ch:Show()
    page.mode, page.fullMap, page.runVisit, page.matchId, page.session = "plates", nil, nil, nil, nil
    YourDiary.DrawRight()
    Fill()
    ch.list:SetOffset(0)
end

-- The left page given back ("Done", or anything that opens something
-- else). `quiet`: nothing drawn again (a caller draws both pages again).
local function Unchoose(quiet)
    local page = YourDiary.page
    if not (page and page.choosing) then return end
    RingOff()
    page.choosing, page.chooseBlocked, page.chooseNote, page.choices, page.chooseLit = nil, nil, nil, nil, nil
    page.chooser:Hide()
    LeftShown(page, true)
    if not quiet then
        YourDiary.Rebuild(true, page.open)
        if page.mode == "plates" then YourDiary.DrawRight() end
    end
end

-- A row clicked: Chosen.Tick on it. Blocked, the line under the cap line
-- says why and the box shakes; else the recap is built again and the page
-- drawn again, staying on this piece (page.holdAt, as a card changed does),
-- and the ticklist with it (RefreshJourneyPage calls Fill); a map moved off
-- to make room is named on that line. The right page eases from the old
-- drawing to the new (Glide.Around).
function Tick(row)
    local page = YourDiary.page
    local item = row.item
    if not (page and page.choosing and item) then return end
    local piece = Shown()
    if not piece then return end
    local result = ns.Chosen.Tick(nil, piece, page.ctx or {}, piece.cover, item.row)
    if not result then return end
    if result.blocked then
        page.chooseBlocked = true
        Fill()
        Shake(item.card and row.cardBox or row.placeBox)
        return
    end
    page.chooseBlocked = nil
    page.chooseNote = result.bumped and Fmt(WORDS.bumped, ZoneName(result.bumped.mapID)) or nil
    Style.PlaySound("write")
    page.holdAt = piece.from
    GameTooltip:Hide()
    RingOff()
    -- (the plates ease into their new places, the page final at once:
    -- UI/Journey/Glide.lua)
    YourDiary.Glide.Around(function() ns.UI.RefreshJourneyPage(false) end)
end

YourDiary.CanChoose, YourDiary.Choose, YourDiary.Unchoose, YourDiary.FillChoose = CanChoose, Choose, Unchoose, Fill
YourDiary.ShownPiece = Shown

-- The pad picked up with the ticklist open: it is mouse-only for now (the
-- gamepad is a later phase), so the left page is given back before the
-- page's own handler (UI/Journey/Pad.lua, loaded after this) builds it for
-- the pad (the plates drawn again, losing a ring).
ns.UI.Pad.Input.OnChange(function()
    local page = YourDiary.page
    if page and page.choosing and YourDiary.Solo() then
        Unchoose(true)
        if page.mode == "plates" then YourDiary.DrawRight() end
    end
end)
