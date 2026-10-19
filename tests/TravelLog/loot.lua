-- Loot sources and roll wins. Remembered chests and gathering nodes are
-- TravelLog_Nodes' (tests/TravelLog_Nodes).
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

--------------------------------------------------------------------------------
-- What opened the loot window
--------------------------------------------------------------------------------

-- A combat spell that finished seconds before looting a corpse isn't "via"
local WOLF = "Creature-0-1-0-1-299-0000AAAA"
M.units.target = { name = "Young Wolf", guid = WOLF, hostile = true }
M.cast(133, "Young Wolf") -- Fireball
M.advance(3)
M.loot = { { name = "Ruined Pelt", link = "[Ruined Pelt]", qty = 1, guid = WOLF } }
M.lootAll()
check(last("loot").source == "Young Wolf" and last("loot").via == nil, "a kill's loot has no gathering spell")

-- Skinning the same corpse right after is
M.cast(8613, "Young Wolf")
M.loot = { { name = "Light Leather", link = "[Light Leather]", qty = 1, guid = WOLF } }
M.lootAll()
check(last("loot").via == "Skinning", "second loot of a corpse after a cast is skinning")
M.units.target = nil

-- A crate that opens without a cast gets no stale name from an old cast
M.cast(133, "Young Wolf")
M.advance(5)
M.loot = { { name = "Apple", link = "[Apple]", qty = 1, guid = "GameObject-0-1-0-1-777-0000C0DE" } }
M.lootAll()
check(last("loot").source == nil and last("loot").via == nil and last("loot").sourceID == 777, "no cast, no name")

--------------------------------------------------------------------------------
-- Roll wins
--------------------------------------------------------------------------------

M.advance(30)
local SWORD = "|cff1eff00|Hitem:2488::::|h[Gladius]|h|r"

-- Roll event first, then the chat line: one entry
M.fire("LOOT_ITEM_ROLL_WON", SWORD, 1, 2, 87, false)
M.fire("CHAT_MSG_LOOT", "You receive loot: " .. SWORD .. ".")
check(count("receive") == 1 and last("receive").how == "roll" and last("receive").roll == 87, "roll win logged once (event first)")

-- Chat line first, then the roll event: still one entry, marked as a roll
M.advance(30)
local AXE = "|cff1eff00|Hitem:2489::::|h[Axe]|h|r"
M.fire("CHAT_MSG_LOOT", "You receive loot: " .. AXE .. ".")
M.fire("LOOT_ITEM_ROLL_WON", AXE, 1, 1, 12, false)
check(count("receive") == 2 and last("receive").how == "roll" and last("receive").roll == 12, "roll win logged once (chat first)")
check(ns.stats.received.roll == 2 and (ns.stats.received.loot or 0) == 0, "roll stats")

-- In a dungeon the chat line is hidden, the roll event still records it
M.advance(30)
local RING = "|cff0070dd|Hitem:2490::::|h[Ring]|h|r"
M.secrets["You receive loot: " .. RING .. "."] = true
M.fire("LOOT_ITEM_ROLL_WON", RING, 1, 1, 99, false)
M.fire("CHAT_MSG_LOOT", "You receive loot: " .. RING .. ".")
check(count("receive") == 3 and last("receive").item == RING, "roll win recorded despite hidden chat")

M.out = {}
SlashCmdList.TRAVELLOG("log 1")
check(table.concat(M.out, "\n"):find("won with a roll of 99"), "log shows the roll")
