local _, UUF = ...
local AG = UUF.AG
UUF.GUIWidgets = {}

local function DeepDisable(widget, disabled, skipWidget)
    if widget == skipWidget then return end
    if widget.SetDisabled then widget:SetDisabled(disabled) end
    if widget.children then
        for _, child in ipairs(widget.children) do
            DeepDisable(child, disabled, skipWidget)
        end
    end
end

UUF.GUIWidgets.DeepDisable = DeepDisable

local function CreateInformationTag(containerParent, labelDescription, textJustification)
    local informationLabel = AG:Create("Label")
    informationLabel:SetText(UUF.INFOBUTTON .. labelDescription)
    informationLabel:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    informationLabel:SetFullWidth(true)
    informationLabel:SetJustifyH(textJustification or "CENTER")
    informationLabel:SetHeight(24)
    informationLabel:SetJustifyV("MIDDLE")
    containerParent:AddChild(informationLabel)
    return informationLabel
end

UUF.GUIWidgets.CreateInformationTag = CreateInformationTag

local function CreateScrollFrame(containerParent)
    local scrollFrame = AG:Create("ScrollFrame")
    scrollFrame:SetLayout("Flow")
    scrollFrame:SetFullWidth(true)
    containerParent:AddChild(scrollFrame)
    return scrollFrame
end

UUF.GUIWidgets.CreateScrollFrame = CreateScrollFrame

local function CreateInlineGroup(containerParent, containerTitle)
    local inlineGroup = AG:Create("InlineGroup")
    inlineGroup:SetTitle("|cFFFFFFFF" .. containerTitle .. "|r")
    inlineGroup:SetFullWidth(true)
    inlineGroup:SetLayout("Flow")
    containerParent:AddChild(inlineGroup)
    return inlineGroup
end

UUF.GUIWidgets.CreateInlineGroup = CreateInlineGroup

local function CreateHeader(containerParent, headerTitle)
    local headingText = AG:Create("Heading")
    headingText:SetText("|cFF8080FF" .. headerTitle .. "|r")
    headingText:SetFullWidth(true)
    containerParent:AddChild(headingText)
    return headingText
end

UUF.GUIWidgets.CreateHeader = CreateHeader

do
	local Type, Version = "UUFAnchorButtons", 2
	if not AG:GetWidgetVersion(Type) or AG:GetWidgetVersion(Type) < Version then
		local buttonSize, frameWidth, frameHeight, titleHeight = 12, 130, 68, 16
		local methods = {
			RefreshButtons = function(self)
				for point, button in pairs(self.buttons) do
					local selected = point == self.value
					local ContainerDB = self.configured and self.configured[point]
					local auraType = ContainerDB and ContainerDB.Type
					local red, green, blue = 0.25, 0.25, 0.25
					if selected then
						red, green, blue = 0.9, 0.9, 0.1
					elseif auraType == "Buffs" then
						red, green, blue = 0.2, 0.6, 1
					elseif auraType == "Debuffs" then
						red, green, blue = 1, 0.25, 0.25
					end
					button.texture:SetVertexColor(red, green, blue, 1)
				end
			end,
			OnAcquire = function(self)
				self:SetFullWidth(true)
				self:SetHeight(frameHeight + buttonSize + titleHeight + 4)
				self.configured = nil
				self.value = nil
				self:SetDisabled(false)
			end,
			SetValue = function(self, value)
				if not UUF.AURA_CONTAINER_SLOT_NAMES[value] then return end
				self.value = value
				self:RefreshButtons()
			end,
			GetValue = function(self) return self.value end,
			SetConfiguredSlots = function(self, configured)
				self.configured = configured
				self:RefreshButtons()
			end,
			SetLabel = function(self, text)
				self.label:SetText(text or "")
				self.label:SetShown(text and text ~= "")
			end,
			SetDisabled = function(self, disabled)
				self.disabled = disabled
				self.label:SetTextColor(disabled and 0.5 or 1, disabled and 0.5 or 0.82, disabled and 0.5 or 0)
				for _, button in pairs(self.buttons) do button:EnableMouse(not disabled) end
				self:RefreshButtons()
			end,
		}
		local function ButtonClicked(button)
			AG:ClearFocus()
			local widget = button:GetParent().obj
			widget:SetValue(button.value)
			widget:Fire("OnValueChanged", button.value)
		end
		local function ButtonEntered(button)
			local widget = button:GetParent().obj
			local ContainerDB = widget.configured and widget.configured[button.value]
			GameTooltip:SetOwner(button, "ANCHOR_CURSOR")
			GameTooltip:AddLine(UUF.AURA_CONTAINER_SLOT_NAMES[button.value], 1, 1, 1)
			GameTooltip:AddLine(ContainerDB and (ContainerDB.Type or "Aura") .. " Container" or "Empty", ContainerDB and 0.5 or 0.7, 0.7, ContainerDB and 1 or 0.7)
			GameTooltip:Show()
		end
		local function ButtonLeft() GameTooltip:Hide() end
		local function Constructor()
			local frame = CreateFrame("Frame", nil, UIParent)
			frame:SetSize(frameWidth + buttonSize, frameHeight + buttonSize + titleHeight + 4)

			local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			label:SetPoint("TOP", frame, "TOP")
			label:SetHeight(titleHeight)
			label:SetJustifyH("CENTER")

			local background = CreateFrame("Frame", nil, frame, "BackdropTemplate")
			background:SetPoint("TOP", frame, "TOP", 0, -(titleHeight + 4))
			background:SetSize(frameWidth, frameHeight)
			background:SetBackdrop(UUF.BACKDROP)
			background:SetBackdropColor(0.1, 0.1, 0.1, 0.55)
			background:SetBackdropBorderColor(1, 1, 1, 0.45)

			local buttons = {}
			for _, slot in ipairs(UUF.AURA_CONTAINER_SLOTS) do
				local button = CreateFrame("Button", nil, frame)
				button:SetSize(buttonSize, buttonSize)
				button:SetPoint("CENTER", background, slot.Key)
				button:RegisterForClicks("LeftButtonUp")
				button.value = slot.Key
				button:SetScript("OnClick", ButtonClicked)
				button:SetScript("OnEnter", ButtonEntered)
				button:SetScript("OnLeave", ButtonLeft)

				local texture = button:CreateTexture(nil, "ARTWORK")
				texture:SetAllPoints()
				texture:SetTexture("Interface\\Buttons\\WHITE8X8")
				texture:SetVertexColor(0.25, 0.25, 0.25, 1)
				button:SetNormalTexture(texture)
				button.texture = texture
				buttons[slot.Key] = button
			end

			local widget = {frame = frame, type = Type, label = label, buttons = buttons}
			for method, func in pairs(methods) do widget[method] = func end
			return AG:RegisterAsWidget(widget)
		end
		AG:RegisterWidgetType(Type, Constructor, Version)
	end
end
