local WorldMath = require(script.Parent:WaitForChild("WorldMath"))

local RoadLoopSettings = {}

local DEFAULTS = {
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
}

local function deepMerge(base, overrides)
	local merged = WorldMath.deepCopy(base)
	for key, value in pairs(overrides or {}) do
		if type(value) == "table" and type(merged[key]) == "table" then
			merged[key] = deepMerge(merged[key], value)
		else
			merged[key] = WorldMath.deepCopy(value)
		end
	end
	return merged
end

function RoadLoopSettings.resolve(profile)
	local settings = deepMerge(DEFAULTS, profile and profile.PathPlanner or nil)
	settings.SearchAttempts = math.max(1, math.floor((settings.SearchAttempts or 1) + 0.5))
	settings.Graph.GenerationAttempts = math.max(1, math.floor((settings.Graph.GenerationAttempts or 4) + 0.5))
	settings.Graph.NodeCountMin = math.max(12, math.floor((settings.Graph.NodeCountMin or 18) + 0.5))
	settings.Graph.NodeCountMax = math.max(settings.Graph.NodeCountMin, math.floor((settings.Graph.NodeCountMax or settings.Graph.NodeCountMin) + 0.5))
	settings.Graph.MinCycleNodes = math.max(6, math.floor((settings.Graph.MinCycleNodes or 8) + 0.5))
	settings.Graph.PerimeterWeight = math.max(0, settings.Graph.PerimeterWeight or 1.05)
	settings.Graph.SpreadWeight = math.max(0, settings.Graph.SpreadWeight or 1.05)
	settings.Graph.RandomWeight = math.max(0, settings.Graph.RandomWeight or 0.25)
	settings.Graph.EdgeBendFraction = math.max(0, settings.Graph.EdgeBendFraction or 0.16)
	settings.Graph.EdgeDetourRate = WorldMath.clamp(settings.Graph.EdgeDetourRate or 0.22, 0, 1)
	settings.Graph.EdgeDensitySamples = math.max(6, math.floor((settings.Graph.EdgeDensitySamples or 16) + 0.5))
	settings.Graph.CurveAttemptCount = math.max(1, math.floor((settings.Graph.CurveAttemptCount or 8) + 0.5))
	settings.Graph.CurveBackoffFactor = WorldMath.clamp(settings.Graph.CurveBackoffFactor or 0.5, 0.1, 0.9)
	settings.Graph.CurveMinimumScale = WorldMath.clamp(settings.Graph.CurveMinimumScale or 0.04, 0.01, 1)
	return settings
end

return RoadLoopSettings
