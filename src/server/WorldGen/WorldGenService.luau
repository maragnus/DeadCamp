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
local RoadNetworkBuilder = require(WorldGenShared:WaitForChild("RoadNetworkBuilder"))
local WorldConstants = require(WorldGenShared:WaitForChild("WorldConstants"))
local WorldProfile = require(WorldGenShared:WaitForChild("WorldProfile"))
local WorldSeed = require(WorldGenShared:WaitForChild("WorldSeed"))
local WorldSerialization = require(WorldGenShared:WaitForChild("WorldSerialization"))
local WorldTerrainMasks = require(WorldGenShared:WaitForChild("WorldTerrainMasks"))

local DeadCampCollisionService = require(script.Parent.Parent:WaitForChild("DeadCampCollisionService"))
local FailedLoopPreviewBuilder = require(script.Parent:WaitForChild("FailedLoopPreviewBuilder"))
local LandformPreviewBuilder = require(script.Parent:WaitForChild("LandformPreviewBuilder"))
local POIPreviewBuilder = require(script.Parent:WaitForChild("POIPreviewBuilder"))
local TerrainBuilder = require(script.Parent:WaitForChild("TerrainBuilder"))
local WorldGenAudit = require(script.Parent:WaitForChild("WorldGenAudit"))
local WorldPlacement = require(script.Parent:WaitForChild("WorldPlacement"))

local WorldGenService = {}

local FRAME_BUDGET_SECONDS = 1 / 240
local MAX_STRING_VALUE_LENGTH = 200000

local phaseOrder = {
	[WorldConstants.Phases.LandIntent] = 1,
	[WorldConstants.Phases.Path] = 2,
	[WorldConstants.Phases.POIs] = 3,
	[WorldConstants.Phases.Branches] = 4,
	[WorldConstants.Phases.Terrain] = 5,
	[WorldConstants.Phases.Hooks] = 6,
	[WorldConstants.Phases.All] = 6,
}

local loadingPhaseProgress = {
	[WorldConstants.Phases.LandIntent] = 0.08,
	[WorldConstants.Phases.Path] = 0.28,
	Branches = 0.44,
	[WorldConstants.Phases.POIs] = 0.58,
	[WorldConstants.Phases.Terrain] = 0.64,
	[WorldConstants.Phases.Hooks] = 0.96,
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
	ActiveJob = nil,
}

local function phaseAtLeast(selectedPhase, expectedPhase)
	return (phaseOrder[selectedPhase] or 0) >= (phaseOrder[expectedPhase] or 0)
end

local function rootName()
	return RunService:IsStudio() and WorldConstants.RootNames.Studio or WorldConstants.RootNames.Runtime
end

local function shouldPublishClientRoadOverlay()
	return RunService:IsStudio()
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

local function ensureStatusFolder()
	local folder = ReplicatedStorage:FindFirstChild(WorldConstants.NetworkNames.Status)
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = WorldConstants.NetworkNames.Status
		folder.Parent = ReplicatedStorage
	end

	return folder
end

local function syncStatusWithCurrentWorld()
	local folder = ensureStatusFolder()
	local hasWorld = state.CurrentRoot ~= nil and state.CurrentRoot.Parent ~= nil
	local completedPhase = hasWorld and state.CurrentRoot:GetAttribute(WorldConstants.Attributes.PhaseCompleted) or nil

	folder:SetAttribute(WorldConstants.LoadingAttributes.HasWorld, hasWorld)
	folder:SetAttribute(WorldConstants.Attributes.ProfileId, state.CurrentProfile and state.CurrentProfile.Id or nil)
	folder:SetAttribute(WorldConstants.Attributes.Seed, state.CurrentSeedInfo and state.CurrentSeedInfo.Seed or nil)
	folder:SetAttribute(WorldConstants.Attributes.PhaseCompleted, completedPhase)
end

local function setLoadingStatus(isLoading, phaseId, progress, errorMessage)
	local folder = ensureStatusFolder()
	folder:SetAttribute(WorldConstants.LoadingAttributes.IsLoading, isLoading)
	folder:SetAttribute(WorldConstants.LoadingAttributes.Phase, phaseId)
	folder:SetAttribute(WorldConstants.LoadingAttributes.Progress, progress)
	folder:SetAttribute(WorldConstants.LoadingAttributes.Error, errorMessage)
end

local function logJobPhase(job, phaseId, progress)
	if job.LastLoggedPhase == phaseId then
		return
	end

	job.LastLoggedPhase = phaseId
	local progressPercent = math.floor(((progress or 0) * 100) + 0.5)
	local profileId = job.Data and job.Data.Profile and job.Data.Profile.Id or "unknown"
	local seed = job.Data and job.Data.SeedInfo and job.Data.SeedInfo.Seed or "unknown"
	print(("WorldGenService %s for profile %s seed %s (%d%%)"):format(
		tostring(phaseId),
		tostring(profileId),
		tostring(seed),
		progressPercent
	))
end

local function upsertStringValue(parent, name, value)
	if type(value) == "string" and #value >= MAX_STRING_VALUE_LENGTH then
		error(
			("WorldGenService refused to write %s StringValue payload length %d; replicated descriptors must stay below %d characters")
				:format(name, #value, MAX_STRING_VALUE_LENGTH),
			0
		)
	end

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

local function createRoot(profile, seedInfo, parent)
	local root = Instance.new("Folder")
	root.Name = rootName()
	root.Parent = parent
	root:SetAttribute(WorldConstants.Attributes.ProfileId, profile.Id)
	root:SetAttribute(WorldConstants.Attributes.Seed, seedInfo.Seed)
	root:SetAttribute(WorldConstants.Attributes.BuildVersion, WorldConstants.BuildVersion)
	root:SetAttribute(WorldConstants.Attributes.ClientRoadOverlay, shouldPublishClientRoadOverlay())

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

	upsertStringValue(folders.Debug, WorldConstants.ValueNames.ProfileDescriptor, WorldSerialization.encodeProfileDescriptor({
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
	syncStatusWithCurrentWorld()
end

local function clearCurrentWorld()
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
	clearCurrentWorld()
	local root, folders = createRoot(profile, seedInfo, Workspace)

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

local function createBuildData(options, selectedPhase)
	DeadCampCollisionService.ensureConfigured()

	local profile = WorldProfile.resolve(options and options.ProfileId or WorldProfile.defaultId(), options and options.ProfileOverrides)
	local seedInfo = WorldSeed.resolve(options, profile.Id)
	local landformDescriptor = LandformPlanner.generate(profile, seedInfo.Seed)
	local terrainContext = TerrainBuilder.createContext(profile, seedInfo.Seed, landformDescriptor)

	return {
		SelectedPhase = selectedPhase,
		Profile = profile,
		SeedInfo = seedInfo,
		Landform = landformDescriptor,
		TerrainContext = terrainContext,
		Loop = nil,
		Masks = nil,
		RoadNetworkDescriptor = nil,
		RenderNetwork = nil,
		Parcels = {},
		Branches = {},
		POIRejects = {},
		BranchRejects = {},
		Audit = nil,
		StartMarker = nil,
		Root = nil,
	}
end

local function runPathPhase(data)
	if not phaseAtLeast(data.SelectedPhase, WorldConstants.Phases.Path) then
		return
	end

	local ok, loopOrError = pcall(function()
		return RoadLoop.generate(data.Profile, data.SeedInfo.Seed, {
			SampleHeight = function(x, z)
				return data.TerrainContext:sampleBaseHeight(x, z)
			end,
			SampleLandContext = function(x, z)
				return data.TerrainContext:sampleLandContext(x, z)
			end,
		})
	end)
	if not ok then
		local failureReport = RoadLoop.latestFailure()
		if failureReport then
			buildFailurePreviewRoot(data.Profile, data.SeedInfo, failureReport, data.Landform, data.TerrainContext)
		end
		error(loopOrError, 0)
	end

	data.Loop = loopOrError
	data.Masks = WorldTerrainMasks.build(data.Loop, data.Profile)
	data.TerrainContext:setRoadLoop(data.Loop, data.Masks)
end

local function runBranchPhase(data)
	if not phaseAtLeast(data.SelectedPhase, WorldConstants.Phases.POIs) or not data.Loop then
		return
	end

	data.Branches = BranchPlanner.plan(data.Loop, data.Profile, {
		SampleHeight = function(x, z)
			return data.TerrainContext:sampleBaseHeight(x, z)
		end,
		Seed = data.SeedInfo.Seed,
		LandformRuntime = data.TerrainContext.LandformRuntime,
		DebugRejects = data.BranchRejects,
	})
end

local function refreshRoadNetworkData(data)
	if not data.Loop then
		data.RoadNetworkDescriptor = nil
		data.RenderNetwork = nil
		return
	end

	if shouldPublishClientRoadOverlay() then
		data.RoadNetworkDescriptor = WorldSerialization.encodeRoadNetwork(data.Loop, data.Branches, {
			RoadWidth = data.Profile.RoadWidth,
		})
	else
		data.RoadNetworkDescriptor = nil
	end
	data.RenderNetwork = WorldSerialization.buildRoadNetwork(data.Loop, data.Branches)
end

local function runPOIPhase(data)
	if not phaseAtLeast(data.SelectedPhase, WorldConstants.Phases.POIs) or not data.Loop or not data.Masks then
		return
	end

	data.Parcels = POIParcelPlanner.plan(data.Loop, data.Profile, data.Masks, {
		SampleHeight = function(x, z)
			return data.TerrainContext:sampleBaseHeight(x, z)
		end,
		Seed = data.SeedInfo.Seed,
		LandformRuntime = data.TerrainContext.LandformRuntime,
		Branches = data.Branches,
		DebugRejects = data.POIRejects,
	})
end

local function buildFinalRoot(data)
	clearCurrentWorld()
	local root, folders = createRoot(data.Profile, data.SeedInfo, nil)
	local auditResult = nil
	local startMarker = nil

	local ok, result = xpcall(function()
		upsertStringValue(folders.Landforms, WorldConstants.ValueNames.LandformDescriptor, WorldSerialization.encodeLandform(data.Landform))
		upsertStringValue(folders.POIs, WorldConstants.ValueNames.ParcelDescriptor, WorldSerialization.encodeParcels(data.Parcels))
		upsertStringValue(folders.Debug, "POIRejects", #data.POIRejects > 0 and table.concat(data.POIRejects, " | ") or "None")
		upsertStringValue(folders.Debug, "BranchRejects", #data.BranchRejects > 0 and table.concat(data.BranchRejects, " | ") or "None")

		if phaseAtLeast(data.SelectedPhase, WorldConstants.Phases.Path) and data.Loop and not data.RenderNetwork then
			error("WorldGenService finalize missing road-network payload after path generation", 0)
		end

		if data.RoadNetworkDescriptor then
			upsertStringValue(folders.Road, WorldConstants.ValueNames.RoadNetworkDescriptor, data.RoadNetworkDescriptor)
		end

		if data.RenderNetwork then
			local sampleSurfaceHeight = nil
			if phaseAtLeast(data.SelectedPhase, WorldConstants.Phases.Terrain) then
				sampleSurfaceHeight = function(x, z)
					return data.TerrainContext:sampleSurfaceHeight(x, z)
				end
			end

			RoadNetworkBuilder.build(folders.ServerRoad, "RoadNetwork", data.RenderNetwork, data.Profile, {
				SampleSurfaceHeight = sampleSurfaceHeight,
				PrimaryName = "RoadSurface",
				SecondaryName = "SecondaryRoadSurface",
				JunctionName = "IntersectionSurface",
				PrimaryOptions = {
					Color = Color3.fromRGB(78, 125, 84),
					CanCollide = false,
					CanQuery = true,
					CanTouch = false,
					CastShadow = false,
					CollisionGroup = DeadCampCollisionGroups.Groups.DrivingSurface,
				},
				SecondaryOptions = {
					Color = Color3.fromRGB(89, 84, 79),
					CanCollide = false,
					CanQuery = true,
					CanTouch = false,
					CastShadow = false,
					CollisionGroup = DeadCampCollisionGroups.Groups.DrivingSurface,
				},
				JunctionOptions = {
					Color = Color3.fromRGB(92, 91, 86),
					CanCollide = false,
					CanQuery = true,
					CanTouch = false,
					CastShadow = false,
					CollisionGroup = DeadCampCollisionGroups.Groups.DrivingSurface,
				},
			})
		end

		LandformPreviewBuilder.build(folders.Landforms, data.Landform, function(x, z)
			return data.TerrainContext:sampleSurfaceHeight(x, z)
		end)
		
		if phaseAtLeast(data.SelectedPhase, WorldConstants.Phases.POIs) then
			POIPreviewBuilder.build(folders.POIs, data.Parcels, function(x, z)
				return data.TerrainContext:sampleSurfaceHeight(x, z)
			end)
		end

		if phaseAtLeast(data.SelectedPhase, WorldConstants.Phases.Path) then
			startMarker = placeStartMarker(folders.Debug, data.TerrainContext:startCFrame())
			root:SetAttribute(WorldConstants.Attributes.LoopLength, data.RenderNetwork and data.RenderNetwork.Loop and data.RenderNetwork.Loop.LoopLength or 0)
			root:SetAttribute(WorldConstants.Attributes.SampleCount, data.RenderNetwork and data.RenderNetwork.Loop and #data.RenderNetwork.Loop.Samples or 0)
		end

		if phaseAtLeast(data.SelectedPhase, WorldConstants.Phases.Terrain) and data.Loop then
			auditResult = WorldGenAudit.audit({
				Root = root,
				Loop = data.Loop,
				Profile = data.Profile,
				Parcels = data.Parcels,
				Branches = data.Branches,
				TerrainContext = data.TerrainContext,
			})
			upsertStringValue(folders.Debug, WorldConstants.ValueNames.AuditSummary, auditResult.Summary)
		else
			upsertStringValue(folders.Debug, WorldConstants.ValueNames.AuditSummary, "Terrain audit not run for this phase")
		end
	end, debug.traceback)
	if not ok then
		root:Destroy()
		error(result, 0)
	end

	root.Parent = Workspace
	root:SetAttribute(WorldConstants.Attributes.PhaseCompleted, data.SelectedPhase)
	setCurrentState(root, data.Loop, data.Profile, data.SeedInfo, data.Landform, data.TerrainContext, data.Parcels, data.Branches, auditResult, startMarker)

	data.Root = root
	data.Audit = auditResult
	data.StartMarker = startMarker

	if auditResult and not auditResult.Passed then
		error(auditResult.Summary, 0)
	end
end

local function buildResult(data)
	return {
		Root = data.Root,
		Loop = data.Loop,
		Profile = data.Profile,
		SeedInfo = data.SeedInfo,
		Landform = data.Landform,
		Parcels = data.Parcels,
		Branches = data.Branches,
		Audit = data.Audit,
	}
end

local function buildPhase(options, selectedPhase)
	local data = createBuildData(options, selectedPhase)
	runPathPhase(data)
	refreshRoadNetworkData(data)
	runBranchPhase(data)
	refreshRoadNetworkData(data)
	runPOIPhase(data)
	data.TerrainContext:setLayout(data.Parcels, data.Branches)

	if phaseAtLeast(selectedPhase, WorldConstants.Phases.Terrain) then
		data.TerrainContext:apply(data.Parcels, data.Branches)
	end

	buildFinalRoot(data)
	return buildResult(data)
end

local function activeJob()
	return state.ActiveJob
end

local function disconnectJob(job)
	if job and job.Connection then
		job.Connection:Disconnect()
		job.Connection = nil
	end
end

local function finishJob(job)
	if job.Cancelled then
		return
	end

	disconnectJob(job)
	if state.ActiveJob == job then
		state.ActiveJob = nil
	end

	setLoadingStatus(false, job.SelectedPhase, 1, "")
	print(("WorldGenService completed %s for profile %s seed %s"):format(
		tostring(job.SelectedPhase),
		tostring(job.Data and job.Data.Profile and job.Data.Profile.Id or "unknown"),
		tostring(job.Data and job.Data.SeedInfo and job.Data.SeedInfo.Seed or "unknown")
	))

	if job.Callbacks and type(job.Callbacks.OnComplete) == "function" then
		job.Callbacks.OnComplete(job.Result)
	end
end

local function failJob(job, errorMessage)
	if job.Cancelled then
		return
	end

	disconnectJob(job)
	if state.ActiveJob == job then
		state.ActiveJob = nil
	end

	setLoadingStatus(false, job.StatusPhase or WorldConstants.Phases.LandIntent, job.Progress or 0, tostring(errorMessage))
	warn(("WorldGenService failed during %s for profile %s seed %s: %s"):format(
		tostring(job.StatusPhase or WorldConstants.Phases.LandIntent),
		tostring(job.Data and job.Data.Profile and job.Data.Profile.Id or "unknown"),
		tostring(job.Data and job.Data.SeedInfo and job.Data.SeedInfo.Seed or "unknown"),
		tostring(errorMessage)
	))

	if job.Callbacks and type(job.Callbacks.OnError) == "function" then
		job.Callbacks.OnError(errorMessage)
	end
end

local function updateJobStatus(job, phaseId, progress)
	if job.Cancelled then
		return
	end

	job.StatusPhase = phaseId
	job.Progress = progress
	setLoadingStatus(true, phaseId, progress, "")
	logJobPhase(job, phaseId, progress)
end

local function runFinalize(job)
	if job.Cancelled then
		return
	end

	local ok, err = pcall(function()
		updateJobStatus(job, WorldConstants.Phases.Hooks, loadingPhaseProgress[WorldConstants.Phases.Hooks])
		if job.Cancelled then
			return
		end
		buildFinalRoot(job.Data)
		if job.Cancelled then
			WorldGenService.destroyCurrent()
			return
		end
		job.Result = buildResult(job.Data)
		finishJob(job)
	end)
	if not ok then
		failJob(job, err)
	end
end

local function processJob(job)
	if job.Cancelled then
		return
	end

	local deadline = os.clock() + FRAME_BUDGET_SECONDS

	while os.clock() < deadline do
		if job.Step == "Prepare" then
			updateJobStatus(job, WorldConstants.Phases.LandIntent, loadingPhaseProgress[WorldConstants.Phases.LandIntent])
			job.Data = createBuildData(job.Options, job.SelectedPhase)
			local folder = ensureStatusFolder()
			folder:SetAttribute(WorldConstants.Attributes.ProfileId, job.Data.Profile.Id)
			folder:SetAttribute(WorldConstants.Attributes.Seed, job.Data.SeedInfo.Seed)
			job.Step = "Path"
		elseif job.Step == "Path" then
			if phaseAtLeast(job.SelectedPhase, WorldConstants.Phases.Path) then
				updateJobStatus(job, WorldConstants.Phases.Path, loadingPhaseProgress[WorldConstants.Phases.Path])
				runPathPhase(job.Data)
				refreshRoadNetworkData(job.Data)
			end
			job.Step = "Branches"
		elseif job.Step == "Branches" then
			if phaseAtLeast(job.SelectedPhase, WorldConstants.Phases.POIs) then
				updateJobStatus(job, "Branches", loadingPhaseProgress.Branches)
				runBranchPhase(job.Data)
				refreshRoadNetworkData(job.Data)
			end
			job.Step = "POIs"
		elseif job.Step == "POIs" then
			if phaseAtLeast(job.SelectedPhase, WorldConstants.Phases.POIs) then
				updateJobStatus(job, WorldConstants.Phases.POIs, loadingPhaseProgress[WorldConstants.Phases.POIs])
				runPOIPhase(job.Data)
			end
			job.Data.TerrainContext:setLayout(job.Data.Parcels, job.Data.Branches)
			job.Step = "Terrain"
		elseif job.Step == "Terrain" then
			if phaseAtLeast(job.SelectedPhase, WorldConstants.Phases.Terrain) then
				if not job.TerrainStarted then
					job.Data.TerrainContext:beginApply(job.Data.Parcels, job.Data.Branches)
					job.TerrainStarted = true
				end

				local progress = job.Data.TerrainContext:applyNextChunk()
				local alpha = progress.TotalChunks > 0 and (progress.CompletedChunks / progress.TotalChunks) or 1
				updateJobStatus(
					job,
					WorldConstants.Phases.Terrain,
					loadingPhaseProgress[WorldConstants.Phases.Terrain] + (0.28 * alpha)
				)
				if not progress.Done then
					return
				end
			end
			job.Step = "Finalize"
		elseif job.Step == "Finalize" then
			job.Step = "Finalizing"
			disconnectJob(job)
			task.defer(runFinalize, job)
			return
		elseif job.Step == "Finalizing" then
			return
		else
			error(("Unknown world generation job step %s"):format(tostring(job.Step)), 0)
		end
	end
end

local function beginGenerate(options, phaseId, callbacks)
	if activeJob() then
		error("World generation is already in progress", 2)
	end

	clearCurrentWorld()
	setLoadingStatus(true, WorldConstants.Phases.LandIntent, 0, "")

	local job = {
		Options = options,
		SelectedPhase = phaseId or WorldConstants.Phases.Path,
		Callbacks = callbacks or {},
		Step = "Prepare",
		StatusPhase = WorldConstants.Phases.LandIntent,
		Progress = 0,
		TerrainStarted = false,
		IsProcessing = false,
		Cancelled = false,
		Data = nil,
		Connection = nil,
		Result = nil,
		LastLoggedPhase = nil,
	}

	print(("WorldGenService starting %s generation job"):format(tostring(job.SelectedPhase)))
	state.ActiveJob = job
	job.Connection = RunService.Heartbeat:Connect(function()
		if job.IsProcessing then
			return
		end

		job.IsProcessing = true
		local ok, err = pcall(processJob, job)
		job.IsProcessing = false
		if not ok then
			failJob(job, err)
		end
	end)

	return job
end

function WorldGenService.destroyCurrent()
	local job = activeJob()
	if job then
		job.Cancelled = true
		disconnectJob(job)
		state.ActiveJob = nil
	end

	clearCurrentWorld()
	setLoadingStatus(false, nil, 0, "")
end

function WorldGenService.generatePhase(options, phaseId)
	if activeJob() then
		error("World generation is already in progress", 2)
	end

	local selectedPhase = phaseId or WorldConstants.Phases.Path
	local result = buildPhase(options, selectedPhase)
	setLoadingStatus(false, selectedPhase, 1, "")
	return result
end

function WorldGenService.generateAll(options)
	if activeJob() then
		error("World generation is already in progress", 2)
	end

	local result = buildPhase(options, WorldConstants.Phases.All)
	setLoadingStatus(false, WorldConstants.Phases.All, 1, "")
	return result
end

function WorldGenService.generatePhaseAsync(options, phaseId, callbacks)
	local selectedPhase = phaseId or WorldConstants.Phases.Path
	return beginGenerate(options, selectedPhase, callbacks)
end

function WorldGenService.generateAllAsync(options, callbacks)
	return beginGenerate(options, WorldConstants.Phases.All, callbacks)
end

function WorldGenService.ensureGeneratedWorld(options)
	if state.CurrentRoot and state.CurrentRoot.Parent and state.StartMarker and state.StartMarker.Parent then
		return state.CurrentRoot
	end
	if activeJob() then
		error("World generation is already in progress", 2)
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

function WorldGenService.isLoading()
	return activeJob() ~= nil
end

function WorldGenService.loadingStatus()
	return ensureStatusFolder()
end

return WorldGenService
