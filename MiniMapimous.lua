-- Create our addon's main frame and register events
local frame = CreateFrame("Frame")
local addonName, addon = ...

-- Store button information for restoration
addon.buttonInfo = {}

-- Initialize saved variables with defaults and version tracking
local VERSION_COUNTER = 1

local defaultOptions = {
    hideButtons = true,
    minimapScale = 1.0,
    barTransparency = 0.4,
    showBlizzardButtons = true,
    barPosition = "LEFT",
    anchorToMinimap = true,
    hideZoomButtons = false,
    hideCalendar = false,
    hideTime = false,
    hideAddonCompartment = false,
    detachBar = false,
    minimizeBar = false,
    autoCollapse = true,
    showDataTexts = false,
    whitelist = {
        -- Common addon buttons that should always be collected
        ZygorGuidesViewerMapIcon = true,
        TrinketMenu_IconFrame = true,
        CodexBrowserIcon = true,
        ExpansionLandingPageMinimapButton = true,
        KhazSummaryButton = true,
        KhazAlgarSummaryButton = true,
        KhazSummaryMinimapButton = true,
        -- User requested addons
        CellMinimapButton = true,
        KalielTrackerMinimapButton = true,
        QuazziUIMinimapButton = true,
        WeakAurasMinimapButton = true,
        -- Common variations
        Cell = true,
        KalielTracker = true,
        QuazziUI = true,
        WeakAuras = true,
    },
    blacklist = {},
    buttonScale = 1.0,
    version = 0,
}

-- Button Collection Module
local ButtonCollection = addon.export("ButtonCollection", {
    collectedButtons = {},
    processedButtons = {},
    buttonTypes = {},
})

function ButtonCollection:isButtonCollected(button)
    local name = button:GetName()
    return name and self.processedButtons[name]
end

function ButtonCollection:addButton(button, buttonType)
    if not button then return end
    local name = button:GetName()
    if not name or self.processedButtons[name] then return end

    -- Just add the button to our collection - positioning will handle data storage
    table.insert(self.collectedButtons, button)
    self.processedButtons[name] = true
    self.buttonTypes[name] = buttonType
end

function ButtonCollection:restore()
    for _, button in ipairs(self.collectedButtons) do
        if button.minimapimousOriginal then
            local orig = button.minimapimousOriginal
            
            -- Simply restore original position and parent
            button:SetParent(orig.parent)
            button:SetScale(orig.scale)
            button:SetFrameStrata(orig.strata)
            button:SetFrameLevel(orig.level)
            
            -- Restore original points
            button:ClearAllPoints()
            for _, pointData in ipairs(orig.points) do
                local point, relativeTo, relativePoint, x, y = unpack(pointData)
                button:SetPoint(point, relativeTo, relativePoint, x, y)
            end
            
            -- Clean up our data
            button.minimapimousOriginal = nil
        end
    end
    self:clear()
end

function ButtonCollection:clear()
    wipe(self.collectedButtons)
    wipe(self.processedButtons)
    wipe(self.buttonTypes)
end

-- Button Identification Module
local ButtonIdentification = {
    blizzardButtons = {
        -- Calendar
        GameTimeFrame = "Calendar",
        MinimapClusterCalendar = "Calendar",
        CalendarButtonFrame = "Calendar",
        
        -- Clock
        TimeManagerClockButton = "Clock",
        MinimapClusterClock = "Clock",
        
        -- Tracking
        MinimapTracking = "Tracking",
        MinimapClusterTracking = "Tracking",
        MiniMapTracking = "Tracking",
        MinimapClusterTrackingButton = "Tracking",
        
        -- Queue
        QueueStatusButton = "Queue",
        QueueStatusMinimapButton = "Queue",
        MiniMapLFGFrame = "Queue",
        MinimapQueueFrame = "Queue",
        
        -- Map
        MinimapToggleButton = "Map",
        MiniMapWorldMapButton = "Map",
        MinimapClusterWorldMap = "Map",
        
        -- Mail
        MiniMapMailFrame = "Mail",
        MinimapMailIcon = "Mail",
        MinimapClusterMail = "Mail",
        MinimapClusterMailButton = "Mail",
        MailFrame = "Mail",
        MinimapMail = "Mail",
        
        -- Addon Compartment
        AddonCompartmentFrame = "AddonCompartment",
        MinimapClusterAddonCompartment = "AddonCompartment",
        
        -- Social
        QuickJoinToastButton = "Social",
        QuickJoinFrame = "Social",
        MinimapClusterSocialButton = "Social",
        
        -- Ping
        MinimapPingFrame = "Ping",
        MinimapPing = "Ping"
    },
    
    buttonPatterns = {
        "^LibDBIcon10_",  -- LibDBIcon buttons
        "MinimapButton",  -- Standard minimap button naming
        "MinimapFrame",   -- Frame-based buttons
        "MinimapIcon",    -- Icon-based buttons
        "[-_]Minimap[-_]", -- Buttons with minimap in middle
        "Minimap$",       -- Buttons ending in minimap
        "^Khaz.*Summary.*Button",
        "Summary.*Button$",
        "^Cell",          -- Cell addon variations
        "^Kaliel",        -- Kaliel Tracker variations
        "^Quazzi",        -- Quazzi UI variations
        "^WeakAuras",     -- WeakAuras variations
        "Tracker.*Button", -- Tracker buttons
        "UI.*Button",     -- UI buttons
    }
}

function ButtonIdentification:isValidFrame(frame)
    if type(frame) ~= "table" then return false end
    if not frame.IsObjectType or not frame:IsObjectType("Frame") then return false end
    return true
end

function ButtonIdentification:isTomCatsButton(frameName)
    return frameName:match("^TomCats%-") ~= nil
end

function ButtonIdentification:nameEndsWithNumber(frameName)
    return frameName:match("%d$") ~= nil
end

function ButtonIdentification:nameMatchesButtonPattern(frameName)
    for _, pattern in ipairs(self.buttonPatterns) do
        if frameName:match(pattern) then
            return true
        end
    end
    return false
end

function ButtonIdentification:identifyButton(button)
    if not button then return nil end
    
    local Options = addon.import("Options")
    local name = button:GetName() or ""

    -- First check whitelist
    if Options:get("whitelist") and Options:get("whitelist")[name] then
        return "Addon"
    end
    
    -- Check for Khaz Algar Summary button specifically
    if name:match("^Khaz.*Summary") or name:match("Summary.*Button$") then
        return "Addon"
    end
    
    -- Then check if it's a known Blizzard button
    if self.blizzardButtons[name] then
        return self.blizzardButtons[name]
    end
    
    -- Check for LibDBIcon buttons
    if name:find("^LibDBIcon") then
        return "Addon"
    end
    
    -- Check for other addon buttons using pattern matching
    if name ~= "" and not name:find("^Minimap") and not name:find("^MinimapCluster") then
        if not self:nameEndsWithNumber(name) or self:isTomCatsButton(name) then
            if self:nameMatchesButtonPattern(name) then
                return "Addon"
            end
        end
    end

    return nil
end

addon.export('ButtonIdentification', ButtonIdentification)

-- Function to update bar visibility based on hideButtonBar setting
function UpdateBarVisibility()
    local Options = addon.import("Options")
    if not addon.buttonBar then
        return
    end
    
    local hideButtonBar = Options:get("hideButtonBar")
    
    -- If hideButtonBar is enabled, handle mouseover functionality
    if hideButtonBar then
        local shouldShow = false
        
        -- Check if mouse is over minimap or button bar
        if MouseIsOver(Minimap) or MouseIsOver(addon.buttonBar) then
            shouldShow = true
        end
        
        -- Also check if mouse is over any of the buttons in the bar
        for _, button in ipairs(addon.collectedAddonButtons or {}) do
            if button and MouseIsOver(button) then
                shouldShow = true
                break
            end
        end
        
        if shouldShow then
            addon.buttonBar:Show()
            addon.buttonBar:SetAlpha(1)
        else
            addon.buttonBar:Hide()
        end
    else
        -- Always show the bar when hideButtonBar is disabled
        addon.buttonBar:Show()
        addon.buttonBar:SetAlpha(1)
        -- Show all buttons
        for _, button in ipairs(addon.collectedAddonButtons or {}) do
            if button then button:Show() end
        end
    end
end

-- Function to position buttons in a bar
local function PositionButtons(buttonList, bar)
    local Options = addon.import("Options")
    if not buttonList or not bar then return 0 end
    
    local padding = 5
    local buttonSize = 24
    local minimapHeight = Minimap:GetHeight() * (Options:get("minimapScale") or 1)
    
    -- Calculate layout
    local availableHeight = minimapHeight - (padding * 2)
    local buttonWithPadding = buttonSize + padding
    local maxButtonsPerColumn = math.max(1, math.floor(availableHeight / buttonWithPadding))
    local totalButtons = #buttonList
    local columnsNeeded = math.ceil(totalButtons / maxButtonsPerColumn)
    local buttonsPerColumn = math.ceil(totalButtons / columnsNeeded)
    local barWidth = (buttonSize * columnsNeeded) + (padding * (columnsNeeded + 1))
    
    bar:SetSize(barWidth, minimapHeight)
    
    -- Position buttons
    for i, button in ipairs(buttonList) do
        -- Store original data for restoration ONLY
        if not button.minimapimousOriginal then
            button.minimapimousOriginal = {
                parent = button:GetParent(),
                points = {},
                scale = button:GetScale(),
                strata = button:GetFrameStrata(),
                level = button:GetFrameLevel()
            }
            
            -- Store all points
            for j = 1, button:GetNumPoints() do
                local point, relativeTo, relativePoint, x, y = button:GetPoint(j)
                table.insert(button.minimapimousOriginal.points, {point, relativeTo, relativePoint, x, y})
            end
        end
        
        -- Calculate position
        local column = math.floor((i - 1) / buttonsPerColumn)
        local row = (i - 1) % buttonsPerColumn
        local xOffset = padding + (column * (buttonSize + padding))
        local yOffset = padding + (row * (buttonSize + padding))
        
        -- Position the button
        button:SetParent(bar)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", bar, "TOPLEFT", xOffset, -yOffset)
        button:SetSize(buttonSize, buttonSize)
        button:SetFrameLevel(bar:GetFrameLevel() + 10)
        
        -- Ensure visibility
        button:Show()
    end
    
    -- Update bar visibility state after positioning
    UpdateBarVisibility()
    
    return #buttonList
end

-- Function to create a button bar
local function CreateButtonBar()
    local Options = addon.import("Options")
    
    if addon.buttonBar then
        return addon.buttonBar
    end
    
    local bar = CreateFrame("Frame", "MiniMapimousButtonBar", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    bar:SetSize(200, 36) -- Default size, will be resized based on button count
    bar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    bar:SetBackdropColor(0, 0, 0, 0.6)
    bar:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(10)
    
    -- Add mouse event handlers for hideButtonBar functionality
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function(self)
        if Options:get("hideButtonBar") then
            UpdateBarVisibility()
        end
    end)
    
    bar:SetScript("OnLeave", function(self)
        if Options:get("hideButtonBar") then
            -- Delay the hide check to prevent flickering
            C_Timer.After(0.1, function()
                UpdateBarVisibility()
            end)
        end
    end)
    
    -- Position the bar (always anchored to minimap)
    if Options:get("barPosition") == "LEFT" then
        bar:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -5, 0)
    else
        bar:SetPoint("TOPLEFT", Minimap, "TOPRIGHT", 5, 0)
    end
    
    addon.buttonBar = bar
    return bar
end

-- Function to update bar position when minimap scale changes
function addon.UpdateBarPosition()
    local Options = addon.import("Options")
    if addon.buttonBar then
        addon.buttonBar:ClearAllPoints()
        
        -- Always anchor to minimap (detach functionality removed)
        if Options:get("barPosition") == "LEFT" then
            addon.buttonBar:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -5, 0)
        else
            addon.buttonBar:SetPoint("TOPLEFT", Minimap, "TOPRIGHT", 5, 0)
        end
        
        -- Ensure the bar is visible after positioning
        addon.buttonBar:Show()
        
        -- Reposition buttons when scale changes
        if addon.collectedAddonButtons then
            PositionButtons(addon.collectedAddonButtons, addon.buttonBar)
        end
    end
end

-- Function to show/hide button bar
local function UpdateButtonBarVisibility()
    if addon.buttonBar and addon.buttonsCollected then
        addon.buttonBar:Show()
    end
end

local function ShouldHideBar()
    if MouseIsOver(Minimap) then return false end
    if addon.buttonBar then
        -- Check if mouse is over any of the buttons
        for _, button in ipairs(addon.collectedAddonButtons or {}) do
            if MouseIsOver(button) then return false end
        end
    end
    return true
end

local function HideButtonBar()
    if addon.buttonBar then
        if ShouldHideBar() then
            addon.buttonBar:Hide()
        end
    end
end

-- Create a custom mask texture if it doesn't exist
local function CreateMinimapMask()
    local maskFile = "Interface\\AddOns\\MiniMapimous\\Media\\MinimapMask"
    if not maskFile then
        -- Create the Media directory if it doesn't exist
        local mediaDir = "Interface\\AddOns\\MiniMapimous\\Media"
        CreateDir(mediaDir)
        
        -- Create a simple square mask texture
        local mask = CreateFrame("Frame")
        mask:SetSize(256, 256)
        local texture = mask:CreateTexture()
        texture:SetAllPoints()
        texture:SetColorTexture(1, 1, 1, 1)
        
        -- Save the texture
        texture:SetTexture(maskFile)
    end
end

-- Function to create a custom border for the square minimap
local function CreateMinimapBorder()
    -- Don't create multiple borders
    if addon.minimapBorder then 
        addon.minimapBorder:Hide()
        addon.minimapBorder = nil
    end
    
    addon.minimapBorder = CreateFrame("Frame", "MiniMapimousMinimapBorder", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    local border = addon.minimapBorder
    
    -- Position and size to match minimap with expansion for border
    border:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -4, 4)
    border:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 4, -4)
    border:SetFrameStrata("MEDIUM") -- Changed from LOW to MEDIUM
    border:SetFrameLevel(Minimap:GetFrameLevel() + 1) -- Changed to be ABOVE minimap
    
    -- Create simple black border without background
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8", -- Use solid white texture for clean lines
        edgeSize = 4,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    border:SetBackdropBorderColor(0, 0, 0, 1) -- Black border
    
    -- Make it scale with the minimap
    border:SetScript("OnUpdate", function(self)
        local scale = Minimap:GetScale()
        if self.lastScale ~= scale then
            self.lastScale = scale
            -- Update position to stay aligned with minimap
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -4, 4)
            self:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 4, -4)
        end
    end)
    
    -- Ensure it's visible and force show
    border:Show()
    border:SetAlpha(1)
    
    -- Disable mouse interaction so it doesn't interfere with minimap
    border:EnableMouse(false)
    
    return border
end

-- Function to set up square minimap
function SetupSquareMinimap()
    local Options = addon.import("Options")
    if not Minimap then return end
    
    -- Make minimap square
    Minimap:SetMaskTexture('Interface\\BUTTONS\\WHITE8X8')
    
    -- Create custom border for square minimap
    CreateMinimapBorder()
    
    -- Hide the compass
    if MinimapCompassTexture then
        MinimapCompassTexture:Hide()
    end
    if MinimapNorthTag then
        MinimapNorthTag:Hide()
    end
    
    -- Enable mousewheel zoom
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            Minimap_ZoomIn()
        else
            Minimap_ZoomOut()
        end
    end)
    
    -- Add mouseover handlers for button bar visibility
    Minimap:SetScript("OnEnter", function(self)
        if Options:get("hideButtonBar") then
            UpdateBarVisibility()
        end
    end)
    
    Minimap:SetScript("OnLeave", function(self)
        if Options:get("hideButtonBar") then
            -- Add a small delay before hiding to prevent flickering
            C_Timer.After(0.1, function()
                UpdateBarVisibility()
            end)
        end
    end)
    
    -- Enable right-click for tracking menu with multiple fallback methods
    Minimap:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            -- Method 1: Try ToggleDropDownMenu
            if ToggleDropDownMenu and MiniMapTrackingDropDown then
                ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "cursor")
                return
            end
            
            -- Method 2: Try direct tracking button click
            if MiniMapTrackingButton and MiniMapTrackingButton:IsVisible() then
                MiniMapTrackingButton:Click()
                return
            end
            
            -- Method 3: Try MinimapCluster tracking
            if MinimapCluster and MinimapCluster.Tracking then
                if MinimapCluster.Tracking:IsVisible() then
                    MinimapCluster.Tracking:Click()
                    return
                end
            end
            
            -- Method 4: Try to find any tracking-related frame
            local trackingFrames = {
                _G["MiniMapTrackingFrame"],
                _G["MinimapTracking"],
                _G["MinimapClusterTracking"],
                _G["MinimapClusterTrackingButton"]
            }
            
            for _, frame in ipairs(trackingFrames) do
                if frame and frame:IsVisible() and frame.Click then
                    frame:Click()
                    return
                end
            end
            
            -- Method 5: Fallback to game menu
            print("MiniMapimous: Could not open tracking menu, opening game menu instead")
            if GameMenuFrame and GameMenuFrame:IsVisible() then
                HideUIPanel(GameMenuFrame)
            else
                ShowUIPanel(GameMenuFrame)
            end
        end
    end)
    
    -- Apply scale
    if Minimap and Options:get("minimapScale") then
        Minimap:SetScale(Options:get("minimapScale"))
        if MinimapCluster then
            MinimapCluster:SetScale(Options:get("minimapScale"))
        end
    end
    
    -- Ensure proper strata and level
    Minimap:SetFrameStrata("LOW")
    if MinimapCluster then
        MinimapCluster:SetFrameStrata("LOW")
        MinimapCluster:SetFrameLevel(1)
    end
    Minimap:SetFrameLevel(2)
    
    -- Hook minimap scaling to ensure UI elements are properly managed
    if not Minimap.minimapimousScaleHooked then
        local originalSetScale = Minimap.SetScale
        Minimap.SetScale = function(self, scale)
            originalSetScale(self, scale)
            -- Apply UI element visibility after scaling
            C_Timer.After(0.1, function()
                UpdateUIElementVisibility()
            end)
        end
        Minimap.minimapimousScaleHooked = true
    end
    
    -- Also hook MinimapCluster if it exists
    if MinimapCluster and not MinimapCluster.minimapimousScaleHooked then
        local originalSetScale = MinimapCluster.SetScale
        MinimapCluster.SetScale = function(self, scale)
            originalSetScale(self, scale)
            -- Apply UI element visibility after scaling
            C_Timer.After(0.1, function()
                UpdateUIElementVisibility()
            end)
        end
        MinimapCluster.minimapimousScaleHooked = true
    end
end

-- Register events
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        -- Initialize options using the new Options module
        local Options = addon.import("Options")
        Options:init()
        
        -- Create config panel using the one from Config.lua
        local ConfigPanel = addon.import("ConfigPanel")
        addon.configPanel = ConfigPanel.CreateConfigPanel()
        
    elseif event == "PLAYER_LOGIN" then
        local Options = addon.import("Options")
        SetupSquareMinimap()
        UpdateUIElementVisibility()  -- Apply UI element visibility settings
        
        -- Force border creation after a delay to ensure minimap is ready
        C_Timer.After(0.5, function()
            CreateMinimapBorder()
        end)
        
        -- Debug: Check if DataTexts module is available
        local DataTexts = addon.import("DataTexts")
        
        -- Initialize DataTexts properly
        if DataTexts then
            DataTexts:Initialize()
            
            -- Force refresh after a short delay to ensure everything is ready
            C_Timer.After(1, function()
                DataTexts:RefreshDataTexts()
            end)
        end
        
        -- Create button bar if hideButtons is enabled
        if Options:get("hideButtons") then
            -- Create the button bar first
            if not addon.buttonBar then
                addon.buttonBar = CreateButtonBar()
            end
            -- Ensure proper positioning for detached bars
            addon.UpdateBarPosition()
            UpdateBarVisibility()
            -- Then collect buttons after a delay
            C_Timer.After(2, CollectMinimapButtons)
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        local Options = addon.import("Options")
        UpdateUIElementVisibility()  -- Reapply UI element visibility settings
        
        -- Ensure button bar is visible and positioned correctly if it should be
        if Options:get("hideButtons") then
            if not addon.buttonBar then
                addon.buttonBar = CreateButtonBar()
            end
            -- Update bar position in case it was detached
            addon.UpdateBarPosition()
            UpdateBarVisibility()
            -- Make sure the bar is visible
            if addon.buttonBar then
                addon.buttonBar:Show()
            end
            C_Timer.After(1, CollectMinimapButtons)
        end
    end
end)

-- Periodic update to ensure square shape and visibility
C_Timer.NewTicker(1, function()
    local Options = addon.import("Options")
    if Minimap then
        Minimap:SetMaskTexture('Interface\\BUTTONS\\WHITE8X8')
        Minimap:Show()
        if MinimapCluster then
            MinimapCluster:Show()
        end
        
        -- Ensure border is visible and properly positioned
        if not addon.minimapBorder or not addon.minimapBorder:IsShown() then
            CreateMinimapBorder()
        elseif addon.minimapBorder then
            -- Force border to stay visible and properly colored
            addon.minimapBorder:Show()
            addon.minimapBorder:SetAlpha(1)
            addon.minimapBorder:SetBackdropBorderColor(0, 0, 0, 1)
        end
        
        -- Ensure minimap data bar scales with minimap
        local DataTexts = addon.import("DataTexts")
        if DataTexts and DataTexts.UpdateMinimapDataBarScale then
            DataTexts:UpdateMinimapDataBarScale()
        end
        
        -- Use centralized UI element visibility function
        UpdateUIElementVisibility()
        
        -- Handle hideButtonBar functionality with more frequent updates
        if Options:get("hideButtonBar") then
            UpdateBarVisibility()
        end
        
        -- Recheck buttons periodically
        if Options:get("hideButtons") and addon.buttonBar and #(addon.collectedAddonButtons or {}) == 0 then
            CollectMinimapButtons()
        end
    end
end)

-- More frequent update for hideButtonBar responsiveness
C_Timer.NewTicker(0.1, function()
    local Options = addon.import("Options")
    if Options:get("hideButtonBar") and addon.buttonBar then
        UpdateBarVisibility()
    end
end)

-- Slash command handler
SLASH_MINIMAPIMOUS1 = "/minimapimous"
SLASH_MINIMAPIMOUS2 = "/mmap"
SLASH_MINIMAPIMOUS3 = "/mmmail"
SlashCmdList["MINIMAPIMOUS"] = function(msg)
    if msg == "mail" or msg == "debugmail" then
        DebugMailIcon()
        -- Also try to re-collect buttons
        if Options and Options:get("hideButtons") then
            CollectMinimapButtons()
        end
    else
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("MiniMapimous")
        else
            InterfaceOptionsFrame_OpenToCategory(addon.configPanel)
            InterfaceOptionsFrame_OpenToCategory(addon.configPanel)
        end
    end
end

-- Add debounce timer variable near the top with other variables
local collectionTimer = nil

-- Prevent multiple rapid collections
local isCollecting = false

-- Function to check and potentially show mail icon for debugging
local function DebugMailIcon()
    -- Check mail status
    local hasNewMail = HasNewMail()
    
    -- Try to get mail count
    local numUnreadMail = 0
    if C_Mail and C_Mail.GetNumUnreadMail then
        numUnreadMail = C_Mail.GetNumUnreadMail() or 0
    end
    
    -- Check if mailbox is open (alternative to CanSendMail which doesn't exist)
    local mailboxOpen = MailFrame and MailFrame:IsVisible()
    
    -- Look for the actual mail icon that should exist according to WoW wiki
    -- The mail icon should be a "smaller circular indicator under the date indicator"
    local modernMailFrames = {
        -- Modern mail icon possibilities
        _G["MinimapMailIcon"],
        _G["MinimapMail"],
        _G["MiniMapMailFrame"],
        _G["MinimapClusterMail"],
        _G["MinimapClusterMailButton"],
        _G["MinimapClusterMailIcon"],
        -- Check for any frame with "Mail" in the name that's a child of Minimap or MinimapCluster
    }
    
    -- Also check children of MinimapCluster for mail-related frames
    if MinimapCluster then
        for i, child in ipairs({MinimapCluster:GetChildren()}) do
            local name = child:GetName()
            if name and name:find("Mail") then
                table.insert(modernMailFrames, child)
            end
        end
    end
    
    -- Check children of Minimap for mail-related frames
    if Minimap then
        for i, child in ipairs({Minimap:GetChildren()}) do
            local name = child:GetName()
            if name and name:find("Mail") then
                table.insert(modernMailFrames, child)
            end
        end
    end
    
    -- Try to find mail icon by searching all global frames
    for name, frame in pairs(_G) do
        if type(name) == "string" and type(frame) == "table" and frame.GetObjectType then
            if name:find("Mail") and (name:find("Minimap") or name:find("Icon")) then
                if not tContains(modernMailFrames, frame) then
                    table.insert(modernMailFrames, frame)
                end
            end
        end
    end
    
    for i, frame in ipairs(modernMailFrames) do
        if frame then
            local frameName = frame:GetName() or ("unnamed_" .. i)
            frame:Show()
            frame:SetAlpha(1)
            if frame.SetShown then
                frame:SetShown(true)
            end
        end
    end
    
    -- Also check if any mail frames are actually visible after our attempts
    for i, frame in ipairs(modernMailFrames) do
        if frame then
            local frameName = frame:GetName() or ("unnamed_" .. i)
        end
    end
end

-- Update the main collection function
function CollectMinimapButtons()
    local Options = addon.import("Options")
    
    -- Prevent multiple simultaneous collections
    if isCollecting then return end
    isCollecting = true
    
    -- Cancel any pending collection
    if collectionTimer then
        collectionTimer:Cancel()
        collectionTimer = nil
    end
    
    -- Schedule the actual collection after a short delay
    collectionTimer = C_Timer.NewTimer(0.1, function()
        collectionTimer = nil
        
        if not Options:get("hideButtons") then
            ButtonCollection:restore()
            isCollecting = false
            return
        end
        
        if not addon.buttonBar then
            addon.buttonBar = CreateButtonBar()
        end

        -- Clear previous collection
        ButtonCollection:clear()
        
        -- Check for mail buttons specifically
        local mailButtons = {
            "MiniMapMailFrame",
            "MinimapMailIcon", 
            "MinimapClusterMail",
            "MinimapClusterMailButton",
            "MailFrame",
            "MinimapMail"
        }
        
        for _, buttonName in ipairs(mailButtons) do
            local button = _G[buttonName]
        end

        -- First collect whitelisted buttons
        for buttonName in pairs(Options:get("whitelist")) do
            local button = _G[buttonName]
            if button then
                ButtonCollection:addButton(button, "Addon")
            end
        end

        -- Specifically check for ExpansionLandingPageMinimapButton
        local expansionButton = _G["ExpansionLandingPageMinimapButton"]
        if expansionButton then
            ButtonCollection:addButton(expansionButton, "Addon")
        end

        -- Then collect LibDBIcon buttons
        local libDBIconButtons = {}
        for name, child in pairs(_G) do
            if type(name) == "string" and name:find("^LibDBIcon10_") then
                table.insert(libDBIconButtons, child)
            end
        end
        table.sort(libDBIconButtons, function(a, b)
            return (a:GetName() or "") < (b:GetName() or "")
        end)
        for _, button in ipairs(libDBIconButtons) do
            ButtonCollection:addButton(button, "Addon")
        end

        -- Helper function to process buttons
        local function processButton(button)
            local buttonType = ButtonIdentification:identifyButton(button)
            if not buttonType then return end
            
            local buttonName = button:GetName()
            
            -- Check if this is a Blizzard button
            if buttonName and ButtonIdentification.blizzardButtons[buttonName] then
                -- If showBlizzardButtons is false, skip this button entirely
                if not Options:get("showBlizzardButtons") then
                    return
                end
                -- Use the specific Blizzard button type
                buttonType = ButtonIdentification.blizzardButtons[buttonName]
            end
            
            -- Add the button to collection
            ButtonCollection:addButton(button, buttonType)
        end

        -- Then collect MinimapCluster children
        if MinimapCluster then
            for _, child in ipairs({MinimapCluster:GetChildren()}) do
                processButton(child)
            end
        end

        -- Finally collect Minimap children
        if Minimap then
            for _, child in ipairs({Minimap:GetChildren()}) do
                processButton(child)
            end
        end

        -- Position all buttons in the bar
        if addon.buttonBar then
            addon.buttonBar:Show()
            local numButtons = PositionButtons(ButtonCollection.collectedButtons, addon.buttonBar)
        end
        
        addon.collectedAddonButtons = ButtonCollection.collectedButtons
        addon.buttonsCollected = (#ButtonCollection.collectedButtons > 0)
        
        isCollecting = false
    end)
end

-- Function to update UI element visibility (removed - functionality simplified)
function UpdateUIElementVisibility()
    -- This function is no longer needed since we removed the hide UI elements options
    -- All UI elements will remain visible by default
end 