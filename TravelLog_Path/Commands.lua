-- Path's part of /tl: jumps, the map trail, the recording interval and its
-- lines in /tl stats.
local _, ns = ...
local tl = TravelLog

local YARDS_PER_MILE = 1760
local TRAIL_RANGES = { session = true, today = true, week = true, all = true, off = true }

local function Sum(t)
	local total = 0
	for _, v in pairs(t or {}) do
		total = total + v
	end
	return total
end

local function Top(t)
	local best, bestCount
	for key, count in pairs(t or {}) do
		if not bestCount or count > bestCount then
			best, bestCount = key, count
		end
	end
	return best, bestCount
end

tl.On("TL_STATS", function()
	local st, Count = tl.stats, tl.Count
	local zone, zoneJumps = Top(st.jumpsByZone)
	tl.Print("Jumps: %s (%s this session)%s", Count(st.jumps), Count(ns.session.jumpCount),
		zone and (", most in %s (%s)"):format(zone, Count(zoneJumps)) or "")

	local d = st.distance or {}
	local total = Sum(d)
	tl.Print("Distance: %s yd (%.1f miles): foot %s, mount %s, flight %s, swim %s, ghost %s",
		Count(total), total / YARDS_PER_MILE, Count(d.foot), Count(d.mount), Count(d.flight),
		Count(d.swim), Count(d.ghost))

	local points = 0
	for _, s in ipairs(ns.db.sessions) do
		points = points + ns.CountRecords(s.track, s == ns.session and ns.track.buffer)
	end
	tl.Print("Path: %s points in %s sessions", Count(points), Count(#ns.db.sessions))
end)

tl.Command("jumps", "jumps - jumps per zone", function()
	local list = {}
	for zone, n in pairs(tl.stats.jumpsByZone or {}) do
		list[#list + 1] = { zone = zone, n = n }
	end
	table.sort(list, function(a, b) return a.n > b.n end)
	tl.Print("Jumps: %s in total, %s this session", tl.Count(tl.stats.jumps), tl.Count(ns.session.jumpCount))
	for i = 1, math.min(10, #list) do
		tl.Print("  %s: %s", list[i].zone, tl.Count(list[i].n))
	end
end)

tl.Command("trail", function()
	return "trail session|today|week|all|off - how far back the map trail goes (now: " .. tl.settings.trail .. ")"
end, function(arg)
	if not TRAIL_RANGES[arg] then
		return false
	end
	tl.settings.trail = arg
	ns.RefreshTrail()
	tl.Print("map trail: %s", arg)
end)

tl.Command("interval", function()
	return "interval 1-5 - seconds between path points (now: " .. tl.settings.interval .. ")"
end, function(arg)
	local seconds = tonumber(arg)
	if not seconds or seconds < 1 or seconds > 5 then
		return false
	end
	tl.settings.interval = seconds
	tl.Print("recording a path point every %s seconds while moving", arg)
end)
