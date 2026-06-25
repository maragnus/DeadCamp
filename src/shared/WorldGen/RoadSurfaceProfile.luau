local RoadSurfaceProfile = {}

RoadSurfaceProfile.Kinds = {
	Main = "Main",
	Secondary = "Secondary",
}

local function terrainConfig(profile)
	assert(type(profile) == "table", "RoadSurfaceProfile requires a world profile")
	assert(type(profile.TerrainConfig) == "table", "RoadSurfaceProfile requires TerrainConfig")
	return profile.TerrainConfig
end

function RoadSurfaceProfile.surfaceRaise(profile, roadKind)
	local config = terrainConfig(profile)
	if roadKind == RoadSurfaceProfile.Kinds.Secondary then
		return config.SecondaryRoadSurfaceRaise
	end

	return config.RoadSurfaceRaise
end

function RoadSurfaceProfile.visualClearance(profile, roadKind)
	local config = terrainConfig(profile)
	if roadKind == RoadSurfaceProfile.Kinds.Secondary then
		return config.SecondaryRoadVisualClearance
	end

	return config.RoadVisualClearance
end

function RoadSurfaceProfile.visualSurfaceLift(profile, roadKind)
	return RoadSurfaceProfile.surfaceRaise(profile, roadKind) + RoadSurfaceProfile.visualClearance(profile, roadKind)
end

function RoadSurfaceProfile.renderSamples(samples, profile, roadKind, sampleSurfaceHeight)
	assert(type(sampleSurfaceHeight) == "function", "RoadSurfaceProfile.renderSamples requires a surface-height callback")

	local liftedSamples = {}
	local clearance = RoadSurfaceProfile.visualClearance(profile, roadKind)
	for _, sample in ipairs(samples or {}) do
		local position = sample.Position
		local liftedY = sampleSurfaceHeight(position.X, position.Z, sample) + clearance
		liftedSamples[#liftedSamples + 1] = {
			Position = Vector3.new(position.X, liftedY, position.Z),
			Tangent = sample.Tangent,
			Right = sample.Right,
			Up = sample.Up,
			Curvature = sample.Curvature,
			LapDistance = sample.LapDistance,
		}
	end

	return liftedSamples
end

function RoadSurfaceProfile.visualSurfaceHeight(sampleHeight, profile, roadKind)
	return sampleHeight + RoadSurfaceProfile.visualSurfaceLift(profile, roadKind)
end

function RoadSurfaceProfile.auditClearance(profile, roadKind)
	return math.max(0.04, RoadSurfaceProfile.visualClearance(profile, roadKind) * 0.5)
end

function RoadSurfaceProfile.shoulderValleyDepth(profile)
	return terrainConfig(profile).ShoulderValleyDepth
end

return RoadSurfaceProfile
