--[[
	MovementController.lua
	======================
	Sprint : maintenir Maj (gauche ou droite) pour courir à Config.Movement.SprintSpeed.
	Sur mobile/tablette, un bouton "🏃 Courir" dans le HUD active/désactive le sprint.

	Note : si un joueur a activé le "Shift Lock" dans ses paramètres Roblox,
	Maj sert aussi à verrouiller la caméra (comportement normal de Roblox).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

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
		humanoid.WalkSpeed = if sprinting then MovementConfig.SprintSpeed else MovementConfig.WalkSpeed
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
