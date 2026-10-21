-- Progress while leveling: spells from a trainer and a recipe, new skills and
-- skill milestones, a flight path and a reputation standing, and a reload.
M.skills = {
	{ name = "Weapon Skills", isHeader = true },
	{ skillID = 43, name = "Swords", rank = 22 },
	{ skillID = 98, name = "Language: Common", rank = 300 },
}
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

-- The skills you have at the first login are remembered, not logged.
check(TravelLogCharDB.skills[43] == 22 and TravelLogCharDB.skills[98] == 300, "skills remembered")
check(count("skill") == 0 and count("skillup") == 0, "existing skills not logged")

-- Two ranks of a spell from a trainer, each reported by the event and in chat.
M.units.npc = { name = "Jennea Cannon", guid = "Creature-0-1-0-1-5497-0000" }
M.fire("TRAINER_SHOW")
M.spellNames[8400], M.spellRanks[8400] = "Fireball", "Rank 5"
M.spellNames[8401], M.spellRanks[8401] = "Fireball", "Rank 6"
M.fire("LEARNED_SPELL_IN_SKILL_LINE", 8400, 2, false)
M.fire("CHAT_MSG_SYSTEM", "You have learned a new spell: |cff71d5ff|Hspell:8400:0|h[Fireball]|h|r.")
M.fire("LEARNED_SPELL_IN_SKILL_LINE", 8401, 2, false)
M.fire("CHAT_MSG_SYSTEM", "You have learned a new spell: |cff71d5ff|Hspell:8401:0|h[Fireball]|h|r.")
M.fire("TRAINER_CLOSED")
check(count("spell") == 2, "each rank logged once: " .. count("spell"))
local spell = last("spell")
check(spell.id == 8401 and spell.name == "Fireball" and spell.rank == "Rank 6" and spell.trainer == "Jennea Cannon",
	"spell with rank and trainer")
check(spell.zone == "Elwynn Forest" and spell.x, "stamped with where")
check(ns.Describe(spell) == "Learned Fireball (Rank 6) from Jennea Cannon", "described: " .. ns.Describe(spell))

-- A recipe from a recipe item: only the chat line, and no trainer open.
M.advance(10)
M.fire("CHAT_MSG_SYSTEM", "You have learned how to create a new item: |cff71d5ff|Hspell:2545:0|h[Linen Bandage]|h|r.")
check(count("spell") == 3 and last("spell").id == 2545 and last("spell").name == "Linen Bandage"
	and not last("spell").trainer, "recipe from chat")
check(ns.stats.spells == 3, "spells counted")

-- Guild perks aren't yours.
M.fire("LEARNED_SPELL_IN_SKILL_LINE", 9999, 1, true)
check(count("spell") == 3, "guild perk skipped")

-- A new skill, a skill-up below a milestone and one past it.
table.insert(M.skills, { skillID = 129, name = "First Aid", rank = 1 })
M.fire("SKILL_LINES_CHANGED")
check(count("skill") == 1 and last("skill").name == "First Aid" and last("skill").rank == 1, "new skill logged")
M.skills[2].rank = 24
M.fire("SKILL_LINES_CHANGED")
check(count("skillup") == 0, "no milestone yet")
M.skills[2].rank = 26
M.fire("SKILL_LINES_CHANGED")
check(count("skillup") == 1 and last("skillup").name == "Swords" and last("skillup").rank == 26, "milestone at 25")
check(ns.Describe(last("skillup")) == "Swords reached 26", "skill-up described")
check(ns.stats.skills == 1 and ns.stats.skillups == 4, "skills and points counted")

-- A collapsed header hides its skills; showing them again isn't news.
local swords = table.remove(M.skills, 2)
M.fire("SKILL_LINES_CHANGED")
table.insert(M.skills, 2, swords)
M.fire("SKILL_LINES_CHANGED")
check(count("skill") == 1, "skill shown again not logged")

-- A flight path, shown on screen and in chat.
M.units.npc = { name = "Thor", guid = "Creature-0-1-0-1-523-0000" }
M.fire("UI_INFO_MESSAGE", 0, "New flight path discovered!")
M.fire("CHAT_MSG_SYSTEM", "New flight path discovered!")
check(count("taxipath") == 1 and last("taxipath").npc == "Thor", "flight path logged once")
check(ns.Describe(last("taxipath")) == "Found the flight path at Thor", "flight path described")

-- A reputation standing.
M.fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "You are now Friendly with Stormwind.")
M.fire("CHAT_MSG_SYSTEM", "You are now Friendly with Stormwind.")
check(count("standing") == 1 and last("standing").faction == "Stormwind" and last("standing").standing == "Friendly",
	"standing logged once")
check(ns.Describe(last("standing")) == "Now Friendly with Stormwind", "standing described")

-- Secret chat (in a dungeon) is skipped.
M.secrets["You are now Honored with Stormwind."] = true
M.fire("CHAT_MSG_SYSTEM", "You are now Honored with Stormwind.")
check(count("standing") == 1, "secret chat skipped")

-- After a reload the skills are still known, so nothing is logged again.
ns = M.Reload()
check(TravelLogCharDB.skills[129] == 1 and TravelLogCharDB.skills[43] == 26, "skills saved")
check(count("skill") == 1 and count("skillup") == 1, "nothing new after reload")
M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("Spells learned .*") end
check(line == "Spells learned 3, new skills 1, skill points 4, flight paths found 1", "stats line: " .. tostring(line))
