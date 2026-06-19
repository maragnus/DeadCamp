-- Vehicle module handlers. Each handler receives an absolute section from Layout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounds = require(Shared:WaitForChild("RVBounds"))
local ShapePrimitives = require(Shared:WaitForChild("RVShapePrimitives"))

local Assemblies = require(script.Parent:WaitForChild("Assemblies"))
local Layout = require(script.Parent:WaitForChild("Layout"))
local Panels = require(script.Parent:WaitForChild("Panels"))

local ModuleBuilders = {}

local function moduleMeta(section, role)
	return {
		ModuleId = section.Id,
		PartRole = role,
		DamageSlot = section.Id .. role,
		Swappable = true,
		DetachableComponent = true,
	}
end

local function featureY(section, key, fallback)
	if section.FeatureY and section.FeatureY[key] then
		return section.FeatureY[key]
	end
	return fallback
end

local function wheelOpenings(builder, section, side)
	local openings = {}
	for _, group in ipairs(section.WheelGroups or {}) do
		openings[#openings + 1] = Panels.wheelOpening(builder.Config.Dimensions, section, group, side)
	end
	return openings
end

local function addWindows(builder, glassParent, section, side, windows)
	local dimensions = builder.Config.Dimensions
	local halfWidth = dimensions.Width * 0.5
	local x = side * (halfWidth + dimensions.GlassThickness * 0.5)

	for _, window in ipairs(windows) do
		builder:addGlass(glassParent, section.Id .. "_" .. Panels.sideName(side) .. "_" .. window.Id, Bounds.new(
			x - dimensions.GlassThickness * 0.5,
			x + dimensions.GlassThickness * 0.5,
			window.Y0,
			window.Y1,
			window.Z0,
			window.Z1
		), moduleMeta(section, "WindowGlass"))
	end
end

function ModuleBuilders.buildLiving(builder, folders, section)
	local dimensions = builder.Config.Dimensions
	local sideWindows = { [-1] = {}, [1] = {} }
	local sideDoors = { [-1] = {}, [1] = {} }

	for _, windowSpec in ipairs(section.Windows or {}) do
		local window = Assemblies.absoluteWindow(section, {
			Id = windowSpec.Id,
			Side = windowSpec.Side,
			LocalZ0 = windowSpec.LocalZ0,
			LocalZ1 = windowSpec.LocalZ1,
			Y0 = windowSpec.Y0 or featureY(section, "WindowY0", dimensions.Scale * 6.16),
			Y1 = windowSpec.Y1 or featureY(section, "WindowY1", dimensions.Scale * 7.86),
		})
		if window.Side == nil or window.Side == 0 then
			sideWindows[-1][#sideWindows[-1] + 1] = window
			sideWindows[1][#sideWindows[1] + 1] = window
		else
			sideWindows[window.Side][#sideWindows[window.Side] + 1] = window
		end
	end

	for _, doorSpec in ipairs(section.Doors or {}) do
		local door = Assemblies.absoluteDoor(section, {
			Id = doorSpec.Id or "SideEntryDoor",
			Side = doorSpec.Side or 1,
			LocalZ0 = doorSpec.LocalZ0,
			LocalZ1 = doorSpec.LocalZ1,
			Y0 = doorSpec.Y0 or dimensions.FloorTop + dimensions.Scale * 0.08,
			Y1 = doorSpec.Y1 or dimensions.Scale * 7.65,
		})
		sideDoors[door.Side][#sideDoors[door.Side] + 1] = door
	end

	for _, side in ipairs({ -1, 1 }) do
		local openings = wheelOpenings(builder, section, side)
		for _, window in ipairs(sideWindows[side]) do
			openings[#openings + 1] = window
		end
		for _, door in ipairs(sideDoors[side]) do
			openings[#openings + 1] = door
		end

		Panels.buildSidePanel(builder, folders.Body, Panels.sideName(side) .. "SidePanel_" .. section.Id, side, section, openings)
		addWindows(builder, folders.Glass, section, side, sideWindows[side])

		for _, opening in ipairs(openings) do
			if opening.Kind == "WheelWell" then
				Panels.addWheelTub(builder, folders.WheelBoxes, opening)
			elseif opening.Kind == "Door" then
				Assemblies.buildDoor(builder, folders.Interactables, folders.Glass, section, opening)
			end
		end
	end

	Assemblies.buildRoof(builder, folders.Roof, section)

	if section.RearWall then
		local rearWindow = {
			Id = "RearWindow",
			Kind = "Window",
			X0 = -dimensions.Scale * 1.75,
			X1 = dimensions.Scale * 1.75,
			Y0 = dimensions.Scale * 6.25,
			Y1 = dimensions.Scale * 7.85,
		}
		local openings = section.RearWall.Window and { rearWindow } or {}
		Panels.buildEndPanel(builder, folders.Body, "RearWall", section, section.Z1 - dimensions.Scale * 0.18, section.Z1 + dimensions.Scale * 0.18, openings)
		if section.RearWall.Window then
			builder:addGlass(folders.Glass, "RearWindow", Bounds.new(
				rearWindow.X0,
				rearWindow.X1,
				rearWindow.Y0,
				rearWindow.Y1,
				section.Z1 + dimensions.Scale * 0.18,
				section.Z1 + dimensions.Scale * 0.28
			), moduleMeta(section, "RearWindowGlass"))
		end
	end

	if section.Ladder then
		Assemblies.buildLadder(builder, folders.Body, section)
	end
end

function ModuleBuilders.buildClassCCab(builder, folders, section)
	local dimensions = builder.Config.Dimensions
	local halfCab = dimensions.CabHalfWidth
	local z = function(fraction)
		return Layout.localZ(section, fraction)
	end

	for _, side in ipairs({ -1, 1 }) do
		local window = {
			Id = "CabWindow",
			Kind = "Window",
			Side = side,
			Z0 = z(0.39),
			Z1 = z(0.68),
			Y0 = dimensions.Scale * 4.55,
			Y1 = dimensions.Scale * 6.25,
		}
		local openings = wheelOpenings(builder, section, side)
		openings[#openings + 1] = window

		Panels.buildSidePanel(builder, folders.Cab, Panels.sideName(side) .. "CabSidePanel_" .. section.Id, side, section, openings, {
			X0 = -halfCab,
			X1 = halfCab,
			Y0 = dimensions.BodyBottom,
			Y1 = dimensions.CabWallTop,
			Z0 = z(0.24),
			Z1 = section.Z1,
		})

		addWindows(builder, folders.Glass, section, side, { window })
		for _, opening in ipairs(openings) do
			if opening.Kind == "WheelWell" then
				Panels.addWheelTub(builder, folders.WheelBoxes, opening)
			end
		end
	end

	builder:part(folders.Cab, "CabFrontCowl", Bounds.new(-halfCab, halfCab, dimensions.BodyBottom, dimensions.Scale * 4.45, z(0.23), z(0.26)), {
		Color = "Body",
		Meta = moduleMeta(section, "CabFrontCowl"),
		Tags = { "RVBreakable" },
	})
	builder:part(folders.Cab, "CabBackPanel", Bounds.new(-halfCab, halfCab, dimensions.BodyBottom, dimensions.CabWallTop, section.Z1 - dimensions.Scale * 0.18, section.Z1 + dimensions.Scale * 0.05), {
		Color = "Body",
		Meta = moduleMeta(section, "CabBackPanel"),
		Tags = { "RVBreakable" },
	})
	builder:part(folders.Cab, "CabRoofPanel", Bounds.new(-halfCab, halfCab, dimensions.CabWallTop, dimensions.CabWallTop + dimensions.RoofThickness, z(0.24), section.Z1), {
		Color = "Body",
		Meta = moduleMeta(section, "CabRoof"),
		Tags = { "RVBreakable" },
	})
	builder:addGlass(folders.Glass, "Windshield", Bounds.new(-dimensions.Scale * 3.3, dimensions.Scale * 3.3, dimensions.Scale * 4.68, dimensions.Scale * 6.72, z(0.245), z(0.255)), moduleMeta(section, "Windshield"))

	builder:part(folders.Cab, "OverCabSleeperShell", Bounds.new(
		-dimensions.Width * 0.5,
		dimensions.Width * 0.5,
		dimensions.Scale * 8.15,
		dimensions.WallTop + dimensions.Scale * 0.35,
		z(0.18),
		section.Z1
	), {
		Color = "Body",
		CanCollide = false,
		Meta = moduleMeta(section, "OverCabShell"),
		Tags = { "RVBreakable" },
	})
	builder:wedge(folders.Cab, "OverCabFrontSlope", Bounds.new(
		-dimensions.Width * 0.5,
		dimensions.Width * 0.5,
		dimensions.Scale * 7.25,
		dimensions.Scale * 9.55,
		section.Z0 + dimensions.Scale * 0.15,
		z(0.2)
	), ShapePrimitives.WedgeSlope.TopBack, {
		Color = "Body",
		CanCollide = false,
		Meta = moduleMeta(section, "OverCabFrontSlope"),
		Tags = { "RVBreakable" },
	})

	local hood = builder:wedge(folders.Interactables, "Hood", Bounds.new(
		-dimensions.Scale * 4.55,
		dimensions.Scale * 4.55,
		dimensions.Scale * 4.52,
		dimensions.Scale * 5.28,
		section.Z0 + dimensions.Scale * 0.35,
		z(0.25)
	), ShapePrimitives.WedgeSlope.TopBack, {
		Color = "Body",
		Meta = moduleMeta(section, "Hood"),
		Tags = { "RVBreakable" },
	})
	builder:prompt(hood, "Hood", 0.15)

	builder:part(folders.Cab, "EngineBayFirewall", Bounds.new(-dimensions.Scale * 4.45, dimensions.Scale * 4.45, dimensions.Scale * 2.45, dimensions.Scale * 5.15, z(0.25), z(0.28)), {
		Color = "Trim",
		Material = Enum.Material.Metal,
		Meta = moduleMeta(section, "EngineBayFirewall"),
	})
	builder:part(folders.Cab, "EngineBlock", Bounds.new(-dimensions.Scale * 1.4, dimensions.Scale * 1.4, dimensions.Scale * 3.1, dimensions.Scale * 4.15, section.Z0 + dimensions.Scale * 1.8, z(0.2)), {
		Color = "Engine",
		Material = Enum.Material.Metal,
		Meta = moduleMeta(section, "Engine"),
		Tags = { "RVBreakable" },
	})

	local driverSeat = builder:part(folders.Interior, "DriverVehicleSeat", Bounds.new(
		-dimensions.Scale * 3.1,
		-dimensions.Scale * 1.35,
		dimensions.FloorTop + dimensions.Scale * 0.35,
		dimensions.FloorTop + dimensions.Scale * 0.85,
		z(0.45),
		z(0.62)
	), {
		ClassName = "VehicleSeat",
		Color = "Seat",
		Material = Enum.Material.Fabric,
		Meta = moduleMeta(section, "DriverVehicleSeat"),
	}, CFrame.Angles(0, math.rad(180), 0))
	driverSeat.MaxSpeed = 0
	driverSeat.Torque = 0

	builder:part(folders.Interior, "PassengerSeat", Bounds.new(
		dimensions.Scale * 1.35,
		dimensions.Scale * 3.1,
		dimensions.FloorTop + dimensions.Scale * 0.35,
		dimensions.FloorTop + dimensions.Scale * 0.85,
		z(0.45),
		z(0.62)
	), {
		ClassName = "Seat",
		Color = "Seat",
		Material = Enum.Material.Fabric,
		Meta = moduleMeta(section, "PassengerSeat"),
	}, CFrame.Angles(0, math.rad(180), 0))

	builder:part(folders.Interior, "Dashboard", Bounds.new(-dimensions.Scale * 4.2, dimensions.Scale * 4.2, dimensions.Scale * 3.22, dimensions.Scale * 3.92, z(0.27), z(0.38)), {
		Color = "Trim",
		Meta = moduleMeta(section, "Dashboard"),
	})

	local wheelBounds = Bounds.new(-dimensions.Scale * 2.8, -dimensions.Scale * 1.6, dimensions.Scale * 3.76, dimensions.Scale * 3.9, z(0.35), z(0.48))
	local steeringWheel = builder:cloneSourceToBounds(builder.Config.SteeringWheelSourcePath, folders.Interior, "SteeringWheel", wheelBounds, {
		Color = "Tire",
		CanCollide = false,
		Meta = moduleMeta(section, "SteeringWheel"),
	})
	if not steeringWheel then
		builder:cylinder(folders.Interior, "SteeringWheel", wheelBounds, ShapePrimitives.CylinderAxis.Height, {
			Color = "Tire",
			CanCollide = false,
			Meta = moduleMeta(section, "SteeringWheel"),
		}, { Toward = ShapePrimitives.Direction.Back, Degrees = 65 })
	end
	builder:cylinder(folders.Interior, "SteeringColumn", Bounds.new(-dimensions.Scale * 2.32, -dimensions.Scale * 2.1, dimensions.Scale * 3.38, dimensions.Scale * 3.62, z(0.37), z(0.47)), ShapePrimitives.CylinderAxis.Height, {
		Color = "Tire",
		Material = Enum.Material.Metal,
		CanCollide = false,
		Meta = moduleMeta(section, "SteeringColumn"),
	}, { Toward = ShapePrimitives.Direction.Back, Degrees = 65 })
end

function ModuleBuilders.buildClassACab(builder, folders, section)
	local dimensions = builder.Config.Dimensions
	local frontWindow = {
		Id = "PanoramicWindshield",
		Kind = "Window",
		X0 = -dimensions.Scale * 4.0,
		X1 = dimensions.Scale * 4.0,
		Y0 = dimensions.Scale * 5.15,
		Y1 = dimensions.Scale * 8.55,
	}

	Panels.buildEndPanel(builder, folders.Cab, "ClassAFrontCap", section, section.Z0 - dimensions.Scale * 0.08, section.Z0 + dimensions.Scale * 0.18, { frontWindow })
	builder:addGlass(folders.Glass, "PanoramicWindshield", Bounds.new(frontWindow.X0, frontWindow.X1, frontWindow.Y0, frontWindow.Y1, section.Z0 - dimensions.Scale * 0.14, section.Z0 - dimensions.Scale * 0.04), moduleMeta(section, "Windshield"))

	ModuleBuilders.buildLiving(builder, folders, section)
end

return ModuleBuilders
