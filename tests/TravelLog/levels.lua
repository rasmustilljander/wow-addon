-- Level-ups: max health and power, base stats and item level saved on the
-- entry, the gains from the event (or since the level before when it hides
-- them), stats catching up late, combat, /played answering late or never,
-- the chat line and its setting, /tl log, a reload.
local ns = M.Login()
M.tick(1)

local function last(kind)
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == kind then return log[i] end
	end
end
local function Said(text)
	for _, line in ipairs(M.out) do
		if line:find(text, 1, true) then return line end
	end
end
local function Lines(text)
	local n = 0
	for _, line in ipairs(M.out) do
		if line:find(text, 1, true) then n = n + 1 end
	end
	return n
end
local function Stats(e) return e.stats and table.concat(e.stats, ",") or "none" end

-- A level-up: the gains from the event, the snapshot a second later, then
-- the line in chat.
M.out = {}
M.itemLevel = 12.34
M.levelUp({ hp = 18, power = 15, str = 1, sta = 2 })
M.playedLevel = 0
local e = last("level")
check(e.level == 6 and e.gain and e.gain.hp == 18 and e.gain.power == 15 and table.concat(e.gain.stats, ",") == "1,0,2,0,0",
	"gains from the event")
check(e.hp == nil and not Said("Level 6"), "snapshot and line wait a moment")
M.tick(1)
check(e.hp == 168 and e.power == 275 and e.powerType == "MANA" and Stats(e) == "21,21,24,30,28" and e.ilvl == 12.3,
	"snapshot: " .. tostring(e.hp) .. ", " .. tostring(e.power) .. ", " .. Stats(e) .. ", " .. tostring(e.ilvl))
local line = Said("Level 6")
check(line == "|cff4fc3f7TravelLog|r Level 6 in 1h 0m played (1d 1h total). +18 health, +15 mana, +1 Strength, +2 Stamina.",
	"chat line: " .. tostring(line))
check(ns.Describe(e) == "Reached level 6 after 1h 0m at level 5: +18 health, +15 mana, +1 Strength, +2 Stamina",
	"described: " .. ns.Describe(e))
M.tick(10)
check(Lines("Level 6") == 1, "said once")

-- Stats that catch up only after the event are waited for.
M.out = {}
M.itemLevel = 0
M.levelUp({ hp = 20, power = 17, agi = 1, int = 2, spi = 1 }, 3)
M.tick(2)
e = last("level")
check(e.level == 7 and e.hp == nil and not Said("Level 7"), "old stats aren't saved")
M.tick(1)
check(e.hp == 188 and e.power == 292 and Stats(e) == "21,22,24,32,29" and e.ilvl == nil, "caught-up stats: " .. tostring(e.hp) .. ", " .. Stats(e))
check(Said("Level 7 in under a minute played (1d 1h total). +20 health, +17 mana, +1 Agility, +2 Intellect, +1 Spirit."),
	"line after the stats caught up: " .. tostring(Said("Level 7")))

-- In combat they can't be read: the entry waits until combat ends. A secret
-- event payload gives the change since the level before instead.
M.out = {}
M.combat = true
M.secrets[19] = true
M.levelUp({ hp = 19, power = 16, sta = 1, spi = 1 })
M.secrets[M.health], M.secrets[M.stats[3]] = true, true
M.tick(20)
e = last("level")
check(e.level == 8 and e.gain == nil and e.hp == nil and not Said("Level 8"), "waits for the end of combat")
M.combat, M.secrets = false, {}
M.fire("PLAYER_REGEN_ENABLED")
check(e.hp == 207 and Stats(e) == "21,22,25,32,30", "read after combat: " .. tostring(e.hp))
check(e.gain and e.gain.hp == 19 and e.gain.power == 16 and table.concat(e.gain.stats, ",") == "0,0,1,0,1",
	"gains since the level before")
check(Said("Level 8 in under a minute played (1d 1h total). +19 health, +16 mana, +1 Stamina, +1 Spirit."),
	"line after combat: " .. tostring(Said("Level 8")))

-- Unreadable for good: the line goes out after a few tries, without a snapshot.
M.out = {}
local health = UnitHealthMax
UnitHealthMax = function() return nil end
M.levelUp({ hp = 21, power = 18 })
M.tick(4)
check(not Said("Level 9"), "still trying")
M.tick(2)
e = last("level")
check(e.hp == nil and e.stats == nil and e.gain.hp == 21, "no snapshot")
check(e.powerType == "MANA" and Said("Level 9 in under a minute played (1d 1h total). +21 health, +18 mana."), "line without a snapshot: " .. tostring(Said("Level 9")))
UnitHealthMax = health

-- Rage: none gained. A change of power type since the level before gives
-- no power gain. Without one before, nothing is compared.
M.out = {}
M.powerType, M.power = "RAGE", 100
M.fire("PLAYER_LEVEL_UP", 10)
M.level = 10
M.health = M.health + 22
M.tick(1)
e = last("level")
check(e.powerType == "RAGE" and e.power == 100, "rage saved")
check(e.gain == nil, "level before has no snapshot: no gains")
M.out = {}
M.levelUp({ hp = 23 })
M.tick(1)
check(Said("Level 11 in under a minute played (1d 1h total). +23 health."), "no power gain: " .. tostring(Said("Level 11")))
M.fire("PLAYER_LEVEL_UP", 12)
M.level = 12
M.powerType = "ENERGY"
M.tick(1)
e = last("level")
check(e.gain and e.gain.hp == 0 and e.gain.power == nil and ns.LevelGains(e) == nil, "another power type isn't compared")
check(ns.Describe(e) == "Reached level 12 after under a minute at level 11", "nothing gained: " .. ns.Describe(e))
M.powerType = "MANA"

-- Two level-ups at once: the first is said straight away.
M.out = {}
M.combat = true
M.levelUp({ hp = 10 })
M.levelUp({ hp = 11 })
check(Said("Level 13 in under a minute played (1d 1h total). +10 health.") and not Said("Level 14"), "first said at the second")
M.tick(2)
M.combat = false
M.fire("PLAYER_REGEN_ENABLED")
check(Said("Level 14") and last("level").hp == M.health, "second after combat")

-- The setting turns the line off; the snapshot is still saved.
M.compartment.TravelLog:Click()
local w = ns.window
w.Tabs[2]:Click()
local box
for _, r in ipairs(M.descendants(w)) do
	if r.kind == "CheckButton" and r.Text:GetText() == "Say in chat what each level-up gave" then box = r end
end
check(box and box:GetChecked(), "setting on by default")
box:Click()
check(ns.settings.levelChat == false, "setting off")
M.out = {}
M.levelUp({ hp = 12 })
M.tick(1)
check(not Said("Level 15") and last("level").hp == M.health, "no line, snapshot saved")

-- After a reload: saved, and shown in /tl log.
ns = M.Reload()
check(ns.settings.levelChat == false, "setting saved")
e = last("level")
check(e.level == 15 and e.hp == M.health and e.gain.hp == 12 and #e.stats == 5, "entry saved")
local first = TravelLogCharDB.log
for _, o in ipairs(first) do
	if o.type == "level" and o.level == 6 then first = o break end
end
check(first.ilvl == 12.3 and first.gain.stats[3] == 2, "first level-up saved")
M.out = {}
SlashCmdList.TRAVELLOG("log level")
check(Said("Reached level 6 after 1h 0m at level 5: +18 health, +15 mana, +1 Strength, +2 Stamina"),
	"/tl log: " .. table.concat(M.out, "\n"))
ns.settings.levelChat = true

-- A level-up before /played answers: the line waits for it, and gets the
-- total played but not how long the level took.
local request = RequestTimePlayed
RequestTimePlayed = function()
	C_Timer.After(5, function() M.fire("TIME_PLAYED_MSG", M.played, M.playedLevel) end)
end
ns = M.Reload()
local before = M.played
M.out = {}
M.levelUp({ hp = 13 })
M.tick(2)
e = last("level")
check(e.hp == M.health and e.played == nil and not Said("Level 16"), "waits for /played")
M.tick(3)
check(e.played == before and e.took == nil, "total played from the late answer: " .. tostring(e.played) .. " vs " .. before)
check(Said("Level 16 (1d 1h played). +13 health."), "line after the answer: " .. tostring(Said("Level 16")))

-- No answer at all: said when the wait for it is over.
RequestTimePlayed = function() end
ns = M.Reload()
M.out = {}
M.levelUp({ hp = 14 })
M.tick(9)
check(not Said("Level 17"), "still waiting")
M.tick(1)
check(Said("Level 17. +14 health."), "line without times: " .. tostring(Said("Level 17")))
RequestTimePlayed = request
