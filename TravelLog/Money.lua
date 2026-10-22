-- Money ledger: every change to your gold, with a best guess at why.
local _, ns = ...

local lastMoney

local WAIT = 5 -- seconds a click's money change may take to arrive

-- Money reasons and how they read in /tl log, /tl stats and the window.
ns.MONEY_REASONS = {
	loot = "loot", vendor = "vendor", flight = "flight", quest = "quest", training = "training",
	mail = "mail", cod = "COD", trade = "trade", auction = "auction", deposit = "auction deposit",
	bankslot = "bank slot", bank = "account bank", guildbank = "guild bank", barber = "barber",
	respec = "talent reset", stable = "stable slot", other = "other",
}

--------------------------------------------------------------------------------
-- Clicks that cost or bring money: marked when they happen, so the change
-- that follows gets its reason.
--------------------------------------------------------------------------------

local slot  -- the bank slot being bought: { bank, slot }
local sale  -- the auction sale whose mail money was just taken: { item }

-- On Forever the bank's bag slots are bank tabs, bought for each bank.
if C_Bank and C_Bank.PurchaseBankTab then
	hooksecurefunc(C_Bank, "PurchaseBankTab", function(bankType)
		if not ns.char then
			return
		end
		local owned = ns.Clean(C_Bank.FetchNumPurchasedBankTabs(bankType)) or 0
		slot = { bank = bankType == Enum.BankType.Account and "account" or "character", slot = owned + 1 }
		ns.Mark("bankslot")
	end)
end

-- Gold moved to or from the account bank.
for _, name in ipairs({ "DepositMoney", "WithdrawMoney" }) do
	if C_Bank and C_Bank[name] then
		hooksecurefunc(C_Bank, name, function()
			ns.Mark("bankmoney")
		end)
	end
end

if ConfirmTalentWipe then
	hooksecurefunc("ConfirmTalentWipe", function()
		ns.Mark("respec")
	end)
end

if C_StableInfo and C_StableInfo.BuyStableSlot then
	hooksecurefunc(C_StableInfo, "BuyStableSlot", function()
		ns.Mark("stable")
	end)
end

-- Taking an item from a COD mail pays for it; money from the auction house's
-- "sold" mail is a sale.
local function TookMail(index)
	if (ns.Clean((select(6, GetInboxHeaderInfo(index)))) or 0) > 0 then
		ns.Mark("cod")
	end
end
local function TookMoney(index)
	local invoiceType, item = GetInboxInvoiceInfo(index)
	sale = ns.Clean(invoiceType) == "seller" and { item = ns.Clean(item) } or nil
	ns.Mark("mailmoney")
end
hooksecurefunc("TakeInboxItem", TookMail)
hooksecurefunc("AutoLootMailItem", TookMail)
hooksecurefunc("TakeInboxMoney", TookMoney)
hooksecurefunc("AutoLootMailItem", TookMoney)

--------------------------------------------------------------------------------
-- The ledger
--------------------------------------------------------------------------------

local function Reason(delta)
	if ns.LootEventForMoney() then return "loot" end
	if delta < 0 then
		if ns.Recent("bankslot", WAIT) then return "bankslot" end
		if ns.Recent("deposit", WAIT) and ns.open.auction then return "deposit" end
		if ns.Recent("cod", WAIT) and ns.open.mail then return "cod" end
		if ns.Recent("respec", WAIT) then return "respec" end
		if ns.Recent("stable", WAIT) then return "stable" end
	end
	if ns.Recent("bankmoney", WAIT) then return "bank" end
	if ns.open.merchant then return "vendor" end
	if ns.open.taxi or ns.Recent("flight", 5) then return "flight" end
	if ns.Recent("questdone", 3) then return "quest" end
	if ns.open.trainer then return "training" end
	if ns.open.mail then return delta > 0 and sale and ns.Recent("mailmoney", WAIT) and "auction" or "mail" end
	if ns.open.trade then return "trade" end
	if ns.open.auction then return "auction" end
	if ns.open.guildbank then return "guildbank" end
	if ns.open.barber then return "barber" end
	return "other"
end

ns.On("PLAYER_LOGIN", function()
	lastMoney = GetMoney()
end)

ns.On("PLAYER_MONEY", function()
	local money = GetMoney()
	local delta = money - (lastMoney or money)
	lastMoney = money
	if delta == 0 then
		return
	end

	local reason = Reason(delta)
	ns.Add(math.abs(delta), "money", reason, delta > 0 and "gained" or "spent")

	-- Looted coins are stored on the loot event itself, not as separate rows.
	if reason == "loot" then
		local e = ns.LootEventForMoney()
		e.money = (e.money or 0) + delta
		ns.Add(delta, "loot", "money")
		return
	end
	local data = { amount = delta, reason = reason, balance = money }
	if reason == "auction" and ns.open.mail then
		data.item = sale.item
	end
	ns.Log("money", ns.WithCounterpart(data, reason))

	-- A bank slot also gets its own entry, once.
	if reason == "bankslot" and slot then
		ns.Log("bankslot", { bank = slot.bank, slot = slot.slot, price = -delta })
		slot = nil
	end
end)
