local AssetService = game:GetService("AssetService")

local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))

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
	if type(AssetService.CreateEditableMesh) ~= "function" or type(AssetService.CreateMeshPartAsync) ~= "function" then
		return nil, "EditableMesh APIs unavailable"
	end

	local ok, result = pcall(function()
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		folder:SetAttribute("RenderMode", "MeshChunks")

		for chunkIndex, chunk in ipairs(spec.Chunks or {}) do
			local editableMesh = AssetService:CreateEditableMesh()
			local vertexIds = {}

			for index, vertex in ipairs(chunk.Vertices) do
				vertexIds[index] = editableMesh:AddVertex(vertex)
			end

			for _, triangle in ipairs(chunk.Triangles) do
				editableMesh:AddTriangle(vertexIds[triangle[1]], vertexIds[triangle[2]], vertexIds[triangle[3]])
			end

			local meshPart = AssetService:CreateMeshPartAsync(Content.fromObject(editableMesh))
			meshPart.Name = chunk.Id or ("%s_%03d"):format(name, chunkIndex)
			configurePart(meshPart, options)
			meshPart.CFrame = CFrame.new(chunk.Center + (options.CenterOffset or Vector3.zero))
			meshPart.Parent = folder
			meshPart:SetAttribute("RenderMode", "MeshPart")
			meshPart:SetAttribute("ChunkWidth", chunk.BoundsSize.X)
			meshPart:SetAttribute("ChunkLength", chunk.BoundsSize.Z)
		end

		return folder
	end)

	if not ok then
		return nil, result
	end

	return result, nil
end

local function buildFallbackSegments(parent, name, spec, options)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	folder:SetAttribute("RenderMode", "StripParts")

	local centerOffset = options.CenterOffset or Vector3.zero
	for chunkIndex, chunk in ipairs(spec.Chunks or {}) do
		local chunkFolder = Instance.new("Folder")
		chunkFolder.Name = chunk.Id or ("%s_%03d"):format(name, chunkIndex)
		chunkFolder.Parent = folder

		local thickness = options.Thickness or chunk.Thickness or spec.Thickness or WorldConstants.DefaultRibbonThickness
		for index, segment in ipairs(chunk.Segments or {}) do
			local part = Instance.new("Part")
			part.Name = ("%s_%03d"):format(chunkFolder.Name, index)
			configurePart(part, options)
			part.Size = Vector3.new(segment.Width, thickness, math.max(0.1, segment.Length))
			local center = chunk.Center + segment.Center + centerOffset
			local lookAt = chunk.Center + segment.LookAt + centerOffset
			part.CFrame = CFrame.lookAt(center, lookAt, WorldConstants.WorldUp)
			part.Parent = chunkFolder
		end
	end

	return folder
end

function RoadRenderBuilder.build(parent, name, spec, options)
	local renderOptions = options or {}
	local meshPart, meshError = tryBuildMesh(parent, name, spec, renderOptions)
	if meshPart then
		return meshPart, "MeshPart"
	end

	local fallback = buildFallbackSegments(parent, name, spec, renderOptions)
	if meshError then
		fallback:SetAttribute("MeshFallbackReason", tostring(meshError))
	end

	return fallback, "StripParts"
end

return RoadRenderBuilder
