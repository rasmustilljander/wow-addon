-- How auctions end: sold (money from the mail, a partial commodity sale),
-- expired (the item back from the mail), cancelled (at the auction house, by
-- auction ID, with and without its quantity); posts that share an item, a
-- sale with no post, items won, a reload with auctions open; the post's
-- outcome, `/tl log`, History, `/tl stats`, item tooltips.
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
local function Open() return #(TravelLogCharDB.auctions or {}) end

local SWORD = "|cff1eff00|Hitem:2488:0:0:0:0:0:1017:0|h[Gladius of the Bear]|h|r"
local ORE = "|cffffffff|Hitem:2770::::|h[Copper Ore]|h|r"
local RING = "|cff0070dd|Hitem:2043::::|h[Ring of Forlorn Spirits]|h|r"

--------------------------------------------------------------------------------
-- Posting
--------------------------------------------------------------------------------

M.fire("AUCTION_HOUSE_SHOW")

-- Two swords from one click are two auctions on one post.
M.bags["0:3"] = SWORD
C_AuctionHouse.PostItem(ItemLocation:CreateFromBagAndSlot(0, 3), 2, 2, nil, 12000)
M.fire("AUCTION_HOUSE_AUCTION_CREATED", 201)
M.fire("AUCTION_HOUSE_AUCTION_CREATED", 202)
local swords = last("post")
local swordsPosted = swords.time
check(count("post") == 1 and swords.count == 2 and Open() == 1, "one open post for both auctions")

M.bags["0:4"] = { link = ORE, count = 20 }
C_AuctionHouse.PostCommodity(ItemLocation:CreateFromBagAndSlot(0, 4), 1, 20, 150)
M.fire("AUCTION_HOUSE_AUCTION_CREATED", 203)
check(count("post") == 2 and Open() == 2, "a second open post")

--------------------------------------------------------------------------------
-- Cancelled at the auction house
--------------------------------------------------------------------------------

M.advance(600)
M.ownedAuctions = {
	{ auctionID = 201, itemKey = { itemID = 2488 }, itemLink = SWORD, status = 0, quantity = 1 },
	{ auctionID = 202, itemKey = { itemID = 2488 }, itemLink = SWORD, status = 0, quantity = 1 },
}
C_AuctionHouse.CancelAuction(202)
check(count("auction") == 0, "not cancelled until the auction house says so")
M.fire("AUCTION_CANCELED", 202)
local ended = last("auction")
check(ended and ended.result == "cancelled" and ended.item == SWORD and ended.count == 1 and ended.posted == swordsPosted,
	"cancel linked to its post")
check(last("post").item == ORE and TravelLogCharDB.log[#TravelLogCharDB.log - 1].type == "post", "the post stays in place")
check(swords.cancelled == 1 and not swords.sold and Open() == 2, "the post has one cancelled, one still open")
check(Log(1):find("Cancelled auction: " .. SWORD .. " (posted 10m before)", 1, true), "log shows the cancel")

-- Another addon's or a GM's cancel isn't yours.
M.fire("AUCTION_CANCELED", 201)
check(count("auction") == 1, "a cancel you didn't make isn't logged")
M.fire("AUCTION_HOUSE_CLOSED")

--------------------------------------------------------------------------------
-- A reload with auctions open
--------------------------------------------------------------------------------

ns = M.Reload()
swords = nil
for _, e in ipairs(TravelLogCharDB.log) do
	if e.type == "post" and e.item == SWORD then swords = e end
end
check(Open() == 2 and swords.cancelled == 1, "open auctions kept after a reload")

--------------------------------------------------------------------------------
-- Sold: the money taken from the mail
--------------------------------------------------------------------------------

M.advance(7200)
M.fire("MAIL_SHOW")
M.inbox = {
	{ sender = "Auction House", subject = "Auction successful: Gladius of the Bear", money = 11400,
		invoice = { type = "seller", item = "Gladius of the Bear", player = "Thrall", bid = 12000 } },
	{ sender = "Auction House", subject = "Auction successful: Copper Ore (15)", money = 2140,
		invoice = { type = "seller", item = "Copper Ore", player = nil, bid = 2250, count = 15 } },
}
TakeInboxMoney(1)
check(count("auction") == 1, "nothing ends before the money arrives")
M.money = M.money + 11400
M.fire("PLAYER_MONEY")
ended = last("auction")
check(last("money").reason == "auction" and ended.result == "sold" and ended.item == SWORD and ended.count == 1
	and ended.price == 12000 and ended.buyer == "Thrall" and ended.posted == swordsPosted, "sale linked to its post, by name")
check(swords.sold == 1 and swords.cancelled == 1 and Open() == 1, "the post has ended")
check(Log(1):find("Sold at auction: " .. SWORD .. " for 1g 20s 0c to Thrall (posted 2h 10m before)", 1, true),
	"log shows the sale")

-- A commodity sold in part, with several buyers.
TakeInboxMoney(2)
M.money = M.money + 2140
M.fire("PLAYER_MONEY")
ended = last("auction")
local ore = last("post")
check(ended.result == "sold" and ended.item == ORE and ended.count == 15 and ended.price == 2250 and not ended.buyer,
	"part of a commodity sold")
check(ore.sold == 15 and Open() == 1, "the rest is still open")

-- Money from other mail ends nothing.
M.inbox[3] = { sender = "Jaina", money = 500 }
TakeInboxMoney(3)
M.money = M.money + 500
M.fire("PLAYER_MONEY")
check(count("auction") == 3, "other mail money isn't a sale")

--------------------------------------------------------------------------------
-- Expired: the item back from the mail
--------------------------------------------------------------------------------

M.inbox[4] = { sender = "Auction House", subject = "Auction expired: Copper Ore (5)", items = { { link = ORE, count = 5 } } }
AutoLootMailItem(4)
M.fire("CHAT_MSG_LOOT", "You receive item: " .. ORE .. "x5.")
ended = last("auction")
check(last("receive").how == "returned" and last("receive").count == 5 and not last("receive").sender, "a returned item")
check(ended.result == "expired" and ended.item == ORE and ended.count == 5 and ended.posted == ore.time, "expiry linked to its post")
check(ore.sold == 15 and ore.expired == 5 and Open() == 0, "the commodity post has ended")
check(Log(20):find("Posted " .. ORE .. "x20 at auction, buyout 30s 0c: 15 sold, 5 expired", 1, true), "the post shows how it ended")
check(Log(20):find("Posted " .. SWORD .. "x2 at auction, buyout 1g 20s 0c: 1 sold, 1 cancelled", 1, true), "both outcomes on one post")

-- The item back from the cancel is returned too, and ends nothing more.
M.inbox[5] = { sender = "Auction House", subject = "Auction canceled: Gladius of the Bear", items = { { link = SWORD } } }
TakeInboxItem(5, 1)
M.fire("CHAT_MSG_LOOT", "You receive item: " .. SWORD .. ".")
check(last("receive").how == "returned" and count("auction") == 4, "a cancelled auction's item is returned")
check(not ns.ItemHistory(2488), "returned items aren't items you got")

-- An item won at auction.
M.items[2043] = { link = RING, quality = 3 }
M.inbox[6] = { sender = "Auction House", subject = "Auction won: Ring of Forlorn Spirits", items = { { link = RING } } }
TakeInboxItem(6, 1)
M.fire("CHAT_MSG_LOOT", "You receive item: " .. RING .. ".")
check(last("receive").how == "auction" and ns.stats.received.auction == 1, "an item won at auction")
check(table.concat(M.hoverItem(2043), "\n"):find("First bought at auction", 1, true), "the tooltip says it was bought at auction")

-- Ordinary mail is still mail.
M.inbox[7] = { sender = "Anduin", subject = "cloth", items = { { link = ORE } } }
TakeInboxItem(7, 1)
M.fire("CHAT_MSG_LOOT", "You receive item: " .. ORE .. ".")
check(last("receive").how == "mail" and last("receive").sender == "Anduin" and count("auction") == 4, "other mail is mail")
M.fire("MAIL_CLOSED")

--------------------------------------------------------------------------------
-- Posts sharing an item, a cancel without its quantity, a sale with no post
--------------------------------------------------------------------------------

M.fire("AUCTION_HOUSE_SHOW")
M.bags["0:5"] = { link = ORE, count = 10 }
C_AuctionHouse.PostCommodity(ItemLocation:CreateFromBagAndSlot(0, 5), 1, 10, 100)
M.fire("AUCTION_HOUSE_AUCTION_CREATED", 301)
local first = last("post")
M.advance(60)
C_AuctionHouse.PostCommodity(ItemLocation:CreateFromBagAndSlot(0, 5), 1, 10, 90)
M.fire("AUCTION_HOUSE_AUCTION_CREATED", 302)
local second = last("post")
check(Open() == 2 and first ~= second, "two open posts of ore")

-- The auction house no longer lists it: the cancel takes what's left of its post.
M.ownedAuctions = {}
C_AuctionHouse.CancelAuction(302)
M.fire("AUCTION_CANCELED", 302)
check(last("auction").result == "cancelled" and last("auction").count == 10 and last("auction").posted == second.time
	and second.cancelled == 10 and not first.cancelled and Open() == 1, "cancelled by ID, not the older post")
M.fire("AUCTION_HOUSE_CLOSED")

-- A sale bigger than what's open is logged in full.
M.fire("MAIL_SHOW")
M.inbox = {
	{ sender = "Auction House", money = 1400, invoice = { type = "seller", item = "Copper Ore", bid = 1500, count = 15 } },
	{ sender = "Auction House", money = 4750, invoice = { type = "seller", item = "Linen Cloth", bid = 5000, player = "Bob" } },
}
TakeInboxMoney(1)
M.money = M.money + 1400
M.fire("PLAYER_MONEY")
check(last("auction").count == 15 and first.sold == 10 and Open() == 0, "a sale ends the oldest post")

TakeInboxMoney(2)
M.money = M.money + 4750
M.fire("PLAYER_MONEY")
ended = last("auction")
check(ended.result == "sold" and ended.item == "Linen Cloth" and ended.count == 1 and not ended.posted, "a sale with no post")
check(Log(1):find("Sold at auction: Linen Cloth for 50s 0c to Bob", 1, true) and not Log(1):find("posted", 1, true),
	"log shows a sale with no post")
M.fire("MAIL_CLOSED")

--------------------------------------------------------------------------------
-- Totals, History and a reload
--------------------------------------------------------------------------------

check(ns.stats.auctions.sold == 32 and ns.stats.auctions.expired == 5 and ns.stats.auctions.cancelled == 11, "ended items counted")
check(ns.stats.received.returned == 6, "returned items counted apart")
M.out = {}
SlashCmdList.TRAVELLOG("stats")
check(table.concat(M.out, "\n"):find("Auctioned items: 32 sold, 5 expired, 11 cancelled", 1, true), "/tl stats line")
check(ns.LogMatches(last("auction"), "", "Trade") and ns.LogMatches(last("auction"), "auction ended sold bob"), "History group and search")

ns = M.Reload()
check(last("auction").buyer == "Bob" and ns.stats.auctions.sold == 32 and Open() == 0, "kept after a reload")
