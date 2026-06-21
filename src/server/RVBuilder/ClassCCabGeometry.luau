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

function ClassCCabGeometry.frontProfile(dimensions)
	local s = dimensions.Scale
	local hoodLowerTopY = s * 4.2

	return {
		HoodPitchDegrees = 5,
		HoodTopY0 = s * 4.18,
		HoodTopY1 = s * 4.72,
		HoodSideTopY0 = s * 4.05,
		HoodLowerTopY = hoodLowerTopY,
		WindshieldSideY0 = s * 4.35,
		BelowWindshieldTopY = s * 4.55,
		WindshieldTopY = s * 6.8,
	}
end

function ClassCCabGeometry.hoodLeadingEdgeBand(profile, hoodDepth)
	local halfHeight = (profile.HoodTopY1 - profile.HoodTopY0) * 0.5
	local centerY = (profile.HoodTopY0 + profile.HoodTopY1) * 0.5
	local frontYOffset = -hoodDepth * 0.5 * math.sin(math.rad(profile.HoodPitchDegrees))
	local projectedHalfHeight = halfHeight * math.cos(math.rad(profile.HoodPitchDegrees))

	return {
		Y0 = centerY - projectedHalfHeight + frontYOffset,
		Y1 = centerY + projectedHalfHeight + frontYOffset,
	}
end

function ClassCCabGeometry.overCabCapHeights(dimensions)
	local s = dimensions.Scale

	return {
		BottomY = dimensions.CabWallTop,
		ShoulderY = dimensions.CabWallTop + s * 0.82,
		TopY = dimensions.WallTop,
	}
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

function ClassCCabGeometry.alignedCabWindowBand(dimensions)
	local profile = ClassCCabGeometry.frontProfile(dimensions)
	local sideHeight = dimensions.CabWallTop - profile.WindshieldSideY0
	local baseBand = ClassCCabGeometry.cabWindowBand(dimensions)
	local windowHeight = baseBand.Y1 - baseBand.Y0
	local borderReveal = (baseBand.Y0 - profile.WindshieldSideY0) * WINDSHIELD_SIDE_WINDOW_BORDER_FRACTION
	local y0 = profile.WindshieldSideY0 + borderReveal
	local y1 = y0 + windowHeight

	if sideHeight <= 0 then
		return baseBand
	end

	return {
		Y0 = y0,
		Y1 = y1,
	}
end

function ClassCCabGeometry.sideWallBounds(dimensions, side, y0, y1, z0, z1)
	local halfCab = dimensions.CabHalfWidth
	local x0 = side < 0 and -halfCab or halfCab - dimensions.SideWallThickness
	local x1 = side < 0 and -halfCab + dimensions.SideWallThickness or halfCab
	return Bounds.new(x0, x1, y0, y1, z0, z1)
end

function ClassCCabGeometry.windshieldSideBounds(dimensions, side, y0, y1, z0, z1)
	return ClassCCabGeometry.sideWallBounds(dimensions, side, y0, y1, z0, z1)
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

function ClassCCabGeometry.windshieldSlopeZAtY(sideBounds, y)
	local sideHeight = sideBounds.Y1 - sideBounds.Y0
	if sideHeight == 0 then
		return (sideBounds.Z0 + sideBounds.Z1) * 0.5
	end

	return sideBounds.Z0 + (y - sideBounds.Y0) * ((sideBounds.Z1 - sideBounds.Z0) / sideHeight)
end

function ClassCCabGeometry.windshieldGlassBounds(dimensions, sideBounds, cabWindowBand, windshieldTopY)
	local halfWidth = ClassCCabGeometry.windshieldHalfWidth(dimensions)
	local height = windshieldTopY - cabWindowBand.Y0
	local pitchDegrees = math.deg(math.atan((sideBounds.Z1 - sideBounds.Z0) / (sideBounds.Y1 - sideBounds.Y0)))
	local rotation = ShapePrimitives.pitchToward(ShapePrimitives.Direction.Back, pitchDegrees)
	local faceCenterY = (cabWindowBand.Y0 + windshieldTopY) * 0.5
	local faceCenterZ = ClassCCabGeometry.windshieldSlopeZAtY(sideBounds, faceCenterY)
	local faceCenter = Vector3.new(0, faceCenterY, faceCenterZ)
	-- Align the visible front face to the side-slope plane by backing the
	-- entire glass thickness behind that plane instead of centering on it.
	local center = faceCenter - rotation.LookVector * (dimensions.GlassThickness * 0.5)
	local halfDepth = dimensions.GlassThickness * 0.5

	return Bounds.new(
		-halfWidth,
		halfWidth,
		center.Y - height * 0.5,
		center.Y + height * 0.5,
		center.Z - halfDepth,
		center.Z + halfDepth
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
