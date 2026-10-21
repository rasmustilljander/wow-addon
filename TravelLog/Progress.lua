-- Progress while leveling: spells learned, new skills and skill milestones,
-- flight paths found and reputation standings reached.
local _, ns = ...

--------------------------------------------------------------------------------
-- Spells, abilities and recipes
--------------------------------------------------------------------------------

-- The same spell can be reported by an event and by a chat line, so each is
-- logged once within this many seconds.
local SPELL_DEDUPE = 5
local learned = {} -- spell ID and name -> GetTime() when logged

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
	ns.Log("spell", {
		id = id,
		name = name,
		rank = rank ~= "" and rank or nil,
		trainer = ns.open.trainer and ns.Clean(UnitName("npc")) or nil,
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
