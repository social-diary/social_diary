-- Someone you met, as the player tells it (.claude/features/custom-cards.md): a
-- person's strip in the margin, with no session, fight or note behind it. Only
-- ever written by hand, so it has no capture.
--
--   Kind.lua     the moment, who the card names, and the form's fields
--   Text.lua     its words: the name on the strip, the mark's tooltip, and the
--                caption's for someone left out of the margin
--   Mark.lua     its mark: the core's ring for time together, drawn as is
--   Strip.lua    its note in the margin, a person's strip from their pool
--
-- What stays core: an automatic person's strip (UI/Journey/Margin.lua's
-- MarginNote, from sessions, fights and notes), and the strip itself. This
-- kind writes no session, no People row and no interaction, so the person's
-- page, the level's prose and the route's counts never hear of it: the card is
-- the player's word about one place on one map, and nothing more. Forgetting
-- someone is the custom list's (Core/Custom.lua's Forget): the link goes and
-- the name as written stays.

local addonName, ns = ...

local Met = {}
ns.Met = Met

-- The diary entry a card links to, where the character is still known; nil for
-- a name only typed, or one forgotten since. An entry taken out of the diary
-- afterwards stays linked, as an automatic strip's does: going back to pencil
-- is not being forgotten, and their page still opens.
function Met.Guid(rec)
    local guid = rec.whoGuid
    return guid and ns.db.characters[guid] ~= nil and guid or nil
end

-- The moment: only ever inserted, so there is nothing to gather; Gather makes
-- the entry's list and adds the player's cards to it. It ranks with the
-- people, whom it stands for; being custom, it outranks them anyway (Recap's
-- Rank), so the rank is only what tests/kinds.lua and a reader ask of a kind.
-- Not light: it has a note in the margin, so its plate needs a full slot.
ns.JourneyRecap.RegisterMoment("met", { order = 85, entry = "met", field = "met", rank = 1,
    gather = function() end,
    custom = {
        label = "Someone You Met",
        heading = "Someone you met",
        group = "social",
        -- A menu's line, where a spot merges several: the name alone will not
        -- tell apart two meetings with one person.
        describe = function(rec)
            local name = Met.Name(rec) or "Someone you met"
            return rec.what and (name .. ", " .. rec.what) or name
        end,
        -- Only these: the strip shows a name and a line of what happened. Both
        -- may stay empty, a stranger's strip being "with someone" already. The
        -- line's length is the base's: three lines of a strip hold about that,
        -- and what its narrowest column cuts the tooltip keeps (Strip.lua).
        fields = {
            { key = "who", type = "person", label = "Who", hint = "Someone in your diary, or any name" },
            { key = "what", type = "text", label = "Together", hint = "What you did, in a line" },
        },
    } })
