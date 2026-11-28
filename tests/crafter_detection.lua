-- Crafter detection's capture (Features/CrafterDetection/Capture.lua),
-- Stage 1: the craft book, the hand-offs (a trade, an auction sale), what
-- the user got and from whom (a trade, an auction won), the worn slots,
-- meeting people, the inspect queue and its gate, and one connection ever.
-- Invented players and items throughout.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq

-- The inbox's letters: { kind, item, who, bid } by index.
local letters = {}
_G.GetInboxNumItems = function() return #letters end
_G.GetInboxInvoiceInfo = function(i)
    local l = letters[i]
    if not l then return nil end
    return l[1], l[2], l[3], l[4], l[4], 0, 0, 0, 0, 0, 1, false
end

-- The inspect calls: who was asked, and what each GUID wears.
local asks, wears, canInspect = {}, {}, true
_G.CanInspect = function() return canInspect end
_G.NotifyInspect = function(unit) asks[#asks + 1] = unit end
_G.InspectFrame = { shown = false, IsShown = function(self) return self.shown end }

-- A tailor, past the crafter gate's rank.
mock.professions = { { name = "Tailoring", rank = 40, max = 75, line = 197 } }

local ns = T.Boot()

-- Worn slots: the user's from the mock, anyone else's from `wears`.
local own = _G.GetInventoryItemLink
_G.GetInventoryItemLink = function(unit, slot)
    if unit == "player" then return own(unit, slot) end
    local guid = UnitGUID(unit)
    return wears[guid] and wears[guid][slot]
end

local CD = ns.CrafterDetection
local Test = ns._test.CrafterDetection
local SELF, BRAM, TULLUS, NUMA, GARRICK = F.SELF, F.STRANGER, F.STRANGER2, F.FRIEND, F.GARRICK

local function Link(id, name, colour)
    return ("|cff%s|Hitem:%d::::::::14:::::::::|h[%s]|h|r"):format(colour or "ffffff", id, name)
end
local BOOTS = Link(2302, "Handstitched Leather Boots")
local GLOVES = Link(7001, "Linen Gloves")
local CLOTH = Link(2589, "Linen Cloth")
local BRACERS = Link(6070, "Wolfskin Bracers", "1eff00")
local CHARM = Link(7002, "Lucky Charm Amulet", "1eff00")
for id, equipLoc in pairs({ [2302] = "INVTYPE_FEET", [7001] = "INVTYPE_HAND", [6070] = "INVTYPE_WRIST",
    [7002] = "INVTYPE_NECK", [2589] = "" }) do
    mock.itemInfo[id] = { equipLoc = equipLoc }
end

-- The route, kept.
mock.fire("PLAYER_ENTERING_WORLD")
local j = ns.db.journey[SELF.guid]
Check(j, "setup: no route")

local toasts = {}
ns.On("SD_TOAST", function(_, kind, guid, data) toasts[#toasts + 1] = { kind = kind, guid = guid, data = data } end)

local made = 0
local function Craft(link, extra)
    made = made + 1
    local result = { itemID = CD.ItemID(link), itemGUID = ("Item-0000-0-%08X"):format(made), hyperlink = link,
        quantity = 1, isEnchant = false }
    for k, v in pairs(extra or {}) do result[k] = v end
    mock.fire("TRADE_SKILL_ITEM_CRAFTED_RESULT", result)
    return result.itemGUID
end

local function Book() return j.crafter end

-- Time passes past the queue's gap, so the next ask may go.
local function Later(seconds)
    mock.now = mock.now + (seconds or 10)
    mock.RunTimers()
end

local function Target(who)
    Later()
    mock.SetUnit("target", who)
    mock.fire("PLAYER_TARGET_CHANGED")
end

local function Answer(who)
    mock.fire("INSPECT_READY", who.guid)
end

local function Rows(guid, dir)
    local n = 0
    for _, row in ipairs(ns.Interactions.For(guid) or {}) do
        if row.type == "crafted" and (not dir or row.context.dir == dir) then n = n + 1 end
    end
    return n
end

--------------------------------------------------------------------------
Section("the craft book keeps worn gear the user made, nothing else")

local bootsKey = Craft(BOOTS)
Craft(CLOTH)
Craft(GLOVES, { isEnchant = true })
Eq(Book().made[bootsKey] and Book().made[bootsKey].id, 2302, "the boots made are not in the book")
Eq(Book().made[bootsKey].name, "Handstitched Leather Boots", "the craft's name, for an auction letter")
local n = 0
for _ in pairs(Book().made) do n = n + 1 end
Eq(n, 1, "cloth or an enchant was booked as gear made")
-- The same result told twice is one craft.
mock.fire("TRADE_SKILL_ITEM_CRAFTED_RESULT", { itemID = 2302, itemGUID = bootsKey, hyperlink = BOOTS })
n = 0
for _ in pairs(Book().made) do n = n + 1 end
Eq(n, 1, "the same craft was booked twice")

--------------------------------------------------------------------------
Section("the crafter gate: the craft side runs only past T.rank in a gear profession")

local Crafter = CD.Crafter
Check(Crafter(), "a tailor at 40 is not a crafter")
mock.professions = { { name = "Tailoring", rank = 1, max = 75, line = 197 },
    { name = "Alchemy", rank = 60, max = 75, line = 171 } }
mock.fire("SKILL_LINES_CHANGED")
Check(not Crafter(), "a tailor at 1 (and an alchemist) counted as a crafter")
local beforeGate = 0
for _ in pairs(Book().made) do beforeGate = beforeGate + 1 end
Craft(GLOVES)
local afterGate = 0
for _ in pairs(Book().made) do afterGate = afterGate + 1 end
Eq(afterGate, beforeGate, "a craft booked for someone not a crafter")
CD.INSPECT_EVERYONE = true
asks = {}
Target(GARRICK)
Eq(#asks, 0, "someone not a crafter asked for an inspect")
CD.INSPECT_EVERYONE = false
mock.professions = { { name = "Tailoring", rank = 40, max = 75, line = 197 } }
mock.fire("SKILL_LINES_CHANGED")
Check(Crafter(), "the gate did not open again once the skills changed")
Test.Reset()
Test.Worn()
asks = {}

--------------------------------------------------------------------------
Section("Stage 1's gate: nobody is inspected without a craft of the user's")

Target(BRAM)
Eq(#asks, 0, "a stranger with nothing of the user's was inspected")
CD.INSPECT_EVERYONE = true
Target(TULLUS)
Eq(#asks, 1, "with the gate open (Stage 2), a stranger targeted was not inspected")
CD.INSPECT_EVERYONE = false
Test.Reset()
Test.Worn()
asks = {}

--------------------------------------------------------------------------
Section("a craft traded, then found on them: one connection, one toast")

ns.Fire("SD_TRADE_COMPLETED", BRAM.guid, nil, { { link = BOOTS, count = 1 } })
Eq(Book().made[bootsKey].to, BRAM.guid, "the boots traded were not handed to them")
Eq(Book().made[bootsKey].how, "trade", "how they went")
Check(Test.Index().guids[BRAM.guid], "who has the boots is not watched for")

-- With someone watched for, a stranger without a craft of the user's is
-- still not inspected: the gate, not an empty book, keeps them out.
Target(TULLUS)
Eq(#asks, 0, "Stage 1 inspected someone the user handed nothing to")

-- Seen on a nameplate only: no inspect (target and mouseover ask).
mock.SetUnit("nameplate1", BRAM)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Eq(#asks, 0, "a nameplate asked for an inspect")

-- Targeted: asked; not wearing them yet.
Target(BRAM)
Eq(#asks, 1, "targeting them did not ask for an inspect")
Eq(asks[1], "target", "the inspect was not asked of the target")
wears[BRAM.guid] = { [1] = Link(9001, "Plain Hat") }
Answer(BRAM)
Eq(Rows(BRAM.guid), 0, "a connection found with the boots not on them")

-- Asked again only after T.again.
Target(BRAM)
Eq(#asks, 1, "the same person was inspected again before T.again")

mock.now = mock.now + CD.T.again
wears[BRAM.guid] = { [1] = Link(9001, "Plain Hat"), [8] = BOOTS }
Target(BRAM)
Eq(#asks, 2, "not asked again after T.again")
Answer(BRAM)
Eq(Rows(BRAM.guid, CD.THEIRS), 1, "the boots on them made no connection")
local row = ns.Interactions.For(BRAM.guid)[#ns.Interactions.For(BRAM.guid)]
Eq(row.context.id, 2302, "the row's item")
Eq(row.context.how, "trade", "the row's how")
Eq(row.context.proof, "handoff", "the row's proof")
Eq(#toasts, 1, "no toast for the connection")
Eq(toasts[1] and toasts[1].kind, "crafter", "the toast's kind")
Eq(toasts[1] and toasts[1].guid, BRAM.guid, "the toast's person")
Eq(#(j.craftMeets or {}), 1, "the connection is not on the route")
Eq(j.craftMeets[1].dir, CD.THEIRS, "the route's record's direction")
Check(Book().made[bootsKey].met, "the craft is not marked found")
Check(not Test.Index().guids[BRAM.guid], "someone already found is still watched for")

-- Found: never asked, never told again.
mock.now = mock.now + CD.T.again
Target(BRAM)
Answer(BRAM)
Eq(#asks, 2, "someone already found was inspected again")
Eq(Rows(BRAM.guid), 1, "a second row for the same connection")
Eq(#toasts, 1, "a second toast for the same connection")

--------------------------------------------------------------------------
Section("the queue keeps out of the way")

local glovesKey = Craft(GLOVES)
ns.Fire("SD_TRADE_COMPLETED", NUMA.guid, nil, { { link = GLOVES, count = 1 } })
wears[NUMA.guid] = { [10] = GLOVES }
asks = {}

mock.inCombat = true
Target(NUMA)
Eq(#asks, 0, "asked in combat")
mock.inCombat = false

mock.inInstance = true
Target(NUMA)
Eq(#asks, 0, "asked in an instance")
mock.inInstance = false

InspectFrame.shown = true
Target(NUMA)
Eq(#asks, 0, "asked while the Inspect frame was open")
-- ... but what the frame asked is read along.
Answer(NUMA)
Eq(Rows(NUMA.guid, CD.THEIRS), 1, "the Inspect frame's answer was not read along")
InspectFrame.shown = false

-- Two asks within T.gap: the second waits.
mock.itemInfo[7003] = { equipLoc = "INVTYPE_WAIST" }
mock.itemInfo[7004] = { equipLoc = "INVTYPE_CLOAK" }
local craft2 = Craft(Link(7003, "Linen Belt"))
local craft3 = Craft(Link(7004, "Linen Cloak"))
Check(Book().made[craft2] and Book().made[craft3], "setup: the belt and the cloak are not in the book")
ns.Fire("SD_TRADE_COMPLETED", TULLUS.guid, nil, { { link = Link(7003, "Linen Belt"), count = 1 } })
ns.Fire("SD_TRADE_COMPLETED", GARRICK.guid, nil, { { link = Link(7004, "Linen Cloak"), count = 1 } })
asks = {}
Target(TULLUS)
mock.SetUnit("mouseover", GARRICK)
mock.fire("UPDATE_MOUSEOVER_UNIT")
Eq(#asks, 1, "two inspects asked within T.gap")
-- An answer for someone else is not taken for theirs.
wears[GARRICK.guid] = { [15] = Link(7004, "Linen Cloak") }
Answer(GARRICK)
Eq(Rows(GARRICK.guid), 0, "an answer nobody asked for was read")
-- An ask unanswered is given up after T.timeout.
Later(CD.T.timeout)
mock.fire("UPDATE_MOUSEOVER_UNIT")
Eq(#asks, 2, "an unanswered ask blocked the queue past T.timeout")
Eq(asks[2], "mouseover", "the inspect was not asked of the mouseover")
Answer(GARRICK)
Eq(Rows(GARRICK.guid, CD.THEIRS), 1, "the mouseover's answer made no connection")

-- Someone who can't be inspected is not asked.
asks, canInspect = {}, false
mock.now = mock.now + CD.T.again
Target(TULLUS)
Eq(#asks, 0, "asked of someone the client says can't be inspected")
canInspect = true

--------------------------------------------------------------------------
Section("an auction sale hands a craft to the buyer's name, met later")

local saleKey = Craft(GLOVES)
local spareKey = Craft(GLOVES)
-- The buyer reads "" for a moment after the letter arrives.
letters = { { "seller", "Linen Gloves", "", 120 } }
mock.fire("MAIL_INBOX_UPDATE")
Check(CD.Unhanded(Book().made[saleKey]), "a craft was handed to nobody")
letters = { { "seller", "Linen Gloves", "Tullus Hostilius", 120 } }
mock.fire("MAIL_INBOX_UPDATE")
mock.fire("MAIL_INBOX_UPDATE")
Eq(Book().made[saleKey].toName, "Tullus Hostilius", "the craft sold did not go to the buyer's name")
Eq(Book().made[saleKey].how, "auction", "how it went")
Check(CD.Unhanded(Book().made[spareKey]), "the same letter read again handed a second craft")
-- "Multiple buyers" (nil): a stack, nobody.
letters = { { "seller", "Linen Gloves", nil, 5 } }
mock.fire("MAIL_INBOX_UPDATE")
Check(CD.Unhanded(Book().made[spareKey]), "a letter with no buyer handed a craft")
letters = {}
for key in pairs(Book().letters) do
    Check(type(key) == "number", "a letter's key kept the buyer's name")
end

-- Someone else's name is read once a session while a name waits; again
-- only once a new name joins.
Check(Test.Index().names["Tullus Hostilius"], "the buyer's name is not watched for")
local nameReads, NameFromUnit = 0, ns.NameFromUnit
ns.NameFromUnit = function(...) nameReads = nameReads + 1 return NameFromUnit(...) end
mock.SetUnit("nameplate6", GARRICK)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate6")
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate6")
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate6")
Eq(nameReads, 1, "the same person's name read again in one session")
local otherKey = Craft(BOOTS)
letters = { { "seller", "Handstitched Leather Boots", "Garrick Fallow", 77 } }
mock.fire("MAIL_INBOX_UPDATE")
letters = {}
Eq(Book().made[otherKey].toName, "Garrick Fallow", "setup: the boots were not sold")
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate6")
Eq(nameReads, 2, "a new name waiting did not read people already read")
Eq(Book().made[otherKey].to, GARRICK.guid, "the new name was not met")
ns.NameFromUnit = NameFromUnit
Book().made[otherKey] = nil
Test.Reindex()

-- Seen on a nameplate: by GUID from now on.
mock.SetUnit("nameplate2", TULLUS)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
Eq(Book().made[saleKey].to, TULLUS.guid, "meeting the buyer did not put their GUID on the craft")
Eq(Book().made[saleKey].toName, nil, "the name stayed on the craft")

asks = {}
mock.now = mock.now + CD.T.again
wears[TULLUS.guid] = { [10] = GLOVES }
Target(TULLUS)
Answer(TULLUS)
Eq(Rows(TULLUS.guid, CD.THEIRS), 1, "the gloves sold made no connection when found")
local last = ns.Interactions.For(TULLUS.guid)[#ns.Interactions.For(TULLUS.guid)]
Eq(last.context.how, "auction", "the connection's how")

--------------------------------------------------------------------------
Section("yours: given in a trade, worn, and seeing them is enough")

toasts = {}
ns.Fire("SD_TRADE_COMPLETED", NUMA.guid, { { link = BRACERS, count = 1 }, { link = CLOTH, count = 5 } }, nil)
Eq(Book().got[6070] and Book().got[6070].from, NUMA.guid, "the bracers given were not noted from them")
Eq(Book().got[2589], nil, "cloth given was noted as gear")

-- Not worn yet: nothing.
mock.SetUnit("nameplate3", NUMA)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
Eq(Rows(NUMA.guid, CD.YOURS), 0, "a connection with the bracers not worn")

mock.equipped[9] = { link = BRACERS, quality = 2 }
mock.fire("PLAYER_EQUIPMENT_CHANGED", 9, false)
mock.RunTimers()
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
Eq(Rows(NUMA.guid, CD.YOURS), 1, "seeing who gave the bracers worn made no connection")
Eq(#toasts, 1, "no toast for the bracers")
Eq(toasts[1] and toasts[1].data.dir, CD.YOURS, "the toast's direction")
Eq(toasts[1] and toasts[1].data.how, "trade", "the toast's how")
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
Eq(Rows(NUMA.guid, CD.YOURS), 1, "a second row for the same bracers")
Check(Book().got[6070].met, "the bracers' connection is not marked made")
Check(not Test.Index().guids[NUMA.guid], "who gave the bracers is still watched for once connected")

-- Taken off once worn: let go.
mock.equipped[9] = nil
mock.fire("PLAYER_EQUIPMENT_CHANGED", 9, true)
mock.RunTimers()
Eq(Book().got[6070], nil, "the bracers taken off are still kept")

--------------------------------------------------------------------------
Section("yours: won at auction, put on, the seller met by name")

toasts = {}
letters = { { "buyer", "Lucky Charm Amulet", "Garrick Fallow", 900 } }
mock.fire("MAIL_INBOX_UPDATE")
Check(next(Book().bought), "the auction won was not noted")
letters = {}
mock.equipped[2] = { link = CHARM, quality = 2 }
mock.fire("PLAYER_EQUIPMENT_CHANGED", 2, false)
mock.RunTimers()
Eq(Book().got[7002] and Book().got[7002].fromName, "Garrick Fallow", "the amulet put on is not noted from the seller")
Eq(next(Book().bought), nil, "the auction won stayed noted once worn")
mock.SetUnit("nameplate4", GARRICK)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
Eq(Rows(GARRICK.guid, CD.YOURS), 1, "seeing the seller made no connection")
Eq(Book().got[7002].from, GARRICK.guid, "the seller's GUID was not put on the amulet")
local sold = ns.Interactions.For(GARRICK.guid)[#ns.Interactions.For(GARRICK.guid)]
Eq(sold.context.how, "auction", "the connection's how")
Eq(#toasts, 1, "no toast for the amulet")
mock.equipped[2] = nil
mock.fire("PLAYER_EQUIPMENT_CHANGED", 2, true)
mock.RunTimers()

--------------------------------------------------------------------------
Section("nothing in an instance; nothing without the route kept")

ns.Fire("SD_TRADE_COMPLETED", BRAM.guid, { { link = BRACERS, count = 1 } }, nil)
mock.equipped[9] = { link = BRACERS, quality = 2 }
mock.fire("PLAYER_EQUIPMENT_CHANGED", 9, false)
mock.RunTimers()
mock.inInstance = true
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Eq(Rows(BRAM.guid, CD.YOURS), 0, "a connection made in an instance")
mock.inInstance = false

ns.db.settings.keepRoute = false
local before = 0
for _ in pairs(Book().made) do before = before + 1 end
Craft(BOOTS)
local after = 0
for _ in pairs(Book().made) do after = after + 1 end
Eq(after, before, "a craft booked with the route not kept")
ns.db.settings.keepRoute = true
mock.equipped[9] = nil
mock.fire("PLAYER_EQUIPMENT_CHANGED", 9, true)
mock.RunTimers()

--------------------------------------------------------------------------
Section("forgetting someone, and the buffer's days")

ns.Characters.Forget(TULLUS.guid)
Eq(Book().made[saleKey].to, nil, "a forgotten person is still on the craft")
Check(Book().made[saleKey].gone, "the craft a forgotten person had could be handed again")
for _, rec in ipairs(j.craftMeets) do
    Check(rec.guid ~= TULLUS.guid, "a forgotten person is still on the route's record")
end

-- A stranger's hand-off past the buffer's days goes; a diary entry's stays.
local oldKey = Craft(Link(7005, "Linen Hood"))
mock.itemInfo[7005] = { equipLoc = "INVTYPE_HEAD" }
Book().made[oldKey] = { id = 7005, name = "Linen Hood", t = mock.now, to = BRAM.guid, how = "trade",
    handed = mock.now }
ns.Journey.Prune(mock.now + (ns.BufferDays() + 1) * T.DAY)
Eq(Book().made[oldKey], nil, "a stranger's hand-off outlived the buffer")

-- A sale letter still in the inbox after its craft was pruned hands no
-- second craft; the letter's key goes after T.letters.
local soldKey = Craft(Link(7006, "Linen Sash"))
local twinKey = Craft(Link(7006, "Linen Sash"))
mock.itemInfo[7006] = { equipLoc = "INVTYPE_WAIST" }
Book().made[soldKey] = { id = 7006, name = "Linen Sash", t = mock.now - 1, link = Link(7006, "Linen Sash") }
Book().made[twinKey] = { id = 7006, name = "Linen Sash", t = mock.now, link = Link(7006, "Linen Sash") }
letters = { { "seller", "Linen Sash", "Kaeso Varro", 300 } }
mock.fire("MAIL_INBOX_UPDATE")
Eq(Book().made[soldKey].toName, "Kaeso Varro", "setup: the sash was not sold")
ns.Journey.Prune(mock.now + (ns.BufferDays() + 1) * T.DAY)
Eq(Book().made[soldKey], nil, "setup: the sale outlived the buffer")
mock.fire("MAIL_INBOX_UPDATE")
Check(CD.Unhanded(Book().made[twinKey]), "a letter read again after its craft was pruned handed a second craft")
ns.Journey.Prune(mock.now + CD.T.letters + T.DAY)
Eq(next(Book().letters), nil, "a letter's key outlived the mail")
letters = {}

-- Everyone forgotten: the names not yet met go too.
Book().made[soldKey] = { id = 7006, name = "Linen Sash", t = mock.now, toName = "Kaeso Varro", how = "auction",
    handed = mock.now }
Book().got[7007] = { fromName = "Kaeso Varro", how = "auction", t = mock.now }
Book().bought["Linen Sash|Kaeso Varro"] = { name = "Linen Sash", fromName = "Kaeso Varro", t = mock.now }
ns.ForgetEverywhere(nil)
Eq(Book().made[soldKey].toName, nil, "a buyer's name outlived forgetting everyone")
Check(Book().made[soldKey].gone, "a craft sold to a forgotten name could be handed again")
Eq(Book().got[7007], nil, "a seller's name outlived forgetting everyone")
Eq(next(Book().bought), nil, "an auction won's seller outlived forgetting everyone")

--------------------------------------------------------------------------
Section("the book's bounds: what an auction win keeps, and how long")

-- A long-lived book stays bounded (the impact review, 28 Nov 2026): a
-- reagent bought is never noted, a consumable is (the user: who sold it is
-- worth keeping), an unknown name is asked again, and every table has a
-- cap or an age.
local book = Book()
wipe(book.made); wipe(book.got); wipe(book.bought)
mock.itemByName["Silk Cloth"], mock.itemInfo[7010] = 7010, { equipLoc = "", classID = 7 }
mock.itemByName["Healing Potion"], mock.itemInfo[7011] = 7011, { equipLoc = "", classID = 0 }
letters = { { "buyer", "Silk Cloth", "Garrick Fallow", 40 }, { "buyer", "Healing Potion", "Garrick Fallow", 25 } }
mock.fire("MAIL_INBOX_UPDATE")
letters = {}
Eq(book.bought["Silk Cloth|Garrick Fallow"], nil, "a reagent won at auction was noted")
local potion = book.bought["Healing Potion|Garrick Fallow"]
Eq(potion and potion.use, "consumable", "a consumable won at auction was not noted as one")
mock.fire("PLAYER_EQUIPMENT_CHANGED", 1, false)
mock.RunTimers()
Check(book.bought["Healing Potion|Garrick Fallow"], "a consumable went at an equipment change")

-- A name the client had no info for is asked again at the prune.
book.bought["Copper Bar|Garrick Fallow"] = { name = "Copper Bar", fromName = "Garrick Fallow", t = mock.now, use = "unknown" }
mock.itemByName["Copper Bar"], mock.itemInfo[7012] = 7012, { equipLoc = "", classID = 7 }
ns.Journey.Prune(mock.now)
Eq(book.bought["Copper Bar|Garrick Fallow"], nil, "an unknown win, a reagent once known, was kept")
Check(book.bought["Healing Potion|Garrick Fallow"], "the prune let a fresh consumable go")

-- The newest T.bought, the oldest going first.
wipe(book.bought)
for i = 1, CD.T.bought + 5 do
    book.bought["Item " .. i .. "|Seller"] = { name = "Item " .. i, fromName = "Seller", t = mock.now - 1000 + i, use = "gear" }
end
CD.Tidy(book, mock.now)
local count = 0
for _ in pairs(book.bought) do count = count + 1 end
Eq(count, CD.T.bought, "the auction wins past their cap")
Eq(book.bought["Item 1|Seller"], nil, "the cap kept the oldest win")
Check(book.bought["Item " .. (CD.T.bought + 5) .. "|Seller"], "the cap let the newest win go")
wipe(book.bought)

-- Crafts found or given up go after the buffer's days, whoever they went
-- to; one still waited on for someone in the diary stays.
local KEPT = "Player-1111-0000F00D"
ns.Characters.Observe(KEPT, { first = "Aulus", last = "Kept" })
ns.Diary.Add(KEPT, { source = "test" })
local old = mock.now - 10
book.made.found = { id = 1, t = old, to = KEPT, how = "trade", handed = old, met = old }
book.made.gone = { id = 2, t = old, how = "trade", handed = old, gone = true }
book.made.waiting = { id = 3, t = old, to = KEPT, how = "trade", handed = old }
book.got[7013] = { from = KEPT, how = "trade", t = old }
ns.Journey.Prune(mock.now + (ns.BufferDays() + 1) * T.DAY)
Eq(book.made.found, nil, "a craft found on them outlived the buffer")
Eq(book.made.gone, nil, "a craft given up outlived the buffer")
Check(book.made.waiting, "a craft waited on for someone in the diary was pruned")
Eq(book.got[7013], nil, "a got never put on outlived the buffer")

-- The whole book within T.book: the oldest handed go first, the ones in
-- hand stay.
wipe(book.made)
for i = 1, CD.T.book + 10 do
    book.made["h" .. i] = { id = 100 + i, t = old, to = KEPT, how = "trade", handed = old + i }
end
for i = 1, 5 do book.made["in" .. i] = { id = 900 + i, t = old } end
CD.Tidy(book, mock.now)
count = 0
for _ in pairs(book.made) do count = count + 1 end
Eq(count, CD.T.book, "the craft book past its cap")
Eq(book.made.h1, nil, "the cap kept the oldest hand-off")
for i = 1, 5 do Check(book.made["in" .. i], "the cap let a craft in hand go before the hand-offs") end
wipe(book.made)
ns.Diary.Remove(KEPT)

--------------------------------------------------------------------------
Section("after the reunion toast: what a connection reads")

-- Nearby's reunion toast (Capture/Nearby.lua) and this capture hear the
-- same nameplate. A connection puts what the unit shows on the person's
-- record (Characters.ObserveUnit), so it comes after the toast has taken
-- its snapshot: Features/CrafterDetection/Capture.lua is listed after
-- Capture/ in the TOC (as Witnesses' is). A diary entry known by their
-- first name only gave the user bracers, worn now, and comes into view:
-- the toast names them as the diary knew them, the connection reads their
-- surname after.
-- (the crafter toasts the sections above raised, once their kind is
-- registered (Toast.lua), shown and put away first: the reunion's card is
-- the one this looks at)
for _ = 1, 60 do mock.RunTimers() end
wipe(ns.UI.Toast.queue)
ns.Characters.Forget(NUMA.guid)
wipe(ns.db.meta.greeted)
ns.Characters.Observe(NUMA.guid, { first = "Numa" })
ns.Diary.Add(NUMA.guid, { source = "test" })
Eq(ns.Characters.FullName(NUMA.guid), "Numa", "setup: the diary knew their surname")
ns.Fire("SD_TRADE_COMPLETED", NUMA.guid, { { link = BRACERS, count = 1 } }, nil)
mock.equipped[9] = { link = BRACERS, quality = 2 }
mock.fire("PLAYER_EQUIPMENT_CHANGED", 9, false)
mock.RunTimers()
mock.SetUnit("nameplate5", NUMA)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
Eq(Rows(NUMA.guid, CD.YOURS), 1, "setup: no connection")
Eq(ns.Characters.FullName(NUMA.guid), "Numa Pompilius", "the connection did not read them")
local toast = ns.UI.ReunionShowing()
Eq(toast and toast.name, "Numa", "the toast's name: the connection was read before the toast took it")
mock.RunTimers()
