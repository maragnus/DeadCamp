-- Shared assemblies used by multiple RV module types.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounds = require(Shared:WaitForChild("RVBounds"))
local ShapePrimitives = require(Shared:WaitForChild("RVShapePrimitives"))

local Layout = require(script.Parent:WaitForChild("Layout"))
local Panels = require(script.Parent:WaitForChild("Panels"))
local RVInteractableMotion = require(script.Parent:WaitForChild("RVInteractableMotion"))
local RoofProfiles = require(script.Parent:WaitForChild("RoofProfiles"))
local WheelGroups = require(script.Parent:WaitForChild("WheelGroups"))

local Assemblies = {}

local function sideName(side)
	return Panels.sideName(side)
end

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

local function openCloseMeta(section, role, groupId, kind, side)
	return mergeAttributes(moduleMeta(section, role), {
		[RVInteractableMotion.Attributes.GroupId] = groupId,
		[RVInteractableMotion.Attributes.Kind] = kind,
		[RVInteractableMotion.Attributes.Side] = side,
	})
end

local function sideDoorWindowBounds(dimensions, side, door)
	return Panels.sideFlushBounds(
		dimensions,
		side,
		door.Y0 + dimensions.Scale * 3.1,
		door.Y1 - dimensions.Scale * 0.75,
		door.Z0 + dimensions.Scale * 0.72,
		door.Z1 - dimensions.Scale * 0.72
	)
end

local function sideDoorHandleBounds(dimensions, side, door)
	return Panels.sideOutsetBounds(
		dimensions,
		side,
		door.Y0 + dimensions.Scale * 2.36,
		door.Y0 + dimensions.Scale * 2.54,
		door.Z1 - dimensions.Scale * 0.55,
		door.Z1 - dimensions.Scale * 0.15,
		dimensions.TrimThickness
	)
end

local function wheelXCenter(dimensions, halfWidth, side, width, group, wheelIndex)
	local outerProtrusion = group.OuterProtrusion
	if outerProtrusion == nil then
		outerProtrusion = dimensions.WheelOuterProtrusion or 0
	end

	local wheelSpacing = group.DualSpacing or dimensions.DualWheelSpacing
	local inwardOffset = (wheelIndex - 1) * (width + wheelSpacing)
	return side * (halfWidth + outerProtrusion - width * 0.5 - inwardOffset)
end

local function frontBodyHalfWidth(dimensions, layout)
	local firstSection = layout.Sections and layout.Sections[1]
	if firstSection then
		return firstSection.Type == "ClassCCab" and dimensions.CabHalfWidth or dimensions.Width * 0.5
	end
	return dimensions.Width * 0.5
end

local function sectionHalfWidth(dimensions, section)
	if section and section.Type == "ClassCCab" then
		return dimensions.CabHalfWidth
	end
	return dimensions.Width * 0.5
end

local function sideFloorXBounds(dimensions, section, side, centerHalf)
	local innerSideX = sectionHalfWidth(dimensions, section) - dimensions.SideWallThickness
	if side < 0 then
		return -innerSideX, -centerHalf
	end
	return centerHalf, innerSideX
end

local function chassisStyle()
	return {
		Color = "Chassis",
		Material = Enum.Material.Metal,
		Meta = { PartRole = "Chassis", Swappable = false },
	}
end

local function buildChassisSpan(builder, parent, name, dimensions, halfWidth, z0, z1)
	if z1 <= z0 then
		return nil
	end
	return builder:part(parent, name, Bounds.new(
		-halfWidth + dimensions.Scale * 0.4,
		halfWidth - dimensions.Scale * 0.4,
		dimensions.ChassisBottom,
		dimensions.ChassisTop,
		z0,
		z1
	), chassisStyle())
end

local function buildSideFloorSegment(builder, parent, name, floorStyle, dimensions, x0, x1, z0, z1)
	return builder:part(parent, name, Bounds.new(
		x0,
		x1,
		dimensions.FloorTop - dimensions.FloorThickness,
		dimensions.FloorTop,
		z0,
		z1
	), floorStyle)
end

local function buildSectionSideFloor(builder, parent, section, side, wells, floorStyle, dimensions, centerHalf, z0, z1)
	if z1 <= z0 then
		return
	end

	local x0, x1 = sideFloorXBounds(dimensions, section, side, centerHalf)
	local cursor = z0
	local spanIndex = 0

	for _, well in ipairs(wells) do
		local clippedZ0 = math.max(z0, well.Z0)
		local clippedZ1 = math.min(z1, well.Z1)

		if clippedZ1 > clippedZ0 then
			if clippedZ0 > cursor then
				spanIndex += 1
				buildSideFloorSegment(
					builder,
					parent,
					sideName(side) .. section.Id .. "FloorSpan" .. spanIndex,
					floorStyle,
					dimensions,
					x0,
					x1,
					cursor,
					clippedZ0
				)
			end
			cursor = math.max(cursor, clippedZ1)
		end
	end

	if cursor < z1 then
		buildSideFloorSegment(
			builder,
			parent,
			sideName(side) .. section.Id .. "FloorSpan" .. (spanIndex + 1),
			floorStyle,
			dimensions,
			x0,
			x1,
			cursor,
			z1
		)
	end
end

function Assemblies.buildChassis(builder, parent, layout)
	local dimensions = builder.Config.Dimensions
	local firstSection = layout.Sections and layout.Sections[1]
	local frontZ0 = layout.TotalZ0 + dimensions.Scale * 1.6
	local rearZ1 = layout.TotalZ1 - dimensions.Scale * 1.0

	if firstSection and firstSection.Type == "ClassCCab" then
		local cabChassis = buildChassisSpan(
			builder,
			parent,
			"CabChassis",
			dimensions,
			sectionHalfWidth(dimensions, firstSection),
			frontZ0,
			math.min(firstSection.Z1, rearZ1)
		)
		local mainChassis = buildChassisSpan(
			builder,
			parent,
			"MainChassis",
			dimensions,
			dimensions.Width * 0.5,
			math.max(firstSection.Z1, frontZ0),
			rearZ1
		)
		return mainChassis or cabChassis
	end

	return buildChassisSpan(builder, parent, "MainChassis", dimensions, dimensions.Width * 0.5, frontZ0, rearZ1)
end

function Assemblies.buildFloor(builder, parent, layout, wheelGroups)
	local dimensions = builder.Config.Dimensions
	local centerHalf = Panels.wheelTubInnerHalfWidth(dimensions) - dimensions.Scale * 0.25
	local floorStyle = {
		Color = "Floor",
		Material = Enum.Material.WoodPlanks,
		Meta = { PartRole = "WalkableFloor", Swappable = false },
	}

	builder:part(parent, "CenterWalkableFloor", Bounds.new(
		-centerHalf,
		centerHalf,
		dimensions.FloorTop - dimensions.FloorThickness,
		dimensions.FloorTop,
		layout.TotalZ0 + dimensions.Scale * 0.2,
		layout.TotalZ1
	), floorStyle)

	for _, side in ipairs({ -1, 1 }) do
		local wellsBySection = {}

		for _, group in ipairs(wheelGroups) do
			local well = Panels.wheelOpening(dimensions, group.Section, group, side)
			local sectionWells = wellsBySection[group.Section]
			if not sectionWells then
				sectionWells = {}
				wellsBySection[group.Section] = sectionWells
			end
			sectionWells[#sectionWells + 1] = well
		end

		for _, section in ipairs(layout.Sections) do
			local sectionWells = wellsBySection[section] or {}
			table.sort(sectionWells, function(a, b)
				return a.Z0 < b.Z0
			end)

			local sectionZ0 = section.Z0
			if section == layout.Sections[1] then
				sectionZ0 = math.max(sectionZ0, layout.TotalZ0 + dimensions.Scale * 0.2)
			end
			local sectionZ1 = section.Z1
			if section == layout.Sections[#layout.Sections] then
				sectionZ1 = math.min(sectionZ1, layout.TotalZ1)
			end

			buildSectionSideFloor(builder, parent, section, side, sectionWells, floorStyle, dimensions, centerHalf, sectionZ0, sectionZ1)
		end
	end
end

function Assemblies.buildRoof(builder, parent, section)
	local dimensions = builder.Config.Dimensions
	local halfWidth = dimensions.Width * 0.5
	local roofBounds = RoofProfiles.shoulderedTopBounds(
		dimensions,
		halfWidth,
		dimensions.WallTop,
		section.Z0,
		section.Z1
	)
	local style = {
		Color = section.PanelColor or "Body",
		Material = Enum.Material.SmoothPlastic,
		Meta = moduleMeta(section, "Roof"),
		Tags = { "RVBreakable" },
	}

	builder:part(parent, section.Id .. "_RoofCenter", roofBounds.Center, style)
	builder:cylinder(parent, section.Id .. "_RoofLeftShoulder", roofBounds.LeftShoulder, ShapePrimitives.CylinderAxis.Length, style)
	builder:cylinder(parent, section.Id .. "_RoofRightShoulder", roofBounds.RightShoulder, ShapePrimitives.CylinderAxis.Length, style)
end

function Assemblies.buildDoor(builder, interactables, glassParent, section, door)
	local dimensions = builder.Config.Dimensions
	local side = door.Side or 1
	local doorId = door.Id or "SideEntryDoor"
	local motionGroupId = section.Id .. "_" .. doorId
	local doorMeta = openCloseMeta(section, "EntryDoor", motionGroupId, RVInteractableMotion.Kinds.SideDoor, side)
	if side == 1 and doorId == "SideEntryDoor" then
		doorMeta.PlayerPlacementEntry = true
	end
	local doorBounds = Panels.sideFlushBounds(
		dimensions,
		side,
		door.Y0,
		door.Y1,
		door.Z0,
		door.Z1,
		dimensions.SideWallThickness
	)
	local windowBounds = sideDoorWindowBounds(dimensions, side, door)
	local cutoutBleed = dimensions.TrimThickness
	local doorSource = builder:part(interactables, doorId, doorBounds, {
		Color = section.PanelColor or "Body",
		Meta = doorMeta,
		Tags = { "RVBreakable" },
	})
	local doorWindowCutout = builder:part(interactables, doorId .. "_WindowCutout", Bounds.new(
		doorBounds.X0 - cutoutBleed,
		doorBounds.X1 + cutoutBleed,
		windowBounds.Y0,
		windowBounds.Y1,
		windowBounds.Z0,
		windowBounds.Z1
	), {
		Color = "Trim",
		CanCollide = false,
		CanQuery = false,
		Meta = moduleMeta(section, "EntryDoorWindowCutout"),
	})
	local doorPart = builder:trySubtract(interactables, doorId, doorSource, { doorWindowCutout }, doorMeta)

	if doorPart and doorPart:IsA("BasePart") then
		builder:prompt(doorPart, "Side Door", 0)
	end

	builder:addGlass(glassParent, doorId .. "_Window", windowBounds, openCloseMeta(section, "EntryDoorWindow", motionGroupId, RVInteractableMotion.Kinds.SideDoor, side))
	builder:part(interactables, doorId .. "_Handle", sideDoorHandleBounds(dimensions, side, door), {
		Color = "Tire",
		Material = Enum.Material.Metal,
		CanCollide = false,
		Meta = openCloseMeta(section, "DoorHandle", motionGroupId, RVInteractableMotion.Kinds.SideDoor, side),
	})

	return doorPart
end

function Assemblies.buildWheels(builder, parent, wheelGroups)
	local dimensions = builder.Config.Dimensions
	local halfWidth = dimensions.Width * 0.5

	for _, group in ipairs(wheelGroups) do
		local axleCount = group.AxleCount or 1
		local sideWheels = group.SideWheels or 1
		local axleSpacing = group.AxleSpacing or dimensions.WheelRadius * 0.62
		local radius = group.Radius or dimensions.WheelRadius
		local width = group.Width or dimensions.WheelWidth

		for _, side in ipairs({ -1, 1 }) do
			for axleIndex = 1, axleCount do
				local axleOffset = (axleIndex - (axleCount + 1) * 0.5) * axleSpacing
				for wheelIndex = 1, sideWheels do
					local x = wheelXCenter(dimensions, halfWidth, side, width, group, wheelIndex)
					local z = group.Z + axleOffset
					local wheelModel = Instance.new("Model")
					wheelModel.Name = sideName(side) .. group.Id .. "_Wheel" .. wheelIndex
					wheelModel:SetAttribute("ModuleId", group.ModuleId)
					wheelModel:SetAttribute("PartRole", "WheelAssembly")
					wheelModel:SetAttribute("Swappable", true)
					wheelModel:SetAttribute("DetachableComponent", true)
					wheelModel.Parent = parent
					WheelGroups.tagAssembly(wheelModel, group, side, axleIndex, wheelIndex, radius, width, z)

					builder:cylinder(wheelModel, "Tire", Bounds.new(
						x - width * 0.5,
						x + width * 0.5,
						dimensions.WheelCenterY - radius,
						dimensions.WheelCenterY + radius,
						z - radius,
						z + radius
					), ShapePrimitives.CylinderAxis.Width, {
						Color = "Tire",
						Material = Enum.Material.SmoothPlastic,
						Meta = {
							ModuleId = group.ModuleId,
							PartRole = "Wheel",
							WheelGroupId = group.Id,
							WheelSide = side,
							WheelAxleIndex = axleIndex,
							WheelIndex = wheelIndex,
							DamageSlot = wheelModel.Name,
							Swappable = true,
						},
						Tags = { "RVBreakable" },
					})
					builder:cylinder(wheelModel, "Rim", Bounds.new(
						x - (width + dimensions.Scale * 0.08) * 0.5,
						x + (width + dimensions.Scale * 0.08) * 0.5,
						dimensions.WheelCenterY - radius * 0.49,
						dimensions.WheelCenterY + radius * 0.49,
						z - radius * 0.49,
						z + radius * 0.49
					), ShapePrimitives.CylinderAxis.Width, {
						Color = "Metal",
						Material = Enum.Material.Metal,
						CanCollide = false,
						Meta = {
							ModuleId = group.ModuleId,
							PartRole = "WheelRim",
							WheelGroupId = group.Id,
							WheelSide = side,
							WheelAxleIndex = axleIndex,
							WheelIndex = wheelIndex,
							DamageSlot = wheelModel.Name .. "Rim",
							Swappable = true,
						},
					})
				end
			end
		end
	end
end

function Assemblies.buildBumpers(builder, parent, layout)
	local dimensions = builder.Config.Dimensions
	local halfWidth = dimensions.Width * 0.5
	local frontHalfWidth = frontBodyHalfWidth(dimensions, layout)
	local style = {
		Color = "Metal",
		Material = Enum.Material.Metal,
		Meta = { PartRole = "Bumper", DamageSlot = "Bumper", Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	}

	builder:part(parent, "FrontBumper", Bounds.new(
		-frontHalfWidth + dimensions.Scale * 0.3,
		frontHalfWidth - dimensions.Scale * 0.3,
		dimensions.Scale * 1.58,
		dimensions.Scale * 2.15,
		layout.TotalZ0 - dimensions.Scale * 0.28,
		layout.TotalZ0 + dimensions.Scale * 0.35
	), style)
	builder:part(parent, "RearBumper", Bounds.new(
		-halfWidth + dimensions.Scale * 0.25,
		halfWidth - dimensions.Scale * 0.25,
		dimensions.Scale * 1.58,
		dimensions.Scale * 2.15,
		layout.TotalZ1 - dimensions.Scale * 0.2,
		layout.TotalZ1 + dimensions.Scale * 0.42
	), style)
end

function Assemblies.buildLights(builder, parent, layout, sections)
	local dimensions = builder.Config.Dimensions
	local halfWidth = dimensions.Width * 0.5
	local frontHalfWidth = frontBodyHalfWidth(dimensions, layout)
	local colors = builder.Config.Colors
	local firstSection = layout.Sections and layout.Sections[1]
	local frontZ = firstSection and firstSection.Type == "ClassCCab" and layout.TotalZ0 + dimensions.Scale * 0.24 or layout.TotalZ0 - dimensions.Scale * 0.32
	local rearZ = layout.TotalZ1 + dimensions.Scale * 0.15

	builder:addLight(parent, "HeadlightLeft", Bounds.new(-frontHalfWidth * 0.7, -frontHalfWidth * 0.5, dimensions.Scale * 3.35, dimensions.Scale * 3.78, frontZ, frontZ + dimensions.Scale * 0.18), colors.Headlamp, "Headlamp", { PartRole = "ExteriorLight", LightType = "Headlamp", DamageSlot = "HeadlightLeft", Swappable = true })
	builder:addLight(parent, "HeadlightRight", Bounds.new(frontHalfWidth * 0.5, frontHalfWidth * 0.7, dimensions.Scale * 3.35, dimensions.Scale * 3.78, frontZ, frontZ + dimensions.Scale * 0.18), colors.Headlamp, "Headlamp", { PartRole = "ExteriorLight", LightType = "Headlamp", DamageSlot = "HeadlightRight", Swappable = true })
	builder:addLight(parent, "BlinkerLeft", Bounds.new(-frontHalfWidth * 0.88, -frontHalfWidth * 0.76, dimensions.Scale * 3.12, dimensions.Scale * 3.4, frontZ, frontZ + dimensions.Scale * 0.16), colors.Amber, "Blinker", { PartRole = "ExteriorLight", LightType = "Blinker", DamageSlot = "BlinkerLeft", Swappable = true })
	builder:addLight(parent, "BlinkerRight", Bounds.new(frontHalfWidth * 0.76, frontHalfWidth * 0.88, dimensions.Scale * 3.12, dimensions.Scale * 3.4, frontZ, frontZ + dimensions.Scale * 0.16), colors.Amber, "Blinker", { PartRole = "ExteriorLight", LightType = "Blinker", DamageSlot = "BlinkerRight", Swappable = true })
	builder:addLight(parent, "TaillightLeft", Bounds.new(-halfWidth * 0.84, -halfWidth * 0.74, dimensions.Scale * 3.5, dimensions.Scale * 4.15, rearZ, rearZ + dimensions.Scale * 0.16), colors.Red, "Brake", { PartRole = "ExteriorLight", LightType = "Brake", DamageSlot = "TaillightLeft", Swappable = true })
	builder:addLight(parent, "TaillightRight", Bounds.new(halfWidth * 0.74, halfWidth * 0.84, dimensions.Scale * 3.5, dimensions.Scale * 4.15, rearZ, rearZ + dimensions.Scale * 0.16), colors.Red, "Brake", { PartRole = "ExteriorLight", LightType = "Brake", DamageSlot = "TaillightRight", Swappable = true })

	for _, section in ipairs(sections) do
		local z = (section.Z0 + section.Z1) * 0.5
		for _, side in ipairs({ -1, 1 }) do
			local x = side * (halfWidth + dimensions.Scale * 0.05)
			builder:addLight(parent, "Marker_" .. sideName(side) .. "_" .. section.Id, Bounds.new(
				x - dimensions.Scale * 0.05,
				x + dimensions.Scale * 0.05,
				dimensions.WallTop - dimensions.Scale * 1.55,
				dimensions.WallTop - dimensions.Scale * 1.32,
				z - dimensions.Scale * 0.22,
				z + dimensions.Scale * 0.22
			), colors.Amber, "Marker", { ModuleId = section.Id, PartRole = "ExteriorLight", LightType = "Marker", DamageSlot = "Marker" .. section.Id, Swappable = true })
		end
	end
end

function Assemblies.buildLadder(builder, parent, section)
	local dimensions = builder.Config.Dimensions
	local halfWidth = dimensions.Width * 0.5
	local x0 = halfWidth - dimensions.Scale * 1.0
	local x1 = halfWidth - dimensions.Scale * 0.2
	local z0 = section.Z1 + dimensions.Scale * 0.16
	local style = {
		Color = "Metal",
		Material = Enum.Material.Metal,
		Meta = moduleMeta(section, "Ladder"),
		Tags = { "RVBreakable" },
	}

	for _, x in ipairs({ x0, x1 }) do
		builder:part(parent, "RearLadderRail_" .. tostring(x), Bounds.new(x - dimensions.Scale * 0.04, x + dimensions.Scale * 0.04, dimensions.FloorTop, dimensions.WallTop - dimensions.Scale * 1.0, z0, z0 + dimensions.Scale * 0.1), style)
	end

	local rungY = dimensions.FloorTop + dimensions.Scale * 0.35
	while rungY < dimensions.WallTop - dimensions.Scale * 1.2 do
		builder:part(parent, "RearLadderRung_" .. tostring(math.floor(rungY * 10)), Bounds.new(x0, x1, rungY - dimensions.Scale * 0.04, rungY + dimensions.Scale * 0.04, z0 - dimensions.Scale * 0.02, z0 + dimensions.Scale * 0.12), style)
		rungY += dimensions.Scale * 0.78
	end
end

function Assemblies.connectInteractables(root)
	return RVInteractableMotion.attach(root)
end

function Assemblies.absoluteDoor(section, door)
	local z0, z1 = Layout.localSpan(section, door.LocalZ0 or 0.28, door.LocalZ1 or 0.58)
	return {
		Id = door.Id,
		Kind = "Door",
		Side = door.Side or 1,
		Z0 = z0,
		Z1 = z1,
		Y0 = door.Y0,
		Y1 = door.Y1,
	}
end

function Assemblies.absoluteWindow(section, window)
	local z0, z1 = Layout.localSpan(section, window.LocalZ0 or 0.2, window.LocalZ1 or 0.5)
	return {
		Id = window.Id,
		Kind = "Window",
		Side = window.Side,
		Z0 = z0,
		Z1 = z1,
		Y0 = window.Y0,
		Y1 = window.Y1,
	}
end

return Assemblies
