-- Main frame and locals
local addonName, addon = ...
local frame = CreateFrame("Frame", "TokenPriceFrame", UIParent, "BackdropTemplate")
local labelText, priceText, priceIndicator
local updateTicker
local historyFrame = nil
local lastAlertTime = 0

-- Fixed scale constants (only used as fallback, now dynamically calculated)
local GRAPH_MIN_PRICE = 0
local GRAPH_MAX_PRICE = 750000
local MIN_TIME_BETWEEN_RECORDS = 240 -- 4 minutes minimum between data points to avoid spam
local ALERT_COOLDOWN = 240 -- 4 minutes between chat alerts to prevent spam

-- Frequency options for the dropdown (seconds)
local FREQUENCY_OPTIONS = {
    { text = "5 minutes", value = 300 },
    { text = "10 minutes", value = 600 },
    { text = "30 minutes", value = 1800 },
    { text = "1 hour", value = 3600 },
}

-- Default configuration values for first-time users
local DEFAULTS = {
    frameColor = {1, 1, 1, 1},
    textColor = {1, 0.82, 0, 1},
    iconSize = 30,
    displayType = "text",
    showArrow = true,
    alertEnabled = false,
    alertLowThreshold = nil,
    alertHighThreshold = nil,
    updateInterval = 300, -- Default 5 minutes
}

-- Utility: Format copper value as "XX,XXXg" with gold color code
-- Converts 250000 copper to "25|cffd700g|r" format
local function FormatGold(number)
    if not number then return "N/A" end
    local gold = math.floor(number / 10000)
    local formatted = tostring(gold):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return formatted .. "|cffffd700g|r"
end

-- Utility: Format Unix timestamp to "MM/DD HH:MM" for tooltips
local function FormatTime(timestamp)
    return date("%m/%d %H:%M", timestamp)
end

-- Initialize saved variables with default values if they don't exist
-- Also validates that color tables are properly formatted
local function InitSettings()
    TokenPriceDisplayDB = TokenPriceDisplayDB or {}
    TokenPriceDisplaySettings = TokenPriceDisplaySettings or {}
    TokenPriceHistoryDB = TokenPriceHistoryDB or {}
    
    if not TokenPriceHistoryDB.prices then
        TokenPriceHistoryDB.prices = {}
    end
    
    -- Set any missing settings to defaults
    for k, v in pairs(DEFAULTS) do
        if TokenPriceDisplaySettings[k] == nil then
            TokenPriceDisplaySettings[k] = v
        end
    end
    
    -- Ensure color tables are valid (not accidentally set to strings/numbers)
    if type(TokenPriceDisplaySettings.frameColor) ~= "table" then
        TokenPriceDisplaySettings.frameColor = DEFAULTS.frameColor
    end
    if type(TokenPriceDisplaySettings.textColor) ~= "table" then
        TokenPriceDisplaySettings.textColor = DEFAULTS.textColor
    end
    if not TokenPriceDisplaySettings.updateInterval then
        TokenPriceDisplaySettings.updateInterval = DEFAULTS.updateInterval
    end
end

-- Records current price to history database with duplicate filtering
-- Only records if 4+ minutes passed OR price changed by more than 10,000g
-- Also trims old data (keeps 7 days max, max 1008 entries)
local function RecordPriceHistory(price)
    if not price then return end
    
    local now = time()
    local lastEntry = TokenPriceHistoryDB.prices[#TokenPriceHistoryDB.prices]
    
    -- Filter: skip if too soon AND price change is small
    if lastEntry then
        local timeDiff = now - lastEntry.timestamp
        local priceDiff = math.abs(lastEntry.price - price)
        
        if timeDiff < MIN_TIME_BETWEEN_RECORDS and priceDiff <= 100000 then
            return
        end
    end
    
    local entry = {
        timestamp = now,
        price = price
    }
    
    table.insert(TokenPriceHistoryDB.prices, entry)
    
    -- Keep max 1008 entries (about 3.5 days at 5-min intervals)
    while #TokenPriceHistoryDB.prices > 1008 do
        table.remove(TokenPriceHistoryDB.prices, 1)
    end
    
    -- Remove entries older than 7 days
    local cutoff = time() - (7 * 24 * 60 * 60)
    while #TokenPriceHistoryDB.prices > 0 and TokenPriceHistoryDB.prices[1].timestamp < cutoff do
        table.remove(TokenPriceHistoryDB.prices, 1)
    end
end

-- Creates the history window with bar chart visualization
-- Shows price history data with dynamic Y-axis scaling
local function CreateHistoryFrame()
    if historyFrame then return historyFrame end
    
    local f = CreateFrame("Frame", "TokenPriceHistoryFrame", UIParent, "BackdropTemplate")
    f:SetSize(600, 440)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    
    -- Static title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -20)
    title:SetText("WoW Token Price History")
    
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    
    local graphWidth = 550
    local graphHeight = 300
    local graph = CreateFrame("Frame", nil, f, "BackdropTemplate")
    graph:SetSize(graphWidth, graphHeight)
    graph:SetPoint("CENTER", f, "CENTER", 0, 20)
    graph:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
    })
    graph:SetBackdropColor(0, 0, 0, 0.6)
    
    graph.bars = {}
    graph.points = {}
    
    local minLabel = graph:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minLabel:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", 5, 5)
    minLabel:SetTextColor(0.7, 0.7, 0.7)
    
    local maxLabel = graph:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    maxLabel:SetPoint("TOPLEFT", graph, "TOPLEFT", 5, -5)
    maxLabel:SetTextColor(0.7, 0.7, 0.7)
    
    local currentLabel = graph:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    currentLabel:SetPoint("BOTTOMRIGHT", graph, "BOTTOMRIGHT", -5, 5)
    currentLabel:SetTextColor(0, 1, 0)
    
    local statsFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    statsFrame:SetSize(400, 30)
    statsFrame:SetPoint("BOTTOM", f, "BOTTOM", 0, 50)
    statsFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    statsFrame:SetBackdropColor(0, 0, 0, 0.8)
    statsFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    
    local statsText = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsText:SetPoint("CENTER", statsFrame, "CENTER", 0, 0)
    statsText:SetText("Loading statistics...")
    
    -- Clears all bar textures and tooltip buttons from previous render
    function graph:ClearGraph()
        for _, bar in pairs(self.bars) do bar:Hide() end
        for _, point in pairs(self.points) do point:Hide() end
        wipe(self.bars)
        wipe(self.points)
    end
    
    -- Draws a single bar on the graph with specified height and color
    -- isCurrent adds a glow effect to the most recent price point
    function graph:DrawBar(x, height, maxHeight, color, isCurrent)
        local barWidth = 2
        local bar = self:CreateTexture(nil, "ARTWORK")
        bar:SetTexture("Interface\\Buttons\\WHITE8X8")
        bar:SetVertexColor(unpack(color or {0.2, 0.8, 0.2}))
        
        local y = 20
        bar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x, y)
        bar:SetSize(barWidth, height)
        bar:Show()
        table.insert(self.bars, bar)
        
        local dot = self:CreateTexture(nil, "OVERLAY")
        dot:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
        dot:SetSize(4, 4)
        dot:SetPoint("CENTER", bar, "TOP", 0, 0)
        dot:SetVertexColor(1, 0.82, 0)
        dot:Show()
        table.insert(self.bars, dot)
        
        if isCurrent then
            local glow = self:CreateTexture(nil, "OVERLAY")
            glow:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
            glow:SetSize(8, 8)
            glow:SetPoint("CENTER", bar, "TOP", 0, 0)
            glow:SetVertexColor(1, 0.82, 0, 0.5)
            glow:Show()
            table.insert(self.bars, glow)
        end
        
        return bar -- Return bar for tooltip anchoring
    end
    
    -- Main graph rendering function - calculates dynamic scale and draws all bars
    -- Now uses actual data min/max instead of fixed 0-750k scale for better visibility
    function graph:UpdateData()
        self:ClearGraph()
        
        local data = TokenPriceHistoryDB.prices
        if #data < 2 then
            local msg = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            msg:SetPoint("CENTER", self, "CENTER")
            msg:SetText("Not enough data yet...\nCheck back after a few price updates!")
            table.insert(self.points, msg)
            statsText:SetText("No historical data available")
            return
        end
        
        -- Calculate actual min/max from data for dynamic scaling
        local minPrice = math.huge
        local maxPrice = 0
        for _, entry in ipairs(data) do
            local gold = entry.price / 10000
            if gold < minPrice then minPrice = gold end
            if gold > maxPrice then maxPrice = gold end
        end
        
        -- Add padding so bars don't touch edges (10% of range or 5000g minimum)
        local priceRange = maxPrice - minPrice
        local padding = math.max(priceRange * 0.1, 5000)
        
        local displayMin = math.max(0, minPrice - padding)
        local displayMax = maxPrice + padding
        
        -- Ensure minimum 20,000g range so flat prices don't look broken
        if displayMax - displayMin < 20000 then
            displayMax = displayMin + 20000
        end
        
        statsText:SetText(string.format("Session High: %s%s|r | Session Low: %s%s|r | Points: %d", 
            "|cff00ff00", FormatGold(maxPrice * 10000),
            "|cffff0000", FormatGold(minPrice * 10000),
            #data))
        
        minLabel:SetText(FormatGold(displayMin * 10000))
        maxLabel:SetText(FormatGold(displayMax * 10000))
        local current = data[#data]
        currentLabel:SetText("Current: " .. FormatGold(current.price))
        
        local leftPadding = 40
        local rightPadding = 20
        local bottomPadding = 20
        local topPadding = 20
        local drawWidth = graphWidth - leftPadding - rightPadding
        local drawHeight = graphHeight - bottomPadding - topPadding
        
        local timeRange = data[#data].timestamp - data[1].timestamp
        if timeRange == 0 then timeRange = 1 end
        
        local maxBars = math.min(#data, 100)
        local step = math.ceil(#data / maxBars)
        
        local barCount = 0
        for i = 1, #data, step do
            local entry = data[i]
            local isLast = (i >= #data - step + 1)
            
            local x = leftPadding + (barCount / (maxBars - 1)) * drawWidth
            
            -- Use dynamic scale instead of fixed 0-750k scale
            local normalizedPrice = (entry.price/10000 - displayMin) / (displayMax - displayMin)
            normalizedPrice = math.max(0, math.min(1, normalizedPrice))
            local barHeight = normalizedPrice * drawHeight
            
            -- Color based on trend: green up, red down, gray same
            local color = {0.2, 0.8, 0.2}
            if i > 1 then
                if entry.price > data[i-1].price then
                    color = {0, 1, 0}      -- Bright green for increase
                elseif entry.price < data[i-1].price then
                    color = {1, 0.2, 0.2}  -- Red for decrease
                else
                    color = {0.8, 0.8, 0.8} -- Gray for no change
                end
            end
            
            local bar = self:DrawBar(x, math.max(2, barHeight), drawHeight, color, isLast)
            
            -- TOOLTIP FIX: Position tooltip button at the bar location, not full height
            local tooltipBtn = CreateFrame("Button", nil, self)
            local btnHeight = math.max(barHeight + 15, 30)
            tooltipBtn:SetSize(12, btnHeight)
            tooltipBtn:SetPoint("BOTTOM", self, "BOTTOMLEFT", x + 1, 20)
            tooltipBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(FormatTime(entry.timestamp))
                GameTooltip:AddLine(FormatGold(entry.price), 1, 0.82, 0)
                if isLast then
                    GameTooltip:AddLine("Current Price", 0, 1, 0)
                end
                GameTooltip:Show()
            end)
            tooltipBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            table.insert(self.points, tooltipBtn)
            
            barCount = barCount + 1
            if barCount >= maxBars then break end
        end
    end
    
    f.graph = graph
    
    -- Clear History button with confirmation dialog
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(120, 25)
    clearBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
    clearBtn:SetText("Clear History")
    clearBtn:SetScript("OnClick", function()
        StaticPopupDialogs["CONFIRM_CLEAR_TOKEN_HISTORY"] = {
            text = "Are you sure you want to clear all price history?",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                TokenPriceHistoryDB.prices = {}
                graph:UpdateData()
                print("|cffff0000[Token Price Display]: Price history cleared.|r")
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("CONFIRM_CLEAR_TOKEN_HISTORY")
    end)
    
    historyFrame = f
    return f
end

-- Toggles visibility of the history window
-- Refreshes graph data each time it's shown to display latest prices
local function ToggleHistoryFrame()
    if not historyFrame then
        CreateHistoryFrame()
    end
    
    if historyFrame:IsShown() then
        historyFrame:Hide()
    else
        historyFrame.graph:UpdateData()
        historyFrame:Show()
    end
end

-- Saves current frame position to saved variables
-- Called when dragging stops or logging out
local function SaveFramePosition()
    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
    if point then
        TokenPriceDisplayDB.point = point
        TokenPriceDisplayDB.relativePoint = relativePoint
        TokenPriceDisplayDB.xOfs = xOfs
        TokenPriceDisplayDB.yOfs = yOfs
    end
end

-- Restores frame position from saved variables
-- Called on login or after settings are initialized
local function LoadFramePosition()
    if TokenPriceDisplayDB.point then
        frame:ClearAllPoints()
        frame:SetPoint(TokenPriceDisplayDB.point, UIParent, TokenPriceDisplayDB.relativePoint, TokenPriceDisplayDB.xOfs, TokenPriceDisplayDB.yOfs)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- Creates the main draggable frame that displays current token price
-- Sets up border, fonts, tooltip, and mouse interaction (drag to move, right-click for history)
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
    
    -- Right-click opens history window
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            ToggleHistoryFrame()
        end
    end)
    
    -- Tooltip on hover
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("WoW Token Price")
        GameTooltip:AddLine("Right-click for history", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("LEFT", frame, "LEFT", 10, 0)
    labelText:SetText("WoW Token:")
    
    priceText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    priceText:SetPoint("LEFT", labelText, "RIGHT", 5, 0)
    priceText:SetTextColor(1, 1, 1)
    
    priceIndicator = frame:CreateTexture(nil, "OVERLAY")
    priceIndicator:SetSize(16, 16)
    priceIndicator:Hide()
end

-- Resizes the main frame based on content (icon mode vs text mode, arrows, etc.)
-- Called whenever display settings change or price updates
local function AdjustFrameSize()
    if TokenPriceDisplaySettings.displayType == "icon" then
        local iconWidth = TokenPriceDisplaySettings.iconSize
        local textWidth = priceText:GetStringWidth()
        local width = 5 + iconWidth + 5 + textWidth + 10
        frame:SetWidth(width)
        frame:SetHeight(math.max(30, TokenPriceDisplaySettings.iconSize + 4))
    else
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

-- Applies all visual settings to the main frame
-- Colors, display mode (icon vs text), visibility of arrow indicator
local function ApplySettings()
    frame:SetBackdropBorderColor(unpack(TokenPriceDisplaySettings.frameColor))
    labelText:SetTextColor(unpack(TokenPriceDisplaySettings.textColor))
    
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
    
    if not TokenPriceDisplaySettings.showArrow then
        priceIndicator:Hide()
    end
    
    AdjustFrameSize()
end

-- Opens the WoW color picker to change frame border or text color
-- Updates the frame in real-time as user adjusts color
-- colorType: "frame" for border color, "text" for text color
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

-- Resets frame and text colors to addon defaults (white border, gold text)
local function ResetToDefaultColors()
    TokenPriceDisplaySettings.frameColor = {unpack(DEFAULTS.frameColor)}
    TokenPriceDisplaySettings.textColor = {unpack(DEFAULTS.textColor)}
    ApplySettings()
end

-- Checks if current price triggers alert thresholds
-- Respects 4-minute cooldown between alerts to prevent spam
-- Prints colored message to chat if alert conditions met
local function CheckAlerts(currentGold)
    if not TokenPriceDisplaySettings.alertEnabled then return end
    
    local now = time()
    if now - lastAlertTime < ALERT_COOLDOWN then
        return
    end
    
    local low = TokenPriceDisplaySettings.alertLowThreshold
    local high = TokenPriceDisplaySettings.alertHighThreshold
    local alerted = false
    
    if low and currentGold <= low then
        print(string.format("|cffff0000[Token Alert]: WoW Token price is %s! (Below threshold: %s)|r", 
            FormatGold(currentGold * 10000), 
            FormatGold(low * 10000)))
        alerted = true
    end
    
    if high and currentGold >= high then
        print(string.format("|cff00ff00[Token Alert]: WoW Token price is %s! (Above threshold: %s)|r", 
            FormatGold(currentGold * 10000), 
            FormatGold(high * 10000)))
        alerted = true
    end
    
    if alerted then
        lastAlertTime = now
    end
end

-- Fetches current token price from WoW API and updates display
-- Records to history, shows up/down arrow based on last price, checks alerts
-- Also refreshes history graph if it's currently open
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
    
    RecordPriceHistory(price)
    
    -- Determine arrow direction (up/down/same) or icon mode
    local lastPrice = TokenPriceDisplaySettings.lastKnownPrice
    if lastPrice and TokenPriceDisplaySettings.showArrow and TokenPriceDisplaySettings.displayType ~= "icon" then
        if goldPrice > lastPrice then
            priceIndicator:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
            priceIndicator:SetVertexColor(0, 1, 0)  -- Green for up
        elseif goldPrice < lastPrice then
            priceIndicator:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
            priceIndicator:SetVertexColor(1, 0, 0)  -- Red for down
        else
            priceIndicator:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            priceIndicator:SetVertexColor(1, 1, 1)  -- White for no change
        end
        priceIndicator:Show()
    elseif TokenPriceDisplaySettings.displayType == "icon" then
        priceIndicator:SetTexture("Interface\\Icons\\wow_token01")
        priceIndicator:SetVertexColor(1, 1, 1)
        priceIndicator:Show()
    elseif not TokenPriceDisplaySettings.showArrow then
        priceIndicator:Hide()
    end
    
    TokenPriceDisplaySettings.lastKnownPrice = goldPrice
    AdjustFrameSize()
    CheckAlerts(goldPrice)
    
    -- Refresh history graph if open
    if historyFrame and historyFrame:IsShown() then
        historyFrame.graph:UpdateData()
    end
end

-- Cancels existing timer and creates new one with specified interval
-- Called when user changes frequency in settings
local function RestartTicker()
    if updateTicker then
        updateTicker:Cancel()
    end
    
    local interval = TokenPriceDisplaySettings.updateInterval or 300
    updateTicker = C_Timer.NewTicker(interval, function()
        C_WowTokenPublic.UpdateMarketPrice()
    end)
    
    print(string.format("|cff00ff00[Token Price Display]: Update frequency set to %d minutes|r", interval / 60))
end

-- Creates the settings panel in Interface Options
-- Organized into sections: Update Frequency, Appearance, Price Alerts, Actions
local function CreateSettingsPanel()
    local panel = CreateFrame("Frame", "TokenPriceDisplaySettingsPanel")
    panel.name = "Token Price Display"
    
    -- Title area 
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText("Token Price Display Settings")
    
    -- White text for subtitle
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Customize appearance and behavior")
    subtitle:SetWidth(500)
    
    -- Content frame
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -15)
    content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 10)
    
    local yPos = 0
    local contentWidth = 520
    
    -- Helper: Creates a bordered section container with header and optional description
    local function CreateSection(titleText, descText)
        local box = CreateFrame("Frame", nil, content, "BackdropTemplate")
        box:SetSize(contentWidth, 100)
        box:SetPoint("TOPLEFT", 0, yPos)
        box:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        box:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        box:SetBackdropColor(0, 0, 0, 0.2)
        
        local header = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header:SetPoint("TOPLEFT", 15, -12)
        header:SetText("|cffffd700" .. titleText .. "|r")
        
        if descText then
            local desc = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            desc:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
            desc:SetText(descText)
            desc:SetWidth(contentWidth - 30)
            desc:SetJustifyH("LEFT")
        end
        
        yPos = yPos - 30
        return box
    end
    
    -- Helper: Creates label for a setting control, returns x position for control placement
    local function AddControl(section, labelText, yOffset)
        local label = section:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 15, yOffset)
        label:SetText(labelText)
        label:SetWidth(100)
        label:SetJustifyH("LEFT")
        return 120, yOffset
    end
    
    -- SECTION 1: Update Frequency - Dropdown for how often to check prices
    local section1 = CreateSection("Update Frequency", "How often to check for new token prices")
    
    local ctrlX, cy = AddControl(section1, "Frequency:", -50)
    local dropdown = CreateFrame("Frame", "TokenPriceDisplayFreqDropDown", section1, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", section1, "TOPLEFT", ctrlX - 15, cy + 5)
    UIDropDownMenu_SetWidth(dropdown, 130)
    
    local function InitializeDropDown(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, option in ipairs(FREQUENCY_OPTIONS) do
            info.text = option.text
            info.value = option.value
            info.func = function()
                UIDropDownMenu_SetSelectedValue(dropdown, option.value)
                TokenPriceDisplaySettings.updateInterval = option.value
                RestartTicker()
            end
            info.checked = (TokenPriceDisplaySettings.updateInterval == option.value)
            UIDropDownMenu_AddButton(info)
        end
    end
    UIDropDownMenu_Initialize(dropdown, InitializeDropDown)
    UIDropDownMenu_SetSelectedValue(dropdown, TokenPriceDisplaySettings.updateInterval or 300)
    
    section1:SetHeight(70)
    yPos = yPos - 75
    
    -- SECTION 2: Appearance - Color pickers, icon mode, arrow toggle
    local section2 = CreateSection("Appearance", "Customize colors, icons, and indicators")
    
    -- Color pickers row
    local cx, cy = AddControl(section2, "Border:", -50)
    local colorBtn1 = CreateFrame("Button", nil, section2, "UIPanelButtonTemplate")
    colorBtn1:SetSize(70, 22)
    colorBtn1:SetPoint("TOPLEFT", cx - 10, cy + 5)
    colorBtn1:SetText("Change")
    colorBtn1:SetScript("OnClick", function() ShowColorPicker("frame") end)
    
    local colorLabel2 = section2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    colorLabel2:SetPoint("TOPLEFT", 220, cy)
    colorLabel2:SetText("Text:")
    
    local colorBtn2 = CreateFrame("Button", nil, section2, "UIPanelButtonTemplate")
    colorBtn2:SetSize(70, 22)
    colorBtn2:SetPoint("TOPLEFT", 265, cy + 5)
    colorBtn2:SetText("Change")
    colorBtn2:SetScript("OnClick", function() ShowColorPicker("text") end)
    
    -- Checkboxes 
    local iconCb = CreateFrame("CheckButton", nil, section2, "InterfaceOptionsCheckButtonTemplate")
    iconCb:SetPoint("TOPLEFT", 15, -85)
    iconCb.Text:SetText("Show Token Icon")
    iconCb:SetChecked(TokenPriceDisplaySettings.displayType == "icon")
    iconCb:SetScript("OnClick", function(self)
        TokenPriceDisplaySettings.displayType = self:GetChecked() and "icon" or "text"
        ApplySettings()
        C_WowTokenPublic.UpdateMarketPrice()
    end)
    
    local arrowCb = CreateFrame("CheckButton", nil, section2, "InterfaceOptionsCheckButtonTemplate")
    arrowCb:SetPoint("TOPLEFT", 250, -85)
    arrowCb.Text:SetText("Show Change Arrow")
    arrowCb:SetChecked(TokenPriceDisplaySettings.showArrow)
    arrowCb:SetScript("OnClick", function(self)
        TokenPriceDisplaySettings.showArrow = self:GetChecked()
        ApplySettings()
    end)
    
    section2:SetHeight(115)
    yPos = yPos - 120
    
    -- SECTION 3: Price Alerts - Enable/disable and threshold inputs
    local section3 = CreateSection("Price Alerts", "Get notified when price crosses your set thresholds")
    
    local alertCb = CreateFrame("CheckButton", nil, section3, "InterfaceOptionsCheckButtonTemplate")
    alertCb:SetPoint("TOPLEFT", 15, -50)
    alertCb.Text:SetText("Enable Price Alerts")
    alertCb:SetChecked(TokenPriceDisplaySettings.alertEnabled)
    
    -- Low/High threshold inputs
    local lowLabel = section3:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lowLabel:SetPoint("TOPLEFT", 35, -80)
    lowLabel:SetText("Low:")
    
    local lowEdit = CreateFrame("EditBox", nil, section3, "InputBoxTemplate")
    lowEdit:SetSize(80, 20)
    lowEdit:SetPoint("TOPLEFT", 70, -76)
    lowEdit:SetAutoFocus(false)
    lowEdit:SetNumeric(true)
    lowEdit:SetText(TokenPriceDisplaySettings.alertLowThreshold or "")
    
    local lowGold = section3:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lowGold:SetPoint("LEFT", lowEdit, "RIGHT", 4, 0)
    lowGold:SetText("|cffffd700g|r")
    
    local highLabel = section3:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    highLabel:SetPoint("TOPLEFT", 200, -80)
    highLabel:SetText("High:")
    
    local highEdit = CreateFrame("EditBox", nil, section3, "InputBoxTemplate")
    highEdit:SetSize(80, 20)
    highEdit:SetPoint("TOPLEFT", 240, -76)
    highEdit:SetAutoFocus(false)
    highEdit:SetNumeric(true)
    highEdit:SetText(TokenPriceDisplaySettings.alertHighThreshold or "")
    
    local highGold = section3:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    highGold:SetPoint("LEFT", highEdit, "RIGHT", 4, 0)
    highGold:SetText("|cffffd700g|r")
    
    -- Cooldown note
    local note = section3:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    note:SetPoint("TOPLEFT", 35, -100)
    note:SetWidth(450)
    note:SetJustifyH("LEFT")
    note:SetText("Note: Alerts have a 4-minute cooldown when logging in and switching characters")
    
    -- Enable/disable text input fields based on checkbox state
    local function UpdateAlertEdits()
        local enabled = alertCb:GetChecked()
        lowEdit:SetEnabled(enabled)
        highEdit:SetEnabled(enabled)
        local color = enabled and {1, 1, 1} or {0.5, 0.5, 0.5}
        lowEdit:SetTextColor(unpack(color))
        highEdit:SetTextColor(unpack(color))
    end
    
    alertCb:SetScript("OnClick", function(self)
        TokenPriceDisplaySettings.alertEnabled = self:GetChecked()
        UpdateAlertEdits()
    end)
    
    lowEdit:SetScript("OnEnterPressed", function(self)
        local num = tonumber(self:GetText())
        if num and num >= 0 then
            TokenPriceDisplaySettings.alertLowThreshold = num
            self:ClearFocus()
        else
            self:SetText("")
        end
    end)
    
    highEdit:SetScript("OnEnterPressed", function(self)
        local num = tonumber(self:GetText())
        if num and num >= 0 then
            TokenPriceDisplaySettings.alertHighThreshold = num
            self:ClearFocus()
        else
            self:SetText("")
        end
    end)
    
    UpdateAlertEdits()
    
    section3:SetHeight(118)
    yPos = yPos - 125
    
    -- SECTION 4: Actions - Utility buttons
    local section4 = CreateSection("Actions", nil)
    
    local historyBtn = CreateFrame("Button", nil, section4, "UIPanelButtonTemplate")
    historyBtn:SetSize(130, 24)
    historyBtn:SetPoint("TOPLEFT", 15, -45)
    historyBtn:SetText("View History")
    historyBtn:SetScript("OnClick", ToggleHistoryFrame)
    
    local resetBtn = CreateFrame("Button", nil, section4, "UIPanelButtonTemplate")
    resetBtn:SetSize(130, 24)
    resetBtn:SetPoint("LEFT", historyBtn, "RIGHT", 15, 0)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        ResetToDefaultColors()
        TokenPriceDisplaySettings.displayType = DEFAULTS.displayType
        TokenPriceDisplaySettings.showArrow = DEFAULTS.showArrow
        TokenPriceDisplaySettings.alertEnabled = DEFAULTS.alertEnabled
        TokenPriceDisplaySettings.alertLowThreshold = DEFAULTS.alertLowThreshold
        TokenPriceDisplaySettings.alertHighThreshold = DEFAULTS.alertHighThreshold
        TokenPriceDisplaySettings.updateInterval = DEFAULTS.updateInterval
        
        RestartTicker()
        
        iconCb:SetChecked(TokenPriceDisplaySettings.displayType == "icon")
        arrowCb:SetChecked(TokenPriceDisplaySettings.showArrow)
        alertCb:SetChecked(TokenPriceDisplaySettings.alertEnabled)
        lowEdit:SetText("")
        highEdit:SetText("")
        UIDropDownMenu_SetSelectedValue(dropdown, TokenPriceDisplaySettings.updateInterval)
        UpdateAlertEdits()
        
        print("|cff00ff00[Token Price Display]: Settings reset to default|r")
    end)
    
    section4:SetHeight(75)
    
    -- Register with WoW settings system (Dragonflight+ uses new API, older uses legacy)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        
        SLASH_TOKENPRICEDISPLAY1 = "/tpd"
        SlashCmdList["TOKENPRICEDISPLAY"] = function(msg)
            if msg == "settings" then
                Settings.OpenToCategory(category:GetID())
            elseif msg == "history" then
                ToggleHistoryFrame()
            else
                print("|cff00ff00[Token Price Display]:|r /tpd settings | /tpd history")
            end
        end
    else
        InterfaceOptions_AddCategory(panel)
        SLASH_TOKENPRICEDISPLAY1 = "/tpd"
        SlashCmdList["TOKENPRICEDISPLAY"] = function(msg)
            if msg == "history" then
                ToggleHistoryFrame()
            else
                InterfaceOptionsFrame_OpenToCategory(panel)
            end
        end
    end
end

-- Main event handler - manages addon lifecycle
-- ADDON_LOADED: Initialize everything
-- PLAYER_LOGIN: Start price updates and restore position  
-- PLAYER_LOGOUT: Save position
-- TOKEN_MARKET_PRICE_UPDATED: Price changed, update display
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
        
        lastAlertTime = time()
        
        if not updateTicker then
            local interval = TokenPriceDisplaySettings.updateInterval or 300
            updateTicker = C_Timer.NewTicker(interval, function()
                C_WowTokenPublic.UpdateMarketPrice()
            end)
        end
        
        local current = C_WowTokenPublic.GetCurrentMarketPrice()
        if current then
            RecordPriceHistory(current)
        end
        
    elseif event == "PLAYER_LOGOUT" then
        SaveFramePosition()
        
    elseif event == "TOKEN_MARKET_PRICE_UPDATED" then
        UpdateTokenPrice()
    end
end)

-- Register for required events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")