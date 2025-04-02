local inspect = require("libs/inspect/inspect")

local function getGroundModels()
	local handle = io.open("art/groundmodels.json", "r")
	if handle == nil then
		log('E', 'Telemetry - GroundModels', 'Cannot open "art/groundmodels.json" in read mode')
		return nil
	end
	local groundmodels = handle:read("*all")
	handle:close()
	
	groundmodels = jsonDecode(groundmodels)
	if groundmodels == nil then
		log('E', 'Telemetry - GroundModels', 'Cannot decode groundmodels from "art/groundmodels.json"')
		return nil
	end
	
	return groundmodels
end

-- -----------------------------------------------------------------------
-- GroundModelClass
--[[ Format
	
]]

local missing_patches = {
	_default = {
		collisiontype = "",
		defaultDepth = 0,
		hydrodynamicFriction = 0,
		roughnessCoefficient = 0,
		skidMarks = false,
		slidingFrictionCoefficient = 0,
		staticFrictionCoefficient = 0,
		strength = 0,
		stribeckVelocity = 0
	},
	RUBBER = {
		collisiontype = "RUBBER",
		defaultDepth = 0,
		hydrodynamicFriction = 0,
		roughnessCoefficient = 0,
		skidMarks = false,
		slidingFrictionCoefficient = 0.7,
		staticFrictionCoefficient = 0.98,
		strength = 1,
		stribeckVelocity = 4.5
	}
}

local M = {}
M._groundmodels = {}

M.init = function()
	local groundmodels = getGroundModels()
	if not groundmodels then
		return M
	end
	
	local materials, _ = particles.getMaterialsParticlesTable()
	for id, material in pairs(materials) do
		if groundmodels[material.name] == nil then
			if missing_patches[material.name] == nil then
				log('W', 'Telemetry - GroundModels', 'Material: "' .. material.name .. '" with ID ' .. id .. ' has no game own collision definitions. Ignoring')
			else
				M._groundmodels[id] = M.createGroundModel(missing_patches[material.name], material.name)
				log('I', 'Telemetry - GroundModels', 'Learned : "' .. missing_patches[material.name].collisiontype .. '" from patch')
			end
		else
			M._groundmodels[id] = M.createGroundModel(groundmodels[material.name], material.name)
			log('I', 'Telemetry - GroundModels', 'Learned : "' .. groundmodels[material.name].collisiontype .. '"')
		end
		
	end
	
	--print("===========")
	--dump(M._groundmodels[10])
	return M
end

M.createGroundModel = function(ref, name)
	local groundmodel = {data = {
		-- copy from ref
		name = name,
		collisiontype = ref.collisiontype,
		defaultDepth = ref.defaultDepth,
		hydrodynamicFriction = ref.hydrodynamicFriction,
		roughnessCoefficient = ref.roughnessCoefficient,
		skidMarks = ref.skidMarks,
		slidingFrictionCoefficient = ref.slidingFrictionCoefficient,
		staticFrictionCoefficient = ref.staticFrictionCoefficient,
		strength = ref.strength,
		stribeckVelocity = ref.stribeckVelocity,
	}}
	
	function groundmodel:dump()
		local filter = function(item, path)
			if type(item) == "function" then return nil end
			return item
		end
		log('A', "Telemetry", inspect(self, {process = filter}))
	end
	
	function groundmodel:getName() return self.data.name end
	function groundmodel:getCollisionType() return self.data.collisiontype end
	function groundmodel:getDefaultDepth() return self.data.defaultDepth end
	function groundmodel:getHydrodynamicFriction() return self.data.hydrodynamicFriction end
	function groundmodel:getRoughnessCoefficient() return self.data.roughnessCoefficient end
	function groundmodel:getSkidMarks() return self.data.skidMarks end
	function groundmodel:getSlidingFrictionCoefficient() return self.data.slidingFrictionCoefficient end
	function groundmodel:getStaticFrictionCoefficient() return self.data.staticFrictionCoefficient end
	function groundmodel:getStrength() return self.data.strength end
	function groundmodel:getStribeckVelocity() return self.data.stribeckVelocity end
	
	function groundmodel:getEnvTemp()
		local env_temp = powertrain.currentEnvTemperatureCelsius
		if env_temp then env_temp = env_temp else env_temp = 20 end
		return env_temp
	end
	function groundmodel:getTemp()
		-- this needs to check if sun is actually hitting the model
		-- todo
		local env_temp = self:getEnvTemp()
		 -- https://pmc.ncbi.nlm.nih.gov/articles/PMC10211493/
		local ground_temp = env_temp + (env_temp * self:getStaticFrictionCoefficient()) / 1.5
		
		return ground_temp
	end
	
	return groundmodel
end

M.getGroundModelById = function(id)
	return M._groundmodels[id]
end


return M