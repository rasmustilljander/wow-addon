-- Path recording: where you walk, ride, swim and fly, plus zone changes,
-- flights, hearthstones and distance travelled.
local _, ns = ...

local HEARTHSTONE = 8690
local MAX_SPEED = 60   -- yards/second; anything faster is a teleport, not travel
local MIN_MOVE = 1     -- yards moved before a new point is worth recording

local last     -- last recorded path point
local prev     -- previous sample, for distance
local wasTaxi
local flight   -- the flight we're on, if any

local function Mode(h)
	if h.taxi then return "flight" end
	if h.dead then return "ghost" end
	if h.swimming then return "swim" end
	if h.mounted then return "mount" end
	return "foot"
end

local function WorldDistance(a, b)
	if a.inst and a.inst == b.inst and a.wx and b.wx then
		return math.sqrt((a.wx - b.wx) ^ 2 + (a.wy - b.wy) ^ 2)
	end
end

local function Moved(a, b)
	local d = WorldDistance(a, b)
	if d then
		return d >= MIN_MOVE
	end
	return a.map ~= b.map or math.abs(a.x - b.x) + math.abs(a.y - b.y) > 0.0002
end

local function Record(h)
	ns.track:Add(ns.Pack(h))
	last = h
end

local function Tick()
	local h = ns.Here()

	if prev then
		local d = WorldDistance(prev, h)
		local seconds = math.max(h.now - prev.now, 1)
		if d and d > 0 and d / seconds <= MAX_SPEED then
			ns.Add(d, "distance", Mode(h))
		end
	end
	prev = h

	if wasTaxi ~= nil and h.taxi ~= wasTaxi and not h.taxi then
		local e = ns.Log("landed")
		if flight then
			e.from, e.to, e.seconds = flight.from, flight.to, e.time - flight.time
			flight.seconds = e.seconds
			flight = nil
		end
	end
	wasTaxi = h.taxi

	if not h.x then
		return
	end
	if not last or last.map ~= h.map or last.flags ~= h.flags then
		Record(h)
	elseif h.t - last.t >= ns.settings.interval and Moved(last, h) then
		Record(h)
	end
end

ns.On("PLAYER_LOGIN", function()
	C_Timer.NewTicker(1, function()
		local ok, err = pcall(Tick)
		if not ok then
			geterrorhandler()(err)
		end
	end)
end)

--------------------------------------------------------------------------------
-- Zones and subzones
--------------------------------------------------------------------------------

local lastZone, lastSubzone

local function CheckArea()
	local zone = ns.Clean(GetRealZoneText()) or ""
	local subzone = ns.Clean(GetSubZoneText()) or ""
	if zone == "" or (zone == lastZone and subzone == lastSubzone) then
		return
	end
	lastZone, lastSubzone = zone, subzone

	ns.stats.places = ns.stats.places or {}
	local places = ns.stats.places
	places[zone] = places[zone] or {}
	local place = subzone ~= "" and subzone or zone
	local first = places[zone][place] == nil
	if first then
		places[zone][place] = time()
	end
	ns.Log("area", { first = first or nil })
end

for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
	ns.On(event, CheckArea)
end

--------------------------------------------------------------------------------
-- Flights, hearthstone, inn binding
--------------------------------------------------------------------------------

-- Taxi node info is cached when the flight map opens, because it's gone by the
-- time our TakeTaxiNode hook runs.
local nodes = {}

ns.On("TL_OPEN", function(context)
	if context ~= "taxi" or not NumTaxiNodes then
		return
	end
	wipe(nodes)
	for i = 1, NumTaxiNodes() do
		nodes[i] = { name = TaxiNodeName(i), kind = TaxiNodeGetType(i), cost = TaxiNodeCost(i) }
	end
end)

if TakeTaxiNode then
	hooksecurefunc("TakeTaxiNode", function(index)
		if not ns.char then
			return
		end
		local from
		for _, node in pairs(nodes) do
			if node.kind == "CURRENT" then
				from = node.name
			end
		end
		local to = nodes[index] or { name = TaxiNodeName(index), cost = TaxiNodeCost(index) }
		ns.Mark("flight")
		flight = ns.Log("flight", { from = from, to = to.name, price = to.cost })
		ns.Add(1, "flights")
	end)
end

ns.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
	if unit == "player" and ns.Clean(spellID) == HEARTHSTONE then
		ns.Log("hearth", { to = GetBindLocation() })
		ns.Add(1, "hearths")
	end
end)

ns.On("HEARTHSTONE_BOUND", function()
	ns.Log("bind", { place = GetBindLocation() })
end)
