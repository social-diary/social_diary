-- Duels' words on Your Diary's plates: the margin note's (one line in the
-- hand, S, words only), the flag's and the note's tooltip, and the
-- caption's words where the note found no room. Copy changes go through
-- the copywriter skill, as every player-read word does.
--
-- The flag is the same for a duel won or lost (the user, 15 Oct), so these
-- words are where won and lost are told: each leads with the outcome. No
-- sentence on the left page (the user, 15 Oct), so no Text.RegisterLines;
-- the caption's words are registered at the foot (Text.RegisterCaption).

local addonName, ns = ...

local Duels = ns.Duels
local Text = ns.UI.JourneyText
local Capital, MapName, NUMBER, When = Text.Capital, Text.MapName, Text.NUMBER, Text.When
local L, Fmt = ns.L, ns.Fmt

-- The opponent of a series on the route (Kind.lua's records): the name the
-- player wrote on the card, which only a custom one has (Core/Custom.lua), or
-- else read from the diary by `guid` (the route keeps no names), or nil: not
-- read, let go of, or forgotten. The written name stays once they are
-- forgotten: it is the player's own words.
function Duels.Who(rec)
    if not rec then return nil end
    if rec.name then return rec.name end
    return rec.guid and ns.Characters.Name(rec.guid) or nil
end

-- A series' counts in the words' order: the outcome it leads with
-- (Duels.Balance), then how many it was won and lost by, flights counted
-- with their side. One duel at most goes by its latest (Duels.Latest), and a card
-- with no count at all says no result.
function Duels.Score(rec)
    local up = (rec.won or 0) + (rec.theyFled or 0)
    local down = (rec.lost or 0) + (rec.fled or 0)
    local last = Duels.Latest(rec)
    if up + down <= 1 and Duels.COUNT[last] then
        local won = last == "won" or last == "they_fled"
        return won and "won" or "lost", won and 1 or 0, won and 0 or 1
    end
    return Duels.Balance(rec), up, down
end

-- A single duel's outcome (one of Duels.COUNT's keys): its latest, or read
-- off its counts where that wasn't kept. Nil where nothing says, as on a card
-- the player left blank: it is not for the diary to call that a loss.
local function Single(rec)
    local latest = Duels.Latest(rec)
    if Duels.COUNT[latest] then return latest end
    if (rec.theyFled or 0) > 0 then return "they_fled" end
    if (rec.fled or 0) > 0 then return "fled" end
    if (rec.won or 0) > 0 then return "won" end
    if (rec.lost or 0) > 0 then return "lost" end
    return nil
end

-- The margin note for the plate's biggest series `rec`: one line, lower
-- case as the hand's notes are, words only, the outcome first (the flag
-- is the same for both). `named` false gives the form without the
-- opponent's name, for a long name that won't fit the box, and for an
-- opponent the diary no longer knows.
--
-- One duel: "beat Bram in a duel", "lost a duel to Bram", "Bram fled the
-- duel", "fled a duel with Bram"; nameless "won a duel", "lost a duel",
-- "they fled the duel", "fled a duel". A series by its balance, flights
-- counted with their side: "beat Bram 3 to 1", "lost to Bram 3 to 2",
-- "beat Bram twice", "lost to Bram 3 times", "2 each with Bram"; nameless
-- "won 3 duels to 1", "lost 3 duels to 2", "won 2 duels", "2 duels each".
-- A card the player left without a result: "duelled Bram", nameless "a duel".
-- Figures, as a score is written and as the margin's ledger counts
-- ("killed you twice"): measured in the hand at 14 px (Neuton Italic,
-- 15 Oct), "three to one" in words put "won three duels to two" a pixel
-- past the narrowest box (122 px less the slip's pad, 107), where every
-- form here with "Bram" fits (at most 104 px; "lost to Bram 12 times"
-- 106) and every nameless one has 15 px to spare.
function Duels.Note(rec, named)
    local balance, up, down = Duels.Score(rec)
    local who = named ~= false and Duels.Who(rec) or nil
    if up + down <= 1 then
        local last = Single(rec)
        if not last then return who and Fmt(L["duelled %s"], who) or L["a duel"] end
        if last == "won" then return who and Fmt(L["beat %s in a duel"], who) or L["won a duel"] end
        if last == "they_fled" then return who and Fmt(L["%s fled the duel"], who) or L["they fled the duel"] end
        if last == "fled" then return who and Fmt(L["fled a duel with %s"], who) or L["fled a duel"] end
        return who and Fmt(L["lost a duel to %s"], who) or L["lost a duel"]
    end
    if up == down then return who and Fmt(L["%1$d each with %2$s"], up, who) or Fmt(L["%d duels each"], up) end
    local lead, rest = up, down
    if balance == "lost" then lead, rest = down, up end
    if rest == 0 then
        local Times = ns.UI.Format.Times
        if balance == "won" then return who and Fmt(L["beat %1$s %2$s"], who, Times(lead)) or Fmt(L["won %d duels"], lead) end
        return who and Fmt(L["lost to %1$s %2$s"], who, Times(lead)) or Fmt(L["lost %d duels"], lead)
    end
    if balance == "won" then
        return who and Fmt(L["beat %1$s %2$d to %3$d"], who, lead, rest) or Fmt(L["won %1$d duels to %2$d"], lead, rest)
    end
    return who and Fmt(L["lost to %1$s %2$d to %3$d"], who, lead, rest) or Fmt(L["lost %1$d duels to %2$d"], lead, rest)
end

-- A line of a menu, where a spot merges several or one is hidden
-- (Core/Custom.lua's `describe`): the note's words, which tell two apart.
function Duels.Describe(rec)
    return Capital(Duels.Note(rec, true))
end

-- The flag's and the note's tooltip: a title, and lines under it (where,
-- when, as the campfire's: Campfire.Tip). The title names the opponent,
-- "Duelled Bram", or counts the duels where the diary no longer knows
-- them, "A duel", "4 duels". Then the outcome, first: one duel "You won",
-- "You lost", "They fled", "You fled"; a series by its balance, "Won 3,
-- lost 1", "Lost 3, won 2", "Won both", "Lost all 3", and its flights on
-- a line of their own, "They fled once", "You fled once, they fled
-- twice". Figures, as tooltips count.
local ONE = { won = L["You won"], lost = L["You lost"], they_fled = L["They fled"], fled = L["You fled"] }

function Duels.Tip(rec, now)
    local balance, up, down = Duels.Score(rec)
    local who = Duels.Who(rec)
    local total = up + down
    local lines = {}
    if total <= 1 then
        -- Nothing under the title where a card says no result.
        lines[1] = ONE[Single(rec)]
    else
        local lead, rest = up, down
        if balance == "lost" then lead, rest = down, up end
        local won = balance == "won"
        if rest > 0 then
            lines[1] = Fmt(won and L["Won %1$d, lost %2$d"] or L["Lost %1$d, won %2$d"], lead, rest)
        elseif lead == 2 then
            lines[1] = won and L["Won both"] or L["Lost both"]
        else
            lines[1] = Fmt(won and L["Won all %d"] or L["Lost all %d"], lead)
        end
        local Times = ns.UI.Format.Times
        local flights = {}
        if (rec.fled or 0) > 0 then flights[#flights + 1] = Fmt(L["you fled %s"], Times(rec.fled)) end
        if (rec.theyFled or 0) > 0 then flights[#flights + 1] = Fmt(L["they fled %s"], Times(rec.theyFled)) end
        if #flights > 0 then lines[#lines + 1] = Capital(table.concat(flights, L[", "])) end
    end
    local sub = rec.subZone
    if type(sub) == "string" and sub ~= "" and sub ~= MapName(rec.mapID) then lines[#lines + 1] = Fmt(L["In %s"], sub) end
    local j = ns.Journey.For and ns.Journey.For(ns.ownGUID)
    local level = j and ns.JourneyRecap and ns.JourneyRecap.LevelAt(j, rec.t or 0) or nil
    lines[#lines + 1] = When(rec.t or 0, level, now)
    local title = who and Fmt(L["Duelled %s"], who) or (total <= 1 and L["A duel"] or Fmt(L["%d duels"], total))
    return Capital(title), lines
end

-- The caption's words for a plate's series (`recs`, oldest first), where
-- the note found no room: as short as the campfire's beside them (FL's
-- print has two lines for its words), and dropped rather than run past
-- the page's foot. Every duel on the plate together, flights with their
-- side; nameless, as the caption names nobody a strip may name.
--
-- `Phrase` ends a list of the plate's other kinds (the campfire's ", and
-- a campfire"): "a duel won", "a duel lost", "two duels won", "three
-- duels lost", "duels mostly won", "duels mostly lost", and level, "duels
-- won and lost". `Lead` opens the words where nothing else does, the
-- same words and where (`spot`, the subzone they share, or nil): "A duel
-- won in Sentinel Hill", "Duels mostly lost in Sentinel Hill".
function Duels.Phrase(recs)
    local up, down = 0, 0
    for _, rec in ipairs(recs) do
        local _, u, d = Duels.Score(rec)
        up, down = up + u, down + d
    end
    local n = up + down
    if n == 0 then return L["a duel"] end
    if n == 1 then return up == 1 and L["a duel won"] or L["a duel lost"] end
    local count = NUMBER[n] or tostring(n)
    if down == 0 then return Fmt(L["%s duels won"], count) end
    if up == 0 then return Fmt(L["%s duels lost"], count) end
    if up == down then return L["duels won and lost"] end
    return up > down and L["duels mostly won"] or L["duels mostly lost"]
end

function Duels.Lead(recs, spot)
    local phrase = Capital(Duels.Phrase(recs))
    return spot and Fmt(L["%1$s in %2$s"], phrase, spot) or phrase
end

-- The subzone a plate's series (route records) all started in, or nil
-- where they differ, where one has none, or where it is only the zone's
-- own name (`zone`): the campfire's rule (Features/Campfire/Text.lua's
-- Campfire.At).
local function Spot(recs, zone)
    local at
    for _, rec in ipairs(recs) do
        local sub = rec.subZone
        if type(sub) ~= "string" or sub == "" or (at and sub ~= at) then return nil end
        at = sub
    end
    if at == zone then return nil end
    return at
end

-- The caption's words (Text.RegisterCaption, UI/Journey/Text/Caption.lua).
-- `said.duel` (true): the plate's note (Slip.lua) found no room, in the
-- margin nor on the print, so the words say it, after every other kind
-- but the campfire (", a duel won, and a campfire"), or lead where nothing
-- else does ("A duel won in Raptor Grounds"). With the note beside the
-- plate or on its print the words say nothing of it, but where the duels
-- are all there is they name their place ("Raptor Grounds.") for the note
-- to finish, as the campfire's do. Filler: where saying it would run the
-- words past their foot, the page leaves it out and the flag alone tells
-- it (plate.duelTold false, Slip.lua's `flag`).
--
-- Its lead (`at` 135) comes after the company (130), before a campfire
-- (140): a duel names a person, a fire nobody; its tail (`at` 85) after
-- good luck's (70), before the campfire's (90), in the margin's order.
Text.RegisterCaption("duel", {
    moment = "duel",
    take = function(m) return m.duel end,
    lead = { at = 135, say = function(recs, c)
        local spot = Spot(recs, MapName(c.plate.mapID))
        if c.said.duel then return Duels.Lead(recs, spot) end
        return spot
    end },
    tail = { at = 85, say = function(recs, c) return c.said.duel and Duels.Phrase(recs) or nil end },
})
