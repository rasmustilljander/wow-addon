-- Items used up: potions, food, bandages, reagents, ammo, and the materials
-- that go into crafts. No event says an item was used, so it's read from
-- your bags: what they lose that no open window, destroy, quest or gear
-- change explains. Your cast right before names the spell, when the client
-- shows it.
local _, ns = ...

local CAST_WINDOW = 1.5 -- seconds between your cast and the bag change it caused
local CRAFT_WAIT = 1    -- seconds a craft's "You create" line may come before or after its materials go
local MERGE = 30        -- seconds within which the same item used again adds to its entry
local UNEXPLAINED = 3   -- more different items than this vanishing at once, without a cast, isn't use
-- Windows that move items out of your bags (sales, trades, mail, auctions, banks).
local MOVES = { "merchant", "trade", "mail", "auction", "bank", "guildbank" }

local counts, links, sizes -- your bags as last seen: item ID -> count, item ID -> link, bag -> slots
local cast    -- your last finished cast: { spellID, at }
local pending -- items a cast used, waiting a moment in case it was a craft: { items, spellID, at }
local created -- the last crafted item's receive entry: { event, spellID, at }
local lastUse -- the last use entry and when it last grew: { event, at }

ns.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
	spellID = ns.Clean(spellID)
	if unit == "player" and spellID then
		cast = { spellID = spellID, at = GetTime() }
	end
end)

local function RecentCast()
	return cast and GetTime() - cast.at <= CAST_WINDOW and cast.spellID or nil
end

local function ReadBags()
	local c, l, s = {}, {}, {}
	for bag = Enum.BagIndex.Backpack, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS do
		s[bag] = C_Container.GetContainerNumSlots(bag)
		for slot = 1, s[bag] do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local id = info and ns.Clean(info.itemID)
			if id then
				c[id] = (c[id] or 0) + math.max(ns.Clean(info.stackCount) or 1, 1)
				l[id] = l[id] or ns.Clean(info.hyperlink)
			end
		end
	end
	return c, l, s
end

-- Gear and bags leave your bags to be worn, not used up. Ammo is used from them.
local function IsGear(id)
	local equipLoc = select(4, C_Item.GetItemInfoInstant(id))
	return type(equipLoc) == "string" and equipLoc ~= "" and equipLoc ~= "INVTYPE_AMMO"
		and not equipLoc:find("NON_EQUIP")
end

-- Adds { item, count } items into a list, one line per item.
local function AddTo(list, items)
	for _, it in ipairs(items) do
		local found
		for _, have in ipairs(list) do
			if have.item == it.item then
				have.count, found = have.count + it.count, true
			end
		end
		if not found then
			list[#list + 1] = { item = it.item, count = it.count }
		end
	end
	return list
end

-- One entry per item, or more of the last one when it's the same item used
-- the same way a moment ago (arrows, a stack of food).
local function LogUse(items, spellID)
	local spell = spellID and ns.Clean(C_Spell.GetSpellName(spellID))
	for _, it in ipairs(items) do
		local log, e = ns.char.log, lastUse and lastUse.event
		if e and log[#log] == e and e.item == it.item and e.spellID == spellID and GetTime() - lastUse.at <= MERGE then
			e.count = e.count + it.count
			ns.version = ns.version + 1
		else
			e = ns.Log("use", { item = it.item, count = it.count, spell = spell ~= "" and spell or nil, spellID = spellID })
		end
		lastUse = { event = e, at = GetTime() }
		ns.Add(it.count, "used", "items")
	end
end

local function Materials(e, items)
	e.materials = AddTo(e.materials or {}, items)
	ns.version = ns.version + 1
	for _, it in ipairs(items) do
		ns.Add(it.count, "used", "crafting")
	end
end

local function Flush()
	local p = pending
	pending = nil
	if p and ns.char then
		LogUse(p.items, p.spellID)
	end
end

-- Crafted items' receive entries, from Loot.lua: the materials already gone
-- are theirs, and any going in the next moment too.
ns.On("TL_CREATED", function(e)
	if pending and GetTime() - pending.at <= CRAFT_WAIT then
		Materials(e, pending.items)
		pending = nil
		return
	end
	created = { event = e, spellID = RecentCast(), at = GetTime() }
end)

local function Gone(items, spellID)
	local fight = ns.char.fight
	if fight then
		fight.used = fight.used or {}
		for _, it in ipairs(items) do
			fight.used[it.item] = (fight.used[it.item] or 0) + it.count
		end
	end
	if not spellID then
		return LogUse(items)
	end
	if created and created.spellID == spellID and GetTime() - created.at <= CRAFT_WAIT then
		return Materials(created.event, items)
	end
	if pending and pending.spellID ~= spellID then
		Flush()
	end
	if not pending then
		local p = { items = {}, spellID = spellID, at = GetTime() }
		pending = p
		C_Timer.After(CRAFT_WAIT, function()
			if pending == p then Flush() end
		end)
	end
	AddTo(pending.items, items)
end

local function Check()
	-- An item held on the cursor is on its way somewhere; look once it's down.
	if GetCursorInfo() then
		return
	end
	local was, wasLinks, wasSizes = counts, links, sizes
	counts, links, sizes = ReadBags()
	if not was then
		return
	end
	-- A bag put on, taken off or not readable yet: its items moved, or will show.
	for bag, n in pairs(sizes) do
		if wasSizes[bag] ~= n then
			return
		end
	end
	if ns.Recent("destroy", 2) or ns.Recent("questdone", 5) or ns.Recent("questabandon", 5) then
		return
	end
	local spellID = RecentCast()
	if not spellID then
		for _, context in ipairs(MOVES) do
			if ns.open[context] then
				return
			end
		end
	end
	local items = {}
	for id, n in pairs(was) do
		local left = counts[id] or 0
		if left < n and wasLinks[id] and not IsGear(id) then
			items[#items + 1] = { item = wasLinks[id], count = n - left, id = id }
		end
	end
	if #items == 0 or (not spellID and #items > UNEXPLAINED) then
		return
	end
	table.sort(items, function(a, b) return a.id < b.id end)
	for _, it in ipairs(items) do
		it.id = nil
	end
	Gone(items, spellID)
end

ns.On("BAG_UPDATE_DELAYED", Check)
-- Start over after a loading screen, when bags may have been unreadable.
ns.On("PLAYER_ENTERING_WORLD", function()
	counts, links, sizes = ReadBags()
end)
ns.On("PLAYER_LOGOUT", Flush)
