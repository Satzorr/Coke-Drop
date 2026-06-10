local QBCore = exports['qb-core']:GetCoreObject()

local SpawnedNPCs    = {}
local ActiveCrate    = nil
local pickupCooldown = false
local dropBlip       = nil

-- =====================
-- UTILITY
-- =====================

local function LoadModel(model)
    local hash = type(model) == 'string' and GetHashKey(model) or model
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do
        Wait(100)
        t = t + 1
    end
    return hash
end

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(100) end
end

-- =====================
-- NPC SYSTEM
-- =====================

local function DeleteNPCs()
    for i = 1, #SpawnedNPCs do
        local data = SpawnedNPCs[i]
        if data and DoesEntityExist(data.ped) then
            SetEntityAsMissionEntity(data.ped, true, true)
            DeleteEntity(data.ped)
        end
    end
    SpawnedNPCs = {}
end

RegisterNetEvent('coke_drop:client:SpawnGroup', function(pos, number)
    DeleteNPCs()

    local offsets = {
        { x = 0.0,  y = 0.0 },
        { x = 1.2,  y = 0.0 },
        { x = -1.2, y = 0.0 },
    }

    for i = 1, #offsets do
        local offset    = offsets[i]
        local spawnPos  = vector3(pos.x + offset.x, pos.y + offset.y, pos.z)
        local heading   = pos.w
        local modelName = Config.CartelModels[math.random(#Config.CartelModels)]
        local hash      = LoadModel(modelName)

        if HasModelLoaded(hash) then
            local ped = CreatePed(4, hash, spawnPos.x, spawnPos.y, spawnPos.z - 1.0, heading, false, true)
            SetEntityAsMissionEntity(ped, true, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedDiesWhenInjured(ped, false)
            SetEntityInvincible(ped, true)
            FreezeEntityPosition(ped, false)
            TaskStartScenarioInPlace(ped, Config.CartelScenarios[math.random(#Config.CartelScenarios)], -1, true)
            SetModelAsNoLongerNeeded(hash)
            SpawnedNPCs[#SpawnedNPCs + 1] = { ped = ped, number = number }
        end
    end

    print('[coke_drop] Spawned ' .. #SpawnedNPCs .. ' NPCs')
end)

-- =====================
-- NPC INTERACTION LOOP
-- =====================

CreateThread(function()
    Wait(3000)
    TriggerServerEvent('coke_drop:server:RequestSync')

    while true do
        Wait(500)

        local playerPed    = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local closestDist  = 999.0
        local closestData  = nil

        for i = 1, #SpawnedNPCs do
            local data = SpawnedNPCs[i]
            if data and DoesEntityExist(data.ped) then
                local dist = #(playerCoords - GetEntityCoords(data.ped))
                if dist < closestDist then
                    closestDist = dist
                    closestData = data
                end
            end
        end

        if closestDist < Config.InteractionDistance and closestData then
            SetTextScale(0.4, 0.4)
            SetTextFont(4)
            SetTextColour(255, 165, 0, 255)
            SetTextCentre(true)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName('[E] Talk')
            EndTextCommandDisplayText(0.5, 0.92)

            if IsControlJustPressed(0, 38) then
                local ped    = closestData.ped
                local number = closestData.number
                local pedCoords = GetEntityCoords(ped)

                SetEntityHeading(ped, GetHeadingFromVector_2d(
                    pedCoords.x - playerCoords.x,
                    pedCoords.y - playerCoords.y
                ))

                LoadAnimDict('mp_common')
                TaskPlayAnim(playerPed, 'mp_common', 'givetake1_a', 3.0, 3.0, 1500, 0, 0, false, false, false)
                TaskPlayAnim(ped,       'mp_common', 'givetake1_b', 3.0, 3.0, 1500, 0, 0, false, false, false)
                Wait(1500)

                QBCore.Functions.Notify('~o~Alright esse, take this: ~g~' .. number, 'success', 7000)
                TriggerServerEvent('coke_drop:server:NumberGiven', number)
                TriggerEvent('qb-phone:client:AddContact', { name = '???', number = number, iban = '' })
                Wait(3000)
            end
        end
    end
end)

-- =====================
-- PHONE CALL HANDLER
-- =====================

AddEventHandler('qb-phone:client:CallNumber', function(number)
    TriggerServerEvent('coke_drop:server:PhoneCall', number)
end)

-- =====================
-- MENU
-- =====================

RegisterNetEvent('coke_drop:client:OpenMenu', function(number)
    local options = {}
    for packageKey, pkg in pairs(Config.Packages) do
        local key = packageKey
        options[#options + 1] = {
            title       = pkg.label,
            description = '~g~$' .. pkg.price,
            onSelect    = function()
                TriggerServerEvent('coke_drop:server:OrderDrop', number, key)
            end
        }
    end
    table.sort(options, function(a, b) return a.description < b.description end)
    lib.registerContext({ id = 'cartel_menu', title = '??? Contact', options = options })
    lib.showContext('cartel_menu')
end)

-- =====================
-- AIRDROP
-- =====================

RegisterNetEvent('coke_drop:client:InboundDrop', function(dropPos, callerSrc, packageKey)
    print('[coke_drop] CLIENT: InboundDrop at ' .. tostring(dropPos))

    local myId     = GetPlayerServerId(PlayerId())
    local isCaller = (callerSrc == myId)
    local playerData = QBCore.Functions.GetPlayerData()
    local hasChip    = false
    if playerData and playerData.items then
        for _, item in pairs(playerData.items) do
            if item and item.name == Config.SimcardItem and item.amount > 0 then
                hasChip = true
                break
            end
        end
    end

    if isCaller or hasChip then
        if dropBlip and DoesBlipExist(dropBlip) then RemoveBlip(dropBlip) end

        local bx = isCaller and (dropPos.x + math.random(-50, 50))   or (dropPos.x + math.random(-200, 200))
        local by = isCaller and (dropPos.y + math.random(-50, 50))   or (dropPos.y + math.random(-200, 200))
        local radius = isCaller and Config.Drop.CallerRadius or Config.Drop.ChipRadius

        dropBlip = AddBlipForRadius(bx, by, dropPos.z, radius)
        SetBlipColour(dropBlip, 38)
        SetBlipAlpha(dropBlip, 170)

        QBCore.Functions.Notify(
            isCaller and '~y~Delivery inbound. Check your map.' or '~y~Airdrop spotted nearby.',
            'primary', 8000
        )

        SetTimeout(Config.Drop.BlipDuration * 1000, function()
            if dropBlip and DoesBlipExist(dropBlip) then
                RemoveBlip(dropBlip)
                dropBlip = nil
            end
        end)
    end

    CreateThread(function()
        local chuteHash = LoadModel(Config.Drop.Models.chute)
        local crateHash = LoadModel(Config.Drop.Models.crate)

        print('[coke_drop] CLIENT: Spawning crate')

        local crate = CreateObject(crateHash, dropPos.x, dropPos.y, Config.Drop.SpawnHeight, false, false, false)
        SetEntityAsMissionEntity(crate, true, true)
        SetEntityDynamic(crate, true)
        SetEntityHasGravity(crate, true)
        SetEntityCollision(crate, true, true)

        local chute = CreateObject(chuteHash, dropPos.x, dropPos.y, Config.Drop.SpawnHeight, false, false, false)
        SetEntityAsMissionEntity(chute, true, true)
        AttachEntityToEntity(chute, crate, 0, 0.0, 0.0, 3.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)

        ActiveCrate = { obj = crate, chute = chute, packageKey = packageKey, landed = false }

        -- Keep pushing crate down until landed
        CreateThread(function()
            while DoesEntityExist(crate) and ActiveCrate and not ActiveCrate.landed do
                SetEntityVelocity(crate, 0.0, 0.0, -6.0)
                Wait(100)
            end
        end)

        -- Landing detection
        CreateThread(function()
            while DoesEntityExist(crate) do
                Wait(300)
                local cp = GetEntityCoords(crate)
                local found, gz = GetGroundZFor_3dCoord(cp.x, cp.y, cp.z, false)
                if not found then
                    found, gz = GetGroundZFor_3dCoord(cp.x, cp.y, 1000.0, false)
                end

                if found and cp.z <= gz + 1.5 then
                    print('[coke_drop] CLIENT: Crate landed at ' .. tostring(cp))
                    local fp = vector3(cp.x, cp.y, gz + 0.05)

                    SetEntityCoords(crate, fp.x, fp.y, fp.z, false, false, false, false)
                    FreezeEntityPosition(crate, true)
                    SetEntityDynamic(crate, false)

                    if chute and DoesEntityExist(chute) then
                        DetachEntity(chute, true, false)
                        SetEntityAsMissionEntity(chute, true, true)
                        FreezeEntityPosition(chute, true)
                        SetEntityCoords(chute, fp.x + 1.5, fp.y + 1.5, fp.z, false, false, false, false)
                        -- clean up after blip expires
                        SetTimeout(Config.Drop.BlipDuration * 1000, function()
                            if DoesEntityExist(chute) then
                                SetEntityAsMissionEntity(chute, true, true)
                                DeleteObject(chute)
                            end
                        end)
                    end

                    -- Flare effect using particle (ThrowProjectile not available in FiveM)
                    RequestNamedPtfxAsset('scr_rcbarry2')
                    local pt = 0
                    while not HasNamedPtfxAssetLoaded('scr_rcbarry2') and pt < 30 do Wait(100); pt = pt + 1 end
                    if HasNamedPtfxAssetLoaded('scr_rcbarry2') then
                        UseParticleFxAssetNextCall('scr_rcbarry2')
                        local fx = StartParticleFxLoopedAtCoord(
                            'scr_rcbarry2_alien_dis',
                            fp.x, fp.y, fp.z + 0.3,
                            0.0, 0.0, 0.0, 1.5, false, false, false, false
                        )
                        SetParticleFxLoopedColour(fx, 1.0, 0.1, 0.0, false)
                        SetTimeout(Config.Drop.BlipDuration * 1000, function()
                            StopParticleFxLooped(fx, false)
                        end)
                    end

                    if ActiveCrate then
                        ActiveCrate.landed = true
                        ActiveCrate.pos    = fp
                    end

                    break
                end
            end
        end)

        SetModelAsNoLongerNeeded(chuteHash)
        SetModelAsNoLongerNeeded(crateHash)
    end)
end)

-- =====================
-- PICKUP LOOP
-- =====================

CreateThread(function()
    while true do
        local hasActive   = ActiveCrate ~= nil
        local landed      = hasActive and ActiveCrate.landed
        local looted      = hasActive and ActiveCrate.looted
        local crateObj    = hasActive and ActiveCrate.obj or nil
        local crateExists = crateObj ~= nil and DoesEntityExist(crateObj)

        if landed and not looted and crateExists and not pickupCooldown then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local crateCoords  = GetEntityCoords(crateObj)
            local dist         = #(playerCoords - crateCoords)

            if dist < 2.5 then
                local playerData  = QBCore.Functions.GetPlayerData()
                local hasCrowbar  = false
                if playerData and playerData.items then
                    for _, item in pairs(playerData.items) do
                        if item and item.name == 'crowbar' and item.amount > 0 then
                            hasCrowbar = true
                            break
                        end
                    end
                end

                SetTextScale(0.4, 0.4)
                SetTextFont(4)
                SetTextColour(255, 165, 0, 255)
                SetTextCentre(true)
                BeginTextCommandDisplayText('STRING')
                if hasCrowbar then
                    AddTextComponentSubstringPlayerName('[E] Loot Drop')
                else
                    AddTextComponentSubstringPlayerName('~r~Need a Crowbar')
                end
                EndTextCommandDisplayText(0.5, 0.92)

                if IsControlJustPressed(0, 38) and hasCrowbar then
                    pickupCooldown = true

                    local pkg = Config.Packages[ActiveCrate.packageKey]
                    if pkg then
                        local total = pkg.amount
                        for i = 1, total do
                            if not ActiveCrate or ActiveCrate.looted then break end

                            LoadAnimDict('mp_common')
                            TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_b', 3.0, 3.0, 2500, 0, 0, false, false, false)
                            QBCore.Functions.Notify('Looting... (' .. i .. '/' .. total .. ')', 'primary', 2500)
                            Wait(2500)

                            TriggerServerEvent('coke_drop:server:PickupBrick', ActiveCrate.packageKey)
                        end

                        if ActiveCrate then ActiveCrate.looted = true end
                        QBCore.Functions.Notify('Crate looted.', 'success', 4000)
                    end

                    pickupCooldown = false
                end

                Wait(0)
            else
                Wait(500)
            end
        else
            Wait(500)
        end
    end
end)

-- =====================
-- CLEANUP
-- =====================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DeleteNPCs()
    if ActiveCrate and DoesEntityExist(ActiveCrate.obj) then
        DeleteObject(ActiveCrate.obj)
    end
    if dropBlip and DoesBlipExist(dropBlip) then
        RemoveBlip(dropBlip)
    end
end)
