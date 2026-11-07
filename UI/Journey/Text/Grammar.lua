-- Your Diary's words (JRN-11 to JRN-14, JRN-21 to JRN-26): what each recap
-- entry says, the plates' captions and margin notes, the first sightings in
-- hindsight, the zone lines, and the plates' tooltips.
--
-- Pure functions over Core/JourneyRecap.lua's entries, no frames: the page
-- (UI/Journey/Page.lua) and the plates (UI/Journey/Plate.lua) lay them out.
-- The journal's voice, as the profile and the timeline speak it: prose,
-- relative dates, quiet. It recaps where you went and who you were with; it
-- never counts quests or keeps a score.
--
-- The words are one module, ns.UI.JourneyText (aliased `Text` by its
-- readers), in a file per question, each loaded after the one before it
-- (the TOC's order) and putting its words on the module as it loads:
--   UI/Journey/Text/Grammar.lua  this file: the module, and how a name, a
--                                place, a count and a plural are written
--   UI/Journey/Text/Time.lua     how a time is written: Duration, Spoken, a
--                                day, a tooltip's "when"
--   UI/Journey/Text/Notes.lua    the player's own words: cleaned (Written),
--                                cut, quoted on a level and in the margin
--   UI/Journey/Text/Prose.lua    an entry's prose: the prologue, the title,
--                                the paragraphs and their registry
--                                (Text.RegisterLines), the hindsight line
--   UI/Journey/Text/Zones.lua    the zone index's lines and a full page's foot
--   UI/Journey/Text/Tips.lua     the sheet's labels and tooltips: meetings,
--                                stops, pins, dungeons, flights, faces, pools
--   UI/Journey/Text/Caption.lua  a plate's heading and words, and their
--                                registry (Text.RegisterCaption)
--   UI/Journey/Text/Margin.lua   what a person's margin note says
--
-- Its readers: Your Diary's page (UI/Journey/Left.lua, Caption.lua,
-- Margin.lua, ...: UI/Journey/Look.lua lists them) and
-- Features/<Name>/Text.lua load after these files and take what they need as they load; UI/Ink/Trail.lua,
-- UI/Journey/Plate.lua and UI/Words/Timeline.lua load before them and look
-- the words up when they draw. A sibling takes its helpers from the module
-- as it loads (`local Capital = Text.Capital`), so it loads after the file
-- that writes them.

local addonName, ns = ...

local Text = {}
ns.UI.JourneyText = Text

local List = ns.UI.Format.List
local L, Fmt = ns.L, ns.Fmt
-- A locale's own grammar (Locales/Locale.lua): Plural, ItemWord, KillerName
-- and Capital, where a locale has replaced them.
local G = ns.Locale.grammar

-- How a time is written in Your Diary's words: the number held to its
-- unit by a no-break space (UTF-8 `nbsp`), so "55 min" never breaks across
-- two lines as "55" and "min". `keep` is the one switch: off, plain
-- spaces again, should the client's fonts draw no glyph for it or its
-- wrapping not honour it (to check in the client).
local SPACE = { keep = true, nbsp = "\194\160" }

local function Glue(text)
    if not SPACE.keep then return text end
    return (text:gsub(" ", SPACE.nbsp))
end

local function Capital(text)
    if G.Capital then return G.Capital(text) end
    return text:sub(1, 1):upper() .. text:sub(2)
end

-- A rubric's capitals ("LEVEL 12", "WEEK OF 6 OCTOBER"): string.upper
-- leaves UTF-8 letters alone, so a locale may give its own
-- (G.JourneyUpper: German's umlauts).
local function Upper(text)
    if G.JourneyUpper then return G.JourneyUpper(text) end
    return text:upper()
end

local function MapName(mapID)
    return mapID and ns.MapName(mapID) or nil
end

local function Who(guid)
    return guid and (ns.Characters.FullName(guid) or ns.Characters.Name(guid)) or nil
end

-- A place: "Lushwater Oasis, The Barrens", or the zone alone.
local function Place(mapID, subZone)
    local zone = MapName(mapID)
    if subZone and zone and subZone ~= zone then return Fmt(L["%1$s, %2$s"], subZone, zone) end
    return subZone or zone
end
Text.Place = Place

-- A person's short name for a margin note or a line: their first name.
local function Short(guid)
    local first = guid and ns.Characters.Name(guid)
    return first or Who(guid)
end
Text.Short = Short

--------------------------------------------------------------------------
-- Counts, plurals and items (shared helpers, exported below)
--------------------------------------------------------------------------

local NUMBER = { L["a##one"], L["two"], L["three"], L["four"], L["five"] }

-- `many` a template whose %s takes "twice", "3 times".
local function Times(n, one, many)
    if n == 1 then return one end
    if n == 2 then return many:format(L["twice"]) end
    return many:format(Fmt(L["%d times"], n))
end

-- A close call's health left (JRN-25), held together: "6% health".
local function Health(call)
    return Glue(Fmt(L["%d%% health"], call.pct or 0))
end

-- A number held to the word after it, as a time is ("31 Plainstriders"
-- never breaks after the 31); the rest of the words may wrap.
local function Count(n, words)
    return tostring(n) .. (SPACE.keep and SPACE.nbsp or " ") .. words
end

-- A creature's name for more than one: "Plainstriders", "Timber Wolves",
-- "Defias Highwaymen", "Harpies"; "Servants of Grol" when the name has an
-- "of". Only the last word changes. A few kinds are their own plural.
local SAME = { sheep = true, deer = true, fish = true, moose = true }
local IRREGULAR = { tooth = "teeth", foot = "feet", mouse = "mice", louse = "lice", ox = "oxen", child = "children",
    shaman = "shamans", human = "humans", talisman = "talismans", chief = "chiefs" }
local PLURAL = { { "ief$", "ieves" }, { "([lr])f$", "%1ves" }, { "fe$", "ves" }, { "man$", "men" },
    { "([^aeiouAEIOU])y$", "%1ies" }, { "([sxz])$", "%1es" }, { "([cs]h)$", "%1es" } }

local function Plural(name)
    if G.Plural then return G.Plural(name) end
    local head, tail = name:match("^(.-)( of .+)$")
    if head then return Plural(head) .. tail end
    local word = name:match("(%a+)$") or ""
    local lower = word:lower()
    if SAME[lower] then return name end
    local odd = IRREGULAR[lower]
    if odd then
        if word:sub(1, 1) ~= lower:sub(1, 1) then odd = Capital(odd) end
        return name:sub(1, #name - #word) .. odd
    end
    for _, rule in ipairs(PLURAL) do
        local out, n = name:gsub(rule[1], rule[2])
        if n > 0 then return out end
    end
    return name .. "s"
end
Text.Plural = Plural

-- An item's name for more than one: "Intact Raptor Horns", but never
-- "Plainstrider Meats": what is not counted keeps its name (MASS, by its
-- last word, or a word it ends in), and so does a name already plural.
local MASS = { meat = true, flesh = true, blood = true, ichor = true, silk = true, cloth = true, leather = true,
    venom = true, dust = true, ore = true, wool = true, hair = true, fur = true, essence = true, oil = true,
    water = true, sand = true, ash = true, moss = true, slime = true, dirt = true, mud = true, powder = true,
    gunpowder = true, pollen = true, ink = true, fat = true, bark = true, bile = true, sap = true, silt = true,
    honey = true, grain = true, ectoplasm = true, residue = true, jerky = true, wood = true }
local MASS_ENDS = { "weed", "cloth", "meat", "silk", "dust", "moss", "wood" }

local function ItemWord(n, item)
    if G.ItemWord then return G.ItemWord(n, item) end
    if n == 1 then return item end
    local last = (item:match("(%a+)$") or ""):lower()
    local mass = MASS[last] or (last:sub(-1) == "s" and last:sub(-2) ~= "ss")
    for _, e in ipairs(MASS_ENDS) do mass = mass or last:sub(-#e) == e end
    return mass and item or Plural(item)
end

local function Items(n, item)
    if n == 1 then return Count(L["one"], item) end
    return Count(n, ItemWord(n, item))
end

-- A killer's name in a sentence: "a Sunscale Lashtail", "an Ornery
-- Plainstrider"; a rare or a boss is most often one of a kind, named
-- ("Hogger", "The Rake"), so it goes bare, as does a name that brings its
-- own article. `bare`: the player said it goes bare (a custom card's choice).
function Text.KillerName(k)
    local name = k and k.name
    if not name or name == "" then return nil end
    if G.KillerName then return G.KillerName(k) end
    if k.bare or name:find("^[Tt]he ") or k.rank == "rare" or k.rank == "rareelite" or k.rank == "worldboss" then
        return name
    end
    return (name:find("^[AEIOUaeiou]") and "an " or "a ") .. name
end

--------------------------------------------------------------------------
-- The words every kind shares
--------------------------------------------------------------------------

-- What a kind's own words (its card's, its mark's tooltip, its caption
-- words) are written with, on Text, so its section can move to its
-- feature's file (Features/<Name>/, .claude/skills/new-feature/folder.md) as it
-- is, its helpers taken from here (`local When, Capital = Text.When,
-- Text.Capital`) instead of from these files' locals:
--   Glue(text)            its spaces no-break (SPACE), so it never wraps
--   Duration(seconds)     "1 h 33 min", glued
--   Spoken(seconds)       "twenty minutes", "an hour and a half"
--   Capital(text)         its first letter capitalised
--   MapName(mapID)        a map's name, or nil
--   Who(guid)             a character's full name, else their name
--   Short(guid)           their first name (a margin note's)
--   Day(t, now)           "6 October", the year once it is not this one's
--   When(t, level, now)   "Yesterday, 21:40, at level 12": a tooltip's last line
--   Place(mapID, subZone) "Lushwater Oasis, The Barrens"
--   Times(n, one, many)   "Died here", "Died here twice", "... 3 times"
--   NUMBER, WORDS         counts in words: NUMBER[n] "a", "two" ... "five";
--                         WORDS[n] "two" ... "twelve", "fifteen", "twenty", ...
--   Count(n, words)       a figure held to its noun ("31 Plainstriders")
--   Plural(name)          a creature's name for more than one
--   ItemWord(n, item)     an item's name for `n` of it ("Plainstrider Meat")
--   Items(n, item)        "one Hezrul's Head", "7 Plainstrider Meat"
--   Health(call)          "6% health", glued
--   Written(text)         the player's words, escapes taken out
--   List(items, opts)     "A, B and 2 others" (ns.UI.Format.List)
-- Each is set where it is written: Duration, Spoken, WORDS, Day and When
-- by UI/Journey/Text/Time.lua, Written by UI/Journey/Text/Notes.lua, the
-- rest here.
Text.Glue, Text.Capital, Text.MapName, Text.Who = Glue, Capital, MapName, Who
Text.Upper = Upper
Text.Times, Text.NUMBER, Text.Count, Text.ItemWord, Text.Items = Times, NUMBER, Count, ItemWord, Items
Text.Health = Health
Text.List = List
