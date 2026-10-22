-- /sd handtest: the handwritten notes on the party's cards (UI/Dungeon/
-- Cards.lua) tried on a real save, before any real run has a note to show.
-- While it is on, a card whose holder won an item in the run (a `won`
-- fact, Core/DungeonRun.lua's Person) has the note a snagged item would
-- have ("snagged an item / from me"), with that item's tooltip over it;
-- never the user's own card. A run out on the table is laid again at once.
--
-- Kept in memory only, so a /reload turns it off. It reads and writes no
-- saved data and leaves Core alone: it only stands in front of
-- DungeonPage.CardJot, the cards' one question of what to jot. Development
-- tooling, listed in /sd help only while debug is on.

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
