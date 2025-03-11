-- Configuration
local DEFAULT_FRAME_COLOR = {1, 1, 1, 1}  -- White
local DEFAULT_TEXT_COLOR = {1, 0.82, 0, 1}  -- Gold
local DEFAULT_ICON_SIZE = 30
local DEFAULT_DISPLAY_TYPE = "text"
local DEFAULT_SHOW_ARROW = true

-- Initialize saved variables if they don't exist
TokenPriceDisplayDB = TokenPriceDisplayDB or {}
TokenPriceDisplaySettings = TokenPriceDisplaySettings or {
    frameColor = DEFAULT_FRAME_COLOR,
    textColor = DEFAULT_TEXT_COLOR,
    lastKnownPrice = nil,
    displayType = DEFAULT_DISPLAY_TYPE,
    showArrow = DEFAULT_SHOW_ARROW,
    iconSize = DEFAULT_ICON_SIZE,

    -- Alert Settings
    alertEnabled = false,
    alertLowThreshold = nil,
    alertHighThreshold = nil,

    -- Alert Counters (Reset on Login)
    alertLowCount = 0,
    alertHighCount = 0
}

-- Create the main display frame for the addon
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
    if TokenPriceDisplayDB.point then
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
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    SaveFramePosition()
end)

-- Create a font string for the label "WoW Token:"
local labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
labelText:SetPoint("LEFT", frame, "LEFT", 10, 0)
labelText:SetTextColor(unpack(TokenPriceDisplaySettings.textColor))
labelText:SetText("WoW Token:")

-- Create a font string to display the token price
local priceText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
priceText:SetPoint("LEFT", labelText, "RIGHT", 5, 0)
priceText:SetTextColor(1, 1, 1)  -- White color for the price

-- Create texture for the arrow indicator
local priceIndicator = frame:CreateTexture(nil, "OVERLAY")
priceIndicator:SetSize(16, 16)
priceIndicator:SetPoint("LEFT", priceText, "RIGHT", 5, 0)

-- Function to add commas to large numbers
local function FormatNumberWithCommas(number)
    return tostring(number):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- Function to adjust the frame size dynamically
local function AdjustFrameSize()
    local labelWidth = labelText:IsShown() and labelText:GetStringWidth() or 0
    local textWidth = priceText:GetStringWidth()
    local iconWidth = priceIndicator:IsShown() and priceIndicator:GetWidth() or 0
    local padding = 20  -- Reduced padding to minimize extra space

    if TokenPriceDisplaySettings.displayType == "icon" then
        frame:SetWidth(iconWidth + textWidth + padding)
    else
        frame:SetWidth(labelWidth + textWidth + iconWidth + padding + 15)
    end
end

-- Function to apply user settings
local function ApplySettings()
    frame:SetBackdropBorderColor(unpack(TokenPriceDisplaySettings.frameColor))
    labelText:SetTextColor(unpack(TokenPriceDisplaySettings.textColor))

    if TokenPriceDisplaySettings.displayType == "icon" then
        labelText:Hide()
        priceIndicator:SetTexture("Interface\\Icons\\wow_token01")
        priceIndicator:SetSize(TokenPriceDisplaySettings.iconSize, TokenPriceDisplaySettings.iconSize)
        priceIndicator:SetPoint("LEFT", frame, "LEFT", 5, 0)
        priceText:ClearAllPoints()
        priceText:SetPoint("LEFT", priceIndicator, "RIGHT", 5, 0)

        -- Ensure the frame is properly resized
        frame:SetSize(TokenPriceDisplaySettings.iconSize + priceText:GetStringWidth() + 20, TokenPriceDisplaySettings.iconSize)
        frame:Show()  -- Ensure frame remains visible
    else
        labelText:SetText("WoW Token:")
        labelText:Show()
        priceText:ClearAllPoints()
        priceText:SetPoint("LEFT", labelText, "RIGHT", 5, 0)
        priceIndicator:ClearAllPoints()
        priceIndicator:SetPoint("LEFT", priceText, "RIGHT", 5, 0)

        -- Ensure the frame is properly resized
        frame:SetSize(180, 30)
        frame:Show()  -- Ensure frame remains visible
    end

    -- Toggle the visibility of the arrow
    priceIndicator:SetShown(TokenPriceDisplaySettings.showArrow)

    AdjustFrameSize()
end

-- Function to reset colors to default
local function ResetToDefaultColors()
    TokenPriceDisplaySettings.frameColor = DEFAULT_FRAME_COLOR
    TokenPriceDisplaySettings.textColor = DEFAULT_TEXT_COLOR
    ApplySettings()
end

-- Function to show the color picker for frame or text color
local function ShowColorPicker(colorType)
    local r, g, b, a = unpack(colorType == "frame" and TokenPriceDisplaySettings.frameColor or TokenPriceDisplaySettings.textColor)

    local function OnColorChanged()
        local newR, newG, newB = ColorPickerFrame:GetColorRGB()
        local newA = ColorPickerFrame:GetColorAlpha() or 1

        if colorType == "frame" then
            TokenPriceDisplaySettings.frameColor = {newR, newG, newB, newA}
        else
            TokenPriceDisplaySettings.textColor = {newR, newG, newB, newA}
        end

        ApplySettings()
    end

    local function OnCancel()
        ApplySettings()  -- Revert to previous settings if the user cancels
    end

    ColorPickerFrame:SetupColorPickerAndShow({
        swatchFunc = OnColorChanged,
        opacityFunc = OnColorChanged,
        cancelFunc = OnCancel,
        hasOpacity = true,
        opacity = a,
        r = r,
        g = g,
        b = b,
    })
end

-- Function to update the token price display
local function UpdateTokenPrice()
    local price = C_WowTokenPublic.GetCurrentMarketPrice()

    if price then
        local goldPrice = math.floor(price / 10000)  -- Convert from copper to gold
        local formattedPrice = GetCoinTextureString(price)  -- Keep display price unchanged
        priceText:SetText(FormatNumberWithCommas(formattedPrice))
        AdjustFrameSize()

        if TokenPriceDisplaySettings.lastKnownPrice then
            if goldPrice > TokenPriceDisplaySettings.lastKnownPrice then
                priceIndicator:SetTexture("Interface\\Icons\\wow_token01")  -- 🔹 Arrow up
            elseif goldPrice < TokenPriceDisplaySettings.lastKnownPrice then
                priceIndicator:SetTexture("Interface\\Icons\\wow_token02")  -- 🔹 Arrow down
            else
                priceIndicator:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")  -- No change
            end
            priceIndicator:SetSize(TokenPriceDisplaySettings.iconSize, TokenPriceDisplaySettings.iconSize)
        end
        priceIndicator:Show()
        TokenPriceDisplaySettings.lastKnownPrice = goldPrice  -- Store gold value

        -- 🔹 Alert Logic (Only Trigger if Alerts Are Enabled)
        if TokenPriceDisplaySettings.alertEnabled then
            if TokenPriceDisplaySettings.alertLowThreshold and goldPrice <= TokenPriceDisplaySettings.alertLowThreshold and TokenPriceDisplaySettings.alertLowCount < 3 then
                print("|cffff0000[Token Alert]: WoW Token price has dropped below " .. TokenPriceDisplaySettings.alertLowThreshold .. "! Current price: " .. goldPrice .. " gold|r")
                TokenPriceDisplaySettings.alertLowCount = TokenPriceDisplaySettings.alertLowCount + 1
            end
            if TokenPriceDisplaySettings.alertHighThreshold and goldPrice >= TokenPriceDisplaySettings.alertHighThreshold and TokenPriceDisplaySettings.alertHighCount < 3 then
                print("|cff00ff00[Token Alert]: WoW Token price has risen above " .. TokenPriceDisplaySettings.alertHighThreshold .. "! Current price: " .. goldPrice .. " gold|r")
                TokenPriceDisplaySettings.alertHighCount = TokenPriceDisplaySettings.alertHighCount + 1
            end
        end
    else
        priceText:SetText("N/A")
        priceIndicator:Hide()
    end
end

-- 🔹 Create the Settings Panel Function (MUST BE ABOVE OnEvent)
local function CreateSettingsPanel()
    local settingsPanel = CreateFrame("FRAME", "TokenPriceDisplaySettingsPanel", UIParent)
    settingsPanel.name = "Token Price Display"
    settingsPanel:SetSize(400, 500)

    local title = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Token Price Display Settings")

    -- 🔹 Frame Color Picker Button
    local frameColorButton = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
    frameColorButton:SetSize(150, 30)
    frameColorButton:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    frameColorButton:SetText("Change Frame Color")
    frameColorButton:SetScript("OnClick", function() ShowColorPicker("frame") end)

    -- 🔹 Text Color Picker Button
    local textColorButton = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
    textColorButton:SetSize(150, 30)
    textColorButton:SetPoint("TOPLEFT", frameColorButton, "BOTTOMLEFT", 0, -10)
    textColorButton:SetText("Change Text Color")
    textColorButton:SetScript("OnClick", function() ShowColorPicker("text") end)

    -- 🔹 Reset to Default Button
    local resetButton = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
    resetButton:SetSize(150, 30)
    resetButton:SetPoint("TOPLEFT", textColorButton, "BOTTOMLEFT", 0, -10)
    resetButton:SetText("Reset to Default")
    resetButton:SetScript("OnClick", ResetToDefaultColors)
	
	    -- 🔹 Label for Low Price Alert (Buy Threshold)
    local lowPriceLabel = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lowPriceLabel:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -20)
    lowPriceLabel:SetText("Game Time Alert - Low Price (Gold):")

    -- 🔹 Low (Buy) Price Threshold Input
    local lowPriceInput = CreateFrame("EditBox", nil, settingsPanel, "InputBoxTemplate")
    lowPriceInput:SetSize(100, 20)
    lowPriceInput:SetPoint("TOPLEFT", lowPriceLabel, "BOTTOMLEFT", 0, -5)
    lowPriceInput:SetAutoFocus(false)
    lowPriceInput:SetText(TokenPriceDisplaySettings.alertLowThreshold or "")
    lowPriceInput:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())  -- Convert back to number
        if value then
            TokenPriceDisplaySettings.alertLowThreshold = value
            print("|cff00ff00[Token Alert]: Game Time Alert set at " .. value .. " gold!|r")
        else
            print("|cffff0000[Token Alert]: Invalid Game Time Alert price!|r")
        end
        self:ClearFocus()
    end)

    -- 🔹 Label for High Price Alert (Sell Threshold)
    local highPriceLabel = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    highPriceLabel:SetPoint("TOPLEFT", lowPriceInput, "BOTTOMLEFT", 0, -20)
    highPriceLabel:SetText("Gold Buyer Alert - High Price (Gold):")

    -- 🔹 High (Sell) Price Threshold Input
    local highPriceInput = CreateFrame("EditBox", nil, settingsPanel, "InputBoxTemplate")
    highPriceInput:SetSize(100, 20)
    highPriceInput:SetPoint("TOPLEFT", highPriceLabel, "BOTTOMLEFT", 0, -5)
    highPriceInput:SetAutoFocus(false)
    highPriceInput:SetText(tostring(TokenPriceDisplaySettings.alertHighThreshold or ""))  -- 🔹 Convert number to string
    highPriceInput:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())  -- Convert back to number
        if value then
            TokenPriceDisplaySettings.alertHighThreshold = value
            print("|cffff0000[Token Alert]: Gold Buyer Alert set at " .. value .. " gold!|r")
        else
            print("|cffff0000[Token Alert]: Invalid Gold Buyer Alert price!|r")
        end
        self:ClearFocus()
    end)

    -- 🔹 Checkbox for Enabling/Disabling Icon Display
    local iconCheckbox = CreateFrame("CheckButton", nil, settingsPanel, "InterfaceOptionsCheckButtonTemplate")
    iconCheckbox:SetPoint("TOPLEFT", highPriceInput, "BOTTOMLEFT", 0, -20)
    iconCheckbox.Text:SetText("Use Icon for WoW Token Display")
    iconCheckbox:SetChecked(TokenPriceDisplaySettings.displayType == "icon")
    iconCheckbox:SetScript("OnClick", function(self)
        TokenPriceDisplaySettings.displayType = self:GetChecked() and "icon" or "text"
        ApplySettings()
    end)

    -- 🔹 Checkbox for Enabling/Disabling Arrow Display
    local arrowCheckbox = CreateFrame("CheckButton", nil, settingsPanel, "InterfaceOptionsCheckButtonTemplate")
    arrowCheckbox:SetPoint("TOPLEFT", iconCheckbox, "BOTTOMLEFT", 0, -10)
    arrowCheckbox.Text:SetText("Show Price Change Arrow")
    arrowCheckbox:SetChecked(TokenPriceDisplaySettings.showArrow)
    arrowCheckbox:SetScript("OnClick", function(self)
        TokenPriceDisplaySettings.showArrow = self:GetChecked()
        ApplySettings()
    end)
	
	-- 🔹 Checkbox for Enabling/Disabling Price Alerts
    local alertCheckbox = CreateFrame("CheckButton", nil, settingsPanel, "InterfaceOptionsCheckButtonTemplate")
    alertCheckbox:SetPoint("TOPLEFT", arrowCheckbox, "BOTTOMLEFT", 0, -20)
    alertCheckbox.Text:SetText("Enable Price Alerts")
    alertCheckbox:SetChecked(TokenPriceDisplaySettings.alertEnabled)
    alertCheckbox:SetScript("OnClick", function(self)
        TokenPriceDisplaySettings.alertEnabled = self:GetChecked()
        print("|cff00ff00[Token Alert]: Price alerts " .. (self:GetChecked() and "enabled" or "disabled") .. "!|r")
    end)


    -- Register the panel with the Interface Options
    local category = Settings.RegisterCanvasLayoutCategory(settingsPanel, settingsPanel.name)
    Settings.RegisterAddOnCategory(category)

    -- Slash command to open settings
    SLASH_TOKENPRICEDISPLAY1 = "/tpd"
    SlashCmdList["TOKENPRICEDISPLAY"] = function(msg)
        if msg == "settings" then
            Settings.OpenToCategory(category:GetID())
        else
            print("Token Price Display commands:")
            print("/tpd settings - Open the settings window")
        end
    end
end

-- Event handler for TOKEN_MARKET_PRICE_UPDATED
local function OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "TokenPriceDisplay" then
        -- Load saved settings
        TokenPriceDisplayDB = TokenPriceDisplayDB or {}
        TokenPriceDisplaySettings = TokenPriceDisplaySettings or {
            frameColor = {0.949, 1, 0, 1},
            textColor = {1, 0.82, 0, 1},
            lastKnownPrice = nil,
            displayType = "text",
            showArrow = true,
            iconSize = 30,
            alertEnabled = false,
            alertLowThreshold = nil,
            alertHighThreshold = nil,
            alertLowCount = 0,
            alertHighCount = 0
        }

        print("|cff00ff00[Token Price Display]: Saved variables loaded!|r")

        -- ✅ Now that saved variables are loaded, create the settings panel
        CreateSettingsPanel()
    elseif event == "TOKEN_MARKET_PRICE_UPDATED" then
        UpdateTokenPrice()
    elseif event == "PLAYER_LOGIN" then
        LoadFramePosition()
        ApplySettings()
        UpdateTokenPrice()

        -- Reset alert counters on login
        TokenPriceDisplaySettings.alertLowCount = 0
        TokenPriceDisplaySettings.alertHighCount = 0
    elseif event == "PLAYER_LOGOUT" then
        SaveFramePosition()  -- Save frame position when logging out
    end
end

-- Register the frame to listen for events
frame:RegisterEvent("ADDON_LOADED")  -- Ensure saved variables load correctly
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")
frame:SetScript("OnEvent", OnEvent)

-- Request the initial market price update
C_WowTokenPublic.UpdateMarketPrice()

-- Use a timer for periodic price updates
local updateTimer = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    updateTimer = updateTimer + elapsed
    if updateTimer >= 300 then  -- ⏳ Updating every 1 min
        C_WowTokenPublic.UpdateMarketPrice()
        C_Timer.After(2, function()  -- 🔹 Wait 2 seconds before updating display
            UpdateTokenPrice()
        end)
        updateTimer = 0
    end
end)
