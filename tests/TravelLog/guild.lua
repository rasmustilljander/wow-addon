-- Guilds: the guild you're in at the first login remembered, promotions and
-- demotions (the line before or after the change), others' lines, a renamed
-- rank, being kicked out, an invitation and a guild whose info loads late,
-- leaving, a declined invitation, founding one, changes while offline, a secret guild name; stats,
-- /tl log, the Guild row and a reload.
M.guild = { name = "Wanderers", rank = "Member", rankIndex = 3 }
local ns = M.Login()

local function last(kind)
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == kind then return log[i] end
	end
end
local function count(kind)
	local n = 0
	for _, e in ipairs(TravelLogCharDB.log) do if e.type:find("^guild") and (not kind or e.type == kind) then n = n + 1 end end
	return n
end
local function update()
	M.fire("PLAYER_GUILD_UPDATE", "player")
	M.tick(3)
end

-- The guild you're in when recording begins isn't news.
check(count() == 0 and ns.char.guild.name == "Wanderers" and ns.char.guild.rankIndex == 3, "first guild remembered")

-- Ann promotes you: the line, then the change.
M.chat("CHAT_MSG_SYSTEM", "Ann has promoted Rasmus to Officer.")
M.guild = { name = "Wanderers", rank = "Officer", rankIndex = 2 }
update()
local e = last("guildrank")
check(count() == 1 and e.guild == "Wanderers" and e.rank == "Officer" and e.from == "Member" and e.change == "promoted" and e.by == "Ann", "promoted")
check(ns.Describe(e) == "Promoted to Officer in Wanderers by Ann (was Member)", "promotion described: " .. ns.Describe(e))

-- Others' promotions and arrivals, and a renamed rank, aren't yours.
M.chat("CHAT_MSG_SYSTEM", "Ann has promoted Bob to Officer.")
M.chat("CHAT_MSG_SYSTEM", "Cid has joined the guild.")
M.fire("GUILD_ROSTER_UPDATE", false)
M.guild.rank = "Captain"
M.fire("GUILD_RANKS_UPDATE")
M.tick(3)
check(count() == 1 and ns.char.guild.rank == "Captain", "others' lines and a renamed rank not logged")

-- A demotion whose line comes just after the change.
M.guild = { name = "Wanderers", rank = "Member", rankIndex = 3 }
M.fire("PLAYER_GUILD_UPDATE", "player")
M.tick(1)
M.chat("CHAT_MSG_SYSTEM", "Ann-Otherrealm has demoted Rasmus to Member.")
M.tick(3)
e = last("guildrank")
check(count() == 2 and e.change == "demoted" and e.by == "Ann-Otherrealm" and e.from == "Captain", "demoted, line after")
check(ns.Describe(e) == "Demoted to Member in Wanderers by Ann-Otherrealm (was Captain)", "demotion described: " .. ns.Describe(e))

-- Kicked out.
M.chat("CHAT_MSG_SYSTEM", "Rasmus has been kicked out of the guild by Ann.")
M.guild = nil
update()
e = last("guildleave")
check(count() == 3 and e.guild == "Wanderers" and e.rank == "Member" and e.how == "kicked" and e.by == "Ann" and not e.seconds, "kicked out")
check(ns.Describe(e) == "Kicked out of Wanderers by Ann", "kick described: " .. ns.Describe(e))

-- Bob invites you; the client knows you're in a guild before it knows which.
M.fire("GUILD_INVITE_REQUEST", "Bob", "Night Watch", 0, "", false)
M.guild = { loading = true }
M.chat("CHAT_MSG_SYSTEM", "You have joined the guild.")
update()
check(count() == 1 + 2 and M.rosterRequests >= 1, "nothing logged until the guild is known; roster asked for")
M.guild = { name = "Night Watch", rank = "Initiate", rankIndex = 4 }
M.fire("GUILD_ROSTER_UPDATE", true)
M.tick(3)
e = last("guildjoin")
check(count() == 4 and e.guild == "Night Watch" and e.rank == "Initiate" and e.by == "Bob" and not e.founder, "joined")
check(ns.Describe(e) == "Joined Night Watch as Initiate (invited by Bob)", "join described: " .. ns.Describe(e))
check(ns.char.guild.since == M.now, "join time kept")

-- An hour later you leave.
M.tick(3600)
M.chat("CHAT_MSG_SYSTEM", "You have left the guild.")
M.guild = nil
update()
e = last("guildleave")
check(count() == 5 and e.how == "left" and e.guild == "Night Watch" and e.seconds == 3603, "left: " .. tostring(e.seconds))
check(ns.Describe(e) == "Left Night Watch after 1h 0m", "leave described: " .. ns.Describe(e))

-- A declined invitation isn't credited if you join the same guild later by
-- founding it from a charter.
M.fire("GUILD_INVITE_REQUEST", "Eve", "Dawn", 0, "", false)
DeclineGuild()
M.guild = { name = "Dawn", rank = "Guild Master", rankIndex = 0 }
M.chat("CHAT_MSG_SYSTEM", "Congratulations, you are a founding member of Dawn!")
update()
e = last("guildjoin")
check(count() == 6 and e.guild == "Dawn" and e.founder and not e.by, "founded")
check(ns.Describe(e) == "Joined Dawn as Guild Master (founder)", "founding described: " .. ns.Describe(e))

--------------------------------------------------------------------------------
-- Totals, /tl log, the window
--------------------------------------------------------------------------------

local g = ns.stats.guilds
check(g.joined == 2 and g.left == 1 and g.kicked == 1 and g.promoted == 1 and g.demoted == 1, "counted")
for _, kind in ipairs({ "guildjoin", "guildleave", "guildrank" }) do
	check(ns.LogGroup(last(kind)) == "Life", kind .. " under Life")
end
check(ns.LogTypeLabel(last("guildjoin")) == "Guild joined" and ns.LogTypeLabel(last("guildleave")) == "Guild left"
	and ns.LogTypeLabel(last("guildrank")) == "Guild rank", "labels")

M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("Guild: .*") end
check(line == "Guild: Dawn (Guild Master); joined 2, left 1, kicked out 1, promoted 1, demoted 1", "stats line: " .. tostring(line))
M.out = {}
SlashCmdList.TRAVELLOG("log 5 wanderers")
check(#M.out == 4 and M.out[4]:find("Kicked out of Wanderers by Ann", 1, true), "/tl log finds the guild")

SlashCmdList.TRAVELLOG("")
local values = {}
for _, fs in ipairs(M.descendants(TravelLogFrame.pages[1])) do values[#values + 1] = fs.text end
check(table.concat(values, "\n"):find("Guild\nDawn (Guild Master); joined 2, left 1, kicked out 1, promoted 1, demoted 1", 1, true), "Guild row")

--------------------------------------------------------------------------------
-- A reload, and changes while you were offline
--------------------------------------------------------------------------------

ns = M.Reload()
M.tick(3)
check(count() == 6 and ns.char.guild.name == "Dawn" and ns.stats.guilds.joined == 2, "kept after a reload")

-- Demoted while offline (a Guild Master can't be, but ranks were reworked).
M.Logout()
M.guild = { name = "Dawn", rank = "Veteran", rankIndex = 1 }
ns = M.Login()
M.tick(3)
e = last("guildrank")
check(count() == 7 and e.change == "demoted" and e.rank == "Veteran" and not e.by, "rank change while offline")
check(ns.Describe(e) == "Demoted to Veteran in Dawn (was Guild Master)", "offline change described: " .. ns.Describe(e))

-- Removed while offline, an hour after founding it.
M.Logout()
M.guild = nil
ns = M.Login()
M.tick(3)
e = last("guildleave")
check(count() == 8 and e.guild == "Dawn" and not e.how and e.seconds, "removed while offline")
check(ns.Describe(e):find("^No longer in Dawn after "), "unknown leave described: " .. ns.Describe(e))
check(ns.stats.guilds.left == 2, "counted as left")

-- A guild name the client hides is waited out, not taken for leaving.
M.secrets["Hidden"] = true
M.guild = { name = "Hidden", rank = "Member", rankIndex = 2 }
update()
check(count() == 8, "secret name not logged")
M.secrets["Hidden"] = nil
M.fire("GUILD_ROSTER_UPDATE", true)
M.tick(3)
check(count() == 9 and last("guildjoin").guild == "Hidden" and not last("guildjoin").by, "logged once readable")

-- Everyone's totals don't name a guild.
M.out = {}
SlashCmdList.TRAVELLOG("stats all")
line = nil
for _, text in ipairs(M.out) do line = line or text:match("Guild: .*") end
check(line == "Guild: joined 3, left 2, kicked out 1, promoted 1, demoted 2", "all characters' line: " .. tostring(line))
