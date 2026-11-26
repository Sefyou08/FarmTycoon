--[[
	ShopService.lua
	===============
	Boutique de graines : un stand avec PNJ au centre de la map.
	Le ProximityPrompt du stand ouvre l'interface côté client (attribut OpenUI).
	L'achat passe par la RemoteFunction "BuySeed", entièrement validée ici :
	type des arguments, cooldown, distance au stand, disponibilité, Coins.

	Stock tournant (phase 7) : les graines communes sont en vente illimitée ; les graines
	RARES (Rare / Épique / Légendaire) n'apparaissent que dans un stock renouvelé toutes
	les Config.Shop.Rotation.Interval secondes. Le stock est le même pour tout le serveur,
	avec une quantité PAR JOUEUR. Le client reçoit son stock restant et l'heure du
	prochain renouvellement (RemoteEvent "ShopStock") pour afficher le compte à rebours.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local CropUtil = require(ReplicatedStorage.Shared.CropUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local StandBuilder = require(script.Parent.Parent.Util.StandBuilder)
local CurrencyService = require(script.Parent.CurrencyService)
local SyncService = require(script.Parent.SyncService)
local InventoryService = require(script.Parent.InventoryService)
local FarmService = require(script.Parent.FarmService)

local ShopService = {}

local standPosition: Vector3
local Rotation = Config.Shop.Rotation

-- Stock tournant actuel : { [cropId] = quantité par joueur }, et achats de chaque joueur
local rotationStock: { [string]: number } = {}
local rotationEndsAt = 0
local bought: { [Player]: { [string]: number } } = {}
local rng = Random.new()

-- Quantité encore achetable par ce joueur (math.huge pour les communes)
function ShopService:GetRemaining(player: Player, cropId: string): number
	local crop = CropUtil.Get(cropId)
	if not crop then
		return 0
	end
	if crop.Rarity == "Common" then
		return math.huge
	end
	local stock = rotationStock[cropId] or 0
	local already = (bought[player] and bought[player][cropId]) or 0
	return math.max(0, stock - already)
end

function ShopService:IsAvailable(cropId: string): boolean
	local crop = CropUtil.Get(cropId)
	return crop ~= nil and (crop.Rarity == "Common" or (rotationStock[cropId] or 0) > 0)
end

-- Envoie à un joueur son stock restant + l'heure du prochain renouvellement
local function sendStock(player: Player)
	local remaining = {}
	for cropId in rotationStock do
		remaining[cropId] = ShopService:GetRemaining(player, cropId)
	end
	Remotes.Get("ShopStock"):FireClient(player, { EndsAt = rotationEndsAt, Stock = remaining })
end

local function rotate()
	rotationStock = {}
	table.clear(bought)
	for cropId, crop in Config.Crops do
		local chance = Rotation.Chance[crop.Rarity]
		local range = Rotation.Stock[crop.Rarity]
		if chance and range and rng:NextNumber() < chance then
			rotationStock[cropId] = rng:NextInteger(range[1], range[2])
		end
	end
	rotationEndsAt = Workspace:GetServerTimeNow() + Rotation.Interval
	for _, player in Players:GetPlayers() do
		sendStock(player)
	end
	-- Une graine Légendaire en stock : on prévient tout le monde
	for cropId in rotationStock do
		if Config.Crops[cropId].Rarity == "Legendary" then
			SyncService:NotifyAll(("🌟 Graine Légendaire en boutique : %s !"):format(CropUtil.Label(cropId)), "Rare")
		end
	end
end

local function onBuySeed(player: Player, cropId: any, amount: any): (boolean, string)
	-- 1. Arguments (un exploiteur peut envoyer n'importe quoi)
	local crop = CropUtil.Get(cropId)
	if not crop then
		return false, "Graine inconnue."
	end
	if not RemoteGuard.IsValidNumber(amount, 1, Config.Shop.MaxBuyAmount, true) then
		return false, "Quantité invalide."
	end
	-- 2. Anti-spam
	if not RemoteGuard.CheckCooldown(player, "BuySeed", Config.Shop.BuyCooldown) then
		return false, "Doucement !"
	end
	-- 3. Distance au stand
	if not RemoteGuard.IsNear(player, standPosition, Config.Stands.MaxDistance) then
		return false, "Approche-toi de la boutique."
	end
	-- 4. Disponibilité (stock tournant) et place
	if not ShopService:IsAvailable(cropId) then
		return false, "Cette graine n'est pas en stock en ce moment."
	end
	local remaining = ShopService:GetRemaining(player, cropId)
	if remaining <= 0 then
		return false, "Stock épuisé pour toi : attends le prochain renouvellement !"
	end
	local room = Config.Farm.MaxSeedsPerCrop - InventoryService:GetSeedCount(player, cropId)
	local count = math.min(amount, room, remaining)
	if count <= 0 then
		return false, "Tu as déjà le maximum de cette graine."
	end
	-- 5. Paiement (le serveur vérifie le solde)
	local cost = crop.SeedPrice * count
	if not CurrencyService:SpendCoins(player, cost, "BuySeed:" .. cropId) then
		return false, "Pas assez de Coins !"
	end

	InventoryService:AddSeeds(player, cropId, count)
	FarmService:RefreshSeedSelection(player)
	if crop.Rarity ~= "Common" then
		bought[player] = bought[player] or {}
		bought[player][cropId] = (bought[player][cropId] or 0) + count
		sendStock(player)
	end
	return true, ("+%d graine(s) %s"):format(count, CropUtil.Label(cropId))
end

function ShopService:Init()
	local stands = Config.Stands
	standPosition = stands.SeedShopPosition

	local _, _, prompt = StandBuilder.Build({
		Name = "SeedShop",
		Position = stands.SeedShopPosition,
		Facing = Vector3.new(1, 0, 0), -- tourné vers le centre de la map
		Color = Color3.fromRGB(80, 160, 80),
		Title = "🌱 GRAINES",
		ActionText = "Ouvrir la boutique",
		ObjectText = "Vendeur de graines",
		PromptDistance = 10,
	})
	prompt:SetAttribute("OpenUI", "SeedShop") -- le client ouvre la fenêtre de boutique
end

function ShopService:Start()
	Remotes.Get("BuySeed").OnServerInvoke = onBuySeed

	rotate()
	task.spawn(function()
		while true do
			task.wait(1)
			if Workspace:GetServerTimeNow() >= rotationEndsAt then
				rotate()
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.wait(2) -- laisse le client démarrer
		sendStock(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		bought[player] = nil
	end)
end

return ShopService
