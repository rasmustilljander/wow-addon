-- Map replay: plays your trail back on the world map. A time slider with
-- play, pause, step and speed ends the trail and markers at a moment of the
-- range your trail shows (Map.lua draws up to ns.replayAt), and shows your
-- level and gear then. The controls are a frame of their own, not part of
-- the world map, so the map stays click-through and untainted.
local _, ns = ...
local tl = TravelLog

local SPEEDS = { 60, 300, 1200, 3600 } -- played seconds per second
local REFRESH = 0.1   -- seconds between moves while playing
local MAX_FRAME = 1   -- seconds of a slow frame counted while playing
local WIDTH = 380

local frame
-- While open: { pos, playing, tickedAt, range }, pos in played seconds into
-- the range.
local replay
local updating -- the slider is being set, not dragged

-- The range your trail shows as the stretches of it you were logged in,
-- each { from, to } (epoch), oldest first, and their total length.
local function Timeline()
	local now = time()
	local list, total = {}, 0
	local since, before = ns.TrailSpan(tl.settings.trail, ns.db.sessions)
	if not since then
		return list, total
	end
	local stop = math.min(before or now, now)
	for _, s in ipairs(ns.db.sessions) do
		local from, to = math.max(s.start, since), math.min(ns.SessionEnd(s, now), stop)
		if to > from then
			list[#list + 1] = { from = from, to = to }
			total = total + to - from
		end
	end
	return list, total
end

-- The time pos played seconds into the timeline.
local function Moment(list, pos)
	for _, part in ipairs(list) do
		local length = part.to - part.from
		if pos <= length then
			return part.from + pos
		end
		pos = pos - length
	end
	local last = list[#list]
	return last and last.to
end

-- Your level and gear before a time, from TravelLog's log: the last
-- level-up by then (or one below the first after it), and the last item
-- logged in each slot. Items are logged only the first time they're worn.
local function Then(at)
	local level, gear = nil, {}
	for _, e in ipairs(tl.char.log) do
		if e.time >= at then
			if level then
				break
			elseif e.type == "level" and e.level then
				level = e.level - 1
				break
			end
		elseif e.type == "level" then
			level = e.level
		elseif e.type == "equip" and e.slot then
			gear[e.slot] = e
		end
	end
	return level or tl.profile.level, gear
end

local function SpeedLabel(speed)
	return speed >= 3600 and ("%d h/s"):format(speed / 3600) or ("%d min/s"):format(speed / 60)
end

-- Applies replay.pos: the map's end, the slider and the texts.
local function Update()
	replay.range = tl.settings.trail
	local list, total = Timeline()
	replay.pos = math.max(0, math.min(replay.pos, total))
	if replay.pos >= total then
		replay.playing = false
	end
	local moment = Moment(list, replay.pos)
	-- Records are in whole seconds; those at the moment are shown.
	ns.replayAt = moment and math.floor(moment) + 1 or 0

	updating = true
	frame.slider:SetMinMaxValues(0, math.max(total, 1))
	frame.slider:SetValue(replay.pos)
	updating = false
	frame.play:SetText(replay.playing and "Pause" or "Play")
	frame.speed:SetText(SpeedLabel(tl.settings.replaySpeed))

	if not moment then
		frame.when:SetText("No path in your trail's range: " .. ns.DescribeTrail(tl.settings.trail))
		frame.now:SetText("")
		frame.gear = {}
		return
	end
	frame.when:SetText(("%s, %s of %s played"):format(date("%a %d %b %H:%M", moment), tl.Duration(replay.pos),
		tl.Duration(total)))
	local level, gear = Then(ns.replayAt)
	local sum, count = 0, 0
	for _, e in pairs(gear) do
		if e.ilvl then
			sum, count = sum + e.ilvl, count + 1
		end
	end
	frame.now:SetText(("Level %s%s"):format(level or "?",
		count > 0 and (", item level %d"):format(math.floor(sum / count + 0.5)) or ""))
	frame.gear = gear
end

local function Step(direction)
	replay.playing = false
	replay.pos = replay.pos + direction * tl.settings.replaySpeed
	Update()
end

local function TogglePlay()
	-- At the end, which moves on while you play, it starts over.
	local _, total = Timeline()
	if not replay.playing and replay.pos >= total - 1 then
		replay.pos = 0
	end
	replay.playing = not replay.playing
	replay.tickedAt = GetTime()
	Update()
end

local function NextSpeed()
	local speed = SPEEDS[1]
	for i, s in ipairs(SPEEDS) do
		if s == tl.settings.replaySpeed then
			speed = SPEEDS[i % #SPEEDS + 1]
		end
	end
	tl.settings.replaySpeed = speed
	Update()
end

local function OnUpdate()
	-- A new range, from /tl trail or the TravelLog window, starts over.
	if tl.settings.trail ~= replay.range then
		replay.pos = 0
		Update()
	end
	if not replay.playing then
		return
	end
	local now = GetTime()
	local elapsed = now - replay.tickedAt
	if elapsed >= REFRESH then
		replay.tickedAt = now
		replay.pos = replay.pos + math.min(elapsed, MAX_FRAME) * tl.settings.replaySpeed
		Update()
	end
end

local function GearTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine("Gear then")
	local any = false
	for slot = INVSLOT_FIRST_EQUIPPED or 1, INVSLOT_LAST_EQUIPPED or 19 do
		local e = frame.gear[slot]
		if e then
			GameTooltip:AddLine(("%s: %s"):format(tl.SLOT_NAMES[slot] or slot, e.item or "?"), 1, 1, 1)
			any = true
		end
	end
	if not any then
		GameTooltip:AddLine("none logged", 1, 1, 1)
	end
	GameTooltip:Show()
end

local function Button(text, width, x, onClick)
	local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetPoint("TOPLEFT", x, -82)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

local function Create()
	frame = CreateFrame("Frame", "TravelLogReplayFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(WIDTH, 140)
	-- Above the world map.
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetPoint("BOTTOM", 0, 120)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetUserPlaced(false) -- it opens in its default place
	end)
	frame.TitleText:SetText("TravelLog replay")
	table.insert(UISpecialFrames, frame:GetName())

	frame.when = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.when:SetPoint("TOPLEFT", 14, -32)

	frame.slider = CreateFrame("Slider", nil, frame, "UISliderTemplate")
	frame.slider:SetSize(WIDTH - 32, 16)
	frame.slider:SetPoint("TOPLEFT", 16, -56)
	frame.slider:SetValueStep(1)
	frame.slider:SetScript("OnValueChanged", function(_, value)
		if not updating then
			replay.playing = false
			replay.pos = value
			Update()
		end
	end)

	frame.back = Button("<", 32, 14, function() Step(-1) end)
	frame.play = Button("Play", 64, 50, TogglePlay)
	frame.forward = Button(">", 32, 118, function() Step(1) end)
	frame.speed = Button("", 80, 154, NextSpeed)

	frame.now = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.now:SetPoint("TOPLEFT", 14, -114)
	frame.hover = CreateFrame("Frame", nil, frame)
	frame.hover:SetAllPoints(frame.now)
	frame.hover:EnableMouse(true)
	frame.hover:SetScript("OnEnter", GearTooltip)
	frame.hover:SetScript("OnLeave", function() GameTooltip:Hide() end)

	frame:SetScript("OnUpdate", OnUpdate)
	-- Closing it ends the replay; the map shows the whole trail again.
	frame:SetScript("OnHide", function()
		replay, ns.replayAt = nil, nil
	end)
	frame:Hide()
end

-- Opens the controls at the start of your trail's range, or closes them.
function ns.ToggleReplay()
	if not frame then
		Create()
	end
	if frame:IsShown() then
		frame:Hide()
		return
	end
	replay = { pos = 0, playing = false, tickedAt = GetTime() }
	frame:Show()
	Update()
end

tl.Command("replay", "replay [<range>] - play your map trail back, over that range if given (see /tl trail)",
	function(arg)
		if arg ~= "" then
			local range = ns.ParseTrail(arg)
			if not range then
				return false
			end
			tl.settings.trail = range
			ns.RefreshTrail()
			if frame and frame:IsShown() then
				return
			end
		end
		ns.ToggleReplay()
		if frame:IsShown() then
			tl.Print("replaying %s; open the world map to watch", ns.DescribeTrail(tl.settings.trail))
		end
	end)
