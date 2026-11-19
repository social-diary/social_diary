-- The free card's sixteen icons (Features/Note/Icons.lua,
-- .claude/features/note-card.md, phase 2): their keys and names, and every
-- one drawn on a mark kit and on a frame of its own without an error.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Icons = ns.NoteIcons
local Plate = ns.UI.JourneyPlate

--------------------------------------------------------------------------
Section("sixteen keys, each named, the meeting among them")

do
    Check(Icons ~= nil, "ns.NoteIcons is loaded")
    Eq(#Icons.KEYS, 16, "sixteen icons")
    local seen, meeting = {}, false
    for _, key in ipairs(Icons.KEYS) do
        Check(not seen[key], key .. " is listed once")
        seen[key] = true
        if key == "meeting" then meeting = true end
        Check(type(Icons.NAMES[key]) == "string" and Icons.NAMES[key] ~= "", key .. " has a name")
    end
    Check(meeting, "the meeting is one (the old met card's)")
    local names = 0
    for key in pairs(Icons.NAMES) do
        names = names + 1
        Check(seen[key], key .. " is named but not listed")
    end
    Eq(names, 16, "a name for each, and no more")
    Eq(Icons.Known(nil), Icons.KEYS[1], "no key: the default")
    Eq(Icons.Known("nonsense"), Icons.KEYS[1], "an unknown key: the default")
    Eq(Icons.Known("skull"), "skull", "a known key: itself")
end

--------------------------------------------------------------------------
Section("each draws on a mark kit, at the mark's size and the card's")

do
    local kit = Plate.MarkKit(UIParent, function() end, function() return true end, { 1, 1, 1 })
    local keys = { nil, "nonsense" }
    for _, key in ipairs(Icons.KEYS) do keys[#keys + 1] = key end
    for i = 1, #Icons.KEYS + 2 do
        local key = keys[i]
        for _, size in ipairs({ false, 13, 24, 40, 48 }) do
            kit:Begin()
            local ok, err = pcall(Icons.Draw, kit, key, 20, 20, size or nil)
            kit:Finish()
            Check(ok, ("%s at %s: %s"):format(tostring(key), tostring(size), tostring(err)))
            Check(kit.inner.used > 0, ("%s at %s draws ink"):format(tostring(key), tostring(size)))
        end
    end
    -- Where corners cannot move, a fill falls back to a disc and still draws.
    local flat = Plate.MarkKit(UIParent, function() end, function() return false end, { 1, 1, 1 })
    for _, key in ipairs(Icons.KEYS) do
        flat:Begin()
        local ok, err = pcall(Icons.Draw, flat, key, 20, 20, 40)
        flat:Finish()
        Check(ok, key .. " without moving corners: " .. tostring(err))
    end
end

--------------------------------------------------------------------------
Section("a frame of its own shows one icon")

do
    local frame = Icons.New(UIParent, 40)
    Eq(frame.key, Icons.KEYS[1], "the default at first")
    for _, key in ipairs(Icons.KEYS) do
        local ok, err = pcall(frame.SetIcon, frame, key)
        Check(ok, key .. ": " .. tostring(err))
        Eq(frame.key, key, "shows " .. key)
    end
    frame:SetIcon("nonsense")
    Eq(frame.key, Icons.KEYS[1], "an unknown key shows the default")
    frame:SetIcon(nil)
    Eq(frame.key, Icons.KEYS[1], "and so does none")
    frame:SetPaper({ 0.9, 0.85, 0.7 })
    Eq(frame.kit.P[1], 0.9, "the paper it lies on")
    local small = Icons.New(UIParent)
    Check(small ~= nil, "a size by default")
end
