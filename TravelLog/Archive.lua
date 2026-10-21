-- Archive: keeps the files loaded at every login small by moving old history
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

-- The lists of history that rotate, in the order they're reported.
local lists = {}

-- Registers a list of this character's history (oldest first) that moves
-- into the archive under archive.chars[character][name]. get() returns the
-- list and set(list) replaces it; when(item) says when the item happened, or
-- nil to keep it no matter how old. label names the items in chat.
function ns.Rotates(name, label, get, set, when)
	lists[#lists + 1] = { name = name, label = label, get = get, set = set, when = when }
end

ns.Rotates("sessions", "sessions",
	function() return ns.char.sessions end,
	function(list) ns.char.sessions = list end,
	function(s) return s ~= ns.session and (s.stop or s.start) end)
ns.Rotates("log", "log entries",
	function() return ns.char.log end,
	function(list) ns.char.log = list end,
	function(e) return e.time end)

-- "30 sessions, 30 log entries and 30 paths"
local function Counts(moves)
	local parts = {}
	for _, m in ipairs(moves) do
		parts[#parts + 1] = ("%d %s"):format(#m.old, m.list.label)
	end
	if #parts == 1 then
		return parts[1]
	end
	return table.concat(parts, ", ", 1, #parts - 1) .. " and " .. parts[#parts]
end

-- Moves this character's history older than KEEP_DAYS into the archive.
-- Unless forced, only when that history has grown past ROTATE_AT. Returns
-- how many items moved.
function ns.Rotate(force)
	local total = 0
	for _, list in ipairs(lists) do
		total = total + Size(list.get())
	end
	if not force and total < ROTATE_AT then
		return 0
	end

	local cutoff = time() - KEEP_DAYS * 86400
	local moves, moving, count = {}, 0, 0
	for _, list in ipairs(lists) do
		local old, keep = {}, {}
		for _, item in ipairs(list.get()) do
			local t = list.when(item)
			if t and t < cutoff then
				old[#old + 1] = item
			else
				keep[#keep + 1] = item
			end
		end
		moves[#moves + 1] = { list = list, old = old, keep = keep }
		moving, count = moving + Size(old), count + #old
	end
	if count == 0 or (not force and moving < MIN_MOVE) then
		return 0
	end

	local archive, reason = Open()
	if not archive then
		ns.Print("can't open %s (%s), so old history stays in this character's file. Install the %s folder to keep it small.",
			ARCHIVE, reason or "unknown", ARCHIVE)
		return 0
	end

	local mine = archive.chars[ns.charKey] or {}
	archive.chars[ns.charKey] = mine
	for _, m in ipairs(moves) do
		local into = mine[m.list.name] or {}
		mine[m.list.name] = into
		for _, item in ipairs(m.old) do
			into[#into + 1] = item
		end
		m.list.set(m.keep)
	end
	local state = State()
	state.size = (state.size or 0) + moving

	ns.Print("moved %s older than %d days to %s.", Counts(moves), KEEP_DAYS, ARCHIVE)
	ns.Fire("TL_ROTATED")
	return count
end

-- A character's archived history (this one's unless key is given) in a
-- list, loading the archive if needed. Empty when nothing is archived. Its
-- fields are the names lists were registered under ({ sessions, log, path,
-- ... }); any may be missing.
function ns.ArchivedHistory(key)
	if not State().size then
		return {}
	end
	local archive = Open()
	local mine = archive and archive.chars[key or ns.charKey]
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
