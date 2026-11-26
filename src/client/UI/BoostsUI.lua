--[[
	BoostsUI.lua
	============
	Affiche les boosts actifs (consommables) en haut à droite, avec leur bonus et
	un compte à rebours, ainsi que les œufs en train d'éclore (🐣). Les boosts sont décidés par le serveur (data.Boosts) ;
	le client ne fait que les afficher.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(script.Parent.Theme)

local BoostsUI = {}

local StateController
local container: Frame

local function render()
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local boosts = StateController.Get("Boosts") or {}
	local now = Workspace:GetServerTimeNow()
	local order = 0
	-- Œufs en couveuse
	for _, entry in StateController.Get("Hatching") or {} do
		local egg = Config.Eggs[entry.Egg]
		if egg then
			order += 1
			local remaining = math.max(0, (entry.ReadyAt or 0) - now)
			local frame = Instance.new("Frame")
			frame.Size = UDim2.fromOffset(200, 32)
			frame.LayoutOrder = 100 + order
			frame.BackgroundColor3 = Theme.Colors.Panel
			frame.BackgroundTransparency = 0.15
			frame.Parent = container
			Theme.Corner(frame, 8)
			Theme.Stroke(frame, 2, Color3.fromRGB(150, 110, 220))
			Theme.Label({
				Size = UDim2.new(1, -12, 1, -8),
				Position = UDim2.fromOffset(6, 4),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = if remaining > 0 then ("🐣 %s  ⏳ %s"):format(egg.DisplayName, Format.Time(math.ceil(remaining))) else ("🐣 %s : éclosion !"):format(egg.DisplayName),
				Parent = frame,
			})
		end
	end
	for boostType, boost in boosts do
		local info = Config.Boosts.Types[boostType]
		local remaining = (boost.EndsAt or 0) - now
		if info and remaining > 0 then
			order += 1
			local frame = Instance.new("Frame")
			frame.Size = UDim2.fromOffset(200, 32)
			frame.LayoutOrder = order
			frame.BackgroundColor3 = Theme.Colors.Panel
			frame.BackgroundTransparency = 0.15
			frame.Parent = container
			Theme.Corner(frame, 8)
			Theme.Stroke(frame, 2, Color3.fromRGB(230, 120, 60))
			Theme.Label({
				Size = UDim2.new(1, -12, 1, -8),
				Position = UDim2.fromOffset(6, 4),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = ("%s %s +%d %%   ⏳ %s"):format(info.Icon, info.DisplayName, math.floor(boost.Power * 100 + 0.5), Format.Time(math.ceil(remaining))),
				Parent = frame,
			})
		end
	end
end

function BoostsUI.Init(screen: ScreenGui, stateController)
	StateController = stateController
	container = Instance.new("Frame")
	container.Name = "Boosts"
	container.AnchorPoint = Vector2.new(1, 0)
	container.Position = UDim2.new(1, -12, 0, 60)
	container.Size = UDim2.fromOffset(200, 200)
	container.BackgroundTransparency = 1
	container.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = container

	-- Rafraîchi chaque seconde (compte à rebours), et dès qu'un boost change
	StateController.Changed:Connect(function(key)
		if key == "*" or key == "Boosts" or key == "Hatching" then
			render()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			render()
		end
	end)
end

return BoostsUI
