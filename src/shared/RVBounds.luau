-- Axis-aligned bounding boxes for Roblox geometry placement.
-- Coordinate convention: X = width, Y = height, Z = length; negative Z is vehicle front.

local RVBounds = {}

function RVBounds.new(x0, x1, y0, y1, z0, z1)
	return {
		X0 = math.min(x0, x1),
		X1 = math.max(x0, x1),
		Y0 = math.min(y0, y1),
		Y1 = math.max(y0, y1),
		Z0 = math.min(z0, z1),
		Z1 = math.max(z0, z1),
	}
end

function RVBounds.center(bounds)
	return Vector3.new(
		(bounds.X0 + bounds.X1) * 0.5,
		(bounds.Y0 + bounds.Y1) * 0.5,
		(bounds.Z0 + bounds.Z1) * 0.5
	)
end

function RVBounds.size(bounds)
	return Vector3.new(
		math.max(0.001, bounds.X1 - bounds.X0),
		math.max(0.001, bounds.Y1 - bounds.Y0),
		math.max(0.001, bounds.Z1 - bounds.Z0)
	)
end

function RVBounds.isValid(bounds)
	return bounds.X1 > bounds.X0 and bounds.Y1 > bounds.Y0 and bounds.Z1 > bounds.Z0
end

function RVBounds.cframe(bounds, rotation)
	return CFrame.new(RVBounds.center(bounds)) * (rotation or CFrame.new())
end

function RVBounds.offset(bounds, dx, dy, dz)
	return RVBounds.new(
		bounds.X0 + dx,
		bounds.X1 + dx,
		bounds.Y0 + dy,
		bounds.Y1 + dy,
		bounds.Z0 + dz,
		bounds.Z1 + dz
	)
end

return RVBounds
