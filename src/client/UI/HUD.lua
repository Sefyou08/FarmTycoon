--[[
	HUD.lua
	=======
	Interface principale toujours visible :
	  - compteurs de Coins (animé) et de Rebirths, en haut au centre
	  - barre de niveau / XP et revenus des socles sous les compteurs
	  - grille de boutons à gauche, sur 2 colonnes (🏠 Ma ferme, 🎒 Sac, ...)
	Les autres écrans ajoutent leurs boutons avec HUD.AddButton().
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local HUD = {}

local player = Players.LocalPlayer

HUD.Screen = nil :: ScreenGui?

local coinsLabel: TextLabel
local rebirthsLabel: TextLabel
local incomeLabel: TextLabel
local levelFill: Frame
local levelLabel: TextLabel
local leftColumn: Frame
local coinsDisplayValue = Instance.new("NumberValue") -- valeur animée affichée

local function buildCounter(parent: Instance, name: string, icon: string, color: Color3, order: number): TextLabel
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromOffset(190, 44)
	frame.BackgroundColor3 = Theme.Colors.Panel
	frame.BackgroundTransparency = 0.1
	frame.LayoutOrder = order
	frame.Parent = parent
	Theme.Corner(frame, 12)
	Theme.Stroke(frame, 2)

	Theme.Label({
		Name = "Icon",
		Size = UDim2.new(0, 36, 1, -8),
		Position = UDim2.fromOffset(6, 4),
		Text = icon,
		Parent = frame,
	})

	return Theme.Label({
		Name = "Value",
		Size = UDim2.new(1, -52, 1, -10),
		Position = UDim2.fromOffset(46, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
		Text = "0",
		Parent = frame,
	})
end

local function setCoins(value: number)
	-- Petite animation de compteur qui défile + "pop" du cadre
	TweenService:Create(coinsDisplayValue, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Value = value }):Play()
	local frame = coinsLabel.Parent :: Frame
	frame.Size = UDim2.fromOffset(200, 48)
	TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(190, 44) }):Play()
end

local function setRebirths(value: number)
	rebirthsLabel.Text = Format.Number(value)
end

-- Ajoute un bouton dans la colonne de gauche.
function HUD.AddButton(name: string, text: string, color: Color3, order: number, onClick: () -> ()): TextButton
	local button = Theme.Button({
		Name = name,
		Size = UDim2.fromOffset(130, 40),
		BackgroundColor3 = color,
		Text = text,
		LayoutOrder = order,
		Parent = leftColumn,
	})
	button.Activated:Connect(onClick)
	return button
end

function HUD.Init(StateController)
	local screen = Instance.new("ScreenGui")
	screen.Name = "FarmHUD"
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = player:WaitForChild("PlayerGui")
	HUD.Screen = screen

	-- Compteurs en haut au centre
	local top = Instance.new("Frame")
	top.Name = "TopBar"
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 8)
	top.Size = UDim2.fromOffset(400, 48)
	top.BackgroundTransparency = 1
	top.Parent = screen

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = top

	coinsLabel = buildCounter(top, "Coins", "💰", Theme.Colors.Coins, 1)
	rebirthsLabel = buildCounter(top, "Rebirths", "⭐", Theme.Colors.Rebirth, 2)

	coinsDisplayValue.Changed:Connect(function(value)
		coinsLabel.Text = Format.Number(value)
	end)

	-- Barre de niveau / XP
	local levelBar = Instance.new("Frame")
	levelBar.Name = "LevelBar"
	levelBar.AnchorPoint = Vector2.new(0.5, 0)
	levelBar.Position = UDim2.new(0.5, 0, 0, 60)
	levelBar.Size = UDim2.fromOffset(390, 20)
	levelBar.BackgroundColor3 = Theme.Colors.Panel
	levelBar.Parent = screen
	Theme.Corner(levelBar, 8)
	Theme.Stroke(levelBar, 2)
	levelFill = Instance.new("Frame")
	levelFill.Size = UDim2.fromScale(0, 1)
	levelFill.BackgroundColor3 = Color3.fromRGB(90, 200, 255)
	levelFill.BorderSizePixel = 0
	levelFill.Parent = levelBar
	Theme.Corner(levelFill, 8)
	levelLabel = Theme.Label({ Size = UDim2.fromScale(1, 1), ZIndex = 2, TextStrokeTransparency = 0.4, Text = "", Parent = levelBar })

	-- Revenus des créatures exposées, sous la barre de niveau
	incomeLabel = Theme.Label({
		Name = "Income",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.fromOffset(260, 22),
		TextColor3 = Theme.Colors.Coins,
		TextStrokeTransparency = 0.4,
		Text = "",
		Parent = screen,
	})

	-- Colonne de boutons à gauche
	leftColumn = Instance.new("Frame")
	leftColumn.Name = "LeftButtons"
	leftColumn.AnchorPoint = Vector2.new(0, 0.5)
	leftColumn.Position = UDim2.new(0, 12, 0.5, 0)
	leftColumn.Size = UDim2.fromOffset(266, 376) -- 15 boutons sur 2 colonnes
	leftColumn.BackgroundTransparency = 1
	leftColumn.Parent = screen

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(130, 40)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.FillDirectionMaxCells = 2
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.Parent = leftColumn

	local teleportRemote: RemoteEvent = Remotes.Get("RequestTeleportHome")
	HUD.AddButton("HomeButton", "🏠 Ma ferme", Theme.Colors.Button, 1, function()
		-- Le client se contente de DEMANDER ; le serveur décide (cooldown).
		teleportRemote:FireServer()
	end)

	-- Réaction aux changements d'état envoyés par le serveur
	StateController.Changed:Connect(function(key, value)
		if key == "*" then
			coinsDisplayValue.Value = value.Coins or 0
			setRebirths(value.Rebirths or 0)
		elseif key == "Coins" then
			setCoins(value)
		elseif key == "Rebirths" then
			setRebirths(value)
		end
		if key == "*" or key == "XP" or key == "Level" then
			local level = StateController.Get("Level") or 1
			local xp = StateController.Get("XP") or 0
			local needed = math.floor(Config.Progression.XPBase * level ^ Config.Progression.XPExponent)
			levelFill.Size = UDim2.fromScale(math.clamp(xp / needed, 0, 1), 1)
			levelLabel.Text = ("Niveau %d   •   %s / %s XP"):format(level, Format.Number(xp), Format.Number(needed))
		end
		if key == "*" or key == "DisplayIncome" then
			local income = StateController.Get("DisplayIncome") or 0
			incomeLabel.Text = if income > 0 then ("🏛️ +%s Coins/s"):format(Format.Number(income)) else ""
		end
	end)
end

return HUD
