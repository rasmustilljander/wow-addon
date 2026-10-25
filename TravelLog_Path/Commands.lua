-- Path's part of /tl: jumps, the map trail (yours and alts'), its curves
-- and fading, the recording interval and its lines in /tl stats, and the
-- same in the TravelLog window.
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

-- stats.formDistance keys in the order shown, with their labels.
local FORMS = { "cat", "bear", "travel", "aquatic", "moonkin", "ghostwolf", "stealth" }
local FORM_LABELS = { ghostwolf = "ghost wolf" }

-- "cat 1,200, stealth 300", formatting each distance with fmt; nil if none.
local function ByForm(st, fmt)
	local parts = {}
	for _, form in ipairs(FORMS) do
		local d = st.formDistance and st.formDistance[form]
		if d and d > 0 then
			parts[#parts + 1] = (FORM_LABELS[form] or form) .. " " .. fmt(d)
		end
	end
	return #parts > 0 and table.concat(parts, ", ") or nil
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
	local forms = ByForm(st, Count)
	if forms then
		tl.Print("Distance by form (yd): %s", forms)
	end

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

local function SetSmooth(percent)
	tl.settings.smooth = percent
	ns.RefreshTrail()
end

tl.Command("smooth", function()
	return "smooth 0-100 - how round the map trail's turns are, 0 for straight lines (now: " .. tl.settings.smooth .. ")"
end, function(arg)
	local percent = tonumber(arg)
	if not percent or percent < 0 or percent > 100 then
		return false
	end
	SetSmooth(math.floor(percent))
	tl.Print("map trail curves: %s%%", tl.settings.smooth)
end)

-- /tl fade: presets stretch the default shape (3h) to a total length.
local FADE_PRESETS = { "1h", "3h", "6h", "12h" }
local IS_PRESET = { off = true, ["1h"] = true, ["3h"] = true, ["6h"] = true, ["12h"] = true }
local FADE_TIMES = { "alphaFrom", "alphaTo", "widthFrom", "widthTo" }
local MAX_FADE = 10080 -- minutes, a week
local FADE_FLOORS = { opacity = { "alpha", 10 }, width = { "width", 30 } }

-- Saves a fade field, or nil when it's the default.
local function SetFade(key, value)
	if value == ns.TRAIL_FADE[key] then
		value = nil
	end
	tl.settings.trailFade[key] = value
end

local function ApplyPreset(preset)
	if preset == "off" then
		SetFade("on", false)
	else
		local hours = tonumber(preset:match("^(%d+)h$"))
		SetFade("on", true)
		for _, key in ipairs(FADE_TIMES) do
			SetFade(key, ns.TRAIL_FADE[key] * hours / 3)
		end
	end
	ns.RefreshTrail()
end

-- The preset the fade is at, or nil if changed otherwise.
local function CurrentPreset()
	local S = ns.FadeSetting
	if not S("on") then
		return "off"
	end
	for _, preset in ipairs(FADE_PRESETS) do
		local hours = tonumber(preset:match("^(%d+)h$"))
		local match = true
		for _, key in ipairs(FADE_TIMES) do
			if S(key) ~= ns.TRAIL_FADE[key] * hours / 3 then match = false end
		end
		if match then
			return preset
		end
	end
end

local function DescribeFade()
	local S = ns.FadeSetting
	if not S("on") then
		return "off"
	end
	return ("opacity to %d%% from %s to %s min, width to %d%% from %s to %s min"):format(S("alpha"),
		S("alphaFrom"), S("alphaTo"), S("width"), S("widthFrom"), S("widthTo"))
end

tl.Command("fade", function()
	return "fade on|off|default|1h|3h|6h|12h, fade opacity|width <from>-<to> <percent> - how the map trail fades"
		.. " over played minutes (now: " .. DescribeFade() .. ")"
end, function(arg)
	if arg == "" then
		tl.Print("map trail fade: %s", DescribeFade())
		return
	end
	if arg == "on" then
		SetFade("on", true)
		ns.RefreshTrail()
	elseif arg == "default" then
		wipe(tl.settings.trailFade)
		ns.RefreshTrail()
	elseif IS_PRESET[arg] then
		ApplyPreset(arg)
	else
		local what, from, to, percent = arg:match("^(%a+)%s+(%d+)%s*%-%s*(%d+)%s+(%d+)%%?$")
		local floor = FADE_FLOORS[what]
		from, to, percent = tonumber(from), tonumber(to), tonumber(percent)
		if not (floor and from < to and to <= MAX_FADE and percent >= floor[2] and percent <= 100) then
			return false
		end
		local key = floor[1]
		SetFade("on", true)
		SetFade(key .. "From", from)
		SetFade(key .. "To", to)
		SetFade(key, percent)
		ns.RefreshTrail()
	end
	tl.Print("map trail fade: %s", DescribeFade())
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
tl.AddStat("Travel", "Distance by form", function(st)
	local forms = ByForm(st, function(d) return ("%.1f"):format(d / YARDS_PER_MILE) end)
	return forms and forms .. " miles" or "none"
end)
tl.AddSetting("World map", "Your trail", function() return tl.settings.trail end, SetTrail, TRAIL_CHOICES)
tl.AddStepper("World map", nil, function() return ns.DescribeTrail(tl.settings.trail) end, function(step)
	SetTrail(ns.StepDay(tl.settings.trail, step))
end)
tl.AddSetting("World map", "Trail fade", CurrentPreset, ApplyPreset, { "off", unpack(FADE_PRESETS) })
tl.AddSetting("World map", "Trail curves (%)", function() return tl.settings.smooth end, SetSmooth, { 0, 25, 50, 75, 100 })
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
