-- Instance resets and lockouts: lockouts at the first login remembered
-- without logging, a new one after a boss kill and after the "now saved"
-- line, an extended and an expired one, a reload, a secret name; resets that
-- worked and failed; stats, /tl log, the Instances row and a reload.
M.saves = {
	{ name = "Molten Core", id = 1001, reset = 86400, difficulty = 9, locked = true, isRaid = true,
		maxPlayers = 40, difficultyName = "40 Player" },
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

-- The first login remembers what you're saved to.
M.tick(2)
check(M.raidInfoRequests == 1, "lockouts asked for at login")
check(count("lockout") == 0, "lockouts at the first login aren't logged")
check(TravelLogCharDB.lockouts["Molten Core:9:1001"] == M.now + 86400, "first login's lockout remembered")

-- A boss kill saves you; TravelLog asks a few seconds later.
M.instance, M.instanceInfo = "party", { name = "The Deadmines", difficultyName = "Normal", maxPlayers = 5, instanceID = 36 }
M.zone, M.subzone, M.x, M.wa = "The Deadmines", "", nil, nil
M.fire("PLAYER_ENTERING_WORLD", false, false)
M.tick(2)
local asked = M.raidInfoRequests
M.fire("ENCOUNTER_END", 2969, "Sneed", 1, 5, 0, {})
M.tick(5)
check(M.raidInfoRequests == asked, "a wipe doesn't ask")
table.insert(M.saves, { name = "The Deadmines", id = 2002, reset = 3600, difficulty = 1, locked = true,
	maxPlayers = 5, difficultyName = "Normal" })
M.fire("ENCOUNTER_END", 2969, "Sneed", 1, 5, 1, {})
M.fire("BOSS_KILL", 2969, "Sneed")
M.tick(5)
check(M.raidInfoRequests == asked + 1, "a kill asks once")
local lock = last("lockout")
check(count("lockout") == 1 and lock and lock.name == "The Deadmines" and lock.lockout == 2002, "new lockout logged")
check(lock.kind == "dungeon" and lock.difficulty == "Normal" and lock.size == 5, "lockout's kind, difficulty and size")
check(lock.resets == M.now - 1 + 3600 and lock.zone == "The Deadmines", "lockout's reset time and place")
check(ns.Describe(lock) == "Saved to The Deadmines (dungeon, Normal), ID 2002, resets " .. date("%Y-%m-%d %H:%M", lock.resets),
	"lockout described: " .. ns.Describe(lock))

-- Asking again lists the same lockouts: nothing new. Extending one isn't new.
M.saves[1].extended, M.saves[1].reset = true, 86400 * 8
RequestRaidInfo()
M.tick(2)
check(count("lockout") == 1, "known and extended lockouts aren't logged again")

-- The "now saved" line asks too; an expired lockout that's still listed isn't
-- news, and a secret name is skipped.
table.insert(M.saves, { name = "Zul'Gurub", id = 3003, reset = 0, difficulty = 3, locked = false, isRaid = true,
	maxPlayers = 20, difficultyName = "20 Player" })
M.secrets["Onyxia's Lair"] = true
table.insert(M.saves, { name = "Onyxia's Lair", id = 4004, reset = 3600, difficulty = 9, locked = true, isRaid = true })
asked = M.raidInfoRequests
M.chat("CHAT_MSG_SYSTEM", "You are now saved to this instance")
M.tick(3)
check(M.raidInfoRequests == asked + 1 and count("lockout") == 1, "now saved line asks; expired and secret ones skipped")

-- After a reload nothing is new.
ns = M.Reload()
M.tick(2)
check(count("lockout") == 1 and TravelLogCharDB.lockouts["The Deadmines:1:2002"], "kept across a reload")

-- The dungeon resets an hour later: a new run is a new lockout ID.
M.instance = nil
M.zone, M.subzone, M.x, M.y, M.wa, M.wb = "Westfall", "Moonbrook", 0.4, 0.7, -10000, 1500
table.remove(M.saves, 2)
M.tick(3600)
RequestRaidInfo()
M.tick(2)
check(not TravelLogCharDB.lockouts["The Deadmines:1:2002"], "a lockout gone and past its reset is forgotten")
check(TravelLogCharDB.lockouts["Zul'Gurub:3:3003"], "an expired one still listed is remembered")
table.insert(M.saves, { name = "The Deadmines", id = 2003, reset = 3600, difficulty = 1, locked = true,
	maxPlayers = 5, difficultyName = "Normal" })
RequestRaidInfo()
M.tick(2)
check(count("lockout") == 2 and last("lockout").lockout == 2003, "the next run's lockout logged")

-- Resets: the game's line names the instance; failures say why.
M.chat("CHAT_MSG_SYSTEM", "The Deadmines has been reset.")
local reset = last("instancereset")
check(reset and reset.name == "The Deadmines" and not reset.failed and reset.zone == "Westfall", "reset logged")
check(ns.Describe(reset) == "Reset The Deadmines", "reset described")
M.chat("CHAT_MSG_SYSTEM", "Cannot reset Shadowfang Keep.  There are players still inside the instance.")
M.chat("CHAT_MSG_SYSTEM", "Cannot reset Razorfen Kraul.  There are players offline in your party.")
M.chat("CHAT_MSG_SYSTEM", "Cannot reset Wailing Caverns.  There are players in your party attempting to zone into an instance.")
check(count("instancereset") == 4 and last("instancereset").failed == "zoning", "failed resets logged")
check(ns.Describe(last("instancereset")) == "Couldn't reset Wailing Caverns: players entering an instance", "failed reset described")
local failed = {}
for _, e in ipairs(TravelLogCharDB.log) do
	if e.type == "instancereset" and e.failed then failed[#failed + 1] = e.name .. "=" .. e.failed end
end
check(table.concat(failed, ",") == "Shadowfang Keep=inside,Razorfen Kraul=offline,Wailing Caverns=zoning", "failure reasons")
M.secrets["Stratholme has been reset."] = true
M.chat("CHAT_MSG_SYSTEM", "Stratholme has been reset.")
M.chat("CHAT_MSG_SYSTEM", "You have joined the guild.")
check(count("instancereset") == 4, "secret and other lines ignored")

-- Counted, under Travel, in /tl stats, /tl log and the window.
local st = ns.stats
check(st.instanceResets == 1 and st.lockouts == 2, "counted: " .. tostring(st.instanceResets) .. " " .. tostring(st.lockouts))
check(ns.LogGroup(reset) == "Travel" and ns.LogTypeLabel(reset) == "Instance reset", "reset's group and label")
check(ns.LogGroup(lock) == "Travel" and ns.LogTypeLabel(lock) == "Lockout", "lockout's group and label")
M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("Hearths .*") end
check(line and line:find("instance resets 1, lockouts 2,", 1, true), "stats line: " .. tostring(line))
M.out = {}
SlashCmdList.TRAVELLOG("log 1 lockout")
check(#M.out == 2 and M.out[2]:find("Saved to The Deadmines (dungeon, Normal), ID 2003", 1, true), "/tl log: " .. tostring(M.out[2]))
SlashCmdList.TRAVELLOG("")
local values = {}
for _, fs in ipairs(M.descendants(TravelLogFrame.pages[1])) do values[#values + 1] = fs.text end
local all = table.concat(values, "\n")
check(all:find(", 1 resets, 2 lockouts", 1, true), "Instances row: " .. all)

ns = M.Reload()
check(ns.stats.lockouts == 2 and count("instancereset") == 4, "kept after a reload")
