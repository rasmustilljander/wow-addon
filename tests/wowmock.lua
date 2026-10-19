-- A small fake of the WoW: Forever addon API, enough to run this repo's
-- addons outside the game. Tests drive it through the global M:
--
--   M.Login()             load installed addons and log in
--   M.Reload()            log out (saving SavedVariables to text) and back in
--   M.fire(event, ...)    send a game event
--   M.tick(n)             advance n seconds, running C_Timer tickers
--   M.frame()             run one OnUpdate frame
--   check(cond, message)  record a test result
--
-- Player state (position, zone, money, ...) lives in fields of M that the
-- fake API reads; tests set them directly. When an addon starts using an API
-- this file doesn't have, add it here.

M = {
	now = 1760000000, gametime = 1000.0, out = {}, errors = {},
	player = { name = "Rasmus", realm = "Forever" },
	money = 10000, level = 5, xp = 0, xpMax = 2800, rested = nil, maxLevel = 60, xpDisabled = false,
	instance = nil, group = {}, raid = false, mapID = 1429, x = 0.42, y = 0.65,
	inst = 0, wa = -9000, wb = -100, zone = "Elwynn Forest", subzone = "Goldshire",
	mounted = false, taxi = false, swimming = false, dead = false, ghost = false, falling = false,
	combat = false, indoors = false, secrets = {}, viewMap = 1429,
	loot = {}, buyback = {}, merchantItems = {}, units = {}, taxiNodes = {},
	quests = {}, bind = "Goldshire", bags = {}, repairCost = 0,
	installed = { "TravelLog" },   -- addon folders the fake client knows about
	disabled = {},                 -- addon name -> true
}

--------------------------------------------------------------------------------
-- Test results
--------------------------------------------------------------------------------

M.passed, M.failed = 0, 0
function check(cond, message)
	if cond then
		M.passed = M.passed + 1
	else
		M.failed = M.failed + 1
		io.write("  FAIL: ", tostring(message), "\n")
	end
end

--------------------------------------------------------------------------------
-- Lua extras WoW adds
--------------------------------------------------------------------------------

function time(t) if t then return os.time(t) end return M.now end
function date(fmt, t) return os.date(fmt, t or M.now) end
function GetTime() return M.gametime end

function M.advance(seconds)
	M.now = M.now + seconds
	M.gametime = M.gametime + seconds
end

function print(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
	local line = table.concat(parts, " ")
	M.out[#M.out + 1] = line
	if M.echo then
		io.write((line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), "\n")
	end
end

function strsplit(delim, str, pieces)
	local out, start = {}, 1
	while true do
		if pieces and #out == pieces - 1 then out[#out + 1] = str:sub(start); break end
		local i, j = str:find(delim, start, true)
		if not i then out[#out + 1] = str:sub(start); break end
		out[#out + 1] = str:sub(start, i - 1)
		start = j + 1
	end
	return unpack(out)
end

function wipe(t) for k in pairs(t) do t[k] = nil end return t end

function geterrorhandler()
	return function(err)
		M.errors[#M.errors + 1] = err
		io.write("  LUA ERROR: ", tostring(err), "\n")
	end
end

-- Hooks are undone on logout, so a reloaded addon doesn't stack on top of the
-- previous load's hooks.
local hooks = {}
function hooksecurefunc(tbl, name, fn)
	if type(tbl) == "string" then tbl, name, fn = _G, tbl, name end
	local orig = tbl[name]
	assert(type(orig) == "function", "hooksecurefunc: no function " .. tostring(name))
	hooks[#hooks + 1] = { tbl = tbl, name = name, orig = orig }
	tbl[name] = function(...)
		local r = { orig(...) }
		fn(...)
		return unpack(r)
	end
end

function issecretvalue(v) return M.secrets[v] == true end

--------------------------------------------------------------------------------
-- Global strings (enUS) and enums
--------------------------------------------------------------------------------

LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
LOOT_ITEM_CREATED_SELF = "You create: %s."
LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d."
COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience."
COMBATLOG_XPGAIN_EXHAUSTION1 = "%s dies, you gain %d experience. (%s exp %s bonus)"
COMBATLOG_XPGAIN_FIRSTPERSON_GROUP = "%s dies, you gain %d experience. (+%d group bonus)"
ERR_ZONE_EXPLORED = "Discovered: %s"
ERR_ZONE_EXPLORED_XP = "Discovered %s: %d experience gained"

Enum = {
	PlayerInteractionType = { None = 0, TradePartner = 1, Merchant = 5, TaxiNode = 6, Trainer = 7, Banker = 8, MailInfo = 17, Auctioneer = 21 },
	LootSlotType = { None = 0, Item = 1, Money = 2, Currency = 3 },
	TooltipDataType = { Item = 0, Spell = 1, Unit = 2 },
}

--------------------------------------------------------------------------------
-- Frames
--------------------------------------------------------------------------------

-- Events the fake client accepts; registering anything else errors like the
-- real one does.
M.KNOWN_EVENTS = {}
for e in ([[PLAYER_LOGIN PLAYER_LOGOUT PLAYER_ENTERING_WORLD ADDON_LOADED ZONE_CHANGED ZONE_CHANGED_INDOORS
ZONE_CHANGED_NEW_AREA PLAYER_INTERACTION_MANAGER_FRAME_SHOW PLAYER_INTERACTION_MANAGER_FRAME_HIDE MERCHANT_SHOW
MERCHANT_CLOSED MERCHANT_UPDATE TAXIMAP_OPENED TAXIMAP_CLOSED TRAINER_SHOW TRAINER_CLOSED MAIL_SHOW MAIL_CLOSED
TRADE_SHOW TRADE_CLOSED AUCTION_HOUSE_SHOW AUCTION_HOUSE_CLOSED BANKFRAME_OPENED BANKFRAME_CLOSED
UNIT_SPELLCAST_SENT UNIT_SPELLCAST_SUCCEEDED HEARTHSTONE_BOUND LOOT_READY LOOT_OPENED LOOT_SLOT_CLEARED LOOT_CLOSED
LOOT_ITEM_ROLL_WON CHAT_MSG_LOOT CHAT_MSG_COMBAT_XP_GAIN CHAT_MSG_SYSTEM UI_INFO_MESSAGE BAG_UPDATE_DELAYED
UPDATE_INVENTORY_DURABILITY PLAYER_MONEY PLAYER_DEAD PLAYER_ALIVE PLAYER_UNGHOST PLAYER_LEVEL_UP QUEST_ACCEPTED
QUEST_TURNED_IN PLAYER_TARGET_CHANGED]]):gmatch("%S+") do
	M.KNOWN_EVENTS[e] = true
end

local Region = {}
Region.__index = Region

local function NewRegion(kind, parent)
	return setmetatable({ kind = kind, parent = parent, shown = true }, Region)
end

function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:SetShown(v) self.shown = v and true or false end
function Region:IsShown() return self.shown end
function Region:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function Region:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
function Region:SetTexture(t) self.texture = t end
function Region:SetThickness(t) self.thickness = t end
function Region:SetStartPoint(p, rel, x, y) assert(type(p) == "string" and rel); self.start = { x, y } end
function Region:SetEndPoint(p, rel, x, y) assert(type(p) == "string" and rel); self.stop = { x, y } end
function Region:SetSize(w, h) self.w, self.h = w, h end
function Region:ClearAllPoints() self.point = nil end
function Region:SetPoint(p, rel, rp, x, y) self.point = { p, rel, rp, x, y } end
function Region:SetAllPoints(rel) self.allPoints = rel or self.parent end
function Region:GetSize()
	if self.w then return self.w, self.h end
	if self.allPoints then return self.allPoints:GetSize() end
	return 0, 0
end
function Region:SetFrameLevel(l) self.level = l end
function Region:GetFrameLevel() return self.level or 1 end
function Region:EnableMouse(v) self.mouse = v end
function Region:SetMouseClickEnabled(v) self.mouseClicks = v end
function Region:RegisterEvent(e)
	if not M.KNOWN_EVENTS[e] then error('Attempt to register unknown event "' .. e .. '"') end
	self.events = self.events or {}
	self.events[e] = true
end
function Region:SetScript(k, fn) self.scripts = self.scripts or {}; self.scripts[k] = fn end
function Region:CreateLine()
	local l = NewRegion("Line", self)
	self.lines = self.lines or {}
	self.lines[#self.lines + 1] = l
	return l
end
function Region:CreateTexture()
	local t = NewRegion("Texture", self)
	self.textures = self.textures or {}
	self.textures[#self.textures + 1] = t
	return t
end

M.frames = {}
function CreateFrame(kind, name, parent)
	local f = NewRegion("Frame", parent)
	M.frames[#M.frames + 1] = f
	if parent then
		parent.children = parent.children or {}
		parent.children[#parent.children + 1] = f
	end
	return f
end

function M.fire(event, ...)
	assert(M.KNOWN_EVENTS[event], "unknown event " .. event)
	for _, f in ipairs(M.frames) do
		if f.events and f.events[event] and f.scripts and f.scripts.OnEvent then
			f.scripts.OnEvent(f, event, ...)
		end
	end
end

local function Visible(f)
	while f do
		if not f.shown then return false end
		f = f.parent
	end
	return true
end

function M.frame()
	for _, f in ipairs(M.frames) do
		if f.scripts and f.scripts.OnUpdate and Visible(f) then
			f.scripts.OnUpdate(f, 0.016)
		end
	end
end

-- Regions of a pool (lines, textures, children) that are currently shown.
function M.shown(pool)
	local list = {}
	for _, r in ipairs(pool or {}) do
		if r.shown then list[#list + 1] = r end
	end
	return list
end

C_Timer = {}
M.tickers = {}
function C_Timer.NewTicker(seconds, fn) M.tickers[#M.tickers + 1] = { seconds = seconds, fn = fn } end

function M.tick(n)
	for _ = 1, n or 1 do
		M.advance(1)
		for _, t in ipairs(M.tickers) do t.fn() end
	end
end

GameTooltip = { lines = {} }
function GameTooltip:SetOwner(owner) self.owner, self.lines, self.unit = owner, {}, nil end
function GameTooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function GameTooltip:AddDoubleLine(a, b) self.lines[#self.lines + 1] = a .. "  " .. b end
function GameTooltip:Show() self.shown = true end
function GameTooltip:Hide() self.shown = false end
function GameTooltip:GetUnit()
	if self.unit then return UnitName(self.unit), self.unit, UnitGUID(self.unit) end
end

-- Tooltip post-calls added by addons, by tooltip data type.
M.tooltipPostCalls = {}
TooltipDataProcessor = { AllTypes = "ALL" }
function TooltipDataProcessor.AddTooltipPostCall(kind, fn)
	M.tooltipPostCalls[kind] = M.tooltipPostCalls[kind] or {}
	table.insert(M.tooltipPostCalls[kind], fn)
end

-- Shows the unit tooltip for a unit (like hovering it) and returns its lines
-- without color codes.
function M.hover(unit)
	GameTooltip:SetOwner(UIParent)
	GameTooltip.unit = unit
	GameTooltip:AddLine(UnitName(unit))
	for _, fn in ipairs(M.tooltipPostCalls[Enum.TooltipDataType.Unit] or {}) do
		fn(GameTooltip, { type = Enum.TooltipDataType.Unit })
	end
	GameTooltip:Show()
	local lines = {}
	for i, line in ipairs(GameTooltip.lines) do
		lines[i] = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	end
	return lines
end

--------------------------------------------------------------------------------
-- Player and world
--------------------------------------------------------------------------------

function UnitName(unit)
	if unit == "player" then return M.player.name end
	local u = M.units[unit]
	return u and u.name
end
function UnitGUID(unit)
	if unit == "player" then return "Player-1-" .. M.player.name end
	local u = M.units[unit]
	return u and u.guid
end
function UnitExists(unit) return unit == "player" or M.units[unit] ~= nil end
function UnitCanAttack(_, unit) local u = M.units[unit]; return u and u.hostile or false end
function UnitIsUnit(a, b) return a == b or (M.units[a] ~= nil and M.units[a] == M.units[b]) end
function UnitIsPlayer(unit) local u = M.units[unit]; return unit == "player" or (u and u.player) or false end
function UnitPlayerControlled(unit) local u = M.units[unit]; return unit == "player" or (u and (u.player or u.pet)) or false end
function UnitClassification(unit) local u = M.units[unit]; return u and u.classification or "normal" end
function UnitIsTapDenied(unit) local u = M.units[unit]; return u and u.tapped or false end
function UnitIsTrivial(unit) local u = M.units[unit]; return u and u.trivial or false end
function GetRealmName() return M.player.realm end
function UnitClass() return "Mage", "MAGE" end
function UnitRace() return "Human", "Human" end
function UnitFactionGroup() return "Alliance" end
function UnitLevel(unit)
	if unit == "player" then return M.level end
	local u = M.units[unit]
	return u and u.level or 0
end
function UnitXP() return M.xp end
function UnitXPMax() return M.xpMax end
function GetXPExhaustion() return M.rested end
function GetMaxPlayerLevel() return M.maxLevel end
function IsXPUserDisabled() return M.xpDisabled end
function IsInInstance() return M.instance ~= nil, M.instance or "none" end
-- M.group lists the other members' units ("party1", ...), set in M.units.
function GetNumGroupMembers() return #M.group > 0 and #M.group + 1 or 0 end
function IsInRaid() return M.raid end
function GetMoney() return M.money end
function IsMounted() return M.mounted end
function UnitOnTaxi() return M.taxi end
function IsSwimming() return M.swimming end
function IsFlying() return false end
function IsFalling() return M.falling end
function IsIndoors() return M.indoors end
function UnitIsDeadOrGhost() return M.dead or M.ghost end
function UnitIsDead(unit)
	if unit == "player" then return M.dead end
	local u = M.units[unit]
	return u and u.dead or false
end
function UnitIsGhost() return M.ghost end
function UnitAffectingCombat() return M.combat end
function GetRealZoneText() return M.zone end
function GetSubZoneText() return M.subzone end
function GetBindLocation() return M.bind end
function UnitPosition()
	if not M.wa then return nil end
	return M.wa, M.wb, 0, M.inst
end

C_Map = {}
function C_Map.GetBestMapForUnit() return M.mapID end
function C_Map.GetPlayerMapPosition()
	if not M.x then return nil end
	return { x = M.x, y = M.y }
end
-- Elwynn Forest (1429) and Westfall (1436) inside Eastern Kingdoms (1415).
M.rects = { ["1429:1415"] = { 0.40, 0.50, 0.70, 0.80 }, ["1436:1415"] = { 0.35, 0.42, 0.75, 0.85 } }
function C_Map.GetMapRectOnMap(map, top)
	local r = M.rects[map .. ":" .. top]
	if r then return r[1], r[2], r[3], r[4] end
end

C_QuestLog = {}
function C_QuestLog.GetTitleForQuestID(id) return M.quests[id] end
C_Spell = {}
M.spellNames = { [2366] = "Herb Gathering", [2575] = "Mining", [3365] = "Opening", [8613] = "Skinning", [133] = "Fireball" }
function C_Spell.GetSpellName(id) return M.spellNames[id] end
C_Container = {}
function C_Container.UseContainerItem() end
function C_Container.GetContainerItemLink(bag, slot) return M.bags[bag .. ":" .. slot] end

-- Casting: fires SENT then SUCCEEDED like the client does.
function M.cast(spellID, target)
	local guid = "Cast-" .. spellID .. "-" .. M.gametime
	M.fire("UNIT_SPELLCAST_SENT", "player", target or "", guid, spellID)
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", guid, spellID)
end

-- Loot window
function GetNumLootItems() return #M.loot end
function GetLootSlotInfo(i) local s = M.loot[i]; return 133784, s.name, s.qty end
function GetLootSlotLink(i) return M.loot[i].link end
function GetLootSlotType(i) return M.loot[i].type or 1 end
function GetLootSourceInfo(i) return M.loot[i].guid, M.loot[i].qty end
function IsFishingLoot() return M.fishing or false end

-- Opens a loot window on M.loot, takes the given slots (all when nil) and
-- closes it, like autoloot.
function M.lootAll(take)
	M.fire("LOOT_READY", true)
	M.fire("LOOT_OPENED", true, false)
	for i = 1, #M.loot do
		if not take or take[i] then M.fire("LOOT_SLOT_CLEARED", i) end
	end
	M.fire("LOOT_CLOSED")
end

-- Merchant
C_MerchantFrame = {}
function C_MerchantFrame.GetItemInfo(i) return M.merchantItems[i] end
function GetMerchantItemLink(i) local it = M.merchantItems[i]; return it and it.link end
function BuyMerchantItem() end
function GetNumBuybackItems() return #M.buyback end
function GetBuybackItemInfo(i) local b = M.buyback[i]; if b then return b.name, 1, b.price, b.count end end
function GetBuybackItemLink(i) local b = M.buyback[i]; return b and b.link end
function BuybackItem() end
function GetRepairAllCost() return M.repairCost, M.repairCost > 0 end
function RepairAllItems() end

-- Taxi
function NumTaxiNodes() return #M.taxiNodes end
function TaxiNodeName(i) return M.taxiNodes[i] and M.taxiNodes[i].name end
function TaxiNodeGetType(i) return M.taxiNodes[i] and M.taxiNodes[i].type end
function TaxiNodeCost(i) return M.taxiNodes[i] and M.taxiNodes[i].cost end
function TakeTaxiNode() end

function GetQuestReward() end
function JumpOrAscendStart() end

-- World map: Blizzard's frames survive reloads, addon frames don't.
M.canvas = CreateFrame("Frame")
M.canvas.w, M.canvas.h, M.canvas.level = 1000, 667, 3
WorldMapFrame = CreateFrame("Frame")
WorldMapFrame.scale = 1
function WorldMapFrame:GetCanvas() return M.canvas end
function WorldMapFrame:GetMapID() return M.viewMap end
function WorldMapFrame:GetCanvasScale() return self.scale end
function WorldMapFrame:GetPinFrameLevelsManager()
	return { GetValidFrameLevel = function(_, kind) assert(kind == "PIN_FRAME_LEVEL_MAP_HIGHLIGHT"); return 2009 end }
end
local blizzardFrames = { M.canvas, WorldMapFrame }

-- The newest addon frame drawn on the map canvas.
function M.mapOverlay()
	local found
	for _, f in ipairs(M.frames) do
		if f.parent == M.canvas then found = f end
	end
	return found
end

SlashCmdList = {}
function ReloadUI() M.reloadRequested = true end

--------------------------------------------------------------------------------
-- Addons and SavedVariables
--------------------------------------------------------------------------------

local function ReadToc(name)
	local path = REPO .. "/" .. name .. "/" .. name .. ".toc"
	local f = io.open(path)
	if not f then return nil end
	local toc = { name = name, files = {}, saved = {}, perChar = {} }
	for line in f:lines() do
		line = line:gsub("\r$", "")
		local key, value = line:match("^##%s*([%w%-]+):%s*(.-)%s*$")
		if key == "SavedVariables" then
			for var in value:gmatch("[^,%s]+") do toc.saved[#toc.saved + 1] = var end
		elseif key == "SavedVariablesPerCharacter" then
			for var in value:gmatch("[^,%s]+") do toc.perChar[#toc.perChar + 1] = var end
		elseif key == "LoadOnDemand" then
			toc.loadOnDemand = value == "1"
		elseif key == "Dependencies" or key == "RequiredDeps" then
			toc.deps = value
		elseif not line:match("^#") and line:match("%.lua$") then
			toc.files[#toc.files + 1] = line
		end
	end
	f:close()
	return toc
end

local function Installed(name)
	for _, n in ipairs(M.installed) do
		if n == name then return true end
	end
	return false
end

-- Serializes a SavedVariables value the way the client would write it.
-- Functions and other non-data can't be saved, so they fail the test.
local function Serialize(v, indent, out)
	local t = type(v)
	if t == "string" then
		out[#out + 1] = ("%q"):format(v)
	elseif t == "number" or t == "boolean" then
		out[#out + 1] = tostring(v)
	elseif t == "table" then
		out[#out + 1] = "{\n"
		local n = #v
		for i = 1, n do
			out[#out + 1] = indent .. "\t"
			Serialize(v[i], indent .. "\t", out)
			out[#out + 1] = ", -- [" .. i .. "]\n"
		end
		for k, val in pairs(v) do
			if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then
				assert(type(k) == "string" or type(k) == "number", "can't save a key of type " .. type(k))
				out[#out + 1] = indent .. "\t["
				Serialize(k, "", out)
				out[#out + 1] = "] = "
				Serialize(val, indent .. "\t", out)
				out[#out + 1] = ",\n"
			end
		end
		out[#out + 1] = indent .. "}"
	else
		error("can't save a value of type " .. t)
	end
end

local function SaveVars(vars)
	local out = {}
	for _, var in ipairs(vars) do
		if _G[var] ~= nil then
			out[#out + 1] = var .. " = "
			Serialize(_G[var], "", out)
			out[#out + 1] = "\n"
		end
	end
	return table.concat(out)
end

-- Saved text per addon (account-wide) and per character.
M.saved, M.savedChar = {}, {}
M.loaded = {}

local function CharKey() return M.player.name .. "-" .. M.player.realm end

local function Load(name)
	local toc = ReadToc(name)
	assert(toc, "no addon " .. name)
	local ns = {}
	for _, file in ipairs(toc.files) do
		local chunk = assert(loadfile(REPO .. "/" .. name .. "/" .. file))
		chunk(name, ns)
	end
	-- Like the client: SavedVariables are read after the addon's files run.
	for _, text in ipairs({ M.saved[name] or "", (M.savedChar[CharKey()] or {})[name] or "" }) do
		assert(loadstring(text, "@SavedVariables/" .. name))()
	end
	M.loaded[name] = { toc = toc, ns = ns }
	M.fire("ADDON_LOADED", name)
	return ns
end

function M.ns(name) return M.loaded[name or M.installed[1]].ns end

C_AddOns = {}
function C_AddOns.DoesAddOnExist(name) return Installed(name) and ReadToc(name) ~= nil end
function C_AddOns.IsAddOnLoaded(name) return M.loaded[name] ~= nil, M.loaded[name] ~= nil end
function C_AddOns.LoadAddOn(name)
	if M.loaded[name] then return true end
	if not C_AddOns.DoesAddOnExist(name) then return false, "MISSING" end
	if M.disabled[name] then return false, "DISABLED" end
	Load(name)
	return true
end

function M.Login()
	for _, name in ipairs(M.installed) do
		local toc = ReadToc(name)
		if toc and not toc.loadOnDemand and not M.disabled[name] then
			Load(name)
		end
	end
	M.fire("PLAYER_LOGIN")
	M.fire("PLAYER_ENTERING_WORLD", true, false)
	return M.ns()
end

-- Logs out: saves every loaded addon's variables (files of addons that
-- weren't loaded stay as they were) and clears all addon state.
function M.Logout()
	M.fire("PLAYER_LOGOUT")
	local key = CharKey()
	M.savedChar[key] = M.savedChar[key] or {}
	for name, addon in pairs(M.loaded) do
		M.saved[name] = SaveVars(addon.toc.saved)
		M.savedChar[key][name] = SaveVars(addon.toc.perChar)
		for _, var in ipairs(addon.toc.saved) do _G[var] = nil end
		for _, var in ipairs(addon.toc.perChar) do _G[var] = nil end
	end
	for i = #hooks, 1, -1 do
		hooks[i].tbl[hooks[i].name] = hooks[i].orig
		hooks[i] = nil
	end
	M.loaded, M.tickers, M.frames = {}, {}, { unpack(blizzardFrames) }
	M.canvas.children = nil
	SlashCmdList = {}
	M.tooltipPostCalls = {}
	M.reloadRequested = nil
end

function M.Reload()
	M.Logout()
	return M.Login()
end

-- Size in bytes of an addon's saved file (as of the last logout).
function M.savedSize(name, perCharacter)
	if perCharacter then
		return #((M.savedChar[CharKey()] or {})[name] or "")
	end
	return #(M.saved[name] or "")
end
