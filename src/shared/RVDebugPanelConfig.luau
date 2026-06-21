local Config = {}

Config.RemoteFolderName = "DeadCampDebug"
Config.RemoteEventName = "RVDebugCommand"

Config.ActionKinds = {
	Spawn = "Spawn",
	Drive = "Drive",
}

Config.DefaultSpawnActionId = "SpawnLongClassC"
Config.DefaultDriveActionId = "StopRV"

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
