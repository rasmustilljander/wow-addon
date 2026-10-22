-- Localized format strings can display numbered arguments in a different
-- order. Every parser must still return them in the format's argument order.
LOOT_ITEM_SELF_MULTIPLE = "You receive %2$d of %1$s."
COMBATLOG_XPGAIN_FIRSTPERSON = "You gain %2$d experience when %1$s dies."
ERR_ZONE_EXPLORED_XP = "For %2$d experience, discovered %1$s."
FACTION_STANDING_CHANGED = "With %2$s, you are now %1$s."
FACTION_STANDING_INCREASED = "For %2$d reputation, %1$s likes you more."
FACTION_STANDING_DECREASED = "For %2$d reputation, %1$s likes you less."
ERR_GUILD_PROMOTE_SSS = "%2$s is now %3$s, promoted by %1$s."
COMBATLOG_HONORGAIN = "For %3$d Honor, %1$s (%2$s) dies."

M.guild = { name = "Wanderers", rank = "Member", rankIndex = 3 }
local ns = M.Login()

local function last(kind)
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == kind then return log[i] end
	end
end
local function count(kind)
	local n = 0
	for _, e in ipairs(TravelLogCharDB.log) do
		if e.type == kind then n = n + 1 end
	end
	return n
end

M.fire("CHAT_MSG_LOOT", "You receive 3 of [Linen Cloth].")
local received = last("receive")
check(received.item == "[Linen Cloth]" and received.count == 3, "loot arguments reordered")

M.fire("CHAT_MSG_COMBAT_XP_GAIN", "You gain 45 experience when Kobold Worker dies.")
local kill = last("kill")
check(kill.name == "Kobold Worker" and kill.xp == 45, "XP arguments reordered")

M.fire("UI_INFO_MESSAGE", 0, "For 30 experience, discovered Jerod's Landing.")
M.fire("CHAT_MSG_SYSTEM", "For 30 experience, discovered Jerod's Landing.")
local discovery = last("discover")
check(count("discover") == 1 and discovery.place == "Jerod's Landing" and discovery.xp == 30,
	"discovery arguments reordered")

M.fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "With Stormwind, you are now Friendly.")
M.fire("CHAT_MSG_SYSTEM", "With Stormwind, you are now Friendly.")
local standing = last("standing")
check(count("standing") == 1 and standing.faction == "Stormwind" and standing.standing == "Friendly",
	"reputation standing arguments reordered")

M.fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "For 25 reputation, Stormwind likes you more.")
M.fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "For 10 reputation, Booty Bay likes you less.")
local reputation = ns.stats.reputation
check(reputation.Stormwind.gained == 25 and reputation["Booty Bay"].lost == 10,
	"reputation change arguments reordered")

M.chat("CHAT_MSG_SYSTEM", "Rasmus is now Officer, promoted by Ann.")
M.guild = { name = "Wanderers", rank = "Officer", rankIndex = 2 }
M.fire("PLAYER_GUILD_UPDATE", "player")
M.tick(3)
local guild = last("guildrank")
check(guild.rank == "Officer" and guild.change == "promoted" and guild.by == "Ann",
	"guild arguments reordered")

M.chat("CHAT_MSG_COMBAT_HONOR_GAIN", "For 45 Honor, Grok (Sergeant) dies.")
local honor = last("honorkill")
check(honor.name == "Grok" and honor.rank == "Sergeant" and honor.honor == 45,
	"honor arguments reordered")

-- The existing retreat format displays loser before winner; keep duel parsing
-- on the same shared path as the other localized messages.
M.fire("DUEL_REQUESTED", "Bob")
AcceptDuel()
M.fire("DUEL_FINISHED")
M.chat("CHAT_MSG_SYSTEM", "Rasmus has fled from Bob in a duel")
M.tick(3)
local duel = last("duel")
check(duel.opponent == "Bob" and duel.result == "lost" and duel.fled, "duel arguments reordered")
