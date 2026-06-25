local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))
local WorldMath = require(script.Parent:WaitForChild("WorldMath"))

local WorldProfile = {}

local DEFAULT_PROFILE = {
	Id = "RuralTwoLane2048",
	MapSizeStuds = 2048,
	EdgeMarginStuds = 192,
	RoadStyle = "RuralTwoLane",
	RoadWidth = 22,
	ShoulderWidth = 8,
	RecoveryWidth = 12,
	DiscourageWidth = 24,
	BarrierWidth = 52,
	TargetLoopLength = 4700,
	MinCurveRadius = 52,
	CenterReachRadius = 220,
	MaxRoadGradeDegrees = 8,
	MaxCrossfallDegrees = 4,
	PathPlanner = {
		SearchAttempts = 1,
		HairpinTurnDegrees = 118,
		StraightRunLimitStuds = 430,
		ScoreWeights = {
			Footprint = 2.9,
			Quadrants = 1.5,
			RadiusMargin = 1.6,
			StraightRun = 1.7,
			Hairpin = 1.8,
			Smoothness = 1.1,
			Scenic = 1.2,
		},
		Graph = {
			GenerationAttempts = 1,
			NodeCountMin = 22,
			NodeCountMax = 30,
			NodeJitter = 0.78,
			TargetFaceFractionMin = 0.26,
			TargetFaceFractionMax = 0.42,
			MinCycleNodes = 8,
			PerimeterWeight = 1.05,
			SpreadWeight = 1.05,
			RandomWeight = 0.25,
			EdgeBendFraction = 0.16,
			EdgeDetourRate = 0.22,
			EdgeDensitySamples = 16,
			CurveAttemptCount = 8,
			CurveBackoffFactor = 0.5,
			CurveMinimumScale = 0.04,
		},
	},
	RiverConfig = {
		Enabled = false,
		WidthMin = 28,
		WidthMax = 44,
		WidthVariance = 0.18,
		BankWidth = 18,
		BankWidthVariance = 10,
		FloodplainWidth = 54,
		RoadClearance = 38,
		MeanderStrength = 210,
		WaterLevelBase = 8,
		WaterLevelVariance = 2.5,
		WaterSlope = 3.5,
		WaterDepth = 5,
	},
	LandformConfig = {
		RidgeCountMin = 1,
		RidgeCountMax = 2,
		RidgeWidthMin = 150,
		RidgeWidthMax = 240,
		RidgeAmplitudeMin = 16,
		RidgeAmplitudeMax = 28,
		BasinRadiusMin = 200,
		BasinRadiusMax = 320,
		BasinStrength = 12,
		RoadsideCutDepth = 4.5,
		RoadsideFillDepth = 3.5,
	},
	POIBudgets = {
		Small = 6,
		Medium = 2,
		Large = 1,
	},
	BranchConfig = {
		TotalBranches = 4,
		DeadEndPOIs = 1,
		FalseIntersections = 1,
		MinBranchLength = 220,
		MaxBranchLength = 420,
	},
	VoxelResolution = WorldConstants.TerrainResolution,
}

local PROFILES = {
	[DEFAULT_PROFILE.Id] = DEFAULT_PROFILE,
}

local function validateNumber(name, value, minimum)
	if type(value) ~= "number" or value < minimum then
		error(("%s must be a number >= %s"):format(name, tostring(minimum)), 3)
	end
end

function WorldProfile.defaultId()
	return DEFAULT_PROFILE.Id
end

function WorldProfile.get(profileId)
	local profile = PROFILES[profileId or DEFAULT_PROFILE.Id]
	if not profile then
		error(("Unknown world profile %s"):format(tostring(profileId)), 2)
	end

	return WorldMath.deepCopy(profile)
end

function WorldProfile.resolve(profileOrId, overrides)
	local base = type(profileOrId) == "table" and WorldMath.deepCopy(profileOrId) or WorldProfile.get(profileOrId)

	for key, value in pairs(overrides or {}) do
		base[key] = WorldMath.deepCopy(value)
	end

	WorldProfile.validate(base)
	return base
end

function WorldProfile.validate(profile)
	if type(profile.Id) ~= "string" or profile.Id == "" then
		error("World profile Id is required", 2)
	end

	validateNumber("MapSizeStuds", profile.MapSizeStuds, 256)
	validateNumber("EdgeMarginStuds", profile.EdgeMarginStuds, 32)
	validateNumber("RoadWidth", profile.RoadWidth, 8)
	validateNumber("ShoulderWidth", profile.ShoulderWidth, 0)
	validateNumber("RecoveryWidth", profile.RecoveryWidth, 0)
	validateNumber("DiscourageWidth", profile.DiscourageWidth, 0)
	validateNumber("BarrierWidth", profile.BarrierWidth, 0)
	validateNumber("TargetLoopLength", profile.TargetLoopLength, 512)
	validateNumber("MinCurveRadius", profile.MinCurveRadius, 16)
	validateNumber("CenterReachRadius", profile.CenterReachRadius, 64)
	validateNumber("MaxRoadGradeDegrees", profile.MaxRoadGradeDegrees, 0)
	validateNumber("MaxCrossfallDegrees", profile.MaxCrossfallDegrees, 0)
	validateNumber("VoxelResolution", profile.VoxelResolution, 4)

	if type(profile.POIBudgets) ~= "table" then
		error("POIBudgets must be a table", 2)
	end
	if type(profile.BranchConfig) ~= "table" then
		error("BranchConfig must be a table", 2)
	end
	if type(profile.RiverConfig) ~= "table" then
		error("RiverConfig must be a table", 2)
	end
	if profile.RiverConfig.Enabled ~= nil and type(profile.RiverConfig.Enabled) ~= "boolean" then
		error("RiverConfig.Enabled must be a boolean", 2)
	end
	if type(profile.LandformConfig) ~= "table" then
		error("LandformConfig must be a table", 2)
	end
	if type(profile.PathPlanner) ~= "table" then
		error("PathPlanner must be a table", 2)
	end

	validateNumber("PathPlanner.SearchAttempts", profile.PathPlanner.SearchAttempts, 1)
	validateNumber("PathPlanner.HairpinTurnDegrees", profile.PathPlanner.HairpinTurnDegrees, 0)
	validateNumber("PathPlanner.StraightRunLimitStuds", profile.PathPlanner.StraightRunLimitStuds, 32)
	if type(profile.PathPlanner.ScoreWeights) ~= "table" then
		error("PathPlanner.ScoreWeights must be a table", 2)
	end
	if type(profile.PathPlanner.Graph) ~= "table" then
		error("PathPlanner.Graph must be a table", 2)
	end
	validateNumber("PathPlanner.Graph.GenerationAttempts", profile.PathPlanner.Graph.GenerationAttempts, 1)
	validateNumber("PathPlanner.Graph.NodeCountMin", profile.PathPlanner.Graph.NodeCountMin, 12)
	validateNumber("PathPlanner.Graph.NodeCountMax", profile.PathPlanner.Graph.NodeCountMax, profile.PathPlanner.Graph.NodeCountMin)
	validateNumber("PathPlanner.Graph.NodeJitter", profile.PathPlanner.Graph.NodeJitter, 0)
	validateNumber("PathPlanner.Graph.TargetFaceFractionMin", profile.PathPlanner.Graph.TargetFaceFractionMin, 0.05)
	validateNumber("PathPlanner.Graph.TargetFaceFractionMax", profile.PathPlanner.Graph.TargetFaceFractionMax, profile.PathPlanner.Graph.TargetFaceFractionMin)
	validateNumber("PathPlanner.Graph.MinCycleNodes", profile.PathPlanner.Graph.MinCycleNodes, 6)
	validateNumber("PathPlanner.Graph.PerimeterWeight", profile.PathPlanner.Graph.PerimeterWeight, 0)
	validateNumber("PathPlanner.Graph.SpreadWeight", profile.PathPlanner.Graph.SpreadWeight, 0)
	validateNumber("PathPlanner.Graph.RandomWeight", profile.PathPlanner.Graph.RandomWeight, 0)
	validateNumber("PathPlanner.Graph.EdgeBendFraction", profile.PathPlanner.Graph.EdgeBendFraction, 0)
	validateNumber("PathPlanner.Graph.EdgeDetourRate", profile.PathPlanner.Graph.EdgeDetourRate, 0)
	validateNumber("PathPlanner.Graph.EdgeDensitySamples", profile.PathPlanner.Graph.EdgeDensitySamples, 6)
	validateNumber("PathPlanner.Graph.CurveAttemptCount", profile.PathPlanner.Graph.CurveAttemptCount, 1)
	validateNumber("PathPlanner.Graph.CurveBackoffFactor", profile.PathPlanner.Graph.CurveBackoffFactor, 0.1)
	validateNumber("PathPlanner.Graph.CurveMinimumScale", profile.PathPlanner.Graph.CurveMinimumScale, 0.01)

	validateNumber("RiverConfig.WidthMin", profile.RiverConfig.WidthMin, 8)
	validateNumber("RiverConfig.WidthMax", profile.RiverConfig.WidthMax, profile.RiverConfig.WidthMin)
	validateNumber("RiverConfig.WidthVariance", profile.RiverConfig.WidthVariance, 0)
	validateNumber("RiverConfig.BankWidth", profile.RiverConfig.BankWidth, 0)
	validateNumber("RiverConfig.BankWidthVariance", profile.RiverConfig.BankWidthVariance, 0)
	validateNumber("RiverConfig.FloodplainWidth", profile.RiverConfig.FloodplainWidth, 0)
	validateNumber("RiverConfig.RoadClearance", profile.RiverConfig.RoadClearance, 0)
	validateNumber("RiverConfig.MeanderStrength", profile.RiverConfig.MeanderStrength, 0)
	validateNumber("RiverConfig.WaterLevelBase", profile.RiverConfig.WaterLevelBase, -128)
	validateNumber("RiverConfig.WaterLevelVariance", profile.RiverConfig.WaterLevelVariance, 0)
	validateNumber("RiverConfig.WaterSlope", profile.RiverConfig.WaterSlope, 0)
	validateNumber("RiverConfig.WaterDepth", profile.RiverConfig.WaterDepth, 0)

	validateNumber("LandformConfig.RidgeCountMin", profile.LandformConfig.RidgeCountMin, 0)
	validateNumber("LandformConfig.RidgeCountMax", profile.LandformConfig.RidgeCountMax, profile.LandformConfig.RidgeCountMin)
	validateNumber("LandformConfig.RidgeWidthMin", profile.LandformConfig.RidgeWidthMin, 16)
	validateNumber("LandformConfig.RidgeWidthMax", profile.LandformConfig.RidgeWidthMax, profile.LandformConfig.RidgeWidthMin)
	validateNumber("LandformConfig.RidgeAmplitudeMin", profile.LandformConfig.RidgeAmplitudeMin, 0)
	validateNumber("LandformConfig.RidgeAmplitudeMax", profile.LandformConfig.RidgeAmplitudeMax, profile.LandformConfig.RidgeAmplitudeMin)
	validateNumber("LandformConfig.BasinRadiusMin", profile.LandformConfig.BasinRadiusMin, 32)
	validateNumber("LandformConfig.BasinRadiusMax", profile.LandformConfig.BasinRadiusMax, profile.LandformConfig.BasinRadiusMin)
	validateNumber("LandformConfig.BasinStrength", profile.LandformConfig.BasinStrength, 0)
	validateNumber("LandformConfig.RoadsideCutDepth", profile.LandformConfig.RoadsideCutDepth, 0)
	validateNumber("LandformConfig.RoadsideFillDepth", profile.LandformConfig.RoadsideFillDepth, 0)

	return true
end

return WorldProfile
