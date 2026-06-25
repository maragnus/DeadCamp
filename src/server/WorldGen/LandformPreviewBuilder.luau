local LandformPreviewBuilder = {}

local function pointFromArray(values)
	return Vector3.new(values[1], values[2], values[3])
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		folder:ClearAllChildren()
		return folder
	end
	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function marker(parent, name, size, cframe, color, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency or 0
	part.Size = size
	part.CFrame = cframe
	part.Parent = parent
	return part
end

local function segmentPart(parent, name, startPoint, endPoint, thickness, color, yOffset)
	local liftedStart = startPoint + Vector3.new(0, yOffset, 0)
	local liftedEnd = endPoint + Vector3.new(0, yOffset, 0)
	local length = (liftedEnd - liftedStart).Magnitude
	if length <= 0.05 then
		return nil
	end

	return marker(
		parent,
		name,
		Vector3.new(thickness, thickness, length),
		CFrame.lookAt((liftedStart + liftedEnd) * 0.5, liftedEnd, Vector3.yAxis),
		color,
		0.18
	)
end

function LandformPreviewBuilder.build(parent, descriptor, sampleSurfaceHeight)
	local root = ensureFolder(parent, "LandformPreview")
	local riverFolder = ensureFolder(root, "River")
	local ridgeFolder = ensureFolder(root, "Ridges")
	local basinFolder = ensureFolder(root, "Basin")

	for sampleIndex = 1, math.max(0, #(descriptor.River and descriptor.River.Samples or {}) - 1) do
		local sample = descriptor.River.Samples[sampleIndex]
		local nextSample = descriptor.River.Samples[sampleIndex + 1]
		local startPoint = pointFromArray(sample.Position)
		local endPoint = pointFromArray(nextSample.Position)
		local surfaceY = sampleSurfaceHeight and sampleSurfaceHeight(startPoint.X, startPoint.Z) or sample.WaterY
		local centerYOffset = math.max(sample.WaterY, surfaceY) + 2.5 - startPoint.Y
		local right = pointFromArray(sample.Right)
		local leftBank = startPoint - right * sample.BankHalfWidth
		local rightBank = startPoint + right * sample.BankHalfWidth

		segmentPart(riverFolder, ("Center_%03d"):format(sampleIndex), startPoint, endPoint, 2, Color3.fromRGB(61, 149, 231), centerYOffset)
		marker(
			riverFolder,
			("LeftBank_%03d"):format(sampleIndex),
			Vector3.new(2, 2, 2),
			CFrame.new(leftBank + Vector3.new(0, sample.WaterY + 2.2, 0)),
			Color3.fromRGB(120, 197, 140),
			0.25
		)
		marker(
			riverFolder,
			("RightBank_%03d"):format(sampleIndex),
			Vector3.new(2, 2, 2),
			CFrame.new(rightBank + Vector3.new(0, sample.WaterY + 2.2, 0)),
			Color3.fromRGB(120, 197, 140),
			0.25
		)
	end

	for ridgeIndex, ridge in ipairs(descriptor.Ridges or {}) do
		local startPoint = pointFromArray(ridge.Start)
		local endPoint = pointFromArray(ridge.Finish)
		local startY = sampleSurfaceHeight and sampleSurfaceHeight(startPoint.X, startPoint.Z) or 0
		local endY = sampleSurfaceHeight and sampleSurfaceHeight(endPoint.X, endPoint.Z) or 0
		segmentPart(
			ridgeFolder,
			("Ridge_%02d"):format(ridgeIndex),
			Vector3.new(startPoint.X, startY, startPoint.Z),
			Vector3.new(endPoint.X, endY, endPoint.Z),
			5,
			Color3.fromRGB(233, 183, 90),
			4.5
		)
	end

	local basinCenter = pointFromArray(descriptor.Basin.Center)
	local basinY = sampleSurfaceHeight and sampleSurfaceHeight(basinCenter.X, basinCenter.Z) or 0
	marker(
		basinFolder,
		"BasinCenter",
		Vector3.new(descriptor.Basin.RadiusX * 0.4, 1, descriptor.Basin.RadiusZ * 0.4),
		CFrame.new(basinCenter.X, basinY + 3, basinCenter.Z),
		Color3.fromRGB(145, 117, 223),
		0.55
	)

	return root
end

return LandformPreviewBuilder
