-- /sd handtest: tried the handwritten notes (UI/Ink/Hand.lua) on a real
-- save. It stood in front of DungeonPage.CardJot, the question of what to
-- jot that the party's cards asked; the cards are gone and nothing asks it
-- now, so it draws nothing: it toggles and lays the run out again. Kept
-- for whatever writes with the hand next.
--
-- Kept in memory only, so a /reload turns it off. It reads and writes no
-- saved data and leaves Core alone. Development tooling, listed in /sd help
-- only while debug is on.

local addonName, ns = ...

local DungeonPage = ns.UI.DungeonPage
local CardJot = DungeonPage.CardJot
local on = false

DungeonPage.CardJot = function(p)
    local fact, key = CardJot(p)
    if fact or not on or p.isMe then return fact, key end
    for _, f in ipairs(p.facts or {}) do
        if f.kind == "won" and ns.UI.Hand.Note("snagged") then return f, "snagged" end
    end
    return nil
end

ns.Slash.Register("handtest", function()
    on = not on
    ns.Print("handtest %s: %s", on and "on" or "off", on and "a card whose holder won an item has the snagged note."
        or "cards jot only their own notes again.")
    DungeonPage.Refresh()
end, "snagged note on the cards of those who won an item: |cffffd100/sd handtest|r", { dev = true })
