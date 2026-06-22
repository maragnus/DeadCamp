local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DeadCampCollisionGroups = require(Shared:WaitForChild("DeadCampCollisionGroups"))
local WorldGenShared = Shared:WaitForChild("WorldGen")

local BranchPlanner = require(WorldGenShared:WaitForChild("BranchPlanner"))
local Hydrology = require(WorldGenShared:WaitForChild("Hydrology"))
local POIParcelPlanner = require(WorldGenShared:WaitForChild("POIParcelPlanner"))
local RoadLoop = require(WorldGenShared:WaitForChild("RoadLoop"))
local RoadRibbonSpec = require(WorldGenShared:WaitForChild("RoadRibbonSpec"))
local WorldConstants = require(WorldGenShared:WaitForChild("WorldConstants"))
local WorldProfile = require(WorldGenShared:WaitForChild("WorldProfile"))
local WorldSeed = require(WorldGenShared:WaitForChild("WorldSeed"))
local WorldSerialization = require(WorldGenShared:WaitForChild("WorldSerialization"))
local WorldTerrainMasks = require(WorldGenShared:WaitForChild("WorldTerrainMasks"))

local RVConstants = require(script.Parent.Parent:WaitForChild("RVBuilder"):WaitForChild("Constants"))
local DeadCampCollisionService = require(script.Parent.Parent:WaitForChild("DeadCampCollisionService"))
local BlockerDecorator = require(script.Parent:WaitForChild("BlockerDecorator"))
local BranchPreviewBuilder = require(script.Parent:WaitForChild("BranchPreviewBuilder"))
local FailedLoopPreviewBuilder = require(script.Parent:WaitForChild("FailedLoopPreviewBuilder"))
local POIPreviewBuilder = require(script.Parent:WaitForChild("POIPreviewBuilder"))
local RoadModelBuilder = require(script.Parent:WaitForChild("RoadModelBuilder"))
local TerrainBuilder = require(script.Parent:WaitForChild("TerrainBuilder"))

local WorldGenService = {}

local phaseOrder = {
	[WorldConstants.Phases.Path] = 1,
	[WorldConstants.Phases.Terrain] = 2,
	[WorldConstants.Phases.POIs] = 3,
	[WorldConstants.Phases.Branches] = 4,
	[WorldConstants.Phases.Hooks] = 5,
	[WorldConstants.Phases.All] = 5,
}

local state = {
	CurrentRoot = nil,
	CurrentLoop = nil,
	CurrentProfile = nil,
	CurrentSeedInfo = nil,
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

function WorldGenService.destroyCurrent()
	destroyRoot(Workspace:FindFirstChild(WorldConstants.RootNames.Studio))
	destroyRoot(Workspace:FindFirstChild(WorldConstants.RootNames.Runtime))
	state.CurrentRoot = nil
	state.CurrentLoop = nil
	state.CurrentProfile = nil
	state.CurrentSeedInfo = nil
	state.StartMarker = nil
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

local function buildFailurePreviewRoot(profile, seedInfo, failureReport)
	WorldGenService.destroyCurrent()
	local root, folders = createRoot(profile, seedInfo)

	FailedLoopPreviewBuilder.build(folders.Debug, failureReport)

	if failureReport and failureReport.BestAttempt then
		local attempt = failureReport.BestAttempt
		root:SetAttribute(WorldConstants.Attributes.LoopLength, attempt.LoopLength or 0)
		root:SetAttribute(WorldConstants.Attributes.SampleCount, #(attempt.Samples or {}))
	end

	state.CurrentRoot = root
	state.CurrentLoop = nil
	state.CurrentProfile = profile
	state.CurrentSeedInfo = seedInfo
	state.StartMarker = nil
	return root
end

local function buildPhase(options, selectedPhase)
	DeadCampCollisionService.ensureConfigured()

	local profile = WorldProfile.resolve(options and options.ProfileId or WorldProfile.defaultId(), options and options.ProfileOverrides)
	local seedInfo = WorldSeed.resolve(options, profile.Id)
	local ok, loopOrError = pcall(function()
		return RoadLoop.generate(profile, seedInfo.Seed)
	end)
	if not ok then
		local failureReport = RoadLoop.latestFailure()
		if failureReport then
			buildFailurePreviewRoot(profile, seedInfo, failureReport)
		end
		error(loopOrError, 0)
	end
	local loop = loopOrError
	local masks = WorldTerrainMasks.build(loop, profile)
	local terrainContext = TerrainBuilder.createContext(loop, profile, seedInfo.Seed, masks)
	local loopDescriptor = WorldSerialization.encodeRoadLoop(loop, {
		RoadWidth = profile.RoadWidth,
	})
	local renderLoop = WorldSerialization.decodeRoadLoop(loopDescriptor)
	local ribbonSpec = RoadRibbonSpec.fromLoop(renderLoop)
	local parcels = {}
	local branches = {}

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.POIs) then
		parcels = POIParcelPlanner.plan(loop, profile, masks, {
			SampleHeight = function(x, z)
				return terrainContext:sampleBaseHeight(x, z)
			end,
			Seed = seedInfo.Seed,
		})
	end

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.Branches) then
		branches = BranchPlanner.plan(loop, profile, {
			Parcels = parcels,
			SampleHeight = function(x, z)
				return terrainContext:sampleBaseHeight(x, z)
			end,
			Seed = seedInfo.Seed,
		})
	end

	WorldGenService.destroyCurrent()
	local root, folders = createRoot(profile, seedInfo)

	upsertStringValue(folders.Road, WorldConstants.ValueNames.LoopDescriptor, loopDescriptor)
	upsertStringValue(folders.POIs, WorldConstants.ValueNames.ParcelDescriptor, WorldSerialization.encodeParcels(parcels))
	upsertStringValue(folders.Branches, WorldConstants.ValueNames.BranchDescriptor, WorldSerialization.encodeBranches(branches))

	RoadModelBuilder.build(folders.ServerRoad, ribbonSpec, {
		Color = Color3.fromRGB(56, 54, 50),
		CanCollide = false,
		CanQuery = true,
		CanTouch = false,
		CastShadow = false,
		CollisionGroup = DeadCampCollisionGroups.Groups.DrivingSurface,
	})

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.Terrain) then
		terrainContext:apply(parcels, branches)
	end

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.POIs) then
		POIPreviewBuilder.build(folders.POIs, parcels)
	end

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.Branches) then
		BranchPreviewBuilder.build(folders.Branches, branches, profile.RoadWidth)
	end

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.Hooks) then
		BlockerDecorator.build(folders.Blockers, masks.ShortcutHotspots)
	end

	local startMarker = placeStartMarker(folders.Debug, terrainContext:startCFrame())
	root:SetAttribute(WorldConstants.Attributes.PhaseCompleted, selectedPhase)
	root:SetAttribute(WorldConstants.Attributes.LoopLength, renderLoop.LoopLength)
	root:SetAttribute(WorldConstants.Attributes.SampleCount, #renderLoop.Samples)

	state.CurrentRoot = root
	state.CurrentLoop = loop
	state.CurrentProfile = profile
	state.CurrentSeedInfo = seedInfo
	state.StartMarker = startMarker

	return {
		Root = root,
		Loop = loop,
		Profile = profile,
		SeedInfo = seedInfo,
		Parcels = parcels,
		Branches = branches,
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

function WorldGenService.startCFrame()
	if state.StartMarker and state.StartMarker.Parent then
		return state.StartMarker.CFrame
	end

	return nil
end

function WorldGenService.placeRVAtStart(rv)
	local startCFrame = WorldGenService.startCFrame()
	if not startCFrame then
		return false
	end

	local scale = rv:GetAttribute("Scale") or RVConstants.DefaultScale
	local dimensions = RVConstants.dimensions(scale)
	local pivotPosition = startCFrame.Position + Vector3.new(0, dimensions.ChassisY, 0)
	local targetCFrame = CFrame.lookAt(pivotPosition, pivotPosition + startCFrame.LookVector, Vector3.yAxis)
	rv:PivotTo(targetCFrame)
	return true
end

return WorldGenService
