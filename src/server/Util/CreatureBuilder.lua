--[[
	CreatureBuilder.lua
	===================
	Construit le modèle d'une créature en Parts simples (corps, yeux, détails)
	à partir de Config.Creatures, avec l'effet de sa mutation :
	  Dorée (couleur or), Géante (taille x2), Arc-en-ciel (couleurs animées par
	  le client), Spectrale (translucide et lumineuse).
	Réutilisé en phase 6 pour les socles d'exposition.
	Pour mettre de vrais modèles plus tard : remplace seulement ce fichier.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureUtil = require(ReplicatedStorage.Shared.CreatureUtil)

local CreatureBuilder = {}

local RAINBOW_TAG = "RainbowPart" -- animé par le client (AnimalController)

local function hasFeature(def: any, feature: string): boolean
	for _, f in def.Features do
		if f == feature then
			return true
		end
	end
	return false
end

-- Renvoie (model, bodyPart). groundCFrame = position au sol, regard vers -Z.
function CreatureBuilder.Build(creatureId: string, mutationId: string, groundCFrame: CFrame): (Model, Part)
	local def = Config.Creatures[creatureId]
	local mutation = CreatureUtil.GetMutation(mutationId)

	local model = Instance.new("Model")
	model.Name = creatureId
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local s = def.Size
	local color = if mutation.Gold then mutation.Color else def.Color
	local accent = if mutation.Gold then Color3.fromRGB(255, 240, 150) else def.Accent

	local function part(name: string, shape: Enum.PartType, size: Vector3, offset: CFrame, partColor: Color3, keepColor: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = name == "Body" -- seul le corps est "cliquable" (prompt)
		p.CFrame = groundCFrame * offset
		p.Color = partColor
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if mutation.Gold then
			p.Reflectance = 0.25
		end
		if mutation.Spectral then
			p.Transparency = 0.45
			p.Material = Enum.Material.Neon
		end
		if mutation.Rainbow and not keepColor then
			p:SetAttribute("HueOffset", math.random())
			CollectionService:AddTag(p, RAINBOW_TAG)
		end
		p.Parent = model
		return p
	end

	-- Corps
	local legs = hasFeature(def, "Legs")
	local legHeight = if legs then s * 0.35 else 0
	local bodySize = if def.Body == "Ball" then Vector3.new(s, s, s) else Vector3.new(s * 0.9, s * 0.75, s * 1.25)
	local bodyY = legHeight + bodySize.Y / 2
	local body = part("Body", if def.Body == "Ball" then Enum.PartType.Ball else Enum.PartType.Block, bodySize, CFrame.new(0, bodyY, 0), color)
	model.PrimaryPart = body

	local top = bodyY + bodySize.Y / 2
	local front = -bodySize.Z / 2

	-- Yeux (toujours) : blanc + pupille noire, à l'avant (-Z)
	for _, sx in { -1, 1 } do
		local eyeY = bodyY + bodySize.Y * 0.15
		local eyeZ = front + s * 0.06
		part("Eye", Enum.PartType.Ball, Vector3.one * s * 0.28, CFrame.new(sx * s * 0.2, eyeY, eyeZ), Color3.new(1, 1, 1), true)
		part("Pupil", Enum.PartType.Ball, Vector3.one * s * 0.14, CFrame.new(sx * s * 0.2, eyeY, eyeZ - s * 0.12), Color3.fromRGB(20, 20, 30), true)
	end

	-- Détails
	if legs then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part("Leg", Enum.PartType.Block, Vector3.new(s * 0.2, legHeight, s * 0.2), CFrame.new(sx * bodySize.X * 0.32, legHeight / 2, sz * bodySize.Z * 0.32), color:Lerp(Color3.new(0, 0, 0), 0.2))
			end
		end
	end
	if hasFeature(def, "Ears") then
		for _, sx in { -1, 1 } do
			part("Ear", Enum.PartType.Block, Vector3.new(s * 0.22, s * 0.4, s * 0.12), CFrame.new(sx * s * 0.28, top + s * 0.12, front * 0.3) * CFrame.Angles(0, 0, sx * math.rad(-15)), accent)
		end
	end
	if hasFeature(def, "Horns") then
		for _, sx in { -1, 1 } do
			part("Horn", Enum.PartType.Cylinder, Vector3.new(s * 0.5, s * 0.12, s * 0.12), CFrame.new(sx * s * 0.25, top + s * 0.15, front * 0.4) * CFrame.Angles(0, 0, math.rad(90 + sx * 25)), accent)
		end
	end
	if hasFeature(def, "Wings") then
		for _, sx in { -1, 1 } do
			part("Wing", Enum.PartType.Block, Vector3.new(s * 0.9, s * 0.08, s * 0.6), CFrame.new(sx * (bodySize.X / 2 + s * 0.35), bodyY + s * 0.15, 0) * CFrame.Angles(0, 0, sx * math.rad(20)), accent)
		end
	end
	if hasFeature(def, "Tail") then
		part("Tail", Enum.PartType.Block, Vector3.new(s * 0.18, s * 0.18, s * 0.8), CFrame.new(0, bodyY + s * 0.1, bodySize.Z / 2 + s * 0.3) * CFrame.Angles(math.rad(25), 0, 0), accent)
	end
	if hasFeature(def, "Leaf") then
		part("Leaf", Enum.PartType.Block, Vector3.new(s * 0.5, s * 0.06, s * 0.3), CFrame.new(0, top + s * 0.08, 0) * CFrame.Angles(0, math.rad(30), math.rad(10)), Color3.fromRGB(80, 200, 70), true)
	end
	if hasFeature(def, "Hat") then
		part("Hat", Enum.PartType.Ball, Vector3.one * s * 1.1, CFrame.new(0, top - s * 0.05, 0), accent)
		if hasFeature(def, "Spots") then
			for i = 1, 3 do
				local angle = i * math.pi * 2 / 3
				part("Spot", Enum.PartType.Ball, Vector3.one * s * 0.18, CFrame.new(math.cos(angle) * s * 0.3, top + s * 0.4, math.sin(angle) * s * 0.3), Color3.new(1, 1, 1), true)
			end
		end
	end
	if hasFeature(def, "Spikes") then
		for i = -1, 1 do
			part("Spike", Enum.PartType.Block, Vector3.new(s * 0.12, s * 0.35, s * 0.25), CFrame.new(0, top + s * 0.1, i * bodySize.Z * 0.25) * CFrame.Angles(math.rad(-20), 0, 0), accent)
		end
	end

	-- Lueur (créatures "Glow", et mutation Spectrale)
	if hasFeature(def, "Glow") or mutation.Spectral or mutation.Gold then
		local light = Instance.new("PointLight")
		light.Color = if mutation.Gold then mutation.Color else accent
		light.Range = 8 + s
		light.Brightness = 1.5
		light.Parent = body

		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(light.Color)
		particles.LightEmission = 1
		particles.Rate = 5
		particles.Lifetime = NumberRange.new(0.8, 1.4)
		particles.Speed = NumberRange.new(0.5, 1.2)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Size = NumberSequence.new(0.3, 0)
		particles.Parent = body
	end

	-- Géante : on agrandit tout le modèle autour de son pivot (au sol)
	if mutation.Scale and mutation.Scale ~= 1 then
		model.WorldPivot = groundCFrame
		model:ScaleTo(mutation.Scale)
	end

	return model, body
end

return CreatureBuilder
