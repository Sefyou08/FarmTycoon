--[[
	MovementController.lua
	======================
	Sprint : maintenir Maj (gauche ou droite) pour courir à Config.Movement.SprintSpeed.
	Sur mobile/tablette, un bouton "🏃 Courir" dans le HUD active/désactive le sprint.
	Monture : bouton "🐴 Monture" (le serveur vérifie et pose l'attribut "Mounted") ;
	à cheval, les vitesses sont MountSpeed / MountSprintSpeed.
	Boost de vitesse (consommables) : attribut "SpeedBoost" posé par le serveur (x1,2...).

	Note : si un joueur a activé le "Shift Lock" dans ses paramètres Roblox,
	Maj sert aussi à verrouiller la caméra (comportement normal de Roblox).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MovementController = {}

local player = Players.LocalPlayer
local MovementConfig = Config.Movement

local sprinting = false
local toggleButton: TextButton? = nil

local function isSprintKey(keyCode: Enum.KeyCode): boolean
	for _, key in MovementConfig.SprintKeys do
		if key == keyCode then
			return true
		end
	end
	return false
end

local function apply()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local mounted = player:GetAttribute("Mounted") == true
		local walk = if mounted then MovementConfig.MountSpeed else MovementConfig.WalkSpeed
		local sprint = if mounted then MovementConfig.MountSprintSpeed else MovementConfig.SprintSpeed
		local boost = player:GetAttribute("SpeedBoost") or 1
		humanoid.WalkSpeed = (if sprinting then sprint else walk) * boost
	end
	if toggleButton then
		toggleButton.Text = if sprinting then "🏃 Courir : ON" else "🏃 Courir"
	end
end

local function setSprinting(value: boolean)
	if not MovementConfig.SprintEnabled then
		value = false
	end
	if sprinting ~= value then
		sprinting = value
		apply()
	end
end

function MovementController.Init(HUD)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- gameProcessed = le joueur écrit dans le chat ou une zone de texte
		if not gameProcessed and isSprintKey(input.KeyCode) then
			setSprinting(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isSprintKey(input.KeyCode) then
			setSprinting(false)
		end
	end)

	-- Bouton tactile (mobile / tablette)
	if MovementConfig.SprintEnabled and UserInputService.TouchEnabled then
		toggleButton = HUD.AddButton("SprintButton", "🏃 Courir", Color3.fromRGB(200, 120, 60), 10, function()
			setSprinting(not sprinting)
		end)
	end

	-- Monture
	local mountRemote: RemoteEvent = Remotes.Get("ToggleMount")
	HUD.AddButton("MountButton", "🐴 Monture", Color3.fromRGB(150, 100, 60), 9, function()
		mountRemote:FireServer()
	end)
	player:GetAttributeChangedSignal("Mounted"):Connect(apply)
	player:GetAttributeChangedSignal("SpeedBoost"):Connect(apply)

	-- Réapplique la vitesse à chaque réapparition (le serveur remet la vitesse de base)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			task.wait(0.5) -- laisse la vitesse de base du serveur arriver d'abord
			apply()
		end
	end)
	apply()
end

return MovementController
