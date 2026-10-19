-- TravelLog Kills: kills from PARTY_KILL and the XP chat line, per mob, with
-- when and where; commands, tooltips and a reload.
M.installed = { "TravelLog", "TravelLog_Kills" }
M.Login()
local ns = M.ns("TravelLog_Kills")
check(TravelLogKillsDB and TravelLogKillsDB.total == 0, "starts empty")

local ME = UnitGUID("player")
local function Kobold(n) return "Creature-0-1-2-3-257-" .. n end
local function XP(name, xp) M.fire("CHAT_MSG_COMBAT_XP_GAIN", ("%s dies, you gain %d experience."):format(name, xp)) end

-- A kill that gives XP: PARTY_KILL, then the chat line. Saved once, with both.
M.units.target = { name = "Kobold Worker", guid = Kobold(1), hostile = true }
M.fire("PARTY_KILL", ME, Kobold(1))
XP("Kobold Worker", 45)
local mob = TravelLogKillsDB.mobs["Kobold Worker"]
check(mob and mob.count == 1, "kill saved once with both halves")
check(mob and mob.ids[1] == 257, "NPC ID kept")
local k = mob and ns.UnpackKill(mob.kills[1])
check(k and k.time == M.now and k.xp == 45 and k.map == 1429, "time, xp and map")
check(k and k.zone == "Elwynn Forest" and k.subzone == "Goldshire", "zone and subzone")
check(k and math.abs(k.x - 42) < 0.01 and math.abs(k.y - 65) < 0.01, "coordinates")
check(k and not k.by, "your own kill has no 'by'")

-- The same GUID again (a repeated event) isn't a second kill.
M.fire("PARTY_KILL", ME, Kobold(1))
M.tick(3)
check(mob.count == 1, "repeated PARTY_KILL ignored")

-- A grey mob: no XP line, so it's saved after a short wait. The unit is gone
-- by then, but its name was remembered from the target.
M.units.target = { name = "Kobold Worker", guid = Kobold(2), hostile = true }
M.fire("PLAYER_TARGET_CHANGED")
M.units.target = nil
M.x, M.y, M.subzone = 0.40, 0.70, "Fargodeep Mine"
M.fire("PARTY_KILL", ME, Kobold(2))
check(mob.count == 1, "waits for an XP line")
M.tick(3)
check(mob.count == 2, "saved without XP after the wait")
k = ns.UnpackKill(mob.kills[2])
check(k.subzone == "Fargodeep Mine" and not k.xp, "second kill's place, no xp")
check(#TravelLogKillsDB.places == 2, "places stored once each")

-- The XP line first, then PARTY_KILL: still one kill.
M.guidNames["Creature-0-1-2-3-299-9"] = "Diseased Young Wolf"
XP("Diseased Young Wolf", 30)
M.fire("PARTY_KILL", ME, "Creature-0-1-2-3-299-9")
local wolf = TravelLogKillsDB.mobs["Diseased Young Wolf"]
check(wolf and wolf.count == 1 and wolf.ids[1] == 299, "XP line before PARTY_KILL")
check(wolf and ns.UnpackKill(wolf.kills[1]).xp == 30, "xp kept")

-- Two kills at once (AoE): each XP line goes to its own mob.
M.guidNames[Kobold(3)] = "Kobold Worker"
M.guidNames["Creature-0-1-2-3-299-10"] = "Diseased Young Wolf"
M.fire("PARTY_KILL", ME, Kobold(3))
M.fire("PARTY_KILL", ME, "Creature-0-1-2-3-299-10")
XP("Diseased Young Wolf", 31)
XP("Kobold Worker", 44)
check(mob.count == 3 and ns.UnpackKill(mob.kills[3]).xp == 44, "AoE: kobold got its own xp")
check(wolf.count == 2 and ns.UnpackKill(wolf.kills[2]).xp == 31, "AoE: wolf got its own xp")

-- A party member's killing blow is recorded with who did it; your pet's isn't.
M.units.party1 = { name = "Friend", guid = "Player-1-Friend" }
M.guidNames[Kobold(4)] = "Kobold Worker"
M.fire("PARTY_KILL", "Player-1-Friend", Kobold(4))
XP("Kobold Worker", 22)
check(ns.UnpackKill(mob.kills[4]).by == "Friend", "party member's kill has 'by'")
M.units.pet = { name = "Wolfie", guid = "Pet-0-1-2-3-4-5" }
M.guidNames[Kobold(5)] = "Kobold Worker"
M.fire("PARTY_KILL", "Pet-0-1-2-3-4-5", Kobold(5))
M.tick(3)
check(mob.count == 5 and not ns.UnpackKill(mob.kills[5]).by, "pet's kill counts as yours")
M.units.party1, M.units.pet = nil, nil

-- Inside an instance the GUID can be secret: the XP line still names it.
local secret = "Creature-0-1-2-3-46-1"
M.secrets[secret] = true
M.x, M.y = nil, nil
M.fire("PARTY_KILL", ME, secret)
XP("Murloc Forager", 50)
local murloc = TravelLogKillsDB.mobs["Murloc Forager"]
check(murloc and murloc.count == 1 and not murloc.ids, "secret GUID: named by the XP line")
check(murloc and not ns.UnpackKill(murloc.kills[1]).x, "no coordinates inside")
-- With neither a GUID nor an XP line there's nothing to record.
M.fire("PARTY_KILL", ME, secret)
M.tick(3)
check(TravelLogKillsDB.total == 8, "unnamed kill dropped")
M.x, M.y = 0.42, 0.65

-- Tooltips show the count on mobs you've killed, not on others.
M.guidNames[Kobold(99)] = "Kobold Worker"
M.units.mouseover = { name = "Kobold Worker", guid = Kobold(99), hostile = true }
local lines = M.hover("mouseover")
check(lines[2] and lines[2]:find("Killed 5 times") ~= nil, "tooltip: " .. tostring(lines[2]))
M.units.mouseover = { name = "Stranger", guid = "Creature-0-1-2-3-1-1", hostile = true }
check(#M.hover("mouseover") == 1, "no tooltip line for unknown mobs")
M.units.mouseover = nil

-- Commands.
local function Run(msg)
	M.out = {}
	SlashCmdList.TRAVELLOGKILLS(msg)
	return table.concat(M.out, "\n")
end
local text = Run("")
check(text:find("8 kills of 3 different mobs") and text:find("Kobold Worker: 5"), "/kills top")
text = Run("kobold worker")
check(text:find("killed 5 times") and text:find("Elwynn Forest / Fargodeep Mine %(4%), Elwynn Forest / Goldshire %(1%)") and text:find("by Friend"), "/kills <name>")
text = Run("wolf")
check(text:find("Diseased Young Wolf: killed 2 times"), "/kills finds a partial name")
text = Run("o")
check(text:find("3 mobs match"), "/kills lists several matches")
text = Run("recent 3")
check(text:find("Last 3 kills") and text:find("Murloc Forager"), "/kills recent")
M.units.target = { name = "Diseased Young Wolf", guid = "Creature-0-1-2-3-299-77", hostile = true }
check(Run("target"):find("Diseased Young Wolf: killed 2 times"), "/kills target")
check(Run("nothing like it"):find("no kills"), "/kills with no match")

-- Kills waiting at logout are saved, and everything survives a reload.
M.guidNames["Creature-0-1-2-3-299-11"] = "Diseased Young Wolf"
M.fire("PARTY_KILL", ME, "Creature-0-1-2-3-299-11")
M.Reload()
ns = M.ns("TravelLog_Kills")
check(TravelLogKillsDB.total == 9 and TravelLogKillsDB.mobs["Diseased Young Wolf"].count == 3, "saved over a reload")
check(ns.Mob(nil, 257) and ns.Mob(nil, 257).name == "Kobold Worker", "NPC ID index rebuilt")
check(#M.tooltipPostCalls[Enum.TooltipDataType.Unit] == 1, "tooltip hook registered once after reload")
M.guidNames[Kobold(6)] = "Kobold Worker"
M.fire("PARTY_KILL", ME, Kobold(6))
XP("Kobold Worker", 40)
check(TravelLogKillsDB.mobs["Kobold Worker"].count == 6 and #TravelLogKillsDB.places == 2, "keeps recording after reload")

-- Wipe.
SlashCmdList.TRAVELLOGKILLS("wipe confirm")
check(TravelLogKillsDB == nil and M.reloadRequested, "wipe")

-- Works without TravelLog too.
M.Logout()
M.installed = { "TravelLog_Kills" }
M.saved, M.savedChar = {}, {}
for _, name in ipairs(M.installed) do C_AddOns.LoadAddOn(name) end
M.fire("PLAYER_LOGIN")
M.guidNames[Kobold(7)] = "Kobold Worker"
M.fire("PARTY_KILL", ME, Kobold(7))
M.tick(3)
check(TravelLogKillsDB.total == 1, "works on its own")
