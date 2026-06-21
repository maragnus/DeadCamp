local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RVDebugPanelConfig = require(Shared:WaitForChild("RVDebugPanelConfig"))

local RVBuilder = script.Parent:WaitForChild("RVBuilder")
local BaseCampPlan = require(RVBuilder:WaitForChild("Plans"):WaitForChild("BaseCamp"))
local RVDriveController = require(RVBuilder:WaitForChild("RVDriveController"))
local VehicleBuilder = require(RVBuilder:WaitForChild("VehicleBuilder"))

local RVDebugPanelService = {}

local state = {
	Started = false,
	RemoteEvent = nil,
	Controller = nil,
	CurrentRV = nil,
}

local function currentController()
	local controller = state.Controller
	local rv = state.CurrentRV

	if controller and rv and rv.Parent then
		return controller
	end

	state.Controller = nil
	state.CurrentRV = nil
	return nil
end

local function destroyCurrentController()
	if state.Controller then
		state.Controller:Destroy()
	end

	state.Controller = nil
	state.CurrentRV = nil
end

local function requireAction(actionId)
	local action = RVDebugPanelConfig.action(actionId)
	if not action then
		error(("Unknown RV debug action %s"):format(tostring(actionId)), 2)
	end

	return action
end

local function requirePlan(action)
	local planFactory = BaseCampPlan[action.PlanFactory]
	if type(planFactory) ~= "function" then
		error(("Unknown BaseCamp plan factory %s"):format(tostring(action.PlanFactory)), 2)
	end

	return planFactory()
end

local function ensureRemoteEvent()
	local folder = ReplicatedStorage:FindFirstChild(RVDebugPanelConfig.RemoteFolderName)
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = RVDebugPanelConfig.RemoteFolderName
		folder.Parent = ReplicatedStorage
	end

	local remoteEvent = folder:FindFirstChild(RVDebugPanelConfig.RemoteEventName)
	if remoteEvent and not remoteEvent:IsA("RemoteEvent") then
		remoteEvent:Destroy()
		remoteEvent = nil
	end
	if not remoteEvent then
		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = RVDebugPanelConfig.RemoteEventName
		remoteEvent.Parent = folder
	end

	return remoteEvent
end

function RVDebugPanelService.applyDriveAction(actionId)
	local action = requireAction(actionId)
	if action.Kind ~= RVDebugPanelConfig.ActionKinds.Drive then
		error(("RV debug action %s is not a drive action"):format(action.Id), 2)
	end

	local controller = currentController()
	if not controller then
		return nil
	end

	controller:SetManualInput(action.Throttle, action.Steer)
	if action.ImmediateStop then
		controller:Stop()
	end

	return controller
end

function RVDebugPanelService.spawnAction(actionId)
	local action = requireAction(actionId)
	if action.Kind ~= RVDebugPanelConfig.ActionKinds.Spawn then
		error(("RV debug action %s is not a spawn action"):format(action.Id), 2)
	end

	destroyCurrentController()

	local rv = VehicleBuilder.build(requirePlan(action))
	local controller = RVDriveController.attach(rv)

	state.CurrentRV = rv
	state.Controller = controller

	rv.AncestryChanged:Connect(function(_, parent)
		if not parent and state.CurrentRV == rv then
			state.CurrentRV = nil
			if state.Controller == controller then
				state.Controller = nil
			end
		end
	end)

	RVDebugPanelService.applyDriveAction(RVDebugPanelConfig.DefaultDriveActionId)
	return rv
end

function RVDebugPanelService.performAction(actionId)
	local action = requireAction(actionId)

	if action.Kind == RVDebugPanelConfig.ActionKinds.Spawn then
		return RVDebugPanelService.spawnAction(actionId)
	end
	if action.Kind == RVDebugPanelConfig.ActionKinds.Drive then
		return RVDebugPanelService.applyDriveAction(actionId)
	end

	error(("Unsupported RV debug action kind %s"):format(tostring(action.Kind)), 2)
end

function RVDebugPanelService.spawnDefault()
	return RVDebugPanelService.spawnAction(RVDebugPanelConfig.DefaultSpawnActionId)
end

function RVDebugPanelService.currentRV()
	return state.CurrentRV
end

function RVDebugPanelService.start()
	if state.Started then
		return state.RemoteEvent
	end

	state.Started = true

	if not RunService:IsStudio() then
		return nil
	end

	local remoteEvent = ensureRemoteEvent()
	state.RemoteEvent = remoteEvent

	remoteEvent.OnServerEvent:Connect(function(player, actionId)
		if type(actionId) ~= "string" then
			return
		end

		local ok, err = pcall(function()
			RVDebugPanelService.performAction(actionId)
		end)
		if not ok then
			warn(("RVDebugPanelService failed for %s action %s: %s"):format(player.Name, actionId, err))
		end
	end)

	return remoteEvent
end

return RVDebugPanelService
