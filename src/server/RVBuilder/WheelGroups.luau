-- Shared wheel-group helpers for build-time layout resolution and runtime animation.

local Layout = require(script.Parent:WaitForChild("Layout"))

local WheelGroups = {}

local function copyTable(values)
	local result = {}
	for key, value in pairs(values or {}) do
		result[key] = value
	end
	return result
end

function WheelGroups.collect(layout)
	local groups = {}
	local firstSection = layout.Sections and layout.Sections[1]

	for _, section in ipairs(layout.Sections) do
		section.WheelGroups = {}

		for _, source in ipairs(section.Wheels or {}) do
			local group = copyTable(source)
			group.Id = group.Id or section.Id .. "Wheel"
			group.ModuleId = section.Id
			group.Section = section
			group.LocalZ = group.LocalZ or 0.5
			group.Z = Layout.localZ(section, group.LocalZ)

			if group.Steerable == nil then
				group.Steerable = section == firstSection
			end

			section.WheelGroups[#section.WheelGroups + 1] = group
			groups[#groups + 1] = group
		end
	end

	return groups
end

function WheelGroups.tagAssembly(model, group, side, axleIndex, wheelIndex, radius, width, axleZ)
	model:SetAttribute("WheelGroupId", group.Id)
	model:SetAttribute("WheelSide", side)
	model:SetAttribute("WheelAxleIndex", axleIndex)
	model:SetAttribute("WheelIndex", wheelIndex)
	model:SetAttribute("WheelRadius", radius)
	model:SetAttribute("WheelWidth", width)
	model:SetAttribute("WheelAxleZ", axleZ)
	model:SetAttribute("WheelSteerable", group.Steerable == true)
end

local function runtimeAssembly(driveRoot, model)
	local tire = model:FindFirstChild("Tire")
	if not tire or not tire:IsA("BasePart") then
		return nil
	end

	local rim = model:FindFirstChild("Rim")
	if rim and not rim:IsA("BasePart") then
		rim = nil
	end

	local tireBaseLocalCFrame = driveRoot.CFrame:ToObjectSpace(tire.CFrame)
	local rimBaseLocalCFrame = rim and driveRoot.CFrame:ToObjectSpace(rim.CFrame) or nil

	return {
		Model = model,
		Tire = tire,
		Rim = rim,
		GroupId = model:GetAttribute("WheelGroupId"),
		Side = model:GetAttribute("WheelSide") or 0,
		AxleIndex = model:GetAttribute("WheelAxleIndex") or 1,
		WheelIndex = model:GetAttribute("WheelIndex") or 1,
		Radius = model:GetAttribute("WheelRadius") or (tire.Size.Z * 0.5),
		Width = model:GetAttribute("WheelWidth") or tire.Size.X,
		AxleZ = model:GetAttribute("WheelAxleZ") or tire.Position.Z,
		Steerable = model:GetAttribute("WheelSteerable") == true,
		LocalCenter = tireBaseLocalCFrame.Position,
		TireBaseLocalCFrame = tireBaseLocalCFrame,
		RimBaseLocalCFrame = rimBaseLocalCFrame,
	}
end

function WheelGroups.runtimeAssemblies(rv, driveRoot)
	local wheelsFolder = rv:FindFirstChild("Wheels")
	if not wheelsFolder then
		return {}
	end

	local assemblies = {}
	for _, child in ipairs(wheelsFolder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("PartRole") == "WheelAssembly" then
			local descriptor = runtimeAssembly(driveRoot, child)
			if descriptor then
				assemblies[#assemblies + 1] = descriptor
			end
		end
	end

	table.sort(assemblies, function(a, b)
		if a.AxleZ ~= b.AxleZ then
			return a.AxleZ < b.AxleZ
		end
		if a.Side ~= b.Side then
			return a.Side < b.Side
		end
		return a.WheelIndex < b.WheelIndex
	end)

	return assemblies
end

return WheelGroups
