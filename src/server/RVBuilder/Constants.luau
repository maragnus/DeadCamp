-- Shared constants for the modular RV builder.

local Constants = {}

Constants.DefaultScale = 1.5
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

function Constants.dimensions(scale)
	local s = scale or Constants.DefaultScale

	return {
		Scale = s,
		Width = scaled(s, 12.0),
		SideWallThickness = scaled(s, 0.35),
		FloorTop = scaled(s, 2.2),
		FloorThickness = scaled(s, 0.3),
		BodyBottom = scaled(s, 2.2),
		WallTop = scaled(s, 10.8),
		RoofThickness = scaled(s, 0.3),
		RoofShoulderRadius = scaled(s, 0.6),
		ChassisY = scaled(s, 1.25),
		ChassisHeight = scaled(s, 0.65),
		CabHalfWidth = scaled(s, 5.1),
		CabWallTop = scaled(s, 6.7),
		CabFenderTop = scaled(s, 5.0),
		WheelCenterY = scaled(s, 2.1),
		WheelRadius = scaled(s, 1.85),
		WheelWidth = scaled(s, 1.5),
		WheelWellClearance = scaled(s, 0.2),
		WheelTubDepth = scaled(s, 1.85),
		WheelTubThickness = scaled(s, 0.18),
		WheelWellCorner = scaled(s, 0.56),
		DualWheelSpacing = scaled(s, 0.12),
		GlassThickness = scaled(s, 0.08),
		TrimThickness = scaled(s, 0.12),
	}
end

return Constants
