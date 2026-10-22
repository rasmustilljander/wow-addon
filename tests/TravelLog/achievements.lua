-- Legacy Challenges (achievements): one earned with points, category and
-- reward, one already earned on another character, a guild one, one the
-- client knows nothing about, a secret name; History, /tl log, /tl stats, the
-- Totals row and a reload.
M.achievementCategories = { [92] = { name = "General" }, [96] = { name = "Quests" }, [15088] = { name = "Guild" } }
M.achievements = {
	[6] = { name = "Level 10", points = 10, category = 92 },
	[503] = { name = "50 Quests Completed", points = 10, category = 96, reward = "Reward: Title - the Seeker" },
	[4860] = { name = "Guild Level 2", points = 0, category = 15088, guild = true },
}
local ns = M.Login()

local function last(kind)
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == kind then return log[i] end
	end
end
local function count()
	local n = 0
	for _, e in ipairs(TravelLogCharDB.log) do if e.type == "achievement" then n = n + 1 end end
	return n
end

M.fire("ACHIEVEMENT_EARNED", 6, false)
local e = last("achievement")
check(count() == 1 and e.id == 6 and e.name == "Level 10" and e.points == 10 and e.category == "General"
	and not e.reward and not e.already and not e.guild, "earned")
check(e.zone == "Elwynn Forest" and e.x, "stamped with where")
check(ns.Describe(e) == "Legacy Challenge: Level 10 (10 points, General)", "described: " .. ns.Describe(e))

-- Earned before on another character, with a reward.
M.fire("ACHIEVEMENT_EARNED", 503, true)
e = last("achievement")
check(count() == 2 and e.already and e.reward == "Reward: Title - the Seeker", "already earned, reward")
check(ns.Describe(e) == "Legacy Challenge: 50 Quests Completed (10 points, Quests, already earned on another character); Reward: Title - the Seeker",
	"described: " .. ns.Describe(e))

-- A guild one, worth no points.
M.fire("ACHIEVEMENT_EARNED", 4860)
e = last("achievement")
check(count() == 3 and e.guild and not e.points and not e.already, "guild achievement")
check(ns.Describe(e) == "Legacy Challenge: Guild Level 2 (Guild, guild)", "described: " .. ns.Describe(e))

-- One the client has no info for still gets its ID.
M.fire("ACHIEVEMENT_EARNED", 9999, false)
e = last("achievement")
check(count() == 4 and e.id == 9999 and not e.name and not e.category, "unknown achievement")
check(ns.Describe(e) == "Legacy Challenge: 9999", "described: " .. ns.Describe(e))

-- A secret name is left out.
M.achievements[7] = { name = "Level 20", points = 10, category = 92 }
M.secrets["Level 20"] = true
M.fire("ACHIEVEMENT_EARNED", 7, false)
e = last("achievement")
check(count() == 5 and e.id == 7 and not e.name and e.points == 10, "secret name left out")
M.secrets["Level 20"] = nil

check(ns.stats.achievements == 5 and ns.stats.achievementPoints == 30, "counted: " .. tostring(ns.stats.achievementPoints))
check(ns.LogGroup(e) == "Progress" and ns.LogTypeLabel(e) == "Legacy Challenge", "group and label")

M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("Legacy Challenges: .*") end
check(line == "Legacy Challenges: 5 earned, 30 points", "stats line: " .. tostring(line))
M.out = {}
SlashCmdList.TRAVELLOG("log 5 seeker")
check(#M.out == 2 and M.out[2]:find("50 Quests Completed", 1, true), "/tl log finds the reward")

SlashCmdList.TRAVELLOG("")
local values = {}
for _, fs in ipairs(M.descendants(TravelLogFrame.pages[1])) do values[#values + 1] = fs.text end
check(table.concat(values, "\n"):find("Legacy Challenges\n5 earned, 30 points", 1, true), "Totals row")

ns = M.Reload()
check(count() == 5 and last("achievement").id == 7 and ns.stats.achievementPoints == 30, "kept after a reload")
