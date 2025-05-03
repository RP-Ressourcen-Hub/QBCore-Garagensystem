-- Main client file for QBCore garage system
local QBCore = exports['qb-core']:GetCoreObject()
local currentGarage = nil
local isMenuOpen = false
local nearbyVehicles = {}
local displayedBlips = {}
local currentlyWithinMarker = false
local lastZone = nil
local infoShowing = false
local previewVehicle = nil
local activeCamera = false

-- Initialize the script
CreateThread(function()
    -- Wait for Bridge to be ready
    while not Bridge do
        Wait(500)
    end
    
    -- Create garage blips
    CreateGarageBlips()
    
    -- Main loop
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local sleep = 1000
        local inMarker = false
        local currentZone = nil
        
        -- Check for nearby garages
        for garageName, garage in pairs(Config.Garages) do
            -- Check if player is near a menu point
            local menuDistance = #(playerCoords - garage.menu_point.coords)
            if menuDistance < garage.menu_point.radius then
                sleep = 0
                inMarker = true
                currentZone = {name = garageName, point = 'menu'}
                
                -- Display help text
                if garage.type == "impound" then
                    DisplayHelpText(_U('help_open_impound'))
                else
                    DisplayHelpText(_U('help_open_garage'))
                end
                
                -- Open garage menu on interact
                if IsControlJustReleased(0, 38) then -- E key
                    OpenGarageMenu(garageName)
                end
                
                break
            end
            
            -- Check if player is near a parking point and in a vehicle
            if IsPedInAnyVehicle(playerPed, false) then
                local parkingDistance = #(playerCoords - garage.parking_point.coords)
                if parkingDistance < garage.parking_point.radius then
                    sleep = 0
                    inMarker = true
                    currentZone = {name = garageName, point = 'parking'}
                    
                    -- Display help text
                    DisplayHelpText(_U('help_store_vehicle'))
                    
                    -- Store vehicle on interact
                    if IsControlJustReleased(0, 38) then -- E key
                        StoreVehicle(garageName)
                    end
                    
                    break
                end
            end
        end
        
        -- Handle marker status changes
        if inMarker and not currentlyWithinMarker then
            currentlyWithinMarker = true
            lastZone = currentZone
            TriggerEvent('qb-garage:hasEnteredMarker', currentZone)
        end
        
        if not inMarker and currentlyWithinMarker then
            currentlyWithinMarker = false
            TriggerEvent('qb-garage:hasExitedMarker', lastZone)
        end
        
        Wait(sleep)
    end
end)

-- Create blips for all garages
function CreateGarageBlips()
    -- Remove existing blips
    for _, blip in pairs(displayedBlips) do
        RemoveBlip(blip)
    end
    displayedBlips = {}
    
    -- Create new blips
    for garageName, garage in pairs(Config.Garages) do
        if garage.blip then
            local blip = AddBlipForCoord(garage.menu_point.coords)
            
            SetBlipSprite(blip, garage.type == "impound" and 523 or Config.BlipSprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.BlipScale)
            SetBlipColour(blip, garage.type == "impound" and 17 or Config.BlipColor)
            SetBlipAsShortRange(blip, true)
            
            BeginTextCommandSetBlipName("STRING")
            if garage.type == "impound" then
                AddTextComponentString(garage.label .. " (" .. _U('impound_blip') .. ")")
            else
                AddTextComponentString(garage.label)
            end
            EndTextCommandSetBlipName(blip)
            
            table.insert(displayedBlips, blip)
        end
    end
end

-- Draw markers at garage locations
CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local sleep = 1000
        
        if Config.DrawMarker then
            for _, garage in pairs(Config.Garages) do
                -- Draw marker at menu point
                local menuDistance = #(playerCoords - garage.menu_point.coords)
                if menuDistance < 50.0 then
                    sleep = 0
                    
                    DrawMarker(
                        Config.MarkerType,
                        garage.menu_point.coords.x, garage.menu_point.coords.y, garage.menu_point.coords.z - 0.5,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z,
                        Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, Config.MarkerColor.a,
                        false, true, 2, nil, nil, false
                    )
                end
                
                -- Draw marker at parking point
                local parkingDistance = #(playerCoords - garage.parking_point.coords)
                if parkingDistance < 50.0 then
                    sleep = 0
                    
                    DrawMarker(
                        Config.MarkerType,
                        garage.parking_point.coords.x, garage.parking_point.coords.y, garage.parking_point.coords.z - 0.5,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z,
                        Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, Config.MarkerColor.a,
                        false, true, 2, nil, nil, false
                    )
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- Open the garage menu
function OpenGarageMenu(garageName)
    if isMenuOpen then return end
    
    currentGarage = Config.Garages[garageName]
    if not currentGarage then return end
    
    local playerJob = QBCore.Functions.GetPlayerData().job
    local playerGang = QBCore.Functions.GetPlayerData().gang
    
    -- Check if player has access to this garage
    if not CanAccessGarage(currentGarage, playerJob, playerGang) then
        Bridge.Notify(source, _U('error_not_allowed'), 'error')
        return
    end
    
    isMenuOpen = true
    
    -- Get player vehicles from server
    TriggerServerEvent('qb-garage:requestVehicles', garageName)
    
    -- Track nearbyVehicles for parking
    FindNearbyVehicles()
    
    -- Display UI
    SendNUIMessage({
        type = 'openGarage',
        garageName = garageName,
        garageLabel = currentGarage.label,
        isImpound = currentGarage.type == "impound",
        impoundFee = Config.ImpoundFee,
        transferFee = Config.TransferFee,
        allowTransfer = Config.AllowVehicleTransfer,
        categories = Config.VehicleCategories,
        defaultCategory = Config.UI.defaultCategory,
        showStats = Config.UI.showVehicleStats,
        showMods = Config.UI.showVehicleMods,
        darkMode = Config.UI.darkMode,
        garageLocations = GetTransferableGarages(currentGarage.type),
        locale = {
            title = _U('garage_title'),
            impoundTitle = _U('impound_title'),
            noVehicles = _U('no_vehicles'),
            noImpoundedVehicles = _U('no_vehicles_impounded'),
            close = _U('ui_close'),
            back = _U('ui_back'),
            confirm = _U('ui_confirm'),
            cancel = _U('ui_cancel'),
            selectVehicle = _U('ui_select_vehicle'),
            selectCategory = _U('ui_select_category'),
            transferTo = _U('ui_transfer_to'),
            transferFee = _U('ui_transfer_fee'),
            impoundFee = _U('ui_impound_fee'),
            vehicleInfo = _U('ui_vehicle_info'),
            plate = _U('ui_plate'),
            fuel = _U('ui_fuel'),
            engine = _U('ui_engine'),
            body = _U('ui_body'),
            status = _U('ui_status'),
            location = _U('ui_location')
        }
    })
    
    -- Set focus to NUI
    SetNuiFocus(true, true)
    
    -- Start UI animations
    TriggerScreenblurFadeIn(300)
end

-- Display vehicles in the garage UI
RegisterNetEvent('qb-garage:receiveVehicles')
AddEventHandler('qb-garage:receiveVehicles', function(vehicles)
    local formattedVehicles = {}
    
    for _, vehicle in ipairs(vehicles) do
        local formattedVehicle = FormatVehicleData(vehicle)
        table.insert(formattedVehicles, formattedVehicle)
    end
    
    SendNUIMessage({
        type = 'setVehicles',
        vehicles = formattedVehicles
    })
end)

-- Spawn a vehicle from the garage
RegisterNUICallback('spawnVehicle', function(data, cb)
    if not currentGarage then
        cb({success = false, message = 'No active garage'})
        return
    end
    
    TriggerServerEvent('qb-garage:requestVehicleSpawn', data.plate)
    
    cb({success = true})
end)

-- Close the garage UI
RegisterNUICallback('closeGarage', function(_, cb)
    CloseGarageMenu()
    cb({})
end)

-- Handle vehicle spawn from server
RegisterNetEvent('qb-garage:spawnVehicle')
AddEventHandler('qb-garage:spawnVehicle', function(vehicleData)
    if not currentGarage then return end
    
    -- Find a free spawn point
    local spawnPoint = nil
    for _, point in ipairs(currentGarage.spawn_points) do
        if IsSpawnPointClear(point.coords, point.radius) then
            spawnPoint = point
            break
        end
    end
    
    if not spawnPoint then
        Bridge.Notify(source, _U('no_spawn_point'), 'error')
        return
    end
    
    -- Close the menu
    CloseGarageMenu()
    
    -- Request the model
    local modelHash = GetHashKey(vehicleData.model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(1)
    end
    
    -- Spawn the vehicle
    local vehicle = CreateVehicle(modelHash, spawnPoint.coords, spawnPoint.heading, true, false)
    
    -- Set vehicle properties
    Bridge.SetVehicleProperties(vehicle, vehicleData.properties)
    
    -- Set as player vehicle
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    
    -- Restore vehicle damage if configured
    if Config.RestoreVehicleDamage and vehicleData.bodyHealth then
        SetVehicleBodyHealth(vehicle, vehicleData.bodyHealth)
    end
    
    if Config.RestoreVehicleDamage and vehicleData.engineHealth then
        SetVehicleEngineHealth(vehicle, vehicleData.engineHealth)
    end
    
    -- Restore fuel if configured
    if Config.RestoreVehicleFuel and vehicleData.fuelLevel then
        SetVehicleFuelLevel(vehicle, vehicleData.fuelLevel)
    end
    
    -- Set into driver seat
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    
    -- Cleanup model
    SetModelAsNoLongerNeeded(modelHash)
    
    -- Notify the player
    Bridge.Notify(source, _U('vehicle_retrieved'), 'success')
end)

-- Store a vehicle in the garage
function StoreVehicle(garageName)
    local garage = Config.Garages[garageName]
    if not garage then return end
    
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if vehicle == 0 then
        Bridge.Notify(source, _U('not_in_vehicle'), 'error')
        return
    end
    
    -- Check if vehicle type is allowed in this garage
    local vehicleType = GetVehicleType(GetEntityModel(vehicle))
    if not IsVehicleTypeAllowedInGarage(vehicleType, garage) then
        Bridge.Notify(source, _U('cannot_store_this_vehicle'), 'error')
        return
    end
    
    -- Get vehicle properties
    local vehicleProps = Bridge.GetVehicleProperties(vehicle)
    if not vehicleProps then return end
    
    -- Get additional vehicle data
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local fuelLevel = GetVehicleFuelLevel(vehicle)
    
    -- Store the vehicle on the server
    TriggerServerEvent('qb-garage:storeVehicle', garageName, vehicleProps, {
        bodyHealth = bodyHealth,
        engineHealth = engineHealth,
        fuelLevel = fuelLevel
    })
    
    -- Delete the vehicle
    DeleteVehicle(vehicle)
end

-- Transfer a vehicle to another garage
RegisterNUICallback('transferVehicle', function(data, cb)
    if not currentGarage or not Config.AllowVehicleTransfer then
        cb({success = false, message = 'Transfer not allowed'})
        return
    end
    
    TriggerServerEvent('qb-garage:transferVehicle', data.plate, data.targetGarage)
    
    cb({success = true})
end)

-- Release a vehicle from impound
RegisterNUICallback('releaseVehicle', function(data, cb)
    if not currentGarage or currentGarage.type ~= "impound" then
        cb({success = false, message = 'Not an impound'})
        return
    end
    
    TriggerServerEvent('qb-garage:releaseVehicle', data.plate)
    
    cb({success = true})
end)

-- Preview a vehicle before spawning
RegisterNUICallback('previewVehicle', function(data, cb)
    if not Config.VehiclePreview or not currentGarage then
        cb({success = false})
        return
    end
    
    -- Remove existing preview vehicle
    if previewVehicle then
        DeleteVehicle(previewVehicle)
        previewVehicle = nil
    end
    
    TriggerServerEvent('qb-garage:requestVehiclePreview', data.plate)
    
    cb({success = true})
end)

-- Handle vehicle preview from server
RegisterNetEvent('qb-garage:previewVehicle')
AddEventHandler('qb-garage:previewVehicle', function(vehicleData)
    if not currentGarage or previewVehicle then return end
    
    -- Find an available spawn point for preview
    local spawnPoint = nil
    for _, point in ipairs(currentGarage.spawn_points) do
        if IsSpawnPointClear(point.coords, point.radius) then
            spawnPoint = point
            break
        end
    end
    
    if not spawnPoint then return end
    
    -- Request the model
    local modelHash = GetHashKey(vehicleData.model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(1)
    end
    
    -- Create the preview vehicle
    previewVehicle = CreateVehicle(modelHash, spawnPoint.coords, spawnPoint.heading, false, false)
    
    -- Set vehicle properties
    Bridge.SetVehicleProperties(previewVehicle, vehicleData.properties)
    
    -- Make the vehicle unable to be entered or damaged
    SetEntityAlpha(previewVehicle, 200, false)
    SetVehicleDoorsLocked(previewVehicle, 2)
    FreezeEntityPosition(previewVehicle, true)
    SetEntityInvincible(previewVehicle, true)
    SetVehicleEngineOn(previewVehicle, false, true, true)
    
    -- Create a camera looking at the vehicle
    if not DoesCamExist(cam) then
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    end
    
    local offset = GetOffsetFromEntityInWorldCoords(previewVehicle, 0.0, -5.0, 1.75)
    local coords = GetEntityCoords(previewVehicle)
    
    SetCamCoord(cam, offset.x, offset.y, offset.z)
    PointCamAtCoord(cam, coords.x, coords.y, coords.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)
    
    -- Start a thread to handle preview rotation if enabled
    if Config.RotateVehicle then
        CreateThread(function()
            local heading = spawnPoint.heading
            
            while DoesEntityExist(previewVehicle) and isMenuOpen do
                if previewVehicle then
                    heading = heading + 0.1
                    SetEntityHeading(previewVehicle, heading)
                end
                Wait(10)
            end
        end)
    end
end)

-- Helper function to check if a spawn point is clear
function IsSpawnPointClear(coords, radius)
    local vehicles = GetNearbyVehicles(coords, radius)
    return #vehicles == 0
end

-- Helper function to find nearby vehicles
function FindNearbyVehicles()
    nearbyVehicles = {}
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local handle, vehicle = FindFirstVehicle()
    local success
    
    repeat
        if DoesEntityExist(vehicle) then
            local vehicleCoords = GetEntityCoords(vehicle)
            local distance = #(playerCoords - vehicleCoords)
            
            if distance <= 30.0 then
                table.insert(nearbyVehicles, vehicle)
            end
        end
        
        success, vehicle = FindNextVehicle(handle)
    until not success
    
    EndFindVehicle(handle)
    return nearbyVehicles
end

-- Helper function to get nearby vehicles at a specific position
function GetNearbyVehicles(coords, radius)
    local vehicles = {}
    
    for _, vehicle in ipairs(nearbyVehicles) do
        if DoesEntityExist(vehicle) then
            local vehicleCoords = GetEntityCoords(vehicle)
            local distance = #(coords - vehicleCoords)
            
            if distance <= radius then
                table.insert(vehicles, vehicle)
            end
        end
    end
    
    return vehicles
end

-- Helper function to get transferable garages
function GetTransferableGarages(currentType)
    local garages = {}
    
    for name, garage in pairs(Config.Garages) do
        -- Only include same type garages (public to public, job to job, etc.)
        if garage.type == currentType and currentType ~= "impound" then
            table.insert(garages, {
                id = name,
                label = garage.label
            })
        end
    end
    
    return garages
end

-- Display help text on screen
function DisplayHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Close the garage menu
function CloseGarageMenu()
    if not isMenuOpen then return end
    
    -- Hide UI
    SendNUIMessage({
        type = 'closeGarage'
    })
    
    -- Reset NUI focus
    SetNuiFocus(false, false)
    
    -- Clean up preview if exists
    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteVehicle(previewVehicle)
        previewVehicle = nil
    end
    
    -- Destroy camera if exists
    if DoesCamExist(cam) then
        SetCamActive(cam, false)
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cam, true)
        cam = nil
    end
    
    -- Reset menu state
    isMenuOpen = false
    TriggerScreenblurFadeOut(300)
    currentGarage = nil
end

-- Register key mapping for garage command if enabled
if Config.UseKeyMapping then
    RegisterKeyMapping('garage', _U('command_garage'), 'keyboard', Config.KeyMapping)
end

-- Register garage command
if Config.UseCommand then
    RegisterCommand('garage', function()
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        for garageName, garage in pairs(Config.Garages) do
            local distance = #(playerCoords - garage.menu_point.coords)
            
            if distance < garage.menu_point.radius then
                OpenGarageMenu(garageName)
                return
            end
            
            if IsPedInAnyVehicle(playerPed, false) then
                local parkingDistance = #(playerCoords - garage.parking_point.coords)
                if parkingDistance < garage.parking_point.radius then
                    StoreVehicle(garageName)
                    return
                end
            end
        end
    end, false)