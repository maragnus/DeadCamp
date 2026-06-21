-- Default modular plan for the Dead Camp RV base camp.

local Constants = require(script.Parent.Parent:WaitForChild("Constants"))

local BaseCamp = {}
local CLASS_C_CAB_GEOMETRY_LENGTH = 12.4
local CLASS_C_CAB_TRIM_LENGTH = 4.472 / Constants.DefaultScale
local CLASS_C_CAB_LENGTH = CLASS_C_CAB_GEOMETRY_LENGTH - CLASS_C_CAB_TRIM_LENGTH

local function mergePlan(base, overrides)
	for key, value in pairs(overrides or {}) do
		base[key] = value
	end
	return base
end

local function basePlan(modules)
	return {
		OutputName = Constants.OutputName,
		VehicleId = Constants.VehicleId,
		BuildVersion = Constants.BuildVersion,
		Scale = Constants.DefaultScale,
		Drive = Constants.driveConfig(Constants.DefaultScale),
		SteeringWheelSourcePath = Constants.SteeringWheelSourcePath,
		Modules = modules,
	}
end

local function classCCabModule()
	return {
		Id = "Cab",
		Type = "ClassCCab",
		Length = CLASS_C_CAB_LENGTH,
		GeometryLength = CLASS_C_CAB_GEOMETRY_LENGTH,
		PanelColor = "Body",
		Wheels = {
			{ Id = "Front", LocalZ = 0.405, AxleCount = 1, SideWheels = 1 },
		},
	}
end

local function entryModule()
	return {
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
	}
end

local function centerModule()
	return {
		Id = "Center",
		Type = "Living",
		Length = 10.8,
		PanelColor = "Body",
		Windows = {
			{ Id = "LargeLeftWindow", Side = -1, LocalZ0 = 0.12, LocalZ1 = 0.48 },
			{ Id = "SmallRightWindow", Side = 1, LocalZ0 = 0.16, LocalZ1 = 0.42 },
		},
	}
end

local function rearModule()
	return {
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
	}
end

local function classCModules(includeCenter)
	local modules = {
		classCCabModule(),
		entryModule(),
	}

	if includeCenter then
		modules[#modules + 1] = centerModule()
	end

	modules[#modules + 1] = rearModule()
	return modules
end

function BaseCamp.classC(overrides)
	return mergePlan(basePlan(classCModules(true)), overrides)
end

function BaseCamp.classCSimple(overrides)
	return mergePlan(basePlan(classCModules(false)), overrides)
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
