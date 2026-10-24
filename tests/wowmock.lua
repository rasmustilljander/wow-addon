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
	money = 10000, level = 5, played = 90000, playedLevel = 3600, xp = 0, xpMax = 2800, rested = nil, maxLevel = 60, xpDisabled = false,
	instance = nil, group = {}, raid = false, mapID = 1429, x = 0.42, y = 0.65,
	inst = 0, wa = -9000, wb = -100, zone = "Elwynn Forest", subzone = "Goldshire",
	mounted = false, taxi = false, swimming = false, dead = false, ghost = false, falling = false, afk = false,
	combat = false, indoors = false, secrets = {}, viewMap = 1429, facing = 0, minimapRadius = 200,
	auras = {},
	loot = {}, buyback = {}, merchantItems = {}, units = {}, taxiNodes = {},
	quests = {}, questLog = {}, failedQuests = {}, questTimers = {}, bind = "Goldshire", bags = {}, repairCost = 0, canRepair = false,
	installed = { "TravelLog", "TravelLog_Path", "TravelLog_Nodes" }, -- addon folders the fake client knows about
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
	M.played, M.playedLevel = M.played + seconds, M.playedLevel + seconds
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
UNKNOWNOBJECT = "Unknown"
COMBATLOG_XPGAIN_FIRSTPERSON_GROUP = "%s dies, you gain %d experience. (+%d group bonus)"
ERR_ZONE_EXPLORED = "Discovered: %s"
ERR_ZONE_EXPLORED_XP = "Discovered %s: %d experience gained"
ERR_LEARN_SPELL_S = "You have learned a new spell: %s."
ERR_LEARN_ABILITY_S = "You have learned a new ability: %s."
ERR_LEARN_RECIPE_S = "You have learned how to create a new item: %s."
ERR_NEWTAXIPATH = "New flight path discovered!"
FACTION_STANDING_CHANGED = "You are now %s with %s."
FACTION_STANDING_INCREASED = "Reputation with %s increased by %d."
FACTION_STANDING_DECREASED = "Reputation with %s decreased by %d."
ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
ERR_TRADE_COMPLETE = "Trade complete."
DUEL_WINNER_KNOCKOUT = "%1$s has defeated %2$s in a duel"
DUEL_WINNER_RETREAT = "%2$s has fled from %1$s in a duel"
COMBATLOG_HONORGAIN = "%s dies (Honorable Kill: %s). You gain %d Honor."
COMBATLOG_HONORGAIN_EXHAUSTION1 = "%s dies (Honorable Kill: %s). You gain %d Honor (%s %s bonus)."
COMBATLOG_HONORGAIN_NO_RANK = "%s dies (Honorable Kill). You gain %d Honor."
COMBATLOG_HONORAWARD = "You have been awarded %d Honor."
PVP_RANK_0_NAME = "No Rank"
PVP_RANK_5_1, PVP_RANK_6_1, PVP_RANK_7_1 = "Private", "Corporal", "Sergeant"
PVP_RANK_5_0, PVP_RANK_6_0, PVP_RANK_7_0 = "Scout", "Grunt", "Sergeant"
ERR_GUILD_ACCEPT = "You have joined the guild."
ERR_GUILD_FOUNDER_S = "Congratulations, you are a founding member of %s!"
ERR_GUILD_JOIN_S = "%s has joined the guild."
ERR_GUILD_LEAVE_RESULT = "You have left the guild."
ERR_GUILD_LEAVE_S = "%s has left the guild."
ERR_GUILD_REMOVE_SELF = "You have been kicked out of the guild."
ERR_GUILD_REMOVE_SS = "%s has been kicked out of the guild by %s."
ERR_GUILD_DISBANDED = "Guild has been disbanded."
ERR_GUILD_DISBAND_SELF = "You have disbanded the guild."
ERR_GUILD_DISBAND_S = "%s has disbanded the guild."
ERR_GUILD_PROMOTE_SSS = "%s has promoted %s to %s."
ERR_GUILD_DEMOTE_SSS = "%s has demoted %s to %s."
ERR_GUILD_LEADER_CHANGED_SS = "%s has made %s the new Guild Master."

Enum = {
	PlayerInteractionType = { None = 0, TradePartner = 1, Merchant = 5, TaxiNode = 6, Trainer = 7, Banker = 8, GuildBanker = 10, MailInfo = 17,
		SpiritHealer = 18, Binder = 20, Auctioneer = 21, StableMaster = 22 },
	LootSlotType = { None = 0, Item = 1, Money = 2, Currency = 3 },
	TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Corpse = 3, Object = 4 },
	ConsoleCommandType = { Cvar = 0, Command = 1, Macro = 2, Script = 3 },
	ConsoleCategory = { Debug = 0, Graphics = 1, Console = 2, Combat = 3, Game = 4, Default = 5, Net = 6, Sound = 7, Gm = 8, Reveal = 9, None = 10 },
	ItemQuality = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 },
	BagIndex = { Keyring = -1, Backpack = 0, CharacterBankTab_1 = 6, AccountBankTab_1 = 15 },
	BankType = { Character = 0, Guild = 1, Account = 2 },
	EncounterLootDropRollState = { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 },
	AuctionStatus = { Active = 0, Sold = 1 },
	SendAddonMessageResult = { Success = 0, InvalidPrefix = 1, InvalidMessage = 2, AddonMessageThrottle = 3, InvalidChatType = 4,
		NotInGroup = 5, TargetRequired = 6, InvalidChannel = 7, ChannelThrottle = 8, GeneralError = 9, NotInGuild = 10,
		AddOnMessageLockdown = 11, TargetOffline = 12 },
	PvPRanks = { RankNone = 0, Rank_1 = 5, Rank_14 = 18 },
	PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 },
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
QUEST_TURNED_IN QUEST_REMOVED QUEST_LOG_UPDATE PARTY_KILL UNIT_DIED NAME_PLATE_UNIT_ADDED PLAYER_TARGET_CHANGED UPDATE_MOUSEOVER_UNIT CVAR_UPDATE
PLAYER_REGEN_DISABLED PLAYER_REGEN_ENABLED PLAYERBANKSLOTS_CHANGED PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED
PLAYER_EQUIPMENT_CHANGED MAIL_INBOX_UPDATE MAIL_SEND_SUCCESS MAIL_FAILED OWNED_AUCTIONS_UPDATED
AUCTION_HOUSE_AUCTION_CREATED AUCTION_CANCELED CHAT_MSG_ADDON SKILL_LINES_CHANGED LEARNED_SPELL_IN_SKILL_LINE
NEW_RECIPE_LEARNED CHAT_MSG_COMBAT_FACTION_CHANGE PLAYER_MOUNT_DISPLAY_CHANGED MERCHANT_FILTER_ITEM_UPDATE
GROUP_ROSTER_UPDATE PLAYER_XP_UPDATE TIME_PLAYED_MSG TRADE_PLAYER_ITEM_CHANGED TRADE_ACCEPT_UPDATE CONFIRM_SUMMON
RESURRECT_REQUEST MIRROR_TIMER_START MIRROR_TIMER_STOP MIRROR_TIMER_PAUSE
GUILDBANKFRAME_OPENED GUILDBANKFRAME_CLOSED GUILDBANKBAGSLOTS_CHANGED BARBER_SHOP_OPEN BARBER_SHOP_CLOSE
TRAIT_CONFIG_UPDATED TRAIT_CONFIG_LIST_UPDATED PLAYER_TALENT_UPDATE ACTIVE_TALENT_GROUP_CHANGED
DUEL_REQUESTED DUEL_TO_THE_DEATH_REQUESTED DUEL_FINISHED DUEL_INBOUNDS DUEL_OUTOFBOUNDS CHAT_MSG_COMBAT_HONOR_GAIN
PLAYER_PVP_KILLS_CHANGED SCREENSHOT_STARTED SCREENSHOT_SUCCEEDED SCREENSHOT_FAILED LOOT_HISTORY_UPDATE_DROP
UNIT_SPELLCAST_CHANNEL_START UNIT_SPELLCAST_CHANNEL_STOP UNIT_SPELLCAST_INTERRUPTED UNIT_PET
UPDATE_FACTION MAJOR_FACTION_RENOWN_LEVEL_CHANGED PLAYER_PVP_RANK_CHANGED PVP_MATCH_COMPLETE
PLAYER_GUILD_UPDATE GUILD_ROSTER_UPDATE GUILD_RANKS_UPDATE GUILD_INVITE_REQUEST
ACHIEVEMENT_EARNED ENCOUNTER_START ENCOUNTER_END PLAYER_UPDATE_RESTING PLAYER_FLAGS_CHANGED
PLAYER_ENTER_COMBAT PLAYER_LEAVE_COMBAT START_AUTOREPEAT_SPELL STOP_AUTOREPEAT_SPELL]]):gmatch("%S+") do
	M.KNOWN_EVENTS[e] = true
end

local Region = {}
Region.__index = Region

local function NewRegion(kind, parent)
	return setmetatable({ kind = kind, parent = parent, shown = true }, Region)
end

-- Runs a frame's script handler and the handlers hooked onto it.
function M.script(f, name, ...)
	if f.scripts and f.scripts[name] then f.scripts[name](f, ...) end
	for _, fn in ipairs(f.hooked and f.hooked[name] or {}) do fn(f, ...) end
end

function Region:Show() if not self.shown then self.shown = true; M.script(self, "OnShow") end end
function Region:Hide() if self.shown then self.shown = false; M.script(self, "OnHide") end end
function Region:SetShown(v) if v then self:Show() else self:Hide() end end
function Region:IsShown() return self.shown end
function Region:GetName() return self.name end
function Region:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function Region:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
function Region:SetTexture(t) self.texture = t end
function Region:SetThickness(t) self.thickness = t end
function Region:SetDrawLayer(layer, sublevel) self.layer, self.sublevel = layer, sublevel end
function Region:SetStartPoint(p, rel, x, y) assert(type(p) == "string" and rel); self.start = { x, y } end
function Region:SetEndPoint(p, rel, x, y) assert(type(p) == "string" and rel); self.stop = { x, y } end
function Region:SetSize(w, h) self.w, self.h = w, h end
function Region:SetWidth(w) self.w = w end
function Region:SetHeight(h) self.h = h end
function Region:ClearAllPoints() self.point = nil end
function Region:SetPoint(p, rel, rp, x, y) self.point = { p, rel, rp, x, y } end
-- The first point as the client reports it, relative frame included.
function Region:GetPoint()
	local p = self.point
	if not p then return nil end
	if type(p[2]) ~= "table" then return p[1], self.parent, p[1], p[2], p[3] end
	return p[1], p[2], p[3], p[4], p[5]
end
function Region:SetAllPoints(rel) self.allPoints = rel or self.parent end
function Region:GetWidth() return (self:GetSize()) end
function Region:GetCenter() return self.center[1], self.center[2] end
function Region:GetEffectiveScale() return self.scale or 1 end
function Region:GetSize()
	if self.w then return self.w, self.h end
	if self.allPoints then return self.allPoints:GetSize() end
	return 0, 0
end
function Region:SetFrameLevel(l) self.level = l end
function Region:RegisterForClicks(...) self.clicks = { ... } end
function Region:SetHighlightTexture(t) self.highlightTexture = t end
function Region:SetNormalTexture(t) self.normalTexture = t end
function Region:SetChecked(v) self.checked = v and true or false end
function Region:GetChecked() return self.checked or false end
function Region:GetFrameLevel() return self.level or 1 end
function Region:EnableMouse(v) self.mouse = v end
function Region:SetMouseClickEnabled(v) self.mouseClicks = v end
function Region:RegisterEvent(e)
	if not M.KNOWN_EVENTS[e] then error('Attempt to register unknown event "' .. e .. '"') end
	self.events = self.events or {}
	self.events[e] = true
end
function Region:UnregisterEvent(e)
	if self.events then self.events[e] = nil end
end
function Region:IsEventRegistered(e) return self.events ~= nil and self.events[e] == true end
function Region:SetScript(k, fn)
	self.scripts = self.scripts or {}
	self.scripts[k] = fn
	if self.hooked then self.hooked[k] = nil end
end
function Region:HookScript(k, fn)
	self.hooked = self.hooked or {}
	self.hooked[k] = self.hooked[k] or {}
	table.insert(self.hooked[k], fn)
end
function Region:GetScript(k) return self.scripts and self.scripts[k] end

-- Windows and their widgets: buttons, edit boxes, font strings.
function Region:SetText(t)
	local old = self.text
	self.text = t ~= nil and tostring(t) or ""
	if self.kind == "EditBox" and self.text ~= old then M.script(self, "OnTextChanged", false) end
end
function Region:GetText() return self.text or "" end
function Region:SetAtlas(a) self.atlas = a end
function Region:SetAlpha(a) self.alpha = a end
function Region:SetTexCoord() end
function Region:SetJustifyH(j) self.justifyH = j end
function Region:SetJustifyV(j) self.justifyV = j end
function Region:SetWordWrap(v) self.wordWrap = v end
function Region:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
function Region:SetFrameStrata(s) self.strata = s end
function Region:SetToplevel(v) self.toplevel = v end
function Region:SetClampedToScreen(v) self.clamped = v end
function Region:SetMovable(v) self.movable = v end
function Region:RegisterForDrag(...) self.drag = { ... } end
function Region:StartMoving() assert(self.movable, "StartMoving on a frame that isn't movable"); self.moving = true end
function Region:StopMovingOrSizing() self.moving = nil end
function Region:SetUserPlaced(v) self.userPlaced = v end
function Region:SetEnabled(v) self.disabled = not v end
function Region:Enable() self.disabled = false end
function Region:Disable() self.disabled = true end
function Region:IsEnabled() return not self.disabled end
function Region:LockHighlight() self.highlightLocked = true end
function Region:SetNormalFontObject(font) self.normalFont = font end
function Region:SetFontObject(font) self.font = font end
function Region:SetID(id) self.id = id end
function Region:GetID() return self.id or 0 end
function Region:UnlockHighlight() self.highlightLocked = false end
-- Clicking does nothing on a disabled button, like in the game. A check
-- button flips before its OnClick runs.
function Region:Click(button)
	if self.disabled then return end
	if self.kind == "CheckButton" then self.checked = not self.checked end
	M.script(self, "OnClick", button or "LeftButton", false)
end
function Region:SetAutoFocus(v) self.autoFocus = v end
function Region:SetFocus() M.focus = self end
function Region:ClearFocus() if M.focus == self then M.focus = nil end end
function Region:HasFocus() return M.focus == self end
function Region:CreateFontString()
	local fs = NewRegion("FontString", self)
	self.fontStrings = self.fontStrings or {}
	self.fontStrings[#self.fontStrings + 1] = fs
	return fs
end
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

-- What the Blizzard templates addons use add to a frame.
M.templates = {
	BasicFrameTemplateWithInset = function(f)
		f.TitleText = f:CreateFontString()
		f.CloseButton = CreateFrame("Button", nil, f)
		f.CloseButton:SetScript("OnClick", function() f:Hide() end)
	end,
	UICheckButtonTemplate = function(f)
		f.Text = f:CreateFontString()
	end,
	PanelTabButtonTemplate = function(f)
		f.Text = f:CreateFontString()
		f.parent.Tabs = f.parent.Tabs or {}
		table.insert(f.parent.Tabs, f)
	end,
	SearchBoxTemplate = function(f)
		f.searchIcon = f:CreateTexture()
		f.clearButton = CreateFrame("Button", nil, f)
		f.clearButton:SetScript("OnClick", function() f:SetText("") end)
	end,
	WowScrollBoxList = function(f)
		f.rows = {}
		-- Unlike the game, every element gets a row, so tests can reach them.
		function f:SetDataProvider(provider, retainScrollPosition)
			assert(self.view, "A view is required before assigning the data provider.")
			self.provider, self.retained = provider, retainScrollPosition
			for i, data in ipairs(provider.items) do
				self.rows[i] = self.rows[i] or CreateFrame(self.view.kind, nil, self)
				self.rows[i]:Show()
				self.view.init(self.rows[i], data)
			end
			for i = #provider.items + 1, #self.rows do self.rows[i]:Hide() end
		end
	end,
}

-- Named frames become globals; addon ones are removed on logout.
local namedFrames = {}
M.frames = {}
function CreateFrame(kind, name, parent, template)
	local f = NewRegion(kind, parent)
	M.frames[#M.frames + 1] = f
	if parent then
		parent.children = parent.children or {}
		parent.children[#parent.children + 1] = f
	end
	if name then
		f.name = name
		_G[name] = f
		namedFrames[#namedFrames + 1] = name
	end
	for t in (template or ""):gmatch("[^,%s]+") do
		if M.templates[t] then M.templates[t](f) end
	end
	return f
end

-- Scroll boxes: data providers, views and scroll bars.
function CreateDataProvider(items) return { items = items or {} } end
function CreateScrollBoxListLinearView()
	local view = {}
	function view:SetElementExtent(extent) self.extent = extent end
	function view:SetElementInitializer(kind, init) self.kind, self.init = kind, init end
	return view
end
ScrollUtil = {}
function ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view) box.view, box.scrollBar = view, bar end
ScrollBoxConstants = { RetainScrollPosition = true }
UISpecialFrames = {}
GameFontNormal, GameFontHighlight = { name = "GameFontNormal" }, { name = "GameFontHighlight" }
-- Tabs: the selected one is disabled, like in the game.
function PanelTemplates_SetNumTabs(frame, n) frame.numTabs = n end
function PanelTemplates_SetTab(frame, id)
	frame.selectedTab = id
	for i = 1, frame.numTabs do frame.Tabs[i]:SetEnabled(i ~= id) end
end
-- Every frame and font string under f, each frame's font strings first.
function M.descendants(f, list)
	list = list or {}
	for _, fs in ipairs(f.fontStrings or {}) do list[#list + 1] = fs end
	for _, child in ipairs(f.children or {}) do
		list[#list + 1] = child
		M.descendants(child, list)
	end
	return list
end
function InCombatLockdown() return M.combat end

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
M.timers = {}
function C_Timer.After(seconds, fn) M.timers[#M.timers + 1] = { at = M.gametime + seconds, fn = fn } end

function M.tick(n)
	for _ = 1, n or 1 do
		M.advance(1)
		for _, t in ipairs(M.tickers) do t.fn() end
		local due, keep = {}, {}
		for _, t in ipairs(M.timers) do
			if t.at <= M.gametime then due[#due + 1] = t else keep[#keep + 1] = t end
		end
		M.timers = keep
		for _, t in ipairs(due) do t.fn() end
	end
end

GameTooltip = { lines = {} }
function GameTooltip:SetOwner(owner) self.owner, self.lines, self.unit, self.item = owner, {}, nil, nil end
function GameTooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function GameTooltip:SetText(text) self.lines = { text } end
function GameTooltip:SetHyperlink(link) self.lines = { link } end
function GameTooltip:SetItemByID(id) self.lines, self.item = { C_Item.GetItemInfo(id) or ("Item " .. id) }, id end
function GameTooltip:AddDoubleLine(a, b) self.lines[#self.lines + 1] = a .. "  " .. b end
function GameTooltip:Show() self.shown = true end
function GameTooltip:Hide() self.shown = false end
function GameTooltip:GetUnit()
	if self.unit then return UnitName(self.unit), self.unit, UnitGUID(self.unit) end
end
function GameTooltip:GetItem()
	if self.item then local name, link = C_Item.GetItemInfo(self.item); return name, link, self.item end
end

-- The color picker. M.pickColor drags it to a color, which calls swatchFunc
-- and opacityFunc like the game; Okay and Cancel close it.
ColorPickerFrame = {}
function ColorPickerFrame:SetupColorPickerAndShow(info)
	self.info, self.shown = info, true
	self.color = { info.r, info.g, info.b, info.hasOpacity and info.opacity or 1 }
end
function ColorPickerFrame:GetColorRGB() return self.color[1], self.color[2], self.color[3] end
function ColorPickerFrame:GetColorAlpha() return self.color[4] end
function M.pickColor(r, g, b, a)
	ColorPickerFrame.color = { r, g, b, a or ColorPickerFrame.color[4] }
	ColorPickerFrame.info.swatchFunc()
	if ColorPickerFrame.info.opacityFunc then ColorPickerFrame.info.opacityFunc() end
end
function M.closeColorPicker(okay)
	local info = ColorPickerFrame.info
	if okay then
		info.swatchFunc()
		if info.opacityFunc then info.opacityFunc() end
	elseif info.cancelFunc then
		info.cancelFunc({ r = info.r, g = info.g, b = info.b, a = info.opacity })
	end
	ColorPickerFrame.shown = false
end

-- Tooltip post-calls added by addons, by tooltip data type.
M.tooltipPostCalls = {}
TooltipDataProcessor = { AllTypes = "ALL" }
function TooltipDataProcessor.AddTooltipPostCall(kind, fn)
	M.tooltipPostCalls[kind] = M.tooltipPostCalls[kind] or {}
	table.insert(M.tooltipPostCalls[kind], fn)
end

-- Runs the post-calls for a tooltip of this data type and returns its lines
-- without color codes.
local function ShowTooltip(data)
	for _, fn in ipairs(M.tooltipPostCalls[data.type] or {}) do
		fn(GameTooltip, data)
	end
	GameTooltip:Show()
	local lines = {}
	for i, line in ipairs(GameTooltip.lines) do
		lines[i] = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	end
	return lines
end

-- Shows the unit tooltip for a unit (like hovering it) and returns its lines
-- without color codes.
function M.hover(unit)
	GameTooltip:SetOwner(UIParent)
	GameTooltip.unit = unit
	GameTooltip:AddLine(UnitName(unit))
	return ShowTooltip({ type = Enum.TooltipDataType.Unit, guid = UnitGUID(unit) })
end

-- The same for an item, by item ID (like hovering it in the bags).
function M.hoverItem(id)
	GameTooltip:SetOwner(UIParent)
	GameTooltip.item = id
	GameTooltip:AddLine(C_Item.GetItemInfo(id) or ("Item " .. id))
	return ShowTooltip({ type = Enum.TooltipDataType.Item, id = id })
end

--------------------------------------------------------------------------------
-- Player and world
--------------------------------------------------------------------------------

-- A unit's realm is only returned when it's another realm, as in the game.
function UnitName(unit)
	if unit == "player" then return M.player.name end
	local u = M.units[unit]
	if u then return u.name, u.realm end
end
function UnitGUID(unit)
	if unit == "player" then return "Player-1-" .. M.player.name end
	local u = M.units[unit]
	return u and u.guid
end
-- Units around the player: M.units, or names the client still knows by GUID
-- (M.guidNames) after the unit is gone.
M.guidNames = {}
function UnitNameFromGUID(guid)
	for _, u in pairs(M.units) do
		if u.guid == guid then return u.name end
	end
	return M.guidNames[guid]
end
-- A unit's tooltip lines: its name, then u.title if it has one, then its level.
C_TooltipInfo = {}
function C_TooltipInfo.GetUnit(unit)
	local u = M.units[unit]
	if not u then return nil end
	local lines = { { leftText = u.name } }
	if u.title then lines[#lines + 1] = { leftText = u.title } end
	lines[#lines + 1] = { leftText = "Level " .. (u.level or 1) }
	return { lines = lines }
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
function GetNormalizedRealmName() return (M.player.realm:gsub("[%s%-]", "")) end
-- M.player.class (or M.units[unit].class) is the class file name, MAGE by
-- default.
function UnitClass(unit)
	local u = M.units[unit]
	local class = u and u.class or M.player.class or "MAGE"
	return class:sub(1, 1) .. class:sub(2):lower(), class
end
-- A few of RAID_CLASS_COLORS; unknown classes are white, as in the game.
local CLASS_COLORS = { MAGE = { 0.25, 0.78, 0.92, "ff3fc7eb" }, WARRIOR = { 0.78, 0.61, 0.43, "ffc69b6d" } }
function GetClassColor(class)
	local c = CLASS_COLORS[class]
	if c then return c[1], c[2], c[3], c[4] end
	return 1, 1, 1, "ffffffff"
end
function UnitRace() return "Human", "Human" end
function UnitFactionGroup() return "Alliance" end
function UnitLevel(unit)
	if unit == "player" then return M.level end
	local u = M.units[unit]
	return u and u.level or 0
end
-- u.family is a beast's creature family ("Cat").
function UnitCreatureFamily(unit)
	local u = M.units[unit]
	if u and u.family then return u.family, u.familyID or 1 end
end
function UnitXP() return M.xp end
-- /played: the server answers a second later with the time played then.
M.playedAsks = 0
function RequestTimePlayed()
	M.playedAsks = M.playedAsks + 1
	C_Timer.After(1, function() M.fire("TIME_PLAYED_MSG", M.played, M.playedLevel) end)
end
function UnitXPMax() return M.xpMax end
function GetXPExhaustion() return M.rested end
function IsResting() return M.resting == true end
function GetMaxPlayerLevel() return M.maxLevel end
function IsXPUserDisabled() return M.xpDisabled end
function IsInInstance() return M.instance ~= nil, M.instance or "none" end
-- Inside (M.instance set), M.instanceInfo = { name, difficultyName,
-- maxPlayers, instanceID } names the instance; outside, it's the zone.
function GetInstanceInfo()
	if not M.instance then return M.zone, "none", 0, "", 0, 0, false, M.inst, 0, nil, false end
	local i = M.instanceInfo or {}
	return i.name or M.zone, M.instance, 1, i.difficultyName or "Normal", i.maxPlayers or 5, 0, false,
		i.instanceID or 36, i.maxPlayers or 5, nil, false
end
-- Name, instance type, isHeroic, ... maxPlayers of a difficulty ID; only
-- the ones the tests use.
local DIFFICULTIES = { [1] = { "Normal", "party", 5 }, [2] = { "Heroic", "party", 5 }, [9] = { "40 Player", "raid", 40 } }
function GetDifficultyInfo(id)
	local d = DIFFICULTIES[id]
	if not d then return nil end
	return d[1], d[2], id == 2, false, id == 2, false, nil, false, 1, d[3], true
end
-- Your own speed in yards a second: running (7) unless M.speed says
-- otherwise, such as 0 standing on a boat.
function GetUnitSpeed() return M.speed or 7, 7, 7, 4.72 end
-- A summon on offer: M.summon = { by, area }, announced with CONFIRM_SUMMON.
C_SummonInfo = {}
function C_SummonInfo.GetSummonConfirmSummoner() return M.summon and M.summon.by end
function C_SummonInfo.GetSummonConfirmAreaName() return M.summon and M.summon.area or "" end
function C_SummonInfo.GetSummonConfirmTimeLeft() return M.summon and 120 or 0 end
function C_SummonInfo.ConfirmSummon() M.summon = nil end
function C_SummonInfo.CancelSummon() M.summon = nil end
C_UnitAuras = {}
function C_UnitAuras.GetPlayerAuraBySpellID(spellID) return M.auras[spellID] end
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
-- Only the player can be AFK; tests fire PLAYER_FLAGS_CHANGED themselves.
function UnitIsAFK(unit) return unit == "player" and M.afk end
-- Coming back to life. These only answer or do nothing; tests set M.dead and
-- M.ghost and fire PLAYER_ALIVE or PLAYER_UNGHOST themselves.
-- M.resurrecter: who's offering a resurrection, M.resSickness: whether it
-- brings resurrection sickness, M.selfRes: the death dialog's self-resurrect
-- options ({ name, optionType, id, canUse, isLimited, priority }).
function ResurrectGetOfferer() return M.resurrecter end
function ResurrectHasSickness() return M.resSickness == true end
function AcceptResurrect() end
function DeclineResurrect() end
function RetrieveCorpse() end
function RepopMe() end
C_DeathInfo = {}
function C_DeathInfo.GetSelfResurrectOptions() return M.selfRes end
function C_DeathInfo.UseSelfResurrectOption() end
C_PlayerInteractionManager = {}
function C_PlayerInteractionManager.ConfirmationInteraction() end
function C_PlayerInteractionManager.ClearInteraction() end
Constants = { LevelConstsExposed = { MIN_RES_SICKNESS_LEVEL = 10 } }
-- Breath and fatigue bars: milliseconds left by timer name ("BREATH",
-- "EXHAUSTION"). Tests fire MIRROR_TIMER_START/STOP/PAUSE themselves.
M.mirrorTimers = {}
function GetMirrorTimerProgress(name) return M.mirrorTimers[name] end
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
-- Where maps lie in the world: { continent, left, top, width, height } in
-- yards. Stormwind (84) is inside Elwynn's top left, Westfall west of it,
-- Teldrassil (1438) on another continent. World positions here are { x = east,
-- y = south }; the real client's axes differ, but addons only pass them back.
M.world = {
	[1429] = { 0, 0, 0, 3470, 2315 }, [84] = { 0, 300, 100, 1340, 890 },
	[1436] = { 0, -3500, 1000, 3500, 2333 }, [1438] = { 1, 0, 0, 5090, 3393 },
}
function CreateVector2D(x, y) return { x = x, y = y, GetXY = function(v) return v.x, v.y end } end
function C_Map.GetMapWorldSize(map) local w = M.world[map]; if w then return w[4], w[5] end return 0, 0 end
function C_Map.GetWorldPosFromMapPos(map, pos)
	local w = M.world[map]
	if w then return w[1], CreateVector2D(w[2] + pos.x * w[4], w[3] + pos.y * w[5]) end
end
function C_Map.GetMapPosFromWorldPos(continent, pos, map)
	local w = M.world[map]
	if w and w[1] == continent then return map, CreateVector2D((pos.x - w[2]) / w[4], (pos.y - w[3]) / w[5]) end
end
-- The minimap: how many yards its radius shows, and which way you face
-- (radians, counterclockwise from north) for a rotating one.
C_Minimap = {}
function C_Minimap.GetViewRadius() return M.minimapRadius end
function GetPlayerFacing() return M.facing end

-- CVars: M.cvars[name] = { value, default, help, category, secure, readOnly,
-- account, character, unlisted, max }. Names are case-insensitive, as in the
-- game. Unlisted ones are left out of ConsoleGetAllCommands, but still work.
M.cvars = {}
local function CVar(name)
	if name == nil then return nil end
	for n, c in pairs(M.cvars) do
		if n:lower() == name:lower() then return c, n end
	end
end
function ConsoleGetAllCommands()
	local list = { { command = "reloadui", help = "Reloads the UI", category = 2, commandType = 1, scriptContents = "", scriptParameters = "" } }
	for name, c in pairs(M.cvars) do
		if not c.unlisted then
			list[#list + 1] = { command = name, help = c.help or "", category = c.category or 5, commandType = 0, scriptContents = "", scriptParameters = "" }
		end
	end
	return list
end
C_CVar = {}
function C_CVar.GetCVar(name) local c = CVar(name); return c and c.value end
function C_CVar.GetCVarDefault(name) local c = CVar(name); return c and c.default end
function C_CVar.GetCVarInfo(name)
	local c = CVar(name)
	if not c then return nil end
	return c.value, c.default, c.account or false, c.character or false, false, c.secure or false, c.readOnly or false
end
-- Secure and read-only CVars return nothing, as in the game; values over
-- `max` are clamped.
function C_CVar.SetCVar(name, value)
	local c, n = CVar(name)
	if not c or c.secure or c.readOnly then return end
	value = tostring(value)
	if c.max and tonumber(value) and tonumber(value) > c.max then value = tostring(c.max) end
	c.value = value
	M.fire("CVAR_UPDATE", n, value)
	return true
end

C_QuestLog = {}
function C_QuestLog.GetTitleForQuestID(id) return M.quests[id] end
-- Abandoning: the Abandon button picks the selected quest, the confirmation
-- drops it. The client fires QUEST_REMOVED later, when the server agrees.
function C_QuestLog.SetSelectedQuest(id) M.selectedQuest = id end
function C_QuestLog.GetSelectedQuest() return M.selectedQuest or 0 end
function C_QuestLog.SetAbandonQuest() M.abandonQuest = M.selectedQuest end
function C_QuestLog.GetAbandonQuest() return M.abandonQuest or 0 end
function C_QuestLog.AbandonQuest() M.abandonQuest = nil end
-- The quest log as shown: M.questLog lists quest IDs and header names (a
-- collapsed header's quests left out). M.failedQuests[id] marks a failed
-- quest, M.questTimers[id] = { total = seconds, started = GetTime() } a timed one.
function C_QuestLog.GetNumQuestLogEntries()
	local quests = 0
	for _, entry in ipairs(M.questLog) do
		if type(entry) == "number" then quests = quests + 1 end
	end
	return #M.questLog, quests
end
function C_QuestLog.GetQuestIDForLogIndex(i)
	local entry = M.questLog[i]
	return type(entry) == "number" and entry or nil
end
function C_QuestLog.IsFailed(id) return M.failedQuests[id] == true end
function C_QuestLog.GetTimeAllowed(id)
	local timer = M.questTimers[id]
	if timer then
		return timer.total, math.min(M.gametime - timer.started, timer.total)
	end
end
C_Spell = {}
M.spellNames = { [2366] = "Herb Gathering", [2575] = "Mining", [3365] = "Opening", [8613] = "Skinning", [133] = "Fireball", [921] = "Pick Pocket", [1515] = "Tame Beast" }
function C_Spell.GetSpellName(id) return M.spellNames[id] end
M.spellRanks = {}
function C_Spell.GetSpellSubtext(id) return M.spellRanks[id] end
-- Spells being cast or queued, like auto attack (6603) while it's on.
M.currentSpells = {}
function C_Spell.IsCurrentSpell(id) return M.currentSpells[id] == true end

-- Range to the target: M.units.target.distance in yards. CheckInteractDistance
-- uses the client's distances (1 inspect, 2 trade, 3 duel, 4 follow, 5 pet
-- duel). M.swingReach[Enum.PlayerSwingType] = { min, max } yards of the weapon
-- for that swing type, nil when none is equipped.
local interactDistances = { 28, 8, 7, 28, 7 }
function CheckInteractDistance(unit, index)
	local u = M.units[unit]
	return u ~= nil and u.distance ~= nil and u.distance <= interactDistances[index]
end
M.swingReach = { [0] = { 0, 5 } }
C_SwingTimer = {}
function C_SwingTimer.IsTargetWithinSwingRange(swingType)
	local u, reach = M.units.target, M.swingReach[swingType]
	if not u or not u.hostile or u.dead or not u.distance or not reach then return nil end
	return u.distance >= reach[1] and u.distance <= reach[2]
end
-- Skill lines as the skills frame lists them: { skillID, name, rank, isHeader,
-- isCollapsed }. A collapsed header's skills are left out of the list.
M.skills = {}
C_SkillInfo = {}
function C_SkillInfo.GetNumSkillLines() return #M.skills end
function C_SkillInfo.GetSkillLineInfo(i)
	local s = M.skills[i]
	return s and { skillID = s.skillID or 0, name = s.name, rank = s.rank or 0, isHeader = s.isHeader or false, isCollapsed = s.isCollapsed or false, maxRank = s.maxRank or 0 }
end
-- Talents, as Forever's trait system: M.talentConfig is the active loadout's
-- ID (nil before the client has one) and M.loadouts[configID][nodeID] =
-- { spellID, tree, rank, max } its nodes, rank the points applied. All
-- loadouts share one tree whose display groups are M.talentTrees[groupID] =
-- name; a node is in group tree + 100 too (a currency group, unnamed).
-- M.talentsStaged: points placed in the talent frame, not applied yet.
M.talentConfig, M.loadouts, M.talentTrees = nil, {}, {}
local TALENT_TREE = 790
C_ClassTalents = {}
function C_ClassTalents.GetActiveConfigID() return M.talentConfig end
C_Traits = {}
function C_Traits.ConfigHasStagedChanges() return M.talentsStaged or false end
function C_Traits.GetConfigInfo(configID)
	if M.loadouts[configID] then
		return { ID = configID, type = 1, name = "", treeIDs = { TALENT_TREE }, usesSharedActionBars = false }
	end
end
function C_Traits.GetTreeNodes(treeID)
	local ids, seen = {}, {}
	if treeID == TALENT_TREE then
		for _, nodes in pairs(M.loadouts) do
			for id in pairs(nodes) do
				if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
			end
		end
	end
	table.sort(ids)
	return ids
end
function C_Traits.GetNodeInfo(configID, nodeID)
	local n = (M.loadouts[configID] or {})[nodeID]
	if not n then return end
	local entryID = nodeID * 10
	return {
		ID = nodeID, entryIDs = { entryID }, ranksPurchased = n.rank or 0, activeRank = n.rank or 0, currentRank = n.rank or 0,
		activeEntry = (n.rank or 0) > 0 and { entryID = entryID, rank = n.rank } or nil, maxRanks = n.max or 1,
		groupIDs = { n.tree + 100, n.tree },
	}
end
function C_Traits.GetEntryInfo(configID, entryID)
	local n = (M.loadouts[configID] or {})[entryID / 10]
	return n and { definitionID = entryID / 10, type = 1, maxRanks = n.max or 1, isAvailable = true, conditionIDs = {} }
end
function C_Traits.GetDefinitionInfo(definitionID)
	for _, nodes in pairs(M.loadouts) do
		if nodes[definitionID] then return { spellID = nodes[definitionID].spellID } end
	end
end
function C_Traits.GetGroupDisplayInfoByTreeID(treeID)
	local list = {}
	for groupID, name in pairs(M.talentTrees) do
		list[#list + 1] = { groupID = groupID, treeID = treeID, skillLineID = 0, orderIndex = groupID, displayName = name, icon = 0 }
	end
	return list
end
-- Bags: M.bags["bag:slot"] is an item link, or { link, count, locked }.
-- M.bagSlots[bag] is each bag's size and M.items[itemID] = { quality, price,
-- icon, noValue, level, uncached } what the client knows about an item
-- (uncached: GetItemInfo returns nothing yet).
NUM_BAG_SLOTS, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4, 5
M.bagSlots, M.items = { [0] = 16 }, {}
local function BagItem(key)
	local entry = M.bags[key]
	if type(entry) == "string" then return { link = entry, count = 1 } end
	return entry
end
local function LinkID(link) return tonumber(link:match("item:(%d+)")) end
C_Container = {}
function C_Container.UseContainerItem() end
function C_Container.GetContainerItemLink(bag, slot) local e = BagItem(bag .. ":" .. slot); return e and e.link end
function C_Container.GetContainerNumSlots(bag) return M.bagSlots[bag] or 0 end
function C_Container.GetContainerItemInfo(bag, slot)
	local key = bag .. ":" .. slot
	local e = BagItem(key)
	if not e then return nil end
	local id = LinkID(e.link)
	local item = M.items[id] or {}
	return {
		iconFileID = item.icon or 134400, stackCount = e.count or 1, isLocked = e.locked or M.cursorItem == key,
		quality = item.quality or 1, isReadable = false, hasLoot = false, hyperlink = e.link, isFiltered = false,
		hasNoValue = item.noValue or false, itemID = id, isBound = false, itemName = e.link:match("%[(.-)%]"),
	}
end
-- The cursor holds a bag slot's item (M.cursorItem = "bag:slot", which stays
-- locked; M.cursorSplit items of it after a split) or a worn item
-- ("equip:slot") until it's put down, cleared or deleted.
function C_Container.PickupContainerItem(bag, slot)
	local key = bag .. ":" .. slot
	if M.cursorItem then
		M.bags[M.cursorItem], M.bags[key] = M.bags[key], M.bags[M.cursorItem]
		M.cursorItem, M.cursorSplit = nil, nil
	elseif M.bags[key] then
		M.cursorItem = key
	end
end
function C_Container.SplitContainerItem(bag, slot, amount)
	local e = BagItem(bag .. ":" .. slot)
	if not M.cursorItem and e and amount < (e.count or 1) then
		M.cursorItem, M.cursorSplit = bag .. ":" .. slot, amount
	end
end
function PickupInventoryItem(slot)
	if not M.cursorItem and M.equipped[slot] then M.cursorItem = "equip:" .. slot end
end
local function CursorLink()
	local slot = M.cursorItem:match("^equip:(%d+)")
	return slot and M.equipped[tonumber(slot)] or BagItem(M.cursorItem).link
end
function GetCursorInfo()
	if M.cursorItem then
		local link = CursorLink()
		return "item", LinkID(link), link
	end
end
function CursorHasItem() return M.cursorItem ~= nil end
function ClearCursor() M.cursorItem, M.cursorSplit, M.deletePending = nil, nil, nil end
function DeleteCursorItem()
	local key = M.cursorItem
	if not key then return end
	if M.deleteWarning and not M.deletePending then
		M.deletePending = true
		return
	end
	local slot = key:match("^equip:(%d+)")
	if slot then
		M.equipped[tonumber(slot)] = nil
	elseif M.cursorSplit then
		local e = BagItem(key)
		M.bags[key] = { link = e.link, count = e.count - M.cursorSplit }
	else
		M.bags[key] = nil
	end
	M.cursorItem, M.cursorSplit, M.deletePending = nil, nil, nil
end
-- Equipped items: M.equipped[inventorySlot] = item link.
INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED = 1, 19
M.equipped = {}
function GetInventoryItemID(_, slot) local link = M.equipped[slot]; return link and LinkID(link) end
function GetInventoryItemLink(_, slot) return M.equipped[slot] end
-- Puts on a worn item (or takes it off with nil), as the client reports it.
function M.equip(slot, link)
	M.equipped[slot] = link
	M.fire("PLAYER_EQUIPMENT_CHANGED", slot, link == nil)
end

-- Worn items' durability: M.durability[inventorySlot] = { current, max }.
M.durability = {}
function GetInventoryItemDurability(slot)
	local d = M.durability[slot]
	if d then return d[1], d[2] end
end
-- The bank: its tabs are bags (Enum.BagIndex.CharacterBankTab_1 and up, the
-- account bank's from AccountBankTab_1), in M.bags and M.bagSlots like the
-- others. M.accountBank: the account bank can be seen. M.bankTabs[bankType]
-- is how many tabs (bank bag slots) are bought; buying one or moving gold
-- does nothing, since the result arrives later as events.
C_Bank = {}
M.bankTabs = {}
function C_Bank.CanViewBank(bankType) return bankType ~= Enum.BankType.Account or M.accountBank == true end
function C_Bank.FetchNumPurchasedBankTabs(bankType) assert(type(bankType) == "number"); return M.bankTabs[bankType] or 0 end
function C_Bank.PurchaseBankTab(bankType) assert(type(bankType) == "number") end
function C_Bank.DepositMoney(bankType, amount) assert(type(bankType) == "number" and type(amount) == "number") end
function C_Bank.WithdrawMoney(bankType, amount) assert(type(bankType) == "number" and type(amount) == "number") end
-- Paid at a class trainer and a stable master; the charge arrives later.
function ConfirmTalentWipe() end
C_StableInfo = {}
function C_StableInfo.BuyStableSlot() end
C_Item = {}
function C_Item.GetItemInfo(item)
	local id = tonumber(item) or LinkID(item)
	local it = M.items[id]
	if not it or it.uncached then return nil end
	local link = it.link or ("|cff9d9d9d|Hitem:" .. id .. "::::|h[Item " .. id .. "]|h|r")
	return link:match("%[(.-)%]"), link, it.quality or 1, it.level or 1, 1, "Junk", "Junk", 20, "", it.icon or 134400,
		it.price or 0, 15, 0, 0, 0, nil, false, ""
end
-- Nil while the item isn't cached.
function C_Item.GetItemQualityByID(item)
	local it = M.items[tonumber(item) or LinkID(item)]
	if not it or it.uncached then return nil end
	return it.quality or 1
end
-- Actual item level, preview flag and base item level.
function C_Item.GetDetailedItemLevelInfo(item)
	local it = M.items[tonumber(item) or LinkID(item)]
	if not it or it.uncached then return nil end
	return it.level or 1, false, it.level or 1
end
-- Item locations: only bag slots.
ItemLocation = {}
local ItemLocationMixin = {}
ItemLocationMixin.__index = ItemLocationMixin
function ItemLocationMixin:GetBagAndSlot() return self.bagID, self.slotIndex end
function ItemLocation:CreateFromBagAndSlot(bag, slot)
	return setmetatable({ bagID = bag, slotIndex = slot }, ItemLocationMixin)
end
function C_Item.DoesItemExist(loc) return BagItem(loc.bagID .. ":" .. loc.slotIndex) ~= nil end
function C_Item.GetItemLink(loc) local e = BagItem(loc.bagID .. ":" .. loc.slotIndex); return e and e.link end
function C_Item.GetStackCount(loc) return BagItem(loc.bagID .. ":" .. loc.slotIndex).count or 1 end
function C_Item.GetItemInfoInstant(item)
	local id = tonumber(item) or LinkID(item)
	return id, "Junk", "Junk", "", (M.items[id] or {}).icon or 134400, 15, 0
end
-- The guild bank: M.guildBankItems["tab:slot"] is an item link or { link,
-- count }, M.guildBankTabs how many tabs the guild has, M.guildBankTab the
-- one shown and M.guildBankHidden[tab] the tabs you may not view. Tests fire
-- GUILDBANKBAGSLOTS_CHANGED when a tab's items arrive.
M.guildBankItems, M.guildBankTabs, M.guildBankTab, M.guildBankHidden = {}, 0, 1, {}
local function GuildBankItem(tab, slot)
	local entry = M.guildBankItems[tab .. ":" .. slot]
	if type(entry) == "string" then return { link = entry, count = 1 } end
	return entry
end
function GetNumGuildBankTabs() return M.guildBankTabs end
function GetCurrentGuildBankTab() return M.guildBankTab end
function GetGuildBankTabInfo(tab)
	return "Tab " .. tab, 134400, not M.guildBankHidden[tab], true, -1, -1, false
end
function GetGuildBankItemInfo(tab, slot)
	local e = GuildBankItem(tab, slot)
	if not e then return nil, 0, false, false, nil end
	local item = M.items[LinkID(e.link)] or {}
	return item.icon or 134400, e.count or 1, false, false, item.quality or 1
end
function GetGuildBankItemLink(tab, slot) local e = GuildBankItem(tab, slot); return e and e.link end
-- Moving items in or out happens on the server: tests change M.bags and
-- fire BAG_UPDATE_DELAYED.
function PickupGuildBankItem(tab, slot) end
function AutoStoreGuildBankItem(tab, slot) end
function SplitGuildBankItem(tab, slot, amount) end

-- The game's Options window. M.settings[name] is an addon's page under
-- AddOns ({ name, controls = { { setting, tooltip } } }). Ticking a checkbox
-- is control.setting:SetValue(value).
Settings = { VarType = { Boolean = "boolean", String = "string", Number = "number" } }
M.settings = {}
local SettingMixin = {}
SettingMixin.__index = SettingMixin
function SettingMixin:GetVariable() return self.variable end
function SettingMixin:GetName() return self.name end
function SettingMixin:GetVariableType() return self.variableType end
function SettingMixin:GetDefaultValue() return self.defaultValue end
function SettingMixin:GetValue() return self.variableTbl[self.variableKey] end
function SettingMixin:SetValue(value) self.variableTbl[self.variableKey] = value end
local CategoryMixin = {}
CategoryMixin.__index = CategoryMixin
function CategoryMixin:GetID() return self.id end
function CategoryMixin:GetName() return self.name end
function Settings.RegisterVerticalLayoutCategory(name)
	local category = setmetatable({ id = name, name = name, controls = {} }, CategoryMixin)
	return category, {}
end
function Settings.RegisterAddOnSetting(category, variable, variableKey, variableTbl, variableType, name, defaultValue)
	assert(type(variableTbl) == "table", "'variableTbl' argument must be a table.")
	assert(type(defaultValue) == variableType)
	if variableTbl[variableKey] == nil then variableTbl[variableKey] = defaultValue end
	return setmetatable({ variable = variable, variableKey = variableKey, variableTbl = variableTbl,
		variableType = variableType, name = name, defaultValue = defaultValue }, SettingMixin)
end
function Settings.CreateCheckbox(category, setting, tooltip)
	assert(setting:GetVariableType() == "boolean")
	local control = { setting = setting, tooltip = tooltip }
	category.controls[#category.controls + 1] = control
	return control
end
function Settings.RegisterAddOnCategory(category) M.settings[category:GetName()] = category end

-- Casting: fires SENT then SUCCEEDED like the client does.
function M.cast(spellID, target)
	local guid = "Cast-" .. spellID .. "-" .. M.gametime
	M.fire("UNIT_SPELLCAST_SENT", "player", target or "", guid, spellID)
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", guid, spellID)
end

-- Channeling: M.channel(spellID, seconds) starts one (CHANNEL_START), and
-- M.channelStop(interrupted) ends it (INTERRUPTED first if interrupted).
function M.channel(spellID, seconds)
	M.channeling = { spellID = spellID, guid = "Cast-" .. spellID .. "-" .. M.gametime,
		started = M.gametime, ends = M.gametime + seconds }
	M.fire("UNIT_SPELLCAST_CHANNEL_START", "player", M.channeling.guid, spellID)
end
function M.channelStop(interrupted)
	local c = M.channeling
	M.channeling = nil
	if interrupted then M.fire("UNIT_SPELLCAST_INTERRUPTED", "player", c.guid, c.spellID, "") end
	M.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", c.guid, c.spellID, "")
end
function UnitChannelInfo(unit)
	local c = unit == "player" and M.channeling
	if c then
		local name = M.spellNames[c.spellID] or ""
		return name, name, 136243, c.started * 1000, c.ends * 1000, false, false, c.spellID, false, 0, nil
	end
end

-- Loot window
function GetNumLootItems() return #M.loot end
function GetLootSlotInfo(i) local s = M.loot[i]; return 133784, s.name, s.qty end
function GetLootSlotLink(i) return M.loot[i].link end
function GetLootSlotType(i) return M.loot[i].type or 1 end
-- A slot can come from several corpses: sources = { guid, qty, guid, qty, ... }.
function GetLootSourceInfo(i)
	local s = M.loot[i]
	if s.sources then return unpack(s.sources) end
	return s.guid, s.qty
end
function IsFishingLoot() return M.fishing or false end

-- Group loot rolls. M.lootDrops[encounterID][lootListKey] is the drop's
-- EncounterLootDropInfo: { itemHyperlink, playerRollState, winner, allPassed,
-- rollInfos = { { playerName, isSelf, state, isWinner, roll }, ... } }.
M.lootDrops = {}
C_LootHistory = {}
function C_LootHistory.GetSortedInfoForDrop(encounterID, lootListKey)
	return (M.lootDrops[encounterID] or {})[lootListKey]
end

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

-- Mail. M.inbox = { { sender, money, cod, invoice, items = { { link, count, currency }, ... } }, ... },
-- invoice being an auction house mail's { type, item, player } ("seller" for a sale);
-- M.sendItems[i] = { link, count } are the attachments of the mail being
-- written, and SendMail puts { to, items } in M.sentMail. Taking money or
-- items does nothing: as in the game, the result arrives later as events.
M.inbox, M.sendItems, M.sentMail = {}, {}, {}
function GetInboxNumItems() return #M.inbox, #M.inbox end
function GetInboxHeaderInfo(i)
	local m = M.inbox[i]
	return nil, nil, m.sender or "Someone", m.subject or "", m.money or 0, m.cod or 0, 30, #(m.items or {}), false
end
function GetInboxInvoiceInfo(i)
	local inv = M.inbox[i].invoice
	if inv then return inv.type, inv.item, inv.player, inv.bid or 0, inv.buyout or 0, inv.deposit or 0, inv.consignment or 0 end
end
function TakeInboxMoney(i) assert(M.inbox[i]) end
function TakeInboxItem(i, a) assert(M.inbox[i] and a) end
function AutoLootMailItem(i) assert(M.inbox[i]) end
function GetInboxItem(i, a)
	local it = (M.inbox[i].items or {})[a]
	if not it then return nil end
	local id = LinkID(it.link)
	return it.link:match("%[(.-)%]"), id, 134400, it.count or 1, (M.items[id] or {}).quality or 1, true, it.currency or false
end
function GetSendMailItem(i)
	local it = M.sendItems[i]
	if not it then return nil end
	local id = LinkID(it.link)
	return it.link:match("%[(.-)%]"), id, 134400, it.count or 1, (M.items[id] or {}).quality or 1
end
function SendMail(to) M.sentMail[#M.sentMail + 1] = { to = to, items = M.sendItems } end

-- Trade. M.tradeItems[i] = { link, count } is what you've put in trade slot
-- i (7 is "will not be traded"). Completing it is a UI_INFO_MESSAGE.
M.tradeItems = {}
function GetTradePlayerItemInfo(i)
	local it = M.tradeItems[i]
	if not it then return nil end
	local id = LinkID(it.link)
	return it.link:match("%[(.-)%]"), 134400, it.count or 1, (M.items[id] or {}).quality or 1, nil, false, false, id
end
function GetTradePlayerItemLink(i) return M.tradeItems[i] and M.tradeItems[i].link end

-- Auction house. M.ownedAuctions = { OwnedAuctionInfo, ... } is what
-- GetOwnedAuctions returns after QueryOwnedAuctions, which counts its calls
-- in M.ownedQueries.
M.ownedAuctions, M.ownedQueries = {}, 0
C_AuctionHouse = {}
function C_AuctionHouse.QueryOwnedAuctions(sorts) assert(type(sorts) == "table"); M.ownedQueries = M.ownedQueries + 1 end
function C_AuctionHouse.HasFullOwnedAuctionResults() return true end
function C_AuctionHouse.GetOwnedAuctions() return M.ownedAuctions end
-- Posting: what was posted goes in M.posts ({ fn, item, duration, quantity,
-- ... }); M.postWarning makes a post need confirming. The auction exists
-- once the test fires AUCTION_HOUSE_AUCTION_CREATED.
M.posts = {}
local function Poster(fn, confirm)
	return function(item, duration, quantity, ...)
		assert(getmetatable(item) == ItemLocationMixin and type(duration) == "number" and type(quantity) == "number")
		M.posts[#M.posts + 1] = { fn = fn, item = item, duration = duration, quantity = quantity, ... }
		return not confirm and M.postWarning == true
	end
end
C_AuctionHouse.PostItem = Poster("PostItem")
C_AuctionHouse.PostCommodity = Poster("PostCommodity")
C_AuctionHouse.ConfirmPostItem = Poster("ConfirmPostItem", true)
C_AuctionHouse.ConfirmPostCommodity = Poster("ConfirmPostCommodity", true)

-- Merchant: M.merchantItems[i] is C_MerchantFrame.GetItemInfo's table plus
-- the item's link and cost: { { count, link = ..., currency = ... } }, what
-- GetMerchantItemCostItem returns. M.merchantFilter is the list's filter (all
-- by default).
LE_LOOT_FILTER_ALL, LE_LOOT_FILTER_CLASS, MAX_ITEM_COST = 1, 2, 3
C_MerchantFrame = {}
function C_MerchantFrame.GetItemInfo(i) return M.merchantItems[i] end
function GetMerchantNumItems() return #M.merchantItems end
function GetMerchantItemID(i) local it = M.merchantItems[i]; return it and LinkID(it.link) end
function GetMerchantFilter() return M.merchantFilter or LE_LOOT_FILTER_ALL end
function CanMerchantRepair() return M.canRepair end
function GetMerchantItemLink(i) local it = M.merchantItems[i]; return it and it.link end
function GetMerchantItemCostInfo(i) local it = M.merchantItems[i]; return it and it.cost and #it.cost or 0 end
function GetMerchantItemCostItem(i, c)
	local it = M.merchantItems[i]
	local cost = it and it.cost and it.cost[c]
	if cost then return 134400, cost[1], cost.link, cost.currency end
end
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

-- Trainer: M.trainerServices[i] = { name, rank, cost }.
M.trainerServices = {}
function GetTrainerServiceInfo(i)
	local t = M.trainerServices[i]
	if t then return t.name, "available", 136116, 1, t.rank or "" end
end
function GetTrainerServiceCost(i) return M.trainerServices[i] and M.trainerServices[i].cost or 0, false end
function BuyTrainerService() end

function GetQuestReward() end

-- Duels: tests fire DUEL_REQUESTED, DUEL_FINISHED and the result line
-- themselves.
function StartDuel() end
function AcceptDuel() end
function CancelDuel() end
-- Honorable and dishonorable kills today; fire PLAYER_PVP_KILLS_CHANGED
-- after changing M.honorKills.
M.honorKills = 0
function GetPVPSessionStats() return M.honorKills, 0 end
-- Your PvP rank: renown with faction 2800 in the season M.pvpSeason (nil:
-- not loaded yet). Fire UPDATE_FACTION or MAJOR_FACTION_RENOWN_LEVEL_CHANGED
-- after changing M.pvpRank.
M.pvpRank, M.pvpSeason = 0, 1
C_MajorFactions = {}
function C_MajorFactions.GetMajorFactionProgressionInfo(factionID)
	if factionID ~= 2800 or not M.pvpRank then return nil end
	return { renownLevel = M.pvpRank, previousWeekProgressiveMaxLevel = 0, currentWeekProgressiveMaxLevel = 0,
		maxLevel = 14, renownReputationEarned = 0, renownLevelThreshold = 1000, weekNumber = 1 }
end
function GetCurrentArenaSeason() return M.pvpSeason end
-- Global strings by name; the female forms are left out.
function GetText(token) return _G[token] end
function UnitSex() return 2 end

-- Battlegrounds: your team (0 Horde, 1 Alliance) and your scoreboard line
-- (M.pvpScore = { killingBlows, honorableKills, deaths, honorGained }); fire
-- PVP_MATCH_COMPLETE(winner, duration) when the match ends.
M.pvpFaction = 1
function GetBattlefieldArenaFaction() return M.pvpFaction end
C_PvP = {}
function C_PvP.GetScoreInfoByPlayerGuid(guid)
	return M.pvpScore and guid == UnitGUID("player") and M.pvpScore or nil
end

-- Your guild: M.guild = { name, rank, rankIndex } or nil for none, and
-- M.guild.loading while the client knows you're in one but not which.
-- Tests fire PLAYER_GUILD_UPDATE and the system lines themselves.
function IsInGuild() return M.guild ~= nil end
function GetGuildInfo(unit)
	local g = M.guild
	if unit == "player" and g and not g.loading then return g.name, g.rank, g.rankIndex, nil end
end
C_GuildInfo = {}
M.rosterRequests = 0
function C_GuildInfo.GuildRoster() M.rosterRequests = M.rosterRequests + 1 end
function DeclineGuild() end

-- Achievements (Forever's Legacy Challenges): M.achievements[id] = { name,
-- points, category, reward, guild } and M.achievementCategories[id] = { name,
-- parent }. Tests fire ACHIEVEMENT_EARNED themselves.
M.achievements, M.achievementCategories = {}, {}
function GetAchievementInfo(id)
	local a = M.achievements[id]
	if a then
		return id, a.name, a.points or 0, true, 10, 22, 26, a.description or "", 0, 134400, a.reward or "", a.guild or false, true, nil
	end
end
function GetAchievementCategory(id) return M.achievements[id] and M.achievements[id].category end
function GetCategoryInfo(id)
	local c = M.achievementCategories[id]
	if c then return c.name, c.parent or -1, 0 end
end
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
UIParent = CreateFrame("Frame")
-- The minimap: 140 wide, its center at (1800, 900) in screen coordinates.
Minimap = CreateFrame("Frame", nil, UIParent)
Minimap.w, Minimap.h, Minimap.center = 140, 140, { 1800, 900 }
M.cursor = { 0, 0 }
function GetCursorPosition() return M.cursor[1], M.cursor[2] end
-- The chat window. It shows the answer to /played (M.chatLines) when it
-- gets TIME_PLAYED_MSG.
ChatFrame1 = CreateFrame("Frame")
CHAT_FRAMES = { "ChatFrame1" }
M.chatLines = {}
ChatFrame1:RegisterEvent("TIME_PLAYED_MSG")
ChatFrame1:SetScript("OnEvent", function(_, event, total)
	M.chatLines[#M.chatLines + 1] = ("Total time played: %d seconds"):format(total)
end)
local blizzardFrames = { M.canvas, WorldMapFrame, UIParent, Minimap, ChatFrame1 }

-- The newest addon frame drawn on the map canvas, or the newest one at a
-- frame level (each addon draws at its own).
function M.mapOverlay(level)
	local found
	for _, f in ipairs(M.frames) do
		if f.parent == M.canvas and (not level or f.level == level) then found = f end
	end
	return found
end

SlashCmdList = {}
function ReloadUI() M.reloadRequested = true end

-- Addon messages. Sent ones go to M.sent as { prefix, text, chatType,
-- target }; M.sendResult(prefix, text, chatType, target) can return another
-- Enum.SendAddonMessageResult (throttled, offline...). M.addonMessage
-- delivers a whisper from another player to the registered prefixes.
M.prefixes, M.sent = {}, {}
C_ChatInfo = {}
function C_ChatInfo.RegisterAddonMessagePrefix(prefix)
	assert(#prefix <= 16, "prefix too long")
	M.prefixes[prefix] = true
	return 0
end
function C_ChatInfo.SendAddonMessage(prefix, text, chatType, target)
	assert(#text <= 255, "addon message longer than 255 bytes: " .. #text)
	assert(not text:find("[%z\n]"), "addon message with a NUL or newline")
	local result = M.sendResult and M.sendResult(prefix, text, chatType, target) or 0
	if result == 0 then
		M.sent[#M.sent + 1] = { prefix = prefix, text = text, chatType = chatType, target = target }
	end
	return result
end
function M.addonMessage(sender, prefix, text)
	if M.prefixes[prefix] then
		M.fire("CHAT_MSG_ADDON", prefix, text, "WHISPER", sender, M.player.name, 0, 0, "", 0)
	end
end

-- Chat frame message filters. M.chat(event, text) sends a chat event and
-- returns whether the chat frame would show it.
M.chatFilters = {}
ChatFrameUtil = {}
function ChatFrameUtil.AddMessageEventFilter(event, fn)
	M.chatFilters[event] = M.chatFilters[event] or {}
	table.insert(M.chatFilters[event], fn)
end
function M.chat(event, text, ...)
	M.fire(event, text, ...)
	for _, fn in ipairs(M.chatFilters[event] or {}) do
		if fn(nil, event, text, ...) then return false end
	end
	return true
end

--------------------------------------------------------------------------------
-- Addons and SavedVariables
--------------------------------------------------------------------------------

local function ReadToc(name)
	local path = REPO .. "/" .. name .. "/" .. name .. ".toc"
	local f = io.open(path)
	if not f then return nil end
	local toc = { name = name, files = {}, saved = {}, perChar = {}, meta = {} }
	for line in f:lines() do
		line = line:gsub("\r$", "")
		local key, value = line:match("^##%s*([%w%-]+):%s*(.-)%s*$")
		if key then
			toc.meta[key] = value
		end
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
	-- The addon compartment (the minimap's addons dropdown) lists the addons
	-- whose .toc names an AddonCompartmentFunc. Clicking an entry calls that
	-- global with the addon's name and the mouse button.
	M.compartment = {}
	for name, addon in pairs(M.loaded) do
		local meta = addon.toc.meta
		if meta.AddonCompartmentFunc then
			M.compartment[name] = { text = meta.Title, icon = meta.IconTexture, Click = function(_, button)
				_G[meta.AddonCompartmentFunc](name, button or "LeftButton")
			end }
		end
	end
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
	M.loaded, M.tickers, M.timers, M.frames = {}, {}, {}, { unpack(blizzardFrames) }
	M.canvas.children, Minimap.children = nil, nil
	UIParent.children = { Minimap }
	for _, name in ipairs(namedFrames) do _G[name] = nil end
	namedFrames, UISpecialFrames, M.focus, M.cursorItem, M.cursorSplit, M.deletePending = {}, {}, nil, nil, nil, nil
	SlashCmdList = {}
	M.tooltipPostCalls = {}
	M.settings = {}
	M.chatFilters, M.prefixes = {}, {}
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
