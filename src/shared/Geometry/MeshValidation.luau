local GeometryDirections = require(script.Parent:WaitForChild("GeometryDirections"))

local MeshValidation = {}

local NORMAL_EPSILON = 1e-6

local function describeChunk(chunk)
	return tostring(chunk.Id or chunk.Name or "<chunk>")
end

local function resolveExpectedNormal(validation)
	if type(validation) ~= "table" then
		return nil, nil
	end

	if validation.ExpectedFacing ~= nil then
		return GeometryDirections.toVector(validation.ExpectedFacing), "ExpectedFacing"
	end

	if typeof(validation.ExpectedNormal) == "Vector3" and validation.ExpectedNormal.Magnitude > NORMAL_EPSILON then
		return validation.ExpectedNormal.Unit, "ExpectedNormal"
	end

	return nil, nil
end

local function assertVector3(value, context)
	if typeof(value) ~= "Vector3" then
		error(("%s must be a Vector3, got %s"):format(context, typeof(value)), 3)
	end
end

local function triangleNormal(vertices, triangle)
	local a = vertices[triangle[1]]
	local b = vertices[triangle[2]]
	local c = vertices[triangle[3]]
	local normal = (b - a):Cross(c - a)
	return normal, normal.Magnitude
end

function MeshValidation.validateChunk(chunk)
	local chunkName = describeChunk(chunk)
	local vertices = chunk.Vertices or {}
	local triangles = chunk.Triangles or {}
	local validation = chunk.Validation or {}
	local expectedNormal, expectedNormalSource = resolveExpectedNormal(validation)
	local minimumDot = validation.MinimumDot or 0

	if #vertices == 0 then
		error(("Mesh chunk %s has no vertices"):format(chunkName), 2)
	end

	if #triangles == 0 then
		error(("Mesh chunk %s has no triangles"):format(chunkName), 2)
	end

	for vertexIndex, vertex in ipairs(vertices) do
		assertVector3(vertex, ("Mesh chunk %s vertex %d"):format(chunkName, vertexIndex))
	end

	for triangleIndex, triangle in ipairs(triangles) do
		if type(triangle) ~= "table" or #triangle ~= 3 then
			error(("Mesh chunk %s triangle %d must contain exactly 3 vertex indices"):format(chunkName, triangleIndex), 2)
		end

		for cornerIndex = 1, 3 do
			local vertexIndex = triangle[cornerIndex]
			if type(vertexIndex) ~= "number" or vertexIndex % 1 ~= 0 then
				error(("Mesh chunk %s triangle %d corner %d must be an integer index"):format(chunkName, triangleIndex, cornerIndex), 2)
			end
			if vertexIndex < 1 or vertexIndex > #vertices then
				error(("Mesh chunk %s triangle %d corner %d references vertex %d outside 1..%d"):format(
					chunkName,
					triangleIndex,
					cornerIndex,
					vertexIndex,
					#vertices
				), 2)
			end
		end

		if triangle[1] == triangle[2] or triangle[2] == triangle[3] or triangle[1] == triangle[3] then
			error(("Mesh chunk %s triangle %d repeats a vertex index"):format(chunkName, triangleIndex), 2)
		end

		local normal, magnitude = triangleNormal(vertices, triangle)
		if magnitude <= NORMAL_EPSILON then
			error(("Mesh chunk %s triangle %d is degenerate"):format(chunkName, triangleIndex), 2)
		end

		if expectedNormal then
			local dot = normal.Unit:Dot(expectedNormal)
			if dot <= minimumDot then
				error(("Mesh chunk %s triangle %d faces the wrong way for %s (dot %.4f <= %.4f)"):format(
					chunkName,
					triangleIndex,
					expectedNormalSource,
					dot,
					minimumDot
				), 2)
			end
		end
	end

	return true
end

return MeshValidation
