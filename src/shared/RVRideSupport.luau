-- Shared helpers for detecting when a humanoid is standing on a drivable RV.

local Workspace = game:GetService("Workspace")

local RVRideSupport = {}

RVRideSupport.SupportRayLength = 6.5
RVRideSupport.SupportRoles = {
	WalkableFloor = true,
	WheelBoxInterior = true,
}

local function filteredInstances(character, extra)
	local excluded = { character }

	for _, instance in ipairs(extra or {}) do
		excluded[#excluded + 1] = instance
	end

	return excluded
end

function RVRideSupport.findRVModel(instance)
	local current = instance

	while current do
		if current:IsA("Model")
			and current:GetAttribute("DriveModel") ~= nil
			and current:GetAttribute("DriveRootName") ~= nil
		then
			return current
		end

		current = current.Parent
	end

	return nil
end

function RVRideSupport.findDriveRoot(rv)
	if not rv or not rv:IsA("Model") then
		return nil
	end

	local driveRootName = rv:GetAttribute("DriveRootName") or "DriveRoot"
	local driveRoot = rv:FindFirstChild(driveRootName)
	if driveRoot and driveRoot:IsA("BasePart") then
		return driveRoot
	end

	return nil
end

function RVRideSupport.isSupportedRole(part)
	if not part then
		return false
	end

	local role = part:GetAttribute("PartRole")
	return role ~= nil and RVRideSupport.SupportRoles[role] == true
end

function RVRideSupport.supportingRV(character, rootPart, options)
	if not character or not rootPart then
		return nil
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = filteredInstances(character, options and options.Exclude)

	local result = Workspace:Raycast(
		rootPart.Position + Vector3.new(0, 0.25, 0),
		Vector3.new(0, -(options and options.RayLength or RVRideSupport.SupportRayLength), 0),
		raycastParams
	)

	if not (result and result.Instance and RVRideSupport.isSupportedRole(result.Instance)) then
		return nil
	end

	local rv = RVRideSupport.findRVModel(result.Instance)
	if not rv then
		return nil
	end

	local driveRoot = RVRideSupport.findDriveRoot(rv)
	if not driveRoot then
		return nil
	end

	return {
		RV = rv,
		DriveRoot = driveRoot,
		SupportPart = result.Instance,
		RaycastResult = result,
	}
end

return RVRideSupport
