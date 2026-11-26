--[[
	BuildingBuilder.lua
	===================
	Modèles cartoon des bâtiments de transformation (phase 10), une fonction par
	bâtiment derrière une interface commune :

	  BuildingBuilder.Build(buildingId, origin, palette) -> (model, refs)
	    origin  : CFrame au sol, au centre de l'emprise, l'avant (porte) vers -Z
	    palette : cosmétique "Couleurs des bâtiments" ({ Wall, Roof, Pattern... } ou {})
	    refs    : { Walls, Door, WorkFX = { ParticleEmitter, PointLight... }, WorkShow = { BasePart } }

	  Walls (Part principale, porte le panneau d'infos) et Door (porte le ProximityPrompt)
	  existent toujours. WorkFX / WorkShow ne sont visibles QUE quand le bâtiment produit
	  (BuildingService les active). Les pièces qui BOUGENT (roues, aiguille, bobine) sont
	  des Models tagués "BuildingAnim" (attributs Anim = "Spin" | "Bob", Axis, Speed, Amp),
	  animés par le client (BuildingAnimator) seulement quand le bâtiment a l'attribut Working.

	Thèmes :
	  Bakery   Boulangerie : auvent rayé, vitrine (baguettes, croissants, pains), croissant
	                         géant sur le toit, four en briques avec feu.
	  Dairy    Laiterie    : bouteille de lait géante, tête de vache sur la façade reliée à
	                         la bouteille par un tuyau, lait qui coule, taches de vache.
	  Cheese   Fromagerie  : toit en part de fromage à trous, grosse meule, machine à roue.
	  Spinning Filature    : rouet géant qui tourne, pelotes de laine colorées.
	  Tailor   Atelier     : machine à coudre géante (aiguille, bobine), rouleaux de tissu.

	Modèle à toi : ServerStorage.CustomModels.Buildings.<id> (voir ArtKit). Le jeu ajoute
	alors une Part "Walls" et une "Door" invisibles pour le panneau et le prompt.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ArtKit = require(script.Parent.ArtKit)
local PatternBuilder = require(script.Parent.PatternBuilder)

local BuildingBuilder = {}

local ANIM_TAG = "BuildingAnim"
local FOUNDATION = 0.6
local WALL_H = 7
local WOOD = Color3.fromRGB(140, 95, 60)
local DARK_WOOD = Color3.fromRGB(95, 62, 40)
local GLASS = Color3.fromRGB(170, 220, 255)
local WHITE = Color3.new(1, 1, 1)

type Refs = { Walls: BasePart, Door: BasePart, WorkFX: { Instance }, WorkShow: { BasePart } }

--------------------------------------------------------------------------
-- Aides
--------------------------------------------------------------------------

-- Cylindre entre deux points (tuyaux, fils)
local function beam(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material?): BasePart
	local mid = (a + b) / 2
	return ArtKit.Disc(parent, name, (b - a).Magnitude, diameter, CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0), color, material)
end

-- Groupe animé (roue, aiguille...) : Model tagué, pivot = centre de rotation
local function animGroup(parent: Instance, name: string, pivot: CFrame, anim: string, axis: string, speed: number, amp: number?): Model
	local group = Instance.new("Model")
	group.Name = name
	group.WorldPivot = pivot
	group:SetAttribute("Anim", anim)
	group:SetAttribute("Axis", axis)
	group:SetAttribute("Speed", speed)
	group:SetAttribute("Amp", amp or 0)
	CollectionService:AddTag(group, ANIM_TAG)
	group.Parent = parent
	return group
end

-- Roue à rayons dans le plan local XY (axe de rotation = Z local de center)
local function wheel(parent: Instance, center: CFrame, radius: number, rim: Color3, spokes: Color3, segments: number, spokeCount: number, thickness: number?)
	local t = thickness or 0.4
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local len = 2 * math.pi * radius / segments + 0.1
		ArtKit.Block(parent, "Rim", Vector3.new(len, 0.45, t), center * CFrame.Angles(0, 0, a) * CFrame.new(0, radius, 0), rim, Enum.Material.Wood)
	end
	for i = 0, spokeCount - 1 do
		local a = i / spokeCount * math.pi
		ArtKit.Block(parent, "Spoke", Vector3.new(0.22, radius * 2, t * 0.7), center * CFrame.Angles(0, 0, a), spokes, Enum.Material.Wood)
	end
	ArtKit.Disc(parent, "Hub", t + 0.3, radius * 0.3, center * CFrame.Angles(0, math.rad(90), 0), ArtKit.Darker(spokes, 0.2), Enum.Material.Wood)
end

local function smokeEmitter(parent: Instance, refs: Refs)
	local smoke = ArtKit.Particles(parent, {
		Name = "Smoke",
		Color = ColorSequence.new(Color3.fromRGB(235, 235, 235)),
		Transparency = NumberSequence.new(0.25, 1),
		Size = NumberSequence.new(0.8, 2.6),
		Lifetime = NumberRange.new(2, 3),
		Rate = 5,
		Speed = NumberRange.new(2, 3),
		SpreadAngle = Vector2.new(12, 12),
		LightEmission = 0,
		EmissionDirection = Enum.NormalId.Top,
		Enabled = false,
	})
	table.insert(refs.WorkFX, smoke)
end

local function window(parent: Instance, cf: CFrame, w: number, h: number, trim: Color3, flowerBox: boolean?)
	ArtKit.Block(parent, "WindowFrame", Vector3.new(w + 0.5, h + 0.5, 0.25), cf, trim, Enum.Material.Wood)
	ArtKit.Block(parent, "Glass", Vector3.new(w, h, 0.3), cf * CFrame.new(0, 0, -0.04), GLASS, Enum.Material.Glass, { Transparency = 0.25, Reflectance = 0.2 })
	ArtKit.Block(parent, "Mullion", Vector3.new(0.15, h, 0.35), cf * CFrame.new(0, 0, -0.06), trim, Enum.Material.Wood)
	ArtKit.Block(parent, "Mullion", Vector3.new(w, 0.15, 0.35), cf * CFrame.new(0, 0, -0.06), trim, Enum.Material.Wood)
	ArtKit.Block(parent, "Sill", Vector3.new(w + 0.8, 0.25, 0.5), cf * CFrame.new(0, -h / 2 - 0.3, -0.2), trim, Enum.Material.Wood)
	if flowerBox then
		local box = cf * CFrame.new(0, -h / 2 - 0.75, -0.45)
		ArtKit.Block(parent, "FlowerBox", Vector3.new(w + 0.4, 0.6, 0.6), box, WOOD, Enum.Material.WoodPlanks)
		local colors = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 70), Color3.fromRGB(255, 255, 255) }
		for i = -2, 2 do
			ArtKit.Ball(parent, "BoxFlower", 0.45, box * CFrame.new(i * w / 5, 0.45, 0), colors[(i + 3) % 3 + 1])
		end
	end
end

local function hangingSign(parent: Instance, cf: CFrame, width: number, text: string, color: Color3)
	local board = ArtKit.Block(parent, "ShopSign", Vector3.new(width, 1.4, 0.3), cf, color, Enum.Material.WoodPlanks)
	ArtKit.Block(parent, "ShopSignFrame", Vector3.new(width + 0.3, 1.7, 0.2), cf * CFrame.new(0, 0, 0.1), DARK_WOOD, Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(width * 50, 70)
	gui.LightInfluence = 0.4
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 250, 235)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
end

-- Maison de base : fondation, murs, poutres d'angle, fenêtres, porte, toit, enseigne.
-- opts : Width, Depth, OffsetX, Wall, Roof, Trim, Pattern, NoRoof, NoRightWindows, Sign
local function house(model: Model, origin: CFrame, opts: { [string]: any }, refs: Refs): (number, number)
	local w, d, ox = opts.Width, opts.Depth, opts.OffsetX or 0
	local trim = opts.Trim or DARK_WOOD
	local center = origin * CFrame.new(ox, 0, 0)

	ArtKit.Block(model, "Foundation", Vector3.new(w + 0.8, FOUNDATION, d + 0.8), center * CFrame.new(0, FOUNDATION / 2, 0), Color3.fromRGB(150, 145, 140), Enum.Material.Cobblestone)
	local walls = ArtKit.Block(model, "Walls", Vector3.new(w, WALL_H, d), center * CFrame.new(0, FOUNDATION + WALL_H / 2, 0), opts.Wall, Enum.Material.SmoothPlastic, { CanCollide = true, CanQuery = true })
	refs.Walls = walls
	model.PrimaryPart = walls

	-- Poutres d'angle et poutre haute (colombages)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			ArtKit.Block(model, "CornerBeam", Vector3.new(0.6, WALL_H, 0.6), center * CFrame.new(sx * w / 2, FOUNDATION + WALL_H / 2, sz * d / 2), trim, Enum.Material.Wood)
		end
	end
	ArtKit.Block(model, "TopBeam", Vector3.new(w + 0.4, 0.5, d + 0.4), center * CFrame.new(0, FOUNDATION + WALL_H - 0.25, 0), trim, Enum.Material.Wood)

	-- Porte (le prompt y est attaché) + encadrement + poignée
	local frontZ = -d / 2
	local door = ArtKit.Block(model, "Door", Vector3.new(3, 5, 0.3), center * CFrame.new(0, FOUNDATION + 2.5, frontZ - 0.15), Color3.fromRGB(120, 75, 45), Enum.Material.WoodPlanks, { CanQuery = true })
	refs.Door = door
	ArtKit.Block(model, "DoorFrame", Vector3.new(3.6, 5.4, 0.2), center * CFrame.new(0, FOUNDATION + 2.7, frontZ - 0.05), trim, Enum.Material.Wood)
	ArtKit.Ball(model, "DoorKnob", 0.35, center * CFrame.new(1, FOUNDATION + 2.4, frontZ - 0.35), Color3.fromRGB(255, 210, 80), Enum.Material.Metal)
	ArtKit.Block(model, "Doorstep", Vector3.new(3.6, 0.3, 1), center * CFrame.new(0, 0.15, frontZ - 0.7), Color3.fromRGB(170, 165, 160), Enum.Material.Slate)
	-- Paillasson lumineux devant la porte : c'est ici qu'on appuie sur E
	local mat = ArtKit.Block(model, "DoorMat", Vector3.new(4.2, 0.15, 2.4), center * CFrame.new(0, 0.08, frontZ - 2), Color3.fromRGB(255, 205, 80), Enum.Material.Neon, { Transparency = 0.2 })
	ArtKit.Light(mat, Color3.fromRGB(255, 210, 120), 8, 1)

	-- Fenêtres
	if w >= 9.5 then
		for _, sx in { -1, 1 } do
			if not (sx > 0 and opts.NoFrontRightWindow) then
				window(model, center * CFrame.new(sx * (w / 2 - 1.9), FOUNDATION + 3.6, frontZ - 0.13), 1.9, 1.9, trim, true)
			end
		end
	end
	for _, side in { -1, 1 } do
		if not (side > 0 and opts.NoRightWindows) then
			local sideCf = center * CFrame.new(side * (w / 2 + 0.13), FOUNDATION + 3.8, 0) * CFrame.Angles(0, side * math.rad(-90), 0)
			window(model, sideCf, 2, 2, trim, false)
		end
	end

	-- Enseigne au-dessus de la porte
	if opts.Sign then
		hangingSign(model, center * CFrame.new(0, FOUNDATION + 5.9, frontZ - 0.35), math.min(w - 1, 7.5), opts.Sign, opts.SignColor or opts.Roof)
	end

	-- Toit à deux pentes + faîtage + bordures
	local roofTop = FOUNDATION + WALL_H
	if not opts.NoRoof then
		local rh = 3.2
		for _, side in { -1, 1 } do
			ArtKit.Wedge(model, "Roof", Vector3.new(w + 1.2, rh, d / 2 + 0.7), center * CFrame.new(0, roofTop + rh / 2, side * (d / 4 + 0.35)) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0), opts.Roof, Enum.Material.SmoothPlastic)
			ArtKit.Block(model, "Eave", Vector3.new(w + 1.4, 0.3, 0.4), center * CFrame.new(0, roofTop + 0.1, side * (d / 2 + 0.6)), ArtKit.Darker(opts.Roof, 0.25), Enum.Material.SmoothPlastic)
		end
		ArtKit.Disc(model, "Ridge", w + 1.4, 0.6, center * CFrame.new(0, roofTop + rh, 0), ArtKit.Darker(opts.Roof, 0.25), Enum.Material.SmoothPlastic)
		roofTop += rh
	end

	-- Motif cosmétique sur les murs (côtés et arrière)
	if opts.Pattern then
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Back } do
			PatternBuilder.Apply(walls, face, opts.Pattern, { Parent = model, Spacing = 3.4, Size = 2, MaxCount = 14, Color = opts.PatternColor, Accent = opts.PatternAccent })
		end
	end
	return roofTop, frontZ
end

--------------------------------------------------------------------------
-- Bâtiments
--------------------------------------------------------------------------

local BUILDERS = {}

-- 🥖 Boulangerie
function BUILDERS.Bakery(model: Model, origin: CFrame, def: any, palette: any, refs: Refs)
	local W, D = def.Width, def.Depth
	local houseW = W - 3.2
	local ox = -1.6
	local wall = palette.Wall or def.WallColor
	local roof = palette.Roof or def.RoofColor
	local roofTop, frontZ = house(model, origin, { Width = houseW, Depth = D, OffsetX = ox, Wall = wall, Roof = roof, Pattern = palette.Pattern, PatternColor = palette.PatternColor, PatternAccent = palette.PatternAccent, NoRightWindows = true, Sign = "🥖 Boulangerie" }, refs)
	local center = origin * CFrame.new(ox, 0, 0)

	-- Auvent rayé rouge et blanc au-dessus de la façade
	local stripes = 9
	for i = 0, stripes - 1 do
		local x = -houseW / 2 + (i + 0.5) * houseW / stripes
		local color = if i % 2 == 0 then Color3.fromRGB(220, 50, 50) else WHITE
		ArtKit.Block(model, "Awning", Vector3.new(houseW / stripes + 0.02, 0.18, 2.4), center * CFrame.new(x, FOUNDATION + 5.1, frontZ - 1.1) * CFrame.Angles(math.rad(-22), 0, 0), color, Enum.Material.Fabric)
		ArtKit.Ball(model, "AwningScallop", houseW / stripes, center * CFrame.new(x, FOUNDATION + 4.62, frontZ - 2.2), color, Enum.Material.Fabric)
	end

	-- Vitrine : baguettes, croissants et pains derrière la fenêtre gauche
	local shelf = center * CFrame.new(-(houseW / 2 - 1.9), FOUNDATION + 2.75, frontZ - 0.55)
	ArtKit.Block(model, "Shelf", Vector3.new(2.6, 0.2, 0.7), shelf, WOOD, Enum.Material.WoodPlanks)
	local crust = Color3.fromRGB(215, 150, 70)
	for i = -1, 1 do
		ArtKit.Ellipsoid(model, "Baguette", Vector3.new(0.35, 1.7, 0.35), shelf * CFrame.new(i * 0.55, 1.0, 0.1) * CFrame.Angles(0, 0, math.rad(12)), crust)
	end
	ArtKit.Ellipsoid(model, "Loaf", Vector3.new(0.9, 0.55, 0.6), shelf * CFrame.new(0.8, 0.35, -0.1), ArtKit.Darker(crust, 0.1))
	for i = 0, 2 do
		local a = math.rad(-60 + i * 60)
		ArtKit.Ellipsoid(model, "Croissant", Vector3.new(0.45, 0.35, 0.35), shelf * CFrame.new(-0.8 + math.sin(a) * 0.3, 0.3, -math.cos(a) * 0.15) * CFrame.Angles(0, a, 0), Color3.fromRGB(235, 175, 80))
	end

	-- Croissant géant sur le faîtage
	local top = center * CFrame.new(0, roofTop + 1.2, 0)
	for i = 0, 6 do
		local t = i / 6
		local a = math.rad(-80 + t * 160)
		local size = 1.2 + math.sin(t * math.pi) * 1.4
		ArtKit.Ellipsoid(model, "GiantCroissant", Vector3.new(size * 0.9, size, size * 0.8), top * CFrame.new(math.sin(a) * 2.4, math.cos(a) * 1.2 - 0.9 + size * 0.3, 0) * CFrame.Angles(0, 0, -a), if i % 2 == 0 then Color3.fromRGB(230, 165, 70) else Color3.fromRGB(245, 195, 100))
	end

	-- Four en briques (côté droit) avec feu quand ça cuit
	local ovenC = origin * CFrame.new(W / 2 - 1.6, 0, -0.5)
	ArtKit.Block(model, "OvenBase", Vector3.new(3, 1.6, 4), ovenC * CFrame.new(0, 0.8, 0), Color3.fromRGB(170, 80, 60), Enum.Material.Brick)
	ArtKit.Ball(model, "OvenDome", 3.6, ovenC * CFrame.new(0, 1.9, 0), Color3.fromRGB(190, 95, 70), Enum.Material.Brick)
	ArtKit.Disc(model, "OvenMouth", 0.4, 1.8, ovenC * CFrame.new(0, 2.2, -1.65) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(30, 20, 20))
	local fire = ArtKit.Ball(model, "OvenFire", 1.2, ovenC * CFrame.new(0, 2, -1.5), Color3.fromRGB(255, 140, 30), Enum.Material.Neon, { Transparency = 1 })
	table.insert(refs.WorkShow, fire)
	table.insert(refs.WorkFX, ArtKit.Light(fire, Color3.fromRGB(255, 150, 60), 12, 2))
	table.insert(refs.WorkFX, ArtKit.Particles(fire, { Name = "Fire", Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 80, 20)), LightEmission = 1, Rate = 12, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(1, 2), Size = NumberSequence.new(0.5, 0), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Enabled = false }))
	local chimney = ArtKit.Cylinder(model, "Chimney", 4.5, 1.1, ovenC * CFrame.new(0, 4.6, 0.6), Color3.fromRGB(160, 75, 55), Enum.Material.Brick)
	smokeEmitter(chimney, refs)
	-- Pelle à pain posée contre le four
	beam(model, "BreadPeel", ovenC.Position + Vector3.new(0, 0.2, 0) + ovenC.LookVector * 2.3 + ovenC.RightVector * 1.2, ovenC.Position + Vector3.new(0, 3.4, 0) + ovenC.LookVector * 2 + ovenC.RightVector * 1.2, 0.2, WOOD)
end

-- 🥛 Laiterie
function BUILDERS.Dairy(model: Model, origin: CFrame, def: any, palette: any, refs: Refs)
	local W, D = def.Width, def.Depth
	local houseW = W - 4
	local ox = -2
	local wall = palette.Wall or def.WallColor
	local roof = palette.Roof or def.RoofColor
	local roofTop, frontZ = house(model, origin, { Width = houseW, Depth = D, OffsetX = ox, Wall = wall, Roof = roof, Pattern = palette.Pattern, PatternColor = palette.PatternColor, PatternAccent = palette.PatternAccent, NoRightWindows = true, Sign = "🥛 Laiterie" }, refs)
	local center = origin * CFrame.new(ox, 0, 0)
	local black = Color3.fromRGB(35, 35, 40)

	-- Taches de vache sur les murs (si pas de motif cosmétique)
	if not palette.Pattern then
		for i, info in { { -2.2, 2.6, 1.6 }, { 1.8, 5.2, 1.2 }, { 2.6, 2.2, 1 }, { -2.8, 5.6, 0.9 } } do
			ArtKit.Ellipsoid(model, "CowSpot", Vector3.new(info[3] * 1.3, info[3], 0.15), center * CFrame.new(info[1], FOUNDATION + info[2], frontZ - 0.05) * CFrame.Angles(0, 0, i), black)
			ArtKit.Ellipsoid(model, "CowSpot", Vector3.new(0.15, info[3], info[3] * 1.4), center * CFrame.new(-houseW / 2 - 0.05, FOUNDATION + info[2], info[1]), black)
		end
	end

	-- Bouteille de lait géante (à droite)
	local bottle = origin * CFrame.new(W / 2 - 1.9, 0, 0.5)
	ArtKit.Cylinder(model, "BottleBody", 6.5, 3.6, bottle * CFrame.new(0, 3.25, 0), Color3.fromRGB(250, 252, 255), Enum.Material.SmoothPlastic, { Reflectance = 0.1 })
	ArtKit.Ball(model, "BottleShoulder", 3.6, bottle * CFrame.new(0, 6.5, 0), Color3.fromRGB(250, 252, 255))
	ArtKit.Cylinder(model, "BottleNeck", 1.6, 1.7, bottle * CFrame.new(0, 8.5, 0), Color3.fromRGB(250, 252, 255))
	ArtKit.Cylinder(model, "BottleCap", 0.6, 1.9, bottle * CFrame.new(0, 9.5, 0), Color3.fromRGB(60, 130, 220))
	ArtKit.Cylinder(model, "BottleBand", 1.8, 3.7, bottle * CFrame.new(0, 3.5, 0), Color3.fromRGB(70, 140, 230))
	local label = ArtKit.Block(model, "BottleLabel", Vector3.new(2.4, 1.4, 0.2), bottle * CFrame.new(0, 3.5, -1.85), Color3.fromRGB(70, 140, 230))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(200, 100)
	gui.Parent = label
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = WHITE
	text.Text = "LAIT"
	text.Parent = gui

	-- Tête de vache stylisée sur le pignon avant
	local head = center * CFrame.new(0, roofTop - 1.2, frontZ - 0.6)
	ArtKit.Ellipsoid(model, "CowHead", Vector3.new(2.6, 2.2, 1.6), head, WHITE)
	ArtKit.Ellipsoid(model, "CowSpot", Vector3.new(1, 0.8, 0.3), head * CFrame.new(-0.6, 0.5, -0.65), black)
	ArtKit.Ellipsoid(model, "CowMuzzle", Vector3.new(1.9, 1, 0.8), head * CFrame.new(0, -0.65, -0.65), Color3.fromRGB(255, 180, 190))
	for _, sx in { -1, 1 } do
		ArtKit.Ball(model, "Nostril", 0.25, head * CFrame.new(sx * 0.4, -0.6, -1.05), Color3.fromRGB(150, 80, 90))
		ArtKit.Ball(model, "CowEye", 0.45, head * CFrame.new(sx * 0.6, 0.25, -0.75), black)
		ArtKit.Ball(model, "CowEyeShine", 0.15, head * CFrame.new(sx * 0.6 + 0.08, 0.35, -0.95), WHITE)
		ArtKit.Ellipsoid(model, "CowEar", Vector3.new(1, 0.45, 0.3), head * CFrame.new(sx * 1.5, 0.45, 0) * CFrame.Angles(0, 0, sx * math.rad(-20)), Color3.fromRGB(255, 200, 205))
		ArtKit.Cylinder(model, "CowHorn", 0.8, 0.3, head * CFrame.new(sx * 0.8, 1.25, 0) * CFrame.Angles(0, 0, sx * math.rad(-30)), Color3.fromRGB(245, 235, 200))
	end

	-- Tuyau : de la tête de vache jusqu'au goulot de la bouteille
	local p0 = (head * CFrame.new(1.2, -0.3, 0.3)).Position
	local pipeY = (bottle * CFrame.new(0, 11.8, 0)).Position.Y -- au-dessus du faîtage
	local p1 = Vector3.new(p0.X, pipeY, p0.Z)
	local p2 = (bottle * CFrame.new(0, 11.8, 0)).Position
	local pipeColor = Color3.fromRGB(180, 185, 195)
	beam(model, "Pipe", p0, p1, 0.5, pipeColor, Enum.Material.Metal)
	beam(model, "Pipe", p1, p2, 0.5, pipeColor, Enum.Material.Metal)
	ArtKit.Ball(model, "PipeElbow", 0.6, CFrame.new(p1), pipeColor, Enum.Material.Metal)
	ArtKit.Ball(model, "PipeElbow", 0.6, CFrame.new(p2), pipeColor, Enum.Material.Metal)
	-- Le lait coule du tuyau dans la bouteille (visible seulement en production)
	local stream = ArtKit.Cylinder(model, "MilkStream", 2, 0.3, CFrame.new(p2 - Vector3.new(0, 1, 0)), WHITE, Enum.Material.SmoothPlastic, { Transparency = 1 })
	table.insert(refs.WorkShow, stream)
	table.insert(refs.WorkFX, ArtKit.Particles(stream, { Name = "MilkDrops", Color = ColorSequence.new(WHITE), LightEmission = 0, Rate = 10, Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(3, 4), Size = NumberSequence.new(0.25, 0.1), EmissionDirection = Enum.NormalId.Left, SpreadAngle = Vector2.new(5, 5), Acceleration = Vector3.new(0, -20, 0), Enabled = false }))

	-- Caisse de petites bouteilles devant la porte
	local crate = center * CFrame.new(-houseW / 2 + 1.4, 0, frontZ - 1.6)
	ArtKit.Block(model, "MilkCrate", Vector3.new(2, 0.9, 1.4), crate * CFrame.new(0, 0.45, 0), Color3.fromRGB(60, 130, 220))
	for i = -1, 1 do
		for j = 0, 1 do
			ArtKit.Cylinder(model, "SmallBottle", 1, 0.45, crate * CFrame.new(i * 0.6, 1.2, -0.3 + j * 0.6), WHITE)
		end
	end
	local chimney = ArtKit.Block(model, "Chimney", Vector3.new(1.2, 3, 1.2), center * CFrame.new(-houseW / 2 + 1.5, roofTop - 1, D / 4), Color3.fromRGB(120, 90, 80), Enum.Material.Brick)
	smokeEmitter(chimney, refs)
end

-- 🧀 Fromagerie
function BUILDERS.Cheese(model: Model, origin: CFrame, def: any, palette: any, refs: Refs)
	local W, D = def.Width, def.Depth
	local houseW = W - 2.4
	local ox = -1.2
	local wall = palette.Wall or def.WallColor
	local cheese = Color3.fromRGB(255, 205, 70)
	local rind = Color3.fromRGB(230, 150, 40)
	local roofTop, frontZ = house(model, origin, { Width = houseW, Depth = D, OffsetX = ox, Wall = wall, Roof = palette.Roof or def.RoofColor, Pattern = palette.Pattern, PatternColor = palette.PatternColor, PatternAccent = palette.PatternAccent, NoRoof = true, NoRightWindows = true, Sign = "🧀 Fromagerie" }, refs)
	local center = origin * CFrame.new(ox, 0, 0)

	-- Toit = grosse part de fromage (coin qui monte vers l'arrière) avec des trous
	local roofH = 3.6
	local roofColor = palette.Roof or cheese
	ArtKit.Wedge(model, "CheeseRoof", Vector3.new(houseW + 1, roofH, D + 1), center * CFrame.new(0, roofTop + roofH / 2, 0), roofColor)
	ArtKit.Block(model, "CheeseRind", Vector3.new(houseW + 1.1, 0.5, D + 1.1), center * CFrame.new(0, roofTop + 0.25, 0), rind)
	-- Trous sur les flancs (dans le triangle du coin : plus haut vers l'arrière)
	for _, info in { { 0.45, 0.5, 0.9 }, { 0.7, 0.35, 0.7 }, { 0.88, 0.6, 0.8 }, { 0.62, 0.75, 0.5 } } do
		local depth = D + 1
		local z = -depth / 2 + info[1] * depth
		local y = roofTop + 0.5 + info[2] * (roofH * info[1] - 0.9)
		for _, sx in { -1, 1 } do
			ArtKit.Disc(model, "CheeseHole", 0.2, info[3], center * CFrame.new(sx * (houseW / 2 + 0.5), y, z), ArtKit.Darker(roofColor, 0.2))
		end
	end
	roofTop += roofH

	-- Grosse meule (devant à gauche)
	local wheelCf = center * CFrame.new(-houseW / 2 + 1.2, 1.4, frontZ - 1.6) * CFrame.Angles(0, math.rad(90), 0)
	ArtKit.Disc(model, "CheeseWheel", 1.8, 2.8, wheelCf, cheese)
	ArtKit.Disc(model, "CheeseWheelRind", 1.6, 2.95, wheelCf, rind)
	for _, sx in { -1, 1 } do
		ArtKit.Disc(model, "CheeseHole", 0.1, 0.5, wheelCf * CFrame.new(sx * 0.92, 0.5, 0.3), ArtKit.Darker(cheese, 0.2))
		ArtKit.Disc(model, "CheeseHole", 0.1, 0.35, wheelCf * CFrame.new(sx * 0.92, -0.4, -0.5), ArtKit.Darker(cheese, 0.2))
	end

	-- Machine à roue (côté droit) : la roue tourne quand ça produit
	local machine = origin * CFrame.new(W / 2 - 1, 0, 0)
	ArtKit.Block(model, "Machine", Vector3.new(1.8, 4, 4), machine * CFrame.new(0, 2, 0), Color3.fromRGB(150, 155, 165), Enum.Material.Metal)
	ArtKit.Block(model, "MachineVat", Vector3.new(1.9, 1.2, 4.2), machine * CFrame.new(0, 4.4, 0), cheese)
	local axle = machine * CFrame.new(0.95, 2.6, 0) * CFrame.Angles(0, math.rad(90), 0) -- axe = X monde
	local spin = animGroup(model, "CheeseWheelMachine", axle, "Spin", "Z", 1.4)
	wheel(spin, axle, 1.7, Color3.fromRGB(200, 60, 50), Color3.fromRGB(230, 230, 230), 14, 4, 0.35)
	local chimney = ArtKit.Cylinder(model, "Chimney", 3, 0.8, machine * CFrame.new(0, 6.5, 1.2), Color3.fromRGB(120, 125, 135), Enum.Material.Metal)
	smokeEmitter(chimney, refs)
end

-- 🧶 Filature
function BUILDERS.Spinning(model: Model, origin: CFrame, def: any, palette: any, refs: Refs)
	local W, D = def.Width, def.Depth
	local houseW = W - 4.4
	local ox = -2.2
	local wall = palette.Wall or def.WallColor
	local roof = palette.Roof or def.RoofColor
	local roofTop, frontZ = house(model, origin, { Width = houseW, Depth = D, OffsetX = ox, Wall = wall, Roof = roof, Pattern = palette.Pattern, PatternColor = palette.PatternColor, PatternAccent = palette.PatternAccent, NoRightWindows = true, Sign = "🧶 Filature" }, refs)
	local center = origin * CFrame.new(ox, 0, 0)

	-- Rouet géant (à droite), roue face à l'allée
	local base = origin * CFrame.new(W / 2 - 2, 0, -1)
	ArtKit.Block(model, "SpinnerTable", Vector3.new(3.2, 0.5, 2.4), base * CFrame.new(0, 1.6, 0), WOOD, Enum.Material.WoodPlanks)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			ArtKit.Block(model, "SpinnerLeg", Vector3.new(0.35, 1.6, 0.35), base * CFrame.new(sx * 1.3, 0.8, sz * 0.9) * CFrame.Angles(sz * math.rad(8), 0, sx * math.rad(-8)), DARK_WOOD, Enum.Material.Wood)
		end
		ArtKit.Block(model, "WheelUpright", Vector3.new(0.35, 3.6, 0.35), base * CFrame.new(sx * 0.4, 3.5, 0.4), DARK_WOOD, Enum.Material.Wood)
	end
	local wheelCenter = base * CFrame.new(0, 4.6, 0.4)
	local spin = animGroup(model, "SpinningWheel", wheelCenter, "Spin", "Z", 1.6)
	wheel(spin, wheelCenter, 2.4, Color3.fromRGB(170, 115, 70), Color3.fromRGB(205, 160, 110), 18, 4, 0.35)
	-- Bobine et fil
	local bobbin = base * CFrame.new(-1.1, 2.4, -0.6)
	ArtKit.Disc(model, "Bobbin", 1.2, 0.7, bobbin, Color3.fromRGB(255, 130, 180), Enum.Material.Fabric)
	beam(model, "Thread", bobbin.Position, (wheelCenter * CFrame.new(0, -2.4, 0)).Position, 0.08, Color3.fromRGB(255, 130, 180))

	-- Pelotes de laine colorées devant la porte
	local yarnColors = { Color3.fromRGB(255, 120, 170), Color3.fromRGB(120, 180, 255), Color3.fromRGB(255, 220, 80), Color3.fromRGB(140, 220, 120), Color3.fromRGB(200, 140, 255) }
	local pile = center * CFrame.new(-houseW / 2 + 1.5, 0, frontZ - 1.6)
	for i, info in { { 0, 0.55, 0, 1.1 }, { 0.9, 0.5, 0.2, 1 }, { 0.45, 1.35, 0.1, 0.9 }, { -0.9, 0.45, 0.3, 0.9 }, { 1.8, 0.4, -0.2, 0.8 } } do
		local color = yarnColors[i]
		local yarn = pile * CFrame.new(info[1], info[2], info[3])
		ArtKit.Ball(model, "Yarn", info[4], yarn, color, Enum.Material.Fabric)
		ArtKit.Disc(model, "YarnWrap", 0.08, info[4] * 1.02, yarn * CFrame.Angles(0, math.rad(i * 37), math.rad(30)), ArtKit.Darker(color, 0.2), Enum.Material.Fabric)
	end
	beam(model, "KnittingNeedle", (pile * CFrame.new(0.3, 1.6, 0)).Position, (pile * CFrame.new(0.7, 2.6, 0.3)).Position, 0.1, Color3.fromRGB(200, 200, 210), Enum.Material.Metal)

	-- Grosse pelote sur le toit
	local big = center * CFrame.new(houseW / 4, roofTop + 0.6, 0)
	ArtKit.Ball(model, "RoofYarn", 2.6, big, yarnColors[1], Enum.Material.Fabric)
	ArtKit.Disc(model, "RoofYarnWrap", 0.12, 2.65, big * CFrame.Angles(0, 0, math.rad(35)), ArtKit.Darker(yarnColors[1], 0.2), Enum.Material.Fabric)
	ArtKit.Disc(model, "RoofYarnWrap", 0.12, 2.65, big * CFrame.Angles(0, math.rad(90), math.rad(-25)), ArtKit.Darker(yarnColors[1], 0.2), Enum.Material.Fabric)
	local chimney = ArtKit.Block(model, "Chimney", Vector3.new(1.2, 3, 1.2), center * CFrame.new(-houseW / 2 + 1.5, roofTop - 1.8, D / 4), Color3.fromRGB(120, 90, 80), Enum.Material.Brick)
	smokeEmitter(chimney, refs)
end

-- 🪡 Atelier de couture
function BUILDERS.Tailor(model: Model, origin: CFrame, def: any, palette: any, refs: Refs)
	local W, D = def.Width, def.Depth
	local houseW = W - 5
	local ox = -2.5
	local wall = palette.Wall or def.WallColor
	local roof = palette.Roof or def.RoofColor
	local roofTop, frontZ = house(model, origin, { Width = houseW, Depth = D, OffsetX = ox, Wall = wall, Roof = roof, Pattern = palette.Pattern, PatternColor = palette.PatternColor, PatternAccent = palette.PatternAccent, NoRightWindows = true, Sign = "🪡 Couture" }, refs)
	local center = origin * CFrame.new(ox, 0, 0)

	-- Gros boutons décoratifs sur la façade
	for _, info in { { -2.6, 6.4, Color3.fromRGB(255, 200, 60) }, { 2.6, 6.4, Color3.fromRGB(90, 170, 255) } } do
		local cf = center * CFrame.new(info[1], FOUNDATION + info[2], frontZ - 0.1) * CFrame.Angles(0, math.rad(90), 0)
		ArtKit.Disc(model, "Button", 0.2, 1.2, cf, info[3])
		for _, o in { { -0.2, -0.2 }, { 0.2, -0.2 }, { -0.2, 0.2 }, { 0.2, 0.2 } } do
			ArtKit.Disc(model, "ButtonHole", 0.25, 0.18, cf * CFrame.new(0, o[1], o[2]), ArtKit.Darker(info[3], 0.4))
		end
	end

	-- Machine à coudre géante (à droite)
	local m = origin * CFrame.new(W / 2 - 2.4, 0, -0.5)
	local body = Color3.fromRGB(240, 240, 245)
	local accent = palette.Roof or def.RoofColor
	ArtKit.Block(model, "SewingTable", Vector3.new(4.4, 0.6, 3.4), m * CFrame.new(0, 2.6, 0), WOOD, Enum.Material.WoodPlanks)
	for _, sx in { -1, 1 } do
		ArtKit.Block(model, "SewingTableLeg", Vector3.new(0.4, 2.4, 3), m * CFrame.new(sx * 1.9, 1.2, 0), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	end
	ArtKit.Block(model, "SewingBase", Vector3.new(4, 0.7, 2.2), m * CFrame.new(0, 3.25, 0), body)
	ArtKit.Block(model, "SewingPillar", Vector3.new(1.1, 3, 1.6), m * CFrame.new(1.4, 5.1, 0), body)
	ArtKit.Block(model, "SewingArm", Vector3.new(4, 1.1, 1.5), m * CFrame.new(0, 6.6, 0), body)
	ArtKit.Block(model, "SewingStripe", Vector3.new(4.05, 0.3, 1.55), m * CFrame.new(0, 6.6, 0), accent)
	ArtKit.Block(model, "SewingHead", Vector3.new(1, 1.5, 1.4), m * CFrame.new(-1.6, 6.3, 0), body)
	-- Volant (roue à main) : tourne en production
	local handAxis = m * CFrame.new(2.05, 5.6, 0) * CFrame.Angles(0, math.rad(90), 0)
	local hand = animGroup(model, "HandWheel", handAxis, "Spin", "Z", 3)
	ArtKit.Disc(hand, "HandWheel", 0.3, 1.6, handAxis * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(90, 90, 100), Enum.Material.Metal)
	ArtKit.Block(hand, "HandWheelMark", Vector3.new(0.3, 0.7, 0.32), handAxis * CFrame.new(0, 0.4, 0), accent)
	-- Aiguille qui monte et descend
	local needlePivot = m * CFrame.new(-1.6, 5.1, 0)
	local needle = animGroup(model, "Needle", needlePivot, "Bob", "Y", 10, 0.35)
	ArtKit.Cylinder(needle, "Needle", 1.2, 0.12, needlePivot, Color3.fromRGB(210, 210, 220), Enum.Material.Metal)
	-- Bobine de fil sur le dessus : tourne en production
	local spoolCf = m * CFrame.new(0.4, 7.6, 0)
	local spool = animGroup(model, "Spool", spoolCf, "Spin", "Y", 2.5)
	ArtKit.Cylinder(spool, "Spool", 0.9, 0.7, spoolCf, Color3.fromRGB(255, 90, 130), Enum.Material.Fabric)
	ArtKit.Cylinder(spool, "SpoolCap", 0.12, 0.95, spoolCf * CFrame.new(0, 0.5, 0), WOOD, Enum.Material.Wood)
	ArtKit.Cylinder(spool, "SpoolCap", 0.12, 0.95, spoolCf * CFrame.new(0, -0.5, 0), WOOD, Enum.Material.Wood)
	beam(model, "Thread", spoolCf.Position, (m * CFrame.new(-1.6, 6.9, -0.6)).Position, 0.06, Color3.fromRGB(255, 90, 130))
	-- Tissu sous l'aiguille
	ArtKit.Block(model, "FabricPiece", Vector3.new(2.4, 0.08, 1.8), m * CFrame.new(-1.2, 3.62, 0) * CFrame.Angles(0, math.rad(10), 0), Color3.fromRGB(120, 200, 255), Enum.Material.Fabric)

	-- Rouleaux de tissu devant la porte
	local rolls = center * CFrame.new(-houseW / 2 + 1.3, 0, frontZ - 1.6)
	local fabrics = { Color3.fromRGB(255, 120, 160), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 220, 90), Color3.fromRGB(150, 220, 130) }
	for i, info in { { 0, 0.5 }, { 0, 1.45 }, { 0, 2.4 } } do
		ArtKit.Disc(model, "FabricRoll", 2.4, 0.95, rolls * CFrame.new(0, info[2], info[1] + (i - 2) * 0.05), fabrics[i], Enum.Material.Fabric)
	end
	ArtKit.Cylinder(model, "FabricRollStanding", 3.2, 0.9, rolls * CFrame.new(1.8, 1.6, 0.3) * CFrame.Angles(math.rad(-12), 0, 0), fabrics[4], Enum.Material.Fabric)
	local chimney = ArtKit.Block(model, "Chimney", Vector3.new(1.2, 3, 1.2), center * CFrame.new(-houseW / 2 + 1.5, roofTop - 1.8, D / 4), Color3.fromRGB(120, 90, 80), Enum.Material.Brick)
	smokeEmitter(chimney, refs)
end

--------------------------------------------------------------------------

-- Bâtiment fourni à la main (ServerStorage.CustomModels.Buildings.<id>)
local function buildCustom(custom: Model, origin: CFrame, def: any, refs: Refs): Model
	ArtKit.PlaceCustom(custom, origin)
	local walls = ArtKit.Block(custom, "Walls", Vector3.new(def.Width, WALL_H, def.Depth), origin * CFrame.new(0, WALL_H / 2, 0), WHITE, nil, { Transparency = 1, CanQuery = true })
	local door = ArtKit.Block(custom, "Door", Vector3.new(3, 5, 0.3), origin * CFrame.new(0, 2.5, -def.Depth / 2 - 0.3), WHITE, nil, { Transparency = 1, CanQuery = true })
	custom.PrimaryPart = walls
	refs.Walls, refs.Door = walls, door
	smokeEmitter(walls, refs)
	return custom
end

function BuildingBuilder.Build(buildingId: string, origin: CFrame, palette: { [string]: any }?): (Model, Refs)
	local def = Config.Buildings[buildingId]
	local refs: Refs = { Walls = nil :: any, Door = nil :: any, WorkFX = {}, WorkShow = {} }
	local custom = ArtKit.Custom("Buildings", buildingId)
	if custom then
		return buildCustom(custom, origin, def, refs), refs
	end

	local model = Instance.new("Model")
	model.Name = buildingId
	local builder = BUILDERS[buildingId]
	if builder then
		builder(model, origin, def, palette or {}, refs)
	else
		-- Bâtiment sans design dédié : maison simple aux couleurs du bâtiment
		house(model, origin, { Width = def.Width, Depth = def.Depth, Wall = (palette and palette.Wall) or def.WallColor, Roof = (palette and palette.Roof) or def.RoofColor, Pattern = palette and palette.Pattern, Sign = def.Icon .. " " .. def.DisplayName }, refs)
		local chimney = ArtKit.Block(model, "Chimney", Vector3.new(1.2, 3, 1.2), origin * CFrame.new(def.Width / 2 - 2.5, FOUNDATION + WALL_H + 1.5, def.Depth / 4), Color3.fromRGB(120, 90, 80), Enum.Material.Brick)
		smokeEmitter(chimney, refs)
	end
	-- Tout est décoratif sauf les murs (collision) et la porte (prompt)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= refs.Walls and d ~= refs.Door then
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	return model, refs
end

BuildingBuilder.WallHeight = WALL_H + FOUNDATION

return BuildingBuilder
