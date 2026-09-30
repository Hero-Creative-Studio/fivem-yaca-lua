YacaMicrophone = {}

local function initMicrophoneModule()
    YacaMicrophone:registerEvents()
end

function YacaMicrophone:registerEvents()
    RegisterNetEvent("client:yaca:microphone", function(target, state, settings)
        local speakerSettings = self:buildSpeakerSettings(settings)
        local range = settings and settings.range or nil

        if target == YacaCache.serverId then
            YacaClient:setPlayersCommType(
                {}, YacaFilterEnum.MICROPHONE, state,
                nil, range, CommDeviceMode.SENDER, CommDeviceMode.RECEIVER,
                nil, speakerSettings
            )

            TriggerEvent("yaca:external:microphoneState", state)
            return
        end

        local player = YacaClient:getPlayerByID(target)
        if not player then return end

        YacaClient:setPlayersCommType(
            player, YacaFilterEnum.MICROPHONE, state,
            nil, range, CommDeviceMode.RECEIVER, CommDeviceMode.SENDER,
            nil, speakerSettings
        )
    end)
end

function YacaMicrophone:buildSpeakerSettings(settings)
    local positions = settings and settings.positions
    if type(positions) ~= "table" or #positions == 0 then
        return nil
    end

    if settings.interiorKey and settings.interiorKey ~= 0 and settings.roomKey and settings.roomKey ~= 0 then
        return { positions = positions, interiorKey = settings.interiorKey, roomKey = settings.roomKey }
    end

    local roomPair = self:resolveSpeakerRoomPair(positions[1])
    return { positions = positions, interiorKey = roomPair.interiorKey, roomKey = roomPair.roomKey }
end

function YacaMicrophone:resolveSpeakerRoomPair(position)
    if not YacaClient.isFiveM then
        return YacaOutsideRoomPair
    end

    local speakerRoomPair = YacaGetInteriorRoomPairAtCoords(YacaConvertToXYZ(position))
    if speakerRoomPair.interiorKey ~= 0 and speakerRoomPair.roomKey ~= 0 then
        return speakerRoomPair
    end

    return YacaClient:getRoomPair(YacaCache.ped)
end

Citizen.CreateThread(function()
    while not YacaClient.sharedConfig do
        Citizen.Wait(100)
    end
    initMicrophoneModule()
end)
