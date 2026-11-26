--[[
	ShopUI.lua
	==========
	Fenêtre de la boutique de graines. S'ouvre quand le joueur utilise le
	ProximityPrompt du stand (attribut OpenUI = "SeedShop") et se ferme
	automatiquement s'il s'éloigne.
	Les achats sont envoyés au serveur (RemoteFunction BuySeed), qui valide tout.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CropUtil = require(ReplicatedStorage.Shared.CropUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local ShopUI = {}

local player = Players.LocalPlayer
local window: Frame
local buyRemote: RemoteFunction
local busy = false

local function buildRow(list: ScrollingFrame, cropId: string, order: number, notify: (string, string) -> ())
	local crop = CropUtil.Get(cropId)
	local rarity = CropUtil.RarityInfo(crop.Rarity)

	local row = Instance.new("Frame")
	row.Name = cropId
	row.Size = UDim2.new(1, -8, 0, 70)
	row.LayoutOrder = order
	row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
	row.Parent = list
	Theme.Corner(row, 10)
	Theme.Stroke(row, 2, rarity.Color)

	Theme.Label({
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.fromOffset(8, 10),
		Text = crop.Icon or "🌱",
		Parent = row,
	})
	Theme.Label({
		Size = UDim2.new(0.5, -60, 0, 28),
		Position = UDim2.fromOffset(64, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = ("%s  <font color=\"#%s\">(%s)</font>"):format(crop.DisplayName, rarity.Color:ToHex(), rarity.DisplayName),
		RichText = true,
		Parent = row,
	})
	Theme.Label({
		Size = UDim2.new(0.5, -60, 0, 22),
		Position = UDim2.fromOffset(64, 38),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Text = ("⏳ %s   💰 vente %s"):format(Format.Time(crop.GrowTime), Format.Number(crop.SellPrice)),
		Parent = row,
	})

	-- Boutons d'achat (x1, x5...) alignés à droite
	local buttons = Instance.new("Frame")
	buttons.AnchorPoint = Vector2.new(1, 0.5)
	buttons.Position = UDim2.new(1, -8, 0.5, 0)
	buttons.Size = UDim2.new(0.5, -10, 0, 50)
	buttons.BackgroundTransparency = 1
	buttons.Parent = row

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = buttons

	for i, amount in Config.Shop.BuyAmounts do
		local button = Theme.Button({
			Size = UDim2.fromOffset(96, 50),
			LayoutOrder = i,
			BackgroundColor3 = Color3.fromRGB(240, 180, 40),
			Text = ("x%d  💰%s"):format(amount, Format.Number(crop.SeedPrice * amount)),
			Parent = buttons,
		})
		button.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local ok, success, message = pcall(function()
				return buyRemote:InvokeServer(cropId, amount)
			end)
			busy = false
			if ok then
				notify(message or "", if success then "Success" else "Error")
			end
		end)
	end
end

function ShopUI.Open()
	window.Visible = true
end

function ShopUI.Close()
	window.Visible = false
end

function ShopUI.Init(screen: ScreenGui, notify: (string, string) -> ())
	buyRemote = Remotes.Get("BuySeed")

	local content
	window, content = Theme.Window(screen, "SeedShop", "🌱 Boutique de graines", Vector2.new(560, 420))

	local list = Instance.new("ScrollingFrame")
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

	for order, cropId in CropUtil.SortedIds() do
		-- Phase 3 : on affichera aussi le stock tournant des graines rares
		if CropUtil.Get(cropId).Rarity == "Common" then
			buildRow(list, cropId, order, notify)
		end
	end

	-- Ouverture via le prompt du stand
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("OpenUI") == "SeedShop" then
			ShopUI.Open()
		end
	end)

	-- Fermeture automatique si le joueur s'éloigne du stand
	task.spawn(function()
		local shopPosition = Config.Stands.SeedShopPosition
		while true do
			task.wait(0.5)
			if window.Visible then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not root or (root.Position - shopPosition).Magnitude > Config.Stands.MaxDistance + 4 then
					ShopUI.Close()
				end
			end
		end
	end)
end

return ShopUI
