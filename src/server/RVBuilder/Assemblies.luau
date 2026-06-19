-- Shared assemblies used by multiple RV module types.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounds = require(Shared:WaitForChild("RVBounds"))
local ShapePrimitives = require(Shared:WaitForChild("RVShapePrimitives"))

local Layout = require(script.Parent:WaitForChild("Layout"))
local Panels = require(script.Parent:WaitForChild("Panels"))

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

function Assemblies.buildChassis(builder, parent, layout)
	local dimensions = builder.Config.Dimensions
	local halfWidth = dimensions.Width * 0.5
	return builder:part(parent, "MainChassis", Bounds.new(
		-halfWidth + dimensions.Scale * 0.4,
		halfWidth - dimensions.Scale * 0.4,
		dimensions.ChassisY - dimensions.ChassisHeight * 0.5,
		dimensions.ChassisY + dimensions.ChassisHeight * 0.5,
		layout.TotalZ0 + dimensions.Scale * 1.6,
		layout.TotalZ1 - dimensions.Scale * 1.0
	), {
		Color = "Chassis",
		Material = Enum.Material.Metal,
		Meta = { PartRole = "Chassis", Swappable = false },
	})
end

function Assemblies.buildFloor(builder, parent, layout, wheelGroups)
	local dimensions = builder.Config.Dimensions
	local halfWidth = dimensions.Width * 0.5
	local innerSideX = halfWidth - dimensions.SideWallThickness
	local centerHalf = innerSideX - dimensions.WheelTubDepth - dimensions.Scale * 0.25
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
		local sideX0 = side < 0 and -innerSideX or centerHalf
		local sideX1 = side < 0 and -centerHalf or innerSideX
		local cursor = layout.TotalZ0 + dimensions.Scale * 0.2
		local wells = {}

		for _, group in ipairs(wheelGroups) do
			local well = Panels.wheelOpening(dimensions, group.Section, group, side)
			wells[#wells + 1] = well
		end
		table.sort(wells, function(a, b)
			return a.Z0 < b.Z0
		end)

		for index, well in ipairs(wells) do
			if well.Z0 > cursor then
				builder:part(parent, sideName(side) .. "FloorSpan" .. index, Bounds.new(
					sideX0,
					sideX1,
					dimensions.FloorTop - dimensions.FloorThickness,
					dimensions.FloorTop,
					cursor,
					well.Z0
				), floorStyle)
			end
			cursor = math.max(cursor, well.Z1)
		end

		if cursor < layout.TotalZ1 then
			builder:part(parent, sideName(side) .. "FloorEnd", Bounds.new(
				sideX0,
				sideX1,
				dimensions.FloorTop - dimensions.FloorThickness,
				dimensions.FloorTop,
				cursor,
				layout.TotalZ1
			), floorStyle)
		end
	end
end

function Assemblies.buildRoof(builder, parent, section)
	local dimensions = builder.Config.Dimensions
	local halfWidth = dimensions.Width * 0.5
	local innerSideX = halfWidth - dimensions.SideWallThickness
	local roofY = dimensions.WallTop + dimensions.RoofThickness * 0.5
	local style = {
		Color = section.PanelColor or "Body",
		Material = Enum.Material.SmoothPlastic,
		Meta = moduleMeta(section, "Roof"),
		Tags = { "RVBreakable" },
	}

	builder:part(parent, section.Id .. "_RoofCenter", Bounds.new(
		-halfWidth + dimensions.RoofShoulderRadius,
		halfWidth - dimensions.RoofShoulderRadius,
		dimensions.WallTop,
		dimensions.WallTop + dimensions.RoofThickness,
		section.Z0,
		section.Z1
	), style)
	builder:cylinder(parent, section.Id .. "_RoofLeftShoulder", Bounds.new(
		-innerSideX - dimensions.RoofShoulderRadius * 0.5,
		-innerSideX + dimensions.RoofShoulderRadius * 0.5,
		roofY - dimensions.RoofShoulderRadius * 0.5,
		roofY + dimensions.RoofShoulderRadius * 0.5,
		section.Z0,
		section.Z1
	), ShapePrimitives.CylinderAxis.Length, style)
	builder:cylinder(parent, section.Id .. "_RoofRightShoulder", Bounds.new(
		innerSideX - dimensions.RoofShoulderRadius * 0.5,
		innerSideX + dimensions.RoofShoulderRadius * 0.5,
		roofY - dimensions.RoofShoulderRadius * 0.5,
		roofY + dimensions.RoofShoulderRadius * 0.5,
		section.Z0,
		section.Z1
	), ShapePrimitives.CylinderAxis.Length, style)
end

function Assemblies.buildDoor(builder, interactables, glassParent, section, door)
	local dimensions = builder.Config.Dimensions
	local halfWidth = dimensions.Width * 0.5
	local side = door.Side or 1
	local doorX = side * (halfWidth + dimensions.Scale * 0.22)
	local doorPart = builder:part(interactables, door.Id or "SideEntryDoor", Bounds.new(
		doorX - dimensions.Scale * 0.18,
		doorX + dimensions.Scale * 0.18,
		door.Y0,
		door.Y1,
		door.Z0,
		door.Z1
	), {
		Color = section.PanelColor or "Body",
		Meta = moduleMeta(section, "EntryDoor"),
		Tags = { "RVBreakable" },
	})
	builder:prompt(doorPart, "Side Door", 0)

	local glassX = side * (halfWidth + dimensions.Scale * 0.42)
	builder:addGlass(glassParent, (door.Id or "SideEntryDoor") .. "_Window", Bounds.new(
		glassX - dimensions.GlassThickness * 0.5,
		glassX + dimensions.GlassThickness * 0.5,
		door.Y0 + dimensions.Scale * 3.1,
		door.Y1 - dimensions.Scale * 0.75,
		door.Z0 + dimensions.Scale * 0.72,
		door.Z1 - dimensions.Scale * 0.72
	), moduleMeta(section, "EntryDoorWindow"))
	builder:part(interactables, (door.Id or "SideEntryDoor") .. "_Handle", Bounds.new(
		glassX - dimensions.Scale * 0.07,
		glassX + dimensions.Scale * 0.07,
		door.Y0 + dimensions.Scale * 2.36,
		door.Y0 + dimensions.Scale * 2.54,
		door.Z0 + dimensions.Scale * 0.15,
		door.Z0 + dimensions.Scale * 0.55
	), {
		Color = "Tire",
		Material = Enum.Material.Metal,
		CanCollide = false,
		Meta = moduleMeta(section, "DoorHandle"),
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
					local dualOffset = (wheelIndex - 1) * (width + (group.DualSpacing or dimensions.DualWheelSpacing))
					local x = side * (halfWidth + dimensions.Scale * 1.08 - dualOffset)
					local z = group.Z + axleOffset
					local wheelModel = Instance.new("Model")
					wheelModel.Name = sideName(side) .. group.Id .. "_Wheel" .. wheelIndex
					wheelModel:SetAttribute("ModuleId", group.ModuleId)
					wheelModel:SetAttribute("PartRole", "WheelAssembly")
					wheelModel:SetAttribute("Swappable", true)
					wheelModel:SetAttribute("DetachableComponent", true)
					wheelModel.Parent = parent

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
	local style = {
		Color = "Metal",
		Material = Enum.Material.Metal,
		Meta = { PartRole = "Bumper", DamageSlot = "Bumper", Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	}

	builder:part(parent, "FrontBumper", Bounds.new(
		-halfWidth + dimensions.Scale * 0.45,
		halfWidth - dimensions.Scale * 0.45,
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
	local colors = builder.Config.Colors
	local frontZ = layout.TotalZ0 - dimensions.Scale * 0.32
	local rearZ = layout.TotalZ1 + dimensions.Scale * 0.15

	builder:addLight(parent, "HeadlightLeft", Bounds.new(-halfWidth * 0.58, -halfWidth * 0.42, dimensions.Scale * 3.45, dimensions.Scale * 3.82, frontZ, frontZ + dimensions.Scale * 0.18), colors.Headlamp, "Headlamp", { PartRole = "ExteriorLight", LightType = "Headlamp", DamageSlot = "HeadlightLeft", Swappable = true })
	builder:addLight(parent, "HeadlightRight", Bounds.new(halfWidth * 0.42, halfWidth * 0.58, dimensions.Scale * 3.45, dimensions.Scale * 3.82, frontZ, frontZ + dimensions.Scale * 0.18), colors.Headlamp, "Headlamp", { PartRole = "ExteriorLight", LightType = "Headlamp", DamageSlot = "HeadlightRight", Swappable = true })
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

function Assemblies.connectInteractables(interactables)
	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	for _, part in ipairs(interactables:GetChildren()) do
		if part:IsA("BasePart") then
			local prompt = part:FindFirstChild("OpenClosePrompt")
			if prompt then
				local closed = part.CFrame
				local isHood = string.find(string.lower(part.Name), "hood") ~= nil
				local pivotOffset = isHood and CFrame.new(0, 0, part.Size.Z * 0.5) or CFrame.new(0, 0, -part.Size.Z * 0.5)
				local axis = isHood and closed.RightVector or closed.UpVector
				local angle = isHood and math.rad(-70) or math.rad(95)
				local pivot = (closed * pivotOffset).Position
				local open = CFrame.new(pivot) * CFrame.fromAxisAngle(axis.Unit, angle) * CFrame.new(-pivot) * closed
				local isOpen = false

				prompt.Triggered:Connect(function()
					isOpen = not isOpen
					prompt.ActionText = isOpen and "Close" or "Open"
					TweenService:Create(part, tweenInfo, { CFrame = isOpen and open or closed }):Play()
				end)
			end
		end
	end
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
