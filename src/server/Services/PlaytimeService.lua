--[[
	PlaytimeService.lua
	===================
	Récompenses de temps de jeu (Config.Playtime) : à réclamer après 15 min, 30 min, 1 h
	et 2 h de jeu dans la SESSION en cours (le compteur repart à chaque connexion).
	  • L'heure d'arrivée est notée par le serveur ; le client ne fait qu'afficher le minuteur.
	  • RemoteFunction "ClaimPlaytime" (index) : le serveur vérifie le temps écoulé et que la
	    récompense n'a pas déjà été réclamée dans cette session.
	  • État synchronisé "Playtime" = { Start = os.time() d'arrivée, Claimed = { [index] = true } }.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local TutorialService = require(script.Parent.TutorialService)

local Rewards = Config.Playtime.Rewards

local PlaytimeService = {}

local sessions: { [Player]: { Start: number, Claimed: { [number]: boolean } } } = {}

local function sync(player: Player)
	local session = sessions[player]
	if session then
		-- Clés en texte : une table à trous ne passe pas bien sur le réseau
		local claimed = {}
		for index in session.Claimed do
			claimed[tostring(index)] = true
		end
		SyncService:Set(player, "Playtime", { Start = session.Start, Claimed = claimed })
	end
end

local function onClaim(player: Player, index: any): (boolean, string)
	if not RemoteGuard.CheckCooldown(player, "ClaimPlaytime", 0.5) then
		return false, "Doucement !"
	end
	local session = sessions[player]
	local reward = type(index) == "number" and Rewards[index]
	if not session or not reward then
		return false, "Récompense inconnue."
	end
	if session.Claimed[index] then
		return false, "Déjà réclamée."
	end
	local remaining = session.Start + reward.Minutes * 60 - os.time()
	if remaining > 0 then
		return false, ("Encore %d min de jeu !"):format(math.ceil(remaining / 60))
	end
	session.Claimed[index] = true
	local text = TutorialService:GrantReward(player, reward.Reward)
	sync(player)
	return true, ("🎁 Récompense de %d min : %s"):format(reward.Minutes, text)
end

function PlaytimeService:Init()
	DataService:OnProfileLoaded(function(player)
		sessions[player] = { Start = os.time(), Claimed = {} }
		sync(player)
	end)
end

function PlaytimeService:Start()
	Remotes.Get("ClaimPlaytime").OnServerInvoke = onClaim
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return PlaytimeService
