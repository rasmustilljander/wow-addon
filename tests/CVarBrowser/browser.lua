-- CVarBrowser: listing, searching, filtering, bookmarking and changing CVars,
-- through its functions and its window.
M.installed = { "CVarBrowser" }
M.cvars = {
	nameplateMaxDistance = { value = "41", default = "41", help = "The max distance to show nameplates.", category = 4, max = 60 },
	nameplateShowEnemies = { value = "1", default = "1", category = 4, account = true },
	cameraDistanceMaxZoomFactor = { value = "1.9", default = "1.9", category = 4 },
	autoLootDefault = { value = "0", default = "0", category = 4, character = true },
	maxFPS = { value = "60", default = "200.000", category = 1 },
	someDebugThing = { value = "0", default = "0", help = "Draws debug lines.", category = 0 },
	secureThing = { value = "1", default = "1", secure = true },
	hiddenThing = { value = "5", default = "5", unlisted = true },
}
local ns = M.Login()

local function Names(list)
	local names = {}
	for i, entry in ipairs(list) do names[i] = entry.name end
	return table.concat(names, " ")
end

-- The list: CVars only, sorted by name, case-insensitively.
check(Names(ns.All()) == "autoLootDefault cameraDistanceMaxZoomFactor maxFPS nameplateMaxDistance nameplateShowEnemies secureThing someDebugThing",
	"listed CVars: " .. Names(ns.All()))
check(ns.All()[4].category == "Game" and ns.All()[4].help == "The max distance to show nameplates.", "category and help")
check(ns.All()[1].help == nil, "empty help left out")

-- Search: every word in the name or description; name matches first.
check(Names(ns.Find("nameplate")) == "nameplateMaxDistance nameplateShowEnemies", "by name")
check(Names(ns.Find("  NamePlate ")) == "nameplateMaxDistance nameplateShowEnemies", "case and spaces ignored")
check(Names(ns.Find("zoom")) == "cameraDistanceMaxZoomFactor", "by name part")
check(Names(ns.Find("debug lines")) == "someDebugThing", "by the game's help")
check(Names(ns.Find("loot window")) == "", "every word must match")
check(Names(ns.Find("camera")) == "cameraDistanceMaxZoomFactor", "by our description")
check(Names(ns.Find("loot")) == "autoLootDefault", "loot")
-- A description-only match comes after name matches.
check(Names(ns.Find("frame")) == "maxFPS", "frame rate: " .. Names(ns.Find("frame")))
M.cvars.frameDelay = { value = "0", default = "0" }
check(Names(ns.Find("frame")) == "maxFPS", "the list is read once")
M.cvars.frameDelay = nil
-- An unlisted CVar is found by its whole name.
check(Names(ns.Find("hiddenthing")) == "hiddenthing" and ns.Find("hiddenthing")[1].unlisted, "unlisted CVar by name")
check(Names(ns.Find("hidden")) == "", "not by part of its name")
check(Names(ns.Find("nosuchthing")) == "", "unknown name finds nothing")

-- Filters.
check(Names(ns.Find("", "changed")) == "maxFPS", "changed: " .. Names(ns.Find("", "changed")))
check(not ns.Info("cameraDistanceMaxZoomFactor").changed, "1.9 is the default")
check(Names(ns.Find("", "known")) == "autoLootDefault cameraDistanceMaxZoomFactor maxFPS nameplateMaxDistance nameplateShowEnemies",
	"known: " .. Names(ns.Find("", "known")))
check(Names(ns.Find("", "bookmarks")) == "", "no bookmarks yet")
ns.ToggleBookmark("autoLootDefault")
ns.ToggleBookmark("hiddenThing")
check(Names(ns.Find("", "bookmarks")) == "autoLootDefault hiddenThing", "bookmarks, unlisted ones too: " .. Names(ns.Find("", "bookmarks")))
check(Names(ns.Find("auto", "bookmarks")) == "autoLootDefault", "search within bookmarks")
check(ns.IsBookmarked("AUTOLOOTDEFAULT"), "bookmarks are case-insensitive")

-- Changing values.
M.out = {}
check(ns.Set("nameplateMaxDistance", "50") == "50" and M.cvars.nameplateMaxDistance.value == "50", "set")
check(M.out[1]:find("nameplateMaxDistance: 41 %-> |cffffffff50"), "set printed: " .. tostring(M.out[1]))
check(ns.Set("nameplateMaxDistance", "100") == "60", "clamped by the client")
check(M.out[2]:find("stays |cffffffff60|r; the client didn't take 100"), "clamp printed: " .. tostring(M.out[2]))
check(ns.Reset("nameplateMaxDistance") == "41", "reset to default")
local value, why = ns.Set("secureThing", "0")
check(value == nil and why == "addons can't change it" and M.cvars.secureThing.value == "1", "secure CVar left alone")
check(select(2, ns.Set("noSuchCVar", "1")) == "the client doesn't know it", "unknown CVar")
M.combat = true
check(select(2, ns.Set("autoLootDefault", "1")) == "not in combat" and M.cvars.autoLootDefault.value == "0", "not in combat")
M.combat = false
check(ns.Set("hiddenThing", "7") == "7", "unlisted CVars can be set")

-- The info box.
check(ns.InfoText(ns.Find("nameplateMaxDistance")[1]):find("in yards.*From the game:|r The max distance"), "description and the game's help")
check(ns.InfoText(ns.Find("autoLootDefault")[1]):find("Values:|r 0 = off, 1 = on"), "values")
check(ns.InfoText(ns.Find("secureThing")[1]):find("No description known"), "nothing known")

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

local function Row(name)
	for _, row in ipairs(ns.window.list.rows) do
		if row:IsShown() and row.entry.name == name then return row end
	end
end
local function Rows()
	local names = {}
	for _, row in ipairs(ns.window.list.rows) do
		if row:IsShown() then names[#names + 1] = row.entry.name end
	end
	return table.concat(names, " ")
end

SlashCmdList.CVARBROWSER("")
local w = ns.window
check(w:IsShown() and #M.shown(w.list.rows) == 8, "opened with every CVar and bookmark: " .. Rows())
check(w.count:GetText() == "8 CVars", "count: " .. w.count:GetText())
check(UISpecialFrames[1] == "CVarBrowserFrame", "Escape closes it")
check(not w.detail:IsShown() and w.empty:IsShown(), "nothing selected yet")
check(Row("maxFPS").value:GetText() == "|cffffffff60|r", "changed value in white")
check(Row("autoLootDefault").star.icon.atlas == "auctionhouse-icon-favorite", "bookmark star")
check(Row("maxFPS").star.icon.atlas == "auctionhouse-icon-favorite-off", "no bookmark star")
SlashCmdList.CVARBROWSER("")
check(not w:IsShown(), "/cvars toggles it")

-- /cvars with text searches.
SlashCmdList.CVARBROWSER("nameplate")
check(w:IsShown() and w.search:GetText() == "nameplate" and Rows() == "nameplateMaxDistance nameplateShowEnemies", "search: " .. Rows())
w.search:SetText("")
check(#M.shown(w.list.rows) == 8, "search cleared")
w.search.clearButton:Click()

-- Filter buttons.
w.filters[3]:Click()
check(Rows() == "maxFPS hiddenThing" and w.filters[3].highlightLocked and not w.filters[1].highlightLocked, "changed filter: " .. Rows())
w.filters[1]:Click()

-- Selecting a CVar shows it on the right.
Row("nameplateShowEnemies"):Click()
local d = w.detail
check(d:IsShown() and not w.empty:IsShown() and d.name:GetText() == "nameplateShowEnemies", "selected")
check(Row("nameplateShowEnemies").selected:IsShown() and not Row("maxFPS").selected:IsShown(), "selected row marked")
check(d.edit:GetText() == "1" and d.defaultText:GetText():find("1"), "value and default")
check(d.meta:GetText() == "Game, saved on the server for your account", "meta: " .. d.meta:GetText())
check(d.info:GetText():find("Show enemy nameplates"), "info box")
check(d.toggle:IsShown() and not d.reset:IsEnabled(), "toggle shown, nothing to reset")
d.toggle:Click()
check(M.cvars.nameplateShowEnemies.value == "0" and d.edit:GetText() == "0" and d.reset:IsEnabled(), "toggled")
check(Row("nameplateShowEnemies").value:GetText() == "|cffffffff0|r", "row updated")
d.reset:Click()
check(M.cvars.nameplateShowEnemies.value == "1", "back to default")

-- Typing a value and pressing Enter sets it.
Row("nameplateMaxDistance"):Click()
check(not d.toggle:IsShown(), "no toggle for numbers")
d.edit:SetFocus()
d.edit:SetText("45")
M.script(d.edit, "OnEnterPressed")
check(M.cvars.nameplateMaxDistance.value == "45" and not d.edit:HasFocus(), "set with Enter")
d.edit:SetFocus()
d.edit:SetText("50")
d.set:Click()
check(M.cvars.nameplateMaxDistance.value == "50", "set with the button")
-- Escape throws the typing away.
d.edit:SetFocus()
d.edit:SetText("12")
M.script(d.edit, "OnEscapePressed")
check(M.cvars.nameplateMaxDistance.value == "50" and d.edit:GetText() == "50", "escape reverts")
-- A change from elsewhere shows up, but not over what you're typing.
C_CVar.SetCVar("nameplateMaxDistance", "30")
check(d.edit:GetText() == "30" and Row("nameplateMaxDistance").value:GetText():find("30"), "outside change shown")
d.edit:SetFocus()
d.edit:SetText("3")
C_CVar.SetCVar("nameplateMaxDistance", "31")
check(d.edit:GetText() == "3", "typing kept")
d.edit:ClearFocus()

-- In combat, and for CVars addons can't change, the buttons are off.
M.combat = true
M.fire("PLAYER_REGEN_DISABLED")
check(not d.set:IsEnabled() and d.note:GetText():find("in combat"), "combat: " .. d.note:GetText())
d.set:Click()
check(M.cvars.nameplateMaxDistance.value == "31", "nothing set in combat")
M.combat = false
M.fire("PLAYER_REGEN_ENABLED")
check(d.set:IsEnabled() and d.note:GetText() == "", "after combat")
Row("secureThing"):Click()
check(not d.set:IsEnabled() and not d.toggle:IsEnabled() and d.note:GetText():find("can't change"), "secure CVar")

-- Bookmarking from the row star and the detail star.
Row("maxFPS").star:Click()
check(ns.IsBookmarked("maxFPS") and Row("maxFPS").star.icon.atlas == "auctionhouse-icon-favorite", "bookmarked from the row")
Row("maxFPS"):Click()
d.star:Click()
check(not ns.IsBookmarked("maxFPS") and d.star.icon.atlas == "auctionhouse-icon-favorite-off", "unbookmarked from the detail")
w.filters[2]:Click()
check(Rows() == "autoLootDefault hiddenThing", "bookmarks filter: " .. Rows())
Row("hiddenThing"):Click()
check(d.meta:GetText() == "not in the client's list", "unlisted meta: " .. d.meta:GetText())
w.filters[1]:Click()

-- The minimap button: on the minimap's edge, bottom left at first.
local mb = ns.minimapButton
check(mb and mb:IsShown() and mb.parent == Minimap, "minimap button")
check(mb.point[1] == "CENTER" and math.abs(mb.point[4] + 53.03) < 0.01 and math.abs(mb.point[5] + 53.03) < 0.01, "at 225 degrees")
M.script(mb, "OnEnter")
check(GameTooltip.lines[1] == "CVarBrowser" and GameTooltip.lines[2]:find("drag to move"), "tooltip")
M.script(mb, "OnLeave")
mb:Click()
check(not w:IsShown(), "click closes the window")
mb:Click()
check(w:IsShown(), "click opens it")
-- Dragging follows the cursor around the edge; the minimap's center is at
-- (1800, 900).
M.script(mb, "OnDragStart")
M.cursor = { 1800, 1000 }
M.frame()
M.script(mb, "OnDragStop")
check(CVarBrowserDB.minimap.angle == 90 and math.abs(mb.point[4]) < 0.01 and math.abs(mb.point[5] - 75) < 0.01, "dragged to the top")
check(mb:GetScript("OnUpdate") == nil, "stops following on release")
-- The window's checkbox hides it.
check(w.minimap:GetChecked(), "checkbox on")
w.minimap:Click()
check(not mb:IsShown() and CVarBrowserDB.minimap.hide, "hidden")

-- Moving the window is remembered.
M.script(w, "OnDragStart")
w:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -80)
M.script(w, "OnDragStop")
check(CVarBrowserDB.point[1] == "TOPLEFT" and CVarBrowserDB.point[3] == 100 and CVarBrowserDB.point[4] == -80, "position saved")

-- Bookmarks and the position survive a reload.
ns = M.Reload()
check(ns.IsBookmarked("autoLootDefault") and ns.IsBookmarked("hiddenThing") and not ns.IsBookmarked("maxFPS"), "bookmarks kept")
SlashCmdList.CVARBROWSER("")
check(ns.window.point[1] == "TOPLEFT" and ns.window.point[4] == 100, "position restored")
check(#UISpecialFrames == 1, "not registered twice")
check(ns.minimapButton == nil and not ns.window.minimap:GetChecked(), "minimap button stays hidden")
ns.window.minimap:Click()
check(ns.minimapButton:IsShown() and not CVarBrowserDB.minimap.hide, "shown again")
check(math.abs(ns.minimapButton.point[5] - 75) < 0.01, "where it was dragged")
