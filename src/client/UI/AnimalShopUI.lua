--[[
	AnimalShopUI.lua
	================
	Fenêtre du stand 🐄 ANIMAUX : liste des espèces (prix, ressource produite,
	cycle, nourriture) et chances d'obtenir une variante rare.
	S'ouvre via le prompt du stand (attribut OpenUI = "AnimalShop"), se ferme si
	le joueur s'éloigne. L'achat est validé par le serveur (RemoteFunction BuyAnimal).
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local AnimalShopUI = {}

local player = Players.LocalPlayer
local window: Frame
local buyRemote: RemoteFunction
local busy = false

local function sortedSpecies(): { string }
	local ids = {}
	for id, def in Config.Animals do
		if not def.NotForSale then -- les chevaux sauvages ne s'achètent pas
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Config.Animals[a].Order < Config.Animals[b].Order
	end)
	return ids
end

local function chancesText(): string
	local parts = {}
	for _, id in ItemUtil.SortedVariants() do
		local variant = Config.Variants[id]
		if id ~= "Normal" then
			table.insert(parts, ('<font color="#%s">%s %s%%</font>'):format(variant.Color:ToHex(), variant.DisplayName, tostring(variant.Chance * 100)))
		end
	end
	return "Chances : " .. table.concat(parts, "  •  ")
end

local function buildRow(list: ScrollingFrame, speciesId: string, order: number, notify: (string, string) -> ())
	local species = Config.Animals[speciesId]
	local resource = Config.Resources[species.Resource]

	local row = Instance.new("Frame")
	row.Name = speciesId
	row.Size = UDim2.new(1, -8, 0, 78)
	row.LayoutOrder = order
	row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
	row.Parent = list
	Theme.Corner(row, 10)

	Theme.Label({
		Size = UDim2.fromOffset(54, 54),
		Position = UDim2.fromOffset(8, 12),
		Text = species.Icon,
		Parent = row,
	})
	Theme.Label({
		Size = UDim2.new(0.62, -70, 0, 26),
		Position = UDim2.fromOffset(68, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = species.DisplayName,
		Parent = row,
	})
	Theme.Label({
		Size = UDim2.new(0.62, -70, 0, 20),
		Position = UDim2.fromOffset(68, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(210, 210, 220),
		Text = ("%s %s (💰%s) toutes les %s"):format(resource.Icon, resource.DisplayName, Format.Number(resource.SellPrice), Format.Time(species.ProductionTime)),
		Parent = row,
	})
	local diet = {}
	for _, cropId in species.Diet do
		table.insert(diet, ItemUtil.Label(cropId))
	end
	Theme.Label({
		Size = UDim2.new(0.62, -70, 0, 18),
		Position = UDim2.fromOffset(68, 54),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(170, 200, 170),
		Text = ("Mange : %s  (%d rations)"):format(table.concat(diet, ", "), species.FeedPerProduct),
		Parent = row,
	})

	local button = Theme.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.38, -16, 0, 50),
		BackgroundColor3 = Color3.fromRGB(240, 180, 40),
		Text = "Acheter  💰" .. Format.Number(species.Price),
		Parent = row,
	})
	button.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local ok, success, message, variant = pcall(function()
			return buyRemote:InvokeServer(speciesId)
		end)
		busy = false
		if ok then
			-- Pour une variante rare, le serveur envoie déjà une notification spéciale
			local kind = if not success then "Error" elseif variant and variant ~= "Normal" then "Rare" else "Success"
			notify(message or "", kind)
		end
	end)
end

function AnimalShopUI.Open()
	window.Visible = true
end

function AnimalShopUI.Close()
	window.Visible = false
end

function AnimalShopUI.Init(screen: ScreenGui, notify: (string, string) -> ())
	buyRemote = Remotes.Get("BuyAnimal")

	local content
	window, content = Theme.Window(screen, "AnimalShop", "🐄 Éleveur : animaux de ferme", Vector2.new(600, 460))

	Theme.Label({
		Size = UDim2.new(1, 0, 0, 22),
		RichText = true,
		Text = chancesText(),
		Parent = content,
	})

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 28)
	list.Size = UDim2.new(1, 0, 1, -28)
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

	for order, speciesId in sortedSpecies() do
		buildRow(list, speciesId, order, notify)
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("OpenUI") == "AnimalShop" then
			AnimalShopUI.Open()
		end
	end)

	-- Fermeture automatique si le joueur s'éloigne du stand
	task.spawn(function()
		local position = Config.Stands.AnimalShopPosition
		while true do
			task.wait(0.5)
			if window.Visible then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not root or (root.Position - position).Magnitude > Config.Stands.MaxDistance + 4 then
					AnimalShopUI.Close()
				end
			end
		end
	end)
end

return AnimalShopUI
