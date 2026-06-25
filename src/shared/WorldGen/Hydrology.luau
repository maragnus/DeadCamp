local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))
local RoadSpatialIndex = require(script.Parent:WaitForChild("RoadSpatialIndex"))
local WorldMath = require(script.Parent:WaitForChild("WorldMath"))
local WorldSeed = require(script.Parent:WaitForChild("WorldSeed"))

local Hydrology = {}

local SAMPLE_SPACING = 12

local function vectorToArray(vector)
	return { vector.X, vector.Y, vector.Z }
end

local function arrayToVector(values)
	return Vector3.new(values[1], values[2], values[3])
end

local function closestOnSegmentXZ(position, a, b)
	local apx = position.X - a.X
	local apz = position.Z - a.Z
	local abx = b.X - a.X
	local abz = b.Z - a.Z
	local lengthSquared = abx * abx + abz * abz
	if lengthSquared <= 1e-4 then
		return 0, math.sqrt(apx * apx + apz * apz)
	end

	local alpha = WorldMath.clamp((apx * abx + apz * abz) / lengthSquared, 0, 1)
	local closestX = a.X + abx * alpha
	local closestZ = a.Z + abz * alpha
	local dx = position.X - closestX
	local dz = position.Z - closestZ
	return alpha, math.sqrt(dx * dx + dz * dz)
end

local function riverControlPoint(horizontal, alongValue, lateralValue)
	if horizontal then
		return Vector3.new(alongValue, 0, lateralValue)
	end
	return Vector3.new(lateralValue, 0, alongValue)
end

function Hydrology.describeReservationHooks()
	return {
		Enabled = true,
		Reason = "Hydrology drives real river planning, terrain carving, and river-clearance validation",
		ReservedAPIs = {
			"collectCrossingCandidates",
			"reserveBridgeSpans",
			"stampRiverCorridors",
		},
	}
end

function Hydrology.generate(profile, seed)
	local riverConfig = profile.RiverConfig
	if riverConfig.Enabled == false then
		return nil
	end
	local safeHalf = profile.MapSizeStuds * 0.5 - profile.EdgeMarginStuds * 0.6
	local rng = WorldSeed.random(seed, "Hydrology")
	local horizontal = rng:NextNumber() < 0.5
	local controlCount = rng:NextInteger(4, 6)
	local startLateral = rng:NextNumber(-safeHalf * 0.28, safeHalf * 0.28)
	local endLateral = WorldMath.clamp(
		startLateral + rng:NextNumber(-safeHalf * 0.24, safeHalf * 0.24),
		-safeHalf * 0.34,
		safeHalf * 0.34
	)
	local phase = rng:NextNumber(0, math.pi * 2)
	local meander = riverConfig.MeanderStrength
	local controls = {}

	for controlIndex = 1, controlCount do
		local alpha = (controlIndex - 1) / math.max(1, controlCount - 1)
		local along = WorldMath.lerp(-safeHalf, safeHalf, alpha)
		local lateral = WorldMath.lerp(startLateral, endLateral, alpha)
		if controlIndex > 1 and controlIndex < controlCount then
			lateral += math.sin(alpha * math.pi * 2 + phase) * meander * 0.45
			lateral += rng:NextNumber(-meander * 0.35, meander * 0.35)
		end
		lateral = WorldMath.clamp(lateral, -safeHalf * 0.46, safeHalf * 0.46)
		controls[#controls + 1] = riverControlPoint(horizontal, along, lateral)
	end

	local samplePositions, pathLength = RoadPathUtils.samplePath(controls, SAMPLE_SPACING, {
		Closed = false,
		DenseSegmentSamples = 18,
	})
	local samples = RoadPathUtils.sampleDescriptors(samplePositions, pathLength, false)
	local baseWidth = rng:NextNumber(riverConfig.WidthMin, riverConfig.WidthMax) * 0.5
	local widthPhase = rng:NextNumber(0, math.pi * 2)
	local startWaterY = riverConfig.WaterLevelBase + rng:NextNumber(-riverConfig.WaterLevelVariance, riverConfig.WaterLevelVariance)
	local endWaterY = startWaterY + rng:NextNumber(-riverConfig.WaterSlope, riverConfig.WaterSlope)
	local serialized = {}

	for sampleIndex, sample in ipairs(samples) do
		local alpha = (sampleIndex - 1) / math.max(1, #samples - 1)
		local widthScale = 1 + math.sin(alpha * math.pi * 2 + widthPhase) * riverConfig.WidthVariance
		local halfWidth = WorldMath.clamp(
			baseWidth * widthScale,
			riverConfig.WidthMin * 0.5,
			riverConfig.WidthMax * 0.5
		)
		local bankHalfWidth = halfWidth + riverConfig.BankWidth
		bankHalfWidth += math.sin(alpha * math.pi + widthPhase * 0.5) * riverConfig.BankWidthVariance * 0.3
		bankHalfWidth = math.max(halfWidth + 6, bankHalfWidth)
		serialized[#serialized + 1] = {
			Position = vectorToArray(sample.Position),
			Tangent = vectorToArray(sample.Tangent),
			Right = vectorToArray(sample.Right),
			Up = vectorToArray(sample.Up),
			WaterY = WorldMath.lerp(startWaterY, endWaterY, alpha),
			HalfWidth = halfWidth,
			BankHalfWidth = bankHalfWidth,
			FloodplainWidth = riverConfig.FloodplainWidth,
		}
	end

	local controlArrays = {}
	for index, point in ipairs(controls) do
		controlArrays[index] = vectorToArray(point)
	end

	return {
		Orientation = horizontal and "Horizontal" or "Vertical",
		Controls = controlArrays,
		Samples = serialized,
		PathLength = pathLength,
		WaterDepth = riverConfig.WaterDepth,
		RoadClearance = riverConfig.RoadClearance,
		BankLift = 4.5,
	}
end

function Hydrology.createRuntime(descriptor)
	if not descriptor then
		return nil
	end

	local samples = {}

	for _, sample in ipairs(descriptor.Samples or {}) do
		samples[#samples + 1] = {
			Position = arrayToVector(sample.Position),
			Tangent = arrayToVector(sample.Tangent),
			Right = arrayToVector(sample.Right),
			Up = arrayToVector(sample.Up),
			WaterY = sample.WaterY,
			HalfWidth = sample.HalfWidth,
			BankHalfWidth = sample.BankHalfWidth,
			FloodplainWidth = sample.FloodplainWidth,
		}
	end

	local pseudoLoop = { Samples = samples }
	local indexRadius = 72
	for _, sample in ipairs(samples) do
		indexRadius = math.max(indexRadius, sample.BankHalfWidth + sample.FloodplainWidth + descriptor.RoadClearance + 24)
	end

	return {
		Descriptor = descriptor,
		Samples = samples,
		SpatialIndex = RoadSpatialIndex.build(pseudoLoop, math.max(36, indexRadius * 0.45)),
		MaxQueryRadius = indexRadius,
	}
end

function Hydrology.sample(runtime, position)
	if not runtime or not runtime.SpatialIndex then
		return nil
	end

	local nearestIndex, nearestSample, nearestDistance = RoadSpatialIndex.nearest(
		runtime.SpatialIndex,
		position,
		runtime.MaxQueryRadius
	)
	if not nearestIndex or not nearestSample then
		return nil
	end

	local nextSample = runtime.Samples[math.min(#runtime.Samples, nearestIndex + 1)] or nearestSample
	local alpha = 0
	local distance = nearestDistance
	if nextSample ~= nearestSample then
		alpha, distance = closestOnSegmentXZ(position, nearestSample.Position, nextSample.Position)
	end

	local halfWidth = WorldMath.lerp(nearestSample.HalfWidth, nextSample.HalfWidth, alpha)
	local bankHalfWidth = WorldMath.lerp(nearestSample.BankHalfWidth, nextSample.BankHalfWidth, alpha)
	local floodplainWidth = WorldMath.lerp(nearestSample.FloodplainWidth, nextSample.FloodplainWidth, alpha)
	local waterY = WorldMath.lerp(nearestSample.WaterY, nextSample.WaterY, alpha)

	return {
		Distance = distance,
		HalfWidth = halfWidth,
		BankHalfWidth = bankHalfWidth,
		FloodplainWidth = floodplainWidth,
		WaterY = waterY,
		ClearanceHalfWidth = bankHalfWidth + runtime.Descriptor.RoadClearance,
		InWater = distance <= halfWidth,
		InBank = distance <= bankHalfWidth,
		InFloodplain = distance <= bankHalfWidth + floodplainWidth,
	}
end

return Hydrology
