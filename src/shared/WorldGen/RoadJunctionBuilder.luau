local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))
local RoadSurfaceProfile = require(script.Parent:WaitForChild("RoadSurfaceProfile"))
local WorldMath = require(script.Parent:WaitForChild("WorldMath"))

local RoadJunctionBuilder = {}

local DIRECTION_DUPLICATE_DOT = 0.996

local function resolveSamples(road)
	if road._DecodedSamples then
		return road._DecodedSamples
	end

	local samples = road.Samples or {}
	if #samples > 0 and typeof(samples[1].Position) == "Vector3" then
		road._DecodedSamples = samples
		return samples
	end

	road._DecodedSamples = RoadPathUtils.deserializeSamples(samples)
	return road._DecodedSamples
end

local function nearestLoopSample(loop, position)
	if not loop or not loop.Samples or #loop.Samples == 0 then
		return nil
	end

	local bestSample = loop.Samples[1]
	local bestDistance = math.huge
	for _, sample in ipairs(loop.Samples) do
		local dx = sample.Position.X - position.X
		local dz = sample.Position.Z - position.Z
		local distance = dx * dx + dz * dz
		if distance < bestDistance then
			bestDistance = distance
			bestSample = sample
		end
	end

	return bestSample
end

local function ensureNode(nodeByIndex, nodeIndex, positionHint)
	local node = nodeByIndex[nodeIndex]
	if node then
		if positionHint then
			node.PositionHint = positionHint
		end
		return node
	end

	node = {
		NodeIndex = nodeIndex,
		Degree = 0,
		TouchesLoop = false,
		PositionHint = positionHint,
		Positions = {},
		Heights = {},
		Entries = {},
		SurfaceRaise = 0,
		HasLoopEntries = false,
	}
	nodeByIndex[nodeIndex] = node
	return node
end

local function registerEntry(node, samplePosition, direction, halfWidth, roadKind, profile)
	if not node or not samplePosition then
		return
	end

	local unitDirection = WorldMath.horizontalUnit(direction, Vector3.new(0, 0, -1))
	for _, entry in ipairs(node.Entries) do
		if entry.Direction:Dot(unitDirection) >= DIRECTION_DUPLICATE_DOT and math.abs(entry.HalfWidth - halfWidth) <= 0.1 then
			return
		end
	end

	node.Entries[#node.Entries + 1] = {
		Direction = unitDirection,
		HalfWidth = halfWidth,
		RoadKind = roadKind,
	}
	node.Positions[#node.Positions + 1] = samplePosition
	node.Heights[#node.Heights + 1] = samplePosition.Y
	node.SurfaceRaise = math.max(node.SurfaceRaise, RoadSurfaceProfile.surfaceRaise(profile, roadKind))
end

local function ensureLoopEntries(node, loop, samplePosition, profile)
	if node.HasLoopEntries then
		return
	end

	local loopSample = nearestLoopSample(loop, samplePosition)
	if not loopSample then
		return
	end

	registerEntry(node, loopSample.Position, loopSample.Tangent, profile.RoadWidth * 0.5, RoadSurfaceProfile.Kinds.Main, profile)
	registerEntry(node, loopSample.Position, -loopSample.Tangent, profile.RoadWidth * 0.5, RoadSurfaceProfile.Kinds.Main, profile)
	node.HasLoopEntries = true
end

local function finalizeJunction(node, profile)
	local count = math.max(1, #node.Positions)
	local total = Vector3.zero
	local totalHeight = 0
	local maxHalfWidth = profile.RoadWidth * 0.5
	for index, position in ipairs(node.Positions) do
		total += position
		totalHeight += node.Heights[index]
	end
	for _, entry in ipairs(node.Entries) do
		maxHalfWidth = math.max(maxHalfWidth, entry.HalfWidth or 0)
	end

	local average = total / count
	local averageHeight = totalHeight / count
	local degree = math.max(node.Degree, #node.Entries)
	local degreeBonus = math.max(0, degree - 3) * 2
	local widthBonus = math.max(0, maxHalfWidth - (profile.RoadWidth * 0.5))
	local terrainConfig = profile.TerrainConfig
	local coreRadius = math.max(
		terrainConfig.IntersectionCoreRadius + degreeBonus + (node.TouchesLoop and 4 or 0),
		maxHalfWidth + 6 + widthBonus * 0.5
	)
	local pavedRadius = math.max(coreRadius + 4, maxHalfWidth + 10)
	local shoulderRadius = math.max(
		pavedRadius + 6,
		terrainConfig.IntersectionShoulderRadius + degreeBonus + widthBonus
	)

	table.sort(node.Entries, function(left, right)
		return math.atan2(left.Direction.X, left.Direction.Z) < math.atan2(right.Direction.X, right.Direction.Z)
	end)

	local position = node.PositionHint or average
	return {
		NodeIndex = node.NodeIndex,
		Position = Vector3.new(position.X, averageHeight, position.Z),
		Height = averageHeight,
		Degree = degree,
		TouchesLoop = node.TouchesLoop,
		CoreRadius = coreRadius,
		PavedRadius = pavedRadius,
		ShoulderRadius = shoulderRadius,
		FlattenStrength = terrainConfig.IntersectionFlattenStrength,
		SurfaceRaise = node.SurfaceRaise,
		Entries = node.Entries,
	}
end

function RoadJunctionBuilder.build(loop, roads, profile)
	local nodeByIndex = {}

	for _, meta in ipairs(loop and loop.Topology and loop.Topology.Junctions or {}) do
		if meta.NodeIndex then
			local node = ensureNode(nodeByIndex, meta.NodeIndex, meta.Position)
			node.Degree = math.max(node.Degree, meta.Degree or 0)
			node.TouchesLoop = node.TouchesLoop or meta.TouchesLoop == true
			if meta.TouchesLoop then
				ensureLoopEntries(node, loop, meta.Position or Vector3.zero, profile)
			end
		end
	end

	for _, road in ipairs(roads or {}) do
		local samples = resolveSamples(road)
		if #samples >= 2 then
			local halfWidth = road.HalfWidth or (profile.RoadWidth * 0.5)
			local startMeta = road.Start or {}
			if startMeta.NodeIndex then
				local startNode = ensureNode(nodeByIndex, startMeta.NodeIndex, samples[1].Position)
				startNode.Degree = math.max(startNode.Degree, startMeta.Degree or 0)
				startNode.TouchesLoop = startNode.TouchesLoop or startMeta.TouchesLoop == true
				registerEntry(
					startNode,
					samples[1].Position,
					samples[2].Position - samples[1].Position,
					halfWidth,
					RoadSurfaceProfile.Kinds.Secondary,
					profile
				)
				if startMeta.TouchesLoop then
					ensureLoopEntries(startNode, loop, samples[1].Position, profile)
				end
			end

			local finishMeta = road.Finish or {}
			if finishMeta.NodeIndex then
				local finishNode = ensureNode(nodeByIndex, finishMeta.NodeIndex, samples[#samples].Position)
				finishNode.Degree = math.max(finishNode.Degree, finishMeta.Degree or 0)
				finishNode.TouchesLoop = finishNode.TouchesLoop or finishMeta.TouchesLoop == true
				registerEntry(
					finishNode,
					samples[#samples].Position,
					samples[#samples - 1].Position - samples[#samples].Position,
					halfWidth,
					RoadSurfaceProfile.Kinds.Secondary,
					profile
				)
				if finishMeta.TouchesLoop then
					ensureLoopEntries(finishNode, loop, samples[#samples].Position, profile)
				end
			end
		end
	end

	local junctions = {}
	for _, node in pairs(nodeByIndex) do
		if math.max(node.Degree, #node.Entries) >= 3 or node.TouchesLoop then
			junctions[#junctions + 1] = finalizeJunction(node, profile)
		end
	end

	table.sort(junctions, function(left, right)
		return tostring(left.NodeIndex) < tostring(right.NodeIndex)
	end)

	return junctions
end

return RoadJunctionBuilder
