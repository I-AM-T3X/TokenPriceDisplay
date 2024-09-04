-- Initialize saved variables if they don't exist
if not TokenPriceDisplayDB then
    TokenPriceDisplayDB = {}
end

if not TokenPriceDisplaySettings then
    TokenPriceDisplaySettings = {
        frameColor = {255, 255, 255, 1},  -- Default to white using RGB 0-255
        frameStyle = "Default"  -- Placeholder for different frame styles
    }
end

-- Create a frame for the addon
local frame = CreateFrame("Frame", "TokenPriceFrame", UIParent, "BackdropTemplate")
frame:SetSize(180, 30)  -- Initial size; this will be adjusted dynamically
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})

-- Function to apply user settings
local function ApplySettings()
    local r, g, b = TokenPriceDisplaySettings.frameColor[1] / 255, TokenPriceDisplaySettings.frameColor[2] / 255, TokenPriceDisplaySettings.frameColor[3] / 255
    frame:SetBackdropBorderColor(r, g, b, 1)  -- Apply the color using 0-1 range
end

-- Apply settings after frame creation
ApplySettings()

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
        frame:ClearAllPoints()
        frame:SetPoint(TokenPriceDisplayDB.point, UIParent, TokenPriceDisplayDB.relativePoint, TokenPriceDisplayDB.xOfs, TokenPriceDisplayDB.yOfs)
    else
        frame:SetPoint("CENTER")  -- Default position
    end
end

-- Make the frame movable and save its position when moved
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveFramePosition()
end)

-- Create a font string for the label "WoW Token:"
local labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
labelText:SetPoint("LEFT", frame, "LEFT", 10, 0)  -- Position the label on the left side
labelText:SetTextColor(1, 0.82, 0)  -- Gold color for the text
labelText:SetText("WoW Token:")

-- Create a font string to display the token price
local priceText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
priceText:SetPoint("LEFT", labelText, "RIGHT", 10, 0)  -- Position the price text next to the label
priceText:SetTextColor(1, 1, 1)  -- White color for the price

-- Function to update the frame size dynamically based on content width
local function UpdateFrameSize()
    local totalWidth = labelText:GetStringWidth() + priceText:GetStringWidth() + 30  -- Calculate total width needed for both texts
    frame:SetWidth(totalWidth)  -- Set the frame width dynamically
end

-- Function to update the token price
local function UpdateTokenPrice()
    local price = C_WowTokenPublic.GetCurrentMarketPrice()
    if price then
        priceText:SetText(GetCoinTextureString(price))  -- Set the text to the formatted price
    else
        priceText:SetText("N/A")  -- Set the text if price is not available
    end
    UpdateFrameSize()  -- Update the frame size based on the new content
end

-- Event handler for TOKEN_MARKET_PRICE_UPDATED
local function OnEvent(self, event, ...)
    if event == "TOKEN_MARKET_PRICE_UPDATED" then
        UpdateTokenPrice()  -- Update the price when the event is fired
    elseif event == "PLAYER_LOGIN" then
        LoadFramePosition()  -- Load the saved frame position after the player logs in
        ApplySettings()  -- Apply settings when the player logs in
    end
end

-- Register the frame to listen for events
frame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")
frame:RegisterEvent("PLAYER_LOGIN")  -- Register for PLAYER_LOGIN to ensure loading after login
frame:SetScript("OnEvent", OnEvent)

-- Request the initial market price update
C_WowTokenPublic.UpdateMarketPrice()

-- Set up an OnUpdate handler to check the price every 5 minutes (300 seconds)
local function OnUpdate(self, elapsed)
    self.timeSinceLastUpdate = (self.timeSinceLastUpdate or 0) + elapsed
    if self.timeSinceLastUpdate >= 300 then  -- 300 seconds = 5 minutes
        C_WowTokenPublic.UpdateMarketPrice()  -- Request a new market price update every 5 minutes
        self.timeSinceLastUpdate = 0
    end
end

-- Initialize the frame
frame:SetScript("OnUpdate", OnUpdate)

-- Create the settings window
local settingsFrame = CreateFrame("Frame", "TokenPriceDisplaySettingsFrame", UIParent, "BasicFrameTemplateWithInset")
settingsFrame:SetSize(350, 350)  -- Reduced height to provide more space
settingsFrame:SetPoint("CENTER")
settingsFrame:SetMovable(true)
settingsFrame:EnableMouse(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
settingsFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
settingsFrame:Hide()  -- Hide by default

-- Title for the settings frame
settingsFrame.title = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
settingsFrame.title:SetPoint("CENTER", settingsFrame.TitleBg, "CENTER", 0, 0)
settingsFrame.title:SetText("Token Price Display Settings")

-- Headline for Frame Color settings
local frameColorTitle = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frameColorTitle:SetPoint("TOP", settingsFrame, "TOP", 0, -60)  -- Further increased vertical spacing
frameColorTitle:SetText("Frame Color")

-- Function to create a slider with an editable input field
local function CreateColorSlider(parent, name, label, colorKey, colorIndex, y)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOP", parent, "TOP", 0, y)  -- Centered horizontally
    slider:SetMinMaxValues(0, 255)
    slider:SetValueStep(1)
    slider:SetValue(TokenPriceDisplaySettings[colorKey][colorIndex])
    slider:SetWidth(200)  -- Wider for better alignment

    -- Change the low and high text to "0" and "255"
    _G[name .. 'Low']:SetText('0')
    _G[name .. 'High']:SetText('255')

    -- Color label above the slider
    local sliderLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sliderLabel:SetPoint("TOP", slider, "TOP", 0, 15)  -- Adjusted to ensure no overlap
    sliderLabel:SetText(label)

    -- Editable input field below the slider
    local valueInput = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    valueInput:SetSize(50, 20)
    valueInput:SetPoint("TOP", slider, "BOTTOM", 0, -10)
    valueInput:SetAutoFocus(false)
    valueInput:SetNumeric(true)
    valueInput:SetMaxLetters(3)
    valueInput:SetText(tostring(TokenPriceDisplaySettings[colorKey][colorIndex]))

    valueInput:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value and value >= 0 and value <= 255 then
            TokenPriceDisplaySettings[colorKey][colorIndex] = value
            slider:SetValue(value)
            ApplySettings()
        else
            self:SetText(tostring(TokenPriceDisplaySettings[colorKey][colorIndex]))  -- Reset to current if invalid
        end
        self:ClearFocus()
    end)

    slider:SetScript("OnValueChanged", function(self, value)
        TokenPriceDisplaySettings[colorKey][colorIndex] = value
        valueInput:SetText(tostring(value))  -- Update the value display
        ApplySettings()
    end)

    return slider
end

-- Create RGB sliders for Frame Color, centered in the frame
local redSlider = CreateColorSlider(settingsFrame, "RedSlider", "Red", "frameColor", 1, -100)  -- Adjusted positions to give more space
local greenSlider = CreateColorSlider(settingsFrame, "GreenSlider", "Green", "frameColor", 2, -180)
local blueSlider = CreateColorSlider(settingsFrame, "BlueSlider", "Blue", "frameColor", 3, -260)

-- Function to update the sliders and input fields with saved settings
local function UpdateSettingsWindow()
    redSlider:SetValue(TokenPriceDisplaySettings.frameColor[1])
    greenSlider:SetValue(TokenPriceDisplaySettings.frameColor[2])
    blueSlider:SetValue(TokenPriceDisplaySettings.frameColor[3])
end

-- Function to toggle the settings window
local function ToggleSettings()
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        UpdateSettingsWindow()  -- Update sliders to reflect saved settings before showing
        settingsFrame:Show()
    end
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
