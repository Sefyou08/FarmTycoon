--[[
	SeedBar.lua
	===========
	Barre de graines en bas de l'écran : une case par graine possédée (avec la
	quantité). Cliquer sur une case demande au serveur de la sélectionner ;
	la prochaine case de terre plantée utilisera cette graine.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CropUtil = require(ReplicatedStorage.Shared.CropUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local SeedBar = {}

local bar: Frame
local emptyLabel: TextLabel
local selectRemote: RemoteEvent

local function rebuild(seeds: { [string]: number }?, selected: string?)
	for _, child in bar:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local hasSeeds = false
	for order, cropId in CropUtil.SortedIds() do
		local count = seeds and seeds[cropId] or 0
		if count > 0 then
			hasSeeds = true
			local crop = CropUtil.Get(cropId)
			local isSelected = cropId == selected

			local slot = Theme.Button({
				Name = cropId,
				Size = UDim2.fromOffset(78, 78),
				LayoutOrder = order,
				BackgroundColor3 = if isSelected then Color3.fromRGB(90, 190, 100) else Theme.Colors.Panel,
				Text = "",
				Parent = bar,
			})
			local stroke = slot:FindFirstChildOfClass("UIStroke")
			if stroke and isSelected then
				stroke.Color = Color3.fromRGB(255, 255, 255)
				stroke.Thickness = 3
			end

			Theme.Label({
				Size = UDim2.new(1, 0, 0.55, 0),
				Text = crop.Icon or "🌱",
				Parent = slot,
			})
			Theme.Label({
				Size = UDim2.new(1, 0, 0.25, 0),
				Position = UDim2.fromScale(0, 0.55),
				Text = crop.DisplayName,
				TextColor3 = CropUtil.RarityInfo(crop.Rarity).Color,
				Parent = slot,
			})
			Theme.Label({
				Size = UDim2.new(1, 0, 0.22, 0),
				Position = UDim2.fromScale(0, 0.78),
				Text = "x" .. count,
				Parent = slot,
			})

			slot.Activated:Connect(function()
				selectRemote:FireServer(cropId)
			end)
		end
	end
	emptyLabel.Visible = not hasSeeds
end

function SeedBar.Init(screen: ScreenGui, StateController)
	selectRemote = Remotes.Get("SelectSeed")

	bar = Instance.new("Frame")
	bar.Name = "SeedBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -12)
	bar.Size = UDim2.fromOffset(600, 80)
	bar.BackgroundTransparency = 1
	bar.Parent = screen

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = bar

	emptyLabel = Theme.Label({
		Name = "Empty",
		Size = UDim2.fromOffset(420, 30),
		Text = "Aucune graine : va au stand 🌱 GRAINES !",
		TextStrokeTransparency = 0.4,
		Parent = bar,
	})

	local function refresh()
		rebuild(StateController.Get("Seeds"), StateController.Get("SelectedSeed"))
	end
	StateController.Changed:Connect(function(key)
		if key == "*" or key == "Seeds" or key == "SelectedSeed" then
			refresh()
		end
	end)
	refresh()
end

return SeedBar
