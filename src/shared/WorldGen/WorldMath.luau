local WorldMath = {}

local EPSILON = 1e-4

function WorldMath.clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

function WorldMath.lerp(a, b, alpha)
	return a + (b - a) * alpha
end

function WorldMath.inverseLerp(a, b, value)
	if math.abs(b - a) <= EPSILON then
		return 0
	end

	return (value - a) / (b - a)
end

function WorldMath.smoothStep(minValue, maxValue, value)
	local alpha = WorldMath.clamp(WorldMath.inverseLerp(minValue, maxValue, value), 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

function WorldMath.roundToGrid(value, resolution)
	return math.floor((value / resolution) + 0.5) * resolution
end

function WorldMath.wrapIndex(index, count)
	return ((index - 1) % count) + 1
end

function WorldMath.flattenXZ(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

function WorldMath.horizontalUnit(vector, fallback)
	local flattened = WorldMath.flattenXZ(vector)
	if flattened.Magnitude <= EPSILON then
		return fallback or Vector3.new(0, 0, -1)
	end

	return flattened.Unit
end

function WorldMath.forwardFromRotation(rotation)
	return Vector3.new(math.sin(rotation), 0, math.cos(rotation))
end

function WorldMath.rightFromTangent(tangent, upVector)
	local up = upVector or Vector3.yAxis
	local right = tangent:Cross(up)
	if right.Magnitude <= EPSILON then
		return Vector3.xAxis
	end

	return right.Unit
end

function WorldMath.rightFromRotation(rotation, upVector)
	return WorldMath.rightFromTangent(WorldMath.forwardFromRotation(rotation), upVector)
end

function WorldMath.insideTurnSideSign(curvature)
	return curvature >= 0 and 1 or -1
end

function WorldMath.angleAroundY(fromVector, toVector)
	local fromUnit = WorldMath.horizontalUnit(fromVector)
	local toUnit = WorldMath.horizontalUnit(toVector)
	local crossY = fromUnit.X * toUnit.Z - fromUnit.Z * toUnit.X
	local dot = WorldMath.clamp(fromUnit:Dot(toUnit), -1, 1)
	return math.atan2(crossY, dot)
end

function WorldMath.distanceXZ(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function WorldMath.segmentIntersectionXZ(a0, a1, b0, b1)
	local ax = a1.X - a0.X
	local az = a1.Z - a0.Z
	local bx = b1.X - b0.X
	local bz = b1.Z - b0.Z
	local determinant = ax * bz - az * bx

	if math.abs(determinant) <= EPSILON then
		return false
	end

	local cx = b0.X - a0.X
	local cz = b0.Z - a0.Z
	local t = (cx * bz - cz * bx) / determinant
	local u = (cx * az - cz * ax) / determinant

	return t >= EPSILON and t <= 1 - EPSILON and u >= EPSILON and u <= 1 - EPSILON
end

function WorldMath.deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, item in pairs(value) do
		copy[key] = WorldMath.deepCopy(item)
	end

	return copy
end

function WorldMath.tableCount(values)
	local count = 0
	for _ in pairs(values) do
		count += 1
	end
	return count
end

return WorldMath
