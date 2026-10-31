-- TravelLog Nodes: remembers each chest, herb and ore spot any of your
-- characters loot, by place, so the map can show when it was last emptied
-- and by whom. Needs TravelLog, whose loot recording tells it what was
-- looted where.
local _, ns = ...
local tl = TravelLog

tl.Defaults({
	nodes = true,        -- show looted chests, herbs and ore on the world map
	nodeMinimap = true,  -- and on the minimap
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
-- Nodes
--------------------------------------------------------------------------------

local function IsNear(node, x, y, inst, a, b)
	if a and node.a and node.inst == inst then
		return (node.a - a) ^ 2 + (node.b - b) ^ 2 <= NODE_RADIUS ^ 2
	end
	return math.abs(node.x - x) + math.abs(node.y - y) <= 0.5
end

-- The node of this kind at this spot and its place in the map's list, added
-- if there's none. Spawn points are matched by kind and place rather than by
-- object, because the same spot can grow different herbs.
local function Find(map, kind, x, y, inst, a, b)
	local maps = ns.db.maps
	maps[map] = maps[map] or {}
	local list = maps[map]
	for i, node in ipairs(list) do
		if node.kind == kind and IsNear(node, x, y, inst, a, b) then
			return node, i
		end
	end
	local node = { kind = kind, x = x, y = y, times = {}, by = {}, counts = {} }
	if a then
		node.inst, node.a, node.b = inst, tl.Round(a, 1), tl.Round(b, 1)
	end
	list[#list + 1] = node
	return node, #list
end

-- Notes that a character looted the node at time t, keeping the newest
-- NODE_TIMES times.
local function AddTime(node, t, who)
	local i = 1
	while node.times[i] and node.times[i] > t do
		i = i + 1
	end
	if i <= NODE_TIMES then
		table.insert(node.times, i, t)
		table.insert(node.by, i, who)
		node.times[NODE_TIMES + 1], node.by[NODE_TIMES + 1] = nil, nil
	end
	node.last = node.times[1]
end

-- How many times all characters together looted the node.
function ns.Total(node)
	local n = 0
	for _, count in pairs(node.counts) do
		n = n + count
	end
	return n
end

--------------------------------------------------------------------------------
-- Saved data
--------------------------------------------------------------------------------

-- TravelLogNodesAccountDB = {
--   maps = {   -- per uiMapID
--     [1429] = { { kind = "herb", name = "Peacebloom", id = 1618, x = 42.1, y = 65.3,
--                  inst = 0, a = -9000.0, b = -100.0, last = 1760000000,
--                  times = { 1760000000, 1759998200, ... },
--                  by = { "Rasmus-Forever", "Altie-Forever", ... },
--                  counts = { ["Rasmus-Forever"] = 5, ["Altie-Forever"] = 3 } } },
--   },
-- }
-- by[i] is who looted at times[i]. Every character's nodes are in the
-- account-wide file, so all of them see and add to the same nodes.

tl.On("PLAYER_LOGIN", function()
	TravelLogNodesAccountDB = TravelLogNodesAccountDB or {}
	local db = TravelLogNodesAccountDB
	db.maps = db.maps or {}
	ns.db = db
end)

-- Takes a character ("Name-Realm") out of the shared nodes, dropping the
-- ones only it looted.
local function Remove(who)
	for _, list in pairs(ns.db.maps) do
		for i = #list, 1, -1 do
			local node = list[i]
			node.counts[who] = nil
			if next(node.counts) == nil then
				table.remove(list, i)
			else
				for j = #node.by, 1, -1 do
					if node.by[j] == who then
						table.remove(node.times, j)
						table.remove(node.by, j)
					end
				end
				node.last = node.times[1]
			end
		end
	end
	ns.version = ns.version + 1
end

tl.On("TL_WIPE", function()
	Remove(tl.charKey)
end)
tl.On("TL_FORGET", Remove)

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

-- Notes the loot on the node at this spot. Notes on the loot entry when the
-- node was last looted before, and by which alt if it wasn't you, for
-- /tl log. Fires TL_NODE(mapID, index, node) after.
local function Remember(e)
	if e.sourceType ~= "GameObject" or not (e.map and e.x) then
		return
	end
	local inst, a, b = tl.WorldPosition()
	local node, index = Find(e.map, NodeKind(e.via), e.x, e.y, inst, a, b)
	e.lastHere = node.last
	if node.by[1] ~= tl.charKey then
		e.lastBy = node.by[1]
	end
	node.name = e.source or node.name
	node.id = e.sourceID or node.id
	AddTime(node, e.time, tl.charKey)
	node.counts[tl.charKey] = (node.counts[tl.charKey] or 0) + 1
	ns.version = ns.version + 1
	tl.Fire("TL_NODE", e.map, index, node)
end

tl.On("TL_LOOT", Remember)

--------------------------------------------------------------------------------
-- /tl nodes, and a line in /tl stats and the TravelLog window
--------------------------------------------------------------------------------

local function Remembered()
	local n = { herb = 0, ore = 0, chest = 0, object = 0 }
	for _, list in pairs(ns.db.maps) do
		for _, node in ipairs(list) do
			n[node.kind] = (n[node.kind] or 0) + 1
		end
	end
	local Count = tl.Count
	return ("%s herbs, %s ore, %s chests, %s other"):format(Count(n.herb), Count(n.ore), Count(n.chest), Count(n.object))
end

tl.On("TL_STATS", function()
	tl.Print("Nodes remembered: %s (all characters)", Remembered())
end)

tl.AddStat("Loot", "Nodes", Remembered)
tl.AddSetting("World map", "Looted nodes on the minimap", function() return tl.settings.nodeMinimap end, function(on)
	tl.settings.nodeMinimap = on
	if ns.RefreshMinimap then ns.RefreshMinimap() end
end)
tl.AddSetting("World map", "Looted nodes on the world map", function() return tl.settings.nodes end, function(on)
	tl.settings.nodes = on
	ns.RefreshMap()
end)

tl.Command("nodes", function()
	return "nodes on|off - looted chests and herbs/ore on the world map (now: " .. (tl.settings.nodes and "on" or "off") .. ")"
end, function(arg)
	if arg ~= "on" and arg ~= "off" then
		return false
	end
	tl.settings.nodes = arg == "on"
	ns.RefreshMap()
	tl.Print("chests and gathering nodes on the world map: %s", arg)
end)
