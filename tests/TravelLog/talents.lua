-- Talent points: the ones you have at the first login remembered, each point
-- applied logged with tree, rank and level, points staged but not applied,
-- several at once, refunds and a full reset, the second spec, unreadable
-- names, the log, History, stats and the Totals row, a reload.
M.level = 12
M.talentTrees = { [1] = "Arcane", [2] = "Fire", [3] = "Frost" }
M.spellNames[11069], M.spellNames[11210], M.spellNames[11071] = "Improved Fireball", "Arcane Subtlety", "Frostbite"
M.talentConfig = 7001
M.loadouts[7001] = {
	[101] = { spellID = 11069, tree = 2, rank = 2, max = 5 },
	[102] = { spellID = 11210, tree = 1, rank = 0, max = 2 },
	[103] = { spellID = 11071, tree = 3, rank = 0, max = 3 },
}
local talents = M.loadouts[7001]
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
local function Apply()
	M.fire("TRAIT_CONFIG_UPDATED", M.talentConfig)
	M.fire("PLAYER_TALENT_UPDATE")
end

-- Points already spent at the first login are remembered, not logged.
check(TravelLogCharDB.talents[7001][101] == 2 and TravelLogCharDB.talents[7001][102] == nil, "talents remembered")
check(count("talent") == 0 and count("talentreset") == 0 and not ns.stats.talents, "existing talents not logged")

-- A point at the next level.
M.level = 13
talents[101].rank = 3
Apply()
local t = last("talent")
check(count("talent") == 1 and t.name == "Improved Fireball" and t.id == 11069 and t.tree == "Fire"
	and t.rank == 3 and t.max == 5 and t.level == 13 and not t.points, "talent logged once")
check(t.zone == "Elwynn Forest" and t.x, "stamped with where")
check(ns.Describe(t) == "Talent: Improved Fireball 3/5 (Fire) at level 13", "described: " .. ns.Describe(t))
check(ns.stats.talents == 1, "point counted")

-- Placed in the talent frame but not applied yet: nothing until Apply.
talents[102].rank = 1
M.talentsStaged = true
M.fire("PLAYER_TALENT_UPDATE")
check(count("talent") == 1, "staged point not logged")
M.talentsStaged = false
Apply()
check(count("talent") == 2 and last("talent").name == "Arcane Subtlety" and last("talent").tree == "Arcane"
	and last("talent").rank == 1 and last("talent").max == 2, "applied point logged")

-- Two ranks of one talent applied together: one entry, both points counted.
talents[103].rank = 2
Apply()
check(count("talent") == 3 and last("talent").rank == 2 and last("talent").points == 2, "two ranks in one entry")
check(ns.stats.talents == 4, "both points counted: " .. tostring(ns.stats.talents))

-- After a reload nothing is logged again.
ns = M.Reload()
check(TravelLogCharDB.talents[7001][101] == 3 and TravelLogCharDB.talents[7001][103] == 2, "talents saved")
check(count("talent") == 3 and count("talentreset") == 0, "nothing new after reload")

-- The second spec has its own talents: switching to it, and back, logs nothing.
M.loadouts[7002] = {
	[101] = { spellID = 11069, tree = 2, rank = 0, max = 5 },
	[102] = { spellID = 11210, tree = 1, rank = 0, max = 2 },
	[103] = { spellID = 11071, tree = 3, rank = 3, max = 3 },
}
M.talentConfig = 7002
M.fire("ACTIVE_TALENT_GROUP_CHANGED", 2, 1)
check(count("talent") == 3 and count("talentreset") == 0, "spec switch not logged")
check(TravelLogCharDB.talents[7002][103] == 3, "second spec remembered")
M.loadouts[7002][101].rank = 1
Apply()
check(count("talent") == 4 and last("talent").name == "Improved Fireball" and last("talent").rank == 1, "point in the second spec")
M.talentConfig = 7001
M.fire("ACTIVE_TALENT_GROUP_CHANGED", 1, 2)
check(count("talent") == 4 and count("talentreset") == 0, "switching back not logged")

-- A respec applied in one go: the refund first, then the new point.
local before = #TravelLogCharDB.log
talents[103].rank = 0
talents[102].rank = 2
Apply()
local reset = last("talentreset")
check(count("talentreset") == 1 and reset.points == 2 and reset.spent == 5 and reset.level == 13, "refund logged")
check(TravelLogCharDB.log[before + 1] == reset and TravelLogCharDB.log[before + 2] == last("talent")
	and last("talent").name == "Arcane Subtlety", "refund before the new point")
check(ns.Describe(reset) == "Unlearned talents: 2 points back at level 13", "refund described: " .. ns.Describe(reset))

-- Every point taken back.
talents[101].rank, talents[102].rank = 0, 0
Apply()
reset = last("talentreset")
check(count("talentreset") == 2 and reset.points == 5 and reset.spent == 0, "reset logged")
check(ns.Describe(reset) == "Reset talents: 5 points back at level 13", "reset described: " .. ns.Describe(reset))
check(ns.stats.talents == 6, "refunds don't count as points: " .. tostring(ns.stats.talents))

-- A name the client won't reveal is left out; the spell ID is kept.
M.secrets["Frostbite"] = true
talents[103].rank = 1
Apply()
check(last("talent").name == nil and last("talent").id == 11071, "secret name skipped")
check(ns.Describe(last("talent")) == "Talent: 11071 1/3 (Frost) at level 13", "described by ID: " .. ns.Describe(last("talent")))

-- Without a loadout yet (early at login) nothing is touched.
M.talentConfig = nil
Apply()
check(TravelLogCharDB.talents[7001][103] == 1, "no loadout, no change")
M.talentConfig = 7001

-- History's Progress group, search, /tl log and /tl stats.
local first
for _, e in ipairs(TravelLogCharDB.log) do first = first or (e.type == "talent" and e) end
check(ns.LogGroup(first) == "Progress" and ns.LogGroup(reset) == "Progress", "Progress group")
check(ns.LogTypeLabel(first) == "Talent" and ns.LogTypeLabel(reset) == "Talent reset", "labels")
check(ns.LogMatches(first, "talent fire", "Progress") and ns.LogMatches(reset, "talent reset", "Progress"), "History search")
M.out = {}
SlashCmdList.TRAVELLOG("log 2 talent")
local out = table.concat(M.out, "\n")
check(out:find("Reset talents: 5 points back at level 13", 1, true) and out:find("Talent: 11071 1/3 (Frost)", 1, true), "/tl log: " .. out)
M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("Spells learned .*") end
check(line and line:find("talent points 7", 1, true), "stats line: " .. tostring(line))

-- The Totals tab's Learned row (Path's Colors tab has a "Learned" too).
ns.Toggle()
local all = M.descendants(ns.window.pages[1])
local learned
for i, r in ipairs(all) do
	if r.kind == "FontString" and r:GetText() == "Learned" then learned = all[i + 1]:GetText() end
end
check(learned == "0 spells, 0 skills, 0 skill points, 7 talent points", "Learned row: " .. tostring(learned))
