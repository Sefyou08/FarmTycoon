--[[
	MovementService.lua
	===================
	Applique la vitesse de marche de base (Config.Movement.WalkSpeed) à chaque
	personnage qui apparaît. Le sprint (touche Maj) est géré par le client
	(MovementController) : c'est purement du confort de déplacement.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MovementService = {}

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.WalkSpeed = Config.Movement.WalkSpeed
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

function MovementService:Init() end

function MovementService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return MovementService
