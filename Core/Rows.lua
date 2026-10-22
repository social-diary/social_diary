-- The kinds of People row (ns.db.interactions[guid][i].type), each told
-- once, here or by the feature that writes it, rather than in a list in
-- every file that treats one kind apart.
--
-- Rows.Register(type, spec) declares a kind or adds to one: the core says
-- how a row of it counts, the ledger (UI/Words/Timeline.lua) how it reads,
-- each in its own call, so a feature's folder can do both. Every field is
-- optional, and a kind nobody declared is still stored and shown, as the
-- fallbacks below say.
--
--   chat        it carries chat text: its excerpt is kept only while chat
--               storage is on, and trimmed to the chat lines setting
--               (Core/Interactions.lua)
--   observed    something the user saw of them, not an exchange: it does not
--               count as an interaction on record, nor make them someone
--               just dealt with (Interactions.Count, Since; the picker)
--   proximity   they were within earshot or arm's reach, so a live row is
--               also "last seen" (Characters.Seen)
--   opens       a live row with a diary entry opens a "nearby" together
--               session (Sessions.Note); any other kind only joins an open one
--   structural  the bones of a session, not a highlight of it
--               (Sessions.Highlights)
--   meeting     a row outside any session that counts as meeting them
--               (People: times met, last met, the zones)
--   dealt       the mark it leaves on Recently nearby's day ("together",
--               "trade" or "talk", Rows.DEALT; Sightings, DEALT_RANK)
--   matters     the first one makes a person matter, so their first
--               sighting shows in hindsight (Core/JourneyRecap.lua, JRN-23)
--   activity    the timeline's activity ("chat", "group", "trade", ...,
--               Timeline's RANK); none, and it cannot make an exchange alone
--   moment      function(row): true when it is a line of its own on the
--               timeline
--   climb       its lines one after another, with nothing between them,
--               fold into one (a "climb", Core/Timeline.lua's Climbs), each
--               its own line again when opened; its rows carry context
--               { from, level }, which the climb's words read ("went from
--               level 1 to 6", UI/Words/Timeline.lua)
--   fight       "kill" (they died to the user or their group) or "death"
--               (they killed the user): a fight with the player the row is
--               on, written at the fight's own time, as the user's route
--               marks it (Core/Journey.lua: FightIndex finds the stranger
--               a fight mark was with by that time) and as the score with
--               them counts it (Interactions.Fights); a kill's context.by
--               is the group member who landed the blow, none when it was
--               the user's own
--   witness     "watched" (they looked on as the user died) or "helped"
--               (they fought the user's foes, in a fight the user died in
--               or survived): a stranger who was there at one of the
--               user's deaths or close calls, written at that moment's own
--               time, so the plates find a moment's witnesses by it
--               (Core/Journey.lua's WitnessIndex: every such row, by time);
--               context.watched is a watcher's seconds, context.pct a
--               rescue's health left, and { npcID, name, rank } the
--               creature, where known
--   plate       its rank for the plate on the person's page, lower first
--               (Core/PersonPlate.lua: Your Diary's ranks where the kinds
--               meet); without one, PersonPlate.LAST; false, never weighed
--   hidden      never shown on the timeline
--   reason      why the picker offers someone whose latest row it is ("they
--               saved you"); without one, "recent <type>"
--   text        function(row, guid): its line on the timeline; without one,
--               the type itself
--   icon        its Style.ART key on the timeline; without one, no icon
--
-- Unknown kinds: activity "other" (chatter, "N other interactions"), not a
-- moment, no excerpt, nothing else.

local addonName, ns = ...

local Rows = {}
ns.Rows = Rows

local KINDS = {}
local NONE = {}

-- The marks a kind's `dealt` may leave: Recently nearby ranks them
-- (Core/Sightings.lua's DEALT_RANK) and words them (UI/Journal/Nearby.lua's
-- DEALT_TEXT), so a new one is added in all three places.
Rows.DEALT = { together = true, trade = true, talk = true }

-- Declares `kind`, or adds `spec`'s fields to it. Returns the kind's table.
function Rows.Register(kind, spec)
    assert(type(kind) == "string", "a row kind is a string")
    assert(not (spec and spec.dealt) or Rows.DEALT[spec.dealt],
        "a row kind's `dealt` is one of Rows.DEALT (together, trade, talk)")
    local k = KINDS[kind]
    if not k then
        k = { type = kind }
        KINDS[kind] = k
    end
    for key, value in pairs(spec or {}) do k[key] = value end
    return k
end

-- The kind's table, or an empty one for a kind nobody declared.
function Rows.Get(kind)
    return KINDS[kind] or NONE
end

-- Every declared kind's name, sorted (for the tests).
function Rows.All()
    local list = {}
    for kind in pairs(KINDS) do list[#list + 1] = kind end
    table.sort(list)
    return list
end

--------------------------------------------------------------------------
-- The kinds the diary has always had
--------------------------------------------------------------------------
--
-- Their words and icons are UI/Words/Timeline.lua's. A feature in
-- Features/<Name>/ declares its kind whole there, words and icon included
-- (its Kind.lua; .claude/skills/new-feature/folder.md).

Rows.Register("group_join", { structural = true, meeting = true, dealt = "together", matters = true,
    activity = "group", plate = 8 })
-- Implied by the session's end, so never a line.
Rows.Register("group_leave", { structural = true, hidden = true })
