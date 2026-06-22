-- Shared constants for the modular RV builder.

local Constants = {}

Constants.DefaultScale = 1.1
Constants.OutputName = "RV_BaseCamp_RepairCandidate"
Constants.VehicleId = "RV_BaseCamp"
Constants.BuildVersion = "BaseCamp.ModularBuilder.1"
Constants.SteeringWheelSourcePath = "game.Workspace.RV_BaseCamp.Generated.RV_BaseCamp.Cab.SteeringWheel"
Constants.DriveModel = "KinematicArcade"
Constants.DriveConfigKeys = {
	"MaxForwardSpeed",
	"MaxReverseSpeed",
	"Acceleration",
	"BrakeDeceleration",
	"CoastDeceleration",
	"SteerRateDegrees",
	"SteerReturnDegrees",
	"MaxGroundTiltDegrees",
	"GroundCastLength",
	"ForwardClearance",
	"LedgeProbeLength",
	"StopBuffer",
	"UndersideClearance",
	"SpawnClearance",
	"SuspensionPositionSharpness",
	"SuspensionAngularSharpness",
	"SuspensionMaxTravel",
	"SuspensionMaxPitchDegrees",
	"SuspensionMaxRollDegrees",
	"SupportLossGraceSeconds",
	"CameraPitchInfluence",
	"CameraRollInfluence",
}

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

local function requireAtMost(name, value, maximumName, maximum)
	if value > maximum + EPSILON then
		error(("%s must be at most %s; got %.3f > %.3f"):format(name, maximumName, value, maximum), 3)
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
	local wallTop = scaled(s, 10.8)
	local roofThickness = scaled(s, 0.3)
	local bodyTop = wallTop + roofThickness

	return {
		Scale = s,
		GroundY = groundY,
		Width = scaled(s, 12.0),
		SideWallThickness = scaled(s, 0.35),
		FloorTop = floorTop,
		FloorThickness = scaled(s, 0.3),
		BodyBottom = floorTop,
		WallTop = wallTop,
		RoofThickness = roofThickness,
		BodyTop = bodyTop,
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

function Constants.driveConfig(scale, overrides)
	local s = scale or Constants.DefaultScale
	local config = {
		MaxForwardSpeed = scaled(s, 24.0),
		MaxReverseSpeed = scaled(s, 11.0),
		Acceleration = scaled(s, 14.5),
		BrakeDeceleration = scaled(s, 22.0),
		CoastDeceleration = scaled(s, 9.0),
		SteerRateDegrees = 78,
		SteerReturnDegrees = 124,
		MaxGroundTiltDegrees = 18,
		GroundCastLength = scaled(s, 7.5),
		ForwardClearance = scaled(s, 4.2),
		LedgeProbeLength = scaled(s, 6.2),
		StopBuffer = scaled(s, 0.6),
		UndersideClearance = scaled(s, 0.18),
		SpawnClearance = scaled(s, 0.45),
		SuspensionPositionSharpness = 10,
		SuspensionAngularSharpness = 7,
		SuspensionMaxTravel = scaled(s, 1.45),
		SuspensionMaxPitchDegrees = 7.5,
		SuspensionMaxRollDegrees = 5.5,
		SupportLossGraceSeconds = 0.22,
		CameraPitchInfluence = 0.28,
		CameraRollInfluence = 0.08,
	}

	for key, value in pairs(overrides or {}) do
		config[key] = value
	end

	return config
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
	requireEqual("BodyTop", dimensions.BodyTop, "WallTop + RoofThickness", dimensions.WallTop + dimensions.RoofThickness)
	requireAbove("BodyTop", dimensions.BodyTop, "WallTop", dimensions.WallTop)
	requireAtLeast("FloorTop", dimensions.FloorTop, "BodyBottom", dimensions.BodyBottom)
	requireAtLeast("Wheel well top", wheelWellTop, "BodyBottom", dimensions.BodyBottom)
	requireAtLeast("Wheel outer protrusion", dimensions.WheelOuterProtrusion, "0", 0)

	return true
end

function Constants.validateDriveConfig(driveConfig)
	for _, key in ipairs(Constants.DriveConfigKeys) do
		if driveConfig[key] == nil then
			error(("Drive config is missing %s"):format(key), 2)
		end
	end

	requireAbove("Drive MaxForwardSpeed", driveConfig.MaxForwardSpeed, "0", 0)
	requireAbove("Drive MaxReverseSpeed", driveConfig.MaxReverseSpeed, "0", 0)
	requireAbove("Drive Acceleration", driveConfig.Acceleration, "0", 0)
	requireAbove("Drive BrakeDeceleration", driveConfig.BrakeDeceleration, "0", 0)
	requireAbove("Drive CoastDeceleration", driveConfig.CoastDeceleration, "0", 0)
	requireAbove("Drive SteerRateDegrees", driveConfig.SteerRateDegrees, "0", 0)
	requireAbove("Drive SteerReturnDegrees", driveConfig.SteerReturnDegrees, "0", 0)
	requireAbove("Drive MaxGroundTiltDegrees", driveConfig.MaxGroundTiltDegrees, "0", 0)
	requireAtMost("Drive MaxGroundTiltDegrees", driveConfig.MaxGroundTiltDegrees, "89", 89)
	requireAbove("Drive GroundCastLength", driveConfig.GroundCastLength, "0", 0)
	requireAbove("Drive ForwardClearance", driveConfig.ForwardClearance, "0", 0)
	requireAbove("Drive LedgeProbeLength", driveConfig.LedgeProbeLength, "0", 0)
	requireAtLeast("Drive StopBuffer", driveConfig.StopBuffer, "0", 0)
	requireAtLeast("Drive UndersideClearance", driveConfig.UndersideClearance, "0", 0)
	requireAtLeast("Drive SpawnClearance", driveConfig.SpawnClearance, "0", 0)
	requireAbove("Drive SuspensionPositionSharpness", driveConfig.SuspensionPositionSharpness, "0", 0)
	requireAbove("Drive SuspensionAngularSharpness", driveConfig.SuspensionAngularSharpness, "0", 0)
	requireAtLeast("Drive SuspensionMaxTravel", driveConfig.SuspensionMaxTravel, "0", 0)
	requireAtLeast("Drive SuspensionMaxPitchDegrees", driveConfig.SuspensionMaxPitchDegrees, "0", 0)
	requireAtMost("Drive SuspensionMaxPitchDegrees", driveConfig.SuspensionMaxPitchDegrees, "89", 89)
	requireAtLeast("Drive SuspensionMaxRollDegrees", driveConfig.SuspensionMaxRollDegrees, "0", 0)
	requireAtMost("Drive SuspensionMaxRollDegrees", driveConfig.SuspensionMaxRollDegrees, "89", 89)
	requireAtLeast("Drive SupportLossGraceSeconds", driveConfig.SupportLossGraceSeconds, "0", 0)
	requireAtLeast("Drive CameraPitchInfluence", driveConfig.CameraPitchInfluence, "0", 0)
	requireAtMost("Drive CameraPitchInfluence", driveConfig.CameraPitchInfluence, "1", 1)
	requireAtLeast("Drive CameraRollInfluence", driveConfig.CameraRollInfluence, "0", 0)
	requireAtMost("Drive CameraRollInfluence", driveConfig.CameraRollInfluence, "1", 1)

	return true
end

return Constants
