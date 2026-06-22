-- Shared terrain fit and underside-clearance helpers for drivable RVs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(script.Parent:WaitForChild("Constants"))
local DeadCampCollisionService = require(script.Parent.Parent:WaitForChild("DeadCampCollisionService"))
local WheelGroups = require(script.Parent:WaitForChild("WheelGroups"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DeadCampCollisionGroups = require(Shared:WaitForChild("DeadCampCollisionGroups"))

local RVGrounding = {}

local WORLD_UP = Vector3.new(0, 1, 0)
local EPSILON = 0.001

local function horizontalUnit(vector, fallback)
	local flattened = Vector3.new(vector.X, 0, vector.Z)
	if flattened.Magnitude <= EPSILON then
		return fallback or Vector3.new(0, 0, -1)
	end

	return flattened.Unit
end

local function averageVector(vectors, fallback)
	local sum = Vector3.zero
	for _, vector in ipairs(vectors) do
		sum += vector
	end

	if sum.Magnitude <= EPSILON then
		return fallback
	end

	return sum.Unit
end

local function tiltDegreesFromUp(upVector)
	return math.deg(math.acos(math.clamp(upVector:Dot(WORLD_UP), -1, 1)))
end

local function buildRaycastParams(rv, collisionGroup)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rv }
	params.CollisionGroup = collisionGroup
	return params
end

local function readNumberAttribute(instance, name, defaultValue)
	local value = instance and instance:GetAttribute(name)
	return type(value) == "number" and value or defaultValue
end

local function readDriveAttributes(rv)
	local overrides = {}

	for _, key in ipairs(Constants.DriveConfigKeys) do
		local value = rv:GetAttribute(key)
		if value ~= nil then
			overrides[key] = value
		end
	end

	return overrides
end

local function driveConfig(rv, overrides)
	local scale = rv:GetAttribute("Scale") or Constants.DefaultScale
	local mergedOverrides = readDriveAttributes(rv)

	for key, value in pairs(overrides or {}) do
		mergedOverrides[key] = value
	end

	local config = Constants.driveConfig(scale, mergedOverrides)
	Constants.validateDriveConfig(config)
	return config
end

local function withVerticalLift(rootCFrame, lift)
	if lift <= EPSILON then
		return rootCFrame
	end

	return CFrame.new(rootCFrame.Position + Vector3.new(0, lift, 0)) * rootCFrame.Rotation
end

local function clampedProbeZ(halfLength, scale, fraction, inset)
	local minZ = -halfLength + inset
	local maxZ = halfLength - inset
	if minZ > maxZ then
		return 0
	end

	return math.clamp(halfLength * fraction, minZ, maxZ)
end

local function dimensionsSnapshot(rv, driveRoot)
	local scale = readNumberAttribute(rv, "Scale", Constants.DefaultScale)
	local wheelCenterY = readNumberAttribute(rv, "WheelCenterY", scale * 1.85)

	return {
		Scale = scale,
		BodyTop = readNumberAttribute(rv, "BodyTop", scale * 11.1),
		ChassisBottom = readNumberAttribute(rv, "ChassisBottom", scale * 1.6),
		FloorTop = readNumberAttribute(rv, "FloorTop", scale * 2.2),
		FloorThickness = readNumberAttribute(rv, "FloorThickness", scale * 0.3),
		WheelCenterY = wheelCenterY,
		WheelRadius = readNumberAttribute(rv, "WheelRadius", scale * 1.85),
		WallThickness = readNumberAttribute(rv, "WallThickness", scale * 0.35),
		DriveRootHalfWidth = driveRoot.Size.X * 0.5,
		DriveRootHalfLength = driveRoot.Size.Z * 0.5,
	}
end

local function bodyClearancePoints(dimensions)
	local scale = dimensions.Scale
	local halfWidth = dimensions.DriveRootHalfWidth
	local halfLength = dimensions.DriveRootHalfLength
	local frontInset = math.min(halfLength * 0.3, scale * 1.3)
	local rearInset = math.min(halfLength * 0.25, scale * 1.1)
	local chassisHalfWidth = math.max(scale * 0.9, halfWidth - scale * 0.55)
	local floorHalfWidth = math.max(scale * 1.4, halfWidth - dimensions.WallThickness - scale * 0.15)
	local localChassisBottom = dimensions.ChassisBottom - dimensions.WheelCenterY
	local localFloorBottom = dimensions.FloorTop - dimensions.FloorThickness - dimensions.WheelCenterY

	local frontZ = clampedProbeZ(halfLength, scale, -0.38, frontInset)
	local frontMidZ = clampedProbeZ(halfLength, scale, -0.12, frontInset)
	local rearMidZ = clampedProbeZ(halfLength, scale, 0.16, rearInset)
	local rearZ = clampedProbeZ(halfLength, scale, 0.38, rearInset)

	return {
		Vector3.new(0, localChassisBottom, frontZ),
		Vector3.new(-chassisHalfWidth, localChassisBottom, frontMidZ),
		Vector3.new(0, localChassisBottom, frontMidZ),
		Vector3.new(chassisHalfWidth, localChassisBottom, frontMidZ),
		Vector3.new(-chassisHalfWidth, localChassisBottom, rearMidZ),
		Vector3.new(0, localChassisBottom, rearMidZ),
		Vector3.new(chassisHalfWidth, localChassisBottom, rearMidZ),
		Vector3.new(0, localChassisBottom, rearZ),
		Vector3.new(-floorHalfWidth, localFloorBottom, frontMidZ),
		Vector3.new(floorHalfWidth, localFloorBottom, frontMidZ),
		Vector3.new(-floorHalfWidth, localFloorBottom, rearMidZ),
		Vector3.new(0, localFloorBottom, rearMidZ),
		Vector3.new(floorHalfWidth, localFloorBottom, rearMidZ),
	}
end

local function localWheelContactPoint(wheel)
	return Vector3.new(
		wheel.LocalCenter.X,
		wheel.LocalCenter.Y - wheel.Radius,
		wheel.LocalCenter.Z
	)
end

local function wheelContactPoints(wheels)
	local points = {}

	for _, wheel in ipairs(wheels) do
		points[#points + 1] = localWheelContactPoint(wheel)
	end

	return points
end

local function maxPointY(points, fallback)
	local maxY = fallback

	for _, point in ipairs(points) do
		maxY = math.max(maxY, point.Y)
	end

	return maxY
end

local function minPointY(points, fallback)
	local minY = fallback

	for _, point in ipairs(points) do
		minY = math.min(minY, point.Y)
	end

	return minY
end

function RVGrounding.localContactAverage(wheels)
	if #wheels == 0 then
		return Vector3.zero
	end

	local localContactAverage = Vector3.zero
	for _, wheel in ipairs(wheels) do
		localContactAverage += localWheelContactPoint(wheel)
	end

	return localContactAverage / #wheels
end

function RVGrounding.currentYawRoot(rootCFrame, suspensionHeight)
	local basePosition = rootCFrame.Position - Vector3.new(0, suspensionHeight or 0, 0)
	local forward = horizontalUnit(rootCFrame.LookVector)
	local rotation = CFrame.lookAt(Vector3.zero, forward, WORLD_UP).Rotation
	return CFrame.new(basePosition) * rotation
end

function RVGrounding.supportIsUsable(support, drive)
	return support ~= nil and support.TiltDegrees <= drive.MaxGroundTiltDegrees
end

local function groundProbe(state, rootCFrame, localPoint)
	local probePoint = rootCFrame:PointToWorldSpace(localPoint)
	local originLift = math.max(0, state.SearchTopLocalY - localPoint.Y) + state.SearchTopPadding
	local castDepth = originLift + state.SearchBottomPadding

	return probePoint, Workspace:Raycast(
		probePoint + WORLD_UP * originLift,
		Vector3.new(0, -castDepth, 0),
		state.SupportRaycastParams
	)
end

function RVGrounding.sampleGround(state, candidateRootCFrame)
	local contactPoints = {}
	local normals = {}
	local hitSides = {}

	for _, wheel in ipairs(state.Wheels) do
		local _, result = groundProbe(state, candidateRootCFrame, localWheelContactPoint(wheel))

		if result then
			contactPoints[#contactPoints + 1] = result.Position
			normals[#normals + 1] = result.Normal
			hitSides[wheel.Side] = true
		end
	end

	if #contactPoints < state.MinimumGroundContacts then
		return nil
	end
	if state.RequireBothSides and (not hitSides[-1] or not hitSides[1]) then
		return nil
	end

	local averagePoint = Vector3.zero
	for _, point in ipairs(contactPoints) do
		averagePoint += point
	end
	averagePoint /= #contactPoints

	local upVector = averageVector(normals, WORLD_UP)

	return {
		AveragePoint = averagePoint,
		Up = upVector,
		TiltDegrees = tiltDegreesFromUp(upVector),
	}
end

function RVGrounding.composeRootFromSupport(state, candidateRootCFrame, support, desiredForward)
	local upVector = support.Up
	local projectedForward = desiredForward - upVector * desiredForward:Dot(upVector)
	if projectedForward.Magnitude <= EPSILON then
		local currentForward = candidateRootCFrame.LookVector - upVector * candidateRootCFrame.LookVector:Dot(upVector)
		projectedForward = currentForward.Magnitude > EPSILON and currentForward or Vector3.new(0, 0, -1)
	end

	local forward = projectedForward.Unit
	local rotation = CFrame.lookAt(Vector3.zero, forward, upVector).Rotation
	local position = support.AveragePoint - rotation:VectorToWorldSpace(state.LocalContactAverage)
	return CFrame.new(position) * rotation
end

local function requiredLiftForPoints(state, rootCFrame, localPoints, requiredGap)
	local lift = 0

	for _, localPoint in ipairs(localPoints) do
		local probePoint, result = groundProbe(state, rootCFrame, localPoint)

		if result then
			lift = math.max(lift, result.Position.Y + requiredGap - probePoint.Y)
		end
	end

	return math.max(0, lift)
end

function RVGrounding.requiredClearanceLift(state, rootCFrame, extraClearance)
	local wheelLift = requiredLiftForPoints(
		state,
		rootCFrame,
		state.WheelClearancePoints,
		state.WheelContactClearance
	)
	local wheelResolvedRoot = withVerticalLift(rootCFrame, wheelLift)
	local bodyLift = requiredLiftForPoints(
		state,
		wheelResolvedRoot,
		state.BodyClearancePoints,
		state.Drive.UndersideClearance + math.max(0, extraClearance or 0)
	)

	return wheelLift + bodyLift, wheelLift, bodyLift
end

function RVGrounding.fitRootToTerrain(state, candidateRootCFrame, desiredForward, extraClearance)
	local support = RVGrounding.sampleGround(state, candidateRootCFrame)
	local supportedRoot = candidateRootCFrame

	if RVGrounding.supportIsUsable(support, state.Drive) then
		supportedRoot = RVGrounding.composeRootFromSupport(state, candidateRootCFrame, support, desiredForward)
	end

	local clearanceLift, wheelLift, bodyLift = RVGrounding.requiredClearanceLift(state, supportedRoot, extraClearance)

	return {
		Support = support,
		SupportedRootCFrame = supportedRoot,
		RootCFrame = withVerticalLift(supportedRoot, clearanceLift),
		ClearanceLift = clearanceLift,
		WheelLift = wheelLift,
		BodyLift = bodyLift,
	}
end

function RVGrounding.createState(config)
	local rv = config.RV
	local driveRoot = config.DriveRoot
	local drive = config.Drive or driveConfig(rv, config.DriveOverrides)
	local wheels = config.Wheels or WheelGroups.runtimeAssemblies(rv, driveRoot)
	local dimensions = config.Dimensions or dimensionsSnapshot(rv, driveRoot)
	DeadCampCollisionService.ensureConfigured()
	local wheelPoints = config.WheelClearancePoints or wheelContactPoints(wheels)
	local bodyPoints = config.BodyClearancePoints or bodyClearancePoints(dimensions)
	local bodyTopLocalY = dimensions.BodyTop - dimensions.WheelCenterY
	local highestProbeY = math.max(
		bodyTopLocalY,
		maxPointY(wheelPoints, bodyTopLocalY),
		maxPointY(bodyPoints, bodyTopLocalY)
	)
	local lowestProbeY = math.min(
		minPointY(wheelPoints, dimensions.ChassisBottom - dimensions.WheelCenterY),
		minPointY(bodyPoints, dimensions.ChassisBottom - dimensions.WheelCenterY)
	)
	local probeSpan = math.max(dimensions.Scale, highestProbeY - lowestProbeY)
	local supportRaycastParams = config.SupportRaycastParams
		or config.RaycastParams
		or buildRaycastParams(rv, DeadCampCollisionGroups.Groups.RVGroundProbe)
	local barrierRaycastParams = config.BarrierRaycastParams
		or buildRaycastParams(rv, DeadCampCollisionGroups.Groups.RVBarrierProbe)

	return {
		RV = rv,
		DriveRoot = driveRoot,
		Drive = drive,
		Wheels = wheels,
		LocalContactAverage = config.LocalContactAverage or RVGrounding.localContactAverage(wheels),
		SupportRaycastParams = supportRaycastParams,
		BarrierRaycastParams = barrierRaycastParams,
		RaycastParams = supportRaycastParams,
		MinimumGroundContacts = config.MinimumGroundContacts or math.max(1, math.min(#wheels, 2)),
		RequireBothSides = config.RequireBothSides == nil and #wheels >= 2 or config.RequireBothSides,
		WheelClearancePoints = wheelPoints,
		BodyClearancePoints = bodyPoints,
		SearchTopLocalY = config.SearchTopLocalY or highestProbeY,
		SearchTopPadding = config.SearchTopPadding or math.max(drive.GroundCastLength, dimensions.Scale * 4.0),
		SearchBottomPadding = config.SearchBottomPadding or (drive.GroundCastLength + probeSpan + dimensions.Scale * 2.0),
		WheelContactClearance = config.WheelContactClearance or math.max(EPSILON, dimensions.Scale * 0.02),
	}
end

function RVGrounding.groundModel(rv, config)
	local driveRoot = (config and config.DriveRoot) or rv:FindFirstChild(rv:GetAttribute("DriveRootName") or "DriveRoot")
	if not driveRoot or not driveRoot:IsA("BasePart") then
		error(("RVGrounding.groundModel requires DriveRoot under %s"):format(rv:GetFullName()), 2)
	end

	local state = config and config.State or RVGrounding.createState({
		RV = rv,
		DriveRoot = driveRoot,
		Drive = config and config.Drive,
		DriveOverrides = config and config.DriveOverrides,
	})
	local candidateYawRoot = RVGrounding.currentYawRoot(driveRoot.CFrame, 0)
	local desiredForward = horizontalUnit(candidateYawRoot.LookVector)
	local fit = RVGrounding.fitRootToTerrain(
		state,
		candidateYawRoot,
		desiredForward,
		(state.Drive.SpawnClearance or 0) + (config and config.ExtraClearance or 0)
	)
	local rootToModel = driveRoot.CFrame:ToObjectSpace(rv:GetPivot())
	rv:PivotTo(fit.RootCFrame * rootToModel)
	return fit, state
end

return RVGrounding
