local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))
local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))
local RoadSurfaceProfile = require(script.Parent:WaitForChild("RoadSurfaceProfile"))

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

local function makeChunk(samples, width, thickness, roadLift)
	local points = {}
	local vertices = {}
	local triangles = {}
	local segments = {}
	local accumulatedUp = Vector3.zero
	local halfWidth = width * 0.5
	local sectionLength = 0

	for segmentIndex = 1, math.max(0, #samples - 1) do
		local sample = samples[segmentIndex]
		local nextSample = samples[segmentIndex + 1]
		local lifted = sample.Position + sample.Up * roadLift
		local nextLifted = nextSample.Position + nextSample.Up * roadLift
		local left = lifted - sample.Right * halfWidth
		local right = lifted + sample.Right * halfWidth
		local nextLeft = nextLifted - nextSample.Right * halfWidth
		local nextRight = nextLifted + nextSample.Right * halfWidth

		if segmentIndex == 1 then
			points[#points + 1] = left
			points[#points + 1] = right
			vertices[#vertices + 1] = left
			vertices[#vertices + 1] = right
			accumulatedUp += sample.Up
		end

		points[#points + 1] = nextLeft
		points[#points + 1] = nextRight
		vertices[#vertices + 1] = nextLeft
		vertices[#vertices + 1] = nextRight
		accumulatedUp += nextSample.Up

		segments[#segments + 1] = {
			Start = lifted,
			Finish = nextLifted,
			Center = (lifted + nextLifted) * 0.5,
			LookAt = nextLifted,
			Up = sample.Up,
			Width = width,
			Length = (nextLifted - lifted).Magnitude,
		}
		sectionLength += segments[#segments].Length
	end

	local minPoint, maxPoint = pointBounds(points)
	local center = (minPoint + maxPoint) * 0.5

	for index = 1, #segments do
		local left0 = (index - 1) * 2 + 1
		local right0 = left0 + 1
		local left1 = index * 2 + 1
		local right1 = left1 + 1
		triangles[#triangles + 1] = { left0, left1, right0 }
		triangles[#triangles + 1] = { right0, left1, right1 }
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

	local expectedNormal = accumulatedUp.Magnitude > 0 and accumulatedUp.Unit or WorldConstants.WorldUp

	return {
		Center = center,
		Width = width,
		Thickness = thickness,
		Vertices = localizedVertices,
		Triangles = triangles,
		Segments = segments,
		BoundsSize = maxPoint - minPoint,
		SectionLength = sectionLength,
		Validation = {
			ExpectedNormal = expectedNormal,
			MinimumDot = 0.001,
		},
	}
end

function RoadRibbonSpec.fromSamples(profileId, seed, samples, width, options)
	local settings = options or {}
	local closed = settings.Closed == true
	local thickness = settings.Thickness or WorldConstants.DefaultRibbonThickness
	local roadLift = settings.RoadLift
	if roadLift == nil then
		roadLift = WorldConstants.DefaultRoadLift
	end
	local chunks = {}
	local chunkPrefix = settings.ChunkPrefix or "Chunk"
	local sectionSamples = RoadPathUtils.partitionSamplesByLength(samples, closed, WorldConstants.MaxRoadMeshLength)

	for chunkIndex, chunkSamples in ipairs(sectionSamples) do
		if #chunkSamples >= 2 then
			local chunk = makeChunk(chunkSamples, width, thickness, roadLift)
			chunk.Id = ("%s_%03d"):format(chunkPrefix, chunkIndex)
			chunks[#chunks + 1] = chunk
		end
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
	local roadLift = profile and RoadSurfaceProfile.visualSurfaceLift(profile, RoadSurfaceProfile.Kinds.Main)
		or WorldConstants.DefaultRoadLift

	return RoadRibbonSpec.fromSamples(loop.ProfileId, loop.Seed, loop.Samples, width, {
		Closed = loop.Closed ~= false,
		ChunkPrefix = "LoopChunk",
		RoadLift = roadLift,
	})
end

return RoadRibbonSpec
