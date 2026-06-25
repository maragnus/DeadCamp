local RoadLoopSettings = require(script.Parent:WaitForChild("RoadLoopSettings"))
local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))
local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))
local WorldMath = require(script.Parent:WaitForChild("WorldMath"))
local WorldSeed = require(script.Parent:WaitForChild("WorldSeed"))

local RoadLoopGraphPlanner = {}

local function edgeKey(a, b)
	if a < b then
		return ("%d_%d"):format(a, b)
	end
	return ("%d_%d"):format(b, a)
end

local function pointDistanceSquared(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return dx * dx + dz * dz
end

local function pathLength(points)
	local total = 0
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
	end
	return total
end

local function boundsForFace(nodes, face)
	local minX = math.huge
	local minZ = math.huge
	local maxX = -math.huge
	local maxZ = -math.huge

	for _, nodeIndex in ipairs(face) do
		local point = nodes[nodeIndex]
		minX = math.min(minX, point.X)
		minZ = math.min(minZ, point.Z)
		maxX = math.max(maxX, point.X)
		maxZ = math.max(maxZ, point.Z)
	end

	return {
		MinX = minX,
		MinZ = minZ,
		MaxX = maxX,
		MaxZ = maxZ,
	}
end

local function boundsArea(bounds)
	return math.max(0, bounds.MaxX - bounds.MinX) * math.max(0, bounds.MaxZ - bounds.MinZ)
end

local function combinedBounds(a, b)
	return {
		MinX = math.min(a.MinX, b.MinX),
		MinZ = math.min(a.MinZ, b.MinZ),
		MaxX = math.max(a.MaxX, b.MaxX),
		MaxZ = math.max(a.MaxZ, b.MaxZ),
	}
end

local function faceCentroid(nodes, face)
	local total = Vector3.zero
	for _, nodeIndex in ipairs(face) do
		total += nodes[nodeIndex]
	end
	return total / math.max(1, #face)
end

local function signedArea(nodes, indices)
	local total = 0
	for index = 1, #indices do
		local current = nodes[indices[index]]
		local following = nodes[indices[(index % #indices) + 1]]
		total += current.X * following.Z - following.X * current.Z
	end
	return total * 0.5
end

local function buildFrames(points)
	local frames = {}
	for index, point in ipairs(points) do
		local previous = points[WorldMath.wrapIndex(index - 1, #points)]
		local following = points[WorldMath.wrapIndex(index + 1, #points)]
		frames[index] = {
			Position = point,
			Tangent = WorldMath.horizontalUnit(following - previous, Vector3.new(0, 0, -1)),
			Heading = math.atan2((following - previous).X, (following - previous).Z),
			SectorIndex = index,
		}
	end
	return frames
end

local function generateNodes(profile, settings, rng)
	local safeHalf = profile.MapSizeStuds * 0.5 - profile.EdgeMarginStuds
	local graphSettings = settings.Graph
	local nodeCount = rng:NextInteger(graphSettings.NodeCountMin, graphSettings.NodeCountMax)
	local cols = math.max(3, math.floor(math.sqrt(nodeCount) + 0.5))
	local rows = math.max(3, math.ceil(nodeCount / cols))
	local paddedHalf = safeHalf * 0.92
	local width = paddedHalf * 2
	local cellWidth = width / cols
	local cellDepth = width / rows
	local nodes = {}

	for row = 1, rows do
		for col = 1, cols do
			if #nodes >= nodeCount then
				break
			end

			local jitterX = (rng:NextNumber() - 0.5) * cellWidth * graphSettings.NodeJitter
			local jitterZ = (rng:NextNumber() - 0.5) * cellDepth * graphSettings.NodeJitter
			nodes[#nodes + 1] = Vector3.new(
				-paddedHalf + (col - 0.5) * cellWidth + jitterX,
				0,
				-paddedHalf + (row - 0.5) * cellDepth + jitterZ
			)
		end
	end

	return nodes
end

local function gabrielEdges(nodes)
	local edges = {}

	for index = 1, #nodes do
		for otherIndex = index + 1, #nodes do
			local center = (nodes[index] + nodes[otherIndex]) * 0.5
			local radiusSquared = pointDistanceSquared(nodes[index], nodes[otherIndex]) * 0.25
			local clear = true

			for testIndex = 1, #nodes do
				if testIndex ~= index and testIndex ~= otherIndex then
					local point = nodes[testIndex]
					local dx = point.X - center.X
					local dz = point.Z - center.Z
					if (dx * dx + dz * dz) < (radiusSquared - 1e-3) then
						clear = false
						break
					end
				end
			end

			if clear then
				edges[#edges + 1] = { index, otherIndex }
			end
		end
	end

	return edges
end

local function planarFaces(nodes, edges)
	local adjacency = {}
	for nodeIndex = 1, #nodes do
		adjacency[nodeIndex] = {}
	end

	for _, edge in ipairs(edges) do
		local a = edge[1]
		local b = edge[2]
		adjacency[a][#adjacency[a] + 1] = b
		adjacency[b][#adjacency[b] + 1] = a
	end

	local positionLookup = {}
	for nodeIndex = 1, #nodes do
		table.sort(adjacency[nodeIndex], function(left, right)
			local point = nodes[nodeIndex]
			local leftPoint = nodes[left]
			local rightPoint = nodes[right]
			return math.atan2(leftPoint.Z - point.Z, leftPoint.X - point.X) < math.atan2(rightPoint.Z - point.Z, rightPoint.X - point.X)
		end)

		positionLookup[nodeIndex] = {}
		for listIndex, neighborIndex in ipairs(adjacency[nodeIndex]) do
			positionLookup[nodeIndex][neighborIndex] = listIndex
		end
	end

	local function nextHalfEdge(a, b)
		local list = adjacency[b]
		local fromIndex = positionLookup[b][a]
		local previousIndex = fromIndex - 1
		if previousIndex < 1 then
			previousIndex = #list
		end
		return b, list[previousIndex]
	end

	local used = {}
	local faces = {}

	for _, edge in ipairs(edges) do
		for _, halfEdge in ipairs({ { edge[1], edge[2] }, { edge[2], edge[1] } }) do
			local startA = halfEdge[1]
			local startB = halfEdge[2]
			local key = ("%d>%d"):format(startA, startB)
			if not used[key] then
				local face = {}
				local currentA = startA
				local currentB = startB
				local guard = 0

				while not used[("%d>%d"):format(currentA, currentB)] do
					used[("%d>%d"):format(currentA, currentB)] = true
					face[#face + 1] = currentA
					currentA, currentB = nextHalfEdge(currentA, currentB)
					guard += 1
					if guard > (#edges * 4) then
						break
					end
				end

				faces[#faces + 1] = face
			end
		end
	end

	local outerFaceIndex = 1
	local largestArea = 0
	for faceIndex, face in ipairs(faces) do
		local area = math.abs(signedArea(nodes, face))
		if area > largestArea then
			largestArea = area
			outerFaceIndex = faceIndex
		end
	end

	return adjacency, faces, outerFaceIndex
end

local function buildFaceData(nodes, faces)
	local edgeFaces = {}
	local faceAdjacency = {}
	local faceBounds = {}
	local faceCenters = {}

	for faceIndex, face in ipairs(faces) do
		faceAdjacency[faceIndex] = {}
		faceBounds[faceIndex] = boundsForFace(nodes, face)
		faceCenters[faceIndex] = faceCentroid(nodes, face)
		for pointIndex = 1, #face do
			local a = face[pointIndex]
			local b = face[(pointIndex % #face) + 1]
			local key = edgeKey(a, b)
			edgeFaces[key] = edgeFaces[key] or {}
			edgeFaces[key][#edgeFaces[key] + 1] = faceIndex
		end
	end

	for _, connectedFaces in pairs(edgeFaces) do
		if #connectedFaces == 2 then
			local first = connectedFaces[1]
			local second = connectedFaces[2]
			faceAdjacency[first][#faceAdjacency[first] + 1] = second
			faceAdjacency[second][#faceAdjacency[second] + 1] = first
		end
	end

	return {
		EdgeFaces = edgeFaces,
		FaceAdjacency = faceAdjacency,
		FaceBounds = faceBounds,
		FaceCenters = faceCenters,
	}
end

local function blobCount(inBlob)
	local count = 0
	for _, inCourseBlob in pairs(inBlob) do
		if inCourseBlob then
			count += 1
		end
	end
	return count
end

local function connectedOutside(faceData, outerFaceIndex, inBlob, addFaceIndex, faceCount)
	local seen = { [outerFaceIndex] = true }
	local stack = { outerFaceIndex }
	local count = 1
	local blockedFaces = blobCount(inBlob) + (addFaceIndex and not inBlob[addFaceIndex] and 1 or 0)
	local target = faceCount - blockedFaces

	while #stack > 0 do
		local current = table.remove(stack)
		for _, nextFace in ipairs(faceData.FaceAdjacency[current] or {}) do
			if nextFace ~= addFaceIndex and not inBlob[nextFace] and not seen[nextFace] then
				seen[nextFace] = true
				count += 1
				stack[#stack + 1] = nextFace
			end
		end
	end

	return count == target
end

local function growBlob(nodes, faces, outerFaceIndex, faceData, settings, rng)
	local innerFaces = {}
	for faceIndex = 1, #faces do
		if faceIndex ~= outerFaceIndex then
			innerFaces[#innerFaces + 1] = faceIndex
		end
	end

	if #innerFaces == 0 then
		return nil, "NoInnerFaces"
	end

	local center = Vector3.zero
	table.sort(innerFaces, function(left, right)
		return pointDistanceSquared(faceData.FaceCenters[left], center) < pointDistanceSquared(faceData.FaceCenters[right], center)
	end)

	local seedFace = innerFaces[rng:NextInteger(1, math.min(3, #innerFaces))]
	local inBlob = { [seedFace] = true }
	local blobFaces = { seedFace }
	local graphSettings = settings.Graph
	local targetFraction = rng:NextNumber(graphSettings.TargetFaceFractionMin, graphSettings.TargetFaceFractionMax)
	local targetCount = math.max(3, math.min(#innerFaces, math.floor(#innerFaces * targetFraction + 0.5)))
	local currentBounds = faceData.FaceBounds[seedFace]
	local mapArea = boundsArea(faceData.FaceBounds[outerFaceIndex])

	while #blobFaces < targetCount do
		local candidates = {}
		local seen = {}
		for _, faceIndex in ipairs(blobFaces) do
			for _, adjacentFace in ipairs(faceData.FaceAdjacency[faceIndex] or {}) do
				if adjacentFace ~= outerFaceIndex and not inBlob[adjacentFace] and not seen[adjacentFace] then
					seen[adjacentFace] = true
					candidates[#candidates + 1] = adjacentFace
				end
			end
		end

		if #candidates == 0 then
			break
		end

		local bestFace = nil
		local bestScore = -math.huge

		for _, candidateFace in ipairs(candidates) do
			if connectedOutside(faceData, outerFaceIndex, inBlob, candidateFace, #faces) then
				local sharedEdges = 0
				for _, adjacentFace in ipairs(faceData.FaceAdjacency[candidateFace] or {}) do
					if inBlob[adjacentFace] then
						sharedEdges += 1
					end
				end

				local perimeterGain = #faces[candidateFace] - (sharedEdges * 2)
				local expandedBounds = combinedBounds(currentBounds, faceData.FaceBounds[candidateFace])
				local spreadGain = (boundsArea(expandedBounds) - boundsArea(currentBounds)) / math.max(1, mapArea)
				local score = graphSettings.PerimeterWeight * perimeterGain
					+ graphSettings.SpreadWeight * spreadGain * 40
					+ graphSettings.RandomWeight * rng:NextNumber()

				if score > bestScore then
					bestScore = score
					bestFace = candidateFace
				end
			end
		end

		if not bestFace then
			break
		end

		inBlob[bestFace] = true
		blobFaces[#blobFaces + 1] = bestFace
		currentBounds = combinedBounds(currentBounds, faceData.FaceBounds[bestFace])
	end

	return inBlob
end

local function boundaryCycle(nodes, faceData, inBlob, settings)
	local boundaryEdges = {}
	local neighborMap = {}

	for key, connectedFaces in pairs(faceData.EdgeFaces) do
		local blobHits = 0
		for _, faceIndex in ipairs(connectedFaces) do
			if inBlob[faceIndex] then
				blobHits += 1
			end
		end

		if blobHits == 1 then
			local parts = string.split(key, "_")
			local a = tonumber(parts[1])
			local b = tonumber(parts[2])
			boundaryEdges[#boundaryEdges + 1] = { a, b }
			neighborMap[a] = neighborMap[a] or {}
			neighborMap[b] = neighborMap[b] or {}
			neighborMap[a][#neighborMap[a] + 1] = b
			neighborMap[b][#neighborMap[b] + 1] = a
		end
	end

	if #boundaryEdges == 0 then
		return nil, "NoBoundaryEdges"
	end

	local usedEdges = {}
	local bestCycle = nil

	for _, edge in ipairs(boundaryEdges) do
		local startA = edge[1]
		local startB = edge[2]
		local startKey = edgeKey(startA, startB)
		if not usedEdges[startKey] then
			local cycle = { startA }
			local previous = startA
			local current = startB
			local ok = true
			local guard = 0

			usedEdges[startKey] = true

			while current ~= startA do
				cycle[#cycle + 1] = current
				local nextNode = nil
				for _, candidate in ipairs(neighborMap[current] or {}) do
					local candidateKey = edgeKey(current, candidate)
					if candidate ~= previous and not usedEdges[candidateKey] then
						nextNode = candidate
						usedEdges[candidateKey] = true
						break
					end
				end

				if not nextNode then
					ok = false
					break
				end

				previous = current
				current = nextNode
				guard += 1
				if guard > (#boundaryEdges + 5) then
					ok = false
					break
				end
			end

			if ok and #cycle >= settings.Graph.MinCycleNodes and (not bestCycle or #cycle > #bestCycle) then
				bestCycle = cycle
			end
		end
	end

	if not bestCycle then
		return nil, "NoBoundaryCycle"
	end

	if signedArea(nodes, bestCycle) < 0 then
		local reversed = {}
		for index = #bestCycle, 1, -1 do
			reversed[#reversed + 1] = bestCycle[index]
		end
		bestCycle = reversed
	end

	return bestCycle
end

local function reversePoints(points)
	local reversed = {}
	for index = #points, 1, -1 do
		reversed[#reversed + 1] = points[index]
	end
	return reversed
end

local function appendPath(target, addition)
	for index, point in ipairs(addition) do
		if index > 1 or #target == 0 then
			target[#target + 1] = point
		end
	end
end

local function pathSelfIntersects(points)
	local count = #points
	if count < 4 then
		return false
	end

	for aIndex = 1, count do
		local a0 = points[aIndex]
		local a1 = points[(aIndex % count) + 1]

		for bIndex = aIndex + 2, count do
			if not (aIndex == 1 and bIndex == count) then
				local b0 = points[bIndex]
				local b1 = points[(bIndex % count) + 1]
				if WorldMath.segmentIntersectionXZ(a0, a1, b0, b1) then
					return true
				end
			end
		end
	end

	return false
end

local function canonicalEdgePath(nodes, a, b, settings, seedInput, bendScale)
	local low = math.min(a, b)
	local high = math.max(a, b)
	local startPoint = nodes[low]
	local finishPoint = nodes[high]
	local delta = finishPoint - startPoint
	local length = delta.Magnitude
	if length <= 1e-3 then
		return { startPoint }, "Flat"
	end

	local rng = WorldSeed.random(seedInput, ("RoadEdge_%d_%d"):format(low, high))
	local graphSettings = settings.Graph
	local direction = delta.Unit
	local normal = Vector3.new(-direction.Z, 0, direction.X)
	local sign = rng:NextNumber() < 0.5 and -1 or 1
	local isLong = length > settings.MapSizeStuds * 0.12
	local detour = isLong and rng:NextNumber() < graphSettings.EdgeDetourRate
	local curveType = "Bulge"
	local amplitude = 0

	if detour then
		curveType = rng:NextNumber() < 0.45 and "Meander" or "Bulge"
		local scale = curveType == "Meander" and rng:NextNumber(0.55, 0.95) or rng:NextNumber(0.85, 1.45)
		amplitude = graphSettings.EdgeBendFraction * length * scale * sign * bendScale
	else
		amplitude = graphSettings.EdgeBendFraction * length * 0.5 * sign * bendScale * rng:NextNumber(0.5, 1.1)
	end

	local steps = detour and math.max(14, graphSettings.EdgeDensitySamples) or math.max(4, math.floor(graphSettings.EdgeDensitySamples * 0.6 + 0.5))
	local points = {}

	for step = 0, steps do
		local alpha = step / steps
		local displacement = curveType == "Meander" and math.sin(math.pi * 2 * alpha) or math.sin(math.pi * alpha)
		points[#points + 1] = startPoint:Lerp(finishPoint, alpha) + normal * amplitude * displacement
	end

	return points, curveType
end

local function makeEdgePathResolver(nodes, settings, seedInput, bendScale)
	local cache = {}

	local function resolve(a, b)
		local key = edgeKey(a, b)
		local cached = cache[key]
		if not cached then
			local points, curveType = canonicalEdgePath(nodes, a, b, settings, seedInput, bendScale)
			cached = {
				Low = math.min(a, b),
				High = math.max(a, b),
				Points = points,
				CurveType = curveType,
			}
			cache[key] = cached
		end

		if a == cached.Low and b == cached.High then
			return cached.Points, cached.CurveType
		end

		return reversePoints(cached.Points), cached.CurveType
	end

	return resolve
end

local function buildCoursePath(cycle, resolveEdgePath)
	local coursePath = {}
	local loopEdges = {}

	for index = 1, #cycle do
		local a = cycle[index]
		local b = cycle[(index % #cycle) + 1]
		local points = resolveEdgePath(a, b)
		loopEdges[edgeKey(a, b)] = true
		appendPath(coursePath, points)
	end

	return coursePath, loopEdges
end

local function buildTopology(nodes, edges, adjacency, mainCycle, resolveEdgePath)
	local loopNodes = {}
	local loopEdges = {}
	for index = 1, #mainCycle do
		local a = mainCycle[index]
		local b = mainCycle[(index % #mainCycle) + 1]
		loopNodes[a] = true
		loopEdges[edgeKey(a, b)] = true
	end

	local offLoopDegree = {}
	for nodeIndex = 1, #nodes do
		offLoopDegree[nodeIndex] = 0
	end

	for _, edge in ipairs(edges) do
		if not loopEdges[edgeKey(edge[1], edge[2])] then
			offLoopDegree[edge[1]] += 1
			offLoopDegree[edge[2]] += 1
		end
	end

	local junctions = {}
	for nodeIndex = 1, #nodes do
		if #(adjacency[nodeIndex] or {}) >= 3 then
			junctions[#junctions + 1] = {
				NodeIndex = nodeIndex,
				Position = nodes[nodeIndex],
				Degree = #(adjacency[nodeIndex] or {}),
				TouchesLoop = loopNodes[nodeIndex] == true,
			}
		end
	end

	local networkRoads = {}
	local branchCandidates = {}
	for _, edge in ipairs(edges) do
		local a = edge[1]
		local b = edge[2]
		local key = edgeKey(a, b)
		if not loopEdges[key] then
			local points, curveType = resolveEdgePath(a, b)
			local road = {
				Id = ("Network_%s"):format(key),
				EdgeKey = key,
				NodeIndices = { a, b },
				Points = points,
				Length = pathLength(points),
				CurveType = curveType,
				TouchesLoop = loopNodes[a] == true or loopNodes[b] == true,
				RejoinsLoop = loopNodes[a] == true and loopNodes[b] == true,
				EndsAtLeaf = (not loopNodes[a] and offLoopDegree[a] <= 1) or (not loopNodes[b] and offLoopDegree[b] <= 1),
				Start = {
					NodeIndex = a,
					Position = nodes[a],
					Degree = #(adjacency[a] or {}),
					OffLoopDegree = offLoopDegree[a],
					TouchesLoop = loopNodes[a] == true,
				},
				Finish = {
					NodeIndex = b,
					Position = nodes[b],
					Degree = #(adjacency[b] or {}),
					OffLoopDegree = offLoopDegree[b],
					TouchesLoop = loopNodes[b] == true,
				},
			}
			networkRoads[#networkRoads + 1] = road
			branchCandidates[#branchCandidates + 1] = {
				Id = road.Id,
				NodeIndices = road.NodeIndices,
				Points = road.Points,
				Length = road.Length,
				RejoinsLoop = road.RejoinsLoop,
				EndsAtLeaf = road.EndsAtLeaf,
				TouchesLoop = road.TouchesLoop,
			}
		end
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

	return {
		Junctions = junctions,
		NetworkRoads = networkRoads,
		BranchCandidates = branchCandidates,
		MainLoopNodes = mainCycle,
	}
end

function RoadLoopGraphPlanner.generate(profile, seedInput)
	local settings = RoadLoopSettings.resolve(profile)
	settings.MapSizeStuds = profile.MapSizeStuds
	local lastFailure = nil

	for generationAttempt = 1, settings.Graph.GenerationAttempts do
		local scopedSeed = WorldSeed.combine(seedInput, ("GraphAttempt_%d"):format(generationAttempt))
		local graphRng = WorldSeed.random(scopedSeed, "RoadLoopGraphPlanner")
		local blobRng = WorldSeed.random(scopedSeed, "RoadLoopGraphPlannerBlob")
		local nodes = generateNodes(profile, settings, graphRng)
		local edges = gabrielEdges(nodes)
		if #edges >= 6 then
			local adjacency, faces, outerFaceIndex = planarFaces(nodes, edges)
			local faceData = buildFaceData(nodes, faces)
			local inBlob, blobFailure = growBlob(nodes, faces, outerFaceIndex, faceData, settings, blobRng)
			if inBlob then
				local cycle, cycleFailure = boundaryCycle(nodes, faceData, inBlob, settings)
				if cycle then
					local anchors = {}
					for _, nodeIndex in ipairs(cycle) do
						anchors[#anchors + 1] = nodes[nodeIndex]
					end

					local samplePositions = nil
					local loopLength = 0
					local resolvedScale = 1

					for curveAttempt = 1, settings.Graph.CurveAttemptCount do
						local edgeResolver = makeEdgePathResolver(nodes, settings, scopedSeed, resolvedScale)
						local coursePath = buildCoursePath(cycle, edgeResolver)
						if not pathSelfIntersects(coursePath) or resolvedScale <= settings.Graph.CurveMinimumScale then
							samplePositions, loopLength = RoadPathUtils.resampleByArcLength(coursePath, WorldConstants.DefaultSampleSpacing, true)
							if #samplePositions >= 12 then
								local topology = buildTopology(nodes, edges, adjacency, cycle, edgeResolver)
								local nodePlan = {}
								for anchorIndex, point in ipairs(anchors) do
									nodePlan[anchorIndex] = {
										NodeIndex = cycle[anchorIndex],
										Position = point,
									}
								end

								return {
									StrategyName = ("HtmlNetwork_%02d"):format(#anchors),
									Anchors = anchors,
									Frames = buildFrames(anchors),
									SectorPlan = nodePlan,
									PathPositions = samplePositions,
									PathLength = loopLength,
									Topology = topology,
								}
							end

							lastFailure = {
								Reason = "InsufficientFrames",
								MinimumRadius = 0,
							}
							break
						end

						resolvedScale *= settings.Graph.CurveBackoffFactor
					end

					if not samplePositions then
						lastFailure = {
							Reason = "CurvedCourseSelfIntersection",
							MinimumRadius = 0,
						}
					end
				else
					lastFailure = {
						Reason = cycleFailure or "BoundaryCycleFailed",
						MinimumRadius = 0,
					}
				end
			else
				lastFailure = {
					Reason = blobFailure or "BlobGrowthFailed",
					MinimumRadius = 0,
				}
			end
		else
			lastFailure = {
				Reason = "InsufficientGraphEdges",
				MinimumRadius = 0,
			}
		end
	end

	return nil, lastFailure or {
		Reason = "GraphPlannerExhausted",
		MinimumRadius = 0,
	}
end

return RoadLoopGraphPlanner
