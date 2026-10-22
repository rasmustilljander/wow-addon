-- Failed quests: an escort that dies, a timer running out, a quest under a
-- collapsed header, logged once across log updates, a reload and an abandon,
-- and again when retaken; /tl log, /tl stats, /tl sessions and the Totals.
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
local function Said(text)
	for _, line in ipairs(M.out) do
		if line:find(text, 1, true) then return line end
	end
end
local function Accept(id, title)
	M.quests[id] = title
	M.fire("QUEST_ACCEPTED", id)
end

-- An escort quest in the log: nothing until it fails, then once.
Accept(70, "Escort Duty")
M.questLog = { "Elwynn Forest", 70 }
M.fire("QUEST_LOG_UPDATE")
check(count("questfail") == 0, "a quest in progress isn't failed")
M.failedQuests[70] = true
M.fire("QUEST_LOG_UPDATE")
local e = last("questfail")
check(count("questfail") == 1 and e.id == 70 and e.title == "Escort Duty" and e.reason == nil, "failed quest logged without a reason")
check(TravelLogCharDB.quests[70].failed == e.time, "failed time saved on the quest")
check(ns.stats.quests.failed == 1, "failure counted")
check(ns.Describe(e) == "Failed quest: Escort Duty", "failure described: " .. ns.Describe(e))
check(ns.LogTypeLabel(e) == "Quest failed" and ns.LogMatches(e, "failed", "Life"), "failure found under Life")
M.fire("QUEST_LOG_UPDATE")
M.fire("QUEST_LOG_UPDATE")
check(count("questfail") == 1, "later log updates don't log it again")

-- A timed quest under a collapsed header runs out of time.
M.advance(10)
Accept(71, "Rush Delivery")
M.questTimers[71] = { total = 300, started = GetTime() }
M.fire("QUEST_LOG_UPDATE")
M.advance(300)
M.failedQuests[71] = true
M.fire("QUEST_LOG_UPDATE")
e = last("questfail")
check(count("questfail") == 2 and e.id == 71 and e.reason == "time", "timed-out quest under a collapsed header logged with its reason")
check(ns.Describe(e) == "Failed quest: Rush Delivery (ran out of time)", "timeout described: " .. ns.Describe(e))

-- A timed escort that fails before its timer runs out has no reason.
Accept(72, "Timed Escort")
M.questTimers[72] = { total = 600, started = GetTime() }
M.questLog = { "Elwynn Forest", 70, 72 }
M.fire("QUEST_LOG_UPDATE")
M.advance(60)
M.failedQuests[72] = true
M.fire("QUEST_LOG_UPDATE")
check(count("questfail") == 3 and last("questfail").id == 72 and last("questfail").reason == nil, "early failure of a timed quest has no reason")

-- A quest that had already failed when TravelLog first saw it.
M.quests[80] = "Old Failure"
M.questLog = { "Elwynn Forest", 70, 72, "Westfall", 80 }
M.failedQuests[80] = true
M.fire("QUEST_LOG_UPDATE")
check(count("questfail") == 4 and last("questfail").title == "Old Failure", "failed quest found in the log")
check(TravelLogCharDB.quests[80].failed and not TravelLogCharDB.quests[80].accepted, "saved without an accept time")

-- Accepted now, under a collapsed header; it fails after the reload below.
Accept(90, "Hidden Away")

-- /tl stats, /tl log, /tl sessions and the Totals.
M.out = {}
SlashCmdList.TRAVELLOG("stats")
check(Said("quests done 0, failed 4,"), "/tl stats: " .. tostring(Said("Deaths")))
M.out = {}
SlashCmdList.TRAVELLOG("log 1 fail")
check(Said("Failed quest: Old Failure"), "/tl log describes it")
M.out = {}
SlashCmdList.TRAVELLOG("sessions")
check(Said("4 failed quests"), "/tl sessions: " .. tostring(Said("Now")))
ns.Toggle()
local shown
local all = M.descendants(ns.window)
for i, r in ipairs(all) do
	if r.kind == "FontString" and r:GetText() == "Quests" then shown = all[i + 1]:GetText() end
end
check(shown == "4 accepted, 0 done, 0 abandoned, 4 failed", "Totals: " .. tostring(shown))
ns.Toggle()

-- A reload doesn't log the failed quests again.
ns = M.Reload()
M.fire("QUEST_LOG_UPDATE")
check(count("questfail") == 4 and ns.stats.quests.failed == 4, "nothing logged again after a reload")
M.failedQuests[90] = true
M.fire("QUEST_LOG_UPDATE")
check(count("questfail") == 5 and last("questfail").title == "Hidden Away", "a quest accepted before the reload is checked by ID")

-- Abandoning a failed quest is an abandon, not another failure.
C_QuestLog.SetSelectedQuest(70)
C_QuestLog.SetAbandonQuest()
C_QuestLog.AbandonQuest()
M.questLog = { "Elwynn Forest", 72, "Westfall", 80 }
M.failedQuests[70] = nil
M.fire("QUEST_REMOVED", 70, false)
M.fire("QUEST_LOG_UPDATE")
check(count("questabandon") == 1 and count("questfail") == 5, "abandoning a failed quest logs an abandon only")
local saved = TravelLogCharDB.quests[70]
check(saved.failed and saved.abandoned and saved.abandoned >= saved.failed, "both times kept on the quest")

-- Taken again, it can fail again.
M.advance(30)
Accept(70, "Escort Duty")
M.questLog = { "Elwynn Forest", 70, 72, "Westfall", 80 }
M.fire("QUEST_LOG_UPDATE")
check(count("questfail") == 5, "a retaken quest isn't failed yet")
M.failedQuests[70] = true
M.fire("QUEST_LOG_UPDATE")
check(count("questfail") == 6 and last("questfail").id == 70 and ns.stats.quests.failed == 6, "a retaken quest fails again")

ns.Toggle()
all = M.descendants(ns.window)
for i, r in ipairs(all) do
	if r.kind == "FontString" and r:GetText() == "Quests" then shown = all[i + 1]:GetText() end
end
check(shown == "5 accepted, 0 done, 1 abandoned, 6 failed", "Totals after retaking: " .. tostring(shown))
ns.Toggle()

-- A secret quest ID in the log is skipped.
M.questLog = { "Elwynn Forest", 70, 72, "Westfall", 80, 99 }
M.secrets[99] = true
M.failedQuests[99] = true
M.fire("QUEST_LOG_UPDATE")
check(count("questfail") == 6, "secret quest ID skipped")
