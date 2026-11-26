--[[
	StateController.lua
	===================
	Copie LOCALE (lecture seule) des données du joueur, pour l'affichage.
	Le serveur reste la seule source de vérité : modifier cette table côté
	client ne change rien au vrai solde.

	  StateController.Get("Coins")
	  StateController.Changed:Connect(function(key, value) ... end)
	     key = "*" quand l'état complet vient d'être reçu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local StateController = {}

local data: { [string]: any }? = nil
-- Valeurs reçues AVANT l'état complet (ex. SelectedSeed, qui n'est pas dans la sauvegarde)
local pending: { [string]: any } = {}
local changedEvent = Instance.new("BindableEvent")
StateController.Changed = changedEvent.Event

function StateController.Get(key: string): any
	return data and data[key]
end

function StateController.IsReady(): boolean
	return data ~= nil
end

function StateController.Init()
	Remotes.Get("StateChanged").OnClientEvent:Connect(function(key: string, value: any)
		if data then
			data[key] = value
		else
			pending[key] = value
		end
		changedEvent:Fire(key, value)
	end)

	-- Récupère l'état complet (réessaie tant que le serveur n'a pas fini de charger)
	task.spawn(function()
		local getState: RemoteFunction = Remotes.Get("GetState")
		while not data do
			local ok, result = pcall(function()
				return getState:InvokeServer()
			end)
			if ok and type(result) == "table" then
				-- L'état complet est plus récent : on ne garde que les clés qu'il ne contient pas
				for key, value in pending do
					if result[key] == nil then
						result[key] = value
					end
				end
				pending = {}
				data = result
				changedEvent:Fire("*", result)
				break
			end
			task.wait(1)
		end
	end)
end

return StateController
