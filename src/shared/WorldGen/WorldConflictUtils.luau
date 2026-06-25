local RoadSpatialIndex = require(script.Parent:WaitForChild("RoadSpatialIndex"))
local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))
local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))
local WorldMath = require(script.Parent:WaitForChild("WorldMath"))

local WorldConflictUtils = {}

local function pointFromArray(values)
	return Vector3.new(values[1], values[2], values[3])
end

local function vectorsFromRotation(rotation)
	local forward = WorldMath.forwardFromRotation(rotation)
	local right = WorldMath.rightFromRotation(rotation)
	return right, forward
end

local function sampleIndexFromPolyline(points, cellSize)
	return RoadSpatialIndex.build({
		Samples = points,
	}, cellSize)
end

local function pointInRect(point, center, right, forward, size)
	local offset = point - center
	return math.abs(offset:Dot(right)) <= size.X * 0.5 and math.abs(offset:Dot(forward)) <= size.Y * 0.5
end

function WorldConflictUtils.rectanglePoints(center, rotation, size)
	local right, forward = vectorsFromRotation(rotation)
	local halfX = size.X * 0.5
	local halfZ = size.Y * 0.5

	return {
		center,
		center + right * halfX,
		center - right * halfX,
		center + forward * halfZ,
		center - forward * halfZ,
		center + right * halfX + forward * halfZ,
		center + right * halfX - forward * halfZ,
		center - right * halfX + forward * halfZ,
		center - right * halfX - forward * halfZ,
	}
end

function WorldConflictUtils.rectanglesOverlap(aCenter, aRotation, aSize, bCenter, bRotation, bSize)
	local aRight, aForward = vectorsFromRotation(aRotation)
	local bRight, bForward = vectorsFromRotation(bRotation)

	for _, point in ipairs(WorldConflictUtils.rectanglePoints(aCenter, aRotation, aSize)) do
		if pointInRect(point, bCenter, bRight, bForward, bSize) then
			return true
		end
	end

	for _, point in ipairs(WorldConflictUtils.rectanglePoints(bCenter, bRotation, bSize)) do
		if pointInRect(point, aCenter, aRight, aForward, aSize) then
			return true
		end
	end

	return false
end

function WorldConflictUtils.buildContext(options)
	local context = {
		Loop = options and options.Loop or nil,
		Profile = options and options.Profile or nil,
		LandformRuntime = options and options.LandformRuntime or nil,
		Parcels = options and options.Parcels or {},
		RoadIndex = nil,
		BranchIndices = {},
	}

	if context.Loop then
		local roadRadius = math.max(36, (context.Profile and context.Profile.RoadWidth or 22) + 24)
		context.RoadIndex = sampleIndexFromPolyline(context.Loop.Samples, roadRadius)
	end

	for _, branch in ipairs(options and options.Branches or {}) do
		local samples = RoadPathUtils.deserializeSamples(branch.Samples)
		local halfWidth = branch.HalfWidth or (context.Profile and context.Profile.RoadWidth or 22) * WorldConstants.BranchRoadWidthScale * 0.5
		context.BranchIndices[#context.BranchIndices + 1] = {
			Branch = branch,
			HalfWidth = halfWidth,
			Index = sampleIndexFromPolyline(samples, math.max(24, halfWidth + 18)),
		}
	end

	return context
end

function WorldConflictUtils.nearestRoadDistance(context, position)
	if not context or not context.RoadIndex then
		return math.huge
	end

	local _, _, distance = RoadSpatialIndex.nearest(context.RoadIndex, position, context.RoadIndex.CellSize * 3)
	return distance
end

function WorldConflictUtils.pointConflictsRoads(context, position, clearance)
	local roadDistance = WorldConflictUtils.nearestRoadDistance(context, position)
	if roadDistance <= clearance then
		return true, "MainRoad"
	end

	for _, branchInfo in ipairs(context and context.BranchIndices or {}) do
		local _, _, branchDistance = RoadSpatialIndex.nearest(branchInfo.Index, position, branchInfo.Index.CellSize * 3)
		if branchDistance <= clearance + branchInfo.HalfWidth then
			return true, "BranchRoad"
		end
	end

	return false, nil
end

function WorldConflictUtils.pointConflictsWater(context, position)
	local landformRuntime = context and context.LandformRuntime
	if not landformRuntime then
		return false, nil
	end

	local river = landformRuntime:sampleContext(position.X, position.Z).River
	if not river then
		return false, nil
	end
	if river.InWater then
		return true, "RiverWater"
	end
	if river.Distance <= river.ClearanceHalfWidth then
		return true, "RiverBank"
	end
	return false, nil
end

function WorldConflictUtils.segmentConflicts(context, startPoint, finishPoint, clearance, sampleStep)
	local span = (finishPoint - startPoint).Magnitude
	local step = sampleStep or 8
	local samples = math.max(1, math.ceil(span / step))

	for sampleIndex = 0, samples do
		local alpha = sampleIndex / samples
		local point = startPoint:Lerp(finishPoint, alpha)
		local roadConflict, roadReason = WorldConflictUtils.pointConflictsRoads(context, point, clearance)
		if roadConflict then
			return true, roadReason, point
		end

		local waterConflict, waterReason = WorldConflictUtils.pointConflictsWater(context, point)
		if waterConflict then
			return true, waterReason, point
		end
	end

	return false, nil, nil
end

function WorldConflictUtils.parcelConflictReason(context, center, rotation, reserveSize, acceptedParcels)
	for _, point in ipairs(WorldConflictUtils.rectanglePoints(center, rotation, reserveSize)) do
		local roadConflict, roadReason = WorldConflictUtils.pointConflictsRoads(context, point, reserveSize.X * 0.04 + (context.Profile and context.Profile.ShoulderWidth or 0))
		if roadConflict then
			return roadReason
		end

		local waterConflict, waterReason = WorldConflictUtils.pointConflictsWater(context, point)
		if waterConflict then
			return waterReason
		end
	end

	for _, parcel in ipairs(acceptedParcels or {}) do
		if WorldConflictUtils.rectanglesOverlap(
			center,
			rotation,
			reserveSize,
			parcel.Center,
			parcel.Rotation,
			parcel.ReserveSize
		) then
			return "ParcelOverlap"
		end
	end

	return nil
end

function WorldConflictUtils.accessConflictReason(context, startPoint, finishPoint, width)
	return WorldConflictUtils.segmentConflicts(context, startPoint, finishPoint, width * 0.5 + 2, 6)
end

return WorldConflictUtils
