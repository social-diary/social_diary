-- Your Diary with the pad (.claude/controller-plan.md, step 4a): the left
-- page.
--
-- With the pad in hand the left page shows one level at a time (the user,
-- 7 Nov 2026: the whole contents is too crowded for a pad), with the
-- diary's pen's chevrons either side of its rubric (Left.lua's Chevrons,
-- Look.lua's SOLO). D-pad left and right turn to the level before and
-- after: it opens as a click on its rubric opens it (its newest sitting,
-- its plates on the right page), and the pad stands on its rubric. No
-- wrap round: at the first or last level the dead side's chevron is
-- faded, and the press only nudges it. With the mouse the page is the
-- whole contents as it always was, and it changes over as the hand does
-- (Pad.Input.OnChange, below).
--
-- Up and down walk the level's rows that do something, in the order they
-- are on the page: its rubric, its sittings and their runs, a hindsight
-- line with a name in it, the zones of its ledger that open a map or a
-- run. A does what a click does (Left.lua's OpenItem: the same sitting,
-- run page or map on the right page; a name's page) and the pad stays
-- where it is, on the left. Paragraphs, the note and the faces are passed
-- over: the margin notes on the right page reach the same people (4b).
-- The words of the row stood on take the pen's box (Pad.Look), the
-- level's rubric over them its subheading.
--
-- B is the book's (its scope is this one's parent): it closes. The
-- shoulders turn the ribbons. After a ribbon turn the character's name
-- holds the box until the first D-pad press (the journal's HOLD_TITLE),
-- which lands on the level's rubric.
--
-- The right page (step 4b): left and right are the levels' on the left
-- page, so the pad crosses with A. On a row whose plates are already on
-- the right (the rubric, or the sitting ticked) A goes over to them; on
-- any other row A opens it as a click does, and goes over if it opened
-- plates (a zone's whole map takes the pad with it, below; a run's page
-- too, at the foot of this comment). B comes back to the row it left.
--
-- On the right page (group `page`, spatial) the pad stands on each plate
-- and each margin note or card, moving by where they lie. A plate's words
-- are its caption's heading. Its active state, and a card's, is the
-- user's (7 Nov 2026): a red outline, a slight red drop shadow, its
-- heading red (Pad.Look's `outline`). Nothing here names a kind: the
-- plates say where their marks are (plate:Marks) and every note what it
-- is (strip:Focus, the card contract over ns.UI.PaperStrip), so a new
-- feature's mark or card is found without pad code.
--   A on a plate goes in among its marks (group `marks`, spatial): each
--     ringed by the pen, its own tooltip shown as under the mouse, the
--     plate leaning in (plate.padLean) and its heading red over them. A
--     on a mark does nothing. A on a note is its click (a person's page).
--   X on a plate or a mark opens the zone's whole map, as a click on the
--     plate does (plate.onClick: there is no opening it at a mark yet).
--     B there goes back (Full.lua's Back) to where X was pressed.
--   B: marks → their plate → the left page's row → the book closes.
--   Y (step 4c) is the right click: on a custom card, or a mark of one, its
--     form (CardSheet.Edit, as the mouse's); on a plate or any other mark
--     a new card, from the picker, at where the player stands
--     (CardSheet.PadRight, which says what it does where the player is not
--     on this map). The slip has its own scope over this one
--     (UI/Journey/CardPad.lua); put away, the pad is back where it was.
-- No item to chat.
--
-- The whole map (step 4d; group `full`, spatial), opened by X on a plate or
-- a mark, or by A on a ledger's zone row (the pad goes with it): every mark
-- on the zone, found as on a plate (plate:Marks), ringed by the pen with its
-- own tooltip, the foot's zone name red over them as their subheading. They
-- are measured in the map's own units (a px of its art), not on the card, so
-- a zoom or a pan does not change which way "left" is, and the pad may walk
-- to a mark out of the view: the map pans to bring it in (plate:PanTo, eased
-- as the wheel eases). Keys are what the mark is and where on the map, so
-- the one stood on is found again as the map is drawn again for a new
-- window (and, as marks merge or step apart with the zoom, the nearest of
-- its kind where it was). After the right stick has moved the view away
-- from it, the pad takes the mark nearest the middle of what is shown.
--   A: closer, a wheel's notch about the mark stood on (plate:ZoomAt); X:
--     further. A has no click of its own here: a click on the map is the
--     way back, which is B's. At either end the press is still the map's.
--   The right stick pans, as a drag does (plate:Pan; the scope asks for
--     sticks only while the whole map is open: Catcher.lua's `stick`).
--   Y: as on a plate (CardSheet.PadRight, the full page's own right click).
--   B: back to where it was opened from (scope.back).
-- With no mark on the map at all, the map itself is the one thing stood on.
--
-- A run's page (step 4e; group `run`, spatial), opened by A on a run's line
-- or its ledger row (the pad goes with it, onto its title): everything on it
-- that the mouse can hover (UI/Journey/Run.lua's hits, each saying what it is
-- as `hit.pad`: YourDiary.RunParts), walked by where it lies. Pasted things
-- (the keepsakes, the map scrap, the slip of the rest) are outlined as a
-- margin card is; words straight on the page (the title, the fallen note,
-- the signatures, "+ Add", "and n others") take the pen's box. Each shows
-- its own tooltip as under the mouse: a keepsake the game's item tooltip.
--   A on the title or the scrap lays the run out on the table (their click,
--     ns.UI.OpenVisit; the spread's own scope has the pad while it is out,
--     UI/Dungeon/Pad.lua); put away, the pad is back where A was pressed. A
--     on a signature in the diary opens their page, on "+ Add" keeps them
--     (the pad then on their signature), on "and n others" turns the party
--     over. On a keepsake A does nothing: no item to chat (the user, 7 Nov
--     2026), and no click is made on it at all, so a held Shift or Ctrl
--     stand-in never reaches the game's modified click.
--   No Y: the run's page has no right click.
--   B: back to the left page's row.
--
-- A battleground's pages (group `match`, spatial; UI/Journey/Match.lua's
-- hits, YourDiary.MatchParts), opened by A on a battleground's line (the pad
-- goes with it, onto the title), walked as the run's page is, with no new
-- grammar (battleground-page.md §4): the overview's tickets (outlined, as a
-- pasted thing), its people by hand, the turn link, your note; the match
-- page's back link, the rows of the people in your diary, the margin's
-- strips, the turn link, your note.
--   A on a ticket opens its match (the pad on its title); on "Back to the
--     evening's battlegrounds" the overview comes back, the pad on the
--     ticket it left from; on a diary person's row their page; on "Turn …
--     over" the next face, the pad staying on the link. Anything else shows
--     its tooltip only.
--   B: on a match opened from its evening, back to the overview onto its
--     ticket; otherwise back to the left page's line.
--
-- The list is virtual, so a row's frame is found as the pad lands on its
-- item (Find, the group's `reveal`): scrolled into view, then its words.

local addonName, ns = ...

local Pad = ns.UI.Pad
local J = ns.UI.Journal
local Style = ns.Style
local YourDiary = ns.UI.YourDiary

local function Page() return YourDiary.page end

local function Journal() return Pad.Scope("journal") end

-- The page has a road on it to walk (not the empty page).
local function Road()
    local page = Page()
    return page and page.state == "entries" and page.recap and page.items and page
end

local PROMPT = {
    open = { "PAD1", "Open", main = true },
    map = { "PAD1", "See the map", main = true },
    person = { "PAD1", "Go to their page", main = true },
    levels = { { "PADDLEFT", "PADDRIGHT" }, "Earlier or later", main = false },
    title = { { "PADDUP", "PADDDOWN" }, "Go to the levels", main = true },
    marks = { "PAD1", "Show marks", main = true },
    whole = { "PAD3", "See the whole map" },
    backLeft = { "PAD2", "Back to the contents" },
    backPlate = { "PAD2", "Back to the plate" },
    backPlates = { "PAD2", "Back to the plates" },
    edit = { "PAD4", "Change the card" },
    add = { "PAD4", "Add a card here" },
    closer = { "PAD1", "Closer", main = true },
    further = { "PAD3", "Further" },
    move = { "PADRSTICK", "Move the map" },
    layout = { "PAD1", "Open the map", main = true },
    keep = { "PAD1", "Add to the diary", main = true },
    others = { "PAD1", "See the others", main = true },
    -- A battleground's pages (battleground-page.md §4).
    match = { "PAD1", "Open the match", main = true },
    evening = { "PAD1", "Back to the battlegrounds", main = true },
    turnBoard = { "PAD1", "Turn the board over", main = true },
    turnRoll = { "PAD1", "Turn the roll over", main = true },
    backEvening = { "PAD2", "Back to the battlegrounds" },
}

-- The whole map with the pad: `speed` card px a second the right stick
-- pans at, pushed all the way (by the square of the push, so a nudge is
-- fine and a push sweeps); `margin` px inside the neat line a mark must
-- lie to count as in view (its ring whole), else the walk pans to it.
local FULLPAD = { speed = 520, margin = 14 }

-- An item's key, the same however the list is built again: the rubric is
-- "rubric" whichever level, so turning a level keeps the pad on it.
local function KeyOf(data, zone)
    if data.title then return "rubric" end
    if data.sitting then return "sitting:" .. data.sitting end
    if data.run then return "run:" .. tostring(data.run.id) end
    if data.bg then
        return data.match and ("match:" .. tostring(data.match.id)) or ("evening:" .. tostring(data.bg.key))
    end
    if data.zone then return "zone:" .. zone end
    if data.later then return "later:" .. tostring(data.later.guid) end
end

local function WordsOf(row, data)
    if data.title then return row.header end
    if data.sitting or data.run or data.bg or data.zone then return row.zone end
    return row.text
end

-- The pad lands on `item`: its row scrolled into view, and its words and
-- the level's rubric over it (the subheading, its red rule laid over).
local function Find(item)
    local page = Page()
    if not page then return end
    local list = page.entries
    list:Reveal(item.index)
    local row = list:RowOf(item.index)
    item.frame = row
    item.words = row and WordsOf(row, item.data) or nil
    -- (the rubric's paraph leads its words: the box holds it too, else its
    -- left edge cut the diamond, in the client 8 Nov 2026)
    item.encloses = row and item.data.title and row.paraph or nil
    local head = item.rubric ~= item.index and item.rubric and list:RowOf(item.rubric)
    if head then head.header.rule = head.rule end
    item.subhead = head and head.header or nil
end

local scope = {
    layer = 20,
    parent = "journal",
    host = function() return J.journal end,
    -- (the empty page has nothing to walk: the book's scope has the pad there)
    active = function() return ns.UI.JournalShowing("journey") and Road() and true or false end,
}

-- The plates shown on the right page now, in their order (none on a full
-- page or a run's).
local function Count(page)
    return page.mode == "plates" and type(page.layout) == "number" and page.layout or 0
end

local function Plates(page)
    local out = {}
    for i = 1, Count(page) do
        local plate = page.plates[i]
        if plate and plate:IsShown() then out[i] = plate end
    end
    return out
end

local function Middle(corners)
    local x, y = 0, 0
    for _, c in ipairs(corners) do x, y = x + c[1] / #corners, y + c[2] / #corners end
    return x, y
end

local function PlateKey(i, plate) return "plate:" .. i .. ":" .. tostring(plate.mapID) end

local function Run(frame, script)
    local fn = frame and frame:GetScript(script)
    if fn then fn(frame, false) end
end

-- The right page's things: its plates and their notes (group `page`), and
-- the marks of the plate the pad went into (group `marks`). Centres are on
-- the page with y up, as Focus measures.
local BuildFull, BuildRun, BuildMatch

local function BuildRight(f, page)
    -- (where X was pressed is only kept while its whole map is open)
    if page.mode ~= "full" then scope.from, scope.fullOf, scope.fullAt = nil, nil, nil end
    if page.mode == "full" then BuildFull(f, page) end
    BuildRun(f, page)
    BuildMatch(f, page)
    local plates = Plates(page)
    if scope.inPlate and not plates[scope.inPlate] then
        scope.inPlate = nil
        if f.group == "marks" then f:Within("page") end
    end
    for i = 1, Count(page) do
        local plate = plates[i]
        if plate then
            f:Add("page", {
                key = PlateKey(i, plate), plate = i, heading = plate.heading,
                available = function() return plate:IsShown() end,
                center = function()
                    local x, y = Middle(plate:Corners())
                    return x, -y
                end,
                outline = function()
                    return { anchor = page.right, corners = plate:Corners(), level = plate:GetFrameLevel() }
                end,
                -- (no hover look of its own: the outline is the whole of it)
                enter = function() end, leave = function() end,
                press = function() if plate:HasMarks() then scope.EnterMarks(i) end end,
                whole = function() return plate end,
            })
        end
    end
    for i = 1, Count(page) do
        local plate = plates[i]
        for k, it in ipairs(plate and plate.margin or {}) do
            local note = it.note
            if note and note.Focus and note:IsShown() then
                local at = note:Focus()
                -- (a card that may be custom is keyed by its record: changed
                -- with Y, it is written again as another kind, a changed close
                -- call's "foeCustom" for "foe", and the pad stays on it)
                local spec = ns.UI.JourneyMargin.KINDS[it.kind]
                local _, rec
                if spec and spec.custom then _, rec = spec.custom(it) end
                rec = type(rec) == "table" and (rec.customOf or rec) or nil
                f:Add("page", {
                    key = rec and ("card:" .. i .. ":" .. tostring(rec))
                        or ("note:" .. i .. ":" .. tostring(it.kind) .. ":" .. tostring(it.rank or k)),
                    frame = at.frame, heading = at.words, person = it.kind == "person", note = note,
                    available = function() return note:IsShown() end,
                    center = function() return at.x, -at.y end,
                    outline = function()
                        local now = note:Focus()
                        return { anchor = note:GetParent(), corners = now.corners, level = note:GetFrameLevel() }
                    end,
                })
            end
        end
    end
    local plate = scope.inPlate and plates[scope.inPlate]
    if plate then
        local marks = plate:Marks()
        -- (top to bottom, then left to right: the first one in is the
        -- highest on the plate)
        table.sort(marks, function(a, b)
            if math.abs(a.y - b.y) > 0.5 then return a.y < b.y end
            return a.x < b.x
        end)
        for _, mk in ipairs(marks) do
            local frame = mk.frame
            f:Add("marks", {
                key = mk.key, frame = frame, ring = true, subhead = plate.heading,
                available = function() return frame:IsShown() end,
                center = function() return mk.x, -mk.y end,
                -- (its tooltip as under the mouse, the plate leaning in)
                enter = function()
                    plate.padLean = true
                    plate:Lean()
                    Run(frame, "OnEnter")
                end,
                leave = function()
                    plate.padLean = nil
                    plate:Lean()
                    Run(frame, "OnLeave")
                end,
                press = function() end,
                whole = function() return plate end,
            })
        end
    end
end

-- The run's page: its parts (UI/Journey/Run.lua's hits, YourDiary.RunParts),
-- centred on the page with y up as the plates are.
function BuildRun(f, page)
    if page.mode ~= "run" then return end
    for _, part in ipairs(YourDiary.RunParts()) do
        local hit, b, pad = part.frame, part.box, part.pad
        local strip = pad.strip
        local item = {
            key = pad.key, frame = hit, kind = pad.kind, kept = pad.kept,
            available = function() return hit:IsShown() end,
            center = function() return b.x + b.w / 2, -(b.y + b.h / 2) end,
        }
        if strip then
            item.heading = pad.heading
            item.outline = function()
                local now = strip:Focus()
                return { anchor = strip:GetParent(), corners = now.corners, level = strip:GetFrameLevel() }
            end
        else
            item.words = pad.words
        end
        local kind = pad.kind
        if kind == "add" then
            -- (kept, they sign in the same place: the pad goes onto it)
            local guid = pad.guid
            item.press = function()
                f:Remember("run", "sig:" .. tostring(guid))
                hit:Click("LeftButton")
            end
        elseif not (kind == "title" or kind == "scrap" or kind == "others" or (kind == "sig" and pad.kept)) then
            -- (a keepsake, the slip, the fallen note, a stranger's name: only
            -- the tooltip; never a click, which a keepsake hands to the
            -- game's modified click)
            item.press = function() end
        end
        f:Add("run", item)
    end
end

-- A battleground's page: its parts (UI/Journey/Match.lua's hits,
-- YourDiary.MatchParts), as the run's are found.
function BuildMatch(f, page)
    if page.mode ~= "match" and page.mode ~= "matches" then return end
    for _, part in ipairs(YourDiary.MatchParts()) do
        local hit, b, pad = part.frame, part.box, part.pad
        local strip = pad.strip
        local item = {
            key = pad.key, frame = hit, kind = pad.kind, kept = pad.kept,
            available = function() return hit:IsShown() end,
            center = function() return b.x + b.w / 2, -(b.y + b.h / 2) end,
        }
        if strip then
            item.heading = pad.heading
            item.outline = function()
                local now = strip:Focus()
                return { anchor = strip:GetParent(), corners = now.corners, level = strip:GetFrameLevel() }
            end
        else
            item.words = pad.words
        end
        local kind = pad.kind
        if kind == "back" then
            -- (the overview comes back with the pad on the ticket it left)
            local id = page.matchId
            item.press = function()
                local ticket = "ticket:" .. tostring(id)
                f:Remember("match", ticket)
                hit:Click("LeftButton")
                local now = scope.focus
                if now then now:Focus(ticket, "match") end
            end
        elseif not (kind == "ticket" or kind == "turn" or ((kind == "row" or kind == "hand") and pad.kept)) then
            -- (the title, a strip, a stranger by hand, your note, the lost
            -- records: only the tooltip)
            item.press = function() end
        end
        f:Add("match", item)
    end
end

-- The whole map's plate, while it is open.
local function FullPlate(page)
    local plate = page and page.mode == "full" and page.plates[1]
    return plate and plate.look and plate or nil
end

-- The right stick on the whole map: it pans (Catcher.lua's `stick`; set
-- only while the whole map is open, in build). Another stick goes on to
-- the game.
local function Stick(_, stick, x, y, len, elapsed)
    if stick ~= "Right" and stick ~= "Camera" then return false end
    local plate = FullPlate(Road())
    if not plate then return false end
    if elapsed > 0 then
        local k = FULLPAD.speed * len * elapsed
        plate:Pan(x * k, -y * k)
    end
    return true
end

-- Walking onto a mark out of the view brings it in. Only on a press: a
-- redraw after the stick moved the map away is not a walk (build picks a
-- mark in view then).
local function RevealOnMap(item)
    local plate = FullPlate(Road())
    if plate and item.mx and Pad.pressing and not plate:InView(item.mx, item.my, FULLPAD.margin) then
        plate:PanTo(item.mx, item.my)
    end
end

function BuildFull(f, page)
    local plate = FullPlate(page)
    if not plate then return end
    scope.stick = Stick
    local look = plate.look
    local LW, LH = look.LW, look.LH
    local of = tostring(page.open) .. ":" .. tostring(page.fullMap)
    local fresh = scope.fullOf ~= of
    scope.fullOf = of
    -- (just opened, or back from the card slip: the pad is on the map)
    if f.group ~= "full" then f:Within("full") end
    local name = page.foot and page.foot.name
    local items = {}
    for _, mk in ipairs(plate:Marks()) do
        local frame = mk.frame
        local at = frame.padAt
        local mx, my = plate:MapAtCard(at[1], at[2])
        if mx then
            local item
            item = f:Add("full", {
                key = string.format("full:%s:%d:%d", tostring(mk.what), math.floor(mx * LW + 0.5), math.floor(my * LH + 0.5)),
                frame = frame, ring = true, clip = plate.clip, subhead = name,
                what = mk.what, mx = mx, my = my,
                available = function() return frame:IsShown() end,
                center = function() return mx * LW, -my * LH end,
                enter = function()
                    scope.fullAt = { what = mk.what, mx = mx, my = my }
                    Run(frame, "OnEnter")
                end,
                leave = function() Run(frame, "OnLeave") end,
                -- (A is the zoom's, scope.keys)
                press = function() end,
                whole = function() return plate end,
            })
            items[#items + 1] = item
        end
    end
    if not items[1] then
        f:Add("full", {
            key = "full:map", heading = name,
            available = function() return plate:IsShown() end,
            center = function() return 0, 0 end,
            outline = function()
                return { anchor = page.right, corners = plate:Corners(), level = plate:GetFrameLevel() }
            end,
            enter = function() end, leave = function() end, press = function() end,
            whole = function() return plate end,
        })
        return
    end
    -- Where the pad lands: the mark nearest (dx, dy in map px) of those
    -- `ok` lets through.
    local function Nearest(x, y, ok)
        local best, bestD
        for _, item in ipairs(items) do
            if ok(item) then
                local dx, dy = (item.mx - x) * LW, (item.my - y) * LH
                local d = dx * dx + dy * dy
                if not bestD or d < bestD then best, bestD = item, d end
            end
        end
        return best
    end
    local function Shown(item) return plate:InView(item.mx, item.my, FULLPAD.margin) end
    local g = look.goal
    local was = f.remembered.full
    local kept
    for _, item in ipairs(items) do if item.key == was then kept = item end end
    local pick
    if fresh or not scope.fullAt then
        -- (opened: the mark in view nearest the middle)
        pick = Nearest(g.cx, g.cy, Shown) or Nearest(g.cx, g.cy, function() return true end)
    elseif not kept then
        -- (drawn again at another zoom: the nearest of its kind where it was)
        local a = scope.fullAt
        pick = Nearest(a.mx, a.my, function(item) return item.what == a.what end)
            or Nearest(a.mx, a.my, function() return true end)
    elseif not Pad.pressing and not plate:InView(kept.mx, kept.my, 0) then
        -- (the stick took the view away from it: the one nearest the middle;
        -- out of the view altogether, not only near its edge, as a mark at
        -- the map's very edge never comes `margin` px in)
        pick = Nearest(g.cx, g.cy, Shown) or kept
    end
    if pick then f:Remember("full", pick.key) end
end

function scope.build(f)
    scope.stick = nil
    f:Group("left", { mode = "list", reveal = Find })
    f:Group("page", { mode = "spatial" })
    f:Group("marks", { mode = "spatial" })
    f:Group("full", { mode = "spatial", reveal = RevealOnMap })
    f:Group("run", { mode = "spatial" })
    f:Group("match", { mode = "spatial" })
    f:Group("title", { mode = "list" })

    -- (a ribbon just turned: the title alone, until the first D-pad press)
    local journal = Journal()
    if journal and journal.held and journal.held() then
        local spec = J.Page("journey")
        local title = spec and spec.title and spec.title()
        -- (the page fell open at the newest level: the first press lands
        -- on its rubric, not where the pad was on another level)
        f:Remember("left", "rubric")
        if title then
            f:Add("title", { key = "title", words = title, prompt = PROMPT.title,
                enter = function() end, leave = function() end })
            return
        end
    end

    local page = Road()
    if not page then return end
    BuildRight(f, page)
    local rubric = page.rubrics[page.open]
    local zones = 0
    for index, data in ipairs(page.items) do
        if data.zone then zones = zones + 1 end
        local key
        if data.later then
            key = data.linked and KeyOf(data)
        elseif YourDiary.Opens(data) then
            key = KeyOf(data, zones)
        end
        if key then
            f:Add("left", {
                key = key, index = index, data = data, rubric = rubric,
                available = function() return true end,
                press = function()
                    if data.later then
                        YourDiary.ToPerson(data.later.guid)
                    else
                        scope.Cross(data)
                    end
                end,
            })
        end
    end
end

-- The run `data`'s row opens: a run's line, or a dungeon's ledger row.
local function RunOf(data)
    if data.run then return data.run.id end
    local d = data.zone and data.zone.dungeon
    return d and d.visit and d.visit.id
end

-- Whether the plates `data`'s row opens are on the right page already:
-- the level's (the rubric), or its sitting ticked; or the run's page it
-- opens.
local function Showing(page, data)
    if page.mode == "match" or page.mode == "matches" then
        if not data.bg then return false end
        if data.match then return page.mode == "match" and page.matchId == data.match.id end
        return page.mode == "matches" and page.session == data.bg.key
    end
    if page.mode == "run" then
        local id = RunOf(data)
        return id ~= nil and id == page.runVisit
    end
    if page.mode ~= "plates" then return false end
    if data.title then return true end
    local e = page.recap.entries[page.open]
    return data.sitting ~= nil and page.pieceOf == e and page.piece == data.sitting
end

-- A on a row of the left page: what a click does, unless its plates (or
-- its run's page) are open already; then over to the right page, onto its
-- first plate or the run's title (or where it was, when nothing was
-- opened), if there are plates or a run's page there. The run being played
-- is laid out on the table instead: the spread's scope has the pad then.
function scope.Cross(data)
    local page = Road()
    if not page then return end
    local f = scope.focus
    if not Showing(page, data) then
        YourDiary.OpenItem(data)
        if f then
            f:Remember("page", nil)
            f:Remember("run", nil)
            f:Remember("match", nil)
        end
        if J.visit then return end
    end
    if not f then return end
    if page.mode == "plates" then
        f:EnterGroup("page")
    elseif page.mode == "run" then
        f:EnterGroup("run")
    elseif page.mode == "match" or page.mode == "matches" then
        f:EnterGroup("match")
    end
end

-- A on plate `i`: in among its marks, the highest first.
function scope.EnterMarks(i)
    local f = scope.focus
    scope.inPlate = i
    Pad.Refresh()
    if not (f and f:EnterGroup("marks")) then scope.inPlate = nil end
end

-- X: the zone's whole map, as a click on the plate opens it; where the
-- pad was is kept for B to come back to.
local function Whole()
    local f = scope.focus
    local page = Road()
    if page and page.mode == "full" then return false end
    local at = f and f:Current()
    local plate = at and at.whole and at.whole()
    if not (plate and plate.onClick) then return false end
    scope.from = { group = at.group, key = at.key, plate = scope.inPlate or at.plate }
    scope.inPlate = nil
    plate.onClick(plate)
    return true
end

-- B, one level out: the whole map back to the plates (where X was
-- pressed), the marks to their plate, the right page to the row it was
-- crossed from. On the left page it goes on to the book (it closes).
function scope.back()
    local page = Road()
    local f = scope.focus
    if not (page and f) then return false end
    if page.mode == "full" then
        local from = scope.from
        scope.from = nil
        YourDiary.FullBack()
        -- (its plates drawn again: among the marks of the one X was
        -- pressed on, where it was among them)
        if from and from.group == "marks" then
            scope.inPlate = from.plate
            Pad.Refresh()
            if f:Focus(from.key, "marks") or f:EnterGroup("marks") then return true end
        end
        scope.inPlate = nil
        -- (opened from the left page's zone row: back there)
        if not from then return f:EnterGroup("left") or true end
        f:Remember("page", from.group == "page" and from.key or nil)
        if not f:EnterGroup("page") then f:EnterGroup("left") end
        return true
    end
    local at = f:Current()
    if at and at.group == "marks" then
        scope.inPlate = nil
        f:EnterGroup("page")
        return true
    end
    if at and at.group == "match" and page.mode == "match" and page.matchBack then
        -- (a match of an evening: back to its overview, onto its ticket)
        local ticket = "ticket:" .. tostring(page.matchId)
        f:Remember("match", ticket)
        Style.PlaySound("pageTurn")
        YourDiary.OpenMatches(page.matchBack)
        -- (the title is on both pages: the pad is put on the ticket, not
        -- kept on the title by its key)
        local now = scope.focus
        if now then now:Focus(ticket, "match") end
        return true
    end
    if at and (at.group == "page" or at.group == "run" or at.group == "match") then
        f:EnterGroup("left")
        return true
    end
    return false
end

-- On the left page (or the title held after a ribbon turn).
local function OnLeft()
    local at = scope.focus and scope.focus:Current()
    return not at or at.group == "left" or at.group == "title"
end

-- The level before or after (delta -1 / 1), opened as its rubric opens it.
-- At either end nothing opens, but the press is taken (and its chevron
-- nudged): it is the diary's, not the character's.
local function Level(delta, key)
    return function()
        local journal = Journal()
        if journal and journal.held and journal.held() then
            journal.keys[key](journal)
            return true
        end
        local page = Road()
        if not page then return false end
        -- (on the right page left and right move the pad)
        if not OnLeft() then return false end
        local to = page.open + delta
        if to >= 1 and to <= #page.recap.entries then
            if scope.focus then scope.focus:Remember("left", "rubric") end
            Style.PlaySound("pageTurn")
            YourDiary.OpenLevel(to)
        end
        YourDiary.NudgeChevron(delta < 0 and "LEFT" or "RIGHT")
        return true
    end
end

-- The first up or down after a ribbon turn is the journal's (it lets the
-- title go); any other time this page's focus.
local function Direction(key)
    return function()
        local journal = Journal()
        if journal and journal.held and journal.held() then
            journal.keys[key](journal)
            return true
        end
        return false
    end
end

-- Y on what the pad stands on (`at`): what a right click there does, "edit"
-- or "add", or nil where it does nothing (a person's strip, a card no one may
-- change, a plate where the player is not); `dry` only says which.
local function CardAt(at, dry)
    local page = Road()
    if not (page and at) then return nil end
    local CardSheet = YourDiary.CardSheet
    if page.mode == "full" then
        -- (the whole map's own right click: a mark's, or the map's)
        local plate = at.group == "full" and FullPlate(page)
        return plate and CardSheet.PadRight(plate, at.frame, dry)
    end
    if page.mode ~= "plates" then return nil end
    if at.group == "page" and at.plate then
        local plate = page.plates[at.plate]
        return plate and CardSheet.PadRight(plate, nil, dry)
    elseif at.group == "page" and at.note then
        -- (a card says what its right click does: strip:SetRight, Margin.lua)
        local fn = at.note.onRight
        if not fn then return nil end
        if not dry then fn() end
        return "edit"
    elseif at.group == "marks" then
        local plate = at.whole and at.whole()
        return plate and CardSheet.PadRight(plate, at.frame, dry)
    end
end

local function Card()
    local f = scope.focus
    return CardAt(f and f:Current(), false) ~= nil
end

-- A on the whole map: a notch closer (delta 1) about the mark stood on;
-- X: a notch further (-1). Taken at either end too: there it is the
-- map's, and nothing moves. Elsewhere A goes on to the focus, X to Whole.
local function Zoom(delta, other)
    return function()
        local plate = FullPlate(Road())
        if not plate then return other and other() or false end
        local at = scope.focus and scope.focus:Current()
        local on = at and at.group == "full" and at.mx and at
        plate:ZoomAt(delta, on and on.mx, on and on.my)
        return true
    end
end

scope.keys = {
    PADDUP = Direction("PADDUP"), PADDDOWN = Direction("PADDDOWN"),
    PADDLEFT = Level(-1, "PADDLEFT"), PADDRIGHT = Level(1, "PADDRIGHT"),
    PAD1 = Zoom(1), PAD3 = Zoom(-1, Whole), PAD4 = Card,
}

local function CardPrompt(out, at)
    local did = CardAt(at, true)
    if did then out[#out + 1] = did == "edit" and PROMPT.edit or PROMPT.add end
end

function scope.legend()
    local at = scope.focus and scope.focus:Current()
    if not at then return {} end
    local page = Road()
    if page and page.mode == "full" then
        -- (the zoom's prompts only while a notch that way would move it)
        local out = {}
        local plate = FullPlate(page)
        local closer, further = false, false
        if plate then closer, further = plate:Zooms() end
        if closer then out[#out + 1] = PROMPT.closer end
        if further then out[#out + 1] = PROMPT.further end
        if plate then out[#out + 1] = PROMPT.move end
        CardPrompt(out, at)
        out[#out + 1] = scope.from and PROMPT.backPlates or PROMPT.backLeft
        return out
    end
    if at.group == "page" then
        local out = {}
        if at.plate then
            -- (A goes in only where there is a mark to stand on)
            local plate = at.whole and at.whole()
            if plate and plate:HasMarks() then out[#out + 1] = PROMPT.marks end
            out[#out + 1] = PROMPT.whole
        elseif at.person then
            out[#out + 1] = PROMPT.person
        end
        CardPrompt(out, at)
        out[#out + 1] = PROMPT.backLeft
        return out
    end
    if at.group == "run" then
        local out = {}
        local k = at.kind
        if k == "title" or k == "scrap" then
            out[1] = PROMPT.layout
        elseif k == "sig" and at.kept then
            out[1] = PROMPT.person
        elseif k == "add" then
            out[1] = PROMPT.keep
        elseif k == "others" then
            out[1] = PROMPT.others
        end
        out[#out + 1] = PROMPT.backLeft
        return out
    end
    if at.group == "match" then
        local out = {}
        local k = at.kind
        if k == "ticket" then
            out[1] = PROMPT.match
        elseif k == "back" then
            out[1] = PROMPT.evening
        elseif (k == "row" or k == "hand") and at.kept then
            out[1] = PROMPT.person
        elseif k == "turn" then
            out[1] = page and page.mode == "matches" and PROMPT.turnRoll or PROMPT.turnBoard
        end
        out[#out + 1] = (page and page.mode == "match" and page.matchBack) and PROMPT.backEvening or PROMPT.backLeft
        return out
    end
    if at.group == "marks" then
        local out = { PROMPT.whole }
        CardPrompt(out, at)
        out[#out + 1] = PROMPT.backPlate
        return out
    end
    if at.prompt then return { at.prompt } end
    local d = at.data
    local out = { d.later and PROMPT.person or (d.zone and not d.zone.dungeon and PROMPT.map) or PROMPT.open }
    local page = Road()
    if page and #page.recap.entries > 1 then out[#out + 1] = PROMPT.levels end
    return out
end

Pad.RegisterScope("yourdiary", scope)

-- The hand changed with the page open: the left page built again, one
-- level or the whole contents, at the open level's rubric.
Pad.Input.OnChange(function()
    local page = Road()
    if not (page and ns.UI.JournalShowing("journey")) then return end
    YourDiary.Rebuild(false)
    if page.mode == "full" then YourDiary.FullHint() end
    local at = page.rubrics[page.open]
    if at then page.entries:SetOffset(at - 1) end
    Pad.Refresh()
end)
