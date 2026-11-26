--[[
	InventoryService.lua
	====================
	SEUL endroit autorisé à modifier les graines (data.Seeds) et les objets
	(data.Inventory : récoltes, ressources animales, et plus tard produits) d'un
	joueur. Envoie chaque changement au client.

	Graines :
	  InventoryService:GetSeedCount(player, cropId) -> number
	  InventoryService:AddSeeds(player, cropId, amount) -> montantAjouté
	  InventoryService:ConsumeSeed(player, cropId) -> boolean
	  InventoryService:GetFirstOwnedSeed(player) -> cropId | nil
	Objets (itemId = id de Config.Crops ou Config.Resources, variant = id de Config.Variants) :
	  InventoryService:GetItemCount(player) -> nombre total d'objets
	  InventoryService:GetFreeSpace(player) -> places libres
	  InventoryService:HasRoom(player, amount) -> boolean
	  InventoryService:GetAmount(player, itemId, variant?) -> quantité (toutes variantes si nil)
	  InventoryService:AddItem(player, itemId, variant, amount) -> boolean
	  InventoryService:RemoveItem(player, itemId, variant, amount) -> boolean
	  InventoryService:RemoveAnyVariant(player, itemId, amount) -> nombre retiré (variantes communes d'abord)
	  InventoryService:TakeAllItems(player) -> { [itemId] = { [variant] = n } } (vide l'inventaire)
	  InventoryService:OnItemsChanged(callback(player))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CropUtil = require(ReplicatedStorage.Shared.CropUtil)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)

local InventoryService = {}

local FarmConfig = Config.Farm

local changedCallbacks: { (Player) -> () } = {}

-- callback(player) : appelé après chaque modification de data.Inventory
function InventoryService:OnItemsChanged(callback: (Player) -> ())
	table.insert(changedCallbacks, callback)
end

local function itemsChanged(player: Player, data: { [string]: any })
	SyncService:Set(player, "Inventory", data.Inventory)
	for _, callback in changedCallbacks do
		task.spawn(callback, player)
	end
end

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
-- Objets
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

function InventoryService:GetFreeSpace(player: Player): number
	return math.max(0, ItemUtil.Capacity(player) - self:GetItemCount(player))
end

function InventoryService:HasRoom(player: Player, amount: number?): boolean
	return self:GetFreeSpace(player) >= (amount or 1)
end

function InventoryService:GetAmount(player: Player, itemId: string, variant: string?): number
	local data = DataService:GetData(player)
	local variants = data and data.Inventory[itemId]
	if not variants then
		return 0
	end
	if variant then
		return variants[variant] or 0
	end
	local total = 0
	for _, count in variants do
		total += count
	end
	return total
end

function InventoryService:AddItem(player: Player, itemId: string, variant: string, amount: number?): boolean
	local data = DataService:GetData(player)
	local count = math.floor(amount or 1)
	if not data or not ItemUtil.Get(itemId) or not ItemUtil.IsValidVariant(variant) or count <= 0 then
		return false
	end
	if not self:HasRoom(player, count) then
		return false
	end

	local variants = data.Inventory[itemId]
	if not variants then
		variants = {}
		data.Inventory[itemId] = variants
	end
	variants[variant] = (variants[variant] or 0) + count

	itemsChanged(player, data)
	return true
end

function InventoryService:RemoveItem(player: Player, itemId: string, variant: string, amount: number): boolean
	local data = DataService:GetData(player)
	local variants = data and data.Inventory[itemId]
	local count = math.floor(amount)
	if not variants or count <= 0 or (variants[variant] or 0) < count then
		return false
	end

	variants[variant] -= count
	if variants[variant] <= 0 then
		variants[variant] = nil
	end
	if next(variants) == nil then
		data.Inventory[itemId] = nil
	end

	itemsChanged(player, data)
	return true
end

-- Retire jusqu'à `amount` unités, toutes variantes confondues, en commençant par les plus communes.
function InventoryService:RemoveAnyVariant(player: Player, itemId: string, amount: number): number
	local removed = 0
	for _, variant in ItemUtil.SortedVariants() do
		local need = amount - removed
		if need <= 0 then
			break
		end
		local take = math.min(need, self:GetAmount(player, itemId, variant))
		if take > 0 and self:RemoveItem(player, itemId, variant, take) then
			removed += take
		end
	end
	return removed
end

-- Vide l'inventaire et renvoie ce qu'il contenait (utilisé par la vente).
function InventoryService:TakeAllItems(player: Player): { [string]: { [string]: number } }
	local data = DataService:GetData(player)
	if not data then
		return {}
	end
	local items = data.Inventory
	data.Inventory = {}
	itemsChanged(player, data)
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
