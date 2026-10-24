-- Hunter pets: a beast tamed (the first one marked), a tame cut short by
-- moving or an interrupt, pets called or dismissed, other channels, a secret
-- name; level-ups, abandoning and the stable; the log, History, stats and a
-- reload.
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
SlashCmdList.TRAVELLOG("")
local totals = M.descendants(ns.window)
for i, r in ipairs(totals) do
	if r.kind == "FontString" and r:GetText() == "Pets" then line = totals[i + 1]:GetText() end
end
check(line == "3 tamed, 0 levels gained, 0 abandoned", "pet total: " .. tostring(line))

-- Kept across a reload.
ns = M.Reload()
check(count("tame") == 3 and last("tame").name == "Boar" and ns.stats.tames == 3, "kept after reload")

-- Your pet's level-ups: the level it's seen at first isn't one, and each
-- level gained is logged once, from either event.
local fang = { name = "Fang", guid = "Pet-0-1-0-1-525-0008", level = 10, family = "Wolf", pet = true }
M.units.pet = fang
M.fire("UNIT_PET", "player")
check(count("petlevel") == 0, "pet out: no level-up")
fang.level = 11
M.fire("UNIT_LEVEL", "pet")
local p = last("petlevel")
check(count("petlevel") == 1 and p.name == "Fang" and p.family == "Wolf" and p.level == 11, "pet level-up logged")
check(p.zone == "Elwynn Forest", "level-up stamped with where")
check(ns.Describe(p) == "Fang reached level 11 (Wolf)", "described: " .. ns.Describe(p))
M.fire("UNIT_PET_EXPERIENCE", "player")
M.fire("UNIT_LEVEL", "pet")
check(count("petlevel") == 1, "same level not logged again")
fang.level = 13
M.fire("UNIT_PET_EXPERIENCE", "player")
check(count("petlevel") == 3 and last("petlevel").level == 13, "two levels at once: one entry each")
M.fire("UNIT_LEVEL", "target")
check(count("petlevel") == 3, "other units' levels ignored")

-- Another pet called out at a higher level isn't a level-up, nor is a
-- level the client hides.
M.units.pet = { name = "Wolf", guid = "Pet-0-1-0-1-525-0005", level = 20, family = "Wolf", pet = true }
M.fire("UNIT_PET", "player")
check(count("petlevel") == 3, "other pet: no level-up")
M.units.pet.level = 21
M.fire("UNIT_LEVEL", "pet")
check(ns.Describe(last("petlevel")) == "Your Wolf reached level 21", "unnamed pet: " .. ns.Describe(last("petlevel")))
M.secrets[22] = true
M.units.pet.level = 22
M.fire("UNIT_LEVEL", "pet")
check(count("petlevel") == 4, "secret level skipped")
M.secrets[22] = nil
M.fire("UNIT_LEVEL", "pet")
check(count("petlevel") == 5 and last("petlevel").level == 22, "level logged once readable")

-- Abandoning: confirmed by the pet going away. One that stays, or goes long
-- after, wasn't abandoned.
M.units.pet = fang
M.fire("UNIT_PET", "player")
C_PetInfo.PetAbandon()
M.advance(10)
M.units.pet = nil
M.fire("UNIT_PET", "player")
check(count("petabandon") == 0, "pet dismissed long after: not abandoned")
M.units.pet = fang
M.fire("UNIT_PET", "player")
C_PetInfo.PetAbandon()
M.advance(1)
M.units.pet = nil
M.fire("UNIT_PET", "player")
local a = last("petabandon")
check(count("petabandon") == 1 and a.name == "Fang" and a.level == 13 and a.family == "Wolf", "abandon logged")
check(ns.Describe(a) == "Abandoned Fang (level 13 Wolf)", "described: " .. ns.Describe(a))
check(ns.stats.petAbandons == 1 and ns.stats.petLevels == 5, "pet totals")

-- The stable: slot 1 is the pet you can call. Putting it away, taking one
-- out and swapping them; opening the stable and moving pets between stable
-- slots is neither.
M.stable = {
	{ name = "Wolf", level = 22, familyName = "Wolf", petNumber = 5 },
	{ name = "Young Nightsaber", level = 3, familyName = "Cat", petNumber = 2 },
}
M.fire("PET_STABLE_SHOW")
M.fire("PET_STABLE_UPDATE")
check(count("petstable") == 0 and count("petunstable") == 0, "opening the stable logs nothing")
C_StableInfo.SetPetSlot(1, 3)
local st = last("petstable")
check(count("petstable") == 1 and st.name == "Wolf" and st.level == 22 and st.family == "Wolf", "pet stabled")
check(ns.Describe(st) == "Stabled your level 22 Wolf", "described: " .. ns.Describe(st))
C_StableInfo.SetPetSlot(2, 3)
check(count("petstable") == 1 and count("petunstable") == 0, "moved between stable slots: nothing")
C_StableInfo.SetPetSlot(3, 1)
local un = last("petunstable")
check(count("petunstable") == 1 and un.name == "Young Nightsaber" and un.level == 3 and un.family == "Cat", "pet taken out")
check(ns.Describe(un) == "Took Young Nightsaber (level 3 Cat) out of the stable", "described: " .. ns.Describe(un))
C_StableInfo.SetPetSlot(1, 2)
local log = TravelLogCharDB.log
check(count("petstable") == 2 and count("petunstable") == 2 and log[#log - 1].type == "petstable"
	and log[#log - 1].name == "Young Nightsaber" and log[#log].name == "Wolf", "swap: stabled, then taken out")
M.fire("PET_STABLE_CLOSED")
C_StableInfo.SetPetSlot(1, 2)
check(count("petstable") == 2, "stable closed: not logged")

-- A pet that isn't a hunter's: a warlock's demon levels with its master.
M.player.class = "WARLOCK"
M.units.pet = { name = "Imp", guid = "Pet-0-1-0-1-416-0009", level = 20, family = "Imp", pet = true }
M.fire("UNIT_PET", "player")
M.units.pet.level = 21
M.fire("UNIT_LEVEL", "pet")
check(count("petlevel") == 5, "demon level not logged")
M.player.class = "HUNTER"

-- History, /tl log, /tl stats and the Totals row.
check(ns.LogGroup(p) == "Progress" and ns.LogTypeLabel(p) == "Pet level", "level-up group and label")
check(ns.LogGroup(a) == "Progress" and ns.LogTypeLabel(a) == "Pet abandoned", "abandon group and label")
check(ns.LogGroup(st) == "Progress" and ns.LogTypeLabel(st) == "Pet stabled"
	and ns.LogGroup(un) == "Progress" and ns.LogTypeLabel(un) == "Pet unstabled", "stable groups and labels")
check(ns.LogMatches(a, "pet abandoned fang", "Progress") and ns.LogMatches(un, "unstabled cat"), "History search")
M.out = {}
SlashCmdList.TRAVELLOG("log 20 pet")
out = table.concat(M.out, "\n")
check(out:find("Fang reached level 11 (Wolf)", 1, true) and out:find("Abandoned Fang", 1, true)
	and out:find("Stabled your level 22 Wolf", 1, true), "/tl log: " .. out)
M.out = {}
SlashCmdList.TRAVELLOG("stats")
line = nil
for _, text in ipairs(M.out) do line = line or text:match("Spells learned .*") end
check(line and line:find("pets tamed 3, pet levels 5, pets abandoned 1", 1, true), "stats line: " .. tostring(line))
SlashCmdList.TRAVELLOG("")
totals = M.descendants(ns.window)
line = nil
for i, r in ipairs(totals) do
	if r.kind == "FontString" and r:GetText() == "Pets" then line = totals[i + 1]:GetText() end
end
check(line == "3 tamed, 5 levels gained, 1 abandoned", "pet totals row: " .. tostring(line))

ns = M.Reload()
check(count("petlevel") == 5 and count("petabandon") == 1 and count("petstable") == 2 and count("petunstable") == 2
	and ns.stats.petLevels == 5 and ns.stats.petAbandons == 1, "pet entries kept after reload")
