--[[
	CollectionUI.lua
	================
	Fenêtre "📖 Créatures" : créatures capturées (nom, rareté, mutation, valeur,
	revenu si exposée) avec, pour chacune :
	  ⭐       épingler / désépingler dans la vitrine de prestige
	  🏛️      exposer sur un socle libre / retirer du socle
	  Vendre  (double clic pour confirmer ; impossible si la créature est exposée)
	  🐾      (chevaux sauvages) mettre en enclos : il y produit son crin, et reste une monture
	S'ouvre aussi via le prompt d'un socle (attribut OpenUI = "Collection").
	Tout est validé par le serveur (DisplayAction, SellCreature).
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
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
local displayRemote: RemoteFunction
local window: Frame
local list: ScrollingFrame
local summary: TextLabel
local busy = false

local function invoke(remote: RemoteFunction, ...: any)
	if busy then
		return
	end
	busy = true
	local args = table.pack(...)
	local ok, success, message = pcall(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
	busy = false
	if ok then
		notify(message or "", if success then "Success" else "Error")
	end
end

local function rebuild()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local creatures = StateController.Get("Creatures") or {}
	local pedestals = StateController.Get("Pedestals") or {}
	local picks = StateController.Get("ShowcasePicks") or {}

	local displayed = {}
	local freePedestals = 0
	for _, pedestal in pedestals do
		if pedestal.Creature then
			displayed[pedestal.Creature] = true
		elseif pedestal.Placed then
			freePedestals += 1
		end
	end

	-- Tri : les plus prestigieuses en premier
	local sorted = table.clone(creatures)
	table.sort(sorted, function(a, b)
		return CreatureUtil.GetPrestige(a.Creature, a.Mutation) > CreatureUtil.GetPrestige(b.Creature, b.Mutation)
	end)

	for order, entry in sorted do
		local def = CreatureUtil.Get(entry.Creature)
		if not def then
			continue
		end
		local rarity = CreatureUtil.GetRarity(def.Rarity)
		local zone = Config.Zones[def.Zone]
		local value = CreatureUtil.GetValue(entry.Creature, entry.Mutation)
		local income = CreatureUtil.GetIncome(entry.Creature, entry.Mutation)
		local isDisplayed = displayed[entry.Id] == true
		local isPinned = table.find(picks, entry.Id) ~= nil

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 56)
		row.LayoutOrder = order
		row.BackgroundColor3 = if isDisplayed then Color3.fromRGB(55, 70, 60) else Color3.fromRGB(50, 56, 75)
		row.Parent = list
		Theme.Corner(row, 8)
		Theme.Stroke(row, 2, rarity.Color)

		Theme.Label({
			Size = UDim2.new(0.5, -10, 0, 26),
			Position = UDim2.fromOffset(10, 3),
			TextXAlignment = Enum.TextXAlignment.Left,
			RichText = true,
			Text = ('%s%s <font color="#%s">[%s]</font>'):format(if isDisplayed then "🏛️ " else "", CreatureUtil.Label(entry.Creature, entry.Mutation), rarity.Color:ToHex(), rarity.DisplayName),
			Parent = row,
		})
		Theme.Label({
			Size = UDim2.new(0.5, -10, 0, 18),
			Position = UDim2.fromOffset(10, 32),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(200, 200, 210),
			Text = ("%s %s  •  💰%s  •  %s/s exposée"):format(zone and zone.Icon or "", zone and zone.DisplayName or "", Format.Number(value), Format.Number(income)),
			Parent = row,
		})

		-- Boutons à droite : ⭐  🏛️  Vendre
		local buttons = Instance.new("Frame")
		buttons.AnchorPoint = Vector2.new(1, 0.5)
		buttons.Position = UDim2.new(1, -6, 0.5, 0)
		buttons.Size = UDim2.new(0.5, -10, 0, 40)
		buttons.BackgroundTransparency = 1
		buttons.Parent = row
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = buttons

		local pin = Theme.Button({
			Size = UDim2.fromOffset(40, 40),
			LayoutOrder = 1,
			BackgroundColor3 = if isPinned then Color3.fromRGB(255, 200, 50) else Color3.fromRGB(90, 90, 110),
			Text = "⭐",
			Parent = buttons,
		})
		pin.Activated:Connect(function()
			invoke(displayRemote, "Pin", entry.Id)
		end)

		local display = Theme.Button({
			Size = UDim2.fromOffset(92, 40),
			LayoutOrder = 2,
			BackgroundColor3 = if isDisplayed then Color3.fromRGB(150, 110, 70) else Color3.fromRGB(150, 90, 255),
			Text = if isDisplayed then "Retirer" else "🏛️ Exposer",
			Parent = buttons,
		})
		display.Activated:Connect(function()
			invoke(displayRemote, if isDisplayed then "Remove" else "Assign", entry.Id)
		end)

		if def.Horse then
			local toPen = Theme.Button({
				Size = UDim2.fromOffset(40, 40),
				LayoutOrder = 0,
				BackgroundColor3 = Color3.fromRGB(150, 100, 60),
				Text = "🐾",
				Parent = buttons,
			})
			toPen.Activated:Connect(function()
				invoke(displayRemote, "ToPen", entry.Id)
			end)
		end

		local sell = Theme.Button({
			Size = UDim2.fromOffset(86, 40),
			LayoutOrder = 3,
			BackgroundColor3 = if isDisplayed then Color3.fromRGB(90, 90, 100) else Color3.fromRGB(240, 180, 40),
			Text = "Vendre",
			AutoButtonColor = not isDisplayed,
			Parent = buttons,
		})
		local armed = false
		sell.Activated:Connect(function()
			if isDisplayed then
				notify("Retire d'abord cette créature de son socle.", "Error")
				return
			end
			if not armed then
				-- 1er clic : confirmation (évite de vendre une Secrète par erreur)
				armed = true
				sell.Text = "Sûr ?"
				sell.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
				task.delay(3, function()
					if sell.Parent then
						armed = false
						sell.Text = "Vendre"
						sell.BackgroundColor3 = Color3.fromRGB(240, 180, 40)
					end
				end)
				return
			end
			invoke(sellRemote, entry.Id)
		end)
	end

	local income = StateController.Get("DisplayIncome") or 0
	summary.Text = ("%d / %d créatures  •  🏛️ %d socle(s) libre(s)  •  +%s Coins/s  •  ⭐ %d/%d en vitrine"):format(
		#creatures,
		Config.Expeditions.MaxCreatures,
		freePedestals,
		Format.Number(income),
		#picks,
		Config.Showcase.Slots
	)
end

local function open()
	window.Visible = true
	rebuild()
end

function CollectionUI.Init(screen: ScreenGui, HUD, stateController, notifyFn: (string, string) -> ())
	StateController = stateController
	notify = notifyFn
	sellRemote = Remotes.Get("SellCreature")
	displayRemote = Remotes.Get("DisplayAction")

	local content
	window, content = Theme.Window(screen, "Collection", "📖 Mes créatures", Vector2.new(680, 460))
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
		if window.Visible then
			window.Visible = false
		else
			open()
		end
	end)

	-- Prompt d'un socle : ouvre la collection pour choisir quoi exposer
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("OpenUI") == "Collection" then
			open()
		end
	end)

	StateController.Changed:Connect(function(key)
		if window.Visible and (key == "*" or key == "Creatures" or key == "CreatureIndex" or key == "Pedestals" or key == "ShowcasePicks" or key == "DisplayIncome") then
			rebuild()
		end
	end)
end

return CollectionUI
