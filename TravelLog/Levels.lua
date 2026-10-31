-- Levels: what happened at each level, from the log, and how long the next
-- one should take at your recent XP per hour. Shown in the History tab's
-- Levels view; the estimate is in the Totals too.
local _, ns = ...

local Count = ns.Count

local HEIGHT = 320
local LIST_WIDTH = 410
local ZONES = 3 -- zones a level's tooltip names

--------------------------------------------------------------------------------
-- The next level
--------------------------------------------------------------------------------

-- "12,345 xp to go (45%), about 1h 20m at 9,800 xp/h", "max level", or
-- nothing while the XP bar can't be read.
function ns.NextLevelText()
	if UnitLevel("player") >= GetMaxPlayerLevel() then
		return "max level"
	end
	local xp, max = ns.Clean(UnitXP("player")), ns.Clean(UnitXPMax("player"))
	if type(xp) ~= "number" or type(max) ~= "number" or max <= 0 then
		return
	end
	local need = math.max(max - xp, 0)
	local text = ("%s xp to go (%d%%)"):format(Count(need), math.floor(xp / max * 100))
	local rate = ns.XPRate()
	if rate then
		local seconds = need / rate * 3600
		text = ("%s, %s at %s xp/h"):format(text,
			seconds < 60 and "under a minute" or "about " .. ns.Duration(seconds), Count(rate))
	end
	return text
end

--------------------------------------------------------------------------------
-- Summaries
--------------------------------------------------------------------------------

-- The log entries that say how much XP they gave, and their source.
local XP_SOURCES = { questdone = "quests", kill = "kills", discover = "discoveries" }

local function NewLevel(level, reached)
	return {
		level = level,
		reached = reached, -- the level-up entry, nil for the level recording began at
		experience = { quests = 0, kills = 0, discoveries = 0 },
		quests = 0, failed = 0, kills = 0, deaths = 0, discoveries = 0, money = 0,
		zones = {}, -- zone -> log entries there
	}
end

-- One summary per level in this character's log, newest first: the level-up
-- that reached it, the one that left it (whose took is the time played at
-- it), and what the log entries in between add up to.
function ns.LevelSummaries()
	local list, sum = {}, nil
	for _, e in ipairs(ns.char.log) do
		if e.type == "level" and e.level then
			if sum then
				sum.left = e
			end
			sum = NewLevel(e.level, e)
			list[#list + 1] = sum
		else
			if not sum then
				-- Before the first level-up: the level it left.
				local up
				for _, o in ipairs(ns.char.log) do
					if o.type == "level" and o.level then
						up = o
						break
					end
				end
				sum = NewLevel(up and up.level - 1 or UnitLevel("player"))
				sum.since = e.time
				list[#list + 1] = sum
			end
			local source = XP_SOURCES[e.type]
			if source then
				sum.experience[source] = sum.experience[source] + (tonumber(e.xp) or 0)
			end
			if e.type == "questdone" then
				sum.quests = sum.quests + 1
			elseif e.type == "questfail" then
				sum.failed = sum.failed + 1
			elseif e.type == "kill" then
				sum.kills = sum.kills + 1
			elseif e.type == "death" then
				sum.deaths = sum.deaths + 1
			elseif e.type == "discover" then
				sum.discoveries = sum.discoveries + 1
			elseif e.type == "money" then
				sum.money = sum.money + (tonumber(e.amount) or 0)
			end
			if e.zone then
				sum.zones[e.zone] = (sum.zones[e.zone] or 0) + 1
			end
		end
	end
	if sum and not sum.left and sum.level == UnitLevel("player") then
		sum.current = true
	end
	local newest = {}
	for i = #list, 1, -1 do
		newest[#newest + 1] = list[i]
	end
	return newest
end

-- The zones with the most log entries, most first.
local function Zones(sum)
	local zones = {}
	for zone in pairs(sum.zones) do
		zones[#zones + 1] = zone
	end
	table.sort(zones, function(a, b)
		if sum.zones[a] ~= sum.zones[b] then
			return sum.zones[a] > sum.zones[b]
		end
		return a < b
	end)
	return zones
end

local function Plural(n, one)
	return ("%s %s%s"):format(Count(n), one, n == 1 and "" or "s")
end

-- "Level 12 in 1h 23m played", or "Level 13, 20m played so far" for the one
-- you're at. Time played comes from /played, so it's whole even at the level
-- recording began.
local function Headline(sum)
	local text = "Level " .. sum.level
	local took = sum.left and sum.left.took
	local _, level = ns.Played()
	if took then
		return ("%s in %s played"):format(text, ns.Duration(took))
	elseif sum.current and level then
		return ("%s, %s played so far"):format(text, ns.Duration(level))
	end
	return text
end

-- "5 quests, 1 failed quest, 40 XP kills, 1 death, +1g 20s 0c"
local function Happenings(sum)
	local parts = {}
	if sum.quests > 0 then parts[#parts + 1] = Plural(sum.quests, "quest") end
	if sum.failed > 0 then parts[#parts + 1] = Plural(sum.failed, "failed quest") end
	if sum.kills > 0 then parts[#parts + 1] = Plural(sum.kills, "XP kill") end
	if sum.deaths > 0 then parts[#parts + 1] = Plural(sum.deaths, "death") end
	if sum.money ~= 0 then
		parts[#parts + 1] = (sum.money > 0 and "+" or "") .. ns.MoneyText(sum.money)
	end
	return table.concat(parts, ", ")
end

--------------------------------------------------------------------------------
-- The Levels view
--------------------------------------------------------------------------------

local page
local drawn

local function LevelTexts(sum)
	-- When it was reached, or "from" when recording began during it.
	local when = sum.reached and date("%Y-%m-%d %H:%M", sum.reached.time) or "from " .. date("%Y-%m-%d", sum.since)
	if sum.current then
		when = "|cff20ff20Now|r, " .. when
	end
	return Headline(sum), when, Happenings(sum), Zones(sum)[1] or ""
end

-- Hovering a level shows its XP by source, what it gave and where you were.
local function LevelTooltip(sum)
	local lines = {}
	local xp = sum.experience
	local sources = {}
	for _, source in ipairs({ "quests", "kills", "discoveries" }) do
		if xp[source] > 0 then
			sources[#sources + 1] = ("%s %s"):format(source, Count(xp[source]))
		end
	end
	if #sources > 0 then
		lines[#lines + 1] = "XP: " .. table.concat(sources, ", ")
	end
	if sum.discoveries > 0 then
		lines[#lines + 1] = "Discoveries: " .. Count(sum.discoveries)
	end
	local gains = sum.reached and ns.LevelGains(sum.reached)
	if gains then
		lines[#lines + 1] = "Gave: " .. gains
	end
	local zones = Zones(sum)
	for i = #zones, ZONES + 1, -1 do
		zones[i] = nil
	end
	if #zones > 0 then
		lines[#lines + 1] = "Mostly in " .. table.concat(zones, ", ")
	end
	return #lines > 0 and lines or nil
end

-- Redrawn when something is recorded, and each minute for the time at the
-- current level.
local function Refresh()
	if not ns.char then
		return
	end
	local next = ns.NextLevelText()
	page.next:SetText(next and ("Next level: %s"):format(next) or "")
	local state = ("%d\n%d"):format(ns.version, math.floor(time() / 60))
	if state == drawn then
		return
	end
	drawn = state
	local found = ns.LevelSummaries()
	page.levels:SetDataProvider(CreateDataProvider(found), ScrollBoxConstants.RetainScrollPosition)
end

local function Build(f)
	page = f
	f.next = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	f.next:SetPoint("TOPLEFT", 18, -4)
	f.next:SetWidth(LIST_WIDTH)
	f.next:SetJustifyH("LEFT")
	f.levels = ns.HistoryList(f, LevelTexts, LevelTooltip)
	f.levels:SetPoint("TOPLEFT", 14, -24)
	f.levels:SetPoint("BOTTOMLEFT", 14, 8)
	f.levels:SetWidth(LIST_WIDTH)
end

ns.AddHistoryView("Levels", HEIGHT, Build, Refresh)
