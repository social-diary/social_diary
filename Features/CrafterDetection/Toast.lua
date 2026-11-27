-- Crafter detection's toast card (ns.UI.Toast.RegisterKind,
-- UI/Windows/Reunion/Queue.lua; the signed proposal's toast, words only):
-- the reunion card, filled with a connection found. Capture fires
-- SD_TOAST("crafter", guid, { dir, id, link, how }) once a connection
-- (Capture.lua: a row with the same dir and id already on the person
-- means none), so this kind keeps no count of its own and needs no `due`.
--
--   heading  which way it went (WORDS.toast: "Wearing what you made",
--            "Gave you what you wear", "Sold you what you wear")
--   name     the person, a stranger too: read from ns.Characters, never
--            a diary entry
--   stories  the item, its name in its quality's ink (Style.QualityNameInk,
--            the card's paper inks), longest first for the card to take
--            the first that fits
--
-- Its own switch on Settings' Toasts page (`crafterToasts`, under the
-- master "Show toasts"): a serial crafter may meet many of their buyers
-- (the user, 27 Nov 2026). One card for each (direction, item) a person,
-- and never folded into "and N more" (no `more`): a card said once ever
-- must not be lost to a crowd. A toast never takes the pad.

local addonName, ns = ...

local CrafterDetection = ns.CrafterDetection

-- The item's name as the card writes it: in its quality's ink where it has
-- one (green and better), plain for a white item, "?" with no name.
local function Inked(link)
    local name = CrafterDetection.ItemName(link) or "?"
    local q = ns.UI.ItemBox.Quality(link)
    local ink = q and q >= 2 and ns.Style.QualityNameInk(q)
    if not ink then return name end
    return ("|cff%02x%02x%02x%s|r"):format(ink[1] * 255 + 0.5, ink[2] * 255 + 0.5, ink[3] * 255 + 0.5, name)
end
CrafterDetection.Inked = Inked

ns.UI.Toast.RegisterKind("crafter", {
    setting = "crafterToasts",
    label = CrafterDetection.WORDS.label,
    -- The person's name and record (the portrait), a stranger's as well,
    -- and which way and what.
    snapshot = function(guid, data)
        if type(data) ~= "table" then return nil end
        local record = ns.Characters.Get(guid)
        local name = ns.Characters.FullName(guid) or ns.Characters.Name(guid)
        if not (record and name) then return nil end
        return { name = name, record = record, way = CrafterDetection.Way(data), link = data.link }
    end,
    text = function(snap)
        local words = CrafterDetection.WORDS.toast[snap.way] or CrafterDetection.WORDS.toast.theirs
        local item, stories = Inked(snap.link), {}
        for i, story in ipairs(words.stories) do stories[i] = ns.Fmt(story, item) end
        return { heading = words.heading, name = snap.name, stories = stories }
    end,
    -- One card a (direction, item) in line, the toast's own rule for twins.
    key = function(_, data)
        if type(data) ~= "table" then return tostring(data) end
        return tostring(data.dir) .. ":" .. tostring(data.id)
    end,
})
