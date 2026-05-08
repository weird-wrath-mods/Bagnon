--[[
	sortToggle.lua
		A bag sort button widget
--]]

local Bagnon = LibStub('AceAddon-3.0'):GetAddon('Bagnon')
local SortToggle = Bagnon.Classy:New('Button')
Bagnon.SortToggle = SortToggle


local SIZE = 20
local NORMAL_TEXTURE_SIZE = 64 * (SIZE/36)


--[[ Constructor ]]--

function SortToggle:New(frameID, parent)
	local b = self:Bind(CreateFrame('Button', nil, parent))
	b:SetWidth(SIZE)
	b:SetHeight(SIZE)
	b:RegisterForClicks('anyUp')

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
	icon:SetTexture([[Interface\Icons\INV_Misc_Shovel_01]])

	b:SetScript('OnClick', b.OnClick)
	b:SetScript('OnEnter', b.OnEnter)
	b:SetScript('OnLeave', b.OnLeave)
	b:SetFrameID(frameID)

	return b
end


--[[ Frame Events ]]--

function SortToggle:OnClick()
	if not Bagnon.SortBags then return end
	if Bagnon.SortBags:IsRunning() then return end

	if self:GetFrameID() == 'bank' then
		Bagnon.SortBags:SortBank()
	else
		Bagnon.SortBags:SortInventory()
	end
end

function SortToggle:OnEnter()
	if self:GetRight() > (GetScreenWidth() / 2) then
		GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
	else
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	end
	GameTooltip:SetText(self:GetFrameID() == 'bank' and 'Sort Bank' or 'Sort Bags')
	GameTooltip:Show()
end

function SortToggle:OnLeave()
	if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end


--[[ Properties ]]--

function SortToggle:SetFrameID(frameID)
	self.frameID = frameID
end

function SortToggle:GetFrameID()
	return self.frameID
end
