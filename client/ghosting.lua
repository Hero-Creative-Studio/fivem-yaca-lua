YacaGhosting = {
    isGhosting = false,
    ghostingRange = nil,
    ghostedPlayers = {},
    ghostsAround = {},
}

local GHOST_DIRECTION = { x = 0, y = 0, z = 0 }

local function initGhostingModule()
    YacaGhosting:registerEvents()
    YacaGhosting:registerExports()
end

function YacaGhosting:registerEvents()
    RegisterNetEvent("client:yaca:setGhosting", function(state, range)
        self.isGhosting = state
        self.ghostingRange = range
        TriggerEvent("yaca:external:ghostingState", state, self:getReach())
    end)

    RegisterNetEvent("client:yaca:ghosting", function(ghostId, state)
        self.ghostsAround[ghostId] = state or nil
    end)
end

function YacaGhosting:registerExports()
    exports("isGhosting", function() return self.isGhosting end)
    exports("getGhostingRange", function() return self:getReach() end)
    exports("getGhostedPlayers", function()
        local list = {}
        for playerId in pairs(self.ghostedPlayers) do list[#list + 1] = playerId end
        return list
    end)
end

function YacaGhosting:getReach()
    return self.ghostingRange or YacaClient:getVoiceRange()
end

function YacaGhosting:isPlayerGhosted(distance, forceMuted, reach)
    return self.isGhosting and not forceMuted and distance <= reach
end

function YacaGhosting:handleGhostingEmit(playersToGhost)
    if next(playersToGhost) == nil and next(self.ghostedPlayers) == nil then return end

    local startGhosting, stopGhosting = {}, {}
    for playerId in pairs(self.ghostedPlayers) do
        if not playersToGhost[playerId] then stopGhosting[#stopGhosting + 1] = playerId end
    end
    for playerId in pairs(playersToGhost) do
        if not self.ghostedPlayers[playerId] then startGhosting[#startGhosting + 1] = playerId end
    end

    self.ghostedPlayers = playersToGhost

    if #startGhosting > 0 or #stopGhosting > 0 then
        TriggerServerEvent("server:yaca:ghosting", startGhosting, stopGhosting)
    end
end

function YacaGhosting:addGhostsToPlayerList(playersList, playerIndexById, localPos, localRoomPair)
    for ghostId in pairs(self.ghostsAround) do
        local ghost = YacaClient:getPlayerByID(ghostId)
        if ghost and ghost.clientId then
            local entry = {
                client_id = ghost.clientId,
                position = localPos,
                direction = GHOST_DIRECTION,
                range = YacaClient:getVoiceRange(ghostId),
                is_underwater = false,
                muffle_intensity = 0,
                is_muted = ghost.forceMuted or false,
            }
            if type(ghost.volumeModifier) == "number" then
                entry.volume_modifier = ghost.volumeModifier
            end
            if localRoomPair.interiorKey ~= 0 and localRoomPair.roomKey ~= 0 then
                entry.interior_key = localRoomPair.interiorKey
                entry.room_key = localRoomPair.roomKey
            end

            playersList[playerIndexById[ghostId] or (#playersList + 1)] = entry
        end
    end
end

function YacaGhosting:handleDisconnect(remoteId)
    self.ghostedPlayers[remoteId] = nil
    self.ghostsAround[remoteId] = nil
end

Citizen.CreateThread(function()
    while not YacaClient.sharedConfig do
        Citizen.Wait(100)
    end
    initGhostingModule()
end)
