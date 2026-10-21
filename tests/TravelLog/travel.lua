-- Travel besides flights: teleports by your own casts (a hearthstone-like
-- spell too), another mage's portal, summons, boats and zeppelins, dungeons
-- and raids with the time inside, and what isn't travel (casts that don't
-- move you, instance doors, knockbacks, deaths). Then the window, /tl log and
-- /tl stats, and a reload inside a dungeon.
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
local function moveTo(zone, subzone, wa, wb, inst)
	M.zone, M.subzone, M.wa, M.wb, M.inst = zone, subzone, wa, wb, inst or 0
	M.x, M.y = 0.5, 0.5
end

M.tick(2)

-- A cast that doesn't move you, then walking: nothing.
M.cast(133, "Young Wolf")
for _ = 1, 6 do M.wb = M.wb - 7; M.tick(1) end
check(count("teleport") == 0 and count("hearth") == 0, "a cast and a walk aren't travel")

-- A mage teleport: the jump right after the cast, with the spell's name.
M.spellNames[3561] = "Teleport: Stormwind"
M.cast(3561)
moveTo("Stormwind City", "Trade District", -8900, -700)
M.fire("ZONE_CHANGED_NEW_AREA")
local tp = last("teleport")
check(count("teleport") == 1 and tp.from == "Goldshire" and tp.to == "Trade District", "teleport from and to")
check(tp.spell == 3561 and tp.via == "Teleport: Stormwind", "teleport's spell")
check(ns.Describe(tp) == "Teleported from Goldshire to Trade District (Teleport: Stormwind)", "teleport described: " .. ns.Describe(tp))
M.tick(10)
check(count("teleport") == 1, "logged once")

-- Another spell that lands you where your hearthstone is set is a hearth.
M.spellNames[556] = "Astral Recall"
M.cast(556)
moveTo("Elwynn Forest", "Goldshire", -9000, -100)
M.tick(1)
local hearth = last("hearth")
check(count("hearth") == 1 and hearth.via == "Astral Recall" and hearth.from == "Trade District" and hearth.to == "Goldshire",
	"hearth-like spell")
check(ns.Describe(hearth) == "Hearthed from Trade District to Goldshire (Astral Recall)", "hearth described: " .. ns.Describe(hearth))

-- The Hearthstone used next to the inn barely moves you, but still counts.
M.spellNames[8690] = "Hearthstone"
M.cast(8690)
M.wb = M.wb - 20
M.tick(8)
check(count("hearth") == 2 and last("hearth").to == "Goldshire" and last("hearth").spell == 8690, "short hearth")

-- Taking another mage's portal to another continent: no cast of yours.
M.tick(10)
moveTo("Teldrassil", "Rut'theran Village", 9900, 2500, 1)
M.fire("PLAYER_ENTERING_WORLD", false, false)
tp = last("teleport")
check(count("teleport") == 2 and tp.from == "Goldshire" and tp.to == "Rut'theran Village" and not tp.via, "portal")
check(ns.Describe(tp) == "Teleported from Goldshire to Rut'theran Village", "portal described")

-- A summon: who and from where to where. A declined one is nothing.
M.tick(10)
M.summon = { by = "Grimlock", area = "Elwynn Forest" }
M.fire("CONFIRM_SUMMON", 0, false)
C_SummonInfo.CancelSummon()
M.tick(10)
M.summon = { by = "Grimlock", area = "Elwynn Forest" }
M.fire("CONFIRM_SUMMON", 0, false)
C_SummonInfo.ConfirmSummon()
moveTo("Elwynn Forest", "Northshire Valley", -8900, 0)
M.fire("PLAYER_ENTERING_WORLD", false, false)
local summon = last("summon")
check(count("summon") == 1 and summon.by == "Grimlock" and summon.from == "Rut'theran Village" and summon.to == "Northshire Valley",
	"summon")
check(count("teleport") == 2, "a summon isn't another teleport")
check(ns.Describe(summon) == "Summoned from Rut'theran Village to Northshire Valley by Grimlock", "summon described")

-- Deaths aren't teleports: off to the graveyard as a ghost and back.
M.tick(10)
M.dead = true
M.tick(1)
M.dead, M.ghost = false, true
moveTo("Elwynn Forest", "Goldshire", -9000, -100)
M.tick(1)
M.ghost = false
moveTo("Elwynn Forest", "Northshire Valley", -8900, 0)
M.tick(1)
check(count("teleport") == 2, "graveyard isn't a teleport")

-- A knockback is too short to be a ride.
M.speed = 0
M.wb = M.wb - 30
M.tick(1)
M.speed = nil
M.tick(3)
check(count("board") == 0, "knockback isn't a boat")

-- A boat: carried while standing still, a loading screen halfway, then off.
-- (A flight takes us to the harbor.)
M.taxi = true
M.tick(1)
moveTo("Wetlands", "Menethil Harbor", -3700, -600)
M.tick(1)
M.taxi = false
M.tick(5)
M.speed = 0
for i = 1, 40 do
	if i == 20 then
		moveTo("Darkshore", "The Great Sea", 6000, 1000, 1)
		M.fire("PLAYER_ENTERING_WORLD", false, false)
	else
		M.wa = M.wa + 15
	end
	if i == 35 then M.subzone = "Auberdine" end
	M.tick(1)
	if i == 5 then check(count("board") == 1, "boarded after 5 s") end
end
check(count("board") == 1 and last("board").subzone == "Menethil Harbor", "boarded at the harbor")
check(ns.Describe(last("board")) == "Boarded a boat or zeppelin at Menethil Harbor", "boarding described")
M.tick(1)
M.speed = nil
M.tick(8)
check(count("disembark") == 0, "still on board while docked")
M.tick(2)
local ride = last("disembark")
check(count("disembark") == 1 and ride.from == "Menethil Harbor" and ride.to == "Auberdine" and ride.seconds == 40,
	"arrived: " .. tostring(ride and ride.seconds))
check(ride.subzone == "Auberdine" and ride.time == last("board").time + 39, "arrival stamped where the boat stopped")
check(ns.Describe(ride) == "Rode a boat or zeppelin from Menethil Harbor to Auberdine in 0:40", "ride described: " .. ns.Describe(ride))
check(count("teleport") == 2, "the loading screen on a boat isn't a teleport")

-- A dungeon through its door: entered, not a teleport. A reload inside
-- isn't a new visit and time logged out doesn't count.
M.tick(10)
M.instance, M.instanceInfo = "party", { name = "The Deadmines", difficultyName = "Normal", maxPlayers = 5, instanceID = 36 }
M.zone, M.subzone, M.x, M.wa = "The Deadmines", "", nil, nil
M.fire("PLAYER_ENTERING_WORLD", false, false)
local entered = last("instance")
check(count("instance") == 1 and entered.name == "The Deadmines" and entered.kind == "dungeon"
	and entered.difficulty == "Normal" and entered.size == 5, "dungeon entered")
check(ns.Describe(entered) == "Entered The Deadmines (dungeon, Normal)", "entry described: " .. ns.Describe(entered))
check(count("teleport") == 2 and count("hearth") == 2, "a door isn't a teleport")
M.tick(600)
ns = M.Reload()
M.Logout()
M.advance(3600)
ns = M.Login()
check(count("instance") == 1 and TravelLogCharDB.instance.name == "The Deadmines", "same visit after reload and relog")
M.tick(300)

-- Hearthing out: a hearth and leaving the dungeon.
M.cast(8690)
M.instance = nil
moveTo("Elwynn Forest", "Goldshire", -9000, -100)
M.fire("PLAYER_ENTERING_WORLD", false, false)
check(count("hearth") == 3 and last("hearth").from == "The Deadmines", "hearthed out of the dungeon")
local left = last("instanceleave")
check(left and left.name == "The Deadmines" and left.seconds == 900, "left after 15 minutes inside: " .. tostring(left and left.seconds))
check(ns.Describe(left) == "Left The Deadmines after 15m", "leaving described")
check(not TravelLogCharDB.instance, "no longer inside")

-- A summon straight into a raid.
M.tick(10)
M.summon = { by = "Grimlock", area = "Molten Core" }
M.fire("CONFIRM_SUMMON", 0, false)
C_SummonInfo.ConfirmSummon()
M.instance, M.instanceInfo = "raid", { name = "Molten Core", difficultyName = "40 Player", maxPlayers = 40, instanceID = 409 }
M.zone, M.subzone, M.x, M.wa = "Molten Core", "", nil, nil
M.fire("PLAYER_ENTERING_WORLD", false, false)
check(count("summon") == 2 and last("summon").to == "Molten Core", "summoned into a raid")
check(last("instance").kind == "raid" and last("instance").size == 40, "raid entered")

-- A summoner's name can be secret.
M.instance = nil
moveTo("Elwynn Forest", "Goldshire", -9000, -100)
M.fire("PLAYER_ENTERING_WORLD", false, false)
M.tick(10)
M.secrets["Shadowy"] = true
M.summon = { by = "Shadowy", area = "Elwynn Forest" }
M.fire("CONFIRM_SUMMON", 0, false)
C_SummonInfo.ConfirmSummon()
moveTo("Elwynn Forest", "Northshire Valley", -8900, 0)
M.tick(1)
check(count("summon") == 3 and not last("summon").by, "secret summoner left out")
check(ns.Describe(last("summon")) == "Summoned from Goldshire to Northshire Valley", "summon without a name described")

-- Counted, and under Travel in the window and /tl log.
local st = ns.stats
check(st.hearths == 3 and st.teleports == 2 and st.summons == 3 and st.boats == 1, "travel counted")
check(st.instances.dungeon == 1 and st.instances.raid == 1 and st.instanceTime == 900, "instances counted")
for _, kind in ipairs({ "teleport", "summon", "board", "disembark", "instance", "instanceleave" }) do
	check(ns.LogGroup(last(kind)) == "Travel", kind .. " under Travel")
end
check(ns.LogTypeLabel(last("disembark")) == "Arrival" and ns.LogTypeLabel(last("instanceleave")) == "Instance left", "labels")
M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("Hearths .*") end
check(line == "Hearths 3, teleports 2, summons 3, boat rides 1, dungeons 1, raids 1, 15m inside", "stats line: " .. tostring(line))
M.out = {}
SlashCmdList.TRAVELLOG("log 3 summon")
check(#M.out == 4 and M.out[2]:find("Summoned from Rut'theran Village to Northshire Valley by Grimlock", 1, true), "/tl log")

SlashCmdList.TRAVELLOG("")
local w = TravelLogFrame
local values = {}
for _, fs in ipairs(M.descendants(w.pages[1])) do values[#values + 1] = fs.text end
local all = table.concat(values, "\n")
check(all:find("3 hearths, 2 teleports, 3 summons", 1, true), "Teleports row")
check(all:find("1 dungeons, 1 raids, 15m inside", 1, true), "Instances row")
