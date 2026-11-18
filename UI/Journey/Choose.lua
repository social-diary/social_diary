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
-- said once, on the fixed line in the footer, beside "Done".
--
-- The cap line's three small frames are the three maps, top to bottom as they
-- stand on the right page: red filled where a map holds the player's choice,
-- faded the diary's, empty where there is no such map. The maps carry no
-- numbers (the user's, 18 Nov, after a round with I, II, III on the rows, the
-- frames and paper labels on the plates: not meaningful enough for the
-- clutter); a row on the page is in ink, and hovering links a row and its mark
-- both ways: a row under the mouse rings its mark on its map (the card
-- sheet's pencil ring); a mark under the mouse lights its rows
-- (Plate.Hovered). The meter is in that link too: a frame under the mouse
-- lights the rows on its map, and a row under the mouse lights its map's
-- frame (a zone's row, the frames of every map holding something of it).
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
-- piece. A keep that cannot fit is blocked: the footer's line says why in
-- red, the box and the cap line's frames shake, nothing is written.
--
-- Reached by the link under the open level's sittings (Left.lua's EntryItems,
-- `choose`; YourDiary.Choose), left by "Done", the ribbon (the page turned to
-- again: RefreshJourneyPage's opening), or another level, sitting, run, match
-- or map opened (Page.lua's Open*, which call Unchoose).
--
-- With the pad (choose-page.md, "Later: the gamepad", 18 Nov): the ticklist
-- is the left page of Your Diary's own scope while it is open
-- (UI/Journey/Pad.lua, group `choose`): its zones and rows one list keyed by
-- their moments, then Done. A on a row is its click (Tick), the pad on a row
-- its hover (its tooltip, its mark ringed, its map's frame lit), right goes
-- over to the plates and left comes back, B is Done. Picking the pad up or
-- putting it down leaves the ticklist as it is; every change to it (Fill,
-- Choose, Unchoose) asks the pad's look to find its words again
-- (Pad.Refresh: the rows are handed round as the list is filled). The
-- meter's frames are not stood on: they say again what the rows' ink says,
-- and a plate the pad stands on lights its frame and its rows, as a frame
-- under the mouse does (LightMap).
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
-- paraph and fading rule as an entry's, ENTRY), the title in the hand a size
-- up under it (`title`, FONT.noteWrittenLarge: it leads the zones' names in
-- the hand), the cap line (`cap`: its frames, the maps, `meter` px wide in
-- all and `frameH` tall, `frameGap` apart, the words `capGap` past them),
-- and the list from `list` (HEAD.list: where the entries begin, so the page
-- doesn't jump as it turns into the ticklist) down to `bottom` px above the
-- page's foot. Under the list the footer, as the link sheet's
-- (UI/Paper/LinkSheet.lua): a rule fading at both ends (`foot.rule` px above
-- the foot), the line saying what a tick did or why it was blocked at its left
-- (`foot.note` px above the foot, two lines high, always there: `noteH`), and
-- "Done" at its right in strong ink (its top `done` px above the foot, as
-- before, clear of the ribbons as the entries are), `foot.gap` from the line.
-- (The user's, 18 Nov, after the client round: the top was out of balance,
-- an empty two-line slot under the cap line leaving a hole over the list, and
-- Done too dim.)
-- A zone's row: its box `box` px at `boxX`, its name in the hand `nameX` in,
-- `place` px tall. A moment's row: `indent` px further in, its box `cardBox`,
-- its words in small type, `card` px tall; at its right the time. `gap` under a
-- zone's last row, so the next zone stands apart. No row has a second line: a
-- row's height never changes with its look. A list too short to scroll lends
-- its rows the scrollbar's width.
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
-- a faint fill `diaryFill`), a map not there (`free`, a graphite outline
-- alone, as faint as a row's box off the page, `faded.off`); `hot`, the
-- outline's alpha of a frame lit (under the mouse, or a row of its map under
-- the mouse).
-- The meter as one quiet unit under the title (the user's, 18 Nov, after the
-- title went up to 20 pt): `cap` leaves the title's descenders room;
-- `frameGap` 4 keeps the maps apart rather than one bar; the words `capGap` 8
-- past the meter, their middle `capY` px above the frames' (Friz's line box
-- holds its descenders under the words, so its middle sits low).
-- The meter is the right page's room as its plates share it (the user's, 18
-- Nov: "move on from 3 simple slots to what is happening on the right side";
-- one plate may take all of it): a frame for each plate, in their order on
-- the page, as wide as its card's share of the plates' area (the slot it was
-- drawn in, F+L's tucked print and TOP's caption over the plate included),
-- all of them `meter` px across with their gaps: one plate is one frame the
-- whole width. `frameMin`: no frame narrower, so a tucked print's stays a
-- frame and can be hovered (at 9 px tall, 9 is a square). Was three fixed
-- 13 px frames, 4 apart: `meter` widened from their 47 so a snapshot beside
-- a full plate is still told from it. An empty frame only where there is
-- room the page does not use: a piece whose plates were all left out (its
-- page says so in words), one frame the whole width; a page with one or two
-- plates has no free room, its layout gives them the page (LAYOUT[1], [2]).
-- A tick that changes the page eases the frames to their new widths
-- (`ease` s, the right page's own glide, UI/Journey/Glide.lua's GLIDE.secs
-- and its curve); anything else, and "Flat paper only", sets them at once.
-- The empty frame was ink at 0.5, darker than the diary's graphite: it
-- read stronger than a map on the page. Now the three inks step down from
-- the player's red through the diary's graphite to an outline barely there,
-- in the same inks and alphas as the rows' boxes beside them; the red fill
-- a wash (0.70) under its full outline, as a kept row's red box round its
-- tick, not a solid block.
-- `ring`: the pencil ring round a row's mark on its map (plate:SetRing, as
-- UI/Journey/CardSheet.lua's: radius, dashes, ...), in the leaders' pencil.
-- `shake`: the box (and the cap line's frames) on a blocked tick, `amp` px
-- either way, `times` there and back over `secs`, dying away.
local CHOOSE = {
    rubric = 20, title = 40, cap = 70, meter = 60, frameMin = 9, frameH = 9, frameGap = 4, capGap = 8, capY = 1,
    noteH = 28,
    list = HEAD.list, bottom = 70, done = 30, foot = { rule = 64, note = 58, gap = 10 },
    box = 13, boxX = 1, nameX = 21, place = 23, indent = 18, cardBox = 10, card = 18, gap = 10,
    faded = { outline = 0.55, tick = 0.80, tickW = 1, off = 0.38 }, thin = 1, red = 0.95, bold = 1.8, edge = 1.25,
    off = { name = 0.72 },
    strikeW = 1.2, strikeOver = 3,
    frames = { mine = 0.95, fill = 0.70, diary = 0.55, diaryFill = 0.25, free = 0.38, hot = 1 },
    ring = { r = 9, dashes = 9, share = 0.62, uneven = 0.25, wander = 0.8, bends = 4, step = 1.5, width = 1.4 },
    shake = { amp = 2.5, times = 3, secs = 0.45 },
    ease = YourDiary.GLIDE and YourDiary.GLIDE.secs or 0.28,
}
YourDiary.CHOOSE = CHOOSE

-- The words, furniture and ledger (the copywriter's §1; choose-page.md's
-- "Stable list"). A row's reason is its tooltip's line (ledger, capitalised);
-- the cap line and the line under it are furniture.
local WORDS = {
    title = L["Choose what's on this page"],
    cap = L["Three maps fit a page."],
    blocked = L["No room for it beside what you chose. Leave something out first."],
    -- A frame's tooltip: its zone, and whose choice it is; an empty one.
    yours = L["Your choice"],
    forYou = L["Chosen for you"],
    noMaps = L["No maps on this page"],
    noMapsHow = L["Tick a place to bring its map in"],
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

-- What a moment's row says: a person's name; a feature's mark's short
-- label for a list (Plate.RegisterMark's `label`: no day or time, the time
-- column has them; the user's, 18 Nov, after "Tarren Mill, yesterday at…"
-- and "Dun Garok Soldier, 1% h…" were cut short), else its card as its
-- editor describes it (Core/Custom.lua), else its mark's tooltip's title
-- (`tip`); the route's own kinds in their words (a stop and an arrival by
-- their sub-zone, which is never a heading).
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
    local values = type(rec) == "table" and ns.Custom.Values(rec.customOf or rec) or nil
    local mark = Plate.MARKS[m.kind]
    local short = mark and mark.label and mark.label(values, m)
    if type(short) == "string" and short ~= "" then return short end
    if spec and values then
        return spec.describe and spec.describe(values) or Capital(spec.label)
    end
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

local Tick, RowInk, LightFrames

-- The maps (their places top to bottom, as Recap.Choices' `row.plate`) an
-- item is on: a moment's its own, a zone's every one holding a row of it.
local function MapsOf(item)
    local maps = {}
    local rows = item and (item.card and { item.card } or (item.zone and item.zone.rows)) or {}
    for _, r in ipairs(rows) do
        if r.on and r.plate then maps[r.plate] = true end
    end
    return maps
end

local function Hover(row, over)
    row.hot = over or nil
    RowInk(row)
    if over then RingOn(row.item) else RingOff() end
    LightFrames(over and MapsOf(row.item) or nil)
end

local function BuildRow(list)
    local row = CreateFrame("Button", nil, list)
    row.list = list
    row.placeBox = Box(row, CHOOSE.box)
    row.cardBox = Box(row, CHOOSE.cardBox)
    row.name = Style.Text(row, FONT.noteWritten)
    row.name:SetWordWrap(false)
    row.time = Style.Text(row, FONT.small)
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
    -- A list too short to scroll has no scrollbar: its rows reach over the
    -- bar's room (the words and the time, and the mouse with them).
    local bar = row.list and row.list.bar
    local lend = (bar and not bar:IsShown()) and SCROLLBAR_WIDTH or 0
    row.time:ClearAllPoints()
    row.time:SetPoint("TOPRIGHT", lend - 2, -4)
    row:SetHitRectInsets(0, -lend, 0, 0)
    local rowW = LEFT_W - SCROLLBAR_WIDTH - 2 + lend
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

-- A frame of the cap line's: what its map holds, as Light's keys (nil: none).
local function KeysOn(k)
    local page = YourDiary.page
    local keys, any = {}, false
    for _, zone in ipairs(page and page.choices and page.choices.zones or {}) do
        for _, r in ipairs(zone.rows) do
            if r.on and r.plate == k then
                for _, key in ipairs(r.keys) do keys[key], any = true, true end
            end
        end
    end
    return any and keys or nil
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
    f:SetSize(CHOOSE.frameMin, CHOOSE.frameH)
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

-- The frames' widths for plates drawn in `slots` ({ w, h } each, in their
-- order): `meter` px less the gaps, shared by the cards' areas, none under
-- `frameMin`, whole pixels adding up to the meter (the remainders to the
-- largest shares). No slots: one frame the whole width (an empty page).
local function Widths(slots)
    local n = #slots
    if n == 0 then return { CHOOSE.meter } end
    local room = CHOOSE.meter - (n - 1) * CHOOSE.frameGap
    local area, total = {}, 0
    for i, s in ipairs(slots) do
        area[i] = math.max((s.w or 0) * (s.h or 0), 1)
        total = total + area[i]
    end
    -- The narrow ones held at the least, the rest sharing what is left.
    local raw, held = {}, {}
    for _ = 1, n do
        local free, rest = room, 0
        for i = 1, n do
            if held[i] then free = free - CHOOSE.frameMin else rest = rest + area[i] end
        end
        local again = false
        for i = 1, n do
            if not held[i] then
                raw[i] = free * area[i] / rest
                if raw[i] < CHOOSE.frameMin then held[i], again = true, true end
            else
                raw[i] = CHOOSE.frameMin
            end
        end
        if not again then break end
    end
    local widths, used, order = {}, 0, {}
    for i = 1, n do
        widths[i] = math.floor(raw[i])
        used = used + widths[i]
        order[i] = i
    end
    table.sort(order, function(a, b)
        local ra, rb = raw[a] - widths[a], raw[b] - widths[b]
        if ra ~= rb then return ra > rb end
        return a < b
    end)
    for k = 1, room - used do
        local i = order[(k - 1) % n + 1]
        widths[i] = widths[i] + 1
    end
    return widths
end
YourDiary.MeterWidths = Widths

-- The slots the piece's plates were drawn in (DrawPlates keeps them,
-- piece.drawnSlots, there while a plate's whole map is open); where they
-- are not there for these plates (the whole map open on a recap built
-- again), the slots its page gives (PlatesOf's layout: F+L there as FL,
-- TOP as its plate).
local function SlotsOf(piece, count)
    local drawn = piece.drawnSlots
    if drawn and #drawn == count then return drawn end
    local _, layout = YourDiary.PlatesOf(piece)
    local slots = {}
    for i = 1, count do
        local s = layout and layout[i]
        if not s then return {} end
        slots[i] = { w = s.w, h = s.h }
    end
    return slots
end

-- Eased out, quartic: the right page's glide's curve (UI/Journey/Glide.lua).
local function Eased(t) return 1 - (1 - t) ^ 4 end

-- The frames set to `widths` from the left, at once, or eased from where
-- they stood (`from`: { x, w } each; a frame coming grows from nothing at
-- its place).
local function Meter(ch, widths, from)
    local x, to = 0, {}
    for k, f in ipairs(ch.frames) do
        local w = widths[k]
        f:SetShown(w ~= nil)
        if w then
            to[k] = { x = x, w = w }
            PlaceBox(f, x, -CHOOSE.cap)
            f:SetWidth(w)
            f.w = w
            x = x + w + CHOOSE.frameGap
        end
    end
    local driver = ch.meterEase
    driver:SetScript("OnUpdate", nil)
    if not from then return end
    local t = 0
    local function Step(_, elapsed)
        t = t + (elapsed or 0)
        local e = Eased(math.min(t / CHOOSE.ease, 1))
        for k, f in ipairs(ch.frames) do
            local a, b = from[k] or (to[k] and { x = to[k].x, w = 0 }), to[k]
            if a and b then
                local w = math.max(a.w + (b.w - a.w) * e, 1)
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", a.x + (b.x - a.x) * e, -CHOOSE.cap)
                f:SetWidth(w)
            end
        end
        if t >= CHOOSE.ease then
            driver:SetScript("OnUpdate", nil)
            for k, f in ipairs(ch.frames) do
                if to[k] then PlaceBox(f, to[k].x, -CHOOSE.cap) f:SetWidth(to[k].w) end
            end
        end
    end
    driver:SetScript("OnUpdate", Step)
    Step(nil, 0)
end

-- `kind`: "mine" (red), "diary" (faded), or nil (no such map on the page);
-- `hot`: lit (its outline at `frames.hot`).
local function FrameLook(f, kind, hot)
    local FR = CHOOSE.frames
    local c, edge, fill = Style.GRAPHITE, FR.free, nil
    if kind == "mine" then
        c, edge, fill = Style.RUBRIC, FR.mine, FR.fill
    elseif kind == "diary" then
        c, edge, fill = Style.GRAPHITE, FR.diary, FR.diaryFill
    end
    if hot and kind then edge = FR.hot end
    for _, t in ipairs(f.edges) do t:SetColorTexture(c[1], c[2], c[3], edge) end
    f.fill:SetColorTexture(c[1], c[2], c[3], fill or 0)
    f.fill:SetShown(fill ~= nil)
    f.kind, f.hot = kind, (hot and kind) and true or nil
end

-- The frames of `maps` (a set of map places; nil: none) lit, the rest not.
function LightFrames(maps)
    local page = YourDiary.page
    local ch = page and page.chooser
    if not ch then return end
    for k, f in ipairs(ch.frames) do FrameLook(f, f.kind, maps and maps[k]) end
end

-- A frame's tooltip: its map's zone and whose choice it is; an empty
-- frame (no plate on the page) what is missing and how it fills.
local function FrameTip(f)
    if not f.kind then return { { WORDS.noMaps }, { WORDS.noMapsHow, 1, 1, 1, true } } end
    return { { ZoneName(f.mapID) }, { f.kind == "mine" and WORDS.yours or WORDS.forYou, 1, 1, 1, true } }
end

-- Map `k` lit (its frame and the rows on it), nil for none: a frame under
-- the mouse, or the pad on the plate of that map (UI/Journey/Pad.lua).
local function LightMap(k)
    LightFrames(k and { [k] = true } or nil)
    Light(k and KeysOn(k) or nil)
end
YourDiary.ChooseLightMap = LightMap

-- A frame under the mouse: it lit, and the rows on its map with it.
local function FrameHover(f, over)
    LightMap(over and f.index or nil)
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

    ch.title = Style.Text(ch, FONT.noteWrittenLarge)
    ch.title:SetPoint("TOPLEFT", 0, -CHOOSE.title)
    ch.title:SetText(WORDS.title)

    -- The frames shake on a blocked tick (Shake: x, y from the page's
    -- corner), so the words are placed from the page, not from a frame.
    -- A frame for each plate a page can hold (Recap.PLATES.max), placed by
    -- Fill (Meter).
    ch.frames = {}
    for k = 1, ns.JourneyRecap.PLATES.max do
        local f = Frame(ch)
        f.index = k
        PlaceBox(f, 0, -CHOOSE.cap)
        f:EnableMouse(true)
        Style.Tooltip(f, FrameTip, "ANCHOR_RIGHT", FrameHover)
        ch.frames[k] = f
    end
    ch.meterEase = CreateFrame("Frame", nil, ch)
    local capX = CHOOSE.meter + CHOOSE.capGap
    ch.cap = Style.Text(ch, FONT.small)
    ch.cap:SetPoint("LEFT", ch, "TOPLEFT", capX, -(CHOOSE.cap + CHOOSE.frameH / 2) + CHOOSE.capY)
    ch.cap:SetWidth(LEFT_W - capX)
    ch.cap:SetJustifyH("LEFT")

    local listH = BOOK_H - CHOOSE.list - CHOOSE.bottom
    ch.list = ns.UI.Journal.List(ch, ENTRY.unit, math.ceil(listH / ENTRY.unit), BuildRow, UpdateRow, LEFT_W,
        "TOPLEFT", 0, -CHOOSE.list)
    ch.list:SetNumRows(math.floor(listH / ENTRY.unit))

    -- The footer, as the link sheet's: the rule fading at both ends, the
    -- line at its left (its foot on Done's, one line or two), Done at its
    -- right in strong ink. (Check in the client: Done at the left page's
    -- right foot must stay clear of the ribbons hanging there.)
    local FOOT, INK = CHOOSE.foot, Style.INK
    local half = (LEFT_W - 2) / 2
    ch.footRule = {}
    for i, alpha in ipairs({ { 0, Style.HAIRLINE }, { Style.HAIRLINE, 0 } }) do
        local t = ch:CreateTexture(nil, "ARTWORK")
        t:SetSize(half, 1)
        t:SetPoint("TOPLEFT", (i - 1) * half, -(BOOK_H - FOOT.rule))
        Style.Shade(t, "HORIZONTAL", INK[1], INK[2], INK[3], alpha[1], alpha[2])
        ch.footRule[i] = t
    end
    ch.done = Style.Link(ch, FONT.strong, function() YourDiary.Unchoose() end)
    ch.done:SetPoint("TOPRIGHT", -2, -(BOOK_H - CHOOSE.done - 18))
    ch.done:SetText(WORDS.done)
    -- (its own ink, so the mouse leaving gives back strong ink, not the
    -- link's usual)
    local S = Style.INK_STRONG
    ch.done:SetColor(S[1], S[2], S[3])
    ch.note = Style.Text(ch, FONT.small)
    ch.note:SetPoint("TOPLEFT", 0, -(BOOK_H - FOOT.note))
    ch.note:SetSize(LEFT_W - 2 - ch.done:GetWidth() - FOOT.gap, CHOOSE.noteH)
    ch.note:SetJustifyH("LEFT")
    ch.note:SetJustifyV("BOTTOM")
    ch.note:SetWordWrap(true)
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

    -- The meter: the plates' share of the page; eased where a tick changed
    -- it (Tick's page.chooseEase), the page on the screen and not laid flat.
    local count = #choices.plates
    local widths = Widths(SlotsOf(piece, count))
    local from
    if page.chooseEase and ns.Setting("flatSheets") ~= true and ch:IsVisible() then
        from = {}
        for k, f in ipairs(ch.frames) do
            if f:IsShown() and f.w then from[k] = { x = f.x or 0, w = f.w } end
        end
        local same = true
        for k = 1, #ch.frames do
            local a = from[k]
            if (a and a.w) ~= widths[k] then same = false end
        end
        if same then from = nil end
    end
    Meter(ch, widths, from)
    for k, f in ipairs(ch.frames) do
        local p = choices.plates[k]
        f.mapID = p and p.mapID or nil
        FrameLook(f, p and (p.mine and "mine" or "diary") or nil)
    end
    ch.cap:SetText(WORDS.cap)
    local blocked = page.chooseBlocked == true
    ch.note:SetText(blocked and WORDS.blocked or page.chooseNote or "")
    local ink = blocked and Style.RUBRIC or Style.INK_FADED
    ch.note:SetTextColor(ink[1], ink[2], ink[3], 1)

    page.chooseLit = nil
    ch.list:SetData(Items(choices, now), true)
    -- (the rows handed round: the pad's box finds its words again; with the
    -- pad down this does nothing)
    ns.UI.Pad.Refresh()
end

-- The ticklist for the piece the right page shows, in place of the left
-- page; where a run, a match or a map was on the right page, the piece's
-- plates drawn in its place.
local function Choose()
    local page = YourDiary.page
    if not page then return end
    local piece = Shown()
    if not CanChoose(piece) then return end
    local ch = page.chooser or Build(page)
    GameTooltip:Hide()
    -- (`chooseLand`: the pad, if in hand, lands on the list's first row, from
    -- the link or a plate's menu alike; UI/Journey/Pad.lua)
    page.choosing, page.chooseBlocked, page.chooseNote, page.chooseLand = true, nil, nil, true
    LeftShown(page, false)
    ch:Show()
    page.mode, page.fullMap, page.runVisit, page.matchId, page.session = "plates", nil, nil, nil, nil
    YourDiary.DrawRight()
    Fill()
    ch.list:SetOffset(0)
    ns.UI.Pad.Refresh()
end

-- The left page given back ("Done", or anything that opens something
-- else). `quiet`: nothing drawn again (a caller draws both pages again).
local function Unchoose(quiet)
    local page = YourDiary.page
    if not (page and page.choosing) then return end
    RingOff()
    page.choosing, page.chooseBlocked, page.chooseNote, page.choices, page.chooseLit = nil, nil, nil, nil, nil
    page.chooseLand = nil
    page.chooser:Hide()
    LeftShown(page, true)
    if not quiet then
        YourDiary.Rebuild(true, page.open)
        if page.mode == "plates" then YourDiary.DrawRight() end
        ns.UI.Pad.Refresh()
    end
end

-- A row clicked: Chosen.Tick on it. Blocked, the footer's line says why and
-- the box and the frames shake; else the recap is built again and the page
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
        for _, f in ipairs(page.chooser.frames) do Shake(f) end
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
    page.chooseEase = true
    YourDiary.Glide.Around(function() ns.UI.RefreshJourneyPage(false) end)
    page.chooseEase = nil
end

YourDiary.CanChoose, YourDiary.Choose, YourDiary.Unchoose, YourDiary.FillChoose = CanChoose, Choose, Unchoose, Fill
YourDiary.ShownPiece = Shown

