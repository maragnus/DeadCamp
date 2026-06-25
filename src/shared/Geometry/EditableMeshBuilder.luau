local AssetService = game:GetService("AssetService")

local MeshValidation = require(script.Parent:WaitForChild("MeshValidation"))

local EditableMeshBuilder = {}

local function supportsEditableMesh()
	return type(AssetService.CreateEditableMesh) == "function"
		and type(AssetService.CreateMeshPartAsync) == "function"
end

function EditableMeshBuilder.isAvailable()
	return supportsEditableMesh()
end

function EditableMeshBuilder.buildMeshPartFromChunk(chunk)
	if not supportsEditableMesh() then
		return nil, "EditableMesh APIs unavailable"
	end

	local editableMesh = nil
	local fixedSizeMesh = nil
	local ok, meshPartOrError, usedFixedSize = pcall(function()
		MeshValidation.validateChunk(chunk)

		editableMesh = AssetService:CreateEditableMesh()
		local vertexIds = {}

		for index, vertex in ipairs(chunk.Vertices or {}) do
			vertexIds[index] = editableMesh:AddVertex(vertex)
		end

		for _, triangle in ipairs(chunk.Triangles or {}) do
			editableMesh:AddTriangle(vertexIds[triangle[1]], vertexIds[triangle[2]], vertexIds[triangle[3]])
		end

		editableMesh:RemoveUnused()

		local meshSource = editableMesh
		local didUseFixedSize = false
		if type(AssetService.CreateEditableMeshAsync) == "function" then
			fixedSizeMesh = AssetService:CreateEditableMeshAsync(Content.fromObject(editableMesh), { FixedSize = true })
			meshSource = fixedSizeMesh
			didUseFixedSize = true
		end

		local meshPart = AssetService:CreateMeshPartAsync(Content.fromObject(meshSource))
		local retainedFixedSizeMesh = fixedSizeMesh
		if retainedFixedSizeMesh then
			meshPart.Destroying:Connect(function()
				retainedFixedSizeMesh:Destroy()
			end)
			fixedSizeMesh = nil
		end

		return meshPart, didUseFixedSize
	end)

	if editableMesh then
		editableMesh:Destroy()
	end
	if fixedSizeMesh then
		fixedSizeMesh:Destroy()
	end
	if not ok then
		return nil, meshPartOrError
	end

	return meshPartOrError, {
		UsedFixedSize = usedFixedSize == true,
		Validated = true,
	}
end

function EditableMeshBuilder.buildFolderFromSpec(parent, name, spec, options)
	if not supportsEditableMesh() then
		return nil, "EditableMesh APIs unavailable"
	end

	local settings = options or {}
	local folder = Instance.new("Folder")
	folder.Name = name
	folder:SetAttribute("RenderMode", "MeshChunks")
	folder:SetAttribute("MeshValidated", true)

	local ok, result = pcall(function()
		for chunkIndex, chunk in ipairs(spec and spec.Chunks or {}) do
			local meshPart, metadataOrError = EditableMeshBuilder.buildMeshPartFromChunk(chunk)
			if not meshPart then
				error(metadataOrError, 2)
			end

			local metadata = metadataOrError
			meshPart.Name = chunk.Id or ("%s_%03d"):format(name, chunkIndex)
			meshPart.CFrame = CFrame.new(chunk.Center + (settings.CenterOffset or Vector3.zero))
			meshPart:SetAttribute("RenderMode", "MeshPart")
			meshPart:SetAttribute("MeshSource", metadata.UsedFixedSize and "FixedSizeClone" or "EditableMesh")
			meshPart:SetAttribute("MeshValidated", metadata.Validated == true)
			if settings.ConfigurePart then
				settings.ConfigurePart(meshPart, chunk, chunkIndex, metadata)
			end
			meshPart.Parent = folder
		end

		folder.Parent = parent
		return folder
	end)

	if not ok then
		folder:Destroy()
		return nil, result
	end

	return result, nil
end

return EditableMeshBuilder
