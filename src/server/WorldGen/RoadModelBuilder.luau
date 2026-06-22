local RoadRenderBuilder = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WorldGen"):WaitForChild("RoadRenderBuilder"))

local RoadModelBuilder = {}

function RoadModelBuilder.build(parent, spec, options)
	return RoadRenderBuilder.build(parent, "RoadSurface", spec, options)
end

return RoadModelBuilder
