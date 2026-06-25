local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldGenShared = Shared:WaitForChild("WorldGen")

local WorldConflictUtils = require(WorldGenShared:WaitForChild("WorldConflictUtils"))
local RoadLoopDiagnostics = require(WorldGenShared:WaitForChild("RoadLoopDiagnostics"))

local WorldGenAudit = {}

local function pointFromArray(values)
	return Vector3.new(values[1], values[2], values[3])
end

local function addFailure(failures, message)
	failures[#failures + 1] = message
end

function WorldGenAudit.audit(options)
	local loop = options.Loop
	local profile = options.Profile
	local parcels = options.Parcels or {}
	local branches = options.Branches or {}
	local terrainContext = options.TerrainContext
	local root = options.Root
	local failures = {}
	local context = WorldConflictUtils.buildContext({
		Loop = loop,
		Profile = profile,
		LandformRuntime = terrainContext and terrainContext.LandformRuntime or nil,
		Branches = branches,
		Parcels = parcels,
	})

	local evaluated = loop and loop.Diagnostics or (loop and RoadLoopDiagnostics.evaluate(loop.Samples, options.Profile) or nil)
	if evaluated and not evaluated.SelfIntersectionOk then
		addFailure(failures, "Main road self-intersects")
	end

	for _, branch in ipairs(branches) do
		for sampleIndex = 3, #(branch.Samples or {}) do
			local point = pointFromArray(branch.Samples[sampleIndex].Position)
			local waterConflict = WorldConflictUtils.pointConflictsWater(context, point)
			if waterConflict then
				addFailure(failures, ("%s intersects river clearance"):format(branch.Id))
				break
			end
		end
	end

	local accepted = {}
	for _, parcel in ipairs(parcels) do
		local center = pointFromArray(parcel.Center)
		local reserveSize = Vector2.new(parcel.ReserveSize.X, parcel.ReserveSize.Y)
		local conflictReason = WorldConflictUtils.parcelConflictReason(context, center, parcel.Rotation, reserveSize, accepted)
		if conflictReason then
			addFailure(failures, ("%s conflicts with %s"):format(parcel.Id, conflictReason))
		end
		if parcel.AccessType ~= "RoadEdge" then
			local entry = pointFromArray(parcel.EntryPoint)
			local accessConflict = WorldConflictUtils.accessConflictReason(context, entry, center, parcel.AccessWidth or 8)
			if accessConflict then
				addFailure(failures, ("%s %s access crosses a protected corridor"):format(parcel.Id, parcel.AccessType))
			end
		end

		accepted[#accepted + 1] = {
			Center = center,
			Rotation = parcel.Rotation,
			ReserveSize = reserveSize,
		}
	end

	if root and terrainContext then
		local poiFolder = root:FindFirstChild("POIs")
		if poiFolder then
			for _, descendant in ipairs(poiFolder:GetDescendants()) do
				if descendant:IsA("BasePart") then
					local surfaceY = terrainContext:sampleSurfaceHeight(descendant.Position.X, descendant.Position.Z)
					local bottomY = descendant.Position.Y - descendant.Size.Y * 0.5
					if bottomY < surfaceY + 1 then
						addFailure(failures, ("%s is buried or clipped into terrain"):format(descendant.Name))
						break
					end
				end
			end
		end
	end

	return {
		Passed = #failures == 0,
		Failures = failures,
		Summary = #failures == 0 and "World audit passed" or table.concat(failures, " | "),
	}
end

return WorldGenAudit
