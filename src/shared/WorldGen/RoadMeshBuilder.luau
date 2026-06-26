local GeometryDirections = require(script.Parent.Parent:WaitForChild("Geometry"):WaitForChild("GeometryDirections"))
local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))
local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))

local RoadMeshBuilder = {}

local VECTOR_EPSILON = 1e-4
local DEFAULT_MINIMUM_DOT = 0.001

local function assertVector3(value, context)
	if typeof(value) ~= "Vector3" then
		error(("%s must be a Vector3, got %s"):format(context, typeof(value)), 3)
	end
end

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

local function samplePositions(samples)
	local positions = table.create(#samples)
	for index, sample in ipairs(samples) do
		local position = sample and sample.Position
		assertVector3(position, ("RoadMeshBuilder sample %d Position"):format(index))
		positions[index] = position
	end
	return positions
end

local function buildSegmentLengths(positions, closed)
	local segmentCount = closed and #positions or (#positions - 1)
	local lengths = table.create(segmentCount)

	for index = 1, segmentCount do
		local nextIndex = index + 1
		if nextIndex > #positions then
			nextIndex = 1
		end
		lengths[index] = (positions[nextIndex] - positions[index]).Magnitude
	end

	return lengths
end

local function buildFrameSamples(samples, closed, normalOffset)
	local frameSamples = table.create(#samples)

	for index, sample in ipairs(samples) do
		local position = sample and sample.Position
		assertVector3(position, ("RoadMeshBuilder sample %d Position"):format(index))
		frameSamples[index] = {
			Position = position + WorldConstants.WorldUp * normalOffset,
			Up = WorldConstants.WorldUp,
		}
	end

	return RoadPathUtils.resolveSampleFrames(frameSamples, closed)
end

local function buildCrossSections(samples, width, closed, normalOffset)
	local positions = samplePositions(samples)
	local segmentLengths = buildSegmentLengths(positions, closed)
	local frameSamples = buildFrameSamples(samples, closed, normalOffset)
	local halfWidth = width * 0.5
	local sections = table.create(closed and (#frameSamples + 1) or #frameSamples)

	-- Rebuild both edges from one continuous frame pass so left/right cannot flip independently at joins.
	for sampleIndex, frameSample in ipairs(frameSamples) do
		local center = frameSample.Position
		local right = frameSample.Right
		assertVector3(right, ("RoadMeshBuilder frame sample %d Right"):format(sampleIndex))
		local offset = right.Unit * halfWidth

		sections[sampleIndex] = {
			Center = center,
			Left = center - offset,
			Right = center + offset,
		}
	end

	if closed then
		sections[#sections + 1] = {
			Center = sections[1].Center,
			Left = sections[1].Left,
			Right = sections[1].Right,
		}
	end

	return sections, segmentLengths
end

local function buildChunkRanges(sectionCount, segmentLengths, maxSectionLength)
	local ranges = {}
	local startSection = 1
	local segmentIndex = 1
	local accumulatedLength = 0

	while segmentIndex <= #segmentLengths do
		local segmentLength = segmentLengths[segmentIndex]
		if accumulatedLength > VECTOR_EPSILON and accumulatedLength + segmentLength > maxSectionLength then
			ranges[#ranges + 1] = {
				StartSection = startSection,
				EndSection = segmentIndex,
			}
			startSection = segmentIndex
			accumulatedLength = 0
		else
			accumulatedLength += segmentLength
			segmentIndex += 1
		end
	end

	ranges[#ranges + 1] = {
		StartSection = startSection,
		EndSection = sectionCount,
	}

	return ranges
end

local function diagnosticSummary(diagnostics, chunkId, startSection, endSection)
	if type(diagnostics) ~= "table" or diagnostics.Enabled ~= true then
		return nil
	end

	local prefix = diagnostics.LabelPrefix or "RoadMesh"
	return ("%s/%s sections=%d-%d"):format(tostring(prefix), tostring(chunkId), startSection, endSection)
end

local function triangleFacingScore(a, b, c)
	local normal = (b - a):Cross(c - a)
	if normal.Magnitude <= VECTOR_EPSILON then
		return -math.huge
	end

	return math.abs(normal.Unit:Dot(WorldConstants.WorldUp))
end

local function chooseQuadTriangles(left0Index, right0Index, left1Index, right1Index, left0, right0, left1, right1)
	local optionAFirst = { left0Index, right0Index, left1Index }
	local optionASecond = { right0Index, right1Index, left1Index }
	local optionAMinDot = math.min(
		triangleFacingScore(left0, right0, left1),
		triangleFacingScore(right0, right1, left1)
	)
	local optionAAverageDot = (
		triangleFacingScore(left0, right0, left1)
		+ triangleFacingScore(right0, right1, left1)
	) * 0.5

	local optionBFirst = { left0Index, right0Index, right1Index }
	local optionBSecond = { left0Index, right1Index, left1Index }
	local optionBMinDot = math.min(
		triangleFacingScore(left0, right0, right1),
		triangleFacingScore(left0, right1, left1)
	)
	local optionBAverageDot = (
		triangleFacingScore(left0, right0, right1)
		+ triangleFacingScore(left0, right1, left1)
	) * 0.5

	if optionBMinDot > optionAMinDot + VECTOR_EPSILON then
		return optionBFirst, optionBSecond
	end

	if math.abs(optionBMinDot - optionAMinDot) <= VECTOR_EPSILON and optionBAverageDot > optionAAverageDot + VECTOR_EPSILON then
		return optionBFirst, optionBSecond
	end

	return optionAFirst, optionASecond
end

local function buildChunk(chunkId, sections, startSection, endSection, width, thickness, minimumDot, diagnostics)
	local vertices = {}
	local points = {}
	local triangles = {}
	local segments = {}
	local sectionLength = 0

	for sectionIndex = startSection, endSection do
		local section = sections[sectionIndex]
		local localSectionIndex = sectionIndex - startSection
		local leftIndex = localSectionIndex * 2 + 1
		local rightIndex = leftIndex + 1

		points[#points + 1] = section.Left
		points[#points + 1] = section.Right
		vertices[#vertices + 1] = section.Left
		vertices[#vertices + 1] = section.Right

		if sectionIndex < endSection then
			local nextSection = sections[sectionIndex + 1]
			local firstTriangle, secondTriangle = chooseQuadTriangles(
				leftIndex,
				rightIndex,
				leftIndex + 2,
				rightIndex + 2,
				section.Left,
				section.Right,
				nextSection.Left,
				nextSection.Right
			)
			triangles[#triangles + 1] = firstTriangle
			triangles[#triangles + 1] = secondTriangle

			local startCenter = section.Center
			local finishCenter = nextSection.Center
			local segmentLength = (finishCenter - startCenter).Magnitude

			segments[#segments + 1] = {
				Start = startCenter,
				Finish = finishCenter,
				Center = (startCenter + finishCenter) * 0.5,
				LookAt = finishCenter,
				Up = WorldConstants.WorldUp,
				Width = width,
				Length = segmentLength,
			}
			sectionLength += segmentLength
		end
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

	return {
		Id = chunkId,
		Center = center,
		Width = width,
		Thickness = thickness,
		Vertices = localizedVertices,
		Triangles = triangles,
		Segments = segments,
		BoundsSize = maxPoint - minPoint,
		SectionLength = sectionLength,
		Validation = {
			ExpectedFacing = GeometryDirections.Top,
			MinimumDot = minimumDot,
			DiagnosticSummary = diagnosticSummary(diagnostics, chunkId, startSection, endSection),
		},
	}
end

function RoadMeshBuilder.buildSpec(profileId, seed, samples, width, options)
	local settings = options or {}
	local closed = settings.Closed == true
	local thickness = settings.Thickness or WorldConstants.DefaultRibbonThickness
	local normalOffset = settings.NormalOffset or 0
	local minimumDot = settings.MinimumDot or DEFAULT_MINIMUM_DOT
	local maxSectionLength = settings.MaxSectionLength or WorldConstants.MaxRoadMeshLength
	local chunkPrefix = settings.ChunkPrefix or "Chunk"

	assert(type(width) == "number" and width > 0, "RoadMeshBuilder requires a positive width")
	assert(type(thickness) == "number" and thickness > 0, "RoadMeshBuilder requires a positive thickness")
	assert(type(samples) == "table" and #samples >= 2, "RoadMeshBuilder requires at least two samples")

	local sections, segmentLengths = buildCrossSections(samples, width, closed, normalOffset)
	local chunkRanges = buildChunkRanges(#sections, segmentLengths, maxSectionLength)
	local chunks = {}

	for chunkIndex, range in ipairs(chunkRanges) do
		local chunkId = ("%s_%03d"):format(chunkPrefix, chunkIndex)
		chunks[#chunks + 1] = buildChunk(
			chunkId,
			sections,
			range.StartSection,
			range.EndSection,
			width,
			thickness,
			minimumDot,
			settings.Diagnostics
		)
	end

	return {
		ProfileId = profileId,
		Seed = seed,
		Width = width,
		Thickness = thickness,
		Closed = closed,
		Chunks = chunks,
	}
end

return RoadMeshBuilder
