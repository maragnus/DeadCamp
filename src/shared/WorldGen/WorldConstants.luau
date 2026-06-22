local WorldConstants = {}

WorldConstants.BuildVersion = "WorldGen.LayeredRoad.V1"

WorldConstants.RootNames = {
	Studio = "WorldGenPreview",
	Runtime = "GeneratedWorld",
}

WorldConstants.FolderNames = {
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
	LoopDescriptor = "RoadLoopDescriptor",
	ParcelDescriptor = "POIParcelDescriptor",
	BranchDescriptor = "BranchDescriptor",
	ProfileDescriptor = "WorldProfileDescriptor",
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

WorldConstants.Phases = {
	Path = "Path",
	Terrain = "Terrain",
	POIs = "POIs",
	Branches = "Branches",
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
	WalkUp = "WalkUp",
}

WorldConstants.BranchTypes = {
	BlockedBranch = "BlockedBranch",
	DeadEndPOI = "DeadEndPOI",
	ServiceSpur = "ServiceSpur",
	FalseIntersection = "FalseIntersection",
}

WorldConstants.WorldUp = Vector3.new(0, 1, 0)
WorldConstants.TerrainResolution = 4
WorldConstants.DefaultSampleSpacing = 12
WorldConstants.DefaultRibbonThickness = 0.6
WorldConstants.DefaultRoadLift = 0.08
WorldConstants.ClientRoadLift = 0.04
WorldConstants.RoadLoopQuantizationScale = 4
WorldConstants.MaxRoadChunkSize = 128
WorldConstants.TargetRoadChunkLength = 96
WorldConstants.BranchRoadWidthScale = 0.78
WorldConstants.POISpacingVariance = 0.5

WorldConstants.ParcelFootprints = {
	[WorldConstants.SizeClasses.Small] = Vector2.new(64, 64),
	[WorldConstants.SizeClasses.Medium] = Vector2.new(128, 128),
	[WorldConstants.SizeClasses.Large] = Vector2.new(256, 256),
}

WorldConstants.ParcelReservePadding = {
	[WorldConstants.AccessTypes.DriveUp] = Vector2.new(52, 32),
	[WorldConstants.AccessTypes.WalkUp] = Vector2.new(28, 22),
}

return WorldConstants
