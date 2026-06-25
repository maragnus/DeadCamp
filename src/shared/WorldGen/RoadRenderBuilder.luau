local EditableMeshBuilder = require(script.Parent.Parent:WaitForChild("Geometry"):WaitForChild("EditableMeshBuilder"))

local RoadRenderBuilder = {}

local function configurePart(part, options)
	part.Anchored = true
	part.CanCollide = options.CanCollide == true
	part.CanQuery = options.CanQuery ~= false
	part.CanTouch = options.CanTouch ~= false
	part.Material = options.Material or Enum.Material.Asphalt
	part.Color = options.Color or Color3.fromRGB(52, 50, 47)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = options.CastShadow == true
	part.Transparency = options.Transparency or 0
	if options.CollisionGroup ~= nil then
		part.CollisionGroup = options.CollisionGroup
	end
end

local function tryBuildMesh(parent, name, spec, options)
	return EditableMeshBuilder.buildFolderFromSpec(parent, name, spec, {
		CenterOffset = options.CenterOffset,
		ConfigurePart = function(meshPart, chunk)
			configurePart(meshPart, options)
			meshPart:SetAttribute("ChunkWidth", chunk.BoundsSize.X)
			meshPart:SetAttribute("ChunkLength", chunk.SectionLength or chunk.BoundsSize.Z)
		end,
	})
end

function RoadRenderBuilder.build(parent, name, spec, options)
	local renderOptions = options or {}
	local meshFolder, meshError = tryBuildMesh(parent, name, spec, renderOptions)
	if not meshFolder then
		error(("RoadRenderBuilder failed to build %s: %s"):format(tostring(name), tostring(meshError)), 2)
	end

	return meshFolder, "MeshPart"
end

return RoadRenderBuilder
