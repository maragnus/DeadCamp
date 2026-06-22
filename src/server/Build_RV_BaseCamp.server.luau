-- Dead Camp RV BaseCamp modular builder and Studio debug bootstrap.
-- Coordinates: X = width, Y = height, Z = length; negative Z is front.

local RVDebugPanelService = require(script.Parent:WaitForChild("RVDebugPanelService"))
local WorldGenService = require(script.Parent:WaitForChild("WorldGen"):WaitForChild("WorldGenService"))

RVDebugPanelService.start()

local function tryStep(stepName, callback)
	local ok, result = pcall(callback)
	if not ok then
		warn(("Build_RV_BaseCamp failed during %s: %s"):format(stepName, tostring(result)))
		return nil
	end

	return result
end

local world = tryStep("startup world generation", function()
	return WorldGenService.generateAll()
end)

if world then
	local rv = tryStep("default RV spawn", function()
		return RVDebugPanelService.spawnDefault()
	end)

	if rv then
		print(("Built %s with modular RV builder and attached %s drive controller."):format(rv.Name, rv:GetAttribute("DriveModel") or "unknown"))
	end
else
	warn("World generation startup failed. The Studio debug panel remains available for manual retries.")
end
