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
local Capital, List, MapName, NUMBER = Text.Capital, Text.List, Text.MapName, Text.NUMBER

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
        if not last then return who and ("duelled " .. who) or "a duel" end
        if last == "won" then return who and ("beat " .. who .. " in a duel") or "won a duel" end
        if last == "they_fled" then return (who or "they") .. " fled the duel" end
        if last == "fled" then return who and ("fled a duel with " .. who) or "fled a duel" end
        return who and ("lost a duel to " .. who) or "lost a duel"
    end
    if up == down then return who and (up .. " each with " .. who) or (up .. " duels each") end
    local lead, rest = up, down
    if balance == "lost" then lead, rest = down, up end
    if rest == 0 then
        local Times = ns.UI.Format.Times
        if balance == "won" then return who and ("beat " .. who .. " " .. Times(lead)) or ("won " .. lead .. " duels") end
        return who and ("lost to " .. who .. " " .. Times(lead)) or ("lost " .. lead .. " duels")
    end
    local score = lead .. " to " .. rest
    if balance == "won" then return who and ("beat " .. who .. " " .. score) or ("won " .. lead .. " duels to " .. rest) end
    return who and ("lost to " .. who .. " " .. score) or ("lost " .. lead .. " duels to " .. rest)
end

-- A line of a menu, where a spot merges several or one is hidden
-- (Core/Custom.lua's `describe`): the note's words, which tell two apart.
function Duels.Describe(rec)
    return Capital(Duels.Note(rec, true))
end

-- When the series were, and at what level, as every mark's tooltip on the
-- plates ends (the core's Text.Foot and Text.Moments, UI/Journey/Text/
-- Tips.lua): each time, a day said once for the times on it, past four
-- the first to the last, then the levels after a comma, "Today at 12:47
-- and 15:10, level 20", "Today from 12:47 to 19:02, levels 19 to 20".
-- The tames' tooltip says its times the same way, without the level.
local function Foot(ts, lo, hi, now)
    return Text.Foot({ times = ts, levelFrom = lo, levelTo = hi }, now)
end

-- The series with one opponent on a spot as one: their counts added, a
-- single duel's outcome counted where only its latest says it (Single), and
-- `last` the newest series' latest, so Duels.Score and Duels.Note read it as
-- they read one series.
local function Together(recs)
    local c = { won = 0, lost = 0, fled = 0, theyFled = 0 }
    local newest
    for _, rec in ipairs(recs) do
        local up = (rec.won or 0) + (rec.theyFled or 0)
        local down = (rec.lost or 0) + (rec.fled or 0)
        if up + down <= 1 then
            local one = Single(rec)
            if one then c[Duels.COUNT[one]] = c[Duels.COUNT[one]] + 1 end
        else
            for key in pairs(c) do c[key] = c[key] + (rec[key] or 0) end
        end
        if not newest or (rec.t or 0) >= (newest.t or 0) then newest = rec end
    end
    c.last = newest and Duels.Latest(newest) or nil
    if c.won + c.lost + c.fled + c.theyFled == 1 then
        for key, count in pairs(Duels.COUNT) do
            if c[count] == 1 then c.last = key end
        end
    end
    c.name, c.guid = newest and newest.name, newest and newest.guid
    return c
end

-- The outcome of a series (or series together): one duel "You won", "You
-- lost", "They fled", "You fled", nothing where a card says no result; more
-- by their balance, "Won 3, lost 1", "Lost 3, won 2", "Won both", "Lost all
-- 3". Figures, as tooltips count.
local ONE = { won = "You won", lost = "You lost", they_fled = "They fled", fled = "You fled" }

local function Outcome(rec)
    local balance, up, down = Duels.Score(rec)
    if up + down <= 1 then return ONE[Single(rec)] end
    local lead, rest = up, down
    if balance == "lost" then lead, rest = down, up end
    local verb, other = balance == "won" and "Won" or "Lost", balance == "won" and "lost" or "won"
    if rest > 0 then return verb .. " " .. lead .. ", " .. other .. " " .. rest end
    return verb .. (lead == 2 and " both" or (" all " .. lead))
end

-- The flag's tooltip: one account of every series on its spot (a list of
-- one for a lone flag), four lines at most. The title names the opponents,
-- "Duelled Bram", "Duelled Bram and Old Tom", "Duelled Bram and others"
-- (those the diary no longer knows), or counts the duels where it knows
-- none, "A duel", "4 duels". Then the outcome first: with one opponent all
-- their series added up (Outcome: "Won 3, lost 1"); with several, the
-- note's words for each, "Beat Bram 2 to 1, lost a duel to Old Tom". The
-- flights on a line of their own, "They fled once", "You fled once, they
-- fled twice"; where ("In Raptor Grounds", each place once, only a subzone
-- that is not its zone's name); then when and at what level. (9 Nov: a
-- rematch on the same spot told "Duelled Bram" and its time twice over.)
function Duels.Tips(recs, now)
    local by, order = {}, {}
    local places, seen = {}, {}
    local ts, lo, hi = {}, nil, nil
    local j = ns.Journey.For and ns.Journey.For(ns.ownGUID)
    for _, rec in ipairs(recs) do
        local who = Duels.Who(rec) or false
        if not by[who] then
            by[who] = {}
            order[#order + 1] = who
        end
        table.insert(by[who], rec)
        local sub = rec.subZone
        if type(sub) == "string" and sub ~= "" and sub ~= MapName(rec.mapID) and not seen[sub] then
            seen[sub] = true
            places[#places + 1] = sub
        end
        ts[#ts + 1] = rec.t or 0
        local level = j and ns.JourneyRecap and ns.JourneyRecap.LevelAt(j, rec.t or 0) or nil
        if level then
            lo = (not lo or level < lo) and level or lo
            hi = (not hi or level > hi) and level or hi
        end
    end
    -- The known opponents first, in the order met; those not known last.
    table.sort(order, function(a, b) return a ~= false and b == false end)
    local all = Together(recs)
    local lines = {}
    local names = {}
    for _, who in ipairs(order) do
        if who then names[#names + 1] = who end
    end
    local title
    if #order == 1 then
        lines[1] = Outcome(Together(by[order[1]]))
        if not order[1] then
            local _, up, down = Duels.Score(all)
            local n = math.max(up + down, #recs)
            title = n <= 1 and "A duel" or (n .. " duels")
        end
    else
        local each = {}
        for _, who in ipairs(order) do each[#each + 1] = Duels.Note(Together(by[who]), who ~= false) end
        lines[1] = Capital(table.concat(each, ", "))
    end
    if not title then
        if by[false] then names[#names + 1] = "others" end
        title = "Duelled " .. List(names)
    end
    local Times = ns.UI.Format.Times
    local flights = {}
    if all.fled > 0 then flights[#flights + 1] = "you fled " .. Times(all.fled) end
    if all.theyFled > 0 then flights[#flights + 1] = "they fled " .. Times(all.theyFled) end
    if #flights > 0 and (all.won + all.lost + all.fled + all.theyFled) > 1 then
        lines[#lines + 1] = Capital(table.concat(flights, ", "))
    end
    if places[1] then lines[#lines + 1] = "In " .. List(places) end
    lines[#lines + 1] = Foot(ts, lo, hi, now)
    return Capital(title), lines
end

-- One series' tooltip, the note's (Slip.lua), as its flag's alone
-- (Duels.Tips).
function Duels.Tip(rec, now)
    return Duels.Tips({ rec }, now)
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
    if n == 0 then return "a duel" end
    if n == 1 then return up == 1 and "a duel won" or "a duel lost" end
    local count = NUMBER[n] or tostring(n)
    if down == 0 then return count .. " duels won" end
    if up == 0 then return count .. " duels lost" end
    if up == down then return "duels won and lost" end
    return up > down and "duels mostly won" or "duels mostly lost"
end

function Duels.Lead(recs, spot)
    return Capital(Duels.Phrase(recs)) .. (spot and (" in " .. spot) or "")
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
