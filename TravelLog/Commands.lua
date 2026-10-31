-- Slash commands: /tl (or /travellog). /tl alone opens or closes the window.
local _, ns = ...

function ns.Count(n)
	local s = tostring(math.floor((n or 0) + 0.5))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^(-?),", "%1"))
end
local Count = ns.Count

-- Subcommands added with ns.Command, in the order they were added.
local commands, order = {}, {}

-- Adds "/tl <name> ...". run(arg, text) does it, and returns false when arg
-- isn't valid, which shows the help: arg is the rest of the line in lower
-- case, text the same as typed. help is its line there, after "/tl ", or a
-- function returning that line.
function ns.Command(name, help, run)
	if not commands[name] then
		order[#order + 1] = name
	end
	commands[name] = { help = help, run = run }
end

--------------------------------------------------------------------------------
-- /tl stats
--------------------------------------------------------------------------------

-- Friends' characters by key, filled by TravelLog_Share and saved there:
-- profiles like ns.db.chars' (name, realm, class, race, level, stats) plus
-- when they arrived. They're never counted as yours.
ns.friends = {}

-- Every character's key ("Name-Realm"), the one you're on first, then the
-- others alphabetically, then with friends set your friends' characters.
function ns.Characters(friends)
	local list = {}
	for key in pairs(ns.db.chars) do
		if key ~= ns.charKey then
			list[#list + 1] = key
		end
	end
	table.sort(list)
	table.insert(list, 1, ns.charKey)
	if friends then
		local theirs = {}
		for key in pairs(ns.friends) do
			if not ns.db.chars[key] then
				theirs[#theirs + 1] = key
			end
		end
		table.sort(theirs)
		for _, key in ipairs(theirs) do
			list[#list + 1] = key
		end
	end
	return list
end

-- A character's profile: yours, or a friend's.
function ns.Profile(key)
	return ns.db.chars[key] or ns.friends[key]
end

-- "Bob-Forever, level 12, a friend's from 5m ago"
function ns.FriendText(key)
	local friend = ns.friends[key]
	return ("%s, level %d, a friend's from %s ago"):format(key, friend.level or 0, ns.Ago(friend.received or time()))
end

-- Adds from's counters into into: numbers summed, nested tables merged,
-- anything else kept from the first character that has it.
local function AddUp(into, from)
	for k, v in pairs(from) do
		if type(v) == "table" then
			into[k] = AddUp(type(into[k]) == "table" and into[k] or {}, v)
		elseif type(v) == "number" and type(into[k]) == "number" then
			into[k] = into[k] + v
		elseif into[k] == nil then
			into[k] = v
		end
	end
	return into
end

-- A character's totals, a friend's too, or with no key all of yours added up.
function ns.StatsFor(key)
	if key then
		return key == ns.charKey and ns.stats or (ns.Profile(key) or {}).stats or {}
	end
	local total = {}
	for _, profile in pairs(ns.db.chars) do
		AddUp(total, profile.stats or {})
	end
	return total
end

-- Subzones visited, counted across zones. Added up, a place visited by
-- several characters counts once.
function ns.PlacesVisited(st)
	local places = 0
	for _, subzones in pairs((st or ns.stats).places or {}) do
		for _ in pairs(subzones) do
			places = places + 1
		end
	end
	return places
end

-- Items that left the bags, by how: "3 traded, 1 mailed, 0 auctioned, 2 destroyed".
function ns.GivenText(st)
	local given = (st or ns.stats).given or {}
	return ("%s traded, %s mailed, %s auctioned, %s destroyed"):format(
		Count(given.trade), Count(given.mail), Count(given.auction), Count(given.destroy))
end

-- Items used up: "34, 12 of them in crafts".
function ns.UsedText(st)
	local used = (st or ns.stats).used or {}
	return ("%s, %s of them in crafts"):format(Count((used.items or 0) + (used.crafting or 0)), Count(used.crafting))
end

-- How auctioned items ended: "15 sold, 5 expired, 1 cancelled".
function ns.AuctionsText(st)
	local a = st.auctions or {}
	return ("%s sold, %s expired, %s cancelled"):format(Count(a.sold), Count(a.expired), Count(a.cancelled))
end

-- Items moved to and from the guild bank: "4 deposited, 2 withdrawn".
function ns.GuildBankText(st)
	local g = st.guildBank or {}
	return ("%s deposited, %s withdrawn"):format(Count(g.deposited), Count(g.withdrawn))
end

-- Loot rolls by outcome: "2 won, 5 lost, 9 passed".
function ns.RollsText(st)
	local rolls = st.rolls or {}
	return ("%s won, %s lost, %s passed"):format(Count((st.received or {}).roll), Count(rolls.lost), Count(rolls.passed))
end

-- Deaths, and what killed you when it wasn't a mob: "4 (1 falling, 1 drowning, 2 by players)".
function ns.DeathsText(st)
	local causes = {}
	for _, cause in ipairs({ "falling", "drowning", "fatigue", "fire", "lava", "slime", "player" }) do
		local n = (st.deathCauses or {})[cause]
		if n then
			causes[#causes + 1] = Count(n) .. " " .. (cause == "player" and (n == 1 and "by a player" or "by players") or cause)
		end
	end
	local text = Count(st.deaths)
	return #causes > 0 and ("%s (%s)"):format(text, table.concat(causes, ", ")) or text
end

-- How you came back: "corpse run 2, spirit healer 1, by a player 1, self-res 0; 12m dead".
function ns.RevivalsText(st)
	local r = st.revives or {}
	local text = ("corpse run %s, spirit healer %s, by a player %s, self-res %s"):format(
		Count(r.corpse), Count(r.spirithealer), Count(r.player), Count(r.selfres))
	return (st.deadTime or 0) > 0 and ("%s; %s dead"):format(text, ns.Duration(st.deadTime)) or text
end

-- Guild changes, after the character you're on's guild: "Wanderers
-- (Officer); joined 2, left 1, kicked out 0, promoted 1, demoted 0".
function ns.GuildText(st, key)
	local g = st.guilds or {}
	local text = ("joined %s, left %s, kicked out %s, promoted %s, demoted %s"):format(
		Count(g.joined), Count(g.left), Count(g.kicked), Count(g.promoted), Count(g.demoted))
	local now = key == ns.charKey and ns.char.guild or {}
	if now.name then
		return ("%s (%s); %s"):format(now.name, now.rank or "?", text)
	end
	return text
end

-- Legacy Challenges earned and their points: "12 earned, 120 points".
function ns.ChallengesText(st)
	return ("%s earned, %s points"):format(Count(st.achievements), Count(st.achievementPoints))
end

local ZONE_STATES = {
	{ "combat", "combat" }, { "dead", "dead" }, { "afk", "AFK" }, { "flight", "flying" }, { "group", "grouped" },
}

-- Time logged in per zone, longest first: "Elwynn Forest 3h 12m (combat
-- 20m, grouped 1h 5m), Westfall 45m". With most, only that many zones and
-- how many more, without the states. States under a minute are left out.
function ns.ZoneTimeText(st, most)
	local list = {}
	for zone, seconds in pairs(st.zoneTime or {}) do
		list[#list + 1] = { zone = zone, seconds = seconds }
	end
	if #list == 0 then
		return "none"
	end
	table.sort(list, function(a, b)
		if a.seconds ~= b.seconds then
			return a.seconds > b.seconds
		end
		return a.zone < b.zone
	end)
	local parts = {}
	for i, z in ipairs(list) do
		if most and i > most then
			parts[#parts + 1] = ("%d more"):format(#list - most)
			break
		end
		local text = ("%s %s"):format(z.zone, ns.Duration(z.seconds))
		if not most then
			local states = {}
			for _, s in ipairs(ZONE_STATES) do
				local seconds = ((st.zoneStateTime or {})[s[1]] or {})[z.zone] or 0
				if seconds >= 60 then
					states[#states + 1] = ("%s %s"):format(s[2], ns.Duration(seconds))
				end
			end
			if #states > 0 then
				text = ("%s (%s)"):format(text, table.concat(states, ", "))
			end
		end
		parts[i] = text
	end
	return table.concat(parts, ", ")
end

-- Reputation gained and lost per faction, most changed first: "Stormwind
-- +800, Booty Bay +200 -600". With most, only that many factions and how
-- many more.
function ns.ReputationText(st, most)
	local list = {}
	for faction, t in pairs(st.reputation or {}) do
		list[#list + 1] = { faction = faction, gained = t.gained or 0, lost = t.lost or 0 }
	end
	if #list == 0 then
		return "none"
	end
	table.sort(list, function(a, b)
		local x, y = a.gained + a.lost, b.gained + b.lost
		if x ~= y then
			return x > y
		end
		return a.faction < b.faction
	end)
	local parts = {}
	for i, r in ipairs(list) do
		if most and i > most then
			parts[#parts + 1] = ("%d more"):format(#list - most)
			break
		end
		local text = r.faction
		if r.gained > 0 then text = text .. " +" .. Count(r.gained) end
		if r.lost > 0 then text = text .. " -" .. Count(r.lost) end
		parts[i] = text
	end
	return table.concat(parts, ", ")
end

-- Where experience came from, largest first: "quests 2,000, kills 1,000,
-- rested 1,000, other 300", or "" with none. xp is { total, quests, kills,
-- discoveries, rested }; other is what the XP bar gained beyond those. The
-- rested bonus comes with kill XP, so it's taken out of kills, and out of
-- other for kills the chat didn't show.
function ns.XPSources(xp)
	xp = xp or {}
	local total, quests, discoveries = xp.total or 0, xp.quests or 0, xp.discoveries or 0
	local rested = math.min(xp.rested or 0, math.max(total - quests - discoveries, 0))
	local list = {
		{ source = "quests", amount = quests },
		{ source = "kills", amount = math.max((xp.kills or 0) - rested, 0) },
		{ source = "discoveries", amount = discoveries },
		{ source = "rested", amount = rested },
	}
	local known = 0
	for _, s in ipairs(list) do
		known = known + s.amount
	end
	list[#list + 1] = { source = "other", amount = math.max(total - known, 0) }
	table.sort(list, function(a, b) return a.amount > b.amount end)
	local parts = {}
	for _, s in ipairs(list) do
		if s.amount > 0 then
			parts[#parts + 1] = ("%s %s"):format(s.source, Count(s.amount))
		end
	end
	return table.concat(parts, ", ")
end

-- "3,300: quests 2,000, kills 1,000, other 300"
function ns.XPText(xp)
	local sources = ns.XPSources(xp)
	local total = Count(math.max((xp or {}).total or 0, 0))
	return sources ~= "" and ("%s: %s"):format(total, sources) or total
end

-- Money gained or spent ("gained" or "spent") with its reasons, largest
-- first: "5g 20s 0c: quest 3g 0s 0c, loot 2g 20s 0c".
function ns.MoneyByReason(st, way)
	local list, total = {}, 0
	for reason, t in pairs((st or ns.stats).money or {}) do
		local amount = t[way] or 0
		if amount > 0 then
			list[#list + 1] = { reason = reason, amount = amount }
			total = total + amount
		end
	end
	table.sort(list, function(a, b) return a.amount > b.amount end)
	local parts = {}
	for i, r in ipairs(list) do
		parts[i] = ("%s %s"):format(ns.MONEY_REASONS[r.reason] or r.reason, ns.MoneyText(r.amount))
	end
	return #parts > 0 and ("%s: %s"):format(ns.MoneyText(total), table.concat(parts, ", ")) or ns.MoneyText(0)
end

-- The character a /tl stats argument names: "Name" or "Name-Realm", yours
-- before a friend's.
local function FindCharacter(arg)
	for _, key in ipairs(ns.Characters(true)) do
		if key:lower() == arg or (ns.Profile(key).name or ""):lower() == arg then
			return key
		end
	end
end

local function ShowStats(arg)
	local key = ns.charKey
	if arg == "all" then
		key = nil
	elseif arg ~= "" then
		key = FindCharacter(arg)
		if not key then
			ns.Print("no character \"%s\". Known: %s", arg, table.concat(ns.Characters(true), ", "))
			return
		end
	end
	local st = ns.StatsFor(key)
	if key == ns.charKey then
		ns.Print("%s, level %d %s %s", key, ns.profile.level or 0, UnitRace("player"), UnitClass("player"))
		local total, level = ns.Played()
		if total then
			ns.Print("Played %s, %s at this level", ns.Duration(total), ns.Duration(level))
		end
	elseif ns.db.chars[key] then
		ns.Print("%s, level %d", key, ns.db.chars[key].level or 0)
	elseif key then
		ns.Print("%s", ns.FriendText(key))
	else
		ns.Print("All %d characters", #ns.Characters())
	end

	local loot = st.loot or {}
	ns.Print("Loot: %s items from %s corpses/chests/nodes, plus %s in coins",
		Count(loot.items), Count(loot.opened), ns.MoneyText(loot.money))

	local v = st.vendor or {}
	ns.Print("Vendors: %s bought, %s sold, %s repairs; spent %s, earned %s",
		Count(v.bought), Count(v.sold), Count(v.repairs),
		ns.MoneyText((v.spent or 0) + (v.repairCost or 0)), ns.MoneyText(v.earned))
	ns.Print("Rolls: %s", ns.RollsText(st))
	ns.Print("Items out: %s", ns.GivenText(st))
	ns.Print("Items used: %s", ns.UsedText(st))
	ns.Print("Auctioned items: %s", ns.AuctionsText(st))
	ns.Print("Guild bank items: %s", ns.GuildBankText(st))
	ns.Print("Money in: %s", ns.MoneyByReason(st, "gained"))
	ns.Print("Money out: %s", ns.MoneyByReason(st, "spent"))

	local quests = st.quests or {}
	local bosses = st.bosses or {}
	ns.Print("Deaths %s, kills %s, bosses killed %s, wipes %s, quests done %s, failed %s, flights %s, places visited %s",
		ns.DeathsText(st), Count(st.kills), Count(bosses.kill), Count(bosses.wipe), Count(quests.completed),
		Count(quests.failed), Count(st.flights), Count(ns.PlacesVisited(st)))
	ns.Print("XP: %s", ns.XPText(st.experience))
	ns.Print("Came back: %s", ns.RevivalsText(st))
	local duels = st.duels or {}
	local bgs = st.battlegrounds or {}
	ns.Print("Duels won %s, lost %s, no winner %s; battlegrounds won %s, lost %s, drawn %s, left %s; honorable kills %s, honor %s",
		Count(duels.won), Count(duels.lost), Count(duels.interrupted),
		Count(bgs.won), Count(bgs.lost), Count(bgs.draw), Count(bgs.left), Count(st.honorKills), Count(st.honor))
	ns.Print("Guild: %s", ns.GuildText(st, key))
	local instances = st.instances or {}
	ns.Print("Hearths %s, teleports %s, summons %s, boat rides %s, dungeons %s, raids %s, %s inside, instance resets %s, lockouts %s, rested stays %s, %s resting, screenshots %s, notes %s",
		Count(st.hearths), Count(st.teleports), Count(st.summons), Count(st.boats),
		Count(instances.dungeon), Count(instances.raid), ns.Duration(st.instanceTime or 0),
		Count(st.instanceResets), Count(st.lockouts),
		Count(st.rests), ns.Duration(st.restTime or 0), Count(st.screenshots), Count(st.notes))
	ns.Print("Time by zone: %s", ns.ZoneTimeText(st))
	ns.Print("Spells learned %s, new skills %s, skill points %s, talent points %s, flight paths found %s, mounts %s, pets tamed %s, pet levels %s, pet deaths %s, pets abandoned %s, new gear %s, bags %s, enchants %s",
		Count(st.spells), Count(st.skills), Count(st.skillups), Count(st.talents), Count(st.flightPaths), Count(st.mounts),
		Count(st.tames), Count(st.petLevels), Count(st.petDeaths), Count(st.petAbandons), Count(st.gear), Count(st.bags), Count(st.enchants))
	ns.Print("Legacy Challenges: %s", ns.ChallengesText(st))
	ns.Print("World buffs: %s", Count(st.worldBuffs))
	ns.Print("Reputation: %s", ns.ReputationText(st))

	-- Companion addons add their own lines here, for these totals and this
	-- character (nil for all of them).
	ns.Fire("TL_STATS", st, key)

	if key == ns.charKey then
		ns.Print("In this character's file: %s sessions, %s log entries",
			Count(#ns.char.sessions), Count(#ns.char.log))
	end
end

--------------------------------------------------------------------------------
-- /tl log
--------------------------------------------------------------------------------

local function Item(item, count)
	if count and count > 1 then
		return ("%sx%d"):format(item, count)
	end
	return item or "?"
end

local function Items(items)
	local parts = {}
	for _, it in ipairs(items or {}) do
		parts[#parts + 1] = Item(it.item, it.count)
	end
	return table.concat(parts, ", ")
end

-- Inventory slots by number, for equip entries.
ns.SLOT_NAMES = {
	"head", "neck", "shoulder", "shirt", "chest", "waist", "legs", "feet", "wrist", "hands",
	"finger", "finger", "trinket", "trinket", "back", "main hand", "off hand", "ranged", "tabard",
}
local SLOT_NAMES = ns.SLOT_NAMES

-- "4:05" for times under an hour, "1h 12m" from there.
local function Clock(s)
	if s >= 3600 then
		return ns.Duration(s)
	end
	return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

local RESET_FAILED = {
	inside = "players still inside", offline = "players offline in your party", zoning = "players entering an instance",
}

local DEATH_CAUSE = {
	falling = "Fell to death", drowning = "Drowned", fatigue = "Died of fatigue",
	fire = "Burned to death", lava = "Died in lava", slime = "Died in slime",
}

-- Adds what got you there, e.g. " (Teleport: Stormwind)".
local function Via(text, e)
	return e.via and ("%s (%s)"):format(text, e.via) or text
end

-- A pet by its name, or "your Wolf" when it's named after its family.
local function PetName(e)
	if e.name and e.name ~= e.family then
		return e.name
	end
	return e.family and "your " .. e.family or "your pet"
end

-- "Fang (level 12 Wolf)", or "your level 12 Wolf".
local function PetText(e)
	if e.name and e.name ~= e.family then
		local about = {}
		if e.level then about[#about + 1] = "level " .. e.level end
		if e.family then about[#about + 1] = e.family end
		return #about > 0 and ("%s (%s)"):format(e.name, table.concat(about, " ")) or e.name
	end
	return ("your %s%s"):format(e.level and "level " .. e.level .. " " or "", e.family or "pet")
end

local AUCTION_ENDS = { sold = "Sold at auction:", expired = "Auction expired:", cancelled = "Cancelled auction:" }

local DESCRIBE = {
	area = function(e)
		return (e.first and "First visit to %s" or "Entered %s"):format(e.subzone or e.zone or "?")
	end,
	loot = function(e)
		local what = Items(e.items)
		if e.money then
			what = what == "" and ns.MoneyText(e.money) or what .. ", " .. ns.MoneyText(e.money)
		end
		local text = ("Looted %s from %s"):format(what, e.source or e.sourceType or "?")
		if e.lastHere then
			local by = e.lastBy and " by " .. e.lastBy or ""
			text = text .. (" (looted here %s before%s)"):format(ns.Ago(e.lastHere, e.time), by)
		end
		return text
	end,
	receive = function(e)
		local how = e.roll and ("won with a roll of %d"):format(e.roll) or e.how or "?"
		local from = e.partner or e.sender
		from = from and " from " .. from or e.materials and " from " .. Items(e.materials) or ""
		return ("Received %s (%s%s)"):format(Item(e.item, e.count), how, from)
	end,
	use = function(e)
		local text = "Used " .. Item(e.item, e.count)
		return e.spell and ("%s (%s)"):format(text, e.spell) or text
	end,
	roll = function(e)
		local mine = e.roll and ("%s %d"):format(e.choice, e.roll) or e.choice or "?"
		local won = e.winner and ("won by %s%s"):format(e.winner, e.winnerRoll and " with " .. e.winnerRoll or "")
			or "everyone passed"
		return ("%s %s (%s; %s)"):format(e.choice == "pass" and "Passed on" or "Lost the roll for", Item(e.item), mine, won)
	end,
	buy = function(e) return ("Bought %s for %s from %s"):format(Item(e.item, e.count), ns.MoneyText(e.price), e.vendor or "?") end,
	sell = function(e) return ("Sold %s for %s to %s"):format(Item(e.item, e.count), ns.MoneyText(e.price), e.vendor or "?") end,
	buyback = function(e) return ("Bought back %s for %s"):format(Item(e.item, e.count), ns.MoneyText(e.price)) end,
	repair = function(e) return ("Repaired for %s"):format(ns.MoneyText(e.price)) end,
	give = function(e) return ("Gave %s to %s"):format(Items(e.items), e.partner or "?") end,
	send = function(e) return ("Mailed %s to %s"):format(Items(e.items), e.recipient or "?") end,
	post = function(e)
		local text = ("Posted %s at auction"):format(Item(e.item, e.count))
		if e.buyout then text = ("%s, buyout %s"):format(text, ns.MoneyText(e.buyout)) end
		if e.bid then text = ("%s, bid %s"):format(text, ns.MoneyText(e.bid)) end
		local ended = {}
		for _, result in ipairs({ "sold", "expired", "cancelled" }) do
			if e[result] then ended[#ended + 1] = ("%d %s"):format(e[result], result) end
		end
		return #ended > 0 and ("%s: %s"):format(text, table.concat(ended, ", ")) or text
	end,
	auction = function(e)
		local text = ("%s %s"):format(AUCTION_ENDS[e.result] or "Auction ended:", Item(e.item, e.count))
		if e.price then text = ("%s for %s"):format(text, ns.MoneyText(e.price)) end
		if e.buyer then text = ("%s to %s"):format(text, e.buyer) end
		return e.posted and ("%s (posted %s before)"):format(text, ns.Ago(e.posted, e.time)) or text
	end,
	destroy = function(e) return ("Destroyed %s"):format(Item(e.item, e.count)) end,
	guildbank = function(e)
		local parts = {}
		if e.deposited then parts[#parts + 1] = "deposited " .. Items(e.deposited) end
		if e.withdrawn then parts[#parts + 1] = "withdrew " .. Items(e.withdrawn) end
		return ("Guild bank%s: %s"):format(e.guild and " of " .. e.guild or "", table.concat(parts, "; "))
	end,
	money = function(e)
		local who = e.partner or e.sender or e.recipient
		who = who and (e.amount > 0 and " from " or " to ") .. who or ""
		local reason = ns.MONEY_REASONS[e.reason] or e.reason
		reason = e.item and ("%s: %s"):format(reason, e.item) or reason
		return ("%s %s (%s%s)"):format(e.amount > 0 and "Got" or "Paid", ns.MoneyText(math.abs(e.amount)), reason, who)
	end,
	bankslot = function(e)
		return ("Bought %sbank slot %d for %s"):format(e.bank == "account" and "account " or "", e.slot or 0, ns.MoneyText(e.price))
	end,
	flight = function(e) return ("Flew from %s to %s for %s"):format(e.from or "?", e.to or "?", ns.MoneyText(e.price)) end,
	landed = function(e) return e.seconds and ("Landed after %s"):format(Clock(e.seconds)) or "Landed" end,
	hearth = function(e)
		local text = e.from and ("Hearthed from %s to %s"):format(e.from, e.to or "?") or ("Hearthed to %s"):format(e.to or "?")
		return Via(text, e)
	end,
	teleport = function(e) return Via(("Teleported from %s to %s"):format(e.from or "?", e.to or "?"), e) end,
	summon = function(e)
		local text = ("Summoned from %s to %s"):format(e.from or "?", e.to or "?")
		return e.by and ("%s by %s"):format(text, e.by) or text
	end,
	board = function(e) return ("Boarded a boat or zeppelin at %s"):format(e.subzone or e.zone or "?") end,
	disembark = function(e)
		local text = ("Rode a boat or zeppelin from %s to %s"):format(e.from or "?", e.to or "?")
		return e.seconds and ("%s in %s"):format(text, Clock(e.seconds)) or text
	end,
	instance = function(e)
		local about = e.difficulty and e.kind .. ", " .. e.difficulty or e.kind
		return ("Entered %s (%s)"):format(e.name or "?", about or "instance")
	end,
	instanceleave = function(e)
		local text = ("Left %s after %s"):format(e.name or "?", ns.Duration(e.seconds or 0))
		if e.kills or e.wipes then
			text = ("%s: %d bosses killed, %d wipes"):format(text, e.kills or 0, e.wipes or 0)
		end
		return text
	end,
	instancereset = function(e)
		if e.failed then
			return ("Couldn't reset %s: %s"):format(e.name or "?", RESET_FAILED[e.failed] or e.failed)
		end
		return ("Reset %s"):format(e.name or "?")
	end,
	lockout = function(e)
		local about = e.difficulty and e.kind .. ", " .. e.difficulty or e.kind or "instance"
		local text = ("Saved to %s (%s)"):format(e.name or "?", about)
		if e.lockout then text = ("%s, ID %s"):format(text, e.lockout) end
		return e.resets and ("%s, resets %s"):format(text, date("%Y-%m-%d %H:%M", e.resets)) or text
	end,
	boss = function(e)
		local name = e.name or (e.id and "boss " .. e.id) or "a boss"
		local text = e.result == "kill" and "Killed " .. name or "Wiped on " .. name
		if e.seconds then text = ("%s %s %s"):format(text, e.result == "kill" and "in" or "after", Clock(e.seconds)) end
		local about = {}
		if e.difficulty then about[#about + 1] = e.difficulty end
		if e.size then about[#about + 1] = e.size .. " players" end
		if #about > 0 then text = ("%s (%s)"):format(text, table.concat(about, ", ")) end
		return e.used and ("%s; used %s"):format(text, Items(e.used)) or text
	end,
	bind = function(e) return ("Hearthstone set to %s"):format(e.place or "?") end,
	rest = function(e) return ("Started resting in %s"):format(e.subzone or e.zone or "?") end,
	restleave = function(e)
		local text = ("Stopped resting after %s"):format(ns.Duration(e.seconds or 0))
		return e.rested and ("%s, %s XP rested"):format(text, Count(e.rested)) or text
	end,
	screenshot = function(e)
		local why = e.auto == "level" and "level " .. (e.what or "up")
			or e.auto == "boss" and (e.what or "boss kill")
			or e.auto == "achievement" and (e.what or "Legacy Challenge")
		return why and ("Screenshot (%s) %s"):format(why, e.file or "") or "Screenshot " .. (e.file or "")
	end,
	note = function(e) return "Note: " .. (e.text or "") end,
	death = function(e)
		local text = DEATH_CAUSE[e.cause] or "Died"
		if e.killer then
			-- "Killed by Bob (player, Fireball, 120 damage)"
			local about = {}
			if e.killerType == "Player" or e.killerType == "Pet" then about[1] = e.killerType:lower() end
			if e.spell then about[#about + 1] = e.spell end
			if e.amount then about[#about + 1] = Count(e.amount) .. " damage" end
			text = "Killed by " .. e.killer
			if #about > 0 then text = ("%s (%s)"):format(text, table.concat(about, ", ")) end
		elseif e.target then
			text = ("%s fighting %s"):format(text, e.target)
		end
		return e.level and ("%s at level %d"):format(text, e.level) or text
	end,
	release = function() return "Released spirit" end,
	revive = function(e)
		local text = "Came back to life"
		if e.how == "corpse" then
			text = "Ran back to corpse"
		elseif e.how == "spirithealer" then
			text = "Revived by a spirit healer"
		elseif e.how == "player" then
			text = "Resurrected by " .. (e.by or "another player")
		elseif e.how == "selfres" then
			text = "Came back with " .. (e.spell or "a self-resurrection")
		end
		if e.took then
			text = ("%s after %s"):format(text, Clock(e.took))
			if e.ghost then text = ("%s (%s as a ghost)"):format(text, Clock(e.ghost)) end
		end
		if e.sickness then text = text .. ", with resurrection sickness" end
		if e.durability then text = ("%s, lost %d%% durability"):format(text, e.durability) end
		return text
	end,
	level = function(e)
		local text = ("Reached level %d"):format(e.level)
		if e.took then text = ("%s after %s at level %d"):format(text, ns.Duration(e.took), e.level - 1) end
		local gains = ns.LevelGains(e)
		return gains and ("%s: %s"):format(text, gains) or text
	end,
	quest = function(e) return ("Accepted quest: %s"):format(e.title or e.id) end,
	questdone = function(e) return ("Completed quest: %s"):format(e.title or e.id) end,
	questabandon = function(e) return ("Abandoned quest: %s"):format(e.title or e.id) end,
	questfail = function(e)
		local text = ("Failed quest: %s"):format(e.title or e.id)
		return e.reason == "time" and text .. " (ran out of time)" or text
	end,
	kill = function(e) return ("Killed %s (+%s xp)"):format(e.name, e.xp or "?") end,
	discover = function(e) return ("Discovered %s"):format(e.place) end,
	duel = function(e)
		local opponent = e.opponent or "?"
		local text = e.result == "won" and ("Won a duel against %s"):format(opponent)
			or e.result == "lost" and ("Lost a duel to %s"):format(opponent)
			or ("Duel with %s ended without a winner"):format(opponent)
		local notes = {}
		if e.fled then notes[#notes + 1] = e.result == "won" and "they fled" or "you fled" end
		if e.challenger then notes[#notes + 1] = e.challenger == "you" and "you challenged" or "they challenged" end
		return #notes > 0 and ("%s (%s)"):format(text, table.concat(notes, ", ")) or text
	end,
	honorkill = function(e)
		if not e.name then return "Honorable kill" end
		local text = "Honorable kill: " .. e.name
		if e.rank then text = ("%s (%s)"):format(text, e.rank) end
		return e.honor and ("%s, +%d honor"):format(text, e.honor) or text
	end,
	honor = function(e) return ("Awarded %d honor"):format(e.honor) end,
	pvprank = function(e)
		local text = ("PvP rank %d"):format(e.rank)
		if e.title then text = ("%s, %s"):format(text, e.title) end
		text = ("%s (%s from %d"):format(text, e.rank > e.old and "up" or "down", e.old)
		return (e.newSeason and "%s, new season)" or "%s)"):format(text)
	end,
	battleground = function(e)
		local name = e.name or "a battleground"
		local text = e.result == "won" and "Won " .. name
			or e.result == "lost" and "Lost " .. name
			or e.result == "draw" and "Draw in " .. name
			or ("Left %s before the end"):format(name)
		if e.seconds then text = ("%s after %s"):format(text, ns.Duration(e.seconds)) end
		local score = {}
		local function Add(n, one, many)
			if n then score[#score + 1] = ("%d %s"):format(n, n == 1 and one or many) end
		end
		Add(e.killingBlows, "killing blow", "killing blows")
		Add(e.honorableKills, "honorable kill", "honorable kills")
		Add(e.deaths, "death", "deaths")
		if e.honor then score[#score + 1] = ("+%d honor"):format(e.honor) end
		return #score > 0 and ("%s: %s"):format(text, table.concat(score, ", ")) or text
	end,
	guildjoin = function(e)
		local text = ("Joined %s"):format(e.guild or "a guild")
		if e.rank then text = ("%s as %s"):format(text, e.rank) end
		if e.founder then return text .. " (founder)" end
		return e.by and ("%s (invited by %s)"):format(text, e.by) or text
	end,
	guildleave = function(e)
		local guild = e.guild or "the guild"
		local text = e.how == "left" and ("Left %s"):format(guild)
			or e.how == "kicked" and ("Kicked out of %s"):format(guild)
			or e.how == "disbanded" and ("%s was disbanded"):format(guild)
			or ("No longer in %s"):format(guild)
		if e.by then text = ("%s by %s"):format(text, e.by) end
		return e.seconds and ("%s after %s"):format(text, ns.Duration(e.seconds)) or text
	end,
	guildrank = function(e)
		local text = ("%s to %s in %s"):format(e.change == "promoted" and "Promoted" or "Demoted",
			e.rank or "?", e.guild or "the guild")
		if e.by then text = ("%s by %s"):format(text, e.by) end
		return e.from and ("%s (was %s)"):format(text, e.from) or text
	end,
	spell = function(e)
		local text = "Learned " .. (e.name or e.id or "?")
		if e.rank then text = ("%s (%s)"):format(text, e.rank) end
		if e.trainer then text = ("%s from %s"):format(text, e.trainer) end
		return e.cost and ("%s for %s"):format(text, ns.MoneyText(e.cost)) or text
	end,
	skill = function(e) return ("Learned skill: %s"):format(e.name or e.id) end,
	skillup = function(e) return ("%s reached %d"):format(e.name or e.id, e.rank) end,
	talent = function(e)
		local text = ("Talent: %s %d/%d"):format(e.name or e.id or "?", e.rank, e.max or e.rank)
		if e.tree then text = ("%s (%s)"):format(text, e.tree) end
		return ("%s at level %d"):format(text, e.level or 0)
	end,
	talentreset = function(e)
		local text = e.spent == 0 and "Reset talents" or "Unlearned talents"
		return ("%s: %d points back at level %d"):format(text, e.points or 0, e.level or 0)
	end,
	taxipath = function(e) return e.npc and ("Found the flight path at %s"):format(e.npc) or "Found a flight path" end,
	standing = function(e) return ("Now %s with %s"):format(e.standing, e.faction) end,
	mount = function(e) return (e.first and "First mount: %s" or "First ride on %s"):format(e.name or e.id) end,
	tame = function(e)
		local text = (e.first and "First pet: %s" or "Tamed %s"):format(e.name or e.id or "a beast")
		local about = {}
		if e.level then about[#about + 1] = "level " .. e.level end
		if e.family then about[#about + 1] = e.family end
		if #about > 0 then text = ("%s (%s)"):format(text, table.concat(about, " ")) end
		return e.pet and ("%s, named %s"):format(text, e.pet) or text
	end,
	petlevel = function(e)
		local text = (("%s reached level %d"):format(PetName(e), e.level or 0):gsub("^%l", string.upper))
		return e.family and e.name ~= e.family and ("%s (%s)"):format(text, e.family) or text
	end,
	petdeath = function(e) return (("%s died"):format(PetText(e)):gsub("^%l", string.upper)) end,
	petrevive = function(e) return "Revived " .. PetText(e) end,
	petabandon = function(e) return "Abandoned " .. PetText(e) end,
	petstable = function(e) return "Stabled " .. PetText(e) end,
	petunstable = function(e) return ("Took %s out of the stable"):format(PetText(e)) end,
	achievement = function(e)
		local text = "Legacy Challenge: " .. (e.name or e.id or "?")
		local about = {}
		if e.points then about[#about + 1] = e.points .. " points" end
		if e.category then about[#about + 1] = e.category end
		if e.guild then about[#about + 1] = "guild" end
		if e.already then about[#about + 1] = "already earned on another character" end
		if #about > 0 then text = ("%s (%s)"):format(text, table.concat(about, ", ")) end
		return e.reward and ("%s; %s"):format(text, e.reward) or text
	end,
	worldbuff = function(e)
		local text = "Gained " .. (e.name or e.id or "a world buff")
		local about = {}
		if e.duration then about[#about + 1] = ns.Duration(e.duration) end
		if e.by then about[#about + 1] = "from " .. e.by end
		return #about > 0 and ("%s (%s)"):format(text, table.concat(about, ", ")) or text
	end,
	equip = function(e)
		local slot = SLOT_NAMES[e.slot] or "slot " .. tostring(e.slot)
		local text = ("Equipped %s (%s%s)"):format(e.item or "?", slot, e.ilvl and ", item level " .. e.ilvl or "")
		return e.replaced and ("%s, replacing %s"):format(text, e.replaced) or text
	end,
	enchant = function(e)
		local slot = SLOT_NAMES[e.slot] or "slot " .. tostring(e.slot)
		local text = ("Enchanted %s (%s): %s"):format(e.item or "?", slot, e.name or "enchant " .. tostring(e.enchant))
		return e.old and ("%s, replacing %s"):format(text, e.oldName or "enchant " .. e.old) or text
	end,
	bag = function(e)
		local text = ("Equipped bag %s%s"):format(e.item or "?", e.slots and (" (%d slots)"):format(e.slots) or "")
		return e.replaced and ("%s, replacing %s"):format(text, e.replaced) or text
	end,
}

-- A log entry as text, and where it happened.
function ns.Describe(e)
	local describe = DESCRIBE[e.type]
	local where = e.subzone or e.zone or "?"
	if e.x then
		where = ("%s (%.1f, %.1f)"):format(where, e.x, e.y)
	end
	return describe and describe(e) or e.type, where
end

-- The Log tab and /tl log share these categories and labels. Every current
-- event type belongs to one category; an unknown future type still appears
-- under All and remains searchable by its saved fields.
local LOG_GROUP = {
	area = "Travel", flight = "Travel", landed = "Travel", hearth = "Travel", bind = "Travel",
	teleport = "Travel", summon = "Travel", board = "Travel", disembark = "Travel",
	instance = "Travel", instanceleave = "Travel", instancereset = "Travel", lockout = "Travel", rest = "Travel",
	restleave = "Travel", screenshot = "Travel", note = "Travel",
	loot = "Loot", receive = "Loot", roll = "Loot", destroy = "Loot", use = "Loot",
	buy = "Trade", sell = "Trade", buyback = "Trade", repair = "Trade", money = "Trade",
	give = "Trade", send = "Trade", post = "Trade", auction = "Trade", bankslot = "Trade", guildbank = "Trade",
	death = "Life", release = "Life", revive = "Life", level = "Life", quest = "Life",
	questdone = "Life", questabandon = "Life", questfail = "Life", kill = "Life", discover = "Life",
	boss = "Life", duel = "Life", honorkill = "Life", honor = "Life", pvprank = "Life", battleground = "Life",
	guildjoin = "Life", guildleave = "Life", guildrank = "Life", worldbuff = "Life",
	spell = "Progress", skill = "Progress", skillup = "Progress", talent = "Progress",
	talentreset = "Progress", taxipath = "Progress",
	standing = "Progress", mount = "Progress", tame = "Progress", equip = "Progress",
	enchant = "Progress", bag = "Progress",
	petlevel = "Progress", petabandon = "Progress", petstable = "Progress", petunstable = "Progress",
	petdeath = "Progress", petrevive = "Progress",
	achievement = "Progress",
}
local LOG_LABEL = {
	area = "Area", loot = "Loot", receive = "Item", roll = "Roll", buy = "Purchase", sell = "Sale",
	buyback = "Buyback", repair = "Repair", give = "Given", send = "Mail sent",
	post = "Auction", auction = "Auction ended", destroy = "Destroyed", use = "Used", money = "Money", bankslot = "Bank slot", guildbank = "Guild bank",
	flight = "Flight",
	landed = "Landing", hearth = "Hearth", bind = "Hearth bind", teleport = "Teleport",
	summon = "Summon", board = "Boarding", disembark = "Arrival", instance = "Instance",
	instanceleave = "Instance left", instancereset = "Instance reset", lockout = "Lockout", rest = "Resting",
	restleave = "Resting ended", screenshot = "Screenshot", note = "Note", death = "Death",
	release = "Spirit release", revive = "Revival", level = "Level", quest = "Quest accepted",
	questdone = "Quest completed", questabandon = "Quest abandoned", questfail = "Quest failed", kill = "XP kill",
	discover = "Discovery", boss = "Boss", duel = "Duel", honorkill = "Honorable kill", honor = "Honor", pvprank = "PvP rank",
	battleground = "Battleground",
	guildjoin = "Guild joined", guildleave = "Guild left", guildrank = "Guild rank",
	worldbuff = "World buff", spell = "Spell",
	skill = "Skill", skillup = "Skill-up", talent = "Talent", talentreset = "Talent reset",
	taxipath = "Flight path", standing = "Reputation",
	mount = "Mount", tame = "Pet tamed", equip = "Gear", enchant = "Enchant", bag = "Bag",
	achievement = "Legacy Challenge",
	petdeath = "Pet death", petrevive = "Pet revived",
	petlevel = "Pet level", petabandon = "Pet abandoned", petstable = "Pet stabled", petunstable = "Pet unstabled",
}

function ns.LogGroup(e)
	return LOG_GROUP[e.type] or "Other"
end

function ns.LogTypeLabel(e)
	return LOG_LABEL[e.type] or e.type or "Event"
end

-- Add every scalar saved in the entry, including nested loot items. This
-- lets one search field match IDs and less prominent fields as well as the
-- human-readable description.
local function SearchValues(out, value, seen)
	local kind = type(value)
	if kind == "string" then
		value = ns.Clean(value)
		if value then out[#out + 1] = value end
	elseif kind == "number" or kind == "boolean" then
		out[#out + 1] = tostring(value)
	elseif kind == "table" and not seen[value] then
		seen[value] = true
		for key, child in pairs(value) do
			if type(key) == "string" then out[#out + 1] = key end
			SearchValues(out, child, seen)
		end
	end
end

-- True when an entry is in group (nil means All) and every word in query
-- occurs in its type, description, date, location or any saved field.
function ns.LogMatches(e, query, group)
	if group and ns.LogGroup(e) ~= group then
		return false
	end
	query = (query or ""):lower()
	if query == "" then
		return true
	end
	local text, where = ns.Describe(e)
	local values = { ns.LogTypeLabel(e), ns.LogGroup(e), text, where,
		date("%Y-%m-%d %H:%M", e.time) }
	SearchValues(values, e, {})
	local haystack = table.concat(values, " "):lower()
	for word in query:gmatch("%S+") do
		local found = haystack:find(word, 1, true)
		-- Natural plurals such as "deaths" and "quests" match their type.
		if not found and word:sub(-1) == "s" then
			found = haystack:find(word:sub(1, -2), 1, true)
		end
		if not found then
			return false
		end
	end
	return true
end

local function ShowLog(arg)
	-- A count is a number on its own, so "2026-10-19" is a search.
	local number, query = arg:match("^(%d+)$")
	if not number then
		number, query = arg:match("^(%d+)%s+(.+)$")
	end
	local limit = tonumber(number) or 15
	query = query or (number and "" or arg)
	local found = {} -- log positions, newest first
	if limit > 0 then
		for i = #ns.char.log, 1, -1 do
			if ns.LogMatches(ns.char.log[i], query) then
				found[#found + 1] = i
				if #found >= limit then break end
			end
		end
	end
	if query == "" then
		ns.Print("Last %d events:", #found)
	else
		ns.Print("Last %d events matching \"%s\":", #found, query)
	end
	for i = #found, 1, -1 do
		local e = ns.char.log[found[i]]
		local text, where = ns.Describe(e)
		print(("  |cff999999#%d|r  %s  %s  |cff999999%s|r"):format(found[i], date("%m-%d %H:%M", e.time), text, where))
	end
end

-- Log entry n as typed ("12" or "#12"), or nil and a message saying why not.
local function Entry(n)
	n = tonumber((n or ""):match("^#?(%d+)$"))
	if not n then
		return nil
	end
	local e = ns.char.log[n]
	if not e then
		ns.Print("no entry #%d: the log has %s (see /tl log)", n, Count(#ns.char.log))
		return false
	end
	return e, n
end

local function EntryText(e, n)
	local text, where = ns.Describe(e)
	return ("#%d %s  %s, %s"):format(n, date("%Y-%m-%d %H:%M", e.time), text, where)
end

--------------------------------------------------------------------------------
-- /tl note
--------------------------------------------------------------------------------

ns.Command("note", "note <text> - add a note to the log, stamped with the time and place", function(_, text)
	if text == "" then
		ns.Print("usage: /tl note <text>")
		return
	end
	ns.Log("note", { text = text })
	ns.Add(1, "notes")
	ns.Print("note added: %s", text)
end)

--------------------------------------------------------------------------------
-- /tl edit, /tl delete
--------------------------------------------------------------------------------

ns.Command("edit", "edit <#> <text> - change a note's text (# from /tl log)", function(_, text)
	local n, new = text:match("^(%S+)%s+(.+)$")
	local e, i = Entry(n)
	if e == nil then
		return false
	elseif not e then
		return
	elseif e.type ~= "note" then
		ns.Print("#%d isn't a note; only notes can be edited", i)
		return
	end
	e.text = new
	ns.version = ns.version + 1
	ns.Print("note changed: %s", new)
end)

-- The entry the last "/tl delete <#>" asked about, so the confirm can't
-- delete another one that took its number since.
local asked

ns.Command("delete", "delete <#> - delete one entry (# from /tl log); asks first", function(arg)
	local n, confirm = arg:match("^(%S+)%s*(.-)$")
	local e, i = Entry(n)
	if e == nil or (confirm ~= "" and confirm ~= "confirm") then
		return false
	elseif not e then
		return
	end
	if confirm == "" or asked ~= e then
		asked = e
		ns.Print("delete %s? Type /tl delete %d confirm", EntryText(e, i), i)
		return
	end
	asked = nil
	ns.Remove(e)
	ns.Print("deleted %s", EntryText(e, i))
end)

--------------------------------------------------------------------------------
-- Dispatch
--------------------------------------------------------------------------------

local function Help()
	ns.Print("commands:")
	print("  /tl - open or close the TravelLog window")
	print("  /tl stats [all|name] - totals for this character, all of yours, another or a friend's")
	print("  /tl log [n] [search] - the last matching events (default 15)")
	for _, name in ipairs(order) do
		local help = commands[name].help
		print("  /tl " .. (type(help) == "function" and help() or help))
	end
	print("  /tl wipe confirm - delete everything recorded for this character")
end

SLASH_TRAVELLOG1 = "/travellog"
SLASH_TRAVELLOG2 = "/tl"
SlashCmdList.TRAVELLOG = function(msg)
	if not ns.char then
		if ns.unreadable then
			ns.Print(ns.unreadable)
		end
		return
	end
	local command, text = msg:match("^%s*(%S*)%s*(.-)%s*$")
	command = command:lower()
	local arg = text:lower()
	if command == "" then
		ns.Toggle()
	elseif command == "stats" then
		ShowStats(arg)
	elseif command == "log" then
		ShowLog(arg)
	elseif command == "wipe" and arg == "confirm" then
		ns.db.chars[ns.charKey] = nil
		TravelLogCharDB = nil
		ns.Fire("TL_WIPE") -- companion addons drop their files too
		ReloadUI()
	elseif not (commands[command] and commands[command].run(arg, text) ~= false) then
		Help()
	end
end
