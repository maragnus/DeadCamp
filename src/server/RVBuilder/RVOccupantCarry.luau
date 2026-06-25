-- Server fallback carry for grounded humanoids standing on the RV.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RVRideSupport = require(Shared:WaitForChild("RVRideSupport"))

local RVOccupantCarry = {}

local Controller = {}
Controller.__index = Controller

local POSITION_EPSILON = 0.005
local ROTATION_EPSILON = math.rad(0.2)

local function isClientOwned(rootPart)
	local ok, ownerOrErr = pcall(function()
		return rootPart:GetNetworkOwner()
	end)
	if not ok then
		error(("RVOccupantCarry failed to read network owner for %s: %s"):format(rootPart:GetFullName(), tostring(ownerOrErr)), 0)
	end
	return ownerOrErr ~= nil
end

local function shouldSkipHumanoid(rv, humanoid, rootPart)
	if humanoid.Health <= 0 then
		return true
	end

	if isClientOwned(rootPart) then
		return true
	end

	local seatPart = humanoid.SeatPart
	if seatPart and seatPart:IsDescendantOf(rv) then
		return true
	end

	return false
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

			if humanoid and rootPart and not rootPart.Anchored and not shouldSkipHumanoid(self.RV, humanoid, rootPart) then
				local support = RVRideSupport.supportingRV(character, rootPart)
				if support and support.RV == self.RV then
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
