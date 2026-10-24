-- Screenshots: the file name from the time the picture was taken, where you
-- were, a failed one, totals, the window, /tl log and a reload. Automatic
-- ones on level-ups, boss kills (first kills only, or all) and Legacy
-- Challenges: the wait, the 1 s gap, a failed one, /tl screenshots, the
-- Settings tab, a reload.
local ns = M.Login()

local function count(kind)
	local n = 0
	for _, e in ipairs(TravelLogCharDB.log) do if e.type == kind then n = n + 1 end end
	return n
end
local function last()
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == "screenshot" then return log[i] end
	end
end

-- Saved a second after it was taken: named after when it was taken.
M.zone, M.subzone, M.x, M.y = "Elwynn Forest", "Goldshire", 0.42, 0.65
local taken = M.now
M.fire("SCREENSHOT_STARTED")
M.tick(1)
M.fire("SCREENSHOT_SUCCEEDED")
local e = last()
local file = date("WoWScrnShot_%m%d%y_%H%M%S", taken)
check(count("screenshot") == 1 and e.file == file, "file name: " .. tostring(e.file))
check(e.zone == "Elwynn Forest" and e.subzone == "Goldshire" and e.x == 42 and e.y == 65, "where it was taken")
check(ns.Describe(e) == "Screenshot " .. file, "described: " .. ns.Describe(e))

-- A failed one isn't logged and doesn't name the next.
M.tick(5)
M.fire("SCREENSHOT_STARTED")
M.fire("SCREENSHOT_FAILED")
M.tick(5)
M.fire("SCREENSHOT_SUCCEEDED")
check(count("screenshot") == 2 and last().file == date("WoWScrnShot_%m%d%y_%H%M%S", M.now), "failed one skipped")

check(ns.stats.screenshots == 2, "counted")
check(ns.LogGroup(e) == "Travel" and ns.LogTypeLabel(e) == "Screenshot", "under Travel")
M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("screenshots %d+") end
check(line == "screenshots 2", "stats line: " .. tostring(line))
M.out = {}
SlashCmdList.TRAVELLOG("log 5 wowscrnshot")
check(#M.out == 3 and M.out[2]:find("Screenshot " .. file, 1, true), "/tl log finds the file name")

SlashCmdList.TRAVELLOG("")
local values = {}
for _, fs in ipairs(M.descendants(TravelLogFrame.pages[1])) do values[#values + 1] = fs.text end
check(table.concat(values, "\n"):find("Screenshots\n2", 1, true), "Screenshots row")

local second = last().file
ns = M.Reload()
check(count("screenshot") == 2 and last().file == second and ns.stats.screenshots == 2, "kept after a reload")

-- Automatic screenshots: level-ups and first boss kills by default.
check(ns.settings.screenshotLevel and ns.settings.screenshotBoss and ns.settings.screenshotFirstKill
	and not ns.settings.screenshotAchievement, "defaults")
local shots = M.screenshots

-- A level-up waits a second for the glow, then takes one, logged as usual.
M.tick(5)
M.fire("PLAYER_LEVEL_UP", 12)
check(M.screenshots == shots, "not at once")
M.tick(1)
check(M.screenshots == shots + 1, "taken after a second")
taken = M.now
M.tick(1)
e = last()
check(count("screenshot") == 3 and e.auto == "level" and e.what == 12
	and e.file == date("WoWScrnShot_%m%d%y_%H%M%S", taken), "level-up shot logged")
check(ns.Describe(e) == "Screenshot (level 12) " .. e.file, "described: " .. ns.Describe(e))
check(ns.stats.screenshots == 3, "counted")

-- Not for level 1.
M.fire("PLAYER_LEVEL_UP", 1)
M.tick(3)
check(M.screenshots == shots + 1, "no shot at level 1")

-- Boss kills: the first of each boss only, not wipes.
M.instance, M.instanceInfo = "party", { name = "The Deadmines", difficultyName = "Normal", maxPlayers = 5, instanceID = 36 }
M.zone, M.subzone, M.x = "The Deadmines", "", nil
M.fire("PLAYER_ENTERING_WORLD", false, false)
M.fire("ENCOUNTER_END", 2972, "Edwin VanCleef", 1, 5, 0)
M.tick(3)
check(M.screenshots == shots + 1, "no shot on a wipe")
M.fire("ENCOUNTER_END", 2972, "Edwin VanCleef", 1, 5, 1)
M.tick(2)
e = last()
check(M.screenshots == shots + 2 and e.auto == "boss" and e.what == "Edwin VanCleef", "first kill shot")
check(ns.Describe(e) == "Screenshot (Edwin VanCleef) " .. e.file, "described: " .. ns.Describe(e))
M.fire("ENCOUNTER_END", 2972, "Edwin VanCleef", 1, 5, 1)
M.tick(3)
check(M.screenshots == shots + 2, "no shot on a second kill")
M.secrets["Secret Boss"] = true
M.fire("ENCOUNTER_END", 2973, "Secret Boss", 1, 5, 1)
M.tick(2)
e = last()
check(M.screenshots == shots + 3 and e.auto == "boss" and e.what == nil
	and ns.Describe(e) == "Screenshot (boss kill) " .. e.file, "a secret boss name: " .. ns.Describe(e))

-- Every kill with first kills only turned off.
M.out = {}
SlashCmdList.TRAVELLOG("screenshots first off")
check(ns.settings.screenshotFirstKill == false, "first kills only off")
check(M.out[1] and M.out[1]:find("automatic screenshots: level-ups on, boss kills on (first kill of each boss only: off), Legacy Challenges off", 1, true),
	"/tl screenshots says: " .. tostring(M.out[1]))
M.fire("ENCOUNTER_END", 2972, "Edwin VanCleef", 1, 5, 1)
M.tick(2)
check(M.screenshots == shots + 4, "a repeat kill shot")
SlashCmdList.TRAVELLOG("screenshots boss off")
M.fire("ENCOUNTER_END", 2974, "Mr. Smite", 1, 5, 1)
M.tick(3)
check(ns.settings.screenshotBoss == false and M.screenshots == shots + 4, "boss shots off")

-- Legacy Challenges: off by default, then on.
M.achievements = { [6] = { name = "Level 10", points = 10 } }
M.fire("ACHIEVEMENT_EARNED", 6, false)
M.tick(3)
check(M.screenshots == shots + 4, "no challenge shot by default")
SlashCmdList.TRAVELLOG("screenshots achievement on")
M.fire("ACHIEVEMENT_EARNED", 6, false)
M.tick(2)
e = last()
check(M.screenshots == shots + 5 and e.auto == "achievement" and e.what == "Level 10"
	and ns.Describe(e) == "Screenshot (Level 10) " .. e.file, "challenge shot: " .. ns.Describe(e))

-- A level-up and a challenge together give one picture, not two.
M.fire("PLAYER_LEVEL_UP", 13)
M.fire("ACHIEVEMENT_EARNED", 6, false)
M.tick(3)
check(M.screenshots == shots + 6 and last().auto == "level", "one shot for two milestones")

-- A failed one isn't logged, and a manual one after it isn't marked as ours.
local before = count("screenshot")
M.screenshotFails = true
M.fire("PLAYER_LEVEL_UP", 14)
M.tick(3)
M.screenshotFails = nil
check(M.screenshots == shots + 7 and count("screenshot") == before, "failed auto shot not logged")
M.fire("SCREENSHOT_STARTED")
M.tick(1)
M.fire("SCREENSHOT_SUCCEEDED")
check(count("screenshot") == before + 1 and not last().auto, "manual shot after it")

-- Bad arguments show the help.
M.out = {}
SlashCmdList.TRAVELLOG("screenshots level maybe")
local help
for _, text in ipairs(M.out) do help = help or text:find("/tl screenshots [level|boss|first|achievement on|off]", 1, true) end
check(help and ns.settings.screenshotLevel, "help on a bad argument")

-- The Settings tab's checkboxes, "first kill only" indented under boss kills.
SlashCmdList.TRAVELLOG("")
TravelLogFrame.Tabs[2]:Click()
local function Check(text)
	for _, r in ipairs(M.descendants(TravelLogFrame.pages[2])) do
		if r.kind == "CheckButton" and r.Text:GetText() == text then return r end
	end
end
local level, boss = Check("Take one on each level-up"), Check("Take one on boss kills")
local first, challenge = Check("First kill of each boss only"), Check("Take one on Legacy Challenges earned")
check(level and boss and first and challenge, "four checkboxes")
check(level:GetChecked() and not boss:GetChecked() and not first:GetChecked() and challenge:GetChecked(), "show the settings")
check(first.point[2] > boss.point[2], "first kill only indented")
level:Click()
boss:Click()
check(ns.settings.screenshotLevel == false and ns.settings.screenshotBoss == true, "checkboxes change them")
M.fire("PLAYER_LEVEL_UP", 15)
M.tick(3)
check(M.screenshots == shots + 7, "level shots off")

-- Settings and what triggered each shot survive a reload.
ns = M.Reload()
check(ns.settings.screenshotLevel == false and ns.settings.screenshotBoss == true and ns.settings.screenshotFirstKill == false
	and ns.settings.screenshotAchievement == true, "settings kept")
local autos = {}
for _, entry in ipairs(TravelLogCharDB.log) do
	if entry.type == "screenshot" and entry.auto then autos[#autos + 1] = entry.auto .. ":" .. tostring(entry.what) end
end
check(table.concat(autos, ",") == "level:12,boss:Edwin VanCleef,boss:nil,boss:Edwin VanCleef,achievement:Level 10,level:13",
	"auto shots kept: " .. table.concat(autos, ","))
M.fire("ENCOUNTER_END", 2975, "Captain Greenskin", 1, 5, 1)
M.tick(2)
check(M.screenshots == shots + 8 and last().auto == "boss", "shots after a reload")
