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

local SCROLL_GUTTER = 3

local function FixScrollFrame(widget)
	if widget.updateLock then return end
	widget.updateLock = true
	local status = widget.status or widget.localstatus
	local contentHeight = widget.content:GetHeight()
	local scrollFrameHeight = widget.scrollframe:GetHeight()
	local scrollable = contentHeight > scrollFrameHeight + 2
	widget.scrollBarShown = scrollable or nil
	widget.scrollbar:SetShown(scrollable)
	if scrollable then widget.scrollbar.ThumbTexture:SetHeight(math.max(widget.scrollbar:GetHeight() * scrollFrameHeight / contentHeight, 24)) end
	widget.scrollbar:SetValue(scrollable and (status.scrollvalue or 0) or 0)
	widget:SetScroll(scrollable and (status.scrollvalue or 0) or 0)
	widget.updateLock = nil
end

local function SetScrollFrameWidth(widget, width)
	widget.content.width = math.max(width - SCROLL_GUTTER, 0)
	widget.content.original_width = width
	widget.scrollframe:SetPoint("BOTTOMRIGHT", -SCROLL_GUTTER, 0)
end

local function StyleScrollFrame(widget)
	if widget.UUFMinimalScrollBar then return end
	local scrollBar = widget.scrollbar
	scrollBar.ScrollUpButton:Hide()
	scrollBar.ScrollDownButton:Hide()
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPRIGHT", widget.frame, "TOPRIGHT")
	scrollBar:SetPoint("BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT")
	scrollBar:SetWidth(SCROLL_GUTTER)
	scrollBar:SetHitRectInsets(-4, -4, 0, 0)
	scrollBar:SetFrameLevel(widget.frame:GetFrameLevel() + 2)
	scrollBar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
	scrollBar.ThumbTexture:SetWidth(SCROLL_GUTTER)
	scrollBar.ThumbTexture:SetTexCoord(0, 1, 0, 1)
	scrollBar.ThumbTexture:SetColorTexture(0.5, 0.5, 1, 0.85)
	local scrollTrack = scrollBar:CreateTexture(nil, "BACKGROUND")
	scrollTrack:SetAllPoints()
	scrollTrack:SetColorTexture(1, 1, 1, 0.12)
	widget.UUFMinimalScrollBar = true
end

local function CreateScrollFrame(containerParent)
    local scrollFrame = AG:Create("ScrollFrame")
	StyleScrollFrame(scrollFrame)
	scrollFrame.FixScroll = FixScrollFrame
	scrollFrame.OnWidthSet = SetScrollFrameWidth
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
