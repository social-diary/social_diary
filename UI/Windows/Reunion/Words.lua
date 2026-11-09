-- What a reunion toast says (ns.UI.ReunionText): the heading by what
-- brought them, the warning for a foe or someone to avoid, who they are,
-- and the last meeting or a foe's score in a sentence, each longest first
-- for the card to take the first that fits. And the snapshot it is said
-- from (ns.UI.Toast.Snapshot), taken at the moment of the join. The card
-- that lays these words out is UI/Windows/Reunion/Toast.lua, which also
-- lists the module's shared state; the queue is Queue.lua's.

local addonName, ns = ...

local Format = ns.UI.Format

local Style = ns.Style
local Toast = ns.UI.Toast

-- The heading, rubricated like a day on the timeline, by what brought them.
local HEADINGS = {
    group = "Joined your group",
    nearby = "Nearby",
    mixed = "Nearby and in your group",
}
-- The last card of a flood goes on from "AND 3 MORE".
local MORE = {
    group = "from your diary joined your group too.",
    nearby = "from your diary are nearby too.",
    mixed = "from your diary are about too.",
}
-- A warning: someone tagged foe or avoid. Their card says so in its
-- heading, its paraph is red (lapis on the others), and a double rule is
-- inked round it in red, like a notice: never colour alone. The tags in
-- the order they matter: in the group, the person to avoid; nearby, the foe.
local WARNINGS = {
    foe = { group = "A foe joined your group", nearby = "A foe, nearby" },
    avoid = { group = "Someone to avoid joined your group", nearby = "Someone to avoid, nearby" },
}
local WARNING_ORDER = { group = { "avoid", "foe" }, nearby = { "foe", "avoid" } }

--------------------------------------------------------------------------
-- Content
--------------------------------------------------------------------------

-- Taken at the moment of the join, from the stats as they were before it.
local function Snapshot(guid, reason)
    local s = ns.People.Stats(guid)
    if not s then return nil end

    local tags = {}
    for i, tag in ipairs(s.entry.tags) do tags[i] = tag end

    return {
        guid = guid,
        reason = reason,
        name = s.name,
        record = s.record,
        guild = s.entry.guildAtAdd,
        tags = tags,
        relationship = s.entry.relationship,
        lastMet = s.lastMet,
        lastZone = s.lastZone,
        timesMet = s.timesMet,
        fights = ns.Interactions.Fights(guid),
    }
end
Toast.Snapshot = Snapshot

-- A word at a time: the story is wrapped by hand into separate lines, and
-- a colour opened on one line would not carry over to the next.
local function Em(text)
    return (tostring(text):gsub("%S+", function(word)
        return "|cff" .. Style.HEX.accent .. word .. "|r"
    end))
end

-- "3 days ago", but "on 12 Sep 2025".
local function When(time)
    local when = Format.Ago(time)
    if when:match("^%d") and not when:find("ago$") then when = "on " .. when end
    return when
end

-- A foe's card tells the score instead (Interactions.Fights): "You've killed
-- them twice, they've killed you 5 times. Last fight 3 days ago in
-- Hillsbrad Foothills." Longest first, for the card to take the first that
-- fits.
local function FightStories(fights)
    local score = Format.FightsText(fights, Em, true)
    if not score then return { "No blood between you yet." } end
    local last = "Last fight " .. Em(When(fights.last))
    local stories = {}
    if fights.zone then stories[1] = score .. " " .. last .. " in " .. Em(fights.zone) .. "." end
    stories[#stories + 1] = score .. " " .. last .. "."
    stories[#stories + 1] = score
    return stories
end

-- What there is to say about the last meeting, the way the profile says it
-- (UI/Journal/Profile.lua), without the place when `place` is false. Never
-- met: nearby, only that they have been seen so far (no time:
-- Characters.Seen has just moved it to now); in a group, that this is the
-- first time.
local function Story(snap, place)
    if snap.timesMet == 0 then
        if snap.reason == "nearby" then
            return "You've only seen them in passing so far."
        end
        return "Your first time together since you wrote them in."
    end

    local when = When(snap.lastMet)
    local where = place and snap.lastZone and (" in " .. Em(snap.lastZone)) or ""

    if snap.timesMet == 1 then
        return ("You've met once, %s%s."):format(Em(when), where)
    end
    return ("You've crossed paths %s, last %s%s."):format(Em(snap.timesMet .. " times"), Em(when), where)
end

-- The record without some of what it says.
local function Without(record, ...)
    local copy = {}
    for key, value in pairs(record) do copy[key] = value end
    for _, key in ipairs({ ... }) do copy[key] = nil end
    return copy
end

-- Who they are, longest first: with the guild, without it, without the
-- race (the portrait shows it), then the class alone. A foe's faction
-- stays to the last: it matters more on a toast than any guild.
local function Whos(record, guild)
    record = record or {}
    local W = Format.WhoLine
    return {
        W(record, guild, true),
        W(record, nil, true),
        W(Without(record, "race", "raceID"), nil, true),
        W(Without(record, "race", "raceID", "level"), nil, true),
    }
end

-- What the card says, as a table:
--   heading       why it came up
--   name          who, or "and 3 more" at the end of a flood
--   tags          the tags in small capitals, each in its own ink
--   relationship  as the user wrote it
--   who           who they are, for an entry with neither tags nor a
--                 relationship: "Level 12 Tauren Druid  <Guild>", the
--                 faction only when it is not the player's; longest
--                 first, for the card to take the first that fits
--   stories       what to say under them, longest first, for the card to
--                 take the first that fits: the last meeting with its
--                 place and without, or for a foe the score
--   warning       "foe" or "avoid", for the warning card, else nil
function ns.UI.ReunionText(snap)
    -- The sample laid out to be placed: the name line and the story read
    -- on as one sentence, the way "AND 3 MORE" does.
    if snap.place then
        return {
            heading = "Placing the toast",
            name = "Your toasts",
            stories = { "will appear where you leave this card." },
        }
    end
    if snap.more then
        return {
            heading = HEADINGS[snap.reason] or HEADINGS.mixed,
            name = ("and %d more"):format(snap.more),
            stories = { MORE[snap.reason] or MORE.mixed },
        }
    end

    local tags, has = {}, {}
    for i, tag in ipairs(snap.tags or {}) do
        local colour = Style.TAG_COLORS[tag] or Style.TAG_DEFAULT
        tags[i] = "|cff" .. Style.HexOf(colour) .. tag:upper() .. "|r"
        has[tag] = true
    end
    local reason = snap.reason == "nearby" and "nearby" or "group"
    local warning
    for _, tag in ipairs(WARNING_ORDER[reason]) do
        if has[tag] then
            warning = tag
            break
        end
    end

    local text = {
        heading = warning and WARNINGS[warning][reason] or HEADINGS[reason],
        name = snap.name,
        tags = tags[1] and table.concat(tags, ", ") or nil,
        relationship = snap.relationship,
        stories = has.foe and FightStories(snap.fights) or { Story(snap, true), Story(snap, false) },
        warning = warning,
    }
    if not text.tags and not text.relationship then
        text.who = Whos(snap.record, snap.guild)
    end
    return text
end
