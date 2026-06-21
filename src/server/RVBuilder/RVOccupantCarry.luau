-- Carries grounded humanoid characters with the moving RV.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RVOccupantCarry = {}

local Controller = {}
Controller.__index = Controller

local SUPPORT_RAY_LENGTH = 6.5
local POSITION_EPSILON = 0.005
local ROTATION_EPSILON = math.rad(0.2)
local CARRIED_SUPPORT_ROLES = {
	WalkableFloor = true,
	WheelBoxInterior = true,
}

local function shouldSkipHumanoid(rv, humanoid)
	if humanoid.Health <= 0 then
		return true
	end

	local seatPart = humanoid.SeatPart
	if seatPart and seatPart:IsDescendantOf(rv) then
		return true
	end

	return false
end

local function isSupportedByRV(rv, character, rootPart)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local result = Workspace:Raycast(
		rootPart.Position + Vector3.new(0, 0.25, 0),
		Vector3.new(0, -SUPPORT_RAY_LENGTH, 0),
		raycastParams
	)

	if not (result and result.Instance and result.Instance:IsDescendantOf(rv)) then
		return false
	end

	local role = result.Instance:GetAttribute("PartRole")
	return role ~= nil and CARRIED_SUPPORT_ROLES[role] == true
end

local function hasMeaningfulDelta(deltaCFrame)
	local _, angle = deltaCFrame:ToAxisAngle()
	return deltaCFrame.Position.Magnitude > POSITION_EPSILON or math.abs(angle) > ROTATION_EPSILON
end

function Controller:applyDelta(deltaCFrame)
	if self.Destroyed then
		return
	end
	if not hasMeaningfulDelta(deltaCFrame) then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character.Parent then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local rootPart = character:FindFirstChild("HumanoidRootPart")

			if humanoid and rootPart and not rootPart.Anchored and not shouldSkipHumanoid(self.RV, humanoid) then
				if isSupportedByRV(self.RV, character, rootPart) then
					character:PivotTo(deltaCFrame * character:GetPivot())
				end
			end
		end
	end
end

function Controller:Destroy()
	self.Destroyed = true
end

function RVOccupantCarry.attach(rv)
	return setmetatable({
		RV = rv,
		Destroyed = false,
	}, Controller)
end

return RVOccupantCarry
