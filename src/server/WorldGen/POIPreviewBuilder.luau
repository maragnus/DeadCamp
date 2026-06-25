local WorldGenShared = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WorldGen")

local WorldConstants = require(WorldGenShared:WaitForChild("WorldConstants"))
local WorldMath = require(WorldGenShared:WaitForChild("WorldMath"))

local POIPreviewBuilder = {}

local DEBUG_LIFT = 2

local SIZE_COLORS = {
	[WorldConstants.SizeClasses.Small] = Color3.fromRGB(116, 152, 116),
	[WorldConstants.SizeClasses.Medium] = Color3.fromRGB(170, 150, 89),
	[WorldConstants.SizeClasses.Large] = Color3.fromRGB(174, 115, 92),
}

local ACCESS_COLORS = {
	[WorldConstants.AccessTypes.RoadEdge] = Color3.fromRGB(208, 183, 92),
	[WorldConstants.AccessTypes.DriveUp] = Color3.fromRGB(86, 86, 84),
	[WorldConstants.AccessTypes.WalkUp] = Color3.fromRGB(88, 99, 76),
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
	local forward = WorldMath.forwardFromRotation(rotation)
	local right = WorldMath.rightFromRotation(rotation)
	return right, forward
end

local function liftedCenter(surfaceHeight, sizeY)
	return surfaceHeight + DEBUG_LIFT + sizeY * 0.5
end

function POIPreviewBuilder.build(parent, parcels, sampleSurfaceHeight)
	for _, parcel in ipairs(parcels or {}) do
		local center = Vector3.new(parcel.Center[1], parcel.Center[2], parcel.Center[3])
		local entryPoint = Vector3.new(parcel.EntryPoint[1], parcel.EntryPoint[2], parcel.EntryPoint[3])
		local padSize = parcel.PadSize
		local reserveSize = parcel.ReserveSize
		local rotation = parcel.Rotation
		local color = SIZE_COLORS[parcel.SizeClass] or Color3.fromRGB(135, 135, 135)
		local padSurface = sampleSurfaceHeight(center.X, center.Z)
		local padHeight = 1
		local padCFrame = CFrame.new(center.X, liftedCenter(padSurface, padHeight), center.Z) * CFrame.Angles(0, rotation, 0)
		local pad = createPreviewPart(parent, parcel.Id .. "_Pad", Vector3.new(padSize.X, padHeight, padSize.Y), padCFrame, color, 0.2)
		pad:SetAttribute("SizeClass", parcel.SizeClass)
		pad:SetAttribute("AccessType", parcel.AccessType)
		pad:SetAttribute("FlatteningCost", parcel.FlatteningCost)
		pad:SetAttribute("ShortcutRisk", parcel.ShortcutRisk)

		local reserveHeight = 0.35
		local reserveSurface = sampleSurfaceHeight(center.X, center.Z)
		local reserve = createPreviewPart(
			parent,
			parcel.Id .. "_Reserve",
			Vector3.new(reserveSize.X, reserveHeight, reserveSize.Y),
			CFrame.new(center.X, liftedCenter(reserveSurface, reserveHeight), center.Z) * CFrame.Angles(0, rotation, 0),
			color,
			0.72
		)
		reserve:SetAttribute("PreviewRole", "Reserve")

		if parcel.AccessType ~= WorldConstants.AccessTypes.RoadEdge then
			local direction = center - entryPoint
			local length = math.max(10, direction.Magnitude)
			local accessCenter = entryPoint:Lerp(center, 0.5)
			local width = math.max(6, parcel.AccessWidth or 8)
			local accessSurface = sampleSurfaceHeight(accessCenter.X, accessCenter.Z)
			local access = createPreviewPart(
				parent,
				parcel.Id .. "_Access",
				Vector3.new(width, 0.45, length),
				CFrame.lookAt(
					Vector3.new(accessCenter.X, liftedCenter(accessSurface, 0.45), accessCenter.Z),
					Vector3.new(center.X, liftedCenter(accessSurface, 0.45), center.Z),
					Vector3.yAxis
				),
				ACCESS_COLORS[parcel.AccessType] or Color3.fromRGB(86, 86, 84),
				0.15
			)
			access:SetAttribute("PreviewRole", parcel.AccessType == WorldConstants.AccessTypes.DriveUp and "DriveUpApron" or "WalkPath")
		else
			local edgeDirection = Vector3.new(entryPoint.X - center.X, 0, entryPoint.Z - center.Z)
			if edgeDirection.Magnitude <= 1e-4 then
				local right, _ = vectorsFromRotation(rotation)
				edgeDirection = -right
			else
				edgeDirection = edgeDirection.Unit
			end
			local edgePoint = center + edgeDirection * (reserveSize.X * 0.5 - 2)
			local edgeSurface = sampleSurfaceHeight(edgePoint.X, edgePoint.Z)
			local edgeMarker = createPreviewPart(
				parent,
				parcel.Id .. "_RoadEdge",
				Vector3.new(5, 0.6, math.max(12, padSize.Y * 0.2)),
				CFrame.new(edgePoint.X, liftedCenter(edgeSurface, 0.6), edgePoint.Z) * CFrame.Angles(0, rotation, 0),
				ACCESS_COLORS[WorldConstants.AccessTypes.RoadEdge],
				0.18
			)
			edgeMarker:SetAttribute("PreviewRole", "RoadEdge")
		end
	end
end

return POIPreviewBuilder
