--[[
	TutorialService.lua
	===================
	Tutoriel des nouveaux joueurs : une suite de quêtes (Config.Tutorial.Quests).
	  • data.Tutorial = { Step, Skipped, Rewarded = { [idQuête] = true } } (sauvegardé).
	  • Une quête est validée quand le joueur fait l'action (GameEvents, signalés par les
	    services) ou si c'est déjà fait (Check). Chaque quête donne sa récompense UNE fois.
	  • RemoteFunction "TutorialAction" : ("Skip") passer, ("Restart") recommencer
	    (les récompenses déjà reçues ne sont pas redonnées).
	  • Le client affiche l'objectif en haut de l'écran et une flèche vers la cible
	    (TutorialController), à partir de l'état "Tutorial" synchronisé.

	API : TutorialService:GrantReward(player, reward) -> texte (utilisé aussi par PlaytimeService)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RewardUtil = require(ReplicatedStorage.Shared.RewardUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local GameEvents = require(script.Parent.Parent.Util.GameEvents)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)
local BoostService = require(script.Parent.BoostService)
local XPService = require(script.Parent.XPService)
local WheelService = require(script.Parent.WheelService)

local Quests = Config.Tutorial.Quests

local TutorialService = {}

-- Donne une récompense ; renvoie son texte
function TutorialService:GrantReward(player: Player, reward: { [string]: any }): string
	local data = DataService:GetData(player)
	if not data or not reward then
		return ""
	end
	local coins = RewardUtil.Coins(reward, data.Level or 1)
	if coins > 0 then
		CurrencyService:AddCoins(player, coins, "Reward")
	end
	if reward.XP then
		XPService:AddXP(player, reward.XP)
	end
	if reward.Seeds then
		InventoryService:AddSeeds(player, reward.Seeds.Id, reward.Seeds.Amount)
	end
	if reward.Item then
		InventoryService:AddItem(player, reward.Item.Id, "Normal", reward.Item.Amount)
	end
	if reward.Boost then
		BoostService:Grant(player, reward.Boost.Type, reward.Boost.Power, reward.Boost.Duration)
	end
	if reward.WheelSpins then
		WheelService:AddSpins(player, reward.WheelSpins)
	end
	return RewardUtil.Describe(reward, data.Level or 1)
end

local function sync(player: Player, data: { [string]: any })
	SyncService:Set(player, "Tutorial", data.Tutorial)
end

-- La quête est-elle déjà accomplie (état actuel des données) ?
local function isAlreadyDone(data: { [string]: any }, quest: any): boolean
	local check = quest.Check
	if check == "HasPen" then
		for _, pen in data.Pens do
			if pen.Placed then
				return true
			end
		end
	elseif check == "HasAnimal" then
		if #(data.AnimalInventory or {}) > 0 then
			return true
		end
		for _, pen in data.Pens do
			if #pen.Animals > 0 then
				return true
			end
		end
	elseif check == "HasAnimalInPen" then
		for _, pen in data.Pens do
			if pen.Placed and #pen.Animals > 0 then
				return true
			end
		end
	elseif check == "HasBuilding" then
		local building = data.Buildings and data.Buildings[quest.Arg]
		return building ~= nil and building.Placed == true
	elseif check == "HasPedestal" then
		for _, pedestal in data.Pedestals or {} do
			if pedestal.Placed then
				return true
			end
		end
	elseif check == "HasExhibit" then
		for _, pedestal in data.Pedestals or {} do
			if pedestal.Creature then
				return true
			end
		end
	end
	return false
end

-- Valide la quête en cours, puis passe les suivantes déjà accomplies
local function complete(player: Player, data: { [string]: any })
	local tutorial = data.Tutorial
	while tutorial.Step <= #Quests do
		local quest = Quests[tutorial.Step]
		local text = ""
		if not tutorial.Rewarded[quest.Id] then
			tutorial.Rewarded[quest.Id] = true
			text = TutorialService:GrantReward(player, quest.Reward)
		end
		tutorial.Step += 1
		SyncService:Notify(player, ("✅ Quête réussie !%s"):format(if text ~= "" then " " .. text else ""), "Success")
		local nextQuest = Quests[tutorial.Step]
		if not nextQuest or not isAlreadyDone(data, nextQuest) then
			break
		end
	end
	if tutorial.Step > #Quests and not tutorial.Rewarded.Final then
		tutorial.Rewarded.Final = true
		local text = TutorialService:GrantReward(player, Config.Tutorial.FinalReward)
		SyncService:Notify(player, "🎉 Tutoriel terminé, bravo ! " .. text, "Rare")
	end
	sync(player, data)
end

local function onGameEvent(player: Player, name: string, arg: any)
	local data = DataService:GetData(player)
	if not data or not data.Tutorial or data.Tutorial.Skipped then
		return
	end
	local quest = Quests[data.Tutorial.Step]
	if quest and quest.Event == name and (quest.Arg == nil or quest.Arg == arg) then
		complete(player, data)
	end
end

local function onTutorialAction(player: Player, action: any): (boolean, string)
	if not RemoteGuard.CheckCooldown(player, "TutorialAction", 1) then
		return false, "Doucement !"
	end
	local data = DataService:GetData(player)
	if not data then
		return false, "Données pas encore chargées."
	end
	if action == "Skip" then
		data.Tutorial.Skipped = true
		sync(player, data)
		return true, "Tutoriel passé. Tu peux le relancer depuis ❓ Guide."
	elseif action == "Restart" then
		data.Tutorial.Skipped = false
		data.Tutorial.Step = 1
		if isAlreadyDone(data, Quests[1]) then
			complete(player, data)
		end
		sync(player, data)
		return true, "🎯 Tutoriel relancé ! (les récompenses déjà reçues ne sont pas redonnées)"
	end
	return false, "Action inconnue."
end

function TutorialService:Init()
	DataService:OnProfileLoaded(function(player, data)
		if type(data.Tutorial) ~= "table" then
			data.Tutorial = { Step = 1, Skipped = false, Rewarded = {} }
		end
		data.Tutorial.Rewarded = data.Tutorial.Rewarded or {}
		data.Tutorial.Step = math.clamp(tonumber(data.Tutorial.Step) or 1, 1, #Quests + 1)
		-- Quête en cours déjà accomplie (anciens joueurs) : validée tout de suite
		local quest = Quests[data.Tutorial.Step]
		if quest and not data.Tutorial.Skipped and isAlreadyDone(data, quest) then
			complete(player, data)
		end
		sync(player, data)
	end)
	GameEvents.Connect(onGameEvent)
end

function TutorialService:Start()
	Remotes.Get("TutorialAction").OnServerInvoke = onTutorialAction
end

return TutorialService
