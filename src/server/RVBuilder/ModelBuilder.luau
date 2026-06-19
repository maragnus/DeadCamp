-- Thin wrapper around Roblox Instances so vehicle modules describe geometry with bounds.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounds = require(Shared:WaitForChild("RVBounds"))
local ShapePrimitives = require(Shared:WaitForChild("RVShapePrimitives"))

local ModelBuilder = {}
ModelBuilder.__index = ModelBuilder
ModelBuilder.Bounds = Bounds
ModelBuilder.ShapePrimitives = ShapePrimitives

local SERVICES = {
	Workspace = Workspace,
	ReplicatedStorage = ReplicatedStorage,
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayer = game:GetService("StarterPlayer"),
}

local function setAttributes(instance, values)
	for key, value in pairs(values or {}) do
		instance:SetAttribute(key, value)
	end
end

local function addTags(instance, tags)
	CollectionService:AddTag(instance, "RVComponent")
	for _, tagName in ipairs(tags or {}) do
		CollectionService:AddTag(instance, tagName)
	end
end

local function copyTable(values)
	local result = {}
	for key, value in pairs(values or {}) do
		result[key] = value
	end
	return result
end

local function resolvePath(path)
	if typeof(path) == "Instance" then
		return path
	end
	if type(path) ~= "string" then
		return nil
	end

	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		if token == "game" then
			current = game
		elseif current == game and SERVICES[token] then
			current = SERVICES[token]
		else
			current = current:FindFirstChild(token)
		end

		if not current then
			return nil
		end
	end

	return current
end

local function wedgeSizeFromBounds(partBounds, slope)
	local size = Bounds.size(partBounds)
	if slope == ShapePrimitives.WedgeSlope.TopLeft or slope == ShapePrimitives.WedgeSlope.TopRight then
		return Vector3.new(size.Z, size.Y, size.X)
	end
	return size
end

local function cylinderSizeFromBounds(partBounds, axis)
	local size = Bounds.size(partBounds)
	if axis == ShapePrimitives.CylinderAxis.Width then
		return Vector3.new(size.Y, size.X, size.Z)
	elseif axis == ShapePrimitives.CylinderAxis.Length then
		return Vector3.new(size.X, size.Z, size.Y)
	end
	return size
end

local WEDGE_ROTATIONS = {
	[ShapePrimitives.WedgeSlope.TopFront] = CFrame.new(),
	[ShapePrimitives.WedgeSlope.TopBack] = CFrame.Angles(math.rad(180), 0, 0),
	[ShapePrimitives.WedgeSlope.TopLeft] = CFrame.Angles(0, math.rad(90), 0),
	[ShapePrimitives.WedgeSlope.TopRight] = CFrame.Angles(0, math.rad(-90), 0),
}

local CYLINDER_AXIS_ROTATIONS = {
	[ShapePrimitives.CylinderAxis.Height] = CFrame.new(),
	[ShapePrimitives.CylinderAxis.Width] = CFrame.Angles(0, 0, math.rad(90)),
	[ShapePrimitives.CylinderAxis.Length] = CFrame.Angles(math.rad(90), 0, 0),
}

local function tiltRotation(axis, tilt)
	if not tilt then
		return CFrame.new()
	end
	if axis ~= ShapePrimitives.CylinderAxis.Height then
		error("Cylinder tilt currently supports Height axis only; add the needed case before using it.", 3)
	end

	local degrees = tilt.Degrees or 0
	if tilt.Toward == ShapePrimitives.Direction.Back then
		return CFrame.Angles(math.rad(degrees), 0, 0)
	elseif tilt.Toward == ShapePrimitives.Direction.Front then
		return CFrame.Angles(math.rad(-degrees), 0, 0)
	elseif tilt.Toward == ShapePrimitives.Direction.Left then
		return CFrame.Angles(0, 0, math.rad(degrees))
	elseif tilt.Toward == ShapePrimitives.Direction.Right then
		return CFrame.Angles(0, 0, math.rad(-degrees))
	end

	error(("Unknown cylinder tilt direction: %s"):format(tostring(tilt.Toward)), 3)
end

local function wedgeCFrameFromBounds(partBounds, slope)
	local cframeFromBounds = ShapePrimitives.wedgeCFrameFromBounds or ShapePrimitives.wedgeCFrame
	if cframeFromBounds then
		local ok, result = pcall(cframeFromBounds, partBounds, slope)
		if ok then
			return result
		end
	end
	return Bounds.cframe(partBounds, WEDGE_ROTATIONS[slope])
end

local function cylinderCFrameFromBounds(partBounds, axis, tilt)
	local cframeFromBounds = ShapePrimitives.cylinderCFrameFromBounds or ShapePrimitives.cylinderCFrame
	if cframeFromBounds then
		local ok, result = pcall(cframeFromBounds, partBounds, axis, tilt)
		if ok then
			return result
		end
	end
	return Bounds.cframe(partBounds, CYLINDER_AXIS_ROTATIONS[axis] * tiltRotation(axis, tilt))
end

function ModelBuilder.destroyExisting(outputName)
	local existing = Workspace:FindFirstChild(outputName)
	if existing then
		existing:Destroy()
	end
end

function ModelBuilder.new(config)
	return setmetatable({
		Config = config,
		Colors = config.Colors,
	}, ModelBuilder)
end

function ModelBuilder:color(value)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "string" then
		return self.Colors[value] or self.Colors.Body
	end
	return self.Colors.Body
end

function ModelBuilder:folder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function ModelBuilder:style(colorName, overrides)
	local style = copyTable(overrides)
	style.Color = self:color(colorName or style.Color or style.ColorName)
	return style
end

function ModelBuilder:configure(part, style)
	local resolvedStyle = style or {}
	part.Anchored = resolvedStyle.Anchored ~= false
	part.CanCollide = resolvedStyle.CanCollide ~= false
	part.CanTouch = resolvedStyle.CanTouch == true
	part.CanQuery = resolvedStyle.CanQuery ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = self:color(resolvedStyle.Color or resolvedStyle.ColorName)
	part.Material = resolvedStyle.Material or Enum.Material.SmoothPlastic
	part.Transparency = resolvedStyle.Transparency or 0

	setAttributes(part, resolvedStyle.Meta)
	addTags(part, resolvedStyle.Tags)
	return part
end

function ModelBuilder:part(parent, name, partBounds, style, rotation)
	if not Bounds.isValid(partBounds) then
		return nil
	end

	local className = style and style.ClassName or "Part"
	local part = Instance.new(className)
	part.Name = name
	part.Size = Bounds.size(partBounds)
	part.CFrame = Bounds.cframe(partBounds, rotation)
	if style and style.Shape then
		part.Shape = style.Shape
	end
	self:configure(part, style)
	part.Parent = parent
	return part
end

function ModelBuilder:wedge(parent, name, partBounds, slope, style)
	if not Bounds.isValid(partBounds) then
		return nil
	end

	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = wedgeSizeFromBounds(partBounds, slope)
	part.CFrame = wedgeCFrameFromBounds(partBounds, slope)
	self:configure(part, style)
	part.Parent = parent
	return part
end

function ModelBuilder:cylinder(parent, name, partBounds, axis, style, tilt)
	if not Bounds.isValid(partBounds) then
		return nil
	end

	local part = Instance.new("Part")
	part.Name = name
	part.Size = cylinderSizeFromBounds(partBounds, axis)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = cylinderCFrameFromBounds(partBounds, axis, tilt)
	self:configure(part, style)
	part.Parent = parent
	return part
end

function ModelBuilder:prompt(parent, objectText, holdDuration)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenClosePrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = holdDuration or 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function ModelBuilder:tryUnion(parent, name, pieces, meta)
	local parts = {}
	for _, item in ipairs(pieces) do
		if item and item:IsA("BasePart") then
			parts[#parts + 1] = item
		end
	end
	if #parts == 0 then
		return nil
	end
	if #parts == 1 then
		parts[1].Name = name
		setAttributes(parts[1], meta)
		return parts[1]
	end

	local root = parts[1]
	local others = {}
	for index = 2, #parts do
		others[#others + 1] = parts[index]
	end

	local ok, result = pcall(function()
		return root:UnionAsync(others)
	end)

	if ok and result then
		result.Name = name
		result.Color = root.Color
		result.Material = root.Material
		result.Anchored = true
		result.CanCollide = root.CanCollide
		result.CanTouch = false
		result.CanQuery = true
		result.Parent = parent
		pcall(function()
			result.UsePartColor = true
		end)
		setAttributes(result, meta)
		addTags(result)
		for _, item in ipairs(parts) do
			item:Destroy()
		end
		return result
	end

	local fallback = self:folder(parent, name .. "_Ununioned")
	fallback:SetAttribute("UnionFailed", true)
	for _, item in ipairs(parts) do
		item.Parent = fallback
		setAttributes(item, meta)
	end
	return fallback
end

function ModelBuilder:addGlass(parent, name, partBounds, meta, rotation)
	return self:part(parent, name, partBounds, {
		Color = "Glass",
		Material = Enum.Material.Glass,
		Transparency = 0.38,
		CanCollide = false,
		Meta = meta,
		Tags = { "RVBreakable" },
	}, rotation)
end

function ModelBuilder:addLight(parent, name, partBounds, lightColor, lightType, meta)
	local part = self:part(parent, name, partBounds, {
		Color = lightColor,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Meta = meta,
		Tags = { "RVLight", "RVBreakable" },
	})
	local glow = Instance.new("PointLight")
	glow.Name = lightType .. "Glow"
	glow.Color = lightColor
	glow.Range = lightType == "Headlamp" and 13 or 8
	glow.Brightness = lightType == "Headlamp" and 1.2 or 0.8
	glow.Parent = part
	return part
end

function ModelBuilder:cloneSourceToBounds(sourcePath, parent, name, partBounds, style, rotation)
	local source = resolvePath(sourcePath)
	if not source then
		return nil
	end

	local clone = source:Clone()
	clone.Name = name
	local targetCFrame = Bounds.cframe(partBounds, rotation)
	local targetSize = Bounds.size(partBounds)

	if clone:IsA("BasePart") then
		clone.Size = targetSize
		clone.CFrame = targetCFrame
		self:configure(clone, style)
		clone.Parent = parent
		return clone
	end

	clone.Parent = parent
	if clone:IsA("Model") then
		local currentSize = clone:GetExtentsSize()
		local smallestAxis = math.min(currentSize.X, currentSize.Y, currentSize.Z)
		if smallestAxis > 0 then
			local scale = math.min(targetSize.X / currentSize.X, targetSize.Y / currentSize.Y, targetSize.Z / currentSize.Z)
			clone:ScaleTo(scale)
		end
		clone:PivotTo(targetCFrame)
		setAttributes(clone, style and style.Meta)
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				self:configure(descendant, style)
			end
		end
	end
	return clone
end

return ModelBuilder
