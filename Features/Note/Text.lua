-- The free card, in words: see Kind.lua. The words are the copywriter's
-- (note-card.md, phase 4, 19 Nov 2026).

local addonName, ns = ...

local Note = ns.Note
local Text = ns.UI.JourneyText
local List, Short = Text.List, Text.Short
local L, Fmt = ns.L, ns.Fmt

-- A label's longest run of a card's own text, in bytes, before it is cut.
local LABEL_MOST = 40

-- One person's name on the card: a diary entry's current name, so a rename
-- shows here as it does on an automatic strip; else the name as written.
function Note.PersonName(p)
    local guid = Note.Guid(p)
    return guid and Short(guid) or (type(p) == "table" and p.name) or nil
end

-- A meeting with nobody named: "with someone", as a stranger's strip reads
-- (Text.MarginWho) and as "Someone you met" read before it folded into this
-- card (Core/DB.lua's diary step 6 gives an old one the meeting's icon).
-- Any other card that names nobody names nobody.
function Note.Someone(rec)
    if rec.icon ~= "meeting" then return false end
    for _, p in ipairs(Note.People(rec)) do
        if Note.PersonName(p) then return false end
    end
    return true
end

-- Everyone the card names, each once, in its order; "someone" alone for a
-- meeting with nobody named (Note.Someone).
function Note.Names(rec)
    local names, seen = {}, {}
    for _, p in ipairs(Note.People(rec)) do
        local name = Note.PersonName(p)
        if name and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    if not names[1] and Note.Someone(rec) then names[1] = L["someone##with"] end
    return names
end

-- The chosen icon's name, "A meeting", "Treasure"; "A note" for the quill,
-- or where the icons are not there. What a card says it is where nothing
-- else names it, as its heading in the margin does (Card.lua).
function Note.IconName(rec)
    local icons = ns.NoteIcons
    return icons and icons.NAMES[icons.Known(rec.icon)] or L["A note"]
end

-- The card's text on one line, cut to `most` bytes at a word where it is
-- longer. Nil for none.
local function Line(rec, most)
    local text = type(rec.text) == "string" and rec.text:gsub("\n", " ") or ""
    if text == "" then return nil end
    if most and #text > most then
        local cut = ns.CutBytes(text, most)
        text = (cut:match("^(.*%S)%s+%S*$") or cut) .. "..."
    end
    return text
end

-- What the card is about, in a few words: who (all named, "Old Tom and
-- Wenna", or "Someone you met"), else the creature, else the item, else its
-- text cut short; nil for an empty card.
function Note.Subject(rec)
    if Note.Someone(rec) then return L["Someone you met"] end
    local names = Note.Names(rec)
    if names[1] then return List(names) end
    if type(rec.mob) == "string" and rec.mob ~= "" then return rec.mob end
    if type(rec.item) == "string" and rec.item ~= "" then return rec.item end
    return Line(rec, LABEL_MOST)
end

-- The strip's top line: "with Old Tom and Wenna" for a card that names
-- people, as an automatic strip's ("with someone" for a meeting with nobody
-- named); else what it is about; else the icon's name.
function Note.Who(rec)
    local names = Note.Names(rec)
    if names[1] then return Fmt(L["with %s"], List(names)) end
    return Note.Subject(rec) or Note.IconName(rec)
end

-- A row of the ticklist ("Choose what's on this page", the mark's `label`):
-- short, one line.
function Note.Label(rec)
    return Note.Subject(rec) or Note.IconName(rec)
end

-- A menu's line, where a spot merges several: what it is about and the
-- start of its text, "Old Tom, fished off the pier".
function Note.Describe(rec)
    local subject, line = Note.Subject(rec), Line(rec, LABEL_MOST)
    if subject and line and subject ~= line then return Fmt(L["%1$s, %2$s"], subject, line) end
    return subject or Note.IconName(rec)
end

-- When the cards were, and at what level, as every mark's tooltip on the
-- plates ends (the core's Text.Foot).
local function Foot(ts, lo, hi, now)
    return Text.Foot({ times = ts, levelFrom = lo, levelTo = hi }, now)
end

-- The mark's tooltip: one account of every card on its spot (a list of one
-- for a lone card). Its title what the first card is about ("With Old Tom",
-- or the creature, the item, else the icon's name: the words are the
-- lines'); then each card's text, once, and what else it names; then when,
-- and at what level.
function Note.Tips(recs, now)
    local title
    local lines, said = {}, {}
    local ts, lo, hi = {}, nil, nil
    local function Say(line)
        if line and line ~= "" and not said[line] then
            said[line] = true
            lines[#lines + 1] = line
        end
    end
    for _, rec in ipairs(recs) do
        local names = Note.Names(rec)
        local mob = type(rec.mob) == "string" and rec.mob ~= "" and rec.mob or nil
        local item = type(rec.item) == "string" and rec.item ~= "" and rec.item or nil
        local about = names[1] and Fmt(L["With %s"], List(names)) or mob or item or Note.IconName(rec)
        title = title or about
        if about ~= title then Say(about) end
        for line in ((type(rec.text) == "string" and rec.text or "") .. "\n"):gmatch("(.-)\n") do Say(line) end
        if names[1] and type(rec.mob) == "string" and rec.mob ~= "" then Say(rec.mob) end
        if (names[1] or rec.mob) and type(rec.item) == "string" and rec.item ~= "" then Say(rec.item) end
        ts[#ts + 1] = rec.t or 0
        local level = rec.level
        if level then
            lo = (not lo or level < lo) and level or lo
            hi = (not hi or level > hi) and level or hi
        end
    end
    if #lines > 4 then lines = { ns.UI.TimelineText.Join(lines, L["%1$s; %2$s##list"]) } end
    lines[#lines + 1] = Foot(ts, lo, hi, now)
    return title or L["A note"], lines
end

-- One card's tooltip, as its mark's alone (Note.Tips).
function Note.Tip(rec, now)
    return Note.Tips({ rec }, now)
end

--------------------------------------------------------------------------
-- On a plate (Text.RegisterCaption)
--------------------------------------------------------------------------

-- As the core's people lead words a list of names.
local MOST = { max = 3, shown = 2, more = ns.UI.Format.OTHERS }

-- Only a card the player asked to have in the caption (`caption`, off by
-- default: the user's, 19 Nov) is ever said there.
local function Captioned(list)
    local out = {}
    for _, rec in ipairs(list) do
        if rec.caption then out[#out + 1] = rec end
    end
    return out
end

-- The names no note beside the plate gives, and the words have not.
-- said.noteCard holds the cards in the margin ([record] = true, Card.lua);
-- said.named who any strip names. A person who is also among the words' own
-- people ("With Tester") is not said twice. A meeting with nobody named is
-- "someone" (Note.Someone), as "Someone you met" was. The second value: a
-- card in the list names anyone at all.
local function Unsaid(list, c)
    local names, seen, anyone = {}, {}, false
    for _, rec in ipairs(list) do
        local onStrip = c.said.noteCard and c.said.noteCard[rec]
        local function Say(name, guid)
            anyone = true
            if not onStrip and not (guid and c.named[guid]) and not c.people[name] and not seen[name] then
                seen[name] = true
                names[#names + 1] = name
            end
        end
        if Note.Someone(rec) then Say(L["someone##with"]) end
        for _, p in ipairs(Note.People(rec)) do
            local name = Note.PersonName(p)
            if name then Say(name, Note.Guid(p)) end
        end
    end
    return names, anyone
end

-- A captioned card's people, on a strip, the words say what an automatic
-- strip's plate says beside its note: "In good company" (`c.company`). Left
-- off the margin, they are named as the people's lead names them, right after
-- it (15); or after it in the tail (5), first of all, where it led.
Text.RegisterCaption(Note.KIND, {
    moment = Note.KIND,
    take = function(m) return m.noteCard end,
    lead = { at = 15, say = function(list, c)
        list = Captioned(list)
        if not list[1] then return nil end
        local names, anyone = Unsaid(list, c)
        if names[1] then return Fmt(L["With %s"], List(names, MOST)) end
        -- (all of them in the margin already: "In good company"; a card
        -- naming nobody says nothing here)
        if anyone then c.company = c.company or Note.KIND end
        return nil
    end },
    tail = { at = 5, say = function(list, c)
        local names = Unsaid(Captioned(list), c)
        return names[1] and Fmt(L["with %s"], List(names, MOST)) or nil
    end },
})
