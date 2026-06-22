local WorldMath = require(script.Parent:WaitForChild("WorldMath"))

local RoadSpatialIndex = {}

local function bucketKey(x, z)
	return ("%d:%d"):format(x, z)
end

function RoadSpatialIndex.build(loop, cellSize)
	local buckets = {}
	local sampleCount = #loop.Samples

	for index, sample in ipairs(loop.Samples) do
		local bucketX = math.floor(sample.Position.X / cellSize)
		local bucketZ = math.floor(sample.Position.Z / cellSize)
		local key = bucketKey(bucketX, bucketZ)
		local bucket = buckets[key]
		if not bucket then
			bucket = {}
			buckets[key] = bucket
		end
		bucket[#bucket + 1] = index
	end

	return {
		CellSize = cellSize,
		Buckets = buckets,
		SampleCount = sampleCount,
		Loop = loop,
	}
end

function RoadSpatialIndex.nearby(index, position, radius)
	local cellRadius = math.max(1, math.ceil(radius / index.CellSize))
	local centerX = math.floor(position.X / index.CellSize)
	local centerZ = math.floor(position.Z / index.CellSize)
	local indices = {}

	for dz = -cellRadius, cellRadius do
		for dx = -cellRadius, cellRadius do
			local bucket = index.Buckets[bucketKey(centerX + dx, centerZ + dz)]
			if bucket then
				for _, sampleIndex in ipairs(bucket) do
					indices[#indices + 1] = sampleIndex
				end
			end
		end
	end

	return indices
end

function RoadSpatialIndex.nearest(index, position, radius)
	local nearestDistance = math.huge
	local nearestSample = nil
	local nearestIndex = nil

	for _, sampleIndex in ipairs(RoadSpatialIndex.nearby(index, position, radius)) do
		local sample = index.Loop.Samples[sampleIndex]
		local distance = WorldMath.distanceXZ(position, sample.Position)
		if distance < nearestDistance then
			nearestDistance = distance
			nearestSample = sample
			nearestIndex = sampleIndex
		end
	end

	return nearestIndex, nearestSample, nearestDistance
end

return RoadSpatialIndex
