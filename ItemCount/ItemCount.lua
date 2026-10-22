-- ItemCount: counts the items each of your characters has in their bags,
-- bank, mailbox and on the auction house. Bags and equipped items are
-- counted whenever they change; the bank, mail, auctions and guild bank
-- only while you visit them, so those are as of your last visit. The tooltip
-- lines are in Tooltip.lua, the Options page in Settings.lua.
local _, ns = ...

local NUM_BANK_TABS = 9         -- CharacterBankTab_1-9 and AccountBankTab_1-9
local ATTACHMENTS_RECEIVE = 16  -- ATTACHMENTS_MAX_RECEIVE and _SEND, which only
local ATTACHMENTS_SEND = 12     -- exist once Blizzard_MailFrame has loaded
local GUILD_BANK_SLOTS = 98     -- MAX_GUILDBANK_SLOTS_PER_TAB, local to Blizzard_GuildBankUI

-- The places a character keeps items, in tooltip order.
ns.PLACES = { "bags", "bank", "mail", "auctions", "equipped" }

-- Forever runs on the Midnight-era client, which hands addons unreadable
-- "secret" values in some situations. We can't use those, so treat them as
-- missing.
local issecretvalue = issecretvalue
function ns.Clean(value)
	if value ~= nil and issecretvalue and issecretvalue(value) then
		return nil
	end
	return value
end

function ns.Print(text, ...)
	if select("#", ...) > 0 then
		text = text:format(...)
	end
	print("|cffffd200ItemCount|r " .. text)
end

--------------------------------------------------------------------------------
-- Saved data
--------------------------------------------------------------------------------

-- ItemCountDB = {
--   chars = {
--     ["Name-Realm"] = {
--       class = "MAGE",
--       bags = { [itemID] = count }, equipped = { ... },
--       bank = { ... }, bankTime = 1760000000,     -- nil until first seen
--       mail = { ... }, mailTime = 1760000000,
--       auctions = { { id = 2589, count = 5, ends = 1760043200 }, ... },
--       auctionTime = 1760000000,
--     },
--   },
--   accountBank = { [itemID] = count }, accountBankTime = 1760000000,
--   guildBanks = {
--     ["Guild-Realm"] = { tabs = { [tab] = { [itemID] = count } }, time = 1760000000 },
--   },
--   settings = { guildBank = true },
-- }

local db, me

local function Add(counts, id, n)
	counts[id] = (counts[id] or 0) + n
end

-- Counts what's in bags first..last by item ID into `counts`, and returns
-- how many slots those bags have.
local function CountBags(first, last, counts)
	local slots = 0
	for bag = first, last do
		local n = C_Container.GetContainerNumSlots(bag)
		slots = slots + n
		for slot = 1, n do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info then
				Add(counts, info.itemID, info.stackCount)
			end
		end
	end
	return slots
end

local function ScanBags()
	local counts = {}
	CountBags(Enum.BagIndex.Backpack, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS, counts)
	if Enum.BagIndex.Keyring then
		CountBags(Enum.BagIndex.Keyring, Enum.BagIndex.Keyring, counts)
	end
	me.bags = counts
end

local function ScanEquipped()
	local counts = {}
	for slot = INVSLOT_FIRST_EQUIPPED or 1, INVSLOT_LAST_EQUIPPED or 19 do
		local id = GetInventoryItemID("player", slot)
		if id then
			Add(counts, id, 1)
		end
	end
	me.equipped = counts
end

-- Only while the bank is open. A bank whose tabs show no slots hasn't
-- loaded, so the last count is kept.
local function ScanBank()
	local counts = {}
	local first = Enum.BagIndex.CharacterBankTab_1
	if CountBags(first, first + NUM_BANK_TABS - 1, counts) > 0 then
		me.bank, me.bankTime = counts, time()
	end
	if C_Bank.CanViewBank(Enum.BankType.Account) then
		counts, first = {}, Enum.BagIndex.AccountBankTab_1
		if CountBags(first, first + NUM_BANK_TABS - 1, counts) > 0 then
			db.accountBank, db.accountBankTime = counts, time()
		end
	end
end

-- Only while the mailbox is open. Leaves out COD mail, which isn't yours
-- until you pay.
local function ScanMail()
	local counts = {}
	for i = 1, GetInboxNumItems() do
		local cod = select(6, GetInboxHeaderInfo(i))
		if not cod or cod == 0 then
			for a = 1, ATTACHMENTS_RECEIVE do
				local _, id, _, count, _, _, isCurrency = GetInboxItem(i, a)
				if id and not isCurrency then
					Add(counts, id, count or 1)
				end
			end
		end
	end
	me.mail, me.mailTime = counts, time()
end

-- "Guild-Realm" for the guild of the character you're playing, or nil.
local function GuildKey()
	local name, _, _, realm = GetGuildInfo("player")
	name = ns.Clean(name)
	if name then
		return name .. "-" .. (ns.Clean(realm) or ns.realm)
	end
end

-- Only while the guild bank is open. The client only has the items of the
-- tab you're looking at, so each tab is counted when you view it.
local function ScanGuildBank()
	local key = GuildKey()
	if not key or not db.settings.guildBank then
		return
	end
	local bank = db.guildBanks[key] or { tabs = {} }
	db.guildBanks[key] = bank
	local numTabs = GetNumGuildBankTabs()
	for tab in pairs(bank.tabs) do
		if tab > numTabs then
			bank.tabs[tab] = nil
		end
	end
	local tab = GetCurrentGuildBankTab()
	if tab > numTabs or not select(3, GetGuildBankTabInfo(tab)) then
		return
	end
	local counts = {}
	for slot = 1, GUILD_BANK_SLOTS do
		local link = GetGuildBankItemLink(tab, slot)
		if link then
			local _, count = GetGuildBankItemInfo(tab, slot)
			Add(counts, (C_Item.GetItemInfoInstant(link)), count or 1)
		end
	end
	bank.tabs[tab], bank.time = counts, time()
end

local function ScanAuctions()
	if not C_AuctionHouse.HasFullOwnedAuctionResults() then
		return
	end
	local list, now = {}, time()
	for _, auction in ipairs(C_AuctionHouse.GetOwnedAuctions()) do
		if auction.status == Enum.AuctionStatus.Active then
			list[#list + 1] = {
				id = auction.itemKey.itemID,
				count = auction.quantity,
				ends = auction.timeLeftSeconds and now + auction.timeLeftSeconds,
			}
		end
	end
	me.auctions, me.auctionTime = list, now
end

--------------------------------------------------------------------------------
-- Counting
--------------------------------------------------------------------------------

-- How many of an item one of a character's places holds. Auctions count
-- until they run out.
function ns.Count(char, place, id)
	local where = char[place]
	if place ~= "auctions" then
		return where and where[id] or 0
	end
	local n, now = 0, time()
	for _, auction in ipairs(where or {}) do
		if auction.id == id and (not auction.ends or auction.ends > now) then
			n = n + auction.count
		end
	end
	return n
end

-- Everyone who has the item: { key, class, total, places = { { place, n } } },
-- this character first, then most first. Also returns the account bank's
-- count and the total of all.
function ns.Holders(id)
	local list, total = {}, 0
	for key, char in pairs(db.chars) do
		local holder = { key = key, class = char.class, total = 0, places = {} }
		for _, place in ipairs(ns.PLACES) do
			local n = ns.Count(char, place, id)
			if n > 0 then
				holder.places[#holder.places + 1] = { place = place, n = n }
				holder.total = holder.total + n
			end
		end
		if holder.total > 0 then
			list[#list + 1] = holder
			total = total + holder.total
		end
	end
	table.sort(list, function(a, b)
		if (a.key == ns.charKey) ~= (b.key == ns.charKey) then
			return a.key == ns.charKey
		elseif a.total ~= b.total then
			return a.total > b.total
		end
		return a.key < b.key
	end)
	local account = db.accountBank and db.accountBank[id] or 0
	return list, account, total + account
end

-- How many of an item the guild bank of the character you're playing has,
-- or 0 when the guild bank is turned off.
function ns.GuildBankCount(id)
	local bank = db.settings.guildBank and db.guildBanks[GuildKey() or ""]
	local n = 0
	for _, counts in pairs(bank and bank.tabs or {}) do
		n = n + (counts[id] or 0)
	end
	return n
end

-- The key of your character called `name` ("Name" or "Name-Realm", in any
-- case), or nil if it isn't one of yours.
local function Squash(text)
	return (text:gsub("[%s%-']", ""):lower())
end
function ns.Find(name)
	local who, realm = strsplit("-", name, 2)
	realm = Squash(realm and realm ~= "" and realm or GetRealmName())
	for key in pairs(db.chars) do
		local n, r = strsplit("-", key, 2)
		if n:lower() == who:lower() and Squash(r) == realm then
			return key
		end
	end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local bankOpen, mailOpen, guildBankOpen

-- Items mailed to one of your characters, until the mail has gone.
local outgoing
hooksecurefunc("SendMail", function(recipient)
	outgoing = nil
	local key = ns.Clean(recipient) and ns.Find(recipient)
	if not key or key == ns.charKey then
		return
	end
	local counts = {}
	for i = 1, ATTACHMENTS_SEND do
		local _, id, _, count = GetSendMailItem(i)
		if id then
			Add(counts, id, count or 1)
		end
	end
	outgoing = { key = key, counts = counts }
end)

local handlers = {
	PLAYER_LOGIN = function()
		ItemCountDB = ItemCountDB or {}
		db = ItemCountDB
		db.chars = db.chars or {}
		db.guildBanks = db.guildBanks or {}
		ns.SetUpSettings(db)
		ns.realm = GetRealmName()
		ns.charKey = UnitName("player") .. "-" .. ns.realm
		db.chars[ns.charKey] = db.chars[ns.charKey] or {}
		me = db.chars[ns.charKey]
		me.class = select(2, UnitClass("player"))
		ns.db = db
		ScanBags()
		ScanEquipped()
	end,
	BAG_UPDATE_DELAYED = function()
		ScanBags()
		if bankOpen then
			ScanBank()
		end
	end,
	PLAYER_EQUIPMENT_CHANGED = ScanEquipped,
	BANKFRAME_OPENED = function()
		bankOpen = true
		ScanBank()
	end,
	BANKFRAME_CLOSED = function()
		bankOpen = false
	end,
	GUILDBANKFRAME_OPENED = function()
		guildBankOpen = true
	end,
	GUILDBANKFRAME_CLOSED = function()
		guildBankOpen = false
	end,
	-- The shown tab's items have arrived or changed.
	GUILDBANKBAGSLOTS_CHANGED = function()
		if guildBankOpen then
			ScanGuildBank()
		end
	end,
	MAIL_SHOW = function()
		mailOpen = true
	end,
	MAIL_CLOSED = function()
		mailOpen = false
	end,
	-- The inbox has loaded or changed.
	MAIL_INBOX_UPDATE = function()
		if mailOpen then
			ScanMail()
		end
	end,
	MAIL_SEND_SUCCESS = function()
		if outgoing then
			local char = db.chars[outgoing.key]
			if char then
				char.mail = char.mail or {}
				for id, n in pairs(outgoing.counts) do
					Add(char.mail, id, n)
				end
			end
			outgoing = nil
		end
	end,
	MAIL_FAILED = function()
		outgoing = nil
	end,
	AUCTION_HOUSE_SHOW = function()
		C_AuctionHouse.QueryOwnedAuctions({})
	end,
	AUCTION_HOUSE_AUCTION_CREATED = function()
		C_AuctionHouse.QueryOwnedAuctions({})
	end,
	AUCTION_CANCELED = function()
		C_AuctionHouse.QueryOwnedAuctions({})
	end,
	OWNED_AUCTIONS_UPDATED = ScanAuctions,
}
handlers.PLAYERBANKSLOTS_CHANGED = handlers.BAG_UPDATE_DELAYED
handlers.PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED = handlers.BAG_UPDATE_DELAYED

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
	-- Bag events can come before PLAYER_LOGIN.
	if me or event == "PLAYER_LOGIN" then
		handlers[event](...)
	end
end)
for event in pairs(handlers) do
	frame:RegisterEvent(event)
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

local function Ago(t)
	if not t then
		return "never"
	end
	local s = time() - t
	if s < 3600 then
		return math.floor(s / 60) .. "m ago"
	elseif s < 2 * 86400 then
		return math.floor(s / 3600) .. "h ago"
	end
	return math.floor(s / 86400) .. "d ago"
end

SLASH_ITEMCOUNT1 = "/itemcount"
SlashCmdList.ITEMCOUNT = function(msg)
	local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "" then
		local keys = {}
		for key in pairs(db.chars) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
		ns.Print("Last counted:")
		for _, key in ipairs(keys) do
			local char = db.chars[key]
			ns.Print("%s: bank %s, mail %s, AH %s", key, Ago(char.bankTime), Ago(char.mailTime), Ago(char.auctionTime))
		end
		if db.accountBankTime then
			ns.Print("Account bank: %s", Ago(db.accountBankTime))
		end
		local guild = GuildKey()
		if db.settings.guildBank and guild and db.guildBanks[guild] then
			ns.Print("Guild bank (%s): %s", guild, Ago(db.guildBanks[guild].time))
		end
	elseif cmd == "forget" and rest ~= "" then
		local key = ns.Find(rest)
		if not key then
			ns.Print("%s isn't one of your characters.", rest)
		elseif key == ns.charKey then
			ns.Print("You can't forget the character you're playing.")
		else
			db.chars[key] = nil
			ns.Print("Forgot %s.", key)
		end
	else
		ns.Print("/itemcount shows when each character's bank, mail and auctions were last counted. /itemcount forget <name> drops a character you deleted.")
	end
end
