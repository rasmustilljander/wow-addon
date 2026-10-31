-- Money reasons: bank slots (with their own entry), the account bank, the
-- guild bank, the barber, talent resets, stable slots, auction deposits and
-- sales, COD; what's left is "other". /tl log, /tl stats, Totals, a reload.
M.money = 1000000
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
-- Changes your gold and returns the money entry it made.
local function Pay(amount)
	M.money = M.money - amount
	M.fire("PLAYER_MONEY")
	return last("money")
end

--------------------------------------------------------------------------------
-- The bank
--------------------------------------------------------------------------------

-- A bank slot: the money has its reason, and the slot its own entry with
-- which slot of which bank it was.
M.fire("BANKFRAME_OPENED")
M.bankTabs[Enum.BankType.Character] = 2
C_Bank.PurchaseBankTab(Enum.BankType.Character)
local money = Pay(10000)
local slot = last("bankslot")
check(money.reason == "bankslot" and money.amount == -10000, "bank slot money reason")
check(slot and slot.bank == "character" and slot.slot == 3 and slot.price == 10000, "bank slot entry")
check(Log(2):find("Paid 1g 0s 0c (bank slot)", 1, true) and Log(1):find("Bought bank slot 3 for 1g 0s 0c", 1, true),
	"log shows the bank slot: " .. Log(2))

-- The account bank's first slot.
C_Bank.PurchaseBankTab(Enum.BankType.Account)
Pay(250000)
check(last("bankslot").bank == "account" and last("bankslot").slot == 1, "account bank slot")
check(Log(1):find("Bought account bank slot 1 for 25g 0s 0c", 1, true), "log shows the account bank slot")

-- A free slot changes no money and logs nothing; a later change isn't a slot.
C_Bank.PurchaseBankTab(Enum.BankType.Character)
M.advance(6)
check(Pay(5).reason == "other" and count("bankslot") == 2, "a change long after buying isn't a slot")

-- Gold put into and taken out of the account bank.
C_Bank.DepositMoney(Enum.BankType.Account, 5000)
check(Pay(5000).reason == "bank", "account bank deposit")
C_Bank.WithdrawMoney(Enum.BankType.Account, 2000)
local back = Pay(-2000)
check(back.reason == "bank" and back.amount == 2000, "account bank withdrawal")
check(Log(1):find("Got 20s 0c (account bank)", 1, true), "log shows the account bank")
M.fire("BANKFRAME_CLOSED")
M.advance(6)

--------------------------------------------------------------------------------
-- The guild bank, barber, talent resets and stable slots
--------------------------------------------------------------------------------

M.fire("GUILDBANKFRAME_OPENED")
check(Pay(300).reason == "guildbank" and Pay(-100).reason == "guildbank", "guild bank deposit and withdrawal")
M.fire("GUILDBANKFRAME_CLOSED")
check(Pay(1).reason == "other", "guild bank closed")
-- The interaction manager opens it too.
M.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.GuildBanker)
check(Pay(50).reason == "guildbank", "guild bank from the interaction manager")
M.fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.GuildBanker)
check(Log(1):find("Paid 50c (guild bank)", 1, true), "log shows the guild bank")

M.fire("BARBER_SHOP_OPEN")
check(Pay(500).reason == "barber", "barber")
M.fire("BARBER_SHOP_CLOSE")
check(Pay(1).reason == "other", "barber closed")

ConfirmTalentWipe()
check(Pay(10000).reason == "respec", "talent reset")
check(Log(1):find("Paid 1g 0s 0c (talent reset)", 1, true), "log shows the talent reset")
M.advance(6)
C_StableInfo.BuyStableSlot()
check(Pay(1000).reason == "stable", "stable slot")
M.advance(6)
check(Pay(1).reason == "other", "nothing marked any more")

--------------------------------------------------------------------------------
-- Auctions and mail
--------------------------------------------------------------------------------

-- A post's cost is its deposit; buying later isn't.
local SWORD = "|cff1eff00|Hitem:2488::::|h[Gladius]|h|r"
M.fire("AUCTION_HOUSE_SHOW")
M.bags["0:3"] = SWORD
C_AuctionHouse.PostItem(ItemLocation:CreateFromBagAndSlot(0, 3), 2, 1, 5000, 12000)
check(Pay(150).reason == "deposit", "auction deposit")
M.advance(6)
check(Pay(4000).reason == "auction", "auction buyout")
M.fire("AUCTION_HOUSE_CLOSED")

-- COD is paid to the mail's sender; an auction sale's money names the item;
-- other mail money is still mail.
M.fire("MAIL_SHOW")
M.inbox = {
	{ sender = "Jaina", cod = 2000, items = { { link = SWORD } } },
	{ sender = "Auction House", money = 11000, invoice = { type = "seller", item = "Gladius", player = "Thrall" } },
	{ sender = "Anduin", money = 700 },
}
TakeInboxItem(1, 1)
local cod = Pay(2000)
check(cod.reason == "cod" and cod.sender == "Jaina", "COD paid to its sender")
check(Log(1):find("Paid 20s 0c (COD to Jaina)", 1, true), "log shows the COD")
TakeInboxMoney(2)
local sold = Pay(-11000)
check(sold.reason == "auction" and sold.item == "Gladius" and not sold.sender, "auction sale with its item")
check(Log(2):find("Got 1g 10s 0c (auction: Gladius)", 1, true), "log shows the sale")
TakeInboxMoney(3)
check(Pay(-700).reason == "mail" and last("money").sender == "Anduin", "the next mail's money is mail")
M.fire("MAIL_CLOSED")

--------------------------------------------------------------------------------
-- Totals
--------------------------------------------------------------------------------

local spent = ns.stats.money
check(spent.bankslot.spent == 260000 and spent.bank.spent == 5000 and spent.bank.gained == 2000
	and spent.guildbank.spent == 350 and spent.guildbank.gained == 100 and spent.barber.spent == 500
	and spent.respec.spent == 10000 and spent.stable.spent == 1000 and spent.deposit.spent == 150
	and spent.cod.spent == 2000 and spent.auction.gained == 11000, "money by reason")

-- Largest first, with the total.
M.out = {}
SlashCmdList.TRAVELLOG("stats")
local stats = table.concat(M.out, "\n")
check(stats:find("Money out: 28g 30s 8c: bank slot 26g 0s 0c, talent reset 1g 0s 0c, account bank 50s 0c, auction 40s 0c, ", 1, true),
	"/tl stats money out: " .. stats)
check(stats:find("Money in: 1g 38s 0c: auction 1g 10s 0c, account bank 20s 0c, mail 7s 0c, guild bank 1s 0c", 1, true),
	"/tl stats money in")
check(ns.MoneyByReason({}, "spent") == "0c", "no money yet")

-- A count on its own is no search.
check(Log(2):find("Last 2 events:", 1, true), "/tl log n lists the last n")

-- Searching the log finds the reasons by name.
check(Log("1 bankslot"):find("Bought account bank slot 1", 1, true), "search by entry type")
check(Log("1 respec"):find("talent reset", 1, true), "search by reason")

-- Everything survives a reload.
ns = M.Reload()
check(last("bankslot").slot == 1 and ns.stats.money.bankslot.spent == 260000, "kept across a reload")
check(Log(50):find("Bought bank slot 3 for 1g 0s 0c", 1, true), "described after a reload")
