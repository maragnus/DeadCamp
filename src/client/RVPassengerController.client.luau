local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RVRideSupport = require(Shared:WaitForChild("RVRideSupport"))

local player = Players.LocalPlayer

local CAMERA_BIND_NAME = "RVPassengerControllerCamera"
local CAMERA_BIND_PRIORITY = Enum.RenderPriority.Camera.Value + 1
local FIRST_PERSON_DISTANCE = 1
local FIRST_PERSON_FOCUS_DISTANCE = 0.5
local CAMERA_PITCH_LIMIT = math.rad(85)
local MOUSE_SENSITIVITY = 0.0035
local POSITION_EPSILON = 0.0005
local ROTATION_EPSILON = math.rad(0.03)
local UNSUPPORTED_STATES = {
	[Enum.HumanoidStateType.Dead] = true,
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Swimming] = true,
}

local state = {
	Character = nil,
	Humanoid = nil,
	RootPart = nil,
	ActiveRV = nil,
	ActiveDriveRoot = nil,
	LastDriveRootCFrame = nil,
	CameraYaw = nil,
	CameraPitch = nil,
}

local function resetRideState()
	state.ActiveRV = nil
	state.ActiveDriveRoot = nil
	state.LastDriveRootCFrame = nil
	state.CameraYaw = nil
	state.CameraPitch = nil
end

local function syncCharacterReferences()
	local character = player.Character
	if character ~= state.Character then
		state.Character = character
		state.Humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
		state.RootPart = character and character:FindFirstChild("HumanoidRootPart") or nil
		resetRideState()
		return
	end

	if character and (not state.Humanoid or state.Humanoid.Parent ~= character) then
		state.Humanoid = character:FindFirstChildOfClass("Humanoid")
	end
	if character and (not state.RootPart or state.RootPart.Parent ~= character) then
		state.RootPart = character:FindFirstChild("HumanoidRootPart")
	end
end

local function humanoidCanRide(humanoid, activeRV)
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	if UNSUPPORTED_STATES[humanoid:GetState()] then
		return false
	end

	local seatPart = humanoid.SeatPart
	if seatPart and (not activeRV or seatPart:IsDescendantOf(activeRV)) then
		return false
	end

	return true
end

local function hasMeaningfulDelta(deltaCFrame)
	local _, angle = deltaCFrame:ToAxisAngle()
	return deltaCFrame.Position.Magnitude > POSITION_EPSILON or math.abs(angle) > ROTATION_EPSILON
end

local function isFirstPerson(cameraCFrame, focusCFrame)
	return (cameraCFrame.Position - focusCFrame.Position).Magnitude <= FIRST_PERSON_DISTANCE
end

local function clampPitch(pitch)
	return math.clamp(pitch, -CAMERA_PITCH_LIMIT, CAMERA_PITCH_LIMIT)
end

local function yawPitchFromLookVector(driveRootCFrame, lookVector)
	local localLook = driveRootCFrame:VectorToObjectSpace(lookVector)
	local unitLook = localLook.Magnitude > 0 and localLook.Unit or Vector3.new(0, 0, -1)
	local pitch = math.asin(math.clamp(unitLook.Y, -1, 1))
	local yaw = math.atan2(-unitLook.X, -unitLook.Z)
	return yaw, clampPitch(pitch)
end

local function localLookRotation(yaw, pitch)
	return CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

local function shouldApplyMouseLook(firstPerson)
	if firstPerson then
		return true
	end

	return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

local function ensureCameraAngles(cameraCFrame, driveRootCFrame)
	if state.CameraYaw ~= nil and state.CameraPitch ~= nil then
		return
	end

	state.CameraYaw, state.CameraPitch = yawPitchFromLookVector(driveRootCFrame, cameraCFrame.LookVector)
end

local function updateCameraAngles(firstPerson)
	ensureCameraAngles(Workspace.CurrentCamera.CFrame, state.ActiveDriveRoot.CFrame)

	if not shouldApplyMouseLook(firstPerson) then
		return
	end

	local mouseDelta = UserInputService:GetMouseDelta()
	if mouseDelta == Vector2.zero then
		return
	end

	state.CameraYaw -= mouseDelta.X * MOUSE_SENSITIVITY
	state.CameraPitch = clampPitch(state.CameraPitch - mouseDelta.Y * MOUSE_SENSITIVITY)
end

local function updateRide(dt)
	syncCharacterReferences()

	local character = state.Character
	local humanoid = state.Humanoid
	local rootPart = state.RootPart
	if not character or not humanoid or not rootPart or rootPart.Anchored then
		resetRideState()
		return
	end

	local support = humanoidCanRide(humanoid, state.ActiveRV) and RVRideSupport.supportingRV(character, rootPart) or nil
	if not support then
		resetRideState()
		return
	end

	local driveRoot = support.DriveRoot
	local driveRootCFrame = driveRoot.CFrame

	if state.ActiveDriveRoot ~= driveRoot then
		state.ActiveRV = support.RV
		state.ActiveDriveRoot = driveRoot
		state.LastDriveRootCFrame = driveRootCFrame
		state.CameraYaw = nil
		state.CameraPitch = nil
		return
	end

	local lastDriveRootCFrame = state.LastDriveRootCFrame
	state.ActiveRV = support.RV
	state.ActiveDriveRoot = driveRoot
	state.LastDriveRootCFrame = driveRootCFrame

	if not lastDriveRootCFrame then
		return
	end

	local deltaCFrame = driveRootCFrame * lastDriveRootCFrame:Inverse()
	if not hasMeaningfulDelta(deltaCFrame) then
		return
	end

	character:PivotTo(deltaCFrame * character:GetPivot())
end

local function applyCameraDelta()
	if not state.RootPart or not state.ActiveDriveRoot then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local driveRootCFrame = state.ActiveDriveRoot.CFrame
	local baseCameraCFrame = camera.CFrame
	local baseFocusCFrame = camera.Focus
	local firstPerson = isFirstPerson(baseCameraCFrame, baseFocusCFrame)
	local focusDistance = math.max(
		(baseCameraCFrame.Position - baseFocusCFrame.Position).Magnitude,
		FIRST_PERSON_FOCUS_DISTANCE
	)

	ensureCameraAngles(baseCameraCFrame, driveRootCFrame)
	updateCameraAngles(firstPerson)

	local worldRotation = driveRootCFrame.Rotation * localLookRotation(state.CameraYaw, state.CameraPitch)
	local lookVector = worldRotation.LookVector
	local upVector = worldRotation.UpVector

	if firstPerson then
		local cameraPosition = baseCameraCFrame.Position
		local focusPosition = cameraPosition + lookVector * FIRST_PERSON_FOCUS_DISTANCE
		camera.CFrame = CFrame.lookAt(cameraPosition, focusPosition, upVector)
		camera.Focus = CFrame.lookAt(focusPosition, focusPosition + lookVector, upVector)
		return
	end

	local focusPosition = baseFocusCFrame.Position
	local cameraPosition = focusPosition - lookVector * focusDistance
	camera.CFrame = CFrame.lookAt(cameraPosition, focusPosition, upVector)
	camera.Focus = CFrame.lookAt(focusPosition, focusPosition + lookVector, upVector)
end

player.CharacterAdded:Connect(function()
	task.defer(syncCharacterReferences)
end)
player.CharacterRemoving:Connect(function()
	resetRideState()
	state.Character = nil
	state.Humanoid = nil
	state.RootPart = nil
end)

RunService.PreSimulation:Connect(updateRide)
RunService:BindToRenderStep(CAMERA_BIND_NAME, CAMERA_BIND_PRIORITY, applyCameraDelta)

syncCharacterReferences()
