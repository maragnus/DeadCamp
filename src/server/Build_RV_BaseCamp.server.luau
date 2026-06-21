-- Dead Camp RV BaseCamp modular builder and Studio debug bootstrap.
-- Coordinates: X = width, Y = height, Z = length; negative Z is front.

local RVDebugPanelService = require(script.Parent:WaitForChild("RVDebugPanelService"))

RVDebugPanelService.start()
local rv = RVDebugPanelService.spawnDefault()

print(("Built %s with modular RV builder and attached %s drive controller."):format(rv.Name, rv:GetAttribute("DriveModel") or "unknown"))
