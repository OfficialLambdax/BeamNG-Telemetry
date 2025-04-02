local M = {}

-- ----------------------------------------------------------------------------
-- Common functions
local function gameVehicleIDToServerVehicleID(game_vehicle_id)
	local server_vehicle_id = MPVehicleGE.getServerVehicleID(game_vehicle_id)
	if not server_vehicle_id or server_vehicle_id == -1 then return end
	return server_vehicle_id
end

-- ----------------------------------------------------------------------------
-- Readout Receiver from the vehicle VM's
M.sendReadout = function(game_vehicle_id, readout)
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
-- Init
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

return M
