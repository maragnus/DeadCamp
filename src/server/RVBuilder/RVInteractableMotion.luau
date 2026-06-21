-- Root-relative prompt motion for RV doors and hoods.

local RunService = game:GetService("RunService")

local RVInteractableMotion = {}
RVInteractableMotion.Attributes = {
	GroupId = "OpenCloseGroupId",
	Kind = "OpenCloseKind",
	Side = "OpenCloseSide",
}
RVInteractableMotion.Kinds = {
	SideDoor = "SideDoor",
	Hood = "Hood",
}

local Controller = {}
Controller.__index = Controller

local MOTION_DURATION = 0.35
local HOOD_FRONT_BUFFER_SCALE = 1.4
local HOOD_SIDE_BUFFER_SCALE = 1.6
local HOOD_HEIGHT_BUFFER_SCALE = 3.0

local function easeOutQuad(alpha)
	return 1 - (1 - alpha) * (1 - alpha)
end

local function promptBasePart(prompt)
	local parent = prompt.Parent
	if parent and parent:IsA("Attachment") then
		parent = parent.Parent
	end

	if parent and parent:IsA("BasePart") then
		return parent
	end

	return nil
end

local function findDriveRoot(rv)
	local driveRootName = rv:GetAttribute("DriveRootName") or "DriveRoot"
	local driveRoot = rv:FindFirstChild(driveRootName)
	if driveRoot and driveRoot:IsA("BasePart") then
		return driveRoot
	end
	return nil
end

local function openCloseParts(root, sourcePart)
	local groupAttribute = RVInteractableMotion.Attributes.GroupId
	local groupId = sourcePart:GetAttribute(groupAttribute)
	if not groupId then
		return { sourcePart }
	end

	local parts = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute(groupAttribute) == groupId then
			parts[#parts + 1] = descendant
		end
	end

	if #parts == 0 then
		return { sourcePart }
	end

	return parts
end

local function characterParts(player)
	if not player then
		return nil, nil, nil
	end

	local character = player.Character
	if not character then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, rootPart
end

local function openCloseTransformFromLocal(closedCFrame, size, kind, side)
	local isHood = kind == RVInteractableMotion.Kinds.Hood
	local pivotOffset = isHood and CFrame.new(0, 0, size.Z * 0.5) or CFrame.new(0, 0, -size.Z * 0.5)
	local axis = isHood and closedCFrame.RightVector or closedCFrame.UpVector
	local angle = isHood and math.rad(70) or math.rad(95) * side
	local pivot = (closedCFrame * pivotOffset).Position

	return CFrame.new(pivot) * CFrame.fromAxisAngle(axis.Unit, angle) * CFrame.new(-pivot)
end

local function buildEntry(rv, driveRoot, prompt, sourcePart)
	local kindAttribute = RVInteractableMotion.Attributes.Kind
	local sideAttribute = RVInteractableMotion.Attributes.Side
	local parts = openCloseParts(rv, sourcePart)
	local closedSourceLocal = driveRoot.CFrame:ToObjectSpace(sourcePart.CFrame)
	local transform = openCloseTransformFromLocal(
		closedSourceLocal,
		sourcePart.Size,
		sourcePart:GetAttribute(kindAttribute),
		sourcePart:GetAttribute(sideAttribute) or 1
	)
	local partStates = {}

	for _, part in ipairs(parts) do
		partStates[#partStates + 1] = {
			Part = part,
			ClosedLocalCFrame = driveRoot.CFrame:ToObjectSpace(part.CFrame),
			OpenLocalCFrame = transform * driveRoot.CFrame:ToObjectSpace(part.CFrame),
		}
	end

	return {
		Prompt = prompt,
		Parts = partStates,
		Kind = sourcePart:GetAttribute(kindAttribute),
		SourcePart = sourcePart,
		SourceSize = sourcePart.Size,
		SourceClosedLocalCFrame = closedSourceLocal,
		Alpha = 0,
		TargetAlpha = 0,
	}
end

function Controller:_isSeatedPlayer(player)
	local _, humanoid = characterParts(player)
	return humanoid ~= nil and humanoid.SeatPart ~= nil
end

function Controller:_isPlayerInFrontOfHood(entry, player)
	local _, _, rootPart = characterParts(player)
	if not rootPart then
		return false
	end

	local closedSourceCFrame = self.DriveRoot.CFrame * entry.SourceClosedLocalCFrame
	local localPosition = closedSourceCFrame:PointToObjectSpace(rootPart.Position)
	local scale = self.Scale
	local halfSize = entry.SourceSize * 0.5

	if localPosition.Z > -scale * HOOD_FRONT_BUFFER_SCALE then
		return false
	end
	if math.abs(localPosition.X) > halfSize.X + scale * HOOD_SIDE_BUFFER_SCALE then
		return false
	end
	if math.abs(localPosition.Y) > halfSize.Y + scale * HOOD_HEIGHT_BUFFER_SCALE then
		return false
	end

	return true
end

function Controller:_canToggleEntry(entry, player)
	if self:_isSeatedPlayer(player) then
		return false
	end

	if entry.Kind == RVInteractableMotion.Kinds.Hood then
		return self:_isPlayerInFrontOfHood(entry, player)
	end

	return true
end

function Controller:_applyEntry(entry)
	local easedAlpha = easeOutQuad(entry.Alpha)
	local rootCFrame = self.DriveRoot.CFrame

	for _, state in ipairs(entry.Parts) do
		if state.Part.Parent then
			state.Part.CFrame = rootCFrame * state.ClosedLocalCFrame:Lerp(state.OpenLocalCFrame, easedAlpha)
		end
	end
end

function Controller:_step(dt)
	if not self.RV.Parent or not self.DriveRoot.Parent then
		self:Destroy()
		return
	end

	for _, entry in ipairs(self.Entries) do
		if entry.Alpha ~= entry.TargetAlpha then
			local direction = entry.TargetAlpha > entry.Alpha and 1 or -1
			local deltaAlpha = direction * (dt / MOTION_DURATION)

			if direction > 0 then
				entry.Alpha = math.min(entry.TargetAlpha, entry.Alpha + deltaAlpha)
			else
				entry.Alpha = math.max(entry.TargetAlpha, entry.Alpha + deltaAlpha)
			end
		end

		self:_applyEntry(entry)
	end
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
end

function RVInteractableMotion.attach(rv)
	local driveRoot = findDriveRoot(rv)
	if not driveRoot then
		error(("RVInteractableMotion.attach requires DriveRoot under %s"):format(rv:GetFullName()), 2)
	end

	local controller = setmetatable({
		RV = rv,
		DriveRoot = driveRoot,
		Scale = rv:GetAttribute("Scale") or 1,
		Entries = {},
		Connections = {},
		Destroyed = false,
	}, Controller)

	for _, descendant in ipairs(rv:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			local sourcePart = promptBasePart(descendant)
			if sourcePart then
				local entry = buildEntry(rv, driveRoot, descendant, sourcePart)
				controller.Entries[#controller.Entries + 1] = entry
				controller.Connections[#controller.Connections + 1] = descendant.Triggered:Connect(function(player)
					if not controller:_canToggleEntry(entry, player) then
						return
					end

					entry.TargetAlpha = entry.TargetAlpha > 0 and 0 or 1
					descendant.ActionText = entry.TargetAlpha > 0 and "Close" or "Open"
				end)
			end
		end
	end

	controller.Connections[#controller.Connections + 1] = RunService.Heartbeat:Connect(function(dt)
		controller:_step(dt)
	end)

	return controller
end

return RVInteractableMotion
