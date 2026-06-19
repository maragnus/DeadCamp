-- Dead Camp RV BaseCamp repair candidate.
-- Source of truth for the RV builder. Coordinates: X = width, Y = height, Z = length; negative Z is front.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounds = require(Shared:WaitForChild("RVBounds"))
local ShapePrimitives = require(Shared:WaitForChild("RVShapePrimitives"))

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

local bounds = Bounds.new

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
	if not Bounds.isValid(b) then
		return nil
	end
	local p = Instance.new(style and style.ClassName or "Part")
	p.Name = name
	p.Size = Bounds.size(b)
	p.CFrame = Bounds.cframe(b)
	configure(p, style)
	p.Parent = parent
	return p
end

local function part(parent, name, b, style, rotation)
	if not Bounds.isValid(b) then
		return nil
	end
	local p = Instance.new(style and style.ClassName or "Part")
	p.Name = name
	p.Size = Bounds.size(b)
	p.CFrame = Bounds.cframe(b, rotation)
	if style and style.Shape then
		p.Shape = style.Shape
	end
	configure(p, style)
	p.Parent = parent
	return p
end

local function wedge(parent, name, b, slope, style)
	return ShapePrimitives.createWedgeInBounds(parent, name, b, slope, function(p)
		configure(p, style)
	end)
end

local function cylinder(parent, name, b, axis, style, tilt)
	local merged = table.clone(style or {})
	merged.Shape = Enum.PartType.Cylinder
	return ShapePrimitives.createCylinderInBounds(parent, name, b, axis, function(p)
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
			pieces[#pieces + 1] = wedge(parent, name .. "_" .. opening.Id .. "_FrontCornerWedge", bounds(wall.X0, wall.X1, y0, y0 + wedgeHeight, opening.Z0, opening.Z0 + corner), ShapePrimitives.wheelWellCornerSlope(side, ShapePrimitives.Direction.Front), style)
			pieces[#pieces + 1] = wedge(parent, name .. "_" .. opening.Id .. "_RearCornerWedge", bounds(wall.X0, wall.X1, y0, y0 + wedgeHeight, opening.Z1 - corner, opening.Z1), ShapePrimitives.wheelWellCornerSlope(side, ShapePrimitives.Direction.Back), style)
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

local function addGlass(parent, name, b, values, rotation)
	local g = part(parent, name, b, {
		Color = Colors.Glass,
		Material = Enum.Material.Glass,
		Transparency = 0.38,
		CanCollide = false,
		Meta = values,
		Tags = { "RVBreakable" },
	}, rotation)
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
				addGlass(glassParent, sideName(side) .. section.Id .. "_WindowGlass", bounds(side * (sideWallX + 0.04) - 0.08, side * (sideWallX + 0.04) + 0.08, opening.Y0, opening.Y1, opening.Z0, opening.Z1), {
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
		part(parent, section.Id .. "_RoofCenter", bounds(-halfWidth + 0.9, halfWidth - 0.9, wallTop, wallTop + dims.RoofThickness, section.Z0, section.Z1), {
			Color = Colors.Body,
			Material = Enum.Material.SmoothPlastic,
			Meta = { ModuleId = section.Id, PartRole = "Roof", Swappable = true, DetachableComponent = true },
			Tags = { "RVBreakable" },
		})
		cylinder(parent, section.Id .. "_RoofLeftShoulder", bounds(-innerSideX - dims.RoofShoulderRadius * 0.5, -innerSideX + dims.RoofShoulderRadius * 0.5, roofY - 0.1 - dims.RoofShoulderRadius * 0.5, roofY - 0.1 + dims.RoofShoulderRadius * 0.5, section.Z0, section.Z1), ShapePrimitives.CylinderAxis.Length, {
			Color = Colors.Body,
			Material = Enum.Material.SmoothPlastic,
			Meta = { ModuleId = section.Id, PartRole = "RoundedRoofShoulder", Swappable = true, DetachableComponent = true },
			Tags = { "RVBreakable" },
		})
		cylinder(parent, section.Id .. "_RoofRightShoulder", bounds(innerSideX - dims.RoofShoulderRadius * 0.5, innerSideX + dims.RoofShoulderRadius * 0.5, roofY - 0.1 - dims.RoofShoulderRadius * 0.5, roofY - 0.1 + dims.RoofShoulderRadius * 0.5, section.Z0, section.Z1), ShapePrimitives.CylinderAxis.Length, {
			Color = Colors.Body,
			Material = Enum.Material.SmoothPlastic,
			Meta = { ModuleId = section.Id, PartRole = "RoundedRoofShoulder", Swappable = true, DetachableComponent = true },
			Tags = { "RVBreakable" },
		})
	end
end

local function buildCab(parent, glassParent, interactables, interior)
	local cab = Config.Sections.Cab
	part(parent, "CabLeftSidePanel", bounds(-7.6, -7.1, 3.35, 10.05, -26.2, -15.4), {
		Color = Colors.Body,
		Meta = { ModuleId = "Cab", PartRole = "CabSidePanel", Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "CabRightSidePanel", bounds(7.1, 7.6, 3.35, 10.05, -26.2, -15.4), {
		Color = Colors.Body,
		Meta = { ModuleId = "Cab", PartRole = "CabSidePanel", Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "CabBackPanel", bounds(-7.05, 7.05, 3.7, 10.1, -15.225, -14.775), {
		Color = Colors.Body,
		Meta = { ModuleId = "Cab", PartRole = "CabBackPanel", Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "CabFrontCowl", bounds(-7.1, 7.1, 3.8, 6.6, -26.8, -26.3), {
		Color = Colors.Body,
		Meta = { ModuleId = "Cab", PartRole = "CabFrontCowl", Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "CabRoofPanel", bounds(-7.2, 7.2, 10.125, 10.575, -26.1, -15.3), {
		Color = Colors.Body,
		Meta = { ModuleId = "Cab", PartRole = "CabRoof", Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "OverCabSleeperShell", bounds(-8.7, 8.7, 12.35, 16.75, -23.35, -9.85), {
		Color = Colors.Body,
		CanCollide = false,
		Meta = { ModuleId = "Cab", PartRole = "OverCabShell", VisualShell = true, Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	wedge(parent, "OverCabFrontSlope", bounds(-8.7, 8.7, 11.45, 14.15, -26.9, -22.7), ShapePrimitives.WedgeSlope.TopBack, {
		Color = Colors.Body,
		CanCollide = false,
		Meta = { ModuleId = "Cab", PartRole = "OverCabFrontSlope", VisualShell = true, Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})

	local hood = wedge(interactables, "Hood", bounds(-6.75, 6.75, 6.775, 7.925, -33.0, -25.0), ShapePrimitives.WedgeSlope.TopBack, {
		Color = Colors.Body,
		Meta = { ModuleId = "Cab", PartRole = "Hood", Interactable = true, Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	prompt(hood, "Hood", 0.15)

	part(parent, "EngineBayFirewall", bounds(-6.7, 6.7, 3.5, 7.7, -24.85, -24.45), {
		Color = Colors.Trim,
		Material = Enum.Material.Metal,
		Meta = { ModuleId = "Cab", PartRole = "EngineBayFirewall", Swappable = true },
	})
	part(parent, "EngineBlock", bounds(-2.1, 2.1, 4.7, 6.2, -30.8, -27.6), {
		Color = Colors.Engine,
		Material = Enum.Material.Metal,
		Meta = { ModuleId = "Cab", PartRole = "Engine", DamageSlot = "Engine", Swappable = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "EngineIntake", bounds(-1.2, 1.2, 6.275, 6.825, -30.2, -28.2), {
		Color = Colors.Metal,
		Material = Enum.Material.Metal,
		Meta = { ModuleId = "Cab", PartRole = "Engine", DamageSlot = "EngineIntake", Swappable = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "EngineLeftHead", bounds(-3.15, -2.05, 5.5, 6.1, -30.9, -27.5), {
		Color = Colors.Metal,
		Material = Enum.Material.Metal,
		Meta = { ModuleId = "Cab", PartRole = "Engine", DamageSlot = "EngineLeftHead", Swappable = true },
		Tags = { "RVBreakable" },
	})
	part(parent, "EngineRightHead", bounds(2.05, 3.15, 5.5, 6.1, -30.9, -27.5), {
		Color = Colors.Metal,
		Material = Enum.Material.Metal,
		Meta = { ModuleId = "Cab", PartRole = "Engine", DamageSlot = "EngineRightHead", Swappable = true },
		Tags = { "RVBreakable" },
	})

	addGlass(glassParent, "Windshield", bounds(-4.9, 4.9, 7.0, 10.1, -26.54, -26.36), { ModuleId = "Cab", PartRole = "WindowGlass", DamageSlot = "Windshield", Swappable = true }, CFrame.Angles(math.rad(-8), 0, 0))
	addGlass(glassParent, "DriverCabWindow", bounds(-7.38, -7.22, 6.85, 9.35, -22.85, -19.55), { ModuleId = "Cab", PartRole = "WindowGlass", DamageSlot = "DriverCabWindow", Swappable = true })
	addGlass(glassParent, "PassengerCabWindow", bounds(7.22, 7.38, 6.85, 9.35, -22.85, -19.55), { ModuleId = "Cab", PartRole = "WindowGlass", DamageSlot = "PassengerCabWindow", Swappable = true })

	local driverSeat = part(interior, "DriverVehicleSeat", bounds(-4.6, -2.0, 3.875, 4.625, -22.0, -19.2), {
		ClassName = "VehicleSeat",
		Color = Colors.Seat,
		Material = Enum.Material.Fabric,
		Meta = { ModuleId = "Cab", PartRole = "DriverVehicleSeat", Swappable = true },
	}, CFrame.Angles(0, math.rad(180), 0))
	driverSeat.MaxSpeed = 0
	driverSeat.Torque = 0

	part(interior, "PassengerSeat", bounds(2.0, 4.6, 3.875, 4.625, -22.0, -19.2), {
		ClassName = "Seat",
		Color = Colors.Seat,
		Material = Enum.Material.Fabric,
		Meta = { ModuleId = "Cab", PartRole = "PassengerSeat", Swappable = true },
	}, CFrame.Angles(0, math.rad(180), 0))

	part(interior, "DriverSeatBack", bounds(-4.65, -1.95, 4.3, 7.1, -19.375, -18.925), { Color = Color3.fromRGB(28, 28, 27), Material = Enum.Material.Fabric, Meta = { ModuleId = "Cab", PartRole = "SeatBack" } })
	part(interior, "PassengerSeatBack", bounds(1.95, 4.65, 4.3, 7.1, -19.375, -18.925), { Color = Color3.fromRGB(28, 28, 27), Material = Enum.Material.Fabric, Meta = { ModuleId = "Cab", PartRole = "SeatBack" } })
	part(interior, "Dashboard", bounds(-6.3, 6.3, 4.825, 5.875, -26.225, -24.875), { Color = Colors.Trim, Meta = { ModuleId = "Cab", PartRole = "Dashboard", Swappable = true } })
	cylinder(interior, "SteeringWheel", bounds(-4.2, -2.4, 5.66, 5.84, -25.65, -23.85), ShapePrimitives.CylinderAxis.Height, { Color = Colors.Tire, CanCollide = false, Meta = { ModuleId = "Cab", PartRole = "SteeringWheel", Swappable = true } }, { Toward = ShapePrimitives.Direction.Back, Degrees = 65 })
	part(interior, "SteeringColumn", bounds(-3.46, -3.14, 5.09, 5.41, -24.975, -23.425), { Color = Colors.Tire, Material = Enum.Material.Metal, CanCollide = false, Meta = { ModuleId = "Cab", PartRole = "SteeringColumn", Swappable = true } }, CFrame.Angles(math.rad(65), 0, 0))

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
			pieces[#pieces + 1] = wedge(parent, sideName(side) .. "_FrontFender_FrontCornerWedge", bounds(x0, x1, wedgeY0, wedgeY0 + wedgeHeight, well.Z0, well.Z0 + well.CornerWedge), ShapePrimitives.wheelWellCornerSlope(side, ShapePrimitives.Direction.Front), style)
			pieces[#pieces + 1] = wedge(parent, sideName(side) .. "_FrontFender_RearCornerWedge", bounds(x0, x1, wedgeY0, wedgeY0 + wedgeHeight, well.Z1 - well.CornerWedge, well.Z1), ShapePrimitives.wheelWellCornerSlope(side, ShapePrimitives.Direction.Back), style)
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
	local doorX = side * (sideWallX + 0.36)
	local door = part(parent, "SideEntryDoor", bounds(doorX - Config.Door.Thickness * 0.5, doorX + Config.Door.Thickness * 0.5, Config.Door.Y0, Config.Door.Y1, Config.Door.Z0, Config.Door.Z1), {
		Color = Colors.Body,
		Meta = { ModuleId = "LivingFront", PartRole = "EntryDoor", Interactable = true, Swappable = true, DetachableComponent = true },
		Tags = { "RVBreakable" },
	})
	prompt(door, "Side Door", 0)
	addGlass(parent, "SideEntryDoorWindow", bounds(side * (sideWallX + 0.64) - 0.06, side * (sideWallX + 0.64) + 0.06, 8.1, 10.3, Config.Door.Z0 + 1.05, Config.Door.Z1 - 1.05), { ModuleId = "LivingFront", PartRole = "WindowGlass", DamageSlot = "SideDoorWindow", Swappable = true })
	part(parent, "SideEntryHandle", bounds(side * (sideWallX + 0.72) - 0.11, side * (sideWallX + 0.72) + 0.11, 6.975, 7.225, Config.Door.Z0 + 0.125, Config.Door.Z0 + 0.775), { Color = Colors.Tire, Material = Enum.Material.Metal, CanCollide = false, Meta = { ModuleId = "LivingFront", PartRole = "DoorHandle", Swappable = true } })
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
					cylinder(wheelModel, "Tire", bounds(x - Config.Wheels.Width * 0.5, x + Config.Wheels.Width * 0.5, 3.2 - Config.Wheels.Radius, 3.2 + Config.Wheels.Radius, z - Config.Wheels.Radius, z + Config.Wheels.Radius), ShapePrimitives.CylinderAxis.Width, {
						Color = Colors.Tire,
						Material = Enum.Material.SmoothPlastic,
						Meta = { ModuleId = group.ModuleId, PartRole = "Wheel", DamageSlot = wheelModel.Name, Swappable = true },
						Tags = { "RVBreakable" },
					})
					cylinder(wheelModel, "Rim", bounds(x - (Config.Wheels.Width + 0.1) * 0.5, x + (Config.Wheels.Width + 0.1) * 0.5, 3.2 - 1.375, 3.2 + 1.375, z - 1.375, z + 1.375), ShapePrimitives.CylinderAxis.Width, {
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

local function addLight(parent, name, b, lightColor, lightType)
	local p = part(parent, name, b, {
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
	addLight(parent, "HeadlightLeft", bounds(-4.675, -3.525, 5.175, 5.725, -33.875, -33.625), Colors.Headlamp, "Headlamp")
	addLight(parent, "HeadlightRight", bounds(3.525, 4.675, 5.175, 5.725, -33.875, -33.625), Colors.Headlamp, "Headlamp")
	addLight(parent, "BlinkerFrontLeft", bounds(-6.575, -5.925, 4.81, 5.19, -33.875, -33.625), Colors.Amber, "Blinker")
	addLight(parent, "BlinkerFrontRight", bounds(5.925, 6.575, 4.81, 5.19, -33.875, -33.625), Colors.Amber, "Blinker")
	addLight(parent, "TaillightLeft", bounds(-6.975, -6.225, 5.3, 6.3, 30.825, 31.075), Colors.Red, "Brake")
	addLight(parent, "TaillightRight", bounds(6.225, 6.975, 5.3, 6.3, 30.825, 31.075), Colors.Red, "Brake")
	addLight(parent, "BlinkerRearLeft", bounds(-8.075, -7.425, 4.775, 5.225, 30.825, 31.075), Colors.Amber, "Blinker")
	addLight(parent, "BlinkerRearRight", bounds(7.425, 8.075, 4.775, 5.225, 30.825, 31.075), Colors.Amber, "Blinker")
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -10.5, 5.5, 21.5 }) do
			local x = side * (sideWallX + 0.08)
			addLight(parent, "Marker_" .. sideName(side) .. "_" .. tostring(z), bounds(x - 0.08, x + 0.08, 13.875, 14.225, z - 0.325, z + 0.325), Colors.Amber, "Marker")
		end
	end
end

local function buildLadder(parent)
	local x0 = sideWallX - 1.5
	local x1 = sideWallX - 0.25
	local z0 = Config.Sections.LivingRear.Z1 + 0.22
	for _, x in ipairs({ x0, x1 }) do
		part(parent, "RearLadderRail_" .. tostring(x), bounds(x - 0.06, x + 0.06, 3.2, 13.7, z0 - 0.08, z0 + 0.08), {
			Color = Colors.Metal,
			Material = Enum.Material.Metal,
			Meta = { ModuleId = "LivingRear", PartRole = "Ladder", DamageSlot = "RearLadder", Swappable = true, DetachableComponent = true },
			Tags = { "RVBreakable" },
		})
	end
	for y = 3.6, 13.3, 1.15 do
		part(parent, "RearLadderRung_" .. tostring(math.floor(y * 10)), bounds(x0, x1, y - 0.06, y + 0.06, z0 - 0.09, z0 + 0.09), {
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
	rv:SetAttribute("SourceOfTruth", "W:\\Dead Camp\\src\\server\\Build_RV_BaseCamp.server.luau")
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

local chassis = part(folders.Chassis, "MainChassis", bounds(-8.6, 8.6, dims.ChassisY - 0.5, dims.ChassisY + 0.5, -28.75, 28.75), {
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
addGlass(folders.Glass, "RearWindow", bounds(-2.6, 2.6, 9.35, 11.75, 30.64, 30.8), { ModuleId = "LivingRear", PartRole = "WindowGlass", DamageSlot = "RearWindow", Swappable = true })
buildRoof(folders.Roof)
buildDoor(folders.Interactables)
buildWheels(folders.Wheels)
buildLights(folders.Lights)
buildLadder(folders.Body)
part(folders.Chassis, "FrontBumper", bounds(-8.1, 8.1, 2.425, 3.275, -33.7, -32.8), {
	Color = Colors.Metal,
	Material = Enum.Material.Metal,
	Meta = { PartRole = "FrontBumper", DamageSlot = "FrontBumper", Swappable = true, DetachableComponent = true },
	Tags = { "RVBreakable" },
})
part(folders.Chassis, "RearBumper", bounds(-8.6, 8.6, 2.425, 3.275, 30.9, 31.8), {
	Color = Colors.Metal,
	Material = Enum.Material.Metal,
	Meta = { PartRole = "RearBumper", DamageSlot = "RearBumper", Swappable = true, DetachableComponent = true },
	Tags = { "RVBreakable" },
})
buildInteractions(rv)
addMetadata(rv)
rv:PivotTo(CFrame.new(0, 0, 0))

print("Built " .. OUTPUT_NAME .. " from repaired source-of-truth builder.")
