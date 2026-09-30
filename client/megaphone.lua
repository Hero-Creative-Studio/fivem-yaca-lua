YacaMegaphone = {
    canUseMegaphone = false,
    forceCanUseMegaphone = false,
    lastMegaphoneState = false,
    megaphoneVehicleWhitelistHashes = {},
}

local function initMegaphoneModule()
    YacaMegaphone:registerEvents()
    YacaMegaphone:registerExports()
    YacaMegaphone:registerStateBagHandlers()

    if YacaClient.isFiveM then
        YacaMegaphone:registerKeybinds()

        if YacaClient.sharedConfig.megaphone.allowedVehicleModels then
            for _, vehicleModel in ipairs(YacaClient.sharedConfig.megaphone.allowedVehicleModels) do
                YacaMegaphone.megaphoneVehicleWhitelistHashes[YacaJoaat(vehicleModel)] = true
            end
        end
    elseif YacaClient.isRedM then
        YacaMegaphone:registerRdrKeybinds()
        YacaMegaphone.canUseMegaphone = true
    end
end

function YacaMegaphone:registerEvents()
    RegisterNetEvent("client:yaca:setLastMegaphoneState", function(state)
        self.lastMegaphoneState = state
    end)

    if YacaClient.isFiveM and YacaClient.sharedConfig.megaphone.automaticVehicleDetection then
        local lastVehicle = false
        local lastSeat = false

        Citizen.CreateThread(function()
            while true do
                local currentVehicle = YacaCache.vehicle
                local currentSeat = YacaCache.seat

                if currentVehicle ~= lastVehicle or currentSeat ~= lastSeat then
                    lastVehicle = currentVehicle
                    lastSeat = currentSeat

                    if currentSeat == false or currentSeat > 0 or not currentVehicle then
                        self.canUseMegaphone = false
                        if not self.forceCanUseMegaphone then
                            TriggerServerEvent("server:yaca:playerLeftVehicle")
                        end
                    else
                        local vehicleClass = GetVehicleClass(currentVehicle)
                        local vehicleModel = YacaToUInt32(GetEntityModel(currentVehicle))

                        local allowedClasses = YacaClient.sharedConfig.megaphone.allowedVehicleClasses or {}
                        local classAllowed = false
                        for _, cls in ipairs(allowedClasses) do
                            if cls == vehicleClass then
                                classAllowed = true
                                break
                            end
                        end

                        self.canUseMegaphone = classAllowed or self.megaphoneVehicleWhitelistHashes[vehicleModel] == true
                    end
                end

                Citizen.Wait(500)
            end
        end)
    end
end

function YacaMegaphone:registerKeybinds()
    if YacaClient.sharedConfig.keyBinds.megaphone == false then return end

    RegisterCommand("+yaca:megaphone", function()
        self:useMegaphone(true)
    end, false)
    RegisterCommand("-yaca:megaphone", function()
        self:useMegaphone(false)
    end, false)
    RegisterKeyMapping("+yaca:megaphone", YacaLocale("use_megaphone"), "keyboard", YacaClient.sharedConfig.keyBinds.megaphone)
end

function YacaMegaphone:registerRdrKeybinds()
    if YacaClient.sharedConfig.keyBinds.megaphone == false then return end

    YacaRegisterRdrKeyBind(YacaClient.sharedConfig.keyBinds.megaphone, function()
        self:useMegaphone(not self.lastMegaphoneState)
    end)
end

function YacaMegaphone:registerExports()
    exports("getCanUseMegaphone", function()
        return self:isMegaphoneUsable()
    end)

    exports("getCurrentMegaphoneState", function()
        return self.lastMegaphoneState
    end)

    exports("setCanUseMegaphone", function(state, force)
        self.canUseMegaphone = state
        self.forceCanUseMegaphone = state and force == true
        if not state and self.lastMegaphoneState then
            TriggerServerEvent("server:yaca:playerLeftVehicle")
        end
    end)

    exports("useMegaphone", function(state)
        self:useMegaphone(state or false)
    end)
end

function YacaMegaphone:registerStateBagHandlers()
    AddStateBagChangeHandler(YACA_STATE_MEGAPHONE, "", function(bagName, _, value, _, replicated)
        if replicated then return end

        local playerId = GetPlayerFromStateBagName(bagName)
        if playerId == 0 then return end

        local playerSource = GetPlayerServerId(playerId)
        if playerSource == 0 then return end

        self:applyMegaphoneEffect(playerSource, value)
    end)
end

function YacaMegaphone:applyMegaphoneEffect(playerSource, value)
    if playerSource == YacaCache.serverId then
        YacaClient:setPlayersCommType(
            {}, YacaFilterEnum.MEGAPHONE,
            type(value) == "number", nil, value,
            CommDeviceMode.SENDER, CommDeviceMode.RECEIVER
        )
        return
    end

    local player = YacaClient:getPlayerByID(playerSource)
    if not player then return end

    YacaClient:setPlayersCommType(
        player, YacaFilterEnum.MEGAPHONE,
        type(value) == "number", nil, value,
        CommDeviceMode.RECEIVER, CommDeviceMode.SENDER
    )
end

function YacaMegaphone:reestablishMegaphone(targetIDs)
    for _, targetId in ipairs(targetIDs) do
        local value = Player(targetId).state[YACA_STATE_MEGAPHONE]
        if type(value) == "number" then
            self:applyMegaphoneEffect(targetId, value)
        end
    end
end

function YacaMegaphone:isMegaphoneUsable()
    if self.forceCanUseMegaphone then
        return true
    end

    if YacaClient.isFiveM and not YacaCache.vehicle and YacaClient.sharedConfig.megaphone.automaticVehicleDetection then
        return false
    end

    return self.canUseMegaphone
end

function YacaMegaphone:useMegaphone(state)
    state = state or false

    if not self:isMegaphoneUsable() or state == self.lastMegaphoneState then
        return
    end

    self.lastMegaphoneState = not self.lastMegaphoneState
    TriggerServerEvent("server:yaca:useMegaphone", state)
    TriggerEvent("yaca:external:megaphoneState", state)
end

Citizen.CreateThread(function()
    while not YacaClient.sharedConfig do
        Citizen.Wait(100)
    end
    initMegaphoneModule()
end)
