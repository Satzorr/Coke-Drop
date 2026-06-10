local QBCore = exports['qb-core']:GetCoreObject()

local CartelNumbers  = {}  
local CurrentGroupPos = nil  -- the current active group position sent to clients

local function RandomFrom(t)
    return t[math.random(#t)]
end

-- Pick a random drop landing position
local function RandomDropPosition()
    local zones = {
        vector3(-46.313,   -1757.504, 29.0),
        vector3(24.376,    -1345.558, 29.0),
        vector3(1134.182,  -982.477,  46.0),
        vector3(373.015,   328.332,   103.0),
        vector3(200.0,     -900.0,    30.0),
        vector3(800.0,     -1200.0,   30.0),
        vector3(1200.0,    -600.0,    65.0),
        vector3(1700.0,    3700.0,    34.0),
        vector3(2500.0,    4100.0,    38.0),
        vector3(-150.0,    6300.0,    31.0),
        vector3(-1200.0,   -500.0,    40.0),
        vector3(1000.0,    -200.0,    70.0),
        vector3(-609.77,   -1672.07,  19.0),
        vector3(949.84,    -202.72,   73.0),
        vector3(-447.97,   -895.47,   47.0),
    }
    local base = zones[math.random(#zones)]
    return vector3(
        base.x + math.random(-200, 200),
        base.y + math.random(-200, 200),
        base.z
    )
end

local function GetCopsOnline()
    local count = 0
    for _, src in ipairs(QBCore.Functions.GetPlayers()) do
        local player = QBCore.Functions.GetPlayer(src)
        if player then
            local job = player.PlayerData.job
            if job and (job.name == 'police' or job.name == 'bcso') and job.onduty then
                count = count + 1
            end
        end
    end
    return count
end

-- Pick a new random group position and assign a number to it
-- Called on start and every 4 hours
local function SpawnNewCartelGroup()
    -- Shuffle and pick position
    local pos = Config.GroupPositions[math.random(#Config.GroupPositions)]
    CurrentGroupPos = pos

    -- Pick one random number for this group
    local number = Config.PhoneNumbers and Config.PhoneNumbers[math.random(#Config.PhoneNumbers)]
    if not number then
        -- Build phone number dynamically if Config.PhoneNumbers missing
        number = string.format('52-550-%03d-%04d', math.random(100, 999), math.random(1000, 9999))
    end

    -- Register the number (persists until server restart or used)
    CartelNumbers[number] = { active = true }

    -- Tell all clients to spawn NPCs at this position with this number
    TriggerClientEvent('coke_drop:client:SpawnGroup', -1, pos, number)

    print('[coke_drop] New cartel group spawned at ' .. tostring(pos) .. ' | Number: ' .. number)

    -- Schedule next respawn in 4h (always, regardless of whether bought)
    SetTimeout(Config.NPCRespawnDelay * 1000, function()
        SpawnNewCartelGroup()
    end)
end

-- Sync group to a player who just joined
RegisterNetEvent('coke_drop:server:RequestSync', function()
    local src = source
    if CurrentGroupPos then
        -- Find the active number for this group
        for number, data in pairs(CartelNumbers) do
            if data.active then
                TriggerClientEvent('coke_drop:client:SpawnGroup', src, CurrentGroupPos, number)
                break
            end
        end
    end
end)

-- Player calls the number from qb-phone
RegisterNetEvent('coke_drop:server:PhoneCall', function(number)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local data = CartelNumbers[number]
    if not data or not data.active then
        TriggerClientEvent('QBCore:Notify', src, 'This number is no longer active.', 'error')
        return
    end

    TriggerClientEvent('coke_drop:client:OpenMenu', src, number)
end)

-- Player ordered a package
RegisterNetEvent('coke_drop:server:OrderDrop', function(number, packageKey)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local data = CartelNumbers[number]
    if not data or not data.active then
        TriggerClientEvent('QBCore:Notify', src, 'This number is no longer active.', 'error')
        return
    end

    local package = Config.Packages[packageKey]
    if not package then return end

    -- Check money
    local cash = player.PlayerData.money['cash'] or 0
    local bank = player.PlayerData.money['bank'] or 0

    if (cash + bank) < package.price then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough money.', 'error')
        return
    end

    -- Deduct money (bank first)
    if bank >= package.price then
        player.Functions.RemoveMoney('bank', package.price, 'coke-drop')
    else
        local remainder = package.price - bank
        player.Functions.RemoveMoney('bank', bank, 'coke-drop')
        player.Functions.RemoveMoney('cash', remainder, 'coke-drop')
    end

    -- Mark number as used
    data.active = false

    -- Pick drop position
    local dropPos = RandomDropPosition()

    -- Send drop event to all clients
    TriggerClientEvent('coke_drop:client:InboundDrop', -1, dropPos, src, packageKey)

    -- Police alert
    if math.random(100) <= Config.Drop.PoliceChance then
        TriggerClientEvent('police:client:PoliceAlert', -1, {
            type    = 'airdrop',
            message = 'Suspicious aircraft detected',
            coords  = dropPos,
        })
    end

    print('[coke_drop] Drop ordered - package: ' .. packageKey)
end)

-- Player picks up one brick at a time
RegisterNetEvent('coke_drop:server:PickupBrick', function(packageKey)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local package = Config.Packages[packageKey]
    if not package then return end

    local added = player.Functions.AddItem(package.item, 1)
    if added then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[package.item], 'add')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Inventory full.', 'error')
    end
end)

-- Admin test command
QBCore.Commands.Add('testdrop', 'Trigger test coke drop', {}, false, function(source)
    local dropPos = RandomDropPosition()
    TriggerClientEvent('coke_drop:client:InboundDrop', -1, dropPos, source, 'small')
    TriggerClientEvent('QBCore:Notify', source, 'Test drop triggered.', 'success')
end, 'admin')

QBCore.Commands.Add('respawncartel', 'Force respawn cartel group', {}, false, function(source)
    SpawnNewCartelGroup()
    TriggerClientEvent('QBCore:Notify', source, 'Cartel group respawned.', 'success')
end, 'admin')

-- Init
CreateThread(function()
    math.randomseed(os.time())
    Wait(3000)
    SpawnNewCartelGroup()
    print('[coke_drop] Initialized')
end)
