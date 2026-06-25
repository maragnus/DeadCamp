local RoadLoopSettings = require(script.Parent:WaitForChild("RoadLoopSettings"))
local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))
local WorldMath = require(script.Parent:WaitForChild("WorldMath"))

local RoadLoopDiagnostics = {}

local SHORTCUT_DISTANCE_THRESHOLD = 116
local SHORTCUT_LAP_THRESHOLD = 220

local function rotateSamples(samples, startIndex)
	local rotated = {}
	for offset = 0, #samples - 1 do
		rotated[#rotated + 1] = samples[WorldMath.wrapIndex(startIndex + offset, #samples)]
	end
	return rotated
end

function RoadLoopDiagnostics.describeLoop(samplePositions, loopLength)
	local descriptors = RoadPathUtils.sampleDescriptors(samplePositions, loopLength, true)
	local startIndex = 1
	local bestScore = -math.huge

	for index, sample in ipairs(descriptors) do
		local score = sample.Position.Z + math.abs(sample.Position.X) * 0.12 - math.abs(sample.Curvature) * 110
		if score > bestScore then
			bestScore = score
			startIndex = index
		end
	end

	local rotatedSamples = rotateSamples(descriptors, startIndex)
	for index, sample in ipairs(rotatedSamples) do
		sample.LapDistance = ((index - 1) / #rotatedSamples) * loopLength
	end

	return rotatedSamples
end

local function segmentIntersectionPointXZ(a0, a1, b0, b1)
	local ax = a1.X - a0.X
	local az = a1.Z - a0.Z
	local bx = b1.X - b0.X
	local bz = b1.Z - b0.Z
	local determinant = ax * bz - az * bx
	if math.abs(determinant) <= 1e-4 then
		return nil
	end

	local cx = b0.X - a0.X
	local cz = b0.Z - a0.Z
	local t = (cx * bz - cz * bx) / determinant
	local u = (cx * az - cz * ax) / determinant
	if t <= 1e-4 or t >= 1 - 1e-4 or u <= 1e-4 or u >= 1 - 1e-4 then
		return nil
	end

	local pointA = a0:Lerp(a1, t)
	local pointB = b0:Lerp(b1, u)
	return (pointA + pointB) * 0.5
end

local function validateSelfIntersection(samples)
	local count = 0
	local firstA = nil
	local firstB = nil
	local firstPoint = nil

	for aIndex = 1, #samples do
		local a0 = samples[aIndex].Position
		local a1 = samples[WorldMath.wrapIndex(aIndex + 1, #samples)].Position

		for bIndex = aIndex + 2, #samples do
			if WorldMath.wrapIndex(aIndex - 1, #samples) ~= bIndex and WorldMath.wrapIndex(bIndex + 1, #samples) ~= aIndex then
				local b0 = samples[bIndex].Position
				local b1 = samples[WorldMath.wrapIndex(bIndex + 1, #samples)].Position
				if WorldMath.segmentIntersectionXZ(a0, a1, b0, b1) then
					count += 1
					if not firstA then
						firstA = aIndex
						firstB = bIndex
						firstPoint = segmentIntersectionPointXZ(a0, a1, b0, b1)
					end
				end
			end
		end
	end

	return count == 0, {
		Count = count,
		SampleA = firstA,
		SampleB = firstB,
		Position = firstPoint,
	}
end

local function sampleScenicScore(samples, options)
	if not options or type(options.SampleLandContext) ~= "function" then
		return {
			ScenicScore = 0,
		}
	end

	local scenicScore = 0
	for _, sample in ipairs(samples) do
		local context = options.SampleLandContext(sample.Position.X, sample.Position.Z)
		if context and context.River then
			local scenicCenter = context.River.ClearanceHalfWidth + 92
			local scenicHalfSpan = 92
			local scenicAlpha = 1 - math.abs(context.River.Distance - scenicCenter) / scenicHalfSpan
			if scenicAlpha > 0 then
				scenicScore += scenicAlpha
			end
		end

		scenicScore += (context and context.BasinShelfBias or 0) * 0.45
		scenicScore -= (context and context.RidgeCrestRisk or 0) * 0.8
	end

	return {
		ScenicScore = scenicScore / math.max(1, #samples),
	}
end

local function quadrantName(point)
	if point.X >= 0 and point.Z < 0 then
		return "NorthEast"
	elseif point.X >= 0 and point.Z >= 0 then
		return "SouthEast"
	elseif point.X < 0 and point.Z >= 0 then
		return "SouthWest"
	end
	return "NorthWest"
end

function RoadLoopDiagnostics.evaluateCoverage(samples, profile)
	local settings = RoadLoopSettings.resolve(profile)
	local safeHalf = profile.MapSizeStuds * 0.5 - profile.EdgeMarginStuds
	local minX = math.huge
	local maxX = -math.huge
	local minZ = math.huge
	local maxZ = -math.huge
	local quadrants = {}
	local outerTouches = 0

	for _, sample in ipairs(samples or {}) do
		local point = sample.Position
		minX = math.min(minX, point.X)
		maxX = math.max(maxX, point.X)
		minZ = math.min(minZ, point.Z)
		maxZ = math.max(maxZ, point.Z)

		local edgeRatio = math.max(math.abs(point.X), math.abs(point.Z)) / math.max(1, safeHalf)
		if edgeRatio >= 0.72 then
			quadrants[quadrantName(point)] = true
			outerTouches += 1
		end
	end

	if minX == math.huge then
		minX, maxX, minZ, maxZ = 0, 0, 0, 0
	end

	local widthCoverage = math.max(0, maxX - minX) / math.max(1, safeHalf * 2)
	local depthCoverage = math.max(0, maxZ - minZ) / math.max(1, safeHalf * 2)
	local footprintAreaRatio = math.min(1, widthCoverage) * math.min(1, depthCoverage)
	local quadrantsReached = WorldMath.tableCount(quadrants)
	local quadrantsMissing = {}
	for _, name in ipairs({ "NorthWest", "NorthEast", "SouthEast", "SouthWest" }) do
		if not quadrants[name] then
			quadrantsMissing[#quadrantsMissing + 1] = name
		end
	end

	local weights = settings.ScoreWeights
	local envelopeScore = (math.min(1, widthCoverage) + math.min(1, depthCoverage)) * 0.5
	local coverageScore = envelopeScore * weights.Footprint
	coverageScore += (quadrantsReached / 4) * weights.Quadrants

	return {
		WidthCoverage = widthCoverage,
		DepthCoverage = depthCoverage,
		FootprintAreaRatio = footprintAreaRatio,
		QuadrantsReached = quadrantsReached,
		QuadrantsMissing = quadrantsMissing,
		OuterTouches = outerTouches,
		Score = coverageScore,
	}
end

function RoadLoopDiagnostics.evaluate(samples, profile, options)
	local intersectionOk, intersectionData = validateSelfIntersection(samples)
	local coverageData = RoadLoopDiagnostics.evaluateCoverage(samples, profile)
	local scenicData = sampleScenicScore(samples, options)

	return {
		Accepted = intersectionOk,
		SelfIntersectionOk = intersectionOk,
		Intersections = intersectionData,
		Coverage = coverageData,
		LandIntent = scenicData,
	}
end

function RoadLoopDiagnostics.shortcutHotspots(samples, loopLength)
	local hotspots = {}

	for aIndex = 1, #samples do
		local a = samples[aIndex]
		for bIndex = aIndex + 6, #samples do
			local b = samples[bIndex]
			local worldDistance = WorldMath.distanceXZ(a.Position, b.Position)
			if worldDistance <= SHORTCUT_DISTANCE_THRESHOLD then
				local lapDistance = math.abs(a.LapDistance - b.LapDistance)
				lapDistance = math.min(lapDistance, loopLength - lapDistance)
				if lapDistance >= SHORTCUT_LAP_THRESHOLD then
					hotspots[#hotspots + 1] = {
						Position = { (a.Position.X + b.Position.X) * 0.5, 0, (a.Position.Z + b.Position.Z) * 0.5 },
						WorldDistance = worldDistance,
						LapDistance = lapDistance,
						SampleA = aIndex,
						SampleB = bIndex,
					}
				end
			end
		end
	end

	return hotspots
end

return RoadLoopDiagnostics
