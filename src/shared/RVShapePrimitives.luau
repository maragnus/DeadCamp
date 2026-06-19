-- Prescriptive shape helpers for Roblox primitives whose default rotations are easy to misuse.
-- Coordinate convention: X = width, Y = height, Z = length; negative Z is vehicle front.

local Bounds = require(script.Parent:WaitForChild("RVBounds"))

local RVShapePrimitives = {}

RVShapePrimitives.Direction = {
	Left = "Left",
	Right = "Right",
	Top = "Top",
	Bottom = "Bottom",
	Front = "Front",
	Back = "Back",
}

RVShapePrimitives.WedgeSlope = {
	-- Matches the reference Workspace.Wedge: triangular side visible on the right,
	-- bottom is flat, back is vertical, and the diagonal face runs between top/front.
	TopFront = "TopFront",
	TopBack = "TopBack",
	TopLeft = "TopLeft",
	TopRight = "TopRight",
}

RVShapePrimitives.CylinderAxis = {
	Width = "Width",
	Height = "Height",
	Length = "Length",
}

local WEDGE_ROTATIONS = {
	[RVShapePrimitives.WedgeSlope.TopFront] = CFrame.new(),
	[RVShapePrimitives.WedgeSlope.TopBack] = CFrame.Angles(math.rad(180), 0, 0),
	[RVShapePrimitives.WedgeSlope.TopLeft] = CFrame.Angles(0, math.rad(90), 0),
	[RVShapePrimitives.WedgeSlope.TopRight] = CFrame.Angles(0, math.rad(-90), 0),
}

local CYLINDER_AXIS_ROTATIONS = {
	[RVShapePrimitives.CylinderAxis.Height] = CFrame.new(),
	[RVShapePrimitives.CylinderAxis.Width] = CFrame.Angles(0, 0, math.rad(90)),
	[RVShapePrimitives.CylinderAxis.Length] = CFrame.Angles(math.rad(90), 0, 0),
}

local function wedgeSizeFromBounds(bounds, slope)
	local size = Bounds.size(bounds)
	if slope == RVShapePrimitives.WedgeSlope.TopLeft or slope == RVShapePrimitives.WedgeSlope.TopRight then
		return Vector3.new(size.Z, size.Y, size.X)
	end
	return size
end

local function cylinderSizeFromBounds(bounds, axis)
	local size = Bounds.size(bounds)
	if axis == RVShapePrimitives.CylinderAxis.Width then
		return Vector3.new(size.Y, size.X, size.Z)
	elseif axis == RVShapePrimitives.CylinderAxis.Length then
		return Vector3.new(size.X, size.Z, size.Y)
	end
	return size
end

local function requiredRotation(rotation, value, kind)
	if not rotation then
		error(("Unknown %s orientation: %s"):format(kind, tostring(value)), 3)
	end
	return rotation
end

local function tiltRotation(axis, tilt)
	if not tilt then
		return CFrame.new()
	end

	if axis ~= RVShapePrimitives.CylinderAxis.Height then
		error("Cylinder tilt currently supports Height axis only; add the needed case here before using it.", 3)
	end

	local degrees = tilt.Degrees or 0
	local toward = tilt.Toward
	if toward == RVShapePrimitives.Direction.Back then
		return CFrame.Angles(math.rad(degrees), 0, 0)
	elseif toward == RVShapePrimitives.Direction.Front then
		return CFrame.Angles(math.rad(-degrees), 0, 0)
	elseif toward == RVShapePrimitives.Direction.Left then
		return CFrame.Angles(0, 0, math.rad(degrees))
	elseif toward == RVShapePrimitives.Direction.Right then
		return CFrame.Angles(0, 0, math.rad(-degrees))
	end

	error(("Unknown cylinder tilt direction: %s"):format(tostring(toward)), 3)
end

function RVShapePrimitives.wedgeCFrameFromBounds(bounds, slope)
	return Bounds.cframe(bounds, requiredRotation(WEDGE_ROTATIONS[slope], slope, "wedge"))
end

function RVShapePrimitives.cylinderCFrameFromBounds(bounds, axis, tilt)
	local axisRotation = requiredRotation(CYLINDER_AXIS_ROTATIONS[axis], axis, "cylinder axis")
	return Bounds.cframe(bounds, axisRotation * tiltRotation(axis, tilt))
end

function RVShapePrimitives.wheelWellCornerSlope(side, edge)
	local leftSide = side == -1 or side == RVShapePrimitives.Direction.Left
	if edge == RVShapePrimitives.Direction.Front then
		return leftSide and RVShapePrimitives.WedgeSlope.TopFront or RVShapePrimitives.WedgeSlope.TopBack
	elseif edge == RVShapePrimitives.Direction.Back then
		return leftSide and RVShapePrimitives.WedgeSlope.TopBack or RVShapePrimitives.WedgeSlope.TopFront
	end

	error(("Wheel well corner edge must be Front or Back, got %s"):format(tostring(edge)), 2)
end

local function applyAndParent(part, parent, configure)
	if configure then
		configure(part)
	end
	part.Parent = parent
	return part
end

function RVShapePrimitives.createWedgeInBounds(parent, name, bounds, slope, configure)
	if not Bounds.isValid(bounds) then
		return nil
	end

	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = wedgeSizeFromBounds(bounds, slope)
	part.CFrame = RVShapePrimitives.wedgeCFrameFromBounds(bounds, slope)
	return applyAndParent(part, parent, configure)
end

function RVShapePrimitives.createCylinderInBounds(parent, name, bounds, axis, configure, tilt)
	if not Bounds.isValid(bounds) then
		return nil
	end

	local part = Instance.new("Part")
	part.Name = name
	part.Size = cylinderSizeFromBounds(bounds, axis)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = RVShapePrimitives.cylinderCFrameFromBounds(bounds, axis, tilt)
	return applyAndParent(part, parent, configure)
end

return RVShapePrimitives
