-- Slash commands: /tl (or /travellog). /tl alone opens or closes the window.
local _, ns = ...

function ns.Count(n)
	local s = tostring(math.floor((n or 0) + 0.5))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^(-?),", "%1"))
end
local Count = ns.Count

-- Subcommands added with ns.Command, in the order they were added.
local commands, order = {}, {}

-- Adds "/tl <name> ...". run(arg) does it, and returns false when arg isn't
-- valid, which shows the help. help is its line there, after "/tl ", or a
-- function returning that line.
function ns.Command(name, help, run)
	if not commands[name] then
		order[#order + 1] = name
	end
	commands[name] = { help = help, run = run }
end

--------------------------------------------------------------------------------
-- /tl stats
--------------------------------------------------------------------------------

-- Every character's key ("Name-Realm"), the one you're on first, then the
-- others alphabetically.
function ns.Characters()
	local list = {}
	for key in pairs(ns.db.chars) do
		if key ~= ns.charKey then
			list[#list + 1] = key
		end
	end
	table.sort(list)
	table.insert(list, 1, ns.charKey)
	return list
end

-- Adds from's counters into into: numbers summed, nested tables merged,
-- anything else kept from the first character that has it.
local function AddUp(into, from)
	for k, v in pairs(from) do
		if type(v) == "table" then
			into[k] = AddUp(type(into[k]) == "table" and into[k] or {}, v)
		elseif type(v) == "number" and type(into[k]) == "number" then
			into[k] = into[k] + v
		elseif into[k] == nil then
			into[k] = v
		end
	end
	return into
end

-- A character's totals, or with no key every character's added up.
function ns.StatsFor(key)
	if key then
		return key == ns.charKey and ns.stats or (ns.db.chars[key] or {}).stats or {}
	end
	local total = {}
	for _, profile in pairs(ns.db.chars) do
		AddUp(total, profile.stats or {})
	end
	return total
end

-- Subzones visited, counted across zones. Added up, a place visited by
-- several characters counts once.
function ns.PlacesVisited(st)
	local places = 0
	for _, subzones in pairs((st or ns.stats).places or {}) do
		for _ in pairs(subzones) do
			places = places + 1
		end
	end
	return places
end

-- The character a /tl stats argument names: "Name" or "Name-Realm".
local function FindCharacter(arg)
	for _, key in ipairs(ns.Characters()) do
		if key:lower() == arg or (ns.db.chars[key].name or ""):lower() == arg then
			return key
		end
	end
end

local function ShowStats(arg)
	local key = ns.charKey
	if arg == "all" then
		key = nil
	elseif arg ~= "" then
		key = FindCharacter(arg)
		if not key then
			ns.Print("no character \"%s\". Known: %s", arg, table.concat(ns.Characters(), ", "))
			return
		end
	end
	local st = ns.StatsFor(key)
	if key == ns.charKey then
		ns.Print("%s, level %d %s %s", key, ns.profile.level or 0, UnitRace("player"), UnitClass("player"))
		local total, level = ns.Played()
		if total then
			ns.Print("Played %s, %s at this level", ns.Duration(total), ns.Duration(level))
		end
	elseif key then
		ns.Print("%s, level %d", key, ns.db.chars[key].level or 0)
	else
		ns.Print("All %d characters", #ns.Characters())
	end

	local loot = st.loot or {}
	ns.Print("Loot: %s items from %s corpses/chests/nodes, plus %s in coins",
		Count(loot.items), Count(loot.opened), ns.MoneyText(loot.money))

	local v = st.vendor or {}
	ns.Print("Vendors: %s bought, %s sold, %s repairs; spent %s, earned %s",
		Count(v.bought), Count(v.sold), Count(v.repairs),
		ns.MoneyText((v.spent or 0) + (v.repairCost or 0)), ns.MoneyText(v.earned))

	local quests = st.quests or {}
	ns.Print("Deaths %s, kills %s, quests done %s, flights %s, places visited %s",
		Count(st.deaths), Count(st.kills), Count(quests.completed), Count(st.flights), Count(ns.PlacesVisited(st)))
	ns.Print("Spells learned %s, new skills %s, skill points %s, flight paths found %s, mounts %s",
		Count(st.spells), Count(st.skills), Count(st.skillups), Count(st.flightPaths), Count(st.mounts))

	-- Companion addons add their own lines here, for these totals and this
	-- character (nil for all of them).
	ns.Fire("TL_STATS", st, key)

	if key == ns.charKey then
		ns.Print("In this character's file: %s sessions, %s log entries%s",
			Count(#ns.char.sessions), Count(#ns.char.log),
			ns.ArchiveStatus() and " (older history: /tl archive)" or "")
	end
end

local function ShowArchive(arg)
	if arg == "now" then
		if ns.Rotate(true) == 0 then
			ns.Print("nothing old enough to archive.")
		end
	end
	local size, installed, keepDays = ns.ArchiveStatus()
	ns.Print("history older than %d days moves to TravelLog_Archive when this character's file gets big.", keepDays)
	if size then
		print(("  Archived so far: about %.1f MB (all characters)"):format(size / 1048576))
	else
		print("  Nothing archived yet.")
	end
	if not installed then
		print("  TravelLog_Archive isn't installed, so old history stays in the character file.")
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
			local by = e.lastBy and " by " .. e.lastBy or ""
			text = text .. (" (looted here %s before%s)"):format(ns.Ago(e.lastHere, e.time), by)
		end
		return text
	end,
	receive = function(e)
		local how = e.roll and ("won with a roll of %d"):format(e.roll) or e.how or "?"
		local from = e.partner or e.sender
		return ("Received %s (%s%s)"):format(Item(e.item, e.count), how, from and " from " .. from or "")
	end,
	buy = function(e) return ("Bought %s for %s from %s"):format(Item(e.item, e.count), ns.MoneyText(e.price), e.vendor or "?") end,
	sell = function(e) return ("Sold %s for %s to %s"):format(Item(e.item, e.count), ns.MoneyText(e.price), e.vendor or "?") end,
	buyback = function(e) return ("Bought back %s for %s"):format(Item(e.item, e.count), ns.MoneyText(e.price)) end,
	repair = function(e) return ("Repaired for %s"):format(ns.MoneyText(e.price)) end,
	money = function(e)
		local who = e.partner or e.sender
		who = who and (e.amount > 0 and " from " or " to ") .. who or ""
		return ("%s %s (%s%s)"):format(e.amount > 0 and "Got" or "Paid", ns.MoneyText(math.abs(e.amount)), e.reason, who)
	end,
	flight = function(e) return ("Flew from %s to %s for %s"):format(e.from or "?", e.to or "?", ns.MoneyText(e.price)) end,
	landed = function(e) return e.seconds and ("Landed after %d:%02d"):format(math.floor(e.seconds / 60), e.seconds % 60) or "Landed" end,
	hearth = function(e) return ("Hearthed to %s"):format(e.to or "?") end,
	bind = function(e) return ("Hearthstone set to %s"):format(e.place or "?") end,
	death = function(e)
		local text = e.target and ("Died fighting %s"):format(e.target) or "Died"
		return e.level and ("%s at level %d"):format(text, e.level) or text
	end,
	release = function() return "Released spirit" end,
	revive = function() return "Came back to life" end,
	level = function(e)
		local text = ("Reached level %d"):format(e.level)
		return e.took and ("%s after %s at level %d"):format(text, ns.Duration(e.took), e.level - 1) or text
	end,
	quest = function(e) return ("Accepted quest: %s"):format(e.title or e.id) end,
	questdone = function(e) return ("Completed quest: %s"):format(e.title or e.id) end,
	questabandon = function(e) return ("Abandoned quest: %s"):format(e.title or e.id) end,
	kill = function(e) return ("Killed %s (+%s xp)"):format(e.name, e.xp or "?") end,
	discover = function(e) return ("Discovered %s"):format(e.place) end,
	spell = function(e)
		local text = "Learned " .. (e.name or e.id or "?")
		if e.rank then text = ("%s (%s)"):format(text, e.rank) end
		if e.trainer then text = ("%s from %s"):format(text, e.trainer) end
		return e.cost and ("%s for %s"):format(text, ns.MoneyText(e.cost)) or text
	end,
	skill = function(e) return ("Learned skill: %s"):format(e.name or e.id) end,
	skillup = function(e) return ("%s reached %d"):format(e.name or e.id, e.rank) end,
	taxipath = function(e) return e.npc and ("Found the flight path at %s"):format(e.npc) or "Found a flight path" end,
	standing = function(e) return ("Now %s with %s"):format(e.standing, e.faction) end,
	mount = function(e) return (e.first and "First mount: %s" or "First ride on %s"):format(e.name or e.id) end,
}

-- A log entry as text, and where it happened. TravelLog_Share sends these.
function ns.Describe(e)
	local describe = DESCRIBE[e.type]
	local where = e.subzone or e.zone or "?"
	if e.x then
		where = ("%s (%.1f, %.1f)"):format(where, e.x, e.y)
	end
	return describe and describe(e) or e.type, where
end

-- The Log tab and /tl log share these categories and labels. Every current
-- event type belongs to one category; an unknown future type still appears
-- under All and remains searchable by its saved fields.
local LOG_GROUP = {
	area = "Travel", flight = "Travel", landed = "Travel", hearth = "Travel", bind = "Travel",
	loot = "Loot", receive = "Loot",
	buy = "Trade", sell = "Trade", buyback = "Trade", repair = "Trade", money = "Trade",
	death = "Life", release = "Life", revive = "Life", level = "Life", quest = "Life",
	questdone = "Life", questabandon = "Life", kill = "Life", discover = "Life",
	spell = "Progress", skill = "Progress", skillup = "Progress", taxipath = "Progress",
	standing = "Progress", mount = "Progress",
}
local LOG_LABEL = {
	area = "Area", loot = "Loot", receive = "Item", buy = "Purchase", sell = "Sale",
	buyback = "Buyback", repair = "Repair", money = "Money", flight = "Flight",
	landed = "Landing", hearth = "Hearth", bind = "Hearth bind", death = "Death",
	release = "Spirit release", revive = "Revival", level = "Level", quest = "Quest accepted",
	questdone = "Quest completed", questabandon = "Quest abandoned", kill = "XP kill", discover = "Discovery", spell = "Spell",
	skill = "Skill", skillup = "Skill-up", taxipath = "Flight path", standing = "Reputation",
	mount = "Mount",
}

function ns.LogGroup(e)
	return LOG_GROUP[e.type] or "Other"
end

function ns.LogTypeLabel(e)
	return LOG_LABEL[e.type] or e.type or "Event"
end

-- Add every scalar saved in the entry, including nested loot items. This
-- lets one search field match IDs and less prominent fields as well as the
-- human-readable description.
local function SearchValues(out, value, seen)
	local kind = type(value)
	if kind == "string" then
		value = ns.Clean(value)
		if value then out[#out + 1] = value end
	elseif kind == "number" or kind == "boolean" then
		out[#out + 1] = tostring(value)
	elseif kind == "table" and not seen[value] then
		seen[value] = true
		for key, child in pairs(value) do
			if type(key) == "string" then out[#out + 1] = key end
			SearchValues(out, child, seen)
		end
	end
end

-- True when an entry is in group (nil means All) and every word in query
-- occurs in its type, description, date, location or any saved field.
function ns.LogMatches(e, query, group)
	if group and ns.LogGroup(e) ~= group then
		return false
	end
	query = (query or ""):lower()
	if query == "" then
		return true
	end
	local text, where = ns.Describe(e)
	local values = { ns.LogTypeLabel(e), ns.LogGroup(e), text, where,
		date("%Y-%m-%d %H:%M", e.time) }
	SearchValues(values, e, {})
	local haystack = table.concat(values, " "):lower()
	for word in query:gmatch("%S+") do
		local found = haystack:find(word, 1, true)
		-- Natural plurals such as "deaths" and "quests" match their type.
		if not found and word:sub(-1) == "s" then
			found = haystack:find(word:sub(1, -2), 1, true)
		end
		if not found then
			return false
		end
	end
	return true
end

local function ShowLog(arg)
	-- A count is a number on its own, so "2026-10-19" is a search.
	local number, query = arg:match("^(%d+)$")
	if not number then
		number, query = arg:match("^(%d+)%s+(.+)$")
	end
	local limit = tonumber(number) or 15
	query = query or arg
	local found = {}
	if limit > 0 then
		for i = #ns.char.log, 1, -1 do
			local e = ns.char.log[i]
			if ns.LogMatches(e, query) then
				found[#found + 1] = e
				if #found >= limit then break end
			end
		end
	end
	if query == "" then
		ns.Print("Last %d events:", #found)
	else
		ns.Print("Last %d events matching \"%s\":", #found, query)
	end
	for i = #found, 1, -1 do
		local text, where = ns.Describe(found[i])
		print(("  %s  %s  |cff999999%s|r"):format(date("%m-%d %H:%M", found[i].time), text, where))
	end
end

--------------------------------------------------------------------------------
-- Dispatch
--------------------------------------------------------------------------------

local function Help()
	ns.Print("commands:")
	print("  /tl - open or close the TravelLog window")
	print("  /tl stats [all|name] - totals for this character, all of them or another")
	print("  /tl log [n] [search] - the last matching events (default 15)")
	for _, name in ipairs(order) do
		local help = commands[name].help
		print("  /tl " .. (type(help) == "function" and help() or help))
	end
	print("  /tl archive [now] - where older history is kept; \"now\" archives it right away")
	print("  /tl wipe confirm - delete everything recorded for this character")
end

SLASH_TRAVELLOG1 = "/travellog"
SLASH_TRAVELLOG2 = "/tl"
SlashCmdList.TRAVELLOG = function(msg)
	if not ns.char then
		return
	end
	local command, arg = msg:lower():match("^%s*(%S*)%s*(.-)%s*$")
	if command == "" then
		ns.Toggle()
	elseif command == "stats" then
		ShowStats(arg)
	elseif command == "log" then
		ShowLog(arg)
	elseif command == "archive" then
		ShowArchive(arg)
	elseif command == "wipe" and arg == "confirm" then
		ns.WipeArchive(ns.charKey)
		ns.db.chars[ns.charKey] = nil
		TravelLogCharDB = nil
		ns.Fire("TL_WIPE") -- companion addons drop their files too
		ReloadUI()
	elseif not (commands[command] and commands[command].run(arg) ~= false) then
		Help()
	end
end
