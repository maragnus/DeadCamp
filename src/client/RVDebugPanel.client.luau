local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RVDebugPanelConfig = require(Shared:WaitForChild("RVDebugPanelConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local debugFolder = ReplicatedStorage:WaitForChild(RVDebugPanelConfig.RemoteFolderName)
local commandRemote = debugFolder:WaitForChild(RVDebugPanelConfig.RemoteEventName)

local SCREEN_GUI_NAME = "RVDebugPanel"
local PANEL_SIZE = UDim2.fromOffset(260, 290)
local PANEL_POSITION = UDim2.fromOffset(18, 18)
local SECTION_HEIGHT = 22
local BUTTON_HEIGHT = 38

local function create(className, properties)
	local instance = Instance.new(className)

	for key, value in pairs(properties or {}) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end

	instance.Parent = properties.Parent
	return instance
end

local function buttonColor(action)
	if action.Id == "StopRV" then
		return Color3.fromRGB(132, 57, 57)
	end
	if action.Kind == RVDebugPanelConfig.ActionKinds.Spawn then
		return Color3.fromRGB(73, 103, 80)
	end
	return Color3.fromRGB(117, 92, 52)
end

local existingGui = playerGui:FindFirstChild(SCREEN_GUI_NAME)
if existingGui then
	existingGui:Destroy()
end

local screenGui = create("ScreenGui", {
	Name = SCREEN_GUI_NAME,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

local panel = create("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0, 0),
	Position = PANEL_POSITION,
	Size = PANEL_SIZE,
	BackgroundColor3 = Color3.fromRGB(24, 28, 31),
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Parent = screenGui,
})
create("UICorner", {
	CornerRadius = UDim.new(0, 14),
	Parent = panel,
})
create("UIStroke", {
	Color = Color3.fromRGB(92, 104, 112),
	Transparency = 0.2,
	Thickness = 1,
	Parent = panel,
})
create("UIPadding", {
	PaddingTop = UDim.new(0, 14),
	PaddingBottom = UDim.new(0, 14),
	PaddingLeft = UDim.new(0, 14),
	PaddingRight = UDim.new(0, 14),
	Parent = panel,
})

local panelLayout = create("UIListLayout", {
	Padding = UDim.new(0, 8),
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = panel,
})

local function updatePanelHeight()
	panel.Size = UDim2.new(0, PANEL_SIZE.X.Offset, 0, panelLayout.AbsoluteContentSize.Y + 28)
end

panelLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updatePanelHeight)

create("TextLabel", {
	Name = "Title",
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundTransparency = 1,
	Text = "RV Debug Panel",
	TextColor3 = Color3.fromRGB(233, 236, 239),
	TextSize = 20,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1,
	Parent = panel,
})

local layoutOrder = 2

for _, section in ipairs(RVDebugPanelConfig.Sections) do
	create("TextLabel", {
		Name = section.Title .. "Label",
		Size = UDim2.new(1, 0, 0, SECTION_HEIGHT),
		BackgroundTransparency = 1,
		Text = string.upper(section.Title),
		TextColor3 = Color3.fromRGB(156, 170, 176),
		TextSize = 13,
		Font = Enum.Font.Code,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = layoutOrder,
		Parent = panel,
	})
	layoutOrder += 1

	for _, actionId in ipairs(section.ActionIds) do
		local action = RVDebugPanelConfig.action(actionId)
		if action then
			local button = create("TextButton", {
				Name = action.Id,
				Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
				BackgroundColor3 = buttonColor(action),
				BorderSizePixel = 0,
				AutoButtonColor = true,
				Text = action.Label,
				TextColor3 = Color3.fromRGB(245, 246, 247),
				TextSize = 16,
				Font = Enum.Font.Code,
				LayoutOrder = layoutOrder,
				Parent = panel,
			})
			create("UICorner", {
				CornerRadius = UDim.new(0, 10),
				Parent = button,
			})

			button.Activated:Connect(function()
				commandRemote:FireServer(action.Id)
			end)

			layoutOrder += 1
		end
	end
end

updatePanelHeight()
