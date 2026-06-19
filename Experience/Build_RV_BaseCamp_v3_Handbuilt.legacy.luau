-- Dead Camp handbuilt Class C RV base camp.
-- Run once in Studio Edit mode. This deletes only RV_BaseCamp_v2_Candidate and RV_BaseCamp_v3_Handbuilt.
-- It does not touch the original Workspace.RV_BaseCamp.

local Workspace = game:GetService("Workspace")

for _, name in ipairs({ "RV_BaseCamp_v2_Candidate", "RV_BaseCamp_v3_Handbuilt" }) do
	local existing = Workspace:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

local rv = Instance.new("Model")
rv.Name = "RV_BaseCamp_v3_Handbuilt"
rv.Parent = Workspace

local folders = {}
for _, name in ipairs({
	"Chassis",
	"Cab",
	"LivingShell",
	"Interior",
	"Panels",
	"Wheels",
	"WheelWells",
	"Lights",
	"Interactables",
}) do
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = rv
	folders[name] = folder
end

local colors = {
	body = Color3.fromRGB(196, 199, 181),
	panel = Color3.fromRGB(154, 165, 133),
	trim = Color3.fromRGB(47, 49, 47),
	chassis = Color3.fromRGB(38, 39, 38),
	floor = Color3.fromRGB(85, 78, 66),
	glass = Color3.fromRGB(74, 120, 145),
	black = Color3.fromRGB(8, 8, 8),
	metal = Color3.fromRGB(112, 115, 113),
	engine = Color3.fromRGB(82, 84, 85),
	red = Color3.fromRGB(196, 30, 28),
	amber = Color3.fromRGB(255, 151, 42),
	headlamp = Color3.fromRGB(255, 240, 188),
}

local function configure(part, anchored, canCollide)
	part.Anchored = anchored ~= false
	part.CanCollide = canCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function part(parent, name, size, cf, color, material, canCollide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	configure(p, true, canCollide)
	p.Parent = parent
	return p
end

local function wedge(parent, name, size, cf, color, material, canCollide)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	configure(p, true, canCollide)
	p.Parent = parent
	return p
end

local function cylinder(parent, name, size, cf, color, material, canCollide)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	configure(p, true, canCollide)
	p.Parent = parent
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
	return w
end

local function prompt(parent, objectText, hold)
	local p = Instance.new("ProximityPrompt")
	p.Name = "OpenClosePrompt"
	p.ActionText = "Open"
	p.ObjectText = objectText
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 11
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

-- Oversized Class C proportions. Z is length; front is negative Z.
local floorY = 3.1
local wallCenterY = 9.8
local wallHeight = 13.0
local roofY = 16.65
local sideX = 9.1
local innerSideX = 8.55

local chassis = part(folders.Chassis, "MainChassis", Vector3.new(17.2, 1.0, 57.5), CFrame.new(0, 1.85, 0), colors.chassis, Enum.Material.Metal, true)
rv.PrimaryPart = chassis

part(folders.Interior, "WalkableInteriorFloor", Vector3.new(16.4, 0.45, 42.5), CFrame.new(0, floorY, 5.5), colors.floor, Enum.Material.WoodPlanks, true)
part(folders.Interior, "CabFloor", Vector3.new(13.6, 0.45, 15.5), CFrame.new(0, floorY, -20.0), colors.floor, Enum.Material.Metal, true)

-- Living shell: six explicit side panels, rear wall, front divider, and three roof panels.
local panelZ = { -4.5, 9.5, 23.5 }
local panelNames = { "Front", "Middle", "Rear" }
for sideName, x in pairs({ Left = -sideX, Right = sideX }) do
	for index, z in ipairs(panelZ) do
		local panelLength = 12.9
		local panelCenterZ = z
		if sideName == "Right" and index == 1 then
			panelLength = 10.0
			panelCenterZ = -6.0
		elseif sideName == "Right" and index == 2 then
			panelLength = 10.0
			panelCenterZ = 10.4
		end

		local p = part(
			folders.Panels,
			sideName .. "SidePanel_" .. panelNames[index],
			Vector3.new(0.55, wallHeight, panelLength),
			CFrame.new(x, wallCenterY, panelCenterZ),
			index == 2 and colors.body or colors.panel,
			Enum.Material.SmoothPlastic,
			true
		)
		p:SetAttribute("DetachableComponent", true)
	end
end

part(folders.Panels, "RightEntryDoorUpperWall", Vector3.new(0.55, 4.6, 4.8), CFrame.new(sideX, 12.0, 2.6), colors.body, Enum.Material.SmoothPlastic, true)
part(folders.Panels, "RightEntryDoorFrontJamb", Vector3.new(0.55, 8.4, 0.45), CFrame.new(sideX, 7.3, 0.15), colors.body, Enum.Material.SmoothPlastic, true)
part(folders.Panels, "RightEntryDoorRearJamb", Vector3.new(0.55, 8.4, 0.45), CFrame.new(sideX, 7.3, 5.05), colors.body, Enum.Material.SmoothPlastic, true)

part(folders.LivingShell, "RearWall", Vector3.new(17.7, wallHeight, 0.55), CFrame.new(0, wallCenterY, 30.4), colors.body, Enum.Material.SmoothPlastic, true)
part(folders.LivingShell, "CabDividerWall", Vector3.new(17.2, wallHeight - 1.5, 0.45), CFrame.new(0, wallCenterY + 0.4, -15.2), colors.body, Enum.Material.SmoothPlastic, true)

for index, z in ipairs(panelZ) do
	local roof = part(
		folders.LivingShell,
		"RoofPanel_" .. panelNames[index],
		Vector3.new(17.4, 0.45, 13.1),
		CFrame.new(0, roofY, z),
		colors.body,
		Enum.Material.SmoothPlastic,
		true
	)
	roof:SetAttribute("DetachableComponent", true)
end

-- Rounded roof shoulders; these sit above the side walls, not inside the walkway.
cylinder(folders.LivingShell, "LeftRoundedRoofShoulder", Vector3.new(0.9, 42.5, 0.9), CFrame.new(-8.55, roofY - 0.1, 5.5) * CFrame.Angles(math.rad(90), 0, 0), colors.body, Enum.Material.SmoothPlastic, true)
cylinder(folders.LivingShell, "RightRoundedRoofShoulder", Vector3.new(0.9, 42.5, 0.9), CFrame.new(8.55, roofY - 0.1, 5.5) * CFrame.Angles(math.rad(90), 0, 0), colors.body, Enum.Material.SmoothPlastic, true)

-- Cab, over-cab shell, hood, and engine bay. The cab is panel-built so players can sit/walk inside.
part(folders.Cab, "CabLeftSidePanel", Vector3.new(0.5, 6.7, 10.8), CFrame.new(-7.35, 6.7, -20.8), colors.body, Enum.Material.SmoothPlastic, true)
part(folders.Cab, "CabRightSidePanel", Vector3.new(0.5, 6.7, 10.8), CFrame.new(7.35, 6.7, -20.8), colors.body, Enum.Material.SmoothPlastic, true)
part(folders.Cab, "CabBackPanel", Vector3.new(14.1, 6.4, 0.45), CFrame.new(0, 6.9, -15.0), colors.body, Enum.Material.SmoothPlastic, true)
part(folders.Cab, "CabFrontCowl", Vector3.new(14.2, 2.8, 0.5), CFrame.new(0, 5.2, -26.55), colors.body, Enum.Material.SmoothPlastic, true)
part(folders.Cab, "CabRoofPanel", Vector3.new(14.4, 0.45, 10.8), CFrame.new(0, 10.35, -20.7), colors.body, Enum.Material.SmoothPlastic, true)
part(folders.Cab, "OverCabSleeperShell", Vector3.new(17.4, 4.4, 13.5), CFrame.new(0, 14.55, -16.6), colors.body, Enum.Material.SmoothPlastic, false):SetAttribute("VisualShell", true)
wedge(folders.Cab, "OverCabFrontSlope", Vector3.new(17.4, 2.7, 4.2), CFrame.new(0, 12.8, -24.8) * CFrame.Angles(0, math.rad(180), 0), colors.body, Enum.Material.SmoothPlastic, false):SetAttribute("VisualShell", true)

local hood = wedge(folders.Interactables, "Hood", Vector3.new(13.5, 1.15, 8.0), CFrame.new(0, 7.35, -29.0) * CFrame.Angles(0, math.rad(180), 0), colors.body, Enum.Material.SmoothPlastic, true)
hood:SetAttribute("DetachableComponent", true)
hood:SetAttribute("Interactable", true)
prompt(hood, "Hood", 0.15)

part(folders.Cab, "EngineBayFirewall", Vector3.new(13.4, 4.2, 0.4), CFrame.new(0, 5.6, -24.65), colors.trim, Enum.Material.Metal, true)
part(folders.Cab, "EngineBlock", Vector3.new(4.2, 1.5, 3.2), CFrame.new(0, 5.45, -29.2), colors.engine, Enum.Material.Metal, true)
part(folders.Cab, "EngineIntake", Vector3.new(2.4, 0.55, 2.0), CFrame.new(0, 6.55, -29.2), colors.metal, Enum.Material.Metal, true)
part(folders.Cab, "EngineLeftHead", Vector3.new(1.1, 0.6, 3.4), CFrame.new(-2.6, 5.8, -29.2), colors.metal, Enum.Material.Metal, true)
part(folders.Cab, "EngineRightHead", Vector3.new(1.1, 0.6, 3.4), CFrame.new(2.6, 5.8, -29.2), colors.metal, Enum.Material.Metal, true)

-- Door is separate from side panel and pivots away from the opening.
local sideDoor = part(folders.Interactables, "SideEntryDoor", Vector3.new(0.48, 8.0, 4.2), CFrame.new(sideX + 0.36, 7.45, 2.6), colors.body, Enum.Material.SmoothPlastic, true)
sideDoor:SetAttribute("DetachableComponent", true)
sideDoor:SetAttribute("Interactable", true)
prompt(sideDoor, "Side Door", 0)
part(folders.Interactables, "SideEntryDoorWindow", Vector3.new(0.12, 2.2, 2.1), CFrame.new(sideX + 0.64, 9.2, 2.6), colors.glass, Enum.Material.Glass, false).Transparency = 0.35
part(folders.Interactables, "SideEntryHandle", Vector3.new(0.22, 0.25, 0.65), CFrame.new(sideX + 0.72, 7.1, 0.95), colors.black, Enum.Material.Metal, false)

-- Seats and cab controls. These are real seat objects, not just visual blocks.
local driverSeat = Instance.new("VehicleSeat")
driverSeat.Name = "DriverVehicleSeat"
driverSeat.Size = Vector3.new(2.6, 0.75, 2.8)
driverSeat.CFrame = CFrame.new(-3.3, 4.25, -20.6) * CFrame.Angles(0, math.rad(180), 0)
driverSeat.Color = Color3.fromRGB(33, 33, 31)
driverSeat.Material = Enum.Material.Fabric
driverSeat.Anchored = true
driverSeat.CanCollide = true
driverSeat.MaxSpeed = 0
driverSeat.Torque = 0
driverSeat.Parent = folders.Interior

local passengerSeat = Instance.new("Seat")
passengerSeat.Name = "PassengerSeat"
passengerSeat.Size = Vector3.new(2.6, 0.75, 2.8)
passengerSeat.CFrame = CFrame.new(3.3, 4.25, -20.6) * CFrame.Angles(0, math.rad(180), 0)
passengerSeat.Color = Color3.fromRGB(33, 33, 31)
passengerSeat.Material = Enum.Material.Fabric
passengerSeat.Anchored = true
passengerSeat.CanCollide = true
passengerSeat.Parent = folders.Interior

part(folders.Interior, "DriverSeatBack", Vector3.new(2.7, 2.8, 0.45), CFrame.new(-3.3, 5.7, -19.15), Color3.fromRGB(28, 28, 27), Enum.Material.Fabric, true)
part(folders.Interior, "PassengerSeatBack", Vector3.new(2.7, 2.8, 0.45), CFrame.new(3.3, 5.7, -19.15), Color3.fromRGB(28, 28, 27), Enum.Material.Fabric, true)
part(folders.Interior, "Dashboard", Vector3.new(12.6, 1.05, 1.35), CFrame.new(0, 5.35, -25.55), colors.trim, Enum.Material.SmoothPlastic, true)
cylinder(folders.Interior, "SteeringWheel", Vector3.new(1.8, 0.18, 1.8), CFrame.new(-3.3, 5.75, -24.75) * CFrame.Angles(math.rad(65), 0, 0), colors.black, Enum.Material.SmoothPlastic, false)
part(folders.Interior, "SteeringColumn", Vector3.new(0.32, 0.32, 1.55), CFrame.new(-3.3, 5.25, -24.2) * CFrame.Angles(math.rad(65), 0, 0), colors.black, Enum.Material.Metal, false)

-- Windows sit in the shell and do not block walking space.
local function glass(name, size, cf)
	local g = part(folders.LivingShell, name, size, cf, colors.glass, Enum.Material.Glass, false)
	g.Transparency = 0.38
	return g
end
glass("Windshield", Vector3.new(9.8, 3.1, 0.18), CFrame.new(0, 8.55, -26.45) * CFrame.Angles(math.rad(-8), 0, 0))
glass("DriverCabWindow", Vector3.new(0.16, 2.5, 3.3), CFrame.new(-7.3, 8.1, -21.2))
glass("PassengerCabWindow", Vector3.new(0.16, 2.5, 3.3), CFrame.new(7.3, 8.1, -21.2))
glass("LeftWindowFront", Vector3.new(0.16, 2.5, 4.6), CFrame.new(-9.42, 10.55, -4.5))
glass("LeftWindowRear", Vector3.new(0.16, 2.5, 4.6), CFrame.new(-9.42, 10.55, 21.0))
glass("RightWindowRear", Vector3.new(0.16, 2.5, 4.6), CFrame.new(9.42, 10.55, 21.0))
glass("RearWindow", Vector3.new(5.2, 2.4, 0.16), CFrame.new(0, 10.55, 30.72))

-- Wheels: placed outside the body with enough clearance for the arches.
local wheelData = {
	{ name = "FrontLeft", x = -10.8, z = -16.5 },
	{ name = "FrontRight", x = 10.8, z = -16.5 },
	{ name = "RearLeft", x = -10.8, z = 18.5 },
	{ name = "RearRight", x = 10.8, z = 18.5 },
}

for _, data in ipairs(wheelData) do
	local model = Instance.new("Model")
	model.Name = "Wheel_" .. data.name
	model:SetAttribute("DetachableComponent", true)
	model.Parent = folders.Wheels

	cylinder(model, "Tire", Vector3.new(5.6, 2.25, 5.6), CFrame.new(data.x, 3.2, data.z) * CFrame.Angles(0, 0, math.rad(90)), colors.black, Enum.Material.SmoothPlastic, true)
	cylinder(model, "Rim", Vector3.new(2.75, 2.35, 2.75), CFrame.new(data.x, 3.2, data.z) * CFrame.Angles(0, 0, math.rad(90)), colors.metal, Enum.Material.Metal, false)
end

-- Rounded wheel wells are arch segments outside the tire radius, not boxes crossing the tire.
local function wheelWell(name, x, z)
	local sideSign = x > 0 and 1 or -1
	local model = Instance.new("Model")
	model.Name = name .. "_RoundedWheelWell"
	model:SetAttribute("DetachableComponent", true)
	model.Parent = folders.WheelWells

	local center = Vector3.new(x - sideSign * 0.2, 3.25, z)
	local radius = 3.35
	local segmentCount = 9
	for i = 1, segmentCount do
		local t = math.rad(180 - (i - 1) * 180 / (segmentCount - 1))
		local y = center.Y + math.sin(t) * radius
		local zz = center.Z + math.cos(t) * radius
		local angle = -math.deg(t) + 90
		part(
			model,
			"ArchSegment_" .. i,
			Vector3.new(0.7, 0.42, 1.15),
			CFrame.new(center.X, y, zz) * CFrame.Angles(0, 0, math.rad(angle)),
			colors.body,
			Enum.Material.SmoothPlastic,
			true
		)
	end

	part(model, "DarkInnerWheelOpening", Vector3.new(0.18, 5.2, 6.6), CFrame.new(center.X - sideSign * 0.08, center.Y + 1.2, center.Z), colors.black, Enum.Material.SmoothPlastic, false).Transparency = 0.1
end

wheelWell("FrontLeft", -9.45, -16.5)
wheelWell("FrontRight", 9.45, -16.5)
wheelWell("RearLeft", -9.45, 18.5)
wheelWell("RearRight", 9.45, 18.5)

-- Bumpers and lights.
part(folders.Chassis, "FrontBumper", Vector3.new(16.2, 0.85, 0.9), CFrame.new(0, 2.85, -33.25), colors.metal, Enum.Material.Metal, true):SetAttribute("DetachableComponent", true)
part(folders.Chassis, "RearBumper", Vector3.new(17.2, 0.85, 0.9), CFrame.new(0, 2.85, 31.35), colors.metal, Enum.Material.Metal, true):SetAttribute("DetachableComponent", true)

local function light(name, size, cf, color)
	local p = part(folders.Lights, name, size, cf, color, Enum.Material.Neon, false)
	p:SetAttribute("DetachableComponent", true)
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = color
	glow.Range = 10
	glow.Brightness = 1
	glow.Parent = p
	return p
end

light("HeadlightLeft", Vector3.new(1.15, 0.55, 0.25), CFrame.new(-4.1, 5.45, -33.75), colors.headlamp)
light("HeadlightRight", Vector3.new(1.15, 0.55, 0.25), CFrame.new(4.1, 5.45, -33.75), colors.headlamp)
light("BlinkerFrontLeft", Vector3.new(0.65, 0.38, 0.25), CFrame.new(-6.25, 5.0, -33.75), colors.amber)
light("BlinkerFrontRight", Vector3.new(0.65, 0.38, 0.25), CFrame.new(6.25, 5.0, -33.75), colors.amber)
light("TaillightLeft", Vector3.new(0.75, 1.0, 0.25), CFrame.new(-6.6, 5.8, 30.95), colors.red)
light("TaillightRight", Vector3.new(0.75, 1.0, 0.25), CFrame.new(6.6, 5.8, 30.95), colors.red)
light("BlinkerRearLeft", Vector3.new(0.65, 0.45, 0.25), CFrame.new(-7.75, 5.0, 30.95), colors.amber)
light("BlinkerRearRight", Vector3.new(0.65, 0.45, 0.25), CFrame.new(7.75, 5.0, 30.95), colors.amber)

local interactionScript = Instance.new("Script")
interactionScript.Name = "RVInteractables"
interactionScript.Source = [==[
local TweenService = game:GetService("TweenService")

local rv = script.Parent
local interactables = rv:WaitForChild("Interactables")
local door = interactables:WaitForChild("SideEntryDoor")
local hood = interactables:WaitForChild("Hood")
local doorPrompt = door:WaitForChild("OpenClosePrompt")
local hoodPrompt = hood:WaitForChild("OpenClosePrompt")

local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local doorClosed = door.CFrame
local hoodClosed = hood.CFrame
local doorOpen = false
local hoodOpen = false

local function rotateAroundAxis(cf, pivot, axis, angle)
	return CFrame.new(pivot) * CFrame.fromAxisAngle(axis.Unit, angle) * CFrame.new(-pivot) * cf
end

local doorPivot = (doorClosed * CFrame.new(0, 0, -door.Size.Z * 0.5)).Position
local hoodPivot = (hoodClosed * CFrame.new(0, 0, hood.Size.Z * 0.5)).Position
local doorOpenCFrame = rotateAroundAxis(doorClosed, doorPivot, doorClosed.UpVector, math.rad(95))
local hoodOpenCFrame = rotateAroundAxis(hoodClosed, hoodPivot, hoodClosed.RightVector, math.rad(-70))

doorPrompt.Triggered:Connect(function()
	doorOpen = not doorOpen
	doorPrompt.ActionText = doorOpen and "Close" or "Open"
	TweenService:Create(door, tweenInfo, { CFrame = doorOpen and doorOpenCFrame or doorClosed }):Play()
end)

hoodPrompt.Triggered:Connect(function()
	hoodOpen = not hoodOpen
	hoodPrompt.ActionText = hoodOpen and "Close" or "Open"
	TweenService:Create(hood, tweenInfo, { CFrame = hoodOpen and hoodOpenCFrame or hoodClosed }):Play()
end)
]==]
interactionScript.Parent = rv

rv:SetAttribute("Build", "Handbuilt")
rv:SetAttribute("Scale", "Oversized Class C, larger than prior generated candidates")
rv:SetAttribute("Interior", "Walkable gutted shell; no RV furniture")
rv:SetAttribute("Requirements", "driver seat, passenger seat, steering wheel, dashboard, hood, engine, side door, rounded roof, 3 side panels, 3 roof panels, windows, lights, rounded wheel wells, bumpers")

rv:PivotTo(CFrame.new(0, 0, 0))

print("Built RV_BaseCamp_v3_Handbuilt. Original RV_BaseCamp remains untouched.")