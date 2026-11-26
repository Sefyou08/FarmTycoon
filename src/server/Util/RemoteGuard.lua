--[[
	RemoteGuard.lua
	===============
	Outils anti-triche pour valider les requêtes venant des clients.

	Règle d'or : on ne fait JAMAIS confiance au client.
	Chaque OnServerEvent / OnServerInvoke doit :
	  1. vérifier le type des arguments (un exploiteur peut envoyer n'importe quoi) ;
	  2. vérifier un cooldown (anti-spam) ;
	  3. vérifier la distance si l'action concerne un objet du monde.
]]

local Players = game:GetService("Players")

local RemoteGuard = {}

-- lastCalls[player][action] = os.clock() du dernier appel accepté
local lastCalls: { [Player]: { [string]: number } } = {}

-- Renvoie true si l'action est autorisée (et enregistre l'appel), false si trop tôt.
function RemoteGuard.CheckCooldown(player: Player, action: string, cooldown: number): boolean
	local now = os.clock()
	local calls = lastCalls[player]
	if not calls then
		calls = {}
		lastCalls[player] = calls
	end

	local last = calls[action]
	if last and now - last < cooldown then
		return false
	end

	calls[action] = now
	return true
end

-- Renvoie true si le personnage du joueur est à moins de maxDistance studs de position.
function RemoteGuard.IsNear(player: Player, position: Vector3, maxDistance: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - position).Magnitude <= maxDistance
end

-- Nombre fini, non-NaN, éventuellement entier et dans [min, max].
function RemoteGuard.IsValidNumber(value: any, min: number?, max: number?, integer: boolean?): boolean
	if typeof(value) ~= "number" then
		return false
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return false -- NaN ou infini
	end
	if integer and value % 1 ~= 0 then
		return false
	end
	if min and value < min then
		return false
	end
	if max and value > max then
		return false
	end
	return true
end

-- Chaîne non vide et de taille raisonnable.
function RemoteGuard.IsValidString(value: any, maxLength: number?): boolean
	return typeof(value) == "string" and #value > 0 and #value <= (maxLength or 64)
end

Players.PlayerRemoving:Connect(function(player)
	lastCalls[player] = nil
end)

return RemoteGuard
