-- Guilds: joining, leaving (or being kicked out, or the guild disbanding)
-- and rank changes.
local _, ns = ...

-- The guild you're in is kept in the character file as { name, rank,
-- rankIndex, since = when you joined, if TravelLog saw it }, or {} for none,
-- so a change while you were offline is logged at the next login. The first
-- look only remembers it.

-- What the last system line said about your guild, for the change it comes
-- with: { how = "joined", "left", "kicked" or "disbanded", by, founder }.
local reason
-- The last guild invitation: { by, guild }.
local invite

local function Me(name)
	return name and ns.IsMe(name)
end

-- System lines about you. Others' arrivals and departures aren't news.
local LINES = {
	{ "ERR_GUILD_ACCEPT", function() return { how = "joined" } end },
	{ "ERR_GUILD_FOUNDER_S", function() return { how = "joined", founder = true } end },
	{ "ERR_GUILD_LEAVE_RESULT", function() return { how = "left" } end },
	{ "ERR_GUILD_REMOVE_SELF", function() return { how = "kicked" } end },
	{ "ERR_GUILD_REMOVE_SS", function(who, by) return Me(who) and { how = "kicked", by = by } end },
	{ "ERR_GUILD_DISBANDED", function() return { how = "disbanded" } end },
	{ "ERR_GUILD_DISBAND_SELF", function() return { how = "disbanded" } end },
	{ "ERR_GUILD_DISBAND_S", function(by) return { how = "disbanded", by = by } end },
	{ "ERR_GUILD_PROMOTE_SSS", function(by, who) return Me(who) and { by = by } end },
	{ "ERR_GUILD_DEMOTE_SSS", function(by, who) return Me(who) and { by = by } end },
	{ "ERR_GUILD_LEADER_CHANGED_SS", function(by, who) return Me(who) and { by = by } end },
}
local lines = {}
for _, entry in ipairs(LINES) do
	local format = _G[entry[1]]
	if type(format) == "string" then
		local pattern, order = ns.ToPattern(format)
		lines[#lines + 1] = { pattern = pattern, order = order, fn = entry[2] }
	end
end

-- Your guild as the client has it now; nil while it hasn't loaded yet.
local function Current()
	if not IsInGuild() then
		return {}
	end
	local name, rank, rankIndex = GetGuildInfo("player")
	name, rank, rankIndex = ns.Clean(name), ns.Clean(rank), ns.Clean(rankIndex)
	if not name then
		-- Ask for it now and then; the answer is a GUILD_ROSTER_UPDATE.
		if C_GuildInfo and C_GuildInfo.GuildRoster and not ns.Recent("guildroster", 10) then
			ns.Mark("guildroster")
			C_GuildInfo.GuildRoster()
		end
		return
	end
	return { name = name, rank = rank, rankIndex = rankIndex }
end

local function Joined(now, r)
	local by = invite and (not invite.guild or invite.guild == now.name) and invite.by or nil
	invite = nil
	now.since = time()
	ns.Log("guildjoin", { guild = now.name, rank = now.rank, by = by, founder = r.founder })
	ns.Add(1, "guilds", "joined")
end

local function Left(was, r)
	local how = r.how ~= "joined" and r.how or nil
	ns.Log("guildleave", { guild = was.name, rank = was.rank, how = how, by = how and r.by,
		seconds = was.since and time() - was.since })
	ns.Add(1, "guilds", how == "kicked" and "kicked" or "left")
end

-- Rank 0 is the Guild Master; a lower index is a higher rank.
local function RankChanged(was, now, r)
	local change = now.rankIndex < was.rankIndex and "promoted" or "demoted"
	ns.Log("guildrank", { guild = now.name, rank = now.rank, from = was.rank, change = change,
		by = not r.how and r.by or nil })
	ns.Add(1, "guilds", change)
end

local function Settle()
	local now = Current()
	if not now then
		return
	end
	local was = ns.char.guild
	local r = ns.Recent("guild", 10) and reason or {}
	if was and was.name ~= now.name then
		if was.name then Left(was, r) end
		if now.name then Joined(now, r) end
	elseif was and now.name then
		now.since = was.since
		if was.rankIndex and now.rankIndex and was.rankIndex ~= now.rankIndex then
			RankChanged(was, now, r)
		end
	end
	reason = nil
	ns.char.guild = now
end

-- The client's guild info, the system line and the roster arrive in any
-- order, so a change is logged a moment after it's first seen.
local pending
local function Check()
	local now, was = Current(), ns.char.guild
	if not now or pending then
		return
	end
	if not was then
		ns.char.guild = now
	elseif was.name ~= now.name or was.rankIndex ~= now.rankIndex or was.rank ~= now.rank then
		pending = true
		C_Timer.After(3, function()
			pending = nil
			Settle()
		end)
	end
end

ns.On("PLAYER_LOGIN", Check)
ns.On("PLAYER_GUILD_UPDATE", function(unit)
	if not unit or unit == "player" then Check() end
end)
ns.On("GUILD_ROSTER_UPDATE", Check)
ns.On("GUILD_RANKS_UPDATE", Check)

ns.On("GUILD_INVITE_REQUEST", function(inviter, guildName)
	invite = { by = ns.Clean(inviter), guild = ns.Clean(guildName) }
end)

hooksecurefunc("DeclineGuild", function()
	invite = nil
end)

ns.On("CHAT_MSG_SYSTEM", function(text)
	text = ns.Clean(text)
	if type(text) ~= "string" then
		return
	end
	for _, line in ipairs(lines) do
		-- A line without %s gives back the whole match, which is ignored.
		local a, b, c = ns.MatchPattern(text, line.pattern, line.order)
		if a then
			local r = line.fn(a, b, c)
			if r then
				reason = r
				ns.Mark("guild")
				Check()
			end
			return
		end
	end
end)
