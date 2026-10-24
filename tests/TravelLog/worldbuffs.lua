-- World buffs: gained ones logged with name, spell, duration and giver;
-- buffs already on you at login, refreshes, other buffs, other units, secret
-- spell IDs and full updates not; totals, the window, /tl log and a reload.
M.auras[15366] = { spellId = 15366, auraInstanceID = 900, name = "Songflower Serenade", duration = 3600 }
local ns = M.Login()

local function count(kind)
	local n = 0
	for _, e in ipairs(TravelLogCharDB.log) do if e.type == kind then n = n + 1 end end
	return n
end
local function last()
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == "worldbuff" then return log[i] end
	end
end

-- Already on you at login: remembered, not logged, even if listed again.
check(count("worldbuff") == 0, "buff from before login not logged")
M.fire("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = { M.auras[15366] } })
check(count("worldbuff") == 0, "buff from before login listed again not logged")

-- Rallying Cry from the NPC you're talking to.
M.units.npc = { name = "Major Mattingly" }
M.zone, M.subzone, M.x, M.y = "Stormwind City", "Valley of Heroes", 0.62, 0.71
M.gainAura(22888, { name = "Rallying Cry of the Dragonslayer", duration = 7200, sourceUnit = "npc" })
local e = last()
check(count("worldbuff") == 1, "gain logged")
check(e.id == 22888 and e.name == "Rallying Cry of the Dragonslayer" and e.duration == 7200 and e.by == "Major Mattingly",
	"fields: " .. tostring(e.id) .. " " .. tostring(e.name) .. " " .. tostring(e.duration) .. " " .. tostring(e.by))
check(e.zone == "Stormwind City" and e.subzone == "Valley of Heroes" and e.x == 62 and e.y == 71, "where")
check(ns.Describe(e) == "Gained Rallying Cry of the Dragonslayer (2h 0m, from Major Mattingly)", "described: " .. ns.Describe(e))
check(ns.LogGroup(e) == "Life" and ns.LogTypeLabel(e) == "World buff", "under Life")

-- A refresh in place isn't a new gain; a new aura replacing it is.
M.refreshAura(22888)
check(count("worldbuff") == 1, "refresh not logged")
M.gainAura(22888, { name = "Rallying Cry of the Dragonslayer", duration = 7200 })
check(count("worldbuff") == 2 and last().by == nil, "replaced buff logged, no giver")

-- Other buffs and other units are ignored.
M.gainAura(1459, { name = "Arcane Intellect", duration = 1800 })
M.fire("UNIT_AURA", "target", { isFullUpdate = false,
	addedAuras = { { spellId = 16609, auraInstanceID = 5000, name = "Warchief's Blessing", duration = 3600 } } })
check(count("worldbuff") == 2, "other buffs and units ignored")

-- From yourself (no giver), without a name (the list's), without a duration.
M.gainAura(23768, { sourceUnit = "player" })
e = last()
check(count("worldbuff") == 3 and e.name == "Sayge's Dark Fortune of Damage" and e.by == nil and e.duration == nil,
	"name from the list, no giver or duration")
check(ns.Describe(e) == "Gained Sayge's Dark Fortune of Damage", "described: " .. ns.Describe(e))

-- A secret spell ID (aura restrictions in combat) can't be told apart.
local secret = {}
M.secrets[secret] = true
M.fire("UNIT_AURA", "player", { isFullUpdate = false,
	addedAuras = { { spellId = secret, auraInstanceID = 5001, duration = 7200 } } })
check(count("worldbuff") == 3 and #M.errors == 0, "secret spell ID skipped")

-- A full update (a loading screen) only remembers what's on you.
M.auras[24425] = { spellId = 24425, auraInstanceID = 5002, name = "Spirit of Zandalar", duration = 7200 }
M.fire("UNIT_AURA", "player", { isFullUpdate = true })
M.fire("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = { M.auras[24425] } })
check(count("worldbuff") == 3, "full update not logged")

-- Lost and gained again.
M.loseAura(15366)
M.gainAura(15366, { name = "Songflower Serenade", duration = 3600 })
check(count("worldbuff") == 4 and last().name == "Songflower Serenade" and last().duration == 3600, "regained logged")

-- Totals, /tl stats, /tl log and the window.
check(ns.stats.worldBuffs == 4, "counted: " .. tostring(ns.stats.worldBuffs))
M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("World buffs: %d+") end
check(line == "World buffs: 4", "stats line: " .. tostring(line))
M.out = {}
SlashCmdList.TRAVELLOG("log 10 world buff")
check(#M.out == 5 and M.out[2]:find("Gained Rallying Cry of the Dragonslayer (2h 0m, from Major Mattingly)", 1, true),
	"/tl log lists them: " .. tostring(M.out[2]))
M.out = {}
SlashCmdList.TRAVELLOG("log zandalar")
check(#M.out == 1, "/tl log: Spirit of Zandalar not logged")

SlashCmdList.TRAVELLOG("")
local values = {}
for _, fs in ipairs(M.descendants(TravelLogFrame.pages[1])) do values[#values + 1] = fs.text end
check(table.concat(values, "\n"):find("World buffs\n4", 1, true), "World buffs row")

-- A reload keeps them, and the buffs still on you aren't logged again.
ns = M.Reload()
check(count("worldbuff") == 4 and ns.stats.worldBuffs == 4, "kept after a reload")
M.fire("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = { M.auras[22888], M.auras[24425] } })
check(count("worldbuff") == 4, "buffs from before the reload not logged")
M.gainAura(22817, { name = "Fengus' Ferocity", duration = 7200 })
check(count("worldbuff") == 5 and last().id == 22817, "logged after a reload")
