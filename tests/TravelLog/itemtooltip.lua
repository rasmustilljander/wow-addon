-- Item tooltips: when, where and how you first got a rare or better item
-- (looted, fished, a roll win, mail, bought), how often, kept up to date as
-- the log grows, a reload and an alt.
local ns = M.Login()

local function Link(id, name, color) return ("|cff%s|Hitem:%d::::|h[%s]|h|r"):format(color or "0070dd", id, name) end
local function Tip(id) return table.concat(M.hoverItem(id), "\n") end
local function Day() return date("%Y-%m-%d", M.now) end

local BLADE = Link(2042, "Staff of Westfall")
local CLOTH = Link(2589, "Linen Cloth", "ffffff")
local RING = Link(2043, "Ring of Forlorn Spirits", "a335ee")
M.items[2042] = { quality = 3, link = BLADE }
M.items[2589] = { quality = 1, link = CLOTH }
M.items[2043] = { quality = 4, link = RING }

check(not Tip(2042):find("First"), "nothing before you've got it")

-- Looted from a mob in Westfall
M.mapID, M.zone, M.subzone = 1436, "Westfall", "Moonbrook"
local THUG = "Creature-0-1-0-1-116-0000BBBB"
M.units.target = { name = "Defias Thug", guid = THUG, hostile = true, dead = true }
M.loot = { { name = "Staff of Westfall", link = BLADE, qty = 1, guid = THUG },
	{ name = "Linen Cloth", link = CLOTH, qty = 2, guid = THUG } }
M.lootAll()
M.units.target = nil
local firstDay = Day()
local tip = Tip(2042)
check(tip:find("First looted " .. firstDay .. " from Defias Thug, Westfall", 1, true), "first looted: " .. tip)
check(not tip:find("Got %d+ times"), "no count for one")
check(not Tip(2589):find("First"), "nothing for common items")

-- An unknown quality (not cached yet) shows nothing
M.items[2042].uncached = true
check(not Tip(2042):find("First"), "nothing while the item isn't cached")
M.items[2042].uncached = nil

-- Got again later, from fishing elsewhere: the first stays, the count grows
M.advance(3 * 86400)
M.mapID, M.zone, M.subzone = 1429, "Elwynn Forest", "Goldshire"
M.fishing = true
M.loot = { { name = "Staff of Westfall", link = BLADE, qty = 1 } }
M.lootAll()
M.fishing = false
tip = Tip(2042)
check(tip:find("First looted " .. firstDay .. " from Defias Thug, Westfall", 1, true), "still the first: " .. tip)
check(tip:find("Got 2 times", 1, true), "count: " .. tip)

-- A roll win, then by mail and bought: each counts once
M.advance(86400)
M.fire("LOOT_ITEM_ROLL_WON", RING, 1, 2, 87, false)
M.fire("CHAT_MSG_LOOT", "You receive loot: " .. RING .. ".")
local rollDay = Day()
tip = Tip(2043)
check(tip:find("First won " .. rollDay .. " in Elwynn Forest (rolled 87)", 1, true), "roll win: " .. tip)
check(not tip:find("Got %d+ times"), "a roll seen twice counts once")

M.inbox = { { sender = "Anduin", items = { { link = RING } } } }
M.fire("MAIL_SHOW")
AutoLootMailItem(1)
M.fire("CHAT_MSG_LOOT", "You receive item: " .. RING .. ".")
M.fire("MAIL_CLOSED")
check(Tip(2043):find("Got 2 times", 1, true), "mail counted")

M.units.npc = { name = "Brother Danil", guid = "Creature-0-1-0-1-152-0000" }
M.merchantItems[1] = { name = "Ring of Forlorn Spirits", price = 5000, stackCount = 1, link = RING }
M.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.Merchant)
M.fire("MERCHANT_SHOW")
BuyMerchantItem(1)
M.bags["0:1"] = { link = RING, count = 1 }
M.fire("BAG_UPDATE_DELAYED")
M.fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.Merchant)
M.units.npc = nil
check(Tip(2043):find("Got 3 times", 1, true), "purchase counted: " .. Tip(2043))

-- Only bought: from the vendor
M.items[2044] = { quality = 3, link = Link(2044, "Ironforge Breastplate") }
M.mapID, M.zone, M.subzone = 1453, "Stormwind City", "Old Town"
ns.Log("buy", { item = M.items[2044].link, count = 1, price = 100, vendor = "Brother Danil" })
check(Tip(2044):find("First bought " .. Day() .. " from Brother Danil, Stormwind City", 1, true), "bought: " .. Tip(2044))

-- Got by mail first: the sender
M.items[2045] = { quality = 3, link = Link(2045, "Rare Gem") }
M.inbox = { { sender = "Jaina", items = { { link = M.items[2045].link } } } }
M.fire("MAIL_SHOW")
AutoLootMailItem(1)
M.fire("CHAT_MSG_LOOT", "You receive item: " .. M.items[2045].link .. ".")
M.fire("MAIL_CLOSED")
check(Tip(2045):find("First got by mail " .. Day() .. " from Jaina, Stormwind City", 1, true), "mail: " .. Tip(2045))

-- Other entries with the item (sold, given away) don't count
ns.Log("sell", { item = BLADE, count = 1, price = 100, vendor = "Brother Danil" })
ns.Log("destroy", { item = BLADE, count = 1 })
check(Tip(2042):find("Got 2 times", 1, true), "sales and destroys don't count")

-- After a reload the index is built again from the saved log
ns = M.Reload()
tip = Tip(2042)
check(tip:find("First looted " .. firstDay .. " from Defias Thug, Westfall", 1, true) and tip:find("Got 2 times", 1, true),
	"after a reload: " .. tip)
check(Tip(2043):find("Got 3 times", 1, true), "roll, mail and purchase after a reload")

-- Another character's log isn't loaded
M.Logout()
M.player = { name = "Alt", realm = "Forever" }
ns = M.Login()
check(not Tip(2042):find("First") and not Tip(2043):find("First"), "nothing on an alt")
