local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local WorldGenShared = Shared:WaitForChild("WorldGen")

local RoadNetworkBuilder = require(WorldGenShared:WaitForChild("RoadNetworkBuilder"))
local WorldConstants = require(WorldGenShared:WaitForChild("WorldConstants"))
local WorldProfile = require(WorldGenShared:WaitForChild("WorldProfile"))
local WorldSerialization = require(WorldGenShared:WaitForChild("WorldSerialization"))

local WorldGenClientRenderer = {}

local attached = {}

local function runRenderStep(stepName, root, callback)
	local ok, result = pcall(callback)
	if not ok then
		error(("WorldGenClientRenderer failed to %s for %s: %s"):format(stepName, root:GetFullName(), tostring(result)), 0)
	end
	return result
end

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

	local descriptor = roadFolder:FindFirstChild(WorldConstants.ValueNames.RoadNetworkDescriptor)
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

local function terrainSurfaceHeight(root, x, z, fallbackY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = false

	local result = Workspace:Raycast(Vector3.new(x, 512, z), Vector3.new(0, -1024, 0), params)
	if result then
		return result.Position.Y
	end

	return fallbackY
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

	local renderNetwork = runRenderStep("decode road network descriptor", root, function()
		return WorldSerialization.decodeRoadNetwork(descriptor.Value)
	end)

	local profileId = root:GetAttribute(WorldConstants.Attributes.ProfileId) or renderNetwork.ProfileId
	local renderProfile = nil
	if profileId ~= nil then
		renderProfile = runRenderStep(("resolve world profile %s"):format(tostring(profileId)), root, function()
			return WorldProfile.resolve(profileId)
		end)
	end
	if not renderProfile then
		renderProfile = WorldProfile.resolve(WorldProfile.defaultId())
	end

	runRenderStep("rebuild road network", root, function()
		RoadNetworkBuilder.build(root, WorldConstants.FolderNames.ClientRoad, renderNetwork, renderProfile, {
			SampleSurfaceHeight = function(x, z, sample)
				return terrainSurfaceHeight(root, x, z, sample and sample.Position and sample.Position.Y or 0)
			end,
			PrimaryName = "ClientPrimaryRoadSurface",
			SecondaryName = "ClientSecondaryRoadSurface",
			JunctionName = "ClientIntersectionSurface",
			PrimaryOptions = {
				Color = Color3.fromRGB(96, 150, 101),
				Transparency = 0.08,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			},
			SecondaryOptions = {
				Color = Color3.fromRGB(108, 104, 98),
				Transparency = 0.1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			},
			JunctionOptions = {
				Color = Color3.fromRGB(113, 111, 106),
				Transparency = 0.08,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			},
		})
	end)
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
			if descendant:IsA("StringValue") and descendant.Name == WorldConstants.ValueNames.RoadNetworkDescriptor then
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
