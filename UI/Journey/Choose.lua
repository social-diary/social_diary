-- "Choose what's on this page" (.claude/features/choose-page.md, Phase 3):
-- the left page of Your Diary turned into a ticklist for the piece the right
-- page shows. Everything the diary noticed there, grouped by place (a plate is
-- a place), in time order; a place on the page opens its cards under it, a
-- place off it stays closed. Each row is a box, its name, its time, and under
-- a row that is off the page, why.
--
-- A box has the four looks of Recap.Choices (Core/Chosen.lua): the diary's
-- pick a faded tick, the diary's leaving off an empty box, the player's keep a
-- red tick, the player's leaving out a red cross with the name struck through
-- in red (the user's, 18 Nov: the diary's is faded, the player's is the
-- rubric's red; no "the diary's" link and no way back to the diary's choice).
-- A click on a row that shows leaves it out, on one that doesn't keeps it
-- (Chosen.Tick); the recap is built again, the right page redrawn, then the
-- ticklist built from the new piece (its plates and their margins' leftOff are
-- the new page's). The cap line at the top says how many places fit, three
-- small frames beside it: red filled the player's, faded the diary's, empty
-- free. A keep onto a page whose three places are all the player's is
-- blocked: the cap line turns red and says why, the box shakes, nothing is
-- written.
--
-- Reached by the link under the open level's sittings (Left.lua's EntryItems,
-- `choose`; YourDiary.Choose), left by "Done", the ribbon (the page turned to
-- again: RefreshJourneyPage's opening), or another level, sitting, run, match
-- or map opened (Page.lua's Open*, which call Unchoose). With the pad in hand
-- the link is not offered (the gamepad is a later phase, the user's): the
-- ticklist is mouse-only, so it closes as the pad is picked up.
--
-- The words are draft copy (the mock's): Phase 4's copywriter round settles
-- them. The module and its siblings: UI/Journey/Look.lua.

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local Style = ns.Style
local FONT = Style.FONT
local Text = ns.UI.JourneyText
local Format = ns.UI.Format
local YourDiary = ns.UI.YourDiary

local BOOK = ns.UI.Journal.BOOK
local LEFT_X, LEFT_W, BOOK_H = BOOK.LEFT_X, BOOK.LEFT_W, BOOK.BOOK_H
local SCROLLBAR_WIDTH = ns.UI.SCROLLBAR_WIDTH

local HEAD, ENTRY = YourDiary.HEAD, YourDiary.ENTRY

-- The ticklist's look, down from the left page's top as the entries are
-- (HEAD): the level's rubric where the character's name stands (`rubric`, its
-- paraph and fading rule as an entry's, ENTRY), the title in the hand under it
-- (`title`), the cap line (`cap`: its three frames `frame` px wide and
-- `frameH` tall, `frameGap` apart, the words `capGap` past the last, `capW`
-- wide, so the blocked words wrap to two lines under the title), and the list
-- from `list` down to `bottom` px above the page's foot, where "Done" stands
-- (`done`, its top that far above the foot, clear of the ribbons as the
-- entries are).
-- A place's row: its box `box` px at `boxX`, its name in the hand `nameX` in,
-- the time at the row's right in small type; `place` px tall, `reason` more
-- with the line under it. A card's row: `indent` px further in, its box
-- `cardBox`, its words in small type in ink, `card` px tall (`reason` more).
-- `gap` under a place's last card, so the next place stands apart.
-- The boxes are drawn by hand (Box): an outline a little off square, a tick
-- that runs past the box's top as a quick hand's does, or a cross. The
-- diary's in graphite (`faded`: its outline and tick alpha, `thin` px), the
-- player's in the rubric (`red`, `bold` px for the tick and cross).
-- `strike` is the red line through a name left out: `strikeW` px thick, a
-- little longer than the name (`strikeOver`).
-- `shake`: the box on a blocked tick, `amp` px either way, `times` there and
-- back over `secs`, dying away.
local CHOOSE = {
    rubric = 20, title = 38, cap = 66, frame = 13, frameH = 10, frameGap = 3, capGap = 7, capW = 180,
    list = 96, bottom = 42, done = 30,
    box = 13, boxX = 1, nameX = 21, place = 23, reason = 13, indent = 18, cardBox = 10, card = 18, gap = 4,
    faded = { outline = 0.55, tick = 0.80 }, thin = 1, red = 0.95, bold = 1.8, edge = 1.25,
    strikeW = 1.2, strikeOver = 3,
    shake = { amp = 2.5, times = 3, secs = 0.45 },
}
YourDiary.CHOOSE = CHOOSE

-- The words, furniture and ledger (the copywriter's §1; settled in the
-- copywriter round, choose-page.md Phase 4). Reasons are lowercase: they
-- sit faded under a row's name, as margin words do.
local WORDS = {
    title = L["Choose what's on this page"],
    cap = L["Three places fit."],
    blocked = L["Three places fit, and you've chosen three. Leave one out first."],
    done = L["Done"],
    reason = {
        next = L["next in line"],
        noRoom = L["no room"],
        minor = L["too small for a plate of its own"],
        marginRoom = L["no room in the margin"],
        byYou = L["left out by you"],
    },
    madeRoom = L["made room for %s"],
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

-- A place's name: its zone's; where two places of the list share one, the
-- sub-zone of its lead moment's stop after it, where it has one.
local function PlaceName(place, twice)
    local name = Text.MapName(place.mapID) or L["A stop"]
    local seg = place.lead and place.lead.seg
    if twice[name] and seg and seg.subZone and seg.subZone ~= "" and seg.subZone ~= name then
        name = Fmt(L["%1$s, %2$s##zone and sub-zone"], name, seg.subZone)
    end
    return name
end

-- What a card's row says: a person's name; a feature's card as its editor
-- describes it (Core/Custom.lua), else its mark's tooltip's title
-- (Plate.RegisterMark's `tip`); the route's own kinds in their words.
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
    local mark = ns.UI.JourneyPlate.MARKS[m.kind]
    local title = mark and mark.tip and mark.tip(m, now)
    if type(title) == "string" and title ~= "" then return title end
    return spec and Capital(spec.label) or Capital(m.kind)
end

-- Why a row is not on the page, in words; nil where it is.
local function Reason(row, names)
    if not row.reason then return nil end
    if row.reason == "madeRoom" then
        local kept = row.madeRoomFor
        return Fmt(WORDS.madeRoom, kept and names[kept] or L["A stop"])
    end
    return WORDS.reason[row.reason]
end

-- The list's items for `choices`: a place, then (where it is on the page)
-- its cards.
local function Items(choices, now)
    local names, seen, twice = {}, {}, {}
    for _, place in ipairs(choices.places) do
        local name = Text.MapName(place.mapID) or ""
        if seen[name] then twice[name] = true end
        seen[name] = true
    end
    for _, place in ipairs(choices.places) do names[place] = PlaceName(place, twice) end
    local items = {}
    for _, place in ipairs(choices.places) do
        local why = Reason(place, names)
        items[#items + 1] = { place = place, row = place, label = names[place], time = Format.Clock(place.t or 0),
            why = why, height = CHOOSE.place + (why and CHOOSE.reason or 0) }
        if place.on then
            local at = items[#items].time
            for _, c in ipairs(place.cards) do
                local cwhy = Reason(c, names)
                -- (a card's time only where it is not its place's: the
                -- same clock down a column of cards read as noise)
                local time = Format.Clock(c.t or 0)
                items[#items + 1] = { card = c, row = c, label = CardLabel(c.moment, now),
                    time = time ~= at and time or nil, why = cwhy,
                    height = CHOOSE.card + (cwhy and CHOOSE.reason or 0) }
            end
            items[#items].height = items[#items].height + CHOOSE.gap
        end
    end
    return items
end

--------------------------------------------------------------------------
-- The box, drawn by hand
--------------------------------------------------------------------------

-- A box `s` px: its outline a little off square, a tick, a cross; each a
-- pen stroke (Style.Stroke) whose ink and weight Look sets.
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

-- The box as `look` has it (Recap.Choices' looks).
local function Look(box, look)
    local R, G, F = Style.RUBRIC, Style.GRAPHITE, CHOOSE.faded
    local mine = look == "keep" or look == "out"
    if mine then
        Ink(box.outline, R, CHOOSE.red, CHOOSE.edge, true)
    else
        Ink(box.outline, G, F.outline, CHOOSE.thin, true)
    end
    Ink(box.tick, mine and R or G, mine and CHOOSE.red or F.tick, mine and CHOOSE.bold or CHOOSE.edge,
        look == "keep" or look == "diary")
    Ink(box.cross, R, CHOOSE.red, CHOOSE.bold * 0.85, look == "out")
    box.look = look
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
-- The rows
--------------------------------------------------------------------------

local Tick

local function BuildRow(list)
    local row = CreateFrame("Button", nil, list)
    row.placeBox = Box(row, CHOOSE.box)
    row.cardBox = Box(row, CHOOSE.cardBox)
    row.name = Style.Text(row, FONT.noteWritten)
    row.name:SetWordWrap(false)
    row.time = Style.Text(row, FONT.small)
    row.time:SetPoint("TOPRIGHT", -2, -5)
    row.time:SetJustifyH("RIGHT")
    row.why = Style.Text(row, FONT.small)
    row.why:SetWordWrap(false)
    row.strike = row:CreateTexture(nil, "OVERLAY")
    row.strike:SetHeight(CHOOSE.strikeW)
    local R = Style.RUBRIC
    row.strike:SetColorTexture(R[1], R[2], R[3], CHOOSE.red)
    -- Under the mouse its words darken, as a ledger's row does (no light).
    row:SetScript("OnEnter", function(self)
        self.hot = true
        YourDiary.ChooseRowInk(self)
    end)
    row:SetScript("OnLeave", function(self)
        self.hot = nil
        YourDiary.ChooseRowInk(self)
    end)
    row:SetScript("OnClick", function(self) Tick(self) end)
    return row
end

-- A row's words in their ink: a name left out faded (its strike red), the
-- rest in ink, darker under the mouse; a reason the player's in red, the
-- diary's faded.
local function RowInk(row)
    local item = row.item
    if not item then return end
    local look = item.row.look
    local ink
    if look == "out" then
        ink = Style.INK_FADED
    elseif item.card then
        ink = row.hot and Style.INK_STRONG or Style.INK
    else
        ink = row.hot and Style.INK_STRONG or (look == "diaryOff" and Style.INK or Style.INK_STRONG)
    end
    row.name:SetTextColor(ink[1], ink[2], ink[3], 1)
    local why = item.row.reason == "byYou" and Style.RUBRIC or Style.INK_FADED
    row.why:SetTextColor(why[1], why[2], why[3], 1)
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
    Look(box, item.row.look)

    row.name:SetFontObject(card and FONT.small or FONT.noteWritten)
    row.name:ClearAllPoints()
    row.name:SetPoint("TOPLEFT", x + CHOOSE.nameX - (card and 3 or 0), card and -3 or -3)
    row.name:SetWidth(0)
    row.name:SetText(item.label)
    row.time:SetText(item.time or "")
    local rowW = LEFT_W - SCROLLBAR_WIDTH - 2
    local most = rowW - (x + CHOOSE.nameX) - (row.time:GetUnboundedStringWidth() or 0) - 6
    local nameW = row.name:GetUnboundedStringWidth() or 0
    if nameW > most then
        row.name:SetWidth(most)
        nameW = most
    end

    row.why:ClearAllPoints()
    row.why:SetPoint("TOPLEFT", x + CHOOSE.nameX - (card and 3 or 0), -(h - 2))
    row.why:SetWidth(rowW - (x + CHOOSE.nameX))
    row.why:SetText(item.why or "")
    row.why:SetShown(item.why ~= nil)

    -- Left out by the player: struck through in red, a little past both ends.
    local out = item.row.look == "out"
    row.strike:ClearAllPoints()
    row.strike:SetPoint("LEFT", row.name, "LEFT", -CHOOSE.strikeOver / 2, card and 0 or -1)
    row.strike:SetWidth(math.max(1, nameW + CHOOSE.strikeOver))
    row.strike:SetShown(out)
    RowInk(row)
end

--------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------

-- One of the cap line's frames: an outline, and its fill.
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

-- `kind`: "mine" (red, filled), "diary" (faded), or nil (free).
local function FrameLook(f, kind)
    local c, edge, fill = Style.INK, 0.5, nil
    if kind == "mine" then
        c, edge, fill = Style.RUBRIC, CHOOSE.red, 0.85
    elseif kind == "diary" then
        c, edge, fill = Style.GRAPHITE, CHOOSE.faded.outline, 0.30
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
        f:SetPoint("TOPLEFT", (k - 1) * (CHOOSE.frame + CHOOSE.frameGap), -CHOOSE.cap - 2)
        ch.frames[k] = f
    end
    ch.cap = Style.Text(ch, FONT.small)
    ch.cap:SetPoint("TOPLEFT", 3 * (CHOOSE.frame + CHOOSE.frameGap) - CHOOSE.frameGap + CHOOSE.capGap, -CHOOSE.cap)
    ch.cap:SetWidth(CHOOSE.capW)
    ch.cap:SetWordWrap(true)

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
        FrameLook(f, k <= choices.mine and "mine" or (k <= choices.mine + choices.diary and "diary" or nil))
    end
    local blocked = page.chooseBlocked == true
    ch.cap:SetText(blocked and WORDS.blocked or WORDS.cap)
    local ink = blocked and Style.RUBRIC or Style.INK
    ch.cap:SetTextColor(ink[1], ink[2], ink[3], 1)

    ch.list:SetData(Items(choices, now), true)
end

-- The ticklist for the piece the right page shows, in place of the left
-- page: its plates drawn first where a run, a match or a map was there.
local function Choose()
    local page = YourDiary.page
    if not page or YourDiary.Solo() then return end
    local piece = Shown()
    if not CanChoose(piece) then return end
    local ch = page.chooser or Build(page)
    GameTooltip:Hide()
    page.choosing, page.chooseBlocked = true, nil
    LeftShown(page, false)
    ch:Show()
    if page.mode ~= "plates" then
        page.mode, page.fullMap, page.runVisit, page.matchId, page.session = "plates", nil, nil, nil, nil
        YourDiary.DrawRight()
    end
    Fill()
    ch.list:SetOffset(0)
end

-- The left page given back ("Done", or anything that opens something
-- else). `quiet`: no list built again (a caller rebuilds it).
local function Unchoose(quiet)
    local page = YourDiary.page
    if not (page and page.choosing) then return end
    page.choosing, page.chooseBlocked, page.choices = nil, nil, nil
    page.chooser:Hide()
    LeftShown(page, true)
    if not quiet then
        YourDiary.Rebuild(true, page.open)
    end
end

-- A row clicked: Chosen.Tick on it. Blocked, the cap line says why and the
-- box shakes; else the recap is built again and the page drawn again,
-- staying on this piece (page.holdAt, as a card changed does), and the
-- ticklist with it (RefreshJourneyPage calls Fill).
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
    Style.PlaySound("write")
    page.holdAt = piece.from
    GameTooltip:Hide()
    ns.UI.RefreshJourneyPage(false)
end

YourDiary.CanChoose, YourDiary.Choose, YourDiary.Unchoose, YourDiary.FillChoose = CanChoose, Choose, Unchoose, Fill
YourDiary.ShownPiece = Shown

-- The pad picked up with the ticklist open: it is mouse-only for now (the
-- gamepad is a later phase), so the left page is given back before the
-- page's own handler (UI/Journey/Pad.lua, loaded after this) builds it for
-- the pad.
ns.UI.Pad.Input.OnChange(function()
    local page = YourDiary.page
    if page and page.choosing and YourDiary.Solo() then Unchoose(true) end
end)
