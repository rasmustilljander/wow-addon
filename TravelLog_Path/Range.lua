-- Trail ranges: how far back the map trail goes, for you and for alts. A
-- range is a word (session, today, week, all, off), a duration ("6h",
-- "3d") or a calendar day ("2026-10-19").
local _, ns = ...

local HOUR, DAY = 3600, 86400

local WORDS = { session = true, today = true, week = true, all = true, off = true }

local function Midnight(t)
	local d = date("*t", t)
	d.hour, d.min, d.sec = 0, 0, 0
	return time(d)
end

-- Seconds in "6h" or "3d", or nil.
local function Duration(range)
	local n, unit = range:match("^(%d+)([hd])$")
	n = tonumber(n)
	if n and n > 0 then
		return n * (unit == "h" and HOUR or DAY), n, unit
	end
end

-- Midnight at the start of a "YYYY-MM-DD" day, and the next midnight, or
-- nil if it isn't a real date.
local function Day(range)
	local y, m, d = range:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	if not y then
		return
	end
	y, m, d = tonumber(y), tonumber(m), tonumber(d)
	local start = time({ year = y, month = m, day = d, hour = 0, min = 0, sec = 0 })
	if date("%Y-%m-%d", start) ~= range then
		return
	end
	return start, time({ year = y, month = m, day = d + 1, hour = 0, min = 0, sec = 0 })
end

-- What was typed as a range, as it's saved, or nil if it isn't one.
-- "yesterday" becomes that day's date.
function ns.ParseTrail(text)
	if text == "yesterday" then
		return date("%Y-%m-%d", Midnight(time()) - 1)
	end
	if WORDS[text] or Duration(text) or Day(text) then
		return text
	end
end

-- The time a range starts and the time it ends before (nil for now), or
-- nil when it's off. sessions are the character's path sessions, oldest
-- first; "session" is the last of them.
function ns.TrailSpan(range, sessions)
	if range == "session" then
		local last = sessions[#sessions]
		return last and last.start
	elseif range == "today" then
		return Midnight(time())
	elseif range == "week" then
		return time() - 7 * DAY
	elseif range == "all" then
		return 0
	end
	local seconds = Duration(range)
	if seconds then
		return time() - seconds
	end
	return Day(range)
end

-- "today", "last 6 hours", "Mon 19 Oct", ...
function ns.DescribeTrail(range)
	if range == "session" then
		return "latest session"
	elseif range == "week" then
		return "last 7 days"
	elseif range == "all" then
		return "everything"
	elseif WORDS[range] then
		return range
	end
	local seconds, n, unit = Duration(range)
	if seconds then
		local word = unit == "h" and "hour" or "day"
		return n == 1 and "last " .. word or ("last %d %ss"):format(n, word)
	end
	local start = Day(range)
	return start and date("%a %d %b", start) or range
end

-- The day before (step -1) or after (step 1) a day range. Any other range
-- steps from today. Reaching today gives "today".
function ns.StepDay(range, step)
	local start = Day(range) or Midnight(time())
	local noon = start + step * DAY + DAY / 2
	if Midnight(noon) >= Midnight(time()) then
		return "today"
	end
	return date("%Y-%m-%d", noon)
end
