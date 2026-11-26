--[[
	CreatureUtil.lua  (ReplicatedStorage.Shared.CreatureUtil)
	=========================================================
	Aide autour des créatures d'expédition (Config.Creatures, CreatureRarities,
	CreatureMutations, Zones). Partagé client/serveur.
]]

local Config = require(script.Parent.Config)

local CreatureUtil = {}

function CreatureUtil.Get(creatureId: any)
	return if type(creatureId) == "string" then Config.Creatures[creatureId] else nil
end

function CreatureUtil.GetRarity(rarityId: string)
	return Config.CreatureRarities[rarityId] or Config.CreatureRarities.Common
end

function CreatureUtil.GetMutation(mutationId: any)
	return (type(mutationId) == "string" and Config.CreatureMutations[mutationId]) or Config.CreatureMutations.Normal
end

function CreatureUtil.IsValidMutation(mutationId: any): boolean
	return type(mutationId) == "string" and Config.CreatureMutations[mutationId] ~= nil
end

local function sortedKeys(dict: { [string]: any }): { string }
	local ids = {}
	for id in dict do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return (dict[a].Order or 0) < (dict[b].Order or 0)
	end)
	return ids
end

function CreatureUtil.SortedZones(): { string }
	return sortedKeys(Config.Zones)
end

function CreatureUtil.SortedRarities(): { string }
	return sortedKeys(Config.CreatureRarities)
end

function CreatureUtil.SortedMutations(): { string }
	return sortedKeys(Config.CreatureMutations)
end

-- Créatures d'une zone, triées de la plus commune à la plus rare
function CreatureUtil.CreaturesInZone(zoneId: string): { string }
	local ids = {}
	for id, def in Config.Creatures do
		if def.Zone == zoneId then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Config.Creatures[a].Order < Config.Creatures[b].Order
	end)
	return ids
end

-- Toutes les créatures, triées par zone puis par ordre
function CreatureUtil.AllSorted(): { string }
	local ids = {}
	for _, zoneId in CreatureUtil.SortedZones() do
		for _, id in CreatureUtil.CreaturesInZone(zoneId) do
			table.insert(ids, id)
		end
	end
	return ids
end

-- "Champiloup" / "Champiloup Doré" / "Givrelle Dorée"
function CreatureUtil.Label(creatureId: string, mutationId: string?): string
	local def = Config.Creatures[creatureId]
	if not def then
		return creatureId
	end
	local mutation = CreatureUtil.GetMutation(mutationId)
	local adjective = if def.Feminine then mutation.DisplayNameF else mutation.DisplayName
	return def.DisplayName .. (if adjective ~= "" then " " .. adjective else "")
end

-- Coins / seconde d'une créature exposée = revenu de la rareté x zone x mutation
function CreatureUtil.GetIncome(creatureId: string, mutationId: string?): number
	local def = Config.Creatures[creatureId]
	if not def then
		return 0
	end
	local zone = Config.Zones[def.Zone]
	local rarity = CreatureUtil.GetRarity(def.Rarity)
	return rarity.Income * (zone and zone.IncomeMultiplier or 1) * CreatureUtil.GetMutation(mutationId).ValueMultiplier
end

-- Points de prestige d'une créature (vitrine, meilleure prise, classement)
function CreatureUtil.GetPrestige(creatureId: string, mutationId: string?): number
	local def = Config.Creatures[creatureId]
	if not def then
		return 0
	end
	return math.floor(CreatureUtil.GetRarity(def.Rarity).Prestige * CreatureUtil.GetMutation(mutationId).ValueMultiplier)
end

-- Points de prestige d'un animal de ferme (selon sa variante, départagé par le prix de l'espèce)
function CreatureUtil.GetAnimalPrestige(speciesId: string, variantId: string): number
	local species = Config.Animals[speciesId]
	local variant = Config.Variants[variantId] or Config.Variants.Normal
	if not species then
		return 0
	end
	return variant.Prestige + species.Price / 1e6
end

-- Position (0 à 1) du curseur du mini-jeu de capture à l'instant t (temps serveur).
-- Aller-retour régulier : le serveur et le client calculent EXACTEMENT la même valeur,
-- ce qui permet au serveur de vérifier chaque clic.
function CreatureUtil.CursorPosition(startTime: number, speed: number, t: number): number
	local phase = ((t - startTime) * speed) % 2
	return if phase < 1 then phase else 2 - phase
end

-- Valeur = base de la rareté x multiplicateur de zone x mutation
function CreatureUtil.GetValue(creatureId: string, mutationId: string?): number
	local def = Config.Creatures[creatureId]
	if not def then
		return 0
	end
	local zone = Config.Zones[def.Zone]
	local rarity = CreatureUtil.GetRarity(def.Rarity)
	return math.floor(rarity.BaseValue * (zone and zone.ValueMultiplier or 1) * CreatureUtil.GetMutation(mutationId).ValueMultiplier)
end

return CreatureUtil
