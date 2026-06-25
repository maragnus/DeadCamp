local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldGenShared = Shared:WaitForChild("WorldGen")

local LandformPlanner = require(WorldGenShared:WaitForChild("LandformPlanner"))
local RoadSpatialIndex = require(WorldGenShared:WaitForChild("RoadSpatialIndex"))
local WorldMath = require(WorldGenShared:WaitForChild("WorldMath"))

local TerrainBuilder = {}

local CHUNK_SIZE_STUDS = 128
local MIN_TERRAIN_Y = -64
local MAX_TERRAIN_Y = 144

local function pointFromArray(values)
	return Vector3.new(values[1], values[2], values[3])
end

local function terrainMaterialForContext(landContext)
	if landContext.River and landContext.River.InBank then
		return Enum.Material.Mud
	end
	if landContext.River and landContext.River.InFloodplain then
		return Enum.Material.Ground
	end
	if landContext.RidgeBlend > 0.42 then
		return Enum.Material.Slate
	end
	if landContext.DetailNoise < -0.18 then
		return Enum.Material.Ground
	end
	return Enum.Material.Grass
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
				StartDistance = samples[index].LapDistance or 0,
				FinishDistance = samples[index + 1].LapDistance or 0,
			}
		end

		branchSegments[#branchSegments + 1] = {
			Id = branch.Id,
			Type = branch.Type,
			HalfWidth = branch.HalfWidth or 8,
			EntranceTaperLength = branch.EntranceTaperLength or 0,
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

local function branchRoadTarget(x, z, branchSegments, roadWidth, shoulderWidth)
	local nearest = nil

	for _, branch in ipairs(branchSegments) do
		for _, segment in ipairs(branch.Segments) do
			local alpha, distance = closestOnSegmentXZ(x, z, segment.Start, segment.Finish)
			if not nearest or distance < nearest.Distance then
				local pathDistance = segment.StartDistance + (segment.FinishDistance - segment.StartDistance) * alpha
				local taperAlpha = branch.EntranceTaperLength > 0
					and WorldMath.smoothStep(0, branch.EntranceTaperLength, pathDistance)
					or 1
				local halfWidth = WorldMath.lerp(2, branch.HalfWidth, taperAlpha)
				nearest = {
					Distance = distance,
					Height = segment.Start.Y + (segment.Finish.Y - segment.Start.Y) * alpha,
					Type = branch.Type,
					HalfWidth = halfWidth,
					Shoulder = halfWidth + shoulderWidth * 0.55,
				}
			end
		end
	end

	return nearest
end

local function sampleRoadSurface(x, z, state, baseHeight, landContext)
	if not state.SpatialIndex then
		return baseHeight, terrainMaterialForContext(landContext), math.huge
	end

	local _, nearestSample, nearestDistance = RoadSpatialIndex.nearest(
		state.SpatialIndex,
		Vector3.new(x, 0, z),
		state.Masks.TerrainInfluenceRadius
	)
	local finalHeight = baseHeight
	local material = terrainMaterialForContext(landContext)

	if nearestSample and nearestDistance <= state.Masks.TerrainInfluenceRadius then
		local roadHeight = nearestSample.Position.Y
		local signedDistance = Vector3.new(x - nearestSample.Position.X, 0, z - nearestSample.Position.Z):Dot(nearestSample.Right)
		local sideSign = signedDistance >= 0 and 1 or -1
		local probeDistance = state.Masks.ShoulderRadius + 8
		local outerX = x + nearestSample.Right.X * sideSign * probeDistance
		local outerZ = z + nearestSample.Right.Z * sideSign * probeDistance
		local outerHeight = state.LandformRuntime:sampleHeight(outerX, outerZ)
		local uphill = outerHeight > roadHeight

		if nearestDistance <= state.Masks.RoadHalfWidth then
			finalHeight = roadHeight - 0.25
			material = Enum.Material.Asphalt
		elseif nearestDistance <= state.Masks.ShoulderRadius then
			local alpha = WorldMath.smoothStep(state.Masks.RoadHalfWidth, state.Masks.ShoulderRadius, nearestDistance)
			local shoulderTarget = uphill
				and math.min(baseHeight, roadHeight + state.Profile.LandformConfig.RoadsideCutDepth * 0.3)
				or baseHeight - state.Profile.LandformConfig.RoadsideFillDepth * 0.08
			finalHeight = WorldMath.lerp(roadHeight - 0.16, shoulderTarget, alpha)
			material = Enum.Material.Ground
		elseif nearestDistance <= state.Masks.RecoveryRadius then
			local alpha = WorldMath.smoothStep(state.Masks.ShoulderRadius, state.Masks.RecoveryRadius, nearestDistance)
			local edgeNoise = landContext.DetailNoise * (uphill and 0.8 or 1.2)
			finalHeight = WorldMath.lerp(roadHeight - 0.05, baseHeight + edgeNoise, alpha)
		elseif nearestDistance <= state.Masks.RoughRadius then
			local alpha = WorldMath.smoothStep(state.Masks.RecoveryRadius, state.Masks.RoughRadius, nearestDistance)
			finalHeight = baseHeight + alpha * landContext.DetailNoise * 1.4 + landContext.RidgeBlend * 0.6
		end
	end

	return finalHeight, material, nearestDistance
end

local function sampleFinalSurface(x, z, state)
	local landContext = state.LandformRuntime:sampleContext(x, z)
	local baseHeight = landContext.Height
	local finalHeight, material, nearestRoadDistance = sampleRoadSurface(x, z, state, baseHeight, landContext)
	local branchTarget = branchRoadTarget(x, z, state.BranchSegments, state.Profile.RoadWidth, state.Profile.ShoulderWidth)

	if branchTarget and branchTarget.Distance <= branchTarget.Shoulder then
		local branchAlpha = WorldMath.smoothStep(branchTarget.HalfWidth, branchTarget.Shoulder, branchTarget.Distance)
		finalHeight = WorldMath.lerp(branchTarget.Height - 0.15, finalHeight, branchAlpha)
		material = branchTarget.Distance <= branchTarget.HalfWidth and Enum.Material.Asphalt or Enum.Material.Ground
	end

	for _, parcel in ipairs(state.ActiveParcels or {}) do
		local center = pointFromArray(parcel.Center)
		local forward = Vector3.new(math.sin(parcel.Rotation), 0, math.cos(parcel.Rotation))
		local right = Vector3.new(forward.Z, 0, -forward.X)
		local offset = Vector3.new(x - center.X, 0, z - center.Z)
		local localX = math.abs(offset:Dot(right))
		local localZ = math.abs(offset:Dot(forward))
		local halfX = parcel.ReserveSize.X * 0.5
		local halfZ = parcel.ReserveSize.Y * 0.5
		local edgeDistance = math.max(localX - halfX, localZ - halfZ)

		if edgeDistance < 18 and nearestRoadDistance > state.Masks.ShoulderRadius + 2 then
			local blend = edgeDistance <= 0 and 1 or (1 - (edgeDistance / 18))
			local targetHeight = parcel.Center[2]
			finalHeight = WorldMath.lerp(finalHeight, targetHeight, blend)
			material = Enum.Material.Ground
		end

		if parcel.AccessType ~= "RoadEdge" then
			local entry = pointFromArray(parcel.EntryPoint)
			local alpha, accessDistance = closestOnSegmentXZ(x, z, entry, center)
			local maxWidth = math.max(4, parcel.AccessWidth or 8)
			if accessDistance < maxWidth * 0.65 and nearestRoadDistance > state.Masks.RoadHalfWidth + 1 then
				local accessBlend = 1 - (accessDistance / (maxWidth * 0.65))
				local targetHeight = entry.Y + (center.Y - entry.Y) * alpha
				finalHeight = WorldMath.lerp(finalHeight, targetHeight, accessBlend * 0.82)
				material = parcel.AccessType == "DriveUp" and Enum.Material.Ground or Enum.Material.Grass
			end
		end
	end

	local waterSurface = nil
	if landContext.River and landContext.River.InWater then
		waterSurface = landContext.River.WaterY
	end

	return finalHeight, material, waterSurface, landContext
end

local function applyChunk(terrain, minX, maxX, minZ, maxZ, state)
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
			local topHeight, topMaterial, waterSurface = sampleFinalSurface(worldX, worldZ, state)

			for yIndex = 1, yCount do
				local worldY = regionMin.Y + (yIndex - 0.5) * resolution
				local solidOccupancy = WorldMath.clamp(0.5 + ((topHeight - worldY) / resolution), 0, 1)
				local waterOccupancy = waterSurface and WorldMath.clamp(0.5 + ((waterSurface - worldY) / resolution), 0, 1) or 0

				if solidOccupancy > 0 then
					materials[xIndex][yIndex][zIndex] = topMaterial
					occupancies[xIndex][yIndex][zIndex] = solidOccupancy
				elseif waterOccupancy > 0 then
					materials[xIndex][yIndex][zIndex] = Enum.Material.Water
					occupancies[xIndex][yIndex][zIndex] = waterOccupancy
				else
					materials[xIndex][yIndex][zIndex] = Enum.Material.Air
					occupancies[xIndex][yIndex][zIndex] = 0
				end
			end
		end
	end

	terrain:WriteVoxels(region, resolution, materials, occupancies)
end

function TerrainBuilder.createContext(profile, seed, landformDescriptor)
	local landformRuntime = LandformPlanner.createRuntime(landformDescriptor)

	local state = {
		Profile = profile,
		Seed = seed,
		Landform = landformDescriptor,
		LandformRuntime = landformRuntime,
		Loop = nil,
		Masks = nil,
		SpatialIndex = nil,
		ActiveParcels = {},
		ActiveBranches = {},
		BranchSegments = {},
	}

	function state:sampleBaseHeight(x, z)
		return self.LandformRuntime:sampleHeight(x, z)
	end

	function state:sampleLandContext(x, z)
		return self.LandformRuntime:sampleContext(x, z)
	end

	function state:setRoadLoop(loop, masks)
		self.Loop = loop
		self.Masks = masks
		self.SpatialIndex = RoadSpatialIndex.build(loop, math.max(48, masks.TerrainInfluenceRadius * 0.65))
	end

	function state:setLayout(parcels, branches)
		self.ActiveParcels = parcels or {}
		self.ActiveBranches = branches or {}
		self.BranchSegments = buildBranchSegments(self.ActiveBranches)
	end

	function state:sampleSurfaceHeight(x, z)
		local topHeight, _, waterSurface = sampleFinalSurface(x, z, self)
		return waterSurface and math.max(topHeight, waterSurface) or topHeight
	end

	function state:startCFrame()
		local startSample = self.Loop and self.Loop.Samples[1]
		if not startSample then
			return CFrame.new()
		end
		return CFrame.lookAt(startSample.Position, startSample.Position + startSample.Tangent, Vector3.yAxis)
	end

	function state:apply(parcels, branches)
		self:setLayout(parcels, branches)
		local terrain = Workspace.Terrain
		local halfSize = self.Profile.MapSizeStuds * 0.5
		local minX = -halfSize

		while minX < halfSize do
			local maxX = math.min(halfSize, minX + CHUNK_SIZE_STUDS)
			local minZ = -halfSize
			while minZ < halfSize do
				local maxZ = math.min(halfSize, minZ + CHUNK_SIZE_STUDS)
				applyChunk(terrain, minX, maxX, minZ, maxZ, self)
				minZ += CHUNK_SIZE_STUDS
			end
			minX += CHUNK_SIZE_STUDS
		end
	end

	return state
end

return TerrainBuilder
