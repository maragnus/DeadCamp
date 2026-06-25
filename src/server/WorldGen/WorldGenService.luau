local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DeadCampCollisionGroups = require(Shared:WaitForChild("DeadCampCollisionGroups"))
local WorldGenShared = Shared:WaitForChild("WorldGen")

local BranchPlanner = require(WorldGenShared:WaitForChild("BranchPlanner"))
local Hydrology = require(WorldGenShared:WaitForChild("Hydrology"))
local LandformPlanner = require(WorldGenShared:WaitForChild("LandformPlanner"))
local POIParcelPlanner = require(WorldGenShared:WaitForChild("POIParcelPlanner"))
local RoadLoop = require(WorldGenShared:WaitForChild("RoadLoop"))
local RoadRibbonSpec = require(WorldGenShared:WaitForChild("RoadRibbonSpec"))
local WorldConstants = require(WorldGenShared:WaitForChild("WorldConstants"))
local WorldProfile = require(WorldGenShared:WaitForChild("WorldProfile"))
local WorldSeed = require(WorldGenShared:WaitForChild("WorldSeed"))
local WorldSerialization = require(WorldGenShared:WaitForChild("WorldSerialization"))
local WorldTerrainMasks = require(WorldGenShared:WaitForChild("WorldTerrainMasks"))

local DeadCampCollisionService = require(script.Parent.Parent:WaitForChild("DeadCampCollisionService"))
local BranchPreviewBuilder = require(script.Parent:WaitForChild("BranchPreviewBuilder"))
local FailedLoopPreviewBuilder = require(script.Parent:WaitForChild("FailedLoopPreviewBuilder"))
local LandformPreviewBuilder = require(script.Parent:WaitForChild("LandformPreviewBuilder"))
local POIPreviewBuilder = require(script.Parent:WaitForChild("POIPreviewBuilder"))
local RoadModelBuilder = require(script.Parent:WaitForChild("RoadModelBuilder"))
local TerrainBuilder = require(script.Parent:WaitForChild("TerrainBuilder"))
local WorldGenAudit = require(script.Parent:WaitForChild("WorldGenAudit"))
local WorldPlacement = require(script.Parent:WaitForChild("WorldPlacement"))

local WorldGenService = {}

local phaseOrder = {
	[WorldConstants.Phases.LandIntent] = 1,
	[WorldConstants.Phases.Path] = 2,
	[WorldConstants.Phases.POIs] = 3,
	[WorldConstants.Phases.Branches] = 4,
	[WorldConstants.Phases.Terrain] = 5,
	[WorldConstants.Phases.Hooks] = 6,
	[WorldConstants.Phases.All] = 6,
}

local state = {
	CurrentRoot = nil,
	CurrentLoop = nil,
	CurrentProfile = nil,
	CurrentSeedInfo = nil,
	CurrentLandform = nil,
	CurrentTerrainContext = nil,
	CurrentParcels = {},
	CurrentBranches = {},
	CurrentAudit = nil,
	StartMarker = nil,
}

local function phaseAtLeast(selectedPhase, expectedPhase)
	return (phaseOrder[selectedPhase] or 0) >= (phaseOrder[expectedPhase] or 0)
end

local function rootName()
	return RunService:IsStudio() and WorldConstants.RootNames.Studio or WorldConstants.RootNames.Runtime
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function upsertStringValue(parent, name, value)
	local stringValue = parent:FindFirstChild(name)
	if stringValue and not stringValue:IsA("StringValue") then
		stringValue:Destroy()
		stringValue = nil
	end

	if stringValue then
		stringValue.Value = value
		return stringValue
	end

	stringValue = Instance.new("StringValue")
	stringValue.Name = name
	stringValue.Value = value
	stringValue.Parent = parent
	return stringValue
end

local function createRoot(profile, seedInfo)
	local root = Instance.new("Folder")
	root.Name = rootName()
	root.Parent = Workspace
	root:SetAttribute(WorldConstants.Attributes.ProfileId, profile.Id)
	root:SetAttribute(WorldConstants.Attributes.Seed, seedInfo.Seed)
	root:SetAttribute(WorldConstants.Attributes.BuildVersion, WorldConstants.BuildVersion)
	root:SetAttribute(WorldConstants.Attributes.ClientRoadOverlay, RunService:IsStudio())

	local folders = {
		Landforms = ensureFolder(root, WorldConstants.FolderNames.Landforms),
		Road = ensureFolder(root, WorldConstants.FolderNames.Road),
		ServerRoad = ensureFolder(root, WorldConstants.FolderNames.ServerRoad),
		Terrain = ensureFolder(root, WorldConstants.FolderNames.Terrain),
		POIs = ensureFolder(root, WorldConstants.FolderNames.POIs),
		Branches = ensureFolder(root, WorldConstants.FolderNames.Branches),
		Blockers = ensureFolder(root, WorldConstants.FolderNames.Blockers),
		Debug = ensureFolder(root, WorldConstants.FolderNames.Debug),
	}

	upsertStringValue(folders.Debug, WorldConstants.ValueNames.ProfileDescriptor, WorldSerialization.encodeBranches({
		ProfileId = profile.Id,
		Seed = seedInfo.Seed,
		Hydrology = Hydrology.describeReservationHooks(),
	}))

	return root, folders
end

local function destroyRoot(root)
	if root and root.Parent then
		root:Destroy()
	end
end

local function setCurrentState(root, loop, profile, seedInfo, landform, terrainContext, parcels, branches, audit, startMarker)
	state.CurrentRoot = root
	state.CurrentLoop = loop
	state.CurrentProfile = profile
	state.CurrentSeedInfo = seedInfo
	state.CurrentLandform = landform
	state.CurrentTerrainContext = terrainContext
	state.CurrentParcels = parcels or {}
	state.CurrentBranches = branches or {}
	state.CurrentAudit = audit
	state.StartMarker = startMarker
end

function WorldGenService.destroyCurrent()
	destroyRoot(Workspace:FindFirstChild(WorldConstants.RootNames.Studio))
	destroyRoot(Workspace:FindFirstChild(WorldConstants.RootNames.Runtime))
	WorldPlacement.deactivate(nil)
	setCurrentState(nil, nil, nil, nil, nil, nil, {}, {}, nil, nil)
end

local function placeStartMarker(parent, startCFrame)
	local marker = Instance.new("Part")
	marker.Name = "WorldStartMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(6, 1, 12)
	marker.CFrame = startCFrame + Vector3.new(0, 0.5, 0)
	marker.Parent = parent
	return marker
end

local function buildFailurePreviewRoot(profile, seedInfo, failureReport, landformDescriptor, terrainContext)
	WorldGenService.destroyCurrent()
	local root, folders = createRoot(profile, seedInfo)

	upsertStringValue(folders.Landforms, WorldConstants.ValueNames.LandformDescriptor, WorldSerialization.encodeLandform(landformDescriptor))
	LandformPreviewBuilder.build(folders.Landforms, landformDescriptor, function(x, z)
		return terrainContext:sampleBaseHeight(x, z)
	end)
	FailedLoopPreviewBuilder.build(folders.Debug, failureReport)

	if failureReport and failureReport.BestAttempt then
		local attempt = failureReport.BestAttempt
		root:SetAttribute(WorldConstants.Attributes.LoopLength, attempt.LoopLength or 0)
		root:SetAttribute(WorldConstants.Attributes.SampleCount, #(attempt.Samples or {}))
	end

	setCurrentState(root, nil, profile, seedInfo, landformDescriptor, terrainContext, {}, {}, nil, nil)
	return root
end

local function buildPhase(options, selectedPhase)
	DeadCampCollisionService.ensureConfigured()

	local profile = WorldProfile.resolve(options and options.ProfileId or WorldProfile.defaultId(), options and options.ProfileOverrides)
	local seedInfo = WorldSeed.resolve(options, profile.Id)
	local landformDescriptor = LandformPlanner.generate(profile, seedInfo.Seed)
	local terrainContext = TerrainBuilder.createContext(profile, seedInfo.Seed, landformDescriptor)
	local loop = nil
	local masks = nil
	local loopDescriptor = nil
	local renderLoop = nil
	local ribbonSpec = nil
	local parcels = {}
	local branches = {}
	local poiRejects = {}
	local branchRejects = {}

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.Path) then
		local ok, loopOrError = pcall(function()
			return RoadLoop.generate(profile, seedInfo.Seed, {
				SampleHeight = function(x, z)
					return terrainContext:sampleBaseHeight(x, z)
				end,
				SampleLandContext = function(x, z)
					return terrainContext:sampleLandContext(x, z)
				end,
			})
		end)
		if not ok then
			local failureReport = RoadLoop.latestFailure()
			if failureReport then
				buildFailurePreviewRoot(profile, seedInfo, failureReport, landformDescriptor, terrainContext)
			end
			error(loopOrError, 0)
		end

		loop = loopOrError
		masks = WorldTerrainMasks.build(loop, profile)
		terrainContext:setRoadLoop(loop, masks)
		loopDescriptor = WorldSerialization.encodeRoadLoop(loop, {
			RoadWidth = profile.RoadWidth,
		})
		renderLoop = WorldSerialization.decodeRoadLoop(loopDescriptor)
		ribbonSpec = RoadRibbonSpec.fromLoop(renderLoop)
	end

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.POIs) and loop and masks then
		parcels = POIParcelPlanner.plan(loop, profile, masks, {
			SampleHeight = function(x, z)
				return terrainContext:sampleBaseHeight(x, z)
			end,
			Seed = seedInfo.Seed,
			LandformRuntime = terrainContext.LandformRuntime,
			DebugRejects = poiRejects,
		})
	end

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.Branches) and loop then
		branches = BranchPlanner.plan(loop, profile, {
			Parcels = parcels,
			SampleHeight = function(x, z)
				return terrainContext:sampleBaseHeight(x, z)
			end,
			Seed = seedInfo.Seed,
			LandformRuntime = terrainContext.LandformRuntime,
			DebugRejects = branchRejects,
		})
	end

	terrainContext:setLayout(parcels, branches)

	WorldGenService.destroyCurrent()
	local root, folders = createRoot(profile, seedInfo)
	local auditResult = nil
	local startMarker = nil

	upsertStringValue(folders.Landforms, WorldConstants.ValueNames.LandformDescriptor, WorldSerialization.encodeLandform(landformDescriptor))
	upsertStringValue(folders.POIs, WorldConstants.ValueNames.ParcelDescriptor, WorldSerialization.encodeParcels(parcels))
	upsertStringValue(folders.Branches, WorldConstants.ValueNames.BranchDescriptor, WorldSerialization.encodeBranches(branches))
	upsertStringValue(folders.Debug, "POIRejects", #poiRejects > 0 and table.concat(poiRejects, " | ") or "None")
	upsertStringValue(folders.Debug, "BranchRejects", #branchRejects > 0 and table.concat(branchRejects, " | ") or "None")

	if loopDescriptor then
		upsertStringValue(folders.Road, WorldConstants.ValueNames.LoopDescriptor, loopDescriptor)
	end

	if ribbonSpec then
		RoadModelBuilder.build(folders.ServerRoad, ribbonSpec, {
			Color = Color3.fromRGB(56, 54, 50),
			CanCollide = false,
			CanQuery = true,
			CanTouch = false,
			CastShadow = false,
			CollisionGroup = DeadCampCollisionGroups.Groups.DrivingSurface,
		})
	end

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.Terrain) then
		terrainContext:apply(parcels, branches)
	end

	LandformPreviewBuilder.build(folders.Landforms, landformDescriptor, function(x, z)
		return terrainContext:sampleSurfaceHeight(x, z)
	end)

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.POIs) then
		POIPreviewBuilder.build(folders.POIs, parcels, function(x, z)
			return terrainContext:sampleSurfaceHeight(x, z)
		end)
	end

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.Branches) then
		BranchPreviewBuilder.build(folders.Branches, branches, profile.RoadWidth)
	end

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.Path) then
		startMarker = placeStartMarker(folders.Debug, terrainContext:startCFrame())
		root:SetAttribute(WorldConstants.Attributes.LoopLength, renderLoop.LoopLength)
		root:SetAttribute(WorldConstants.Attributes.SampleCount, #renderLoop.Samples)
	end

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.Terrain) and loop then
		auditResult = WorldGenAudit.audit({
			Root = root,
			Loop = loop,
			Profile = profile,
			Parcels = parcels,
			Branches = branches,
			TerrainContext = terrainContext,
		})
		upsertStringValue(folders.Debug, WorldConstants.ValueNames.AuditSummary, auditResult.Summary)
	else
		upsertStringValue(folders.Debug, WorldConstants.ValueNames.AuditSummary, "Terrain audit not run for this phase")
	end

	root:SetAttribute(WorldConstants.Attributes.PhaseCompleted, selectedPhase)
	setCurrentState(root, loop, profile, seedInfo, landformDescriptor, terrainContext, parcels, branches, auditResult, startMarker)

	if auditResult and not auditResult.Passed then
		error(auditResult.Summary, 0)
	end

	return {
		Root = root,
		Loop = loop,
		Profile = profile,
		SeedInfo = seedInfo,
		Landform = landformDescriptor,
		Parcels = parcels,
		Branches = branches,
		Audit = auditResult,
	}
end

function WorldGenService.generatePhase(options, phaseId)
	local selectedPhase = phaseId or WorldConstants.Phases.Path
	return buildPhase(options, selectedPhase)
end

function WorldGenService.generateAll(options)
	return buildPhase(options, WorldConstants.Phases.All)
end

function WorldGenService.ensureGeneratedWorld(options)
	if state.CurrentRoot and state.CurrentRoot.Parent and state.StartMarker and state.StartMarker.Parent then
		return state.CurrentRoot
	end

	return WorldGenService.generateAll(options).Root
end

function WorldGenService.currentRoot()
	return state.CurrentRoot
end

function WorldGenService.currentTerrainContext()
	return state.CurrentTerrainContext
end

function WorldGenService.surfaceHeightAt(x, z)
	if state.CurrentTerrainContext then
		return state.CurrentTerrainContext:sampleSurfaceHeight(x, z)
	end
	return 0
end

function WorldGenService.startCFrame()
	if state.StartMarker and state.StartMarker.Parent then
		return state.StartMarker.CFrame
	end

	return nil
end

function WorldGenService.placeRVAtStart(rv)
	return WorldPlacement.placeRVAtStart(rv, WorldGenService.startCFrame())
end

return WorldGenService
