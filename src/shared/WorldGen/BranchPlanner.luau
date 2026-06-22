local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))
local WorldMath = require(script.Parent:WaitForChild("WorldMath"))
local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))
local WorldSeed = require(script.Parent:WaitForChild("WorldSeed"))

local BranchPlanner = {}

local BRANCH_ORDER = {
	WorldConstants.BranchTypes.FalseIntersection,
	WorldConstants.BranchTypes.DeadEndPOI,
	WorldConstants.BranchTypes.BlockedBranch,
	WorldConstants.BranchTypes.ServiceSpur,
}

local function pointToArray(point)
	return { point.X, point.Y, point.Z }
end

local function branchAnchors(sample, branchType, length, rng)
	local sideSign = sample.Curvature >= 0 and 1 or -1
	if rng:NextNumber() < 0.35 then
		sideSign = -sideSign
	end

	local tangent = sample.Tangent
	local branchNormal = sample.Right * sideSign
	local startPoint = sample.Position
	local startShoulder = startPoint + branchNormal * 10 + tangent * 10
	local pullout = startShoulder + tangent * rng:NextNumber(18, 32)
	local deepCurve = pullout + branchNormal * rng:NextNumber(length * 0.24, length * 0.38) + tangent * rng:NextNumber(20, 46)
	local settle = deepCurve + tangent * rng:NextNumber(length * 0.22, length * 0.34) + branchNormal * rng:NextNumber(-length * 0.08, length * 0.12)
	local finish = settle + tangent * rng:NextNumber(length * 0.16, length * 0.26)

	if branchType == WorldConstants.BranchTypes.ServiceSpur then
		finish = settle
	elseif branchType == WorldConstants.BranchTypes.DeadEndPOI then
		finish = settle + branchNormal * rng:NextNumber(-length * 0.05, length * 0.05)
	end

	return {
		startPoint,
		startShoulder,
		pullout,
		deepCurve,
		settle,
		finish,
	}
end

local function branchDescriptor(loop, profile, sampleIndex, branchType, length, sampleHeight, seed)
	local sample = loop.Samples[sampleIndex]
	local branchSeed = WorldSeed.combine(seed, ("%s_%d"):format(branchType, sampleIndex))
	local rng = Random.new(branchSeed)
	local anchors = branchAnchors(sample, branchType, length, rng)
	local samplePositions, pathLength = RoadPathUtils.samplePath(anchors, WorldConstants.DefaultSampleSpacing, {
		Closed = false,
		DenseSegmentSamples = 12,
	})
	local samples = RoadPathUtils.sampleDescriptors(samplePositions, pathLength, false)
	RoadPathUtils.fitHeights(samples, sampleHeight, profile.MaxRoadGradeDegrees, false)

	local serializedSamples = {}
	for _, descriptor in ipairs(samples) do
		serializedSamples[#serializedSamples + 1] = {
			Position = pointToArray(descriptor.Position),
			Tangent = pointToArray(descriptor.Tangent),
			Right = pointToArray(descriptor.Right),
			Up = pointToArray(descriptor.Up),
			Curvature = descriptor.Curvature,
			LapDistance = descriptor.LapDistance,
		}
	end

	local finishSample = samples[#samples]
	local penultimate = samples[math.max(1, #samples - 1)]

	return {
		Id = ("%s_%d"):format(branchType, sampleIndex),
		Type = branchType,
		RoadSampleIndex = sampleIndex,
		Length = pathLength,
		Blocked = branchType ~= WorldConstants.BranchTypes.ServiceSpur,
		Samples = serializedSamples,
		Blocker = {
			Position = pointToArray(finishSample.Position),
			LookAt = pointToArray(penultimate.Position),
		},
	}
end

function BranchPlanner.plan(loop, profile, options)
	local sampleHeight = assert(options and options.SampleHeight, "BranchPlanner.plan requires SampleHeight")
	local seed = assert(options and options.Seed, "BranchPlanner.plan requires Seed")
	local parcels = options and options.Parcels or {}
	local branches = {}
	local usedSamples = {}
	local targetCount = profile.BranchConfig.TotalBranches or 0
	local branchIndex = 1

	for _, parcel in ipairs(parcels) do
		usedSamples[parcel.RoadSampleIndex] = true
	end

	for _, branchType in ipairs(BRANCH_ORDER) do
		if #branches >= targetCount then
			break
		end

		for sampleIndex = 10, #loop.Samples, 18 do
			if #branches >= targetCount then
				break
			end
			if not usedSamples[sampleIndex] then
				usedSamples[sampleIndex] = true
				local length = profile.BranchConfig.MinBranchLength + ((branchIndex - 1) % 3) * ((profile.BranchConfig.MaxBranchLength - profile.BranchConfig.MinBranchLength) * 0.5)
				branches[#branches + 1] = branchDescriptor(loop, profile, sampleIndex, branchType, length, sampleHeight, seed)
				branchIndex += 1
			end
		end
	end

	return branches
end

return BranchPlanner
