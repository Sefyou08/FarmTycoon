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
	MODÈLE IMPORTÉ : si ServerStorage.CustomModels.Animals.<espèce> existe (Horse, ForestHorse,
	SnowHorse, SandHorse, LavaHorse, Astrelune...), la monture utilise CE modèle :
	  • redressé (Yaw/Pitch/Roll), mis à l'échelle et posé au sol comme dans les enclos ;
	  • toutes ses pièces sans collision, sans masse, non ancrées, soudées entre elles ;
	  • variante (Doré, Arc-en-ciel, aura) et selle cosmétique appliquées ;
	  • hauteur du dos mesurée par rayons sur le vrai modèle : le cavalier est assis au
	    milieu du dos, les sabots touchent le sol ;
	  • animations : si le modèle a un squelette (Motor6D / Bone) ET des Animation (noms
	    contenant idle / walk / run, gallop, trot), le client les joue ; sinon, balancement
	    de galop + léger rebond via l'articulation "MountBob".
	  Attribut "MountRig" : "Generated" | "Animated" | "Simple" (lu par MountController).
	Build renvoie aussi la disposition : { AttachHeight, BackHeight, SeatZ } (voir Layout).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local PatternBuilder = require(script.Parent.PatternBuilder)
local ArtKit = require(script.Parent.ArtKit)

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local MountBuilder = {}

local RAINBOW_TAG = "RainbowPart"
local MOUNT_TAG = "MountModel"

-- Disposition d'une monture, pour placer le cavalier :
--   AttachHeight : hauteur (au-dessus du sol) de l'origine de la pièce à souder au joueur
--   BackHeight   : hauteur du dos (dessus de la selle) au milieu du dos
--   SeatZ        : position avant/arrière du siège dans le repère du cheval (-Z = avant)
export type Layout = { AttachHeight: number, BackHeight: number, SeatZ: number }

-- Motif et étincelles de la selle cosmétique (pièces soudées à la selle)
local function saddleExtras(model: Model, saddle: BasePart, skin: any)
	if skin.Pattern then
		local holder = Instance.new("Model")
		holder.Name = "SaddlePattern"
		holder.Parent = model
		PatternBuilder.Apply(saddle, Enum.NormalId.Top, skin.Pattern, { Parent = holder, Spacing = 0.9, Size = 0.6, MaxCount = 8, Color = skin.PatternColor, Accent = skin.PatternAccent })
		-- Le cheval bouge avec le joueur : les pièces du motif sont soudées à la selle
		for _, d in holder:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.Massless = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = saddle
				weld.Part1 = d
				weld.Parent = d
			end
		end
	end
	if skin.Sparkles then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(skin.Harness or Color3.new(1, 1, 1))
		sparkles.LightEmission = 1
		sparkles.Rate = 10
		sparkles.Lifetime = NumberRange.new(0.6, 1.2)
		sparkles.Speed = NumberRange.new(0.3, 1)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.3, 0)
		sparkles.Parent = saddle
	end
end

-- Effets des variantes rares (particules, lumière) sur la pièce principale
local function variantFX(body: BasePart, variant: any)
	if variant.Aura or variant.Gold or variant.Rainbow then
		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(variant.Aura or variant.Color)
		particles.LightEmission = 1
		particles.Rate = if variant.Aura then 14 else 5
		particles.Lifetime = NumberRange.new(0.8, 1.5)
		particles.Speed = NumberRange.new(0.5, 1.5)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Size = NumberSequence.new(0.4, 0)
		particles.Parent = body
	end
	if variant.Aura then
		local light = Instance.new("PointLight")
		light.Color = variant.Aura
		light.Range = 14
		light.Brightness = 2
		light.Parent = body
	end
end

--------------------------------------------------------------------------
-- Monture à partir d'un modèle importé (CustomModels.Animals.<espèce>)
--------------------------------------------------------------------------

-- Rôle d'une animation selon son nom (ou celui de son parent, ex. dossiers du script Animate)
local function animationRole(anim: Animation): string?
	local name = (anim.Name .. " " .. (if anim.Parent then anim.Parent.Name else "")):lower()
	if name:find("run") or name:find("gallop") or name:find("galop") or name:find("sprint") then
		return "Run"
	elseif name:find("walk") or name:find("trot") or name:find("marche") then
		return "Walk"
	elseif name:find("idle") or name:find("stand") or name:find("repos") then
		return "Idle"
	end
	return nil
end

-- Hauteur touchée par un rayon vertical sur le modèle (nil si rien)
local function probe(params: RaycastParams, origin: Vector3, direction: Vector3): number?
	local hit = Workspace:Raycast(origin, direction, params)
	return hit and hit.Position.Y
end

local function buildCustom(custom: Model, speciesId: string, variantId: string, skin: any?): (Model, BasePart, Layout)
	local species = Config.Animals[speciesId] or Config.Animals.Horse
	local variant = ItemUtil.GetVariant(variantId)

	-- 1) Redressé, mis à l'échelle (même taille que dans les enclos) et posé sur un sol
	--    temporaire très haut dans le Workspace, pour pouvoir le mesurer par rayons
	local lift = 4000
	local ground = CFrame.new(0, lift, 0)
	ArtKit.PlaceCustom(custom, ground, true, math.max(species.BodySize.Z + species.HeadSize.Z, species.LegHeight + species.BodySize.Y + species.HeadSize.Y))
	local parts = {}
	for _, d in custom:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = true
			table.insert(parts, d)
		end
	end
	custom.Parent = Workspace

	-- Boîte englobante FINALE alignée sur le sol (après redressement et mise à l'échelle)
	local primary = custom.PrimaryPart
	custom.PrimaryPart = nil
	custom.WorldPivot = ground
	local boxCf, boxSize = custom:GetBoundingBox()
	custom.PrimaryPart = primary
	local center = ground:PointToObjectSpace(boxCf.Position)
	local length = boxSize.Z

	-- 2) Hauteur du dos : rayons verticaux autour du milieu du corps (médiane : ignore une
	--    crinière ou une corne qui dépasse), puis dessous du ventre (pour le harnais)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { custom }
	local samples = {}
	for i = -2, 2 do
		local z = center.Z + i * length * 0.06
		local y = probe(params, Vector3.new(center.X, lift + boxSize.Y + 5, z), Vector3.new(0, -(boxSize.Y + 10), 0))
		if y then
			table.insert(samples, y - lift)
		end
	end
	table.sort(samples)
	local back = if #samples > 0 then samples[math.ceil(#samples / 2)] else boxSize.Y * 0.62
	local belly = probe(params, Vector3.new(center.X, lift + 0.05, center.Z), Vector3.new(0, back, 0))
	belly = if belly then math.clamp(belly - lift, 0.2, back - 0.3) else back * 0.55

	-- 3) Retour à l'origine (sol à y = 0), hors du Workspace ; plus aucune collision ni masse
	custom.Parent = nil
	custom:PivotTo(custom:GetPivot() - Vector3.new(0, lift, 0))
	for _, p in parts do
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = true
	end

	-- 4) Variante : couleur dorée / arc-en-ciel sur tout le corps (les textures sont retirées
	--    pour que la couleur se voie), effets des variantes rares
	if variant.Gold or variant.Rainbow then
		for _, d in custom:GetDescendants() do
			if d:IsA("SurfaceAppearance") or d:IsA("Texture") or d:IsA("Decal") then
				d:Destroy()
			end
		end
		for _, p in parts do
			if p:IsA("MeshPart") then
				p.TextureID = ""
			end
			if variant.Gold then
				p.Color = variant.Color
				p.Material = Enum.Material.SmoothPlastic
				p.Reflectance = 0.25
			else
				p:SetAttribute("HueOffset", math.random())
				CollectionService:AddTag(p, RAINBOW_TAG)
			end
		end
	end

	-- 5) Soudure : chaque groupe de pièces non relié par une articulation du modèle est soudé
	--    à la pièce principale (le squelette importé, s'il existe, est conservé tel quel)
	local root = primary or parts[1]
	local group: { [BasePart]: BasePart } = {}
	local function find(p: BasePart): BasePart
		while group[p] and group[p] ~= p do
			p = group[p]
		end
		return p
	end
	for _, p in parts do
		group[p] = p
	end
	local hasSkeleton = false
	for _, d in custom:GetDescendants() do
		local a, b
		if d:IsA("JointInstance") then
			a, b = d.Part0, d.Part1
			if d:IsA("Motor6D") then
				hasSkeleton = true
			end
		elseif d:IsA("WeldConstraint") or d:IsA("RigidConstraint") then
			a, b = (d :: any).Part0, (d :: any).Part1
		elseif d:IsA("Bone") then
			hasSkeleton = true
		end
		if a and b and group[a] and group[b] then
			group[find(a)] = find(b)
		end
	end
	local rootGroup = find(root)
	local welded: { [BasePart]: boolean } = { [rootGroup] = true }
	for _, p in parts do
		local g = find(p)
		if not welded[g] then
			welded[g] = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = g
			weld.Parent = g
		end
	end

	-- 6) Pièce d'attache (au sol, sous le milieu du cheval) + articulation "MountBob" que le
	--    client fait balancer (galop) quand le modèle n'a pas d'animations à lui
	local mountRoot = Instance.new("Part")
	mountRoot.Name = "MountRoot"
	mountRoot.Size = Vector3.new(0.2, 0.2, 0.2)
	mountRoot.Transparency = 1
	mountRoot.Anchored = false
	mountRoot.CanCollide = false
	mountRoot.CanQuery = false
	mountRoot.CanTouch = false
	mountRoot.Massless = true
	mountRoot.CFrame = CFrame.new(center.X, 0, center.Z)
	mountRoot.Parent = custom
	local pivotHeight = (back + belly) / 2 -- le balancement tourne autour du milieu du corps
	local bob = Instance.new("Motor6D")
	bob.Name = "MountBob"
	bob.Part0 = mountRoot
	bob.Part1 = root
	bob.C0 = CFrame.new(0, pivotHeight, 0)
	bob.C1 = root.CFrame:ToObjectSpace(mountRoot.CFrame * CFrame.new(0, pivotHeight, 0))
	bob.Parent = mountRoot

	-- 7) Selle cosmétique sur le dos (soudée au corps) ; harnais autour du ventre
	local width = boxSize.X
	local saddleColor = if skin and skin.Saddle then skin.Saddle else Color3.fromRGB(120, 50, 40)
	local function deco(name: string, size: Vector3, cf: CFrame, color: Color3, neon: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = custom
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		return p
	end
	local saddleWidth = math.clamp(width * 0.75, 0.8, 4)
	local saddle = deco("Saddle", Vector3.new(saddleWidth, 0.3, math.clamp(length * 0.22, 0.8, 4)), CFrame.new(center.X, back + 0.1, center.Z), saddleColor)
	if skin then
		if skin.Harness then
			local strapHeight = math.max(0.4, back - belly + 0.1)
			deco("Harness", Vector3.new(saddleWidth + 0.2, strapHeight, 0.25), CFrame.new(center.X, belly + strapHeight / 2 - 0.05, center.Z - length * 0.06), skin.Harness, skin.Neon)
		end
		saddleExtras(custom, saddle, skin)
	end
	variantFX(root, variant)

	-- 8) Animations du modèle importé (prises sur l'original : le nettoyage supprime les
	--    scripts, et donc les Animation rangées dans un script "Animate")
	local folder = ServerStorage:FindFirstChild("CustomModels")
	folder = folder and folder:FindFirstChild("Animals")
	local template = folder and folder:FindFirstChild(speciesId)
	local animations = Instance.new("Folder")
	animations.Name = "MountAnimations"
	local roles = 0
	if template and hasSkeleton then
		for _, d in template:GetDescendants() do
			if d:IsA("Animation") and d.AnimationId ~= "" then
				local role = animationRole(d)
				if role and not animations:FindFirstChild(role) then
					local copy = d:Clone()
					copy.Name = role
					copy.Parent = animations
					roles += 1
				end
			end
		end
	end
	if roles > 0 then
		animations.Parent = custom
		local controller = custom:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController")
		controller.Parent = custom
		if not controller:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = controller
		end
		custom:SetAttribute("MountRig", "Animated")
	else
		animations:Destroy()
		custom:SetAttribute("MountRig", "Simple")
	end

	custom.Name = "Mount"
	custom.PrimaryPart = mountRoot
	custom:SetAttribute("LegHeight", belly)
	custom:SetAttribute("Species", speciesId)
	custom:SetAttribute("Variant", variantId)
	CollectionService:AddTag(custom, MOUNT_TAG)
	return custom, mountRoot, { AttachHeight = 0, BackHeight = back + 0.25, SeatZ = center.Z }
end

-- Renvoie (model, pièce à souder au joueur, disposition). Le modèle est construit à l'origine.
-- skin (optionnel) = cosmétique "Selle de monture" (Config.Cosmetics, catégorie MountSkin).
function MountBuilder.Build(speciesId: string, variantId: string, skin: any?): (Model, BasePart, Layout)
	local custom = ArtKit.Custom("Animals", speciesId)
	if custom then
		return buildCustom(custom, speciesId, variantId, skin)
	end
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
	local saddle = part("Saddle", Vector3.new(body.X + 0.15, 0.3, body.Z * 0.38), if skin and skin.Saddle then skin.Saddle else Color3.fromRGB(120, 50, 40), false)
	joint("SaddleJoint", bodyPart, saddle, CFrame.new(0, body.Y / 2 + 0.1, 0.1), CFrame.new())
	-- Harnais (bandes autour du corps et du cou) si la selle cosmétique en a un
	if skin and skin.Harness then
		for i, z in { -0.1, 0.35 } do
			local strap = part("Harness" .. i, Vector3.new(body.X + 0.2, body.Y + 0.1, 0.25), skin.Harness, false)
			if skin.Neon then
				strap.Material = Enum.Material.Neon
			end
			joint("HarnessJoint" .. i, bodyPart, strap, CFrame.new(0, 0, z * body.Z), CFrame.new())
		end
		local collar = part("Collar", Vector3.new(body.X * 0.7, 0.25, head.Z * 0.6), skin.Harness, false)
		if skin.Neon then
			collar.Material = Enum.Material.Neon
		end
		joint("CollarJoint", neck, collar, CFrame.new(0, 0, 0), CFrame.new())
	end
	if skin then
		-- (hors Workspace, les Motor6D ne placent pas encore les pièces : on place la selle à la main)
		saddle.CFrame = bodyPart.CFrame * CFrame.new(0, body.Y / 2 + 0.1, 0.1)
		saddleExtras(model, saddle, skin)
	end
	variantFX(bodyPart, variant)

	model:SetAttribute("LegHeight", leg)
	model:SetAttribute("MountRig", "Generated")
	model:SetAttribute("Species", speciesId)
	model:SetAttribute("Variant", variantId)
	CollectionService:AddTag(model, MOUNT_TAG)
	return model, bodyPart, { AttachHeight = leg + body.Y / 2, BackHeight = leg + body.Y, SeatZ = -0.2 }
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
