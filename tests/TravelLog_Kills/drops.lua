-- TravelLog Kills: what each mob dropped, from the loot windows of its
-- corpses; tooltips, /kills <name> and a reload.
M.installed = { "TravelLog", "TravelLog_Kills" }
M.Login()
local ns = M.ns("TravelLog_Kills")

local function Kobold(n) return "Creature-0-1-2-3-257-" .. n end
local function Link(id, name, color) return ("|cff%s|Hitem:%d::::::::|h[%s]|h|r"):format(color or "ffffff", id, name) end
local LINEN, CANDLE, PICK = Link(2589, "Linen Cloth"), Link(772, "Large Candle"), Link(2901, "Mining Pick", "1eff00")
local function Coins() return { name = "12 Copper", qty = 0, type = 2 } end

-- Loots kobold n with these slots; coins and items from that corpse.
local function Loot(n, slots, take)
	M.guidNames[Kobold(n)] = "Kobold Worker"
	M.units.mouseover = { name = "Kobold Worker", guid = Kobold(n), hostile = true, dead = true }
	for _, s in ipairs(slots) do s.guid = s.guid or Kobold(n) end
	M.loot = slots
	M.lootAll(take)
	M.units.mouseover = nil
end

-- What's in the window counts, taken or not, once per corpse.
Loot(1, { { name = "Linen Cloth", link = LINEN, qty = 2 }, Coins() }, {})
local d = TravelLogKillsDB.drops["Kobold Worker"]
check(d and d.looted == 1, "corpse counted once (LOOT_READY and LOOT_OPENED)")
check(d and d.items[2589][1] == 1 and d.items[2589][2] == 2, "item counted with its stack, even if left")
check(TravelLogKillsDB.items[2589] == LINEN, "item link kept")
Loot(1, { { name = "Linen Cloth", link = LINEN, qty = 2 } })
check(d.looted == 1 and d.items[2589][2] == 2, "reopening a corpse adds nothing")

Loot(2, { Coins() })
check(d.looted == 2 and d.items[2589][1] == 1, "a corpse with only coins counts as looted")
Loot(3, { { name = "Linen Cloth", link = LINEN, qty = 1 }, { name = "Large Candle", link = CANDLE, qty = 1 } })
Loot(4, { { name = "Mining Pick", link = PICK, qty = 1 } })

-- One window holding two corpses: each gets its own share.
M.guidNames[Kobold(5)], M.guidNames[Kobold(6)] = "Kobold Worker", "Kobold Worker"
M.loot = {
	{ name = "Linen Cloth", link = LINEN, qty = 3, sources = { Kobold(5), 1, Kobold(6), 2 } },
	{ name = "Large Candle", link = CANDLE, qty = 1, guid = Kobold(6) },
}
M.lootAll()
check(d.looted == 6 and d.items[2589][1] == 4 and d.items[2589][2] == 6, "merged window: per corpse")
check(d.items[772][1] == 2, "merged window: candle on one corpse")

-- Not corpses: a pickpocket, a chest, fishing, a skinned corpse.
local THUG = "Creature-0-1-2-3-116-1"
M.guidNames[THUG] = "Defias Thug"
M.units.target = { name = "Defias Thug", guid = THUG, hostile = true }
M.loot = { { name = "Linen Cloth", link = LINEN, qty = 1, guid = THUG } }
M.lootAll()
check(not TravelLogKillsDB.drops["Defias Thug"], "pickpocketing isn't a drop")
M.units.target.dead = true
M.lootAll()
check(TravelLogKillsDB.drops["Defias Thug"].looted == 1, "its corpse later is")
M.units.target = nil
M.loot = { { name = "Linen Cloth", link = LINEN, qty = 1, guid = "GameObject-0-1-2-3-1617-1" } }
M.lootAll()
M.fishing = true
M.loot = { { name = "Raw Brilliant Smallfish", link = Link(6291, "Raw Brilliant Smallfish"), qty = 1, guid = "GameObject-0-1-2-3-1-2" } }
M.lootAll()
M.fishing = false
Loot(3, { { name = "Ruined Leather Scraps", link = Link(2934, "Ruined Leather Scraps"), qty = 1 } })
check(d.looted == 6 and not d.items[2934], "skinning a looted corpse adds nothing")

-- No source info: the dead creature under the mouse.
M.guidNames[Kobold(7)] = "Kobold Worker"
M.units.mouseover = { name = "Kobold Worker", guid = Kobold(7), hostile = true, dead = true }
M.loot = { { name = "Large Candle", link = CANDLE, qty = 1, guid = false } }
M.lootAll()
M.units.mouseover = nil
check(d.looted == 7 and d.items[772][1] == 3, "falls back to the corpse under the mouse")

-- Tooltips: the top 5, most often first; also for mobs you haven't killed.
for i = 10, 14 do
	Loot(i, { { name = "Item " .. i, link = Link(9000 + i, "Item " .. i), qty = i == 10 and 3 or 1 } })
end
Loot(15, { { name = "Item 10", link = Link(9010, "Item 10"), qty = 3 } })
M.units.mouseover = { name = "Kobold Worker", guid = Kobold(99), hostile = true }
M.guidNames[Kobold(99)] = "Kobold Worker"
local lines = M.hover("mouseover")
check(lines[2] == "Looted 13 times, drops:", "tooltip header: " .. tostring(lines[2]))
check(lines[3] == "  Linen Cloth  31% x1.5" and lines[4] == "  Large Candle  23%", "most often first: " .. tostring(lines[3]))
check(lines[5] == "  Item 10  15% x3", "average stack: " .. tostring(lines[5]))
check(lines[6] == "  Mining Pick  8%" and #lines == 7, "five items: " .. table.concat(lines, " | "))
M.units.mouseover = nil

-- /kills <name> lists them too, as links.
M.fire("PARTY_KILL", UnitGUID("player"), Kobold(15))
M.tick(3)
M.out = {}
SlashCmdList.TRAVELLOGKILLS("kobold worker")
local text = table.concat(M.out, "\n")
check(text:find("Drops %(looted 13 times%): " .. LINEN:gsub("%p", "%%%0") .. " 31%%"), "/kills <name> drops: " .. text)

-- Saved over a reload.
M.Reload()
ns = M.ns("TravelLog_Kills")
d = TravelLogKillsDB.drops["Kobold Worker"]
check(d.looted == 13 and d.items[2589][2] == 6 and TravelLogKillsDB.items[2901] == PICK, "saved over a reload")
Loot(16, { { name = "Linen Cloth", link = LINEN, qty = 1 } })
check(d.looted == 14 and d.items[2589][1] == 5, "keeps recording after a reload")
