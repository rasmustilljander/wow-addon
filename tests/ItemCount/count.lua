-- ItemCount: counting bags, bank, mail, auctions and equipped items per
-- character, the tooltip lines, mail to alts, auctions running out,
-- commands and a reload.
M.installed = { "ItemCount" }

local function Link(id, name, color)
	return "|cff" .. (color or "ffffff") .. "|Hitem:" .. id .. "::::|h[" .. name .. "]|h|r"
end
local LINEN, SWORD, KEY = Link(2589, "Linen Cloth"), Link(2000, "Shiny Sword", "1eff00"), Link(5396, "Key to Searing Gorge")
M.items = { [2589] = { link = LINEN }, [2000] = { link = SWORD, quality = 2 }, [5396] = { link = KEY } }

local function Lines(id)
	local lines = M.hoverItem(id)
	table.remove(lines, 1) -- the item's name
	return table.concat(lines, " | ")
end

--------------------------------------------------------------------------------
-- An alt with linen in the bags and on the auction house
--------------------------------------------------------------------------------

M.player = { name = "Altie", realm = "Forever", class = "WARRIOR" }
M.bagSlots = { [0] = 16, [1] = 6 }
M.bags = { ["0:1"] = { link = LINEN, count = 10 } }
local ns = M.Login()
check(Lines(2589) == "Altie  10 (bags 10)", "one character, no total: " .. Lines(2589))

M.ownedAuctions = {
	{ auctionID = 1, itemKey = { itemID = 2589 }, status = 0, quantity = 5, timeLeftSeconds = 12 * 3600 },
	{ auctionID = 2, itemKey = { itemID = 2589 }, status = 1, quantity = 3 }, -- sold
}
M.fire("AUCTION_HOUSE_SHOW")
check(M.ownedQueries == 1, "owned auctions asked for")
M.fire("OWNED_AUCTIONS_UPDATED")
check(Lines(2589) == "Altie  15 (bags 10, AH 5)", "active auctions only: " .. Lines(2589))
M.fire("AUCTION_HOUSE_AUCTION_CREATED", 3)
M.fire("AUCTION_CANCELED", 1)
check(M.ownedQueries == 3, "asked again after posting and canceling")
M.fire("AUCTION_HOUSE_CLOSED")
M.Logout()

--------------------------------------------------------------------------------
-- The main: bags and bank, and the alt in the tooltip
--------------------------------------------------------------------------------

M.player = { name = "Rasmus", realm = "Forever", class = "MAGE" }
M.bagSlots = { [0] = 16, [1] = 6, [6] = 28, [7] = 28 }
M.bags = {
	["0:1"] = { link = LINEN, count = 15 }, ["1:2"] = { link = LINEN, count = 5 },
	["6:1"] = { link = LINEN, count = 20 }, ["7:3"] = { link = LINEN, count = 20 },
}
ns = M.Login()
check(Lines(2589) == "Total  35 | Rasmus  20 (bags 20) | Altie  15 (bags 10, AH 5)", "bank not seen yet: " .. Lines(2589))

M.fire("BANKFRAME_OPENED")
check(Lines(2589) == "Total  75 | Rasmus  60 (bags 20, bank 40) | Altie  15 (bags 10, AH 5)", "the example: " .. Lines(2589))

-- Moving between bags and bank while it's open.
M.bags["1:2"], M.bags["7:4"] = nil, { link = LINEN, count = 5 }
M.fire("BAG_UPDATE_DELAYED")
check(Lines(2589):find("Rasmus  60 %(bags 15, bank 45%)"), "moved to the bank: " .. Lines(2589))
M.fire("BANKFRAME_CLOSED")
-- Once closed, bank tabs aren't counted; bags still are.
M.bags["7:4"], M.bags["0:2"] = nil, { link = LINEN, count = 1 }
M.fire("BAG_UPDATE_DELAYED")
check(Lines(2589):find("Rasmus  61 %(bags 16, bank 45%)"), "bank kept when closed: " .. Lines(2589))
-- A bank whose tabs haven't loaded keeps the last count.
local slots = M.bagSlots
M.bagSlots = { [0] = 16, [1] = 6 }
M.fire("BANKFRAME_OPENED")
check(Lines(2589):find("bank 45"), "unloaded bank ignored")
M.fire("BANKFRAME_CLOSED")
M.bagSlots = slots
-- The next visit counts what was taken out meanwhile.
M.fire("BANKFRAME_OPENED")
M.fire("BANKFRAME_CLOSED")
check(Lines(2589):find("Rasmus  56 %(bags 16, bank 40%)"), "recounted: " .. Lines(2589))

-- The keyring counts as bags; equipped items have their own place.
M.bagSlots[-1], M.bags["-1:1"] = 12, KEY
M.equipped[16] = SWORD
M.fire("BAG_UPDATE_DELAYED")
M.fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
check(Lines(5396) == "Rasmus  1 (bags 1)", "keyring: " .. Lines(5396))
check(Lines(2000) == "Rasmus  1 (equipped 1)", "equipped: " .. Lines(2000))
check(Lines(1234) == "", "nobody has it")

--------------------------------------------------------------------------------
-- Auctions run out, the account bank
--------------------------------------------------------------------------------

M.advance(12 * 3600 + 1)
check(Lines(2589):find("Altie  10 %(bags 10%)"), "ended auction dropped: " .. Lines(2589))

M.accountBank = true
M.bagSlots[15], M.bags["15:1"] = 98, { link = LINEN, count = 4 }
M.fire("BANKFRAME_OPENED")
M.fire("BANKFRAME_CLOSED")
check(Lines(2589) == "Total  70 | Rasmus  56 (bags 16, bank 40) | Altie  10 (bags 10) | Account bank  4", "account bank: " .. Lines(2589))

--------------------------------------------------------------------------------
-- Mail
--------------------------------------------------------------------------------

-- Mail to an alt is theirs once it's sent, by name in any case or with the
-- realm.
M.sendItems = { { link = LINEN, count = 8 }, [3] = { link = SWORD } }
SendMail("altie", "cloth", "")
M.fire("MAIL_SEND_SUCCESS")
check(Lines(2589):find("Altie  18 %(bags 10, mail 8%)"), "mailed to an alt: " .. Lines(2589))
check(Lines(2000):find("Altie  1 %(mail 1%)"), "every attachment")
SendMail("Altie-Forever", "", "")
M.fire("MAIL_FAILED")
M.fire("MAIL_SEND_SUCCESS")
check(Lines(2589):find("mail 8%)"), "failed mail not added")
SendMail("Stranger", "", "")
M.fire("MAIL_SEND_SUCCESS")
SendMail("Altie-OtherRealm", "", "")
M.fire("MAIL_SEND_SUCCESS")
check(Lines(2589):find("mail 8%)"), "mail to others not added")
M.sendItems = {}

-- The own inbox, counted when it loads, without COD mail and currency.
M.inbox = {
	{ items = { { link = LINEN, count = 7 }, [5] = { link = LINEN, count = 2 } } },
	{ cod = 500, items = { { link = LINEN, count = 3 } } },
	{ items = { { link = KEY, count = 1, currency = true } } },
}
M.fire("MAIL_INBOX_UPDATE")
check(not Lines(2589):find("Rasmus  %d+ %([^)]*mail"), "inbox not counted before the mailbox opens")
M.fire("MAIL_SHOW")
M.fire("MAIL_INBOX_UPDATE")
check(Lines(2589):find("Rasmus  65 %(bags 16, bank 40, mail 9%)"), "inbox: " .. Lines(2589))
check(Lines(5396) == "Rasmus  1 (bags 1)", "currency left out")
M.fire("MAIL_CLOSED")

--------------------------------------------------------------------------------
-- Other realms, a reload, commands
--------------------------------------------------------------------------------

ns.db.chars["Farfar-Other Realm"] = { class = "PRIEST", bags = { [2589] = 2 } }
check(Lines(2589):find("Farfar%-Other Realm  2 %(bags 2%)"), "realm shown for other realms: " .. Lines(2589))
check(ns.Find("farfar-OtherRealm") == "Farfar-Other Realm", "realm without spaces")

ns = M.Reload()
check(Lines(2589):find("^Total  89 | Rasmus  65 %(bags 16, bank 40, mail 9%)"), "kept over a reload: " .. Lines(2589))
check(ns.db.chars["Rasmus-Forever"].bankTime and ns.db.chars["Altie-Forever"].auctionTime, "times saved")

M.out = {}
SlashCmdList.ITEMCOUNT("")
local out = table.concat(M.out, "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
check(out:find("Altie%-Forever: bank never, mail never, AH 12h ago"), "last counted: " .. out)
check(out:find("Rasmus%-Forever: bank 0m ago, mail 0m ago, AH never") and out:find("Account bank: 0m ago"), "own and account bank")

M.out = {}
SlashCmdList.ITEMCOUNT("forget farfar-other realm")
SlashCmdList.ITEMCOUNT("forget Rasmus")
SlashCmdList.ITEMCOUNT("forget Nobody")
check(M.out[1]:find("Forgot Farfar%-Other Realm") and M.out[2]:find("can't forget") and M.out[3]:find("isn't one of your"), "forget: " .. table.concat(M.out, " / "))
check(not Lines(2589):find("Farfar"), "forgotten character gone")
