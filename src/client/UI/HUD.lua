--[[
	HUD.lua
	=======
	Interface principale toujours visible :
	  - compteur de Coins (en haut, animé quand la valeur change)
	  - compteur de Rebirths
	  - bouton "Ma ferme" (téléportation, cooldown vérifié par le serveur)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local HUD = {}

local player = Players.LocalPlayer

local coinsLabel: TextLabel
local rebirthsLabel: TextLabel
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
	-- Petite animation de compteur qui défile
	TweenService:Create(coinsDisplayValue, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Value = value }):Play()

	local frame = coinsLabel.Parent :: Frame
	frame.Size = UDim2.fromOffset(200, 48)
	TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(190, 44) }):Play()
end

local function setRebirths(value: number)
	rebirthsLabel.Text = Format.Number(value)
end

function HUD.Init(StateController)
	local screen = Instance.new("ScreenGui")
	screen.Name = "FarmHUD"
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = player:WaitForChild("PlayerGui")

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

	-- Boutons à gauche
	local homeButton = Instance.new("TextButton")
	homeButton.Name = "HomeButton"
	homeButton.AnchorPoint = Vector2.new(0, 0.5)
	homeButton.Position = UDim2.new(0, 12, 0.5, 0)
	homeButton.Size = UDim2.fromOffset(130, 44)
	homeButton.BackgroundColor3 = Theme.Colors.Button
	homeButton.Font = Theme.Font
	homeButton.TextScaled = true
	homeButton.TextColor3 = Theme.Colors.Text
	homeButton.Text = "🏠 Ma ferme"
	homeButton.AutoButtonColor = true
	homeButton.Parent = screen
	Theme.Corner(homeButton, 12)
	Theme.Stroke(homeButton, 2)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = homeButton

	local teleportRemote: RemoteEvent = Remotes.Get("RequestTeleportHome")
	homeButton.Activated:Connect(function()
		-- Le client se contente de DEMANDER ; le serveur décide.
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
	end)
end

return HUD
