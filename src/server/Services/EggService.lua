--[[
	EggService.lua
	==============
	Œufs de créatures (récompenses de donjon, Config.Eggs).
	  • RemoteFunction "Hatch"(eggId, variante) : retire l'œuf du sac et le met à
	    couver (Config.EggSettings.Incubators œufs en même temps).
	  • data.Hatching = { { Id, Egg, ReadyAt = os.time() } } : l'éclosion continue
	    hors ligne.
	  • À l'éclosion, une créature de la zone de l'œuf est tirée avec des raretés
	    hautes favorisées (Config.EggSettings.RarityWeightMultiplier), plus une
	    mutation, puis ajoutée à la collection (Index, annonces, XP).
	  • Collection pleine : l'œuf attend qu'une place se libère.
	  • Phase 9 : accélération de l'éclosion en Robux -> GetHatchSpeedMultiplier.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureUtil = require(ReplicatedStorage.Shared.CreatureUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local InventoryService = require(script.Parent.InventoryService)
local ExpeditionService = require(script.Parent.ExpeditionService)

local EggService = {}

local warnedFull: { [Player]: boolean } = {}

-- Phase 9 (Robux) : éclosion plus rapide
function EggService:GetHatchSpeedMultiplier(_player: Player): number
	return 1
end

local function onHatch(player: Player, eggId: any, variant: any): (boolean, string)
	local egg = type(eggId) == "string" and Config.Eggs[eggId]
	if not egg or not ItemUtil.IsValidVariant(variant) then
		return false, "Ce n'est pas un œuf."
	end
	if not RemoteGuard.CheckCooldown(player, "Hatch", 0.5) then
		return false, "Doucement !"
	end
	local data = DataService:GetData(player)
	if not data then
		return false, "Données pas encore chargées."
	end
	if #data.Hatching >= Config.EggSettings.Incubators then
		return false, ("Tes %d couveuses sont occupées."):format(Config.EggSettings.Incubators)
	end
	if not InventoryService:RemoveItem(player, eggId, variant, 1) then
		return false, "Tu n'as pas cet œuf."
	end
	local duration = math.ceil(egg.HatchTime / EggService:GetHatchSpeedMultiplier(player))
	table.insert(data.Hatching, { Id = HttpService:GenerateGUID(false), Egg = eggId, ReadyAt = os.time() + duration })
	SyncService:Set(player, "Hatching", data.Hatching)
	return true, ("🐣 %s mis à couver : éclosion dans %s"):format(egg.DisplayName, Format.Time(duration))
end

local function hatchReady(player: Player, data: { [string]: any })
	local now = os.time()
	local changed = false
	for i = #data.Hatching, 1, -1 do
		local entry = data.Hatching[i]
		local egg = type(entry) == "table" and Config.Eggs[entry.Egg]
		if not egg then
			table.remove(data.Hatching, i)
			changed = true
		elseif now >= (tonumber(entry.ReadyAt) or 0) then
			if #data.Creatures >= Config.Expeditions.MaxCreatures then
				if not warnedFull[player] then
					warnedFull[player] = true
					SyncService:Notify(player, "🐣 Un œuf est prêt mais ta collection est pleine : vends ou expose des créatures !", "Error")
				end
				break
			end
			local creatureId = ExpeditionService:PickCreature(egg.Zone, Config.EggSettings.RarityWeightMultiplier)
			if creatureId then
				local mutationId = ExpeditionService:RollMutation()
				if ExpeditionService:GiveCreature(player, creatureId, mutationId) then
					local rarity = CreatureUtil.GetRarity(Config.Creatures[creatureId].Rarity)
					SyncService:Notify(player, ("🐣 Ton %s a éclos : %s [%s] !"):format(egg.DisplayName, CreatureUtil.Label(creatureId, mutationId), rarity.DisplayName), "Rare")
				end
			end
			table.remove(data.Hatching, i)
			changed = true
			warnedFull[player] = nil
		end
	end
	if changed then
		SyncService:Set(player, "Hatching", data.Hatching)
	end
end

function EggService:Init()
	DataService:OnProfileLoaded(function(player, data)
		if type(data.Hatching) ~= "table" then
			data.Hatching = {}
		end
		SyncService:Set(player, "Hatching", data.Hatching)
	end)
end

function EggService:Start()
	Remotes.Get("Hatch").OnServerInvoke = onHatch
	Players.PlayerRemoving:Connect(function(player)
		warnedFull[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = DataService:GetData(player)
				if data and #data.Hatching > 0 then
					hatchReady(player, data)
				end
			end
		end
	end)
end

return EggService
