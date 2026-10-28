-- Facts for the chat angle: whispers one way, the other, or both, with or
-- without a meeting, first-ever or not; and short lines, mine or theirs,
-- on every channel. Whispers come with a name; a line in /say or a yell
-- may come from someone unnamed.
local QUOTES = {
    "anyone know where the quest giver is?",
    "ty for the heal!",
    "lfg deadmines",
    "need one more for the cave, you in?",
    "thanks for the rez",
    "watch out, patrol coming",
    "where do you get the boat to Menethil?",
    "gl with the levelling",
    "brb, dinner",
    "that was close",
    "inc two from the left",
    "anyone selling linen?",
    "want to group for the ogres?",
    "nice duel, gg",
    "any idea where the last camp is?",
    "sorry, my bad",
    "heading in now, wish me luck",
    "see you tomorrow",
    "is this the line for the boat?",
    "I'll tank if someone heals",
    "have fun out there",
    "careful, elite up the hill",
    "good luck with the quest!",
    "does anyone have a spare bag?",
    "omw",
    "hold on, drinking",
    "gg all",
    "where are the murlocs for this one?",
    "thanks, you're a lifesaver",
    "back in five",
}

return {
    angle = "chat",
    n = 1200,
    gen = function(P)
        local channel = P.pick({ "whisper", "whisper", "whisper", "say", "say", "party", "party", "yell" })
        local fromMe = P.chance(0.35)
        local inn = P.pick({ 0, 1, 1, 2, 3, 5, 8 })
        local out = P.pick({ 0, 0, 1, 2, 3, 6 })
        -- A whispered line needs a whisper that way.
        if channel == "whisper" then
            if fromMe and out == 0 then out = 1 end
            if not fromMe and inn == 0 then inn = 1 end
        end
        -- Sometimes a line out loud and no whispers at all: then the heard
        -- move has nothing to say and is skipped.
        if channel ~= "whisper" and P.chance(0.15) then inn, out = 0, 0 end
        if channel == "whisper" and inn + out == 0 then inn = 1 end
        -- Whispers always carry a name; a voice in /say may not.
        local whispered = inn + out > 0
        local who = P.person({ named = whispered or P.chance(0.4), hostile = false })
        if not who.diary and not who.named then who.familiar = P.chance(0.3) or nil end
        return {
            who = who,
            whispersIn = inn,
            whispersOut = out,
            -- Only whispers today: a line in /say, a yell or party chat means
            -- we were together, so no meeting is only possible by whisper.
            noMeeting = whispered and channel == "whisper" and P.chance(0.5),
            firstWhisper = whispered and P.chance(0.3),
            quote = P.pick(QUOTES),
            fromMe = fromMe,
            channel = channel,
        }
    end,
}
