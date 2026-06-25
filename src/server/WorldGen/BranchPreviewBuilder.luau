local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldGenShared = Shared:WaitForChild("WorldGen")

local RoadRenderBuilder = require(WorldGenShared:WaitForChild("RoadRenderBuilder"))
local RoadRibbonSpec = require(WorldGenShared:WaitForChild("RoadRibbonSpec"))
local WorldConstants = require(WorldGenShared:WaitForChild("WorldConstants"))

local BranchPreviewBuilder = {}

local function descriptorSamples(branch)
	local samples = {}

	for _, sample in ipairs(branch.Samples or {}) do
		samples[#samples + 1] = {
			Position = Vector3.new(sample.Position[1], sample.Position[2], sample.Position[3]),
			Tangent = Vector3.new(sample.Tangent[1], sample.Tangent[2], sample.Tangent[3]),
			Right = Vector3.new(sample.Right[1], sample.Right[2], sample.Right[3]),
			Up = Vector3.new(sample.Up[1], sample.Up[2], sample.Up[3]),
			Curvature = sample.Curvature,
			LapDistance = sample.LapDistance,
		}
	end

	return samples
end

function BranchPreviewBuilder.build(parent, branches, roadWidth)
	for _, branch in ipairs(branches or {}) do
		local branchFolder = Instance.new("Folder")
		branchFolder.Name = branch.Id
		branchFolder.Parent = parent
		branchFolder:SetAttribute("BranchType", branch.Type)

		local ribbonSpec = RoadRibbonSpec.fromSamples("Branch", 0, descriptorSamples(branch), (branch.HalfWidth or (roadWidth * WorldConstants.BranchRoadWidthScale * 0.5)) * 2, {
			Closed = false,
			ChunkPrefix = branch.Id,
		})

		local color
		if branch.Type == WorldConstants.BranchTypes.ServiceSpur then
			color = Color3.fromRGB(77, 72, 67)
		elseif branch.Template == "HookBack" then
			color = Color3.fromRGB(98, 89, 82)
		elseif branch.Template == "ReverseTurn" then
			color = Color3.fromRGB(102, 86, 86)
		else
			color = Color3.fromRGB(89, 84, 79)
		end
		RoadRenderBuilder.build(branchFolder, "Road", ribbonSpec, {
			Color = color,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})

		if branch.Blocked and branch.Blocker then
			local blockerPoint = Vector3.new(branch.Blocker.Position[1], branch.Blocker.Position[2], branch.Blocker.Position[3])
			local lookAt = Vector3.new(branch.Blocker.LookAt[1], branch.Blocker.LookAt[2], branch.Blocker.LookAt[3])
			local blocker = Instance.new("Part")
			blocker.Name = "Blocker"
			blocker.Anchored = true
			blocker.Material = Enum.Material.Slate
			blocker.Color = Color3.fromRGB(78, 77, 73)
			blocker.Size = Vector3.new(roadWidth * 0.82, 8, 14)
			blocker.CFrame = CFrame.lookAt(blockerPoint + Vector3.new(0, 4, 0), lookAt + Vector3.new(0, 4, 0), Vector3.yAxis)
			blocker.Parent = branchFolder
		end
	end
end

return BranchPreviewBuilder
