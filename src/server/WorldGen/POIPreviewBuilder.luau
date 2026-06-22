local WorldConstants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WorldGen"):WaitForChild("WorldConstants"))

local POIPreviewBuilder = {}

local SIZE_COLORS = {
	[WorldConstants.SizeClasses.Small] = Color3.fromRGB(116, 152, 116),
	[WorldConstants.SizeClasses.Medium] = Color3.fromRGB(170, 150, 89),
	[WorldConstants.SizeClasses.Large] = Color3.fromRGB(174, 115, 92),
}

local function createPreviewPart(parent, name, size, cframe, color, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Transparency = transparency or 0
	part.Parent = parent
	return part
end

local function vectorsFromRotation(rotation)
	local forward = Vector3.new(math.sin(rotation), 0, math.cos(rotation))
	local right = Vector3.new(forward.Z, 0, -forward.X)
	return right, forward
end

function POIPreviewBuilder.build(parent, parcels)
	for _, parcel in ipairs(parcels or {}) do
		local center = Vector3.new(parcel.Center[1], parcel.Center[2], parcel.Center[3])
		local entryPoint = Vector3.new(parcel.EntryPoint[1], parcel.EntryPoint[2], parcel.EntryPoint[3])
		local padSize = parcel.PadSize
		local reserveSize = parcel.ReserveSize
		local rotation = parcel.Rotation
		local color = SIZE_COLORS[parcel.SizeClass] or Color3.fromRGB(135, 135, 135)
		local padCFrame = CFrame.new(center + Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, rotation, 0)
		local pad = createPreviewPart(parent, parcel.Id .. "_Pad", Vector3.new(padSize.X, 1, padSize.Y), padCFrame, color, 0.25)
		pad:SetAttribute("SizeClass", parcel.SizeClass)
		pad:SetAttribute("AccessType", parcel.AccessType)
		pad:SetAttribute("FlatteningCost", parcel.FlatteningCost)
		pad:SetAttribute("ShortcutRisk", parcel.ShortcutRisk)

		local reserve = createPreviewPart(parent, parcel.Id .. "_Reserve", Vector3.new(reserveSize.X, 0.25, reserveSize.Y), CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, rotation, 0), color, 0.75)
		reserve:SetAttribute("PreviewRole", "Reserve")

		if parcel.AccessType == WorldConstants.AccessTypes.DriveUp then
			local direction = center - entryPoint
			local length = math.max(20, direction.Magnitude)
			local apronCenter = entryPoint:Lerp(center, 0.45)
			local apron = createPreviewPart(
				parent,
				parcel.Id .. "_Apron",
				Vector3.new(math.min(padSize.X * 0.55, 18), 0.8, length),
				CFrame.lookAt(apronCenter + Vector3.new(0, 0.45, 0), center + Vector3.new(0, 0.45, 0), Vector3.yAxis),
				Color3.fromRGB(86, 86, 84),
				0.15
			)
			apron:SetAttribute("PreviewRole", "DriveUpApron")
		else
			local _, forward = vectorsFromRotation(rotation)
			local pathCenter = entryPoint:Lerp(center, 0.5)
			local pathLength = math.max(10, (center - entryPoint).Magnitude)
			local walkPath = createPreviewPart(
				parent,
				parcel.Id .. "_WalkPath",
				Vector3.new(8, 0.35, pathLength),
				CFrame.lookAt(pathCenter + Vector3.new(0, 0.2, 0), center + forward * 5 + Vector3.new(0, 0.2, 0), Vector3.yAxis),
				Color3.fromRGB(88, 99, 76),
				0.25
			)
			walkPath:SetAttribute("PreviewRole", "WalkPath")
		end
	end
end

return POIPreviewBuilder
