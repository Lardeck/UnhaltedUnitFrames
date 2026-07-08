local _, UUF = ...

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

local function RegisterAuraRefreshEvent(container, unit)
	if not container then return end
	local event = unit == "target" and "PLAYER_TARGET_CHANGED" or unit == "focus" and "PLAYER_FOCUS_CHANGED"
	if not event or container.UUFAuraRefreshEvent == event then return end
	if container.UUFAuraRefreshEvent then AuraRefreshContainers[container.UUFAuraRefreshEvent][container] = nil end
	AuraRefreshContainers[event][container] = true
	container.UUFAuraRefreshEvent = event
	AuraRefreshEventFrame:RegisterEvent(event)
end

local function GetAuraSorting(sorting)
	if sorting == "BLIZZARD_REVERSED" then
		return AuraContainerSortMethod.Default, AuraContainerSortDirection.Reverse
	elseif sorting == "DURATION" then
		return AuraContainerSortMethod.ExpirationOnly, AuraContainerSortDirection.Normal
	elseif sorting == "DURATION_REVERSED" then
		return AuraContainerSortMethod.ExpirationOnly, AuraContainerSortDirection.Reverse
	end
	return AuraContainerSortMethod.Default, AuraContainerSortDirection.Normal
end

local function GetAuraCandidateFilters(AuraDB, auraType, typed, spellIDs)
	local candidateFilters
	if AuraDB.Blacklist then
		candidateFilters = candidateFilters or {}
		candidateFilters.excludeSpellIDs = UUF.AURA_BLACKLIST
	end
	if AuraDB.OnlyShowPlayer then
		candidateFilters = candidateFilters or {}
		candidateFilters.isFromPlayerOrPlayerPet = true
	end
	if typed and auraType == "HARMFUL" then
		candidateFilters = candidateFilters or {}
		candidateFilters.includeDispelTypes = TypedDebuffTypes
	end
	if spellIDs then
		candidateFilters = candidateFilters or {}
		candidateFilters.includeSpellIDs = spellIDs
	end
	return candidateFilters
end

local function HasSpellIDs(AuraDB)
	return AuraDB.SpellIDs and next(AuraDB.SpellIDs) ~= nil
end

local function StyleAuras(_, button, unit, auraType, _, auraDB)
	if not button then return end
	unit = unit or button.UUFUnit
	auraType = auraType or button.UUFAuraType
	auraDB = auraDB or button.UUFAuraDB
	if not unit or not auraType then return end

	local UnitDB = UUF.db.profile.Units[UUF:GetNormalizedUnit(unit)]
	local AurasDB = UnitDB and UnitDB.Auras
	if not AurasDB then return end
	local AuraDB = auraDB and AurasDB[auraDB] or auraType == "HELPFUL" and AurasDB.Buffs or AurasDB.Debuffs
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

local function InitializeAuraButton(container, button, unit, auraDB, auraType)
	if not button.UUFBorder then
		button.UUFBorder = CreateFrame("Frame", nil, button, "BackdropTemplate")
		button.UUFBorder:SetAllPoints()
		button.UUFBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, insets = {left = 0, right = 0, top = 0, bottom = 0} })
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

	button.UUFUnit = unit
	button.UUFAuraDB = auraDB
	button.UUFAuraType = auraType
	container.UUFButtons = container.UUFButtons or {}
	container.UUFButtonRegistry = container.UUFButtonRegistry or {}
	if not container.UUFButtonRegistry[button] then
		container.UUFButtonRegistry[button] = true
		container.UUFButtons[#container.UUFButtons + 1] = button
	end
	StyleAuras(container, button, unit, auraType, nil, auraDB)
end

local function AddAuraGroup(container, groupKey, filterString, unit, auraDB, auraType, maxFrameCount, candidateFilters, sortMethod, sortDirection, layout)
	container:AddAuraGroup(groupKey, filterString, {
		maxFrameCount = maxFrameCount,
		candidateFilters = candidateFilters,
		sortMethod = sortMethod,
		sortDirection = sortDirection,
		layout = layout,
		initializeFrame = function(button) InitializeAuraButton(container, button, unit, auraDB, auraType) end,
	})
end

local function ConfigureAuraGroup(container, groupKey, filterString, AuraDB, unit, auraDB, auraType, enabled, candidateFilters, sortMethod, sortDirection, layout)
	if not enabled then
		if container:HasAuraGroup(groupKey) then container:SetAuraGroupMaxFrameCount(groupKey, 0) end
		return
	end

	local maxFrameCount = AuraDB.Num or 0
	if not container:HasAuraGroup(groupKey) then
		AddAuraGroup(container, groupKey, filterString, unit, auraDB, auraType, maxFrameCount, candidateFilters, sortMethod, sortDirection, layout)
		return
	end

	container:SetAuraGroupMaxFrameCount(groupKey, maxFrameCount)
	container:SetAuraGroupCandidateFilters(groupKey, candidateFilters)
	container:SetAuraGroupSortMethod(groupKey, sortMethod, sortDirection)
	container:SetAuraGroupLayout(groupKey, layout)
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

UUF.StyleAuras = StyleAuras
UUF.FilterAura = function() return true end

function UUF:GetCustomAuraFilter(CustomDB)
	return CustomDB and CustomDB.Type == "Debuffs" and "HARMFUL" or "HELPFUL"
end

function UUF:UpdateUnitAuras(unitFrame, unit)
	if not unit or not unitFrame then return end
	local UnitDB = UUF.db.profile.Units[UUF:GetNormalizedUnit(unit)]
	local AurasDB = UnitDB and UnitDB.Auras
	if not AurasDB then return end
	local BuffsDB = AurasDB.Buffs
	local DebuffsDB = AurasDB.Debuffs
	local CustomDB = AurasDB.Custom
	BuffsDB.Filter = "HELPFUL"
	DebuffsDB.Filter = "HARMFUL"
	if CustomDB then CustomDB.Filter = UUF:GetCustomAuraFilter(CustomDB) end
	if not unitFrame.BuffContainer or not unitFrame.DebuffContainer or (CustomDB and not unitFrame.CustomAuraContainer) then
		UUF:CreateUnitAuras(unitFrame, unit)
		return
	end

	unitFrame.Buffs = nil
	unitFrame.Debuffs = nil
	unitFrame.CustomAuras = nil
	unitFrame.PrivateAuras = nil

	local auraUnit = unit == "partyplayer" and "player" or unit
	local spacing = BuffsDB.Layout[5] or 0
	local perRow = math.max(BuffsDB.Wrap or 1, 1)
	local rows = math.max(math.ceil((BuffsDB.Num or 0) / perRow), 1)
	local sortMethod, sortDirection = GetAuraSorting(BuffsDB.Sorting)
	local buffCandidateFilters = GetAuraCandidateFilters(BuffsDB, "HELPFUL")
	local hasBuffSpellIDs = HasSpellIDs(BuffsDB) and not BuffsDB.OnlyShowPlayer
	local buffSpellIDCandidateFilters = hasBuffSpellIDs and GetAuraCandidateFilters(BuffsDB, "HELPFUL", nil, BuffsDB.SpellIDs) or nil
	local buffLayout = { elementSpacingX = spacing, elementSpacingY = spacing, elementWidth = BuffsDB.Size, elementHeight = BuffsDB.Size }
	local hasBuffFilters = hasBuffSpellIDs
	if BuffsDB.Filters and not BuffsDB.OnlyShowPlayer then
		for _, filterGroup in ipairs(AuraFilterGroups) do
			if BuffsDB.Filters[filterGroup.Key] then
				hasBuffFilters = true
				break
			end
		end
	end

	unitFrame.BuffContainer:SetUnit(auraUnit)
	unitFrame.BuffContainer:ClearAllPoints()
	unitFrame.BuffContainer:SetPoint(BuffsDB.Layout[1], unitFrame, BuffsDB.Layout[2], BuffsDB.Layout[3], BuffsDB.Layout[4])
	unitFrame.BuffContainer:SetFrameStrata(AurasDB.FrameStrata)
	unitFrame.BuffContainer:SetSize(math.max((BuffsDB.Size * perRow) + (spacing * (perRow - 1)), 1), math.max((BuffsDB.Size * rows) + (spacing * (rows - 1)), 1))
	unitFrame.BuffContainer:SetAuraLayoutAnchorPoint(BuffsDB.Layout[1])
	unitFrame.BuffContainer:SetAuraLayoutGrowthDirection(BuffsDB.GrowthDirection == "LEFT" and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right, BuffsDB.WrapDirection == "UP" and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
	unitFrame.BuffContainer:SetAuraLayoutRowWidth(math.max((BuffsDB.Size * perRow) + (spacing * (perRow - 1)), 1))
	ConfigureAuraGroup(unitFrame.BuffContainer, "Buffs", "HELPFUL", BuffsDB, unit, "Buffs", "HELPFUL", BuffsDB.Enabled and not hasBuffFilters, buffCandidateFilters, sortMethod, sortDirection, buffLayout)
	ConfigureAuraGroup(unitFrame.BuffContainer, "BuffsSpellIDs", "HELPFUL", BuffsDB, unit, "Buffs", "HELPFUL", BuffsDB.Enabled and hasBuffSpellIDs, buffSpellIDCandidateFilters, sortMethod, sortDirection, buffLayout)
	for _, filterGroup in ipairs(AuraFilterGroups) do
		local groupKey = "Buffs" .. filterGroup.Key
		local filterEnabled = BuffsDB.Enabled and hasBuffFilters and BuffsDB.Filters and BuffsDB.Filters[filterGroup.Key] and (not filterGroup.Player or filterGroup.Key == "Player" or not BuffsDB.Filters.Player)
		ConfigureAuraGroup(unitFrame.BuffContainer, groupKey, "HELPFUL|" .. filterGroup.Filter, BuffsDB, unit, "Buffs", "HELPFUL", filterEnabled, buffCandidateFilters, sortMethod, sortDirection, buffLayout)
	end
	if unitFrame.BuffContainer.UUFButtons then for _, button in ipairs(unitFrame.BuffContainer.UUFButtons) do StyleAuras(unitFrame.BuffContainer, button, unit, "HELPFUL", nil, "Buffs") end end
	unitFrame.BuffContainer:SetEnabled(BuffsDB.Enabled and not UUF.AURA_TEST_MODE)
	if BuffsDB.Enabled then
		unitFrame.BuffContainer:Show()
		if not UUF.AURA_TEST_MODE then unitFrame.BuffContainer:UpdateAllAuras() end
	else
		unitFrame.BuffContainer:Hide()
	end

	spacing = DebuffsDB.Layout[5] or 0
	perRow = math.max(DebuffsDB.Wrap or 1, 1)
	rows = math.max(math.ceil((DebuffsDB.Num or 0) / perRow), 1)
	sortMethod, sortDirection = GetAuraSorting(DebuffsDB.Sorting)
	local debuffCandidateFilters = GetAuraCandidateFilters(DebuffsDB, "HARMFUL")
	local typedDebuffCandidateFilters = GetAuraCandidateFilters(DebuffsDB, "HARMFUL", true)
	local hasDebuffSpellIDs = HasSpellIDs(DebuffsDB) and not DebuffsDB.OnlyShowPlayer
	local debuffSpellIDCandidateFilters = hasDebuffSpellIDs and GetAuraCandidateFilters(DebuffsDB, "HARMFUL", nil, DebuffsDB.SpellIDs) or nil
	local debuffLayout = { elementSpacingX = spacing, elementSpacingY = spacing, elementWidth = DebuffsDB.Size, elementHeight = DebuffsDB.Size }
	local hasDebuffFilters = hasDebuffSpellIDs
	if DebuffsDB.Filters and not DebuffsDB.OnlyShowPlayer then
		if DebuffsDB.Filters.Typed then hasDebuffFilters = true end
		for _, filterGroup in ipairs(AuraFilterGroups) do
			if DebuffsDB.Filters[filterGroup.Key] then
				hasDebuffFilters = true
				break
			end
		end
	end

	unitFrame.DebuffContainer:SetUnit(auraUnit)
	unitFrame.DebuffContainer:ClearAllPoints()
	unitFrame.DebuffContainer:SetPoint(DebuffsDB.Layout[1], unitFrame, DebuffsDB.Layout[2], DebuffsDB.Layout[3], DebuffsDB.Layout[4])
	unitFrame.DebuffContainer:SetFrameStrata(AurasDB.FrameStrata)
	unitFrame.DebuffContainer:SetSize(math.max((DebuffsDB.Size * perRow) + (spacing * (perRow - 1)), 1), math.max((DebuffsDB.Size * rows) + (spacing * (rows - 1)), 1))
	unitFrame.DebuffContainer:SetAuraLayoutAnchorPoint(DebuffsDB.Layout[1])
	unitFrame.DebuffContainer:SetAuraLayoutGrowthDirection(DebuffsDB.GrowthDirection == "LEFT" and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right, DebuffsDB.WrapDirection == "UP" and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
	unitFrame.DebuffContainer:SetAuraLayoutRowWidth(math.max((DebuffsDB.Size * perRow) + (spacing * (perRow - 1)), 1))
	ConfigureAuraGroup(unitFrame.DebuffContainer, "Debuffs", "HARMFUL", DebuffsDB, unit, "Debuffs", "HARMFUL", DebuffsDB.Enabled and not hasDebuffFilters, debuffCandidateFilters, sortMethod, sortDirection, debuffLayout)
	ConfigureAuraGroup(unitFrame.DebuffContainer, "DebuffsTyped", "HARMFUL", DebuffsDB, unit, "Debuffs", "HARMFUL", DebuffsDB.Enabled and DebuffsDB.Filters and DebuffsDB.Filters.Typed and not DebuffsDB.OnlyShowPlayer, typedDebuffCandidateFilters, sortMethod, sortDirection, debuffLayout)
	ConfigureAuraGroup(unitFrame.DebuffContainer, "DebuffsSpellIDs", "HARMFUL", DebuffsDB, unit, "Debuffs", "HARMFUL", DebuffsDB.Enabled and hasDebuffSpellIDs, debuffSpellIDCandidateFilters, sortMethod, sortDirection, debuffLayout)
	for _, filterGroup in ipairs(AuraFilterGroups) do
		local groupKey = "Debuffs" .. filterGroup.Key
		local filterEnabled = DebuffsDB.Enabled and hasDebuffFilters and DebuffsDB.Filters and DebuffsDB.Filters[filterGroup.Key] and (not filterGroup.Player or filterGroup.Key == "Player" or not DebuffsDB.Filters.Player)
		ConfigureAuraGroup(unitFrame.DebuffContainer, groupKey, "HARMFUL|" .. filterGroup.Filter, DebuffsDB, unit, "Debuffs", "HARMFUL", filterEnabled, debuffCandidateFilters, sortMethod, sortDirection, debuffLayout)
	end
	if unitFrame.DebuffContainer.UUFButtons then for _, button in ipairs(unitFrame.DebuffContainer.UUFButtons) do StyleAuras(unitFrame.DebuffContainer, button, unit, "HARMFUL", nil, "Debuffs") end end
	unitFrame.DebuffContainer:SetEnabled(DebuffsDB.Enabled and not UUF.AURA_TEST_MODE)
	if DebuffsDB.Enabled then
		unitFrame.DebuffContainer:Show()
		if not UUF.AURA_TEST_MODE then unitFrame.DebuffContainer:UpdateAllAuras() end
	else
		unitFrame.DebuffContainer:Hide()
	end

	if CustomDB and unitFrame.CustomAuraContainer then
		local customAuraFilter = UUF:GetCustomAuraFilter(CustomDB)
		spacing = CustomDB.Layout[5] or 0
		perRow = math.max(CustomDB.Wrap or 1, 1)
		rows = math.max(math.ceil((CustomDB.Num or 0) / perRow), 1)
		sortMethod, sortDirection = GetAuraSorting(CustomDB.Sorting)
		local customBuffCandidateFilters = GetAuraCandidateFilters(CustomDB, "HELPFUL")
		local customDebuffCandidateFilters = GetAuraCandidateFilters(CustomDB, "HARMFUL")
		local customDebuffTypedCandidateFilters = GetAuraCandidateFilters(CustomDB, "HARMFUL", true)
		local customLayout = { elementSpacingX = spacing, elementSpacingY = spacing, elementWidth = CustomDB.Size, elementHeight = CustomDB.Size }
		local hasCustomFilters = false
		if CustomDB.Filters and not CustomDB.OnlyShowPlayer then
			if customAuraFilter == "HARMFUL" and CustomDB.Filters.Typed then hasCustomFilters = true end
			for _, filterGroup in ipairs(AuraFilterGroups) do
				if CustomDB.Filters[filterGroup.Key] then
					hasCustomFilters = true
					break
				end
			end
		end

		unitFrame.CustomAuraContainer:SetUnit(auraUnit)
		unitFrame.CustomAuraContainer:ClearAllPoints()
		unitFrame.CustomAuraContainer:SetPoint(CustomDB.Layout[1], unitFrame, CustomDB.Layout[2], CustomDB.Layout[3], CustomDB.Layout[4])
		unitFrame.CustomAuraContainer:SetFrameStrata(AurasDB.FrameStrata)
		unitFrame.CustomAuraContainer:SetSize(math.max((CustomDB.Size * perRow) + (spacing * (perRow - 1)), 1), math.max((CustomDB.Size * rows) + (spacing * (rows - 1)), 1))
		unitFrame.CustomAuraContainer:SetAuraLayoutAnchorPoint(CustomDB.Layout[1])
		unitFrame.CustomAuraContainer:SetAuraLayoutGrowthDirection(CustomDB.GrowthDirection == "LEFT" and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right, CustomDB.WrapDirection == "UP" and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
		unitFrame.CustomAuraContainer:SetAuraLayoutRowWidth(math.max((CustomDB.Size * perRow) + (spacing * (perRow - 1)), 1))
		ConfigureAuraGroup(unitFrame.CustomAuraContainer, "CustomBuffs", "HELPFUL", CustomDB, unit, "Custom", "HELPFUL", CustomDB.Enabled and customAuraFilter == "HELPFUL" and not hasCustomFilters, customBuffCandidateFilters, sortMethod, sortDirection, customLayout)
		ConfigureAuraGroup(unitFrame.CustomAuraContainer, "CustomDebuffs", "HARMFUL", CustomDB, unit, "Custom", "HARMFUL", CustomDB.Enabled and customAuraFilter == "HARMFUL" and not hasCustomFilters, customDebuffCandidateFilters, sortMethod, sortDirection, customLayout)
		ConfigureAuraGroup(unitFrame.CustomAuraContainer, "CustomDebuffsTyped", "HARMFUL", CustomDB, unit, "Custom", "HARMFUL", CustomDB.Enabled and customAuraFilter == "HARMFUL" and CustomDB.Filters and CustomDB.Filters.Typed and not CustomDB.OnlyShowPlayer, customDebuffTypedCandidateFilters, sortMethod, sortDirection, customLayout)
		for _, filterGroup in ipairs(AuraFilterGroups) do
			local buffGroupKey = "CustomBuffs" .. filterGroup.Key
			local debuffGroupKey = "CustomDebuffs" .. filterGroup.Key
			local filterEnabled = CustomDB.Enabled and hasCustomFilters and CustomDB.Filters and CustomDB.Filters[filterGroup.Key] and (not filterGroup.Player or filterGroup.Key == "Player" or not CustomDB.Filters.Player)
			ConfigureAuraGroup(unitFrame.CustomAuraContainer, buffGroupKey, "HELPFUL|" .. filterGroup.Filter, CustomDB, unit, "Custom", "HELPFUL", customAuraFilter == "HELPFUL" and filterEnabled, customBuffCandidateFilters, sortMethod, sortDirection, customLayout)
			ConfigureAuraGroup(unitFrame.CustomAuraContainer, debuffGroupKey, "HARMFUL|" .. filterGroup.Filter, CustomDB, unit, "Custom", "HARMFUL", customAuraFilter == "HARMFUL" and filterEnabled, customDebuffCandidateFilters, sortMethod, sortDirection, customLayout)
		end
		if unitFrame.CustomAuraContainer.UUFButtons then for _, button in ipairs(unitFrame.CustomAuraContainer.UUFButtons) do StyleAuras(unitFrame.CustomAuraContainer, button, unit, button.UUFAuraType, nil, "Custom") end end
		unitFrame.CustomAuraContainer:SetEnabled(CustomDB.Enabled and not UUF.AURA_TEST_MODE)
		if CustomDB.Enabled then
			unitFrame.CustomAuraContainer:Show()
			if not UUF.AURA_TEST_MODE then unitFrame.CustomAuraContainer:UpdateAllAuras() end
		else
			unitFrame.CustomAuraContainer:Hide()
		end
	end

	if UUF.AURA_TEST_MODE then UUF:CreateTestAuras(unitFrame, unit) end
end

function UUF:CreateUnitAuras(unitFrame, unit)
	if not unit or not unitFrame then return end
	if not (AuraContainerSortMethod and AuraContainerSortDirection and AuraButtonBorderStyle and AnchorUtil and AnchorUtil.FlowDirection) then
		if not AuraContainerLoaded then
			AuraContainerLoaded = true
			if C_AddOns and C_AddOns.LoadAddOn then
				pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
			elseif LoadAddOn then
				pcall(LoadAddOn, "Blizzard_AuraContainer")
			end
		end
		if not (AuraContainerSortMethod and AuraContainerSortDirection and AuraButtonBorderStyle and AnchorUtil and AnchorUtil.FlowDirection) then return end
	end

	local UnitDB = UUF.db.profile.Units[UUF:GetNormalizedUnit(unit)]
	local AurasDB = UnitDB and UnitDB.Auras
	if not AurasDB then return end
	local BuffsDB = AurasDB.Buffs
	local DebuffsDB = AurasDB.Debuffs
	local CustomDB = AurasDB.Custom
	BuffsDB.Filter = "HELPFUL"
	DebuffsDB.Filter = "HARMFUL"
	if CustomDB then CustomDB.Filter = UUF:GetCustomAuraFilter(CustomDB) end

	if not unitFrame.BuffContainer then
		unitFrame.BuffContainer = CreateFrame("AuraContainer", UUF:FetchFrameName(unit) .. "_BuffsContainer", unitFrame, "CustomAuraContainerTemplate")
		unitFrame.BuffContainer.UUFButtons = {}
		unitFrame.BuffContainer.UUFButtonRegistry = {}
		unitFrame.BuffContainer:SetEnabled(false)
		unitFrame.BuffContainer:Hide()
	end

	if not unitFrame.DebuffContainer then
		unitFrame.DebuffContainer = CreateFrame("AuraContainer", UUF:FetchFrameName(unit) .. "_DebuffsContainer", unitFrame, "CustomAuraContainerTemplate")
		unitFrame.DebuffContainer.UUFButtons = {}
		unitFrame.DebuffContainer.UUFButtonRegistry = {}
		unitFrame.DebuffContainer:SetEnabled(false)
		unitFrame.DebuffContainer:Hide()
	end

	if CustomDB and not unitFrame.CustomAuraContainer then
		unitFrame.CustomAuraContainer = CreateFrame("AuraContainer", UUF:FetchFrameName(unit) .. "_CustomAurasContainer", unitFrame, "CustomAuraContainerTemplate")
		unitFrame.CustomAuraContainer.UUFButtons = {}
		unitFrame.CustomAuraContainer.UUFButtonRegistry = {}
		unitFrame.CustomAuraContainer:SetEnabled(false)
		unitFrame.CustomAuraContainer:Hide()
	end

	RegisterAuraRefreshEvent(unitFrame.BuffContainer, unit)
	RegisterAuraRefreshEvent(unitFrame.DebuffContainer, unit)
	RegisterAuraRefreshEvent(unitFrame.CustomAuraContainer, unit)

	UUF:UpdateUnitAuras(unitFrame, unit)
end

function UUF:UpdateUnitAurasStrata(unit)
	if not unit then return end
	local normalizedUnit = UUF:GetNormalizedUnit(unit)
	local unitDB = UUF.db.profile.Units[normalizedUnit]
	if unit == "party" then
		if not unitDB or not unitDB.Auras then return end
		for index = 1, UUF.MAX_PARTY_FRAMES do
			UUF:UpdateUnitAurasStrata("party" .. index)
		end
		if UUF.PARTYPLAYER then UUF:UpdateUnitAurasStrata("partyplayer") end
		return
	end

	local unitFrame = UUF[unit:upper()]
	if not unitFrame or not unitDB or not unitDB.Auras then return end
	if unitFrame.BuffContainer then unitFrame.BuffContainer:SetFrameStrata(unitDB.Auras.FrameStrata) end
	if unitFrame.DebuffContainer then unitFrame.DebuffContainer:SetFrameStrata(unitDB.Auras.FrameStrata) end
	if unitFrame.CustomAuraContainer then unitFrame.CustomAuraContainer:SetFrameStrata(unitDB.Auras.FrameStrata) end
end

function UUF:CreateTestAuras(unitFrame, unit)
	if not unit or not unitFrame then return end
	local UnitDB = UUF.db.profile.Units[UUF:GetNormalizedUnit(unit)]
	local AurasDB = UnitDB and UnitDB.Auras
	if not AurasDB then return end
	local BuffsDB = AurasDB.Buffs
	local DebuffsDB = AurasDB.Debuffs
	local CustomDB = AurasDB.Custom

	if UUF.AURA_TEST_MODE then
		if unitFrame.BuffContainer then unitFrame.BuffContainer:SetEnabled(false) end
		if unitFrame.DebuffContainer then unitFrame.DebuffContainer:SetEnabled(false) end
		if unitFrame.CustomAuraContainer then unitFrame.CustomAuraContainer:SetEnabled(false) end
		CreateTestAuraButtons(unitFrame.BuffContainer, unitFrame, unit, BuffsDB, 135769, AurasDB.FrameStrata)
		CreateTestAuraButtons(unitFrame.DebuffContainer, unitFrame, unit, DebuffsDB, 135768, AurasDB.FrameStrata)
		if CustomDB then CreateTestAuraButtons(unitFrame.CustomAuraContainer, unitFrame, unit, CustomDB, CustomDB.Type == "Debuffs" and 135768 or 135769, AurasDB.FrameStrata) end
	else
		HideFakeAuras(unitFrame.BuffContainer)
		HideFakeAuras(unitFrame.DebuffContainer)
		HideFakeAuras(unitFrame.CustomAuraContainer)
		UUF:UpdateUnitAuras(unitFrame, unit)
	end
end
