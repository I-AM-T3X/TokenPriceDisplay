-- Create a frame for the addon
local frame = CreateFrame("Frame", "TokenPriceFrame", UIParent, "BackdropTemplate")
frame:SetSize(180, 30)  -- Initial size; this will be adjusted dynamically
frame:SetPoint("CENTER")  -- Position it at the center of the screen
frame:SetMovable(true)  -- Make the frame movable
frame:EnableMouse(true)  -- Enable mouse interaction
frame:RegisterForDrag("LeftButton")  -- Register for dragging with the left mouse button
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
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
priceText:SetPoint("LEFT", labelText, "RIGHT", 6, 0)  -- Position the price text next to the label
priceText:SetTextColor(1, 1, 1)  -- White color for the price

-- Function to update the frame size dynamically based on content width
local function UpdateFrameSize()
    local totalWidth = labelText:GetStringWidth() + priceText:GetStringWidth() + 30  -- Calculate total width needed for both texts
    frame:SetWidth(totalWidth)  -- Set the frame width dynamically
end

-- Function to update the token price
local function UpdateTokenPrice()
    C_WowTokenPublic.UpdateMarketPrice()  -- Request an update of the market price
    local price = C_WowTokenPublic.GetCurrentMarketPrice()
    if price then
        priceText:SetText(GetCoinTextureString(price))  -- Set the text to the formatted price
    else
        priceText:SetText("N/A")  -- Set the text if price is not available
    end
    UpdateFrameSize()  -- Update the frame size based on the new content
end

-- Set up an OnUpdate handler to check the price every 5 minutes (300 seconds)
local function OnUpdate(self, elapsed)
    self.timeSinceLastUpdate = (self.timeSinceLastUpdate or 0) + elapsed
    if self.timeSinceLastUpdate >= 300 then  -- 300 seconds = 5 minutes
        UpdateTokenPrice()
        self.timeSinceLastUpdate = 0
    end
end

-- Initialize the frame
frame:SetScript("OnUpdate", OnUpdate)
UpdateTokenPrice()  -- Initial update when the addon is loaded
