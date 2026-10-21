-- TravelLog Group: groups from the roster, per player, with when, how long,
-- where and kills together; reloads and logging out while grouped; commands,
-- tooltips and the Players tab.
M.installed = { "TravelLog", "TravelLog_Group" }
M.Login()
local ns = M.ns("TravelLog_Group")
check(TravelLogGroupDB and TravelLogGroupDB.total == 0, "starts empty")

local ANNA = { name = "Anna", guid = "Player-1-0A", class = "WARRIOR", level = 12, player = true }
local BOB = { name = "Bob", realm = "Storm Rage", guid = "Player-2-0B", class = "PRIEST", level = 30, player = true }
local function Roster(...)
	M.group, M.units.party1, M.units.party2 = {}, nil, nil
	for i, u in ipairs({ ... }) do
		M.group[i] = "party" .. i
		M.units["party" .. i] = u
	end
	M.fire("GROUP_ROSTER_UPDATE")
end
local start = M.now

-- Anna joins: a group starts, with where and her level.
Roster(ANNA)
local anna = TravelLogGroupDB.players["Anna-Forever"]
check(anna and anna.count == 1 and anna.class == "WARRIOR" and anna.guid == "Player-1-0A", "Anna recorded")
check(TravelLogGroupDB.open["Anna-Forever"] and TravelLogGroupDB.total == 1, "her group is open")
check(ns.Display(anna) == "Anna", "own realm shown without it")

-- Kills while grouped count for everyone in the group; repeats and pets don't.
M.fire("PARTY_KILL", "Player-1-0A", "Creature-0-1-2-3-257-1")
M.fire("PARTY_KILL", "Player-1-0A", "Creature-0-1-2-3-257-1")
M.fire("PARTY_KILL", "Player-1-Rasmus", "Pet-0-1-2-3-4-5")
check(TravelLogGroupDB.open["Anna-Forever"].kills == 1, "one kill together")

-- Bob from another realm joins 10 minutes later in Westfall.
M.advance(600)
M.zone, M.subzone = "Westfall", "Moonbrook"
Roster(ANNA, BOB)
local bob = TravelLogGroupDB.players["Bob-StormRage"]
check(bob and ns.Display(bob) == "Bob-StormRage", "other realm kept in the name")
check(anna.count == 1, "a roster change doesn't restart Anna's group")
M.fire("PARTY_KILL", "Player-1-Rasmus", "Creature-0-1-2-3-299-1")
check(TravelLogGroupDB.open["Anna-Forever"].kills == 2 and TravelLogGroupDB.open["Bob-StormRage"].kills == 1, "kills per group")

-- Anna leaves after an hour: her group is written down.
M.advance(3000)
Roster(BOB)
check(not TravelLogGroupDB.open["Anna-Forever"], "Anna's group closed")
local g = ns.UnpackGroup(anna.groups[1])
check(g.start == start and g.seconds == 3600 and g.kills == 2 and g.level == 12 and not g.raid, "group: " .. anna.groups[1])
check(g.zone == "Elwynn Forest" and g.subzone == "Goldshire", "where it started")
check(anna.time == 3600 and anna.kills == 2 and anna.last == M.now, "her totals")

-- Someone still loading ("Unknown") or hidden ends nobody's group.
M.advance(60)
Roster({ name = "Unknown", guid = "Player-1-0C" })
check(TravelLogGroupDB.open["Bob-StormRage"] and not TravelLogGroupDB.players["Unknown-Forever"], "an unreadable roster keeps groups")
M.secrets["Bob"] = true
Roster(BOB)
check(TravelLogGroupDB.open["Bob-StormRage"], "a secret name keeps groups")
M.secrets["Bob"] = nil

-- Later, a raid with both again.
M.advance(1200)
Roster()
check(next(TravelLogGroupDB.open) == nil and bob.count == 1, "leaving the group ends every group")
M.advance(3600)
M.raid, M.group = true, { "raid1", "raid2" }
M.units.raid1, M.units.raid2 = ANNA, BOB
M.fire("GROUP_ROSTER_UPDATE")
check(anna.count == 2 and ns.UnpackGroup(anna.groups[2]).raid, "raid group")

-- A reload while grouped keeps the group going.
M.advance(300)
M.Reload()
ns = M.ns("TravelLog_Group")
anna = TravelLogGroupDB.players["Anna-Forever"]
check(anna.count == 2 and TravelLogGroupDB.open["Anna-Forever"], "same group after a reload")
M.tick(15)
check(TravelLogGroupDB.open["Anna-Forever"] and ns.TimeWith(anna) == 3600 + 315, "still going: " .. ns.TimeWith(anna))

-- Logging out for longer: the group ended at logout, a new one starts.
M.Logout()
local out = M.now
M.advance(1800)
M.Login()
ns = M.ns("TravelLog_Group")
anna = TravelLogGroupDB.players["Anna-Forever"]
check(anna.count == 3 and ns.UnpackGroup(anna.groups[2]).seconds == 315, "ended at logout")
check(TravelLogGroupDB.open["Anna-Forever"].start == M.now, "new group after a long logout")

-- Bob left while you were offline: his ends at logout, once the roster settles.
M.Logout()
out = M.now
M.advance(120)
M.group, M.units.raid2 = { "raid1" }, nil
M.Login()
ns = M.ns("TravelLog_Group")
anna, bob = TravelLogGroupDB.players["Anna-Forever"], TravelLogGroupDB.players["Bob-StormRage"]
check(TravelLogGroupDB.open["Bob-StormRage"], "not ended before the roster settles")
M.tick(10)
check(not TravelLogGroupDB.open["Bob-StormRage"] and bob.last == out and bob.count == 3, "Bob's group ended at logout")
check(anna.count == 3 and TravelLogGroupDB.open["Anna-Forever"], "Anna's resumed")
M.raid, M.group, M.units.raid1 = false, {}, nil
M.fire("GROUP_ROSTER_UPDATE")
check(anna.count == 3 and #anna.groups == 3 and next(TravelLogGroupDB.open) == nil, "all closed")

-- Tooltips on players you've grouped with.
M.units.mouseover = { name = "Anna", guid = "Player-1-0A", player = true }
local lines = M.hover("mouseover")
check(lines[2] and lines[2]:find("Grouped 3 times %(") and lines[2]:find("last under a minute ago"), "tooltip: " .. tostring(lines[2]))
M.units.mouseover = { name = "Stranger", guid = "Player-1-0D", player = true }
check(#M.hover("mouseover") == 1, "no line for strangers")
M.units.mouseover = nil

-- Commands.
local function Run(msg)
	M.out = {}
	SlashCmdList.TRAVELLOGGROUP(msg)
	return table.concat(M.out, "\n")
end
local text = Run("")
check(text:find("grouped 6 times with 2 different players") and text:find("Anna: 3 times"), "/grouped: " .. text)
text = Run("anna")
check(text:find("Anna %(Warrior%): grouped 3 times") and text:find("2 kills together") and text:find("Last 3:")
	and text:find("Elwynn Forest / Goldshire, 2 kills, level 12"), "/grouped <name>: " .. text)
check(Run("storm"):find("Bob%-StormRage %(Priest%): grouped 3 times"), "/grouped finds a partial name or realm")
check(Run("r"):find("2 players match"), "/grouped lists several matches")
check(Run("recent 2"):find("Last 2 groups"), "/grouped recent")
M.units.target = BOB
check(Run("target"):find("Bob%-StormRage %(Priest%): grouped 3 times"), "/grouped target")
M.units.target = nil
check(Run("nobody"):find("haven't grouped"), "/grouped with no match")

-- The Players tab: everyone, searchable; a click shows each group.
Roster(ANNA)
check(Run("window") == "", "/grouped window")
local w = M.ns("TravelLog").window
local page = w.pages[3]
check(w:IsShown() and w.Tabs[3]:GetText() == "Players" and page:IsShown(), "opens on the Players tab")
local function Rows(list, a, b)
	local out = {}
	for _, row in ipairs(M.shown(list.rows)) do out[#out + 1] = row[a]:GetText() .. " " .. row[b]:GetText() end
	return table.concat(out, ", ")
end
check(Rows(page.players, "name", "count") == "Anna 4, Bob-StormRage 3", "players: " .. Rows(page.players, "name", "count"))
check(page.found:GetText() == "2 players, 7 groups", "count: " .. page.found:GetText())
check(page.players.rows[1].name.textColor[1] == 0.78, "class colored")
check(page.hint:GetText():find("Click a player") and Rows(page.groups, "when", "length") == "", "nothing picked yet")
page.search:SetText("STORM")
check(Rows(page.players, "name", "count") == "Bob-StormRage 3", "search: " .. Rows(page.players, "name", "count"))
page.search:SetText("")
page.players.rows[1]:Click()
check(page.title:GetText() == "Anna" and page.summary:GetText():find("^4 times, ") and page.last:GetText() == "In your group now, 2 kills",
	"picked: " .. page.summary:GetText() .. " / " .. page.last:GetText())
local rows = M.shown(page.groups.rows)
check(#rows == 4 and rows[1].length:GetText():find("under a minute") and rows[4].length:GetText() == "1h 0m", "groups, newest first")
check(rows[4].when:GetText() == date("%Y-%m-%d %H:%M", start) and rows[4].where:GetText() == "Elwynn Forest / Goldshire, 2 kills, level 12",
	"oldest: " .. rows[4].where:GetText())
check(rows[3].where:GetText():find("raid$"), "raid marked")
-- The running group grows while the window is open.
M.advance(600)
for _ = 1, 70 do M.frame() end
check(M.shown(page.groups.rows)[1].length:GetText():find("10m"), "running group updates")

-- Wipe.
SlashCmdList.TRAVELLOGGROUP("wipe confirm")
check(TravelLogGroupDB == nil and M.reloadRequested, "wipe")

-- Works without TravelLog too.
M.Logout()
M.installed = { "TravelLog_Group" }
M.saved, M.savedChar = {}, {}
TravelLog = nil -- the fake keeps addon globals across logins
for _, name in ipairs(M.installed) do C_AddOns.LoadAddOn(name) end
M.fire("PLAYER_LOGIN")
Roster(ANNA)
check(TravelLogGroupDB.total == 1, "works on its own")
check(Run("window"):find("needs TravelLog"), "no window without TravelLog")
