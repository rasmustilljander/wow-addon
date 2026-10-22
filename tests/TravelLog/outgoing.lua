-- Items that leave your bags: given in a trade, mailed, put up for auction or
-- destroyed, with who got them, and items moved to and from the guild bank;
-- their stats, the log and History, a reload.
M.guild = { name = "Wanderers", rank = "Member", rankIndex = 3 }
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
local function Log(n)
	M.out = {}
	SlashCmdList.TRAVELLOG("log " .. n)
	return table.concat(M.out, "\n")
end

local BREAD = "|cffffffff|Hitem:4540::::|h[Tough Hunk of Bread]|h|r"
local CLOTH = "|cffffffff|Hitem:2589::::|h[Linen Cloth]|h|r"
local SWORD = "|cff1eff00|Hitem:2488:0:0:0:0:0:1017:0|h[Gladius of the Bear]|h|r"
local ORE = "|cffffffff|Hitem:2770::::|h[Copper Ore]|h|r"
local JUNK = "|cff9d9d9d|Hitem:4865::::|h[Ruined Pelt]|h|r"
local AXE = "|cffffffff|Hitem:2489::::|h[Axe]|h|r"

--------------------------------------------------------------------------------
-- Trades
--------------------------------------------------------------------------------

-- What's in your slots when the trade completes, with the partner. The
-- "will not be traded" slot and items taken back out don't count.
M.units.npc = { name = "Thrall", realm = "Orgrimmar" }
M.fire("TRADE_SHOW")
M.tradeItems[1] = { link = BREAD, count = 5 }
M.fire("TRADE_PLAYER_ITEM_CHANGED", 1)
M.tradeItems[2] = { link = CLOTH, count = 2 }
M.fire("TRADE_PLAYER_ITEM_CHANGED", 2)
M.tradeItems[7] = { link = AXE }
M.fire("TRADE_PLAYER_ITEM_CHANGED", 7)
M.tradeItems[2] = nil
M.fire("TRADE_PLAYER_ITEM_CHANGED", 2)
M.fire("TRADE_ACCEPT_UPDATE", 1, 0)
M.fire("TRADE_ACCEPT_UPDATE", 1, 1)
M.fire("TRADE_CLOSED")
M.units.npc = nil
check(count("give") == 0, "nothing given before the trade completes")
M.fire("UI_INFO_MESSAGE", 1, "Trade complete.")
local give = last("give")
check(give and give.partner == "Thrall-Orgrimmar" and #give.items == 1 and give.items[1].item == BREAD
	and give.items[1].count == 5, "traded items with the partner")
check(Log(1):find("Gave " .. BREAD .. "x5 to Thrall-Orgrimmar", 1, true), "log shows the trade")

-- A cancelled trade, or one where you only received, gives nothing.
M.tradeItems = {}
M.units.npc = { name = "Jaina" }
M.fire("TRADE_SHOW")
M.tradeItems[1] = { link = CLOTH, count = 3 }
M.fire("TRADE_PLAYER_ITEM_CHANGED", 1)
M.fire("TRADE_CLOSED")
M.tradeItems = {}
M.fire("TRADE_SHOW")
M.fire("TRADE_ACCEPT_UPDATE", 1, 1)
M.fire("TRADE_CLOSED")
M.fire("UI_INFO_MESSAGE", 1, "Trade complete.")
M.units.npc = nil
check(count("give") == 1, "cancelled and receive-only trades give nothing")
check(ns.stats.given.trade == 5, "traded items counted")

--------------------------------------------------------------------------------
-- Mail
--------------------------------------------------------------------------------

M.items[2589] = { link = CLOTH }
M.fire("MAIL_SHOW")

-- Attachments, logged once the mail has gone; its postage is paid to the
-- recipient.
M.sendItems = { { link = CLOTH, count = 20 }, nil, { link = BREAD } }
SendMail("Jaina", "cloth", "")
check(count("send") == 0, "not sent yet")
M.money = M.money - 60
M.fire("PLAYER_MONEY")
check(last("money").reason == "mail" and last("money").recipient == "Jaina" and not last("money").sender,
	"postage has the recipient")
M.fire("MAIL_SEND_SUCCESS")
local send = last("send")
check(send and send.recipient == "Jaina" and #send.items == 2 and send.items[1].item == CLOTH
	and send.items[1].count == 20 and send.items[2].item == "Tough Hunk of Bread" and send.items[2].count == 1,
	"mailed items with the recipient, by name when the client doesn't know the item yet")
check(Log(1):find("Mailed " .. CLOTH .. "x20, ", 1, true) and Log(1):find(" to Jaina", 1, true), "log shows the mail")

-- A failed mail, and money alone, mail no items.
M.sendItems = { { link = CLOTH, count = 5 } }
SendMail("Bob", "", "")
M.fire("MAIL_FAILED", 2589)
M.fire("MAIL_SEND_SUCCESS")
M.sendItems = {}
SendMail("Bob", "", "")
M.fire("MAIL_SEND_SUCCESS")
check(count("send") == 1, "failed mail and mail without items not logged")
check(ns.stats.given.mail == 21, "mailed items counted")

-- Mail money taken later still comes from its sender.
M.advance(30)
M.inbox = { { sender = "Anduin", money = 100 } }
TakeInboxMoney(1)
M.money = M.money + 100
M.fire("PLAYER_MONEY")
check(last("money").sender == "Anduin" and not last("money").recipient, "taken money has its sender")
M.fire("MAIL_CLOSED")

--------------------------------------------------------------------------------
-- Auctions
--------------------------------------------------------------------------------

M.fire("AUCTION_HOUSE_SHOW")

-- An item with bid and buyout, logged once the auction exists. Several
-- auctions from one post are one entry.
M.bags["0:3"] = SWORD
C_AuctionHouse.PostItem(ItemLocation:CreateFromBagAndSlot(0, 3), 2, 1, 5000, 12000)
check(count("post") == 0, "not posted yet")
M.fire("AUCTION_HOUSE_AUCTION_CREATED", 101)
M.fire("AUCTION_HOUSE_AUCTION_CREATED", 102)
local post = last("post")
check(count("post") == 1 and post.item == SWORD and post.count == 1 and post.bid == 5000 and post.buyout == 12000,
	"posted item with its prices")
check(Log(1):find("Posted " .. SWORD .. " at auction, buyout 1g 20s 0c, bid 50s 0c", 1, true), "log shows the auction")

-- A commodity that needs confirming: its buyout is the unit price times
-- the quantity.
M.postWarning = true
M.bags["0:4"] = { link = ORE, count = 20 }
local ore = ItemLocation:CreateFromBagAndSlot(0, 4)
C_AuctionHouse.PostCommodity(ore, 1, 20, 150)
C_AuctionHouse.ConfirmPostCommodity(ore, 1, 20, 150)
M.fire("AUCTION_HOUSE_AUCTION_CREATED", 103)
post = last("post")
check(post.item == ORE and post.count == 20 and post.buyout == 3000 and not post.bid, "commodity posted")

-- A post whose warning was declined isn't logged.
C_AuctionHouse.PostItem(ore, 1, 5, nil, 100)
M.fire("AUCTION_HOUSE_CLOSED")
M.fire("AUCTION_HOUSE_AUCTION_CREATED", 104)
check(count("post") == 2 and ns.stats.given.auction == 21, "declined post not logged")
M.postWarning = nil

--------------------------------------------------------------------------------
-- Destroyed items
--------------------------------------------------------------------------------

-- A protected item is not recorded when its confirmation is cancelled, and
-- is recorded only after the accepted second DeleteCursorItem call.
M.bags["0:9"] = SWORD
M.deleteWarning = true
C_Container.PickupContainerItem(0, 9)
DeleteCursorItem()
check(count("destroy") == 0 and M.bags["0:9"] == SWORD and M.cursorItem == "0:9", "confirmation is not a deletion")
ClearCursor()
check(count("destroy") == 0 and M.bags["0:9"] == SWORD, "cancelled deletion not recorded")
C_Container.PickupContainerItem(0, 9)
DeleteCursorItem()
DeleteCursorItem()
check(count("destroy") == 1 and last("destroy").item == SWORD and not M.bags["0:9"], "confirmed deletion recorded once")
M.deleteWarning = nil

-- A whole stack, part of one and a worn item.
M.bags["0:5"] = { link = JUNK, count = 3 }
C_Container.PickupContainerItem(0, 5)
DeleteCursorItem()
check(last("destroy").item == JUNK and last("destroy").count == 3 and not M.bags["0:5"], "stack destroyed")
M.bags["0:6"] = { link = CLOTH, count = 10 }
C_Container.SplitContainerItem(0, 6, 4)
DeleteCursorItem()
check(last("destroy").item == CLOTH and last("destroy").count == 4 and M.bags["0:6"].count == 6, "split stack destroyed")
M.equipped[16] = AXE
PickupInventoryItem(16)
DeleteCursorItem()
check(last("destroy").item == AXE and last("destroy").count == 1, "worn item destroyed")
check(Log(1):find("Destroyed " .. AXE, 1, true), "log shows the destroyed item")

-- Putting an item back down or cancelling destroys nothing.
M.bags["0:7"] = JUNK
C_Container.PickupContainerItem(0, 7)
C_Container.PickupContainerItem(0, 8)
DeleteCursorItem()
C_Container.PickupContainerItem(0, 8)
ClearCursor()
DeleteCursorItem()
check(count("destroy") == 4 and M.bags["0:8"] == JUNK, "nothing destroyed when put down or cancelled")
check(ns.stats.given.destroy == 9, "destroyed items counted")

--------------------------------------------------------------------------------
-- Guild bank
--------------------------------------------------------------------------------

local function bagUpdate()
	M.fire("BAG_UPDATE_DELAYED")
end

-- Bag changes while the guild bank is closed aren't moves.
M.guildBankItems["1:1"] = { link = ORE, count = 10 }
M.bags["0:9"] = { link = BREAD, count = 4 }
PickupGuildBankItem(1, 1)
bagUpdate()

M.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.GuildBanker)
M.fire("GUILDBANKFRAME_OPENED")

-- Withdrawn by right-click: a new stack in the bags.
AutoStoreGuildBankItem(1, 1)
M.bags["0:10"] = { link = ORE, count = 10 }
bagUpdate()

-- Deposited by dragging part of a stack, held on the cursor a few seconds.
C_Container.SplitContainerItem(0, 9, 3)
M.advance(4)
PickupGuildBankItem(1, 2)
M.bags["0:9"] = { link = BREAD, count = 1 }
ClearCursor()
bagUpdate()

-- Deposited by right-click, then more ore withdrawn into the same stack.
C_Container.UseContainerItem(0, 3)
M.bags["0:3"] = nil
bagUpdate()
M.advance(2)
PickupGuildBankItem(1, 3)
C_Container.PickupContainerItem(0, 10)
M.bags["0:10"] = { link = ORE, count = 15 }
bagUpdate()

-- Equipping from the bags long after a click isn't a deposit.
M.advance(30)
M.bags["0:9"] = nil
M.equip(5, BREAD)
bagUpdate()
check(count("guildbank") == 0, "nothing logged while the guild bank is open")

M.fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.GuildBanker)
M.fire("GUILDBANKFRAME_CLOSED")
local gb = last("guildbank")
check(count("guildbank") == 1 and gb.guild == "Wanderers", "one entry per visit, with the guild")
check(gb.withdrawn and #gb.withdrawn == 1 and gb.withdrawn[1].item == ORE and gb.withdrawn[1].count == 15,
	"withdrawn items added up")
check(gb.deposited and #gb.deposited == 2 and gb.deposited[1].item == SWORD and gb.deposited[1].count == 1
	and gb.deposited[2].item == BREAD and gb.deposited[2].count == 3, "deposited items by name, split stack too")
check(ns.stats.guildBank.deposited == 4 and ns.stats.guildBank.withdrawn == 15, "guild bank items counted")
check(Log(1):find("Guild bank of Wanderers: deposited " .. SWORD .. ", " .. BREAD .. "x3; withdrew " .. ORE .. "x15", 1, true),
	"log shows the visit")

-- A visit that only looks moves nothing.
M.fire("GUILDBANKFRAME_OPENED")
M.fire("GUILDBANKFRAME_CLOSED")
check(count("guildbank") == 1, "a visit without moves isn't logged")

-- Leaving by logging out with the guild bank open still logs the visit.
M.fire("GUILDBANKFRAME_OPENED")
AutoStoreGuildBankItem(1, 4)
M.bags["0:11"] = AXE
bagUpdate()
ns = M.Reload()
gb = last("guildbank")
check(count("guildbank") == 2 and not gb.deposited and gb.withdrawn[1].item == AXE and gb.withdrawn[1].count == 1,
	"visit logged on logout")
check(ns.stats.guildBank.withdrawn == 16, "counted on logout")

--------------------------------------------------------------------------------
-- Totals, History and a reload
--------------------------------------------------------------------------------

M.out = {}
SlashCmdList.TRAVELLOG("stats")
local stats = table.concat(M.out, "\n")
check(stats:find("Items out: 5 traded, 21 mailed, 21 auctioned, 9 destroyed", 1, true), "/tl stats line")
check(stats:find("Guild bank items: 4 deposited, 16 withdrawn", 1, true), "/tl stats guild bank line")
check(ns.LogMatches(last("give"), "", "Trade") and ns.LogMatches(last("send"), "", "Trade")
	and ns.LogMatches(last("post"), "", "Trade") and ns.LogMatches(last("destroy"), "", "Loot")
	and ns.LogMatches(last("guildbank"), "", "Trade"), "History groups")
check(ns.LogMatches(last("send"), "mail sent jaina") and ns.LogMatches(last("destroy"), "destroyed axe")
	and ns.LogMatches(last("guildbank"), "guild bank axe"), "History search")

ns = M.Reload()
check(last("give").partner == "Thrall-Orgrimmar" and last("send").recipient == "Jaina" and last("post").buyout == 3000
	and last("destroy").item == AXE and ns.stats.given.trade == 5, "kept after a reload")
