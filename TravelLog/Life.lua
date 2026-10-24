-- Life on the road: deaths (what killed you and how you came back),
-- level-ups, quests, kills and newly discovered places.
local _, ns = ...

--------------------------------------------------------------------------------
-- Deaths
--------------------------------------------------------------------------------

local state -- "alive", "dead" or "ghost"

ns.On("PLAYER_LOGIN", function()
	state = UnitIsGhost("player") and "ghost" or UnitIsDead("player") and "dead" or "alive"
end)

-- What killed you, when the death recap doesn't say (see Recap below):
-- drowning and fatigue from the breath and fatigue bars, falling from a long
-- fall just before.

-- The breath and fatigue bars by the client's timer name: { scale, ends =
-- GetTime() it runs out while draining, stopped = GetTime() it went away }.
local timers = {}
local TIMER_CAUSES = { BREATH = "drowning", EXHAUSTION = "fatigue" }

ns.On("MIRROR_TIMER_START", function(name, value, _, scale, paused)
	name, value, scale, paused = ns.Clean(name), ns.Clean(value), ns.Clean(scale), ns.Clean(paused)
	if not name then
		return
	end
	local t = { scale = scale }
	if value and scale and scale < 0 and paused ~= 1 then
		t.ends = GetTime() + value / 1000 / -scale -- value is in milliseconds
	end
	timers[name] = t
end)

ns.On("MIRROR_TIMER_PAUSE", function(name, paused)
	local t = timers[ns.Clean(name)]
	if not t then
		return
	end
	t.ends = nil
	if ns.Clean(paused) == 0 and t.scale and t.scale < 0 then
		local left = ns.Clean(GetMirrorTimerProgress(name))
		t.ends = left and GetTime() + left / 1000 / -t.scale
	end
end)

ns.On("MIRROR_TIMER_STOP", function(name)
	local t = timers[ns.Clean(name)]
	if t then
		t.stopped = GetTime()
	end
end)

-- Falls, sampled every frame: { falling, start, stop } in GetTime().
local fall = {}
local FALL_SECONDS = 1.5 -- shorter falls do little or no damage
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	local falling = IsFalling() and true or false
	if falling and not fall.falling then
		fall.start = GetTime()
	elseif fall.falling and not falling then
		fall.stop = GetTime()
	end
	fall.falling = falling
end)

-- A bar that ran out in the last DAMAGE_SECONDS, and is still up or went
-- away with the death, killed you; it counts once.
local DAMAGE_SECONDS = 60

local function Cause()
	local now = GetTime()
	for name, cause in pairs(TIMER_CAUSES) do
		local t = timers[name]
		if t and t.ends and now >= t.ends and now - t.ends <= DAMAGE_SECONDS and now - (t.stopped or now) <= 2 then
			timers[name] = nil
			return cause
		end
	end
	-- Still falling, or landed within the last second.
	local landed = fall.falling and now or fall.stop
	if fall.start and landed and now - landed <= 1 and landed - fall.start >= FALL_SECONDS then
		return "falling"
	end
end

-- Worn items' durability, kept while alive, to tell how much dying (and the
-- spirit healer) cost: { [slot] = { now, max } }.
local worn

local function Durability()
	local list = {}
	for slot = INVSLOT_FIRST_EQUIPPED or 1, INVSLOT_LAST_EQUIPPED or 19 do
		local now, max = GetInventoryItemDurability(slot)
		now, max = ns.Clean(now), ns.Clean(max)
		if now and max and max > 0 then
			list[slot] = { now = now, max = max }
		end
	end
	return list
end

local function KeepDurability()
	if state == "alive" and not UnitIsDeadOrGhost("player") then
		worn = Durability()
	end
end
ns.On("PLAYER_LOGIN", KeepDurability)
ns.On("UPDATE_INVENTORY_DURABILITY", KeepDurability)
ns.On("PLAYER_EQUIPMENT_CHANGED", KeepDurability)

-- Average percentage points lost since before, over items worn both times
-- (so gear swapped while dead doesn't count), or nothing when none was.
local function DurabilityLost(before)
	local lost, n = 0, 0
	for slot, now in pairs(Durability()) do
		local was = before[slot]
		if was and was.max == now.max then
			lost, n = lost + (was.now - now.now) / now.max * 100, n + 1
		end
	end
	lost = n > 0 and ns.Round(lost / n) or 0
	return lost > 0 and lost or nil
end

-- The death recap (what the game's own Death Recap window shows): its hits
-- are newest first, and the first one killed you. Blizzard's window reads
-- event, spellName, spellId, sourceName, hideCaster, amount, overkill,
-- environmentalType and timestamp; it doesn't read sourceGUID, so that one
-- is optional.
local ENVIRONMENT = { DROWNING = "drowning", FALLING = "falling", FATIGUE = "fatigue", FIRE = "fire", LAVA = "lava", SLIME = "slime" }
local GUID_KINDS = { Creature = "Creature", Vehicle = "Creature", Player = "Player", Pet = "Pet" }
local usedRecap -- the killing blow's timestamp in the last recap seen, so it isn't used again

local function Field(hit, key, kind)
	local value = ns.Clean(hit[key])
	return type(value) == kind and value or nil
end

-- The latest recap's killing blow and its timestamp.
local function KillingBlow()
	if not (C_DeathRecap and C_DeathRecap.GetRecapEvents) then
		return
	end
	local ok, hits = pcall(C_DeathRecap.GetRecapEvents)
	hits = ok and ns.Clean(hits)
	local hit = type(hits) == "table" and ns.Clean(hits[1])
	if type(hit) == "table" then
		return hit, Field(hit, "timestamp", "number")
	end
end

-- A recap there at login is from an earlier death.
ns.On("PLAYER_LOGIN", function()
	local ok, _, stamp = pcall(KillingBlow)
	usedRecap = ok and stamp or nil
end)

-- What killed you, from a recap not used before: { killer, killerType,
-- killerID, spell, spellID, amount, overkill, cause }.
local function ReadRecap()
	local hit, stamp = KillingBlow()
	if not hit or stamp and stamp == usedRecap then
		return
	end
	usedRecap = stamp
	local event = Field(hit, "event", "string") or ""
	local found = {}
	if event == "ENVIRONMENTAL_DAMAGE" then
		local env = Field(hit, "environmentalType", "string")
		found.cause = env and (ENVIRONMENT[env:upper()] or env:lower())
	else
		if not ns.Clean(hit.hideCaster) then
			local name = Field(hit, "sourceName", "string")
			found.killer = name ~= "" and name or nil
			local kind, id = ns.ParseGUID(Field(hit, "sourceGUID", "string"))
			found.killerType = GUID_KINDS[kind]
			found.killerID = found.killerType == "Creature" and id or nil
		end
		if event:sub(1, 5) == "SPELL" or event == "RANGE_DAMAGE" then
			found.spell = Field(hit, "spellName", "string")
			found.spellID = Field(hit, "spellId", "number")
		end
	end
	found.amount = Field(hit, "amount", "number")
	local overkill = Field(hit, "overkill", "number")
	found.overkill = overkill and overkill > 0 and overkill or nil
	return found
end

-- Moves this death's count in the totals from one cause to another.
local function CountCause(from, to)
	local causes = ns.stats.deathCauses
	if from and causes and causes[from] then
		causes[from] = causes[from] > 1 and causes[from] - 1 or nil
	end
	if to then
		ns.Add(1, "deathCauses", to)
	end
end

-- Adds the recap to a death entry. The recap may not be ready during
-- PLAYER_DEAD, so this runs a frame later, and again a second after that if
-- there's nothing new yet. The recap's cause replaces the one guessed from
-- the bars and falls.
local function AddRecap(e, retry)
	local ok, found = pcall(ReadRecap)
	if not (ok and found) then
		if retry then
			C_Timer.After(1, function() AddRecap(e) end)
		end
		return
	end
	if found.cause ~= e.cause then
		CountCause(e.cause, found.cause)
	end
	for _, key in ipairs({ "killer", "killerType", "killerID", "spell", "spellID", "amount", "overkill" }) do
		e[key] = found[key]
	end
	e.cause = found.cause
	if found.killerType == "Player" or found.killerType == "Pet" then
		ns.Add(1, "deathCauses", "player")
	end
	ns.version = ns.version + 1
end

ns.On("PLAYER_DEAD", function()
	state = "dead"
	local target
	if UnitExists("target") and UnitCanAttack("player", "target") then
		target = ns.Clean(UnitName("target"))
	end
	local cause = Cause()
	local e = ns.Log("death", { target = target, level = UnitLevel("player"), cause = cause })
	ns.Add(1, "deaths")
	CountCause(nil, cause)
	C_Timer.After(0, function() AddRecap(e, true) end)
	fall.start = nil
end)

-- How you're coming back, from what you last chose: { how, by, spell,
-- sickness, at = GetTime() }. how is "corpse", "spirithealer", "player" or
-- "selfres". A choice older than COMEBACK_SECONDS didn't work.
local comeback
local COMEBACK_SECONDS = 30

local function ComingBack(data)
	data.at = GetTime()
	comeback = data
end

-- The last resurrection offered. The event names only the player, not the
-- spell.
local offer -- { by, sickness }

ns.On("RESURRECT_REQUEST", function(inviter)
	offer = { by = ns.Clean(inviter), sickness = ns.Clean(ResurrectHasSickness()) or nil }
end)

hooksecurefunc("AcceptResurrect", function()
	local by = offer and offer.by or ns.Clean(ResurrectGetOfferer())
	ComingBack({ how = "player", by = by ~= "" and by or nil, sickness = offer and offer.sickness })
end)

hooksecurefunc("RetrieveCorpse", function()
	ComingBack({ how = "corpse" })
end)

-- The spirit healer's dialog confirms the interaction. Resurrection sickness
-- comes with it from MIN_RES_SICKNESS_LEVEL, as that dialog says.
hooksecurefunc(C_PlayerInteractionManager, "ConfirmationInteraction", function(kind)
	if kind ~= Enum.PlayerInteractionType.SpiritHealer then
		return
	end
	local levels = Constants and Constants.LevelConstsExposed
	local sicknessLevel = levels and levels.MIN_RES_SICKNESS_LEVEL or 10
	ComingBack({ how = "spirithealer", sickness = UnitLevel("player") >= sicknessLevel or nil })
end)

-- Soulstone, Reincarnation and other ways back in the death dialog.
hooksecurefunc(C_DeathInfo, "UseSelfResurrectOption", function(kind, id)
	local spell
	for _, option in ipairs(C_DeathInfo.GetSelfResurrectOptions() or {}) do
		if option.optionType == kind and option.id == id then
			spell = ns.Clean(option.name)
		end
	end
	ComingBack({ how = "selfres", spell = spell })
end)

-- Seconds since the last death and since the spirit release after it, read
-- from the log so a reload while dead keeps them.
local function SinceDeath()
	local log, now = ns.char.log, time()
	local released
	for i = #log, math.max(#log - 500, 1), -1 do
		local e = log[i]
		if e.type == "release" then
			released = released or now - e.time
		elseif e.type == "death" then
			return now - e.time, released
		elseif e.type == "revive" then
			return
		end
	end
end

local function Revive()
	state = "alive"
	local data = {}
	if comeback and GetTime() - comeback.at <= COMEBACK_SECONDS then
		data.how, data.by, data.spell, data.sickness = comeback.how, comeback.by, comeback.spell, comeback.sickness
	end
	comeback, offer = nil, nil
	data.took, data.ghost = SinceDeath()
	local e = ns.Log("revive", data)
	ns.Add(1, "revives", data.how or "other")
	ns.Add(data.took or 0, "deadTime")
	-- The spirit healer's durability loss can arrive just after.
	local before = worn
	if before then
		C_Timer.After(1, function()
			e.durability = DurabilityLost(before)
			KeepDurability()
		end)
	end
end

-- Fires both when you release your spirit and when you're resurrected.
ns.On("PLAYER_ALIVE", function()
	if UnitIsGhost("player") then
		if state ~= "ghost" then
			state = "ghost"
			ns.Log("release")
		end
	elseif state ~= "alive" then
		Revive()
	end
end)

ns.On("PLAYER_UNGHOST", function()
	if state ~= "alive" then
		Revive()
	end
end)

--------------------------------------------------------------------------------
-- Levels
--------------------------------------------------------------------------------

-- The server tells time played only when asked (/played), so it's asked once
-- per login and counted forward from there.
local played -- { total, level, at }: seconds played in all and at this level, at GetTime() at

-- Seconds played in all and at the current level, or nothing before the
-- server has answered.
function ns.Played()
	if played then
		local since = math.floor(GetTime() - played.at)
		return played.total + since, played.level + since
	end
end

-- Asking prints the answer in chat like /played, so the chat frames stop
-- listening until it arrives.
local muted = {}

local function Unmute()
	for frame in pairs(muted) do
		frame:RegisterEvent("TIME_PLAYED_MSG")
	end
	muted = {}
end

ns.On("PLAYER_LOGIN", function()
	if not RequestTimePlayed then
		return
	end
	for _, name in ipairs(CHAT_FRAMES or {}) do
		local frame = _G[name]
		if frame and frame:IsEventRegistered("TIME_PLAYED_MSG") then
			frame:UnregisterEvent("TIME_PLAYED_MSG")
			muted[frame] = true
		end
	end
	RequestTimePlayed()
	C_Timer.After(10, Unmute) -- in case no answer comes
end)

ns.On("TIME_PLAYED_MSG", function(total, level)
	C_Timer.After(0, Unmute)
	total, level = ns.Clean(total), ns.Clean(level)
	if total and level then
		played = { total = total, level = level, at = GetTime() }
	end
end)

ns.On("PLAYER_LEVEL_UP", function(level)
	ns.profile.level = level
	local total, took = ns.Played()
	ns.Log("level", { level = level, played = total, took = took })
	if total then
		played = { total = total, level = 0, at = GetTime() }
	end
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
	ns.Add(tonumber(ns.Clean(xp)) or 0, "experience", "quests")
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

-- A quest fails when its timer runs out, an escort dies or a condition
-- breaks. No event says so: the quest stays in the log marked failed, so the
-- log is checked whenever it changes. A collapsed header hides its quests
-- from the log's list, so quests TravelLog saw you accept are checked by ID
-- too.
local open = {}      -- quest IDs that may be in the log
local deadlines = {} -- quest ID -> GetTime() its timer runs out

local function Ended(quest)
	local accepted = quest.accepted or 0
	return (quest.done or 0) >= accepted or (quest.abandoned or 0) >= accepted or (quest.failed or 0) >= accepted
end

local function CheckFailed(questID)
	local total, elapsed = C_QuestLog.GetTimeAllowed(questID)
	total, elapsed = ns.Clean(total), ns.Clean(elapsed)
	if total and elapsed and total > 0 then
		deadlines[questID] = GetTime() - elapsed + total
	end
	if not ns.Clean(C_QuestLog.IsFailed(questID)) then
		return
	end
	-- Logged once per time you take the quest, not again on a reload or
	-- when you abandon it afterwards.
	local quest = ns.char.quests[questID]
	if quest and quest.failed and quest.failed >= (quest.accepted or 0) then
		return
	end
	-- The client doesn't say why; a timer we saw run out is the one reason
	-- we can tell.
	local deadline = deadlines[questID]
	local reason = deadline and GetTime() >= deadline - 2 and "time" or nil
	local title = Note(questID, "failed")
	ns.Log("questfail", { id = questID, title = title, reason = reason })
	ns.Add(1, "quests", "failed")
end

if C_QuestLog.IsFailed and C_QuestLog.GetTimeAllowed and C_QuestLog.GetQuestIDForLogIndex then
	ns.On("PLAYER_LOGIN", function()
		for questID, quest in pairs(ns.char.quests) do
			if quest.accepted and not Ended(quest) then
				open[questID] = true
			end
		end
	end)

	ns.On("QUEST_ACCEPTED", function(a, b)
		open[b or a] = true
	end)

	ns.On("QUEST_REMOVED", function(questID)
		if questID then
			open[questID], deadlines[questID] = nil, nil
		end
	end)

	ns.On("QUEST_LOG_UPDATE", function()
		for i = 1, C_QuestLog.GetNumQuestLogEntries() do
			local questID = ns.Clean(C_QuestLog.GetQuestIDForLogIndex(i))
			if questID then
				open[questID] = true
			end
		end
		for questID in pairs(open) do
			CheckFailed(questID)
		end
	end)
end

--------------------------------------------------------------------------------
-- Kills (from "X dies, you gain N experience")
--------------------------------------------------------------------------------

-- Left open-ended so rested and group bonus variants match too.
local killPattern, killOrder
if type(COMBATLOG_XPGAIN_FIRSTPERSON) == "string" then
	killPattern, killOrder = ns.ToPattern(COMBATLOG_XPGAIN_FIRSTPERSON:gsub("%.$", ""), true)
end

ns.On("CHAT_MSG_COMBAT_XP_GAIN", function(text)
	text = ns.Clean(text)
	if not killPattern or not text then
		return
	end
	local name, xp = ns.MatchPattern(text, killPattern, killOrder)
	if not name then
		return
	end
	ns.Log("kill", { name = name, xp = tonumber(xp) })
	ns.Add(1, "kills")
	ns.Add(tonumber(xp) or 0, "experience", "kills")
end)

--------------------------------------------------------------------------------
-- Discoveries ("Discovered Goldshire: 30 experience gained")
--------------------------------------------------------------------------------

local discoveryPatterns = {}
for _, name in ipairs({ "ERR_ZONE_EXPLORED_XP", "ERR_ZONE_EXPLORED" }) do
	if type(_G[name]) == "string" then
		local pattern, order = ns.ToPattern(_G[name], true)
		discoveryPatterns[#discoveryPatterns + 1] = { pattern = pattern, order = order }
	end
end

local lastDiscovery

local function CheckDiscovery(text)
	text = ns.Clean(text)
	if type(text) ~= "string" then
		return
	end
	for _, p in ipairs(discoveryPatterns) do
		local place, xp = ns.MatchPattern(text, p.pattern, p.order)
		if place then
			-- The same message can arrive both as a UI message and in chat.
			if place ~= lastDiscovery or not ns.Recent("discovery", 5) then
				lastDiscovery = place
				ns.Mark("discovery")
				ns.Log("discover", { place = place, xp = tonumber(xp) })
				ns.Add(1, "discoveries")
				ns.Add(tonumber(xp) or 0, "experience", "discoveries")
			end
			return
		end
	end
end

ns.On("UI_INFO_MESSAGE", function(_, text)
	CheckDiscovery(text)
end)
ns.On("CHAT_MSG_SYSTEM", CheckDiscovery)
