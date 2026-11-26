--[[
	SellUI.lua
	==========
	Fenêtre "💰 Vendre" (ouverte par le stand de vente) : on CHOISIT ce qu'on vend.
	  • Onglets : Tout, Récoltes, Produits des animaux, Produits fabriqués, Œufs.
	  • Chaque objet (et chaque variante : Doré, Arc-en-ciel...) : quantité possédée, prix
	    unitaire, et un sélecteur de quantité (−, +, Tout).
	  • En bas : « Vendre la sélection » (total affiché) et « Tout vendre ».
	Le serveur vérifie la distance au stand et les quantités (RemoteFunction "SellItems").
	Les prix affichés sont les prix de base : les bonus (rebirth, boost Coins, x2 Coins)
	s'ajoutent au moment de la vente.
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local SellUI = {}

local TABS = {
	{ Id = "All", Text = "Tout" },
	{ Id = "Crops", Text = "🌱 Récoltes" },
	{ Id = "Resources", Text = "🥚 Animaux" },
	{ Id = "Products", Text = "🥖 Fabriqués" },
	{ Id = "Eggs", Text = "🐣 Œufs" },
}

local StateController
local notify: (string, string) -> ()
local remote: RemoteFunction
local window: Frame
local list: ScrollingFrame
local totalLabel: TextLabel
local tabButtons: { [string]: TextButton } = {}
local currentTab = "All"
local selection: { [string]: number } = {} -- ["itemId|variante"] = quantité choisie
local busy = false

local function categoryOf(itemId: string): string
	if Config.Crops[itemId] then
		return "Crops"
	elseif Config.Resources[itemId] then
		return "Resources"
	elseif Config.Eggs[itemId] then
		return "Eggs"
	end
	return "Products"
end

-- Liste des objets possédés : { { Item, Variant, Owned, Unit, Key } }, triée par valeur
local function entries(): { { [string]: any } }
	local result = {}
	for itemId, variants in StateController.Get("Inventory") or {} do
		if ItemUtil.Get(itemId) then
			for variant, count in variants do
				if count > 0 then
					table.insert(result, { Item = itemId, Variant = variant, Owned = count, Unit = ItemUtil.UnitValue(itemId, variant), Key = itemId .. "|" .. variant })
				end
			end
		end
	end
	table.sort(result, function(a, b)
		return a.Unit * a.Owned > b.Unit * b.Owned
	end)
	return result
end

local function refreshTotal()
	local total, count = 0, 0
	local owned = {}
	for _, entry in entries() do
		owned[entry.Key] = entry
	end
	for key, amount in selection do
		local entry = owned[key]
		if not entry or amount <= 0 then
			selection[key] = nil
		else
			selection[key] = math.min(amount, entry.Owned)
			total += entry.Unit * selection[key]
			count += selection[key]
		end
	end
	totalLabel.Text = if count > 0 then ("Sélection : %d objet(s)  •  💰 %s Coins (+ bonus)"):format(count, Format.Number(total)) else "Choisis ce que tu veux vendre"
end

local rebuild

local function sell(request: any)
	if busy then
		return
	end
	busy = true
	local ok, success, message = pcall(function()
		return remote:InvokeServer(request)
	end)
	busy = false
	if ok then
		notify(message or "?", if success then "Success" else "Error")
		if success then
			selection = {}
		end
	else
		notify("Erreur réseau.", "Error")
	end
	rebuild()
end

rebuild = function()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for id, button in tabButtons do
		button.BackgroundColor3 = if id == currentTab then Color3.fromRGB(230, 140, 40) else Color3.fromRGB(70, 76, 100)
	end
	local shown = 0
	for order, entry in entries() do
		if currentTab ~= "All" and categoryOf(entry.Item) ~= currentTab then
			continue
		end
		shown += 1
		local variant = ItemUtil.GetVariant(entry.Variant)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 46)
		row.LayoutOrder = order
		row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
		row.Parent = list
		Theme.Corner(row, 10)
		Theme.Label({
			Size = UDim2.new(0.45, -10, 1, -10),
			Position = UDim2.fromOffset(10, 5),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if entry.Variant == "Normal" then Theme.Colors.Text else variant.Color,
			Text = ("%s  x%d"):format(ItemUtil.Label(entry.Item, entry.Variant), entry.Owned),
			Parent = row,
		})
		Theme.Label({
			Size = UDim2.new(0.18, 0, 1, -10),
			Position = UDim2.new(0.45, 0, 0, 5),
			TextColor3 = Theme.Colors.Coins,
			Text = ("💰 %s / u"):format(Format.Number(entry.Unit)),
			Parent = row,
		})
		local chosen = selection[entry.Key] or 0
		local function set(amount: number)
			selection[entry.Key] = math.clamp(amount, 0, entry.Owned)
			rebuild()
		end
		local controls = {
			{ "−", function() set(chosen - 1) end, 36 },
			{ tostring(chosen), nil, 46 },
			{ "+", function() set(chosen + 1) end, 36 },
			{ "Tout", function() set(if chosen == entry.Owned then 0 else entry.Owned) end, 60 },
		}
		local x = -6
		for i = #controls, 1, -1 do
			local c = controls[i]
			x -= c[3] + 4
			if c[2] then
				local b = Theme.Button({ Size = UDim2.fromOffset(c[3], 36), Position = UDim2.new(1, x, 0, 5), BackgroundColor3 = if c[1] == "Tout" and chosen == entry.Owned then Color3.fromRGB(60, 170, 80) else Color3.fromRGB(80, 90, 120), Text = c[1], Parent = row })
				b.Activated:Connect(c[2])
			else
				Theme.Label({ Size = UDim2.fromOffset(c[3], 36), Position = UDim2.new(1, x, 0, 5), TextColor3 = if chosen > 0 then Theme.Colors.Coins else Theme.Colors.Text, Text = c[1], Parent = row })
			end
		end
	end
	if shown == 0 then
		Theme.Label({ Size = UDim2.new(1, -8, 0, 30), LayoutOrder = 0, TextColor3 = Color3.fromRGB(190, 195, 210), Text = "Rien à vendre ici.", Parent = list })
	end
	refreshTotal()
end

function SellUI.Open()
	rebuild()
	window.Visible = true
end

function SellUI.Init(screen: ScreenGui, stateController, notifyFn)
	StateController = stateController
	notify = notifyFn
	remote = Remotes.Get("SellItems")
	local content
	window, content = Theme.Window(screen, "SellWindow", "💰 Vendre", Vector2.new(760, 560))

	local tabs = Instance.new("Frame")
	tabs.Size = UDim2.new(1, 0, 0, 34)
	tabs.BackgroundTransparency = 1
	tabs.Parent = content
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.2, -4, 0, 32)
	grid.CellPadding = UDim2.fromOffset(4, 0)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = tabs
	for order, tab in TABS do
		local b = Theme.Button({ LayoutOrder = order, Text = tab.Text, Parent = tabs })
		b.Activated:Connect(function()
			currentTab = tab.Id
			rebuild()
		end)
		tabButtons[tab.Id] = b
	end

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 40)
	list.Size = UDim2.new(1, 0, 1, -130)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	totalLabel = Theme.Label({ Position = UDim2.new(0, 0, 1, -84), Size = UDim2.new(1, 0, 0, 28), TextColor3 = Theme.Colors.Coins, Text = "", Parent = content })
	local actions = {
		{ "☑️ Tout sélectionner (onglet)", Color3.fromRGB(80, 90, 120), function()
			for _, entry in entries() do
				if currentTab == "All" or categoryOf(entry.Item) == currentTab then
					selection[entry.Key] = entry.Owned
				end
			end
			rebuild()
		end },
		{ "✖ Vider la sélection", Color3.fromRGB(110, 110, 125), function()
			selection = {}
			rebuild()
		end },
		{ "💰 Vendre la sélection", Color3.fromRGB(60, 170, 80), function()
			local request = {}
			for key, amount in selection do
				local itemId, variant = string.match(key, "^(.-)|(.+)$")
				if itemId and amount > 0 then
					table.insert(request, { Item = itemId, Variant = variant, Amount = amount })
				end
			end
			if #request == 0 then
				notify("Choisis d'abord des objets (+ ou Tout).", "Info")
				return
			end
			sell(request)
		end },
		{ "Tout vendre", Color3.fromRGB(200, 120, 40), function()
			sell("All")
		end },
	}
	for i, action in actions do
		local b = Theme.Button({ Position = UDim2.new((i - 1) * 0.25, 2, 1, -50), Size = UDim2.new(0.25, -4, 0, 44), BackgroundColor3 = action[2], Text = action[1], Parent = content })
		b.Activated:Connect(action[3])
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("OpenUI") == "Sell" then
			SellUI.Open()
		end
	end)
	StateController.Changed:Connect(function(key)
		if window.Visible and (key == "*" or key == "Inventory") then
			rebuild()
		end
	end)
end

return SellUI
