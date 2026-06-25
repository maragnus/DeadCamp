local Players = game:GetService("Players")

local RVConstants = require(script.Parent.Parent:WaitForChild("RVBuilder"):WaitForChild("Constants"))

local WorldPlacement = {}

local state = {
	CurrentRV = nil,
	SurfaceHeightFn = nil,
	PlayerConnections = {},
	PlayerAddedConnection = nil,
}

local function pointInsideBox(point, cframe, size)
	local localPoint = cframe:PointToObjectSpace(point)
	return math.abs(localPoint.X) <= size.X * 0.5
		and math.abs(localPoint.Y) <= size.Y * 0.5
		and math.abs(localPoint.Z) <= size.Z * 0.5
end

local function findEntryPart(rv)
	for _, descendant in ipairs(rv:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("PlayerPlacementEntry") == true then
			return descendant
		end
	end

	for _, descendant in ipairs(rv:GetDescendants()) do
		if descendant:IsA("BasePart")
			and descendant:GetAttribute("PartRole") == "EntryDoor"
			and descendant:GetAttribute("OpenCloseSide") == 1
		then
			return descendant
		end
	end

	return nil
end

local function dropPoint(rv, surfaceHeightFn)
	local entryPart = findEntryPart(rv)
	if not entryPart then
		return nil, "Missing right-side entry part"
	end

	local surfaceY = surfaceHeightFn and surfaceHeightFn(entryPart.Position.X, entryPart.Position.Z) or entryPart.Position.Y
	local outward = entryPart.CFrame.RightVector
	local drop = entryPart.Position
		+ outward * (entryPart.Size.X * 0.5 + 4.5)
		+ entryPart.CFrame.LookVector * 1.5
	local dropSurfaceY = surfaceHeightFn and surfaceHeightFn(drop.X, drop.Z) or surfaceY
	drop = Vector3.new(drop.X, math.max(drop.Y, dropSurfaceY + 4), drop.Z)

	local boxCFrame, boxSize = rv:GetBoundingBox()
	if pointInsideBox(drop, boxCFrame, boxSize) then
		drop += outward * 4
		dropSurfaceY = surfaceHeightFn and surfaceHeightFn(drop.X, drop.Z) or surfaceY
		drop = Vector3.new(drop.X, math.max(drop.Y, dropSurfaceY + 4), drop.Z)
	end

	return drop, nil
end

local function placeCharacter(rv, surfaceHeightFn, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if not humanoid or not rootPart then
		return false, "Missing humanoid or root"
	end

	local drop, err = dropPoint(rv, surfaceHeightFn)
	if not drop then
		return false, err
	end

	local facing = rv:GetPivot().LookVector
	local lift = math.max(4, humanoid.HipHeight + 2.5)
	character:PivotTo(CFrame.lookAt(drop + Vector3.new(0, lift, 0), drop + facing + Vector3.new(0, lift, 0), Vector3.yAxis))
	return true, nil
end

local function ensureHooks()
	if state.PlayerAddedConnection then
		return
	end

	local function bindPlayer(player)
		if state.PlayerConnections[player] then
			return
		end

		state.PlayerConnections[player] = player.CharacterAdded:Connect(function(character)
			task.defer(function()
				if state.CurrentRV and state.CurrentRV.Parent and state.SurfaceHeightFn then
					local ok, err = placeCharacter(state.CurrentRV, state.SurfaceHeightFn, character)
					if not ok then
						warn(("WorldPlacement failed to place respawned character for %s: %s"):format(player.Name, tostring(err)))
					end
				end
			end)
		end)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		bindPlayer(player)
	end

	state.PlayerAddedConnection = Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local connection = state.PlayerConnections[player]
		if connection then
			connection:Disconnect()
			state.PlayerConnections[player] = nil
		end
	end)
end

function WorldPlacement.auditDrop(rv, surfaceHeightFn)
	local drop, err = dropPoint(rv, surfaceHeightFn)
	if not drop then
		return false, err
	end

	local surfaceY = surfaceHeightFn and surfaceHeightFn(drop.X, drop.Z) or drop.Y
	if drop.Y <= surfaceY + 1 then
		return false, ("Drop point %.2f is below terrain %.2f"):format(drop.Y, surfaceY)
	end

	local boxCFrame, boxSize = rv:GetBoundingBox()
	if pointInsideBox(drop, boxCFrame, boxSize) then
		return false, "Drop point still intersects RV bounds"
	end

	return true, nil
end

function WorldPlacement.placeRVAtStart(rv, startCFrame)
	if not startCFrame then
		return false
	end

	local scale = rv:GetAttribute("Scale") or RVConstants.DefaultScale
	local dimensions = RVConstants.dimensions(scale)
	local pivotPosition = startCFrame.Position + Vector3.new(0, dimensions.ChassisY, 0)
	local targetCFrame = CFrame.lookAt(pivotPosition, pivotPosition + startCFrame.LookVector, Vector3.yAxis)
	rv:PivotTo(targetCFrame)
	return true
end

function WorldPlacement.activate(rv, surfaceHeightFn)
	ensureHooks()
	state.CurrentRV = rv
	state.SurfaceHeightFn = surfaceHeightFn

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local ok, err = placeCharacter(rv, surfaceHeightFn, character)
			if not ok then
				warn(("WorldPlacement failed to place %s: %s"):format(player.Name, tostring(err)))
			end
		end
	end
end

function WorldPlacement.deactivate(rv)
	if not rv or state.CurrentRV == rv then
		state.CurrentRV = nil
		state.SurfaceHeightFn = nil
	end
end

return WorldPlacement
