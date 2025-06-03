-- MiniMapimous - Square Minimap with Data Texts and Button Management
local frame = CreateFrame("Frame")
local addonName, addon = ...

addon.buttonInfo = {}

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
        ZygorGuidesViewerMapIcon = true,
        TrinketMenu_IconFrame = true,
        CodexBrowserIcon = true,
        ExpansionLandingPageMinimapButton = true,
        KhazSummaryButton = true,
        KhazAlgarSummaryButton = true,
        KhazSummaryMinimapButton = true,
        CellMinimapButton = true,
        KalielTrackerMinimapButton = true,
        QuazziUIMinimapButton = true,
        WeakAurasMinimapButton = true,
        Cell = true,
        KalielTracker = true,
        QuazziUI = true,
        WeakAuras = true,
    },
    blacklist = {},
    buttonScale = 1.0,
    version = 0,
}

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

    table.insert(self.collectedButtons, button)
    self.processedButtons[name] = true
    self.buttonTypes[name] = buttonType
end

function ButtonCollection:restore()
    for _, button in ipairs(self.collectedButtons) do
        if button.minimapimousOriginal then
            local orig = button.minimapimousOriginal
            
            button:SetParent(orig.parent)
            button:SetScale(orig.scale)
            button:SetFrameStrata(orig.strata)
            button:SetFrameLevel(orig.level)
            
            button:ClearAllPoints()
            for _, pointData in ipairs(orig.points) do
                local point, relativeTo, relativePoint, x, y = unpack(pointData)
                button:SetPoint(point, relativeTo, relativePoint, x, y)
            end
            
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

local ButtonIdentification = {
    blizzardButtons = {
        GameTimeFrame = "Calendar",
        MinimapClusterCalendar = "Calendar",
        CalendarButtonFrame = "Calendar",
        TimeManagerClockButton = "Clock",
        MinimapClusterClock = "Clock",
        MinimapTracking = "Tracking",
        MinimapClusterTracking = "Tracking",
        MiniMapTracking = "Tracking",
        MinimapClusterTrackingButton = "Tracking",
        QueueStatusButton = "Queue",
        QueueStatusMinimapButton = "Queue",
        MiniMapLFGFrame = "Queue",
        MinimapQueueFrame = "Queue",
        MinimapToggleButton = "Map",
        MiniMapWorldMapButton = "Map",
        MinimapClusterWorldMap = "Map",
        MiniMapMailFrame = "Mail",
        MinimapMailIcon = "Mail",
        MinimapClusterMail = "Mail",
        MinimapClusterMailButton = "Mail",
        MailFrame = "Mail",
        MinimapMail = "Mail",
        AddonCompartmentFrame = "AddonCompartment",
        MinimapClusterAddonCompartment = "AddonCompartment",
        QuickJoinToastButton = "Social",
        QuickJoinFrame = "Social",
        MinimapClusterSocialButton = "Social",
        MinimapPingFrame = "Ping",
        MinimapPing = "Ping"
    },
    
    buttonPatterns = {
        "^LibDBIcon10_",
        "MinimapButton",
        "MinimapFrame",
        "MinimapIcon",
        "[-_]Minimap[-_]",
        "Minimap$",
        "^Khaz.*Summary.*Button",
        "Summary.*Button$",
        "^Cell",
        "^Kaliel",
        "^Quazzi",
        "^WeakAuras",
        "Tracker.*Button",
        "UI.*Button",
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

    if Options:get("whitelist") and Options:get("whitelist")[name] then
        return "Addon"
    end
    
    if name:match("^Khaz.*Summary") or name:match("Summary.*Button$") then
        return "Addon"
    end
    
    if self.blizzardButtons[name] then
        return self.blizzardButtons[name]
    end
    
    if name:find("^LibDBIcon") then
        return "Addon"
    end
    
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

local masterTimer = 0
local UPDATE_INTERVAL = 1
local BUTTON_BAR_CHECK_INTERVAL = 0.2
local BORDER_CHECK_INTERVAL = 5

local mouseOverCache = {}
local cacheTimestamp = 0
local CACHE_DURATION = 0.1

local function GetCachedMouseIsOver(frame)
    local now = GetTime()
    if now - cacheTimestamp > CACHE_DURATION then
        wipe(mouseOverCache)
        cacheTimestamp = now
    end
    
    local frameKey = tostring(frame)
    if mouseOverCache[frameKey] == nil then
        mouseOverCache[frameKey] = MouseIsOver(frame)
    end
    return mouseOverCache[frameKey]
end

local Options = addon.import("Options")

local buttonCategories = {
    ADDON = { priority = 1, color = {0.3, 1, 0.8}, name = "Addons" },
    BLIZZARD = { priority = 2, color = {0.8, 0.8, 1}, name = "Blizzard" },
    TOOL = { priority = 3, color = {1, 0.8, 0.3}, name = "Tools" },
    UNKNOWN = { priority = 4, color = {0.7, 0.7, 0.7}, name = "Other" }
}

local highPriorityButtons = {
    "MiniMapTrackingFrame",
    "GameTimeFrame", 
    "MiniMapMailFrame",
    "QueueStatusMinimapButton",
    "MiniMapLFGFrame"
}

local function CategorizeButton(button)
    if not button then return "UNKNOWN" end
    
    local name = button:GetName() or ""
    local parent = button:GetParent()
    
    for _, priorityName in ipairs(highPriorityButtons) do
        if name == priorityName then
            return "BLIZZARD"
        end
    end
    
    if name:match("^MiniMap") or name:match("^GameTime") or name:match("^Queue") then
        return "BLIZZARD"
    end
    
    if name:match("Tool") or name:match("Util") or name:match("Helper") then
        return "TOOL"
    end
    
    if parent and parent ~= Minimap and parent ~= UIParent then
        return "ADDON"
    end
    
    return "ADDON"
end

local function ShowEnhancedButtonTooltip(button)
    if not button then return end
    
    local name = button:GetName() or "Unknown Button"
    local category = CategorizeButton(button)
    local categoryInfo = buttonCategories[category] or buttonCategories.UNKNOWN
    
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText(name, 1, 1, 1)
    
    GameTooltip:AddLine("Category: " .. categoryInfo.name, categoryInfo.color[1], categoryInfo.color[2], categoryInfo.color[3])
    
    local width, height = button:GetSize()
    GameTooltip:AddLine(string.format("Size: %.0fx%.0f", width, height), 0.8, 0.8, 0.8)
    
    local parent = button:GetParent()
    if parent then
        local parentName = parent:GetName() or "Unknown Parent"
        GameTooltip:AddLine("Parent: " .. parentName, 0.8, 0.8, 0.8)
    end
    
    GameTooltip:AddLine("Frame Level: " .. button:GetFrameLevel(), 0.8, 0.8, 0.8)
    
    if button:IsEnabled() and button:GetScript("OnClick") then
        GameTooltip:AddLine("Left-click: Activate", 0.3, 1, 0.3)
    end
    
    GameTooltip:AddLine("Right-click: Hide button", 1, 0.8, 0.3)
    GameTooltip:Show()
end

function UpdateBarVisibility()
    if not addon.buttonBar then return end
    
    local hideButtonBar = Options:get("hideButtonBar")
    
    if hideButtonBar then
        local shouldShow = false
        
        if GetCachedMouseIsOver(Minimap) or GetCachedMouseIsOver(addon.buttonBar) then
            shouldShow = true
        end
        
        if not shouldShow then
            local buttons = addon.collectedAddonButtons
            if buttons then
                for _, button in ipairs(buttons) do
                    if button and GetCachedMouseIsOver(button) then
                        shouldShow = true
                        break
                    end
                end
            end
        end
        
        if shouldShow then
            addon.buttonBar:Show()
            addon.buttonBar:SetAlpha(1)
        else
            addon.buttonBar:Hide()
        end
    else
        addon.buttonBar:Show()
        addon.buttonBar:SetAlpha(1)
        local buttons = addon.collectedAddonButtons
        if buttons then
            for _, button in ipairs(buttons) do
                if button then button:Show() end
            end
        end
    end
end

local function PositionButtons(buttonList, bar)
    if not buttonList or not bar then return 0 end
    
    local padding = 5
    local buttonSize = 24
    local minimapHeight = Minimap:GetHeight() * (Options:get("minimapScale") or 1)
    
    local availableHeight = minimapHeight - (padding * 2)
    local buttonWithPadding = buttonSize + padding
    local maxButtonsPerColumn = math.max(1, math.floor(availableHeight / buttonWithPadding))
    local totalButtons = #buttonList
    local columnsNeeded = math.ceil(totalButtons / maxButtonsPerColumn)
    local buttonsPerColumn = math.ceil(totalButtons / columnsNeeded)
    local barWidth = (buttonSize * columnsNeeded) + (padding * (columnsNeeded + 1))
    
    bar:SetSize(barWidth, minimapHeight)
    
    for i, button in ipairs(buttonList) do
        if not button.minimapimousOriginal then
            button.minimapimousOriginal = {
                parent = button:GetParent(),
                points = {},
                scale = button:GetScale(),
                strata = button:GetFrameStrata(),
                level = button:GetFrameLevel()
            }
            
            for j = 1, button:GetNumPoints() do
                local point, relativeTo, relativePoint, x, y = button:GetPoint(j)
                table.insert(button.minimapimousOriginal.points, {point, relativeTo, relativePoint, x, y})
            end
        end
        
        local column = math.floor((i - 1) / buttonsPerColumn)
        local row = (i - 1) % buttonsPerColumn
        local xOffset = padding + (column * (buttonSize + padding))
        local yOffset = padding + (row * (buttonSize + padding))
        
        button:SetParent(bar)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", bar, "TOPLEFT", xOffset, -yOffset)
        button:SetSize(buttonSize, buttonSize)
        button:SetFrameLevel(bar:GetFrameLevel() + 10)
        
        button:Show()
        
        button:SetScript("OnEnter", function(self)
            ShowEnhancedButtonTooltip(self)
        end)
        
        button:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        local category = CategorizeButton(button)
        local categoryInfo = buttonCategories[category] or buttonCategories.UNKNOWN
        
        if not button.categoryBorder then
            button.categoryBorder = CreateFrame("Frame", nil, button, BackdropTemplateMixin and "BackdropTemplate")
            button.categoryBorder:SetAllPoints(button)
            button.categoryBorder:SetFrameLevel(button:GetFrameLevel() - 1)
            button.categoryBorder:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 2,
                insets = {left = 1, right = 1, top = 1, bottom = 1}
            })
        end
        
        button.categoryBorder:SetBackdropBorderColor(categoryInfo.color[1], categoryInfo.color[2], categoryInfo.color[3], 0.8)
    end
    
    UpdateBarVisibility()
    
    return #buttonList
end

local function CreateButtonBar()
    if addon.buttonBar then
        return addon.buttonBar
    end
    
    local bar = CreateFrame("Frame", "MiniMapimousButtonBar", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    bar:SetSize(200, 36)
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
    bar:SetFrameLevel(Minimap:GetFrameLevel() + 3)
    
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function(self)
        if Options:get("hideButtonBar") then
            UpdateBarVisibility()
        end
    end)
    
    bar:SetScript("OnLeave", function(self)
        if Options:get("hideButtonBar") then
            C_Timer.After(0.1, function()
                UpdateBarVisibility()
            end)
        end
    end)
    
    if Options:get("barPosition") == "LEFT" then
        bar:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -9, 0)
    else
        bar:SetPoint("TOPLEFT", Minimap, "TOPRIGHT", 9, 0)
    end
    
    addon.buttonBar = bar
    return bar
end

function addon.UpdateBarPosition()
    if addon.buttonBar then
        addon.buttonBar:ClearAllPoints()
        
        if Options:get("barPosition") == "LEFT" then
            addon.buttonBar:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -9, 0)
        else
            addon.buttonBar:SetPoint("TOPLEFT", Minimap, "TOPRIGHT", 9, 0)
        end
        
        addon.buttonBar:Show()
        
        if addon.collectedAddonButtons then
            PositionButtons(addon.collectedAddonButtons, addon.buttonBar)
        end
    end
end

local function UpdateButtonBarVisibility()
    if addon.buttonBar and addon.buttonsCollected then
        addon.buttonBar:Show()
    end
end

local function ShouldHideBar()
    if MouseIsOver(Minimap) then return false end
    if addon.buttonBar then
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

local function CreateMinimapMask()
    local maskFile = "Interface\\AddOns\\MiniMapimous\\Media\\MinimapMask"
    if not maskFile then
        local mediaDir = "Interface\\AddOns\\MiniMapimous\\Media"
        CreateDir(mediaDir)
        
        local mask = CreateFrame("Frame")
        mask:SetSize(256, 256)
        local texture = mask:CreateTexture()
        texture:SetAllPoints()
        texture:SetColorTexture(1, 1, 1, 1)
        
        texture:SetTexture(maskFile)
    end
end

local function CreateMinimapBorder()
    if addon.minimapBorder then 
        addon.minimapBorder:Hide()
        addon.minimapBorder = nil
    end
    
    addon.minimapBorder = CreateFrame("Frame", "MiniMapimousMinimapBorder", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    local border = addon.minimapBorder
    
    border:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -4, 4)
    border:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 4, -4)
    border:SetFrameStrata("MEDIUM")
    border:SetFrameLevel(Minimap:GetFrameLevel() + 1)
    
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 4,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    border:SetBackdropBorderColor(0, 0, 0, 1)
    
    border:SetScript("OnUpdate", function(self)
        local scale = Minimap:GetScale()
        if self.lastScale ~= scale then
            self.lastScale = scale
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -4, 4)
            self:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 4, -4)
        end
    end)
    
    border:Show()
    border:SetAlpha(1)
    
    border:EnableMouse(false)
    
    return border
end

function SetupSquareMinimap()
    if not Minimap then return end
    
    Minimap:SetMaskTexture('Interface\\BUTTONS\\WHITE8X8')
    
    CreateMinimapBorder()
    
    if MinimapCompassTexture then
        MinimapCompassTexture:Hide()
    end
    if MinimapNorthTag then
        MinimapNorthTag:Hide()
    end
    
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            Minimap_ZoomIn()
        else
            Minimap_ZoomOut()
        end
    end)
    
    Minimap:SetScript("OnEnter", function(self)
        if Options:get("hideButtonBar") then
            UpdateBarVisibility()
        end
    end)
    
    Minimap:SetScript("OnLeave", function(self)
        if Options:get("hideButtonBar") then
            C_Timer.After(0.1, function()
                UpdateBarVisibility()
            end)
        end
    end)
    
    Minimap:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            if ToggleDropDownMenu and MiniMapTrackingDropDown then
                ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "cursor")
                return
            end
            
            if MiniMapTrackingButton and MiniMapTrackingButton:IsVisible() then
                MiniMapTrackingButton:Click()
                return
            end
            
            if MinimapCluster and MinimapCluster.Tracking then
                if MinimapCluster.Tracking:IsVisible() then
                    MinimapCluster.Tracking:Click()
                    return
                end
            end
            
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
        end
    end)
    
    if Minimap and Options:get("minimapScale") then
        Minimap:SetScale(Options:get("minimapScale"))
        if MinimapCluster then
            MinimapCluster:SetScale(Options:get("minimapScale"))
        end
    end
    
    Minimap:SetFrameStrata("LOW")
    if MinimapCluster then
        MinimapCluster:SetFrameStrata("LOW")
        MinimapCluster:SetFrameLevel(1)
    end
    Minimap:SetFrameLevel(2)
    
    if not Minimap.minimapimousScaleHooked then
        local originalSetScale = Minimap.SetScale
        Minimap.SetScale = function(self, scale)
            originalSetScale(self, scale)
            C_Timer.After(0.1, function()
                UpdateUIElementVisibility()
            end)
        end
        Minimap.minimapimousScaleHooked = true
    end
    
    if MinimapCluster and not MinimapCluster.minimapimousScaleHooked then
        local originalSetScale = MinimapCluster.SetScale
        MinimapCluster.SetScale = function(self, scale)
            originalSetScale(self, scale)
            C_Timer.After(0.1, function()
                UpdateUIElementVisibility()
            end)
        end
        MinimapCluster.minimapimousScaleHooked = true
    end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        local Options = addon.import("Options")
        Options:init()
        
        local ConfigPanel = addon.import("ConfigPanel")
        addon.configPanel = ConfigPanel.CreateConfigPanel()
        
    elseif event == "PLAYER_LOGIN" then
        local Options = addon.import("Options")
        SetupSquareMinimap()
        UpdateUIElementVisibility()
        
        C_Timer.After(0.5, function()
            CreateMinimapBorder()
        end)
        
        local DataTexts = addon.import("DataTexts")
        
        if DataTexts then
            DataTexts:Initialize()
            
            C_Timer.After(1, function()
                DataTexts:RefreshDataTexts()
            end)
        end
        
        if Options:get("hideButtons") then
            if not addon.buttonBar then
                addon.buttonBar = CreateButtonBar()
            end
            addon.UpdateBarPosition()
            UpdateBarVisibility()
            C_Timer.After(2, CollectMinimapButtons)
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        local Options = addon.import("Options")
        UpdateUIElementVisibility()
        
        if Options:get("hideButtons") then
            if not addon.buttonBar then
                addon.buttonBar = CreateButtonBar()
            end
            addon.UpdateBarPosition()
            UpdateBarVisibility()
            if addon.buttonBar then
                addon.buttonBar:Show()
            end
            C_Timer.After(1, CollectMinimapButtons)
        end
    end
end)

local masterUpdateFrame = CreateFrame("Frame")
masterUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
    masterTimer = masterTimer + elapsed
    
    if masterTimer >= UPDATE_INTERVAL then
        local Options = addon.import("Options")
        
        if Minimap then
            Minimap:SetMaskTexture('Interface\\BUTTONS\\WHITE8X8')
            Minimap:Show()
            if MinimapCluster then
                MinimapCluster:Show()
            end
            
            local DataTexts = addon.import("DataTexts")
            if DataTexts then
                DataTexts:UpdateAllDataTexts()
            end
            
            if Options:get("hideButtons") and addon.buttonBar and #(addon.collectedAddonButtons or {}) == 0 then
                CollectMinimapButtons()
            end
        end
        
        masterTimer = 0
    end
    
    if (masterTimer % BUTTON_BAR_CHECK_INTERVAL) < elapsed then
        local Options = addon.import("Options")
        if Options:get("hideButtonBar") and addon.buttonBar then
            UpdateBarVisibility()
        end
    end
    
    if (masterTimer % BORDER_CHECK_INTERVAL) < elapsed then
        if not addon.minimapBorder or not addon.minimapBorder:IsShown() then
            CreateMinimapBorder()
        elseif addon.minimapBorder then
            addon.minimapBorder:Show()
            addon.minimapBorder:SetAlpha(1)
            addon.minimapBorder:SetBackdropBorderColor(0, 0, 0, 1)
        end
    end
end)

function UpdateUIElementVisibility()
end

local collectionTimer = nil

local isCollecting = false

function CollectMinimapButtons()
    local Options = addon.import("Options")
    
    if isCollecting then return end
    isCollecting = true
    
    if collectionTimer then
        collectionTimer:Cancel()
        collectionTimer = nil
    end
    
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

        ButtonCollection:clear()

        for buttonName in pairs(Options:get("whitelist")) do
            local button = _G[buttonName]
            if button then
                ButtonCollection:addButton(button, "Addon")
            end
        end

        local expansionButton = _G["ExpansionLandingPageMinimapButton"]
        if expansionButton then
            ButtonCollection:addButton(expansionButton, "Addon")
        end

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

        local function processButton(button)
            local buttonType = ButtonIdentification:identifyButton(button)
            if not buttonType then return end
            
            local buttonName = button:GetName()
            
            if buttonName and ButtonIdentification.blizzardButtons[buttonName] then
                if not Options:get("showBlizzardButtons") then
                    return
                end
                buttonType = ButtonIdentification.blizzardButtons[buttonName]
            end
            
            ButtonCollection:addButton(button, buttonType)
        end

        if MinimapCluster then
            for _, child in ipairs({MinimapCluster:GetChildren()}) do
                processButton(child)
            end
        end

        if Minimap then
            for _, child in ipairs({Minimap:GetChildren()}) do
                processButton(child)
            end
        end

        if addon.buttonBar then
            addon.buttonBar:Show()
            local numButtons = PositionButtons(ButtonCollection.collectedButtons, addon.buttonBar)
        end
        
        addon.collectedAddonButtons = ButtonCollection.collectedButtons
        addon.buttonsCollected = (#ButtonCollection.collectedButtons > 0)
        
        isCollecting = false
    end)
end 