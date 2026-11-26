--[[
	PortalUI.lua
	============
	Fenêtre du portail d'expédition : liste des zones avec leurs créatures
	(découvertes ou "???"), bouton "Partir" ou "Débloquer (prix)".
	S'ouvre via le prompt du portail (attribut OpenUI = "Portal").
	Les demandes passent par la RemoteFunction ExpeditionAction (validée par le serveur).
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureUtil = require(ReplicatedStorage.Shared.CreatureUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local PortalUI = {}

local player = Players.LocalPlayer
local StateController
local notify: (string, string) -> ()
local actionRemote: RemoteFunction
local window: Frame
local list: ScrollingFrame
local busy = false

local function send(action: string, zoneId: string)
	if busy then
		return
	end
	busy = true
	local ok, success, message = pcall(function()
		return actionRemote:InvokeServer(action, zoneId)
	end)
	busy = false
	if ok then
		notify(message or "", if success then "Success" else "Error")
		if success and action == "Travel" then
			window.Visible = false
		end
	end
end

local function rebuild()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local unlocked = StateController.Get("UnlockedZones") or { Forest = true }
	local index = StateController.Get("CreatureIndex") or {}

	for order, zoneId in CreatureUtil.SortedZones() do
		local zone = Config.Zones[zoneId]
		local isUnlocked = unlocked[zoneId] or zone.UnlockPrice <= 0

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 92)
		row.LayoutOrder = order
		row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
		row.Parent = list
		Theme.Corner(row, 10)

		Theme.Label({
			Size = UDim2.new(0.65, -10, 0, 28),
			Position = UDim2.fromOffset(10, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = ("%s %s   (valeur x%d)"):format(zone.Icon, zone.DisplayName, zone.ValueMultiplier),
			Parent = row,
		})

		-- Créatures de la zone : nom si découverte, sinon "???" (couleur de rareté)
		local names = {}
		local found = 0
		local creatures = CreatureUtil.CreaturesInZone(zoneId)
		for _, creatureId in creatures do
			local def = Config.Creatures[creatureId]
			local color = CreatureUtil.GetRarity(def.Rarity).Color:ToHex()
			if index[creatureId] then
				found += 1
				table.insert(names, ('<font color="#%s">%s</font>'):format(color, def.DisplayName))
			else
				table.insert(names, ('<font color="#%s">???</font>'):format(color))
			end
		end
		Theme.Label({
			Size = UDim2.new(0.65, -10, 0, 48),
			Position = UDim2.fromOffset(10, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			RichText = true,
			Text = ("📖 %d/%d : %s"):format(found, #creatures, table.concat(names, ", ")),
			Parent = row,
		})

		local button = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.35, -20, 0, 50),
			BackgroundColor3 = if isUnlocked then Color3.fromRGB(150, 90, 255) else Color3.fromRGB(240, 180, 40),
			Text = if isUnlocked then "🧭 Partir" else ("🔓 Débloquer 💰%s"):format(Format.Number(zone.UnlockPrice)),
			Parent = row,
		})
		button.Activated:Connect(function()
			send(if isUnlocked then "Travel" else "Unlock", zoneId)
		end)
	end
end

function PortalUI.Init(screen: ScreenGui, stateController, notifyFn: (string, string) -> ())
	StateController = stateController
	notify = notifyFn
	actionRemote = Remotes.Get("ExpeditionAction")

	local content
	window, content = Theme.Window(screen, "Portal", "🧭 Expéditions", Vector2.new(620, 460))
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
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("OpenUI") == "Portal" then
			rebuild()
			window.Visible = true
		end
	end)
	StateController.Changed:Connect(function(key)
		if window.Visible and (key == "*" or key == "UnlockedZones" or key == "CreatureIndex") then
			rebuild()
		end
	end)

	-- Fermeture si on s'éloigne du portail
	task.spawn(function()
		local position = Config.Expeditions.PortalPosition
		while true do
			task.wait(0.5)
			if window.Visible then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not root or (root.Position - position).Magnitude > Config.Expeditions.PortalInteractDistance + 10 then
					window.Visible = false
				end
			end
		end
	end)
end

return PortalUI
