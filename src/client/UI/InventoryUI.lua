--[[
	InventoryUI.lua
	===============
	Fenêtre "🎒 Inventaire" : récoltes et ressources animales (avec leur variante),
	quantité, valeur estimée, et remplissage (ex. 12 / 300). La vente se fait au
	stand 💰 VENTE.
	La valeur affichée n'est qu'une estimation : le serveur calcule le vrai prix.
	Les objets consommables (Config.Consumables) ont un bouton 🍴 Manger (boost temporaire),
	les œufs de créatures (Config.Eggs) un bouton 🐣 Couver.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local InventoryUI = {}

local window: Frame
local list: ScrollingFrame
local summary: TextLabel
local hudButton: TextButton?
local notify: (string, string) -> ()
local busy = false

local function invokeItem(remoteName: string, itemId: string, variant: string)
	if busy then
		return
	end
	busy = true
	local ok, success, message = pcall(function()
		return Remotes.Get(remoteName):InvokeServer(itemId, variant)
	end)
	busy = false
	if ok then
		notify(message or "", if success then "Success" else "Error")
	end
end

local function eat(itemId: string, variant: string)
	invokeItem("Consume", itemId, variant)
end

local function rebuild(inventory: { [string]: { [string]: number } }?)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local totalCount, totalValue = 0, 0
	local variantOrder = ItemUtil.SortedVariants()
	for itemOrder, itemId in ItemUtil.SortedIds() do
		local variants = inventory and inventory[itemId]
		if variants then
			for variantIndex, variant in variantOrder do
				local count = variants[variant] or 0
				if count > 0 then
					totalCount += count
					local value = ItemUtil.UnitValue(itemId, variant) * count
					totalValue += value

					local row = Instance.new("Frame")
					row.Size = UDim2.new(1, -8, 0, 44)
					row.LayoutOrder = itemOrder * 10 + variantIndex
					row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
					row.Parent = list
					Theme.Corner(row, 8)
					if variant ~= "Normal" then
						Theme.Stroke(row, 2, ItemUtil.GetVariant(variant).Color)
					end

					Theme.Label({
						Size = UDim2.new(0.6, -10, 1, -10),
						Position = UDim2.fromOffset(10, 5),
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = ("%s  x%d"):format(ItemUtil.Label(itemId, variant), count),
						Parent = row,
					})
					local consumable = Config.Consumables[itemId]
					if consumable then
						local boostInfo = Config.Boosts.Types[consumable.Boost]
						local eatButton = Theme.Button({
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(0.62, 0, 0.5, 0),
							Size = UDim2.fromOffset(74, 32),
							BackgroundColor3 = Color3.fromRGB(230, 120, 60),
							Text = "🍴 " .. boostInfo.Icon,
							Parent = row,
						})
						eatButton.Activated:Connect(function()
							eat(itemId, variant)
						end)
					end
					-- Œufs de créatures : mise en couveuse
					if Config.Eggs[itemId] then
						local hatchButton = Theme.Button({
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(0.62, 0, 0.5, 0),
							Size = UDim2.fromOffset(80, 32),
							BackgroundColor3 = Color3.fromRGB(150, 110, 220),
							Text = "🐣 Couver",
							Parent = row,
						})
						hatchButton.Activated:Connect(function()
							invokeItem("Hatch", itemId, variant)
						end)
					end
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

function InventoryUI.Init(screen: ScreenGui, HUD, StateController, notifyFn: (string, string) -> ())
	notify = notifyFn
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
