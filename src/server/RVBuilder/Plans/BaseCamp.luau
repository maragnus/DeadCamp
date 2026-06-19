-- Default modular plan for the Dead Camp RV base camp.

local Constants = require(script.Parent.Parent:WaitForChild("Constants"))

local BaseCamp = {}

local function mergePlan(base, overrides)
	for key, value in pairs(overrides or {}) do
		base[key] = value
	end
	return base
end

function BaseCamp.classC(overrides)
	return mergePlan({
		OutputName = Constants.OutputName,
		VehicleId = Constants.VehicleId,
		BuildVersion = Constants.BuildVersion,
		Scale = Constants.DefaultScale,
		SteeringWheelSourcePath = Constants.SteeringWheelSourcePath,

		Modules = {
			{
				Id = "Cab",
				Type = "ClassCCab",
				Length = 12.4,
				PanelColor = "Body",
				Wheels = {
					{ Id = "Front", LocalZ = 0.62, AxleCount = 1, SideWheels = 1 },
				},
			},
			{
				Id = "Entry",
				Type = "Living",
				Length = 9.4,
				PanelColor = "Panel",
				Doors = {
					{ Id = "SideEntryDoor", Side = 1, LocalZ0 = 0.52, LocalZ1 = 0.86 },
				},
				Windows = {
					{ Id = "ForwardWindow", Side = -1, LocalZ0 = 0.18, LocalZ1 = 0.54 },
				},
			},
			{
				Id = "Center",
				Type = "Living",
				Length = 10.8,
				PanelColor = "Body",
				Windows = {
					{ Id = "LargeLeftWindow", Side = -1, LocalZ0 = 0.12, LocalZ1 = 0.48 },
					{ Id = "SmallRightWindow", Side = 1, LocalZ0 = 0.16, LocalZ1 = 0.42 },
				},
			},
			{
				Id = "Rear",
				Type = "Living",
				Length = 10.3,
				PanelColor = "Panel",
				Wheels = {
					{ Id = "Rear", LocalZ = 0.34, AxleCount = 1, SideWheels = 1 },
				},
				Windows = {
					{ Id = "RearLeftWindow", Side = -1, LocalZ0 = 0.58, LocalZ1 = 0.86 },
					{ Id = "RearRightWindow", Side = 1, LocalZ0 = 0.58, LocalZ1 = 0.86 },
				},
				RearWall = { Window = true },
				Ladder = true,
			},
		},
	}, overrides)
end

function BaseCamp.classA(overrides)
	local plan = BaseCamp.classC(overrides)
	plan.Modules[1] = {
		Id = "Cab",
		Type = "ClassACab",
		Length = 8.8,
		PanelColor = "Body",
		Wheels = {
			{ Id = "Front", LocalZ = 0.72, AxleCount = 1, SideWheels = 1 },
		},
		Windows = {
			{ Id = "DriverSideWindow", Side = -1, LocalZ0 = 0.2, LocalZ1 = 0.55 },
			{ Id = "PassengerSideWindow", Side = 1, LocalZ0 = 0.2, LocalZ1 = 0.55 },
		},
	}
	return plan
end

return BaseCamp
