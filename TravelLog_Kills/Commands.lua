-- Slash commands (/kills) and the kill count on mob tooltips.
local _, ns = ...

local function Count(n)
	local s = tostring(math.floor((n or 0) + 0.5))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^(-?),", "%1"))
end

local function Times(n)
	return n == 1 and "once" or Count(n) .. " times"
end

local function Place(k)
	return k.subzone and (k.zone .. " / " .. k.subzone) or k.zone or "?"
end

local function Where(k)
	local where = Place(k)
	if k.x then
		where = ("%s (%.1f, %.1f)"):format(where, k.x, k.y)
	end
	return where
end

local function SortedMobs()
	local list = {}
	for _, mob in pairs(ns.db.mobs) do
		list[#list + 1] = mob
	end
	table.sort(list, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.name < b.name
	end)
	return list
end

--------------------------------------------------------------------------------
-- /kills, /kills top
--------------------------------------------------------------------------------

local function ShowTop(n)
	local list = SortedMobs()
	ns.Print("%s kills of %s different mobs.", Count(ns.db.total), Count(#list))
	for i = 1, math.min(n, #list) do
		local mob = list[i]
		print(("  %s: %s, last %s ago"):format(mob.name, Count(mob.count), ns.Ago(mob.last)))
	end
end

--------------------------------------------------------------------------------
-- /kills recent
--------------------------------------------------------------------------------

local function ShowRecent(n)
	-- The last n kills of every mob, merged, newest first.
	local all = {}
	for _, mob in pairs(ns.db.mobs) do
		for i = #mob.kills, math.max(#mob.kills - n + 1, 1), -1 do
			local k = ns.UnpackKill(mob.kills[i])
			k.name = mob.name
			all[#all + 1] = k
		end
	end
	table.sort(all, function(a, b) return a.time > b.time end)
	ns.Print("Last %d kills:", math.min(n, #all))
	for i = 1, math.min(n, #all) do
		local k = all[i]
		print(("  %s  %s%s  |cff999999%s|r"):format(date("%m-%d %H:%M", k.time), k.name,
			k.xp and (" (+%d xp)"):format(k.xp) or "", Where(k)))
	end
end

--------------------------------------------------------------------------------
-- /kills <name>
--------------------------------------------------------------------------------

local SHOW_KILLS = 10
local SHOW_PLACES = 5

local function ShowMob(mob)
	ns.Print("%s: killed %s.", mob.name, Times(mob.count))
	print(("  First %s, last %s (%s ago)"):format(date("%Y-%m-%d %H:%M", mob.first),
		date("%Y-%m-%d %H:%M", mob.last), ns.Ago(mob.last)))

	local places, xp, assisted = {}, 0, 0
	for _, rec in ipairs(mob.kills) do
		local k = ns.UnpackKill(rec)
		local place = Place(k)
		places[place] = (places[place] or 0) + 1
		xp = xp + (k.xp or 0)
		assisted = assisted + (k.by and 1 or 0)
	end
	local list = {}
	for place, n in pairs(places) do
		list[#list + 1] = { place = place, n = n }
	end
	table.sort(list, function(a, b) return a.n > b.n end)
	local parts = {}
	for i = 1, math.min(SHOW_PLACES, #list) do
		parts[#parts + 1] = ("%s (%s)"):format(list[i].place, Count(list[i].n))
	end
	print("  Where: " .. table.concat(parts, ", ") .. (#list > SHOW_PLACES and ", ..." or ""))
	if xp > 0 or assisted > 0 then
		print(("  %s xp in total%s"):format(Count(xp),
			assisted > 0 and (", %s finished by party members"):format(Count(assisted)) or ""))
	end

	local first = math.max(#mob.kills - SHOW_KILLS + 1, 1)
	print(("  Last %d:"):format(#mob.kills - first + 1))
	for i = #mob.kills, first, -1 do
		local k = ns.UnpackKill(mob.kills[i])
		print(("    %s  %s%s%s"):format(date("%m-%d %H:%M", k.time), Where(k),
			k.xp and (" +%d xp"):format(k.xp) or "", k.by and (" (by %s)"):format(k.by) or ""))
	end
end

-- An exact name first, otherwise every mob whose name contains the text.
local function Find(text)
	text = text:lower()
	local matches = {}
	for _, mob in ipairs(SortedMobs()) do
		local name = mob.name:lower()
		if name == text then
			return { mob }
		elseif name:find(text, 1, true) then
			matches[#matches + 1] = mob
		end
	end
	return matches
end

local function Lookup(text)
	local matches = Find(text)
	if #matches == 0 then
		ns.Print("no kills of \"%s\" recorded.", text)
	elseif #matches == 1 then
		ShowMob(matches[1])
	else
		ns.Print("%d mobs match \"%s\":", #matches, text)
		for i = 1, math.min(15, #matches) do
			print(("  %s: %s"):format(matches[i].name, Count(matches[i].count)))
		end
	end
end

local function ShowTarget()
	if not UnitExists("target") then
		ns.Print("you have no target.")
		return
	end
	local name = ns.Clean(UnitName("target"))
	local _, id = ns.ParseGUID(UnitGUID("target"))
	local mob = ns.Mob(name, id)
	if mob then
		ShowMob(mob)
	else
		ns.Print("you haven't killed %s yet.", name or "your target")
	end
end

--------------------------------------------------------------------------------
-- Dispatch
--------------------------------------------------------------------------------

local function Help()
	ns.Print("commands:")
	print("  /kills [n] - the n mobs you've killed most (default 10)")
	print("  /kills <name> - how often, when and where you killed a mob")
	print("  /kills target - the same for your target")
	print("  /kills recent [n] - your last n kills (default 15)")
	print("  /kills wipe confirm - delete every recorded kill for this character")
end

SLASH_TRAVELLOGKILLS1 = "/kills"
SLASH_TRAVELLOGKILLS2 = "/tlk"
SlashCmdList.TRAVELLOGKILLS = function(msg)
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
	elseif command == "wipe" and arg == "confirm" then
		TravelLogKillsDB = nil
		ReloadUI()
	elseif command == "help" or command == "wipe" then
		Help()
	else
		Lookup(msg)
	end
end

--------------------------------------------------------------------------------
-- Tooltips: "Killed 54 times, last 2h ago" on mobs you've killed
--------------------------------------------------------------------------------

local function OnUnitTooltip(tooltip, data)
	if tooltip ~= GameTooltip or not ns.db or not data then
		return
	end
	local guid = ns.Clean(data.guid)
	local kind, id = ns.ParseGUID(guid)
	if kind ~= "Creature" and kind ~= "Vehicle" then
		return
	end
	local mob = ns.Mob(UnitNameFromGUID and ns.Clean(UnitNameFromGUID(guid)), id)
	if mob then
		tooltip:AddLine(("Killed %s, last %s ago"):format(Times(mob.count), ns.Ago(mob.last)), 0.9, 0.45, 0.45)
	end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
end
