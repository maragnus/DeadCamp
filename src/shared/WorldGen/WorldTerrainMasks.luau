local WorldMath = require(script.Parent:WaitForChild("WorldMath"))

local WorldTerrainMasks = {}

function WorldTerrainMasks.build(loop, profile)
	local hotspots = {}

	for _, hotspot in ipairs(loop.ShortcutHotspots or {}) do
		hotspots[#hotspots + 1] = {
			Position = Vector3.new(hotspot.Position[1], hotspot.Position[2], hotspot.Position[3]),
			WorldDistance = hotspot.WorldDistance,
			LapDistance = hotspot.LapDistance,
			SampleA = hotspot.SampleA,
			SampleB = hotspot.SampleB,
		}
	end

	local roadHalfWidth = profile.RoadWidth * 0.5
	local shoulderRadius = roadHalfWidth + profile.ShoulderWidth
	local recoveryRadius = shoulderRadius + profile.RecoveryWidth
	local roughRadius = recoveryRadius + profile.DiscourageWidth

	return {
		RoadHalfWidth = roadHalfWidth,
		ShoulderRadius = shoulderRadius,
		RecoveryRadius = recoveryRadius,
		RoughRadius = roughRadius,
		TerrainInfluenceRadius = roughRadius + 18,
		ShortcutHotspots = hotspots,
	}
end

function WorldTerrainMasks.shortcutRiskAt(position, masks)
	local highestRisk = 0

	for _, hotspot in ipairs(masks.ShortcutHotspots or {}) do
		local distance = WorldMath.distanceXZ(position, hotspot.Position)
		if distance < hotspot.WorldDistance then
			highestRisk = math.max(highestRisk, 1 - (distance / hotspot.WorldDistance))
		end
	end

	return highestRisk
end

return WorldTerrainMasks
