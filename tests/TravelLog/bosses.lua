-- Boss fights: a wipe and a kill in a dungeon (with a reload during the
-- fight), a kill without a pull seen, a secret name, an unknown difficulty,
-- what leaving the dungeon says, a raid boss, and a fight outside any
-- instance; stats, /tl log, the Bosses row and a reload.
local ns = M.Login()

local function last(kind)
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == kind then return log[i] end
	end
end
local function count(kind)
	local n = 0
	for _, e in ipairs(TravelLogCharDB.log) do if e.type == kind then n = n + 1 end end
	return n
end
local function enter(kind, info)
	M.instance, M.instanceInfo = kind, info
	M.zone, M.subzone, M.x, M.wa = info.name, "", nil, nil
	M.fire("PLAYER_ENTERING_WORLD", false, false)
end
local function leave()
	M.instance = nil
	M.zone, M.subzone, M.x, M.y, M.wa, M.wb = "Westfall", "Moonbrook", 0.4, 0.7, -10000, 1500
	M.fire("PLAYER_ENTERING_WORLD", false, false)
end

M.tick(2)
enter("party", { name = "The Deadmines", difficultyName = "Normal", maxPlayers = 5, instanceID = 36 })
M.tick(300)

-- A wipe: the boss, difficulty, group size and how long it lasted.
M.fire("ENCOUNTER_START", 2972, "Edwin VanCleef", 1, 5)
M.tick(65)
M.fire("ENCOUNTER_END", 2972, "Edwin VanCleef", 1, 5, 0, {})
local wipe = last("boss")
check(count("boss") == 1 and wipe.name == "Edwin VanCleef" and wipe.id == 2972 and wipe.result == "wipe", "wipe logged")
check(wipe.difficulty == "Normal" and wipe.size == 5 and wipe.seconds == 65, "wipe's difficulty, size and length")
check(wipe.instance == "The Deadmines" and wipe.zone == "The Deadmines", "wipe's instance")
check(ns.Describe(wipe) == "Wiped on Edwin VanCleef after 1:05 (Normal, 5 players)", "wipe described: " .. ns.Describe(wipe))
check(not TravelLogCharDB.fight, "no fight in progress after it ends")

-- A kill, with a reload during the fight: the length counts from the pull.
M.tick(60)
M.fire("ENCOUNTER_START", 2972, "Edwin VanCleef", 1, 5)
M.tick(40)
ns = M.Reload()
check(TravelLogCharDB.fight and TravelLogCharDB.fight.id == 2972, "fight kept across a reload")
M.tick(50)
M.fire("ENCOUNTER_END", 2972, "Edwin VanCleef", 1, 5, 1, { { creatureID = 639, creatureName = "Edwin VanCleef", remainingHealthPercent = 0 } })
local kill = last("boss")
check(count("boss") == 2 and kill.result == "kill" and kill.seconds == 90, "kill after a reload: " .. tostring(kill.seconds))
check(ns.Describe(kill) == "Killed Edwin VanCleef in 1:30 (Normal, 5 players)", "kill described: " .. ns.Describe(kill))

-- A kill whose pull wasn't seen has no length; a secret name and an unknown
-- difficulty are left out.
M.secrets["Cookie"] = true
M.fire("ENCOUNTER_END", 2971, "Cookie", 77, 5, 1, {})
local odd = last("boss")
check(count("boss") == 3 and odd.id == 2971 and not odd.name and not odd.difficulty and not odd.seconds, "unknowns left out")
check(ns.Describe(odd) == "Killed boss 2971 (5 players)", "unnamed kill described: " .. ns.Describe(odd))

-- A pull of another boss doesn't time the one that ends.
M.fire("ENCOUNTER_START", 2970, "Mr. Smite", 1, 5)
M.tick(20)
M.fire("ENCOUNTER_END", 2969, "Sneed", 1, 5, 1, {})
check(not last("boss").seconds, "another boss's pull isn't its length")

-- Leaving says what happened inside.
M.tick(30)
leave()
local left = last("instanceleave")
check(left.kills == 3 and left.wipes == 1, "kills and wipes on leaving")
check(ns.Describe(left):find("^Left The Deadmines after %d+m: 3 bosses killed, 1 wipes$"), "leaving described: " .. ns.Describe(left))

-- A raid boss, and a visit with no fights.
enter("raid", { name = "Molten Core", difficultyName = "40 Player", maxPlayers = 40, instanceID = 409 })
M.fire("ENCOUNTER_START", 663, "Lucifron", 9, 38)
M.tick(120)
M.fire("ENCOUNTER_END", 663, "Lucifron", 9, 38, 1, {})
check(last("boss").instance == "Molten Core" and last("boss").size == 38 and last("boss").difficulty == "40 Player", "raid boss")
leave()
check(last("instanceleave").kills == 1 and not last("instanceleave").wipes, "raid visit's kills")
enter("party", { name = "The Deadmines", difficultyName = "Normal", maxPlayers = 5, instanceID = 36 })
M.tick(60)
leave()
check(not last("instanceleave").kills and ns.Describe(last("instanceleave")) == "Left The Deadmines after 1m", "visit without bosses")

-- A fight outside an instance has no instance.
M.fire("ENCOUNTER_START", 1, "Azuregos", 0, 40)
M.tick(5)
M.fire("ENCOUNTER_END", 1, "Azuregos", 0, 40, 0, {})
check(last("boss").result == "wipe" and not last("boss").instance and last("boss").zone == "Westfall", "outside an instance")

-- Counted, under Life, in /tl stats, /tl log and the window.
local st = ns.stats
check(st.bosses.kill == 4 and st.bosses.wipe == 2, "bosses counted")
check(ns.LogGroup(kill) == "Life" and ns.LogTypeLabel(kill) == "Boss", "group and label")
M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("Deaths .*") end
check(line and line:find("kills 0, bosses killed 4, wipes 2, quests done 0", 1, true), "stats line: " .. tostring(line))
M.out = {}
SlashCmdList.TRAVELLOG("log 2 killed lucifron")
check(#M.out == 2 and M.out[2]:find("Killed Lucifron in 2:00 (40 Player, 38 players)", 1, true), "/tl log: " .. tostring(M.out[2]))
SlashCmdList.TRAVELLOG("")
local values = {}
for _, fs in ipairs(M.descendants(TravelLogFrame.pages[1])) do values[#values + 1] = fs.text end
check(table.concat(values, "\n"):find("4 killed, 2 wipes", 1, true), "Bosses row")

ns = M.Reload()
check(ns.stats.bosses.kill == 4 and count("boss") == 6, "kept after a reload")
