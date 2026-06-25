local GeometryDirections = {
	Left = "Left",
	Right = "Right",
	Top = "Top",
	Bottom = "Bottom",
	Front = "Front",
	Back = "Back",
}

local DIRECTION_VECTORS = {
	[GeometryDirections.Left] = Vector3.new(-1, 0, 0),
	[GeometryDirections.Right] = Vector3.new(1, 0, 0),
	[GeometryDirections.Top] = Vector3.new(0, 1, 0),
	[GeometryDirections.Bottom] = Vector3.new(0, -1, 0),
	[GeometryDirections.Front] = Vector3.new(0, 0, -1),
	[GeometryDirections.Back] = Vector3.new(0, 0, 1),
}

local OPPOSITES = {
	[GeometryDirections.Left] = GeometryDirections.Right,
	[GeometryDirections.Right] = GeometryDirections.Left,
	[GeometryDirections.Top] = GeometryDirections.Bottom,
	[GeometryDirections.Bottom] = GeometryDirections.Top,
	[GeometryDirections.Front] = GeometryDirections.Back,
	[GeometryDirections.Back] = GeometryDirections.Front,
}

function GeometryDirections.toVector(direction)
	local vector = DIRECTION_VECTORS[direction]
	if not vector then
		error(("Unknown geometry direction: %s"):format(tostring(direction)), 2)
	end

	return vector
end

function GeometryDirections.opposite(direction)
	local opposite = OPPOSITES[direction]
	if not opposite then
		error(("Unknown geometry direction: %s"):format(tostring(direction)), 2)
	end

	return opposite
end

return GeometryDirections
