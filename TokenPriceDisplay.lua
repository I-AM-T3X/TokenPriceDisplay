-- Initialize saved variables if they don't exist
if not TokenPriceDisplayDB then
    TokenPriceDisplayDB = {}  -- Table for saving frame position and other settings
end

if not TokenPriceDisplaySettings then
    TokenPriceDisplaySettings = {
        frameColor = {1, 1, 1, 1},  -- Default to white using RGB 0-1
        textColor = {1, 0.82, 0, 1},  -- Default to gold color
        lastKnownPrice = nil,  -- Initialize last known price
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

-- Function to adjust the frame size dynamically
local function AdjustFrameSize()
    local textWidth = priceText:GetStringWidth()  -- Get the width of the price text
    local iconWidth = priceIndicator:IsShown() and priceIndicator:GetWidth() or 0  -- Width of the icon if shown
    local labelWidth = labelText:GetStringWidth()  -- Width of the label text
    local padding = 35  -- Extra padding to account for label and margins

    frame:SetWidth(labelWidth + textWidth + iconWidth + padding)  -- Adjust the frame width based on text and icon
end

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
    -- Save the original position of the ColorPickerFrame
    local originalPoint, originalRelativeTo, originalRelativePoint, originalXOfs, originalYOfs = ColorPickerFrame:GetPoint()

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
        -- No action needed
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

    -- Reset the position of the ColorPickerFrame to its original position when closed
    ColorPickerFrame:HookScript("OnHide", function()
        ColorPickerFrame:ClearAllPoints()
        ColorPickerFrame:SetPoint(originalPoint, originalRelativeTo, originalRelativePoint, originalXOfs, originalYOfs)
    end)
end

-- Function to update the token price and indicator
local function UpdateTokenPrice()
    local price = C_WowTokenPublic.GetCurrentMarketPrice()  -- Get current token price in copper
    if price then
        local formattedPrice = GetCoinTextureString(price)  -- Convert to formatted string with textures
        priceText:SetText(formattedPrice)  -- Set the formatted price on the frame
        AdjustFrameSize()  -- Adjust frame size after setting the text

        -- Use the saved price to determine the arrow indicator on login
        if TokenPriceDisplaySettings.lastKnownPrice then
            if price > TokenPriceDisplaySettings.lastKnownPrice then
                priceIndicator:SetTexture("Interface\\Icons\\Misc_Arrowlup")  -- Up arrow texture
                priceIndicator:Show()  -- Ensure the indicator is visible
            elseif price < TokenPriceDisplaySettings.lastKnownPrice then
                priceIndicator:SetTexture("Interface\\Icons\\Misc_Arrowdown")  -- Down arrow texture
                priceIndicator:Show()  -- Ensure the indicator is visible
            else
                priceIndicator:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")  -- Red "X" texture for no change
                priceIndicator:Show()  -- Ensure the indicator is visible
            end
        end
        
        -- Update the saved price with the current one
        TokenPriceDisplaySettings.lastKnownPrice = price
    else
        priceText:SetText("N/A")  -- Set the text if price is not available
        priceIndicator:Hide()  -- Hide the arrow if no price is available
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

frame:SetScript("OnUpdate", OnUpdate)

-- Create the main settings panel for the Interface Options
local settingsPanel = CreateFrame("FRAME", "TokenPriceDisplaySettingsPanel", UIParent)
settingsPanel.name = "Token Price Display"  -- Name to show in Interface Options

-- Function to initialize the panel
local function InitializeSettingsPanel(panel)
    -- Title for the settings panel
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Token Price Display Settings")

    -- Frame Color Picker Button
    local frameColorButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    frameColorButton:SetSize(150, 30)
    frameColorButton:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    frameColorButton:SetText("Change Frame Color")
    frameColorButton:SetNormalFontObject("GameFontHighlight")
    frameColorButton:SetScript("OnClick", function() ShowColorPicker("frame") end)

    -- Text Color Picker Button
    local textColorButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    textColorButton:SetSize(150, 30)
    textColorButton:SetPoint("TOPLEFT", frameColorButton, "BOTTOMLEFT", 0, -10)
    textColorButton:SetText("Change Text Color")
    textColorButton:SetNormalFontObject("GameFontHighlight")
    textColorButton:SetScript("OnClick", function() ShowColorPicker("text") end)

    -- Reset to Default Button
    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(150, 30)
    resetButton:SetPoint("TOPLEFT", textColorButton, "BOTTOMLEFT", 0, -10)
    resetButton:SetText("Reset to Default")
    resetButton:SetNormalFontObject("GameFontHighlight")
    resetButton:SetScript("OnClick", function() ResetToDefaultColors() end)

    -- Acknowledgements Header
    local ackHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    ackHeader:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -20)
    ackHeader:SetTextColor(1, 0.82, 0)  -- Gold color
    ackHeader:SetText("Acknowledgements")

    -- Individual Acknowledgements
    local ackTomcat = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ackTomcat:SetPoint("TOPLEFT", ackHeader, "BOTTOMLEFT", 0, -10)
    ackTomcat:SetTextColor(1, 0.82, 0)  -- Gold color
    ackTomcat:SetJustifyH("LEFT")
    ackTomcat:SetText("Tomcat of Tomcat Tours: For your invaluable help with the API.")

    local ackPirateSoftware = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ackPirateSoftware:SetPoint("TOPLEFT", ackTomcat, "BOTTOMLEFT", 0, -10)
    ackPirateSoftware:SetTextColor(1, 0.82, 0)  -- Gold color
    ackPirateSoftware:SetJustifyH("LEFT")
    ackPirateSoftware:SetText("PirateSoftware: For encouraging me to learn coding.")

    local ackPersephonae = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ackPersephonae:SetPoint("TOPLEFT", ackPirateSoftware, "BOTTOMLEFT", 0, -10)
    ackPersephonae:SetTextColor(1, 0.82, 0)  -- Gold color
    ackPersephonae:SetJustifyH("LEFT")
    ackPersephonae:SetText("Persephonae: For suggesting the idea for this addon.")
end

-- Initialize the settings panel
InitializeSettingsPanel(settingsPanel)

-- Add "okay" method to apply changes
settingsPanel.okay = function()
    -- Save settings here if needed
    print("Settings applied")
end

-- Add "cancel" method to revert changes
settingsPanel.cancel = function()
    -- Revert changes here if needed
    print("Settings reverted")
end

-- Add "default" method to reset to default settings
settingsPanel.default = function()
    ResetToDefaultColors()
    print("Settings reset to default")
end

-- Add "refresh" method to refresh settings display
settingsPanel.refresh = function()
    -- Refresh settings display here if needed
    print("Settings refreshed")
end

-- Register the panel with the Interface Options using the new Settings API
local category = Settings.RegisterCanvasLayoutCategory(settingsPanel, settingsPanel.name)
Settings.RegisterAddOnCategory(category)

-- Function to toggle the settings window and open directly to the panel
local function ToggleSettings()
    Settings.OpenToCategory(category:GetID())  -- Open directly to the settings panel using the category ID
end

-- Slash command to open settings
SLASH_TOKENPRICEDISPLAY1 = "/tpd"
SlashCmdList["TOKENPRICEDISPLAY"] = function(msg)
    if msg == "settings" then
        ToggleSettings()  -- Open the Interface Options to the settings panel
    else
        print("Token Price Display commands:")
        print("/tpd settings - Open the settings window")
    end
end
