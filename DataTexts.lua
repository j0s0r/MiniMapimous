local addonName, addon = ...

-- DataTexts Module
local DataTexts = addon.export("DataTexts", {
    texts = {},
    frames = {},
    updateInterval = 1, -- Update every second
    ticker = nil,
})

-- Import Options module
local Options = addon.import("Options")

-- Data text frames storage
local dataTextFrames = {}
local minimapDataTexts = {}
local minimapDataBar = nil
local otherDataTexts = {}
local otherDataBar = nil
local secondDataTexts = {} -- New second data bar storage
local secondDataBar = nil -- New second data bar

-- Available data texts configuration
local availableDataTexts = {
    fps = {
        name = "FPS",
        color = {1, 1, 1}, -- White (default, will be overridden by color coding)
        update = function(frame)
            local fps = GetFramerate()
            frame.text:SetText(string.format("%.0f:FPS", fps))
            
            -- Color coding based on FPS value
            if fps >= 60 then
                frame.text:SetTextColor(0.3, 1, 0.3) -- Green for good FPS
            elseif fps >= 30 then
                frame.text:SetTextColor(1, 1, 0.3) -- Yellow for medium FPS
            else
                frame.text:SetTextColor(1, 0.3, 0.3) -- Red for low FPS
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Frames Per Second")
            local fps = GetFramerate()
            GameTooltip:AddLine(string.format("Current: %.1f", fps), 1, 1, 1)
            
            -- Add performance assessment
            if fps >= 60 then
                GameTooltip:AddLine("Excellent performance", 0.3, 1, 0.3)
            elseif fps >= 30 then
                GameTooltip:AddLine("Good performance", 1, 1, 0.3)
            elseif fps >= 20 then
                GameTooltip:AddLine("Poor performance", 1, 0.8, 0.3)
            else
                GameTooltip:AddLine("Very poor performance", 1, 0.3, 0.3)
            end
            
            GameTooltip:AddLine("Higher is better for smooth gameplay", 0.8, 0.8, 0.8)
        end
    },
    memory = {
        name = "Memory",
        color = {0.5, 1, 0.5}, -- Light green
        update = function(frame)
            -- Enable CPU profiling if not already enabled
            if GetCVar("scriptProfile") ~= "1" then
                SetCVar("scriptProfile", "1")
            end
            
            -- Update addon memory usage data
            UpdateAddOnMemoryUsage()
            UpdateAddOnCPUUsage()
            
            -- Calculate total memory and CPU usage across all addons
            local totalMemory = 0
            local totalCPU = 0
            local addonCount = C_AddOns.GetNumAddOns()
            
            for i = 1, addonCount do
                if C_AddOns.IsAddOnLoaded(i) then
                    local memory = GetAddOnMemoryUsage(i)
                    local cpu = GetAddOnCPUUsage(i)
                    totalMemory = totalMemory + memory
                    totalCPU = totalCPU + cpu
                end
            end
            
            -- Display both memory and CPU usage
            local memStr = ""
            if totalMemory > 1024 then
                memStr = string.format("%.1fMB", totalMemory / 1024)
            else
                memStr = string.format("%.0fKB", totalMemory)
            end
            
            local cpuStr = ""
            if totalCPU > 1000 then
                cpuStr = string.format("%.1fs", totalCPU / 1000) -- Show in seconds for very high values
            elseif totalCPU > 1 then
                cpuStr = string.format("%.1fms", totalCPU)
            else
                cpuStr = string.format("%.2fms", totalCPU)
            end
            
            frame.text:SetText(string.format("%s | %s", memStr, cpuStr))
            
            -- Color coding based on memory usage (primary indicator)
            if totalMemory > 50 * 1024 then -- > 50MB
                frame.text:SetTextColor(1, 0.3, 0.3) -- Red
            elseif totalMemory > 20 * 1024 then -- > 20MB
                frame.text:SetTextColor(1, 1, 0.3) -- Yellow
            else
                frame.text:SetTextColor(0.5, 1, 0.5) -- Green
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Addon Performance (CPU/Memory)")
            
            -- Update both memory and CPU data
            UpdateAddOnMemoryUsage()
            UpdateAddOnCPUUsage()
            
            -- Collect all addon data
            local addonData = {}
            local totalMemory = 0
            local totalCPU = 0
            local loadedCount = 0
            
            for i = 1, C_AddOns.GetNumAddOns() do
                if C_AddOns.IsAddOnLoaded(i) then
                    local name = C_AddOns.GetAddOnMetadata(i, "Title") or C_AddOns.GetAddOnMetadata(i, "X-Curse-Project-Name") or select(2, C_AddOns.GetAddOnInfo(i))
                    local memory = GetAddOnMemoryUsage(i)
                    local cpu = GetAddOnCPUUsage(i)
                    totalMemory = totalMemory + memory
                    totalCPU = totalCPU + cpu
                    loadedCount = loadedCount + 1
                    
                    table.insert(addonData, {
                        name = name,
                        memory = memory,
                        cpu = cpu
                    })
                end
            end
            
            -- Sort by memory usage (highest first)
            table.sort(addonData, function(a, b) return a.memory > b.memory end)
            
            -- Show totals
            GameTooltip:AddLine(string.format("Total: %.1f MB | %.1f ms CPU (%d addons)", totalMemory / 1024, totalCPU, loadedCount), 1, 1, 1)
            GameTooltip:AddLine(" ")
            
            -- Show all addons in a compact format
            GameTooltip:AddLine("All Loaded Addons:", 1, 1, 0)
            
            for i, addon in ipairs(addonData) do
                local color = {1, 1, 1} -- White default
                
                -- Color code based on memory usage
                if addon.memory > 5 * 1024 then -- > 5MB
                    color = {1, 0.3, 0.3} -- Red
                elseif addon.memory > 2 * 1024 then -- > 2MB
                    color = {1, 1, 0.3} -- Yellow
                elseif addon.memory > 1 * 1024 then -- > 1MB
                    color = {1, 0.8, 0.3} -- Orange
                elseif addon.memory > 512 then -- > 512KB
                    color = {0.8, 1, 0.8} -- Light green
                else
                    color = {0.6, 0.6, 0.6} -- Gray for very low usage
                end
                
                -- Format memory and CPU
                local memStr = addon.memory > 1024 and string.format("%.1fMB", addon.memory / 1024) or string.format("%.0fKB", addon.memory)
                local cpuStr = addon.cpu > 1 and string.format("%.1fms", addon.cpu) or string.format("%.2fms", addon.cpu)
                
                GameTooltip:AddLine(string.format("%s: %s | %s", addon.name, memStr, cpuStr), color[1], color[2], color[3])
            end
            
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to run garbage collection", 0.8, 0.8, 0.8)
        end
    },
    coordinates = {
        name = "Coordinates",
        color = {1, 1, 0.5}, -- Light yellow
        update = function(frame)
            local mapID = C_Map.GetBestMapForUnit("player")
            if mapID then
                local position = C_Map.GetPlayerMapPosition(mapID, "player")
                if position then
                    local x, y = position:GetXY()
                    frame.text:SetText(string.format("%.1f, %.1f", x * 100, y * 100))
                else
                    frame.text:SetText("No coords")
                end
            else
                frame.text:SetText("No map")
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Player Coordinates")
            local mapID = C_Map.GetBestMapForUnit("player")
            if mapID then
                local position = C_Map.GetPlayerMapPosition(mapID, "player")
                if position then
                    local x, y = position:GetXY()
                    GameTooltip:AddLine(string.format("X: %.2f, Y: %.2f", x * 100, y * 100), 1, 1, 1)
                    local mapInfo = C_Map.GetMapInfo(mapID)
                    if mapInfo then
                        GameTooltip:AddLine("Zone: " .. mapInfo.name, 0.8, 0.8, 0.8)
                    end
                end
            end
        end
    },
    clock = {
        name = "Clock",
        color = {0.5, 0.8, 1}, -- Light blue
        update = function(frame)
            -- Use local time instead of server time
            local timeStr = date("%H:%M")
            frame.text:SetText(timeStr)
        end,
        tooltip = function()
            GameTooltip:SetText("Time")
            -- Show both local and server time
            local localTime = date("%H:%M")
            local hour, minute = GetGameTime()
            local serverTime = string.format("%02d:%02d", hour, minute)
            
            GameTooltip:AddLine(string.format("Local Time: %s", localTime), 1, 1, 1)
            GameTooltip:AddLine(string.format("Server Time: %s", serverTime), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to open calendar", 0.8, 0.8, 0.8)
        end,
        onClick = function()
            -- Try multiple methods to open the calendar
            if Calendar_Toggle then
                Calendar_Toggle()
            elseif ToggleCalendar then
                ToggleCalendar()
            elseif CalendarFrame then
                if CalendarFrame:IsShown() then
                    CalendarFrame:Hide()
                else
                    CalendarFrame:Show()
                end
            elseif GameTimeFrame and GameTimeFrame:IsVisible() then
                -- Click the game time frame if it's visible
                GameTimeFrame:Click()
            else
                -- Fallback: try to show the calendar addon interface
                if C_Calendar and C_Calendar.OpenCalendar then
                    C_Calendar.OpenCalendar()
                else
                    print("MiniMapimous: Could not open calendar")
                end
            end
        end
    },
    durability = {
        name = "Durability",
        color = {1, 0.7, 0.5}, -- Light orange (default, will be overridden by color coding)
        update = function(frame)
            local total, broken = 0, 0
            for i = 1, 18 do
                local durability, maxDurability = GetInventoryItemDurability(i)
                if durability and maxDurability then
                    total = total + 1
                    if durability == 0 then
                        broken = broken + 1
                    end
                end
            end
            
            if total > 0 then
                local percent = ((total - broken) / total) * 100
                frame.text:SetText(string.format("Gear: %.0f%%", percent))
                
                -- Color coding based on durability percentage
                if percent >= 75 then
                    frame.text:SetTextColor(0.3, 1, 0.3) -- Green for good durability
                elseif percent >= 25 then
                    frame.text:SetTextColor(1, 1, 0.3) -- Yellow for medium durability
                else
                    frame.text:SetTextColor(1, 0.3, 0.3) -- Red for low durability
                end
            else
                frame.text:SetText("Gear: N/A")
                frame.text:SetTextColor(0.7, 0.7, 0.7) -- Gray for no data
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Equipment Durability")
            local total, broken = 0, 0
            for i = 1, 18 do
                local durability, maxDurability = GetInventoryItemDurability(i)
                if durability and maxDurability then
                    total = total + 1
                    if durability == 0 then
                        broken = broken + 1
                    end
                end
            end
            
            if total > 0 then
                local percent = ((total - broken) / total) * 100
                GameTooltip:AddLine(string.format("Overall: %.1f%%", percent), 1, 1, 1)
                
                -- Add condition assessment
                if percent >= 75 then
                    GameTooltip:AddLine("Excellent condition", 0.3, 1, 0.3)
                elseif percent >= 50 then
                    GameTooltip:AddLine("Good condition", 1, 1, 0.3)
                elseif percent >= 25 then
                    GameTooltip:AddLine("Fair condition", 1, 0.8, 0.3)
                else
                    GameTooltip:AddLine("Poor condition - repair needed!", 1, 0.3, 0.3)
                end
                
                if broken > 0 then
                    GameTooltip:AddLine(string.format("%d broken items", broken), 1, 0.2, 0.2)
                end
            else
                GameTooltip:AddLine("No equipment data", 0.8, 0.8, 0.8)
            end
        end
    },
    gold = {
        name = "Gold",
        color = {1, 0.8, 0}, -- Gold color
        update = function(frame)
            local money = GetMoney()
            local gold = math.floor(money / 10000)
            local silver = math.floor((money % 10000) / 100)
            local copper = money % 100
            
            -- Format gold with commas for readability
            local function FormatGold(amount)
                local formatted = tostring(amount)
                local k = 1
                while k <= #formatted do
                    k = k + 1
                end
                -- Add commas every 3 digits from right
                local result = ""
                local count = 0
                for i = #formatted, 1, -1 do
                    if count == 3 then
                        result = "," .. result
                        count = 0
                    end
                    result = formatted:sub(i, i) .. result
                    count = count + 1
                end
                return result
            end
            
            if gold > 0 then
                local goldStr = FormatGold(gold)
                frame.text:SetText(string.format("%sg %ds %dc", goldStr, silver, copper))
            elseif silver > 0 then
                frame.text:SetText(string.format("%ds %dc", silver, copper))
            else
                frame.text:SetText(string.format("%dc", copper))
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Currency")
            local money = GetMoney()
            local gold = math.floor(money / 10000)
            local silver = math.floor((money % 10000) / 100)
            local copper = money % 100
            
            -- Format with commas for tooltip too
            local function FormatGold(amount)
                local formatted = tostring(amount)
                local result = ""
                local count = 0
                for i = #formatted, 1, -1 do
                    if count == 3 then
                        result = "," .. result
                        count = 0
                    end
                    result = formatted:sub(i, i) .. result
                    count = count + 1
                end
                return result
            end
            
            local goldStr = FormatGold(gold)
            GameTooltip:AddLine(string.format("Total: %s gold, %d silver, %d copper", goldStr, silver, copper), 1, 1, 1)
            GameTooltip:AddLine(string.format("Raw copper: %s", FormatGold(money)), 0.8, 0.8, 0.8)
        end
    },
    guild = {
        name = "Guild",
        color = {0.25, 1, 0.25}, -- Green
        icon = "Interface\\GossipFrame\\TabardGossipIcon", -- Guild tabard icon
        update = function(frame)
            if IsInGuild() then
                local numTotal, numOnline = GetNumGuildMembers()
                -- Use icon + numbers instead of text
                if frame.icon then
                    frame.text:SetText(string.format("%d/%d", numOnline, numTotal))
                else
                    frame.text:SetText(string.format("Guild: %d/%d", numOnline, numTotal))
                end
            else
                frame.text:SetText("No Guild")
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Guild Information")
            if IsInGuild() then
                local guildName = GetGuildInfo("player")
                local numTotal, numOnline = GetNumGuildMembers()
                GameTooltip:AddLine(guildName, 0.25, 1, 0.25)
                GameTooltip:AddLine(string.format("Online: %d/%d", numOnline, numTotal), 1, 1, 1)
                
                if numOnline > 0 and numOnline <= 15 then -- Increased from 10 to 15
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Online Members:", 1, 1, 0)
                    
                    -- Get player's faction for comparison
                    local playerFaction = UnitFactionGroup("player")
                    
                    for i = 1, numTotal do
                        local name, _, _, level, _, zone, _, _, online = GetGuildRosterInfo(i)
                        if online and name then
                            -- Get class info for class colors
                            local _, class = UnitClass(name)
                            local classColor = RAID_CLASS_COLORS[class] or {r=1, g=1, b=1}
                            
                            -- Try to determine faction (this is tricky in guild context)
                            -- We'll use the player's faction as default since guild members are same faction
                            local factionColor = {r=1, g=1, b=1} -- Default white
                            if playerFaction == "Alliance" then
                                factionColor = {r=0.3, g=0.6, b=1} -- Blue for Alliance
                            elseif playerFaction == "Horde" then
                                factionColor = {r=1, g=0.3, b=0.3} -- Red for Horde
                            end
                            
                            -- Combine class and faction colors (use class color with faction tint)
                            local finalR = (classColor.r + factionColor.r) / 2
                            local finalG = (classColor.g + factionColor.g) / 2
                            local finalB = (classColor.b + factionColor.b) / 2
                            
                            GameTooltip:AddLine(string.format("%s (%d) - %s", name, level, zone or "Unknown"), finalR, finalG, finalB)
                        end
                    end
                end
            else
                GameTooltip:AddLine("Not in a guild", 0.8, 0.8, 0.8)
            end
        end
    },
    friends = {
        name = "Friends",
        color = {0.5, 0.5, 1}, -- Light blue
        icon = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon", -- Friends icon
        update = function(frame)
            local numBNetOnline = select(2, BNGetNumFriends()) or 0
            local numWoWOnline = 0
            
            local numWoWFriends = C_FriendList.GetNumFriends() or 0
            for i = 1, numWoWFriends do
                local friendInfo = C_FriendList.GetFriendInfoByIndex(i)
                if friendInfo and friendInfo.connected then
                    numWoWOnline = numWoWOnline + 1
                end
            end
            
            local total = numBNetOnline + numWoWOnline
            -- Use icon + numbers instead of text
            if frame.icon then
                frame.text:SetText(string.format("%d", total))
            else
                frame.text:SetText(string.format("Friends: %d", total))
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Friends List")
            local numBNetTotal, numBNetOnline = BNGetNumFriends()
            numBNetOnline = numBNetOnline or 0
            local numWoWOnline = 0
            
            local numWoWFriends = C_FriendList.GetNumFriends() or 0
            for i = 1, numWoWFriends do
                local friendInfo = C_FriendList.GetFriendInfoByIndex(i)
                if friendInfo and friendInfo.connected then
                    numWoWOnline = numWoWOnline + 1
                end
            end
            
            GameTooltip:AddLine(string.format("Battle.net: %d online", numBNetOnline), 0.5, 0.8, 1)
            GameTooltip:AddLine(string.format("WoW: %d online", numWoWOnline), 0.5, 0.8, 1)
            GameTooltip:AddLine(string.format("Total Online: %d", numBNetOnline + numWoWOnline), 1, 1, 1)
            
            -- Show some Battle.net friends with faction colors if available
            if numBNetOnline > 0 and numBNetOnline <= 10 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Battle.net Friends:", 1, 1, 0)
                
                for i = 1, numBNetTotal do
                    local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
                    if accountInfo and accountInfo.isOnline then
                        local name = accountInfo.accountName or "Unknown"
                        local gameAccountInfo = accountInfo.gameAccountInfo
                        
                        if gameAccountInfo and gameAccountInfo.isOnline then
                            local characterName = gameAccountInfo.characterName
                            local realmName = gameAccountInfo.realmName
                            local factionName = gameAccountInfo.factionName
                            
                            -- Color code by faction
                            local factionColor = {r=1, g=1, b=1} -- Default white
                            if factionName == "Alliance" then
                                factionColor = {r=0.3, g=0.6, b=1} -- Blue
                            elseif factionName == "Horde" then
                                factionColor = {r=1, g=0.3, b=0.3} -- Red
                            end
                            
                            local displayText = name
                            if characterName and realmName then
                                displayText = string.format("%s (%s-%s)", name, characterName, realmName)
                            elseif characterName then
                                displayText = string.format("%s (%s)", name, characterName)
                            end
                            
                            GameTooltip:AddLine(displayText, factionColor.r, factionColor.g, factionColor.b)
                        else
                            GameTooltip:AddLine(name, 0.8, 0.8, 0.8) -- Gray for non-WoW games
                        end
                    end
                end
            end
        end
    },
    latency = {
        name = "Latency",
        color = {1, 0.5, 1}, -- Light purple
        update = function(frame)
            local _, _, lagHome, lagWorld = GetNetStats()
            -- Show the higher of home or world latency
            local maxLatency = math.max(lagHome or 0, lagWorld or 0)
            
            frame.text:SetText(string.format("%dms", maxLatency))
            
            -- Color coding based on latency
            if maxLatency > 300 then
                frame.text:SetTextColor(1, 0.3, 0.3) -- Red for high latency
            elseif maxLatency > 150 then
                frame.text:SetTextColor(1, 1, 0.3) -- Yellow for medium latency
            else
                frame.text:SetTextColor(0.3, 1, 0.3) -- Green for good latency
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Network Latency")
            local _, _, lagHome, lagWorld = GetNetStats()
            
            GameTooltip:AddLine(string.format("Home Latency: %d ms", lagHome or 0), 1, 1, 1)
            GameTooltip:AddLine(string.format("World Latency: %d ms", lagWorld or 0), 1, 1, 1)
            GameTooltip:AddLine(" ")
            
            local maxLatency = math.max(lagHome or 0, lagWorld or 0)
            if maxLatency <= 50 then
                GameTooltip:AddLine("Excellent connection", 0.3, 1, 0.3)
            elseif maxLatency <= 100 then
                GameTooltip:AddLine("Good connection", 0.8, 1, 0.3)
            elseif maxLatency <= 150 then
                GameTooltip:AddLine("Fair connection", 1, 1, 0.3)
            elseif maxLatency <= 300 then
                GameTooltip:AddLine("Poor connection", 1, 0.8, 0.3)
            else
                GameTooltip:AddLine("Very poor connection", 1, 0.3, 0.3)
            end
        end
    },
    mail = {
        name = "Mail",
        color = {1, 1, 0.8}, -- Light yellow
        update = function(frame)
            local hasNewMail = HasNewMail()
            local numUnreadMail = 0
            
            -- Try to get unread mail count
            if C_Mail and C_Mail.GetNumUnreadMail then
                numUnreadMail = C_Mail.GetNumUnreadMail() or 0
            end
            
            if hasNewMail or numUnreadMail > 0 then
                if numUnreadMail > 0 then
                    frame.text:SetText(string.format("Mail: %d", numUnreadMail))
                else
                    frame.text:SetText("Mail: New")
                end
                -- Color it more prominently when there's mail
                frame.text:SetTextColor(1, 1, 0.3) -- Bright yellow
            else
                frame.text:SetText("Mail: 0")
                frame.text:SetTextColor(0.7, 0.7, 0.7) -- Gray when no mail
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Mail Status")
            local hasNewMail = HasNewMail()
            local numUnreadMail = 0
            
            if C_Mail and C_Mail.GetNumUnreadMail then
                numUnreadMail = C_Mail.GetNumUnreadMail() or 0
            end
            
            if hasNewMail or numUnreadMail > 0 then
                if numUnreadMail > 0 then
                    GameTooltip:AddLine(string.format("Unread mail: %d", numUnreadMail), 1, 1, 0.3)
                else
                    GameTooltip:AddLine("You have new mail!", 1, 1, 0.3)
                end
            else
                GameTooltip:AddLine("No new mail", 0.7, 0.7, 0.7)
            end
        end
    }
}

-- Create a data text frame
local function CreateDataTextFrame(key, config, parent)
    local frame = CreateFrame("Frame", "MiniMapimousDataText_" .. key, parent)
    frame:SetSize(100, 20)
    
    -- Set frame strata and level to be relative to parent
    -- This ensures the data text appears properly within its parent bar
    if parent then
        frame:SetFrameStrata(parent:GetFrameStrata())
        frame:SetFrameLevel(parent:GetFrameLevel() + 1)
    else
        frame:SetFrameStrata("MEDIUM")
        frame:SetFrameLevel(20)
    end
    
    -- Determine font size based on parent bar
    local fontSize = 13 -- Default
    if parent then
        local parentName = parent:GetName()
        if parentName == "MiniMapimousMinimapDataBar" then
            fontSize = 15 -- Fixed larger size for minimap - make it stand out
        elseif parentName == "MiniMapimousOtherDataBar" then
            fontSize = Options:get("otherDataBarFontSize") or 13
        elseif parentName == "MiniMapimousSecondDataBar" then
            fontSize = Options:get("secondDataBarFontSize") or 13
        end
    end
    
    -- Create icon if the config has one
    if config.icon then
        frame.icon = frame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetSize(16, 16)
        frame.icon:SetPoint("LEFT", frame, "LEFT", 2, 0)
        frame.icon:SetTexture(config.icon)
        
        -- Create text positioned next to icon
        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.text:SetPoint("LEFT", frame.icon, "RIGHT", 4, 0)
        frame.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
        frame.text:SetTextColor(unpack(config.color))
        frame.text:SetShadowOffset(2, -2)
        frame.text:SetShadowColor(0, 0, 0, 1)
        
        -- Adjust frame width to accommodate icon + text
        frame:SetWidth(80) -- Slightly wider for icon + text
    else
        -- Create text centered (no icon)
        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.text:SetPoint("CENTER")
        frame.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
        frame.text:SetTextColor(unpack(config.color))
        frame.text:SetShadowOffset(2, -2)
        frame.text:SetShadowColor(0, 0, 0, 1)
    end
    
    -- Set initial text to ensure it's visible
    frame.text:SetText(config.name or key)
    
    -- Mouse events for tooltip - but allow dragging to pass through
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        config.tooltip()
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Click functionality for specific data texts
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            if key == "memory" then
                -- Run garbage collection for memory data text
                collectgarbage("collect")
                
                -- Force immediate update
                if config.update then
                    config.update(self)
                end
            elseif key == "mail" then
                -- Mail data text is unclickable - do nothing
                return
            elseif config.onClick then
                -- Call the onClick function if it exists
                config.onClick()
            else
                -- If no specific click action, pass the event to parent for dragging
                if self:GetParent() and self:GetParent().OnDragStart then
                    self:GetParent():GetScript("OnDragStart")(self:GetParent())
                end
            end
        end
    end)
    
    -- Allow drag events to pass through to parent
    frame:SetScript("OnDragStart", function(self)
        if self:GetParent() and self:GetParent():GetScript("OnDragStart") then
            self:GetParent():GetScript("OnDragStart")(self:GetParent())
        end
    end)
    
    frame:SetScript("OnDragStop", function(self)
        if self:GetParent() and self:GetParent():GetScript("OnDragStop") then
            self:GetParent():GetScript("OnDragStop")(self:GetParent())
        end
    end)
    
    -- Register for drag to enable pass-through
    frame:RegisterForDrag("LeftButton")
    
    -- Store config and update function
    frame.config = config
    frame.key = key
    
    return frame
end

-- Create the "First Data Bar"
local function CreateOtherDataBar()
    if otherDataBar then 
        return otherDataBar 
    end
    
    otherDataBar = CreateFrame("Frame", "MiniMapimousOtherDataBar", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    otherDataBar:SetSize(400, 25) -- Default size, will be dynamically adjusted
    
    -- Position from saved location or default to top center
    local savedPos = Options:get("otherDataBarPosition")
    if savedPos and savedPos.x and savedPos.y then
        otherDataBar:SetPoint("CENTER", UIParent, "CENTER", savedPos.x, savedPos.y)
    else
        otherDataBar:SetPoint("TOP", UIParent, "TOP", 0, -100)
    end
    
    -- Set frame strata for visibility
    otherDataBar:SetFrameStrata("HIGH")
    otherDataBar:SetFrameLevel(10)
    
    -- Make it draggable
    otherDataBar:SetMovable(true)
    otherDataBar:EnableMouse(true)
    otherDataBar:RegisterForDrag("LeftButton")
    
    otherDataBar:SetScript("OnDragStart", function(self)
        if not Options:get("lockDataBars") then
            self:StartMoving()
        end
    end)
    
    otherDataBar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position relative to screen center
        local centerX, centerY = UIParent:GetCenter()
        local barX, barY = self:GetCenter()
        local relativeX = barX - centerX
        local relativeY = barY - centerY
        Options:set("otherDataBarPosition", {x = relativeX, y = relativeY})
    end)
    
    -- Add visual feedback for dragging
    otherDataBar:SetScript("OnEnter", function(self)
        if not Options:get("lockDataBars") then
            self:SetBackdropBorderColor(0.8, 0.8, 1, 1) -- Light blue when hoverable
        end
    end)
    
    otherDataBar:SetScript("OnLeave", function(self)
        -- Restore normal border color based on lock state
        if Options:get("lockDataBars") then
            self:SetBackdropBorderColor(0.8, 0.2, 0.2, 0.8) -- Red when locked
        else
            self:SetBackdropBorderColor(0.5, 0.5, 1, 1) -- Blue when unlocked
        end
    end)
    
    -- Background with visible colors
    otherDataBar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    otherDataBar:SetBackdropColor(0, 0, 0, 0.9)
    otherDataBar:SetBackdropBorderColor(0.5, 0.5, 1, 1)
    
    -- Apply initial opacity to backdrop only
    local opacity = Options:get("otherDataBarOpacity") or 0.9
    otherDataBar:SetBackdropColor(0, 0, 0, 0.9 * opacity)
    otherDataBar:SetBackdropBorderColor(0.5, 0.5, 1, 1 * opacity)
    
    -- Show the bar immediately
    otherDataBar:Show()
    
    return otherDataBar
end

-- Create the "Second Data Bar"
local function CreateSecondDataBar()
    if secondDataBar then 
        return secondDataBar 
    end
    
    secondDataBar = CreateFrame("Frame", "MiniMapimousSecondDataBar", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    secondDataBar:SetSize(400, 25) -- Default size, will be dynamically adjusted
    
    -- Position from saved location or default to bottom center
    local savedPos = Options:get("secondDataBarPosition")
    if savedPos and savedPos.x and savedPos.y then
        secondDataBar:SetPoint("CENTER", UIParent, "CENTER", savedPos.x, savedPos.y)
    else
        secondDataBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 100)
    end
    
    -- Set frame strata for visibility
    secondDataBar:SetFrameStrata("HIGH")
    secondDataBar:SetFrameLevel(10)
    
    -- Make it draggable
    secondDataBar:SetMovable(true)
    secondDataBar:EnableMouse(true)
    secondDataBar:RegisterForDrag("LeftButton")
    
    secondDataBar:SetScript("OnDragStart", function(self)
        if not Options:get("lockDataBars") then
            self:StartMoving()
        end
    end)
    
    secondDataBar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position relative to screen center
        local centerX, centerY = UIParent:GetCenter()
        local barX, barY = self:GetCenter()
        local relativeX = barX - centerX
        local relativeY = barY - centerY
        Options:set("secondDataBarPosition", {x = relativeX, y = relativeY})
    end)
    
    -- Add visual feedback for dragging
    secondDataBar:SetScript("OnEnter", function(self)
        if not Options:get("lockDataBars") then
            secondDataBar:SetBackdropBorderColor(1, 0.8, 0.8, 1) -- Light red when hoverable
        end
    end)
    
    secondDataBar:SetScript("OnLeave", function(self)
        -- Restore normal border color based on lock state
        if Options:get("lockDataBars") then
            secondDataBar:SetBackdropBorderColor(0.8, 0.2, 0.2, 0.8) -- Red when locked
        else
            secondDataBar:SetBackdropBorderColor(1, 0.5, 0.5, 1) -- Reddish when unlocked
        end
    end)
    
    -- Background with visible colors (different from other bar)
    secondDataBar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    secondDataBar:SetBackdropColor(0, 0, 0, 0.9)
    secondDataBar:SetBackdropBorderColor(1, 0.5, 0.5, 1) -- Reddish border to distinguish from other bar
    
    -- Apply initial opacity to backdrop only
    local opacity = Options:get("secondDataBarOpacity") or 0.9
    secondDataBar:SetBackdropColor(0, 0, 0, 0.9 * opacity)
    secondDataBar:SetBackdropBorderColor(1, 0.5, 0.5, 1 * opacity)
    
    -- Show the bar immediately
    secondDataBar:Show()
    
    return secondDataBar
end

-- Create the "Minimap Data Bar"
local function CreateMinimapDataBar()
    if minimapDataBar then return minimapDataBar end
    
    minimapDataBar = CreateFrame("Frame", "MiniMapimousMinimapDataBar", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    
    -- Set size to exactly match minimap width (accounting for scale)
    local minimapWidth = Minimap:GetWidth() * Minimap:GetScale()
    minimapDataBar:SetSize(minimapWidth, 25)
    
    -- Position to align perfectly with minimap edges
    minimapDataBar:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -5)
    minimapDataBar:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -5)
    
    -- Set scale to match minimap scale
    minimapDataBar:SetScale(Minimap:GetScale())
    
    -- NOT draggable - minimap bar should stay attached to minimap
    -- Removed all dragging functionality
    
    -- No visual feedback for dragging since it's not draggable
    minimapDataBar:SetScript("OnEnter", function(self)
        -- Just show that it exists, no dragging feedback
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1) -- Slightly lighter border on hover
    end)
    
    minimapDataBar:SetScript("OnLeave", function(self)
        -- Restore normal border color
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8) -- Normal border
    end)
    
    -- Background
    minimapDataBar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    minimapDataBar:SetBackdropColor(0, 0, 0, 0.8)
    minimapDataBar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    
    -- Set frame strata to ensure it's visible
    minimapDataBar:SetFrameStrata("MEDIUM")
    minimapDataBar:SetFrameLevel(10)
    
    -- Apply initial opacity to backdrop only
    local opacity = Options:get("minimapDataBarOpacity") or 0.9
    minimapDataBar:SetBackdropColor(0, 0, 0, 0.8 * opacity)
    minimapDataBar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8 * opacity)
    
    return minimapDataBar
end

-- Update minimap data bar size and position to match minimap scale
function DataTexts:UpdateMinimapDataBarScale()
    if not minimapDataBar then return end
    
    local minimapScale = Minimap:GetScale()
    
    -- Update scale to match minimap
    minimapDataBar:SetScale(minimapScale)
    
    -- Recalculate size to match minimap width (at base scale, then scaled)
    local minimapWidth = Minimap:GetWidth()
    minimapDataBar:SetSize(minimapWidth, 25)
    
    -- Reposition to maintain perfect alignment with minimap edges
    minimapDataBar:ClearAllPoints()
    minimapDataBar:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -5)
    minimapDataBar:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -5)
    
    -- Reposition data texts within the scaled bar
    self:PositionMinimapDataTexts()
end

-- Position data texts in minimap area
function DataTexts:PositionMinimapDataTexts()
    local count = 0
    for _, frame in pairs(minimapDataTexts) do
        if frame:IsShown() then
            count = count + 1
        end
    end
    
    -- Only hide if user explicitly disabled it, not if count is 0
    if not Options:get("showMinimapDataBar") then
        if minimapDataBar then
            minimapDataBar:Hide()
        end
        return
    end
    
    -- Show the minimap data bar if user wants it visible
    if not minimapDataBar then
        CreateMinimapDataBar()
    end
    
    minimapDataBar:Show()
    
    -- If no data texts, the bar will still maintain minimap width
    if count == 0 then
        -- Bar maintains minimap alignment even when empty
        return
    end
    
    -- First update all data texts to get current content
    for key, frame in pairs(minimapDataTexts) do
        if frame:IsShown() and frame.config and frame.config.update then
            frame.config.update(frame)
        end
    end
    
    -- Calculate actual text widths dynamically
    local totalTextWidth = 0
    local textWidths = {}
    local maxTextWidth = 0
    
    for key, frame in pairs(minimapDataTexts) do
        if frame:IsShown() and frame.text then
            -- Get actual text width with padding, accounting for icons
            local baseWidth = frame.text:GetStringWidth() + 12 -- Reduced from 20px to 12px padding
            local iconWidth = frame.icon and 20 or 0 -- 16px icon + 4px spacing
            local textWidth = math.max(baseWidth + iconWidth, 50) -- Reduced minimum from 80px to 50px
            textWidths[key] = textWidth
            totalTextWidth = totalTextWidth + textWidth
            maxTextWidth = math.max(maxTextWidth, textWidth)
        end
    end
    
    -- Calculate spacing and ensure bar uses full minimap width
    local minimapWidth = Minimap:GetWidth()
    local spacing = count > 1 and 4 or 0 -- Reduced from 8px to 4px between texts
    local totalSpacing = (count - 1) * spacing
    local padding = 12 -- Reduced from 16px to 12px padding on sides
    
    -- The bar always matches minimap width exactly
    -- We don't change the bar width - it's set by the minimap alignment
    
    -- Position texts with proper spacing, centered within the minimap-width bar
    local availableWidth = minimapWidth - padding
    local startX = -(totalTextWidth + totalSpacing) / 2
    local currentX = startX
    
    for key, frame in pairs(minimapDataTexts) do
        if frame:IsShown() then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", minimapDataBar, "CENTER", currentX + (textWidths[key] / 2), 0)
            currentX = currentX + textWidths[key] + spacing
        end
    end
end

-- Position data texts in the first data bar
local function PositionOtherDataTexts()
    local count = 0
    for key, frame in pairs(otherDataTexts) do
        if frame:IsShown() then
            count = count + 1
        end
    end
    
    -- Only hide if user explicitly disabled it, not if count is 0
    if not Options:get("showOtherDataBar") then
        if otherDataBar then
            otherDataBar:Hide()
        end
        return
    end
    
    -- Show and position the other data bar if user wants it visible
    if not otherDataBar then
        CreateOtherDataBar()
    end
    
    otherDataBar:Show()
    
    -- If no data texts, show minimal bar
    if count == 0 then
        otherDataBar:SetWidth(150) -- Minimal width when empty
        return
    end
    
    -- Update all data texts first to get current content
    for key, frame in pairs(otherDataTexts) do
        if frame:IsShown() and frame.config and frame.config.update then
            frame.config.update(frame)
        end
    end
    
    -- Calculate actual text widths dynamically (similar to minimap bar)
    local totalTextWidth = 0
    local textWidths = {}
    
    for key, frame in pairs(otherDataTexts) do
        if frame:IsShown() and frame.text then
            -- Get actual text width with padding, accounting for icons
            local baseWidth = frame.text:GetStringWidth() + 12 -- Reduced from 20px to 12px padding
            local iconWidth = frame.icon and 20 or 0 -- 16px icon + 4px spacing
            local textWidth = math.max(baseWidth + iconWidth, 50) -- Reduced minimum from 80px to 50px
            textWidths[key] = textWidth
            totalTextWidth = totalTextWidth + textWidth
        end
    end
    
    -- Calculate spacing and total bar width
    local spacing = count > 1 and 8 or 0 -- Reduced from 15px to 8px between texts
    local totalSpacing = (count - 1) * spacing
    local padding = 16 -- Reduced from 20px to 16px padding on sides
    local calculatedBarWidth = totalTextWidth + totalSpacing + padding
    
    -- Ensure minimum and maximum bar widths
    local minWidth = 150
    local finalBarWidth = math.max(minWidth, calculatedBarWidth) -- Removed maxWidth constraint
    
    -- Set the dynamic bar width
    otherDataBar:SetWidth(finalBarWidth)
    
    -- Position texts with proper spacing
    local startX = -(totalTextWidth + totalSpacing) / 2
    local currentX = startX
    
    for key, frame in pairs(otherDataTexts) do
        if frame:IsShown() then
            frame:ClearAllPoints()
            local xPos = currentX + (textWidths[key] / 2)
            frame:SetPoint("CENTER", otherDataBar, "CENTER", xPos, 0)
            currentX = currentX + textWidths[key] + spacing
        end
    end
end

-- Position data texts in the second data bar
local function PositionSecondDataTexts()
    local count = 0
    for key, frame in pairs(secondDataTexts) do
        if frame:IsShown() then
            count = count + 1
        end
    end
    
    -- Only hide if user explicitly disabled it, not if count is 0
    if not Options:get("showSecondDataBar") then
        if secondDataBar then
            secondDataBar:Hide()
        end
        return
    end
    
    -- Show and position the second data bar if user wants it visible
    if not secondDataBar then
        CreateSecondDataBar()
    end
    
    secondDataBar:Show()
    
    -- If no data texts, show minimal bar
    if count == 0 then
        secondDataBar:SetWidth(150) -- Minimal width when empty
        return
    end
    
    -- Update all data texts first to get current content
    for key, frame in pairs(secondDataTexts) do
        if frame:IsShown() and frame.config and frame.config.update then
            frame.config.update(frame)
        end
    end
    
    -- Calculate actual text widths dynamically (similar to other bars)
    local totalTextWidth = 0
    local textWidths = {}
    
    for key, frame in pairs(secondDataTexts) do
        if frame:IsShown() and frame.text then
            -- Get actual text width with padding, accounting for icons
            local baseWidth = frame.text:GetStringWidth() + 12 -- Reduced from 20px to 12px padding
            local iconWidth = frame.icon and 20 or 0 -- 16px icon + 4px spacing
            local textWidth = math.max(baseWidth + iconWidth, 50) -- Reduced minimum from 80px to 50px
            textWidths[key] = textWidth
            totalTextWidth = totalTextWidth + textWidth
        end
    end
    
    -- Calculate spacing and total bar width
    local spacing = count > 1 and 8 or 0 -- Reduced from 15px to 8px between texts
    local totalSpacing = (count - 1) * spacing
    local padding = 16 -- Reduced from 20px to 16px padding on sides
    local calculatedBarWidth = totalTextWidth + totalSpacing + padding
    
    -- Ensure minimum and maximum bar widths
    local minWidth = 150
    local finalBarWidth = math.max(minWidth, calculatedBarWidth) -- Removed maxWidth constraint
    
    -- Set the dynamic bar width
    secondDataBar:SetWidth(finalBarWidth)
    
    -- Position texts with proper spacing
    local startX = -(totalTextWidth + totalSpacing) / 2
    local currentX = startX
    
    for key, frame in pairs(secondDataTexts) do
        if frame:IsShown() then
            frame:ClearAllPoints()
            local xPos = currentX + (textWidths[key] / 2)
            frame:SetPoint("CENTER", secondDataBar, "CENTER", xPos, 0)
            currentX = currentX + textWidths[key] + spacing
        end
    end
end

-- Refresh all data texts based on current settings
function DataTexts:RefreshDataTexts()
    -- Prevent rapid successive refreshes
    if self.refreshing then 
        return 
    end
    self.refreshing = true
    
    -- Clear existing assignments
    for key, frame in pairs(minimapDataTexts) do
        frame:SetParent(UIParent)
        frame:Hide()
        minimapDataTexts[key] = nil
    end
    
    for key, frame in pairs(otherDataTexts) do
        frame:SetParent(UIParent)
        frame:Hide()
        otherDataTexts[key] = nil
    end
    
    for key, frame in pairs(secondDataTexts) do
        frame:SetParent(UIParent)
        frame:Hide()
        secondDataTexts[key] = nil
    end
    
    -- Reassign based on current settings
    for key, config in pairs(availableDataTexts) do
        local position = Options:get("dataText_" .. key .. "_position") or "other"
        
        if position ~= "hide" then
            local frame = dataTextFrames[key]
            if not frame then
                frame = CreateDataTextFrame(key, config, UIParent)
                dataTextFrames[key] = frame
            end
            
            if position == "minimap" then
                if not minimapDataBar then
                    CreateMinimapDataBar()
                end
                frame:SetParent(minimapDataBar)
                -- Update frame strata to match new parent
                frame:SetFrameStrata(minimapDataBar:GetFrameStrata())
                frame:SetFrameLevel(minimapDataBar:GetFrameLevel() + 1)
                minimapDataTexts[key] = frame
                frame:Show()
            elseif position == "other" then
                if not otherDataBar then
                    CreateOtherDataBar()
                end
                frame:SetParent(otherDataBar)
                -- Update frame strata to match new parent
                frame:SetFrameStrata(otherDataBar:GetFrameStrata())
                frame:SetFrameLevel(otherDataBar:GetFrameLevel() + 1)
                otherDataTexts[key] = frame
                frame:Show()
            elseif position == "second" then
                if not secondDataBar then
                    CreateSecondDataBar()
                end
                frame:SetParent(secondDataBar)
                -- Update frame strata to match new parent
                frame:SetFrameStrata(secondDataBar:GetFrameStrata())
                frame:SetFrameLevel(secondDataBar:GetFrameLevel() + 1)
                secondDataTexts[key] = frame
                frame:Show()
            end
        end
    end
    
    -- Position everything
    self:PositionMinimapDataTexts()
    PositionOtherDataTexts()
    PositionSecondDataTexts()
    
    -- Update lock states
    self:UpdateDataBarLocks()
    
    -- Reset refresh flag after a short delay
    C_Timer.After(0.1, function()
        self.refreshing = false
    end)
end

-- Update all visible data texts
local function UpdateDataTexts()
    for key, frame in pairs(dataTextFrames) do
        if frame:IsShown() and frame.config and frame.config.update then
            frame.config.update(frame)
        end
    end
    
    -- Reposition both bars occasionally for dynamic width changes
    -- This prevents infinite repositioning loops while still allowing dynamic resizing
    if math.random(1, 5) == 1 then -- 20% of the time (every 5 seconds on average)
        local DataTexts = addon.import("DataTexts")
        DataTexts:PositionMinimapDataTexts()
        PositionOtherDataTexts() -- Also reposition the other data bar for dynamic width
        PositionSecondDataTexts() -- Also reposition the second data bar for dynamic width
    end
end

-- Initialize data texts
function DataTexts:Initialize()
    -- Ensure lockDataBars has a default value
    if Options:get("lockDataBars") == nil then
        Options:set("lockDataBars", false)
    end
    
    -- Enable CPU profiling for performance tracking
    if GetCVar("scriptProfile") ~= "1" then
        SetCVar("scriptProfile", "1")
    end
    
    -- Reset CPU usage tracking periodically for more accurate readings
    C_Timer.NewTicker(10, function()
        ResetCPUUsage()
    end)
    
    -- Create update timer
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function(self, elapsed)
        self.timer = (self.timer or 0) + elapsed
        if self.timer >= 1 then -- Update every second
            UpdateDataTexts()
            self.timer = 0
        end
    end)
    
    -- Register mail events for immediate updates
    local mailEventFrame = CreateFrame("Frame")
    mailEventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
    mailEventFrame:RegisterEvent("UPDATE_PENDING_MAIL")
    mailEventFrame:RegisterEvent("MAIL_CLOSED")
    mailEventFrame:SetScript("OnEvent", function(self, event, ...)
        -- Update mail data text immediately when mail events occur
        if dataTextFrames.mail and dataTextFrames.mail:IsShown() then
            local config = availableDataTexts.mail
            if config and config.update then
                config.update(dataTextFrames.mail)
            end
        end
    end)
    
    -- Initial refresh
    self:RefreshDataTexts()
    
    -- Force create first data bar if enabled (ensures it appears)
    if Options:get("showOtherDataBar") then
        CreateOtherDataBar()
        PositionOtherDataTexts()
    end
end

-- Get available data texts
function DataTexts:GetAvailableDataTexts()
    return availableDataTexts
end

-- Update data bar lock states
function DataTexts:UpdateDataBarLocks()
    local isLocked = Options:get("lockDataBars")
    
    -- Minimap data bar is not included in lock system since it's not draggable
    -- It always stays attached to the minimap
    
    if otherDataBar then
        if isLocked then
            otherDataBar:SetBackdropBorderColor(0.8, 0.2, 0.2, 0.8) -- Red border when locked
        else
            otherDataBar:SetBackdropBorderColor(0.5, 0.5, 1, 1) -- Blue border when unlocked
        end
    end
    
    if secondDataBar then
        if isLocked then
            secondDataBar:SetBackdropBorderColor(0.8, 0.2, 0.2, 0.8) -- Red border when locked
        else
            secondDataBar:SetBackdropBorderColor(1, 0.5, 0.5, 1) -- Reddish border when unlocked
        end
    end
end

-- Update data bar opacity
function DataTexts:UpdateDataBarOpacity()
    if minimapDataBar then
        local opacity = Options:get("minimapDataBarOpacity") or 0.9
        -- Only change backdrop opacity, not frame alpha to preserve text visibility
        minimapDataBar:SetBackdropColor(0, 0, 0, 0.8 * opacity)
        minimapDataBar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8 * opacity)
    end
    
    if otherDataBar then
        local opacity = Options:get("otherDataBarOpacity") or 0.9
        -- Only change backdrop opacity, not frame alpha to preserve text visibility
        otherDataBar:SetBackdropColor(0, 0, 0, 0.9 * opacity)
        otherDataBar:SetBackdropBorderColor(0.5, 0.5, 1, 1 * opacity)
    end
    
    if secondDataBar then
        local opacity = Options:get("secondDataBarOpacity") or 0.9
        -- Only change backdrop opacity, not frame alpha to preserve text visibility
        secondDataBar:SetBackdropColor(0, 0, 0, 0.9 * opacity)
        secondDataBar:SetBackdropBorderColor(1, 0.5, 0.5, 1 * opacity)
    end
end

-- Update data bar font sizes
function DataTexts:UpdateDataBarFontSizes()
    -- Update minimap data bar texts
    for key, frame in pairs(minimapDataTexts) do
        if frame and frame.text then
            local fontSize = 15 -- Fixed larger size for minimap - make it stand out
            frame.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
        end
    end
    
    -- Update first data bar texts
    for key, frame in pairs(otherDataTexts) do
        if frame and frame.text then
            local fontSize = Options:get("otherDataBarFontSize") or 13
            frame.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
        end
    end
    
    -- Update second data bar texts
    for key, frame in pairs(secondDataTexts) do
        if frame and frame.text then
            local fontSize = Options:get("secondDataBarFontSize") or 13
            frame.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
        end
    end
    
    -- Refresh positioning to account for new text sizes
    self:PositionMinimapDataTexts()
    PositionOtherDataTexts()
    PositionSecondDataTexts()
end

-- Module is already exported at the top of the file 