-- Travel: zone and subzone changes, flights (and landing), hearthstones and
-- other teleports, summons, boats and zeppelins, dungeons and raids, where
-- you set your hearthstone, and screenshots. Your path itself is
-- TravelLog_Path's.
local _, ns = ...

local HEARTHSTONE = 8690
local JUMP = 100       -- yards between two looks at your position that make a teleport...
local MAX_SPEED = 20   -- ...plus this many yards a second you might have moved yourself
local CAUSE_WAIT = 5   -- seconds a cast or an accepted summon waits for its teleport
local CARRIED = 4      -- yards a second you move beyond your own speed on a boat or zeppelin
local BOARD_AFTER = 5  -- seconds carried before it counts as a ride
local ARRIVE_AFTER = 10 -- seconds not carried before the ride is over

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
-- Flights, inn binding
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

ns.On("HEARTHSTONE_BOUND", function()
	ns.Log("bind", { place = GetBindLocation() })
end)

--------------------------------------------------------------------------------
-- Hearthstones, teleports and summons
--------------------------------------------------------------------------------

-- Where you are, looked at every second and on zone changes. A teleport is a
-- jump between two looks that your own speed can't explain.
local function Sample()
	local s = { now = GetTime() }
	s.inst, s.wx, s.wy = ns.WorldPosition()
	s.zone = ns.Clean(GetRealZoneText()) or ""
	local subzone = ns.Clean(GetSubZoneText()) or ""
	s.place = subzone ~= "" and subzone or s.zone
	s.instanced = IsInInstance() and true or false
	s.taxi = UnitOnTaxi("player") and true or false
	s.dead = UnitIsDeadOrGhost("player") and true or false
	s.speed = GetUnitSpeed and ns.Clean((GetUnitSpeed("player")))
	return s
end

-- Yards between two looks: math.huge across continents or into or out of an
-- instance, nil when a position is unknown.
local function Distance(a, b)
	if a.instanced ~= b.instanced or (a.inst and b.inst and a.inst ~= b.inst) then
		return math.huge
	end
	if a.wx and b.wx then
		return math.sqrt((a.wx - b.wx) ^ 2 + (a.wy - b.wy) ^ 2)
	end
end

local last     -- the last look
local cast     -- { spell, at, from }: your last successful cast
local summon   -- { by, area, at, from }: the summon you accepted
local ride     -- the boat or zeppelin you're on, if any (see below)

ns.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
	spellID = ns.Clean(spellID)
	if unit == "player" and spellID then
		cast = { spell = spellID, at = GetTime(), from = last and last.place }
	end
end)

-- The summoner's name and where to are only known while the dialog is up.
local offered

ns.On("CONFIRM_SUMMON", function()
	offered = {
		by = ns.Clean(C_SummonInfo.GetSummonConfirmSummoner()),
		area = ns.Clean(C_SummonInfo.GetSummonConfirmAreaName()),
	}
end)

if C_SummonInfo and C_SummonInfo.ConfirmSummon then
	hooksecurefunc(C_SummonInfo, "ConfirmSummon", function()
		if not ns.char then
			return
		end
		local o = offered or {}
		summon = { by = o.by, area = o.area ~= "" and o.area or nil, at = GetTime(), from = last and last.place }
	end)
end

-- Whether you're where your hearthstone is set.
local function AtBind(here)
	local bind = ns.Clean(GetBindLocation())
	return bind ~= nil and (bind == here.place or bind == here.zone)
end

-- Logs how you got from where you were to here: a summon, a hearthstone (or
-- any cast that lands you where it's set), another teleport by a cast, or a
-- teleport with no cast of yours, such as another mage's portal.
local function Arrived(here, by)
	local data = { from = by and by.from or last and last.place, to = here.place ~= "" and here.place or nil }
	local kind = "teleport"
	if by and by == summon then
		kind, data.by = "summon", by.by
		data.to = data.to or by.area
		ns.Add(1, "summons")
	elseif by then
		data.spell = by.spell
		data.via = C_Spell and ns.Clean(C_Spell.GetSpellName(by.spell))
		if by.spell == HEARTHSTONE or AtBind(here) then
			kind = "hearth"
			ns.Add(1, "hearths")
		end
	end
	if kind == "teleport" then
		ns.Add(1, "teleports")
	end
	ns.Log(kind, data)
end

-- Whether a cast or summon could have moved you since the last look.
local function Fresh(cause)
	return cause ~= nil and cause.at >= last.now - CAUSE_WAIT
end

local function CheckJump(ticking)
	local here = Sample()
	if last and not ride and not (last.taxi or here.taxi or last.dead or here.dead) then
		local by = Fresh(summon) and summon or Fresh(cast) and cast or nil
		local d = Distance(last, here)
		local jumped
		if last.instanced ~= here.instanced then
			-- Into or out of an instance is its door, unless you were summoned
			-- or hearthed out.
			if by and by == cast and not (cast.spell == HEARTHSTONE or AtBind(here)) then
				by = nil
			end
			jumped = by ~= nil
		elseif d then
			jumped = d > JUMP + MAX_SPEED * (here.now - last.now)
		else
			jumped = summon ~= nil and by == summon and last.zone ~= here.zone
		end
		if jumped then
			Arrived(here, by)
			if by == summon then summon = nil elseif by then cast = nil end
		end
	end
	-- A hearthstone used close to the inn doesn't jump far enough to tell,
	-- but always takes you there. Only the ticker gives up on a cast, since
	-- it doesn't run during loading screens.
	if ticking then
		if cast and here.now - cast.at > CAUSE_WAIT then
			if cast.spell == HEARTHSTONE then
				Arrived(here, cast)
			end
			cast = nil
		end
		if summon and here.now - summon.at > CAUSE_WAIT then
			summon = nil
		end
	end
	last = here
	return here
end

for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
	ns.On(event, function()
		CheckJump(false)
	end)
end

--------------------------------------------------------------------------------
-- Boats and zeppelins
--------------------------------------------------------------------------------

-- The client says nothing about transports, but on one your position moves
-- while your own speed (GetUnitSpeed) stays near zero. A ride starts once
-- you've been carried for BOARD_AFTER seconds and ends after ARRIVE_AFTER
-- seconds on your own feet. Its entries are made where it started and
-- stopped, and saved once that's certain.
-- ride = { start, carried, still, board (entry), arrive (entry), boarded }
local lastTick

local function CheckRide(here)
	local before = lastTick
	lastTick = here
	if not before or here.now <= before.now then
		return
	end
	local d = Distance(before, here)
	local carried
	if d == math.huge then
		carried = ride ~= nil -- a zeppelin's loading screen halfway
	elseif d and here.speed and not (here.taxi or here.dead or before.taxi) then
		carried = d / (here.now - before.now) - here.speed > CARRIED
	else
		return
	end
	if carried then
		if not ride then
			ride = { start = before.now, carried = 0, still = 0, board = ns.NewEvent("board"), from = before.place }
		end
		ride.carried, ride.still, ride.last = ride.carried + 1, 0, here.now
		ride.arrive = ns.NewEvent("disembark", { from = ride.from, to = here.place })
		if not ride.boarded and ride.carried >= BOARD_AFTER then
			ride.boarded = true
			ns.Save(ride.board)
			ns.Add(1, "boats")
		end
	elseif ride then
		ride.still = ride.still + 1
		if not ride.boarded then
			ride = nil -- knocked back, or something else brief
		elseif ride.still >= ARRIVE_AFTER then
			ride.arrive.seconds = math.floor(ride.last - ride.start + 0.5)
			ns.Save(ride.arrive)
			ride = nil
		end
	end
end

ns.On("PLAYER_LOGIN", function()
	C_Timer.NewTicker(1, function()
		local ok, err = pcall(function()
			CheckLanded()
			CheckRide(CheckJump(true))
		end)
		if not ok then
			geterrorhandler()(err)
		end
	end)
end)

--------------------------------------------------------------------------------
-- Dungeons and raids
--------------------------------------------------------------------------------

local KINDS = { party = "dungeon", raid = "raid", pvp = "battleground", arena = "arena", scenario = "scenario" }

-- The instance you're in is kept in the character file, so a reload inside
-- doesn't make a new visit. Time inside counts only while you're logged in.
local function CheckInstance()
	local inside, instanceType = IsInInstance()
	local name, _, _, difficulty, maxPlayers, _, _, id = GetInstanceInfo()
	name, difficulty, maxPlayers, id = ns.Clean(name), ns.Clean(difficulty), ns.Clean(maxPlayers), ns.Clean(id)
	local kind = inside and name and KINDS[ns.Clean(instanceType)]
	local was = ns.char.instance
	if was and kind and was.name == name and was.id == id then
		return
	end
	if was then
		local seconds = was.inside + (was.since and time() - was.since or 0)
		ns.Log("instanceleave", { name = was.name, kind = was.kind, seconds = seconds })
		ns.Add(seconds, "instanceTime")
		ns.char.instance = nil
	end
	if kind then
		local data = {
			name = name, kind = kind, id = id,
			difficulty = difficulty ~= "" and difficulty or nil,
			size = maxPlayers and maxPlayers > 0 and maxPlayers or nil,
		}
		ns.Log("instance", data)
		ns.Add(1, "instances", kind)
		ns.char.instance = { name = name, kind = kind, id = id, inside = 0, since = time() }
	end
end

ns.On("PLAYER_ENTERING_WORLD", CheckInstance)
ns.On("ZONE_CHANGED_NEW_AREA", CheckInstance)

ns.On("PLAYER_LOGIN", function()
	if ns.char.instance then
		ns.char.instance.since = time()
	end
end)

ns.On("PLAYER_LOGOUT", function()
	local i = ns.char.instance
	if i and i.since then
		i.inside, i.since = i.inside + time() - i.since, nil
	end
end)

--------------------------------------------------------------------------------
-- Screenshots
--------------------------------------------------------------------------------

-- The game names the file after the local time it was taken, as
-- WoWScrnShot_MMDDYY_HHMMSS plus the format's extension. SCREENSHOT_STARTED
-- fires just before the picture is taken, SCREENSHOT_SUCCEEDED once it's
-- saved.
local shotAt

ns.On("SCREENSHOT_STARTED", function()
	shotAt = time()
end)

ns.On("SCREENSHOT_FAILED", function()
	shotAt = nil
end)

ns.On("SCREENSHOT_SUCCEEDED", function()
	local at = shotAt or time()
	shotAt = nil
	ns.Log("screenshot", { file = date("WoWScrnShot_%m%d%y_%H%M%S", at) })
	ns.Add(1, "screenshots")
end)
