--[[
	disenchantButton.lua
		A bag disenchant button widget. Each click casts Disenchant on the
		first non-soulbound green-quality equipable item found in the bags.
--]]

local Bagnon = LibStub('AceAddon-3.0'):GetAddon('Bagnon')
local DisenchantButton = Bagnon.Classy:New('Button')
Bagnon.DisenchantButton = DisenchantButton


local SIZE = 20
local NORMAL_TEXTURE_SIZE = 64 * (SIZE/36)

local scan_tooltip = CreateFrame('GameTooltip', 'BagnonDisenchantScanTooltip', nil, 'GameTooltipTemplate')
scan_tooltip:SetOwner(UIParent, 'ANCHOR_NONE')

local function is_soulbound(bag, slot)
	scan_tooltip:ClearLines()
	scan_tooltip:SetBagItem(bag, slot)
	for i = 1, scan_tooltip:NumLines() do
		local line = _G['BagnonDisenchantScanTooltipTextLeft' .. i]
		local text = line and line:GetText()
		if text == ITEM_SOULBOUND then
			return true
		end
	end
	return false
end

-- Cached spellbook scan for the Disenchant spell. Invalidated whenever the
-- spellbook changes so picking up Enchanting (or losing it) flips the gate.
local cached_knows
local known_watcher = CreateFrame('Frame')
known_watcher:RegisterEvent('PLAYER_LOGIN')
known_watcher:RegisterEvent('SPELLS_CHANGED')
known_watcher:SetScript('OnEvent', function() cached_knows = nil end)

local function knows_disenchant()
	if cached_knows ~= nil then return cached_knows end
	for tab = 1, GetNumSpellTabs() do
		local _, _, offset, count = GetSpellTabInfo(tab)
		for i = offset + 1, offset + count do
			if GetSpellName(i, BOOKTYPE_SPELL) == 'Disenchant' then
				cached_knows = true
				return true
			end
		end
	end
	cached_knows = false
	return false
end

DisenchantButton.PlayerKnows = knows_disenchant

-- Pick the lowest-itemLevel equipable green that isn't soulbound. Iterating
-- the whole bag lets us prefer the lowest-value item rather than just the
-- first one the scan happens to hit.
local function find_target()
	local best_bag, best_slot, best_link, best_ilvl
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local _, _, quality, ilvl, _, _, _, _, equipLoc = GetItemInfo(link)
				if quality == 2 and equipLoc and equipLoc ~= ''
				   and not is_soulbound(bag, slot) then
					if not best_ilvl or (ilvl and ilvl < best_ilvl) then
						best_bag, best_slot, best_link, best_ilvl = bag, slot, link, ilvl
					end
				end
			end
		end
	end
	return best_bag, best_slot, best_link
end


--[[ Constructor ]]--

function DisenchantButton:New(frameID, parent)
	-- See ProspectButton:New for why this is parented to UIParent.
	local b = self:Bind(CreateFrame('Button', 'BagnonDisenchantButton' .. frameID, UIParent, 'SecureActionButtonTemplate'))
	b:SetFrameStrata('DIALOG')
	b:Hide()
	b:SetWidth(SIZE)
	b:SetHeight(SIZE)
	b:RegisterForClicks('AnyUp')
	b:SetAttribute('type', 'macro')
	b:SetAttribute('macrotext', '')

	local nt = b:CreateTexture()
	nt:SetTexture([[Interface\Buttons\UI-Quickslot2]])
	nt:SetWidth(NORMAL_TEXTURE_SIZE)
	nt:SetHeight(NORMAL_TEXTURE_SIZE)
	nt:SetPoint('CENTER', 0, -1)
	b:SetNormalTexture(nt)

	local pt = b:CreateTexture()
	pt:SetTexture([[Interface\Buttons\UI-Quickslot-Depress]])
	pt:SetAllPoints(b)
	b:SetPushedTexture(pt)

	local ht = b:CreateTexture()
	ht:SetTexture([[Interface\Buttons\ButtonHilight-Square]])
	ht:SetAllPoints(b)
	b:SetHighlightTexture(ht)

	local icon = b:CreateTexture(nil, 'ARTWORK')
	icon:SetAllPoints(b)
	icon:SetTexture([[Interface\Icons\INV_Enchant_Disenchant]])

	b:SetScript('PreClick', b.PreClick)
	b:SetScript('OnEnter', b.OnEnter)
	b:SetScript('OnLeave', b.OnLeave)
	b:RegisterEvent('BAG_UPDATE')
	b:SetScript('OnEvent', function(self)
		if GameTooltip:IsOwned(self) then self:OnEnter() end
	end)
	b:SetFrameID(frameID)

	return b
end


--[[ Frame Events ]]--

-- Recompute the macro just before the secure click fires so we always target
-- a still-present, still-eligible item.
function DisenchantButton:PreClick()
	if InCombatLockdown() then
		self:SetAttribute('macrotext', '')
		return
	end
	local bag, slot = find_target()
	if bag then
		self:SetAttribute('macrotext', '/cast Disenchant\n/use ' .. bag .. ' ' .. slot)
	else
		self:SetAttribute('macrotext', '')
	end
end

function DisenchantButton:OnEnter()
	if self:GetRight() > (GetScreenWidth() / 2) then
		GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
	else
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	end
	GameTooltip:SetText('Disenchant')
	GameTooltip:AddLine('Disenchants the first non-soulbound green item in your bags.', 1, 1, 1, true)
	local bag, slot, link = find_target()
	if link then
		GameTooltip:AddLine('Next: ' .. link, 0.6, 0.8, 1, true)
	else
		GameTooltip:AddLine('No eligible items found.', 1, 0.4, 0.4, true)
	end
	GameTooltip:Show()
end

function DisenchantButton:OnLeave()
	if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end


--[[ Properties ]]--

function DisenchantButton:SetFrameID(frameID)
	self.frameID = frameID
end

function DisenchantButton:GetFrameID()
	return self.frameID
end
