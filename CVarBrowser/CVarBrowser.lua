-- CVarBrowser: finding, bookmarking and changing CVars. The window is in
-- UI.lua.
local _, ns = ...

function ns.Print(text, ...)
	if select("#", ...) > 0 then
		text = text:format(...)
	end
	print("|cffffd200CVarBrowser|r " .. text)
end

--------------------------------------------------------------------------------
-- The CVars
--------------------------------------------------------------------------------

local CATEGORIES = {}
for name, value in pairs(Enum.ConsoleCategory or {}) do
	CATEGORIES[value] = name
end

-- Every CVar the client lists, sorted by name: { name, help, category }.
-- Read once, on first use.
local all
function ns.All()
	if all then
		return all
	end
	all = {}
	local seen = {}
	for _, cmd in ipairs(ConsoleGetAllCommands()) do
		local lower = cmd.command:lower()
		if cmd.commandType == Enum.ConsoleCommandType.Cvar and not seen[lower] then
			seen[lower] = true
			all[#all + 1] = {
				name = cmd.command,
				help = cmd.help ~= "" and cmd.help or nil,
				category = CATEGORIES[cmd.category],
			}
		end
	end
	table.sort(all, function(a, b)
		return a.name:lower() < b.name:lower()
	end)
	return all
end

local function Same(a, b)
	if a == b then
		return true
	end
	local x, y = tonumber(a), tonumber(b)
	return x ~= nil and x == y
end

-- A CVar's value, default and flags, or nil if the client doesn't know it.
function ns.Info(name)
	local value, default, account, character, locked, secure, readOnly = C_CVar.GetCVarInfo(name)
	if value == nil then
		return nil
	end
	return {
		value = value,
		default = default,
		changed = not Same(value, default),
		account = account,
		character = character,
		editable = not (locked or secure or readOnly),
	}
end

function ns.Known(name)
	return ns.known[name:lower()]
end

--------------------------------------------------------------------------------
-- Bookmarks
--------------------------------------------------------------------------------

-- CVarBrowserDB.bookmarks maps lowercase names to names.
function ns.IsBookmarked(name)
	return CVarBrowserDB.bookmarks[name:lower()] ~= nil
end

function ns.ToggleBookmark(name)
	local key = name:lower()
	CVarBrowserDB.bookmarks[key] = not CVarBrowserDB.bookmarks[key] and name or nil
end

--------------------------------------------------------------------------------
-- Searching
--------------------------------------------------------------------------------

local function Matches(entry, words)
	if not entry.about then
		local known = ns.Known(entry.name)
		entry.lower = entry.name:lower()
		entry.about = ((known and known.text or "") .. " " .. (entry.help or "")):lower()
	end
	for _, word in ipairs(words) do
		if not entry.lower:find(word, 1, true) and not entry.about:find(word, 1, true) then
			return false
		end
	end
	return true
end

local FILTERS = {
	all = function() return true end,
	bookmarks = function(entry) return ns.IsBookmarked(entry.name) end,
	changed = function(entry, info) return info.changed end,
	known = function(entry) return ns.Known(entry.name) ~= nil end,
}

-- The CVars matching a search and a filter (all, bookmarks, changed or
-- known). Every word must be in the name or the description; CVars with the
-- whole search in their name come first. Besides the listed CVars this finds
-- unlisted ones the client still knows when they're bookmarked or their
-- whole name is searched.
function ns.Find(text, filter)
	text = (text or ""):lower():match("^%s*(.-)%s*$")
	local words = {}
	for word in text:gmatch("%S+") do
		words[#words + 1] = word
	end
	local entries, listed = {}, {}
	for _, entry in ipairs(ns.All()) do
		entries[#entries + 1] = entry
		listed[entry.name:lower()] = true
	end
	local unlisted = {}
	for key, name in pairs(CVarBrowserDB.bookmarks) do
		unlisted[key] = name
	end
	if text:match("^[%w_]+$") then
		unlisted[text] = text
	end
	for key, name in pairs(unlisted) do
		if not listed[key] and C_CVar.GetCVar(name) ~= nil then
			entries[#entries + 1] = { name = name, unlisted = true }
		end
	end

	local first, rest = {}, {}
	for _, entry in ipairs(entries) do
		local info = Matches(entry, words) and ns.Info(entry.name)
		if info and FILTERS[filter or "all"](entry, info) then
			local list = (text == "" or entry.lower:find(text, 1, true)) and first or rest
			list[#list + 1] = entry
		end
	end
	for _, entry in ipairs(rest) do
		first[#first + 1] = entry
	end
	return first
end

--------------------------------------------------------------------------------
-- Changing
--------------------------------------------------------------------------------

-- Sets a CVar and returns its new value, or nil and why it wasn't set.
function ns.Set(name, value)
	local info = ns.Info(name)
	if not info then
		return nil, "the client doesn't know it"
	elseif not info.editable then
		return nil, "addons can't change it"
	elseif InCombatLockdown() then
		return nil, "not in combat"
	end
	C_CVar.SetCVar(name, value)
	local now = C_CVar.GetCVar(name)
	if Same(now, value) then
		ns.Print("%s: %s -> |cffffffff%s|r", name, info.value, now)
	else
		ns.Print("%s stays |cffffffff%s|r; the client didn't take %s.", name, now, value)
	end
	return now
end

function ns.Reset(name)
	local info = ns.Info(name)
	return ns.Set(name, info and info.default)
end

--------------------------------------------------------------------------------
-- Events and commands
--------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" and arg == "CVarBrowser" then
		CVarBrowserDB = CVarBrowserDB or {}
		CVarBrowserDB.bookmarks = CVarBrowserDB.bookmarks or {}
		CVarBrowserDB.minimap = nil -- the minimap button's, before the addon compartment
	elseif ns.Refresh then
		-- A CVar changed, or combat started or ended.
		ns.Refresh()
	end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CVAR_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

SLASH_CVARBROWSER1 = "/cvars"
SLASH_CVARBROWSER2 = "/cvar"
SlashCmdList.CVARBROWSER = function(msg)
	ns.Toggle(msg:match("^%s*(.-)%s*$"))
end

-- The addon compartment's entry, named in the .toc.
function CVarBrowser_OnAddonCompartmentClick()
	ns.Toggle()
end
