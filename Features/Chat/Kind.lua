-- Chat (INT-1, INT-3, INT-4): whispers both ways, /say, /yell and party
-- lines, each a row on the person who said it. A feature in a folder of
-- its own (.claude/skills/new-feature/folder.md), and the
-- first that is a People row and nothing else: no route list, no moment on
-- the plates, no mark, no margin note, no caption words.
--
--   Kind.lua     what a line of chat is to the diary: its five row kinds,
--                their words and icons on the timeline, and the bubbles'
--                colours
--   Capture.lua  the chat events listened to, and who is worth a row
--   Dev.lua      its part of /sd testdata: Tester's whispers (never
--                packaged)
--
-- Everything is registered into the core's and the UI's registries, so no
-- file outside this folder names a chat row's kind. Its own names are on
-- ns.Chat, made here, the first of its files the TOC loads.
--
-- What stays core, because it is the diary's substrate and not this
-- feature's detection:
--   - chat text as such, driven by a kind's `chat` flag (Core/Rows.lua):
--     the excerpt's cap and TrimExcerpts in Core/Interactions.lua, the
--     storeChat and chatLines settings and their switches in
--     UI/Settings/Sections/Recording.lua;
--   - the chat events' plumbing, ns.OnChat and ns.ChatHandler
--     (Core/Events.lua), and the restricted-chat rule (ns.SafeGUID);
--   - the Nearby engine's own ears, Capture/Sightings.lua's FromChat
--     (people heard in /say and /yell are sightings, whoever they are);
--   - the timeline's activity "chat" and its headline words ("Chatted",
--     "N messages"), keyed by activity, not by row kind
--     (UI/Words/Timeline.lua), and the "talk" bubble they share with a
--     /say;
--   - ns.Recent's "whisper" (Core/Candidates.lua: the picker's "last
--     whisperer"), which Capture.lua sets through ns.Recent.Set.
--
-- This file: the five kinds, whole (Core/Rows.lua's spec in one call
-- each, words and icon included), and the whisper and party bubbles.

local addonName, ns = ...

local Chat = {}
ns.Chat = Chat

--------------------------------------------------------------------------
-- The People rows
--------------------------------------------------------------------------
--
-- Each carries chat text (`chat`: kept only while chat storage is on, and
-- trimmed to the chat lines setting), leaves a "talk" mark on Recently
-- nearby's day, and is the timeline's "chat" activity: chatter, folded
-- into an exchange or a session, never a line of its own.
--
--   whisper_in, whisper_out  contact from anywhere: never "last seen", never
--                            opens a together session; makes a person matter
--   say                      within earshot: "last seen", opens a session
--                            with a diary entry, makes a person matter
--   yell                     within earshot as /say, but heard across a
--                            camp: it does not make a person matter
--   party                    a grouped conversation; the group itself is
--                            what opened the session
--
-- Their words: 'They whispered: "ty! inviting"', 'Said in party: "ok"', or
-- the bare verb where the text was not kept.

local Quote = ns.UI.TimelineText.Quote

ns.Rows.Register("whisper_in", { chat = true, plate = 7, dealt = "talk", matters = true, activity = "chat",
    text = function(row) return Quote(row.excerpt, "They whispered") end,
    icon = "whisper" })
ns.Rows.Register("whisper_out", { chat = true, plate = 7, dealt = "talk", matters = true, activity = "chat",
    text = function(row) return Quote(row.excerpt, ns.UI.Format.You(row.me, "{You} whispered")) end,
    icon = "whisper" })
ns.Rows.Register("say", { chat = true, plate = 7, proximity = true, opens = true, dealt = "talk", matters = true,
    activity = "chat",
    text = function(row) return Quote(row.excerpt, "Said") end,
    icon = "talk" })
ns.Rows.Register("yell", { chat = true, plate = 7, proximity = true, opens = true, dealt = "talk", activity = "chat",
    text = function(row) return Quote(row.excerpt, "Yelled") end,
    icon = "talk" })
ns.Rows.Register("party", { chat = true, plate = 7, dealt = "talk", activity = "chat",
    text = function(row) return Quote(row.excerpt, "Said in party") end,
    icon = "party" })

--------------------------------------------------------------------------
-- The bubbles
--------------------------------------------------------------------------
--
-- A /say is the plain bubble ("talk", the core's: the chat activity's
-- icon too). A whisper and a party line are the same bubble in the chat's
-- own colour for them, so a player who changed it sees theirs; the
-- fallback is the client's default.

-- A tint (Style.AddArt's third argument) that reads `chatType`'s colour off
-- the client's chat settings each time it is asked, falling back to r, g, b.
function Chat.Colour(chatType, r, g, b)
    return function()
        local info = ChatTypeInfo and ChatTypeInfo[chatType]
        if info and info.r then return info.r, info.g, info.b end
        return r, g, b
    end
end

ns.Style.AddArt("whisper", { "Interface\\GossipFrame\\GossipGossipIcon" }, Chat.Colour("WHISPER", 1, 0.5, 1))
ns.Style.AddArt("party", { "Interface\\GossipFrame\\GossipGossipIcon" }, Chat.Colour("PARTY", 0.667, 0.667, 1))
