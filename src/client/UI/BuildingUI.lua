--[[
	BuildingUI.lua
	==============
	Fenêtre d'un bâtiment de transformation, ouverte via le prompt de sa porte
	(attributs OpenUI = "Building" et BuildingId). Elle affiche :
	  - le niveau, la vitesse et le bouton d'amélioration ;
	  - les recettes (ingrédients possédés / nécessaires) avec "Lancer x1 / x5" ;
	  - la file de production avec des barres de progression ;
	  - les produits finis et le bouton "Récupérer".
	Toutes les actions sont envoyées au serveur (RemoteFunction BuildingAction),
	qui valide tout. La progression est estimée localement, sans trafic réseau.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local BuildingUI = {}

local LEVELS = Config.BuildingLevels
local Settings = Config.BuildingSettings

local player = Players.LocalPlayer
local StateController
local notify: (string, string) -> ()
local actionRemote: RemoteFunction

local window: Frame
local titleLabel: TextLabel
local levelLabel: TextLabel
local upgradeButton: TextButton
local recipeList: ScrollingFrame
local queueList: ScrollingFrame
local outputLabel: TextLabel
local collectButton: TextButton

local currentId: string? = nil
local currentDoor: Vector3? = nil
local busy = false

-- Barres de progression à animer : { fill, remainingLabel, jobIndex }
local progressBars: { { Fill: Frame, Label: TextLabel, Index: number } } = {}

local function getBuilding()
	local buildings = StateController.Get("Buildings")
	return currentId and buildings and buildings[currentId]
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function send(action: string, a: any?, b: any?)
	if busy or not currentId then
		return
	end
	busy = true
	local ok, success, message = pcall(function()
		return actionRemote:InvokeServer(action, currentId, a, b)
	end)
	busy = false
	if ok and message then
		notify(message, if success then "Success" else "Error")
	end
end

local function makeList(parent: Instance, position: UDim2, size: UDim2): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Position = position
	list.Size = size
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	return list
end

--------------------------------------------------------------------------
-- Construction du contenu
--------------------------------------------------------------------------

local function buildRecipeRow(def: any, recipe: any, building: any, inventory: any, order: number)
	local output = ItemUtil.Get(recipe.Output.Item)
	local locked = (recipe.RequiredBuildingLevel or 1) > building.Level

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 84)
	row.LayoutOrder = order
	row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
	row.Parent = recipeList
	Theme.Corner(row, 10)

	Theme.Label({
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.fromOffset(8, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = ("%s x%d   💰%s   ⏳ %s"):format(
			ItemUtil.Label(recipe.Output.Item),
			recipe.Output.Amount,
			Format.Number(output.SellPrice),
			Format.Time(recipe.Time / LEVELS[building.Level].Speed)
		),
		Parent = row,
	})

	-- Ingrédients : vert si on en a assez, rouge sinon
	local parts = {}
	for _, input in recipe.Inputs do
		local have = 0
		for _, count in (inventory and inventory[input.Item]) or {} do
			have += count
		end
		local color = if have >= input.Amount then "#7CFF7C" else "#FF7C7C"
		table.insert(parts, ('<font color="%s">%d %s (%d)</font>'):format(color, input.Amount, ItemUtil.Label(input.Item), have))
	end
	Theme.Label({
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		Text = table.concat(parts, "  +  "),
		Parent = row,
	})

	if locked then
		Theme.Label({
			Size = UDim2.new(1, -16, 0, 24),
			Position = UDim2.fromOffset(8, 54),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 200, 100),
			Text = ("🔒 Débloqué au niveau %d du bâtiment"):format(recipe.RequiredBuildingLevel),
			Parent = row,
		})
		return
	end

	for i, amount in Settings.QueueAmounts do
		local button = Theme.Button({
			Size = UDim2.fromOffset(90, 28),
			Position = UDim2.fromOffset(8 + (i - 1) * 98, 52),
			BackgroundColor3 = Color3.fromRGB(240, 180, 40),
			Text = "Lancer x" .. amount,
			Parent = row,
		})
		button.Activated:Connect(function()
			send("Queue", recipe.Id, amount)
		end)
	end
end

local function buildQueue(def: any, building: any)
	clear(queueList)
	table.clear(progressBars)
	local info = LEVELS[building.Level]

	if #building.Queue == 0 then
		local empty = Instance.new("Frame")
		empty.Size = UDim2.new(1, -8, 0, 30)
		empty.BackgroundTransparency = 1
		empty.Parent = queueList
		Theme.Label({ Size = UDim2.fromScale(1, 1), Text = "File vide : lance une recette !", TextColor3 = Color3.fromRGB(180, 180, 190), Parent = empty })
		return
	end

	for index, job in building.Queue do
		local recipe
		for _, r in def.Recipes do
			if r.Id == job.Recipe then
				recipe = r
			end
		end
		if not recipe then
			continue
		end

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 34)
		row.LayoutOrder = index
		row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
		row.Parent = queueList
		Theme.Corner(row, 8)

		-- Barre de progression (seulement pour les commandes en cours)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Color3.fromRGB(90, 190, 100)
		fill.BackgroundTransparency = 0.4
		fill.BorderSizePixel = 0
		fill.Parent = row
		Theme.Corner(fill, 8)

		local label = Theme.Label({
			Size = UDim2.new(1, -12, 1, -8),
			Position = UDim2.fromOffset(6, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
			Text = ItemUtil.Label(recipe.Output.Item, job.Variant),
			Parent = row,
		})
		if index <= info.Slots then
			table.insert(progressBars, { Fill = fill, Label = label, Index = index })
		else
			label.Text ..= "   (en attente)"
		end
	end
end

-- Estimation locale de la progression des commandes en cours
local function updateProgress()
	local building = getBuilding()
	if not building then
		return
	end
	local def = Config.Buildings[currentId :: string]
	local info = LEVELS[building.Level]
	local elapsed = math.max(0, Workspace:GetServerTimeNow() - (building.LastUpdate or 0)) * info.Speed

	for _, bar in progressBars do
		local job = building.Queue[bar.Index]
		if job then
			local recipeTime, outputItem = 1, job.Recipe
			for _, r in def.Recipes do
				if r.Id == job.Recipe then
					recipeTime, outputItem = r.Time, r.Output.Item
				end
			end
			local remaining = math.max(0, job.Remaining - elapsed)
			bar.Fill.Size = UDim2.fromScale(math.clamp(1 - remaining / recipeTime, 0, 1), 1)
			local name = ItemUtil.Label(outputItem, job.Variant)
			bar.Label.Text = if remaining > 0
				then ("%s   ⏳ %s"):format(name, Format.Time(math.ceil(remaining / info.Speed)))
				else name .. "   ✅ (stockage plein ?)"
		end
	end
end

local function refresh()
	if not window.Visible or not currentId then
		return
	end
	local building = getBuilding()
	if not building then
		window.Visible = false
		return
	end
	local def = Config.Buildings[currentId]
	local info = LEVELS[building.Level]
	local inventory = StateController.Get("Inventory")

	titleLabel.Text = ("%s %s"):format(def.Icon, def.DisplayName)
	levelLabel.Text = ("Niveau %d/%d  •  vitesse x%s  •  %d en même temps  •  file %d/%d"):format(
		building.Level,
		#LEVELS,
		tostring(info.Speed),
		info.Slots,
		#building.Queue,
		info.QueueSize
	)
	if building.Level < #LEVELS then
		upgradeButton.Visible = true
		upgradeButton.Text = ("⬆️ Améliorer  💰%s"):format(Format.Number(math.floor(def.Price * LEVELS[building.Level + 1].CostMultiplier)))
	else
		upgradeButton.Visible = false
	end

	clear(recipeList)
	for order, recipe in def.Recipes do
		buildRecipeRow(def, recipe, building, inventory, order)
	end

	buildQueue(def, building)

	local parts, total = {}, 0
	for itemId, variants in building.Output do
		for variant, count in variants do
			total += count
			table.insert(parts, ("%d %s"):format(count, ItemUtil.Label(itemId, variant)))
		end
	end
	outputLabel.Text = if total > 0
		then ("📦 Prêt (%d/%d) : %s"):format(total, Settings.OutputCapacity, table.concat(parts, ", "))
		else "📦 Aucun produit fini pour l'instant"
	collectButton.Visible = total > 0
	updateProgress()
end

--------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------

function BuildingUI.Open(buildingId: string, doorPosition: Vector3)
	if not Config.Buildings[buildingId] then
		return
	end
	currentId = buildingId
	currentDoor = doorPosition
	window.Visible = true
	refresh()
end

function BuildingUI.Init(screen: ScreenGui, stateController, notifyFn: (string, string) -> ())
	StateController = stateController
	notify = notifyFn
	actionRemote = Remotes.Get("BuildingAction")

	local content
	window, content = Theme.Window(screen, "Building", "", Vector2.new(720, 500))
	titleLabel = window:FindFirstChild("Title") :: TextLabel

	levelLabel = Theme.Label({
		Size = UDim2.new(1, -190, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(210, 210, 220),
		Text = "",
		Parent = content,
	})
	upgradeButton = Theme.Button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, -2),
		Size = UDim2.fromOffset(180, 30),
		BackgroundColor3 = Color3.fromRGB(120, 90, 220),
		Text = "⬆️ Améliorer",
		Parent = content,
	})
	upgradeButton.Activated:Connect(function()
		send("Upgrade")
	end)

	-- Colonne gauche : recettes
	Theme.Label({
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(0.58, -6, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "📜 Recettes",
		Parent = content,
	})
	recipeList = makeList(content, UDim2.fromOffset(0, 58), UDim2.new(0.58, -6, 1, -58))

	-- Colonne droite : file + produits finis
	Theme.Label({
		Position = UDim2.new(0.58, 6, 0, 32),
		Size = UDim2.new(0.42, -6, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "🔨 Production",
		Parent = content,
	})
	queueList = makeList(content, UDim2.new(0.58, 6, 0, 58), UDim2.new(0.42, -6, 1, -170))

	outputLabel = Theme.Label({
		Position = UDim2.new(0.58, 6, 1, -106),
		Size = UDim2.new(0.42, -6, 0, 58),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = "",
		Parent = content,
	})
	collectButton = Theme.Button({
		Position = UDim2.new(0.58, 6, 1, -44),
		Size = UDim2.new(0.42, -6, 0, 40),
		Text = "📦 Récupérer",
		Parent = content,
	})
	collectButton.Activated:Connect(function()
		send("Collect")
	end)

	-- Ouverture via la porte du bâtiment
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("OpenUI") == "Building" then
			local buildingId = prompt:GetAttribute("BuildingId")
			local door = prompt.Parent
			if type(buildingId) == "string" and door and door:IsA("BasePart") then
				BuildingUI.Open(buildingId, door.Position)
			end
		end
	end)

	StateController.Changed:Connect(function(key)
		if key == "*" or key == "Buildings" or key == "Inventory" then
			refresh()
		end
	end)

	-- Barres de progression + fermeture si on s'éloigne
	task.spawn(function()
		while true do
			task.wait(0.2)
			if window.Visible then
				updateProgress()
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not root or not currentDoor or (root.Position - currentDoor).Magnitude > Settings.InteractDistance + 10 then
					window.Visible = false
				end
			end
		end
	end)
end

return BuildingUI
