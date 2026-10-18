-- Slash commands: /tl (or /travellog).
local _, ns = ...

local YARDS_PER_MILE = 1760
local TRAIL_RANGES = { session = true, today = true, week = true, all = true, off = true }

local function Count(n)
	local s = tostring(math.floor((n or 0) + 0.5))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^(-?),", "%1"))
end

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

--------------------------------------------------------------------------------
-- /tl stats
--------------------------------------------------------------------------------

local function ShowStats()
	local char, st = ns.char, ns.stats
	ns.Print("%s, level %d %s %s", ns.charKey, ns.profile.level or 0, UnitRace("player"), UnitClass("player"))

	local zone, zoneJumps = Top(st.jumpsByZone)
	ns.Print("Jumps: %s (%s this session)%s", Count(st.jumps), Count(ns.session.jumpCount),
		zone and (", most in %s (%s)"):format(zone, Count(zoneJumps)) or "")

	local d = st.distance or {}
	local total = Sum(d)
	ns.Print("Distance: %s yd (%.1f miles): foot %s, mount %s, flight %s, swim %s, ghost %s",
		Count(total), total / YARDS_PER_MILE, Count(d.foot), Count(d.mount), Count(d.flight),
		Count(d.swim), Count(d.ghost))

	local loot = st.loot or {}
	ns.Print("Loot: %s items from %s corpses/chests/nodes, plus %s in coins",
		Count(loot.items), Count(loot.opened), ns.MoneyText(loot.money))

	local v = st.vendor or {}
	ns.Print("Vendors: %s bought, %s sold, %s repairs; spent %s, earned %s",
		Count(v.bought), Count(v.sold), Count(v.repairs),
		ns.MoneyText((v.spent or 0) + (v.repairCost or 0)), ns.MoneyText(v.earned))

	local places = 0
	for _, subzones in pairs(st.places or {}) do
		for _ in pairs(subzones) do
			places = places + 1
		end
	end
	local quests = st.quests or {}
	ns.Print("Deaths %s, kills %s, quests done %s, flights %s, places visited %s",
		Count(st.deaths), Count(st.kills), Count(quests.completed), Count(st.flights), Count(places))

	local nodes = st.nodes or {}
	ns.Print("Nodes remembered: %s herbs, %s ore, %s chests, %s other",
		Count(nodes.herb), Count(nodes.ore), Count(nodes.chest), Count(nodes.object))

	local points = 0
	for _, s in ipairs(char.sessions) do
		points = points + ns.CountRecords(s.track, s == ns.session and ns.track.buffer)
	end
	ns.Print("In this character's file: %s sessions, %s path points, %s log entries%s",
		Count(#char.sessions), Count(points), Count(#char.log),
		#ns.ArchiveStatus() > 0 and " (older history: /tl archive)" or "")
end

local function ShowArchive(arg)
	if arg == "now" then
		local sessions, entries = ns.Rotate(true)
		if sessions + entries == 0 then
			ns.Print("nothing old enough to archive.")
		end
		ns.RefreshTrail()
	end
	local lines, keepDays = ns.ArchiveStatus()
	ns.Print("history older than %d days moves to the archive addons when the main file gets big.", keepDays)
	if #lines == 0 then
		print("  Nothing archived yet.")
	end
	for _, line in ipairs(lines) do
		print("  " .. line)
	end
end

local function ShowJumps()
	local list = {}
	for zone, n in pairs(ns.stats.jumpsByZone or {}) do
		list[#list + 1] = { zone = zone, n = n }
	end
	table.sort(list, function(a, b) return a.n > b.n end)
	ns.Print("Jumps: %s in total, %s this session", Count(ns.stats.jumps), Count(ns.session.jumpCount))
	for i = 1, math.min(10, #list) do
		ns.Print("  %s: %s", list[i].zone, Count(list[i].n))
	end
end

--------------------------------------------------------------------------------
-- /tl log
--------------------------------------------------------------------------------

local function Item(item, count)
	if count and count > 1 then
		return ("%sx%d"):format(item, count)
	end
	return item or "?"
end

local function Items(items)
	local parts = {}
	for _, it in ipairs(items or {}) do
		parts[#parts + 1] = Item(it.item, it.count)
	end
	return table.concat(parts, ", ")
end

local DESCRIBE = {
	area = function(e)
		return (e.first and "First visit to %s" or "Entered %s"):format(e.subzone or e.zone or "?")
	end,
	loot = function(e)
		local what = Items(e.items)
		if e.money then
			what = what == "" and ns.MoneyText(e.money) or what .. ", " .. ns.MoneyText(e.money)
		end
		local text = ("Looted %s from %s"):format(what, e.source or e.sourceType or "?")
		if e.lastHere then
			text = text .. (" (looted here %s before)"):format(ns.Ago(e.lastHere, e.time))
		end
		return text
	end,
	receive = function(e)
		local how = e.roll and ("won with a roll of %d"):format(e.roll) or e.how or "?"
		return ("Received %s (%s)"):format(Item(e.item, e.count), how)
	end,
	buy = function(e) return ("Bought %s for %s from %s"):format(Item(e.item, e.count), ns.MoneyText(e.price), e.vendor or "?") end,
	sell = function(e) return ("Sold %s for %s to %s"):format(Item(e.item, e.count), ns.MoneyText(e.price), e.vendor or "?") end,
	buyback = function(e) return ("Bought back %s for %s"):format(Item(e.item, e.count), ns.MoneyText(e.price)) end,
	repair = function(e) return ("Repaired for %s"):format(ns.MoneyText(e.price)) end,
	money = function(e) return ("%s %s (%s)"):format(e.amount > 0 and "Got" or "Paid", ns.MoneyText(math.abs(e.amount)), e.reason) end,
	flight = function(e) return ("Flew from %s to %s for %s"):format(e.from or "?", e.to or "?", ns.MoneyText(e.price)) end,
	landed = function(e) return e.seconds and ("Landed after %d:%02d"):format(math.floor(e.seconds / 60), e.seconds % 60) or "Landed" end,
	hearth = function(e) return ("Hearthed to %s"):format(e.to or "?") end,
	bind = function(e) return ("Hearthstone set to %s"):format(e.place or "?") end,
	death = function(e) return e.target and ("Died fighting %s"):format(e.target) or "Died" end,
	release = function() return "Released spirit" end,
	revive = function() return "Came back to life" end,
	level = function(e) return ("Reached level %d"):format(e.level) end,
	quest = function(e) return ("Accepted quest: %s"):format(e.title or e.id) end,
	questdone = function(e) return ("Completed quest: %s"):format(e.title or e.id) end,
	kill = function(e) return ("Killed %s (+%s xp)"):format(e.name, e.xp or "?") end,
	discover = function(e) return ("Discovered %s"):format(e.place) end,
}

local function ShowLog(n)
	local log = ns.char.log
	n = math.min(n, #log)
	ns.Print("Last %d events:", n)
	for i = #log - n + 1, #log do
		local e = log[i]
		local describe = DESCRIBE[e.type]
		local where = e.subzone or e.zone or "?"
		if e.x then
			where = ("%s (%.1f, %.1f)"):format(where, e.x, e.y)
		end
		print(("  %s  %s  |cff999999%s|r"):format(date("%m-%d %H:%M", e.time),
			describe and describe(e) or e.type, where))
	end
end

--------------------------------------------------------------------------------
-- Dispatch
--------------------------------------------------------------------------------

local function Help()
	ns.Print("commands:")
	print("  /tl stats - totals for this character")
	print("  /tl jumps - jumps per zone")
	print("  /tl log [n] - the last n recorded events (default 15)")
	print("  /tl trail session|today|week|all|off - what the world map shows (now: " .. ns.settings.trail .. ")")
	print("  /tl nodes on|off - looted chests and herbs/ore on the map (now: " .. (ns.settings.nodes and "on" or "off") .. ")")
	print("  /tl archive [now] - where older history is kept; \"now\" archives it right away")
	print("  /tl interval 1-5 - seconds between path points (now: " .. ns.settings.interval .. ")")
	print("  /tl wipe confirm - delete everything recorded for this character")
end

SLASH_TRAVELLOG1 = "/travellog"
SLASH_TRAVELLOG2 = "/tl"
SlashCmdList.TRAVELLOG = function(msg)
	if not ns.char then
		return
	end
	local command, arg = msg:lower():match("^%s*(%S*)%s*(.-)%s*$")
	if command == "" or command == "stats" then
		ShowStats()
	elseif command == "jumps" then
		ShowJumps()
	elseif command == "log" then
		ShowLog(tonumber(arg) or 15)
	elseif command == "trail" and TRAIL_RANGES[arg] then
		ns.settings.trail = arg
		ns.RefreshTrail()
		ns.Print("map trail: %s", arg)
	elseif command == "nodes" and (arg == "on" or arg == "off") then
		ns.settings.nodes = arg == "on"
		ns.RefreshTrail()
		ns.Print("chests and gathering nodes on the map: %s", arg)
	elseif command == "archive" then
		ShowArchive(arg)
	elseif command == "interval" and tonumber(arg) and tonumber(arg) >= 1 and tonumber(arg) <= 5 then
		ns.settings.interval = tonumber(arg)
		ns.Print("recording a path point every %s seconds while moving", arg)
	elseif command == "wipe" and arg == "confirm" then
		ns.WipeArchives(ns.charKey)
		ns.db.chars[ns.charKey] = nil
		TravelLogCharDB = nil
		ReloadUI()
	else
		Help()
	end
end
