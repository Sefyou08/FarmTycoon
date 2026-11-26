--[[
	RebirthService.lua
	==================
	Rebirth : le joueur remet sa ferme à zéro contre un multiplicateur de Coins
	permanent (Config.Rebirth.CoinMultiplierPerRebirth par rebirth, appliqué à la
	vente et aux socles via CurrencyService:GetCoinMultiplier).

	Conditions (vérifiées ici) : niveau >= Config.Progression.Unlocks.Rebirth et
	Coins >= RebirthService:GetCost(rebirths).

	Remis à zéro : Coins, niveau de parcelle, champs (1 champ de 6 cases), plantes,
	graines (pack de départ redonné), enclos + animaux, bâtiments, inventaire.
	Gardé : créatures, Index, récompenses d'Index, zones, socles (rangés), XP / niveau,
	aides PNJ, boosts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)
local XPService = require(script.Parent.XPService)
local InventoryService = require(script.Parent.InventoryService)

local RebirthService = {}

function RebirthService:GetCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths)
end

local function onRebirth(player: Player): (boolean, string)
	if not RemoteGuard.CheckCooldown(player, "Rebirth", 3) then
		return false, "Doucement !"
	end
	local data = DataService:GetData(player)
	if not data or not PlotService:GetPlot(player) then
		return false, "Ta ferme n'est pas encore prête."
	end
	if not XPService:HasUnlock(player, "Rebirth") then
		return false, ("Rebirth débloqué au niveau %d."):format(Config.Progression.Unlocks.Rebirth)
	end
	local cost = RebirthService:GetCost(data.Rebirths)
	if data.Coins < cost then
		return false, ("Il te faut %s Coins pour renaître."):format(Format.Number(cost))
	end

	-- 1. Remise à zéro de la ferme (les données d'abord, puis reconstruction des visuels)
	data.Rebirths += 1
	data.Coins = 0
	data.PlotLevel = 1
	data.Fields = {} -- FarmService recrée le 1er champ de 6 cases
	data.Plants = {}
	data.Seeds = {}
	data.Inventory = {}
	data.Pens = {}
	data.Buildings = {}
	for _, pedestal in data.Pedestals do
		pedestal.Placed = false -- les socles sont gardés mais rangés (la parcelle redevient petite)
	end

	-- 2. Pack de départ redonné
	for cropId, amount in Config.Farm.StarterSeeds do
		InventoryService:AddSeeds(player, cropId, amount)
	end

	-- 3. Reconstruction de la ferme et mise à jour de l'affichage
	PlotService:Reload(player)
	CurrencyService:Refresh(player)
	for _, key in { "Inventory", "Seeds", "Fields", "Pens", "Buildings", "Pedestals", "PlotLevel" } do
		SyncService:Set(player, key, data[key])
	end
	PlotService:TeleportHome(player)

	local multiplier = 1 + Config.Rebirth.CoinMultiplierPerRebirth * data.Rebirths
	SyncService:NotifyAll(("⭐ %s a fait son rebirth n°%d !"):format(player.DisplayName, data.Rebirths), "Rare")
	return true, ("⭐ Rebirth %d ! Tes gains de Coins sont maintenant x%s."):format(data.Rebirths, tostring(multiplier))
end

function RebirthService:Init() end

function RebirthService:Start()
	Remotes.Get("Rebirth").OnServerInvoke = onRebirth
end

return RebirthService
