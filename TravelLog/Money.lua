-- Money ledger: every change to your gold, with a best guess at why.
local _, ns = ...

local lastMoney

local function Reason()
	if ns.LootEventForMoney() then return "loot" end
	if ns.open.merchant then return "vendor" end
	if ns.open.taxi or ns.Recent("flight", 5) then return "flight" end
	if ns.Recent("questdone", 3) then return "quest" end
	if ns.open.trainer then return "training" end
	if ns.open.mail then return "mail" end
	if ns.open.trade then return "trade" end
	if ns.open.auction then return "auction" end
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

	local reason = Reason()
	ns.Add(math.abs(delta), "money", reason, delta > 0 and "gained" or "spent")

	-- Looted coins are stored on the loot event itself, not as separate rows.
	if reason == "loot" then
		local e = ns.LootEventForMoney()
		e.money = (e.money or 0) + delta
		ns.Add(delta, "loot", "money")
	else
		ns.Log("money", ns.WithCounterpart({ amount = delta, reason = reason, balance = money }, reason))
	end
end)
