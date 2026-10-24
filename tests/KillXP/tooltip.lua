-- KillXP: the tooltip's XP and kills-to-level lines, rested and party
-- bonuses, learning the real XP from kills, and its data version.
M.installed = { "KillXP" }
M.level, M.xp, M.xpMax = 10, 7000, 7600   -- 600 XP to level 11
local ns = M.Login()
check(KillXPDB.version == 1 and ns.DATA_VERSION == 1 and next(KillXPDB.seen) == nil, "a new file gets data version 1")

local function Line(lines, label)
	for _, line in ipairs(lines) do
		if line:find("^" .. label .. "  ") then
			return line:sub(#label + 3)
		end
	end
end

local function Mob(level, extra)
	local u = { name = "Kobold Vermin", guid = "Creature-0-1-2-3-6-1", hostile = true, level = level }
	for k, v in pairs(extra or {}) do u[k] = v end
	M.units.mouseover = u
	return M.hover("mouseover")
end

-- The Forever formula: lower-level mobs use the mob's level for their base;
-- dungeon creatures get the current 20% modifier instead of elite XP.
check(ns.ForeverXP(10, 10) == 95, "even level")
check(ns.ForeverXP(10, 12) == 105, "two levels above")
check(ns.ForeverXP(10, 20) == ns.ForeverXP(10, 14), "more than 4 levels above counts as +4")
check(ns.ForeverXP(10, 8) == 61, "two levels below")
check(ns.ForeverXP(16, 15) == 107 and ns.ForeverXP(16, 11) == 44, "Forever lower-level formula and rounding")
check(ns.ForeverXP(10, 4) == 0, "gray")
check(ns.ForeverXP(10, 10, true) == 190 and ns.ForeverXP(10, 10, true, true) == 114, "outdoor elite and dungeon creature")
check(ns.GroupShare(ns.ForeverXP(20, 20, true, true), 20, 20, { 20, 20, 20, 20, 20 }, false) == 48,
	"level 20 five-player dungeon share")
check(ns.GrayLevel(5) == 0 and ns.GrayLevel(25) == 18 and ns.GrayLevel(50) == 39 and ns.GrayLevel(60) == 51, "gray levels")

-- Kills to level with rested: two doubled kills, one partly rested, then plain.
check(ns.KillsToLevel(600, 95, 0) == 7, "no rest")
check(ns.KillsToLevel(600, 95, 200) == 5, "partly rested")
check(ns.KillsToLevel(600, 95, 10000) == 4, "fully rested")
check(ns.KillsToLevel(600, 0, 0) == nil, "no XP, no count")

-- Solo, not rested: an estimate, so marked with ~.
local lines = Mob(10)
check(Line(lines, "Kill XP") == "~95", "solo estimate: " .. tostring(Line(lines, "Kill XP")))
check(Line(lines, "Kills to level") == "~7", "kills to level")

-- Rested.
M.rested = 200
lines = Mob(10)
check(Line(lines, "Kill XP") == "~190 (+95 rested)", "rested: " .. tostring(Line(lines, "Kill XP")))
check(Line(lines, "Kills to level") == "~5", "rested kills: " .. tostring(Line(lines, "Kills to level")))
M.rested = nil

-- Forever's percentage buffs are separate from the rested-XP pool and stack.
M.auras[1243969] = { spellId = 1243969, applications = 1 }
check(Line(Mob(10), "Kill XP") == "~100 (+5% XP buffs)", "food XP buff")
M.auras[429959] = { spellId = 429959, applications = 3 }
check(Line(Mob(10), "Kill XP") == "~103 (+8% XP buffs)", "food and sleeping-bag XP buffs")
M.auras = {}

-- Elite and dungeon elite.
check(Line(Mob(10, { classification = "elite" }), "Kill XP") == "~190", "elite")
M.instance = "party"
check(Line(Mob(10, { classification = "rareelite" }), "Kill XP") == "~114", "dungeon creature")
M.instance = nil

-- Mobs that give nothing.
check(Line(Mob(4, { trivial = true }), "Kill XP") == "none (too low)", "gray mob")
check(Line(Mob(4), "Kill XP") == "none (too low)", "gray by formula")
check(Line(Mob(10, { tapped = true }), "Kill XP") == "none (tapped by others)", "tapped")
check(Line(Mob(-1), "Kill XP") == "unknown (level ??)", "skull level")
check(Line(Mob(-1), "Kills to level") == nil, "no kill count for ??")
check(#Mob(10, { hostile = false }) == 1, "friendly NPC: no lines")
check(#Mob(10, { player = true }) == 1, "enemy player: no lines")
check(#Mob(10, { pet = true }) == 1, "enemy pet: no lines")
check(#Mob(10, { dead = true }) == 1, "corpse: no lines")
M.level = 60
check(#Mob(60) == 1, "max level: no lines")
M.level = 10
M.xpDisabled = true
check(#Mob(10) == 1, "XP turned off: no lines")
M.xpDisabled = false

-- A party of three (levels 10, 10, 12): the 1.166 bonus, split by level.
M.units.party1 = { name = "Anna", level = 10, player = true }
M.units.party2 = { name = "Bo", level = 12, player = true }
M.group = { "party1", "party2" }
lines = Mob(10)
check(Line(lines, "Kill XP") == "~34 (3 in group, ~95 solo)", "party: " .. tostring(Line(lines, "Kill XP")))
check(Line(lines, "Kills to level") == "~18", "party kills: " .. tostring(Line(lines, "Kills to level")))
M.rested = 1000
check(Line(Mob(10), "Kill XP") == "~68 (+34 rested, 3 in group, ~95 solo)", "party, rested")
M.rested = nil
M.auras[1243969] = { spellId = 1243969, applications = 1 }
M.auras[429959] = { spellId = 429959, applications = 3 }
M.rested = 1000
check(Line(Mob(10), "Kill XP") == "~74 (+37 rested, +8% XP buffs, 3 in group, ~103 solo)", "party, Forever XP buffs")
M.auras = {}
M.rested = nil
-- A much higher member makes the mob gray for everyone.
M.units.party2.level = 30
check(Line(Mob(10), "Kill XP") == "none (too low for your group)", "high-level party member")
-- Party kills don't teach the solo value.
Mob(8)
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Vermin dies, you gain 40 experience. (+5 group bonus)")
check(next(KillXPDB.seen) == nil, "party kill not learned")
M.group = {}

-- Solo kills teach the real value (Forever gives less than Classic below
-- your level), which then replaces the estimate.
check(Line(Mob(8), "Kill XP") == "~61", "estimate before the kill")
-- Learning removes active percentage buffs before saving the value.
M.auras[1243969] = { spellId = 1243969, applications = 1 }
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Vermin dies, you gain 63 experience.")
M.auras = {}
lines = Mob(8)
check(Line(lines, "Kill XP") == "60", "learned: " .. tostring(Line(lines, "Kill XP")))
check(Line(lines, "Kills to level") == "10", "learned kills to level")
M.auras[1243969] = { spellId = 1243969, applications = 1 }
check(Line(Mob(8), "Kill XP") == "63 (+5% XP buffs)", "buff applied to learned value")
M.auras = {}
-- The rested bonus is taken out of what's learned.
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Vermin dies, you gain 116 experience. (+58 exp Rested bonus)")
check(Line(Mob(8), "Kill XP") == "58", "learned from a rested kill")
-- Only for that mob level and your level.
check(Line(Mob(9), "Kill XP"):sub(1, 1) == "~", "other mob levels still estimated")
-- A mob targeted rather than hovered is matched too.
M.units.target = { name = "Kobold Worker", hostile = true, level = 9 }
M.fire("PLAYER_TARGET_CHANGED")
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Worker dies, you gain 70 experience.")
check(Line(Mob(9), "Kill XP") == "70", "learned from a targeted mob")
-- A kill of a mob we never saw teaches nothing.
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Stranger dies, you gain 999 experience.")
check(Line(Mob(10), "Kill XP") == "~95", "unknown mob not learned")
-- A same-named mob seen long before the kill is no longer a safe match.
ns.Remember("Old Wolf", 6, false)
M.advance(61)
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Old Wolf dies, you gain 999 experience.")
local _, guessed = ns.SoloXP(10, 6, false, false)
check(guessed, "stale mob observation not learned")
-- The same name at another level: the targeted corpse decides which level
-- the kill was.
Mob(8)
M.units.target = { name = "Kobold Vermin", hostile = true, level = 7, dead = true }
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Vermin dies, you gain 50 experience.")
check(Line(Mob(7), "Kill XP") == "50", "learned for the targeted corpse's level")
check(Line(Mob(8), "Kill XP") == "58", "not for the level last hovered")
M.units.target = nil
-- Secret names and messages (in dungeons) are ignored rather than erroring.
local secretText = "Kobold Vermin dies, you gain 1 experience."
M.secrets["Kobold Vermin"], M.secrets[secretText] = true, true
check(#Mob(6) == 3, "secret name: lines still shown")
M.fire("CHAT_MSG_COMBAT_XP_GAIN", secretText)
check(Line(Mob(6), "Kill XP"):sub(1, 1) == "~", "secret message: nothing learned")
M.secrets = {}

-- What's learned survives a reload, and /killxp reset forgets it.
M.Reload()
check(Line(Mob(8), "Kill XP") == "58", "learned value kept over a reload")
check(#M.tooltipPostCalls[Enum.TooltipDataType.Unit] == 1, "tooltip hook not stacked by reload")
SlashCmdList.KILLXP("")
check(M.out[#M.out]:find("3 mob levels"), "status: " .. M.out[#M.out])
SlashCmdList.KILLXP("reset")
check(Line(Mob(8), "Kill XP") == "~61", "reset back to estimates")

-- A rested kill whose line leaves the bonus out (said to happen on Forever)
-- teaches nothing: not while the pool is above 0, nor when the pool ran out
-- just before the line or just after the last time it was read.
M.rested = 300
M.fire("UPDATE_EXHAUSTION")
Mob(8)
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Vermin dies, you gain 122 experience.")
check(KillXPDB.seen["10:8"] == nil, "rested kill without the bonus in the line")
M.rested = nil
M.fire("UPDATE_EXHAUSTION")
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Vermin dies, you gain 100 experience.")
check(KillXPDB.seen["10:8"] == nil, "pool ran out just before the line")
M.advance(3)
M.rested = 40
M.fire("UPDATE_EXHAUSTION")
M.rested = nil
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Vermin dies, you gain 81 experience.")
check(KillXPDB.seen["10:8"] == nil, "pool ran out with no event before the line")
-- An unreadable pool might be rested too.
M.advance(3)
M.secrets[77] = true
M.rested = 77
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Vermin dies, you gain 61 experience.")
check(KillXPDB.seen["10:8"] == nil, "unreadable pool")
M.secrets, M.rested = {}, nil
-- With no rest left a plain kill teaches again, and a line with the bonus
-- in it does while rested.
M.advance(3)
M.fire("UPDATE_EXHAUSTION")
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Vermin dies, you gain 61 experience.")
check(KillXPDB.seen["10:8"] == 61, "plain kill learned: " .. tostring(KillXPDB.seen["10:8"]))
M.rested = 300
M.fire("UPDATE_EXHAUSTION")
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Vermin dies, you gain 124 experience. (+62 exp Rested bonus)")
check(KillXPDB.seen["10:8"] == 62, "rested line still learned: " .. tostring(KillXPDB.seen["10:8"]))
M.rested = nil
SlashCmdList.KILLXP("reset")

-- Bigger numbers get thousands separators.
M.level, M.xp, M.xpMax = 55, 0, 300000
check(Line(Mob(55, { classification = "elite" }), "Kill XP") == "~640", "level 55 elite")
check(Line(Mob(55, { classification = "elite" }), "Kills to level") == "~469", "kills at 55")
M.xpMax = 3000000
check(Line(Mob(55, { classification = "elite" }), "Kills to level") == "~4,688", "thousands separator")

-- Saved data of a data version this KillXP doesn't know (a newer one's)
-- isn't read: tooltips show estimates, nothing is learned, the file is kept.
M.Logout()
M.saved.KillXP = 'KillXPDB = { ["version"] = 2, ["seen"] = { ["55:55e"] = 999 } }\n'
M.out = {}
ns = M.Login()
check(M.out[#M.out] and M.out[#M.out]:find("data version 2"), "a newer data version isn't read, and chat says so")
check(Line(Mob(55, { classification = "elite" }), "Kill XP") == "~640", "estimates only")
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Vermin dies, you gain 700 experience.")
check(KillXPDB.seen["55:55e"] == 999 and Line(Mob(55, { classification = "elite" }), "Kill XP") == "~640", "nothing learned")
SlashCmdList.KILLXP("reset")
check(M.out[#M.out]:find("data version 2") and KillXPDB.seen["55:55e"] == 999, "/killxp says why and resets nothing")
M.Logout()
check(M.saved.KillXP:find('%["version"%] = 2') and M.saved.KillXP:find("999"), "the file is saved back as it was")
