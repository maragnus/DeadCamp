local RoadMeshBuilder = require(script.Parent:WaitForChild("RoadMeshBuilder"))
local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))
local RoadSurfaceProfile = require(script.Parent:WaitForChild("RoadSurfaceProfile"))

local RoadRibbonSpec = {}

local function resolveDiagnostics(settings, profileId, seed)
	if type(settings.Diagnostics) == "table" then
		local diagnostics = {}
		for key, value in pairs(settings.Diagnostics) do
			diagnostics[key] = value
		end
		diagnostics.Enabled = diagnostics.Enabled ~= false
		diagnostics.LabelPrefix = diagnostics.LabelPrefix or diagnostics.ChunkLabel or ("%s/%s"):format(tostring(profileId), tostring(seed))
		return diagnostics
	end

	if WorldConstants.DebugFlags.RoadRenderMeshDiagnostics ~= true then
		return nil
	end

	return {
		Enabled = true,
		LabelPrefix = ("%s/%s"):format(tostring(profileId), tostring(seed)),
	}
end

function RoadRibbonSpec.fromSamples(profileId, seed, samples, width, options)
	local settings = options or {}
	local closed = settings.Closed == true
	local thickness = settings.Thickness or WorldConstants.DefaultRibbonThickness
	local roadLift = settings.RoadLift
	if roadLift == nil then
		roadLift = WorldConstants.DefaultRoadLift
	end
	local chunkPrefix = settings.ChunkPrefix or "Chunk"
	local diagnostics = resolveDiagnostics(settings, profileId, seed)
	local spec = RoadMeshBuilder.buildSpec(profileId, seed, samples, width, {
		Closed = closed,
		Thickness = thickness,
		NormalOffset = roadLift,
		MinimumDot = 0.001,
		MaxSectionLength = WorldConstants.MaxRoadMeshLength,
		ChunkPrefix = chunkPrefix,
		Diagnostics = diagnostics,
	})

	return {
		ProfileId = spec.ProfileId,
		Seed = spec.Seed,
		Width = spec.Width,
		Thickness = spec.Thickness,
		Closed = spec.Closed,
		Chunks = spec.Chunks,
	}
end

function RoadRibbonSpec.fromLoop(loop, profile)
	local width = (profile and profile.RoadWidth) or loop.RoadWidth
	assert(type(width) == "number", "RoadRibbonSpec.fromLoop requires a RoadWidth from the profile or loop descriptor")
	local roadLift = profile and RoadSurfaceProfile.visualSurfaceLift(profile, RoadSurfaceProfile.Kinds.Main)
		or WorldConstants.DefaultRoadLift

	return RoadRibbonSpec.fromSamples(loop.ProfileId, loop.Seed, loop.Samples, width, {
		Closed = loop.Closed ~= false,
		ChunkPrefix = "LoopChunk",
		RoadLift = roadLift,
	})
end

return RoadRibbonSpec
