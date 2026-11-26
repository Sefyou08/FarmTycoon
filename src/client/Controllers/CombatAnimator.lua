--[[
	CombatAnimator.lua
	==================
	Animations du JOUEUR dans le donjon, entièrement côté client (aucun asset
	d'animation nécessaire : on anime les articulations du personnage).
	  • Épée simple (Parts) dans la main droite pendant le donjon.
	  • Combo de 3 coups si on attaque vite (Config.Combat.ComboWindow) :
	    1 = taille de droite à gauche, 2 = revers, 3 = coup vertical puissant.
	  • Esquive : roulade avant (rotation du bas du corps) + poussière.
	Fonctionne en R15 (épaule "RightShoulder", taille "Waist", racine "Root") et en R6
	("Right Shoulder", "RootJoint"). Le serveur décide toujours des dégâts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)

local CombatAnimator = {}

local Effects = Config.CombatEffects
local player = Players.LocalPlayer

local weapon: Model? = nil
local swingSound: Sound? = nil
local combo = 0
local lastAttack = 0

-- Animation en cours : { Motor, BaseC0, Start, Duration, Curve(t) -> CFrame }
local active: { [Motor6D]: { [string]: any } } = {}

local function findMotor(character: Model, names: { string }): Motor6D?
	for _, name in names do
		local motor = character:FindFirstChild(name, true)
		if motor and motor:IsA("Motor6D") then
			return motor
		end
	end
	return nil
end

-- Joue une courbe sur une articulation (C0 = base * courbe(t)), puis remet la pose
local function animate(motor: Motor6D?, duration: number, curve: (number) -> CFrame)
	if not motor then
		return
	end
	local current = active[motor]
	local base = if current then current.BaseC0 else motor.C0
	active[motor] = { Motor = motor, BaseC0 = base, Start = os.clock(), Duration = duration, Curve = curve }
end

local function easeOut(t: number): number
	return 1 - (1 - t) ^ 3
end

--------------------------------------------------------------------------
-- Arme
--------------------------------------------------------------------------

function CombatAnimator.EquipWeapon(equipped: boolean)
	if weapon then
		weapon:Destroy()
		weapon = nil
	end
	if not equipped then
		return
	end
	local character = player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "DungeonSword"
	local function part(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		-- L'épée sort du poing vers l'avant (-Z de la main), légèrement relevée
		local isR6 = hand.Name == "Right Arm"
		local grip = hand.CFrame * CFrame.new(0, if isR6 then -1 else -0.2, 0) * CFrame.Angles(math.rad(30), 0, 0)
		p.CFrame = grip * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
		return p
	end
	part("Handle", Vector3.new(0.3, 0.3, 1.2), CFrame.new(0, 0, 0), Color3.fromRGB(110, 70, 40), Enum.Material.Wood)
	part("Guard", Vector3.new(1.3, 0.25, 0.3), CFrame.new(0, 0, -0.65), Color3.fromRGB(230, 190, 70), Enum.Material.Metal)
	part("Blade", Vector3.new(0.3, 0.1, 3.6), CFrame.new(0, 0, -2.6), Color3.fromRGB(220, 230, 240), Enum.Material.Metal)
	model.Parent = character
	weapon = model

	swingSound = Instance.new("Sound")
	swingSound.SoundId = Effects.SwingSound
	swingSound.Volume = 0.5
	swingSound.Parent = model
	local equip = Instance.new("Sound")
	equip.SoundId = Effects.EquipSound
	equip.Volume = 0.5
	equip.Parent = model
	equip:Play()
end

--------------------------------------------------------------------------
-- Attaque (combo)
--------------------------------------------------------------------------

-- Trace lumineuse de l'épée devant le personnage
local function slashTrail(root: BasePart, comboIndex: number)
	local colors = { Color3.fromRGB(255, 245, 200), Color3.fromRGB(200, 230, 255), Color3.fromRGB(255, 200, 120) }
	local arc = Instance.new("Part")
	arc.Anchored = true
	arc.CanCollide = false
	arc.CanQuery = false
	arc.CanTouch = false
	arc.Material = Enum.Material.Neon
	arc.Color = colors[comboIndex]
	arc.Transparency = 0.35
	arc.Size = if comboIndex == 3 then Vector3.new(1.5, 7, 0.3) else Vector3.new(8, 0.3, 2)
	arc.CFrame = root.CFrame * CFrame.new(0, 0.3, -4) * CFrame.Angles(0, 0, if comboIndex == 2 then math.rad(-20) else math.rad(20))
	arc.Parent = Workspace
	Debris:AddItem(arc, 0.12)
end

-- Renvoie le numéro du coup dans le combo (1, 2 ou 3)
function CombatAnimator.Attack(): number
	local now = os.clock()
	combo = if now - lastAttack <= Config.Combat.ComboWindow then (combo % 3) + 1 else 1
	lastAttack = now

	local character = player.Character
	if not character then
		return combo
	end
	local shoulder = findMotor(character, { "RightShoulder", "Right Shoulder" })
	local waist = findMotor(character, { "Waist" })
	local root = character:FindFirstChild("HumanoidRootPart")

	if combo == 1 then
		-- Taille horizontale : le bras part de la droite vers la gauche, le buste tourne
		animate(shoulder, 0.28, function(t)
			local k = easeOut(t)
			return CFrame.Angles(math.rad(90), math.rad(-70 + 150 * k), 0)
		end)
		animate(waist, 0.28, function(t)
			return CFrame.Angles(0, math.rad(25 - 50 * easeOut(t)), 0)
		end)
	elseif combo == 2 then
		-- Revers : dans l'autre sens
		animate(shoulder, 0.28, function(t)
			local k = easeOut(t)
			return CFrame.Angles(math.rad(80), math.rad(80 - 150 * k), 0)
		end)
		animate(waist, 0.28, function(t)
			return CFrame.Angles(0, math.rad(-25 + 50 * easeOut(t)), 0)
		end)
	else
		-- Coup vertical puissant : bras levé puis abattu
		animate(shoulder, 0.36, function(t)
			local angle = if t < 0.35 then 170 * (t / 0.35) else 170 - 150 * easeOut((t - 0.35) / 0.65)
			return CFrame.Angles(math.rad(angle), 0, 0)
		end)
		animate(waist, 0.36, function(t)
			return CFrame.Angles(math.rad(-15 * math.sin(t * math.pi)), 0, 0)
		end)
	end
	if swingSound then
		swingSound.PlaybackSpeed = 0.9 + combo * 0.1
		swingSound:Play()
	end
	if root and root:IsA("BasePart") then
		task.delay(0.08, function()
			slashTrail(root, combo)
		end)
	end
	return combo
end

--------------------------------------------------------------------------
-- Esquive (roulade)
--------------------------------------------------------------------------

function CombatAnimator.Roll()
	local character = player.Character
	if not character then
		return
	end
	-- R15 : articulation "Root" (bas du corps) ; R6 : "RootJoint"
	local rootMotor = findMotor(character, { "Root", "RootJoint" })
	local isR6 = rootMotor ~= nil and rootMotor.Name == "RootJoint"
	animate(rootMotor, 0.4, function(t)
		local angle = -360 * easeOut(t)
		return if isR6 then CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, 0) else CFrame.Angles(math.rad(angle), 0, 0)
	end)

	-- Petit nuage de poussière aux pieds
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(0, -2.5, 0)
		attachment.Parent = root
		local dust = Instance.new("ParticleEmitter")
		dust.Enabled = false
		dust.Color = ColorSequence.new(Color3.fromRGB(200, 190, 170))
		dust.Lifetime = NumberRange.new(0.3, 0.5)
		dust.Speed = NumberRange.new(4, 8)
		dust.SpreadAngle = Vector2.new(80, 20)
		dust.Size = NumberSequence.new(0.8, 0)
		dust.Transparency = NumberSequence.new(0.3, 1)
		dust.Parent = attachment
		dust:Emit(10)
		Debris:AddItem(attachment, 0.6)
	end
end

function CombatAnimator.Init()
	-- Une seule boucle : applique les courbes en cours, puis remet les poses d'origine
	RunService.RenderStepped:Connect(function()
		if next(active) == nil then
			return
		end
		local now = os.clock()
		for motor, anim in active do
			local t = (now - anim.Start) / anim.Duration
			if not motor.Parent or t >= 1 then
				if motor.Parent then
					motor.C0 = anim.BaseC0
				end
				active[motor] = nil
			else
				motor.C0 = anim.BaseC0 * anim.Curve(t)
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		table.clear(active)
		weapon = nil
	end)
end

return CombatAnimator
