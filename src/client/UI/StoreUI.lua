--[[
	StoreUI.lua
	===========
	Fenêtre "💎 Boutique" : Game Passes et Developer Products (Config.Monetization).
	Le client ne fait qu'OUVRIR la fenêtre d'achat Roblox ; c'est le serveur
	(MonetizationService) qui donne la récompense une fois l'achat confirmé par Roblox.
	Un Id à 0 = pas encore créé sur Roblox -> bouton "Bientôt disponible".
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(script.Parent.Theme)

local StoreUI = {}

local player = Players.LocalPlayer
local Monetization = Config.Monetization

local StateController
local notify: (string, string) -> ()
local window: Frame
local list: ScrollingFrame

-- Ordre d'affichage des produits
local PRODUCT_ORDER = {
	"CoinsSmall", "CoinsMedium", "CoinsLarge",
	"PlotExpansion", "HatchNow", "WheelSpin", "WheelSpins5",
	"GrowthBoost", "ProductionBoost", "CoinsBoost", "XPBoost", "SpeedBoost", "CaptureBoost", "CombatBoost",
}
local PASS_ORDER = { "DoubleCoins", "PremiumHelpers", "BigBackpack", "ExtraIncubators", "BigCollection" }

local function header(text: string, order: number)
	local label = Theme.Label({
		Size = UDim2.new(1, -8, 0, 30),
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.Coins,
		Text = text,
		Parent = list,
	})
	return label
end

local function card(order: number, icon: string, name: string, description: string, price: number, id: number, owned: boolean, onBuy: () -> ())
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 64)
	row.LayoutOrder = order
	row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
	row.Parent = list
	Theme.Corner(row, 10)
	Theme.Label({ Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(8, 8), Text = icon, Parent = row })
	Theme.Label({
		Size = UDim2.new(1, -230, 0, 26),
		Position = UDim2.fromOffset(62, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = name,
		Parent = row,
	})
	Theme.Label({
		Size = UDim2.new(1, -230, 0, 22),
		Position = UDim2.fromOffset(62, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 205, 220),
		TextWrapped = true,
		Text = description,
		Parent = row,
	})
	local text, color, active
	if owned then
		text, color, active = "✅ Possédé", Color3.fromRGB(90, 90, 100), false
	elseif id <= 0 then
		text, color, active = "Bientôt disponible", Color3.fromRGB(90, 90, 100), false
	else
		text, color, active = ("💎 %d R$"):format(price), Color3.fromRGB(60, 170, 80), true
	end
	local button = Theme.Button({
		Size = UDim2.fromOffset(150, 44),
		Position = UDim2.new(1, -160, 0, 10),
		BackgroundColor3 = color,
		AutoButtonColor = active,
		Text = text,
		Parent = row,
	})
	button.Activated:Connect(function()
		if active then
			onBuy()
		elseif not owned then
			notify("Cet achat n'est pas encore disponible.", "Info")
		end
	end)
end

local function rebuild()
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local level = StateController.Get("Level") or 1
	header("⭐ Game Passes (pour toujours)", 1)
	for i, key in PASS_ORDER do
		local pass = Monetization.GamePasses[key]
		card(10 + i, pass.Icon, pass.Name, pass.Description, pass.Price, pass.Id, player:GetAttribute("Pass_" .. key) == true, function()
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end)
	end
	header("🛒 Achats (plusieurs fois)", 100)
	for i, key in PRODUCT_ORDER do
		local product = Monetization.Products[key]
		local description = product.Description
		if product.Kind == "Coins" then
			description = ("+%s Coins (selon ton niveau %d)"):format(Format.Number(product.Amount + (product.PerLevel or 0) * level), level)
		end
		card(100 + i, product.Icon, product.Name, description, product.Price, product.Id, false, function()
			MarketplaceService:PromptProductPurchase(player, product.Id)
		end)
	end
end

function StoreUI.Open()
	rebuild()
	window.Visible = true
end

function StoreUI.Init(screen: ScreenGui, HUD, stateController, notifyFn)
	StateController = stateController
	notify = notifyFn
	local content
	window, content = Theme.Window(screen, "StoreWindow", "💎 Boutique", Vector2.new(640, 560))

	Theme.Label({
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = Color3.fromRGB(200, 205, 220),
		Text = "Tout le jeu se joue gratuitement : ces achats vont juste plus vite. Prix en Robux.",
		Parent = content,
	})
	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 26)
	list.Size = UDim2.new(1, 0, 1, -26)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	HUD.AddButton("StoreButton", "💎 Boutique", Color3.fromRGB(40, 150, 220), 11, function()
		if window.Visible then
			window.Visible = false
		else
			StoreUI.Open()
		end
	end)

	-- Un pass acheté s'active via un attribut posé par le serveur : on rafraîchit
	player.AttributeChanged:Connect(function(name)
		if window.Visible and string.sub(name, 1, 5) == "Pass_" then
			rebuild()
		end
	end)
end

return StoreUI
