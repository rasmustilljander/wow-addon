-- JunkToss: finds the least valuable grey (or allowlisted item) in the bags
-- and throws it away. The window is in UI.lua, the minimap button in
-- Minimap.lua.
local _, ns = ...

function ns.Print(text, ...)
	if select("#", ...) > 0 then
		text = text:format(...)
	end
	print("|cffffd200JunkToss|r " .. text)
end

-- Copper as "1g 2s 3c".
function ns.Money(copper)
	local parts = {}
	local gold, silver = math.floor(copper / 10000), math.floor(copper / 100) % 100
	if gold > 0 then
		parts[#parts + 1] = gold .. "|cffffd700g|r"
	end
	if silver > 0 then
		parts[#parts + 1] = silver .. "|cffc7c7cfs|r"
	end
	if copper % 100 > 0 or #parts == 0 then
		parts[#parts + 1] = copper % 100 .. "|cffeda55fc|r"
	end
	return table.concat(parts, " ")
end

function ns.ItemName(link)
	return link:match("|h%[(.-)%]|h") or link
end

--------------------------------------------------------------------------------
-- The allowlist
--------------------------------------------------------------------------------

-- JunkTossDB.allow maps item IDs to item links.
function ns.IsAllowed(id)
	return JunkTossDB.allow[id] ~= nil
end

function ns.Allow(id, link)
	if ns.IsAllowed(id) then
		ns.Print("%s is already on the allowlist.", link)
		return
	end
	JunkTossDB.allow[id] = link
	ns.Print("Added %s to the allowlist.", link)
	ns.Update()
end

function ns.Disallow(id)
	local link = JunkTossDB.allow[id]
	if not link then
		return
	end
	JunkTossDB.allow[id] = nil
	ns.Print("Removed %s from the allowlist.", link)
	ns.Update()
end

-- The allowlist sorted by name: { id, link }.
function ns.Allowlist()
	local list = {}
	for id, link in pairs(JunkTossDB.allow) do
		list[#list + 1] = { id = id, link = link }
	end
	table.sort(list, function(a, b)
		return ns.ItemName(a.link):lower() < ns.ItemName(b.link):lower()
	end)
	return list
end

--------------------------------------------------------------------------------
-- The bags
--------------------------------------------------------------------------------

-- Every grey and allowlisted stack in the bags, cheapest stack first (ties in
-- bag order): { bag, slot, id, link, icon, count, value, allowed }. Leaves out
-- locked items (on the cursor, or just thrown away) and items whose sell
-- price the client doesn't know yet.
function ns.Candidates()
	local list = {}
	for bag = Enum.BagIndex.Backpack, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local allowed = info and ns.IsAllowed(info.itemID)
			if info and not info.isLocked and (allowed or info.quality == Enum.ItemQuality.Poor) then
				local price = info.hasNoValue and 0 or select(11, C_Item.GetItemInfo(info.itemID))
				if price then
					list[#list + 1] = {
						bag = bag,
						slot = slot,
						id = info.itemID,
						link = info.hyperlink,
						icon = info.iconFileID,
						count = info.stackCount,
						value = price * info.stackCount,
						allowed = allowed,
					}
				end
			end
		end
	end
	table.sort(list, function(a, b)
		if a.value ~= b.value then
			return a.value < b.value
		elseif a.bag ~= b.bag then
			return a.bag < b.bag
		end
		return a.slot < b.slot
	end)
	return list
end

function ns.Describe(item)
	return item.link .. (item.count > 1 and "x" .. item.count or "") .. " (" .. ns.Money(item.value) .. ")"
end

local deleting

-- Blizzard calls DeleteCursorItem again after the player accepts its dialog
-- for a protected item. Report success only after that call clears the cursor.
hooksecurefunc("DeleteCursorItem", function()
	if deleting and not GetCursorInfo() then
		local item = deleting
		deleting = nil
		ns.Print("Threw away %s.", ns.Describe(item))
		ns.Update()
	end
end)
hooksecurefunc("ClearCursor", function()
	deleting = nil
end)

-- Throws away the cheapest stack and returns it, or nil if nothing was thrown.
function ns.Throw()
	if GetCursorInfo() then
		ns.Print("Put down what's on your cursor first.")
		return nil
	end
	local item = ns.Candidates()[1]
	if not item then
		ns.Print("Nothing to throw away.")
		return nil
	end
	C_Container.PickupContainerItem(item.bag, item.slot)
	local kind, id = GetCursorInfo()
	if kind ~= "item" or id ~= item.id then
		ClearCursor()
		ns.Print("Couldn't pick up %s.", item.link)
		return nil
	end
	deleting = item
	DeleteCursorItem()
	return not GetCursorInfo() and item or nil
end

--------------------------------------------------------------------------------
-- Events and commands
--------------------------------------------------------------------------------

-- Redraws the window and the minimap button's tooltip.
function ns.Update()
	if ns.Refresh then
		ns.Refresh()
	end
	if ns.UpdateTooltip then
		ns.UpdateTooltip()
	end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" and arg == "JunkToss" then
		JunkTossDB = JunkTossDB or {}
		JunkTossDB.allow = JunkTossDB.allow or {}
		JunkTossDB.minimap = JunkTossDB.minimap or { angle = 200 }
		ns.ShowMinimapButton(not JunkTossDB.minimap.hide)
	elseif event == "BAG_UPDATE_DELAYED" then
		ns.Update()
	end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")

SLASH_JUNKTOSS1 = "/junktoss"
SLASH_JUNKTOSS2 = "/junk"
SlashCmdList.JUNKTOSS = function(msg)
	local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	local id = tonumber(rest:match("item:(%d+)"))
	if cmd == "" then
		ns.Toggle()
	elseif cmd == "throw" then
		ns.Throw()
	elseif cmd == "add" and id then
		ns.Allow(id, rest:match("|c.-|Hitem:.-|h|r") or rest)
	elseif cmd == "remove" and id then
		if not ns.IsAllowed(id) then
			ns.Print("That item isn't on the allowlist.")
		end
		ns.Disallow(id)
	else
		ns.Print("/junk opens the window, /junk throw throws away the cheapest item, /junk add <item> and /junk remove <item> (shift-click an item) change the allowlist.")
	end
end
