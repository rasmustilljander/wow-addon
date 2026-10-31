-- Loot: what you took from corpses, pickpockets, chests, herbs, ore, fishing
-- and containers (with the source), plus items that arrive without a loot
-- window: quest rewards, crafts, roll wins and other pickups, and the rolls
-- you lost or passed on.
local _, ns = ...

local MONEY_SLOT = Enum and Enum.LootSlotType and Enum.LootSlotType.Money or 2
local CAST_WINDOW = 2 -- seconds between a cast finishing and the loot it opened

local current    -- the loot window being looted: { event, slots, guid }
local lastLoot   -- the last saved loot event, for coins that arrive late
local sent       -- the player's last UNIT_SPELLCAST_SENT, which names the target
local lastCast   -- the player's last finished cast: { target, spellID, at }
local lastUsed   -- last bag item the player used (clams, lockboxes, ...)
local looted, lootedCount = {}, 0 -- creature GUIDs looted lately, to spot skinning

ns.On("UNIT_SPELLCAST_SENT", function(unit, target, castGUID, spellID)
	if unit == "player" then
		sent = { target = ns.Clean(target), castGUID = ns.Clean(castGUID), spellID = ns.Clean(spellID) }
	end
end)

ns.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, castGUID, spellID)
	if unit ~= "player" then
		return
	end
	castGUID, spellID = ns.Clean(castGUID), ns.Clean(spellID)
	local target = sent and (sent.castGUID == castGUID or sent.spellID == spellID) and sent.target
	lastCast = { target = target ~= "" and target or nil, spellID = spellID, at = GetTime() }
end)

hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
	lastUsed = { item = C_Container.GetContainerItemLink(bag, slot), at = GetTime() }
end)

local function SpellName(spellID)
	return spellID and C_Spell.GetSpellName(spellID)
end

local function UnitWithGUID(guid)
	for _, unit in ipairs({ "target", "mouseover" }) do
		if ns.Clean(UnitGUID(unit)) == guid then
			return unit
		end
	end
end

-- Works out what is being looted. Called when the window opens, while the
-- target and the cast that opened it still describe the source.
local function Describe(e, guid, fromItem)
	local kind, id = ns.ParseGUID(guid)
	e.sourceType, e.sourceID = kind, id
	local unit = guid and UnitWithGUID(guid)
	e.source = unit and ns.Clean(UnitName(unit))

	-- Herb Gathering, Mining, Opening, Skinning... finish right before the
	-- loot window opens. Combat spells usually finish well before.
	local cast = lastCast and GetTime() - lastCast.at <= CAST_WINDOW and lastCast
	if IsFishingLoot() then
		e.sourceType = "Fishing"
	elseif fromItem or kind == "Item" then
		e.sourceType = "Item"
		if lastUsed and GetTime() - lastUsed.at < 10 then
			e.source = lastUsed.item
		end
	elseif kind == "GameObject" and cast then
		e.source = e.source or cast.target
		e.via = SpellName(cast.spellID)
	elseif kind == "Creature" and guid then
		-- A creature that's still alive is being pickpocketed. Its corpse,
		-- if it comes, is still its first loot.
		if unit and ns.Clean(UnitIsDead(unit)) == false then
			e.via = cast and SpellName(cast.spellID)
		-- Looting a corpse a second time means skinning (or mining, herbing) it.
		elseif cast and looted[guid] then
			e.via = SpellName(cast.spellID)
		elseif not looted[guid] then
			if lootedCount >= 500 then
				looted, lootedCount = {}, 0
			end
			looted[guid], lootedCount = true, lootedCount + 1
		end
	end
end

local function Open(fromItem)
	if current then
		-- LOOT_READY came first; LOOT_OPENED adds whether it's from an item.
		if fromItem and not current.fromItem then
			current.fromItem = true
			Describe(current.event, current.guid, true)
		end
		return
	end
	ns.Mark("loot")
	local slots, guid = {}, nil
	for slot = 1, GetNumLootItems() do
		local _, name, quantity = GetLootSlotInfo(slot)
		slots[slot] = {
			item = ns.Clean(GetLootSlotLink(slot)) or ns.Clean(name),
			count = math.max(quantity or 1, 1),
			money = GetLootSlotType(slot) == MONEY_SLOT,
		}
		if not guid and GetLootSourceInfo then
			guid = ns.Clean((GetLootSourceInfo(slot)))
		end
	end
	current = { event = ns.NewEvent("loot"), slots = slots, guid = guid, fromItem = fromItem }
	Describe(current.event, guid, fromItem)
end

ns.On("LOOT_READY", function()
	Open(false)
end)

ns.On("LOOT_OPENED", function(_, fromItem)
	Open(fromItem)
end)

ns.On("LOOT_SLOT_CLEARED", function(slot)
	ns.Mark("loot")
	local s = current and current.slots[slot]
	if s then
		s.taken = true
	end
end)

ns.On("LOOT_CLOSED", function()
	ns.Mark("loot")
	if not current then
		return
	end
	local e, items, tookMoney = current.event, {}, false
	for _, s in pairs(current.slots) do
		if s.taken and s.money then
			tookMoney = true
		elseif s.taken and s.item then
			items[#items + 1] = { item = s.item, count = s.count }
			ns.Add(s.count, "loot", "items")
		end
	end
	current = nil

	if #items == 0 and not tookMoney and not e.money then
		lastLoot = nil
		return
	end
	e.items = #items > 0 and items or nil
	-- Lets companion addons (TravelLog_Nodes) look at it, and add to it,
	-- before it's saved.
	ns.Fire("TL_LOOT", e)
	ns.Add(1, "loot", "opened")
	ns.Add(1, "loot", "bySource", e.sourceType or "Unknown")
	lastLoot = ns.Save(e)
end)

-- The loot event that coins arriving right now belong to, if any. Money from
-- the loot window can show up just after the window closes.
function ns.LootEventForMoney()
	if current then
		return current.event
	end
	if lastLoot and ns.Recent("loot", 2) then
		return lastLoot
	end
end

--------------------------------------------------------------------------------
-- Items received without a loot window
--------------------------------------------------------------------------------

-- Turns a localized format like "You receive loot: %sx%d." into a Lua pattern.
-- Numbered placeholders can appear in a different display order in some
-- locales, so keep their argument numbers alongside the pattern.
local function ToPattern(format, open)
	local order = {}
	for position in format:gmatch("%%(%d+)%$[sd]") do
		order[#order + 1] = tonumber(position)
	end
	local pattern = format:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
	pattern = pattern:gsub("%%%%%d+%%%$s", "(.+)"):gsub("%%%%%d+%%%$d", "(%%d+)")
	pattern = pattern:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
	return "^" .. pattern .. (open and "" or "$"), order[1] and order or nil
end
ns.ToPattern = ToPattern

-- Returns captures in format-argument order, rather than the order in which
-- numbered placeholders happen to be displayed.
function ns.MatchPattern(text, pattern, order)
	local captures = { text:match(pattern) }
	if not captures[1] or not order then
		return unpack(captures)
	end
	local reordered, count = {}, 0
	for i, position in ipairs(order) do
		reordered[position] = captures[i]
		count = math.max(count, position)
	end
	return unpack(reordered, 1, count)
end

-- Multiple-item variants first: the single variant would also match them.
local RECEIVE = {
	{ "LOOT_ITEM_SELF_MULTIPLE", "loot" },
	{ "LOOT_ITEM_SELF", "loot" },
	{ "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "received" },
	{ "LOOT_ITEM_PUSHED_SELF", "received" },
	{ "LOOT_ITEM_CREATED_SELF_MULTIPLE", "created" },
	{ "LOOT_ITEM_CREATED_SELF", "created" },
}
local patterns = {}
for _, entry in ipairs(RECEIVE) do
	local format = _G[entry[1]]
	if type(format) == "string" then
		local pattern, order = ToPattern(format)
		patterns[#patterns + 1] = { pattern = pattern, order = order, how = entry[2] }
	end
end

local function ReceivedHow(how)
	if how ~= "received" then
		return how
	end
	if ns.Recent("questdone", 3) then return "quest" end
	if ns.open.mail then return "mail" end
	if ns.open.trade then return "trade" end
	return how
end

-- A won roll can be reported twice: by LOOT_ITEM_ROLL_WON (which also works
-- in dungeons, where loot chat is hidden from addons) and by the "You receive
-- loot" chat line. Whichever comes second is folded into the first.
local ROLL_DEDUPE = 10
local rollWon = {}     -- item link -> when LOOT_ITEM_ROLL_WON logged it
local chatLooted = {}  -- item link -> { event, at } logged from chat

ns.On("LOOT_ITEM_ROLL_WON", function(item, count, _, roll)
	item = ns.Clean(item)
	if not item then
		return
	end
	count = ns.Clean(count) or 1
	local seen = chatLooted[item]
	if seen and GetTime() - seen.at <= ROLL_DEDUPE then
		seen.event.how, seen.event.roll = "roll", ns.Clean(roll)
		chatLooted[item] = nil
		ns.Add(-count, "received", "loot")
	else
		rollWon[item] = GetTime()
		ns.Log("receive", { item = item, count = count, how = "roll", roll = ns.Clean(roll) })
	end
	ns.Add(count, "received", "roll")
end)

ns.On("CHAT_MSG_LOOT", function(text)
	text = ns.Clean(text)
	if not text then
		return
	end
	for _, p in ipairs(patterns) do
		local item, count = ns.MatchPattern(text, p.pattern, p.order)
		if item then
			-- Loot-window items are already recorded with their source, and
			-- vendor purchases are recorded by the vendor module.
			if (p.how == "loot" and (current or ns.Recent("loot", 3)))
				or (p.how == "received" and ns.open.merchant) then
				return
			end
			if p.how == "loot" and rollWon[item] and GetTime() - rollWon[item] <= ROLL_DEDUPE then
				rollWon[item] = nil
				return
			end
			count = tonumber(count) or 1
			local how = ReceivedHow(p.how)
			local e = ns.Log("receive", ns.WithCounterpart({ item = item, count = count, how = how }, how))
			if how == "loot" then
				chatLooted[item] = { event = e, at = GetTime() }
			elseif how == "created" then
				-- Use.lua adds the materials it took.
				ns.Fire("TL_CREATED", e)
			end
			ns.Add(count, "received", how)
			return
		end
	end
end)

--------------------------------------------------------------------------------
-- Rolls lost or passed on
--------------------------------------------------------------------------------

-- The group loot history reports every roll, in dungeons too. Wins are logged
-- above as items received; this logs the rest once the roll is decided.
local ROLL_STATE = Enum and Enum.EncounterLootDropRollState or {}
local CHOICES = {
	[ROLL_STATE.NeedMainSpec or 0] = "need",
	[ROLL_STATE.NeedOffSpec or 1] = "offspec",
	[ROLL_STATE.Transmog or 2] = "transmog",
	[ROLL_STATE.Greed or 3] = "greed",
	[ROLL_STATE.Pass or 5] = "pass",
}
-- "encounterID:lootListKey" -> true while undecided, false once handled. Only
-- rolls seen undecided are logged, so history the client replays isn't.
local drops = {}

ns.On("LOOT_HISTORY_UPDATE_DROP", function(encounterID, lootListKey)
	encounterID, lootListKey = ns.Clean(encounterID), ns.Clean(lootListKey)
	local key = encounterID and lootListKey and encounterID .. ":" .. lootListKey
	local drop = key and drops[key] ~= false and C_LootHistory.GetSortedInfoForDrop(encounterID, lootListKey)
	if not drop then
		return
	end
	local winner = ns.Clean(drop.winner)
	if not winner and not ns.Clean(drop.allPassed) then
		drops[key] = true
		return
	end
	local pending, choice = drops[key], CHOICES[ns.Clean(drop.playerRollState)]
	drops[key] = false
	if not pending or not choice or (winner and ns.Clean(winner.isSelf)) then
		return
	end
	local mine
	for _, r in ipairs(ns.Clean(drop.rollInfos) or {}) do
		if ns.Clean(r.isSelf) then
			mine = ns.Clean(r.roll)
		end
	end
	ns.Log("roll", {
		item = ns.Clean(drop.itemHyperlink), choice = choice, roll = mine,
		winner = winner and ns.Clean(winner.playerName), winnerRoll = winner and ns.Clean(winner.roll),
	})
	ns.Add(1, "rolls", choice == "pass" and "passed" or "lost")
end)
