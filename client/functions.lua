-- Additional client functions for QBCore garage system

-- Initialize variables
local QBCore = exports['qb-core']:GetCoreObject()

-- Check if player owns a vehicle
function DoesPlayerOwnVehicle(plate)
    local vehicles = GetPlayerVehicles()
    
    for _, vehicle in ipairs(vehicles) do
        if vehicle.plate == plate then
            return true
        end
    end
    
    return false
end

-- Get player vehicles
function GetPlayerVehicles()
    local playerVehicles = {}
    local playerData = QBCore.Functions.GetPlayerData()
    
    TriggerServerCallback('qb-garage:getPlayerVehicles', function(vehicles)
        playerVehicles = vehicles
    end)
    
    return playerVehicles
end

-- Calculate vehicle stats (normalized from 0.0 to 1.0)
function CalculateVehicleStats(vehicle)
    if not DoesEntityExist(vehicle) then
        return {
            speed = 0.0,
            acceleration = 0.0,
            braking = 0.0,
            handling = 0.0
        }
    end
    
    local stats = {
        speed = GetVehicleModelMaxSpeed(GetEntityModel(vehicle)) / 100.0,
        acceleration = GetVehicleModelAcceleration(GetEntityModel(vehicle)) * 2.5,
        braking = GetVehicleModelMaxBraking(GetEntityModel(vehicle)) * 2.0,
        handling = GetVehicleModelMaxTraction(GetEntityModel(vehicle)) / 2.0
    }
    
    -- Normalize values between 0.0 and 1.0
    for k, v in pairs(stats) do
        stats[k] = math.min(math.max(v, 0.0), 1.0)
    end
    
    return stats
end

-- Generate a new random license plate
function GenerateNewPlate()
    local plate = ""
    
    if Config.GenerateNewPlateOnPurchase then
        if Config.CustomPlateText and Config.CustomPlateText ~= "" then
            plate = Config.CustomPlateText
            local remaining = 8 - #plate
            
            for i = 1, remaining do
                local charPool = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                local random = math.random(1, #charPool)
                plate = plate .. string.sub(charPool, random, random)
            end
        else
            for i = 1, 8 do
                local charPool = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                local random = math.random(1, #charPool)
                plate = plate .. string.sub(charPool, random, random)
            end
        end
    end
    
    return plate
end

-- Round number to decimal places
function Round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Format number with commas
function CommaValue(amount)
    local formatted = tostring(amount)
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- Get all nearby players
function GetNearbyPlayers(radius)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local players = {}
    local nearbyPlayers = QBCore.Functions.GetPlayersFromCoords(playerCoords, radius)
    
    for _, player in ipairs(nearbyPlayers) do
        if player ~= PlayerId() then
            table.insert(players, {
                id = GetPlayerServerId(player),
                name = GetPlayerName(player)
            })
        end
    end
    
    table.sort(players, function(a, b)
        return a.name < b.name
    end)
    
    return players
end

-- Set vehicle as player owned
function SetVehicleAsOwned(vehicle)
    local vehicleProps = Bridge.GetVehicleProperties(vehicle)
    if not vehicleProps then return false end
    
    TriggerServerEvent('qb-garage:setVehicleOwned', vehicleProps)
    return true
end

-- Update vehicle tuning parts from vehicle entity
function UpdateVehicleTuning(vehicle, vehicleProps)
    if not DoesEntityExist(vehicle) or not vehicleProps then return vehicleProps end
    
    -- Updated mods
    local updatedProps = Bridge.GetVehicleProperties(vehicle)
    
    if Config.EnableVehicleTuning and updatedProps then
        -- Update mods
        vehicleProps.modEngine = updatedProps.modEngine
        vehicleProps.modBrakes = updatedProps.modBrakes
        vehicleProps.modTransmission = updatedProps.modTransmission
        vehicleProps.modSuspension = updatedProps.modSuspension
        vehicleProps.modArmor = updatedProps.modArmor
        vehicleProps.modTurbo = updatedProps.modTurbo
        vehicleProps.modXenon = updatedProps.modXenon
        vehicleProps.xenonColor = updatedProps.xenonColor
        vehicleProps.wheelColor = updatedProps.wheelColor
        vehicleProps.wheels = updatedProps.wheels
        vehicleProps.windowTint = updatedProps.windowTint
        
        -- Update all other mods (0-49)
        for i = 0, 49 do
            vehicleProps["modMod" .. i] = updatedProps["modMod" .. i]
        end
        
        -- Update custom livery if exists
        if updatedProps.livery then
            vehicleProps.livery = updatedProps.livery
        end
    end
    
    return vehicleProps
end

-- Get player job vehicles
function GetJobVehicles(job)
    local jobVehicles = {}
    
    if not job or not job.name then return jobVehicles end
    
    TriggerServerCallback('qb-garage:getJobVehicles', function(vehicles)
        jobVehicles = vehicles
    end, job.name)
    
    return jobVehicles
end

-- Get vehicle health status as percentage
function GetVehicleHealthPercent(vehicle)
    if not DoesEntityExist(vehicle) then return 100 end
    
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    
    local enginePercent = (engineHealth / 1000) * 100
    local bodyPercent = (bodyHealth / 1000) * 100
    
    return {
        engine = Round(enginePercent, 1),
        body = Round(bodyPercent, 1)
    }
end

-- Get fuel level percentage
function GetVehicleFuelPercent(vehicle)
    if not DoesEntityExist(vehicle) then return 100 end
    
    local fuelLevel = GetVehicleFuelLevel(vehicle)
    return Round(fuelLevel, 1)
end

-- Check if vehicle has a car key in inventory
function HasVehicleKey(plate)
    local hasKey = false
    
    if Config.UseCarKeys then
        QBCore.Functions.TriggerCallback('qb-vehiclekeys:server:CheckHasKey', function(result)
            hasKey = result
        end, plate)
    else
        hasKey = true
    end
    
    return hasKey
end

-- Add car key to player inventory
function GiveVehicleKeys(plate)
    if not Config.UseCarKeys then return true end
    
    TriggerServerEvent('qb-vehiclekeys:server:GiveVehicleKeys', plate)
    return true
end

-- Add marker to vehicle location on map
function SetVehicleLocationBlip(coords, plate, vehicleLabel)
    if not Config.EnableVehicleTracking then return end
    
    local blip = AddBlipForCoord(coords)
    SetBlipSprite(blip, 225) -- GPS Location
    SetBlipColour(blip, 4)   -- Red
    SetBlipScale(blip, 1.2)
    SetBlipAlpha(blip, 180)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Fahrzeug: " .. vehicleLabel .. " (" .. plate .. ")")
    EndTextCommandSetBlipName(blip)
    
    -- Remove blip after 60 seconds
    SetTimeout(60000, function()
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
end