-- Hunter pets: a beast tamed (the first one marked), a tame cut short by
-- moving or an interrupt, pets called or dismissed, other channels, a secret
-- name, the log, History, stats and a reload.
M.player.class = "HUNTER"
M.level = 10
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
-- The beast becomes your pet: the target is gone and the pet appears.
local function Becomes(pet)
	M.units.target = nil
	M.units.pet = pet
	M.fire("UNIT_PET", "player")
end

-- A full channel and a new pet: tamed.
M.units.target = { name = "Young Nightsaber", guid = "Creature-0-1-0-1-2031-0001", level = 3, family = "Cat", hostile = true }
M.channel(1515, 20)
M.advance(20)
M.channelStop()
Becomes({ name = "Young Nightsaber", guid = "Pet-0-1-0-1-2031-0002", level = 3, family = "Cat", pet = true })
local t = last("tame")
check(count("tame") == 1 and t.name == "Young Nightsaber" and t.id == 2031 and t.level == 3 and t.family == "Cat"
	and t.first and not t.pet, "tame logged")
check(t.zone == "Elwynn Forest" and t.x, "stamped with where")
check(ns.Describe(t) == "First pet: Young Nightsaber (level 3 Cat)", "described: " .. ns.Describe(t))
check(ns.stats.tames == 1, "tame counted")

-- Dismissing and calling the pet back isn't a tame.
M.units.pet = nil
M.fire("UNIT_PET", "player")
M.advance(60)
M.units.pet = { name = "Young Nightsaber", guid = "Pet-0-1-0-1-2031-0002", level = 3, family = "Cat", pet = true }
M.fire("UNIT_PET", "player")
check(count("tame") == 1, "called pet not logged")

-- Moving stops the channel early: the beast stays wild, even if the old
-- pet is called right after.
M.units.pet = nil
M.fire("UNIT_PET", "player")
M.units.target = { name = "Mangy Wolf", guid = "Creature-0-1-0-1-525-0003", level = 2, family = "Wolf", hostile = true }
M.channel(1515, 20)
M.advance(6)
M.channelStop()
M.advance(1)
M.units.pet = { name = "Young Nightsaber", guid = "Pet-0-1-0-1-2031-0002", level = 3, family = "Cat", pet = true }
M.fire("UNIT_PET", "player")
check(count("tame") == 1, "channel cut short: no tame")

-- An interrupt does the same.
M.units.pet = nil
M.fire("UNIT_PET", "player")
M.channel(1515, 20)
M.advance(20)
M.channelStop(true)
M.units.pet = { name = "Young Nightsaber", guid = "Pet-0-1-0-1-2031-0002", level = 3, family = "Cat", pet = true }
M.fire("UNIT_PET", "player")
check(count("tame") == 1, "interrupted: no tame")

-- A pet that turns up long after the channel isn't from it.
M.units.pet = nil
M.fire("UNIT_PET", "player")
M.channel(1515, 20)
M.advance(20)
M.channelStop()
M.advance(10)
M.units.pet = { name = "Young Nightsaber", guid = "Pet-0-1-0-1-2031-0002", level = 3, family = "Cat", pet = true }
M.fire("UNIT_PET", "player")
check(count("tame") == 1, "late pet not logged")

-- Another channel isn't a tame.
M.units.pet = nil
M.fire("UNIT_PET", "player")
M.spellNames[6197] = "Eagle Eye"
M.channel(6197, 10)
M.advance(10)
M.channelStop()
Becomes({ name = "Young Nightsaber", guid = "Pet-0-1-0-1-2031-0002", level = 3, family = "Cat", pet = true })
check(count("tame") == 1, "other channel not a tame")

-- A second tame, by another spell ID of the same name; the pet is named after
-- its family, so it has no name of its own yet.
M.units.pet = nil
M.fire("UNIT_PET", "player")
M.spellNames[13481] = "Tame Beast"
M.units.target = { name = "Mangy Wolf", guid = "Creature-0-1-0-1-525-0004", level = 2, family = "Wolf", hostile = true }
M.channel(13481, 20)
M.advance(20)
M.channelStop()
Becomes({ name = "Wolf", guid = "Pet-0-1-0-1-525-0005", level = 2, family = "Wolf", pet = true })
t = last("tame")
check(count("tame") == 2 and t.name == "Mangy Wolf" and t.id == 525 and t.family == "Wolf" and not t.first and not t.pet,
	"second tame logged")
check(ns.Describe(t) == "Tamed Mangy Wolf (level 2 Wolf)", "described: " .. ns.Describe(t))

-- A beast whose name the client won't reveal: the pet's name stands in.
M.units.pet = nil
M.fire("UNIT_PET", "player")
M.secrets["Dire Mottled Boar"] = true
M.units.target = { name = "Dire Mottled Boar", guid = "Creature-0-1-0-1-3099-0006", level = 6, family = "Boar", hostile = true }
M.channel(1515, 20)
M.advance(20)
M.channelStop()
Becomes({ name = "Boar", guid = "Pet-0-1-0-1-3099-0007", level = 6, family = "Boar", pet = true })
t = last("tame")
check(count("tame") == 3 and t.name == "Boar" and t.id == 3099 and t.level == 6, "secret name: " .. tostring(t.name))
check(ns.stats.tames == 3, "three tames counted")

-- History's Progress group, search, /tl log and /tl stats.
local first
for _, e in ipairs(TravelLogCharDB.log) do first = first or (e.type == "tame" and e) end
check(ns.LogGroup(first) == "Progress" and ns.LogTypeLabel(first) == "Pet tamed", "group and label")
check(ns.LogMatches(first, "nightsaber", "Progress") and ns.LogMatches(first, "pet tamed"), "History search")
M.out = {}
SlashCmdList.TRAVELLOG("log 5 tame")
local out = table.concat(M.out, "\n")
check(out:find("First pet: Young Nightsaber (level 3 Cat)", 1, true) and out:find("Tamed Mangy Wolf", 1, true), "/tl log: " .. out)
M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("Spells learned .*") end
check(line and line:find("pets tamed 3", 1, true), "stats line: " .. tostring(line))

-- Kept across a reload.
ns = M.Reload()
check(count("tame") == 3 and last("tame").name == "Boar" and ns.stats.tames == 3, "kept after reload")
