-- A sheet among Your Diary's plates (the city-trips proposal's hook 4, 24
-- Nov 2026): a plate that is not a map but a half-page leaf a feature
-- draws itself, for a moment kind registered with `sheet`
-- (Core/JourneyRecap.lua's RegisterMoment, whose comment says how such a
-- moment is grouped and what it may tell). The registry of who draws each,
-- beside the margin's (UI/Journey/Margin.lua), and the sheet drawn in its
-- slot (Draw, called by DrawPlates where Plated is, UI/Journey/Caption.lua).
-- A sheet has no caption, no margin, no leaders and no whole map: it is
-- its own caption. The paper is a leaf (UI/Paper/Leaf.lua), whose header is
-- the drawer's toolkit; the pen marks are UI/Ink/Scribble.lua's, the small
-- drawings UI/Ink/Sketch.lua's.
--
-- ns.UI.JourneySheet.Register(kind, spec) declares one (the kind's moment
-- registered with `sheet = true` too; tests/kinds.lua asks for both):
--
--   draw    function(leaf, plate, slot, c): writes and draws the sheet on
--           `leaf`, laid in `slot` (444 by 240, turned, maybe lifted at a
--           corner) and begun: whatever it hands out of the leaf's pools is
--           shown, the rest hidden after. `plate` is Recap.Plates' (its
--           `sheet` the kind, its `moments` in time order); `c`:
--             moment   the sheet's own moment (its record in its field);
--                      its `errands`, where other kinds offered it any
--                      (RegisterMoment's `errand`): { errand, moment }
--                      each, in time order, the errand's `kind` the word
--                      the drawer reads it by
--             told     the other moments it tells (Recap.Told): the stays
--                      of the same visit, and its errands' moments
--             e        the piece the page shows; now; j the route
--             index    its place on the page, top to bottom
--             before   the plate above it (a heading counts on from it,
--                      Text.PlateHeading's `before`)
--             named    { [guid] = true } for everyone a margin strip on this
--                      page names (the caption's rule: not named twice)
--             Seed(...)  a seed string of its parts and the sheet's spot
--             ToPerson(guid)  opens their page (a name's click)
--             Heading  Text.PlateHeading(plate, now, before): the line, the
--                      zone alone, the day (as a plate's heading reads)
--           Stops for the pad are what draw gives the leaf (leaf:Name, or
--           leaf:Stop for a line with only a tooltip): A goes in among them
--           as among a plate's marks, A on one is its click.
--   label   function(m) → the ticklist's words for its row ("Errands, 38
--           min": short, no day or time, the time column has them)
--   new     optional function(parent) → its leaf (UI/Paper/Leaf.lua's
--           Leaf.New(parent, opts): its own stock, fold or edge); made once
--           a page. Without it, Leaf.New(parent)
--   tip     optional function(m, now) → the row's tooltip title, where the
--           label is not enough (the label without it)
--
-- Its right click (and the pad's Y) is the plate's menu as a sheet has it
-- (UI/Journey/CardSheet.lua's SheetGenerator): "Leave it out" and
-- "Choose what's on this page...". With the ticklist open, the mouse on it
-- lights its row and its frame (ChooseLightMap), and its row under the
-- mouse draws a pencil line under its heading (leaf:SetRing).
--
-- The module and its siblings: UI/Journey/Look.lua.

local addonName, ns = ...

local Text = ns.UI.JourneyText
local YourDiary = ns.UI.YourDiary

local sheetKinds = ns.Registry.New({
    what = "JourneySheet.Register(kind, { draw, label, new, tip })",
    key = "kind",
    check = function(_, spec) return type(spec.draw) == "function" and type(spec.label) == "function" end,
})
local KINDS = sheetKinds.specs

local Sheet = { KINDS = KINDS }
ns.UI.JourneySheet = Sheet
YourDiary.SHEETS = KINDS

function Sheet.Register(kind, spec)
    return sheetKinds:Add(kind, spec)
end

-- Takes a kind's drawer out again (a test's own kind). Its leaf stays on a
-- page already built, unused.
function Sheet.Remove(kind)
    sheetKinds:Remove(kind)
end

-- The mouse on a sheet: with the ticklist open its row and its frame lit,
-- as a frame under the mouse lights them (UI/Journey/Choose.lua).
local function Hover(leaf, over)
    local page = YourDiary.page
    if page and page.choosing and YourDiary.ChooseLightMap then
        YourDiary.ChooseLightMap(over and leaf.index or nil)
    end
end

-- The leaf for `kind` on the page, made once (its spec's `new`, else a
-- plain leaf).
local function LeafOf(kind)
    local page = YourDiary.page
    page.leaves = page.leaves or {}
    local leaf = page.leaves[kind]
    if not leaf then
        local spec = KINDS[kind]
        leaf = spec and spec.new and spec.new(page.right) or ns.UI.Leaf.New(page.right)
        page.leaves[kind] = leaf
    end
    return leaf
end

-- Sheet plate `p`, the page's `i`th, drawn in `slot` (ctx as Plated's: the
-- piece `e`, the plate `before` it, the journey `j`, and `named`). Kept as
-- page.sheetAt[i]. Returns the leaf.
function Sheet.Draw(i, p, slot, ctx)
    local page = YourDiary.page
    local kind = p.sheet
    local leaf = LeafOf(kind)
    leaf:SetSlot(slot)
    leaf:Begin()
    leaf.plan, leaf.index, leaf.kind, leaf.entry = p, i, kind, ctx.e
    leaf.onHover = Hover
    leaf.onRight = function(l) YourDiary.CardSheet.SheetMenu(l) end
    local moment, told = nil, {}
    for _, m in ipairs(p.moments) do
        if not moment and m.kind == kind then moment = m else told[#told + 1] = m end
    end
    local spec = KINDS[kind]
    if spec then
        spec.draw(leaf, p, slot, {
            moment = moment, told = told, e = ctx.e, now = page.now, j = ctx.j, index = i, before = ctx.before,
            named = ctx.named or {}, ToPerson = YourDiary.ToPerson,
            Seed = function(...)
                local parts, n = { ... }, select("#", ...)
                parts[n + 1], parts[n + 2] = kind, p.mapID or 0
                return table.concat(parts, ":")
            end,
            Heading = function() return Text.PlateHeading(p, page.now, ctx.before) end,
        })
    end
    leaf:Finish()
    leaf:Show()
    page.sheetAt = page.sheetAt or {}
    page.sheetAt[i] = leaf
    return leaf
end

-- After a drawing of the right page: every leaf not drawn on it hidden.
function Sheet.Settle()
    local page = YourDiary.page
    local drawn = {}
    for _, leaf in pairs(page.sheetAt or {}) do drawn[leaf] = true end
    for _, leaf in pairs(page.leaves or {}) do
        if not drawn[leaf] then
            leaf:SetRing(nil)
            leaf:Hide()
        end
    end
end

-- The leaf drawn as the page's `i`th plate, nil where that is no sheet.
function Sheet.At(i)
    local page = YourDiary.page
    return page and page.sheetAt and page.sheetAt[i] or nil
end

YourDiary.Sheet, YourDiary.SheetAt = Sheet, Sheet.At
