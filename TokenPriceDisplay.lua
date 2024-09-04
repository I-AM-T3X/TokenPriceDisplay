-- Initialize saved variables if they don't exist
if not TokenPriceDisplayDB then
    TokenPriceDisplayDB = {}  -- Table for saving frame position and other settings
end

if not TokenPriceDisplaySettings then
    TokenPriceDisplaySettings = {
        frameColor = {1, 1, 1, 1},  -- Default to white using RGB 0-1
        textColor = {1, 0.82, 0, 1},  -- Default to gold color
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
priceText:SetPoint("LEFT", labelText, "RIGHT", 10, 0)  -- Position the price text next to the label
priceText:SetTextColor(1, 1, 1)  -- White color for the price

-- Function to apply user settings
local function ApplySettings()
    local r, g, b = TokenPriceDisplaySettings.frameColor[1], TokenPriceDisplaySettings.frameColor[2], TokenPriceDisplaySettings.frameColor[3]
    frame:SetBackdropBorderColor(r, g, b, 1)  -- Apply the frame color using 0-1 range

    local tr, tg, tb = TokenPriceDisplaySettings.textColor[1], TokenPriceDisplaySettings.textColor[2], TokenPriceDisplaySettings.textColor[3]
    labelText:SetTextColor(tr, tg, tb)  -- Apply the text color
end

-- Function to reset colors to default
local function ResetToDefaultColors()
    TokenPriceDisplaySettings.frameColor = {1, 1, 1, 1}  -- Reset to white
    TokenPriceDisplaySettings.textColor = {1, 0.82, 0, 1}  -- Reset to gold
    ApplySettings()
end

-- Function to show the color picker with proper options
local function ShowColorPicker(colorType)
    -- Determine which color to change
    local r, g, b, a = 1, 1, 1, 1
    if colorType == "frame" then
        r, g, b, a = unpack(TokenPriceDisplaySettings.frameColor)
    elseif colorType == "text" then
        r, g, b, a = unpack(TokenPriceDisplaySettings.textColor)
    end

    -- Callback function for when color changes
    local function OnColorChanged()
        local newR, newG, newB = ColorPickerFrame:GetColorRGB()
        local newA = ColorPickerFrame:GetColorAlpha()

        if colorType == "frame" then
            TokenPriceDisplaySettings.frameColor = {newR, newG, newB, newA}
        elseif colorType == "text" then
            TokenPriceDisplaySettings.textColor = {newR, newG, newB, newA}
        end

        ApplySettings()  -- Apply the new settings
    end

    -- Callback function for when the user cancels the color selection
    local function OnCancel()
        print("Color Picker Canceled")
    end

    -- Options for the ColorPickerFrame
    local options = {
        swatchFunc = OnColorChanged,  -- Called when color is changed
        opacityFunc = OnColorChanged,  -- Called when opacity is changed
        cancelFunc = OnCancel,  -- Called when the user cancels the picker
        hasOpacity = true,  -- Enable opacity slider
        opacity = a,  -- Initial opacity
        r = r,  -- Initial red value
        g = g,  -- Initial green value
        b = b,  -- Initial blue value
    }

    -- Set up and show the ColorPickerFrame with the specified options
    ColorPickerFrame:SetupColorPickerAndShow(options)
end

-- Function to update the token price
local function UpdateTokenPrice()
    local price = C_WowTokenPublic.GetCurrentMarketPrice()  -- Get current token price in copper
    if price then
        local formattedPrice = GetCoinTextureString(price)  -- Convert to formatted string with textures
        priceText:SetText(formattedPrice)  -- Set the formatted price on the frame
    else
        priceText:SetText("N/A")  -- Set the text if price is not available
    end
end

-- Event handler for TOKEN_MARKET_PRICE_UPDATED
local function OnEvent(self, event, ...)
    if event == "TOKEN_MARKET_PRICE_UPDATED" then
        UpdateTokenPrice()  -- Update the price when the event is fired
    elseif event == "PLAYER_LOGIN" then
        LoadFramePosition()  -- Ensure frame position is loaded on login
        ApplySettings()  -- Apply settings when the player logs in
        UpdateTokenPrice()  -- Get the initial price when the player logs in
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

-- Button to change frame color
local frameColorButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
frameColorButton:SetSize(150, 30)
frameColorButton:SetPoint("TOP", settingsFrame, "TOP", 0, -80)
frameColorButton:SetText("Change Frame Color")
frameColorButton:SetNormalFontObject("GameFontHighlight")
frameColorButton:SetScript("OnClick", function() ShowColorPicker("frame") end)

-- Button to change text color
local textColorButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
textColorButton:SetSize(150, 30)
textColorButton:SetPoint("TOP", frameColorButton, "BOTTOM", 0, -20)
textColorButton:SetText("Change Text Color")
textColorButton:SetNormalFontObject("GameFontHighlight")
textColorButton:SetScript("OnClick", function() ShowColorPicker("text") end)

-- Button to reset colors to default
local resetButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
resetButton:SetSize(150, 30)
resetButton:SetPoint("TOP", textColorButton, "BOTTOM", 0, -20)
resetButton:SetText("Reset to Default Colors")
resetButton:SetNormalFontObject("GameFontHighlight")
resetButton:SetScript("OnClick", function() ResetToDefaultColors() end)

-- Function to toggle the settings window
local function ToggleSettings()
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
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

-- Apply settings after frame creation
ApplySettings()
