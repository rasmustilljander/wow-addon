-- Slash commands: /npcs
local _, ns = ...

local SHOW = 15 -- search results listed

local function Line(m)
	local npc, sells = m.npc, ""
	if m.item then
		for _, it in pairs(npc.items) do
			if it.name == m.item then
				sells = (" - sells %s for %s"):format(it.name, ns.PriceText(it))
			end
		end
	end
	return ("  %s (%s), %s%s%s"):format(npc.name, ns.KindsText(npc), ns.Where(npc), sells,
		npc.hidden and " |cff999999[hidden]|r" or "")
end

local function Search(text)
	local found = ns.Search(text)
	if #found == 0 then
		ns.Print("no NPC matches \"%s\".", text)
		return
	end
	ns.Print("%d NPC%s \"%s\":", #found, #found == 1 and " matches" or "s match", text)
	for i = 1, math.min(SHOW, #found) do
		print(Line(found[i]))
	end
	if #found > SHOW then
		print(("  and %d more"):format(#found - SHOW))
	end
end

-- The NPC meant by "target" or a name (exact, or the only partial match):
-- its ID and record, or nil after saying why there isn't one.
local function Pick(text)
	if text == "target" then
		local _, id = ns.ParseGUID(UnitGUID("target"))
		if id and ns.db.npcs[id] then
			return id, ns.db.npcs[id]
		end
		ns.Print("your target isn't a saved NPC.")
		return
	end
	local lower, matches = text:lower(), {}
	for id, npc in pairs(ns.db.npcs) do
		local name = npc.name:lower()
		if name == lower then
			return id, npc
		elseif name:find(lower, 1, true) then
			matches[#matches + 1] = id
		end
	end
	if #matches == 1 then
		return matches[1], ns.db.npcs[matches[1]]
	end
	ns.Print(#matches == 0 and "no saved NPC is called \"%s\"." or "several NPCs match \"%s\", be more exact.", text)
end

local function Add()
	local id, npc = ns.Record("target")
	if id then
		ns.Print("saved %s (%s), %s.", npc.name, ns.KindsText(npc), ns.Where(npc))
	else
		ns.Print("target an NPC to save it.")
	end
end

local function OnOff(word)
	if word == "on" then
		return true
	elseif word == "off" then
		return false
	end
end

local function KindByWord(word)
	word = word:gsub("s$", "")
	for _, kind in ipairs(ns.KINDS) do
		if kind.key == word or kind.name:find(word, 1, true) == 1 then
			return kind
		end
	end
end

local function ShowKinds()
	local parts = {}
	for _, kind in ipairs(ns.KINDS) do
		parts[#parts + 1] = kind.key .. (ns.db.settings.hideKinds[kind.key] and " off" or " on")
	end
	ns.Print("kinds on the maps: %s", table.concat(parts, ", "))
end

local function Status()
	local s = ns.db.settings
	return ("minimap %s, world map %s"):format(s.minimap and "on" or "off", s.worldMap and "on" or "off")
end

local function Help()
	local npcs = 0
	for _ in pairs(ns.db.npcs) do
		npcs = npcs + 1
	end
	ns.Print("%s NPCs saved, selling %s items. Pins: %s.", ns.Count(npcs), ns.Count(ns.ItemCount()), Status())
	print("  /npcs <text> - NPCs whose name, title, place or items contain the text")
	print("  /npcs add - save your target")
	print("  /npcs forget <name>|target - delete a saved NPC")
	print("  /npcs hide|show <name>|target - one NPC's pins")
	print("  /npcs minimap on|off, /npcs map on|off - all pins on the minimap or world map")
	print("  /npcs kind <kind> on|off - one kind's pins (/npcs kinds lists them)")
	print("  /npcs window - search NPCs in the TravelLog window")
end

SLASH_TRAVELLOGNPCS1 = "/npcs"
SLASH_TRAVELLOGNPCS2 = "/tln"
SlashCmdList.TRAVELLOGNPCS = function(msg)
	if not ns.db then
		return
	end
	msg = msg:match("^%s*(.-)%s*$")
	local command, arg = msg:match("^(%S*)%s*(.-)$")
	command = command:lower()
	local s = ns.db.settings
	if msg == "" or msg == "help" then
		Help()
	elseif command == "add" and arg == "" then
		Add()
	elseif (command == "forget" or command == "hide" or command == "show") and arg ~= "" then
		local id, npc = Pick(arg)
		if not id then
			return
		end
		if command == "forget" then
			ns.Forget(id)
			ns.Print("forgot %s.", npc.name)
		else
			npc.hidden = command == "hide" or nil
			ns.Changed()
			ns.Print("%s: pins %s.", npc.name, npc.hidden and "hidden" or "shown")
		end
	elseif (command == "minimap" or command == "map") and OnOff(arg:lower()) ~= nil then
		s[command == "map" and "worldMap" or "minimap"] = OnOff(arg:lower())
		ns.Changed()
		ns.Print("pins: %s.", Status())
	elseif command == "kinds" and arg == "" then
		ShowKinds()
	elseif command == "kind" and arg ~= "" then
		local word, value = arg:lower():match("^(%S+)%s+(%S+)$")
		local kind = word and KindByWord(word)
		if not kind or OnOff(value) == nil then
			ns.Print("usage: /npcs kind <kind> on|off")
			return ShowKinds()
		end
		s.hideKinds[kind.key] = not OnOff(value) or nil
		ns.Changed()
		ShowKinds()
	elseif command == "window" and arg == "" then
		if ns.ShowWindow then
			ns.ShowWindow()
		else
			ns.Print("the NPC window needs TravelLog.")
		end
	else
		Search(msg)
	end
end
