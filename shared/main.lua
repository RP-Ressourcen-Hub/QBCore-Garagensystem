-- Shared functions for garage system

-- Function to get localized text
function _U(str)
    if not Locales[Config.Locale] then
        return 'Locale error: ' .. Config.Locale .. ' does not exist'
    end
    
    if not Locales[Config.Locale][str] then
        return 'Locale error: string ' .. str .. ' does not exist'
    end
    
    return Locales[Config.Locale][str]
end

-- Function to get vehicle display name from model
function GetVehicleDisplayName(model)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local name = GetLabelText(displayName)
    if name == 'NULL' then
        name = displayName
    end
    return name
end

-- Function to get vehicle class name from class ID
function GetVehicleClassName(classId)
    local classes = {
        [0] = "compacts",
        [1] = "sedans",
        [2] = "suvs",
        [3] = "coupes",
        [4] = "muscle",
        [5] = "sportsclassics",
        [6] = "sports",
        [7] = "super",
        [8] = "motorcycles",
        [9] = "offroad",
        [10] = "industrial",
        [11] = "utility",
        [12] = "vans",
        [13] = "cycles",
        [14] = "boats",
        [15] = "helicopters",
        [16] = "planes",
        [17] = "service",
        [18] = "emergency",
        [19] = "military",
        [20] = "commercial",
        [21] = "trains"
    }
    
    return classes[classId] or "unknown"
end

-- Function to get vehicle type from model
function GetVehicleType(model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then return nil end
    
    local vehicleType = "car"
    
    if IsThisModelACar(hash) then
        vehicleType = "car"
    elseif IsThisModelABike(hash) or IsThisModelABicycle(hash) then
        vehicleType = IsThisModelABicycle(hash) and "bicycle" or "bike"
    elseif IsThisModelABoat(hash) then
        vehicleType = "boat"
    elseif IsThisModelAHeli(hash) then
        vehicleType = "helicopter"
    elseif IsThisModelAPlane(hash) then
        vehicleType = "plane"
    elseif IsThisModelAnEmergencyBoat(hash) then
        vehicleType = "boat"
    end
    
    return vehicleType
end

-- Function to format vehicle data for UI
function FormatVehicleData(vehicle)
    if not vehicle then return nil end
    
    local formattedData = {
        id = vehicle.id or vehicle.plate,
        plate = vehicle.plate,
        model = vehicle.model,
        name = vehicle.name or GetVehicleDisplayName(vehicle.model),
        type = vehicle.type or GetVehicleType(vehicle.model),
        class = vehicle.class or "unknown",
        status = vehicle.status or "stored",
        garage = vehicle.garage or "unknown",
        fuel = vehicle.fuel or 100,
        body = vehicle.body or 1000,
        engine = vehicle.engine or 1000,
        stats = {
            speed = vehicle.stats and vehicle.stats.speed or 0,
            acceleration = vehicle.stats and vehicle.stats.acceleration or 0,
            braking = vehicle.stats and vehicle.stats.braking or 0,
            handling = vehicle.stats and vehicle.stats.handling or 0
        },
        lastUsed = vehicle.lastUsed or 0,
        stored = vehicle.status == "stored",
        impounded = vehicle.status == "impounded",
        out = vehicle.status == "out"
    }
    
    -- Get category based on class
    if Config.VehicleCategories[formattedData.class] then
        formattedData.category = formattedData.class
    else
        formattedData.category = "unknown"
    end
    
    -- Get status color
    if Config.VehicleStatuses[formattedData.status] then
        formattedData.statusColor = Config.VehicleStatuses[formattedData.status].color
        formattedData.statusLabel = Config.VehicleStatuses[formattedData.status].label
    else
        formattedData.statusColor = "#777777"
        formattedData.statusLabel = formattedData.status
    end
    
    return formattedData
end

-- Function to check if vehicle type is allowed in garage
function IsVehicleTypeAllowedInGarage(vehicleType, garage)
    if not garage.allowed_vehicles or #garage.allowed_vehicles == 0 then
        return true -- If no restrictions, all vehicles are allowed
    end
    
    for _, allowedType in ipairs(garage.allowed_vehicles) do
        if allowedType == vehicleType then
            return true
        end
    end
    
    return false
end

-- Function to check job/gang restrictions
function CanAccessGarage(garage, playerJob, playerGang)
    -- Public garages are accessible to everyone
    if garage.type == "public" then
        return true
    end
    
    -- Job garages check
    if garage.type == "job" then
        if not garage.allowed_jobs or #garage.allowed_jobs == 0 then
            return true
        end
        
        if not playerJob then
            return false
        end
        
        for _, allowedJob in ipairs(garage.allowed_jobs) do
            if allowedJob == playerJob.name then
                return true
            end
        end
    end
    
    -- Gang garages check
    if garage.type == "gang" then
        if not garage.allowed_gangs or #garage.allowed_gangs == 0 then
            return true
        end
        
        if not playerGang then
            return false
        end
        
        for _, allowedGang in ipairs(garage.allowed_gangs) do
            if allowedGang == playerGang.name then
                return true
            end
        end
    end
    
    return false
end