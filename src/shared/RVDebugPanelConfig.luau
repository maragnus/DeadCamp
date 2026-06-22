local Config = {}

Config.RemoteFolderName = "DeadCampDebug"
Config.RemoteEventName = "RVDebugCommand"

Config.ActionKinds = {
	Spawn = "Spawn",
	Drive = "Drive",
	World = "World",
}

Config.DefaultSpawnActionId = "SpawnLongClassC"
Config.DefaultDriveActionId = "StopRV"
Config.DefaultWorldProfileId = "RuralTwoLane2048"
Config.DefaultWorldSeed = 7402048

Config.Actions = {
	SpawnSimpleClassC = {
		Id = "SpawnSimpleClassC",
		Kind = Config.ActionKinds.Spawn,
		Label = "Spawn Simple Class-C",
		PlanFactory = "classCSimple",
	},
	SpawnLongClassC = {
		Id = "SpawnLongClassC",
		Kind = Config.ActionKinds.Spawn,
		Label = "Spawn Long Class-C",
		PlanFactory = "classC",
	},
	StopRV = {
		Id = "StopRV",
		Kind = Config.ActionKinds.Drive,
		Label = "Stop RV",
		Throttle = 0,
		Steer = 0,
		ImmediateStop = true,
	},
	DriveForward = {
		Id = "DriveForward",
		Kind = Config.ActionKinds.Drive,
		Label = "Drive Forward",
		Throttle = 1,
		Steer = 0,
	},
	DriveCircle = {
		Id = "DriveCircle",
		Kind = Config.ActionKinds.Drive,
		Label = "Drive In Circle",
		Throttle = 1,
		Steer = 0.72,
	},
	GenerateWorldPhase1 = {
		Id = "GenerateWorldPhase1",
		Kind = Config.ActionKinds.World,
		Label = "Generate Path",
		WorldPhase = "Path",
		ProfileId = Config.DefaultWorldProfileId,
		Seed = Config.DefaultWorldSeed,
	},
	GenerateTerrain = {
		Id = "GenerateTerrain",
		Kind = Config.ActionKinds.World,
		Label = "Generate Terrain",
		WorldPhase = "Terrain",
		ProfileId = Config.DefaultWorldProfileId,
		Seed = Config.DefaultWorldSeed,
	},
	GeneratePOIParcels = {
		Id = "GeneratePOIParcels",
		Kind = Config.ActionKinds.World,
		Label = "Generate POIs",
		WorldPhase = "POIs",
		ProfileId = Config.DefaultWorldProfileId,
		Seed = Config.DefaultWorldSeed,
	},
	GenerateBranches = {
		Id = "GenerateBranches",
		Kind = Config.ActionKinds.World,
		Label = "Generate Branches",
		WorldPhase = "Branches",
		ProfileId = Config.DefaultWorldProfileId,
		Seed = Config.DefaultWorldSeed,
	},
	GenerateWorldAll = {
		Id = "GenerateWorldAll",
		Kind = Config.ActionKinds.World,
		Label = "Generate World All",
		WorldPhase = "All",
		ProfileId = Config.DefaultWorldProfileId,
		Seed = Config.DefaultWorldSeed,
	},
	DestroyWorld = {
		Id = "DestroyWorld",
		Kind = Config.ActionKinds.World,
		Label = "Destroy World",
		DestroyOnly = true,
	},
}

Config.Sections = {
	{
		Title = "Spawn",
		ActionIds = {
			"SpawnSimpleClassC",
			"SpawnLongClassC",
		},
	},
	{
		Title = "Drive",
		ActionIds = {
			"StopRV",
			"DriveForward",
			"DriveCircle",
		},
	},
	{
		Title = "World",
		ActionIds = {
			"GenerateWorldPhase1",
			"GenerateTerrain",
			"GeneratePOIParcels",
			"GenerateBranches",
			"GenerateWorldAll",
			"DestroyWorld",
		},
	},
}

function Config.action(actionId)
	return Config.Actions[actionId]
end

function Config.orderedActions()
	local ordered = {}

	for _, section in ipairs(Config.Sections) do
		for _, actionId in ipairs(section.ActionIds) do
			local action = Config.Actions[actionId]
			if action then
				ordered[#ordered + 1] = action
			end
		end
	end

	return ordered
end

return Config
