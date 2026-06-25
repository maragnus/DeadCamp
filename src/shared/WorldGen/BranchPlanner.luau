local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))
local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))

local BranchPlanner = {}

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

local function networkRoadDescriptor(loop, profile, road, sampleHeight)
	local points, startMeta, finishMeta = orientRoad(loop, road)
	if not points or #points < 2 then
		return nil, "descriptor build failed"
	end

	local samples, pathLength = RoadPathUtils.buildFittedDescriptors(points, sampleHeight, profile.MaxRoadGradeDegrees, false)
	if #samples < 2 then
		return nil, "insufficient samples"
	end

	local startPoint = samples[1].Position
	local finishPoint = samples[#samples].Position
	local sampleIndex = nearestLoopSampleIndex(loop, startPoint)
	if startMeta and startMeta.TouchesLoop and finishMeta and finishMeta.TouchesLoop then
		local finishIndex = nearestLoopSampleIndex(loop, finishPoint)
		if finishIndex < sampleIndex then
			sampleIndex = finishIndex
		end
	end

	return {
		Id = road.Id,
		Type = WorldConstants.BranchTypes.NetworkRoad,
		Template = road.CurveType or "NetworkRoad",
		RoadSampleIndex = sampleIndex,
		Length = pathLength,
		HalfWidth = profile.RoadWidth * WorldConstants.BranchRoadWidthScale * 0.5,
		EntranceTaperLength = startMeta and startMeta.TouchesLoop and 18 or 0,
		Samples = RoadPathUtils.serializeSamples(samples),
		NodeIndices = road.NodeIndices,
		TouchesLoop = road.TouchesLoop == true,
		RejoinsLoop = road.RejoinsLoop == true,
		EndsAtLeaf = road.EndsAtLeaf == true,
		Start = {
			NodeIndex = startMeta and startMeta.NodeIndex or nil,
			Degree = startMeta and startMeta.Degree or 0,
			TouchesLoop = startMeta and startMeta.TouchesLoop == true or false,
		},
		Finish = {
			NodeIndex = finishMeta and finishMeta.NodeIndex or nil,
			Degree = finishMeta and finishMeta.Degree or 0,
			TouchesLoop = finishMeta and finishMeta.TouchesLoop == true or false,
		},
	}, nil
end

function BranchPlanner.plan(loop, profile, options)
	local sampleHeight = assert(options and options.SampleHeight, "BranchPlanner.plan requires SampleHeight")
	local debugRejects = options and options.DebugRejects or nil
	local branches = {}

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
		local descriptor, rejectReason = networkRoadDescriptor(loop, profile, road, sampleHeight)
		if descriptor then
			branches[#branches + 1] = descriptor
		elseif debugRejects then
			debugRejects[#debugRejects + 1] = ("%s rejected: %s"):format(road.Id, tostring(rejectReason))
		end
	end

	return branches
end

return BranchPlanner
