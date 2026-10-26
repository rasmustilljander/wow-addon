-- OpenMap's seamless map: the overlays stay above its art when it moves the
-- map's layers, zones in view around the map underneath get their trail and
-- pins, and its menu gets a switch for each overlay.
M.installed = { "TravelLog", "TravelLog_Path", "TravelLog_Nodes", "TravelLog_Kills", "TravelLog_NPCs" }

-- Each addon carries the same copy of the helper.
local function Read(path)
	local f = assert(io.open(REPO .. "/" .. path))
	local text = f:read("*a")
	f:close()
	return text
end
local helper = Read("TravelLog_Path/MapView.lua")
for _, addon in ipairs({ "TravelLog_Nodes", "TravelLog_Kills", "TravelLog_NPCs" }) do
	check(Read(addon .. "/MapView.lua") == helper, addon .. "/MapView.lua matches TravelLog_Path's")
end

local ns = M.Login()
local kills, npcs = M.ns("TravelLog_Kills"), M.ns("TravelLog_NPCs")
local ME = UnitGUID("player")

-- Something of each in Westfall: a walk, a herb, a kill and a vendor.
M.mapID, M.zone, M.subzone = 1436, "Westfall", "Sentinel Hill"
M.x, M.y, M.wa, M.wb = 0.50, 0.50, -10500, 1000
for _ = 1, 10 do
	M.x, M.wb = M.x + 0.005, M.wb - 15
	M.tick(2)
end
M.cast(2366, "Peacebloom")
M.loot = { { name = "Peacebloom", link = "[Peacebloom]", qty = 2, guid = "GameObject-0-1-0-1-1618-00F00D" } }
M.lootAll()
local THUG = "Creature-0-1-2-3-116-1"
M.units.target = { name = "Defias Thug", guid = THUG, hostile = true }
M.fire("PARTY_KILL", ME, THUG)
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Defias Thug dies, you gain 60 experience.")
M.units.target = nil
local function Talk(name, id)
	M.units.npc = { name = name, guid = "Creature-0-1-2-3-" .. id .. "-1", title = "General Goods", level = 30 }
	M.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.Merchant)
	M.fire("MERCHANT_SHOW")
	M.fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.Merchant)
	M.units.npc = nil
end
Talk("Quartermaster Lewis", 491)
-- A vendor in Stormwind, and a kill and a vendor at home in Goldshire.
M.mapID, M.zone, M.subzone, M.x, M.y = 84, "Stormwind City", "Trade District", 0.60, 0.70
Talk("Olivia Burgess", 1257)
M.mapID, M.zone, M.subzone, M.x, M.y, M.wa, M.wb = 1429, "Elwynn Forest", "Goldshire", 0.42, 0.65, -9000, -100
local KOBOLD = "Creature-0-1-2-3-257-1"
M.units.target = { name = "Kobold Worker", guid = KOBOLD, hostile = true }
M.fire("PARTY_KILL", ME, KOBOLD)
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Worker dies, you gain 45 experience.")
M.units.target = nil
Talk("Brog Hamfist", 1265)
M.tick(3)
check(TravelLogNodesAccountDB.maps[1436] and TravelLogKillsDB.mobs["Defias Thug"] and TravelLogNPCsDB.npcs[491]
	and TravelLogNPCsDB.npcs[1257].map == 84, "a node, a kill and NPCs saved in Westfall and Stormwind")

local function Overlays()
	M.frame()
	local shift = M.levelShift
	return M.mapOverlay(2010 + shift), kills.mapOverlay, M.mapOverlay(2012 + shift), npcs.mapOverlay
end
local function Names(overlay, field)
	local list = {}
	for _, pin in ipairs(M.shown(overlay.children)) do
		local v = pin[field]
		list[#list + 1] = field == "npc" and v.name or field == "spot" and next(v.mobs) or v.name
	end
	table.sort(list)
	return table.concat(list, ",")
end
-- Trail lines left of Elwynn's canvas: Westfall's part, placed by OpenMap.
local function WestLines(path)
	local n = 0
	for _, l in ipairs(M.shown(path.lines)) do
		if l.start[1] < 0 then n = n + 1 end
	end
	return n
end

-- Blizzard's map alone: only Elwynn's own.
M.viewMap = 1429
local path, killPins, nodePins, npcPins = Overlays()
check(path.level == 2010 and killPins.level == 2011 and nodePins.level == 2012 and npcPins.level == 2013,
	"overlays above the highlight layer")
check(Names(killPins, "spot") == "Kobold Worker" and #M.shown(nodePins.children) == 0
	and Names(npcPins, "npc") == "Brog Hamfist", "only Elwynn's pins on Elwynn's map: " .. Names(npcPins, "npc"))
check(WestLines(path) == 0, "no Westfall trail on Elwynn's map")

-- OpenMap installed (it loads before the TravelLog addons); its menu gets a
-- switch per overlay.
M.OpenMap()
ns = M.Reload()
kills, npcs = M.ns("TravelLog_Kills"), M.ns("TravelLog_NPCs")
local toggles = M.openMapToggles
check(toggles.trail and toggles.nodes and toggles.kills and toggles.npcs, "a switch per overlay in OpenMap's menu")
check(toggles.trail.section == "TravelLog" and toggles.nodes.label == "Looted nodes" and toggles.npcs.icon,
	"under TravelLog, with labels and icons")

-- OpenMap's art moves the highlight layer up; the overlays follow.
M.levelShift = 80
path, killPins, nodePins, npcPins = Overlays()
check(path and path.level == 2090 and killPins.level == 2091 and nodePins.level == 2092 and npcPins.level == 2093,
	"overlays moved above OpenMap's art")

-- Stitched, Elwynn underneath and Westfall in view to the west: Westfall's
-- pins and trail, placed where OpenMap draws it. Stormwind is too small
-- at this zoom for its pins; Teldrassil is out of view.
M.viewRect = { -0.6, 0.4, 0, 1 }
M.openMapMoved()
path, killPins, nodePins, npcPins = Overlays()
check(Names(killPins, "spot") == "Defias Thug,Kobold Worker", "Westfall's kills too: " .. Names(killPins, "spot"))
check(Names(npcPins, "npc") == "Brog Hamfist,Quartermaster Lewis", "Westfall's NPCs too, not Stormwind's: " .. Names(npcPins, "npc"))
local node = M.shown(nodePins.children)[1]
local saved = TravelLogNodesAccountDB.maps[1436][1]
check(#M.shown(nodePins.children) == 1 and node.node == saved, "Westfall's node")
-- Westfall is { -1, 1, 0.25, 1 } on Elwynn's canvas (1000 x 667).
check(node and math.abs(node.point[4] - (-1 + saved.x / 100) * 1000) < 0.01
	and math.abs(node.point[5] + (0.25 + saved.y / 100) * 667) < 0.01, "placed by OpenMap's positions")
check(WestLines(path) >= 5, "Westfall's trail: " .. WestLines(path))

-- Panning east takes Westfall out of view, without a new map underneath.
M.viewRect = { 0.5, 1.5, 0, 1 }
M.openMapMoved()
path, killPins, nodePins, npcPins = Overlays()
check(Names(killPins, "spot") == "Kobold Worker" and #M.shown(nodePins.children) == 0
	and Names(npcPins, "npc") == "Brog Hamfist" and WestLines(path) == 0, "Westfall's gone once out of view")

-- Zoomed in on Stormwind: big enough now for its pins.
M.viewRect = { 0.15, 0.4, 0.05, 0.3 }
M.openMapMoved()
path, killPins, nodePins, npcPins = Overlays()
check(Names(npcPins, "npc") == "Brog Hamfist,Olivia Burgess", "Stormwind's NPCs zoomed in: " .. Names(npcPins, "npc"))

-- Back on Blizzard's own map: only Elwynn's again.
M.viewRect = { -0.6, 0.4, 0, 1 }
M.stitched = false
M.openMapMoved()
path, killPins, nodePins, npcPins = Overlays()
check(Names(killPins, "spot") == "Kobold Worker" and Names(npcPins, "npc") == "Brog Hamfist" and WestLines(path) == 0,
	"nothing from other zones on Blizzard's map")
M.stitched = true
M.openMapMoved()
path, killPins = Overlays()
check(Names(killPins, "spot") == "Defias Thug,Kobold Worker", "back with OpenMap's")

-- The switches.
toggles.nodes.set(false)
check(not ns.settings.nodes and not toggles.nodes.get() and not M.mapOverlay(2092).shown, "nodes switched off")
toggles.nodes.set(true)
check(ns.settings.nodes and M.mapOverlay(2092).shown, "and on")
toggles.kills.set(false)
check(not TravelLogKillsDB.settings.map and #M.shown(select(2, Overlays()).children) == 0, "kills switched off")
toggles.kills.set(true)
check(toggles.kills.get() and #M.shown(select(2, Overlays()).children) == 2, "and on")
toggles.npcs.set(false)
check(not TravelLogNPCsDB.settings.worldMap and #M.shown(select(4, Overlays()).children) == 0, "NPCs switched off")
toggles.npcs.set(true)
check(toggles.npcs.get() and #M.shown(select(4, Overlays()).children) == 2, "and on")
SlashCmdList.TRAVELLOG("trail week")
toggles.trail.set(false)
check(ns.settings.trail == "off" and not toggles.trail.get() and not M.mapOverlay(2090).shown, "trail switched off")
toggles.trail.set(true)
check(ns.settings.trail == "week" and toggles.trail.get() and M.mapOverlay(2090).shown, "and back on at its range")
