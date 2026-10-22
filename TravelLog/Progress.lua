-- Progress while leveling: spells learned (and what the trainer charged), new
-- skills and skill milestones, talent points spent, flight paths found,
-- reputation standings reached, the first ride on each mount and the first
-- time you put on each piece of gear.
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
-- header and shown again isn't taken for a new one. The first scan only
-- remembers what you already have.
local function CheckSkills()
	if not (C_SkillInfo and C_SkillInfo.GetNumSkillLines) then
		return
	end
	local known = ns.char.skills
	local skills = known or {}
	local any
	for i = 1, C_SkillInfo.GetNumSkillLines() do
		local info = C_SkillInfo.GetSkillLineInfo(i)
		local id = info and not info.isHeader and ns.Clean(info.skillID)
		local rank = id and ns.Clean(info.rank)
		if rank then
			any = true
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

local standingPattern = type(FACTION_STANDING_CHANGED) == "string" and ns.ToPattern(FACTION_STANDING_CHANGED)
local lastStanding

local function CheckStanding(text)
	local standing, faction = text:match(standingPattern)
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
