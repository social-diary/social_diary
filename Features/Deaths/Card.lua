-- The killer card (Your Diary's plates, JRN-21; Kind.lua): what killed you on a plate,
-- as option A of .claude/ui-proposal/killer-models-proposal.md, "Cut in
-- ink". A paper strip (UI/Paper/Strip.lua) taped in the plate's margin, last
-- of its notes, with a pencil leader to its death cross; on it, straight on
-- the slip's paper, the creature as a flat silhouette in ink, its head and
-- shoulders in profile, facing the cross (a Victorian cut-paper portrait,
-- the oldest keepsake picture there is), and under it its name in the
-- diary's hand and what it did, "killed you twice".
--
-- Which deaths get one (the proposal's 0.1, 0.2):
--   - only a creature's: a fall or a drowning has no card (its cross's
--     tooltip says what it was), a player's death is their fight's strip,
--     and a death from before deaths were kept is its cross alone;
--   - one card a plate: the killer that got you most there, a tie to the
--     latest; but a rare, an elite or a boss outranks any number of common
--     kills (the user's choice, 10 Oct), the higher rank first;
--   - after the people: the card is the margin's last note and the first
--     left off when the column runs out; then its name goes into the
--     caption ("Level 12, and two deaths, to a Sunscale Lashtail.").
-- The same card may carry another feature's subject, a face of its own
-- (KillerCard.RegisterFace, below): the close calls' creature that nearly
-- got you (Features/CloseCalls/Card.lua), beside its killer's card, under
-- its own heading, tag and chart.
--
-- The picture walks down one ladder, each card on its own (0.4): the ink
-- silhouette (a PlayerModel drawn from the creature's display with its
-- lights put out, black) where the client has everything it needs and KILLER.silhouette
-- is on; else the 2D print (the creature's portrait texture, desaturated,
-- warmed, in a rectangular window with small photo corners, the same shape
-- as the model's, Q4); else the name alone. No display kept, no picture.
-- A model that has drawn nothing after KILLER.check seconds gives way to the
-- print. The name is always written: nothing is only in the picture.
--
-- Of the model's calls the client has shown SetDisplayInfo, SetFacing, the
-- lights put out and the camera's fit (10 Oct); the rest are unproven, so
-- every one is looked up and called guarded: a method the client lacks is
-- skipped, one that errors is caught. The model is still at rest (frozen,
-- no idle), never faint, a child of the strip and never of a plate's
-- clipping frame (P5); at most one a card, so six on a page (two cards a
-- plate).
--
-- The card is ns.Deaths.Card. It is shared, and this folder owns it:
--   - Deaths' own: Match, Choose, the card's SetKiller, Tip; the pass
--     that matches the deaths to the plate's crosses and chooses the
--     killer, and the killer's note in the margin (the foot of this file);
--   - the faces other features register for it (RegisterFace): the card
--     wears one with its own subject, and its methods are on every card
--     (Features/CloseCalls/Card.lua's: SetFoe, Deed, and its chart,
--     VITALS; its pass and its note in the margin share the killer's
--     pool, page.killerPool), reaching New, KILLER and RANK here at call
--     time;
--   - read by the witnesses (Features/Witnesses/): their pass (order 30)
--     reads the crosses' deaths the killer's pass leaves and may clear
--     plate.killer (or the close call's plate.foe).

local addonName, ns = ...

local Style = ns.Style

local KillerCard = {}
ns.Deaths.Card = KillerCard

-- The picture's room over the name: `w` by `h`, `gap` above the name;
-- `narrow` where the margin's column is under `below` px (the two-plate
-- layout's). The slip turns at most `turn` degrees (a model cannot turn
-- with it, and at about a degree no one can tell); its tape goes `tapeAt`
-- of the way along its top, clear of the picture by `clear` px, the slip
-- made wide enough for that. A name too long for the column is set at
-- `small`, the hand's smaller size (the plates' captions' second), and a
-- card whose name will not fit even so is left off.
-- The silhouette (A): on while `silhouette`, black: the model drawn with
-- its lights put out (`dark`), so only its outline shows, the cut-paper
-- portrait's black paper. In profile toward its cross: `face` is the
-- model's turn for a creature facing the page's left or right. Framed by
-- `frame`, the model always on its own camera (portrait zoom 0), which
-- fits the whole creature to the window whatever its size:
--   "body"  the whole creature, the camera at `distance` (its distance
--           scale);
--   "head"  head and shoulders (Q2), cropped from the whole: the camera
--           `head.distance` as far (closer), and the view moved by
--           `head.shift` of the window (across, away from the way it
--           faces; down) so its head and shoulders, at the top and front,
--           come into the middle. The same shares fit any creature, as
--           the camera has fitted it first. Not proven (its probes are
--           out); "body" where the client cannot move the view.
-- (10 Oct, in the client: under the portrait camera a model turned to
-- profile swung its head out of the camera's aim, a black blob; a custom
-- camera moved round it went into the model; fog did nothing at all, and
-- the lights put out drew it black. SetFacing(-pi/2) faces the viewer's
-- left.)
-- Held still in `pose` (stand: an attack can carry the head out of
-- frame; `blow` lists attacks to try first). The print (0): its portrait desaturated and warmed
-- by `tint`, edged in ink at `edge`, its photo corners `corner` px of
-- `ink` at `alpha` (MOUNT's kraft).
local KILLER = {
    picture = { w = 70, h = 48, gap = 2 }, narrow = { w = 62, h = 42, gap = 2, below = 140 },
    turn = 1.2, tapeAt = 0.8, clear = 4, small = 14,
    silhouette = true, frame = "body", distance = 1, dark = true, face = { left = -math.pi / 2, right = math.pi / 2 },
    head = { distance = 0.5, shift = { 0.2, 0.3 } },
    pose = { anim = 0, variation = 0, at = 0, blow = nil }, check = 1.5,
    print = { tint = { 1, 0.88, 0.68 }, edge = 0.55, corner = 7, ink = { 0.29, 0.19, 0.105 }, alpha = 0.95 },
}
-- A death matches a cross whose stop or road it fell in, `slack` seconds
-- either side; one placed on the map but in no such time goes to the
-- nearest cross within `near` px of its spot.
local MATCH = { slack = 30, near = 24 }
-- What outranks what (Capture.lua's ranks); a common creature none.
local RANK = { worldboss = 4, rareelite = 3, rare = 2, elite = 1 }

local HAND = Style.NEUTON_ITALIC

-- The displays a model drew nothing from this session (KILLER.check): their
-- cards are the print from the start.
local BLANK = {}

--------------------------------------------------------------------------
-- Another feature's face on the card (KillerCard.RegisterFace)
--------------------------------------------------------------------------

-- The card is shared: another feature may put its own subject on it (the
-- close calls' creature that nearly got you, Features/CloseCalls/Card.lua),
-- the same slip, picture ladder, name and tooltip, with its own drawings
-- over and under the name. It registers a face; a card wears it when
-- told (card:Wear(face, k, note)), and takes it off when it is given
-- another subject (SetKiller, or another face), as the margin's pool
-- hands one card to a killer and a close call by turns.
--
-- `face` (KillerCard.RegisterFace(key, face), at load, so this file loads
-- first):
--   methods  optional { name = function(card, ...) }: put on every card
--            as it is made, so a note of the pool is told through them
--            (the close call's card:SetFoe, card:Deed)
--   plan     function(card, note, width, room, pic, Least) → plan, as a
--            card wearing it is laid: it sets the note's room over and
--            under the name (note.picture, note.under), its words
--            (note.what), its tape (note.tapeAt, note.least), as the strip
--            takes them. `room` is the width inside the slip's padding,
--            `pic` the picture's room by the column (KILLER.picture or
--            .narrow; nil without a picture), Least(over, tapeAt) the
--            slip's least width for its tape to start clear of `over` px
--            at its top. card.compact is set while it is laid again with
--            its picture drawn small (Layout: it stood taller than the
--            margin's room)
--   top      function(card, plan): what it draws over the name, before
--            the picture is laid (it may move the picture's room,
--            card.picture)
--   under    function(card, plan): what it draws after the picture
--   hide     function(card): what it drew put away (and its fields for
--            the tests cleared); asked of every face on every laying,
--            worn or not, before `top`
--   off      optional function(card): its own fields cleared, the card
--            given another subject
--   smaller  function(card) → whether it gave something up (card:Smaller,
--            the margin's, short of room)
local FACES = {}

function KillerCard.RegisterFace(key, face)
    assert(type(key) == "string" and type(face) == "table" and type(face.plan) == "function"
        and type(face.top) == "function" and type(face.under) == "function" and type(face.hide) == "function"
        and type(face.smaller) == "function",
        "Deaths.Card.RegisterFace(key, { plan, top, under, hide, smaller, ... })")
    for i = #FACES, 1, -1 do
        if FACES[i].key == key then table.remove(FACES, i) end
    end
    face.key = key
    FACES[#FACES + 1] = face
    return face
end

-- Takes a face off the card again (a test's own): cards made after no
-- longer get its methods, and no card lays it.
function KillerCard.RemoveFace(key)
    for i = #FACES, 1, -1 do
        if FACES[i].key == key then table.remove(FACES, i) end
    end
end
KillerCard.FACES = FACES

--------------------------------------------------------------------------
-- Which killer
--------------------------------------------------------------------------

-- Whether a stop or road drawn as `cross` held time `t`.
local function Holds(cross, t)
    for _, seg in ipairs(cross.segs or {}) do
        local from = seg.from or 0
        if t >= from - MATCH.slack and t <= (seg.to or from) + MATCH.slack then return true end
    end
    return false
end

local function Gap(cross, x, y)
    return (cross.x - x) ^ 2 + (cross.y - y) ^ 2
end

-- The deaths (Deaths.List's records) onto the plate's death crosses:
-- `crosses` { x, y (on the card), segs (the stops or road it marks), count },
-- each given its `deaths`. A death goes to a cross whose time held it (the
-- nearest of those to its spot, when it has one), else, placed on this map
-- and in the open `entry`, to the cross nearest its spot within MATCH.near.
-- `place(death)` is its spot on the card, nil off it. Before all that,
-- `countedOn(t)` (Journey.CountedOn), where given, is the segment the death
-- was counted on: it goes to that segment's cross, or to none where that
-- cross is not on this plate, whatever its time or spot (a long fight ends
-- long after its stop's last sample).
local function Marks(cross, seg)
    for _, s in ipairs(cross.segs or {}) do
        if s == seg or (s.kind == seg.kind and s.from == seg.from and s.mapID == seg.mapID) then return true end
    end
    return false
end

function KillerCard.Match(crosses, deaths, mapID, place, entry, countedOn)
    for _, cross in ipairs(crosses) do cross.deaths = {} end
    if #crosses == 0 then return crosses end
    for _, d in ipairs(deaths or {}) do
        local seg = countedOn and type(d.t) == "number" and countedOn(d.t) or nil
        if seg then
            for _, cross in ipairs(crosses) do
                if Marks(cross, seg) then
                    cross.deaths[#cross.deaths + 1] = d
                    break
                end
            end
        elseif type(d.t) == "number" and not (d.mapID and mapID and d.mapID ~= mapID) then
            local x, y
            if d.x and d.y and place then x, y = place(d) end
            local best, gap
            for _, cross in ipairs(crosses) do
                if Holds(cross, d.t) then
                    local g = x and Gap(cross, x, y) or 0
                    if not best or g < gap then best, gap = cross, g end
                end
            end
            if not best and x and (not entry or (d.t >= entry.from and d.t < entry.to)) then
                for _, cross in ipairs(crosses) do
                    local g = Gap(cross, x, y)
                    if g <= MATCH.near ^ 2 and (not best or g < gap) then best, gap = cross, g end
                end
            end
            if best then best.deaths[#best.deaths + 1] = d end
        end
    end
    return crosses
end

-- Whether a death was a creature's: a name and no world (a player's
-- death keeps no killer).
local function Creature(d)
    return type(d.name) == "string" and d.name ~= "" and not d.environment
end

-- The plate's one killer, from its crosses' deaths (Match), or nil: the
-- highest rank (RANK), then the most deaths, then the latest. { npcID,
-- name, rank, count, last (time), spell (the latest), display (the latest
-- kept), probable (none confirmed by the death recap), cross (where the
-- latest was), death (the latest's record: what a right click on the card
-- edits, the others staying as they were) }.
function KillerCard.Choose(crosses)
    local by, list = {}, {}
    for _, cross in ipairs(crosses or {}) do
        for _, d in ipairs(cross.deaths or {}) do
            if Creature(d) then
                local key = d.npcID or d.name
                local k = by[key]
                if not k then
                    k = { npcID = d.npcID, name = d.name, count = 0, probable = true }
                    by[key] = k
                    list[#list + 1] = k
                end
                k.count = k.count + 1
                if (RANK[d.rank] or 0) > (RANK[k.rank] or 0) then k.rank = d.rank end
                k.probable = k.probable and d.probable == true
                if not k.last or d.t >= k.last then
                    k.last, k.cross, k.name, k.death = d.t, cross, d.name, d
                    k.spell = d.spell or k.spell
                end
                local display = ns.Plain(d.display)
                if type(display) == "number" and display > 0 and (not k.shown or d.t >= k.shown) then
                    k.display, k.shown = display, d.t
                end
            end
        end
    end
    table.sort(list, function(a, b)
        local ra, rb = RANK[a.rank] or 0, RANK[b.rank] or 0
        if ra ~= rb then return ra > rb end
        if a.count ~= b.count then return a.count > b.count end
        return a.last > b.last
    end)
    local k = list[1]
    if k then k.shown = nil end
    return k
end

-- A death the player changed or wrote as a card of its own (Core/Custom.lua),
-- in Choose's shape: past the plate's one, one death to a card, and no hedging:
-- `probable` was the diary's doubt about what the player has now said.
local function OwnCard(d, mark)
    local display = ns.Plain(d.display)
    return { npcID = d.npcID, name = d.name, rank = d.rank, count = 1, last = d.t, spell = d.spell, death = d,
        mark = mark, display = type(display) == "number" and display > 0 and display or nil }
end

-- The plate's custom cards, the newest first, so that where the margin runs out
-- the oldest are the ones left to their marks: `edited`, the deaths the killer's
-- pass took off the crosses ({ d, mark }), and the inserted, on `marks` (their
-- own, plate.killedMarks). Only with a creature named, as a detected one: an
-- inserted death with none is its cross and no card.
function KillerCard.Customs(edited, marks)
    local list = {}
    for _, e in ipairs(edited or {}) do
        if Creature(e.d) then list[#list + 1] = OwnCard(e.d, e.mark) end
    end
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            if m.killedBy and Creature(m.killedBy) then list[#list + 1] = OwnCard(m.killedBy, mark.at) end
        end
    end
    table.sort(list, function(a, b) return (a.last or 0) > (b.last or 0) end)
    return list
end

--------------------------------------------------------------------------
-- The model, guarded
--------------------------------------------------------------------------

-- Whether `object` has `method` (a missing one is nil in the client; the
-- tests' mock raises on it, so it is looked up guarded).
local function Can(object, method)
    local ok, fn = pcall(function() return object[method] end)
    return ok and type(fn) == "function"
end

-- `method` called on `object`, if it has it: whether it ran, and what it
-- returned.
local function Try(object, method, ...)
    if not Can(object, method) then return false end
    return pcall(object[method], object, ...)
end

-- What the silhouette cannot do without.
local NEEDS = { "SetDisplayInfo", "SetFacing", "SetLight" }

-- The lights put out (P3'), as the modern client takes them; the old
-- argument list is not tried. Nil where the client has no vectors.
local function Dark()
    if type(CreateVector3D) ~= "function" or type(CreateColor) ~= "function" then return nil end
    local ok, light = pcall(function()
        return { omnidirectional = false, point = CreateVector3D(0, 0, -1), ambientIntensity = 0,
            ambientColor = CreateColor(0, 0, 0), diffuseIntensity = 0, diffuseColor = CreateColor(0, 0, 0) }
    end)
    return ok and light or nil
end

-- Whether `model` can be the silhouette: everything in NEEDS, the lights
-- to put out, and a way to hold it still.
local function Inks(model)
    if not (model and KILLER.dark and Dark()) then return false end
    for _, method in ipairs(NEEDS) do
        if not Can(model, method) then return false end
    end
    return Can(model, "FreezeAnimation") or (Can(model, "SetAnimation") and Can(model, "SetPaused"))
end

-- Whether the client can draw the print.
local function Prints()
    return type(SetPortraitTextureFromCreatureDisplayID) == "function"
end

-- Whether `model` has drawn something: its model file, where the client
-- says; taken on trust where it cannot.
local function Drawn(model)
    if not Can(model, "GetModelFileID") then return true end
    local ok, id = Try(model, "GetModelFileID")
    if not ok then return true end
    id = ns.Plain(id)
    return type(id) == "number" and id > 0
end

-- Held still: the first of KILLER.pose's attacks the model has, else
-- standing; frozen, or else paused.
local function Freeze(model)
    local P = KILLER.pose
    local anim = P.anim
    for _, id in ipairs(P.blow or {}) do
        local ok, has = Try(model, "HasAnimation", id)
        if ok and ns.Plain(has) == true then
            anim = id
            break
        end
    end
    if Try(model, "FreezeAnimation", anim, P.variation, P.at) then return true end
    Try(model, "SetAnimation", anim)
    return (Try(model, "SetPaused", true))
end

-- The model framed (KILLER.frame) in profile toward `facing`, in a window
-- `w` by `h`: the whole creature on its own camera, or its head and
-- shoulders cropped from that.
local function Frame(model, facing, w, h)
    local head = KILLER.frame == "head" and Can(model, "SetCamDistanceScale") and Can(model, "SetViewTranslation")
        and KILLER.head
    Try(model, "SetPortraitZoom", 0)
    Try(model, "SetFacing", facing)
    Try(model, "SetCamDistanceScale", head and head.distance or KILLER.distance)
    local away = facing == KILLER.face.left and 1 or -1
    Try(model, "SetViewTranslation", head and away * head.shift[1] * w or 0, head and -head.shift[2] * h or 0)
end

-- The model as ink: framed in profile toward `facing` in a window `w` by
-- `h`, still, its lights out, its particles off. Called again once the
-- model has loaded, as a load may reset it.
local function Ink(model, facing, w, h)
    Frame(model, facing, w, h)
    Freeze(model)
    local dark = Dark()
    if dark then Try(model, "SetLight", true, dark) end
    Try(model, "SetParticlesEnabled", false)
end

--------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------

-- A card on `parent` (the right page): a paper strip, its model made
-- when first wanted. card:SetKiller(k, seed, now) with Choose's killer
-- (and k.mark, its cross on `parent`), then card:Layout(x, y, width) as a
-- strip's; card.mode says what its picture is: "ink", "print" or "name".
-- Laid through the strip's hooks (UI/Paper/Strip.lua), `hooks`, filled in
-- below, after its picture's drawing.
function KillerCard.New(parent)
    local hooks = {}
    local card = ns.UI.PaperStrip(parent, hooks)
    for _, face in ipairs(FACES) do
        for name, fn in pairs(face.methods or {}) do card[name] = fn end
    end

    -- The print's window: its ink edge, the portrait, its photo corners.
    card.printEdge = card:CreateTexture(nil, "ARTWORK", nil, 2)
    card.print = card:CreateTexture(nil, "ARTWORK", nil, 3)
    card.corners = {}
    for i = 1, 4 do card.corners[i] = card:CreateTexture(nil, "ARTWORK", nil, 4) end
    for _, texture in ipairs({ card.printEdge, card.print, unpack(card.corners) }) do
        if texture.SetSnapToPixelGrid then
            texture:SetSnapToPixelGrid(false)
            texture:SetTexelSnappingBias(0)
        end
        texture:Hide()
    end

    -- The model: a child of the strip, a level over its textures (its tape
    -- is clear of it), never taking the mouse; made once.
    local function Model()
        if card.model == nil then
            local ok, model = pcall(CreateFrame, "PlayerModel", nil, card)
            card.model = ok and model or false
            if card.model then
                model:SetFrameLevel(card:GetFrameLevel() + 1)
                Try(model, "EnableMouse", false)
                model:Hide()
                -- A load may reset what was set before it: set again.
                local can, has = Try(model, "HasScript", "OnModelLoaded")
                if can and has then
                    model:SetScript("OnModelLoaded", function(m)
                        if card.mode == "ink" and card.picture then
                            Ink(m, card.facing, card.picture.w, card.picture.h)
                        end
                    end)
                end
            end
        end
        return card.model or nil
    end

    -- What the picture is: the silhouette, the print or none, down the
    -- ladder.
    local function Mode(k)
        if not (k and k.display) then return "name" end
        if KILLER.silhouette and not BLANK[k.display] and Inks(Model()) then return "ink" end
        if Prints() then return "print" end
        return "name"
    end

    -- The card given subject `k` (its name, its display) and `note` (the
    -- strip's, SetNote), wearing `face` (RegisterFace) or none: any other
    -- face it wore is taken off.
    function card:Wear(face, k, note)
        for _, other in ipairs(FACES) do
            if other ~= face and other.off then other.off(self) end
        end
        self.killer, self.face = k, face
        self.mode = Mode(k)
        self:SetNote(note)
    end

    function card:SetKiller(k, seed, now)
        self:Wear(nil, k, { name = k.name, what = ns.Deaths.Killed(k.count), strong = true, seed = seed,
            tapeAt = KILLER.tapeAt, turn = KILLER.turn,
            tip = function() return KillerCard.Tip(k, now) end })
    end

    -- The print in the picture's room: the portrait, cropped to the room's
    -- shape, desaturated and warmed; false where it would not draw.
    local function Print(display)
        local texture = card.print
        if not (Prints() and pcall(SetPortraitTextureFromCreatureDisplayID, texture, display)) then return false end
        texture:SetDesaturated(true)
        local T = KILLER.print.tint
        texture:SetVertexColor(T[1], T[2], T[3], 1)
        return true
    end

    -- The picture laid in its room, as the card lies now.
    local function Picture()
        local pic, k = card.picture, card.killer
        local model = card.model or nil
        local ink, printed = card.mode == "ink" and pic ~= nil, card.mode == "print" and pic ~= nil
        if model then model:SetShown(ink) end
        card.print:SetShown(printed)
        card.printEdge:SetShown(printed)
        for _, corner in ipairs(card.corners) do corner:SetShown(printed) end
        if not pic then return end

        -- Toward its cross: the leader leaves on that side.
        local box = card.box
        card.facing = (k.mark and box and k.mark[1] < box[1] + box[3] / 2) and KILLER.face.left or KILLER.face.right

        if ink then
            model:ClearAllPoints()
            model:SetPoint("CENTER", card, "CENTER", pic.X, pic.Y)
            model:SetSize(pic.w, pic.h)
            if card.shownDisplay ~= k.display then
                card.shownDisplay = k.display
                Try(model, "SetDisplayInfo", k.display)
                -- One that draws nothing gives way to the print, and its
                -- display is not tried again this session.
                local display = k.display
                if C_Timer and C_Timer.After then
                    C_Timer.After(KILLER.check, function()
                        if card.shownDisplay ~= display or card.mode ~= "ink" then return end
                        -- Put away before it could load (another level
                        -- opened, the book closed): no verdict, and not laid
                        -- again, which would show it on whatever page is open
                        -- now; it is tried again when next shown. (11 Oct, in
                        -- the client: level 8's close call, opened and left
                        -- at once, lay on level 7 as a print.)
                        if not (card:IsVisible() and model:IsVisible()) then
                            card.shownDisplay = nil
                            return
                        end
                        if Drawn(model) then
                            local room = card.picture or pic
                            Ink(model, card.facing, room.w, room.h)
                        else
                            BLANK[display] = true
                            card.shownDisplay = nil
                            card.mode = Prints() and "print" or "name"
                            if card.box then card:Layout(card.box[1], card.box[2], card.column, card.room) end
                        end
                    end)
                end
            end
            Ink(model, card.facing, pic.w, pic.h)
            return
        end

        if not Print(k.display) then
            card.print:Hide()
            card.printEdge:Hide()
            for _, corner in ipairs(card.corners) do corner:Hide() end
            return
        end
        -- A square portrait shown through the room's shape: its full width,
        -- a band of its height a little above the middle (the head).
        local share = math.min(1, pic.h / pic.w)
        local v0 = math.max(0, 0.45 - share / 2)
        card.print:SetTexCoord(0, 1, v0, v0 + share)
        card:Lay(card.print, pic.lx, pic.ly, pic.w, pic.h)
        local P, INK = KILLER.print, Style.INK
        card.printEdge:SetColorTexture(INK[1], INK[2], INK[3], P.edge)
        card:Lay(card.printEdge, pic.lx, pic.ly, pic.w + 2, pic.h + 2)
        -- Its photo corners: a small pocket over each corner, a triangle
        -- where corners can move, none where they cannot.
        local c, x0, y0 = P.corner, pic.lx - pic.w / 2 - 1, pic.ly - pic.h / 2 - 1
        local x1, y1 = x0 + pic.w + 2, y0 + pic.h + 2
        local tri = {
            { x0, y0, x0 + c, y0, x0, y0 + c, x0, y0 + c },
            { x1 - c, y0, x1, y0, x1, y0 + c, x1, y0 + c },
            { x1, y1 - c, x1, y1 - c, x1, y1, x1 - c, y1 },
            { x0, y1 - c, x0, y1 - c, x0 + c, y1, x0, y1 },
        }
        for i, corner in ipairs(card.corners) do
            corner:SetColorTexture(P.ink[1], P.ink[2], P.ink[3], P.alpha)
            corner:SetShown(card:Bend(corner, unpack(tri[i])) == true)
        end
    end

    -- Where the margin has too little room for it, a card wearing a face
    -- gives up what the face says it can (RegisterFace's `smaller`); a
    -- killer's has nothing to give up. Whether there was anything left to
    -- give up (the page lays it again).
    function hooks.smaller(self)
        if not self.face then return false end
        return self.face.smaller(self)
    end

    -- Laid as a strip, with room for its picture by the column's width
    -- (KILLER.picture, or .narrow), its name at the smaller hand where it
    -- is long, its words in ink; wearing a face, with the room its plan
    -- asks over and under the name, its picture drawn small (card.compact)
    -- where it would stand taller than `room` px (the margin's height
    -- left, where the page says: `again`). card.overfull where the name
    -- will not fit `width` even so (the page leaves it off).
    --
    -- The slip's tape `tapeAt` of the way along, the slip wide enough for
    -- it to start KILLER.clear px past what is at its top (`over` px
    -- wide): a killer's picture, a face's heading (the strip's Least).
    local function Least(over, tapeAt) return card:Least(over, tapeAt, KILLER.clear) end
    function hooks.plan(self, note, width, room, again)
        -- The first laying: the margin's room kept (for a laying of its
        -- own, Picture's), the picture at its size.
        if not again then self.room, self.compact = room, nil end
        self.column = width
        local pic = self.mode ~= "name" and (width < KILLER.narrow.below and KILLER.narrow or KILLER.picture) or nil
        local l, _, r = self:Pad()
        local inside = width - l - r
        local plan
        if self.face then
            plan = self.face.plan(self, note, width, inside, pic, Least)
        else
            note.under = nil
            note.picture = pic
            note.tapeAt = KILLER.tapeAt
            note.least = pic and Least(pic.w, KILLER.tapeAt) or nil
        end
        self.name:SetFontObject(Style.FONT.noteWritten)
        self.name:SetText(note.name or "")
        if (self.name:GetUnboundedStringWidth() or 0) > inside then self.name:SetFont(HAND, KILLER.small, "") end
        self.overfull = (self.name:GetUnboundedStringWidth() or 0) > inside
            or (note.least or 0) > width or (note.under ~= nil and note.under.w > inside)
            or (note.picture ~= nil and note.picture.w > inside)
        return plan
    end
    -- Wearing a face, laid once more with its picture drawn small where it
    -- stood taller than the margin's room.
    function hooks.again(self, w, h, room)
        if self.face and self.picture and room and h > room then
            self.compact = true
            return true
        end
        return false
    end
    function hooks.draw(self, plan)
        local INK = Style.INK
        for _, line in ipairs(self:WhatLines()) do line:SetTextColor(INK[1], INK[2], INK[3]) end
        -- A killer's card has nothing of a face's (the pool hands the same
        -- card to a killer and a close call by turns, two a plate).
        for _, face in ipairs(FACES) do face.hide(self) end
        if self.face then self.face.top(self, plan) end
        Picture()
        if self.face then self.face.under(self, plan) end
    end

    return card
end

-- The card's tooltip as Style.Tooltip takes it: the creature's name, and
-- its lines (Text.lua's KillerTip).
function KillerCard.Tip(k, now)
    local title, lines = ns.Deaths.KillerTip(k, now)
    return Style.TipList(title, lines)
end

KillerCard.KILLER, KillerCard.RANK = KILLER, RANK

--------------------------------------------------------------------------
-- On the plates: the passes over the crosses, and the margin's notes
--------------------------------------------------------------------------

-- Deaths' pass (ns.UI.JourneyPlate.RegisterPass, after the marks): the
-- deaths kept with their killers (Kind.lua's list, the logged-in
-- character's) onto the crosses they fell at, each found by the segment
-- that counted it (Journey.CountedOn) where it can be: a cross that knows
-- its killers tells them under the mouse ("Died here twice" / "Sunscale
-- Lashtail, with Bite"), and the plate's one killer is chosen from them,
-- with where its card's leader ends on the page (plate.killer.mark).
-- First of the passes: the others' (the close call's, the witness's) come
-- after it.
--
-- The list is read as the player left it (Deaths.Read): a hidden death matches
-- no cross, whose count is still the route's, so it stays a cross with no name.
-- A death they changed tells its cross's tooltip what they said, and then comes
-- off cross.deaths, into a card of its own (KillerCard.Customs): what is left
-- there is what Choose picks the plate's one card from and what the witnesses'
-- pass reads, so neither merges it with others or takes its place.
ns.UI.JourneyPlate.RegisterPass("killer", {
    order = 10,
    draw = function(plate, c)
        local j = ns.Journey.For(ns.ownGUID)
        local At = c.At
        local deaths = {}
        for _, rec in ipairs(ns.Deaths.List(j)) do
            local d = ns.Deaths.Read(rec)
            if d then deaths[#deaths + 1] = d end
        end
        KillerCard.Match(c.crosses, deaths, c.mapID, function(d) return At(d.x, d.y) end, c.entry,
            function(t) return ns.Journey.CountedOn(j, t) end)
        local edited = {}
        for _, cross in ipairs(c.crosses) do
            if #cross.deaths > 0 then
                local told, kept = cross.deaths, {}
                -- What the tooltip reads: each death as the player left it,
                -- with the level it came at (the route's, Recap.LevelAt),
                -- on a copy, so nothing is written to the saved record.
                local said = {}
                for i, d in ipairs(told) do
                    said[i] = { name = d.name, spell = d.spell, environment = d.environment, t = d.t,
                        level = type(d.t) == "number" and ns.JourneyRecap.LevelAt(j, d.t) or nil }
                end
                c.HoverCross(cross, function() return c.Tip(ns.Deaths.DeathCross(cross.count, said, c.now)) end)
                for _, d in ipairs(told) do
                    if d.customOf then
                        local px, py = c.OnPage(cross.x, cross.y)
                        edited[#edited + 1] = { d = d, mark = { px, py } }
                    else
                        kept[#kept + 1] = d
                    end
                end
                cross.deaths = kept
            end
        end
        plate.customKillers = KillerCard.Customs(edited, plate.killedMarks)
        local k = KillerCard.Choose(c.crosses)
        if k then
            local px, py = c.OnPage(k.cross.x, k.cross.y)
            k.mark = { px, py }
        end
        plate.killer = k
    end,
})

-- What killed you, in the margin (ns.UI.JourneyMargin.Register): order
-- 40, after someone who was there (a witness, 30) and before what nearly
-- got you (the close call's card, 50, which shares its pool). Left off, its
-- name goes with the deaths in the words ("Two deaths, to a Sunscale
-- Lashtail.": `said.death`, Text.lua's caption).
ns.UI.JourneyMargin.Register("killer", {
    order = 40, pool = "killerPool", count = "killersWritten",
    new = function(parent) return KillerCard.New(parent) end,
    item = function(plate)
        local k = plate.killer
        return k and { killer = k, top = k.mark[2], x = k.mark[1] } or nil
    end,
    write = function(card, it, c)
        card:SetKiller(it.killer, c.Seed("killer", it.killer.npcID or it.killer.name), c.now)
    end,
    mark = function(it) return it.killer.mark end,
    custom = function(it) return "killedBy", it.killer.death end,
    say = function(said, shown, plate)
        if plate.killer and not shown[1] then said.death = ns.UI.JourneyText.KillerName(plate.killer) end
    end,
})

-- The deaths the player changed or wrote, each its own killer's card, past the
-- plate's one (Choose) and never replaced by a witness's: laid before the people
-- (10) and the other custom cards after it, so they are nearly the last left off
-- (.claude/features/custom-cards.md's table of orders). The same card, the same
-- pool. Left off, the first left off is named in the words, as a killer's is; the
-- plate's own killer, asked later, overrules it where its card is left off too.
ns.UI.JourneyMargin.Register("killerCustom", {
    order = 4, pool = "killerPool", count = "customKillersWritten",
    new = function(parent) return KillerCard.New(parent) end,
    items = function(plate)
        local items = {}
        for _, k in ipairs(plate.customKillers or {}) do
            items[#items + 1] = { killer = k, top = k.mark[2], x = k.mark[1] }
        end
        return items
    end,
    write = function(card, it, c)
        card:SetKiller(it.killer, c.Seed("killer", it.killer.last or it.killer.name), c.now)
    end,
    mark = function(it) return it.killer.mark end,
    custom = function(it) return "killedBy", it.killer.death end,
    say = function(said, shown, plate)
        local on = {}
        for _, it in ipairs(shown) do on[it.killer] = true end
        for _, k in ipairs(plate.customKillers or {}) do
            if not on[k] then
                said.death = ns.UI.JourneyText.KillerName(k)
                return
            end
        end
    end,
})

-- An inserted death's mark: the cross the route's deaths get, from the core's own
-- shape so that the two cannot drift apart, on the moment of its own (Kind.lua), so
-- nothing of the route is touched to draw it. Here and not in a Mark.lua of its
-- own, since it has no drawing of its own to keep there. After the close call's (30)
-- and before the luck's (40). On its own dot of paper, as the route's cross is, so
-- no halo; hovered as the route's is, and told by the same tooltip: those on
-- one spot together ("Died here twice", each killer once), as a cross of the
-- route's tells its deaths (`tips`, 9 Nov).
local function Inserted(list)
    local deaths = {}
    for i, m in ipairs(list) do deaths[i] = m.killedBy end
    return deaths
end

ns.UI.JourneyPlate.RegisterMark("killedBy", {
    order = 32, cap = 20, count = "insertedDeaths",
    radius = 5, halo = false, hover = 14,
    tip = function(m, now) return ns.Deaths.DeathCross(1, { m.killedBy }, now) end,
    tips = function(list, now) return ns.Deaths.DeathCross(#list, Inserted(list), now) end,
    keep = "killedMarks",
    draw = function(kit, x, y) ns.UI.JourneyPlate.SHAPE.death(kit, x, y) end,
})
