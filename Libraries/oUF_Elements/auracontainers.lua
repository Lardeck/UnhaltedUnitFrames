local _, UUF = ...
local oUF = UUF.oUF

local AuraContainerLoaded = false
local TypedDebuffTypes = {
	Magic = true,
	Curse = true,
	Disease = true,
	Poison = true,
	Bleed = true,
}

local AuraFilterGroups = {
	{Key = "Player", Filter = "PLAYER", Player = true},
	{Key = "BigDefensivePlayer", Filter = "BIG_DEFENSIVE|PLAYER", Player = true},
	{Key = "ExternalDefensivePlayer", Filter = "EXTERNAL_DEFENSIVE|PLAYER", Player = true},
	{Key = "RaidInCombatPlayer", Filter = "RAID_IN_COMBAT|PLAYER", Player = true},
	{Key = "CancelablePlayer", Filter = "CANCELABLE|PLAYER", Player = true},
	{Key = "NotCancelablePlayer", Filter = "!CANCELABLE|PLAYER", Player = true},
	{Key = "RaidPlayer", Filter = "RAID|PLAYER", Player = true},
	{Key = "BigDefensive", Filter = "BIG_DEFENSIVE|!PLAYER"},
	{Key = "ExternalDefensive", Filter = "EXTERNAL_DEFENSIVE|!PLAYER"},
	{Key = "RaidInCombat", Filter = "RAID_IN_COMBAT|!PLAYER"},
	{Key = "Cancelable", Filter = "CANCELABLE|!PLAYER"},
	{Key = "NotCancelable", Filter = "!CANCELABLE|!PLAYER"},
	{Key = "Raid", Filter = "RAID|!PLAYER"},
}

local AuraRefreshContainers = {
	PLAYER_TARGET_CHANGED = {},
	PLAYER_FOCUS_CHANGED = {},
}

local AuraRefreshEventFrame = CreateFrame("Frame")
AuraRefreshEventFrame:SetScript("OnEvent", function(_, event)
	local containers = AuraRefreshContainers[event]
	if not containers then return end
	for container in pairs(containers) do
		if container.UpdateAllAuras and (not container.IsEnabled or container:IsEnabled()) then container:UpdateAllAuras() end
	end
end)

local function LoadAuraContainer()
	if AuraContainerSortMethod and AuraContainerSortDirection and AuraButtonBorderStyle and AnchorUtil and AnchorUtil.FlowDirection then return true end
	if not AuraContainerLoaded then
		AuraContainerLoaded = true
		if C_AddOns and C_AddOns.LoadAddOn then
			pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
		elseif LoadAddOn then
			pcall(LoadAddOn, "Blizzard_AuraContainer")
		end
	end
	return AuraContainerSortMethod and AuraContainerSortDirection and AuraButtonBorderStyle and AnchorUtil and AnchorUtil.FlowDirection
end

local function GetCustomAuraFilter(CustomDB)
	return CustomDB and CustomDB.Type == "Debuffs" and "HARMFUL" or "HELPFUL"
end

function UUF:GetCustomAuraFilter(CustomDB)
	return GetCustomAuraFilter(CustomDB)
end

local function StyleAuras(_, button, unit, auraType, _, auraKey)
	if not button then return end
	unit = unit or button.UUFUnit
	auraType = auraType or button.UUFAuraType
	auraKey = auraKey or button.UUFAuraKey
	if not unit or not auraType then return end
	local UnitDB = UUF.db.profile.Units[UUF:GetNormalizedUnit(unit)]
	local AurasDB = UnitDB and UnitDB.Auras
	local AuraDB = AurasDB and AurasDB[auraKey or (auraType == "HELPFUL" and "Buffs" or "Debuffs")]
	if not AuraDB then return end

	button:SetSize(AuraDB.Size, AuraDB.Size)
	if button.Icon then button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
	if button.Cooldown then
		button.Cooldown:SetDrawEdge(false)
		button.Cooldown:SetReverse(true)
		UUF:ApplyCooldownText(button.Cooldown, nil, unit)
	end
	if button.Count then
		if AuraDB.Count.HideStacks then
			if button.ClearApplicationCount then button:ClearApplicationCount() end
			button.Count:Hide()
		else
			local FontsDB = UUF.db.profile.General.Fonts
			button.Count:ClearAllPoints()
			button.Count:SetFont(UUF.Media.Font, AuraDB.Count.FontSize, FontsDB.FontFlag)
			button.Count:SetPoint(AuraDB.Count.Layout[1], button, AuraDB.Count.Layout[2], AuraDB.Count.Layout[3], AuraDB.Count.Layout[4])
			if FontsDB.Shadow.Enabled then
				button.Count:SetShadowColor(FontsDB.Shadow.Colour[1], FontsDB.Shadow.Colour[2], FontsDB.Shadow.Colour[3], FontsDB.Shadow.Colour[4])
				button.Count:SetShadowOffset(FontsDB.Shadow.XPos, FontsDB.Shadow.YPos)
			else
				button.Count:SetShadowColor(0, 0, 0, 0)
				button.Count:SetShadowOffset(0, 0)
			end
			button.Count:SetTextColor(unpack(AuraDB.Count.Colour))
			button.Count:Show()
			if button.SetApplicationCount then button:SetApplicationCount(button.Count) end
		end
	end
	if button.Overlay then
		button.Overlay:SetTexture("Interface\\AddOns\\UnhaltedUnitFrames\\Media\\Textures\\AuraOverlay.png")
		button.Overlay:ClearAllPoints()
		button.Overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		button.Overlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
		button.Overlay:SetTexCoord(0, 1, 0, 1)
		if AuraDB.ShowType and button.SetAuraBorder and AuraButtonBorderStyle and AuraButtonBorderStyle.Color then
			button:SetAuraBorder(button.Overlay, {
				showIcon = false,
				showWhenHelpful = auraType == "HELPFUL",
				showWhenHarmful = auraType == "HARMFUL",
				style = AuraButtonBorderStyle.Color,
			})
		else
			if button.ClearAuraBorder then button:ClearAuraBorder() end
			button.Overlay:Hide()
		end
	end
end

UUF.StyleAuras = StyleAuras
UUF.FilterAura = function() return true end

local function GetSpellIDFilters(AurasDB, auraKey)
	local spellIDFilters
	local SpellIDFilterDB = UUF.db.profile.GlobalSpellIDFilters
	for filterIndex = 1, 2 do
		if filterIndex == 2 then SpellIDFilterDB = AurasDB.SpellIDFilters end
		if SpellIDFilterDB then
			for spellID, auraDestinations in pairs(SpellIDFilterDB) do
				if type(auraDestinations) == "table" and auraDestinations[auraKey] then
					local auraDestination = auraDestinations[auraKey]
					local mode = auraDestinations.Mode or "Whitelist"
					local source = auraDestinations.Source or "Any"
					if type(auraDestination) == "table" then
						mode = auraDestination.Mode or mode
						source = auraDestination.Source or source
					end
					if mode == "Whitelist" or mode == "Blacklist" then
						local spellIDValue = tonumber(spellID) or spellID
						if source ~= "Player" and source ~= "Other" then source = "Any" end
						spellIDFilters = spellIDFilters or {Whitelist = {}, Blacklist = {}}
						if mode == "Whitelist" then
							spellIDFilters.HasWhitelist = true
							spellIDFilters.Whitelist[source] = spellIDFilters.Whitelist[source] or {}
							spellIDFilters.Whitelist[source][spellIDValue] = true
						elseif source == "Any" then
							spellIDFilters.Blacklist.Any = spellIDFilters.Blacklist.Any or {}
							spellIDFilters.Blacklist.Player = spellIDFilters.Blacklist.Player or {}
							spellIDFilters.Blacklist.Other = spellIDFilters.Blacklist.Other or {}
							spellIDFilters.Blacklist.Any[spellIDValue] = true
							spellIDFilters.Blacklist.Player[spellIDValue] = true
							spellIDFilters.Blacklist.Other[spellIDValue] = true
						else
							spellIDFilters.HasSourceBlacklist = true
							spellIDFilters.Blacklist[source] = spellIDFilters.Blacklist[source] or {}
							spellIDFilters.Blacklist[source][spellIDValue] = true
						end
					end
				end
			end
		end
	end
	return spellIDFilters
end

local function GetCandidateFilters(AuraDB, auraType, typed, includeSpellIDs, excludeSpellIDs)
	local candidateFilters
	if AuraDB.Blacklist or excludeSpellIDs then
		candidateFilters = candidateFilters or {}
		if AuraDB.Blacklist and excludeSpellIDs then
			candidateFilters.excludeSpellIDs = {}
			for spellID in pairs(UUF.AURA_BLACKLIST) do candidateFilters.excludeSpellIDs[spellID] = true end
			for spellID in pairs(excludeSpellIDs) do candidateFilters.excludeSpellIDs[spellID] = true end
		else
			candidateFilters.excludeSpellIDs = AuraDB.Blacklist and UUF.AURA_BLACKLIST or excludeSpellIDs
		end
	end
	if AuraDB.OnlyShowPlayer then
		candidateFilters = candidateFilters or {}
		candidateFilters.isFromPlayerOrPlayerPet = true
	end
	if typed and auraType == "HARMFUL" then
		candidateFilters = candidateFilters or {}
		candidateFilters.includeDispelTypes = TypedDebuffTypes
	end
	if includeSpellIDs then
		candidateFilters = candidateFilters or {}
		candidateFilters.includeSpellIDs = includeSpellIDs
	end
	return candidateFilters
end

local function InitializeAuraButton(container, button, unit, auraKey, auraType)
	if not button.UUFBorder then
		button.UUFBorder = CreateFrame("Frame", nil, button, "BackdropTemplate")
		button.UUFBorder:SetAllPoints()
		button.UUFBorder:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, insets = {left = 0, right = 0, top = 0, bottom = 0}})
		button.UUFBorder:SetBackdropBorderColor(0, 0, 0, 1)
	end

	if not button.Icon then button.Icon = button:CreateTexture(nil, "BORDER") end
	button.Icon:ClearAllPoints()
	button.Icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
	button.Icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
	if button.SetIcon then button:SetIcon(button.Icon) end

	if not button.Cooldown then button.Cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate") end
	button.Cooldown:ClearAllPoints()
	button.Cooldown:SetAllPoints(button)
	if button.SetDurationCooldown then button:SetDurationCooldown(button.Cooldown) end

	if not button.Count then button.Count = button:CreateFontString(nil, "OVERLAY") end
	if not button.Overlay then button.Overlay = button:CreateTexture(nil, "OVERLAY") end

	if not container.UUFButtonRegistry[button] then
		container.UUFButtonRegistry[button] = true
		container.UUFButtons[#container.UUFButtons + 1] = button
	end
	button.UUFUnit = unit
	button.UUFAuraKey = auraKey
	button.UUFAuraType = auraType
	StyleAuras(container, button, unit, auraType, nil, auraKey)
end

local function ConfigureAuraGroup(container, groupKey, filterString, AuraDB, unit, auraKey, auraType, enabled, candidateFilters, sortMethod, sortDirection, layout)
	if not enabled then
		if container:HasAuraGroup(groupKey) then container:SetAuraGroupMaxFrameCount(groupKey, 0) end
		return
	end

	local maxFrameCount = AuraDB.Num or 0
	if not container:HasAuraGroup(groupKey) then
		container:AddAuraGroup(groupKey, filterString, {
			maxFrameCount = maxFrameCount,
			candidateFilters = candidateFilters,
			sortMethod = sortMethod,
			sortDirection = sortDirection,
			layout = layout,
			initializeFrame = function(button) InitializeAuraButton(container, button, unit, auraKey, auraType) end,
		})
		return
	end

	container:SetAuraGroupMaxFrameCount(groupKey, maxFrameCount)
	container:SetAuraGroupCandidateFilters(groupKey, candidateFilters)
	container:SetAuraGroupSortMethod(groupKey, sortMethod, sortDirection)
	container:SetAuraGroupLayout(groupKey, layout)
end

local function ConfigureAuraContainer(container, unitFrame, unit, AurasDB, AuraDB, auraKey, auraType)
	local spacing = AuraDB.Layout[5] or 0
	local perRow = math.max(AuraDB.Wrap or 1, 1)
	local rows = math.max(math.ceil((AuraDB.Num or 0) / perRow), 1)
	local width = math.max((AuraDB.Size * perRow) + (spacing * (perRow - 1)), 1)
	local height = math.max((AuraDB.Size * rows) + (spacing * (rows - 1)), 1)
	local spellIDFilters = auraType == "HELPFUL" and not AuraDB.OnlyShowPlayer and GetSpellIDFilters(AurasDB, auraKey) or nil
	local whitelistSpellIDs = spellIDFilters and spellIDFilters.Whitelist
	local blacklistSpellIDs = spellIDFilters and spellIDFilters.Blacklist
	local hasSpellIDs = spellIDFilters and spellIDFilters.HasWhitelist
	local hasSourceBlacklist = spellIDFilters and spellIDFilters.HasSourceBlacklist
	local hasFilters = hasSpellIDs
	local sortMethod = AuraContainerSortMethod.Default
	local sortDirection = AuraContainerSortDirection.Normal
	local layout = {elementSpacingX = spacing, elementSpacingY = spacing, elementWidth = AuraDB.Size, elementHeight = AuraDB.Size}
	local candidateFilters = GetCandidateFilters(AuraDB, auraType, nil, nil, blacklistSpellIDs and blacklistSpellIDs.Any)
	local playerCandidateFilters = hasSourceBlacklist and GetCandidateFilters(AuraDB, auraType, nil, nil, blacklistSpellIDs.Player) or candidateFilters
	local otherCandidateFilters = hasSourceBlacklist and GetCandidateFilters(AuraDB, auraType, nil, nil, blacklistSpellIDs.Other) or candidateFilters
	local typedFilters = auraType == "HARMFUL" and GetCandidateFilters(AuraDB, auraType, true, nil, blacklistSpellIDs and blacklistSpellIDs.Any) or nil
	local typedPlayerFilters = auraType == "HARMFUL" and hasSourceBlacklist and GetCandidateFilters(AuraDB, auraType, true, nil, blacklistSpellIDs.Player) or typedFilters
	local typedOtherFilters = auraType == "HARMFUL" and hasSourceBlacklist and GetCandidateFilters(AuraDB, auraType, true, nil, blacklistSpellIDs.Other) or typedFilters

	if AuraDB.Sorting == "BLIZZARD_REVERSED" then
		sortDirection = AuraContainerSortDirection.Reverse
	elseif AuraDB.Sorting == "DURATION" then
		sortMethod = AuraContainerSortMethod.ExpirationOnly
	elseif AuraDB.Sorting == "DURATION_REVERSED" then
		sortMethod = AuraContainerSortMethod.ExpirationOnly
		sortDirection = AuraContainerSortDirection.Reverse
	end
	if AuraDB.Filters and not AuraDB.OnlyShowPlayer then
		if auraType == "HARMFUL" and AuraDB.Filters.Typed then hasFilters = true end
		for _, filterGroup in ipairs(AuraFilterGroups) do
			if AuraDB.Filters[filterGroup.Key] then
				hasFilters = true
				break
			end
		end
	end

	container:SetUnit(unit == "partyplayer" and "player" or unit)
	container:ClearAllPoints()
	container:SetPoint(AuraDB.Layout[1], unitFrame, AuraDB.Layout[2], AuraDB.Layout[3], AuraDB.Layout[4])
	container:SetSize(width, height)
	container:SetFrameStrata(AurasDB.FrameStrata)
	container:SetAuraLayoutAnchorPoint(AuraDB.Layout[1])
	container:SetAuraLayoutGrowthDirection(AuraDB.GrowthDirection == "LEFT" and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right, AuraDB.WrapDirection == "UP" and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
	container:SetAuraLayoutRowWidth(width)

	ConfigureAuraGroup(container, auraKey, auraType, AuraDB, unit, auraKey, auraType, AuraDB.Enabled and not hasFilters and not hasSourceBlacklist, candidateFilters, sortMethod, sortDirection, layout)
	ConfigureAuraGroup(container, auraKey .. "PlayerBlacklist", auraType .. "|PLAYER", AuraDB, unit, auraKey, auraType, AuraDB.Enabled and not hasFilters and hasSourceBlacklist, playerCandidateFilters, sortMethod, sortDirection, layout)
	ConfigureAuraGroup(container, auraKey .. "OtherBlacklist", auraType .. "|!PLAYER", AuraDB, unit, auraKey, auraType, AuraDB.Enabled and not hasFilters and hasSourceBlacklist, otherCandidateFilters, sortMethod, sortDirection, layout)
	if auraType == "HARMFUL" then
		local typedEnabled = AuraDB.Enabled and AuraDB.Filters and AuraDB.Filters.Typed and not AuraDB.OnlyShowPlayer
		ConfigureAuraGroup(container, auraKey .. "Typed", auraType, AuraDB, unit, auraKey, auraType, typedEnabled and not hasSourceBlacklist, typedFilters, sortMethod, sortDirection, layout)
		ConfigureAuraGroup(container, auraKey .. "TypedPlayerBlacklist", auraType .. "|PLAYER", AuraDB, unit, auraKey, auraType, typedEnabled and hasSourceBlacklist, typedPlayerFilters, sortMethod, sortDirection, layout)
		ConfigureAuraGroup(container, auraKey .. "TypedOtherBlacklist", auraType .. "|!PLAYER", AuraDB, unit, auraKey, auraType, typedEnabled and hasSourceBlacklist, typedOtherFilters, sortMethod, sortDirection, layout)
	end
	ConfigureAuraGroup(container, auraKey .. "SpellIDs", auraType, AuraDB, unit, auraKey, auraType, AuraDB.Enabled and hasSpellIDs and whitelistSpellIDs.Any, GetCandidateFilters(AuraDB, auraType, nil, whitelistSpellIDs and whitelistSpellIDs.Any, blacklistSpellIDs and blacklistSpellIDs.Any), sortMethod, sortDirection, layout)
	ConfigureAuraGroup(container, auraKey .. "SpellIDsPlayer", auraType .. "|PLAYER", AuraDB, unit, auraKey, auraType, AuraDB.Enabled and hasSpellIDs and whitelistSpellIDs.Player, GetCandidateFilters(AuraDB, auraType, nil, whitelistSpellIDs and whitelistSpellIDs.Player, blacklistSpellIDs and blacklistSpellIDs.Player), sortMethod, sortDirection, layout)
	ConfigureAuraGroup(container, auraKey .. "SpellIDsOther", auraType .. "|!PLAYER", AuraDB, unit, auraKey, auraType, AuraDB.Enabled and hasSpellIDs and whitelistSpellIDs.Other, GetCandidateFilters(AuraDB, auraType, nil, whitelistSpellIDs and whitelistSpellIDs.Other, blacklistSpellIDs and blacklistSpellIDs.Other), sortMethod, sortDirection, layout)
	for _, filterGroup in ipairs(AuraFilterGroups) do
		local enabled = AuraDB.Enabled and hasFilters and AuraDB.Filters and AuraDB.Filters[filterGroup.Key] and (not filterGroup.Player or filterGroup.Key == "Player" or not AuraDB.Filters.Player)
		ConfigureAuraGroup(container, auraKey .. filterGroup.Key, auraType .. "|" .. filterGroup.Filter, AuraDB, unit, auraKey, auraType, enabled, filterGroup.Player and playerCandidateFilters or otherCandidateFilters, sortMethod, sortDirection, layout)
	end
	if container.UUFButtons then
		for _, button in ipairs(container.UUFButtons) do
			StyleAuras(container, button, unit, button.UUFAuraType, true, button.UUFAuraKey)
		end
	end
	container:SetEnabled(AuraDB.Enabled and not UUF.AURA_TEST_MODE)
	if AuraDB.Enabled then
		container:Show()
		if not UUF.AURA_TEST_MODE then container:UpdateAllAuras() end
	else
		container:Hide()
	end
end

local function CreateAuraContainer(unitFrame, unit, suffix)
	local container = CreateFrame("AuraContainer", UUF:FetchFrameName(unit) .. "_" .. suffix, unitFrame, "CustomAuraContainerTemplate")
	container.UUFButtons = {}
	container.UUFButtonRegistry = {}
	container.tooltipAnchor = "ANCHOR_CURSOR"
	container:SetEnabled(false)
	container:Hide()
	return container
end

local function RegisterAuraRefreshEvent(container, unit)
	if not container then return end
	local event = unit == "target" and "PLAYER_TARGET_CHANGED" or unit == "focus" and "PLAYER_FOCUS_CHANGED"
	if container.UUFAuraRefreshEvent and container.UUFAuraRefreshEvent ~= event then
		AuraRefreshContainers[container.UUFAuraRefreshEvent][container] = nil
		if not next(AuraRefreshContainers[container.UUFAuraRefreshEvent]) then AuraRefreshEventFrame:UnregisterEvent(container.UUFAuraRefreshEvent) end
		container.UUFAuraRefreshEvent = nil
	end
	if not event or container.UUFAuraRefreshEvent == event then return end
	AuraRefreshContainers[event][container] = true
	container.UUFAuraRefreshEvent = event
	AuraRefreshEventFrame:RegisterEvent(event)
end

local function UnregisterAuraRefreshEvent(container)
	if not container or not container.UUFAuraRefreshEvent then return end
	local event = container.UUFAuraRefreshEvent
	AuraRefreshContainers[event][container] = nil
	container.UUFAuraRefreshEvent = nil
	if not next(AuraRefreshContainers[event]) then AuraRefreshEventFrame:UnregisterEvent(event) end
end

local function HideFakeAuras(container)
	if not container then return end
	for index = 1, (container.maxFake or 0) do
		local button = container["fake" .. index]
		if button then button:Hide() end
	end
end

local function CreateTestAuraButtons(container, unitFrame, unit, AuraDB, icon, frameStrata)
	if not container then return end
	if not AuraDB.Enabled then
		HideFakeAuras(container)
		container:Hide()
		return
	end

	local General = UUF.db.profile.General
	local spacing = AuraDB.Layout[5] or 0
	local perRow = math.max(AuraDB.Wrap or 1, 1)
	local rows = math.max(math.ceil((AuraDB.Num or 0) / perRow), 1)

	container:ClearAllPoints()
	container:SetSize(math.max((AuraDB.Size * perRow) + (spacing * (perRow - 1)), 1), math.max((AuraDB.Size * rows) + (spacing * (rows - 1)), 1))
	container:SetPoint(AuraDB.Layout[1], unitFrame, AuraDB.Layout[2], AuraDB.Layout[3], AuraDB.Layout[4])
	container:SetFrameStrata(frameStrata)
	container:Show()
	if container.UUFButtons then
		for _, button in ipairs(container.UUFButtons) do
			if button then button:Hide() end
		end
	end

	for index = 1, AuraDB.Num do
		local button = container["fake" .. index]
		if not button then
			button = CreateFrame("Button", nil, container, "BackdropTemplate")
			button:SetBackdrop(UUF.BACKDROP)
			button:SetBackdropColor(0, 0, 0, 0)
			button:SetBackdropBorderColor(0, 0, 0, 1)
			button.Icon = button:CreateTexture(nil, "BORDER")
			button.Count = button:CreateFontString(nil, "OVERLAY")
			container["fake" .. index] = button
		end

		local row = math.floor((index - 1) / perRow)
		local column = (index - 1) % perRow
		local x = column * (AuraDB.Size + spacing)
		local y = row * (AuraDB.Size + spacing)
		if AuraDB.GrowthDirection == "LEFT" then x = -x end
		if AuraDB.WrapDirection == "DOWN" then y = -y end

		button:SetSize(AuraDB.Size, AuraDB.Size)
		button:SetFrameStrata(frameStrata)
		button:ClearAllPoints()
		button:SetPoint(AuraDB.Layout[1], container, AuraDB.Layout[1], x, y)
		button.Icon:ClearAllPoints()
		button.Icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		button.Icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
		button.Icon:SetTexture(icon)
		button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		button.Count:ClearAllPoints()
		button.Count:SetPoint(AuraDB.Count.Layout[1], button, AuraDB.Count.Layout[2], AuraDB.Count.Layout[3], AuraDB.Count.Layout[4])
		button.Count:SetFont(UUF.Media.Font, AuraDB.Count.FontSize, General.Fonts.FontFlag)
		if General.Fonts.Shadow.Enabled then
			button.Count:SetShadowColor(unpack(General.Fonts.Shadow.Colour))
			button.Count:SetShadowOffset(General.Fonts.Shadow.XPos, General.Fonts.Shadow.YPos)
		else
			button.Count:SetShadowColor(0, 0, 0, 0)
			button.Count:SetShadowOffset(0, 0)
		end
		button.Count:SetTextColor(unpack(AuraDB.Count.Colour))
		button.Count:SetText(index)
		if AuraDB.Count.HideStacks then button.Count:Hide() else button.Count:Show() end
		button.Duration = button.Duration or button:CreateFontString(nil, "OVERLAY")
		UUF:ApplyCooldownText(button, button.Duration, unit)
		button.Duration:SetText("10m")
		button:Show()
	end

	for index = AuraDB.Num + 1, (container.maxFake or AuraDB.Num) do
		local button = container["fake" .. index]
		if button then button:Hide() end
	end
	container.maxFake = AuraDB.Num
end

local function Update(self, _, unit)
	local element = self.UUFAuras
	if not element or not LoadAuraContainer() then return end

	unit = unit or element.UUFUnit or self.unit
	if not unit then return end

	local UnitDB = UUF.db.profile.Units[UUF:GetNormalizedUnit(unit)]
	local AurasDB = UnitDB and UnitDB.Auras
	if not AurasDB then return end

	local BuffsDB = AurasDB.Buffs
	local DebuffsDB = AurasDB.Debuffs
	local CustomDB = AurasDB.Custom
	BuffsDB.Filter = "HELPFUL"
	DebuffsDB.Filter = "HARMFUL"
	if CustomDB then CustomDB.Filter = GetCustomAuraFilter(CustomDB) end

	element.UUFUnit = unit
	if not element.BuffContainer then element.BuffContainer = CreateAuraContainer(self, unit, "BuffsContainer") end
	if not element.DebuffContainer then element.DebuffContainer = CreateAuraContainer(self, unit, "DebuffsContainer") end
	if CustomDB and not element.CustomAuraContainer then element.CustomAuraContainer = CreateAuraContainer(self, unit, "CustomAurasContainer") end
	self.BuffContainer = element.BuffContainer
	self.DebuffContainer = element.DebuffContainer
	if element.CustomAuraContainer then self.CustomAuraContainer = element.CustomAuraContainer end
	RegisterAuraRefreshEvent(element.BuffContainer, unit)
	RegisterAuraRefreshEvent(element.DebuffContainer, unit)
	RegisterAuraRefreshEvent(element.CustomAuraContainer, unit)
	self.Buffs = nil
	self.Debuffs = nil
	self.CustomAuras = nil
	self.PrivateAuras = nil

	ConfigureAuraContainer(element.BuffContainer, self, unit, AurasDB, BuffsDB, "Buffs", "HELPFUL")
	ConfigureAuraContainer(element.DebuffContainer, self, unit, AurasDB, DebuffsDB, "Debuffs", "HARMFUL")
	if CustomDB and element.CustomAuraContainer then
		local CustomAuraContainer = element.CustomAuraContainer
		local spacing = CustomDB.Layout[5] or 0
		local perRow = math.max(CustomDB.Wrap or 1, 1)
		local rows = math.max(math.ceil((CustomDB.Num or 0) / perRow), 1)
		local width = math.max((CustomDB.Size * perRow) + (spacing * (perRow - 1)), 1)
		local height = math.max((CustomDB.Size * rows) + (spacing * (rows - 1)), 1)
		local customAuraFilter = GetCustomAuraFilter(CustomDB)
		local spellIDFilters = customAuraFilter == "HELPFUL" and not CustomDB.OnlyShowPlayer and GetSpellIDFilters(AurasDB, "Custom") or nil
		local whitelistSpellIDs = spellIDFilters and spellIDFilters.Whitelist
		local blacklistSpellIDs = spellIDFilters and spellIDFilters.Blacklist
		local hasSpellIDs = spellIDFilters and spellIDFilters.HasWhitelist
		local hasSourceBlacklist = spellIDFilters and spellIDFilters.HasSourceBlacklist
		local hasFilters = hasSpellIDs
		local sortMethod = AuraContainerSortMethod.Default
		local sortDirection = AuraContainerSortDirection.Normal
		local layout = {elementSpacingX = spacing, elementSpacingY = spacing, elementWidth = CustomDB.Size, elementHeight = CustomDB.Size}
		local buffCandidateFilters = GetCandidateFilters(CustomDB, "HELPFUL", nil, nil, blacklistSpellIDs and blacklistSpellIDs.Any)
		local debuffCandidateFilters = GetCandidateFilters(CustomDB, "HARMFUL", nil, nil, blacklistSpellIDs and blacklistSpellIDs.Any)
		local buffPlayerCandidateFilters = hasSourceBlacklist and GetCandidateFilters(CustomDB, "HELPFUL", nil, nil, blacklistSpellIDs.Player) or buffCandidateFilters
		local buffOtherCandidateFilters = hasSourceBlacklist and GetCandidateFilters(CustomDB, "HELPFUL", nil, nil, blacklistSpellIDs.Other) or buffCandidateFilters
		local debuffPlayerCandidateFilters = hasSourceBlacklist and GetCandidateFilters(CustomDB, "HARMFUL", nil, nil, blacklistSpellIDs.Player) or debuffCandidateFilters
		local debuffOtherCandidateFilters = hasSourceBlacklist and GetCandidateFilters(CustomDB, "HARMFUL", nil, nil, blacklistSpellIDs.Other) or debuffCandidateFilters
		local typedFilters = GetCandidateFilters(CustomDB, "HARMFUL", true, nil, blacklistSpellIDs and blacklistSpellIDs.Any)
		local typedPlayerFilters = hasSourceBlacklist and GetCandidateFilters(CustomDB, "HARMFUL", true, nil, blacklistSpellIDs.Player) or typedFilters
		local typedOtherFilters = hasSourceBlacklist and GetCandidateFilters(CustomDB, "HARMFUL", true, nil, blacklistSpellIDs.Other) or typedFilters

		if CustomDB.Sorting == "BLIZZARD_REVERSED" then
			sortDirection = AuraContainerSortDirection.Reverse
		elseif CustomDB.Sorting == "DURATION" then
			sortMethod = AuraContainerSortMethod.ExpirationOnly
		elseif CustomDB.Sorting == "DURATION_REVERSED" then
			sortMethod = AuraContainerSortMethod.ExpirationOnly
			sortDirection = AuraContainerSortDirection.Reverse
		end
		if CustomDB.Filters and not CustomDB.OnlyShowPlayer then
			if customAuraFilter == "HARMFUL" and CustomDB.Filters.Typed then hasFilters = true end
			for _, filterGroup in ipairs(AuraFilterGroups) do
				if CustomDB.Filters[filterGroup.Key] then
					hasFilters = true
					break
				end
			end
		end

		CustomAuraContainer:SetUnit(unit == "partyplayer" and "player" or unit)
		CustomAuraContainer:ClearAllPoints()
		CustomAuraContainer:SetPoint(CustomDB.Layout[1], self, CustomDB.Layout[2], CustomDB.Layout[3], CustomDB.Layout[4])
		CustomAuraContainer:SetSize(width, height)
		CustomAuraContainer:SetFrameStrata(AurasDB.FrameStrata)
		CustomAuraContainer:SetAuraLayoutAnchorPoint(CustomDB.Layout[1])
		CustomAuraContainer:SetAuraLayoutGrowthDirection(CustomDB.GrowthDirection == "LEFT" and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right, CustomDB.WrapDirection == "UP" and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
		CustomAuraContainer:SetAuraLayoutRowWidth(width)

		ConfigureAuraGroup(CustomAuraContainer, "CustomBuffs", "HELPFUL", CustomDB, unit, "Custom", "HELPFUL", CustomDB.Enabled and customAuraFilter == "HELPFUL" and not hasFilters and not hasSourceBlacklist, buffCandidateFilters, sortMethod, sortDirection, layout)
		ConfigureAuraGroup(CustomAuraContainer, "CustomDebuffs", "HARMFUL", CustomDB, unit, "Custom", "HARMFUL", CustomDB.Enabled and customAuraFilter == "HARMFUL" and not hasFilters and not hasSourceBlacklist, debuffCandidateFilters, sortMethod, sortDirection, layout)
		ConfigureAuraGroup(CustomAuraContainer, "CustomBuffsPlayerBlacklist", "HELPFUL|PLAYER", CustomDB, unit, "Custom", "HELPFUL", CustomDB.Enabled and customAuraFilter == "HELPFUL" and not hasFilters and hasSourceBlacklist, buffPlayerCandidateFilters, sortMethod, sortDirection, layout)
		ConfigureAuraGroup(CustomAuraContainer, "CustomBuffsOtherBlacklist", "HELPFUL|!PLAYER", CustomDB, unit, "Custom", "HELPFUL", CustomDB.Enabled and customAuraFilter == "HELPFUL" and not hasFilters and hasSourceBlacklist, buffOtherCandidateFilters, sortMethod, sortDirection, layout)
		ConfigureAuraGroup(CustomAuraContainer, "CustomDebuffsPlayerBlacklist", "HARMFUL|PLAYER", CustomDB, unit, "Custom", "HARMFUL", CustomDB.Enabled and customAuraFilter == "HARMFUL" and not hasFilters and hasSourceBlacklist, debuffPlayerCandidateFilters, sortMethod, sortDirection, layout)
		ConfigureAuraGroup(CustomAuraContainer, "CustomDebuffsOtherBlacklist", "HARMFUL|!PLAYER", CustomDB, unit, "Custom", "HARMFUL", CustomDB.Enabled and customAuraFilter == "HARMFUL" and not hasFilters and hasSourceBlacklist, debuffOtherCandidateFilters, sortMethod, sortDirection, layout)
		local customTypedEnabled = CustomDB.Enabled and customAuraFilter == "HARMFUL" and CustomDB.Filters and CustomDB.Filters.Typed and not CustomDB.OnlyShowPlayer
		ConfigureAuraGroup(CustomAuraContainer, "CustomDebuffsTyped", "HARMFUL", CustomDB, unit, "Custom", "HARMFUL", customTypedEnabled and not hasSourceBlacklist, typedFilters, sortMethod, sortDirection, layout)
		ConfigureAuraGroup(CustomAuraContainer, "CustomDebuffsTypedPlayerBlacklist", "HARMFUL|PLAYER", CustomDB, unit, "Custom", "HARMFUL", customTypedEnabled and hasSourceBlacklist, typedPlayerFilters, sortMethod, sortDirection, layout)
		ConfigureAuraGroup(CustomAuraContainer, "CustomDebuffsTypedOtherBlacklist", "HARMFUL|!PLAYER", CustomDB, unit, "Custom", "HARMFUL", customTypedEnabled and hasSourceBlacklist, typedOtherFilters, sortMethod, sortDirection, layout)
		ConfigureAuraGroup(CustomAuraContainer, "CustomBuffsSpellIDs", "HELPFUL", CustomDB, unit, "Custom", "HELPFUL", CustomDB.Enabled and customAuraFilter == "HELPFUL" and hasSpellIDs and whitelistSpellIDs.Any, GetCandidateFilters(CustomDB, "HELPFUL", nil, whitelistSpellIDs and whitelistSpellIDs.Any, blacklistSpellIDs and blacklistSpellIDs.Any), sortMethod, sortDirection, layout)
		ConfigureAuraGroup(CustomAuraContainer, "CustomBuffsSpellIDsPlayer", "HELPFUL|PLAYER", CustomDB, unit, "Custom", "HELPFUL", CustomDB.Enabled and customAuraFilter == "HELPFUL" and hasSpellIDs and whitelistSpellIDs.Player, GetCandidateFilters(CustomDB, "HELPFUL", nil, whitelistSpellIDs and whitelistSpellIDs.Player, blacklistSpellIDs and blacklistSpellIDs.Player), sortMethod, sortDirection, layout)
		ConfigureAuraGroup(CustomAuraContainer, "CustomBuffsSpellIDsOther", "HELPFUL|!PLAYER", CustomDB, unit, "Custom", "HELPFUL", CustomDB.Enabled and customAuraFilter == "HELPFUL" and hasSpellIDs and whitelistSpellIDs.Other, GetCandidateFilters(CustomDB, "HELPFUL", nil, whitelistSpellIDs and whitelistSpellIDs.Other, blacklistSpellIDs and blacklistSpellIDs.Other), sortMethod, sortDirection, layout)
		ConfigureAuraGroup(CustomAuraContainer, "CustomDebuffsSpellIDs", "HARMFUL", CustomDB, unit, "Custom", "HARMFUL", CustomDB.Enabled and customAuraFilter == "HARMFUL" and hasSpellIDs and whitelistSpellIDs.Any, GetCandidateFilters(CustomDB, "HARMFUL", nil, whitelistSpellIDs and whitelistSpellIDs.Any, blacklistSpellIDs and blacklistSpellIDs.Any), sortMethod, sortDirection, layout)
		ConfigureAuraGroup(CustomAuraContainer, "CustomDebuffsSpellIDsPlayer", "HARMFUL|PLAYER", CustomDB, unit, "Custom", "HARMFUL", CustomDB.Enabled and customAuraFilter == "HARMFUL" and hasSpellIDs and whitelistSpellIDs.Player, GetCandidateFilters(CustomDB, "HARMFUL", nil, whitelistSpellIDs and whitelistSpellIDs.Player, blacklistSpellIDs and blacklistSpellIDs.Player), sortMethod, sortDirection, layout)
		ConfigureAuraGroup(CustomAuraContainer, "CustomDebuffsSpellIDsOther", "HARMFUL|!PLAYER", CustomDB, unit, "Custom", "HARMFUL", CustomDB.Enabled and customAuraFilter == "HARMFUL" and hasSpellIDs and whitelistSpellIDs.Other, GetCandidateFilters(CustomDB, "HARMFUL", nil, whitelistSpellIDs and whitelistSpellIDs.Other, blacklistSpellIDs and blacklistSpellIDs.Other), sortMethod, sortDirection, layout)
		for _, filterGroup in ipairs(AuraFilterGroups) do
			local enabled = CustomDB.Enabled and hasFilters and CustomDB.Filters and CustomDB.Filters[filterGroup.Key] and (not filterGroup.Player or filterGroup.Key == "Player" or not CustomDB.Filters.Player)
			ConfigureAuraGroup(CustomAuraContainer, "CustomBuffs" .. filterGroup.Key, "HELPFUL|" .. filterGroup.Filter, CustomDB, unit, "Custom", "HELPFUL", customAuraFilter == "HELPFUL" and enabled, filterGroup.Player and buffPlayerCandidateFilters or buffOtherCandidateFilters, sortMethod, sortDirection, layout)
			ConfigureAuraGroup(CustomAuraContainer, "CustomDebuffs" .. filterGroup.Key, "HARMFUL|" .. filterGroup.Filter, CustomDB, unit, "Custom", "HARMFUL", customAuraFilter == "HARMFUL" and enabled, filterGroup.Player and debuffPlayerCandidateFilters or debuffOtherCandidateFilters, sortMethod, sortDirection, layout)
		end
		if CustomAuraContainer.UUFButtons then
			for _, button in ipairs(CustomAuraContainer.UUFButtons) do
				StyleAuras(CustomAuraContainer, button, unit, button.UUFAuraType, true, button.UUFAuraKey)
			end
		end
		CustomAuraContainer:SetEnabled(CustomDB.Enabled and not UUF.AURA_TEST_MODE)
		if CustomDB.Enabled then
			CustomAuraContainer:Show()
			if not UUF.AURA_TEST_MODE then CustomAuraContainer:UpdateAllAuras() end
		else
			CustomAuraContainer:Hide()
		end
	end
	if UUF.AURA_TEST_MODE then element:SetTestMode(unit) end
end

local function Path(self, ...)
	return (self.UUFAuras.Override or Update) (self, ...)
end

local function ForceUpdate(element)
	return Path(element.__owner, "ForceUpdate", element.UUFUnit or element.__owner.unit)
end

local function SetTestMode(element, unit, skipLiveUpdate)
	if not element or not element.__owner then return end
	unit = unit or element.UUFUnit or element.__owner.unit

	local UnitDB = UUF.db.profile.Units[UUF:GetNormalizedUnit(unit)]
	local AurasDB = UnitDB and UnitDB.Auras
	if not AurasDB then return end

	if not element.BuffContainer then element.BuffContainer = CreateAuraContainer(element.__owner, unit, "BuffsContainer") end
	if not element.DebuffContainer then element.DebuffContainer = CreateAuraContainer(element.__owner, unit, "DebuffsContainer") end
	if AurasDB.Custom and not element.CustomAuraContainer then element.CustomAuraContainer = CreateAuraContainer(element.__owner, unit, "CustomAurasContainer") end
	element.__owner.BuffContainer = element.BuffContainer
	element.__owner.DebuffContainer = element.DebuffContainer
	if element.CustomAuraContainer then element.__owner.CustomAuraContainer = element.CustomAuraContainer end
	if UUF.AURA_TEST_MODE then
		if element.BuffContainer then element.BuffContainer:SetEnabled(false) end
		if element.DebuffContainer then element.DebuffContainer:SetEnabled(false) end
		if element.CustomAuraContainer then element.CustomAuraContainer:SetEnabled(false) end
		CreateTestAuraButtons(element.BuffContainer, element.__owner, unit, AurasDB.Buffs, 135769, AurasDB.FrameStrata)
		CreateTestAuraButtons(element.DebuffContainer, element.__owner, unit, AurasDB.Debuffs, 135768, AurasDB.FrameStrata)
		if AurasDB.Custom then CreateTestAuraButtons(element.CustomAuraContainer, element.__owner, unit, AurasDB.Custom, GetCustomAuraFilter(AurasDB.Custom) == "HARMFUL" and 135768 or 135769, AurasDB.FrameStrata) end
		return
	end

	HideFakeAuras(element.BuffContainer)
	HideFakeAuras(element.DebuffContainer)
	HideFakeAuras(element.CustomAuraContainer)
	if skipLiveUpdate then
		if element.BuffContainer then element.BuffContainer:SetEnabled(false) element.BuffContainer:Hide() end
		if element.DebuffContainer then element.DebuffContainer:SetEnabled(false) element.DebuffContainer:Hide() end
		if element.CustomAuraContainer then element.CustomAuraContainer:SetEnabled(false) element.CustomAuraContainer:Hide() end
		return
	end
	element:ForceUpdate()
end

local function Enable(self, unit)
	local element = self.UUFAuras
	if not element or not LoadAuraContainer() then return end

	element.__owner = self
	element.ForceUpdate = ForceUpdate
	element.SetTestMode = SetTestMode
	element.UUFUnit = element.UUFUnit or unit
	element:Show()

	Update(self, "OnEnable", element.UUFUnit)
	return true
end

local function Disable(self)
	local element = self.UUFAuras
	if not element then return end

	if element.BuffContainer then
		UnregisterAuraRefreshEvent(element.BuffContainer)
		element.BuffContainer:SetEnabled(false)
		element.BuffContainer:Hide()
	end
	if element.DebuffContainer then
		UnregisterAuraRefreshEvent(element.DebuffContainer)
		element.DebuffContainer:SetEnabled(false)
		element.DebuffContainer:Hide()
	end
	if element.CustomAuraContainer then
		UnregisterAuraRefreshEvent(element.CustomAuraContainer)
		element.CustomAuraContainer:SetEnabled(false)
		element.CustomAuraContainer:Hide()
	end
	element:Hide()
end

oUF:AddElement("UUFAuras", Path, Enable, Disable)
