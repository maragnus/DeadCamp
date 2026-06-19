-- Dead Camp RV BaseCamp repair candidate.
-- Source of truth for the RV builder. Coordinates: X = width, Y = height, Z = length; negative Z is front.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ShapePrimitives = require(script.Parent:WaitForChild("RVShapePrimitives"))

local OUTPUT_NAME = "RV_BaseCamp_RepairCandidate"

local Config = {
	OutputName = OUTPUT_NAME,
	VehicleId = "RV_BaseCamp",
	BuildVersion = "BaseCamp.RepairCandidate.1",

	Dimensions = {
		Width = 18.2,
		SideWallThickness = 0.55,
		FloorTop = 3.325,
		FloorThickness = 0.45,
		BodyBottom = 3.325,
		WallTop = 16.3,
		RoofThickness = 0.45,
		RoofShoulderRadius = 0.9,
		ChassisY = 1.85,
	},

	Sections = {
		Cab = { Id = "Cab", Kind = "cab", Z0 = -33.7, Z1 = -15.2 },
		LivingFront = { Id = "LivingFront", Kind = "living", Z0 = -15.2, Z1 = -1.1, PanelColor = "Panel" },
		LivingMiddle = { Id = "LivingMiddle", Kind = "living", Z0 = -1.1, Z1 = 15.0, PanelColor = "Body" },
		LivingRear = { Id = "LivingRear", Kind = "living", Z0 = 15.0, Z1 = 30.4, PanelColor = "Panel" },
	},

	Wheels = {
		Radius = 2.8,
		Width = 2.25,
		WellClearance = 0.3,
		TubDepth = 2.8,
		TubThickness = 0.28,
		CornerWedge = 0.85,
		AxleGroups = {
			{ Id = "Front", ModuleId = "Cab", Z = -16.5, AxleCount = 1, AxleSpacing = 1.7, SideWheels = 1, DualSpacing = 0.18 },
			{ Id = "Rear", ModuleId = "LivingRear", Z = 18.5, AxleCount = 1, AxleSpacing = 1.7, SideWheels = 1, DualSpacing = 0.18 },
		},
	},

	Door = {
		Side = 1,
		Z0 = 0.5,
		Z1 = 4.7,
		Y0 = 3.45,
		Y1 = 11.45,
		Thickness = 0.48,
	},

	Windows = {
		SideY0 = 9.25,
		SideY1 = 11.8,
		CabY0 = 6.85,
		CabY1 = 9.35,
		RearY0 = 9.35,
		RearY1 = 11.75,
	},
}

local Colors = {
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

local dims = Config.Dimensions
local halfWidth = dims.Width * 0.5
local sideWallX = halfWidth
local innerSideX = halfWidth - dims.SideWallThickness
local floorTop = dims.FloorTop
local floorBottom = floorTop - dims.FloorThickness
local wallBottom = dims.BodyBottom
local wallTop = dims.WallTop
local roofY = wallTop + dims.RoofThickness * 0.5

local function destroyExisting(name)
	local existing = Workspace:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function bounds(x0, x1, y0, y1, z0, z1)
	return {
		X0 = math.min(x0, x1),
		X1 = math.max(x0, x1),
		Y0 = math.min(y0, y1),
		Y1 = math.max(y0, y1),
		Z0 = math.min(z0, z1),
		Z1 = math.max(z0, z1),
	}
end

local function centerOf(b)
	return Vector3.new((b.X0 + b.X1) * 0.5, (b.Y0 + b.Y1) * 0.5, (b.Z0 + b.Z1) * 0.5)
end

local function sizeOf(b)
	return Vector3.new(
		math.max(0.001, b.X1 - b.X0),
		math.max(0.001, b.Y1 - b.Y0),
		math.max(0.001, b.Z1 - b.Z0)
	)
end

local function validBounds(b)
	return b.X1 > b.X0 and b.Y1 > b.Y0 and b.Z1 > b.Z0
end

local function sideName(side)
	return side < 0 and "Left" or "Right"
end

local function color(name)
	return Colors[name] or Colors.Body
end

local function tag(instance, tags)
	CollectionService:AddTag(instance, "RVComponent")
	for _, name in ipairs(tags or {}) do
		CollectionService:AddTag(instance, name)
	end
end

local function meta(instance, values)
	for key, value in pairs(values or {}) do
		instance:SetAttribute(key, value)
	end
end

local function configure(part, style)
	part.Anchored = true
	part.CanCollide = style == nil or style.CanCollide ~= false
	part.CanTouch = style and style.CanTouch == true or false
	part.CanQuery = style == nil or style.CanQuery ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = style and style.Color or Colors.Body
	part.Material = style and style.Material or Enum.Material.SmoothPlastic
	part.Transparency = style and style.Transparency or 0
	if style and style.Meta then
		meta(part, style.Meta)
	end
	tag(part, style and style.Tags or nil)
	return part
end

local function box(parent, name, b, style)
	if not validBounds(b) then
		return nil
	end
	local p = Instance.new(style and style.ClassName or "Part")
	p.Name = name
	p.Size = sizeOf(b)
	p.CFrame = CFrame.new(centerOf(b))
	configure(p, style)
	p.Parent = parent
	return p
end

local function part(parent, name, size, cf, style)
	local p = Instance.new(style and style.ClassName or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	if style and style.Shape then
		p.Shape = style.Shape
	end
	configure(p, style)
	p.Parent = parent
	return p
end

local function wedge(parent, name, size, center, slope, style)
	return ShapePrimitives.createWedge(parent, name, size, center, slope, function(p)
		configure(p, style)
	end)
end

local function cylinder(parent, name, size, center, axis, style, tilt)
	local merged = table.clone(style or {})
	merged.Shape = Enum.PartType.Cylinder
	return ShapePrimitives.createCylinder(parent, name, size, center, axis, function(p)
		configure(p, merged)
	end, tilt)
end

local function prompt(parent, objectText, holdDuration)
	local p = Instance.new("ProximityPrompt")
	p.Name = "OpenClosePrompt"
	p.ActionText = "Open"
	p.ObjectText = objectText
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = holdDuration or 0
	p.MaxActivationDistance = 11
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function tryUnion(parent, name, pieces, values)
	local parts = {}
	for _, item in ipairs(pieces) do
		if item and item:IsA("BasePart") then
			parts[#parts + 1] = item
		end
	end
	if #parts == 0 then
		return nil
	end
	if #parts == 1 then
		parts[1].Name = name
		meta(parts[1], values)
		return parts[1]
	end

	local root = parts[1]
	local others = {}
	for index = 2, #parts do
		others[#others + 1] = parts[index]
	end

	local ok, result = pcall(function()
		return root:UnionAsync(others)
	end)

	if ok and result then
		result.Name = name
		result.Color = root.Color
		result.Material = root.Material
		result.Anchored = true
		result.CanCollide = root.CanCollide
		result.CanTouch = false
		result.CanQuery = true
		result.Parent = parent
		pcall(function()
			result.UsePartColor = true
		end)
		meta(result, values)
		tag(result)
		for _, item in ipairs(parts) do
			item:Destroy()
		end
		return result
	end

	local fallback = folder(parent, name .. "_Ununioned")
	fallback:SetAttribute("UnionFailed", true)
	for _, item in ipairs(parts) do
		item.Parent = fallback
		meta(item, values)
	end
	return fallback
end

local function sortedEdges(minValue, maxValue, openings, axis)
	local edges = { minValue, maxValue }
	for _, opening in ipairs(openings or {}) do
		local a = math.max(minValue, opening[axis .. "0"])
		local b = math.min(maxValue, opening[axis .. "1"])
		if b > a then
			edges[#edges + 1] = a
			edges[#edges + 1] = b
		end
	end
	table.sort(edges)

	local result = {}
	for _, edge in ipairs(edges) do
		if #result == 0 or math.abs(result[#result] - edge) > 0.001 then
			result[#result + 1] = edge
		end
	end
	return result
end

local function containsZY(opening, z, y)
	return z > opening.Z0 and z < opening.Z1 and y > opening.Y0 and y < opening.Y1
end

local function containsXY(opening, x, y)
	return x > opening.X0 and x < opening.X1 and y > opening.Y0 and y < opening.Y1
end

local function panelStyle(section, role)
	return {
		Color = color(section.PanelColor or "Body"),
		Material = Enum.Material.SmoothPlastic,
		Meta = {
			ModuleId = section.Id,
			PartRole = role,
			DamageSlot = section.Id .. role,
			Swappable = true,
			DetachableComponent = true,
		},
		Tags = { "RVBreakable" },
	}
end

local function buildSidePanel(parent, name, side, section, openings)
	local x0 = side < 0 and -sideWallX or sideWallX - dims.SideWallThickness
	local x1 = side < 0 and -sideWallX + dims.SideWallThickness or sideWallX
	local wall = bounds(x0, x1, wallBottom, wallTop, section.Z0, section.Z1)
	local pieces = {}
	local zEdges = sortedEdges(wall.Z0, wall.Z1, openings, "Z")
	local yEdges = sortedEdges(wall.Y0, wall.Y1, openings, "Y")

	for zi = 1, #zEdges - 1 do
		for yi = 1, #yEdges - 1 do
			local z0 = zEdges[zi]
			local z1 = zEdges[zi + 1]
			local y0 = yEdges[yi]
			local y1 = yEdges[yi + 1]
			local blocked = false
			local zc = (z0 + z1) * 0.5
			local yc = (y0 + y1) * 0.5
			for _, opening in ipairs(openings or {}) do
				if containsZY(opening, zc, yc) then
					blocked = true
					break
				end
			end
			if not blocked then
				pieces[#pieces + 1] = box(parent, name .. "_Panel", bounds(wall.X0, wall.X1, y0, y1, z0, z1), panelStyle(section, sideName(side) .. "SidePanel"))
			end
		end
	end

	for _, opening in ipairs(openings or {}) do
		if opening.Kind == "WheelWell" then
			local corner = opening.CornerWedge
			local wedgeHeight = math.min(corner, (opening.Y1 - opening.Y0) * 0.72)
			local y0 = opening.Y1 - wedgeHeight
			local style = panelStyle(section, sideName(side) .. "WheelWellCorner")
			pieces[#pieces + 1] = wedge(parent, name .. "_" .. opening.Id .. "_FrontCornerWedge", Vector3.new(dims.SideWallThickness, wedgeHeight, corner), Vector3.new((wall.X0 + wall.X1) * 0.5, y0 + wedgeHeight * 0.5, opening.Z0 + corner * 0.5), ShapePrimitives.wheelWellCornerSlope(side, ShapePrimitives.Direction.Front), style)
			pieces[#pieces + 1] = wedge(parent, name .. "_" .. opening.Id .. "_RearCornerWedge", Vector3.new(dims.SideWallThickness, wedgeHeight, corner), Vector3.new((wall.X0 + wall.X1) * 0.5, y0 + wedgeHeight * 0.5, opening.Z1 - corner * 0.5), ShapePrimitives.wheelWellCornerSlope(side, ShapePrimitives.Direction.Back), style)
		end
	end

	return tryUnion(parent, name, pieces, {
		ModuleId = section.Id,
		PartRole = sideName(side) .. "SidePanel",
		WheelWellRule = "wall before/after, wall above, two wedge corners",
		Swappable = true,
		DetachableComponent = true,
	})
end

local function buildEndPanel(parent, name, section, z0, z1, openings)
	local wall = bounds(-sideWallX, sideWallX, wallBottom, wallTop, z0, z1)
	local pieces = {}
	local xEdges = sortedEdges(wall.X0, wall.X1, openings, "X")
	local yEdges = sortedEdges(wall.Y0, wall.Y1, openings, "Y")

	for xi = 1, #xEdges - 1 do
		for yi = 1, #yEdges - 1 do
			local x0 = xEdges[xi]
			local x1 = xEdges[xi + 1]
			local y0 = yEdges[yi]
			local y1 = yEdges[yi + 1]
			local blocked = false
			local xc = (x0 + x1) * 0.5
			local yc = (y0 + y1) * 0.5
			for _, opening in ipairs(openings or {}) do
				if containsXY(opening, xc, yc) then
					blocked = true
					break
				end
			end
			if not blocked then
				pieces[#pieces + 1] = box(parent, name .. "_Panel", bounds(x0, x1, y0, y1, wall.Z0, wall.Z1), panelStyle(section, name))
			end
		end
	end

	return tryUnion(parent, name, pieces, {
		ModuleId = section.Id,
		PartRole = name,
		Swappable = true,
		DetachableComponent = true,
	})
end

local function wheelWellOpening(group, side)
	local radius = group.Radius or Config.Wheels.Radius
	local clearance = group.WellClearance or Config.Wheels.WellClearance
	local halfAxleSpan = ((group.AxleCount or 1) - 1) * (group.AxleSpacing or 0) * 0.5
	local centerY = 3.2
	local z0 = group.Z - halfAxleSpan - radius - clearance
	local z1 = group.Z + halfAxleSpan + radius + clearance
	return {
		Id = group.Id,
		Kind = "WheelWell",
		ModuleId = group.ModuleId,
		Side = side,
		Z0 = z0,
		Z1 = z1,
		Y0 = wallBottom,
		Y1 = centerY + radius + clearance,
		CornerWedge = Config.Wheels.CornerWedge,
	}
end

local function openingsFor(section, side)
	local openings = {}
	for _, group in ipairs(Config.Wheels.AxleGroups) do
		if group.ModuleId == section.Id then
			openings[#openings + 1] = wheelWellOpening(group, side)
		end
	end
	return openings
end

local function addWheelTub(parent, well)
	local side = well.Side
	local skinInnerX = side < 0 and -innerSideX or innerSideX
	local tubInnerX = skinInnerX - side * Config.Wheels.TubDepth
	local x0 = math.min(skinInnerX, tubInnerX)
	local x1 = math.max(skinInnerX, tubInnerX)
	local t = Config.Wheels.TubThickness
	local y0 = floorTop
	local y1 = well.Y1
	local z0 = well.Z0
	local z1 = well.Z1
	local prefix = well.Id .. "_" .. sideName(side) .. "_WheelBox"
	local style = {
		Color = Colors.Trim,
		Material = Enum.Material.Metal,
		Meta = {
			ModuleId = well.ModuleId,
			PartRole = "WheelBoxInterior",
			DamageSlot = prefix,
			Swappable = true,
			DetachableComponent = true,
		},
		Tags = { "RVBreakable" },
	}

	box(parent, prefix .. "_InnerWall", bounds(tubInnerX - t * 0.5, tubInnerX + t * 0.5, y0, y1, z0, z1), style)
	box(parent, prefix .. "_Top", bounds(x0, x1, y1 - t, y1, z0, z1), style)
	box(parent, prefix .. "_FrontWall", bounds(x0, x1, y0, y1, z0, z0 + t), style)
	box(parent, prefix .. "_RearWall", bounds(x0, x1, y0, y1, z1 - t, z1), style)
end

local function addGlass(parent, name, size, cf, values)
	local g = part(parent, name, size, cf, {
		Color = Colors.Glass,
		Material = Enum.Material.Glass,
		Transparency = 0.38,
		CanCollide = false,
		Meta = values,
		Tags = { "RVBreakable" },
	})
	return g
end

local function buildFloor(parent)
	local centerHalf = innerSideX - Config.Wheels.TubDepth - 0.35
	local totalZ0 = Config.Sections.Cab.Z0 + 0.2
	local totalZ1 = Config.Sections.LivingRear.Z1
	box(parent, "CenterWalkableFloor", bounds(-centerHalf, centerHalf, floorBottom, floorTop, totalZ0, totalZ1), {
		Color = Colors.Floor,
		Material = Enum.Material.WoodPlanks,
		Meta = { PartRole = "WalkableFloor", Swappable = false },
	})

	local allWells = {}
	for _, group in ipairs(Config.Wheels.AxleGroups) do
		for _, side in ipairs({ -1, 1 }) do
			allWells[#allWells + 1] = wheelWellOpening(group, side)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		local sideX0 = side < 0 and -innerSideX or centerHalf
		local sideX1 = side < 0 and -centerHalf or innerSideX
		local cursor = totalZ0
		local relevant = {}
		for _, well in ipairs(allWells) do
			if well.Side == side then
				relevant[#relevant + 1] = well
			end
		end
		table.sort(relevant, function(a, b)
			return a.Z0 < b.Z0
		end)
		for index, well in ipairs(relevant) do
			if well.Z0 > cursor then
				box(parent, sideName(side) .. "FloorSpan" .. index, bounds(sideX0, sideX1, floorBottom, floorTop, cursor, well.Z0), {
					Color = Colors.Floor,
					Material = Enum.Material.WoodPlanks,
					Meta = { PartRole = "WalkableFloor", Swappable = false },
				})
			end
			cursor = math.max(cursor, well.Z1)
		end
		if cursor < totalZ1 then
			box(parent, sideName(side) .. "FloorEnd", bounds(sideX0, sideX1, floorBottom, floorTop, cursor, totalZ1), {
				Color = Colors.Floor,
				Material = Enum.Material.WoodPlanks,
				Meta = { PartRole = "WalkableFloor", Swappable = false },
			})
		end
	end
end

local function buildLivingSide(parent, glassParent, tubsParent, section)
	for _, side in ipairs({ -1, 1 }) do
		local openings = openingsFor(section, side)
		local window
		if section.Id == "LivingFront" and side < 0 then
			window = { Id = "Window", Kind = "Window", Z0 = -8.0, Z1 = -3.4, Y0 = Config.Windows.SideY0, Y1 = Config.Windows.SideY1 }
		elseif section.Id == "LivingRear" then
			window = { Id = "Window", Kind = "Window", Z0 = 18.7, Z1 = 23.3, Y0 = Config.Windows.SideY0, Y1 = Config.Windows.SideY1 }
		end
		if window then
			openings[#openings + 1] = window
		end
		if section.Id == "LivingFront" and side > 0 then
			openings[#openings + 1] = {
				Id = "EntryDoorOpening",
				Kind = "Door",
				Z0 = Config.Door.Z0,
				Z1 = Config.Door.Z1,
				Y0 = Config.Door.Y0,
				Y1 = Config.Door.Y1,
			}
		end

		buildSidePanel(parent, sideName(side) .. "SidePanel_" .. section.Id, side, section, openings)

		for _, opening in ipairs(openings) do
			if opening.Kind == "WheelWell" then
				addWheelTub(tubsParent, opening)
			elseif opening.Kind == "Window" then
				addGlass(glassParent, sideName(side) .. section.Id .. "_WindowGlass", Vector3.new(0.16, opening.Y1 - opening.Y0, opening.Z1 - opening.Z0), CFrame.new(side * (sideWallX + 0.04), (opening.Y0 + opening.Y1) * 0.5, (opening.Z0 + opening.Z1) * 0.5), {
					ModuleId = section.Id,
					PartRole = "WindowGlass",
					DamageSlot = section.Id .. sideName(side) .. "Window",
					Swappable = true,
				})
			end
		end
	end
end

local function buildRoof(parent)
	for _, section in ipairs({ Config.Sections.LivingFront, Config.Sections.LivingMiddle, Config.Sections.LivingRear }) do
		local z = (section.Z0 + section.Z1) * 0.5
		local length = section.Z1 - section.Z0
		part(parent, section.Id .. "_RoofCenter", Vector3.new(dims.Width - 1.8, dims.RoofThickness, length), CFrame.new(0, roofY, z), {
			Color = Colors.Body,
			Material = Enum.Material.SmoothPlastic,
			Meta = { ModuleId = section.Id, PartRole = "Roof", Swappable = true, DetachableComponent = true },
			Tags = { "RVBreakable" },
		})
		cylinder(parent, section.Id .. "_RoofLeftShoulder", Vector3.new(dims.RoofShoulderRadius, length, dims.RoofShoulderRadius), Vector3.new(-innerSideX, roofY - 0.1, z), ShapePrimitives.CylinderAxis.Length, {
			Color = Colors.Body,
			Material = Enum.Material.SmoothPlastic,
			Meta = { ModuleId = section.Id, PartRole = "RoundedRoofShoulder", Swappable = true, DetachableComponent = true },
			Tags = { "RVBreakable" },
		})
		cylinder(parent, section.Id .. "_RoofRightShoulder", Vector3.new(dims.RoofShoulderRadius, length, dims.RoofShoulderRadius), Vector3.new(innerSideX, roofY - 0.1, z), ShapePrimitives.CylinderAxis.Length, {
			Color = Colors.Body,
			Material = Enum.Material.SmoothPlastic,
			Meta = { ModuleId = section.Id, PartRole = "RoundedRoofShoulder", Swappable = true, DetachableComponent = true },
			Tags = { "RVBreakable" },
		})
	end
end

local function buildCab(parent, glassParent, interactables, interior)
	local cab = Config.Sections.Cab
	part(parent, "CabLeftSidePanel", Vector3.new(0.5, 6.7, 10.8), CFrame.new(-7.35, 6.7, -20.8), {
		Color = Colors.Body,
		Meta = { ModuleId = "Cab", PartRole = "CabSidePanel", Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "CabRightSidePanel", Vector3.new(0.5, 6.7, 10.8), CFrame.new(7.35, 6.7, -20.8), {
		Color = Colors.Body,
		Meta = { ModuleId = "Cab", PartRole = "CabSidePanel", Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "CabBackPanel", Vector3.new(14.1, 6.4, 0.45), CFrame.new(0, 6.9, -15.0), {
		Color = Colors.Body,
		Meta = { ModuleId = "Cab", PartRole = "CabBackPanel", Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "CabFrontCowl", Vector3.new(14.2, 2.8, 0.5), CFrame.new(0, 5.2, -26.55), {
		Color = Colors.Body,
		Meta = { ModuleId = "Cab", PartRole = "CabFrontCowl", Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "CabRoofPanel", Vector3.new(14.4, 0.45, 10.8), CFrame.new(0, 10.35, -20.7), {
		Color = Colors.Body,
		Meta = { ModuleId = "Cab", PartRole = "CabRoof", Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "OverCabSleeperShell", Vector3.new(17.4, 4.4, 13.5), CFrame.new(0, 14.55, -16.6), {
		Color = Colors.Body,
		CanCollide = false,
		Meta = { ModuleId = "Cab", PartRole = "OverCabShell", VisualShell = true, Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	wedge(parent, "OverCabFrontSlope", Vector3.new(17.4, 2.7, 4.2), Vector3.new(0, 12.8, -24.8), ShapePrimitives.WedgeSlope.TopBack, {
		Color = Colors.Body,
		CanCollide = false,
		Meta = { ModuleId = "Cab", PartRole = "OverCabFrontSlope", VisualShell = true, Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})

	local hood = wedge(interactables, "Hood", Vector3.new(13.5, 1.15, 8.0), Vector3.new(0, 7.35, -29.0), ShapePrimitives.WedgeSlope.TopBack, {
		Color = Colors.Body,
		Meta = { ModuleId = "Cab", PartRole = "Hood", Interactable = true, Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	prompt(hood, "Hood", 0.15)

	part(parent, "EngineBayFirewall", Vector3.new(13.4, 4.2, 0.4), CFrame.new(0, 5.6, -24.65), {
		Color = Colors.Trim,
		Material = Enum.Material.Metal,
		Meta = { ModuleId = "Cab", PartRole = "EngineBayFirewall", Swappable = true },
	})
	part(parent, "EngineBlock", Vector3.new(4.2, 1.5, 3.2), CFrame.new(0, 5.45, -29.2), {
		Color = Colors.Engine,
		Material = Enum.Material.Metal,
		Meta = { ModuleId = "Cab", PartRole = "Engine", DamageSlot = "Engine", Swappable = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "EngineIntake", Vector3.new(2.4, 0.55, 2.0), CFrame.new(0, 6.55, -29.2), {
		Color = Colors.Metal,
		Material = Enum.Material.Metal,
		Meta = { ModuleId = "Cab", PartRole = "Engine", DamageSlot = "EngineIntake", Swappable = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "EngineLeftHead", Vector3.new(1.1, 0.6, 3.4), CFrame.new(-2.6, 5.8, -29.2), {
		Color = Colors.Metal,
		Material = Enum.Material.Metal,
		Meta = { ModuleId = "Cab", PartRole = "Engine", DamageSlot = "EngineLeftHead", Swappable = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "EngineRightHead", Vector3.new(1.1, 0.6, 3.4), CFrame.new(2.6, 5.8, -29.2), {
		Color = Colors.Metal,
		Material = Enum.Material.Metal,
		Meta = { ModuleId = "Cab", PartRole = "Engine", DamageSlot = "EngineRightHead", Swappable = true },
		Tags = { "RVBreakable" },
	})

	addGlass(glassParent, "Windshield", Vector3.new(9.8, 3.1, 0.18), CFrame.new(0, 8.55, -26.45) * CFrame.Angles(math.rad(-8), 0, 0), { ModuleId = "Cab", PartRole = "WindowGlass", DamageSlot = "Windshield", Swappable = true })
	addGlass(glassParent, "DriverCabWindow", Vector3.new(0.16, 2.5, 3.3), CFrame.new(-7.3, 8.1, -21.2), { ModuleId = "Cab", PartRole = "WindowGlass", DamageSlot = "DriverCabWindow", Swappable = true })
	addGlass(glassParent, "PassengerCabWindow", Vector3.new(0.16, 2.5, 3.3), CFrame.new(7.3, 8.1, -21.2), { ModuleId = "Cab", PartRole = "WindowGlass", DamageSlot = "PassengerCabWindow", Swappable = true })

	local driverSeat = Instance.new("VehicleSeat")
	driverSeat.Name = "DriverVehicleSeat"
	driverSeat.Size = Vector3.new(2.6, 0.75, 2.8)
	driverSeat.CFrame = CFrame.new(-3.3, 4.25, -20.6) * CFrame.Angles(0, math.rad(180), 0)
	driverSeat.Color = Colors.Seat
	driverSeat.Material = Enum.Material.Fabric
	driverSeat.Anchored = true
	driverSeat.CanCollide = true
	driverSeat.MaxSpeed = 0
	driverSeat.Torque = 0
	meta(driverSeat, { ModuleId = "Cab", PartRole = "DriverVehicleSeat", Swappable = true })
	tag(driverSeat)
	driverSeat.Parent = interior

	local passengerSeat = Instance.new("Seat")
	passengerSeat.Name = "PassengerSeat"
	passengerSeat.Size = Vector3.new(2.6, 0.75, 2.8)
	passengerSeat.CFrame = CFrame.new(3.3, 4.25, -20.6) * CFrame.Angles(0, math.rad(180), 0)
	passengerSeat.Color = Colors.Seat
	passengerSeat.Material = Enum.Material.Fabric
	passengerSeat.Anchored = true
	passengerSeat.CanCollide = true
	meta(passengerSeat, { ModuleId = "Cab", PartRole = "PassengerSeat", Swappable = true })
	tag(passengerSeat)
	passengerSeat.Parent = interior

	part(interior, "DriverSeatBack", Vector3.new(2.7, 2.8, 0.45), CFrame.new(-3.3, 5.7, -19.15), { Color = Color3.fromRGB(28, 28, 27), Material = Enum.Material.Fabric, Meta = { ModuleId = "Cab", PartRole = "SeatBack" } })
	part(interior, "PassengerSeatBack", Vector3.new(2.7, 2.8, 0.45), CFrame.new(3.3, 5.7, -19.15), { Color = Color3.fromRGB(28, 28, 27), Material = Enum.Material.Fabric, Meta = { ModuleId = "Cab", PartRole = "SeatBack" } })
	part(interior, "Dashboard", Vector3.new(12.6, 1.05, 1.35), CFrame.new(0, 5.35, -25.55), { Color = Colors.Trim, Meta = { ModuleId = "Cab", PartRole = "Dashboard", Swappable = true } })
	cylinder(interior, "SteeringWheel", Vector3.new(1.8, 0.18, 1.8), Vector3.new(-3.3, 5.75, -24.75), ShapePrimitives.CylinderAxis.Height, { Color = Colors.Tire, CanCollide = false, Meta = { ModuleId = "Cab", PartRole = "SteeringWheel", Swappable = true } }, { Toward = ShapePrimitives.Direction.Back, Degrees = 65 })
	part(interior, "SteeringColumn", Vector3.new(0.32, 0.32, 1.55), CFrame.new(-3.3, 5.25, -24.2) * CFrame.Angles(math.rad(65), 0, 0), { Color = Colors.Tire, Material = Enum.Material.Metal, CanCollide = false, Meta = { ModuleId = "Cab", PartRole = "SteeringColumn", Swappable = true } })

	for _, side in ipairs({ -1, 1 }) do
		local section = cab
		for _, well in ipairs(openingsFor(section, side)) do
			local fenderZ0 = -20.2
			local fenderZ1 = -13.4
			local fenderTop = 7.4
			local x0 = side < 0 and -sideWallX or sideWallX - dims.SideWallThickness
			local x1 = side < 0 and -sideWallX + dims.SideWallThickness or sideWallX
			local pieces = {}
			local style = panelStyle(section, sideName(side) .. "FrontFender")
			pieces[#pieces + 1] = box(parent, sideName(side) .. "_FrontFender_BeforeWheel", bounds(x0, x1, wallBottom, fenderTop, fenderZ0, math.min(well.Z0, fenderZ1)), style)
			pieces[#pieces + 1] = box(parent, sideName(side) .. "_FrontFender_AfterWheel", bounds(x0, x1, wallBottom, fenderTop, math.max(well.Z1, fenderZ0), fenderZ1), style)
			pieces[#pieces + 1] = box(parent, sideName(side) .. "_FrontFender_AboveWheel", bounds(x0, x1, well.Y1, fenderTop, math.max(well.Z0 + well.CornerWedge, fenderZ0), math.min(well.Z1 - well.CornerWedge, fenderZ1)), style)
			local wedgeHeight = math.min(well.CornerWedge, (well.Y1 - wallBottom) * 0.72)
			local wedgeY0 = well.Y1 - wedgeHeight
			pieces[#pieces + 1] = wedge(parent, sideName(side) .. "_FrontFender_FrontCornerWedge", Vector3.new(dims.SideWallThickness, wedgeHeight, well.CornerWedge), Vector3.new((x0 + x1) * 0.5, wedgeY0 + wedgeHeight * 0.5, well.Z0 + well.CornerWedge * 0.5), ShapePrimitives.wheelWellCornerSlope(side, ShapePrimitives.Direction.Front), style)
			pieces[#pieces + 1] = wedge(parent, sideName(side) .. "_FrontFender_RearCornerWedge", Vector3.new(dims.SideWallThickness, wedgeHeight, well.CornerWedge), Vector3.new((x0 + x1) * 0.5, wedgeY0 + wedgeHeight * 0.5, well.Z1 - well.CornerWedge * 0.5), ShapePrimitives.wheelWellCornerSlope(side, ShapePrimitives.Direction.Back), style)
			tryUnion(parent, sideName(side) .. "_FrontWheelWellFender", pieces, {
				ModuleId = "Cab",
				PartRole = sideName(side) .. "FrontWheelWellFender",
				WheelWellRule = "wall before/after, wall above, two wedge corners",
				Swappable = true,
				DetachableComponent = true,
			})
			addWheelTub(parent, well)
		end
	end
end

local function buildDoor(parent)
	local side = Config.Door.Side
	local x = side * (sideWallX + 0.36)
	local z = (Config.Door.Z0 + Config.Door.Z1) * 0.5
	local y = (Config.Door.Y0 + Config.Door.Y1) * 0.5
	local door = part(parent, "SideEntryDoor", Vector3.new(Config.Door.Thickness, Config.Door.Y1 - Config.Door.Y0, Config.Door.Z1 - Config.Door.Z0), CFrame.new(x, y, z), {
		Color = Colors.Body,
		Meta = { ModuleId = "LivingFront", PartRole = "EntryDoor", Interactable = true, Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	prompt(door, "Side Door", 0)
	addGlass(parent, "SideEntryDoorWindow", Vector3.new(0.12, 2.2, 2.1), CFrame.new(side * (sideWallX + 0.64), 9.2, z), { ModuleId = "LivingFront", PartRole = "WindowGlass", DamageSlot = "SideDoorWindow", Swappable = true })
	part(parent, "SideEntryHandle", Vector3.new(0.22, 0.25, 0.65), CFrame.new(side * (sideWallX + 0.72), 7.1, Config.Door.Z0 + 0.45), { Color = Colors.Tire, Material = Enum.Material.Metal, CanCollide = false, Meta = { ModuleId = "LivingFront", PartRole = "DoorHandle", Swappable = true } })
end

local function buildWheels(parent)
	for _, group in ipairs(Config.Wheels.AxleGroups) do
		local axleCount = group.AxleCount or 1
		local sideWheels = group.SideWheels or 1
		for _, side in ipairs({ -1, 1 }) do
			for axleIndex = 1, axleCount do
				local axleOffset = (axleIndex - (axleCount + 1) * 0.5) * (group.AxleSpacing or 0)
				for wheelIndex = 1, sideWheels do
					local wheelOffset = (wheelIndex - 1) * (Config.Wheels.Width + (group.DualSpacing or 0))
					local x = side * (sideWallX + 1.7 - wheelOffset)
					local z = group.Z + axleOffset
					local wheelModel = Instance.new("Model")
					wheelModel.Name = sideName(side) .. group.Id .. "_Wheel" .. wheelIndex
					wheelModel:SetAttribute("ModuleId", group.ModuleId)
					wheelModel:SetAttribute("PartRole", "WheelAssembly")
					wheelModel:SetAttribute("Swappable", true)
					wheelModel:SetAttribute("DetachableComponent", true)
					wheelModel.Parent = parent
					cylinder(wheelModel, "Tire", Vector3.new(Config.Wheels.Radius * 2, Config.Wheels.Width, Config.Wheels.Radius * 2), Vector3.new(x, 3.2, z), ShapePrimitives.CylinderAxis.Width, {
						Color = Colors.Tire,
						Material = Enum.Material.SmoothPlastic,
						Meta = { ModuleId = group.ModuleId, PartRole = "Wheel", DamageSlot = wheelModel.Name, Swappable = true },
						Tags = { "RVBreakable" },
					})
					cylinder(wheelModel, "Rim", Vector3.new(2.75, Config.Wheels.Width + 0.1, 2.75), Vector3.new(x, 3.2, z), ShapePrimitives.CylinderAxis.Width, {
						Color = Colors.Metal,
						Material = Enum.Material.Metal,
						CanCollide = false,
						Meta = { ModuleId = group.ModuleId, PartRole = "WheelRim", DamageSlot = wheelModel.Name .. "Rim", Swappable = true },
					})
				end
			end
		end
	end
end

local function addLight(parent, name, size, cf, lightColor, lightType)
	local p = part(parent, name, size, cf, {
		Color = lightColor,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Meta = { PartRole = "ExteriorLight", LightType = lightType, DamageSlot = name, Swappable = true, DetachableComponent = true },
		Tags = { "RVLight", "RVBreakable" },
	})
	local glow = Instance.new("PointLight")
	glow.Name = lightType .. "Glow"
	glow.Color = lightColor
	glow.Range = lightType == "Headlamp" and 13 or 8
	glow.Brightness = lightType == "Headlamp" and 1.2 or 0.8
	glow.Parent = p
	return p
end

local function buildLights(parent)
	addLight(parent, "HeadlightLeft", Vector3.new(1.15, 0.55, 0.25), CFrame.new(-4.1, 5.45, -33.75), Colors.Headlamp, "Headlamp")
	addLight(parent, "HeadlightRight", Vector3.new(1.15, 0.55, 0.25), CFrame.new(4.1, 5.45, -33.75), Colors.Headlamp, "Headlamp")
	addLight(parent, "BlinkerFrontLeft", Vector3.new(0.65, 0.38, 0.25), CFrame.new(-6.25, 5.0, -33.75), Colors.Amber, "Blinker")
	addLight(parent, "BlinkerFrontRight", Vector3.new(0.65, 0.38, 0.25), CFrame.new(6.25, 5.0, -33.75), Colors.Amber, "Blinker")
	addLight(parent, "TaillightLeft", Vector3.new(0.75, 1.0, 0.25), CFrame.new(-6.6, 5.8, 30.95), Colors.Red, "Brake")
	addLight(parent, "TaillightRight", Vector3.new(0.75, 1.0, 0.25), CFrame.new(6.6, 5.8, 30.95), Colors.Red, "Brake")
	addLight(parent, "BlinkerRearLeft", Vector3.new(0.65, 0.45, 0.25), CFrame.new(-7.75, 5.0, 30.95), Colors.Amber, "Blinker")
	addLight(parent, "BlinkerRearRight", Vector3.new(0.65, 0.45, 0.25), CFrame.new(7.75, 5.0, 30.95), Colors.Amber, "Blinker")
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -10.5, 5.5, 21.5 }) do
			addLight(parent, "Marker_" .. sideName(side) .. "_" .. tostring(z), Vector3.new(0.16, 0.35, 0.65), CFrame.new(side * (sideWallX + 0.08), 14.05, z), Colors.Amber, "Marker")
		end
	end
end

local function buildLadder(parent)
	local x0 = sideWallX - 1.5
	local x1 = sideWallX - 0.25
	local z0 = Config.Sections.LivingRear.Z1 + 0.22
	for _, x in ipairs({ x0, x1 }) do
		part(parent, "RearLadderRail_" .. tostring(x), Vector3.new(0.12, 10.5, 0.16), CFrame.new(x, 8.45, z0), {
			Color = Colors.Metal,
			Material = Enum.Material.Metal,
			Meta = { ModuleId = "LivingRear", PartRole = "Ladder", DamageSlot = "RearLadder", Swappable = true, DetachableComponent = true },
			Tags = { "RVBreakable" },
		})
	end
	for y = 3.6, 13.3, 1.15 do
		part(parent, "RearLadderRung_" .. tostring(math.floor(y * 10)), Vector3.new(x1 - x0, 0.12, 0.18), CFrame.new((x0 + x1) * 0.5, y, z0), {
			Color = Colors.Metal,
			Material = Enum.Material.Metal,
			Meta = { ModuleId = "LivingRear", PartRole = "LadderRung", DamageSlot = "RearLadder", Swappable = true },
			Tags = { "RVBreakable" },
		})
	end
end

local function buildInteractions(rv)
	local scriptObject = Instance.new("Script")
	scriptObject.Name = "RVInteractables"
	scriptObject.Source = [==[
local TweenService = game:GetService("TweenService")

local rv = script.Parent
local interactables = rv:WaitForChild("Interactables")
local door = interactables:WaitForChild("SideEntryDoor")
local hood = interactables:WaitForChild("Hood")
local doorPrompt = door:WaitForChild("OpenClosePrompt")
local hoodPrompt = hood:WaitForChild("OpenClosePrompt")

local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local doorClosed = door.CFrame
local hoodClosed = hood.CFrame
local doorOpen = false
local hoodOpen = false

local function rotateAroundAxis(cf, pivot, axis, angle)
	return CFrame.new(pivot) * CFrame.fromAxisAngle(axis.Unit, angle) * CFrame.new(-pivot) * cf
end

local doorPivot = (doorClosed * CFrame.new(0, 0, -door.Size.Z * 0.5)).Position
local hoodPivot = (hoodClosed * CFrame.new(0, 0, hood.Size.Z * 0.5)).Position
local doorOpenCFrame = rotateAroundAxis(doorClosed, doorPivot, doorClosed.UpVector, math.rad(95))
local hoodOpenCFrame = rotateAroundAxis(hoodClosed, hoodPivot, hoodClosed.RightVector, math.rad(-70))

doorPrompt.Triggered:Connect(function()
	doorOpen = not doorOpen
	doorPrompt.ActionText = doorOpen and "Close" or "Open"
	TweenService:Create(door, tweenInfo, { CFrame = doorOpen and doorOpenCFrame or doorClosed }):Play()
end)

hoodPrompt.Triggered:Connect(function()
	hoodOpen = not hoodOpen
	hoodPrompt.ActionText = hoodOpen and "Close" or "Open"
	TweenService:Create(hood, tweenInfo, { CFrame = hoodOpen and hoodOpenCFrame or hoodClosed }):Play()
end)
]==]
	scriptObject.Parent = rv
end

local function addMetadata(rv)
	rv:SetAttribute("VehicleId", Config.VehicleId)
	rv:SetAttribute("BuildVersion", Config.BuildVersion)
	rv:SetAttribute("SourceOfTruth", "W:\\Dead Camp\\Build_RV_BaseCamp.server.lua")
	rv:SetAttribute("OutputMode", "RepairCandidate")
	rv:SetAttribute("AxisRule", "X width, Y height, Z length, negative Z front")
	rv:SetAttribute("BodyBottom", wallBottom)
	rv:SetAttribute("FloorTop", floorTop)
	rv:SetAttribute("FloorThickness", dims.FloorThickness)
	rv:SetAttribute("WallThickness", dims.SideWallThickness)
	rv:SetAttribute("SwappableModules", "Cab,LivingFront,LivingMiddle,LivingRear")
	rv:SetAttribute("WheelWellRule", "Divide wall before/after; stop wall above wheel top; use WedgePart corners; box interior from floor top to wheel top")
	rv:SetAttribute("SupportsDuallyWheels", true)
	rv:SetAttribute("SupportsTandemAxles", true)
end

destroyExisting(OUTPUT_NAME)

local rv = Instance.new("Model")
rv.Name = OUTPUT_NAME
rv.Parent = Workspace

local folders = {
	Chassis = folder(rv, "Chassis"),
	Body = folder(rv, "Body"),
	Cab = folder(rv, "Cab"),
	Roof = folder(rv, "Roof"),
	Interior = folder(rv, "Interior"),
	Glass = folder(rv, "Glass"),
	WheelBoxes = folder(rv, "WheelBoxes"),
	Wheels = folder(rv, "Wheels"),
	Lights = folder(rv, "Lights"),
	Interactables = folder(rv, "Interactables"),
}

local chassis = part(folders.Chassis, "MainChassis", Vector3.new(17.2, 1.0, 57.5), CFrame.new(0, dims.ChassisY, 0), {
	Color = Colors.Chassis,
	Material = Enum.Material.Metal,
	Meta = { PartRole = "Chassis", Swappable = false },
})
rv.PrimaryPart = chassis

buildFloor(folders.Interior)
buildCab(folders.Cab, folders.Glass, folders.Interactables, folders.Interior)
for _, section in ipairs({ Config.Sections.LivingFront, Config.Sections.LivingMiddle, Config.Sections.LivingRear }) do
	buildLivingSide(folders.Body, folders.Glass, folders.WheelBoxes, section)
end
buildEndPanel(folders.Body, "CabDividerWall", Config.Sections.LivingFront, -15.42, -14.97, {})
buildEndPanel(folders.Body, "RearWall", Config.Sections.LivingRear, 30.12, 30.67, {
	{ Id = "RearWindow", Kind = "Window", X0 = -2.6, X1 = 2.6, Y0 = Config.Windows.RearY0, Y1 = Config.Windows.RearY1 },
})
addGlass(folders.Glass, "RearWindow", Vector3.new(5.2, 2.4, 0.16), CFrame.new(0, 10.55, 30.72), { ModuleId = "LivingRear", PartRole = "WindowGlass", DamageSlot = "RearWindow", Swappable = true })
buildRoof(folders.Roof)
buildDoor(folders.Interactables)
buildWheels(folders.Wheels)
buildLights(folders.Lights)
buildLadder(folders.Body)
part(folders.Chassis, "FrontBumper", Vector3.new(16.2, 0.85, 0.9), CFrame.new(0, 2.85, -33.25), {
	Color = Colors.Metal,
	Material = Enum.Material.Metal,
	Meta = { PartRole = "FrontBumper", DamageSlot = "FrontBumper", Swappable = true, DetachableComponent = true },
	Tags = { "RVBreakable" },
})
part(folders.Chassis, "RearBumper", Vector3.new(17.2, 0.85, 0.9), CFrame.new(0, 2.85, 31.35), {
	Color = Colors.Metal,
	Material = Enum.Material.Metal,
	Meta = { PartRole = "RearBumper", DamageSlot = "RearBumper", Swappable = true, DetachableComponent = true },
	Tags = { "RVBreakable" },
})
buildInteractions(rv)
addMetadata(rv)
rv:PivotTo(CFrame.new(0, 0, 0))

print("Built " .. OUTPUT_NAME .. " from repaired source-of-truth builder.")
