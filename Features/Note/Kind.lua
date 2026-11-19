-- The free card (.claude/features/note-card.md): a card of the player's own
-- making, on a spot of their map: an icon, a few lines, the people who were
-- there, and if they like a creature and an item. Only ever written by hand,
-- so it has no capture. "Someone you met" folded into it (19 Nov 2026): a
-- saved `met` card is one of these with the meeting's icon (Core/DB.lua's
-- diary step 6).
--
--   Icons.lua    the sixteen icons, drawn with the house pen and watercolour
--                (ns.NoteIcons: KEYS, the first the default; Draw)
--   Kind.lua     the moment, who the card names, and the form's fields
--   Text.lua     its words: the strip's top line, the mark's tooltip, the
--                ticklist's row, the menu's line, and where the player
--                asked for it (`caption`, off by default) a sentence in the
--                level's prose on the left page and the caption's names
--   Mark.lua     its mark: the chosen icon
--   Card.lua     its card in the margin: the killer card worn with a face of
--                its own (the icon, who, the item, the player's words), as
--                the close call's is (loads after Features/Deaths/ and
--                Features/CloseCalls/)
--
-- The moment kind is `noteCard`, not `note`: a person's diary note is already
-- a moment of that name on every plate (Core/JourneyRecap.lua's people, RANK,
-- the plate's people marks, the caption's company), and the two would read
-- each other's records.
--
-- What stays core: the strip itself and the people's own strips. This kind
-- writes no session, no People row and no interaction, so the person's page,
-- the level's prose and the route's counts never hear of it. Forgetting
-- someone is the custom list's (Core/Custom.lua's Forget): the link goes and
-- the name as written stays.
--
-- A card: { kind = "noteCard", t, mapID, x, y, level, icon, text, people =
-- { { name, guid }, ... }, mob, npcID, display, item, itemID, caption }; all
-- but the icon may be absent.

local addonName, ns = ...

local L = ns.L

local Note = {}
ns.Note = Note

Note.KIND = "noteCard"

-- The diary entry a person on the card links to, where the character is still
-- known; nil for a name only typed, or one forgotten since. An entry taken out
-- of the diary afterwards stays linked, as an automatic strip's does.
function Note.Guid(p)
    local guid = type(p) == "table" and p.guid or nil
    return guid and ns.db.characters[guid] ~= nil and guid or nil
end

-- The people on a card, as a list (none: empty).
function Note.People(rec)
    return type(rec.people) == "table" and rec.people or {}
end

-- The first person on the card with a link: where its strip's name goes.
function Note.FirstGuid(rec)
    for _, p in ipairs(Note.People(rec)) do
        local guid = Note.Guid(p)
        if guid then return guid end
    end
    return nil
end

-- The moment: only ever inserted, so there is nothing to gather; Gather makes
-- the entry's list and adds the player's cards to it. It ranks with the
-- people, as "Someone you met" did; being custom, it outranks them anyway
-- (Recap's Rank). Not light: it has a note in the margin, so its plate needs
-- a full slot.
ns.JourneyRecap.RegisterMoment(Note.KIND, { order = 85, entry = "noteCard", field = "noteCard", rank = 1,
    gather = function() end,
    custom = {
        label = L["Note##card"],
        heading = L["A note"],
        group = "other",
        -- A menu's line, where a spot merges several (Text.lua).
        describe = function(rec) return Note.Describe(rec) end,
        -- A typed creature's name brings its picture, where this character's
        -- records know it.
        creature = "mob",
        defaults = {},
        -- The form's rows in three groups (`group`, CardSheet's BEAT: close
        -- within one, a faint rule and more air between two): what it is
        -- (the icon, the words), who and what with (the people, the
        -- creature, the item), and how it goes on the page (the caption).
        fields = {
            { key = "icon", type = "icon", label = L["Icon"], group = "what" },
            { key = "text", type = "text", most = 150, lines = 3, label = L["Words"],
                hint = L["What happened here"], group = "what" },
            { key = "people", type = "people", label = L["Who was there"],
                hint = L["Any name will do"], group = "who" },
            { key = "mob", type = "text", optional = true, label = L["Creature"], hint = L["As the game names it"],
                add = L["+ A creature"], group = "who" },
            { key = "item", type = "item", id = "itemID", optional = true, label = L["Item"],
                hint = L["Shift-click an item"], add = L["+ An item"], group = "who" },
            { key = "caption", type = "flag", label = L["Write it into the entry"], group = "page" },
        },
        -- The card as it will look, beside the form while it is written
        -- (CardSheet's preview): the margin's own card, written by its own
        -- face from what the form holds (Features/Note/Card.lua's Preview).
        preview = {
            new = function(parent) return ns.Deaths.Card.New(parent) end,
            write = function(card, rec, now) return Note.Card.Preview(card, rec, now) end,
        },
    } })
