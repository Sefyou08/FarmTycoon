--[[
	InventoryService.lua
	====================
	SEUL endroit autorisé à modifier les graines (data.Seeds) et les produits
	récoltés (data.Inventory) d'un joueur. Envoie chaque changement au client.

	Graines :
	  InventoryService:GetSeedCount(player, cropId) -> number
	  InventoryService:AddSeeds(player, cropId, amount) -> montantAjouté
	  InventoryService:ConsumeSeed(player, cropId) -> boolean
	Produits :
	  InventoryService:GetItemCount(player) -> nombre total de produits
	  InventoryService:HasRoom(player, amount) -> boolean
	  InventoryService:AddCrop(player, cropId, variant, amount) -> boolean
	  InventoryService:TakeAllCrops(player) -> { [cropId] = { [variant] = n } } (vide l'inventaire)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CropUtil = require(ReplicatedStorage.Shared.CropUtil)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)

local InventoryService = {}

local FarmConfig = Config.Farm

--------------------------------------------------------------------------
-- Graines
--------------------------------------------------------------------------

function InventoryService:GetSeedCount(player: Player, cropId: string): number
	local data = DataService:GetData(player)
	return if data then (data.Seeds[cropId] or 0) else 0
end

function InventoryService:AddSeeds(player: Player, cropId: string, amount: number): number
	local data = DataService:GetData(player)
	if not data or not CropUtil.Get(cropId) or amount <= 0 then
		return 0
	end
	local current = data.Seeds[cropId] or 0
	local added = math.min(math.floor(amount), FarmConfig.MaxSeedsPerCrop - current)
	if added <= 0 then
		return 0
	end
	data.Seeds[cropId] = current + added
	SyncService:Set(player, "Seeds", data.Seeds)
	return added
end

function InventoryService:ConsumeSeed(player: Player, cropId: string): boolean
	local data = DataService:GetData(player)
	if not data then
		return false
	end
	local current = data.Seeds[cropId] or 0
	if current <= 0 then
		return false
	end
	-- On supprime la clé à 0 pour garder une sauvegarde propre
	data.Seeds[cropId] = if current > 1 then current - 1 else nil
	SyncService:Set(player, "Seeds", data.Seeds)
	return true
end

-- Premier type de graine possédé (ordre de la boutique), ou nil
function InventoryService:GetFirstOwnedSeed(player: Player): string?
	local data = DataService:GetData(player)
	if not data then
		return nil
	end
	for _, cropId in CropUtil.SortedIds() do
		if (data.Seeds[cropId] or 0) > 0 then
			return cropId
		end
	end
	return nil
end

--------------------------------------------------------------------------
-- Produits récoltés
--------------------------------------------------------------------------

function InventoryService:GetItemCount(player: Player): number
	local data = DataService:GetData(player)
	if not data then
		return 0
	end
	local total = 0
	for _, variants in data.Inventory do
		for _, count in variants do
			total += count
		end
	end
	return total
end

function InventoryService:HasRoom(player: Player, amount: number?): boolean
	return self:GetItemCount(player) + (amount or 1) <= FarmConfig.InventoryCapacity
end

-- variant = "Normal" (phase 3 : "Golden", "Rainbow"...)
function InventoryService:AddCrop(player: Player, cropId: string, variant: string, amount: number?): boolean
	local data = DataService:GetData(player)
	local count = amount or 1
	if not data or not CropUtil.Get(cropId) or count <= 0 then
		return false
	end
	if not self:HasRoom(player, count) then
		return false
	end

	local variants = data.Inventory[cropId]
	if not variants then
		variants = {}
		data.Inventory[cropId] = variants
	end
	variants[variant] = (variants[variant] or 0) + count
	data.Stats.TotalHarvested += count

	SyncService:Set(player, "Inventory", data.Inventory)
	return true
end

-- Vide l'inventaire et renvoie ce qu'il contenait (utilisé par la vente).
function InventoryService:TakeAllCrops(player: Player): { [string]: { [string]: number } }
	local data = DataService:GetData(player)
	if not data then
		return {}
	end
	local items = data.Inventory
	data.Inventory = {}
	SyncService:Set(player, "Inventory", data.Inventory)
	return items
end

--------------------------------------------------------------------------
-- Cycle de vie
--------------------------------------------------------------------------

function InventoryService:Init()
	-- Pack de départ (une seule fois par joueur, même pour les anciens joueurs)
	DataService:OnProfileLoaded(function(player, data)
		if data.StarterPackGiven then
			return
		end
		data.StarterPackGiven = true
		for cropId, amount in FarmConfig.StarterSeeds do
			local added = self:AddSeeds(player, cropId, amount)
			if added > 0 then
				SyncService:Notify(player, ("Pack de départ : %d graines %s !"):format(added, CropUtil.Label(cropId)), "Success")
			end
		end
	end)
end

function InventoryService:Start() end

return InventoryService
