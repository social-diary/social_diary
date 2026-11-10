-- Your Diary's left page (JRN-11, JRN-13, JRN-15, JRN-22, JRN-23): the
-- character at its top (FillHeader), and the recap as the virtual list's
-- items (EntryItems): the rubrics, the open entry's prose with its names
-- made links (ToPerson), the player's note, the hindsight lines and the
-- ledger of zones, each row built and filled (BuildEntryRow,
-- UpdateEntryRow) with its faces and dot leaders. Under the open entry's
-- rubric, where it was played in more than one sitting or has a run page
-- (not spliced: Recap.Pieces), its sittings, each with its runs indented
-- under it (SITTINGS): the right page's contents for that level. A rubric
-- opens its level at its newest sitting, a sitting's line that sitting, a
-- run's line or a recorded run's row in the ledger its page, and a zone's
-- row its map (YourDiary.OpenLevel, OpenPiece, OpenRun, OpenFull:
-- Page.lua's). The run being played lays out its map instead, either row
-- (LiveRun), to trace the way through as it goes. With the pad in hand
-- (Solo) the list is the open level alone, chevrons either side of its
-- rubric (Chevrons, SOLO): UI/Journey/Pad.lua.
--
-- The module and its siblings: UI/Journey/Look.lua.

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local Style = ns.Style
local FONT = Style.FONT
local Text = ns.UI.JourneyText
local Plate = ns.UI.JourneyPlate
local YourDiary = ns.UI.YourDiary

local BOOK = ns.UI.Journal.BOOK
local LEFT_W = BOOK.LEFT_W
local SCROLLBAR_WIDTH = ns.UI.SCROLLBAR_WIDTH

local ENTRY, LEDGER, PARAPHS, FACES = YourDiary.ENTRY, YourDiary.LEDGER, YourDiary.PARAPHS, YourDiary.FACES
local SITTINGS, SOLO = YourDiary.SITTINGS, YourDiary.SOLO
-- A battleground's line under its sitting (UI/Journey/Match.lua) hangs a
-- pennant where a run's hangs its doorway, in the doorway's ink
-- (LEDGER.door): its pole `pole` by `h` px, its flag `w` px out and `flag`
-- px deep at the pole, drawn in `pieces` bands narrowing to its point.
local BATTLE = { pole = 1.2, h = 10, w = 7, flag = 5, pieces = 4 }

--------------------------------------------------------------------------
-- The character
--------------------------------------------------------------------------

-- Whose road: the name as the bookplate has it, then "Level 14 Tauren
-- Hunter".
local function FillHeader()
    local page = YourDiary.page
    local own = ns.ownGUID and ns.OwnCharacters()[ns.ownGUID] or {}
    local name = table.concat({ own.first or ns.Plain(UnitName("player")) or "", own.surname or "" }, " ")
        :gsub("%s+$", "")
    page.name:SetFontObject(FONT.title)
    page.name:SetText(Text.Upper(name))
    if (page.name:GetUnboundedStringWidth() or 0) > LEFT_W then page.name:SetFontObject(FONT.titleSmall) end

    local level = ns.Plain(UnitLevel("player"))
    local race, class = ns.Plain(UnitRace("player")), ns.Plain(UnitClass("player"))
    local parts = {}
    if type(level) == "number" and level > 0 then parts[#parts + 1] = Fmt(L["Level %d"], level) end
    if type(race) == "string" and race ~= "" then parts[#parts + 1] = race end
    if type(class) == "string" and class ~= "" then parts[#parts + 1] = class end
    page.who:SetText(table.concat(parts, " "))
end

-- A name is a way to their page: People, open at them; a stranger's
-- opens their page pencilled in, the glimpse (the stranger-glimpse
-- proposal, 5 Nov 2026). Asked first: with neither (a stale strip whose
-- record the buffer has just forgotten), nothing happens, no page turns and
-- no sound, rather than an empty People page. Every name on Your Diary
-- (faces, prose, margin strips, the "met" strip, the witness card, the
-- dungeon notes) comes here.
local function ToPerson(guid)
    if not (guid and ns.UI.Journal.Route(guid)) then return end
    GameTooltip:Hide()
    ns.UI.Journal.TurnTo("people")
    ns.UI.SelectPerson(guid)
end

--------------------------------------------------------------------------
-- The entries (left page)
--------------------------------------------------------------------------

-- How tall `text` wraps in `font` across the entries' text width, on a
-- font string of the page's own that is never shown.
local function Measure(font, text)
    local page = YourDiary.page
    local m = page.measure
    m:SetFontObject(font)
    m:SetText(text)
    return math.ceil(m:GetStringHeight() or 0)
end

-- Whether Text.Lines opened `e` with its dateline (where and when it began),
-- which is set in faded ink. Mirrors JourneyText's Opening.
local function HasOpening(e)
    if e.kind == "week" then return e.reached ~= nil end
    return e.known and (e.first or e.reached ~= nil)
end

-- The names in an entry's prose made links to their pages (JRN-22): the
-- people from the diary crossed there, by the name the prose gives them,
-- the longest first so "Koko Skybluff" is never cut to "Koko".
local LINK = "|Hsdperson:%s|h|cff" .. Style.HEX.accent .. "%s|r|h"

local function NamesOf(e)
    local names, seen = {}, {}
    local function Add(guid)
        if not guid or seen[guid] then return end
        seen[guid] = true
        local name = ns.Characters.FullName(guid) or ns.Characters.Name(guid)
        if name and name ~= "" then names[#names + 1] = { name = name, guid = guid } end
    end
    for _, face in ipairs(e.faces or {}) do Add(face.guid) end
    for _, person in ipairs(e.people or {}) do
        if ns.Diary.IsDiary(person.guid) then Add(person.guid) end
    end
    table.sort(names, function(a, b) return #a.name > #b.name end)
    return names
end

local function Linked(line, names)
    local marks = {}
    for i, n in ipairs(names) do
        local pattern = n.name:gsub("%p", "%%%0")
        line = line:gsub(pattern, function()
            marks[#marks + 1] = LINK:format(n.guid, n.name)
            return "\001" .. #marks .. "\002"
        end)
    end
    return (line:gsub("\001(%d+)\002", function(k) return marks[tonumber(k)] end))
end

-- An entry's pieces, one a sitting it was played in (Recap.Pieces, worked
-- out as it is first asked and kept on the entry).
local function PiecesOf(e)
    local page = YourDiary.page
    return ns.JourneyRecap.Pieces(ns.Journey.For(ns.ownGUID), e, page.ctx or {})
end

-- The piece of `e` the right page shows, and its index: the one opened
-- (page.piece, kept with the entry it is of, so a stale index never
-- carries to another entry), else the newest. Nil where `e` is spliced:
-- the entry is drawn whole, as it always was.
local function OpenPieceOf(e)
    local page = YourDiary.page
    if not e then return nil end
    local pieces = PiecesOf(e)
    if e.spliced or #pieces == 0 then return nil end
    local k = page.pieceOf == e and page.piece or nil
    if not (k and pieces[k]) then k = #pieces end
    return pieces[k], k
end

-- One level at a time: the pad in hand (ns.UI.Pad.Input, asked as the
-- list is built; UI/Journey/Pad.lua builds it again as the hand changes).
local function Solo()
    local Pad = ns.UI.Pad
    return Pad ~= nil and Pad.Input.Active() == true
end

-- The recap as list items: the prologue, then per entry its rubric. Only
-- the open entry says more (journey-revamp-plan §3): its sittings and
-- their runs where it is not spliced (SITTINGS), its paragraphs, the
-- player's note in their hand, the hindsight lines, then its ledger of
-- zones. A closed entry is its rubric and faces alone, so wherever the
-- list stands, the first thing under the character is a rubric, never
-- another level's zone rows. Returns the items and the index of each
-- entry's rubric.
-- With the pad in hand (Solo) the open entry alone, from its rubric down:
-- no prologue and no closed rubrics (rubrics holds the open one's only),
-- the rubric `solo`, with whether a level lies `older` and `newer` for
-- its chevrons (SOLO).
local function EntryItems(recap, now, fights)
    local page = YourDiary.page
    local items, rubrics = {}, {}
    local solo = Solo()
    local function Add(item) items[#items + 1] = item end
    local prologue = not solo and Text.Prologue(recap.prologue) or nil
    if prologue then
        Add({ text = prologue, font = FONT.faded, height = Measure(FONT.faded, prologue) + ENTRY.prologue })
    end
    for i, e in ipairs(recap.entries) do
        -- Closed rubrics close up; the open entry stands apart.
        local open = i == page.open
        if solo then
            -- (one level at a time: the others are a D-pad press away)
        elseif open and (i > 1 or prologue) then
            Add({ height = ENTRY.open })
        elseif i > 1 and i - 1 == page.open then
            Add({ height = ENTRY.after })
        end
        if open or not solo then
            Add({ title = Text.Title(e, now), aside = Text.Current(e), paraph = i, entry = i,
                faces = e.faces, e = e, open = open, height = open and ENTRY.title or ENTRY.closed,
                solo = solo or nil, older = solo and i > 1 or nil, newer = solo and i < #recap.entries or nil })
            rubrics[i] = #items
        end
        if i == page.open then
            -- The sittings, oldest first, each one's runs under it.
            local _, at = OpenPieceOf(e)
            if at then
                for k, p in ipairs(e.pieces) do
                    Add({ sitting = k, label = Text.SittingLabel(p, now), aside = Text.Current(p), entry = i,
                        chosen = k == at, current = k == at and page.mode == "plates", height = SITTINGS.row })
                    -- Its runs and its battlegrounds together, in the order
                    -- they began (battleground-page.md §3): a session of three
                    -- matches or more one line (its overview), else a line a
                    -- match (its page).
                    local subs = {}
                    for _, visit in ipairs(p.runs) do subs[#subs + 1] = { t = visit.startedAt or 0, visit = visit } end
                    for _, session in ipairs(p.battlegrounds or {}) do
                        if ns.Matches.HasOverview(session) then
                            subs[#subs + 1] = { t = session.startedAt or 0, session = session }
                        else
                            for _, m in ipairs(session.matches) do
                                subs[#subs + 1] = { t = m.startedAt or 0, session = session, match = m }
                            end
                        end
                    end
                    table.sort(subs, function(a, b) return a.t < b.t end)
                    for _, sub in ipairs(subs) do
                        local visit, session, m = sub.visit, sub.session, sub.match
                        if visit then
                            Add({ run = visit, label = visit.name or L["An instance"], entry = i, height = SITTINGS.runRow,
                                current = page.mode == "run" and page.runVisit == visit.id })
                        elseif m then
                            Add({ bg = session, match = m, label = Text.MatchLine(m), entry = i,
                                height = SITTINGS.runRow, current = page.mode == "match" and page.matchId == m.id })
                        else
                            local open = page.mode == "matches" and page.session == session.key
                            if page.mode == "match" then
                                for _, x in ipairs(session.matches) do open = open or x.id == page.matchId end
                            end
                            Add({ bg = session, label = Text.EveningLine(#session.matches), entry = i,
                                height = SITTINGS.runRow, current = open })
                        end
                    end
                end
                Add({ height = SITTINGS.after })
            end
            local opening, names = HasOpening(e), NamesOf(e)
            for k, line in ipairs(Text.Lines(e, now, fights)) do
                local font = (k == 1 and opening) and FONT.faded or FONT.body
                Add({ text = Linked(line, names), font = font, height = Measure(font, line) + ENTRY.para })
            end
            -- The player's own words, in their hand, as written.
            local quote, more = Text.Note(e)
            if quote then
                Add({ text = quote, font = FONT.noteWritten, note = true,
                    height = Measure(FONT.noteWritten, quote) + (more and ENTRY.more or ENTRY.para) })
                if more then
                    Add({ text = more, font = FONT.small, height = Measure(FONT.small, more) + ENTRY.para })
                end
            end
            -- The name in each is a link to them (the user's decision 5 on
            -- the stranger-glimpse proposal, 5 Nov 2026): their page, or a
            -- stranger's glimpse, through ToPerson as every name here.
            for _, f in ipairs(e.hindsight or {}) do
                local line = Text.Hindsight(f)
                local short = Text.Short(f.guid)
                -- (`text` the words as read, `linked` as written on the row.)
                Add({ text = line, linked = short and Linked(line, { { name = short, guid = f.guid } }) or nil,
                    font = FONT.noteWritten, later = f,
                    height = Measure(FONT.noteWritten, line) + ENTRY.later })
            end
            if #(e.places or {}) > 0 then Add({ height = ENTRY.ledger }) end
            for _, place in ipairs(e.places or {}) do
                local mapID = place.mapID or (place.dungeon and place.dungeon.seg.mapID)
                Add({ zone = place, mapID = mapID, entry = i, height = ENTRY.zone,
                    current = (page.mode == "full" and place.mapID ~= nil and place.mapID == page.fullMap)
                    or (page.mode == "run" and place.dungeon ~= nil and place.dungeon.visit ~= nil
                        and place.dungeon.visit.id == page.runVisit) })
            end
        end
    end
    return items, rubrics
end

-- A face at a rubric's end: the class circle on its dark edge, ringed in
-- rubric for a rival; its tooltip says who and what happened, and a click
-- opens their page.
local function Face(row)
    local face = CreateFrame("Button", nil, row)
    face:SetSize(FACES.size, FACES.size)
    face.ring = face:CreateTexture(nil, "ARTWORK", nil, 0)
    face.ring:SetSize(FACES.size + FACES.edge + FACES.ring, FACES.size + FACES.edge + FACES.ring)
    face.ring:SetPoint("CENTER")
    local R = Style.RUBRIC
    Style.Disc(face.ring, R[1], R[2], R[3], FACES.ringAlpha)
    face.edge = face:CreateTexture(nil, "ARTWORK", nil, 1)
    face.edge:SetSize(FACES.size + FACES.edge, FACES.size + FACES.edge)
    face.edge:SetPoint("CENTER")
    local S = Style.INK_STRONG
    Style.Disc(face.edge, S[1], S[2], S[3], 0.9)
    face.icon = face:CreateTexture(nil, "ARTWORK", nil, 2)
    face.icon:SetAllPoints()
    Style.Tooltip(face, function(self) return self.tip end, "ANCHOR_TOP")
    face:SetScript("OnClick", function(self) ToPerson(self.guid) end)
    return face
end

local function SetFace(face, f, e)
    local record = ns.db.characters[f.guid]
    face.guid = f.guid
    face.tip = Text.Face(f, e)
    if not Style.SetClassIcon(face.icon, record and record.class) then
        local INK = Style.INK
        face.icon:SetTexCoord(0, 1, 0, 1)
        Style.Disc(face.icon, INK[1], INK[2], INK[3], 0.6)
    end
    face.ring:SetShown(f.rival == true)
end

-- The chevrons either side of the level shown with the pad (SOLO): made
-- on a rubric's row the first time it shows one, so a book read with the
-- mouse never makes them. Each is a frame of two pen strokes, its point
-- outward: "<" before the paraph, ">" at the line's end.
local function Chevron(row, dir)
    local c = CreateFrame("Frame", nil, row)
    c:SetSize(SOLO.w, SOLO.h)
    c.dir = dir
    local S = Style.INK_STRONG
    local tip, back = dir == "LEFT" and 0 or SOLO.w, dir == "LEFT" and SOLO.w or 0
    -- (the nib a hair past the tip on the way in, as a hand makes a "<")
    Style.Stroke(c, "ARTWORK", back, 0, tip, SOLO.h / 2 + 0.3, S, 1, SOLO.thick)
    Style.Stroke(c, "ARTWORK", tip, SOLO.h / 2 - 0.3, back, SOLO.h, S, 1, SOLO.thick)
    c:Hide()
    return c
end

-- `shift` px further out than its place.
local function PlaceChevron(c, shift)
    local row = c:GetParent()
    c:ClearAllPoints()
    if c.dir == "LEFT" then
        c:SetPoint("CENTER", row.paraph, "CENTER", -SOLO.out - shift, 0)
    else
        c:SetPoint("RIGHT", row, "RIGHT", -2 + shift, 0)
    end
end

local function Nudging(c, elapsed)
    c.t = c.t + elapsed
    local p = math.min(c.t / SOLO.nudge, 1)
    PlaceChevron(c, SOLO.travel * math.sin(math.pi * p))
    if p >= 1 then c:SetScript("OnUpdate", nil) end
end

-- A D-pad press toward `dir` ("LEFT" / "RIGHT"): its chevron on the level
-- shown gives a little outward and back, live or faded (at an end it says
-- the press was heard, and that nothing lies that way).
local function NudgeChevron(dir)
    local page = YourDiary.page
    local at = page and page.rubrics and page.rubrics[page.open]
    local row = at and page.entries:RowOf(at)
    local c = row and row.chevrons and row.chevrons[dir]
    if not (c and c:IsShown()) then return end
    c.t = 0
    c:SetScript("OnUpdate", Nudging)
end

local function Chevrons(row, item)
    if not row.chevrons then
        row.chevrons = { LEFT = Chevron(row, "LEFT"), RIGHT = Chevron(row, "RIGHT") }
    end
    local left, right = row.chevrons.LEFT, row.chevrons.RIGHT
    for _, c in pairs(row.chevrons) do
        c:SetScript("OnUpdate", nil)
        PlaceChevron(c, 0)
    end
    left:SetAlpha(item.older and SOLO.alpha or SOLO.dead)
    right:SetAlpha(item.newer and SOLO.alpha or SOLO.dead)
    left.live, right.live = item.older == true, item.newer == true
    left:Show()
    right:Show()
end

local Marked

-- The ledger's dot leaders: as many LEDGER.dot as fit `room` px, by the
-- width of one measured once (on the page's own measure, at a run of
-- twenty for a true average). Nothing where the client gave no width yet:
-- it is measured again next time.
local function Dots(room)
    local page = YourDiary.page
    if not page.dotW then
        local m = page.measure
        m:SetFontObject(FONT.small)
        m:SetText(LEDGER.dot:rep(20))
        local w = (m:GetUnboundedStringWidth() or 0) / 20
        page.dotW = w > 0 and w or nil
    end
    if not page.dotW or room < page.dotW then return "" end
    return LEDGER.dot:rep(math.floor(room / page.dotW))
end

-- A zone's row as it stands (LEDGER.mark): under the mouse (`row.hot`)
-- its name darker and a pencil line under it; while its map is on the
-- right page, darker and the line in ink.
function Marked(row, item)
    local M = LEDGER.mark
    local current = item.current == true
    local on = current or row.hot == true
    local ink = on and Style.INK_STRONG or Style.INK
    row.zone:SetTextColor(ink[1], ink[2], ink[3], 1)
    if current then
        local S = Style.INK_STRONG
        row.underline:SetColorTexture(S[1], S[2], S[3], M.inkAlpha)
    else
        local G = M.colour
        row.underline:SetColorTexture(G[1], G[2], G[3], M.alpha)
    end
    row.underline:SetShown(on)
    -- Laid flat ("Flat paper only"), the line alone: no light on it.
    row.lip:SetShown(on and ns.Setting("flatSheets") ~= true)
end

-- The run going on now that `item` is the row of, where it has a map to
-- trace on (UI/Dungeon/Way.lua), or nil.
local function LiveRun(item)
    local visit = item.run or (item.zone and item.zone.dungeon and item.zone.dungeon.visit)
    local current = visit and ns.Instances.Current()
    if not (current and current.id == visit.id) then return nil end
    local floors = ns.Dungeons.Floors(visit.instanceID, ns.UI.DungeonPage.Wing(visit))
    return floors and #floors > 0 and visit or nil
end

-- What a click on a row of `item` does (the pad's A too, UI/Journey/Pad.lua):
-- the run being played lays out its map; a rubric opens its level, a
-- sitting's line that sitting, a run's line its page; a zone's row its
-- map. True where it did something.
local function OpenItem(item)
    if not item then return false end
    local live = LiveRun(item)
    if live then
        Style.PlaySound("pageTurn")
        ns.UI.OpenVisit(live.id, "journey")
    elseif item.title then
        Style.PlaySound("pageTurn")
        YourDiary.OpenLevel(item.entry)
    elseif item.sitting then
        Style.PlaySound("pageTurn")
        YourDiary.OpenPiece(item.entry, item.sitting)
    elseif item.run then
        Style.PlaySound("pageTurn")
        YourDiary.OpenRun(item.run.id, item.entry)
    elseif item.bg then
        -- A battleground's line: its match's page, or the evening's overview
        -- (UI/Journey/Match.lua).
        Style.PlaySound("pageTurn")
        if item.match then
            YourDiary.OpenMatch(item.match.id, item.entry)
        else
            YourDiary.OpenMatches(item.bg.key, item.entry)
        end
    elseif item.zone and item.zone.dungeon and ns.JourneyRecap.RunWorthy(item.zone.dungeon.visit) then
        -- A run that earned a page opens it (UI/Journey/Run.lua); any
        -- other dungeon's row, its map as a zone's does.
        Style.PlaySound("pageTurn")
        YourDiary.OpenRun(item.zone.dungeon.visit.id, item.entry)
    elseif item.zone and item.mapID then
        Style.PlaySound("pageTurn")
        YourDiary.OpenFull(item.mapID, item.entry)
    else
        return false
    end
    return true
end

-- Whether a click on `item`'s row does something (OpenItem), asked
-- without doing it.
local function Opens(item)
    if not item then return false end
    if item.title or item.sitting or item.run or item.bg then return true end
    return item.zone ~= nil and (item.mapID ~= nil or LiveRun(item) ~= nil)
end

local function BuildEntryRow(list)
    local row = CreateFrame("Button", nil, list)
    local w = LEFT_W - SCROLLBAR_WIDTH - 2 - ENTRY.indent

    row.text = Style.Text(row, FONT.body)
    row.text:SetPoint("TOPLEFT", ENTRY.indent, 0)
    row.text:SetWidth(w)
    row.text:SetWordWrap(true)
    row.text:SetSpacing(ENTRY.leading)
    -- The names in the prose are links to their pages.
    if row.SetHyperlinksEnabled then row:SetHyperlinksEnabled(true) end
    row:SetScript("OnHyperlinkClick", function(_, link)
        local guid = type(link) == "string" and link:match("^sdperson:(.+)$")
        if guid then ToPerson(guid) end
    end)
    -- A stranger's name (a hindsight line's) says where it leads, as their
    -- margin strip does; a diary person's says nothing, as before.
    row:SetScript("OnHyperlinkEnter", function(self, link)
        local guid = type(link) == "string" and link:match("^sdperson:(.+)$")
        if not guid or ns.Diary.IsDiary(guid) then return end
        local list = ns.UI.PersonText.GlimpseTip(ns.Characters.FullName(guid) or ns.Characters.Name(guid))
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(unpack(list[1]))
        for i = 2, #list do GameTooltip:AddLine(unpack(list[i])) end
        GameTooltip:Show()
    end)
    row:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)

    -- The rubric: paraph, red capitals, "so far", a red rule fading out to
    -- the faces.
    row.header = Style.Text(row, FONT.headingRubric)
    row.header:SetPoint("BOTTOMLEFT", ENTRY.indent, ENTRY.base)
    row.paraph = row:CreateTexture(nil, "ARTWORK")
    row.paraph:SetSize(ENTRY.paraph, ENTRY.paraph)
    row.paraph:SetRotation(math.pi / 4)
    row.paraph:SetPoint("CENTER", row.header, "LEFT", -ENTRY.indent / 2 - 1, 0)
    row.aside = Style.Text(row, FONT.small)
    row.aside:SetPoint("LEFT", row.header, "RIGHT", 7, 0)
    row.rule = row:CreateTexture(nil, "ARTWORK")
    row.rule:SetHeight(1)
    row.more = Style.Text(row, FONT.small)
    row.more:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.more:SetJustifyH("RIGHT")
    row.faces = {}

    -- A zone in the ledger (LEDGER): its name in small type, dot leaders
    -- out to its time at the right in faded ink, and a dungeon's doorway
    -- in the margin.
    row.zone = Style.Text(row, FONT.small)
    row.zone:SetPoint("LEFT", ENTRY.indent, 0)
    row.zone:SetWordWrap(false)
    row.time = Style.Text(row, FONT.small)
    row.time:SetPoint("RIGHT", -LEDGER.right, 0)
    row.time:SetJustifyH("RIGHT")
    row.dots = Style.Text(row, FONT.small)
    row.dots:SetPoint("RIGHT", row.time, "LEFT", -LEDGER.gap, 0)
    row.dots:SetJustifyH("RIGHT")
    row.dots:SetWordWrap(false)
    row.dots:SetAlpha(LEDGER.dotAlpha)
    -- The doorway: the plates' arch, its body then its round head (y up
    -- here, down in DOOR). A run's line under a sitting has the same
    -- doorway, hung before its name further in (PlaceDoor).
    local D, A = LEDGER.door, Plate.DOOR
    local s, I = D.size, D.ink
    local body = row:CreateTexture(nil, "ARTWORK")
    body:SetSize(s * A.body.w, s * A.body.h)
    body:SetColorTexture(I[1], I[2], I[3], D.alpha)
    body.dy = -s * A.body.y
    local head = row:CreateTexture(nil, "ARTWORK")
    head:SetSize(s * A.head.size, s * A.head.size)
    head.dy = -s * A.head.y
    Style.Disc(head, I[1], I[2], I[3], D.alpha)
    row.door = { body, head }
    -- A battleground's line has a pennant where a run's has its doorway
    -- (BATTLE): a pole, and its flag in pieces narrowing to the point.
    local B = BATTLE
    row.pennant = {}
    local pole = row:CreateTexture(nil, "ARTWORK")
    pole:SetSize(B.pole, B.h)
    pole:SetColorTexture(I[1], I[2], I[3], D.alpha)
    pole.dx, pole.dy = 0, 0
    row.pennant[1] = pole
    for k = 1, B.pieces do
        local piece = row:CreateTexture(nil, "ARTWORK")
        local w = B.w * (1 - (k - 1) / B.pieces)
        piece:SetSize(w, B.flag / B.pieces + 0.3)
        piece:SetColorTexture(I[1], I[2], I[3], D.alpha)
        piece.dx = B.pole / 2 + w / 2
        piece.dy = B.h / 2 - (k - 0.5) * B.flag / B.pieces
        row.pennant[#row.pennant + 1] = piece
    end

    -- A sitting's "so far", and the tick in the margin at the sitting
    -- open (SITTINGS): the paraph's lozenge, smaller, in rubric.
    row.so = Style.Text(row, FONT.small)
    row.so:SetPoint("LEFT", row.zone, "RIGHT", SITTINGS.aside, 0)
    row.tick = row:CreateTexture(nil, "ARTWORK")
    row.tick:SetSize(SITTINGS.tick, SITTINGS.tick)
    row.tick:SetRotation(math.pi / 4)
    local R = Style.RUBRIC
    row.tick:SetColorTexture(R[1], R[2], R[3], 1)

    -- The reader's mark under a zone's name (LEDGER.mark): the pencil
    -- line, and the light on its groove's lower side.
    local M = LEDGER.mark
    row.underline = row:CreateTexture(nil, "ARTWORK")
    row.underline:SetHeight(M.width)
    row.underline:SetPoint("TOPLEFT", row.zone, "BOTTOMLEFT", 0, -M.under)
    row.lip = row:CreateTexture(nil, "ARTWORK")
    row.lip:SetHeight(1)
    row.lip:SetPoint("TOPLEFT", row.underline, "BOTTOMLEFT", 0, 0)
    row.lip:SetColorTexture(M.lip[1], M.lip[2], M.lip[3], M.lipAlpha)

    row:SetScript("OnClick", function(self) YourDiary.OpenItem(self.item) end)
    -- Under the mouse, a rubric's rule darkens: it opens its level. A
    -- zone's row that opens its map, a sitting's and a run's line are
    -- marked (LEDGER.mark).
    local function Hot(self, on)
        local item = self.item
        if item and (item.sitting or item.run or item.bg) then
            self.hot = on
            Marked(self, item)
            return
        end
        if item and item.zone then
            self.hot = on and (item.mapID ~= nil or LiveRun(item) ~= nil)
            Marked(self, item)
            return
        end
        if not (item and item.title) then return end
        local R = Style.RUBRIC
        Style.Shade(self.rule, "HORIZONTAL", R[1], R[2], R[3], on and ENTRY.ruleHot or ENTRY.ruleAlpha, 0)
    end
    row:SetScript("OnEnter", function(self) Hot(self, true) end)
    row:SetScript("OnLeave", function(self) Hot(self, false) end)
    return row
end

-- A battleground's pennant hung `at` px in from the row's left: its pole
-- centred there.
local function PlacePennant(row, at)
    for _, piece in ipairs(row.pennant) do
        piece:ClearAllPoints()
        piece:SetPoint("CENTER", row, "LEFT", at - BATTLE.w / 4 + piece.dx, piece.dy)
    end
end

-- The doorway hung `at` px in from the row's left, centred there.
local function PlaceDoor(row, at)
    for _, piece in ipairs(row.door) do
        piece:ClearAllPoints()
        piece:SetPoint("CENTER", row, "LEFT", at, piece.dy)
    end
end

local function UpdateEntryRow(row, item)
    local isTitle, isZone = item.title ~= nil, item.zone ~= nil
    local isSitting, isRun, isBg = item.sitting ~= nil, item.run ~= nil, item.bg ~= nil
    -- (a battleground's line is set as a run's, its pennant for the door)
    local isSub = isSitting or isRun or isBg
    for _, piece in ipairs(row.pennant) do piece:SetShown(isBg) end
    if isBg then isRun = true end
    row.header:SetShown(isTitle)
    row.paraph:SetShown(isTitle)
    row.rule:SetShown(isTitle)
    row.aside:SetShown(isTitle)
    row.more:SetShown(false)
    row.text:SetShown(item.text ~= nil)
    row.zone:SetShown(isZone or isSub)
    row.time:SetShown(isZone)
    row.dots:SetShown(isZone)
    row.so:SetShown(isSitting and item.aside ~= nil)
    row.tick:SetShown(isSitting and item.chosen == true)
    for _, piece in ipairs(row.door) do piece:SetShown((isRun and not isBg) or (isZone and item.zone.dungeon ~= nil)) end
    row.underline:SetShown(false)
    row.lip:SetShown(false)
    if not (isSub or (isZone and (item.mapID or LiveRun(item)))) then row.hot = nil end
    for _, face in ipairs(row.faces) do face:Hide() end
    if row.chevrons then
        row.chevrons.LEFT:Hide()
        row.chevrons.RIGHT:Hide()
    end
    -- A ledger's name lines up with the prose; a sitting's and a run's
    -- hang further in under the rubric (SITTINGS).
    if isZone or isSub then
        local x = ENTRY.indent
        if isSub then x = x + SITTINGS.indent + (isRun and SITTINGS.run or 0) end
        row.zone:ClearAllPoints()
        row.zone:SetPoint("LEFT", x, 0)
        if isRun or isZone then PlaceDoor(row, isRun and x - SITTINGS.tickX or ENTRY.indent / 2 - 1) end
        if isBg then PlacePennant(row, x - SITTINGS.tickX) end
        if isSitting then
            row.tick:ClearAllPoints()
            row.tick:SetPoint("CENTER", row, "LEFT", x - SITTINGS.tickX, 0)
        end
    end

    if isSub then
        -- A sitting's date in body type, a run's name in small; "so far"
        -- beside the one being played; cut short at the row's end.
        row.zone:SetFontObject(isSitting and FONT.body or FONT.small)
        row.zone:SetWidth(0)
        row.zone:SetText(item.label)
        row.so:SetText(item.aside or "")
        local x = ENTRY.indent + SITTINGS.indent + (isRun and SITTINGS.run or 0)
        local most = LEFT_W - SCROLLBAR_WIDTH - 2 - x - LEDGER.right
        if isSitting and item.aside then
            most = most - SITTINGS.aside - (row.so:GetUnboundedStringWidth() or 0)
        end
        local nameW = row.zone:GetUnboundedStringWidth() or 0
        if nameW > most then
            row.zone:SetWidth(most)
            nameW = most
        end
        row.underline:SetWidth(math.max(1, nameW))
        row.lip:SetWidth(math.max(1, nameW))
        Marked(row, item)
        return
    end

    if isTitle then
        -- A closed rubric's words sit lower in its shorter row.
        row.header:SetPoint("BOTTOMLEFT", ENTRY.indent, item.open and ENTRY.base or ENTRY.closedBase)
        row.header:SetText(item.title)
        local paraph = PARAPHS[item.paraph % 2 == 1 and 1 or 2]
        row.paraph:SetColorTexture(paraph[1], paraph[2], paraph[3], 1)
        row.aside:SetText(item.aside or "")
        local R = Style.RUBRIC
        Style.Shade(row.rule, "HORIZONTAL", R[1], R[2], R[3], ENTRY.ruleAlpha, 0)

        -- The faces, from the right: "+n" past the most, then the circles
        -- in the order met; the rule runs out to the first of them.
        local faces = item.faces or {}
        local shown = math.min(#faces, FACES.most)
        -- (the pad's level shown: its chevrons, the faces in from the end)
        local edge = -2
        if item.solo then
            Chevrons(row, item)
            edge = -2 - SOLO.reserve
        end
        local to, point, x = row, "RIGHT", edge
        row.more:ClearAllPoints()
        row.more:SetPoint("RIGHT", row, "RIGHT", edge, 0)
        if #faces > FACES.most then
            row.more:SetText("+" .. (#faces - FACES.most))
            row.more:Show()
            to, point, x = row.more, "LEFT", -FACES.gap
        end
        for k = shown, 1, -1 do
            local face = row.faces[k] or Face(row)
            row.faces[k] = face
            SetFace(face, faces[k], item.e)
            face:ClearAllPoints()
            face:SetPoint("RIGHT", to, point, x, 0)
            face:Show()
            to, point, x = face, "LEFT", -FACES.gap
        end
        row.rule:ClearAllPoints()
        row.rule:SetPoint("LEFT", row.aside, "RIGHT", ENTRY.rule, 0)
        row.rule:SetPoint("RIGHT", to, point, to == row and edge or -ENTRY.rule, 0)
    elseif isZone then
        local place = item.zone
        row.zone:SetFontObject(FONT.small)
        row.zone:SetWidth(0)
        row.zone:SetText(place.dungeon and (place.name or L["An instance"]) or Text.ZoneName(place))
        row.time:SetText((place.seconds or 0) >= 60 and Text.LedgerTime(place.seconds) or "")
        -- The name never crowds out the leaders: past its share of the row
        -- it is cut short (the client adds the ellipsis).
        local rowW = LEFT_W - SCROLLBAR_WIDTH - 2
        local nameW = row.zone:GetUnboundedStringWidth() or 0
        local most = math.floor(LEDGER.nameMax * (rowW - ENTRY.indent))
        if nameW > most then
            row.zone:SetWidth(most)
            nameW = most
        end
        local timeW = row.time:GetUnboundedStringWidth() or 0
        row.dots:SetText(Dots(rowW - ENTRY.indent - nameW - timeW - LEDGER.right - 2 * LEDGER.gap))
        -- The mark under the name, as long as the name.
        row.underline:SetWidth(math.max(1, nameW))
        row.lip:SetWidth(math.max(1, nameW))
        Marked(row, item)
    elseif item.text then
        row.text:SetFontObject(item.font or FONT.body)
        row.text:SetText(item.linked or item.text)
    end
end

YourDiary.FillHeader, YourDiary.ToPerson, YourDiary.EntryItems = FillHeader, ToPerson, EntryItems
YourDiary.BuildEntryRow, YourDiary.UpdateEntryRow = BuildEntryRow, UpdateEntryRow
YourDiary.PiecesOf, YourDiary.OpenPieceOf = PiecesOf, OpenPieceOf
YourDiary.Solo, YourDiary.OpenItem, YourDiary.Opens, YourDiary.NudgeChevron = Solo, OpenItem, Opens, NudgeChevron
