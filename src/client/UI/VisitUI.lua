--[[
	VisitUI.lua
	===========
	Fenêtre "🏡 Visiter" : liste des joueurs du serveur qui ont une parcelle,
	avec un bouton pour s'y téléporter (RemoteEvent RequestVisit, cooldown côté
	serveur). Le visiteur voit les socles, la vitrine et les animaux, mais aucun
	prompt (ils sont réservés au propriétaire).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local VisitUI = {}

local player = Players.LocalPlayer
local window: Frame
local list: ScrollingFrame
local visitRemote: RemoteEvent

local function rebuild()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("PlotId") then
			count += 1
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -8, 0, 50)
			row.LayoutOrder = count
			row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
			row.Parent = list
			Theme.Corner(row, 8)
			Theme.Label({
				Size = UDim2.new(0.6, -10, 1, -12),
				Position = UDim2.fromOffset(10, 6),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = ("🏡 Ferme de %s"):format(other.DisplayName),
				Parent = row,
			})
			local button = Theme.Button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.new(0.4, -16, 0, 38),
				Text = "Visiter",
				Parent = row,
			})
			local userId = other.UserId
			button.Activated:Connect(function()
				visitRemote:FireServer(userId)
				window.Visible = false
			end)
		end
	end
	if count == 0 then
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 40)
		row.BackgroundTransparency = 1
		row.Parent = list
		Theme.Label({ Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(180, 180, 190), Text = "Aucun autre joueur sur ce serveur.", Parent = row })
	end
end

function VisitUI.Init(screen: ScreenGui, HUD)
	visitRemote = Remotes.Get("RequestVisit")

	local content
	window, content = Theme.Window(screen, "Visit", "🏡 Visiter une ferme", Vector2.new(420, 380))
	list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	HUD.AddButton("VisitButton", "🏡 Visiter", Color3.fromRGB(90, 160, 120), 6, function()
		window.Visible = not window.Visible
		if window.Visible then
			rebuild()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if window.Visible then
			rebuild()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if window.Visible then
			task.defer(rebuild)
		end
	end)
end

return VisitUI
