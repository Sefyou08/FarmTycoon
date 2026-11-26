--[[
	WheelService.lua
	================
	Roue quotidienne (Config.Wheel).
	  • 1 tour GRATUIT toutes les 24 h (data.Wheel.LastFree, sauvegardé) + tours achetés
	    (data.Wheel.ExtraSpins, Developer Products WheelSpin / WheelSpins5).
	  • RemoteFunction "SpinWheel" : le SERVEUR tire la récompense (poids de Config.Wheel.Rewards),
	    la donne tout de suite, et renvoie au client l'index de la case gagnée : le client
	    fait tourner la roue avec suspense et s'arrête sur cette case.
	  • Récompense ultra rare : l'Astrelune, animal exclusif (annonce sur TOUS les serveurs).
	    Elle arrive dans 🐾 Mes animaux (si c'est plein, elle attend dans data.PendingAnimals).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureUtil = require(ReplicatedStorage.Shared.CreatureUtil)
local CropUtil = require(ReplicatedStorage.Shared.CropUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)
local BoostService = require(script.Parent.BoostService)
local XPService = require(script.Parent.XPService)
local AnimalService = require(script.Parent.AnimalService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local ExpeditionService = require(script.Parent.ExpeditionService)

local WheelConfig = Config.Wheel

local WheelService = {}

local rng = Random.new()

local function sync(player: Player, data: { [string]: any })
	SyncService:Set(player, "Wheel", data.Wheel)
end

function WheelService:AddSpins(player: Player, amount: number): boolean
	local data = DataService:GetData(player)
	if not data then
		return false
	end
	data.Wheel.ExtraSpins = (data.Wheel.ExtraSpins or 0) + amount
	sync(player, data)
	return true
end

local function rollIndex(): number
	local total = 0
	for _, reward in WheelConfig.Rewards do
		total += reward.Weight
	end
	local roll = rng:NextNumber(0, total)
	for index, reward in WheelConfig.Rewards do
		roll -= reward.Weight
		if roll <= 0 then
			return index
		end
	end
	return 1
end

-- Livre les animaux en attente dans 🐾 Mes animaux s'il y a de la place
local function deliverPending(player: Player, data: { [string]: any }): boolean
	local delivered = false
	for i = #data.PendingAnimals, 1, -1 do
		local pending = data.PendingAnimals[i]
		if AnimalService:GiveAnimal(player, pending.Species, pending.Variant) then
			table.remove(data.PendingAnimals, i)
			delivered = true
		end
	end
	return delivered
end

-- Donne la récompense ; renvoie son texte
local function grant(player: Player, data: { [string]: any }, reward: { [string]: any }): string
	local level = data.Level or 1
	if reward.Kind == "Coins" then
		local amount = reward.Amount + (reward.PerLevel or 0) * level
		CurrencyService:AddCoins(player, amount, "Wheel")
		return ("💰 %s Coins"):format(Format.Number(amount))
	elseif reward.Kind == "XP" then
		local amount = reward.Amount + (reward.PerLevel or 0) * level
		XPService:AddXP(player, amount)
		return ("⭐ %s XP"):format(Format.Number(amount))
	elseif reward.Kind == "Seeds" then
		local added = InventoryService:AddSeeds(player, reward.Item, reward.Amount)
		return ("%d graine(s) %s"):format(added, CropUtil.Label(reward.Item))
	elseif reward.Kind == "Boost" then
		BoostService:Grant(player, reward.Boost, reward.Power, reward.Duration)
		local info = Config.Boosts.Types[reward.Boost]
		return ("%s Boost %s +%d %% (%s)"):format(info.Icon, info.DisplayName, math.floor(reward.Power * 100), Format.Time(reward.Duration))
	elseif reward.Kind == "Rations" then
		local pens = AnimalService:AddRationsAll(player, reward.Amount)
		if pens == 0 then
			-- Pas encore d'animaux : on compense en Coins
			CurrencyService:AddCoins(player, 2000, "WheelRations")
			return "🍽️ Rations (pas d'enclos : +2 000 Coins)"
		end
		return ("🍽️ +%d rations dans %d enclos"):format(reward.Amount, pens)
	elseif reward.Kind == "Item" then
		local variant = reward.Variant or "Normal"
		if InventoryService:AddItem(player, reward.Item, variant, reward.Amount) then
			return ("%d %s"):format(reward.Amount, ItemUtil.Label(reward.Item, variant))
		end
		local value = ItemUtil.UnitValue(reward.Item, variant) * reward.Amount
		CurrencyService:AddCoins(player, value, "WheelOverflow")
		return ("%s (sac plein : +%s Coins)"):format(ItemUtil.Label(reward.Item, variant), Format.Number(value))
	elseif reward.Kind == "Creature" then
		local creatureId = ExpeditionService:PickCreature(reward.Zone, Config.EggSettings.RarityWeightMultiplier)
		if creatureId then
			local mutationId = ExpeditionService:RollMutation()
			if ExpeditionService:GiveCreature(player, creatureId, mutationId) then
				local rarity = CreatureUtil.GetRarity(Config.Creatures[creatureId].Rarity)
				return ("📖 %s [%s]"):format(CreatureUtil.Label(creatureId, mutationId), rarity.DisplayName)
			end
			local value = CreatureUtil.GetValue(creatureId, mutationId)
			CurrencyService:AddCoins(player, value, "WheelCreatureOverflow")
			return ("📖 Créature (collection pleine : +%s Coins)"):format(Format.Number(value))
		end
		return "📖 Créature"
	elseif reward.Kind == "Animal" then
		local species = Config.Animals[reward.Species]
		if not AnimalService:GiveAnimal(player, reward.Species, reward.Variant or "Normal") then
			-- Inventaire plein : on la garde de côté, elle arrivera dès qu'il y a de la place
			table.insert(data.PendingAnimals, { Species = reward.Species, Variant = reward.Variant or "Normal" })
		end
		SyncService:Notify(player, ("%s %s t'attend dans 🐾 Mes animaux !"):format(species.Icon, species.DisplayName), "Rare")
		AnnouncementService:Announce(("🦄 %s a gagné l'animal EXCLUSIF %s à la roue !"):format(player.DisplayName, species.DisplayName), Color3.fromRGB(255, 120, 220), "Global")
		return ("%s %s, l'animal EXCLUSIF de la roue !"):format(species.Icon, species.DisplayName)
	end
	return "?"
end

local function onSpin(player: Player): { [string]: any }
	if not RemoteGuard.CheckCooldown(player, "SpinWheel", WheelConfig.SpinDuration) then
		return { Ok = false, Message = "La roue tourne encore !" }
	end
	local data = DataService:GetData(player)
	if not data then
		return { Ok = false, Message = "Données pas encore chargées." }
	end
	local now = os.time()
	local wheel = data.Wheel
	local freeReady = now >= (wheel.LastFree or 0) + WheelConfig.Cooldown
	if freeReady then
		wheel.LastFree = now
	elseif (wheel.ExtraSpins or 0) > 0 then
		wheel.ExtraSpins -= 1
	else
		return { Ok = false, Message = "Plus de tour gratuit : reviens plus tard, ou achète des tours 🎡." }
	end

	local index = rollIndex()
	local reward = WheelConfig.Rewards[index]
	local ok, text = pcall(grant, player, data, reward)
	if not ok then
		-- Erreur inattendue : on rend le tour pour que le joueur ne perde rien
		warn("[WheelService] Erreur de récompense : " .. tostring(text))
		wheel.ExtraSpins = (wheel.ExtraSpins or 0) + 1
		sync(player, data)
		return { Ok = false, Message = "Oups, réessaie (ton tour t'a été rendu)." }
	end
	sync(player, data)
	return { Ok = true, Index = index, Text = text, Jackpot = reward.Jackpot == true }
end

function WheelService:Init()
	DataService:OnProfileLoaded(function(player, data)
		if type(data.Wheel) ~= "table" then
			data.Wheel = { LastFree = 0, ExtraSpins = 0 }
		end
		if type(data.PendingAnimals) ~= "table" then
			data.PendingAnimals = {}
		end
		sync(player, data)
	end)
end

function WheelService:Start()
	Remotes.Get("SpinWheel").OnServerInvoke = onSpin
	-- Animaux gagnés en attente d'un enclos
	task.spawn(function()
		while true do
			task.wait(10)
			for _, player in Players:GetPlayers() do
				local data = DataService:GetData(player)
				if data and #data.PendingAnimals > 0 then
					deliverPending(player, data)
				end
			end
		end
	end)
end

return WheelService
