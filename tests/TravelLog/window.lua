-- The TravelLog window and its addon compartment entry, with every companion
-- adding its rows: tabs, sections, totals, settings, moving and a reload.
M.installed = { "TravelLog", "TravelLog_Path", "TravelLog_Nodes", "TravelLog_Kills" }
local ns = M.Login()

-- The value shown next to a label in the totals.
local function Stat(w, label)
	local all = M.descendants(w)
	for i, r in ipairs(all) do
		if r.kind == "FontString" and r:GetText() == label then return all[i + 1]:GetText() end
	end
end
-- The font strings at x on a page, in order.
local function Texts(page, x)
	local list = {}
	for _, fs in ipairs(page.fontStrings or {}) do
		if fs.point and fs.point[2] == x and fs:GetText() ~= "" then list[#list + 1] = fs:GetText() end
	end
	return table.concat(list, ", ")
end
local function Button(w, text)
	for _, r in ipairs(M.descendants(w)) do
		if r.kind == "Button" and r:GetText() == text then return r end
	end
end
local function Check(w, text)
	for _, r in ipairs(M.descendants(w)) do
		if r.kind == "CheckButton" and r.Text:GetText():find(text, 1, true) then return r end
	end
end
local function ExactCheck(w, text)
	for _, r in ipairs(M.descendants(w)) do
		if r.kind == "CheckButton" and r.Text:GetText() == text then return r end
	end
end
-- Runs OnUpdate for a bit more than the window's 1 s redraw interval.
local function Wait()
	for _ = 1, 70 do M.frame() end
end

-- The addon compartment entry, with the map icon; no minimap button.
local entry = M.compartment.TravelLog
check(entry and entry.text == "TravelLog" and entry.icon == "Interface\\Icons\\INV_Misc_Map_01", "compartment entry")
check(TravelLogMinimapButton == nil, "no minimap button")
entry:Click()
local w = ns.window
check(w and w:IsShown(), "click opens the window")
check(w.TitleText:GetText() == "TravelLog", "title")
check(w.who:GetText() == "Rasmus-Forever, level 5 Human Mage", "who: " .. w.who:GetText())

-- Totals, Settings and Log, then the companions' tabs in load order; Totals
-- open first, the other pages hidden.
local totals, settings, log = w.pages[1], w.pages[2], w.pages[3]
check(#w.Tabs == 5 and w.Tabs[1]:GetText() == "Totals" and w.Tabs[2]:GetText() == "Settings"
	and w.Tabs[3]:GetText() == "Log" and w.Tabs[4]:GetText() == "Colors" and w.Tabs[5]:GetText() == "Kills", "tabs")
check(w.selectedTab == 1 and totals:IsShown() and not settings:IsShown() and not log:IsShown()
	and not w.pages[4]:IsShown(), "totals tab open")
check(not w.Tabs[1]:IsEnabled() and w.Tabs[2]:IsEnabled(), "the open tab is disabled")

-- Totals by section, each companion's rows in its section in load order.
check(Texts(totals, 14) == "Travel, Loot, Life, Log", "sections: " .. Texts(totals, 14))
check(Texts(totals, 18) == "Places visited, Flights, Flight paths, Jumps, Distance, Looted, Vendors, Nodes, "
	.. "Quests done, Learned, XP kills, Deaths, All kills, Most killed, Entries", "rows: " .. Texts(totals, 18))
check(Texts(settings, 14) == "World map, General", "setting sections: " .. Texts(settings, 14))
check(Texts(settings, 18) == "Your trail, Path interval (s)", "setting labels: " .. Texts(settings, 18))
check(Stat(w, "Looted") == "0 items from 0 sources, 0c in coins", "loot: " .. Stat(w, "Looted"))
check(Stat(w, "Places visited") == "1", "places: " .. Stat(w, "Places visited"))
check(Stat(w, "Most killed") == "nothing yet", "no kills yet")

-- They follow what happens while the window is open.
JumpOrAscendStart()
M.fire("PARTY_KILL", UnitGUID("player"), "Creature-0-1-2-3-257-1")
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Worker dies, you gain 45 experience.")
M.units.target = { name = "Defias Thug", hostile = true }
M.dead = true
M.fire("PLAYER_DEAD")
M.dead = false
M.units.target = nil
Wait()
check(Stat(w, "Jumps") == "1 (1 this session)", "jumps: " .. Stat(w, "Jumps"))
check(Stat(w, "XP kills") == "1", "xp kills: " .. Stat(w, "XP kills"))
check(Stat(w, "Deaths") == "1", "deaths: " .. Stat(w, "Deaths"))
check(Stat(w, "All kills") == "1 of 1 mobs", "all kills: " .. Stat(w, "All kills"))
check(Stat(w, "Most killed") == "Kobold Worker (1)", "most killed: " .. Stat(w, "Most killed"))

-- Log: individual entries newest first, category buttons, and searches over
-- both visible text and saved fields such as a death's level.
w.Tabs[3]:Click()
local function LogRows()
	local out = {}
	for _, row in ipairs(M.shown(log.events.rows)) do
		out[#out + 1] = row.kind:GetText() .. ": " .. row.what:GetText()
	end
	return table.concat(out, ", ")
end
check(w.selectedTab == 3 and log:IsShown() and LogRows():find("^Death: Died fighting Defias Thug at level 5"),
	"individual deaths, newest first: " .. LogRows())
check(log.found:GetText() == "3 entries", "all log entries: " .. log.found:GetText())
Button(log, "Life"):Click()
check(log.found:GetText() == "2 of 3 entries" and LogRows():find("XP kill"), "life filter: " .. LogRows())
log.search:SetText("deaths level 5")
check(log.found:GetText() == "1 of 3 entries" and LogRows():find("Defias Thug"), "search saved death fields: " .. LogRows())
log.search.clearButton:Click()
Button(log, "All"):Click()
check(log.found:GetText() == "3 entries", "log filters cleared: " .. log.found:GetText())

-- Settings: choice buttons and checkboxes change what the commands change.
w.Tabs[2]:Click()
check(w.selectedTab == 2 and settings:IsShown() and not totals:IsShown(), "settings tab")
check(Button(w, "today").normalFont == GameFontHighlight and Button(w, "week").normalFont == GameFontNormal,
	"the chosen button in white")
check(Button(w, "1"):GetWidth() == Button(w, "today"):GetWidth(), "choice buttons all the same width")
check(Button(w, "today").highlightLocked and not Button(w, "week").highlightLocked, "trail today")
Button(w, "week"):Click()
check(ns.settings.trail == "week" and Button(w, "week").highlightLocked and not Button(w, "today").highlightLocked, "trail week")
check(Button(w, "2").highlightLocked, "interval 2")
Button(w, "5"):Click()
check(ns.settings.interval == 5 and Button(w, "5").highlightLocked, "interval 5")
local miniNodes = ExactCheck(w, "Looted nodes on the minimap")
local mapNodes = ExactCheck(w, "Looted nodes on the world map")
check(miniNodes:GetChecked() and mapNodes:GetChecked(), "node pins on")
miniNodes:Click()
mapNodes:Click()
check(ns.settings.nodeMinimap == false and ns.settings.nodes == false, "node pins off")

-- A /kills map filter shows in the label; the checkbox goes back to all kills.
SlashCmdList.TRAVELLOGKILLS("map kobold")
Wait()
local kills = Check(w, "Kills")
check(kills.Text:GetText() == "Kills: only Kobold Worker", "filter shown: " .. kills.Text:GetText())
kills:Click()
check(TravelLogKillsDB.settings.map == false and TravelLogKillsDB.settings.mapFilter == nil, "kill pins off")
kills:Click()
check(TravelLogKillsDB.settings.map and kills.Text:GetText() == "Kills", "kill pins on, all kills")

-- Moving the window.
M.script(w, "OnDragStart")
w:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -80)
M.script(w, "OnDragStop")
check(ns.settings.point[1] == "TOPLEFT" and ns.settings.point[3] == 100, "position saved")

-- The compartment entry and /tl close it.
M.compartment.TravelLog:Click()
check(not w:IsShown(), "click closes the window")
SlashCmdList.TRAVELLOG("")
check(w:IsShown(), "/tl opens")
SlashCmdList.TRAVELLOG("")
check(not w:IsShown(), "/tl closes")

-- Everything survives a reload; the minimap button's old settings are dropped.
TravelLogDB.settings.minimap, TravelLogDB.settings.minimapAngle = false, 90
ns = M.Reload()
check(ns.settings.minimap == nil and ns.settings.minimapAngle == nil, "old minimap settings dropped")
SlashCmdList.TRAVELLOG("")
w = ns.window
check(w:IsShown() and w.point[1] == "TOPLEFT" and w.point[4] == 100, "position restored")
check(Button(w, "week").highlightLocked and not ExactCheck(w, "Looted nodes on the minimap"):GetChecked()
	and not ExactCheck(w, "Looted nodes on the world map"):GetChecked(), "settings kept")

