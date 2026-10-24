-- Who or what killed you, from the death recap: a mob, a player, lava; a
-- recap that's late, old or unreadable; the totals.
local ns = M.Login()

local function last()
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == "death" then return log[i] end
	end
end
local stamp = 5000
local function Hit(hit)
	stamp = stamp + 10
	hit.timestamp = stamp
	return hit
end
-- Dies; the recap is ready a frame later.
local function Die(recap)
	M.dead = true
	M.fire("PLAYER_DEAD")
	M.recap = recap
	M.tick(1)
	M.dead = false
	M.fire("PLAYER_ALIVE")
end

-- A mob's melee hit; the recap fills the entry in place a frame later.
M.units.target = { name = "Defias Thug", hostile = true }
M.dead = true
M.fire("PLAYER_DEAD")
local death = last()
check(not death.killer and death.target == "Defias Thug", "no recap during PLAYER_DEAD")
M.recap = {
	Hit({ event = "SWING_DAMAGE", sourceName = "Defias Thug", sourceGUID = "Creature-0-1-2-3-116-4", amount = 45, overkill = 12, school = 1 }),
	Hit({ event = "SPELL_DAMAGE", spellName = "Backstab", spellId = 53, sourceName = "Defias Thug", amount = 30, overkill = -1 }),
}
M.tick(1)
check(death.killer == "Defias Thug" and death.killerType == "Creature" and death.killerID == 116 and death.amount == 45
	and death.overkill == 12 and not death.spell and not death.cause, "mob: " .. ns.Describe(death))
check(ns.Describe(death) == "Killed by Defias Thug (45 damage) at level 5", "described: " .. ns.Describe(death))
M.dead = false
M.fire("PLAYER_ALIVE")
M.units.target = nil

-- A long fall, but a mob's spell killed you: the recap wins over the fall.
M.falling = true
M.frame()
M.advance(3)
M.falling = false
M.frame()
M.dead = true
M.fire("PLAYER_DEAD")
check(last().cause == "falling" and ns.stats.deathCauses.falling == 1, "the fall, until the recap")
M.recap = { Hit({ event = "SPELL_DAMAGE", spellName = "Fireball", spellId = 133, sourceName = "Kobold Geomancer",
	sourceGUID = "Creature-0-1-2-3-476-9", amount = 25 }) }
M.tick(1)
death = last()
check(not death.cause and not ns.stats.deathCauses.falling and death.spell == "Fireball" and death.spellID == 133
	and not death.overkill, "recap over the fall: " .. ns.Describe(death))
check(ns.Describe(death) == "Killed by Kobold Geomancer (Fireball, 25 damage) at level 5", "described: " .. ns.Describe(death))
M.dead = false
M.fire("PLAYER_ALIVE")

-- Lava, which the bars can't tell.
Die({ Hit({ event = "ENVIRONMENTAL_DAMAGE", environmentalType = "Lava", amount = 300 }) })
death = last()
check(death.cause == "lava" and not death.killer and ns.Describe(death) == "Died in lava at level 5", "lava: " .. ns.Describe(death))

-- Another player's spell; a pet.
Die({ Hit({ event = "SPELL_DAMAGE", spellName = "Shadow Bolt", spellId = 686, sourceName = "Bob",
	sourceGUID = "Player-1-0ABC", amount = 1234, overkill = 200 }) })
death = last()
check(death.killerType == "Player" and not death.killerID
	and ns.Describe(death) == "Killed by Bob (player, Shadow Bolt, 1,234 damage) at level 5", "player: " .. ns.Describe(death))
Die({ Hit({ event = "SWING_DAMAGE", sourceName = "Wolf", sourceGUID = "Pet-0-1-2-3-299-5", amount = 20 }) })
check(ns.Describe(last()) == "Killed by Wolf (pet, 20 damage) at level 5", "pet: " .. ns.Describe(last()))

-- An old recap isn't used again: the drowning bar names the cause.
M.fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
M.advance(70)
M.dead = true
M.fire("PLAYER_DEAD")
M.fire("MIRROR_TIMER_STOP", "BREATH")
M.tick(2)
death = last()
check(death.cause == "drowning" and not death.killer and ns.Describe(death) == "Drowned at level 5", "old recap: " .. ns.Describe(death))
M.dead = false
M.fire("PLAYER_ALIVE")

-- A recap that's ready only a second later, with an unreadable name.
M.recap = nil
M.dead = true
M.fire("PLAYER_DEAD")
M.tick(1)
check(not last().amount, "nothing yet")
M.secrets["Rogue"] = true
M.recap = { Hit({ event = "SWING_DAMAGE", sourceName = "Rogue", sourceGUID = "Player-1-0DEF", amount = 50 }) }
M.tick(1)
death = last()
check(death.amount == 50 and not death.killer and death.killerType == "Player", "late, secret name: " .. ns.Describe(death))
check(ns.Describe(death) == "Died at level 5", "described: " .. ns.Describe(death))
M.dead = false
M.fire("PLAYER_ALIVE")

-- A hidden caster isn't named.
Die({ Hit({ event = "SPELL_DAMAGE", spellName = "Shadow Word: Pain", sourceName = "Priest", hideCaster = true, amount = 10 }) })
check(not last().killer and last().spell == "Shadow Word: Pain", "hidden caster")

-- Totals, and the fields after a reload.
check(ns.stats.deaths == 8 and ns.stats.deathCauses.lava == 1 and ns.stats.deathCauses.drowning == 1
	and ns.stats.deathCauses.player == 3, "counted")
check(ns.DeathsText(ns.stats) == "8 (1 drowning, 1 lava, 3 by players)", "deaths text: " .. ns.DeathsText(ns.stats))
ns = M.Reload()
local first
for _, e in ipairs(TravelLogCharDB.log) do
	if e.type == "death" then first = first or e end
end
check(first.killer == "Defias Thug" and first.killerID == 116 and first.overkill == 12, "saved")
M.out = {}
SlashCmdList.TRAVELLOG("log geomancer")
check(table.concat(M.out, "\n"):find("Killed by Kobold Geomancer (Fireball, 25 damage)", 1, true), "/tl log geomancer")

-- A recap from before the reload is old.
Die({ M.recap[1] })
check(not last().amount, "recap from before the reload")

-- No recap API, or one that errors: no harm.
local api = C_DeathRecap
C_DeathRecap = nil
Die(nil)
check(last() and not last().killer, "no API")
C_DeathRecap = { GetRecapEvents = function() error("secret") end }
Die(nil)
check(last() and not last().killer, "API error")
C_DeathRecap = api
