--[[
	WheelUI.lua
	===========
	Fenêtre "🎡 Roue" : 1 tour gratuit toutes les 24 h (+ tours achetés).
	  • S'ouvre toute seule à la connexion si le tour gratuit est prêt.
	  • Affiche le compte à rebours du prochain tour gratuit et les CHANCES de chaque case
	    (Weight / total : les mêmes valeurs que le serveur).
	  • Animation de suspense : une bande de cases défile sous un repère et ralentit
	    jusqu'à la case choisie PAR LE SERVEUR (le client ne tire rien au sort).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local WheelUI = {}

local player = Players.LocalPlayer
local WheelConfig = Config.Wheel
local Products = Config.Monetization.Products

local TILE = 96 -- largeur d'une case (px)
local LOOPS = 6 -- nombre de fois que la liste est répétée sur la bande

local StateController
local notify: (string, string) -> ()
local spinRemote: RemoteFunction
local window: Frame
local strip: Frame
local spinButton: TextButton
local statusLabel: TextLabel
local resultLabel: TextLabel
local spinning = false
local autoOpened = false

local function totalWeight(): number
	local total = 0
	for _, reward in WheelConfig.Rewards do
		total += reward.Weight
	end
	return total
end

local function chanceText(weight: number): string
	local percent = weight / totalWeight() * 100
	if percent >= 1 then
		return ("%.1f %%"):format(percent)
	end
	return ("%.2f %%"):format(percent)
end

local function freeReady(): (boolean, number)
	local wheel = StateController.Get("Wheel") or {}
	local nextFree = (wheel.LastFree or 0) + WheelConfig.Cooldown
	local now = Workspace:GetServerTimeNow()
	return now >= nextFree, math.max(0, nextFree - now)
end

local function refreshStatus()
	if not window then
		return
	end
	local wheel = StateController.Get("Wheel") or {}
	local ready, remaining = freeReady()
	local extra = wheel.ExtraSpins or 0
	if ready then
		statusLabel.Text = "🎁 Tour GRATUIT disponible !" .. (if extra > 0 then ("  (+%d tours achetés)"):format(extra) else "")
	else
		statusLabel.Text = ("Prochain tour gratuit dans %s"):format(Format.Time(math.ceil(remaining)))
			.. (if extra > 0 then ("   •   🎡 %d tour(s) en réserve"):format(extra) else "")
	end
	local canSpin = ready or extra > 0
	spinButton.Text = if spinning then "..." elseif ready then "🎡 TOURNER (gratuit)" elseif extra > 0 then "🎡 TOURNER (1 tour)" else "⏳ Reviens plus tard"
	spinButton.BackgroundColor3 = if canSpin and not spinning then Color3.fromRGB(230, 120, 40) else Color3.fromRGB(90, 90, 100)
end

local function buildStrip()
	local count = #WheelConfig.Rewards
	strip.Size = UDim2.fromOffset(TILE * count * LOOPS, TILE)
	for loop = 0, LOOPS - 1 do
		for index, reward in WheelConfig.Rewards do
			local tile = Instance.new("Frame")
			tile.Size = UDim2.fromOffset(TILE - 6, TILE - 6)
			tile.Position = UDim2.fromOffset((loop * count + index - 1) * TILE + 3, 3)
			tile.BackgroundColor3 = reward.Color
			tile.Parent = strip
			Theme.Corner(tile, 10)
			Theme.Stroke(tile, 2, if reward.Jackpot then Color3.fromRGB(255, 255, 255) else nil)
			Theme.Label({ Size = UDim2.new(1, 0, 0.6, 0), Text = reward.Icon, Parent = tile })
			Theme.Label({
				Size = UDim2.new(1, -6, 0.3, 0),
				Position = UDim2.new(0, 3, 0.65, 0),
				TextStrokeTransparency = 0.3,
				Text = chanceText(reward.Weight),
				Parent = tile,
			})
		end
	end
end

-- Description courte d'une récompense (liste des chances)
local function describe(reward: { [string]: any }): string
	local level = StateController.Get("Level") or 1
	if reward.Kind == "Coins" then
		return ("%s Coins"):format(Format.Number(reward.Amount + (reward.PerLevel or 0) * level))
	elseif reward.Kind == "XP" then
		return ("%s XP"):format(Format.Number(reward.Amount + (reward.PerLevel or 0) * level))
	elseif reward.Kind == "Seeds" then
		local crop = Config.Crops[reward.Item]
		return ("%d graine(s) %s"):format(reward.Amount, if crop then crop.DisplayName else reward.Item)
	elseif reward.Kind == "Boost" then
		local info = Config.Boosts.Types[reward.Boost]
		return ("Boost %s +%d %% (%s)"):format(info.DisplayName, math.floor(reward.Power * 100), Format.Time(reward.Duration))
	elseif reward.Kind == "Rations" then
		return ("+%d rations dans chaque enclos"):format(reward.Amount)
	elseif reward.Kind == "Item" then
		local egg = Config.Eggs and Config.Eggs[reward.Item]
		return if egg then egg.DisplayName else reward.Item
	elseif reward.Kind == "Creature" then
		local zone = Config.Zones[reward.Zone]
		return ("Créature rare (%s)"):format(if zone then zone.DisplayName else reward.Zone)
	elseif reward.Kind == "Animal" then
		local species = Config.Animals[reward.Species]
		return ("✨ %s : animal EXCLUSIF !"):format(species.DisplayName)
	end
	return reward.Id
end

local function spin()
	if spinning then
		return
	end
	spinning = true
	resultLabel.Text = ""
	refreshStatus()
	local ok, result = pcall(function()
		return spinRemote:InvokeServer()
	end)
	if not ok or type(result) ~= "table" or not result.Ok then
		spinning = false
		refreshStatus()
		notify(if ok and type(result) == "table" then result.Message or "Impossible." else "Erreur réseau.", "Error")
		return
	end

	-- La bande défile et s'arrête sur la case gagnée (choisie par le serveur), dans l'avant-dernière boucle
	local count = #WheelConfig.Rewards
	local viewport = strip.Parent :: Frame
	local center = viewport.AbsoluteSize.X / 2
	local target = ((LOOPS - 2) * count + result.Index - 1) * TILE + TILE / 2
	local jitter = (math.random() - 0.5) * (TILE * 0.6) -- s'arrête un peu à gauche ou à droite du centre
	strip.Position = UDim2.fromOffset(center - TILE / 2, 0)
	local tween = TweenService:Create(strip, TweenInfo.new(WheelConfig.SpinDuration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(center - target + jitter, 0),
	})
	tween:Play()
	tween.Completed:Wait()

	spinning = false
	resultLabel.Text = "🎉 " .. tostring(result.Text)
	resultLabel.TextColor3 = if result.Jackpot then Color3.fromRGB(255, 120, 220) else Theme.Colors.Coins
	notify("🎡 Roue : " .. tostring(result.Text), if result.Jackpot then "Rare" else "Success")
	refreshStatus()
end

function WheelUI.Open()
	window.Visible = true
	refreshStatus()
end

function WheelUI.Init(screen: ScreenGui, HUD, stateController, notifyFn)
	StateController = stateController
	notify = notifyFn
	spinRemote = Remotes.Get("SpinWheel")
	local content
	window, content = Theme.Window(screen, "WheelWindow", "🎡 Roue quotidienne", Vector2.new(640, 560))

	statusLabel = Theme.Label({ Size = UDim2.new(1, 0, 0, 24), Text = "", Parent = content })

	-- Bande de cases sous un repère
	local viewport = Instance.new("Frame")
	viewport.Position = UDim2.fromOffset(0, 30)
	viewport.Size = UDim2.new(1, 0, 0, TILE)
	viewport.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
	viewport.ClipsDescendants = true
	viewport.Parent = content
	Theme.Corner(viewport, 10)
	strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Parent = viewport
	local marker = Instance.new("Frame")
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.Position = UDim2.fromScale(0.5, 0)
	marker.Size = UDim2.new(0, 4, 1, 0)
	marker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	marker.ZIndex = 5
	marker.Parent = viewport
	buildStrip()

	spinButton = Theme.Button({
		Position = UDim2.new(0.5, -130, 0, 34 + TILE),
		Size = UDim2.fromOffset(260, 44),
		Text = "🎡 TOURNER",
		Parent = content,
	})
	spinButton.Activated:Connect(spin)
	resultLabel = Theme.Label({ Position = UDim2.fromOffset(0, 82 + TILE), Size = UDim2.new(1, 0, 0, 26), Text = "", Parent = content })

	-- Achat de tours en plus
	for i, key in { "WheelSpin", "WheelSpins5" } do
		local product = Products[key]
		local available = product.Id > 0
		local buy = Theme.Button({
			Position = UDim2.new(if i == 1 then 0 else 0.5, if i == 1 then 0 else 4, 0, 112 + TILE),
			Size = UDim2.new(0.5, -4, 0, 34),
			BackgroundColor3 = if available then Color3.fromRGB(40, 150, 220) else Color3.fromRGB(90, 90, 100),
			Text = if available then ("%s : %d R$"):format(product.Name, product.Price) else product.Name .. " (bientôt)",
			Parent = content,
		})
		buy.Activated:Connect(function()
			if available then
				MarketplaceService:PromptProductPurchase(player, product.Id)
			else
				notify("Cet achat n'est pas encore disponible.", "Info")
			end
		end)
	end

	-- Chances affichées (toujours visibles)
	local chances = Instance.new("ScrollingFrame")
	chances.Position = UDim2.fromOffset(0, 152 + TILE)
	chances.Size = UDim2.new(1, 0, 1, -(152 + TILE))
	chances.BackgroundTransparency = 1
	chances.ScrollBarThickness = 6
	chances.AutomaticCanvasSize = Enum.AutomaticSize.Y
	chances.CanvasSize = UDim2.new()
	chances.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = chances
	local function fillChances()
		for _, child in chances:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		Theme.Label({ Size = UDim2.new(1, -8, 0, 22), LayoutOrder = 0, TextColor3 = Theme.Colors.Coins, Text = "🎲 Chances de chaque case", Parent = chances })
		for i, reward in WheelConfig.Rewards do
			Theme.Label({
				Size = UDim2.new(1, -8, 0, 20),
				LayoutOrder = i,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if reward.Jackpot then Color3.fromRGB(255, 120, 220) else Theme.Colors.Text,
				Text = ("%s  %s  —  %s"):format(reward.Icon, describe(reward), chanceText(reward.Weight)),
				Parent = chances,
			})
		end
	end

	HUD.AddButton("WheelButton", "🎡 Roue", Color3.fromRGB(230, 120, 40), 12, function()
		if window.Visible then
			window.Visible = false
		else
			fillChances()
			WheelUI.Open()
		end
	end)

	StateController.Changed:Connect(function(key)
		if key == "*" or key == "Wheel" then
			refreshStatus()
			-- À la connexion : ouverture automatique si le tour gratuit est prêt
			if not autoOpened and StateController.Get("Wheel") then
				autoOpened = true
				if freeReady() then
					task.delay(3, function()
						fillChances()
						WheelUI.Open()
					end)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if window.Visible and not spinning then
				refreshStatus()
			end
		end
	end)
end

return WheelUI
