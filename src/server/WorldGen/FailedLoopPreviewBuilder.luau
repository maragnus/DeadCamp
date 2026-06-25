local FailedLoopPreviewBuilder = {}

local PREVIEW_FOLDER_NAME = "FailedLoopPreview"
local ANCHOR_FOLDER_NAME = "Anchors"
local ANCHOR_SEGMENT_FOLDER_NAME = "AnchorPolygon"
local CONTROL_FRAME_FOLDER_NAME = "ControlFrames"
local CONTROL_FRAME_SEGMENT_FOLDER_NAME = "ControlFramePolygon"
local CURVE_SEGMENT_FOLDER_NAME = "CurveSegments"
local SAMPLE_SEGMENT_FOLDER_NAME = "SampledLoop"
local MARKER_FOLDER_NAME = "Markers"
local DEBUG_PREVIEW_BASE_HEIGHT = 160

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		folder:ClearAllChildren()
		return folder
	end
	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function createStringValue(parent, name, value)
	local stringValue = Instance.new("StringValue")
	stringValue.Name = name
	stringValue.Value = value
	stringValue.Parent = parent
	return stringValue
end

local function createSegment(parent, name, startPoint, finishPoint, width, color, transparency)
	local delta = finishPoint - startPoint
	local length = delta.Magnitude
	if length <= 0.05 then
		return nil
	end

	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency or 0
	part.Size = Vector3.new(width, width, length)
	part.CFrame = CFrame.lookAt((startPoint + finishPoint) * 0.5, finishPoint, Vector3.yAxis)
	part.Parent = parent
	return part
end

local function createMarker(parent, name, position, size, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Shape = Enum.PartType.Ball
	part.Material = material or Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(size, size, size)
	part.CFrame = CFrame.new(position)
	part.Parent = parent
	return part
end

local function previewPoint(point, extraY)
	return Vector3.new(point.X, DEBUG_PREVIEW_BASE_HEIGHT + (extraY or 0), point.Z)
end

local function connectClosedPoints(parent, points, width, color, transparency, prefix, verticalOffset)
	if #points < 2 then
		return
	end

	for index = 1, #points do
		local nextIndex = (index % #points) + 1
		createSegment(
			parent,
			("%s_%03d"):format(prefix, index),
			previewPoint(points[index], verticalOffset),
			previewPoint(points[nextIndex], verticalOffset),
			width,
			color,
			transparency
		)
	end
end

local function connectOpenPoints(parent, points, width, color, transparency, prefix, verticalOffset)
	if #points < 2 then
		return
	end

	for index = 1, #points - 1 do
		createSegment(
			parent,
			("%s_%03d"):format(prefix, index),
			previewPoint(points[index], verticalOffset),
			previewPoint(points[index + 1], verticalOffset),
			width,
			color,
			transparency
		)
	end
end

local function connectClosedSamples(parent, samples, width, color, transparency, prefix, verticalOffset)
	local positions = {}
	for _, sample in ipairs(samples or {}) do
		positions[#positions + 1] = sample.Position
	end
	connectClosedPoints(parent, positions, width, color, transparency, prefix, verticalOffset)
end

local function framePositions(frames)
	local positions = {}
	for _, frame in ipairs(frames or {}) do
		positions[#positions + 1] = frame.Position
	end
	return positions
end

local function highlightIntersection(markersFolder, segmentsFolder, samples, intersections)
	if not intersections or intersections.Count <= 0 then
		return
	end

	if intersections.Position then
		createMarker(markersFolder, "IntersectionMarker", previewPoint(intersections.Position, 2.5), 14, Color3.fromRGB(215, 63, 63))
	end

	for _, sampleIndex in ipairs({ intersections.SampleA, intersections.SampleB }) do
		if sampleIndex then
			local nextIndex = (sampleIndex % #samples) + 1
			local sample = samples[sampleIndex]
			local nextSample = samples[nextIndex]
			if sample and nextSample then
				createSegment(
					segmentsFolder,
					("IntersectingSegment_%03d"):format(sampleIndex),
					previewPoint(sample.Position, 1.4),
					previewPoint(nextSample.Position, 1.4),
					5,
					Color3.fromRGB(255, 83, 83),
					0.1
				)
			end
		end
	end
end

function FailedLoopPreviewBuilder.build(parent, failureReport)
	local attempt = failureReport and failureReport.BestAttempt
	if not attempt then
		return nil
	end

	local previewFolder = ensureFolder(parent, PREVIEW_FOLDER_NAME)
	local anchorFolder = ensureFolder(previewFolder, ANCHOR_FOLDER_NAME)
	local anchorSegmentsFolder = ensureFolder(previewFolder, ANCHOR_SEGMENT_FOLDER_NAME)
	local controlFrameFolder = ensureFolder(previewFolder, CONTROL_FRAME_FOLDER_NAME)
	local controlFrameSegmentsFolder = ensureFolder(previewFolder, CONTROL_FRAME_SEGMENT_FOLDER_NAME)
	local curveSegmentsFolder = ensureFolder(previewFolder, CURVE_SEGMENT_FOLDER_NAME)
	local sampleSegmentsFolder = ensureFolder(previewFolder, SAMPLE_SEGMENT_FOLDER_NAME)
	local markersFolder = ensureFolder(previewFolder, MARKER_FOLDER_NAME)

	createStringValue(previewFolder, "Summary", ("Best failed attempt %d using %s"):format(attempt.AttemptNumber, attempt.StrategyName))
	createStringValue(previewFolder, "FailureCounts", ("planner=%d, selfIntersection=%d"):format(
		failureReport.FailureCounts.PlannerFailure or 0,
		failureReport.FailureCounts.SelfIntersection or 0
	))
	if failureReport.FailureExamples and #failureReport.FailureExamples > 0 then
		createStringValue(previewFolder, "SampleRejects", table.concat(failureReport.FailureExamples, " | "))
	end

	for index, anchor in ipairs(attempt.Anchors or {}) do
		local marker = createMarker(anchorFolder, ("Anchor_%02d"):format(index), previewPoint(anchor, 1.5), 6, Color3.fromRGB(241, 213, 91), Enum.Material.SmoothPlastic)
		marker.Transparency = 0.05
	end
	connectClosedPoints(anchorSegmentsFolder, attempt.Anchors or {}, 2.5, Color3.fromRGB(235, 210, 101), 0.45, "AnchorSpan", 0.8)

	for index, frame in ipairs(attempt.ControlFrames or {}) do
		local marker = createMarker(controlFrameFolder, ("ControlFrame_%02d"):format(index), previewPoint(frame.Position, 2.2), 5.5, Color3.fromRGB(87, 217, 175), Enum.Material.SmoothPlastic)
		marker.Transparency = 0.08
		if frame.Tangent then
			createSegment(
				controlFrameFolder,
				("ControlHeading_%02d"):format(index),
				previewPoint(frame.Position, 2.2),
				previewPoint(frame.Position + frame.Tangent * 34, 2.2),
				2.2,
				Color3.fromRGB(87, 217, 175),
				0.12
			)
		end
	end
	connectClosedPoints(controlFrameSegmentsFolder, framePositions(attempt.ControlFrames), 2.1, Color3.fromRGB(89, 211, 170), 0.32, "ControlFrameSpan", 1.1)

	for index, segment in ipairs(attempt.CurveSegments or {}) do
		local color = segment.Type == "Arc" and Color3.fromRGB(112, 214, 255) or Color3.fromRGB(142, 154, 255)
		connectOpenPoints(curveSegmentsFolder, segment.Points or {}, segment.Type == "Arc" and 2.8 or 2.2, color, 0.16, ("CurveSegment_%03d"):format(index), 1.45)
	end
	connectClosedSamples(sampleSegmentsFolder, attempt.Samples or {}, 3.5, Color3.fromRGB(255, 154, 74), 0.08, "SampleSpan", 1.8)

	if attempt.Samples and attempt.Samples[1] then
		createMarker(markersFolder, "StartSample", previewPoint(attempt.Samples[1].Position, 2), 10, Color3.fromRGB(78, 188, 255))
	end

	highlightIntersection(markersFolder, sampleSegmentsFolder, attempt.Samples or {}, attempt.Diagnostics and attempt.Diagnostics.Intersections)
	return previewFolder
end

return FailedLoopPreviewBuilder
