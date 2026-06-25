-- Dead Camp RV BaseCamp modular builder and Studio debug bootstrap.
-- Coordinates: X = width, Y = height, Z = length; negative Z is front.

local RVDebugPanelService = require(script.Parent:WaitForChild("RVDebugPanelService"))
local WorldGenService = require(script.Parent:WaitForChild("WorldGen"):WaitForChild("WorldGenService"))

RVDebugPanelService.start()

local function runStep(stepName, callback)
	local ok, result = pcall(callback)
	if not ok then
		error(("Build_RV_BaseCamp failed during %s: %s"):format(stepName, tostring(result)), 0)
	end

	return result
end

WorldGenService.generateAllAsync(nil, {
	OnComplete = function(world)
		if not world then
			return
		end

		local rv = runStep("default RV spawn", function()
			return RVDebugPanelService.spawnDefault()
		end)
		print(("Built %s with modular RV builder and attached %s drive controller."):format(rv.Name, rv:GetAttribute("DriveModel") or "unknown"))
	end,
	OnError = function(result)
		error((
			"Build_RV_BaseCamp failed during startup world generation: %s. The Studio debug panel remains available for manual retries."
		):format(tostring(result)), 0)
	end,
})
