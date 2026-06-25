local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))
local WorldMath = require(script.Parent:WaitForChild("WorldMath"))

local RoadPathUtils = {}
local KNOT_EPSILON = 1e-3
local SAMPLE_EPSILON = 1e-4

local function knotInterval(a, b)
	local distance = (b - a).Magnitude
	local interval = distance ^ 0.5
	return math.max(KNOT_EPSILON, interval)
end

local function blendPoint(a, b, ta, tb, t)
	if math.abs(tb - ta) <= KNOT_EPSILON then
		return b
	end

	return a:Lerp(b, (t - ta) / (tb - ta))
end

local function catmullRomCentripetal(p0, p1, p2, p3, t)
	local t0 = 0
	local t1 = t0 + knotInterval(p0, p1)
	local t2 = t1 + knotInterval(p1, p2)
	local t3 = t2 + knotInterval(p2, p3)
	local tt = WorldMath.lerp(t1, t2, t)

	local a1 = blendPoint(p0, p1, t0, t1, tt)
	local a2 = blendPoint(p1, p2, t1, t2, tt)
	local a3 = blendPoint(p2, p3, t2, t3, tt)

	local b1 = blendPoint(a1, a2, t0, t2, tt)
	local b2 = blendPoint(a2, a3, t1, t3, tt)

	return blendPoint(b1, b2, t1, t2, tt)
end

local function densePath(anchors, closed, segmentSamples)
	local points = {}
	local count = #anchors

	for index = 1, (closed and count or count - 1) do
		local p0
		local p1 = anchors[index]
		local p2 = anchors[index + 1] or anchors[1]
		local p3

		if closed then
			p0 = anchors[WorldMath.wrapIndex(index - 1, count)]
			p3 = anchors[WorldMath.wrapIndex(index + 2, count)]
		else
			p0 = anchors[math.max(1, index - 1)]
			p3 = anchors[math.min(count, index + 2)]
		end

		for step = 0, segmentSamples - 1 do
			local t = step / segmentSamples
			points[#points + 1] = catmullRomCentripetal(p0, p1, p2, p3, t)
		end
	end

	if not closed then
		points[#points + 1] = anchors[#anchors]
	end

	return points
end

function RoadPathUtils.pathLength(points, closed)
	local totalLength = 0

	for index = 2, #points do
		totalLength += (points[index] - points[index - 1]).Magnitude
	end
	if closed and #points > 1 then
		totalLength += (points[1] - points[#points]).Magnitude
	end

	return totalLength
end

function RoadPathUtils.resampleByArcLength(points, spacing, closed)
	local samples = {}
	local totalLength = RoadPathUtils.pathLength(points, closed)

	local targetDistance = 0
	local currentDistance = 0
	local segmentStart = points[1]
	local segmentIndex = 2
	local endIndex = closed and (#points + 1) or #points

	while targetDistance < totalLength and segmentIndex <= endIndex do
		local nextPoint
		if segmentIndex > #points then
			if not closed then
				break
			end
			nextPoint = points[1]
		else
			nextPoint = points[segmentIndex]
		end

		local segmentLength = (nextPoint - segmentStart).Magnitude
		if currentDistance + segmentLength >= targetDistance then
			local alpha = segmentLength > 0 and (targetDistance - currentDistance) / segmentLength or 0
			samples[#samples + 1] = segmentStart:Lerp(nextPoint, alpha)
			targetDistance += spacing
		else
			currentDistance += segmentLength
			segmentStart = nextPoint
			segmentIndex += 1
		end
	end

	if not closed and (samples[#samples] - points[#points]).Magnitude > 0.1 then
		samples[#samples + 1] = points[#points]
	end

	return samples, totalLength
end

function RoadPathUtils.samplePath(anchors, spacing, options)
	local settings = options or {}
	local closed = settings.Closed == true
	local segmentSamples = settings.DenseSegmentSamples or 16
	local densePoints = densePath(anchors, closed, segmentSamples)
	return RoadPathUtils.resampleByArcLength(densePoints, spacing, closed)
end

function RoadPathUtils.sampleDescriptors(samplePositions, totalLength, closed)
	local descriptors = {}
	local count = #samplePositions

	for index, position in ipairs(samplePositions) do
		local previousIndex = index - 1
		local nextIndex = index + 1
		if previousIndex < 1 then
			previousIndex = closed and count or 1
		end
		if nextIndex > count then
			nextIndex = closed and 1 or count
		end

		local previous = samplePositions[previousIndex]
		local nextPosition = samplePositions[nextIndex]
		local tangent = WorldMath.horizontalUnit(nextPosition - previous, Vector3.new(0, 0, -1))
		local right = WorldMath.rightFromTangent(tangent, WorldConstants.WorldUp)
		local signedTurn = WorldMath.angleAroundY(position - previous, nextPosition - position)
		local averageDistance = ((position - previous).Magnitude + (nextPosition - position).Magnitude) * 0.5
		local curvature = averageDistance > 0 and signedTurn / averageDistance or 0

		descriptors[index] = {
			Position = position,
			Tangent = tangent,
			Right = right,
			Up = WorldConstants.WorldUp,
			Curvature = curvature,
			LapDistance = totalLength > 0 and ((index - 1) / math.max(1, count - (closed and 0 or 1))) * totalLength or 0,
		}
	end

	return descriptors
end

function RoadPathUtils.serializeSamples(samples)
	local serialized = {}

	for _, sample in ipairs(samples or {}) do
		serialized[#serialized + 1] = {
			Position = { sample.Position.X, sample.Position.Y, sample.Position.Z },
			Tangent = { sample.Tangent.X, sample.Tangent.Y, sample.Tangent.Z },
			Right = { sample.Right.X, sample.Right.Y, sample.Right.Z },
			Up = { sample.Up.X, sample.Up.Y, sample.Up.Z },
			Curvature = sample.Curvature,
			LapDistance = sample.LapDistance,
		}
	end

	return serialized
end

function RoadPathUtils.deserializeSamples(samples)
	local descriptors = {}

	for _, sample in ipairs(samples or {}) do
		descriptors[#descriptors + 1] = {
			Position = Vector3.new(sample.Position[1], sample.Position[2], sample.Position[3]),
			Tangent = Vector3.new(sample.Tangent[1], sample.Tangent[2], sample.Tangent[3]),
			Right = Vector3.new(sample.Right[1], sample.Right[2], sample.Right[3]),
			Up = Vector3.new(sample.Up[1], sample.Up[2], sample.Up[3]),
			Curvature = sample.Curvature,
			LapDistance = sample.LapDistance,
		}
	end

	return descriptors
end

local function normalizedOrFallback(vector, fallback)
	if vector.Magnitude <= SAMPLE_EPSILON then
		return fallback
	end

	return vector.Unit
end

local function cloneSample(sample, lapDistance)
	return {
		Position = sample.Position,
		Tangent = sample.Tangent,
		Right = sample.Right,
		Up = sample.Up,
		Curvature = sample.Curvature,
		LapDistance = lapDistance ~= nil and lapDistance or sample.LapDistance,
	}
end

local function interpolateSample(a, b, alpha, lapDistance)
	local tangent = normalizedOrFallback(a.Tangent:Lerp(b.Tangent, alpha), a.Tangent)
	local up = normalizedOrFallback(a.Up:Lerp(b.Up, alpha), a.Up)
	local right = normalizedOrFallback(a.Right:Lerp(b.Right, alpha), a.Right)

	return {
		Position = a.Position:Lerp(b.Position, alpha),
		Tangent = tangent,
		Right = right,
		Up = up,
		Curvature = WorldMath.lerp(a.Curvature or 0, b.Curvature or 0, alpha),
		LapDistance = lapDistance,
	}
end

local function appendUniqueSample(list, sample)
	local previous = list[#list]
	if previous and (previous.Position - sample.Position).Magnitude <= SAMPLE_EPSILON then
		list[#list] = sample
		return
	end

	list[#list + 1] = sample
end

function RoadPathUtils.partitionSamplesByLength(samples, closed, maxSectionLength)
	local count = #samples
	if count == 0 then
		return {}, 0
	end
	if count == 1 then
		return {
			{ cloneSample(samples[1], 0) },
		}, 0
	end

	local segmentCount = closed and count or (count - 1)
	local totalLength = 0
	for index = 1, segmentCount do
		local nextIndex = index + 1
		if nextIndex > count then
			nextIndex = 1
		end
		totalLength += (samples[nextIndex].Position - samples[index].Position).Magnitude
	end

	if totalLength <= SAMPLE_EPSILON or maxSectionLength <= 0 then
		local section = {}
		for _, sample in ipairs(samples) do
			section[#section + 1] = cloneSample(sample)
		end
		if closed then
			appendUniqueSample(section, cloneSample(samples[1], totalLength))
		end
		return { section }, totalLength
	end

	local sectionCount = math.max(1, math.ceil(totalLength / maxSectionLength))
	local targetSectionLength = totalLength / sectionCount
	local sections = {}
	local currentSection = { cloneSample(samples[1], 0) }
	local nextBoundaryDistance = targetSectionLength
	local boundaryIndex = 1
	local traversedLength = 0

	for index = 1, segmentCount do
		local nextIndex = index + 1
		if nextIndex > count then
			nextIndex = 1
		end

		local startSample = samples[index]
		local finishSample = samples[nextIndex]
		local segmentLength = (finishSample.Position - startSample.Position).Magnitude
		local segmentEndDistance = traversedLength + segmentLength

		while boundaryIndex < sectionCount and nextBoundaryDistance <= segmentEndDistance + SAMPLE_EPSILON do
			local alpha = segmentLength > SAMPLE_EPSILON and math.clamp((nextBoundaryDistance - traversedLength) / segmentLength, 0, 1) or 0
			local boundarySample = interpolateSample(startSample, finishSample, alpha, nextBoundaryDistance)
			appendUniqueSample(currentSection, boundarySample)
			sections[#sections + 1] = currentSection
			currentSection = { cloneSample(boundarySample, nextBoundaryDistance) }
			boundaryIndex += 1
			nextBoundaryDistance = targetSectionLength * boundaryIndex
		end

		local segmentEndSample = cloneSample(finishSample, segmentEndDistance)
		appendUniqueSample(currentSection, segmentEndSample)
		traversedLength = segmentEndDistance
	end

	if closed then
		appendUniqueSample(currentSection, cloneSample(samples[1], totalLength))
	end

	sections[#sections + 1] = currentSection
	return sections, totalLength
end

function RoadPathUtils.buildFittedDescriptors(points, sampleHeight, maxGradeDegrees, closed)
	local samplePositions, pathLength = RoadPathUtils.resampleByArcLength(points, WorldConstants.DefaultSampleSpacing, closed == true)
	local samples = RoadPathUtils.sampleDescriptors(samplePositions, pathLength, closed == true)
	RoadPathUtils.fitHeights(samples, sampleHeight, maxGradeDegrees, closed == true)
	return samples, pathLength
end

function RoadPathUtils.fitHeights(samples, sampleHeight, maxGradeDegrees, closed)
	local heights = {}

	for index, sample in ipairs(samples) do
		heights[index] = sampleHeight(sample.Position.X, sample.Position.Z)
	end

	for _ = 1, 4 do
		local smoothed = {}
		for index = 1, #heights do
			local previousIndex = index - 1
			local nextIndex = index + 1
			if previousIndex < 1 then
				previousIndex = closed and #heights or 1
			end
			if nextIndex > #heights then
				nextIndex = closed and 1 or #heights
			end

			smoothed[index] = (heights[previousIndex] + heights[index] * 2 + heights[nextIndex]) * 0.25
		end
		heights = smoothed
	end

	for _ = 1, 4 do
		for index = 2, #heights do
			local span = (samples[index].Position - samples[index - 1].Position).Magnitude
			local step = math.tan(math.rad(maxGradeDegrees)) * span
			heights[index] = WorldMath.clamp(heights[index], heights[index - 1] - step, heights[index - 1] + step)
		end
		for index = #heights - 1, 1, -1 do
			local span = (samples[index + 1].Position - samples[index].Position).Magnitude
			local step = math.tan(math.rad(maxGradeDegrees)) * span
			heights[index] = WorldMath.clamp(heights[index], heights[index + 1] - step, heights[index + 1] + step)
		end
	end

	for index, sample in ipairs(samples) do
		sample.Position = Vector3.new(sample.Position.X, heights[index], sample.Position.Z)
	end
end

return RoadPathUtils
