local Workspace = game:GetService("Workspace")

local WorldGenClientRenderer = require(script.Parent:WaitForChild("WorldGen"):WaitForChild("WorldGenClientRenderer"))
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local WorldConstants = require(Shared:WaitForChild("WorldGen"):WaitForChild("WorldConstants"))

local ROOT_NAMES = {
	[WorldConstants.RootNames.Studio] = true,
	[WorldConstants.RootNames.Runtime] = true,
}

local function tryAttach(instance)
	if (instance:IsA("Folder") or instance:IsA("Model")) and ROOT_NAMES[instance.Name] then
		WorldGenClientRenderer.attach(instance)
	end
end

for _, child in ipairs(Workspace:GetChildren()) do
	tryAttach(child)
end

Workspace.ChildAdded:Connect(function(child)
	tryAttach(child)
end)
