-- Screenshots: every one is logged with the game's file name, and TravelLog
-- can take them itself on level-ups, boss kills and Legacy Challenges.
local _, ns = ...

ns.Defaults({
	screenshotLevel = true,
	screenshotBoss = true,
	screenshotFirstKill = true,
	screenshotAchievement = false,
})

-- An automatic shot waits this long, so the level-up glow, the kill or the
-- banner is in the picture, and none comes within GAP seconds of another.
local DELAY = { level = 1, boss = 0.5, achievement = 1 }
local GAP = 1

--------------------------------------------------------------------------------
-- Logging every screenshot
--------------------------------------------------------------------------------

-- The game names the file after the local time it was taken, as
-- WoWScrnShot_MMDDYY_HHMMSS plus the format's extension. SCREENSHOT_STARTED
-- fires just before the picture is taken, SCREENSHOT_SUCCEEDED once it's
-- saved.
local shotAt, shotAuto -- the picture being taken, and why if it's ours
local asked            -- the automatic one just asked for: { kind, what, at }
local lastShot         -- GetTime() of the last one started or asked for

ns.On("SCREENSHOT_STARTED", function()
	shotAt, lastShot = time(), GetTime()
	shotAuto = asked and GetTime() - asked.at <= 2 and asked or nil
	asked = nil
end)

ns.On("SCREENSHOT_FAILED", function()
	shotAt, shotAuto = nil, nil
end)

ns.On("SCREENSHOT_SUCCEEDED", function()
	local at, auto = shotAt or time(), shotAuto
	shotAt, shotAuto = nil, nil
	ns.Log("screenshot", {
		file = date("WoWScrnShot_%m%d%y_%H%M%S", at),
		auto = auto and auto.kind,
		what = auto and auto.what,
	})
	ns.Add(1, "screenshots")
end)

--------------------------------------------------------------------------------
-- Taking them on milestones
--------------------------------------------------------------------------------

-- Takes a screenshot after kind's delay, unless another came too close.
-- what says what it shows: the level, the boss or the challenge's name.
local function Shoot(kind, what)
	C_Timer.After(DELAY[kind], function()
		if not Screenshot or (lastShot and GetTime() - lastShot < GAP) then
			return
		end
		asked = { kind = kind, what = what, at = GetTime() }
		lastShot = GetTime()
		Screenshot()
	end)
end

ns.On("PLAYER_LEVEL_UP", function(level)
	level = ns.Clean(level)
	if ns.settings.screenshotLevel and level and level > 1 then
		Shoot("level", level)
	end
end)

-- Whether the log has a kill of encounter id before the one just logged
-- (Travel.lua logs it first). Without an ID it can't tell, so it says no.
local function KilledBefore(id)
	if not id then
		return false
	end
	local log, seen = ns.char.log, false
	for i = #log, 1, -1 do
		local e = log[i]
		if e.type == "boss" and e.result == "kill" and e.id == id then
			if seen then
				return true
			end
			seen = true
		end
	end
	return false
end

ns.On("ENCOUNTER_END", function(id, name, _, _, success)
	if not ns.settings.screenshotBoss or ns.Clean(success) ~= 1 then
		return
	end
	id, name = ns.Clean(id), ns.Clean(name)
	if not (ns.settings.screenshotFirstKill and KilledBefore(id)) then
		Shoot("boss", name ~= "" and name or nil)
	end
end)

ns.On("ACHIEVEMENT_EARNED", function(id)
	id = ns.Clean(id)
	if not (ns.settings.screenshotAchievement and id) then
		return
	end
	local name = GetAchievementInfo and ns.Clean(select(2, GetAchievementInfo(id)))
	Shoot("achievement", name ~= "" and name or nil)
end)

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

local SETTINGS = {
	level = "screenshotLevel", boss = "screenshotBoss",
	first = "screenshotFirstKill", achievement = "screenshotAchievement",
}

local function OnOff(key)
	return ns.settings[key] and "on" or "off"
end

ns.Command("screenshots", "screenshots [level|boss|first|achievement on|off] - automatic screenshots", function(arg)
	local which, state = arg:match("^(%a+)%s+(%a+)$")
	local key = SETTINGS[which]
	if key and (state == "on" or state == "off") then
		ns.settings[key] = state == "on"
	elseif arg ~= "" then
		return false
	end
	ns.Print("automatic screenshots: level-ups %s, boss kills %s (first kill of each boss only: %s), Legacy Challenges %s",
		OnOff("screenshotLevel"), OnOff("screenshotBoss"), OnOff("screenshotFirstKill"), OnOff("screenshotAchievement"))
end)

local function Setting(label, key, indent)
	ns.AddSetting("Screenshots", label, function()
		return ns.settings[key]
	end, function(on)
		ns.settings[key] = on
	end, nil, indent)
end
Setting("Take one on each level-up", "screenshotLevel")
Setting("Take one on boss kills", "screenshotBoss")
Setting("First kill of each boss only", "screenshotFirstKill", true)
Setting("Take one on Legacy Challenges earned", "screenshotAchievement")
