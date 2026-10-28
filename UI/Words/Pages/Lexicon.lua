-- Shared words for the pages (PAGE-3): the leads that join one sentence to
-- the one before, and banks of interchangeable phrases any angle can draw
-- on with <name>.
--
-- A bank's entries must be interchangeable where the bank is used: every
-- entry of <ranInto> takes an object after it, so "I <ranInto> {ref.obj}"
-- reads whichever is drawn. The comment over each bank says what its
-- entries are, so new ones keep to it.

local addonName, ns = ...

local Pages = ns.Pages
local Bank, Lead = Pages.Bank, Pages.Lead

--------------------------------------------------------------------------
-- Leads
--------------------------------------------------------------------------
--
-- A lead opens a clause that follows another sentence: "Later, " + "we
-- found Mor'Ladim". Empty entries are leads too: most sentences need none,
-- and a page where every sentence starts "Later," reads like a log.

-- What happened next.
Lead("then", "lead.then")
Bank("lead.then", {
    "", "", "",
    "Later, ", "Later on, ", "After that, ", "Then ", "A while later, ",
    "Further on, ", "Not long after, ",
    { "Afterwards, ", voice = "warm" },
    { "Then, ", voice = "terse" },
    { "Next thing I knew, ", voice = "wry" },
})

-- More of the same kind, no order implied.
Lead("also", "lead.also")
Bank("lead.also", {
    "", "", "", "",
    "And ", "On top of that, ", "Besides that, ",
    { "What's more, ", voice = "warm" },
    { "For good measure, ", voice = "wry" },
})

-- Against what came before.
Lead("but", "lead.but")
Bank("lead.but", {
    "But ", "Still, ", "Even so, ", "That said, ", "Then again, ",
    { "Mind you, ", voice = "wry" },
    { "But ", voice = "terse" },
})

-- Because of what came before.
Lead("so", "lead.so")
Bank("lead.so", {
    "So ", "Which meant ", "As a result, ",
    { "Naturally, ", voice = "wry" },
    { "So ", voice = "terse" },
})

-- At the same time, somewhere else.
Lead("meanwhile", "lead.meanwhile")
Bank("lead.meanwhile", {
    "Meanwhile, ", "Elsewhere, ", "In between, ", "Along the way, ",
})

-- Earlier than what came before.
Lead("before", "lead.before")
Bank("lead.before", {
    "Earlier, ", "Before that, ", "Earlier on, ", "Before all that, ",
})

-- Towards the end of a stretch together.
Lead("end", "lead.end")
Bank("lead.end", {
    "By the end, ", "In the end, ", "Towards the end, ", "Before we parted, ",
    "Before we split, ", "Just before we went our ways, ",
})

-- Turning to someone else entirely, at a paragraph's start.
Lead("turn", "lead.turn")
Bank("lead.turn", {
    "", "", "As for the rest, ", "Otherwise, ", "Apart from that, ",
})

--------------------------------------------------------------------------
-- Verb banks (past tense, transitive: an object follows)
--------------------------------------------------------------------------

-- Meeting someone by chance.
Bank("ranInto", {
    "ran into", "bumped into", "crossed paths with", "came across", "ran across",
    { "stumbled on", voice = "wry" },
})

-- Grouping up with someone.
Bank("groupedWith", {
    "grouped with", "teamed up with", "joined up with", "partied up with",
    "fell in with",
})

-- Seeing someone without dealing with them.
Bank("noticed", {
    "saw", "spotted", "caught sight of", "noticed",
})

--------------------------------------------------------------------------
-- Little phrases
--------------------------------------------------------------------------

-- "again" in its many forms, for the end of a clause.
Bank("again", {
    "again", "again", "once more", "yet again",
})

-- The narrator's own small reactions, as whole short sentences. Feelings
-- here are the diarist's, never anyone else's.
Bank("glad", {
    "Good to see a familiar face.", "Nice to have the company.",
    { "It was good to see a friendly face.", voice = "warm" },
    { "I'd missed that.", voice = "warm" },
    { "Not a bad way to spend a {part}.", voice = "wry" },
})

Bank("relief", {
    "I won't forget that one.", "Too close.", "That was close.",
    { "I owe one there.", voice = "warm" },
    { "I'll take it.", voice = "wry" },
    { "Close.", voice = "terse" },
})

Bank("grumble", {
    "Annoying.", "Not my favourite moment.",
    { "Rude.", voice = "wry" },
    { "Lesson noted.", voice = "terse" },
})
