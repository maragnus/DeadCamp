-- Vehicle module handlers. Each handler receives an absolute section from Layout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounds = require(Shared:WaitForChild("RVBounds"))

local Assemblies = require(script.Parent:WaitForChild("Assemblies"))
local ClassCCabBuilder = require(script.Parent:WaitForChild("ClassCCabBuilder"))
local CockpitBuilder = require(script.Parent:WaitForChild("CockpitBuilder"))
local Panels = require(script.Parent:WaitForChild("Panels"))

local ModuleBuilders = {}
local DEFAULT_SIDE_DOOR_BOTTOM_OFFSET = 0.08
local DEFAULT_SIDE_DOOR_TOP_Y = 9.0

local function moduleMeta(section, role)
	return {
		ModuleId = section.Id,
		PartRole = role,
		DamageSlot = section.Id .. role,
		Swappable = true,
		DetachableComponent = true,
	}
end

local function featureY(section, key, fallback)
	if section.FeatureY and section.FeatureY[key] then
		return section.FeatureY[key]
	end
	return fallback
end

local function wheelOpenings(builder, section, side)
	local openings = {}
	for _, group in ipairs(section.WheelGroups or {}) do
		openings[#openings + 1] = Panels.wheelOpening(builder.Config.Dimensions, section, group, side)
	end
	return openings
end

local function addWindows(builder, glassParent, section, side, windows)
	local dimensions = builder.Config.Dimensions

	for _, window in ipairs(windows) do
		builder:addGlass(
			glassParent,
			section.Id .. "_" .. Panels.sideName(side) .. "_" .. window.Id,
			Panels.sideFlushBounds(dimensions, side, window.Y0, window.Y1, window.Z0, window.Z1),
			moduleMeta(section, "WindowGlass")
		)
	end
end

function ModuleBuilders.buildLiving(builder, folders, section)
	local dimensions = builder.Config.Dimensions
	local defaultDoorY0 = dimensions.FloorTop + dimensions.Scale * DEFAULT_SIDE_DOOR_BOTTOM_OFFSET
	local defaultDoorY1 = dimensions.Scale * DEFAULT_SIDE_DOOR_TOP_Y
	local sideWindows = { [-1] = {}, [1] = {} }
	local sideDoors = { [-1] = {}, [1] = {} }

	for _, windowSpec in ipairs(section.Windows or {}) do
		local window = Assemblies.absoluteWindow(section, {
			Id = windowSpec.Id,
			Side = windowSpec.Side,
			LocalZ0 = windowSpec.LocalZ0,
			LocalZ1 = windowSpec.LocalZ1,
			Y0 = windowSpec.Y0 or featureY(section, "WindowY0", dimensions.Scale * 6.16),
			Y1 = windowSpec.Y1 or featureY(section, "WindowY1", dimensions.Scale * 7.86),
		})
		if window.Side == nil or window.Side == 0 then
			sideWindows[-1][#sideWindows[-1] + 1] = window
			sideWindows[1][#sideWindows[1] + 1] = window
		else
			sideWindows[window.Side][#sideWindows[window.Side] + 1] = window
		end
	end

	for _, doorSpec in ipairs(section.Doors or {}) do
		local door = Assemblies.absoluteDoor(section, {
			Id = doorSpec.Id or "SideEntryDoor",
			Side = doorSpec.Side or 1,
			LocalZ0 = doorSpec.LocalZ0,
			LocalZ1 = doorSpec.LocalZ1,
			Y0 = doorSpec.Y0 or defaultDoorY0,
			Y1 = doorSpec.Y1 or defaultDoorY1,
		})
		sideDoors[door.Side][#sideDoors[door.Side] + 1] = door
	end

	for _, side in ipairs({ -1, 1 }) do
		local openings = wheelOpenings(builder, section, side)
		for _, window in ipairs(sideWindows[side]) do
			openings[#openings + 1] = window
		end
		for _, door in ipairs(sideDoors[side]) do
			openings[#openings + 1] = door
		end

		Panels.buildSidePanel(builder, folders.Body, Panels.sideName(side) .. "SidePanel_" .. section.Id, side, section, openings)
		addWindows(builder, folders.Glass, section, side, sideWindows[side])

		for _, opening in ipairs(openings) do
			if opening.Kind == "WheelWell" then
				Panels.addWheelTub(builder, folders.WheelBoxes, opening)
			elseif opening.Kind == "Door" then
				Assemblies.buildDoor(builder, folders.Interactables, folders.Glass, section, opening)
			end
		end
	end

	Assemblies.buildRoof(builder, folders.Roof, section)

	if section.RearWall then
		local rearWindow = {
			Id = "RearWindow",
			Kind = "Window",
			X0 = -dimensions.Scale * 1.75,
			X1 = dimensions.Scale * 1.75,
			Y0 = dimensions.Scale * 6.25,
			Y1 = dimensions.Scale * 7.85,
		}
		local openings = section.RearWall.Window and { rearWindow } or {}
		Panels.buildEndPanel(builder, folders.Body, "RearWall", section, section.Z1 - dimensions.Scale * 0.18, section.Z1 + dimensions.Scale * 0.18, openings)
		if section.RearWall.Window then
			local rearOuterZ = section.Z1 + dimensions.Scale * 0.18
			builder:addGlass(folders.Glass, "RearWindow", Bounds.new(
				rearWindow.X0,
				rearWindow.X1,
				rearWindow.Y0,
				rearWindow.Y1,
				rearOuterZ - dimensions.GlassThickness,
				rearOuterZ
			), moduleMeta(section, "RearWindowGlass"))
		end
	end

	if section.Ladder then
		Assemblies.buildLadder(builder, folders.Body, section)
	end
end

function ModuleBuilders.buildClassCCab(builder, folders, section)
	ClassCCabBuilder.build(builder, folders, section)
end

function ModuleBuilders.buildClassACab(builder, folders, section)
	local dimensions = builder.Config.Dimensions
	local frontWindow = {
		Id = "PanoramicWindshield",
		Kind = "Window",
		X0 = -dimensions.Scale * 4.0,
		X1 = dimensions.Scale * 4.0,
		Y0 = dimensions.Scale * 5.15,
		Y1 = dimensions.Scale * 8.55,
	}

	Panels.buildEndPanel(builder, folders.Cab, "ClassAFrontCap", section, section.Z0 - dimensions.Scale * 0.08, section.Z0 + dimensions.Scale * 0.18, { frontWindow })
	builder:addGlass(folders.Glass, "PanoramicWindshield", Bounds.new(frontWindow.X0, frontWindow.X1, frontWindow.Y0, frontWindow.Y1, section.Z0 - dimensions.Scale * 0.14, section.Z0 - dimensions.Scale * 0.04), moduleMeta(section, "Windshield"))

	ModuleBuilders.buildLiving(builder, folders, section)
	CockpitBuilder.build(builder, folders, section)
end

return ModuleBuilders
