-- The addon's globals for the client: the key bindings' names (Bindings.xml
-- declares the bindings, and its handlers call these) and the function the
-- addon compartment calls (the TOC's AddonCompartmentFunc). The client looks
-- them up only when a key is pressed or the compartment clicked, so nothing
-- reads them at load. What they open is elsewhere: the journal
-- (UI/Journal/Book.lua), the page to add someone on (UI/Windows/Entry.lua)
-- and the quick note (UI/Paper/NoteSheet.lua).

local addonName, ns = ...

--------------------------------------------------------------------------
-- DIA-2's keybind
--------------------------------------------------------------------------

BINDING_HEADER_SOCIAL_DIARY = "Social Diary"
BINDING_NAME_SOCIALDIARY_REMEMBER = "Remember this"

-- With a player targeted who is not in the diary yet, the page to add them
-- on: that is the one-action case, and flow 1 ("helped me with Nagas") lives
-- on it. Anyone else -- nobody targeted, or somebody already in the diary --
-- gets a new note (ns.UI.QuickNote), with them linked on it. The picker is
-- /sd remember's.
function SocialDiary_Remember()
    -- Only the key comes here (the macro and /sd remember open the picker):
    -- what the "Quickly Add Notes" hints count (Core/Hints.lua).
    ns.Hints.Remembered()
    local guid = ns.SafeGUID(UnitGUID("target"))
    if guid and UnitIsPlayer("target") and guid ~= ns.ownGUID then
        if ns.Diary.IsDiary(guid) then
            ns.UI.QuickNote(guid)
        else
            ns.UI.Remember(guid, { unit = "target", source = "keybind" })
        end
        return
    end

    ns.UI.QuickNote()
end

--------------------------------------------------------------------------
-- JNL-4's keybind, and the addon compartment
--------------------------------------------------------------------------

BINDING_NAME_SOCIALDIARY_JOURNAL = "Open the journal"

function SocialDiary_ToggleJournal()
    ns.UI.ToggleJournal()
end

function SocialDiary_OnCompartmentClick()
    ns.UI.ToggleJournal()
end
