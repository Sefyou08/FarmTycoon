--[[
	SyncService.lua
	===============
	Fait le lien entre les données serveur et l'affichage client.

	  SyncService:Set(player, "Coins", 150)       -> le client met à jour son HUD
	  SyncService:Notify(player, "+150 Coins", "Success")

	Le client peut aussi demander l'état complet via la RemoteFunction GetState
	(au démarrage). Il ne peut RIEN modifier : il reçoit seulement des copies.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local SyncService = {}

local stateChangedRemote: RemoteEvent
local notifyRemote: RemoteEvent

-- Types de notification reconnus par le client : "Info" | "Success" | "Error" | "Rare" | "Mutation"
function SyncService:Notify(player: Player, text: string, kind: string?)
	notifyRemote:FireClient(player, text, kind or "Info")
end

function SyncService:NotifyAll(text: string, kind: string?)
	notifyRemote:FireAllClients(text, kind or "Info")
end

-- Envoie une valeur (déjà modifiée côté serveur) au client.
function SyncService:Set(player: Player, key: string, value: any)
	stateChangedRemote:FireClient(player, key, value)
end

function SyncService:Init()
	stateChangedRemote = Remotes.Get("StateChanged")
	notifyRemote = Remotes.Get("Notify")

	-- Renvoie une copie des données (la sérialisation réseau copie de toute façon).
	Remotes.Get("GetState").OnServerInvoke = function(player: Player)
		return DataService:GetData(player) -- nil tant que les données ne sont pas chargées
	end
end

function SyncService:Start() end

return SyncService
