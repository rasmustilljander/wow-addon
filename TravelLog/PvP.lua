-- PvP: duels and honorable kills.
local _, ns = ...

--------------------------------------------------------------------------------
-- Duels
--------------------------------------------------------------------------------

-- The duel being asked for or fought: { opponent, challenger = "you" or
-- "opponent", started }. Nothing says when the other player accepts your
-- challenge, so it's started once you accept theirs or either of you
-- crosses the duel area's edge.
local duel

local function Name(unit)
	local name, realm = UnitName(unit)
	name, realm = ns.Clean(name), ns.Clean(realm)
	return name and realm and realm ~= "" and name .. "-" .. realm or name
end

-- /duel without a name and the unit menu's Duel pass a unit; /duel Name
-- passes the name.
hooksecurefunc("StartDuel", function(unit)
	unit = ns.Clean(unit)
	if not unit or unit == "" then
		unit = "target"
	end
	local opponent = UnitExists(unit) and Name(unit) or unit ~= "target" and unit or nil
	duel = { opponent = opponent, challenger = "you" }
end)

local function Requested(name)
	duel = { opponent = ns.Clean(name), challenger = "opponent" }
end
ns.On("DUEL_REQUESTED", Requested)
ns.On("DUEL_TO_THE_DEATH_REQUESTED", Requested) -- Hardcore realms only

hooksecurefunc("AcceptDuel", function()
	if duel then duel.started = true end
end)

-- Declining isn't a duel.
hooksecurefunc("CancelDuel", function()
	if duel and not duel.started then duel = nil end
end)

local function Started()
	if duel then duel.started = true end
end
ns.On("DUEL_OUTOFBOUNDS", Started)
ns.On("DUEL_INBOUNDS", Started)

local function LogDuel(result, opponent, fled)
	local d = duel or {}
	duel = nil
	ns.Log("duel", { opponent = opponent or d.opponent, result = result, fled = fled, challenger = d.challenger })
	ns.Add(1, "duels", result)
end

-- Everyone nearby sees "Bob has defeated Ann in a duel", so only duels with
-- you in them count. %1$s is the winner and %2$s the loser in both.
local results = {}
for _, entry in ipairs({ { "DUEL_WINNER_KNOCKOUT", false }, { "DUEL_WINNER_RETREAT", true } }) do
	local format = _G[entry[1]]
	if type(format) == "string" then
		local order = {}
		for n in format:gmatch("%%(%d)%$") do
			order[#order + 1] = tonumber(n)
		end
		results[#results + 1] = { pattern = ns.ToPattern(format), order = order, fled = entry[2] }
	end
end

local function IsMe(name)
	return name:match("^[^%-]+") == UnitName("player")
end

ns.On("CHAT_MSG_SYSTEM", function(text)
	text = ns.Clean(text)
	if type(text) ~= "string" then
		return
	end
	for _, r in ipairs(results) do
		local a, b = text:match(r.pattern)
		if a then
			local names = {}
			names[r.order[1] or 1], names[r.order[2] or 2] = a, b
			local winner, loser = names[1], names[2]
			if IsMe(winner) then
				LogDuel("won", loser, r.fled)
			elseif IsMe(loser) then
				LogDuel("lost", winner, r.fled)
			end
			return
		end
	end
end)

-- The result arrives in chat just after DUEL_FINISHED, which also fires
-- when a challenge is declined. A duel that started and has no result by
-- then was interrupted.
ns.On("DUEL_FINISHED", function()
	local finished = duel
	C_Timer.After(2, function()
		if finished and duel == finished then
			if finished.started then
				LogDuel("interrupted")
			else
				duel = nil
			end
		end
	end)
end)

--------------------------------------------------------------------------------
-- Honor ("Bob dies (Honorable Kill: Sergeant). You gain 45 Honor.")
--------------------------------------------------------------------------------

-- Open-ended so the bonus variants match too.
local function Open(name)
	local format = _G[name]
	return type(format) == "string" and ns.ToPattern(format:gsub("%.$", ""), true)
end
local killPattern = Open("COMBATLOG_HONORGAIN")
local noRankPattern = Open("COMBATLOG_HONORGAIN_NO_RANK")
local awardPattern = Open("COMBATLOG_HONORAWARD")

-- Kills the server counted minus kills read from chat, for kills whose chat
-- line was hidden (in battlegrounds, say). Settled a moment after the count
-- changes.
local unexplained = 0
local sessionKills

local function HonorKill(data)
	ns.Log("honorkill", data)
	ns.Add(1, "honorKills")
	if data.honor then
		ns.Add(data.honor, "honor")
	end
end

ns.On("CHAT_MSG_COMBAT_HONOR_GAIN", function(text)
	text = ns.Clean(text)
	if type(text) ~= "string" then
		return
	end
	local name, rank, honor
	if killPattern then
		name, rank, honor = text:match(killPattern)
	end
	if not name and noRankPattern then
		name, honor = text:match(noRankPattern)
	end
	if name then
		unexplained = unexplained - 1
		HonorKill({ name = name, rank = rank, honor = tonumber(honor) })
		return
	end
	local award = awardPattern and tonumber(text:match(awardPattern))
	if award then
		ns.Log("honor", { honor = award })
		ns.Add(award, "honor")
	end
end)

local function SessionKills()
	return GetPVPSessionStats and ns.Clean((GetPVPSessionStats()))
end

ns.On("PLAYER_LOGIN", function()
	sessionKills = SessionKills()
end)

ns.On("PLAYER_PVP_KILLS_CHANGED", function(unit)
	if unit and unit ~= "player" then
		return
	end
	local kills = SessionKills()
	if not kills then
		return
	end
	-- The day's count starts over at the daily reset.
	if sessionKills and kills > sessionKills then
		unexplained = unexplained + kills - sessionKills
	end
	sessionKills = kills
	C_Timer.After(2, function()
		for _ = 1, unexplained do
			HonorKill({})
		end
		unexplained = 0
	end)
end)
