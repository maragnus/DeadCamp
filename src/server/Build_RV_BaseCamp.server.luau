-- Dead Camp RV BaseCamp modular builder entrypoint.
-- Coordinates: X = width, Y = height, Z = length; negative Z is front.

local RVBuilder = script.Parent:WaitForChild("RVBuilder")
local VehicleBuilder = require(RVBuilder:WaitForChild("VehicleBuilder"))
local BaseCampPlan = require(RVBuilder:WaitForChild("Plans"):WaitForChild("BaseCamp"))

local rv = VehicleBuilder.build(BaseCampPlan.classC())

print(("Built %s with modular RV builder."):format(rv.Name))
