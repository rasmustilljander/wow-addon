-- Path's part of /tl: jumps, the map trail (yours and alts'), the recording
-- interval and its lines in /tl stats, and the same in the TravelLog window.
local _, ns = ...
local tl = TravelLog

local YARDS_PER_MILE = 1760
-- The window's buttons; /tl trail takes any range (see Range.lua).
local TRAIL_CHOICES = { "session", "today", "24h", "week", "all", "off" }

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

-- "12 (3 this session)", the session only for the character you're on.
local function Jumps(st, key)
	local jumps = tl.Count(st.jumps)
	return key == tl.charKey and ("%s (%s this session)"):format(jumps, tl.Count(ns.session.jumpCount)) or jumps
end

tl.On("TL_STATS", function(st, key)
	local Count = tl.Count
	local zone, zoneJumps = Top(st.jumpsByZone)
	tl.Print("Jumps: %s%s", Jumps(st, key), zone and (", most in %s (%s)"):format(zone, Count(zoneJumps)) or "")

	local d = st.distance or {}
	local total = Sum(d)
	tl.Print("Distance: %s yd (%.1f miles): foot %s, mount %s, flight %s, swim %s, ghost %s",
		Count(total), total / YARDS_PER_MILE, Count(d.foot), Count(d.mount), Count(d.flight),
		Count(d.swim), Count(d.ghost))

	if key ~= tl.charKey then
		return
	end
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

local function SetTrail(range)
	tl.settings.trail = range
	ns.RefreshTrail()
end

local function SetAltTrail(range)
	tl.settings.altTrail = range
	ns.RefreshTrail()
end

tl.Command("trail", function()
	return ("trail [alts] session|today|week|all|off|<n>h|<n>d|yesterday|<yyyy-mm-dd> - how far back the map trail goes (now: %s, alts: %s)")
		:format(ns.DescribeTrail(tl.settings.trail), ns.DescribeTrail(tl.settings.altTrail))
end, function(arg)
	local alts, text = arg:match("^(alts)%s+(%S+)$")
	local range = ns.ParseTrail(text or arg)
	if not range then
		return false
	end
	if alts then
		SetAltTrail(range)
		tl.Print("alts' map trail: %s", ns.DescribeTrail(range))
	else
		SetTrail(range)
		tl.Print("map trail: %s", ns.DescribeTrail(range))
	end
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

--------------------------------------------------------------------------------
-- The TravelLog window
--------------------------------------------------------------------------------

tl.AddStat("Travel", "Jumps", Jumps)
tl.AddStat("Travel", "Distance", function(st)
	return ("%.1f miles"):format(Sum(st.distance) / YARDS_PER_MILE)
end)
tl.AddSetting("World map", "Your trail", function() return tl.settings.trail end, SetTrail, TRAIL_CHOICES)
tl.AddStepper("World map", nil, function() return ns.DescribeTrail(tl.settings.trail) end, function(step)
	SetTrail(ns.StepDay(tl.settings.trail, step))
end)
tl.AddSetting("General", "Path interval (s)", function() return tl.settings.interval end, function(seconds)
	tl.settings.interval = seconds
end, { 1, 2, 3, 4, 5 })

-- Alts are known once the saved data is loaded, so their rows come last.
tl.On("PLAYER_LOGIN", function()
	local alts = ns.Alts()
	if #alts == 0 then
		return
	end
	tl.AddSetting("World map", "Alts' trail", function() return tl.settings.altTrail end, SetAltTrail, TRAIL_CHOICES)
	tl.AddStepper("World map", nil, function() return ns.DescribeTrail(tl.settings.altTrail) end, function(step)
		SetAltTrail(ns.StepDay(tl.settings.altTrail, step))
	end)
	for _, alt in ipairs(alts) do
		local _, _, _, color = GetClassColor(alt.profile.class)
		local label = ("|c%s%s|r, level %s"):format(color, alt.key, alt.profile.level or "?")
		tl.AddSetting("World map", label, function() return not tl.settings.hiddenAlts[alt.key] end, function(shown)
			tl.settings.hiddenAlts[alt.key] = not shown or nil
			ns.RefreshTrail()
		end, nil, true)
	end
end)
