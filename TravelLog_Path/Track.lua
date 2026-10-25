-- Path recording: where you walk, ride, swim and fly, and how far you went
-- each way, in each shapeshift form and in stealth.
local _, ns = ...
local tl = TravelLog

local MAX_SPEED = 60   -- yards/second; anything faster is a teleport, not travel
local MIN_MOVE = 1     -- yards moved before a new point is worth recording

-- formDistance keys by GetShapeshiftFormID(), from Blizzard's constants.
local FORMS = { [1] = "cat", [3] = "travel", [4] = "aquatic", [5] = "bear", [16] = "ghostwolf", [31] = "moonkin", [35] = "moonkin" }

local last     -- last recorded path point
local prev     -- previous sample, for distance

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
	local h = tl.Here()

	if prev then
		local d = WorldDistance(prev, h)
		local seconds = math.max(h.now - prev.now, 1)
		if d and d > 0 and d / seconds <= MAX_SPEED then
			tl.Add(d, "distance", Mode(h))
			if FORMS[h.form] then
				tl.Add(d, "formDistance", FORMS[h.form])
			end
			if h.stealth then
				tl.Add(d, "formDistance", "stealth")
			end
		end
	end
	prev = h

	if not h.x then
		return
	end
	if not last or last.map ~= h.map or last.flags ~= h.flags then
		Record(h)
	elseif h.t - last.t >= tl.settings.interval and Moved(last, h) then
		Record(h)
	end
end

tl.On("PLAYER_LOGIN", function()
	C_Timer.NewTicker(1, function()
		local ok, err = pcall(Tick)
		if not ok then
			geterrorhandler()(err)
		end
	end)
end)
