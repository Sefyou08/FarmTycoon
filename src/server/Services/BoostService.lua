--[[
	BoostService.lua
	================
	Consommables et boosts temporaires.

	  • Manger un objet de Config.Consumables (RemoteFunction "Consume") retire 1 objet
	    de l'inventaire et active un boost : Speed, XP, Coins, Capture ou Combat.
	  • Puissance et durée augmentent avec la VARIANTE de l'objet mangé
	    (Config.Boosts.VariantPowerBonus / VariantDurationBonus par rang).
	  • Un même type de boost ne se cumule pas en puissance : on garde la plus forte,
	    et la durée s'ajoute (plafond Config.Boosts.MaxDuration).
	  • Les boosts sont sauvegardés (data.Boosts) avec leur heure de fin (os.time) :
	    le temps continue de passer quand le joueur est hors ligne.
	  • Vitesse : le serveur pose l'attribut "SpeedBoost" sur le joueur, le client
	    l'applique à la marche (MovementController).

	API :
	  BoostService:GetPower(player, boostType) -> bonus actif (0 si aucun ; 0.2 = +20 %)
	  BoostService:GetMultiplier(player, boostType) -> 1 + bonus
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local GameEvents = require(script.Parent.Parent.Util.GameEvents)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local InventoryService = require(script.Parent.InventoryService)

local BoostConfig = Config.Boosts

local BoostService = {}

function BoostService:GetPower(player: Player, boostType: string): number
	local data = DataService:GetData(player)
	local boost = data and data.Boosts[boostType]
	if boost and boost.EndsAt > os.time() then
		return boost.Power
	end
	return 0
end

function BoostService:GetMultiplier(player: Player, boostType: string): number
	return 1 + self:GetPower(player, boostType)
end

local function applySpeedAttribute(player: Player)
	local power = BoostService:GetPower(player, "Speed")
	player:SetAttribute("SpeedBoost", if power > 0 then 1 + power else nil)
end

-- Supprime les boosts terminés. Renvoie true si quelque chose a changé.
local function cleanup(player: Player, data: { [string]: any }): boolean
	local changed = false
	local now = os.time()
	for boostType, boost in data.Boosts do
		if type(boost) ~= "table" or not BoostConfig.Types[boostType] or (tonumber(boost.EndsAt) or 0) <= now then
			data.Boosts[boostType] = nil
			changed = true
			if type(boost) == "table" and BoostConfig.Types[boostType] then
				SyncService:Notify(player, ("%s Boost %s terminé."):format(BoostConfig.Types[boostType].Icon, BoostConfig.Types[boostType].DisplayName), "Info")
			end
		end
	end
	return changed
end

local function onConsume(player: Player, itemId: any, variant: any): (boolean, string)
	local consumable = type(itemId) == "string" and Config.Consumables[itemId]
	if not consumable or not ItemUtil.IsValidVariant(variant) then
		return false, "Cet objet ne se mange pas."
	end
	if not RemoteGuard.CheckCooldown(player, "Consume", 0.5) then
		return false, "Doucement !"
	end
	local data = DataService:GetData(player)
	if not data then
		return false, "Données pas encore chargées."
	end
	if not InventoryService:RemoveItem(player, itemId, variant, 1) then
		return false, "Tu n'as pas cet objet."
	end

	-- Puissance et durée selon la variante (Normal = rang 1)
	local rank = ItemUtil.GetVariant(variant).Order - 1
	local power = consumable.Power * (1 + BoostConfig.VariantPowerBonus * rank)
	local duration = consumable.Duration * (1 + BoostConfig.VariantDurationBonus * rank)
	BoostService:Grant(player, consumable.Boost, power, duration)
	GameEvents.Fire(player, "Consume")

	local info = BoostConfig.Types[consumable.Boost]
	return true, ("%s %s mangé : boost %s +%d %% pendant %s"):format(
		info.Icon,
		ItemUtil.Label(itemId, variant),
		info.DisplayName,
		math.floor(power * 100 + 0.5),
		Format.Time(duration)
	)
end

-- Active (ou prolonge) un boost : utilisé par les consommables, la roue et les achats Robux.
-- Même type : on garde la plus forte puissance, la durée s'ajoute (plafond MaxDuration).
function BoostService:Grant(player: Player, boostType: string, power: number, duration: number): boolean
	local data = DataService:GetData(player)
	if not data or not BoostConfig.Types[boostType] or power <= 0 or duration <= 0 then
		return false
	end
	local now = os.time()
	local current = data.Boosts[boostType]
	local endsAt = math.max(if current then current.EndsAt else now, now) + duration
	data.Boosts[boostType] = {
		Power = math.max(power, if current and current.EndsAt > now then current.Power else 0),
		EndsAt = math.min(endsAt, now + BoostConfig.MaxDuration),
	}
	SyncService:Set(player, "Boosts", data.Boosts)
	applySpeedAttribute(player)
	return true
end

function BoostService:Init()
	DataService:OnProfileLoaded(function(player, data)
		cleanup(player, data)
		SyncService:Set(player, "Boosts", data.Boosts)
		applySpeedAttribute(player)
	end)
end

function BoostService:Start()
	Remotes.Get("Consume").OnServerInvoke = onConsume
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = DataService:GetData(player)
				if data and cleanup(player, data) then
					SyncService:Set(player, "Boosts", data.Boosts)
					applySpeedAttribute(player)
				end
			end
		end
	end)
end

return BoostService
