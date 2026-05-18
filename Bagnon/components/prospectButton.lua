--[[
	prospectButton.lua
		A bag prospect button widget. Each click casts Prospecting on the
		lowest-tier prospectable ore stack of 5+ in the bags.
--]]

local Bagnon = LibStub('AceAddon-3.0'):GetAddon('Bagnon')
local ProspectButton = Bagnon.Classy:New('Button')
Bagnon.ProspectButton = ProspectButton


local SIZE = 20
local NORMAL_TEXTURE_SIZE = 64 * (SIZE/36)

-- itemID -> tier (lower = older / cheaper). Ordering doubles as the
-- preference list: copper goes before saronite when both are present.
local ORES = {
	[2770]  = 1,  -- Copper Ore
	[2771]  = 2,  -- Tin Ore
	[2772]  = 3,  -- Iron Ore
	[3858]  = 4,  -- Mithril Ore
	[10620] = 5,  -- Thorium Ore
	[23424] = 6,  -- Fel Iron Ore
	[23425] = 7,  -- Adamantite Ore
	[36909] = 8,  -- Cobalt Ore
	[36912] = 9,  -- Saronite Ore
	[36910] = 10, -- Titanium Ore
}

-- Cached spellbook scan for the Prospecting spell. Invalidated whenever the
-- spellbook changes so picking up Jewelcrafting (or losing it) flips the gate.
local cached_knows
local known_watcher = CreateFrame('Frame')
known_watcher:RegisterEvent('PLAYER_LOGIN')
known_watcher:RegisterEvent('SPELLS_CHANGED')
known_watcher:SetScript('OnEvent', function() cached_knows = nil end)

local function knows_prospecting()
	if cached_knows ~= nil then return cached_knows end
	for tab = 1, GetNumSpellTabs() do
		local _, _, offset, count = GetSpellTabInfo(tab)
		for i = offset + 1, offset + count do
			if GetSpellName(i, BOOKTYPE_SPELL) == 'Prospecting' then
				cached_knows = true
				return true
			end
		end
	end
	cached_knows = false
	return false
end

ProspectButton.PlayerKnows = knows_prospecting

-- Find the lowest-tier ore stack of >= 5 in the player's bags.
local function find_target()
	local best_bag, best_slot, best_link, best_tier
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local id = tonumber(string.match(link, 'item:(%d+)'))
				local tier = id and ORES[id]
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

function ProspectButton:New(frameID, parent)
	-- Parent to UIParent (not the bag frame) so this secure-template button
	-- doesn't taint the bag frame's IsProtected, which would block Show() in
	-- combat. Positioning is handled via cross-parent SetPoint in Frame:Place*.
	local b = self:Bind(CreateFrame('Button', 'BagnonProspectButton' .. frameID, UIParent, 'SecureActionButtonTemplate'))
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
	icon:SetTexture([[Interface\Icons\INV_Misc_Gem_BloodGem_01]])

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

function ProspectButton:PreClick()
	if InCombatLockdown() then
		self:SetAttribute('macrotext', '')
		return
	end
	local bag, slot = find_target()
	if bag then
		self:SetAttribute('macrotext', '/cast Prospecting\n/use ' .. bag .. ' ' .. slot)
	else
		self:SetAttribute('macrotext', '')
	end
end

function ProspectButton:OnEnter()
	if self:GetRight() > (GetScreenWidth() / 2) then
		GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
	else
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	end
	GameTooltip:SetText('Prospecting')
	GameTooltip:AddLine('Prospects the lowest-tier ore stack (5+) in your bags.', 1, 1, 1, true)
	local bag, slot, link = find_target()
	if link then
		GameTooltip:AddLine('Next: ' .. link, 0.6, 0.8, 1, true)
	else
		GameTooltip:AddLine('No eligible ore stacks found.', 1, 0.4, 0.4, true)
	end
	GameTooltip:Show()
end

function ProspectButton:OnLeave()
	if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end


--[[ Properties ]]--

function ProspectButton:SetFrameID(frameID)
	self.frameID = frameID
end

function ProspectButton:GetFrameID()
	return self.frameID
end
