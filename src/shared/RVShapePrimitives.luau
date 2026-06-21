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

RVShapePrimitives.WedgeSlopeFace = {
	-- Names describe the diagonal face direction, not the retained solid corner.
	-- TopFront matches the reference Workspace.Wedge: triangular side visible on
	-- the right, bottom is flat, back is vertical, and the diagonal face runs
	-- between top/front.
	TopLeft = "TopLeft",
	TopFront = "TopFront",
	TopRight = "TopRight",
	TopBack = "TopBack",
	BottomLeft = "BottomLeft",
	BottomFront = "BottomFront",
	BottomRight = "BottomRight",
	BottomBack = "BottomBack",
}

RVShapePrimitives.WedgeSolidCorner = {
	-- Names describe the box corner that remains solid. The sloped face is the
	-- opposite diagonal direction. Values are distinct from WedgeSlopeFace so
	-- call sites fail loudly if the wrong enum is passed to wedge().
	TopLeft = "SolidCornerTopLeft",
	TopFront = "SolidCornerTopFront",
	TopRight = "SolidCornerTopRight",
	TopBack = "SolidCornerTopBack",
	BottomLeft = "SolidCornerBottomLeft",
	BottomFront = "SolidCornerBottomFront",
	BottomRight = "SolidCornerBottomRight",
	BottomBack = "SolidCornerBottomBack",
}

-- Compatibility alias for older call sites. Prefer WedgeSlopeFace for new code.
RVShapePrimitives.WedgeSlope = RVShapePrimitives.WedgeSlopeFace

RVShapePrimitives.CylinderAxis = {
	Width = "Width",
	Height = "Height",
	Length = "Length",
}

local DIRECTION_VECTORS = {
	[RVShapePrimitives.Direction.Left] = Vector3.new(-1, 0, 0),
	[RVShapePrimitives.Direction.Right] = Vector3.new(1, 0, 0),
	[RVShapePrimitives.Direction.Top] = Vector3.new(0, 1, 0),
	[RVShapePrimitives.Direction.Bottom] = Vector3.new(0, -1, 0),
	[RVShapePrimitives.Direction.Front] = Vector3.new(0, 0, -1),
	[RVShapePrimitives.Direction.Back] = Vector3.new(0, 0, 1),
}

local OPPOSITE_DIRECTION = {
	[RVShapePrimitives.Direction.Left] = RVShapePrimitives.Direction.Right,
	[RVShapePrimitives.Direction.Right] = RVShapePrimitives.Direction.Left,
	[RVShapePrimitives.Direction.Top] = RVShapePrimitives.Direction.Bottom,
	[RVShapePrimitives.Direction.Bottom] = RVShapePrimitives.Direction.Top,
	[RVShapePrimitives.Direction.Front] = RVShapePrimitives.Direction.Back,
	[RVShapePrimitives.Direction.Back] = RVShapePrimitives.Direction.Front,
}

local WEDGE_DIAGONAL_DIRECTIONS = {
	[RVShapePrimitives.WedgeSlopeFace.TopLeft] = {
		Vertical = RVShapePrimitives.Direction.Top,
		Horizontal = RVShapePrimitives.Direction.Left,
	},
	[RVShapePrimitives.WedgeSlopeFace.TopFront] = {
		Vertical = RVShapePrimitives.Direction.Top,
		Horizontal = RVShapePrimitives.Direction.Front,
	},
	[RVShapePrimitives.WedgeSlopeFace.TopRight] = {
		Vertical = RVShapePrimitives.Direction.Top,
		Horizontal = RVShapePrimitives.Direction.Right,
	},
	[RVShapePrimitives.WedgeSlopeFace.TopBack] = {
		Vertical = RVShapePrimitives.Direction.Top,
		Horizontal = RVShapePrimitives.Direction.Back,
	},
	[RVShapePrimitives.WedgeSlopeFace.BottomLeft] = {
		Vertical = RVShapePrimitives.Direction.Bottom,
		Horizontal = RVShapePrimitives.Direction.Left,
	},
	[RVShapePrimitives.WedgeSlopeFace.BottomFront] = {
		Vertical = RVShapePrimitives.Direction.Bottom,
		Horizontal = RVShapePrimitives.Direction.Front,
	},
	[RVShapePrimitives.WedgeSlopeFace.BottomRight] = {
		Vertical = RVShapePrimitives.Direction.Bottom,
		Horizontal = RVShapePrimitives.Direction.Right,
	},
	[RVShapePrimitives.WedgeSlopeFace.BottomBack] = {
		Vertical = RVShapePrimitives.Direction.Bottom,
		Horizontal = RVShapePrimitives.Direction.Back,
	},
}

local WEDGE_SOLID_CORNER_DIRECTIONS = {}
for key, solidCorner in pairs(RVShapePrimitives.WedgeSolidCorner) do
	WEDGE_SOLID_CORNER_DIRECTIONS[solidCorner] = WEDGE_DIAGONAL_DIRECTIONS[RVShapePrimitives.WedgeSlopeFace[key]]
end

local function directionPairKey(vertical, horizontal)
	return vertical .. horizontal
end

local function wedgeRotationFromDirections(directions)
	local up = DIRECTION_VECTORS[directions.Vertical]
	local front = DIRECTION_VECTORS[directions.Horizontal]
	local back = -front
	local right = up:Cross(back)
	return CFrame.fromMatrix(Vector3.new(0, 0, 0), right, up, back)
end

local WEDGE_ROTATIONS = {}
for slopeFace, directions in pairs(WEDGE_DIAGONAL_DIRECTIONS) do
	WEDGE_ROTATIONS[slopeFace] = wedgeRotationFromDirections(directions)
end

local CYLINDER_AXIS_ROTATIONS = {
	[RVShapePrimitives.CylinderAxis.Width] = CFrame.new(),
	[RVShapePrimitives.CylinderAxis.Height] = CFrame.Angles(0, 0, math.rad(90)),
	[RVShapePrimitives.CylinderAxis.Length] = CFrame.Angles(0, math.rad(-90), 0),
}

local function wedgeSizeFromBounds(bounds, slopeFace)
	local size = Bounds.size(bounds)
	local directions = WEDGE_DIAGONAL_DIRECTIONS[slopeFace]
	if not directions then
		error(("Unknown wedge slope face: %s"):format(tostring(slopeFace)), 3)
	end

	if directions.Horizontal == RVShapePrimitives.Direction.Left or directions.Horizontal == RVShapePrimitives.Direction.Right then
		return Vector3.new(size.Z, size.Y, size.X)
	end
	return size
end

local function cylinderSizeFromBounds(bounds, axis)
	local size = Bounds.size(bounds)
	if axis == RVShapePrimitives.CylinderAxis.Height then
		return Vector3.new(size.Y, size.X, size.Z)
	elseif axis == RVShapePrimitives.CylinderAxis.Length then
		return Vector3.new(size.Z, size.Y, size.X)
	end
	return size
end

local function requiredRotation(rotation, value, kind)
	if not rotation then
		error(("Unknown %s orientation: %s"):format(kind, tostring(value)), 3)
	end
	return rotation
end

function RVShapePrimitives.pitchToward(toward, degrees)
	-- Positive X pitch tilts a part's local top toward +Z. In vehicle space,
	-- +Z is back and -Z is front, so callers should name the direction instead
	-- of hand-picking a CFrame.Angles sign.
	degrees = degrees or 0
	if toward == RVShapePrimitives.Direction.Back then
		return CFrame.Angles(math.rad(degrees), 0, 0)
	elseif toward == RVShapePrimitives.Direction.Front then
		return CFrame.Angles(math.rad(-degrees), 0, 0)
	end

	error(("Pitch direction must be Front or Back, got %s"):format(tostring(toward)), 2)
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
		return RVShapePrimitives.pitchToward(toward, degrees)
	elseif toward == RVShapePrimitives.Direction.Front then
		return RVShapePrimitives.pitchToward(toward, degrees)
	elseif toward == RVShapePrimitives.Direction.Left then
		return CFrame.Angles(0, 0, math.rad(degrees))
	elseif toward == RVShapePrimitives.Direction.Right then
		return CFrame.Angles(0, 0, math.rad(-degrees))
	end

	error(("Unknown cylinder tilt direction: %s"):format(tostring(toward)), 3)
end

local function explicitCylinderRotation(orientation)
	if type(orientation) == "table" and typeof(orientation.Rotation) == "CFrame" then
		return orientation.Rotation
	end
	return nil
end

function RVShapePrimitives.wedgeSlopeFaceForSolidCorner(solidCorner)
	local directions = WEDGE_SOLID_CORNER_DIRECTIONS[solidCorner]
	if not directions then
		error(("Unknown wedge solid corner: %s"):format(tostring(solidCorner)), 2)
	end

	local slopeFaceKey = directionPairKey(
		OPPOSITE_DIRECTION[directions.Vertical],
		OPPOSITE_DIRECTION[directions.Horizontal]
	)
	return RVShapePrimitives.WedgeSlopeFace[slopeFaceKey]
end

function RVShapePrimitives.wedgeCFrameFromBounds(bounds, slopeFace, rotation)
	return Bounds.cframe(bounds, (rotation or CFrame.new()) * requiredRotation(WEDGE_ROTATIONS[slopeFace], slopeFace, "wedge"))
end

function RVShapePrimitives.cylinderCFrameFromBounds(bounds, axis, orientation)
	local explicitRotation = explicitCylinderRotation(orientation)
	if explicitRotation then
		return Bounds.cframe(bounds, explicitRotation)
	end

	local axisRotation = requiredRotation(CYLINDER_AXIS_ROTATIONS[axis], axis, "cylinder axis")
	return Bounds.cframe(bounds, tiltRotation(axis, orientation) * axisRotation)
end

function RVShapePrimitives.wheelWellCornerSlopeFace(edge)
	-- Wheel-well corner wedges are solid filler pieces. The front corner keeps
	-- the upper/front material and cuts away bottom/back; the rear corner keeps
	-- the upper/back material and cuts away bottom/front.
	if edge == RVShapePrimitives.Direction.Front then
		return RVShapePrimitives.WedgeSlopeFace.BottomBack
	elseif edge == RVShapePrimitives.Direction.Back then
		return RVShapePrimitives.WedgeSlopeFace.BottomFront
	end

	error(("Wheel well corner edge must be Front or Back, got %s"):format(tostring(edge)), 2)
end

function RVShapePrimitives.wheelWellCornerSlope(sideOrEdge, maybeEdge)
	return RVShapePrimitives.wheelWellCornerSlopeFace(maybeEdge or sideOrEdge)
end

local function applyAndParent(part, parent, configure)
	if configure then
		configure(part)
	end
	part.Parent = parent
	return part
end

function RVShapePrimitives.createWedgeInBounds(parent, name, bounds, slopeFace, configure, rotation)
	if not Bounds.isValid(bounds) then
		return nil
	end

	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = wedgeSizeFromBounds(bounds, slopeFace)
	part.CFrame = RVShapePrimitives.wedgeCFrameFromBounds(bounds, slopeFace, rotation)
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
