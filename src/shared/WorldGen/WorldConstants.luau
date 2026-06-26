local WorldConstants = {}

WorldConstants.BuildVersion = "WorldGen.FlowingRoad.V4"

WorldConstants.RootNames = {
	Studio = "WorldGenPreview",
	Runtime = "GeneratedWorld",
}

WorldConstants.NetworkNames = {
	Status = "DeadCampWorldGenStatus",
}

WorldConstants.FolderNames = {
	Landforms = "Landforms",
	Road = "Road",
	ServerRoad = "ServerRoad",
	ClientRoad = "ClientRoad",
	Terrain = "Terrain",
	POIs = "POIs",
	Branches = "Branches",
	Blockers = "Blockers",
	Debug = "Debug",
}

WorldConstants.ValueNames = {
	LandformDescriptor = "LandformDescriptor",
	RoadNetworkDescriptor = "RoadNetworkDescriptor",
	ParcelDescriptor = "POIParcelDescriptor",
	ProfileDescriptor = "WorldProfileDescriptor",
	AuditSummary = "WorldAuditSummary",
}

WorldConstants.Attributes = {
	ProfileId = "WorldProfileId",
	Seed = "WorldSeed",
	BuildVersion = "WorldBuildVersion",
	PhaseCompleted = "WorldPhaseCompleted",
	LoopLength = "RoadLoopLength",
	SampleCount = "RoadSampleCount",
	ClientRoadOverlay = "EnableClientRoadOverlay",
}

WorldConstants.LoadingAttributes = {
	IsLoading = "IsLoading",
	HasWorld = "HasWorld",
	Phase = "LoadPhase",
	Progress = "LoadProgress",
	Error = "LoadError",
}

WorldConstants.DebugFlags = {
	RoadRenderMeshDiagnostics = false,
}

WorldConstants.Phases = {
	LandIntent = "LandIntent",
	Path = "Path",
	POIs = "POIs",
	Branches = "Branches",
	Terrain = "Terrain",
	Hooks = "Hooks",
	All = "All",
}

WorldConstants.SizeClasses = {
	Small = "Small",
	Medium = "Medium",
	Large = "Large",
}

WorldConstants.AccessTypes = {
	DriveUp = "DriveUp",
	RoadEdge = "RoadEdge",
	WalkUp = "WalkUp",
}

WorldConstants.BranchTypes = {
	NetworkRoad = "NetworkRoad",
}

WorldConstants.WorldUp = Vector3.new(0, 1, 0)
WorldConstants.TerrainResolution = 4
WorldConstants.DefaultSampleSpacing = 12
WorldConstants.DefaultRibbonThickness = 0.6
WorldConstants.DefaultRoadLift = 0.08
WorldConstants.RoadLoopQuantizationScale = 4
WorldConstants.MaxRoadMeshLength = 256
WorldConstants.BranchRoadWidthScale = 0.78
WorldConstants.POISpacingVariance = 0.5

WorldConstants.ParcelFootprints = {
	[WorldConstants.SizeClasses.Small] = Vector2.new(64, 64),
	[WorldConstants.SizeClasses.Medium] = Vector2.new(128, 128),
	[WorldConstants.SizeClasses.Large] = Vector2.new(256, 256),
}

local SHOULDER_ACCESS_RESERVE_PADDING = Vector2.new(28, 22)

WorldConstants.ParcelReservePadding = {
	[WorldConstants.AccessTypes.RoadEdge] = SHOULDER_ACCESS_RESERVE_PADDING,
	[WorldConstants.AccessTypes.DriveUp] = Vector2.new(52, 32),
	[WorldConstants.AccessTypes.WalkUp] = SHOULDER_ACCESS_RESERVE_PADDING,
}

return WorldConstants
