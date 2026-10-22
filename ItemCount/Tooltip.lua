-- ItemCount tooltip lines: how many of the item you have in all, each
-- character's count by place, and your guild's bank (not in the total).
local _, ns = ...

local LABELS = { bags = "bags", bank = "bank", mail = "mail", auctions = "AH", equipped = "equipped" }
local WHITE, GRAY = "|cffffffff", "|cff9d9d9d"

-- "Name" for characters on this realm, "Name-Realm" for the others.
local function Name(key)
	local name, realm = strsplit("-", key, 2)
	return realm == ns.realm and name or key
end

-- "60 (bags 20, bank 40)"
local function Places(holder)
	local parts = {}
	for i, p in ipairs(holder.places) do
		parts[i] = LABELS[p.place] .. " " .. p.n
	end
	return WHITE .. holder.total .. "|r " .. GRAY .. "(" .. table.concat(parts, ", ") .. ")|r"
end

local function AddLines(tooltip, data)
	if not ns.db or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) then
		return
	end
	local id = ns.Clean(data and data.id)
	if not id then
		return
	end
	local holders, account, total = ns.Holders(id)
	local guild = ns.GuildBankCount(id)
	if total == 0 and guild == 0 then
		return
	end
	if #holders + (account > 0 and 1 or 0) > 1 then
		tooltip:AddDoubleLine("Total", WHITE .. total .. "|r", 1, 0.82, 0)
	end
	for _, holder in ipairs(holders) do
		local r, g, b = GetClassColor(holder.class)
		tooltip:AddDoubleLine(Name(holder.key), Places(holder), r, g, b)
	end
	if account > 0 then
		tooltip:AddDoubleLine("Account bank", WHITE .. account .. "|r", 1, 0.82, 0)
	end
	if guild > 0 then
		tooltip:AddDoubleLine("Guild bank", WHITE .. guild .. "|r", 1, 0.82, 0)
	end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
	-- A broken tooltip line must not break the tooltip.
	local ok, err = pcall(AddLines, tooltip, data)
	if not ok then
		geterrorhandler()(err)
	end
end)
