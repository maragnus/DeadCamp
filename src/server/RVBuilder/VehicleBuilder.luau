-- Orchestrates a complete RV build from a front-to-back module plan.

local Workspace = game:GetService("Workspace")

local Constants = require(script.Parent:WaitForChild("Constants"))
local Layout = require(script.Parent:WaitForChild("Layout"))
local ModelBuilder = require(script.Parent:WaitForChild("ModelBuilder"))
local Assemblies = require(script.Parent:WaitForChild("Assemblies"))
local ModuleBuilders = require(script.Parent:WaitForChild("ModuleBuilders"))

local VehicleBuilder = {}

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

local function collectWheelGroups(layout)
	local groups = {}

	for _, section in ipairs(layout.Sections) do
		section.WheelGroups = {}
		for _, source in ipairs(section.Wheels or {}) do
			local group = {}
			for key, value in pairs(source) do
				group[key] = value
			end
			group.Id = group.Id or section.Id .. "Wheel"
			group.ModuleId = section.Id
			group.Section = section
			group.Z = section.Z0 + section.Length * (group.LocalZ or 0.5)

			section.WheelGroups[#section.WheelGroups + 1] = group
			groups[#groups + 1] = group
		end
	end

	return groups
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

local function addMetadata(rv, plan, layout, dimensions)
	rv:SetAttribute("VehicleId", plan.VehicleId or Constants.VehicleId)
	rv:SetAttribute("BuildVersion", plan.BuildVersion or Constants.BuildVersion)
	rv:SetAttribute("SourceOfTruth", "W:\\Dead Camp\\src\\server\\Build_RV_BaseCamp.server.luau")
	rv:SetAttribute("OutputMode", "ModularBuilder")
	rv:SetAttribute("AxisRule", "X width, Y height, Z length, negative Z front")
	rv:SetAttribute("Scale", dimensions.Scale)
	rv:SetAttribute("GroundY", dimensions.GroundY)
	rv:SetAttribute("BodyBottom", dimensions.BodyBottom)
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
end

function VehicleBuilder.build(plan)
	local scale = plan.Scale or Constants.DefaultScale
	local dimensions = Constants.dimensions(scale)
	Constants.validateDimensions(dimensions)
	local outputName = plan.OutputName or Constants.OutputName
	local config = {
		Colors = Constants.Colors,
		Dimensions = dimensions,
		SteeringWheelSourcePath = plan.SteeringWheelSourcePath or Constants.SteeringWheelSourcePath,
	}

	ModelBuilder.destroyExisting(outputName)

	local layout = Layout.resolve({
		Scale = scale,
		Modules = plan.Modules,
	})
	local wheelGroups = collectWheelGroups(layout)

	local rv = Instance.new("Model")
	rv.Name = outputName
	rv.Parent = Workspace

	local builder = ModelBuilder.new(config)
	local folders = buildFolders(builder, rv)
	local chassis = Assemblies.buildChassis(builder, folders.Chassis, layout)
	rv.PrimaryPart = chassis

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
	addMetadata(rv, plan, layout, dimensions)
	validateBuiltGeometry(rv, dimensions)

	return rv
end

return VehicleBuilder
