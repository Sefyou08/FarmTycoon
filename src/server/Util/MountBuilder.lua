--[[
	MountBuilder.lua
	================
	Construit un cheval MONTABLE en Parts, articulé avec des Motor6D pour que les
	clients puissent l'animer (pattes qui bougent, tête qui hoche) :
	  Body (racine) -> LegFL / LegFR / LegBL / LegBR, Neck -> Head, Tail, Saddle.
	Effets de variante : Doré (or brillant), Arc-en-ciel (couleurs animées par le
	client), Légendaire / Mythique (aura + particules). Toutes les parts sont
	sans masse et sans collision : c'est le personnage qui porte la physique.

	Le modèle est tagué "MountModel" ; ses attributs :
	  OwnerUserId, LegHeight (pour l'animation client), Species, Variant.
	Remplacer par un vrai modèle (phase 10) : seul ce fichier change, en gardant les
	noms des Motor6D (LegFL, LegFR, LegBL, LegBR, Neck).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)

local MountBuilder = {}

local RAINBOW_TAG = "RainbowPart"
local MOUNT_TAG = "MountModel"

-- Renvoie (model, body). Le modèle est construit à l'origine ; l'appelant le soude au joueur.
function MountBuilder.Build(speciesId: string, variantId: string): (Model, Part)
	local species = Config.Animals[speciesId] or Config.Animals.Horse
	local variant = ItemUtil.GetVariant(variantId)
	local model = Instance.new("Model")
	model.Name = "Mount"

	local body, head, leg = species.BodySize, species.HeadSize, species.LegHeight
	local bodyColor = if variant.Gold then variant.Color else species.Color
	local headColor = if variant.Gold then variant.Color else (species.HeadColor or species.Color)
	local maneColor = species.Mane or Color3.fromRGB(40, 30, 25)

	local function part(name: string, size: Vector3, color: Color3, rainbow: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = if variant.Gold then 0.25 else 0
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if variant.Rainbow and rainbow ~= false then
			p:SetAttribute("HueOffset", math.random())
			CollectionService:AddTag(p, RAINBOW_TAG)
		end
		p.Parent = model
		return p
	end

	-- Articulation : enfant attaché au parent, C0 = point d'attache dans le parent,
	-- C1 = point d'attache dans l'enfant
	local function joint(name: string, parent: BasePart, child: BasePart, c0: CFrame, c1: CFrame)
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = parent
		motor.Part1 = child
		motor.C0 = c0
		motor.C1 = c1
		motor.Parent = parent
	end

	-- Corps (racine) : son centre est à LegHeight + BodySize.Y / 2 au-dessus du sol
	local bodyPart = part("Body", body, bodyColor)
	bodyPart.CFrame = CFrame.new(0, leg + body.Y / 2, 0)
	model.PrimaryPart = bodyPart

	-- Pattes (pivot à la hanche, en haut de la patte)
	local thickness = math.max(0.35, body.X * 0.2)
	local legColor = bodyColor:Lerp(Color3.new(0, 0, 0), 0.25)
	for _, info in {
		{ "LegFL", -1, -1 },
		{ "LegFR", 1, -1 },
		{ "LegBL", -1, 1 },
		{ "LegBR", 1, 1 },
	} do
		local legPart = part(info[1], Vector3.new(thickness, leg, thickness), legColor)
		local hoof = part(info[1] .. "Hoof", Vector3.new(thickness * 1.1, 0.3, thickness * 1.1), Color3.fromRGB(40, 30, 25), false)
		joint(info[1], bodyPart, legPart, CFrame.new(info[2] * (body.X / 2 - thickness / 2), -body.Y / 2, info[3] * (body.Z / 2 - thickness)), CFrame.new(0, leg / 2, 0))
		joint(info[1] .. "Hoof", legPart, hoof, CFrame.new(0, -leg / 2 + 0.15, 0), CFrame.new())
	end

	-- Cou + tête (articulation "Neck" à l'avant du corps)
	local neck = part("NeckPart", Vector3.new(body.X * 0.6, head.Y * 1.1, head.Z * 0.5), bodyColor)
	joint("Neck", bodyPart, neck, CFrame.new(0, body.Y * 0.35, -body.Z / 2) * CFrame.Angles(math.rad(-35), 0, 0), CFrame.new(0, -head.Y * 0.4, 0))
	local headPart = part("Head", head, headColor)
	joint("HeadJoint", neck, headPart, CFrame.new(0, head.Y * 0.5, -head.Z * 0.2) * CFrame.Angles(math.rad(45), 0, 0), CFrame.new(0, 0, head.Z * 0.25))
	for _, sx in { -1, 1 } do
		local ear = part("Ear", Vector3.new(0.2, 0.5, 0.2), headColor)
		joint("Ear", headPart, ear, CFrame.new(sx * head.X * 0.3, head.Y / 2 + 0.2, head.Z * 0.25), CFrame.new())
		local eye = part("Eye", Vector3.new(0.18, 0.18, 0.18), Color3.fromRGB(20, 20, 25), false)
		joint("Eye", headPart, eye, CFrame.new(sx * (head.X / 2 + 0.02), head.Y * 0.15, -head.Z * 0.05), CFrame.new())
	end
	if species.Horns then
		local horn = part("Horn", Vector3.new(0.25, 0.9, 0.25), maneColor, false)
		horn.Material = Enum.Material.Neon
		joint("Horn", headPart, horn, CFrame.new(0, head.Y / 2 + 0.35, -head.Z * 0.2) * CFrame.Angles(math.rad(-20), 0, 0), CFrame.new())
	end

	-- Crinière, queue, selle
	local mane = part("Mane", Vector3.new(0.3, head.Y * 1.2, head.Z * 0.6), maneColor, false)
	joint("ManeJoint", neck, mane, CFrame.new(0, 0, head.Z * 0.28), CFrame.new())
	local tail = part("Tail", Vector3.new(0.35, 0.35, 1.6), maneColor, false)
	joint("Tail", bodyPart, tail, CFrame.new(0, body.Y * 0.3, body.Z / 2) * CFrame.Angles(math.rad(35), 0, 0), CFrame.new(0, 0, -0.8))
	local saddle = part("Saddle", Vector3.new(body.X + 0.15, 0.3, body.Z * 0.38), Color3.fromRGB(120, 50, 40), false)
	joint("SaddleJoint", bodyPart, saddle, CFrame.new(0, body.Y / 2 + 0.1, 0.1), CFrame.new())

	-- Effets des variantes rares
	if variant.Aura or variant.Gold or variant.Rainbow then
		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(variant.Aura or variant.Color)
		particles.LightEmission = 1
		particles.Rate = if variant.Aura then 14 else 5
		particles.Lifetime = NumberRange.new(0.8, 1.5)
		particles.Speed = NumberRange.new(0.5, 1.5)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Size = NumberSequence.new(0.4, 0)
		particles.Parent = bodyPart
	end
	if variant.Aura then
		local light = Instance.new("PointLight")
		light.Color = variant.Aura
		light.Range = 14
		light.Brightness = 2
		light.Parent = bodyPart
	end

	model:SetAttribute("LegHeight", leg)
	model:SetAttribute("Species", speciesId)
	model:SetAttribute("Variant", variantId)
	CollectionService:AddTag(model, MOUNT_TAG)
	return model, bodyPart
end

-- Hauteur du dos du cheval au-dessus du sol (pour placer le cavalier)
function MountBuilder.BackHeight(speciesId: string): number
	local species = Config.Animals[speciesId] or Config.Animals.Horse
	return species.LegHeight + species.BodySize.Y
end

-- Hauteur du centre du corps au-dessus du sol
function MountBuilder.BodyCenterHeight(speciesId: string): number
	local species = Config.Animals[speciesId] or Config.Animals.Horse
	return species.LegHeight + species.BodySize.Y / 2
end

return MountBuilder
