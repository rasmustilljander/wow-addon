-- Items used up: a potion with its cast, the same one again (one entry),
-- ammo with no cast seen, reagents, crafts with the "You create" line before
-- or after their materials go, and what isn't use (sales, the bank, a
-- destroy, a quest turn-in or abandon, gear put on, an item held on the
-- cursor, a bag put on, a loading screen, many items vanishing at once).
-- What a boss fight used, across a reload. Stats, /tl log, the History
-- group, a reload.
local POTION = "|cffffffff|Hitem:929::::|h[Healing Potion]|h|r"
local ARROW = "|cffffffff|Hitem:2512::::|h[Rough Arrow]|h|r"
local CLOTH = "|cffffffff|Hitem:2589::::|h[Linen Cloth]|h|r"
local BANDAGE = "|cffffffff|Hitem:1251::::|h[Linen Bandage]|h|r"
local RUNE = "|cffffffff|Hitem:17031::::|h[Rune of Teleportation]|h|r"
local SWORD = "|cff1eff00|Hitem:2488::::|h[Gladius]|h|r"
local BREAD = "|cffffffff|Hitem:4540::::|h[Tough Hunk of Bread]|h|r"
local QUESTITEM = "|cffffffff|Hitem:752::::|h[Red Burlap Bandana]|h|r"
local ORE = "|cffffffff|Hitem:2770::::|h[Copper Ore]|h|r"
local PELT = "|cffffffff|Hitem:4865::::|h[Ruined Pelt]|h|r"
M.spellNames[441] = "Healing Potion"
M.spellNames[3275] = "Linen Bandage"
M.spellNames[3561] = "Teleport: Stormwind"
M.items[2488] = { equipLoc = "INVTYPE_WEAPON" }
M.items[2512] = { equipLoc = "INVTYPE_AMMO" }

M.bags["0:1"] = { link = POTION, count = 5 }
M.bags["0:2"] = { link = ARROW, count = 200 }
M.bags["0:3"] = { link = CLOTH, count = 10 }
M.bags["0:4"] = SWORD
M.bags["0:5"] = { link = RUNE, count = 2 }
M.bags["0:6"] = { link = BREAD, count = 10 }
M.bags["0:7"] = QUESTITEM
local ns = M.Login()
M.fire("PLAYER_ENTERING_WORLD", true, false)

local function count(kind)
	local n = 0
	for _, e in ipairs(TravelLogCharDB.log) do if e.type == kind then n = n + 1 end end
	return n
end
local function last(kind)
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == kind then return log[i] end
	end
end
local function Log(n, search)
	M.out = {}
	SlashCmdList.TRAVELLOG("log " .. n .. (search and " " .. search or ""))
	return table.concat(M.out, "\n")
end
local function bags()
	M.fire("BAG_UPDATE_DELAYED")
end

--------------------------------------------------------------------------------
-- Used up
--------------------------------------------------------------------------------

-- A potion with its cast: logged a moment later, in case it was a craft.
M.cast(441)
M.bags["0:1"].count = 4
bags()
check(count("use") == 0, "waits a moment for a craft line")
M.tick(1)
local use = last("use")
check(count("use") == 1 and use.item == POTION and use.count == 1 and use.spell == "Healing Potion" and use.spellID == 441,
	"potion used, with its spell")
check(Log(1):find("Used " .. POTION .. " (Healing Potion)", 1, true), "log shows the potion")

-- The same again soon after adds to that entry.
M.tick(10)
M.cast(441)
M.bags["0:1"].count = 3
bags()
M.tick(1)
check(count("use") == 1 and use.count == 2, "second potion added to the entry")

-- Arrows going one by one with no cast seen (hidden in combat): one entry.
M.tick(5)
for _ = 1, 3 do
	M.bags["0:2"].count = M.bags["0:2"].count - 1
	bags()
	M.tick(2)
end
use = last("use")
check(count("use") == 2 and use.item == ARROW and use.count == 3 and not use.spell, "ammo used, one entry")
check(Log(1):find("Used " .. ARROW .. "x3", 1, true), "log shows the arrows")

-- Long after, the same item is a new entry.
M.tick(60)
M.bags["0:2"].count = 196
bags()
check(count("use") == 3 and last("use").count == 1, "a new entry after a while")

-- A reagent: the spell is the one that took it.
M.cast(3561)
M.bags["0:5"].count = 1
bags()
M.tick(1)
check(last("use").item == RUNE and last("use").spell == "Teleport: Stormwind", "reagent used by its spell")

--------------------------------------------------------------------------------
-- Crafts
--------------------------------------------------------------------------------

-- The materials go, then "You create" comes: they're the craft's.
local uses = count("use")
M.cast(3275)
M.bags["0:3"].count = 8
M.bags["0:8"] = BANDAGE
bags()
M.fire("CHAT_MSG_LOOT", "You create: " .. BANDAGE .. ".")
M.tick(2)
local made = last("receive")
check(made and made.how == "created" and made.item == BANDAGE and made.materials and #made.materials == 1
	and made.materials[1].item == CLOTH and made.materials[1].count == 2, "craft's materials")
check(count("use") == uses, "materials aren't a use entry")
check(Log(1, "Linen Bandage"):find("Received " .. BANDAGE .. " (created from " .. CLOTH .. "x2)", 1, true),
	"log shows the materials")

-- "You create" first, then the materials.
M.cast(3275)
M.fire("CHAT_MSG_LOOT", "You create: " .. BANDAGE .. ".")
M.bags["0:3"].count = 6
M.bags["0:8"] = { link = BANDAGE, count = 2 }
bags()
M.tick(2)
made = last("receive")
check(made.materials and made.materials[1].count == 2 and count("use") == uses, "materials after the line")

--------------------------------------------------------------------------------
-- Not used up
--------------------------------------------------------------------------------

uses = count("use")

-- Sold at a vendor.
M.units.npc = { name = "Brother Danil" }
M.fire("MERCHANT_SHOW")
M.bags["0:6"].count = 9
bags()
M.fire("MERCHANT_CLOSED")
check(count("use") == uses, "sale isn't use")

-- Put in the bank.
M.fire("BANKFRAME_OPENED")
M.bags["0:6"].count = 8
bags()
M.fire("BANKFRAME_CLOSED")
check(count("use") == uses, "bank deposit isn't use")

-- Destroyed.
C_Container.PickupContainerItem(0, 6)
DeleteCursorItem()
bags()
check(last("destroy") and count("use") == uses, "destroyed isn't use")
M.tick(5)

-- Gear put on.
M.bags["0:4"] = nil
M.equip(16, SWORD)
bags()
check(count("use") == uses, "gear put on isn't use")

-- A quest's items taken at turn-in.
M.bags["0:9"] = { link = ORE, count = 5 }
bags()
GetQuestReward(1)
M.bags["0:9"] = nil
bags()
check(count("use") == uses, "quest items handed in aren't use")
M.tick(10)

-- A quest's items taken when you abandon it.
M.questLog = { 54 }
C_QuestLog.SetSelectedQuest(54)
C_QuestLog.SetAbandonQuest()
C_QuestLog.AbandonQuest()
M.bags["0:7"] = nil
bags()
check(count("use") == uses, "quest items of an abandoned quest aren't use")
M.tick(10)

-- Held on the cursor and put back.
M.bags["0:10"] = { link = PELT, count = 4 }
bags()
C_Container.SplitContainerItem(0, 10, 2)
M.bags["0:10"].count = 2
bags()
M.bags["0:10"].count = 4
ClearCursor()
bags()
check(count("use") == uses, "item held on the cursor isn't use")

-- A bag taken off with its items, or one not readable yet.
M.equipBag(1, "|cffffffff|Hitem:4496::::|h[Small Brown Pouch]|h|r", 6)
M.bags["1:1"] = { link = ORE, count = 3 }
bags()
M.bags["1:1"] = nil
M.equipBag(1, nil)
bags()
check(count("use") == uses, "bag taken off isn't use")

-- Many items vanishing at once with no cast.
M.bags["0:11"] = ORE
M.bags["0:12"] = { link = PELT, count = 1 }
M.bags["0:13"] = BANDAGE
bags()
M.bags["0:5"], M.bags["0:8"], M.bags["0:10"], M.bags["0:11"], M.bags["0:12"] = nil, nil, nil, nil, nil
bags()
check(count("use") == uses, "several items gone at once isn't use")

--------------------------------------------------------------------------------
-- Boss fights
--------------------------------------------------------------------------------

M.instance, M.instanceInfo = "party", { name = "The Deadmines", difficultyName = "Normal", maxPlayers = 5, instanceID = 36 }
M.zone, M.subzone, M.x, M.wa = "The Deadmines", "", nil, nil
M.fire("PLAYER_ENTERING_WORLD", false, false)
M.fire("ENCOUNTER_START", 2972, "Edwin VanCleef", 1, 5)
M.cast(441)
M.bags["0:1"].count = 2
bags()
M.tick(1)
ns = M.Reload()
M.fire("PLAYER_ENTERING_WORLD", false, true)
M.tick(5)
M.bags["0:1"].count = 1
bags()
M.bags["0:13"] = nil
bags()
M.fire("ENCOUNTER_END", 2972, "Edwin VanCleef", 1, 5, 1, {})
local boss = last("boss")
check(boss.used and #boss.used == 2 and boss.used[1].item == POTION and boss.used[1].count == 2
	and boss.used[2].item == BANDAGE and boss.used[2].count == 1, "boss fight's items, across a reload")
check(Log(1, "VanCleef"):find("Killed Edwin VanCleef in 0:06 (Normal, 5 players); used " .. POTION .. "x2, " .. BANDAGE, 1, true),
	"log shows what the fight used: " .. Log(1, "VanCleef"))
M.fire("ENCOUNTER_START", 2973, "Cookie", 1, 5)
M.fire("ENCOUNTER_END", 2973, "Cookie", 1, 5, 1, {})
check(not last("boss").used, "a fight using nothing has no list")

--------------------------------------------------------------------------------
-- Totals, History and a reload
--------------------------------------------------------------------------------

local used = ns.stats.used
check(used.items == 2 + 4 + 1 + 1 + 2 and used.crafting == 4, "used counted: " .. tostring(used.items) .. ", " .. tostring(used.crafting))
M.out = {}
SlashCmdList.TRAVELLOG("stats")
check(table.concat(M.out, "\n"):find("Items used: 14, 4 of them in crafts", 1, true), "/tl stats line")
check(ns.LogGroup(last("use")) == "Loot" and ns.LogTypeLabel(last("use")) == "Used", "History group and label")
ns = M.Reload()
check(last("use").item == BANDAGE and last("receive").materials, "kept across a reload")
