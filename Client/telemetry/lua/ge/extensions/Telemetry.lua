local M = {}

local UI_UPDATE_TIMER = hptimer()
local DO_READOUT = false

-- ----------------------------------------------------------------------------
-- Common functions
local function gameVehicleIDToServerVehicleID(game_vehicle_id)
	local server_vehicle_id = MPVehicleGE.getServerVehicleID(game_vehicle_id)
	if not server_vehicle_id or server_vehicle_id == -1 then return end
	return server_vehicle_id
end

local function isMPSession()
	local is_mp_session = false
	if MPCoreNetwork then
		is_mp_session = MPCoreNetwork.isMPSession()
	end
	return is_mp_session
end

local function isOwn(game_vehicle_id)
	local is_own = true
	if isMPSession() then
		is_own = MPVehicleGE.isOwn(game_vehicle_id)
	end
	return is_own
end

-- ----------------------------------------------------------------------------
-- Readout Receiver from the vehicle VM's
M.sendReadout = function(game_vehicle_id, readout)
	if not DO_READOUT then return end
	--dump(readout)
	if MPVehicleGE and MPVehicleGE.isOwn(game_vehicle_id) then
		-- send to server
		TriggerServerEvent("telemetrySendReadout", jsonEncode({
			readout = readout,
			server_vehicle_id = gameVehicleIDToServerVehicleID(game_vehicle_id)
		}))
	end
end

M.hasReset = function(game_vehicle_id)
	if MPVehicleGE and MPVehicleGE.isOwn(game_vehicle_id) then
		-- send to server
		TriggerServerEvent("telemetrySendRestart", jsonEncode({
			server_vehicle_id = gameVehicleIDToServerVehicleID(game_vehicle_id)
		}))
	end
end

-- ----------------------------------------------------------------------------
-- Vehicle init
M.getInit = function(game_vehicle_id)
	getObjectByID(game_vehicle_id):queueLuaCommand(
		string.format('Telemetry.setInit(%s, %s, "%s")',
			DO_READOUT,
			isOwn(game_vehicle_id),
			beamng_version
		)
	)
end

-- ----------------------------------------------------------------------------
-- GE init
local function onInit()
	if core_levels.getLevelName(getMissionFilename()) == nil then return end
	if MPVehicleGE then
		-- init here what needs to be initialized
	end
end

-- ----------------------------------------------------------------------------
-- Game Events
M.onWorldReadyState = function(state)
	if state == 2 then
		onInit()
	end
end

M.onExtensionLoaded = function()
	onInit()
end

M.toggleReadout = function()
	DO_READOUT = not DO_READOUT
	
	for _, vehicle in ipairs(getAllVehicles()) do
		vehicle:queueLuaCommand(
			string.format('if Telemetry then Telemetry.setDoReadout(%s) end',
				DO_READOUT
			)
		)
	end
	
	local message = 'Telemetry '
	if DO_READOUT then
		message = message .. ' enabled'
	else
		message = message .. ' disabled'
	end
	
	guihooks.trigger('toastrMsg', {type = 'info', title = '', msg = message, config = {timeOut = 1000}})
end

M.onUpdate = function()
	if UI_UPDATE_TIMER:stop() < 1000 then return end
	UI_UPDATE_TIMER:stopAndReset()
	
	local message = '-> Telemetry '
	if DO_READOUT then
		message = message .. 'ENABLED\n'
	else
		message = message .. 'DISABLED\n'
	end
	
	if DO_READOUT then
		local tracked_vehicles = 0
		for _, vehicle in ipairs(getAllVehicles()) do
			if isOwn(vehicle:getId()) then tracked_vehicles = tracked_vehicles + 1 end
		end
		
		message = message .. 'Tracking ' .. tracked_vehicles .. ' vehicles\n\n'
		if isMPSession() then
			message = message .. 'Sending to Server'
		else
			message = message .. 'Saving locally (Not implemented)'
		end
	end
	
	guihooks.message({txt = message}, 2, "Telemetry")
end

return M
