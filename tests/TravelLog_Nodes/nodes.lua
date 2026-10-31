-- TravelLog_Nodes: chests and gathering nodes remembered by place, with
-- when they were last looted and by whom, their map pins and tooltips, alts
-- sharing them and wiping.
local ns = M.Login()
local nodeNS = M.ns("TravelLog_Nodes")
check(ns.settings.nodeMinimap and ns.settings.nodes, "minimap and world map pins on by default")

local function last(kind)
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == kind then return log[i] end
	end
end
local function Herb(name, id)
	return { { name = name, link = "[" .. name .. "]", qty = 2, guid = "GameObject-0-1-0-1-" .. id .. "-00F00D" } }
end
local function Nodes(map)
	return TravelLogNodesAccountDB.maps[map or 1429] or {}
end
local function Total(node)
	return nodeNS.Total(node)
end
local function Tooltip(node)
	for _, pin in ipairs(M.shown(M.mapOverlay(2012).children)) do
		if pin.node == node then
			pin.scripts.OnEnter(pin)
			return table.concat(GameTooltip.lines, "\n")
		end
	end
end
local function Stats()
	M.out = {}
	SlashCmdList.TRAVELLOG("stats")
	return table.concat(M.out, "\n")
end

-- Kills' loot isn't a node
local WOLF = "Creature-0-1-0-1-299-0000AAAA"
M.units.target = { name = "Young Wolf", guid = WOLF, hostile = true }
M.loot = { { name = "Ruined Pelt", link = "[Ruined Pelt]", qty = 1, guid = WOLF } }
M.lootAll()
check(#Nodes() == 0 and last("loot").lastHere == nil, "corpses aren't remembered as nodes")
M.units.target = nil

-- A crate that opens without a cast
M.loot = { { name = "Apple", link = "[Apple]", qty = 1, guid = "GameObject-0-1-0-1-777-0000C0DE" } }
M.lootAll()
local crate = Nodes()[1]
check(crate and crate.kind == "object" and Total(crate) == 1 and crate.id == 777, "uncast object remembered as 'object'")

--------------------------------------------------------------------------------
-- Gathering nodes
--------------------------------------------------------------------------------

M.advance(60)
M.x, M.y, M.wa, M.wb = 0.30, 0.40, -9100, -300
M.cast(2366, "Peacebloom")
M.loot = Herb("Peacebloom", 1618)
M.lootAll()
local herb = last("loot")
check(herb.via == "Herb Gathering" and herb.lastHere == nil, "first pick of a herb")
check(#Nodes() == 2 and Nodes()[2].kind == "herb" and Nodes()[2].name == "Peacebloom", "herb node remembered")
local firstPick = herb.time

-- Same spot later, from a few yards away and a different herb: same node
M.advance(25 * 60)
M.x, M.y, M.wa, M.wb = 0.301, 0.401, -9104, -303
M.cast(2366, "Silverleaf")
M.loot = Herb("Silverleaf", 1617)
M.lootAll()
check(last("loot").lastHere == firstPick, "loot remembers when this node was last picked")
local node = Nodes()[2]
check(#Nodes() == 2 and Total(node) == 2 and node.name == "Silverleaf" and node.last == M.now, "same spawn point, updated")
check(node.times[1] == M.now and node.times[2] == firstPick, "loot times kept newest first")
check(node.by[1] == "Rasmus-Forever" and node.by[2] == "Rasmus-Forever" and node.counts["Rasmus-Forever"] == 2, "who looted each time")

-- Mining a vein next to it is a different node
M.cast(2575, "Copper Vein")
M.loot = { { name = "Copper Ore", link = "[Copper Ore]", qty = 1, guid = "GameObject-0-1-0-1-1731-0000BEEF" } }
M.lootAll()
check(#Nodes() == 3 and Nodes()[3].kind == "ore", "ore is its own node")

-- A chest opened with a cast across the zone
M.x, M.y, M.wa, M.wb = 0.70, 0.20, -8800, -900
M.cast(3365, "Battered Chest")
M.loot = { { name = "Linen Cloth", link = "[Linen Cloth]", qty = 1, guid = "GameObject-0-1-0-1-2843-0000FEED" } }
M.lootAll()
check(#Nodes() == 4 and Nodes()[4].kind == "chest" and Nodes()[4].name == "Battered Chest", "chest remembered")

-- Only five loot times are kept per node
M.x, M.y, M.wa, M.wb = 0.30, 0.40, -9100, -300
for _ = 1, 6 do
	M.advance(1800)
	M.cast(2366, "Peacebloom")
	M.loot = Herb("Peacebloom", 1618)
	M.lootAll()
end
check(Total(Nodes()[2]) == 8 and #Nodes()[2].times == 5 and #Nodes()[2].by == 5, "count keeps going, times capped at 5")
check(Stats():find("Nodes remembered: 1 herbs, 1 ore, 1 chests, 1 other (all characters)", 1, true), "node stats count spawn points")

-- Nodes in dungeons (no coordinates) aren't remembered
M.x, M.wa = nil, nil
M.cast(3365, "Dusty Chest")
M.loot = { { name = "Coin", link = "[Coin]", qty = 1, guid = "GameObject-0-1-0-1-9999-0000" } }
M.lootAll()
check(last("loot").source == "Dusty Chest" and #Nodes() == 4, "dungeon loot logged but no node")
M.x, M.y, M.wa, M.wb = 0.42, 0.65, -9000, -100

--------------------------------------------------------------------------------
-- Node pins on the minimap, following its range and rotation
--------------------------------------------------------------------------------

local function MiniPins()
	M.frame()
	return M.shown(nodeNS.minimapHolder.children)
end
local function MiniPin(node)
	for _, pin in ipairs(MiniPins()) do
		if pin.node == node then return pin end
	end
end

M.x, M.y = 0.30, 0.40
local miniPins = MiniPins()
check(#miniPins == 2, "nearby herb and ore pinned on the minimap: " .. #miniPins)
local miniHerb, miniOre = MiniPin(Nodes()[2]), MiniPin(Nodes()[3])
check(miniHerb and miniHerb.w == 8 and miniHerb.icon.color[1] == 0.35, "minimap herb uses the node pin style")
-- The ore is 3.47 yards east and 2.315 yards south; 70 pixels is 200 yards.
check(miniOre and math.abs(miniOre.point[4] - 3.47 * 70 / 200) < 0.01
	and math.abs(miniOre.point[5] + 2.315 * 70 / 200) < 0.01, "minimap pin at the node's relative position")
M.script(miniHerb, "OnEnter")
check(GameTooltip.lines[1] == "Peacebloom", "minimap pin has the node tooltip")

M.cvars.rotateMinimap = { value = "1", default = "0" }
M.facing = math.pi / 2
miniOre = MiniPin(Nodes()[3])
check(math.abs(miniOre.point[4] + 2.315 * 70 / 200) < 0.01
	and math.abs(miniOre.point[5] + 3.47 * 70 / 200) < 0.01, "minimap pin follows rotation")
M.cvars.rotateMinimap, M.facing = nil, 0

M.x, M.y = 0.42, 0.65
check(#MiniPins() == 1 and MiniPins()[1].node == crate, "minimap only shows nodes in range")
M.x = nil
check(#MiniPins() == 0, "no minimap pins without a position")
M.x = 0.42
ns.settings.nodeMinimap = false
nodeNS.RefreshMinimap()
check(#MiniPins() == 0, "minimap node setting hides pins")
ns.settings.nodeMinimap = true
nodeNS.RefreshMinimap()
check(#MiniPins() == 1, "minimap node setting shows pins")

--------------------------------------------------------------------------------
-- Node pins on the map, with the last looted time in the tooltip
--------------------------------------------------------------------------------

M.viewMap = 1429
M.frame()
local overlay = M.mapOverlay(2012)
local pins = M.shown(overlay.children)
check(#pins == 4, "a pin per remembered node: " .. #pins)
local herbPin
for _, pin in ipairs(pins) do if pin.node == Nodes()[2] then herbPin = pin end end
check(herbPin and herbPin.mouse and herbPin.mouseClicks == false, "pins take hover but let clicks through")
check(math.abs(herbPin.point[4] - 300) < 0.01 and math.abs(herbPin.point[5] + 266.8) < 0.01, "pin at the node's spot")

herbPin.scripts.OnEnter(herbPin)
local tip = table.concat(GameTooltip.lines, "\n")
check(GameTooltip.lines[1] == "Peacebloom", "tooltip names the node")
check(tip:find("Last looted " .. date("%Y-%m-%d %H:%M", Nodes()[2].last) .. " (under a minute ago) by |cff3fc7ebRasmus|r", 1, true),
	"tooltip shows the last looted time and who, in their class color: " .. tip)
check(tip:find("Looted 8 times. Before that:", 1, true) and not tip:find("Rasmus 8"), "tooltip shows how often, without a breakdown for one looter")
check(tip:find("  " .. date("%Y-%m-%d %H:%M", Nodes()[2].times[2]) .. "  |cff3fc7ebRasmus|r", 1, true), "earlier times say who")
herbPin.scripts.OnLeave(herbPin)
check(not GameTooltip.shown, "tooltip hides")

M.advance(3 * 3600 + 15 * 60)
herbPin.scripts.OnEnter(herbPin)
check(table.concat(GameTooltip.lines, "\n"):find("%(3h 15m ago%)"), "relative time grows")

-- Picking a new node shows up while the map is open
M.x, M.y, M.wa, M.wb = 0.55, 0.55, -9300, -500
M.cast(2575, "Tin Vein")
M.loot = { { name = "Tin Ore", link = "[Tin Ore]", qty = 1, guid = "GameObject-0-1-0-1-1732-0000BEEF" } }
M.lootAll()
M.advance(4); M.frame()
check(#M.shown(overlay.children) == 5, "new node pin appears on the open map")

M.viewMap = 1415
M.frame()
check(#M.shown(overlay.children) == 0, "no node pins on the continent map")
M.viewMap = 1429
SlashCmdList.TRAVELLOG("nodes off")
M.frame()
check(#M.shown(overlay.children) == 0, "/tl nodes off hides pins")
SlashCmdList.TRAVELLOG("nodes on")

-- The log line says when you were last here
M.out = {}
SlashCmdList.TRAVELLOG("log 3")
local logged = table.concat(M.out, "\n")
check(logged:find("Looted [Peacebloom]x2 from Peacebloom (looted here 30m before)", 1, true), "log shows when the node was looted before: " .. logged)

-- Nodes survive a reload
ns = M.Reload()
check(#Nodes() == 5 and Total(Nodes()[2]) == 8, "nodes saved")
check(not M.savedChar["Rasmus-Forever"].TravelLog:find("nodes"), "nodes aren't in TravelLog's file")
check(M.savedSize("TravelLog_Nodes", true) == 0 and M.saved.TravelLog_Nodes:find("Peacebloom"), "nodes are saved account-wide only")


--------------------------------------------------------------------------------
-- An alt sees the same nodes and adds to them
--------------------------------------------------------------------------------

M.Logout()
M.player = { name = "Altie", realm = "Forever", class = "WARRIOR" }
ns = M.Login()
M.viewMap = 1429
M.frame()
check(#M.shown(M.mapOverlay(2012).children) == 5, "the alt sees the main's nodes")

M.advance(600)
M.x, M.y, M.wa, M.wb = 0.30, 0.40, -9100, -300
M.cast(2366, "Peacebloom")
M.loot = Herb("Peacebloom", 1618)
M.lootAll()
local herbNode = Nodes()[2]
check(#Nodes() == 5 and Total(herbNode) == 9 and herbNode.counts["Altie-Forever"] == 1 and herbNode.counts["Rasmus-Forever"] == 8,
	"the alt's pick lands on the same node")
check(herbNode.by[1] == "Altie-Forever" and herbNode.by[2] == "Rasmus-Forever" and #herbNode.times == 5, "the alt's pick is the newest")
check(last("loot").lastBy == "Rasmus-Forever", "the loot entry notes who looted it before")
M.out = {}
SlashCmdList.TRAVELLOG("log 1")
check(table.concat(M.out, "\n"):find("(looted here 3h 25m before by Rasmus-Forever)", 1, true), "log names the alt who looted it before: " .. table.concat(M.out, "\n"))

-- A chest only the alt has opened
M.x, M.y, M.wa, M.wb = 0.80, 0.80, -8500, -1200
M.cast(3365, "Battered Chest")
M.loot = { { name = "Linen Cloth", link = "[Linen Cloth]", qty = 1, guid = "GameObject-0-1-0-1-2843-0000FEED" } }
M.lootAll()
check(#Nodes() == 6 and last("loot").lastBy == nil, "a new node has no one before")

M.frame()
tip = Tooltip(herbNode)
check(tip:find("(under a minute ago) by |cffc69b6dAltie|r", 1, true), "tooltip names the alt in their class color: " .. tip)
check(tip:find("Looted 9 times (|cff3fc7ebRasmus|r 8, |cffc69b6dAltie|r 1). Before that:", 1, true), "tooltip splits the count by character")
check(Stats():find("Nodes remembered: 1 herbs, 2 ore, 2 chests, 1 other (all characters)", 1, true), "stats count every character's nodes")

-- Back on the main, the alt's loot shows too
M.Logout()
M.player = { name = "Rasmus", realm = "Forever" }
ns = M.Login()
M.frame()
check(#M.shown(M.mapOverlay(2012).children) == 6 and Tooltip(Nodes()[2]):find("by |cffc69b6dAltie|r", 1, true), "the main sees the alt's loot")

-- A character on another realm is named with the realm
M.Logout()
M.player = { name = "Faraway", realm = "Elsewhere" }
ns = M.Login()
M.frame()
check(Tooltip(Nodes()[2]):find("by |cffc69b6dAltie-Forever|r", 1, true), "other realms' characters show their realm")

-- Wiping the alt takes it out of the shared nodes
M.Logout()
M.player = { name = "Altie", realm = "Forever", class = "WARRIOR" }
ns = M.Login()
SlashCmdList.TRAVELLOG("wipe confirm")
ns = M.Reload()
herbNode = Nodes()[2]
check(#Nodes() == 5 and Total(herbNode) == 8 and herbNode.counts["Altie-Forever"] == nil, "wipe drops the alt's loot and the chest only it opened")
check(herbNode.by[1] == "Rasmus-Forever" and #herbNode.times == 4 and herbNode.last == herbNode.times[1], "and its time")
M.Logout()
M.player = { name = "Rasmus", realm = "Forever" }

-- Forgetting the alt from the main takes it out the same way, and redraws
M.player = { name = "Altie", realm = "Forever", class = "WARRIOR" }
ns = M.Login()
M.advance(600)
M.x, M.y, M.wa, M.wb = 0.30, 0.40, -9100, -300
M.cast(2366, "Peacebloom")
M.loot = Herb("Peacebloom", 1618)
M.lootAll()
M.x, M.y, M.wa, M.wb = 0.80, 0.80, -8500, -1200
M.cast(3365, "Battered Chest")
M.loot = { { name = "Linen Cloth", link = "[Linen Cloth]", qty = 1, guid = "GameObject-0-1-0-1-2843-0000FEED" } }
M.lootAll()
M.Logout()
M.player = { name = "Rasmus", realm = "Forever" }
ns = M.Login()
M.viewMap = 1429
M.frame()
check(#Nodes() == 6 and #M.shown(M.mapOverlay(2012).children) == 6, "the alt's chest is back")
SlashCmdList.TRAVELLOG("forget altie confirm")
M.frame()
herbNode = Nodes()[2]
check(#Nodes() == 5 and herbNode.counts["Altie-Forever"] == nil and herbNode.by[1] == "Rasmus-Forever"
	and #M.shown(M.mapOverlay(2012).children) == 5, "forget drops the alt's loot and its chest, and the map follows")
M.Logout()
