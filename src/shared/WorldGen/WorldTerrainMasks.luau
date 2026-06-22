local WorldMath = require(script.Parent:WaitForChild("WorldMath"))

local WorldTerrainMasks = {}

function WorldTerrainMasks.build(loop, profile)
	local hotspots = {}

	for index, hotspot in ipairs(loop.ShortcutHotspots or {}) do
		local mode = (index % 2 == 0) and "Valley" or "Hill"
		hotspots[#hotspots + 1] = {
			Position = Vector3.new(hotspot.Position[1], hotspot.Position[2], hotspot.Position[3]),
			Radius = math.max(profile.BarrierWidth * 0.38, hotspot.WorldDistance * 0.62),
			WorldDistance = hotspot.WorldDistance,
			LapDistance = hotspot.LapDistance,
			Mode = mode,
			Amplitude = mode == "Hill" and 12 or 8,
		}
	end

	return {
		RoadHalfWidth = profile.RoadWidth * 0.5,
		ShoulderRadius = profile.RoadWidth * 0.5 + profile.ShoulderWidth,
		RecoveryRadius = profile.RoadWidth * 0.5 + profile.ShoulderWidth + profile.RecoveryWidth,
		DiscourageRadius = profile.RoadWidth * 0.5 + profile.ShoulderWidth + profile.DiscourageWidth,
		BarrierRadius = profile.RoadWidth * 0.5 + profile.ShoulderWidth + profile.BarrierWidth,
		ShortcutHotspots = hotspots,
	}
end

function WorldTerrainMasks.shortcutRiskAt(position, masks)
	local highestRisk = 0

	for _, hotspot in ipairs(masks.ShortcutHotspots or {}) do
		local distance = WorldMath.distanceXZ(position, hotspot.Position)
		if distance < hotspot.Radius then
			highestRisk = math.max(highestRisk, 1 - (distance / hotspot.Radius))
		end
	end

	return highestRisk
end

return WorldTerrainMasks
