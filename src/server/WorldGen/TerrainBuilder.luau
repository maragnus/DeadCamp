local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldGenShared = Shared:WaitForChild("WorldGen")

local LandformPlanner = require(WorldGenShared:WaitForChild("LandformPlanner"))
local RoadJunctionBuilder = require(WorldGenShared:WaitForChild("RoadJunctionBuilder"))
local RoadPathUtils = require(WorldGenShared:WaitForChild("RoadPathUtils"))
local RoadSurfaceProfile = require(WorldGenShared:WaitForChild("RoadSurfaceProfile"))
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

local function buildBranchSegments(branches, profile)
	local branchSegments = {}

	for _, branch in ipairs(branches or {}) do
		local samples = RoadPathUtils.deserializeSamples(branch.Samples)
		local segments = {}
		for index = 1, #samples - 1 do
			segments[#segments + 1] = {
				Start = samples[index].Position,
				Finish = samples[index + 1].Position,
				StartDistance = samples[index].LapDistance or 0,
				FinishDistance = samples[index + 1].LapDistance or 0,
			}
		end

		if #segments > 0 then
			branchSegments[#branchSegments + 1] = {
				Id = branch.Id,
				Type = branch.Type,
				HalfWidth = branch.HalfWidth or (profile.RoadWidth * 0.5),
				EntranceTaperLength = branch.EntranceTaperLength or 0,
				Segments = segments,
				Start = branch.Start,
				Finish = branch.Finish,
				StartSample = samples[1],
				FinishSample = samples[#samples],
			}
		end
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

local function mainRoadTarget(x, z, state)
	if not state.SpatialIndex then
		return nil, math.huge
	end

	local _, nearestSample, nearestDistance = RoadSpatialIndex.nearest(
		state.SpatialIndex,
		Vector3.new(x, 0, z),
		state.Masks.TerrainInfluenceRadius
	)
	if not nearestSample or nearestDistance > state.Masks.TerrainInfluenceRadius then
		return nil, nearestDistance
	end

	return {
		Distance = nearestDistance,
		Height = nearestSample.Position.Y,
		Position = nearestSample.Position,
		HalfWidth = state.Masks.RoadHalfWidth,
		Shoulder = state.Masks.ShoulderRadius,
		Recovery = state.Masks.RecoveryRadius,
		Rough = state.Masks.RoughRadius,
		Right = nearestSample.Right,
		SurfaceRaise = RoadSurfaceProfile.surfaceRaise(state.Profile, RoadSurfaceProfile.Kinds.Main),
	}, nearestDistance
end

local function branchRoadTarget(x, z, branchSegments, profile)
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
				local shoulder = halfWidth + profile.ShoulderWidth * 0.9
				local recovery = shoulder + profile.RecoveryWidth * 0.8
				nearest = {
					Distance = distance,
					Height = segment.Start.Y + (segment.Finish.Y - segment.Start.Y) * alpha,
					Position = segment.Start:Lerp(segment.Finish, alpha),
					HalfWidth = halfWidth,
					Shoulder = shoulder,
					Recovery = recovery,
					Rough = recovery + profile.DiscourageWidth * 0.45,
					Right = WorldMath.rightFromTangent(
						WorldMath.horizontalUnit(segment.Finish - segment.Start, Vector3.new(0, 0, -1))
					),
					SurfaceRaise = RoadSurfaceProfile.surfaceRaise(profile, RoadSurfaceProfile.Kinds.Secondary),
				}
			end
		end
	end

	return nearest
end

local function chooseRoadTarget(mainTarget, branchTarget)
	if not mainTarget then
		return branchTarget, branchTarget and branchTarget.Distance or math.huge
	end
	if not branchTarget then
		return mainTarget, mainTarget.Distance
	end

	local mainMetric = mainTarget.Distance / math.max(1, mainTarget.Shoulder)
	local branchMetric = branchTarget.Distance / math.max(1, branchTarget.Shoulder)
	if branchMetric < mainMetric then
		return branchTarget, math.min(mainTarget.Distance, branchTarget.Distance)
	end
	return mainTarget, math.min(mainTarget.Distance, branchTarget.Distance)
end

local function roadContextHeight(baseHeight, outerHeight, profile, landContext)
	local contextual = WorldMath.lerp(baseHeight, outerHeight, profile.TerrainConfig.RoadBlendStrength)
	return contextual + landContext.DetailNoise * 0.18 + landContext.RidgeBlend * 0.12
end

local function sampleRoadSurface(x, z, state, baseHeight, landContext)
	local material = terrainMaterialForContext(landContext)
	local mainTarget = mainRoadTarget(x, z, state)
	local branchTarget = branchRoadTarget(x, z, state.BranchSegments, state.Profile)
	local roadTarget, nearestRoadDistance = chooseRoadTarget(mainTarget, branchTarget)
	local finalHeight = baseHeight

	if roadTarget and nearestRoadDistance <= roadTarget.Rough then
		local right = roadTarget.Right or Vector3.xAxis
		local signedDistance = Vector3.new(x - roadTarget.Position.X, 0, z - roadTarget.Position.Z):Dot(right)
		local sideSign = signedDistance >= 0 and 1 or -1
		local outerProbe = roadTarget.Shoulder + state.Profile.TerrainConfig.OuterSampleDistance
		local outerX = x + right.X * sideSign * outerProbe
		local outerZ = z + right.Z * sideSign * outerProbe
		local outerHeight = state.LandformRuntime:sampleHeight(outerX, outerZ)
		local contextualHeight = roadContextHeight(baseHeight, outerHeight, state.Profile, landContext)
		local roadSurface = roadTarget.Height + roadTarget.SurfaceRaise
		local shoulderHeight = WorldMath.lerp(roadSurface, contextualHeight, 0.42) + state.Profile.TerrainConfig.ShoulderRaise
		shoulderHeight = math.min(
			shoulderHeight,
			roadSurface - RoadSurfaceProfile.shoulderValleyDepth(state.Profile)
		)
		local recoveryHeight = WorldMath.lerp(roadSurface, contextualHeight, 0.78)
		local roughHeight = contextualHeight + landContext.DetailNoise * 0.2 + landContext.RidgeBlend * 0.16

		if nearestRoadDistance <= roadTarget.HalfWidth then
			finalHeight = roadSurface
			material = Enum.Material.Asphalt
		elseif nearestRoadDistance <= roadTarget.Shoulder then
			local alpha = WorldMath.smoothStep(roadTarget.HalfWidth, roadTarget.Shoulder, nearestRoadDistance)
			finalHeight = WorldMath.lerp(roadSurface, shoulderHeight, alpha)
			material = Enum.Material.Ground
		elseif nearestRoadDistance <= roadTarget.Recovery then
			local alpha = WorldMath.smoothStep(roadTarget.Shoulder, roadTarget.Recovery, nearestRoadDistance)
			finalHeight = WorldMath.lerp(shoulderHeight, recoveryHeight, alpha)
		elseif nearestRoadDistance <= roadTarget.Rough then
			local alpha = WorldMath.smoothStep(roadTarget.Recovery, roadTarget.Rough, nearestRoadDistance)
			finalHeight = WorldMath.lerp(recoveryHeight, roughHeight, alpha)
		end
	end

	return finalHeight, material, nearestRoadDistance
end

local function applyJunctionSurface(x, z, state, finalHeight, material)
	local bestJunction = nil
	local bestDistance = math.huge
	local probe = Vector3.new(x, 0, z)

	for _, junction in ipairs(state.RoadJunctions) do
		local distance = WorldMath.distanceXZ(probe, junction.Position)
		if distance < bestDistance and distance <= junction.ShoulderRadius then
			bestDistance = distance
			bestJunction = junction
		end
	end

	if not bestJunction then
		return finalHeight, material
	end

	local flattenAlpha = 1 - WorldMath.smoothStep(0, bestJunction.ShoulderRadius, bestDistance)
	finalHeight = WorldMath.lerp(
		finalHeight,
		bestJunction.Height + bestJunction.SurfaceRaise,
		flattenAlpha * bestJunction.FlattenStrength
	)
	if bestDistance <= bestJunction.PavedRadius then
		material = Enum.Material.Asphalt
	elseif bestDistance <= bestJunction.ShoulderRadius and material ~= Enum.Material.Asphalt then
		material = Enum.Material.Ground
	end

	return finalHeight, material
end

local function sampleFinalSurface(x, z, state)
	local landContext = state.LandformRuntime:sampleContext(x, z)
	local baseHeight = landContext.Height
	local finalHeight, material, nearestRoadDistance = sampleRoadSurface(x, z, state, baseHeight, landContext)
	finalHeight, material = applyJunctionSurface(x, z, state, finalHeight, material)

	for _, parcel in ipairs(state.ActiveParcels or {}) do
		local center = pointFromArray(parcel.Center)
		local forward = WorldMath.forwardFromRotation(parcel.Rotation)
		local right = WorldMath.rightFromRotation(parcel.Rotation)
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

	return finalHeight, material, waterSurface
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
		RoadJunctions = {},
		ApplyCursor = nil,
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
		self.BranchSegments = buildBranchSegments(self.ActiveBranches, self.Profile)
		self.RoadJunctions = RoadJunctionBuilder.build(self.Loop, self.ActiveBranches, self.Profile)
	end

	function state:beginApply(parcels, branches)
		self:setLayout(parcels, branches)

		local halfSize = self.Profile.MapSizeStuds * 0.5
		local mapSpan = halfSize * 2
		self.ApplyCursor = {
			HalfSize = halfSize,
			NextMinX = -halfSize,
			NextMinZ = -halfSize,
			CompletedChunks = 0,
			TotalChunks = math.max(1, math.ceil(mapSpan / CHUNK_SIZE_STUDS) ^ 2),
		}

		return self.ApplyCursor
	end

	function state:applyNextChunk()
		local cursor = self.ApplyCursor
		if not cursor then
			error("TerrainBuilder.applyNextChunk called before beginApply", 2)
		end

		if cursor.NextMinX >= cursor.HalfSize then
			return {
				Done = true,
				CompletedChunks = cursor.CompletedChunks,
				TotalChunks = cursor.TotalChunks,
			}
		end

		local terrain = Workspace.Terrain
		local minX = cursor.NextMinX
		local maxX = math.min(cursor.HalfSize, minX + CHUNK_SIZE_STUDS)
		local minZ = cursor.NextMinZ
		local maxZ = math.min(cursor.HalfSize, minZ + CHUNK_SIZE_STUDS)
		applyChunk(terrain, minX, maxX, minZ, maxZ, self)
		cursor.CompletedChunks += 1

		cursor.NextMinZ += CHUNK_SIZE_STUDS
		if cursor.NextMinZ >= cursor.HalfSize then
			cursor.NextMinZ = -cursor.HalfSize
			cursor.NextMinX += CHUNK_SIZE_STUDS
		end

		local done = cursor.NextMinX >= cursor.HalfSize
		if done then
			self.ApplyCursor = nil
		end

		return {
			Done = done,
			CompletedChunks = cursor.CompletedChunks,
			TotalChunks = cursor.TotalChunks,
		}
	end

	function state:sampleSurfaceHeight(x, z, sample, roadKind)
		if typeof(sample) == "table" and typeof(sample.Position) == "Vector3" then
			return sample.Position.Y + RoadSurfaceProfile.surfaceRaise(self.Profile, roadKind)
		end

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
		self:beginApply(parcels, branches)
		while true do
			local progress = self:applyNextChunk()
			if progress.Done then
				break
			end
		end
	end

	return state
end

return TerrainBuilder
