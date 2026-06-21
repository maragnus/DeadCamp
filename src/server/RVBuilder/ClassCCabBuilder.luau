-- Class-C cab body builder. Describes the cab front-to-back while reusing
-- shared panel splitters for carved openings and wheel wells.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounds = require(Shared:WaitForChild("RVBounds"))
local ShapePrimitives = require(Shared:WaitForChild("RVShapePrimitives"))

local Layout = require(script.Parent:WaitForChild("Layout"))
local Panels = require(script.Parent:WaitForChild("Panels"))

local ClassCCabBuilder = {}

local OPEN_CLOSE_GROUP_ATTRIBUTE = "OpenCloseGroupId"
local OPEN_CLOSE_KIND_ATTRIBUTE = "OpenCloseKind"

local function moduleMeta(section, role)
	return {
		ModuleId = section.Id,
		PartRole = role,
		DamageSlot = section.Id .. role,
		Swappable = true,
		DetachableComponent = true,
	}
end

local function mergeAttributes(base, overrides)
	local merged = {}
	for key, value in pairs(base or {}) do
		merged[key] = value
	end
	for key, value in pairs(overrides or {}) do
		merged[key] = value
	end
	return merged
end

local function bodyStyle(section, role, overrides)
	local style = {
		Color = section.PanelColor or "Body",
		Material = Enum.Material.SmoothPlastic,
		Meta = moduleMeta(section, role),
		Tags = { "RVBreakable" },
	}
	for key, value in pairs(overrides or {}) do
		style[key] = value
	end
	return style
end

local function hoodStyle(section, role, groupId)
	return bodyStyle(section, role, {
		Meta = mergeAttributes(moduleMeta(section, role), {
			[OPEN_CLOSE_GROUP_ATTRIBUTE] = groupId,
			[OPEN_CLOSE_KIND_ATTRIBUTE] = "Hood",
		}),
	})
end

local function glassStyle(section, role)
	return {
		Color = "Glass",
		Material = Enum.Material.Glass,
		Transparency = 0.38,
		CanCollide = false,
		Meta = moduleMeta(section, role),
		Tags = { "RVBreakable" },
	}
end

local function cabBodyOptions(dimensions)
	local halfCab = dimensions.CabHalfWidth
	return {
		X0 = -halfCab,
		X1 = halfCab,
		Y0 = dimensions.BodyBottom,
		Y1 = dimensions.CabWallTop,
	}
end

local function localZ(section, fraction)
	return Layout.localZ(section, fraction)
end

local function wheelOpenings(builder, section, side)
	local openings = {}
	for _, group in ipairs(section.WheelGroups or {}) do
		openings[#openings + 1] = Panels.wheelOpening(builder.Config.Dimensions, section, group, side)
	end
	return openings
end

local function sideGlass(builder, parent, section, side, id, y0, y1, z0, z1)
	local dimensions = builder.Config.Dimensions
	local halfCab = dimensions.CabHalfWidth
	local x = side < 0 and -halfCab - dimensions.GlassThickness * 0.5 or halfCab + dimensions.GlassThickness * 0.5

	return builder:addGlass(parent, section.Id .. "_" .. Panels.sideName(side) .. "_" .. id, Bounds.new(
		x - dimensions.GlassThickness * 0.5,
		x + dimensions.GlassThickness * 0.5,
		y0,
		y1,
		z0,
		z1
	), moduleMeta(section, id .. "Glass"))
end

local function slopePitchDegrees(y0, y1, z0, z1)
	return math.deg(math.atan((z1 - z0) / (y1 - y0)))
end

local function buildFrontFace(builder, folders, section, z0, z1)
	local dimensions = builder.Config.Dimensions
	local s = dimensions.Scale
	local halfCab = dimensions.CabHalfWidth
	local grille = {
		Id = "Grille",
		Kind = "Opening",
		X0 = -s * 1.85,
		X1 = s * 1.85,
		Y0 = s * 2.62,
		Y1 = s * 3.72,
	}
	local corner = s * 0.62

	Panels.buildEndPanel(builder, folders.Cab, "CabFrontWithGrille", section, z0, z1, { grille }, {
		X0 = -halfCab,
		X1 = halfCab,
		Y0 = dimensions.BodyBottom,
		Y1 = s * 4.68,
		TopCornerRadius = corner,
	})
	builder:part(folders.Cab, "CabGrilleInset", Bounds.new(
		grille.X0,
		grille.X1,
		grille.Y0,
		grille.Y1,
		z0 - s * 0.07,
		z0 + s * 0.02
	), bodyStyle(section, "FrontGrille", {
		Color = "Trim",
		Material = Enum.Material.Metal,
		CanCollide = false,
	}))
end

local function buildHood(builder, folders, section, frontFaceZ1, hoodZ1)
	local dimensions = builder.Config.Dimensions
	local s = dimensions.Scale
	local halfCab = dimensions.CabHalfWidth
	local hoodHalf = halfCab - s * 0.82
	local hoodGroupId = section.Id .. "_Hood"
	local hoodPitch = ShapePrimitives.pitchToward(ShapePrimitives.Direction.Front, 5)
	local hood = builder:part(folders.Interactables, "Hood", Bounds.new(
		-hoodHalf,
		hoodHalf,
		s * 4.18,
		s * 4.72,
		frontFaceZ1,
		hoodZ1
	), hoodStyle(section, "Hood", hoodGroupId), hoodPitch)

	if hood then
		builder:prompt(hood, "Hood", 0.15)
	end

	for _, side in ipairs({ -1, 1 }) do
		local sideName = Panels.sideName(side)
		local topX0 = side < 0 and -halfCab or hoodHalf
		local topX1 = side < 0 and -hoodHalf or halfCab
		local slopeFace = side < 0 and ShapePrimitives.WedgeSlopeFace.TopLeft or ShapePrimitives.WedgeSlopeFace.TopRight

		builder:wedge(folders.Interactables, sideName .. "HoodSideTop", Bounds.new(
			topX0,
			topX1,
			s * 4.05,
			s * 4.72,
			frontFaceZ1,
			hoodZ1
		), slopeFace, hoodStyle(section, sideName .. "HoodSideTop", hoodGroupId), hoodPitch)

		local openings = wheelOpenings(builder, section, side)
		Panels.buildSidePanel(builder, folders.Cab, sideName .. "HoodSideLower", side, section, openings, {
			X0 = -halfCab,
			X1 = halfCab,
			Y0 = dimensions.BodyBottom,
			Y1 = s * 4.2,
			Z0 = frontFaceZ1,
			Z1 = hoodZ1,
		})

		for _, opening in ipairs(openings) do
			Panels.addWheelTub(builder, folders.WheelBoxes, opening, cabBodyOptions(dimensions))
		end
	end

	builder:part(folders.Cab, "EngineBayFirewall", Bounds.new(
		-halfCab + s * 0.28,
		halfCab - s * 0.28,
		dimensions.BodyBottom,
		s * 4.82,
		hoodZ1 - s * 0.2,
		hoodZ1 + s * 0.05
	), bodyStyle(section, "EngineBayFirewall", {
		Color = "Trim",
		Material = Enum.Material.Metal,
	}))
	builder:part(folders.Cab, "EngineBlock", Bounds.new(
		-s * 1.35,
		s * 1.35,
		s * 3.1,
		s * 4.08,
		frontFaceZ1 + s * 0.85,
		hoodZ1 - s * 0.7
	), bodyStyle(section, "Engine", {
		Color = "Engine",
		Material = Enum.Material.Metal,
	}))
end

local function buildWindshieldSide(builder, folders, section, side, y0, y1, z0, z1)
	local dimensions = builder.Config.Dimensions
	local s = dimensions.Scale
	local halfCab = dimensions.CabHalfWidth
	local sideName = Panels.sideName(side)
	local x0 = side < 0 and -halfCab or halfCab - dimensions.SideWallThickness
	local x1 = side < 0 and -halfCab + dimensions.SideWallThickness or halfCab
	local inset = 0.21
	local borderY = (y1 - y0) * inset
	local borderZ = (z1 - z0) * inset
	local window = {
		Y0 = y0 + borderY,
		Y1 = y1 - borderY,
		Z0 = z0 + borderZ,
		Z1 = z1 - borderZ,
	}
	local cutterBleed = dimensions.GlassThickness * 2
	local slopeBleed = dimensions.GlassThickness * 0.5

	local sideWedge = builder:wedge(folders.Cab, sideName .. "WindshieldSide", Bounds.new(
		x0,
		x1,
		y0,
		y1,
		z0,
		z1
	), ShapePrimitives.WedgeSlopeFace.TopFront, bodyStyle(section, sideName .. "WindshieldSide"))
	local windowCutout = builder:wedge(folders.Cab, sideName .. "WindshieldSideWindowCutout", Bounds.new(
		x0 - cutterBleed,
		x1 + cutterBleed,
		window.Y0,
		window.Y1 + slopeBleed,
		window.Z0 - slopeBleed,
		window.Z1
	), ShapePrimitives.WedgeSlopeFace.TopFront, {
		Color = "Trim",
		CanCollide = false,
		CanQuery = false,
		Meta = moduleMeta(section, sideName .. "WindshieldSideWindowCutout"),
	})
	builder:trySubtract(folders.Cab, sideName .. "WindshieldSide", sideWedge, { windowCutout }, {
		ModuleId = section.Id,
		PartRole = sideName .. "WindshieldSide",
		Swappable = true,
		DetachableComponent = true,
	})
	builder:wedge(folders.Glass, sideName .. "WindshieldSideWindow", Bounds.new(
		x0 - side * dimensions.GlassThickness,
		x1 - side * dimensions.GlassThickness,
		window.Y0,
		window.Y1,
		window.Z0,
		window.Z1
	), ShapePrimitives.WedgeSlopeFace.TopFront, glassStyle(section, sideName .. "WindshieldSideWindow"))
end

local function buildWindshield(builder, folders, section, windshieldZ0, windshieldZ1)
	local dimensions = builder.Config.Dimensions
	local s = dimensions.Scale
	local halfCab = dimensions.CabHalfWidth
	local sideY0 = s * 4.35
	local sideY1 = dimensions.CabWallTop
	local windshieldCenterZ = (windshieldZ0 + windshieldZ1) * 0.5
	local windshieldDepth = math.min(s * 0.62, 1)
	local windshieldXInset = dimensions.SideWallThickness * 0.5
	local windshieldPitch = slopePitchDegrees(sideY0, sideY1, windshieldZ0, windshieldZ1)

	builder:part(folders.Cab, "BelowWindshieldPanel", Bounds.new(
		-halfCab,
		halfCab,
		dimensions.BodyBottom,
		s * 4.55,
		windshieldZ0,
		windshieldZ1
	), bodyStyle(section, "BelowWindshield"))

	builder:addGlass(folders.Glass, "Windshield", Bounds.new(
		-halfCab + windshieldXInset,
		halfCab - windshieldXInset,
		s * 4.58,
		s * 6.8,
		windshieldCenterZ - windshieldDepth * 0.5,
		windshieldCenterZ + windshieldDepth * 0.5
	), moduleMeta(section, "Windshield"), ShapePrimitives.pitchToward(ShapePrimitives.Direction.Back, windshieldPitch))

	for _, side in ipairs({ -1, 1 }) do
		buildWindshieldSide(builder, folders, section, side, sideY0, sideY1, windshieldZ0, windshieldZ1)
	end
end

local function buildCabin(builder, folders, section, cabinZ0, cabinZ1)
	local dimensions = builder.Config.Dimensions
	local s = dimensions.Scale
	local halfCab = dimensions.CabHalfWidth

	for _, side in ipairs({ -1, 1 }) do
		local window = {
			Id = "CabWindow",
			Kind = "Window",
			Side = side,
			Z0 = cabinZ0 + s * 0.55,
			Z1 = cabinZ1 - s * 1.15,
			Y0 = s * 4.58,
			Y1 = s * 6.2,
		}

		Panels.buildSidePanel(builder, folders.Cab, Panels.sideName(side) .. "CabinSide", side, section, { window }, {
			X0 = -halfCab,
			X1 = halfCab,
			Y0 = dimensions.BodyBottom,
			Y1 = dimensions.CabWallTop,
			Z0 = cabinZ0,
			Z1 = cabinZ1,
		})
		sideGlass(builder, folders.Glass, section, side, "CabWindow", window.Y0, window.Y1, window.Z0, window.Z1)
	end

	builder:part(folders.Cab, "CabRoofPanel", Bounds.new(
		-halfCab,
		halfCab,
		dimensions.CabWallTop,
		dimensions.CabWallTop + dimensions.RoofThickness,
		cabinZ0,
		section.Z1
	), bodyStyle(section, "CabRoof"))
end

local function buildOverCabCap(builder, folders, section)
	local dimensions = builder.Config.Dimensions
	local s = dimensions.Scale
	local halfWidth = dimensions.Width * 0.5
	local capFrontZ0 = localZ(section, 0.16)
	local capFrontZ1 = localZ(section, 0.29)
	local capBottomY = dimensions.CabWallTop + s * 0.18
	local capShoulderY = dimensions.CabWallTop + s * 0.82
	local capTopY = dimensions.WallTop

	builder:wedge(folders.Cab, "OverCabCapFrontTopRound", Bounds.new(
		-halfWidth,
		halfWidth,
		capTopY - s * 1.05,
		capTopY + dimensions.RoofThickness,
		capFrontZ0,
		capFrontZ1
	), ShapePrimitives.WedgeSlopeFace.TopFront, bodyStyle(section, "OverCabCapFrontTop"))
	builder:part(folders.Cab, "OverCabCapFrontCenter", Bounds.new(
		-halfWidth,
		halfWidth,
		capShoulderY,
		capTopY - s * 1.0,
		capFrontZ0,
		capFrontZ1
	), bodyStyle(section, "OverCabCapFrontCenter"))
	builder:wedge(folders.Cab, "OverCabCapFrontBottomRound", Bounds.new(
		-halfWidth,
		halfWidth,
		capBottomY,
		capShoulderY,
		capFrontZ0,
		capFrontZ1
	), ShapePrimitives.WedgeSlopeFace.BottomFront, bodyStyle(section, "OverCabCapFrontBottom"))

	for _, side in ipairs({ -1, 1 }) do
		local x0 = side < 0 and -halfWidth or halfWidth - dimensions.SideWallThickness
		local x1 = side < 0 and -halfWidth + dimensions.SideWallThickness or halfWidth
		builder:part(folders.Cab, Panels.sideName(side) .. "OverCabCapSideWall", Bounds.new(
			x0,
			x1,
			capBottomY,
			capTopY,
			capFrontZ1,
			section.Z1
		), bodyStyle(section, Panels.sideName(side) .. "OverCabCapSideWall"))
	end

	builder:part(folders.Cab, "OverCabCapTop", Bounds.new(
		-halfWidth,
		halfWidth,
		capTopY,
		capTopY + dimensions.RoofThickness,
		capFrontZ1,
		section.Z1
	), bodyStyle(section, "OverCabCapTop"))
	builder:part(folders.Cab, "OverCabCapBottom", Bounds.new(
		-halfWidth,
		halfWidth,
		capBottomY,
		capBottomY + dimensions.RoofThickness,
		capFrontZ1,
		section.Z1
	), bodyStyle(section, "OverCabCapBottom"))
	builder:part(folders.Cab, "OverCabCapBackBottomWall", Bounds.new(
		-halfWidth,
		halfWidth,
		capBottomY,
		capShoulderY,
		section.Z1 - s * 0.18,
		section.Z1 + s * 0.05
	), bodyStyle(section, "OverCabCapBackBottom"))
end

local function buildInterior(builder, folders, section)
	local dimensions = builder.Config.Dimensions
	local s = dimensions.Scale
	local seatZ0 = localZ(section, 0.45)
	local seatZ1 = localZ(section, 0.62)

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
		Meta = moduleMeta(section, "DriverVehicleSeat"),
	}, CFrame.Angles(0, math.rad(180), 0))
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
		Meta = moduleMeta(section, "PassengerSeat"),
	}, CFrame.Angles(0, math.rad(180), 0))

	builder:part(folders.Interior, "Dashboard", Bounds.new(
		-s * 4.2,
		s * 4.2,
		s * 3.22,
		s * 3.92,
		localZ(section, 0.31),
		localZ(section, 0.42)
	), {
		Color = "Trim",
		Meta = moduleMeta(section, "Dashboard"),
	})

	local wheelBounds = Bounds.new(-s * 2.8, -s * 1.6, s * 3.76, s * 3.9, localZ(section, 0.39), localZ(section, 0.5))
	local steeringWheel = builder:cloneSourceToBounds(builder.Config.SteeringWheelSourcePath, folders.Interior, "SteeringWheel", wheelBounds, {
		Color = "Tire",
		CanCollide = false,
		Meta = moduleMeta(section, "SteeringWheel"),
	}, nil, { PreserveSourceOrientation = true })
	if not steeringWheel then
		builder:cylinder(folders.Interior, "SteeringWheel", wheelBounds, ShapePrimitives.CylinderAxis.Height, {
			Color = "Tire",
			CanCollide = false,
			Meta = moduleMeta(section, "SteeringWheel"),
		}, { Toward = ShapePrimitives.Direction.Back, Degrees = 65 })
	end
	builder:cylinder(folders.Interior, "SteeringColumn", Bounds.new(
		-s * 2.32,
		-s * 2.1,
		s * 3.38,
		s * 3.62,
		localZ(section, 0.4),
		localZ(section, 0.49)
	), ShapePrimitives.CylinderAxis.Height, {
		Color = "Tire",
		Material = Enum.Material.Metal,
		CanCollide = false,
		Meta = moduleMeta(section, "SteeringColumn"),
	}, { Toward = ShapePrimitives.Direction.Back, Degrees = 65 })
end

function ClassCCabBuilder.build(builder, folders, section)
	local dimensions = builder.Config.Dimensions
	local s = dimensions.Scale
	local frontFaceZ0 = section.Z0 + s * 0.32
	local frontFaceZ1 = section.Z0 + s * 0.62
	local hoodZ1 = localZ(section, 0.31)
	local windshieldZ1 = localZ(section, 0.41)
	local cabinZ1 = localZ(section, 0.76)

	buildFrontFace(builder, folders, section, frontFaceZ0, frontFaceZ1)
	buildHood(builder, folders, section, frontFaceZ1, hoodZ1)
	buildWindshield(builder, folders, section, hoodZ1, windshieldZ1)
	buildCabin(builder, folders, section, windshieldZ1, cabinZ1)
	buildOverCabCap(builder, folders, section)
	buildInterior(builder, folders, section)
end

return ClassCCabBuilder
