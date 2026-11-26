--[[
	IndexService.lua
	================
	Index des créatures : une zone est "complète" quand toutes ses créatures
	(hors Divines, qui sont un bonus) ont été découvertes (data.CreatureIndex).
	Le joueur réclame alors la récompense de la zone (Config.Index.ZoneRewards),
	une seule fois (data.IndexRewards). Validé ici : RemoteFunction "ClaimIndexReward".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureUtil = require(ReplicatedStorage.Shared.CreatureUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local SyncService = require(script.Parent.SyncService)

local IndexService = {}

-- true si toutes les créatures non Divines de la zone sont découvertes
function IndexService:IsZoneComplete(data: { [string]: any }, zoneId: string): boolean
	for _, creatureId in CreatureUtil.CreaturesInZone(zoneId) do
		local rarity = CreatureUtil.GetRarity(Config.Creatures[creatureId].Rarity)
		if not rarity.Divine and not data.CreatureIndex[creatureId] then
			return false
		end
	end
	return true
end

local function onClaim(player: Player, zoneId: any): (boolean, string)
	if type(zoneId) ~= "string" or not Config.Zones[zoneId] then
		return false, "Zone inconnue."
	end
	if not RemoteGuard.CheckCooldown(player, "ClaimIndexReward", 0.5) then
		return false, "Doucement !"
	end
	local data = DataService:GetData(player)
	if not data then
		return false, "Données pas encore chargées."
	end
	if data.IndexRewards[zoneId] then
		return false, "Récompense déjà réclamée."
	end
	if not IndexService:IsZoneComplete(data, zoneId) then
		return false, "Découvre d'abord toutes les créatures de cette zone."
	end
	local reward = Config.Index.ZoneRewards[zoneId] or 0
	data.IndexRewards[zoneId] = true
	SyncService:Set(player, "IndexRewards", data.IndexRewards)
	if reward > 0 then
		CurrencyService:AddCoins(player, reward, "IndexReward:" .. zoneId)
	end
	local zone = Config.Zones[zoneId]
	return true, ("📚 Index %s %s complété : +%s Coins !"):format(zone.Icon, zone.DisplayName, Format.Number(reward))
end

function IndexService:Init() end

function IndexService:Start()
	Remotes.Get("ClaimIndexReward").OnServerInvoke = onClaim
end

return IndexService
