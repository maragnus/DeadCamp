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

local SCREEN_GUI_NAME = "RVDebugPanel"
local PANEL_SIZE = UDim2.fromOffset(260, 420)
local PANEL_POSITION = UDim2.fromOffset(18, 18)
local SECTION_HEIGHT = 22
local BUTTON_HEIGHT = 38

local commandRemote = nil
local remoteAncestryConnection = nil
local actionButtons = {}

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

local function findCommandRemote()
	local debugFolder = ReplicatedStorage:FindFirstChild(RVDebugPanelConfig.RemoteFolderName)
	if not debugFolder or not debugFolder:IsA("Folder") then
		return nil
	end

	local remote = debugFolder:FindFirstChild(RVDebugPanelConfig.RemoteEventName)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	return nil
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

local statusLabel = create("TextLabel", {
	Name = "Status",
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	Text = "Waiting For Server Debug Remote",
	TextColor3 = Color3.fromRGB(214, 183, 113),
	TextSize = 12,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 2,
	Parent = panel,
})

local function updateConnectionState()
	local connected = commandRemote ~= nil and commandRemote.Parent ~= nil
	statusLabel.Text = connected and "Debug Remote Connected" or "Waiting For Server Debug Remote"
	statusLabel.TextColor3 = connected and Color3.fromRGB(141, 212, 149) or Color3.fromRGB(214, 183, 113)

	for button, baseColor in pairs(actionButtons) do
		button.Active = connected
		button.AutoButtonColor = connected
		button.BackgroundColor3 = baseColor
		button.BackgroundTransparency = connected and 0 or 0.35
		button.TextTransparency = connected and 0 or 0.25
	end
end

local function setCommandRemote(remote)
	if commandRemote == remote then
		updateConnectionState()
		return
	end

	if remoteAncestryConnection then
		remoteAncestryConnection:Disconnect()
		remoteAncestryConnection = nil
	end

	commandRemote = remote

	if commandRemote then
		remoteAncestryConnection = commandRemote.AncestryChanged:Connect(function(_, parent)
			if not parent then
				setCommandRemote(findCommandRemote())
			end
		end)
	end

	updateConnectionState()
end

local layoutOrder = 3

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
			local baseColor = buttonColor(action)
			local button = create("TextButton", {
				Name = action.Id,
				Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
				BackgroundColor3 = baseColor,
				BorderSizePixel = 0,
				AutoButtonColor = false,
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

			actionButtons[button] = baseColor
			button.Activated:Connect(function()
				if commandRemote then
					commandRemote:FireServer(action.Id)
				else
					updateConnectionState()
				end
			end)

			layoutOrder += 1
		end
	end
end

ReplicatedStorage.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("RemoteEvent")
		and descendant.Name == RVDebugPanelConfig.RemoteEventName
		and descendant.Parent
		and descendant.Parent.Name == RVDebugPanelConfig.RemoteFolderName then
		setCommandRemote(descendant)
	end
end)

setCommandRemote(findCommandRemote())
updatePanelHeight()
