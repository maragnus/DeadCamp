local BlockerDecorator = {}

function BlockerDecorator.build(parent, shortcutHotspots)
	for index, hotspot in ipairs(shortcutHotspots or {}) do
		local center = hotspot.Position
		local blocker = Instance.new("Part")
		blocker.Name = ("ShortcutBlocker_%02d"):format(index)
		blocker.Anchored = true
		blocker.CanCollide = false
		blocker.CanTouch = false
		blocker.CanQuery = false
		blocker.Material = Enum.Material.Rock
		blocker.Color = Color3.fromRGB(91, 94, 88)
		blocker.Shape = Enum.PartType.Cylinder
		blocker.Size = Vector3.new(18, math.max(12, hotspot.Radius * 0.65), 18)
		blocker.CFrame = CFrame.new(center + Vector3.new(0, blocker.Size.Y * 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		blocker.Transparency = 0.35
		blocker.Parent = parent
		blocker:SetAttribute("Radius", hotspot.Radius)
	end
end

return BlockerDecorator
