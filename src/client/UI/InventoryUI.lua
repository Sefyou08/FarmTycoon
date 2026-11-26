--[[
	InventoryUI.lua
	===============
	Fenêtre "🎒 Inventaire" : produits récoltés, quantité, valeur estimée,
	et remplissage (ex. 12 / 200). La vente se fait au stand 💰 VENTE.
	La valeur affichée n'est qu'une estimation : le serveur calcule le vrai prix.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CropUtil = require(ReplicatedStorage.Shared.CropUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(script.Parent.Theme)

local InventoryUI = {}

local window: Frame
local list: ScrollingFrame
local summary: TextLabel
local hudButton: TextButton?

local VARIANT_NAMES = { Normal = "" } -- phase 3 : "Dorée", "Arc-en-ciel"...

local function rebuild(inventory: { [string]: { [string]: number } }?)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local totalCount, totalValue = 0, 0
	for order, cropId in CropUtil.SortedIds() do
		local variants = inventory and inventory[cropId]
		if variants then
			local crop = CropUtil.Get(cropId)
			for variant, count in variants do
				if count > 0 then
					totalCount += count
					local value = crop.SellPrice * count
					totalValue += value

					local row = Instance.new("Frame")
					row.Size = UDim2.new(1, -8, 0, 44)
					row.LayoutOrder = order
					row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
					row.Parent = list
					Theme.Corner(row, 8)

					local variantName = VARIANT_NAMES[variant] or variant
					Theme.Label({
						Size = UDim2.new(0.6, -10, 1, -10),
						Position = UDim2.fromOffset(10, 5),
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = ("%s %s  x%d"):format(CropUtil.Label(cropId), variantName, count),
						Parent = row,
					})
					Theme.Label({
						AnchorPoint = Vector2.new(1, 0),
						Size = UDim2.new(0.4, -10, 1, -10),
						Position = UDim2.new(1, -10, 0, 5),
						TextXAlignment = Enum.TextXAlignment.Right,
						TextColor3 = Theme.Colors.Coins,
						Text = "💰 " .. Format.Number(value),
						Parent = row,
					})
				end
			end
		end
	end

	summary.Text = ("%d / %d produits  •  valeur ≈ 💰 %s  •  Vends au stand 💰 VENTE"):format(
		totalCount,
		Config.Farm.InventoryCapacity,
		Format.Number(totalValue)
	)
	summary.TextColor3 = if totalCount >= Config.Farm.InventoryCapacity then Color3.fromRGB(255, 100, 100) else Theme.Colors.Text

	if hudButton then
		hudButton.Text = ("🎒 Sac %d/%d"):format(totalCount, Config.Farm.InventoryCapacity)
	end
end

function InventoryUI.Toggle()
	window.Visible = not window.Visible
end

function InventoryUI.Init(screen: ScreenGui, HUD, StateController)
	local content
	window, content = Theme.Window(screen, "Inventory", "🎒 Inventaire", Vector2.new(480, 400))

	summary = Theme.Label({
		Size = UDim2.new(1, 0, 0, 26),
		Text = "",
		Parent = content,
	})

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 34)
	list.Size = UDim2.new(1, 0, 1, -34)
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

	hudButton = HUD.AddButton("InventoryButton", "🎒 Sac", Color3.fromRGB(70, 120, 200), 2, InventoryUI.Toggle)

	StateController.Changed:Connect(function(key)
		if key == "*" or key == "Inventory" then
			rebuild(StateController.Get("Inventory"))
		end
	end)
	rebuild(StateController.Get("Inventory"))
end

return InventoryUI
