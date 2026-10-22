-- The party's business cards on the table spread (step 4): everyone who was
-- on the run, the user too, has a card lying beside the map, over its edge
-- a little and over everything on the table (the sheet and its strips).
-- A card is chosen by the holder's race, which is never printed: it is told
-- by its look (STYLES). A gnome's is a Brightgear Engineering ID badge
-- (the user's art, Art/Cards/gnome.tga), its photo, class icon and three
-- printed fields filled in; a dwarf's a mason's slab of stone and gold (the user's art, Art/Cards/
-- dwarf.tga), its name and class set in its two parchment slots; a night
-- elf's a parchment card in a carved wooden frame grown over with ivy (the
-- user's art, Art/Cards/nightelf.tga), its name and class written by its
-- holder's own hand on its two ruled lines; a Skyborne's a slab of pale
-- marble in silver, a blue gem at its corner, wind carved over its top and
-- a bundle of feathers at its foot (the user's art, Art/Cards/
-- skyborne.tga), written on the same way; a human's a stone wall in
-- Stormwind with the Alliance's banner and a stained-glass window (the
-- user's art, Art/Cards/human.tga), its name and class centred on its gold
-- rules; anyone else's, and anyone whose race was never seen, a jobbing
-- printer's plain card. Each design is a table of named slots (stock,
-- ornament, emblem, stain) where the user's art drops in (`art`); a slot
-- without art is drawn in code, the same size and place, so the art
-- changes no layout.
--
-- On a card, printed or written by its holder: the name, the class's
-- icon and the level and class ("Level 22 Shaman"), and what belongs to
-- the design (a gnome's employee number and photo); nothing of the run is
-- printed. Below them, in the room the card leaves, the
-- user may have jotted a note about them by hand (JOTS): handwriting
-- baked offline and drawn with the diary's pen (UI/Ink/Hand.lua), in its
-- brown-black ink on every stock, rising a little off the card's own
-- line and never quite on its margin, as a note written on a card held
-- in the hand; a dwarf's stone takes no ink, so its note is written on a
-- slip of paper tucked under the card's foot (CardSlip), and so is a
-- gnome's, its badge full of print. A note about an
-- item has the item's tooltip over it. A
-- run's facts with no baked note (Core/DungeonRun.lua's Person) write
-- nothing. Someone not in the diary can be added from their card, each
-- design its own way (a gnome's badge stamped, a dwarf's wax seal pressed
-- over its corner bracket, a leaf pressed on a night elf's, a Skyborne's
-- gem kindled, a human's seal hung on its banner's rod, a plain card's box
-- ticked); someone in it shows it done,
-- and their card opens their page. Never the user's own.
--
-- The cards rest in a small stack of their own by the map's bottom-left
-- corner, a little over the paper's edge (the user, 17 Oct: the scattered
-- cards were confusing and cluttered; 20 Oct: the cards on their own): small,
-- each a little off the one over it and a little fanned, the page's own
-- person's on top, its name readable. Under the mouse they rise a little.
-- A click on the stack fans them out (STACK, FAN): each lifted off it,
-- then growing along a gentle arc to its place in a column rising from
-- where the stack lies, each turned a little more with the clock than the
-- one under it, so the column bends to the right as it rises (the macOS
-- Dock's fan), one after the other, eased out. Fanned, they are much
-- bigger than in the stack, over the map and its strips, and still
-- whole on the screen: where the column does not fit, each card lies over
-- the foot of the one above it, its name and level and class showing (a
-- shingled column), and a card lifts over the others under the mouse.
-- A click on the stack again, beside the cards, or Escape gathers them
-- the way they came; the spread put away gathers them at once. Where
-- the strips lie keeps off the stack (view.stack, worked out before the
-- strips are laid), never off the fan, which comes and goes over them.
-- A raid's: the five cards most worth seeing and a deck of the rest under
-- a paper band ("and 34 more") at the bottom of the stack, which rises
-- with them to the top of the column; a click on it spreads the rest over
-- the map and a click beside gathers them again. The same for the same run
-- every time. Nothing of it is saved: the fan is open only while it is.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local DungeonPage = ns.UI.DungeonPage
local Surface = ns.UI.Surface

-- A card: `w` by `h` px as it is drawn (smaller in the stack, bigger
-- fanned: STACK, FAN). Its cut edge in ink at `cut`; lifted under the
-- mouse `raise` levels up. Its shadows are cast by the table's lamp from
-- how high it lies (UI/Dungeon/Heights.lua): on what is under it, and on
-- the world.
-- The note jotted on it (`jot`): written at an x-height of `size` px (the
-- hand's lines `lead` x-heights apart, Hand.HAND), smaller only where it
-- would not fit the body; rising `turn` degrees (seeded between the two)
-- off the card's line; begun up to `drift` px right of the design's own
-- place (STYLES' `jot`), each line after the first moved up to `indent`
-- px either way; in `ink` at `alpha`, `room` px kept clear of the card's
-- right edge and its foot.
local CARD = { w = 178, h = 100, cut = 0.32, raise = 200, room = 4,
    jot = { size = 9, turn = { 1.5, 4 }, drift = 5, indent = 6, ink = Style.INK_STRONG, alpha = 0.9, room = 8 } }
-- A raid's: the `most` cards worth seeing in the stack, the rest a deck
-- of `backs` card backs `offset` px apart under a paper band `band` px
-- tall, `inset` px down from the deck's top; spread, a grid over the map,
-- `gap` px between, at most `fill` of it.
local DECK = { most = 5, backs = 3, offset = 2.5, band = 18, inset = 17, gap = 8, fill = 0.9 }
-- The stack: the cards at `scale` of their size, the page's own
-- person's on top, turned `turn` degrees (with the clock, as the fan
-- bends); each card under it turned
-- FAN.turn more with the clock (as it will be fanned) about the top
-- card's bottom-right corner, so the stack splays a little up and to the
-- left, away from the map, and set `shift` px further left and `rise` px
-- higher, so it reads as several cards laid flat too. Its right side
-- `overlap` px onto the paper (less than any mark lies in from the edge,
-- Sheet.lua's LABEL.inside), its foot `up` px above the paper's
-- bottom-left corner (clear of the deaths tallied there, Print.lua's
-- DEATH) with `tail` px more under the top card's foot for its slip,
-- `edge` px inside the screen; the strips keep `keep` px off it. Under
-- the mouse the cards rise `hover` px over `hoverTime` s; the click is
-- taken `pad` px round them.
local STACK = { scale = 0.8, turn = -1.5, shift = 2.5, rise = 1.5, overlap = 12, up = 8, tail = 14, edge = 12, keep = 6,
    hover = 5, hoverTime = 0.12, pad = 4 }
-- Fanned (a click on the stack): a column rising from where the stack
-- lies, the front card lowest (its foot `lift` px over the top card's
-- foot in the stack), each next one up `gap` px apart and turned `turn`
-- degrees more with the clock, so the column bends to the right as it rises; at `scale` times the cards' size
-- where the screen has room, all of it `edge` px inside the screen. Where
-- it does not fit, each card lies over the foot of the one above it, so
-- that one shows at least `show` of its height (its name, its level and
-- class); still too tall, smaller, down to `least`; then shingled closer,
-- down to `name` (its name still shows), and only then smaller still. A
-- raid's deck shows its top `deck` (its band) over the top card.
-- Each card goes over `time` s, eased out (a cubic), `stagger` s after
-- the one before (the front one first out, the top one first back):
-- lifted off the stack (STACK.hover) at its resting size over the first
-- `draw` of the way, then growing to its place along a gentle arc, its
-- sideways part lagging (to the power `bend`). Escape closes the fan
-- first (its catcher, `name`, stands in the spread's place in
-- UISpecialFrames: UI/Dungeon/Spread.lua).
local FAN = { scale = 1.8, least = 1.45, gap = 8, lift = 8, turn = 1.4, show = 0.8, name = 0.6, deck = 0.42,
    edge = 12, time = 0.26, stagger = 0.035, draw = 0.2, bend = 2, catcher = "SocialDiaryCardFan" }
DungeonPage.CARD, DungeonPage.DECK, DungeonPage.STACK, DungeonPage.FAN = CARD, DECK, STACK, FAN

-- The designs. Every colour is the card's own; `art` names the slots'
-- files, empty until the art comes: `stock` the card, `ornament` its
-- rules or band, `emblem` its cog or marks, `stain` what was spilt on it.
-- `jot` is where a note on it begins: the left end of its first baseline
-- (x, y from the card's top left), under the level and class; each line
-- after the first begun `after` px further right (a gnome's clear of its
-- cog).
local BRASS = Style.BRASS_MID or { 0.78, 0.6, 0.3 }
local STYLES = {
    -- Gnomish: the user's art (Art/Cards/gnome.tga, Dev/card_art.py --key
    -- light: its rounded corners keyed out of a white backdrop), a
    -- Brightgear Engineering ID badge: a teal header band with the
    -- company's name and a gold gear-and-lightning medallion, a pink stripe
    -- under it, a gold-framed photo slot on the left, three printed fields
    -- on teal rules (NAME, CLASS, EMPLOYEE ID), a holographic disc, a gold
    -- chip and a barcode. Places are fractions of the card, as the others'.
    -- Filled in as the badge's own machine prints, in Friz: the name in
    -- capitals (`name`), the level and class and the employee number
    -- (Words.Serial) as printed (`print`), each sitting on its rule
    -- (`fields`: x0, x1 and the y of its top; its middle `sit` of its size
    -- above it, begun `inset` px in), fitted to the rule down to `least`,
    -- then cut short. The photo (`photo`, the grey inside the gold frame)
    -- is their face: live where they are about (SetPortraitTexture), else
    -- their race's portrait (Style.RaceFace), cropped like a photo
    -- (`crop`), else the badge's blank head and shoulders (`blank`). Their
    -- class's icon in the holographic disc (`disc`: x, y, r px; the icon
    -- `icon` px, the disc's rim showing round it). No room for ink between
    -- the printed fields: a note is on a slip under its foot (`slip`), as a
    -- dwarf's. `keep`: the art the printing keeps off. Added: the badge
    -- validated, a stamp inked over the header's right end (`stamp`: a cog
    -- of `teeth` round a tick, in a stamp pad's red, turned up to `turn`
    -- degrees, seeded); before, a ring of dots printed there, where it
    -- will be stamped.
    gnome = {
        stock = { 0.93, 0.92, 0.86 }, ink = { 0.12, 0.14, 0.16 },
        art = { stock = "Interface\\AddOns\\" .. addonName .. "\\Art\\Cards\\gnome" },
        coords = { 0, 0.8887, 0, 1 },
        fields = { name = { 0.3814, 0.9477, 0.398 }, who = { 0.3814, 0.8036, 0.5918 }, id = { 0.3814, 0.7022, 0.7857 } },
        name = { font = Style.FRIZ, size = 10, least = 8, colour = "ink", alpha = 0.95, sit = 0.32 },
        print = { font = Style.FRIZ, size = 9.5, least = 8, alpha = 0.92, sit = 0.32 }, inset = 2,
        photo = { 0.0593, 0.2834, 0.3195, 0.8231 }, crop = { 0.2, 0.8, 0.15, 0.85 }, blank = { 0.68, 0.67, 0.63 },
        disc = { x = 0.888, y = 0.528, r = 9.6, icon = 16 },
        keep = { { 0, 0, 1, 0.197 }, { 0.0497, 0.2630, 0.3278, 0.8390 }, { 0.3827, 0.254, 0.4675, 0.2925 },
            { 0.3820, 0.4456, 0.4726, 0.4841 }, { 0.3827, 0.6395, 0.5733, 0.678 }, { 0.834, 0.43, 0.944, 0.626 },
            { 0.7883, 0.6497, 0.9273, 0.8039 }, { 0.3814, 0.8549, 0.9471, 0.9456 } },
        stamp = { x = 0.905, y = 0.095, r = 6.5, teeth = 10, turn = 14, ink = { 0.66, 0.11, 0.13 }, alpha = 0.88,
            dots = 14, dot = { 0.93, 0.92, 0.86, 0.75 } },
        slip = true,
    },
    -- Dwarvish: the user's art (Art/Cards/dwarf.tga, Dev/card_art.py): a
    -- slab of grey stone blocks, gold brackets at its corners, a gold rail,
    -- a medallion with crossed hammers at the top, a knotwork band at the
    -- foot, and two parchment slots in gold frames. Every place on it is a
    -- fraction of the card (x of its width from the left, y of its height
    -- from the top), as the art's are: `slots` the slots' paper (x0, y0,
    -- x1, y1), the name in the long one and the level and class in the
    -- short one, both in ink, fitted and centred; the class's icon on the
    -- stone left of the short one (`icon`); `medallion` (x, y, r of the
    -- width) and `knot` the art the rest keeps off. The stone takes no ink:
    -- a note is written on a slip tucked under its foot (`slip`, SLIP).
    -- Added: the diary's red wax seal pressed over the top right bracket
    -- (`seal`; a chalk ring there before, where it will go).
    dwarf = {
        stock = { 0.40, 0.41, 0.43 }, ink = Style.INK_STRONG,
        art = { stock = "Interface\\AddOns\\" .. addonName .. "\\Art\\Cards\\dwarf" },
        coords = { 0, 0.8916, 0, 1 },
        slots = { name = { 0.165, 0.360, 0.840, 0.515 }, who = { 0.315, 0.625, 0.690, 0.740 } },
        medallion = { 0.501, 0.178, 0.07 }, knot = { 0.25, 0.82, 0.75, 0.87 },
        name = { font = Style.MORPHEUS, size = 12, least = 8, colour = "ink", alpha = 0.92 },
        who = { font = Style.FRIZ, size = 9, least = 7, alpha = 0.85, inset = 3 }, inset = 5,
        icon = { x = 0.255, size = 12 },
        seal = { x = 0.925, y = 0.13, r = 10, wax = { 0.56, 0.09, 0.06 }, deep = { 0.34, 0.04, 0.02 },
            light = { 0.82, 0.32, 0.22 }, drops = 6, ring = 8, dashes = 9 },
        slip = true,
    },
    -- Night elven: the user's art (Art/Cards/nightelf.tga, Dev/card_art.py
    -- --opaque: it has no backdrop): warm parchment in a carved light-wood
    -- frame, a carved leaf in three corners, ivy with violet flowers up its
    -- right side and over its top, a few leaves at its foot on the left, and
    -- two ruled lines on the open parchment. Places are fractions of the
    -- card, as the dwarf's. Its holder wrote on the lines themselves: the
    -- name on the long one and the level and class on the short one
    -- (`lines`: x0, x1 and the y of each rule's top), in a hand (Neuton
    -- Italic, the diary's for what someone wrote) and as written, not in
    -- capitals, in their own violet-black ink, not the diary's; each
    -- sitting on its rule (its middle `sit` of its size above it), begun
    -- `inset` px in, fitted to the rule down to `least`, and past that run
    -- on beyond the rule's end, no further than `reach` (the parchment
    -- clear of the vines). No class icon: nothing on it is printed. A note
    -- is jotted on the open parchment above the name (`jot`: from x, its
    -- line's middle at y, as far right as `right` and as low as `foot`), on
    -- one line, its lines joined (`one`), as that room is wide and shallow,
    -- rising less than on other cards (`turn`, degrees) under the hanging
    -- leaves. `keep`: the art the writing keeps off, the vines and the
    -- carved corners (x0, y0, x1, y1). Added: a leaf pressed on the card in the top band,
    -- beside the carved corner (`leaf`); before, its outline pencilled
    -- there, where it will go.
    nightelf = {
        stock = { 0.91, 0.80, 0.62 }, ink = { 0.21, 0.12, 0.25 },
        art = { stock = "Interface\\AddOns\\" .. addonName .. "\\Art\\Cards\\nightelf" },
        coords = { 0, 0.8887, 0, 1 },
        lines = { name = { 0.103, 0.605, 0.531 }, who = { 0.103, 0.432, 0.753 } },
        name = { font = Style.NEUTON_ITALIC, size = 13, least = 10, colour = "ink", alpha = 0.92, caps = false,
            sit = 0.37, reach = 0.70 },
        who = { font = Style.NEUTON_ITALIC, size = 11, least = 9, alpha = 0.88, sit = 0.37, reach = 0.62 }, inset = 3,
        jot = { x = 0.06, y = 0.362, right = 0.68, foot = 0.43, turn = { 0.6, 1.6 }, drift = 2, one = true },
        keep = { { 0.22, 0, 1, 0.10 }, { 0.28, 0, 1, 0.17 }, { 0.39, 0, 1, 0.23 }, { 0.56, 0, 1, 0.26 },
            { 0.70, 0, 1, 1 }, { 0.64, 0.82, 1, 1 }, { 0, 0.82, 0.28, 1 }, { 0.14, 0, 0.19, 0.12 },
            { 0.02, 0.04, 0.10, 0.17 }, { 0.02, 0.83, 0.10, 0.96 }, { 0.90, 0.83, 0.98, 0.96 } },
        -- The leaf: its middle at x, y, `len` px from its stalk's joint to
        -- its tip, which points `turn` degrees up from the right; its
        -- outline one side of the midrib, from the notch to the tip (`edge`:
        -- along the midrib, out from it, in `len`s), each point moved out up
        -- to `wobble` (seeded); `stalk` its stalk (in `len`s). Pressed: in
        -- `body`, its rim in `rim`, its veins in `vein`, its shadow (right,
        -- down, alpha); to come: its outline in pencil (`pencil`).
        leaf = { x = 0.215, y = 0.17, len = 12, turn = 40, wobble = 0.08, stalk = 0.35,
            edge = { { 0, 0 }, { -0.12, 0.18 }, { -0.10, 0.34 }, { 0.04, 0.45 }, { 0.22, 0.48 }, { 0.42, 0.42 },
                { 0.62, 0.30 }, { 0.80, 0.16 }, { 1, 0 } },
            body = { 0.50, 0.50, 0.24, 0.94 }, rim = { 0.33, 0.32, 0.13, 0.8 }, vein = { 0.76, 0.72, 0.46, 0.75 },
            shadow = { 0.6, 0.9, 0.3 }, pencil = { colour = Style.GRAPHITE, alpha = 0.7, width = 0.8 } },
    },
    -- Skyborne: the user's art (Art/Cards/skyborne.tga, Dev/card_art.py
    -- --opaque): pale silver-white marble, faint blue-violet veins at its
    -- left edge, a thin silver frame with a blue stud in each corner, a
    -- faceted blue teardrop gem in a silver setting at the top left, wind
    -- swirls carved in silver over its top, a bundle of feathers tied with
    -- cord at the bottom right and a few small rocks before them, and two
    -- ruled lines as the night elf's. Written on as the night elf's (its
    -- `lines`, `name`, `who`, `inset`), in its holder's storm-grey ink, a
    -- cool slate dark enough to read on the pale marble. A note is jotted on
    -- the marble between the swirls and the name, on one line, begun clear
    -- of the gem's tail, kept nearly level and no higher than the swirls'
    -- low tails (`jot`'s `top`): that strip is shallow, so the hand comes
    -- out small (about 5 px high); `slip = true` writes it on a slip under
    -- the card's foot instead, as a dwarf's, at the hand's own size.
    -- `keep`: the art the writing keeps off, the gem, the swirls, the
    -- feathers and rocks, the veins and the studs (x0, y0, x1, y1).
    -- Added: the gem kindled (`gem`: its middle x, y; a soft light round
    -- its setting, `halo` faint discs out to `r` px, gathering toward it
    -- and never past the card's edge; its own light, `lit`, added to the
    -- painted gem; a glint, a small star, on its upper facet), laid over
    -- the art, never painting it out; before, a ring pencilled round it,
    -- where it will be lit (`ring`, rx, ry px).
    skyborne = {
        stock = { 0.90, 0.92, 0.94 }, ink = { 0.15, 0.19, 0.27 },
        art = { stock = "Interface\\AddOns\\" .. addonName .. "\\Art\\Cards\\skyborne" },
        coords = { 0, 0.8887, 0, 1 },
        lines = { name = { 0.103, 0.599, 0.531 }, who = { 0.103, 0.431, 0.753 } },
        name = { font = Style.NEUTON_ITALIC, size = 13, least = 10, colour = "ink", alpha = 0.94, caps = false,
            sit = 0.37, reach = 0.76 },
        who = { font = Style.NEUTON_ITALIC, size = 11, least = 9, alpha = 0.9, sit = 0.37, reach = 0.68 }, inset = 3,
        jot = { x = 0.175, y = 0.375, top = 0.288, right = 0.83, foot = 0.422, turn = { 0.1, 0.6 }, drift = 2, one = true },
        keep = { { 0.02, 0.02, 0.10, 0.34 }, { 0.10, 0, 0.17, 0.31 }, { 0.17, 0, 0.42, 0.29 }, { 0.42, 0, 0.59, 0.24 },
            { 0.59, 0, 0.75, 0.29 }, { 0.75, 0, 0.85, 0.26 }, { 0.85, 0, 1, 0.29 },
            { 0.87, 0.40, 1, 1 }, { 0.84, 0.43, 1, 1 }, { 0.815, 0.46, 1, 1 }, { 0.79, 0.53, 1, 1 }, { 0.76, 0.59, 1, 1 },
            { 0.73, 0.64, 1, 1 }, { 0.70, 0.73, 1, 1 }, { 0.62, 0.80, 1, 1 }, { 0.53, 0.87, 1, 1 }, { 0.49, 0.80, 0.70, 1 },
            { 0.04, 0.56, 0.07, 0.62 }, { 0.04, 0.81, 0.12, 0.95 },
            { 0, 0, 0.05, 0.07 }, { 0.95, 0, 1, 0.07 }, { 0, 0.93, 0.05, 1 }, { 0.95, 0.93, 1, 1 } },
        gem = { x = 0.085, y = 0.16, ring = { 10, 13 }, r = 14.5, halo = 7, light = { 0.42, 0.70, 0.96 }, alpha = 0.075,
            lit = { 0.25, 0.50, 0.75, 0.30, r = 5.5 }, glint = { x = -2.6, y = -4.2, len = { 6.5, 4.5, 2.2 },
                colour = { 0.97, 0.99, 1.0 } },
            pencil = { colour = Style.GRAPHITE, alpha = 0.6, width = 0.8, dashes = 12 } },
    },
    -- Human: the user's art (Art/Cards/human.tga, Dev/card_art.py
    -- --opaque): a pale cream stone wall, a royal-blue Alliance banner with
    -- a gold lion hanging from an iron rod at the top left, a tall stained-
    -- glass window with a sun at the right, its light falling across the
    -- wall in soft rays, a steel shield with a sword, a hammer and a gold
    -- sun at the foot, a raised stone block at the lower left, and two gold
    -- rules, centred. Written on as the night elf's, but centred on the
    -- rules (`centre`; over their ends by up to `overhang` px before made
    -- smaller, as a name over a plaque's rule; `reach` the wall either side
    -- clear of the banner and the window, x0 and x1): a herald's card, so the name in the house's
    -- Morpheus capitals, the level and class in Neuton Italic under it, in
    -- a deep blue-black ink, the banner's. A note is jotted on the open wall
    -- above the name, between the banner and the window, at the hand's own
    -- size, in two lines a little closer than the hand's (`lead`), the
    -- long first one high, where no ray falls. `keep`: the art the writing
    -- keeps off; `rays`: the light, which a note keeps off too. Added: the
    -- diary's seal in the Alliance's colours, blue wax and gold, hung on a
    -- blue ribbon from the banner's rod beside the banner (`pendant`: its
    -- middle x, y, r px; `knot` where the ribbon is tied); before, a ring
    -- pencilled where it will hang.
    human = {
        stock = { 0.88, 0.86, 0.80 }, ink = { 0.10, 0.13, 0.25 },
        art = { stock = "Interface\\AddOns\\" .. addonName .. "\\Art\\Cards\\human" },
        coords = { 0, 0.8887, 0, 1 },
        lines = { name = { 0.243, 0.758, 0.527 }, who = { 0.3425, 0.657, 0.746 } }, centre = true,
        name = { font = Style.MORPHEUS, size = 12, least = 8, colour = "ink", alpha = 0.94, sit = 0.30,
            reach = { 0.235, 0.815 } },
        who = { font = Style.NEUTON_ITALIC, size = 11, least = 9, alpha = 0.9, sit = 0.37, reach = { 0.19, 0.81 } },
        inset = 3, overhang = 6,
        jot = { x = 0.302, y = 0.183, top = 0.045, right = 0.84, foot = 0.42, lead = 2.0, turn = { 0.8, 1.8 }, drift = 2 },
        keep = { { 0, 0, 0.225, 0.62 }, { 0.86, 0, 1, 0.12 }, { 0.84, 0.12, 1, 0.25 }, { 0.825, 0.25, 1, 0.76 },
            { 0.84, 0.74, 0.93, 0.92 }, { 0.395, 0.77, 0.62, 1 }, { 0.045, 0.67, 0.18, 0.93 } },
        rays = { { 0.74, 0.22, 0.83, 0.40 }, { 0.71, 0.40, 0.83, 0.55 }, { 0.72, 0.55, 0.83, 0.76 } },
        pendant = { x = 0.255, y = 0.165, r = 5.2, knot = { 0.207, 0.03 }, ribbon = { 0.17, 0.27, 0.58 },
            wax = { 0.15, 0.24, 0.56 }, deep = { 0.07, 0.11, 0.30 }, gold = { 0.86, 0.68, 0.26 },
            light = { 0.48, 0.60, 0.92 }, drops = 5, dashes = 9,
            pencil = { colour = Style.GRAPHITE, alpha = 0.7, width = 0.8 } },
    },
    -- Undead: the user's art (Art/Cards/undead.tga, Dev/card_art.py
    -- --opaque), the human's card ruined: a dark cracked stone wall with
    -- drips, a torn purple Forsaken banner with a banshee on a rusty rod,
    -- a broken window glowing fel-green, dead roots over the top right and
    -- bricks bared beside the window, a rusty shield with a sword and a
    -- hammer at the foot, rubble, dead vines at the left, and two brass
    -- rules with knobbed ends, centred. Written on as the human's, but the
    -- wall is dark: in bone (`ink`), the name in Morpheus capitals and the
    -- level and class in Neuton Italic, each with a dark stroke under it
    -- (`shade`) where the lit middle of the wall is lightest. The open
    -- wall left for a note is narrow and cracked, so a note is on a slip
    -- under its foot (`slip`), as a dwarf's, in the diary's ink at the
    -- hand's own size. `keep`: the art the writing keeps off; `wall`: the
    -- luminance measured under the name and the class (the tests' contrast
    -- check). Added: the diary's seal in purple wax, ruined, hung on a
    -- frayed hemp cord from the rod beside the banner (`pendant`, as the
    -- human's; light enough to stand off the dark wall; its ring in chalk
    -- before).
    undead = {
        stock = { 0.32, 0.31, 0.33 }, ink = { 0.94, 0.92, 0.84 },
        art = { stock = "Interface\\AddOns\\" .. addonName .. "\\Art\\Cards\\undead" },
        coords = { 0, 0.8887, 0, 1 },
        lines = { name = { 0.243, 0.756, 0.529 }, who = { 0.343, 0.657, 0.745 } }, centre = true,
        name = { font = Style.MORPHEUS, size = 12, least = 8, colour = "ink", alpha = 1, sit = 0.30,
            reach = { 0.205, 0.745 }, shade = { 0.8, -0.8, 0.04, 0.03, 0.05, 0.9 } },
        who = { font = Style.NEUTON_ITALIC, size = 11, least = 9, alpha = 1, sit = 0.37, reach = { 0.205, 0.745 },
            shade = { 0.8, -0.8, 0.04, 0.03, 0.05, 0.9 } },
        inset = 3, overhang = 6,
        slip = true,
        keep = { { 0, 0, 0.195, 0.60 }, { 0.01, 0.025, 0.225, 0.07 }, { 0.195, 0, 0.66, 0.09 },
            { 0.585, 0.09, 0.67, 0.21 }, { 0.62, 0, 0.86, 0.16 }, { 0.62, 0.16, 0.83, 0.40 }, { 0.745, 0.40, 0.83, 0.72 },
            { 0.815, 0, 1, 0.75 }, { 0.30, 0.78, 0.63, 1 }, { 0.83, 0.74, 1, 1 }, { 0, 0.55, 0.20, 1 }, { 0, 0.91, 1, 1 } },
        wall = { name = 0.172, who = 0.103 },
        pendant = { x = 0.255, y = 0.18, r = 5.2, knot = { 0.218, 0.046 }, ribbon = { 0.56, 0.47, 0.36 },
            wax = { 0.48, 0.23, 0.56 }, deep = { 0.20, 0.07, 0.24 }, gold = { 0.86, 0.82, 0.70 },
            light = { 0.74, 0.54, 0.80 }, drops = 6, dashes = 9, chalk = true, frayed = true, crack = true },
    },
    -- Anyone else: a jobbing printer's card. Cream laid stock, a single
    -- rule, no ornament. Added: a small box under the rule, ticked.
    plain = {
        stock = { 0.94, 0.90, 0.80 }, ink = Style.INK, laid = { step = 4, alpha = 0.035 },
        name = { font = Style.MORPHEUS, size = 14, colour = "ink" }, who = "ink", box = 10,
        jot = { x = 14, y = 58 },
        art = {},
    },
}
DungeonPage.STYLES = STYLES
-- Races with a design of their own (UnitRace's file name); else `plain`.
local RACES = { Gnome = "gnome", Dwarf = "dwarf", NightElf = "nightelf", Skyborne = "skyborne", Human = "human",
    Scourge = "undead" }

-- The design for a race.
function DungeonPage.CardStyle(race)
    return RACES[race or ""] or "plain"
end

-- The notes jotted on cards, by the kind of the run's fact they tell
-- (Core/DungeonRun.lua's Person): the baked note's key (UI/Ink/
-- HandData.lua). A kind not here, or whose note was never baked, writes
-- nothing. Only `snagged` is baked so far ("snagged an item / from me").
local JOTS = { snagged = "snagged" }
DungeonPage.JOTS = JOTS

-- What is jotted on `p`'s card: the first of their facts with a baked
-- note, and that note's key; nil for none. One note a card: the body
-- holds two lines of the hand.
function DungeonPage.CardJot(p)
    for _, f in ipairs(p.facts or {}) do
        local key = JOTS[f.kind]
        if ns.UI.Hand.Note(key) then return f, key end
    end
    return nil
end

-- A note's slip, on a design that takes no ink (STYLES' `slip`): a strip
-- of notebook paper tucked under the card's foot, `under` px of it under
-- the card. The note on one line (its lines joined `gap` x-heights apart)
-- where that is at least `least` px high, else its lines one under the
-- other; `pad` px of paper either side of the ink, `top` above it and
-- `foot` under it; at most `most` px wide, set off the card's middle by
-- up to `shift` px and turned up to `turn` degrees (seeded). In `paper`,
-- a faint `rule` under the writing; its shadows from its height (UI/
-- Dungeon/Heights.lua's HEIGHT.slip), lit as the card is.
local SLIP = { under = 9, least = 7, gap = 0.55, pad = 6, top = 3, foot = 4, most = 160, shift = 7, turn = 1.6,
    paper = { 0.95, 0.91, 0.81 }, rule = { 0.17, 0.23, 0.47, 0.22 } }
DungeonPage.SLIP = SLIP

-- The slip under `p`'s card, or nil (no note, or a design with ink room):
-- { fact, key, note, size, lead, indent, cx, cy, w, h, turn (radians),
-- x, y (its writing's first baseline's left end), tail (how far it shows
-- past the card's foot) }, on the card from its top left. The same every
-- time: a spread deck's rows count it with its card (CardTail).
function DungeonPage.CardSlip(p)
    local style = STYLES[DungeonPage.CardStyle(p.race)]
    if not style.slip then return nil end
    local fact, key = DungeonPage.CardJot(p)
    local note = ns.UI.Hand.Note(key)
    if not note then return nil end
    local room = SLIP.most - 2 * SLIP.pad
    local lines = note.lines
    local along, up, down = 0, 0, 0
    for i, line in ipairs(lines) do
        along = along + line.w + (i > 1 and SLIP.gap or 0)
        up, down = math.max(up, line.up), math.max(down, line.down)
    end
    local size = math.min(CARD.jot.size, room / along)
    local lead, indent, w, h, top = 0, {}, nil, nil, nil
    if size >= SLIP.least or #lines == 1 then
        local x = 0
        for i, line in ipairs(lines) do
            indent[i] = x * size
            x = x + line.w + SLIP.gap
        end
        w, h, top = along * size, (up + down) * size, up * size
    else
        local widest = 0
        for i, line in ipairs(lines) do
            widest = math.max(widest, line.w)
            indent[i] = 0
        end
        size = math.min(CARD.jot.size, room / widest)
        lead = ns.UI.Hand.HAND.lead
        w, h, top = ns.UI.Hand.Measure(note, size, lead, indent)
    end
    local U = ns.UI.Pen.Random(Surface.Seed(p.guid .. ":slip"))
    local turn = math.rad((2 * U() - 1) * SLIP.turn)
    local sw, sh = w + 2 * SLIP.pad, SLIP.under + SLIP.top + h + SLIP.foot
    local cx, cy = CARD.w / 2 + (2 * U() - 1) * SLIP.shift, CARD.h - SLIP.under + sh / 2
    local c, sn = math.cos(turn), math.sin(turn)
    local x, y = Surface.Turned(cx, cy, -sw / 2 + SLIP.pad, -sh / 2 + SLIP.under + SLIP.top + top, c, sn)
    local low = -math.huge
    for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        local _, qy = Surface.Turned(cx, cy, q[1] * sw / 2, q[2] * sh / 2, c, sn)
        low = math.max(low, qy)
    end
    return { fact = fact, key = key, note = note, size = size, lead = lead, indent = indent, cx = cx, cy = cy,
        w = sw, h = sh, turn = turn, x = x, y = y, tail = math.max(0, low - CARD.h) }
end

-- How far `p`'s card reaches past its foot (its slip), for a spread deck's rows.
function DungeonPage.CardTail(p)
    local slip = p and DungeonPage.CardSlip(p)
    return slip and slip.tail or 0
end

--------------------------------------------------------------------------
-- Who is on the run
--------------------------------------------------------------------------

-- The run's people as cards show them, in the order they lie, front first:
-- the page's own person, the user, the diary's people, then strangers
-- (those with more to say first). Each { guid, first, surname, race, class
-- (its name), classToken, level, sex, isMe, inDiary, facts }.
function DungeonPage.Party(visit, page)
    local me = visit.me or ns.ownGUID
    local list, seen = {}, {}
    local function Add(guid, m)
        if not guid or seen[guid] then return end
        seen[guid] = true
        local record = ns.Characters.Get(guid) or {}
        local first, surname = ns.Characters.Name(guid)
        local p = { guid = guid, first = first or m.first, surname = surname or m.surname, race = record.race,
            classToken = record.class or m.class, level = record.level, isMe = guid == me,
            inDiary = guid ~= me and ns.Diary.IsDiary(guid) or false, sex = record.sex }
        if p.isMe then
            local _, race = UnitRace("player")
            local _, class = UnitClass("player")
            p.race, p.classToken = race or p.race, class or p.classToken
            p.level = UnitLevel("player") or p.level
            p.sex = UnitSex("player") or p.sex
            p.first = p.first or UnitName("player")
        end
        p.class = p.classToken and ns.UI.Format.ClassName({ class = p.classToken, sex = record.sex }) or nil
        p.facts, p.visit = ns.DungeonRun.Person(visit, guid), visit
        list[#list + 1] = p
    end
    for _, m in ipairs(visit.members or {}) do Add(m.guid, m) end
    Add(me, {})
    local function Rank(p)
        if p.guid == page then return 0 end
        if p.isMe then return 1 end
        if p.inDiary then return 2 end
        return 3
    end
    table.sort(list, function(a, b)
        local ra, rb = Rank(a), Rank(b)
        if ra ~= rb then return ra < rb end
        if #a.facts ~= #b.facts then return #a.facts > #b.facts end
        return (a.first or "") < (b.first or "")
    end)
    return list
end

--------------------------------------------------------------------------
-- A card
--------------------------------------------------------------------------

-- A diary person's card opens their page: the run put away first (its
-- rustle), as the page's own person's would not close it.
local function ToPerson(guid)
    if not guid then return end
    DungeonPage.Close()
    ns.UI.YourDiary.ToPerson(guid)
end

-- A card on `table` (a frame whose top left is the sheet's middle: a card
-- laid at x, y lies x, y from it on the screen, y down).
local function NewCard(table_)
    local card = CreateFrame("Button", nil, table_)
    card:SetSize(CARD.w, CARD.h)
    card.table = table_
    local plane = Surface.New(card)
    local Place, Quad = plane.Place, plane.Quad
    -- Whether its corners can move (an uneven cut, a torn stub's teeth),
    -- and a measure for fitting its name.
    local probe = card:CreateTexture(nil, "BACKGROUND")
    card.canBend = probe.SetVertexOffset ~= nil
    probe:Hide()
    card.measure = card:CreateFontString(nil, "OVERLAY")
    card.measure:Hide()

    -- Textures and writing, handed out per drawing.
    card.textures = ns.UI.Pool.New(function()
        local t = card:CreateTexture(nil, "ARTWORK")
        if t.SetSnapToPixelGrid then
            t:SetSnapToPixelGrid(false)
            t:SetTexelSnappingBias(0)
        end
        return t
    end)
    card.texts = ns.UI.Pool.New(function() return card:CreateFontString(nil, "OVERLAY") end)
    -- Its shadow on the world: textures on the sheet's ground layer, under
    -- the sheet (UI/Dungeon/Sheet.lua's view.ground, the table's `ground`),
    -- so only what falls off the sheet shows; on a frame of their own there
    -- that lies where the card lies and grows with it (`groundFrame`,
    -- scaled as the card is), placed on it through a plane turned as the
    -- card's is, from how high it lies (card.height: in the stack or
    -- fanned).
    card.groundFrame = CreateFrame("Frame", nil, table_.ground)
    card.groundFrame:SetSize(1, 1)
    card.groundFrame:SetPoint("CENTER", card, "CENTER")
    card.groundFrame:Hide()
    card.groundPlane = Surface.New(card.groundFrame)
    card.grounds = ns.UI.Pool.New(function()
        local t = card.groundFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
        if t.SetSnapToPixelGrid then
            t:SetSnapToPixelGrid(false)
            t:SetTexelSnappingBias(0)
        end
        return t
    end)
    -- The item's tooltip over a note about an item, a button on the table.
    card.hovers = ns.UI.Pool.New(function()
        local hover = CreateFrame("Button", nil, table_)
        hover:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local shown = self.item and type(GameTooltip.SetHyperlink) == "function"
                and pcall(GameTooltip.SetHyperlink, GameTooltip, self.item)
            if not shown then GameTooltip:SetText(self.text or "") end
            GameTooltip:Show()
        end)
        hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return hover
    end)
    -- The way into the diary, a button over its piece of the card.
    card.add = CreateFrame("Button", nil, table_)
    Style.Tooltip(card.add, function(self) return self.offer and { { DungeonPage.Words.ADD } } or nil end)

    local W, H = CARD.w, CARD.h
    -- From the card's top left (x right, y down) to its middle's.
    local function M(x, y) return x - W / 2, y - H / 2 end

    local function Tex(layer, sublevel)
        local t = card.textures:Next()
        Surface.Unbend(t)
        t:SetTexture(nil)
        t:SetTexCoord(0, 1, 0, 1)
        t:SetVertexColor(1, 1, 1, 1)
        -- (A gem's light is added; the next use of its texture is not.)
        t:SetBlendMode("BLEND")
        t:SetDrawLayer(layer, sublevel)
        return t
    end
    function card:Rect(layer, sub, x, y, w, h, c, a, more)
        local t = Tex(layer, sub)
        t:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1)
        local lx, ly = M(x + w / 2, y + h / 2)
        Place(t, lx, ly, w, h, more)
        return t
    end
    function card:Disc(layer, sub, x, y, size, c, a)
        local t = Tex(layer, sub)
        Style.Disc(t, c[1], c[2], c[3], a or c[4] or 1)
        local lx, ly = M(x, y)
        Place(t, lx, ly, size, size)
        return t
    end
    -- A stroke from one point to another, `width` wide.
    function card:Line(layer, sub, x1, y1, x2, y2, width, c, a)
        local dx, dy = x2 - x1, y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 0.01 then return end
        local t = Tex(layer, sub)
        t:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1)
        local lx, ly = M((x1 + x2) / 2, (y1 + y2) / 2)
        Place(t, lx, ly, len + 0.4, width, math.atan2(-dy, dx))
        return t
    end
    -- Four points (a triangle gives one twice); nothing where corners
    -- cannot move.
    function card:Quad(layer, sub, c, a, x1, y1, x2, y2, x3, y3, x4, y4)
        local t = Tex(layer, sub)
        t:SetColorTexture(c[1], c[2], c[3], a or 1)
        local p = { M(x1, y1) }
        local q = { M(x2, y2) }
        local r = { M(x3, y3) }
        local s = { M(x4, y4) }
        if not Quad(t, p[1], p[2], q[1], q[2], r[1], r[2], s[1], s[2]) then
            t:Hide()
            card.textures.used = card.textures.used - 1
            return nil
        end
        return t
    end
    -- A piece of art (`file`, its part `coords` { l, r, t, b }) over the
    -- box x, y, w, h of the card, turned and bent with it; tinted c at
    -- alpha a (a shadow), else as drawn.
    function card:Art(layer, sub, file, coords, x, y, w, h, c, a)
        local t = Tex(layer, sub)
        -- (Or a function that sets it: a live portrait.)
        if type(file) == "function" then file(t) else t:SetTexture(file) end
        t:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        if c then t:SetVertexColor(c[1], c[2], c[3], a or 1) end
        local x1, y1 = M(x, y)
        local x2, y2 = M(x + w, y + h)
        if not Quad(t, x1, y1, x2, y1, x2, y2, x1, y2) then
            Place(t, (x1 + x2) / 2, (y1 + y2) / 2, w, h)
        end
        return t
    end
    -- An outline's shadow on the world (`grounds`, on its ground frame): the
    -- art `file` (its part `coords`), or a rectangle where none, over the
    -- box x, y, w, h of the card, turned with it and `more`, in colour c at
    -- alpha a.
    function card:Ground(file, coords, x, y, w, h, c, a, more)
        local t = card.grounds:Next()
        Surface.Unbend(t)
        t:SetVertexColor(1, 1, 1, 1)
        if file then
            t:SetTexture(file)
            t:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            t:SetVertexColor(c[1], c[2], c[3], a)
            local x1, y1 = M(x, y)
            local x2, y2 = M(x + w, y + h)
            if not more and card.groundPlane.Quad(t, x1, y1, x2, y1, x2, y2, x1, y2) then return t end
        else
            t:SetTexCoord(0, 1, 0, 1)
            t:SetColorTexture(c[1], c[2], c[3], a)
        end
        local lx, ly = M(x + w / 2, y + h / 2)
        card.groundPlane.Place(t, lx, ly, w, h, more)
        return t
    end
    -- The pen's quads (ns.UI.Pen's primitives, on the card) in colour c;
    -- where corners cannot move, each laid flat from the middle of its
    -- start to the middle of its end, as wide as it is on average.
    function card:Ink(layer, sub, prims, c)
        for _, q in ipairs(prims) do
            if not self:Quad(layer, sub, c, q.a, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4) then
                local w = (math.sqrt((q.x1 - q.x4) ^ 2 + (q.y1 - q.y4) ^ 2)
                    + math.sqrt((q.x2 - q.x3) ^ 2 + (q.y2 - q.y3) ^ 2)) / 2
                self:Line(layer, sub, (q.x1 + q.x4) / 2, (q.y1 + q.y4) / 2, (q.x2 + q.x3) / 2, (q.y2 + q.y3) / 2,
                    math.max(w, 0.6), c, q.a)
            end
        end
    end
    -- A ring of short strokes round x, y: `from` to `to` of a turn.
    function card:Ring(layer, sub, x, y, rx, ry, width, c, a, from, to)
        local n, px, py = 20, nil, nil
        for i = 0, n do
            local t = (from + (to - from) * i / n) * 2 * math.pi
            local qx, qy = x + rx * math.cos(t), y + ry * math.sin(t)
            if px then self:Line(layer, sub, px, py, qx, qy, width, c, a) end
            px, py = qx, qy
        end
    end
    -- A line of writing with its left (or `justify`) at x, its middle at y,
    -- in `font` at `size`, in colour c; in a box with the room its turn
    -- takes (the strips' TURNED); no wider than `room` where given (the
    -- client cuts it short with an ellipsis). `shade` { dx, dy, r, g, b, a }:
    -- a dark stroke under it, for light writing on a dark stock; else none.
    -- Returns it and its width.
    function card:Text(text, x, y, font, size, c, justify, more, room, shade)
        local fs = card.texts:Next()
        fs:SetFont(font, size, "")
        fs:SetText(text)
        fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
        if shade then
            fs:SetShadowOffset(shade[1], shade[2])
            fs:SetShadowColor(shade[3], shade[4], shade[5], shade[6])
        else
            fs:SetShadowOffset(0, 0)
        end
        fs:SetJustifyH(justify == "CENTER" and "CENTER" or "LEFT")
        fs:SetSize(0, 0)
        fs:SetWordWrap(false)
        local w = Surface.Width(fs) + 2
        if room and w > room then w = room end
        local h = math.max(fs:GetStringHeight() or 0, size)
        local left = justify == "RIGHT" and x - w or justify == "CENTER" and x - w / 2 or x
        local lx, ly = M(left + w / 2, y)
        local turn = (card.turn or 0) + (more or 0)
        Place(fs, lx, ly, w, h + w * math.abs(math.sin(turn)) + CARD.room, more)
        return fs, w, h
    end
    -- A box of the card (from its top left) on the table, square: where a
    -- button over that piece goes (in the table's own units, a card laid
    -- smaller in a spread deck too).
    function card:Box(x, y, w, h)
        local k = card.scaleK or 1
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        for _, p in ipairs({ { x, y }, { x + w, y }, { x + w, y + h }, { x, y + h } }) do
            local px, py = plane.Out(M(p[1], p[2]))
            x0, y0, x1, y1 = math.min(x0, px * k), math.min(y0, py * k), math.max(x1, px * k), math.max(y1, py * k)
        end
        return x0, y0, x1, y1
    end
    -- A button (the way in, a note's tooltip) over the box x, y, w, h of
    -- the card, on the table.
    function card:Over(button, x, y, w, h)
        local x0, y0, x1, y1 = card:Box(x, y, w, h)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", card.table, "TOPLEFT", x0, -y0)
        button:SetSize(x1 - x0, y1 - y0)
        return x0, y0, x1, y1
    end
    -- Put away with its buttons, which lie on the table beside it, and its
    -- shadow on the world.
    card:HookScript("OnHide", function()
        card.grounds:Begin()
        card.grounds:Finish()
        card.groundFrame:Hide()
        card.add:Hide()
        card.hovers:Begin()
        card.hovers:Finish()
    end)

    card:SetScript("OnClick", function(self)
        if self.person and self.person.inDiary and not self.person.isMe then ToPerson(self.person.guid) end
    end)
    -- Lifted from the pile under the mouse; laid back after.
    local function Level(level)
        card:SetFrameLevel(level)
        card.add:SetFrameLevel(level + 2)
        for i = 1, card.hovers.used do card.hovers[i]:SetFrameLevel(level + 3) end
    end
    card.SetLevel = function(_, level)
        card.level = level
        Level(level)
    end
    -- Picked up, its shadow on the world falls further out and paler
    -- (HEIGHT.lifted more: Ground).
    local function Lift(on)
        Level(on and (card.level or 0) + CARD.raise or card.level or 0)
        local was = card.lifted
        card.lifted = on or nil
        if was ~= card.lifted and card.person then DungeonPage.CardGround(card) end
    end
    card:SetScript("OnEnter", function() Lift(true) end)
    card:SetScript("OnLeave", function() Lift(false) end)
    card.add:HookScript("OnEnter", function() Lift(true) end)
    card.add:HookScript("OnLeave", function() Lift(false) end)
    card.add:SetScript("OnClick", function(self)
        local p = card.person
        if not (p and self.offer) then return end
        local entry, added = ns.Diary.Add(p.guid, { source = "dungeon" })
        if entry then
            if added then Style.PlaySound("write") end
            p.inDiary = true
            card:Draw()
        end
    end)

    card.plane, card.Lift = plane, Lift
    return card
end

--------------------------------------------------------------------------
-- Drawing a card
--------------------------------------------------------------------------

-- The colour a design names.
local function Ink(style, key) return style[key] or style.ink end

-- The name, fitted: as big as it can be up to the design's size in the
-- room it has (`fit`, else `room`; no smaller than its `least`, then cut
-- short at `room`), from x or centred on it (`justify`); its middle at y,
-- or, where the design writes it on a rule (`sit`), sitting on the rule at
-- y. In capitals but where the design writes it as written (`caps` false);
-- set wide where the design says (a hair's space between the letters).
local function Name(card, style, text, x, y, room, justify, fit)
    local N = style.name
    text = text or "?"
    if N.caps ~= false then text = text:upper() end
    if N.wide then
        -- A letter at a time, a letter being one UTF-8 character.
        text = (text:gsub("([%z\1-\127\194-\244][\128-\191]*)", "%1\226\128\138"):gsub("\226\128\138$", ""))
    end
    local size, m = N.size, card.measure
    -- The font first: the client refuses text on a string with none.
    m:SetFont(N.font, size, "")
    m:SetText(text)
    local least = N.least or 9
    fit = fit or room
    while Surface.Width(m) * size / N.size > fit and size > least do size = math.max(least, size - 1) end
    local c = Ink(style, N.colour)
    if N.alpha then c = { c[1], c[2], c[3], N.alpha } end
    if N.sit then y = y - N.sit * size end
    local fs, w = card:Text(text, x, y, N.font, size, c, justify, nil, room, N.shade)
    card.nameText, card.nameSize, card.nameWords = fs, size, text
    return fs, w
end

-- The class icon `size` px at x, y (its middle), where the client has it.
local function Icon(card, token, x, y, size)
    local t = card.textures:Next()
    Surface.Unbend(t)
    t:SetVertexColor(1, 1, 1, 1)
    t:SetDrawLayer("ARTWORK", 2)
    if Style.SetClassIcon(t, token) then
        card.plane.Place(t, x - CARD.w / 2, y - CARD.h / 2, size, size)
        return true
    end
    t:Hide()
    card.textures.used = card.textures.used - 1
    return false
end

-- The level and class, after the icon where there is one.
local function Who(card, style, p, x, y, colour)
    local hasIcon = Icon(card, p.classToken, x + 6, y, 12)
    card:Text(DungeonPage.Words.Who(p.level, p.class), x + (hasIcon and 16 or 0), y, Style.FRIZ, 10, colour)
end

-- The note jotted on the card (DungeonPage.CardJot), in the body from
-- the design's `jot` place, no further right than `right` and no lower
-- than `foot` (CARD.jot): the hand at its size, or smaller where it will
-- not fit; turned up off the card's line, begun a little off the margin
-- and its lines a little apart from it (seeded by the person, so a card
-- reads the same every time). A note about an item has its tooltip over
-- the note's box. A design may say where in px (`place`, else its `jot`),
-- how far it rises (`turn`) and drifts (`drift`), how high its letters
-- may reach (`top`), how far apart its lines are (`lead`, x-heights), and
-- that it is written
-- on one line, its lines joined a space apart (`one`). Kept for the
-- tests: card.jot { key, fact, pieces, box (on the card, from its top
-- left) }.
local function Jot(card, style, p, right, foot, place)
    card.hovers:Begin()
    card.jot = nil
    local fact, key = DungeonPage.CardJot(p)
    local note = ns.UI.Hand.Note(key)
    if note then
        local J, A = CARD.jot, place or style.jot
        local U = ns.UI.Pen.Random(Surface.Seed(p.guid .. ":jot"))
        local T = A.turn or J.turn
        local turn = math.rad(T[1] + (T[2] - T[1]) * U())
        local x = A.x + (A.drift or J.drift) * U()
        local indent, lead = { 0 }, A.lead
        for i = 2, #note.lines do indent[i] = (A.after or 0) + (2 * U() - 1) * J.indent end
        if A.one then
            lead = 0
            for i = 2, #note.lines do indent[i] = indent[i - 1] + (note.lines[i - 1].w + SLIP.gap) * J.size end
        end
        -- Turned up about its first baseline's left end, and set down by
        -- half its rise, so the line's middle lies on the place. Its size:
        -- as big as the hand is written, unless its widest line or its
        -- lowest letter would run past the body.
        local w, h, top = ns.UI.Hand.Measure(note, J.size, lead, indent)
        -- (On one line, its tallest and lowest letters of any line.)
        if A.one then
            local up, down = 0, 0
            for _, line in ipairs(note.lines) do up, down = math.max(up, line.up), math.max(down, line.down) end
            top, h = up * J.size, (up + down) * J.size
        end
        local rise = math.sin(turn)
        local fit = math.min(1, (right - x) / (w * math.cos(turn) + (h - top) * rise),
            (foot - A.y) / (h - top + w * rise / 2))
        -- (No higher than the design's `top`, where art hangs over it.)
        if A.top then fit = math.min(fit, (A.y - A.top) / (top + w * rise / 2)) end
        local size = J.size * fit
        -- (Joined lines' places shrink with the hand.)
        if A.one then for i = 2, #indent do indent[i] = indent[i] * fit end end
        local prims = {}
        local made, box = ns.UI.Hand.Draw(prims, note, { x = x, y = A.y + w * fit * rise / 2, size = size,
            turn = turn, lead = lead, indent = indent, colour = J.ink, alpha = J.alpha })
        card:Ink("ARTWORK", 3, prims, J.ink)
        card.jot = { key = key, fact = fact, pieces = made, box = box, size = size }
        if fact.item and box then
            local hover = card.hovers:Next()
            hover.item, hover.text = fact.item, DungeonPage.Words.Fact(fact, p.visit)
            card:Over(hover, box[1], box[2], box[3] - box[1], box[4] - box[2])
        end
    end
    card.hovers:Finish()
end

-- Its shadow on the sheet where it lies over its edge, its stock lit by
-- the table's lamp and its cut edge (`w` wide: a gnome's without its stub, once torn). The
-- shadow is cast from its height over the sheet under its edge
-- (UI/Dungeon/Heights.lua's HEIGHT.onCard), a few copies of its outline
-- from the contact shadow out (UI/Paper/Light.lua's Cast); the light falls
-- across it as across the map's facets (SHEEN), not laid flat. Kept for its
-- shadow on the world (Ground): its outline, card.outline.
local function Stock(card, style, w)
    local layers, colour = DungeonPage.Cast(DungeonPage.HEIGHT.onCard, "paper")
    local lit = not card.flat
    -- The user's art: the card as drawn, its shadow its own outline; a
    -- layer up from the table's, where a slip tucked under it lies.
    if style.art.stock then
        local file, C = style.art.stock, style.coords or { 0, 1, 0, 1 }
        for _, L in ipairs(layers) do
            card:Art("BORDER", -8, file, C, L[1] - L[3], L[2] - L[3], w + 2 * L[3], CARD.h + 2 * L[3], colour, L[4])
        end
        local art = card:Art("BORDER", -7, file, C, 0, 0, w, CARD.h)
        if lit then ns.UI.Light.Sheen(art, card:Art("BORDER", -6, file, C, 0, 0, w, CARD.h), nil, file) end
        card.outline = { file = file, coords = C, w = w }
        return
    end
    for _, L in ipairs(layers) do
        card:Rect("BACKGROUND", -8, L[1] - L[3], L[2] - L[3], w + 2 * L[3], CARD.h + 2 * L[3], colour, L[4])
    end
    local stock = card:Rect("BACKGROUND", -5, 0, 0, w, CARD.h, style.stock, 1)
    if lit then ns.UI.Light.Sheen(stock, card:Rect("BACKGROUND", -4, 0, 0, w, CARD.h, style.stock, 1), style.stock) end
    local I = Style.INK
    for _, e in ipairs({ { 0, 0, w, 1 }, { 0, CARD.h - 1, w, 1 }, { 0, 0, 1, CARD.h }, { w - 1, 0, 1, CARD.h } }) do
        card:Rect("BACKGROUND", -3, e[1], e[2], e[3], e[4], I, CARD.cut)
    end
    card.outline = { w = w }
end

-- A place on the art (fractions, STYLES.dwarf) on the card, px.
local function At(fx, fy) return fx * CARD.w, fy * CARD.h end

-- The note on a slip tucked under the card's foot (DungeonPage.CardSlip):
-- the paper and its shadow under the card's own stock, a faint rule, and
-- the note in the diary's ink on it. Kept for the tests as Jot's card.jot,
-- with the slip.
local function Slip(card, p)
    card.hovers:Begin()
    card.jot = nil
    local slip = DungeonPage.CardSlip(p)
    if slip then
        local S, J = SLIP, CARD.jot
        local x0, y0 = slip.cx - slip.w / 2, slip.cy - slip.h / 2
        -- Its shadow from its height over what is under it, its paper lit.
        local layers, colour = DungeonPage.Cast(DungeonPage.HEIGHT.slip, "paper")
        for _, L in ipairs(layers) do
            card:Rect("BACKGROUND", -8, x0 + L[1] - L[3], y0 + L[2] - L[3], slip.w + 2 * L[3], slip.h + 2 * L[3],
                colour, L[4], slip.turn)
        end
        local paper = card:Rect("BACKGROUND", -7, x0, y0, slip.w, slip.h, S.paper, 1, slip.turn)
        if not card.flat then
            ns.UI.Light.Sheen(paper, card:Rect("BACKGROUND", -6, x0, y0, slip.w, slip.h, S.paper, 1, slip.turn), S.paper)
        end
        -- The rule under the writing's (last) line, the slip's width less
        -- a little, turned with it.
        local base = (slip.lead > 0 and (#slip.note.lines - 1) * slip.lead * slip.size or 0) + 1
        local rx, ry = Surface.Turned(slip.x, slip.y, slip.w / 2 - SLIP.pad, base, math.cos(slip.turn), math.sin(slip.turn))
        card:Rect("BACKGROUND", -6, rx - (slip.w - 6) / 2, ry - 0.3, slip.w - 6, 0.6, S.rule, S.rule[4], slip.turn)
        local prims = {}
        local made, box = ns.UI.Hand.Draw(prims, slip.note, { x = slip.x, y = slip.y, size = slip.size, turn = slip.turn,
            lead = slip.lead, indent = slip.indent, colour = J.ink, alpha = J.alpha })
        -- On the slip, under the card (its art is a layer up).
        card:Ink("BACKGROUND", -5, prims, J.ink)
        card.jot = { key = slip.key, fact = slip.fact, pieces = made, box = box, size = slip.size, slip = slip }
        if slip.fact.item and box then
            local hover = card.hovers:Next()
            hover.item, hover.text = slip.fact.item, DungeonPage.Words.Fact(slip.fact, p.visit)
            card:Over(hover, box[1], box[2], box[3] - box[1], box[4] - box[2])
        end
    end
    card.hovers:Finish()
end

-- The diary's red wax seal, pressed (`pressed`), or the chalk ring where
-- it will be pressed: a dwarf's way into the diary (STYLES.dwarf.seal).
local function Seal(card, s, pressed)
    local E = s.seal
    local x, y = At(E.x, E.y)
    local r = E.r
    if not pressed then
        -- A ring in chalk, in dashes, its faint dark stroke under it.
        local C, U = DungeonPage.CHALK, DungeonPage.CHALK.under
        for k = 0, E.dashes - 1 do
            local from, to = k / E.dashes, (k + 0.55) / E.dashes
            card:Ring("ARTWORK", 4, x + U.offset, y + U.offset, E.ring, E.ring, 1.3, Style.INK_STRONG, U.alpha, from, to)
            card:Ring("ARTWORK", 5, x, y, E.ring, E.ring, 1.2, C.colour, 0.9, from, to)
        end
        return
    end
    -- Its shadow, its spill round the rim (seeded by the card's person),
    -- the wax, the rim the seal's die pressed and the diary's lozenge in
    -- it, and the light on the wax.
    local U = ns.UI.Pen.Random(Surface.Seed((card.person and card.person.guid or "") .. ":seal"))
    card:Disc("ARTWORK", 4, x + 1, y + 1.5, 2 * r + 1, Style.INK_STRONG, 0.45)
    for k = 1, E.drops do
        local a = 2 * math.pi * (k + U() * 0.6) / E.drops
        local d = r * (0.72 + 0.18 * U())
        card:Disc("ARTWORK", 5, x + math.cos(a) * d, y + math.sin(a) * d, r * (0.55 + 0.25 * U()), E.wax, 1)
    end
    card:Disc("ARTWORK", 5, x, y, 2 * r, E.wax, 1)
    card:Ring("ARTWORK", 6, x, y, r * 0.66, r * 0.66, 1.1, E.deep, 0.85, 0, 1)
    card:Rect("ARTWORK", 6, x - 3, y - 3, 6, 6, E.deep, 0.9, math.pi / 4)
    card:Disc("ARTWORK", 7, x - r * 0.38, y - r * 0.42, r * 0.5, E.light, 0.45)
end

-- A dwarf's card (STYLES.dwarf): the user's art, the name and the level
-- and class in its slots, the class's icon on the stone beside the short
-- one, the note on a slip under its foot, the seal over its corner.
local function Dwarf(card, s, p)
    Stock(card, s, CARD.w)
    local N, Wh = s.slots.name, s.slots.who
    local nx0, ny0 = At(N[1], N[2])
    local nx1, ny1 = At(N[3], N[4])
    Name(card, s, (p.first or "?") .. (p.surname and (" " .. p.surname) or ""), (nx0 + nx1) / 2, (ny0 + ny1) / 2,
        nx1 - nx0 - 2 * s.inset, "CENTER")
    local wx0, wy0 = At(Wh[1], Wh[2])
    local wx1, wy1 = At(Wh[3], Wh[4])
    local I = s.icon
    Icon(card, p.classToken, I.x * CARD.w, (wy0 + wy1) / 2, I.size)
    -- The level and class, fitted to the slot like the name.
    local F = s.who
    local text, room = DungeonPage.Words.Who(p.level, p.class), wx1 - wx0 - 2 * F.inset
    local size, m = F.size, card.measure
    m:SetFont(F.font, size, "")
    m:SetText(text)
    local natural = Surface.Width(m)
    while natural * size / F.size > room and size > F.least do size = math.max(F.least, size - 0.5) end
    local c = s.ink
    card.whoText = card:Text(text, (wx0 + wx1) / 2, (wy0 + wy1) / 2, F.font, size, { c[1], c[2], c[3], F.alpha },
        "CENTER", nil, room)
    card.whoSize = size
    Slip(card, p)
    card.stamped = p.inDiary and not p.isMe
    if not p.isMe then Seal(card, s, card.stamped) end
    local x, y = At(s.seal.x, s.seal.y)
    local r = s.seal.r + 2
    return { x = x - r, y = y - r, w = 2 * r, h = 2 * r }
end

-- A night elf's leaf (STYLES.nightelf.leaf), the same every time for one
-- person: the points round it (from its notch up one side to its tip and
-- back down the other), and a place on it (t along its midrib from the
-- stalk's joint, u out from it, both in `len`s).
local function LeafShape(L, seed)
    local U = ns.UI.Pen.Random(Surface.Seed(seed))
    local cx, cy = At(L.x, L.y)
    local a = math.rad(L.turn)
    -- Along the midrib to the tip (y down), and across it.
    local dx, dy = math.cos(a), -math.sin(a)
    local nx, ny = -dy, dx
    local bx, by = cx - dx * L.len * 0.45, cy - dy * L.len * 0.45
    local function P(t, u) return bx + (dx * t + nx * u) * L.len, by + (dy * t + ny * u) * L.len end
    local E, edge = L.edge, {}
    for i = 1, #E do edge[#edge + 1] = { P(E[i][1], E[i][2] * (1 + (2 * U() - 1) * L.wobble)) } end
    for i = #E - 1, 2, -1 do edge[#edge + 1] = { P(E[i][1], -E[i][2] * (1 + (2 * U() - 1) * L.wobble)) } end
    return edge, P
end

-- How far out the leaf's edge lies at t along its midrib (in `len`s).
local function LeafWidth(L, t)
    local E = L.edge
    for i = 4, #E - 1 do
        local a, b = E[i], E[i + 1]
        if t <= b[1] then return a[2] + (b[2] - a[2]) * math.max(0, t - a[1]) / (b[1] - a[1]) end
    end
    return 0
end

-- The leaf pressed on the card (`pressed`): its shadow, the leaf, its rim
-- and veins and stalk; or its outline in pencil where it will be pressed.
-- A night elf's way into the diary. Returns its box on the card.
local function Leaf(card, s, pressed, draw)
    local L = s.leaf
    local edge, P = LeafShape(L, (card.person and card.person.guid or "") .. ":leaf")
    local n = #edge
    local sx, sy = P(-L.stalk, 0.05)
    local x0, y0, x1, y1 = sx, sy, sx, sy
    for _, e in ipairs(edge) do
        x0, y0, x1, y1 = math.min(x0, e[1]), math.min(y0, e[2]), math.max(x1, e[1]), math.max(y1, e[2])
    end
    local box = { x = x0 - 2, y = y0 - 2, w = x1 - x0 + 4, h = y1 - y0 + 4 }
    if not draw then return box end
    local jx, jy = P(0, 0)
    local mx, my = P(-L.stalk * 0.5, 0.01)
    if not pressed then
        -- Each edge's first half in pencil: a dashed outline, and its stalk.
        local G = L.pencil
        for i = 1, n do
            local a, b = edge[i], edge[i % n + 1]
            card:Line("ARTWORK", 4, a[1], a[2], (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, G.width, G.colour, G.alpha)
        end
        card:Line("ARTWORK", 4, jx, jy, sx, sy, G.width, G.colour, G.alpha)
        return box
    end
    -- A fan of triangles from its middle; where corners cannot move, a disc.
    local cx, cy = P(0.35, 0)
    local S, B = L.shadow, L.body
    local fanned = true
    for i = 1, n do
        local a, b = edge[i], edge[i % n + 1]
        if not card:Quad("ARTWORK", 5, Style.INK_STRONG, S[3], cx + S[1], cy + S[2], a[1] + S[1], a[2] + S[2],
            b[1] + S[1], b[2] + S[2], b[1] + S[1], b[2] + S[2]) then
            fanned = false
            break
        end
        card:Quad("ARTWORK", 6, B, 1, cx, cy, a[1], a[2], b[1], b[2], b[1], b[2])
    end
    if not fanned then
        card:Disc("ARTWORK", 5, cx + S[1], cy + S[2], L.len * 0.9, Style.INK_STRONG, S[3])
        card:Disc("ARTWORK", 6, cx, cy, L.len * 0.9, B, 1)
    end
    local R, V = L.rim, L.vein
    for i = 1, n do
        local a, b = edge[i], edge[i % n + 1]
        card:Line("ARTWORK", 7, a[1], a[2], b[1], b[2], 0.5, R, R[4])
    end
    -- The midrib, three veins a side running out and on, two into the
    -- lobes; the stalk, bent a little.
    local tx, ty = P(0.9, 0)
    card:Line("ARTWORK", 7, jx, jy, tx, ty, 0.8, V, V[4])
    for _, side in ipairs({ 1, -1 }) do
        for _, t in ipairs({ 0.15, 0.38, 0.6 }) do
            local ax, ay = P(t, 0)
            local bx, by = P(t + 0.17, side * 0.8 * LeafWidth(L, t + 0.17))
            card:Line("ARTWORK", 7, ax, ay, bx, by, 0.6, V, V[4])
        end
        local lx, ly = P(-0.07, side * 0.24)
        card:Line("ARTWORK", 7, jx, jy, lx, ly, 0.6, V, V[4])
    end
    card:Line("ARTWORK", 7, jx, jy, mx, my, 0.9, R, R[4])
    card:Line("ARTWORK", 7, mx, my, sx, sy, 0.8, R, R[4])
    return box
end

-- A line sitting on a rule at y (its middle F.sit of its size above it),
-- from x (or centred on it: `justify`), in F's font and colour c at
-- F.alpha: fitted to `fit` px down to F.least, cut short at `room`.
-- Returns it and its size.
local function OnRule(card, F, c, text, x, y, fit, room, justify)
    local size, m = F.size, card.measure
    m:SetFont(F.font, size, "")
    m:SetText(text)
    local natural = Surface.Width(m)
    while natural * size / F.size > fit and size > F.least do size = math.max(F.least, size - 0.5) end
    local fs = card:Text(text, x, y - F.sit * size, F.font, size, { c[1], c[2], c[3], F.alpha }, justify, nil, room,
        F.shade)
    return fs, size
end

-- A ruled card (STYLES.nightelf, skyborne): the user's art; the name, and
-- the level and class, in its holder's hand on its ruled lines; the note
-- on the open stock above the name.
local function Ruled(card, s, p)
    Stock(card, s, CARD.w)
    local Ln, N, F = s.lines, s.name, s.who
    -- Where a line goes on its rule: from its left end `inset` px in, or
    -- centred on it (`centre`, and over its ends by up to `overhang` px
    -- before it is made smaller); fitted, cut short at its reach.
    local function On(line, R)
        local x0, y = At(line[1], line[3])
        local x1 = line[2] * CARD.w
        if s.centre then
            local cx = (x0 + x1) / 2
            local room = 2 * math.min(cx - R[1] * CARD.w, R[2] * CARD.w - cx)
            return cx, y, math.min(room, x1 - x0 + 2 * (s.overhang or -s.inset)), room, "CENTER"
        end
        local x = x0 + s.inset
        return x, y, x1 - x - s.inset, R * CARD.w - x
    end
    local nx, ny, fit, room, justify = On(Ln.name, N.reach)
    Name(card, s, (p.first or "?") .. (p.surname and (" " .. p.surname) or ""), nx, ny, room, justify, fit)
    -- The level and class the same way on the short rule.
    local wx, wy, wfit, wroom, wjustify = On(Ln.who, F.reach)
    card.whoText, card.whoSize = OnRule(card, F, s.ink, DungeonPage.Words.Who(p.level, p.class), wx, wy, wfit, wroom,
        wjustify)
    -- (A design may take its note on a slip under its foot instead.)
    if s.slip then return Slip(card, p) end
    local A = s.jot
    local jx, jy = At(A.x, A.y)
    Jot(card, s, p, A.right * CARD.w, A.foot * CARD.h, { x = jx, y = jy, turn = A.turn, drift = A.drift, one = A.one,
        top = A.top and A.top * CARD.h, lead = A.lead, after = A.after })
end

-- A night elf's card (STYLES.nightelf): ruled, the leaf pressed beside the
-- carved corner.
local function NightElf(card, s, p)
    Ruled(card, s, p)
    card.pressed = p.inDiary and not p.isMe
    return Leaf(card, s, card.pressed, not p.isMe)
end

-- A Skyborne's gem kindled (`lit`), or a ring pencilled round it where it
-- will be: its way into the diary (STYLES.skyborne.gem). Laid over the
-- art, never painting it out: a faint light gathering round the setting,
-- the gem's own light added to it, a glint on its upper facet. Returns
-- its box on the card.
local function Gem(card, s, lit, draw)
    local E = s.gem
    local x, y = At(E.x, E.y)
    local rx, ry = E.ring[1], E.ring[2]
    local box = { x = x - rx - 1, y = y - ry - 1, w = 2 * rx + 2, h = 2 * ry + 2 }
    if not draw then return box end
    if not lit then
        local G = E.pencil
        for k = 0, G.dashes - 1 do
            card:Ring("ARTWORK", 4, x, y, rx, ry, G.width, G.colour, G.alpha, k / G.dashes, (k + 0.55) / G.dashes)
        end
        return box
    end
    for k = 1, E.halo do
        card:Disc("ARTWORK", 5, x, y, 2 * E.r * (1 - (k - 1) / (E.halo + 1)), E.light, E.alpha)
    end
    local L = E.lit
    card:Disc("ARTWORK", 6, x, y + 1, 2 * L.r, L, L[4]):SetBlendMode("ADD")
    -- The glint: a star, long up and down, shorter across, its diagonals
    -- short (`len`), a bright point at its heart.
    local G, Ln = E.glint, E.glint.len
    local gx, gy = x + G.x, y + G.y
    card:Line("ARTWORK", 7, gx, gy - Ln[1] / 2, gx, gy + Ln[1] / 2, 0.6, G.colour, 0.95)
    card:Line("ARTWORK", 7, gx - Ln[2] / 2, gy, gx + Ln[2] / 2, gy, 0.6, G.colour, 0.95)
    local d = Ln[3] / 2 / math.sqrt(2)
    card:Line("ARTWORK", 7, gx - d, gy - d, gx + d, gy + d, 0.5, G.colour, 0.8)
    card:Line("ARTWORK", 7, gx - d, gy + d, gx + d, gy - d, 0.5, G.colour, 0.8)
    card:Disc("ARTWORK", 7, gx, gy, 1.6, G.colour, 1)
    return box
end

-- A Skyborne's card (STYLES.skyborne): ruled, the gem kindled.
local function Skyborne(card, s, p)
    Ruled(card, s, p)
    card.lit = p.inDiary and not p.isMe
    return Gem(card, s, card.lit, not p.isMe)
end

-- Where someone is about for a live portrait: the user always, anyone
-- else where a unit the client knows is them (target, focus, mouse, the
-- party, the raid).
local UNITS = { "target", "focus", "mouseover" }
for i = 1, 4 do UNITS[#UNITS + 1] = "party" .. i end
for i = 1, 40 do UNITS[#UNITS + 1] = "raid" .. i end
local function UnitOf(p)
    if p.isMe then return "player" end
    for _, unit in ipairs(UNITS) do
        if UnitGUID(unit) == p.guid then return unit end
    end
    return nil
end

-- A gnome's photo in its slot (STYLES.gnome.photo): their face, live, or
-- their race's portrait, cropped like a photo; else the badge's blank head
-- and shoulders. Kept for the tests: card.photo ("live", "race", "blank").
local function Photo(card, s, p)
    local P, C = s.photo, s.crop
    local x0, y0 = At(P[1], P[2])
    local x1, y1 = At(P[3], P[4])
    local w, h = x1 - x0, y1 - y0
    local function Crop(l, r, t, b)
        return { l + (r - l) * C[1], l + (r - l) * C[2], t + (b - t) * C[3], t + (b - t) * C[4] }
    end
    local unit = type(SetPortraitTexture) == "function" and UnitOf(p)
    if unit then
        card:Art("ARTWORK", 1, function(t) SetPortraitTexture(t, unit) end, Crop(0, 1, 0, 1), x0, y0, w, h)
        card.photo = "live"
        return
    end
    local file, part = Style.RaceFace({ race = p.race, sex = p.sex })
    if file then
        card:Art("ARTWORK", 1, file, Crop(part[1], part[2], part[3], part[4]), x0, y0, w, h)
        card.photo = "race"
        return
    end
    local B, cx = s.blank, (x0 + x1) / 2
    card:Disc("ARTWORK", 1, cx, y0 + 0.42 * h, 0.36 * w, B, 1)
    card:Disc("ARTWORK", 1, cx, y0 + 0.74 * h, 0.6 * w, B, 1)
    card:Rect("ARTWORK", 1, cx - 0.3 * w, y0 + 0.74 * h, 0.6 * w, y1 - (y0 + 0.74 * h), B, 1)
    card.photo = "blank"
end

-- A gnome's badge stamped (`inked`), or the ring of dots printed where it
-- will be: its way into the diary (STYLES.gnome.stamp). Returns its box.
local function Stamp(card, s, inked, draw)
    local E = s.stamp
    local x, y = At(E.x, E.y)
    local r = E.r
    local box = { x = x - r - 2, y = y - r - 2, w = 2 * r + 4, h = 2 * r + 4 }
    if not draw then return box end
    if not inked then
        for k = 0, E.dots - 1 do
            local a = 2 * math.pi * k / E.dots
            card:Disc("ARTWORK", 4, x + math.cos(a) * r, y + math.sin(a) * r, 1.3, E.dot, E.dot[4])
        end
        return box
    end
    -- Inked a little unevenly, turned its own way (seeded by the person).
    local U = ns.UI.Pen.Random(Surface.Seed((card.person and card.person.guid or "") .. ":stamp"))
    local turn = math.rad((2 * U() - 1) * E.turn)
    local I = E.ink
    for k = 1, E.teeth do
        local a = turn + 2 * math.pi * k / E.teeth
        local tx, ty = x + math.cos(a) * r, y + math.sin(a) * r
        card:Rect("ARTWORK", 5, tx - 1.2, ty - 1.2, 2.4, 2.4, I, E.alpha * (0.8 + 0.2 * U()), -a)
    end
    card:Ring("ARTWORK", 5, x, y, r - 0.9, r - 0.9, 1.4, I, E.alpha, 0, 1)
    card:Ring("ARTWORK", 5, x, y, r - 3, r - 3, 0.6, I, E.alpha * 0.8, 0, 1)
    -- The tick, turned with it.
    local c, sn = math.cos(turn), math.sin(turn)
    local function P(u, v) return x + u * c + v * sn, y - u * sn + v * c end
    local ax, ay = P(-2.3, 0.1)
    local bx, by = P(-0.6, 1.9)
    local tx, ty = P(2.5, -2.1)
    card:Line("ARTWORK", 6, ax, ay, bx, by, 1.3, I, E.alpha)
    card:Line("ARTWORK", 6, bx, by, tx, ty, 1.3, I, E.alpha)
    return box
end

-- A gnome's card (STYLES.gnome): the user's art; the photo, the class's
-- icon in the disc, the three fields printed on their rules; the note on
-- a slip under its foot; the stamp over the header.
local function Gnome(card, s, p)
    Stock(card, s, CARD.w)
    Photo(card, s, p)
    local D = s.disc
    Icon(card, p.classToken, D.x * CARD.w, D.y * CARD.h, D.icon)
    local Fd, I = s.fields, s.print
    local nx, ny = At(Fd.name[1], Fd.name[3])
    nx = nx + s.inset
    local room = Fd.name[2] * CARD.w - nx - s.inset
    Name(card, s, (p.first or "?") .. (p.surname and (" " .. p.surname) or ""), nx, ny, room)
    local wx, wy = At(Fd.who[1], Fd.who[3])
    wx = wx + s.inset
    room = Fd.who[2] * CARD.w - wx - s.inset
    card.whoText, card.whoSize = OnRule(card, I, s.ink, DungeonPage.Words.Who(p.level, p.class), wx, wy, room, room)
    local ix, iy = At(Fd.id[1], Fd.id[3])
    ix = ix + s.inset
    room = Fd.id[2] * CARD.w - ix - s.inset
    card.idText, card.idSize = OnRule(card, I, s.ink, DungeonPage.Words.Serial(p.guid), ix, iy, room, room)
    Slip(card, p)
    card.stamped = p.inDiary and not p.isMe
    return Stamp(card, s, card.stamped, not p.isMe)
end

-- A human's way into the diary (STYLES.human.pendant): the diary's seal in
-- blue wax and gold, hung on a ribbon from the banner's rod (`sealed`), or
-- a ring pencilled where it will hang; an undead's the same, ruined
-- (STYLES.undead.pendant: the ring in chalk, `chalk`; one tail of its cord
-- torn short, `frayed`; the wax cracked, `crack`). Returns its box.
local function Pendant(card, s, sealed, draw)
    local E = s.pendant
    local x, y = At(E.x, E.y)
    local r = E.r
    local box = { x = x - r - 2, y = y - r - 2, w = 2 * r + 4, h = 2 * r + 4 }
    if not draw then return box end
    if not sealed then
        for k = 0, E.dashes - 1 do
            local from, to = k / E.dashes, (k + 0.55) / E.dashes
            if E.chalk then
                -- In chalk, its faint dark stroke under it (as a dwarf's).
                local C, Un = DungeonPage.CHALK, DungeonPage.CHALK.under
                card:Ring("ARTWORK", 3, x + Un.offset, y + Un.offset, r + 0.8, r + 0.8, 1.3, Style.INK_STRONG, Un.alpha,
                    from, to)
                card:Ring("ARTWORK", 4, x, y, r + 0.8, r + 0.8, 1.2, C.colour, 0.9, from, to)
            else
                local G = E.pencil
                card:Ring("ARTWORK", 4, x, y, r + 0.8, r + 0.8, G.width, G.colour, G.alpha, from, to)
            end
        end
        return box
    end
    -- The ribbon: two tails from the knot on the rod to the seal's top,
    -- crossing a little (one torn short where `frayed`).
    local kx, ky = At(E.knot[1], E.knot[2])
    card:Line("ARTWORK", 5, kx, ky, x - 1.2, y - r + 1, 1.8, E.ribbon, 1)
    if E.frayed then
        card:Line("ARTWORK", 5, kx + 1.2, ky, kx + 1.2 + (x + 1 - kx - 1.2) * 0.45, ky + (y - r + 1 - ky) * 0.45, 1.4,
            E.ribbon, 0.9)
    else
        card:Line("ARTWORK", 5, kx + 1.2, ky, x + 1, y - r + 1, 1.5, E.ribbon, 0.9)
    end
    -- Its shadow on the wall, the spill round its rim (seeded), the wax, a
    -- gold ring pressed in it and the diary's lozenge in gold, the light.
    local U = ns.UI.Pen.Random(Surface.Seed((card.person and card.person.guid or "") .. ":pendant"))
    card:Disc("ARTWORK", 5, x + 1, y + 1.5, 2 * r + 1, Style.INK_STRONG, 0.4)
    for k = 1, E.drops do
        local a = 2 * math.pi * (k + U() * 0.6) / E.drops
        local d = r * (0.7 + 0.18 * U())
        card:Disc("ARTWORK", 6, x + math.cos(a) * d, y + math.sin(a) * d, r * (0.5 + 0.25 * U()), E.wax, 1)
    end
    card:Disc("ARTWORK", 6, x, y, 2 * r, E.wax, 1)
    card:Ring("ARTWORK", 7, x, y, r * 0.66, r * 0.66, 0.9, E.gold, 0.95, 0, 1)
    card:Rect("ARTWORK", 7, x - 1.6, y - 1.6, 3.2, 3.2, E.gold, 1, math.pi / 4)
    card:Disc("ARTWORK", 7, x - r * 0.36, y - r * 0.4, r * 0.5, E.light, 0.4)
    if E.crack then
        -- Cracked across, a chip of it gone at the rim.
        card:Line("ARTWORK", 7, x - r * 0.75, y - r * 0.2, x + r * 0.1, y + r * 0.15, 0.6, E.deep, 0.95)
        card:Line("ARTWORK", 7, x + r * 0.1, y + r * 0.15, x + r * 0.55, y + r * 0.7, 0.6, E.deep, 0.95)
        card:Disc("ARTWORK", 7, x + r * 0.78, y - r * 0.55, r * 0.55, E.deep, 0.9)
    end
    return box
end

-- A human's card (STYLES.human): ruled and centred, the seal hung on the
-- banner's rod.
local function Human(card, s, p)
    Ruled(card, s, p)
    card.sealed = p.inDiary and not p.isMe
    return Pendant(card, s, card.sealed, not p.isMe)
end

-- An undead's card (STYLES.undead): the human's ruined, ruled and centred
-- in bone, the seal hung on the banner's rusty rod.
local function Undead(card, s, p)
    Ruled(card, s, p)
    card.sealed = p.inDiary and not p.isMe
    return Pendant(card, s, card.sealed, not p.isMe)
end

-- Anyone else's (STYLES.plain).
local function Plain(card, s, p)
    local W, H = CARD.w, CARD.h
    Stock(card, s, W)
    local L = s.laid
    for ly = L.step, H - L.step, L.step do card:Rect("BORDER", 0, 1, ly, W - 2, 0.6, s.ink, L.alpha) end
    Name(card, s, (p.first or "?") .. (p.surname and (" " .. p.surname) or ""), 12, 15, W - 40)
    card:Rect("BORDER", 1, 12, 26, W - 24, 0.8, s.ink, 0.45)
    Who(card, s, p, 12, 36, s.ink)
    Jot(card, s, p, W - CARD.jot.room, H - CARD.jot.room)
    -- A small box by the name, ticked once they are in the diary.
    local B = s.box
    local bx, by = W - B - 12, 10
    for _, e in ipairs({ { bx, by, B, 0.8 }, { bx, by + B - 0.8, B, 0.8 }, { bx, by, 0.8, B }, { bx + B - 0.8, by, 0.8, B } }) do
        card:Rect("ARTWORK", 1, e[1], e[2], e[3], e[4], s.ink, 0.6)
    end
    card.ticked = p.inDiary and not p.isMe
    if card.ticked then
        card:Line("ARTWORK", 2, bx + 2, by + B * 0.55, bx + B * 0.42, by + B - 2, 1.3, Style.INK_STRONG, 0.9)
        card:Line("ARTWORK", 2, bx + B * 0.42, by + B - 2, bx + B + 2, by - 2, 1.3, Style.INK_STRONG, 0.9)
    end
    return { x = bx - 4, y = by - 4, w = B + 8, h = B + 8 }
end


local DRAW = { gnome = Gnome, dwarf = Dwarf, nightelf = NightElf, skyborne = Skyborne, human = Human, undead = Undead, plain = Plain }

-- Lays a card for `p` (DungeonPage.Party's) with its middle at cx, cy of
-- its table, in its own units (a card laid bigger or smaller: card.scaleK),
-- turned `turn` (radians), and draws it.
local function Lay(card, p, cx, cy, turn)
    card.person, card.turn, card.cx, card.cy = p, turn, cx, cy
    card.flat = ns.Setting("flatSheets") == true
    card:ClearAllPoints()
    card:SetPoint("CENTER", card.table, "TOPLEFT", cx, -cy)
    card:Draw()
    card:Show()
end

-- Its shadow on the world (card:Ground), from how high it lies over it
-- (card.height: lying in the stack or held up fanned, UI/Dungeon/
-- Heights.lua; more lifted), and its slip's a little lower; in the
-- world's shadow. None
-- for a card with no height (one spread over the map, which lies on the
-- sheet).
local function Ground(card)
    card.grounds:Begin()
    local o = card.outline
    if card.height and o and card.table.ground then
        local lifted = card.lifted and DungeonPage.HEIGHT.lifted or 0
        local layers, colour = DungeonPage.Cast(card.height + lifted, "world")
        for _, L in ipairs(layers) do
            card:Ground(o.file, o.coords, L[1] - L[3], L[2] - L[3], o.w + 2 * L[3], CARD.h + 2 * L[3], colour, L[4])
        end
        local slip = card.jot and card.jot.slip
        if slip then
            local x0, y0 = slip.cx - slip.w / 2, slip.cy - slip.h / 2
            layers = DungeonPage.Cast(card.height + lifted - DungeonPage.HEIGHT.slip / 2, "world")
            for _, L in ipairs(layers) do
                card:Ground(nil, nil, x0 + L[1] - L[3], y0 + L[2] - L[3], slip.w + 2 * L[3], slip.h + 2 * L[3], colour,
                    L[4], slip.turn)
            end
        end
    end
    card.grounds:Finish()
end

DungeonPage.CardGround = Ground

-- Whether a card answers the mouse (`on`): fanned, not while it lies in
-- the stack or is on its way. Its way into the diary and its notes' tooltips
-- with it; one lifted under the mouse is laid back as it goes. Kept:
-- card.held, while it does not.
local function Reach(card, on)
    card.held = not on or nil
    card:EnableMouse(on)
    local p = card.person
    card.add:SetShown(on and p ~= nil and not p.isMe)
    for i = 1, card.hovers.used do card.hovers[i]:SetShown(on) end
    if not on and card.lifted then card.Lift(false) end
end

local function Draw(card)
    local p = card.person
    local turn = card.flat and 0 or card.turn
    local bends = card.canBend and not card.flat
    card.plane.Set(turn, card.cx, card.cy, bends)
    card.groundPlane.Set(turn, 0, 0, bends)
    card.textures:Begin()
    card.texts:Begin()
    card.style = DungeonPage.CardStyle(p.race)
    local style = STYLES[card.style]
    card.stamped, card.ticked, card.pressed, card.lit, card.sealed, card.photo = nil, nil, nil, nil, nil, nil
    card.outline = nil
    local way = DRAW[card.style](card, style, p)
    -- (Its way in, on the card from its top left: for the tests.)
    card.way = way
    card.textures:Finish()
    card.texts:Finish()
    Ground(card)
    -- The way in, for someone not in the diary; never the user's own.
    local add = card.add
    add.offer = not p.isMe and not p.inDiary
    add:EnableMouse(add.offer)
    if way then
        local x0, y0, x1, y1 = card:Over(add, way.x, way.y, way.w, way.h)
        add.box = { x0, y0, x1, y1 }
    end
    Reach(card, not card.held)
end

--------------------------------------------------------------------------
-- Where they lie: in their stack, and fanned out of it
--------------------------------------------------------------------------

-- The table's space: from the sheet's middle, x right and y down, in the
-- spread's own units (the cards' table, LayCards: something laid at x, y
-- lies there). A point u, v (y down) of something turned `turn` with its
-- middle at x, y is Surface.Turned's.

-- Where the j-th card of the stack lies (the front one first): its middle
-- from the top card's (x right, y down, the stack unturned) and its turn
-- from the stack's (radians). Turned FAN.turn more with the clock for each
-- card over it, about the top card's bottom-right corner, so the stack
-- splays a little up and to the left; set STACK.shift px further left and
-- STACK.rise px higher. Laid `flat`, unturned.
local function InStack(j, flat)
    local w, h = CARD.w * STACK.scale, CARD.h * STACK.scale
    local rel = flat and 0 or -(j - 1) * math.rad(FAN.turn)
    local x, y = Surface.Turned(w / 2, h / 2, -w / 2, -h / 2, math.cos(rel), math.sin(rel))
    return x - (j - 1) * STACK.shift, y - (j - 1) * STACK.rise, rel
end

-- The box round the fullest stack (DECK.most cards and a raid's deck)
-- turned `turn`, STACK.tail more under the top card's foot for its slip:
-- x0, y0, x1, y1 from the top card's middle, on the table's axes.
local function StackBox(turn, flat)
    local w, h = CARD.w * STACK.scale, CARD.h * STACK.scale
    local c, s = math.cos(turn), math.sin(turn)
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for j = 1, DECK.most + 1 do
        local u, v, rel = InStack(j, flat)
        local rc, rs = math.cos(rel), math.sin(rel)
        local foot = j == 1 and STACK.tail or 0
        for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
            local qu, qv = Surface.Turned(u, v, q[1] * w / 2, q[2] * h / 2 + (q[2] > 0 and foot or 0), rc, rs)
            local x, y = Surface.Turned(0, 0, qu, qv, c, s)
            x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
        end
    end
    return x0, y0, x1, y1
end

-- Where the stack lies on the sheet `view` (UI/Dungeon/Sheet.lua: its
-- size, its toolkit K, view.lie and view.screen as the spread fitted it):
-- { x, y (the top card's middle on the table), turn (radians), w, h (a
-- card's size in it), box (left, top, right, bottom on the table, round
-- the fullest stack), corners (the box's, on the table), keep (the part of
-- the sheet under it and its shadow, in the sheet's own coordinates,
-- STACK.keep more, for the strips to keep out of) }. Beside the paper's
-- left edge, its foot STACK.up above the bottom-left corner, STACK.overlap
-- onto the paper; on the screen.
function DungeonPage.StackPlace(view)
    local K, W, H = view.K, view.w, view.h
    if not (K and W and H) then return nil end
    local flat = ns.Setting("flatSheets") == true
    local turn = flat and 0 or math.rad(STACK.turn)
    local x0, y0, x1, y1 = StackBox(turn, flat)
    local function Table(x, y)
        local X, Y = K.Screen(x, y)
        return X, -Y
    end
    local tlx, tly = Table(0, 0)
    local blx, bly = Table(0, H)
    local cy = bly - STACK.up - y1
    local my = cy + (y0 + y1) / 2
    local ex = math.abs(bly - tly) < 1e-6 and tlx or tlx + (blx - tlx) * (my - tly) / (bly - tly)
    local cx = ex + STACK.overlap - x1
    local lie, screen = view.lie or { 0, 0 }, view.screen
    if screen then
        cx = math.max(cx, -lie[1] - screen.w / 2 + STACK.edge - x0)
        cy = math.min(cy, lie[2] + screen.h / 2 - STACK.edge - y1)
    end
    local box = { cx + x0, cy + y0, cx + x1, cy + y1 }
    local corners = { { box[1], box[2] }, { box[3], box[2] }, { box[3], box[4] }, { box[1], box[4] } }
    -- Its box on the sheet, its shadow's reach and STACK.keep round it.
    local angle = view.angle or 0
    local ca, sa = math.cos(angle), math.sin(angle)
    local reach = ns.UI.Light.Fall(DungeonPage.HEIGHT.stack, true) + STACK.keep
    local kx0, ky0, kx1, ky1 = math.huge, math.huge, -math.huge, -math.huge
    for _, q in ipairs(corners) do
        local u, v = q[1] * ca - q[2] * sa, -q[1] * sa - q[2] * ca
        local px, py = u + W / 2, H / 2 - v
        kx0, ky0, kx1, ky1 = math.min(kx0, px), math.min(ky0, py), math.max(kx1, px), math.max(ky1, py)
    end
    return { x = cx, y = cy, turn = turn, w = CARD.w * STACK.scale, h = CARD.h * STACK.scale, box = box,
        corners = corners, keep = { kx0 - reach, ky0 - reach, kx1 + reach, ky1 + reach } }
end

-- How much room the stack needs past the left of a sheet w by h as the
-- spread fits it (UI/Dungeon/Spread.lua's Lie: past the sheet's turned
-- box and its shadow): the more of lying turned (SHEET.turn) and lying
-- straight (a combined map whose masks cannot turn).
function DungeonPage.StackFlank(w, h)
    local S, SP = DungeonPage.SHEET, DungeonPage.SPREAD
    local x0, y0, x1, y1 = StackBox(math.rad(STACK.turn), false)
    local a0 = math.rad(S.turn)
    local box = (w * math.cos(a0) + h * math.sin(a0)) / 2 + SP.shadow
    local most = 0
    for _, a in ipairs({ a0, 0 }) do
        local c, s = math.cos(a), math.sin(a)
        -- The left edge, y up from the sheet's middle.
        local tlx, tly = -w / 2 * c - h / 2 * s, -w / 2 * s + h / 2 * c
        local blx, bly = -w / 2 * c + h / 2 * s, -w / 2 * s - h / 2 * c
        local y = bly + STACK.up + (y1 - y0) / 2
        local ex = tlx + (blx - tlx) * (y - tly) / (bly - tly)
        most = math.max(most, -box - (ex + STACK.overlap - (x1 - x0)))
    end
    return math.max(0, most)
end

-- Where each of `items` (front first, each { deck = true for a raid's
-- deck }) lies, with the stack at `at` (DungeonPage.StackPlace's) and the
-- screen `bounds` on the table ({ x0, y0, x1, y1 }, or nil while not
-- known), cards `flat` or turned: { k (the fan's scale), step (between two
-- cards' middles), and per item { turn, rest (its middle in the stack),
-- lift (how far under the mouse: STACK.hover up the stack), out (its
-- middle lifted off the stack), fan (its middle fanned) } }. A card's place
-- is its middle's; its size there is CARD's times STACK.scale in the
-- stack, k fanned (FAN).
function DungeonPage.FanPlan(at, items, bounds, flat)
    local n = #items
    local pc, ps = math.cos(at.turn), math.sin(at.turn)
    local function P(u, v) return { Surface.Turned(at.x, at.y, u, v, pc, ps) } end
    local k0 = STACK.scale
    local plan = { k0 = k0 }
    local turns = {}
    for j = 1, n do
        local u, v, rel = InStack(j, flat)
        local turn = at.turn + rel
        turns[j] = turn
        -- Lifted off the stack: STACK.hover up it, as under the mouse.
        local rest, up = P(u, v), P(u, v - STACK.hover)
        plan[j] = { turn = turn, rest = rest, lift = { up[1] - rest[1], up[2] - rest[2] }, out = up }
    end
    -- The column at scale k, a card's middle `s` from the next: from the
    -- front card's foot FAN.lift over the top card's foot in the stack,
    -- each next one up along the two cards' mean turn (a raid's deck
    -- showing FAN.deck of itself), slid across to lie inside the screen.
    -- Its places and whether it fits.
    local foot = P(0, k0 * CARD.h / 2 - FAN.lift)
    local function Column(k, s)
        local h, w = CARD.h * k, CARD.w * k
        local places = {}
        local x, y = foot[1] - math.sin(turns[1]) * h / 2, foot[2] - math.cos(turns[1]) * h / 2
        for j = 1, n do
            if j > 1 then
                local a = (turns[j - 1] + turns[j]) / 2
                local step = items[j].deck and FAN.deck * h or s
                x, y = x - math.sin(a) * step, y - math.cos(a) * step
            end
            places[j] = { x, y }
        end
        if not bounds then return places, true end
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        for j = 1, n do
            local c, sn = math.cos(turns[j]), math.sin(turns[j])
            for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
                local qx, qy = Surface.Turned(places[j][1], places[j][2], q[1] * w / 2, q[2] * h / 2, c, sn)
                x0, y0, x1, y1 = math.min(x0, qx), math.min(y0, qy), math.max(x1, qx), math.max(y1, qy)
            end
        end
        local E = FAN.edge
        local dx = 0
        if x0 < bounds[1] + E then dx = bounds[1] + E - x0 end
        if x1 + dx > bounds[3] - E then dx = bounds[3] - E - x1 end
        for j = 1, n do places[j][1] = places[j][1] + dx end
        local fits = y0 >= bounds[2] + E - 1e-6 and x0 + dx >= bounds[1] + E - 1e-6 and y1 <= bounds[4] - E + 1e-6
        return places, fits
    end
    -- As big as fits: whole and apart, else shingled to FAN.show; smaller
    -- to FAN.least; shingled to FAN.name; smaller still.
    local k, step, places
    for i = 0, 60 do
        k = FAN.scale - i * 0.02
        if k < 0.5 then break end
        local h = CARD.h * k
        local full = h + FAN.gap
        local fits
        places, fits = Column(k, full)
        if fits then
            step = full
            break
        end
        local lo = (k >= FAN.least - 1e-9 and FAN.show or FAN.name) * h
        places, fits = Column(k, lo)
        if fits then
            -- The widest step that fits.
            local a, b = lo, full
            for _ = 1, 24 do
                local m = (a + b) / 2
                if select(2, Column(k, m)) then a = m else b = m end
            end
            step = a
            places = Column(k, a)
            break
        end
    end
    if not step then
        -- (No room even so: the smallest tried, as shingled as it goes.)
        step = FAN.name * CARD.h * k
        places = Column(k, step)
    end
    plan.k, plan.step = k, step
    for j = 1, n do plan[j].fan = places[j] end
    return plan
end

--------------------------------------------------------------------------
-- The stack
--------------------------------------------------------------------------

-- What takes the mouse over the cards' stack on the table `t`: a button
-- over them (a card lying in it takes none), its tooltip saying what a
-- click does; under the mouse the cards rise a little, and a click fans
-- them out or gathers them. It runs the fan's driver too.
local function NewStack(spread, t)
    local stack = CreateFrame("Button", nil, t)
    stack.peek, stack.peekTo = 0, 0
    Style.Tooltip(stack, function() return not spread.fanned and { { DungeonPage.Words.STACK } } or nil end, nil,
        function(_, on) DungeonPage.StackPeek(spread, on) end)
    stack:SetScript("OnClick", function() DungeonPage.Fan(spread, not spread.fanned) end)
    return stack
end

-- The button laid over the stack where it lies (`at`, DungeonPage.
-- StackPlace's): its box and STACK.pad round it.
local function LayStack(stack, t, at)
    local b, p = at.box, STACK.pad
    stack:ClearAllPoints()
    stack:SetPoint("TOPLEFT", t, "TOPLEFT", b[1] - p, -(b[2] - p))
    stack:SetSize(b[3] - b[1] + 2 * p, b[4] - b[2] + 2 * p)
    stack:Show()
end

-- A raid's deck's shadow on the world (its `grounds`, on its ground
-- frame), from `height` over it: lying in the stack (HEIGHT.stack) or held
-- up in the fan (HEIGHT.fan). Kept: deck.height.
local function DeckGround(deck, height)
    deck.height = height
    local o = DECK.offset
    local lead = ((DECK.backs + 1) / 2 - 1) * o
    local layers, colour = DungeonPage.Cast(height, "world")
    for k, L in ipairs(layers) do
        local sh = deck.grounds[k]
        sh:SetColorTexture(colour[1], colour[2], colour[3], L[4])
        deck.groundPlane.Place(sh, lead + L[1], lead + L[2], CARD.w + 2 * L[3], CARD.h + 2 * L[3])
        sh:Show()
    end
end

--------------------------------------------------------------------------
-- The fan
--------------------------------------------------------------------------

-- An item (a card, or a raid's deck) put where it is `e` of the way out
-- (0 in the stack, 1 fanned; FanPlan's places): lifted off the stack at
-- its resting size over the first FAN.draw (lifted `peek` of STACK.hover
-- while there), then along an arc to its place, growing; over the stack's
-- button and the cards still in it, and its shadow on the world cast from
-- the fan's height, only once off it.
local function Move(item, e, peek)
    item.e = e
    local D = FAN.draw
    local x, y, k, out
    if e <= D then
        local u = e / D
        local rx, ry = item.rest[1] + item.lift[1] * (peek or 0), item.rest[2] + item.lift[2] * (peek or 0)
        x, y, k, out = rx + (item.out[1] - rx) * u, ry + (item.out[2] - ry) * u, item.k0, false
    else
        local v = (e - D) / (1 - D)
        x = item.out[1] + (item.fan[1] - item.out[1]) * v ^ FAN.bend
        y = item.out[2] + (item.fan[2] - item.out[2]) * v
        k, out = item.k0 + (item.k1 - item.k0) * v, true
    end
    local f = item.frame
    f:SetScale(k)
    f:ClearAllPoints()
    f:SetPoint("CENTER", f.table, "TOPLEFT", x / k, -y / k)
    f.groundFrame:SetScale(k)
    if not f.groundFrame:IsShown() then f.groundFrame:Show() end
    item.at = { x, y, k }
    if out == item.isOut then return end
    item.isOut = out
    local height = DungeonPage.HEIGHT[out and "fan" or "stack"]
    if item.card then
        f:SetLevel(out and item.fanLevel or item.restLevel)
        if f.height ~= height then
            f.height = height
            Ground(f)
        end
    else
        f:SetFrameLevel(out and item.fanLevel or item.restLevel)
        if f.height ~= height then DeckGround(f, height) end
    end
end
DungeonPage.FanMove = Move

-- An item come to rest where it went: fanned, it answers the mouse.
local function Arrive(item)
    local on = item.to == 1
    if item.card then
        Reach(item.frame, on)
    else
        item.frame:EnableMouse(on)
    end
end

-- One frame of the driver: the cards in the stack rising under the mouse
-- or settling, and each card on its way; the driver stopped once all
-- are still.
local function Step(spread, dt)
    local stack, busy = spread.stack, false
    if stack.peek ~= stack.peekTo then
        local d = dt / STACK.hoverTime
        stack.peek = stack.peek < stack.peekTo and math.min(stack.peekTo, stack.peek + d)
            or math.max(stack.peekTo, stack.peek - d)
        busy = stack.peek ~= stack.peekTo
        for _, item in ipairs(spread.fanItems) do
            if item.e <= FAN.draw and item.q >= 1 then Move(item, item.e, stack.peek) end
        end
    end
    for _, item in ipairs(spread.fanItems) do
        if item.q < 1 then
            busy = true
            if item.wait > 0 then
                item.wait = item.wait - dt
            else
                item.q = math.min(1, item.q + dt / item.dur)
                local ease = 1 - (1 - item.q) ^ 3
                Move(item, item.from + (item.to - item.from) * ease, stack.peek)
                if item.q >= 1 then Arrive(item) end
            end
        end
    end
    if not busy then stack:SetScript("OnUpdate", nil) end
end

local function Drive(spread)
    spread.stack:SetScript("OnUpdate", function(_, dt) Step(spread, dt) end)
end

-- The cards in the stack rising a little under the mouse (`on`), or
-- settling back.
function DungeonPage.StackPeek(spread, on)
    local stack = spread.stack
    if not stack then return end
    stack.peekTo = (on and not spread.fanned) and 1 or 0
    if stack.peek ~= stack.peekTo then Drive(spread) end
end

-- The cards fanned out of the stack (`open`) or gathered back into it, one
-- after the other (FAN), the driver run each frame; `now`, at once (the
-- spread put away, laid again). A turn back while they go goes back from
-- where each is. Kept: spread.fanned. Escape is told (spread.onFan).
function DungeonPage.Fan(spread, open, now)
    local items = spread.fanItems
    if not items or #items == 0 then return end
    open = open == true
    if spread.fanned == open and not now then return end
    spread.fanned = open
    local stack = spread.stack
    stack.peekTo = 0
    if spread.onFan then spread.onFan(open) end
    spread.catcher:SetShown(open)
    if not open then
        if spread.spreadOut then DungeonPage.SpreadDeck(spread, false) end
        for _, item in ipairs(items) do
            if item.card then Reach(item.frame, false) else item.frame:EnableMouse(false) end
        end
        GameTooltip:Hide()
    end
    if not now then Style.PlaySound(open and "fanOpen" or "fanClose") end
    local n = #items
    for i, item in ipairs(items) do
        item.from, item.to = item.e, open and 1 or 0
        item.wait = (open and (i - 1) or (n - i)) * FAN.stagger
        item.dur = math.max(0.06, FAN.time * math.abs(item.to - item.from))
        item.q = 0
        if now then
            item.q, item.wait = 1, 0
            Move(item, item.to, 0)
            Arrive(item)
        end
    end
    if now then
        stack.peek = 0
        stack:SetScript("OnUpdate", nil)
    else
        Drive(spread)
    end
end

--------------------------------------------------------------------------
-- The cards on the table
--------------------------------------------------------------------------

-- The deck drawn turned `turn` (radians), with `count` more in it, at
-- `height` over the world (DeckGround): its backs stacked down and to the
-- right, its shadows from its height (on what is under it, and on the
-- world), its top back lit, the paper band round it with the count.
local function DrawDeck(deck, turn, count, height)
    local flat = ns.Setting("flatSheets") == true
    deck.plane.Set(turn, 0, 0, false)
    deck.groundPlane.Set(turn, 0, 0, false)
    local Place, P, o = deck.plane.Place, STYLES.plain.stock, DECK.offset
    for k, back in ipairs(deck.backs) do
        local m = 0.96 + 0.01 * k
        back:SetColorTexture(P[1] * m, P[2] * m, P[3] * m, 1)
        Place(back, (k - 2) * o, (k - 2) * o, CARD.w, CARD.h)
    end
    -- Shadows from the stack's height: on the card under it
    -- (UI/Dungeon/Heights.lua's HEIGHT.deck), and on the world.
    local lead = ((DECK.backs + 1) / 2 - 1) * o
    local layers, colour = DungeonPage.Cast(DungeonPage.HEIGHT.deck, "paper")
    for k, L in ipairs(layers) do
        local sh = deck.shadows[k]
        sh:SetColorTexture(colour[1], colour[2], colour[3], L[4])
        Place(sh, lead + L[1], lead + L[2], CARD.w + 2 * L[3], CARD.h + 2 * L[3])
        sh:Show()
    end
    DeckGround(deck, height)
    local top, m = deck.backs[DECK.backs], 0.96 + 0.01 * DECK.backs
    Place(deck.shade, (DECK.backs - 2) * o, (DECK.backs - 2) * o, CARD.w, CARD.h)
    if flat then
        deck.shade:Hide()
    else
        ns.UI.Light.Sheen(top, deck.shade, { P[1] * m, P[2] * m, P[3] * m })
        deck.shade:Show()
    end
    local paper = Style.PAPER
    local y = -CARD.h / 2 + DECK.inset + DECK.band / 2
    deck.band:SetColorTexture(paper[1], paper[2], paper[3], 1)
    Place(deck.band, 0, y, CARD.w + 6, DECK.band)
    deck.words:SetText(DungeonPage.Words.More(count))
    Place(deck.words, 0, y, CARD.w, DECK.band)
end

-- The cards' table and what lies on it, made the first time: the cards'
-- pool, the stack's button, the raid's deck, the catcher beside the fan
-- (Escape's too: FAN.catcher) and the one beside a spread deck.
local function Build(spread, view)
    local t = CreateFrame("Frame", nil, spread)
    t:SetSize(1, 1)
    t.ground = view.ground
    spread.cardTable = t
    spread.cardPool = ns.UI.Pool.New(function()
        local card = NewCard(t)
        card.Draw = Draw
        return card
    end)
    spread.stack = NewStack(spread, t)
    -- A raid's deck, and what gathers it again once spread.
    local deck = CreateFrame("Button", nil, t)
    deck:SetSize(CARD.w, CARD.h)
    deck.table = t
    deck.plane = Surface.New(deck)
    deck.groundFrame = CreateFrame("Frame", nil, view.ground)
    deck.groundFrame:SetSize(1, 1)
    deck.groundFrame:SetPoint("CENTER", deck, "CENTER")
    deck.groundFrame:Hide()
    deck.groundPlane = Surface.New(deck.groundFrame)
    deck.backs = {}
    for k = 1, DECK.backs do deck.backs[k] = deck:CreateTexture(nil, "BACKGROUND", nil, k - 4) end
    deck.shadows, deck.grounds = {}, {}
    for k = 1, ns.UI.Light.CAST.layers do
        deck.shadows[k] = deck:CreateTexture(nil, "BACKGROUND", nil, -8)
        deck.grounds[k] = deck.groundFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    end
    deck.shade = deck:CreateTexture(nil, "BACKGROUND", nil, 0)
    deck:HookScript("OnHide", function() deck.groundFrame:Hide() end)
    deck.band = deck:CreateTexture(nil, "ARTWORK")
    deck.words = Style.Text(deck, FONT.small)
    deck.words:SetJustifyH("CENTER")
    deck:Hide()
    spread.deck = deck
    local gather = CreateFrame("Frame", nil, spread)
    gather:SetAllPoints(spread)
    gather:EnableMouse(true)
    gather:Hide()
    spread.gather = gather
    deck:SetScript("OnClick", function() DungeonPage.SpreadDeck(spread, true) end)
    gather:SetScript("OnMouseDown", function() DungeonPage.SpreadDeck(spread, false) end)
    -- Beside the fan: a click there puts the cards back, and so does
    -- Escape, which hides it. Hidden with the spread, they go back at once.
    local catcher = CreateFrame("Frame", FAN.catcher, spread)
    catcher:SetAllPoints(spread)
    catcher:EnableMouse(true)
    catcher:Hide()
    spread.catcher = catcher
    catcher:SetScript("OnMouseDown", function() DungeonPage.Fan(spread, false) end)
    catcher:SetScript("OnHide", function()
        if spread.fanned then DungeonPage.Fan(spread, false, not spread:IsVisible()) end
    end)
end

-- The cards of the run out on `spread` (Spread.lua's host) in their stack
-- where the map put it (view.stack, DungeonPage.StackPlace), the page's
-- person's on top; fanned already where they were (laid again: another
-- floor, the screen changed). Frame levels on the table, from the bottom:
-- the deck, the cards in the stack (the front one highest), the stack's
-- button, the catcher beside the fan, the fanned deck and
-- cards (the front one highest), a card lifted, a spread deck. Kept for
-- the tests: spread.cards (each card, in the party's order), spread.deck
-- (a raid's), spread.party, spread.rest (the deck's people),
-- spread.fanItems (FanPlan's places, each with its `frame`, `card` where
-- it is one, `e` how far out it is), spread.fanPlan.
function DungeonPage.LayCards(spread, visit, page, party)
    local view = spread.map
    if not spread.cardTable then Build(spread, view) end
    local t, stack, deck = spread.cardTable, spread.stack, spread.deck
    t.ground = view.ground
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", view.sheet, "CENTER")
    local base = view.sheet:GetFrameLevel() + 40
    t:SetFrameLevel(base)
    spread.party = party
    spread.cardPool:Begin()
    spread.cards, spread.rest, spread.fanItems = {}, {}, {}
    stack:SetScript("OnUpdate", nil)
    stack.peek, stack.peekTo = 0, 0
    deck:Hide()
    if spread.spreadOut then DungeonPage.SpreadDeck(spread, false) end
    local at = view.stack
    if not at or #party == 0 then
        stack:Hide()
        spread.cardPool:Finish()
        spread.fanned = false
        spread.catcher:Hide()
        return
    end
    LayStack(stack, t, at)
    local shown = math.min(#party, DECK.most)
    local items = {}
    for i = 1, shown do items[i] = { p = party[i] } end
    if #party > shown then
        for i = shown + 1, #party do spread.rest[#spread.rest + 1] = party[i] end
        items[#items + 1] = { deck = true }
    end
    local bounds
    local lie, screen = view.lie or { 0, 0 }, view.screen
    if screen then
        bounds = { -lie[1] - screen.w / 2, lie[2] - screen.h / 2, -lie[1] + screen.w / 2, lie[2] + screen.h / 2 }
    end
    local flat = ns.Setting("flatSheets") == true
    local plan = DungeonPage.FanPlan(at, items, bounds, flat)
    spread.fanPlan = plan
    -- The levels: the stack's button over the cards in it, the catcher
    -- over that, fanned over all. Their shadows on the world from how high
    -- they lie: in the stack or fanned.
    local front, fanBase = base + 10 * (DECK.most + 3), base + 10 * (DECK.most + 5)
    stack:SetFrameLevel(front)
    local height = DungeonPage.HEIGHT[spread.fanned and "fan" or "stack"]
    spread.catcher:SetFrameLevel(front + 10)
    spread.fanTop = fanBase + 10 * (DECK.most + 2)
    local e = spread.fanned and 1 or 0
    for j, item in ipairs(items) do
        local P = plan[j]
        local it = { rest = P.rest, lift = P.lift, out = P.out, fan = P.fan, turn = P.turn, k0 = plan.k0, k1 = plan.k,
            e = e, from = e, to = e, q = 1, wait = 0, dur = 0 }
        if item.deck then
            it.frame, it.restLevel, it.fanLevel = deck, base + 5, fanBase + 5
            deck:SetScale(plan.k)
            DrawDeck(deck, P.turn, #spread.rest, height)
            deck:Show()
        else
            local card = spread.cardPool:Next()
            it.frame, it.card = card, card
            it.restLevel, it.fanLevel = base + 10 * (shown - j + 2), fanBase + 10 * (shown - j + 2)
            card.height = height
            card.held = not spread.fanned or nil
            card.scaleK = plan.k
            card:SetScale(plan.k)
            card:SetLevel(it.restLevel)
            Lay(card, item.p, P.fan[1] / plan.k, P.fan[2] / plan.k, P.turn)
            card.item = j
            spread.cards[#spread.cards + 1] = card
        end
        spread.fanItems[j] = it
        Move(it, e, 0)
        it.to = e
        Arrive(it)
    end
    spread.cardPool:Finish()
    spread.catcher:SetShown(spread.fanned == true)
end

-- A raid's deck spread over the map as a grid (`on`), or gathered back.
function DungeonPage.SpreadDeck(spread, on)
    local view, rest = spread.map, spread.rest or {}
    spread.spreadOut = on or nil
    spread.gridCards = spread.gridCards or {}
    for _, card in ipairs(spread.gridCards) do card:Hide() end
    spread.gather:SetShown(on == true)
    if not on or #rest == 0 then return end
    -- Over the fan, a card of it lifted too.
    local base = (spread.fanTop or spread.cardTable:GetFrameLevel()) + CARD.raise + 20
    spread.gather:SetFrameLevel(base - 5)
    local n = #rest
    local cols = math.max(1, math.ceil(math.sqrt(n * 1.6)))
    local rows = math.ceil(n / cols)
    -- (A row as deep as the deepest slip under a card in it.)
    local tail = 0
    for _, p in ipairs(rest) do tail = math.max(tail, DungeonPage.CardTail(p)) end
    local gw, gh = CARD.w + DECK.gap, CARD.h + DECK.gap + tail
    local scale = math.min(1, view.w * DECK.fill / (cols * gw), view.h * DECK.fill / (rows * gh))
    spread.gridScale = scale
    local X0, Y0 = view.K.Screen(view.w / 2, view.h / 2)
    for i, p in ipairs(rest) do
        local card = spread.gridCards[i]
        if not card then
            card = NewCard(spread.cardTable)
            card.Draw = Draw
            spread.gridCards[i] = card
        end
        local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
        local cx = X0 / scale + (c - (cols - 1) / 2) * gw
        local cy = -Y0 / scale + (r - (rows - 1) / 2) * gh
        card:SetScale(scale)
        card.scaleK = scale
        -- On the sheet: no shadow on the world.
        card.height = nil
        card:SetLevel(base + i)
        Lay(card, p, cx, cy, 0)
    end
end
