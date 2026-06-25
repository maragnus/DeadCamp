local Hydrology = require(script.Parent:WaitForChild("Hydrology"))
local WorldMath = require(script.Parent:WaitForChild("WorldMath"))
local WorldSeed = require(script.Parent:WaitForChild("WorldSeed"))

local LandformPlanner = {}

local function vectorToArray(vector)
	return { vector.X, vector.Y, vector.Z }
end

local function arrayToVector(values)
	return Vector3.new(values[1], values[2], values[3])
end

local function ridgePoint(alongAlpha, alongRange, offset, horizontal)
	local alongValue = WorldMath.lerp(-alongRange, alongRange, alongAlpha)
	if horizontal then
		return Vector3.new(alongValue, 0, offset)
	end
	return Vector3.new(offset, 0, alongValue)
end

local function closestOnSegmentXZ(position, a, b)
	local apx = position.X - a.X
	local apz = position.Z - a.Z
	local abx = b.X - a.X
	local abz = b.Z - a.Z
	local lengthSquared = abx * abx + abz * abz
	if lengthSquared <= 1e-4 then
		return 0, math.sqrt(apx * apx + apz * apz)
	end

	local alpha = WorldMath.clamp((apx * abx + apz * abz) / lengthSquared, 0, 1)
	local closestX = a.X + abx * alpha
	local closestZ = a.Z + abz * alpha
	local dx = position.X - closestX
	local dz = position.Z - closestZ
	return alpha, math.sqrt(dx * dx + dz * dz)
end

local function ridgeContribution(position, ridge)
	local alpha, distance = closestOnSegmentXZ(position, ridge.Start, ridge.Finish)
	local taper = math.sin(alpha * math.pi)
	local falloff = 1 - WorldMath.smoothStep(0, ridge.Width, distance)
	local strength = taper * falloff
	return ridge.Amplitude * strength, strength
end

local function basinContribution(position, basin)
	local dx = (position.X - basin.Center.X) / basin.RadiusX
	local dz = (position.Z - basin.Center.Z) / basin.RadiusZ
	local radial = math.sqrt(dx * dx + dz * dz)
	if radial >= 1 then
		return 0, 0
	end

	local alpha = 1 - radial
	return -basin.Strength * alpha * alpha, alpha
end

local function detailNoise(sampleSettings, seedOffset, x, z)
	local primary = math.noise(x * sampleSettings.PrimaryScale, z * sampleSettings.PrimaryScale, seedOffset) * sampleSettings.PrimaryAmplitude
	local secondary = math.noise(x * sampleSettings.SecondaryScale, z * sampleSettings.SecondaryScale, seedOffset + 17.1) * sampleSettings.SecondaryAmplitude
	local detail = math.noise(x * sampleSettings.DetailScale, z * sampleSettings.DetailScale, seedOffset + 39.7) * sampleSettings.DetailAmplitude
	return sampleSettings.BaseHeight + primary + secondary + detail
end

function LandformPlanner.generate(profile, seed)
	local safeHalf = profile.MapSizeStuds * 0.5 - profile.EdgeMarginStuds
	local landformConfig = profile.LandformConfig
	local rng = WorldSeed.random(seed, "Landforms")
	local river = Hydrology.generate(profile, seed)
	local ridgeCount = rng:NextInteger(landformConfig.RidgeCountMin, landformConfig.RidgeCountMax)
	local ridges = {}
	local horizontal = river and river.Orientation == "Horizontal" or (rng:NextNumber() < 0.5)
	local ridgeAlongRange = safeHalf * 0.96
	local primaryRiverOffset = river
		and rng:NextNumber(safeHalf * 0.12, safeHalf * 0.28)
		or rng:NextNumber(safeHalf * 0.08, safeHalf * 0.34)
	local baseSign = rng:NextNumber() < 0.5 and -1 or 1

	for ridgeIndex = 1, ridgeCount do
		local ridgeOffset = primaryRiverOffset * (baseSign * (ridgeIndex == 1 and 1 or -1))
		ridgeOffset += rng:NextNumber(-safeHalf * 0.08, safeHalf * 0.08)
		ridgeOffset = WorldMath.clamp(ridgeOffset, -safeHalf * 0.44, safeHalf * 0.44)
		local start = ridgePoint(0, ridgeAlongRange, ridgeOffset, horizontal)
		local finish = ridgePoint(1, ridgeAlongRange, ridgeOffset + rng:NextNumber(-safeHalf * 0.06, safeHalf * 0.06), horizontal)
		ridges[#ridges + 1] = {
			Start = vectorToArray(start),
			Finish = vectorToArray(finish),
			Width = rng:NextNumber(landformConfig.RidgeWidthMin, landformConfig.RidgeWidthMax),
			Amplitude = rng:NextNumber(landformConfig.RidgeAmplitudeMin, landformConfig.RidgeAmplitudeMax),
		}
	end

	local basinRadiusX = rng:NextNumber(landformConfig.BasinRadiusMin, landformConfig.BasinRadiusMax)
	local basinRadiusZ = rng:NextNumber(landformConfig.BasinRadiusMin, landformConfig.BasinRadiusMax)
	local basinCenter = Vector3.new(
		rng:NextNumber(-safeHalf * 0.16, safeHalf * 0.16),
		0,
		rng:NextNumber(-safeHalf * 0.16, safeHalf * 0.16)
	)

	return {
		Version = 1,
		River = river,
		Ridges = ridges,
		Basin = {
			Center = vectorToArray(basinCenter),
			RadiusX = basinRadiusX,
			RadiusZ = basinRadiusZ,
			Strength = landformConfig.BasinStrength,
		},
		DetailNoise = {
			BaseHeight = 16,
			PrimaryScale = 0.0015,
			PrimaryAmplitude = 18,
			SecondaryScale = 0.0036,
			SecondaryAmplitude = 6,
			DetailScale = 0.0088,
			DetailAmplitude = 2,
			SeedOffset = seed * 0.00073,
		},
	}
end

function LandformPlanner.createRuntime(descriptor)
	local ridges = {}
	for _, ridge in ipairs(descriptor.Ridges or {}) do
		ridges[#ridges + 1] = {
			Start = arrayToVector(ridge.Start),
			Finish = arrayToVector(ridge.Finish),
			Width = ridge.Width,
			Amplitude = ridge.Amplitude,
		}
	end

	local basin = {
		Center = arrayToVector(descriptor.Basin.Center),
		RadiusX = descriptor.Basin.RadiusX,
		RadiusZ = descriptor.Basin.RadiusZ,
		Strength = descriptor.Basin.Strength,
	}
	local riverRuntime = Hydrology.createRuntime(descriptor.River)
	local noiseSettings = descriptor.DetailNoise

	local runtime = {
		Descriptor = descriptor,
		Ridges = ridges,
		Basin = basin,
		River = riverRuntime,
	}
	local runtimeRidges = runtime.Ridges
	local runtimeBasin = runtime.Basin
	local runtimeRiver = runtime.River

	local function sampleValues(x, z)
		local position = Vector3.new(x, 0, z)
		local height = detailNoise(noiseSettings, noiseSettings.SeedOffset, x, z)
		local crestRisk = 0
		local ridgeBlend = 0

		for _, ridge in ipairs(runtimeRidges) do
			local addition, strength = ridgeContribution(position, ridge)
			height += addition
			ridgeBlend = math.max(ridgeBlend, strength)
			crestRisk = math.max(crestRisk, strength > 0 and math.max(0, strength - 0.55) / 0.45 or 0)
		end

		local basinDelta, basinAlpha = basinContribution(position, runtimeBasin)
		height += basinDelta

		local river = Hydrology.sample(runtimeRiver, position)
		if river then
			local floodplainRadius = river.BankHalfWidth + river.FloodplainWidth
			if river.Distance <= floodplainRadius then
				local floodplainAlpha = 1 - WorldMath.smoothStep(river.HalfWidth, floodplainRadius, river.Distance)
				local bankTarget = river.WaterY + math.max(0, river.Distance - river.HalfWidth) * 0.18 + runtimeRiver.Descriptor.BankLift
				height = WorldMath.lerp(height, bankTarget, floodplainAlpha * 0.65)
			end
			if river.InWater then
				height = math.min(height, river.WaterY - runtimeRiver.Descriptor.WaterDepth)
			elseif river.InBank then
				local bankAlpha = 1 - WorldMath.smoothStep(river.HalfWidth, river.BankHalfWidth, river.Distance)
				height = WorldMath.lerp(height, river.WaterY + runtimeRiver.Descriptor.BankLift * 0.35, bankAlpha * 0.55)
			end
		end

		return height, river, ridgeBlend, crestRisk, basinAlpha, basinAlpha * 0.35, math.noise(
			x * noiseSettings.DetailScale,
			z * noiseSettings.DetailScale,
			noiseSettings.SeedOffset + 57.2
		)
	end

	function runtime:sampleContext(x, z)
		local height, river, ridgeBlend, crestRisk, basinAlpha, basinShelfBias, detailValue = sampleValues(x, z)
		return {
			Height = height,
			River = river,
			RidgeBlend = ridgeBlend,
			RidgeCrestRisk = crestRisk,
			BasinAlpha = basinAlpha,
			BasinShelfBias = basinShelfBias,
			DetailNoise = detailValue,
		}
	end

	function runtime:sampleHeight(x, z)
		local height = sampleValues(x, z)
		return height
	end

	return runtime
end

return LandformPlanner
