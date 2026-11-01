-- The mouse on the table spread (UI/Dungeon/Spread.lua's Settle): what the
-- client protects is asked for out of a fight only, and however the client
-- answers, the run still comes out.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq

-- Every frame made refuses the calls by throwing, while `refusing`.
local refusing = false
local Create = _G.CreateFrame
_G.CreateFrame = function(...)
    local frame = Create(...)
    local pass, clicks = frame.SetPassThroughButtons, frame.SetMouseClickEnabled
    function frame:SetPassThroughButtons(...)
        if refusing then error("blocked") end
        if mock.inCombat then error("called in a fight") end
        return pass(self, ...)
    end
    function frame:SetMouseClickEnabled(...)
        if refusing then error("blocked") end
        if mock.inCombat then error("called in a fight") end
        return clicks(self, ...)
    end
    return frame
end

local ns = T.Boot()
local DP = ns.UI.DungeonPage
local J = ns.UI.Journal
mock.missingFiles["Interface\\LFGFrame\\LFGIcon-HallofThanes"] = true
mock.missingFiles["Interface\\LFGFrame\\LFGIcon-TestVault"] = true
mock.now = 1795000000
SlashCmdList.SOCIALDIARY("testdata")
local G = ns.TestData.GUID
local RFK
for _, visit in ipairs(ns.Instances.For(G)) do
    if visit.instanceID == 47 then RFK = visit end
end
Check(RFK ~= nil, "setup: the test data's Razorfen Kraul run")

local function Hearing(frame, found)
    found = found or {}
    if frame:IsMouseClickEnabled() then found[#found + 1] = frame end
    for _, child in ipairs({ frame:GetChildren() }) do Hearing(child, found) end
    return found
end

--------------------------------------------------------------------------
Section("the client refuses: the run comes out all the same")

ns.UI.ShowJournal(G)
refusing = true
Eq(ns.UI.OpenVisit(RFK.id, G), true, "a refused call stopped the run coming out")
local host = DP.Spread()
Check(host:IsShown() and host.map:IsShown(), "a refused call left the sheet not laid")
Check(host.back ~= nil and host.map.onMeasure ~= nil, "a refused call left the spread half built")
Eq(J.journal:GetAlpha(), 0, "a refused call left the book showing")
DP.Close(true)
Eq(ns.UI.OpenVisit(RFK.id, G), true, "the second time out, refused")
DP.Close(true)
Eq(J.journal:GetAlpha(), 1, "the book not back")
refusing = false
Eq(ns.UI.OpenVisit(RFK.id, G), true, "out again, no longer refused")
Eq(host.map.recorded.calls.SetPassThroughButtons[1], "RightButton", "a refusal is not asked again")
DP.Close(true)

--------------------------------------------------------------------------
Section("nothing is asked in a fight, and it is all put right after")

local heard = #Hearing(J.journal)
Check(heard > 0, "setup: the book hears clicks")
-- Out in a fight: the book not touched, then deaf as the fight ends.
mock.inCombat = true
Eq(ns.UI.OpenVisit(RFK.id, G), true, "the run did not come out in a fight")
Eq(#Hearing(J.journal), heard, "the book was touched in a fight")
mock.inCombat = false
host.scripts.OnEvent(host, "PLAYER_REGEN_ENABLED")
Eq(#Hearing(J.journal), 0, "the book not deaf as the fight ended")
-- Away in a fight: it hears again only as the fight ends.
mock.inCombat = true
DP.Close(true)
Eq(#Hearing(J.journal), 0, "the book was touched in a fight")
mock.inCombat = false
host.scripts.OnEvent(host, "PLAYER_REGEN_ENABLED")
Eq(#Hearing(J.journal), heard, "the book did not hear again as the fight ended")
-- Out and away in the one fight: never touched.
mock.inCombat = true
ns.UI.OpenVisit(RFK.id, G)
DP.Close(true)
mock.inCombat = false
host.scripts.OnEvent(host, "PLAYER_REGEN_ENABLED")
Eq(#Hearing(J.journal), heard, "the book changed by a run out and away in one fight")
ns.UI.CloseJournal()
_G.CreateFrame = Create
