-- Server-authoritative kinematic RV driving and visual wheel animation.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CockpitBuilder = require(script.Parent:WaitForChild("CockpitBuilder"))
local Constants = require(script.Parent:WaitForChild("Constants"))
local RVGrounding = require(script.Parent:WaitForChild("RVGrounding"))
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

local function smoothingAlpha(sharpness, dt)
	if sharpness <= 0 then
		return 1
	end

	return 1 - math.exp(-sharpness * dt)
end

local function wrapAngle(angle)
	return math.atan2(math.sin(angle), math.cos(angle))
end

local function lerpAngle(current, target, alpha)
	return current + wrapAngle(target - current) * alpha
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

function Controller:_currentYawRoot(rootCFrame)
	return RVGrounding.currentYawRoot(rootCFrame, self.SuspensionHeight)
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

function Controller:_supportSuspensionTarget(candidateRootCFrame, fit)
	local targetHeight = math.clamp(
		fit.SupportedRootCFrame.Position.Y - candidateRootCFrame.Position.Y,
		-self.Drive.SuspensionMaxTravel,
		self.Drive.SuspensionMaxTravel
	) + fit.ClearanceLift
	local pitch, _, roll = candidateRootCFrame:ToObjectSpace(fit.SupportedRootCFrame):ToOrientation()

	return targetHeight,
		math.clamp(wrapAngle(pitch), -self.MaxSuspensionPitch, self.MaxSuspensionPitch),
		math.clamp(wrapAngle(roll), -self.MaxSuspensionRoll, self.MaxSuspensionRoll)
end

function Controller:_applySuspension(targetHeight, targetPitch, targetRoll, dt, immediateLift)
	local positionAlpha = smoothingAlpha(self.Drive.SuspensionPositionSharpness, dt)
	local angularAlpha = smoothingAlpha(self.Drive.SuspensionAngularSharpness, dt)

	if immediateLift and targetHeight > self.SuspensionHeight then
		self.SuspensionHeight = targetHeight
	else
		self.SuspensionHeight += (targetHeight - self.SuspensionHeight) * positionAlpha
	end
	self.SuspensionPitch = lerpAngle(self.SuspensionPitch, targetPitch, angularAlpha)
	self.SuspensionRoll = lerpAngle(self.SuspensionRoll, targetRoll, angularAlpha)
end

function Controller:_composeFinalRoot(candidateRootCFrame)
	local position = candidateRootCFrame.Position + Vector3.new(0, self.SuspensionHeight, 0)
	local rotation = candidateRootCFrame.Rotation * CFrame.Angles(self.SuspensionPitch, 0, self.SuspensionRoll)
	return CFrame.new(position) * rotation
end

function Controller:_resolveGrounding(candidateRootCFrame, desiredForward, directionSign, dt)
	local fit = RVGrounding.fitRootToTerrain(
		self.GroundingState,
		candidateRootCFrame,
		desiredForward,
		0
	)
	local canUseFreshSupport = RVGrounding.supportIsUsable(fit.Support, self.Drive)

	if canUseFreshSupport and directionSign ~= 0 then
		canUseFreshSupport = self:_ledgeIsSupported(candidateRootCFrame, directionSign)
	end

	if canUseFreshSupport then
		self.CurrentSupport = fit.Support
		self.SupportLossTime = 0
		return fit, false, false
	end

	self.SupportLossTime += dt

	if fit.ClearanceLift > EPSILON then
		return fit, false, false
	end

	if self.SupportLossTime <= self.Drive.SupportLossGraceSeconds then
		return nil, false, true
	end

	if directionSign ~= 0 then
		return nil, true, false
	end

	return fit, false, false
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
	local yawRoot = self:_currentYawRoot(rootCFrame)
	local desiredDistance = self.Speed * dt
	local _, predictedForward = self:_advanceYawRoot(yawRoot, desiredDistance)
	local clampedDistance = self:_clampTravelByObstacles(yawRoot, predictedForward, desiredDistance)

	if math.abs(clampedDistance - desiredDistance) > EPSILON and dt > 0 then
		self.Speed = clampedDistance / dt
	end

	local directionSign = signedDirection(clampedDistance)
	local candidateYawRoot, candidateForward = self:_advanceYawRoot(yawRoot, clampedDistance)
	local fit, shouldStop, holdSuspension = self:_resolveGrounding(candidateYawRoot, candidateForward, directionSign, dt)

	if shouldStop then
		clampedDistance = 0
		self.Speed = 0
		candidateYawRoot = yawRoot
		candidateForward = horizontalUnit(yawRoot.LookVector)
		fit = RVGrounding.fitRootToTerrain(self.GroundingState, candidateYawRoot, candidateForward, 0)
		if RVGrounding.supportIsUsable(fit.Support, self.Drive) then
			self.CurrentSupport = fit.Support
			self.SupportLossTime = 0
		end
		holdSuspension = false
	end

	local targetHeight = self.SuspensionHeight
	local targetPitch = self.SuspensionPitch
	local targetRoll = self.SuspensionRoll

	if fit then
		targetHeight, targetPitch, targetRoll = self:_supportSuspensionTarget(candidateYawRoot, fit)
	elseif not holdSuspension then
		targetHeight, targetPitch, targetRoll = 0, 0, 0
	end

	self:_applySuspension(targetHeight, targetPitch, targetRoll, dt, fit and fit.ClearanceLift > EPSILON)
	local targetRoot = self:_composeFinalRoot(candidateYawRoot)
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

	local drive = driveConfig(rv, driveOverrides)
	local groundingState = RVGrounding.createState({
		RV = rv,
		DriveRoot = driveRoot,
		Drive = drive,
	})
	RVGrounding.groundModel(rv, {
		DriveRoot = driveRoot,
		State = groundingState,
	})

	local controller = setmetatable({
		RV = rv,
		DriveRoot = driveRoot,
		DriverSeat = driverSeat,
		Drive = drive,
		Wheels = groundingState.Wheels,
		GroundingState = groundingState,
		RootToModel = driveRoot.CFrame:ToObjectSpace(rv:GetPivot()),
		LocalRearAxleCenter = Vector3.zero,
		Wheelbase = 0,
		CurrentSupport = nil,
		SupportLossTime = 0,
		Speed = 0,
		VisualSteerDegrees = 0,
		SuspensionHeight = 0,
		SuspensionPitch = 0,
		SuspensionRoll = 0,
		ManualInput = nil,
		MaxVisualSteerDegrees = math.min(34, Constants.driveConfig(rv:GetAttribute("Scale") or Constants.DefaultScale).SteerRateDegrees * 0.45),
		MaxSuspensionPitch = 0,
		MaxSuspensionRoll = 0,
		TotalTravel = 0,
		BumperProbeHeight = (rv:GetAttribute("FloorTop") or driveRoot.Position.Y) - driveRoot.Position.Y + (rv:GetAttribute("Scale") or Constants.DefaultScale) * 1.25,
		RaycastParams = groundingState.RaycastParams,
		Connections = {},
		Destroyed = false,
	}, Controller)

	controller.MaxVisualSteerDegrees = math.min(34, controller.Drive.SteerRateDegrees * 0.45)
	controller.MaxSuspensionPitch = math.rad(controller.Drive.SuspensionMaxPitchDegrees)
	controller.MaxSuspensionRoll = math.rad(controller.Drive.SuspensionMaxRollDegrees)
	controller.OccupantCarry = RVOccupantCarry.attach(rv)
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
	local currentYawRoot = controller:_currentYawRoot(driveRoot.CFrame)
	local initialFit = RVGrounding.fitRootToTerrain(
		controller.GroundingState,
		currentYawRoot,
		horizontalUnit(currentYawRoot.LookVector),
		0
	)
	if RVGrounding.supportIsUsable(initialFit.Support, controller.Drive) then
		controller.CurrentSupport = initialFit.Support
	end
	if initialFit then
		local targetHeight, targetPitch, targetRoll = controller:_supportSuspensionTarget(
			currentYawRoot,
			initialFit
		)
		controller.SuspensionHeight = targetHeight
		controller.SuspensionPitch = targetPitch
		controller.SuspensionRoll = targetRoll
	end

	controller.Connections[#controller.Connections + 1] = RunService.PreSimulation:Connect(function(dt)
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
