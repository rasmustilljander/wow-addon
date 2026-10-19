-- Travel: zone and subzone changes, flights (and landing), hearthstones and
-- where you set your hearthstone. Your path itself is TravelLog_Path's.
local _, ns = ...

local HEARTHSTONE = 8690

local wasTaxi
local flight   -- the flight we're on, if any

local function CheckLanded()
	local taxi = UnitOnTaxi("player") and true or false
	if wasTaxi and not taxi then
		local e = ns.Log("landed")
		if flight then
			e.from, e.to, e.seconds = flight.from, flight.to, e.time - flight.time
			flight.seconds = e.seconds
			flight = nil
		end
	end
	wasTaxi = taxi
end

ns.On("PLAYER_LOGIN", function()
	C_Timer.NewTicker(1, function()
		local ok, err = pcall(CheckLanded)
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
