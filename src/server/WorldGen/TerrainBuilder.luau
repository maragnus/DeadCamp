local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldGenShared = Shared:WaitForChild("WorldGen")

local RoadPathUtils = require(WorldGenShared:WaitForChild("RoadPathUtils"))
local RoadSpatialIndex = require(WorldGenShared:WaitForChild("RoadSpatialIndex"))
local WorldMath = require(WorldGenShared:WaitForChild("WorldMath"))

local TerrainBuilder = {}

local CHUNK_SIZE_STUDS = 128
local MIN_TERRAIN_Y = -48
local MAX_TERRAIN_Y = 128

local function pointFromArray(values)
	return Vector3.new(values[1], values[2], values[3])
end

local function terrainMaterialForDistance(distance, masks)
	if distance <= masks.RoadHalfWidth then
		return Enum.Material.Asphalt
	end
	if distance <= masks.ShoulderRadius then
		return Enum.Material.Ground
	end
	if distance <= masks.DiscourageRadius then
		return Enum.Material.Grass
	end
	return Enum.Material.Ground
end

local function baseHeightSampler(seed)
	local seedOffset = seed * 0.00073
	return function(x, z)
		local primary = math.noise(x * 0.0022, z * 0.0022, seedOffset) * 26
		local secondary = math.noise(x * 0.0049, z * 0.0049, seedOffset + 17.1) * 7
		local detail = math.noise(x * 0.0105, z * 0.0105, seedOffset + 39.7) * 2.2
		return 10 + primary + secondary + detail
	end
end

local function deserializeBranchSamples(branch)
	local samples = {}
	for _, sample in ipairs(branch.Samples or {}) do
		samples[#samples + 1] = {
			Position = pointFromArray(sample.Position),
			Tangent = pointFromArray(sample.Tangent),
			Right = pointFromArray(sample.Right),
			Up = pointFromArray(sample.Up),
			Curvature = sample.Curvature,
			LapDistance = sample.LapDistance,
		}
	end
	return samples
end

local function buildBranchSegments(branches)
	local branchSegments = {}

	for _, branch in ipairs(branches or {}) do
		local samples = deserializeBranchSamples(branch)
		local segments = {}
		for index = 1, #samples - 1 do
			segments[#segments + 1] = {
				Start = samples[index].Position,
				Finish = samples[index + 1].Position,
			}
		end

		branchSegments[#branchSegments + 1] = {
			Id = branch.Id,
			Type = branch.Type,
			Segments = segments,
		}
	end

	return branchSegments
end

local function closestOnSegmentXZ(x, z, a, b)
	local apx = x - a.X
	local apz = z - a.Z
	local abx = b.X - a.X
	local abz = b.Z - a.Z
	local abLengthSquared = abx * abx + abz * abz
	if abLengthSquared <= 1e-4 then
		return 0, math.sqrt(apx * apx + apz * apz)
	end

	local alpha = WorldMath.clamp((apx * abx + apz * abz) / abLengthSquared, 0, 1)
	local closestX = a.X + abx * alpha
	local closestZ = a.Z + abz * alpha
	local dx = x - closestX
	local dz = z - closestZ
	return alpha, math.sqrt(dx * dx + dz * dz)
end

local function branchRoadTarget(x, z, branchSegments, roadWidth)
	local nearest = nil
	local halfWidth = roadWidth * 0.5
	local shoulder = roadWidth * 0.88

	for _, branch in ipairs(branchSegments) do
		for _, segment in ipairs(branch.Segments) do
			local alpha, distance = closestOnSegmentXZ(x, z, segment.Start, segment.Finish)
			if not nearest or distance < nearest.Distance then
				local targetHeight = segment.Start.Y + (segment.Finish.Y - segment.Start.Y) * alpha
				nearest = {
					Distance = distance,
					Height = targetHeight,
					Type = branch.Type,
					HalfWidth = halfWidth,
					Shoulder = shoulder,
				}
			end
		end
	end

	return nearest
end

local function smoothBarrierContribution(distance, hotspot)
	if distance >= hotspot.Radius then
		return 0
	end

	local alpha = 1 - (distance / hotspot.Radius)
	local eased = alpha * alpha * (3 - 2 * alpha)
	return eased * hotspot.Amplitude * (hotspot.Mode == "Valley" and -1 or 1)
end

local function sampleFinalHeight(x, z, state, parcels, branchSegments)
	local baseHeight = state.SampleBaseHeight(x, z)
	local _, nearestSample, nearestDistance = RoadSpatialIndex.nearest(
		state.SpatialIndex,
		Vector3.new(x, 0, z),
		state.Masks.BarrierRadius + 18
	)
	local finalHeight = baseHeight
	local material = Enum.Material.Grass

	if nearestSample and nearestDistance <= state.Masks.BarrierRadius + 18 then
		local roadHeight = nearestSample.Position.Y
		if nearestDistance <= state.Masks.RoadHalfWidth then
			finalHeight = roadHeight - 0.35
		elseif nearestDistance <= state.Masks.ShoulderRadius then
			local alpha = WorldMath.smoothStep(state.Masks.RoadHalfWidth, state.Masks.ShoulderRadius, nearestDistance)
			finalHeight = WorldMath.lerp(roadHeight - 0.3, finalHeight, alpha)
		elseif nearestDistance <= state.Masks.RecoveryRadius then
			local alpha = WorldMath.smoothStep(state.Masks.ShoulderRadius, state.Masks.RecoveryRadius, nearestDistance)
			finalHeight = WorldMath.lerp(roadHeight - 0.05, finalHeight, alpha)
		elseif nearestDistance <= state.Masks.DiscourageRadius then
			local alpha = WorldMath.smoothStep(state.Masks.RecoveryRadius, state.Masks.DiscourageRadius, nearestDistance)
			finalHeight += alpha * (2.5 + math.noise(x * 0.0085, z * 0.0085, state.Seed * 0.0017) * 1.8)
		end

		material = terrainMaterialForDistance(nearestDistance, state.Masks)
	end

	local branchTarget = branchRoadTarget(x, z, branchSegments, state.Profile.RoadWidth)
	if branchTarget and branchTarget.Distance <= branchTarget.Shoulder then
		local branchAlpha = WorldMath.smoothStep(branchTarget.HalfWidth, branchTarget.Shoulder, branchTarget.Distance)
		finalHeight = WorldMath.lerp(branchTarget.Height - 0.2, finalHeight, branchAlpha)
		material = branchTarget.Distance <= branchTarget.HalfWidth and Enum.Material.Asphalt or Enum.Material.Ground
	end

	for _, parcel in ipairs(parcels or {}) do
		local center = pointFromArray(parcel.Center)
		local forward = Vector3.new(math.sin(parcel.Rotation), 0, math.cos(parcel.Rotation))
		local right = Vector3.new(forward.Z, 0, -forward.X)
		local offset = Vector3.new(x - center.X, 0, z - center.Z)
		local localX = math.abs(offset:Dot(right))
		local localZ = math.abs(offset:Dot(forward))
		local halfX = parcel.ReserveSize.X * 0.5
		local halfZ = parcel.ReserveSize.Y * 0.5
		local edgeDistance = math.max(localX - halfX, localZ - halfZ)

		if edgeDistance < 22 then
			local blend = edgeDistance <= 0 and 1 or (1 - (edgeDistance / 22))
			local targetHeight = parcel.Center[2]
			finalHeight = WorldMath.lerp(finalHeight, targetHeight, blend)
			material = Enum.Material.Ground
		end

		if parcel.AccessType == "DriveUp" then
			local entry = pointFromArray(parcel.EntryPoint)
			local alpha, apronDistance = closestOnSegmentXZ(x, z, entry, center)
			if apronDistance < state.Profile.RoadWidth * 0.4 then
				local apronBlend = 1 - (apronDistance / (state.Profile.RoadWidth * 0.4))
				local targetHeight = entry.Y + (center.Y - entry.Y) * alpha
				finalHeight = WorldMath.lerp(finalHeight, targetHeight, apronBlend * 0.8)
				material = Enum.Material.Ground
			end
		end
	end

	for _, hotspot in ipairs(state.Masks.ShortcutHotspots or {}) do
		local distance = WorldMath.distanceXZ(Vector3.new(x, 0, z), hotspot.Position)
		finalHeight += smoothBarrierContribution(distance, hotspot)
		if distance < hotspot.Radius * 0.65 then
			material = Enum.Material.Ground
		end
	end

	return finalHeight, material
end

local function applyChunk(terrain, minX, maxX, minZ, maxZ, state, parcels, branchSegments)
	local resolution = state.Profile.VoxelResolution
	local region = Region3.new(Vector3.new(minX, MIN_TERRAIN_Y, minZ), Vector3.new(maxX, MAX_TERRAIN_Y, maxZ)):ExpandToGrid(resolution)
	local materials, occupancies = terrain:ReadVoxels(region, resolution)
	local size = region.Size
	local xCount = math.floor(size.X / resolution)
	local yCount = math.floor(size.Y / resolution)
	local zCount = math.floor(size.Z / resolution)
	local regionMin = region.CFrame.Position - (size * 0.5)

	for xIndex = 1, xCount do
		local worldX = regionMin.X + (xIndex - 0.5) * resolution
		for zIndex = 1, zCount do
			local worldZ = regionMin.Z + (zIndex - 0.5) * resolution
			local topHeight, topMaterial = sampleFinalHeight(worldX, worldZ, state, parcels, branchSegments)

			for yIndex = 1, yCount do
				local worldY = regionMin.Y + (yIndex - 0.5) * resolution
				local occupancy = WorldMath.clamp(0.5 + ((topHeight - worldY) / resolution), 0, 1)
				if occupancy > 0 then
					materials[xIndex][yIndex][zIndex] = topMaterial
					occupancies[xIndex][yIndex][zIndex] = occupancy
				else
					materials[xIndex][yIndex][zIndex] = Enum.Material.Air
					occupancies[xIndex][yIndex][zIndex] = 0
				end
			end
		end
	end

	terrain:WriteVoxels(region, resolution, materials, occupancies)
end

function TerrainBuilder.createContext(loop, profile, seed, masks)
	local sampleBaseHeight = baseHeightSampler(seed)
	RoadPathUtils.fitHeights(loop.Samples, sampleBaseHeight, profile.MaxRoadGradeDegrees, true)

	local state = {
		Loop = loop,
		Profile = profile,
		Seed = seed,
		Masks = masks,
		SampleBaseHeight = sampleBaseHeight,
		SpatialIndex = RoadSpatialIndex.build(loop, math.max(48, masks.BarrierRadius * 0.7)),
	}

	function state:sampleBaseHeight(x, z)
		return self.SampleBaseHeight(x, z)
	end

	function state:startCFrame()
		local startSample = self.Loop.Samples[1]
		return CFrame.lookAt(startSample.Position, startSample.Position + startSample.Tangent, Vector3.yAxis)
	end

	function state:apply(parcels, branches)
		local terrain = Workspace.Terrain
		local halfSize = self.Profile.MapSizeStuds * 0.5
		local branchSegments = buildBranchSegments(branches)
		local minX = -halfSize

		while minX < halfSize do
			local maxX = math.min(halfSize, minX + CHUNK_SIZE_STUDS)
			local minZ = -halfSize
			while minZ < halfSize do
				local maxZ = math.min(halfSize, minZ + CHUNK_SIZE_STUDS)
				applyChunk(
					terrain,
					minX,
					maxX,
					minZ,
					maxZ,
					self,
					parcels,
					branchSegments
				)
				minZ += CHUNK_SIZE_STUDS
			end
			minX += CHUNK_SIZE_STUDS
		end
	end

	return state
end

return TerrainBuilder
