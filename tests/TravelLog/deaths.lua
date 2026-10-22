-- Deaths: what killed you (drowning, fatigue, a fall, a mob), how you came
-- back (corpse run, spirit healer, another player, a soulstone), how long it
-- took, durability lost, a reload while dead, /tl log and /tl stats.
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
local function Die()
	M.dead = true
	M.fire("PLAYER_DEAD")
end
local function Release()
	M.dead, M.ghost = false, true
	M.fire("PLAYER_ALIVE")
end
local function Fall(seconds)
	M.falling = true
	M.frame()
	M.advance(seconds)
	M.falling = false
	M.frame()
end

-- Drowned: the breath bar ran out. Released, then ran back to the corpse.
-- Dying cost 10% of each item's durability.
M.durability = { [5] = { 80, 100 }, [16] = { 50, 50 } }
M.fire("UPDATE_INVENTORY_DURABILITY")
M.fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
M.advance(70)
M.durability = { [5] = { 70, 100 }, [16] = { 45, 50 } }
Die()
M.fire("MIRROR_TIMER_STOP", "BREATH")
local death = last("death")
check(death.cause == "drowning" and not death.target and death.level == 5, "drowned: " .. tostring(death.cause))
check(ns.Describe(death) == "Drowned at level 5", "described: " .. ns.Describe(death))
M.advance(5)
Release()
check(count("release") == 1, "released")
M.advance(120)
RetrieveCorpse()
M.ghost = false
M.fire("PLAYER_UNGHOST")
M.fire("PLAYER_ALIVE")
local revive = last("revive")
check(count("revive") == 1 and revive.how == "corpse" and revive.took == 125 and revive.ghost == 120,
	"corpse run: " .. tostring(revive.how) .. ", " .. tostring(revive.took) .. ", " .. tostring(revive.ghost))
M.tick(1)
check(revive.durability == 10, "durability lost: " .. tostring(revive.durability))
check(ns.Describe(revive) == "Ran back to corpse after 2:05 (2:00 as a ghost), lost 10% durability",
	"described: " .. ns.Describe(revive))

-- Fell to death at level 12, then the spirit healer: resurrection sickness
-- and another 25% durability.
M.level = 12
M.durability = { [5] = { 100, 100 } }
M.fire("UPDATE_INVENTORY_DURABILITY")
Fall(3)
Die()
death = last("death")
check(death.cause == "falling" and ns.Describe(death) == "Fell to death at level 12", "fell: " .. ns.Describe(death))
M.advance(10)
Release()
M.advance(50)
C_PlayerInteractionManager.ConfirmationInteraction(Enum.PlayerInteractionType.SpiritHealer)
M.ghost = false
M.fire("PLAYER_UNGHOST")
M.durability = { [5] = { 65, 100 } }
M.fire("UPDATE_INVENTORY_DURABILITY")
M.tick(1)
revive = last("revive")
check(revive.how == "spirithealer" and revive.sickness == true and revive.took == 60 and revive.ghost == 50
	and revive.durability == 35, "spirit healer: " .. ns.Describe(revive))
check(ns.Describe(revive) == "Revived by a spirit healer after 1:00 (0:50 as a ghost), with resurrection sickness, lost 35% durability",
	"described: " .. ns.Describe(revive))

-- Killed by a mob after a short fall and a breath bar that refilled: no
-- cause. Resurrected by another player without releasing.
M.fire("MIRROR_TIMER_START", "BREATH", 30000, 60000, -1, 0, "Breath")
M.advance(40)
M.fire("MIRROR_TIMER_START", "BREATH", 20000, 60000, 10, 0, "Breath")
M.advance(4)
M.fire("MIRROR_TIMER_STOP", "BREATH")
M.advance(60)
Fall(1)
M.units.target = { name = "Defias Thug", hostile = true }
Die()
death = last("death")
check(not death.cause and death.target == "Defias Thug", "a mob, nothing else: " .. tostring(death.cause))
check(ns.Describe(death) == "Died fighting Defias Thug at level 12", "described: " .. ns.Describe(death))
M.advance(30)
M.resurrecter = "Anna"
M.fire("RESURRECT_REQUEST", "Anna")
AcceptResurrect()
M.dead = false
M.fire("PLAYER_ALIVE")
revive = last("revive")
check(revive.how == "player" and revive.by == "Anna" and revive.took == 30 and not revive.ghost and not revive.sickness,
	"resurrected: " .. ns.Describe(revive))
check(ns.Describe(revive):find("^Resurrected by Anna after 0:30"), "described: " .. ns.Describe(revive))

-- Fatigue, with a pause in the bar: a mob as well. Back with a soulstone.
M.fire("MIRROR_TIMER_START", "EXHAUSTION", 60000, 60000, -1, 0, "Fatigue")
M.advance(20)
M.fire("MIRROR_TIMER_PAUSE", "EXHAUSTION", 1)
M.advance(100)
M.mirrorTimers.EXHAUSTION = 40000
M.fire("MIRROR_TIMER_PAUSE", "EXHAUSTION", 0)
M.advance(30)
M.units.target = { name = "Murloc", hostile = true }
Die()
check(not last("death").cause, "not out of breath yet after the pause")
M.dead = false
M.fire("PLAYER_ALIVE")
M.advance(15)
M.units.target = { name = "Murloc", hostile = true }
Die()
death = last("death")
check(death.cause == "fatigue" and ns.Describe(death) == "Died of fatigue fighting Murloc at level 12", "fatigue: " .. ns.Describe(death))
M.units.target = nil
M.advance(10)
M.selfRes = { { name = "Soulstone Resurrection", optionType = 0, id = 20707, canUse = true, isLimited = false, priority = 1 } }
C_DeathInfo.UseSelfResurrectOption(0, 20707)
M.dead = false
M.fire("PLAYER_ALIVE")
revive = last("revive")
check(revive.how == "selfres" and revive.spell == "Soulstone Resurrection", "soulstone: " .. ns.Describe(revive))
check(ns.Describe(revive):find("^Came back with Soulstone Resurrection after 0:10"), "described: " .. ns.Describe(revive))

-- A choice that didn't work (the resurrection timed out) isn't how you came
-- back, and a secret name isn't saved.
Die()
M.resurrecter = nil
M.secrets.Bob = true
M.fire("RESURRECT_REQUEST", "Bob")
AcceptResurrect()
M.advance(5)
M.dead = false
M.fire("PLAYER_ALIVE")
revive = last("revive")
check(revive.how == "player" and not revive.by and ns.Describe(revive):find("^Resurrected by another player"),
	"unreadable name: " .. ns.Describe(revive))
Die()
AcceptResurrect()
M.advance(60)
Release()
M.advance(30)
M.ghost = false
M.fire("PLAYER_UNGHOST")
revive = last("revive")
check(not revive.how and ns.Describe(revive):find("^Came back to life after 1:30 %(0:30 as a ghost%)"),
	"stale choice: " .. ns.Describe(revive))

-- A reload while a ghost keeps how long you were dead.
Die()
M.advance(20)
Release()
ns = M.Reload()
M.advance(40)
RetrieveCorpse()
M.ghost = false
M.fire("PLAYER_UNGHOST")
revive = last("revive")
check(revive.how == "corpse" and revive.took == 60 and revive.ghost == 40, "after a reload: " .. ns.Describe(revive))
M.tick(1)
check(not revive.durability, "no durability without a reading from before the death")

-- Totals and commands.
check(ns.stats.deaths == 8 and ns.stats.deathCauses.drowning == 1 and ns.stats.deathCauses.falling == 1
	and ns.stats.deathCauses.fatigue == 1, "death causes counted")
local r = ns.stats.revives
check(r.corpse == 2 and r.spirithealer == 1 and r.player == 2 and r.selfres == 1 and r.other == 2, "revivals counted")
check(ns.DeathsText(ns.stats) == "8 (1 falling, 1 drowning, 1 fatigue)", "deaths text: " .. ns.DeathsText(ns.stats))
check(ns.RevivalsText(ns.stats) == "corpse run 2, spirit healer 1, by a player 2, self-res 1; 6m dead",
	"revivals text: " .. ns.RevivalsText(ns.stats))
M.out = {}
SlashCmdList.TRAVELLOG("stats")
local stats = table.concat(M.out, "\n")
check(stats:find("Deaths 8 (1 falling, 1 drowning, 1 fatigue), kills 0", 1, true)
	and stats:find("Came back: corpse run 2, spirit healer 1, by a player 2, self-res 1; 6m dead", 1, true), "/tl stats: " .. stats)
M.out = {}
SlashCmdList.TRAVELLOG("log drowning")
local out = table.concat(M.out, "\n")
check(out:find('Last 1 events matching "drowning"', 1, true) and out:find("Drowned at level 5", 1, true), "/tl log drowning: " .. out)
M.out = {}
SlashCmdList.TRAVELLOG("log spirit healer")
out = table.concat(M.out, "\n")
check(out:find("Last 1 events", 1, true) and out:find("with resurrection sickness", 1, true), "/tl log spirit healer: " .. out)
local deaths, revivals = 0, 0
for _, e in ipairs(TravelLogCharDB.log) do
	if ns.LogMatches(e, "death") then deaths = deaths + 1 end
	if ns.LogMatches(e, "revival corpse") then revivals = revivals + 1 end
end
check(deaths == 8 and revivals == 2, "searches: " .. deaths .. " deaths, " .. revivals .. " corpse runs")
