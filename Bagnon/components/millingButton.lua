--[[
	millingButton.lua
		A bag mill button widget. Each click casts Milling on the
		lowest-tier millable herb stack of 5+ in the bags.
--]]

local Bagnon = LibStub('AceAddon-3.0'):GetAddon('Bagnon')
local MillingButton = Bagnon.Classy:New('Button')
Bagnon.MillingButton = MillingButton


local SIZE = 20
local NORMAL_TEXTURE_SIZE = 64 * (SIZE/36)

-- itemID -> tier (lower = older / cheaper). Ordering doubles as the
-- preference list: silverleaf goes before icethorn when both are present.
local HERBS = {
	-- Tier 1 (Alabaster Pigment)
	[765]   = 1,  -- Silverleaf
	[2447]  = 1,  -- Peacebloom
	[2449]  = 1,  -- Earthroot
	-- Tier 2 (Dusky/Verdant Pigment)
	[785]   = 2,  -- Mageroyal
	[2450]  = 2,  -- Briarthorn
	[2452]  = 2,  -- Swiftthistle
	[3820]  = 2,  -- Stranglekelp
	[2453]  = 2,  -- Bruiseweed
	-- Tier 3 (Golden/Burnt Pigment)
	[3355]  = 3,  -- Wild Steelbloom
	[3369]  = 3,  -- Grave Moss
	[3356]  = 3,  -- Kingsblood
	[3357]  = 3,  -- Liferoot
	-- Tier 4 (Emerald/Indigo Pigment)
	[3818]  = 4,  -- Fadeleaf
	[3821]  = 4,  -- Goldthorn
	[3358]  = 4,  -- Khadgar's Whisker
	[3819]  = 4,  -- Wintersbite
	-- Tier 5 (Violet/Ruby Pigment)
	[4625]  = 5,  -- Firebloom
	[8831]  = 5,  -- Purple Lotus
	[8836]  = 5,  -- Arthas' Tears
	[8838]  = 5,  -- Sungrass
	[8839]  = 5,  -- Blindweed
	[8845]  = 5,  -- Ghost Mushroom
	[8846]  = 5,  -- Gromsblood
	-- Tier 6 (Silvery/Sapphire Pigment)
	[13464] = 6,  -- Golden Sansam
	[13463] = 6,  -- Dreamfoil
	[13465] = 6,  -- Mountain Silversage
	[13466] = 6,  -- Sorrowmoss
	[13467] = 6,  -- Icecap
	-- Tier 7 (Nether/Ebon Pigment)
	[22785] = 7,  -- Felweed
	[22786] = 7,  -- Dreaming Glory
	[22787] = 7,  -- Ragveil
	[22789] = 7,  -- Terocone
	[22790] = 7,  -- Ancient Lichen
	[22791] = 7,  -- Netherbloom
	[22792] = 7,  -- Nightmare Vine
	[22793] = 7,  -- Mana Thistle
	-- Tier 8 (Azure/Icy Pigment)
	[36901] = 8,  -- Goldclover
	[36903] = 8,  -- Adder's Tongue
	[36904] = 8,  -- Tiger Lily
	[36905] = 8,  -- Lichbloom
	[36906] = 8,  -- Icethorn
	[36907] = 8,  -- Talandra's Rose
	[37921] = 8,  -- Deadnettle
	[39970] = 8,  -- Firethorn
	[36908] = 8,  -- Frost Lotus
}

-- Cached spellbook scan for the Milling spell. Invalidated whenever the
-- spellbook changes so picking up Inscription (or losing it) flips the gate.
local cached_knows
local known_watcher = CreateFrame('Frame')
known_watcher:RegisterEvent('PLAYER_LOGIN')
known_watcher:RegisterEvent('SPELLS_CHANGED')
known_watcher:SetScript('OnEvent', function() cached_knows = nil end)

local function knows_milling()
	if cached_knows ~= nil then return cached_knows end
	for tab = 1, GetNumSpellTabs() do
		local _, _, offset, count = GetSpellTabInfo(tab)
		for i = offset + 1, offset + count do
			if GetSpellName(i, BOOKTYPE_SPELL) == 'Milling' then
				cached_knows = true
				return true
			end
		end
	end
	cached_knows = false
	return false
end

MillingButton.PlayerKnows = knows_milling

-- Find the lowest-tier herb stack of >= 5 in the player's bags.
local function find_target()
	local best_bag, best_slot, best_link, best_tier
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local id = tonumber(string.match(link, 'item:(%d+)'))
				local tier = id and HERBS[id]
				if tier then
					local _, count = GetContainerItemInfo(bag, slot)
					if count and count >= 5 then
						if not best_tier or tier < best_tier then
							best_bag, best_slot, best_link, best_tier = bag, slot, link, tier
						end
					end
				end
			end
		end
	end
	return best_bag, best_slot, best_link
end


--[[ Constructor ]]--

function MillingButton:New(frameID, parent)
	-- See ProspectButton:New for why this is parented to UIParent.
	local b = self:Bind(CreateFrame('Button', 'BagnonMillingButton' .. frameID, UIParent, 'SecureActionButtonTemplate'))
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
	icon:SetTexture([[Interface\Icons\Ability_Miling]])

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

function MillingButton:PreClick()
	if InCombatLockdown() then
		self:SetAttribute('macrotext', '')
		return
	end
	local bag, slot = find_target()
	if bag then
		self:SetAttribute('macrotext', '/cast Milling\n/use ' .. bag .. ' ' .. slot)
	else
		self:SetAttribute('macrotext', '')
	end
end

function MillingButton:OnEnter()
	if self:GetRight() > (GetScreenWidth() / 2) then
		GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
	else
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	end
	GameTooltip:SetText('Milling')
	GameTooltip:AddLine('Mills the lowest-tier herb stack (5+) in your bags.', 1, 1, 1, true)
	local bag, slot, link = find_target()
	if link then
		GameTooltip:AddLine('Next: ' .. link, 0.6, 0.8, 1, true)
	else
		GameTooltip:AddLine('No eligible herb stacks found.', 1, 0.4, 0.4, true)
	end
	GameTooltip:Show()
end

function MillingButton:OnLeave()
	if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end


--[[ Properties ]]--

function MillingButton:SetFrameID(frameID)
	self.frameID = frameID
end

function MillingButton:GetFrameID()
	return self.frameID
end
