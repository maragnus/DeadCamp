local GeometryDirections = require(script.Parent:WaitForChild("GeometryDirections"))
local PartOrientation = require(script.Parent:WaitForChild("PartOrientation"))

local MeshShapePrimitives = {}

local function buildDiscTriangles(vertexCount, facing)
	local triangles = {}
	local reverseWinding = facing == GeometryDirections.Bottom

	for index = 2, vertexCount do
		local nextIndex = index + 1
		if nextIndex > vertexCount then
			nextIndex = 2
		end

		if reverseWinding then
			triangles[#triangles + 1] = { 1, nextIndex, index }
		else
			triangles[#triangles + 1] = { 1, index, nextIndex }
		end
	end

	return triangles
end

function MeshShapePrimitives.discCapChunk(id, center, radius, thickness, options)
	local settings = options or {}
	local segmentCount = math.max(3, settings.SegmentCount or 24)
	local facing = settings.Facing or GeometryDirections.Top

	if facing ~= GeometryDirections.Top and facing ~= GeometryDirections.Bottom then
		error(("Disc caps support only Top or Bottom facing, got %s"):format(tostring(facing)), 2)
	end

	local vertices = {
		Vector3.zero,
	}
	for index = 0, segmentCount - 1 do
		local angle = (index / segmentCount) * math.pi * 2
		vertices[#vertices + 1] = Vector3.new(
			math.sin(angle) * radius,
			0,
			math.cos(angle) * radius
		)
	end

	return {
		Id = id,
		Center = center,
		Width = radius * 2,
		Thickness = thickness,
		Vertices = vertices,
		Triangles = buildDiscTriangles(#vertices, facing),
		Segments = {},
		FallbackParts = {
			{
				Shape = "Cylinder",
				Size = Vector3.new(thickness, radius * 2, radius * 2),
				Axis = PartOrientation.CylinderAxis.Height,
			},
		},
		BoundsSize = Vector3.new(radius * 2, thickness, radius * 2),
		SectionLength = radius * 2,
		Validation = {
			ExpectedFacing = facing,
			MinimumDot = settings.MinimumDot or 0.05,
		},
	}
end

return MeshShapePrimitives
