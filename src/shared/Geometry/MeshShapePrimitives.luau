local GeometryDirections = require(script.Parent:WaitForChild("GeometryDirections"))
local PartOrientation = require(script.Parent:WaitForChild("PartOrientation"))

local MeshShapePrimitives = {}

local NORMAL_EPSILON = 1e-6

local function pointBounds(points)
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

	for _, point in ipairs(points) do
		minX = math.min(minX, point.X)
		minY = math.min(minY, point.Y)
		minZ = math.min(minZ, point.Z)
		maxX = math.max(maxX, point.X)
		maxY = math.max(maxY, point.Y)
		maxZ = math.max(maxZ, point.Z)
	end

	return Vector3.new(minX, minY, minZ), Vector3.new(maxX, maxY, maxZ)
end

local function assertVector3(value, context)
	if typeof(value) ~= "Vector3" then
		error(("%s must be a Vector3, got %s"):format(context, typeof(value)), 3)
	end
end

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

local function buildRibbonTriangles(segmentCount, facing)
	local triangles = {}
	local reverseWinding = facing == GeometryDirections.Bottom

	for index = 1, segmentCount do
		local left0 = (index - 1) * 2 + 1
		local right0 = left0 + 1
		local left1 = index * 2 + 1
		local right1 = left1 + 1

		if reverseWinding then
			triangles[#triangles + 1] = { left0, left1, right0 }
			triangles[#triangles + 1] = { right0, left1, right1 }
		else
			triangles[#triangles + 1] = { left0, right0, left1 }
			triangles[#triangles + 1] = { right0, right1, left1 }
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

function MeshShapePrimitives.frameRibbonChunk(id, samples, width, thickness, options)
	local settings = options or {}
	local facing = settings.Facing or GeometryDirections.Top
	local normalOffset = settings.NormalOffset or 0
	local minimumDot = settings.MinimumDot or 0.001
	local fallbackNormal = settings.FallbackNormal or Vector3.yAxis
	local halfWidth = width * 0.5
	local points = {}
	local vertices = {}
	local segments = {}
	local accumulatedNormal = Vector3.zero
	local sectionLength = 0

	if facing ~= GeometryDirections.Top and facing ~= GeometryDirections.Bottom then
		error(("Frame ribbons support only Top or Bottom facing, got %s"):format(tostring(facing)), 2)
	end

	assert(type(width) == "number" and width > 0, "Frame ribbons require a positive width")
	assert(type(thickness) == "number" and thickness > 0, "Frame ribbons require a positive thickness")
	assert(type(samples) == "table" and #samples >= 2, "Frame ribbons require at least two samples")
	assertVector3(fallbackNormal, "Frame ribbon fallback normal")

	for segmentIndex = 1, #samples - 1 do
		local sample = samples[segmentIndex]
		local nextSample = samples[segmentIndex + 1]
		local samplePosition = sample and sample.Position
		local sampleRight = sample and sample.Right
		local sampleUp = sample and sample.Up
		local nextPosition = nextSample and nextSample.Position
		local nextRight = nextSample and nextSample.Right
		local nextUp = nextSample and nextSample.Up

		assertVector3(samplePosition, ("Frame ribbon sample %d Position"):format(segmentIndex))
		assertVector3(sampleRight, ("Frame ribbon sample %d Right"):format(segmentIndex))
		assertVector3(sampleUp, ("Frame ribbon sample %d Up"):format(segmentIndex))
		assertVector3(nextPosition, ("Frame ribbon sample %d Position"):format(segmentIndex + 1))
		assertVector3(nextRight, ("Frame ribbon sample %d Right"):format(segmentIndex + 1))
		assertVector3(nextUp, ("Frame ribbon sample %d Up"):format(segmentIndex + 1))

		local lifted = samplePosition + sampleUp * normalOffset
		local nextLifted = nextPosition + nextUp * normalOffset
		local left = lifted - sampleRight * halfWidth
		local right = lifted + sampleRight * halfWidth
		local nextLeft = nextLifted - nextRight * halfWidth
		local nextRightPoint = nextLifted + nextRight * halfWidth

		if segmentIndex == 1 then
			points[#points + 1] = left
			points[#points + 1] = right
			vertices[#vertices + 1] = left
			vertices[#vertices + 1] = right
			accumulatedNormal += sampleUp
		end

		points[#points + 1] = nextLeft
		points[#points + 1] = nextRightPoint
		vertices[#vertices + 1] = nextLeft
		vertices[#vertices + 1] = nextRightPoint
		accumulatedNormal += nextUp

		local segmentLength = (nextLifted - lifted).Magnitude
		segments[#segments + 1] = {
			Start = lifted,
			Finish = nextLifted,
			Center = (lifted + nextLifted) * 0.5,
			LookAt = nextLifted,
			Up = sampleUp,
			Width = width,
			Length = segmentLength,
		}
		sectionLength += segmentLength
	end

	local minPoint, maxPoint = pointBounds(points)
	local center = (minPoint + maxPoint) * 0.5
	local localizedVertices = {}
	for index, vertex in ipairs(vertices) do
		localizedVertices[index] = vertex - center
	end

	for _, segment in ipairs(segments) do
		segment.Center = segment.Center - center
		segment.LookAt = segment.LookAt - center
		segment.Start = segment.Start - center
		segment.Finish = segment.Finish - center
	end

	local resolvedNormal = accumulatedNormal.Magnitude > NORMAL_EPSILON and accumulatedNormal.Unit or fallbackNormal.Unit
	if facing == GeometryDirections.Bottom then
		resolvedNormal = -resolvedNormal
	end

	return {
		Id = id,
		Center = center,
		Width = width,
		Thickness = thickness,
		Vertices = localizedVertices,
		Triangles = buildRibbonTriangles(#segments, facing),
		Segments = segments,
		BoundsSize = maxPoint - minPoint,
		SectionLength = sectionLength,
		Validation = {
			ExpectedNormal = resolvedNormal,
			MinimumDot = minimumDot,
		},
	}
end

return MeshShapePrimitives
