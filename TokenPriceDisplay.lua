-- Main frame and locals
local addonName, addon = ...
local frame = CreateFrame("Frame", "TokenPriceFrame", UIParent, "BackdropTemplate")
local labelText, priceText, priceIndicator
local updateTicker

-- Default configuration
local DEFAULTS = {
    frameColor = {1, 1, 1, 1},
    textColor = {1, 0.82, 0, 1},
    iconSize = 30,
    displayType = "text",
    showArrow = true,
    alertEnabled = false,
    alertLowThreshold = nil,
    alertHighThreshold = nil,
}

-- State variables (not saved)
local alertState = {
    lowTriggered = false,
    highTriggered = false,
}

-- Utility: Format number with commas (for raw numbers only)
local function FormatGold(number)
    if not number then return "N/A" end
    local gold = math.floor(number / 10000)
    local formatted = tostring(gold):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return formatted .. "|cffffd700g|r"
end

-- Utility: Safe saved variables initialization
local function InitSettings()
    TokenPriceDisplayDB = TokenPriceDisplayDB or {}
    TokenPriceDisplaySettings = TokenPriceDisplaySettings or {}
    
    -- Merge with defaults for any missing values
    for k, v in pairs(DEFAULTS) do
        if TokenPriceDisplaySettings[k] == nil then
            TokenPriceDisplaySettings[k] = v
        end
    end
    
    -- Ensure color tables are valid
    if type(TokenPriceDisplaySettings.frameColor) ~= "table" then
        TokenPriceDisplaySettings.frameColor = DEFAULTS.frameColor
    end
    if type(TokenPriceDisplaySettings.textColor) ~= "table" then
        TokenPriceDisplaySettings.textColor = DEFAULTS.textColor
    end
end

-- Frame Position Management
local function SaveFramePosition()
    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
    if point then
        TokenPriceDisplayDB.point = point
        TokenPriceDisplayDB.relativePoint = relativePoint
        TokenPriceDisplayDB.xOfs = xOfs
        TokenPriceDisplayDB.yOfs = yOfs
    end
end

local function LoadFramePosition()
    if TokenPriceDisplayDB.point then
        frame:ClearAllPoints()
        frame:SetPoint(TokenPriceDisplayDB.point, UIParent, TokenPriceDisplayDB.relativePoint, TokenPriceDisplayDB.xOfs, TokenPriceDisplayDB.yOfs)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- Frame Setup
local function SetupFrame()
    frame:SetSize(180, 40)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SaveFramePosition()
    end)
    
    -- Label
    labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("LEFT", frame, "LEFT", 10, 0)
    labelText:SetText("WoW Token:")
    
    -- Price text
    priceText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    priceText:SetPoint("LEFT", labelText, "RIGHT", 5, 0)
    priceText:SetTextColor(1, 1, 1)
    
    -- Indicator texture
    priceIndicator = frame:CreateTexture(nil, "OVERLAY")
    priceIndicator:SetSize(16, 16)
    priceIndicator:Hide()
end

-- Dynamic sizing - FIXED for compact icon mode
local function AdjustFrameSize()
    if TokenPriceDisplaySettings.displayType == "icon" then
        -- Compact mode: Just icon + text + minimal padding
        -- Layout: [5px][icon][5px][text][10px]
        local iconWidth = TokenPriceDisplaySettings.iconSize
        local textWidth = priceText:GetStringWidth()
        local width = 5 + iconWidth + 5 + textWidth + 10
        frame:SetWidth(width)
        frame:SetHeight(math.max(30, TokenPriceDisplaySettings.iconSize + 4))
    else
        -- Text mode: Original wider calculation with label
        local padding = 20
        local width = padding
        
        if labelText:IsShown() then
            width = width + labelText:GetStringWidth() + 5
        end
        
        width = width + priceText:GetStringWidth()
        
        if TokenPriceDisplaySettings.showArrow and priceIndicator:IsShown() then
            width = width + 5 + 16
        end
        
        frame:SetHeight(30)
        frame:SetWidth(math.max(120, width))
    end
end

-- Apply settings to UI
local function ApplySettings()
    -- Colors
    frame:SetBackdropBorderColor(unpack(TokenPriceDisplaySettings.frameColor))
    labelText:SetTextColor(unpack(TokenPriceDisplaySettings.textColor))
    
    -- Layout mode
    if TokenPriceDisplaySettings.displayType == "icon" then
        labelText:Hide()
        priceIndicator:ClearAllPoints()
        priceIndicator:SetPoint("LEFT", frame, "LEFT", 5, 0)
        priceIndicator:SetTexture("Interface\\Icons\\wow_token01")
        priceIndicator:SetSize(TokenPriceDisplaySettings.iconSize, TokenPriceDisplaySettings.iconSize)
        priceIndicator:Show()
        
        priceText:ClearAllPoints()
        priceText:SetPoint("LEFT", priceIndicator, "RIGHT", 5, 0)
    else
        labelText:Show()
        priceText:ClearAllPoints()
        priceText:SetPoint("LEFT", labelText, "RIGHT", 5, 0)
        
        priceIndicator:ClearAllPoints()
        priceIndicator:SetPoint("LEFT", priceText, "RIGHT", 5, 0)
    end
    
    -- Arrow visibility (only applies to text mode really)
    if not TokenPriceDisplaySettings.showArrow then
        priceIndicator:Hide()
    end
    
    AdjustFrameSize()
end

-- Color Picker (Fixed for cancel logic)
local function ShowColorPicker(colorType)
    local settings = TokenPriceDisplaySettings
    local color = colorType == "frame" and settings.frameColor or settings.textColor
    local r, g, b, a = unpack(color)
    local originalColor = {r, g, b, a}
    
    local function OnColorChanged()
        local newR, newG, newB = ColorPickerFrame:GetColorRGB()
        local newA = ColorPickerFrame:GetColorAlpha()
        
        if colorType == "frame" then
            settings.frameColor = {newR, newG, newB, newA}
        else
            settings.textColor = {newR, newG, newB, newA}
        end
        ApplySettings()
    end
    
    local function OnCancel()
        if colorType == "frame" then
            settings.frameColor = originalColor
        else
            settings.textColor = originalColor
        end
        ApplySettings()
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

-- Reset colors
local function ResetToDefaultColors()
    TokenPriceDisplaySettings.frameColor = {unpack(DEFAULTS.frameColor)}
    TokenPriceDisplaySettings.textColor = {unpack(DEFAULTS.textColor)}
    ApplySettings()
end

-- Alert Logic (Improved with hysteresis)
local function CheckAlerts(currentGold)
    if not TokenPriceDisplaySettings.alertEnabled then return end
    
    local low = TokenPriceDisplaySettings.alertLowThreshold
    local high = TokenPriceDisplaySettings.alertHighThreshold
    
    if low and currentGold <= low then
        if not alertState.lowTriggered then
            print(string.format("|cffff0000[Token Alert]: WoW Token price has dropped to %s! (Below threshold: %s)|r", 
                FormatGold(currentGold * 10000), FormatGold(low * 10000)))
            alertState.lowTriggered = true
        end
    else
        alertState.lowTriggered = false
    end
    
    if high and currentGold >= high then
        if not alertState.highTriggered then
            print(string.format("|cff00ff00[Token Alert]: WoW Token price has risen to %s! (Above threshold: %s)|r", 
                FormatGold(currentGold * 10000), FormatGold(high * 10000)))
            alertState.highTriggered = true
        end
    else
        alertState.highTriggered = false
    end
end

-- Main update function
local function UpdateTokenPrice()
    local price = C_WowTokenPublic.GetCurrentMarketPrice()
    
    if not price then
        priceText:SetText("Loading...")
        priceIndicator:Hide()
        AdjustFrameSize()
        return
    end
    
    local goldPrice = math.floor(price / 10000)
    priceText:SetText(FormatGold(price))
    
    local lastPrice = TokenPriceDisplaySettings.lastKnownPrice
    if lastPrice and TokenPriceDisplaySettings.showArrow and TokenPriceDisplaySettings.displayType ~= "icon" then
        -- Only show arrows in text mode
        if goldPrice > lastPrice then
            priceIndicator:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
            priceIndicator:SetVertexColor(0, 1, 0)
        elseif goldPrice < lastPrice then
            priceIndicator:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
            priceIndicator:SetVertexColor(1, 0, 0)
        else
            priceIndicator:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            priceIndicator:SetVertexColor(1, 1, 1)
        end
        priceIndicator:Show()
    elseif TokenPriceDisplaySettings.displayType == "icon" then
        -- In icon mode, priceIndicator shows the token icon, handled in ApplySettings
        -- But we need to make sure it stays as token icon even after price updates
        priceIndicator:SetTexture("Interface\\Icons\\wow_token01")
        priceIndicator:SetVertexColor(1, 1, 1)
        priceIndicator:Show()
    elseif not TokenPriceDisplaySettings.showArrow then
        priceIndicator:Hide()
    end
    
    TokenPriceDisplaySettings.lastKnownPrice = goldPrice
    AdjustFrameSize()
    CheckAlerts(goldPrice)
end

-- Settings Panel
local function CreateSettingsPanel()
    local panel = CreateFrame("Frame", "TokenPriceDisplaySettingsPanel", UIParent)
    panel.name = "Token Price Display"
    panel.okay = function() end
    panel.cancel = function() end
    panel.default = function() 
        ResetToDefaultColors()
        TokenPriceDisplaySettings.displayType = DEFAULTS.displayType
        TokenPriceDisplaySettings.showArrow = DEFAULTS.showArrow
        TokenPriceDisplaySettings.alertEnabled = DEFAULTS.alertEnabled
        TokenPriceDisplaySettings.alertLowThreshold = DEFAULTS.alertLowThreshold
        TokenPriceDisplaySettings.alertHighThreshold = DEFAULTS.alertHighThreshold
    end
    
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Token Price Display Settings")
    
    local yOffset = -50
    
    local function CreateButton(text, onClick)
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(150, 30)
        btn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        yOffset = yOffset - 40
        return btn
    end
    
    local function CreateCheckbox(label, checked, onClick)
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
        cb.Text:SetText(label)
        cb:SetChecked(checked)
        cb:SetScript("OnClick", function(self)
            onClick(self:GetChecked())
        end)
        yOffset = yOffset - 30
        return cb
    end
    
    local function CreateNumberInput(label, value, onEnter)
        local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
        lbl:SetText(label)
        yOffset = yOffset - 20
        
        local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        edit:SetSize(100, 20)
        edit:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
        edit:SetAutoFocus(false)
        edit:SetText(value and tostring(value) or "")
        edit:SetNumeric(true)
        edit:SetScript("OnEnterPressed", function(self)
            local num = tonumber(self:GetText())
            if num and num >= 0 then
                onEnter(num)
                self:ClearFocus()
            else
                print("|cffff0000[Token Price Display]: Invalid number entered|r")
            end
        end)
        yOffset = yOffset - 40
        return edit
    end
    
    CreateButton("Change Frame Color", function() ShowColorPicker("frame") end)
    CreateButton("Change Text Color", function() ShowColorPicker("text") end)
    CreateButton("Reset to Default", ResetToDefaultColors)
    
    yOffset = yOffset - 10
    
    CreateNumberInput("Low Price Alert (Gold):", TokenPriceDisplaySettings.alertLowThreshold, function(val)
        TokenPriceDisplaySettings.alertLowThreshold = val
        print(string.format("|cff00ff00[Token Price Display]: Low price alert set to %s gold|r", FormatGold(val * 10000)))
    end)
    
    CreateNumberInput("High Price Alert (Gold):", TokenPriceDisplaySettings.alertHighThreshold, function(val)
        TokenPriceDisplaySettings.alertHighThreshold = val
        print(string.format("|cff00ff00[Token Price Display]: High price alert set to %s gold|r", FormatGold(val * 10000)))
    end)
    
    CreateCheckbox("Use Icon Display", TokenPriceDisplaySettings.displayType == "icon", function(checked)
        TokenPriceDisplaySettings.displayType = checked and "icon" or "text"
        ApplySettings()
        -- Force price update to refresh display
        C_WowTokenPublic.UpdateMarketPrice()
    end)
    
    CreateCheckbox("Show Price Change Arrow", TokenPriceDisplaySettings.showArrow, function(checked)
        TokenPriceDisplaySettings.showArrow = checked
        ApplySettings()
    end)
    
    CreateCheckbox("Enable Price Alerts", TokenPriceDisplaySettings.alertEnabled, function(checked)
        TokenPriceDisplaySettings.alertEnabled = checked
        print(string.format("|cff00ff00[Token Price Display]: Alerts %s|r", checked and "enabled" or "disabled"))
    end)
    
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        
        SLASH_TOKENPRICEDISPLAY1 = "/tpd"
        SlashCmdList["TOKENPRICEDISPLAY"] = function(msg)
            if msg == "settings" then
                Settings.OpenToCategory(category:GetID())
            else
                print("Token Price Display commands:")
                print("/tpd settings - Open settings")
            end
        end
    else
        InterfaceOptions_AddCategory(panel)
        SLASH_TOKENPRICEDISPLAY1 = "/tpd"
        SlashCmdList["TOKENPRICEDISPLAY"] = function()
            InterfaceOptionsFrame_OpenToCategory(panel)
        end
    end
end

-- Event Handling
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitSettings()
        SetupFrame()
        LoadFramePosition()
        ApplySettings()
        CreateSettingsPanel()
        C_WowTokenPublic.UpdateMarketPrice()
        
    elseif event == "PLAYER_LOGIN" then
        LoadFramePosition()
        ApplySettings()
        alertState.lowTriggered = false
        alertState.highTriggered = false
        
        if not updateTicker then
            updateTicker = C_Timer.NewTicker(300, function()
                C_WowTokenPublic.UpdateMarketPrice()
            end)
        end
        
    elseif event == "PLAYER_LOGOUT" then
        SaveFramePosition()
        
    elseif event == "TOKEN_MARKET_PRICE_UPDATED" then
        UpdateTokenPrice()
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")