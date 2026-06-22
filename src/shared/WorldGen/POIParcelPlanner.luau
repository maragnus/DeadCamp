local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))
local WorldMath = require(script.Parent:WaitForChild("WorldMath"))
local WorldTerrainMasks = require(script.Parent:WaitForChild("WorldTerrainMasks"))
local WorldSeed = require(script.Parent:WaitForChild("WorldSeed"))

local POIParcelPlanner = {}

local function parcelReserveSize(sizeClass, accessType)
	local padSize = WorldConstants.ParcelFootprints[sizeClass]
	local padding = WorldConstants.ParcelReservePadding[accessType]
	return Vector2.new(padSize.X + padding.X * 2, padSize.Y + padding.Y * 2)
end

local function parcelPoints(center, rightVector, forwardVector, reserveSize)
	local halfX = reserveSize.X * 0.5
	local halfZ = reserveSize.Y * 0.5

	return {
		center,
		center + rightVector * halfX + forwardVector * halfZ,
		center + rightVector * halfX,
		center + rightVector * halfX - forwardVector * halfZ,
		center + forwardVector * halfZ,
		center - forwardVector * halfZ,
		center - rightVector * halfX + forwardVector * halfZ,
		center - rightVector * halfX,
		center - rightVector * halfX - forwardVector * halfZ,
	}
end

local function flatteningCost(points, sampleHeight)
	local heights = {}
	local sum = 0

	for _, point in ipairs(points) do
		local height = sampleHeight(point.X, point.Z)
		heights[#heights + 1] = height
		sum += height
	end

	local average = sum / #heights
	local maxDelta = 0
	for _, height in ipairs(heights) do
		maxDelta = math.max(maxDelta, math.abs(height - average))
	end

	return average, maxDelta
end

local function lapDistance(loopLength, a, b)
	local distance = math.abs(a - b)
	return math.min(distance, loopLength - distance)
end

local function overlaps(existingParcels, center, reserveSize)
	for _, parcel in ipairs(existingParcels) do
		local distance = (parcel.Center - center).Magnitude
		local minimumDistance = math.max(parcel.ReserveSize.X, parcel.ReserveSize.Y, reserveSize.X, reserveSize.Y) * 0.82
		if distance < minimumDistance then
			return true
		end
	end
	return false
end

local function candidateFromSample(loop, sample, sampleIndex, sizeClass, accessType, sideSign, profile, sampleHeight, masks, targetLapDistance)
	local padSize = WorldConstants.ParcelFootprints[sizeClass]
	local reserveSize = parcelReserveSize(sizeClass, accessType)
	local roadOffset = profile.RoadWidth * 0.5 + profile.ShoulderWidth + reserveSize.X * 0.5
	local center = sample.Position + sample.Right * roadOffset * sideSign
	local forward = sample.Tangent
	local right = sample.Right
	local points = parcelPoints(center, right, forward, reserveSize)
	local targetHeight, maxDelta = flatteningCost(points, sampleHeight)
	local shortcutRisk = WorldTerrainMasks.shortcutRiskAt(center, masks)
	local entryPoint = sample.Position + sample.Right * sideSign * (profile.RoadWidth * 0.5 + profile.ShoulderWidth * 0.6)
	local targetDistance = lapDistance(loop.LoopLength, sample.LapDistance, targetLapDistance)
	local insideSide = sample.Curvature >= 0 and -1 or 1

	local baseScore = 120
	baseScore -= maxDelta * 10
	baseScore -= shortcutRisk * 220
	baseScore -= targetDistance * 0.08
	baseScore -= math.abs(sample.Curvature) * (sizeClass == WorldConstants.SizeClasses.Small and 180 or 90)

	if sizeClass == WorldConstants.SizeClasses.Small and sideSign == insideSide and math.abs(sample.Curvature) > 0.0012 then
		baseScore += 14
	end
	if sizeClass ~= WorldConstants.SizeClasses.Small and sideSign ~= insideSide then
		baseScore += 8
	end
	if accessType == WorldConstants.AccessTypes.DriveUp then
		baseScore += 10
	end

	return {
		Id = ("%s_%s_%d_%d"):format(sizeClass, accessType, sideSign, sampleIndex),
		SizeClass = sizeClass,
		AccessType = accessType,
		PadSize = { X = padSize.X, Y = padSize.Y },
		ReserveSize = { X = reserveSize.X, Y = reserveSize.Y },
		RoadSampleIndex = sampleIndex,
		LapDistance = sample.LapDistance,
		Center = center,
		Rotation = math.atan2(sample.Tangent.X, sample.Tangent.Z),
		EntryPoint = entryPoint,
		TargetHeight = targetHeight,
		FlatteningCost = maxDelta,
		ShortcutRisk = shortcutRisk,
		Score = baseScore,
	}
end

local function slotSizeClasses(profile, seed)
	local totalCount = (profile.POIBudgets.Small or 0) + (profile.POIBudgets.Medium or 0) + (profile.POIBudgets.Large or 0)
	local slots = table.create(totalCount, WorldConstants.SizeClasses.Small)
	local rng = WorldSeed.random(seed, "POISlots")
	local used = {}

	local function reserve(count, sizeClass)
		for index = 1, count do
			local target = math.floor(((index - 0.5) / math.max(1, count)) * totalCount) + 1
			target = WorldMath.clamp(target + rng:NextInteger(-1, 1), 1, totalCount)
			while used[target] do
				target = (target % totalCount) + 1
			end
			used[target] = true
			slots[target] = sizeClass
		end
	end

	reserve(profile.POIBudgets.Large or 0, WorldConstants.SizeClasses.Large)
	reserve(profile.POIBudgets.Medium or 0, WorldConstants.SizeClasses.Medium)

	return slots
end

function POIParcelPlanner.plan(loop, profile, masks, options)
	local sampleHeight = assert(options and options.SampleHeight, "POIParcelPlanner.plan requires SampleHeight")
	local seed = assert(options and options.Seed, "POIParcelPlanner.plan requires Seed")
	local parcels = {}
	local selected = {}
	local slots = slotSizeClasses(profile, seed)
	local totalCount = #slots
	local idealSpacing = loop.LoopLength / math.max(1, totalCount)
	local maxOffset = idealSpacing * WorldConstants.POISpacingVariance

	for slotIndex, sizeClass in ipairs(slots) do
		local targetLap = (slotIndex - 0.5) * idealSpacing
		local candidates = {}

		for sampleIndex, sample in ipairs(loop.Samples) do
			if lapDistance(loop.LoopLength, sample.LapDistance, targetLap) <= maxOffset then
				for _, sideSign in ipairs({ -1, 1 }) do
					for _, accessType in ipairs({ WorldConstants.AccessTypes.DriveUp, WorldConstants.AccessTypes.WalkUp }) do
						local candidate = candidateFromSample(loop, sample, sampleIndex, sizeClass, accessType, sideSign, profile, sampleHeight, masks, targetLap)
						if candidate.FlatteningCost <= 10 and candidate.ShortcutRisk <= 0.55 then
							candidates[#candidates + 1] = candidate
						end
					end
				end
			end
		end

		table.sort(candidates, function(a, b)
			return a.Score > b.Score
		end)

		for _, candidate in ipairs(candidates) do
			local reserveSize = Vector2.new(candidate.ReserveSize.X, candidate.ReserveSize.Y)
			local pacingOk = true

			for _, parcel in ipairs(parcels) do
				if lapDistance(loop.LoopLength, parcel.LapDistance, candidate.LapDistance) < idealSpacing * 0.5 then
					pacingOk = false
					break
				end
			end

			if pacingOk and not overlaps(selected, candidate.Center, reserveSize) then
				selected[#selected + 1] = {
					Center = candidate.Center,
					ReserveSize = reserveSize,
				}

				parcels[#parcels + 1] = {
					Id = candidate.Id,
					SizeClass = candidate.SizeClass,
					AccessType = candidate.AccessType,
					PadSize = candidate.PadSize,
					ReserveSize = candidate.ReserveSize,
					RoadSampleIndex = candidate.RoadSampleIndex,
					LapDistance = candidate.LapDistance,
					Center = { candidate.Center.X, candidate.TargetHeight, candidate.Center.Z },
					Rotation = candidate.Rotation,
					EntryPoint = { candidate.EntryPoint.X, candidate.TargetHeight, candidate.EntryPoint.Z },
					FlatteningCost = candidate.FlatteningCost,
					ShortcutRisk = candidate.ShortcutRisk,
				}
				break
			end
		end
	end

	return parcels
end

return POIParcelPlanner
