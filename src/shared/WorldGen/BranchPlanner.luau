local WorldConflictUtils = require(script.Parent:WaitForChild("WorldConflictUtils"))
local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))
local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))

local BranchPlanner = {}

local function pointToArray(point)
	return { point.X, point.Y, point.Z }
end

local function pointFromArray(values)
	return Vector3.new(values[1], values[2], values[3])
end

local function nearestLoopSampleIndex(loop, position)
	local bestIndex = 1
	local bestDistance = math.huge

	for sampleIndex, sample in ipairs(loop.Samples) do
		local probe = Vector3.new(position.X, sample.Position.Y, position.Z)
		local distance = (probe - sample.Position).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			bestIndex = sampleIndex
		end
	end

	return bestIndex
end

local function reversePoints(points)
	local reversed = {}
	for index = #points, 1, -1 do
		reversed[#reversed + 1] = points[index]
	end
	return reversed
end

local function classifyRoad(road)
	if road.RejoinsLoop then
		return WorldConstants.BranchTypes.FalseIntersection, "NetworkFalseIntersection", true
	end
	if road.EndsAtLeaf then
		return WorldConstants.BranchTypes.DeadEndPOI, "NetworkDeadEnd", true
	end
	if road.TouchesLoop then
		return WorldConstants.BranchTypes.BlockedBranch, "NetworkBranch", true
	end
	return WorldConstants.BranchTypes.ServiceSpur, "NetworkConnector", false
end

local function orientRoad(loop, road)
	local points = road.Points or {}
	if #points < 2 then
		return nil, nil, nil
	end

	local startMeta = road.Start or {}
	local finishMeta = road.Finish or {}
	local useReversed = false

	if finishMeta.TouchesLoop and not startMeta.TouchesLoop then
		useReversed = true
	elseif startMeta.TouchesLoop == finishMeta.TouchesLoop then
		local startIndex = nearestLoopSampleIndex(loop, points[1])
		local finishIndex = nearestLoopSampleIndex(loop, points[#points])
		useReversed = finishIndex < startIndex
	end

	if useReversed then
		return reversePoints(points), finishMeta, startMeta
	end

	return points, startMeta, finishMeta
end

local function buildSerializedSamples(points, sampleHeight, profile)
	local samplePositions, pathLength = RoadPathUtils.resampleByArcLength(points, WorldConstants.DefaultSampleSpacing, false)
	local samples = RoadPathUtils.sampleDescriptors(samplePositions, pathLength, false)
	RoadPathUtils.fitHeights(samples, sampleHeight, profile.MaxRoadGradeDegrees, false)

	local serialized = {}
	for _, descriptor in ipairs(samples) do
		serialized[#serialized + 1] = {
			Position = pointToArray(descriptor.Position),
			Tangent = pointToArray(descriptor.Tangent),
			Right = pointToArray(descriptor.Right),
			Up = pointToArray(descriptor.Up),
			Curvature = descriptor.Curvature,
			LapDistance = descriptor.LapDistance,
		}
	end

	return serialized, samples, pathLength
end

local function networkBranchDescriptor(loop, profile, road, sampleHeight)
	local points, startMeta, finishMeta = orientRoad(loop, road)
	if not points or #points < 2 then
		return nil
	end

	local branchType, template, blocked = classifyRoad(road)
	local serializedSamples, samples, pathLength = buildSerializedSamples(points, sampleHeight, profile)
	if #samples < 2 then
		return nil
	end

	local startPoint = pointFromArray(serializedSamples[1].Position)
	local finishSample = samples[#samples]
	local penultimate = samples[math.max(1, #samples - 1)]

	local sampleIndex = nearestLoopSampleIndex(loop, startPoint)
	if startMeta and startMeta.TouchesLoop and finishMeta and finishMeta.TouchesLoop then
		local finishIndex = nearestLoopSampleIndex(loop, finishSample.Position)
		if finishIndex < sampleIndex then
			sampleIndex = finishIndex
		end
	end

	local blocker = nil
	if blocked then
		blocker = {
			Position = pointToArray(finishSample.Position),
			LookAt = pointToArray(penultimate.Position),
		}
	end

	return {
		Id = road.Id,
		Type = branchType,
		Template = template,
		RoadSampleIndex = sampleIndex,
		Length = pathLength,
		Blocked = blocked,
		HalfWidth = profile.RoadWidth * WorldConstants.BranchRoadWidthScale * 0.5,
		EntranceTaperLength = startMeta and startMeta.TouchesLoop and 18 or 0,
		Samples = serializedSamples,
		Blocker = blocker,
	}
end

function BranchPlanner.plan(loop, profile, options)
	local sampleHeight = assert(options and options.SampleHeight, "BranchPlanner.plan requires SampleHeight")
	local parcels = options and options.Parcels or {}
	local debugRejects = options and options.DebugRejects or nil
	local branches = {}
	local context = WorldConflictUtils.buildContext({
		Loop = loop,
		Profile = profile,
		LandformRuntime = options and options.LandformRuntime or nil,
		Parcels = parcels,
	})

	local networkRoads = {}
	for _, road in ipairs(loop.Topology and loop.Topology.NetworkRoads or {}) do
		networkRoads[#networkRoads + 1] = road
	end

	table.sort(networkRoads, function(left, right)
		if left.TouchesLoop ~= right.TouchesLoop then
			return left.TouchesLoop
		end
		if left.RejoinsLoop ~= right.RejoinsLoop then
			return left.RejoinsLoop
		end
		if left.Length ~= right.Length then
			return left.Length > right.Length
		end
		return left.Id < right.Id
	end)

	for _, road in ipairs(networkRoads) do
		local descriptor = networkBranchDescriptor(loop, profile, road, sampleHeight)
		if descriptor then
			local rejectReason = nil
			for pointIndex = 3, #(descriptor.Samples or {}) do
				local point = pointFromArray(descriptor.Samples[pointIndex].Position)
				local roadConflict, reason = WorldConflictUtils.pointConflictsRoads(context, point, descriptor.HalfWidth + profile.ShoulderWidth * 0.45)
				if roadConflict then
					rejectReason = reason
					break
				end
				local waterConflict, waterReason = WorldConflictUtils.pointConflictsWater(context, point)
				if waterConflict then
					rejectReason = waterReason
					break
				end
			end

			if not rejectReason then
				branches[#branches + 1] = descriptor
				context.BranchIndices = WorldConflictUtils.buildContext({
					Loop = loop,
					Profile = profile,
					LandformRuntime = options and options.LandformRuntime or nil,
					Parcels = parcels,
					Branches = branches,
				}).BranchIndices
			elseif debugRejects then
				debugRejects[#debugRejects + 1] = ("%s rejected: %s"):format(road.Id, rejectReason)
			end
		elseif debugRejects then
			debugRejects[#debugRejects + 1] = ("%s rejected: descriptor build failed"):format(road.Id)
		end
	end

	return branches
end

return BranchPlanner
