--[[
	ShopService.lua
	===============
	Boutique de graines : un stand avec PNJ au centre de la map.
	Le ProximityPrompt du stand ouvre l'interface côté client (attribut OpenUI).
	L'achat passe par la RemoteFunction "BuySeed", entièrement validée ici :
	type des arguments, cooldown, distance au stand, disponibilité, Coins.

	Phase 3 : le stock tournant (graines rares toutes les 5 min) se branchera
	sur ShopService:IsAvailable().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CropUtil = require(ReplicatedStorage.Shared.CropUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local StandBuilder = require(script.Parent.Parent.Util.StandBuilder)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)
local FarmService = require(script.Parent.FarmService)

local ShopService = {}

local standPosition: Vector3

-- Phase 2 : seules les graines communes sont en vente, en stock illimité.
function ShopService:IsAvailable(cropId: string): boolean
	local crop = CropUtil.Get(cropId)
	return crop ~= nil and crop.Rarity == "Common"
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
	-- 4. Disponibilité et place
	if not ShopService:IsAvailable(cropId) then
		return false, "Cette graine n'est pas en vente."
	end
	local room = Config.Farm.MaxSeedsPerCrop - InventoryService:GetSeedCount(player, cropId)
	local count = math.min(amount, room)
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
end

return ShopService
