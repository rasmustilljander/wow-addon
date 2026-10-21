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

-- Map pins: one per spot on the zone map, sized by the count, with a tooltip.
local function Pins()
	M.frame()
	return M.shown(ns.mapOverlay.children)
end
local function PinAt(x, y)
	for _, pin in ipairs(Pins()) do
		if math.abs(pin.point[4] - x * 10) < 0.5 and math.abs(pin.point[5] + y * 6.67) < 0.5 then return pin end
	end
end
check(#Pins() == 2, "a pin per kill spot: " .. #Pins())
local mine = PinAt(40, 70)
check(mine and mine.count == 6, "Fargodeep spot has 6 kills")
check(mine and mine.mouse and mine.mouseClicks == false, "pins take hover but let clicks through")
local single = PinAt(42, 65)
check(single and single.count == 1 and single.w < mine.w, "pins grow with the count")
local before = mine.w
WorldMapFrame.scale = 2
M.advance(1)
check(math.abs(PinAt(40, 70).w - before / 2) < 0.01, "pins keep their screen size when zoomed")
WorldMapFrame.scale = 1
M.advance(1)
M.frame()
mine.scripts.OnEnter(mine)
local tip = table.concat(GameTooltip.lines, "\n")
check(tip:find("6 kills here") and tip:find("Kobold Worker  4") and tip:find("Diseased Young Wolf  2"), "pin tooltip: " .. tip)
check(tip:find("Kobold Worker") < tip:find("Diseased Young Wolf"), "most killed first")
mine.scripts.OnLeave(mine)
check(not GameTooltip.shown, "tooltip hides")

-- A new kill shows up on the open map.
M.x, M.y = 0.55, 0.30
M.guidNames[Kobold(50)] = "Kobold Worker"
M.fire("PARTY_KILL", ME, Kobold(50))
M.tick(3)
check(#Pins() == 3, "new kill spot appears on the open map")
M.x, M.y = 0.42, 0.65

-- Only on the zone's own map.
M.viewMap = 1415
check(#Pins() == 0, "no pins on the continent map")
M.viewMap = 1429

-- One mob only, then off, then all again.
check(Run("map wolf"):find("only Diseased Young Wolf"), "/kills map <name>")
check(#Pins() == 1 and Pins()[1].count == 2, "only the wolf's spot, with its count")
Pins()[1].scripts.OnEnter(Pins()[1])
check(not table.concat(GameTooltip.lines, "\n"):find("Kobold"), "filtered tooltip lists only that mob")
check(Run("map o"):find("3 mobs match") and TravelLogKillsDB.settings.mapFilter == "Diseased Young Wolf", "ambiguous name keeps the filter")
M.units.target = { name = "Kobold Worker", guid = Kobold(60), hostile = true }
check(Run("map target"):find("only Kobold Worker") and #Pins() == 3, "/kills map target")
check(Run("map off"):find("off") and #Pins() == 0, "/kills map off")
check(Run("map on"):find("all kills") and #Pins() == 3, "/kills map on")

-- Kills waiting at logout are saved, and everything survives a reload.
M.guidNames["Creature-0-1-2-3-299-11"] = "Diseased Young Wolf"
M.fire("PARTY_KILL", ME, "Creature-0-1-2-3-299-11")
M.Reload()
ns = M.ns("TravelLog_Kills")
check(TravelLogKillsDB.total == 10 and TravelLogKillsDB.mobs["Diseased Young Wolf"].count == 3, "saved over a reload")
check(ns.Mob(nil, 257) and ns.Mob(nil, 257).name == "Kobold Worker", "NPC ID index rebuilt")
check(#M.tooltipPostCalls[Enum.TooltipDataType.Unit] == 1, "tooltip hook registered once after reload")
check(#Pins() == 3, "pins rebuilt from the saved kills")
M.guidNames[Kobold(6)] = "Kobold Worker"
M.fire("PARTY_KILL", ME, Kobold(6))
XP("Kobold Worker", 40)
check(TravelLogKillsDB.mobs["Kobold Worker"].count == 7 and #TravelLogKillsDB.places == 2, "keeps recording after reload")

-- The Kills tab in TravelLog's window: every mob, searchable; a click shows
-- the zones it died in.
check(Run("window") == "", "/kills window")
local w = M.ns("TravelLog").window
local page = w.pages[3]
check(w:IsShown() and w.selectedTab == 3 and page:IsShown(), "opens on the Kills tab")
-- The shown rows of a list, as "name count".
local function Rows(list)
	local out = {}
	for _, row in ipairs(M.shown(list.rows)) do out[#out + 1] = row.name:GetText() .. " " .. row.count:GetText() end
	return table.concat(out, ", ")
end
check(Rows(page.mobs) == "Kobold Worker 7, Diseased Young Wolf 3, Murloc Forager 1", "mobs, most first: " .. Rows(page.mobs))
check(page.found:GetText() == "3 mobs, 11 kills", "count: " .. page.found:GetText())
check(page.hint:GetText():find("Click a mob") and Rows(page.zones) == "", "nothing picked yet")
page.search:SetText("WO")
check(Rows(page.mobs) == "Kobold Worker 7, Diseased Young Wolf 3", "search: " .. Rows(page.mobs))
check(page.found:GetText() == "2 of 3 mobs", "found: " .. page.found:GetText())
page.mobs.rows[2]:Click()
check(page.title:GetText() == "Diseased Young Wolf" and page.summary:GetText():find("^3 kills, last "), "picked: " .. page.summary:GetText())
check(page.mobs.rows[2].selected:IsShown() and not page.mobs.rows[1].selected:IsShown(), "picked row marked")
check(Rows(page.zones) == "Elwynn Forest 3" and page.hint:GetText() == "", "zones: " .. Rows(page.zones))
-- A kill elsewhere shows up while the window is open.
M.zone, M.subzone = "Westfall", "Moonbrook"
M.guidNames["Creature-0-1-2-3-299-12"] = "Diseased Young Wolf"
M.fire("PARTY_KILL", ME, "Creature-0-1-2-3-299-12")
M.tick(3)
for _ = 1, 70 do M.frame() end
check(Rows(page.zones) == "Elwynn Forest 3, Westfall 1", "new zone: " .. Rows(page.zones))
check(Rows(page.mobs) == "Kobold Worker 7, Diseased Young Wolf 4", "new count: " .. Rows(page.mobs))
page.search.clearButton:Click()
check(page.found:GetText() == "3 mobs, 12 kills" and page.title:GetText() == "Diseased Young Wolf", "search cleared, pick kept")
M.zone, M.subzone = "Elwynn Forest", "Goldshire"

-- Wipe.
SlashCmdList.TRAVELLOGKILLS("wipe confirm")
check(TravelLogKillsDB == nil and M.reloadRequested, "wipe")

-- Works without TravelLog too.
M.Logout()
M.installed = { "TravelLog_Kills" }
M.saved, M.savedChar = {}, {}
TravelLog = nil -- the fake keeps addon globals across logins
for _, name in ipairs(M.installed) do C_AddOns.LoadAddOn(name) end
M.fire("PLAYER_LOGIN")
M.guidNames[Kobold(7)] = "Kobold Worker"
M.fire("PARTY_KILL", ME, Kobold(7))
M.tick(3)
check(TravelLogKillsDB.total == 1, "works on its own")
check(Run("window"):find("needs TravelLog"), "no window without TravelLog")
