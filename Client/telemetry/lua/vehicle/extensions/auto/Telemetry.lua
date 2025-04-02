package.loaded["libs/GroundModels"] = nil
local GroundModels = require("libs/GroundModels")

local M = {}

--[[
	General notes
	- Everything that says that the data will be int or float, can be either. Because in lua every number is a float but the final json encoder WILL encode floats as integers if the fractionals are 0.
]]

local _VERSION = 0.1 -- version of the script
--[[
	Version of the data format. helps you to align the parser to the correct data format.
	This version will change if
		- the data structure is changed
		- data points are added or removed
		- data points are altered in their unit or data type
	
	This version will NOT change if
		- a data point is corrected (when a bug caused it to throw invalid data)
]]
local _DATA_VERSION = 1

-- ----------------------------------------------------------------------------
-- Settings
-- Leave this at 0 to fetch data every frame
local FETCH_EVERY = 0 -- ms


-- ----------------------------------
-- Internal
local FETCH_TIMER = HighPerfTimer()
local LIFE_TIMER = HighPerfTimer()
local INITIALIZED = false

-- ----------------------------------
-- Measurement variables
local LAST_VEL = 0


-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- Common functions
local function getSurfaceHeight(pos_vec)
	local surface_z = obj:getSurfaceHeightBelow(vec3(pos_vec.x, pos_vec.y, pos_vec.z + 2))
	if surface_z < -1e10 then return end -- "the function returns -1e20 when the raycast fails"
	return surface_z
end

local function getAltitude(pos_vec, relative_z) -- relative to the given, eg. relative to surface_z or to sea level
	return pos_vec.z - (relative_z or 0)
end

local function getHeading(dir_vec)
	local angle = math.atan2(dir_vec.x, dir_vec.y)
	local degrees = 180 * angle / math.pi
	return (360 + degrees) % 360
end

local function intToBool(int)
	if int and int > 0 then return true end
	return false
end

-- ----------------------------------------------------------------------------
-- Data collect
local function collectConfig()
	return {
		jbm = v.config.mainPartName, -- string
		config = v.config.partConfigFilename, -- string
		id = obj:getId(), -- int
	}
end

local function collectGeneral()
	return {
		pos = obj:getPosition(), -- vec3 (meters)
		rot = obj:getRotation(), -- quat
		dir = obj:getDirectionVector(), -- vec3
		dirUp = obj:getDirectionVectorUp(), -- vec3
		vel = obj:getVelocity(), -- vec3 (meter/s)
		accel = obj:getVelocity():length() - LAST_VEL, -- float (meter/s)
		altToMsl = getAltitude(obj:getPosition()), -- float (meters)
		altToSurface = getAltitude(obj:getPosition(), getSurfaceHeight(obj:getPosition())), -- float (meters)
		
		--[[
		       360/0
		        +y
		         |
		   270   |    90
		   -x----x----x+
		         |
		         |
				-y
				180
		]]
		heading = math.floor(getHeading(obj:getDirectionVector())), -- int
	}
end

local function collectElectrics()
	--[[
		Not all electric values are always present on every vehicle and config. This is highly dependant on the vehicle, their controllers and settings.
		
		As such each variable is assigned default data so to never leave holes in the data.
	]]
	local vars = electrics.values
	return {
		odometer = vars.odometer or 0, -- float (meters)
		
		-- True on the vehicles signaling intention not if the lights are actually active
		signalRightActive = intToBool(vars.signal_right_input), -- bool
		signalLeftActive = intToBool(vars.signal_left_input), -- bool
		signalHazardActive = intToBool(vars.hazard_enabled), -- bool
		signalReverseActive = intToBool(vars.reverse), -- bool
		
		-- True when the vehicle has this system, unrelated to if its active or acting
		hasAbs = intToBool(vars.hasABS), -- bool
		hasEsc = intToBool(vars.hasESC), -- bool
		hasTcs = intToBool(vars.hasTCS), -- bool
		
		-- True when the systems are acting.
		-- Eg vehicle does a full brake and abs kicks in, then absActive == true.
		absActive = intToBool(vars.absActive), -- bool
		escActive = vars.escActive or false, -- bool
		tcsActive = vars.tcsActive or false, -- bool
		
		-- True when the system is enabled
		twoStepEnabled = vars.twoStep or false, -- bool
	}
end

local function collectInputs()
	return {
		brake = input.brake, -- float
		clutch = input.clutch, -- float
		parkingBrake = input.parkingbrake, -- float
		steering = input.steering, -- float
		throttle = input.throttle, -- float
	}
end

local function collectWheels()
	local extract = {}
	for _, wheel in pairs(wheels.wheels) do
		local groundmodel = GroundModels.getGroundModelById(wheel.contactMaterialID1)
		if groundmodel then
			groundmodel = groundmodel:getName()
		else
			groundmodel = ''
		end
		extract[wheel.name] = {
			hasTire = wheel.hasTire, -- bool
			hubRadius = wheel.hubRadius, -- float (meters)
			radius = wheel.radius, -- float (meters)
			isBroken = wheel.isBroken, -- float
			isDeflated = wheel.isTireDeflated, -- bool
			slip = wheel.lastSlip, -- float
			slipEnergy = wheel.slipEnergy, -- float (joules?)
			treadCoef = wheel.treadCoef, -- float (0 = slick, 1 = offroad)
			wheelSpeed = wheel.wheelSpeed, -- float (meter/s)
			
			angularVelocity = wheel.angularVelocity, -- float (meter/s)
			contactMaterialID = wheel.contactMaterialID1, -- int (-1 means none)
			contactMaterial = groundmodel, -- string
			downForce = wheel.downForceRaw, -- float (newton)
			
			brake = {
				absActive = wheel.absActive or false, -- bool
				absFrequency = wheel.absFrequency or 0, -- int (milliseconds)
				
				brakeType = wheel.brakeType, -- string
				brakeMaterial = wheel.padMaterial, -- string
				brakeCoolingArea = wheel.brakeCoolingArea, -- float (m²?)
				brakeDiameter = wheel.brakeDiameter, -- float (meter)
				brakeMeltingPoint = wheel.brakeMeltingPoint, -- float (celcius)
				brakeSpecHeat = wheel.brakeSpecHeat, -- float (celcius)
				brakeThermalEfficiency = wheel.brakeThermalEfficiency, -- float
				brakeTorque = wheel.brakeTorque, -- int (max)
				brakingTorque = wheel.brakingTorque, -- float (actual)
				
				brakeCoreEnergyCoef = wheel.brakeCoreEnergyCoef, -- float
				brakeCoreTemperature = wheel.brakeCoreTemperature, -- float (celcius)
				
				brakeSurfaceEnergyCoef = wheel.brakeSurfaceEnergyCoef, -- float
				brakeSurfaceTemperature = wheel.brakeSurfaceTemperature, -- float (celcius)
				
			},
		}
	end
	return extract
end

local function collectSuspension()
	return {
	
	}
end

local function collectEngine()
	return {
	
	}
end

local function collectTransmission()
	return {
	
	}
end

local function collectEnergy()
	--[[
		This will catch gasoline, diesel, n2o, air pressure tanks and electric batteries
	]]
	local storages = {}
	for name, storage in pairs(energyStorage.getStorages()) do
		storages[name] = {
			energyType = storage.energyType or '', -- string
			
			fluidCapacity = storage.capacity or 0, -- float
			remainingFluidCapacity = storage.remainingVolume or 0, -- float
			leakRate = storage.currentLeakRate or 0, -- float
			
			energyCapacity = storage.energyCapacity or 0, -- float (joules?)
			remainingEnergyCapacity = storage.storedEnergy or 0, -- float (joules?)
			energyDensity = storage.energyDensity or 0, -- float (?)
		}
	end
	return storages
end

-- ----------------------------------------------------------------------------
-- Init
local function tryInit(life_time)
	if life_time < 1000 then
		return
	else
		if v.mpVehicleType == "R" then -- we only want to consider vehicles owned by this client
			extensions.unload("Telemetry")
		end
	end
	
	GroundModels.init()
	INITIALIZED = true
end

-- ----------------------------------------------------------------------------
-- Game Events
M.onReset = function()
	LIFE_TIMER:stopAndReset()
	FETCH_TIMER:stopAndReset()
	obj:queueGameEngineLua(
		string.format('Telemetry.hasReset(%d)',
			obj:getId()
		)
	)
end

M.updateGFX = function()
	local life_time = LIFE_TIMER:stop()
	if not INITIALIZED then return tryInit(life_time) end
	if life_time < 100 then return end -- readouts directly after a reset are error prone
	
	if FETCH_EVERY > 0 then
		if FETCH_EVERY < FETCH_TIMER:stop() then return end
		FETCH_TIMER:stopAndReset()
	end
	
	-- Read out all data
	local readout = {
		_VERSION = _DATA_VERSION, -- int
		time = math.floor(life_time), -- int (milliseconds)
		config = collectConfig(),
		general = collectGeneral(),
		electrics = collectElectrics(),
		inputs = collectInputs(),
		wheels = collectWheels(),
		energy = collectEnergy(),
		--suspension = collectSuspension(),
		--engine = collectEngine(),
		--transmission = collectTransmission(),
	}
	
	-- Save variables we need for the next readout
	LAST_VEL = obj:getVelocity():length()
	
	-- Send the readout to the general environment
	obj:queueGameEngineLua(
		string.format('Telemetry.sendReadout(%d,%s)',
			obj:getId(),
			serialize(readout)
		)
	)
end

return M
