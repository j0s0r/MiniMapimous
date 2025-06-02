local addonName, addon = ...

-- Module system (moved here since Config.lua loads first now)
addon.modules = addon.modules or {}

function addon.export(name, module)
    assert(name ~= nil, "Module name cannot be nil")
    assert(addon.modules[name] == nil, "Module already exists: " .. name)
    assert(type(module) == "table", "Module needs to be table: " .. name)
    addon.modules[name] = module
    return module
end

function addon.import(name)
    assert(name ~= nil, "Module name cannot be nil")
    assert(addon.modules[name] ~= nil, "Module does not exist: " .. name)
    return addon.modules[name]
end

-- Options Module
local Options = {}

-- Default options
local defaultOptions = {
    hideButtons = true,
    minimapScale = 1.0,
    barTransparency = 0.4,
    showBlizzardButtons = true,
    barPosition = "LEFT",
    anchorToMinimap = true,
    hideButtonBar = false,
    showDataTexts = false,
    showMinimapDataBar = true,
    showOtherDataBar = true,
    showSecondDataBar = false,
    lockDataBars = false,
    minimapDataBarOpacity = 0.9,
    otherDataBarOpacity = 0.9,
    secondDataBarOpacity = 0.9,
    otherDataBarFontSize = 13,
    secondDataBarFontSize = 13,
    -- Default data text positions
    dataText_fps_position = "minimap",
    dataText_memory_position = "minimap",
    dataText_coordinates_position = "other",
    dataText_clock_position = "minimap",
    dataText_durability_position = "other",
    dataText_gold_position = "other",
    dataText_guild_position = "other",
    dataText_friends_position = "other",
    dataText_latency_position = "other",
    dataText_mail_position = "other",
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

-- Initialize saved variables
function Options:init()
    if not MiniMapimousDB then
        MiniMapimousDB = {}
    end
    
    -- Set defaults for missing options
    for key, value in pairs(defaultOptions) do
        if MiniMapimousDB[key] == nil then
            MiniMapimousDB[key] = value
        end
    end
    
    -- Force update data text positions if they don't exist or are using old defaults
    local dataTextKeys = {"fps", "memory", "coordinates", "clock", "durability", "gold", "guild", "friends", "latency", "mail"}
    for _, key in ipairs(dataTextKeys) do
        local optionKey = "dataText_" .. key .. "_position"
        local currentValue = MiniMapimousDB[optionKey]
        
        -- Migrate any "third" positions to "other" (first data bar)
        if currentValue == "third" then
            MiniMapimousDB[optionKey] = "other"
        elseif currentValue == nil then
            MiniMapimousDB[optionKey] = defaultOptions[optionKey]
        end
        
        -- Ensure valid position values (minimap, other, second, hide)
        local validPositions = {minimap = true, other = true, second = true, hide = true}
        if not validPositions[MiniMapimousDB[optionKey]] then
            MiniMapimousDB[optionKey] = defaultOptions[optionKey] or "other"
        end
    end
    
    -- Version migration if needed
    if not MiniMapimousDB.version or MiniMapimousDB.version < 2 then
        -- Migrate old settings if they exist
        MiniMapimousDB.version = 2
    end
end

-- Get option value
function Options:get(key)
    return MiniMapimousDB[key]
end

-- Set option value
function Options:set(key, value)
    MiniMapimousDB[key] = value
end

-- Get default value
function Options:getDefault(key)
    return defaultOptions[key]
end

-- Reset all options to defaults
function Options:reset()
    MiniMapimousDB = {}
    self:init()
end

-- Export the Options module
addon.export("Options", Options)

-- Configuration Panel Module
local ConfigPanel = {}

-- Create configuration panel
local function CreateConfigPanel()
    local panel = CreateFrame("Frame")
    panel.name = "MiniMapimous"
    
    -- Create a scroll frame for the content
    local scrollFrame = CreateFrame("ScrollFrame", "MiniMapimousScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    -- Create the content frame
    local content = CreateFrame("Frame", "MiniMapimousContent", scrollFrame)
    content:SetSize(600, 1000) -- Increased height for single column layout
    scrollFrame:SetScrollChild(content)
    
    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("MiniMapimous Options")
    
    -- Minimap Section
    local minimapTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    minimapTitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -24)
    minimapTitle:SetText("Minimap Settings")
    minimapTitle:SetTextColor(1, 1, 0) -- Yellow title
    
    local scaleSlider = CreateFrame("Slider", "MiniMapimousScaleSlider", content, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", minimapTitle, "BOTTOMLEFT", 0, -16)
    scaleSlider:SetWidth(200)
    scaleSlider:SetHeight(20)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetObeyStepOnDrag(true)
    
    _G[scaleSlider:GetName() .. "Low"]:SetText("50%")
    _G[scaleSlider:GetName() .. "High"]:SetText("200%")
    _G[scaleSlider:GetName() .. "Text"]:SetText("Minimap Scale: " .. Options:get("minimapScale") * 100 .. "%")
    
    scaleSlider:SetValue(Options:get("minimapScale"))
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        Options:set("minimapScale", value)
        _G[self:GetName() .. "Text"]:SetText("Minimap Scale: " .. floor(value * 100) .. "%")
        if Minimap then
            Minimap:SetScale(value)
            if MinimapCluster then
                MinimapCluster:SetScale(value)
            end
        end
        if addon.UpdateBarPosition then
            addon.UpdateBarPosition()
        end
        -- Update minimap data bar scale
        local DataTexts = addon.import("DataTexts")
        if DataTexts and DataTexts.UpdateMinimapDataBarScale then
            DataTexts:UpdateMinimapDataBarScale()
        end
        
        -- Cancel any existing timer
        if self.scaleTimer then
            self.scaleTimer:Cancel()
        end
        
        -- Re-collect buttons after a short delay to ensure proper positioning
        if Options:get("hideButtons") then
            self.scaleTimer = C_Timer.NewTimer(0.5, function()
                CollectMinimapButtons()
                self.scaleTimer = nil
            end)
        end
    end)
    
    -- Button Bar Section
    local buttonBarTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    buttonBarTitle:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -32)
    buttonBarTitle:SetText("Button Bar Settings")
    buttonBarTitle:SetTextColor(1, 1, 0) -- Yellow title
    
    local hideButtonsCheck = CreateFrame("CheckButton", "MiniMapimousHideButtonsCheck", content, "InterfaceOptionsCheckButtonTemplate")
    hideButtonsCheck:SetPoint("TOPLEFT", buttonBarTitle, "BOTTOMLEFT", 0, -8)
    _G[hideButtonsCheck:GetName() .. "Text"]:SetText("Collect addon buttons in bar")
    hideButtonsCheck:SetChecked(Options:get("hideButtons"))
    hideButtonsCheck:SetScript("OnClick", function(self)
        Options:set("hideButtons", self:GetChecked())
        if self:GetChecked() then
            CollectMinimapButtons()
        else
            local ButtonCollection = addon.import("ButtonCollection")
            ButtonCollection:restore()
        end
    end)
    
    local hideButtonBarCheck = CreateFrame("CheckButton", "MiniMapimousHideButtonBarCheck", content, "InterfaceOptionsCheckButtonTemplate")
    hideButtonBarCheck:SetPoint("TOPLEFT", hideButtonsCheck, "BOTTOMLEFT", 0, -8)
    _G[hideButtonBarCheck:GetName() .. "Text"]:SetText("Hide button bar (show on minimap hover)")
    hideButtonBarCheck:SetChecked(Options:get("hideButtonBar"))
    hideButtonBarCheck:SetScript("OnClick", function(self)
        Options:set("hideButtonBar", self:GetChecked())
        UpdateBarVisibility()
    end)
    
    -- Show Blizzard buttons in bar checkbox
    local showBlizzardButtonsCheck = CreateFrame("CheckButton", "MiniMapimousShowBlizzardButtonsCheck", content, "InterfaceOptionsCheckButtonTemplate")
    showBlizzardButtonsCheck:SetPoint("TOPLEFT", hideButtonBarCheck, "BOTTOMLEFT", 0, -8)
    _G[showBlizzardButtonsCheck:GetName() .. "Text"]:SetText("Show Blizzard buttons in bar")
    showBlizzardButtonsCheck:SetChecked(Options:get("showBlizzardButtons"))
    showBlizzardButtonsCheck:SetScript("OnClick", function(self)
        Options:set("showBlizzardButtons", self:GetChecked())
        -- Re-collect buttons to apply the new setting
        if Options:get("hideButtons") then
            CollectMinimapButtons()
        end
    end)
    
    -- Data Texts Section (moved to left column for better visibility)
    local dataTextsTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dataTextsTitle:SetPoint("TOPLEFT", showBlizzardButtonsCheck, "BOTTOMLEFT", 0, -32)
    dataTextsTitle:SetText("Data Texts & Bars")
    dataTextsTitle:SetTextColor(1, 1, 0) -- Yellow title
    
    -- Data bar controls section
    local dataBarControlsTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dataBarControlsTitle:SetPoint("TOPLEFT", dataTextsTitle, "BOTTOMLEFT", 0, -16)
    dataBarControlsTitle:SetText("Data Bar Controls:")
    dataBarControlsTitle:SetTextColor(0.8, 0.8, 1) -- Light blue subtitle
    
    -- Lock/Unlock data bars
    local lockDataBarsCheck = CreateFrame("CheckButton", "MiniMapimousLockDataBarsCheck", content, "InterfaceOptionsCheckButtonTemplate")
    lockDataBarsCheck:SetPoint("TOPLEFT", dataBarControlsTitle, "BOTTOMLEFT", 0, -8)
    _G[lockDataBarsCheck:GetName() .. "Text"]:SetText("Lock movable data bars (First & Second only)")
    lockDataBarsCheck:SetChecked(Options:get("lockDataBars") or false)
    lockDataBarsCheck:SetScript("OnClick", function(self)
        Options:set("lockDataBars", self:GetChecked())
        local DataTexts = addon.import("DataTexts")
        DataTexts:UpdateDataBarLocks()
    end)
    
    -- Minimap Data Bar controls
    local minimapDataBarTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    minimapDataBarTitle:SetPoint("TOPLEFT", lockDataBarsCheck, "BOTTOMLEFT", 0, -16)
    minimapDataBarTitle:SetText("Minimap Data Bar (attached to minimap):")
    minimapDataBarTitle:SetTextColor(0.7, 0.7, 0.7)
    
    local showMinimapDataBarCheck = CreateFrame("CheckButton", "MiniMapimousShowMinimapDataBarCheck", content, "InterfaceOptionsCheckButtonTemplate")
    showMinimapDataBarCheck:SetPoint("TOPLEFT", minimapDataBarTitle, "BOTTOMLEFT", 0, -4)
    _G[showMinimapDataBarCheck:GetName() .. "Text"]:SetText("Show")
    showMinimapDataBarCheck:SetChecked(Options:get("showMinimapDataBar"))
    showMinimapDataBarCheck:SetScript("OnClick", function(self)
        Options:set("showMinimapDataBar", self:GetChecked())
        local DataTexts = addon.import("DataTexts")
        DataTexts:RefreshDataTexts()
    end)
    
    -- Other Data Bar controls
    local otherDataBarTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    otherDataBarTitle:SetPoint("TOPLEFT", showMinimapDataBarCheck, "BOTTOMLEFT", 0, -24)
    otherDataBarTitle:SetText("First Data Bar:")
    otherDataBarTitle:SetTextColor(0.7, 0.7, 0.7)
    
    local showOtherDataBarCheck = CreateFrame("CheckButton", "MiniMapimousShowOtherDataBarCheck", content, "InterfaceOptionsCheckButtonTemplate")
    showOtherDataBarCheck:SetPoint("TOPLEFT", otherDataBarTitle, "BOTTOMLEFT", 0, -4)
    _G[showOtherDataBarCheck:GetName() .. "Text"]:SetText("Show")
    showOtherDataBarCheck:SetChecked(Options:get("showOtherDataBar"))
    showOtherDataBarCheck:SetScript("OnClick", function(self)
        Options:set("showOtherDataBar", self:GetChecked())
        local DataTexts = addon.import("DataTexts")
        DataTexts:RefreshDataTexts()
    end)
    
    -- Other Data Bar opacity slider
    local otherBarOpacitySlider = CreateFrame("Slider", "MiniMapimousOtherBarOpacitySlider", content, "OptionsSliderTemplate")
    otherBarOpacitySlider:SetPoint("TOPLEFT", showOtherDataBarCheck, "TOPRIGHT", 80, 8)
    otherBarOpacitySlider:SetWidth(80)
    otherBarOpacitySlider:SetHeight(16)
    otherBarOpacitySlider:SetMinMaxValues(0.1, 1.0)
    otherBarOpacitySlider:SetValueStep(0.1)
    otherBarOpacitySlider:SetObeyStepOnDrag(true)
    
    _G[otherBarOpacitySlider:GetName() .. "Low"]:SetText("10%")
    _G[otherBarOpacitySlider:GetName() .. "High"]:SetText("100%")
    _G[otherBarOpacitySlider:GetName() .. "Text"]:SetText("Opacity: " .. (Options:get("otherDataBarOpacity") or 0.9) * 100 .. "%")
    
    otherBarOpacitySlider:SetValue(Options:get("otherDataBarOpacity") or 0.9)
    otherBarOpacitySlider:SetScript("OnValueChanged", function(self, value)
        Options:set("otherDataBarOpacity", value)
        _G[self:GetName() .. "Text"]:SetText("Opacity: " .. floor(value * 100) .. "%")
        local DataTexts = addon.import("DataTexts")
        DataTexts:UpdateDataBarOpacity()
    end)
    
    -- Other Data Bar font size slider (next to opacity)
    local otherBarFontSizeSlider = CreateFrame("Slider", "MiniMapimousOtherBarFontSizeSlider", content, "OptionsSliderTemplate")
    otherBarFontSizeSlider:SetPoint("TOPLEFT", otherBarOpacitySlider, "TOPRIGHT", 15, 0)
    otherBarFontSizeSlider:SetWidth(80)
    otherBarFontSizeSlider:SetHeight(16)
    otherBarFontSizeSlider:SetMinMaxValues(8, 20)
    otherBarFontSizeSlider:SetValueStep(1)
    otherBarFontSizeSlider:SetObeyStepOnDrag(true)
    
    _G[otherBarFontSizeSlider:GetName() .. "Low"]:SetText("8")
    _G[otherBarFontSizeSlider:GetName() .. "High"]:SetText("20")
    _G[otherBarFontSizeSlider:GetName() .. "Text"]:SetText("Font: " .. (Options:get("otherDataBarFontSize") or 13))
    
    otherBarFontSizeSlider:SetValue(Options:get("otherDataBarFontSize") or 13)
    otherBarFontSizeSlider:SetScript("OnValueChanged", function(self, value)
        Options:set("otherDataBarFontSize", value)
        _G[self:GetName() .. "Text"]:SetText("Font: " .. floor(value))
        local DataTexts = addon.import("DataTexts")
        DataTexts:UpdateDataBarFontSizes()
    end)
    
    -- Second Data Bar controls
    local secondDataBarTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    secondDataBarTitle:SetPoint("TOPLEFT", showOtherDataBarCheck, "BOTTOMLEFT", 0, -24)
    secondDataBarTitle:SetText("Second Data Bar:")
    secondDataBarTitle:SetTextColor(0.7, 0.7, 0.7)
    
    local showSecondDataBarCheck = CreateFrame("CheckButton", "MiniMapimousShowSecondDataBarCheck", content, "InterfaceOptionsCheckButtonTemplate")
    showSecondDataBarCheck:SetPoint("TOPLEFT", secondDataBarTitle, "BOTTOMLEFT", 0, -4)
    _G[showSecondDataBarCheck:GetName() .. "Text"]:SetText("Show")
    showSecondDataBarCheck:SetChecked(Options:get("showSecondDataBar"))
    showSecondDataBarCheck:SetScript("OnClick", function(self)
        Options:set("showSecondDataBar", self:GetChecked())
        local DataTexts = addon.import("DataTexts")
        DataTexts:RefreshDataTexts()
    end)
    
    -- Second Data Bar opacity slider
    local secondBarOpacitySlider = CreateFrame("Slider", "MiniMapimousSecondBarOpacitySlider", content, "OptionsSliderTemplate")
    secondBarOpacitySlider:SetPoint("TOPLEFT", showSecondDataBarCheck, "TOPRIGHT", 80, 8)
    secondBarOpacitySlider:SetWidth(80)
    secondBarOpacitySlider:SetHeight(16)
    secondBarOpacitySlider:SetMinMaxValues(0.1, 1.0)
    secondBarOpacitySlider:SetValueStep(0.1)
    secondBarOpacitySlider:SetObeyStepOnDrag(true)
    
    _G[secondBarOpacitySlider:GetName() .. "Low"]:SetText("10%")
    _G[secondBarOpacitySlider:GetName() .. "High"]:SetText("100%")
    _G[secondBarOpacitySlider:GetName() .. "Text"]:SetText("Opacity: " .. (Options:get("secondDataBarOpacity") or 0.9) * 100 .. "%")
    
    secondBarOpacitySlider:SetValue(Options:get("secondDataBarOpacity") or 0.9)
    secondBarOpacitySlider:SetScript("OnValueChanged", function(self, value)
        Options:set("secondDataBarOpacity", value)
        _G[self:GetName() .. "Text"]:SetText("Opacity: " .. floor(value * 100) .. "%")
        local DataTexts = addon.import("DataTexts")
        DataTexts:UpdateDataBarOpacity()
    end)
    
    -- Second Data Bar font size slider (next to opacity)
    local secondBarFontSizeSlider = CreateFrame("Slider", "MiniMapimousSecondBarFontSizeSlider", content, "OptionsSliderTemplate")
    secondBarFontSizeSlider:SetPoint("TOPLEFT", secondBarOpacitySlider, "TOPRIGHT", 15, 0)
    secondBarFontSizeSlider:SetWidth(80)
    secondBarFontSizeSlider:SetHeight(16)
    secondBarFontSizeSlider:SetMinMaxValues(8, 20)
    secondBarFontSizeSlider:SetValueStep(1)
    secondBarFontSizeSlider:SetObeyStepOnDrag(true)
    
    _G[secondBarFontSizeSlider:GetName() .. "Low"]:SetText("8")
    _G[secondBarFontSizeSlider:GetName() .. "High"]:SetText("20")
    _G[secondBarFontSizeSlider:GetName() .. "Text"]:SetText("Font: " .. (Options:get("secondDataBarFontSize") or 13))
    
    secondBarFontSizeSlider:SetValue(Options:get("secondDataBarFontSize") or 13)
    secondBarFontSizeSlider:SetScript("OnValueChanged", function(self, value)
        Options:set("secondDataBarFontSize", value)
        _G[self:GetName() .. "Text"]:SetText("Font: " .. floor(value))
        local DataTexts = addon.import("DataTexts")
        DataTexts:UpdateDataBarFontSizes()
    end)
    
    -- Data text positioning section
    local dataTextPositionTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dataTextPositionTitle:SetPoint("TOPLEFT", showSecondDataBarCheck, "BOTTOMLEFT", 0, -32)
    dataTextPositionTitle:SetText("Data Text Positioning:")
    dataTextPositionTitle:SetTextColor(0.8, 0.8, 1) -- Light blue subtitle
    
    -- Individual data text controls with dropdowns (more compact)
    local dataTextControls = {}
    local DataTexts = addon.import("DataTexts")
    local availableTexts = DataTexts:GetAvailableDataTexts()
    
    local yOffset = -8 -- Start right after the subtitle
    local dataTextOrder = {"fps", "memory", "coordinates", "clock", "durability", "gold", "guild", "friends", "latency", "mail"}
    
    -- Function to create dropdown for data text positioning
    local function CreateDataTextDropdown(key, config, parent, yPos)
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", dataTextPositionTitle, "BOTTOMLEFT", 0, yPos)
        label:SetText(config.name .. ":")
        label:SetWidth(70)
        label:SetJustifyH("LEFT")
        
        local dropdown = CreateFrame("Frame", "MiniMapimousDataText" .. key .. "Dropdown", parent, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", label, "TOPRIGHT", -10, 7)
        UIDropDownMenu_SetWidth(dropdown, 100)
        
        local function OnClick(self)
            Options:set("dataText_" .. key .. "_position", self.value)
            UIDropDownMenu_SetText(dropdown, self.text)
            local DataTexts = addon.import("DataTexts")
            DataTexts:RefreshDataTexts()
        end
        
        local function Initialize(self, level)
            local info = UIDropDownMenu_CreateInfo()
            info.func = OnClick
            
            info.text = "Hide"
            info.value = "hide"
            info.checked = Options:get("dataText_" .. key .. "_position") == "hide"
            UIDropDownMenu_AddButton(info)
            
            info.text = "Minimap"
            info.value = "minimap"
            info.checked = Options:get("dataText_" .. key .. "_position") == "minimap"
            UIDropDownMenu_AddButton(info)
            
            info.text = "First Data Bar"
            info.value = "other"
            info.checked = Options:get("dataText_" .. key .. "_position") == "other"
            UIDropDownMenu_AddButton(info)
            
            info.text = "Second Data Bar"
            info.value = "second"
            info.checked = Options:get("dataText_" .. key .. "_position") == "second"
            UIDropDownMenu_AddButton(info)
        end
        
        UIDropDownMenu_Initialize(dropdown, Initialize)
        
        -- Set initial value with shorter text
        local currentPos = Options:get("dataText_" .. key .. "_position") or "other"
        local displayText = "First Data Bar"
        if currentPos == "hide" then displayText = "Hide"
        elseif currentPos == "minimap" then displayText = "Minimap"
        elseif currentPos == "second" then displayText = "Second Data Bar"
        end
        UIDropDownMenu_SetText(dropdown, displayText)
        
        return dropdown
    end
    
    -- Create dropdowns in a single column for better visibility
    for i, key in ipairs(dataTextOrder) do
        local config = availableTexts[key]
        if config then
            local yPos = yOffset - ((i - 1) * 32)
            local dropdown = CreateDataTextDropdown(key, config, content, yPos)
            dataTextControls[key] = dropdown
        end
    end
    
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    end
    
    return panel
end

-- Export the function as a module
local ConfigPanel = addon.export("ConfigPanel", {
    CreateConfigPanel = CreateConfigPanel
})

return ConfigPanel 