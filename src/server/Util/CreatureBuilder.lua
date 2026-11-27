--[[
	CreatureBuilder.lua
	===================
	Modèles cartoon des créatures d'expédition (phase 10). Créatures 100 % originales.
	UNE FONCTION PAR CRÉATURE (table DESIGNS, plus bas), qui assemble des silhouettes
	de base partagées :
	  blob      : petite boule sautillante (yeux immenses, petits pieds)
	  quad      : quadrupède (cerf, ours, chat, dragon...)
	  lizard    : corps bas et long, pattes écartées, longue queue
	  insect    : carapace + 6 pattes (scorpion, scarabée)
	  flyer     : petit corps qui flotte, ailes qui battent sans arrêt
	  bird      : oiseau (bec, ailes, plumes de queue)
	  biped     : créature debout sur deux pattes (bras qui balancent)

	Palette par zone : Forêt verts / bruns, Montagne blancs / bleus glacés,
	Désert ocres / dorés, Volcan noirs / rouges / orangés (couleurs dans Config.Creatures).
	Plus la créature est rare, plus elle est grande et impressionnante : taille, couleurs
	vives, particules et lumière (Config.CreatureRarities[x].Visual), auréole pour les Divines.
	Mutations : Dorée (or), Géante (x2), Arc-en-ciel (couleurs animées), Spectrale (translucide).

	Animations (client, AnimalController) : chaque pièce a un attribut Anim
	("Breathe", "Leg", "Arm", "Head", "Tail", "Wing") ; le modèle a Hop (sautille),
	Flyer (flotte, ailes en continu) et RigScale (taille appliquée).

	  CreatureBuilder.Build(creatureId, mutationId, groundCFrame) -> (model, body)
	    body = Part invisible "Body" (boîte englobante, porte les prompts et panneaux).

	REMPLACER UN MODÈLE (Toolbox / MeshPart importé), créature par créature :
	  ServerStorage.CustomModels.Creatures.<id de la créature> (voir ArtKit).
	  Taille de rareté, mutation Géante et lumières de rareté sont appliquées par-dessus.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureUtil = require(ReplicatedStorage.Shared.CreatureUtil)
local ArtKit = require(script.Parent.ArtKit)
local AnimalBuilder = require(script.Parent.AnimalBuilder)

local CreatureBuilder = {}

local RAINBOW_TAG = "RainbowPart"
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(20, 18, 26)
local PINK = Color3.fromRGB(255, 160, 180)
local GOLD = Color3.fromRGB(255, 215, 80)
local rgb = Color3.fromRGB

-- Couleur plus saturée et plus lumineuse (raretés hautes)
local function vivid(color: Color3): Color3
	local h, sat, v = color:ToHSV()
	return Color3.fromHSV(h, math.min(1, sat * 1.35 + 0.15), math.min(1, v * 1.1 + 0.05))
end

--------------------------------------------------------------------------
-- Contexte de construction
--------------------------------------------------------------------------

type Ctx = {
	Model: Model,
	G: CFrame,
	S: number, -- taille de base de la créature (Config.Creatures[x].Size)
	Color: Color3,
	Accent: Color3,
	Mutation: any,
	Rare: boolean, -- Épique et plus : détails supplémentaires
	Part: (kind: string, name: string, size: any, cf: CFrame, color: Color3, opts: { [string]: any }?) -> BasePart,
	Head: BasePart?,
}

-- opts : Keep (garde sa couleur), Anim, Phase, Hinge, OnHead, Material, Neon, Transparency
local function makeCtx(model: Model, g: CFrame, def: any, mutation: any, rarity: any): Ctx
	local isVivid = rarity.Visual and rarity.Visual.Vivid
	local ctx = {} :: any
	ctx.Model = model
	ctx.G = g
	ctx.S = def.Size
	ctx.Color = if isVivid then vivid(def.Color) else def.Color
	ctx.Accent = if isVivid then vivid(def.Accent) else def.Accent
	ctx.Mutation = mutation
	ctx.Rare = rarity.Order >= 3
	if mutation.Gold then
		ctx.Color = mutation.Color
		ctx.Accent = rgb(255, 240, 150)
	end
	function ctx.Part(kind: string, name: string, size: any, cf: CFrame, color: Color3, opts: { [string]: any }?): BasePart
		local o = opts or {}
		local world = g * cf
		local p
		if kind == "Ball" then
			p = ArtKit.Ball(model, name, size, world, color)
		elseif kind == "Ellipsoid" then
			p = ArtKit.Ellipsoid(model, name, size, world, color)
		elseif kind == "Cylinder" then
			p = ArtKit.Cylinder(model, name, size.X, size.Y, world, color)
		elseif kind == "Wedge" then
			p = ArtKit.Wedge(model, name, size, world, color)
		else
			p = ArtKit.Block(model, name, size, world, color)
		end
		if o.Material then
			p.Material = o.Material
		end
		if o.Neon then
			p.Material = Enum.Material.Neon
		end
		if o.Transparency then
			p.Transparency = o.Transparency
		end
		if mutation.Gold and not o.Keep then
			p.Reflectance = 0.25
		end
		if mutation.Spectral then
			p.Transparency = math.max(p.Transparency, 0.45)
			p.Material = Enum.Material.Neon
		end
		if mutation.Rainbow and not o.Keep then
			p:SetAttribute("HueOffset", math.random())
			CollectionService:AddTag(p, RAINBOW_TAG)
		end
		p:SetAttribute("Anim", o.Anim or "Breathe")
		p:SetAttribute("Phase", o.Phase or 0)
		p:SetAttribute("Hinge", o.Hinge or Vector3.zero)
		if o.OnHead then
			p:SetAttribute("OnHead", true)
		end
		p.CastShadow = size ~= nil and (typeof(size) == "number" and size > 0.4 or typeof(size) == "Vector3" and size.Magnitude > 0.6)
		return p
	end
	return ctx
end

--------------------------------------------------------------------------
-- Pièces communes
--------------------------------------------------------------------------

-- Grands yeux expressifs : blanc, iris coloré (créatures rares), pupille, 2 reflets
local function eyes(ctx: Ctx, head: CFrame, spread: number, size: number, forward: number, iris: Color3?, onHead: boolean?)
	local o = { Keep = true, OnHead = onHead }
	for _, sx in { -1, 1 } do
		local eye = head * CFrame.new(sx * spread, 0, -forward)
		ctx.Part("Ball", "EyeWhite", size, eye, WHITE, o)
		local front = eye * CFrame.new(0, -size * 0.04, -size * 0.3)
		if iris then
			ctx.Part("Ball", "Iris", size * 0.62, front, iris, o)
		end
		ctx.Part("Ball", "Pupil", size * (if iris then 0.4 else 0.58), front * CFrame.new(0, 0, -size * (if iris then 0.12 else 0.04)), BLACK, o)
		ctx.Part("Ball", "EyeShine", size * 0.24, eye * CFrame.new(sx * size * 0.12, size * 0.18, -size * 0.47), WHITE, o)
		ctx.Part("Ball", "EyeShine", size * 0.12, eye * CFrame.new(-sx * size * 0.1, -size * 0.12, -size * 0.48), WHITE, o)
	end
end

local function mouth(ctx: Ctx, cf: CFrame, w: number, onHead: boolean?)
	ctx.Part("Block", "Mouth", Vector3.new(w, w * 0.18, w * 0.15), cf, BLACK, { Keep = true, OnHead = onHead })
end

local function blush(ctx: Ctx, cf: CFrame, spread: number, size: number, onHead: boolean?)
	for _, sx in { -1, 1 } do
		ctx.Part("Ellipsoid", "Blush", Vector3.new(size, size * 0.5, size * 0.3), cf * CFrame.new(sx * spread, 0, 0), PINK, { Keep = true, OnHead = onHead })
	end
end

-- Oreilles : "Point" (triangle), "Round", "Long" (lapin), "Big" (fennec)
local function ears(ctx: Ctx, head: CFrame, d: number, kind: string, color: Color3, inner: Color3?)
	for _, sx in { -1, 1 } do
		local base = head * CFrame.new(sx * d * 0.32, d * 0.4, 0)
		if kind == "Round" then
			ctx.Part("Ball", "Ear", d * 0.38, base * CFrame.new(sx * d * 0.05, 0.05, 0), color, { OnHead = true })
			ctx.Part("Ball", "EarInner", d * 0.22, base * CFrame.new(sx * d * 0.05, 0.05, -d * 0.1), inner or PINK, { Keep = true, OnHead = true })
		elseif kind == "Long" then
			local cf = base * CFrame.new(0, d * 0.45, 0) * CFrame.Angles(0, 0, sx * math.rad(-12))
			ctx.Part("Ellipsoid", "Ear", Vector3.new(d * 0.24, d * 0.95, d * 0.14), cf, color, { OnHead = true })
			ctx.Part("Ellipsoid", "EarInner", Vector3.new(d * 0.12, d * 0.7, d * 0.05), cf * CFrame.new(0, 0, -d * 0.05), inner or PINK, { Keep = true, OnHead = true })
		else
			local w = if kind == "Big" then d * 0.6 else d * 0.38
			local h = if kind == "Big" then d * 0.8 else d * 0.45
			local cf = base * CFrame.new(sx * d * 0.04, h * 0.4, 0) * CFrame.Angles(0, 0, sx * math.rad(-14))
			local l, r = ArtKit.Triangle(ctx.Model, "Ear", w, h, d * 0.12, ctx.G * cf, color)
			local li, ri = ArtKit.Triangle(ctx.Model, "EarInner", w * 0.55, h * 0.6, d * 0.05, ctx.G * cf * CFrame.new(0, -h * 0.1, -d * 0.07), inner or PINK)
			for _, p in { l, r, li, ri } do
				p:SetAttribute("Anim", "Breathe")
				p:SetAttribute("OnHead", true)
				if ctx.Mutation.Gold and (p == l or p == r) then
					p.Color = ctx.Color
				end
				if ctx.Mutation.Rainbow and (p == l or p == r) then
					p:SetAttribute("HueOffset", math.random())
					CollectionService:AddTag(p, RAINBOW_TAG)
				end
			end
		end
	end
end

-- Cornes / bois : "Horns" (2 cornes recourbées), "Antlers" (bois ramifiés), "Unicorn"
local function horns(ctx: Ctx, head: CFrame, d: number, kind: string, color: Color3, leaves: Color3?)
	local o = { OnHead = true }
	if kind == "Antlers" then
		for _, sx in { -1, 1 } do
			local base = head * CFrame.new(sx * d * 0.25, d * 0.45, 0.1)
			local main = base * CFrame.Angles(math.rad(10), 0, sx * math.rad(-30)) * CFrame.new(0, d * 0.4, 0)
			ctx.Part("Cylinder", "Antler", Vector3.new(d * 0.9, d * 0.1), main, color, o)
			for i = 1, 2 do
				local branch = main * CFrame.new(0, -d * 0.25 + i * d * 0.25, 0) * CFrame.Angles(0, 0, sx * math.rad(50)) * CFrame.new(0, d * 0.18, 0)
				ctx.Part("Cylinder", "Antler", Vector3.new(d * 0.4, d * 0.08), branch, color, o)
				if leaves then
					ctx.Part("Ball", "AntlerLeaf", d * 0.2, branch * CFrame.new(0, d * 0.22, 0), leaves, o)
				end
			end
		end
	elseif kind == "Unicorn" then
		ctx.Part("Cylinder", "Horn", Vector3.new(d * 0.7, d * 0.14), head * CFrame.new(0, d * 0.6, -d * 0.2) * CFrame.Angles(math.rad(-25), 0, 0), color, { OnHead = true, Neon = true })
	else
		for _, sx in { -1, 1 } do
			local h1 = head * CFrame.new(sx * d * 0.28, d * 0.45, 0.05) * CFrame.Angles(math.rad(20), 0, sx * math.rad(-25))
			ctx.Part("Cylinder", "Horn", Vector3.new(d * 0.45, d * 0.16), h1 * CFrame.new(0, d * 0.2, 0), color, o)
			ctx.Part("Cylinder", "Horn", Vector3.new(d * 0.35, d * 0.12), h1 * CFrame.new(0, d * 0.4, d * 0.05) * CFrame.Angles(math.rad(50), 0, 0) * CFrame.new(0, d * 0.12, 0), color, o)
		end
	end
end

-- Ailes : "Feather", "Bat", "Leaf", "Crystal", "Flame", "Moth"
local function wings(ctx: Ctx, anchor: CFrame, span: number, kind: string, color: Color3, accent: Color3)
	for _, sx in { -1, 1 } do
		local hinge = Vector3.new(-sx * span * 0.5, 0, 0)
		local base = anchor * CFrame.new(sx * span * 0.5, 0, 0)
		local opts = { Anim = "Wing", Phase = sx, Hinge = hinge }
		if kind == "Feather" or kind == "Flame" then
			for i = 0, 2 do
				local o = table.clone(opts)
				o.Hinge = hinge + Vector3.new(0, 0, -(i - 1) * span * 0.18)
				o.Neon = kind == "Flame"
				ctx.Part("Ellipsoid", "Wing", Vector3.new(span, span * 0.1, span * 0.32), base * CFrame.new(0, -i * span * 0.05, (i - 1) * span * 0.18) * CFrame.Angles(0, sx * math.rad((i - 1) * 15), sx * math.rad(-10)), if i == 1 then color else accent, o)
			end
		elseif kind == "Bat" then
			ctx.Part("Cylinder", "WingBone", Vector3.new(span, span * 0.08), base * CFrame.new(0, span * 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), color, opts)
			local o = table.clone(opts)
			o.Hinge = hinge + Vector3.new(0, span * 0.2, 0)
			ctx.Part("Wedge", "WingMembrane", Vector3.new(span * 0.05, span * 0.55, span * 0.9), base * CFrame.new(0, -span * 0.15, span * 0.1) * CFrame.Angles(0, sx * math.rad(90), 0) * CFrame.Angles(math.pi, 0, 0), accent, o)
		else
			local o = table.clone(opts)
			o.Transparency = if kind == "Crystal" or kind == "Moth" then 0.25 else nil
			o.Material = if kind == "Crystal" then Enum.Material.Glass else nil
			o.Neon = kind == "Crystal"
			ctx.Part("Ellipsoid", "Wing", Vector3.new(span, span * 0.06, span * 0.7), base * CFrame.new(0, span * 0.1, -span * 0.1) * CFrame.Angles(math.rad(-15), 0, sx * math.rad(-20)), color, o)
			ctx.Part("Ellipsoid", "Wing", Vector3.new(span * 0.7, span * 0.05, span * 0.5), base * CFrame.new(-sx * span * 0.1, -span * 0.05, span * 0.3) * CFrame.Angles(math.rad(10), 0, sx * math.rad(-10)), accent, o)
		end
	end
end

-- Queue articulée en segments (de la base vers la pointe)
local function tail(ctx: Ctx, root: CFrame, segments: number, length: number, thick: number, color: Color3, curl: number?, tipColor: Color3?, tipNeon: boolean?)
	local step = length / segments
	local cf = root
	for i = 1, segments do
		local t = thick * (1 - (i - 1) / segments * 0.6)
		cf = cf * CFrame.Angles(math.rad(curl or 0), 0, 0) * CFrame.new(0, 0, step)
		local isTip = i == segments
		ctx.Part("Ball", "Tail", t, cf, if isTip and tipColor then tipColor else color, { Anim = "Tail", Hinge = root.Position - cf.Position, Neon = isTip and tipNeon })
	end
	return cf
end

-- Lueur, particules (feature "Glow" ou mutations)
local function glow(body: BasePart, color: Color3, s: number)
	ArtKit.Light(body, color, 8 + s, 1.5)
	ArtKit.Particles(body, { Color = ColorSequence.new(color), LightEmission = 1, Rate = 5, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.5, 1.2), Size = NumberSequence.new(0.3, 0) })
end

--------------------------------------------------------------------------
-- Silhouettes de base
--------------------------------------------------------------------------

-- Boule sautillante. Renvoie le repère du centre et le diamètre.
local function blob(ctx: Ctx, o: { [string]: any }): (CFrame, number)
	local d = ctx.S * (o.Scale or 1)
	local h = o.Height or 0.9
	local center = CFrame.new(0, d * h * 0.5 + d * 0.06, 0)
	ctx.Part("Ellipsoid", "Shell", Vector3.new(d, d * h, d * (o.Depth or 0.95)), center, o.Color or ctx.Color, { Material = o.Material })
	if o.Belly ~= false then
		ctx.Part("Ellipsoid", "Belly", Vector3.new(d * 0.6, d * h * 0.55, d * 0.2), center * CFrame.new(0, -d * h * 0.12, -d * 0.42), o.Belly or ArtKit.Lighter(o.Color or ctx.Color, 0.35))
	end
	for index, sx in { -1, 1 } do
		ctx.Part("Ellipsoid", "Foot", Vector3.new(d * 0.28, d * 0.16, d * 0.36), CFrame.new(sx * d * 0.24, d * 0.08, -d * 0.18), o.Feet or ArtKit.Darker(o.Color or ctx.Color, 0.15), { Anim = "Leg", Phase = (index - 1) * math.pi, Hinge = Vector3.new(0, d * 0.2, 0) })
	end
	local face = center * CFrame.new(0, d * h * 0.1, -d * 0.36)
	eyes(ctx, face, d * 0.2, d * 0.3, d * 0.05, if ctx.Rare then ctx.Accent else nil)
	mouth(ctx, face * CFrame.new(0, -d * 0.2, -d * 0.1), d * 0.14)
	blush(ctx, face * CFrame.new(0, -d * 0.12, -d * 0.02), d * 0.32, d * 0.16)
	ctx.Model:SetAttribute("Hop", o.Hop ~= false)
	return center, d
end

-- Quadrupède. Renvoie (repère de la tête, diamètre de la tête, repère du corps, dimensions)
local function quad(ctx: Ctx, o: { [string]: any }): (CFrame, number, CFrame, Vector3)
	local s = ctx.S
	local L, H, W = s * (o.Length or 1.3), s * (o.Height or 0.7), s * (o.Width or 0.75)
	local leg = s * (o.Leg or 0.45)
	local legT = s * (o.LegThick or 0.2)
	local color = o.Color or ctx.Color
	local body = CFrame.new(0, leg + H / 2, 0)
	ctx.Part("Ellipsoid", "Shell", Vector3.new(W, H, L), body, color, { Material = o.Material })
	if o.Belly ~= false then
		ctx.Part("Ellipsoid", "Belly", Vector3.new(W * 0.75, H * 0.5, L * 0.75), body * CFrame.new(0, -H * 0.22, 0), o.Belly or ArtKit.Lighter(color, 0.3))
	end
	local legCount = o.Legs or 4
	local rows = legCount / 2
	for row = 0, rows - 1 do
		local z = if rows == 1 then 0 else (-0.5 + row / (rows - 1)) * (L - legT * 2.5)
		for _, sx in { -1, 1 } do
			local phase = if (row + (if sx > 0 then 1 else 0)) % 2 == 0 then 0 else math.pi
			local legCf = CFrame.new(sx * (W / 2 - legT * 0.4), leg / 2 + 0.05, z)
			ctx.Part("Cylinder", "Leg", Vector3.new(leg + H * 0.2, legT), legCf * CFrame.new(0, H * 0.1, 0), o.LegColor or ArtKit.Darker(color, 0.1), { Anim = "Leg", Phase = phase, Hinge = Vector3.new(0, (leg + H * 0.2) / 2, 0) })
			ctx.Part("Ball", "Paw", legT * 1.35, legCf * CFrame.new(0, -leg / 2 + legT * 0.4, -legT * 0.15), o.PawColor or ArtKit.Lighter(color, 0.15), { Anim = "Leg", Phase = phase, Hinge = Vector3.new(0, leg * 0.9, legT * 0.15) })
		end
	end
	-- Cou + tête
	local hd = s * (o.Head or 0.6)
	local neck = s * (o.Neck or 0)
	local headCf
	if neck > 0 then
		local neckCf = body * CFrame.new(0, H * 0.35, -L / 2 + hd * 0.1) * CFrame.Angles(math.rad(-35), 0, 0) * CFrame.new(0, neck / 2, 0)
		ctx.Part("Ellipsoid", "Neck", Vector3.new(hd * 0.6, neck + hd * 0.3, hd * 0.65), neckCf, color)
		headCf = neckCf * CFrame.new(0, neck / 2 + hd * 0.1, -hd * 0.1) * CFrame.Angles(math.rad(35), 0, 0)
	else
		headCf = body * CFrame.new(0, H * 0.3 + (o.HeadUp or 0) * s, -L / 2 - hd * 0.2)
	end
	local head = ctx.Part("Ball", "Head", hd, headCf, o.HeadColor or color, { Anim = "Head", Hinge = Vector3.new(0, -hd * 0.2, hd * 0.5) })
	ctx.Head = head
	if (o.Snout or 0) > 0 then
		local sn = s * o.Snout
		ctx.Part("Ellipsoid", "Snout", Vector3.new(hd * 0.6, hd * 0.45, sn), headCf * CFrame.new(0, -hd * 0.15, -hd * 0.4 - sn * 0.3), o.SnoutColor or ArtKit.Lighter(color, 0.25), { OnHead = true })
		ctx.Part("Ball", "Nose", hd * 0.16, headCf * CFrame.new(0, -hd * 0.05, -hd * 0.42 - sn * 0.75), o.NoseColor or BLACK, { Keep = true, OnHead = true })
	end
	eyes(ctx, headCf * CFrame.new(0, hd * 0.1, 0), hd * 0.24, hd * 0.32, hd * 0.36, if ctx.Rare then ctx.Accent else nil, true)
	if o.Ears then
		ears(ctx, headCf, hd, o.Ears, o.EarColor or color, o.EarInner)
	end
	if o.Tail then
		local root = body * CFrame.new(0, H * 0.15, L / 2 - s * 0.05) * CFrame.Angles(math.rad(o.TailUp or 20), 0, 0)
		tail(ctx, root, o.TailSegments or 3, s * (o.TailLength or 0.6), s * (o.TailThick or 0.18), o.TailColor or color, o.TailCurl, o.TailTip, o.TailTipNeon)
	end
	return headCf, hd, body, Vector3.new(W, H, L)
end

-- Petit volant qui flotte. Renvoie (repère du corps, diamètre)
local function flyer(ctx: Ctx, o: { [string]: any }): (CFrame, number)
	local d = ctx.S * (o.Scale or 0.8)
	local hover = ctx.S * (o.Hover or 0.9)
	local body = CFrame.new(0, hover + d * 0.5, 0)
	ctx.Part("Ellipsoid", "Shell", Vector3.new(d * 0.8, d * 0.9, d * 1.1), body, o.Color or ctx.Color, { Material = o.Material, Transparency = o.Transparency })
	local headCf = body * CFrame.new(0, d * 0.45, -d * 0.35)
	ctx.Part("Ball", "Head", d * 0.75, headCf, o.HeadColor or o.Color or ctx.Color, { Transparency = o.Transparency })
	eyes(ctx, headCf * CFrame.new(0, d * 0.02, 0), d * 0.17, d * 0.26, d * 0.28, ctx.Accent)
	blush(ctx, headCf * CFrame.new(0, -d * 0.14, -d * 0.3), d * 0.24, d * 0.13)
	wings(ctx, body * CFrame.new(0, d * 0.25, d * 0.1), d * (o.Span or 1.4), o.Wings or "Leaf", o.WingColor or ctx.Accent, o.WingAccent or ArtKit.Lighter(ctx.Accent, 0.3))
	ctx.Model:SetAttribute("Flyer", true)
	return body, d
end

-- Oiseau. Renvoie (repère de la tête, diamètre de la tête, repère du corps)
local function bird(ctx: Ctx, o: { [string]: any }): (CFrame, number, CFrame)
	local s = ctx.S
	local color = o.Color or ctx.Color
	local legH = s * 0.35
	local body = CFrame.new(0, legH + s * 0.45, 0) * CFrame.Angles(math.rad(-12), 0, 0)
	ctx.Part("Ellipsoid", "Shell", Vector3.new(s * 0.75, s * 0.8, s * 1.1), body, color)
	ctx.Part("Ellipsoid", "Chest", Vector3.new(s * 0.55, s * 0.6, s * 0.4), body * CFrame.new(0, -s * 0.05, -s * 0.38), o.Chest or ArtKit.Lighter(color, 0.3))
	for index, sx in { -1, 1 } do
		ctx.Part("Cylinder", "Leg", Vector3.new(legH + 0.2, s * 0.08), CFrame.new(sx * s * 0.18, legH / 2, 0.05), rgb(255, 170, 50), { Keep = true, Anim = "Leg", Phase = (index - 1) * math.pi, Hinge = Vector3.new(0, legH / 2 + 0.1, 0) })
		ctx.Part("Ellipsoid", "Foot", Vector3.new(s * 0.2, s * 0.06, s * 0.28), CFrame.new(sx * s * 0.18, 0.03, -s * 0.08), rgb(255, 170, 50), { Keep = true, Anim = "Leg", Phase = (index - 1) * math.pi, Hinge = Vector3.new(0, legH, s * 0.08) })
	end
	local hd = s * 0.55
	local headCf = CFrame.new(0, legH + s * 0.95, -s * 0.45)
	local head = ctx.Part("Ball", "Head", hd, headCf, o.HeadColor or color, { Anim = "Head", Hinge = Vector3.new(0, -hd * 0.4, hd * 0.2) })
	ctx.Head = head
	ctx.Part("Wedge", "Beak", Vector3.new(hd * 0.3, hd * 0.25, hd * 0.5), headCf * CFrame.new(0, -hd * 0.08, -hd * 0.55) * CFrame.Angles(0, math.pi, 0), o.Beak or GOLD, { Keep = true, OnHead = true })
	ctx.Part("Wedge", "Beak", Vector3.new(hd * 0.28, hd * 0.12, hd * 0.35), headCf * CFrame.new(0, -hd * 0.24, -hd * 0.48) * CFrame.Angles(math.pi, math.pi, 0), ArtKit.Darker(o.Beak or GOLD, 0.15), { Keep = true, OnHead = true })
	eyes(ctx, headCf * CFrame.new(0, hd * 0.12, 0), hd * 0.25, hd * 0.3, hd * 0.32, ctx.Accent, true)
	wings(ctx, body * CFrame.new(0, s * 0.2, 0), s * (o.Span or 1.1), o.Wings or "Feather", o.WingColor or color, o.WingAccent or ctx.Accent)
	-- Plumes de queue
	for i = -1, 1 do
		ctx.Part("Ellipsoid", "Tail", Vector3.new(s * 0.18, s * 0.08, s * (o.TailLength or 0.9)), body * CFrame.new(i * s * 0.14, -s * 0.1, s * 0.6 + s * (o.TailLength or 0.9) * 0.3) * CFrame.Angles(math.rad(15), i * math.rad(15), 0), if i == 0 then (o.TailColor or ctx.Accent) else color, { Anim = "Tail", Hinge = Vector3.new(0, 0, -s * 0.4), Neon = o.TailNeon })
	end
	if o.Crest then
		for i = 0, 2 do
			ctx.Part("Ellipsoid", "Crest", Vector3.new(hd * 0.1, hd * 0.6, hd * 0.2), headCf * CFrame.new(0, hd * 0.5, hd * (0.05 + i * 0.12)) * CFrame.Angles(math.rad(-20 - i * 15), 0, 0) * CFrame.new(0, hd * 0.25, 0), o.Crest, { OnHead = true, Neon = o.CrestNeon })
		end
	end
	return headCf, hd, body
end

-- Bipède (debout). Renvoie (repère de la tête, diamètre de la tête, repère du corps)
local function biped(ctx: Ctx, o: { [string]: any }): (CFrame, number, CFrame)
	local s = ctx.S
	local color = o.Color or ctx.Color
	local leg = s * 0.35
	local body = CFrame.new(0, leg + s * 0.5, 0)
	ctx.Part("Ellipsoid", "Shell", Vector3.new(s * 0.95, s * 1.05, s * 0.8), body, color)
	ctx.Part("Ellipsoid", "Belly", Vector3.new(s * 0.6, s * 0.65, s * 0.3), body * CFrame.new(0, -s * 0.05, -s * 0.3), o.Belly or ArtKit.Lighter(color, 0.3))
	for index, sx in { -1, 1 } do
		local phase = (index - 1) * math.pi
		ctx.Part("Ellipsoid", "Leg", Vector3.new(s * 0.32, leg + s * 0.15, s * 0.32), CFrame.new(sx * s * 0.25, leg / 2 + s * 0.07, 0), color, { Anim = "Leg", Phase = phase, Hinge = Vector3.new(0, leg / 2, 0) })
		ctx.Part("Ellipsoid", "Foot", Vector3.new(s * 0.34, s * 0.14, s * 0.48), CFrame.new(sx * s * 0.25, s * 0.07, -s * 0.08), o.Feet or ArtKit.Lighter(color, 0.2), { Anim = "Leg", Phase = phase, Hinge = Vector3.new(0, leg, s * 0.08) })
		ctx.Part("Ellipsoid", "Arm", Vector3.new(s * 0.26, s * 0.65, s * 0.26), body * CFrame.new(sx * s * 0.55, s * 0.0, 0) * CFrame.Angles(0, 0, sx * math.rad(-12)), color, { Anim = "Arm", Phase = phase + math.pi, Hinge = Vector3.new(-sx * s * 0.05, s * 0.3, 0) })
	end
	local hd = s * 0.7
	local headCf = body * CFrame.new(0, s * 0.72, -s * 0.05)
	local head = ctx.Part("Ball", "Head", hd, headCf, o.HeadColor or color, { Anim = "Head", Hinge = Vector3.new(0, -hd * 0.45, 0) })
	ctx.Head = head
	if o.Face then
		ctx.Part("Ellipsoid", "Face", Vector3.new(hd * 0.75, hd * 0.6, hd * 0.25), headCf * CFrame.new(0, -hd * 0.05, -hd * 0.38), o.Face, { Keep = true, OnHead = true })
	end
	eyes(ctx, headCf * CFrame.new(0, hd * 0.05, 0), hd * 0.2, hd * 0.26, hd * 0.42, ctx.Accent, true)
	mouth(ctx, headCf * CFrame.new(0, -hd * 0.22, -hd * 0.5), hd * 0.2, true)
	return headCf, hd, body
end

-- Lézard : quadrupède bas et allongé avec une longue queue
local function lizard(ctx: Ctx, o: { [string]: any }): (CFrame, number, CFrame)
	o.Length = o.Length or 1.6
	o.Height = o.Height or 0.45
	o.Width = o.Width or 0.6
	o.Leg = o.Leg or 0.22
	o.LegThick = o.LegThick or 0.16
	o.Head = o.Head or 0.55
	o.Snout = o.Snout or 0.25
	o.Tail = true
	o.TailSegments = o.TailSegments or 5
	o.TailLength = o.TailLength or 1.2
	o.TailUp = o.TailUp or -5
	o.TailCurl = o.TailCurl or 6
	local headCf, hd, body = quad(ctx, o)
	return headCf, hd, body
end

-- Insecte : carapace + 6 pattes
local function insect(ctx: Ctx, o: { [string]: any }): (CFrame, number, CFrame)
	o.Legs = 6
	o.Length = o.Length or 1.2
	o.Height = o.Height or 0.5
	o.Width = o.Width or 0.9
	o.Leg = o.Leg or 0.22
	o.LegThick = o.LegThick or 0.12
	o.Head = o.Head or 0.5
	o.Belly = false
	local headCf, hd, body, dims = quad(ctx, o)
	-- Carapace segmentée
	for i = -1, 1 do
		ctx.Part("Ellipsoid", "ShellPlate", Vector3.new(dims.X * 0.95, dims.Y * 0.35, dims.Z * 0.36), body * CFrame.new(0, dims.Y * 0.38, i * dims.Z * 0.3), o.PlateColor or ArtKit.Darker(o.Color or ctx.Color, 0.15), { Material = o.PlateMaterial })
	end
	return headCf, hd, body
end

--------------------------------------------------------------------------
-- UNE FONCTION PAR CRÉATURE
--------------------------------------------------------------------------

local DESIGNS = {}

-- 🌲 FORÊT -------------------------------------------------------------

-- Mousselin : boule de mousse avec une pousse sur la tête
function DESIGNS.Mousselin(ctx: Ctx)
	local c, d = blob(ctx, {})
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		ctx.Part("Ball", "Moss", d * 0.32, c * CFrame.new(math.cos(a) * d * 0.25, d * 0.32, math.sin(a) * d * 0.25 + d * 0.05), ArtKit.Darker(ctx.Color, 0.12))
	end
	for _, sx in { -1, 1 } do
		ctx.Part("Ellipsoid", "Sprout", Vector3.new(d * 0.32, d * 0.06, d * 0.16), c * CFrame.new(sx * d * 0.12, d * 0.58, 0) * CFrame.Angles(0, 0, sx * math.rad(25)), rgb(120, 220, 80), { Anim = "Tail", Hinge = Vector3.new(-sx * d * 0.12, -d * 0.05, 0) })
	end
	ctx.Part("Cylinder", "Stem", Vector3.new(d * 0.2, d * 0.05), c * CFrame.new(0, d * 0.5, 0), rgb(90, 160, 60))
end

-- Glandinet : un gland avec son chapeau
function DESIGNS.Glandinet(ctx: Ctx)
	local c, d = blob(ctx, { Height = 1.05, Depth = 0.9 })
	ctx.Part("Ellipsoid", "Cap", Vector3.new(d * 1.08, d * 0.45, d * 1.02), c * CFrame.new(0, d * 0.4, 0), ctx.Accent, { Material = Enum.Material.Slate })
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		ctx.Part("Ball", "CapBump", d * 0.14, c * CFrame.new(math.cos(a) * d * 0.4, d * 0.42, math.sin(a) * d * 0.4), ArtKit.Darker(ctx.Accent, 0.15))
	end
	ctx.Part("Cylinder", "CapStem", Vector3.new(d * 0.22, d * 0.1), c * CFrame.new(0, d * 0.68, 0) * CFrame.Angles(0, 0, math.rad(15)), ArtKit.Darker(ctx.Accent, 0.2), { Anim = "Tail", Hinge = Vector3.new(0, -d * 0.1, 0) })
end

-- Champiloup : louveteau crème avec un chapeau de champignon rouge à pois
function DESIGNS.Champiloup(ctx: Ctx)
	local headCf, hd = quad(ctx, { Length = 1.15, Height = 0.6, Leg = 0.35, Head = 0.62, Snout = 0.25, Ears = "Point", Tail = true, TailLength = 0.5, TailThick = 0.22, TailUp = 40 })
	local cap = headCf * CFrame.new(0, hd * 0.45, hd * 0.05)
	ctx.Part("Ellipsoid", "MushroomCap", Vector3.new(hd * 1.5, hd * 0.6, hd * 1.4), cap, ctx.Accent, { OnHead = true })
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		ctx.Part("Ball", "CapSpot", hd * 0.22, cap * CFrame.new(math.cos(a) * hd * 0.45, hd * 0.14, math.sin(a) * hd * 0.42), WHITE, { Keep = true, OnHead = true })
	end
	ctx.Part("Ball", "CapSpot", hd * 0.25, cap * CFrame.new(0, hd * 0.3, 0), WHITE, { Keep = true, OnHead = true })
end

-- Lucifeuille : fée-luciole aux ailes de feuille, lanterne lumineuse
function DESIGNS.Lucifeuille(ctx: Ctx)
	local body, d = flyer(ctx, { Wings = "Leaf", WingColor = rgb(120, 210, 90), WingAccent = rgb(170, 240, 120) })
	local lantern = ctx.Part("Ball", "Lantern", d * 0.55, body * CFrame.new(0, -d * 0.25, d * 0.55), ctx.Accent, { Neon = true, Anim = "Tail", Hinge = Vector3.new(0, d * 0.2, -d * 0.3) })
	ArtKit.Light(lantern, ctx.Accent, 10, 2)
	for _, sx in { -1, 1 } do
		local antenna = body * CFrame.new(sx * d * 0.12, d * 0.95, -d * 0.35) * CFrame.Angles(0, 0, sx * math.rad(-20))
		ctx.Part("Cylinder", "Antenna", Vector3.new(d * 0.4, d * 0.05), antenna, BLACK, { Keep = true })
		ctx.Part("Ball", "AntennaTip", d * 0.12, antenna * CFrame.new(0, d * 0.22, 0), ctx.Accent, { Neon = true })
	end
end

-- Cerfeuillu : cerf aux bois fleuris, dos tacheté
function DESIGNS.Cerfeuillu(ctx: Ctx)
	local headCf, hd, body, dims = quad(ctx, { Length = 1.3, Height = 0.6, Width = 0.55, Leg = 0.75, LegThick = 0.13, Head = 0.45, Neck = 0.45, Snout = 0.3, Ears = "Point", Tail = true, TailLength = 0.25, TailThick = 0.2, TailColor = WHITE })
	horns(ctx, headCf, hd, "Antlers", rgb(110, 75, 45), ctx.Accent)
	for i = 0, 5 do
		ctx.Part("Ball", "Spot", ctx.S * 0.1, body * CFrame.new((i % 2 - 0.5) * dims.X * 0.4, dims.Y * 0.42, -dims.Z * 0.3 + i * dims.Z * 0.12), rgb(245, 235, 210), { Keep = true })
	end
end

-- Racinor : bête d'écorce aux racines lumineuses
function DESIGNS.Racinor(ctx: Ctx)
	local _, _, body, dims = quad(ctx, { Length = 1.2, Height = 0.8, Width = 0.9, Leg = 0.4, LegThick = 0.3, Head = 0.6, Snout = 0.15, Material = Enum.Material.Wood, Belly = ArtKit.Darker(ctx.Color, 0.2), Ears = "Round" })
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		ctx.Part("Cylinder", "GlowRoot", Vector3.new(dims.Z * 0.7, ctx.S * 0.05), body * CFrame.new(math.cos(a) * dims.X * 0.47, math.sin(a) * dims.Y * 0.3, 0) * CFrame.Angles(math.rad(90), 0, 0), ctx.Accent, { Neon = true })
	end
	for i = -1, 1 do
		ctx.Part("Wedge", "Thorn", Vector3.new(ctx.S * 0.12, ctx.S * 0.4, ctx.S * 0.3), body * CFrame.new(0, dims.Y * 0.55, i * dims.Z * 0.3), rgb(80, 60, 40))
	end
	ctx.Part("Ellipsoid", "MossBack", Vector3.new(dims.X * 0.7, dims.Y * 0.2, dims.Z * 0.6), body * CFrame.new(0, dims.Y * 0.42, 0), rgb(90, 170, 70), { Material = Enum.Material.Grass })
	ctx.Part("Ellipsoid", "Mushroom", Vector3.new(ctx.S * 0.3, ctx.S * 0.15, ctx.S * 0.3), body * CFrame.new(dims.X * 0.25, dims.Y * 0.6, dims.Z * 0.2), rgb(230, 70, 60))
end

-- Murmure-des-Bois : esprit-cerf translucide, orbes de lumière
function DESIGNS.MurmureDesBois(ctx: Ctx)
	local body, d = flyer(ctx, { Scale = 1, Hover = 1.1, Wings = "Moth", Transparency = 0.3, WingColor = ctx.Accent, WingAccent = WHITE, Span = 1.8 })
	horns(ctx, body * CFrame.new(0, d * 0.45, -d * 0.35), d * 0.75, "Antlers", rgb(220, 255, 230), ctx.Accent)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		local orb = ctx.Part("Ball", "SpiritOrb", d * 0.2, body * CFrame.new(math.cos(a) * d * 0.9, math.sin(a * 2) * d * 0.2, math.sin(a) * d * 0.9), ctx.Accent, { Neon = true })
		if i == 0 then
			ArtKit.Light(orb, ctx.Accent, 10, 2)
		end
	end
end

-- Sylvanthe (Divine) : cerf ailé couronné de fleurs
function DESIGNS.Sylvanthe(ctx: Ctx)
	local headCf, hd, body = quad(ctx, { Length = 1.3, Height = 0.6, Width = 0.55, Leg = 0.8, LegThick = 0.13, Head = 0.45, Neck = 0.5, Snout = 0.3, Ears = "Point", Tail = true, TailLength = 0.3, TailColor = WHITE })
	horns(ctx, headCf, hd, "Antlers", GOLD, rgb(255, 150, 200))
	wings(ctx, body * CFrame.new(0, ctx.S * 0.35, 0), ctx.S * 1.3, "Feather", WHITE, ctx.Accent)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		ctx.Part("Ball", "FlowerCrown", hd * 0.2, headCf * CFrame.new(math.cos(a) * hd * 0.4, hd * 0.42, math.sin(a) * hd * 0.35), if i % 2 == 0 then rgb(255, 140, 200) else rgb(255, 240, 120), { OnHead = true, Keep = true })
	end
end

-- ⛰️ MONTAGNE ----------------------------------------------------------

-- Caillouteux : petit caillou vivant avec des plaques de roche et un cristal
function DESIGNS.Caillouteux(ctx: Ctx)
	local c, d = blob(ctx, { Material = Enum.Material.Slate, Belly = rgb(170, 170, 180) })
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + 0.4
		ctx.Part("Wedge", "RockPlate", Vector3.new(d * 0.3, d * 0.25, d * 0.35), c * CFrame.new(math.cos(a) * d * 0.25, d * 0.38, math.sin(a) * d * 0.25 + d * 0.1) * CFrame.Angles(0, a, 0), ArtKit.Darker(ctx.Color, 0.15), { Material = Enum.Material.Slate })
	end
	ctx.Part("Wedge", "Crystal", Vector3.new(d * 0.14, d * 0.45, d * 0.18), c * CFrame.new(0, d * 0.62, d * 0.1), rgb(120, 200, 255), { Neon = true, Anim = "Tail", Hinge = Vector3.new(0, -d * 0.2, 0) })
end

-- Flocon : boule de neige-lapin aux longues oreilles
function DESIGNS.Flocon(ctx: Ctx)
	local c, d = blob(ctx, { Belly = WHITE, Feet = rgb(220, 235, 255) })
	ears(ctx, c * CFrame.new(0, d * 0.15, 0), d * 0.8, "Long", ctx.Color, ctx.Accent)
	ctx.Part("Ball", "Tail", d * 0.3, c * CFrame.new(0, -d * 0.1, d * 0.48), WHITE, { Anim = "Tail" })
	for i = 0, 2 do
		ctx.Part("Wedge", "Frost", Vector3.new(d * 0.05, d * 0.18, d * 0.12), c * CFrame.new((i - 1) * d * 0.12, d * 0.48, d * 0.2), ctx.Accent, { Neon = true })
	end
end

-- Bouquetonnerre : bouquetin aux grandes cornes et à la queue-éclair
function DESIGNS.Bouquetonnerre(ctx: Ctx)
	local headCf, hd, body, dims = quad(ctx, { Length = 1.2, Height = 0.65, Width = 0.6, Leg = 0.6, LegThick = 0.16, Head = 0.5, Neck = 0.25, Snout = 0.25, Ears = "Point", Belly = WHITE })
	horns(ctx, headCf, hd * 1.5, "Horns", ctx.Accent)
	ctx.Part("Wedge", "Beard", Vector3.new(hd * 0.2, hd * 0.4, hd * 0.25), headCf * CFrame.new(0, -hd * 0.5, -hd * 0.4) * CFrame.Angles(math.pi, 0, 0), WHITE, { Keep = true, OnHead = true })
	-- Queue en zigzag lumineuse
	local root = body * CFrame.new(0, dims.Y * 0.3, dims.Z / 2)
	for i = 0, 2 do
		ctx.Part("Block", "BoltTail", Vector3.new(ctx.S * 0.1, ctx.S * 0.32, ctx.S * 0.1), root * CFrame.new((if i % 2 == 0 then 1 else -1) * ctx.S * 0.06, i * ctx.S * 0.22, i * ctx.S * 0.05) * CFrame.Angles(0, 0, (if i % 2 == 0 then 1 else -1) * math.rad(35)), rgb(255, 240, 90), { Neon = true, Anim = "Tail", Hinge = Vector3.new(0, -i * ctx.S * 0.22, 0) })
	end
end

-- Givrelle : papillon de glace aux ailes de cristal
function DESIGNS.Givrelle(ctx: Ctx)
	local body, d = flyer(ctx, { Wings = "Crystal", WingColor = rgb(170, 230, 255), WingAccent = WHITE, Span = 1.6 })
	for i = -1, 1 do
		ctx.Part("Wedge", "IceCrown", Vector3.new(d * 0.08, d * (0.3 + (1 - math.abs(i)) * 0.15), d * 0.14), body * CFrame.new(i * d * 0.15, d * 0.95, -d * 0.35), rgb(200, 240, 255), { Neon = true })
	end
end

-- Grizzlune : ours brun avec un croissant de lune sur le poitrail
function DESIGNS.Grizzlune(ctx: Ctx)
	local _, _, body, dims = quad(ctx, { Length = 1.2, Height = 0.85, Width = 0.95, Leg = 0.35, LegThick = 0.32, Head = 0.65, Snout = 0.22, SnoutColor = rgb(190, 150, 110), Ears = "Round", EarInner = rgb(190, 150, 110), Tail = true, TailSegments = 1, TailLength = 0.15, TailThick = 0.25 })
	-- Croissant de lune (2 disques décalés : un clair, un de la couleur du pelage)
	local chest = body * CFrame.new(0, dims.Y * 0.1, -dims.Z * 0.47)
	ctx.Part("Ball", "Moon", ctx.S * 0.4, chest, ctx.Accent, { Neon = true, Keep = true })
	ctx.Part("Ball", "MoonCut", ctx.S * 0.36, chest * CFrame.new(ctx.S * 0.1, ctx.S * 0.06, -ctx.S * 0.05), ctx.Color)
end

-- Aquilorage : aigle d'orage aux éclairs
function DESIGNS.Aquilorage(ctx: Ctx)
	local _, _, body = bird(ctx, { Span = 1.6, WingAccent = ctx.Accent, Crest = ctx.Accent, CrestNeon = true, Chest = rgb(200, 190, 230), Beak = rgb(255, 200, 60) })
	for _, sx in { -1, 1 } do
		ctx.Part("Block", "Lightning", Vector3.new(ctx.S * 0.06, ctx.S * 0.4, ctx.S * 0.06), body * CFrame.new(sx * ctx.S * 0.4, 0, ctx.S * 0.3) * CFrame.Angles(0, 0, sx * math.rad(30)), rgb(255, 245, 120), { Neon = true })
	end
end

-- Yétinou : bébé yéti tout blanc, visage bleu, petites cornes
function DESIGNS.Yetinou(ctx: Ctx)
	local headCf, hd = biped(ctx, { Face = rgb(140, 200, 255), Feet = rgb(150, 200, 255) })
	horns(ctx, headCf, hd, "Horns", rgb(200, 230, 255))
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		ctx.Part("Ball", "Fluff", hd * 0.3, headCf * CFrame.new(math.cos(a) * hd * 0.35, hd * 0.42, math.sin(a) * hd * 0.3 + hd * 0.1), ctx.Color, { OnHead = true })
	end
end

-- Auroréal (Divine) : oiseau des aurores à longs rubans lumineux
function DESIGNS.Aurorea(ctx: Ctx)
	local _, _, body = bird(ctx, { Span = 1.8, WingColor = ctx.Color, WingAccent = ctx.Accent, Crest = rgb(180, 140, 255), CrestNeon = true, TailLength = 1.4, TailNeon = true })
	local colors = { rgb(120, 255, 200), rgb(140, 170, 255), rgb(230, 140, 255) }
	for i, c in colors do
		ctx.Part("Ellipsoid", "AuroraRibbon", Vector3.new(ctx.S * 0.08, ctx.S * 0.05, ctx.S * 1.6), body * CFrame.new((i - 2) * ctx.S * 0.2, -ctx.S * 0.2, ctx.S * 1.3) * CFrame.Angles(math.rad(10), (i - 2) * math.rad(12), 0), c, { Neon = true, Anim = "Tail", Hinge = Vector3.new(0, 0, -ctx.S * 0.8) })
	end
end

-- 🏜️ DÉSERT ------------------------------------------------------------

-- Dunelle : petite boule-fennec aux oreilles immenses
function DESIGNS.Dunelle(ctx: Ctx)
	local c, d = blob(ctx, { Belly = rgb(255, 240, 210) })
	ears(ctx, c * CFrame.new(0, d * 0.12, 0), d * 0.9, "Big", ctx.Color, rgb(255, 200, 170))
	ctx.Part("Ellipsoid", "Tail", Vector3.new(d * 0.25, d * 0.25, d * 0.55), c * CFrame.new(0, -d * 0.1, d * 0.55) * CFrame.Angles(math.rad(-30), 0, 0), ctx.Accent, { Anim = "Tail", Hinge = Vector3.new(0, 0, -d * 0.25) })
end

-- Scorpinou : petit scorpion aux pinces et au dard recourbé
function DESIGNS.Scorpinou(ctx: Ctx)
	local headCf, hd, body = insect(ctx, { Length = 1, Height = 0.4, Width = 0.8, Head = 0.42 })
	for _, sx in { -1, 1 } do
		local arm = headCf * CFrame.new(sx * hd * 0.55, -hd * 0.1, -hd * 0.2)
		ctx.Part("Cylinder", "PincerArm", Vector3.new(hd * 0.7, hd * 0.18), arm * CFrame.Angles(math.rad(-80), sx * math.rad(-25), 0), ctx.Color, { Anim = "Arm", Phase = (sx + 1) * 1.5, Hinge = Vector3.new(0, 0, hd * 0.3) })
		for _, k in { -1, 1 } do
			ctx.Part("Ellipsoid", "Pincer", Vector3.new(hd * 0.18, hd * 0.12, hd * 0.45), arm * CFrame.new(sx * hd * 0.1 + k * hd * 0.08, 0, -hd * 0.55) * CFrame.Angles(0, k * math.rad(15), 0), ctx.Accent, { Anim = "Arm", Phase = (sx + 1) * 1.5, Hinge = Vector3.new(0, 0, hd * 0.8) })
		end
	end
	local tip = tail(ctx, body * CFrame.new(0, ctx.S * 0.15, ctx.S * 0.45) * CFrame.Angles(math.rad(50), 0, 0), 5, ctx.S * 1.1, ctx.S * 0.2, ctx.Color, -28)
	ctx.Part("Wedge", "Stinger", Vector3.new(ctx.S * 0.1, ctx.S * 0.12, ctx.S * 0.25), tip * CFrame.new(0, -ctx.S * 0.05, -ctx.S * 0.12), BLACK, { Keep = true, Anim = "Tail" })
end

-- Cactouille : petit cactus à fleur rose
function DESIGNS.Cactouille(ctx: Ctx)
	local c, d = blob(ctx, { Height = 1.25, Depth = 0.85, Belly = rgb(150, 210, 120), Feet = rgb(200, 150, 90) })
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		ctx.Part("Wedge", "Spine", Vector3.new(d * 0.03, d * 0.1, d * 0.12), c * CFrame.new(math.cos(a) * d * 0.48, ((i % 3) - 1) * d * 0.3, math.sin(a) * d * 0.43) * CFrame.Angles(0, -a, math.rad(90)), rgb(255, 250, 220), { Keep = true })
	end
	for _, sx in { -1, 1 } do
		ctx.Part("Ellipsoid", "CactusArm", Vector3.new(d * 0.22, d * 0.45, d * 0.22), c * CFrame.new(sx * d * 0.58, d * 0.1, 0) * CFrame.Angles(0, 0, sx * math.rad(-20)), ctx.Color, { Anim = "Arm", Phase = sx, Hinge = Vector3.new(-sx * d * 0.1, -d * 0.2, 0) })
	end
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		ctx.Part("Ball", "Petal", d * 0.2, c * CFrame.new(math.cos(a) * d * 0.13, d * 0.68, math.sin(a) * d * 0.13), ctx.Accent)
	end
	ctx.Part("Ball", "FlowerHeart", d * 0.14, c * CFrame.new(0, d * 0.72, 0), rgb(255, 230, 90), { Keep = true })
end

-- Mirageon : caméléon translucide à collerette
function DESIGNS.Mirageon(ctx: Ctx)
	local headCf, hd = lizard(ctx, { Material = Enum.Material.Glass, TailCurl = 25, TailSegments = 6 })
	for i = -2, 2 do
		ctx.Part("Wedge", "Frill", Vector3.new(hd * 0.05, hd * 0.5, hd * 0.3), headCf * CFrame.new(i * hd * 0.2, hd * 0.35, hd * 0.3) * CFrame.Angles(0, 0, i * math.rad(-20)), ctx.Accent, { OnHead = true, Neon = true, Transparency = 0.3 })
	end
end

-- Sphinxou : chat du désert coiffé d'un némès rayé bleu et or
function DESIGNS.Sphinxou(ctx: Ctx)
	local headCf, hd = quad(ctx, { Length = 1.25, Height = 0.6, Width = 0.6, Leg = 0.45, LegThick = 0.16, Head = 0.6, Snout = 0.12, Ears = "Point", Tail = true, TailSegments = 4, TailLength = 0.9, TailThick = 0.12, TailUp = 60, TailCurl = -15 })
	for i = 0, 5 do
		local band = if i % 2 == 0 then ctx.Accent else GOLD
		for _, sx in { -1, 1 } do
			ctx.Part("Block", "Nemes", Vector3.new(hd * 0.12, hd * 0.8, hd * 0.12), headCf * CFrame.new(sx * hd * (0.45 + i * 0.02), -hd * 0.25, -hd * 0.1 + i * hd * 0.1), band, { Keep = true, OnHead = true })
		end
	end
	ctx.Part("Ellipsoid", "NemesTop", Vector3.new(hd * 1.05, hd * 0.25, hd * 0.9), headCf * CFrame.new(0, hd * 0.38, 0.05), GOLD, { Keep = true, OnHead = true })
	ctx.Part("Ball", "Jewel", hd * 0.15, headCf * CFrame.new(0, hd * 0.4, -hd * 0.45), rgb(80, 200, 255), { Keep = true, OnHead = true, Neon = true })
end

-- Pharaonix : phénix aux ailes de flammes
function DESIGNS.Pharaonix(ctx: Ctx)
	bird(ctx, { Span = 1.6, Wings = "Flame", WingColor = ctx.Color, WingAccent = ctx.Accent, Crest = ctx.Accent, CrestNeon = true, TailLength = 1.3, TailNeon = true, Chest = rgb(255, 220, 120) })
	ArtKit.Particles(ctx.Model:FindFirstChild("Shell") :: BasePart, { Name = "Flames", Color = ColorSequence.new(rgb(255, 220, 80), rgb(255, 80, 20)), LightEmission = 1, Rate = 14, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(1, 2.5), Size = NumberSequence.new(0.5, 0), Acceleration = Vector3.new(0, 4, 0) })
end

-- Oasien : esprit d'oasis en bulle d'eau, feuille de palmier
function DESIGNS.Oasien(ctx: Ctx)
	local body, d = flyer(ctx, { Scale = 1, Hover = 0.8, Material = Enum.Material.Glass, Transparency = 0.35, Wings = "Leaf", WingColor = rgb(90, 190, 90), WingAccent = rgb(140, 230, 120), Span = 1.2 })
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		ctx.Part("Ellipsoid", "PalmLeaf", Vector3.new(d * 0.15, d * 0.05, d * 0.7), body * CFrame.new(math.cos(a) * d * 0.25, d * 1.05, math.sin(a) * d * 0.25) * CFrame.Angles(0, -a + math.pi / 2, math.rad(25)), rgb(80, 180, 80), { Anim = "Tail" })
	end
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		ctx.Part("Ball", "Droplet", d * 0.18, body * CFrame.new(math.cos(a) * d * 0.75, -d * 0.2, math.sin(a) * d * 0.75), ctx.Accent, { Transparency = 0.2, Material = Enum.Material.Glass })
	end
end

-- Solarion (Divine) : lion solaire à crinière de rayons, ailé
function DESIGNS.Solarion(ctx: Ctx)
	local headCf, hd, body = quad(ctx, { Length = 1.3, Height = 0.7, Width = 0.7, Leg = 0.5, LegThick = 0.2, Head = 0.6, Snout = 0.18, Ears = "Round", Tail = true, TailSegments = 4, TailLength = 0.9, TailThick = 0.12, TailTip = GOLD, TailTipNeon = true })
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local ray = headCf * CFrame.new(math.cos(a) * hd * 0.62, math.sin(a) * hd * 0.62, hd * 0.15) * CFrame.Angles(0, 0, a - math.pi / 2)
		local l, r = ArtKit.Triangle(ctx.Model, "SunRay", hd * 0.3, hd * 0.45, hd * 0.1, ctx.G * ray * CFrame.new(0, hd * 0.2, 0), GOLD, Enum.Material.Neon)
		for _, p in { l, r } do
			p:SetAttribute("Anim", "Breathe")
			p:SetAttribute("OnHead", true)
		end
	end
	wings(ctx, body * CFrame.new(0, ctx.S * 0.4, 0), ctx.S * 1.3, "Feather", rgb(255, 245, 210), GOLD)
end

-- 🌋 VOLCAN ------------------------------------------------------------

-- Braisou : petite boule de braise avec une flamme sur la tête
function DESIGNS.Braisou(ctx: Ctx)
	local c, d = blob(ctx, { Belly = rgb(255, 200, 120) })
	local flame = c * CFrame.new(0, d * 0.55, d * 0.05)
	for i, info in { { 0.45, 0.6, ctx.Color }, { 0.28, 0.4, ctx.Accent } } do
		local l, r = ArtKit.Triangle(ctx.Model, "Flame", d * info[1], d * info[2], d * 0.12, ctx.G * flame * CFrame.new(0, d * info[2] * 0.4, -i * 0.02), info[3], Enum.Material.Neon)
		for _, p in { l, r } do
			p:SetAttribute("Anim", "Tail")
			p:SetAttribute("Hinge", Vector3.new(0, -d * 0.2, 0))
		end
	end
	ArtKit.Particles(ctx.Model:FindFirstChild("Shell") :: BasePart, { Name = "Embers", Color = ColorSequence.new(rgb(255, 200, 60), rgb(255, 80, 20)), LightEmission = 1, Rate = 5, Size = NumberSequence.new(0.2, 0), Acceleration = Vector3.new(0, 3, 0) })
end

-- Cendrou : souris de cendre aux fissures orangées
function DESIGNS.Cendrou(ctx: Ctx)
	local c, d = blob(ctx, { Height = 0.85, Belly = rgb(160, 155, 155) })
	ears(ctx, c * CFrame.new(0, d * 0.05, 0), d * 0.85, "Round", ctx.Color, ctx.Accent)
	for i = 0, 3 do
		ctx.Part("Block", "Crack", Vector3.new(d * 0.04, d * 0.25, d * 0.04), c * CFrame.new((i - 1.5) * d * 0.2, d * 0.15, d * 0.45) * CFrame.Angles(0, 0, math.rad((i % 2 - 0.5) * 50)), ctx.Accent, { Neon = true })
	end
	tail(ctx, c * CFrame.new(0, -d * 0.2, d * 0.45), 4, d * 0.8, d * 0.1, ctx.Color, 12)
end

-- Magmoche : scarabée de magma à carapace fissurée et corne
function DESIGNS.Magmoche(ctx: Ctx)
	local headCf, hd, body = insect(ctx, { PlateColor = rgb(40, 25, 25), PlateMaterial = Enum.Material.Basalt })
	for i = -1, 1 do
		ctx.Part("Block", "LavaCrack", Vector3.new(ctx.S * 0.9, ctx.S * 0.05, ctx.S * 0.05), body * CFrame.new(0, ctx.S * 0.28, i * ctx.S * 0.36 + ctx.S * 0.18), ctx.Accent, { Neon = true })
	end
	ctx.Part("Wedge", "Horn", Vector3.new(hd * 0.2, hd * 0.6, hd * 0.4), headCf * CFrame.new(0, hd * 0.45, -hd * 0.2), rgb(60, 40, 35), { OnHead = true })
end

-- Salamandrix : salamandre rouge à pois jaunes, queue de feu
function DESIGNS.Salamandrix(ctx: Ctx)
	local _, _, body = lizard(ctx, { TailTip = ctx.Accent, TailTipNeon = true })
	for i = 0, 5 do
		ctx.Part("Ball", "Spot", ctx.S * 0.16, body * CFrame.new((i % 2 - 0.5) * ctx.S * 0.3, ctx.S * 0.2, -ctx.S * 0.5 + i * ctx.S * 0.2), ctx.Accent, { Keep = true })
	end
end

-- Pyrodrake : dragon aux ailes de chauve-souris, cornes et queue en pointe
function DESIGNS.Pyrodrake(ctx: Ctx)
	local headCf, hd, body, dims = quad(ctx, { Length = 1.35, Height = 0.6, Width = 0.65, Leg = 0.4, LegThick = 0.2, Head = 0.55, Snout = 0.35, Belly = ctx.Accent, Tail = true, TailSegments = 5, TailLength = 1.1, TailThick = 0.2, TailUp = 0, TailCurl = 5 })
	horns(ctx, headCf, hd, "Horns", rgb(240, 220, 180))
	wings(ctx, body * CFrame.new(0, dims.Y * 0.5, -dims.Z * 0.1), ctx.S * 1.1, "Bat", ctx.Color, ctx.Accent)
	for i = 0, 4 do
		ctx.Part("Wedge", "BackSpike", Vector3.new(ctx.S * 0.08, ctx.S * 0.25, ctx.S * 0.2), body * CFrame.new(0, dims.Y * 0.5, -dims.Z * 0.35 + i * dims.Z * 0.18), ctx.Accent)
	end
end

-- Volcanosaure : dinosaure-volcan à plaques dorsales incandescentes
function DESIGNS.Volcanosaure(ctx: Ctx)
	local headCf, hd, body, dims = quad(ctx, { Length = 1.5, Height = 0.75, Width = 0.85, Leg = 0.4, LegThick = 0.3, Head = 0.6, Snout = 0.3, Material = Enum.Material.Basalt, Belly = rgb(90, 60, 50), Tail = true, TailSegments = 4, TailLength = 1, TailThick = 0.35, TailUp = -5 })
	for i = 0, 4 do
		local h = ctx.S * (0.3 + math.sin(i / 4 * math.pi) * 0.25)
		ctx.Part("Wedge", "LavaPlate", Vector3.new(ctx.S * 0.12, h, ctx.S * 0.3), body * CFrame.new(0, dims.Y * 0.5 + h * 0.4, -dims.Z * 0.35 + i * dims.Z * 0.18), ctx.Accent, { Neon = true })
	end
	ctx.Part("Wedge", "NoseHorn", Vector3.new(hd * 0.2, hd * 0.5, hd * 0.35), headCf * CFrame.new(0, hd * 0.25, -hd * 0.55), rgb(220, 200, 170), { OnHead = true })
	ArtKit.Particles(ctx.Model:FindFirstChild("Shell") :: BasePart, { Name = "Smoke", Color = ColorSequence.new(rgb(90, 80, 80)), LightEmission = 0, Rate = 4, Size = NumberSequence.new(0.6, 1.8), Transparency = NumberSequence.new(0.4, 1), Acceleration = Vector3.new(0, 2, 0) })
end

-- Cœur-de-Lave : cœur de magma flottant entouré d'éclats de roche
function DESIGNS.CoeurDeLave(ctx: Ctx)
	local body, d = flyer(ctx, { Scale = 1, Hover = 1, Wings = "Flame", WingColor = ctx.Color, WingAccent = ctx.Accent, Span = 1.2 })
	local shell = ctx.Model:FindFirstChild("Shell") :: BasePart
	shell.Material = Enum.Material.Neon
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		ctx.Part("Wedge", "RockShard", Vector3.new(d * 0.2, d * 0.35, d * 0.25), body * CFrame.new(math.cos(a) * d * 0.85, math.sin(a * 1.5) * d * 0.25, math.sin(a) * d * 0.85) * CFrame.Angles(a, a, 0), rgb(45, 30, 30), { Material = Enum.Material.Basalt })
	end
	ArtKit.Light(shell, ctx.Accent, 14, 2.5)
end

-- Ignaros (Divine) : roi-dragon couronné aux ailes d'or
function DESIGNS.Ignaros(ctx: Ctx)
	local headCf, hd, body, dims = quad(ctx, { Length = 1.45, Height = 0.65, Width = 0.7, Leg = 0.45, LegThick = 0.22, Head = 0.6, Snout = 0.35, Belly = GOLD, Tail = true, TailSegments = 6, TailLength = 1.3, TailThick = 0.22, TailUp = 0, TailCurl = 6, TailTip = GOLD, TailTipNeon = true })
	horns(ctx, headCf, hd * 1.2, "Horns", GOLD)
	wings(ctx, body * CFrame.new(0, dims.Y * 0.5, 0), ctx.S * 1.4, "Bat", ctx.Color, GOLD)
	for i = 0, 4 do
		local a = (i - 2) * 0.35
		ctx.Part("Wedge", "Crown", Vector3.new(hd * 0.1, hd * 0.35, hd * 0.15), headCf * CFrame.new(math.sin(a) * hd * 0.35, hd * 0.55, -math.cos(a) * hd * 0.1), GOLD, { OnHead = true, Neon = true })
	end
	for i = 0, 5 do
		ctx.Part("Wedge", "BackSpike", Vector3.new(ctx.S * 0.08, ctx.S * 0.3, ctx.S * 0.2), body * CFrame.new(0, dims.Y * 0.5, -dims.Z * 0.4 + i * dims.Z * 0.16), ctx.Accent, { Neon = true })
	end
end

--------------------------------------------------------------------------
-- Effets
--------------------------------------------------------------------------

-- Lumière + particules aux couleurs de la rareté
local function addRarityEffects(body: BasePart, rarity: any, accent: Color3)
	local visual = rarity.Visual or {}
	if (visual.Light or 0) > 0 then
		ArtKit.Light(body, rarity.Color, visual.Light, 2)
	end
	if (visual.Particles or 0) > 0 then
		ArtKit.Particles(body, {
			Name = "RarityParticles",
			Color = ColorSequence.new(rarity.Color, accent),
			LightEmission = 1,
			Rate = visual.Particles,
			Lifetime = NumberRange.new(1, 1.8),
			Speed = NumberRange.new(0.8, 2),
			Size = NumberSequence.new(0.45, 0),
		})
	end
end

-- Divine : auréole dorée au-dessus de la tête (avant le calcul de la boîte englobante)
local function divineHalo(ctx: Ctx)
	local s = ctx.S
	local center
	if ctx.Head then
		center = CFrame.new(ctx.G:PointToObjectSpace(ctx.Head.Position)) * CFrame.new(0, ctx.Head.Size.Y * 0.75, 0)
	else
		local cf, size = ctx.Model:GetBoundingBox()
		center = CFrame.new(ctx.G:PointToObjectSpace(cf.Position) + Vector3.new(0, size.Y / 2 + s * 0.25, 0))
	end
	for i = 1, 12 do
		local angle = i / 12 * math.pi * 2
		ctx.Part("Block", "Halo", Vector3.new(s * 0.22, s * 0.06, s * 0.09), center * CFrame.new(math.cos(angle) * s * 0.35, 0, math.sin(angle) * s * 0.35) * CFrame.Angles(0, -angle, 0), GOLD, { Keep = true, Neon = true, OnHead = ctx.Head ~= nil })
	end
end

-- Divine : lumière intense et pluie d'étincelles
local function divineLight(body: BasePart)
	ArtKit.Light(body, rgb(255, 235, 150), 24, 3)
	ArtKit.Particles(body, { Color = ColorSequence.new(rgb(255, 240, 160), WHITE), LightEmission = 1, Rate = 25, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(1, 3), Size = NumberSequence.new(0.5, 0) })
end

-- Taille finale = taille de la rareté x mutation Géante ; le pivot reste au sol
local function applyScale(model: Model, groundCFrame: CFrame, rarity: any, mutation: any)
	local scale = ((rarity.Visual and rarity.Visual.Scale) or 1) * (mutation.Scale or 1)
	model:SetAttribute("RigScale", scale)
	if scale ~= 1 then
		local primary = model.PrimaryPart
		model.PrimaryPart = nil
		model.WorldPivot = groundCFrame
		model:ScaleTo(scale)
		model.PrimaryPart = primary
		if primary then
			primary.PivotOffset = primary.CFrame:ToObjectSpace(groundCFrame) -- pivot toujours au sol
		end
	end
end

-- Partie invisible "Body" (boîte englobante) : pivot, prompts et panneaux
local function addHitbox(model: Model, groundCFrame: CFrame): BasePart
	model.PrimaryPart = nil
	model.WorldPivot = groundCFrame -- boîte englobante alignée sur la créature
	local cf, size = model:GetBoundingBox()
	local local_ = groundCFrame:ToObjectSpace(cf)
	local body = ArtKit.Block(model, "Body", size, groundCFrame * CFrame.new(local_.Position), WHITE, nil, { Transparency = 1, CanQuery = true })
	model.PrimaryPart = body
	body.PivotOffset = body.CFrame:ToObjectSpace(groundCFrame) -- pivot au sol, sous les pieds
	return body
end

-- Les pièces posées sur la tête la suivent quand elle hoche (même articulation)
local function linkHead(ctx: Ctx)
	local head = ctx.Head
	if not head then
		return
	end
	local headHinge = head:GetAttribute("Hinge") or Vector3.zero
	for _, d in ctx.Model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("OnHead") then
			d:SetAttribute("Anim", "Head")
			d:SetAttribute("Hinge", ctx.G:VectorToObjectSpace(head.Position - d.Position) + headHinge)
		end
	end
end

--------------------------------------------------------------------------

-- Renvoie (model, bodyPart). groundCFrame = position au sol, regard vers -Z.
function CreatureBuilder.Build(creatureId: string, mutationId: string, groundCFrame: CFrame): (Model, Part)
	local def = Config.Creatures[creatureId]
	local mutation = CreatureUtil.GetMutation(mutationId)
	local rarity = CreatureUtil.GetRarity(def.Rarity)

	-- 1. Modèle importé (Toolbox / MeshPart) s'il existe
	local custom = ArtKit.Custom("Creatures", creatureId)
	if custom then
		custom.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		ArtKit.PlaceCustom(custom, groundCFrame, true, def.Size * 1.5) -- taille de base de la créature
		ArtKit.SnapToGround(custom, groundCFrame)
		local body = custom.PrimaryPart :: BasePart
		addRarityEffects(body, rarity, def.Accent)
		applyScale(custom, groundCFrame, rarity, mutation)
		return custom, body :: Part
	end

	-- 2. Cheval sauvage : même silhouette que le cheval qu'il deviendra (AnimalBuilder)
	if def.Horse then
		local variantId = Config.Mounts.MutationToVariant[mutationId] or "Normal"
		local model = AnimalBuilder.Build(def.Horse, variantId, groundCFrame)
		model.Name = creatureId
		local visualBody = model.PrimaryPart :: BasePart
		visualBody.Name = "Torso"
		visualBody:SetAttribute("Anim", nil)
		local body = addHitbox(model, groundCFrame)
		addRarityEffects(body, rarity, def.Accent)
		applyScale(model, groundCFrame, rarity, mutation)
		return model, body :: Part
	end

	-- 3. Modèle généré : la fonction de la créature (ou une boule par défaut)
	local model = Instance.new("Model")
	model.Name = creatureId
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local ctx = makeCtx(model, groundCFrame, def, mutation, rarity)
	local design = DESIGNS[creatureId]
	if design then
		design(ctx)
	else
		blob(ctx, {})
	end
	if rarity.Divine then
		divineHalo(ctx)
	end
	linkHead(ctx)
	-- Pattes bien posées SUR le sol (sauf les créatures qui volent)
	if not model:GetAttribute("Flyer") then
		ArtKit.SnapToGround(model, groundCFrame)
	end
	local body = addHitbox(model, groundCFrame)

	-- Lueur (créatures "Glow", et mutations Spectrale / Dorée)
	local hasGlow = table.find(def.Features or {}, "Glow") ~= nil
	if hasGlow or mutation.Spectral or mutation.Gold then
		glow(body, if mutation.Gold then mutation.Color else ctx.Accent, ctx.S)
	end
	if rarity.Divine then
		divineLight(body)
	end
	addRarityEffects(body, rarity, ctx.Accent)
	applyScale(model, groundCFrame, rarity, mutation)
	return model, body :: Part
end

return CreatureBuilder
