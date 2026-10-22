-- PvP: duels, honorable kills, your rank and battleground results.
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
			if ns.IsMe(winner) then
				LogDuel("won", loser, r.fled)
			elseif ns.IsMe(loser) then
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

--------------------------------------------------------------------------------
-- Your rank: in Forever, your renown with the PvP rank faction. It starts over
-- each season.
--------------------------------------------------------------------------------

local RANK_FACTION = 2800 -- PVP_RANK_POINTS_FACTION_ID in Blizzard's PVPRankFrame

-- As the character frame names it: "Sergeant", "Knight", ...
local function RankTitle(rank)
	if rank <= 0 then
		return ns.Clean(PVP_RANK_0_NAME)
	end
	local ranks = Enum.PvPRanks
	if not GetText or not ranks or rank > ranks.Rank_14 - ranks.Rank_1 + 1 then
		return
	end
	local faction = UnitFactionGroup("player") == "Alliance" and 1 or 0
	local ok, title = pcall(GetText, ("PVP_RANK_%d_%d"):format(ranks.Rank_1 + rank - 1, faction), UnitSex("player"))
	return ok and ns.Clean(title) or nil
end

-- The first reading is only remembered. A change while you were offline (a
-- new week or season) is logged at the next login.
local function CheckRank()
	local info = C_MajorFactions and C_MajorFactions.GetMajorFactionProgressionInfo(RANK_FACTION)
	local rank = info and ns.Clean(info.renownLevel)
	if type(rank) ~= "number" then
		return
	end
	local season = GetCurrentArenaSeason and ns.Clean(GetCurrentArenaSeason())
	local saved = ns.char.pvpRank
	ns.char.pvpRank = { rank = rank, season = season }
	if not saved or saved.rank == rank then
		return
	end
	ns.Log("pvprank", {
		rank = rank,
		old = saved.rank,
		title = RankTitle(rank),
		season = season,
		newSeason = season and saved.season and season ~= saved.season or nil,
	})
end

ns.On("PLAYER_ENTERING_WORLD", CheckRank)
-- Faction data can arrive after login.
ns.On("UPDATE_FACTION", CheckRank)
ns.On("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", function(factionID)
	if factionID == RANK_FACTION then
		CheckRank()
	end
end)
ns.On("PLAYER_PVP_RANK_CHANGED", function(unit)
	if unit == "player" then
		CheckRank()
	end
end)

--------------------------------------------------------------------------------
-- Battlegrounds
--------------------------------------------------------------------------------

-- Your line on the scoreboard, as Blizzard's results window reads it when the
-- match ends. Any of it can be secret.
local function Score()
	local guid = ns.Clean(UnitGUID("player"))
	local info = guid and C_PvP and C_PvP.GetScoreInfoByPlayerGuid and C_PvP.GetScoreInfoByPlayerGuid(guid)
	if type(info) ~= "table" then
		return {}
	end
	return {
		killingBlows = ns.Clean(info.killingBlows), honorableKills = ns.Clean(info.honorableKills),
		deaths = ns.Clean(info.deaths), honor = ns.Clean(info.honorGained),
	}
end

local function LogMatch(data)
	ns.Log("battleground", data)
	ns.Add(1, "battlegrounds", data.result)
end

-- winner is a faction index, as GetBattlefieldArenaFaction gives yours:
-- 0 Horde, 1 Alliance; anything else is a draw.
local watching = ns.On("PVP_MATCH_COMPLETE", function(winner, duration)
	local inst = ns.char.instance
	if inst and inst.result then
		return
	end
	winner = ns.Clean(winner)
	if winner == nil then
		return
	end
	local mine = GetBattlefieldArenaFaction and ns.Clean(GetBattlefieldArenaFaction())
	if mine == nil then
		mine = UnitFactionGroup("player") == "Alliance" and 1 or 0
	end
	local data = Score()
	data.name = ns.Clean((GetInstanceInfo()))
	data.result = winner == mine and "won" or winner == 1 - mine and "lost" or "draw"
	data.seconds = ns.Clean(duration)
	LogMatch(data)
	if inst then
		inst.result = data.result
	end
end)

-- Leaving a battleground before its end: deserting, or a disconnect that
-- outlasted the match.
ns.On("TL_INSTANCE_LEFT", function(inst)
	if watching and (inst.kind == "battleground" or inst.kind == "arena") and not inst.result then
		LogMatch({ name = inst.name, result = "left" })
	end
end)
