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

-- What killed you, when it wasn't (only) a mob: drowning and fatigue from
-- the breath and fatigue bars, falling from a long fall just before. There's
-- no combat log for addons, so lava, fire and slime can't be told.

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

ns.On("PLAYER_DEAD", function()
	state = "dead"
	local target
	if UnitExists("target") and UnitCanAttack("player", "target") then
		target = ns.Clean(UnitName("target"))
	end
	local cause = Cause()
	ns.Log("death", { target = target, level = UnitLevel("player"), cause = cause })
	ns.Add(1, "deaths")
	if cause then
		ns.Add(1, "deathCauses", cause)
	end
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
local asking -- /played was asked at login and hasn't answered yet
local PLAYED_WAIT = 10 -- seconds to wait for the answer

-- Each level-up also saves your max health and power, base stats and item
-- level once they can be read, and says in chat what the level gave.
ns.Defaults({ levelChat = true })

local STATS = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }
local POWER = { MANA = "mana", RAGE = "rage", ENERGY = "energy", FOCUS = "focus" }
local RETRY, TRIES = 1, 5 -- seconds between tries to read the stats, and how many
local pending -- the last level-up, until it's said in chat: { entry, before, at, tries, waiting, filled }
local FillLevel, FinishLevel, RetryLevel

-- Your max health and power, power type, base stats and the average item
-- level of worn gear, or nothing while any but the item level is unreadable.
local function Snapshot()
	local s = { hp = ns.Clean(UnitHealthMax("player")), power = ns.Clean(UnitPowerMax("player")), stats = {} }
	if type(s.hp) ~= "number" or type(s.power) ~= "number" then return end
	s.powerType = ns.Clean((select(2, UnitPowerType("player"))))
	for i = 1, #STATS do
		local base = ns.Clean((UnitStat("player", i)))
		if type(base) ~= "number" then return end
		s.stats[i] = base
	end
	local ilvl = GetAverageItemLevel and ns.Clean((select(2, GetAverageItemLevel())))
	s.ilvl = type(ilvl) == "number" and ilvl > 0 and ns.Round(ilvl, 1) or nil
	return s
end

-- The level-up entry before e with a snapshot, if it's for the level before.
local function Previous(e)
	local log = ns.char.log
	for i = #log, 1, -1 do
		local o = log[i]
		if o ~= e and o.type == "level" and o.hp then
			return o.level == e.level - 1 and o or nil
		end
	end
end

-- "+18 health, +15 mana, +1 Strength": what a level-up gave, or nothing.
function ns.LevelGains(e)
	local g = e.gain
	if not g then return end
	local list = {}
	local function Add(n, what)
		if n and n ~= 0 then list[#list + 1] = ("%+d %s"):format(n, what) end
	end
	Add(g.hp, "health")
	Add(g.power, POWER[e.powerType] or e.powerType and e.powerType:lower() or "power")
	for i, name in ipairs(STATS) do
		Add(g.stats and g.stats[i], name)
	end
	return #list > 0 and table.concat(list, ", ") or nil
end

-- "Level 12 in 1h 23m played (2d 4h total). +18 health, +1 Strength."
local function LevelLine(e)
	local text = "Level " .. e.level
	if e.took then
		text = ("%s in %s played"):format(text, ns.Duration(e.took))
		if e.played then text = ("%s (%s total)"):format(text, ns.Duration(e.played)) end
	elseif e.played then
		text = ("%s (%s played)"):format(text, ns.Duration(e.played))
	end
	local gains = ns.LevelGains(e)
	return gains and ("%s. %s."):format(text, gains) or text .. "."
end

function FinishLevel()
	local p = pending
	pending = nil
	if p and ns.settings.levelChat then
		ns.Print(LevelLine(p.entry))
	end
end

-- Saves the snapshot on the entry once it can be read and has caught up with
-- the level-up (or after TRIES tries), then says the line in chat once
-- /played has answered too.
function FillLevel()
	local p = pending
	if not p then return end
	local e = p.entry
	if not p.filled then
		if p.waiting or InCombatLockdown() then return end -- the retry or PLAYER_REGEN_ENABLED tries again
		local s = Snapshot()
		local stale = s and p.before and e.gain and e.gain.hp > 0 and s.hp == p.before.hp
		if (not s or stale) and p.tries < TRIES then
			return RetryLevel()
		end
		p.filled = true
		if s then
			e.hp, e.power, e.powerType, e.stats, e.ilvl = s.hp, s.power, s.powerType, s.stats, s.ilvl
			-- Without the client's numbers, the gains are the change since the
			-- level before.
			local o = not e.gain and Previous(e)
			if o then
				local g = { hp = s.hp - o.hp, stats = {} }
				g.power = o.powerType == s.powerType and s.power - o.power or nil
				for i = 1, #STATS do
					g.stats[i] = s.stats[i] - (o.stats and o.stats[i] or s.stats[i])
				end
				e.gain = g
			end
			ns.version = ns.version + 1
		end
	end
	if not e.played and asking then return end -- the answer or its timeout tries again
	FinishLevel()
end

function RetryLevel()
	local p = pending
	p.tries, p.waiting = p.tries + 1, true
	C_Timer.After(RETRY, function()
		p.waiting = nil
		if pending == p then FillLevel() end
	end)
end

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
	asking = true
	C_Timer.After(PLAYED_WAIT, function() -- in case no answer comes
		Unmute()
		asking = false
		FillLevel()
	end)
end)

ns.On("TIME_PLAYED_MSG", function(total, level)
	C_Timer.After(0, Unmute)
	asking = false
	total, level = ns.Clean(total), ns.Clean(level)
	if total and level then
		played = { total = total, level = level, at = GetTime() }
		-- A level-up before the answer gets its total played, but not how long
		-- the level took.
		local e = pending and pending.entry
		if e and not e.played then
			e.played = total - math.floor(GetTime() - pending.at)
		end
	end
	FillLevel()
end)

ns.On("PLAYER_LEVEL_UP", function(level, health, power, _, _, ...)
	FinishLevel() -- one still waiting goes without the rest of its snapshot
	level = ns.Clean(level) or UnitLevel("player")
	ns.profile.level = level
	local total, took = ns.Played()
	local e = ns.Log("level", { level = level, played = total, took = took,
		powerType = ns.Clean((select(2, UnitPowerType("player")))) })
	if total then
		played = { total = total, level = 0, at = GetTime() }
	end
	-- What the level gave, when the client says: health, power and each stat.
	local gain, known = { hp = ns.Clean(health), power = ns.Clean(power), stats = {} }, 0
	for i = 1, #STATS do
		local n = ns.Clean((select(i, ...)))
		if type(n) == "number" then
			gain.stats[i], known = n, known + 1
		end
	end
	if type(gain.hp) == "number" and type(gain.power) == "number" and known == #STATS then
		e.gain = gain
	end
	-- The stats can still be the old ones during the event, so they're read
	-- a little later.
	pending = { entry = e, before = Snapshot(), at = GetTime(), tries = 0 }
	RetryLevel()
end)

-- Stats can't be read in combat.
ns.On("PLAYER_REGEN_ENABLED", function()
	FillLevel()
end)

ns.On("PLAYER_LOGIN", function()
	ns.AddSetting("General", "Say in chat what each level-up gave", function()
		return ns.settings.levelChat
	end, function(on)
		ns.settings.levelChat = on
	end)
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
