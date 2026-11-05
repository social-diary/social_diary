-- A plate's margin in Your Diary (JRN-22): a person's strip (NewNote), the
-- registry every other kind of note joins (ns.UI.JourneyMargin.Register,
-- its spec below, and the core's people), the pools made for them
-- (EnsurePools), the margin's items in their order (MarginOrder), and how
-- they are laid: written (MarginNote), shared out along a row (Columns,
-- Shared, ROW), laid down the boxes with their leaders (LayNotes), rolled
-- back (Mark, Undo), and quoted notes kept shorter before anything is left
-- off (WriteMargin, QUOTES). `quoteMost` is this file's alone.
--
-- The module and its siblings: UI/Journey/Look.lua.

local addonName, ns = ...

local Text = ns.UI.JourneyText
local Plate = ns.UI.JourneyPlate
local YourDiary = ns.UI.YourDiary

local CAPTION, STRIPS = YourDiary.CAPTION, YourDiary.STRIPS
local ToPerson = YourDiary.ToPerson
local Handout, LeaderMark, Leader = YourDiary.Handout, YourDiary.LeaderMark, YourDiary.Leader
local NoteGuid, Named, Rival, Tier = YourDiary.NoteGuid, YourDiary.Named, YourDiary.Rival, YourDiary.Tier

-- A margin note: a paper strip taped beside the plate, a name in the
-- diary's hand that opens their page and what happened under it.
local function NewNote()
    local page = YourDiary.page
    local strip = ns.UI.PaperStrip(page.right)
    -- Above the plates and the leaders: a strip lies on the page over the
    -- start of its leader, and takes the mouse before anything under it.
    strip:SetFrameLevel(page.right:GetFrameLevel() + STRIPS.level)
    return strip
end

--------------------------------------------------------------------------
-- The margin's kinds (JourneyMargin.Register)
--------------------------------------------------------------------------

-- What a plate's margin holds, in the order it is given room (MarginOrder):
-- the people who did something with you, then the features' cards by how
-- much they matter, then the people only seen, then filler (the order is
-- the user's, case by case). The people are the diary's own and placed
-- here; every other kind of note (a card, a slip) registers itself, so a
-- feature's file (Features/<Name>/, loaded after UI/) puts its note in
-- every plate's margin without this file knowing of it
-- (.claude/registry-refactor.md, phase 4). Each registration's comment
-- says why it stands where it does.
--
-- Each kind is laid as the people's strips are (LayNotes): from its own
-- pool, down the boxes, a leader from it to its mark, left off where it
-- has no room (and everything after it), then laid again by its marks'
-- heights; and the caption's words told what it showed, so whatever had
-- no room is said there instead (Text.PlateCaption's `said`).
--
-- `spec` (JourneyMargin.Register(kind, spec)), `kind` the name its items
-- carry (it.kind, plate.margin's; never "person"):
--   order    its place in the margin: lowest first, and first left off
--            last. The people who did something with you stand at
--            PEOPLE.close (10) and those only seen at PEOPLE.seen (80);
--            at equal numbers the people go first, then the kinds in the
--            order they registered. A kind registered from
--            Features/<Name>/ says its number there. Leave gaps.
--   item     function(plate) → one item or nil; or
--   items    function(plate) → a list of them (a card each item).
--            An item is { top, x, ... }: `top` its mark's height on the
--            page (the column is laid again in that order, so leaders do
--            not cross), `x` where across the page its leader likeliest
--            goes (for a row of notes under the plate), and its own fields
--            (it.killer, it.hunt, ...: the tests read them). `kind` and
--            `rank` (its place in the order) are set here.
--   pool     the page's key for its pool of notes (page.killerPool, ...);
--            kinds may share one (a killer's and a close call's card are
--            one card, the killer card).
--   new      function(parent) → a new note for the pool, the first time it
--            is needed. It is laid over the plates (STRIPS). A note is what
--            the comment over ns.UI.PaperStrip in UI/Paper/Strip.lua says
--            ("The margin's note": :Layout(x, y, w, room) → w, h,
--            :Nearest(x, y), :Smaller(), `overfull`); a card is a strip
--            laid through its hooks (the same comment).
--   write    function(note, it, c): the note written for its item. `c`:
--            plate, e (the entry), level, named (who the people's notes
--            name), now, Seed(...) (its parts joined with the plate's map
--            and level: a note's seeded look, the same each time),
--            ToPerson(guid) (a name that opens their page).
--   mark     function(it, note) → { x, y } on the page: where its leader
--            goes.
--   personLike  true: a person's strip by another kind, which keeps a shared row's
--            width as theirs does
--   custom   optional function(it) → kind, record: the moment's kind and the
--            record this card shows, when the player may change it
--            (Core/Custom.lua): a right click on the card opens the editor.
--   wants    optional function(it) → the width it would like in a row of
--            fewer notes than boxes (Shared): a hunt's card its wide
--            arrangement.
--   assume   optional function(said, plate, slot, plan): tells the words,
--            before the margin is laid, what it would show if all of it
--            had room (said[...], Text.PlateCaption's `said`).
--   say      optional function(said, shown, plate): tells the words what
--            it showed (`shown`, its items that had room, maybe none), so
--            what had none goes into them. Asked in `order`, so a kind may
--            leave a later one's word to it (a witness's creature, which a
--            killer's card left off overrules).
--   count    optional: the page's key counting its notes written
--            (page.killersWritten, ...: the tests'), set to 0 as the
--            plates are drawn; counted(shown, plate) → how many where it
--            is not just its shown items (good luck on a print counts).
--   filler   true: it is filler (the user, 14 Oct). Left off, its words go
--            in the caption (`say` is asked only then) but never cost the
--            caption its place over the plate nor run it past its foot;
--            `flag` names the plate field saying whether the words told
--            it.
--   fits     optional function(plan, slot) → false where what it puts on
--            a light plate's print will not go on the smaller print tucked
--            into F+L (`slot`): the page is FL then.
--   after    optional function(plate, c): once the margin is laid, for
--            what it draws besides its notes; c.Leader(from, mark) draws a
--            leader (good luck's print up to its star).
local NONE = {}
local PEOPLE = { close = 10, seen = 80 }
local EnsurePools
local marginKinds = ns.Registry.New({
    what = "JourneyMargin.Register(kind, { order, item | items, pool, new, write, mark, ... })",
    key = "kind", order = "order", default = 100,
    check = function(kind, spec)
        return kind ~= "person" and (spec.item or spec.items) and type(spec.pool) == "string"
            and spec.new and spec.write and spec.mark
    end,
    changed = function() EnsurePools() end,
})
local MARGIN, MARGIN_ORDER, MARGIN_ALL = marginKinds.specs, marginKinds.list, marginKinds:Ordered()
local Margin = { KINDS = MARGIN, ORDER = MARGIN_ORDER, PEOPLE = PEOPLE }
ns.UI.JourneyMargin = Margin

-- The right page's pools for every registered kind, made as they are first
-- needed, and the lists of them: the margin's (Mark, Undo) and the whole
-- right page's (DrawRight).
function EnsurePools()
    local page = YourDiary.page
    if not page then return end
    local margin, right = { "notePool" }, { page.leaderPool, page.dotPool, page.headingPool, page.captionPool,
        page.notePool }
    local seen = { notePool = true }
    for _, spec in ipairs(MARGIN_ORDER) do
        local key = spec.pool
        if not page[key] then
            local new = spec.new
            page[key] = Handout(function()
                local note = new(page.right)
                note:SetFrameLevel(page.right:GetFrameLevel() + STRIPS.level)
                return note
            end)
        end
        if not seen[key] then
            seen[key] = true
            margin[#margin + 1] = key
            right[#right + 1] = page[key]
        end
    end
    margin[#margin + 1], margin[#margin + 2] = "leaderPool", "dotPool"
    page.marginPools, page.rightPools = margin, right
end

-- The people are the core's: those who did something with you, then
-- those only seen, each first among the kinds at its number (MarginOrder;
-- after EnsurePools, which each change asks for).
marginKinds:Core("people.close", { order = PEOPLE.close, close = true }, -1)
marginKinds:Core("people.seen", { order = PEOPLE.seen, close = false }, -1)

function Margin.Register(kind, spec)
    return marginKinds:Add(kind, spec)
end

-- Takes a kind out of every margin again (a test's own kind). Its pool
-- stays, unused.
function Margin.Remove(kind)
    marginKinds:Remove(kind)
end

-- A kind's items on `plate`, a list.
local function ItemsOf(spec, plate)
    if spec.items then return spec.items(plate) or {} end
    local item = spec.item(plate)
    return item and { item } or {}
end

-- The margin's items for `plate` in their order. Each { kind = "person"
-- or a registered kind's, top, x, rank, ... }; a person's { g, index }.
local function MarginOrder(plate, groups)
    local order = {}
    local function Add(item)
        item.rank = #order + 1
        order[#order + 1] = item
    end
    -- A person's: the mark LeaderMark would choose first, leftmost of
    -- equals (the strip it would be nearest is not laid yet).
    local function Across(g)
        local quoted = Text.MarginQuoted(g.moments)
        if quoted and plate.where[quoted] then return plate.where[quoted][1] end
        local x, rank
        for _, m in ipairs(g.moments) do
            local at = plate.where[m]
            local r = at and (Plate.PRIORITY[m.kind] or math.huge)
            if at and (not x or r < rank or (r == rank and at[1] < x)) then x, rank = at[1], r end
        end
        return x or 0
    end
    -- The people of tier 1 (close) or past it, in their marks' order.
    local function People(close)
        for i, g in ipairs(groups) do
            if (Tier(g) == 1) == close then Add({ kind = "person", g = g, index = i, top = g.top, x = Across(g) }) end
        end
    end
    for _, spec in ipairs(MARGIN_ALL) do
        if spec.close ~= nil then
            People(spec.close)
        else
            for _, item in ipairs(ItemsOf(spec, plate)) do
                item.kind = spec.kind
                Add(item)
            end
        end
    end
    return order
end

-- How many lines a person's quoted note may take on their strip, tried
-- in turn while the margin will not hold all it has (WriteMargin): its
-- strip's most (UI/Paper/Strip.lua's STRIP.quote), then fewer. The one
-- being tried is `quoteMost`.
local QUOTES = { 3, 2, 1 }
local quoteMost

-- The note for one of MarginOrder's items, from its pool, written: a
-- person's strip here, any other kind's note by its own `write`
-- (JourneyMargin.Register). `named` is who the people's notes name
-- (Named), so a card does not say again what a person's note says.
local function MarginNote(plate, e, it, named)
    local page = YourDiary.page
    local level = e.level or e.week or 0
    if it.kind == "person" then
        local strip = page.notePool:Next()
        -- A card's right click stays on a strip of the pool it shares (Margin.Register's
        -- `custom`, told below): a person's has no editor.
        strip:SetRight(nil)
        local g, guid = it.g, NoteGuid(it.g)
        -- Their latest note quoted under the name; where it was cut, here
        -- or on the strip, the tooltip has the rest.
        local quote, cut, whole = Text.MarginQuote(g.moments)
        local function Tip()
            if not (cut or strip.quoteCut) then return nil end
            return { { "Your note" }, { whole, 1, 1, 1, true } }
        end
        -- A stranger's name (a first sighting in hindsight) is a link in
        -- the plainer ink, to their glimpse, and its tooltip says so: who,
        -- not in the diary yet, and where the click goes (the
        -- stranger-glimpse proposal, section 5, 5 Nov 2026). A quoted note
        -- cannot be on a stranger's strip, so the quote's tooltip stays
        -- the diary people's. Ink and tooltip only: the strip lays out as
        -- it did.
        local stranger = guid ~= nil and not ns.Diary.IsDiary(guid)
        local tip = quote and Tip or nil
        if stranger then
            tip = function()
                return ns.UI.PersonText.GlimpseTip(ns.Characters.FullName(guid) or ns.Characters.Name(guid))
            end
        end
        strip:SetNote({ name = Text.MarginWho(guid), what = Text.MarginWhat(g.moments, e.level), quote = quote,
            quoteLines = quoteMost, guid = guid, plain = stranger, rival = Rival(guid), onClick = ToPerson, tip = tip,
            seed = table.concat({ guid or ("someone" .. it.index), plate.mapID or 0, level }, ":") })
        return strip
    end
    local spec = MARGIN[it.kind]
    local note = page[spec.pool]:Next()
    spec.write(note, it, { plate = plate, e = e, level = level, named = named, now = page.now, ToPerson = ToPerson,
        Seed = function(...)
            local parts, n = { ... }, select("#", ...)
            parts[n + 1], parts[n + 2] = plate.mapID or 0, level
            return table.concat(parts, ":")
        end })
    -- Told every time, cards of one pool being of several kinds (a killer's
    -- has no editor, a close call's on the same strip has).
    if rawget(note, "SetRight") then
        local kind, rec
        if spec.custom then kind, rec = spec.custom(it) end
        note:SetRight(kind and function() YourDiary.CardSheet.Edit(kind, rec) end or nil)
    end
    return note
end

-- Where a note's leader goes: a person's likeliest mark (LeaderMark), any
-- other kind's by its own `mark`.
local function MarginMark(plate, it, note)
    if it.kind == "person" then return LeaderMark(it.g, note, plate) end
    return MARGIN[it.kind].mark(it, note)
end

-- `items` laid in turn down the `boxes` ({ x, y, w, limit, align }), each
-- with its leader: down the first box as far as it goes, then on down the
-- next, never past the page's foot; a box set flush right lays each note
-- against its right side. Stops at the first that finds no room (it is
-- hidden). Returns how many were laid.
-- Boxes side by side (`boxes.row`, the one plate's row under it, TOP)
-- take a note each where they can: each the box nearest its mark across
-- the page, in turn left to right, a box kept for each note still to
-- come (Columns); more notes than boxes share them, the first boxes one
-- more. A note with no room in its box still goes on to the next.
local function Columns(items, boxes)
    local n, m, at = #items, #boxes, {}
    for i, it in ipairs(items) do
        if n > m then
            -- Shared: box k holds n / m notes, the first n % m one more.
            local k, before = 1, 0
            while before + math.floor(n / m) + (k <= n % m and 1 or 0) < i do
                before = before + math.floor(n / m) + (k <= n % m and 1 or 0)
                k = k + 1
            end
            at[i] = k
        else
            local near, gap = 1, math.huge
            for k, box in ipairs(boxes) do
                local d = math.abs((it.x or 0) - (box.x + box.w / 2))
                if d < gap then near, gap = k, d end
            end
            at[i] = math.min(math.max(near, (at[i - 1] or 0) + 1), m - (n - i))
        end
    end
    return at
end

-- `replay`: the notes laid again in another order (WriteMargin's by
-- height), each as small as it was in the order of importance
-- (it.smaller) and no smaller: a note of less importance laid first must
-- not make one of more give up its room (12 Oct: a hunt's card cost the
-- close call's its deed); where they then do not fit, the order of
-- importance stands.
-- A row under one plate (LAYOUT[1][1].top.row) with fewer notes than
-- boxes shares its width among the notes there are (Shared): a box for
-- each, as wide as the widest note would like (its kind's `wants`: a hunt
-- card's wide arrangement, Features/Hunts/HuntCard.lua's card:Preferred,
-- or a lucky card's, its tag beside the struck words,
-- Features/Hunts/LuckyCard.lua) and no wider than its
-- share of the row (217 px for two) or `most` px; never narrower than the
-- row's own boxes. (26 kills, 12 expected, want 187 px; 37 for about 15,
-- some 212.)
-- Each box lies as near its note's mark as the row lets it. A person's
-- strip keeps the row's own width (its quote would run out into a
-- banner), and any note narrower than its box lies under its mark.
-- (12 Oct, in the client: a hunt card wrapped its count into a 142 px box
-- with the row's left box empty beside it.)
local ROW = { most = 220 }

-- `boxes` (a row) for `order` (MarginOrder): the row as it is, or with
-- fewer notes than boxes, a box each, shared out (ROW).
local function Shared(order, boxes)
    local n = #order
    if not boxes.row or n == 0 or n >= #boxes then return boxes end
    local first, last = boxes[1], boxes[#boxes]
    local want = first.w
    for _, it in ipairs(order) do
        local spec = MARGIN[it.kind]
        if spec and spec.wants then want = math.max(want, spec.wants(it)) end
    end
    if want <= first.w then return boxes end
    local x0, x1 = first.x, last.x + last.w
    local gap = boxes[2].x - first.x - first.w
    local w = math.floor(math.min(want, ROW.most, (x1 - x0 - gap * (n - 1)) / n))
    -- In the order of their marks across the page, each box under its
    -- mark where it can be: right of the one before, room left for those
    -- after.
    local marks = {}
    for i, it in ipairs(order) do marks[i] = it.x or 0 end
    table.sort(marks)
    local shared = { row = true, shared = true, base = first.w }
    local at = x0
    for i = 1, n do
        local most = x1 - (n - i + 1) * w - (n - i) * gap
        local x = math.max(at, math.min(most, marks[i] - w / 2))
        shared[i] = { x = x, y = first.y, w = w, limit = first.limit }
        at = x + w + gap
    end
    return shared
end

local function LayNotes(plate, e, items, boxes, named, replay)
    local foot = ns.JourneyCapture.On() and CAPTION.limit or CAPTION.offLimit
    local k, box = 1, boxes[1]
    local y = box.y
    local columns = boxes.row and Columns(items, boxes) or nil
    for i, it in ipairs(items) do
        if columns and columns[i] > k then
            k = columns[i]
            box = boxes[k]
            y = box.y
        end
        local note = MarginNote(plate, e, it, named)
        -- The height left in the box: a note that can fit itself to it (a
        -- close call's card draws its picture smaller) does so before it
        -- goes on to the next box, which in a row is another note's.
        local function Room() return math.min(box.limit or foot, foot) - y end
        local function Over(h) return note.overfull or h > Room() end
        local smaller = 0
        if replay then
            while smaller < (it.smaller or 0) and rawget(note, "Smaller") and note:Smaller() do
                smaller = smaller + 1
            end
        end
        -- In a shared row (Shared) a person's strip keeps the row's width.
        local function Wide() return (boxes.shared and (it.kind == "person" or (MARGIN[it.kind] and MARGIN[it.kind].personLike))) and math.min(box.w, boxes.base) or box.w end
        local w, h = note:Layout(box.x, y, Wide(), Room())
        while Over(h) and boxes[k + 1] do
            k = k + 1
            box = boxes[k]
            y = box.y
            w, h = note:Layout(box.x, y, Wide(), Room())
        end
        -- A note that can do with less (a close call's card, the killer card's:
        -- its picture, then its deed; a hunt's, Features/Hunts/HuntCard.lua:
        -- its lines; a lucky card's, Features/Hunts/LuckyCard.lua: its
        -- creature's line, its icon)
        -- tries that before it is left off.
        while not replay and Over(h) and rawget(note, "Smaller") and note:Smaller() do
            smaller = smaller + 1
            w, h = note:Layout(box.x, y, Wide(), Room())
        end
        if not replay then it.smaller = smaller end
        if Over(h) then
            note:Hide()
            return i - 1
        end
        if box.align == "RIGHT" and type(w) == "number" and w < box.w then
            note:Layout(box.x + box.w - w, y, box.w, Room())
        elseif boxes.shared and type(w) == "number" and w < box.w then
            -- Under its mark, as near as the box lets it.
            local x = math.max(box.x, math.min(box.x + box.w - w, (it.x or 0) - w / 2))
            if x ~= box.x then note:Layout(x, y, Wide(), Room()) end
        end
        Leader(note, MarginMark(plate, it, note), plate)
        -- The note as laid, for the caption (Plated: whether a witness's
        -- card kept its foe's line).
        it.note = note
        y = y + h + CAPTION.gap
    end
    return #items
end

-- What the right page's pools and leaders hold now, and back to it: a
-- margin laid again from there. The pools are the people's strips', every
-- registered kind's (EnsurePools) and the leaders'.
local function Mark()
    local page = YourDiary.page
    local at = { links = #page.links }
    for _, key in ipairs(page.marginPools) do at[key] = page[key].used end
    return at
end

local function Undo(at)
    local page = YourDiary.page
    for _, key in ipairs(page.marginPools) do
        local pool = page[key]
        for i = at[key] + 1, pool.used do pool[i]:Hide() end
        pool.used = at[key]
    end
    for i = #page.links, at.links + 1, -1 do page.links[i] = nil end
end

-- A plate's margin (MarginOrder) laid down `boxes`: as much of it as there
-- is room for, in its order of importance, the rest left off. What is
-- shown is then laid again in the order of its marks' heights (across the
-- page, for a row of boxes), so the leaders do not cross, where that
-- still fits; else in its order of importance. Returns the items shown,
-- and all there were to show (MarginOrder's).
local function WriteMargin(plate, e, groups, boxes)
    local order = MarginOrder(plate, groups)
    boxes = Shared(order, boxes)
    local close = {}
    for _, it in ipairs(order) do
        if it.kind == "person" and Tier(it.g) == 1 then close[#close + 1] = it.g end
    end
    local named = Named(close, #close)
    local at = Mark()
    -- Quoted notes are kept to fewer lines (QUOTES) rather than cost
    -- anything after them its place; where fewer lines make no more room,
    -- they keep the most that showed as much.
    local n, best, most
    for k = 1, #QUOTES do
        quoteMost = QUOTES[k]
        n = LayNotes(plate, e, order, boxes, named)
        if n == #order then break end
        if not best or n > best then best, most = n, QUOTES[k] end
        Undo(at)
        if k == #QUOTES then
            quoteMost = most
            n = LayNotes(plate, e, order, boxes, named)
        end
    end
    local shown = {}
    for i = 1, n do shown[i] = order[i] end
    if n > 1 then
        local sorted = {}
        for i, it in ipairs(shown) do sorted[i] = it end
        local key = boxes.row and "x" or "top"
        table.sort(sorted, function(a, b)
            if a[key] ~= b[key] then return a[key] < b[key] end
            return a.rank < b.rank
        end)
        Undo(at)
        if LayNotes(plate, e, sorted, boxes, named, true) < n then
            Undo(at)
            LayNotes(plate, e, shown, boxes, named)
        end
    end
    return shown, order
end

YourDiary.NewNote, YourDiary.EnsurePools, YourDiary.NONE = NewNote, EnsurePools, NONE
YourDiary.MARGIN, YourDiary.MARGIN_ORDER = MARGIN, MARGIN_ORDER
YourDiary.ROW, YourDiary.Shared, YourDiary.Mark, YourDiary.Undo, YourDiary.WriteMargin = ROW, Shared, Mark, Undo, WriteMargin
