local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local WorldGenShared = Shared:WaitForChild("WorldGen")

local RoadRibbonSpec = require(WorldGenShared:WaitForChild("RoadRibbonSpec"))
local RoadRenderBuilder = require(WorldGenShared:WaitForChild("RoadRenderBuilder"))
local WorldConstants = require(WorldGenShared:WaitForChild("WorldConstants"))
local WorldProfile = require(WorldGenShared:WaitForChild("WorldProfile"))
local WorldSerialization = require(WorldGenShared:WaitForChild("WorldSerialization"))

local WorldGenClientRenderer = {}

local attached = {}

local function destroyLocalRoad(root)
	local existing = root:FindFirstChild(WorldConstants.FolderNames.ClientRoad)
	if existing then
		existing:Destroy()
	end
end

local function descriptorValue(root)
	local roadFolder = root:FindFirstChild(WorldConstants.FolderNames.Road)
	if not roadFolder then
		return nil
	end

	local descriptor = roadFolder:FindFirstChild(WorldConstants.ValueNames.LoopDescriptor)
	if descriptor and descriptor:IsA("StringValue") then
		return descriptor
	end

	return nil
end

local function shouldRender(root)
	local overlayEnabled = root:GetAttribute(WorldConstants.Attributes.ClientRoadOverlay)
	if overlayEnabled == nil then
		return RunService:IsStudio()
	end

	return overlayEnabled == true
end

local function render(root)
	destroyLocalRoad(root)
	if not shouldRender(root) then
		return
	end

	local descriptor = descriptorValue(root)
	if not descriptor or descriptor.Value == "" then
		return
	end

	local decodeOk, renderLoop = pcall(function()
		return WorldSerialization.decodeRoadLoop(descriptor.Value)
	end)
	if not decodeOk then
		warn(("WorldGenClientRenderer failed to decode road loop descriptor for %s: %s"):format(root:GetFullName(), tostring(renderLoop)))
		return
	end

	local renderProfile = nil
	if renderLoop.RoadWidth == nil then
		local profileId = root:GetAttribute(WorldConstants.Attributes.ProfileId) or renderLoop.ProfileId
		if profileId then
			local profileOk, resolvedProfile = pcall(function()
				return WorldProfile.resolve(profileId)
			end)
			if profileOk then
				renderProfile = resolvedProfile
			end
		end
	end

	local specOk, ribbonSpec = pcall(function()
		return RoadRibbonSpec.fromLoop(renderLoop, renderProfile)
	end)
	if not specOk then
		warn(("WorldGenClientRenderer failed to rebuild road ribbon for %s: %s"):format(root:GetFullName(), tostring(ribbonSpec)))
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = WorldConstants.FolderNames.ClientRoad
	folder.Parent = root
	folder:SetAttribute("RenderMode", "ClientRoad")

	RoadRenderBuilder.build(folder, "ClientRoadSurface", ribbonSpec, {
		Color = Color3.fromRGB(66, 63, 58),
		Transparency = 0.08,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		CenterOffset = Vector3.new(0, WorldConstants.ClientRoadLift, 0),
	})
end

function WorldGenClientRenderer.attach(root)
	if attached[root] then
		return attached[root]
	end

	attached[root] = true
	render(root)

	root:GetAttributeChangedSignal(WorldConstants.Attributes.ClientRoadOverlay):Connect(function()
		if root.Parent then
			render(root)
		end
	end)

	local function bindDescriptorSignals()
		local descriptor = descriptorValue(root)
		if descriptor then
			descriptor:GetPropertyChangedSignal("Value"):Connect(function()
				if root.Parent then
					render(root)
				end
			end)
			return true
		end
		return false
	end

	if not bindDescriptorSignals() then
		root.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("StringValue") and descendant.Name == WorldConstants.ValueNames.LoopDescriptor then
				bindDescriptorSignals()
				if root.Parent then
					render(root)
				end
			end
		end)
	end

	root.AncestryChanged:Connect(function(_, parent)
		if not parent then
			attached[root] = nil
		end
	end)

	return root
end

return WorldGenClientRenderer
