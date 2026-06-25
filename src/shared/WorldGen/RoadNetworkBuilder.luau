local GeometryDirections = require(script.Parent.Parent:WaitForChild("Geometry"):WaitForChild("GeometryDirections"))
local MeshShapePrimitives = require(script.Parent.Parent:WaitForChild("Geometry"):WaitForChild("MeshShapePrimitives"))
local RoadJunctionBuilder = require(script.Parent:WaitForChild("RoadJunctionBuilder"))
local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))
local RoadRenderBuilder = require(script.Parent:WaitForChild("RoadRenderBuilder"))
local RoadRibbonSpec = require(script.Parent:WaitForChild("RoadRibbonSpec"))
local RoadSurfaceProfile = require(script.Parent:WaitForChild("RoadSurfaceProfile"))
local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))

local RoadNetworkBuilder = {}

local function resolveRoadSamples(road)
	local samples = road.Samples or {}
	if #samples > 0 and typeof(samples[1].Position) == "Vector3" then
		return samples
	end

	return RoadPathUtils.deserializeSamples(samples)
end

local function appendChunks(targetSpec, sourceSpec)
	for _, chunk in ipairs(sourceSpec and sourceSpec.Chunks or {}) do
		targetSpec.Chunks[#targetSpec.Chunks + 1] = chunk
	end
end

local function buildLoopSpec(network, profile, sampleSurfaceHeight)
	local loop = network and network.Loop
	if not loop then
		return nil
	end

	local loopSamples = loop.Samples
	local roadLift = RoadSurfaceProfile.visualSurfaceLift(profile, RoadSurfaceProfile.Kinds.Main)
	if sampleSurfaceHeight then
		loopSamples = RoadSurfaceProfile.renderSamples(
			loopSamples,
			profile,
			RoadSurfaceProfile.Kinds.Main,
			sampleSurfaceHeight
		)
		roadLift = 0
	end

	return RoadRibbonSpec.fromSamples(loop.ProfileId, loop.Seed, loopSamples, profile.RoadWidth, {
		Closed = loop.Closed ~= false,
		ChunkPrefix = "LoopChunk",
		RoadLift = roadLift,
	})
end

local function buildSecondarySpec(network, profile, sampleSurfaceHeight)
	local roads = network and network.Roads or {}
	local combined = {
		ProfileId = network and network.ProfileId or nil,
		Seed = network and network.Seed or nil,
		Width = profile.RoadWidth * WorldConstants.BranchRoadWidthScale,
		Thickness = WorldConstants.DefaultRibbonThickness,
		Closed = false,
		Chunks = {},
	}

	for _, road in ipairs(roads) do
		local roadSamples = resolveRoadSamples(road)
		if #roadSamples >= 2 then
			local renderedSamples = roadSamples
			local roadLift = RoadSurfaceProfile.visualSurfaceLift(profile, RoadSurfaceProfile.Kinds.Secondary)
			if sampleSurfaceHeight then
				renderedSamples = RoadSurfaceProfile.renderSamples(
					roadSamples,
					profile,
					RoadSurfaceProfile.Kinds.Secondary,
					sampleSurfaceHeight
				)
				roadLift = 0
			end

			local ribbonSpec = RoadRibbonSpec.fromSamples(
				network and network.ProfileId or "RoadNetwork",
				network and network.Seed or 0,
				renderedSamples,
				(road.HalfWidth or (profile.RoadWidth * WorldConstants.BranchRoadWidthScale * 0.5)) * 2,
				{
					Closed = false,
					ChunkPrefix = road.Id or "NetworkRoad",
					RoadLift = roadLift,
				}
			)
			appendChunks(combined, ribbonSpec)
		end
	end

	if #combined.Chunks == 0 then
		return nil
	end

	return combined
end

local function buildJunctionSpec(junctions, profile, sampleSurfaceHeight)
	local thickness = WorldConstants.DefaultRibbonThickness
	local spec = {
		ProfileId = profile.Id,
		Seed = 0,
		Width = 0,
		Thickness = thickness,
		Closed = false,
		Chunks = {},
	}

	for index, junction in ipairs(junctions or {}) do
		local roadKind = junction.TouchesLoop and RoadSurfaceProfile.Kinds.Main or RoadSurfaceProfile.Kinds.Secondary
		local centerY
		if sampleSurfaceHeight then
			centerY = sampleSurfaceHeight(junction.Position.X, junction.Position.Z) + RoadSurfaceProfile.visualClearance(profile, roadKind)
		else
			centerY = junction.Height + RoadSurfaceProfile.visualSurfaceLift(profile, roadKind)
		end
		spec.Chunks[#spec.Chunks + 1] = MeshShapePrimitives.discCapChunk(
			("Junction_%03d"):format(index),
			Vector3.new(junction.Position.X, centerY, junction.Position.Z),
			junction.PavedRadius,
			thickness,
			{
				SegmentCount = 24,
				Facing = GeometryDirections.Top,
			}
		)
	end

	if #spec.Chunks == 0 then
		return nil
	end

	return spec
end

local function cloneOptions(options)
	local cloned = {}
	for key, value in pairs(options or {}) do
		cloned[key] = value
	end
	return cloned
end

function RoadNetworkBuilder.build(parent, name, network, profile, options)
	local renderOptions = options or {}
	local folder = Instance.new("Folder")
	folder.Name = name or "RoadNetwork"
	folder.Parent = parent

	local junctions = RoadJunctionBuilder.build(network and network.Loop or nil, network and network.Roads or {}, profile)
	local sampleSurfaceHeight = renderOptions.SampleSurfaceHeight

	local loopSpec = buildLoopSpec(network, profile, sampleSurfaceHeight)
	if loopSpec then
		RoadRenderBuilder.build(folder, renderOptions.PrimaryName or "PrimaryRoadSurface", loopSpec, cloneOptions(renderOptions.PrimaryOptions))
	end

	local secondarySpec = buildSecondarySpec(network, profile, sampleSurfaceHeight)
	if secondarySpec then
		RoadRenderBuilder.build(folder, renderOptions.SecondaryName or "SecondaryRoadSurface", secondarySpec, cloneOptions(renderOptions.SecondaryOptions))
	end

	local junctionSpec = buildJunctionSpec(junctions, profile, sampleSurfaceHeight)
	if junctionSpec then
		RoadRenderBuilder.build(folder, renderOptions.JunctionName or "IntersectionSurface", junctionSpec, cloneOptions(renderOptions.JunctionOptions))
	end

	folder:SetAttribute("JunctionCount", #junctions)
	folder:SetAttribute("SecondaryRoadCount", #(network and network.Roads or {}))
	return folder, junctions
end

return RoadNetworkBuilder
