-- Loot sources, remembered chests and gathering nodes (with when they were
-- last looted, shown on the map), and roll wins.
local ns = M.Login()

local function last(kind)
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == kind then return log[i] end
	end
end
local function count(kind)
	local n = 0
	for _, e in ipairs(TravelLogCharDB.log) do if e.type == kind then n = n + 1 end end
	return n
end
local function Herb(name, id)
	return { { name = name, link = "[" .. name .. "]", qty = 2, guid = "GameObject-0-1-0-1-" .. id .. "-00F00D" } }
end
local function Nodes(map)
	return TravelLogCharDB.nodes[map or 1429] or {}
end

--------------------------------------------------------------------------------
-- What opened the loot window
--------------------------------------------------------------------------------

-- A combat spell that finished seconds before looting a corpse isn't "via"
local WOLF = "Creature-0-1-0-1-299-0000AAAA"
M.units.target = { name = "Young Wolf", guid = WOLF, hostile = true }
M.cast(133, "Young Wolf") -- Fireball
M.advance(3)
M.loot = { { name = "Ruined Pelt", link = "[Ruined Pelt]", qty = 1, guid = WOLF } }
M.lootAll()
check(last("loot").source == "Young Wolf" and last("loot").via == nil, "a kill's loot has no gathering spell")

-- Skinning the same corpse right after is
M.cast(8613, "Young Wolf")
M.loot = { { name = "Light Leather", link = "[Light Leather]", qty = 1, guid = WOLF } }
M.lootAll()
check(last("loot").via == "Skinning", "second loot of a corpse after a cast is skinning")
M.units.target = nil

-- A crate that opens without a cast gets no stale name from an old cast
M.cast(133, "Young Wolf")
M.advance(5)
M.loot = { { name = "Apple", link = "[Apple]", qty = 1, guid = "GameObject-0-1-0-1-777-0000C0DE" } }
M.lootAll()
check(last("loot").source == nil and last("loot").via == nil and last("loot").sourceID == 777, "no cast, no name")
local crate = Nodes()[1]
check(crate and crate.kind == "object" and crate.count == 1, "uncast object remembered as 'object'")

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
check(#Nodes() == 2 and node.count == 2 and node.name == "Silverleaf" and node.last == M.now, "same spawn point, updated")
check(node.times[1] == M.now and node.times[2] == firstPick, "loot times kept newest first")

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
check(Nodes()[2].count == 8 and #Nodes()[2].times == 5, "count keeps going, times capped at 5")
check(ns.stats.nodes.herb == 1 and ns.stats.nodes.ore == 1 and ns.stats.nodes.chest == 1, "node stats count spawn points")

-- Nodes in dungeons (no coordinates) aren't remembered
M.x, M.wa = nil, nil
M.cast(3365, "Dusty Chest")
M.loot = { { name = "Coin", link = "[Coin]", qty = 1, guid = "GameObject-0-1-0-1-9999-0000" } }
M.lootAll()
check(last("loot").source == "Dusty Chest" and ns.stats.nodes.chest == 1, "dungeon loot logged but no node")
M.x, M.y, M.wa, M.wb = 0.42, 0.65, -9000, -100

--------------------------------------------------------------------------------
-- Node pins on the map, with the last looted time in the tooltip
--------------------------------------------------------------------------------

M.viewMap = 1429
M.frame()
local overlay = M.mapOverlay()
local pins = M.shown(overlay.children)
check(#pins == 4, "a pin per remembered node: " .. #pins)
local herbPin
for _, pin in ipairs(pins) do if pin.node == Nodes()[2] then herbPin = pin end end
check(herbPin and herbPin.mouse and herbPin.mouseClicks == false, "pins take hover but let clicks through")
check(math.abs(herbPin.point[4] - 300) < 0.01 and math.abs(herbPin.point[5] + 266.8) < 0.01, "pin at the node's spot")

herbPin.scripts.OnEnter(herbPin)
local tip = table.concat(GameTooltip.lines, "\n")
check(GameTooltip.lines[1] == "Peacebloom", "tooltip names the node")
check(tip:find("Last looted " .. date("%Y-%m-%d %H:%M", Nodes()[2].last) .. " (under a minute ago)", 1, true), "tooltip shows the last looted time: " .. tip)
check(tip:find("Looted 8 times"), "tooltip shows how often")
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
check(#TravelLogCharDB.nodes[1429] == 5 and TravelLogCharDB.nodes[1429][2].count == 8, "nodes saved")

--------------------------------------------------------------------------------
-- Roll wins
--------------------------------------------------------------------------------

M.advance(30)
local SWORD = "|cff1eff00|Hitem:2488::::|h[Gladius]|h|r"

-- Roll event first, then the chat line: one entry
M.fire("LOOT_ITEM_ROLL_WON", SWORD, 1, 2, 87, false)
M.fire("CHAT_MSG_LOOT", "You receive loot: " .. SWORD .. ".")
check(count("receive") == 1 and last("receive").how == "roll" and last("receive").roll == 87, "roll win logged once (event first)")

-- Chat line first, then the roll event: still one entry, marked as a roll
M.advance(30)
local AXE = "|cff1eff00|Hitem:2489::::|h[Axe]|h|r"
M.fire("CHAT_MSG_LOOT", "You receive loot: " .. AXE .. ".")
M.fire("LOOT_ITEM_ROLL_WON", AXE, 1, 1, 12, false)
check(count("receive") == 2 and last("receive").how == "roll" and last("receive").roll == 12, "roll win logged once (chat first)")
check(ns.stats.received.roll == 2 and (ns.stats.received.loot or 0) == 0, "roll stats")

-- In a dungeon the chat line is hidden, the roll event still records it
M.advance(30)
local RING = "|cff0070dd|Hitem:2490::::|h[Ring]|h|r"
M.secrets["You receive loot: " .. RING .. "."] = true
M.fire("LOOT_ITEM_ROLL_WON", RING, 1, 1, 99, false)
M.fire("CHAT_MSG_LOOT", "You receive loot: " .. RING .. ".")
check(count("receive") == 3 and last("receive").item == RING, "roll win recorded despite hidden chat")

M.out = {}
SlashCmdList.TRAVELLOG("log 1")
check(table.concat(M.out, "\n"):find("won with a roll of 99"), "log shows the roll")
