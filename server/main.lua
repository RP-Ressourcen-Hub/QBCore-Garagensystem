-- Main server file for QBCore garage system
local QBCore = exports['qb-core']:GetCoreObject()

-- Initialize
CreateThread(function()
    -- Wait for Bridge to be ready
    while not Bridge do
        Wait(500)
    end
    
    -- Initialize database with required tables if not exists
    InitializeDatabase()
end)

-- Initialize the database
function InitializeDatabase()
    local success, result = pcall(function()
        -- Check if player_vehicles table has all needed columns
        local query = [[
            SELECT 1 
            FROM information_schema.columns 
            WHERE table_name = 'player_vehicles' 
            AND column_name = 'garage'
        ]]
        local hasGarageColumn = MySQL.Sync.fetchScalar(query) ~= nil
        
        if not hasGarageColumn then
            MySQL.Sync.execute([[
                ALTER TABLE player_vehicles 
                ADD COLUMN IF NOT EXISTS garage VARCHAR(50) DEFAULT 'legion_square',
                ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'stored',
                ADD COLUMN IF NOT EXISTS body FLOAT DEFAULT 1000.0,
                ADD COLUMN IF NOT EXISTS engine FLOAT DEFAULT 1000.0,
                ADD COLUMN IF NOT EXISTS fuel FLOAT DEFAULT 100.0,
                ADD COLUMN IF NOT EXISTS last_used TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ]])
            
            print("^2[QBCore Garage] Database schema updated successfully^7")
        end
    end)
    
    if not success then
        print("^1[QBCore Garage] Error initializing database: " .. tostring(result) .. "^7")
    end
end

-- Get all player vehicles
QBCore.Functions.CreateCallback('qb-garage:getPlayerVehicles', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        cb({})
        return
    end
    
    local cid = Player.PlayerData.citizenid
    local vehicles = {}
    
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE citizenid = @citizenid', {
        ['@citizenid'] = cid
    }, function(result)
        if result and #result > 0 then
            for _, vehicle in ipairs(result) do
                -- Convert mods string to table
                local properties = {}
                if vehicle.mods ~= nil then
                    properties = json.decode(vehicle.mods)
                end
                
                -- Get basic vehicle info
                local vehicleData = {
                    id = vehicle.id,
                    plate = vehicle.plate,
                    model = vehicle.vehicle,
                    citizenid = vehicle.citizenid,
                    garage = vehicle.garage or "legion_square",
                    status = vehicle.status or "stored",
                    fuel = vehicle.fuel or 100,
                    engine = vehicle.engine or 1000,
                    body = vehicle.body or 1000,
                    properties = properties,
                    type = GetVehicleTypeFromModel(vehicle.vehicle)
                }
                
                -- Get the display name
                vehicleData.name = GetVehicleDisplayName(vehicle.vehicle)
                
                -- Add to vehicles list
                table.insert(vehicles, vehicleData)
            end
        end
        
        cb(vehicles)
    end)
end)

-- Get vehicles stored in a specific garage
RegisterNetEvent('qb-garage:requestVehicles')
AddEventHandler('qb-garage:requestVehicles', function(garageName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local garage = Config.Garages[garageName]
    
    if not Player or not garage then
        return
    end
    
    local cid = Player.PlayerData.citizenid
    local vehicles = {}
    
    -- Query for the vehicles based on the garage type
    local query = ''
    local params = {}
    
    if garage.type == "impound" then
        -- Get impounded vehicles
        query = 'SELECT * FROM player_vehicles WHERE citizenid = @citizenid AND status = "impounded"'
        params = {
            ['@citizenid'] = cid
        }
    else
        -- Get vehicles in this garage or out
        query = 'SELECT * FROM player_vehicles WHERE citizenid = @citizenid AND (garage = @garage OR status = "out")'
        params = {
            ['@citizenid'] = cid,
            ['@garage'] = garageName
        }
        
        -- Handle job garage (show job vehicles)
        if garage.type == "job" and garage.allowed_jobs then
            local playerJob = Player.PlayerData.job
            
            if playerJob then
                for _, allowedJob in ipairs(garage.allowed_jobs) do
                    if playerJob.name == allowedJob then
                        -- Also include job vehicles
                        query = 'SELECT * FROM player_vehicles WHERE (citizenid = @citizenid AND (garage = @garage OR status = "out")) OR (job = @job AND garage = @garage)'
                        params['@job'] = playerJob.name
                        break
                    end
                end
            end
        end
        
        -- Handle gang garage (show gang vehicles)
        if garage.type == "gang" and garage.allowed_gangs then
            local playerGang = Player.PlayerData.gang
            
            if playerGang then
                for _, allowedGang in ipairs(garage.allowed_gangs) do
                    if playerGang.name == allowedGang then
                        -- Also include gang vehicles
                        query = 'SELECT * FROM player_vehicles WHERE (citizenid = @citizenid AND (garage = @garage OR status = "out")) OR (gang = @gang AND garage = @garage)'
                        params['@gang'] = playerGang.name
                        break
                    end
                end
            end
        end
    end
    
    MySQL.Async.fetchAll(query, params, function(result)
        if result and #result > 0 then
            for _, vehicle in ipairs(result) do
                -- Convert mods string to table
                local properties = {}
                if vehicle.mods ~= nil then
                    properties = json.decode(vehicle.mods)
                end
                
                -- Get basic vehicle info
                local vehicleData = {
                    id = vehicle.id,
                    plate = vehicle.plate,
                    model = vehicle.vehicle,
                    citizenid = vehicle.citizenid,
                    garage = vehicle.garage or "legion_square",
                    status = vehicle.status or "stored",
                    fuel = vehicle.fuel or 100,
                    engine = vehicle.engine or 1000,
                    body = vehicle.body or 1000,
                    properties = properties,
                    type = GetVehicleTypeFromModel(vehicle.vehicle)
                }
                
                -- Get the display name
                vehicleData.name = GetVehicleDisplayName(vehicle.vehicle)
                
                -- Add to vehicles list
                table.insert(vehicles, vehicleData)
            end
        end
        
        TriggerClientEvent('qb-garage:receiveVehicles', src, vehicles)
    end)
end)

-- Spawn a vehicle from the garage
RegisterNetEvent('qb-garage:requestVehicleSpawn')
AddEventHandler('qb-garage:requestVehicleSpawn', function(plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local cid = Player.PlayerData.citizenid
    
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = @plate AND (citizenid = @citizenid OR job = @job OR gang = @gang)', {
        ['@plate'] = plate,
        ['@citizenid'] = cid,
        ['@job'] = Player.PlayerData.job.name,
        ['@gang'] = Player.PlayerData.gang.name
    }, function(result)
        if result and #result > 0 then
            local vehicle = result[1]
            
            -- Check if vehicle is already out
            if vehicle.status == "out" then
                TriggerClientEvent('QBCore:Notify', src, _U('vehicle_already_out'), 'error')
                return
            end
            
            -- Check if vehicle is impounded
            if vehicle.status == "impounded" then
                TriggerClientEvent('QBCore:Notify', src, _U('vehicle_in_impound'), 'error')
                return
            }
            
            -- Update vehicle status to out
            MySQL.Async.execute('UPDATE player_vehicles SET status = @status, last_used = CURRENT_TIMESTAMP WHERE plate = @plate', {
                ['@status'] = 'out',
                ['@plate'] = plate
            })
            
            -- Convert mods string to table
            local properties = {}
            if vehicle.mods ~= nil then
                properties = json.decode(vehicle.mods)
            end
            
            -- Send vehicle data to client
            TriggerClientEvent('qb-garage:spawnVehicle', src, {
                model = vehicle.vehicle,
                plate = vehicle.plate,
                properties = properties,
                bodyHealth = vehicle.body,
                engineHealth = vehicle.engine,
                fuelLevel = vehicle.fuel
            })
            
            -- Generate logging information
            local vehicleName = GetVehicleDisplayName(vehicle.vehicle)
            
            -- Log the event
            TriggerEvent('qb-log:server:CreateLog', 'garage', 'Vehicle Retrieved', 'green', string.format('%s (CitizenID: %s) retrieved %s (%s) from garage %s', 
                GetPlayerName(src), cid, vehicleName, plate, vehicle.garage))
        else
            TriggerClientEvent('QBCore:Notify', src, _U('not_owner'), 'error')
        end
    end)
end)

-- Store a vehicle in the garage
RegisterNetEvent('qb-garage:storeVehicle')
AddEventHandler('qb-garage:storeVehicle', function(garageName, vehicleProps, vehicleState)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local garage = Config.Garages[garageName]
    
    if not Player or not garage then return end
    
    local plate = vehicleProps.plate
    
    -- Check for player ownership
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = @plate', {
        ['@plate'] = plate
    }, function(result)
        if result and #result > 0 then
            local vehicle = result[1]
            local cid = Player.PlayerData.citizenid
            local isOwner = vehicle.citizenid == cid
            local playerJob = Player.PlayerData.job.name
            local playerGang = Player.PlayerData.gang.name
            local isJobVehicle = playerJob == vehicle.job
            local isGangVehicle = playerGang == vehicle.gang
            
            -- Verify ownership or permissions
            if not isOwner and not isJobVehicle and not isGangVehicle then
                TriggerClientEvent('QBCore:Notify', src, _U('not_owner'), 'error')
                return
            end
            
            -- Update vehicle information
            local updateData = {
                ['@garage'] = garageName,
                ['@status'] = 'stored',
                ['@plate'] = plate
            }
            
            -- Update vehicle state if enabled
            if Config.SaveVehicleDamage then
                updateData['@body'] = vehicleState.bodyHealth
                updateData['@engine'] = vehicleState.engineHealth
            end
            
            if Config.SaveVehicleFuel then
                updateData['@fuel'] = vehicleState.fuelLevel
            end
            
            -- Build update query based on configuration
            local updateQuery = 'UPDATE player_vehicles SET garage = @garage, status = @status'
            
            if Config.SaveVehicleDamage then
                updateQuery = updateQuery .. ', body = @body, engine = @engine'
            end
            
            if Config.SaveVehicleFuel then
                updateQuery = updateQuery .. ', fuel = @fuel'
            end
            
            -- Add mods update if needed
            updateQuery = updateQuery .. ', mods = @mods WHERE plate = @plate'
            updateData['@mods'] = json.encode(vehicleProps)
            
            -- Execute the update
            MySQL.Async.execute(updateQuery, updateData, function(rowsChanged)
                if rowsChanged > 0 then
                    TriggerClientEvent('QBCore:Notify', src, _U('vehicle_stored'), 'success')
                    
                    -- Log the event
                    local vehicleName = GetVehicleDisplayName(vehicle.vehicle)
                    TriggerEvent('qb-log:server:CreateLog', 'garage', 'Vehicle Stored', 'green', string.format('%s (CitizenID: %s) stored %s (%s) in garage %s', 
                        GetPlayerName(src), cid, vehicleName, plate, garageName))
                else
                    TriggerClientEvent('QBCore:Notify', src, _U('error_db'), 'error')
                end
            end)
        else
            TriggerClientEvent('QBCore:Notify', src, _U('must_own_vehicle'), 'error')
        end
    end)
end)

-- Transfer a vehicle to another garage
RegisterNetEvent('qb-garage:transferVehicle')
AddEventHandler('qb-garage:transferVehicle', function(plate, targetGarage)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not Config.AllowVehicleTransfer then return end
    
    local targetGarageConfig = Config.Garages[targetGarage]
    if not targetGarageConfig then
        TriggerClientEvent('QBCore:Notify', src, _U('error_transfer'), 'error')
        return
    end
    
    -- Check for player ownership
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = @plate AND citizenid = @citizenid', {
        ['@plate'] = plate,
        ['@citizenid'] = Player.PlayerData.citizenid
    }, function(result)
        if result and #result > 0 then
            local vehicle = result[1]
            
            -- Check if vehicle is stored
            if vehicle.status ~= "stored" then
                TriggerClientEntry('QBCore:Notify', src, _U('vehicle_already_out'), 'error')
                return
            end
            
            -- Check if player has enough money for transfer fee
            if Config.TransferFee > 0 then
                local playerMoney = Player.PlayerData.money['bank']
                
                if playerMoney < Config.TransferFee then
                    TriggerClientEntry('QBCore:Notify', src, _U('not_enough_money'), 'error')
                    return
                end
                
                -- Charge the transfer fee
                Player.Functions.RemoveMoney('bank', Config.TransferFee, "vehicle-transfer-fee")
                TriggerClientEntry('QBCore:Notify', src, string.format(_U('notify_transfer_fee'), Config.TransferFee), 'info')
            end
            
            -- Update the garage location
            MySQL.Async.execute('UPDATE player_vehicles SET garage = @garage WHERE plate = @plate', {
                ['@garage'] = targetGarage,
                ['@plate'] = plate
            }, function(rowsChanged)
                if rowsChanged > 0 then
                    -- Success notification
                    TriggerClientEntry('QBCore:Notify', src, string.format(_U('notify_vehicle_transferred'), targetGarageConfig.label), 'success')
                    
                    -- Log the event
                    local vehicleName = GetVehicleDisplayName(vehicle.vehicle)
                    TriggerEvent('qb-log:server:CreateLog', 'garage', 'Vehicle Transferred', 'green', string.format('%s (CitizenID: %s) transferred %s (%s) from %s to %s', 
                        GetPlayerName(src), Player.PlayerData.citizenid, vehicleName, plate, vehicle.garage, targetGarage))
                else
                    TriggerClientEntry('QBCore:Notify', src, _U('error_transfer'), 'error')
                end
            end)
        else
            TriggerClientEntry('QBCore:Notify', src, _U('not_owner'), 'error')
        end
    end)
end)

-- Release a vehicle from impound
RegisterNetEvent('qb-garage:releaseVehicle')
AddEventHandler('qb-garage:releaseVehicle', function(plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not Config.EnableImpound then return end
    
    -- Check for player ownership
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = @plate AND citizenid = @citizenid', {
        ['@plate'] = plate,
        ['@citizenid'] = Player.PlayerData.citizenid
    }, function(result)
        if result and #result > 0 then
            local vehicle = result[1]
            
            -- Check if vehicle is actually impounded
            if vehicle.status ~= "impounded" then
                TriggerClientEntry('QBCore:Notify', src, _U('vehicle_not_impounded'), 'error')
                return
            end
            
            -- Check if player has enough money for impound fee
            if Config.ImpoundFee > 0 then
                local playerMoney = Player.PlayerData.money['bank']
                
                if playerMoney < Config.ImpoundFee then
                    TriggerClientEntry('QBCore:Notify', src, _U('not_enough_money'), 'error')
                    return
                end
                
                -- Charge the impound fee
                Player.Functions.RemoveMoney('bank', Config.ImpoundFee, "vehicle-impound-fee")
                TriggerClientEntry('QBCore:Notify', src, string.format(_U('notify_impound_fee'), Config.ImpoundFee), 'info')
            end
            
            -- Update the vehicle status to stored and move to current garage
            MySQL.Async.execute('UPDATE player_vehicles SET status = @status, garage = @garage WHERE plate = @plate', {
                ['@status'] = 'stored',
                ['@garage'] = 'legion_square', -- Default garage
                ['@plate'] = plate
            }, function(rowsChanged)
                if rowsChanged > 0 then
                    -- Success notification
                    TriggerClientEntry('QBCore:Notify', src, _U('notify_vehicle_released'), 'success')
                    
                    -- Log the event
                    local vehicleName = GetVehicleDisplayName(vehicle.vehicle)
                    TriggerEvent('qb-log:server:CreateLog', 'garage', 'Vehicle Released', 'green', string.format('%s (CitizenID: %s) released %s (%s) from impound', 
                        GetPlayerName(src), Player.PlayerData.citizenid, vehicleName, plate))
                else
                    TriggerClientEntry('QBCore:Notify', src, _U('error_release'), 'error')
                end
            end)
        else
            TriggerClientEntry('QBCore:Notify', src, _U('not_owner'), 'error')
        end
    end)
end)

-- Preview a vehicle before spawning
RegisterNetEvent('qb-garage:requestVehiclePreview')
AddEventHandler('qb-garage:requestVehiclePreview', function(plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local cid = Player.PlayerData.citizenid
    
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = @plate AND (citizenid = @citizenid OR job = @job OR gang = @gang)', {
        ['@plate'] = plate,
        ['@citizenid'] = cid,
        ['@job'] = Player.PlayerData.job.name,
        ['@gang'] = Player.PlayerData.gang.name
    }, function(result)
        if result and #result > 0 then
            local vehicle = result[1]
            
            -- Convert mods string to table
            local properties = {}
            if vehicle.mods ~= nil then
                properties = json.decode(vehicle.mods)
            end
            
            -- Send vehicle data to client for preview
            TriggerClientEvent('qb-garage:previewVehicle', src, {
                model = vehicle.vehicle,
                plate = vehicle.plate,
                properties = properties
            })
        end
    end)
end)

-- Set vehicle as owned (for newly purchased vehicles)
RegisterNetEvent('qb-garage:setVehicleOwned')
AddEventHandler('qb-garage:setVehicleOwned', function(vehicleProps)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not vehicleProps then return end
    
    local cid = Player.PlayerData.citizenid
    local plate = vehicleProps.plate
    
    -- Check if vehicle with this plate already exists
    MySQL.Async.fetchScalar('SELECT 1 FROM player_vehicles WHERE plate = @plate', {
        ['@plate'] = plate
    }, function(exists)
        if exists then
            TriggerClientEntry('QBCore:Notify', src, _U('error_vehicle_exists'), 'error')
            return
        end
        
        -- Check if player has reached the maximum number of vehicles
        if Config.MaxVehiclesPerPlayer > 0 then
            MySQL.Async.fetchScalar('SELECT COUNT(*) FROM player_vehicles WHERE citizenid = @citizenid', {
                ['@citizenid'] = cid
            }, function(count)
                if count >= Config.MaxVehiclesPerPlayer then
                    TriggerClientEntry('QBCore:Notify', src, _U('error_max_vehicles'), 'error')
                    return
                end
                
                InsertVehicle(src, Player, vehicleProps)
            end)
        else
            InsertVehicle(src, Player, vehicleProps)
        end
    end)
end)

-- Helper function to insert a vehicle into the database
function InsertVehicle(src, Player, vehicleProps)
    local cid = Player.PlayerData.citizenid
    local plate = vehicleProps.plate
    local model = vehicleProps.model
    local vehType = GetVehicleTypeFromModel(model)
    
    -- Insert the vehicle
    MySQL.Async.execute('INSERT INTO player_vehicles (citizenid, plate, vehicle, hash, mods, garage, status) VALUES (@citizenid, @plate, @vehicle, @hash, @mods, @garage, @status)', {
        ['@citizenid'] = cid,
        ['@plate'] = plate,
        ['@vehicle'] = model,
        ['@hash'] = GetHashKey(model),
        ['@mods'] = json.encode(vehicleProps),
        ['@garage'] = 'legion_square', -- Default garage
        ['@status'] = 'out' -- Vehicle is out when purchased
    }, function(rowsChanged)
        if rowsChanged > 0 then
            TriggerClientEntry('QBCore:Notify', src, _U('vehicle_owned'), 'success')
            
            -- Add vehicle keys if using car keys system
            if Config.UseCarKeys then
                TriggerClientEvent('qb-vehiclekeys:client:AddKeys', src, plate)
            end
            
            -- Log the event
            local vehicleName = GetVehicleDisplayName(model)
            TriggerEvent('qb-log:server:CreateLog', 'garage', 'Vehicle Purchased', 'green', string.format('%s (CitizenID: %s) purchased a new %s with plate %s', 
                GetPlayerName(src), cid, vehicleName, plate))
        else
            TriggerClientEntry('QBCore:Notify', src, _U('error_db'), 'error')
        end
    end)
end

-- Get job vehicles
QBCore.Functions.CreateCallback('qb-garage:getJobVehicles', function(source, cb, job)
    if not job then
        cb({})
        return
    end
    
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE job = @job', {
        ['@job'] = job
    }, function(result)
        local vehicles = {}
        
        if result and #result > 0 then
            for _, vehicle in ipairs(result) do
                -- Convert mods string to table
                local properties = {}
                if vehicle.mods ~= nil then
                    properties = json.decode(vehicle.mods)
                end
                
                -- Get basic vehicle info
                local vehicleData = {
                    id = vehicle.id,
                    plate = vehicle.plate,
                    model = vehicle.vehicle,
                    citizenid = vehicle.citizenid,
                    garage = vehicle.garage or "legion_square",
                    status = vehicle.status or "stored",
                    fuel = vehicle.fuel or 100,
                    engine = vehicle.engine or 1000,
                    body = vehicle.body or 1000,
                    properties = properties,
                    type = GetVehicleTypeFromModel(vehicle.vehicle),
                    job = vehicle.job
                }
                
                -- Get the display name
                vehicleData.name = GetVehicleDisplayName(vehicle.vehicle)
                
                -- Add to vehicles list
                table.insert(vehicles, vehicleData)
            end
        end
        
        cb(vehicles)
    end)
end)

-- Impound a vehicle (for police)
RegisterNetEvent('qb-garage:impoundVehicle')
AddEventHandler('qb-garage:impoundVehicle', function(plate, vehicleProps)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player is police
    if Player.PlayerData.job.name ~= 'police' then
        TriggerClientEntry('QBCore:Notify', src, _U('not_authorized'), 'error')
        return
    end
    
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = @plate', {
        ['@plate'] = plate
    }, function(result)
        if result and #result > 0 then
            local vehicle = result[1]
            
            -- Update the vehicle status to impounded
            MySQL.Async.execute('UPDATE player_vehicles SET status = @status WHERE plate = @plate', {
                ['@status'] = 'impounded',
                ['@plate'] = plate
            }, function(rowsChanged)
                if rowsChanged > 0 then
                    TriggerClientEntry('QBCore:Notify', src, _U('vehicle_impounded'), 'success')
                    
                    -- Log the event
                    local vehicleName = GetVehicleDisplayName(vehicle.vehicle)
                    TriggerEvent('qb-log:server:CreateLog', 'garage', 'Vehicle Impounded', 'red', string.format('%s (CitizenID: %s) impounded a %s with plate %s', 
                        GetPlayerName(src), Player.PlayerData.citizenid, vehicleName, plate))
                else
                    TriggerClientEntry('QBCore:Notify', src, _U('error_db'), 'error')
                end
            end)
        else
            -- Vehicle not found in database, add it
            if vehicleProps then
                local model = vehicleProps.model
                local vehType = GetVehicleTypeFromModel(model)
                
                -- Insert the vehicle as an impounded vehicle
                MySQL.Async.execute('INSERT INTO player_vehicles (citizenid, plate, vehicle, hash, mods, garage, status) VALUES (@citizenid, @plate, @vehicle, @hash, @mods, @garage, @status)', {
                    ['@citizenid'] = 'unknown', -- Unknown owner
                    ['@plate'] = plate,
                    ['@vehicle'] = model,
                    ['@hash'] = GetHashKey(model),
                    ['@mods'] = json.encode(vehicleProps),
                    ['@garage'] = 'legion_square', -- Default garage
                    ['@status'] = 'impounded' -- Impounded status
                }, function(rowsChanged)
                    if rowsChanged > 0 then
                        TriggerClientEntry('QBCore:Notify', src, _U('vehicle_impounded'), 'success')
                        
                        -- Log the event
                        local vehicleName = GetVehicleDisplayName(model)
                        TriggerEvent('qb-log:server:CreateLog', 'garage', 'Vehicle Impounded', 'red', string.format('%s (CitizenID: %s) impounded an unknown %s with plate %s', 
                            GetPlayerName(src), Player.PlayerData.citizenid, vehicleName, plate))
                    else
                        TriggerClientEntry('QBCore:Notify', src, _U('error_db'), 'error')
                    end
                end)
            else
                TriggerClientEntry('QBCore:Notify', src, _U('vehicle_not_found'), 'error')
            end
        end
    end)
end)

-- Helper function to get vehicle display name from model
function GetVehicleDisplayName(model)
    local displayName = "Unknown"
    
    for _, vehicle in pairs(QBCore.Shared.Vehicles) do
        if vehicle.model == model then
            displayName = vehicle.name
            break
        end
    end
    
    return displayName
end

-- Helper function to get vehicle type from model
function GetVehicleTypeFromModel(model)
    local vehicleType = "car"
    
    for _, vehicle in pairs(QBCore.Shared.Vehicles) do
        if vehicle.model == model then
            if vehicle.category then
                if vehicle.category == "motorcycles" then
                    vehicleType = "bike"
                elseif vehicle.category == "cycles" then
                    vehicleType = "bicycle"
                elseif vehicle.category == "boats" then
                    vehicleType = "boat"
                elseif vehicle.category == "helicopters" then
                    vehicleType = "helicopter"
                elseif vehicle.category == "planes" then
                    vehicleType = "plane"
                end
            end
            break
        end
    end
    
    return vehicleType
end