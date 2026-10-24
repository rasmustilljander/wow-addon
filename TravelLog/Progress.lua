-- Progress while leveling: spells learned (and what the trainer charged), new
-- skills and skill milestones, talent points spent, flight paths found,
-- reputation standings reached and gained per faction, the first ride on each
-- mount, beasts tamed and your pet's level-ups, abandoning and stabling, the
-- first time you put on each piece of gear and Legacy Challenges earned.
local _, ns = ...

--------------------------------------------------------------------------------
-- Spells, abilities and recipes
--------------------------------------------------------------------------------

-- The same spell can be reported by an event and by a chat line, so each is
-- logged once within this many seconds.
local SPELL_DEDUPE = 5
local learned = {} -- spell ID and name -> GetTime() when logged

-- What was just bought from a trainer, so the spell it teaches gets its cost.
-- The trainer's list only says the name and rank, and the spell arrives
-- after the click.
local BOUGHT_FOR = 5 -- seconds a purchase waits for its spell
local bought = {}    -- { name, rank, cost, at }

if BuyTrainerService then
	hooksecurefunc("BuyTrainerService", function(index)
		if not ns.char or not GetTrainerServiceInfo then
			return
		end
		local name, _, _, _, rank = GetTrainerServiceInfo(index)
		local cost = ns.Clean(GetTrainerServiceCost and GetTrainerServiceCost(index))
		rank = ns.Clean(rank)
		for i = #bought, 1, -1 do
			if GetTime() - bought[i].at > BOUGHT_FOR then
				table.remove(bought, i)
			end
		end
		name = ns.Clean(name)
		if name then
			bought[#bought + 1] = {
				name = name, rank = rank ~= "" and rank or nil,
				cost = cost and cost > 0 and cost or nil, at = GetTime(),
			}
		end
	end)
end

-- The cost of the purchase that taught this spell, if one is waiting.
local function Cost(name, rank)
	for i, b in ipairs(bought) do
		if GetTime() - b.at <= BOUGHT_FOR and b.name == name and (not b.rank or not rank or b.rank == rank) then
			table.remove(bought, i)
			return b.cost
		end
	end
end

local function Learned(id, name)
	id = ns.Clean(id)
	if id and C_Spell then
		name = ns.Clean(C_Spell.GetSpellName(id)) or name
	end
	-- By ID when there is one: two ranks of a spell share a name.
	local key = id or name
	if not key then
		return
	end
	if learned[key] and GetTime() - learned[key] <= SPELL_DEDUPE then
		return
	end
	learned[key] = GetTime()
	if name then
		learned[name] = GetTime()
	end
	local rank = id and C_Spell and C_Spell.GetSpellSubtext and ns.Clean(C_Spell.GetSpellSubtext(id))
	rank = rank ~= "" and rank or nil
	ns.Log("spell", {
		id = id,
		name = name,
		rank = rank,
		trainer = ns.open.trainer and ns.Clean(UnitName("npc")) or nil,
		cost = Cost(name, rank),
	})
	ns.Add(1, "spells")
end

ns.On("LEARNED_SPELL_IN_SKILL_LINE", function(spellID, _, isGuildPerkSpell)
	if not isGuildPerkSpell then
		Learned(spellID)
	end
end)
ns.On("NEW_RECIPE_LEARNED", function(recipeID)
	Learned(recipeID)
end)

-- "You have learned a new spell: [Fireball]." The link carries the spell ID.
local learnPatterns = {}
for _, name in ipairs({ "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S", "ERR_LEARN_PASSIVE_S", "ERR_LEARN_RECIPE_S" }) do
	if type(_G[name]) == "string" then
		learnPatterns[#learnPatterns + 1] = ns.ToPattern(_G[name])
	end
end

--------------------------------------------------------------------------------
-- Skills: new ones, and every 25 points
--------------------------------------------------------------------------------

local SKILL_STEP = 25

-- Ranks are kept in the character file, so a skill hidden under a collapsed
-- header and shown again isn't taken for a new one. A skill missing from a
-- scan with every header open was dropped, and is forgotten so learning it
-- again counts. The first scan only remembers what you already have.
local function CheckSkills()
	if not (C_SkillInfo and C_SkillInfo.GetNumSkillLines) then
		return
	end
	local known = ns.char.skills
	local skills = known or {}
	local any, collapsed, seen = false, false, {}
	for i = 1, C_SkillInfo.GetNumSkillLines() do
		local info = C_SkillInfo.GetSkillLineInfo(i)
		if info and info.isHeader and ns.Clean(info.isCollapsed) then
			collapsed = true
		end
		local id = info and not info.isHeader and ns.Clean(info.skillID)
		local rank = id and ns.Clean(info.rank)
		if rank then
			any = true
			seen[id] = true
			local old = skills[id]
			if not old then
				if known then
					ns.Log("skill", { id = id, name = ns.Clean(info.name), rank = rank })
					ns.Add(1, "skills")
				end
			elseif rank > old then
				ns.Add(rank - old, "skillups")
				if math.floor(rank / SKILL_STEP) > math.floor(old / SKILL_STEP) then
					ns.Log("skillup", { id = id, name = ns.Clean(info.name), rank = rank })
				end
			end
			skills[id] = rank
		end
	end
	if any and not collapsed then
		for id in pairs(skills) do
			if not seen[id] then
				skills[id] = nil
			end
		end
	end
	if any then
		ns.char.skills = skills
	end
end

ns.On("PLAYER_LOGIN", CheckSkills)
ns.On("SKILL_LINES_CHANGED", CheckSkills)

--------------------------------------------------------------------------------
-- Talents: each point spent, and points taken back
--------------------------------------------------------------------------------

-- Forever's talents are the retail trait system (C_Traits) laid out as the
-- classic trees: one trait tree per class, whose display groups are the trees
-- you see. Ranks are kept per loadout (each spec has its own) in the
-- character file, so a reload, login or spec switch isn't taken for points
-- spent. The first scan of a loadout only remembers what it has.

-- Group ID -> the tree's name ("Fire").
local function TreeNames(treeID)
	local names = {}
	for _, info in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}) do
		names[info.groupID] = ns.Clean(info.displayName)
	end
	return names
end

-- The talent's name and spell ID.
local function Talent(configID, node)
	local entryID = node.activeEntry and node.activeEntry.entryID or (node.entryIDs or {})[1]
	local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
	local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
	if not def then
		return
	end
	local id = ns.Clean(def.spellID)
	local name = ns.Clean(def.overrideName)
	if (not name or name == "") and id and C_Spell then
		name = ns.Clean(C_Spell.GetSpellName(id))
	end
	return name ~= "" and name or nil, id
end

local function CheckTalents()
	if not (C_ClassTalents and C_Traits) then
		return
	end
	local configID = ns.Clean(C_ClassTalents.GetActiveConfigID())
	-- Points placed in the talent frame count once they're applied.
	if not configID or C_Traits.ConfigHasStagedChanges(configID) then
		return
	end
	local config = C_Traits.GetConfigInfo(configID)
	local treeID = config and config.treeIDs[1]
	local nodes = treeID and C_Traits.GetTreeNodes(treeID)
	if not nodes or #nodes == 0 then
		return
	end
	local all = ns.char.talents or {}
	ns.char.talents = all
	local known = all[configID]
	local ranks, gained, refunded, spent, trees = {}, {}, 0, 0, nil
	for _, nodeID in ipairs(nodes) do
		local node = C_Traits.GetNodeInfo(configID, nodeID)
		local old = known and known[nodeID] or 0
		local rank = node and ns.Clean(node.ranksPurchased)
		if not rank then
			rank = old -- unreadable: keep what we had
		elseif known and rank > old then
			trees = trees or TreeNames(treeID)
			local tree
			for _, groupID in ipairs(node.groupIDs or {}) do
				tree = tree or trees[groupID]
			end
			local name, id = Talent(configID, node)
			gained[#gained + 1] = { id = id, name = name, tree = tree, rank = rank,
				max = ns.Clean(node.maxRanks), points = rank - old > 1 and rank - old or nil }
		elseif rank < old then
			refunded = refunded + old - rank
		end
		ranks[nodeID] = rank > 0 and rank or nil
		spent = spent + rank
	end
	all[configID] = ranks
	if not known then
		return
	end
	local level = UnitLevel("player")
	-- A respec applied in one go: the reset first, then the new points.
	if refunded > 0 then
		ns.Log("talentreset", { points = refunded, spent = spent, level = level })
	end
	for _, t in ipairs(gained) do
		t.level = level
		ns.Log("talent", t)
		ns.Add(t.points or 1, "talents")
	end
end

ns.On("PLAYER_ENTERING_WORLD", CheckTalents)
ns.On("TRAIT_CONFIG_UPDATED", CheckTalents)
ns.On("TRAIT_CONFIG_LIST_UPDATED", CheckTalents)
ns.On("PLAYER_TALENT_UPDATE", CheckTalents)
ns.On("ACTIVE_TALENT_GROUP_CHANGED", CheckTalents)

--------------------------------------------------------------------------------
-- Flight paths
--------------------------------------------------------------------------------

local function CheckFlightPath(text)
	if type(ERR_NEWTAXIPATH) ~= "string" or ns.Clean(text) ~= ERR_NEWTAXIPATH then
		return
	end
	-- Shown both on screen and in chat.
	if not ns.Recent("taxipath", 5) then
		ns.Mark("taxipath")
		ns.Log("taxipath", { npc = ns.Clean(UnitName("npc")) })
		ns.Add(1, "flightPaths")
	end
	return true
end

ns.On("UI_INFO_MESSAGE", function(_, text)
	CheckFlightPath(text)
end)

--------------------------------------------------------------------------------
-- Reputation ("You are now Friendly with Stormwind.")
--------------------------------------------------------------------------------

local standingPattern, standingOrder
if type(FACTION_STANDING_CHANGED) == "string" then
	standingPattern, standingOrder = ns.ToPattern(FACTION_STANDING_CHANGED)
end
local lastStanding

local function CheckStanding(text)
	local standing, faction = ns.MatchPattern(text, standingPattern, standingOrder)
	if not standing then
		return
	end
	local key = standing .. faction
	if key ~= lastStanding or not ns.Recent("standing", 5) then
		lastStanding = key
		ns.Mark("standing")
		ns.Log("standing", { faction = faction, standing = standing })
	end
	return true
end

-- Each gain or loss ("Reputation with Stormwind increased by 25.") only adds
-- to the faction's totals: one entry per kill or quest would flood the log.
-- Open-ended, so the bonus variants ("... (+2.5 bonus)") match too.
local repPatterns = {}
for _, entry in ipairs({ { "FACTION_STANDING_INCREASED", "gained" }, { "FACTION_STANDING_DECREASED", "lost" } }) do
	if type(_G[entry[1]]) == "string" then
		local pattern, order = ns.ToPattern(_G[entry[1]], true)
		repPatterns[#repPatterns + 1] = { pattern = pattern, order = order, way = entry[2] }
	end
end

ns.On("CHAT_MSG_COMBAT_FACTION_CHANGE", function(text)
	text = ns.Clean(text)
	if type(text) ~= "string" then
		return
	end
	for _, rep in ipairs(repPatterns) do
		local faction, amount = ns.MatchPattern(text, rep.pattern, rep.order)
		amount = tonumber(amount)
		if amount then
			ns.Add(amount, "reputation", faction, rep.way)
			return
		end
	end
end)

--------------------------------------------------------------------------------
-- Mounts: the first ride on each one
--------------------------------------------------------------------------------

-- Mounting is a cast, so the mount is the spell cast just before.
local lastCast, lastCastAt
local wasMounted

ns.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
	if unit == "player" then
		lastCast, lastCastAt = ns.Clean(spellID), GetTime()
	end
end)

local function CheckMount()
	local mounted = IsMounted() and not UnitOnTaxi("player")
	local justMounted = mounted and not wasMounted
	wasMounted = mounted
	if not justMounted or not lastCast or GetTime() - lastCastAt > 5 then
		return
	end
	local mounts = ns.char.mounts or {}
	ns.char.mounts = mounts
	if mounts[lastCast] then
		return
	end
	mounts[lastCast] = time()
	ns.Log("mount", {
		id = lastCast,
		name = C_Spell and ns.Clean(C_Spell.GetSpellName(lastCast)),
		first = not ns.stats.mounts or nil,
	})
	ns.Add(1, "mounts")
end

-- Clients without the event are checked every second instead.
local mountEvent = ns.On("PLAYER_MOUNT_DISPLAY_CHANGED", CheckMount)

ns.On("PLAYER_LOGIN", function()
	wasMounted = IsMounted() and not UnitOnTaxi("player")
	if not mountEvent then
		C_Timer.NewTicker(1, function()
			local ok, err = pcall(CheckMount)
			if not ok then
				geterrorhandler()(err)
			end
		end)
	end
end)

--------------------------------------------------------------------------------
-- Pets: each beast you tame, your pet's levels, abandoning and the stable
--------------------------------------------------------------------------------

-- Tame Beast is a channel at your target. It worked if a pet appears once
-- the channel has run its full length; nothing else says so.
local TAME_BEAST = 1515
local TAME_LONGEST = 30 -- seconds a channel can last, when its end isn't known
local TAME_WAIT = 5     -- seconds after the channel for the pet to appear
local taming            -- { name, id, level, family, started, ends, stopped }

local function IsTame(spellID)
	spellID = ns.Clean(spellID)
	if spellID == TAME_BEAST then
		return true
	end
	local name = spellID and C_Spell and ns.Clean(C_Spell.GetSpellName(spellID))
	return name ~= nil and name == ns.Clean(C_Spell.GetSpellName(TAME_BEAST))
end

ns.On("UNIT_SPELLCAST_CHANNEL_START", function(unit, _, spellID)
	if unit ~= "player" or not IsTame(spellID) then
		return
	end
	local _, id = ns.ParseGUID(UnitGUID("target"))
	local level = ns.Clean(UnitLevel("target"))
	local ends = UnitChannelInfo and ns.Clean(select(5, UnitChannelInfo("player")))
	taming = {
		name = ns.Clean((UnitName("target"))),
		id = id,
		level = level and level > 0 and level or nil,
		family = UnitCreatureFamily and ns.Clean((UnitCreatureFamily("target"))),
		started = GetTime(),
		ends = ends and ends / 1000,
	}
end)

-- Moving or being hit too hard stops the channel early, and the beast stays
-- wild.
ns.On("UNIT_SPELLCAST_CHANNEL_STOP", function(unit, _, spellID)
	if unit == "player" and taming and IsTame(spellID) then
		if taming.ends and GetTime() < taming.ends - 1 then
			taming = nil
		else
			taming.stopped = GetTime()
		end
	end
end)
ns.On("UNIT_SPELLCAST_INTERRUPTED", function(unit, _, spellID)
	if unit == "player" and IsTame(spellID) then
		taming = nil
	end
end)

ns.On("UNIT_PET", function(unit)
	if unit ~= "player" or not taming or not UnitExists("pet") then
		return
	end
	local beast = taming
	taming = nil
	if GetTime() > (beast.stopped or beast.ends or beast.started + TAME_LONGEST) + TAME_WAIT then
		return
	end
	local pet = ns.Clean((UnitName("pet")))
	local name = beast.name or pet
	local family = beast.family or UnitCreatureFamily and ns.Clean((UnitCreatureFamily("pet")))
	ns.Log("tame", {
		name = name,
		id = beast.id,
		level = beast.level,
		family = family,
		-- Only a name of its own, not the beast's or its family's.
		pet = pet ~= name and pet ~= family and pet or nil,
		first = not ns.stats.tames or nil,
	})
	ns.Add(1, "tames")
end)

-- The pet out now, as its name, level and family.
local function PetInfo()
	return {
		name = ns.Clean((UnitName("pet"))),
		level = ns.Clean(UnitLevel("pet")),
		family = UnitCreatureFamily and ns.Clean((UnitCreatureFamily("pet"))),
	}
end

-- Level-ups: the pet out gaining levels. Only hunter pets: a warlock's demon
-- levels with its master.
local petSeen -- { key (its GUID), level } of the pet out now

local function CheckPetLevel()
	if select(2, UnitClass("player")) ~= "HUNTER" or not UnitExists("pet") then
		petSeen = nil
		return
	end
	local pet = PetInfo()
	local key = ns.Clean(UnitGUID("pet"))
	if not key or not pet.level or pet.level <= 0 then
		return
	end
	if petSeen and petSeen.key == key then
		for level = petSeen.level + 1, pet.level do
			ns.Log("petlevel", { name = pet.name, family = pet.family, level = level })
			ns.Add(1, "petLevels")
		end
	end
	petSeen = { key = key, level = pet.level }
end

ns.On("UNIT_PET", function(unit)
	if unit == "player" then
		CheckPetLevel()
	end
end)
ns.On("UNIT_LEVEL", function(unit)
	if unit == "pet" then
		CheckPetLevel()
	end
end)
ns.On("UNIT_PET_EXPERIENCE", function(unit)
	if unit == "player" then
		CheckPetLevel()
	end
end)

-- Abandoning: the pet's portrait menu asks to confirm, then calls
-- C_PetInfo.PetAbandon for the pet out. It worked if the pet is gone soon
-- after.
local ABANDON_WAIT = 5 -- seconds for the pet to go
local abandoning       -- { pet, at }

if C_PetInfo and C_PetInfo.PetAbandon then
	hooksecurefunc(C_PetInfo, "PetAbandon", function(petNumber)
		if ns.char and petNumber == nil and UnitExists("pet") then
			abandoning = { pet = PetInfo(), at = GetTime() }
		end
	end)
end

ns.On("UNIT_PET", function(unit)
	if unit ~= "player" or not abandoning or UnitExists("pet") then
		return
	end
	local pet = abandoning.pet
	local late = GetTime() - abandoning.at > ABANDON_WAIT
	abandoning = nil
	if not late then
		ns.Log("petabandon", pet)
		ns.Add(1, "petAbandons")
	end
end)

-- The stable: slot 1 holds the pet you can call, the others are stabled.
-- Moving a pet between them is seen by comparing the slots before and after
-- each update while the stable is open.
local PET_CONSTS = Constants and Constants.PetConsts or {}
local ACTIVE_SLOTS = PET_CONSTS.MAX_SUMMONABLE_HUNTER_PETS or 1
local STABLE_SLOTS = PET_CONSTS.NUM_PET_SLOTS_HUNTER or 3
local stableSlots -- pet number -> slot, while the stable is open

local function StablePets()
	local slots, pets = {}, {}
	for slot = 1, STABLE_SLOTS do
		local info = C_StableInfo.GetStablePetInfo(slot)
		local id = info and ns.Clean(info.petNumber)
		if id then
			slots[id] = slot
			pets[slot] = {
				id = id,
				name = ns.Clean(info.name),
				level = ns.Clean(info.level),
				family = ns.Clean(info.familyName),
			}
		end
	end
	return slots, pets
end

if C_StableInfo and C_StableInfo.GetStablePetInfo then
	ns.On("PET_STABLE_SHOW", function()
		stableSlots = StablePets()
	end)
	ns.On("PET_STABLE_UPDATE", function()
		if not stableSlots then
			return
		end
		local slots, pets = StablePets()
		local stabled, taken = {}, {}
		for slot = 1, STABLE_SLOTS do
			local pet = pets[slot]
			local was = pet and stableSlots[pet.id]
			if was and was <= ACTIVE_SLOTS and slot > ACTIVE_SLOTS then
				stabled[#stabled + 1] = pet
			elseif was and was > ACTIVE_SLOTS and slot <= ACTIVE_SLOTS then
				taken[#taken + 1] = pet
			end
		end
		-- In a swap, the pet put away comes first.
		for _, pet in ipairs(stabled) do
			ns.Log("petstable", { name = pet.name, level = pet.level, family = pet.family })
		end
		for _, pet in ipairs(taken) do
			ns.Log("petunstable", { name = pet.name, level = pet.level, family = pet.family })
		end
		-- Pets missing from this update (still loading) keep their last slot.
		for id, slot in pairs(slots) do
			stableSlots[id] = slot
		end
	end)
	ns.On("PET_STABLE_CLOSED", function()
		stableSlots = nil
	end)
end

--------------------------------------------------------------------------------
-- Gear: the first time you put on each item
--------------------------------------------------------------------------------

local FIRST_SLOT, LAST_SLOT = INVSLOT_FIRST_EQUIPPED or 1, INVSLOT_LAST_EQUIPPED or 19
-- Shirts and tabards are only for looks, so they're left out.
local SKIP_SLOT = { [INVSLOT_BODY or 4] = true, [INVSLOT_TABARD or 19] = true }
local worn = {} -- slot -> item link, to say what a new item replaced

local function WornLink(slot)
	return ns.Clean(GetInventoryItemLink("player", slot))
end

-- Remembers what each slot holds. Item IDs are kept in the character file,
-- so swapping back to an item (another weapon, an equipment set, after a
-- reload) isn't news. The first scan only remembers what you already wear.
local function ReadWorn()
	local seed = not ns.char.gear and {}
	for slot = FIRST_SLOT, LAST_SLOT do
		worn[slot] = WornLink(slot)
		local id = seed and worn[slot] and not SKIP_SLOT[slot] and ns.Clean(GetInventoryItemID("player", slot))
		if id then
			seed[id] = 0
			ns.char.gear = seed
		end
	end
end

local function CheckGear(slot)
	slot = ns.Clean(slot)
	if type(slot) ~= "number" or slot < FIRST_SLOT or slot > LAST_SLOT then
		return
	end
	if not ns.char.gear then
		return ReadWorn()
	end
	local link, replaced = WornLink(slot), worn[slot]
	worn[slot] = link
	local id = link and not SKIP_SLOT[slot] and ns.Clean(GetInventoryItemID("player", slot))
	if not id or ns.char.gear[id] then
		return
	end
	ns.char.gear[id] = time()
	local _, _, quality, level = C_Item.GetItemInfo(link)
	if C_Item.GetDetailedItemLevelInfo then
		level = C_Item.GetDetailedItemLevelInfo(link) or level
	end
	level = ns.Clean(level)
	ns.Log("equip", {
		slot = slot,
		item = link,
		ilvl = level and level > 0 and level or nil,
		quality = ns.Clean(quality),
		replaced = replaced,
	})
	ns.Add(1, "gear")
end

ns.On("PLAYER_LOGIN", ReadWorn)
ns.On("PLAYER_EQUIPMENT_CHANGED", CheckGear)

--------------------------------------------------------------------------------
-- Legacy Challenges: Forever's achievements
--------------------------------------------------------------------------------

-- alreadyEarned: another character on the account earned it first.
ns.On("ACHIEVEMENT_EARNED", function(id, alreadyEarned)
	id = ns.Clean(id)
	if not id then
		return
	end
	local name, points, reward, guild
	if GetAchievementInfo then
		local _
		_, name, points, _, _, _, _, _, _, _, reward, guild = GetAchievementInfo(id)
		name, points, reward = ns.Clean(name), ns.Clean(points), ns.Clean(reward)
	end
	local category = GetAchievementCategory and ns.Clean(GetAchievementCategory(id))
	category = category and GetCategoryInfo and ns.Clean((GetCategoryInfo(category))) or nil
	ns.Log("achievement", {
		id = id,
		name = name,
		points = points ~= 0 and points or nil,
		category = category,
		reward = reward ~= "" and reward or nil,
		already = ns.Clean(alreadyEarned) or nil,
		guild = ns.Clean(guild) or nil,
	})
	ns.Add(1, "achievements")
	ns.Add(points or 0, "achievementPoints")
end)

--------------------------------------------------------------------------------
-- Chat
--------------------------------------------------------------------------------

local function CheckChat(text)
	text = ns.Clean(text)
	if type(text) ~= "string" or CheckFlightPath(text) or (standingPattern and CheckStanding(text)) then
		return
	end
	for _, pattern in ipairs(learnPatterns) do
		local link = text:match(pattern)
		if link then
			local id = link:match("|H%a+:(%d+)")
			Learned(tonumber(id), link:match("%[(.-)%]") or link)
			return
		end
	end
end

ns.On("CHAT_MSG_SYSTEM", CheckChat)
ns.On("CHAT_MSG_COMBAT_FACTION_CHANGE", CheckChat)
