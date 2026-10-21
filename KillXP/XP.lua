-- KillXP: how much experience a kill gives, and how many kills to the next
-- level.
--
-- Forever gives Classic's kill XP for mobs of your own level, but bases the
-- value of lower-level mobs on the mob's level. Dungeon creatures use their
-- own reduced modifier. Every solo kill still teaches us the unbuffed value
-- for that player level, mob level and setting, in case the server changes.
local _, ns = ...

-- Forever runs on the Midnight-era client, which hands addons unreadable
-- "secret" values in some situations (unit names in dungeons, ...). We can't
-- use those, so treat them as missing.
local issecretvalue = issecretvalue
function ns.Clean(value)
	if value ~= nil and issecretvalue and issecretvalue(value) then
		return nil
	end
	return value
end

function ns.Print(text, ...)
	if select("#", ...) > 0 then
		text = text:format(...)
	end
	print("|cffffd200KillXP|r " .. text)
end

--------------------------------------------------------------------------------
-- The Forever formula
--------------------------------------------------------------------------------

local function Round(n)
	return math.floor(n + 0.5)
end

-- Mobs at or below this level are gray and give nothing.
function ns.GrayLevel(level)
	if level <= 5 then
		return 0
	elseif level <= 39 then
		return level - math.floor(level / 10) - 5
	elseif level <= 59 then
		return level - math.floor(level / 5) - 1
	end
	return level - 9
end

-- How many levels below you a mob's XP falls to zero ("zero difference").
local function ZeroDifference(level)
	if level < 8 then return 5
	elseif level < 10 then return 6
	elseif level < 12 then return 7
	elseif level < 16 then return 8
	elseif level < 20 then return 9
	elseif level < 30 then return 11
	elseif level < 40 then return 12
	elseif level < 45 then return 13
	elseif level < 50 then return 14
	elseif level < 55 then return 15
	elseif level < 60 then return 16
	end
	return 17
end

-- Forever's solo XP for a kill, without rested or temporary XP buffs. Mobs
-- more than 4 levels above you count as +4. Below your level, Forever uses the
-- mob's level for the base as well as the usual level-difference reduction.
-- Dungeon creatures currently give about 1.2x normal XP regardless of their
-- elite classification; outdoor elites give 2x.
function ns.ForeverXP(level, mobLevel, elite, dungeon)
	if mobLevel <= ns.GrayLevel(level) then
		return 0
	end
	local xp
	if mobLevel >= level then
		local base = level * 5 + 45
		local diff = math.min(mobLevel - level, 4)
		xp = Round(base * (20 + diff) / 20)
	else
		local base = mobLevel * 5 + 45
		local zd = ZeroDifference(level)
		xp = Round(base * (zd + mobLevel - level) / zd)
	end
	if dungeon then
		xp = Round(xp * 1.2)
	elseif elite then
		xp = xp * 2
	end
	return xp
end

--------------------------------------------------------------------------------
-- Forever XP buffs
--------------------------------------------------------------------------------

local WELL_FED_XP = 1243969 -- Well Fed XP Boost: 5% kill XP
local WELL_RESTED = 429959   -- Sleeping bag: 1% per stack, up to 3

local function PlayerAura(spellID)
	if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then
		return nil
	end
	return ns.Clean(C_UnitAuras.GetPlayerAuraBySpellID(spellID))
end

-- Active percentage bonus to kill XP. This is separate from the traditional
-- rested-XP pool returned by GetXPExhaustion().
function ns.XPBonus()
	local bonus = PlayerAura(WELL_FED_XP) and 5 or 0
	local sleeping = PlayerAura(WELL_RESTED)
	if sleeping then
		local stacks = ns.Clean(sleeping.applications) or 1
		if type(stacks) == "number" then
			bonus = bonus + math.min(math.max(stacks, 1), 3)
		end
	end
	return bonus
end

function ns.ApplyXPBonus(xp, bonus)
	return Round(xp * (100 + (bonus or 0)) / 100)
end

local function RemoveXPBonus(xp, bonus)
	return Round(xp * 100 / (100 + (bonus or 0)))
end

-- Party bonus by group size; raids get none.
local PARTY_BONUS = { 1, 1, 1.166, 1.3, 1.4 }

-- Your share of a party kill: the solo XP times the party bonus, split by
-- level. Nobody gets anything if the mob is gray to the highest member.
-- `levels` holds every member's level, yours included.
function ns.GroupShare(xp, level, mobLevel, levels, raid)
	local sum, highest = 0, 0
	for _, l in ipairs(levels) do
		sum, highest = sum + l, math.max(highest, l)
	end
	if #levels < 2 or sum == 0 then
		return xp
	end
	if mobLevel <= ns.GrayLevel(highest) then
		return 0
	end
	local bonus = not raid and PARTY_BONUS[#levels] or 1
	return math.floor(xp * bonus * level / sum)
end

-- Kills needed to gain `need` XP at `xp` per kill. Rested doubles a kill's XP
-- while the rested pool lasts, and each kill uses up as much rest as it
-- added.
function ns.KillsToLevel(need, xp, rested)
	if not xp or xp <= 0 or need <= 0 then
		return nil
	end
	rested = math.max(rested or 0, 0)
	local doubled = math.floor(rested / xp)
	if doubled * 2 * xp >= need then
		return math.ceil(need / (2 * xp))
	end
	need, rested = need - doubled * 2 * xp, rested - doubled * xp
	local kills = doubled
	if rested > 0 then
		kills, need = kills + 1, need - xp - rested
		if need <= 0 then
			return kills
		end
	end
	return kills + math.ceil(need / xp)
end

--------------------------------------------------------------------------------
-- Learning from real kills
--------------------------------------------------------------------------------

local function Key(level, mobLevel, elite, dungeon)
	return ("%d:%d%s%s"):format(level, mobLevel, elite and "e" or "", dungeon and "d" or "")
end

local function InDungeon()
	local inInstance, kind = IsInInstance()
	return inInstance and (kind == "party" or kind == "raid") or false
end
ns.InDungeon = InDungeon

-- Solo XP (before rested) for a kill: what we've seen it give, or the
-- Classic formula's guess. The second return is true for a guess.
function ns.SoloXP(level, mobLevel, elite, dungeon)
	local seen = KillXPDB and KillXPDB.seen[Key(level, mobLevel, elite, dungeon)]
	if seen then
		return seen, false
	end
	return ns.ForeverXP(level, mobLevel, elite, dungeon), true
end

-- Mobs we've looked at recently, by name, so a kill message ("Kobold
-- Vermin dies, you gain 40 experience.") can be matched to a level.
local mobs = {}
function ns.Remember(name, mobLevel, elite)
	name = ns.Clean(name)
	if name then
		mobs[name] = { level = mobLevel, elite = elite }
	end
end

local ELITE = { elite = true, rareelite = true, worldboss = true }
function ns.IsElite(unit)
	return ELITE[ns.Clean(UnitClassification(unit)) or ""] or false
end

function ns.RememberUnit(unit)
	local mobLevel = ns.Clean(UnitLevel(unit))
	if mobLevel and mobLevel > 0 then
		ns.Remember(UnitName(unit), mobLevel, ns.IsElite(unit))
	end
end

-- Turns a localized format like "%s dies, you gain %d experience." into a
-- Lua pattern.
local function ToPattern(format)
	local pattern = format:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
	pattern = pattern:gsub("%%%%%d%%%$s", "(.-)"):gsub("%%%%%d%%%$d", "(%%d+)")
	pattern = pattern:gsub("%%%%s", "(.-)"):gsub("%%%%d", "(%%d+)")
	return "^" .. pattern .. "$"
end

-- "X dies, you gain 80 experience. (+40 exp Rested bonus)": the rested part
-- is included in the 80.
local killPattern = type(COMBATLOG_XPGAIN_FIRSTPERSON) == "string" and ToPattern(COMBATLOG_XPGAIN_FIRSTPERSON)
local restedPattern = type(COMBATLOG_XPGAIN_EXHAUSTION1) == "string" and ToPattern(COMBATLOG_XPGAIN_EXHAUSTION1)

-- Returns the mob's name and the XP the kill gave without rested, or nil
-- for anything that isn't a plain or rested solo kill.
function ns.ParseKill(text)
	if restedPattern then
		local name, xp, bonus = text:match(restedPattern)
		bonus = bonus and tonumber((bonus:gsub("^%+", "")))
		if name and bonus then
			return name, tonumber(xp) - bonus
		end
	end
	if killPattern then
		local name, xp = text:match(killPattern)
		if name then
			return name, tonumber(xp)
		end
	end
end

local frame = CreateFrame("Frame")

local function OnKill(text)
	text = ns.Clean(text)
	-- In a group the kill is split and boosted, so it says nothing certain
	-- about the solo value.
	if not text or GetNumGroupMembers() > 0 then
		return
	end
	local name, xp = ns.ParseKill(text)
	if not name or not xp or xp <= 0 then
		return
	end
	-- Mobs often share a name across levels, so the corpse you have
	-- targeted beats the last one by that name you looked at.
	if UnitIsDead("target") and ns.Clean(UnitName("target")) == name then
		ns.RememberUnit("target")
	end
	local mob = mobs[name]
	if not mob then
		return
	end
	-- Save an unbuffed value so food or sleeping-bag buffs can come and go
	-- without making the learned number stale.
	KillXPDB.seen[Key(UnitLevel("player"), mob.level, mob.elite, InDungeon())] = RemoveXPBonus(xp, ns.XPBonus())
end

frame:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" and arg == "KillXP" then
		KillXPDB = KillXPDB or {}
		-- Version 1 learned the buffed result, without remembering which buffs
		-- were active. Those values cannot be normalized safely.
		if KillXPDB.version ~= 2 then
			KillXPDB.seen = {}
		end
		KillXPDB.version = 2
		KillXPDB.seen = KillXPDB.seen or {}
	elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
		OnKill(arg)
	elseif event == "PLAYER_TARGET_CHANGED" then
		ns.RememberUnit("target")
	end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")

SLASH_KILLXP1 = "/killxp"
SlashCmdList.KILLXP = function(msg)
	if msg:match("^%s*reset%s*$") then
		wipe(KillXPDB.seen)
		ns.Print("Forgot the XP seen from kills; back to estimates.")
	else
		local n = 0
		for _ in pairs(KillXPDB.seen) do
			n = n + 1
		end
		ns.Print("Knows the real XP for %d mob level%s. |cffffffff/killxp reset|r forgets them.", n, n == 1 and "" or "s")
	end
end
