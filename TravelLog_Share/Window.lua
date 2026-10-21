-- The Sharing tab in the TravelLog window, opened with /tl share: everyone
-- you share with, follow or who asked you for something. Pick one, or add
-- one by name, to choose what you share with them, follow their nodes and
-- ask for and read their log.
local _, ns = ...
local tl = TravelLog

local HEIGHT = 320       -- the tab, at least
local ROW_HEIGHT = 18    -- a player
local ENTRY_HEIGHT = 30  -- a log entry: what, then when and where
local LIST_WIDTH = 170   -- the player list
local DETAIL_X = 214     -- the selected player, right of the list and its scroll bar
local DETAIL_WIDTH = 226
local ASKED = "|cffff9933asked|r"

local page     -- the tab's page, once the window exists
local selected -- key of the player shown on the right
local added = {} -- key -> name typed in this session, listed until reload
local drawn    -- what the tab last showed; it's redrawn only when that changes

local function Times(n)
	return n == 1 and "once" or n .. " times"
end

local function CountNodes(peer)
	local n = 0
	for _, list in pairs(peer and peer.nodes or {}) do
		for _ in pairs(list) do
			n = n + 1
		end
	end
	return n
end

local function Describe(r)
	local what = r.what == "log" and ("log (%d)"):format(r.count or 0) or r.what
	return ("%s asked %s for %s: %s"):format(r.from, r.to, what, r.allowed and "sent" or "not allowed")
end

-- Everyone you share with, follow, got something from or who asked you,
-- by name: { key, name, allowed, follow, peer, asks, last }.
local function Players()
	local db, byKey, list = ns.db, {}, {}
	local function Get(key, name)
		if not byKey[key] then
			byKey[key] = { key = key, name = name }
			list[#list + 1] = byKey[key]
		end
		return byKey[key]
	end
	for key, name in pairs(db.allowed) do
		Get(key, name).allowed = true
	end
	for key, name in pairs(db.follow) do
		Get(key, name).follow = true
	end
	for key, peer in pairs(db.peers) do
		Get(key, peer.name).peer = peer
	end
	for _, r in ipairs(db.requests) do
		local name, key = ns.Name(r.from)
		if key then
			local p = Get(key, name)
			p.asks, p.last = (p.asks or 0) + 1, r
		end
	end
	for key, name in pairs(added) do
		Get(key, name)
	end
	table.sort(list, function(a, b) return a.key < b.key end)
	return list, byKey
end

local function Tag(p)
	if p.allowed and p.follow then
		return "share, follow"
	end
	return p.allowed and "share" or p.follow and "follow" or p.asks and ASKED or ""
end

local function AskedText(p)
	local r = p.last
	if not r then
		return "Hasn't asked you for anything."
	end
	local what = r.what == "log" and ("log (%d)"):format(r.count or 0) or r.what
	return ("Asked %s. Last %s ago, for %s from %s: %s"):format(Times(p.asks), tl.Ago(r.time), what, r.to,
		r.allowed and "sent" or "not allowed")
end

local function LogStatus(p)
	local key = p.key
	if ns.pending[key] then
		return ("Asked for %d entries, waiting..."):format(ns.pending[key].count)
	elseif ns.logRefused[key] then
		return "They haven't allowed you to see their log."
	end
	local log = p.peer and p.peer.log
	if log then
		return ("Their last %d entries, received %s ago:"):format(#log.entries, tl.Ago(log.received))
	end
	return "You haven't asked for their log."
end

local function Refresh()
	if not ns.db then
		return
	end
	-- The minute keeps "2m ago" current.
	local state = ("%d\n%d\n%s"):format(ns.version, time() / 60, selected or "")
	if state == drawn then
		return
	end
	drawn = state

	local list, byKey = Players()
	page.players:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants.RetainScrollPosition)
	local p = selected and byKey[selected]
	page.detail:SetShown(p ~= nil)
	page.hint:SetShown(p == nil)
	if not p then
		local last = ns.db.requests[#ns.db.requests]
		page.hint:SetText("Add a player by name, or pick one, to share with them or follow their nodes."
			.. (last and ("\n\nLast request, %s ago: %s"):format(tl.Ago(last.time), Describe(last)) or ""))
		return
	end
	local d = page.detail
	d.title:SetText(p.name)
	d.share:SetChecked(p.allowed)
	d.follow:SetChecked(p.follow)
	d.follow.Text:SetText(not p.follow and "Get their nodes"
		or ns.nodesRefused[p.key] and "Get their nodes (they said no)"
		or ("Get their nodes (%d)"):format(CountNodes(p.peer)))
	d.asked:SetText(AskedText(p))
	d.status:SetText(LogStatus(p))
	local entries, log = {}, p.peer and p.peer.log
	for i = #(log and log.entries or {}), 1, -1 do
		entries[#entries + 1] = log.entries[i]
	end
	d.log:SetDataProvider(CreateDataProvider(entries))
end

local function Select(key, name)
	added[key], selected = name, key
	Refresh()
end

local function InitPlayerRow(row, p)
	if not row.name then
		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.08)
		row.selected = row:CreateTexture(nil, "BACKGROUND")
		row.selected:SetAllPoints()
		row.selected:SetColorTexture(1, 0.82, 0, 0.15)
		row.tag = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		row.tag:SetPoint("RIGHT", -4, 0)
		row.tag:SetJustifyH("RIGHT")
		row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		row.name:SetPoint("LEFT", 4, 0)
		row.name:SetPoint("RIGHT", row.tag, "LEFT", -6, 0)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		row:SetScript("OnClick", function()
			selected = row.player.key
			Refresh()
		end)
	end
	row.player = p
	row.name:SetText(p.name)
	row.tag:SetText(Tag(p))
	row.selected:SetShown(p.key == selected)
end

-- What on top, when and where below.
local function InitEntryRow(row, e)
	if not row.what then
		row.what = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.what:SetPoint("TOPLEFT", 4, -2)
		row.what:SetPoint("RIGHT", -4, 0)
		row.what:SetJustifyH("LEFT")
		row.what:SetWordWrap(false)
		row.where = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		row.where:SetPoint("TOPLEFT", 4, -16)
		row.where:SetPoint("RIGHT", -4, 0)
		row.where:SetJustifyH("LEFT")
		row.where:SetWordWrap(false)
	end
	row.what:SetText(e.text)
	row.where:SetText(date("%m-%d %H:%M", e.time) .. "  " .. e.where)
end

local function List(parent, init, kind, extent)
	local list = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(extent)
	view:SetElementInitializer(kind, init)
	ScrollUtil.InitScrollBoxListWithScrollBar(list, bar, view)
	return list
end

local function Text(f, font, x, y, width)
	local text = f:CreateFontString(nil, "ARTWORK", font)
	text:SetPoint("TOPLEFT", x, y)
	text:SetWidth(width)
	text:SetJustifyH("LEFT")
	return text
end

local function Check(f, y, label, onClick)
	local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("TOPLEFT", -4, y)
	check.Text:SetFontObject(GameFontNormal)
	check.Text:SetText(label)
	check:SetScript("OnClick", function(self)
		local p = select(2, Players())[selected]
		onClick(self:GetChecked(), p.name, p.key)
		Refresh()
	end)
	return check
end

local function Button(f, text, width, x, y, onClick)
	local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	button:SetSize(width, 20)
	button:SetPoint("TOPLEFT", x, y)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

local function AddTyped()
	local name, key = ns.Name(page.name:GetText())
	if key and key ~= ns.me then
		page.name:SetText("")
		page.name:ClearFocus()
		Select(key, name)
	end
end

local function Build(f)
	page = f
	f.name = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	f.name:SetSize(LIST_WIDTH - 54, 20)
	f.name:SetPoint("TOPLEFT", 20, 0)
	f.name:SetAutoFocus(false)
	f.name:SetScript("OnEnterPressed", AddTyped)
	f.name:SetScript("OnEscapePressed", f.name.ClearFocus)
	f.add = Button(f, "Add", 48, LIST_WIDTH - 32, 0, AddTyped)

	f.players = List(f, InitPlayerRow, "Button", ROW_HEIGHT)
	f.players:SetPoint("TOPLEFT", 14, -28)
	f.players:SetPoint("BOTTOMLEFT", 14, 8)
	f.players:SetWidth(LIST_WIDTH)

	f.hint = Text(f, "GameFontDisable", DETAIL_X, -4, DETAIL_WIDTH)

	local d = CreateFrame("Frame", nil, f)
	d:SetPoint("TOPLEFT", DETAIL_X, 0)
	d:SetPoint("BOTTOMLEFT", DETAIL_X, 0)
	d:SetWidth(DETAIL_WIDTH)
	f.detail = d
	d.title = Text(d, "GameFontNormalLarge", 0, -2, DETAIL_WIDTH)
	d.title:SetWordWrap(false)
	d.share = Check(d, -22, "Share my nodes and log", function(on, name, key)
		if on then ns.Allow(name, key) else ns.Revoke(key) end
	end)
	d.follow = Check(d, -46, "Get their nodes", function(on, name, key)
		if on then ns.Follow(name, key) else ns.Unfollow(key) end
	end)
	d.asked = Text(d, "GameFontHighlightSmall", 0, -76, DETAIL_WIDTH)

	local label = Text(d, "GameFontNormal", 0, -112, 80)
	label:SetText("Ask for log")
	d.ask = {}
	for i, n in ipairs({ ns.LOG_DEFAULT, 50, ns.LOG_MAX }) do
		d.ask[i] = Button(d, tostring(n), 46, 84 + (i - 1) * 48, -108, function()
			local p = select(2, Players())[selected]
			ns.RequestLog(p.name, p.key, n)
			Refresh()
		end)
	end
	d.status = Text(d, "GameFontHighlightSmall", 0, -134, DETAIL_WIDTH)
	d.status:SetWordWrap(false)
	d.log = List(d, InitEntryRow, "Frame", ENTRY_HEIGHT)
	d.log:SetPoint("TOPLEFT", -4, -150)
	d.log:SetPoint("BOTTOMLEFT", -4, 8)
	d.log:SetWidth(DETAIL_WIDTH - 10)
end

tl.AddTab("Sharing", HEIGHT, Build, Refresh)

tl.Command("share", "share - who you share with and follow, and their logs, in the Sharing tab", function()
	tl.ShowTab("Sharing")
end)

tl.AddStat("Log", "Sharing", function()
	local allowed, follow = 0, 0
	for _ in pairs(ns.db.allowed) do allowed = allowed + 1 end
	for _ in pairs(ns.db.follow) do follow = follow + 1 end
	local last = ns.db.requests[#ns.db.requests]
	return ("with %d, following %d%s"):format(allowed, follow,
		last and (", last request %s ago"):format(tl.Ago(last.time)) or "")
end)
