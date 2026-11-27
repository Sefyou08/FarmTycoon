--[[
	AnimalBuilder.lua
	=================
	Modèles cartoon des animaux de la ferme (phase 10), une fonction par animal :
	  Chicken (poule), Rabbit (lapin), Duck (canard), Sheep (brebis), Goat (chèvre),
	  Cow (vache), Horse (cheval, et chevaux sauvages / Astrelune), Pig (cochon).

	  AnimalBuilder.Build(speciesId, variantId, groundCFrame) -> Model
	    • le modèle regarde vers -Z, ses pattes touchent groundCFrame ;
	    • PrimaryPart = "Body" ; une Part "Head" porte les chapeaux cosmétiques ;
	    • variantes : Doré (or brillant), Arc-en-ciel (couleurs animées), Légendaire /
	      Mythique (aura + particules + lumière) ;
	    • les pièces animées ont des attributs lus par le client (AnimalController) :
	        Anim  = "Leg" | "Head" | "Tail" | "Wing" | "Ear"
	        Phase = décalage de l'animation (pattes en opposition)
	        Hinge = vecteur du centre de la pièce vers son articulation, dans le repère
	                du modèle (X = droite, Y = haut, Z = arrière)
	      → pattes qui marchent, tête qui hoche, queue qui remue, ailes qui battent.

	Modèle à toi : ServerStorage.CustomModels.Animals.<espèce> (voir ArtKit) ; les effets
	de variante (aura, particules) sont ajoutés par-dessus.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local ArtKit = require(script.Parent.ArtKit)

local AnimalBuilder = {}

local RAINBOW_TAG = "RainbowPart"
local BLACK = Color3.fromRGB(25, 22, 28)
local WHITE = Color3.new(1, 1, 1)
local PINK = Color3.fromRGB(255, 170, 180)
local HOOF = Color3.fromRGB(60, 45, 40)
local ORANGE = Color3.fromRGB(255, 160, 40)

type Ctx = {
	Model: Model,
	G: CFrame,
	Variant: any,
	-- crée une pièce ; keep = garde sa couleur (yeux, bec...) même en Doré / Arc-en-ciel
	Part: (kind: string, name: string, size: Vector3 | number, cf: CFrame, color: Color3, keep: boolean?) -> BasePart,
	Main: (Color3) -> Color3,
}

-- Marque une pièce comme animée
local function anim(part: BasePart, kind: string, phase: number, hinge: Vector3?)
	part:SetAttribute("Anim", kind)
	part:SetAttribute("Phase", phase)
	part:SetAttribute("Hinge", hinge or Vector3.zero)
end

local function makeCtx(model: Model, groundCFrame: CFrame, variant: any): Ctx
	local ctx = {} :: any
	ctx.Model = model
	ctx.G = groundCFrame
	ctx.Variant = variant
	function ctx.Main(color: Color3): Color3
		return if variant.Gold then variant.Color else color
	end
	function ctx.Part(kind: string, name: string, size: any, cf: CFrame, color: Color3, keep: boolean?): BasePart
		local finalColor = if keep then color else ctx.Main(color)
		local world = groundCFrame * cf
		local p
		if kind == "Ball" then
			p = ArtKit.Ball(model, name, size, world, finalColor)
		elseif kind == "Ellipsoid" then
			p = ArtKit.Ellipsoid(model, name, size, world, finalColor)
		elseif kind == "Cylinder" then
			p = ArtKit.Cylinder(model, name, size.X, size.Y, world, finalColor)
		elseif kind == "Wedge" then
			p = ArtKit.Wedge(model, name, size, world, finalColor)
		else
			p = ArtKit.Block(model, name, size, world, finalColor)
		end
		if not keep then
			if variant.Gold then
				p.Reflectance = 0.25
				p.Material = Enum.Material.SmoothPlastic
			end
			if variant.Rainbow then
				p:SetAttribute("HueOffset", math.random())
				CollectionService:AddTag(p, RAINBOW_TAG)
			end
		end
		return p
	end
	return ctx
end

-- Yeux cartoon (blanc + pupille + reflet) de chaque côté d'une tête
local function eyes(ctx: Ctx, head: CFrame, spread: number, size: number, forward: number)
	for _, sx in { -1, 1 } do
		local eye = head * CFrame.new(sx * spread, size * 0.4, -forward)
		anim(ctx.Part("Ball", "EyeWhite", size, eye, WHITE, true), "Head", 0)
		anim(ctx.Part("Ball", "Pupil", size * 0.6, eye * CFrame.new(0, 0, -size * 0.25), BLACK, true), "Head", 0)
		anim(ctx.Part("Ball", "EyeShine", size * 0.22, eye * CFrame.new(size * 0.12, size * 0.15, -size * 0.48), WHITE, true), "Head", 0)
	end
end

-- 4 pattes cylindriques avec sabots (animées), renvoie rien
local function legs(ctx: Ctx, body: Vector3, leg: number, thickness: number, color: Color3, hoof: Color3?, inset: number?)
	local i = inset or 0.3
	for index, info in { { -1, -1, 0 }, { 1, -1, math.pi }, { -1, 1, math.pi }, { 1, 1, 0 } } do
		local cf = CFrame.new(info[1] * (body.X / 2 - thickness * 0.6), leg / 2, info[2] * (body.Z / 2 - thickness - i))
		local legPart = ctx.Part("Cylinder", "Leg" .. index, Vector3.new(leg + 0.2, thickness), cf * CFrame.new(0, 0.1, 0), color)
		anim(legPart, "Leg", info[3], Vector3.new(0, (leg + 0.2) / 2, 0))
		if hoof then
			local h = ctx.Part("Cylinder", "Hoof" .. index, Vector3.new(0.25, thickness * 1.1), cf * CFrame.new(0, -leg / 2 + 0.12, 0), hoof, true)
			anim(h, "Leg", info[3], Vector3.new(0, leg / 2 + 0.1, 0))
		end
	end
end

--------------------------------------------------------------------------
-- Animaux
--------------------------------------------------------------------------

local BUILDERS = {}

-- 🐄 Vache : taches noires, museau rose, cornes, cloche, mamelle, queue à houppe
function BUILDERS.Cow(ctx: Ctx, s: any)
	local body, leg = s.BodySize, s.LegHeight
	local by = leg + body.Y / 2
	local bodyPart = ctx.Part("Ellipsoid", "Body", body * Vector3.new(1.05, 1, 1), CFrame.new(0, by, 0), s.Color)
	ctx.Model.PrimaryPart = bodyPart
	legs(ctx, body, leg, 0.55, s.Color, HOOF)
	-- Taches
	if not ctx.Variant.Gold and not ctx.Variant.Rainbow then
		for i, info in { { 1, 0.15, -0.6, 1 }, { -1, 0.3, 0.4, 1.2 }, { 1, -0.1, 0.9, 0.8 }, { -1, -0.2, -0.9, 0.7 } } do
			ctx.Part("Ellipsoid", "Spot", Vector3.new(0.3, info[4], info[4] * 1.3), CFrame.new(info[1] * body.X * 0.47, by + info[2] * body.Y, info[3]) * CFrame.Angles(i, 0, 0), s.Spots or BLACK, true)
		end
		ctx.Part("Ellipsoid", "Spot", Vector3.new(1, 0.3, 1.2), CFrame.new(0.2, by + body.Y * 0.47, 0.3), s.Spots or BLACK, true)
	end
	-- Mamelle
	ctx.Part("Ellipsoid", "Udder", Vector3.new(0.9, 0.6, 0.9), CFrame.new(0, leg + 0.1, body.Z * 0.22), PINK, true)
	for _, o in { { -0.2, -0.2 }, { 0.2, -0.2 }, { -0.2, 0.2 }, { 0.2, 0.2 } } do
		ctx.Part("Cylinder", "Teat", Vector3.new(0.25, 0.14), CFrame.new(o[1], leg - 0.25, body.Z * 0.22 + o[2]), PINK, true)
	end
	-- Tête
	local head = s.HeadSize
	local hcf = CFrame.new(0, by + body.Y * 0.32, -body.Z / 2 - head.Z * 0.3)
	local headPart = ctx.Part("Ellipsoid", "Head", head * Vector3.new(1.05, 1, 1.1), hcf, s.HeadColor or s.Color)
	anim(headPart, "Head", 0, Vector3.new(0, 0, head.Z * 0.5))
	local muzzle = ctx.Part("Ellipsoid", "Muzzle", Vector3.new(head.X * 1.05, head.Y * 0.6, head.Z * 0.6), hcf * CFrame.new(0, -head.Y * 0.25, -head.Z * 0.45), PINK, true)
	anim(muzzle, "Head", 0, Vector3.new(0, head.Y * 0.25, head.Z * 0.95))
	for _, sx in { -1, 1 } do
		local nostril = ctx.Part("Ball", "Nostril", 0.18, hcf * CFrame.new(sx * 0.22, -head.Y * 0.22, -head.Z * 0.73), Color3.fromRGB(170, 90, 100), true)
		anim(nostril, "Head", 0, Vector3.new(0, head.Y * 0.22, head.Z * 1.23))
		local ear = ctx.Part("Ellipsoid", "Ear", Vector3.new(0.7, 0.3, 0.4), hcf * CFrame.new(sx * head.X * 0.62, head.Y * 0.2, 0.1) * CFrame.Angles(0, 0, sx * math.rad(-15)), s.HeadColor or s.Color)
		anim(ear, "Ear", sx, Vector3.new(-sx * 0.3, 0, 0))
		local horn = ctx.Part("Cylinder", "Horn", Vector3.new(0.6, 0.2), hcf * CFrame.new(sx * head.X * 0.32, head.Y * 0.55, 0.1) * CFrame.Angles(0, 0, sx * math.rad(-35)), Color3.fromRGB(245, 235, 205), true)
		anim(horn, "Head", 0, Vector3.new(0, 0, head.Z * 0.6))
	end
	eyes(ctx, hcf * CFrame.new(0, 0.05, 0), head.X * 0.32, 0.32, head.Z * 0.42)
	-- Collier et cloche
	ctx.Part("Cylinder", "Collar", Vector3.new(0.3, head.X * 1.15), CFrame.new(0, by + body.Y * 0.05, -body.Z / 2 + 0.25) * CFrame.Angles(math.rad(70), 0, 0), Color3.fromRGB(200, 60, 50), true)
	ctx.Part("Ball", "Bell", 0.5, CFrame.new(0, by - body.Y * 0.35, -body.Z / 2 - 0.05), Color3.fromRGB(255, 205, 60), true).Material = Enum.Material.Metal
	-- Queue à houppe
	local tail = ctx.Part("Cylinder", "Tail", Vector3.new(1.4, 0.15), CFrame.new(0, by - 0.1, body.Z / 2 + 0.1) * CFrame.Angles(math.rad(-25), 0, 0), s.Color)
	anim(tail, "Tail", 0, Vector3.new(0, 0.7, 0))
	local tuft = ctx.Part("Ball", "TailTuft", 0.4, CFrame.new(0, by - 0.75, body.Z / 2 + 0.4), BLACK, true)
	anim(tuft, "Tail", 0, Vector3.new(0, 1.3, -0.3))
end

-- 🐑 Brebis : grosse toison en boules, visage et pattes sombres
function BUILDERS.Sheep(ctx: Ctx, s: any)
	local body, leg = s.BodySize, s.LegHeight
	local by = leg + body.Y / 2
	local wool = s.Color
	local bodyPart = ctx.Part("Ellipsoid", "Body", body * 0.9, CFrame.new(0, by, 0), wool)
	ctx.Model.PrimaryPart = bodyPart
	-- Toison : boules autour du corps
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		local ring = i % 2
		ctx.Part("Ball", "Wool", body.Y * (0.55 + ring * 0.1), CFrame.new(math.cos(a) * body.X * 0.38, by + body.Y * (0.12 + ring * 0.12), math.sin(a) * body.Z * 0.38), ArtKit.Lighter(wool, ring * 0.04))
	end
	ctx.Part("Ball", "Wool", body.Y * 0.8, CFrame.new(0, by + body.Y * 0.3, 0), wool)
	legs(ctx, body, leg, 0.32, s.HeadColor or BLACK, BLACK, 0.4)
	-- Tête sombre avec houppette
	local head = s.HeadSize
	local hcf = CFrame.new(0, by + body.Y * 0.2, -body.Z / 2 - head.Z * 0.15)
	local headPart = ctx.Part("Ellipsoid", "Head", head * Vector3.new(0.95, 1.05, 1.15), hcf, s.HeadColor or BLACK, true)
	anim(headPart, "Head", 0, Vector3.new(0, 0, head.Z * 0.5))
	local tuft = ctx.Part("Ball", "WoolTuft", head.X * 0.75, hcf * CFrame.new(0, head.Y * 0.5, 0.1), wool)
	anim(tuft, "Head", 0, Vector3.new(0, -head.Y * 0.5, head.Z * 0.4))
	for _, sx in { -1, 1 } do
		local ear = ctx.Part("Ellipsoid", "Ear", Vector3.new(0.6, 0.22, 0.35), hcf * CFrame.new(sx * head.X * 0.58, head.Y * 0.15, 0.05) * CFrame.Angles(0, 0, sx * math.rad(20)), s.HeadColor or BLACK, true)
		anim(ear, "Ear", sx, Vector3.new(-sx * 0.25, 0, 0))
	end
	eyes(ctx, hcf, head.X * 0.28, 0.28, head.Z * 0.45)
	ctx.Part("Ball", "Nose", 0.2, hcf * CFrame.new(0, -head.Y * 0.3, -head.Z * 0.55), Color3.fromRGB(255, 150, 160), true)
	local tail = ctx.Part("Ball", "Tail", 0.6, CFrame.new(0, by + 0.2, body.Z * 0.48), wool)
	anim(tail, "Tail", 0, Vector3.new(0, 0, -0.2))
end

-- 🐐 Chèvre : cornes recourbées, barbichette, cou, petite queue dressée
function BUILDERS.Goat(ctx: Ctx, s: any)
	local body, leg = s.BodySize, s.LegHeight
	local by = leg + body.Y / 2
	local bodyPart = ctx.Part("Ellipsoid", "Body", body, CFrame.new(0, by, 0), s.Color)
	ctx.Model.PrimaryPart = bodyPart
	ctx.Part("Ellipsoid", "Belly", body * Vector3.new(0.8, 0.5, 0.75), CFrame.new(0, by - body.Y * 0.2, 0), ArtKit.Lighter(s.Color, 0.3))
	legs(ctx, body, leg, 0.32, ArtKit.Darker(s.Color, 0.1), HOOF, 0.35)
	ctx.Part("Ellipsoid", "Neck", Vector3.new(0.8, 1.4, 0.9), CFrame.new(0, by + body.Y * 0.45, -body.Z / 2 + 0.3) * CFrame.Angles(math.rad(-25), 0, 0), s.Color)
	local head = s.HeadSize
	local hcf = CFrame.new(0, by + body.Y * 0.85, -body.Z / 2 - head.Z * 0.2)
	local headPart = ctx.Part("Ellipsoid", "Head", head * Vector3.new(1, 0.95, 1.2), hcf * CFrame.Angles(math.rad(15), 0, 0), s.HeadColor or s.Color)
	anim(headPart, "Head", 0, Vector3.new(0, -0.3, head.Z * 0.5))
	local beard = ctx.Part("Wedge", "Beard", Vector3.new(0.25, 0.6, 0.35), hcf * CFrame.new(0, -head.Y * 0.62, -head.Z * 0.35) * CFrame.Angles(math.pi, 0, 0), Color3.fromRGB(245, 240, 230), true)
	anim(beard, "Head", 0, Vector3.new(0, head.Y * 0.62, head.Z * 0.85))
	for _, sx in { -1, 1 } do
		local horn1 = ctx.Part("Cylinder", "Horn", Vector3.new(0.7, 0.22), hcf * CFrame.new(sx * 0.25, head.Y * 0.6, 0.15) * CFrame.Angles(math.rad(35), 0, sx * math.rad(-10)), Color3.fromRGB(110, 95, 80), true)
		local horn2 = ctx.Part("Cylinder", "Horn", Vector3.new(0.5, 0.17), hcf * CFrame.new(sx * 0.3, head.Y * 0.85, 0.55) * CFrame.Angles(math.rad(85), 0, sx * math.rad(-10)), Color3.fromRGB(110, 95, 80), true)
		anim(horn1, "Head", 0, Vector3.new(0, -0.8, head.Z * 0.4))
		anim(horn2, "Head", 0, Vector3.new(0, -1, 0))
		local ear = ctx.Part("Ellipsoid", "Ear", Vector3.new(0.65, 0.2, 0.32), hcf * CFrame.new(sx * head.X * 0.6, head.Y * 0.2, 0.1) * CFrame.Angles(0, 0, sx * math.rad(25)), s.HeadColor or s.Color)
		anim(ear, "Ear", sx, Vector3.new(-sx * 0.3, 0, 0))
	end
	eyes(ctx, hcf, head.X * 0.32, 0.28, head.Z * 0.4)
	ctx.Part("Ball", "Nose", 0.2, hcf * CFrame.new(0, -head.Y * 0.2, -head.Z * 0.62), Color3.fromRGB(90, 70, 70), true)
	local tail = ctx.Part("Ellipsoid", "Tail", Vector3.new(0.25, 0.6, 0.25), CFrame.new(0, by + body.Y * 0.4, body.Z / 2) * CFrame.Angles(math.rad(-30), 0, 0), s.Color)
	anim(tail, "Tail", 0, Vector3.new(0, -0.3, 0))
end

-- 🐷 Cochon : tout rond, groin, oreilles tombantes, queue en tire-bouchon
function BUILDERS.Pig(ctx: Ctx, s: any)
	local body, leg = s.BodySize, s.LegHeight
	local by = leg + body.Y / 2
	local bodyPart = ctx.Part("Ellipsoid", "Body", body * Vector3.new(1.1, 1.05, 1), CFrame.new(0, by, 0), s.Color)
	ctx.Model.PrimaryPart = bodyPart
	legs(ctx, body, leg, 0.5, s.Color, Color3.fromRGB(200, 110, 120), 0.2)
	local head = s.HeadSize
	local hcf = CFrame.new(0, by + body.Y * 0.12, -body.Z / 2 - head.Z * 0.05)
	local headPart = ctx.Part("Ball", "Head", head.X, hcf, s.HeadColor or s.Color)
	anim(headPart, "Head", 0, Vector3.new(0, 0, head.X * 0.4))
	local snout = ctx.Part("Cylinder", "Snout", Vector3.new(0.4, head.X * 0.5), hcf * CFrame.new(0, -head.X * 0.08, -head.X * 0.5) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(255, 140, 160))
	anim(snout, "Head", 0, Vector3.new(0, 0.2, head.X * 0.9))
	for _, sx in { -1, 1 } do
		local nostril = ctx.Part("Ball", "Nostril", 0.15, hcf * CFrame.new(sx * 0.13, -head.X * 0.08, -head.X * 0.72), Color3.fromRGB(170, 70, 90), true)
		anim(nostril, "Head", 0, Vector3.new(0, 0.1, head.X * 1.1))
		local ear = ctx.Part("Wedge", "Ear", Vector3.new(0.12, 0.6, 0.55), hcf * CFrame.new(sx * head.X * 0.32, head.X * 0.42, -0.1) * CFrame.Angles(math.rad(-35), 0, sx * math.rad(-15)), s.HeadColor or s.Color)
		anim(ear, "Ear", sx, Vector3.new(0, -0.3, 0))
	end
	eyes(ctx, hcf * CFrame.new(0, 0.1, 0), head.X * 0.24, 0.24, head.X * 0.42)
	-- Queue en tire-bouchon
	for i = 0, 3 do
		local a = i * 1.6
		local t = ctx.Part("Ball", "Tail", 0.22, CFrame.new(math.cos(a) * 0.16, by + 0.25 + i * 0.1, body.Z / 2 + 0.1 + math.sin(a) * 0.16), ArtKit.Darker(s.Color, 0.05))
		anim(t, "Tail", 0, Vector3.new(-math.cos(a) * 0.16, -i * 0.1, -math.sin(a) * 0.16 - 0.1))
	end
end

-- 🐴 Cheval (et chevaux sauvages, Astrelune) : long cou, crinière, chanfrein blanc, longue queue
function BUILDERS.Horse(ctx: Ctx, s: any)
	local body, leg = s.BodySize, s.LegHeight
	local by = leg + body.Y / 2
	local mane = s.Mane or Color3.fromRGB(40, 30, 25)
	local bodyPart = ctx.Part("Ellipsoid", "Body", body * Vector3.new(1, 0.95, 1), CFrame.new(0, by, 0), s.Color)
	ctx.Model.PrimaryPart = bodyPart
	legs(ctx, body, leg, 0.45, ArtKit.Darker(s.Color, 0.08), HOOF, 0.4)
	-- Cou incliné vers l'avant
	local neckCf = CFrame.new(0, by + body.Y * 0.55, -body.Z / 2 + 0.3) * CFrame.Angles(math.rad(-30), 0, 0)
	ctx.Part("Ellipsoid", "Neck", Vector3.new(body.X * 0.6, 2.2, 1.2), neckCf, s.Color)
	for i = 0, 4 do
		ctx.Part("Ellipsoid", "Mane", Vector3.new(0.32, 0.7, 0.55), neckCf * CFrame.new(0, -0.7 + i * 0.42, 0.55), mane, true)
	end
	local head = s.HeadSize
	local hcf = CFrame.new(0, by + body.Y * 0.95, -body.Z / 2 - head.Z * 0.35) * CFrame.Angles(math.rad(25), 0, 0)
	local headPart = ctx.Part("Ellipsoid", "Head", head * Vector3.new(1, 0.95, 1), hcf, s.HeadColor or s.Color)
	anim(headPart, "Head", 0, Vector3.new(0, 0.2, head.Z * 0.45))
	local muzzle = ctx.Part("Ellipsoid", "Muzzle", Vector3.new(head.X * 0.95, head.Y * 0.7, head.Z * 0.45), hcf * CFrame.new(0, -head.Y * 0.1, -head.Z * 0.4), ArtKit.Darker(s.HeadColor or s.Color, 0.15))
	anim(muzzle, "Head", 0, Vector3.new(0, 0.3, head.Z * 0.85))
	local blaze = ctx.Part("Ellipsoid", "Blaze", Vector3.new(0.3, 0.2, head.Z * 0.65), hcf * CFrame.new(0, head.Y * 0.45, -head.Z * 0.1), WHITE, true)
	anim(blaze, "Head", 0, Vector3.new(0, -0.25, head.Z * 0.55))
	local forelock = ctx.Part("Ellipsoid", "Mane", Vector3.new(0.5, 0.35, 0.6), hcf * CFrame.new(0, head.Y * 0.5, head.Z * 0.15), mane, true)
	anim(forelock, "Head", 0, Vector3.new(0, -0.3, head.Z * 0.3))
	for _, sx in { -1, 1 } do
		local ear = ctx.Part("Wedge", "Ear", Vector3.new(0.18, 0.55, 0.3), hcf * CFrame.new(sx * head.X * 0.3, head.Y * 0.6, head.Z * 0.25), s.HeadColor or s.Color)
		anim(ear, "Ear", sx, Vector3.new(0, -0.25, 0))
		local nostril = ctx.Part("Ball", "Nostril", 0.16, hcf * CFrame.new(sx * 0.22, -head.Y * 0.15, -head.Z * 0.62), BLACK, true)
		anim(nostril, "Head", 0, Vector3.new(0, 0.3, head.Z * 1.05))
	end
	if s.Horns and not s.Celestial then
		local horn = ctx.Part("Wedge", "Horn", Vector3.new(0.2, 0.6, 0.35), hcf * CFrame.new(0, head.Y * 0.7, -head.Z * 0.1), mane, true)
		anim(horn, "Head", 0, Vector3.new(0, -0.5, head.Z * 0.5))
	end
	eyes(ctx, hcf * CFrame.new(0, head.Y * 0.1, 0), head.X * 0.42, 0.3, head.Z * 0.15)
	-- Longue queue
	local tail = ctx.Part("Ellipsoid", "Tail", Vector3.new(0.45, 2, 0.5), CFrame.new(0, by - 0.1, body.Z / 2 + 0.3) * CFrame.Angles(math.rad(-20), 0, 0), mane, true)
	anim(tail, "Tail", 0, Vector3.new(0, 0.9, 0))
end

-- 🐰 Lapin : assis, grandes oreilles, pompon blanc, grosses pattes arrière
function BUILDERS.Rabbit(ctx: Ctx, s: any)
	local b = s.BodySize
	local fur = s.Color
	local bodyPart = ctx.Part("Ellipsoid", "Body", Vector3.new(b.X * 1.1, b.Y * 1.2, b.Z), CFrame.new(0, b.Y * 0.6, 0.1), fur)
	ctx.Model.PrimaryPart = bodyPart
	ctx.Part("Ellipsoid", "Belly", Vector3.new(b.X * 0.7, b.Y * 0.8, 0.4), CFrame.new(0, b.Y * 0.55, -b.Z * 0.38), ArtKit.Lighter(fur, 0.4))
	for index, info in { { -1, 0 }, { 1, math.pi } } do
		local foot = ctx.Part("Ellipsoid", "Foot" .. index, Vector3.new(0.4, 0.3, 0.9), CFrame.new(info[1] * b.X * 0.35, 0.15, 0.1), ArtKit.Lighter(fur, 0.2))
		anim(foot, "Leg", info[2], Vector3.new(0, 0.3, 0.3))
		local paw = ctx.Part("Ball", "Paw" .. index, 0.32, CFrame.new(info[1] * b.X * 0.22, 0.2, -b.Z * 0.42), ArtKit.Lighter(fur, 0.2))
		anim(paw, "Leg", info[2] + math.pi, Vector3.new(0, 0.4, 0))
	end
	local hcf = CFrame.new(0, b.Y * 1.25, -b.Z * 0.25)
	local head = ctx.Part("Ball", "Head", s.HeadSize.X * 1.05, hcf, s.HeadColor or fur)
	anim(head, "Head", 0, Vector3.new(0, -0.3, 0.2))
	for _, sx in { -1, 1 } do
		local ear = ctx.Part("Ellipsoid", "Ear", Vector3.new(0.3, 1.1, 0.18), hcf * CFrame.new(sx * 0.2, 0.85, 0.1) * CFrame.Angles(math.rad(-10), 0, sx * math.rad(-12)), s.HeadColor or fur)
		anim(ear, "Ear", sx, Vector3.new(0, -0.5, 0))
		local inner = ctx.Part("Ellipsoid", "EarInner", Vector3.new(0.16, 0.8, 0.06), hcf * CFrame.new(sx * 0.2, 0.85, -0.02) * CFrame.Angles(math.rad(-10), 0, sx * math.rad(-12)), PINK, true)
		anim(inner, "Ear", sx, Vector3.new(0, -0.5, 0.1))
		local cheek = ctx.Part("Ball", "Cheek", 0.35, hcf * CFrame.new(sx * 0.18, -0.15, -0.35), ArtKit.Lighter(fur, 0.35))
		anim(cheek, "Head", 0, Vector3.new(-sx * 0.18, 0, 0.55))
	end
	eyes(ctx, hcf * CFrame.new(0, 0.05, 0), 0.22, 0.24, 0.36)
	local nose = ctx.Part("Ball", "Nose", 0.15, hcf * CFrame.new(0, -0.05, -0.5), PINK, true)
	anim(nose, "Head", 0, Vector3.new(0, 0, 0.7))
	local tail = ctx.Part("Ball", "Tail", 0.5, CFrame.new(0, b.Y * 0.45, b.Z * 0.6), WHITE)
	anim(tail, "Tail", 0, Vector3.new(0, 0, -0.2))
end

-- 🐔 Poule : crête et barbillons rouges, bec jaune, ailes, plumes de queue
function BUILDERS.Chicken(ctx: Ctx, s: any)
	local b = s.BodySize
	local legH = s.LegHeight
	local by = legH + b.Y / 2
	local bodyPart = ctx.Part("Ellipsoid", "Body", Vector3.new(b.X, b.Y, b.Z * 1.05), CFrame.new(0, by, 0), s.Color)
	ctx.Model.PrimaryPart = bodyPart
	for index, info in { { -1, 0 }, { 1, math.pi } } do
		local l = ctx.Part("Cylinder", "Leg" .. index, Vector3.new(legH + 0.2, 0.14), CFrame.new(info[1] * 0.3, legH / 2 + 0.05, 0.05), ORANGE, true)
		anim(l, "Leg", info[2], Vector3.new(0, legH / 2 + 0.1, 0))
		local foot = ctx.Part("Block", "Foot" .. index, Vector3.new(0.35, 0.08, 0.45), CFrame.new(info[1] * 0.3, 0.04, -0.12), ORANGE, true)
		anim(foot, "Leg", info[2], Vector3.new(0, legH + 0.05, 0.12))
		local wing = ctx.Part("Ellipsoid", "Wing", Vector3.new(0.25, b.Y * 0.65, b.Z * 0.7), CFrame.new(info[1] * b.X * 0.5, by + 0.05, 0.1), ArtKit.Darker(s.Color, 0.05))
		anim(wing, "Wing", info[1], Vector3.new(-info[1] * 0.1, b.Y * 0.3, 0))
	end
	local hcf = CFrame.new(0, by + b.Y * 0.55, -b.Z * 0.38)
	local head = ctx.Part("Ball", "Head", s.HeadSize.X, hcf, s.HeadColor or s.Color)
	anim(head, "Head", 0, Vector3.new(0, -0.35, 0.15))
	for i = -1, 1 do
		local comb = ctx.Part("Ball", "Comb", 0.28, hcf * CFrame.new(0, s.HeadSize.X * 0.5 + 0.05 - math.abs(i) * 0.05, i * 0.15), Color3.fromRGB(230, 40, 40), true)
		anim(comb, "Head", 0, Vector3.new(0, -0.6, 0.15 - i * 0.15))
	end
	local beak = ctx.Part("Wedge", "Beak", Vector3.new(0.22, 0.18, 0.3), hcf * CFrame.new(0, -0.05, -s.HeadSize.X * 0.55) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(255, 200, 40), true)
	anim(beak, "Head", 0, Vector3.new(0, 0, 0.55))
	local wattle = ctx.Part("Ellipsoid", "Wattle", Vector3.new(0.14, 0.28, 0.14), hcf * CFrame.new(0, -0.3, -s.HeadSize.X * 0.4), Color3.fromRGB(230, 40, 40), true)
	anim(wattle, "Head", 0, Vector3.new(0, 0.3, 0.45))
	eyes(ctx, hcf * CFrame.new(0, 0, 0.05), s.HeadSize.X * 0.33, 0.16, s.HeadSize.X * 0.3)
	-- Plumes de queue en éventail
	for i = -1, 1 do
		local feather = ctx.Part("Ellipsoid", "Tail", Vector3.new(0.2, 0.75, 0.3), CFrame.new(i * 0.18, by + b.Y * 0.4, b.Z * 0.5) * CFrame.Angles(math.rad(-30), 0, i * math.rad(20)), ArtKit.Darker(s.Color, 0.08))
		anim(feather, "Tail", 0, Vector3.new(0, -0.3, 0))
	end
end

-- 🦆 Canard : tête verte, bec plat orange, collier blanc, pattes palmées
function BUILDERS.Duck(ctx: Ctx, s: any)
	local b = s.BodySize
	local legH = s.LegHeight
	local by = legH + b.Y / 2
	local bodyPart = ctx.Part("Ellipsoid", "Body", Vector3.new(b.X, b.Y * 0.95, b.Z), CFrame.new(0, by, 0.1), s.Color)
	ctx.Model.PrimaryPart = bodyPart
	for index, info in { { -1, 0 }, { 1, math.pi } } do
		local l = ctx.Part("Cylinder", "Leg" .. index, Vector3.new(legH + 0.2, 0.16), CFrame.new(info[1] * 0.3, legH / 2 + 0.05, 0.2), ORANGE, true)
		anim(l, "Leg", info[2], Vector3.new(0, legH / 2 + 0.1, 0))
		local foot = ctx.Part("Ellipsoid", "Foot" .. index, Vector3.new(0.45, 0.08, 0.55), CFrame.new(info[1] * 0.3, 0.04, 0.05), ORANGE, true)
		anim(foot, "Leg", info[2], Vector3.new(0, legH + 0.05, 0.15))
		local wing = ctx.Part("Ellipsoid", "Wing", Vector3.new(0.25, b.Y * 0.6, b.Z * 0.65), CFrame.new(info[1] * b.X * 0.5, by + 0.05, 0.25), Color3.fromRGB(150, 140, 130))
		anim(wing, "Wing", info[1], Vector3.new(-info[1] * 0.1, b.Y * 0.3, 0))
	end
	ctx.Part("Ellipsoid", "Neck", Vector3.new(0.55, 0.9, 0.55), CFrame.new(0, by + b.Y * 0.45, -b.Z * 0.35), s.Color)
	ctx.Part("Cylinder", "NeckRing", Vector3.new(0.12, 0.6), CFrame.new(0, by + b.Y * 0.62, -b.Z * 0.37), WHITE, true)
	local hcf = CFrame.new(0, by + b.Y * 0.95, -b.Z * 0.4)
	local head = ctx.Part("Ball", "Head", s.HeadSize.X, hcf, s.HeadColor or s.Color)
	anim(head, "Head", 0, Vector3.new(0, -0.4, 0.1))
	local bill = ctx.Part("Ellipsoid", "Bill", Vector3.new(0.45, 0.15, 0.6), hcf * CFrame.new(0, -0.12, -s.HeadSize.X * 0.55), Color3.fromRGB(255, 170, 40), true)
	anim(bill, "Head", 0, Vector3.new(0, 0.12, 0.55))
	eyes(ctx, hcf * CFrame.new(0, 0, 0.05), s.HeadSize.X * 0.33, 0.16, s.HeadSize.X * 0.3)
	local tail = ctx.Part("Wedge", "Tail", Vector3.new(0.5, 0.45, 0.5), CFrame.new(0, by + b.Y * 0.25, b.Z * 0.6) * CFrame.Angles(0, math.pi, 0), s.Color)
	anim(tail, "Tail", 0, Vector3.new(0, 0, -0.2))
end

-- Chevaux sauvages et Astrelune : même silhouette que le cheval
BUILDERS.ForestHorse = BUILDERS.Horse
BUILDERS.SnowHorse = BUILDERS.Horse
BUILDERS.SandHorse = BUILDERS.Horse
BUILDERS.LavaHorse = BUILDERS.Horse
BUILDERS.Astrelune = BUILDERS.Horse

--------------------------------------------------------------------------
-- Effets
--------------------------------------------------------------------------

local function variantEffects(body: BasePart, variant: any)
	if variant.Aura then
		ArtKit.Light(body, variant.Aura, 10, 2)
	end
	if variant.Gold or variant.Aura or variant.Rainbow then
		ArtKit.Particles(body, {
			Color = ColorSequence.new(variant.Aura or variant.Color),
			LightEmission = 1,
			Rate = if variant.Aura then 10 else 3,
			Lifetime = NumberRange.new(0.8, 1.5),
			Speed = NumberRange.new(0.5, 1.5),
			Size = NumberSequence.new(0.35, 0),
		})
	end
end

-- Effets propres à certaines espèces (chevaux sauvages, Astrelune)
local function speciesEffects(ctx: Ctx, speciesId: string, s: any)
	local body = ctx.Model.PrimaryPart :: BasePart
	local head = ctx.Model:FindFirstChild("Head") :: BasePart?
	if speciesId == "LavaHorse" then
		ArtKit.Particles(body, { Name = "Embers", Color = ColorSequence.new(Color3.fromRGB(255, 180, 60), Color3.fromRGB(255, 60, 20)), LightEmission = 1, Rate = 6, Size = NumberSequence.new(0.25, 0), Acceleration = Vector3.new(0, 3, 0) })
		ArtKit.Light(body, Color3.fromRGB(255, 120, 40), 8, 1)
	elseif speciesId == "SnowHorse" then
		ArtKit.Particles(body, { Name = "Frost", Color = ColorSequence.new(Color3.fromRGB(220, 240, 255)), LightEmission = 0.5, Rate = 4, Size = NumberSequence.new(0.3, 0) })
	elseif speciesId == "ForestHorse" then
		for i = 0, 2 do
			ctx.Part("Ball", "Leaf", 0.35, CFrame.new(-0.3 + i * 0.3, s.LegHeight + s.BodySize.Y * 1.05, -s.BodySize.Z * 0.4 + i * 0.2), Color3.fromRGB(120, 200, 80), true)
		end
	end
	if s.Celestial and head then
		-- Astrelune : corne d'étoile, auréole, crinière arc-en-ciel lumineuse, poussière d'étoiles
		local hs = s.HeadSize
		local hornCf = head.CFrame * CFrame.new(0, hs.Y / 2 + 0.55, -hs.Z * 0.2) * CFrame.Angles(math.rad(-25), 0, 0)
		local horn = ArtKit.Cylinder(ctx.Model, "StarHorn", 1.3, 0.3, hornCf, Color3.fromRGB(255, 240, 150), Enum.Material.Neon)
		anim(horn, "Head", 0)
		for i = 1, 10 do
			local angle = i / 10 * math.pi * 2
			local cf = head.CFrame * CFrame.new(math.cos(angle) * 0.8, hs.Y / 2 + 1.2, math.sin(angle) * 0.8) * CFrame.Angles(0, -angle, 0)
			local halo = ArtKit.Block(ctx.Model, "Halo", Vector3.new(0.35, 0.08, 0.12), cf, Color3.fromRGB(255, 230, 120), Enum.Material.Neon)
			anim(halo, "Head", 0)
		end
		for _, d in ctx.Model:GetChildren() do
			if d:IsA("BasePart") and (d.Name == "Mane" or d.Name == "Tail") then
				d:SetAttribute("HueOffset", math.random() * 0.3)
				CollectionService:AddTag(d, RAINBOW_TAG)
				d.Material = Enum.Material.Neon
			end
		end
		ArtKit.Light(body, Color3.fromRGB(255, 200, 255), 16, 2.5)
		ArtKit.Particles(body, { Name = "Stardust", Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), Color3.fromRGB(200, 150, 255)), LightEmission = 1, Rate = 18, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(0.5, 2), Size = NumberSequence.new(0.4, 0) })
	end
end

--------------------------------------------------------------------------

function AnimalBuilder.Build(speciesId: string, variantId: string, groundCFrame: CFrame): Model
	local species = Config.Animals[speciesId]
	local variant = ItemUtil.GetVariant(variantId)

	local custom = ArtKit.Custom("Animals", speciesId)
	if custom then
		ArtKit.PlaceCustom(custom, groundCFrame, true, math.max(species.BodySize.Z + species.HeadSize.Z, species.LegHeight + species.BodySize.Y + species.HeadSize.Y))
		custom.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local body = custom.PrimaryPart :: BasePart
		if body then
			body.Name = "Body"
			variantEffects(body, variant)
		end
		custom:SetAttribute("Variant", variantId)
		ArtKit.SnapToGround(custom, groundCFrame)
		if body then
			body.PivotOffset = body.CFrame:ToObjectSpace(groundCFrame)
		end
		return custom
	end

	local model = Instance.new("Model")
	model.Name = speciesId
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local ctx = makeCtx(model, groundCFrame, variant)
	local builder = BUILDERS[speciesId] or BUILDERS.Horse
	builder(ctx, species)
	local body = model.PrimaryPart :: BasePart
	-- Seul le corps est "cliquable" (prompts) ; tout le reste est décoratif
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = d == body
		end
	end
	speciesEffects(ctx, speciesId, species)
	variantEffects(body, variant)
	-- Tout ce qui est sur la tête (yeux, oreilles, cornes, museau...) suit le hochement de la
	-- tête : même articulation que la Part "Head" (vecteur exprimé dans le repère du modèle)
	local head = model:FindFirstChild("Head") :: BasePart?
	if head and head:GetAttribute("Anim") == "Head" then
		local headHinge = head:GetAttribute("Hinge") or Vector3.zero
		for _, d in model:GetChildren() do
			if d:IsA("BasePart") and d ~= head and (d:GetAttribute("Anim") == "Head" or d:GetAttribute("Anim") == "Ear") then
				d:SetAttribute("Anim", "Head")
				d:SetAttribute("Hinge", groundCFrame:VectorToObjectSpace(head.Position - d.Position) + headHinge)
			end
		end
	end
	model:SetAttribute("Variant", variantId)
	-- Pattes bien posées SUR le sol (la pièce la plus basse touche le sol), pivot sous les pieds
	ArtKit.SnapToGround(model, groundCFrame)
	body.PivotOffset = body.CFrame:ToObjectSpace(groundCFrame)
	return model
end

return AnimalBuilder
