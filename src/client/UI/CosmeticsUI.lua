--[[
	CosmeticsUI.lua
	===============
	Fenêtre "🎨 Personnaliser" : cosmétiques UNIQUEMENT visuels (Config.Cosmetics).
	  • Onglets par catégorie (Config.CosmeticCategories).
	  • Chaque carte : aperçu (couleur / matière), état (équipé, possédé, à débloquer),
	    bouton Équiper / Acheter (Coins) / Robux (Developer Product) / condition de déblocage.
	  • 👁 Aperçu : montre l'objet en grand pendant quelques secondes (traces de pas et
	    titre : essayés en vrai sur ton personnage, seulement chez toi).
	Le serveur valide tout (CosmeticAction) ; les achats Robux passent par MonetizationService.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CosmeticUtil = require(ReplicatedStorage.Shared.CosmeticUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local CosmeticsUI = {}

local player = Players.LocalPlayer
local PREVIEW_TIME = 7

local StateController
local notify: (string, string) -> ()
local actionRemote: RemoteFunction
local window: Frame
local tabs: Frame
local list: ScrollingFrame
local preview: Frame
local previewSwatch: Frame
local previewLabel: TextLabel
local currentCategory = Config.CosmeticCategories[1].Id
local busy = false
local previewToken = 0

-- Données utiles à CosmeticUtil.IsOwned, reconstruites depuis l'état reçu du serveur
local function stateData(): { [string]: any }
	return {
		Level = StateController.Get("Level") or 1,
		IndexRewards = StateController.Get("IndexRewards") or {},
		Cosmetics = StateController.Get("Cosmetics") or { Owned = {}, Equipped = {} },
	}
end

-- Couleur principale d'un cosmétique (pour l'aperçu)
local function mainColor(def: any): Color3
	return def.Color or def.Wall or def.ParticleColor or def.Color1 or def.Saddle or def.Harness or Color3.fromRGB(120, 120, 130)
end

local function describe(def: any): string
	local parts = {}
	if def.Material then
		table.insert(parts, def.Material.Name)
	end
	if def.Roof then
		table.insert(parts, "toit coloré")
	end
	if def.Rainbow then
		table.insert(parts, "arc-en-ciel")
	end
	if def.Glow or def.Neon then
		table.insert(parts, "lumineux")
	end
	if def.Sparkles then
		table.insert(parts, "étincelles")
	end
	if def.Shape then
		table.insert(parts, def.Shape)
	end
	if def.Text then
		table.insert(parts, def.Text)
	end
	return table.concat(parts, " • ")
end

-- Essai local des traces de pas / du titre (rien n'est envoyé au serveur)
local function tryOnCharacter(def: any, token: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not root or not head then
		return
	end
	local created = {}
	if def.Category == "Trail" and def.Color1 then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, -1.2, 0.3)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -2.6, 0.3)
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Lifetime = 0.6
		trail.LightEmission = if def.Glow then 0.8 else 0
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Color = ColorSequence.new(def.Color1, def.Color2 or def.Color1)
		trail.Parent = root
		created = { a0, a1, trail }
	elseif def.Category == "Title" and def.Text then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(8, 1)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 3.8, 0)
		gui.LightInfluence = 0
		gui.Parent = head
		Theme.Label({ Size = UDim2.fromScale(1, 1), TextColor3 = def.Color, TextStrokeTransparency = 0.3, Text = def.Text .. " (aperçu)", Parent = gui })
		created = { gui }
	end
	task.delay(PREVIEW_TIME, function()
		for _, instance in created do
			instance:Destroy()
		end
		if token == previewToken then
			preview.Visible = false
		end
	end)
end

local function showPreview(def: any)
	previewToken += 1
	local token = previewToken
	previewSwatch.BackgroundColor3 = mainColor(def)
	local roofSwatch = previewSwatch:FindFirstChild("Roof") :: Frame
	roofSwatch.Visible = def.Roof ~= nil
	if def.Roof then
		roofSwatch.BackgroundColor3 = def.Roof
	end
	previewLabel.Text = ("👁 %s\n%s"):format(def.Name, describe(def))
	preview.Visible = true
	if def.Category == "Trail" or def.Category == "Title" then
		previewLabel.Text ..= "\n(essaie-le en marchant !)"
		tryOnCharacter(def, token)
	else
		task.delay(PREVIEW_TIME, function()
			if token == previewToken then
				preview.Visible = false
			end
		end)
	end
end

local rebuild

local function act(action: string, id: string)
	if busy then
		return
	end
	busy = true
	local ok, success, message = pcall(function()
		return actionRemote:InvokeServer(action, id)
	end)
	busy = false
	if ok then
		notify(message or "?", if success then "Success" else "Error")
	else
		notify("Erreur réseau.", "Error")
	end
end

rebuild = function()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, child in tabs:GetChildren() do
		if child:IsA("TextButton") then
			child.BackgroundColor3 = if child.Name == currentCategory then Color3.fromRGB(230, 140, 40) else Color3.fromRGB(70, 76, 100)
		end
	end

	local data = stateData()
	local equippedId = CosmeticUtil.EquippedId(data, currentCategory)
	for order, id in CosmeticUtil.ByCategory(currentCategory) do
		local def = Config.Cosmetics[id]
		local owned = CosmeticUtil.IsOwned(data, id)
		local equipped = id == equippedId

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 58)
		row.LayoutOrder = order
		row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
		row.Parent = list
		Theme.Corner(row, 10)
		if equipped then
			Theme.Stroke(row, 2, Color3.fromRGB(90, 220, 120))
		end

		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.fromOffset(42, 42)
		swatch.Position = UDim2.fromOffset(8, 8)
		swatch.BackgroundColor3 = mainColor(def)
		swatch.Parent = row
		Theme.Corner(swatch, 8)

		Theme.Label({
			Size = UDim2.new(1, -330, 0, 24),
			Position = UDim2.fromOffset(58, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = def.Name .. (if equipped then "  ✅" else ""),
			Parent = row,
		})
		Theme.Label({
			Size = UDim2.new(1, -330, 0, 20),
			Position = UDim2.fromOffset(58, 32),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(200, 205, 220),
			Text = if owned then "Possédé" else "🔒 " .. CosmeticUtil.UnlockText(def),
			Parent = row,
		})

		local previewButton = Theme.Button({
			Size = UDim2.fromOffset(44, 40),
			Position = UDim2.new(1, -262, 0, 9),
			BackgroundColor3 = Color3.fromRGB(70, 120, 200),
			Text = "👁",
			Parent = row,
		})
		previewButton.Activated:Connect(function()
			showPreview(def)
		end)

		local text, color, onClick
		local unlock = def.Unlock
		if equipped then
			text, color = "Équipé", Color3.fromRGB(90, 90, 100)
		elseif owned then
			text, color = "Équiper", Color3.fromRGB(60, 170, 80)
			onClick = function()
				act("Equip", id)
			end
		elseif unlock.Kind == "Coins" then
			text, color = ("💰 %s"):format(Format.Number(unlock.Price)), Color3.fromRGB(220, 170, 40)
			onClick = function()
				act("Buy", id)
			end
		elseif unlock.Kind == "Robux" then
			if unlock.ProductId and unlock.ProductId > 0 then
				text, color = ("💎 %d R$"):format(unlock.Price), Color3.fromRGB(40, 150, 220)
				onClick = function()
					MarketplaceService:PromptProductPurchase(player, unlock.ProductId)
				end
			else
				text, color = "Bientôt", Color3.fromRGB(90, 90, 100)
			end
		else
			text, color = "🔒 À débloquer", Color3.fromRGB(90, 90, 100)
		end
		local button = Theme.Button({
			Size = UDim2.fromOffset(200, 40),
			Position = UDim2.new(1, -210, 0, 9),
			BackgroundColor3 = color,
			AutoButtonColor = onClick ~= nil,
			Text = text,
			Parent = row,
		})
		button.Activated:Connect(function()
			if onClick then
				onClick()
			elseif not owned then
				notify("Pour le débloquer : " .. CosmeticUtil.UnlockText(def), "Info")
			end
		end)
	end
end

function CosmeticsUI.Init(screen: ScreenGui, HUD, stateController, notifyFn)
	StateController = stateController
	notify = notifyFn
	actionRemote = Remotes.Get("CosmeticAction")
	local content
	window, content = Theme.Window(screen, "CosmeticsWindow", "🎨 Personnaliser (visuel uniquement)", Vector2.new(760, 560))

	-- Onglets (2 lignes de 5)
	tabs = Instance.new("Frame")
	tabs.Size = UDim2.new(1, 0, 0, 72)
	tabs.BackgroundTransparency = 1
	tabs.Parent = content
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.2, -4, 0, 32)
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = tabs
	for order, category in Config.CosmeticCategories do
		local tab = Theme.Button({
			Name = category.Id,
			LayoutOrder = order,
			Text = category.Icon .. " " .. category.DisplayName,
			Parent = tabs,
		})
		tab.Activated:Connect(function()
			currentCategory = category.Id
			rebuild()
		end)
	end

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 78)
	list.Size = UDim2.new(1, 0, 1, -78)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- Panneau d'aperçu (par-dessus la liste, à droite)
	preview = Instance.new("Frame")
	preview.AnchorPoint = Vector2.new(1, 1)
	preview.Position = UDim2.new(1, -4, 1, -4)
	preview.Size = UDim2.fromOffset(220, 200)
	preview.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
	preview.ZIndex = 10
	preview.Visible = false
	preview.Parent = content
	Theme.Corner(preview, 12)
	Theme.Stroke(preview, 2, Color3.fromRGB(70, 120, 200))
	previewSwatch = Instance.new("Frame")
	previewSwatch.Position = UDim2.fromOffset(50, 12)
	previewSwatch.Size = UDim2.fromOffset(120, 100)
	previewSwatch.ZIndex = 11
	previewSwatch.Parent = preview
	Theme.Corner(previewSwatch, 10)
	local roof = Instance.new("Frame")
	roof.Name = "Roof"
	roof.Size = UDim2.new(1, 0, 0.35, 0)
	roof.ZIndex = 12
	roof.Visible = false
	roof.Parent = previewSwatch
	Theme.Corner(roof, 10)
	previewLabel = Theme.Label({
		Position = UDim2.fromOffset(8, 118),
		Size = UDim2.new(1, -16, 0, 76),
		TextWrapped = true,
		ZIndex = 11,
		Text = "",
		Parent = preview,
	})

	HUD.AddButton("CosmeticsButton", "🎨 Personnaliser", Color3.fromRGB(220, 90, 150), 13, function()
		if window.Visible then
			window.Visible = false
		else
			rebuild()
			window.Visible = true
		end
	end)

	StateController.Changed:Connect(function(key)
		if window.Visible and (key == "*" or key == "Cosmetics" or key == "Level" or key == "IndexRewards") then
			rebuild()
		end
	end)
end

return CosmeticsUI
