local WorldMath = require(script.Parent:WaitForChild("WorldMath"))

local RoadLoopAttemptRanker = {}

function RoadLoopAttemptRanker.buildAttemptRecord(profile, attemptNumber, attemptSeed, planner, buildResult, samples, loopLength, diagnostics)
	return {
		Profile = {
			Id = profile.Id,
		},
		AttemptNumber = attemptNumber,
		AttemptSeed = attemptSeed,
		StrategyName = planner and planner.StrategyName or "GraphPlanner",
		FailureReason = planner and planner.FailureReason or nil,
		Anchors = WorldMath.deepCopy(planner and planner.Anchors or {}),
		ControlFrames = WorldMath.deepCopy(buildResult and buildResult.ControlFrames or planner and planner.Frames or {}),
		CurveSegments = WorldMath.deepCopy(buildResult and buildResult.Segments or {}),
		SectorPlan = WorldMath.deepCopy(planner and planner.SectorPlan or {}),
		Topology = WorldMath.deepCopy(planner and planner.Topology or {}),
		Samples = WorldMath.deepCopy(samples or {}),
		LoopLength = loopLength or 0,
		Diagnostics = WorldMath.deepCopy(diagnostics),
	}
end

function RoadLoopAttemptRanker.failureLine(attempt)
	local diagnostics = attempt.Diagnostics
	local reasons = {}

	if attempt.FailureReason then
		reasons[#reasons + 1] = ("planner failure %s"):format(attempt.FailureReason)
	end
	if diagnostics and not diagnostics.SelfIntersectionOk then
		reasons[#reasons + 1] = ("self intersections %d near %d/%d"):format(
			diagnostics.Intersections.Count or 0,
			diagnostics.Intersections.SampleA or -1,
			diagnostics.Intersections.SampleB or -1
		)
	end

	if #reasons == 0 then
		reasons[#reasons + 1] = "rejected"
	end

	return ("attempt %d seed %d strategy %s [%s]"):format(
		attempt.AttemptNumber,
		attempt.AttemptSeed,
		attempt.StrategyName,
		table.concat(reasons, ", ")
	)
end

local function failureSeverity(attempt)
	if attempt.FailureReason then
		return 10
	end

	local intersections = attempt.Diagnostics and attempt.Diagnostics.Intersections and attempt.Diagnostics.Intersections.Count or 0
	return intersections * 1.4
end

function RoadLoopAttemptRanker.isBetterRejected(candidate, currentBest)
	if not currentBest then
		return true
	end

	local candidateSeverity = failureSeverity(candidate)
	local currentSeverity = failureSeverity(currentBest)
	if candidateSeverity ~= currentSeverity then
		return candidateSeverity < currentSeverity
	end

	if candidate.Diagnostics.Coverage.Score ~= currentBest.Diagnostics.Coverage.Score then
		return candidate.Diagnostics.Coverage.Score > currentBest.Diagnostics.Coverage.Score
	end

	return candidate.AttemptNumber > currentBest.AttemptNumber
end

return RoadLoopAttemptRanker
