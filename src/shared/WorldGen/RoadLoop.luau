local RunService = game:GetService("RunService")

local RoadLoopGraphPlanner = require(script.Parent:WaitForChild("RoadLoopGraphPlanner"))
local RoadLoopAttemptRanker = require(script.Parent:WaitForChild("RoadLoopAttemptRanker"))
local RoadLoopDiagnostics = require(script.Parent:WaitForChild("RoadLoopDiagnostics"))
local RoadLoopSettings = require(script.Parent:WaitForChild("RoadLoopSettings"))
local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))
local WorldProfile = require(script.Parent:WaitForChild("WorldProfile"))
local WorldSeed = require(script.Parent:WaitForChild("WorldSeed"))
local WorldMath = require(script.Parent:WaitForChild("WorldMath"))

local RoadLoop = {}
local lastFailure = nil

local MAX_FAILURE_EXAMPLES = 6

local function graphAttemptRecord(profile, planner, attemptNumber, attemptSeed, options)
	local samplePositions = planner.PathPositions or {}
	local loopLength = planner.PathLength or RoadPathUtils.pathLength(samplePositions, true)
	local samples = RoadLoopDiagnostics.describeLoop(samplePositions, loopLength)
	if options and type(options.SampleHeight) == "function" then
		RoadPathUtils.fitHeights(samples, options.SampleHeight, profile.MaxRoadGradeDegrees, true)
	end

	local buildResult = {
		ControlFrames = planner.Frames,
		Segments = {},
	}
	local diagnostics = RoadLoopDiagnostics.evaluate(samples, profile, options)

	return RoadLoopAttemptRanker.buildAttemptRecord(
		profile,
		attemptNumber,
		attemptSeed,
		planner,
		buildResult,
		samples,
		loopLength,
		diagnostics
	)
end

local function plannerFailureAttempt(profile, attemptNumber, attemptSeed, failure)
	local failureReason = failure and failure.Reason or "UnknownGraphFailure"
	return RoadLoopAttemptRanker.buildAttemptRecord(
		profile,
		attemptNumber,
		attemptSeed,
		{
			StrategyName = "GraphPlanner",
			FailureReason = failureReason,
			Anchors = {},
			Frames = {},
			Topology = {},
		},
		{
			ControlFrames = {},
			Segments = {},
		},
		{},
		0,
		{
			Accepted = false,
			SelfIntersectionOk = true,
			Intersections = {
				Count = 0,
				SampleA = nil,
				SampleB = nil,
				Position = nil,
			},
			Coverage = {
				WidthCoverage = 0,
				DepthCoverage = 0,
				FootprintAreaRatio = 0,
				QuadrantsReached = 0,
				QuadrantsMissing = { "NorthWest", "NorthEast", "SouthEast", "SouthWest" },
				OuterTouches = 0,
				Score = 0,
			},
			LandIntent = {
				ScenicScore = 0,
			},
		}
	)
end

local function buildLoopResult(profile, seed, attemptRecord)
	if RunService:IsStudio() then
		warn(("RoadLoop.generate selected attempt %d for profile %s seed %d with coverage %.3f scenic %.3f"):format(
			attemptRecord.AttemptNumber,
			profile.Id,
			seed,
			attemptRecord.Diagnostics.Coverage.Score,
			attemptRecord.Diagnostics.LandIntent.ScenicScore
		))
	end

	return {
		ProfileId = profile.Id,
		Seed = seed,
		LoopLength = attemptRecord.LoopLength,
		StartIndex = 1,
		Samples = WorldMath.deepCopy(attemptRecord.Samples),
		ShortcutHotspots = RoadLoopDiagnostics.shortcutHotspots(attemptRecord.Samples, attemptRecord.LoopLength),
		ScenicScore = attemptRecord.Diagnostics.LandIntent.ScenicScore,
		ControlFrames = WorldMath.deepCopy(attemptRecord.ControlFrames),
		CurveSegments = WorldMath.deepCopy(attemptRecord.CurveSegments),
		Topology = WorldMath.deepCopy(attemptRecord.Topology),
		CoverageScore = attemptRecord.Diagnostics.Coverage.Score,
		Diagnostics = WorldMath.deepCopy(attemptRecord.Diagnostics),
	}
end

local function countFailures(failureCounts, attemptRecord)
	if attemptRecord.FailureReason then
		failureCounts.PlannerFailure += 1
		return
	end

	if not attemptRecord.Diagnostics.SelfIntersectionOk then
		failureCounts.SelfIntersection += 1
	end
end

function RoadLoop.latestFailure()
	return WorldMath.deepCopy(lastFailure)
end

function RoadLoop.generate(profileInput, seedInput, options)
	local profile = WorldProfile.resolve(profileInput)
	local settings = RoadLoopSettings.resolve(profile)
	local seed = WorldSeed.normalize(seedInput)
	lastFailure = nil

	local failureCounts = {
		PlannerFailure = 0,
		SelfIntersection = 0,
	}
	local failureExamples = {}
	local bestAttempt = nil

	for attempt = 0, settings.SearchAttempts - 1 do
		local attemptNumber = attempt + 1
		local attemptSeed = WorldSeed.combine(seed + attempt * 193, "Graph")
		local planner, plannerFailure = RoadLoopGraphPlanner.generate(profile, attemptSeed)
		local attemptRecord = planner and graphAttemptRecord(profile, planner, attemptNumber, attemptSeed, options)
			or plannerFailureAttempt(profile, attemptNumber, attemptSeed, plannerFailure)

		if attemptRecord.Diagnostics.Accepted then
			lastFailure = nil
			return buildLoopResult(profile, seed, attemptRecord)
		end

		countFailures(failureCounts, attemptRecord)

		if #failureExamples < MAX_FAILURE_EXAMPLES then
			failureExamples[#failureExamples + 1] = RoadLoopAttemptRanker.failureLine(attemptRecord)
		end

		if RoadLoopAttemptRanker.isBetterRejected(attemptRecord, bestAttempt) then
			bestAttempt = attemptRecord
		end
	end

	lastFailure = {
		ProfileId = profile.Id,
		Seed = seed,
		Attempts = settings.SearchAttempts,
		FailureCounts = WorldMath.deepCopy(failureCounts),
		FailureExamples = WorldMath.deepCopy(failureExamples),
		BestAttempt = bestAttempt,
	}

	error(((
		"RoadLoop.generate failed for profile %s seed %d after %d attempts. Reject counts: planner=%d, selfIntersection=%d. Sample rejects: %s"
	):format(
		profile.Id,
		seed,
		settings.SearchAttempts,
		failureCounts.PlannerFailure,
		failureCounts.SelfIntersection,
		table.concat(failureExamples, " | ")
	)), 2)
end

return RoadLoop
