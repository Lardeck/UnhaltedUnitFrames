local _, UUF = ...

local function EnsureAuraElement(unitFrame, unit)
	if not unitFrame.UUFAuras then
		unitFrame.UUFAuras = CreateFrame("Frame", UUF:FetchFrameName(unit) .. "_Auras", unitFrame)
		unitFrame.UUFAuras:SetAllPoints(unitFrame)
		unitFrame.UUFAuras.UUFUnit = unit
		unitFrame.UUFAuras:Hide()
	end
	unitFrame.Buffs = nil
	unitFrame.Debuffs = nil
	unitFrame.CustomAuras = nil
	unitFrame.PrivateAuras = nil
	return unitFrame.UUFAuras
end

function UUF:CreateUnitAuras(unitFrame, unit)
	if not unit or not unitFrame then return end
	EnsureAuraElement(unitFrame, unit)
end

function UUF:UpdateUnitAuras(unitFrame, unit)
	if not unit or not unitFrame then return end
	local auraElement = EnsureAuraElement(unitFrame, unit)
	auraElement.UUFUnit = unit
	if unitFrame:IsElementEnabled("UUFAuras") then
		auraElement:ForceUpdate()
	else
		unitFrame:EnableElement("UUFAuras", unit)
	end
	if UUF.AURA_TEST_MODE then UUF:CreateTestAuras(unitFrame, unit) end
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

function UUF:CreateTestAuras(unitFrame, unit, skipLiveUpdate)
	if not unit or not unitFrame then return end
	local auraElement = EnsureAuraElement(unitFrame, unit)
	auraElement.UUFUnit = unit
	if not unitFrame:IsElementEnabled("UUFAuras") then unitFrame:EnableElement("UUFAuras", unit) end
	if auraElement.SetTestMode then auraElement:SetTestMode(unit, skipLiveUpdate) end
end
