--[[
	tokenFrame.lua
		Mirrors the default backpack's tracked-currency row (GetBackpackCurrencyInfo).
--]]

local Bagnon = LibStub('AceAddon-3.0'):GetAddon('Bagnon')
local TokenFrame = Bagnon.Classy:New('Frame')
TokenFrame:Hide()
Bagnon.TokenFrame = TokenFrame

local ICON_SIZE = 14
local TOKEN_SPACING = 6

do
	local id = 0
	function TokenFrame:GetNextID()
		id = id + 1
		return id
	end
end

function TokenFrame:New(frameID, parent)
	local f = self:Bind(CreateFrame('Frame', 'BagnonTokenFrame' .. self:GetNextID(), parent))
	f:SetHeight(ICON_SIZE)
	f.frameID = frameID
	f.tokens = {}

	f:SetScript('OnShow', f.OnShow)
	f:SetScript('OnHide', f.OnHide)

	f:UpdateTokens()
	return f
end

function TokenFrame:GetOrCreateTokenSlot(i)
	local slot = self.tokens[i]
	if slot then return slot end

	slot = CreateFrame('Button', self:GetName() .. 'Token' .. i, self)
	slot:SetHeight(ICON_SIZE)

	slot.icon = slot:CreateTexture(nil, 'ARTWORK')
	slot.icon:SetPoint('LEFT', slot, 'LEFT', 0, 0)
	slot.icon:SetWidth(ICON_SIZE)
	slot.icon:SetHeight(ICON_SIZE)

	slot.count = slot:CreateFontString(nil, 'OVERLAY', 'NumberFontNormal')
	slot.count:SetPoint('LEFT', slot.icon, 'RIGHT', 2, 0)
	slot.count:SetTextColor(1, 1, 1)

	slot:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
		GameTooltip:SetBackpackToken(self.tokenIndex)
	end)
	slot:SetScript('OnLeave', function() GameTooltip:Hide() end)
	slot:SetScript('OnMouseUp', function(_, button)
		if button == 'RightButton' then
			ToggleCharacter('TokenFrame')
		end
	end)

	self.tokens[i] = slot
	return slot
end

local function resolveIcon(icon)
	if not icon then return nil end
	if type(icon) == 'number' then
		return GetItemIcon and GetItemIcon(icon) or nil
	end
	if icon == '' then return nil end
	if not icon:find('\\') then
		return 'Interface\\Icons\\' .. icon
	end
	return icon
end

function TokenFrame:UpdateTokens()
	for i = 1, #self.tokens do
		local slot = self.tokens[i]
		slot:Hide()
		slot:ClearAllPoints()
		slot.icon:ClearAllPoints()
		slot.count:ClearAllPoints()
	end

	local maxSlots = (GetNumWatchedTokens and GetNumWatchedTokens()) or 0
	local x = 0
	local shown = 0

	for i = 1, maxSlots do
		local name, tokenCount, _, icon = GetBackpackCurrencyInfo(i)
		if name and name ~= '' then
			shown = shown + 1
			local slot = self:GetOrCreateTokenSlot(shown)
			slot.tokenIndex = i
			slot.icon:SetTexture(resolveIcon(icon))
			slot.count:SetText(tokenCount or 0)

			slot.icon:SetPoint('LEFT', slot, 'LEFT', 0, 0)
			slot.count:SetPoint('LEFT', slot.icon, 'RIGHT', 2, 0)

			local slotW = ICON_SIZE + 2 + tostring(tokenCount or 0):len() * 9
			slot:SetWidth(slotW)
			slot:SetPoint('LEFT', self, 'LEFT', x, 0)
			slot:Show()

			x = x + slotW + TOKEN_SPACING
		end
	end

	self:SetWidth(math.max(x - TOKEN_SPACING, 1))
	self.tokenCount = shown
end

function TokenFrame:HasAnyTokens()
	return ((GetNumWatchedTokens and GetNumWatchedTokens()) or 0) > 0
end

function TokenFrame:OnShow()
	self:RegisterEvent('BACKPACK_TOKEN_UPDATE')
	self:RegisterEvent('PLAYER_ENTERING_WORLD')
	self:SetScript('OnEvent', function(self) self:UpdateTokens() end)
	self:UpdateTokens()
end

function TokenFrame:OnHide()
	self:UnregisterAllEvents()
end

if not TokenFrame.hookedWatch and SetCurrencyBackpack then
	local deferrer = CreateFrame('Frame')
	hooksecurefunc('SetCurrencyBackpack', function()
		deferrer:SetScript('OnUpdate', function(self)
			self:SetScript('OnUpdate', nil)
			for _, frame in pairs(Bagnon.frames or {}) do
				local tf = frame.GetTokenFrame and frame:GetTokenFrame()
				if tf and tf:IsShown() then tf:UpdateTokens() end
			end
		end)
	end)
	TokenFrame.hookedWatch = true
end
