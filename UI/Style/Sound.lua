-- The journal's sounds (Style, from UI/Style/Tokens.lua), kept by key as
-- its art is (UI/Style/Art.lua): Style.SOUNDS and Style.PlaySound.

local addonName, ns = ...

local Style = ns.Style

-- Sounds, by key, as art is: each a list of SOUNDKIT names, the first the
-- client knows winning, and silence where it knows none. Played on the
-- sound effects channel, so the player's effects volume and switch govern
-- them. Only the book's own moments make a sound; choosing a person in the
-- list does not.
--   sheetOpen, sheetClose  a loose sheet laid on the book or taken off it:
--                          paper, the quest log's, which the world map shares
--   pageTurn               a ribbon turning the book to another page
--   write                  something new written into the diary: a person
--                          added, a new note saved. The quill of a quest
--                          written into the log
--   tear                   the parcel at login torn open: a bag opened
--   foeAlert               a foe in view (Core/Reunions.lua): the raid
--                          warning, on the master channel, so it is heard
--                          with sound effects turned down
Style.SOUNDS = {
    sheetOpen = { "IG_QUEST_LOG_OPEN", "IG_SPELLBOOK_OPEN" },
    sheetClose = { "IG_QUEST_LOG_CLOSE", "IG_SPELLBOOK_CLOSE" },
    pageTurn = { "IG_ABILITY_PAGE_TURN", "IG_SPELLBOOK_OPEN" },
    write = { "IG_WRITE_QUEST", "IG_QUEST_LIST_SELECT" },
    foeAlert = { "RAID_WARNING", "READY_CHECK" },
    -- The parcel at login torn open (UI/Windows/Intro/Parcel.lua): a bag opened, the
    -- wrapping coming off (chosen in-client, 9 Oct; the quest abandon's rip
    -- did not fit), else a sheet laid down.
    tear = { "IG_BACKPACK_OPEN", "IG_QUEST_LOG_OPEN" },
}

-- `channel` is "SFX" unless given.
function Style.PlaySound(key, channel)
    if not (PlaySound and SOUNDKIT) then return end
    for _, name in ipairs(Style.SOUNDS[key] or {}) do
        local id = SOUNDKIT[name]
        if id then
            PlaySound(id, channel or "SFX")
            return
        end
    end
end
