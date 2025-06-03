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

-- Cache addon data to reduce expensive scans
local addonDataCache = {}
local addonCacheTimestamp = 0
local ADDON_CACHE_DURATION = 3 -- Cache addon data for 3 seconds

-- SESSION STATISTICS TRACKING
local sessionStats = {
    startTime = 0,
    startXP = 0,
    startGold = 0,
    startLevel = 0,
    fpsHistory = {},
    latencyHistory = {},
    maxHistorySize = 300, -- Keep 5 minutes of data at 1-second intervals
}

-- Initialize session tracking
local function InitializeSessionStats()
    sessionStats.startTime = GetTime()
    sessionStats.startXP = UnitXP("player")
    sessionStats.startGold = GetMoney()
    sessionStats.startLevel = UnitLevel("player")
    sessionStats.fpsHistory = {}
    sessionStats.latencyHistory = {}
end

-- Update session statistics
local function UpdateSessionStats()
    local now = GetTime()
    local fps = GetFramerate()
    local _, _, lagHome, lagWorld = GetNetStats()
    local maxLatency = math.max(lagHome or 0, lagWorld or 0)
    
    -- Add to history
    table.insert(sessionStats.fpsHistory, {time = now, value = fps})
    table.insert(sessionStats.latencyHistory, {time = now, value = maxLatency})
    
    -- Trim history to max size
    while #sessionStats.fpsHistory > sessionStats.maxHistorySize do
        table.remove(sessionStats.fpsHistory, 1)
    end
    while #sessionStats.latencyHistory > sessionStats.maxHistorySize do
        table.remove(sessionStats.latencyHistory, 1)
    end
end

-- Get session statistics
local function GetSessionStats()
    local currentTime = GetTime()
    local sessionDuration = currentTime - sessionStats.startTime
    local currentXP = UnitXP("player")
    local currentGold = GetMoney()
    local currentLevel = UnitLevel("player")
    
    -- Calculate gains
    local xpGained = 0
    local goldGained = currentGold - sessionStats.startGold
    local levelsGained = currentLevel - sessionStats.startLevel
    
    -- Handle level changes for XP calculation
    if levelsGained > 0 then
        -- Player leveled up, XP calculation is more complex
        xpGained = currentXP + (levelsGained * 1000000) -- Rough estimate
    else
        xpGained = currentXP - sessionStats.startXP
    end
    
    -- Calculate rates (per hour)
    local hoursPlayed = sessionDuration / 3600
    local xpPerHour = hoursPlayed > 0 and (xpGained / hoursPlayed) or 0
    local goldPerHour = hoursPlayed > 0 and (goldGained / hoursPlayed) or 0
    
    -- Calculate performance averages
    local avgFPS = 0
    local minFPS = 999
    local maxFPS = 0
    if #sessionStats.fpsHistory > 0 then
        local total = 0
        for _, entry in ipairs(sessionStats.fpsHistory) do
            total = total + entry.value
            minFPS = math.min(minFPS, entry.value)
            maxFPS = math.max(maxFPS, entry.value)
        end
        avgFPS = total / #sessionStats.fpsHistory
    end
    
    local avgLatency = 0
    local minLatency = 999
    local maxLatency = 0
    if #sessionStats.latencyHistory > 0 then
        local total = 0
        for _, entry in ipairs(sessionStats.latencyHistory) do
            total = total + entry.value
            minLatency = math.min(minLatency, entry.value)
            maxLatency = math.max(maxLatency, entry.value)
        end
        avgLatency = total / #sessionStats.latencyHistory
    end
    
    return {
        duration = sessionDuration,
        xpGained = xpGained,
        goldGained = goldGained,
        levelsGained = levelsGained,
        xpPerHour = xpPerHour,
        goldPerHour = goldPerHour,
        avgFPS = avgFPS,
        minFPS = minFPS == 999 and 0 or minFPS,
        maxFPS = maxFPS,
        avgLatency = avgLatency,
        minLatency = minLatency == 999 and 0 or minLatency,
        maxLatency = maxLatency
    }
end

local function GetCachedAddonData()
    local now = GetTime()
    if now - addonCacheTimestamp > ADDON_CACHE_DURATION then
        -- Refresh cache
        addonDataCache = {}
        addonCacheTimestamp = now
        
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
        
        addonDataCache.totalMemory = totalMemory
        addonDataCache.totalCPU = totalCPU
    end
    
    return addonDataCache
end

-- Available data texts configuration
local availableDataTexts = {
    memory = {
        name = "Memory",
        color = {0.7, 1, 0.7},
        update = function(frame)
            local addonData = GetCachedAddonData()
            local totalMemory = addonData.totalMemory or 0
            local totalCPU = addonData.totalCPU or 0
            
            local memStr = ""
            if totalMemory > 1024 then
                memStr = string.format("%.1fMB", totalMemory / 1024)
            else
                memStr = string.format("%.0fKB", totalMemory)
            end
            
            local cpuStr = ""
            if totalCPU > 1000 then
                cpuStr = string.format("%.1fs", totalCPU / 1000)
            elseif totalCPU > 1 then
                cpuStr = string.format("%.1fms", totalCPU)
            else
                cpuStr = string.format("%.2fms", totalCPU)
            end
            
            frame.text:SetText(string.format("%s | %s", memStr, cpuStr))
            
            if totalMemory > 50 * 1024 then
                frame.text:SetTextColor(1, 0.3, 0.3)
            elseif totalMemory > 20 * 1024 then
                frame.text:SetTextColor(1, 1, 0.3)
            else
                frame.text:SetTextColor(0.3, 1, 0.3)
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Addon Performance (CPU/Memory)")
            
            UpdateAddOnMemoryUsage()
            UpdateAddOnCPUUsage()
            
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
            
            table.sort(addonData, function(a, b) return a.memory > b.memory end)
            
            GameTooltip:AddLine(string.format("Total: %.1f MB | %.1f ms CPU (%d addons)", totalMemory / 1024, totalCPU, loadedCount), 1, 1, 1)
            GameTooltip:AddLine(" ")
            
            GameTooltip:AddLine("All Loaded Addons:", 1, 1, 0)
            
            for i, addon in ipairs(addonData) do
                local color = {1, 1, 1}
                
                if addon.memory > 5 * 1024 then
                    color = {1, 0.3, 0.3}
                elseif addon.memory > 2 * 1024 then
                    color = {1, 1, 0.3}
                elseif addon.memory > 1 * 1024 then
                    color = {1, 0.8, 0.3}
                elseif addon.memory > 512 then
                    color = {0.8, 1, 0.8}
                else
                    color = {0.6, 0.6, 0.6}
                end
                
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
        color = {1, 1, 0.5},
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
        color = {0.5, 0.8, 1},
        update = function(frame)
            local timeStr = date("%H:%M")
            frame.text:SetText(timeStr)
        end,
        tooltip = function()
            GameTooltip:SetText("Time")
            local localTime = date("%H:%M")
            local hour, minute = GetGameTime()
            local serverTime = string.format("%02d:%02d", hour, minute)
            
            GameTooltip:AddLine(string.format("Local Time: %s", localTime), 1, 1, 1)
            GameTooltip:AddLine(string.format("Server Time: %s", serverTime), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to open calendar", 0.8, 0.8, 0.8)
        end,
        onClick = function()
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
                GameTimeFrame:Click()
            else
                if C_Calendar and C_Calendar.OpenCalendar then
                    C_Calendar.OpenCalendar()
                end
            end
        end
    },
    durability = {
        name = "Durability",
        color = {1, 0.7, 0.5},
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
                
                if percent >= 75 then
                    frame.text:SetTextColor(0.3, 1, 0.3)
                elseif percent >= 25 then
                    frame.text:SetTextColor(1, 1, 0.3)
                else
                    frame.text:SetTextColor(1, 0.3, 0.3)
                end
            else
                frame.text:SetText("Gear: N/A")
                frame.text:SetTextColor(0.7, 0.7, 0.7)
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
        color = {1, 0.8, 0},
        update = function(frame)
            local money = GetMoney()
            local gold = math.floor(money / 10000)
            local silver = math.floor((money % 10000) / 100)
            local copper = money % 100
            
            local function FormatGold(amount)
                local formatted = tostring(amount)
                local k = 1
                while k <= #formatted do
                    k = k + 1
                end
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
        color = {0.25, 1, 0.25},
        icon = "Interface\\GossipFrame\\TabardGossipIcon",
        update = function(frame)
            if IsInGuild() then
                local numTotal, numOnline = GetNumGuildMembers()
                frame.text:SetText(string.format("Guild: %d", numOnline))
                
                frame.text:SetTextColor(0.25, 1, 0.25)
            else
                frame.text:SetText("Guild: 0")
                frame.text:SetTextColor(0.7, 0.7, 0.7)
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Guild Information")
            GameTooltip:SetMinimumWidth(300)
            
            if IsInGuild() then
                local guildName = GetGuildInfo("player")
                local numTotal, numOnline = GetNumGuildMembers()
                GameTooltip:AddLine(guildName, 0.25, 1, 0.25)
                GameTooltip:AddLine(string.format("Online: %d/%d", numOnline, numTotal), 1, 1, 1)
                
                local activityPercent = numTotal > 0 and (numOnline / numTotal) or 0
                if activityPercent >= 0.5 then
                    GameTooltip:AddLine("High Activity", 0.25, 1, 0.25)
                elseif activityPercent >= 0.2 then
                    GameTooltip:AddLine("Moderate Activity", 1, 1, 0.3)
                else
                    GameTooltip:AddLine("Low Activity", 0.8, 0.8, 0.8)
                end
                
                if numOnline > 0 and numOnline <= 20 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Online Members by Zone:", 1, 1, 0)
                    
                    local playerFaction = UnitFactionGroup("player")
                    local playerZone = GetZoneText() or GetSubZoneText() or "Unknown"
                    
                    local factionColor = {r=1, g=1, b=1}
                    if playerFaction == "Alliance" then
                        factionColor = {r=0.3, g=0.6, b=1}
                    elseif playerFaction == "Horde" then
                        factionColor = {r=1, g=0.3, b=0.3}
                    end
                    
                    local zoneGroups = {}
                    local sameZoneCount = 0
                    
                    for i = 1, numTotal do
                        local name, _, _, level, class, zone, _, _, online = GetGuildRosterInfo(i)
                        if online and name then
                            zone = zone or "Unknown Zone"
                            if not zoneGroups[zone] then
                                zoneGroups[zone] = {}
                            end
                            table.insert(zoneGroups[zone], {name = name, level = level, class = class})
                            
                            if zone == playerZone then
                                sameZoneCount = sameZoneCount + 1
                            end
                        end
                    end
                    
                    if sameZoneCount > 0 then
                        GameTooltip:AddLine(string.format("In %s (%d):", playerZone, sameZoneCount), 0.3, 1, 0.3)
                        for _, member in ipairs(zoneGroups[playerZone] or {}) do
                            local _, classFile = UnitClass(member.name)
                            local classColor = RAID_CLASS_COLORS[classFile or member.class] or {r=1, g=1, b=1}
                            
                            local finalR = (classColor.r + factionColor.r) / 2
                            local finalG = (classColor.g + factionColor.g) / 2
                            local finalB = (classColor.b + factionColor.b) / 2
                            
                            GameTooltip:AddLine(string.format("  %s (%d)", member.name, member.level), finalR, finalG, finalB)
                        end
                    end
                    
                    local zonesShown = sameZoneCount > 0 and 1 or 0
                    for zone, members in pairs(zoneGroups) do
                        if zone ~= playerZone and zonesShown < 4 then -- Limit to 4 zones total
                            -- Color-coordinate zone headers
                            local zoneColor = {0.8, 0.8, 1} -- Light blue for other zones
                            if zone:find("Stormwind") or zone:find("Ironforge") or zone:find("Darnassus") then
                                zoneColor = {0.3, 0.6, 1} -- Alliance blue for Alliance cities
                            elseif zone:find("Orgrimmar") or zone:find("Thunder Bluff") or zone:find("Undercity") then
                                zoneColor = {1, 0.3, 0.3} -- Horde red for Horde cities
                            elseif zone:find("Dalaran") or zone:find("Shattrath") or zone:find("Valdrakken") then
                                zoneColor = {1, 0.8, 0.3} -- Gold for neutral cities
                            end
                            
                            GameTooltip:AddLine(string.format("%s (%d):", zone, #members), zoneColor[1], zoneColor[2], zoneColor[3])
                            for j, member in ipairs(members) do
                                if j <= 3 then -- Limit to 3 members per zone
                                    local _, classFile = UnitClass(member.name)
                                    local classColor = RAID_CLASS_COLORS[classFile or member.class] or {r=1, g=1, b=1}
                                    
                                    -- Apply faction tint to class colors
                                    local finalR = (classColor.r + factionColor.r) / 2
                                    local finalG = (classColor.g + factionColor.g) / 2
                                    local finalB = (classColor.b + factionColor.b) / 2
                                    
                                    GameTooltip:AddLine(string.format("  %s (%d)", member.name, member.level), finalR, finalG, finalB)
                                elseif j == 4 then
                                    GameTooltip:AddLine(string.format("  ... and %d more", #members - 3), 0.7, 0.7, 0.7)
                                    break
                                end
                            end
                            zonesShown = zonesShown + 1
                        end
                    end
                    
                    if zonesShown >= 4 then
                        local remainingZones = 0
                        for zone, _ in pairs(zoneGroups) do
                            if zone ~= playerZone then remainingZones = remainingZones + 1 end
                        end
                        if remainingZones > 3 then
                            GameTooltip:AddLine(string.format("... and %d more zones", remainingZones - 3), 0.7, 0.7, 0.7)
                        end
                    end
                end
                
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Click to open guild panel", 0.8, 0.8, 0.8)
            else
                GameTooltip:AddLine("Not in a guild", 0.8, 0.8, 0.8)
            end
        end,
        onClick = function()
            -- Open guild panel
            if ToggleGuildFrame then
                ToggleGuildFrame()
            elseif GuildFrame then
                if GuildFrame:IsShown() then
                    GuildFrame:Hide()
                else
                    GuildFrame:Show()
                end
            end
        end
    },
    friends = {
        name = "Friends",
        color = {0.5, 0.5, 1}, -- Light blue
        icon = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon", -- Friends icon
        update = function(frame)
            -- Only count WoW friends for main display
            local numWoWOnline = 0
            
            local numWoWFriends = C_FriendList.GetNumFriends() or 0
            for i = 1, numWoWFriends do
                local friendInfo = C_FriendList.GetFriendInfoByIndex(i)
                if friendInfo and friendInfo.connected then
                    numWoWOnline = numWoWOnline + 1
                end
            end
            
            -- Show only WoW friends count as text
            frame.text:SetText(string.format("Friends: %d", numWoWOnline))
            
            -- Always use default Blizzard friend color (cyan)
            if numWoWOnline > 0 then
                frame.text:SetTextColor(0, 1, 1) -- Cyan for online friends (default Blizzard friend color)
            else
                frame.text:SetTextColor(0.7, 0.7, 0.7) -- Gray for no friends
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Friends List")
            -- Make tooltip wider for better readability
            GameTooltip:SetMinimumWidth(320)
            
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
            
            -- Show Battle.net friends with enhanced information
            if numBNetOnline > 0 and numBNetOnline <= 15 then -- Increased limit
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Battle.net Friends:", 1, 1, 0)
                
                -- Group friends by game
                local gameGroups = {}
                
                for i = 1, numBNetTotal do
                    local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
                    if accountInfo and accountInfo.isOnline then
                        local name = accountInfo.accountName or "Unknown"
                        local gameAccountInfo = accountInfo.gameAccountInfo
                        
                        if gameAccountInfo and gameAccountInfo.isOnline then
                            local gameName = gameAccountInfo.clientProgram or "Unknown"
                            local characterName = gameAccountInfo.characterName
                            local realmName = gameAccountInfo.realmName
                            local factionName = gameAccountInfo.factionName
                            local zoneName = gameAccountInfo.areaName
                            
                            if not gameGroups[gameName] then
                                gameGroups[gameName] = {}
                            end
                            
                            table.insert(gameGroups[gameName], {
                                name = name,
                                character = characterName,
                                realm = realmName,
                                faction = factionName,
                                zone = zoneName
                            })
                        else
                            -- Friend online but not in a game
                            if not gameGroups["Offline"] then
                                gameGroups["Offline"] = {}
                            end
                            table.insert(gameGroups["Offline"], {name = name})
                        end
                    end
                end
                
                -- Show WoW friends first with enhanced formatting
                if gameGroups["WoW"] then
                    GameTooltip:AddLine(string.format("World of Warcraft (%d):", #gameGroups["WoW"]), 0.8, 0.8, 1)
                    for _, friend in ipairs(gameGroups["WoW"]) do
                        local factionColor = {r=1, g=1, b=1} -- Default white
                        if friend.faction == "Alliance" then
                            factionColor = {r=0.3, g=0.6, b=1} -- Blue for Alliance
                        elseif friend.faction == "Horde" then
                            factionColor = {r=1, g=0.3, b=0.3} -- Red for Horde
                        end
                        
                        local displayText = friend.name
                        if friend.character and friend.zone then
                            displayText = string.format("%s (%s in %s)", friend.name, friend.character, friend.zone)
                        elseif friend.character and friend.realm then
                            displayText = string.format("%s (%s-%s)", friend.name, friend.character, friend.realm)
                        elseif friend.character then
                            displayText = string.format("%s (%s)", friend.name, friend.character)
                        end
                        
                        GameTooltip:AddLine("  " .. displayText, factionColor.r, factionColor.g, factionColor.b)
                    end
                end
                
                -- Show other games with better formatting
                for gameName, friends in pairs(gameGroups) do
                    if gameName ~= "WoW" and gameName ~= "Offline" and #friends > 0 then
                        GameTooltip:AddLine(string.format("%s (%d):", gameName, #friends), 0.8, 0.8, 0.8)
                        for i, friend in ipairs(friends) do
                            if i <= 3 then -- Limit to prevent overflow
                                GameTooltip:AddLine("  " .. friend.name, 0.8, 0.8, 0.8)
                            elseif i == 4 then
                                GameTooltip:AddLine(string.format("  ... and %d more", #friends - 3), 0.7, 0.7, 0.7)
                                break
                            end
                        end
                    end
                end
            end
            
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to open friends panel", 0.8, 0.8, 0.8)
        end,
        onClick = function()
            -- Open friends panel
            if ToggleFriendsFrame then
                ToggleFriendsFrame()
            elseif FriendsFrame then
                if FriendsFrame:IsShown() then
                    FriendsFrame:Hide()
                else
                    FriendsFrame:Show()
                end
            end
        end
    },
    mail = {
        name = "Mail",
        color = {1, 1, 0.8},
        update = function(frame)
            local hasNewMail = HasNewMail()
            local numUnreadMail = 0
            
            if C_Mail and C_Mail.GetNumUnreadMail then
                numUnreadMail = C_Mail.GetNumUnreadMail() or 0
            end
            
            if hasNewMail or numUnreadMail > 0 then
                if numUnreadMail > 0 then
                    frame.text:SetText(string.format("Mail: %d", numUnreadMail))
                else
                    frame.text:SetText("Mail: New")
                end
                frame.text:SetTextColor(1, 1, 0.3)
            else
                frame.text:SetText("Mail: 0")
                frame.text:SetTextColor(0.7, 0.7, 0.7)
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
    },
    experience = {
        name = "Experience",
        color = {0.3, 1, 0.8},
        update = function(frame)
            local currentXP = UnitXP("player")
            local maxXP = UnitXPMax("player")
            local restXP = GetXPExhaustion() or 0
            local level = UnitLevel("player")
            
            if level >= GetMaxPlayerLevel() then
                frame.text:SetText("Max Level")
                frame.text:SetTextColor(1, 0.8, 0)
            else
                local percent = (currentXP / maxXP) * 100
                frame.text:SetText(string.format("XP: %.1f%%", percent))
                
                if restXP > 0 then
                    frame.text:SetTextColor(0.3, 1, 0.8)
                else
                    frame.text:SetTextColor(1, 1, 1)
                end
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Experience")
            local currentXP = UnitXP("player")
            local maxXP = UnitXPMax("player")
            local restXP = GetXPExhaustion() or 0
            local level = UnitLevel("player")
            
            if level >= GetMaxPlayerLevel() then
                GameTooltip:AddLine("Maximum level reached!", 1, 0.8, 0)
            else
                local percent = (currentXP / maxXP) * 100
                local needed = maxXP - currentXP
                
                GameTooltip:AddLine(string.format("Level %d: %.1f%%", level, percent), 1, 1, 1)
                GameTooltip:AddLine(string.format("XP: %s / %s", BreakUpLargeNumbers(currentXP), BreakUpLargeNumbers(maxXP)), 0.8, 0.8, 0.8)
                GameTooltip:AddLine(string.format("Needed: %s", BreakUpLargeNumbers(needed)), 0.8, 0.8, 0.8)
                
                if restXP > 0 then
                    GameTooltip:AddLine(string.format("Rested: %s (%.1f%%)", BreakUpLargeNumbers(restXP), (restXP/maxXP)*100), 0.3, 1, 0.8)
                end
            end
        end
    },
    bags = {
        name = "Bags",
        color = {0.8, 0.6, 0.4},
        update = function(frame)
            local totalSlots = 0
            local freeSlots = 0
            
            for bagID = 0, 4 do
                if GetContainerNumSlots then
                    local slots = GetContainerNumSlots(bagID) or 0
                    local free = GetContainerNumFreeSlots and GetContainerNumFreeSlots(bagID) or 0
                    totalSlots = totalSlots + slots
                    freeSlots = freeSlots + free
                elseif C_Container and C_Container.GetContainerNumSlots then
                    local slots = C_Container.GetContainerNumSlots(bagID) or 0
                    local free = C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumFreeSlots(bagID) or 0
                    totalSlots = totalSlots + slots
                    freeSlots = freeSlots + free
                end
            end
            
            local usedSlots = totalSlots - freeSlots
            frame.text:SetText(string.format("Bags: %d/%d", usedSlots, totalSlots))
            
            local fillPercent = totalSlots > 0 and (usedSlots / totalSlots) or 0
            if fillPercent >= 0.9 then
                frame.text:SetTextColor(1, 0.3, 0.3)
            elseif fillPercent >= 0.7 then
                frame.text:SetTextColor(1, 1, 0.3)
            else
                frame.text:SetTextColor(0.8, 0.6, 0.4)
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Bag Space")
            local totalSlots = 0
            local freeSlots = 0
            
            for bagID = 0, 4 do
                local slots = 0
                local free = 0
                local bagName = "Unknown"
                
                if GetContainerNumSlots then
                    slots = GetContainerNumSlots(bagID) or 0
                    free = GetContainerNumFreeSlots and GetContainerNumFreeSlots(bagID) or 0
                elseif C_Container and C_Container.GetContainerNumSlots then
                    slots = C_Container.GetContainerNumSlots(bagID) or 0
                    free = C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumFreeSlots(bagID) or 0
                end
                
                if slots > 0 then
                    if bagID == 0 then
                        bagName = "Backpack"
                    else
                        local bagSlotID = bagID + 19
                        local link = GetInventoryItemLink("player", bagSlotID)
                        if link then
                            bagName = GetItemInfo(link) or ("Bag " .. bagID)
                        else
                            bagName = "Bag " .. bagID
                        end
                    end
                    
                    local used = slots - free
                    GameTooltip:AddLine(string.format("%s: %d/%d", bagName, used, slots), 1, 1, 1)
                    totalSlots = totalSlots + slots
                    freeSlots = freeSlots + free
                end
            end
            
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format("Total: %d/%d (%d free)", totalSlots - freeSlots, totalSlots, freeSlots), 0.8, 0.8, 0.8)
        end
    },
    talents = {
        name = "Talents",
        color = {1, 0.8, 0.2}, -- Golden yellow
        update = function(frame)
            -- Check for unspent talent points
            local unspentPoints = 0
            
            -- Try different methods for different WoW versions
            if GetUnspentTalentPoints then
                unspentPoints = GetUnspentTalentPoints() or 0
            elseif C_SpecializationInfo and C_SpecializationInfo.GetUnspentSpecPoints then
                unspentPoints = C_SpecializationInfo.GetUnspentSpecPoints() or 0
            end
            
            if unspentPoints > 0 then
                frame.text:SetText(string.format("Talents: %d", unspentPoints))
                frame.text:SetTextColor(1, 1, 0.3) -- Bright yellow when unspent
            else
                frame.text:SetText("Talents: 0")
                frame.text:SetTextColor(0.7, 0.7, 0.7) -- Gray when none
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Talent Points")
            local unspentPoints = 0
            
            if GetUnspentTalentPoints then
                unspentPoints = GetUnspentTalentPoints() or 0
            elseif C_SpecializationInfo and C_SpecializationInfo.GetUnspentSpecPoints then
                unspentPoints = C_SpecializationInfo.GetUnspentSpecPoints() or 0
            end
            
            if unspentPoints > 0 then
                GameTooltip:AddLine(string.format("Unspent points: %d", unspentPoints), 1, 1, 0.3)
                GameTooltip:AddLine("Click to open talent tree", 0.8, 0.8, 0.8)
            else
                GameTooltip:AddLine("No unspent talent points", 0.7, 0.7, 0.7)
            end
            
            -- Show current spec if available
            local specID = GetSpecialization and GetSpecialization()
            if specID then
                local specName = GetSpecializationInfo(specID)
                if specName then
                    GameTooltip:AddLine("Current: " .. specName, 0.8, 0.8, 1)
                end
            end
        end,
        onClick = function()
            -- Try to open talent frame
            if ToggleTalentFrame then
                ToggleTalentFrame()
            elseif PlayerTalentFrame then
                if PlayerTalentFrame:IsShown() then
                    PlayerTalentFrame:Hide()
                else
                    PlayerTalentFrame:Show()
                end
            end
        end
    },
    reputation = {
        name = "Reputation",
        color = {0.5, 1, 0.5}, -- Light green
        update = function(frame)
            -- Get currently watched faction using modern API
            local factionData = nil
            if C_Reputation and C_Reputation.GetWatchedFactionData then
                factionData = C_Reputation.GetWatchedFactionData()
            end
            
            if factionData and factionData.name then
                local name = factionData.name
                local standing = factionData.reaction or 4
                local min = factionData.currentReactionThreshold or 0
                local max = factionData.nextReactionThreshold or 1
                local value = factionData.currentStanding or 0
                
                local current = value - min
                local total = max - min
                local percent = total > 0 and (current / total) * 100 or 0
                
                frame.text:SetText(string.format("%s: %.0f%%", name:sub(1, 8), percent))
                
                -- Color based on standing
                if standing >= 7 then -- Exalted
                    frame.text:SetTextColor(0.8, 0.2, 1) -- Purple
                elseif standing >= 6 then -- Revered
                    frame.text:SetTextColor(0.2, 1, 0.2) -- Green
                elseif standing >= 5 then -- Honored
                    frame.text:SetTextColor(0.2, 0.8, 1) -- Blue
                elseif standing >= 4 then -- Friendly
                    frame.text:SetTextColor(1, 1, 1) -- White
                else -- Unfriendly or below
                    frame.text:SetTextColor(1, 0.3, 0.3) -- Red
                end
            else
                frame.text:SetText("No Rep")
                frame.text:SetTextColor(0.7, 0.7, 0.7)
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Reputation")
            local factionData = nil
            if C_Reputation and C_Reputation.GetWatchedFactionData then
                factionData = C_Reputation.GetWatchedFactionData()
            end
            
            if factionData and factionData.name then
                local name = factionData.name
                local standing = factionData.reaction or 4
                local min = factionData.currentReactionThreshold or 0
                local max = factionData.nextReactionThreshold or 1
                local value = factionData.currentStanding or 0
                
                local current = value - min
                local total = max - min
                local percent = total > 0 and (current / total) * 100 or 0
                
                -- Get standing text using modern method
                local reactionNames = {
                    [1] = "Hated",
                    [2] = "Hostile", 
                    [3] = "Unfriendly",
                    [4] = "Neutral",
                    [5] = "Friendly",
                    [6] = "Honored",
                    [7] = "Revered",
                    [8] = "Exalted"
                }
                local standingText = reactionNames[standing] or "Unknown"
                
                GameTooltip:AddLine(name, 1, 1, 1)
                GameTooltip:AddLine(string.format("%s: %.1f%%", standingText, percent), 0.8, 0.8, 1)
                GameTooltip:AddLine(string.format("Progress: %s / %s", BreakUpLargeNumbers(current), BreakUpLargeNumbers(total)), 0.8, 0.8, 0.8)
                
                if total > current then
                    GameTooltip:AddLine(string.format("Remaining: %s", BreakUpLargeNumbers(total - current)), 0.8, 0.8, 0.8)
                end
            else
                GameTooltip:AddLine("No faction being watched", 0.7, 0.7, 0.7)
                GameTooltip:AddLine("Select a faction to track in your reputation panel", 0.8, 0.8, 0.8)
            end
        end
    },
    currency = {
        name = "Currency",
        color = {1, 0.8, 0.3}, -- Golden
        update = function(frame)
            -- Try to get various currencies (this will need adjustment per expansion)
            local currencies = {}
            
            -- Honor (if PvP)
            if C_CurrencyInfo then
                local honorInfo = C_CurrencyInfo.GetCurrencyInfo(1901) -- Honor currency ID
                if honorInfo and honorInfo.quantity > 0 then
                    table.insert(currencies, string.format("Honor: %s", BreakUpLargeNumbers(honorInfo.quantity)))
                end
                
                -- Try other common currencies
                local commonCurrencies = {
                    2032, -- Trader's Tender
                    2245, -- Flightstones
                    2657, -- Residual Memories
                }
                
                for _, currencyID in ipairs(commonCurrencies) do
                    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
                    if info and info.quantity > 0 then
                        local shortName = info.name:sub(1, 8)
                        table.insert(currencies, string.format("%s: %s", shortName, BreakUpLargeNumbers(info.quantity)))
                        break -- Only show first found currency to save space
                    end
                end
            end
            
            if #currencies > 0 then
                frame.text:SetText(currencies[1]) -- Show first currency
            else
                frame.text:SetText("Currency: 0")
                frame.text:SetTextColor(0.7, 0.7, 0.7)
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Currencies")
            
            if C_CurrencyInfo then
                local found = false
                local commonCurrencies = {
                    1901, -- Honor
                    2032, -- Trader's Tender  
                    2245, -- Flightstones
                    2657, -- Residual Memories
                    2803, -- Whelpling Crest Fragment
                    2804, -- Drake Crest Fragment
                    2805, -- Wyrm Crest Fragment
                    2806, -- Aspect Crest Fragment
                }
                
                for _, currencyID in ipairs(commonCurrencies) do
                    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
                    if info and info.quantity > 0 then
                        local color = {1, 1, 1}
                        if info.maxQuantity and info.maxQuantity > 0 then
                            local percent = info.quantity / info.maxQuantity
                            if percent >= 0.9 then color = {1, 0.3, 0.3} -- Red when near cap
                            elseif percent >= 0.7 then color = {1, 1, 0.3} end -- Yellow when getting full
                        end
                        
                        GameTooltip:AddLine(string.format("%s: %s", info.name, BreakUpLargeNumbers(info.quantity)), color[1], color[2], color[3])
                        found = true
                    end
                end
                
                if not found then
                    GameTooltip:AddLine("No significant currencies", 0.7, 0.7, 0.7)
                end
            else
                GameTooltip:AddLine("Currency tracking not available", 0.7, 0.7, 0.7)
            end
        end
    },
    session = {
        name = "Session",
        color = {0.8, 1, 0.8}, -- Light green
        update = function(frame)
            local stats = GetSessionStats()
            local hours = math.floor(stats.duration / 3600)
            local minutes = math.floor((stats.duration % 3600) / 60)
            
            frame.text:SetText(string.format("Session: %dh %dm", hours, minutes))
            
            -- Color based on session length
            if stats.duration > 14400 then -- > 4 hours
                frame.text:SetTextColor(1, 0.3, 0.3) -- Red for very long sessions
            elseif stats.duration > 7200 then -- > 2 hours
                frame.text:SetTextColor(1, 1, 0.3) -- Yellow for long sessions
            else
                frame.text:SetTextColor(0.8, 1, 0.8) -- Light green for normal
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Session Statistics")
            GameTooltip:SetMinimumWidth(280)
            
            local stats = GetSessionStats()
            
            -- Time played
            local hours = math.floor(stats.duration / 3600)
            local minutes = math.floor((stats.duration % 3600) / 60)
            local seconds = math.floor(stats.duration % 60)
            GameTooltip:AddLine(string.format("Time Played: %dh %dm %ds", hours, minutes, seconds), 1, 1, 1)
            
            -- XP and Gold gains
            if stats.levelsGained > 0 then
                GameTooltip:AddLine(string.format("Levels Gained: %d", stats.levelsGained), 0.3, 1, 0.3)
            end
            
            if stats.xpGained > 0 then
                GameTooltip:AddLine(string.format("XP Gained: %s", BreakUpLargeNumbers(stats.xpGained)), 0.8, 0.8, 1)
                GameTooltip:AddLine(string.format("XP/Hour: %s", BreakUpLargeNumbers(math.floor(stats.xpPerHour))), 0.8, 0.8, 1)
            end
            
            if stats.goldGained ~= 0 then
                local goldColor = stats.goldGained > 0 and {0.3, 1, 0.3} or {1, 0.3, 0.3}
                local goldText = stats.goldGained > 0 and "Gold Gained" or "Gold Lost"
                GameTooltip:AddLine(string.format("%s: %s", goldText, BreakUpLargeNumbers(math.abs(stats.goldGained))), goldColor[1], goldColor[2], goldColor[3])
                GameTooltip:AddLine(string.format("Gold/Hour: %s", BreakUpLargeNumbers(math.floor(math.abs(stats.goldPerHour)))), goldColor[1], goldColor[2], goldColor[3])
            end
            
            -- Performance stats
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Performance:", 1, 1, 0)
            GameTooltip:AddLine(string.format("FPS: %.1f avg (%.0f-%.0f)", stats.avgFPS, stats.minFPS, stats.maxFPS), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(string.format("Latency: %.0f avg (%.0f-%.0f)", stats.avgLatency, stats.minLatency, stats.maxLatency), 0.8, 0.8, 0.8)
        end
    },
    performance = {
        name = "Performance",
        color = {1, 0.8, 1}, -- Light purple
        update = function(frame)
            local stats = GetSessionStats()
            local fps = GetFramerate()
            local _, _, lagHome, lagWorld = GetNetStats()
            local maxLatency = math.max(lagHome or 0, lagWorld or 0)
            
            -- Show both FPS and latency in compact format
            frame.text:SetText(string.format("%.0f FPS | %dms", fps, maxLatency))
            
            -- Color based on worst performing metric
            local fpsGood = fps >= 60
            local fpsOk = fps >= 30
            local latencyGood = maxLatency <= 100
            local latencyOk = maxLatency <= 200
            
            if fpsGood and latencyGood then
                frame.text:SetTextColor(0.3, 1, 0.3) -- Green - both good
            elseif (fpsOk or fpsGood) and (latencyOk or latencyGood) then
                frame.text:SetTextColor(1, 1, 0.3) -- Yellow - acceptable
            else
                frame.text:SetTextColor(1, 0.3, 0.3) -- Red - poor performance
            end
        end,
        tooltip = function()
            GameTooltip:SetText("Performance Monitor")
            GameTooltip:SetMinimumWidth(280)
            
            local stats = GetSessionStats()
            local fps = GetFramerate()
            local _, _, lagHome, lagWorld = GetNetStats()
            local maxLatency = math.max(lagHome or 0, lagWorld or 0)
            
            -- Current performance with color coding
            GameTooltip:AddLine("Current Performance:", 1, 1, 0)
            
            -- FPS with assessment
            local fpsColor = {1, 1, 1}
            local fpsAssessment = ""
            if fps >= 60 then
                fpsColor = {0.3, 1, 0.3}
                fpsAssessment = " (Excellent)"
            elseif fps >= 30 then
                fpsColor = {1, 1, 0.3}
                fpsAssessment = " (Good)"
            elseif fps >= 20 then
                fpsColor = {1, 0.8, 0.3}
                fpsAssessment = " (Fair)"
            else
                fpsColor = {1, 0.3, 0.3}
                fpsAssessment = " (Poor)"
            end
            GameTooltip:AddLine(string.format("FPS: %.1f%s", fps, fpsAssessment), fpsColor[1], fpsColor[2], fpsColor[3])
            
            -- Latency with assessment
            local latencyColor = {1, 1, 1}
            local latencyAssessment = ""
            if maxLatency <= 50 then
                latencyColor = {0.3, 1, 0.3}
                latencyAssessment = " (Excellent)"
            elseif maxLatency <= 100 then
                latencyColor = {0.8, 1, 0.3}
                latencyAssessment = " (Good)"
            elseif maxLatency <= 200 then
                latencyColor = {1, 1, 0.3}
                latencyAssessment = " (Fair)"
            else
                latencyColor = {1, 0.3, 0.3}
                latencyAssessment = " (Poor)"
            end
            GameTooltip:AddLine(string.format("Latency: %d ms%s", maxLatency, latencyAssessment), latencyColor[1], latencyColor[2], latencyColor[3])
            
            -- Detailed latency breakdown
            GameTooltip:AddLine(string.format("  Home: %d ms | World: %d ms", lagHome or 0, lagWorld or 0), 0.8, 0.8, 0.8)
            
            -- Session performance statistics
            if #sessionStats.fpsHistory > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Session Statistics:", 1, 1, 0)
                GameTooltip:AddLine(string.format("FPS: %.1f avg (%.0f-%.0f)", stats.avgFPS, stats.minFPS, stats.maxFPS), 0.8, 0.8, 1)
                GameTooltip:AddLine(string.format("Latency: %.0f avg (%.0f-%.0f)", stats.avgLatency, stats.minLatency, stats.maxLatency), 0.8, 0.8, 1)
                
                -- Overall session performance assessment
                GameTooltip:AddLine(" ")
                if stats.avgFPS >= 50 and stats.avgLatency <= 100 then
                    GameTooltip:AddLine("Excellent session performance", 0.3, 1, 0.3)
                elseif stats.avgFPS >= 30 and stats.avgLatency <= 150 then
                    GameTooltip:AddLine("Good session performance", 1, 1, 0.3)
                elseif stats.avgFPS >= 20 and stats.avgLatency <= 250 then
                    GameTooltip:AddLine("Fair session performance", 1, 0.8, 0.3)
                else
                    GameTooltip:AddLine("Poor session performance", 1, 0.3, 0.3)
                end
                
                -- Performance tips
                if stats.avgFPS < 30 then
                    GameTooltip:AddLine("Tip: Lower graphics settings for better FPS", 0.7, 0.7, 0.7)
                end
                if stats.avgLatency > 150 then
                    GameTooltip:AddLine("Tip: Check network connection", 0.7, 0.7, 0.7)
                end
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
    local opacity = Options:get("otherDataBarOpacity")
    if opacity == nil then opacity = 0.9 end
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
    local opacity = Options:get("secondDataBarOpacity")
    if opacity == nil then opacity = 0.9 end
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
    
    -- Set height only, width will be determined by anchor points
    minimapDataBar:SetHeight(25)
    
    -- Position directly below minimap using dual anchor points for perfect edge alignment
    minimapDataBar:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -5)
    minimapDataBar:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -5)
    
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
    local opacity = Options:get("minimapDataBarOpacity")
    if opacity == nil then opacity = 0.9 end
    minimapDataBar:SetBackdropColor(0, 0, 0, 0.8 * opacity)
    minimapDataBar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8 * opacity)
    
    minimapDataBar:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end)
    
    minimapDataBar:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    end)
    
    return minimapDataBar
end

-- Update minimap data bar size and position to match minimap scale
function DataTexts:UpdateMinimapDataBarScale()
    if not minimapDataBar then 
        return 
    end
    
    -- Clear all points and reanchor to ensure perfect alignment
    minimapDataBar:ClearAllPoints()
    minimapDataBar:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -5)
    minimapDataBar:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -5)
    
    -- Height remains constant
    minimapDataBar:SetHeight(25)
    
    -- Reposition data texts within the bar after a small delay to ensure the bar has resized
    C_Timer.After(0.1, function()
        self:PositionMinimapDataTexts()
    end)
end

-- Position data texts in minimap area
function DataTexts:PositionMinimapDataTexts()
    local count = 0
    local visibleFrames = {}
    
    -- Collect visible frames and limit to 3 maximum
    for _, frame in pairs(minimapDataTexts) do
        if frame:IsShown() then
            count = count + 1
            if count <= 3 then -- LIMIT: Only allow 3 data texts on minimap bar
                table.insert(visibleFrames, frame)
            else
                -- Hide excess data texts beyond the limit
                frame:Hide()
            end
        end
    end
    
    -- Update count to reflect actual visible frames
    count = #visibleFrames
    
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
        return
    end
    
    -- First update all visible data texts to get current content
    for _, frame in ipairs(visibleFrames) do
        if frame.config and frame.config.update then
            frame.config.update(frame)
        end
    end
    
    -- Get the actual bar width (this will be the minimap width due to anchoring)
    local actualBarWidth = minimapDataBar:GetWidth()
    local backdropInsets = 8 -- Account for backdrop border insets (4px left + 4px right)
    local padding = 8 -- Padding on sides
    local availableWidth = actualBarWidth - backdropInsets - padding
    
    -- Start with default font size and reduce if necessary
    local fontSize = 15 -- Default minimap font size
    local textsFit = false
    local attempts = 0
    local maxAttempts = 5
    
    while not textsFit and attempts < maxAttempts do
        attempts = attempts + 1
        
        -- Update font sizes for all visible texts
        for _, frame in ipairs(visibleFrames) do
            if frame.text then
                frame.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
            end
        end
        
        -- Calculate text widths with current font size
        local totalTextWidth = 0
        local textWidths = {}
        
        for i, frame in ipairs(visibleFrames) do
            if frame.text then
                local baseWidth = frame.text:GetStringWidth() + 6 -- Slightly more padding for 3 texts
                local iconWidth = frame.icon and 18 or 0 -- Icon space
                local textWidth = baseWidth + iconWidth
                textWidths[i] = textWidth
                totalTextWidth = totalTextWidth + textWidth
            end
        end
        
        -- Calculate spacing (more generous for 3 texts)
        local spacing = count > 1 and 4 or 0 -- Increased spacing for better layout
        local totalSpacing = (count - 1) * spacing
        local contentWidth = totalTextWidth + totalSpacing
        
        -- Check if content fits
        if contentWidth <= availableWidth or fontSize <= 8 then
            textsFit = true
            
            -- Position texts with proper spacing
            local startX = -(contentWidth) / 2
            local currentX = startX
            
            for i, frame in ipairs(visibleFrames) do
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", minimapDataBar, "CENTER", currentX + (textWidths[i] / 2), 0)
                currentX = currentX + textWidths[i] + spacing
            end
        else
            -- Reduce font size and try again
            fontSize = fontSize - 1
        end
    end
    
    -- Show warning if some data texts were hidden due to limit
    local totalAssigned = 0
    for _, frame in pairs(minimapDataTexts) do
        if frame:IsShown() or frame:IsVisible() then
            totalAssigned = totalAssigned + 1
        end
    end
    
    -- Excess data texts are automatically handled by hiding them
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
    
    -- Count assignments for each bar
    local minimapCount = 0
    local otherCount = 0
    local secondCount = 0
    
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
                minimapCount = minimapCount + 1
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
                otherCount = otherCount + 1
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
                secondCount = secondCount + 1
            end
        end
    end
    
    -- print(string.format("MiniMapimous: Assigned %d texts to minimap, %d to first bar, %d to second bar", minimapCount, otherCount, secondCount))
    
    -- Warn if too many data texts assigned to minimap
    -- if minimapCount > 3 then
    --     print(string.format("MiniMapimous: WARNING - Only 3 data texts can fit on minimap bar (assigned %d)", minimapCount))
    --     print("MiniMapimous: Consider moving some to First or Second data bar for better layout")
    -- end
    
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

-- Consolidated update function for master timer
function DataTexts:UpdateAllDataTexts()
    -- Update session statistics
    UpdateSessionStats()
    
    for key, frame in pairs(dataTextFrames) do
        if frame:IsShown() and frame.config and frame.config.update then
            frame.config.update(frame)
        end
    end
    
    -- Reduce repositioning frequency even more for better performance
    if math.random(1, 15) == 1 then -- Changed from 10 to 15 (every 15 seconds on average)
        self:PositionMinimapDataTexts()
        PositionOtherDataTexts()
        PositionSecondDataTexts()
    end
end

-- Update all visible data texts (DEPRECATED - use UpdateAllDataTexts instead)
local function UpdateDataTexts()
    -- This function is kept for compatibility but is no longer used
    -- The master timer now calls DataTexts:UpdateAllDataTexts() directly
end

-- Initialize data texts
function DataTexts:Initialize()
    -- Ensure lockDataBars has a default value
    if Options:get("lockDataBars") == nil then
        Options:set("lockDataBars", false)
    end
    
    -- Ensure first data bar is enabled by default so data texts appear
    if Options:get("showOtherDataBar") == nil then
        Options:set("showOtherDataBar", true)
    end
    
    -- Enable minimap data bar by default too
    if Options:get("showMinimapDataBar") == nil then
        Options:set("showMinimapDataBar", true)
    end
    
    -- Enable CPU profiling for performance tracking
    if GetCVar("scriptProfile") ~= "1" then
        SetCVar("scriptProfile", "1")
    end
    
    -- Reset CPU usage tracking periodically for more accurate readings
    C_Timer.NewTicker(10, function()
        ResetCPUUsage()
    end)
    
    -- Initialize session statistics tracking
    InitializeSessionStats()
    
    -- Timer now handled by master timer in MiniMapimous.lua
    
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
        local opacity = Options:get("minimapDataBarOpacity")
        if opacity == nil then opacity = 0.9 end
        -- Only change backdrop opacity, not frame alpha to preserve text visibility
        minimapDataBar:SetBackdropColor(0, 0, 0, 0.8 * opacity)
        minimapDataBar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8 * opacity)
    end
    
    if otherDataBar then
        local opacity = Options:get("otherDataBarOpacity")
        if opacity == nil then opacity = 0.9 end
        -- Only change backdrop opacity, not frame alpha to preserve text visibility
        otherDataBar:SetBackdropColor(0, 0, 0, 0.9 * opacity)
        otherDataBar:SetBackdropBorderColor(0.5, 0.5, 1, 1 * opacity)
    end
    
    if secondDataBar then
        local opacity = Options:get("secondDataBarOpacity")
        if opacity == nil then opacity = 0.9 end
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