--[[
	EnemyBuilder.lua
	================
	Modèles cartoon des ennemis et des boss de donjon (phase 10), construits CÔTÉ CLIENT
	par DungeonRenderer (le serveur n'envoie que des données). Une fonction par ennemi :
	  Ronceux (boule de ronces), Champitox (champignon toxique), Givrelin (lutin de glace),
	  Cognebloc (golem de glace), Scarabix (scarabée), Ventsableux (tourbillon de sable),
	  Braisard (chien de braise), Magmolosse (colosse de magma),
	  Boss : VieuxChene (vieux chêne grognon), ReineGivre (reine du givre),
	         GardienDunes (gardien sphinx), TitanLave (titan de lave).

	  EnemyBuilder.Build(enemyId, cframe) -> (model, body, flashParts, joints)
	    body       : Part invisible (boîte englobante) qui porte la barre de vie
	    flashParts : pièces qui deviennent rouges (attaque) / blanches (touché)
	    joints     : pièces animées { Part, Local, Hinge, Phase, Kind } (pattes, bras)

	Modèle à toi : ReplicatedStorage.CustomModels.Enemies.<id> (le client doit pouvoir le voir).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local EnemyBuilder = {}

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local BLACK = rgb(20, 18, 24)

type Ctx = {
	Model: Model,
	Base: CFrame,
	S: number,
	Def: any,
	Flash: { BasePart },
	JointSpecs: { { Part: BasePart, Hinge: Vector3, Phase: number, Kind: string } },
}

local function newPart(ctx: Ctx, className: string, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	local p = Instance.new(className) :: any
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = ctx.Base * cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = ctx.Model
	return p
end

-- Fonctions de forme. flash = la pièce change de couleur (attaque / touché)
local function block(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, flash: boolean?): BasePart
	local p = newPart(ctx, "Part", name, size, cf, color, material)
	if flash then
		table.insert(ctx.Flash, p)
	end
	return p
end

local function ball(ctx: Ctx, name: string, d: number, cf: CFrame, color: Color3, material: Enum.Material?, flash: boolean?): BasePart
	local p = block(ctx, name, Vector3.one * d, cf, color, material, flash)
	p.Shape = Enum.PartType.Ball
	return p
end

local function ellipsoid(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, flash: boolean?): BasePart
	local p = block(ctx, name, size, cf, color, material, flash)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function cylinder(ctx: Ctx, name: string, height: number, d: number, cf: CFrame, color: Color3, material: Enum.Material?, flash: boolean?): BasePart
	local p = block(ctx, name, Vector3.new(height, d, d), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, flash)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function wedge(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, flash: boolean?): BasePart
	local p = newPart(ctx, "WedgePart", name, size, cf, color, material)
	if flash then
		table.insert(ctx.Flash, p)
	end
	return p
end

-- Triangle debout (2 coins)
local function triangle(ctx: Ctx, name: string, w: number, h: number, depth: number, cf: CFrame, color: Color3, material: Enum.Material?, flash: boolean?)
	local half = w / 2
	wedge(ctx, name, Vector3.new(depth, h, half), cf * CFrame.new(-half / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), color, material, flash)
	wedge(ctx, name, Vector3.new(depth, h, half), cf * CFrame.new(half / 2, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), color, material, flash)
end

local function ArtKit_dark(color: Color3): Color3
	return color:Lerp(Color3.new(0, 0, 0), 0.3)
end

local function joint(ctx: Ctx, part: BasePart, kind: string, phase: number, hinge: Vector3)
	table.insert(ctx.JointSpecs, { Part = part, Kind = kind, Phase = phase, Hinge = hinge })
end

-- Yeux méchants (lumineux) + sourcils froncés
local function angryEyes(ctx: Ctx, cf: CFrame, spread: number, size: number, color: Color3?)
	for _, sx in { -1, 1 } do
		ball(ctx, "Eye", size, cf * CFrame.new(sx * spread, 0, 0), color or rgb(255, 230, 80), Enum.Material.Neon)
		ball(ctx, "Pupil", size * 0.45, cf * CFrame.new(sx * spread, -size * 0.05, -size * 0.4), BLACK)
		block(ctx, "Brow", Vector3.new(size * 1.3, size * 0.25, size * 0.3), cf * CFrame.new(sx * spread, size * 0.6, -size * 0.2) * CFrame.Angles(0, 0, sx * math.rad(22)), BLACK)
	end
end

local function fangs(ctx: Ctx, cf: CFrame, w: number)
	block(ctx, "Mouth", Vector3.new(w, w * 0.25, w * 0.2), cf, BLACK)
	for _, sx in { -1, 1 } do
		wedge(ctx, "Fang", Vector3.new(w * 0.15, w * 0.25, w * 0.12), cf * CFrame.new(sx * w * 0.3, -w * 0.18, -w * 0.05) * CFrame.Angles(math.pi, 0, 0), WHITE)
	end
end

local function legs2(ctx: Ctx, spread: number, h: number, thick: number, color: Color3)
	for i, sx in { -1, 1 } do
		local l = ellipsoid(ctx, "Leg", Vector3.new(thick, h + thick * 0.5, thick), CFrame.new(sx * spread, h / 2, 0), color)
		joint(ctx, l, "Leg", (i - 1) * math.pi, Vector3.new(0, h / 2, 0))
	end
end

local function legs(ctx: Ctx, count: number, w: number, l: number, h: number, thick: number, color: Color3)
	local rows = count / 2
	for row = 0, rows - 1 do
		local z = if rows == 1 then 0 else (-0.5 + row / (rows - 1)) * l
		for _, sx in { -1, 1 } do
			local leg = cylinder(ctx, "Leg", h + 0.2, thick, CFrame.new(sx * w / 2, h / 2, z) * CFrame.Angles(0, 0, sx * math.rad(-15)), color)
			joint(ctx, leg, "Leg", if (row + (if sx > 0 then 1 else 0)) % 2 == 0 then 0 else math.pi, Vector3.new(0, h / 2, 0))
		end
	end
end

--------------------------------------------------------------------------
-- UNE FONCTION PAR ENNEMI
--------------------------------------------------------------------------

local DESIGNS = {}

function DESIGNS.Ronceux(ctx: Ctx)
	local s, d = ctx.S, ctx.Def
	local c = CFrame.new(0, s * 0.55, 0)
	ball(ctx, "Shell", s, c, d.Color, Enum.Material.Grass, true)
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		local tilt = (i % 3 - 1) * 0.5
		wedge(ctx, "Thorn", Vector3.new(s * 0.12, s * 0.35, s * 0.2), c * CFrame.Angles(tilt, a, 0) * CFrame.new(0, 0, s * 0.5) * CFrame.Angles(math.rad(-90), 0, 0), d.Accent, nil, true)
	end
	angryEyes(ctx, c * CFrame.new(0, s * 0.1, -s * 0.45), s * 0.18, s * 0.2)
	fangs(ctx, c * CFrame.new(0, -s * 0.15, -s * 0.47), s * 0.3)
	legs2(ctx, s * 0.25, s * 0.2, s * 0.25, d.Accent)
end

function DESIGNS.Champitox(ctx: Ctx)
	local s, d = ctx.S, ctx.Def
	cylinder(ctx, "Stem", s * 0.7, s * 0.6, CFrame.new(0, s * 0.45, 0), rgb(240, 235, 220), nil, true)
	ellipsoid(ctx, "Cap", Vector3.new(s * 1.3, s * 0.6, s * 1.3), CFrame.new(0, s * 0.95, 0), d.Color, nil, true)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		ball(ctx, "CapSpot", s * 0.18, CFrame.new(math.cos(a) * s * 0.4, s * 1.1, math.sin(a) * s * 0.4), d.Accent)
	end
	angryEyes(ctx, CFrame.new(0, s * 0.55, -s * 0.3), s * 0.14, s * 0.16, rgb(160, 255, 80))
	fangs(ctx, CFrame.new(0, s * 0.35, -s * 0.31), s * 0.25)
	legs2(ctx, s * 0.18, s * 0.15, s * 0.22, rgb(220, 210, 190))
	local spores = Instance.new("ParticleEmitter")
	spores.Color = ColorSequence.new(rgb(160, 255, 80))
	spores.LightEmission = 1
	spores.Rate = 6
	spores.Lifetime = NumberRange.new(1, 2)
	spores.Speed = NumberRange.new(0.5, 1)
	spores.SpreadAngle = Vector2.new(180, 180)
	spores.Size = NumberSequence.new(0.25, 0)
	spores.Parent = ctx.Model:FindFirstChild("Cap")
end

function DESIGNS.Givrelin(ctx: Ctx)
	local s, d = ctx.S, ctx.Def
	local c = CFrame.new(0, s * 0.6, 0)
	ellipsoid(ctx, "Shell", Vector3.new(s, s * 1.05, s * 0.9), c, d.Color, Enum.Material.Glacier, true)
	for i = -1, 1 do
		wedge(ctx, "IceSpike", Vector3.new(s * 0.14, s * (0.45 + (1 - math.abs(i)) * 0.25), s * 0.22), c * CFrame.new(i * s * 0.22, s * 0.55, 0) * CFrame.Angles(0, 0, i * math.rad(-20)), d.Accent, Enum.Material.Glass, true)
	end
	angryEyes(ctx, c * CFrame.new(0, s * 0.1, -s * 0.42), s * 0.18, s * 0.2, rgb(120, 220, 255))
	fangs(ctx, c * CFrame.new(0, -s * 0.15, -s * 0.44), s * 0.3)
	for i, sx in { -1, 1 } do
		local arm = ellipsoid(ctx, "Arm", Vector3.new(s * 0.22, s * 0.55, s * 0.22), c * CFrame.new(sx * s * 0.55, -s * 0.05, 0) * CFrame.Angles(0, 0, sx * math.rad(-25)), d.Color, Enum.Material.Glacier)
		joint(ctx, arm, "Arm", i * math.pi, Vector3.new(-sx * s * 0.05, s * 0.25, 0))
	end
	legs2(ctx, s * 0.22, s * 0.15, s * 0.24, d.Accent)
end

function DESIGNS.Cognebloc(ctx: Ctx)
	local s, d = ctx.S, ctx.Def
	local torso = CFrame.new(0, s * 0.75, 0)
	block(ctx, "Torso", Vector3.new(s * 0.9, s * 0.7, s * 0.6), torso, d.Color, Enum.Material.Glacier, true)
	block(ctx, "Head", Vector3.new(s * 0.5, s * 0.4, s * 0.45), torso * CFrame.new(0, s * 0.5, -s * 0.05), d.Color, Enum.Material.Glacier, true)
	angryEyes(ctx, torso * CFrame.new(0, s * 0.52, -s * 0.28), s * 0.11, s * 0.12, rgb(120, 200, 255))
	for i, sx in { -1, 1 } do
		local arm = block(ctx, "Arm", Vector3.new(s * 0.28, s * 0.6, s * 0.28), torso * CFrame.new(sx * s * 0.6, -s * 0.1, 0), d.Accent, Enum.Material.Glacier)
		joint(ctx, arm, "Arm", i * math.pi, Vector3.new(0, s * 0.3, 0))
		local fist = block(ctx, "Fist", Vector3.new(s * 0.4, s * 0.35, s * 0.4), torso * CFrame.new(sx * s * 0.6, -s * 0.5, 0), d.Color, Enum.Material.Glacier, true)
		joint(ctx, fist, "Arm", i * math.pi, Vector3.new(0, s * 0.7, 0))
	end
	legs2(ctx, s * 0.22, s * 0.4, s * 0.3, d.Accent)
end

function DESIGNS.Scarabix(ctx: Ctx)
	local s, d = ctx.S, ctx.Def
	local c = CFrame.new(0, s * 0.4, 0)
	ellipsoid(ctx, "Shell", Vector3.new(s * 0.9, s * 0.55, s * 1.1), c, d.Color, nil, true)
	block(ctx, "ShellLine", Vector3.new(s * 0.05, s * 0.05, s * 1.05), c * CFrame.new(0, s * 0.27, 0), d.Accent, Enum.Material.Foil)
	for _, sx in { -1, 1 } do
		ball(ctx, "Gem", s * 0.18, c * CFrame.new(sx * s * 0.22, s * 0.2, s * 0.1), d.Accent, Enum.Material.Neon)
	end
	local head = c * CFrame.new(0, -s * 0.02, -s * 0.55)
	ball(ctx, "Head", s * 0.45, head, ArtKit_dark(d.Color), nil, true)
	wedge(ctx, "Horn", Vector3.new(s * 0.12, s * 0.4, s * 0.25), head * CFrame.new(0, s * 0.28, -s * 0.1), d.Accent, Enum.Material.Foil)
	angryEyes(ctx, head * CFrame.new(0, s * 0.03, -s * 0.2), s * 0.12, s * 0.12, rgb(255, 80, 60))
	legs(ctx, 6, s * 0.85, s * 0.7, s * 0.3, s * 0.1, BLACK)
end

function DESIGNS.Ventsableux(ctx: Ctx)
	local s, d = ctx.S, ctx.Def
	for i = 0, 5 do
		local w = s * (0.35 + i * 0.13)
		cylinder(ctx, "Swirl", s * 0.22, w, CFrame.new(0, s * 0.15 + i * s * 0.2, 0) * CFrame.Angles(0, i * 0.7, math.rad((i % 2 - 0.5) * 8)), if i % 2 == 0 then d.Color else d.Accent, Enum.Material.Sand, true)
	end
	angryEyes(ctx, CFrame.new(0, s * 0.95, -s * 0.55), s * 0.2, s * 0.22, rgb(255, 160, 40))
	local sand = Instance.new("ParticleEmitter")
	sand.Color = ColorSequence.new(d.Color, d.Accent)
	sand.Rate = 25
	sand.Lifetime = NumberRange.new(0.6, 1.2)
	sand.Speed = NumberRange.new(4, 7)
	sand.SpreadAngle = Vector2.new(180, 20)
	sand.Size = NumberSequence.new(0.35, 0)
	sand.Parent = ctx.Model:FindFirstChild("Swirl")
end

function DESIGNS.Braisard(ctx: Ctx)
	local s, d = ctx.S, ctx.Def
	local body = CFrame.new(0, s * 0.55, 0)
	ellipsoid(ctx, "Shell", Vector3.new(s * 0.6, s * 0.55, s * 1.1), body, d.Color, nil, true)
	local head = body * CFrame.new(0, s * 0.25, -s * 0.6)
	ball(ctx, "Head", s * 0.5, head, d.Color, nil, true)
	ellipsoid(ctx, "Snout", Vector3.new(s * 0.3, s * 0.22, s * 0.35), head * CFrame.new(0, -s * 0.08, -s * 0.28), ArtKit_dark(d.Color))
	angryEyes(ctx, head * CFrame.new(0, s * 0.08, -s * 0.2), s * 0.12, s * 0.12)
	for _, sx in { -1, 1 } do
		triangle(ctx, "Ear", s * 0.2, s * 0.25, s * 0.06, head * CFrame.new(sx * s * 0.15, s * 0.3, 0), d.Color, nil, true)
	end
	for i = 0, 4 do
		triangle(ctx, "FlameMane", s * 0.25, s * 0.4, s * 0.08, body * CFrame.new(0, s * 0.35, -s * 0.35 + i * s * 0.18), if i % 2 == 0 then d.Accent else rgb(255, 120, 30), Enum.Material.Neon)
	end
	legs(ctx, 4, s * 0.45, s * 0.75, s * 0.35, s * 0.14, ArtKit_dark(d.Color))
	triangle(ctx, "FlameTail", s * 0.2, s * 0.45, s * 0.08, body * CFrame.new(0, s * 0.25, s * 0.6) * CFrame.Angles(math.rad(-40), 0, 0), d.Accent, Enum.Material.Neon)
end

function DESIGNS.Magmolosse(ctx: Ctx)
	local s, d = ctx.S, ctx.Def
	local torso = CFrame.new(0, s * 0.7, 0)
	ellipsoid(ctx, "Torso", Vector3.new(s * 0.95, s * 0.75, s * 0.7), torso, d.Color, Enum.Material.Basalt, true)
	for i = -1, 1 do
		block(ctx, "LavaCrack", Vector3.new(s * 0.06, s * 0.45, s * 0.06), torso * CFrame.new(i * s * 0.22, 0, -s * 0.34) * CFrame.Angles(0, 0, i * 0.5), d.Accent, Enum.Material.Neon)
	end
	ball(ctx, "Head", s * 0.4, torso * CFrame.new(0, s * 0.35, -s * 0.3), d.Color, Enum.Material.Basalt, true)
	angryEyes(ctx, torso * CFrame.new(0, s * 0.38, -s * 0.48), s * 0.09, s * 0.1, d.Accent)
	for i, sx in { -1, 1 } do
		local arm = ellipsoid(ctx, "Arm", Vector3.new(s * 0.35, s * 0.8, s * 0.35), torso * CFrame.new(sx * s * 0.62, -s * 0.15, -s * 0.05), d.Color, Enum.Material.Basalt)
		joint(ctx, arm, "Arm", i * math.pi, Vector3.new(0, s * 0.35, 0))
		local fist = ball(ctx, "Fist", s * 0.42, torso * CFrame.new(sx * s * 0.62, -s * 0.6, -s * 0.05), d.Accent, Enum.Material.Neon, true)
		joint(ctx, fist, "Arm", i * math.pi, Vector3.new(0, s * 0.8, 0))
	end
	legs2(ctx, s * 0.25, s * 0.35, s * 0.32, d.Color)
end

-- 👑 Boss --------------------------------------------------------------

function DESIGNS.VieuxChene(ctx: Ctx)
	local s, d = ctx.S, ctx.Def
	cylinder(ctx, "Trunk", s * 0.8, s * 0.55, CFrame.new(0, s * 0.55, 0), d.Color, Enum.Material.Wood, true)
	for i = 0, 2 do
		ellipsoid(ctx, "Canopy", Vector3.new(s * (0.9 - i * 0.15), s * 0.4, s * (0.9 - i * 0.15)), CFrame.new(0, s * (1.0 + i * 0.22), 0), if i % 2 == 0 then d.Accent else rgb(100, 190, 70), Enum.Material.Grass, true)
	end
	-- Visage d'écorce : gros sourcils, yeux, bouche grognon, barbe de mousse
	angryEyes(ctx, CFrame.new(0, s * 0.7, -s * 0.28), s * 0.1, s * 0.1, rgb(255, 210, 80))
	block(ctx, "Mouth", Vector3.new(s * 0.22, s * 0.05, s * 0.05), CFrame.new(0, s * 0.5, -s * 0.28) * CFrame.Angles(0, 0, 0.05), BLACK)
	ellipsoid(ctx, "MossBeard", Vector3.new(s * 0.3, s * 0.25, s * 0.1), CFrame.new(0, s * 0.38, -s * 0.27), rgb(90, 160, 70), Enum.Material.Grass)
	for i, sx in { -1, 1 } do
		local branch = cylinder(ctx, "Branch", s * 0.55, s * 0.12, CFrame.new(sx * s * 0.45, s * 0.7, 0) * CFrame.Angles(0, 0, sx * math.rad(-55)), d.Color, Enum.Material.Wood)
		joint(ctx, branch, "Arm", i * math.pi, Vector3.new(-sx * s * 0.2, -s * 0.1, 0))
		local leaves = ball(ctx, "BranchLeaves", s * 0.3, CFrame.new(sx * s * 0.68, s * 0.92, 0), d.Accent, Enum.Material.Grass)
		joint(ctx, leaves, "Arm", i * math.pi, Vector3.new(-sx * s * 0.43, -s * 0.32, 0))
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + 0.4
		local root = ellipsoid(ctx, "Root", Vector3.new(s * 0.12, s * 0.12, s * 0.4), CFrame.new(math.cos(a) * s * 0.3, s * 0.05, math.sin(a) * s * 0.3) * CFrame.Angles(0, -a + math.pi / 2, 0), d.Color, Enum.Material.Wood)
		joint(ctx, root, "Leg", i * math.pi / 2, Vector3.new(0, s * 0.1, 0))
	end
end

function DESIGNS.ReineGivre(ctx: Ctx)
	local s, d = ctx.S, ctx.Def
	-- Robe en cône de glace (empilement de disques), buste, tête couronnée
	for i = 0, 4 do
		cylinder(ctx, "Gown", s * 0.14, s * (0.85 - i * 0.12), CFrame.new(0, s * 0.1 + i * s * 0.13, 0), if i % 2 == 0 then d.Color else d.Accent, Enum.Material.Glacier, true)
	end
	ellipsoid(ctx, "Bust", Vector3.new(s * 0.35, s * 0.4, s * 0.28), CFrame.new(0, s * 0.85, 0), d.Color, Enum.Material.Glacier, true)
	local head = CFrame.new(0, s * 1.15, 0)
	ball(ctx, "Head", s * 0.28, head, rgb(220, 240, 255), nil, true)
	angryEyes(ctx, head * CFrame.new(0, s * 0.02, -s * 0.12), s * 0.06, s * 0.06, rgb(120, 200, 255))
	for i = -2, 2 do
		wedge(ctx, "IceCrown", Vector3.new(s * 0.04, s * (0.15 + (2 - math.abs(i)) * 0.06), s * 0.06), head * CFrame.new(i * s * 0.05, s * 0.2, -s * 0.03 * (2 - math.abs(i))), rgb(170, 230, 255), Enum.Material.Neon)
	end
	-- Cape et orbes de glace
	wedge(ctx, "Cape", Vector3.new(s * 0.7, s * 0.9, s * 0.25), CFrame.new(0, s * 0.55, s * 0.25) * CFrame.Angles(0, math.pi, 0), d.Accent, Enum.Material.Fabric, true)
	for i, sx in { -1, 1 } do
		local arm = ellipsoid(ctx, "Arm", Vector3.new(s * 0.09, s * 0.35, s * 0.09), CFrame.new(sx * s * 0.25, s * 0.8, -s * 0.05) * CFrame.Angles(0, 0, sx * math.rad(-30)), d.Color, Enum.Material.Glacier)
		joint(ctx, arm, "Arm", i * math.pi, Vector3.new(-sx * s * 0.05, s * 0.15, 0))
		ball(ctx, "IceOrb", s * 0.16, CFrame.new(sx * s * 0.55, s * 0.95, -s * 0.2), rgb(170, 230, 255), Enum.Material.Neon)
	end
end

function DESIGNS.GardienDunes(ctx: Ctx)
	local s, d = ctx.S, ctx.Def
	local torso = CFrame.new(0, s * 0.55, 0)
	block(ctx, "Torso", Vector3.new(s * 0.7, s * 0.6, s * 0.5), torso, d.Color, Enum.Material.Sandstone, true)
	local head = torso * CFrame.new(0, s * 0.45, -s * 0.05)
	block(ctx, "Head", Vector3.new(s * 0.36, s * 0.34, s * 0.34), head, d.Color, Enum.Material.Sandstone, true)
	-- Némès rayé
	for i = 0, 5 do
		for _, sx in { -1, 1 } do
			block(ctx, "Nemes", Vector3.new(s * 0.05, s * 0.4, s * 0.06), head * CFrame.new(sx * s * 0.2, -s * 0.12, -s * 0.1 + i * s * 0.06), if i % 2 == 0 then d.Accent else rgb(255, 210, 60), Enum.Material.SmoothPlastic)
		end
	end
	block(ctx, "NemesTop", Vector3.new(s * 0.42, s * 0.1, s * 0.4), head * CFrame.new(0, s * 0.2, 0), rgb(255, 210, 60), Enum.Material.Foil)
	angryEyes(ctx, head * CFrame.new(0, s * 0.02, -s * 0.18), s * 0.08, s * 0.08, rgb(80, 200, 255))
	for i, sx in { -1, 1 } do
		local arm = block(ctx, "Arm", Vector3.new(s * 0.18, s * 0.5, s * 0.18), torso * CFrame.new(sx * s * 0.46, -s * 0.05, 0), d.Color, Enum.Material.Sandstone)
		joint(ctx, arm, "Arm", i * math.pi, Vector3.new(0, s * 0.25, 0))
	end
	-- Bâton avec un œil bleu
	cylinder(ctx, "Staff", s * 1.1, s * 0.06, torso * CFrame.new(s * 0.6, 0, -s * 0.2), rgb(255, 210, 60), Enum.Material.Foil)
	ball(ctx, "StaffGem", s * 0.14, torso * CFrame.new(s * 0.6, s * 0.58, -s * 0.2), rgb(80, 200, 255), Enum.Material.Neon)
	legs2(ctx, s * 0.18, s * 0.25, s * 0.22, d.Color)
end

function DESIGNS.TitanLave(ctx: Ctx)
	local s, d = ctx.S, ctx.Def
	local torso = CFrame.new(0, s * 0.62, 0)
	ellipsoid(ctx, "Torso", Vector3.new(s * 0.8, s * 0.65, s * 0.55), torso, d.Color, Enum.Material.Basalt, true)
	local core = ball(ctx, "LavaCore", s * 0.28, torso * CFrame.new(0, s * 0.05, -s * 0.24), d.Accent, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = d.Accent
	light.Range = 24
	light.Brightness = 2
	light.Parent = core
	local head = torso * CFrame.new(0, s * 0.42, -s * 0.08)
	ball(ctx, "Head", s * 0.3, head, d.Color, Enum.Material.Basalt, true)
	angryEyes(ctx, head * CFrame.new(0, s * 0.02, -s * 0.13), s * 0.07, s * 0.07, d.Accent)
	for _, sx in { -1, 1 } do
		wedge(ctx, "Horn", Vector3.new(s * 0.06, s * 0.25, s * 0.1), head * CFrame.new(sx * s * 0.12, s * 0.18, 0) * CFrame.Angles(0, 0, sx * math.rad(-25)), rgb(230, 210, 180))
		local shoulder = ball(ctx, "ShoulderFire", s * 0.25, torso * CFrame.new(sx * s * 0.45, s * 0.25, 0), d.Accent, Enum.Material.Neon)
		local fire = Instance.new("ParticleEmitter")
		fire.Color = ColorSequence.new(rgb(255, 220, 80), rgb(255, 60, 20))
		fire.LightEmission = 1
		fire.Rate = 12
		fire.Lifetime = NumberRange.new(0.4, 0.8)
		fire.Speed = NumberRange.new(2, 4)
		fire.Size = NumberSequence.new(1, 0)
		fire.EmissionDirection = Enum.NormalId.Top
		fire.Parent = shoulder
	end
	for i, sx in { -1, 1 } do
		local arm = ellipsoid(ctx, "Arm", Vector3.new(s * 0.25, s * 0.6, s * 0.25), torso * CFrame.new(sx * s * 0.55, -s * 0.15, 0), d.Color, Enum.Material.Basalt)
		joint(ctx, arm, "Arm", i * math.pi, Vector3.new(0, s * 0.28, 0))
		local fist = ball(ctx, "Fist", s * 0.3, torso * CFrame.new(sx * s * 0.55, -s * 0.5, -s * 0.05), d.Color, Enum.Material.Basalt, true)
		joint(ctx, fist, "Arm", i * math.pi, Vector3.new(0, s * 0.62, 0))
	end
	legs2(ctx, s * 0.22, s * 0.3, s * 0.26, d.Color)
end

--------------------------------------------------------------------------

function EnemyBuilder.Build(enemyId: string, cframe: CFrame): (Model, BasePart, { BasePart }, { any })
	local def = Config.Enemies[enemyId]
	local model: Model
	local ctx: Ctx = { Model = nil :: any, Base = cframe, S = def.Size, Def = def, Flash = {}, JointSpecs = {} }

	local root = ReplicatedStorage:FindFirstChild("CustomModels")
	local customFolder = root and root:FindFirstChild("Enemies")
	local template = customFolder and customFolder:FindFirstChild(enemyId)
	if template and template:IsA("Model") then
		model = template:Clone()
		-- Sécurité : aucun code ni Humanoid dans un modèle importé
		for _, d in model:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") then
				d:Destroy()
			end
		end
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				table.insert(ctx.Flash, p)
			end
		end
		-- Orientation (-Z = avant, attribut "YawOffset" en degrés pour corriger) et taille
		model:PivotTo(cframe * CFrame.Angles(0, math.rad(tonumber(model:GetAttribute("YawOffset")) or 0), 0))
		local extents = model:GetExtentsSize()
		local biggest = math.max(extents.X, extents.Y, extents.Z)
		if biggest > 0.01 then
			model:ScaleTo(model:GetScale() * def.Size * 1.3 / biggest)
		end
		local boxCf = model:GetBoundingBox()
		local offset = cframe:PointToObjectSpace(boxCf.Position)
		model:PivotTo(model:GetPivot() - cframe:VectorToWorldSpace(Vector3.new(offset.X, 0, offset.Z)))
	else
		model = Instance.new("Model")
		ctx.Model = model
		local design = DESIGNS[enemyId]
		if design then
			design(ctx)
		else
			DESIGNS.Ronceux(ctx)
		end
		-- Couronne dorée sur tous les boss
		if def.Boss then
			model.WorldPivot = cframe
			local boxCf, size = model:GetBoundingBox()
			local top = cframe:PointToObjectSpace(boxCf.Position).Y + size.Y / 2
			for i = 1, 6 do
				local a = i / 6 * math.pi * 2
				block(ctx, "Crown", Vector3.new(def.Size * 0.06, def.Size * 0.14, def.Size * 0.06), CFrame.new(math.cos(a) * def.Size * 0.12, top + def.Size * 0.05, math.sin(a) * def.Size * 0.12), rgb(255, 210, 60), Enum.Material.Neon)
			end
		end
	end
	model.Name = def.DisplayName

	-- Pieds bien SUR le sol : la pièce la plus basse touche le sol de l'arène
	model.WorldPivot = cframe
	local boxCf, boxSize = model:GetBoundingBox()
	local bottom = cframe:PointToObjectSpace(boxCf.Position).Y - boxSize.Y / 2
	if math.abs(bottom - 0.02) > 0.005 then
		model:PivotTo(cframe * CFrame.new(0, 0.02 - bottom, 0))
	end
	model.WorldPivot = cframe

	-- Boîte englobante invisible : barre de vie et repère
	local cf, size = model:GetBoundingBox()
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Transparency = 1
	body.Size = size
	body.CFrame = cframe * CFrame.new(cframe:PointToObjectSpace(cf.Position))
	body.Parent = model
	model.PrimaryPart = body
	-- Le pivot du modèle reste AU SOL (sous les pieds), pas au centre de la boîte :
	-- sinon DungeonRenderer, qui place le pivot sur le sol, enfonçait l'ennemi de moitié
	body.PivotOffset = body.CFrame:ToObjectSpace(cframe)

	-- Contour lumineux visible à travers le décor : on voit toujours où sont les ennemis
	local highlight = Instance.new("Highlight")
	highlight.Name = "EnemyOutline"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.OutlineColor = if def.Boss then rgb(255, 215, 60) else rgb(255, 90, 70)
	highlight.OutlineTransparency = 0
	highlight.FillColor = if def.Boss then rgb(255, 200, 80) else rgb(255, 120, 100)
	highlight.FillTransparency = 0.85
	highlight.Parent = model

	-- Articulations : position de chaque pièce par rapport au pivot
	local pivot = model:GetPivot()
	local joints = {}
	for _, spec in ctx.JointSpecs do
		table.insert(joints, { Part = spec.Part, Local = pivot:ToObjectSpace(spec.Part.CFrame), Hinge = spec.Hinge, Phase = spec.Phase, Kind = spec.Kind })
	end
	return model, body, ctx.Flash, joints
end

return EnemyBuilder
