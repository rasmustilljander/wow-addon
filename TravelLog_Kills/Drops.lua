-- Drops: what each mob's corpse held when you looted it, counted per mob, so
-- tooltips and /kills <name> can show what it drops and how often.
--
-- A loot window can hold several corpses at once; GetLootSourceInfo tells
-- which corpse each slot came from. Items are counted when the window opens,
-- taken or not, and each corpse only once, so skinning it or opening it
-- again adds nothing.
local _, ns = ...

local SEEN = 500 -- corpse GUIDs remembered
local ITEM_SLOT = Enum and Enum.LootSlotType and Enum.LootSlotType.Item or 1

local seen, seenCount = {}, 0

local function UnitWithGUID(guid)
	for _, unit in ipairs({ "mouseover", "target" }) do
		if ns.Clean(UnitGUID(unit)) == guid then
			return unit
		end
	end
end

-- The dead creature under the mouse or targeted, for a window that doesn't
-- say where its loot came from.
local function Corpse()
	for _, unit in ipairs({ "mouseover", "target" }) do
		local guid = ns.Clean(UnitGUID(unit))
		if guid and ns.Clean(UnitIsDead(unit)) and ns.ParseGUID(guid) == "Creature" then
			return guid
		end
	end
end

-- Where a slot's items came from: { { guid, count }, ... }.
local function Sources(slot, quantity)
	local out = {}
	if GetLootSourceInfo then
		local list = { GetLootSourceInfo(slot) }
		for i = 1, #list, 2 do
			local guid = ns.Clean(list[i])
			if guid then
				out[#out + 1] = { guid = guid, count = ns.Clean(list[i + 1]) or quantity }
			end
		end
	end
	return out
end

local function Save(guid, items, links)
	local kind, id = ns.ParseGUID(guid)
	if seen[guid] or kind ~= "Creature" then
		return
	end
	-- A creature that's still alive is being pickpocketed.
	local unit = UnitWithGUID(guid)
	if unit and ns.Clean(UnitIsDead(unit)) == false then
		return
	end
	local mob = id and ns.byID[id]
	local name = ns.NameOf(guid) or (mob and mob.name) or (id and "NPC #" .. id)
	if not name then
		return
	end
	if seenCount >= SEEN then
		seen, seenCount = {}, 0
	end
	seen[guid], seenCount = true, seenCount + 1

	local d = ns.db.drops[name]
	if not d then
		d = { looted = 0, items = {} }
		ns.db.drops[name] = d
	end
	d.looted = d.looted + 1
	for item, count in pairs(items) do
		local e = d.items[item]
		if not e then
			e = { 0, 0 }
			d.items[item] = e
		end
		e[1], e[2] = e[1] + 1, e[2] + count
		ns.db.items[item] = ns.db.items[item] or links[item]
	end
end

local function Record()
	if not ns.db or IsFishingLoot() then
		return
	end
	local corpses, order, links, fallback = {}, {}, {}, nil
	for slot = 1, GetNumLootItems() do
		local _, _, quantity = GetLootSlotInfo(slot)
		quantity = math.max(ns.Clean(quantity) or 1, 1)
		local link = GetLootSlotType(slot) == ITEM_SLOT and ns.Clean(GetLootSlotLink(slot))
		local item = link and tonumber(link:match("item:(%d+)"))
		if item then
			links[item] = link
		end
		local sources = Sources(slot, quantity)
		if #sources == 0 then
			fallback = fallback or Corpse()
			sources = fallback and { { guid = fallback, count = quantity } } or sources
		end
		-- Coins have no item but still mark a corpse as looted.
		for _, s in ipairs(sources) do
			local c = corpses[s.guid]
			if not c then
				c = {}
				corpses[s.guid], order[#order + 1] = c, s.guid
			end
			if item then
				c[item] = (c[item] or 0) + s.count
			end
		end
	end
	for _, guid in ipairs(order) do
		Save(guid, corpses[guid], links)
	end
end

ns.On("LOOT_READY", Record)
ns.On("LOOT_OPENED", Record)

--------------------------------------------------------------------------------
-- Reading them back
--------------------------------------------------------------------------------

-- A mob's drops, by its name or NPC ID.
function ns.Drops(name, id)
	local mob = ns.Mob(name, id)
	return (name and ns.db.drops[name]) or (mob and ns.db.drops[mob.name])
end

-- The first n of a mob's drops, most often first:
-- { { link, corpses, count }, ... }.
function ns.TopDrops(d, n)
	local list = {}
	for item, e in pairs(d.items) do
		list[#list + 1] = { item = item, link = ns.db.items[item] or ("item:" .. item), corpses = e[1], count = e[2] }
	end
	table.sort(list, function(a, b)
		if a.corpses ~= b.corpses then
			return a.corpses > b.corpses
		end
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.item < b.item
	end)
	for i = #list, (n or #list) + 1, -1 do
		list[i] = nil
	end
	return list
end

-- "30%", or "25% x1.5" when it comes in stacks of more than one on average.
function ns.DropChance(e, looted)
	local pct = e.corpses / looted * 100
	local text = pct < 1 and "<1%" or ("%d%%"):format(ns.Round(pct))
	local each = e.count / e.corpses
	if each > 1 then
		text = text .. (" x%s"):format(ns.Round(each, 1))
	end
	return text
end

-- An item link's name in its quality color, without the brackets.
function ns.ItemName(link)
	local color, name = link:match("^|c(%x+).-%[(.-)%]")
	if color then
		return ("|c%s%s|r"):format(color, name)
	end
	return link:match("%[(.-)%]") or link
end
