--[[
	CollectionUI.lua
	================
	Fenêtre "📖 Créatures" : créatures capturées (nom, rareté, mutation, valeur),
	nombre de découvertes, et vente (double clic pour confirmer).
	La valeur affichée est une estimation : le serveur calcule le vrai prix.
	(Phase 6 : bouton "Exposer" sur un socle.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureUtil = require(ReplicatedStorage.Shared.CreatureUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local CollectionUI = {}

local StateController
local notify: (string, string) -> ()
local sellRemote: RemoteFunction
local window: Frame
local list: ScrollingFrame
local summary: TextLabel
local busy = false

local function countIndex(): (number, number)
	local index = StateController.Get("CreatureIndex") or {}
	local found, total = 0, 0
	for id in Config.Creatures do
		total += 1
		if index[id] then
			found += 1
		end
	end
	return found, total
end

local function rebuild()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local creatures = StateController.Get("Creatures") or {}

	-- Tri : les plus précieuses en premier
	local sorted = table.clone(creatures)
	table.sort(sorted, function(a, b)
		return CreatureUtil.GetValue(a.Creature, a.Mutation) > CreatureUtil.GetValue(b.Creature, b.Mutation)
	end)

	for order, entry in sorted do
		local def = CreatureUtil.Get(entry.Creature)
		if not def then
			continue
		end
		local rarity = CreatureUtil.GetRarity(def.Rarity)
		local zone = Config.Zones[def.Zone]
		local value = CreatureUtil.GetValue(entry.Creature, entry.Mutation)

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 52)
		row.LayoutOrder = order
		row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
		row.Parent = list
		Theme.Corner(row, 8)
		Theme.Stroke(row, 2, rarity.Color)

		Theme.Label({
			Size = UDim2.new(0.62, -10, 0, 26),
			Position = UDim2.fromOffset(10, 3),
			TextXAlignment = Enum.TextXAlignment.Left,
			RichText = true,
			Text = ('%s <font color="#%s">[%s]</font>'):format(CreatureUtil.Label(entry.Creature, entry.Mutation), rarity.Color:ToHex(), rarity.DisplayName),
			Parent = row,
		})
		Theme.Label({
			Size = UDim2.new(0.62, -10, 0, 18),
			Position = UDim2.fromOffset(10, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(200, 200, 210),
			Text = ("%s %s   •   💰 %s"):format(zone and zone.Icon or "", zone and zone.DisplayName or "", Format.Number(value)),
			Parent = row,
		})

		local sell = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0.38, -16, 0, 38),
			BackgroundColor3 = Color3.fromRGB(240, 180, 40),
			Text = "Vendre 💰" .. Format.Number(value),
			Parent = row,
		})
		local armed = false
		sell.Activated:Connect(function()
			if not armed then
				-- 1er clic : demande de confirmation (évite de vendre une Secrète par erreur)
				armed = true
				sell.Text = "Confirmer ?"
				sell.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
				task.delay(3, function()
					if sell.Parent then
						armed = false
						sell.Text = "Vendre 💰" .. Format.Number(value)
						sell.BackgroundColor3 = Color3.fromRGB(240, 180, 40)
					end
				end)
				return
			end
			if busy then
				return
			end
			busy = true
			local ok, success, message = pcall(function()
				return sellRemote:InvokeServer(entry.Id)
			end)
			busy = false
			if ok then
				notify(message or "", if success then "Success" else "Error")
			end
		end)
	end

	local found, total = countIndex()
	summary.Text = ("%d / %d créatures   •   📖 Découvertes : %d / %d"):format(#creatures, Config.Expeditions.MaxCreatures, found, total)
end

function CollectionUI.Init(screen: ScreenGui, HUD, stateController, notifyFn: (string, string) -> ())
	StateController = stateController
	notify = notifyFn
	sellRemote = Remotes.Get("SellCreature")

	local content
	window, content = Theme.Window(screen, "Collection", "📖 Mes créatures", Vector2.new(560, 440))
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
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	HUD.AddButton("CollectionButton", "📖 Créatures", Color3.fromRGB(150, 90, 255), 3, function()
		window.Visible = not window.Visible
		if window.Visible then
			rebuild()
		end
	end)

	StateController.Changed:Connect(function(key)
		if window.Visible and (key == "*" or key == "Creatures" or key == "CreatureIndex") then
			rebuild()
		end
	end)
end

return CollectionUI
