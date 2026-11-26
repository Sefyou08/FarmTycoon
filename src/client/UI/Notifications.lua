--[[
	Notifications.lua
	=================
	Petites bulles qui apparaissent à droite de l'écran ("+150 Coins",
	"Mutation Dorée !"...). Déclenchées par le serveur via le RemoteEvent
	"Notify", ou localement via Notifications.Show(texte, type).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local Notifications = {}

local MAX_VISIBLE = 5
local DURATION = 3

local player = Players.LocalPlayer
local container: Frame
local counter = 0

function Notifications.Show(text: string, kind: string?)
	if not container then
		return
	end

	-- Limite le nombre de bulles affichées en même temps
	local existing = {}
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			table.insert(existing, child)
		end
	end
	table.sort(existing, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #existing >= MAX_VISIBLE do
		table.remove(existing, 1):Destroy()
	end

	counter += 1

	local holder = Instance.new("Frame") -- conteneur fixe (le layout le place)
	holder.Name = "Notification"
	holder.Size = UDim2.fromOffset(280, 46)
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = counter
	holder.Parent = container

	local bubble = Instance.new("Frame") -- partie animée qui glisse depuis la droite
	bubble.Size = UDim2.fromScale(1, 1)
	bubble.Position = UDim2.fromScale(1.2, 0)
	bubble.BackgroundColor3 = Theme.NotifyColors[kind or "Info"] or Theme.NotifyColors.Info
	bubble.Parent = holder
	Theme.Corner(bubble, 10)
	local stroke = Theme.Stroke(bubble, 2)

	local label = Theme.Label({
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		Text = text,
		Parent = bubble,
	})

	TweenService:Create(bubble, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0, 0) }):Play()

	task.delay(DURATION, function()
		if not holder.Parent then
			return
		end
		local fade = TweenInfo.new(0.4)
		TweenService:Create(bubble, fade, { BackgroundTransparency = 1, Position = UDim2.fromScale(1.2, 0) }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		task.wait(0.4)
		holder:Destroy()
	end)
end

function Notifications.Init()
	local screen = Instance.new("ScreenGui")
	screen.Name = "Notifications"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 10 -- au-dessus du HUD
	screen.Parent = player:WaitForChild("PlayerGui")

	container = Instance.new("Frame")
	container.Name = "Container"
	container.AnchorPoint = Vector2.new(1, 1)
	container.Position = UDim2.new(1, -12, 1, -120)
	container.Size = UDim2.fromOffset(280, 300)
	container.BackgroundTransparency = 1
	container.Parent = screen

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 6)
	layout.Parent = container

	Remotes.Get("Notify").OnClientEvent:Connect(function(text: string, kind: string?)
		if type(text) == "string" then
			Notifications.Show(text, kind)
		end
	end)

	-- Message système dans le chat (ex. créature Secrète capturée)
	Remotes.Get("ChatAnnounce").OnClientEvent:Connect(function(text: string, colorHex: string?)
		if type(text) ~= "string" then
			return
		end
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general and general:IsA("TextChannel") then
			local safe = text:gsub("<", "&lt;"):gsub(">", "&gt;")
			general:DisplaySystemMessage(('<font color="#%s"><b>%s</b></font>'):format(colorHex or "FFD700", safe))
		end
	end)
end

return Notifications
