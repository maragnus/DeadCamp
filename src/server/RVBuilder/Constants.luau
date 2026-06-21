-- Shared constants for the modular RV builder.

local Constants = {}

Constants.DefaultScale = 1.1
Constants.OutputName = "RV_BaseCamp_RepairCandidate"
Constants.VehicleId = "RV_BaseCamp"
Constants.BuildVersion = "BaseCamp.ModularBuilder.1"
Constants.SteeringWheelSourcePath = "game.Workspace.RV_BaseCamp.Generated.RV_BaseCamp.Cab.SteeringWheel"

Constants.Colors = {
	Body = Color3.fromRGB(196, 199, 181),
	Panel = Color3.fromRGB(154, 165, 133),
	Trim = Color3.fromRGB(47, 49, 47),
	Chassis = Color3.fromRGB(38, 39, 38),
	Floor = Color3.fromRGB(85, 78, 66),
	Glass = Color3.fromRGB(74, 120, 145),
	Tire = Color3.fromRGB(8, 8, 8),
	Metal = Color3.fromRGB(112, 115, 113),
	Engine = Color3.fromRGB(82, 84, 85),
	Seat = Color3.fromRGB(33, 33, 31),
	Headlamp = Color3.fromRGB(255, 240, 188),
	Amber = Color3.fromRGB(255, 151, 42),
	Red = Color3.fromRGB(196, 30, 28),
}

local function scaled(scale, value)
	return value * scale
end

local EPSILON = 0.001

local function requireAbove(name, value, minimumName, minimum)
	if value <= minimum + EPSILON then
		error(("%s must be above %s; got %.3f <= %.3f"):format(name, minimumName, value, minimum), 3)
	end
end

local function requireAtLeast(name, value, minimumName, minimum)
	if value + EPSILON < minimum then
		error(("%s must be at least %s; got %.3f < %.3f"):format(name, minimumName, value, minimum), 3)
	end
end

local function requireEqual(name, value, expectedName, expected)
	if math.abs(value - expected) > EPSILON then
		error(("%s must match %s; got %.3f ~= %.3f"):format(name, expectedName, value, expected), 3)
	end
end

function Constants.dimensions(scale)
	local s = scale or Constants.DefaultScale
	local groundY = 0
	local floorTop = scaled(s, 2.2)
	local wheelRadius = scaled(s, 1.85)
	local wheelCenterY = groundY + wheelRadius
	local chassisHeight = scaled(s, 0.65)
	local chassisY = wheelCenterY
	local chassisBottom = chassisY - chassisHeight * 0.5
	local chassisTop = chassisY + chassisHeight * 0.5

	return {
		Scale = s,
		GroundY = groundY,
		Width = scaled(s, 12.0),
		SideWallThickness = scaled(s, 0.35),
		FloorTop = floorTop,
		FloorThickness = scaled(s, 0.3),
		BodyBottom = floorTop,
		WallTop = scaled(s, 10.8),
		RoofThickness = scaled(s, 0.3),
		RoofShoulderRadius = scaled(s, 0.6),
		ChassisY = chassisY,
		ChassisHeight = chassisHeight,
		ChassisBottom = chassisBottom,
		ChassisTop = chassisTop,
		CabHalfWidth = scaled(s, 5.1),
		CabWallTop = scaled(s, 6.7),
		CabFenderTop = scaled(s, 5.0),
		WheelCenterY = wheelCenterY,
		WheelRadius = wheelRadius,
		WheelWidth = scaled(s, 1.5),
		WheelOuterProtrusion = 0,
		WheelWellClearance = scaled(s, 0.2),
		WheelTubDepth = scaled(s, 1.85),
		WheelTubThickness = scaled(s, 0.18),
		WheelWellCorner = scaled(s, 0.56),
		DualWheelSpacing = scaled(s, 0.12),
		GlassThickness = scaled(s, 0.08),
		TrimThickness = scaled(s, 0.12),
	}
end

function Constants.validateDimensions(dimensions)
	local groundY = dimensions.GroundY or 0
	local tireContactY = dimensions.WheelCenterY - dimensions.WheelRadius
	local wheelWellTop = dimensions.WheelCenterY + dimensions.WheelRadius + dimensions.WheelWellClearance

	requireEqual("Wheel tire contact Y", tireContactY, "GroundY", groundY)
	requireEqual("ChassisY", dimensions.ChassisY, "WheelCenterY", dimensions.WheelCenterY)
	requireEqual("ChassisBottom", dimensions.ChassisBottom, "ChassisY - half ChassisHeight", dimensions.ChassisY - dimensions.ChassisHeight * 0.5)
	requireEqual("ChassisTop", dimensions.ChassisTop, "ChassisY + half ChassisHeight", dimensions.ChassisY + dimensions.ChassisHeight * 0.5)
	requireAbove("ChassisBottom", dimensions.ChassisBottom, "GroundY", groundY)
	requireAbove("BodyBottom", dimensions.BodyBottom, "GroundY", groundY)
	requireAtLeast("BodyBottom", dimensions.BodyBottom, "ChassisTop", dimensions.ChassisTop)
	requireAtLeast("FloorTop", dimensions.FloorTop, "BodyBottom", dimensions.BodyBottom)
	requireAtLeast("Wheel well top", wheelWellTop, "BodyBottom", dimensions.BodyBottom)
	requireAtLeast("Wheel outer protrusion", dimensions.WheelOuterProtrusion, "0", 0)

	return true
end

return Constants
