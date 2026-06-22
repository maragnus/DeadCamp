local DeadCampCollisionGroups = {}

DeadCampCollisionGroups.Groups = {
	Default = "Default",
	DrivingSurface = "DrivingSurface",
	Structure = "Structure",
	RVGroundProbe = "RVGroundProbe",
	RVBarrierProbe = "RVBarrierProbe",
}

DeadCampCollisionGroups.RegisteredGroups = {
	DeadCampCollisionGroups.Groups.DrivingSurface,
	DeadCampCollisionGroups.Groups.Structure,
	DeadCampCollisionGroups.Groups.RVGroundProbe,
	DeadCampCollisionGroups.Groups.RVBarrierProbe,
}

return DeadCampCollisionGroups
