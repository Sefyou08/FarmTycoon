--[[
	IndexUI.lua
	===========
	Fenêtre "📚 Index" : toutes les créatures, zone par zone.
	Découverte = nom en couleur de rareté ; pas encore découverte = "???".
	Les Divines (✨) sont un bonus : pas nécessaires pour compléter une zone.
	Zone complète -> bouton "🎁 Réclamer" (validé par le serveur : ClaimIndexReward).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureUtil = require(ReplicatedStorage.Shared.CreatureUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local IndexUI = {}

local StateController
local notify: (string, string) -> ()
local claimRemote: RemoteFunction
local window: Frame
local list: ScrollingFrame
local summary: TextLabel
local busy = false

local function rebuild()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local index = StateController.Get("CreatureIndex") or {}
	local claimed = StateController.Get("IndexRewards") or {}
	local totalFound, total = 0, 0

	for zoneOrder, zoneId in CreatureUtil.SortedZones() do
		local zone = Config.Zones[zoneId]
		local creatures = CreatureUtil.CreaturesInZone(zoneId)
		local found, needed, complete = 0, 0, true
		local cards = {}
		for _, creatureId in creatures do
			local def = Config.Creatures[creatureId]
			local rarity = CreatureUtil.GetRarity(def.Rarity)
			local discovered = index[creatureId] == true
			if not rarity.Divine then
				needed += 1
				total += 1
				if discovered then
					found += 1
					totalFound += 1
				else
					complete = false
				end
			end
			local name = if discovered then def.DisplayName else "???"
			table.insert(cards, ('<font color="#%s">%s%s</font>'):format(rarity.Color:ToHex(), if rarity.Divine then "✨ " else "", name))
		end

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 104)
		row.LayoutOrder = zoneOrder
		row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
		row.Parent = list
		Theme.Corner(row, 10)
		if complete then
			Theme.Stroke(row, 2, Color3.fromRGB(255, 210, 60))
		end

		Theme.Label({
			Size = UDim2.new(0.62, -10, 0, 28),
			Position = UDim2.fromOffset(10, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = ("%s %s   %d/%d"):format(zone.Icon, zone.DisplayName, found, needed),
			Parent = row,
		})
		Theme.Label({
			Size = UDim2.new(0.62, -10, 0, 62),
			Position = UDim2.fromOffset(10, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			RichText = true,
			Text = table.concat(cards, "  •  "),
			Parent = row,
		})

		local reward = Config.Index.ZoneRewards[zoneId] or 0
		local buttonText, buttonColor
		if claimed[zoneId] then
			buttonText, buttonColor = "✅ Réclamée", Color3.fromRGB(90, 90, 100)
		elseif complete then
			buttonText, buttonColor = ("🎁 Réclamer 💰%s"):format(Format.Number(reward)), Color3.fromRGB(240, 180, 40)
		else
			buttonText, buttonColor = ("🎁 %s"):format(Format.Number(reward)), Color3.fromRGB(70, 75, 95)
		end
		local button = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.38, -20, 0, 48),
			BackgroundColor3 = buttonColor,
			Text = buttonText,
			Parent = row,
		})
		button.Activated:Connect(function()
			if busy or claimed[zoneId] then
				return
			end
			busy = true
			local ok, success, message = pcall(function()
				return claimRemote:InvokeServer(zoneId)
			end)
			busy = false
			if ok then
				notify(message or "", if success then "Success" else "Error")
			end
		end)
	end

	summary.Text = ("📚 %d / %d créatures découvertes (hors ✨ Divines, en bonus)"):format(totalFound, total)
end

function IndexUI.Init(screen: ScreenGui, HUD, stateController, notifyFn: (string, string) -> ())
	StateController = stateController
	notify = notifyFn
	claimRemote = Remotes.Get("ClaimIndexReward")

	local content
	window, content = Theme.Window(screen, "Index", "📚 Index des créatures", Vector2.new(640, 520))
	summary = Theme.Label({ Size = UDim2.new(1, 0, 0, 24), Text = "", Parent = content })

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 30)
	list.Size = UDim2.new(1, 0, 1, -30)
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

	HUD.AddButton("IndexButton", "📚 Index", Color3.fromRGB(60, 150, 160), 5, function()
		window.Visible = not window.Visible
		if window.Visible then
			rebuild()
		end
	end)

	StateController.Changed:Connect(function(key)
		if window.Visible and (key == "*" or key == "CreatureIndex" or key == "IndexRewards") then
			rebuild()
		end
	end)
end

return IndexUI
