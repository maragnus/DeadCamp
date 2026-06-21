-- Reusable wall, opening, and wheel-box construction.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounds = require(Shared:WaitForChild("RVBounds"))
local ShapePrimitives = require(Shared:WaitForChild("RVShapePrimitives"))

local Panels = {}

function Panels.sideName(side)
	return side < 0 and "Left" or "Right"
end

local function panelStyle(section, role)
	return {
		Color = section.PanelColor or "Body",
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

local function sortedEdges(minValue, maxValue, openings, axis)
	local edges = { minValue, maxValue }
	for _, opening in ipairs(openings or {}) do
		local lower = math.max(minValue, opening[axis .. "0"])
		local upper = math.min(maxValue, opening[axis .. "1"])
		if upper > lower then
			edges[#edges + 1] = lower
			edges[#edges + 1] = upper
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

local function clippedWheelCornerBounds(wall, wedgeY0, wedgeY1, z0, z1)
	local clippedZ0 = math.max(wall.Z0, z0)
	local clippedZ1 = math.min(wall.Z1, z1)
	if clippedZ1 <= clippedZ0 then
		return nil
	end

	return Bounds.new(wall.X0, wall.X1, wedgeY0, wedgeY1, clippedZ0, clippedZ1)
end

function Panels.wheelOpening(dimensions, section, group, side)
	local radius = group.Radius or dimensions.WheelRadius
	local clearance = group.WellClearance or dimensions.WheelWellClearance
	local axleCount = group.AxleCount or 1
	local axleSpacing = group.AxleSpacing or radius * 0.62
	local halfAxleSpan = (axleCount - 1) * axleSpacing * 0.5

	return {
		Id = group.Id,
		Kind = "WheelWell",
		ModuleId = section.Id,
		Side = side,
		Z0 = group.Z - halfAxleSpan - radius - clearance,
		Z1 = group.Z + halfAxleSpan + radius + clearance,
		Y0 = dimensions.BodyBottom,
		Y1 = dimensions.WheelCenterY + radius + clearance,
		CornerWedge = dimensions.WheelWellCorner,
	}
end

local function sideOuterXBounds(dimensions, options)
	local halfWidth = dimensions.Width * 0.5
	local outerLeft = options and options.X0 or -halfWidth
	local outerRight = options and options.X1 or halfWidth
	return outerLeft, outerRight
end

local function sideWallXBounds(dimensions, side, options)
	local outerLeft, outerRight = sideOuterXBounds(dimensions, options)
	if side < 0 then
		return outerLeft, outerLeft + dimensions.SideWallThickness
	end
	return outerRight - dimensions.SideWallThickness, outerRight
end

function Panels.wheelTubInnerHalfWidth(dimensions)
	return dimensions.Width * 0.5 - dimensions.SideWallThickness - dimensions.WheelTubDepth
end

function Panels.sideFlushBounds(dimensions, side, y0, y1, z0, z1, thickness, options)
	local mountThickness = thickness or dimensions.GlassThickness
	local outerLeft, outerRight = sideOuterXBounds(dimensions, options)
	local x0 = side < 0 and outerLeft or outerRight - mountThickness
	local x1 = side < 0 and outerLeft + mountThickness or outerRight
	return Bounds.new(x0, x1, y0, y1, z0, z1)
end

function Panels.sideOutsetBounds(dimensions, side, y0, y1, z0, z1, thickness, options)
	local mountThickness = thickness or dimensions.TrimThickness
	local outerLeft, outerRight = sideOuterXBounds(dimensions, options)
	local x0 = side < 0 and outerLeft - mountThickness or outerRight
	local x1 = side < 0 and outerLeft or outerRight + mountThickness
	return Bounds.new(x0, x1, y0, y1, z0, z1)
end

function Panels.buildSidePanel(builder, parent, name, side, section, openings, options)
	local dimensions = builder.Config.Dimensions
	local y0 = options and options.Y0 or dimensions.BodyBottom
	local y1 = options and options.Y1 or dimensions.WallTop
	local z0 = options and options.Z0 or section.Z0
	local z1 = options and options.Z1 or section.Z1
	local wall = Panels.sideFlushBounds(dimensions, side, y0, y1, z0, z1, dimensions.SideWallThickness, options)
	local pieces = {}
	local zEdges = sortedEdges(wall.Z0, wall.Z1, openings, "Z")
	local yEdges = sortedEdges(wall.Y0, wall.Y1, openings, "Y")

	for zi = 1, #zEdges - 1 do
		for yi = 1, #yEdges - 1 do
			local pieceZ0 = zEdges[zi]
			local pieceZ1 = zEdges[zi + 1]
			local pieceY0 = yEdges[yi]
			local pieceY1 = yEdges[yi + 1]
			local centerZ = (pieceZ0 + pieceZ1) * 0.5
			local centerY = (pieceY0 + pieceY1) * 0.5
			local blocked = false

			for _, opening in ipairs(openings or {}) do
				if containsZY(opening, centerZ, centerY) then
					blocked = true
					break
				end
			end

			if not blocked then
				pieces[#pieces + 1] = builder:part(
					parent,
					name .. "_Panel",
					Bounds.new(wall.X0, wall.X1, pieceY0, pieceY1, pieceZ0, pieceZ1),
					panelStyle(section, Panels.sideName(side) .. "SidePanel")
				)
			end
		end
	end

	for _, opening in ipairs(openings or {}) do
		if opening.Kind == "WheelWell" then
			local wedgeLength = opening.CornerWedge
			local wedgeHeight = math.min(wedgeLength, (opening.Y1 - opening.Y0) * 0.72)
			local wedgeY0 = opening.Y1 - wedgeHeight
			local style = panelStyle(section, Panels.sideName(side) .. "WheelWellCorner")
			local frontCornerBounds = clippedWheelCornerBounds(wall, wedgeY0, wedgeY0 + wedgeHeight, opening.Z0, opening.Z0 + wedgeLength)
			local rearCornerBounds = clippedWheelCornerBounds(wall, wedgeY0, wedgeY0 + wedgeHeight, opening.Z1 - wedgeLength, opening.Z1)

			if frontCornerBounds then
				pieces[#pieces + 1] = builder:wedge(
					parent,
					name .. "_" .. opening.Id .. "_FrontCornerWedge",
					frontCornerBounds,
					ShapePrimitives.wheelWellCornerSlopeFace(ShapePrimitives.Direction.Front),
					style
				)
			end
			if rearCornerBounds then
				pieces[#pieces + 1] = builder:wedge(
					parent,
					name .. "_" .. opening.Id .. "_RearCornerWedge",
					rearCornerBounds,
					ShapePrimitives.wheelWellCornerSlopeFace(ShapePrimitives.Direction.Back),
					style
				)
			end
		end
	end

	return builder:tryUnion(parent, name, pieces, {
		ModuleId = section.Id,
		PartRole = Panels.sideName(side) .. "SidePanel",
		WheelWellRule = "wall before/after, wall above, wedge corners, boxed interior",
		Swappable = true,
		DetachableComponent = true,
	})
end

function Panels.buildEndPanel(builder, parent, name, section, z0, z1, openings, options)
	local dimensions = builder.Config.Dimensions
	local halfWidth = dimensions.Width * 0.5
	local x0 = options and options.X0 or -halfWidth
	local x1 = options and options.X1 or halfWidth
	local y0 = options and options.Y0 or dimensions.BodyBottom
	local y1 = options and options.Y1 or dimensions.WallTop
	local wall = Bounds.new(x0, x1, y0, y1, z0, z1)
	local pieces = {}
	local panelOpenings = {}
	local topCornerRadius = nil
	for _, opening in ipairs(openings or {}) do
		panelOpenings[#panelOpenings + 1] = opening
	end

	if options and options.TopCornerStartY then
		topCornerRadius = math.max(0, wall.Y1 - options.TopCornerStartY)
	elseif options and options.TopCornerRadius then
		topCornerRadius = options.TopCornerRadius
	end

	if topCornerRadius and topCornerRadius > 0 then
		local radius = topCornerRadius
		panelOpenings[#panelOpenings + 1] = {
			Id = "LeftTopCorner",
			Kind = "Opening",
			X0 = wall.X0,
			X1 = wall.X0 + radius,
			Y0 = wall.Y1 - radius,
			Y1 = wall.Y1,
		}
		panelOpenings[#panelOpenings + 1] = {
			Id = "RightTopCorner",
			Kind = "Opening",
			X0 = wall.X1 - radius,
			X1 = wall.X1,
			Y0 = wall.Y1 - radius,
			Y1 = wall.Y1,
		}
	end

	local xEdges = sortedEdges(wall.X0, wall.X1, panelOpenings, "X")
	local yEdges = sortedEdges(wall.Y0, wall.Y1, panelOpenings, "Y")

	for xi = 1, #xEdges - 1 do
		for yi = 1, #yEdges - 1 do
			local pieceX0 = xEdges[xi]
			local pieceX1 = xEdges[xi + 1]
			local pieceY0 = yEdges[yi]
			local pieceY1 = yEdges[yi + 1]
			local centerX = (pieceX0 + pieceX1) * 0.5
			local centerY = (pieceY0 + pieceY1) * 0.5
			local blocked = false

			for _, opening in ipairs(panelOpenings) do
				if containsXY(opening, centerX, centerY) then
					blocked = true
					break
				end
			end

			if not blocked then
				pieces[#pieces + 1] = builder:part(
					parent,
					name .. "_Panel",
					Bounds.new(pieceX0, pieceX1, pieceY0, pieceY1, wall.Z0, wall.Z1),
					panelStyle(section, name)
				)
			end
		end
	end

	if topCornerRadius and topCornerRadius > 0 then
		local radius = topCornerRadius
		local style = panelStyle(section, name .. "RoundedCorner")
		pieces[#pieces + 1] = builder:wedge(parent, name .. "_LeftTopRound", Bounds.new(
			wall.X0,
			wall.X0 + radius,
			wall.Y1 - radius,
			wall.Y1,
			wall.Z0,
			wall.Z1
		), ShapePrimitives.WedgeSlopeFace.TopLeft, style)
		pieces[#pieces + 1] = builder:wedge(parent, name .. "_RightTopRound", Bounds.new(
			wall.X1 - radius,
			wall.X1,
			wall.Y1 - radius,
			wall.Y1,
			wall.Z0,
			wall.Z1
		), ShapePrimitives.WedgeSlopeFace.TopRight, style)
	end

	return builder:tryUnion(parent, name, pieces, {
		ModuleId = section.Id,
		PartRole = name,
		Swappable = true,
		DetachableComponent = true,
	})
end

function Panels.addWheelTub(builder, parent, well, options)
	local dimensions = builder.Config.Dimensions
	local side = well.Side
	local wallX0, wallX1 = sideWallXBounds(dimensions, side, options)
	local skinInnerX = side < 0 and wallX1 or wallX0
	local tubInnerHalfWidth = Panels.wheelTubInnerHalfWidth(dimensions)
	local tubInnerX = side < 0 and -tubInnerHalfWidth or tubInnerHalfWidth
	local x0 = math.min(skinInnerX, tubInnerX)
	local x1 = math.max(skinInnerX, tubInnerX)
	local thickness = dimensions.WheelTubThickness
	local innerX0 = tubInnerX - thickness * 0.5
	local innerX1 = tubInnerX + thickness * 0.5
	local topX0 = side < 0 and skinInnerX or innerX0
	local topX1 = side < 0 and innerX1 or skinInnerX
	local prefix = well.Id .. "_" .. Panels.sideName(side) .. "_WheelBox"
	local style = {
		Color = "Trim",
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

	builder:part(parent, prefix .. "_InnerWall", Bounds.new(innerX0, innerX1, dimensions.FloorTop, well.Y1, well.Z0 - thickness, well.Z1 + thickness), style)
	-- Keep the top cap fully above the opening plane so the carved wheel arch
	-- only reveals the side walls and rounded corners.
	builder:part(parent, prefix .. "_Top", Bounds.new(topX0, topX1, well.Y1, well.Y1 + thickness, well.Z0 - thickness, well.Z1 + thickness), style)
	-- Keep the entire end-cap thickness behind the wheel opening plane so only
	-- the side walls remain visible through the carved opening.
	builder:part(parent, prefix .. "_FrontWall", Bounds.new(x0, x1, dimensions.FloorTop, well.Y1, well.Z0 - thickness, well.Z0), style)
	builder:part(parent, prefix .. "_RearWall", Bounds.new(x0, x1, dimensions.FloorTop, well.Y1, well.Z1, well.Z1 + thickness), style)
end

return Panels
