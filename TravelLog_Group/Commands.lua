-- Slash commands (/grouped) and the group count on player tooltips.
local _, ns = ...

local Count, Duration = ns.Count, ns.Duration

local function Times(n)
	return n == 1 and "once" or Count(n) .. " times"
end

local function Place(g)
	return g.subzone and (g.zone .. " / " .. g.subzone) or g.zone or "?"
end

-- "1h 5m in Westfall / Moonbrook, 12 kills, level 14, raid"
function ns.GroupText(g)
	local parts = { Place(g) }
	if g.kills > 0 then
		parts[#parts + 1] = g.kills == 1 and "1 kill" or Count(g.kills) .. " kills"
	end
	if g.level then
		parts[#parts + 1] = "level " .. g.level
	end
	if g.raid then
		parts[#parts + 1] = "raid"
	end
	return table.concat(parts, ", ")
end

-- Every player, most grouped with first.
function ns.SortedPlayers()
	local list = {}
	for _, player in pairs(ns.db.players) do
		list[#list + 1] = player
	end
	table.sort(list, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		if a.last ~= b.last then
			return a.last > b.last
		end
		return a.key < b.key
	end)
	return list
end
local SortedPlayers = ns.SortedPlayers

local function Last(player)
	if ns.db.open[player.key] then
		return "in your group now"
	end
	return ("last %s ago"):format(ns.Ago(player.last))
end

--------------------------------------------------------------------------------
-- /grouped, /grouped top
--------------------------------------------------------------------------------

local function ShowTop(n)
	local list = SortedPlayers()
	ns.Print("grouped %s with %s different players.", Times(ns.db.total), Count(#list))
	for i = 1, math.min(n, #list) do
		local player = list[i]
		print(("  %s: %s, %s, %s"):format(ns.Display(player), Times(player.count),
			Duration(ns.TimeWith(player)), Last(player)))
	end
end

--------------------------------------------------------------------------------
-- /grouped recent
--------------------------------------------------------------------------------

local function ShowRecent(n)
	-- The last n groups with every player, merged, newest first.
	local all = {}
	for _, player in pairs(ns.db.players) do
		local groups = ns.Groups(player)
		for i = #groups, math.max(#groups - n + 1, 1), -1 do
			local g = groups[i]
			g.who = ns.Display(player)
			all[#all + 1] = g
		end
	end
	table.sort(all, function(a, b) return a.start > b.start end)
	ns.Print("Last %d groups:", math.min(n, #all))
	for i = 1, math.min(n, #all) do
		local g = all[i]
		print(("  %s  %s, %s%s  |cff999999%s|r"):format(date("%m-%d %H:%M", g.start), g.who,
			Duration(g.seconds), g.now and " so far" or "", ns.GroupText(g)))
	end
end

--------------------------------------------------------------------------------
-- /grouped <name>
--------------------------------------------------------------------------------

local SHOW_GROUPS = 10

local function ShowPlayer(player)
	ns.Print("%s%s: grouped %s, %s in total.", ns.Display(player),
		player.class and (" (%s)"):format(player.class:sub(1, 1) .. player.class:sub(2):lower()) or "",
		Times(player.count), Duration(ns.TimeWith(player)))
	print(("  First %s, last %s (%s)"):format(date("%Y-%m-%d %H:%M", player.first),
		date("%Y-%m-%d %H:%M", player.last), Last(player)))
	local kills = ns.KillsWith(player)
	if kills > 0 then
		print(("  %s kills together"):format(Count(kills)))
	end
	local groups = ns.Groups(player)
	local first = math.max(#groups - SHOW_GROUPS + 1, 1)
	print(("  Last %d:"):format(#groups - first + 1))
	for i = #groups, first, -1 do
		local g = groups[i]
		print(("    %s  %s%s  %s"):format(date("%m-%d %H:%M", g.start), Duration(g.seconds),
			g.now and " so far" or "", ns.GroupText(g)))
	end
end

-- An exact name first, otherwise every player whose name contains the text.
function ns.Find(text)
	text = text:lower()
	local matches = {}
	for _, player in ipairs(SortedPlayers()) do
		local key, name = player.key:lower(), player.name:lower()
		if key == text or name == text then
			return { player }
		elseif key:find(text, 1, true) then
			matches[#matches + 1] = player
		end
	end
	return matches
end

local function Lookup(text)
	local matches = ns.Find(text)
	if #matches == 0 then
		ns.Print("you haven't grouped with \"%s\".", text)
	elseif #matches == 1 then
		ShowPlayer(matches[1])
	else
		ns.Print("%d players match \"%s\":", #matches, text)
		for i = 1, math.min(15, #matches) do
			print(("  %s: %s"):format(ns.Display(matches[i]), Times(matches[i].count)))
		end
	end
end

local function ShowTarget()
	if not UnitIsPlayer("target") then
		ns.Print("your target isn't a player.")
		return
	end
	local guid = ns.Clean(UnitGUID("target"))
	local player = guid and ns.byGUID[guid]
	if player then
		ShowPlayer(player)
	else
		ns.Print("you haven't grouped with %s.", ns.Clean(UnitName("target")) or "your target")
	end
end

--------------------------------------------------------------------------------
-- Dispatch
--------------------------------------------------------------------------------

local function Help()
	ns.Print("commands:")
	print("  /grouped [n] - the n players you've grouped with most (default 10)")
	print("  /grouped <name> - how often, when, how long and where you grouped with a player")
	print("  /grouped target - the same for your target")
	print("  /grouped recent [n] - your last n groups (default 15)")
	print("  /grouped window - every player and each time you grouped (needs TravelLog)")
	print("  /grouped wipe confirm - delete every recorded group for this character")
end

SLASH_TRAVELLOGGROUP1 = "/grouped"
SLASH_TRAVELLOGGROUP2 = "/tlg"
SlashCmdList.TRAVELLOGGROUP = function(msg)
	if not ns.db then
		return
	end
	msg = msg:match("^%s*(.-)%s*$")
	local command, arg = msg:lower():match("^(%S*)%s*(.-)$")
	if msg == "" or tonumber(msg) or command == "top" then
		ShowTop(tonumber(msg) or tonumber(arg) or 10)
	elseif command == "recent" then
		ShowRecent(tonumber(arg) or 15)
	elseif command == "target" and arg == "" then
		ShowTarget()
	elseif command == "window" and arg == "" then
		if ns.ShowWindow then
			ns.ShowWindow()
		else
			ns.Print("the group window needs TravelLog.")
		end
	elseif command == "wipe" and arg == "confirm" then
		TravelLogGroupDB = nil
		ReloadUI()
	elseif command == "help" or command == "wipe" then
		Help()
	else
		Lookup(msg)
	end
end

--------------------------------------------------------------------------------
-- Tooltips: "Grouped 3 times (4h 12m), last 2d ago" on players you know
--------------------------------------------------------------------------------

local function OnUnitTooltip(tooltip, data)
	if tooltip ~= GameTooltip or not ns.db or not data then
		return
	end
	local guid = ns.Clean(data.guid)
	local player = guid and ns.byGUID[guid]
	if player then
		tooltip:AddLine(("Grouped %s (%s), %s"):format(Times(player.count), Duration(ns.TimeWith(player)),
			Last(player)), 0.45, 0.7, 0.9)
	end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
end
