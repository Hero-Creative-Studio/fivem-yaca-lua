YacaServerPhone = {}

local function initServerPhoneModule()
    YacaServerPhone:registerEvents()
    YacaServerPhone:registerExports()
end

function YacaServerPhone:registerEvents()
    RegisterNetEvent("server:yaca:phoneSpeakerEmitWhisper", function(enableForTargets, disableForTargets)
        local player = YacaServer:getPlayer(source)
        if not player then return end

        for callTarget in pairs(player.voiceSettings.inCallWith) do
            if YacaServer:getPlayer(callTarget) then
                local enableFor, disableFor = {}, {}
                for _, targetID in ipairs(enableForTargets or {}) do
                    if targetID ~= callTarget then enableFor[#enableFor + 1] = targetID end
                end
                for _, targetID in ipairs(disableForTargets or {}) do
                    if targetID ~= callTarget then disableFor[#disableFor + 1] = targetID end
                end

                if #enableFor > 0 then
                    TriggerClientEvent("client:yaca:playersToPhoneSpeakerEmitWhisper", callTarget, enableFor, true)
                end
                if #disableFor > 0 then
                    TriggerClientEvent("client:yaca:playersToPhoneSpeakerEmitWhisper", callTarget, disableFor, false)
                end
            end
        end
    end)

    RegisterNetEvent("server:yaca:phoneEmit", function(enableForTargets, disableForTargets)
        if not YacaServer.sharedConfig.phoneHearPlayersNearby then return end

        local src = tonumber(source) or source
        local player = YacaServer:getPlayer(src)
        if not player then return end

        if enableForTargets and #enableForTargets > 0 then
            for callTarget in pairs(player.voiceSettings.inCallWith) do
                local callTargetPlayer = YacaServer:getPlayer(callTarget)
                if callTargetPlayer then
                    local relayTargets = {}
                    local relayClientIds = {}

                    for _, targetID in ipairs(enableForTargets) do
                        local target = YacaServer:getPlayer(targetID)
                        if targetID ~= callTarget and not callTargetPlayer.voiceSettings.inCallWith[targetID] and target and target.voicePlugin then
                            relayTargets[#relayTargets + 1] = targetID
                            relayClientIds[#relayClientIds + 1] = target.voicePlugin.clientId
                        end
                    end

                    if #relayClientIds > 0 then
                        local emitted = player.voiceSettings.emittedPhoneSpeaker
                        for _, targetID in ipairs(relayTargets) do
                            emitted[targetID] = emitted[targetID] or {}
                            emitted[targetID][callTarget] = true
                        end

                        TriggerClientEvent("client:yaca:phoneHearAround", callTarget, relayClientIds, true)

                        if YacaServer.serverConfig.useWhisper and callTargetPlayer.voicePlugin then
                            YacaTriggerClientEvent("client:yaca:phoneHearAroundWhisper", relayTargets, { callTargetPlayer.voicePlugin.clientId }, true)
                        end
                    end
                end
            end
        end

        if disableForTargets and #disableForTargets > 0 then
            self:dropPhoneHearAround(src, disableForTargets)
        end
    end)
end

function YacaServerPhone:isPhoneHearAroundHeld(bystanderId, callTarget)
    for _, player in pairs(YacaServer.players) do
        local members = player.voiceSettings.emittedPhoneSpeaker[bystanderId]
        if members and members[callTarget] then return true end
    end
    return false
end

function YacaServerPhone:dropPhoneHearAround(emitterId, bystanderIds, callTargets)
    local emitter = YacaServer:getPlayer(emitterId)
    if not emitter then return end

    local emitted = emitter.voiceSettings.emittedPhoneSpeaker
    local droppedForMember = {}

    if not bystanderIds then
        bystanderIds = {}
        for bystanderId in pairs(emitted) do bystanderIds[#bystanderIds + 1] = bystanderId end
    end

    for _, bystanderId in ipairs(bystanderIds) do
        local members = emitted[bystanderId]
        if members then
            local memberIds = callTargets
            if not memberIds then
                memberIds = {}
                for member in pairs(members) do memberIds[#memberIds + 1] = member end
            end

            for _, member in ipairs(memberIds) do
                if members[member] then
                    members[member] = nil
                    droppedForMember[member] = droppedForMember[member] or {}
                    table.insert(droppedForMember[member], bystanderId)
                end
            end

            if next(members) == nil then emitted[bystanderId] = nil end
        end
    end

    for member, bystanders in pairs(droppedForMember) do
        local memberPlayer = YacaServer:getPlayer(member)
        if memberPlayer and memberPlayer.voicePlugin then
            local disableForTargets = {}
            local disableClientIds = {}

            for _, bystanderId in ipairs(bystanders) do
                local bystander = YacaServer:getPlayer(bystanderId)
                if not self:isPhoneHearAroundHeld(bystanderId, member) and bystander and bystander.voicePlugin then
                    disableForTargets[#disableForTargets + 1] = bystanderId
                    disableClientIds[#disableClientIds + 1] = bystander.voicePlugin.clientId
                end
            end

            if #disableClientIds > 0 then
                TriggerClientEvent("client:yaca:phoneHearAround", member, disableClientIds, false)

                if YacaServer.serverConfig.useWhisper then
                    YacaTriggerClientEvent("client:yaca:phoneHearAroundWhisper", disableForTargets, { memberPlayer.voicePlugin.clientId }, false)
                end
            end
        end
    end
end

function YacaServerPhone:reestablishPhoneHearAround(src)
    if not YacaServer.sharedConfig.phoneHearPlayersNearby then return end

    local player = YacaServer:getPlayer(src)
    if not player or not player.voicePlugin then return end

    local bystanderClientIds = {}
    local memberClientIds = {}

    for _, emitter in pairs(YacaServer.players) do
        for bystanderId, members in pairs(emitter.voiceSettings.emittedPhoneSpeaker) do
            if members[src] then
                local bystander = YacaServer:getPlayer(bystanderId)
                if bystander and bystander.voicePlugin then
                    bystanderClientIds[bystander.voicePlugin.clientId] = true
                end
            elseif bystanderId == src and YacaServer.serverConfig.useWhisper then
                for member in pairs(members) do
                    local memberPlayer = YacaServer:getPlayer(member)
                    if memberPlayer and memberPlayer.voicePlugin then
                        memberClientIds[memberPlayer.voicePlugin.clientId] = true
                    end
                end
            end
        end
    end

    local function keys(set)
        local list = {}
        for key in pairs(set) do list[#list + 1] = key end
        return list
    end

    if next(bystanderClientIds) then
        TriggerClientEvent("client:yaca:phoneHearAround", src, keys(bystanderClientIds), true)
    end

    if next(memberClientIds) then
        TriggerClientEvent("client:yaca:phoneHearAroundWhisper", src, keys(memberClientIds), true)
    end
end

function YacaServerPhone:dropAllPhoneHearAround(playerId)
    for emitterId in pairs(YacaServer.players) do
        if emitterId == playerId then
            self:dropPhoneHearAround(emitterId)
        else
            self:dropPhoneHearAround(emitterId, { playerId })
            self:dropPhoneHearAround(emitterId, nil, { playerId })
        end
    end
end

function YacaServerPhone:registerExports()
    exports("callPlayer", function(src, target, state)
        self:callPlayer(src, target, state)
    end)

    exports("callPlayerOldEffect", function(src, target, state)
        self:callPlayer(src, target, state, YacaFilterEnum.PHONE_HISTORICAL)
    end)

    exports("muteOnPhone", function(src, state)
        self:muteOnPhone(src, state)
    end)

    exports("enablePhoneSpeaker", function(src, state)
        self:enablePhoneSpeaker(src, state)
    end)

    exports("isPlayerInCall", function(src)
        local player = YacaServer:getPlayer(src)
        if not player then return false, {} end

        local inCall = next(player.voiceSettings.inCallWith) ~= nil
        local callList = {}
        for id in pairs(player.voiceSettings.inCallWith) do
            callList[#callList + 1] = id
        end

        return inCall, callList
    end)
end

function YacaServerPhone:callPlayer(src, target, state, filter)
    filter = filter or YacaFilterEnum.PHONE

    local player = YacaServer:getPlayer(src)
    local targetPlayer = YacaServer:getPlayer(target)
    if not player or not targetPlayer then return end

    TriggerClientEvent("client:yaca:phone", target, src, state, filter)
    TriggerClientEvent("client:yaca:phone", src, target, state, filter)

    local playerState = Player(src).state
    local targetState = Player(target).state

    if state then
        player.voiceSettings.inCallWith[target] = true
        targetPlayer.voiceSettings.inCallWith[src] = true

        if playerState[YACA_STATE_PHONE_SPEAKER] then
            self:enablePhoneSpeaker(src, true)
        end

        if targetState[YACA_STATE_PHONE_SPEAKER] then
            self:enablePhoneSpeaker(target, true)
        end
    else
        self:muteOnPhone(src, false, true)
        self:muteOnPhone(target, false, true)

        player.voiceSettings.inCallWith[target] = nil
        targetPlayer.voiceSettings.inCallWith[src] = nil

        self:dropPhoneHearAround(src, nil, { target })
        self:dropPhoneHearAround(target, nil, { src })

        if playerState[YACA_STATE_PHONE_SPEAKER] then
            self:enablePhoneSpeaker(src, false)
        end

        if targetState[YACA_STATE_PHONE_SPEAKER] then
            self:enablePhoneSpeaker(target, false)
        end
    end

    TriggerEvent("yaca:external:phoneCall", src, target, state, filter)
end

function YacaServerPhone:muteOnPhone(src, state, onCallStop)
    onCallStop = onCallStop or false

    local player = YacaServer:getPlayer(src)
    if not player then return end

    player.voiceSettings.mutedOnPhone = state
    TriggerClientEvent("client:yaca:phoneMute", -1, src, state, onCallStop)
    TriggerEvent("yaca:external:phoneMute", src, state)
end

function YacaServerPhone:enablePhoneSpeaker(src, state)
    local player = YacaServer:getPlayer(src)
    if not player then return end

    local playerState = Player(src).state

    if state and next(player.voiceSettings.inCallWith) ~= nil then
        local callList = {}
        for id in pairs(player.voiceSettings.inCallWith) do
            callList[#callList + 1] = id
        end
        playerState:set(YACA_STATE_PHONE_SPEAKER, callList, true)
        TriggerEvent("yaca:external:phoneSpeaker", src, true)
    else
        playerState:set(YACA_STATE_PHONE_SPEAKER, nil, true)
        TriggerEvent("yaca:external:phoneSpeaker", src, false)
    end
end

Citizen.CreateThread(function()
    while not YacaServer.sharedConfig do
        Citizen.Wait(100)
    end
    initServerPhoneModule()
end)
