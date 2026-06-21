-- Shared Class-C cab measurements that are easy to drift if inlined.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounds = require(Shared:WaitForChild("RVBounds"))
local ShapePrimitives = require(Shared:WaitForChild("RVShapePrimitives"))

local ClassCCabGeometry = {}
local WINDSHIELD_SIDE_WINDOW_BORDER_FRACTION = 0.5

function ClassCCabGeometry.hoodHalfWidth(dimensions)
	return dimensions.CabHalfWidth - dimensions.Scale * 0.82
end

function ClassCCabGeometry.windshieldHalfWidth(dimensions)
	return dimensions.CabHalfWidth - dimensions.SideWallThickness
end

function ClassCCabGeometry.cabWindowBand(dimensions)
	local s = dimensions.Scale
	return {
		Y0 = s * 4.58,
		Y1 = s * 6.2,
	}
end

function ClassCCabGeometry.windshieldSideBounds(dimensions, side, y0, y1, z0, z1)
	local halfCab = dimensions.CabHalfWidth
	local x0 = side < 0 and -halfCab or halfCab - dimensions.SideWallThickness
	local x1 = side < 0 and -halfCab + dimensions.SideWallThickness or halfCab
	return Bounds.new(x0, x1, y0, y1, z0, z1)
end

function ClassCCabGeometry.windshieldSideWindowBounds(sideBounds, cabWindowBand)
	local sideHeight = sideBounds.Y1 - sideBounds.Y0
	local sideDepth = sideBounds.Z1 - sideBounds.Z0
	local windowHeight = cabWindowBand.Y1 - cabWindowBand.Y0
	local borderReveal = (cabWindowBand.Y0 - sideBounds.Y0) * WINDSHIELD_SIDE_WINDOW_BORDER_FRACTION
	local y0 = sideBounds.Y0 + borderReveal
	local y1 = y0 + windowHeight
	local z1 = sideBounds.Z1 - borderReveal
	-- Keep the same height as CabWindow, but trim the lower/back border to sit lower and farther back.
	local z0 = z1 - windowHeight * (sideDepth / sideHeight)

	return Bounds.new(
		sideBounds.X0,
		sideBounds.X1,
		y0,
		y1,
		z0,
		z1
	)
end

function ClassCCabGeometry.steeringAssembly(dimensions, localZAt)
	local s = dimensions.Scale
	local wheelBounds = Bounds.new(
		-s * 2.8,
		-s * 1.6,
		s * 3.76,
		s * 3.9,
		localZAt(0.39),
		localZAt(0.5)
	)
	local columnRadius = s * 0.12
	local columnLength = localZAt(0.49) - localZAt(0.4)

	return {
		WheelBounds = wheelBounds,
		WheelFallbackOrientation = {
			Toward = ShapePrimitives.Direction.Back,
			Degrees = 65,
		},
		ColumnRadius = columnRadius,
		ColumnLength = columnLength,
		HubInset = columnLength * 0.5 - columnRadius,
	}
end

return ClassCCabGeometry
