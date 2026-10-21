-- Time played: asked quietly at login, counted forward, how long each level
-- took, /tl stats and /tl log, a reload, and no answer from the server.
local ns = M.Login()

local function last(kind)
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == kind then return log[i] end
	end
end
local function Registered() return ChatFrame1:IsEventRegistered("TIME_PLAYED_MSG") end

-- Asked once at login, without the answer showing in chat.
check(M.playedAsks == 1, "asked at login")
check(ns.Played() == nil, "nothing known before the answer")
check(not Registered(), "chat stops listening while asking")
M.tick(1)
local total, level = ns.Played()
check(total == M.played and level == M.playedLevel, "played from the answer: " .. tostring(total) .. ", " .. tostring(level))
M.tick(1)
check(#M.chatLines == 0 and Registered(), "answer kept out of chat, which listens again")
RequestTimePlayed()
M.tick(1)
check(#M.chatLines == 1, "your own /played still shows")

-- Counted forward from the answer.
M.tick(600)
total, level = ns.Played()
check(total == M.played and level == M.playedLevel, "counted forward")

-- A level-up saves the time played and how long the level took.
local took, before = M.playedLevel, M.played
M.level = 6
M.fire("PLAYER_LEVEL_UP", 6)
M.playedLevel = 0
local e = last("level")
check(e.level == 6 and e.took == took and e.played == before, "level-up times: " .. tostring(e.took) .. ", " .. tostring(e.played))
check(ns.Describe(e) == "Reached level 6 after 1h 10m at level 5", "described: " .. ns.Describe(e))
M.tick(120)
total, level = ns.Played()
check(level == 120 and total == M.played, "the new level counts from zero: " .. tostring(level))

M.out = {}
SlashCmdList.TRAVELLOG("stats")
local stats = table.concat(M.out, "\n")
check(stats:find("Played 1d 1h, 2m at this level", 1, true), "/tl stats: " .. stats)

-- After a reload: asked again, still quiet, the entry keeps its times.
ns = M.Reload()
check(M.playedAsks == 3, "asked again after a reload")
M.tick(2)
check(#M.chatLines == 1 and Registered(), "still quiet")
check(last("level").took == took, "times saved")
M.out = {}
SlashCmdList.TRAVELLOG("log level")
check(table.concat(M.out, "\n"):find("Reached level 6 after 1h 10m at level 5", 1, true), "/tl log: " .. table.concat(M.out, "\n"))

-- No answer: chat listens again after 10 s, and level-ups have no times.
local request = RequestTimePlayed
RequestTimePlayed = function() end
ns = M.Reload()
M.tick(9)
check(not Registered(), "waits for the answer")
M.tick(1)
check(Registered(), "chat listens again after 10 s")
M.level = 7
M.fire("PLAYER_LEVEL_UP", 7)
e = last("level")
check(e.level == 7 and e.took == nil and e.played == nil and ns.Describe(e) == "Reached level 7", "level-up without times")
RequestTimePlayed = request
