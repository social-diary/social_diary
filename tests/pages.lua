-- The journal's page registry (UI/Journal/Pages.lua) and the settings'
-- sections (UI/Settings/Page.lua), with pages and sections of the test's
-- own: registered before the book is made, they get a ribbon or a row, are
-- built, turned to, refreshed and placed in the stack like the diary's own;
-- one taken out again leaves no trace. That every ribbon page has a cut-out
-- in the front matter's contents and a ribbon on the parcel's closed book
-- is checked with the diary's own pages alone, in tests/settings.lua.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local J = ns.UI.Journal
local SettingsUI = ns.UI.Settings

local function Keys(list)
    local out = {}
    for _, spec in ipairs(list) do out[#out + 1] = spec.key end
    return table.concat(out, " ")
end

-- The error a call raises, without the file and line assert puts first,
-- or nil where it went through.
local function Refused(fn, ...)
    local ok, err = pcall(fn, ...)
    if ok then return nil end
    return (tostring(err):gsub("^[^:]*:%d+: ", ""))
end

local function Build() end

--------------------------------------------------------------------------
Section("the journal's own pages")

Eq(Keys(J.Ribbons()), "journey people nearby settings", "the ribbons, left to right")
Eq(J.Ribbons()[3].colour .. " " .. J.Ribbons()[3].label, "purple Recently nearby", "a ribbon's cloth and words")
Eq(Keys(J.BuildOrder()), "people frontispiece front journey nearby settings",
    "the pages are not built in the book's old order (the golden dump's frames follow it)")
Eq(Keys(J.PagesByKey()), "front frontispiece journey nearby people settings", "the containers' order")
Eq(J.Page("frontispiece").flyleaf, 0, "the frontispiece is not the first leaf")
Eq(J.Page("front").flyleaf, 1, "the front matter is not the second leaf")
Eq(J.Page("front").ribbon, nil, "a flyleaf with a ribbon")
Eq(J.Page("people").leaf, 2, "People does not lie second")
Eq(J.Page("settings").leaf, -1, "the settings do not lie last")
Check(J.Page("people").leaves ~= nil, "People has no leaf inside it")
local stacked, flyleaves = J.StackCounts()
Eq(stacked .. "/" .. flyleaves, "4/2", "four pages in the stack, two before it")

--------------------------------------------------------------------------
Section("what a page must say")

Check(Refused(J.RegisterPage, "bad", { flyleaf = 0 }):find("no build"), "a page without a build")
Check(Refused(J.RegisterPage, "bad", { build = Build }):find("flyleaf"), "a page neither ribbon nor flyleaf")
Check(Refused(J.RegisterPage, "bad", { build = Build, flyleaf = 2 }):find("flyleaf"), "a third flyleaf")
Check(Refused(J.RegisterPage, "bad", { build = Build, ribbon = { colour = "red", label = "Bad" } })
    :find("leaf"), "a ribbon page without a leaf")
Check(Refused(J.RegisterPage, "bad", { build = Build, ribbon = { colour = "red" }, leaf = 3 })
    :find("colour, label"), "a ribbon without words")
Check(Refused(J.RegisterPage, "bad", { build = Build, ribbon = { colour = "red", label = "Bad" }, leaf = 0 })
    :find("leaf"), "a ribbon page at leaf 0")
Check(Refused(J.RegisterPage, "bad", { build = Build, flyleaf = 1, leaf = 3 }):find("no leaf"),
    "a flyleaf in the stack")
Check(Refused(J.RegisterPage, "bad", { build = Build, flyleaf = 1, refresh = 3 }):find("refresh"),
    "a refresh that is not a function")
Eq(J.Page("bad"), nil, "a refused page was kept")

--------------------------------------------------------------------------
Section("the settings' sections, and what a section must say")

Eq(Keys(SettingsUI.Sections()), "recording interface toasts shortcuts dungeons sounds integrations memory about",
    "the sections, in the order the left page lists them")
Eq(SettingsUI.Sections()[3].parent, "interface", "Toasts is not Interface's subpage")
Check(Refused(SettingsUI.RegisterSection, "bad", { label = "Bad", about = "x" }) ~= nil, "a section without a build")
Check(Refused(SettingsUI.RegisterSection, "bad", { about = "x", build = Build }) ~= nil, "a section without a name")
Check(Refused(SettingsUI.RegisterSection, "bad", { label = "Bad", about = "x", build = Build, parent = 3 }) ~= nil,
    "a subpage of a number")

-- A section of the test's own, between Sounds and Integrations, and one
-- taken out again before the page is built. Built with the book below.
local section
SettingsUI.RegisterSection("test", { order = 35, label = "Test section", about = "Only for the tests",
    build = function(pane, c)
        section = { pane = pane, c = c }
        c:Heading("Tested")
    end })
SettingsUI.RegisterSection("gone", { order = 36, label = "Gone", about = "Taken out",
    build = function() section.gone = true end })
Eq(Keys(SettingsUI.Sections()), "recording interface toasts shortcuts dungeons sounds test gone integrations memory about",
    "the test's sections not in their order")
Check(SettingsUI.RemoveSection("gone") ~= nil, "a section taken out was not found")
Eq(Keys(SettingsUI.Sections()), "recording interface toasts shortcuts dungeons sounds test integrations memory about",
    "a section taken out is still listed")

--------------------------------------------------------------------------
Section("a page of the test's own: its ribbon, build, refresh and leaf")

local built, refreshed, goneBuilt = nil, 0, false
J.RegisterPage("test", {
    order = 35, ribbon = { colour = "red", label = "Test page" }, leaf = -3,
    build = function(container, panel)
        built = { container = container, panel = panel, frame = CreateFrame("Frame", nil, container) }
    end,
    refresh = function(...)
        refreshed = refreshed + 1
        Eq(select("#", ...), 0, "a page's refresh was handed something")
    end,
})
-- Registered and taken out again before the book is made: no trace.
J.RegisterPage("gone", { order = 5, ribbon = { colour = "green", label = "Gone" }, leaf = 3,
    build = function() goneBuilt = true end })
Eq(Keys(J.Ribbons()), "gone journey people nearby test settings", "the page's ribbon not in its order")
Check(J.RemovePage("gone") ~= nil, "a page taken out was not found")
Eq(J.RemovePage("gone"), nil, "a page taken out twice")
Eq(Keys(J.Ribbons()), "journey people nearby test settings", "the ribbons with the test's page")
Eq(Keys(J.BuildOrder()), "people frontispiece front journey nearby settings test",
    "a page that says no buildOrder is not built after the others")
Eq(J.StackCounts(), 5, "the test's page not in the stack")

-- The order the book builds them in, as it is made.
local madeOrder = {}
for _, spec in ipairs(J.Pages()) do
    local build = spec.build
    spec.build = function(...)
        madeOrder[#madeOrder + 1] = spec.key
        return build(...)
    end
end
ns.UI.ShowJournal()
local book = J.journal
Eq(table.concat(madeOrder, " "), "people frontispiece front journey nearby settings test",
    "the book did not build its pages in their build order")
-- The containers were made by key, before any page was built into one.
local made = {}
for i, frame in ipairs(T.mock.frames) do made[frame] = i end
local containers = {}
for _, spec in ipairs(J.PagesByKey()) do containers[#containers + 1] = made[book.views[spec.key]] end
for i = 2, #containers do
    Eq(containers[i], containers[i - 1] + 1, "the containers were not made one after another, by key")
end
Check(built and built.container == book.views.test and built.panel == book, "the page was not built into its container")
Check(not goneBuilt and book.views.gone == nil and book.ribbons.gone == nil, "a page taken out was built")
Eq(refreshed, 0, "a page refreshed while another was open")

-- Its ribbon hangs between Recently nearby's and the settings', which
-- move along by one.
local function X(key) return book.ribbons[key].recorded.points[1].args[3] end
Check(book.ribbons.test and book.ribbons.test.label == "Test page", "the page has no ribbon")
Eq(X("journey") .. " " .. X("people") .. " " .. X("nearby") .. " " .. X("test") .. " " .. X("settings"),
    "90 120 150 180 210", "the ribbons' places")

-- Pulled, it turns the book to the page and refreshes it.
book.ribbons.test:Click()
Eq(ns.UI.JournalView(), "test", "the ribbon did not turn to the page")
Eq(J.view, "test", "the open page is not J.view")
Check(book.views.test:IsShown() and not book.views.journey:IsShown() and not book.views.people:IsShown(),
    "more or less than the page shown")
Check(book.ribbons.test.active and not book.ribbons.journey.active, "the page's ribbon is not marked")
Eq(refreshed, 1, "the page was not refreshed as it opened")
Check(ns.UI.JournalShowing("test"), "JournalShowing does not know the page")

-- Third from the back: under it on the right, the settings, Recently
-- nearby and the flyleaves.
local function Stack() return book.book.stackPages[1] .. "/" .. book.book.stackPages[2] end
local pages = math.min(25, 5 + ns.Diary.Count())
Eq(Stack(), (pages - 3) .. "/" .. (2 + 2), "the page's place in the stack")
ns.UI.SetJournalView("settings")
Eq(Stack(), (pages - 1) .. "/2", "the settings' place with the test's page in the book")
ns.UI.SetJournalView("journey")
Eq(Stack(), "0/" .. (2 + pages - 1), "Your Diary's place with the test's page in the book")
ns.UI.SetJournalView("frontispiece")
Eq(Stack(), "0/" .. (2 + pages + 1), "the frontispiece's place with the test's page in the book")

-- A key no page has is not turned to; the book is made once.
ns.UI.SetJournalView("test")
ns.UI.SetJournalView("gone")
Eq(ns.UI.JournalView(), "test", "a page taken out was turned to")
Eq(refreshed, 2, "the page was not refreshed as it opened again")
Check(Refused(J.RegisterPage, "late", { flyleaf = 0, build = Build }):find("already made"),
    "a page registered after the book was made")
Check(Refused(J.RemovePage, "test"):find("already made"), "a page taken out after the book was made")
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("a section of the test's own: its row, its pane, turned to")

local P = ns.UI.SettingsPage()
Check(section and section.pane == P.panes.test, "the section was not built into its pane")
Check(section.c and section.c.Heading ~= nil, "the section was not handed its column")
Eq(P.panes.test.title:GetText(), "TEST SECTION", "the pane's heading")
Eq(P.panes.test.about:GetText(), "Only for the tests", "the pane's small print")
Check(not section.gone and P.nav.gone == nil and P.panes.gone == nil, "a section taken out was built")
Eq(P.nav.test.label:GetText(), "Test section", "the section's row")
Check(P.nav.test.about ~= nil, "a section's row without its small print")

-- Its row between Sounds' and Integrations', which moves down for it.
local function Y(key) return -P.nav[key].recorded.points[1].args[2] end
Check(Y("sounds") < Y("test") and Y("test") < Y("integrations"), "the section's row is out of order: "
    .. Y("sounds") .. " " .. Y("test") .. " " .. Y("integrations"))
Eq(Y("integrations") - Y("test"), Y("test") - Y("sounds"), "the rows are not evenly spaced round it")

Eq(P:Section(), "recording", "the first section is not open to begin with")
P.nav.test:Click()
Eq(P:Section(), "test", "clicking the section did not open it")
Check(P.panes.test:IsShown() and not P.panes.recording:IsShown(), "the panes did not swap")
P:ShowSection("gone")
Eq(P:Section(), "test", "a section taken out was opened")
Check(Refused(SettingsUI.RegisterSection, "late", { label = "Late", about = "x", build = Build })
    :find("already built"), "a section registered after the page was built")
Check(Refused(SettingsUI.RemoveSection, "test"):find("already built"), "a section taken out after the page was built")

--------------------------------------------------------------------------
Section("what the pages share: a turn to another page, a tooltip's list")

-- J.TurnTo (UI/Journal/Book.lua): the sound of a page turning, then the
-- page, as every link and corner that leads elsewhere did by hand.
ns.UI.ShowJournal()
T.mock.sounds = {}
J.TurnTo("nearby")
Eq(#T.mock.sounds, 1, "a turn to another page made no sound (or more than one)")
Eq(ns.UI.JournalView(), "nearby", "a turn did not open the page")
J.TurnTo("journey")
ns.UI.CloseJournal()
T.mock.sounds = {}

-- Style.TipList (UI/Style/Widgets.lua): the shape the cards' tooltips had
-- by hand, the title in the tooltip's colour, each line white and wrapped;
-- `into` adds to a list already begun (the campfire slip's).
local function Shape(list)
    local out = {}
    for _, line in ipairs(list) do
        local parts = {}
        for i = 1, 5 do parts[i] = tostring(line[i]) end
        out[#out + 1] = table.concat(parts, ",")
    end
    return table.concat(out, " | ")
end
Eq(Shape(ns.Style.TipList("Title", { "one", "two" })),
    "Title,nil,nil,nil,nil | one,1,1,1,true | two,1,1,1,true", "a tooltip's list")
Eq(Shape(ns.Style.TipList("Title")), "Title,nil,nil,nil,nil", "a tooltip's list without lines")
local into = ns.Style.TipList("First", { "a" })
Check(ns.Style.TipList("Second", { "b" }, into) == into, "a list added to is not the list returned")
Eq(Shape(into), "First,nil,nil,nil,nil | a,1,1,1,true | Second,nil,nil,nil,nil | b,1,1,1,true",
    "two titles and their lines in one list")
