-- /sd cardrace <Race>: every card on the party's table (UI/Dungeon/
-- Cards.lua) drawn in the design of one race (UnitRace's file name:
-- Dwarf, Gnome, NightElf, Skyborne, Human, Scourge, ...), to see a design
-- on a real save before a run with someone of that race; /sd cardrace
-- alone, back to each holder's own. A run out on the table is laid again
-- at once.
--
-- Kept in memory only, so a /reload turns it off. It reads and writes no
-- saved data: it only stands in front of DungeonPage.CardStyle, the cards'
-- one question of which design. Development tooling, listed in /sd help
-- only while debug is on.

local addonName, ns = ...

local DungeonPage = ns.UI.DungeonPage
local CardStyle = DungeonPage.CardStyle
local race

DungeonPage.CardStyle = function(r) return CardStyle(race or r) end

ns.Slash.Register("cardrace", function(rest)
    race = rest ~= "" and rest or nil
    if race then
        ns.Print("cardrace %s: every card in the %s design.", race, CardStyle(race))
    else
        ns.Print("cardrace off: each card in its holder's own design.")
    end
    DungeonPage.Refresh()
end, "every card in one race's design: |cffffd100/sd cardrace Scourge|r (alone: off)",
    { dev = true, usage = "cardrace <race>" })
