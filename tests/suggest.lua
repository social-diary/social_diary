-- Suggest a better wording (UI/Windows/Suggest/) and the translation's
-- notice (UI/Journal/Hints.lua's "translation"): nothing of either on an
-- English diary; the reverse lookup (exact, template, positional template,
-- plural, gendered, nothing); the issue's address, encoded and cut short;
-- the walk that finds the line under the cursor; the strip, when it is out;
-- picking, and every way it ends; the sheet and its link; the notice once
-- per language, its switch, and its link with the pad in hand; the hints'
-- record taking its new field on an old-shaped table; the strip's own
-- switch (showSuggestStrip, on Settings > Language where a translation is
-- read): on by default, an old table given it, the strip away and back at
-- once, the notice's link untouched, the row with the mouse and the pad,
-- and no row on English or without the folder.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq

--------------------------------------------------------------------------
Section("an English diary: no strip, no notice")

local ns = T.Boot()
Eq(ns.Locale.id, "enUS", "the test's first client reads English")
ns.UI.ShowJournal()
Check(ns.UI.Suggest ~= nil, "the folder's module is there")
Eq(ns.UI.Suggest.Strip.Frame(), nil, "a strip on an English diary")
Eq(ns.UI.Suggest.Available(), false, "picking offered on an English diary")
Eq(ns.Hints.Get("translation").eligible(), false, "the translation's notice on an English diary")
ns.UI.Suggest.Strip.Update()
Eq(ns.UI.Suggest.Strip.Frame(), nil, "...nor after a look")
-- Nor a switch for the strip on Settings > Language, and no room kept.
Eq(ns.Setting("showSuggestStrip"), true, "the strip's switch defaults on")
ns.UI.SetJournalView("settings")
local english = ns.UI.SettingsPage()
Check(english.languageFeedback ~= nil, "setup: the Language page is built")
Eq(english.showSuggestStrip, nil, "a switch for the strip on an English diary")

--------------------------------------------------------------------------
Section("a German diary, its hints' record from before 4.0")

mock.Reset()
-- The client's language for the rest of the file, given back at its end
-- (the harness keeps globals between files).
local clientLocale = _G.GetLocale
_G.GetLocale = function() return "deDE" end
ns = T.Load()
-- As 3.x saved it: no `languages`, no showLanguageHint, no showSuggestStrip.
_G.SocialDiaryDB = { schema = 2, settings = { introSeen = true, showUpdateHint = false },
    hints = { seen = { ["custom-events"] = 100 }, retired = {}, again = {}, played = 4321, opens = 7 } }
mock.SetUnit("player", T.F.SELF)
mock.fire("ADDON_LOADED", ns.addonName)
mock.fire("PLAYER_LOGIN")
local S = SocialDiaryDB.hints
Eq(SocialDiaryDB.schema, 2, "the account's schema moved for an added field")
Eq(type(S.languages), "table", "no languages table filled in")
Eq(next(S.languages), nil, "...and it starts empty")
Eq(S.played, 4321, "the played clock kept")
Eq(S.seen["custom-events"], 100, "the seen kept")
Eq(S.opens, 7, "the openings kept")
Eq(SocialDiaryDB.settings.showLanguageHint, true, "the notice's switch defaults on")
Eq(SocialDiaryDB.settings.showUpdateHint, false, "the update's switch kept as saved")
Eq(ns.IsAccountSetting("showLanguageHint"), true, "the notice's switch is the account's")
Eq(SocialDiaryDB.settings.showSuggestStrip, true, "the strip's switch defaults on, on an old table")
Eq(ns.Setting("showSuggestStrip"), true, "...and reads so")
Eq(ns.IsAccountSetting("showSuggestStrip"), true, "the strip's switch is the account's")
Eq(rawget(SocialDiaryCharDB.settings, "showSuggestStrip"), nil, "...not kept with the character")
Eq(ns.Locale.id, "deDE", "the diary reads German")

local Suggest = ns.UI.Suggest
local L = ns.L

--------------------------------------------------------------------------
Section("the reverse lookup")

-- Words of the test's own, as a locale's would lie in ns.L.
rawset(L, "Quested together all evening##test", "Den ganzen Abend gemeinsam gequestet")
rawset(L, "Met %s in the wild##test", "%s in der Wildnis getroffen")
rawset(L, "%1$s outlasted %2$s##test", "%2$s wurde von %1$s überdauert")
rawset(L, "%d long fight together|%d long fights together##test##plural",
    "%d langer Kampf zusammen|%d lange Kämpfe zusammen")
rawset(L, "A friend called %1$s saved you##test", "<1:Ein Freund/Eine Freundin> namens %1$s hat dich gerettet")
rawset(L, "%1$s %2$s##test only values", "%2$s %1$s")
Suggest.Forget()

local hit = Suggest.Lookup("|cff112233Den ganzen Abend gemeinsam gequestet|r")
Eq(hit and hit.key, "Quested together all evening##test", "exact, through a colour")
Eq(hit and hit.english, "Quested together all evening", "...its English without the context")
Eq(hit and hit.kind, "exact", "...as an exact match")

hit = Suggest.Lookup("Bram Redfen in der Wildnis getroffen")
Eq(hit and hit.key, "Met %s in the wild##test", "a template")
Eq(hit and hit.kind, "template", "...as a template")

hit = Suggest.Lookup("Garrick wurde von Bram überdauert")
Eq(hit and hit.key, "%1$s outlasted %2$s##test", "a positional template, reordered")

hit = Suggest.Lookup("3 lange Kämpfe zusammen")
Eq(hit and hit.key, "%d long fight together|%d long fights together##test##plural", "a plural's form")
Eq(hit and hit.english, "%d long fights together", "...its English form")
Eq(hit and hit.kind, "plural", "...as a plural")
hit = Suggest.Lookup("1 langer Kampf zusammen")
Eq(hit and hit.english, "%d long fight together", "...the singular to the singular")

hit = Suggest.Lookup("Eine Freundin namens Wendla hat dich gerettet")
Eq(hit and hit.key, "A friend called %1$s saved you##test", "a gendered form, either way")
hit = Suggest.Lookup("Ein Freund namens Bram hat dich gerettet")
Eq(hit and hit.key, "A friend called %1$s saved you##test", "...the other way")

-- A line put together from several keys (a plate's caption: a stay and how
-- long, the figure glued to its unit with a no-break space).
rawset(L, "A long halt##test", "Ein langer Halt")
rawset(L, "%d blinks##test", "%d Bl.")
rawset(L, "%1$s, %2$s##test", "%1$s, %2$s")
rawset(L, "%1$s %2$s##test sentences", "%1$s %2$s")
Suggest.Forget()
hit = Suggest.Lookup("Ein langer Halt, 11\194\160Bl.")
Eq(hit and hit.kind, "joined", "a joined line, taken apart")
Eq(hit and #hit.parts, 2, "...both its parts found")
Eq(hit and hit.key, "A long halt##test\n%d blinks##test", "...their keys, a line each")
Eq(hit and hit.english, "A long halt / %d blinks", "...their English side by side")
hit = Suggest.Lookup("Bloodhoof Village, 11\194\160Bl.")
Eq(hit and hit.key, "%d blinks##test", "a name the game gave beside a part: the part alone")
hit = Suggest.Lookup("Ein langer Halt, 11 Bl., Den ganzen Abend gemeinsam gequestet")
Eq(hit and #hit.parts, 3, "a join within a join")
Eq(Suggest.Lookup("Ein langer Halt quorbled"), nil, "two words a space apart, one unknown: nil")
Eq(Suggest.Clean("11\194\160Bl."), "11 Bl.", "a no-break space as a plain one")
rawset(L, "%d h %d blinks##test", "%d Std. %d Bl.")
Suggest.Forget()
hit = Suggest.Lookup("Ein langer Halt, 1 Std. 5 Bl.")
Eq(hit and hit.key, "A long halt##test\n%d h %d blinks##test", "cut no finer than it needs")
hit = Suggest.Lookup("11 Bl.")
Eq(hit and hit.key, "%d blinks##test", "a figure and a short unit")
hit = Suggest.Lookup("Ein langer Halt, zzq Bl.")
Eq(hit and hit.key, "A long halt##test", "a figure's place takes no word: the line is not the unit's")

Eq(Suggest.Lookup("Zzyzx quorbled the flumph"), nil, "nothing matches: nil")
Eq(Suggest.Lookup("Bram Garrick"), nil, "a template of nothing but values matches nothing")
Eq(Suggest.Lookup("|T123:14|t  "), nil, "only escapes: nil")
Eq(Suggest.Clean("|cffaabbccA|r |T1:2|tline|nnext |Hunit:1|h[Bram]|h"), "A line next [Bram]", "escapes stripped")

--------------------------------------------------------------------------
Section("the issue's address")

Eq(Suggest.Encode("a b/ü&=?"), "a%20b%2F%C3%BC%26%3D%3F", "percent-encoded, UTF-8 byte by byte")
Eq(Suggest.Encode("Az09-_.~"), "Az09-_.~", "unreserved kept")
local cyr = ("\208\180"):rep(200)   -- "д" 200 times, 400 bytes
local cut = Suggest.Truncate(cyr, 61)
Check(#cut <= 61, "cut to its bytes: " .. #cut)
Check(cut:sub(-3) == "\226\128\166", "an ellipsis where it was cut")
Eq((#cut - 3) % 2, 0, "never half a letter")
Eq(Suggest.Truncate("short", 61), "short", "a short text as it is")

local url = Suggest.URL({ locale = "deDE", version = "4.0.0", key = "Met %s in the wild##test",
    current = "Bram in der Wildnis getroffen", suggestion = "Bram draußen getroffen" })
Check(url:find("^https://github%.com/social%-diary/social_diary/issues/new%?template=translation%.yml&") ~= nil,
    "the address and its form: " .. url)
Check(url:find("&title=%5BdeDE%5D%20Bram%20in", 1, true) ~= nil, "a title with the locale")
Check(url:find("&locale=deDE&", 1, true) ~= nil, "the locale")
Check(url:find("&addon-version=4.0.0&", 1, true) ~= nil, "the version")
Check(url:find("&english=Met%20%25s%20in%20the%20wild%23%23test&", 1, true) ~= nil, "the key")
Check(url:find("&current=Bram%20in%20der%20Wildnis%20getroffen&", 1, true) ~= nil, "the current text")
local tail = "&suggestion=Bram%20drau%C3%9Fen%20getroffen"
Eq(url:sub(-#tail), tail, "the suggestion, last")
local long = Suggest.URL({ locale = "ruRU", version = "4.0.0", key = cyr, current = cyr, suggestion = cyr })
Check(#long < 2400, "a sane length, all in Cyrillic: " .. #long)
-- Each field id is one of the issue form's.
local form = io.open(".github/ISSUE_TEMPLATE/translation.yml"):read("*a")
for _, id in pairs(Suggest.FIELDS) do
    Check(form:find("id: " .. id .. "\n", 1, true) ~= nil, "the form has no field " .. id)
end

--------------------------------------------------------------------------
Section("the walk: the topmost, smallest shown line under the cursor")

local Pick = Suggest.Pick
local function Line(text, over, w, h, shown)
    return { GetObjectType = function() return "FontString" end, IsVisible = function() return shown ~= false end,
        GetText = function() return text end, IsMouseOver = function() return over end,
        GetWidth = function() return w end, GetHeight = function() return h end }
end
local function Box(o)
    o.regions, o.children = o.regions or {}, o.children or {}
    return { IsVisible = function() return o.shown ~= false end,
        GetRegions = function() return unpack(o.regions) end,
        GetChildren = function() return unpack(o.children) end,
        GetFrameLevel = function() return o.level or 1 end,
        GetFrameStrata = function() return o.strata or "HIGH" end,
        DoesClipChildren = function() return o.clips == true end,
        IsMouseOver = function() return o.over ~= false end,
        IsProtected = function() return o.protected == true end }
end
local wide = Line("A whole paragraph of words", true, 300, 40)
local word = Line("A word", true, 40, 14)
local away = Line("Somewhere else", false, 40, 14)
local hidden = Line("Hidden", true, 10, 10, false)
local empty = Line("|T1:2|t", true, 5, 5)
local root = Box({ regions = { wide, word, away, hidden, empty } })
local found = Pick.Collect({ root }, {})
Eq(#found, 3, "every shown line with words, no hidden or empty one")
Eq(Pick.Under(found), word, "the smallest under the cursor")

local high = Line("On a sheet over it", true, 200, 30)
local sheet = Box({ level = 50, regions = { high } })
root = Box({ regions = { word }, children = { sheet } })
Eq(Pick.Under(Pick.Collect({ root }, {})), high, "the topmost before the smallest")

local scrolled = Line("Scrolled out of sight", true, 10, 10)
local clip = Box({ clips = true, over = false, children = { Box({ level = 60, regions = { scrolled } }) } })
root = Box({ regions = { word }, children = { clip } })
Eq(Pick.Under(Pick.Collect({ root }, {})), word, "outside a clipping frame: not under the cursor")

local mine = Box({ level = 70, regions = { Line("The strip", true, 5, 5) } })
local guarded = Box({ level = 70, protected = true, regions = { Line("Protected", true, 5, 5) } })
root = Box({ regions = { word }, children = { mine, guarded } })
Eq(Pick.Under(Pick.Collect({ root }, { [mine] = true })), word, "a skipped or protected frame not entered")
Eq(Pick.Under({}), nil, "nothing under the cursor: nil")

--------------------------------------------------------------------------
Section("the strip: on the book, out only while nothing holds it")

local Strip = Suggest.Strip
local J = ns.UI.Journal
ns.UI.ShowJournal()
local tab = Strip.Frame()
Check(tab ~= nil, "no strip on a German diary")
Eq(tab:GetParent():GetParent(), ns.UI.JournalFrame(), "not hung on the book")
local anchor = tab.recorded.points[1]
Eq(anchor.point, "BOTTOMRIGHT", "its anchor")
Eq(anchor.args[1], ns.UI.JournalFrame(), "...on the book's chrome")
Eq(anchor.args[2], "TOPRIGHT", "...at its top right")
-- Tucked behind the book: under the cover's frame, enough of it behind the
-- top edge to look held, and the hidden part takes no click.
local book = ns.UI.JournalFrame()
Check(tab:GetFrameLevel() < book:GetFrameLevel(), "the strip not behind the book's cover")
Eq(anchor.args[4], -Strip.PLACE.sink, "...its foot not behind the cover's top edge")
Check(Strip.PLACE.sink >= 6 and Strip.PLACE.tall - Strip.PLACE.sink >= 16, "...too little tucked in, or too little showing")
Eq(tab.recorded.calls.SetHitRectInsets[4], Strip.PLACE.sink, "...the hidden part takes clicks")
Eq(tab.label.recorded.points[1].args[2], Strip.PLACE.sink / 2, "...its words not centred in what shows")
Eq(tab.label:GetText(), ns.L["Suggest Translation"], "the strip's words")
-- The book raised (it is toplevel): the strip goes under it again.
book:SetFrameLevel(book:GetFrameLevel() + 5); Strip.Update()
Eq(tab:GetFrameLevel(), book:GetFrameLevel() - 1, "the strip not under a raised book")
Strip.Update()
Check(tab:IsShown(), "the strip not out on an open book")
J.editing = true; Strip.Update()
Check(not tab:IsShown(), "out while writing")
J.editing = false; J.visit = { id = 1 }; Strip.Update()
Check(not tab:IsShown(), "out while a run lies on the table")
J.visit = nil; ns.UI.Tour.step = 2; Strip.Update()
Check(not tab:IsShown(), "out during the tour")
ns.UI.Tour.step = nil; mock.inCombat = true; Strip.Update()
Check(not tab:IsShown(), "out in combat")
mock.inCombat = false
ns.UI.Pad.Input.Force("on"); ns.UI.Pad.Input.Changed()
Check(not tab:IsShown(), "out with the pad in hand")
Eq(Suggest.Available(), false, "picking offered with the pad in hand")
Eq(Pick.Start(), false, "picking began with the pad in hand")
ns.UI.Pad.Input.Force(nil); ns.UI.Pad.Input.Changed()
Check(tab:IsShown(), "not back with the mouse")

-- Its own switch: away at once, with no look from the ticker, and back.
local heard = {}
local function Hear(_, key, value) heard[#heard + 1] = key .. "=" .. tostring(value) end
ns.On("SD_SETTING_CHANGED", Hear)
ns.SetSetting("showSuggestStrip", false)
ns.Off("SD_SETTING_CHANGED", Hear)
Eq(table.concat(heard, ","), "showSuggestStrip=false", "the setting's change not said, once, after the write")
Check(not tab:IsShown(), "out with its switch off")
Eq(Strip.Wanted(), false, "wanted with its switch off")
Eq(SocialDiaryDB.settings.showSuggestStrip, false, "the switch not kept with the account")
Strip.Update()
Check(not tab:IsShown(), "...out again after a look")
Eq(Suggest.Available(), true, "the switch took picking away (it is the notice's link's too)")
ns.SetSetting("showLanguageHint", true)
Check(not tab:IsShown(), "another setting written brought it out")
ns.SetSetting("showSuggestStrip", true)
Check(tab:IsShown(), "not back at once with its switch on")
-- On again, the other conditions still hold it.
ns.SetSetting("showSuggestStrip", false)
J.editing = true
ns.SetSetting("showSuggestStrip", true)
Check(not tab:IsShown(), "its switch on brought it out while writing")
J.editing = false; Strip.Update()
Check(tab:IsShown(), "setup: out again")

--------------------------------------------------------------------------
Section("picking, and every way it ends")

tab.scripts.OnClick(tab)
local overlay = Pick.Frame()
Check(Pick.Picking(), "a click on the strip did not begin picking")
Eq(overlay.recorded.calls.SetFrameStrata[1], "FULLSCREEN_DIALOG", "the overlay's strata")
Eq(overlay:GetParent(), UIParent, "the overlay not on the screen")
Check(not tab:IsShown(), "the strip out while picking")
Check(overlay.scripts.OnUpdate ~= nil, "no OnUpdate while picking")

overlay.scripts.OnKeyDown(overlay, "W")
Eq(overlay.recorded.calls.SetPropagateKeyboardInput[1], true, "another key not passed on to the game")
Check(Pick.Picking(), "another key ended picking")
overlay.scripts.OnKeyDown(overlay, "ESCAPE")
Eq(overlay.recorded.calls.SetPropagateKeyboardInput[1], false, "Escape passed on (it would shut the book)")
Check(not Pick.Picking(), "Escape did not end picking")
Check(tab:IsShown(), "the strip not back after picking")

Pick.Start()
overlay.scripts.OnMouseDown(overlay, "RightButton")
Check(not Pick.Picking(), "a right-click did not end picking")

Pick.Start()
overlay.scripts.OnMouseDown(overlay, "LeftButton")
Check(Pick.Picking(), "a click on no line ended picking")
mock.fire("PLAYER_REGEN_DISABLED")
Check(not Pick.Picking(), "combat did not end picking")

mock.inCombat = true
Eq(Pick.Start(), false, "picking began in combat")
mock.inCombat = false

Pick.Start()
local holder = tab:GetParent()
holder.scripts.OnHide(holder)
Check(not Pick.Picking(), "the book shut did not end picking")

Pick.Start()
ns.UI.Pad.Input.Force("on"); ns.UI.Pad.Input.Changed()
Check(not Pick.Picking(), "the pad picked up did not end picking")
ns.UI.Pad.Input.Force(nil); ns.UI.Pad.Input.Changed()

--------------------------------------------------------------------------
Section("the sheet: the line, its English, the wording, the link")

local Sheet = Suggest.Sheet
Sheet.Open("|cffffffffBram in der Wildnis getroffen|r")
local view = Sheet.View()
Check(Sheet.Shown(), "the sheet not out")
Eq(view.picked.shown, "Bram in der Wildnis getroffen", "the line as shown, without escapes")
Eq(view.picked.english, "Met %s in the wild", "its English")
Check(view.box:HasFocus(), "the wording's line has no cursor")
Check(not view.copy:IsShown(), "the link out before it was made")
local said = {}
for _, fs in ipairs(view.texts) do if fs:IsShown() then said[#said + 1] = fs:GetText() end end
Eq(table.concat(said, " / "), "Bram in der Wildnis getroffen / Met %s in the wild", "what the sheet says")

Sheet.Make()
Eq(view.url, nil, "a link made with nothing written")
view.box:SetText("Bram draußen getroffen")
Sheet.Make()
Check(view.url ~= nil, "no link made")
Check(view.copy:IsShown(), "the link not out to copy")
Eq(view.copy:GetValue(), view.url, "the copy field holds another text")
Check(view.url:find("&english=Met%20%25s%20in%20the%20wild%23%23test&", 1, true) ~= nil, "the key not sent")
Check(view.url:find("&locale=deDE&", 1, true) ~= nil, "the locale not sent")
Check(view.url:find("&addon-version=" .. Suggest.Encode(ns.version) .. "&", 1, true) ~= nil, "the version not sent")
Check(view.copy.box:HasFocus(), "the link not selected to copy")
Sheet.Close()
Check(not Sheet.Shown(), "the sheet still out")
local special = false
for _, name in ipairs(UISpecialFrames) do if name == "SocialDiarySuggestFrame" then special = true end end
Check(special, "Escape does not put the sheet away")

Sheet.Open("Zzyzx quorbled the flumph")
Eq(view.picked.key, nil, "a key for nothing")
view.box:SetText("Better")
Sheet.Make()
Check(view.url:find("&english=&", 1, true) ~= nil, "no key: the field left empty")
Check(view.url:find("&current=Zzyzx%20quorbled", 1, true) ~= nil, "...the line sent as shown")
Sheet.Close()

--------------------------------------------------------------------------
Section("the translation's notice: once per language")

local Hints = ns.Hints
local spec = Hints.Get("translation")
Check(spec.notice and spec.page == "any", "not a notice on any page")
Check(spec.order > Hints.Get("major-update").order, "not after the update's notice")
local function Due() return (Hints.Due({ view = "journey" }) or {}).id end
Eq(Due(), "translation", "not due on a German diary")
local words = spec.words()
Check(words.body:find("Deutsch", 1, true) ~= nil, "the language not named: " .. words.body)
Eq(words.link, ns.L["Suggest Translation"], "its link with the mouse")
words.onLink()
Check(Pick.Picking(), "its link did not begin picking")
Pick.Stop()

ns.SetSetting("showLanguageHint", false)
Eq(Due(), nil, "its own switch off: no notice")
ns.SetSetting("showLanguageHint", true)

-- The strip's switch is not the notice's: due all the same, its link picks.
ns.SetSetting("showSuggestStrip", false)
Eq(Due(), "translation", "the strip's switch off took the notice away")
words = spec.words()
Eq(words.link, ns.L["Suggest Translation"], "...or changed its link")
words.onLink()
Check(Pick.Picking(), "...or stopped its link picking")
Pick.Stop()
Check(not tab:IsShown(), "picking over brought the strip out, its switch off")
ns.SetSetting("showSuggestStrip", true)
Check(tab:IsShown(), "setup: the strip out again")

ns.UI.Hints.noticeOpen = Hints.Opens()
Eq(Due(), nil, "in the same opening as another notice")
ns.UI.Hints.noticeOpen = nil

-- With the pad: to the Language page.
ns.UI.Pad.Input.Force("on"); ns.UI.Pad.Input.Changed()
words = spec.words()
Eq(words.link, ns.L["Go to Language"], "its link with the pad in hand")
words.onLink()
Check(not Pick.Picking(), "picking began with the pad")
Eq(J.view, "settings", "not turned to the settings")
ns.UI.Pad.Input.Force(nil); ns.UI.Pad.Input.Changed()

Hints.Shown("translation")
Check(Hints.LanguageSeen("deDE"), "not kept as seen in German")
Check(type(S.languages.deDE) == "number", "kept without a time")
Eq(Due(), nil, "told again in German")
Check(not Hints.LanguageSeen("frFR"), "seen in French already")
ns.Locale.id = "frFR"
Eq(Due(), "translation", "not told again in another language")
ns.Locale.id = "enUS"
Eq(Due(), nil, "told in English")
ns.Locale.id = "deDE"

--------------------------------------------------------------------------
Section("the strip's switch: on Settings > Language, where a translation is read")

local Pad = ns.UI.Pad
ns.UI.ShowJournal()
ns.UI.SetJournalView("settings")
local P = ns.UI.SettingsPage()
local function ShowAll(frame)
    frame:Show()
    for _, child in ipairs({ frame:GetChildren() }) do ShowAll(child) end
end
ShowAll(P)
P:ShowSection("language")
P:Refresh()
Strip.Update()
local row = P.showSuggestStrip
Check(row ~= nil, "no switch for the strip on a German diary")
Eq(row:GetParent(), P.languageRest, "not with the translations, on the part that moves")
Eq(row.group, P.languageFeedback.group, "not under the Translations heading")
Check(row.label:GetText():find(ns.L["Suggest Translation"], 1, true) ~= nil, "the slip not called by its name: " .. row.label:GetText())
Check(row.hint ~= nil and row.hint:GetText() ~= "", "no small print")
local function Y(f) return f.recorded.points[1].args[4] end
Check(Y(row) < Y(P.languageFeedback), "not under the way to Feedback")
Check(P.languageRest.recorded.height >= row.height - Y(row), "the part of the page it lies on does not hold it")
Eq(row:GetChecked(), true, "not ticked by default")
Check(tab:IsShown(), "setup: the strip out")
row:Click("LeftButton")
Eq(ns.Setting("showSuggestStrip"), false, "a click did not write the setting")
Eq(row:GetChecked(), false, "...or untick it")
Check(not tab:IsShown(), "the strip out after the switch's click")
row:Click("LeftButton")
Eq(ns.Setting("showSuggestStrip"), true, "a second click did not write it back")
Check(tab:IsShown(), "the strip not back after the switch's click")

-- With the pad: the last thing on the page, under the way to Feedback; A
-- ticks and unticks it as a click does. The strip stays away with the pad
-- in hand either way.
-- (the fight that ended picking above is over: in one the pad is the game's)
mock.fire("PLAYER_REGEN_ENABLED")
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(ns.UI.JournalFrame())
local function Press(key)
    mock.PadPress(catcher, key, true)
    mock.PadPress(catcher, key, false)
end
local function At() return Pad.Top().focus:Current() end
local function Prompt()
    local first = Pad.Top().legend(Pad.Top())[1]
    return first and first[2]
end
P:ShowSection("language")
Pad.Refresh()
Eq(Pad.Top().key, "settings", "the top scope")
Eq(At().key, "nav:language", "not on Language's row")
Press("PADDRIGHT")
Eq(At().frame, P.language.choice, "the pad not on the choice")
local reached
for _ = 1, 4 do
    Press("PADDDOWN")
    if At().frame == row then reached = true break end
end
Check(reached, "the pad could not reach the strip's switch")
Eq(At().kind, "switch", "...not as a switch")
Eq(Prompt(), L["Untick"], "its prompt while ticked")
Press("PADDUP")
Eq(At().frame, P.languageFeedback, "up: not the way to Feedback")
Press("PADDDOWN")
Press("PAD1")
Eq(ns.Setting("showSuggestStrip"), false, "A did not untick it")
Eq(row:GetChecked(), false, "...on the page")
Eq(At().frame, row, "A moved the pad")
Eq(Prompt(), L["Tick"], "its prompt while unticked")
Press("PAD1")
Eq(ns.Setting("showSuggestStrip"), true, "A did not tick it again")
Check(not tab:IsShown(), "the strip out with the pad in hand")
Press("PADDDOWN")
Eq(At().frame, row, "something under the switch")
Press("PAD2")
Eq(At().key, "nav:language", "B: not back on the sections")
mock.pad.ui, mock.pad.enabled, mock.pad.devices = false, false, {}
mock.fire("GAME_PAD_ACTIVE_CHANGED", false)
Pad.Input.Force("off"); Pad.Input.Changed()
Check(tab:IsShown(), "the strip not back with the mouse")
Pad.Input.Force(nil); Pad.Input.Changed()

--------------------------------------------------------------------------
Section("without the folder: the Language page stands, with no switch")

mock.Reset()
ns = T.Load()
mock.SetUnit("player", T.F.SELF)
mock.fire("ADDON_LOADED", ns.addonName)
ns.db.settings.introSeen = true
mock.fire("PLAYER_LOGIN")
Eq(ns.Locale.id, "deDE", "setup: the diary reads German")
ns.UI.Suggest = nil
ns.UI.ShowJournal()
ns.UI.SetJournalView("settings")
P = ns.UI.SettingsPage()
P:ShowSection("language")
P:Refresh()
Check(P.languageFeedback ~= nil, "the Language page not built without the folder")
Eq(P.showSuggestStrip, nil, "a switch for a strip that is not there")
Eq(ns.Setting("showSuggestStrip"), true, "the setting itself stays, unread")

_G.GetLocale = clientLocale
