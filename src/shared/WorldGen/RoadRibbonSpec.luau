local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))

local RoadRibbonSpec = {}

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

local function segmentCount(samples, closed)
	return closed and #samples or math.max(0, #samples - 1)
end

local function segmentSamples(samples, segmentIndex, closed)
	local sample = samples[segmentIndex]
	local nextIndex = segmentIndex + 1
	if not closed and nextIndex > #samples then
		return nil, nil
	end
	if nextIndex > #samples then
		nextIndex = 1
	end

	return sample, samples[nextIndex]
end

local function segmentPoints(sample, nextSample, halfWidth, roadLift)
	local lifted = sample.Position + sample.Up * roadLift
	local nextLifted = nextSample.Position + nextSample.Up * roadLift
	return {
		lifted - sample.Right * halfWidth,
		lifted + sample.Right * halfWidth,
		nextLifted - nextSample.Right * halfWidth,
		nextLifted + nextSample.Right * halfWidth,
	}
end

local function makeChunk(samples, segmentStart, segmentEnd, width, thickness, closed, roadLift)
	local points = {}
	local vertices = {}
	local triangles = {}
	local segments = {}
	local halfWidth = width * 0.5

	for segmentIndex = segmentStart, segmentEnd do
		local sample, nextSample = segmentSamples(samples, segmentIndex, closed)
		local lifted = sample.Position + sample.Up * roadLift
		local nextLifted = nextSample.Position + nextSample.Up * roadLift
		local left = lifted - sample.Right * halfWidth
		local right = lifted + sample.Right * halfWidth
		local nextLeft = nextLifted - nextSample.Right * halfWidth
		local nextRight = nextLifted + nextSample.Right * halfWidth

		if segmentIndex == segmentStart then
			points[#points + 1] = left
			points[#points + 1] = right
			vertices[#vertices + 1] = left
			vertices[#vertices + 1] = right
		end

		points[#points + 1] = nextLeft
		points[#points + 1] = nextRight
		vertices[#vertices + 1] = nextLeft
		vertices[#vertices + 1] = nextRight

		segments[#segments + 1] = {
			Start = lifted,
			Finish = nextLifted,
			Center = (lifted + nextLifted) * 0.5,
			LookAt = nextLifted,
			Width = width,
			Length = (nextLifted - lifted).Magnitude,
		}
	end

	local minPoint, maxPoint = pointBounds(points)
	local center = (minPoint + maxPoint) * 0.5

	for index = 1, #segments do
		local left0 = (index - 1) * 2 + 1
		local right0 = left0 + 1
		local left1 = index * 2 + 1
		local right1 = left1 + 1
		triangles[#triangles + 1] = { left0, right0, left1 }
		triangles[#triangles + 1] = { right0, right1, left1 }
	end

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
		Center = center,
		Width = width,
		Thickness = thickness,
		Vertices = localizedVertices,
		Triangles = triangles,
		Segments = segments,
		BoundsSize = maxPoint - minPoint,
	}
end

local function chunkPath(samples, width, closed)
	local maxSize = WorldConstants.MaxRoadChunkSize - width
	local chunkRanges = {}
	local count = segmentCount(samples, closed)
	local chunkStart = 1
	local spanPoints = {}
	local halfWidth = width * 0.5

	for index = 1, count do
		local sample, nextSample = segmentSamples(samples, index, closed)
		local candidatePoints = {}
		for _, point in ipairs(spanPoints) do
			candidatePoints[#candidatePoints + 1] = point
		end
		for _, point in ipairs(segmentPoints(sample, nextSample, halfWidth, WorldConstants.DefaultRoadLift)) do
			candidatePoints[#candidatePoints + 1] = point
		end

		local minPoint, maxPoint = pointBounds(candidatePoints)
		local size = maxPoint - minPoint
		local currentSpanCount = index - chunkStart + 1

		if currentSpanCount > 1 and (size.X > maxSize or size.Z > maxSize or currentSpanCount * WorldConstants.DefaultSampleSpacing > WorldConstants.TargetRoadChunkLength) then
			chunkRanges[#chunkRanges + 1] = { SegmentStart = chunkStart, SegmentEnd = index - 1 }
			chunkStart = index
			spanPoints = segmentPoints(sample, nextSample, halfWidth, WorldConstants.DefaultRoadLift)
		else
			spanPoints = candidatePoints
		end
	end

	local endIndex = count
	if endIndex >= chunkStart then
		chunkRanges[#chunkRanges + 1] = { SegmentStart = chunkStart, SegmentEnd = endIndex }
	end

	return chunkRanges
end

function RoadRibbonSpec.fromSamples(profileId, seed, samples, width, options)
	local settings = options or {}
	local closed = settings.Closed == true
	local thickness = settings.Thickness or WorldConstants.DefaultRibbonThickness
	local roadLift = settings.RoadLift or WorldConstants.DefaultRoadLift
	local chunks = {}

	for _, range in ipairs(chunkPath(samples, width, closed)) do
		local chunk = makeChunk(samples, range.SegmentStart, range.SegmentEnd, width, thickness, closed, roadLift)
		chunk.Id = ("%s_%03d_%03d"):format(settings.ChunkPrefix or "Chunk", range.SegmentStart, range.SegmentEnd)
		chunks[#chunks + 1] = chunk
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

function RoadRibbonSpec.fromLoop(loop, profile)
	local width = (profile and profile.RoadWidth) or loop.RoadWidth
	assert(type(width) == "number", "RoadRibbonSpec.fromLoop requires a RoadWidth from the profile or loop descriptor")

	return RoadRibbonSpec.fromSamples(loop.ProfileId, loop.Seed, loop.Samples, width, {
		Closed = loop.Closed ~= false,
		ChunkPrefix = "LoopChunk",
	})
end

return RoadRibbonSpec
