-- The free card on the page of everyone it links to: a written slip on
-- their timeline, at the card's time, in the look of a note of yours there
-- (UI/Journal/Strips.lua's Written), through the timeline's asides
-- (Core/Timeline.lua's Timeline.RegisterAside).
--
-- Read from the routes every time, never copied (the user's, 19 Nov 2026):
-- no row, note or session is written, so the card counts for nothing on
-- their page (times met, last met, the zones, "dealt", whether they matter;
-- the plate, the facts and the hindsight line never hear of it), and a card
-- edited, a person taken off it, the card deleted, or Forget (which takes
-- the link and leaves the name: Core/Custom.lua's ForgetOn) shows here with
-- nothing more. A name only typed has no page, so it has no slip. Shown
-- whatever the card's "Write it into the entry" (that box is the left page
-- of Your Diary's only).
--
-- The slip: the chosen icon (small) in the icon column, the player's words
-- in their hand on the slip (the icon's name, "A meeting", where they wrote
-- none), and a quiet line under it of where and at what level, and who else
-- it names, or where it has neither words nor anyone else, the creature and
-- the item:
--   [icon] 18:20  “Fished off the pier till dark.”
--                 Noted on your map in Mulgore, level 12, with Old Tom
-- Its tooltip is the card's (Note.Tip). A click opens Your Diary on the
-- page the card's time falls on (YourDiary.OpenAt), where it is the road of
-- the character playing; a card on another of the user's characters' roads
-- (a shared diary) has no page there, and its click does nothing.

local addonName, ns = ...

local Note = ns.Note
local Text = ns.UI.JourneyText
local Format = ns.UI.Format
local L, Fmt = ns.L, ns.Fmt

-- As the core's people lead words a list of names.
local MOST = { max = 3, shown = 2, more = Format.OTHERS }

-- Every free card on the routes of the diary in use that links to `guid`,
-- oldest first: { time, key (the saved card: the line's place for the pad),
-- rec, me (whose road it is on) }.
local function CardsOf(guid)
    local out = {}
    for me, j in pairs(ns.db.journey or {}) do
        for _, rec in ipairs(type(j) == "table" and j.custom or {}) do
            local hidden = type(rec.custom) == "table" and rec.custom.hidden
            if rec.kind == Note.KIND and type(rec.t) == "number" and not hidden then
                for _, p in ipairs(Note.People(rec)) do
                    if Note.Guid(p) == guid then
                        out[#out + 1] = { time = rec.t, key = rec, rec = rec, me = me }
                        break
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.time < b.time end)
    return out
end
Note.CardsOf = CardsOf

-- Everyone else the card names, each once, in its order (typed names as
-- written): the page is `guid`'s, so they are not among them.
local function Others(rec, guid)
    local names, seen = {}, {}
    for _, p in ipairs(Note.People(rec)) do
        if Note.Guid(p) ~= guid then
            local name = Note.PersonName(p)
            if name and not seen[name] then
                seen[name] = true
                names[#names + 1] = name
            end
        end
    end
    return names
end

-- The player's words on one line, as written; nil for none.
local function Words(rec)
    local text = Text.Written(type(rec.text) == "string" and rec.text or "")
    return text ~= "" and text or nil
end

-- Where the card lies, on whose map, and at what level: "Noted on your
-- map in Mulgore, level 12" ("on Thex's map" for another of the user's
-- characters, in a shared diary).
local function Where(rec, me)
    local zone = rec.mapID and Text.MapName(rec.mapID)
    zone = zone and ns.ZoneIn(rec.mapID, zone)
    local level = rec.level
    local line
    if zone and level then line = Fmt(L["Noted on {your} map %1$s, level %2$s##zone"], zone, level)
    elseif zone then line = Fmt(L["Noted on {your} map %s##zone"], zone)
    elseif level then line = Fmt(L["Noted on {your} map, level %s"], level)
    else line = L["Noted on {your} map"] end
    return Format.You(me, line)
end

-- The slip's words, and the line under it.
function Note.Aside(of, guid)
    local rec = of.rec
    local words = Words(rec)
    local with = Others(rec, guid)
    -- (the creature and the item only on a card with no words and nobody
    -- else, as the entry's sentence says them: otherwise its words, or who
    -- was there, say what it was; the tooltip has them all)
    if not words and not with[1] then
        if type(rec.mob) == "string" and rec.mob ~= "" then with[#with + 1] = Text.KillerName({ name = rec.mob }) end
        if type(rec.item) == "string" and rec.item ~= "" then with[#with + 1] = rec.item end
    end
    local where = Where(rec, of.me)
    local sub = with[1] and Fmt(L["%1$s, with %2$s##card where and who"], where, Text.List(with, MOST)) or where
    return words or Note.IconName(rec), sub
end

-- Whether a click opens Your Diary on the card's page: the road of the
-- character playing, and the page there to open (UI/Journey/Page.lua,
-- looked up when asked: it may not be there yet).
local function Opens(of)
    local YD = ns.UI.YourDiary
    return YD ~= nil and YD.OpenAt ~= nil and of.me == ns.ownGUID
end
Note.OpensAside = Opens

ns.Timeline.RegisterAside(Note.KIND, {
    lines = CardsOf,
    describe = function(of, guid) return Note.Aside(of, guid) end,
    tip = function(of)
        local title, lines = Note.Tip(of.rec, ns.Now())
        return ns.Style.TipList(title, lines)
    end,
    icon = function(parent, size)
        local frame = ns.NoteIcons.New(parent, size)
        function frame:Set(of) self:SetIcon(of.rec.icon) end
        return frame
    end,
    opens = Opens,
    press = function(of)
        if not Opens(of) then return end
        -- The book turns to Your Diary first: the card's page is drawn there.
        ns.UI.SetJournalView("journey")
        ns.UI.YourDiary.OpenAt(of.time)
    end,
    hint = L["Click to open it in Your Diary."],
    prompt = L["Open in Your Diary"],
})
