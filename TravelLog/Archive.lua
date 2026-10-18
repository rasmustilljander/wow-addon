-- Archive: keeps the file loaded at every login small by moving old history
-- into TravelLog_Archive, a load-on-demand addon. WoW gives each addon one
-- SavedVariables file, so the archive has to be an addon of its own to get a
-- file of its own. It's only loaded when old data is asked for, like
-- "/tl trail all".
local _, ns = ...

local ARCHIVE = "TravelLog_Archive"
local ROTATE_AT = 3 * 1024 * 1024 -- estimated bytes of history before rotating
local KEEP_DAYS = 10              -- recent history that always stays in the main file
local MIN_MOVE = 256 * 1024       -- not worth loading the archive for less than this

-- About how many bytes a value takes in a SavedVariables file.
local function Size(v)
	local kind = type(v)
	if kind == "string" then
		return #v + 3
	elseif kind ~= "table" then
		return 8
	end
	local n = 4
	for key, value in pairs(v) do
		n = n + Size(key) + Size(value) + 8
	end
	return n
end
ns.Size = Size

-- Loads the archive and returns its table, or nil and the reason.
local function Open()
	if not C_AddOns.IsAddOnLoaded(ARCHIVE) then
		local loaded, reason = C_AddOns.LoadAddOn(ARCHIVE)
		if not loaded then
			return nil, reason
		end
	end
	TravelLogArchiveDB = TravelLogArchiveDB or { chars = {} }
	return TravelLogArchiveDB
end

-- What's been archived, kept in the account-wide file so the archive itself
-- doesn't have to be loaded to know. size is nil while nothing is archived.
local function State()
	ns.db.archive = ns.db.archive or {}
	return ns.db.archive
end

-- Moves this character's history older than KEEP_DAYS into the archive.
-- Unless forced, only when the main file has grown past ROTATE_AT. Returns
-- how many sessions and log entries moved.
function ns.Rotate(force)
	local char = ns.char
	if not force and Size(char.sessions) + Size(char.log) < ROTATE_AT then
		return 0, 0
	end

	local cutoff = time() - KEEP_DAYS * 86400
	local oldSessions, keepSessions = {}, {}
	for _, s in ipairs(char.sessions) do
		if s ~= ns.session and (s.stop or s.start) < cutoff then
			oldSessions[#oldSessions + 1] = s
		else
			keepSessions[#keepSessions + 1] = s
		end
	end
	local oldLog, keepLog = {}, {}
	for _, e in ipairs(char.log) do
		if e.time < cutoff then
			oldLog[#oldLog + 1] = e
		else
			keepLog[#keepLog + 1] = e
		end
	end
	local moving = Size(oldSessions) + Size(oldLog)
	if moving == 0 or (not force and moving < MIN_MOVE) then
		return 0, 0
	end

	local archive, reason = Open()
	if not archive then
		ns.Print("can't open %s (%s), so old history stays in this character's file. Install the %s folder to keep it small.",
			ARCHIVE, reason or "unknown", ARCHIVE)
		return 0, 0
	end

	local mine = archive.chars[ns.charKey] or { sessions = {}, log = {} }
	archive.chars[ns.charKey] = mine
	for _, s in ipairs(oldSessions) do
		mine.sessions[#mine.sessions + 1] = s
	end
	for _, e in ipairs(oldLog) do
		mine.log[#mine.log + 1] = e
	end
	char.sessions, char.log = keepSessions, keepLog
	local state = State()
	state.size = (state.size or 0) + moving

	ns.Print("moved %d sessions and %d log entries older than %d days to %s.",
		#oldSessions, #oldLog, KEEP_DAYS, ARCHIVE)
	return #oldSessions, #oldLog
end

ns.On("PLAYER_LOGIN", function()
	ns.Rotate(false)
end)

-- This character's archived history ({ sessions, log } like ns.char) in a
-- list, loading the archive if needed. Empty when nothing is archived.
function ns.ArchivedHistory()
	if not State().size then
		return {}
	end
	local archive = Open()
	local mine = archive and archive.chars[ns.charKey]
	return mine and { mine } or {}
end

-- Removes a character from the archive.
function ns.WipeArchive(key)
	local state = State()
	local archive = state.size and Open()
	if archive then
		archive.chars[key] = nil
		state.size = next(archive.chars) and Size(archive) or nil
	end
end

-- For "/tl archive": estimated archive size in bytes (nil when empty),
-- whether the archive addon is installed, and how many days stay in the
-- character file.
function ns.ArchiveStatus()
	return State().size, C_AddOns.DoesAddOnExist(ARCHIVE), KEEP_DAYS
end
