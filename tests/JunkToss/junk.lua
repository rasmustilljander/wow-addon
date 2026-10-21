-- JunkToss: picking the cheapest grey or allowlisted stack, throwing it away
-- from the minimap button, the allowlist window, commands and a reload.
M.installed = { "JunkToss" }

local function Link(id, name, color)
	return "|cff" .. (color or "9d9d9d") .. "|Hitem:" .. id .. "::::|h[" .. name .. "]|h|r"
end
local FANG, TAIL, CLAW, DIRT = Link(1001, "Broken Fang"), Link(1002, "Rat Tail"), Link(1003, "Cracked Claw"), Link(1004, "Dirt")
local LINEN, SWORD = Link(2589, "Linen Cloth", "ffffff"), Link(2000, "Shiny Sword", "1eff00")
M.items = {
	[1001] = { quality = 0, price = 7 },
	[1002] = { quality = 0, price = 2 },
	[1003] = { quality = 0, price = 150 },
	[1004] = { quality = 0, noValue = true, price = 99 },
	[2589] = { quality = 1, price = 13, icon = 132889 },
	[2000] = { quality = 2, price = 2500 },
}
M.bagSlots = { [0] = 16, [1] = 6 }
M.bags = {
	["0:1"] = FANG,                       -- 7c
	["0:2"] = { link = TAIL, count = 5 }, -- 10c for the stack
	["0:3"] = { link = LINEN, count = 3 },
	["1:2"] = CLAW,                       -- 1s 50c
	["1:4"] = SWORD,
	["2:1"] = TAIL,                       -- bag 2 has no slots
}
local ns = M.Login()

local function Names(list)
	local names = {}
	for i, item in ipairs(list) do names[i] = ns.ItemName(item.link) .. "@" .. item.bag .. ":" .. item.slot end
	return table.concat(names, " ")
end
-- Text without colors and link codes.
local function Plain(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")) end

-- Money.
check(Plain(ns.Money(0)) == "0c" and Plain(ns.Money(7)) == "7c", "copper")
check(Plain(ns.Money(10203)) == "1g 2s 3c" and Plain(ns.Money(20000)) == "2g", "gold, silver and copper: " .. Plain(ns.Money(10203)))

-- Greys only, by the value of the whole stack, cheapest first.
check(Names(ns.Candidates()) == "Broken Fang@0:1 Rat Tail@0:2 Cracked Claw@1:2", "greys: " .. Names(ns.Candidates()))
local first = ns.Candidates()[1]
check(first.value == 7 and ns.Candidates()[2].value == 10 and ns.Candidates()[2].count == 5, "stack value")
-- A grey without a sell price goes first; one whose price isn't known yet
-- is left out.
M.bags["1:5"] = DIRT
M.items[1001].uncached = true
check(Names(ns.Candidates()) == "Dirt@1:5 Rat Tail@0:2 Cracked Claw@1:2", "no value first, unknown left out: " .. Names(ns.Candidates()))
M.items[1001].uncached = nil
M.bags["1:5"] = nil
-- Equal values go in bag order.
M.bags["1:1"] = FANG
check(Names(ns.Candidates()):find("^Broken Fang@0:1 Broken Fang@1:1"), "ties in bag order")
M.bags["1:1"] = nil

-- The allowlist adds items of any quality.
M.out = {}
ns.Allow(2589, LINEN)
check(ns.IsAllowed(2589) and M.out[1]:find("Added .*Linen Cloth.* to the allowlist"), "added: " .. tostring(M.out[1]))
check(Names(ns.Candidates()) == "Broken Fang@0:1 Rat Tail@0:2 Linen Cloth@0:3 Cracked Claw@1:2", "allowlisted cloth: " .. Names(ns.Candidates()))
check(ns.Candidates()[3].allowed and not ns.Candidates()[1].allowed, "marked as allowlisted")
ns.Allow(2589, LINEN)
check(M.out[2]:find("already on the allowlist"), "added twice")

--------------------------------------------------------------------------------
-- Throwing away
--------------------------------------------------------------------------------

M.out = {}
local thrown = ns.Throw()
check(thrown and thrown.id == 1001 and M.bags["0:1"] == nil and M.cursorItem == nil, "cheapest thrown away")
check(Plain(M.out[1]) == "JunkToss Threw away [Broken Fang] (7c).", "printed: " .. Plain(M.out[1]))
thrown = ns.Throw()
check(thrown.id == 1002 and M.bags["0:2"] == nil and Plain(M.out[2]) == "JunkToss Threw away [Rat Tail]x5 (10c).", "a whole stack: " .. Plain(M.out[2]))

-- Locked items wait (on the cursor, or still being thrown away).
M.bags["0:3"].locked = true
check(ns.Candidates()[1].id == 1003, "locked cloth skipped")
M.bags["0:3"].locked = nil
-- Something on the cursor stops it.
C_Container.PickupContainerItem(1, 4)
check(ns.Throw() == nil and M.bags["0:3"] and M.cursorItem == "1:4", "not with an item on the cursor")
check(M.out[3]:find("Put down what's on your cursor"), "cursor message")
ClearCursor()
-- If the pick-up doesn't put the right item on the cursor, nothing is deleted.
local pickup = C_Container.PickupContainerItem
C_Container.PickupContainerItem = function() M.cursorItem = "1:4" end
check(ns.Throw() == nil and M.bags["1:4"] == SWORD and M.cursorItem == nil, "wrong item put back")
check(M.out[4]:find("Couldn't pick up"), "pick-up message")
C_Container.PickupContainerItem = pickup

--------------------------------------------------------------------------------
-- The minimap button: right-click throws, left-click opens the window
--------------------------------------------------------------------------------

local mb = ns.minimapButton
check(mb and mb:IsShown() and mb.parent == Minimap, "minimap button")
check(mb.clicks[1] == "LeftButtonUp" and mb.clicks[2] == "RightButtonUp", "both buttons")
check(mb.point[1] == "CENTER" and math.abs(mb.point[4] + 70.48) < 0.01 and math.abs(mb.point[5] + 25.65) < 0.01, "at 200 degrees")
M.script(mb, "OnEnter")
check(Plain(GameTooltip.lines[1]) == "JunkToss" and Plain(GameTooltip.lines[2]) == "Next: [Linen Cloth]x3 (39c)", "tooltip names the next: " .. Plain(GameTooltip.lines[2]))
check(GameTooltip.lines[3]:find("Right%-click to throw"), "tooltip help")
M.out = {}
mb:Click("RightButton")
check(M.bags["0:3"] == nil and Plain(M.out[1]) == "JunkToss Threw away [Linen Cloth]x3 (39c).", "right-click throws")
check(Plain(GameTooltip.lines[2]) == "Next: [Cracked Claw] (1s 50c)", "tooltip updated: " .. Plain(GameTooltip.lines[2]))
M.script(mb, "OnLeave")
check(not GameTooltip.shown, "tooltip hidden")
mb:Click("RightButton")
mb:Click("RightButton")
check(M.out[3]:find("Nothing to throw away") and M.bags["1:4"] == SWORD, "only the sword is left, and it's not grey")
M.script(mb, "OnEnter")
check(GameTooltip.lines[2] == "Nothing to throw away.", "empty tooltip")
M.script(mb, "OnLeave")

-- Left-click opens the window.
mb:Click("LeftButton")
local w = ns.window
check(w and w:IsShown() and UISpecialFrames[1] == "JunkTossFrame", "left-click opens the window")
check(#M.shown(w.bags.rows) == 0 and w.bagsEmpty:IsShown() and not w.throw:IsEnabled(), "nothing in the bags")
check(#M.shown(w.allow.rows) == 1 and w.allow.rows[1].name:GetText() == LINEN and not w.allowEmpty:IsShown(), "allowlist shown")
check(w.allow.rows[1].icon.texture == 132889, "allowlist icon")
mb:Click()
check(not w:IsShown(), "left-click closes it")

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

M.bags["0:1"] = { link = TAIL, count = 2 }
M.bags["0:5"] = CLAW
M.bags["0:6"] = { link = LINEN, count = 20 }
SlashCmdList.JUNKTOSS("")
check(w:IsShown(), "/junk opens it")
local rows = w.bags.rows
check(#M.shown(rows) == 3 and rows[1].item.id == 1002 and rows[2].item.id == 1003 and rows[3].item.id == 2589, "bag list in order")
check(rows[1].next:IsShown() and not rows[2].next:IsShown(), "the next one marked")
check(Plain(rows[1].name:GetText()) == "[Rat Tail] x2" and Plain(rows[1].value:GetText()) == "4c", "row: " .. Plain(rows[1].name:GetText()))
check(Plain(rows[3].name:GetText()) == "[Linen Cloth] x20 (allowlist)" and Plain(rows[3].value:GetText()) == "2s 60c", "allowlisted row: " .. Plain(rows[3].name:GetText()))
check(Plain(w.count:GetText()) == "3 stacks, 4s 14c", "count: " .. Plain(w.count:GetText()))
M.script(rows[2], "OnEnter")
check(GameTooltip.lines[1] == CLAW, "item tooltip")
M.script(rows[2], "OnLeave")

-- The window's button throws too.
w.throw:Click()
check(M.bags["0:1"] == nil and #M.shown(rows) == 2 and rows[1].item.id == 1003, "thrown from the window")
-- Bags changing redraws the list.
M.bags["0:1"] = FANG
M.fire("BAG_UPDATE_DELAYED")
check(#M.shown(rows) == 3 and rows[1].item.id == 1001, "bag update")

-- Dropping an item adds it and puts it back.
C_Container.PickupContainerItem(1, 4)
M.out = {}
M.script(w.drop, "OnReceiveDrag")
check(ns.IsAllowed(2000) and M.cursorItem == nil and M.bags["1:4"] == SWORD, "dropped sword added")
check(M.out[1]:find("Added .*Shiny Sword"), "drop printed")
check(#M.shown(w.allow.rows) == 2 and w.allow.rows[1].link == LINEN and w.allow.rows[2].link == SWORD, "allowlist by name")
check(#M.shown(rows) == 4 and rows[4].item.id == 2000, "sword now in the bag list")
-- Clicking with an item on the cursor adds it too; with nothing, nothing.
w.drop:Click()
check(#M.shown(w.allow.rows) == 2, "empty click")
C_Container.PickupContainerItem(0, 5)
w.drop:Click()
check(ns.IsAllowed(1003) and M.cursorItem == nil, "click adds")
-- The remove button.
w.allow.rows[1].remove:Click()
check(not ns.IsAllowed(1003) and w.allow.rows[1].link == LINEN, "removed: " .. w.allow.rows[1].link)
check(M.out[#M.out]:find("Removed .*Cracked Claw"), "remove printed")
w.allow.rows[2].remove:Click()
check(not ns.IsAllowed(2000) and #M.shown(rows) == 3, "sword gone from the bag list")

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

M.out = {}
SlashCmdList.JUNKTOSS("throw")
check(M.bags["0:1"] == nil and M.out[1]:find("Threw away .*Broken Fang"), "/junk throw")
SlashCmdList.JUNKTOSS("add " .. SWORD)
check(JunkTossDB.allow[2000] == SWORD, "/junk add")
SlashCmdList.JUNKTOSS("remove " .. SWORD)
check(not ns.IsAllowed(2000), "/junk remove")
SlashCmdList.JUNKTOSS("remove " .. SWORD)
check(M.out[#M.out]:find("isn't on the allowlist"), "removing again")
SlashCmdList.JUNKTOSS("add nothing")
check(M.out[#M.out]:find("/junk add <item>"), "help")
SlashCmdList.JUNKTOSS("")
check(not w:IsShown(), "/junk closes it")

-- The window's checkbox hides the minimap button; moving the window and
-- dragging the button are remembered.
SlashCmdList.JUNKTOSS("")
check(w.minimap:GetChecked(), "checkbox on")
M.script(mb, "OnDragStart")
M.cursor = { 1800, 1000 }
M.frame()
M.script(mb, "OnDragStop")
check(JunkTossDB.minimap.angle == 90 and math.abs(mb.point[5] - 75) < 0.01, "dragged to the top")
w.minimap:Click()
check(not mb:IsShown() and JunkTossDB.minimap.hide, "hidden")
M.script(w, "OnDragStart")
w:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -80)
M.script(w, "OnDragStop")

-- The allowlist and settings survive a reload.
ns = M.Reload()
check(ns.IsAllowed(2589) and not ns.IsAllowed(2000) and JunkTossDB.allow[2589] == LINEN, "allowlist kept")
check(ns.minimapButton == nil, "minimap button stays hidden")
SlashCmdList.JUNKTOSS("")
check(ns.window.point[1] == "TOPLEFT" and ns.window.point[4] == 100, "position restored")
ns.window.minimap:Click()
check(ns.minimapButton:IsShown() and math.abs(ns.minimapButton.point[5] - 75) < 0.01, "shown again where it was dragged")
check(Names(ns.Candidates()) == "Cracked Claw@0:5 Linen Cloth@0:6", "after reload: " .. Names(ns.Candidates()))
