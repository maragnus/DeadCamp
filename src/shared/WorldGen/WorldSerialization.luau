local HttpService = game:GetService("HttpService")

local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))
local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))
local WorldMath = require(script.Parent:WaitForChild("WorldMath"))

local WorldSerialization = {}
local ROAD_LOOP_DESCRIPTOR_VERSION = 3
local ROAD_NETWORK_DESCRIPTOR_VERSION = 3

local function vectorToArray(vector)
	return { vector.X, vector.Y, vector.Z }
end

local function arrayToVector(values)
	return Vector3.new(values[1], values[2], values[3])
end

local function sampleToVector(sample)
	local position = sample.Position
	if typeof(position) == "Vector3" then
		return position
	end
	return arrayToVector(position)
end

local function deserializeSamples(samples, closed)
	if type(samples) ~= "table" or #samples == 0 then
		return {}
	end

	return RoadPathUtils.deserializeSamples(samples)
end

local function resolveQuantizationScale(options)
	local scale = options and options.QuantizationScale or WorldConstants.RoadLoopQuantizationScale
	assert(type(scale) == "number" and scale > 0, "Road descriptor quantization scale must be a positive number")
	return scale
end

local function quantizePositions(samples, scale)
	local quantized = {}
	for _, sample in ipairs(samples or {}) do
		local position = sampleToVector(sample)
		quantized[#quantized + 1] = math.round(position.X * scale)
		quantized[#quantized + 1] = math.round(position.Y * scale)
		quantized[#quantized + 1] = math.round(position.Z * scale)
	end
	return quantized
end

local function positionsFromSamples(samples)
	local positions = {}
	for _, sample in ipairs(samples or {}) do
		positions[#positions + 1] = sampleToVector(sample)
	end
	return positions
end

local function compactRoadLoopPayload(loop, options)
	local settings = options or {}
	local roadWidth = settings.RoadWidth or loop.RoadWidth
	local quantizationScale = resolveQuantizationScale(settings)
	assert(type(roadWidth) == "number", "encodeRoadLoop requires RoadWidth")

	local payload = {
		Version = ROAD_LOOP_DESCRIPTOR_VERSION,
		ProfileId = loop.ProfileId,
		Seed = loop.Seed,
		LoopLength = loop.LoopLength,
		StartIndex = loop.StartIndex or 1,
		Closed = loop.Closed ~= false,
		RoadWidth = roadWidth,
		QuantizationScale = quantizationScale,
		SamplePositions = quantizePositions(loop.Samples, quantizationScale),
	}

	return payload
end

local function expandCompactRoadLoopPayload(payload)
	local closed = payload.Closed ~= false
	local samples = nil
	local loopLength = payload.LoopLength
	if payload.Samples ~= nil then
		samples = deserializeSamples(payload.Samples, closed)
	else
		local scale = payload.QuantizationScale or WorldConstants.RoadLoopQuantizationScale
		local samplePositions = {}
		for index = 1, #(payload.SamplePositions or {}), 3 do
			samplePositions[#samplePositions + 1] = Vector3.new(
				payload.SamplePositions[index] / scale,
				payload.SamplePositions[index + 1] / scale,
				payload.SamplePositions[index + 2] / scale
			)
		end
		if type(loopLength) ~= "number" then
			loopLength = RoadPathUtils.pathLength(samplePositions, closed)
		end
		samples = RoadPathUtils.sampleDescriptors(samplePositions, loopLength, closed)
	end

	if type(loopLength) ~= "number" then
		loopLength = RoadPathUtils.pathLength(positionsFromSamples(samples), closed)
	end

	return {
		ProfileId = payload.ProfileId,
		Seed = payload.Seed,
		LoopLength = loopLength,
		StartIndex = payload.StartIndex or 1,
		Closed = closed,
		RoadWidth = payload.RoadWidth,
		ShortcutHotspots = payload.ShortcutHotspots or {},
		Samples = samples,
	}
end

local function expandLegacyRoadLoopPayload(payload)
	local loop = {
		ProfileId = payload.ProfileId,
		Seed = payload.Seed,
		LoopLength = payload.LoopLength,
		StartIndex = payload.StartIndex or 1,
		Closed = true,
		ShortcutHotspots = payload.ShortcutHotspots or {},
		Samples = {},
	}

	for _, sample in ipairs(payload.Samples or {}) do
		loop.Samples[#loop.Samples + 1] = {
			Position = arrayToVector(sample.Position),
			Tangent = arrayToVector(sample.Tangent),
			Right = arrayToVector(sample.Right),
			Up = arrayToVector(sample.Up),
			Curvature = sample.Curvature,
			LapDistance = sample.LapDistance,
		}
	end

	return loop
end

local function compactRoadPayload(road, options)
	local samples = road.Samples or {}
	local samplePositions = positionsFromSamples(samples)
	local quantizationScale = resolveQuantizationScale(options)

	local length = road.Length
	if type(length) ~= "number" then
		length = RoadPathUtils.pathLength(samplePositions, false)
	end

	return {
		Id = road.Id,
		Type = road.Type,
		Template = road.Template,
		RoadSampleIndex = road.RoadSampleIndex,
		Length = length,
		HalfWidth = road.HalfWidth,
		EntranceTaperLength = road.EntranceTaperLength,
		NodeIndices = road.NodeIndices,
		TouchesLoop = road.TouchesLoop == true,
		RejoinsLoop = road.RejoinsLoop == true,
		EndsAtLeaf = road.EndsAtLeaf == true,
		Start = road.Start,
		Finish = road.Finish,
		QuantizationScale = quantizationScale,
		SamplePositions = quantizePositions(samples, quantizationScale),
	}
end

local function expandRoadPayload(payload)
	local samples = nil
	local length = payload.Length
	if payload.Samples ~= nil then
		samples = deserializeSamples(payload.Samples, false)
	else
		local scale = payload.QuantizationScale or WorldConstants.RoadLoopQuantizationScale
		local samplePositions = {}
		for index = 1, #(payload.SamplePositions or {}), 3 do
			samplePositions[#samplePositions + 1] = Vector3.new(
				payload.SamplePositions[index] / scale,
				payload.SamplePositions[index + 1] / scale,
				payload.SamplePositions[index + 2] / scale
			)
		end
		if type(length) ~= "number" then
			length = RoadPathUtils.pathLength(samplePositions, false)
		end
		samples = RoadPathUtils.sampleDescriptors(samplePositions, length, false)
	end

	local samplePositions = positionsFromSamples(samples)
	if type(length) ~= "number" then
		length = RoadPathUtils.pathLength(samplePositions, false)
	end

	return {
		Id = payload.Id,
		Type = payload.Type,
		Template = payload.Template,
		RoadSampleIndex = payload.RoadSampleIndex,
		Length = length,
		HalfWidth = payload.HalfWidth,
		EntranceTaperLength = payload.EntranceTaperLength,
		NodeIndices = payload.NodeIndices,
		TouchesLoop = payload.TouchesLoop == true,
		RejoinsLoop = payload.RejoinsLoop == true,
		EndsAtLeaf = payload.EndsAtLeaf == true,
		Start = payload.Start,
		Finish = payload.Finish,
		Samples = samples,
	}
end

function WorldSerialization.encodeRoadLoop(loop, options)
	return HttpService:JSONEncode(compactRoadLoopPayload(loop, options))
end

function WorldSerialization.decodeRoadLoop(value)
	if type(value) ~= "string" or value == "" then
		error("Road loop descriptor is empty", 2)
	end

	local payload = HttpService:JSONDecode(value)
	if payload.Version == ROAD_LOOP_DESCRIPTOR_VERSION or payload.SamplePositions ~= nil then
		return expandCompactRoadLoopPayload(payload)
	end

	return expandLegacyRoadLoopPayload(payload)
end

function WorldSerialization.encodeRoadNetwork(loop, roads, options)
	local payload = {
		Version = ROAD_NETWORK_DESCRIPTOR_VERSION,
		Loop = compactRoadLoopPayload(loop, options),
		Roads = {},
	}

	for _, road in ipairs(roads or {}) do
		payload.Roads[#payload.Roads + 1] = compactRoadPayload(road, options)
	end

	return HttpService:JSONEncode(payload)
end

function WorldSerialization.decodeRoadNetwork(value)
	if type(value) ~= "string" or value == "" then
		error("Road network descriptor is empty", 2)
	end

	local payload = HttpService:JSONDecode(value)
	if payload.Loop == nil then
		error("Unsupported road network descriptor", 2)
	end

	local loopPayload = payload.Loop
	local loop = nil
	if loopPayload.Version == ROAD_LOOP_DESCRIPTOR_VERSION or loopPayload.SamplePositions ~= nil then
		loop = expandCompactRoadLoopPayload(loopPayload)
	else
		loop = expandLegacyRoadLoopPayload(loopPayload)
	end

	local roads = {}
	for _, roadPayload in ipairs(payload.Roads or {}) do
		roads[#roads + 1] = expandRoadPayload(roadPayload)
	end

	return {
		Version = payload.Version,
		ProfileId = loop.ProfileId,
		Seed = loop.Seed,
		Loop = loop,
		Roads = roads,
	}
end

function WorldSerialization.buildRoadNetwork(loop, roads)
	return {
		Version = ROAD_NETWORK_DESCRIPTOR_VERSION,
		ProfileId = loop and loop.ProfileId or nil,
		Seed = loop and loop.Seed or nil,
		Loop = WorldMath.deepCopy(loop),
		Roads = WorldMath.deepCopy(roads or {}),
	}
end

function WorldSerialization.encodeRibbonSpec(spec)
	local payload = {
		ProfileId = spec.ProfileId,
		Seed = spec.Seed,
		Width = spec.Width,
		Thickness = spec.Thickness,
		Closed = spec.Closed == true,
		Chunks = {},
	}

	for _, chunk in ipairs(spec.Chunks or {}) do
		local encodedChunk = {
			Id = chunk.Id,
			Center = vectorToArray(chunk.Center),
			Width = chunk.Width,
			Thickness = chunk.Thickness,
			BoundsSize = vectorToArray(chunk.BoundsSize),
			Vertices = {},
			Triangles = chunk.Triangles,
			Segments = {},
		}

		for _, vertex in ipairs(chunk.Vertices or {}) do
			encodedChunk.Vertices[#encodedChunk.Vertices + 1] = vectorToArray(vertex)
		end

		for _, segment in ipairs(chunk.Segments or {}) do
			encodedChunk.Segments[#encodedChunk.Segments + 1] = {
				Start = vectorToArray(segment.Start),
				Finish = vectorToArray(segment.Finish),
				Center = vectorToArray(segment.Center),
				LookAt = vectorToArray(segment.LookAt),
				Width = segment.Width,
				Length = segment.Length,
			}
		end

		payload.Chunks[#payload.Chunks + 1] = encodedChunk
	end

	return HttpService:JSONEncode(payload)
end

function WorldSerialization.decodeRibbonSpec(value)
	local payload = HttpService:JSONDecode(value)
	local spec = {
		ProfileId = payload.ProfileId,
		Seed = payload.Seed,
		Width = payload.Width,
		Thickness = payload.Thickness,
		Closed = payload.Closed == true,
		Chunks = {},
	}

	for _, chunk in ipairs(payload.Chunks or {}) do
		local decodedChunk = {
			Id = chunk.Id,
			Center = arrayToVector(chunk.Center),
			Width = chunk.Width,
			Thickness = chunk.Thickness,
			BoundsSize = arrayToVector(chunk.BoundsSize),
			Vertices = {},
			Triangles = chunk.Triangles or {},
			Segments = {},
		}

		for _, vertex in ipairs(chunk.Vertices or {}) do
			decodedChunk.Vertices[#decodedChunk.Vertices + 1] = arrayToVector(vertex)
		end

		for _, segment in ipairs(chunk.Segments or {}) do
			decodedChunk.Segments[#decodedChunk.Segments + 1] = {
				Start = arrayToVector(segment.Start),
				Finish = arrayToVector(segment.Finish),
				Center = arrayToVector(segment.Center),
				LookAt = arrayToVector(segment.LookAt),
				Width = segment.Width,
				Length = segment.Length,
			}
		end

		spec.Chunks[#spec.Chunks + 1] = decodedChunk
	end

	return spec
end

function WorldSerialization.encodeParcels(parcels)
	return HttpService:JSONEncode(parcels)
end

function WorldSerialization.decodeParcels(value)
	return HttpService:JSONDecode(value)
end

function WorldSerialization.encodeLandform(descriptor)
	return HttpService:JSONEncode(descriptor)
end

function WorldSerialization.decodeLandform(value)
	return HttpService:JSONDecode(value)
end

function WorldSerialization.encodeProfileDescriptor(descriptor)
	return HttpService:JSONEncode(descriptor)
end

function WorldSerialization.decodeProfileDescriptor(value)
	return HttpService:JSONDecode(value)
end

return WorldSerialization
