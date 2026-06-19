-- Converts a front-to-back module list into absolute vehicle bounds.

local Layout = {}

local function copyModule(source)
	local result = {}
	for key, value in pairs(source) do
		result[key] = value
	end
	return result
end

function Layout.resolve(plan)
	local scale = plan.Scale
	local sections = {}
	local totalLength = 0

	for _, module in ipairs(plan.Modules) do
		totalLength += module.Length * scale
	end

	local cursor = -totalLength * 0.5
	for index, module in ipairs(plan.Modules) do
		local section = copyModule(module)
		section.Index = index
		section.Length = module.Length * scale
		section.Z0 = cursor
		section.Z1 = cursor + section.Length
		sections[#sections + 1] = section
		cursor = section.Z1
	end

	return {
		Scale = scale,
		Sections = sections,
		TotalZ0 = -totalLength * 0.5,
		TotalZ1 = totalLength * 0.5,
		TotalLength = totalLength,
	}
end

function Layout.localZ(section, fraction)
	return section.Z0 + section.Length * fraction
end

function Layout.localSpan(section, z0Fraction, z1Fraction)
	return Layout.localZ(section, z0Fraction), Layout.localZ(section, z1Fraction)
end

return Layout
