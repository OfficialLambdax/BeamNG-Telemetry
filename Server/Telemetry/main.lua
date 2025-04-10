
local READOUT_PATH = "readouts"


local PLAYERS = {}

-- ------------------------------------------------------------------------------------------------
-- Common functions
local function getPlayerIDFromServerID(server_vehicle_id)
	local _, pos = server_vehicle_id:find('-')
	if pos == nil then return end
	
	return tonumber(server_vehicle_id:sub(1, pos - 1))
end

local function stringSplit(string, delimeter, convert_into)
	local t = {}
	for str in string.gmatch(string, "([^"..delimeter.."]+)") do
		if convert_into == 1 then -- number
			table.insert(t, tonumber(str))
			
		elseif convert_into == 2 then -- bool
			if str:lower() == "false" then
				table.insert(t, false)
			elseif str:lower() == "true" then
				table.insert(t, false)
			end
			
		else -- string
			table.insert(t, str)
		end
	end
	return t
end

local function verifyInputData(player_id, data)
	local data = Util.JsonDecode(data)
	local check_id, vehicle_id = table.unpack(stringSplit(data.server_vehicle_id, '-', 1))
	if check_id ~= player_id then return end
	
	if not PLAYERS[player_id] then return end
	if not (MP.GetPlayerVehicles(player_id) or {})[vehicle_id] then return end
	return vehicle_id, data
end

local function vehicleDataTrim(vehicleData)
	local start = string.find(vehicleData, "{")
	return string.sub(vehicleData, start, -1)
end

-- ------------------------------------------------------------------------------------------------
-- Players
local function newPlayer(player_id)
	PLAYERS[player_id] = {
		handles = {} -- veh_id = handle
	}
end

local function removePlayer(player_id)
	for _, handle in pairs(PLAYERS[player_id].handles or {}) do
		handle:close()
	end
	PLAYERS[player_id] = nil
end

-- ------------------------------------------------------------------------------------------------
-- Readouts
local function newReadout(player_id, vehicle_id)
	local jbm = Util.JsonDecode(
		vehicleDataTrim(
			MP.GetPlayerVehicles(player_id)[vehicle_id]
		)
	).jbm
	
	local file_name = os.date("%Y.%m.%d %H-%M-%S") .. '_' .. jbm .. '_' .. vehicle_id .. '.dat'
	local handle = io.open(READOUT_PATH .. '/' .. file_name, "w")
	if handle == nil then
		print('Failed to create new readout file at "' .. READOUT_PATH .. '/' .. file_name .. '"')
		return
	end
	
	print('Started new Readout for ' .. player_id .. '-' .. vehicle_id)
	PLAYERS[player_id].handles[vehicle_id] = handle
end

local function writeReadout(player_id, vehicle_id, readout)
	local handle = PLAYERS[player_id].handles[vehicle_id]
	if handle == nil then return end
	
	handle:write(Util.JsonEncode(readout) .. '\n')
end

function handleReadout(player_id, data)
	local vehicle_id, data = verifyInputData(player_id, data)
	if vehicle_id == nil then return end
	
	local handle = PLAYERS[player_id].handles[vehicle_id]
	if handle == nil then
		newReadout(player_id, vehicle_id)
	end
	
	writeReadout(player_id, vehicle_id, data.readout)
end

function handleRestart(player_id, data)
	local vehicle_id, data = verifyInputData(player_id, data)
	if vehicle_id == nil then return end
	
	local handle = PLAYERS[player_id].handles[vehicle_id]
	if handle then
		handle:close()
		PLAYERS[player_id].handles[vehicle_id] = nil
	end
end

-- ------------------------------------------------------------------------------------------------
-- MP Events
function onPlayerJoin(player_id)
	newPlayer(player_id)
end

function onPlayerDisconnect(player_id)
	removePlayer(player_id)
end

function onVehicleSpawn(player_id, vehicle_id, data)

end

function onVehicleDeleted(player_id, vehicle_id)

end

function onInit()
	if not FS.IsDirectory(READOUT_PATH) then
		FS.CreateDirectory(READOUT_PATH)
	end
	
	-- custom events
	MP.RegisterEvent("telemetrySendReadout", "handleReadout")
	MP.RegisterEvent("telemetrySendRestart", "handleRestart")
	
	-- server events
	MP.RegisterEvent("onPlayerJoin", "onPlayerJoin")
	MP.RegisterEvent("onPlayerDisconnect", "onPlayerDisconnect")
	MP.RegisterEvent("onVehicleSpawn", "onVehicleSpawn")
	MP.RegisterEvent("onVehicleDeleted", "onVehicleDeleted")
	
	-- hotreload
	for player_id, _ in pairs(MP.GetPlayers() or {}) do
		onPlayerJoin(player_id)
	end
end
