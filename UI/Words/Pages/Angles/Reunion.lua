-- Reunion and regular (PAGE-10): a diary entry back after a long gap, and
-- one met day after day.
--
-- reunion facts (the planner's, from People.Stats and Sessions.For)
--   who               the person (diary, or named)
--   gapDays           days since the last together-session before this one
--   usualGapDays      their median gap between sessions
--   longAbsence       gapDays is at least three times the usual gap
--   isRecordGap       no gap between us was ever longer
--   prevRecordDays    the longest gap before this one (with isRecordGap)
--   lastWhen          when that last session ended (a time)
--   lastZone          where it ended
--   lastGrouped       that last session was a group (not just nearby)
--   sameZoneAsLast    today's meeting was in lastZone
--   zone, subZone     where today's meeting was (the user's own position)
--   zoneNewForUs      we had never been in this zone together before
--   timesMet          meetings with them, today's included
--   firstZone         where we first met
--   firstMetDays      days since we first met
--   addedWhen         when they were written into the diary (a time)
--
-- regular facts
--   who, streakDays   met on this many days running, today included (2+)
--   zone              where today's meeting was

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("reunion", { order = { "gap", "history" },
    about = "a diary entry back after a long gap" })

--------------------------------------------------------------------------
-- gap: the sentence that says they are back, and how long it had been
--------------------------------------------------------------------------

Words("reunion", "gap", {
    must = { "gapDays" },

    stems = {
        "After {days:gapDays} apart, ",
        "After {days:gapDays} away, ",
        "After {days:gapDays} without crossing paths, ",
        "For the first time in {days:gapDays}, ",
        "{days.cap:gapDays} since we last crossed paths, and ",
        "{days.cap:gapDays} after I last saw {ref.obj}, ",
        "It had been {days:gapDays}, but ",
        "It had been {days:gapDays} since our last [session|time] together, and {today} ",
        { "After {days:gapDays} and no sign of {ref.obj}, ", needs = { "longAbsence" } },
        { "{days.cap:gapDays} after we last grouped, ", needs = { "lastGrouped" } },
        { "{days.cap:gapDays} after we parted {in:lastZone}, " },
        { "After the longest gap we've had, {days:gapDays}, ", needs = { "isRecordGap" }, says = { "record" } },
        { "Just when I'd started to wonder, ", needs = { "longAbsence" }, voice = "warm" },
        { "Just when I'd started to wonder, ", needs = { "longAbsence" }, voice = "wry" },
        { "Out of nowhere, after {days:gapDays}, ", needs = { "longAbsence" } },
        { "{days.cap:gapDays}. Then, {today}, ", voice = "terse" },
        { "Right on cue, after {days:gapDays}, ", voice = "wry" },
    },

    clauses = {
        "{ref} turned up again",
        "{ref} turned up",
        "{ref} was back",
        "{ref} was back again",
        "{ref} showed up again",
        "{ref} reappeared",
        "{ref} and I crossed paths again",
        "{ref} and I finally crossed paths again",
        "I <ranInto> {ref.obj} <again>",
        "I finally saw {ref.obj} again",
        "I saw {ref.obj} again",
        { "{ref} turned up {in:zone}", bonus = -1 },
        { "{ref} turned up {at:subZone}", bonus = -0.5 },
        { "{ref} was back, {at:subZone}, of all places", needs = { "zoneNewForUs" }, voice = "wry" },
        { "{ref} turned up {in:zone}, a place we'd never been together", needs = { "zoneNewForUs" } },
        { "{ref} turned up {in:zone} again, right where we'd parted", needs = { "sameZoneAsLast" }, says = { "lastZone" } },
        { "{ref} came back into my evening", needs = { "page.part==evening" }, voice = "warm" },
        { "{ref} was back, and it felt like no time had passed", voice = "warm" },
        { "{ref} wandered back into view", voice = "warm" },
        { "{ref} resurfaced", voice = "wry" },
        { "{ref} rejoined the living, as far as my diary is concerned", voice = "wry" },
        { "{ref} was back", voice = "terse" },
        "{ref} turned up again after {days:gapDays} away",
        "{ref} was back after {days:gapDays}",
        "{ref} turned up for the first time in {days:gapDays}",
        "I saw {ref.obj} for the first time in {days:gapDays}",
        "{ref} and I crossed paths for the first time in {days:gapDays}",
        "I <ranInto> {ref.obj} for the first time in {days:gapDays}",
        { "{ref} ended {dayadj.a:gapDays} absence", voice = "wry" },
        { "{ref} turned up {in:zone}, {days:gapDays} after we parted {in:lastZone}", needs = { "!sameZoneAsLast" } },
        { "{ref} was back {today}, {days:gapDays} after our last [session|time] together" },
        { "I hadn't seen {ref.obj} in {days:gapDays} until {today}" },
    },

    fragments = {
        "Ran into {ref.obj} again",
        "Ran into {ref.obj} {in:zone}",
        "{ref.short} again",
        "{ref.short}, at last",
        "Back with {ref.obj}",
        "Back in {ref.poss} company",
        "Crossed paths with {ref.obj} again",
        "Ran into {ref.obj} for the first time in {days:gapDays}",
        "First sight of {ref.obj} in {days:gapDays}",
        "Back with {ref.obj} after {days:gapDays}",
        "{ref.short} again, after {days:gapDays}",
        "{days.cap:gapDays} without {ref.obj}, and then there {he} was",
        "{days.cap:gapDays} of nothing, then {ref.short}",
        { "{ref.short}, finally", needs = { "longAbsence" }, voice = "terse" },
        { "{ref.short}. After {days:gapDays}", voice = "terse" },
        { "{ref.short} again. {days.cap:gapDays}", voice = "terse" },
        { "Reunited with {ref.obj} after {days:gapDays}", voice = "warm" },
        { "{ref.short}, back from wherever {he} had been", voice = "wry" },
    },

    tails = {
        ", after {days:gapDays} away",
        ", after {days:gapDays}",
        " after {days:gapDays}",
        ", the first time in {days:gapDays}",
        " for the first time in {days:gapDays}",
        ", {days:gapDays} after we last crossed paths",
        ", {days:gapDays} after our last [session|time] together",
        { ", {days:gapDays} after we last grouped", needs = { "lastGrouped" } },
        { ", {days:gapDays} after we parted {in:lastZone}", needs = { "!sameZoneAsLast" } },
        { ", {days:gapDays} after we parted in this very zone", needs = { "sameZoneAsLast" }, says = { "lastZone" } },
        { ", {days:gapDays} since I last saw {him}", bonus = -0.5 },
        { ", the longest we've gone without crossing paths", needs = { "isRecordGap" }, says = { "record" } },
        { ", our longest gap yet", needs = { "isRecordGap" }, says = { "record" } },
        { ", longer apart than we've ever been", needs = { "isRecordGap" }, says = { "record" } },
        { ", the longest stretch since we met {in:firstZone}", needs = { "isRecordGap" }, says = { "record" } },
        { ", a long time by our standards", needs = { "longAbsence" }, says = { "usual" } },
        { ", which is a long time for us", needs = { "longAbsence" }, says = { "usual" } },
        { ", when we usually cross paths every few days", needs = { "longAbsence", "usualGapDays<=4" }, says = { "usual" } },
        { ", when it's usually barely a week between meetings", needs = { "longAbsence", "usualGapDays<=7", "usualGapDays>4" }, says = { "usual" } },
        { ", back where we last were together, {in:lastZone}", needs = { "sameZoneAsLast" } },
        { " {in:zone}, of all places", needs = { "zoneNewForUs" }, voice = "wry" },
        { ", and in a zone we'd never shared before", needs = { "zoneNewForUs" }, says = { "zone" } },
        { ", and I was glad of it", voice = "warm" },
        { ", which made my {part}", voice = "warm" },
        { ", like a bad penny", voice = "wry" },
        { ", just as I'd almost given up on {him}", needs = { "longAbsence" }, voice = "wry" },
    },

    wholes = {
        "{ref} turned up again {today}, {days:gapDays} after we last crossed paths.",
        "It had been {days:gapDays} since I last saw {ref.obj}, and {today} {he} was back.",
        "I hadn't seen {ref.obj} in {days:gapDays}. {today.cap}, there {he} was.",
        "{ref} was back {today}. It had been {days:gapDays}.",
        "{ref} was back {today}, the first time in {days:gapDays}.",
        "{days.cap:gapDays} after our last time together, {ref} turned up again.",
        "{today.cap} ended {dayadj.a:gapDays} stretch without {ref.obj}.",
        { "The last time I saw {ref.obj} was {when:lastWhen}. {today.cap}, {he} was back.", says = { "gapDays" } },
        { "The last time we'd been together was {when:lastWhen}, {in:lastZone}. {today.cap}, {ref} turned up again.", says = { "gapDays" } },
        { "{ref} turned up {today}. The last time was {when:lastWhen}.", says = { "gapDays" } },
        { "{ref} was back {today}, for the first time since {date:lastWhen}.", says = { "gapDays" } },
        { "We hadn't crossed paths since {date:lastWhen}, {in:lastZone}, but {today} {ref} was back.", says = { "gapDays" } },
        { "{days.cap:gapDays}. That's how long it had been since {ref} and I last crossed paths.", needs = { "longAbsence" } },
        { "{days.cap:gapDays} without {ref.obj}, our longest gap yet, and then {today} {he} was back.", needs = { "isRecordGap" }, says = { "record" } },
        { "Our longest gap yet ended {today}: {days:gapDays} after we last crossed paths, {ref} was back.", needs = { "isRecordGap" }, says = { "record" } },
        { "{ref} and I had never gone {days:gapDays} without crossing paths until now. {today.cap}, that ended.", needs = { "isRecordGap" }, says = { "record" } },
        { "The longest we'd gone without crossing paths had been {days:prevRecordDays}. This time it was {days:gapDays}, and then {ref} turned up.", needs = { "isRecordGap" }, says = { "record" } },
        { "{ref} turned up {today} {in:zone}, a zone we'd never shared, {days:gapDays} after we last crossed paths.", needs = { "zoneNewForUs" } },
        { "{days.cap:gapDays} after we parted {in:lastZone}, I <ranInto> {ref.obj} there again.", needs = { "sameZoneAsLast" } },
        { "{ref} turned up again {today} after {days:gapDays}, and it was good to see {him}.", voice = "warm" },
        { "After {days:gapDays} I'd started to miss {ref.obj}. {today.cap}, {he} was back.", needs = { "longAbsence" }, voice = "warm" },
        { "{ref} was back {today}. {days.cap:gapDays} is too long.", voice = "warm" },
        { "{days.cap:gapDays} apart, and then {ref} simply turned up. I was glad.", voice = "warm" },
        { "After {days:gapDays} I'd half assumed {ref} had quit. Apparently not.", needs = { "longAbsence" }, voice = "wry" },
        { "{ref} returned {today} from wherever {he} had spent the last {daysx:gapDays}.", voice = "wry" },
        { "{ref} lives. Back {today} after {days:gapDays}.", needs = { "longAbsence" }, voice = "wry" },
        { "{days.cap:gapDays} and not a sign of {ref.obj}. Then {today}, there {he} was.", voice = "wry" },
        { "{ref.short}, back. {days.cap:gapDays}.", voice = "terse" },
        { "{ref.short} again, after {days:gapDays}.", voice = "terse" },
        { "{days.cap:gapDays} gone, then {ref.short}.", voice = "terse" },
    },
})

--------------------------------------------------------------------------
-- history: a second sentence about how far back we go
--------------------------------------------------------------------------

Words("reunion", "history", {
    wholes = {
        "We first met {in:firstZone}, {ago:firstMetDays}.",
        "We go back {days:firstMetDays}, to {v:firstZone}.",
        "{ref} and I go back {days:firstMetDays}, to {v:firstZone}.",
        "We've known each other since {v:firstZone}, {days:firstMetDays} now.",
        "It all started {in:firstZone}, {ago:firstMetDays}.",
        "Our first meeting was {in:firstZone}, {ago:firstMetDays}.",
        { "That makes {count:timesMet:time} we've crossed paths.", needs = { "timesMet>=3" } },
        { "That's {count:timesMet:meeting} now, all told.", needs = { "timesMet>=3" } },
        { "It was our {nth:timesMet} time together.", needs = { "timesMet>=2", "timesMet<=40" } },
        { "Counting {today}, we've crossed paths {times:timesMet}.", needs = { "timesMet>=3" } },
        { "Our {nth:timesMet} meeting, by the diary's count.", needs = { "timesMet>=3", "timesMet<=40" } },
        { "{count.cap:timesMet:meeting} since {v:firstZone}, {days:firstMetDays} ago.", needs = { "timesMet>=3" } },
        { "We've met {times:timesMet} since {v:firstZone}.", needs = { "timesMet>=3" } },
        "The last time had been {when:lastWhen}, {in:lastZone}.",
        "Before {today}, we'd last been together {in:lastZone}, {when:lastWhen}.",
        "Last time, it was {v:lastZone}, {when:lastWhen}.",
        { "We'd last grouped {in:lastZone}, {when:lastWhen}.", needs = { "lastGrouped" } },
        { "The previous longest had been {days:prevRecordDays}.", needs = { "isRecordGap" } },
        { "Before this, the longest we'd gone was {days:prevRecordDays}.", needs = { "isRecordGap" } },
        { "Usually we cross paths every few days.", needs = { "usualGapDays<=4", "longAbsence" } },
        { "Usually it's not much more than a week between meetings.", needs = { "usualGapDays>4", "usualGapDays<=8", "longAbsence" } },
        { "{ref} has been in my diary since {date:addedWhen}.", needs = { "addedWhen" } },
        { "{ref} went into my diary {when:addedWhen}.", needs = { "addedWhen" } },
        { "I wrote {ref.obj} into this diary {when:addedWhen}, and {he} has stayed in it.", voice = "warm" },
        { "We go back {days:firstMetDays}, all the way to {v:firstZone}. That counts for something.", voice = "warm" },
        { "{count.cap:timesMet:meeting} in, I still look forward to the next.", needs = { "timesMet>=5" }, voice = "warm" },
        { "{count.cap:timesMet:meeting} since {v:firstZone}. I'd call that a habit.", needs = { "timesMet>=8" }, voice = "wry" },
        { "We met {in:firstZone}, {ago:firstMetDays}, and I'm still not rid of {him}.", voice = "wry" },
        { "First met {in:firstZone}. {count.cap:timesMet:meeting} since.", needs = { "timesMet>=3" }, voice = "terse" },
        { "Last time: {v:lastZone}, {when:lastWhen}.", voice = "terse" },
    },
})

--------------------------------------------------------------------------
-- regular: day after day
--------------------------------------------------------------------------

Pages.Angle("regular", { order = { "streak" }, about = "met day after day" })

Words("regular", "streak", {
    must = { "streakDays" },

    stems = {
        "For the {nth:streakDays} day running, ",
        "{nth.cap:streakDays} day in a row, and ",
        "Another day, and ",
        "{nth.cap:streakDays} day running: ",
        { "Like clockwork, ", voice = "wry" },
        { "As has become the habit, ", voice = "warm" },
    },

    clauses = {
        "{ref} was there again",
        "{ref} turned up again",
        "I <ranInto> {ref.obj} <again>",
        "{ref} and I crossed paths again",
        "{ref} and I ended up together again",
        "{ref} and I were at it again",
        { "{ref} was around again {in:zone}" },
        "{ref} turned up for the {nth:streakDays} day running",
        "I saw {ref.obj} for the {nth:streakDays} day in a row",
        "{ref} and I crossed paths for the {nth:streakDays} day running",
        { "{ref} kept the streak going, {count:streakDays:day} now", voice = "wry" },
        { "{ref} was there for the {nth:streakDays} day running, which I'm starting to count on", voice = "warm", final = true },
    },

    fragments = {
        "{ref.short} again",
        "{ref.short} again, the {nth:streakDays} day running",
        "{ref.short}, {nth:streakDays} day in a row",
        "{nth.cap:streakDays} day running with {ref.obj}",
        "{count.cap:streakDays:day} running now with {ref.obj}",
        "Another day, another {part} with {ref.obj}",
        { "{ref.short}. Day {num:streakDays}", voice = "terse" },
        { "{ref.short}, as ever", voice = "wry" },
    },

    tails = {
        ", the {nth:streakDays} day running",
        ", {nth:streakDays} day in a row",
        " for the {nth:streakDays} day running",
        ", {count:streakDays:day} running now",
        { ", which is becoming a habit", voice = "wry" },
        { ", and I'm not complaining", voice = "warm" },
        { " {in:zone} this time", bonus = -0.5 },
    },

    wholes = {
        "{ref} again {today}: {count:streakDays:day} running now.",
        "{nth.cap:streakDays} day in a row with {ref.obj}.",
        "{ref} and I crossed paths again {today}, {count:streakDays:day} running.",
        "That's {count:streakDays:day} running with {ref.obj}.",
        { "{ref} again. {count.cap:streakDays:day} running; I may have to start setting a place for {him}.", voice = "wry" },
        { "{ref} for the {nth:streakDays} day running. I'm getting used to the company.", voice = "warm" },
        { "{ref.short}, day {num:streakDays}.", voice = "terse" },
    },
})
