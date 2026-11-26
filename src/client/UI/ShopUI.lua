--[[
	ShopUI.lua
	==========
	Fenêtre de la boutique de graines. S'ouvre quand le joueur utilise le
	ProximityPrompt du stand (attribut OpenUI = "SeedShop") et se ferme
	automatiquement s'il s'éloigne.
	Les achats sont envoyés au serveur (RemoteFunction BuySeed), qui valide tout.
	Stock tournant : section "🔄 Stock rare" (graines Rares / Épiques / Légendaires),
	quantité restante pour ce joueur et compte à rebours jusqu'au renouvellement
	(RemoteEvent ShopStock envoyé par le serveur).
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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
local shopList: ScrollingFrame
local notifyFn: (string, string) -> ()
local rotationEndsAt = 0
local countdownLabel: TextLabel? = nil

local function buildRow(list: ScrollingFrame, cropId: string, order: number, notify: (string, string) -> (), remaining: number?)
	local crop = CropUtil.Get(cropId)
	local rarity = CropUtil.RarityInfo(crop.Rarity)

	local row = Instance.new("Frame")
	row.Name = cropId
	row.Size = UDim2.new(1, -8, 0, 70)
	row.LayoutOrder = order
	row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
	if remaining then
		row:SetAttribute("Rare", true) -- reconstruite à chaque nouveau stock
	end
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
		Text = ("⏳ %s   💰 vente %s%s"):format(Format.Time(crop.GrowTime), Format.Number(crop.SellPrice), if remaining then ("   📦 %d restante(s)"):format(remaining) else ""),
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

-- Section du stock rare (reconstruite quand le serveur envoie un nouveau stock)
local function rebuildRare(stock: { [string]: number })
	for _, child in shopList:GetChildren() do
		if child:IsA("Frame") and child:GetAttribute("Rare") then
			child:Destroy()
		end
	end
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, -8, 0, 30)
	header.LayoutOrder = 1000
	header.BackgroundTransparency = 1
	header:SetAttribute("Rare", true)
	header.Parent = shopList
	countdownLabel = Theme.Label({ Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(255, 210, 90), Text = "🔄 Stock rare", Parent = header })

	local order, any = 1000, false
	for _, cropId in CropUtil.SortedIds() do
		local remaining = stock[cropId]
		if remaining and remaining > 0 then
			order += 1
			any = true
			buildRow(shopList, cropId, order, notifyFn, remaining)
		end
	end
	if not any then
		local empty = Instance.new("Frame")
		empty.Size = UDim2.new(1, -8, 0, 30)
		empty.LayoutOrder = 1001
		empty.BackgroundTransparency = 1
		empty:SetAttribute("Rare", true)
		empty.Parent = shopList
		Theme.Label({ Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(180, 180, 190), Text = "Aucune graine rare en ce moment... reviens au prochain stock !", Parent = empty })
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

	shopList = list
	notifyFn = notify
	for order, cropId in CropUtil.SortedIds() do
		-- Graines communes : toujours en vente ; les rares sont dans le stock tournant (plus bas)
		if CropUtil.Get(cropId).Rarity == "Common" then
			buildRow(list, cropId, order, notify)
		end
	end
	rebuildRare({})

	Remotes.Get("ShopStock").OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			rotationEndsAt = tonumber(data.EndsAt) or 0
			rebuildRare(if type(data.Stock) == "table" then data.Stock else {})
		end
	end)
	-- Compte à rebours du prochain stock
	task.spawn(function()
		while true do
			task.wait(0.5)
			if countdownLabel then
				local remaining = math.max(0, rotationEndsAt - Workspace:GetServerTimeNow())
				countdownLabel.Text = ("🔄 Stock rare : nouveau stock dans %s"):format(Format.Time(math.ceil(remaining)))
			end
		end
	end)

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
