-- Orchestrates a complete RV build from a front-to-back module plan.

local Workspace = game:GetService("Workspace")

local Constants = require(script.Parent:WaitForChild("Constants"))
local Layout = require(script.Parent:WaitForChild("Layout"))
local ModelBuilder = require(script.Parent:WaitForChild("ModelBuilder"))
local Assemblies = require(script.Parent:WaitForChild("Assemblies"))
local ModuleBuilders = require(script.Parent:WaitForChild("ModuleBuilders"))
local WheelGroups = require(script.Parent:WaitForChild("WheelGroups"))

local VehicleBuilder = {}
local Bounds = ModelBuilder.Bounds

local MODULE_HANDLERS = {
	ClassCCab = ModuleBuilders.buildClassCCab,
	ClassACab = ModuleBuilders.buildClassACab,
	Living = ModuleBuilders.buildLiving,
}

local GEOMETRY_EPSILON = 0.01

local function buildFolders(builder, rv)
	return {
		Chassis = builder:folder(rv, "Chassis"),
		Body = builder:folder(rv, "Body"),
		Cab = builder:folder(rv, "Cab"),
		Roof = builder:folder(rv, "Roof"),
		Interior = builder:folder(rv, "Interior"),
		Glass = builder:folder(rv, "Glass"),
		WheelBoxes = builder:folder(rv, "WheelBoxes"),
		Wheels = builder:folder(rv, "Wheels"),
		Lights = builder:folder(rv, "Lights"),
		Interactables = builder:folder(rv, "Interactables"),
	}
end

local function partWorldYBounds(part)
	local size = part.Size
	local minY = math.huge
	local maxY = -math.huge

	for _, xSign in ipairs({ -1, 1 }) do
		for _, ySign in ipairs({ -1, 1 }) do
			for _, zSign in ipairs({ -1, 1 }) do
				local corner = Vector3.new(
					size.X * xSign * 0.5,
					size.Y * ySign * 0.5,
					size.Z * zSign * 0.5
				)
				local worldY = part.CFrame:PointToWorldSpace(corner).Y
				minY = math.min(minY, worldY)
				maxY = math.max(maxY, worldY)
			end
		end
	end

	return minY, maxY
end

local function validateBuiltGeometry(rv, dimensions)
	local wheelBottomY = math.huge
	local chassisBottomY = math.huge

	for _, descendant in ipairs(rv:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local minY = partWorldYBounds(descendant)
			local role = descendant:GetAttribute("PartRole")

			if role == "Wheel" then
				wheelBottomY = math.min(wheelBottomY, minY)
			elseif role == "Chassis" then
				chassisBottomY = math.min(chassisBottomY, minY)
			end
		end
	end

	if wheelBottomY < math.huge and math.abs(wheelBottomY - dimensions.GroundY) > GEOMETRY_EPSILON then
		error(("Generated wheel bottom must sit on GroundY; got %.3f vs %.3f"):format(wheelBottomY, dimensions.GroundY), 2)
	end
	if chassisBottomY < math.huge and chassisBottomY <= dimensions.GroundY + GEOMETRY_EPSILON then
		error(("Generated chassis must clear GroundY; got %.3f <= %.3f"):format(chassisBottomY, dimensions.GroundY), 2)
	end
end

local function widestHalfWidth(layout, dimensions)
	local halfWidth = dimensions.Width * 0.5

	for _, section in ipairs(layout.Sections) do
		if section.Type == "ClassCCab" then
			halfWidth = math.max(halfWidth, dimensions.CabHalfWidth)
		end
	end

	return halfWidth
end

local function buildDriveRoot(builder, rv, layout, dimensions)
	local s = dimensions.Scale
	local halfWidth = widestHalfWidth(layout, dimensions)
	local driveRoot = builder:part(rv, "DriveRoot", Bounds.new(
		-halfWidth,
		halfWidth,
		dimensions.ChassisY - s * 0.15,
		dimensions.ChassisY + s * 0.15,
		layout.TotalZ0 - s * 0.35,
		layout.TotalZ1 + s * 0.42
	), {
		Color = "Chassis",
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Meta = {
			PartRole = "DriveRoot",
			DriveRoot = true,
			Swappable = false,
		},
	})

	if driveRoot then
		driveRoot.Name = "DriveRoot"
	end

	return driveRoot
end

local function addMetadata(rv, plan, layout, dimensions, driveConfig, driveRoot)
	rv:SetAttribute("VehicleId", plan.VehicleId or Constants.VehicleId)
	rv:SetAttribute("BuildVersion", plan.BuildVersion or Constants.BuildVersion)
	rv:SetAttribute("SourceOfTruth", "W:\\Dead Camp\\src\\server\\Build_RV_BaseCamp.server.luau")
	rv:SetAttribute("OutputMode", "ModularBuilder")
	rv:SetAttribute("DriveModel", Constants.DriveModel)
	rv:SetAttribute("DriveRootName", driveRoot and driveRoot.Name or "DriveRoot")
	rv:SetAttribute("AxisRule", "X width, Y height, Z length, negative Z front")
	rv:SetAttribute("Scale", dimensions.Scale)
	rv:SetAttribute("GroundY", dimensions.GroundY)
	rv:SetAttribute("BodyBottom", dimensions.BodyBottom)
	rv:SetAttribute("BodyTop", dimensions.BodyTop)
	rv:SetAttribute("FloorTop", dimensions.FloorTop)
	rv:SetAttribute("FloorThickness", dimensions.FloorThickness)
	rv:SetAttribute("ChassisBottom", dimensions.ChassisBottom)
	rv:SetAttribute("ChassisTop", dimensions.ChassisTop)
	rv:SetAttribute("WheelCenterY", dimensions.WheelCenterY)
	rv:SetAttribute("WheelRadius", dimensions.WheelRadius)
	rv:SetAttribute("WallThickness", dimensions.SideWallThickness)
	rv:SetAttribute("ModuleCount", #layout.Sections)
	rv:SetAttribute("ModuleOrder", table.concat((function()
		local ids = {}
		for _, section in ipairs(layout.Sections) do
			ids[#ids + 1] = section.Id
		end
		return ids
	end)(), ","))
	rv:SetAttribute("WheelWellRule", "Divide wall before/after; stop wall above wheel top; use wedge corners; box interior")
	rv:SetAttribute("SupportsClassA", true)
	rv:SetAttribute("SupportsClassC", true)
	rv:SetAttribute("SupportsDuallyWheels", true)
	rv:SetAttribute("SupportsTandemAxles", true)

	for _, key in ipairs(Constants.DriveConfigKeys) do
		rv:SetAttribute(key, driveConfig[key])
		if driveRoot then
			driveRoot:SetAttribute(key, driveConfig[key])
		end
	end

	if driveRoot then
		driveRoot:SetAttribute("DriveModel", Constants.DriveModel)
	end
end

function VehicleBuilder.build(plan)
	local scale = plan.Scale or Constants.DefaultScale
	local dimensions = Constants.dimensions(scale)
	local driveConfig = Constants.driveConfig(scale, plan.Drive)
	Constants.validateDimensions(dimensions)
	Constants.validateDriveConfig(driveConfig)
	local outputName = plan.OutputName or Constants.OutputName
	local config = {
		Colors = Constants.Colors,
		Dimensions = dimensions,
		DriveConfig = driveConfig,
		SteeringWheelSourcePath = plan.SteeringWheelSourcePath or Constants.SteeringWheelSourcePath,
	}

	ModelBuilder.destroyExisting(outputName)

	local layout = Layout.resolve({
		Scale = scale,
		Modules = plan.Modules,
	})
	local wheelGroups = WheelGroups.collect(layout)

	local rv = Instance.new("Model")
	rv.Name = outputName
	rv.Parent = Workspace

	local builder = ModelBuilder.new(config)
	local folders = buildFolders(builder, rv)
	local chassis = Assemblies.buildChassis(builder, folders.Chassis, layout)
	local driveRoot = buildDriveRoot(builder, rv, layout, dimensions)
	rv.PrimaryPart = driveRoot or chassis

	Assemblies.buildFloor(builder, folders.Interior, layout, wheelGroups)

	for _, section in ipairs(layout.Sections) do
		local handler = MODULE_HANDLERS[section.Type]
		if not handler then
			error(("Unknown RV module type %s for section %s"):format(tostring(section.Type), tostring(section.Id)), 2)
		end
		handler(builder, folders, section)
	end

	Assemblies.buildWheels(builder, folders.Wheels, wheelGroups)
	Assemblies.buildLights(builder, folders.Lights, layout, layout.Sections)
	Assemblies.buildBumpers(builder, folders.Chassis, layout)
	Assemblies.connectInteractables(rv)
	addMetadata(rv, plan, layout, dimensions, driveConfig, driveRoot)
	validateBuiltGeometry(rv, dimensions)

	return rv
end

return VehicleBuilder
