-- TravelLog Nodes: remembers each chest, herb and ore spot you loot, by
-- place, so the map can show when you last emptied each one. Needs TravelLog,
-- whose loot recording tells it what was looted where.
local _, ns = ...
local tl = TravelLog

tl.Defaults({
	nodes = true, -- show looted chests, herbs and ore on the world map
})

local NODE_RADIUS = 10 -- yards; loot spots closer than this are the same node
local NODE_TIMES = 5   -- loot times kept per node

-- Bumped whenever a node changes, so the map knows when to redraw.
ns.version = 0

-- Other addons' nodes for the map (TravelLog_Share's, from other players).
-- get(mapID, add) calls add(node, from) for each node on that map, from
-- being who it came from. Call tl.NodesChanged() when they change.
ns.sources = {}

function tl.AddNodeSource(get)
	ns.sources[#ns.sources + 1] = get
end

function tl.NodesChanged()
	ns.version = ns.version + 1
end

--------------------------------------------------------------------------------
-- Saved data
--------------------------------------------------------------------------------

-- TravelLogNodesDB = {
--   maps = {   -- per uiMapID
--     [1429] = { { kind = "herb", name = "Peacebloom", id = 1618, x = 42.1, y = 65.3,
--                  inst = 0, a = -9000.0, b = -100.0, last = 1760000000,
--                  count = 8, times = { 1760000000, 1759998200, ... } } },
--   },
-- }

tl.On("PLAYER_LOGIN", function()
	TravelLogNodesDB = TravelLogNodesDB or {}
	local db = TravelLogNodesDB
	db.maps = db.maps or {}

	-- TravelLog kept the nodes in its own character file before this addon
	-- existed.
	local old = tl.char.nodes
	if old then
		for map, list in pairs(old) do
			local into = db.maps[map] or {}
			db.maps[map] = into
			for _, node in ipairs(list) do
				into[#into + 1] = node
			end
		end
		tl.char.nodes = nil
	end
	ns.db = db
end)

tl.On("TL_WIPE", function()
	TravelLogNodesDB = nil
end)

--------------------------------------------------------------------------------
-- Recording
--------------------------------------------------------------------------------

local kindBySpell

local function NodeKind(via)
	if not kindBySpell then
		kindBySpell = {}
		local herb, mining = C_Spell.GetSpellName(2366), C_Spell.GetSpellName(2575)
		if herb then kindBySpell[herb] = "herb" end
		if mining then kindBySpell[mining] = "ore" end
	end
	if not via then
		return "object"
	end
	return kindBySpell[via] or "chest"
end

local function IsNear(node, e, inst, a, b)
	if a and node.a and node.inst == inst then
		return (node.a - a) ^ 2 + (node.b - b) ^ 2 <= NODE_RADIUS ^ 2
	end
	return math.abs(node.x - e.x) + math.abs(node.y - e.y) <= 0.5
end

-- Finds or adds the node at this spot and notes the loot. Spawn points are
-- matched by kind and place rather than by object, because the same spot can
-- grow different herbs. Notes on the loot entry when the node was last
-- looted before, for /tl log. Fires TL_NODE(mapID, index, node) after.
local function Remember(e)
	if e.sourceType ~= "GameObject" or not (e.map and e.x) then
		return
	end
	local kind = NodeKind(e.via)
	local inst, a, b = tl.WorldPosition()
	local maps = ns.db.maps
	maps[e.map] = maps[e.map] or {}
	local list = maps[e.map]
	local node, index
	for i, n in ipairs(list) do
		if n.kind == kind and IsNear(n, e, inst, a, b) then
			node, index = n, i
			break
		end
	end
	if not node then
		node = { kind = kind, x = e.x, y = e.y, count = 0, times = {} }
		if a then
			node.inst, node.a, node.b = inst, tl.Round(a, 1), tl.Round(b, 1)
		end
		index = #list + 1
		list[index] = node
		tl.Add(1, "nodes", kind)
	end
	e.lastHere = node.last
	node.name = e.source or node.name
	node.id = e.sourceID or node.id
	node.last = e.time
	node.count = node.count + 1
	table.insert(node.times, 1, e.time)
	node.times[NODE_TIMES + 1] = nil
	ns.version = ns.version + 1
	tl.Fire("TL_NODE", e.map, index, node)
end

tl.On("TL_LOOT", Remember)

--------------------------------------------------------------------------------
-- /tl nodes, and a line in /tl stats and the TravelLog window
--------------------------------------------------------------------------------

tl.On("TL_STATS", function()
	local nodes, Count = tl.stats.nodes or {}, tl.Count
	tl.Print("Nodes remembered: %s herbs, %s ore, %s chests, %s other",
		Count(nodes.herb), Count(nodes.ore), Count(nodes.chest), Count(nodes.object))
end)

tl.AddStat("Loot", "Nodes", function()
	local nodes, Count = tl.stats.nodes or {}, tl.Count
	return ("%s herbs, %s ore, %s chests, %s other"):format(Count(nodes.herb), Count(nodes.ore),
		Count(nodes.chest), Count(nodes.object))
end)
tl.AddSetting("World map", "Looted nodes", function() return tl.settings.nodes end, function(on)
	tl.settings.nodes = on
	ns.RefreshMap()
end)

tl.Command("nodes", function()
	return "nodes on|off - looted chests and herbs/ore on the map (now: " .. (tl.settings.nodes and "on" or "off") .. ")"
end, function(arg)
	if arg ~= "on" and arg ~= "off" then
		return false
	end
	tl.settings.nodes = arg == "on"
	ns.RefreshMap()
	tl.Print("chests and gathering nodes on the map: %s", arg)
end)
