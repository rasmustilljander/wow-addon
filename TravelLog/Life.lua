-- Life on the road: deaths and corpse runs, level-ups, quests, kills and
-- newly discovered places.
local _, ns = ...

--------------------------------------------------------------------------------
-- Deaths
--------------------------------------------------------------------------------

local state -- "alive", "dead" or "ghost"

ns.On("PLAYER_LOGIN", function()
	state = UnitIsGhost("player") and "ghost" or UnitIsDead("player") and "dead" or "alive"
end)

ns.On("PLAYER_DEAD", function()
	state = "dead"
	local target
	if UnitExists("target") and UnitCanAttack("player", "target") then
		target = ns.Clean(UnitName("target"))
	end
	ns.Log("death", { target = target, level = UnitLevel("player") })
	ns.Add(1, "deaths")
end)

-- Fires both when you release your spirit and when you're resurrected.
ns.On("PLAYER_ALIVE", function()
	if UnitIsGhost("player") then
		if state ~= "ghost" then
			state = "ghost"
			ns.Log("release")
		end
	elseif state ~= "alive" then
		state = "alive"
		ns.Log("revive")
	end
end)

ns.On("PLAYER_UNGHOST", function()
	if state ~= "alive" then
		state = "alive"
		ns.Log("revive")
	end
end)

--------------------------------------------------------------------------------
-- Levels
--------------------------------------------------------------------------------

ns.On("PLAYER_LEVEL_UP", function(level)
	ns.profile.level = level
	ns.Log("level", { level = level })
end)

--------------------------------------------------------------------------------
-- Quests
--------------------------------------------------------------------------------

-- Notes when something happened to a quest and returns its title, which the
-- client may have forgotten by the time you turn the quest in.
local function Note(questID, field)
	local quest = ns.char.quests[questID] or {}
	ns.char.quests[questID] = quest
	quest.title = ns.Clean(C_QuestLog.GetTitleForQuestID(questID)) or quest.title
	quest[field] = time()
	return quest.title
end

ns.On("QUEST_ACCEPTED", function(a, b)
	local questID = b or a -- older clients sent (questLogIndex, questID)
	local title = Note(questID, "accepted")
	ns.Log("quest", { id = questID, title = title })
	ns.Add(1, "quests", "accepted")
end)

-- Marked when you click "Complete Quest", before the reward money and items
-- arrive, so the money ledger and item log can tell they came from a quest.
if GetQuestReward then
	hooksecurefunc("GetQuestReward", function()
		ns.Mark("questdone")
	end)
end

ns.On("QUEST_TURNED_IN", function(questID, xp, money)
	ns.Mark("questdone")
	local title = Note(questID, "done")
	ns.Log("questdone", { id = questID, title = title, xp = xp, money = money })
	ns.Add(1, "quests", "completed")
end)

-- The quest log's Abandon button calls SetAbandonQuest, which picks the
-- selected quest, and its confirmation calls AbandonQuest. The quest then
-- leaves the log with QUEST_REMOVED, which also fires on turn-ins, so only
-- the quest you just abandoned counts.
local abandoning, abandoned

if C_QuestLog.SetAbandonQuest and C_QuestLog.GetAbandonQuest and C_QuestLog.AbandonQuest then
	hooksecurefunc(C_QuestLog, "SetAbandonQuest", function()
		abandoning = ns.Clean(C_QuestLog.GetAbandonQuest())
	end)
	hooksecurefunc(C_QuestLog, "AbandonQuest", function()
		abandoned = abandoning
	end)
end

ns.On("QUEST_REMOVED", function(questID)
	if not questID or questID ~= abandoned then
		return
	end
	abandoned = nil
	local title = Note(questID, "abandoned")
	ns.Log("questabandon", { id = questID, title = title })
	ns.Add(1, "quests", "abandoned")
end)

--------------------------------------------------------------------------------
-- Kills (from "X dies, you gain N experience")
--------------------------------------------------------------------------------

-- Left open-ended so rested and group bonus variants match too.
local killPattern = type(COMBATLOG_XPGAIN_FIRSTPERSON) == "string"
	and ns.ToPattern(COMBATLOG_XPGAIN_FIRSTPERSON:gsub("%.$", ""), true)

ns.On("CHAT_MSG_COMBAT_XP_GAIN", function(text)
	text = ns.Clean(text)
	if not killPattern or not text then
		return
	end
	local name, xp = text:match(killPattern)
	if not name then
		return
	end
	ns.Log("kill", { name = name, xp = tonumber(xp) })
	ns.Add(1, "kills")
	ns.Add(tonumber(xp) or 0, "xp", "kills")
end)

--------------------------------------------------------------------------------
-- Discoveries ("Discovered Goldshire: 30 experience gained")
--------------------------------------------------------------------------------

local discoveryPatterns = {}
for _, name in ipairs({ "ERR_ZONE_EXPLORED_XP", "ERR_ZONE_EXPLORED" }) do
	if type(_G[name]) == "string" then
		discoveryPatterns[#discoveryPatterns + 1] = ns.ToPattern(_G[name], true)
	end
end

local lastDiscovery

local function CheckDiscovery(text)
	text = ns.Clean(text)
	if type(text) ~= "string" then
		return
	end
	for _, pattern in ipairs(discoveryPatterns) do
		local place, xp = text:match(pattern)
		if place then
			-- The same message can arrive both as a UI message and in chat.
			if place ~= lastDiscovery or not ns.Recent("discovery", 5) then
				lastDiscovery = place
				ns.Mark("discovery")
				ns.Log("discover", { place = place, xp = tonumber(xp) })
				ns.Add(1, "discoveries")
			end
			return
		end
	end
end

ns.On("UI_INFO_MESSAGE", function(_, text)
	CheckDiscovery(text)
end)
ns.On("CHAT_MSG_SYSTEM", CheckDiscovery)
