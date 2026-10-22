-- Sessions: one per login or reload, with how long it lasted, where it
-- started and ended, levels, money and experience gained, and what happened
-- in it. Shown in the History tab's
-- Sessions view and by /tl sessions.
local _, ns = ...

local Count = ns.Count

local HEIGHT = 320
local LIST_WIDTH = 410
local RATE_AFTER = 600 -- seconds a session must last before per-hour rates show

--------------------------------------------------------------------------------
-- Experience gained this session
--------------------------------------------------------------------------------

local lastXP, lastMax

local function ReadXP()
	return ns.Clean(UnitXP("player")), ns.Clean(UnitXPMax("player"))
end

ns.On("PLAYER_LOGIN", function()
	lastXP, lastMax = ReadXP()
end)

ns.On("PLAYER_XP_UPDATE", function(unit)
	if unit and unit ~= "player" then
		return
	end
	local xp, max = ReadXP()
	if not (xp and lastXP and lastMax) then
		lastXP, lastMax = xp, max
		return
	end
	-- Experience only drops when a level-up starts the bar over.
	local gained = xp >= lastXP and xp - lastXP or lastMax - lastXP + xp
	lastXP, lastMax = xp, max
	if gained > 0 then
		ns.session.xp = (ns.session.xp or 0) + gained
		ns.version = ns.version + 1
	end
end)

--------------------------------------------------------------------------------
-- Summaries
--------------------------------------------------------------------------------

-- Every session in this character's file, newest first, with what its log
-- entries add up to. The current session runs until now.
function ns.SessionSummaries()
	local now = time()
	local list = {}
	for i, s in ipairs(ns.char.sessions) do
		local current = s == ns.session
		local stop = current and now or s.stop
		local moneyEnd = current and GetMoney() or s.moneyEnd
		local here = current and ns.StampPlace({}) or {}
		list[i] = {
			start = s.start,
			stop = stop,
			current = current,
			level = s.level,
			levelEnd = current and UnitLevel("player") or s.levelEnd,
			money = moneyEnd and s.money and moneyEnd - s.money,
			xp = s.xp,
			from = s.subzone or s.zone,
			to = current and (here.subzone or here.zone) or s.subzoneEnd or s.zoneEnd,
			quests = 0, failed = 0, kills = 0, deaths = 0,
		}
	end

	-- Both lists are oldest first, so one pass matches entries to sessions.
	local j = 0
	for _, e in ipairs(ns.char.log) do
		while list[j + 1] and list[j + 1].start <= e.time do
			j = j + 1
		end
		local sum = list[j]
		if sum and (not sum.stop or e.time <= sum.stop) then
			if e.type == "questdone" then
				sum.quests = sum.quests + 1
			elseif e.type == "questfail" then
				sum.failed = sum.failed + 1
			elseif e.type == "kill" then
				sum.kills = sum.kills + 1
			elseif e.type == "death" then
				sum.deaths = sum.deaths + 1
			end
		end
	end

	local newest = {}
	for i = #list, 1, -1 do
		newest[#newest + 1] = list[i]
	end
	return newest
end

local function Plural(n, one)
	return ("%s %s%s"):format(Count(n), one, n == 1 and "" or "s")
end

local function Seconds(sum)
	return sum.stop and sum.stop - sum.start
end

-- "Goldshire to Old Town", or just "Goldshire" when it ended where it began.
local function Route(sum)
	if sum.from and sum.to then
		return sum.from == sum.to and sum.from or sum.from .. " to " .. sum.to
	end
	return sum.from and "from " .. sum.from or sum.to and "to " .. sum.to
end

-- "2h 12m, level 12 to 13, Goldshire to Old Town", or "Now, 45m, level 13,
-- Goldshire" for the current one.
local function Headline(sum)
	local seconds = Seconds(sum)
	local length = seconds and ns.Ago(sum.start, sum.stop) or "length unknown"
	local level
	if sum.levelEnd and sum.level and sum.levelEnd ~= sum.level then
		level = ("level %d to %d"):format(sum.level, sum.levelEnd)
	elseif sum.level then
		level = ("level %d"):format(sum.level)
	end
	local route = Route(sum)
	local text = length .. (level and ", " .. level or "") .. (route and ", " .. route or "")
	return sum.current and "|cff20ff20Now|r, " .. text or text
end

-- "+1g 20s 0c (54s 0c/h), 12,345 xp (5,600/h)"
local function Gains(sum)
	local seconds = Seconds(sum)
	local hours = seconds and seconds >= RATE_AFTER and seconds / 3600
	local parts = {}
	if sum.money and sum.money ~= 0 then
		local text = (sum.money > 0 and "+" or "") .. ns.MoneyText(sum.money)
		if hours then
			text = ("%s (%s/h)"):format(text, ns.MoneyText(math.floor(sum.money / hours + 0.5)))
		end
		parts[#parts + 1] = text
	end
	if sum.xp and sum.xp > 0 then
		local text = Count(sum.xp) .. " xp"
		if hours then
			text = ("%s (%s/h)"):format(text, Count(sum.xp / hours))
		end
		parts[#parts + 1] = text
	end
	return table.concat(parts, ", ")
end

-- "5 quests, 1 failed quest, 40 XP kills, 1 death"
local function Happenings(sum)
	local parts = {}
	if sum.quests > 0 then parts[#parts + 1] = Plural(sum.quests, "quest") end
	if sum.failed > 0 then parts[#parts + 1] = Plural(sum.failed, "failed quest") end
	if sum.kills > 0 then parts[#parts + 1] = Plural(sum.kills, "XP kill") end
	if sum.deaths > 0 then parts[#parts + 1] = Plural(sum.deaths, "death") end
	return table.concat(parts, ", ")
end

--------------------------------------------------------------------------------
-- /tl sessions
--------------------------------------------------------------------------------

ns.Command("sessions", "sessions [n] - the last n sessions (default 10)", function(arg)
	local limit = arg == "" and 10 or tonumber(arg)
	if not limit then
		return false
	end
	local found = ns.SessionSummaries()
	for i = #found, limit + 1, -1 do
		found[i] = nil
	end
	ns.Print("Last %s:", Plural(#found, "session"))
	for i = #found, 1, -1 do
		local sum = found[i]
		local parts = { date("%m-%d %H:%M", sum.start), Headline(sum) }
		for _, text in ipairs({ Gains(sum), Happenings(sum) }) do
			if text ~= "" then parts[#parts + 1] = text end
		end
		print("  " .. table.concat(parts, "  "))
	end
end)

--------------------------------------------------------------------------------
-- The Sessions view
--------------------------------------------------------------------------------

local page
local drawn

local function SessionTexts(sum)
	return Headline(sum), date("%Y-%m-%d %H:%M", sum.start), Gains(sum), Happenings(sum)
end

-- Redrawn when something is recorded, and each minute for the current
-- session's length.
local function Refresh()
	if not ns.char then
		return
	end
	local state = ("%d\n%d"):format(ns.version, math.floor(time() / 60))
	if state == drawn then
		return
	end
	drawn = state
	local found = ns.SessionSummaries()
	local total = 0
	for _, sum in ipairs(found) do
		total = total + (Seconds(sum) or 0)
	end
	page.sessions:SetDataProvider(CreateDataProvider(found), ScrollBoxConstants.RetainScrollPosition)
	page.found:SetText(("%s, %s in all"):format(Plural(#found, "session"), ns.Ago(0, total)))
end

local function Build(f)
	page = f
	f.found = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	f.found:SetPoint("TOPRIGHT", -18, -4)
	f.found:SetJustifyH("RIGHT")
	f.sessions = ns.HistoryList(f, SessionTexts)
	f.sessions:SetPoint("TOPLEFT", 14, -24)
	f.sessions:SetPoint("BOTTOMLEFT", 14, 8)
	f.sessions:SetWidth(LIST_WIDTH)
end

ns.AddHistoryView("Sessions", HEIGHT, Build, Refresh)
