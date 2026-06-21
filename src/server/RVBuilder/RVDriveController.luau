-- Server-authoritative kinematic RV driving and visual wheel animation.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CockpitBuilder = require(script.Parent:WaitForChild("CockpitBuilder"))
local Constants = require(script.Parent:WaitForChild("Constants"))
local RVOccupantCarry = require(script.Parent:WaitForChild("RVOccupantCarry"))
local WheelGroups = require(script.Parent:WaitForChild("WheelGroups"))

local RVDriveController = {}

local Controller = {}
Controller.__index = Controller

local WORLD_UP = Vector3.new(0, 1, 0)
local EPSILON = 0.001
local LEAD_SAMPLE_EPSILON = 0.05

local function approach(current, target, maxDelta)
	if current < target then
		return math.min(target, current + maxDelta)
	end
	return math.max(target, current - maxDelta)
end

local function horizontalUnit(vector, fallback)
	local flattened = Vector3.new(vector.X, 0, vector.Z)
	if flattened.Magnitude <= EPSILON then
		return fallback or Vector3.new(0, 0, -1)
	end
	return flattened.Unit
end

local function rotateVectorY(vector, angle)
	return CFrame.fromAxisAngle(WORLD_UP, angle):VectorToWorldSpace(vector)
end

local function signedDirection(value)
	if value > EPSILON then
		return 1
	end
	if value < -EPSILON then
		return -1
	end
	return 0
end

local function clampControlInput(value)
	return math.clamp(tonumber(value) or 0, -1, 1)
end

local function findDriveRoot(rv)
	local driveRootName = rv:GetAttribute("DriveRootName") or "DriveRoot"
	local driveRoot = rv:FindFirstChild(driveRootName)
	if driveRoot and driveRoot:IsA("BasePart") then
		return driveRoot
	end
	return nil
end

local function findDriverSeat(rv)
	for _, descendant in ipairs(rv:GetDescendants()) do
		if descendant:IsA("VehicleSeat")
			and descendant:GetAttribute("PartRole") == "DriverVehicleSeat"
			and descendant:GetAttribute(CockpitBuilder.IsDriveSeatAttribute) == true
		then
			return descendant
		end
	end
	return nil
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

local function sampleLeadWheels(wheels, directionSign)
	local leadZ = directionSign >= 0 and math.huge or -math.huge
	local samples = {}

	for _, wheel in ipairs(wheels) do
		local z = wheel.LocalCenter.Z
		local isBetter = directionSign >= 0 and z < leadZ - LEAD_SAMPLE_EPSILON
			or directionSign < 0 and z > leadZ + LEAD_SAMPLE_EPSILON

		if isBetter then
			leadZ = z
			samples = { wheel }
		elseif math.abs(z - leadZ) <= LEAD_SAMPLE_EPSILON then
			samples[#samples + 1] = wheel
		end
	end

	return samples, leadZ
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

local function averagePoint(points)
	local total = Vector3.zero
	for _, point in ipairs(points) do
		total += point
	end

	if #points == 0 then
		return Vector3.zero
	end

	return total / #points
end

local function axleKey(wheel)
	return ("%s:%0.4f"):format(wheel.GroupId or "Wheel", wheel.AxleZ or 0)
end

local function axleLayouts(wheels)
	local axlesByKey = {}

	for _, wheel in ipairs(wheels) do
		local key = axleKey(wheel)
		local axle = axlesByKey[key]
		if not axle then
			axle = {
				Wheels = {},
				Steerable = wheel.Steerable == true,
				Z = wheel.AxleZ or wheel.LocalCenter.Z,
			}
			axlesByKey[key] = axle
		end

		axle.Wheels[#axle.Wheels + 1] = wheel
		axle.Steerable = axle.Steerable or wheel.Steerable == true
	end

	local axles = {}
	for _, axle in pairs(axlesByKey) do
		local centers = {}
		for _, wheel in ipairs(axle.Wheels) do
			centers[#centers + 1] = wheel.LocalCenter
		end
		axle.Center = averagePoint(centers)
		axles[#axles + 1] = axle
	end

	table.sort(axles, function(a, b)
		return a.Z < b.Z
	end)

	return axles
end

local function averageAxleCenter(axles)
	local centers = {}
	for _, axle in ipairs(axles) do
		centers[#centers + 1] = axle.Center
	end
	return averagePoint(centers)
end

local function buildRaycastParams(rv)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rv }
	return params
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

function Controller:_controlInput()
	if self.DriverSeat.Parent and self.DriverSeat.Occupant then
		return self.DriverSeat.ThrottleFloat, self.DriverSeat.SteerFloat
	end

	local manualInput = self.ManualInput
	if manualInput then
		return manualInput.Throttle, manualInput.Steer
	end

	return 0, 0
end

function Controller:_integrateSpeed(throttle, dt)
	local drive = self.Drive
	local targetForwardSpeed = drive.MaxForwardSpeed * math.max(throttle, 0)
	local targetReverseSpeed = -drive.MaxReverseSpeed * math.max(-throttle, 0)

	if throttle > 0 then
		if self.Speed < 0 then
			self.Speed = approach(self.Speed, 0, drive.BrakeDeceleration * dt)
		end
		self.Speed = approach(self.Speed, targetForwardSpeed, drive.Acceleration * dt)
	elseif throttle < 0 then
		if self.Speed > 0 then
			self.Speed = approach(self.Speed, 0, drive.BrakeDeceleration * dt)
		end
		self.Speed = approach(self.Speed, targetReverseSpeed, drive.Acceleration * dt)
	else
		self.Speed = approach(self.Speed, 0, drive.CoastDeceleration * dt)
	end
end

function Controller:_integrateSteer(steerInput, dt)
	local targetAngle = steerInput * self.MaxVisualSteerDegrees
	local rate = steerInput == 0 and self.Drive.SteerReturnDegrees or self.Drive.SteerRateDegrees
	self.VisualSteerDegrees = approach(self.VisualSteerDegrees, targetAngle, rate * dt)
end

function Controller:_yawDeltaForDistance(distance)
	if math.abs(self.VisualSteerDegrees) <= EPSILON or math.abs(distance) <= EPSILON or self.Wheelbase <= EPSILON then
		return 0
	end

	return -math.tan(math.rad(self.VisualSteerDegrees)) * distance / self.Wheelbase
end

function Controller:_sampleGround(candidateRootCFrame)
	local contactPoints = {}
	local normals = {}

	for _, wheel in ipairs(self.Wheels) do
		local localCenter = wheel.LocalCenter
		local sampleCenter = candidateRootCFrame:PointToWorldSpace(localCenter)
		local origin = sampleCenter + WORLD_UP * (self.Drive.GroundCastLength * 0.5 + wheel.Radius)
		local result = Workspace:Raycast(
			origin,
			Vector3.new(0, -(self.Drive.GroundCastLength + wheel.Radius * 2.2), 0),
			self.RaycastParams
		)

		if not result then
			return nil
		end

		contactPoints[#contactPoints + 1] = result.Position
		normals[#normals + 1] = result.Normal
	end

	if #contactPoints == 0 then
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

function Controller:_frontClearanceOffsets(directionSign)
	local leadWheels, leadZ = sampleLeadWheels(self.Wheels, directionSign)
	if #leadWheels == 0 then
		local edgeZ = directionSign >= 0 and -self.DriveRoot.Size.Z * 0.5 or self.DriveRoot.Size.Z * 0.5
		local halfWidth = self.DriveRoot.Size.X * 0.32
		return {
			Vector3.new(-halfWidth, 0, edgeZ),
			Vector3.new(0, 0, edgeZ),
			Vector3.new(halfWidth, 0, edgeZ),
		}
	end

	local offsets = {}
	for _, wheel in ipairs(leadWheels) do
		offsets[#offsets + 1] = Vector3.new(wheel.LocalCenter.X, 0, leadZ)
	end
	offsets[#offsets + 1] = Vector3.new(0, 0, leadZ)
	return offsets
end

function Controller:_clampTravelByObstacles(rootCFrame, desiredForward, desiredDistance)
	local directionSign = signedDirection(desiredDistance)
	if directionSign == 0 then
		return 0
	end

	local desiredMagnitude = math.abs(desiredDistance)
	local rayLength = desiredMagnitude + self.Drive.ForwardClearance + self.Drive.StopBuffer
	local allowedMagnitude = desiredMagnitude
	local probeDirection = desiredForward * rayLength

	for _, localOffset in ipairs(self:_frontClearanceOffsets(directionSign)) do
		local origin = rootCFrame:PointToWorldSpace(localOffset) + WORLD_UP * (self.BumperProbeHeight + self.DriveRoot.Size.Y * 0.5)
		local result = Workspace:Raycast(origin, probeDirection, self.RaycastParams)

		if result then
			local available = math.max(0, result.Distance - self.Drive.ForwardClearance - self.Drive.StopBuffer)
			allowedMagnitude = math.min(allowedMagnitude, available)
		end
	end

	return allowedMagnitude * directionSign
end

function Controller:_ledgeIsSupported(candidateRootCFrame, directionSign)
	if directionSign == 0 then
		return true
	end

	local leadWheels, leadZ = sampleLeadWheels(self.Wheels, directionSign)
	if #leadWheels == 0 then
		return true
	end

	local probeZ = leadZ + (directionSign >= 0 and -self.Drive.LedgeProbeLength or self.Drive.LedgeProbeLength)
	local offsets = {
		Vector3.new(0, 0, probeZ),
	}

	for _, wheel in ipairs(leadWheels) do
		offsets[#offsets + 1] = Vector3.new(wheel.LocalCenter.X, 0, probeZ)
	end

	for _, localOffset in ipairs(offsets) do
		local origin = candidateRootCFrame:PointToWorldSpace(localOffset) + WORLD_UP * self.Drive.GroundCastLength
		local result = Workspace:Raycast(
			origin,
			Vector3.new(0, -(self.Drive.GroundCastLength + self.Drive.LedgeProbeLength), 0),
			self.RaycastParams
		)

		if not result then
			return false
		end
	end

	return true
end

function Controller:_composeRoot(candidateRootCFrame, support, desiredForward)
	local upVector = support.Up
	local projectedForward = desiredForward - upVector * desiredForward:Dot(upVector)
	if projectedForward.Magnitude <= EPSILON then
		local currentForward = candidateRootCFrame.LookVector - upVector * candidateRootCFrame.LookVector:Dot(upVector)
		projectedForward = currentForward.Magnitude > EPSILON and currentForward or Vector3.new(0, 0, -1)
	end

	local forward = projectedForward.Unit
	local rotation = CFrame.lookAt(Vector3.zero, forward, upVector).Rotation
	local position = support.AveragePoint - rotation:VectorToWorldSpace(self.LocalContactAverage)
	return CFrame.new(position) * rotation
end

function Controller:_advanceYawRoot(rootCFrame, distance)
	local forward = horizontalUnit(rootCFrame.LookVector)
	local yawDelta = self:_yawDeltaForDistance(distance)
	local travelForward = math.abs(yawDelta) > EPSILON and rotateVectorY(forward, yawDelta * 0.5) or forward
	local nextForward = rotateVectorY(forward, yawDelta)
	local rearAxleCenter = rootCFrame:PointToWorldSpace(self.LocalRearAxleCenter)
	local nextRearAxleCenter = rearAxleCenter + travelForward * distance
	local rotation = CFrame.lookAt(Vector3.zero, nextForward, WORLD_UP).Rotation
	local nextRootPosition = nextRearAxleCenter - rotation:VectorToWorldSpace(self.LocalRearAxleCenter)

	return CFrame.new(nextRootPosition) * rotation, nextForward
end

function Controller:_animateWheels(rootCFrame)
	for _, wheel in ipairs(self.Wheels) do
		local steerRotation = CFrame.new()
		if wheel.Steerable then
			steerRotation = CFrame.Angles(0, math.rad(-self.VisualSteerDegrees), 0)
		end

		local spinRotation = CFrame.Angles(self.TotalTravel / math.max(wheel.Radius, EPSILON), 0, 0)
		local tireLocal = CFrame.new(wheel.LocalCenter) * steerRotation * wheel.TireBaseLocalCFrame.Rotation * spinRotation
		wheel.Tire.CFrame = rootCFrame * tireLocal

		if wheel.Rim and wheel.RimBaseLocalCFrame then
			local rimLocal = CFrame.new(wheel.LocalCenter) * steerRotation * wheel.RimBaseLocalCFrame.Rotation * spinRotation
			wheel.Rim.CFrame = rootCFrame * rimLocal
		end
	end
end

function Controller:_step(dt)
	if self.Destroyed then
		return
	end
	if not self.RV.Parent or not self.DriveRoot.Parent or not self.DriverSeat.Parent then
		self:Destroy()
		return
	end

	dt = math.min(dt, 0.1)

	local throttle, steerInput = self:_controlInput()
	self:_integrateSpeed(throttle, dt)
	self:_integrateSteer(steerInput, dt)

	local rootCFrame = self.DriveRoot.CFrame
	local desiredDistance = self.Speed * dt
	local _, predictedForward = self:_advanceYawRoot(rootCFrame, desiredDistance)
	local clampedDistance = self:_clampTravelByObstacles(rootCFrame, predictedForward, desiredDistance)

	if math.abs(clampedDistance - desiredDistance) > EPSILON and dt > 0 then
		self.Speed = clampedDistance / dt
	end

	local directionSign = signedDirection(clampedDistance)
	local candidateYawRoot, candidateForward = self:_advanceYawRoot(rootCFrame, clampedDistance)
	local support = self:_sampleGround(candidateYawRoot)

	if directionSign ~= 0 then
		if not support or support.TiltDegrees > self.Drive.MaxGroundTiltDegrees or not self:_ledgeIsSupported(candidateYawRoot, directionSign) then
			clampedDistance = 0
			self.Speed = 0
			candidateYawRoot = rootCFrame
			candidateForward = horizontalUnit(rootCFrame.LookVector)
			support = self:_sampleGround(candidateYawRoot) or self.CurrentSupport
		end
	end

	support = support or self.CurrentSupport
	local targetRoot = rootCFrame

	if support and support.TiltDegrees <= self.Drive.MaxGroundTiltDegrees then
		targetRoot = self:_composeRoot(candidateYawRoot, support, candidateForward)
		self.CurrentSupport = support
	else
		targetRoot = CFrame.lookAt(rootCFrame.Position, rootCFrame.Position + candidateForward, rootCFrame.UpVector)
	end

	local delta = targetRoot * rootCFrame:Inverse()
	self.TotalTravel += clampedDistance
	self.RV:PivotTo(targetRoot * self.RootToModel)
	self.OccupantCarry:applyDelta(delta)
	self:_animateWheels(self.DriveRoot.CFrame)
end

function Controller:SetManualInput(throttle, steer)
	self.ManualInput = {
		Throttle = clampControlInput(throttle),
		Steer = clampControlInput(steer),
	}
end

function Controller:ClearManualInput()
	self.ManualInput = nil
end

function Controller:Stop()
	self.Speed = 0
	self.VisualSteerDegrees = 0
end

function Controller:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	self.Connections = {}

	if self.OccupantCarry then
		self.OccupantCarry:Destroy()
	end
end

function RVDriveController.attach(rv, driveOverrides)
	local driveRoot = findDriveRoot(rv)
	if not driveRoot then
		error(("RVDriveController.attach requires DriveRoot under %s"):format(rv:GetFullName()), 2)
	end

	local driverSeat = findDriverSeat(rv)
	if not driverSeat then
		error(("RVDriveController.attach requires a tagged driver VehicleSeat under %s"):format(rv:GetFullName()), 2)
	end

	local controller = setmetatable({
		RV = rv,
		DriveRoot = driveRoot,
		DriverSeat = driverSeat,
		Drive = driveConfig(rv, driveOverrides),
		Wheels = WheelGroups.runtimeAssemblies(rv, driveRoot),
		RootToModel = driveRoot.CFrame:ToObjectSpace(rv:GetPivot()),
		GroundOffset = driveRoot.Position.Y - (rv:GetAttribute("GroundY") or 0),
		LocalContactAverage = Vector3.zero,
		LocalRearAxleCenter = Vector3.zero,
		Wheelbase = 0,
		CurrentSupport = nil,
		Speed = 0,
		VisualSteerDegrees = 0,
		ManualInput = nil,
		MaxVisualSteerDegrees = math.min(34, Constants.driveConfig(rv:GetAttribute("Scale") or Constants.DefaultScale).SteerRateDegrees * 0.45),
		TotalTravel = 0,
		BumperProbeHeight = (rv:GetAttribute("FloorTop") or driveRoot.Position.Y) - driveRoot.Position.Y + (rv:GetAttribute("Scale") or Constants.DefaultScale) * 1.25,
		RaycastParams = buildRaycastParams(rv),
		Connections = {},
		Destroyed = false,
	}, Controller)

	controller.MaxVisualSteerDegrees = math.min(34, controller.Drive.SteerRateDegrees * 0.45)
	controller.OccupantCarry = RVOccupantCarry.attach(rv)
	if #controller.Wheels > 0 then
		local localContactAverage = Vector3.zero
		for _, wheel in ipairs(controller.Wheels) do
			localContactAverage += Vector3.new(
				wheel.LocalCenter.X,
				wheel.LocalCenter.Y - wheel.Radius,
				wheel.LocalCenter.Z
			)
		end
		controller.LocalContactAverage = localContactAverage / #controller.Wheels
	end
	local axles = axleLayouts(controller.Wheels)
	if #axles > 0 then
		local steerableAxles = {}
		local fixedAxles = {}

		for _, axle in ipairs(axles) do
			if axle.Steerable then
				steerableAxles[#steerableAxles + 1] = axle
			else
				fixedAxles[#fixedAxles + 1] = axle
			end
		end

		local frontReferenceAxle = #steerableAxles > 0 and steerableAxles[1] or axles[1]
		local rearReferenceCenter = #fixedAxles > 0 and averageAxleCenter(fixedAxles) or axles[#axles].Center

		controller.LocalRearAxleCenter = rearReferenceCenter
		controller.Wheelbase = math.max(EPSILON, rearReferenceCenter.Z - frontReferenceAxle.Center.Z)
	end
	controller.CurrentSupport = controller:_sampleGround(driveRoot.CFrame)
	if controller.CurrentSupport then
		controller.GroundOffset = (driveRoot.Position - controller.CurrentSupport.AveragePoint):Dot(controller.CurrentSupport.Up)
	end

	controller.Connections[#controller.Connections + 1] = RunService.Heartbeat:Connect(function(dt)
		controller:_step(dt)
	end)
	controller.Connections[#controller.Connections + 1] = rv.AncestryChanged:Connect(function(_, parent)
		if not parent then
			controller:Destroy()
		end
	end)

	return controller
end

return RVDriveController
