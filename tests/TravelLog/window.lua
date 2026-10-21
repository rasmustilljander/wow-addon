-- The TravelLog window and its minimap button, with every companion adding
-- its rows: totals, settings, moving, hiding the button and a reload.
M.installed = { "TravelLog", "TravelLog_Path", "TravelLog_Nodes", "TravelLog_Kills" }
local ns = M.Login()

-- The value shown next to a label in the totals.
local function Stat(w, label)
	for i, fs in ipairs(w.fontStrings) do
		if fs:GetText() == label then return w.fontStrings[i + 1]:GetText() end
	end
end
local function Labels(w)
	local list = {}
	for i, fs in ipairs(w.fontStrings) do
		if fs.point and fs.point[2] == 18 and fs:GetText() ~= "" then list[#list + 1] = fs:GetText() end
	end
	return table.concat(list, ", ")
end
local function Button(w, text)
	for _, child in ipairs(w.children) do
		if child.kind == "Button" and child:GetText() == text then return child end
	end
end
local function Check(w, text)
	for _, child in ipairs(w.children) do
		if child.kind == "CheckButton" and child.Text:GetText():find(text, 1, true) then return child end
	end
end
-- Runs OnUpdate for a bit more than the window's 1 s redraw interval.
local function Wait()
	for _ = 1, 70 do M.frame() end
end

-- The minimap button: on the minimap's edge at 195 degrees.
local mb = ns.minimapButton
check(mb and mb:IsShown() and mb.parent == Minimap, "minimap button")
check(math.abs(mb.point[4] + 72.44) < 0.01 and math.abs(mb.point[5] + 19.41) < 0.01, "at 195 degrees")
M.script(mb, "OnEnter")
check(GameTooltip.lines[1] == "TravelLog" and GameTooltip.lines[2]:find("drag to move"), "tooltip")
M.script(mb, "OnLeave")
mb:Click()
local w = ns.window
check(w and w:IsShown(), "click opens the window")
check(w.TitleText:GetText() == "TravelLog", "title")
check(w.who:GetText() == "Rasmus-Forever, level 5 Human Mage", "who: " .. w.who:GetText())

-- Totals: TravelLog's, then each companion's in load order.
check(Labels(w) == "Loot, Vendors, Quests done, Flights, Deaths, XP kills, Places visited, Log, Jumps, Distance, "
	.. "Nodes, All kills, Most killed, Map trail, Path interval (s)", "rows: " .. Labels(w))
check(Stat(w, "Loot") == "0 items from 0 sources, 0c in coins", "loot: " .. Stat(w, "Loot"))
check(Stat(w, "Places visited") == "1", "places: " .. Stat(w, "Places visited"))
check(Stat(w, "Most killed") == "nothing yet", "no kills yet")

-- They follow what happens while the window is open.
JumpOrAscendStart()
M.fire("PARTY_KILL", UnitGUID("player"), "Creature-0-1-2-3-257-1")
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Worker dies, you gain 45 experience.")
Wait()
check(Stat(w, "Jumps") == "1 (1 this session)", "jumps: " .. Stat(w, "Jumps"))
check(Stat(w, "XP kills") == "1", "xp kills: " .. Stat(w, "XP kills"))
check(Stat(w, "All kills") == "1 of 1 mobs", "all kills: " .. Stat(w, "All kills"))
check(Stat(w, "Most killed") == "Kobold Worker (1)", "most killed: " .. Stat(w, "Most killed"))

-- Settings: choice buttons and checkboxes change what the commands change.
check(Button(w, "today").highlightLocked and not Button(w, "week").highlightLocked, "trail today")
Button(w, "week"):Click()
check(ns.settings.trail == "week" and Button(w, "week").highlightLocked and not Button(w, "today").highlightLocked, "trail week")
check(Button(w, "2").highlightLocked, "interval 2")
Button(w, "5"):Click()
check(ns.settings.interval == 5 and Button(w, "5").highlightLocked, "interval 5")
local nodes = Check(w, "Looted nodes")
check(nodes:GetChecked(), "nodes on")
nodes:Click()
check(ns.settings.nodes == false, "nodes off")

-- A /kills map filter shows in the label; the checkbox goes back to all kills.
SlashCmdList.TRAVELLOGKILLS("map kobold")
Wait()
local kills = Check(w, "Kills on the world map")
check(kills.Text:GetText() == "Kills on the world map: only Kobold Worker", "filter shown: " .. kills.Text:GetText())
kills:Click()
check(TravelLogKillsDB.settings.map == false and TravelLogKillsDB.settings.mapFilter == nil, "kill pins off")
kills:Click()
check(TravelLogKillsDB.settings.map and kills.Text:GetText() == "Kills on the world map", "kill pins on, all kills")

-- Dragging the button, hiding it, and moving the window.
M.script(mb, "OnDragStart")
M.cursor = { 1800, 1000 }
M.frame()
M.script(mb, "OnDragStop")
check(ns.settings.minimapAngle == 90 and math.abs(mb.point[5] - 75) < 0.01, "dragged to the top")
check(w.minimap:GetChecked(), "minimap checkbox on")
w.minimap:Click()
check(not mb:IsShown() and ns.settings.minimap == false, "button hidden")
M.script(w, "OnDragStart")
w:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -80)
M.script(w, "OnDragStop")
check(ns.settings.point[1] == "TOPLEFT" and ns.settings.point[3] == 100, "position saved")

-- /tl window closes and opens it.
SlashCmdList.TRAVELLOG("window")
check(not w:IsShown(), "/tl window closes")

-- Everything survives a reload; the hidden button stays hidden.
ns = M.Reload()
check(ns.minimapButton == nil, "button stays hidden")
SlashCmdList.TRAVELLOG("window")
w = ns.window
check(w:IsShown() and w.point[1] == "TOPLEFT" and w.point[4] == 100, "position restored")
check(Button(w, "week").highlightLocked and not Check(w, "Looted nodes"):GetChecked(), "settings kept")
w.minimap:Click()
check(ns.minimapButton:IsShown() and math.abs(ns.minimapButton.point[5] - 75) < 0.01, "shown again where it was dragged")
