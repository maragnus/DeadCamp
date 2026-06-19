-- Dead Camp RV v6 bounds-clean scaffold.
-- Clones original RV_BaseCamp and applies narrowly targeted wheel wells / floor notches / engine bay fixes.

local Workspace = game:GetService("Workspace")

local OUTPUT_NAME = "RV_BaseCamp_v6_BoundsClean"
for _, name in ipairs({
	"RV_BaseCamp_v2_Candidate",
	"RV_BaseCamp_v3_Handbuilt",
	"RV_BaseCamp_v4_Scaffold",
	"RV_BaseCamp_v5_CleanScaffold",
	OUTPUT_NAME,
}) do
	local existing = Workspace:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

local source = Workspace:WaitForChild("RV_BaseCamp"):WaitForChild("Generated"):WaitForChild("RV_BaseCamp")
local rv = source:Clone()
rv.Name = OUTPUT_NAME
rv.Parent = Workspace
rv:PivotTo(source:GetPivot() * CFrame.new(28, 0, 0))

local oldManual = rv:FindFirstChild("ManualRequirements")
if oldManual then
	oldManual:Destroy()
end

local frame, bboxSize = rv:GetBoundingBox()

local function ensureFolder(parent, name)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local scaffold = ensureFolder(rv, "BuildScaffold")
local wheelFolder = ensureFolder(scaffold, "WheelWells")
local floorFolder = ensureFolder(scaffold, "SegmentedFloors")
local engineFolder = ensureFolder(scaffold, "EngineBay")
local guideFolder = ensureFolder(scaffold, "SectionGuides")

local function localPoint(worldPoint)
	return frame:PointToObjectSpace(worldPoint)
end

local function localCFrame(world)
	return frame:ToObjectSpace(world)
end

local function worldCFrame(localCf)
	return frame * localCf
end

local function bounds(center, size)
	local half = size * 0.5
	return {
		x0 = center.X - half.X,
		x1 = center.X + half.X,
		y0 = center.Y - half.Y,
		y1 = center.Y + half.Y,
		z0 = center.Z - half.Z,
		z1 = center.Z + half.Z,
	}
end

local function partBounds(part)
	return bounds(localPoint(part.Position), part.Size)
end

local function boundsCenter(b)
	return Vector3.new((b.x0 + b.x1) * 0.5, (b.y0 + b.y1) * 0.5, (b.z0 + b.z1) * 0.5)
end

local function boundsSize(b)
	return Vector3.new(math.max(0.001, b.x1 - b.x0), math.max(0.001, b.y1 - b.y0), math.max(0.001, b.z1 - b.z0))
end

local function box(parent, name, b, color, material, canCollide)
	if b.x1 <= b.x0 or b.y1 <= b.y0 or b.z1 <= b.z0 then
		return nil
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Size = boundsSize(b)
	p.CFrame = worldCFrame(CFrame.new(boundsCenter(b)))
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = canCollide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function wedge(parent, name, b, color, material, localRotation)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = boundsSize(b)
	p.CFrame = worldCFrame(CFrame.new(boundsCenter(b)) * (localRotation or CFrame.identity))
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function hide(part, reason)
	if part and part:IsA("BasePart") then
		part.Transparency = 1
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part:SetAttribute("V6ReplacedBy", reason)
	end
end

local function overlaps(a0, a1, b0, b1)
	return a0 < b1 and a1 > b0
end

local function target(path)
	local current = rv
	for name in string.gmatch(path, "[^%.]+") do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function floorMetrics(floorPart)
	local b = partBounds(floorPart)
	return {
		bounds = b,
		top = b.y1,
		bottom = b.y0,
		thickness = b.y1 - b.y0,
		color = floorPart.Color,
		material = floorPart.Material,
	}
end

local function wheelCut(wheel, floor)
	local c = localPoint(wheel.Position)
	local radius = math.max(wheel.Size.Y, wheel.Size.Z) * 0.5
	local clearance = 0.25
	local top = c.Y + radius + clearance
	return {
		center = c,
		side = c.X < 0 and -1 or 1,
		z0 = c.Z - radius - clearance,
		z1 = c.Z + radius + clearance,
		y0 = floor.top,
		y1 = math.max(floor.top + 0.4, top),
		radius = radius,
	}
end

local function emitWallWell(sourcePart, wheelName, cut)
	local b = partBounds(sourcePart)
	local color = sourcePart.Color
	local material = sourcePart.Material
	local prefix = sourcePart.Name .. "_" .. wheelName
	local corner = math.min(0.8, (cut.z1 - cut.z0) * 0.18, math.max(0.3, cut.y1 - cut.y0))

	hide(sourcePart, "V6 simple wheel cutout")

	box(wheelFolder, prefix .. "_WallBefore", {
		x0 = b.x0, x1 = b.x1,
		y0 = b.y0, y1 = b.y1,
		z0 = b.z0, z1 = math.min(cut.z0, b.z1),
	}, color, material, true)
	box(wheelFolder, prefix .. "_WallAfter", {
		x0 = b.x0, x1 = b.x1,
		y0 = b.y0, y1 = b.y1,
		z0 = math.max(cut.z1, b.z0), z1 = b.z1,
	}, color, material, true)
	box(wheelFolder, prefix .. "_WallAboveWheel", {
		x0 = b.x0, x1 = b.x1,
		y0 = cut.y1, y1 = b.y1,
		z0 = math.max(cut.z0 + corner, b.z0), z1 = math.min(cut.z1 - corner, b.z1),
	}, color, material, true)

	-- The corner pieces are WedgeParts and fill the upper corners of the cutout.
	wedge(wheelFolder, prefix .. "_FrontCornerWedge", {
		x0 = b.x0, x1 = b.x1,
		y0 = cut.y0, y1 = cut.y1,
		z0 = math.max(cut.z0, b.z0), z1 = math.min(cut.z0 + corner, b.z1),
	}, color, material, CFrame.Angles(math.rad(cut.side < 0 and 0 or 180), 0, 0))
	wedge(wheelFolder, prefix .. "_RearCornerWedge", {
		x0 = b.x0, x1 = b.x1,
		y0 = cut.y0, y1 = cut.y1,
		z0 = math.max(cut.z1 - corner, b.z0), z1 = math.min(cut.z1, b.z1),
	}, color, material, CFrame.Angles(math.rad(cut.side < 0 and 180 or 0), 0, 0))
end

local function emitWheelTub(wheelName, wallPart, cut)
	local wall = partBounds(wallPart)
	local side = cut.side
	local skinInnerX = side < 0 and wall.x1 or wall.x0
	local depth = 1.9
	local tubInnerX = skinInnerX - side * depth
	local x0 = math.min(skinInnerX, tubInnerX)
	local x1 = math.max(skinInnerX, tubInnerX)
	local t = 0.25
	local color = Color3.fromRGB(92, 96, 100)
	local material = Enum.Material.Metal
	local prefix = wheelName .. "_WheelTub"

	box(wheelFolder, prefix .. "_InnerWall", {
		x0 = tubInnerX - t * 0.5, x1 = tubInnerX + t * 0.5,
		y0 = cut.y0, y1 = cut.y1,
		z0 = cut.z0, z1 = cut.z1,
	}, color, material, true)
	box(wheelFolder, prefix .. "_Top", {
		x0 = x0, x1 = x1,
		y0 = cut.y1 - t, y1 = cut.y1,
		z0 = cut.z0, z1 = cut.z1,
	}, color, material, true)
	box(wheelFolder, prefix .. "_FrontWall", {
		x0 = x0, x1 = x1,
		y0 = cut.y0, y1 = cut.y1,
		z0 = cut.z0, z1 = cut.z0 + t,
	}, color, material, true)
	box(wheelFolder, prefix .. "_RearWall", {
		x0 = x0, x1 = x1,
		y0 = cut.y0, y1 = cut.y1,
		z0 = cut.z1 - t, z1 = cut.z1,
	}, color, material, true)
end

local function segmentFloor(floorPart, cuts)
	local b = partBounds(floorPart)
	hide(floorPart, "V6 floor wheel notches")
	local centerWidth = (b.x1 - b.x0) - 4.0

	box(floorFolder, floorPart.Name .. "_CenterWalkway", {
		x0 = -centerWidth * 0.5, x1 = centerWidth * 0.5,
		y0 = b.y0, y1 = b.y1,
		z0 = b.z0, z1 = b.z1,
	}, floorPart.Color, floorPart.Material, true)

	for _, side in ipairs({ -1, 1 }) do
		local x0 = side < 0 and b.x0 or centerWidth * 0.5
		local x1 = side < 0 and -centerWidth * 0.5 or b.x1
		local relevant = {}
		for _, cut in ipairs(cuts) do
			if cut.side == side and overlaps(cut.z0, cut.z1, b.z0, b.z1) then
				relevant[#relevant + 1] = cut
			end
		end
		table.sort(relevant, function(a, c) return a.z0 < c.z0 end)

		local cursor = b.z0
		for index, cut in ipairs(relevant) do
			if cut.z0 > cursor then
				box(floorFolder, floorPart.Name .. (side < 0 and "_Left_" or "_Right_") .. "Span" .. index, {
					x0 = x0, x1 = x1,
					y0 = b.y0, y1 = b.y1,
					z0 = cursor, z1 = cut.z0,
				}, floorPart.Color, floorPart.Material, true)
			end
			cursor = math.max(cursor, cut.z1)
		end
		if cursor < b.z1 then
			box(floorFolder, floorPart.Name .. (side < 0 and "_Left_End" or "_Right_End"), {
				x0 = x0, x1 = x1,
				y0 = b.y0, y1 = b.y1,
				z0 = cursor, z1 = b.z1,
			}, floorPart.Color, floorPart.Material, true)
		end
	end
end

local cab = rv:WaitForChild("Cab")
local living = rv:WaitForChild("LivingBox")
local chassis = rv:WaitForChild("Chassis")
local wheels = rv:WaitForChild("Wheels")

local cabFloor = chassis:WaitForChild("CabFloor")
local boxFloor = chassis:WaitForChild("BoxFloor")
local cabFloorInfo = floorMetrics(cabFloor)
local boxFloorInfo = floorMetrics(boxFloor)

local wheelJobs = {
	{
		wheel = wheels:WaitForChild("WheelFrontLeft"),
		floor = cabFloorInfo,
		walls = { cab:WaitForChild("EngineBayLeft") },
	},
	{
		wheel = wheels:WaitForChild("WheelFrontRight"),
		floor = cabFloorInfo,
		walls = { cab:WaitForChild("EngineBayRight") },
	},
	{
		wheel = wheels:WaitForChild("WheelRearLeft"),
		floor = boxFloorInfo,
		walls = { living:WaitForChild("LeftWallUnderWindow"), living:WaitForChild("LeftWallRearSolid") },
	},
	{
		wheel = wheels:WaitForChild("WheelRearRight"),
		floor = boxFloorInfo,
		walls = { living:WaitForChild("RightWallUnderWindow") },
	},
}

local cabCuts = {}
local boxCuts = {}
for _, job in ipairs(wheelJobs) do
	local cut = wheelCut(job.wheel, job.floor)
	for _, wall in ipairs(job.walls) do
		emitWallWell(wall, job.wheel.Name, cut)
	end
	emitWheelTub(job.wheel.Name, job.walls[1], cut)

	if job.floor == cabFloorInfo then
		cabCuts[#cabCuts + 1] = cut
	else
		boxCuts[#boxCuts + 1] = cut
	end
end

segmentFloor(cabFloor, cabCuts)
segmentFloor(boxFloor, boxCuts)

-- Engine bay front: split into cowl pieces so grille bars remain visible.
local engineFront = cab:FindFirstChild("EngineBayFront")
if engineFront then
	local b = partBounds(engineFront)
	local cx = (b.x0 + b.x1) * 0.5
	local cy = (b.y0 + b.y1) * 0.5
	local openW = (b.x1 - b.x0) * 0.66
	local openH = (b.y1 - b.y0) * 0.58
	hide(engineFront, "V6 open grille")
	box(engineFolder, "EngineBayFront_LeftCowl", { x0 = b.x0, x1 = cx - openW * 0.5, y0 = b.y0, y1 = b.y1, z0 = b.z0, z1 = b.z1 }, engineFront.Color, engineFront.Material, true)
	box(engineFolder, "EngineBayFront_RightCowl", { x0 = cx + openW * 0.5, x1 = b.x1, y0 = b.y0, y1 = b.y1, z0 = b.z0, z1 = b.z1 }, engineFront.Color, engineFront.Material, true)
	box(engineFolder, "EngineBayFront_UpperCowl", { x0 = cx - openW * 0.5, x1 = cx + openW * 0.5, y0 = cy + openH * 0.5, y1 = b.y1, z0 = b.z0, z1 = b.z1 }, engineFront.Color, engineFront.Material, true)
	box(engineFolder, "EngineBayFront_LowerCowl", { x0 = cx - openW * 0.5, x1 = cx + openW * 0.5, y0 = b.y0, y1 = cy - openH * 0.5, z0 = b.z0, z1 = b.z1 }, engineFront.Color, engineFront.Material, true)
end

-- Hood sides: each side has one square panel under the windshield side and one hood-aligned wedge.
local hood = cab:WaitForChild("HoodPanel")
local hoodLocal = localCFrame(hood.CFrame)
for _, info in ipairs({
	{ old = "EngineBayLeft", side = -1 },
	{ old = "EngineBayRight", side = 1 },
}) do
	local old = cab:FindFirstChild(info.old)
	if old then
		local b = partBounds(old)
		local hb = partBounds(hood)
		hide(old, "V6 hood side split")
		box(engineFolder, info.old .. "_UnderWindshieldSquare", {
			x0 = b.x0, x1 = b.x1,
			y0 = b.y0, y1 = hb.y0,
			z0 = b.z0, z1 = b.z1,
		}, old.Color, old.Material, true)

		local wedgePart = Instance.new("WedgePart")
		wedgePart.Name = info.old .. "_HoodAlignedWedge"
		wedgePart.Size = Vector3.new(b.x1 - b.x0, math.max(0.2, b.y1 - hb.y0), hood.Size.Z)
		wedgePart.CFrame = worldCFrame(hoodLocal * CFrame.new(info.side * (hood.Size.X * 0.5 + wedgePart.Size.X * 0.5), -0.05, 0))
		wedgePart.Color = old.Color
		wedgePart.Material = old.Material
		wedgePart.Anchored = true
		wedgePart.CanCollide = true
		wedgePart.Parent = engineFolder
	end
end

local function guide(name, z)
	local p = box(guideFolder, name, {
		x0 = -bboxSize.X * 0.5, x1 = bboxSize.X * 0.5,
		y0 = -bboxSize.Y * 0.5, y1 = bboxSize.Y * 0.5,
		z0 = z - 0.04, z1 = z + 0.04,
	}, Color3.fromRGB(255, 210, 80), Enum.Material.SmoothPlastic, false)
	p.Transparency = 0.82
	p.CanQuery = false
	p.CanTouch = false
end

guide("Cab_LivingBoundary", -18)
guide("LivingFront_RearBoundary", -8)

rv:SetAttribute("BuildApproach", "V6 bounds-clean targeted wheel wells")
rv:SetAttribute("FloorTopRule", "Wheel tubs run from actual floor top to wheel top, never to baseplate")
rv:SetAttribute("WheelWellRule", "Divide wall before/after, stop wall above at wheel top, WedgePart corners, interior boxed tub")
rv:SetAttribute("Source", "Cloned from original RV_BaseCamp template")

print("Built " .. OUTPUT_NAME .. " with targeted floor-aware wheel wells.")
