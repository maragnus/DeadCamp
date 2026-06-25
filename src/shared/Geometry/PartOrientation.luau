local PartOrientation = {}

PartOrientation.CylinderAxis = {
	Width = "Width",
	Height = "Height",
	Length = "Length",
}

local CYLINDER_ROTATIONS = {
	[PartOrientation.CylinderAxis.Width] = CFrame.new(),
	[PartOrientation.CylinderAxis.Height] = CFrame.Angles(0, 0, math.rad(90)),
	[PartOrientation.CylinderAxis.Length] = CFrame.Angles(0, math.rad(-90), 0),
}

function PartOrientation.cylinderRotation(axis)
	local rotation = CYLINDER_ROTATIONS[axis]
	if not rotation then
		error(("Unknown cylinder axis: %s"):format(tostring(axis)), 2)
	end

	return rotation
end

return PartOrientation
