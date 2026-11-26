--[[
	CosmeticUtil.lua  (ReplicatedStorage.Shared.CosmeticUtil)
	=========================================================
	Aide autour des cosmétiques (Config.Cosmetics), partagée client/serveur.
	Les cosmétiques sont UNIQUEMENT visuels : aucun avantage de jeu.

	  CosmeticUtil.Get(id)
	  CosmeticUtil.ByCategory(categoryId) -> liste d'ids (défaut d'abord, puis par type de déblocage)
	  CosmeticUtil.IsOwned(data, id) -> boolean (gratuit, niveau atteint, zone d'Index, ou acheté)
	  CosmeticUtil.Equipped(data, categoryId) -> définition équipée (ou celle par défaut)
	  CosmeticUtil.EquippedId(data, categoryId) -> id
	  CosmeticUtil.UnlockText(def) -> "💰 25K", "Niveau 10", "Index 🌲 Forêt", "49 R$"...
	  CosmeticUtil.FindByProductId(productId) -> id | nil
]]

local Config = require(script.Parent.Config)

local CosmeticUtil = {}

local UNLOCK_ORDER = { Free = 1, Level = 2, Index = 3, Coins = 4, Robux = 5 }

function CosmeticUtil.Get(id: any)
	return if type(id) == "string" then Config.Cosmetics[id] else nil
end

function CosmeticUtil.ByCategory(categoryId: string): { string }
	local ids = {}
	for id, def in Config.Cosmetics do
		if def.Category == categoryId then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local da, db = Config.Cosmetics[a], Config.Cosmetics[b]
		if (da.Default == true) ~= (db.Default == true) then
			return da.Default == true
		end
		local oa, ob = UNLOCK_ORDER[da.Unlock.Kind] or 9, UNLOCK_ORDER[db.Unlock.Kind] or 9
		if oa ~= ob then
			return oa < ob
		end
		return (da.Unlock.Price or da.Unlock.Level or 0) < (db.Unlock.Price or db.Unlock.Level or 0)
	end)
	return ids
end

function CosmeticUtil.IsOwned(data: { [string]: any }?, id: string): boolean
	local def = Config.Cosmetics[id]
	if not def or not data then
		return false
	end
	local unlock = def.Unlock
	if unlock.Kind == "Free" then
		return true
	elseif unlock.Kind == "Level" then
		return (data.Level or 1) >= unlock.Level
	elseif unlock.Kind == "Index" then
		return data.IndexRewards ~= nil and data.IndexRewards[unlock.Zone] == true
	end
	-- Coins / Robux : acheté
	return data.Cosmetics ~= nil and data.Cosmetics.Owned ~= nil and data.Cosmetics.Owned[id] == true
end

function CosmeticUtil.DefaultId(categoryId: string): string?
	for id, def in Config.Cosmetics do
		if def.Category == categoryId and def.Default then
			return id
		end
	end
	return nil
end

function CosmeticUtil.EquippedId(data: { [string]: any }?, categoryId: string): string?
	local equipped = data and data.Cosmetics and data.Cosmetics.Equipped and data.Cosmetics.Equipped[categoryId]
	if equipped and Config.Cosmetics[equipped] and Config.Cosmetics[equipped].Category == categoryId and CosmeticUtil.IsOwned(data, equipped) then
		return equipped
	end
	return CosmeticUtil.DefaultId(categoryId)
end

function CosmeticUtil.Equipped(data: { [string]: any }?, categoryId: string)
	local id = CosmeticUtil.EquippedId(data, categoryId)
	return if id then Config.Cosmetics[id] else nil
end

function CosmeticUtil.UnlockText(def: any): string
	local unlock = def.Unlock
	if unlock.Kind == "Free" then
		return "Gratuit"
	elseif unlock.Kind == "Level" then
		return ("Niveau %d"):format(unlock.Level)
	elseif unlock.Kind == "Index" then
		local zone = Config.Zones[unlock.Zone]
		return ("Index %s %s complété"):format(zone and zone.Icon or "", zone and zone.DisplayName or unlock.Zone)
	elseif unlock.Kind == "Coins" then
		return ("💰 %d"):format(unlock.Price)
	elseif unlock.Kind == "Robux" then
		return ("%d R$"):format(unlock.Price)
	end
	return ""
end

function CosmeticUtil.FindByProductId(productId: number): string?
	if productId == 0 then
		return nil
	end
	for id, def in Config.Cosmetics do
		if def.Unlock.Kind == "Robux" and def.Unlock.ProductId == productId then
			return id
		end
	end
	return nil
end

return CosmeticUtil
