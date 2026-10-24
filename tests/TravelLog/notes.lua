-- Notes: /tl note with and without text, the text kept as typed, the time and
-- place stamp, History's Travel filter and search, /tl log, /tl stats, the
-- Notes row, the map marker and its tooltip, and a reload.
local ns = M.Login()

local function notes()
	local list = {}
	for _, e in ipairs(TravelLogCharDB.log) do
		if e.type == "note" then list[#list + 1] = e end
	end
	return list
end

-- No text: usage, nothing logged.
M.out = {}
SlashCmdList.TRAVELLOG("note")
SlashCmdList.TRAVELLOG("note    ")
check(#notes() == 0 and ns.stats.notes == nil, "no note without text")
check(#M.out == 2 and M.out[1]:find("usage: /tl note <text>", 1, true), "usage: " .. table.concat(M.out, " | "))

-- The text as typed, case and spacing inside it kept, stamped like any entry.
M.zone, M.subzone, M.x, M.y = "Elwynn Forest", "Goldshire", 0.42, 0.65
M.out = {}
SlashCmdList.TRAVELLOG("  NOTE   Rare spawn: Mother Fang  near the 100% bridge  ")
local e = notes()[1]
check(#notes() == 1 and e.text == "Rare spawn: Mother Fang  near the 100% bridge", "text as typed: " .. tostring(e and e.text))
check(e.time == M.now and e.zone == "Elwynn Forest" and e.subzone == "Goldshire" and e.map == 1429
	and e.x == 42 and e.y == 65, "time and place")
check(M.out[1]:find("note added: Rare spawn: Mother Fang  near the 100% bridge", 1, true), "confirmed: " .. tostring(M.out[1]))
check(ns.Describe(e) == "Note: Rare spawn: Mother Fang  near the 100% bridge", "described: " .. ns.Describe(e))
check(ns.LogGroup(e) == "Travel" and ns.LogTypeLabel(e) == "Note", "a Travel entry labelled Note")
check(ns.LogMatches(e, "note", "Travel") and ns.LogMatches(e, "notes") and ns.LogMatches(e, "mother fang")
	and not ns.LogMatches(e, "", "Loot"), "searchable, under Travel only")

M.advance(60)
M.zone, M.subzone, M.x, M.y = "Westfall", "Sentinel Hill", 0.56, 0.47
M.mapID = 1436
SlashCmdList.TRAVELLOG("note Buy mageweave here")
check(#notes() == 2 and ns.stats.notes == 2, "second note counted")

-- /tl log finds them by type.
M.out = {}
SlashCmdList.TRAVELLOG("log 5 note")
check(#M.out == 3 and M.out[2]:find("Note: Rare spawn", 1, true) and M.out[3]:find("Note: Buy mageweave here", 1, true),
	"/tl log note: " .. table.concat(M.out, " | "))
M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("notes %d+") end
check(line == "notes 2", "stats line: " .. tostring(line))
M.out = {}
SlashCmdList.TRAVELLOG("help")
check(table.concat(M.out, "\n"):find("/tl note <text> - add a note to the log", 1, true), "in the help")

-- The Notes row, and History's Events view: the Travel filter and a search.
SlashCmdList.TRAVELLOG("")
local w = ns.window
local all = M.descendants(w.pages[1])
local row
for i, r in ipairs(all) do
	if r.kind == "FontString" and r:GetText() == "Notes" then row = all[i + 1]:GetText() end
end
check(row == "2", "Notes row: " .. tostring(row))
w.Tabs[3]:Click()
local log = w.pages[3].views[1]
local function LogRows()
	local out = {}
	for _, r in ipairs(M.shown(log.events.rows)) do out[#out + 1] = r.kind:GetText() .. ": " .. r.what:GetText() end
	return table.concat(out, ", ")
end
for _, r in ipairs(M.descendants(log)) do
	if r.kind == "Button" and r:GetText() == "Travel" then r:Click() end
end
check(LogRows():find("Note: Note: Buy mageweave here, Note: Note: Rare spawn", 1, true), "under Travel: " .. LogRows())
log.search:SetText("note")
check(log.found:GetText():match("^2 of %d+ entries$"), "search note: " .. log.found:GetText() .. ": " .. LogRows())

-- A hoverable marker on the map, showing the note.
M.viewMap = 1436
M.frame()
local overlay = M.mapOverlay(2010)
local colors = {}
for _, t in ipairs(M.shown(overlay.textures)) do colors[table.concat(t.color, ",")] = true end
check(colors["1,1,0.6,1"], "note marker")
local pin = M.shown(overlay.children)[1]
check(pin and pin.mouse and pin.mouseClicks == false, "note marker is hoverable and click-through")
M.script(pin, "OnEnter")
local tip = table.concat(GameTooltip.lines, "\n")
check(tip:find("^Note\n") and tip:find("Note: Buy mageweave here", 1, true), "note marker tooltip: " .. tip)
M.script(pin, "OnLeave")

ns = M.Reload()
local after = notes()
check(#after == 2 and after[1].text == "Rare spawn: Mother Fang  near the 100% bridge" and ns.stats.notes == 2,
	"kept after a reload")
