-- Archive: keeps the file loaded at every login small by moving old history
-- into load-on-demand archive addons (TravelLog_Archive1, 2, ...). WoW gives
-- each addon one SavedVariables file, so each archive slot is its own addon
-- and its own file. A slot is only read when old data is asked for, like
-- "/tl trail all".
local _, ns = ...

local ROTATE_AT = 3 * 1024 * 1024 -- estimated bytes of history before rotating
local KEEP_DAYS = 10              -- recent history that always stays in the main file
local MIN_MOVE = 256 * 1024       -- not worth loading an archive for less than this
local SLOT_FULL = 8 * 1024 * 1024 -- estimated bytes per archive file

local function SlotName(n)
	return "TravelLog_Archive" .. n
end

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

-- Loads archive slot n and returns its table, or nil and the reason.
local function Open(n)
	local name = SlotName(n)
	if not C_AddOns.IsAddOnLoaded(name) then
		local loaded, reason = C_AddOns.LoadAddOn(name)
		if not loaded then
			return nil, reason
		end
	end
	local var = "TravelLogArchive" .. n
	_G[var] = _G[var] or { chars = {} }
	return _G[var]
end

local function State()
	ns.db.archive = ns.db.archive or { slot = 1, sizes = {} }
	return ns.db.archive
end

-- Moves this character's history older than KEEP_DAYS into the current
-- archive slot. Unless forced, only when the main file has grown past
-- ROTATE_AT. Returns how many sessions and log entries moved.
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

	local state = State()
	local n = state.slot
	while (state.sizes[n] or 0) >= SLOT_FULL and C_AddOns.DoesAddOnExist(SlotName(n + 1)) do
		n = n + 1
	end
	local archive, reason = Open(n)
	if not archive then
		ns.Print("can't open %s (%s), so old history stays in the main file. Install the TravelLog_Archive folders to keep it small.",
			SlotName(n), reason or "unknown")
		return 0, 0
	end
	state.slot = n

	local mine = archive.chars[ns.charKey] or { sessions = {}, log = {} }
	archive.chars[ns.charKey] = mine
	for _, s in ipairs(oldSessions) do
		mine.sessions[#mine.sessions + 1] = s
	end
	for _, e in ipairs(oldLog) do
		mine.log[#mine.log + 1] = e
	end
	char.sessions, char.log = keepSessions, keepLog
	state.sizes[n] = (state.sizes[n] or 0) + moving

	ns.Print("moved %d sessions and %d log entries older than %d days to %s.",
		#oldSessions, #oldLog, KEEP_DAYS, SlotName(n))
	if state.sizes[n] >= SLOT_FULL and not C_AddOns.DoesAddOnExist(SlotName(n + 1)) then
		ns.Print("%s is full. Add %s to keep archive files small (see the TravelLog README).",
			SlotName(n), SlotName(n + 1))
	end
	return #oldSessions, #oldLog
end

ns.On("PLAYER_LOGIN", function()
	ns.Rotate(false)
end)

-- This character's archived history, oldest slot first, loading slots as
-- needed. Each entry has .sessions and .log like ns.char.
function ns.ArchivedHistory()
	local list = {}
	local state = State()
	for n = 1, state.slot do
		if state.sizes[n] then
			local archive = Open(n)
			local mine = archive and archive.chars[ns.charKey]
			if mine then
				list[#list + 1] = mine
			end
		end
	end
	return list
end

-- Removes a character from every archive slot.
function ns.WipeArchives(key)
	local state = State()
	for n = 1, state.slot do
		if state.sizes[n] then
			local archive = Open(n)
			if archive then
				archive.chars[key] = nil
			end
		end
	end
end

-- One line per used slot, for "/tl archive".
function ns.ArchiveStatus()
	local state, lines = State(), {}
	for n = 1, state.slot do
		if state.sizes[n] then
			local installed = C_AddOns.DoesAddOnExist(SlotName(n))
			lines[#lines + 1] = ("%s: about %.1f MB%s%s"):format(SlotName(n), state.sizes[n] / 1048576,
				n == state.slot and " (in use)" or "", installed and "" or ", NOT INSTALLED")
		end
	end
	return lines, KEEP_DAYS
end
