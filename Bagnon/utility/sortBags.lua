--[[
	sortBags.lua
		Port of shirsig's SortBags (1.12) for 3.3.5 / Lua 5.1.
		Exposes Bagnon.SortBags.SortInventory() / SortBank().
--]]

local Bagnon = LibStub('AceAddon-3.0'):GetAddon('Bagnon')

local SB = {}
Bagnon.SortBags = SB

local tinsert, sort = table.insert, table.sort
local strfind, gsub, format = string.find, string.gsub, string.format
local min, abs, ceil = math.min, math.abs, math.ceil
local mod = math.fmod or math.mod
local tonumber = tonumber

local sortTooltip = CreateFrame('GameTooltip', 'BagnonSortBagsTooltip', nil, 'GameTooltipTemplate')

local function set(...)
	local t = {}
	for i = 1, select('#', ...) do
		t[select(i, ...)] = true
	end
	return t
end

local function union(...)
	local t = {}
	for i = 1, select('#', ...) do
		for k in pairs((select(i, ...))) do
			t[k] = true
		end
	end
	return t
end

local ITEM_TYPES = {GetAuctionItemClasses()}


local MOUNTS = set(
	5864, 5872, 5873, 18785, 18786, 18787, 18244, 19030, 13328, 13329,
	2411, 2414, 5655, 5656, 18778, 18776, 18777, 18241, 12353, 12354,
	8629, 8631, 8632, 18766, 18767, 18902, 18242, 13086, 19902, 12302, 12303, 8628, 12326,
	8563, 8595, 13321, 13322, 18772, 18773, 18774, 18243, 13326, 13327,
	15277, 15290, 18793, 18794, 18795, 18247, 15292, 15293,
	1132, 5665, 5668, 18796, 18797, 18798, 18245, 12330, 12351,
	8588, 8591, 8592, 18788, 18789, 18790, 18246, 19872, 8586, 13317,
	13331, 13332, 13333, 13334, 18791, 18248, 13335,
	21218, 21321, 21323, 21324, 21176
)

local SPECIAL = set(5462, 17696, 17117, 13347, 13289, 11511)
local KEYS = set(9240, 17191, 13544, 12324, 16309, 12384, 20402)
local TOOLS = set(7005, 12709, 19727, 5956, 2901, 6219, 10498, 6218, 6339, 11130, 11145, 16207, 9149, 15846, 6256, 6365, 6367)

local ENCHANTING_MATERIALS = set(
	10940, 11083, 11137, 11176, 16204,
	10938, 10939, 10998, 11082, 11134, 11135, 11174, 11175, 16202, 16203,
	10978, 11084, 11138, 11139, 11177, 11178, 14343, 14344,
	20725,
	-- WotLK additions
	34054, 34055, 34056, 34057, 22445, 22446, 22447, 22448, 22449, 22450,
	34052, 34053
)

local HERBS = set(
	765, 785, 2447, 2449, 2450, 2452, 2453, 3355, 3356, 3357, 3358, 3369,
	3818, 3819, 3820, 3821, 4625, 8153, 8831, 8836, 8838, 8839, 8845, 8846,
	13463, 13464, 13465, 13466, 13467, 13468,
	-- TBC/WotLK herbs
	22785, 22786, 22787, 22789, 22790, 22791, 22792, 22793, 22794, 22797,
	36901, 36903, 36904, 36905, 36906, 36907, 37921, 39969, 39970, 36908
)

local SEEDS = set(17034, 17035, 17036, 17037, 17038)

local CLASSES = {
	-- arrow
	{
		containers = {2101, 5439, 7278, 11362, 3573, 3605, 7371, 8217, 2662, 19319, 18714},
		items = set(2512, 2515, 3030, 3464, 9399, 11285, 12654, 18042, 19316, 28053, 28056, 31737, 31949, 34581, 41164, 41165),
	},
	-- bullet
	{
		containers = {2102, 5441, 7279, 11363, 3574, 3604, 7372, 8218, 2663, 19320},
		items = set(2516, 2519, 3033, 3465, 4960, 5568, 8067, 8068, 8069, 10512, 10513, 11284, 11630, 13377, 15997, 19317, 28060, 28061, 31735, 32760, 34582, 41584),
	},
	-- soul
	{
		containers = {22243, 22244, 21340, 21341, 21342},
		items = set(6265),
	},
	-- ench
	{
		containers = {22246, 22248, 22249, 38082},
		items = union(
			ENCHANTING_MATERIALS,
			set(6218, 6339, 11130, 11145, 16207, 22461, 41745)
		),
	},
	-- herb
	{
		containers = {22250, 22251, 22252},
		items = union(HERBS, SEEDS),
	},
	-- mining
	{
		containers = {30746, 40327},
		items = set(),
	},
}

local model, itemStacks, itemClasses, itemSortKeys
local CONTAINERS

local function GetExpectedInventoryState()
	local state = {}
	for _, slot in ipairs(model) do
		local key = slot.container .. ':' .. slot.position
		state[key] = { item = slot.link, count = slot.count or 0 }
	end
	return state
end

local function GetActualInventoryState()
	local state = {}
	for _, slot in ipairs(model) do
		local key = slot.container .. ':' .. slot.position
		local link = GetContainerItemLink(slot.container, slot.position)
		local count = 0
		if link then
			local _, c = GetContainerItemInfo(slot.container, slot.position)
			count = c or 0
		end
		state[key] = { item = link, count = count }
	end
	return state
end

local function StateMatches(expected, actual)
	for key, e in pairs(expected) do
		local a = actual[key]
		if not a or e.item ~= a.item or e.count ~= a.count then
			return false
		end
	end
	return true
end

local function findKey(t, value)
	for k, v in pairs(t) do
		if v == value then return k end
	end
end

local function ItemTypeKey(itemClass)
	return findKey(ITEM_TYPES, itemClass) or 0
end

local function ItemSubTypeKey(itemClass, itemSubClass)
	return findKey({GetAuctionItemSubClasses(ItemTypeKey(itemClass))}, itemSubClass) or 0
end

local function ItemInvTypeKey(itemClass, itemSubClass, itemSlot)
	if not GetAuctionInvTypes then return 0 end
	local invTypes = {GetAuctionInvTypes(ItemTypeKey(itemClass), ItemSubTypeKey(itemClass, itemSubClass))}
	return findKey(invTypes, itemSlot) or 0
end

local function LT(a, b)
	local i = 1
	while true do
		if a[i] and b[i] and a[i] ~= b[i] then
			return a[i] < b[i]
		elseif not a[i] and b[i] then
			return true
		elseif not b[i] then
			return false
		end
		i = i + 1
	end
end

local function Move(src, dst)
	local texture, _, srcLocked = GetContainerItemInfo(src.container, src.position)
	local _, _, dstLocked = GetContainerItemInfo(dst.container, dst.position)
	if texture and not srcLocked and not dstLocked then
		ClearCursor()
		PickupContainerItem(src.container, src.position)
		PickupContainerItem(dst.container, dst.position)
		if src.item == dst.item then
			local count = min(src.count, itemStacks[dst.item] - dst.count)
			src.count = src.count - count
			dst.count = dst.count + count
			if src.count == 0 then
				src.item = nil
				src.link = nil
			end
		else
			src.item, dst.item = dst.item, src.item
			src.link, dst.link = dst.link, src.link
			src.count, dst.count = dst.count, src.count
		end
		return true
	end
end

local chargesPattern
local function GetChargesPattern()
	if not chargesPattern then
		chargesPattern = '^' .. gsub(gsub(ITEM_SPELL_CHARGES_P1 or ITEM_SPELL_CHARGES or '%d Charges', '%%d', '(%%d+)'), '%%%d+%$d', '(%%d+)') .. '$'
	end
	return chargesPattern
end

local function TooltipInfo(container, position)
	local pattern = GetChargesPattern()
	sortTooltip:SetOwner(UIParent, 'ANCHOR_NONE')
	sortTooltip:ClearLines()
	if container == BANK_CONTAINER then
		sortTooltip:SetInventoryItem('player', BankButtonIDToInvSlotID(position))
	else
		sortTooltip:SetBagItem(container, position)
	end

	local charges, usable, soulbound, quest, conjured
	for i = 1, sortTooltip:NumLines() do
		local text = _G['BagnonSortBagsTooltipTextLeft' .. i]:GetText()
		if text then
			local _, _, chargeString = strfind(text, pattern)
			if chargeString then
				charges = tonumber(chargeString)
			elseif strfind(text, '^' .. (ITEM_SPELL_TRIGGER_ONUSE or 'Use:')) then
				usable = true
			elseif text == ITEM_SOULBOUND then
				soulbound = true
			elseif text == ITEM_BIND_QUEST then
				quest = true
			elseif text == ITEM_CONJURED then
				conjured = true
			end
		end
	end
	return charges or 1, usable, soulbound, quest, conjured
end

local function ContainerClass(container)
	if container ~= 0 and container ~= BANK_CONTAINER then
		local name = GetBagName(container)
		if name then
			for class, info in ipairs(CLASSES) do
				for _, itemID in ipairs(info.containers) do
					if name == GetItemInfo(itemID) then
						return class
					end
				end
			end
		end
	end
end

local function Item(container, position)
	local link = GetContainerItemLink(container, position)
	if link then
		local _, _, itemID, enchantID, suffixID, uniqueID = strfind(link, 'item:(%d+):(%d*):(%d*):(%d*)')
		itemID = tonumber(itemID)
		if not itemID then return end
		local _, _, quality, _, _, itype, subType, stack, invType = GetItemInfo(itemID)
		if not itype then return end
		local charges, usable, soulbound, quest, conjured = TooltipInfo(container, position)

		local sortKey = {}
		if itemID == 6948 then
			tinsert(sortKey, 1)
		elseif subType == 'Devices' then
			tinsert(sortKey, 2)
		elseif MOUNTS[itemID] then
			tinsert(sortKey, 3)
		elseif SPECIAL[itemID] then
			tinsert(sortKey, 4)
		elseif KEYS[itemID] then
			tinsert(sortKey, 5)
		elseif TOOLS[itemID] then
			tinsert(sortKey, 6)
		elseif quality == 7 then
			tinsert(sortKey, 7)
		elseif itemID == 6265 then
			tinsert(sortKey, 17)
		elseif conjured then
			tinsert(sortKey, 19)
		elseif soulbound then
			tinsert(sortKey, 8)
		elseif itype == ITEM_TYPES[9] then
			tinsert(sortKey, 9)
		elseif quest then
			tinsert(sortKey, 10)
		elseif subType == 'Food & Drink' then
			tinsert(sortKey, 18)
		elseif itype == ITEM_TYPES[4] then
			tinsert(sortKey, 16)
		elseif usable and itype ~= ITEM_TYPES[1] and itype ~= ITEM_TYPES[2] and itype ~= ITEM_TYPES[8] then
			tinsert(sortKey, 15)
		elseif ENCHANTING_MATERIALS[itemID] then
			tinsert(sortKey, 11)
		elseif HERBS[itemID] then
			tinsert(sortKey, 12)
		elseif quality and quality > 1 then
			tinsert(sortKey, 13)
		elseif quality == 1 then
			tinsert(sortKey, 14)
		elseif quality == 0 then
			tinsert(sortKey, 17)
		end

		tinsert(sortKey, ItemTypeKey(itype))
		tinsert(sortKey, ItemInvTypeKey(itype, subType, invType))
		tinsert(sortKey, ItemSubTypeKey(itype, subType))
		tinsert(sortKey, -(quality or 0))
		tinsert(sortKey, itemID)
		tinsert(sortKey, (SortBagsRightToLeft and 1 or -1) * charges)
		tinsert(sortKey, suffixID)
		tinsert(sortKey, enchantID)
		tinsert(sortKey, uniqueID)

		local key = format('%s:%s:%s:%s:%s:%s', itemID, enchantID or '', suffixID or '', uniqueID or '', charges, (soulbound and 1 or 0))

		itemStacks[key] = stack
		itemSortKeys[key] = sortKey

		for class, info in ipairs(CLASSES) do
			if info.items[itemID] then
				itemClasses[key] = class
				break
			end
		end

		return key
	end
end

local function insert(t, v)
	if SortBagsRightToLeft then
		tinsert(t, v)
	else
		tinsert(t, 1, v)
	end
end

local counts
local function assign(slot, item)
	if counts[item] > 0 then
		local count
		if SortBagsRightToLeft and mod(counts[item], itemStacks[item]) ~= 0 then
			count = mod(counts[item], itemStacks[item])
		else
			count = min(counts[item], itemStacks[item])
		end
		slot.targetItem = item
		slot.targetCount = count
		counts[item] = counts[item] - count
		return true
	end
end

local function Initialize()
	model, counts, itemStacks, itemClasses, itemSortKeys = {}, {}, {}, {}, {}

	for _, container in ipairs(CONTAINERS) do
		local class = ContainerClass(container)
		for position = 1, GetContainerNumSlots(container) do
			local slot = { container = container, position = position, class = class }
			local link = GetContainerItemLink(container, position)
			local item = Item(container, position)
			if item then
				local _, count = GetContainerItemInfo(container, position)
				slot.item = item
				slot.link = link
				slot.count = count
				counts[item] = (counts[item] or 0) + count
			end
			insert(model, slot)
		end
	end

	local free = {}
	for item, count in pairs(counts) do
		local stacks = ceil(count / itemStacks[item])
		free[item] = stacks
		if itemClasses[item] then
			free[itemClasses[item]] = (free[itemClasses[item]] or 0) + stacks
		end
	end
	for _, slot in ipairs(model) do
		if slot.class and free[slot.class] then
			free[slot.class] = free[slot.class] - 1
		end
	end

	local items = {}
	for item in pairs(counts) do
		tinsert(items, item)
	end
	sort(items, function(a, b) return LT(itemSortKeys[a], itemSortKeys[b]) end)

	for _, slot in ipairs(model) do
		if slot.class then
			for _, item in ipairs(items) do
				if itemClasses[item] == slot.class and assign(slot, item) then
					break
				end
			end
		else
			for _, item in ipairs(items) do
				if (not itemClasses[item] or free[itemClasses[item]] > 0) and assign(slot, item) then
					if itemClasses[item] then
						free[itemClasses[item]] = free[itemClasses[item]] - 1
					end
					break
				end
			end
		end
	end
end

local function Sort()
	local complete = true
	for _, dst in ipairs(model) do
		if dst.targetItem and (dst.item ~= dst.targetItem or dst.count < dst.targetCount) then
			complete = false
			local sources, rank = {}, {}
			for _, src in ipairs(model) do
				if src.item == dst.targetItem
					and src ~= dst
					and not (dst.item and src.class and src.class ~= itemClasses[dst.item])
					and not (src.targetItem and src.item == src.targetItem and src.count <= src.targetCount)
				then
					rank[src] = abs(src.count - dst.targetCount + (dst.item == dst.targetItem and dst.count or 0))
					tinsert(sources, src)
				end
			end
			sort(sources, function(a, b) return rank[a] < rank[b] end)
			for _, src in ipairs(sources) do
				if Move(src, dst) then break end
			end
		end
	end
	return complete
end

local function Stack()
	for _, src in ipairs(model) do
		if src.item and src.count < itemStacks[src.item] and src.item ~= src.targetItem then
			for _, dst in ipairs(model) do
				if dst ~= src and dst.item and dst.item == src.item and dst.count < itemStacks[dst.item] and dst.item ~= dst.targetItem then
					Move(src, dst)
				end
			end
		end
	end
end

local driver = CreateFrame('Frame')
driver:Hide()

local timeout, operationTimeout, expectedState, waitingForState

local function Start()
	if driver:IsShown() then return end
	Initialize()
	timeout = GetTime() + 7
	waitingForState = false
	driver:Show()
end

driver:SetScript('OnUpdate', function()
	if waitingForState then
		local actual = GetActualInventoryState()
		if not StateMatches(expectedState, actual) then
			if GetTime() > operationTimeout then
				ClearCursor()
				Initialize()
				timeout = GetTime() + 7
				waitingForState = false
			end
			return
		end
		waitingForState = false
	end

	local complete = Sort()
	if complete or GetTime() > timeout then
		ClearCursor()
		driver:Hide()
		return
	end

	Stack()
	expectedState = GetExpectedInventoryState()
	waitingForState = true
	operationTimeout = GetTime() + 2
end)

function SB:SortInventory()
	CONTAINERS = {0, 1, 2, 3, 4}
	Start()
end

function SB:SortBank()
	-- WotLK: bank container -1, bank bags 5-11 (NUM_BANKBAGSLOTS = 7)
	CONTAINERS = {-1, 5, 6, 7, 8, 9, 10, 11}
	Start()
end

function SB:IsRunning()
	return driver:IsShown()
end
