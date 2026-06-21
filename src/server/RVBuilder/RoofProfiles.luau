-- Shared rounded roof span helpers so straight roof runs keep one profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounds = require(Shared:WaitForChild("RVBounds"))

local RoofProfiles = {}

function RoofProfiles.shoulderedTopBounds(dimensions, halfWidth, topY, z0, z1)
	local innerSideX = halfWidth - dimensions.SideWallThickness
	local shoulderRadius = dimensions.RoofShoulderRadius
	local roofY = topY + dimensions.RoofThickness * 0.5

	return {
		Center = Bounds.new(
			-halfWidth + shoulderRadius,
			halfWidth - shoulderRadius,
			topY,
			topY + dimensions.RoofThickness,
			z0,
			z1
		),
		LeftShoulder = Bounds.new(
			-innerSideX - shoulderRadius * 0.5,
			-innerSideX + shoulderRadius * 0.5,
			roofY - shoulderRadius * 0.5,
			roofY + shoulderRadius * 0.5,
			z0,
			z1
		),
		RightShoulder = Bounds.new(
			innerSideX - shoulderRadius * 0.5,
			innerSideX + shoulderRadius * 0.5,
			roofY - shoulderRadius * 0.5,
			roofY + shoulderRadius * 0.5,
			z0,
			z1
		),
	}
end

return RoofProfiles
