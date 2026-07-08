local _, UUF = ...

local AuraContainerLoaded
local TypedDebuffTypes = {
	Magic = true,
	Curse = true,
	Disease = true,
	Poison = true,
	Bleed = true,
}

local function EnsureAuraContainer()
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

local function GetAuraUnit(unit)
	return unit == "partyplayer" and "player" or unit
end

local function GetCustomAuraType(CustomDB)
	return CustomDB and CustomDB.Type == "Debuffs" and "Debuffs" or "Buffs"
end

local function GetCustomAuraFilter(CustomDB)
	return GetCustomAuraType(CustomDB) == "Buffs" and "HELPFUL" or "HARMFUL"
end

function UUF:GetCustomAuraFilter(CustomDB)
	return GetCustomAuraFilter(CustomDB)
end

local function GetAuraDB(unit, auraDB, auraType)
	local UnitDB = UUF.db.profile.Units[UUF:GetNormalizedUnit(unit)]
	local AurasDB = UnitDB and UnitDB.Auras
	if not AurasDB then return end
	if auraDB then return AurasDB[auraDB] end
	return auraType == "HELPFUL" and AurasDB.Buffs or AurasDB.Debuffs
end

local function GetAuraSort(sorting)
	if sorting == "BLIZZARD_REVERSED" then
		return AuraContainerSortMethod.Default, AuraContainerSortDirection.Reverse
	elseif sorting == "DURATION" then
		return AuraContainerSortMethod.ExpirationOnly, AuraContainerSortDirection.Normal
	elseif sorting == "DURATION_REVERSED" then
		return AuraContainerSortMethod.ExpirationOnly, AuraContainerSortDirection.Reverse
	end
	return AuraContainerSortMethod.Default, AuraContainerSortDirection.Normal
end

local function GetAuraGrowthDirections(AuraDB)
	local horizontalDirection = AuraDB.GrowthDirection == "LEFT" and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right
	local verticalDirection = AuraDB.WrapDirection == "UP" and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down
	return horizontalDirection, verticalDirection
end

local function GetAuraContainerSize(AuraDB)
	local spacing = AuraDB.Layout[5] or 0
	local perRow = math.max(AuraDB.Wrap or 1, 1)
	local rows = math.max(math.ceil((AuraDB.Num or 0) / perRow), 1)
	local width = (AuraDB.Size * perRow) + (spacing * (perRow - 1))
	local height = (AuraDB.Size * rows) + (spacing * (rows - 1))
	return math.max(width, 1), math.max(height, 1)
end

local function GetAuraRowWidth(AuraDB)
	local spacing = AuraDB.Layout[5] or 0
	local perRow = math.max(AuraDB.Wrap or 1, 1)
	return math.max((AuraDB.Size * perRow) + (spacing * (perRow - 1)), 1)
end

local function GetAuraCandidateFilters(AuraDB, auraType)
	local candidateFilters
	if AuraDB.Blacklist then
		candidateFilters = candidateFilters or {}
		candidateFilters.excludeSpellIDs = UUF.AURA_BLACKLIST
	end
	if AuraDB.OnlyShowPlayer then
		candidateFilters = candidateFilters or {}
		candidateFilters.isFromPlayerOrPlayerPet = true
	end
	if auraType == "HARMFUL" and AuraDB.Filters and AuraDB.Filters.Typed then
		candidateFilters = candidateFilters or {}
		candidateFilters.includeDispelTypes = TypedDebuffTypes
	end
	return candidateFilters
end

local function HideManagedAuraButtons(container)
	if not container or not container.UUFButtons then return end
	for _, button in ipairs(container.UUFButtons) do
		if button then button:Hide() end
	end
end

local function HideFakeAuraButtons(container)
	if not container then return end
	for index = 1, (container.maxFake or 0) do
		local button = container["fake" .. index]
		if button then button:Hide() end
	end
end

local function SetAuraContainerEnabled(container, enabled)
	if container and container.SetEnabled then container:SetEnabled(enabled == true) end
end

local function StyleAuraButton(container, button, unit, auraDB, auraType)
	if not button or not unit or not auraType then return end
	local AuraDB = GetAuraDB(unit, auraDB, auraType)
	if not AuraDB then return end

	button:SetSize(AuraDB.Size, AuraDB.Size)
	if button.Icon then
		button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
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

local function StyleAuras(_, button, unit, auraType, _, auraDB)
	StyleAuraButton(button and button:GetParent(), button, unit, auraDB, auraType)
end

local function FilterAura()
	return true
end

UUF.StyleAuras = StyleAuras
UUF.FilterAura = FilterAura

local function RegisterAuraButton(container, button, unit, auraDB, auraType)
	container.UUFButtons = container.UUFButtons or {}
	container.UUFButtonRegistry = container.UUFButtonRegistry or {}
	if not container.UUFButtonRegistry[button] then
		container.UUFButtonRegistry[button] = true
		container.UUFButtons[#container.UUFButtons + 1] = button
	end
	button.UUFAuraDB = auraDB
	button.UUFAuraType = auraType
	StyleAuraButton(container, button, unit, auraDB, auraType)
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

	RegisterAuraButton(container, button, unit, auraDB, auraType)
end

local function RestyleAuraButtons(container, unit)
	if not container or not container.UUFButtons then return end
	for _, button in ipairs(container.UUFButtons) do
		StyleAuraButton(container, button, unit, button.UUFAuraDB, button.UUFAuraType)
	end
end

local function ConfigureAuraContainerFrame(container, unitFrame, unit, AuraDB, frameStrata)
	local horizontalDirection, verticalDirection = GetAuraGrowthDirections(AuraDB)
	container:SetUnit(GetAuraUnit(unit))
	container:ClearAllPoints()
	container:SetPoint(AuraDB.Layout[1], unitFrame, AuraDB.Layout[2], AuraDB.Layout[3], AuraDB.Layout[4])
	container:SetFrameStrata(frameStrata)
	container:SetSize(GetAuraContainerSize(AuraDB))
	container:SetAuraLayoutAnchorPoint(AuraDB.Layout[1])
	container:SetAuraLayoutGrowthDirection(horizontalDirection, verticalDirection)
	container:SetAuraLayoutRowWidth(GetAuraRowWidth(AuraDB))
end

local function ConfigureAuraGroup(container, groupKey, AuraDB, auraType, enabled)
	local sortMethod, sortDirection = GetAuraSort(AuraDB.Sorting)
	local spacing = AuraDB.Layout[5] or 0
	container:SetAuraGroupMaxFrameCount(groupKey, enabled and (AuraDB.Num or 0) or 0)
	container:SetAuraGroupCandidateFilters(groupKey, GetAuraCandidateFilters(AuraDB, auraType))
	container:SetAuraGroupSortMethod(groupKey, sortMethod, sortDirection)
	container:SetAuraGroupLayout(groupKey, {
		elementSpacingX = spacing,
		elementSpacingY = spacing,
		elementWidth = AuraDB.Size,
		elementHeight = AuraDB.Size,
	})
end

local function ConfigureAuraContainer(container, unitFrame, unit, AuraDB, groupKey, auraType, frameStrata)
	if not container or not AuraDB then return end
	local enabled = AuraDB.Enabled == true
	ConfigureAuraContainerFrame(container, unitFrame, unit, AuraDB, frameStrata)
	ConfigureAuraGroup(container, groupKey, AuraDB, auraType, enabled)
	RestyleAuraButtons(container, unit)
	SetAuraContainerEnabled(container, enabled and not UUF.AURA_TEST_MODE)
	if enabled then
		container:Show()
		if not UUF.AURA_TEST_MODE and container.UpdateAllAuras then container:UpdateAllAuras() end
	else
		container:Hide()
	end
end

local function ConfigureCustomAuraContainer(container, unitFrame, unit, CustomDB, frameStrata)
	if not container or not CustomDB then return end
	local enabled = CustomDB.Enabled == true
	local customAuraFilter = GetCustomAuraFilter(CustomDB)
	ConfigureAuraContainerFrame(container, unitFrame, unit, CustomDB, frameStrata)
	ConfigureAuraGroup(container, "CustomBuffs", CustomDB, "HELPFUL", enabled and customAuraFilter == "HELPFUL")
	ConfigureAuraGroup(container, "CustomDebuffs", CustomDB, "HARMFUL", enabled and customAuraFilter == "HARMFUL")
	RestyleAuraButtons(container, unit)
	SetAuraContainerEnabled(container, enabled and not UUF.AURA_TEST_MODE)
	if enabled then
		container:Show()
		if not UUF.AURA_TEST_MODE and container.UpdateAllAuras then container:UpdateAllAuras() end
	else
		container:Hide()
	end
end

local function AddAuraGroup(container, unit, groupKey, filterString, auraDB, auraType, AuraDB)
	local sortMethod, sortDirection = GetAuraSort(AuraDB.Sorting)
	container:AddAuraGroup(groupKey, filterString, {
		maxFrameCount = 0,
		sortMethod = sortMethod,
		sortDirection = sortDirection,
		layout = {
			elementSpacingX = AuraDB.Layout[5] or 0,
			elementSpacingY = AuraDB.Layout[5] or 0,
			elementWidth = AuraDB.Size,
			elementHeight = AuraDB.Size,
		},
		initializeFrame = function(button)
			InitializeAuraButton(container, button, unit, auraDB, auraType)
		end,
	})
end

local function CreateAuraContainer(unitFrame, unit, containerName)
	local container = CreateFrame("AuraContainer", UUF:FetchFrameName(unit) .. "_" .. containerName, unitFrame, "CustomAuraContainerTemplate")
	container.UUFButtons = {}
	container.UUFButtonRegistry = {}
	SetAuraContainerEnabled(container, false)
	return container
end

function UUF:UpdateUnitAuras(unitFrame, unit)
	if not unit or not unitFrame then return end
	if not EnsureAuraContainer() then return end
	local UnitDB = UUF.db.profile.Units[UUF:GetNormalizedUnit(unit)]
	local AurasDB = UnitDB and UnitDB.Auras
	if not AurasDB then return end
	local BuffsDB = AurasDB.Buffs
	local DebuffsDB = AurasDB.Debuffs
	local CustomDB = AurasDB.Custom
	if not unitFrame.BuffContainer or not unitFrame.DebuffContainer or (CustomDB and not unitFrame.CustomAuraContainer) then
		UUF:CreateUnitAuras(unitFrame, unit)
		return
	end

	BuffsDB.Filter = "HELPFUL"
	DebuffsDB.Filter = "HARMFUL"
	if CustomDB then CustomDB.Filter = GetCustomAuraFilter(CustomDB) end

	unitFrame.Buffs = nil
	unitFrame.Debuffs = nil
	unitFrame.CustomAuras = nil
	unitFrame.PrivateAuras = nil

	ConfigureAuraContainer(unitFrame.BuffContainer, unitFrame, unit, BuffsDB, "Buffs", "HELPFUL", AurasDB.FrameStrata)
	ConfigureAuraContainer(unitFrame.DebuffContainer, unitFrame, unit, DebuffsDB, "Debuffs", "HARMFUL", AurasDB.FrameStrata)
	if CustomDB and unitFrame.CustomAuraContainer then ConfigureCustomAuraContainer(unitFrame.CustomAuraContainer, unitFrame, unit, CustomDB, AurasDB.FrameStrata) end
	if UUF.AURA_TEST_MODE then UUF:CreateTestAuras(unitFrame, unit) end
end

function UUF:CreateUnitAuras(unitFrame, unit)
	if not unit or not unitFrame then return end
	if not EnsureAuraContainer() then return end
	local UnitDB = UUF.db.profile.Units[UUF:GetNormalizedUnit(unit)]
	local AurasDB = UnitDB and UnitDB.Auras
	if not AurasDB then return end
	local BuffsDB = AurasDB.Buffs
	local DebuffsDB = AurasDB.Debuffs
	local CustomDB = AurasDB.Custom
	BuffsDB.Filter = "HELPFUL"
	DebuffsDB.Filter = "HARMFUL"
	if CustomDB then CustomDB.Filter = GetCustomAuraFilter(CustomDB) end

	if not unitFrame.BuffContainer then
		unitFrame.BuffContainer = CreateAuraContainer(unitFrame, unit, "BuffsContainer")
		AddAuraGroup(unitFrame.BuffContainer, unit, "Buffs", "HELPFUL", "Buffs", "HELPFUL", BuffsDB)
	end

	if not unitFrame.DebuffContainer then
		unitFrame.DebuffContainer = CreateAuraContainer(unitFrame, unit, "DebuffsContainer")
		AddAuraGroup(unitFrame.DebuffContainer, unit, "Debuffs", "HARMFUL", "Debuffs", "HARMFUL", DebuffsDB)
	end

	if CustomDB and not unitFrame.CustomAuraContainer then
		unitFrame.CustomAuraContainer = CreateAuraContainer(unitFrame, unit, "CustomAurasContainer")
		AddAuraGroup(unitFrame.CustomAuraContainer, unit, "CustomBuffs", "HELPFUL", "Custom", "HELPFUL", CustomDB)
		AddAuraGroup(unitFrame.CustomAuraContainer, unit, "CustomDebuffs", "HARMFUL", "Custom", "HARMFUL", CustomDB)
	end

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

local function StyleFakeAuraButton(button, unit, AuraDB)
	local General = UUF.db.profile.General
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
	if AuraDB.Count.HideStacks then button.Count:Hide() else button.Count:Show() end
	button.Duration = button.Duration or button:CreateFontString(nil, "OVERLAY")
	UUF:ApplyCooldownText(button, button.Duration, unit)
	button.Duration:SetText("10m")
end

local function CreateFakeAuraButtons(container, unitFrame, unit, AuraDB, icon, frameStrata)
	if not container then return end
	if not AuraDB.Enabled then
		HideFakeAuraButtons(container)
		container:Hide()
		return
	end

	container:ClearAllPoints()
	container:SetSize(GetAuraContainerSize(AuraDB))
	container:SetPoint(AuraDB.Layout[1], unitFrame, AuraDB.Layout[2], AuraDB.Layout[3], AuraDB.Layout[4])
	container:SetFrameStrata(frameStrata)
	container:Show()
	HideManagedAuraButtons(container)

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

		local row = math.floor((index - 1) / AuraDB.Wrap)
		local column = (index - 1) % AuraDB.Wrap
		local x = column * (AuraDB.Size + AuraDB.Layout[5])
		local y = row * (AuraDB.Size + AuraDB.Layout[5])
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
		button.Count:SetText(index)
		StyleFakeAuraButton(button, unit, AuraDB)
		button:Show()
	end

	for index = AuraDB.Num + 1, (container.maxFake or AuraDB.Num) do
		local button = container["fake" .. index]
		if button then button:Hide() end
	end
	container.maxFake = AuraDB.Num
end

function UUF:CreateTestAuras(unitFrame, unit)
	if not unit or not unitFrame then return end
	local AurasDB = UUF.db.profile.Units[UUF:GetNormalizedUnit(unit)].Auras
	if not AurasDB then return end
	local BuffsDB = AurasDB.Buffs
	local DebuffsDB = AurasDB.Debuffs
	local CustomDB = AurasDB.Custom

	if UUF.AURA_TEST_MODE then
		SetAuraContainerEnabled(unitFrame.BuffContainer, false)
		SetAuraContainerEnabled(unitFrame.DebuffContainer, false)
		SetAuraContainerEnabled(unitFrame.CustomAuraContainer, false)
		CreateFakeAuraButtons(unitFrame.BuffContainer, unitFrame, unit, BuffsDB, 135769, AurasDB.FrameStrata)
		CreateFakeAuraButtons(unitFrame.DebuffContainer, unitFrame, unit, DebuffsDB, 135768, AurasDB.FrameStrata)
		if CustomDB then CreateFakeAuraButtons(unitFrame.CustomAuraContainer, unitFrame, unit, CustomDB, CustomDB.Type == "Debuffs" and 135768 or 135769, AurasDB.FrameStrata) end
	else
		HideFakeAuraButtons(unitFrame.BuffContainer)
		HideFakeAuraButtons(unitFrame.DebuffContainer)
		HideFakeAuraButtons(unitFrame.CustomAuraContainer)
		UUF:UpdateUnitAuras(unitFrame, unit)
	end
end
