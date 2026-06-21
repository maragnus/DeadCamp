-- Shared cockpit builder for drivable cab variants.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounds = require(Shared:WaitForChild("RVBounds"))
local ShapePrimitives = require(Shared:WaitForChild("RVShapePrimitives"))

local CabGeometry = require(script.Parent:WaitForChild("ClassCCabGeometry"))
local Layout = require(script.Parent:WaitForChild("Layout"))
local Panels = require(script.Parent:WaitForChild("Panels"))

local CockpitBuilder = {}
CockpitBuilder.IsDriveSeatAttribute = "IsDriveSeat"

local SHAFT_DIRECTION_BIAS = Vector3.new(0, -1, -1)

local DEFAULTS = {
	SeatZ0Fraction = 0.45,
	SeatZ1Fraction = 0.62,
	DashboardZ0Fraction = 0.31,
	DashboardZ1Fraction = 0.42,
	SteeringAssembly = CabGeometry.steeringAssembly,
}

local function moduleMeta(section, role, overrides)
	local meta = {
		ModuleId = section.Id,
		PartRole = role,
		DamageSlot = section.Id .. role,
		Swappable = true,
		DetachableComponent = true,
	}

	for key, value in pairs(overrides or {}) do
		meta[key] = value
	end

	return meta
end

local function localZ(section, fraction)
	return Layout.localZ(section, fraction)
end

local function instanceRotation(instance)
	if not instance then
		return nil
	end
	if instance:IsA("Model") then
		return instance:GetPivot().Rotation
	end
	if instance:IsA("BasePart") then
		return instance.CFrame.Rotation
	end
	return nil
end

local function dashboardFacingRotation(wheelRotation)
	if wheelRotation.RightVector:Dot(SHAFT_DIRECTION_BIAS) >= 0 then
		return wheelRotation
	end
	return wheelRotation * CFrame.Angles(0, math.pi, 0)
end

function CockpitBuilder.build(builder, folders, section, options)
	local config = {}
	for key, value in pairs(DEFAULTS) do
		config[key] = value
	end
	for key, value in pairs(options or {}) do
		config[key] = value
	end

	local dimensions = builder.Config.Dimensions
	local s = dimensions.Scale
	local interiorHalfWidth = Panels.wheelTubInnerHalfWidth(dimensions)
	local seatZ0 = localZ(section, config.SeatZ0Fraction)
	local seatZ1 = localZ(section, config.SeatZ1Fraction)
	local steering = config.SteeringAssembly(dimensions, function(fraction)
		return localZ(section, fraction)
	end)

	local driverSeat = builder:part(folders.Interior, "DriverVehicleSeat", Bounds.new(
		-s * 3.1,
		-s * 1.35,
		dimensions.FloorTop + s * 0.35,
		dimensions.FloorTop + s * 0.85,
		seatZ0,
		seatZ1
	), {
		ClassName = "VehicleSeat",
		Color = "Seat",
		Material = Enum.Material.Fabric,
		CanTouch = true,
		Meta = moduleMeta(section, "DriverVehicleSeat", {
			[CockpitBuilder.IsDriveSeatAttribute] = true,
		}),
	})
	if driverSeat then
		driverSeat.MaxSpeed = 0
		driverSeat.Torque = 0
	end

	builder:part(folders.Interior, "PassengerSeat", Bounds.new(
		s * 1.35,
		s * 3.1,
		dimensions.FloorTop + s * 0.35,
		dimensions.FloorTop + s * 0.85,
		seatZ0,
		seatZ1
	), {
		ClassName = "Seat",
		Color = "Seat",
		Material = Enum.Material.Fabric,
		CanTouch = true,
		Meta = moduleMeta(section, "PassengerSeat"),
	})

	builder:part(folders.Interior, "Dashboard", Bounds.new(
		-interiorHalfWidth,
		interiorHalfWidth,
		s * 3.22,
		s * 3.92,
		localZ(section, config.DashboardZ0Fraction),
		localZ(section, config.DashboardZ1Fraction)
	), {
		Color = "Trim",
		Meta = moduleMeta(section, "Dashboard"),
	})

	local wheelRotation = ShapePrimitives.cylinderCFrameFromBounds(
		steering.WheelBounds,
		ShapePrimitives.CylinderAxis.Height,
		steering.WheelFallbackOrientation
	).Rotation
	local steeringWheel = builder:cloneSourceToBounds(builder.Config.SteeringWheelSourcePath, folders.Interior, "SteeringWheel", steering.WheelBounds, {
		Color = "Tire",
		CanCollide = false,
		Meta = moduleMeta(section, "SteeringWheel"),
	}, nil, { PreserveSourceOrientation = true })

	wheelRotation = instanceRotation(steeringWheel) or wheelRotation
	if not steeringWheel then
		builder:cylinder(folders.Interior, "SteeringWheel", steering.WheelBounds, ShapePrimitives.CylinderAxis.Height, {
			Color = "Tire",
			CanCollide = false,
			Meta = moduleMeta(section, "SteeringWheel"),
		}, { Rotation = wheelRotation })
	end

	local shaftRotation = dashboardFacingRotation(wheelRotation)
	local shaftDirection = shaftRotation.RightVector
	local wheelCenter = Bounds.center(steering.WheelBounds)
	local columnCenter = wheelCenter + shaftDirection * steering.HubInset

	builder:cylinder(folders.Interior, "SteeringColumn", Bounds.new(
		columnCenter.X - steering.ColumnRadius,
		columnCenter.X + steering.ColumnRadius,
		columnCenter.Y - steering.ColumnLength * 0.5,
		columnCenter.Y + steering.ColumnLength * 0.5,
		columnCenter.Z - steering.ColumnRadius,
		columnCenter.Z + steering.ColumnRadius
	), ShapePrimitives.CylinderAxis.Height, {
		Color = "Tire",
		Material = Enum.Material.Metal,
		CanCollide = false,
		Meta = moduleMeta(section, "SteeringColumn"),
	}, { Rotation = shaftRotation })

	return driverSeat
end

return CockpitBuilder
