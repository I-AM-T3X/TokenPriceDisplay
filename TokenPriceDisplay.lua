-- Initialize the saved variable if it doesn't exist
if not TokenPriceDisplayDB then
    TokenPriceDisplayDB = {}
end

-- Create a frame for the addon
local frame = CreateFrame("Frame", "TokenPriceFrame", UIParent, "BackdropTemplate")
frame:SetSize(180, 30)  -- Initial size; this will be adjusted dynamically

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
        frame:ClearAllPoints()  -- Clear any existing points to avoid conflicts
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
    SaveFramePosition()  -- Save the new position when the frame is moved
end)

-- Set the frame backdrop
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",  -- Background texture
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",  -- Tooltip-style border texture
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})

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
