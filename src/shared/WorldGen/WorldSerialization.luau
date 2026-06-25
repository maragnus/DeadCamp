local HttpService = game:GetService("HttpService")

local RoadPathUtils = require(script.Parent:WaitForChild("RoadPathUtils"))
local WorldConstants = require(script.Parent:WaitForChild("WorldConstants"))

local WorldSerialization = {}
local ROAD_LOOP_DESCRIPTOR_VERSION = 2
local ROAD_NETWORK_DESCRIPTOR_VERSION = 1

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

local function roundToFixedPoint(value, scale)
	if value >= 0 then
		return math.floor(value * scale + 0.5)
	end

	return math.ceil(value * scale - 0.5)
end

local function compactRoadLoopPayload(loop, options)
	local settings = options or {}
	local scale = settings.QuantizationScale or WorldConstants.RoadLoopQuantizationScale
	local roadWidth = settings.RoadWidth or loop.RoadWidth
	assert(type(roadWidth) == "number", "encodeRoadLoop requires RoadWidth")

	local payload = {
		Version = ROAD_LOOP_DESCRIPTOR_VERSION,
		ProfileId = loop.ProfileId,
		Seed = loop.Seed,
		LoopLength = loop.LoopLength,
		StartIndex = loop.StartIndex or 1,
		Closed = loop.Closed ~= false,
		RoadWidth = roadWidth,
		QuantizationScale = scale,
		SamplePositions = {},
	}

	for _, sample in ipairs(loop.Samples) do
		payload.SamplePositions[#payload.SamplePositions + 1] = roundToFixedPoint(sample.Position.X, scale)
		payload.SamplePositions[#payload.SamplePositions + 1] = roundToFixedPoint(sample.Position.Y, scale)
		payload.SamplePositions[#payload.SamplePositions + 1] = roundToFixedPoint(sample.Position.Z, scale)
	end

	return payload
end

local function expandCompactRoadLoopPayload(payload)
	local scale = payload.QuantizationScale or WorldConstants.RoadLoopQuantizationScale
	local closed = payload.Closed ~= false
	local samplePositions = {}

	for index = 1, #(payload.SamplePositions or {}), 3 do
		samplePositions[#samplePositions + 1] = Vector3.new(
			payload.SamplePositions[index] / scale,
			payload.SamplePositions[index + 1] / scale,
			payload.SamplePositions[index + 2] / scale
		)
	end

	local loopLength = payload.LoopLength
	if type(loopLength) ~= "number" then
		loopLength = RoadPathUtils.pathLength(samplePositions, closed)
	end

	return {
		ProfileId = payload.ProfileId,
		Seed = payload.Seed,
		LoopLength = loopLength,
		StartIndex = payload.StartIndex or 1,
		Closed = closed,
		RoadWidth = payload.RoadWidth,
		ShortcutHotspots = payload.ShortcutHotspots or {},
		Samples = RoadPathUtils.sampleDescriptors(samplePositions, loopLength, closed),
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

local function compactSamplePositions(samples, scale)
	local compacted = {}
	for _, sample in ipairs(samples or {}) do
		local position = sampleToVector(sample)
		compacted[#compacted + 1] = roundToFixedPoint(position.X, scale)
		compacted[#compacted + 1] = roundToFixedPoint(position.Y, scale)
		compacted[#compacted + 1] = roundToFixedPoint(position.Z, scale)
	end
	return compacted
end

local function expandCompactSamplePositions(payload)
	local scale = payload.QuantizationScale or WorldConstants.RoadLoopQuantizationScale
	local samplePositions = {}
	for index = 1, #(payload.SamplePositions or {}), 3 do
		samplePositions[#samplePositions + 1] = Vector3.new(
			payload.SamplePositions[index] / scale,
			payload.SamplePositions[index + 1] / scale,
			payload.SamplePositions[index + 2] / scale
		)
	end
	return samplePositions
end

local function compactRoadPayload(road, scale)
	local samples = road.Samples or {}
	local samplePositions = {}
	for _, sample in ipairs(samples) do
		samplePositions[#samplePositions + 1] = sampleToVector(sample)
	end

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
		QuantizationScale = scale,
		SamplePositions = compactSamplePositions(samples, scale),
	}
end

local function expandRoadPayload(payload)
	local samplePositions = expandCompactSamplePositions(payload)
	local length = payload.Length
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
		Samples = RoadPathUtils.sampleDescriptors(samplePositions, length, false),
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
	local settings = options or {}
	local scale = settings.QuantizationScale or WorldConstants.RoadLoopQuantizationScale
	local payload = {
		Version = ROAD_NETWORK_DESCRIPTOR_VERSION,
		Loop = compactRoadLoopPayload(loop, options),
		Roads = {},
	}

	for _, road in ipairs(roads or {}) do
		payload.Roads[#payload.Roads + 1] = compactRoadPayload(road, scale)
	end

	return HttpService:JSONEncode(payload)
end

function WorldSerialization.decodeRoadNetwork(value)
	if type(value) ~= "string" or value == "" then
		error("Road network descriptor is empty", 2)
	end

	local payload = HttpService:JSONDecode(value)
	if payload.Version ~= ROAD_NETWORK_DESCRIPTOR_VERSION or payload.Loop == nil then
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
