YacaServerGhosting = {
    ghostedPlayers = {},
}

local function initServerGhostingModule()
    YacaServerGhosting:registerEvents()
    YacaServerGhosting:registerExports()
end

function YacaServerGhosting:registerEvents()
    RegisterNetEvent("server:yaca:ghosting", function(startGhosting, stopGhosting)
        local src = tonumber(source) or source
        local player = YacaServer:getPlayer(src)
        if not player then return end

        if type(stopGhosting) == "table" and #stopGhosting > 0 then
            self:stopGhostingFor(src, stopGhosting)
        end

        if type(startGhosting) ~= "table" or #startGhosting == 0 or not player.voiceSettings.ghosting then
            return
        end

        local targets = self.ghostedPlayers[src] or {}
        local newTargets = {}

        for _, targetId in ipairs(startGhosting) do
            local target = YacaServer:getPlayer(targetId)
            if targetId ~= src and not targets[targetId] and target and target.voicePlugin then
                targets[targetId] = true
                newTargets[#newTargets + 1] = targetId
            end
        end

        if #newTargets == 0 then return end

        self.ghostedPlayers[src] = targets
        YacaTriggerClientEvent("client:yaca:ghosting", newTargets, src, true)
    end)
end

function YacaServerGhosting:registerExports()
    exports("setPlayerGhosting", function(playerId, state, range)
        self:setPlayerGhosting(playerId, state, range)
    end)

    exports("isPlayerGhosting", function(playerId)
        local player = YacaServer:getPlayer(playerId)
        return player and player.voiceSettings.ghosting or false
    end)

    exports("setPlayerGhostingRange", function(playerId, range)
        local player = YacaServer:getPlayer(playerId)
        if not player then
            print(YacaLocale("player_not_found", playerId))
            return
        end
        self:setPlayerGhosting(playerId, player.voiceSettings.ghosting, range)
    end)

    exports("getPlayerGhostingRange", function(playerId)
        local player = YacaServer:getPlayer(playerId)
        return player and player.voiceSettings.ghostingRange or false
    end)

    exports("getGhostedPlayers", function(playerId)
        local list = {}
        for targetId in pairs(self.ghostedPlayers[tonumber(playerId) or playerId] or {}) do
            list[#list + 1] = targetId
        end
        return list
    end)
end

function YacaServerGhosting:setPlayerGhosting(src, state, range)
    src = tonumber(src) or src
    local player = YacaServer:getPlayer(src)
    if not player then
        print(YacaLocale("player_not_found", src))
        return
    end

    state = state == true
    local ghostingRange = state and self:clampRange(range) or nil

    if player.voiceSettings.ghosting == state and player.voiceSettings.ghostingRange == ghostingRange then
        return
    end

    player.voiceSettings.ghosting = state
    player.voiceSettings.ghostingRange = ghostingRange

    if not state then
        self:stopGhostingFor(src)
    end

    TriggerClientEvent("client:yaca:setGhosting", src, state, ghostingRange)
    TriggerEvent("yaca:external:ghostingState", src, state, ghostingRange)
end

function YacaServerGhosting:clampRange(range)
    if type(range) ~= "number" or range <= 0 then
        return nil
    end

    local ranges = YacaServer.sharedConfig.voiceRange.ranges
    return math.min(range, math.max(table.unpack(ranges)))
end

function YacaServerGhosting:stopGhostingFor(src, targetIds)
    local targets = self.ghostedPlayers[src]
    if not targets or next(targets) == nil then return end

    if not targetIds then
        targetIds = {}
        for targetId in pairs(targets) do targetIds[#targetIds + 1] = targetId end
    end

    local droppedTargets = {}
    for _, targetId in ipairs(targetIds) do
        if targets[targetId] then
            targets[targetId] = nil
            droppedTargets[#droppedTargets + 1] = targetId
        end
    end

    if next(targets) == nil then
        self.ghostedPlayers[src] = nil
    end

    YacaTriggerClientEvent("client:yaca:ghosting", droppedTargets, src, false)
end

function YacaServerGhosting:handlePlayerDisconnect(playerId)
    self:stopGhostingFor(playerId)

    for _, targets in pairs(self.ghostedPlayers) do
        targets[playerId] = nil
    end
end

Citizen.CreateThread(function()
    while not YacaServer.sharedConfig do
        Citizen.Wait(100)
    end
    initServerGhostingModule()
end)
