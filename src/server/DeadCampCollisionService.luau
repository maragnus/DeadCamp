local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DeadCampCollisionGroups = require(Shared:WaitForChild("DeadCampCollisionGroups"))

local DeadCampCollisionService = {}

local function registeredGroupNames()
	local names = {}

	for _, descriptor in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
		names[descriptor.name or descriptor.Name] = true
	end

	return names
end

local function ensureRegisteredGroups()
	local names = registeredGroupNames()

	for _, groupName in ipairs(DeadCampCollisionGroups.RegisteredGroups) do
		if not names[groupName] then
			PhysicsService:RegisterCollisionGroup(groupName)
			names[groupName] = true
		end
	end
end

local function configureProbeMatrix()
	local groups = DeadCampCollisionGroups.Groups
	local probePairs = {
		{ groups.RVGroundProbe, groups.Default, false },
		{ groups.RVGroundProbe, groups.DrivingSurface, true },
		{ groups.RVGroundProbe, groups.Structure, false },
		{ groups.RVGroundProbe, groups.RVGroundProbe, false },
		{ groups.RVGroundProbe, groups.RVBarrierProbe, false },
		{ groups.RVBarrierProbe, groups.Default, false },
		{ groups.RVBarrierProbe, groups.DrivingSurface, true },
		{ groups.RVBarrierProbe, groups.Structure, true },
		{ groups.RVBarrierProbe, groups.RVBarrierProbe, false },
	}

	for _, pair in ipairs(probePairs) do
		PhysicsService:CollisionGroupSetCollidable(pair[1], pair[2], pair[3])
	end
end

function DeadCampCollisionService.ensureConfigured()
	ensureRegisteredGroups()
	configureProbeMatrix()
	Workspace.Terrain.CollisionGroup = DeadCampCollisionGroups.Groups.DrivingSurface
end

function DeadCampCollisionService.applyGroup(root, groupName)
	if not root then
		return nil
	end

	DeadCampCollisionService.ensureConfigured()

	if root:IsA("BasePart") then
		root.CollisionGroup = groupName
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = groupName
		end
	end

	return root
end

return DeadCampCollisionService
