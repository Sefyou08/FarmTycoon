--[[
	ItemUtil.lua  (ReplicatedStorage.Shared.ItemUtil)
	=================================================
	Tout ce qui peut être dans l'inventaire est un "objet" (item) :
	  - les récoltes (Config.Crops)
	  - les ressources animales (Config.Resources)
	  - (phase 4) les produits transformés
	Chaque objet existe en plusieurs VARIANTES (Config.Variants : Normal, Gold...),
	qui multiplient sa valeur de vente.
	Partagé client/serveur.
]]

local Config = require(script.Parent.Config)

local ItemUtil = {}

-- Ordre d'affichage : récoltes, puis ressources
local CATEGORIES = { Config.Crops, Config.Resources }

local sortedIds: { string }? = nil

function ItemUtil.Get(itemId: any)
	if type(itemId) ~= "string" then
		return nil
	end
	for _, category in CATEGORIES do
		local item = category[itemId]
		if item then
			return item
		end
	end
	return nil
end

function ItemUtil.SortedIds(): { string }
	if not sortedIds then
		local ids = {}
		for _, category in CATEGORIES do
			local group = {}
			for id in category do
				table.insert(group, id)
			end
			table.sort(group, function(a, b)
				return (category[a].Order or 0) < (category[b].Order or 0)
			end)
			for _, id in group do
				table.insert(ids, id)
			end
		end
		sortedIds = ids
	end
	return sortedIds :: { string }
end

function ItemUtil.GetVariant(variant: any)
	return (type(variant) == "string" and Config.Variants[variant]) or Config.Variants.Normal
end

function ItemUtil.IsValidVariant(variant: any): boolean
	return type(variant) == "string" and Config.Variants[variant] ~= nil
end

-- Variantes triées de la plus commune à la plus rare
function ItemUtil.SortedVariants(): { string }
	local ids = {}
	for id in Config.Variants do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Config.Variants[a].Order < Config.Variants[b].Order
	end)
	return ids
end

-- Adjectif de variante accordé ("Doré" / "Dorée"), "" pour Normal.
-- def = n'importe quelle config ayant un champ Feminine (culture, ressource, animal).
function ItemUtil.VariantAdjective(def: any, variant: string): string
	local info = ItemUtil.GetVariant(variant)
	if def and def.Feminine then
		return info.DisplayNameF
	end
	return info.DisplayName
end

-- "🥛 Lait" ou "🥛 Lait Doré"
function ItemUtil.Label(itemId: string, variant: string?): string
	local item = ItemUtil.Get(itemId)
	if not item then
		return itemId
	end
	local text = (item.Icon and (item.Icon .. " ") or "") .. item.DisplayName
	local adjective = if variant then ItemUtil.VariantAdjective(item, variant) else ""
	if adjective ~= "" then
		text ..= " " .. adjective
	end
	return text
end

-- Prix de vente d'UNE unité (avant multiplicateurs du joueur)
function ItemUtil.UnitValue(itemId: string, variant: string?): number
	local item = ItemUtil.Get(itemId)
	if not item then
		return 0
	end
	return item.SellPrice * ItemUtil.GetVariant(variant).ValueMultiplier
end

return ItemUtil
