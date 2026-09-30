YacaTowerVisualization = {
    enabled = false,
    blips = {},
    zones = {},
    markerToken = 0,
}

local function initTowerVisualizationModule()
    YacaTowerVisualization:registerExports()

    AddEventHandler("onResourceStop", function(resourceName)
        if YacaCache.resource == resourceName then
            YacaTowerVisualization:setEnabled(false)
        end
    end)

    local config = YacaClient.sharedConfig.towerVisualization
    if config and config.enabled then
        YacaTowerVisualization:setEnabled(true)
    end
end

function YacaTowerVisualization:registerExports()
    exports("setTowerVisualization", function(state) return self:setEnabled(state == true) end)
    exports("toggleTowerVisualization", function() return self:setEnabled(not self.enabled) end)
    exports("isTowerVisualizationEnabled", function() return self.enabled end)
end

function YacaTowerVisualization:setEnabled(state)
    if self.enabled == state or not YacaClient.sharedConfig.towerVisualization then
        return self.enabled
    end

    self.enabled = state
    self.markerToken = self.markerToken + 1
    self:removeBlips()

    if state then
        self:calculateZones()
        self:createBlips()
        self:startMarkerThread(self.markerToken)
    end

    return self.enabled
end

function YacaTowerVisualization:refresh()
    if not self.enabled then return end

    self:removeBlips()
    self:calculateZones()
    self:createBlips()
end

function YacaTowerVisualization:calculateZones()
    self.zones = {}
    for i, zone in ipairs(YacaClient.sharedConfig.towerVisualization.zones or {}) do
        self.zones[i] = {
            radius = YacaRadio:calculateDistanceForSignalStrength(zone.signalStrength),
            blipColor = zone.blipColor,
            blipAlpha = zone.blipAlpha,
            r = zone.r,
            g = zone.g,
            b = zone.b,
        }
    end
    table.sort(self.zones, function(a, b) return a.radius < b.radius end)
end

function YacaTowerVisualization:createBlips()
    local blipConfig = YacaClient.sharedConfig.towerVisualization.blip
    if not blipConfig.enabled and not blipConfig.showZones then return end

    if not YacaClient.isFiveM then
        print("[YaCA] The tower visualization blips are only available in FiveM.")
        return
    end

    local towers = YacaClient.towerConfig.towerPositions

    if blipConfig.showZones then
        for i = #self.zones, 1, -1 do
            local zone = self.zones[i]
            for _, tower in ipairs(towers) do
                local zoneBlip = AddBlipForRadius(tower[1] + 0.0, tower[2] + 0.0, tower[3] + 0.0, zone.radius + 0.0)
                SetBlipColour(zoneBlip, zone.blipColor)
                SetBlipAlpha(zoneBlip, zone.blipAlpha)
                self.blips[#self.blips + 1] = zoneBlip
            end
        end
    end

    if blipConfig.enabled then
        for _, tower in ipairs(towers) do
            local towerBlip = AddBlipForCoord(tower[1] + 0.0, tower[2] + 0.0, tower[3] + 0.0)
            SetBlipSprite(towerBlip, blipConfig.sprite)
            SetBlipColour(towerBlip, blipConfig.color)
            SetBlipScale(towerBlip, blipConfig.scale + 0.0)
            SetBlipAsShortRange(towerBlip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(YacaLocale("radio_tower"))
            EndTextCommandSetBlipName(towerBlip)
            self.blips[#self.blips + 1] = towerBlip
        end
    end
end

function YacaTowerVisualization:removeBlips()
    for _, blip in ipairs(self.blips) do
        RemoveBlip(blip)
    end
    self.blips = {}
end

function YacaTowerVisualization:startMarkerThread(token)
    local markerConfig = YacaClient.sharedConfig.towerVisualization.marker
    if not markerConfig.enabled then return end

    local markerType = markerConfig.type
    if not YacaClient.isFiveM and markerType < 1000 then
        markerType = 0x94fdae17
    end

    Citizen.CreateThread(function()
        while self.markerToken == token do
            local playerPos = GetEntityCoords(YacaCache.ped, false)
            local maxDistance = YacaClient.sharedConfig.radioSettings.maxDistance
            local drewMarker = false

            for _, tower in ipairs(YacaClient.towerConfig.towerPositions) do
                local distance = #(playerPos - vector3(tower[1], tower[2], tower[3]))
                if distance <= markerConfig.drawDistance and distance <= maxDistance then
                    local zone = self.zones[#self.zones]
                    for _, candidate in ipairs(self.zones) do
                        if distance <= candidate.radius then
                            zone = candidate
                            break
                        end
                    end

                    if zone then
                        drewMarker = true
                        DrawMarker(
                            markerType,
                            tower[1] + 0.0, tower[2] + 0.0, tower[3] + 0.0,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            markerConfig.scale + 0.0, markerConfig.scale + 0.0, markerConfig.height + 0.0,
                            zone.r, zone.g, zone.b, markerConfig.alpha,
                            false, false, 2, false, nil, nil, false
                        )
                    end
                end
            end

            Citizen.Wait(drewMarker and 0 or 1000)
        end
    end)
end

Citizen.CreateThread(function()
    while not YacaClient.sharedConfig or not YacaRadio do
        Citizen.Wait(100)
    end
    initTowerVisualizationModule()
end)
