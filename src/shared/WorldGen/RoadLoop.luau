local RunService = game:GetService("RunService")

local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))
local WorldMath = require(script.Parent:WaitForChild("WorldMath"))
local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))
local WorldProfile = require(script.Parent:WaitForChild("WorldProfile"))
local WorldSeed = require(script.Parent:WaitForChild("WorldSeed"))

local RoadLoop = {}
local lastFailure = nil

local RETRY_LIMIT = 18
local SHORTCUT_DISTANCE_THRESHOLD = 116
local SHORTCUT_LAP_THRESHOLD = 220
local MAX_FAILURE_EXAMPLES = 6
local CORNER_ARC_INTERIOR_POINTS = 4

local RETRY_STRATEGIES = {
	{
		Name = "Aggressive",
		RegularFeatureDepthScale = 0.92,
		DeepFeatureDepthScale = 1.0,
		CornerJitterScale = 1.0,
		CornerInsetScale = 1.0,
	},
	{
		Name = "AggressiveWide",
		RegularFeatureDepthScale = 0.86,
		DeepFeatureDepthScale = 0.92,
		CornerJitterScale = 0.86,
		CornerInsetScale = 0.98,
	},
	{
		Name = "Balanced",
		RegularFeatureDepthScale = 0.78,
		DeepFeatureDepthScale = 0.82,
		CornerJitterScale = 0.72,
		CornerInsetScale = 0.97,
	},
	{
		Name = "BalancedSingle",
		RegularFeatureDepthScale = 0.72,
		DeepFeatureDepthScale = 0.74,
		CornerJitterScale = 0.62,
		CornerInsetScale = 0.96,
	},
	{
		Name = "Conservative",
		RegularFeatureDepthScale = 0.62,
		DeepFeatureDepthScale = 0.66,
		CornerJitterScale = 0.5,
		CornerInsetScale = 0.94,
	},
	{
		Name = "Recovery",
		RegularFeatureDepthScale = 0.54,
		DeepFeatureDepthScale = 0.54,
		CornerJitterScale = 0.4,
		CornerInsetScale = 0.92,
	},
}

local function sidePoint(startPoint, finishPoint, inwardVector, alongAlpha, inwardAmount)
	return startPoint:Lerp(finishPoint, alongAlpha) + inwardVector * inwardAmount
end

local function depthFromRatioRange(rng, safeHalf, minRatio, maxRatio, scale)
	return rng:NextNumber(safeHalf * minRatio, safeHalf * maxRatio) * scale
end

local function appendPoints(points, additions)
	for _, point in ipairs(additions) do
		points[#points + 1] = point
	end
end

local function buildSideDeviationPoints(side, depth, pointCount, shapePower, skewAmount)
	local points = {}

	for pointIndex = 1, pointCount do
		local baseAlpha = pointIndex / (pointCount + 1)
		local alongAlpha = WorldMath.smoothStep(0, 1, baseAlpha)
		local bell = math.sin(alongAlpha * math.pi)
		local skewFactor = WorldMath.clamp(1 + skewAmount * (alongAlpha - 0.5) * 2, 0.72, 1.28)
		local inwardAmount = depth * (bell ^ shapePower) * skewFactor
		points[#points + 1] = sidePoint(side.StartSweep, side.EndSweep, side.Inward, alongAlpha, inwardAmount)
	end

	return points
end

local function mildSidePoints(profile, safeHalf, strategy, rng, side)
	local depth = depthFromRatioRange(
		rng,
		safeHalf,
		profile.MildDeviationDepthMin,
		profile.MildDeviationDepthMax,
		strategy.RegularFeatureDepthScale
	)
	local pointCount = profile.AnchorCount >= 16 and 5 or 4
	local shapePower = rng:NextNumber(1.2, 1.55)
	local skewAmount = rng:NextNumber(-0.14, 0.14)
	return buildSideDeviationPoints(side, depth, pointCount, shapePower, skewAmount)
end

local function centerDeviationPoints(profile, safeHalf, strategy, rng, side)
	local depth = depthFromRatioRange(
		rng,
		safeHalf,
		profile.CenterDeviationDepthMin,
		profile.CenterDeviationDepthMax,
		strategy.DeepFeatureDepthScale
	)
	local pointCount = profile.AnchorCount >= 14 and 7 or 6
	local shapePower = rng:NextNumber(0.95, 1.15)
	local skewAmount = rng:NextNumber(-0.22, 0.22)
	return buildSideDeviationPoints(side, depth, pointCount, shapePower, skewAmount)
end

local function pickCenterDeviationSides(rng, profile)
	local minCount = math.floor(profile.CenterDeviationSidesMin)
	local maxCount = math.floor(profile.CenterDeviationSidesMax)
	local targetCount = rng:NextInteger(minCount, maxCount)
	local selected = {}
	if targetCount <= 0 then
		return selected
	end

	local primarySide = rng:NextInteger(1, 4)
	selected[primarySide] = true
	if targetCount >= 2 then
		local offsetChoices = { 1, 2, 3 }
		local offset = offsetChoices[rng:NextInteger(1, #offsetChoices)]
		selected[((primarySide + offset - 1) % 4) + 1] = true
	end

	return selected
end

local function cornerArcInteriorPoints(cornerPoint, entrySide, exitSide, cornerSweep)
	local center = cornerPoint + (entrySide.Inward + exitSide.Inward) * cornerSweep
	local startVector = entrySide.EndSweep - center
	local endVector = exitSide.StartSweep - center
	local startAngle = math.atan2(startVector.Z, startVector.X)
	local deltaAngle = WorldMath.angleAroundY(startVector, endVector)
	local points = {}

	for step = 1, CORNER_ARC_INTERIOR_POINTS do
		local alpha = step / (CORNER_ARC_INTERIOR_POINTS + 1)
		local angle = startAngle + deltaAngle * alpha
		points[#points + 1] = center + Vector3.new(math.cos(angle) * cornerSweep, 0, math.sin(angle) * cornerSweep)
	end

	return points
end

local function retryStrategy(attempt)
	return RETRY_STRATEGIES[math.min(#RETRY_STRATEGIES, math.floor(attempt / 3) + 1)]
end

local function buildAnchors(profile, seed, strategy)
	local rng = WorldSeed.random(seed, "RoadLoopAnchors")
	local safeHalf = profile.MapSizeStuds * 0.5 - profile.EdgeMarginStuds
	local trackHalf = math.min(safeHalf * 0.84, profile.TargetLoopLength / 8)
	local cornerJitter = math.min(92, safeHalf * 0.12) * strategy.CornerJitterScale
	local cornerSweep = WorldMath.clamp(
		profile.CornerSweepStuds * (1 + (1 - strategy.RegularFeatureDepthScale) * 0.35),
		profile.MinCurveRadius * 2,
		safeHalf * 0.28
	)
	local cornerInset = WorldMath.clamp(
		math.max(trackHalf * 0.88, safeHalf * 0.72) * strategy.CornerInsetScale,
		safeHalf * 0.62 + cornerSweep,
		safeHalf * 0.88
	)
	local topZ = -cornerInset - rng:NextNumber(0, cornerJitter)
	local rightX = cornerInset + rng:NextNumber(0, cornerJitter)
	local bottomZ = cornerInset + rng:NextNumber(0, cornerJitter)
	local leftX = -cornerInset - rng:NextNumber(0, cornerJitter)
	local corners = {
		Vector3.new(leftX, 0, topZ),
		Vector3.new(rightX, 0, topZ),
		Vector3.new(rightX, 0, bottomZ),
		Vector3.new(leftX, 0, bottomZ),
	}
	local sides = {
		{ Start = corners[1], Finish = corners[2], Inward = Vector3.new(0, 0, 1) },
		{ Start = corners[2], Finish = corners[3], Inward = Vector3.new(-1, 0, 0) },
		{ Start = corners[3], Finish = corners[4], Inward = Vector3.new(0, 0, -1) },
		{ Start = corners[4], Finish = corners[1], Inward = Vector3.new(1, 0, 0) },
	}
	local centerDeviationSides = pickCenterDeviationSides(rng, profile)

	for _, side in ipairs(sides) do
		side.Direction = (side.Finish - side.Start).Unit
		side.StartSweep = side.Start + side.Direction * cornerSweep
		side.EndSweep = side.Finish - side.Direction * cornerSweep
	end

	local anchors = { sides[1].StartSweep }
	for sideIndex, side in ipairs(sides) do
		local sidePoints
		if centerDeviationSides[sideIndex] then
			sidePoints = centerDeviationPoints(profile, safeHalf, strategy, rng, side)
		else
			sidePoints = mildSidePoints(profile, safeHalf, strategy, rng, side)
		end

		appendPoints(anchors, sidePoints)
		anchors[#anchors + 1] = side.EndSweep

		local nextIndex = (sideIndex % #sides) + 1
		appendPoints(anchors, cornerArcInteriorPoints(side.Finish, side, sides[nextIndex], cornerSweep))
		if nextIndex > 1 then
			anchors[#anchors + 1] = sides[nextIndex].StartSweep
		end
	end

	return anchors
end

local function validateAnchorSeam(anchors)
	if #anchors < 4 then
		return false, "insufficient anchors"
	end

	local firstAnchor = anchors[1]
	local lastAnchor = anchors[#anchors]
	if (firstAnchor - lastAnchor).Magnitude <= 1e-3 then
		return false, "duplicate closing anchor"
	end

	for index = 1, #anchors do
		local nextIndex = (index % #anchors) + 1
		if (anchors[index] - anchors[nextIndex]).Magnitude <= 1e-3 then
			return false, ("duplicate consecutive anchors at %d/%d"):format(index, nextIndex)
		end
	end

	return true, nil
end

local function rotateSamples(samples, startIndex)
	local rotated = {}
	for offset = 0, #samples - 1 do
		rotated[#rotated + 1] = samples[WorldMath.wrapIndex(startIndex + offset, #samples)]
	end
	return rotated
end

local function sampleDescriptors(samplePositions, loopLength)
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

local function validateBounds(samples, profile)
	local halfSize = profile.MapSizeStuds * 0.5 - profile.EdgeMarginStuds
	local maximumOverflow = 0
	local offendingSample = nil

	for sampleIndex, sample in ipairs(samples) do
		local overflow = math.max(math.abs(sample.Position.X) - halfSize, math.abs(sample.Position.Z) - halfSize)
		if overflow > maximumOverflow then
			maximumOverflow = overflow
			offendingSample = sampleIndex
		end
	end

	return maximumOverflow <= 0, {
		MaxOverflow = maximumOverflow,
		SampleIndex = offendingSample,
	}
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

local function shortcutHotspots(samples, loopLength)
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

local function validateCurveRadius(samples, profile)
	local minimumRadius = math.huge
	local minimumIndex = nil

	for index, sample in ipairs(samples) do
		local curvatureMagnitude = math.abs(sample.Curvature)
		if curvatureMagnitude > 1e-4 then
			local radius = 1 / curvatureMagnitude
			if radius < minimumRadius then
				minimumRadius = radius
				minimumIndex = index
			end
		end
	end

	if minimumRadius == math.huge then
		minimumRadius = profile.TargetLoopLength
		minimumIndex = 1
	end

	return minimumRadius >= profile.MinCurveRadius, {
		MinimumRadius = minimumRadius,
		SampleIndex = minimumIndex,
	}
end

local function evaluateAttempt(samples, profile)
	local boundsOk, boundsData = validateBounds(samples, profile)
	local intersectionOk, intersectionData = validateSelfIntersection(samples)
	local curveOk, curveData = validateCurveRadius(samples, profile)

	return {
		Accepted = boundsOk and intersectionOk and curveOk,
		BoundsOk = boundsOk,
		Bounds = boundsData,
		SelfIntersectionOk = intersectionOk,
		Intersections = intersectionData,
		CurveOk = curveOk,
		Curve = curveData,
	}
end

local function failureLine(attemptNumber, attemptSeed, strategy, diagnostics, profile)
	local reasons = {}
	if not diagnostics.BoundsOk then
		reasons[#reasons + 1] = ("bounds overflow %.1f"):format(diagnostics.Bounds.MaxOverflow)
	end
	if not diagnostics.SelfIntersectionOk then
		reasons[#reasons + 1] = ("self intersections %d near %d/%d"):format(
			diagnostics.Intersections.Count,
			diagnostics.Intersections.SampleA or -1,
			diagnostics.Intersections.SampleB or -1
		)
	end
	if not diagnostics.CurveOk then
		reasons[#reasons + 1] = ("min radius %.1f < %.1f"):format(diagnostics.Curve.MinimumRadius, profile.MinCurveRadius)
	end

	return ("attempt %d seed %d strategy %s [%s]"):format(
		attemptNumber,
		attemptSeed,
		strategy.Name,
		table.concat(reasons, ", ")
	)
end

local function isBetterAttempt(candidate, currentBest)
	if not currentBest then
		return true
	end

	local candidateIntersections = candidate.Diagnostics.Intersections.Count
	local currentIntersections = currentBest.Diagnostics.Intersections.Count
	if candidateIntersections ~= currentIntersections then
		return candidateIntersections < currentIntersections
	end

	local candidateCurveDeficit = math.max(0, candidate.Profile.MinCurveRadius - candidate.Diagnostics.Curve.MinimumRadius)
	local currentCurveDeficit = math.max(0, currentBest.Profile.MinCurveRadius - currentBest.Diagnostics.Curve.MinimumRadius)
	if candidateCurveDeficit ~= currentCurveDeficit then
		return candidateCurveDeficit < currentCurveDeficit
	end

	local candidateOverflow = candidate.Diagnostics.Bounds.MaxOverflow
	local currentOverflow = currentBest.Diagnostics.Bounds.MaxOverflow
	if candidateOverflow ~= currentOverflow then
		return candidateOverflow < currentOverflow
	end

	return candidate.AttemptNumber > currentBest.AttemptNumber
end

local function buildFailureAttempt(profile, attemptNumber, attemptSeed, strategy, anchors, samples, loopLength, diagnostics)
	return {
		Profile = {
			Id = profile.Id,
			MinCurveRadius = profile.MinCurveRadius,
		},
		AttemptNumber = attemptNumber,
		AttemptSeed = attemptSeed,
		StrategyName = strategy.Name,
		Anchors = WorldMath.deepCopy(anchors),
		Samples = WorldMath.deepCopy(samples),
		LoopLength = loopLength,
		Diagnostics = WorldMath.deepCopy(diagnostics),
	}
end

function RoadLoop.latestFailure()
	return WorldMath.deepCopy(lastFailure)
end

function RoadLoop.generate(profileInput, seedInput)
	local profile = WorldProfile.resolve(profileInput)
	local seed = WorldSeed.normalize(seedInput)
	lastFailure = nil
	local failureCounts = {
		Bounds = 0,
		SelfIntersection = 0,
		CurveRadius = 0,
	}
	local failureExamples = {}
	local bestAttempt = nil

	for attempt = 0, RETRY_LIMIT - 1 do
		local strategy = retryStrategy(attempt)
		local attemptSeed = seed + attempt * 193
		local anchors = buildAnchors(profile, attemptSeed, strategy)
		local anchorsOk, anchorError = validateAnchorSeam(anchors)
		if not anchorsOk then
			error(("RoadLoop.generate produced an invalid closed-anchor seam: %s"):format(anchorError or "unknown"), 2)
		end
		local samplePositions, loopLength = RoadPathUtils.samplePath(anchors, WorldConstants.DefaultSampleSpacing, {
			Closed = true,
			DenseSegmentSamples = 18,
		})
		local samples = sampleDescriptors(samplePositions, loopLength)
		local diagnostics = evaluateAttempt(samples, profile)

		if diagnostics.Accepted then
			lastFailure = nil
			if attempt > 0 and RunService:IsStudio() then
				warn(("RoadLoop.generate accepted after %d retries for profile %s seed %d with strategy %s. Prior rejects: bounds=%d, selfIntersection=%d, curveRadius=%d"):format(
					attempt,
					profile.Id,
					seed,
					strategy.Name,
					failureCounts.Bounds,
					failureCounts.SelfIntersection,
					failureCounts.CurveRadius
				))
			end

			return {
				ProfileId = profile.Id,
				Seed = seed,
				LoopLength = loopLength,
				StartIndex = 1,
				MinimumCurveRadius = diagnostics.Curve.MinimumRadius,
				Samples = samples,
				ShortcutHotspots = shortcutHotspots(samples, loopLength),
			}
		end

		if not diagnostics.BoundsOk then
			failureCounts.Bounds += 1
		end
		if not diagnostics.SelfIntersectionOk then
			failureCounts.SelfIntersection += 1
		end
		if not diagnostics.CurveOk then
			failureCounts.CurveRadius += 1
		end

		if #failureExamples < MAX_FAILURE_EXAMPLES then
			failureExamples[#failureExamples + 1] = failureLine(attempt + 1, attemptSeed, strategy, diagnostics, profile)
		end

		local failureAttempt = buildFailureAttempt(profile, attempt + 1, attemptSeed, strategy, anchors, samples, loopLength, diagnostics)
		if isBetterAttempt(failureAttempt, bestAttempt) then
			bestAttempt = failureAttempt
		end
	end

	lastFailure = {
		ProfileId = profile.Id,
		Seed = seed,
		Attempts = RETRY_LIMIT,
		FailureCounts = WorldMath.deepCopy(failureCounts),
		FailureExamples = WorldMath.deepCopy(failureExamples),
		BestAttempt = bestAttempt,
	}

	error((
		"RoadLoop.generate failed for profile %s seed %d after %d attempts. Reject counts: bounds=%d, selfIntersection=%d, curveRadius=%d. Sample rejects: %s"
	):format(
		profile.Id,
		seed,
		RETRY_LIMIT,
		failureCounts.Bounds,
		failureCounts.SelfIntersection,
		failureCounts.CurveRadius,
		table.concat(failureExamples, " | ")
	), 2)
end

return RoadLoop
