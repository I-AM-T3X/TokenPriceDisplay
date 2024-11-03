-- Initialize saved variables if they don't exist
if not TokenPriceDisplayDB then
    TokenPriceDisplayDB = {}  -- Table for saving frame position and other settings
end

if not TokenPriceDisplaySettings then
    TokenPriceDisplaySettings = {
        frameColor = {1, 1, 1, 1},  -- Default to white using RGB 0-1
        textColor = {1, 0.82, 0, 1},  -- Default to gold color
        lastKnownPrice = nil,  -- Initialize last known price
        displayType = "text",  -- Default to text for WoW Token display
        showArrow = true,  -- Default to showing the price change arrow
        iconSize = 30,  -- Default icon size
    }
end

-- Function to save the frame's position
local function SaveFramePosition()
    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
    TokenPriceDisplayDB.point = point
    TokenPriceDisplayDB.relativePoint = relativePoint
    TokenPriceDisplayDB.xOfs = xOfs
    TokenPriceDisplayDB.yOfs = yOfs
end

-- Function to load the frame's position
local function LoadFramePosition()
    if TokenPriceDisplayDB and TokenPriceDisplayDB.point then
        frame:ClearAllPoints()  -- Clear all points first
        frame:SetPoint(TokenPriceDisplayDB.point, UIParent, TokenPriceDisplayDB.relativePoint, TokenPriceDisplayDB.xOfs, TokenPriceDisplayDB.yOfs)
    else
        frame:SetPoint("CENTER")  -- Default position
    end
end

-- Create the main display frame for the addon
frame = CreateFrame("Frame", "TokenPriceFrame", UIParent, "BackdropTemplate")
frame:SetSize(180, 30)  -- Initial size; this will be adjusted dynamically
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})

-- Call LoadFramePosition on addon load to restore the frame position
LoadFramePosition()  -- Ensure this is called right after the frame is created

-- Make the frame movable and save its position when moved
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveFramePosition()  -- Save position when the frame stops moving
end)

-- Create a font string for the label "WoW Token:"
labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
labelText:SetPoint("LEFT", frame, "LEFT", 10, 0)  -- Position the label on the left side
labelText:SetTextColor(1, 0.82, 0)  -- Gold color for the text
labelText:SetText("WoW Token:")

-- Create a font string to display the token price
priceText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
priceText:SetPoint("LEFT", labelText, "RIGHT", 5, 0)  -- Position the price text next to the label
priceText:SetTextColor(1, 1, 1)  -- White color for the price

-- Create texture for the arrow indicator
priceIndicator = frame:CreateTexture(nil, "OVERLAY")
priceIndicator:SetSize(16, 16)  -- Keep the size at 16x16
priceIndicator:SetPoint("LEFT", priceText, "RIGHT", 5, 0)  -- Adjusted position to provide more space from the price text

-- Function to add commas to large numbers
local function FormatNumberWithCommas(number)
    local formatted = tostring(number):reverse():gsub("(%d%d%d)", "%1,")
    return formatted:reverse():gsub("^,", "")
end

-- Function to adjust the frame size dynamically
local function AdjustFrameSize()
    local labelWidth = labelText:IsShown() and labelText:GetStringWidth() or 0
    local textWidth = priceText:GetStringWidth()
    local iconWidth = (priceIndicator:IsShown() and TokenPriceDisplaySettings.showArrow) and priceIndicator:GetWidth() or 0
    local padding = 20  -- Reduced padding to minimize extra space

    if TokenPriceDisplaySettings.displayType == "icon" then
        -- Adjust frame width for icon mode
        frame:SetWidth(iconWidth + textWidth + padding)
    else
        -- Adjust frame width for text mode
        frame:SetWidth(labelWidth + textWidth + iconWidth + padding + 15)
    end
end

-- Function to apply user settings
local function ApplySettings()
    local r, g, b = unpack(TokenPriceDisplaySettings.frameColor)
    frame:SetBackdropBorderColor(r, g, b, 1)

    local tr, tg, tb = unpack(TokenPriceDisplaySettings.textColor)
    labelText:SetTextColor(tr, tg, tb)

    if TokenPriceDisplaySettings.displayType == "icon" then
        labelText:Hide()
        priceIndicator:SetTexture("Interface\\Icons\\wow_token01")  -- Use WoW Token icon
        priceIndicator:SetSize(TokenPriceDisplaySettings.iconSize, TokenPriceDisplaySettings.iconSize)
        priceIndicator:SetPoint("LEFT", frame, "LEFT", 5, 0)
        priceText:ClearAllPoints()
        priceText:SetPoint("LEFT", priceIndicator, "RIGHT", 5, 0)  -- Reduce space between icon and text
        priceIndicator:Show()
    else
        labelText:SetText("WoW Token:")
        labelText:Show()
        priceText:ClearAllPoints()
        priceText:SetPoint("LEFT", labelText, "RIGHT", 5, 0)
        priceIndicator:ClearAllPoints()
        priceIndicator:SetPoint("LEFT", priceText, "RIGHT", 5, 0)
    end

    -- Show or hide the price change arrow
    if TokenPriceDisplaySettings.showArrow then
        priceIndicator:Show()
    else
        priceIndicator:Hide()
    end

    AdjustFrameSize()
end

-- Function to reset colors to default
local function ResetToDefaultColors()
    TokenPriceDisplaySettings.frameColor = {1, 1, 1, 1}  -- Reset to white
    TokenPriceDisplaySettings.textColor = {1, 0.82, 0, 1}  -- Reset to gold
    ApplySettings()
end

-- Function to show the color picker for frame or text color
local function ShowColorPicker(colorType)
    local r, g, b, a = 1, 1, 1, 1
    if colorType == "frame" then
        r, g, b, a = unpack(TokenPriceDisplaySettings.frameColor)
    elseif colorType == "text" then
        r, g, b, a = unpack(TokenPriceDisplaySettings.textColor)
    end

    local function OnColorChanged()
        local newR, newG, newB = ColorPickerFrame:GetColorRGB()
        local newA = ColorPickerFrame:GetColorAlpha() or 1

        if colorType == "frame" then
            TokenPriceDisplaySettings.frameColor = {newR, newG, newB, newA}
        elseif colorType == "text" then
            TokenPriceDisplaySettings.textColor = {newR, newG, newB, newA}
        end

        ApplySettings()
    end

    local function OnCancel()
        ApplySettings()  -- Revert to previous settings if the user cancels
    end

    -- Set up options for the color picker
    local options = {
        swatchFunc = OnColorChanged,
        opacityFunc = OnColorChanged,
        cancelFunc = OnCancel,
        hasOpacity = true,
        opacity = a,
        r = r,
        g = g,
        b = b,
    }

    -- Use the custom setup function to display the color picker
    ColorPickerFrame:SetupColorPickerAndShow(options)
end

-- Function to update the token price and indicator
local function UpdateTokenPrice()
    local price = C_WowTokenPublic.GetCurrentMarketPrice()
    if price then
        local formattedPrice = GetCoinTextureString(price)
        priceText:SetText(FormatNumberWithCommas(formattedPrice))
        AdjustFrameSize()  -- Adjust frame size after setting the text

        if TokenPriceDisplaySettings.lastKnownPrice then
            if price > TokenPriceDisplaySettings.lastKnownPrice then
                priceIndicator:SetTexture("Interface\\Icons\\wow_token01")
                priceIndicator:SetSize(TokenPriceDisplaySettings.iconSize, TokenPriceDisplaySettings.iconSize)
                priceIndicator:Show()
            elseif price < TokenPriceDisplaySettings.lastKnownPrice then
                priceIndicator:SetTexture("Interface\\Icons\\wow_token02")
                priceIndicator:SetSize(TokenPriceDisplaySettings.iconSize, TokenPriceDisplaySettings.iconSize)
                priceIndicator:Show()
            else
                priceIndicator:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                priceIndicator:Show()
            end
        end

        TokenPriceDisplaySettings.lastKnownPrice = price
    else
        priceText:SetText("N/A")
        priceIndicator:Hide()
    end
end

-- Event handler for TOKEN_MARKET_PRICE_UPDATED
local function OnEvent(self, event, ...)
    if event == "TOKEN_MARKET_PRICE_UPDATED" then
        UpdateTokenPrice()
    elseif event == "PLAYER_LOGIN" then
        LoadFramePosition()
        ApplySettings()
        UpdateTokenPrice()
    end
end

-- Register the frame to listen for events
frame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", OnEvent)

-- Request the initial market price update
C_WowTokenPublic.UpdateMarketPrice()

-- Set up an OnUpdate handler
local function OnUpdate(self, elapsed)
    self.timeSinceLastUpdate = (self.timeSinceLastUpdate or 0) + elapsed
    if self.timeSinceLastUpdate >= 300 then
        C_WowTokenPublic.UpdateMarketPrice()
        self.timeSinceLastUpdate = 0
    end
end

frame:SetScript("OnUpdate", OnUpdate)

-- Settings Panel for Interface Options
local settingsPanel = CreateFrame("FRAME", "TokenPriceDisplaySettingsPanel", UIParent)
settingsPanel.name = "Token Price Display"
settingsPanel:SetSize(400, 500)

local title = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Token Price Display Settings")

-- Frame Color Picker Button
local frameColorButton = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
frameColorButton:SetSize(150, 30)
frameColorButton:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
frameColorButton:SetText("Change Frame Color")
frameColorButton:SetNormalFontObject("GameFontHighlight")
frameColorButton:SetScript("OnClick", function() ShowColorPicker("frame") end)

-- Text Color Picker Button
local textColorButton = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
textColorButton:SetSize(150, 30)
textColorButton:SetPoint("TOPLEFT", frameColorButton, "BOTTOMLEFT", 0, -10)
textColorButton:SetText("Change Text Color")
textColorButton:SetNormalFontObject("GameFontHighlight")
textColorButton:SetScript("OnClick", function() ShowColorPicker("text") end)

-- Reset to Default Button
local resetButton = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
resetButton:SetSize(150, 30)
resetButton:SetPoint("TOPLEFT", textColorButton, "BOTTOMLEFT", 0, -10)
resetButton:SetText("Reset to Default")
resetButton:SetNormalFontObject("GameFontHighlight")
resetButton:SetScript("OnClick", function() ResetToDefaultColors() end)

-- Display Type Checkbox
local displayTypeCheckbox = CreateFrame("CheckButton", nil, settingsPanel, "InterfaceOptionsCheckButtonTemplate")
displayTypeCheckbox:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -20)
displayTypeCheckbox.Text:SetText("Use Icon for WoW Token Display")
displayTypeCheckbox:SetChecked(TokenPriceDisplaySettings.displayType == "icon")
displayTypeCheckbox:SetScript("OnClick", function(self)
    TokenPriceDisplaySettings.displayType = self:GetChecked() and "icon" or "text"
    ApplySettings()
end)

-- Arrow Visibility Checkbox
local arrowCheckbox = CreateFrame("CheckButton", nil, settingsPanel, "InterfaceOptionsCheckButtonTemplate")
arrowCheckbox:SetPoint("TOPLEFT", displayTypeCheckbox, "BOTTOMLEFT", 0, -20)
arrowCheckbox.Text:SetText("Show Price Change Arrow")
arrowCheckbox:SetChecked(TokenPriceDisplaySettings.showArrow)
arrowCheckbox:SetScript("OnClick", function(self)
    TokenPriceDisplaySettings.showArrow = self:GetChecked()
    ApplySettings()
end)

-- Icon Size Slider
local iconSizeSlider = CreateFrame("Slider", nil, settingsPanel, "OptionsSliderTemplate")
iconSizeSlider:SetOrientation('HORIZONTAL')
iconSizeSlider:SetSize(200, 15)
iconSizeSlider:SetPoint("TOPLEFT", arrowCheckbox, "BOTTOMLEFT", 0, -40)
iconSizeSlider:SetMinMaxValues(10, 50)
iconSizeSlider:SetValue(TokenPriceDisplaySettings.iconSize)
iconSizeSlider:SetValueStep(1)
iconSizeSlider.Text = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
iconSizeSlider.Text:SetPoint("TOP", iconSizeSlider, "BOTTOM", 0, -5)
iconSizeSlider.Text:SetText("Icon Size: " .. TokenPriceDisplaySettings.iconSize)
iconSizeSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    TokenPriceDisplaySettings.iconSize = value
    iconSizeSlider.Text:SetText("Icon Size: " .. value)
    ApplySettings()
end)

-- Acknowledgements Header
local ackHeader = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
ackHeader:SetPoint("TOPLEFT", iconSizeSlider, "BOTTOMLEFT", 0, -20)
ackHeader:SetTextColor(1, 0.82, 0)  -- Gold color
ackHeader:SetText("Acknowledgements")

-- Individual Acknowledgements
local ackTomcat = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ackTomcat:SetPoint("TOPLEFT", ackHeader, "BOTTOMLEFT", 0, -10)
ackTomcat:SetTextColor(1, 0.82, 0)  -- Gold color
ackTomcat:SetJustifyH("LEFT")
ackTomcat:SetText("Tomcat of Tomcat Tours: For your invaluable help with the API.")

local ackPirateSoftware = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ackPirateSoftware:SetPoint("TOPLEFT", ackTomcat, "BOTTOMLEFT", 0, -10)
ackPirateSoftware:SetTextColor(1, 0.82, 0)  -- Gold color
ackPirateSoftware:SetJustifyH("LEFT")
ackPirateSoftware:SetText("PirateSoftware: For encouraging me to learn coding.")

local ackPersephonae = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ackPersephonae:SetPoint("TOPLEFT", ackPirateSoftware, "BOTTOMLEFT", 0, -10)
ackPersephonae:SetTextColor(1, 0.82, 0)  -- Gold color
ackPersephonae:SetJustifyH("LEFT")
ackPersephonae:SetText("Persephonae: For suggesting the idea for this addon.")

-- Register the panel with the Interface Options
local category = Settings.RegisterCanvasLayoutCategory(settingsPanel, settingsPanel.name)
Settings.RegisterAddOnCategory(category)

local function ToggleSettings()
    Settings.OpenToCategory(category:GetID())
end

-- Slash command to open settings
SLASH_TOKENPRICEDISPLAY1 = "/tpd"
SlashCmdList["TOKENPRICEDISPLAY"] = function(msg)
    if msg == "settings" then
        ToggleSettings()
    else
        print("Token Price Display commands:")
        print("/tpd settings - Open the settings window")
    end
end
