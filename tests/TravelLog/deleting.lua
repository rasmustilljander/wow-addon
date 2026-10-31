-- Deleting entries and editing notes: /tl log's numbers, /tl delete asking
-- first and its confirm, /tl edit, the History window's right-click bar,
-- the notes count, item tooltips and Path's markers starting over, and a
-- reload.
local ns = M.Login()

local function Types()
	local list = {}
	for _, e in ipairs(TravelLogCharDB.log) do list[#list + 1] = e.type end
	return table.concat(list, ",")
end
local function Out() return table.concat(M.out, " | ") end

M.zone, M.subzone, M.x, M.y = "Westfall", "Sentinel Hill", 0.56, 0.47
M.mapID = 1436
local RING = "|cffa335ee|Hitem:2043::::|h[Ring of Forlorn Spirits]|h|r"
M.items[2043] = { quality = 4, link = RING }
local start = #TravelLogCharDB.log
SlashCmdList.TRAVELLOG("note first")
ns.Log("receive", { item = RING, count = 1, how = "quest" })
SlashCmdList.TRAVELLOG("note second")
M.x, M.y = 0.6, 0.3 -- apart, so its map marker is its own
SlashCmdList.TRAVELLOG("note third")
local n = start + 1 -- the first note's number
check(ns.stats.notes == 3, "three notes")

-- /tl log numbers each line by its place in the log.
M.out = {}
SlashCmdList.TRAVELLOG("log 2 note")
check(M.out[2]:find("#" .. (n + 2) .. "|r", 1, true) and M.out[2]:find("Note: second", 1, true)
	and M.out[3]:find("#" .. (n + 3) .. "|r", 1, true), "numbered: " .. Out())

-- The ring's tooltip is built from the log.
check(table.concat(M.hoverItem(2043), "\n"):find("First got from a quest", 1, true), "ring in the tooltip")

-- /tl delete asks first; nothing goes until the confirm.
M.out = {}
SlashCmdList.TRAVELLOG("delete " .. (n + 1))
check(#TravelLogCharDB.log == start + 4, "asking deletes nothing")
check(Out():find("delete #" .. (n + 1), 1, true) and Out():find("/tl delete " .. (n + 1) .. " confirm", 1, true),
	"asks: " .. Out())
SlashCmdList.TRAVELLOG("delete #" .. (n + 1) .. " confirm")
check(Types():sub(-14) == "note,note,note", "the ring's entry is gone: " .. Types())
check(not table.concat(M.hoverItem(2043), "\n"):find("First", 1, true), "and out of the tooltip")

-- A confirm without asking about that entry first asks instead.
M.out = {}
SlashCmdList.TRAVELLOG("delete " .. n .. " confirm")
check(#TravelLogCharDB.log == start + 3 and Out():find("Type /tl delete " .. n .. " confirm", 1, true), "confirm asks first")
-- And after asking, an entry that took the number since isn't deleted.
SlashCmdList.TRAVELLOG("delete " .. (n + 1))
table.remove(TravelLogCharDB.log, n + 1)
M.out = {}
SlashCmdList.TRAVELLOG("delete " .. (n + 1) .. " confirm")
check(#TravelLogCharDB.log == start + 2 and Out():find("Type /tl delete", 1, true), "another entry at that number asks again")
table.insert(TravelLogCharDB.log, n + 1, ns.NewEvent("note", { text = "second" }))
TravelLogCharDB.log[n + 1].x, TravelLogCharDB.log[n + 1].y = 56, 47

-- Bad numbers.
M.out = {}
SlashCmdList.TRAVELLOG("delete 99999")
check(Out():find("no entry #99999", 1, true), "no such entry: " .. Out())
M.out = {}
SlashCmdList.TRAVELLOG("delete")
check(Out():find("/tl delete <#>", 1, true), "usage in the help: " .. Out())

-- Deleting the first note counts it out.
SlashCmdList.TRAVELLOG("delete " .. n)
SlashCmdList.TRAVELLOG("delete " .. n .. " confirm")
check(ns.stats.notes == 2 and TravelLogCharDB.log[n].text == "second", "note deleted, count down: " .. tostring(ns.stats.notes))

-- /tl edit changes a note's text, as typed; other entries can't be edited.
M.out = {}
SlashCmdList.TRAVELLOG("edit " .. n .. "   Buy Mageweave here ")
check(TravelLogCharDB.log[n].text == "Buy Mageweave here" and Out():find("note changed: Buy Mageweave here", 1, true),
	"edited: " .. tostring(TravelLogCharDB.log[n].text))
ns.Log("rest")
M.out = {}
SlashCmdList.TRAVELLOG("edit " .. #TravelLogCharDB.log .. " hi")
check(Out():find("isn't a note", 1, true) and TravelLogCharDB.log[#TravelLogCharDB.log].text == nil, "only notes: " .. Out())

-- The window: right-click a row for the bar.
SlashCmdList.TRAVELLOG("")
local w = ns.window
w.Tabs[3]:Click()
local log = w.pages[3].views[1]
local function Row(text)
	for _, r in ipairs(M.shown(log.events.rows)) do
		if r.what:GetText() == text then return r end
	end
end
local function Rows()
	local out = {}
	for _, r in ipairs(M.shown(log.events.rows)) do out[#out + 1] = r.what:GetText() end
	return table.concat(out, ", ")
end
check(not log.edit:IsShown(), "no bar before a click")
M.script(Row("Started resting in Sentinel Hill"), "OnMouseUp", "LeftButton")
check(not log.edit:IsShown(), "a left click doesn't open it")

-- A non-note: a delete prompt, the row marked.
M.script(Row("Started resting in Sentinel Hill"), "OnMouseUp", "RightButton")
check(log.edit:IsShown() and log.edit.label:IsShown() and not log.edit.text:IsShown() and not log.edit.save:IsShown(),
	"delete bar for a non-note")
check(log.edit.label:GetText() == 'Delete "Started resting in Sentinel Hill"?', "label: " .. log.edit.label:GetText())
check(Row("Started resting in Sentinel Hill").mark:IsShown() and not Row("Note: third").mark:IsShown(), "the row is marked")
log.edit.cancel:Click()
check(not log.edit:IsShown() and not Row("Started resting in Sentinel Hill").mark:IsShown() and #TravelLogCharDB.log == start + 3, "cancel keeps it")
M.script(Row("Started resting in Sentinel Hill"), "OnMouseUp", "RightButton")
log.edit.delete:Click()
check(not log.edit:IsShown() and not Row("Started resting in Sentinel Hill") and TravelLogCharDB.log[#TravelLogCharDB.log].type == "note",
	"deleted from the window: " .. Rows())

-- A note: its text to edit, saved with Save or Enter, Escape cancels.
M.script(Row("Note: third"), "OnMouseUp", "RightButton")
check(log.edit.text:IsShown() and log.edit.save:IsShown() and not log.edit.label:IsShown()
	and log.edit.text:GetText() == "third" and log.edit.text:HasFocus(), "note bar")
log.edit.text:SetText("  Third, edited ")
log.edit.save:Click()
check(TravelLogCharDB.log[#TravelLogCharDB.log].text == "Third, edited" and Row("Note: Third, edited"), "saved: " .. Rows())
M.script(Row("Note: Third, edited"), "OnMouseUp", "RightButton")
log.edit.text:SetText("")
M.script(log.edit.text, "OnEnterPressed")
check(TravelLogCharDB.log[#TravelLogCharDB.log].text == "Third, edited", "an empty text keeps the note")
M.script(Row("Note: Third, edited"), "OnMouseUp", "RightButton")
log.edit.text:SetText("nope")
M.script(log.edit.text, "OnEscapePressed")
check(not log.edit:IsShown() and Row("Note: Third, edited"), "escape cancels")

-- Path's note markers: a deleted note's goes.
M.viewMap = 1436
M.frame()
local function Markers()
	local count = 0
	for _, t in ipairs(M.shown(M.mapOverlay(2010).textures)) do
		if table.concat(t.color, ",") == "1,1,0.6,1" then count = count + 1 end
	end
	return count
end
local before = Markers()
check(before > 0, "note markers drawn")
M.script(Row("Note: Third, edited"), "OnMouseUp", "RightButton")
log.edit.delete:Click()
M.frame()
check(Markers() == before - 1 and ns.stats.notes == 1, "marker gone: " .. Markers() .. " of " .. before)

ns = M.Reload()
check(Types():find(",note,") and not Types():find("note,note") and TravelLogCharDB.log[n].text == "Buy Mageweave here"
	and ns.stats.notes == 1,
	"kept after a reload: " .. Types())
