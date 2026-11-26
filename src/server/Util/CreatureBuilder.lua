--[[
	CreatureBuilder.lua
	===================
	Construit le modèle d'une créature en Parts simples (corps, yeux, détails)
	à partir de Config.Creatures, avec l'effet de sa mutation :
	  Dorée (couleur or), Géante (taille x2), Arc-en-ciel (couleurs animées par
	  le client), Spectrale (translucide et lumineuse).
	Réutilisé pour les socles d'exposition et la vitrine.

	Taille et éclat selon la rareté (Config.CreatureRarities[x].Visual) : les
	Légendaires, Mythiques, Secrètes et Divines sont plus grandes, plus vives, avec
	plus de particules et de lumière.

	REMPLACER UN MODÈLE (Toolbox / MeshPart importé), créature par créature :
	  1. crée dans ServerStorage un dossier "CustomModels", puis un dossier "Creatures" dedans ;
	  2. mets-y un Model nommé EXACTEMENT comme l'id de la créature (ex. "Pharaonix"),
	     tourné vers -Z (l'avant du modèle), pieds au niveau de son pivot ;
	  3. c'est tout : ce modèle sera cloné à la place du modèle généré (taille de rareté,
	     mutation Géante et lumières de rareté appliquées par-dessus).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

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

-- Couleur plus saturée et plus lumineuse (raretés hautes)
local function vivid(color: Color3): Color3
	local h, sat, v = color:ToHSV()
	return Color3.fromHSV(h, math.min(1, sat * 1.35 + 0.15), math.min(1, v * 1.1 + 0.05))
end

-- Lumière + particules aux couleurs de la rareté
local function addRarityEffects(body: BasePart, rarity: any, accent: Color3)
	local visual = rarity.Visual or {}
	if (visual.Light or 0) > 0 then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = visual.Light
		light.Brightness = 2
		light.Parent = body
	end
	if (visual.Particles or 0) > 0 then
		local particles = Instance.new("ParticleEmitter")
		particles.Name = "RarityParticles"
		particles.Color = ColorSequence.new(rarity.Color, accent)
		particles.LightEmission = 1
		particles.Rate = visual.Particles
		particles.Lifetime = NumberRange.new(1, 1.8)
		particles.Speed = NumberRange.new(0.8, 2)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Size = NumberSequence.new(0.45, 0)
		particles.Parent = body
	end
end

-- Taille finale = taille de la rareté x mutation Géante ; le pivot reste au sol
local function applyScale(model: Model, groundCFrame: CFrame, rarity: any, mutation: any)
	local scale = ((rarity.Visual and rarity.Visual.Scale) or 1) * (mutation.Scale or 1)
	if scale ~= 1 then
		model.WorldPivot = groundCFrame
		model:ScaleTo(scale)
	end
end

-- Modèle de remplacement fourni à la main (ServerStorage.CustomModels.Creatures.<id>), sinon nil
local function customModel(creatureId: string): Model?
	local folder = ServerStorage:FindFirstChild("CustomModels")
	local creatures = folder and folder:FindFirstChild("Creatures")
	local template = creatures and creatures:FindFirstChild(creatureId)
	if template and template:IsA("Model") then
		return template:Clone()
	end
	return nil
end

-- Renvoie (model, bodyPart). groundCFrame = position au sol, regard vers -Z.
function CreatureBuilder.Build(creatureId: string, mutationId: string, groundCFrame: CFrame): (Model, Part)
	local def = Config.Creatures[creatureId]
	local mutation = CreatureUtil.GetMutation(mutationId)
	local rarity = CreatureUtil.GetRarity(def.Rarity)

	-- 1. Modèle importé (Toolbox / MeshPart) s'il existe
	local custom = customModel(creatureId)
	if custom then
		custom.Name = creatureId
		custom.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local body = custom.PrimaryPart or custom:FindFirstChildWhichIsA("BasePart", true)
		custom.PrimaryPart = body
		for _, descendant in custom:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = descendant == body
			end
		end
		custom:PivotTo(groundCFrame)
		addRarityEffects(body :: BasePart, rarity, def.Accent)
		applyScale(custom, groundCFrame, rarity, mutation)
		return custom, body :: Part
	end

	-- 2. Sinon : modèle généré en Parts
	local model = Instance.new("Model")
	model.Name = creatureId
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local s = def.Size
	local isVivid = rarity.Visual and rarity.Visual.Vivid
	local baseColor = if isVivid then vivid(def.Color) else def.Color
	local baseAccent = if isVivid then vivid(def.Accent) else def.Accent
	local color = if mutation.Gold then mutation.Color else baseColor
	local accent = if mutation.Gold then Color3.fromRGB(255, 240, 150) else baseAccent

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

	-- Divine : auréole dorée au-dessus de la tête, lumière intense, pluie d'étincelles
	if rarity.Divine then
		local haloRadius = s * 0.45
		local haloCenter = CFrame.new(0, top + s * 0.5, front * 0.2)
		for i = 1, 12 do
			local angle = i / 12 * math.pi * 2
			part("Halo", Enum.PartType.Block, Vector3.new(s * 0.26, s * 0.07, s * 0.1), haloCenter * CFrame.new(math.cos(angle) * haloRadius, 0, math.sin(angle) * haloRadius) * CFrame.Angles(0, -angle, 0), Color3.fromRGB(255, 225, 90), true).Material = Enum.Material.Neon
		end
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 235, 150)
		glow.Range = 24
		glow.Brightness = 3
		glow.Parent = body
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 255, 255))
		sparkles.LightEmission = 1
		sparkles.Rate = 25
		sparkles.Lifetime = NumberRange.new(1.2, 2)
		sparkles.Speed = NumberRange.new(1, 3)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.5, 0)
		sparkles.Parent = body
	end

	-- Éclat de la rareté, puis taille (rareté x mutation Géante)
	addRarityEffects(body, rarity, accent)
	applyScale(model, groundCFrame, rarity, mutation)

	return model, body
end

return CreatureBuilder
