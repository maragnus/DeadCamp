local WorldSeed = {}

local WorldMath = require(script.Parent:WaitForChild("WorldMath"))

local function stringHash(value)
	local hash = 2166136261

	for index = 1, #value do
		hash = bit32.bxor(hash, string.byte(value, index))
		hash = (hash * 16777619) % 2147483647
	end

	return hash
end

function WorldSeed.normalize(seed)
	local numericSeed = math.floor(tonumber(seed) or 0)
	if numericSeed == 0 then
		numericSeed = 1
	end

	if numericSeed < 0 then
		numericSeed = -numericSeed
	end

	return numericSeed % 2147483647
end

function WorldSeed.combine(seed, scope)
	local normalized = WorldSeed.normalize(seed)
	local scopeHash = stringHash(tostring(scope))
	return (normalized + scopeHash) % 2147483647
end

function WorldSeed.random(seed, scope)
	return Random.new(WorldSeed.combine(seed, scope))
end

function WorldSeed.resolve(options, defaultProfileId)
	local seed = options and options.Seed or 0
	local resolved = WorldSeed.normalize(seed)

	if resolved == 1 and (seed == nil or tonumber(seed) == nil or tonumber(seed) == 0) then
		resolved = WorldSeed.normalize(os.time())
	end

	return {
		Seed = resolved,
		ProfileId = options and options.ProfileId or defaultProfileId,
	}
end

function WorldSeed.describe(seedInfo)
	return ("%s:%d"):format(seedInfo.ProfileId, seedInfo.Seed)
end

return WorldSeed
