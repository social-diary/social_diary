-- The diary's questions before it deletes (PRV-3, DIA-7): one popup for
-- everything that deletes, and for the one switch that reloads the
-- interface (ns.UI.Dialog.Confirm, ns.UI.ConfirmForget), and the popup
-- that offers DIA-7's choice when someone leaves the diary
-- (ns.UI.ConfirmRemove).
-- Asked from the settings (UI/Settings/), the entry page
-- (UI/Windows/Entry.lua) and /sd forget and /sd remove (Core/Slash.lua).

local addonName, ns = ...

local Dialog = {}
ns.UI.Dialog = Dialog

--------------------------------------------------------------------------
-- Confirmation for everything that deletes (PRV-3), and for the one switch
-- that reloads the interface
--------------------------------------------------------------------------

StaticPopupDialogs["SOCIAL_DIARY_CONFIRM"] = {
    text = "%s",
    button1 = "Delete",
    button2 = CANCEL or "Cancel",
    OnAccept = function(self, action)
        if action then action() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
}

-- `accept`, if given, names the button that goes ahead in place of Delete,
-- for a question that deletes nothing; it comes without the alert sign.
-- The client reads both each time it shows the dialog. Returns the popup
-- shown, for a caller over the dialogs' strata to raise (the dungeon map).
function Dialog.Confirm(text, action, accept)
    local dialog = StaticPopupDialogs["SOCIAL_DIARY_CONFIRM"]
    dialog.button1 = accept or "Delete"
    dialog.showAlert = accept == nil
    return StaticPopup_Show("SOCIAL_DIARY_CONFIRM", text, nil, action)
end

-- Entry.Close announces SD_DIARY_CHANGED, which refreshes the journal and
-- this page with it.
local function AfterDelete()
    ns.UI.Entry.Close()
end

function ns.UI.ConfirmForget(guid)
    local name = ns.Characters.FullName(guid) or guid
    Dialog.Confirm(("Delete everything Social Diary knows about %s?\n\nThis cannot be undone.")
        :format(name), function()
        ns.Characters.Forget(guid)
        ns.Print("deleted everything about |cffffffff%s|r.", name)
        AfterDelete()
    end)
end

--------------------------------------------------------------------------
-- DIA-7: removal offers the choice the requirement demands
--------------------------------------------------------------------------

StaticPopupDialogs["SOCIAL_DIARY_REMOVE"] = {
    text = "Remove %s from the diary?\n\nTheir history can stay as an ordinary"
        .. " character, where the buffer's retention rules apply to it again.",
    button1 = "Keep history",
    button2 = CANCEL or "Cancel",
    button3 = "Delete everything",
    OnAccept = function(self, guid)
        ns.Diary.Remove(guid, "keep")
        ns.UI.Entry.Close()
    end,
    OnAlt = function(self, guid)
        ns.Diary.Remove(guid, "purge")
        ns.UI.Entry.Close()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
}

-- Every way out of the diary goes through this popup (the sheet's link,
-- /sd remove), so each one offers DIA-7's choice.
function ns.UI.ConfirmRemove(guid)
    StaticPopup_Show("SOCIAL_DIARY_REMOVE", ns.Characters.FullName(guid) or guid, nil, guid)
end
