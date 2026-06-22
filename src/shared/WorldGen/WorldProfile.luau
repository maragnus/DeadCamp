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
	AnchorCount = 14,
	MinCurveRadius = 52,
	CornerSweepStuds = 192,
	CenterDeviationSidesMin = 1,
	CenterDeviationSidesMax = 2,
	CenterDeviationDepthMin = 0.25,
	CenterDeviationDepthMax = 0.4,
	MildDeviationDepthMin = 0.06,
	MildDeviationDepthMax = 0.14,
	MaxRoadGradeDegrees = 8,
	MaxCrossfallDegrees = 4,
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
	validateNumber("AnchorCount", profile.AnchorCount, 6)
	validateNumber("MinCurveRadius", profile.MinCurveRadius, 16)
	validateNumber("CornerSweepStuds", profile.CornerSweepStuds, 16)
	validateNumber("CenterDeviationSidesMin", profile.CenterDeviationSidesMin, 0)
	validateNumber("CenterDeviationSidesMax", profile.CenterDeviationSidesMax, profile.CenterDeviationSidesMin)
	validateNumber("CenterDeviationDepthMin", profile.CenterDeviationDepthMin, 0)
	validateNumber("CenterDeviationDepthMax", profile.CenterDeviationDepthMax, profile.CenterDeviationDepthMin)
	validateNumber("MildDeviationDepthMin", profile.MildDeviationDepthMin, 0)
	validateNumber("MildDeviationDepthMax", profile.MildDeviationDepthMax, profile.MildDeviationDepthMin)
	validateNumber("MaxRoadGradeDegrees", profile.MaxRoadGradeDegrees, 0)
	validateNumber("MaxCrossfallDegrees", profile.MaxCrossfallDegrees, 0)
	validateNumber("VoxelResolution", profile.VoxelResolution, 4)

	if type(profile.POIBudgets) ~= "table" then
		error("POIBudgets must be a table", 2)
	end
	if type(profile.BranchConfig) ~= "table" then
		error("BranchConfig must be a table", 2)
	end

	return true
end

return WorldProfile
