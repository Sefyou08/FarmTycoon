--[[
	CropUtil.lua  (ReplicatedStorage.Shared.CropUtil)
	=================================================
	Petites fonctions d'aide autour de Config.Crops, partagées client/serveur.
]]

local Config = require(script.Parent.Config)

local CropUtil = {}

local sortedIds: { string }? = nil

-- Renvoie la config d'une culture, ou nil si l'id est invalide (sécurise les entrées client).
function CropUtil.Get(cropId: any)
	if type(cropId) ~= "string" then
		return nil
	end
	return Config.Crops[cropId]
end

-- Liste des ids triés par Order (ordre d'affichage dans la boutique / la barre de graines).
function CropUtil.SortedIds(): { string }
	if not sortedIds then
		local ids = {}
		for id in Config.Crops do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			return (Config.Crops[a].Order or 0) < (Config.Crops[b].Order or 0)
		end)
		sortedIds = ids
	end
	return sortedIds :: { string }
end

function CropUtil.RarityInfo(rarity: string)
	return Config.Rarities[rarity] or Config.Rarities.Common
end

-- Nom affiché avec icône : "🥕 Carotte"
function CropUtil.Label(cropId: string): string
	local crop = Config.Crops[cropId]
	if not crop then
		return cropId
	end
	return (crop.Icon and (crop.Icon .. " ") or "") .. crop.DisplayName
end

return CropUtil
